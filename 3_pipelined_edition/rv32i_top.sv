
module rv32i_top #(
    parameter DATAMEM_FILE = "",
    parameter DATAMEM_SIZE = 128,
    parameter TEXTMEM_FILE = "",
    parameter TEXTMEM_SIZE = 128
) (
    input logic clk,
    input logic rst_n
);

  logic [31:0] inst_if;
  logic [ 3:0] byte_mask_mem;
  logic [31:0] mem_read_data;
  logic [31:0] mem_addr_mem;
  logic [31:0] mem_write_data;
  logic [31:0] mem_write_mem;
  logic [31:0] current_pc_if;

  core rv32i_core (
      .clk(clk),
      .rst_n(rst_n),
      .inst_if(inst_if),
      .mem_read_data(mem_read_data),
      .byte_mask_mem(byte_mask_mem),
      .mem_addr_mem(mem_addr_mem),
      .mem_write_data(mem_write_data),
      .mem_write_mem(mem_write_mem),
      .current_pc_if(current_pc_if)
  );

  memory #(
      .WORDS(DATAMEM_SIZE),
      .MEM_INIT(DATAMEM_FILE)
  ) data_mem_inst (
      .clk(clk),
      .rst_n(rst_n),
      .address(mem_addr_mem),
      .write_data(mem_write_data),
      .byte_enable(byte_mask_mem),
      .write_enable(mem_write_mem),
      .read_data(mem_read_data)
  );

  memory #(
      .WORDS(TEXTMEM_SIZE),
      .MEM_INIT(TEXTMEM_FILE)
  ) text_mem_inst (
      .clk(clk),
      .rst_n(rst_n),
      .address(current_pc_if),
      .write_data(32'b0),
      .byte_enable(4'b0),
      .write_enable(1'b0),
      .read_data(inst_if)
  );




endmodule
