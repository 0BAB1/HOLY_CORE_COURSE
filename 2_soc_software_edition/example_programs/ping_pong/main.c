#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

void trap_handler(){
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;
    uint32_t claim;

    // Read CSRs
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
    __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));

    // Dump trap registers
    uart_puts("Trap cause: ");
    uart_puthex((uint32_t)mcause);
    uart_puts("  mepc: ");
    uart_puthex((uint32_t)mepc);
    uart_puts("  mtval: ");
    uart_puthex((uint32_t)mtval);
    uart_puts("\n\r");

    // Check if it's an interrupt (MSB set)
    if (mcause >> 31) {
        uint32_t irq = mcause & 0x7FFFFFFF;

        // If external interrupt (PLIC-related)
        if (irq == 11) { // 11 = Machine external interrupt
            claim = PLIC_CLAIM;

            if(claim == 0){
                uart_puts("Error claiming on PLIC : id not valid\n\r");
            }

            uart_putchar('T');

            UART_CONTROL = (1<<1);      // clear RX
            UART_CONTROL = 0;           // clear
            UART_CONTROL = (1 << 4);    // EN intr

            PLIC_CLAIM = claim;
        } else {
            uart_puts("Unhandled interrupt ID\n\r");
        }
    } else {
        // Handle exceptions if needed
        uart_puts("Exception occurred (not interrupt)\n\r");
    }

    // Return from trap
    __asm__ volatile ("mret");
}

int main() {
    uart_puts("Checking PLIC\n\r");
    if(PLIC_ENABLE != 0x3){
        uart_puts("Failed to config PLIC\n\r");
    } else {
        uart_puts("PLIC configuration OK\n\r");
    }

    uart_puts("Checking\n\r");
    if((UART_STATUS & 1 << 4) == 0){
        uart_puts("Failed to enable interrupts\n\r");
    } else {
        uart_puts("Interrupts Enabled\n\r");
    }
    
    uart_puts("Setting up.\n\r");
    UART_CONTROL = (1<<1);      // clear RX
    UART_CONTROL = 0;           // clear
    UART_CONTROL = (1 << 4);    // EN intr
    
    uart_puts("Waiting for interrupt...\n\r");
    while (1) {
        __asm__("nop");
    }

    return 0;
}