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

#ifndef __APPLEFW_H__
#define __APPLEFW_H__

#include <stdint.h>

/* Load a standalone image out of Apple's firmware partition on the NAND
 * (disk mode, the iPod OS) so the Rockbox bootloader can hand control to it,
 * e.g. to reach disk mode when there is no rockbox.ipod. See applefw.c for
 * the on-flash format. Only complete ARM images can be started this way:
 * the diagnostics image is a set of EFI drivers that need Apple's boot
 * loader environment and is not supported. */

/* Four-character image names, as the directory stores them */
#define APPLE_IMG_DISK  "disk"      /* USB disk mode */
#define APPLE_IMG_OSOS  "osos"      /* the iPod OS */

/* What applefw_load() found, for the on-screen report */
struct applefw_info
{
    char     name[5];       /* the image it loaded, NUL-terminated */
    uint32_t fourcc;        /* id as read (little endian) */
    uint8_t  format;        /* IMG1 format byte: 3 encrypted, 4 plain */
    uint32_t body_len;
    uint32_t entry;         /* IMG1 entry field (added to the load base) */
    void    *entry_addr;    /* where to jump: load base + entry */
};

/* Results */
#define APPLEFW_OK              0
#define APPLEFW_ERR_STORAGE     (-1)   /* a sector read failed */
#define APPLEFW_ERR_NO_PART     (-2)   /* no Apple firmware partition */
#define APPLEFW_ERR_NO_DIR      (-3)   /* partition has no STOP/directory */
#define APPLEFW_ERR_NOT_FOUND   (-4)   /* no directory entry of that name */
#define APPLEFW_ERR_BAD_IMG1    (-5)   /* magic/format/length wrong */
#define APPLEFW_ERR_TOO_BIG     (-6)   /* image would overlap the bootloader */
#define APPLEFW_ERR_DECRYPT     (-7)   /* body does not start with ARM code after decryption */

/* Find the named image, read it to the load base, and (format 3) decrypt its
 * body in place with the hardware GID key. On APPLEFW_OK, *info describes it
 * and info->entry_addr is ready to jump to. Storage must be initialised. */
int applefw_load(const char *name, struct applefw_info *info);

#endif /* __APPLEFW_H__ */
