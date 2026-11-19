/*
 * Module: memory controller
 *
 * Description: Byte-addressable memory controller. Masks data
                to/from pipeline and data  to/from memory.
 *
 * Inputs:
 * 1) Reset signal rst
 * 2) AWIDTH raw address for data memory read/write addr_i
 * 3) DWIDTH data to write data_i
 * 4) DWIDTH data to mask mem_data_i
 * 5) byte mask for w, hw, b, funct3_i
 * 6) read enable signal memren_i
 * 7) write enable signal memwren_i
 * 8) AWIDTH address word algined for data memory write waddr_o
 * 9) DWIDTH data write to memory, byte spliced and extended wdata_o
 *10) DWIDTH data read from memory, spliced and extended rdata_o
 *11) DWIDTH/8 signal to select byte lane byteen_o
 *
 * Outputs:
 * 1) AWIDTH address output waddr_o
 * 2) DWIDTH data output data_o
 */

`include "constants.svh"

module memory_controller #(
    // parameters
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32,
    parameter int OWIDTH = 2,
    parameter logic [AWIDTH-1:0] BASE_ADDR = 32'h0100_0000
 ) (
    input  logic rst,
    // raw address for memory reads and writes
    input  logic [AWIDTH-1:0] addr_i,
    // raw data to write to memory
    input  logic [DWIDTH-1:0] data_i,
    // raw data read from memory
    input  logic [DWIDTH-1:0] mem_data_i,
    // for determining size of memory reads/writes
    input  logic [2:0] funct3_i,
    // memory read enable signal
    input  logic memren_i,
    // memory write enable signal
    input  logic memwren_i,
    // data address
    output logic [AWIDTH-1:0] waddr_o,
    // spliced data to write to memory
    output logic [DWIDTH-1:0] wdata_o,
    // masked data
    output logic [DWIDTH-1:0] rdata_o,
    // byte enabled signal for choosing the correct byte lane in ram
    output logic [(DWIDTH/8)-1:0] byteen_o

 );

    //---------- Word algined address ----------//
    logic [AWIDTH-1:0] address;
    assign address = (addr_i - BASE_ADDR);
    assign waddr_o = {address[AWIDTH-1:OWIDTH], {OWIDTH{1'b0}}};


    //---------- Byte offset for data input/output ----------//
    logic [OWIDTH-1:0] byte_offset;
    assign byte_offset = address[OWIDTH-1:0];

    //---------- Data Read ----------//
    logic [DWIDTH-1:0] shifted_data;
    assign shifted_data = mem_data_i >> (byte_offset * 8);

    function automatic logic [DWIDTH-1:0] read_data(
        input logic [DWIDTH-1:0] shifted,
        input logic [2:0] funct3
    );
        case (funct3)
            `F3_LB  : read_data = {{(DWIDTH-8){shifted[7]}}, shifted[7:0]};
            `F3_LBU : read_data = {{(DWIDTH-8){1'b0}}, shifted[7:0]};
            `F3_LH  : read_data = {{(DWIDTH-16){shifted[15]}}, shifted[15:0]};
            `F3_LHU : read_data = {{(DWIDTH-16){1'b0}}, shifted[15:0]};
            default : read_data = shifted;
        endcase
    endfunction

    function automatic logic [(DWIDTH/8)-1:0] write_byte_enable(
        input logic [2:0] funct3,
        input logic [OWIDTH-1:0] offset
    );
        case (funct3)
            `F3_SB : write_byte_enable = {{(DWIDTH/8-1){1'b0}}, 1'b1} << offset;
            `F3_SH : write_byte_enable = {{(DWIDTH/8-2){1'b0}}, 2'b11} << offset;
            `F3_SW : write_byte_enable = {{(DWIDTH/8-4){1'b0}}, 4'b1111} << offset;
            default: write_byte_enable = '0;
        endcase
    endfunction

    function automatic logic [DWIDTH-1:0] write_data(
        input logic [DWIDTH-1:0] data,
        input logic [2:0] funct3
    );
        case (funct3)
            `F3_SB : write_data = {(DWIDTH/8){data[7:0]}};
            `F3_SH : write_data = {(DWIDTH/16){data[15:0]}};
            `F3_SW : write_data = {(DWIDTH/32){data[31:0]}};
            default: write_data = '0;
        endcase
    endfunction

    always_comb begin
        rdata_o = (!rst && memren_i) ? read_data(shifted_data, funct3_i) : '0;
    end

    always_comb begin
        byteen_o = memwren_i ? write_byte_enable(funct3_i, byte_offset) : '0;
        wdata_o = memwren_i ? write_data(data_i, funct3_i) : '0;
    end

endmodule : memory_controller
