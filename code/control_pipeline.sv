`include "constants.svh"

module control_pipeline (
    input logic clk,
    input logic rst,

    input logic idex_en_i,
    input logic idex_clear_i,
    input logic exmem_en_i,
    input logic exmem_clear_i,
    input logic memwb_en_i,
    input logic memwb_clear_i,

    input logic pcsel_i,
    input logic immsel_i,
    input logic regwren_i,
    input logic rs1sel_i,
    input logic rs2sel_i,
    input logic memren_i,
    input logic memwren_i,
    input logic [1:0] wbsel_i,
    input logic [3:0] alusel_i,

    output logic x_pcsel_o,
    output logic x_immsel_o,
    output logic x_regwren_o,
    output logic x_rs1sel_o,
    output logic x_rs2sel_o,
    output logic x_memren_o,
    output logic x_memwren_o,
    output logic [1:0] x_wbsel_o,
    output logic [3:0] x_alusel_o,

    output logic m_regwren_o,
    output logic m_memren_o,
    output logic m_memwren_o,
    output logic [1:0] m_wbsel_o,

    output logic w_regwren_o,
    output logic [1:0] w_wbsel_o
);

    logic [12:0] d_ctrl;
    logic [12:0] x_ctrl;
    logic [12:0] m_ctrl;
    logic [12:0] w_ctrl;

    always_comb begin
        d_ctrl = '0;
        d_ctrl[`PCSEL] = pcsel_i;
        d_ctrl[`IMMSEL] = immsel_i;
        d_ctrl[`REGWREN] = regwren_i;
        d_ctrl[`RS1SEL] = rs1sel_i;
        d_ctrl[`RS2SEL] = rs2sel_i;
        d_ctrl[`MEMREN] = memren_i;
        d_ctrl[`MEMWREN] = memwren_i;
        d_ctrl[`WBSEL] = wbsel_i;
        d_ctrl[`ALUSEL] = alusel_i;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            x_ctrl <= '0;
            m_ctrl <= '0;
            w_ctrl <= '0;
        end else begin
            if (idex_clear_i) begin
                x_ctrl <= '0;
            end else if (idex_en_i) begin
                x_ctrl <= d_ctrl;
            end

            if (exmem_clear_i) begin
                m_ctrl <= '0;
            end else if (exmem_en_i) begin
                m_ctrl <= x_ctrl;
            end

            if (memwb_clear_i) begin
                w_ctrl <= '0;
            end else if (memwb_en_i) begin
                w_ctrl <= m_ctrl;
            end
        end
    end

    assign x_pcsel_o = x_ctrl[`PCSEL];
    assign x_immsel_o = x_ctrl[`IMMSEL];
    assign x_regwren_o = x_ctrl[`REGWREN];
    assign x_rs1sel_o = x_ctrl[`RS1SEL];
    assign x_rs2sel_o = x_ctrl[`RS2SEL];
    assign x_memren_o = x_ctrl[`MEMREN];
    assign x_memwren_o = x_ctrl[`MEMWREN];
    assign x_wbsel_o = x_ctrl[`WBSEL];
    assign x_alusel_o = x_ctrl[`ALUSEL];

    assign m_regwren_o = m_ctrl[`REGWREN];
    assign m_memren_o = m_ctrl[`MEMREN];
    assign m_memwren_o = m_ctrl[`MEMWREN];
    assign m_wbsel_o = m_ctrl[`WBSEL];

    assign w_regwren_o = w_ctrl[`REGWREN];
    assign w_wbsel_o = w_ctrl[`WBSEL];

endmodule : control_pipeline
