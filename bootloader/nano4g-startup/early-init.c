/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2026 Viktor Krapivin
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

/* Cold startup: code, stack and state stay in SRAM until SDRAM is ready. */
#include <stdint.h>
#include "early-init.h"

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define CLOCK(o) REG(0x3c500000u + (o))
#define GPIO(o) REG(0x3cf00000u + (o))
#define TIMER(o) REG(0x3c700000u + (o))
#define SDRAM(o) REG(0x3d700000u + (o))
#define POLL_LIMIT 0x200000u
#define PMU_BUS 0x3c600000u

static int timer_ready;

/* An iteration limit also terminates the wait if the timer itself stops. */
static int wait_mask(uint32_t address, uint32_t mask, uint32_t value)
{
    uint32_t start = timer_ready ? TIMER(0xb4) : 0;
    for (uint32_t n = 0; n < POLL_LIMIT; n++)
    {
        if ((REG(address) & mask) == value)
            return 0;
        if (timer_ready && (uint32_t)(TIMER(0xb4) - start) >= 10000)
            break;
    }
    return -1;
}

static int delay_us(uint32_t delay)
{
    uint32_t start = TIMER(0xb4);
    for (uint32_t n = 0; n < POLL_LIMIT; n++)
        if ((uint32_t)(TIMER(0xb4) - start) >= delay)
            return 0;
    return -1;
}

/* fuse-dependent PLL, system dividers and peripheral gates. */
static int clocks_init(void)
{
    CLOCK(0x4c) &= ~0x4000u;
    uint32_t grade = REG(0x3d100008u) & 1;
    CLOCK(0x4c) |= 0x4000;

    CLOCK(0x48) = 0x000327e5;
    CLOCK(0x4c) = 0xfe2bed6d;
    CLOCK(0x58) = 0x73;
    CLOCK(0x68) = 0xff;
    CLOCK(0x6c) = 0x00dcf779;

    uint32_t select = grade ? 0 : 0x80000000u;
    CLOCK(0x00) = select;
    if (wait_mask(0x3c500000, 0xf, 0))
        return -1;
    CLOCK(0x04) = 0;
    if (wait_mask(0x3c500004, 0x3e3e00, 0))
        return -1;
    CLOCK(0x44) = 7;
    CLOCK(0x44) = 0;
    CLOCK(0x3c) = 0;
    CLOCK(0x20) = ((grade ? 6u : 3u) << 24) | 0x8501;
    CLOCK(0x30) = 0x9bdc;
    CLOCK(0x44) = 1;
    CLOCK(0x44) = 0x10001;
    if (wait_mask(0x3c500040, 1, 1))
        return -1;
    CLOCK(0x04) = 0x404040;
    if (wait_mask(0x3c500004, 0x3e3e3e, 0))
        return -1;
    CLOCK(0x00) = select | 0x40001000;
    if (wait_mask(0x3c500000, 0xf, 0))
        return -1;
    CLOCK(0x08) = 0x80008000;
    CLOCK(0x0c) = 0xc000c000;
    CLOCK(0x10) = 0xc000;
    CLOCK(0x14) = 0x8000;
    CLOCK(0x70) = 0x8000;
    REG(0x38501000) = 2;
    return 0;
}

/* timer E counts microseconds. */
static int timer_init(void)
{
    uint32_t gate1 = CLOCK(0x4c), gate2 = CLOCK(0x58), gate4 = CLOCK(0x6c);
    CLOCK(0x4c) = gate1 & 0xe07fffdf;
    CLOCK(0x58) = gate2 & ~0x60u;
    CLOCK(0x6c) = gate4 & 0xff3fff80;
    TIMER(0x04) = 0x10;
    TIMER(0x24) = 0x10;
    TIMER(0x44) = 0x10;
    TIMER(0x64) = 0x10;
    TIMER(0xa0) = 0x40;
    TIMER(0xb0) = 0xb;
    TIMER(0xa8) = 0xffffffff;
    TIMER(0xa4) = 3;
    TIMER(0xc4) = 0x10;
    TIMER(0xe4) = 0x10;
    TIMER(0x104) = 0x10;
    TIMER(0x118) = 0xffffffff;
    CLOCK(0x4c) = gate1;
    CLOCK(0x58) = gate2;
    CLOCK(0x6c) = gate4;
    if (delay_us(1))
        return -1;
    timer_ready = 1;
    return 0;
}

/* Configure GPIO functions and pull resistors. */
static int gpio_init(uint8_t *board_id)
{
    static const uint32_t function[15] = {
        0x3202eeee, 0xe0ee2253, 0x2223eeee, 0x33333332, 0xff333e33,
        0xe0fee200, 0x2222222e, 0x22222222, 0xeeeeeee2, 0xeee0eeee,
        0x2eeeeeee, 0xeeee0222, 0xeeeee00e, 0xeeeeeeee, 0xeeeeeeee};
    for (unsigned int p = 0; p < 15; p++)
    {
        GPIO(p * 0x20) = function[p];
        GPIO(p * 0x20 + 0x0c) = p == 0 ? 0x20 : 0;
        GPIO(p * 0x20 + 0x10) = p == 1 ? 0x40 : 0;
    }
    GPIO(0x388) = (GPIO(0x388) & ~3u) | 1;
    for (unsigned int group = 0; group < 7; group++)
    {
        REG(0x39700080 + group * 4) = 0;
        REG(0x397000a0 + group * 4) = 0xffffffff;
        REG(0x397000c0 + group * 4) = 0;
        REG(0x397000e0 + group * 4) = 0;
    }
    GPIO(0x60) &= 0xff;
    if (delay_us(1000))
        return -1;
    *board_id = (GPIO(0x64) & 0xff) >> 2;
    GPIO(0x60) = function[3];
    return 0;
}

/* put the ROM's USB PHY into a defined powered-down state. */
static int usb_phy_shutdown(void)
{
    CLOCK(0x48) &= ~4u;
    CLOCK(0x4c) &= ~8u;
    REG(0x38400e00) = 1;
    REG(0x3c400000) = 0x1f;
    REG(0x3c400008) = 1;
    if (delay_us(1000))
        return -1;
    REG(0x3c40001c) = 0;
    CLOCK(0x48) |= 4;
    CLOCK(0x4c) |= 8;
    return 0;
}

static int i2c_write_reg(uint32_t base, unsigned int offset, uint32_t value)
{
    if (wait_mask(base + 0x10, 0xffffffff, 0))
        return -1;
    REG(base + offset) = value;
    return 0;
}

/* Initialize both I2C buses. */
static int i2c_init(void)
{
    static const uint16_t setup[][2] = {
        {0x08, 0x40}, {0x14, 1},    {0x18, 0},     {0x04, 0x80}, {0x00, 0},
        {0x04, 0},    {0x0c, 0x40}, {0x00, 0x181}, {0x04, 0x10}, {0x28, 0}};
    CLOCK(0x4c) &= ~0x50u;
    CLOCK(0x6c) &= ~0x1800u;
    for (unsigned int bus = 0; bus < 2; bus++)
        for (unsigned int i = 0; i < sizeof(setup) / sizeof(setup[0]); i++)
            if (i2c_write_reg(PMU_BUS + bus * 0x300000, setup[i][0],
                              setup[i][1]))
                return -1;
    return 0;
}

/* Acknowledge completion after START or a byte transfer. */
static int i2c_event(void)
{
    uint32_t start = TIMER(0xb4);
    for (unsigned int n = 0; n < POLL_LIMIT; n++)
    {
        if (!(REG(PMU_BUS + 4) & 0x20) || (REG(PMU_BUS + 0x20) & 0x100))
            return i2c_write_reg(PMU_BUS, 0x20, REG(PMU_BUS + 0x20) | 0x100);
        if ((uint32_t)(TIMER(0xb4) - start) >= 10000)
            break;
    }
    return -1;
}

/* polled PMU byte transfer. */
static int pmu_transfer(int read, uint8_t *bytes, unsigned int count)
{
    uint32_t mode = read ? 0x80 : 0xc0;
    int result = -1;
    if (delay_us(100) || i2c_write_reg(PMU_BUS, 0, REG(PMU_BUS) | 0x80) ||
        i2c_write_reg(PMU_BUS, 4, mode) ||
        i2c_write_reg(PMU_BUS, 0x0c, 0xe6 | read) ||
        i2c_write_reg(PMU_BUS, 4, mode | 0x30) || i2c_event())
        goto stop;
    if (REG(PMU_BUS + 4) & 1)
        goto stop;
    for (unsigned int i = 0; i < count; i++)
    {
        if (read)
        {
            uint32_t control = REG(PMU_BUS);
            if (i + 1 == count)
                control &= ~0x80u;
            if (i2c_write_reg(PMU_BUS, 0, control) || i2c_event())
                goto stop;
            bytes[i] = REG(PMU_BUS + 0x0c);
        }
        else
        {
            if (i2c_write_reg(PMU_BUS, 0x0c, bytes[i]) || delay_us(5) ||
                i2c_write_reg(PMU_BUS, 0, REG(PMU_BUS)) || i2c_event())
                goto stop;
            if (REG(PMU_BUS + 4) & 1)
                goto stop;
        }
    }
    result = 0;
stop:
    if (i2c_write_reg(PMU_BUS, 4, mode | 0x10) ||
        i2c_write_reg(PMU_BUS, 0, REG(PMU_BUS)))
        result = -1;
    return result;
}

static int pmu_read(uint8_t address, uint8_t *value)
{
    if (pmu_transfer(0, &address, 1))
        return -1;
    return pmu_transfer(1, value, 1);
}

static int pmu_write(uint8_t address, uint8_t value)
{
    uint8_t bytes[2] = {address, value};
    return pmu_transfer(0, bytes, 2);
}

/* cold regulator setup. Preserve register order, including the
 * repeated 0x1a write. This loader never resumes a retained SDRAM image. */
static int pmu_init(uint8_t board_id)
{
    /* Each row is {register, bits to retain, bits to set}. */
    static const uint8_t setup[][3] = {
        {0x14, 0, 0x13},    {0x15, 0, 0x0d},    {0x0b, 0, 0x22},
        {0x1f, 0, 0x14},    {0x1a, 0, 0xb2},    {0x1a, 0, 0xb2},
        {0x19, 0, 0x14},    {0x21, 0, 0x06},    {0x1d, 0, 0x12},
        {0x10, 0x7f, 0x60}, {0x44, 0, 0x72},    {0x40, 0xff, 0x40},
        {0x33, 0, 0x50},    {0x34, 0x80, 0x54}, {0x22, 0, 0}};
    uint8_t value;
    if (pmu_write(0x7f, board_id) || pmu_read(2, &value))
        return -1;
    /* Acknowledge pending PMU events with bit 7. */
    if ((value & 0x80) && pmu_write(2, 0x80))
        return -1;
    for (unsigned int i = 0; i < sizeof(setup) / sizeof(setup[0]); i++)
    {
        value = 0;
        if (setup[i][1] && pmu_read(setup[i][0], &value))
            return -1;
        if (pmu_write(setup[i][0], (value & setup[i][1]) | setup[i][2]))
            return -1;
        if (setup[i][0] == 0x0b && (board_id & 1))
        {
            if (pmu_read(0x0d, &value) || pmu_write(0x0d, value & 0xdf))
                return -1;
        }
    }
    /* Write the three-byte IRQ mask, then clear pending events. */
    uint8_t masks[] = {7, 0x50, 0xfe, 0x2b};
    uint8_t events[] = {1, 0xff, 0xff, 0xff};
    if (pmu_transfer(0, masks, sizeof(masks)) ||
        pmu_transfer(0, events, sizeof(events)) || pmu_write(0x30, 0x64) ||
        pmu_read(0x31, &value) || pmu_write(0x31, value & 0xfe) ||
        pmu_write(0x0a, 0x70) || pmu_write(0x13, 2))
        return -1;
    /* USB is unconfigured: 0x33=0x50 above explicitly selects 100 mA.
     * The runtime USB driver owns any subsequent increase in input budget. */
    return 0;
}

static int sdram_command(uint32_t command)
{
    SDRAM(0x104) = command;
    if (wait_mask(0x3d700104, 0x110000, 0))
        return -1;
    SDRAM(0x104) = 0x33;
    SDRAM(0x104) = 0x33;
    SDRAM(0x104) = 0x33;
    return 0;
}

/* 32 MiB SDRAM, DLL calibration, cold command sequence. */
static int sdram_init(void)
{
    GPIO(0x384) = 0;
    SDRAM(0) = 1;
    SDRAM(0x100) = 0x1030;
    SDRAM(0x11c) = 0xff;
    SDRAM(0x120) = 0xff;
    SDRAM(0x114) = 0x8aac25;
    SDRAM(0x124) = 0x50d67e5;
    SDRAM(0x118) = 8;
    SDRAM(0x108) = 0x2000b;
    SDRAM(0x148) = 4;
    SDRAM(0x14c) = 0;
    SDRAM(0x140) = 0x3b3b2;
    if (wait_mask(0x3d700140, 2, 2))
        return -1;
    SDRAM(0x140) = 0x3b3b3;
    if (wait_mask(0x3d700144, 3, 3))
        return -1;
    SDRAM(0x140) = (((SDRAM(0x144) >> 18) & 0xff) << 20) + 0xff53b3b0u;
    SDRAM(0x150) = 0x10;
    SDRAM(0x104) = 0x33;
    if (sdram_command(0x233) || sdram_command(0x333) || sdram_command(0x333))
        return -1;
    SDRAM(0x110) = 0x33;
    if (sdram_command(0x133))
        return -1;
    SDRAM(0x110) = 0x8040;
    if (sdram_command(0x133))
        return -1;
    SDRAM(0x10c) = 0x40;
    SDRAM(0x100) |= 0x09100000;
    SDRAM(0x11c) = 0x19;
    SDRAM(0x120) = 1;
    SDRAM(0x108) = 0x2100b;
    SDRAM(8) = 1;
    REG(0x3e000008) = 0x1f;
    return 0;
}

/* VBUS uses CPU 133 MHz, keeping the bus at 133 MHz.
 * The intermediate divider change runs entirely from SRAM with IRQs masked. */
static int power_clock_init(void)
{
    uint8_t status;
    if (pmu_read(4, &status))
        return -1;
    if (status & 0x40)
    {
        CLOCK(0) = 0x40001001;
        if (wait_mask(0x3c500000, 0xf, 1))
            return -1;
        CLOCK(4) = 0;
        if (wait_mask(0x3c500004, 0x3e3e3e, 0))
            return -1;
    }
    return 0;
}

/* Enable the NAND power rail before entering the bootloader. */
static int nand_power_init(void)
{
    uint8_t revision, rail;
    if (pmu_read(0, &revision))
        return -1;
    if (!(revision & 0x0f) || (revision & 0x80))
    {
        if (pmu_read(0x10, &rail) || pmu_write(0x10, rail | 4))
            return -1;
    }
    else
    {
        GPIO(0x1e0) = 0x0005050f;
    }
    return 0;
}

int rockbox_early_init(void)
{
    uint8_t board_id;
    timer_ready = 0;
    if (clocks_init())
        return NANO4G_INIT_CLOCK;
    if (timer_init())
        return NANO4G_INIT_TIMER;
    if (gpio_init(&board_id))
        return NANO4G_INIT_GPIO;
    if (usb_phy_shutdown())
        return NANO4G_INIT_TIMER;
    if (i2c_init())
        return NANO4G_INIT_I2C;
    if (pmu_init(board_id))
        return NANO4G_INIT_PMU;
    if (sdram_init())
        return NANO4G_INIT_SDRAM;
    if (power_clock_init())
        return NANO4G_INIT_POWER_CLOCK;
    if (nand_power_init())
        return NANO4G_INIT_PMU;
    return 0;
}
