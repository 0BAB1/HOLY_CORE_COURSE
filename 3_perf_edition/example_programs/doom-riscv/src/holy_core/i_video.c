/*
 * i_video.c
 *
 * Video system support code
 *
 * Copyright (C) 2021 Sylvain Munaut
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

/* HOLY CORE PORT STUFF : TODO, cleanup in header files */
#include <stdint.h>
#include <string.h>

#include "doomdef.h"

#include "i_system.h"
#include "i_video.h"
#include "v_video.h"

#include "config.h"

#include "holycore.h"
#include "holy_core_soc.h"

/* =============================================================================
 * AXI QSPI Registers
 * ============================================================================= */

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

void debug_dump_regs(void) {
    printf("=== REGISTER DUMP ===\n\r");
    printf("GPIO2_TRI:  0x%08X\n\r", GPIO2_TRI);
    printf("GPIO2_DATA: 0x%08X\n\r", GPIO2_DATA);
    printf("SPI_STATUS: 0x%08X\n\r", SPI_STATUS);
    printf("SPI_CONTROL: 0x%08X\n\r", SPI_CONTROL);
    printf("SPI_SS:     0x%08X\n\r", SPI_SS);
    printf("=====================\n\r");
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

    /* Flush RX FIFO by reading */
    while (!(SPI_STATUS & 0x01)) {  /* While RX not empty */
        volatile uint32_t dummy = SPI_RX;
        (void)dummy;
    }
    
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
            while (SPI_STATUS & SPI_SR_TX_FULL);
            SPI_TX = hi;
            while (SPI_STATUS & SPI_SR_TX_FULL);
            SPI_TX = lo;
        }
    }
    SPI_SS = 0xFFFFFFFF;
}

void lcd_fill_screen(uint16_t color) {
    lcd_fill_rect(0, 0, 240, 320, color);
}

uint32_t pal[256];

void I_InitGraphics(void) {
    // init tft screen and check it works fine
    lcd_init();
    lcd_fill_screen(COLOR_RED);
}
void I_ShutdownGraphics(void) { /* Don't need to do anything really ... */ }

void I_SetPalette(byte *palette) {
  byte r, g, b;

  for (int i = 0; i < 256; i++) {
    r = gammatable[usegamma][*palette++];
    g = gammatable[usegamma][*palette++];
    b = gammatable[usegamma][*palette++];
    pal[i] =
        ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b | 0xff << 24;
  }
}

void I_UpdateNoBlit(void) {}

uint32_t frameGenStart = 0;
uint32_t frameGenEnd = 0;

void I_FinishUpdate(void) {
    frameGenEnd = I_GetMTime();

    #define OUT_WIDTH  160
    #define OUT_HEIGHT 100
    
    lcd_set_window(0, 0, OUT_HEIGHT - 1, OUT_WIDTH - 1);

    GPIO2_DATA |= PIN_DC;
    SPI_SS = 0xFFFFFFFE;

    /* Pre-compute palette to RGB565 once */
    static uint16_t pal565[256];
    static int pal_ready = 0;
    
    if (!pal_ready) {
        for (int i = 0; i < 256; i++) {
            uint32_t rgb = pal[i];
            uint8_t r = (rgb >> 16) & 0xFF;
            uint8_t g = (rgb >> 8) & 0xFF;
            uint8_t b = rgb & 0xFF;
            pal565[i] = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
        }
        pal_ready = 1;
    }

    /* Send pixels - skip every other row and column (4x fewer pixels) */
    for (int x = 0; x < SCREENWIDTH; x += 2) {
        for (int y = SCREENHEIGHT - 2; y >= 0; y -= 2) {
            uint8_t pixel = screens[0][y * SCREENWIDTH + x];
            uint16_t color = pal565[pixel];
            
            while (SPI_STATUS & SPI_SR_TX_FULL);
            SPI_TX = color >> 8;
            while (SPI_STATUS & SPI_SR_TX_FULL);
            SPI_TX = color & 0xFF;
        }
    }

    spi_wait();
    SPI_SS = 0xFFFFFFFF;

    printf("Num cycles to render this frame: %d\n\r", frameGenEnd - frameGenStart);
    frameGenStart = I_GetMTime();
}

void I_WaitVBL(int count) {
  #if 0
  return;
  /* Buys-Wait for VBL status bit */
  static volatile uint32_t *const video_state = (void *)(VID_CTRL_BASE);
  while (!(video_state[0] & (1 << 16)))
    ;
  #endif
}

void I_ReadScreen(byte *scr) {
  /* FIXME: Would have though reading from VID_BASE be better ...
   *        but it seems buggy. Not sure if the problem is in the
   *        gateware
   */
  memcpy(scr, screens[0], SCREENHEIGHT * SCREENWIDTH);
}

#if 0 /* WTF ? Not used ... */
void
I_BeginRead(void)
{
}

void
I_EndRead(void)
{
}
#endif
