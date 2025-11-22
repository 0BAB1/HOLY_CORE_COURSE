# Compiler and flags
CC = riscv32-unknown-elf-gcc
CFLAGS = -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -Wall -Wextra -O2 -Iinclude

# Sources and objects
SRC = src/holycore.c
OBJ = $(SRC:.c=.o)

.PHONY: all clean

all: libholycore.a

libholycore.a: $(OBJ)
	ar rcs $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) libholycore.a
