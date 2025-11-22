/*
 * i_sound.c
 *
 * Dummy sound code
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

#include "i_sound.h"


/* Sound */
/* ----- */

void
I_InitSound()
{
}

void
I_UpdateSound(void)
{
}

void
I_SubmitSound(void)
{
}

void
I_ShutdownSound(void)
{
}

void I_SetChannels(void)
{
}

int
I_GetSfxLumpNum(sfxinfo_t* sfxinfo)
{
	return 0;
}

int
I_StartSound
( int id,
  int vol,
  int sep,
  int pitch,
  int priority )
{
	return 0;
}

void
I_StopSound(int handle)
{
}

int
I_SoundIsPlaying(int handle)
{
	return 0;
}

void
I_UpdateSoundParams
( int handle,
  int vol,
  int sep,
  int pitch )
{
}


/* Music */
/* ----- */

void
I_InitMusic(void)
{
}

void
I_ShutdownMusic(void)
{
}

void
I_SetMusicVolume(int volume)
{
}

void
I_PauseSong(int handle)
{
}

void
I_ResumeSong(int handle)
{
}

int
I_RegisterSong(void *data)
{
	return 0;
}

void
I_PlaySong
( int handle,
  int looping )
{
}

void
I_StopSong(int handle)
{
}

void
I_UnRegisterSong(int handle)
{
}
