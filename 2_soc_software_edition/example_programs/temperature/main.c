/*  Temperatur program (I2C usage example, without drivers)
*
* Read temperature from an AHT20 sensor.
* very raw, no drivers involved for now (kinda of a test file).
*
* BRH 11/25
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

#define CLK_FREQ (uint32_t)25000000
// delay consts
// TODO : use some real delay smh...
#define CLK_CYCLES_MS10 (uint32_t)(10*CLK_FREQ/(150*1000))
#define CLK_CYCLES_MS20 (uint32_t)(20*CLK_FREQ/(150*1000))
#define CLK_CYCLES_MS40 (uint32_t)(40*CLK_FREQ/(150*1000))
#define CLK_CYCLES_MS80 (uint32_t)(80*CLK_FREQ/(150*1000))

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
    while (1)
    {
        // ==================== NOTE ======================
        // Using dynamic mode e.g. TX_FIFO direct manipulation =>
        // Bit [8] is the START, bit [9] is the STOP, bits [7:1] are the address, and bit [0] is the R/W bit.                                                               

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

        // delay 40ms after power on, as per the datasheet
        for(long unsigned int i =0; i < CLK_CYCLES_MS40; i++) { __asm__ volatile("nop"); }

        // =================================
        // Send soft reset + init command after power on
        // =================================
        // soft reset is 0xBA
        I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
        I2C_TX_FIFO = (1<<9) | 0xBA;

        // we use polling to wait for the bus busy flag to go low and tx empty to go high
        while(I2C_STATUS & (1 << 2));    // BB flag
        while(!(I2C_STATUS & (1 << 7))); // TX FIFO Empty flag

        // delay 20ms, as per the datasheet
        for(long unsigned int i =0; i < CLK_CYCLES_MS20; i++) { __asm__ volatile("nop"); }

        // init is 0xBE + params 0x08 & 0x00.
        I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
        I2C_TX_FIFO = 0xBE;
        I2C_TX_FIFO = 0x08;
        I2C_TX_FIFO = (1 << 9) | 0x00;

        // we use polling to wait for the bus busy flag to go low and tx empty to go high
        while(I2C_STATUS & (1 << 2));    // BB flag
        while(!(I2C_STATUS & (1 << 7))); // TX FIFO Empty flag

        // delay 10ms, as per the datasheet
        for(long unsigned int i =0; i < CLK_CYCLES_MS10; i++) { __asm__ volatile("nop"); }

        // =====================
        // Verify status
        // =====================
        // First we specify to sensor we wanna read from 0x71 (STATUS)
        // Write Start + Device + Write
        I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
        I2C_TX_FIFO = 0x71;
        // Repeated Start to read status byte
        I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 1;
        // Stop + read 1 byte
        I2C_TX_FIFO = (1 << 9) | 1;

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
        I2C_TX_FIFO = 0xAC;
        // write 0x33 param
        I2C_TX_FIFO = 0x33;
        // write 0x00 param + STOP
        I2C_TX_FIFO = (1 << 9) | 0x00;

        //delay 80ms
        for(long unsigned int i =0; i < CLK_CYCLES_MS80; i++) { __asm__ volatile("nop"); }

        // wait for measurement to be complted by polling status
        do{
            // Read status byte from sensor
            I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 0;
            I2C_TX_FIFO = 0x71;
            I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 1;
            I2C_TX_FIFO = (1 << 9) | 1;
            while((I2C_STATUS & (1 << 6)));// RX FIFO Empty flag

            // exatrct value from IIC ip
            sensor_status = I2C_RX_FIFO & 0xFF;
        }while(sensor_status & 0x80);

        // ===========================
        // Get & handle measurements
        // ===========================
        // we read 6 bytes to get measurements + CRC data byte (7 total).
        I2C_TX_FIFO = (1 << 8) | (0x38 << 1) | 1;
        // Stop + read 6 bytes
        I2C_TX_FIFO = (1 << 9) | 7;

        // We wait for RX_FIFO_OCY to be 6
        while(I2C_RX_FIFO_OCY != 6);

        // get all the bytes
        uint8_t state = I2C_RX_FIFO     & 0xFF;
        uint8_t byte1 = I2C_RX_FIFO     & 0xFF;
        uint8_t byte2 = I2C_RX_FIFO     & 0xFF;
        uint8_t byte3 = I2C_RX_FIFO     & 0xFF;
        uint8_t byte4 = I2C_RX_FIFO     & 0xFF;
        uint8_t byte5 = I2C_RX_FIFO     & 0xFF;
        uint8_t crc_data = I2C_RX_FIFO  & 0xFF;

        uint32_t hum_raw = ((uint32_t)byte1 << 12) | ((uint32_t)byte2 << 4) | ((byte3 & 0xF0) >> 4);
        uint32_t humidity_scaled = (hum_raw * 10000 + 524288) >> 20;
        uint32_t temp_raw = (((uint32_t)(byte3 & 0x0F)) << 16) | ((uint32_t)byte4 << 8) | byte5;
        int32_t temp_scaled = ((int64_t)temp_raw * 20000 + 524288) >> 20;
        temp_scaled -= 5000;

        uart_puts("Humidity read:\n\r");
        uart_putdec(humidity_scaled);
        uart_puts("\n\rTemp read:\n\r");
        uart_putdec(temp_scaled);

        uart_puts("\n\rdone\n\r");
    }

    return 0;
}
