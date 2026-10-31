.syntax unified
.cpu arm1176jzf-s
.arm

.section .text, "ax", %progbits
.global _start
.type _start, %function
_start:
    msr cpsr_c, #0xd3
    ldr sp, =0x08003000

    /* Build the 16-KiB ARMv6 short-descriptor L1 table at 0x08004000. */
    ldr r0, =0x08004000
    mov r1, #4096
    mov r2, #0
zero_table:
    str r2, [r0], #4
    subs r1, r1, #1
    bne zero_table

    ldr r7, =0x08004000
    ldr r9, =0x00100000

    /* OSOS body mapping: DRAM identity, 64 MiB, TEX/C/B=0x7c0e. */
    ldr r4, =0x08000000
    ldr r5, =0x08000000
    mov r6, #64
    ldr r8, =0x00007c0e
map_dram_identity:
    mov r0, r4, lsr #20
    add r0, r7, r0, lsl #2
    orr r1, r5, r8
    str r1, [r0]
    add r4, r4, r9
    add r5, r5, r9
    subs r6, r6, #1
    bne map_dram_identity

    /* OSOS body mapping: same DRAM at 0x88000000, attr=0x4c02. */
    ldr r4, =0x88000000
    ldr r5, =0x08000000
    mov r6, #64
    ldr r8, =0x00004c02
map_dram_alias:
    mov r0, r4, lsr #20
    add r0, r7, r0, lsl #2
    orr r1, r5, r8
    str r1, [r0]
    add r4, r4, r9
    add r5, r5, r9
    subs r6, r6, #1
    bne map_dram_alias

    /* The low vector section aliases physical 0x22000000 as in the body. */
    ldr r0, =0x22000000
    ldr r1, =0x0000c802
    orr r0, r0, r1
    str r0, [r7]

    /* Map 0x22000000..0x220fffff identity as the body does. */
    ldr r0, =0x22000000
    ldr r1, =0x00004c02
    orr r0, r0, r1
    str r0, [r7, #0x880]

    /* Install TTBR0 and domain 0 client access. Force TRE/C/I off, then
       enable XP and the MMU to test the 0x4c02 alias under TRE=0. */
    mov r0, #0
    mcr p15, 0, r0, c2, c0, 2
    ldr r0, =0x08004000
    mcr p15, 0, r0, c2, c0, 0
    mov r0, #1
    mcr p15, 0, r0, c3, c0, 0
    mov r0, #0
    mcr p15, 0, r0, c8, c7, 0
    mcr p15, 0, r0, c7, c10, 4
    mrc p15, 0, r1, c1, c0, 0
    ldr r2, =0x10001004
    bic r1, r1, r2
    ldr r2, =0x00800001
    orr r1, r1, r2
    mcr p15, 0, r1, c1, c0, 0
    mcr p15, 0, r0, c7, c5, 4

    /* The parser cleanup byte precedes the full file read. */
    ldr r1, =0x8bf00040
    mov r2, #0
    strb r2, [r1]

    /* Model the file read as bytewise STRB stores through the alias. */
    ldr r0, =0x0a000000
    ldr r1, =0x8bf00000
    ldr r2, =0x00010f80
copy_loader:
    ldrb r3, [r0], #1
    strb r3, [r1], #1
    subs r2, r2, #1
    bne copy_loader

    /* Model DSB + bss_init + final branch from the candidate. */
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
