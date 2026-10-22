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
#include <string.h>
#include <stdio.h>
#include "config.h"
#include "system.h"
#include "kernel.h"
#include "thread.h"
#include "logf.h"
#include "pmu-target.h"
#include "devloop-nano5g.h"
#include "nandtest-nano5g.h"

volatile unsigned int devloop_usb_cbw_count;
extern char panic_buf[128];

struct devloop_mailbox {
    uint32_t magic;
    uint32_t reason;
    uint32_t tick;
    uint32_t usb_cbw_count;
    uint32_t far, dfsr, ifsr;
    uint32_t dwc_global[0x14];      /* 0x38400000.. */
    uint32_t dwc_dev[4];            /* 0x38400800.. */
    uint32_t dwc_inep[6][8];        /* 0x38400900.. */
    uint32_t dwc_outep[6][8];       /* 0x38400b00.. */
    char panic[128];
    char threads[1024];             /* "id status prio name" lines */
    uint32_t logfindex, logfwrap;
    char logf[MAX_LOGF_SIZE];
};

static void fill_mailbox(int reason)
{
    struct devloop_mailbox *mb = (void *)DEVLOOP_MAILBOX_ADDR;
    volatile uint32_t *dwc = (volatile uint32_t *)0x38400000;

    mb->magic = DEVLOOP_MAILBOX_MAGIC;
    mb->reason = reason;
    mb->tick = current_tick;
    mb->usb_cbw_count = devloop_usb_cbw_count;
    asm volatile("mrc p15, 0, %0, c6, c0, 0" : "=r"(mb->far));
    asm volatile("mrc p15, 0, %0, c5, c0, 0" : "=r"(mb->dfsr));
    asm volatile("mrc p15, 0, %0, c5, c0, 1" : "=r"(mb->ifsr));
    for (int i = 0; i < 0x14; i++)
        mb->dwc_global[i] = dwc[i];
    for (int i = 0; i < 4; i++)
        mb->dwc_dev[i] = dwc[0x200 + i];
    for (int ep = 0; ep < 6; ep++)
        for (int i = 0; i < 8; i++)
        {
            mb->dwc_inep[ep][i] = dwc[0x240 + ep * 8 + i];
            mb->dwc_outep[ep][i] = dwc[0x2c0 + ep * 8 + i];
        }
    memcpy(mb->panic, panic_buf, sizeof(mb->panic));
    {
        struct thread_debug_info ti;
        int n = 0;
        mb->threads[0] = 0;
        for (unsigned int id = 0; id < MAXTHREADS; id++)
            if (thread_get_debug_info(id, &ti) > 0 &&
                n < (int)sizeof(mb->threads) - 48)
                n += snprintf(mb->threads + n, sizeof(mb->threads) - n,
                              "%2u %s %2d %s\n", id, ti.statusstr,
                              ti.current_priority, ti.name);
    }
    mb->logfindex = logfindex;
    mb->logfwrap = logfwrap;
    memcpy(mb->logf, logfbuffer, sizeof(mb->logf));
}

void devloop_return_to_uboot(int reason)
{
    /* the U-Boot image starts with its vector table: "b reset" */
    if ((*(volatile uint32_t *)DEVLOOP_UBOOT_ADDR >> 24) != 0xea)
        return;

    disable_irq();
    fill_mailbox(reason);

    /* let the host see a disconnect: USB soft disconnect */
    *(volatile uint32_t *)0x38400804 |= 2;

    commit_discard_idcache();
    asm volatile(
        "mrc    p15, 0, r0, c1, c0, 0   \n"
        "bic    r0, r0, #0x1000         \n" /* I-cache off */
        "bic    r0, r0, #0x0005         \n" /* MMU, D-cache off */
        "mcr    p15, 0, r0, c1, c0, 0   \n"
        "mov    r0, #0                  \n"
        "mcr    p15, 0, r0, c7, c5, 0   \n" /* invalidate I-cache */
        "mcr    p15, 0, r0, c8, c7, 0   \n" /* invalidate TLBs */
        "mcr    p15, 0, r0, c7, c5, 4   \n" /* flush prefetch buffer */
        "bx     %0                      \n"
        : : "r"(DEVLOOP_UBOOT_ADDR) : "r0");
}

static long devloop_stack[DEFAULT_STACK_SIZE/sizeof(long)];

static void NORETURN_ATTR devloop_thread(void)
{
    int usb_seconds = 0;

    /* NAND bring-up: read-only, the result ends up in the mailbox's logf */
    sleep(2 * HZ);
    nandtest_run();

    while (true)
    {
        sleep(HZ);
        if (pmu_usb_present() && devloop_usb_cbw_count == 0)
        {
            if (++usb_seconds >= DEVLOOP_USB_TIMEOUT)
            {
                logf("devloop: no USB storage after %ds", usb_seconds);
                devloop_return_to_uboot(DEVLOOP_USB_STORAGE_SILENT);
                usb_seconds = 0;    /* no U-Boot copy: keep running */
            }
        }
        else
            usb_seconds = 0;
    }
}

void devloop_init(void)
{
    create_thread(devloop_thread, devloop_stack, sizeof(devloop_stack), 0,
                  "devloop" IF_PRIO(, PRIORITY_SYSTEM) IF_COP(, CPU));
}
