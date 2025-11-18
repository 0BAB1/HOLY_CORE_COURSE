/*  Temperatur program
*
* Read emperature from an AHT20 sensor.
*
* BRH 11/25
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

uint8_t itr_flag;

__attribute__((interrupt))
void trap_handler() {
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));

    // Check for machine-mode external intr
    if ((mcause == 0x8000000B)) {
        uint32_t claim_id = PLIC_CLAIM;
        PLIC_CLAIM = claim_id;
    } else {
        // Unexpected trap: print diagnostics to uart
        __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
        __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));

        uart_puts("Unexpected exception\n\r");
        uart_puts("mcause: ");
        uart_puthex((uint32_t)mcause);
        uart_puts(" mepc: ");
        uart_puthex((uint32_t)mepc);
        uart_puts(" mtval: ");
        uart_puthex((uint32_t)mtval);
        uart_puts("\n\r");
    }
}

int main() {
    // =====================
    // CONFIG
    // =====================

    // Soft reset
    I2C_SOFT_RESET = 0xA;
    // enc ore
    I2C_CONTROL = 0x0;
    I2C_CONTROL = 0x1;
    // set tx fifo depth to max
    I2C_RX_FIFO_PIRQ = 0x0F;

    // =====================
    // Verify status
    // =====================
    // First we specify to sensor we wanna read from 0x71 (STATUS)
    // Using dynamic mode e.g.
    // Bit [8] is the START, bit [9] is the STOP, bits [7:1] are the address, and bit [0] is the R/W bit.                                                               

    // write device address on bus
    I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
    // write status command 0x71 and stop immediatly
    I2C_TX_FIFO = (1 << 9) | (0x71 << 1);

    // we use polling to wait fot the bus busy flag to go low and tx empty to go high
    while(I2C_STATUS & (1 << 2));    // BB flag
    while(!(I2C_STATUS & (1 << 7))); // TX FIFO Empty flag

    // Now read and we shall get sensor status
    I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 1;   // START read @ sensor
    I2C_TX_FIFO = (1 << 9) | 1;                 // STOP + specify 1 byte

    // wait for RX Fifo not empty
    while((I2C_STATUS & (1 << 6))); // RX FIFO Empty flag

    // Read the status byte
    uint8_t sensor_status = I2C_RX_FIFO & 0xFF;
    if(!(sensor_status & (1 << 3))){
        uart_puts("The sensor is not calibrated !");
        while(1);
    }

    // =====================
    // Trigger measurement
    // =====================
    // Send 0xAC + 0x33 + 0x00
    // write device address on bus
    I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
    // trig meas command 0xAC
    I2C_TX_FIFO = (0xAC) | (0);
    // write 0x33 param
    I2C_TX_FIFO = (0x33) | (0);
    // write 0x00 param + STOP
    I2C_TX_FIFO = (1 << 9) | (0x00 << 1) | (0);

    while(I2C_STATUS & (1 << 2));    // BB flag
    while(!(I2C_STATUS & (1 << 7))); // TX FIFO Empty flag

    uart_puts("done\n\r");
}
