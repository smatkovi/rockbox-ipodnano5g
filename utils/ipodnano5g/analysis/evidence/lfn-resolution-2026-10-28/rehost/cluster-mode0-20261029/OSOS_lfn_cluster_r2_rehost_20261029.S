.syntax unified
.cpu arm926ej-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr r4, =fs_context
    ldr r3, =0x081608f9

    /* Cluster 3, sector 2 -> sector 3: q=1, expected r2=0. */
    mov r0, r4
    ldr r1, =0x00100006
    mov r2, #0x55
    blx r3
    ldr r5, =0x00100007
    cmp r0, r5
    bne fail
    cmp r2, #0
    bne fail

    /* Cluster 4, sector 0 -> sector 1: q=2, expected r2=1. */
    mov r0, r4
    ldr r1, =0x00100008
    mov r2, #0x55
    ldr r3, =0x081608f9
    blx r3
    ldr r5, =0x00100009
    cmp r0, r5
    bne fail
    cmp r2, #1
    bne fail

    ldr r1, =pass_message
    mov r0, #1
    mov r2, #5
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0

fail:
    ldr r1, =fail_message
    mov r0, #1
    mov r2, #5
    mov r7, #4
    svc #0
    mov r0, #1
    mov r7, #1
    svc #0
.size _start, .-_start

.section .advance,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1608f8, 0x58

.section .cluster_test,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x16a970, 0x16

.section .divider_entry,"ax",%progbits
.arm
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18e65c, 0x1c

.section .divider_tail,"ax",%progbits
.arm
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18f720, 0x34

.section .data,"aw",%progbits
.align 4
fs_context:
    .space 0x70
    .word 0x00000000       /* +0x70 */
    .word 0x00100000       /* +0x74: synthetic data-area LBA */
    .space 0x154
    .hword 4               /* +0x1cc: sectors per cluster */
    .hword 2               /* +0x1ce: cluster shift */
    .space 8
    .word 0x00200000       /* +0x1d8: end of valid LBA range */

pass_message:
    .ascii "PASS\n"
fail_message:
    .ascii "FAIL\n"
