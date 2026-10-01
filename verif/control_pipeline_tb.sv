`timescale 1ns/1ps
`include "constants.svh"

module control_pipeline_tb;
    logic clk;
    logic rst;
    logic idex_en;
    logic idex_clear;
    logic exmem_en;
    logic exmem_clear;
    logic memwb_en;
    logic memwb_clear;
    logic pcsel;
    logic immsel;
    logic regwren;
    logic rs1sel;
    logic rs2sel;
    logic memren;
    logic memwren;
    logic [1:0] wbsel;
    logic [3:0] alusel;
    logic x_pcsel;
    logic x_immsel;
    logic x_regwren;
    logic x_rs1sel;
    logic x_rs2sel;
    logic x_memren;
    logic x_memwren;
    logic [1:0] x_wbsel;
    logic [3:0] x_alusel;
    logic m_regwren;
    logic m_memren;
    logic m_memwren;
    logic [1:0] m_wbsel;
    logic w_regwren;
    logic [1:0] w_wbsel;

    control_pipeline dut (
        .clk(clk),
        .rst(rst),
        .idex_en_i(idex_en),
        .idex_clear_i(idex_clear),
        .exmem_en_i(exmem_en),
        .exmem_clear_i(exmem_clear),
        .memwb_en_i(memwb_en),
        .memwb_clear_i(memwb_clear),
        .pcsel_i(pcsel),
        .immsel_i(immsel),
        .regwren_i(regwren),
        .rs1sel_i(rs1sel),
        .rs2sel_i(rs2sel),
        .memren_i(memren),
        .memwren_i(memwren),
        .wbsel_i(wbsel),
        .alusel_i(alusel),
        .x_pcsel_o(x_pcsel),
        .x_immsel_o(x_immsel),
        .x_regwren_o(x_regwren),
        .x_rs1sel_o(x_rs1sel),
        .x_rs2sel_o(x_rs2sel),
        .x_memren_o(x_memren),
        .x_memwren_o(x_memwren),
        .x_wbsel_o(x_wbsel),
        .x_alusel_o(x_alusel),
        .m_regwren_o(m_regwren),
        .m_memren_o(m_memren),
        .m_memwren_o(m_memwren),
        .m_wbsel_o(m_wbsel),
        .w_regwren_o(w_regwren),
        .w_wbsel_o(w_wbsel)
    );

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string name);
        if (!condition) begin
            $fatal(1, "%s", name);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        idex_en = 1'b1;
        idex_clear = 1'b0;
        exmem_en = 1'b1;
        exmem_clear = 1'b0;
        memwb_en = 1'b1;
        memwb_clear = 1'b0;
        pcsel = 1'b0;
        immsel = 1'b0;
        regwren = 1'b0;
        rs1sel = 1'b0;
        rs2sel = 1'b0;
        memren = 1'b0;
        memwren = 1'b0;
        wbsel = `WB_ALU;
        alusel = `ALU_NOP;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        regwren = 1'b1;
        wbsel = `WB_ALU;
        alusel = `ALU_ADD;

        @(posedge clk);
        #1;
        check(x_regwren && x_wbsel == `WB_ALU && x_alusel == `ALU_ADD, "idex load");
        check(!m_regwren && !w_regwren, "later stages empty");

        @(posedge clk);
        #1;
        check(m_regwren && m_wbsel == `WB_ALU, "exmem load");
        check(!w_regwren, "memwb still empty");

        @(posedge clk);
        #1;
        check(w_regwren && w_wbsel == `WB_ALU, "memwb load");

        @(negedge clk);
        regwren = 1'b1;
        memren = 1'b1;
        wbsel = `WB_MEM;
        alusel = `ALU_ADD;
        idex_clear = 1'b1;

        @(posedge clk);
        #1;
        check(!x_regwren && !x_memren && !x_memwren, "idex clear");

        @(negedge clk);
        idex_clear = 1'b0;
        memren = 1'b0;
        memwren = 1'b1;
        regwren = 1'b0;
        idex_en = 1'b1;

        @(posedge clk);
        #1;
        check(x_memwren && !x_regwren, "idex store control");

        @(negedge clk);
        idex_en = 1'b0;
        memwren = 1'b0;
        regwren = 1'b1;

        @(posedge clk);
        #1;
        check(x_memwren && !x_regwren, "idex hold");

        @(negedge clk);
        exmem_clear = 1'b1;

        @(posedge clk);
        #1;
        check(!m_regwren && !m_memren && !m_memwren, "exmem clear");

        @(negedge clk);
        exmem_clear = 1'b0;
        memwb_clear = 1'b1;

        @(posedge clk);
        #1;
        check(!w_regwren, "memwb clear");

        $display("control_pipeline_tb passed");
        $finish;
    end
endmodule
