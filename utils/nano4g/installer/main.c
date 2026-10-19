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
#include "hardware.h"
#include "console.h"

#define MAGIC 0x4934474eu /* "N4GI" */
#define CONFIRM 0x45534152u
enum operation
{
    OP_INIT = 1,
    OP_READ,
    OP_ARM,
    OP_ERASE,
    OP_PROGRAM,
    OP_SKIP,
    OP_AES
};
enum state
{
    CLOSED,
    READING,
    ARMED,
    WRITING,
    FAILED,
    FINISHED
};
struct status
{
    uint32_t magic, version, result, state, page, crc, next, chip;
};
static struct status status = {MAGIC, 1, RESULT_OK, CLOSED, 0, 0, 0, 0};
static uint8_t staging[PAGE_BYTES] __attribute__((aligned(32)));
static uint8_t readback[PAGE_BYTES] __attribute__((aligned(32)));
static unsigned uploaded, readable, snapshot_pages;
static uint32_t snapshot_crc;
static uint32_t job[4];
static bool pending, acknowledged, initialized;

static void print_value(const char *label, uint32_t value)
{
    static const char digits[] = "0123456789abcdef";
    char line[40];
    unsigned length = 0;
    while (*label && length < sizeof(line) - 12)
        line[length++] = *label++;
    line[length++] = '0';
    line[length++] = 'x';
    for (unsigned i = 0; i < 8; i++)
        line[length++] = digits[(value >> (28 - i * 4)) & 15];
    line[length] = 0;
    lcd_puts(line);
}

void vendor_reset(void)
{
    /* USB reset/unconfigure invalidates all confirmations. NAND remains as-is.
     */
    initialized = pending = acknowledged = false;
    uploaded = readable = snapshot_pages = 0;
    snapshot_crc = 0xffffffff;
    status.result = RESULT_OK;
    status.state = CLOSED;
    status.next = status.page = status.crc = status.chip = 0;
}

int vendor_request(uint8_t request, uint16_t value, uint16_t index, bool input,
                   uint8_t *data, unsigned length)
{
    if (index)
        return -1;
    if (input && request == 0x42 && !value && length == sizeof(status))
    {
        memcpy(data, &status, sizeof(status));
        return sizeof(status);
    }
    if (input && request == 0x43 && length && length <= 64 &&
        value <= readable && length <= readable - value && !pending)
    {
        memcpy(data, readback + value, length);
        return length;
    }
    if (pending || status.state == FAILED)
        return -1;
    if (!input && request == 0x40 && length && length <= 64)
    {
        if (value == 0)
            uploaded = 0;
        if (value != uploaded || length > PAGE_BYTES - uploaded)
            return -1;
        memcpy(staging + uploaded, data, length);
        uploaded += length;
        return 0;
    }
    if (!input && request == 0x41 && !value && length == sizeof(job))
    {
        memcpy(job, data, sizeof(job));
        status.result = RESULT_BUSY;
        pending = true;
        acknowledged = false;
        return 0;
    }
    return -1;
}

void vendor_status_complete(void)
{
    if (pending)
        acknowledged = true;
}

static int execute(void)
{
    unsigned operation = job[0], page = job[1];
    uint32_t token = job[2], argument = job[3];
    readable = 0;
    if (operation == OP_INIT)
    {
        if ((status.state != CLOSED && status.state != READING &&
             status.state != FINISHED) ||
            page || token || argument)
            return ERROR_STATE;
        snapshot_pages = 0;
        snapshot_crc = 0xffffffff;
        uploaded = 0;
        status.next = status.crc = 0;
        lcd_puts("Detecting NAND");
        int result = flash_init(&status.chip);
        if (!result)
        {
            initialized = true;
            status.state = READING;
            print_value("NAND ID ", status.chip);
        }
        return result;
    }
    if (operation == OP_AES)
    {
        if (uploaded != 16 || page || token || argument ||
            status.state == WRITING)
            return ERROR_REQUEST;
        lcd_puts("Authenticating header");
        int result = encrypt_header(staging);
        if (!result)
        {
            memcpy(readback, staging, 16);
            readable = 16;
            lcd_puts("Header authenticated");
        }
        uploaded = 0;
        return result;
    }
    if (!initialized)
        return ERROR_STATE;
    if (operation == OP_READ)
    {
        if (page >= BLOCK_PAGES || token || argument)
            return ERROR_REQUEST;
        print_value("Reading page ", page);
        int result = flash_read(page, readback);
        if (result)
            return result;
        readable = PAGE_BYTES;
        status.page = page;
        if (status.state == READING)
        {
            if (page == 0)
            {
                snapshot_pages = 0;
                snapshot_crc = 0xffffffff;
            }
            if (page == snapshot_pages)
            {
                snapshot_crc = crc_update(snapshot_crc, readback, PAGE_BYTES);
                snapshot_pages++;
                status.crc = snapshot_crc ^ 0xffffffff;
            }
            else
                snapshot_pages = 0;
        }
        return RESULT_OK;
    }
    if (operation == OP_ARM)
    {
        if (status.state != READING || snapshot_pages != BLOCK_PAGES || page ||
            token != CONFIRM || argument != (snapshot_crc ^ 0xffffffff))
            return ERROR_STATE;
        status.state = ARMED;
        lcd_puts("Backup verified");
        return RESULT_OK;
    }
    if (operation == OP_ERASE)
    {
        if (status.state != ARMED || page || token != CONFIRM || argument)
            return ERROR_STATE;
        /* Consume authorization before issuing the command: never retry. */
        status.state = WRITING;
        status.next = 0;
        uploaded = 0;
        lcd_puts("Erasing CE0 block 0");
        int result = flash_erase();
        if (result)
            return result;
        lcd_puts("Checking erased pages");
        for (unsigned p = 0; p < BLOCK_PAGES; p++)
        {
            status.page = p;
            result = flash_read(p, readback);
            if (result)
                return result;
            for (unsigned i = 0; i < PAGE_BYTES; i++)
                if (readback[i] != 0xff)
                    return ERROR_VERIFY;
        }
        return RESULT_OK;
    }
    if (operation == OP_PROGRAM || operation == OP_SKIP)
    {
        if (status.state != WRITING || page != status.next ||
            page >= BLOCK_PAGES || token != CONFIRM || uploaded != PAGE_BYTES ||
            (crc_update(0xffffffff, staging, PAGE_BYTES) ^ 0xffffffff) !=
                argument)
            return ERROR_STATE;
        status.page = page;
        int result = RESULT_OK;
        if (operation == OP_SKIP)
        {
            for (unsigned i = 0; i < PAGE_BYTES; i++)
                if (staging[i] != 0xff)
                    return ERROR_REQUEST;
        }
        else
        {
            print_value("Programming page ", page);
            result = flash_program(page, staging);
        }
        uploaded = 0;
        if (!result)
        {
            print_value("Verifying page ", page);
            result = flash_read(page, readback);
        }
        if (!result && memcmp(staging, readback, PAGE_BYTES))
            result = ERROR_VERIFY;
        if (result)
            return result;
        readable = PAGE_BYTES;
        status.next++;
        if (status.next == BLOCK_PAGES)
        {
            status.state = FINISHED;
            lcd_puts("Block complete");
        }
        return RESULT_OK;
    }
    return ERROR_REQUEST;
}

void run_job(void)
{
    if (!pending || !acknowledged)
        return;
    int result = execute();
    status.result = result;
    if (result)
    {
        static const char * const errors[] = {
            "OK", "Busy", "Invalid request", "Invalid session state",
            "Hardware timeout", "Uncorrectable NAND data", "NAND failure",
            "Verification failed", "Unsupported NAND", "USB failure"
        };
        status.state = FAILED;
        if ((unsigned)result < sizeof(errors) / sizeof(errors[0]))
            lcd_puts(errors[result]);
        print_value("ERROR ", result);
        print_value("Operation ", job[0]);
        print_value("Page ", job[1]);
    }
    pending = acknowledged = false;
}

int main(void)
{
    lcd_init();
    lcd_puts("Rockbox nano 4G installer");
    lcd_puts("Initializing USB");
    vendor_reset();
    if (!usb_init())
    {
        lcd_puts("ERROR: USB initialization");
        return ERROR_USB;
    }
    lcd_puts("Waiting for USB host");
    for (;;)
    {
        usb_poll();
        run_job();
    }
}
