// Empty stand-ins for the modules our teammates are still writing
// (decode, igen, control, alu, writeback). Only used so lh1_tb and lh5_tb
// can compile before the other logic holes are done.
module decode #(parameter int DWIDTH=32, parameter int AWIDTH=32)(
    input logic clk, input logic rst,
    input logic [DWIDTH-1:0] insn_i, input logic [AWIDTH-1:0] pc_i,
    output logic [AWIDTH-1:0] pc_o, output logic [DWIDTH-1:0] insn_o,
    output logic [6:0] opcode_o, output logic [4:0] rd_o,
    output logic [4:0] rs1_o, output logic [4:0] rs2_o,
    output logic [6:0] funct7_o, output logic [2:0] funct3_o,
    output logic [4:0] shamt_o, output logic [DWIDTH-1:0] imm_o);
endmodule

module igen #(parameter int DWIDTH=32)(
    input logic [6:0] opcode_i, input logic [DWIDTH-1:0] insn_i,
    output logic [DWIDTH-1:0] imm_o);
endmodule

module control #(parameter int DWIDTH=32)(
    input logic [DWIDTH-1:0] insn_i, input logic [6:0] opcode_i,
    input logic [6:0] funct7_i, input logic [2:0] funct3_i,
    output logic pcsel_o, output logic immsel_o, output logic regwren_o,
    output logic rs1sel_o, output logic rs2sel_o, output logic memren_o,
    output logic memwren_o, output logic [1:0] wbsel_o, output logic [3:0] alusel_o);
endmodule

module alu #(parameter int DWIDTH=32, parameter int AWIDTH=32)(
    input logic [AWIDTH-1:0] pc_i, input logic [DWIDTH-1:0] rs1_i,
    input logic [DWIDTH-1:0] rs2_i, input logic [2:0] funct3_i,
    input logic [6:0] funct7_i, input logic [6:0] opcode_i,
    input logic [DWIDTH-1:0] imm_i, input logic [3:0] alusel_i,
    output logic [DWIDTH-1:0] res_o, output logic brtaken_o);
endmodule

module writeback #(parameter int DWIDTH=32, parameter int AWIDTH=32)(
    input logic [AWIDTH-1:0] pc_i, input logic [DWIDTH-1:0] alu_res_i,
    input logic [DWIDTH-1:0] memory_data_i, input logic [1:0] wbsel_i,
    input logic [DWIDTH-1:0] imm_i, output logic [DWIDTH-1:0] writeback_data_o);
endmodule