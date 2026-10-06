module hazard_detection_unit (
    input logic [4:0] d_rs1_i,
    input logic [4:0] d_rs2_i,
    input logic [4:0] x_rd_i,
    input logic x_memren_i,
    output logic stall_o
);

    always_comb begin
        stall_o = x_memren_i && (x_rd_i != 5'd0) &&
                  ((x_rd_i == d_rs1_i) || (x_rd_i == d_rs2_i));
    end

endmodule : hazard_detection_unit
