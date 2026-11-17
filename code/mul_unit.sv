/*
 * Module: mul_unit
 *
 * Description: Single-cycle RV32M multiplier (MUL, MULH, MULHSU, MULHU).
 *              Each operand is extended by one bit: its sign bit when the
 *              operation treats it as signed, 0 when unsigned. A single signed
 *              (DWIDTH+1) x (DWIDTH+1) multiplier then covers all four
 *              operations. MUL returns the low half of the product (identical
 *              for signed and unsigned operands); the MULH variants return the
 *              high half.
 *
 * Inputs:
 * 1) 3-bit funct3 funct3_i (selects the operation)
 * 2) DWIDTH rs1 data rs1_i
 * 3) DWIDTH rs2 data rs2_i
 *
 * Outputs:
 * 1) DWIDTH result result_o
 */

`include "constants.svh"

module mul_unit #(
    parameter int DWIDTH=32
)(
    input  logic [2:0]        funct3_i,
    input  logic [DWIDTH-1:0] rs1_i,
    input  logic [DWIDTH-1:0] rs2_i,
    output logic [DWIDTH-1:0] result_o
);
    logic rs1_is_signed;                   // rs1 is signed for MULH and MULHSU
    logic rs2_is_signed;                   // rs2 is signed for MULH only
    logic signed [DWIDTH:0] operand_a;     // rs1 extended by one sign/zero bit
    logic signed [DWIDTH:0] operand_b;     // rs2 extended by one sign/zero bit
    logic signed [2*DWIDTH+1:0] product;   // full product of the extended operands

    assign rs1_is_signed = (funct3_i == `F3_MULH) || (funct3_i == `F3_MULHSU);
    assign rs2_is_signed = (funct3_i == `F3_MULH);
    assign operand_a = {rs1_is_signed & rs1_i[DWIDTH-1], rs1_i};
    assign operand_b = {rs2_is_signed & rs2_i[DWIDTH-1], rs2_i};

    // Both operands are signed, so they are sign-extended to the product width.
    // TODO: a single-cycle multiplier lengthens the execute-stage critical
    //       path. A 2-stage pipelined or Booth radix-4 multiplier would recover
    //       fmax at the cost of one extra cycle of latency.
    /* verilator lint_off WIDTH */
    assign product = operand_a * operand_b;
    /* verilator lint_on WIDTH */

    // MUL takes the low half; MULH, MULHSU and MULHU take the high half
    assign result_o = (funct3_i == `F3_MUL) ? product[DWIDTH-1:0]
                                            : product[2*DWIDTH-1:DWIDTH];

endmodule : mul_unit
