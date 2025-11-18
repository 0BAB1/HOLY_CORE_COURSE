/*
 * libc_backend.c
 *
 * Minimal implementation of libc backend to support what DOOM uses
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


#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <unistd.h>

#include "config.h"
#include "console.h"


#define LIBC_DEBUG


// HEAP handling
// -------------

extern uint8_t _heap_start;
extern uint8_t _binary_doom1_wad_start;

void *
_sbrk(intptr_t increment)
{
    static void* heap_end = &_heap_start;
    void *rv = heap_end;
    heap_end += increment;
#ifdef LIBC_DEBUG
    console_printf("Heap extended to %08x\n\r", (uint32_t)heap_end);
#endif
    return rv;
}


// File handling
// -------------

/* Flash "filesystem" */
static struct {
    const char *name;	/* Filename */
    size_t      len;	/* Length */
    void *      addr;	/* Address in flash */
} fs[] = {
    { "doom1.wad", 4196020, (void*)&_binary_doom1_wad_start },
    { NULL }
};


#define NUM_FDS		16

static struct {
    enum {
        FD_NONE  = 0,
        FD_STDIO = 1,
        FD_FLASH = 2,
    } type;
    size_t offset;
    size_t len;
    void   *data;
} fds[NUM_FDS] = {
    [0] = {
        .type = FD_STDIO,
    },
    [1] = {
        .type = FD_STDIO,
    },
    [2] = {
        .type = FD_STDIO,
    },
};

int
_open(const char *pathname, int flags)
{
    int fn, fd;

    /* Try to find file */
    for (fn=0; fs[fn].name; fn++)
        if (!strcmp(pathname, fs[fn].name))
            break;

    if (!fs[fn].name) {
        errno = ENOENT;
        return -1;
    }

    /* Find free FD */
    for (fd=3; (fd<NUM_FDS) && (fds[fd].type != FD_NONE); fd++);
    if (fd == NUM_FDS) {
        errno = ENOMEM;
        return -1;
    }

    /* "Open" file */
    fds[fd].type   = FD_FLASH;
    fds[fd].offset = 0;
    fds[fd].len    = fs[fn].len;
    fds[fd].data   = fs[fn].addr;

    console_printf("Opened: %s as fd=%d\n", pathname, fd);

    return fd;
}

ssize_t
_read(int fd, void *buf, size_t nbyte)
{
    if ((fd < 0) || (fd >= NUM_FDS) || (fds[fd].type != FD_FLASH)) {
        errno = EINVAL;
        return -1;
    }

    if ((fds[fd].offset + nbyte) > fds[fd].len)
        nbyte = fds[fd].len - fds[fd].offset;

    memcpy(buf, fds[fd].data + fds[fd].offset, nbyte);
    fds[fd].offset += nbyte;

    return nbyte;
}

ssize_t
_write(int fd, const void *buf, size_t nbyte)
{
    const unsigned char *c = buf;
    for (int i=0; i<nbyte; i++)
        console_putchar(*c++);
    return nbyte;
}

int
_close(int fd)
{
    if ((fd < 0) || (fd >= NUM_FDS)) {
        errno = EINVAL;
        return -1;
    }

    fds[fd].type = FD_NONE;

    return 0;
}

off_t
_lseek(int fd, off_t offset, int whence)
{
    size_t new_offset;

    if ((fd < 0) || (fd >= NUM_FDS) || (fds[fd].type != FD_FLASH)) {
        errno = EINVAL;
        return -1;
    }

    switch (whence) {
    case SEEK_SET:
        new_offset = offset;
        break;
    case SEEK_CUR:
        new_offset = fds[fd].offset + offset;
        break;
    case SEEK_END:
        new_offset = fds[fd].len - offset;
        break;
    default:
        errno = EINVAL;
        return -1;
    }

    if ((new_offset < 0) || (new_offset > fds[fd].len)) {
        errno = EINVAL;
        return -1;
    }

    fds[fd].offset = new_offset;

    return new_offset;
}

int
_stat(const char *filename, struct stat *statbuf)
{
    /* Not implemented */
#ifdef LIBC_DEBUG
    console_printf("[1] Unimplemented _stat(filename=\"%s\")\n", filename);
#endif

    return -1;
}

int
_fstat(int fd, struct stat *statbuf)
{
    /* Not implemented */
#ifdef LIBC_DEBUG
    console_printf("[1] Unimplemented _fstat(fd=%d)\n", fd);
#endif

    return -1;
}

int
_isatty(int fd)
{
    /* Only stdout and stderr are TTY */
    errno = 0;
    return (fd == 1) || (fd == 2);
}

int
access(const char *pathname, int mode)
{
    int fn;

    /* Try to find file */
    for (fn=0; fs[fn].name; fn++)
        if (!strcmp(pathname, fs[fn].name))
            break;

    if (!fs[fn].name) {
        errno = ENOENT;
        return -1;
    }

    /* Check requested access */
    if (mode & ~(R_OK | F_OK)) {
        errno = EACCES;
        return -1;
    }

    return 0;
}
