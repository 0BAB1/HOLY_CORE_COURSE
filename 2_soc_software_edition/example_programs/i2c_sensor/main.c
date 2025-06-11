#include <stdint.h>
#include <stddef.h>
#include "holycore.h"

#define BMP280_I2C_ADDR (uint8_t)0x77

/*
 NOTES :
 100h => Control
 104h => Sattus
 108h => TX_FIFO
 10Ch => RX_FIFO
*/

int main() {
    uart_puts("Initializing AXI IIC IP...\n\r");

    config_i2c_core();

    uart_puts("Config done ! Sending IIR filter config to sensor\n\r");

    char send_for_config[] = {0xF5, 0x00};
    size_t len = sizeof(send_for_config) / sizeof(send_for_config[0]);

    send_i2c_char(BMP280_I2C_ADDR, send_for_config, len);

    uart_puts("Sent IIR config, sending measurements config...\n\r");

    char send_for_measurement_conf[] = {0xF4, 0x09};
    len = sizeof(send_for_measurement_conf) / sizeof(send_for_measurement_conf[0]);

    send_i2c_char(BMP280_I2C_ADDR, send_for_measurement_conf, len);

    uart_puts("Config OK, waiting for measurement\n\r");

    // we'll poll F3 on the sensor.
    // We need to specify we want to read it 1st.
    char sensor_base_read_reg[] = {0xF3};
    len = sizeof(sensor_base_read_reg) / sizeof(sensor_base_read_reg[0]);

    send_i2c_char(BMP280_I2C_ADDR, sensor_base_read_reg, len);

    // Then we rsend a read request, it should return the value in F3
    // (that we need to poll until measurement is done !)
    char f3_polling_result = 0xFF;

    while((f3_polling_result & 0x8) != 0){
        read_multiple_i2c_char(BMP280_I2C_ADDR, &f3_polling_result, 1);
    }

    uart_puts("Measurement done ! Reading measurement data...\n\r");

    while (1);  // Infinite loop
}