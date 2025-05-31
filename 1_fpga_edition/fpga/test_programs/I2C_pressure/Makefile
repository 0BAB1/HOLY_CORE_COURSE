# Makefile to read pressure from BMP280 sensor using AXIL-I2C IP
# BRH 05/25

pressure.hex: pressure.elf
	riscv64-unknown-elf-objcopy -O binary pressure.elf pressure.bin
	hexdump -v -e '1/4 "%08x\n"' pressure.bin > pressure.hex
	rm -rf *.o *.elf *.bin

pressure.elf: pressure.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -g pressure.s -o pressure.o
	riscv64-unknown-elf-ld -m elf32lriscv -T linker.ld -o pressure.elf pressure.o

disasm: pressure.elf
	riscv64-unknown-elf-objdump -D pressure.elf > pressure.lst

.PHONY: clean
clean:
	rm -rf *.o *.hex *.elf *.lst *.vcd *.ila