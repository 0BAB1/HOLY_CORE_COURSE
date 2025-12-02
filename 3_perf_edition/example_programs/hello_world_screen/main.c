#include <stdint.h>
#include "holycore.h"

/* =============================================================================
 * AXI QSPI Registers
 * ============================================================================= */
#define SPI_BASE                0x10030000
#define SPI_SOFT_RESET          (*(volatile uint32_t *)(SPI_BASE + 0x40))
#define SPI_CONTROL             (*(volatile uint32_t *)(SPI_BASE + 0x60))
#define SPI_STATUS              (*(volatile uint32_t *)(SPI_BASE + 0x64))
#define SPI_TX                  (*(volatile uint32_t *)(SPI_BASE + 0x68))
#define SPI_SS                  (*(volatile uint32_t *)(SPI_BASE + 0x70))

#define SPI_CR_SPE              (1 << 1)
#define SPI_CR_MASTER           (1 << 2)
#define SPI_CR_TX_FIFO_RESET    (1 << 5)
#define SPI_CR_RX_FIFO_RESET    (1 << 6)
#define SPI_CR_MANUAL_SS        (1 << 7)
#define SPI_SR_TX_EMPTY         (1 << 2)
#define SPI_SR_TX_FULL          (1 << 3)

/* =============================================================================
 * GPIO2 for DC and RESET
 * ============================================================================= */
#define GPIO2_DATA              (*(volatile uint32_t *)0x10010008)
#define GPIO2_TRI               (*(volatile uint32_t *)0x1001000C)

#define PIN_DC                  (1 << 0)
#define PIN_RESET               (1 << 1)

/* =============================================================================
 * ILI9341 Commands
 * ============================================================================= */
#define ILI9341_SWRESET         0x01
#define ILI9341_SLPOUT          0x11
#define ILI9341_DISPON          0x29
#define ILI9341_CASET           0x2A
#define ILI9341_PASET           0x2B
#define ILI9341_RAMWR           0x2C
#define ILI9341_MADCTL          0x36
#define ILI9341_COLMOD          0x3A

/* Colors (RGB565) */
#define COLOR_BLACK             0x0000
#define COLOR_RED               0xF800
#define COLOR_GREEN             0x07E0
#define COLOR_BLUE              0x001F
#define COLOR_WHITE             0xFFFF

/* =============================================================================
 * Helper Functions
 * ============================================================================= */
static void delay_ms(uint32_t ms) {
    for (volatile uint32_t i = 0; i < ms; i++);
}

static void spi_send(uint8_t data) {
    while (SPI_STATUS & SPI_SR_TX_FULL);
    SPI_TX = data;
}

static void spi_wait(void) {
    while (!(SPI_STATUS & SPI_SR_TX_EMPTY));
}

static void lcd_cmd(uint8_t cmd) {
    GPIO2_DATA &= ~PIN_DC;          /* DC = 0 (command) */
    SPI_SS = 0xFFFFFFFE;            /* CS low */
    spi_send(cmd);
    spi_wait();
    SPI_SS = 0xFFFFFFFF;            /* CS high */
}

static void lcd_data(uint8_t data) {
    GPIO2_DATA |= PIN_DC;           /* DC = 1 (data) */
    SPI_SS = 0xFFFFFFFE;
    spi_send(data);
    spi_wait();
    SPI_SS = 0xFFFFFFFF;
}

/* =============================================================================
 * ILI9341 Functions
 * ============================================================================= */
void lcd_init(void) {
    /* GPIO2: Set DC and RESET as outputs */
    GPIO2_TRI &= ~(PIN_DC | PIN_RESET);
    
    /* Hardware reset */
    GPIO2_DATA &= ~PIN_RESET;       /* RESET low */
    delay_ms(1000);
    GPIO2_DATA |= PIN_RESET;        /* RESET high */
    delay_ms(12000);
    
    /* SPI init */
    SPI_SOFT_RESET = 0x0000000A;
    SPI_CONTROL = SPI_CR_MASTER | SPI_CR_SPE | SPI_CR_MANUAL_SS |
                  SPI_CR_TX_FIFO_RESET | SPI_CR_RX_FIFO_RESET;
    SPI_CONTROL = SPI_CR_MASTER | SPI_CR_SPE | SPI_CR_MANUAL_SS;
    
    /* Software reset */
    lcd_cmd(ILI9341_SWRESET);
    delay_ms(15000);
    
    /* Sleep out */
    lcd_cmd(ILI9341_SLPOUT);
    delay_ms(15000);
    
    /* Pixel format: 16-bit */
    lcd_cmd(ILI9341_COLMOD);
    lcd_data(0x55);
    
    /* Memory access control */
    lcd_cmd(ILI9341_MADCTL);
    lcd_data(0x48);
    
    /* Display ON */
    lcd_cmd(ILI9341_DISPON);
    delay_ms(10000);
}

void lcd_set_window(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1) {
    lcd_cmd(ILI9341_CASET);
    lcd_data(x0 >> 8); lcd_data(x0 & 0xFF);
    lcd_data(x1 >> 8); lcd_data(x1 & 0xFF);
    
    lcd_cmd(ILI9341_PASET);
    lcd_data(y0 >> 8); lcd_data(y0 & 0xFF);
    lcd_data(y1 >> 8); lcd_data(y1 & 0xFF);
    
    lcd_cmd(ILI9341_RAMWR);
}

void lcd_fill_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint16_t color) {
    lcd_set_window(x, y, x + w - 1, y + h - 1);
    
    GPIO2_DATA |= PIN_DC;
    SPI_SS = 0xFFFFFFFE;
    
    uint8_t hi = color >> 8;
    uint8_t lo = color & 0xFF;
    
    for (uint16_t row = 0; row < h; row++) {
        for (uint16_t col = 0; col < w; col++) {
            SPI_TX = hi;
            SPI_TX = lo;
        }
    }
    SPI_SS = 0xFFFFFFFF;
}

void lcd_fill_screen(uint16_t color) {
    lcd_fill_rect(0, 0, 240, 320, color);
}

/* =============================================================================
 * Main
 * ============================================================================= */
int main(void) {
    lcd_init();
    
    /* Clear screen */
    uart_puts("filling screen black\n\r");
    lcd_fill_screen(COLOR_BLACK);
    
    /* Draw a red horizontal line */
    uart_puts("red line\n\r");
    lcd_fill_rect(20, 100, 200, 2, COLOR_RED);
    
    /* Draw a green vertical line */
    uart_puts("green line\n\r");
    lcd_fill_rect(120, 50, 2, 220, COLOR_GREEN);
    
    /* Draw a blue square */
    uart_puts("green line\n\r");
    lcd_fill_rect(80, 140, 80, 80, COLOR_BLUE);
    
    while (1);
    
    return 0;
}