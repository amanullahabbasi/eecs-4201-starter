/*
 * Testbench: mul_unit_tb
 *
 * Description: Self-checking test of the RV32M multiplier (mul_unit.sv).
 *              Every result is compared against a 64-bit golden model
 *              (mul_ref). Directed vectors are also compared against
 *              hand-written expected values, so a mistake in either the model
 *              or the table shows up as a failure.
 *              1) Trivial cases: one simple vector per instruction
 *              2) Sign combinations for the signed/unsigned variants
 *              3) Corner cases: INT_MIN, INT_MAX, -1, zero, identity, carries
 *                 into the upper half, MULHSU operand asymmetry
 *              4) Back-to-back sequence: operation changes every cycle with the
 *                 same operands (the result must follow funct3 immediately)
 *              5) Uniform random and corner-biased random vectors
 *
 * Run: make tb-mul_unit_tb -C verif/
 */

`include "constants.svh"
`timescale 1ns/1ps

`ifndef NUM_RANDOM
  `define NUM_RANDOM 10000
`endif

module mul_unit_tb;

    localparam int DWIDTH = 32;

    logic [2:0] funct3;                          // operation select
    logic [DWIDTH-1:0] rs1, rs2;                 // operands
    logic [DWIDTH-1:0] result;                   // DUT result

    int errors = 0;                              // failed checks
    int checks = 0;                              // total checks

    mul_unit #(
        .DWIDTH(DWIDTH)
    ) dut (
        .funct3_i(funct3),
        .rs1_i(rs1),
        .rs2_i(rs2),
        .result_o(result)
    );

    // Golden model: 64-bit products with explicit sign handling per operation
    function automatic logic [31:0] mul_ref(input logic [2:0] f3,
                                            input logic [31:0] a,
                                            input logic [31:0] b);
        logic signed [63:0] sa, sb, ub_s;
        logic [63:0] ua, ub;
        sa = $signed({{32{a[31]}}, a});
        sb = $signed({{32{b[31]}}, b});
        ub_s = $signed({32'b0, b});              // rs2 as unsigned, for MULHSU
        ua = {32'b0, a};
        ub = {32'b0, b};
        case (f3)
            `F3_MUL:    return a * b;
            `F3_MULH:   return 32'((sa * sb) >>> 32);
            `F3_MULHSU: return 32'((sa * ub_s) >>> 32);
            default:    return 32'((ua * ub) >> 32);     // MULHU
        endcase
    endfunction

    // Mnemonic for failure messages
    function automatic string op_name(input logic [2:0] f3);
        case (f3)
            `F3_MUL:    return "MUL";
            `F3_MULH:   return "MULH";
            `F3_MULHSU: return "MULHSU";
            default:    return "MULHU";
        endcase
    endfunction

    // Operand biased towards values that hit corner cases (about half the time)
    function automatic logic [31:0] biased_operand();
        case ($urandom_range(13, 0))
            0:       return '0;
            1:       return 32'd1;
            2:       return '1;                                 // -1
            3:       return 32'h7FFF_FFFF;                      // INT_MAX
            4:       return 32'h8000_0000;                      // INT_MIN
            5:       return 32'd1 << $urandom_range(31, 0);     // power of two
            6:       return (32'd1 << $urandom_range(31, 0)) - 32'd1;
            default: return $urandom();
        endcase
    endfunction

    // Apply one vector and compare the DUT with the golden model
    task automatic check_op(input logic [2:0] f3, input logic [31:0] a,
                            input logic [31:0] b, input string name);
        logic [31:0] expected;
        funct3 = f3;
        rs1 = a;
        rs2 = b;
        #1;
        expected = mul_ref(f3, a, b);
        checks++;
        if (result !== expected) begin
            errors++;
            $display("FAIL %s: %s rs1=%h rs2=%h got=%h expected=%h",
                     name, op_name(f3), a, b, result, expected);
        end
    endtask

    // Directed vector: also checks the golden model against the hand-written value
    task automatic check_dir(input logic [2:0] f3, input logic [31:0] a,
                             input logic [31:0] b, input logic [31:0] expected,
                             input string name);
        if (mul_ref(f3, a, b) !== expected) begin
            errors++;
            $display("FAIL %s: table says %h but model says %h",
                     name, expected, mul_ref(f3, a, b));
        end
        check_op(f3, a, b, name);
    endtask

    initial begin
        // 1) Trivial cases
        check_dir(`F3_MUL,    32'd7, 32'd6, 32'd42, "base mul");
        check_dir(`F3_MULH,   32'd7, 32'd6, 32'd0,  "base mulh");
        check_dir(`F3_MULHSU, 32'd7, 32'd6, 32'd0,  "base mulhsu");
        check_dir(`F3_MULHU,  32'd7, 32'd6, 32'd0,  "base mulhu");

        // 2) Sign combinations
        check_dir(`F3_MUL,    -32'sd7, 32'd6,   32'hFFFF_FFD6, "mul -+");
        check_dir(`F3_MUL,    32'd7,   -32'sd6, 32'hFFFF_FFD6, "mul +-");
        check_dir(`F3_MUL,    -32'sd7, -32'sd6, 32'd42,        "mul --");
        check_dir(`F3_MULH,   -32'sd7, 32'd6,   32'hFFFF_FFFF, "mulh -+");
        check_dir(`F3_MULH,   -32'sd7, -32'sd6, 32'd0,         "mulh --");
        check_dir(`F3_MULHU,  32'hFFFF_FFF9, 32'd6, 32'h0000_0005, "mulhu big*small");
        check_dir(`F3_MULHSU, -32'sd7, 32'd6,   32'hFFFF_FFFF, "mulhsu -+");

        // 3) Corner cases
        check_dir(`F3_MUL,    32'h8000_0000, 32'h8000_0000, 32'd0,         "mul min*min");
        check_dir(`F3_MULH,   32'h8000_0000, 32'h8000_0000, 32'h4000_0000, "mulh min*min");
        check_dir(`F3_MULHU,  32'h8000_0000, 32'h8000_0000, 32'h4000_0000, "mulhu min*min");
        check_dir(`F3_MULHSU, 32'h8000_0000, 32'h8000_0000, 32'hC000_0000, "mulhsu min*min");
        check_dir(`F3_MUL,    32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd1,         "mul -1*-1");
        check_dir(`F3_MULH,   32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd0,         "mulh -1*-1");
        check_dir(`F3_MULHU,  32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFE, "mulhu max*max");
        check_dir(`F3_MULHSU, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF, "mulhsu -1*max");
        check_dir(`F3_MUL,    32'h7FFF_FFFF, 32'h7FFF_FFFF, 32'd1,         "mul intmax^2");
        check_dir(`F3_MULH,   32'h7FFF_FFFF, 32'h7FFF_FFFF, 32'h3FFF_FFFF, "mulh intmax^2");
        check_dir(`F3_MULH,   32'h8000_0000, 32'h7FFF_FFFF, 32'hC000_0000, "mulh min*max");
        check_dir(`F3_MULHSU, 32'hFFFF_FFFF, 32'd2,         32'hFFFF_FFFF, "mulhsu asymmetry a");
        check_dir(`F3_MULHSU, 32'd2,         32'hFFFF_FFFF, 32'h0000_0001, "mulhsu asymmetry b");
        check_dir(`F3_MUL,    32'h0001_0000, 32'h0001_0000, 32'd0,         "mul carry into upper half");
        check_dir(`F3_MULHU,  32'h0001_0000, 32'h0001_0000, 32'd1,         "mulhu carry into upper half");
        check_dir(`F3_MUL,    32'h0000_FFFF, 32'h0000_FFFF, 32'hFFFE_0001, "mul 16-bit max squared");
        check_dir(`F3_MUL,    32'h1234_5678, 32'd1,         32'h1234_5678, "mul identity");
        check_dir(`F3_MUL,    32'h1234_5678, 32'd0,         32'd0,         "mul zero");
        check_dir(`F3_MULH,   32'h1234_5678, 32'd0,         32'd0,         "mulh zero");
        check_dir(`F3_MULHU,  32'h1234_5678, 32'd1,         32'd0,         "mulhu identity high half");

        // 4) Back-to-back: same operands, operation changes every cycle
        for (int op = 0; op < 4; op++) begin
            check_op(3'(op), 32'hDEAD_BEEF, 32'hCAFE_F00D, "back-to-back");
        end
        for (int op = 3; op >= 0; op--) begin
            check_op(3'(op), 32'h8000_0001, 32'hFFFF_FFFE, "back-to-back reverse");
        end

        // 5) Random vectors for every operation
        for (int op = 0; op < 4; op++) begin
            for (int i = 0; i < `NUM_RANDOM; i++) begin
                check_op(3'(op), $urandom(), $urandom(), "uniform random");
                check_op(3'(op), biased_operand(), biased_operand(), "biased random");
            end
        end

        $display("=========================================");
        $display("mul_unit_tb: %0d checks, %0d errors", checks, errors);
        $display("=========================================");
        if (errors == 0) begin
            $display("mul_unit_tb passed");
        end
        else begin
            $fatal(1, "mul_unit_tb failed: %0d errors", errors);
        end
        $finish;
    end

endmodule : mul_unit_tb
