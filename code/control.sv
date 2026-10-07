/*
 * Module: control
 *
 * Description: This module sets the control bits (control path) based on the decoded
 * instruction. Note that this is part of the decode stage but housed in a separate
 * module for better readability, debug and design purposes.
 *
 * Inputs:
 * 1) DWIDTH instruction ins_i
 * 2) 7-bit opcode opcode_i
 * 3) 7-bit funct7 funct7_i
 * 4) 3-bit funct3 funct3_i
 *
 * Outputs:
 * 1) 1-bit PC select pcsel_o
 * 2) 1-bit Immediate select immsel_o
 * 3) 1-bit register write en regwren_o
 * 4) 1-bit rs1 select rs1sel_o
 * 5) 1-bit rs2 select rs2sel_o
 * 6) k-bit ALU select alusel_o
 * 7) 1-bit memory read en memren_o
 * 8) 1-bit memory write en memwren_o
 * 9) 2-bit writeback sel wbsel_o
 */

`include "constants.svh"

module control #(
	parameter int DWIDTH=32
)(
	// inputs
    input logic [DWIDTH-1:0] insn_i,
    input logic [6:0] opcode_i,
    input logic [6:0] funct7_i,
    input logic [2:0] funct3_i,

    // outputs
    output logic pcsel_o,
    output logic immsel_o,
    output logic regwren_o,
    output logic rs1sel_o,
    output logic rs2sel_o,
    output logic memren_o,
    output logic memwren_o,
    output logic [1:0] wbsel_o,
    output logic [3:0] alusel_o
);

/* Logic hole 4 (LH4): Complete the control path. This is a key logic module
                       that is crucial for correctness. Pay close attention to
                       this logic.
*/

    logic [12:0] ctrl_bits;

    function automatic logic [3:0] alu_rtype(
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );
        case (funct3)
            `F3_ADD:    alu_rtype = (funct7 == `F7_SUB) ? `ALU_SUB : `ALU_ADD;
            `F3_XOR:    alu_rtype = `ALU_XOR;
            `F3_OR:     alu_rtype = `ALU_OR;
            `F3_AND:    alu_rtype = `ALU_AND;
            `F3_SLEFT:  alu_rtype = `ALU_SLL;
            `F3_SRIGHT: alu_rtype = (funct7 == `F7_SRA) ? `ALU_SRA : `ALU_SRL;
            `F3_SLT:    alu_rtype = `ALU_SLT;
            `F3_SLTU:   alu_rtype = `ALU_SLTU;
            default:    alu_rtype = `ALU_NOP;
        endcase
    endfunction

    function automatic logic [3:0] alu_itype(
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );
        case (funct3)
            `F3_ADD:    alu_itype = `ALU_ADD;
            `F3_XOR:    alu_itype = `ALU_XOR;
            `F3_OR:     alu_itype = `ALU_OR;
            `F3_AND:    alu_itype = `ALU_AND;
            `F3_SLEFT:  alu_itype = `ALU_SLL;
            `F3_SRIGHT: alu_itype = (funct7 == `F7_SRA) ? `ALU_SRA : `ALU_SRL;
            `F3_SLT:    alu_itype = `ALU_SLT;
            `F3_SLTU:   alu_itype = `ALU_SLTU;
            default:    alu_itype = `ALU_NOP;
        endcase
    endfunction

    function automatic logic [12:0] control_bits(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic [6:0] funct7
    );
        control_bits = {`ALU_NOP, `WB_ALU, 7'b0};
        case (opcode)
            `R_TYPE:      control_bits = {alu_rtype(funct3, funct7), `WB_ALU, 7'b0000100};
            `I_TYPE:      control_bits = {alu_itype(funct3, funct7), `WB_ALU, 7'b0010110};
            `I_TYPE_L:    control_bits = {`ALU_ADD, `WB_MEM, 7'b0110110};
            `S_TYPE:      control_bits = {`ALU_ADD, `WB_ALU, 7'b1010010};
            `B_TYPE:      control_bits = {`ALU_ADD, `WB_ALU, 7'b0000000};
            `I_TYPE_JALR: control_bits = {`ALU_ADD, `WB_PC4, 7'b0010111};
            `J_TYPE:      control_bits = {`ALU_ADD, `WB_PC4, 7'b0011111};
            `U_TYPE_LUI:  control_bits = {`ALU_NOP, `WB_IMM, 7'b0000100};
            `U_TYPE_AUIPC:control_bits = {`ALU_ADD, `WB_ALU, 7'b0011110};
            default: ;
        endcase
    endfunction

    always_comb begin
        ctrl_bits = control_bits(opcode_i, funct3_i, funct7_i);
    end

    assign pcsel_o   = ctrl_bits[`PCSEL];
    assign immsel_o  = ctrl_bits[`IMMSEL];
    assign regwren_o = ctrl_bits[`REGWREN];
    assign rs1sel_o  = ctrl_bits[`RS1SEL];
    assign rs2sel_o  = ctrl_bits[`RS2SEL];
    assign memren_o  = ctrl_bits[`MEMREN];
    assign memwren_o = ctrl_bits[`MEMWREN];
    assign wbsel_o   = ctrl_bits[`WBSEL];
    assign alusel_o  = ctrl_bits[`ALUSEL];

endmodule : control


