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

/* Reserved pages use three BCH16 codewords without FTL metadata. */
#include "hardware.h"
#include "nand-chip-table.h"
#include "fmss-installer.h"

#define FMC_BASE 0x38a00000u
#define FMC(off) REG32(FMC_BASE + (off))
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
enum
{
    TRANSFER = 0x004, ECC_RESET = 0x81c,
    SEQ_CONTROL = 0xc00, SEQ_PROGRAM = 0xc04, SEQ_STATE = 0xc08,
    SEQ_IRQ = 0xc0c, SEQ_RESULT = 0xc30,
    BUFFER_RESET = 0xc60, BUFFER_READY = 0xc64, BUFFER_CONFIG = 0xc6c,
    SECTOR_STATUS = 0xd00, ID_BUFFER = 0xd08, PAGE_ROW = 0xd0c,
    CHIP_MASK = 0xd10, DATA_BUFFER = 0xd20
};
static bool available;
static uint32_t chip_ids[NAND_MAX_BANKS] __attribute__((aligned(32)));

static int poll(unsigned reg, uint32_t mask, uint32_t value, uint32_t timeout)
{
    uint32_t start = now_us();
    unsigned budget = 10000000;
    do
    {
        if ((FMC(reg) & mask) == value)
            return RESULT_OK;
    } while (--budget && (uint32_t)(now_us() - start) < timeout);
    return ERROR_TIMEOUT;
}

static int reset_controller(void)
{
    FMC(SEQ_CONTROL) = 8;
    uint32_t start = now_us();
    unsigned budget = 100000;
    while (FMC(SEQ_STATE))
    {
        if (FMC(SEQ_STATE) == 4)
        {
            FMC(SEQ_CONTROL) = 2;
            while (FMC(SEQ_STATE) != 0 && FMC(SEQ_STATE) != 3)
                if (!--budget || (uint32_t)(now_us() - start) >= 100)
                    return ERROR_TIMEOUT;
            break;
        }
        if (!--budget || (uint32_t)(now_us() - start) >= 100)
            return ERROR_TIMEOUT;
    }
    if (FMC(BUFFER_CONFIG) != 0x10)
    {
        FMC(BUFFER_RESET) = 1;
        if (poll(BUFFER_READY, UINT32_MAX, 1, 100))
            return ERROR_TIMEOUT;
        FMC(BUFFER_RESET) = 0;
    }
    FMC(SEQ_CONTROL) = 0x80000;
    FMC(TRANSFER) = 0x800;
    if (poll(TRANSFER, 1u << 30, 1u << 30, 100))
        return ERROR_TIMEOUT;
    FMC(TRANSFER) = 0x80000000;
    FMC(ECC_RESET) = 1;
    return RESULT_OK;
}

/* Startup leaves caches off and SDRAM addresses equal to DMA addresses. */
static int run(const uint32_t *program)
{
    FMC(SEQ_PROGRAM) = (uintptr_t)program;
    FMC(SEQ_IRQ) = 0xff;
    if (poll(SEQ_IRQ, 0xd, 0, 100))
        return ERROR_TIMEOUT;
    FMC(BUFFER_CONFIG) = 0;
    FMC(BUFFER_RESET) = 1;
    if (poll(BUFFER_READY, UINT32_MAX, 1, 100))
        return ERROR_TIMEOUT;
    FMC(BUFFER_RESET) = 0;
    FMC(SEQ_CONTROL) = 0xffb5;
    uint32_t start = now_us(), irq;
    unsigned budget = 100000000;
    do
    {
        irq = FMC(SEQ_IRQ) & 0xd;
        if (!--budget || (uint32_t)(now_us() - start) >= 2000000)
            return ERROR_TIMEOUT;
    } while (!irq);
    uint32_t result = FMC(SEQ_RESULT);
    FMC(SEQ_IRQ) = 0xd;
    if (poll(SEQ_IRQ, 0xd, 0, 100) || irq != 1 || (result & (1u << 27)))
        return ERROR_TIMEOUT;
    return result & 1 ? ERROR_NAND_STATUS : RESULT_OK;
}

static int finish(int result)
{
    if (result)
    {
        available = false;
        reset_controller();
    }
    return result;
}

int flash_init(uint32_t *chip_id)
{
    available = false;
    REG32(0x3c500048) &= ~((1u << 5) | (1u << 9));
    REG32(0x3cf000c0) = (REG32(0x3cf000c0) & 0xf) | 0x22222220;
    REG32(0x3cf000e0) = 0x22222222;
    REG32(0x3cf00100) = (REG32(0x3cf00100) & 0xff0000f0) | 0x333302;
    *chip_id = 0;
    int result = reset_controller();
    if (!result)
        result = run(fmss_prog_reset);
    if (result)
        return finish(result);
    delay_us(10000);
    FMC(ID_BUFFER) = (uintptr_t)chip_ids;
    FMC(PAGE_ROW) = NAND_MAX_BANKS;
    result = run(fmss_prog_readid);
    if (result)
        return finish(result);
    *chip_id = chip_ids[0];
    const struct nand_part *part = nand_find_part(*chip_id);
    if (!part || part->pages_per_block != BLOCK_PAGES || part->page_size != 4096)
        return finish(ERROR_CHIP);
    for (unsigned i = 0; i < ARRAY_SIZE(nand_populations); i++)
    {
        /* Reserved physical addressing is independent of the volume layout. */
        if (nand_population_matches(&nand_populations[i], chip_ids))
        {
            available = true;
            return RESULT_OK;
        }
    }
    return finish(ERROR_CHIP);
}

static int page_operation(unsigned page, const void *data,
                          const uint32_t *program)
{
    if (!available || page >= BLOCK_PAGES)
        return ERROR_STATE;
    if (!data || ((uintptr_t)data & 31))
        return ERROR_REQUEST;
    FMC(PAGE_ROW) = page;
    FMC(CHIP_MASK) = 1; /* CE0 only */
    FMC(DATA_BUFFER) = (uintptr_t)data;
    return finish(run(program));
}

int flash_read(unsigned page, void *data)
{
    int result = page_operation(page, data, fmss_prog_boot_read);
    if (result)
        return result;
    for (unsigned sector = 0; sector < 3; sector++)
    {
        uint32_t ecc = FMC(SECTOR_STATUS + sector * 4);
        if ((ecc & 1) && !(ecc & 0x40))
            return finish(ERROR_ECC);
        if (!(ecc & 0x40))
            continue;
        const uint8_t *bytes = (const uint8_t *)data + sector * 512;
        for (unsigned i = 0; i < 512; i++)
            if (bytes[i] != 0xff)
                return finish(ERROR_ECC);
    }
    return RESULT_OK;
}

int flash_erase(void)
{
    if (!available)
        return ERROR_STATE;
    FMC(PAGE_ROW) = 0; /* No address argument: only physical block zero. */
    FMC(CHIP_MASK) = 1;
    return finish(run(fmss_prog_erase));
}

int flash_program(unsigned page, const void *data)
{
    return page_operation(page, data, fmss_prog_boot_program);
}
