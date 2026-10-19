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

/* SRAM entry for DFU and NAND boot. */
.syntax unified
.cpu arm1176jz-s
.arm
.section .entry, "ax", %progbits
.global _start
_start:
    b stage_entry
    .ascii "RB4S"
stage_size:
    .word _image_end - _start
    .word 1                      /* format: stage + 16-byte payload descriptor */
    .space 16
stage_entry:
    msr cpsr_c, #0xd3
    mov r0, #0
    mcr p15, 0, r0, c7, c14, 0 /* save dirty data before disabling caches */
    mcr p15, 0, r0, c7, c10, 4
    mrc p15, 0, r1, c1, c0, 0
    bic r1, r1, #0x1000
    bic r1, r1, #5
    mcr p15, 0, r1, c1, c0, 0
    /* ARM1176 erratum 411920; IRQ/FIQ are masked at entry. */
    .rept 4
    mcr p15, 0, r0, c7, c5, 0
    .endr
    .rept 11
    nop
    .endr
    mcr p15, 0, r0, c7, c5, 4
    mcr p15, 0, r0, c8, c7, 0
    mcr p15, 0, r0, c13, c0, 0

    /* Relocate only this small stage into high SRAM. The complete input
     * file is capped below 0x2201e000, so the copy cannot damage payload.
     * Relative ADR/LDR work for both SRAM+0x50 and SRAM+0x650. */
    adr r0, _start
    ldr r2, stage_size
    add r6, r0, r2
    ldr r7, [r6]                /* payload byte count */
    add r6, r6, #16             /* payload runtime address */
    ldr r1, =_start
    add r2, r1, r2
1:
    ldr r3, [r0], #4
    str r3, [r1], #4
    cmp r1, r2
    blo 1b
    mov r0, #0
    mcr p15, 0, r0, c7, c10, 4
    mcr p15, 0, r0, c7, c5, 4
    ldr pc, =relocated
    .ltorg

.section .text.relocated, "ax", %progbits
relocated:
    ldr sp, =_stack_top
    ldr r0, =_bss_start
    ldr r1, =_bss_end
    mov r2, #0
2:
    cmp r0, r1
    strlo r2, [r0], #4
    blo 2b
    /* Reject malformed payload descriptors before touching hardware. */
    cmp r7, #64
    blo startup_failed
    tst r7, #31
    bne startup_failed
    add r0, r6, r7
    ldr r1, =0x22020000
    cmp r0, r1
    bhi startup_failed
    bl rockbox_early_init
    cmp r0, #0
    bne startup_failed
    /* Rockbox crt0 relocates itself from this SRAM address to SDRAM and
     * installs its own vectors, stacks and MMU. r6 is AAPCS callee-saved. */
    bx r6
.global startup_failed
startup_failed:
    /* IRQs remain masked. No reset is issued; failures do not write NAND. */
    b startup_failed
    .ltorg
.section .note.GNU-stack,"",%progbits
