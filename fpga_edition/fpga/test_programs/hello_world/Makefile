# Makefile for hello programs
#
# Takes "hello.s" and turns it into "hello.hex", an hex dump ready for use
# in a tcl script for being loaded in BRAM (running "build_hello_hex").
# you can also run "make build_hello" to get all the objdump details with debug hints
#
# BRH 11/12

build_hello_hex: hello.o
	riscv64-unknown-elf-objdump -d -j .text -j .rodata hello.o | sed -n 's/^[ \t]*[0-9a-f]\+:[ \t]*\([0-9a-f]\+\).*/\1/p' > hello.hex
	rm -rf hello.o

build_hello: hello.o
	riscv64-unknown-elf-objdump -d hello.o > hello.hex
	rm -rf hello.o

hello.o: hello.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -g hello.s -o hello.o

.PHONY: clean
clean:
	rm -rf *.o *.hex