module signext (
    // IN
    input logic [24:0] raw_src,
    input logic imm_source,

    // OUT (immediate)
    output logic [31:0] immediate
);

logic [11:0] gathered_imm;

always_comb begin
    case (imm_source)
        1'b0 : gathered_imm = raw_src[24:13];
        default: gathered_imm = 12'b0;
    endcase
end

assign immediate = {{20{gathered_imm[11]}}, gathered_imm};
    
endmodule