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
#ifndef __LCD_TARGET_H__
#define __LCD_TARGET_H__

#define S5L_LCD_WITH_READID

/* The main firmware starts straight after Apple's WTF stage, with no Rockbox
 * bootloader in front of it, so it sends the panel init sequence itself */
#define S5L_LCD_RUN_INIT_SEQ

/* Bring-up: frame updates by programmed I/O until the LCD DMA request line
 * of the S5L8730 is confirmed */
#define S5L_LCD_PIO

#endif /* __LCD_TARGET_H__ */
