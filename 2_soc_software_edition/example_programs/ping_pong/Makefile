# Makefile

CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS = -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -Wall -Wextra -O2 -I../../hc_lib/include
LDFLAGS = -T linker.ld -nostdlib

all: hello.bin hello.hex dump.txt bootloader.tcl

hello.elf: startup.o main.o
	$(CC) $(LDFLAGS) -o $@ $^ -L ../../hc_lib -lholycore

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

hello.bin: hello.elf
	$(OBJCOPY) -O binary $< $@

hello.hex: hello.bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

dump.txt: hello.elf
	$(OBJDUMP) -D -M no-aliases $< > $@

bootloader.tcl: hello.hex
	python gen_bootloader.py

clean:
	rm -f *.o *.elf *.bin dump.txt *.hex *.tcl
