// Auto-generated ROM from boot.bin
module boot_rom(
    input wire clk,
    input wire [31:0] addr,
    output reg [31:0] data_out
);

    reg [31:0] rom [13:0];

    initial begin
        rom[0] = 32'h100102b7;
        rom[1] = 32'h00100313;
        rom[2] = 32'h00000393;
        rom[3] = 32'h0062a023;
        rom[4] = 32'h0003de37;
        rom[5] = 32'h090e0e13;
        rom[6] = 32'hfffe0e13;
        rom[7] = 32'hfe0e1ee3;
        rom[8] = 32'h0072a023;
        rom[9] = 32'h0003de37;
        rom[10] = 32'h090e0e13;
        rom[11] = 32'hfffe0e13;
        rom[12] = 32'hfe0e1ee3;
        rom[13] = 32'hfd9ff06f;
    end

    always @(*) begin
        data_out = rom[addr[31:2]];
    end

endmodule
