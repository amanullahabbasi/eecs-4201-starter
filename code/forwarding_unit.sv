`include "constants.svh"

module forwarding_unit (
    input logic [4:0] x_rs1_i,
    input logic [4:0] x_rs2_i,
    input logic [4:0] m_rd_i,
    input logic m_regwren_i,
    input logic [4:0] w_rd_i,
    input logic w_regwren_i,
    output logic [1:0] forward_a_sel_o,
    output logic [1:0] forward_b_sel_o
);

    always_comb begin
        if (m_regwren_i && (m_rd_i != 5'd0) && (m_rd_i == x_rs1_i)) begin
            forward_a_sel_o = `FWD_EX_MEM;
        end else if (w_regwren_i && (w_rd_i != 5'd0) && (w_rd_i == x_rs1_i)) begin
            forward_a_sel_o = `FWD_MEM_WB;
        end else begin
            forward_a_sel_o = `FWD_NONE;
        end
    end

    always_comb begin
        if (m_regwren_i && (m_rd_i != 5'd0) && (m_rd_i == x_rs2_i)) begin
            forward_b_sel_o = `FWD_EX_MEM;
        end else if (w_regwren_i && (w_rd_i != 5'd0) && (w_rd_i == x_rs2_i)) begin
            forward_b_sel_o = `FWD_MEM_WB;
        end else begin
            forward_b_sel_o = `FWD_NONE;
        end
    end

endmodule : forwarding_unit
