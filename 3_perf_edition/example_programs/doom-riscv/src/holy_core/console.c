/*
 * console.c
 *
 * Copyright (C) 2019-2021 Sylvain Munaut
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

// BRH modified 11/12 : adapted for HOLY CORE port

#include <stdint.h>

#include "config.h"
#include "mini-printf.h"
#include "holycore.h"
#include "holy_core_soc.h"

void console_init(void) {}

void console_putchar(char c) {
  uart_putchar(c);
  // little workaround for better console output
  if(c == '\n') uart_putchar('\r');
}

char console_getchar(void) {
  int32_t c;
  do {
    c = RX_FIFO;
  } while (c <= 0);
  return c;
}

int console_getchar_nowait(void) {
  int32_t c = RX_FIFO;
  // holy core : we get uart RX status as well
  // to check if he char is valid
  int32_t status = UART_STATUS;
  return (status & (1 << 0)) ? (c & 0xff) : -1;
}

void console_puts(const char *p) {
  char c;
  while ((c = *(p++)) != 0x00)
    console_putchar(c);
}

int console_printf(const char *fmt, ...) {
  static char _printf_buf[128];
  va_list va;
  int l;

  va_start(va, fmt);
  l = mini_vsnprintf(_printf_buf, 128, fmt, va);
  va_end(va);

  console_puts(_printf_buf);

  return l;
}
