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
#ifndef NANO4G_INSTALLER_HARDWARE_H
#define NANO4G_INSTALLER_HARDWARE_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define REG32(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define PAGE_BYTES 1536u
#define BLOCK_PAGES 128u
#define BLOCK_BYTES (PAGE_BYTES * BLOCK_PAGES)

/* All errors are terminal for the current destructive session. */
enum result
{
    RESULT_OK, RESULT_BUSY, ERROR_REQUEST, ERROR_STATE, ERROR_TIMEOUT,
    ERROR_ECC, ERROR_NAND_STATUS, ERROR_VERIFY, ERROR_CHIP, ERROR_USB
};

static inline uint32_t now_us(void)
{
    return REG32(0x3c7000b4);
}
bool wait_mask(uintptr_t reg, uint32_t mask, uint32_t value);
void delay_us(uint32_t usec);
void *memcpy(void *dst, const void *src, size_t n);
void *memset(void *dst, int value, size_t n);
int memcmp(const void *a, const void *b, size_t n);
uint32_t crc_update(uint32_t crc, const uint8_t *data, size_t n);

int flash_init(uint32_t *chip_id);
int flash_read(unsigned page, void *data);
int flash_erase(void);
int flash_program(unsigned page, const void *data);
int encrypt_header(uint8_t data[16]);

bool usb_init(void);
void usb_poll(void);
/* USB owns the buffer until completion. Requests are at most 64 bytes. */
int vendor_request(uint8_t request, uint16_t value, uint16_t index,
                   bool input, uint8_t *data, unsigned length);
void vendor_status_complete(void);
void vendor_reset(void);
void run_job(void);
#endif
