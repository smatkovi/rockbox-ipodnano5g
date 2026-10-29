.syntax unified
.cpu arm926ej-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    /* Build the LFN state with the original helper: first previous block,
       then current block; both records carry resolver mode 0 in r2. */
    ldr r4, =0x081f7f9d
    ldr r0, =lfn_state
    mov r1, #0x22
    mov r2, #0
    blx r4
    ldr r0, =lfn_state
    mov r1, #0x11
    mov r2, #0
    blx r4

    /* Assert that FUN_081f7f9c formed the expected state. */
    ldr r0, =lfn_state
    ldr r1, [r0]
    cmp r1, #2
    bne fail
    ldr r1, [r0, #4]
    cmp r1, #0
    bne fail
    ldr r1, [r0, #0xc]
    cmp r1, #0x11
    bne fail
    ldr r1, [r0, #0x10]
    cmp r1, #0x22
    bne fail

    /* Confirm the original short-name checksum routine returns 0x08. */
    ldr r0, =short_entry
    ldr r3, =0x081f8165
    blx r3
    cmp r0, #0x08
    bne fail

    ldr r0, =context
    ldr r1, =lfn_state
    ldr r2, =output
    ldr r3, =0x08159129
    blx r3

    ldr r0, =output
    ldr r1, =expected_name
    mov r2, #26
check_name:
    ldrb r3, [r0], #1
    ldrb r4, [r1], #1
    cmp r3, r4
    bne fail
    subs r2, r2, #1
    bne check_name
    ldrb r3, [r0]
    cmp r3, #0
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

.section .lfn,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x159128, 0x80

.section .copy,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x160828, 0x76

.section .state_helper,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1f7f9c, 0x1c

.section .checksum_helper,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1f8164, 0x1c

.section .utf_stub,"ax",%progbits
.thumb
.thumb_func
utf_stub:
    ldr r3, [r0]
    strb r1, [r3]
    adds r3, #1
    str r3, [r0]
    bx lr

.section .cache_get,"ax",%progbits
.thumb
.thumb_func
cache_get:
    cmp r1, #0x22
    beq previous_cache_result
    ldr r0, =current_cache
    bx lr
previous_cache_result:
    ldr r0, =previous_cache
    bx lr

.section .code_release_stub,"ax",%progbits
.thumb
.thumb_func
release_stub:
    bx lr

.section .data,"aw",%progbits
.align 4
current_cache:
    .space 0x18
    /* Current block index 0: first 13 UTF-16 characters, VFAT sequence 1. */
    .byte 0x01
    .short 0x0041,0x0042,0x0043,0x0044,0x0045
    .byte 0x0f,0x00,0x08
    .short 0x0046,0x0047,0x0048,0x0049,0x004a,0x004b
    .short 0x0000,0x004c,0x004d
    /* Following 8.3 entry; its LFN checksum is 0x08. */
short_entry:
    .ascii "ROCKBO~1BIN"
    .byte 0x20
    .space 20
    .space 0x1c0

previous_cache:
    /* Previous block index 15: final 13 characters, VFAT LAST|sequence 2. */
    .space 0x1f8
    .byte 0x42
    .short 0x004e,0x004f,0x0050,0x0051,0x0052
    .byte 0x0f,0x00,0x08
    .short 0x0053,0x0054,0x0055,0x0056,0x0057,0x0058
    .short 0x0000,0x0059,0x005a

context:
    .word 0
lfn_state:
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
output:
    .fill 32,1,0xaa
expected_name:
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
pass_message:
    .ascii "PASS\n"
fail_message:
    .ascii "FAIL\n"
