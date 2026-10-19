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
; Reset CE0..CE7. The caller waits 10 ms for tRST.
; r6 returns 0, or 0x08000000 | selected CE mask on fault.
;
    wr   [CS_IRQ], #0xff            ; clear sequencer interrupts
    wr   [FMSS_C10], #0x1           ; sequencer enable (inferred)
    wr   [FMSS_C58], #0x4           ; event timeout scale (inf)
    wr   [FMSS_C4C], #fault         ; fault vector
    wr   [FMCTRL1], #0x33338e0      ; transfer engine idle setup
    wr   [FMC_STATUS], #0xff00ffe   ; clear FMC status
; Use maximum pulse/hold timing; bit 9 is set, function unknown.
    wr   [FMC_CTRL0], #0x77201      ; slow timing, no chip selected
    wr   [FMC_CTRL0], #0x773ff      ; ... and CE0..CE7 selected (bits 1..8)
; ---- the NAND command cycle: FMC_CMD puts one byte on the bus with CLE high
    wr   [FMC_CMD], #0xff           ; RESET
    wait 0                          ; command sent (event 0 = FMC_STATUS bit 1)
    wr   [FMC_STATUS], #0x2         ; acknowledge (FMC_STATUS is write-1-to-clear)
    ld   r1, [FMC_CTRL0], 0xfffffe01 ; keep timing + bit 0, CE bits 8..1 cleared
    st   [FMC_CTRL0], r1            ; deselect all chips
    movi r6, #0x0                   ; result: 0 = ok
    end                             ; raises CS_IRQ bit 0 (done) for the CPU
; ---- fault handler: entered through FMSS_C4C when a WAIT times out
fault:
    ld   r0, [FMC_CTRL0], 0x1fe     ; selected chip enables
    shr  r0, r0, #0x1               ; -> bit n = CE n
    or   r6, r0, #0x8000000         ; result: fault flag | CE mask
    ld   r1, [FMC_CTRL0], 0xfffffe01
    st   [FMC_CTRL0], r1            ; deselect
    ld   r2, [FMSS_C3C], 0xffffffff ; fault info
    ld   r0, [FMSS_C50], 0x1        ; fault acknowledge flag
    wr   [FMSS_C50], #0x1           ; acknowledge the fault
    end                             ; the CPU sees CS_IRQ fault (bit 2) + done
