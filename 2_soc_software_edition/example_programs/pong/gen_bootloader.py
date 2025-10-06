# gen_bootloader.py
# BRH 2025-08

MAX_AXI_LEN = 256  # AXI burst max length (beats)

def read_hex_file(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()
    return [line.strip() for line in lines if line.strip()]

def generate_tcl(words):
    hex_word_count = len(words)
    tcl_lines = [
        "# Blink leds loader",
        "#",
        "# BRH Auto-Generated",
        "",
        "reset_hw_axi [get_hw_axis hw_axi_1]",
        "set bram_address 0x00000000",
        "",
        "# Clear previous write transactions if any",
        "if {[llength [get_hw_axi_txns]]} {",
        "    delete_hw_axi_txns [get_hw_axi_txns]",
        "}",
        ""
    ]

    # Generate chunked write transactions
    base_addr = 0x00000000
    for i in range(0, hex_word_count, MAX_AXI_LEN):
        chunk = words[i:i + MAX_AXI_LEN]
        chunk_len = len(chunk)
        addr = base_addr + i * 4  # Assuming 4 bytes per word
        txn_name = f"axi_bram_wt_{i//MAX_AXI_LEN}"

        tcl_lines.append(f"create_hw_axi_txn {txn_name} [get_hw_axis hw_axi_1] -type write -address 0x{addr:08X} -len {chunk_len} -data {{")
        tcl_lines.append("    " + "\n    ".join(chunk))
        tcl_lines.append("}")
        tcl_lines.append(f"run_hw_axi [get_hw_axi_txns {txn_name}]")
        tcl_lines.append("")

    return "\n".join(tcl_lines)

def main():
    hex_words = read_hex_file("pong.hex")
    tcl_out = generate_tcl(hex_words)
    with open("bootloader.tcl", "w") as f:
        f.write(tcl_out)
    print(f"Generated bootloader.tcl with {len(hex_words)} words.")

if __name__ == "__main__":
    main()
