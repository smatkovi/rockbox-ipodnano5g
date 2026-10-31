.syntax unified
.cpu arm1176jzf-s
.arm

.section .text, "ax", %progbits
.global _start
.type _start, %function
_start:
    msr cpsr_c, #0xd3
    ldr sp, =0x09020000

    /* OSOS places its first-level table at 0x086dc000 in DRAM BSS. */
    ldr r0, =0x086dc000
    mov r1, #4096
    mov r2, #0
zero_l1:
    str r2, [r0], #4
    subs r1, r1, #1
    bne zero_l1

    /* Exact Thumb writer and TTBR literal from the OSOS DRAM suffix. */
    ldr r12, =0x080e3e85

    /* DRAM identity: 0x08000000..0x0bffffff -> same PA, attr 0x7c0e. */
    ldr r0, =0x08000000
    ldr r1, =0x0bffffff
    ldr r2, =0x08000000
    ldr r3, =0x00007c0e
    blx r12

    /* Alias: 0x88000000..0x8bffffff -> DRAM, attr 0x4c02. */
    ldr r0, =0x88000000
    ldr r1, =0x8bffffff
    ldr r2, =0x08000000
    ldr r3, =0x00004c02
    blx r12

    /* Low-vector alias and IRAM identity, also through the real writer. */
    ldr r0, =0x00000000
    ldr r1, =0x000fffff
    ldr r2, =0x22000000
    ldr r3, =0x0000c802
    blx r12
    ldr r0, =0x22000000
    ldr r1, =0x220fffff
    ldr r2, =0x22000000
    ldr r3, =0x00004c02
    blx r12

    /* Install the OSOS table and enable MMU with TRE/C/I clear. */
    mov r0, #0
    mcr p15, 0, r0, c2, c0, 2
    ldr r0, =0x086dc000
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

    /* Store actual descriptor outputs for GDB inspection. */
    ldr r0, =0x086dc200
    ldr r1, [r0]
    ldr r2, =identity_first_marker
    str r1, [r2]
    ldr r0, =0x086de200
    ldr r1, [r0]
    ldr r2, =alias_first_marker
    str r1, [r2]
    ldr r0, =0x086de2fc
    ldr r1, [r0]
    ldr r2, =alias_loader_marker
    str r1, [r2]
    ldr r0, =0x086dc000
    ldr r1, [r0]
    ldr r2, =low_vector_marker
    str r1, [r2]
    ldr r0, =0x086dc880
    ldr r1, [r0]
    ldr r2, =iram_marker
    str r1, [r2]

    /* Cleanup, bytewise read, DSB, bss_init, and loader branch. */
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
identity_first_marker: .word 0
alias_first_marker: .word 0
alias_loader_marker: .word 0
low_vector_marker: .word 0
iram_marker: .word 0
