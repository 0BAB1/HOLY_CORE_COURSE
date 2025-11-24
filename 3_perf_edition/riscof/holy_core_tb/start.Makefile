# strart.Makefile
#
# This file generate the hex necessary to load test start code at test start
# run :$ make -f start.Makefile
#
# BRH 11/2025

##################################
# To build the startup code
##################################
ASM     = test_startup.S
OBJ     = $(ASM:.S=.o)
ELF     = test_startup.elf
HEX     = test_startup.hex
BIN     = test_startup.bin
DUMP    = test_startup_dump.txt

CC       = riscv32-unknown-elf-gcc
OBJCOPY  = riscv32-unknown-elf-objcopy
OBJDUMP  = riscv32-unknown-elf-objdump

CFLAGS   = -march=rv32i -mabi=ilp32 -nostdlib -Wall -Wextra -O2

# start_code: $(HEX) $(DUMP)
start_code: $(HEX)

#---------------------------------------------------
# Build Rules
#---------------------------------------------------
# 1. Compile assembly source to object
%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

# 2. Link object to ELF (no standard library)
$(ELF): $(OBJ)
	$(CC) $(CFLAGS) -nostartfiles -o $@ $^

# 3. Convert ELF to raw binary
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

# 4. make a .hex dump
$(HEX): $(BIN)
	hexdump -v -e '1/4 "%08x\n"' $< > $@

# 5. Make a txt disasm dump
$(DUMP): $(ELF)
	$(OBJDUMP) -D $< > $@

#---------------------------------------------------
# Clean
#---------------------------------------------------
clean_start:
	rm -f $(OBJ) $(ELF) $(BIN) $(HEX) $(DUMP)

.PHONY: start_code clean_start