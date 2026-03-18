#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

#define DMA_BASE         0x10040000
// MM2S (TX - Memory to Stream)
#define MM2S_DMACR      (*(volatile uint32_t*)(DMA_BASE + 0x00))
#define MM2S_DMASR      (*(volatile uint32_t*)(DMA_BASE + 0x04))
#define MM2S_SA         (*(volatile uint32_t*)(DMA_BASE + 0x18))
#define MM2S_LENGTH     (*(volatile uint32_t*)(DMA_BASE + 0x28))
// S2MM (RX - Stream to Memory)
#define S2MM_DMACR      (*(volatile uint32_t*)(DMA_BASE + 0x30))
#define S2MM_DMASR      (*(volatile uint32_t*)(DMA_BASE + 0x34))
#define S2MM_DA         (*(volatile uint32_t*)(DMA_BASE + 0x48))
#define S2MM_LENGTH     (*(volatile uint32_t*)(DMA_BASE + 0x58))

#define DMA_RX_BRAM     0x80004000
#define DMA_TX_BRAM     0x80005000

void main() {
    uart_puts("[BOOT] DMA ethernet loop starting\n\r");

    while(1) {

        // ===== ARMER LA RECEPTION =====
        uart_puts("[RX] Arming S2MM...\n\r");
        S2MM_DMACR  = 0x00000001;
        S2MM_DA     = DMA_RX_BRAM;
        S2MM_LENGTH = 1500;
        uart_puts("[RX] Waiting for packet...\n\r");

        // ===== ATTENDRE UN PAQUET =====
        while(!(S2MM_DMASR & 0x1000));
        S2MM_DMASR = 0x1000;

        uint32_t len = S2MM_LENGTH;
        uart_puts("[RX] Packet received! len=");
        uart_puthex(len);
        uart_puts("\n\r");

        // ===== LIRE LE PAQUET =====
        uint8_t* rx = (uint8_t*)DMA_RX_BRAM;
        uart_puts("[RX] First bytes: ");
        for(int i = 0; i < 8 && i < len; i++) {
            uart_puthex(rx[i]);
            uart_puts(" ");
        }
        uart_puts("\n\r");
    }
}