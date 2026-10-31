.syntax unified
.cpu arm1176jzf-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr r12, =saved_regs
    stmia r12, {r4-r11}
    str sp, [r12, #32]
    str lr, [r12, #36]
    ldr sp, =stack_top
    ldr r0, =test_result
    mov r1, #0
    str r1, [r0]

    /* Voice-reader boundary: the first request is the full 0xffffffff size. */
    bl init_file
    ldr r0, =file_object
    ldr r1, =0xffffffff
    str r1, [r0, #0x20]
    mov r1, #0
    str r1, [r0, #0x34]
    ldr r1, =0xffffffff
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    str r2, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0
    bne fail
    ldr r0, =seen_length
    ldr r1, [r0]
    ldr r2, =0xffffffff
    cmp r1, r2
    bne fail
    ldr r0, =seen_offset
    ldr r1, [r0]
    cmp r1, #0
    bne fail
    ldr r0, =seen_handle
    ldr r1, [r0]
    ldr r2, =0xfeed0001
    cmp r1, r2
    bne fail
    ldr r0, =seen_out_count
    ldr r1, [r0]
    ldr r2, =0xffffffff
    cmp r1, r2
    bne fail

    /* In-range request: the provider should receive 0x284 at file offset 0x20. */
    bl init_file
    ldr r0, =file_object
    ldr r1, =0x284
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    ldr r4, =read_buffer
    str r4, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0
    bne fail
    ldr r0, =seen_length
    ldr r1, [r0]
    ldr r2, =0x284
    cmp r1, r2
    bne fail
    ldr r0, =seen_offset
    ldr r1, [r0]
    cmp r1, #0x20
    bne fail
    ldr r0, =seen_out_count
    ldr r1, [r0]
    ldr r2, =0x284
    cmp r1, r2
    bne fail

    /* An oversized request without arithmetic wrap should clamp to 0x2a0. */
    bl init_file
    ldr r0, =file_object
    ldr r1, =0x300
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    ldr r4, =read_buffer
    str r4, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0
    bne fail
    ldr r0, =seen_length
    ldr r1, [r0]
    ldr r2, =0x2a0
    cmp r1, r2
    bne fail
    ldr r0, =seen_out_count
    ldr r1, [r0]
    ldr r2, =0x2a0
    cmp r1, r2
    bne fail

    /* Prefetch the 0x400-byte buffer from offset 0; the file has 0x2c0 bytes. */
    bl init_file
    ldr r0, =file_object
    mov r1, #0
    str r1, [r0, #0x34]
    ldr r1, =0x400
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    ldr r4, =read_buffer
    str r4, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0
    bne fail
    ldr r0, =seen_length
    ldr r1, [r0]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail
    ldr r0, =file_object
    ldr r1, [r0, #0x34]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail

    /* After consuming the 0x20-byte prefix and 0x2a0-byte field,
       0xfffffff0 bytes leave 0xfffffd50; adding that to 0x2c0 wraps to 0x10. */
    ldr r0, =file_object
    ldr r1, =0xfffffd50
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    ldr r4, =read_buffer
    str r4, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0
    bne fail
    ldr r0, =seen_length
    ldr r1, [r0]
    ldr r2, =0xfffffd50
    cmp r1, r2
    bne fail
    ldr r0, =seen_offset
    ldr r1, [r0]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail
    ldr r0, =seen_handle
    ldr r1, [r0]
    ldr r2, =0xfeed0001
    cmp r1, r2
    bne fail
    ldr r0, =seen_out_count
    ldr r1, [r0]
    ldr r2, =0xfffffd50
    cmp r1, r2
    bne fail

    /* A short provider read must propagate its error and advance by out-count. */
    bl init_file
    ldr r0, =file_object
    ldr r1, =0x2c0
    str r1, [r0, #0x34]
    ldr r0, =provider_error_mode
    mov r1, #1
    str r1, [r0]
    ldr r0, =file_object
    ldr r1, =0xfffffd50
    ldr r2, =read_buffer
    ldr r3, =read_count
    sub sp, sp, #8
    ldr r4, =read_buffer
    str r4, [sp]
    ldr r12, =0x081fd5e9
    blx r12
    add sp, sp, #8
    cmp r0, #0x22
    bne fail
    ldr r0, =seen_out_count
    ldr r1, [r0]
    ldr r2, =7424
    cmp r1, r2
    bne fail
    ldr r0, =file_object
    ldr r1, [r0, #0x34]
    ldr r2, =0x1fc0
    cmp r1, r2
    bne fail
    ldr r0, =seen_offset
    ldr r1, [r0]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail
    ldr r0, =seen_handle
    ldr r1, [r0]
    ldr r2, =0xfeed0001
    cmp r1, r2
    bne fail

    ldr r0, =test_result
    ldr r1, =0x50415353
    str r1, [r0]
    mov r0, #0
    b return_to_uboot
fail:
    ldr r0, =test_result
    ldr r1, =0x4641494c
    str r1, [r0]
    mov r0, #1
return_to_uboot:
    ldr r12, =saved_regs
    ldmia r12, {r4-r11}
    ldr sp, [r12, #32]
    ldr lr, [r12, #36]
    bx lr
.size _start, .-_start

.type init_file,%function
init_file:
    ldr r0, =file_object
    mov r1, #0
    str r1, [r0, #0x34]
    str r1, [r0, #0x38]
    ldr r1, =0x2c0
    str r1, [r0, #0x20]
    mov r1, #0x20
    str r1, [r0, #0x34]
    ldr r1, =0xfeed0001
    str r1, [r0, #0x18]
    ldr r1, =0
    ldr r2, =seen_length
    str r1, [r2]
    ldr r2, =seen_offset
    str r1, [r2]
    ldr r2, =seen_handle
    str r1, [r2]
    ldr r2, =seen_out_count
    str r1, [r2]
    ldr r2, =provider_error_mode
    str r1, [r2]
    ldr r2, =read_count
    str r1, [r2]
    bx lr
.size init_file, .-init_file

.ltorg

.section .runtime_function,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1fd5e8, 0x1da

.section .stub_file_error_check,"ax",%progbits
.thumb
.thumb_func
stub_file_error_check:
    movs r0, #0
    bx lr

.section .stub_lock,"ax",%progbits
.thumb
.thumb_func
stub_lock:
    bx lr

.section .stub_is_open,"ax",%progbits
.thumb
.thumb_func
stub_is_open:
    movs r0, #1
    bx lr

.section .stub_unlock,"ax",%progbits
.thumb
.thumb_func
stub_unlock:
    bx lr

.section .stub_get_provider,"ax",%progbits
.thumb
.thumb_func
stub_get_provider:
    ldr r0, =provider_object
    bx lr
    .ltorg

.section .provider_read,"ax",%progbits
.thumb
.thumb_func
provider_read_stub:
    ldr r0, [sp, #0]        /* actual-count output pointer */
    push {r4, lr}
    ldr r4, =provider_error_mode
    ldr r4, [r4]
    cmp r4, #0
    bne .Lprovider_short
    str r3, [r0]
    ldr r0, =seen_length
    str r3, [r0]
    ldr r0, =seen_offset
    str r2, [r0]
    ldr r0, =seen_handle
    str r1, [r0]
    ldr r0, =seen_out_count
    str r3, [r0]
    movs r0, #0
    pop {r4, pc}
.Lprovider_short:
    ldr r4, =7424
    str r4, [r0]
    ldr r0, =seen_length
    str r3, [r0]
    ldr r0, =seen_offset
    str r2, [r0]
    ldr r0, =seen_handle
    str r1, [r0]
    ldr r0, =seen_out_count
    str r4, [r0]
    movs r0, #0x22
    pop {r4, pc}
    .ltorg

.section .state,"aw",%progbits
.align 4
file_object:
    .space 0x40
provider_object:
    .word provider_vtable
    .space 0x1c
provider_vtable:
    .space 0x1c
    .word provider_read_stub
seen_length:
    .word 0
seen_offset:
    .word 0
seen_handle:
    .word 0
seen_out_count:
    .word 0
read_count:
    .word 0
provider_error_mode:
    .word 0
read_buffer:
    .space 0x10000
test_result:
    .word 0
saved_regs:
    .space 40

.section .stack,"aw",%nobits
.space 0x2000
