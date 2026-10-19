/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright © 2008 Rafaël Carré
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
#include "kernel.h"
#include "thread.h"

#include "pmu-target.h"
#include "adc-target.h"
#include "i2c-s5l8702.h"
#include "gpio-s5l8702.h"


int pmu_read_multiple(int address, int count, unsigned char* buffer)
{
    return i2c_read(0, 0xe6, address, count, buffer);
}

int pmu_write_multiple(int address, int count, unsigned char* buffer)
{
    return i2c_write(0, 0xe6, address, count, buffer);
}

unsigned char pmu_read(int address)
{
    unsigned char tmp;
    pmu_read_multiple(address, 1, &tmp);
    return tmp;
}

int pmu_write(int address, unsigned char val)
{
    return pmu_write_multiple(address, 1, &val);
}

#if 0
void pmu_ldo_on_in_standby(unsigned int ldo, int onoff)
{
    if (ldo < 4)
    {
        unsigned char newval = pmu_read(0x3B) & ~(1 << (2 * ldo));
        if (onoff) newval |= 1 << (2 * ldo);
        pmu_write(0x3B, newval);
    }
    else if (ldo < 8)
    {
        unsigned char newval = pmu_read(0x3C) & ~(1 << (2 * (ldo - 4)));
        if (onoff) newval |= 1 << (2 * (ldo - 4));
        pmu_write(0x3C, newval);
    }
}

void pmu_ldo_set_voltage(unsigned int ldo, unsigned char voltage)
{
    if (ldo > 6) return;
    pmu_write(0x2d + (ldo << 1), voltage);
}

void pmu_hdd_power(bool on)
{
    pmu_write(0x1b, on ? 1 : 0);
}

void pmu_ldo_power_on(unsigned int ldo)
{
    if (ldo > 6) return;
    pmu_write(0x2e + (ldo << 1), 1);
}

void pmu_ldo_power_off(unsigned int ldo)
{
    if (ldo > 6) return;
    pmu_write(0x2e + (ldo << 1), 0);
}
#endif

void pmu_set_wake_condition(unsigned char condition)
{
    // TODO
    (void) condition;
}

void pmu_enter_standby(void)
{
    /* D1759 shutdown as the original firmware performs it.
     * The core has already stopped playback and flushed storage. Turn off
     * the backlight, then request PMU power-off with an exact register write
     * (not an OR with the running-state USB/suspend control bits).
     * Keep the scheduler available for the normal I2C bus mutex here. */
    pmu_write(D1759_REG_LEDCTL, 0x02);
    pmu_write(D1759_REG_SYSCTRLA, D1759_SYSCTRLA_POWEROFF);
}

#ifdef HAVE_ADJUSTABLE_CPU_FREQ
void pmu_set_cpu_voltage(bool high)
{
    // TODO
    (void) high;
}
#endif

#if (CONFIG_RTC == RTC_NANO4G)
void pmu_read_rtc(unsigned char* buffer)
{
    // TODO
    (void) buffer;
}

void pmu_write_rtc(unsigned char* buffer)
{
    // TODO
    (void) buffer;
}
#endif

/* USB input: charger off (no external power), or charger on with a
 * 100 mA or 500 mA input limit. Clears the input-off bit first and writes
 * the charge settings after the limit, the order of the original firmware. */
static void pmu_apply_usb_input(int ma)
{
    unsigned char system;
    if (pmu_read_multiple(D1759_REG_SYSCTRLA, 1, &system) == 0 &&
        (system & D1759_SYSCTRLA_INPUTOFF))
        pmu_write(D1759_REG_SYSCTRLA, system & ~D1759_SYSCTRLA_INPUTOFF);

    if (ma <= 0)
    {
        pmu_write(D1759_REG_CHGCTL, 0x00);
        pmu_write(D1759_REG_CHGSET, 0x00);
    }
    else
    {
        pmu_write(D1759_REG_CHGCTL, ma >= 500 ? 0x52 : 0x50);
        pmu_write(D1759_REG_CHGSET, 0x04);
    }
}

static struct mutex pmu_usb_mutex;
static bool pmu_input_usb;
static bool pmu_inputs_valid;

/* Called by the USB stack with the budget the host granted. Ignored while
 * no USB power is present: removal turns the charger off and must win
 * against a late request from the USB thread. */
void pmu_set_usblimit(int ma)
{
    mutex_lock(&pmu_usb_mutex);
    if (pmu_input_usb)
        pmu_apply_usb_input(ma);
    mutex_unlock(&pmu_usb_mutex);
}

int pmu_charging_state(void)
{
    unsigned char control, system, status[3];

    if (pmu_read_multiple(D1759_REG_CHGCTL, 1, &control) != 0 ||
        pmu_read_multiple(D1759_REG_SYSCTRLA, 1, &system) != 0 ||
        pmu_read_multiple(D1759_REG_STATUSA, 3, status) != 0)
        return -1;

    /* USB input usable (the raw VBUS bit while the input is switched off),
     * charger enabled and input not switched off: the charger is busy
     * while status B bits 1..2 are set; with both clear it has stopped,
     * which the original firmware shows as a charged battery */
    bool external = (system & D1759_SYSCTRLA_INPUTOFF) ?
                    (status[0] & D1759_STATUSA_VBUSRAW) :
                    (status[0] & D1759_STATUSA_VBUS);
    if (!external || !(control & 0xfc) || (system & D1759_SYSCTRLA_INPUTOFF))
        return PMU_CHARGER_OFF;
    return (status[1] & 0x06) ? PMU_CHARGER_CHARGING : PMU_CHARGER_CHARGED;
}

/*
 * ADC
 */
static struct mutex pmu_adc_mutex;

/* converts raw value to millivolts */
unsigned short pmu_adc_raw2mv(
        const struct pmu_adc_channel *ch, unsigned short raw)
{
    // TODO
    (void) ch;
    (void) raw;
    return 0;
}

/* returns raw value */
unsigned short pmu_read_adc(const struct pmu_adc_channel *ch)
{
    // TODO
    int raw = 0;
    mutex_lock(&pmu_adc_mutex);
    (void) ch;
    mutex_unlock(&pmu_adc_mutex);
    return raw;
}

/*
 * eINT
 */
#define Q_EINT  0
#define PMU_POLL_INTERVAL   (HZ/2)

static long pmu_thread_stack[DEFAULT_STACK_SIZE/2/sizeof(long)];
static struct event_queue pmu_queue;

static void pmu_eint_isr(struct eic_handler*);

static struct eic_handler pmu_eint =
{
    .gpio_n = GPIO_EINT_PMU,
    .type   = EIC_INTTYPE_LEVEL,
    .level  = EIC_INTLEVEL_LOW,
    .isr    = pmu_eint_isr,
};

static int pmu_input_holdswitch;

bool pmu_usb_present(void)
{
    return pmu_input_usb;
}

int pmu_holdswitch_locked(void)
{
   return pmu_input_holdswitch;
}

#ifdef IPOD_ACCESSORY_PROTOCOL
static int pmu_input_accessory;

int pmu_accessory_present(void)
{
   return pmu_input_accessory;
}
#endif

#if CONFIG_CHARGING
static int pmu_input_firewire;

int pmu_firewire_present(void)
{
   return pmu_input_firewire;
}
#endif

#if defined(BOOTLOADER)   // XXX: from usb-s5l8702.c
#include "usb.h"
static int usb_status = USB_EXTRACTED;

int usb_detect(void)
{
    return usb_status;
}

void usb_insert_int(void)
{
    usb_status = USB_INSERTED;
}

void usb_remove_int(void)
{
    usb_status = USB_EXTRACTED;
}
#elif defined(USB_NONE)
/* bring-up: the main binary has no USB yet (usb.c provides usb_detect);
 * the PMU's VBUS events are read but go nowhere */
#include "usb.h"
void usb_insert_int(void)
{
}

void usb_remove_int(void)
{
}
#endif

static void pmu_read_inputs(void)
{
    unsigned char status[3], system;

    if (pmu_read_multiple(D1759_REG_SYSCTRLA, 1, &system) != 0 ||
        pmu_read_multiple(D1759_REG_STATUSA, sizeof(status), status) != 0)
        return;

    bool usb_present = (system & D1759_SYSCTRLA_INPUTOFF) ?
                       !!(status[0] & D1759_STATUSA_VBUSRAW) :
                       !!(status[0] & D1759_STATUSA_VBUS);
    if (usb_present != pmu_input_usb || !pmu_inputs_valid)
    {
        /* charger on at 100 mA until a host grants more, off on removal */
        mutex_lock(&pmu_usb_mutex);
        pmu_input_usb = usb_present;
        pmu_apply_usb_input(usb_present ? 100 : 0);
        mutex_unlock(&pmu_usb_mutex);

        /* report changes only: every USB event restarts the idle
           poweroff timer */
        if (pmu_input_usb)
            usb_insert_int();
        else
            usb_remove_int();
    }
    pmu_inputs_valid = true;

#ifdef IPOD_ACCESSORY_PROTOCOL
    pmu_input_accessory = !!(status[0] & D1759_STATUSA_INPUT1);
#endif
    pmu_input_holdswitch = !(status[1] & D1759_STATUSB_INPUT2);
#if CONFIG_CHARGING
    pmu_input_firewire = !!(status[2] & D1759_STATUSC_INPUT2);
#endif
}

static void pmu_eint_isr(struct eic_handler *h)
{
     eint_unregister(h);
     queue_post(&pmu_queue, Q_EINT, 0);
}

static void NORETURN_ATTR pmu_thread(void)
{
    struct queue_event ev;

    while (true)
    {
        queue_wait_w_tmo(&pmu_queue, &ev, PMU_POLL_INTERVAL);
        switch (ev.id)
        {
            case Q_EINT:
            {
                /* acknowledge the events that were read, this raises
                   (releases) the PMU IRQ pin unless a new one arrived */
                unsigned char events[3];
                if (pmu_read_multiple(D1759_REG_EVENTA, 3, events) == 0)
                    pmu_write_multiple(D1759_REG_EVENTA, 3, events);
                else
                    pmu_write_multiple(D1759_REG_EVENTA, 3, "\xFF\xFF\xFF");

                /* get actual values */
                pmu_read_inputs();

                eint_register(&pmu_eint);
                break;
            }

            case SYS_TIMEOUT:
                /* the interrupt is level triggered and should not be
                   missed; re-reading the status is a cheap safety net */
                pmu_read_inputs();
                break;
        }
    }
}

/* main init */
void pmu_init(void)
{
    mutex_init(&pmu_adc_mutex);
    mutex_init(&pmu_usb_mutex);
    queue_init(&pmu_queue, false);

    create_thread(pmu_thread,
            pmu_thread_stack, sizeof(pmu_thread_stack), 0,
            "PMU" IF_PRIO(, PRIORITY_SYSTEM) IF_COP(, CPU));

    /* running-state configuration of the original firmware: interrupt
     * masks (1 = masked) leave USB/power in (A b3, b6), the second power
     * input (A b1), the accessory (A b5), battery low (A b7), the hold
     * switch (B b0) and power out (C b2, b4) unmasked */
    pmu_write(0x0c, 0x05);
    pmu_write(0x0e, 0xd0);
    pmu_write(0x22, 0x05);
    pmu_write_multiple(D1759_REG_IRQMASKA, 3, "\x10\xFE\x2B");

    /* clear all interrupts */
    pmu_write_multiple(D1759_REG_EVENTA, 3, "\xFF\xFF\xFF");

    /* get initial values */
    pmu_read_inputs();

    eint_register(&pmu_eint);
}


/*
 * preinit
 */
int pmu_rd_multiple(int address, int count, unsigned char* buffer)
{
    return i2c_rd(0, 0xe6, address, count, buffer);
}

int pmu_wr_multiple(int address, int count, unsigned char* buffer)
{
    return i2c_wr(0, 0xe6, address, count, buffer);
}

unsigned char pmu_rd(int address)
{
    unsigned char val;
    pmu_rd_multiple(address, 1, &val);
    return val;
}

int pmu_wr(int address, unsigned char val)
{
    return pmu_wr_multiple(address, 1, &val);
}

void pmu_preinit(void)
{
#ifndef BOOTLOADER
    /* Regulator / charger setup carried over from the nano 3G port (values
     * marked TBC below). The bootloader skips it: it runs behind the
     * first-stage loader, whose PMU state already powers the
     * LCD, NAND and USB, and Apple's firmware images started from the
     * bootloader expect that state (the USB PHY stayed dead with these
     * writes applied: no device on the host). Only the backlight and the
     * interrupt housekeeping below are needed here. */
    pmu_wr(0x14, 0x13);
    pmu_wr(0x15, 0x0d);
    pmu_wr(0xb, 0x22);
    if (pmu_rd(0x7f) & 1)
        pmu_wr(0xd, (pmu_rd(0xd) & 0xdf));
//     if (unknown_boot_config & 1)                  // XXX: could it be disabling some LDO??? remember that in this type of PMU the LDO enable bits are
//         pmu_wr(0xd, (pmu_rd(0xd) & 0xdf));      //      located in other registers different from the voltage configuration???

    // TBC: LDOs ???
    pmu_wr(0x1f, 0x14);
    pmu_wr(0x1a, 0xb2);         // XXX: 0xA & 0x12, maybe it's an option to always ON, or ON in stby or something like that, could it be the ARM7 ???
    pmu_wr(0x1a, 0xb2);         // XXX: repeat, posibly a typo ??? ??? ???
    pmu_wr(0x19, 0x14);         // XXX: TBC: NAND (by similarity with nano3g)
    pmu_wr(0x21, 0x6);
    pmu_wr(0x1d, 0x12);
    pmu_wr(0x10, (pmu_rd(0x10) & 0x7f) | 0x60);

    pmu_wr(0x44, 0x72);                             // TBC: 0x40+ seems related to ADC
    pmu_wr(0x40, pmu_rd(0x40) | 0x40);

    pmu_wr(0x33, (pmu_rd(0x33) & 0x3) | 0x50);
    pmu_wr(0x34, (pmu_rd(0x34) & 0x80) | 0x54);     // XXX: see DA9030 page 110 charge_control REG 0x28
    pmu_wr(0x22, 0);

#endif

    /* configure and clear interrupts */
    pmu_wr_multiple(D1759_REG_IRQMASKA, 3, "\x50\xFE\x2B");
    pmu_wr_multiple(D1759_REG_EVENTA, 3, "\xFF\xFF\xFF");

    pmu_wr(D1759_REG_LEDOUT, 0x64); /* set backlight brightness to 40% */
    pmu_wr(D1759_REG_LEDCTL,
            pmu_rd(D1759_REG_LEDCTL) | D1759_LEDCTL_ENABLE); /* backlight on */

#ifndef BOOTLOADER /* see above */
    pmu_wr(0xa, 0x70);
    pmu_wr(0x13, 0x02);
#endif
}

#ifdef BOOTLOADER
bool pmu_is_hibernated(void)
{
    return !!(pmu_rd(D1759_REG_EVENTB) & D1759_EVENTB_WARMBOOT);
}
#endif
