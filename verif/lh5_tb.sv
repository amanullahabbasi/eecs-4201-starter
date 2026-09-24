`include "constants.svh"

`timescale 1ns/1ps

`ifndef TIMEOUT
  `define TIMEOUT 32'd50
`endif

`ifndef RESET_CYCLES
  `define RESET_CYCLES 2
`endif

module lh5_tb;

   logic clk = 0;
   logic rst = 1;
   always #1 clk = ~clk;

   localparam int DWIDTH = 32;
   localparam int AWIDTH = 32;

    /*
     * LH5 test: checks the ALU input muxes (alu_A, mux_B, alu_B) in rv_core.
     * The other logic holes aren't done yet, so we force the control signals,
     * register values and immediate to fixed values and only check our outputs.
     */

    rv_core #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH)
    ) hut (
        .clk(clk),
        .reset(rst)
    );

    int errors = 0;

    initial begin
        // fixed test values for rs1, rs2 and the immediate
        force hut.r_rs1data = 32'h11111111;
        force hut.r_rs2data = 32'h22222222;
        force hut.d_imm     = 32'h00000008;
        // no jumps so the pc just counts up
        force hut.c_pcsel   = 1'b0;
        force hut.e_brtaken = 1'b0;

        wait (!rst);

        // Test 1: R-type / branch -> alu_A = rs1, alu_B = rs2
        force hut.c_rs1sel = 1'b0;
        force hut.c_rs2sel = 1'b0;
        @(negedge clk);
        if (hut.alu_A != 32'h11111111 || hut.alu_B != 32'h22222222) begin
            $display("Test 1 FAILED: alu_A=%h alu_B=%h", hut.alu_A, hut.alu_B);
            errors++;
        end

        // Test 2: addi / load / store / jalr -> alu_A = rs1, alu_B = imm
        force hut.c_rs1sel = 1'b0;
        force hut.c_rs2sel = 1'b1;
        @(negedge clk);
        if (hut.alu_A != 32'h11111111 || hut.alu_B != 32'h00000008) begin
            $display("Test 2 FAILED: alu_A=%h alu_B=%h", hut.alu_A, hut.alu_B);
            errors++;
        end

        // Test 3: jal / auipc -> alu_A = pc, alu_B = imm
        force hut.c_rs1sel = 1'b1;
        force hut.c_rs2sel = 1'b1;
        @(negedge clk);
        if (hut.alu_A != hut.pc || hut.alu_B != 32'h00000008) begin
            $display("Test 3 FAILED: alu_A=%h (pc=%h) alu_B=%h", hut.alu_A, hut.pc, hut.alu_B);
            errors++;
        end

        // Test 4: mux_B should always be rs2 (store data)
        if (hut.mux_B != 32'h22222222) begin
            $display("Test 4 FAILED: mux_B=%h", hut.mux_B);
            errors++;
        end

        $display("=========================================");
        if (errors == 0)
            $display("LH5: All tests passed");
        else
            $display("LH5: %0d tests failed", errors);
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
      $dumpfile("lh5_tb.vcd");
      $dumpvars(0, lh5_tb);
      $system("date");
   end

endmodule : lh5_tb