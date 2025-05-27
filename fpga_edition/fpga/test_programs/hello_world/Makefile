# Makefile for hello world program
# BRH 05/25

hello.hex: hello.elf
	riscv64-unknown-elf-objcopy -O binary hello.elf hello.bin
	hexdump -v -e '1/4 "%08x\n"' hello.bin > hello.hex
	rm -rf *.o *.elf *.bin

hello.elf: hello.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -g hello.s -o hello.o
	riscv64-unknown-elf-ld -m elf32lriscv -T linker.ld -o hello.elf hello.o

.PHONY: clean
clean:
	rm -rf *.o *.hex *.elf