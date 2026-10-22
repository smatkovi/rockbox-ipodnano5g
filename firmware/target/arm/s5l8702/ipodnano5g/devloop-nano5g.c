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
#include "button.h"
#include "disk.h"
#include "mrsw_lock.h"
#include "file.h"
#include "dir.h"
#include "rb-loader.h"
#include "rbpaths.h"
#include "usb.h"
#include "i2c-s5l8702.h"

int clickwheel_raw_buttons(void);

volatile unsigned int devloop_usb_cbw_count;
volatile bool devloop_usb_ejected;
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
    char nandtest[NANDTEST_TEXT_SIZE];
    char fslock[128];               /* who holds the file system lock */
    /* where the CPU was when the tick interrupt took the hang dump */
    uint32_t int_spsr, int_sp, int_lr, irq_sp;
    uint32_t int_stack[96];         /* from int_sp up */
    uint32_t irq_stack[48];         /* from irq_sp up: irq_handler's frame */
    uint32_t nthreads;
    /* per thread slot: saved sp, saved lr, then 62 words from sp up */
    uint32_t thread_stack[MAXTHREADS][64];
    uint32_t logfindex, logfwrap;
    char logf[MAX_LOGF_SIZE];
};

static struct {
    uint32_t spsr, sp, lr, irq_sp;
} hang;

static long fslock_since;   /* tick since which the fs lock is taken */

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
    memcpy(mb->nandtest, nandtest_text, sizeof(mb->nandtest));
    {
        /* file system lock: count > 0 readers, < 0 a writer */
        extern struct mrsw_lock file_internal_mrsw;
        extern struct thread_entry *__threads[];
        struct mrsw_lock *l = &file_internal_mrsw;
        int n = snprintf(mb->fslock, sizeof(mb->fslock),
                         "fs lock count %d since tick %ld owner",
                         l->count, fslock_since);
        for (int t = 0; t < MAXTHREADS; t++)
            if (__threads[t] == l->splay.blocker.thread)
                n += snprintf(mb->fslock + n, sizeof(mb->fslock) - n, " %d", t);
        n += snprintf(mb->fslock + n, sizeof(mb->fslock) - n, " readers");
        for (int t = 0; t < MAXTHREADS && n < (int)sizeof(mb->fslock); t++)
            if (l->rdrecursion[t])
                n += snprintf(mb->fslock + n, sizeof(mb->fslock) - n,
                              " %d:%u", t, l->rdrecursion[t]);
    }
    mb->int_spsr = hang.spsr;
    mb->int_sp = hang.sp;
    mb->int_lr = hang.lr;
    mb->irq_sp = hang.irq_sp;
    for (int i = 0; i < 96; i++)
        mb->int_stack[i] = hang.sp ? ((uint32_t *)hang.sp)[i] : 0;
    for (int i = 0; i < 48; i++)
        mb->irq_stack[i] = hang.irq_sp ? ((uint32_t *)hang.irq_sp)[i] : 0;
    mb->nthreads = MAXTHREADS;
    for (int t = 0; t < MAXTHREADS; t++)
    {
        /* struct regs is the thread entry's first member: r4-r11, sp, lr */
        extern struct thread_entry *__threads[];
        const uint32_t *ctx = (const uint32_t *)__threads[t];
        uint32_t sp = ctx[8];
        mb->thread_stack[t][0] = sp;
        mb->thread_stack[t][1] = ctx[9];
        for (int i = 0; i < 62; i++)
            mb->thread_stack[t][2 + i] =
                ((sp >= 0x08000000 && sp < 0x0a000000) || sp < 0x40000)
                ? ((uint32_t *)sp)[i] : 0;
    }
    mb->logfindex = logfindex;
    mb->logfwrap = logfwrap;
    memcpy(mb->logf, logfbuffer, sizeof(mb->logf));
}

/* Images to restart from, in the SDRAM above Rockbox's 32 MiB: GOOD is
 * known to reach working USB storage, NEW is on trial after an eject */
struct devloop_image {
    uint32_t magic;
    uint32_t len;
    uint32_t sum;
    uint32_t trial;         /* NEW: not yet promoted to GOOD */
    uint32_t running;       /* GOOD: 1 = GOOD runs, 2 = NEW runs */
    uint32_t reports;       /* GOOD: report files written so far */
};
#define IMAGE_MAGIC         0x474d4931      /* "1IMG" */
#define IMAGE_GOOD          ((struct devloop_image *)DEVLOOP_GOOD_ADDR)
#define IMAGE_NEW           ((struct devloop_image *)DEVLOOP_NEW_ADDR)
#define IMAGE_DATA(im)      ((uint8_t *)(im) + 0x100)
#define IMAGE_MAX           (DEVLOOP_SLOT_SIZE - 0x100)

static uint32_t image_sum(const struct devloop_image *im)
{
    const uint32_t *w = (const uint32_t *)IMAGE_DATA(im);
    uint32_t sum = 0;
    for (uint32_t i = 0; i < im->len / 4; i++)
        sum += w[i];
    return sum;
}

static bool image_valid(const struct devloop_image *im)
{
    return im->magic == IMAGE_MAGIC && im->len && im->len <= IMAGE_MAX
           && image_sum(im) == im->sum;
}

/* Load the boot file into a slot */
static bool image_load(struct devloop_image *im)
{
    int len = load_firmware(IMAGE_DATA(im), BOOTDIR "/" BOOTFILE, IMAGE_MAX);
    im->magic = 0;
    if (len <= 0)
    {
        logf("devloop: loading %s: %d", BOOTFILE, len);
        return false;
    }
    im->len = (len + 3) & ~3;
    im->sum = image_sum(im);
    im->magic = IMAGE_MAGIC;
    return true;
}

/* Run by U-Boot's "go DEVLOOP_TRAMP_ADDR" (bootcmd, see uboot_enter()):
 * with U-Boot's caches cleaned and off as for any start from U-Boot, copy
 * the image (src, len in the parameter words after the code) to 0x08000000
 * and start it */
extern const char devloop_tramp[], devloop_tramp_params[], devloop_tramp_end[];
asm(".pushsection .text                     \n"
    ".align 2                               \n"
    ".arm                                   \n"
    "devloop_tramp:                         \n"
    "    msr    cpsr_c, #0xd3               \n" /* SVC, IRQ/FIQ off */
    "    mov    r3, #0                      \n"
    "    mcr    p15, 0, r3, c7, c14, 0      \n" /* clean+invalidate D-cache */
    "    mcr    p15, 0, r3, c7, c10, 4      \n" /* drain write buffer */
    "    mrc    p15, 0, r3, c1, c0, 0       \n"
    "    bic    r3, r3, #0x1000             \n" /* I-cache off */
    "    bic    r3, r3, #0x0005             \n" /* MMU, D-cache off */
    "    mcr    p15, 0, r3, c1, c0, 0       \n"
    "    mov    r3, #0                      \n"
    "    mcr    p15, 0, r3, c7, c5, 0       \n" /* invalidate I-cache */
    "    mcr    p15, 0, r3, c8, c7, 0       \n" /* invalidate TLBs */
    "    mcr    p15, 0, r3, c7, c5, 4       \n" /* flush prefetch buffer */
    "    adr    r3, devloop_tramp_params    \n"
    "    ldr    r0, [r3]                    \n" /* source */
    "    ldr    r2, [r3, #4]                \n" /* length */
    "    mov    r1, #0x08000000             \n"
    "1:  ldr    r3, [r0], #4                \n"
    "    str    r3, [r1], #4                \n"
    "    subs   r2, r2, #4                  \n"
    "    bgt    1b                          \n"
    "    mov    r0, #0x08000000             \n"
    "    bx     r0                          \n"
    "devloop_tramp_params:                  \n"
    "    .word  0, 0                        \n"
    "devloop_tramp_end:                     \n"
    ".popsection                            \n");

/* U-Boot as loaded by n5g-shellboot.sh, kept before it ever runs: it
 * changes its load copy when it runs, and clears a 16 MiB heap at the top
 * of the SDRAM, which is why everything here lives below it */
#define UBOOT_SAVE          ((struct devloop_image *)DEVLOOP_UBOOT_SAVE_ADDR)
#define UBOOT_MAX           0x60000
static const char uboot_bootcmd[] = "bootcmd=echo n5g u-boot console ready";

static void uboot_save(void)
{
    struct devloop_image *u = UBOOT_SAVE;

    if (image_valid(u) || (*(volatile uint32_t *)DEVLOOP_UBOOT_ADDR >> 24) != 0xea)
        return;
    memcpy(IMAGE_DATA(u), (void *)DEVLOOP_UBOOT_ADDR, UBOOT_MAX);
    u->len = UBOOT_MAX;
    u->sum = image_sum(u);
    u->magic = IMAGE_MAGIC;
}

/* Enter U-Boot from its saved copy; with go set, its bootcmd runs the
 * trampoline instead of waiting at the console. Returns if there is no
 * U-Boot. Interrupts must be off. */
static void uboot_enter(bool go)
{
    uint8_t *ub = (uint8_t *)DEVLOOP_UBOOT_ADDR;

    /* U-Boot's USB console (its preboot, before bootcmd) only comes up
     * with the cable in: wait for it */
    while (!pmu_usb_present() && !pmu_usb_present_now())
        udelay(100000);

    if (image_valid(UBOOT_SAVE))
        memcpy(ub, IMAGE_DATA(UBOOT_SAVE), UBOOT_SAVE->len);
    else if ((*(volatile uint32_t *)DEVLOOP_UBOOT_ADDR >> 24) != 0xea)
        return;
    if (go)
    {
        /* same length, so the environment keeps its layout */
        for (uint8_t *p = ub; p < ub + UBOOT_MAX - sizeof(uboot_bootcmd); p++)
            if (!memcmp(p, uboot_bootcmd, sizeof(uboot_bootcmd)))
            {
                char cmd[sizeof(uboot_bootcmd)];
                memset(cmd, ' ', sizeof(cmd));
                snprintf(cmd, sizeof(cmd), "bootcmd=go %#x", DEVLOOP_TRAMP_ADDR);
                cmd[strlen(cmd)] = ' ';
                memcpy(p, cmd, sizeof(cmd) - 1);
                break;
            }
    }

    /* let the host see a disconnect: USB soft disconnect */
    *(volatile uint32_t *)0x38400804 |= 2;
    /* nothing left from this instance's interrupt setup */
    VIC0INTENCLEAR = 0xffffffff;
    VIC1INTENCLEAR = 0xffffffff;
    VIC0INTSELECT = 0;
    VIC1INTSELECT = 0;

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
        "msr    cpsr_c, #0xd3           \n" /* SVC mode, also from IRQ */
        "bx     %0                      \n"
        : : "r"(DEVLOOP_UBOOT_ADDR) : "r0");
}

/* Start an image through U-Boot, which sets the hardware up the way a start
 * from its console does */
static void image_start(struct devloop_image *im)
{
    uint32_t *params;

    disable_interrupt(IRQ_FIQ_STATUS);
    IMAGE_GOOD->running = (im == IMAGE_GOOD) ? 1 : 2;
    memcpy((void *)DEVLOOP_TRAMP_ADDR, devloop_tramp,
           devloop_tramp_end - devloop_tramp);
    params = (uint32_t *)(DEVLOOP_TRAMP_ADDR
                          + (devloop_tramp_params - devloop_tramp));
    params[0] = (uint32_t)IMAGE_DATA(im);
    params[1] = im->len;
    uboot_enter(true);
}

void devloop_return_to_uboot(int reason)
{
    disable_irq();
    fill_mailbox(reason);

    /* restart the known good image, with the report in the mailbox */
    if (image_valid(IMAGE_GOOD))
        image_start(IMAGE_GOOD);

    uboot_enter(false);
    enable_irq();
}

static long devloop_stack[DEFAULT_STACK_SIZE/sizeof(long)];

/* Threads switch cooperatively, so a hang in one stops devloop_thread too.
 * This runs in the tick interrupt: MENU+PLAY held for two seconds records
 * the interrupted mode's registers and stacks and returns to the shell. */
static volatile long infotest_start;

static void devloop_hang_dump(void);

static void devloop_tick(void)
{
    static int held;

    if (infotest_start && TIME_AFTER(current_tick, infotest_start + 5 * HZ))
        held = 2 * HZ;  /* the info test hangs: dump without a key */
    else if ((clickwheel_raw_buttons() & (BUTTON_MENU | BUTTON_PLAY))
             != (BUTTON_MENU | BUTTON_PLAY))
    {
        held = 0;
        return;
    }
    if (++held < 2 * HZ)
        return;
    devloop_hang_dump();
}

/* The clickwheel interrupt as FIQ, which most of Rockbox leaves enabled
 * when it disables IRQs: MENU+PLAY takes the dump at once, even when a hang
 * has IRQs off and the tick task no longer runs */
void INT_WHEEL(void);
void fiq_handler(void) __attribute__((interrupt ("FIQ")));
void fiq_handler(void)
{
    INT_WHEEL();
    if ((clickwheel_raw_buttons() & (BUTTON_MENU | BUTTON_PLAY))
        == (BUTTON_MENU | BUTTON_PLAY))
        devloop_hang_dump();
}

/* Record the interrupted mode's registers, then back to the shell. Runs in
 * the tick IRQ or the wheel FIQ. */
static void devloop_hang_dump(void)
{
    uint32_t cpsr, mode;

    asm volatile("mrs %0, spsr" : "=r"(hang.spsr));
    asm volatile("mrs %0, cpsr" : "=r"(cpsr));
    asm volatile("mov %0, sp" : "=r"(hang.irq_sp));
    mode = hang.spsr & 0x1f;
    if (mode == 0x10)
        mode = 0x1f;    /* user mode registers: through system mode */
    asm volatile("msr cpsr_c, %2  \n"
                 "mov %0, sp      \n"
                 "mov %1, lr      \n"
                 "msr cpsr_c, %3  \n"
                 : "=&r"(hang.sp), "=&r"(hang.lr)
                 : "r"((cpsr & ~0x1f) | mode | 0xc0), "r"(cpsr));
    devloop_return_to_uboot(DEVLOOP_HANG_DUMP);
}

static void NORETURN_ATTR devloop_thread(void)
{
    int usb_seconds = 0;

    /* NAND bring-up, read-only, on request: it reads for seconds without
     * yielding, which can starve the USB thread during enumeration */
    sleep(2 * HZ);
    if (file_exists("/devloop/nandtest"))
        nandtest_run();

    while (true)
    {
        extern struct mrsw_lock file_internal_mrsw;
        sleep(HZ);
        if (!file_internal_mrsw.count)
            fslock_since = 0;
        else if (!fslock_since)
            fslock_since = current_tick;
        if (devloop_usb_ejected)
        {
            /* the eject ends USB mode; once the disk is mounted again,
             * start the boot file on trial (GOOD if it does not load) */
            devloop_usb_ejected = false;
            /* every drive must be ejected and the disks mounted again */
            for (int i = 0; i < 40 && (usb_exclusive_storage()
                     || !file_exists(BOOTDIR "/" BOOTFILE)); i++)
                sleep(HZ / 4);
            sleep(HZ / 2);
            logf("devloop: host ejected, starting %s", BOOTFILE);
            if (image_load(IMAGE_NEW))
            {
                IMAGE_NEW->trial = 1;
                disable_irq();
                fill_mailbox(DEVLOOP_HOST_EJECT);
                image_start(IMAGE_NEW);
            }
            devloop_return_to_uboot(DEVLOOP_HOST_EJECT);
        }
        /* a NEW image that got USB storage working becomes GOOD */
        if (devloop_usb_cbw_count && IMAGE_GOOD->running == 2
            && IMAGE_NEW->trial && image_valid(IMAGE_NEW))
        {
            uint32_t reports = IMAGE_GOOD->reports;
            memcpy(IMAGE_GOOD, IMAGE_NEW, 0x100 + IMAGE_NEW->len);
            IMAGE_GOOD->trial = 0;
            IMAGE_GOOD->running = 1;
            IMAGE_GOOD->reports = reports;
            IMAGE_NEW->trial = 0;
            logf("devloop: new image is good now");
        }
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

/* Which I2C devices answer (an address-only write, no data), and the
 * accelerometer's WHO_AM_I: for the radio and pedometer bring-up */
static void i2c_scan(void)
{
    for (int bus = 0; bus < 2; bus++)
    {
        char line[96];
        int n = snprintf(line, sizeof(line), "i2c%d:", bus);
        for (int a = 0x08; a < 0x78 && n < (int)sizeof(line) - 6; a++)
            if (i2c_write(bus, a << 1, -1, 0, NULL) == 0)
                n += snprintf(line + n, sizeof(line) - n, " %02x", a);
        logf("devloop: %s", line);
        for (int a = 0x18; a <= 0x19; a++)
        {
            unsigned char who = 0;
            if (i2c_read(bus, a << 1, 0x0f, 1, &who) == 0)
                logf("devloop: i2c%d %02x WHO_AM_I %02x", bus, a, who);
        }
    }
}

/* Called by init() once the disk is mounted, before USB can take it:
 * save the last report to /devloop, and keep the boot file as GOOD when
 * there is none yet (the first start, from U-Boot) */
void devloop_boot(void)
{
    struct devloop_mailbox *mb = (void *)DEVLOOP_MAILBOX_ADDR;
    char name[32];

    uboot_save();
    if (!image_valid(IMAGE_GOOD))
    {
        IMAGE_GOOD->reports = 0;
        if (image_load(IMAGE_GOOD))
            IMAGE_GOOD->running = 1;
    }
    i2c_scan();
    logf("devloop: boot, running %s, good %d new %d",
         IMAGE_GOOD->running == 2 ? "NEW" : "GOOD",
         image_valid(IMAGE_GOOD), image_valid(IMAGE_NEW));
    if (mb->magic != DEVLOOP_MAILBOX_MAGIC)
        return;
    mkdir("/devloop");
    snprintf(name, sizeof(name), "/devloop/report%03lu.bin",
             (unsigned long)IMAGE_GOOD->reports++);
    int fd = creat(name, 0666);
    if (fd >= 0)
    {
        write(fd, mb, sizeof(*mb));
        close(fd);
    }
    mb->magic = 0;
}

void devloop_init(void)
{
    tick_add_task(devloop_tick);
    VIC0INTSELECT |= 1 << IRQ_WHEEL;   /* the wheel interrupt as FIQ */
    create_thread(devloop_thread, devloop_stack, sizeof(devloop_stack), 0,
                  "devloop" IF_PRIO(, PRIORITY_SYSTEM) IF_COP(, CPU));
}
