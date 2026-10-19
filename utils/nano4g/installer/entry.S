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
.syntax unified
.cpu arm1176jz-s
.arm
.section .entry,"ax",%progbits
.global _start
_start:
    b relocate
    .rept 7
    b .
    .endr
relocate:
    /* The shared Rockbox SRAM startup initialized SDRAM and disabled caches. */
    adr r0, _start
    ldr r1, =_start
    ldr r2, =_image_end
1:  ldr r3, [r0], #4
    str r3, [r1], #4
    cmp r1, r2
    blo 1b
    ldr pc, =relocated
relocated:
    ldr sp, =_stack_top
    ldr r0, =_bss_start
    ldr r1, =_bss_end
    mov r2, #0
2:  cmp r0, r1
    strlo r2, [r0], #4
    blo 2b
    bl main
3:  b 3b
.section .note.GNU-stack,"",%progbits
