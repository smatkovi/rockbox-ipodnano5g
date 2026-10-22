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

/* Read-only NAND bring-up test for the nano 5G: the nano 4G NAND driver and
 * FTL with the 8 KiB-page READ program. Nothing is written to the flash.
 * The result goes to the text buffer below (debug menu) and to logf (the
 * devloop mailbox). */

#define LOGF_ENABLE
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "config.h"
#include "system.h"
#include "logf.h"
#include "s5l87xx.h"
#include "../ipodnano4g/nand-target.h"
#include "../ipodnano4g/ftl-target.h"
#include "nandtest-nano5g.h"

extern char ftl_debug_text[];

char nandtest_text[NANDTEST_TEXT_SIZE];
static int nandtest_len;
static uint8_t nandtest_page[NAND_PAGE_SIZE] CACHEALIGN_ATTR;
static uint8_t nandtest_meta[NAND_META_SIZE];

static void out(const char *fmt, ...)
{
    va_list ap;
    char line[64];

    va_start(ap, fmt);
    vsnprintf(line, sizeof(line), fmt, ap);
    va_end(ap);
    logf("nand: %s", line);
    if (nandtest_len < NANDTEST_TEXT_SIZE - 1)
        nandtest_len += snprintf(nandtest_text + nandtest_len,
                                 NANDTEST_TEXT_SIZE - nandtest_len, "%s\n",
                                 line);
}

/* Partition entries of an MBR in nandtest_page */
static void show_mbr(const char *what)
{
    if (nandtest_page[510] != 0x55 || nandtest_page[511] != 0xaa)
    {
        out("%s: no MBR (%02x%02x)", what, nandtest_page[510],
            nandtest_page[511]);
        return;
    }
    for (int i = 0; i < 4; i++)
    {
        const uint8_t *e = nandtest_page + 0x1be + 16 * i;
        uint32_t start = e[8] | (e[9] << 8) | (e[10] << 16)
                         | ((uint32_t)e[11] << 24);
        uint32_t size = e[12] | (e[13] << 8) | (e[14] << 16)
                        | ((uint32_t)e[15] << 24);
        if (e[4] || size)
            out("%s p%d type %02x %lu+%lu", what, i, e[4],
                (unsigned long)start, (unsigned long)size);
    }
}

void nandtest_run(void)
{
    const struct nand_geometry *g;
    const uint32_t *ids;
    int rc;

    nandtest_len = 0;
    nandtest_text[0] = 0;
    out("PCON6-8 %08lx %08lx %08lx", (unsigned long)PCON(6),
        (unsigned long)PCON(7), (unsigned long)PCON(8));

    rc = nand_phys_init();
    ids = nand_get_raw_ids();
    if (ids)
        for (int ce = 0; ce < NAND_MAX_BANKS; ce += 4)
            out("id%d %08lx %08lx %08lx %08lx", ce, (unsigned long)ids[ce],
                (unsigned long)ids[ce + 1], (unsigned long)ids[ce + 2],
                (unsigned long)ids[ce + 3]);
    out("phys_init %d", rc);
    if (rc)
        return;
    g = nand_get_geometry();
    out("%u banks %u blk %u+%u B ecc%u", g->banks, g->blocks, g->page_size,
        g->spare_size, g->ecc_bits);

    /* the first page of bank 0 (Apple's boot area: may read as erased) and
     * the first page of the last block (the VFL signature lives at the end) */
    rc = nand_read_page(0, 0, nandtest_page, nandtest_meta);
    out("page 0: %d, %02x%02x%02x%02x meta %02x%02x%02x%02x", rc,
        nandtest_page[0], nandtest_page[1], nandtest_page[2], nandtest_page[3],
        nandtest_meta[0], nandtest_meta[1], nandtest_meta[2], nandtest_meta[3]);
    rc = nand_read_page(0, (g->blocks - 1) * g->pages_per_block, nandtest_page,
                        nandtest_meta);
    out("last blk: %d, %.8s meta %02x%02x%02x%02x", rc, nandtest_page,
        nandtest_meta[0], nandtest_meta[1], nandtest_meta[2],
        nandtest_meta[3]);

    rc = ftl_init();
    out("ftl_init %d%s, %lu pages", rc, ftl_was_restored() ? " (restored)" : "",
        (unsigned long)ftl_num_sectors());
    for (char *l = ftl_debug_text, *e; *l; l = e + 1)
    {
        if (!(e = strchr(l, '\n')))
            break;
        out("vfl %.*s", (int)(e - l), l);
    }
    if (rc)
        return;
    rc = ftl_read(0, 1, nandtest_page);
    out("ftl page 0: %d", rc);
    if (rc)
        return;
    show_mbr("fw");
    /* the data partition's boot sector, if the MBR counts in FTL pages */
    if (nandtest_page[510] == 0x55 && nandtest_page[511] == 0xaa)
        for (int i = 0; i < 4; i++)
        {
            const uint8_t *e = nandtest_page + 0x1be + 16 * i;
            uint32_t start = e[8] | (e[9] << 8) | (e[10] << 16)
                             | ((uint32_t)e[11] << 24);
            if (e[4] != 0x0b && e[4] != 0x0c)
                continue;
            /* the MBR counts 4096-byte sectors, half an FTL page */
            const uint8_t *b = nandtest_page + (start & 1) * 4096;
            rc = ftl_read(start / 2, 1, nandtest_page);
            out("p%d boot: %d %.8s %.5s %02x%02x", i, rc, b + 3, b + 0x52,
                b[510], b[511]);
            break;
        }
    out("reads %lu", (unsigned long)nand_get_read_count());
}
