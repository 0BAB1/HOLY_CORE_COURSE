#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

void trap_handler(){
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;

    // Read CSRs
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
    __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));

    // Dump trap registers
    uart_puts("cse: ");
    uart_puthex((uint32_t)mcause);
    uart_puts(" epc: ");
    uart_puthex((uint32_t)mepc);
    uart_puts(" tval: ");
    uart_puthex((uint32_t)mtval);
    uart_puts("\n\r");

    // Claim if external
    if((uint32_t)mcause == 0x8000000B){
        // Claim the interrupt
        uint32_t claim_id = PLIC_CLAIM;
        uart_puts("ID#: ");
        uart_puthex((uint32_t)claim_id);
        uart_puts("\n\r");

        // Read RX FIFO
        uint32_t c = RX_FIFO;
        uart_puts("char: ");
        uart_puthex((uint32_t)c);
        uart_puts("\n\r");

        // Read RX Status
        uint32_t status = UART_STATUS;
        uart_puts("Stat: ");
        uart_puthex((uint32_t)status);
        uart_puts("\n\r");

        // Clear UART LITE ip
        UART_CONTROL = (1<<1);      // clear RX
        UART_CONTROL = 0;           // clear
        UART_CONTROL = (1 << 4);    // EN intr

        PLIC_CLAIM = claim_id;
    }

    // Return from trap
    __asm__ volatile ("mret");
}

int main() {
    if(PLIC_ENABLE != 0x3){
        uart_puts("Failed PLIC\n\r");
    } else {
        uart_puts("PLIC OK\n\r");
    }

    UART_CONTROL = (1<<1);      // clear RX
    UART_CONTROL = 0;           // clear
    UART_CONTROL = (1 << 4);    // EN intr

    if((UART_STATUS & 1 << 4) == 0){
        uart_puts("Failed intr\n\r");
    } else {
        uart_puts("Intr OK\n\r");
    }
    
    uart_puts("Wait\n\r");
    while (1) {
        __asm__("nop");
    }

    return 0;
}