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

/*
    I2C BUS I/O Support using AXI IIC IP in the SOC
*/

void config_i2c_core(){
    // SOFT RESET
    I2C_SOFT_RESET = 0xA;

    for(volatile int i = 0; i < 10; i++){
        // not mandatory and probably useless
        // but I like to let things sink in
        __asm__ volatile("nop");
    }

    // RESET TX_FIFO
    I2C_CONTROL = 0x3;

    for(volatile int i = 0; i < 10; i++){
        // same here
        __asm__ volatile("nop");
    }

    // RELEASE RESET
    I2C_CONTROL = 0x1;
}

void send_i2c_char(uint8_t addr, char *data, uint16_t len){
    if (len == 0) return;

    // address is 7 bits
    addr = addr & 0x7F;
    
    // As we send data, we set the 8th bit to 0 for write
    addr <<= 1;
    
    // Check the AXI IIC IP is clear to send
    while (I2C_STATUS & I2C_STATUS_TX_FIFO_FULL);

    // start : specify IIC slave base addr and write
    I2C_TX_FIFO = 0x100 | addr;
    
    // Send data byte by byte, if len =1, we skip this parts and directly go to stop
    for (int i = 0; i < len - 1; i++) {
        I2C_TX_FIFO = data[i];
    }

    // When we arrive at the last byte to send, we sent it with STOP
    I2C_TX_FIFO = 0x200 | data[len-1];
}

void read_multiple_i2c_char(uint8_t addr, char *dest_data, uint16_t len){
    /*
        The I2C Slave has to be compatible woth multi byte read
        This technically is standard but *not* enforced so a random
        sensor might not sorrt it.

        Typically, on the BMP280 for example, we request a read on an address
        and as long as the master does not stop, it send register after register,
        incrementing the address each time.addr

        Please check you sensor's datasheet before using !

        AXI IIC IP is 16 bytes deep, len cannot go higher than that !
    */

    if (len == 0) return;
    if (len > 16) return; // Max AXI IIC RX FIFO Depth

    // address is 7 bits
    addr = addr & 0x7F;
    
    // As we send data, we set the 8th bit to 1 for read
    addr <<= 1;
    addr |= 0x1;

    // Check the AXI IIC IP is clear to recieve adn send
    while ((I2C_STATUS & I2C_STATUS_RX_FIFO_FULL) || (I2C_STATUS & I2C_STATUS_TX_FIFO_FULL));

    // Start : request a read on I2C slave
    I2C_TX_FIFO = 0x100 | addr;

    // Master reciever mode : set stop after X bytes
    I2C_TX_FIFO = 0x200 | len;

    // Now return content into dest_data by reading from RX_FIFO
    // So we wait for RX FIFO NOT EMPTY AND BUS NOT BUSY
    while (((I2C_STATUS & I2C_STATUS_RX_FIFO_EMPTY) == 0) || (I2C_STATUS & I2C_STATUS_BUS_BUSY));

    // Read `len` bytes from RX FIFO
    for (int i = 0; i < len; i++) {
        // Wait for data to be available
        while (I2C_STATUS & I2C_STATUS_RX_FIFO_EMPTY);
        dest_data[i] = I2C_RX_FIFO;
    }
}