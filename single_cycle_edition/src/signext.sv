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
    input logic [2:0] imm_source,

    // OUT (immediate)
    output logic [31:0] immediate
);

always_comb begin
    case (imm_source)
        // For I-Types
        3'b000 : immediate = {{20{raw_src[24]}}, raw_src[24:13]};
        // For S-types
        3'b001 : immediate = {{20{raw_src[24]}},raw_src[24:18],raw_src[4:0]};
        // For B-types
        3'b010 : immediate = {{20{raw_src[24]}},raw_src[0],raw_src[23:18],raw_src[4:1],1'b0};
        // For J-types
        3'b011 : immediate = {{12{raw_src[24]}}, raw_src[12:5], raw_src[13], raw_src[23:14], 1'b0};
        // For U-Types
        3'b100 : immediate = {raw_src[24:5],12'b000000000000};

        default: immediate = 32'd0;
    endcase
end
    
endmodule