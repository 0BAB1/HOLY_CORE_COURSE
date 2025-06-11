#ifndef SOC_H
#define SOC_H

#include <stdint.h>

// UART
#define UART_BASE 0x2800
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x8))
#define TX_REG (*(volatile uint8_t *)(UART_BASE + 0x4))

// AXI IIC
#define I2C_BASE 0x3000
#define I2C_CONTROL (*(volatile uint32_t *)(I2C_BASE + 0x100))
#define I2C_STATUS (*(volatile uint32_t *)(I2C_BASE + 0x104))
#define I2C_SOFT_RESET (*(volatile uint32_t *)(I2C_BASE + 0x40))
#define I2C_STATUS_RX_FIFO_FULL     0x20
#define I2C_STATUS_RX_FIFO_EMPTY    0x40
#define I2C_STATUS_TX_FIFO_FULL     0x10
#define I2C_STATUS_TX_FIFO_EMPTY    0x80
#define I2C_STATUS_BUS_BUSY         0x04
#define I2C_BUSY_FLAGS          (I2C_STATUS_RX_FIFO_FULL | I2C_STATUS_TX_FIFO_FULL | I2C_STATUS_BUS_BUSY)
#define I2C_TX_FIFO (*(volatile uint32_t *)(I2C_BASE + 0x108))
#define I2C_RX_FIFO (*(volatile uint32_t *)(I2C_BASE + 0x10C))

#endif // SOC_H