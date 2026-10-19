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
#ifndef NANO4G_EARLY_INIT_H
#define NANO4G_EARLY_INIT_H

/* Called in SRAM with IRQ/FIQ, MMU and caches disabled and a valid SRAM stack.
 * Sets up 32 MiB SDRAM at 0x08000000. Zero means success. A negative result
 * identifies the failed stage; the caller must not access SDRAM on failure.
 */
enum nano4g_init_error
{
    NANO4G_INIT_CLOCK = -1,
    NANO4G_INIT_TIMER = -2,
    NANO4G_INIT_GPIO = -3,
    NANO4G_INIT_I2C = -4,
    NANO4G_INIT_PMU = -5,
    NANO4G_INIT_SDRAM = -6,
    NANO4G_INIT_POWER_CLOCK = -7
};

int rockbox_early_init(void);

#endif
