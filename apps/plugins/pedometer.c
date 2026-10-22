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

/* Pedometer: counts steps from the accelerometer while it runs.
 *
 * The magnitude of the acceleration, smoothed, swings around its slow
 * average with every step. A step is a rise above +THRESHOLD after a dip
 * below -THRESHOLD/2, at most one per MIN_STEP_TICKS.
 *
 * SELECT resets the count, the exit button quits. */

#include "plugin.h"
#include "lib/pluginlib_actions.h"
#include "lib/helper.h"

#define SAMPLE_TICKS    2           /* 50 Hz at HZ = 100 */
#define THRESHOLD       90          /* mg */
#define MIN_STEP_TICKS  (HZ / 4)    /* at most 4 steps per second */
#define STEP_LENGTH_CM  70

static const struct button_mapping *plugin_contexts[] = { pla_main_ctx };

static unsigned int isqrt(unsigned int v)
{
    unsigned int r = 0, bit = 1u << 30;

    while (bit > v)
        bit >>= 2;
    while (bit)
    {
        if (v >= r + bit)
        {
            v -= r + bit;
            r = (r >> 1) + bit;
        }
        else
            r >>= 1;
        bit >>= 2;
    }
    return r;
}

static void draw(unsigned long steps, long start, int x, int y, int z,
                 int dev, bool sensor)
{
    long secs = (*rb->current_tick - start) / HZ;
    unsigned long cm = steps * STEP_LENGTH_CM;

    rb->lcd_clear_display();
    rb->lcd_puts(0, 0, "Pedometer");
    if (!sensor)
    {
        rb->lcd_puts(0, 2, "No accelerometer found");
        rb->lcd_update();
        return;
    }
    rb->lcd_putsf(0, 2, "Steps: %lu", steps);
    rb->lcd_putsf(0, 3, "Distance: %lu.%02lu km", cm / 100000,
                  (cm / 1000) % 100);
    rb->lcd_putsf(0, 4, "Time: %ld:%02ld", secs / 60, secs % 60);
    if (secs > 0)
        rb->lcd_putsf(0, 5, "Steps/min: %ld", (long)(steps * 60 / secs));
    rb->lcd_putsf(0, 7, "x %5d y %5d z %5d mg", x, y, z);
    rb->lcd_putsf(0, 8, "swing %4d mg", dev);
    rb->lcd_puts(0, 10, "SELECT: reset");
    rb->lcd_update();
}

enum plugin_status plugin_start(const void* parameter)
{
    unsigned long steps = 0;
    long start = *rb->current_tick, last_step = 0, next_draw = 0;
    int x = 0, y = 0, z = 0, smooth = 1000, base = 1000, dev = 0;
    bool armed = false, sensor;

    (void)parameter;
    sensor = rb->accel_read(&x, &y, &z) == 0;
    rb->lcd_setfont(FONT_SYSFIXED);
    backlight_ignore_timeout();

    while (true)
    {
        int action = pluginlib_getaction(SAMPLE_TICKS, plugin_contexts,
                                         ARRAYLEN(plugin_contexts));
        if (action == PLA_EXIT || action == PLA_CANCEL)
            break;
        if (action == PLA_SELECT)
        {
            steps = 0;
            start = *rb->current_tick;
        }

        if (sensor && rb->accel_read(&x, &y, &z) == 0)
        {
            int mag = isqrt(x * x + y * y + z * z);
            smooth += (mag - smooth) / 4;
            base += (mag - base) / 32;
            dev = smooth - base;
            if (dev < -THRESHOLD / 2)
                armed = true;
            else if (armed && dev > THRESHOLD
                     && TIME_AFTER(*rb->current_tick,
                                   last_step + MIN_STEP_TICKS))
            {
                steps++;
                armed = false;
                last_step = *rb->current_tick;
            }
        }

        if (TIME_AFTER(*rb->current_tick, next_draw))
        {
            draw(steps, start, x, y, z, dev, sensor);
            next_draw = *rb->current_tick + HZ / 5;
        }
    }

    backlight_use_settings();
    rb->lcd_setfont(FONT_UI);
    return PLUGIN_OK;
}
