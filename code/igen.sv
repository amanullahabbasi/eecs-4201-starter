/*
 * Module: igen
 *
 * Description: Immediate value generator
 */
/*
 * Module: igen
 *
 * Description: Immediate value generator
 *
 * Inputs:
 * 1) opcode opcode_i
 * 2) input instruction insn_i
 * Outputs:
 * 2) 32-bit immediate value imm_o
 */
`include "constants.svh"
module igen #(
    parameter int DWIDTH=32
    )(
    input logic [6:0] opcode_i,
    input logic [DWIDTH-1:0] insn_i,
    output logic [DWIDTH-1:0] imm_o
);

    function automatic logic [DWIDTH-1:0] immediate_value(
        input logic [6:0] opcode,
        input logic [DWIDTH-1:0] insn
    );
        case (opcode)
            `I_TYPE, `I_TYPE_L, `I_TYPE_JALR:
                immediate_value = {{20{insn[31]}}, insn[31:20]};
            `S_TYPE:
                immediate_value = {{20{insn[31]}}, insn[31:25], insn[11:7]};
            `B_TYPE:
                immediate_value = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
            `U_TYPE_LUI, `U_TYPE_AUIPC:
                immediate_value = {insn[31:12], 12'b0};
            `J_TYPE:
                immediate_value = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
            default:
                immediate_value = '0;
        endcase
    endfunction

    always_comb begin
        imm_o = immediate_value(opcode_i, insn_i);
    end

endmodule : igen
