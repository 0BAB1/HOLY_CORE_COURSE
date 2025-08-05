/*
 * MEMORY
 *
 * BRH 10/24
 *
 * Simple memory array to remember program or instruction data.
 * Has a simple cpu request interface. Supports byte_enable masks.
 *
 * dev note 2025-08-04 (rur1k):
 * optimized the reset part away so the elaboration part would pick up that it
 * is a ram memory and made the memory wrap instead of giving x values when out
 * of bounds
 */

`timescale 1ns / 1ps

module memory #(
    parameter WORDS = 128,
    parameter MEM_INIT = ""
) (
    input logic clk,
    input logic rst_n,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic [3:0] byte_enable,
    input logic write_enable,

    output logic [31:0] read_data
);

  // Memory array (32-bit words)
  reg [31:0] mem[0:WORDS-1];

  initial begin
    if (MEM_INIT != "") begin
      $readmemh(MEM_INIT, mem);
    end
  end

  localparam addr_bit_size = $clog2(WORDS) - 1;

  wire [addr_bit_size:0] word_address;
  assign word_address = address[addr_bit_size+2:2];

  // Write operation
  always @(posedge clk) begin
    if (write_enable) begin
      if (byte_enable[0]) mem[word_address][7:0] = write_data[7:0];
      if (byte_enable[1]) mem[word_address][15:8] = write_data[15:8];
      if (byte_enable[2]) mem[word_address][23:16] = write_data[23:16];
      if (byte_enable[3]) mem[word_address][31:24] = write_data[31:24];
    end
  end

  /* verilator lint_off WIDTHTRUNC */
  assign read_data = mem[address[31:2]];
  /* verilator lint_on WIDTHTRUNC */

endmodule
