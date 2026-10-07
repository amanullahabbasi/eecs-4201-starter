/*
 * Module: writeback
 *
 * Description: Write-back control stage implementation
 *
 * Inputs:
 * 1) PC pc_i
 * 2) result from alu alu_res_i
 * 3) data from memory memory_data_i
 * 4) data to select for write-back wbsel_i
 * 5) branch taken signal brtaken_i
 *
 * Outputs:
 * 1) DWIDTH wide write back data write_data_o
 */
`include "constants.svh"

 module writeback #(
     parameter int DWIDTH=32,
     parameter int AWIDTH=32
 )(
     input logic [AWIDTH-1:0] pc_i,
     input logic [DWIDTH-1:0] alu_res_i,
     input logic [DWIDTH-1:0] memory_data_i,
     input logic [1:0] wbsel_i,
     input logic [DWIDTH-1:0] imm_i,
     output logic [DWIDTH-1:0] writeback_data_o
 );
    function automatic logic [DWIDTH-1:0] writeback_data(
        input logic [1:0] wbsel,
        input logic [AWIDTH-1:0] pc,
        input logic [DWIDTH-1:0] alu_res,
        input logic [DWIDTH-1:0] memory_data,
        input logic [DWIDTH-1:0] imm
    );
        case (wbsel)
            `WB_ALU: writeback_data = alu_res;
            `WB_MEM: writeback_data = memory_data;
            `WB_PC4: writeback_data = pc + 32'd4;
            `WB_IMM: writeback_data = imm;
            default: writeback_data = alu_res;
        endcase
    endfunction

    always_comb begin
        writeback_data_o = writeback_data(wbsel_i, pc_i, alu_res_i, memory_data_i, imm_i);
    end

endmodule : writeback
