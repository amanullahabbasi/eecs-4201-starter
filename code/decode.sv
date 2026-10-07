/*
 * Module: decode
 *
 * Description: Decode stage
 */

`include "constants.svh"

module decode #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32
)(
    input logic clk,
    input logic rst,
    input logic [DWIDTH - 1:0] insn_i,
    input logic [AWIDTH - 1:0] pc_i,

    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o,
    output logic [6:0] opcode_o,
    output logic [4:0] rd_o,
    output logic [4:0] rs1_o,
    output logic [4:0] rs2_o,
    output logic [6:0] funct7_o,
    output logic [2:0] funct3_o,
    output logic [4:0] shamt_o,
    output logic [DWIDTH-1:0] imm_o
);
    logic uses_rs1;
    logic uses_rs2;

    assign pc_o = pc_i;
    assign insn_o = insn_i;
    assign opcode_o = `OPCODE;
    assign funct3_o = `FUNCT3;
    assign funct7_o = `FUNCT7;

    assign uses_rs1 = opcode_o == `R_TYPE || opcode_o == `I_TYPE ||
                      opcode_o == `I_TYPE_L || opcode_o == `I_TYPE_JALR ||
                      opcode_o == `S_TYPE || opcode_o == `B_TYPE;
    assign uses_rs2 = opcode_o == `R_TYPE || opcode_o == `S_TYPE ||
                      opcode_o == `B_TYPE;

    assign rd_o = (opcode_o != `S_TYPE && opcode_o != `B_TYPE) ? insn_i[11:7] : 5'd0;
    assign rs1_o = uses_rs1 ? insn_i[19:15] : 5'd0;
    assign rs2_o = uses_rs2 ? insn_i[24:20] : 5'd0;
    assign shamt_o = insn_i[24:20];
    assign imm_o = '0;

endmodule : decode
