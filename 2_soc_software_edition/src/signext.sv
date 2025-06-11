/*
* SIGN EXTENDER
*
* BRH 10/24
*
* Extends the imm sign to 32bits based on source specified by the control unit.
*/

`timescale 1ns/1ps

module signext (
    // IN
    input logic [24:0] raw_src,
    input imm_source_t imm_source,

    // OUT (immediate)
    output logic [31:0] immediate
);

import holy_core_pkg::*;

always_comb begin
    case (imm_source)
        // For I-Types
        I_IMM_SOURCE : immediate = {{20{raw_src[24]}}, raw_src[24:13]};
        // For S-types
        S_IMM_SOURCE : immediate = {{20{raw_src[24]}},raw_src[24:18],raw_src[4:0]};
        // For B-types
        B_IMM_SOURCE : immediate = {{20{raw_src[24]}},raw_src[0],raw_src[23:18],raw_src[4:1],1'b0};
        // For J-types
        J_IMM_SOURCE : immediate = {{12{raw_src[24]}}, raw_src[12:5], raw_src[13], raw_src[23:14], 1'b0};
        // For U-Types
        U_IMM_SOURCE : immediate = {raw_src[24:5],12'b000000000000};
        // CSR instrs
        CSR_IMM_SOURCE : immediate = {{27{1'b0}}, raw_src[12:8]};

        default: immediate = 32'd0;
    endcase
end
    
endmodule