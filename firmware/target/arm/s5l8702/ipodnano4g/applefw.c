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

/* Load an IMG1 from the firmware partition into SDRAM at 0x08000000.
 * Format 3 bodies use GID AES-128-CBC with a zero IV; format 4 is plaintext.
 * The bootloader occupies 0x09000000, limiting images to the space below it.
 *
 * The partition starts with the iPod STOP-sign text. Its u32 at +0x104
 * locates the directory relative to partition offset 4096. Directory entries
 * are 0x28 bytes: type +0x00, name +0x04, data offset +0x0c, length +0x10.
 * Data offsets are also relative to 4096; names use big-endian character order.
 * IMG1 has a 0x600-byte header: format +0x07, entry +0x08, body length +0x0c,
 * total data length +0x10. */

#include "config.h"
#include "system.h"
#include "applefw.h"
#include "nand-target.h"
#include "crypto-s5l8702.h"
#include <cpucache-arm.h>
#include <string.h>
#include <stdbool.h>

#define SECTOR          4096u           /* one FTL page = one sector */
#define LOAD_BASE       DRAM_ORIG       /* 0x08000000, the body's link address */
#define LOAD_LIMIT      (DRAM_ORIG + 16 * 1024 * 1024)  /* bootloader link area */
#define IMG1_HDR        0x600u
#define MBR_PART0       0x1be           /* first of 4 16-byte MBR entries */

/* a scratch page for the MBR and the directory (not the image itself) */
static uint8_t applefw_page[SECTOR] __attribute__((aligned(32)));

static uint32_t rd32(const uint8_t *p)
{
    return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int read_sector(uint32_t lpn, void *buf)
{
    return nand_read_flash_sectors(lpn, 1, buf) == 0
        ? APPLEFW_OK : APPLEFW_ERR_STORAGE;
}

/* The iPod "STOP sign" text that opens the firmware partition's first block */
static const char stop_sign[] = "{{~~  /-----\\";

/* The firmware partition: the restore tool writes its MBR entry with type
 * 0x3f (some older layouts use type 0); the FAT data partition has a real
 * type such as 0x0c. The type is only a hint: the entry is accepted when its
 * first block carries the STOP sign, so a layout with an unexpected type
 * byte still works as long as the content is right. */
static int find_partition(uint32_t *start)
{
    uint32_t lba[4];
    uint8_t type[4];
    int rc = read_sector(0, applefw_page);
    if (rc)
        return rc;
    if (applefw_page[0x1fe] != 0x55 || applefw_page[0x1ff] != 0xaa)
        return APPLEFW_ERR_NO_PART;
    for (unsigned int i = 0; i < 4; i++)
    {
        const uint8_t *e = applefw_page + MBR_PART0 + i * 16;
        lba[i] = rd32(e + 8);
        type[i] = e[4];
    }
    for (int pass = 0; pass < 2; pass++)
        for (unsigned int i = 0; i < 4; i++)
        {
            bool expected = type[i] == 0x3f || type[i] == 0;
            if (!lba[i] || (pass == 0) != expected)
                continue;
            if (read_sector(lba[i], applefw_page) == APPLEFW_OK &&
                memcmp(applefw_page, stop_sign, sizeof(stop_sign) - 1) == 0)
            {
                *start = lba[i];
                return APPLEFW_OK;
            }
        }
    return APPLEFW_ERR_NO_PART;
}

/* Read a directory entry's fields by its four-character name */
static int find_entry(uint32_t part, const char *name,
                      uint32_t *dev_offset, uint32_t *length)
{
    uint32_t dir_off, fourcc, lpn, i;
    int rc = read_sector(part, applefw_page);
    if (rc)
        return rc;
    dir_off = rd32(applefw_page + 0x104);
    if (dir_off == 0 || (dir_off & (SECTOR - 1)))
        return APPLEFW_ERR_NO_DIR;      /* directory must start on a page */
    /* the id word spells the name in big-endian order ("disk" = 0x6469736b) */
    fourcc = ((uint32_t)(uint8_t)name[0] << 24) | ((uint32_t)(uint8_t)name[1] << 16)
           | ((uint32_t)(uint8_t)name[2] << 8) | (uint8_t)name[3];
    lpn = part + dir_off / SECTOR + 1;  /* directory is at dirOffset + 4096 */
    rc = read_sector(lpn, applefw_page);
    if (rc)
        return rc;
    for (i = 0; i < SECTOR / 0x28; i++)
    {
        const uint8_t *d = applefw_page + i * 0x28;
        if (rd32(d) == 0)               /* 'NAND' type; 0 ends the directory */
            break;
        if (rd32(d + 4) == fourcc)
        {
            *dev_offset = rd32(d + 0xc);
            *length = rd32(d + 0x10);
            return APPLEFW_OK;
        }
    }
    return APPLEFW_ERR_NOT_FOUND;
}

int applefw_load(const char *name, struct applefw_info *info)
{
    uint32_t part, dev_offset, dir_length, img_lpn, total, pages, blen16;
    uint8_t *base = (uint8_t *)LOAD_BASE;
    int rc;

    memset(info, 0, sizeof(*info));
    memcpy(info->name, name, 4);

    rc = find_partition(&part);
    if (rc)
        return rc;
    rc = find_entry(part, name, &dev_offset, &dir_length);
    if (rc)
        return rc;
    if (dev_offset & (SECTOR - 1))
        return APPLEFW_ERR_BAD_IMG1;    /* file data must start on a page */

    /* file data is at partition byte offset devOffset + 4096 */
    img_lpn = part + dev_offset / SECTOR + 1;

    /* the IMG1 header tells us how much to read */
    rc = read_sector(img_lpn, base);
    if (rc)
        return rc;
    if (memcmp(base, "8720", 4) != 0)
        return APPLEFW_ERR_BAD_IMG1;
    info->format = base[7];
    info->entry = rd32(base + 8);
    info->body_len = rd32(base + 0xc);
    info->fourcc = rd32(base + 4);
    if (info->format != 3 && info->format != 4)
        return APPLEFW_ERR_BAD_IMG1;

    uint32_t data_length = rd32(base + 0x10);
    if (data_length > LOAD_LIMIT - LOAD_BASE - IMG1_HDR ||
        info->body_len < 4 || info->body_len > data_length ||
        info->entry >= info->body_len)
        return APPLEFW_ERR_TOO_BIG;
    total = IMG1_HDR + data_length;
    if (total > dir_length && total - dir_length > SECTOR)
        return APPLEFW_ERR_TOO_BIG;
    blen16 = (info->body_len + 15u) & ~15u;
    if (blen16 > data_length)
        return APPLEFW_ERR_BAD_IMG1;

    /* read the rest of the image after the first page already read */
    pages = (total + SECTOR - 1) / SECTOR;
    if (pages > 1)
    {
        rc = nand_read_flash_sectors(img_lpn + 1, pages - 1,
                                     base + SECTOR) == 0
            ? APPLEFW_OK : APPLEFW_ERR_STORAGE;
        if (rc)
            return rc;
    }

    /* format 3: AES-decrypt the body in place with the hardware GID key
     * (zero IV, CBC) over the body rounded up to a 16-byte multiple */
    if (info->format == 3)
    {
        blen16 = (info->body_len + 15u) & ~15u;
        hwkeyaes(HWKEYAES_DECRYPT, HWKEYAES_GKEY, base + IMG1_HDR, blen16);
        commit_discard_dcache();        /* the engine wrote by DMA */
    }

    /* Wrong decryption keys yield random bytes instead of an ARM branch. */
    uint32_t branch = rd32(base + IMG1_HDR) >> 24;
    if (branch != 0xea && branch != 0xeb)
        return APPLEFW_ERR_DECRYPT;

    /* the body runs at the load base, so move it down over the header */
    memmove(base, base + IMG1_HDR, info->body_len);
    info->entry_addr = base + info->entry;
    return APPLEFW_OK;
}
