#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"
#include "fft.h"

#define DMA_BASE         0x10040000
#define DEBUG            0

#define MM2S_DMACR      (*(volatile uint32_t*)(DMA_BASE + 0x00))
#define MM2S_DMASR      (*(volatile uint32_t*)(DMA_BASE + 0x04))
#define MM2S_SA         (*(volatile uint32_t*)(DMA_BASE + 0x18))
#define MM2S_LENGTH     (*(volatile uint32_t*)(DMA_BASE + 0x28))
#define S2MM_DMACR      (*(volatile uint32_t*)(DMA_BASE + 0x30))
#define S2MM_DMASR      (*(volatile uint32_t*)(DMA_BASE + 0x34))
#define S2MM_DA         (*(volatile uint32_t*)(DMA_BASE + 0x48))
#define S2MM_LENGTH     (*(volatile uint32_t*)(DMA_BASE + 0x58))

#define DMA_RX_BRAM     0x80004000
#define DMA_TX_BRAM     0x80005000
#define EXPECTED_POINTS     256
#define EXPECTED_FFT_POINTS 128

// FFT working buffers — static so they don't go on the stack
static int32_t fft_re[FFT_N];
static int32_t fft_im[FFT_N];

void main() {
    uart_puts("\n\r[BOOT] DMA ethernet FFT starting\n\r");

    int32_t* rx = (int32_t*)DMA_RX_BRAM;
    int32_t* tx = (int32_t*)DMA_TX_BRAM;

    while(1) {
        // ===== ARM RX =====
        S2MM_DMACR = 0x00000004;
        while(S2MM_DMACR & 0x00000004);
        S2MM_DMACR  = 0x00000001;
        S2MM_DA     = DMA_RX_BRAM;
        S2MM_LENGTH = 1500;

        // ===== WAIT FOR PACKET =====
        while(!(S2MM_DMASR & 0x1000));
        S2MM_DMASR = 0x1000;

        // ===== LOAD INTO FFT BUFFERS =====
        // scale input from int32 to Q1.15 range to avoid overflow
        for (int i = 0; i < FFT_N; i++) {
            fft_re[i] = rx[i] >> 16;   // scale down int32 → Q1.15 range
            fft_im[i] = 0;
        }

        // ===== RUN FFT =====
        fft(fft_re, fft_im);

        // ===== COMPUTE MAGNITUDES INTO TX =====
        fft_magnitude(fft_re, fft_im, tx);

        // ===== SEND =====
        MM2S_DMACR = 0x00000004;
        while(MM2S_DMACR & 0x00000004);
        MM2S_DMACR  = 0x00000001;
        MM2S_SA     = DMA_TX_BRAM;
        MM2S_LENGTH = EXPECTED_FFT_POINTS * sizeof(int32_t);

        while(!(MM2S_DMASR & 0x1000));
        MM2S_DMASR = 0x1000;
    }
}