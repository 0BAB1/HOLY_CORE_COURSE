# Makefile — sensor

CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
CFLAGS = -march=rv32i -mabi=ilp32 -nostdlib -Wall -Wextra -O2 -I../../hc_lib/include
LDFLAGS = -T linker.ld -nostdlib

all: sensor.bin sensor.hex sensor.tcl

sensor.elf: startup.o main.o
	$(CC) -T linker.ld -nostdlib -o $@ $^ -L ../../hc_lib -lholycore

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

sensor.bin: sensor.elf
	$(OBJCOPY) -O binary $< $@

sensor.hex: sensor.bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@

sensor.tcl: sensor.hex
	python loader_gen.py

dump.txt: sensor.elf
	$(OBJDUMP) -D -M no-aliases sensor.elf > dump.txt

clean:
	rm -f *.o *.elf *.bin dump.txt *.hex *.tcl
