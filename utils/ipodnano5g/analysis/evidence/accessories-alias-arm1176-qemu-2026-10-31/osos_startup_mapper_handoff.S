.syntax unified
.cpu arm1176jzf-s
.arm

.section .text, "ax", %progbits
.global _start
.type _start, %function
_start:
    msr cpsr_c, #0xd3
    ldr sp, =0x09020000

    /* OSOS's first-level table is in zero-initialized DRAM BSS. */
    ldr r0, =0x086dc000
    mov r1, #4096
    mov r2, #0
zero_l1:
    str r2, [r0], #4
    subs r1, r1, #1
    bne zero_l1

    /* Run the exact relocated SRAM startup mapper at its runtime VA. */
    ldr r0, =0x22005d3c
    blx r0

    /* Capture the control registers after the OSOS function returns. */
    mrc p15, 0, r1, c1, c0, 0
    ldr r2, =captured_sctlr
    str r1, [r2]
    mrc p15, 0, r1, c1, c0, 1
    ldr r2, =captured_actlr
    str r1, [r2]
    mrc p15, 0, r1, c2, c0, 0
    ldr r2, =captured_ttbr0
    str r1, [r2]
    mrc p15, 0, r1, c2, c0, 2
    ldr r2, =captured_ttbcr
    str r1, [r2]
    mrc p15, 0, r1, c3, c0, 0
    ldr r2, =captured_dacr
    str r1, [r2]
    mrc p15, 0, r1, c13, c0, 0
    ldr r2, =captured_fcse
    str r1, [r2]

    /* Reproduce cleanup, bytewise file-read result, DSB, and loader entry. */
    ldr r1, =0x8bf00040
    mov r2, #0
    strb r2, [r1]
    ldr r0, =0x0a000000
    ldr r1, =0x8bf00000
    ldr r2, =0x00010f80
copy_loader:
    ldrb r3, [r0], #1
    strb r3, [r1], #1
    subs r2, r2, #1
    bne copy_loader
    mov r0, #0
    mcr p15, 0, r0, c7, c10, 4
    ldr r0, =0x8bf001c8
    blx r0
    ldr r0, =0x8bf00000
    bx r0

.Lhalt:
    b .Lhalt
.size _start, .-_start
.ltorg

.section .data, "aw", %progbits
.align 2
captured_sctlr: .word 0
captured_actlr: .word 0
captured_ttbr0: .word 0
captured_ttbcr: .word 0
captured_dacr: .word 0
captured_fcse: .word 0
