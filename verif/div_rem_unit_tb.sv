`timescale 1ns/1ps

module div_rem_unit_tb;
    // Testbench drives the divider inputs.
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start_i = 1'b0;
    logic [2:0] funct3_i = '0;
    logic [31:0] dividend_i = '0;
    logic [31:0] divisor_i = '0;
    logic ready_o, busy_o, done_o;
    logic [31:0] result_o;
    logic [31:0] corner_values [0:13]; // Values near arithmetic boundaries
    int cases_checked = 0; // Counts completed arithmetic checks

    // Generate the test clock.
    always #5 clk = ~clk;

    // Connect the unit under test.
    div_rem_unit dut (
        .clk(clk),
        .rst(rst),
        .start_i(start_i),
        .funct3_i(funct3_i),
        .dividend_i(dividend_i),
        .divisor_i(divisor_i),
        .ready_o(ready_o),
        .busy_o(busy_o),
        .done_o(done_o),
        .result_o(result_o)
    );

    // Calculate an independent expected answer.
    function automatic logic [31:0] reference_result(
        input logic [2:0] operation,
        input logic [31:0] dividend,
        input logic [31:0] divisor
    );
        logic signed [31:0] signed_dividend, signed_divisor;

        signed_dividend = $signed(dividend); // Interpret bits as signed
        signed_divisor = $signed(divisor); // Interpret bits as signed

        // RISC-V division-by-zero rule.
        if (divisor == 0) return operation[1] ? dividend : 32'hffff_ffff;
        // RISC-V signed-overflow rule.
        if (!operation[0] && dividend == 32'h8000_0000 && divisor == 32'hffff_ffff)
            return operation[1] ? 32'b0 : dividend;

        // Select signed or unsigned arithmetic.
        case (operation)
            3'b100: return signed_dividend / signed_divisor;
            3'b101: return dividend / divisor;
            3'b110: return signed_dividend % signed_divisor;
            3'b111: return dividend % divisor;
            default: return 32'b0;
        endcase
    endfunction

    // Send request and check response.
    task automatic run_case(
        input logic [2:0] operation,
        input logic [31:0] dividend,
        input logic [31:0] divisor
    );
        logic [31:0] expected;
        int cycles;

        expected = reference_result(operation, dividend, divisor); // Compute comparison value
        // Unit must begin idle.
        if (!ready_o || busy_o || done_o) $fatal(1, "divider not ready");

        // Present operands before clock edge.
        @(negedge clk);
        funct3_i = operation;
        dividend_i = dividend;
        divisor_i = divisor;
        start_i = 1'b1;

        // One clock edge accepts request.
        @(posedge clk);
        #1;
        start_i = 1'b0;
        cycles = 0;

        // Wait, with a timeout guard.
        while (!done_o && cycles < 40) begin
            @(posedge clk);
            #1;
            cycles++;
        end

        // Report incomplete or incorrect operations.
        if (!done_o)
            $fatal(1, "timeout: op=%b dividend=%h divisor=%h",
                   operation, dividend, divisor);
        if (!busy_o || result_o !== expected)
            $fatal(1, "wrong result: op=%b dividend=%h divisor=%h got=%h expected=%h",
                   operation, dividend, divisor, result_o, expected);

        // Done must clear next cycle.
        @(posedge clk);
        #1;
        if (!ready_o || busy_o || done_o) $fatal(1, "done did not clear");
        cases_checked++; // Count successful arithmetic case
    endtask

    initial begin
        // Include zero, powers, and signed limits.
        corner_values[0] = 32'h0000_0000;
        corner_values[1] = 32'h0000_0001;
        corner_values[2] = 32'h0000_0002;
        corner_values[3] = 32'h0000_0003;
        corner_values[4] = 32'h0000_0007;
        corner_values[5] = 32'h0000_ffff;
        corner_values[6] = 32'h7fff_ffff;
        corner_values[7] = 32'h8000_0000;
        corner_values[8] = 32'h8000_0001;
        corner_values[9] = 32'hffff_ffff;
        corner_values[10] = 32'hffff_fffe;
        corner_values[11] = 32'hffff_fff9;
        corner_values[12] = 32'h0001_0000;
        corner_values[13] = 32'h4000_0000;

        // Release reset before testing.
        @(posedge clk);
        #1;
        rst = 1'b0;
        if (!ready_o) $fatal(1, "reset did not produce idle state");

        // Four operations times 14 squared pairs.
        for (int operation = 4; operation < 8; operation++) begin
            for (int i = 0; i < 14; i++) begin
                for (int j = 0; j < 14; j++)
                    run_case(operation[2:0], corner_values[i], corner_values[j]);
            end
        end

        // Add 250 random pairs per operation.
        for (int operation = 4; operation < 8; operation++) begin
            for (int i = 0; i < 250; i++)
                run_case(operation[2:0], $urandom, $urandom);
        end

        // Reset cancels an active operation.
        @(negedge clk);
        funct3_i = 3'b101;
        dividend_i = 32'h7fff_ffff;
        divisor_i = 32'd3;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst = 1'b1;
        #1;
        if (!ready_o || done_o || result_o != 0)
            $fatal(1, "reset failed to cancel division");
        rst = 1'b0;
        run_case(3'b101, 32'h7fff_ffff, 32'd3);

        // Busy unit ignores later requests.
        @(negedge clk);
        funct3_i = 3'b100;
        dividend_i = 32'd100;
        divisor_i = 32'd7;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        funct3_i = 3'b111;
        dividend_i = 32'd9;
        divisor_i = 32'd2;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;
        while (!done_o) begin
            @(posedge clk);
            #1;
        end
        if (result_o !== 32'd14) $fatal(1, "busy request replaced operation");
        @(posedge clk);
        #1;
        if (!ready_o) $fatal(1, "divider did not return to idle");

        // Reject non-divider operation encoding.
        @(negedge clk);
        funct3_i = 3'b000;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;
        if (!ready_o || busy_o || done_o) $fatal(1, "invalid op was accepted");

        // Print arithmetic case count.
        $display("PASS: %0d divide/remainder cases and reset cancellation", cases_checked);
        $finish;
    end
endmodule
