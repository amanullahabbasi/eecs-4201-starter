// MUL, MULH, MULHU, MULHSU instructions

module mul_iter (

    input logic         clk,            // clock, toggles 0/1, rising edge advances step
    input logic         reset,          // clear state and cancel calculation, true/false, 1 resets

    input logic         start_i,        // true/false, 1 request a multiplication
    output logic        ready_o,        // true/false, 1 is ready for request
    input logic [2:0]   funct3_i,       // selects multiply operation
    input logic [31:0]  rs1_i,          // first number
    input logic [31:0]  rs2_i,          // second number

    output logic        done_o,         // true/false, 1 confirms result available
    input logic         accept_i,       // true/false, 1 receiver can take result
    output logic [31:0] result_o        // value, selected 32 product bits
);

logic [63:0]        total;              // running sum
logic [63:0]        add_value;          // value to add, shifts left each step
logic [31:0]        multiplier;         // bits deciding whether to add or skip

logic [4:0]         bit_index;          // current multiplier bit being processed (0-31)

logic [2:0]         operation;          // saved funct3 for current calculation
logic               negative;           // 1 if full product needs sign correction

// 1 if each operand is negative
logic rs1_negative;
logic rs2_negative;

// gets the non-negative of the operand for calculations
logic [31:0]        rs1_magnitude;
logic [31:0]        rs2_magnitude;

// product
logic [63:0] final_product;

typedef enum logic [1:0] {
    IDLE,                       // wait for and capture request
    CALCULATE,                  // perform one shift and add step per cycle
    FINISH,                     // correct product's sign, and select high/low half
    RESULT                      // hold answer until accepted
} state_t;

state_t state;

// accept a new calculation only while idle
assign ready_o = (state == IDLE);

// announce available answer only when holding result
assign done_o = (state == RESULT);

// MULH or MULHSU and left-most bit 1 means rs1 is negative
assign rs1_negative = ((funct3_i == 3'b001) || (funct3_i == 3'b010)) && rs1_i[31];

// MULH and left-most bit 1 means rs2 is negative
assign rs2_negative = (funct3_i == 3'b001) && rs2_i[31];

// if negative, then subtract from 0 to get positive, otherwise give positive magnitude
assign rs1_magnitude = rs1_negative ? (32'b0 - rs1_i) : rs1_i;
assign rs2_magnitude = rs2_negative ? (32'b0 - rs2_i) : rs2_i;

// if the answer is negative, subtract total from 0, otherwise give total
assign final_product = negative ? (64'b0 - total) : total;

always_ff @(posedge clk) begin
    if (reset) begin
        state       <= IDLE;
        total       <= '0;
        add_value   <= '0;
        multiplier  <= '0;
        bit_index   <= '0;
        result_o    <= '0;
        operation   <= '0;
        negative    <= 1'b0;
    end else begin
        // state
        case (state)
            IDLE: begin
                // requested and ready
                if (start_i && ready_o) begin
                    total       <= '0;
                    bit_index   <= '0;
                    operation   <= funct3_i;
                    add_value   <= {32'b0, rs1_magnitude};
                    multiplier  <= rs2_magnitude;
                    negative    <= rs1_negative ^ rs2_negative;
                    state       <= CALCULATE;
                end
            end
            CALCULATE: begin
                // check rightmost bit of multiplier, add if 1, otherwise total keeps its value
                if (multiplier[0])
                    total       <= total + add_value;

                // shifts
                add_value       <= add_value << 1;
                multiplier      <= multiplier >> 1;

                // finish after processing last bit
                if (bit_index == 5'd31)
                    state       <= FINISH;
                else
                    bit_index   <= bit_index + 5'd1;
            end
            FINISH: begin
                if (operation == 3'b000)
                    result_o    <= final_product[31:0];      // MUL: lower half
                else
                    result_o    <= final_product[63:32];     // MULH, MULHU, MULHSU: upper half

                state   <= RESULT;
            end
            RESULT: begin
                if (accept_i)
                    state   <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
