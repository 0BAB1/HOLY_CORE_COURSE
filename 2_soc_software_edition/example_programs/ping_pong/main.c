/*  Ping pong program
*
*   Leverages interruts to get UART input
*   
*   This program tests external interrupt support, claim etc...
*   Also Test basic software functionalities: if you type "ping",
*   The holy core will answer "pong".
*
*   BRH 08/25
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"
#define LINE_BUF_SIZE 64

char line_buf[LINE_BUF_SIZE];
uint8_t line_len = 0;

extern uint32_t _stack_top;
extern uint32_t _stack_bottom;

void dump_stack(void) {
    register uint32_t sp asm("sp");
    uart_puts("\n\rSP: 0x"); uart_puthex(sp); uart_puts("\n\r");
    uart_puts("Stack Top: 0x"); uart_puthex((uint32_t)&_stack_top); uart_puts("\n\r");
    uart_puts("Stack Bottom: 0x"); uart_puthex((uint32_t)&_stack_bottom); uart_puts("\n\r");
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return (unsigned char)(*s1) - (unsigned char)(*s2);
}

void trap_handler(){
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;

    // Read CSRs
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));
    __asm__ volatile ("csrr %0, mepc"   : "=r"(mepc));
    __asm__ volatile ("csrr %0, mtval"  : "=r"(mtval));

    // External irq handler
    if((uint32_t)mcause == 0x8000000B){
        // Claim the interrupt
        uint32_t claim_id = PLIC_CLAIM;

        // Read RX Status
        uint32_t status = UART_STATUS;
        // Check if there is some valid RX data
        if((status & 1 )== 1){
            char c = (char)RX_FIFO;
            
            // Handle the char
            if (c == '\r' || c == '\n' || c == ' ') {
                line_buf[line_len] = '\0';
                uart_puts("\n\rYou typed: ");
                uart_puts(line_buf);

                if(strcmp(line_buf, "ping") == 0){
                    uart_puts("\n\rpong !");
                }

                uart_puts("\n\r> ");
                line_len = 0; // Reset for next line
            } else if (line_len < LINE_BUF_SIZE - 1) {
                line_buf[line_len++] = c;
                uart_putchar(c); // Echo
            }

            // Clear UART LITE ip
            UART_CONTROL = (1 << 1);    // clear RX
            UART_CONTROL = 0;           // clear Control
            UART_CONTROL = (1 << 4);    // reset EN intr
        }

        PLIC_CLAIM = claim_id;

        // Return from trap
        __asm__ volatile ("mret");
    } else {
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
    }

    // Return from trap
    __asm__ volatile ("mret");
}

int main() {
    UART_CONTROL = (1<<1);      // clear RX
    UART_CONTROL = 0;           // clear
    UART_CONTROL = (1 << 4);    // EN intr

    if(((UART_STATUS & 1 << 4) || (PLIC_ENABLE != 0x3)) == 0){
        uart_puts("N\n\r");
    } else {
        uart_puts("CONFIG OK.\n\r");
    }

    uart_puts("===================================================\n\r");
    uart_puts("HOLY CORE - Ping Pong - Interrupt test program\n\r");
    uart_puts("===================================================\n\r");
    uart_puts("> ");
    
    while (1) {
        // Do nothing, let interrupts handle the rest
        __asm__("nop");
    }

    return 0;
}