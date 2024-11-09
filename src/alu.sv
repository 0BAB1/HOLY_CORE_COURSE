`timescale 1ns/1ps

module alu (
    // IN
    input logic [3:0] alu_control,
    input logic [31:0] src1,
    input logic [31:0] src2,
    // OUT
    output logic [31:0] alu_result,
    output logic zero
);

wire [4:0] shamt = src2[4:0];

always_comb begin
    case (alu_control)
        // ADD STUFF
        4'b0000 : alu_result = src1 + src2;
        // AND STUFF
        4'b0010 : alu_result = src1 & src2;
        // OR STUFF
        4'b0011 : alu_result = src1 | src2;
        // SUB Stuff (src1 - src2)
        4'b0001 : alu_result = src1 + (~src2 + 1'b1);
        // LESS THAN COMPARE STUFF (src1 < src2)
        4'b0101 : alu_result = {31'b0, $signed(src1) < $signed(src2)};
        // LESS THAN COMPARE STUFF (src1 < src2) (UNSIGNED VERSION)
        4'b0111 : alu_result = {31'b0, src1 < src2};
        // XOR STUFF
        4'b1000 : alu_result = src1 ^ src2;
        // SLL STUFF
        4'b0100 : alu_result = src1 << shamt;
        // SRL STUFF
        4'b0110 : alu_result = src1 >> shamt;
        // SRA STUFF
        4'b1001 : alu_result = $signed(src1) >>> shamt;
    endcase
end

assign zero = alu_result == 32'b0;
    
endmodule