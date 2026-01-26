/*
* MEMORY
*
* BRH 10/24
*
* Simple memory array to remember program or instruction data.
* Has a simple cpu request interface. Supports byte_enable masks.
*/

`timescale 1ns/1ps

module memory #(
    parameter WORDS = 128,
    parameter mem_init = ""
) (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic [3:0] byte_enable,
    input logic write_enable,
    input logic rst_n,

    output logic [31:0] read_data
);

// Memory array (32-bit words)
reg [31:0] mem [0:WORDS-1];

initial begin
    if (mem_init != "") begin
        $readmemh(mem_init, mem);
    end
end

// Write operation
always @(posedge clk) begin
    if (rst_n == 1'b0) begin
        for (int i = 0; i < WORDS; i++) begin
            mem[i] <= 32'd0;
        end
        for (int i = 0; i < WORDS; i++) begin
            mem[i] <= 32'd0;
        end
    end else begin
        if(write_enable) begin
            if (address[1:0] != 2'b00) begin
                $display("Misaligned write at address %h", address);
            end else begin
                // use byte-enable to selectively write bytes
                for (int i = 0; i < 4; i++) begin
                    if (byte_enable[i]) begin
                        /* verilator lint_off WIDTHTRUNC */
                        mem[address[31:2]][(i*8)+:8] <= write_data[(i*8)+:8];
                        /* verilator lint_on WIDTHTRUNC */
                    end
                end
            end
        end
    end
end

always_comb begin
    /* verilator lint_off WIDTHTRUNC */
    read_data = mem[address[31:2]];
    /* verilator lint_on WIDTHTRUNC */
end

endmodule
