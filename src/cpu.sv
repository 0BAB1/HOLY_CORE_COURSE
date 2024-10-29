module cpu (
    input logic clk,
    input logic rst_n
);

/**
* PROGRAM COUNTER
*/

reg pc;
always @(posedge clk) begin
    if(rst_n == 0) begin
        pc <= 0;
    end else begin
        pc <= pc + 4;
    end
end

/**
* INSTRUCTION MEMORY
*/

// We do not use write for insructions, it acts as a ROM.
memory instruction_memory (
    // todo
);
    
endmodule