#---------------------------------------------------
# Makefile to build RISC-V boot ROM from assembly
#---------------------------------------------------

ASM     = rom.S
OBJ     = $(ASM:.S=.o)
ELF     = boot.elf
BIN     = boot.bin
VROM    = boot_rom.v
DUMP    = dump.txt

CC       = riscv32-unknown-elf-gcc
OBJCOPY  = riscv32-unknown-elf-objcopy
OBJDUMP  = riscv32-unknown-elf-objdump
CFLAGS   = -march=rv32i -mabi=ilp32 -nostdlib -Wall -Wextra -O2

all: $(VROM) $(DUMP)

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

# 4. Generate Verilog ROM from binary
$(VROM): $(BIN) gen_rom.py
	python gen_rom.py $< $@

# 5. Generate disassembly dump
$(DUMP): $(ELF)
	@echo "Generating dump..."
	$(OBJDUMP) -D -M no-aliases $< > $@

#---------------------------------------------------
# Clean up
#---------------------------------------------------

clean:
	rm -f *.o *.elf *.bin *.v *.txt

.PHONY: all clean
