/*
 * i_net.c
 *
 * Dummy net code
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

#include <stdlib.h>

#include "doomstat.h"
#include "d_net.h"
#include "i_net.h"

void
I_InitNetwork (void)
{
	// Base init
	doomcom = calloc(1, sizeof(*doomcom));
	doomcom->ticdup = 1;

	// Single player
	netgame = false;

	doomcom->id = DOOMCOM_ID;
	doomcom->numplayers = doomcom->numnodes = 1;
	doomcom->deathmatch = false;
	doomcom->consoleplayer = 0;
}

void
I_NetCmd (void)
{
	/* No network ... */
}
