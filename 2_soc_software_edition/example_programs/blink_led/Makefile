# Makefile — Blink LED for RV32I

CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -Wall -Wextra -O2
LDFLAGS = -T ../linker.ld -nostdlib

all: blink.bin blink.hex bootloader.tcl

blink.elf: startup.o main.o
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

blink.bin: blink.elf
	$(OBJCOPY) -O binary $< $@

blink.hex: blink.bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

dump.txt: blink.elf
	$(OBJDUMP) -D -M no-aliases blink.elf > dump.txt

bootloader.tcl: blink.hex
	python gen_bootloader.py

clean:
	rm -f *.o *.elf *.bin dump.txt *.hex
