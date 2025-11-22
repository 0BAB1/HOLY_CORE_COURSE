#include "holycore.h"
#include "holy_core_soc.h"
#include <stdint.h>

/*
    UART PRINT FUNCTIONS
*/

void uart_putchar(char c) {
    while (UART_STATUS & 0x8); // Wait TX reg is not full
    TX_REG = c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}

void uart_putdec(int val) {
    // assumes 0 <= val < 100
    int tens = 0;
    while (val >= 10) {
        val -= 10;
        tens++;
    }
    if (tens) uart_putchar('0' + tens);
    uart_putchar('0' + val);
}

// Helper: Convert a nibble to hex character
static char hex_digit(uint8_t nibble) {
    return (nibble < 10) ? ('0' + nibble) : ('A' + nibble - 10);
}

// Print 32-bit value in hexadecimal (8 hex digits)
void uart_puthex(uint32_t val) {
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uint8_t nibble = (val >> (i * 4)) & 0xF;
        uart_putchar(hex_digit(nibble));
    }
}