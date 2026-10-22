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
#ifndef __DEVLOOP_NANO5G_H__
#define __DEVLOOP_NANO5G_H__

/* Bring-up loop for working on the nano 5G over USB alone: the U-Boot shell
 * that loaded Rockbox leaves a copy of itself at DEVLOOP_UBOOT_ADDR, and
 * Rockbox goes back to it, with a report in the mailbox at
 * DEVLOOP_MAILBOX_ADDR, when it reboots, panics, or has USB power without
 * USB storage working after DEVLOOP_USB_TIMEOUT seconds. */

#define DEVLOOP_UBOOT_ADDR      0x0ae00000
#define DEVLOOP_MAILBOX_ADDR    0x0af00000
#define DEVLOOP_MAILBOX_MAGIC   0x4e35474d      /* "MG5N" */
#define DEVLOOP_USB_TIMEOUT     40
/* images to restart from (devloop-nano5g.c), above Rockbox's 32 MiB */
/* (below U-Boot's heap, which it clears: about 0x0afa5000..0x0bfa7000) */
#define DEVLOOP_GOOD_ADDR       0x0a800000
#define DEVLOOP_NEW_ADDR        0x0aa00000
#define DEVLOOP_SLOT_SIZE       0x00200000
#define DEVLOOP_TRAMP_ADDR      0x0ac00000
#define DEVLOOP_UBOOT_SAVE_ADDR 0x0ac10000

enum devloop_reason {
    DEVLOOP_REBOOT = 1,
    DEVLOOP_EXCEPTION,
    DEVLOOP_USB_STORAGE_SILENT,
    DEVLOOP_HOST_EJECT,
    DEVLOOP_HANG_DUMP,              /* MENU+PLAY held in a hang */
};

void devloop_init(void);
/* usb_storage counts the CBWs it receives here */
extern volatile unsigned int devloop_usb_cbw_count;
/* set by usb_storage when the host ejects a drive: back to the shell */
extern volatile bool devloop_usb_ejected;
/* restart the GOOD image with a report, or else back to the U-Boot shell
 * if its copy is there; returns otherwise */
void devloop_return_to_uboot(int reason);
/* init(): the disk is mounted */
void devloop_boot(void);

#endif /* __DEVLOOP_NANO5G_H__ */
