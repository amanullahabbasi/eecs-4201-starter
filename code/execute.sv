/*
 * Module: alu
 *
 * Description: ALU implementation for execute stage.
 *
 * Inputs:
 * 1) 32-bit PC pc_i
 * 2) 32-bit rs1 data rs1_i
 * 3) 32-bit rs2 data rs2_i
 * 4) 3-bit funct3 funct3_i
 * 5) 7-bit funct7 funct7_i
 *
 * Outputs:
 * 1) 32-bit result of ALU res_o
 * 2) 1-bit branch taken signal brtaken_o
 */

`include "constants.svh"

module alu #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32
)(
    input logic [AWIDTH-1:0] pc_i,
    input logic [DWIDTH-1:0] rs1_i,
    input logic [DWIDTH-1:0] rs2_i,
    input logic [2:0] funct3_i,
    input logic [6:0] funct7_i,
    input logic [6:0] opcode_i,
    input logic [DWIDTH-1:0] imm_i,
    input logic [3:0] alusel_i,
    output logic [DWIDTH-1:0] res_o,
    output logic brtaken_o
);
    // Signals for branch control signals
    logic breq, brlt;

    /*
     * Instantiation of branch control module
     * This made more sense to me, so we instantiated it here.
     */
    branch_control #(
        .DWIDTH(DWIDTH)
    ) bc (
        .opcode_i(opcode_i),
        .funct3_i(funct3_i),
        .rs1_i(rs1_i),
        .rs2_i(rs2_i),
        .breq_o(breq),
        .brlt_o(brlt)
    );

    function automatic logic branch_taken(
        input logic [6:0] opcode,
        input logic [2:0] funct3,
        input logic breq_v,
        input logic brlt_v
    );
        branch_taken = 1'b0;
        if (opcode == `B_TYPE) begin
            case (funct3)
                `F3_BEQ:  branch_taken = breq_v;
                `F3_BNE:  branch_taken = !breq_v;
                `F3_BLT, `F3_BLTU: branch_taken = brlt_v;
                `F3_BGE, `F3_BGEU: branch_taken = !brlt_v;
                default: ;
            endcase
        end
    endfunction

    function automatic logic [DWIDTH-1:0] add_result(
        input logic [6:0] opcode,
        input logic [AWIDTH-1:0] pc,
        input logic [DWIDTH-1:0] rs1,
        input logic [DWIDTH-1:0] rs2,
        input logic [DWIDTH-1:0] imm
    );
        if (opcode == `B_TYPE) add_result = pc + imm;
        else if (opcode == `I_TYPE_JALR) add_result = (rs1 + rs2) & 32'hFFFF_FFFE;
        else add_result = rs1 + rs2;
    endfunction

    function automatic logic [DWIDTH-1:0] alu_result(
        input logic [3:0] alusel,
        input logic [6:0] opcode,
        input logic [AWIDTH-1:0] pc,
        input logic [DWIDTH-1:0] rs1,
        input logic [DWIDTH-1:0] rs2,
        input logic [DWIDTH-1:0] imm
    );
        case (alusel)
            `ALU_ADD:  alu_result = add_result(opcode, pc, rs1, rs2, imm);
            `ALU_SUB:  alu_result = rs1 - rs2;
            `ALU_AND:  alu_result = rs1 & rs2;
            `ALU_OR:   alu_result = rs1 | rs2;
            `ALU_XOR:  alu_result = rs1 ^ rs2;
            `ALU_SLL:  alu_result = rs1 << rs2[4:0];
            `ALU_SRL:  alu_result = rs1 >> rs2[4:0];
            `ALU_SRA:  alu_result = $signed(rs1) >>> rs2[4:0];
            `ALU_SLT:  alu_result = ($signed(rs1) < $signed(rs2)) ? 32'd1 : 32'd0;
            `ALU_SLTU: alu_result = (rs1 < rs2) ? 32'd1 : 32'd0;
            default:   alu_result = {DWIDTH{1'b0}};
        endcase
    endfunction

    always_comb begin
        brtaken_o = branch_taken(opcode_i, funct3_i, breq, brlt);
    end

    always_comb begin
        res_o = alu_result(alusel_i, opcode_i, pc_i, rs1_i, rs2_i, imm_i);
    end

endmodule : alu
