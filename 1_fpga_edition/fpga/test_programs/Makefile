# Makefile for test programs
#
# Takes "test.s" and turns it into "test.hex", an hex dump ready for use
# in a tcl script for being loaded in BRAM (running "build_test_hex").
# you can also run "make build_test" to get all the objdump details with debug hints
#
# BRH 11/12

build_test_hex: test.o
	riscv64-unknown-elf-objdump -d test.o | sed -n 's/^[ \t]*[0-9a-f]\+:[ \t]*\([0-9a-f]\+\).*/\1/p' > test.hex
	rm -rf test.o

build_test: test.o
	riscv64-unknown-elf-objdump -d test.o > test.hex
	rm -rf test.o

test.o: test.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -g test.s -o test.o

.PHONY: clean
clean:
	rm -rf *.o *.hex