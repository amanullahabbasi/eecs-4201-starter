`timescale 1ns/1ps

module mul_iter_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic start_i = 1'b0;
    logic accept_i = 1'b0;
    logic [2:0] funct3_i = '0;
    logic [31:0] rs1_i = '0, rs2_i = '0;
    logic ready_o, done_o;
    logic [31:0] result_o;
    logic [31:0] corners [0:7];
    int checked = 0;

    always #5 clk = ~clk;

    mul_iter dut (
        .clk(clk), .reset(reset), .start_i(start_i), .ready_o(ready_o),
        .funct3_i(funct3_i), .rs1_i(rs1_i), .rs2_i(rs2_i),
        .done_o(done_o), .accept_i(accept_i), .result_o(result_o)
    );

    function automatic logic [31:0] expected_result(
        input logic [2:0] operation,
        input logic [31:0] a,
        input logic [31:0] b
    );
        logic signed [63:0] signed_a, signed_b, unsigned_b;
        logic [63:0] unsigned_a, unsigned_both;
        signed_a = $signed({{32{a[31]}}, a});
        signed_b = $signed({{32{b[31]}}, b});
        unsigned_b = $signed({32'b0, b});
        unsigned_a = {32'b0, a};
        unsigned_both = {32'b0, b};
        case (operation)
            3'b000: return 32'(a * b);
            3'b001: return 32'((signed_a * signed_b) >>> 32);
            3'b010: return 32'((signed_a * unsigned_b) >>> 32);
            3'b011: return 32'((unsigned_a * unsigned_both) >> 32);
            default: return '0;
        endcase
    endfunction

    task automatic check_case(
        input logic [2:0] operation,
        input logic [31:0] a,
        input logic [31:0] b
    );
        logic [31:0] expected;
        int cycles;
        expected = expected_result(operation, a, b);
        if (!ready_o || done_o) $fatal(1, "multiplier not ready");

        @(negedge clk);
        funct3_i = operation;
        rs1_i = a;
        rs2_i = b;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;

        cycles = 0;
        while (!done_o && cycles < 40) begin
            @(posedge clk);
            #1;
            cycles++;
        end
        if (!done_o || result_o !== expected)
            $fatal(1, "MUL mismatch: op=%b a=%h b=%h got=%h expected=%h",
                   operation, a, b, result_o, expected);

        // The result must remain stable until the receiver accepts it.
        repeat (2) begin
            @(posedge clk);
            #1;
            if (!done_o || result_o !== expected)
                $fatal(1, "result changed before accept");
        end
        accept_i = 1'b1;
        @(posedge clk);
        #1;
        accept_i = 1'b0;
        if (!ready_o || done_o) $fatal(1, "multiplier did not return to idle");
        checked++;
    endtask

    initial begin
        corners[0] = 32'h0000_0000;
        corners[1] = 32'h0000_0001;
        corners[2] = 32'h0000_0002;
        corners[3] = 32'h7fff_ffff;
        corners[4] = 32'h8000_0000;
        corners[5] = 32'h8000_0001;
        corners[6] = 32'hffff_fffe;
        corners[7] = 32'hffff_ffff;

        @(posedge clk);
        #1;
        reset = 1'b0;
        for (int op = 0; op < 4; op++) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++)
                    check_case(op[2:0], corners[i], corners[j]);
            end
            for (int i = 0; i < 250; i++)
                check_case(op[2:0], $urandom, $urandom);
        end

        // Reset must cancel a multiplication in progress.
        @(negedge clk);
        funct3_i = 3'b000;
        rs1_i = 32'd123;
        rs2_i = 32'd456;
        start_i = 1'b1;
        @(posedge clk);
        #1;
        start_i = 1'b0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        if (!ready_o || done_o) $fatal(1, "reset did not cancel multiply");
        check_case(3'b000, 32'd7, 32'd6);

        $display("PASS: %0d iterative multiply cases and reset cancellation", checked);
        $finish;
    end
endmodule
