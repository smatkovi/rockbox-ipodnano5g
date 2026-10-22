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
#include "adc.h"
#include "adc-target.h"
#include "pmu-target.h"
#include "kernel.h"

static struct mutex adc_mutex;
static int battery_millivolts = -1;

void adc_init(void)
{
    mutex_init(&adc_mutex);
}

unsigned short adc_read(int channel)
{
    (void)channel;
    return 0;
}

/* Returns battery voltage [millivolts]. A failed conversion keeps the last
 * valid reading, so one I2C error cannot look like an empty battery. */
unsigned int adc_read_battery_voltage(void)
{
    mutex_lock(&adc_mutex);
    for (int attempt = 0; attempt < 10; attempt++)
    {
        int mv = pmu_read_battery_mv();
        if (mv > 0)
        {
            battery_millivolts = mv;
            break;
        }
    }
    int millivolts = battery_millivolts;
    mutex_unlock(&adc_mutex);
    return millivolts;
}

unsigned short adc_read_millivolts(int channel)
{
    return (channel == ADC_BATTERY) ? adc_read_battery_voltage() : 0;
}

unsigned int adc_read_usbdata_voltage(bool dp)
{
    (void)dp;
    return 0;
}

int adc_read_accessory_resistor(void)
{
    return -1;
}

const char *adc_name(int channel)
{
    static const char * const names[] = { "Battery", "USB D+/D-", "Accessory" };
    return (channel >= 0 && channel < NUM_ADC_CHANNELS) ? names[channel] : "";
}
