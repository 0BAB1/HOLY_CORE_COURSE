# Makefile — Blink LED for RV32I

CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -Wall -Wextra -O2 -I../../hc_lib/include
LDFLAGS = -T linker.ld -nostdlib

all: blink.bin blink.hex

blink.elf: startup.o main.o
	$(CC) $(LDFLAGS) -o $@ $^ -L ../../hc_lib -lholycore

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

clean:
	rm -f *.o *.elf *.bin dump.txt *.hex
