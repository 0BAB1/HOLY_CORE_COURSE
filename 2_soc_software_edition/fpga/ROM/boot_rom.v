// Auto-generated ROM from boot.bin
module boot_rom(
    input wire clk,
    input wire [31:0] addr,
    output reg [31:0] data_out
);

    reg [31:0] rom [1:0];

    initial begin
        rom[0] = 32'h800002b7;
        rom[1] = 32'h00028067;
    end

    always @(*) begin
        data_out = rom[addr[31:2]];
    end

endmodule
