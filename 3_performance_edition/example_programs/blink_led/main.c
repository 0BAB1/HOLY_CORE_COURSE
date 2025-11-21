#include <stdint.h>

#define LED_REG (*(volatile uint32_t*)0x10010000)

void delay(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main() {
    while (1) {
        LED_REG = 1;     // LED ON
        delay(500000);
        LED_REG = 0;     // LED OFF
        delay(500000);
    }
}