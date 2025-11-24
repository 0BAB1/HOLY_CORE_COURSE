// Auto-generated ROM from boot.bin
module boot_rom(
    input wire clk,
    input wire [31:0] addr,
    output reg [31:0] data_out
);

    reg [31:0] rom [11:0];

    initial begin
        rom[0] = 32'h00000293;
        rom[1] = 32'h800002b7;
        rom[2] = 32'hfff28293;
        rom[3] = 32'h7c129073;
        rom[4] = 32'h7c231073;
        rom[5] = 32'h00000293;
        rom[6] = 32'h80000337;
        rom[7] = 32'hfff30313;
        rom[8] = 32'h7c329073;
        rom[9] = 32'h7c431073;
        rom[10] = 32'h800002b7;
        rom[11] = 32'h00028067;
    end

    always @(*) begin
        data_out = rom[addr[31:2]];
    end

endmodule
