`include "constants.svh"

`timescale 1ns/1ps

`ifndef TIMEOUT
  `define TIMEOUT 32'd50
`endif

`ifndef RESET_CYCLES
  `define RESET_CYCLES 2
`endif

module lh1_tb;

   logic clk = 0;
   logic rst = 1;
   always #1 clk = ~clk;

   localparam int DWIDTH = 32;
   localparam int AWIDTH = 32;

    /*
     * LH1 test: checks the next pc logic (jump_branch, f_pc) in rv_core.
     * The other logic holes aren't done yet, so we force pcsel (control),
     * brtaken and the alu result (target address) and check where the pc goes.
     */

    rv_core #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH)
    ) hut (
        .clk(clk),
        .reset(rst)
    );

    int errors = 0;
    logic [AWIDTH-1:0] old_pc;

    initial begin
        force hut.c_pcsel   = 1'b0;
        force hut.e_brtaken = 1'b0;
        force hut.e_res     = 32'h01000000;

        wait (!rst);
        @(negedge clk);

        // Test 1: no jump -> pc goes to pc + 4
        force hut.c_pcsel   = 1'b0;
        force hut.e_brtaken = 1'b0;
        force hut.e_res     = 32'h01000100;
        old_pc = hut.pc;
        @(negedge clk);
        if (hut.pc != old_pc + 4) begin
            $display("Test 1 FAILED (no jump): pc=%h expected %h", hut.pc, old_pc + 4);
            errors++;
        end

        // Test 2: taken branch -> pc goes to the alu target
        force hut.c_pcsel   = 1'b0;
        force hut.e_brtaken = 1'b1;
        force hut.e_res     = 32'h01000048;
        @(negedge clk);
        if (hut.pc != 32'h01000048) begin
            $display("Test 2 FAILED (branch taken): pc=%h expected 01000048", hut.pc);
            errors++;
        end

        // Test 3: jal -> pc goes to the alu target
        force hut.c_pcsel   = 1'b1;
        force hut.e_brtaken = 1'b0;
        force hut.e_res     = 32'h01000204;
        @(negedge clk);
        if (hut.pc != 32'h01000204) begin
            $display("Test 3 FAILED (jal): pc=%h expected 01000204", hut.pc);
            errors++;
        end

        // Test 4: jalr to an odd address -> bit 0 cleared
        force hut.c_pcsel   = 1'b1;
        force hut.e_brtaken = 1'b0;
        force hut.e_res     = 32'h01000305;
        @(negedge clk);
        if (hut.pc != 32'h01000304) begin
            $display("Test 4 FAILED (jalr odd): pc=%h expected 01000304", hut.pc);
            errors++;
        end

        $display("=========================================");
        if (errors == 0)
            $display("LH1: All tests passed");
        else
            $display("LH1: %0d tests failed", errors);
        $display("=========================================");
        $finish;
    end

    /*
     * This block is to stop infinite loops, if you you see "SIMULATION TIMEOUT" it means either:
     *      1) The number of cycles before timeout is too few to capture the full length of your program.
     *      2) There is a flaw in your logic or execution causing an infinite loop. [THIS IS MOST LIKELY]
     */
    integer counter = 0;
    always_ff @(posedge clk) begin
        counter <= counter + 1;
        if (counter < `RESET_CYCLES) begin
            rst <= 1;
        end else begin
            rst <= 0;
        end
        if (counter >= `TIMEOUT) begin
            $display("========== Simulation TIMEOUT!!! ==========");
            $finish;
        end
    end

    // Dump commands to produce waveform files.
    initial begin
      $dumpfile("lh1_tb.vcd");
      $dumpvars(0, lh1_tb);
      $system("date");
   end

endmodule : lh1_tb