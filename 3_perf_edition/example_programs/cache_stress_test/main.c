/*  DATA & CACHE STRESS TEST
*
*   BRH 12/2025
*   
*   Due to multiple data corruption problems on FPGA that I've not been
*   Able to reproduce in simulation, this test aims at provoking data corruption through
*   the data cache system using software only as a debug tool. The goal being
*   to test systems and pinpoint failures, see if a pattern shows up in failures and
*   reverse engineer the bug once and for all...
*
*   It uses RV32IM to compute addresses and traps (privleged M mode) to ease debugging.
*/

#include <stdint.h>
#include "holycore.h"
#include "holy_core_soc.h"

#define RAM_BASE 0x80001000
#define RAM_SIZE 0x10000
#define CACHE_LINE_SIZE 32
#define CACHE_SIZE 4096
#define NUM_WAYS 2

volatile uint32_t *ram = (volatile uint32_t *)RAM_BASE;

volatile uint32_t fail_addr;
volatile uint32_t fail_got;
volatile uint32_t fail_expected;

#define ASSERT_EQ_DEBUG(addr, got, expected) do { \
    if ((got) != (expected)) { \
        fail_addr = (uint32_t)(addr); \
        fail_got = (got); \
        fail_expected = (expected); \
        asm volatile ("ecall"); \
    } \
} while(0)


__attribute__((interrupt))
void trap_handler() {
    //debugger is almost mandatory to debug here
    uart_puts("Error Detected !\n\r");
    while (1);
}

void test_walking_ones(void) {
    for (int i = 0; i < RAM_SIZE / 4; i++) {
        for (int bit = 0; bit < 32; bit++) {
            uint32_t pattern = 1 << bit;
            ram[i] = pattern;
            uint32_t readback = ram[i];
            ASSERT_EQ_DEBUG(&ram[i], readback, pattern);
        }
    }
}

void test_simple(void) {
    uart_puts("Simple test...\n\r");
    
    // Write just 4 words
    ram[0] = 0xAAAA0000;
    ram[1] = 0xBBBB1111;
    ram[2] = 0xCCCC2222;
    ram[3] = 0xDDDD3333;
    
    // just read, really basic
    uart_puts("ram[0]="); uart_puthex(ram[0]); uart_puts("\n\r");
    uart_puts("ram[1]="); uart_puthex(ram[1]); uart_puts("\n\r");
    uart_puts("ram[2]="); uart_puthex(ram[2]); uart_puts("\n\r");
    uart_puts("ram[3]="); uart_puthex(ram[3]); uart_puts("\n\r");
}

void test_evict_refill(void) {
    uart_puts("Evict/refill test...\n\r");
    
    // Write to beginning of RAM
    ram[0] = 0xAAAA0000;
    ram[1] = 0xBBBB1111;
    ram[2] = 0xCCCC2222;
    ram[3] = 0xDDDD3333;
    
    // Force eviction by accessing conflicting addresses
    volatile uint32_t *conflict1 = (volatile uint32_t *)(RAM_BASE + 2048);
    volatile uint32_t *conflict2 = (volatile uint32_t *)(RAM_BASE + 4096);
    *conflict1 = 0x11111111;
    *conflict2 = 0x22222222;
    
    // Read back original locations (will refill from RAM)
    uart_puts("After eviction:\n\r");
    uart_puts("ram[0]="); uart_puthex(ram[0]); uart_puts("\n\r");
    uart_puts("ram[1]="); uart_puthex(ram[1]); uart_puts("\n\r");
    uart_puts("ram[2]="); uart_puthex(ram[2]); uart_puts("\n\r");
    uart_puts("ram[3]="); uart_puthex(ram[3]); uart_puts("\n\r");
}

void test_evict_refill_detailed(void) {
    uart_puts("Detailed test...\n\r");
    
    // Write pattern where each word is unique
    for (int i = 0; i < 16; i++) {
        ram[i] = 0x80001000 + (i * 4);  // Write address as data
    }
    
    // Force eviction
    volatile uint32_t *conflict1 = (volatile uint32_t *)(RAM_BASE + 2048);
    volatile uint32_t *conflict2 = (volatile uint32_t *)(RAM_BASE + 4096);
    *conflict1 = 0x11111111;
    *conflict2 = 0x22222222;
    
    // Read back entire cache line
    uart_puts("After eviction (first 16 words):\n\r");
    for (int i = 0; i < 16; i++) {
        uart_puts("ram[");
        uart_puthex(i);
        uart_puts("]=");
        uart_puthex(ram[i]);
        uart_puts(" expected=");
        uart_puthex(0x80001000 + (i * 4));
        uart_puts("\n\r");
    }
}

void test_address_as_data(void) {
    uart_puts("  Writing...\n\r");
    for (int i = 0; i < RAM_SIZE / 4; i++) {
        ram[i] = (uint32_t)&ram[i];
    }

    uart_puts("  Reading...\n\r");
    for (int i = 0; i < RAM_SIZE / 4; i++) {
        uint32_t readback = ram[i];
        if (readback != (uint32_t)&ram[i]) {
            uart_puts("  FAIL at i=");
            uart_puthex(i);
            uart_puts(" addr=");
            uart_puthex((uint32_t)&ram[i]);
            uart_puts(" got=");
            uart_puthex(readback);
            uart_puts("\n\r");
            while(1);
        }
    }
}

void test_checkerboard(void) {
    uint32_t patterns[] = {0x55555555, 0xAAAAAAAA, 0x00FF00FF, 0xFF00FF00};
    
    for (int p = 0; p < 4; p++) {
        for (int i = 0; i < RAM_SIZE / 4; i++) {
            ram[i] = patterns[p];
        }
        for (int i = 0; i < RAM_SIZE / 4; i++) {
            uint32_t readback = ram[i];
            ASSERT_EQ_DEBUG(&ram[i], readback, patterns[p]);
        }
    }
}

void test_cache_eviction(void) {
    int stride = CACHE_SIZE / NUM_WAYS;
    
    for (int iter = 0; iter < 10; iter++) {
        for (int way = 0; way <= NUM_WAYS; way++) {
            volatile uint32_t *addr = (volatile uint32_t *)(RAM_BASE + way * stride);
            *addr = 0xDEAD0000 | (iter << 8) | way;
        }
        
        for (int way = 0; way <= NUM_WAYS; way++) {
            volatile uint32_t *addr = (volatile uint32_t *)(RAM_BASE + way * stride);
            uint32_t expected = 0xDEAD0000 | (iter << 8) | way;
            uint32_t readback = *addr;
            ASSERT_EQ_DEBUG(addr, readback, expected);
        }
    }
}

void test_dirty_writeback(void) {
    for (int i = 0; i < 256; i++) {
        ram[i] = 0xCAFE0000 | i;
    }
    
    // Force eviction
    for (int i = 0; i < 256; i++) {
        volatile uint32_t *conflict = (volatile uint32_t *)(RAM_BASE + CACHE_SIZE + i * 4);
        *conflict = 0xBEEF0000 | i;
    }
    
    // Check writeback worked
    for (int i = 0; i < 256; i++) {
        uint32_t readback = ram[i];
        ASSERT_EQ_DEBUG(&ram[i], readback, 0xCAFE0000 | i);
    }
}

int main(void) {
    uart_puts("\n\r");
    uart_puts("=============================\n\r");
    uart_puts("Memory TX and D$ stress test\n\r");
    uart_puts("=============================\n\r");

    uart_puts("Testing walking ones...\n\r");
    test_walking_ones();
    uart_puts("PASS\n\r");

    uart_puts("Testing simple...\n\r");
    test_simple();
    uart_puts("\n\r\n\r");

    uart_puts("Testing evict refill...\n\r");
    test_evict_refill();
    uart_puts("\n\r\n\r");

    uart_puts("Testing evict refill detailled...\n\r");
    test_evict_refill_detailed();
    uart_puts("\n\r\n\r");

    uart_puts("Testing address as data...\n\r");
    test_address_as_data();
    uart_puts("PASS\n\r");

    uart_puts("Testing checkerboard...\n\r");
    test_checkerboard();
    uart_puts("PASS\n\r");

    uart_puts("Testing cache eviction...\n\r");
    test_cache_eviction();
    uart_puts("PASS\n\r");

    uart_puts("Testing dirty wb...\n\r");
    test_dirty_writeback();
    uart_puts("PASS\n\r");
    
    uart_puts("No error detected!\n\r");
    while (1);
}