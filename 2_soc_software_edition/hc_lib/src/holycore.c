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
    // assumes 0 <= val < 10000
    int thousands = 0, hundreds = 0, tens = 0;

    // extract thousands
    while (val >= 1000) {
        val -= 1000;
        thousands++;
    }
    if (thousands) uart_putchar('0' + thousands);

    // extract hundreds
    while (val >= 100) {
        val -= 100;
        hundreds++;
    }
    if (thousands || hundreds) uart_putchar('0' + hundreds);

    // extract tens
    while (val >= 10) {
        val -= 10;
        tens++;
    }
    if (thousands || hundreds || tens) uart_putchar('0' + tens);

    // units
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