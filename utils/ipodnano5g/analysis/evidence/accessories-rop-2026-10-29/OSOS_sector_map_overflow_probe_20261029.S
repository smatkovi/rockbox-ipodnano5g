.syntax unified
.cpu arm1176jzf-s

.macro CHECK_CLUSTER cluster, expected
    ldr r0, =\cluster
    ldr r1, =directory_entry
    mov r2, r0, lsr #16
    strh r2, [r1, #0x14]
    mov r2, r0, lsl #16
    mov r2, r2, lsr #16
    strh r2, [r1, #0x1a]
    ldr r0, =request_record
    ldr r3, =0x08158d01
    blx r3
    ldr r1, =\expected
    cmp r0, r1
    bne fail
.endm

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr sp, =stack_top

    /* Real directory-cluster decode and sector mapping via FUN_08158d00.
       The only replacement is FUN_08229880's mounted-volume predicate. */
    CHECK_CLUSTER 2, 0x7800
    CHECK_CLUSTER 179788, 0x2c5ca0
    CHECK_CLUSTER 1948737, 0x1dc3bf0
    CHECK_CLUSTER 1948738, 0
    CHECK_CLUSTER 1, 0

    /* FAT32-valid bit pattern, but far beyond this volume's max cluster.
       The 32-bit shift/add wraps and the range check accepts the low LBA. */
    CHECK_CLUSTER 0x0ffff883, 0x10

    ldr r1, =pass_message
    mov r0, #1
    mov r2, #5
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0
.size _start, .-_start

.section .fail,"ax",%progbits
.arm
fail:
    ldr r1, =fail_message
    mov r0, #1
    mov r2, #5
    mov r7, #4
    svc #0
    mov r0, #1
    mov r7, #1
    svc #0

.section .runtime_dir_entry_mapper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x158d00, 0x2a

.section .runtime_cluster_decode,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x229210, 0x12

.section .runtime_sector_map,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x22641e, 0x1e

.section .stub_volume_mounted,"ax",%progbits
.thumb
.thumb_func
stub_volume_mounted:
    movs r0, #1
    bx lr

.section .state,"aw",%progbits
.align 4
request_record:
    .word volume_context
    .word directory_entry
    .word 0, 0, 0, 0

volume_context:
    .space 0x6c
    .hword 8
    .space 0x06
    .word 0x7800
    .space 0x156
    .hword 4
    .space 0x08
    .word 0x1dc3c00

directory_entry:
    .space 0x20

pass_message:
    .ascii "PASS\n"
fail_message:
    .ascii "FAIL\n"

.section .stack,"aw",%nobits
.align 12
stack_base:
    .space 0x4000
stack_top:
