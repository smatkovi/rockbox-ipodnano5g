/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2009 by Bertrik Sikken
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

#include "config.h"

#include "inttypes.h"
#include "s5l87xx.h"
#include "adc.h"
#include "adc-target.h"
#include "pmu-target.h"
#include "kernel.h"
#include "system.h"

static struct mutex adc_mutex;
static int battery_millivolts = -1;

static void adc_convert_battery(void)
{
    unsigned char control, result[2];

    /* D1759 channel 4 measures the battery over the 2500..4500 mV range.
     * Bit 4 starts a conversion and clears when the result is ready.
     * The caller holds adc_mutex for the entire conversion, not only for the
     * individual I2C reads. */
    if (pmu_write(0x40, 0x54) == 0)
    {
        for (int tries = 0; tries < 20; tries++)
        {
            if (pmu_read_multiple(0x40, 1, &control) != 0)
                break;
            if (!(control & 0x10))
            {
                if (pmu_read_multiple(0x41, 2, result) == 0)
                {
                    unsigned int raw = (result[1] << 2) | (result[0] & 3);
                    battery_millivolts = 2500 + raw * 2000 / 1023;
                }
                break;
            }
            udelay(100);
        }
        /* back to the idle input, as the original firmware does after
         * every conversion; the charger shares this converter */
        pmu_write(0x40, 0x40);
    }
}

/* Returns battery voltage [millivolts] */
unsigned int adc_read_battery_voltage(void)
{
    mutex_lock(&adc_mutex);

    /* A transient conversion/read error must not turn a previously healthy
     * battery into a zero-volt sample in the power-management filter: keep
     * the last valid reading. Without one yet, retry, or power management
     * would take a failed first sample for an empty battery. */
    for (int attempt = 0; attempt < 10; attempt++)
    {
        adc_convert_battery();
        if (battery_millivolts > 0)
            break;
    }
    int millivolts = battery_millivolts;
    mutex_unlock(&adc_mutex);
    return millivolts;
}

/* API functions */
unsigned short adc_read(int channel)
{
    (void) channel;
    return 0;
}

int adc_read_accessory_resistor(void)
{
    return 0;
}

unsigned int adc_read_usbdata_voltage(bool dp)
{
    (void)dp;
    return 0;
}

const char *adc_name(int channel)
{
    (void) channel;
    return "";
}

void adc_init(void)
{
    mutex_init(&adc_mutex);
}
