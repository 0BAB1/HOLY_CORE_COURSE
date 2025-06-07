#include <stdint.h>
#include "holycore.h"

int main() {
    uart_puts("Hello, world!\n\r");
    while (1);  // Infinite loop
}