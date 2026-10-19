;             __________               __   ___.
;   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
;   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
;   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
;   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
;                     \/            \/     \/    \/            \/
;
; Copyright (C) 2026 Viktor Krapivin
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version 2
; of the License, or (at your option) any later version.
;
; This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
; KIND, either express or implied.
;
;
; Erase one physical block. P_ROWS is its first row, P_CEMASKS one CE bit.
; r6: NAND FAIL in bit 0, controller fault in bit 27.
    wr   [CS_IRQ], #0xff
    wr   [FMSS_C10], #1
    wr   [FMSS_C58], #4
    wr   [FMSS_C4C], #fault
    wr   [FMCTRL1], #0x33338e0
    wr   [FMC_STATUS], #0xff00ffe
    ld   r0, [P_CEMASKS]
    shl  r0, r0, #1
    or   r0, r0, #0x77801
    st   [FMC_CTRL0], r0
    movi r6, #0
    wr   [FMC_CMD], #0x60
    wait 0
    wr   [FMC_STATUS], #2
    ld   r0, [P_ROWS]
    st   [FMC_ADDR0], r0
    wr   [FMC_ANUM], #2
    wr   [FMCTRL1], #1
    wait 1
    wr   [FMC_STATUS], #4
    wr   [FMC_CMD], #0xd0
    wait 0
    wr   [FMC_STATUS], #2
    wr   [FMC_DATA_SEL], #1
    wr   [FMC_CMD], #0x70
    wait 0
    wr   [FMC_STATUS], #2
    wr   [FMCTRL1], #0xca
    wait 12, arg=0x40, mask=0x40
    wr   [FMC_STATUS], #0x800000
    ld   r6, [0x04c], 1
    wr   [FMCTRL1], #0x20
    wr   [FMC_CTRL0], #0
    end
fault:
    wr   [FMSS_C50], #1
    wr   [FMC_CTRL0], #0
    movi r6, #0x8000000
    end
