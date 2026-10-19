/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright 2010 TheSeven
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

/* Polled EP0 transport. */
#include "hardware.h"
#include "console.h"
#define USB_BASE 0x38400000u
#define U(off) REG32(USB_BASE + (off))
#define PHY(off) REG32(0x3c400000u + (off))
enum
{
    AHB = 0x008,
    CONFIG = 0x00c,
    RESET = 0x010,
    INTERRUPT = 0x014,
    MASK = 0x018,
    RX_STATUS = 0x020,
    RX_SIZE = 0x024,
    TX_SIZE = 0x028,
    CORE_CONFIG = 0x038,
    DEVICE_CONFIG = 0x800,
    DEVICE_CONTROL = 0x804,
    IN_CONTROL = 0x900,
    IN_INTERRUPT = 0x908,
    IN_SIZE = 0x910,
    OUT_CONTROL = 0xb00,
    OUT_INTERRUPT = 0xb08,
    OUT_SIZE = 0xb10,
    CLOCK = 0xe00,
    FIFO = 0x1000
};
enum
{
    ENABLE = 1u << 31,
    DISABLE = 1u << 30,
    SET_NAK = 1u << 27,
    CLEAR_NAK = 1u << 26,
    ACTIVE = 1u << 15,
    STALL = 1u << 21
};
enum phase
{
    IDLE,
    IN_DATA,
    OUT_DATA,
    IN_STATUS,
    OUT_STATUS
};
static enum phase phase;
static uint8_t packet[64] __attribute__((aligned(4)));
static uint8_t setup[8];
static unsigned received;
static unsigned configuration;
static bool alive;
static bool vendor_out;
static bool setup_pending;
static bool status_received;

/* Experimental development IDs; not an allocated production USB identity. */
static const uint8_t device_descriptor[] = {
    18, 1, 0, 2, 0, 0, 0, 64, 0xff, 0xff, 0x04, 0xe0, 0x00, 0x01, 0, 0, 0, 1};
static const uint8_t config_descriptor[] = {
    9, 2, 18, 0, 1, 1, 0, 0x80, 50, 9, 4, 0, 0, 0, 0xff, 0x52, 1, 0};

static unsigned le16(const uint8_t *p)
{
    return p[0] | p[1] << 8;
}

static void disconnect(const char *reason)
{
    U(DEVICE_CONTROL) |= 2;
    alive = false;
    vendor_reset();
    lcd_puts(reason);
}

static bool flush(unsigned flags)
{
    if (!wait_mask(USB_BASE + RESET, 1u << 31, 1u << 31))
        return false;
    U(RESET) = flags;
    return wait_mask(USB_BASE + RESET, flags & 0x3f, 0);
}

static void arm_out(void)
{
    U(OUT_SIZE) = (3u << 29) | (1u << 19) | 64;
    U(OUT_CONTROL) = ACTIVE | CLEAR_NAK | ENABLE;
}

static bool send_in(unsigned size)
{
    if (!flush(1u << 5))
    {
        disconnect("USB error: TX FIFO timeout");
        return false;
    }
    U(IN_INTERRUPT) = 0xffffffff;
    U(IN_SIZE) = (1u << 19) | size;
    U(IN_CONTROL) = ACTIVE | CLEAR_NAK | ENABLE;
    for (unsigned i = 0; i < size; i += 4)
    {
        uint32_t word = 0;
        for (unsigned j = 0; j < 4 && i + j < size; j++)
            word |= (uint32_t)packet[i + j] << (8 * j);
        U(FIFO) = word;
    }
    return true;
}

static void finish_in(void)
{
    uint32_t in = U(IN_INTERRUPT);
    U(IN_INTERRUPT) = in;
    if (in & 8)
    {
        disconnect("USB error: IN transfer timeout");
        return;
    }
    if (!(in & 1))
        return;
    if (phase == IN_DATA)
    {
        phase = OUT_STATUS;
        status_received = false;
        arm_out();
    }
    else if (phase == IN_STATUS)
    {
        phase = IDLE;
        arm_out();
        if (vendor_out)
            vendor_status_complete();
        vendor_out = false;
    }
}

static void stall(void)
{
    phase = IDLE;
    vendor_out = false;
    U(IN_CONTROL) = ACTIVE | STALL;
    U(OUT_CONTROL) = ACTIVE | STALL;
    arm_out();
}

static int standard_request(void)
{
    unsigned value = le16(setup + 2), index = le16(setup + 4);
    unsigned length = le16(setup + 6);
    if (setup[0] == 0x80 && setup[1] == 6 && index == 0)
    {
        const uint8_t *desc;
        unsigned size;
        if (value == 0x100)
        {
            desc = device_descriptor;
            size = sizeof(device_descriptor);
        }
        else if (value == 0x200)
        {
            desc = config_descriptor;
            size = sizeof(config_descriptor);
        }
        else
            return -1;
        if (size > length)
            size = length;
        memcpy(packet, desc, size);
        return size;
    }
    if (setup[0] == 0 && setup[1] == 5 && !index && !length && value < 128)
    {
        U(DEVICE_CONFIG) = (U(DEVICE_CONFIG) & ~(127u << 4)) | value << 4;
        return 0;
    }
    if (setup[0] == 0 && setup[1] == 9 && !index && !length && value <= 1)
    {
        configuration = value;
        vendor_reset();
        lcd_puts(value ? "USB configured" : "USB unconfigured");
        return 0;
    }
    if (setup[0] == 0x80 && setup[1] == 8 && !value && !index && length == 1)
    {
        packet[0] = configuration;
        return 1;
    }
    if ((setup[0] == 0x80 || setup[0] == 0x81) && setup[1] == 0 && !value &&
        !index && length == 2)
    {
        packet[0] = packet[1] = 0;
        return 2;
    }
    if (setup[0] == 0x81 && setup[1] == 10 && !value && !index && length == 1)
    {
        packet[0] = 0;
        return 1;
    }
    if (setup[0] == 1 && setup[1] == 11 && !value && !index && !length)
        return 0;
    return -1;
}

static void handle_setup(void)
{
    /* Completion of the preceding status ACK may be queued together with
     * this SETUP. Deliver it before replacing the command state. */
    finish_in();
    if (!alive)
        return;
    /* A new SETUP cancels any earlier control transfer. Kill stale IN data
     * before reusing the FIFO, including on a host timeout/abort. */
    if (U(IN_CONTROL) & ENABLE)
    {
        U(IN_CONTROL) |= SET_NAK | DISABLE;
        if (!wait_mask(USB_BASE + IN_INTERRUPT, 2, 2))
        {
            disconnect("USB error: IN disable timeout");
            return;
        }
    }
    U(IN_INTERRUPT) = 0xffffffff;
    U(IN_CONTROL) = ACTIVE;
    U(OUT_CONTROL) = ACTIVE;
    vendor_out = false;
    setup_pending = false;
    status_received = false;
    received = 0;
    unsigned length = le16(setup + 6);
    bool input = (setup[0] & 0x80) != 0;
    int result;
    if (setup[0] == 0x40 || setup[0] == 0xc0)
    {
        if (length > sizeof(packet))
        {
            stall();
            return;
        }
        if (!configuration)
        {
            stall();
            return;
        }
        if (!input && length)
        {
            vendor_out = true;
            phase = OUT_DATA;
            arm_out();
            return;
        }
        result = vendor_request(setup[1], le16(setup + 2), le16(setup + 4),
                                input, packet, length);
    }
    else
        result = standard_request();
    if (result < 0)
    {
        stall();
        return;
    }
    if ((unsigned)result > length)
        result = length;
    phase = input ? IN_DATA : IN_STATUS;
    send_in(result);
}

bool usb_init(void)
{
    lcd_puts("USB PHY initialization");
    REG32(0x3c500048) &= ~(1u << 2);
    REG32(0x3c50004c) &= ~(1u << 3);
    uint32_t gates = REG32(0x3c50004c);
    REG32(0x3c50004c) = gates & ~(1u << 14);
    uint32_t clock = 0x10 | (REG32(0x3d100008) & 1);
    REG32(0x3c50004c) = gates;
    U(CLOCK) = 0;
    PHY(0x00) = 0;
    PHY(0x04) = clock;
    delay_us(10);
    PHY(0x1c) = 4;
    U(DEVICE_CONTROL) = 2;
    PHY(0x08) = 9;
    delay_us(10);
    PHY(0x40) = (PHY(0x40) & ~0x7ffu) | 0x347;
    PHY(0x44) = (PHY(0x44) & ~0xfffu) | 0xe3f;
    PHY(0x100) |= 1;
    delay_us(10);
    PHY(0x08) = 0;
    delay_us(815);
    PHY(0x1c) = 6;
    U(CORE_CONFIG) = 1u << 21;
    U(CONFIG) = (1u << 30) | (5u << 10) | (1u << 3);
    delay_us(100);
    if (!flush(1) || !wait_mask(USB_BASE + RESET, 1u << 31, 1u << 31))
    {
        lcd_puts("USB core reset timeout");
        return false;
    }
    U(DEVICE_CONTROL) = 2;
    delay_us(10000);
    U(AHB) = 1; /* PIO, no DMA and no CPU interrupts */
    U(CONFIG) = (1u << 30) | (5u << 10) | (1u << 3);
    U(CORE_CONFIG) = (1u << 21) | (1u << 16);
    U(DEVICE_CONFIG) = 1u << 2;
    U(RX_SIZE) = 256;
    U(TX_SIZE) = (64u << 16) | 256;
    U(MASK) = 0;
    if (!flush((0x10u << 6) | (1u << 5) | (1u << 4)))
    {
        lcd_puts("USB FIFO reset timeout");
        return false;
    }
    U(INTERRUPT) = 0xffffffff;
    U(IN_INTERRUPT) = U(OUT_INTERRUPT) = 0xffffffff;
    U(0x810) = 1; /* endpoint transfer complete */
    U(0x814) = 9; /* transfer complete and setup */
    U(0x81c) = 0x10001;
    alive = true;
    phase = IDLE;
    setup_pending = false;
    status_received = false;
    U(DEVICE_CONTROL) = 0;
    return true;
}

void usb_poll(void)
{
    if (!alive)
        return;
    uint32_t interrupts = U(INTERRUPT);
    if (interrupts & (1u << 12))
    { /* USB reset invalidates backup/write gates */
        lcd_puts("USB bus reset");
        vendor_reset();
        configuration = 0;
        phase = IDLE;
        setup_pending = false;
        status_received = false;
        U(DEVICE_CONFIG) &= ~(127u << 4);
        U(IN_CONTROL) = U(OUT_CONTROL) = ACTIVE | SET_NAK;
        if (!flush((0x10u << 6) | (1u << 5) | (1u << 4)))
        {
            disconnect("USB error: bus reset timeout");
            return;
        }
        U(IN_INTERRUPT) = U(OUT_INTERRUPT) = 0xffffffff;
        U(INTERRUPT) = 1u << 12;
        arm_out();
        return;
    }
    if (interrupts & (1u << 13))
    {
        lcd_puts("USB enumeration done");
        U(INTERRUPT) = 1u << 13;
        U(IN_CONTROL) = ACTIVE;
        arm_out();
    }
    unsigned receive_budget = 32;
    while ((U(INTERRUPT) & (1u << 4)) && receive_budget--)
    {
        /* An OUT status packet is legal immediately after IN data completes. */
        finish_in();
        if (!alive)
            return;
        uint32_t status = U(RX_STATUS);
        unsigned count = (status >> 4) & 0x7ff;
        unsigned type = (status >> 17) & 0xf;
        bool ep0 = (status & 0xf) == 0;
        uint8_t bytes[64];
        for (unsigned i = 0; i < count; i += 4)
        {
            uint32_t word = U(FIFO);
            for (unsigned j = 0; j < 4 && i + j < count; j++)
                if (i + j < sizeof(bytes))
                    bytes[i + j] = word >> (8 * j);
        }
        if (!ep0 || count > sizeof(bytes))
        {
            disconnect("USB error: invalid RX packet");
            return;
        }
        if (type == 6 && count == 8)
        {
            memcpy(setup, bytes, 8);
            setup_pending = true;
        }
        else if (type == 2)
        {
            if (phase == OUT_DATA && count == le16(setup + 6))
            {
                memcpy(packet, bytes, count);
                received = count;
            }
            else if (phase != OUT_STATUS || count)
            {
                stall();
                return;
            }
            else
                status_received = true;
        }
    }
    /* If the bounded batch did not drain the RX queue, retain transfer
     * completion until its payload has actually been consumed. */
    if (U(INTERRUPT) & (1u << 4))
        return;
    uint32_t out = U(OUT_INTERRUPT);
    U(OUT_INTERRUPT) = out;
    /* The SETUP payload can precede completion of the controller's SETUP
     * phase. Reprogram endpoints only after that phase has finished. */
    if (out & 8)
    {
        if (setup_pending)
            handle_setup();
        return;
    }
    if (setup_pending)
        return;
    if (out & (1u << 5))
    {
        /* Status notifications stop OUT0 without delivering new data. */
        arm_out();
    }
    else if ((out & 1) && !(out & (1u << 15)))
    {
        if (phase == OUT_DATA && received == le16(setup + 6))
        {
            int result =
                vendor_request(setup[1], le16(setup + 2), le16(setup + 4),
                               false, packet, received);
            if (result < 0)
                stall();
            else
            {
                phase = IN_STATUS;
                send_in(0);
            }
        }
        else if (phase == OUT_STATUS && status_received)
        {
            phase = IDLE;
            arm_out();
        }
    }
    finish_in();
}
