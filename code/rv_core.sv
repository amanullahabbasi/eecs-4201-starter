/*
 * Module: rv_core
 *
 * Description: Top level module that will contain sub-module instantiations.
 *
 * Inputs:
 * 1) clk
 * 2) reset signal
 */

`include "constants.svh"

module rv_core #(
  parameter int AWIDTH = 32,
  parameter int DWIDTH = 32
)(
  input logic clk,
  input logic reset,
  output logic busy
);

    // IF/ID registers
    logic [AWIDTH-1:0] if_id_pc;
    logic [DWIDTH-1:0] if_id_insn;

    // ID/EX registers
    logic [AWIDTH-1:0] id_ex_pc;
    logic [DWIDTH-1:0] id_ex_insn;
    logic [DWIDTH-1:0] id_ex_rs1data;
    logic [DWIDTH-1:0] id_ex_rs2data;
    logic [DWIDTH-1:0] id_ex_imm;
    logic [4:0] id_ex_rs1;
    logic [4:0] id_ex_rs2;
    logic [4:0] id_ex_rd;

    // EX/MEM registers
    logic [AWIDTH-1:0] ex_mem_pc;
    logic [DWIDTH-1:0] ex_mem_insn;
    logic [DWIDTH-1:0] ex_mem_result;
    logic [DWIDTH-1:0] ex_mem_store_data;
    logic [DWIDTH-1:0] ex_mem_imm;
    logic [4:0] ex_mem_rs2;
    logic [4:0] ex_mem_rd;

    // MEM/WB registers
    logic [AWIDTH-1:0] mem_wb_pc;
    logic [DWIDTH-1:0] mem_wb_result;
    logic [DWIDTH-1:0] mem_wb_load_data;
    logic [DWIDTH-1:0] mem_wb_imm;
    logic [4:0] mem_wb_rd;

    logic x_pcsel;
    logic x_immsel;
    logic x_regwren;
    logic x_rs1sel;
    logic x_rs2sel;
    logic x_memren;
    logic x_memwren;
    logic [1:0] x_wbsel;
    logic [3:0] x_alusel;
    logic m_regwren;
    logic m_memren;
    logic m_memwren;
    logic [1:0] m_wbsel;
    logic w_regwren;
    logic [1:0] w_wbsel;

    // ---------- FETCH STAGE ----------- //
    // Logic hole 1 (LH1) : In fetch, determining next PC on a jump/branch
    //               that will feed into jump_branch_i port in fetch module.
    //               No changes are necessary in fetch logic (fetch.sv)
    // fetch signals
    logic [AWIDTH-1:0] f_pc, pc;
    logic [DWIDTH-1:0] f_insn;
    logic pc_en;
    logic stall, flush, hazard;
    logic idex_en, idex_clear;
    logic exmem_en, exmem_clear;
    logic memwb_en, memwb_clear;
    logic jump_branch;

    // stall and flush logic instantiation
    stall_flush_logic stall_flush (
        .hazard_i(hazard),
        .br_jump_i(jump_branch),
        .pc_en_o(pc_en),
        .stall_o(stall),
        .flush_o(flush),
        .idex_en_o(idex_en),
        .idex_clear_o(idex_clear),
        .exmem_en_o(exmem_en),
        .exmem_clear_o(exmem_clear),
        .memwb_en_o(memwb_en),
        .memwb_clear_o(memwb_clear)
    );

    // fetch instantiation
    fetch #(
        .AWIDTH(32),
        .DWIDTH(32),
        .BASEADDR(32'h01000000)
    ) fetch1 (
        .clk(clk),
        .rst(reset),
        .next_pc_i(f_pc),
        .pc_en_i(pc_en),
        .jump_branch_i(jump_branch),
        .pc_o(pc),
        .insn_o()
    );

    // ---------- DECODE STAGE ---------- //
    // decode signals
    logic [6:0] d_opcode;
    logic [4:0] d_rd;
    logic [4:0] d_rs1;
    logic [4:0] d_rs2;
    logic [6:0] d_funct7;
    logic [2:0] d_funct3;
    logic [4:0] d_shamt;
    logic [DWIDTH-1:0] d_imm;
    logic [DWIDTH-1:0] d_insn;
    logic [AWIDTH-1:0] d_pc;

    assign d_insn = if_id_insn;
    assign d_pc = if_id_pc;

    // Logic hole 2 (LH2): Please see decode.sv for details on LH2
    // decode instantiation
    decode #(
        .AWIDTH(32),
        .DWIDTH(32)
    ) decode1 (
        .clk(clk),
        .rst(reset),
        .insn_i(d_insn),
        .pc_i(d_pc),
        .pc_o(),
        .insn_o(),
        .opcode_o(d_opcode),
        .rd_o(d_rd),
        .rs1_o(d_rs1),
        .rs2_o(d_rs2),
        .funct7_o(d_funct7),
        .funct3_o(d_funct3),
        .shamt_o(),
        .imm_o()
    );

    // immediate generator signals
    logic [DWIDTH - 1:0] igen_imm;
    assign d_imm = igen_imm;
    assign d_shamt = igen_imm[4:0];

    // Logic hole 3 (LH3): Please see igen.sv for details on LH3
    // immediate generator instantiation
    igen #(
        .DWIDTH(32)
    ) igen1 (
        .opcode_i(d_opcode),
        .insn_i(d_insn),
        .imm_o(igen_imm)
    );

    // ---------- CONTROL --------------- //
    // Logic hole 4 (LH4): Please see control.sv for details on LH4
    // control signals
    wire c_pcsel;
    wire c_immsel;
    wire c_regwren;
    wire c_rs1sel;
    wire c_rs2sel;
    wire c_memren;
    wire c_memwren;
    wire [1:0] c_wbsel;
    wire [3:0] c_alusel;
    // control instantiation
    control #(
        .DWIDTH(32)
    ) control1 (
        .insn_i(d_insn),
        .opcode_i(d_opcode),
        .funct7_i(d_funct7),
        .funct3_i(d_funct3),
        .pcsel_o(c_pcsel),
        .immsel_o(c_immsel),
        .regwren_o(c_regwren),
        .rs1sel_o(c_rs1sel),
        .rs2sel_o(c_rs2sel),
        .memren_o(c_memren),
        .memwren_o(c_memwren),
        .wbsel_o(c_wbsel),
        .alusel_o(c_alusel)
    );


    control_pipeline control_pipe (
        .clk(clk),
        .rst(reset),
        .idex_en_i(idex_en),
        .idex_clear_i(idex_clear),
        .exmem_en_i(exmem_en),
        .exmem_clear_i(exmem_clear),
        .memwb_en_i(memwb_en),
        .memwb_clear_i(memwb_clear),
        .pcsel_i(c_pcsel),
        .immsel_i(c_immsel),
        .regwren_i(c_regwren),
        .rs1sel_i(c_rs1sel),
        .rs2sel_i(c_rs2sel),
        .memren_i(c_memren),
        .memwren_i(c_memwren),
        .wbsel_i(c_wbsel),
        .alusel_i(c_alusel),
        .x_pcsel_o(x_pcsel),
        .x_immsel_o(x_immsel),
        .x_regwren_o(x_regwren),
        .x_rs1sel_o(x_rs1sel),
        .x_rs2sel_o(x_rs2sel),
        .x_memren_o(x_memren),
        .x_memwren_o(x_memwren),
        .x_wbsel_o(x_wbsel),
        .x_alusel_o(x_alusel),
        .m_regwren_o(m_regwren),
        .m_memren_o(m_memren),
        .m_memwren_o(m_memwren),
        .m_wbsel_o(m_wbsel),
        .w_regwren_o(w_regwren),
        .w_wbsel_o(w_wbsel)
    );

    // ---------- EXECUTE STAGE --------- //
    // execute signals
    logic [DWIDTH - 1:0] alu_A, alu_B, mux_B, e_res;
    logic [DWIDTH - 1:0] e_rs1data, e_rs2data;
    logic [DWIDTH - 1:0] m_forward_data;
    logic [DWIDTH - 1:0] r_rs1data, r_rs2data;
    logic [DWIDTH - 1:0] d_rs1data, d_rs2data;
    logic [DWIDTH - 1:0] m_store_data;
    logic [DWIDTH - 1:0] wb_data;
    logic e_brtaken;

    hazard_detection_unit hazard1 (
        .d_rs1_i(d_rs1),
        .d_rs2_i(d_rs2),
        .x_rd_i(id_ex_rd),
        .x_memren_i(x_memren),
        .stall_o(hazard)
    );

    writeback #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) m_wb_mux (
        .pc_i(ex_mem_pc),
        .alu_res_i(ex_mem_result),
        .memory_data_i('0),
        .wbsel_i(m_wbsel),
        .imm_i(ex_mem_imm),
        .writeback_data_o(m_forward_data)
    );

    logic [1:0] forward_a_sel, forward_b_sel;

    forwarding_unit forward1 (
        .x_rs1_i(id_ex_rs1),
        .x_rs2_i(id_ex_rs2),
        .m_rd_i(ex_mem_rd),
        .m_regwren_i(m_regwren && !m_memren),
        .w_rd_i(mem_wb_rd),
        .w_regwren_i(w_regwren),
        .forward_a_sel_o(forward_a_sel),
        .forward_b_sel_o(forward_b_sel)
    );

    always_comb begin
        case (forward_a_sel)
            `FWD_EX_MEM: e_rs1data = m_forward_data;
            `FWD_MEM_WB: e_rs1data = wb_data;
            default:     e_rs1data = id_ex_rs1data;
        endcase
    end

    always_comb begin
        case (forward_b_sel)
            `FWD_EX_MEM: e_rs2data = m_forward_data;
            `FWD_MEM_WB: e_rs2data = wb_data;
            default:     e_rs2data = id_ex_rs2data;
        endcase
    end

    assign m_store_data = (w_regwren && mem_wb_rd != 0 &&
                           mem_wb_rd == ex_mem_rs2) ?
                          wb_data : ex_mem_store_data;

    // Logic hole 5 (LH5): Complete the logic to determine the inputs to the ALU
    //                     alu_A, mux_B, alu_B

    assign jump_branch = x_pcsel || e_brtaken;
    assign f_pc = jump_branch ? e_res : pc;
    assign alu_A = x_rs1sel ? id_ex_pc : e_rs1data;
    assign mux_B = e_rs2data;
    assign alu_B = x_rs2sel ? id_ex_imm : mux_B;

    // Logic hole 6 (LH6): Please see execute.sv for details on LH6
    // Execute instantiation
    alu #(
      .DWIDTH(DWIDTH),
      .AWIDTH(AWIDTH)
    ) e_alu1 (
      .pc_i(id_ex_pc),
      .rs1_i(alu_A),
      .rs2_i(alu_B),
      .funct3_i(id_ex_insn[14:12]),
      .funct7_i(id_ex_insn[31:25]),
      .opcode_i(id_ex_insn[6:0]),
      .imm_i(id_ex_imm),
      .alusel_i(x_alusel),
      .res_o(e_res),
      .brtaken_o(e_brtaken)
    );

    // ---------- MEMORY STAGE ---------- //
    logic insn_en;
    logic [DWIDTH-1:0] m_data_o;

    // Read instruction from memory only if no reset.
    assign insn_en = 1'b1;

    // Memory instantiation
    memory #(
        .AWIDTH(32),
        .DWIDTH(32),
        .OWIDTH(2),
        .BASE_ADDR(32'h01000000)
        ) memory1 (
        .clk(clk),
        .rst(reset),
        .pc_i(pc),
        .addr_i(ex_mem_result),
        .data_i(m_store_data),
        .funct3_i(ex_mem_insn[14:12]),
        .memren_i(m_memren),
        .memwren_i(m_memwren),
        .insnen_i(insn_en),
        .insn_o(f_insn),
        .data_o(m_data_o)
    );

    // ---------- WRITEBACK STAGE ------- //
    // Logic hole 7 (LH7): Please see writeback.sv for details on LH7
    // write back instantiation
    writeback #(
      .DWIDTH(DWIDTH),
      .AWIDTH(AWIDTH)
    ) wb_wb1 (
      .pc_i(mem_wb_pc),
      .alu_res_i(mem_wb_result),
      .memory_data_i(mem_wb_load_data),
      .wbsel_i(w_wbsel),
      .imm_i(mem_wb_imm),
      .writeback_data_o(wb_data)
    );

    // ---------- REGISTER FILE ------- //
    // Register file instantiation
    register_file #(
      .DWIDTH(DWIDTH)
    ) register_file1 (
      .clk(clk),
      .rst(reset),
      .rs1_i(d_rs1),
      .rs2_i(d_rs2),
      .rd_i(mem_wb_rd),
      .datawb_i(wb_data),
      .regwren_i(w_regwren),
      .rs1data_o(r_rs1data),
      .rs2data_o(r_rs2data)
    );

    assign d_rs1data = (w_regwren && mem_wb_rd != 0 &&
                        mem_wb_rd == d_rs1) ? wb_data : r_rs1data;
    assign d_rs2data = (w_regwren && mem_wb_rd != 0 &&
                        mem_wb_rd == d_rs2) ? wb_data : r_rs2data;

    // IF/ID
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            if_id_pc <= '0;
            if_id_insn <= `NOP;
        end
        else if (!stall) begin
            if_id_pc <= pc;
            if_id_insn <= f_insn;
        end
    end

    // ID/EX
    always_ff @(posedge clk) begin
        if (reset || idex_clear) begin
            id_ex_pc <= '0;
            id_ex_insn <= `NOP;
            id_ex_rs1data <= '0;
            id_ex_rs2data <= '0;
            id_ex_imm <= '0;
            id_ex_rs1 <= '0;
            id_ex_rs2 <= '0;
            id_ex_rd <= '0;
        end
        else if (idex_en) begin
            id_ex_pc <= if_id_pc;
            id_ex_insn <= if_id_insn;
            id_ex_rs1data <= d_rs1data;
            id_ex_rs2data <= d_rs2data;
            id_ex_imm <= d_imm;
            id_ex_rs1 <= d_rs1;
            id_ex_rs2 <= d_rs2;
            id_ex_rd <= d_rd;
        end
    end

    // EX/MEM
    always_ff @(posedge clk) begin
        if (reset) begin
            ex_mem_pc <= '0;
            ex_mem_insn <= `NOP;
            ex_mem_result <= '0;
            ex_mem_store_data <= '0;
            ex_mem_imm <= '0;
            ex_mem_rs2 <= '0;
            ex_mem_rd <= '0;
        end
        else if (exmem_clear) begin
            ex_mem_pc <= '0;
            ex_mem_insn <= `NOP;
            ex_mem_result <= '0;
            ex_mem_store_data <= '0;
            ex_mem_imm <= '0;
            ex_mem_rs2 <= '0;
            ex_mem_rd <= '0;
        end
        else if (exmem_en) begin
            ex_mem_pc <= id_ex_pc;
            ex_mem_insn <= id_ex_insn;
            ex_mem_result <= e_res;
            ex_mem_store_data <= e_rs2data;
            ex_mem_imm <= id_ex_imm;
            ex_mem_rs2 <= id_ex_rs2;
            ex_mem_rd <= id_ex_rd;
        end
    end

    // MEM/WB
    always_ff @(posedge clk) begin
        if (reset) begin
            mem_wb_pc <= '0;
            mem_wb_result <= '0;
            mem_wb_load_data <= '0;
            mem_wb_imm <= '0;
            mem_wb_rd <= '0;
        end
        else if (memwb_clear) begin
            mem_wb_pc <= '0;
            mem_wb_result <= '0;
            mem_wb_load_data <= '0;
            mem_wb_imm <= '0;
            mem_wb_rd <= '0;
        end
        else if (memwb_en) begin
            mem_wb_pc <= ex_mem_pc;
            mem_wb_result <= ex_mem_result;
            mem_wb_load_data <= m_data_o;
            mem_wb_imm <= ex_mem_imm;
            mem_wb_rd <= ex_mem_rd;
        end
    end

    // This is to get yosys to synthesize the design
    assign busy = (c_regwren || c_memren || c_memwren);

endmodule : rv_core
