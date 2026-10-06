`include "constants.svh"
`timescale 1ns/1ps

module hazard_forwarding_stall_tb;
    int errors = 0;

    task automatic check(input logic condition, input string name);
        if (!condition) begin
            $display("FAILED: %s", name);
            errors++;
        end
    endtask

    logic [4:0] h_d_rs1, h_d_rs2, h_x_rd;
    logic h_x_memren, h_stall;

    hazard_detection_unit hdu (
        .d_rs1_i(h_d_rs1),
        .d_rs2_i(h_d_rs2),
        .x_rd_i(h_x_rd),
        .x_memren_i(h_x_memren),
        .stall_o(h_stall)
    );

    logic [4:0] f_x_rs1, f_x_rs2, f_m_rd, f_w_rd;
    logic f_m_regwren, f_w_regwren;
    logic [1:0] f_a, f_b;

    forwarding_unit fu (
        .x_rs1_i(f_x_rs1),
        .x_rs2_i(f_x_rs2),
        .m_rd_i(f_m_rd),
        .m_regwren_i(f_m_regwren),
        .w_rd_i(f_w_rd),
        .w_regwren_i(f_w_regwren),
        .forward_a_sel_o(f_a),
        .forward_b_sel_o(f_b)
    );

    logic s_hazard, s_br_jump;
    logic s_pc_en, s_stall, s_flush;
    logic s_idex_en, s_idex_clear, s_exmem_en, s_exmem_clear, s_memwb_en, s_memwb_clear;

    stall_flush_logic sfl (
        .hazard_i(s_hazard),
        .br_jump_i(s_br_jump),
        .pc_en_o(s_pc_en),
        .stall_o(s_stall),
        .flush_o(s_flush),
        .idex_en_o(s_idex_en),
        .idex_clear_o(s_idex_clear),
        .exmem_en_o(s_exmem_en),
        .exmem_clear_o(s_exmem_clear),
        .memwb_en_o(s_memwb_en),
        .memwb_clear_o(s_memwb_clear)
    );

    task automatic hdu_check(input logic [4:0] d_rs1, d_rs2, x_rd, input logic x_memren, expected, input string name);
        h_d_rs1 = d_rs1;
        h_d_rs2 = d_rs2;
        h_x_rd = x_rd;
        h_x_memren = x_memren;
        #1;
        check(h_stall == expected, name);
    endtask

    task automatic fu_check(input logic [4:0] x_rs1, x_rs2, m_rd, w_rd, input logic m_regwren, w_regwren, input logic [1:0] expected_a, expected_b, input string name);
        f_x_rs1 = x_rs1;
        f_x_rs2 = x_rs2;
        f_m_rd = m_rd;
        f_w_rd = w_rd;
        f_m_regwren = m_regwren;
        f_w_regwren = w_regwren;
        #1;
        check((f_a == expected_a) && (f_b == expected_b), name);
    endtask

    initial begin
        hdu_check(5'd1, 5'd2, 5'd0, 1'b0, 1'b0, "hdu no load");
        hdu_check(5'd1, 5'd2, 5'd3, 1'b1, 1'b0, "hdu no match");
        hdu_check(5'd3, 5'd2, 5'd3, 1'b1, 1'b1, "hdu rs1");
        hdu_check(5'd1, 5'd3, 5'd3, 1'b1, 1'b1, "hdu rs2");
        hdu_check(5'd3, 5'd3, 5'd3, 1'b1, 1'b1, "hdu both");
        hdu_check(5'd3, 5'd2, 5'd3, 1'b0, 1'b0, "hdu raw no load");
        hdu_check(5'd0, 5'd2, 5'd0, 1'b1, 1'b0, "hdu x0");

        fu_check(5'd1, 5'd2, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_NONE, `FWD_NONE, "fu none");
        fu_check(5'd3, 5'd9, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_EX_MEM, `FWD_NONE, "fu m rs1");
        fu_check(5'd9, 5'd3, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_NONE, `FWD_EX_MEM, "fu m rs2");
        fu_check(5'd4, 5'd9, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_MEM_WB, `FWD_NONE, "fu w rs1");
        fu_check(5'd9, 5'd4, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_NONE, `FWD_MEM_WB, "fu w rs2");
        fu_check(5'd3, 5'd4, 5'd3, 5'd4, 1'b1, 1'b1, `FWD_EX_MEM, `FWD_MEM_WB, "fu split");
        fu_check(5'd3, 5'd9, 5'd3, 5'd3, 1'b1, 1'b1, `FWD_EX_MEM, `FWD_NONE, "fu priority");
        fu_check(5'd0, 5'd9, 5'd0, 5'd4, 1'b1, 1'b1, `FWD_NONE, `FWD_NONE, "fu x0");
        fu_check(5'd3, 5'd9, 5'd3, 5'd4, 1'b0, 1'b1, `FWD_NONE, `FWD_NONE, "fu m no write");
        fu_check(5'd9, 5'd4, 5'd3, 5'd4, 1'b1, 1'b0, `FWD_NONE, `FWD_NONE, "fu w no write");

        s_hazard = 1'b0;
        s_br_jump = 1'b0;
        #1;
        check(s_pc_en && !s_stall && !s_flush, "sfl idle");
        check(s_idex_en && !s_idex_clear, "sfl idle idex");
        check(s_exmem_en && !s_exmem_clear, "sfl idle exmem");
        check(s_memwb_en && !s_memwb_clear, "sfl idle memwb");

        s_hazard = 1'b1;
        s_br_jump = 1'b0;
        #1;
        check(!s_pc_en && s_stall && !s_flush, "sfl stall");
        check(s_idex_clear, "sfl stall bubble");
        check(s_exmem_en && !s_exmem_clear, "sfl stall exmem");
        check(s_memwb_en && !s_memwb_clear, "sfl stall memwb");

        s_hazard = 1'b0;
        s_br_jump = 1'b1;
        #1;
        check(s_pc_en && !s_stall && s_flush, "sfl flush");
        check(s_idex_clear, "sfl flush bubble");
        check(s_exmem_en && !s_exmem_clear, "sfl flush exmem");
        check(s_memwb_en && !s_memwb_clear, "sfl flush memwb");

        s_hazard = 1'b1;
        s_br_jump = 1'b1;
        #1;
        check(s_pc_en && !s_stall && s_flush, "sfl flush beats stall");
        check(s_idex_clear, "sfl flush hazard bubble");

        if (errors == 0) begin
            $display("hazard_forwarding_stall_tb passed");
        end else begin
            $fatal(1, "hazard_forwarding_stall_tb failed: %0d", errors);
        end
        $finish;
    end
endmodule : hazard_forwarding_stall_tb
