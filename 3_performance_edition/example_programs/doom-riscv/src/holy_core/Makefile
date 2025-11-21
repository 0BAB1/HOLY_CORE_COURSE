# BRH 11/12 : Makefile for HOLY CORE port

CROSS ?= riscv32-unknown-elf-

CC = $(CROSS)gcc
OBJCOPY = $(CROSS)objcopy
SIZE = $(CROSS)size
ICEPROG = iceprog

# holy core template : CFLAGS = -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -Wall -Wextra -I../hc_lib/include
CFLAGS=-Wall -g -march=rv32i -mabi=ilp32 -mstrict-align -ffreestanding -flto -nostartfiles -fomit-frame-pointer -Wl,--gc-section --specs=nano.specs -I.. -I../../../../hc_lib/include

CFLAGS += \
	-DNORMALUNIX \
	-LIBC_DEBUG\
	$(NULL)
LIBS := -L ../../../../hc_lib -lholycore
DUMP := doom-riscv.dump.txt

include ../sources.mk

# Filter out d_main, we provide our own simplified one
SOURCES_doom := $(filter-out d_main.c,$(SOURCES_doom))

# Filter out s_sound, we provide a dummy one
SOURCES_doom := $(filter-out s_sound.c,$(SOURCES_doom))


SOURCES_doom_arch := \
	d_main.c \
	i_main.c \
	i_net.c \
	i_sound.c \
	i_system.c \
	i_video.c \
	s_sound.c \
	start.S \
	console.c  \
	wad.o \
	libc_backend.c  \
	mini-printf.c \
	$(NULL)


all: wad.o doom-riscv.elf $(DUMP) doom-riscv.hex

wad.o: doom1.wad
	riscv32-unknown-elf-objcopy -I binary -O elf32-littleriscv doom1.wad wad.o

doom-riscv.elf: riscv.lds $(addprefix ../,$(SOURCES_doom)) $(SOURCES_doom_arch)
	$(CC) $(CFLAGS) -Wl,-Bstatic,-T,riscv.lds -o $@ $(addprefix ../,$(SOURCES_doom)) $(SOURCES_doom_arch) $(LIBS)
	$(SIZE) $@

clean:
	rm -f *.bin *.hex *.elf *.o *.gen.h

$(DUMP): doom-riscv.elf
	$(CROSS)objdump -D -M no-aliases doom-riscv.elf > $@

doom-riscv.hex: doom-riscv.elf
	$(OBJCOPY) -O binary doom-riscv.elf doom-riscv.bin
	hexdump -v -e '1/4 "%08X\n"' doom-riscv.bin > doom-riscv.hex

.PHONY: all clean prog prog_wad
.PRECIOUS: *.elf
