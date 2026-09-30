/*
 * Module: control
 *
 * Description: This module sets the control bits (control path) based on the decoded
 * instruction. Note that this is part of the decode stage but housed in a separate
 * module for better readability, debug and design purposes.
 *
 * Inputs:
 * 1) DWIDTH instruction ins_i
 * 2) 7-bit opcode opcode_i
 * 3) 7-bit funct7 funct7_i
 * 4) 3-bit funct3 funct3_i
 *
 * Outputs:
 * 1) 1-bit PC select pcsel_o
 * 2) 1-bit Immediate select immsel_o
 * 3) 1-bit register write en regwren_o
 * 4) 1-bit rs1 select rs1sel_o
 * 5) 1-bit rs2 select rs2sel_o
 * 6) k-bit ALU select alusel_o
 * 7) 1-bit memory read en memren_o
 * 8) 1-bit memory write en memwren_o
 * 9) 2-bit writeback sel wbsel_o
 */

`include "constants.svh"

module control #(
	parameter int DWIDTH=32
)(
	// inputs
    input logic [DWIDTH-1:0] insn_i,
    input logic [6:0] opcode_i,
    input logic [6:0] funct7_i,
    input logic [2:0] funct3_i,

    // outputs
    output logic pcsel_o,
    output logic immsel_o,
    output logic regwren_o,
    output logic rs1sel_o,
    output logic rs2sel_o,
    output logic memren_o,
    output logic memwren_o,
    output logic [1:0] wbsel_o,
    output logic [3:0] alusel_o
);

/* Logic hole 4 (LH4): Complete the control path. This is a key logic module
                       that is crucial for correctness. Pay close attention to
                       this logic.
*/

    always_comb begin
        pcsel_o   = 1'b0;
        immsel_o  = 1'b0;
        regwren_o = 1'b0;
        rs1sel_o  = 1'b0;
        rs2sel_o  = 1'b0;
        memren_o  = 1'b0;
        memwren_o = 1'b0;
        wbsel_o   = `WB_ALU;
        alusel_o  = `ALU_NOP;

        case (opcode_i)
            `R_TYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;

                case (funct3_i)
                    `F3_ADD:    alusel_o = (funct7_i == `F7_SUB) ? `ALU_SUB : `ALU_ADD;
                    `F3_XOR:    alusel_o = `ALU_XOR;
                    `F3_OR:     alusel_o = `ALU_OR;
                    `F3_AND:    alusel_o = `ALU_AND;
                    `F3_SLEFT:  alusel_o = `ALU_SLL;
                    `F3_SRIGHT: alusel_o = (funct7_i == `F7_SRA) ? `ALU_SRA : `ALU_SRL;
                    `F3_SLT:    alusel_o = `ALU_SLT;
                    `F3_SLTU:   alusel_o = `ALU_SLTU;
                    default:    alusel_o = `ALU_NOP;
                endcase
            end

            `I_TYPE: begin
                regwren_o = 1'b1;
                immsel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                wbsel_o   = `WB_ALU;

                case (funct3_i)
                    `F3_ADD:    alusel_o = `ALU_ADD;
                    `F3_XOR:    alusel_o = `ALU_XOR;
                    `F3_OR:     alusel_o = `ALU_OR;
                    `F3_AND:    alusel_o = `ALU_AND;
                    `F3_SLEFT:  alusel_o = `ALU_SLL;
                    `F3_SRIGHT: alusel_o = (funct7_i == `F7_SRA) ? `ALU_SRA : `ALU_SRL;
                    `F3_SLT:    alusel_o = `ALU_SLT;
                    `F3_SLTU:   alusel_o = `ALU_SLTU;
                    default:    alusel_o = `ALU_NOP;
                endcase
            end

            `I_TYPE_L: begin
                regwren_o = 1'b1;
                immsel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                memren_o  = 1'b1;
                wbsel_o   = `WB_MEM;
                alusel_o  = `ALU_ADD;
            end

            `S_TYPE: begin
                immsel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                memwren_o = 1'b1;
                alusel_o  = `ALU_ADD;
            end

            `B_TYPE: begin
                alusel_o = `ALU_ADD;
            end

            `I_TYPE_JALR: begin
                pcsel_o   = 1'b1;
                regwren_o = 1'b1;
                immsel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                wbsel_o   = `WB_PC4;
                alusel_o  = `ALU_ADD;
            end

            `J_TYPE: begin
                pcsel_o   = 1'b1;
                regwren_o = 1'b1;
                immsel_o  = 1'b1;
                rs1sel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                wbsel_o   = `WB_PC4;
                alusel_o  = `ALU_ADD;
            end

            `U_TYPE_LUI: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_IMM;
            end

            `U_TYPE_AUIPC: begin
                regwren_o = 1'b1;
                immsel_o  = 1'b1;
                rs1sel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                wbsel_o   = `WB_ALU;
                alusel_o  = `ALU_ADD;
            end

            default: begin
            end
        endcase
    end

endmodule : control


