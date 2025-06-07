#ifndef HOLYCORE_H
#define HOLYCORE_H

#include <stdint.h>

// UART interface
void uart_putchar(char c);
void uart_puts(const char *s);

#endif // HOLYCORE_H