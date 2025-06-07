#include "holycore.h"
#include "holy_core_soc.h"
#include <stdint.h>

void uart_putchar(char c) {
    while (UART_STATUS & 0x8); // Wait TX reg is not full
    TX_REG = c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}