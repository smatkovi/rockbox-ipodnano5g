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
#ifndef __PMU_TARGET_H__
#define __PMU_TARGET_H__

#include <stdbool.h>

/* The nano 5G PMU is a Dialog D1759, as on the nano 4G: Apple's nano 5G
 * diags carry a "DxeD1759Diagnostic" module. It answers on I2C bus 0 at
 * 0xe6. Checked on a 16 GB unit against the nano 4G register layout: the
 * battery ADC (channel 4) reads ~4.0 V, LEDCTL bit 0 is the backlight
 * enable and LEDOUT holds the brightness << 2 (Apple leaves 0xa0). Only the
 * ADC and LED registers are written; charger and power-off are not used.
 * The brightness is set over the SWIF link, which is how Apple's diags
 * reach LEDOUT on this model. */

#define D1759_I2C_ADDR          0xe6

#define D1759_REG_STATUSA       0x04
#define D1759_REG_STATUSB       0x05
#define D1759_REG_STATUSC       0x06
#define D1759_REG_SYSCTRLA      0x0a
#define D1759_REG_LEDOUT        0x30
#define D1759_REG_LEDCTL        0x31
#define D1759_REG_ADCCTL        0x40
#define D1759_REG_ADCRES        0x41

#define D1759_STATUSB_INPUT2    0x01    /* hold switch: 0 -> locked (nano 4G) */

unsigned char pmu_read(int address);
int pmu_read_multiple(int address, int count, unsigned char* buffer);

#define D1759_LEDCTL_ENABLE     0x01

int pmu_write(int address, unsigned char val);

/* write a PMU register over the SWIF single-wire link; 0 on success */
int pmu_swif_write(int reg, unsigned char val);
#define D1759_SWIF_LEDOUT       9       /* reaches LEDOUT (0x30) */
extern int pmu_swif_status;             /* result of the link setup */

/* battery voltage through the D1759 ADC, as the nano 4G driver measures it;
 * -1 on failure */
int pmu_read_battery_mv(void);

void pmu_init(void);
bool pmu_holdswitch_locked(void);

#endif /* __PMU_TARGET_H__ */
