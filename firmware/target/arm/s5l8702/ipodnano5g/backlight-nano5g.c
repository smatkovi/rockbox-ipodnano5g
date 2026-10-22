/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2026 Sebastian Matkovich
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
#include <stdbool.h>
#include "config.h"
#include "backlight.h"
#include "backlight-target.h"

/* Bring-up: the backlight is driven by the PMU, which is not identified
 * yet. Apple's WTF stage leaves it on, and it stays on. */

void backlight_hw_brightness(int brightness)
{
    (void)brightness;
}

void backlight_hw_on(void)
{
}

void backlight_hw_off(void)
{
}

bool backlight_hw_init(void)
{
    return true;
}

void backlight_hw_kill(void)
{
}
