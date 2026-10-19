/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
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
#include "hardware.h"

bool wait_mask(uintptr_t reg, uint32_t mask, uint32_t value)
{
    uint32_t start = now_us();
    unsigned budget = 10000000;
    do
    {
        if ((REG32(reg) & mask) == value)
            return true;
    } while (--budget && (uint32_t)(now_us() - start) < 100000);
    return false;
}

void delay_us(uint32_t usec)
{
    uint32_t start = now_us();
    unsigned budget = 10000000;
    while (--budget && (uint32_t)(now_us() - start) < usec)
    {
    }
}

void *memcpy(void *dst, const void *src, size_t n)
{
    uint8_t *d = dst;
    const uint8_t *s = src;
    while (n--)
        *d++ = *s++;
    return dst;
}

void *memset(void *dst, int value, size_t n)
{
    uint8_t *d = dst;
    while (n--)
        *d++ = value;
    return dst;
}

int memcmp(const void *a, const void *b, size_t n)
{
    const uint8_t *x = a, *y = b;
    while (n--)
    {
        if (*x != *y)
            return *x - *y;
        x++;
        y++;
    }
    return 0;
}

uint32_t crc_update(uint32_t crc, const uint8_t *data, size_t n)
{
    while (n--)
    {
        crc ^= *data++;
        for (unsigned bit = 0; bit < 8; bit++)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1)));
    }
    return crc;
}
