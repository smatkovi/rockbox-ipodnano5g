.syntax unified
.cpu arm1176jzf-s
.arm

.section .text, "ax", %progbits
.global _start
.type _start, %function
_start:
    msr cpsr_c, #0xd3
    ldr sp, =0x09020000

    /* Seed a non-mapped L1 slot inside DRAM BSS before OSOS clears that BSS. */
    ldr r0, =0x086dd400
    ldr r1, =0xdeadbeef
    str r1, [r0]

    /* Execute the exact OSOS startup BSS initializer, then its exact mapper. */
    ldr r0, =0x22005fec
    blx r0
    ldr r0, =0x22005d3c
    blx r0

    /* Reproduce the controlled file-read result and loader entry handoff. */
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
