build_gpio_hex: gpio.o
	riscv64-unknown-elf-objdump -d gpio.o | sed -n 's/^[ \t]*[0-9a-f]\+:[ \t]*\([0-9a-f]\+\).*/\1/p' > gpio.hex
	rm -rf gpio.o

gpio.o: test_gpio.s
	riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 test_gpio.s -o gpio.o

.PHONY: clean
clean:
	rm -rf *.o *.hex