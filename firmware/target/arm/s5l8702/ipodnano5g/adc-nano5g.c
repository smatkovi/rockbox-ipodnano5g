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

/* Bring-up: the battery ADC sits behind the PMU, which is not driven yet.
 * Report a mid-range voltage so power management does not shut down. */

#define FAKE_BATTERY_MV 3900

void adc_init(void)
{
}

unsigned short adc_read(int channel)
{
    (void)channel;
    return 0;
}

unsigned short adc_read_millivolts(int channel)
{
    return (channel == ADC_BATTERY) ? FAKE_BATTERY_MV : 0;
}

unsigned int adc_read_battery_voltage(void)
{
    return FAKE_BATTERY_MV;
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
