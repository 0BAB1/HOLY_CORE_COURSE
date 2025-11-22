#ifndef HOLYCORE_H
#define HOLYCORE_H

#include <stdint.h>
#include <stddef.h>

// UART interface
void uart_putchar(char c);
void uart_puts(const char *s);
void uart_putdec(int val);
void uart_puthex(uint32_t val);

#endif // HOLYCORE_H