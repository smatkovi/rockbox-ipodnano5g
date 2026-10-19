/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright 2010 TheSeven
 * Copyright (C) 2026 Viktor Krapivin
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ****************************************************************************/

/* GID header authentication. */
#include "hardware.h"
#define AES(off) REG32(0x38c00000u + (off))

int encrypt_header(uint8_t data[16])
{
    REG32(0x3c500048) &= ~(1u << 7);
    for (unsigned i = 0; i < 4; i++)
        AES(0x74 + 4 * i) = 0;
    AES(0x08) = 1;
    AES(0x08) = 0;
    AES(0x00) = 1;
    AES(0x10) = 0;
    AES(0x6c) = 1; /* hardware GID key */
    AES(0x88) = ~AES(0x6c);
    AES(0x8c) = 0;
    AES(0x14) = 0xf; /* encrypt */
    AES(0x18) = 16;
    AES(0x20) = (uintptr_t)data;
    AES(0x24) = 16;
    AES(0x28) = (uintptr_t)data;
    AES(0x2c) = 16;
    AES(0x30) = (uintptr_t)data;
    AES(0x34) = 16;
    AES(0x04) = 1;
    uint32_t start = now_us();
    unsigned budget = 10000000;
    while (!(AES(0x0c) & 0xf))
    {
        if (!--budget || (uint32_t)(now_us() - start) >= 100000)
        {
            REG32(0x3c500048) |= 1u << 7;
            return ERROR_TIMEOUT;
        }
    }
    REG32(0x3c500048) |= 1u << 7;
    return RESULT_OK;
}
