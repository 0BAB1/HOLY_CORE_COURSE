/*  Pong program
*
*   Leverages interruts to get UART input
*   
*   Example game for the HOLY CORE SoC
*
*   BRH 10/25
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

#define SCREEN_WIDTH  17
#define SCREEN_HEIGHT 7

int ball_x;
int ball_y;
int ball_dx;
int ball_dy;
int bat_y;

void draw_char(int x, int y, char c) {
    // Move cursor to (row = y+1, col = x+1) and print character
    uart_putchar(27);     // ESC (0x1B)
    uart_putchar('[');
    uart_putdec(y + 1);   // row (1-based)
    uart_putchar(';');
    uart_putdec(x + 1);   // col (1-based)
    uart_putchar('H');
    uart_putchar(c);
}

// Draw screen using only uart_putchar / uart_puts
void draw_screen() {
    char screen[SCREEN_HEIGHT + 1][SCREEN_WIDTH + 3]; // +3 for bat column and '\0'
    for (int y = 0; y <= SCREEN_HEIGHT; y++) {
        for (int x = 0; x <= SCREEN_WIDTH + 1; x++) {
            screen[y][x] = ' ';
        }
        screen[y][SCREEN_WIDTH + 2] = '\0';
    }

    screen[ball_y][ball_x] = 'O';
    screen[bat_y][SCREEN_WIDTH + 1] = '|';

    uart_puts("\x1b[H"); // move to top left only, don't clear
    for (int y = 0; y <= SCREEN_HEIGHT; y++) {
        uart_puts(screen[y]);
        uart_puts("\r\n");
    }
}

__attribute__((interrupt))
void trap_handler() {
    unsigned long mcause;
    unsigned long mepc;
    unsigned long mtval;

    // Read cause of intr
    __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));

    // Check for machine-mode external intr
    if ((mcause == 0x8000000B)) {
        // Claim the PLIC interrupt
        uint32_t claim_id = PLIC_CLAIM;

        // Read RX status
        uint32_t status = UART_STATUS;

        // If data is available in RX FIFO
        if ((status & 1) == 1) {
            char c = RX_FIFO;   // read the received character
            if(c == 'z' && bat_y > 0) bat_y --;
            if(c == 's' && bat_y < SCREEN_HEIGHT) bat_y ++;
        }

        // Signal plic we handled interrupt
        PLIC_CLAIM = claim_id;

        // Make sure we clean the IP to avoid any risk of deadlocks
        UART_CONTROL = (1 << 1); // clear RX
        UART_CONTROL = 0;
        UART_CONTROL = (1 << 4); // re-enable interrupt
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
    // init uart ip
    UART_CONTROL = (1<<1);      // clear RX
    UART_CONTROL = 0;           // clear
    UART_CONTROL = (1 << 4);    // EN intr

    ball_x = 0;
    ball_dx = 1;
    ball_y = 0;
    ball_dy = 1;
    bat_y = 0;

    if(((UART_STATUS & 1 << 4) || (PLIC_ENABLE != 0x3)) == 0){
        uart_puts("N\n\r");
    } else {
        uart_puts("CONFIG OK.\n\r");
        uart_puts("\x1b[2J\x1b[H");
    }

    while (1) {
        draw_screen();
        ball_x += ball_dx; 
        ball_y += ball_dy; 

        if(ball_x <= 0) ball_dx = 1;
        if(ball_x >= SCREEN_WIDTH) {
            if(bat_y <= ball_y + 1 && bat_y >= ball_y - 1){
                ball_dx = -1;
            } else {
                ball_dx = 0;
            }
        } 

        if(ball_y <= 0) ball_dy = 1;
        if(ball_y >= SCREEN_HEIGHT) ball_dy = -1;

        for(int i = 0; i <2500; i++){;}
    }
}
