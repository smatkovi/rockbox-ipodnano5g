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

/* ST LIS331DLF accelerometer of the nano 5G (Apple's diags: DxeLIS331DLF).
 * Apple's driver looks for its address at run time and reads the 8-bit
 * outputs at 0x29/0x2b/0x2d, the high bytes on the parts with 16-bit
 * outputs. Untested on hardware: the bus and address come from a probe. */

#include "config.h"
#include "system.h"
#include "kernel.h"
#include "logf.h"
#include "i2c-s5l8702.h"
#include "accel.h"

#define REG_WHO_AM_I    0x0f
#define REG_CTRL1       0x20
#define REG_CTRL4       0x23
#define REG_OUT_X       0x29
#define REG_OUT_Y       0x2b
#define REG_OUT_Z       0x2d

static int accel_bus = -1;
static unsigned char accel_addr;
static int accel_mg_per_lsb;
static struct mutex accel_mtx;
static bool accel_tried;

static int accel_reg_read(int reg, unsigned char *val)
{
    return i2c_read(accel_bus, accel_addr, reg, 1, val);
}

static int accel_reg_write(int reg, unsigned char val)
{
    return i2c_write(accel_bus, accel_addr, reg, 1, &val);
}

static void accel_probe(void)
{
    for (int bus = 0; bus < 2; bus++)
        for (int a = 0x18; a <= 0x19; a++)
        {
            unsigned char who = 0;
            if (i2c_read(bus, a << 1, REG_WHO_AM_I, 1, &who) || !who
                || who == 0xff)
                continue;
            logf("accel: i2c%d %02x WHO_AM_I %02x", bus, a, who);
            accel_bus = bus;
            accel_addr = a << 1;
            if (who == 0x32)
            {
                /* LIS331DLH layout: normal mode, 50 Hz, X/Y/Z on; +-2 g,
                 * high byte 2000/128 mg */
                accel_reg_write(REG_CTRL4, 0x00);
                accel_reg_write(REG_CTRL1, 0x27);
                accel_mg_per_lsb = 16;
            }
            else
            {
                /* LIS331DL layout (0x3b): active, 100 Hz, X/Y/Z on, +-2.3 g
                 * at 18 mg; LIS3DH-like parts (0x33) read the same byte
                 * at 50 Hz */
                accel_reg_write(REG_CTRL1, 0x47);
                accel_mg_per_lsb = (who == 0x3b) ? 18 : 16;
            }
            return;
        }
    logf("accel: no sensor found");
}

int accel_read(int *x, int *y, int *z)
{
    unsigned char v[3];

    if (!accel_tried)
    {
        mutex_init(&accel_mtx);
        accel_tried = true;
        accel_probe();
    }
    if (accel_bus < 0)
        return -1;
    mutex_lock(&accel_mtx);
    int rc = accel_reg_read(REG_OUT_X, &v[0]) | accel_reg_read(REG_OUT_Y, &v[1])
             | accel_reg_read(REG_OUT_Z, &v[2]);
    mutex_unlock(&accel_mtx);
    if (rc)
        return -2;
    *x = (signed char)v[0] * accel_mg_per_lsb;
    *y = (signed char)v[1] * accel_mg_per_lsb;
    *z = (signed char)v[2] * accel_mg_per_lsb;
    return 0;
}
