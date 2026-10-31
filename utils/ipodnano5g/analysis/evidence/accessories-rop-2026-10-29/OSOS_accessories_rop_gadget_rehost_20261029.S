.syntax unified
.cpu arm926ej-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr r0, =stack_base
    mov sp, r0
    ldr r0, =0x08e58000
    mov r1, #0x100
    ldr r2, =stack_base + 4
    ldr r3, =stack_base
    ldr r4, =0x08039049
    blx r4
    cmp r0, #0
    bne fail
    ldr r1, =stack_base
    ldr r2, [r1]
    ldr r3, =0x284
    cmp r2, r3
    bne fail
    ldr r1, =stack_base + 0x13c
    ldr r2, [r1]
    ldr r3, =0x08007107
    cmp r2, r3
    bne fail
    ldr r1, =read_call_count
    ldr r2, [r1]
    cmp r2, #2
    bne fail
    ldr r1, =stack_base + 0x287
    ldrb r2, [r1]
    cmp r2, #8
    bne fail
    ldr r3, =0x0802c505
    bx r3
.size _start, .-_start

.section .binary_reader,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x39048, 0x30

.section .parser_epilogue,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2c504, 0x1c

.section .parser_epilogue_literal,"a",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2c528, 0x04

.section .initial_pop,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x7106, 0x02

.section .stack_pointer,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x396c, 0x08

.section .stack_return,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x190ab6, 0x02

.section .sub_e0,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x5cc2, 0x04

.section .sub_20,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x66b2, 0x06

.section .sub_18,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x9cf54, 0x06

.section .trampoline,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x30cbc, 0x04

.section .writer,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x5b090, 0x0c

.section .sub_8c,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x262d50, 0x06

.section .sub_28,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1df4be, 0x06

.section .sub_18_pc,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0xf8a32, 0x04

.section .copy_r0_to_r1,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18a910, 0x04

.macro FAIL_TO_ARM
    ldr r3, =fail
    bx r3
.endm

.section .string_dtor_stub,"ax",%progbits
.thumb
.thumb_func
string_dtor_stub:
    ldr r3, =stack_base + 0x110
    cmp r0, r3
    bne 4f
    ldr r3, [r0]
    ldr r2, =0x085354d8
    cmp r3, r2
    bne 4f
    ldr r3, [r0, #4]
    cmp r3, #0
    bne 4f
    ldr r2, =string_dtor_called
    movs r3, #1
    str r3, [r2]
    bx lr
4:
    FAIL_TO_ARM

.section .close_wrapper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2721d8, 0x18

.section .stream_close_sentinel,"a",%progbits
.word 0

.section .constructor_stub,"ax",%progbits
.thumb
.thumb_func
constructor_stub:
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne 1f
    ldr r3, =stack_base + 0xc0
    cmp r1, r3
    bne 1f
    ldr r2, [r1]
    ldr r3, =0x4f4f422f
    cmp r2, r3
    bne 1f
    ldrh r2, [r1, #4]
    ldr r3, =0x2e54
    cmp r2, r3
    bne 1f
    ldrh r2, [r1, #6]
    ldr r3, =0x4942
    cmp r2, r3
    bne 1f
    ldrb r2, [r1, #8]
    cmp r2, #'N'
    bne 1f
    ldrb r2, [r1, #9]
    cmp r2, #0
    bne 1f
    ldr r2, =constructor_called
    movs r3, #1
    str r3, [r2]
    bx lr
1:
    FAIL_TO_ARM

.section .open_stub,"ax",%progbits
.thumb
.thumb_func
open_stub:
    cmp r0, r1
    bne 2f
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne 2f
    cmp r2, #0
    bne 2f
    ldr r2, =open_called
    movs r3, #1
    str r3, [r2]
    bx lr
2:
    FAIL_TO_ARM

.section .read_entry,"ax",%progbits
.thumb
b.n read_impl

.section .read_impl,"ax",%progbits
.thumb
.thumb_func
read_impl:
    push {r4, r5, lr}
    ldr r3, =read_call_count
    ldr r4, [r3]
    cmp r4, #0
    beq 5f
    cmp r4, #1
    beq 6f
    cmp r4, #2
    beq 7f
    b 8f
5:
    ldr r3, =0x08e58000
    cmp r0, r3
    bne 8f
    cmp r1, #4
    bne 8f
    ldr r3, =stack_base
    cmp r2, r3
    bne 8f
    ldr r3, =0x284
    str r3, [r2]
    movs r0, #0
    ldr r3, =read_call_count
    movs r4, #1
    str r4, [r3]
    pop {r4, r5, pc}
6:
    ldr r3, =0x08e58000
    cmp r0, r3
    bne 8f
    ldr r3, =0x284
    cmp r1, r3
    bne 8f
    ldr r3, =stack_base + 4
    cmp r2, r3
    bne 8f
    ldr r3, =input_field
    movs r4, r2
    ldr r5, =0x284
9:
    ldrb r0, [r3]
    strb r0, [r4]
    adds r3, #1
    adds r4, #1
    subs r5, #1
    bne 9b
    movs r0, #0
    ldr r3, =read_call_count
    movs r4, #2
    str r4, [r3]
    pop {r4, r5, pc}
7:
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne 8f
    ldr r3, =0x10f80
    cmp r1, r3
    bne 8f
    ldr r3, =0x09000000
    cmp r2, r3
    bne 8f
    ldr r2, =read_called
    movs r3, #1
    str r3, [r2]
    movs r0, #0
    ldr r3, =read_call_count
    movs r4, #3
    str r4, [r3]
    pop {r4, r5, pc}
8:
    FAIL_TO_ARM

.section .read_finish_stub,"ax",%progbits
.thumb
.thumb_func
read_finish_stub:
    movs r0, #0
    bx lr

.section .loader_entry,"ax",%progbits
.arm
loader_stub:
    b loader_impl

.section .cleanup_probe,"aw",%progbits
.byte 0x7f

.section .loader_impl,"ax",%progbits
.arm
loader_impl:
    ldr r0, =0x09000040
    ldrb r1, [r0]
    cmp r1, #0
    bne fail
    ldr r0, =string_dtor_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =constructor_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =open_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =read_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r1, =pass_message
    mov r0, #1
    mov r2, #5
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0

.section .start,"ax",%progbits
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

.section .input_field,"a",%progbits
.global input_field
input_field:
.incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/candidate_accessories_reg_unexecuted.bin", 0x20, 0x284

.section .state,"aw",%progbits
.align 2
string_dtor_called: .word 0
constructor_called: .word 0
open_called: .word 0
read_called: .word 0
read_call_count: .word 0
pass_message: .ascii "PASS\n"
fail_message: .ascii "FAIL\n"
