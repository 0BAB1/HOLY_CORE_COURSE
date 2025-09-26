#ifndef HOLYCORE_H
#define HOLYCORE_H

#include <stdint.h>
#include <stddef.h>

// UART interface
void uart_putchar(char c);
void uart_puts(const char *s);
void uart_putdec(int val);
void uart_puthex(uint32_t val);

// AXI IIC Support
void config_i2c_core();
void send_i2c_char(uint8_t addr, char *data, uint16_t len);
void read_multiple_i2c_char(uint8_t addr, char *dest_data, uint16_t len);

#endif // HOLYCORE_H