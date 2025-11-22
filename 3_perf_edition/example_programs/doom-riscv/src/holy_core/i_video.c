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

#include <stdint.h>
#include <string.h>

#include "doomdef.h"

#include "i_system.h"
#include "i_video.h"
#include "v_video.h"

#include "config.h"

#include "holycore.h"

uint32_t pal[256];

void I_InitGraphics(void) {
  /* Don't need to do anything really ... */

  /* Ok, maybe just set gamma default */
  usegamma = 1;
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

  
  /* Simple UART send */
  for (int y = 0; y < SCREENHEIGHT; y++) {
    for (int x = 0; x < SCREENWIDTH; x++) {
      uint8_t pixel = screens[0][y * SCREENWIDTH + x];
      if(pixel > 128){
        // white
        uart_putchar('#');
      }else{
        // black
        uart_putchar(' ');
      }
    }
    uart_puts("\n\r");  // New line after each row
  }

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
