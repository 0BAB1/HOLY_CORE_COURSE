/* Holy core soc platform descriptor
*
* Use this file to give the library a description of you platforms layout and addresses.
* It's also a source of information to know how the overall system is layed out.
*
* BRH - 8/25
*/

#ifndef SOC_H
#define SOC_H

#include <stdint.h>

// UART
#define UART_BASE 0x10000000
#define RX_FIFO (*(volatile uint8_t *)(UART_BASE + 0x0))
#define TX_REG (*(volatile uint8_t *)(UART_BASE + 0x4))
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x8))
#define UART_CONTROL (*(volatile uint32_t *)(UART_BASE + 0xC))

// GPIO
#define GPIO_BASE 0x10010000

// AXI IIC
#define I2C_BASE 0x10020000
#define I2C_CONTROL (*(volatile uint32_t *)(I2C_BASE + 0x100))
#define I2C_STATUS (*(volatile uint32_t *)(I2C_BASE + 0x104))
#define I2C_SOFT_RESET (*(volatile uint32_t *)(I2C_BASE + 0x40))
#define I2C_TX_FIFO (*(volatile uint32_t *)(I2C_BASE + 0x108))
#define I2C_RX_FIFO (*(volatile uint32_t *)(I2C_BASE + 0x10C))
#define I2C_RX_FIFO_PIRQ (*(volatile uint32_t *)(I2C_BASE + 0x120))

// AXI SPI
#define SPI_BASE 0x10030000
#define SPI_SOFT_RESET (*(volatile uint32_t *)(SPI_BASE + 0x40))
#define SPI_CONTROL (*(volatile uint32_t *)(SPI_BASE + 0x60))
#define SPI_STATUS (*(volatile uint32_t *)(SPI_BASE + 0x64))
#define SPI_TX (*(volatile uint32_t *)(SPI_BASE + 0x68))
#define SPI_RX (*(volatile uint32_t *)(SPI_BASE + 0x6C))
#define SPI_SS (*(volatile uint32_t *)(SPI_BASE + 0x70))
#define SPI_TX_OCY (*(volatile uint32_t *)(SPI_BASE + 0x74))
#define SPI_RX_OCY (*(volatile uint32_t *)(SPI_BASE + 0x78))
#define SPI_RX (*(volatile uint32_t *)(SPI_BASE + 0x6C))

#define SPI_DEVICE_GLOBAL_ITR_EN (*(volatile uint32_t *)(SPI_BASE + 0x1C))
#define SPI_ITR_STATUS (*(volatile uint32_t *)(SPI_BASE + 0x20))
#define SPI_ITR_EN (*(volatile uint32_t *)(SPI_BASE + 0x24))

// DEBUG MODULE
#define DEBUG_BASE 0x30000000 // informative placeholder, not really used

// CLINT
// #define CLINT_BASE 0x40000000
// #define CLINT_MSIP (*(volatile uint32_t *)(CLINT_BASE + 0x0))
// #define CLINT_MTIMECMP (*(volatile uint32_t *)(CLINT_BASE + 0x4000))
// #define CLINT_MTIMECMPH (*(volatile uint32_t *)(CLINT_BASE + 0x4004))
// #define CLINT_MTIME (*(volatile uint32_t *)(CLINT_BASE + 0xBFF8))
// #define CLINT_MTIMEH (*(volatile uint32_t *)(CLINT_BASE + 0xBFFC))

// RAM (256M)
#define RAM_BASE 0x80000000 // informative placeholder, not really used

// PLIC
#define PLIC_BASE 0x90000000
#define PLIC_ENABLE (*(volatile uint32_t *)(PLIC_BASE + 0x0))
#define PLIC_CLAIM (*(volatile uint32_t *)(PLIC_BASE + 0x4))

#endif // SOC_H