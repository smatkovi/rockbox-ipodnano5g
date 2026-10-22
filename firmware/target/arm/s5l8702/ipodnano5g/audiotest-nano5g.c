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
#include <stdbool.h>
#include "config.h"
#include "system.h"
#include "s5l87xx.h"
#include "clocking-s5l8702.h"
#include "audiotest-nano5g.h"

/* Bring-up probe for the I2S2 TX DMA request line: with I2S2 running (the
 * codec, set up by the normal audio init, is the clock master) a PL080
 * channel is started on every request line of both DMA controllers in turn,
 * and a line counts if the channel moves data. The run is repeated with
 * I2S2 stopped; the line that moves only while I2S2 runs is the TX request.
 * Result bits: bit (16 * controller + line). */

#define DMAC_BASE(c)        ((c) ? 0x38700000 : 0x38200000)
#define DMAC_REG(c, o)      (*(volatile uint32_t *)(DMAC_BASE(c) + (o)))
#define DMAC_CONFIG         0x030
#define DMAC_CH             7
#define DMAC_CH_REG(c, o)   DMAC_REG(c, 0x100 + DMAC_CH * 0x20 + (o))
#define CH_SRC              0x00
#define CH_DST              0x04
#define CH_LLI              0x08
#define CH_CTRL             0x0c
#define CH_CFG              0x10

#define XFER                1024        /* halfwords */

static int16_t buf[XFER] __attribute__((aligned(32)));

static uint32_t probe(bool i2s_on)
{
    uint32_t hit = 0;

    I2STXCOM = i2s_on ? 0xe : 0xa;
    udelay(1000);

    for (int c = 0; c < 2; c++)
    {
        DMAC_REG(c, DMAC_CONFIG) |= 1;
        for (int req = 0; req < 16; req++)
        {
            DMAC_CH_REG(c, CH_CFG) = 0;
            DMAC_CH_REG(c, CH_SRC) = (uint32_t)buf;
            DMAC_CH_REG(c, CH_DST) = I2S_BASE + 0x10;    /* I2STXDB0 */
            DMAC_CH_REG(c, CH_LLI) = 0;
            DMAC_CH_REG(c, CH_CTRL) = XFER          /* transfer size */
                                    | (2 << 12)     /* src burst 8 */
                                    | (1 << 15)     /* dst burst 4 */
                                    | (1 << 18)     /* src 16 bit */
                                    | (1 << 21)     /* dst 16 bit */
                                    | (1 << 26);    /* src increment */
            DMAC_CH_REG(c, CH_CFG) = 1              /* enable */
                                   | (req << 6)     /* dest peripheral */
                                   | (1 << 11);     /* mem -> peripheral */
            udelay(20000);
            uint32_t left = DMAC_CH_REG(c, CH_CTRL) & 0xfff;
            DMAC_CH_REG(c, CH_CFG) = 0;
            if (left != XFER)
                hit |= 1 << (16 * c + req);
        }
    }
    I2STXCOM = 0xa;
    return hit;
}

/* One short DMAC0 transfer to I2S2 (request 0x0c) with the terminal count
 * interrupt enabled: which VIC input does it raise? out[]: DMAC0 raw TC
 * status, VIC0 raw, VIC1 raw, VIC0 enable, VIC1 enable, channel left */
void audiotest_dma_irq(uint32_t *out)
{
    int oldlevel = disable_irq_save();  /* look at the raw lines only */
    commit_dcache();
    clockgate_enable(CLOCKGATE_DMAC0, true);
    clockgate_enable(48, true);                 /* I2S2 */
    I2SCLKCON = 1;
    I2STXCON = 0x03100099;
    I2STXCOM = 0xe;
    udelay(1000);

    DMAC_REG(0, DMAC_CONFIG) |= 1;
    DMAC_REG(0, 0x008) = 1 << DMAC_CH;          /* clear TC */
    DMAC_CH_REG(0, CH_CFG) = 0;
    DMAC_CH_REG(0, CH_SRC) = (uint32_t)buf;
    DMAC_CH_REG(0, CH_DST) = I2S_BASE + 0x10;
    DMAC_CH_REG(0, CH_LLI) = 0;
    DMAC_CH_REG(0, CH_CTRL) = 64 | (2 << 12) | (1 << 15) | (1 << 18)
                            | (1 << 21) | (1 << 26)
                            | (1u << 31);               /* TC interrupt */
    DMAC_CH_REG(0, CH_CFG) = 1 | (0x0c << 6) | (1 << 11)
                           | (1 << 15);                 /* TC int unmasked */
    udelay(20000);
    out[0] = DMAC_REG(0, 0x014);                /* RawIntTCStatus */
    out[1] = *(volatile uint32_t *)0x38e00008;  /* VIC0 RAWINTR */
    out[2] = *(volatile uint32_t *)0x38e01008;  /* VIC1 RAWINTR */
    out[3] = *(volatile uint32_t *)0x38e00010;  /* VIC0 INTENABLE */
    out[4] = *(volatile uint32_t *)0x38e01010;  /* VIC1 INTENABLE */
    out[5] = DMAC_CH_REG(0, CH_CTRL) & 0xfff;
    DMAC_CH_REG(0, CH_CFG) = 0;
    DMAC_REG(0, 0x008) = 1 << DMAC_CH;
    I2STXCOM = 0xa;
    restore_irq(oldlevel);
}

void audiotest_dma_probe(uint32_t *on, uint32_t *off)
{
    commit_dcache();
    clockgate_enable(CLOCKGATE_DMAC0, true);
    clockgate_enable(CLOCKGATE_DMAC1, true);
    clockgate_enable(48, true);                 /* I2S2 */
    I2SCLKCON = 1;
    I2STXCON = 0x03100099;
    *on = probe(true);
    *off = probe(false);
}
