/* Holy core soc platform descriptor
*
* Use this file to give the library a description of your platforms layout and addresses.
*
* BRH - 8/25
*/

#ifndef SOC_H
#define SOC_H

#include <stdint.h>

// GPIO
#define GPIO_BASE 0x10600000
#define GPIO_LED (*(volatile uint8_t *)(GPIO_BASE + 0x0))

// UART
#define UART_BASE 0x10000000
#define RX_FIFO (*(volatile uint8_t *)(UART_BASE + 0x0))
#define TX_REG (*(volatile uint8_t *)(UART_BASE + 0x4))
#define UART_STATUS (*(volatile uint32_t *)(UART_BASE + 0x8))
#define UART_CONTROL (*(volatile uint32_t *)(UART_BASE + 0xC))

// AXI IIC
#define I2C_BASE 0x0BADBAD0 // !!NO SUPPORT FOR NOW!!
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

// CLINT
#define CLINT_BASE 0x40000000
#define CLINT_MTIME_CMP_LOW (*(volatile uint32_t *)(CLINT_BASE + 0x4000))
#define CLINT_MTIME_CMP_HIGH (*(volatile uint32_t *)(CLINT_BASE + 0x4004))
#define CLINT_MTIME_LOW (*(volatile uint32_t *)(CLINT_BASE + 0xBFF8))
#define CLINT_MTIME_HIGH (*(volatile uint32_t *)(CLINT_BASE + 0xBFFC))

// PLIC
#define PLIC_BASE 0x80000000
#define PLIC_ENABLE (*(volatile uint32_t *)(PLIC_BASE + 0x0))
#define PLIC_CLAIM (*(volatile uint32_t *)(PLIC_BASE + 0x4))

#endif // SOC_H