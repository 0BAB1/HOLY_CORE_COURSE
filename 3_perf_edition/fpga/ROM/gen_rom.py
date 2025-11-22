#!/usr/bin/env python3
import sys

if len(sys.argv) != 3:
    print("Usage: python bin2verilog.py <input.bin> <output.v>")
    sys.exit(1)

bin_file = sys.argv[1]
v_file = sys.argv[2]

# Read binary
with open(bin_file, "rb") as f:
    data = f.read()

# Compute number of 32-bit words
words = [data[i:i+4] for i in range(0, len(data), 4)]

with open(v_file, "w") as f:
    f.write("// Auto-generated ROM from {}\n".format(bin_file))
    f.write("module boot_rom(\n")
    f.write("    input wire clk,\n")
    f.write("    input wire [31:0] addr,\n")
    f.write("    output reg [31:0] data_out\n")
    f.write(");\n\n")
    f.write("    reg [31:0] rom [{}:0];\n\n".format(len(words)-1))
    f.write("    initial begin\n")
    for i, w in enumerate(words):
        # Convert 4 bytes to little-endian 32-bit word
        word = int.from_bytes(w.ljust(4, b'\x00'), byteorder='little')
        f.write("        rom[{}] = 32'h{:08x};\n".format(i, word))
    f.write("    end\n\n")
    f.write("    always @(*) begin\n")
    f.write("        data_out = rom[addr[31:2]];\n")
    f.write("    end\n\n")
    f.write("endmodule\n")
