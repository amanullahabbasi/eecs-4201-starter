// DIV, DIVU, REM, REMU instructions

module div_iter (
    input  logic        clk,       // Rising edge advances one step
    input  logic        reset,     // 1 cancels the operation and resets the unit

    input  logic        start_i,   // 1 requests a divide/remainder operation
    output logic        ready_o,   // 1 means the divider can take a request
    input  logic [2:0]  funct3_i,  // Selects DIV, DIVU, REM, or REMU
    input  logic [31:0] rs1_i,     // Dividend: the number being divided
    input  logic [31:0] rs2_i,     // Divisor: the number we divide by

    output logic        done_o,    // 1 means the result is available
    input  logic        accept_i,  // 1 means the receiver can take the result
    output logic [31:0] result_o   // Selected quotient or remainder
);

logic [31:0] dividend;  // Number whose bits we bring down
logic [31:0] divisor;   // Number we compare against and subtract
logic [31:0] quotient;  // Answer bits we write one at a time
logic [32:0] remainder; // Running remainder, with room for the next bit
logic [4:0]  bit_index; // Which dividend bit to bring down: 31 down to 0

logic [2:0] operation; // Saved funct3 for the current calculation

logic quotient_negative;  // 1 if we need to negate the quotient
logic remainder_negative; // 1 if we need to negate the remainder

logic signed_operation;  // 1 for DIV or REM
logic dividend_negative; // 1 if the dividend is treated as negative
logic divisor_negative;  // 1 if the divisor is treated as negative

logic [31:0] dividend_magnitude;    // Holds the unsigned magnitude of the dividend
logic [31:0] divisor_magnitude;     // Holds the unsigned magnitude of the divisor

logic [32:0] trial_remainder;   // Remainder after bringing down the next bit

logic [31:0] final_quotient;  // Quotient after sign correction
logic [31:0] final_remainder; // Remainder after sign correction

typedef enum logic [1:0] {
    IDLE,       // Wait for a request and capture the operands
    CALCULATE,  // Bring down one dividend bit per clock
    FINISH,     // Apply the sign and select quotient or remainder
    RESULT      // Keep the answer available until accepted
} state_t;

state_t state; // Current phase

// Accept a new division request only while idle
assign ready_o = (state == IDLE);

// Announce that the quotient or remainder is available on result_o
assign done_o = (state == RESULT);

// DIV or REM means both operands are treated as signed
assign signed_operation = (funct3_i == 3'b100) || (funct3_i == 3'b110);

// For signed operations, a leftmost bit of 1 means the dividend is negative
assign dividend_negative = signed_operation && rs1_i[31];

// For signed operations, a leftmost bit of 1 means the divisor is negative
assign divisor_negative = signed_operation && rs2_i[31];

// If the dividend is negative, subtract it from zero. Otherwise, keep it
assign dividend_magnitude = dividend_negative ? (32'b0 - rs1_i) : rs1_i;

// If the divisor is negative, subtract it from zero. Otherwise, keep it
assign divisor_magnitude = divisor_negative ? (32'b0 - rs2_i) : rs2_i;

// Shift the running remainder left and bring down the next dividend bit.
assign trial_remainder = {remainder[31:0], dividend[bit_index]};

// Negate the quotient if the saved sign says it should be negative.
assign final_quotient = quotient_negative ? (32'b0 - quotient) : quotient;

// Negate the remainder if the saved dividend sign was negative.
assign final_remainder = remainder_negative ? (32'b0 - remainder[31:0]) : remainder[31:0];

always_ff @(posedge clk) begin
    if (reset) begin
        state     <= IDLE;
        dividend  <= '0;
        divisor   <= '0;
        quotient  <= '0;
        remainder <= '0;
        bit_index <= '0;
        result_o  <= '0;
        operation <= '0;
        quotient_negative  <= 1'b0;
        remainder_negative <= 1'b0;
    end else begin
        // state
        case (state)
            IDLE: begin
                if (start_i && ready_o) begin
                    operation <= funct3_i;                                          // Remember which instruction was requested
                    quotient  <= '0;                                                // Start with no quotient bits set
                    remainder <= '0;                                                // Start before bringing down any bits
                    bit_index <= 5'd31;                                             // Start at the dividend's leftmost bit
                    dividend <= dividend_magnitude;                                 // Save the value whose bits we bring down
                    divisor  <= divisor_magnitude;                                  // Save the value we compare against each step
                    quotient_negative  <= dividend_negative ^ divisor_negative;     // Operands have different signs
                    remainder_negative <= dividend_negative;                        // Remainder negative if dividend negative

                    // division by zero
                    if (rs2_i == 32'b0) begin
                        if ((funct3_i == 3'b110) || (funct3_i == 3'b111))           // REM or REMU
                            result_o    <= rs1_i;                                   // REM/REMU: return the original dividend
                        else
                            result_o    <= 32'hFFFF_FFFF;                           // DIV/DIVU: return all ones
                        state           <= RESULT;
                    end else begin
                        state           <= CALCULATE;                               // Start long division when the divisor is nonzero
                    end
                end
            end
            CALCULATE: begin
                // Check if divisor fits into trial_remainder
                if (trial_remainder >= {1'b0, divisor}) begin
                    remainder           <= trial_remainder - {1'b0, divisor};       // remainder = trial - divisor
                    quotient[bit_index] <= 1'b1;                                    // Divisor fits: write a 1
                end else begin
                    remainder           <= trial_remainder;
                    quotient[bit_index] <= 1'b0;                                    // Divisor doesn't fit: write a 0
                end
                // Move to the next dividend bit, or finish if it was last bit
                if (bit_index == 5'd0)
                    state <= FINISH;
                else
                    bit_index <= bit_index - 5'd1;
            end
            FINISH: begin
                if ((operation == 3'b110) || (operation == 3'b111))                 // REM or REMU
                    result_o <= final_remainder;                                    // REM/REMU: return the remainder
                else
                    result_o <= final_quotient;                                     // DIV/DIVU: return the quotient
                state <= RESULT;
            end
            RESULT: begin
                if (accept_i)
                    state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
