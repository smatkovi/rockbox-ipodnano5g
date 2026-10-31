.syntax unified
.cpu arm1176jzf-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr sp, =stack_top

    ldr r0, =handle_entry
    mov r1, #0
    str r1, [r0, #4]
    ldr r1, =0x2c0
    str r1, [r0, #8]
    ldr r1, =179788
    str r1, [r0, #12]
    mov r1, #0
    str r1, [r0, #16]

    ldr r0, =file_metadata
    ldr r1, =0x2c0
    str r1, [r0, #0x1c]

    ldr r0, =cache_data
    mov r1, #0x41
    mov r2, #0x200
fill_cache:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_cache

    ldr r0, =out_buffer
    mov r1, #0xcc
    ldr r2, =0x1d41
fill_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_output

    /* FUN_0812ac00 caps each FAT read at 0x100 bytes; model 29 full calls. */
    ldr r4, =out_buffer
    mov r5, #29
read_full_chunks:
    mov r0, #1
    mov r1, r4
    mov r2, #0x100
    ldr r12, =0x0814346d
    blx r12
    cmp r0, #0x100
    bne fail
    add r4, r4, #0x100
    subs r5, r5, #1
    bne read_full_chunks

    /* The 30th call copies the last 64 cluster bytes, then returns the 0xffff sentinel. */
    mov r0, #1
    mov r1, r4
    mov r2, #0x100
    ldr r12, =0x0814346d
    blx r12
    ldr r1, =0xffff
    cmp r0, r1
    bne fail

    /* All bytes from EOF (offset 0x2c0) to the 8 KiB cluster end were copied. */
    ldr r4, =out_buffer
    ldr r5, =7488
    mov r6, #0x41
check_cluster_slack:
    ldrb r0, [r4]
    cmp r0, r6
    bne fail
    adds r4, r4, #1
    subs r5, r5, #1
    bne check_cluster_slack

    ldr r4, =out_buffer
    adds r4, r4, #0x1d40
    ldrb r0, [r4]
    cmp r0, #0xcc
    bne fail

    ldr r0, =handle_entry
    ldr r1, [r0, #8]
    ldr r2, =0x1fc0
    cmp r1, r2
    bne fail
    ldr r1, [r0, #0x14]
    cmp r1, #1
    bne fail
    ldr r0, =file_metadata
    ldr r1, [r0, #0x1c]
    ldr r2, =0x1fc0
    cmp r1, r2
    bne fail

    ldr r0, =pass_text
    mov r1, #5
    mov r4, #0
    b emit_result
fail:
    ldr r0, =fail_text
    mov r1, #5
    mov r4, #1
emit_result:
    mov r2, r1
    mov r1, r0
    mov r0, #1
    mov r7, #4
    svc #0
    mov r0, r4
    mov r7, #1
    svc #0
.size _start, .-_start
.ltorg

.section .runtime_fat_reader,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x14346c, 0x294
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x143700, 8

.section .stub_no_next_cluster,"ax",%progbits
.thumb
.thumb_func
stub_no_next_cluster:
    movs r0, #0
    bx lr

.section .stub_handle_lookup,"ax",%progbits
.thumb
.thumb_func
stub_handle_lookup:
    ldr r0, =handle_entry
    bx lr
    .ltorg

.section .stub_cluster_map,"ax",%progbits
.thumb
.thumb_func
stub_cluster_map:
    str r2, [r3]
    movs r0, #1
    bx lr

.section .stub_sector_map,"ax",%progbits
.thumb
.thumb_func
stub_sector_map:
    movs r0, #0
    bx lr

.section .stub_cache_get,"ax",%progbits
.thumb
.thumb_func
stub_cache_get:
    ldr r0, =cache_entry
    bx lr
    .ltorg

.section .stub_memcpy,"ax",%progbits
.thumb
.thumb_func
stub_memcpy:
    mov r3, r0
copy_loop:
    cmp r2, #0
    beq copy_done
    ldrb r0, [r3]
    strb r0, [r1]
    adds r3, r3, #1
    adds r1, r1, #1
    subs r2, r2, #1
    b copy_loop
copy_done:
    bx lr

.section .stub_cache_valid,"ax",%progbits
.thumb
.thumb_func
stub_cache_valid:
    movs r0, #1
    bx lr

.section .stub_cache_release,"ax",%progbits
.thumb
.thumb_func
stub_cache_release:
    bx lr

.section .stub_bulk_read,"ax",%progbits
.thumb
.thumb_func
stub_bulk_read:
    push {r4, lr}
    mov r4, r2
    lsls r3, r3, #9
    movs r1, #0x42
bulk_fill:
    cmp r3, #0
    beq bulk_done
    strb r1, [r4]
    adds r4, r4, #1
    subs r3, r3, #1
    b bulk_fill
bulk_done:
    movs r0, #1
    pop {r4, pc}

.section .stub_volume_unlock,"ax",%progbits
.thumb
.thumb_func
stub_volume_unlock:
    bx lr

.section .stub_noop_lock,"ax",%progbits
.thumb
.thumb_func
stub_volume_lock:
    bx lr

.section .stub_handle_unlock,"ax",%progbits
.thumb
.thumb_func
stub_handle_unlock:
    bx lr

.section .stub_error_log,"ax",%progbits
.thumb
.thumb_func
stub_error_log:
    bx lr

.section .state,"aw",%progbits
.align 4
handle_entry:
    .word handle_record
    .space 0x3c
handle_record:
    .word volume_context
    .word file_metadata
volume_context:
    .space 0x68
    .word 0x1fff
    .hword 8
    .space 0x0a
    .hword 1
    .space 0x154
    .hword 4
    .space 0x30
file_metadata:
    .space 0x1c
    .word 0x2c0
cache_entry:
    .space 0x18
cache_data:
    .space 0x200
out_buffer:
    .space 0x1d41
pass_text:
    .ascii "PASS\n"
fail_text:
    .ascii "FAIL\n"

.section .stack,"aw",%nobits
.space 0x2000
