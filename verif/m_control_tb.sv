/*
 * Testbench: m_control_tb
 *
 * Description: Self-checking test of the decode stage (decode.sv + control.sv)
 *              for the M-extension, wired the same way as in rv_core.
 *              1) All 8 M instructions: mdusel set, register write, ALU writeback
 *                 path, correct rs1/rs2/rd/funct3 fields
 *              2) RV32I R-type regression: ADD..AND still decode to the same
 *                 ALU operations with mdusel clear (they share funct3 with M ops)
 *              3) Pairs that differ only in funct7: MUL vs ADD vs SUB, DIV vs XOR,
 *                 DIVU vs SRL vs SRA
 *              4) Invalid / look-alike cases: funct7 values other than
 *                 0000000/0100000/0000001 on R-type, and non-R-type instructions
 *                 whose bits [31:25] happen to equal 0000001 (e.g. addi x1,x0,32)
 *                 must never select the MDU
 *
 * Run: make tb-m_control_tb -C verif/
 */

`include "constants.svh"
`timescale 1ns/1ps

module m_control_tb;

    localparam int DWIDTH = 32;

    logic [DWIDTH-1:0] insn;                     // instruction under test

    // decode outputs
    logic [6:0] opcode;                          // decoded opcode
    logic [4:0] rd, rs1, rs2;                    // decoded register numbers
    logic [6:0] funct7;                          // decoded funct7
    logic [2:0] funct3;                          // decoded funct3

    // control outputs
    logic pcsel, immsel, regwren, rs1sel, rs2sel, memren, memwren;
    logic [1:0] wbsel;                           // writeback select
    logic [3:0] alusel;                          // ALU operation
    logic mdusel;                                // multiply/divide unit select

    int errors = 0;                              // failed checks
    int checks = 0;                              // total checks

    decode #(
        .DWIDTH(DWIDTH),
        .AWIDTH(DWIDTH)
    ) decode1 (
        .clk(1'b0),
        .rst(1'b0),
        .insn_i(insn),
        .pc_i('0),
        .pc_o(),
        .insn_o(),
        .opcode_o(opcode),
        .rd_o(rd),
        .rs1_o(rs1),
        .rs2_o(rs2),
        .funct7_o(funct7),
        .funct3_o(funct3),
        .shamt_o(),
        .imm_o()
    );

    control #(
        .DWIDTH(DWIDTH)
    ) control1 (
        .insn_i(insn),
        .opcode_i(opcode),
        .funct7_i(funct7),
        .funct3_i(funct3),
        .pcsel_o(pcsel),
        .immsel_o(immsel),
        .regwren_o(regwren),
        .rs1sel_o(rs1sel),
        .rs2sel_o(rs2sel),
        .memren_o(memren),
        .memwren_o(memwren),
        .wbsel_o(wbsel),
        .alusel_o(alusel),
        .mdusel_o(mdusel)
    );

    // R-type instruction encoder
    function automatic logic [31:0] r_type(input logic [6:0] f7, input logic [4:0] src2,
                                           input logic [4:0] src1, input logic [2:0] f3,
                                           input logic [4:0] dst);
        return {f7, src2, src1, f3, dst, `R_TYPE};
    endfunction

    // Record a failed check
    task automatic check(input logic condition, input string name);
        checks++;
        if (!condition) begin
            errors++;
            $display("FAIL: %s (insn=%h)", name, insn);
        end
    endtask

    // An M instruction must select the MDU and write rd through the ALU path
    task automatic check_m(input logic [2:0] f3, input string name);
        insn = r_type(`F7_MULDIV, 5'd7, 5'd6, f3, 5'd5);
        #1;
        check(mdusel, {name, ": mdusel"});
        check(regwren && wbsel == `WB_ALU, {name, ": writes rd from execute result"});
        check(!memren && !memwren && !pcsel, {name, ": no memory access or jump"});
        check(!rs1sel && !rs2sel, {name, ": operands are rs1 and rs2"});
        check(rs1 == 5'd6 && rs2 == 5'd7 && rd == 5'd5, {name, ": register fields"});
        check(funct3 == f3, {name, ": funct3 reaches execute"});
    endtask

    // An RV32I R-type instruction must keep its ALU op and not select the MDU
    task automatic check_alu(input logic [6:0] f7, input logic [2:0] f3,
                             input logic [3:0] expected_alusel, input string name);
        insn = r_type(f7, 5'd2, 5'd1, f3, 5'd3);
        #1;
        check(!mdusel, {name, ": mdusel clear"});
        check(alusel == expected_alusel, {name, ": alusel"});
        check(regwren && wbsel == `WB_ALU, {name, ": writes rd"});
    endtask

    // Any instruction that is not an M instruction must leave mdusel clear
    task automatic check_not_m(input logic [31:0] instruction, input string name);
        insn = instruction;
        #1;
        check(!mdusel, {name, ": must not select the MDU"});
    endtask

    initial begin
        // 1) All M instructions
        check_m(`F3_MUL,    "MUL");
        check_m(`F3_MULH,   "MULH");
        check_m(`F3_MULHSU, "MULHSU");
        check_m(`F3_MULHU,  "MULHU");
        check_m(`F3_DIV,    "DIV");
        check_m(`F3_DIVU,   "DIVU");
        check_m(`F3_REM,    "REM");
        check_m(`F3_REMU,   "REMU");

        // rd = x0 is still decoded normally (the register file ignores the write)
        insn = r_type(`F7_MULDIV, 5'd2, 5'd1, `F3_MUL, 5'd0);
        #1;
        check(mdusel && rd == 5'd0, "MUL x0: decoded with rd = 0");

        // 2) and 3) RV32I R-type regression and funct7-only differences
        check_alu(`F7_ADD, `F3_ADD,    `ALU_ADD,  "ADD");
        check_alu(`F7_SUB, `F3_ADD,    `ALU_SUB,  "SUB");
        check_alu(`F7_SLL, `F3_SLEFT,  `ALU_SLL,  "SLL");
        check_alu(`F7_ADD, `F3_SLT,    `ALU_SLT,  "SLT");
        check_alu(`F7_ADD, `F3_SLTU,   `ALU_SLTU, "SLTU");
        check_alu(`F7_ADD, `F3_XOR,    `ALU_XOR,  "XOR");
        check_alu(`F7_SRL, `F3_SRIGHT, `ALU_SRL,  "SRL");
        check_alu(`F7_SRA, `F3_SRIGHT, `ALU_SRA,  "SRA");
        check_alu(`F7_ADD, `F3_OR,     `ALU_OR,   "OR");
        check_alu(`F7_ADD, `F3_AND,    `ALU_AND,  "AND");

        // 4) Invalid funct7 values on R-type never select the MDU
        check_not_m(r_type(7'b0000010, 5'd2, 5'd1, `F3_ADD, 5'd3), "R-type funct7=0000010");
        check_not_m(r_type(7'b0100001, 5'd2, 5'd1, `F3_XOR, 5'd3), "R-type funct7=0100001");
        check_not_m(r_type(7'b1111111, 5'd2, 5'd1, `F3_DIV, 5'd3), "R-type funct7=1111111");

        // Non-R-type look-alikes: bits [31:25] = 0000001 but the opcode differs
        check_not_m({7'b0000001, 5'd0, 5'd0, `F3_ADD, 5'd1, `I_TYPE},   "addi x1,x0,32");
        check_not_m({7'b0000001, 5'd5, 5'd0, `F3_SLEFT, 5'd1, `I_TYPE}, "slli-shaped imm");
        check_not_m({7'b0000001, 5'd0, 5'd2, `F3_LW, 5'd4, `I_TYPE_L},  "lw x4,32(x2)");
        check_not_m({7'b0000001, 5'd3, 5'd2, `F3_SW, 5'd0, `S_TYPE},    "sw x3,32(x2)");
        check_not_m({7'b0000001, 5'd2, 5'd1, `F3_BEQ, 5'd0, `B_TYPE},   "beq with imm[11:5]=1");
        check_not_m({7'b0000001, 13'd0, 5'd1, `U_TYPE_LUI},             "lui x1,0x2000");
        check_not_m(`NOP,                                               "nop");

        $display("=========================================");
        $display("m_control_tb: %0d checks, %0d errors", checks, errors);
        $display("=========================================");
        if (errors == 0) begin
            $display("m_control_tb passed");
        end
        else begin
            $fatal(1, "m_control_tb failed: %0d errors", errors);
        end
        $finish;
    end

endmodule : m_control_tb
