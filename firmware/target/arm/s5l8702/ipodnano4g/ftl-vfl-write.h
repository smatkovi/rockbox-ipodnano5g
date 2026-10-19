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

/* Private write half of the virtual flash layer. Included by ftl-nano4g.c
 * in the main firmware only. The storage mutex protects these buffers too.
 *
 * A program failure does not change the page's address: other pages in that
 * block may still be live. It records a pending replacement instead. Only
 * the owner of a free virtual block may erase it and install a replacement.
 * Changes to the address map become durable before an erase reports success.
 */
#define VFL_W_SEQUENCE       0x004
#define VFL_W_ACTIVE         0x00c
#define VFL_W_NEXT           0x00e
#define VFL_W_ERASE_FAILURES 0x014
#define VFL_W_RESERVE_CURSOR 0x016
#define VFL_W_SCRUB_COUNT    0x6a0
#define VFL_W_SCRUB_LIST     0x6a2
#define VFL_W_SCRUB_LIMIT    20

static bool vfl_write_failed;
static uint8_t vfl_write_page[NAND_PAGE_SIZE] CACHEALIGN_ATTR;
static uint8_t vfl_verify_page[NAND_PAGE_SIZE] CACHEALIGN_ATTR;
static uint8_t vfl_write_meta[NAND_META_SIZE] __attribute__((aligned(4)));
static uint8_t vfl_verify_meta[NAND_META_SIZE] __attribute__((aligned(4)));

static bool vfl_context_read_group(unsigned int bank, unsigned int block,
                                   unsigned int page)
{
    unsigned int i;

    for (i = 0; i < VFL_CXT_COPIES; i++)
        if (nand_read_page(bank, block * FTL_PAGES_PER_BLOCK + page + i,
                           vfl_verify_page, vfl_verify_meta) == NAND_OK &&
            vfl_verify_meta[8] == 0 && vfl_verify_meta[9] == 0x80)
            return true;
    return false;
}

/* Context writes must not reuse the caller's data or metadata buffers. */
static int vfl_write_init(void)
{
    unsigned int bank, i, j;

    vfl_write_failed = true;
    for (bank = 0; bank < FTL_BANKS; bank++)
    {
        uint8_t *c = vfl_cxt[bank];
        unsigned int active = 4, next = 0;
        uint32_t sequence = UINT32_MAX;
        unsigned int count = get16(c + VFL_W_SCRUB_COUNT);

        if (count > VFL_W_SCRUB_LIMIT)
            return NAND_ERR_FTL;
        for (i = 0; i < 4; i++)
        {
            unsigned int b = get16(c + VFL_CXT_BLOCKS + 2 * i);
            if (b == 0xffff)
                continue;
            if (!b || b > VFL_SCAN_LAST || b >= vfl_pool_start)
                return NAND_ERR_FTL;
            for (j = 0; j < i; j++)
                if (b == get16(c + VFL_CXT_BLOCKS + 2 * j))
                    return NAND_ERR_FTL;
            if (vfl_context_read_group(bank, b, 0))
            {
                uint32_t candidate = get32(vfl_verify_meta);
                if (candidate && candidate <= sequence)
                {
                    sequence = candidate;
                    active = i;
                }
            }
        }
        if (active == 4)
            return NAND_ERR_FTL;
        /* Recover the append cursor from the flash itself. A recovered
         * volume need not have trustworthy cursor fields in its payload. */
        for (i = 0; i < FTL_PAGES_PER_BLOCK; i += VFL_CXT_COPIES)
        {
            unsigned int block = get16(c + VFL_CXT_BLOCKS + 2 * active);
            if (!vfl_context_read_group(bank, block, i))
                break;
            sequence = get32(vfl_verify_meta);
            next = i + VFL_CXT_COPIES;
        }
        put16(c + VFL_W_ACTIVE, active);
        put16(c + VFL_W_NEXT, next);
        put32(c + VFL_W_SEQUENCE, sequence);
        for (i = 0; i < count; i++)
            if (get16(c + VFL_W_SCRUB_LIST + 2 * i) >= vfl_usable)
                return NAND_ERR_FTL;
    }
    vfl_write_failed = false;
    return NAND_OK;
}

static int vfl_write_stop(void)
{
    /* A partially persisted address change cannot be rolled back safely.
     * Reopen the volume before allowing any more changes. */
    vfl_write_failed = true;
    return NAND_ERR_FTL;
}

static void vfl_update_checksum(uint8_t *c)
{
    unsigned int i;
    uint32_t sum = 0, parity = 0;

    for (i = 0; i < VFL_CXT_SUM1; i += 4)
    {
        uint32_t word = get32(c + i);
        sum += word;
        parity ^= word;
    }
    put32(c + VFL_CXT_SUM1, sum + 0xaabbccdd);
    put32(c + VFL_CXT_SUM2, parity ^ 0xaabbccdd);
}

static bool vfl_context_append(unsigned int bank)
{
    uint8_t *c = vfl_cxt[bank];
    unsigned int i, good = 0;
    unsigned int block = get16(c + VFL_CXT_BLOCKS +
                              2 * get16(c + VFL_W_ACTIVE));
    unsigned int next = get16(c + VFL_W_NEXT);
    uint32_t sequence = get32(c + VFL_W_SEQUENCE) - 1;
    uint32_t generation = 0;
    uint32_t row = block * FTL_PAGES_PER_BLOCK + next;

    if (!sequence || next + VFL_CXT_COPIES > FTL_PAGES_PER_BLOCK)
        return false;
    /* Do not trust a stale cursor enough to program over existing data.
     * This also handles an interrupted append with only some copies written. */
    for (i = 0; i < VFL_CXT_COPIES; i++)
        if (nand_read_page(bank, row + i, vfl_verify_page, vfl_verify_meta)
            != NAND_ERASED)
            return false;
    for (i = 0; i < FTL_BANKS; i++)
        if (get32(vfl_cxt[i] + VFL_CXT_USN) > generation)
            generation = get32(vfl_cxt[i] + VFL_CXT_USN);
    if (generation == UINT32_MAX)
        return false;

    put32(c + VFL_CXT_USN, generation + 1);
    put32(c + VFL_W_SEQUENCE, sequence);
    put16(c + VFL_W_NEXT, next + VFL_CXT_COPIES);
    /* Each bank has its own remap table, but these fields are volume-wide.
     * Copy them from the values selected at mount, not an older bank copy. */
    put16(c + VFL_CXT_USABLE, vfl_usable);
    put16(c + VFL_CXT_POOL_START, vfl_pool_start);
    for (i = 0; i < 3; i++)
        put16(c + VFL_CXT_FTL_CTRL + 2 * i, vfl_ftl_ctrl[i]);
    vfl_update_checksum(c);
    memset(vfl_write_page, 0xff, sizeof(vfl_write_page));
    memcpy(vfl_write_page, c, VFL_CXT_SIZE);
    memset(vfl_write_meta, 0xff, sizeof(vfl_write_meta));
    put32(vfl_write_meta, sequence);
    vfl_write_meta[8] = 0;
    vfl_write_meta[9] = 0x80;
    for (i = 0; i < VFL_CXT_COPIES; i++)
        if (nand_device_program(bank, row + i, vfl_write_page, vfl_write_meta)
            != NAND_OK)
            return false;
    for (i = 0; i < VFL_CXT_COPIES; i++)
        if (nand_read_page(bank, row + i, vfl_verify_page, vfl_verify_meta)
            == NAND_OK && !memcmp(vfl_verify_page, c, VFL_CXT_SIZE) &&
            !memcmp(vfl_verify_meta, vfl_write_meta, NAND_META_SIZE))
            good++;
    return good >= 5;
}

static int vfl_store_context(unsigned int bank)
{
    uint8_t *c = vfl_cxt[bank];
    unsigned int original = get16(c + VFL_W_ACTIVE);
    unsigned int step;

    if (vfl_write_failed)
        return NAND_ERR_FTL;
    if (vfl_context_append(bank))
        return NAND_OK;
    /* Keep the original block intact, even if every alternate block fails.
     * There may already be readable copies of the new context in it. */
    for (step = 1; step < 4; step++)
    {
        unsigned int slot = (original + step) % 4;
        unsigned int block = get16(c + VFL_CXT_BLOCKS + 2 * slot);
        if (block == 0xffff || nand_device_erase(bank, block) != NAND_OK)
            continue;
        put16(c + VFL_W_ACTIVE, slot);
        put16(c + VFL_W_NEXT, 0);
        if (vfl_context_append(bank))
            return NAND_OK;
    }
    return vfl_write_stop();
}

static int vfl_scrub_index(unsigned int bank, unsigned int vb)
{
    const uint8_t *c = vfl_cxt[bank];
    unsigned int i, count = get16(c + VFL_W_SCRUB_COUNT);

    for (i = 0; i < count; i++)
        if (get16(c + VFL_W_SCRUB_LIST + 2 * i) == vb)
            return i;
    return -1;
}

static int vfl_queue_replacement(unsigned int bank, unsigned int vb)
{
    uint8_t *c = vfl_cxt[bank];
    unsigned int count = get16(c + VFL_W_SCRUB_COUNT);

    if (vfl_scrub_index(bank, vb) >= 0)
        return NAND_OK;
    if (count >= VFL_W_SCRUB_LIMIT)
        return vfl_write_stop();
    put16(c + VFL_W_SCRUB_LIST + 2 * count, vb);
    put16(c + VFL_W_SCRUB_COUNT, count + 1);
    return vfl_store_context(bank);
}

static void vfl_clear_replacement(unsigned int bank, unsigned int vb)
{
    uint8_t *c = vfl_cxt[bank];
    int index = vfl_scrub_index(bank, vb);

    if (index >= 0)
    {
        unsigned int count = get16(c + VFL_W_SCRUB_COUNT) - 1;
        put16(c + VFL_W_SCRUB_LIST + 2 * index,
              get16(c + VFL_W_SCRUB_LIST + 2 * count));
        put16(c + VFL_W_SCRUB_LIST + 2 * count, 0);
        put16(c + VFL_W_SCRUB_COUNT, count);
    }
}

static void vfl_set_remap(unsigned int bank, unsigned int index, uint16_t value)
{
    vfl_remap[bank][index] = value;
    put16(vfl_cxt[bank] + VFL_CXT_REMAP + 2 * index, value);
}

/* Select and erase a spare before publishing the new address. No other
 * live virtual block or physical context block is touched here. */
static int vfl_replace_block(unsigned int bank, unsigned int vb)
{
    uint8_t *c = vfl_cxt[bank];
    unsigned int i, j, entries = vfl_blocks - vfl_pool_start;

    for (i = 0; i < entries; i++)
    {
        unsigned int physical = vfl_pool_start + i;
        if (vfl_remap[bank][i] != VFL_REMAP_UNUSED)
            continue;
        if (nand_device_erase(bank, physical) != NAND_OK)
        {
            vfl_set_remap(bank, i, VFL_REMAP_BAD);
            vfl_bad[bank][physical >> 3] |= 1 << (physical & 7);
            continue;
        }
        for (j = 0; j < entries; j++)
            if (vfl_remap[bank][j] == vb)
            {
                unsigned int old = vfl_pool_start + j;
                vfl_set_remap(bank, j, VFL_REMAP_BAD);
                vfl_bad[bank][old >> 3] |= 1 << (old & 7);
            }
        vfl_set_remap(bank, i, vb);
        vfl_bad[bank][vb >> 3] |= 1 << (vb & 7);
        put16(c + VFL_W_RESERVE_CURSOR, i + 1);
        vfl_clear_replacement(bank, vb);
        return vfl_store_context(bank);
    }
    /* Preserve any newly discovered bad reserve entries if possible. */
    vfl_store_context(bank);
    return vfl_write_stop();
}

static bool vfl_data_block(unsigned int bank, unsigned int physical)
{
    unsigned int i;

    if (!physical || physical >= vfl_blocks)
        return false;
    for (i = 0; i < 4; i++)
        if (physical == get16(vfl_cxt[bank] + VFL_CXT_BLOCKS + 2 * i))
            return false;
    return true;
}

static int vfl_program(uint32_t vpn, const void *data, const uint8_t *meta)
{
    uint8_t bank;
    uint32_t page;
    int rc;

    if (vfl_write_failed || vpn / FTL_PAGES_PER_VB >= vfl_usable ||
        !data || !meta || !vfl_locate(vpn, &bank, &page) ||
        !vfl_data_block(bank, page / FTL_PAGES_PER_BLOCK))
        return NAND_ERR_FTL;
    rc = nand_device_program(bank, page, data, meta);
    if (rc != NAND_OK &&
        vfl_queue_replacement(bank, vpn / FTL_PAGES_PER_VB) != NAND_OK)
        return NAND_ERR_FTL;
    return rc;
}

static int vfl_erase(unsigned int vb)
{
    unsigned int bank;

    if (vfl_write_failed || vb >= vfl_usable)
        return NAND_ERR_FTL;
    for (bank = 0; bank < FTL_BANKS; bank++)
    {
        unsigned int physical = vfl_remap_block(bank, vb);
        if (vfl_scrub_index(bank, vb) < 0)
        {
            uint8_t *c = vfl_cxt[bank];
            if (!vfl_data_block(bank, physical))
                return vfl_write_stop();
            if (nand_device_erase(bank, physical) == NAND_OK)
                continue;
            put16(c + VFL_W_ERASE_FAILURES,
                  get16(c + VFL_W_ERASE_FAILURES) + 1);
        }
        if (vfl_replace_block(bank, vb) != NAND_OK)
            return NAND_ERR_FTL;
    }
    return NAND_OK;
}
