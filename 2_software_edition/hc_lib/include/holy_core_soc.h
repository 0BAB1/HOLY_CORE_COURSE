#ifndef SOC_H
#define SOC_H

#include <stdint.h>

#define UART_BASE 0x2800
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x8))
#define TX_REG (*(volatile uint8_t *)(UART_BASE + 0x4))

#endif // SOC_H