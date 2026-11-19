`timescale 1ns/1ps

// Iterative RV32M divider. The result is valid for one cycle when done_o is high.
module div_rem_unit (
    input  logic        clk,
    input  logic        rst,
    input  logic        start_i,
    input  logic [2:0]  funct3_i,
    input  logic [31:0] dividend_i,
    input  logic [31:0] divisor_i,
    output logic        ready_o,
    output logic        busy_o,
    output logic        done_o,
    output logic [31:0] result_o
);
    typedef enum logic [1:0] {IDLE, RUN, SIGN, DONE} state_t;

    state_t state_q, state_d;
    logic [31:0] quotient_q, next_quotient;
    logic [31:0] remainder_q, next_remainder;
    logic [31:0] divisor_q, result_q;
    logic [32:0] shifted_remainder;
    logic [33:0] subtraction;
    logic [5:0] bit_index_q;
    logic negate_quotient_q, negate_remainder_q, return_remainder_q;
    logic is_signed_op, divisor_is_zero, signed_overflow;
    logic start_division, start_special, can_subtract;
    logic [31:0] dividend_magnitude, divisor_magnitude;
    logic [31:0] special_result, signed_result;

    assign is_signed_op = !funct3_i[0];
    assign divisor_is_zero = divisor_i == 32'b0;
    assign signed_overflow = is_signed_op && dividend_i == 32'h8000_0000 &&
                             divisor_i == 32'hffff_ffff;

    assign dividend_magnitude = is_signed_op && dividend_i[31] ?
                                (~dividend_i + 32'd1) : dividend_i;
    assign divisor_magnitude = is_signed_op && divisor_i[31] ?
                               (~divisor_i + 32'd1) : divisor_i;

    // RISC-V defines the results for division by zero and signed overflow.
    assign special_result = funct3_i[1] ?
                            (divisor_is_zero ? dividend_i : 32'b0) :
                            (divisor_is_zero ? 32'hffff_ffff : dividend_i);
    assign start_special = ready_o && start_i && funct3_i[2] &&
                           (divisor_is_zero || signed_overflow);
    assign start_division = ready_o && start_i && funct3_i[2] &&
                            !divisor_is_zero && !signed_overflow;

    // Restoring division: shift in one dividend bit, then subtract if possible.
    assign shifted_remainder = {remainder_q, quotient_q[31]};
    assign subtraction = {1'b0, shifted_remainder} - {2'b0, divisor_q};
    assign can_subtract = !subtraction[33];
    assign next_remainder = can_subtract ? subtraction[31:0] : shifted_remainder[31:0];
    assign next_quotient = {quotient_q[30:0], can_subtract};

    assign signed_result = return_remainder_q ?
                           (negate_remainder_q ? (~remainder_q + 32'd1) : remainder_q) :
                           (negate_quotient_q ? (~quotient_q + 32'd1) : quotient_q);

    assign ready_o = state_q == IDLE;
    assign busy_o = state_q != IDLE;
    assign done_o = state_q == DONE;
    assign result_o = result_q;

    always_comb begin
        state_d = state_q;
        case (state_q)
            IDLE: begin
                if (start_special) state_d = DONE;
                else if (start_division) state_d = RUN;
            end
            RUN:     if (bit_index_q == 6'd31) state_d = SIGN;
            SIGN:    state_d = DONE;
            DONE:    state_d = IDLE;
            default: state_d = IDLE;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) state_q <= IDLE;
        else state_q <= state_d;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            quotient_q <= '0;
            remainder_q <= '0;
        end else if (start_division) begin
            quotient_q <= dividend_magnitude;
            remainder_q <= '0;
        end else if (state_q == RUN) begin
            quotient_q <= next_quotient;
            remainder_q <= next_remainder;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) divisor_q <= '0;
        else if (start_division) divisor_q <= divisor_magnitude;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) bit_index_q <= '0;
        else if (start_division) bit_index_q <= '0;
        else if (state_q == RUN) bit_index_q <= bit_index_q + 6'd1;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            negate_quotient_q <= 1'b0;
            negate_remainder_q <= 1'b0;
            return_remainder_q <= 1'b0;
        end else if (start_division) begin
            negate_quotient_q <= is_signed_op && (dividend_i[31] ^ divisor_i[31]);
            negate_remainder_q <= is_signed_op && dividend_i[31];
            return_remainder_q <= funct3_i[1];
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) result_q <= '0;
        else if (start_special) result_q <= special_result;
        else if (state_q == SIGN) result_q <= signed_result;
    end
endmodule : div_rem_unit
