`timescale 1ns/1ps

module signext (
    // IN
    input logic [24:0] raw_src,
    input logic [1:0] imm_source,

    // OUT (immediate)
    output logic [31:0] immediate
);

logic [11:0] gathered_imm;

always_comb begin
    case (imm_source)
        // For I-Types
        2'b00 : gathered_imm = raw_src[24:13];
        // For S-types
        2'b01 : gathered_imm = {raw_src[24:18],raw_src[4:0]};
        // For B-types
        2'b10 : gathered_imm = {raw_src[0],raw_src[23:18],raw_src[4:1],1'b0};
        default: gathered_imm = 12'b0;
    endcase
end

assign immediate = imm_source == 2'b10 ? {{20{raw_src[24]}}, gathered_imm} : {{20{gathered_imm[11]}}, gathered_imm};
    
endmodule