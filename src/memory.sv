module memory #(
    parameter WORDS = 64,
    parameter ADDR_WIDTH = $clog2(WORDS)
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    input logic rst_n,

    output logic [31:0] read_data
);

reg [31:0] mem [0:WORDS-1];

always @(posedge clk ) begin
    // reset support, init to 0
    if(rst_n == 1'b0) begin
        for(int i = 0; i<WORDS; i++) begin
            mem[i] <= 32'b0;
        end
    end 
    else if(write_enable == 1'b1) begin
        mem[address] <= write_data;
    end

    read_data <= mem[address];
end
    
endmodule