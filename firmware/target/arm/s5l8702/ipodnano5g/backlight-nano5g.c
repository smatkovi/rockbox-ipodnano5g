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
#include "pmu-target.h"

/* D1759 LED driver. Apple leaves LEDCTL = 0x01, LEDOUT = 0xa0. LEDOUT
 * (0..255) is written over the SWIF link, as Apple's diags do on this model
 * (I2C writes to it are ignored); off is level 0, like the diags' "-f". */

static int backlight_level = DEFAULT_BRIGHTNESS_SETTING << 2;
static bool backlight_is_on = true;

void backlight_hw_brightness(int brightness)
{
    backlight_level = brightness << 2;
    if (backlight_is_on)
        pmu_swif_write(D1759_SWIF_LEDOUT, backlight_level);
}

void backlight_hw_on(void)
{
    backlight_is_on = true;
    pmu_swif_write(D1759_SWIF_LEDOUT, backlight_level);
}

void backlight_hw_off(void)
{
    backlight_is_on = false;
    pmu_swif_write(D1759_SWIF_LEDOUT, 0);
}

bool backlight_hw_init(void)
{
    backlight_hw_brightness(DEFAULT_BRIGHTNESS_SETTING);
    backlight_hw_on();
    return true;
}

/* Kill the backlight, instantly. */
void backlight_hw_kill(void)
{
    backlight_hw_off();
}
