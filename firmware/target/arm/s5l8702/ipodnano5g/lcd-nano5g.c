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
#include <stdint.h>
#include "config.h"

#include "lcd-s5l8702.h"

/* Panel 38b3 (READ DISPLAY ID 0x04), 8080 parallel interface: commands in
 * the controller's 8-bit mode, RGB565 frames in its 9-bit mode. Apple's WTF
 * stage leaves the panel configured; waking it is enough to show frames. */
static const uint8_t lcd_init_seq_38b3[] =
{
    CMD,   0x11,  0,    /* Sleep Out */
    SLEEP, 12,          /* 120 ms */
    CMD,   0x29,  0,    /* Display On */
    SLEEP, 1,           /* 10 ms */
    END
};

enum {
    LCD_TYPE_38B3 = 0,
    N_LCD_TYPES
};

static struct lcd_info_rec lcd_info_list[] =
{
    [LCD_TYPE_38B3] = {
        .lcd_type   = LCD_TYPE_38B3,
        .mpuiface   = LCD_MPUIFACE_PAR9,
        .seq_init   = (void*) lcd_init_seq_38b3,
    },
};

uint8_t lcd_id[4];

struct lcd_info_rec* lcd_target_get_info(void)
{
    lcd_read_display_id(LCD_MPUIFACE_PAR9, lcd_id);

    /* The id is 0x38 followed by the panel type; on this controller the
     * reply can arrive one byte later than on the nano 4G (measured:
     * 04 00 38 b3), so accept either position */
    for (int i = 0; i < 3; i++)
        if (lcd_id[i] == 0x38 && lcd_id[i + 1] == 0xb3)
            return &lcd_info_list[LCD_TYPE_38B3];

    /* other panels (38c4, 38f7, 48c4 per freemyipod) are untested: drive
     * them like 38b3, which only wakes the panel */
    return &lcd_info_list[LCD_TYPE_38B3];
}
