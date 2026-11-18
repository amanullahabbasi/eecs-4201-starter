// Wrapper provides the processor one interface for all 8 m-extension instructions

module muldiv_unit (
    input  logic        clk,       // Rising edge
    input  logic        reset,     // 1 cancels the active operation

    input  logic        start_i,   // 1 means the processor has a request
    output logic        ready_o,   // 1 means the wrapper can take the request
    input  logic [2:0]  funct3_i,  // selects one of the eight m instructions
    input  logic [31:0] rs1_i,     // First operand
    input  logic [31:0] rs2_i,     // Second operand

    output logic        done_o,    // 1 means the answer is on result_o
    input  logic        accept_i,  // 1 means the processor can take the answer
    output logic [31:0] result_o   // resulting answer
);

// MUL:     000
// MULH:    001
// MULHSU:  010
// MULHU:   011

// DIV:     100
// DIVU:    101
// REM:     110
// REMU:    111

logic request_is_div;               // 1 for division or remainder, 0 for multiply
logic active_is_div;                // saved request
logic busy;                         // 1 when a request is outstanding

logic take_request;                 // processor sends to wrapper
logic send_result;                 // wrapper sends answer to processor

logic mul_ready;                    // Multiplier can take a request
logic div_ready;                    // Divider can take a request

logic mul_done;                     // Multiplier's answer is ready
logic div_done;                     // Divider's answer is ready

logic [31:0] mul_result;            // Answer from the multiplier
logic [31:0] div_result;            // Answer from the divider

// Read the leftmost funct3 bit to identify the engine, 0 for M, 1 for D/R
assign request_is_div = funct3_i[2];

// ready when idle and requested engine is ready
assign ready_o = !reset && !busy && (request_is_div ? div_ready : mul_ready);

// request transfers when the processor offers one and we are ready.
assign take_request = start_i && ready_o;

// The answer transfers when it's ready and the processor can take it.
assign send_result = done_o && accept_i;

// report when the engine we started has an answer ready.
assign done_o = !reset && busy && (active_is_div ? div_done : mul_done);

// when the answer is ready, return it
assign result_o = done_o ? (active_is_div ? div_result : mul_result) : 32'b0;

always_ff @(posedge clk) begin
    if (reset) begin
        busy          <= 1'b0;                  // no request is outstanding after reset
        active_is_div <= 1'b0;                  // saved engine choice is unused while idle
    end else if (take_request) begin
        busy          <= 1'b1;                  // request taken, don't take another until processor picks this answer up
        active_is_div <= request_is_div;        // Remember which engine got it
    end else if (send_result) begin
        busy <= 1'b0;                           // Answer taken; allow another request
    end
end

mul_iter multiplier (
    .clk      (clk),
    .reset    (reset),
    .start_i  (take_request && !request_is_div),    // Start only for a new multiply request
    .ready_o  (mul_ready),
    .funct3_i (funct3_i),
    .rs1_i    (rs1_i),
    .rs2_i    (rs2_i),
    .done_o   (mul_done),
    .accept_i (send_result && !active_is_div),      // Confirm the multiply answer was taken
    .result_o (mul_result)
);

div_iter divider (
    .clk      (clk),
    .reset    (reset),
    .start_i  (take_request && request_is_div),     // Start only for divide or remainder
    .ready_o  (div_ready),
    .funct3_i (funct3_i),
    .rs1_i    (rs1_i),
    .rs2_i    (rs2_i),
    .done_o   (div_done),
    .accept_i (send_result && active_is_div),       // Confirm the divider's answer was taken
    .result_o (div_result)
);

endmodule
