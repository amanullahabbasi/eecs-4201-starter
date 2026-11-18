module stall_flush_logic (
   input logic hazard_i,
   input logic m_wait_i,        // 1 while Execute waits for an M answer
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

    // Advance the PC only when neither a hazard nor an M operation needs a wait
    // A taken branch/jump keeps its existing priority
    assign pc_en_o = br_jump_i || !(hazard_i || m_wait_i);

    // Hold Fetch/Decode while waiting, unless a branch/jump redirects execution
    assign stall_o = (hazard_i || m_wait_i) && !br_jump_i;

    assign flush_o = br_jump_i;


    // Keep the current instruction in Execute while its M answer is pending
    assign idex_en_o = !m_wait_i;

    // A load-use hazard inserts a bubble; an M wait must preserve the instruction
    assign idex_clear_o = br_jump_i || (hazard_i && !m_wait_i);


    assign exmem_en_o = 1'b1;

    // Send a bubble into EX/MEM while the M answer is unfinished.
    assign exmem_clear_o = m_wait_i;


    assign memwb_en_o = 1'b1;
    assign memwb_clear_o = 1'b0;

endmodule: stall_flush_logic
