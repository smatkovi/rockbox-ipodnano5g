/***************************************************************************
 *             __________               __   ___.
 *   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
 *   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
 *   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
 *   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
 *                     \/            \/     \/    \/            \/
 *
 * Copyright (C) 2009 by Michael Sparmann
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

#ifndef NANO4G_NAND_CHIP_TABLE_H
#define NANO4G_NAND_CHIP_TABLE_H

#include "nand-target.h"

/* ==== Chip identification ==== */

/* Match READ ID responses from all eight chip enables against the population
 * table. Geometry comes from the part table; decoded ID fields are diagnostic. */

/* Match the first four READ ID bytes. Parts use 4096-byte (nano 4G) or
 * 8192-byte (nano 5G) pages and 128-page blocks; init checks these against
 * the static request layout. */
struct nand_part
{
    uint32_t id;                /* READ ID bytes 0..3 little endian (byte 0 = maker) */
    uint16_t blocks;            /* per chip enable */
    uint16_t pages_per_block;
    uint16_t page_size;         /* data bytes */
    uint16_t spare;             /* spare bytes per page: BCH16 if it fits, else BCH8 */
    uint8_t  vendor;            /* NAND_VENDOR_* class (the FTL's "vendor type") */
};

static const struct nand_part nand_parts[] =
{
    { 0xb614d5ec, 4096, 128, 4096, 128, NAND_VENDOR_SAMSUNG },  /* ec d5 14 b6 */
    { 0xb655d7ec, 8192, 128, 4096, 128, NAND_VENDOR_SAMSUNG },  /* ec d7 55 b6 */
    { 0xb614d5ad, 4096, 128, 4096, 128, NAND_VENDOR_HYNIX },    /* ad d5 14 b6 */
    { 0xb655d7ad, 8192, 128, 4096, 128, NAND_VENDOR_HYNIX },    /* ad d7 55 b6 */
    { 0xba94d598, 4096, 128, 4096, 218, NAND_VENDOR_TOSHIBA },  /* 98 d5 94 ba */
    { 0xba95d798, 8192, 128, 4096, 218, NAND_VENDOR_TOSHIBA },  /* 98 d7 95 ba */
    { 0x3e94d589, 4096, 128, 4096, 218, NAND_VENDOR_INTEL },    /* 89 d5 94 3e */
    { 0x3ed5d789, 8192, 128, 4096, 218, NAND_VENDOR_INTEL },    /* 89 d7 d5 3e */
    { 0x3e94d52c, 4096, 128, 4096, 218, NAND_VENDOR_MICRON },   /* 2c d5 94 3e */
    { 0x3ed5d72c, 8192, 128, 4096, 218, NAND_VENDOR_MICRON },   /* 2c d7 d5 3e */
    { 0x3e94d72c, 8192, 128, 4096, 218, NAND_VENDOR_MICRON_2 }, /* 2c d7 94 3e */
    /* 8 KiB pages (nano 5G; Apple's 5G bootloader table) */
    { 0x3294d798, 4148, 128, 8192, 376, NAND_VENDOR_TOSHIBA },  /* 98 d7 94 32 */
    { 0x3295de98, 8296, 128, 8192, 376, NAND_VENDOR_TOSHIBA },  /* 98 de 95 32 */
    { 0x3294e798, 4100, 128, 8192, 448, NAND_VENDOR_TOSHIBA },  /* 98 e7 94 32 */
};

/* Each group of four chip enables has the same part and chip count; unused
 * enables must be empty. The first matching row supplies layout and timings
 * (cycle, pulse, hold in ns). Layout 0 has no supported logical-volume configuration. */
struct nand_population
{
    uint8_t  groups;            /* 1 or 2 */
    uint8_t  chips;             /* populated chip enables per group: 2 or 4 */
    uint32_t id;                /* the part, nand_parts[].id */
    uint8_t  t_write[3];        /* program / erase bus timing */
    uint8_t  t_read[3];         /* read bus timing */
    uint32_t layout;            /* NAND_LAYOUT_*, 0 = no logical-volume configuration */
};

static const struct nand_population nand_populations[] =
{
    { 1, 2, 0xb614d5ec, { 25, 12, 10 }, { 25, 12, 10 }, NAND_LAYOUT_2WAY_14 },
    { 1, 4, 0xb614d5ec, { 25, 12, 10 }, { 25, 12, 10 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0xb614d5ec, { 50, 24, 10 }, { 60, 40, 20 }, 0 },
    { 1, 4, 0xb655d7ec, { 45, 25, 15 }, { 50, 25, 15 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0xb655d7ec, { 90, 50, 30 }, { 100, 50, 30 }, 0 },
    { 1, 4, 0xb614d5ad, { 25, 12, 10 }, { 25, 12, 10 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0xb614d5ad, { 50, 24, 20 }, { 50, 24, 20 }, 0 },
    { 1, 4, 0xb655d7ad, { 30, 15, 10 }, { 30, 15, 10 }, NAND_LAYOUT_1WAY },
    { 1, 2, 0xb614d5ad, { 25, 12, 10 }, { 25, 12, 10 }, NAND_LAYOUT_2WAY_14 },
    { 1, 4, 0xba94d598, { 30, 15, 10 }, { 30, 15, 15 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0xba94d598, { 60, 30, 20 }, { 60, 30, 30 }, 0 },
    { 1, 4, 0xba95d798, { 30, 15, 10 }, { 30, 15, 15 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0xba95d798, { 60, 30, 20 }, { 60, 30, 30 }, 0 },
    { 1, 2, 0x3e94d589, { 20, 10, 7 }, { 25, 12, 10 }, NAND_LAYOUT_2WAY_12_14 },
    { 1, 2, 0x3ed5d789, { 20, 10, 7 }, { 25, 12, 10 }, NAND_LAYOUT_2WAY_11_12 },
    { 1, 4, 0x3ed5d789, { 20, 10, 7 }, { 25, 12, 10 }, NAND_LAYOUT_1WAY },
    { 2, 4, 0x3ed5d789, { 40, 20, 14 }, { 50, 24, 20 }, 0 },
    { 2, 2, 0x3ed5d789, { 40, 20, 14 }, { 50, 24, 20 }, 0 },
    { 1, 2, 0x3e94d52c, { 25, 10, 15 }, { 25, 10, 15 }, NAND_LAYOUT_2WAY_12_14 },
    { 1, 2, 0x3ed5d72c, { 20, 10, 7 }, { 25, 12, 10 }, NAND_LAYOUT_2WAY_11_12 },
    { 2, 2, 0x3ed5d72c, { 50, 20, 30 }, { 50, 20, 30 }, 0 },
    { 1, 4, 0x3ed5d72c, { 20, 10, 7 }, { 25, 12, 10 }, NAND_LAYOUT_1WAY },
    { 1, 2, 0x3e94d72c, { 20, 10, 7 }, { 20, 10, 7 }, NAND_LAYOUT_2WAY_12_14 },
    /* nano 5G. Apple reads these at 25/12/10 with EDO timing (read data
     * valid 20 ns after RE falls), which the FMC setup here does not do:
     * read at the slower two-group timing, whose pulse covers the 20 ns. */
    { 1, 2, 0x3294d798, { 25, 12, 10 }, { 50, 24, 20 }, 0 },
    { 1, 4, 0x3294d798, { 25, 12, 10 }, { 50, 24, 20 }, NAND_LAYOUT_1WAY },
    { 2, 2, 0x3294d798, { 50, 24, 20 }, { 50, 24, 20 }, 0 },
    { 1, 4, 0x3295de98, { 25, 12, 10 }, { 50, 24, 20 }, NAND_LAYOUT_1WAY },
    { 1, 2, 0x3294e798, { 25, 12, 10 }, { 50, 24, 20 }, 0 },
    { 1, 4, 0x3294e798, { 25, 12, 10 }, { 50, 24, 20 }, NAND_LAYOUT_1WAY },
};

/* An absent chip enable reads all 0x00 or all 0xff */
static bool nand_ce_empty(uint32_t id)
{
    return id == 0 || id == 0xffffffff;
}

static const struct nand_part *nand_find_part(uint32_t id)
{
    unsigned int i;

    for (i = 0; i < (sizeof(nand_parts) / sizeof(nand_parts[0])); i++)
        if (nand_parts[i].id == id)
            return &nand_parts[i];
    return NULL;
}

/* Does what READ ID returned on CE0..7 match population p? Group g owns
 * CE 4g..4g+3: its first `chips` enables must report the part, the rest of
 * the group and every enable outside the groups must be empty. */
static bool nand_population_matches(const struct nand_population *p,
                                    const uint32_t *ids)
{
    unsigned int ce;

    for (ce = 0; ce < NAND_MAX_BANKS; ce++)
    {
        bool populated = ce / 4 < p->groups && ce % 4 < p->chips;

        if (populated ? ids[ce] != p->id : !nand_ce_empty(ids[ce]))
            return false;
    }
    return true;
}

#endif
