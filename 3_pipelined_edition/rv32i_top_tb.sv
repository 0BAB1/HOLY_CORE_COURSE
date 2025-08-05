
module rv32i_top_tb;

  logic clk = 0;
  logic rst_n;

  parameter DATAMEM_FILE = "data_mem.mem";
  parameter DATAMEM_SIZE = 128;
  parameter TEXTMEM_FILE = "text_mem.mem";
  parameter TEXTMEM_SIZE = 128;

  rv32i_top #(
      .DATAMEM_FILE(DATAMEM_FILE),
      .DATAMEM_SIZE(DATAMEM_SIZE),
      .TEXTMEM_FILE(TEXTMEM_FILE),
      .TEXTMEM_SIZE(TEXTMEM_SIZE)
  ) DUT (
      .clk  (clk),
      .rst_n(rst_n)
  );

  always #5 clk = ~clk;

  initial begin
    rst_n = 1'b1;
    #5;
    rst_n = 1'b0;
    #5;
    rst_n = 1'b1;
  end




endmodule
