#include <stdint.h>
#include "holy_core_soc.h"

void delay(volatile uint32_t count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main() {
    while (1) {
        GPIO_LED = 1;     // LED ON
        delay(500000);
        GPIO_LED = 0;     // LED OFF
        delay(500000);
    }
}