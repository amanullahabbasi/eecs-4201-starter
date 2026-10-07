/*
 * Module: main_memory
 *
 * Description: Byte-addressable memory implementation. Supports both read and write.
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 * 3) AWIDTH instruction address pc_i
 * 4) AWIDTH data address addr_i
 * 5) DWIDTH data to write to memory data_i
 * 6) DWIDTH/8 wide signal to select the byte of the memory block bytelane_i
 * 7) read enable signal memren_i
 * 8) write enable signal memwren_i
 * 9) instruction enable signal insnen_i
 *
 * Outputs:
 * 1) DWIDTH instruction output insn_o
 * 2) DWIDTH data output data_o
 *
 */

`include "constants.svh"

module main_memory #(
    // parameters
    parameter AWIDTH = 32,
    parameter DWIDTH = 32,
    parameter LINECOUNT = 1000,
    parameter BASE_ADDR = 32'h01000000
) (
    // inputs
    input  logic clk,
    input  logic rst,
    input  logic [AWIDTH-1:0] pc_i, // instruction address
    input  logic [AWIDTH-1:0] addr_i,           // address of where to write to memory
    input  logic [DWIDTH-1:0] data_i,           // data to be written to memory
    input  logic [(DWIDTH/8)-1:0] bytelane_i,   // bytelane for 32-bit memory blocks (like RAM)
    input  logic memren_i,                      // read memory enable
    input  logic memwren_i,                     // write memory enable
    input  logic insnen_i,                      // instruction read enable
    // outputs
    output logic [DWIDTH-1:0] insn_o,           // instruction output
    output logic [DWIDTH-1:0] data_o            // read data from memory output
    // ------------------- //
);

    // Word-addressable memory
`ifdef SYNTHESIS
    localparam MEM_BYTES = 1024;
    localparam MEM_WORDS = 256;
`else
    localparam MEM_BYTES = `MEM_DEPTH;
    localparam MEM_WORDS = MEM_BYTES / (DWIDTH/8);
`endif

    logic [DWIDTH-1:0] main_memory [0:MEM_WORDS-1];

`ifndef SYNTHESIS
    // Temporary memory for loading program
    logic [DWIDTH-1:0] temp_memory [0:LINECOUNT - 1];

    // Initialization of memory from program
    initial begin
        string mem_path;
        if ($value$plusargs("MEM_PATH=%s", mem_path))
            $readmemh(mem_path, temp_memory);
        else
            $fatal(1, "MEM_PATH not provided");
        for (int i = 0; i < MEM_WORDS; i++) begin
            if (i < LINECOUNT) begin
                main_memory[i] = temp_memory[i];
            end
            else begin
                main_memory[i] = '0;
            end
        end
        $display("MEMORY: Loaded program");
    end
`endif

    //---------- Instruction Load ----------//
    logic [AWIDTH-1:0] program_counter;
    assign program_counter = (pc_i - BASE_ADDR) >> 2;

    function automatic logic valid_pc(input logic [AWIDTH-1:0] pc);
        valid_pc = (pc >= BASE_ADDR) && (pc + 32'd3 < BASE_ADDR + MEM_BYTES);
    endfunction

    function automatic logic [DWIDTH-1:0] instruction_read(
        input logic [AWIDTH-1:0] pc,
        input logic [AWIDTH-1:0] word_index
    );
        instruction_read = '0;
        if (!rst && insnen_i && valid_pc(pc)) instruction_read = main_memory[word_index];
`ifndef SYNTHESIS
        else if (!rst && insnen_i && !$isunknown(pc)) instruction_read = 32'hDEAD_BEEF;
`else
        else if (!rst && insnen_i) instruction_read = 32'hDEAD_BEEF;
`endif
    endfunction

    always_comb begin
        insn_o = instruction_read(pc_i, program_counter);
    end

    // Shift byte address from memory controller to word index for memory
    logic [AWIDTH-1:0] address;
    assign address = addr_i >> 2;

    function automatic logic [DWIDTH-1:0] data_read(
        input logic [AWIDTH-1:0] word_index
    );
        data_read = '0;
`ifndef SYNTHESIS
        if (!rst && memren_i && !$isunknown(word_index)) data_read = main_memory[word_index];
`else
        if (!rst && memren_i) data_read = main_memory[word_index];
`endif
    endfunction

    always_comb begin
        data_o = data_read(address);
    end

    //---------- Memory Data Write ----------//
    always_ff @(posedge clk) begin
        if (memwren_i) begin
            for (int i = 0; i < (DWIDTH/8); i++) begin
                if (bytelane_i[i]) main_memory[address][(i*8) +: 8] <= data_i[(i*8) +: 8];
            end
        end
    end

endmodule : main_memory
