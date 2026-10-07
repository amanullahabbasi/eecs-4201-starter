/*
 * Module: branch_control
 *
 * Description: Branch comparison logic for conditional branch instructions.
 */
`include "constants.svh"

module branch_control #(
    parameter int DWIDTH=32
)(
    input logic [6:0] opcode_i,
    input logic [2:0] funct3_i,
    input logic [DWIDTH-1:0] rs1_i,
    input logic [DWIDTH-1:0] rs2_i,
    output logic breq_o,
    output logic brlt_o
);

    logic branch_insn;
    logic unsigned_branch;
    logic signed_less;
    logic unsigned_less;

    assign branch_insn = opcode_i == `B_TYPE;
    assign unsigned_branch = funct3_i == `F3_BLTU || funct3_i == `F3_BGEU;
    assign signed_less = $signed(rs1_i) < $signed(rs2_i);
    assign unsigned_less = rs1_i < rs2_i;

    assign breq_o = branch_insn && (rs1_i == rs2_i);
    assign brlt_o = branch_insn && (unsigned_branch ? unsigned_less : signed_less);

endmodule : branch_control
