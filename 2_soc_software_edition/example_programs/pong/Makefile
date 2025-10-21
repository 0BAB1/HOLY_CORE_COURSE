# Makefile

CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS = -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -Wall -Wextra -I../../hc_lib/include
LDFLAGS = -T ../linker.ld -nostdlib

all: pong.bin pong.hex dump.txt bootloader.tcl

pong.elf: startup.o main.o
	$(CC) $(LDFLAGS) -o $@ $^ -L ../../hc_lib -lholycore

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

pong.bin: pong.elf
	$(OBJCOPY) -O binary $< $@

pong.hex: pong.bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

dump.txt: pong.elf
	$(OBJDUMP) -D -M no-aliases $< > $@

bootloader.tcl: pong.hex
	python gen_bootloader.py

clean:
	rm -f *.o *.elf *.bin dump.txt *.hex *.tcl
