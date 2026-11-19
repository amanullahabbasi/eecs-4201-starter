/*
 * Module: stall_flush_logic
 *
 * Description: Pipeline register enables and clears for the three hazard
 *              types. The three requests never occur together: a load-use
 *              hazard needs a load in execute, a redirect needs a branch/jump
 *              in execute, and an MDU stall needs an M instruction in execute.
 *              1) Load-use hazard: hold PC and IF/ID, insert a bubble into ID/EX.
 *              2) Taken branch/jump: flush IF/ID and ID/EX (2 wrong-path instructions).
 *              3) Multi-cycle M instruction: hold PC, IF/ID and ID/EX (the operation stays
 *                 in execute) and insert bubbles into EX/MEM.
 *
 * Inputs:
 * 1) 1-bit load-use hazard hazard_i
 * 2) 1-bit taken branch or jump br_jump_i
 * 3) 1-bit multiply/divide wait request mdu_stall_i
 *
 * Outputs:
 * 1) 1-bit PC enable pc_en_o
 * 2) 1-bit IF/ID hold stall_o
 * 3) 1-bit IF/ID flush flush_o
 * 4) enable/clear for the ID/EX, EX/MEM and MEM/WB registers
 */
module stall_flush_logic (
   input logic hazard_i,
   input logic br_jump_i,
   input logic mdu_stall_i,
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

    // Branch redirects override pipeline stalls.
    assign pc_en_o = br_jump_i || !(hazard_i || mdu_stall_i);
    // Freeze fetch/decode during a stall.
    assign stall_o = (hazard_i || mdu_stall_i) && !br_jump_i;
    // Discard incorrectly fetched branch path.
    assign flush_o = br_jump_i;

    // Keep active multiply/divide in execute.
    assign idex_en_o = !mdu_stall_i;
    // Insert bubble after load or branch.
    assign idex_clear_o = (hazard_i || br_jump_i) && !mdu_stall_i;

    // Allow older instructions to drain.
    assign exmem_en_o = 1'b1;
    // Prevent unfinished result entering memory.
    assign exmem_clear_o = mdu_stall_i;

    // Complete older writeback operations normally.
    assign memwb_en_o = 1'b1;
    // Never erase pending writeback data.
    assign memwb_clear_o = 1'b0;

endmodule: stall_flush_logic
