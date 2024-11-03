`timescale 1ns/1ps

module alu (
    // IN
    input logic [2:0] alu_control,
    input logic [31:0] src1,
    input logic [31:0] src2,
    // OUT
    output logic [31:0] alu_result,
    output logic zero
);

always_comb begin
    case (alu_control)
        // ADD STUFF
        3'b000 : alu_result = src1 + src2;
        // AND STUFF
        3'b010 : alu_result = src1 & src2;
        // OR STUFF
        3'b011 : alu_result = src1 | src2;
        // NON IMPLEMENTED STUFF
        default: alu_result = 32'b0;
    endcase
end

assign zero = alu_result == 32'b0;
    
endmodule