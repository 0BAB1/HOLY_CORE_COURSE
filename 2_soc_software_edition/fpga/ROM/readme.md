# ROM

This folder contains resources to build a simple test program and generate a bootrom from it.

The generated module is then used in the fpga/ testbench to check basic behavior of the SoC.

## Usage

1. Write you program in rom.S
2. Run `make` in this ROM/ folder
3. Run `make` in the fpga/ folder to run the tb
4. The tb autmatically uses the bootrom in the ROM/ folder.