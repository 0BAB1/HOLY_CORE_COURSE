/*
 * i_system.c
 *
 * System support code
 *
 * Copyright (C) 1993-1996 by id Software, Inc.
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


#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "doomdef.h"
#include "doomstat.h"

#include "d_main.h"
#include "g_game.h"
#include "m_misc.h"
#include "i_sound.h"
#include "i_video.h"

#include "i_system.h"

#include "console.h"
#include "config.h"

// BRH modified 11/12 : adapted for HOLY CORE port


volatile uint64_t* mtime = CLINT_MTIME;

void
I_Init(void)
{
}


byte *
I_ZoneBase(int *size)
{
    /* Give 6M to DOOM */
    *size = 6 * 1024 * 1024;
    return (byte *) malloc (*size);
}

// holy core :  get lower 32 bits of mtime
// ticks run at 35Hz
int
I_GetTime(void)
{
  uint32_t time = (*mtime / 1000) / 32 / 1000;
  return time;
}

int
I_GetMTime(void)
{
  uint32_t time = *mtime;
  return time;
}

static void
I_GetRemoteEvent(void)
{
    event_t event;

    static byte ascii_map[128]; // maps ASCII codes to Doom keys
    static int init_map_done = 0;

    if (!init_map_done) {
    memset(ascii_map, 0, sizeof(ascii_map));
        ascii_map['z'] = KEY_UPARROW;
        ascii_map['s'] = KEY_DOWNARROW;
        ascii_map['q'] = KEY_LEFTARROW;
        ascii_map['d'] = KEY_RIGHTARROW;
        ascii_map[' '] = KEY_RCTRL;   // fire
        ascii_map['e'] = KEY_ENTER;   // menu select
        ascii_map['a'] = KEY_ESCAPE;  // menu back
        init_map_done = 1;
    }

    static byte s_btn = 0;

    boolean mupd = false;
    int mdx = 0;
    int mdy = 0;

    while (1) {
        int ch = console_getchar_nowait();
        if (ch == -1)
            break;

        byte doomkey = ascii_map[ch];
        if (doomkey) {
            event.type = ev_keydown;
            event.data1 = doomkey;
            D_PostEvent(&event);
        }
    }

    if (mupd) {
        event.type = ev_mouse;
        event.data1 = s_btn;
        event.data2 =   mdx << 2;
        event.data3 = - mdy << 2;	/* Doom is sort of inverted ... */
        D_PostEvent(&event);
    }
}

void
I_StartFrame(void)
{
    /* Nothing to do */
}

void
I_StartTic(void)
{
    I_GetRemoteEvent();
}

ticcmd_t *
I_BaseTiccmd(void)
{
    static ticcmd_t emptycmd;
    return &emptycmd;
}


void
I_Quit(void)
{
    D_QuitNetGame();
    M_SaveDefaults();
    I_ShutdownGraphics();
    exit(0);
}


byte *
I_AllocLow(int length)
{
    byte*	mem;
    mem = (byte *)malloc (length);
    memset (mem,0,length);
    return mem;
}


void
I_Tactile
( int on,
  int off,
  int total )
{
    // UNUSED.
    on = off = total = 0;
}


void
I_Error(char *error, ...)
{
    va_list	argptr;

    // Message first.
    va_start (argptr,error);
    fprintf (stderr, "Error: ");
    vfprintf (stderr,error,argptr);
    fprintf (stderr, "\n");
    va_end (argptr);

    fflush( stderr );

    // Shutdown. Here might be other errors.
    if (demorecording)
        G_CheckDemoStatus();

    D_QuitNetGame ();
    I_ShutdownGraphics();

    exit(-1);
}
