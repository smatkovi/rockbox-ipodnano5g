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
#include "config.h"
#include "system.h"
#include "s5l87xx.h"
#include "i2c-s5l8702.h"
#include "cscodec.h"
#include "pmu-target.h"

/* Cirrus Logic CS42L58 (Apple's diags: DxeCS42L58), I2C bus 0 at 0x94.
 * Its reset line is GPIO 14.4: Apple's driver drives it low, waits 10 us
 * and drives it high before the first register access. Its init sequence
 * (hidden registers 0x2e..0x3f) is byte for byte the one Rockbox's CS42L55
 * driver writes, so that driver is used.
 * Its supply is D1759 regulator 19 (Apple's DevicePowerManagement powers
 * device 61 with it): 1800 mV in register 0x21 ((mV - 1200) / 100), enable
 * bit 2 in register 0x11 (Apple's DxeD1759 SetVoltage/Enable). */

#define D1759_REG_LDO19_VOLT    0x21
#define D1759_REG_LDO_EN2       0x11
#define D1759_LDO19_EN          0x04

#define CODEC_ADDR 0x94

unsigned char cscodec_read(int reg)
{
    unsigned char data = 0;
    i2c_read(0, CODEC_ADDR, reg, 1, &data);
    return data;
}

void cscodec_write(int reg, unsigned char data)
{
    i2c_write(0, CODEC_ADDR, reg, 1, &data);
}

void cscodec_power(bool state)
{
    unsigned char en = pmu_read(D1759_REG_LDO_EN2);

    if (state)
    {
        pmu_write(D1759_REG_LDO19_VOLT, (1800 - 1200) / 100);
        pmu_write(D1759_REG_LDO_EN2, en | D1759_LDO19_EN);
        udelay(1000);
    }
    else
        pmu_write(D1759_REG_LDO_EN2, en & ~D1759_LDO19_EN);
}

/* state: true = hold the codec in reset */
void cscodec_reset(bool state)
{
    PCON(14) = (PCON(14) & ~(0xf << 16)) | ((state ? 0xe : 0xf) << 16);
}

void cscodec_clock(bool state)
{
    (void)state;
}
