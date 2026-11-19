`timescale 1ns/1ps

// One dividend bit per cycle.
// done_o marks the result cycle.
module div_rem_unit (
    input  logic        clk,         // Advances one division step
    input  logic        rst,         // Cancels the current request
    input  logic        start_i,     // Requests a new operation
    input  logic [2:0]  funct3_i,    // Selects DIV, DIVU, REM, REMU
    input  logic [31:0] dividend_i,  // Number being divided
    input  logic [31:0] divisor_i,   // Number dividing the dividend
    output logic        ready_o,     // Can accept a request
    output logic        busy_o,      // Operation is not idle
    output logic        done_o,      // Result is now valid
    output logic [31:0] result_o     // Final quotient or remainder
);
    // IDLE accepts, RUN calculates, SIGN corrects, DONE reports.
    typedef enum logic [1:0] {IDLE, RUN, SIGN, DONE} state_t;

    state_t state_q, state_d; // Current and next states
    logic [31:0] quotient_q, next_quotient; // Remaining dividend and quotient bits
    logic [31:0] remainder_q, next_remainder; // Current and next remainder
    logic [31:0] divisor_q, result_q; // Saved divisor and final answer
    logic [32:0] shifted_remainder; // Bring down next dividend bit
    logic [33:0] subtraction; // Extra bit detects negative difference
    logic [5:0] bit_index_q; // Counts all 32 steps
    logic negate_quotient_q, negate_remainder_q, return_remainder_q; // Saved sign and result choice
    logic is_signed_op, divisor_is_zero, signed_overflow; // Detect operation and exceptions
    logic start_division, start_special, can_subtract; // Start conditions and comparison
    logic [31:0] dividend_magnitude, divisor_magnitude; // Positive magnitudes for signed inputs
    logic [31:0] special_result, signed_result; // Exceptional or corrected answer

    // funct3 low bit distinguishes signedness.
    assign is_signed_op = !funct3_i[0];
    // Zero divisor has defined results.
    assign divisor_is_zero = divisor_i == 32'b0;
    // Minimum integer divided by minus one.
    assign signed_overflow = is_signed_op && dividend_i == 32'h8000_0000 &&
                             divisor_i == 32'hffff_ffff;

    // Convert negative inputs to magnitudes.
    assign dividend_magnitude = is_signed_op && dividend_i[31] ?
                                (~dividend_i + 32'd1) : dividend_i;
    assign divisor_magnitude = is_signed_op && divisor_i[31] ?
                               (~divisor_i + 32'd1) : divisor_i;

    // Remainder returns dividend on zero.
    // Quotient returns all ones on zero.
    // Signed overflow returns dividend or zero.
    assign special_result = funct3_i[1] ?
                            (divisor_is_zero ? dividend_i : 32'b0) :
                            (divisor_is_zero ? 32'hffff_ffff : dividend_i);
    // Accept exceptional request only when idle.
    assign start_special = ready_o && start_i && funct3_i[2] &&
                           (divisor_is_zero || signed_overflow);
    // Normal request starts 32 steps.
    assign start_division = ready_o && start_i && funct3_i[2] &&
                            !divisor_is_zero && !signed_overflow;

    // Shift next bit into remainder.
    assign shifted_remainder = {remainder_q, quotient_q[31]};
    // Try subtracting the saved divisor.
    assign subtraction = {1'b0, shifted_remainder} - {2'b0, divisor_q};
    // Negative result means divisor too large.
    assign can_subtract = !subtraction[33];
    // Keep subtraction only when possible.
    assign next_remainder = can_subtract ? subtraction[31:0] : shifted_remainder[31:0];
    // Append one quotient decision bit.
    assign next_quotient = {quotient_q[30:0], can_subtract};

    // Select quotient or remainder, then restore sign.
    assign signed_result = return_remainder_q ?
                           (negate_remainder_q ? (~remainder_q + 32'd1) : remainder_q) :
                           (negate_quotient_q ? (~quotient_q + 32'd1) : quotient_q);

    // State determines interface status.
    assign ready_o = state_q == IDLE;
    assign busy_o = state_q != IDLE;
    assign done_o = state_q == DONE;
    assign result_o = result_q;

    // Choose the next control state.
    always_comb begin
        // Stay put unless transition applies.
        state_d = state_q;
        case (state_q)
            IDLE: begin
                // Exceptions skip calculation steps.
                if (start_special) state_d = DONE;
                else if (start_division) state_d = RUN;
            end
            // Finish after 32 quotient bits.
            RUN:     if (bit_index_q == 6'd31) state_d = SIGN;
            // Sign correction takes one cycle.
            SIGN:    state_d = DONE;
            // Done pulse lasts one cycle.
            DONE:    state_d = IDLE;
            default: state_d = IDLE;
        endcase
    end

    // Reset or advance current state.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state_q <= IDLE;
        else state_q <= state_d;
    end

    // Store partial quotient and remainder.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            quotient_q <= '0;
            remainder_q <= '0;
        end else if (start_division) begin
            // Load magnitude; remainder starts empty.
            quotient_q <= dividend_magnitude;
            remainder_q <= '0;
        end else if (state_q == RUN) begin
            // Complete one restoring division step.
            quotient_q <= next_quotient;
            remainder_q <= next_remainder;
        end
    end

    // Keep divisor stable during division.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) divisor_q <= '0;
        else if (start_division) divisor_q <= divisor_magnitude;
    end

    // Track the 32 division steps.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) bit_index_q <= '0;
        else if (start_division) bit_index_q <= '0;
        else if (state_q == RUN) bit_index_q <= bit_index_q + 6'd1;
    end

    // Remember signs and requested output.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            negate_quotient_q <= 1'b0;
            negate_remainder_q <= 1'b0;
            return_remainder_q <= 1'b0;
        end else if (start_division) begin
            // Quotient negative when signs differ.
            negate_quotient_q <= is_signed_op && (dividend_i[31] ^ divisor_i[31]);
            // Remainder follows the dividend sign.
            negate_remainder_q <= is_signed_op && dividend_i[31];
            // funct3 bit selects remainder output.
            return_remainder_q <= funct3_i[1];
        end
    end

    // Save result before asserting done.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) result_q <= '0;
        else if (start_special) result_q <= special_result;
        else if (state_q == SIGN) result_q <= signed_result;
    end
endmodule : div_rem_unit
