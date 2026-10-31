.syntax unified
.cpu arm926ej-s

.macro FAIL_TO_ARM
    ldr r3, =fail
    bx r3
.endm

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr r0, =stack_base + 0x140
    mov sp, r0
    ldr r0, =0x08e58000
    ldr r1, =0x0802c3c5
    blx r1
    b fail
.size _start, .-_start

.section .binary_reader,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x39048, 0x30

.section .parser_function,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2c3c4, 0x15c

.section .parser_literals,"a",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2c520, 0x0c

.section .parser_initializer_a,"ax",%progbits
.thumb
.thumb_func
parser_initializer_a:
    ldr r3, =0x08e58000
    cmp r0, r3
    bne .Lbad_init_a
    ldr r3, =parser_init_a_called
    movs r2, #1
    str r2, [r3]
    bx lr
.Lbad_init_a:
    FAIL_TO_ARM

.section .parser_initializer_b,"ax",%progbits
.thumb
.thumb_func
parser_initializer_b:
    ldr r3, =0x08e58000
    cmp r0, r3
    bne .Lbad_init_b
    ldr r3, =parser_init_b_called
    movs r2, #1
    str r2, [r3]
    bx lr
.Lbad_init_b:
    FAIL_TO_ARM

.section .parser_path_create,"ax",%progbits
.thumb
.thumb_func
parser_path_create:
    ldr r3, =stack_base + 0x11c
    cmp r0, r3
    bne .Lbad_path_create
    ldr r3, =0x08e58080
    cmp r1, r3
    bne .Lbad_path_create
    ldr r3, =path_create_called
    movs r2, #1
    str r2, [r3]
    ldr r0, =stack_base + 0x11c
    bx lr
.Lbad_path_create:
    FAIL_TO_ARM

.section .parser_temp_destructor,"ax",%progbits
.thumb
.thumb_func
parser_temp_destructor:
    ldr r3, =stack_base + 0x11c
    cmp r0, r3
    bne .Lbad_temp_destructor
    ldr r3, =temp_destructor_called
    movs r2, #1
    str r2, [r3]
    bx lr
.Lbad_temp_destructor:
    FAIL_TO_ARM

.section .string_valid_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1965fe, 0x14

.section .string_assign_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1936ec, 0x3a

.section .string_vtable,"a",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x5354d8, 0x10

.section .container_check_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x26abb0, 0x0e

.section .integer_reader_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x26ab24, 0x0c

.section .read_word_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x23f4f4, 0x30

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
    ldr r3, [r2]
    adds r3, #1
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
    ldr r3, =stack_base + 0x110
    cmp r0, r3
    beq .Lparser_string_init
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
.Lparser_string_init:
    ldr r3, =0x0802c520
    cmp r1, r3
    bne 1f
    ldr r2, =0x085354d8
    str r2, [r0]
    movs r2, #0
    str r2, [r0, #4]
    ldr r2, =parser_string_init_called
    movs r3, #1
    str r3, [r2]
    bx lr
1:
    FAIL_TO_ARM

.section .open_stub,"ax",%progbits
.thumb
.thumb_func
open_stub:
    ldr r3, =0x08e58034
    cmp r0, r3
    bne 3f
    ldr r3, =stack_base + 0x11c
    cmp r1, r3
    bne 2f
    cmp r2, #0
    bne 2f
    ldr r2, =parser_open_called
    movs r3, #1
    str r3, [r2]
    movs r0, #0
    bx lr
3:
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
    ldr r3, =0x08e58034
    cmp r0, r3
    bne .Lread_loader
    ldr r3, =wire_offset
    ldr r4, [r3]
    ldr r5, =input_wire
    adds r5, r5, r4
    /* Record the parser's read of the 0x44 length word in the wire candidate. */
    cmp r4, #0x1c
    bne .Lread_have_offset
    cmp r1, #4
    bne .Lread_have_offset
    ldr r3, =wrap_length_seen
    movs r0, #1
    str r0, [r3]
    ldr r3, =wire_offset
.Lread_have_offset:
    ldr r0, =0x2c0
    subs r0, r0, r4
    cmp r1, r0
    bhi .Lread_partial
    adds r4, r4, r1
    str r4, [r3]
    movs r4, r1
.Lcopy_wire_bytes:
    cmp r4, #0
    beq .Lread_parser_done
    ldrb r0, [r5]
    strb r0, [r2]
    adds r5, #1
    adds r2, #1
    subs r4, #1
    bne .Lcopy_wire_bytes
.Lread_parser_done:
    ldr r3, =read_call_count
    ldr r4, [r3]
    adds r4, #1
    str r4, [r3]
    movs r0, #0
    pop {r4, r5, pc}
.Lread_partial:
    /* Copy the buffered file tail, then model the FAT reader's cluster slack. */
    adds r4, r4, r0
    str r4, [r3]
    movs r4, r0
.Lcopy_partial_bytes:
    cmp r4, #0
    beq .Lpartial_done
    ldrb r0, [r5]
    strb r0, [r2]
    adds r5, #1
    adds r2, #1
    subs r4, #1
    bne .Lcopy_partial_bytes
.Lpartial_done:
    ldr r3, =partial_copy_bytes
    ldr r4, =0x2a0
    str r4, [r3]
    ldr r3, =cluster_slack_bytes
    ldr r4, =7488
    str r4, [r3]
    ldr r4, =7488
    movs r0, #0x41
.Lcopy_cluster_slack:
    strb r0, [r2]
    adds r2, #1
    subs r4, #1
    bne .Lcopy_cluster_slack
    ldr r3, =read_error_seen
    movs r4, #1
    str r4, [r3]
    ldr r3, =read_call_count
    ldr r4, [r3]
    adds r4, #1
    str r4, [r3]
    movs r0, #0x22
    pop {r4, r5, pc}
.Lread_loader:
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne .Lread_reject
    ldr r3, =0x10f80
    cmp r1, r3
    bne .Lread_reject
    ldr r3, =0x09000000
    cmp r2, r3
    bne .Lread_reject
    ldr r2, =read_called
    movs r3, #1
    str r3, [r2]
    movs r0, #0
    pop {r4, r5, pc}
.Lread_reject:
    FAIL_TO_ARM

.section .token_reader_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x26dd26, 0x0c

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
    cmp r1, #3
    bne fail
    ldr r0, =parser_init_a_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =parser_init_b_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =parser_string_init_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =path_create_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =temp_destructor_called
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =wire_offset
    ldr r1, [r0]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail
    ldr r0, =wrap_length_seen
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =read_error_seen
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =partial_copy_bytes
    ldr r1, [r0]
    ldr r2, =0x2a0
    cmp r1, r2
    bne fail
    ldr r0, =cluster_slack_bytes
    ldr r1, [r0]
    ldr r2, =7488
    cmp r1, r2
    bne fail
    ldr r0, =parser_open_called
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
    ldr r0, =read_call_count
    ldr r1, [r0]
    cmp r1, #0
    beq fail
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

.section .input_wire,"a",%progbits
.global input_wire
input_wire:
.incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/candidate_accessories_reg_wrap_unexecuted.bin"

.section .state,"aw",%progbits
.align 2
string_dtor_called: .word 0
constructor_called: .word 0
parser_init_a_called: .word 0
parser_init_b_called: .word 0
parser_string_init_called: .word 0
path_create_called: .word 0
temp_destructor_called: .word 0
wire_offset: .word 0
parser_open_called: .word 0
open_called: .word 0
read_called: .word 0
read_call_count: .word 0
wrap_length_seen: .word 0
read_error_seen: .word 0
partial_copy_bytes: .word 0
cluster_slack_bytes: .word 0
pass_message: .ascii "PASS\n"
fail_message: .ascii "FAIL\n"

.section .global_string_object,"a",%progbits
.word 0
.word 0x08e58080
