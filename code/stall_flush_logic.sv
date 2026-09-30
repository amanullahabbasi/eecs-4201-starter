/*
 * Module: stall_flush_logic
 *
 * Description: Stall and flush logic
 *
 * Inputs:
 * 1) hazard_i
 * 2) br_jump_i
 * Outputs:
 * 1) pc_en_o -- Signal to determine whether to stall fetch
 * 2) stall_o -- Signal to determine whether to stall pipeline
 * 3) flush_o -- Signal to determine whether to flush pipeline
 */


// Stall Logic Module
module stall_flush_logic (
   input logic hazard_i,
   input logic br_jump_i,
   output logic pc_en_o,
   output logic stall_o,
   output logic flush_o,
   output logic idex_en_o,
   output logic idex_clear_o,
   output logic exmem_en_o,
   output logic exmem_clear_o,
   output logic memwb_en_o,
   output logic memwb_clear_o
);

    assign pc_en_o = !hazard_i;
    assign stall_o = hazard_i;
    assign flush_o = br_jump_i;

    assign idex_en_o = 1'b1;
    assign idex_clear_o = hazard_i || br_jump_i;

    assign exmem_en_o = 1'b1;
    assign exmem_clear_o = 1'b0;

    assign memwb_en_o = 1'b1;
    assign memwb_clear_o = 1'b0;

endmodule: stall_flush_logic
