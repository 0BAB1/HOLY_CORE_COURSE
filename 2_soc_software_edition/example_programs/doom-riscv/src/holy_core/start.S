/*
 * start.S
 *
 * Startup code
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

    .section .text.start
    .global _start
_start:

    // Set stack pointer
    la sp, __stacktop

    // holy core exception handler
    la t0, trap_handler
    csrw mtvec, t0

    // zero out the .bss section in the start code
    // because GDB won't load .bss (which is all zeroes)
    call init_bss

    // call main
    call main

init_bss:
    la t0, _sbss
    la t1, _ebss
    li t2, 0
bss_loop:
    bgeu t0, t1, bss_done
    sw t2, 0(t0)
    addi t0, t0, 4
    j bss_loop
bss_done:
    ret

.global	_exit
_exit:
    j _exit