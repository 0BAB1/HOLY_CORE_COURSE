CC = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump

# Compilation flags
CFLAGS = -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -Wall -Wextra -I../hc_lib/include
LDFLAGS = -T ./linker.ld -nostdlib -L ../hc_lib -lholycore

# ===== User specifies app directory =====
# Usage: make APP=app1
APP ?= hello_world

APP_DIR := $(APP)

# Output names (per app)
ELF  := $(APP_DIR)/$(APP).elf
BIN  := $(APP_DIR)/$(APP).bin
HEX  := $(APP_DIR)/$(APP).hex
DUMP := $(APP_DIR)/dump.txt

# Source files (per app)
SRCS := $(APP_DIR)/startup.S $(APP_DIR)/main.c
OBJS := $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# ===== Build rules =====
all: $(BIN) $(HEX) $(DUMP)

OBJS := $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

LIBS := -L ../hc_lib -lholycore

$(ELF): $(OBJS)
	$(CC) -T ./linker.ld -nostdlib -o $@ $(OBJS) $(LIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -c -o $@ $<

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(HEX): $(BIN)
	hexdump -v -e '1/4 "%08x\n"' $< > $@

$(DUMP): $(ELF)
	$(OBJDUMP) -D -M no-aliases $< > $@

# ===== Clean all apps =====
clean:
	@echo "Cleaning all app directories..."
	@find . -mindepth 1 -maxdepth 1 -type d -print0 | \
	  xargs -0 -I{} sh -c 'rm -f "{}"/*.o "{}"/*.elf "{}"/*.bin "{}"/*.hex "{}"/dump.txt || true'