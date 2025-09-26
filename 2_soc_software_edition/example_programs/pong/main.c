#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

#define SCREEN_WIDTH 20
#define SCREEN_HEIGHT 10

int ball_x = 1;
int ball_y = 1;
// int ball_dx = 1;
// int ball_dy = 1;
// int paddle_y = SCREEN_HEIGHT / 2;

void draw_char(int x, int y, char c) {
    uart_putchar(27);     // ESC
    uart_putchar('[');
    uart_putdec(y + 1);   // row
    uart_putchar(';');
    uart_putdec(x + 1);   // col
    uart_putchar('H');
    uart_putchar(c);
}

// Move ball and handle collisions
void move_ball() {
}

// Draw screen using only uart_putchar
void draw_screen() {
    // clear and go to top left
    uart_puts("\x1b[2J\x1b[H");
    draw_char(ball_x,ball_y,'O');
}

// void trap_handler() {
//     unsigned long mcause;
//     __asm__ volatile ("csrr %0, mcause" : "=r"(mcause));

//     if((uint32_t)mcause == 0x8000000B) { // UART IRQ
//         uint32_t claim_id = PLIC_CLAIM;
//         if(UART_STATUS & 1) {
//             char c = RX_FIFO;
//             if (c == 'z' && paddle_y > 0) paddle_y--;
//             if (c == 's' && paddle_y < SCREEN_HEIGHT-1) paddle_y++;
//             UART_CONTROL = (1 << 1); // clear RX
//             UART_CONTROL = 0;
//             UART_CONTROL = (1 << 4); // enable intr
//         }
//         PLIC_CLAIM = claim_id;
//         __asm__ volatile("mret");
//     }
//     __asm__ volatile("mret");
// }

int main() {
    // UART_CONTROL = (1 << 1);
    // UART_CONTROL = 0;
    // UART_CONTROL = (1 << 4);

    
    while(1) {
        draw_screen();
        ball_x += 1;
        //delay
        for(int delay=0; delay < 10000; delay++){
            ;
        }
    }
}
