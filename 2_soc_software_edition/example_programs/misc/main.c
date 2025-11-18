/*  Misc holy core tests program
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

__attribute__((interrupt))
void trap_handler(){
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;

    // Read CSRs
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
    __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));

    uart_puts("Unexpected exception\n\r");
    // dump stack infos
    dump_stack();
    // Dump trap registers
    uart_puts("mcause: ");
    uart_puthex((uint32_t)mcause);
    uart_puts(" mepc: ");
    uart_puthex((uint32_t)mepc);
    uart_puts(" mepc: ");
    uart_puthex((uint32_t)mtval);
    uart_puts("\n\r");

    // Return from trap
    __asm__ volatile ("mret");
}

int main() {
    uart_puts("===================================================\n\r");
    uart_puts("HOLY CORE - Misc Tests Program\n\r");
    uart_puts("===================================================\n\r");

    return 0;
}