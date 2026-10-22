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
#include "system.h"
#include "kernel.h"
#include "thread.h"
#include "i2c-s5l8702.h"
#include "usb.h"
#include "s5l87xx.h"
#include "clocking-s5l8702.h"
#include "pmu-target.h"

int pmu_read_multiple(int address, int count, unsigned char* buffer)
{
    return i2c_read(0, D1759_I2C_ADDR, address, count, buffer);
}

unsigned char pmu_read(int address)
{
    unsigned char tmp = 0;
    pmu_read_multiple(address, 1, &tmp);
    return tmp;
}

int pmu_write(int address, unsigned char val)
{
    return i2c_write(0, D1759_I2C_ADDR, address, 1, &val);
}

int pmu_read_battery_mv(void)
{
    unsigned char control, result[2];
    int mv = -1;

    /* channel 4 over 2500..4500 mV; bit 4 starts a conversion and clears
     * when it is done (nano 4G adc-nano4g.c) */
    if (pmu_write(D1759_REG_ADCCTL, 0x54) != 0)
        return -1;
    for (int tries = 0; tries < 20; tries++)
    {
        if (pmu_read_multiple(D1759_REG_ADCCTL, 1, &control) != 0)
            break;
        if (!(control & 0x10))
        {
            if (pmu_read_multiple(D1759_REG_ADCRES, 2, result) == 0)
            {
                unsigned int raw = (result[1] << 2) | (result[0] & 3);
                mv = 2500 + raw * 2000 / 1023;
            }
            break;
        }
        udelay(100);
    }
    /* back to the idle input, as the original firmware does */
    pmu_write(D1759_REG_ADCCTL, 0x40);
    return mv;
}

/* SWIF: the S5L8730's single-wire link to the D1759. Apple's nano 5G
 * diags (Swif and TestBacklight modules) drive it as below; with the link
 * enabled (SYSCTRLA bits 4..5) the PMU ignores I2C writes to LEDOUT, and
 * SWIF register 9 sets it instead (the diags write 0xe3 over SWIF and read
 * it back from LEDOUT over I2C). */
#define SWIF_BASE       0x3de00000
#define SWIF_CON        (*(REG32_PTR_T)(SWIF_BASE + 0x00))
#define SWIF_RESET      (*(REG32_PTR_T)(SWIF_BASE + 0x04))
#define SWIF_CTRL       (*(REG32_PTR_T)(SWIF_BASE + 0x14))   /* channel 0 */
#define SWIF_DATA       (*(REG32_PTR_T)(SWIF_BASE + 0x18))
#define SWIF_CTRL_WRITE 0x2
#define SWIF_CTRL_START 0x1
#define SWIF_DATA_WRITE 0x80

#define CLOCKGATE_SWI   66
#define CLOCKGATE_SWI_2 149

#define SWIF_TIMEOUT    100000

static int swif_wait(volatile uint32_t *reg, uint32_t mask)
{
    for (int i = 0; i < SWIF_TIMEOUT; i++)
        if (!(*reg & mask))
            return 0;
    return -1;
}

int pmu_swif_write(int reg, unsigned char val)
{
    SWIF_CTRL = SWIF_CTRL_WRITE;
    SWIF_DATA = ((reg & 0x7f) << 8) | SWIF_DATA_WRITE | val;
    SWIF_CTRL |= SWIF_CTRL_START;
    return swif_wait(&SWIF_CTRL, SWIF_CTRL_START);
}

static int swif_init(void)
{
    unsigned char sysctrla;

    clockgate_enable(CLOCKGATE_SWI, true);
    clockgate_enable(CLOCKGATE_SWI_2, true);
    SWIF_RESET = 1;
    if (swif_wait(&SWIF_RESET, 1))
        return -1;
    SWIF_CON = 0x1703;

    /* enable the PMU side of the link, as the diags do before using it */
    if (pmu_read_multiple(D1759_REG_SYSCTRLA, 1, &sysctrla) != 0)
        return -2;
    if ((sysctrla & 0x30) != 0x30)
        pmu_write(D1759_REG_SYSCTRLA, sysctrla | 0x30);
    return pmu_swif_write(8, 0x80);
}

int pmu_swif_status;

/* The hold switch is a PMU input (status B bit 0, clear when locked).
 * button_read_device() asks from tick context, which cannot take the I2C
 * mutex, so a thread polls it and the last value is returned. The PMU
 * interrupt line of the nano 4G (GPIO 5.6) is not confirmed on this unit,
 * hence polling. */
#define PMU_POLL_INTERVAL   (HZ/10)

static long pmu_thread_stack[DEFAULT_STACK_SIZE/2/sizeof(long)];
static volatile bool pmu_hold_locked;
static bool pmu_usb_valid, pmu_usb;

static void pmu_read_inputs(void)
{
    unsigned char status[2], sysctrla;
    if (pmu_read_multiple(D1759_REG_STATUSA, 2, status) != 0 ||
        pmu_read_multiple(D1759_REG_SYSCTRLA, 1, &sysctrla) != 0)
        return;

    pmu_hold_locked = !(status[1] & D1759_STATUSB_INPUT2);

    /* USB cable: VBUS in status A, the raw bit while the USB input is
     * switched off (nano 4G layout). Only changes are reported. */
    bool usb = (sysctrla & D1759_SYSCTRLA_INPUTOFF) ?
               !!(status[0] & D1759_STATUSA_VBUSRAW) :
               !!(status[0] & D1759_STATUSA_VBUS);
    if (usb != pmu_usb || !pmu_usb_valid)
    {
        pmu_usb = usb;
        pmu_usb_valid = true;
        if (usb)
            usb_insert_int();
        else
            usb_remove_int();
    }
}

static void NORETURN_ATTR pmu_thread(void)
{
    while (true)
    {
        pmu_read_inputs();
        sleep(PMU_POLL_INTERVAL);
    }
}

bool pmu_holdswitch_locked(void)
{
    return pmu_hold_locked;
}

bool pmu_usb_present(void)
{
    return pmu_usb;
}

void pmu_init(void)
{
    pmu_swif_status = swif_init();
    pmu_read_inputs();
    create_thread(pmu_thread,
            pmu_thread_stack, sizeof(pmu_thread_stack), 0,
            "PMU" IF_PRIO(, PRIORITY_SYSTEM) IF_COP(, CPU));
}
