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
    mov r1, #0x20
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

    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x1d41
fill_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_output

    ldr r0, =file_object
    ldr r1, =0xfeed0001
    str r1, [r0, #0x18]
    ldr r1, =0x2c0
    str r1, [r0, #0x20]
    mov r1, #0x20
    str r1, [r0, #0x34]
    mov r1, #0
    str r1, [r0, #0x38]

    /* Candidate-sized read: [0x20,0x2a4) stays inside the 0x2c0-byte file. */
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

    /* The original provider executes three bounded FAT reads (0x100,0x100,0x84). */
    ldr r0, =read_count
    ldr r1, [r0]
    ldr r2, =0x284
    cmp r1, r2
    bne fail
    ldr r0, =file_object
    ldr r1, [r0, #0x34]
    ldr r2, =0x2a4
    cmp r1, r2
    bne fail

    /* The real FAT reader reaches the same file position without changing file size. */
    ldr r0, =handle_entry
    ldr r1, [r0, #8]
    ldr r2, =0x2a4
    cmp r1, r2
    bne fail
    ldr r1, [r0, #0x14]
    cmp r1, #0
    bne fail
    ldr r0, =file_metadata
    ldr r1, [r0, #0x1c]
    ldr r2, =0x2c0
    cmp r1, r2
    bne fail

    ldr r4, =read_buffer
    ldr r5, =0x284
    mov r6, #0x41
check_copied_bytes:
    ldrb r0, [r4]
    cmp r0, r6
    bne fail
    adds r4, r4, #1
    subs r5, r5, #1
    bne check_copied_bytes
    ldrb r0, [r4]
    cmp r0, #0xcc
    bne fail

    /* Bounded probe through the original provider at the rounded cluster EOF. */
    ldr r0, =handle_entry
    ldr r1, =0x2c0
    str r1, [r0, #8]
    mov r1, #0
    str r1, [r0, #0x14]
    ldr r0, =file_metadata
    ldr r1, =0x2c0
    str r1, [r0, #0x1c]
    ldr r0, =read_count
    str r1, [r0]
    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x2001
fill_second_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_second_output

    ldr r0, =provider_object
    ldr r1, =0xfeed0001
    ldr r2, =0x2c0
    ldr r3, =0x1d50
    sub sp, sp, #16
    ldr r4, =read_count
    str r4, [sp]
    ldr r4, =read_buffer
    str r4, [sp, #4]
    mov r4, #0
    str r4, [sp, #8]
    ldr r12, =0x0812ac01
    blx r12
    add sp, sp, #16
    cmp r0, #0
    bne fail

    /* A final 0x50-byte chunk crosses the rounded 0x2000-byte cluster end by 16. */
    ldr r0, =read_count
    ldr r1, [r0]
    ldr r2, =0x1d50
    cmp r1, r2
    bne fail
    ldr r0, =handle_entry
    ldr r1, [r0, #8]
    ldr r2, =0x10
    cmp r1, r2
    bne fail
    ldr r1, [r0, #12]
    ldr r2, =179788
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
    ldr r4, =read_buffer
    ldr r5, =0x1d50
    mov r6, #0x41
check_second_read:
    ldrb r0, [r4]
    cmp r0, r6
    bne fail
    adds r4, r4, #1
    subs r5, r5, #1
    bne check_second_read
    ldrb r0, [r4]
    cmp r0, #0xcc
    bne fail

    /* Control case: a full 0x100-byte request at the same boundary. */
    ldr r0, =handle_entry
    ldr r1, =0x1fc0
    str r1, [r0, #8]
    ldr r1, =179788
    str r1, [r0, #12]
    mov r1, #1
    str r1, [r0, #0x14]
    ldr r0, =file_metadata
    ldr r1, =0x1fc0
    str r1, [r0, #0x1c]
    ldr r0, =read_count
    mov r2, #0
    str r2, [r0]
    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x2001
fill_control_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_control_output

    ldr r0, =provider_object
    ldr r1, =0xfeed0001
    ldr r2, =0x1fc0
    ldr r3, =0x100
    sub sp, sp, #16
    ldr r4, =read_count
    str r4, [sp]
    ldr r4, =read_buffer
    str r4, [sp, #4]
    mov r4, #0
    str r4, [sp, #8]
    ldr r12, =0x0812ac01
    blx r12
    add sp, sp, #16
    cmp r0, #0
    bne fail
    ldr r0, =read_count
    ldr r1, [r0]
    ldr r2, =0x100
    cmp r1, r2
    bne fail
    ldr r0, =handle_entry
    ldr r1, [r0, #8]
    ldr r2, =0xc0
    cmp r1, r2
    bne fail
    ldr r1, [r0, #12]
    ldr r2, =179788
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
    ldr r0, =read_buffer
    ldr r1, =0x100
    mov r2, #0x41
check_partial_copy:
    ldrb r3, [r0]
    cmp r3, r2
    bne fail
    adds r0, r0, #1
    subs r1, r1, #1
    bne check_partial_copy
    ldrb r3, [r0]
    cmp r3, #0xcc
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

/* Fresh-process reproductions of the same 0x1fc0/0x100 boundary state. */
.section .isolated_start,"ax",%progbits
.arm
.global isolated_provider_start
.type isolated_provider_start,%function
isolated_provider_start:
    bl boundary_state_init
    ldr r0, =provider_object
    ldr r1, =0xfeed0001
    ldr r2, =0x1fc0
    ldr r3, =0x100
    sub sp, sp, #16
    ldr r4, =read_count
    str r4, [sp]
    ldr r4, =read_buffer
    str r4, [sp, #4]
    mov r4, #0
    str r4, [sp, #8]
    ldr r12, =0x0812ac01
    blx r12
    add sp, sp, #16
    b isolated_record_exit
.size isolated_provider_start, .-isolated_provider_start

.global isolated_crossing_start
.type isolated_crossing_start,%function
isolated_crossing_start:
    bl boundary_state_init
    ldr r0, =file_metadata
    ldr r1, =0x2c0
    str r1, [r0, #0x1c]
    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x1d51
fill_crossing_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_crossing_output
    ldr r0, =provider_object
    ldr r1, =0xfeed0001
    ldr r2, =0x2c0
    ldr r3, =0x1d50
    sub sp, sp, #16
    ldr r4, =read_count
    str r4, [sp]
    ldr r4, =read_buffer
    str r4, [sp, #4]
    mov r4, #0
    str r4, [sp, #8]
    ldr r12, =0x0812ac01
    blx r12
    add sp, sp, #16
    b crossing_record_exit
.size isolated_crossing_start, .-isolated_crossing_start

.global isolated_core_start
.type isolated_core_start,%function
isolated_core_start:
    bl boundary_state_init
    ldr r0, =0xfeed0001
    ldr r1, =read_buffer
    ldr r2, =0x100
    ldr r12, =0x0814346d
    blx r12
    b isolated_record_exit
.size isolated_core_start, .-isolated_core_start

.type boundary_state_init,%function
boundary_state_init:
    ldr sp, =stack_top

    /* Clear every mutable handle word while preserving its record pointer. */
    ldr r0, =handle_entry
    adds r0, r0, #4
    mov r1, #0
    mov r2, #15
clear_handle_words:
    str r1, [r0]
    adds r0, r0, #4
    subs r2, r2, #1
    bne clear_handle_words

    ldr r0, =handle_record
    ldr r1, =volume_context
    str r1, [r0]
    ldr r1, =file_metadata
    str r1, [r0, #4]

    ldr r0, =handle_entry
    ldr r1, =0x1fc0
    str r1, [r0, #8]
    ldr r1, =179788
    str r1, [r0, #12]
    mov r1, #1
    str r1, [r0, #0x14]

    ldr r0, =file_metadata
    mov r1, #0
    mov r2, #8
clear_metadata_words:
    str r1, [r0]
    adds r0, r0, #4
    subs r2, r2, #1
    bne clear_metadata_words
    ldr r0, =file_metadata
    ldr r1, =0x1fc0
    str r1, [r0, #0x1c]

    ldr r0, =cache_entry
    mov r1, #0
    mov r2, #6
clear_cache_entry:
    str r1, [r0]
    adds r0, r0, #4
    subs r2, r2, #1
    bne clear_cache_entry

    ldr r0, =cache_data
    mov r1, #0x41
    mov r2, #0x200
fill_isolated_cache:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_isolated_cache

    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x201
fill_isolated_output:
    strb r1, [r0]
    adds r0, r0, #1
    subs r2, r2, #1
    bne fill_isolated_output
    ldr r0, =read_count
    mov r1, #0
    str r1, [r0]
    bx lr
.size boundary_state_init, .-boundary_state_init

isolated_record_exit:
    ldr r4, =results
    str r0, [r4]
    ldr r1, =read_count
    ldr r1, [r1]
    str r1, [r4, #4]
    ldr r1, =handle_entry
    ldr r2, [r1, #8]
    str r2, [r4, #8]
    ldr r2, [r1, #12]
    str r2, [r4, #12]
    ldr r2, [r1, #0x14]
    str r2, [r4, #16]
    ldr r1, =file_metadata
    ldr r2, [r1, #0x1c]
    str r2, [r4, #20]

    ldr r0, =read_buffer
    mov r1, #0
    ldr r2, =0x100
    mov r3, #0x41
count_isolated_mismatches:
    ldrb r5, [r0], #1
    cmp r5, r3
    addeq r1, r1, #0
    addne r1, r1, #1
    subs r2, r2, #1
    bne count_isolated_mismatches
    str r1, [r4, #24]

    mov r0, #1
    mov r1, r4
    mov r2, #28
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0
.ltorg

crossing_record_exit:
    ldr r4, =crossing_results
    str r0, [r4]
    ldr r1, =read_count
    ldr r2, [r1]
    str r2, [r4, #4]
    ldr r1, =handle_entry
    ldr r2, [r1, #8]
    str r2, [r4, #8]
    ldr r2, [r1, #12]
    str r2, [r4, #12]
    ldr r2, [r1, #0x14]
    str r2, [r4, #16]
    ldr r1, =file_metadata
    ldr r2, [r1, #0x1c]
    str r2, [r4, #20]
    ldr r1, =read_buffer
    ldrb r2, [r1]
    str r2, [r4, #24]
    ldr r3, =0x1cff
    add r3, r1, r3
    ldrb r2, [r3]
    str r2, [r4, #28]
    ldr r3, =0x1d00
    add r3, r1, r3
    ldrb r2, [r3]
    str r2, [r4, #32]
    ldr r3, =0x1d3f
    add r3, r1, r3
    ldrb r2, [r3]
    str r2, [r4, #36]
    ldr r3, =0x1d40
    add r3, r1, r3
    ldrb r2, [r3]
    str r2, [r4, #40]
    ldr r3, =0x1d4f
    add r3, r1, r3
    ldrb r2, [r3]
    str r2, [r4, #44]
    ldr r1, =read_buffer
    mov r2, #0
    ldr r3, =0x1d50
count_crossing_changed:
    ldrb r5, [r1], #1
    cmp r5, #0xcc
    addeq r2, r2, #0
    addne r2, r2, #1
    subs r3, r3, #1
    bne count_crossing_changed
    str r2, [r4, #48]
    mov r0, #1
    mov r1, r4
    mov r2, #52
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0
.ltorg

.section .runtime_provider,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x12ac00, 0x7a

.section .runtime_fat_helper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1384b0, 0x12

.section .runtime_fat_reader,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x14346c, 0x294
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x143700, 8

.section .runtime_cluster_map,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1d7e1a, 0x70

.section .runtime_file_wrapper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1fd5e8, 0x1da

.section .stub_fat_lookup,"ax",%progbits
.thumb
.thumb_func
stub_fat_lookup:
    ldr r0, =handle_entry
    bx lr
    .ltorg

.section .stub_no_next_cluster,"ax",%progbits
.thumb
.thumb_func
stub_no_next_cluster:
    movs r0, #0
    bx lr

.section .stub_sector_map,"ax",%progbits
.thumb
.thumb_func
stub_sector_map:
    movs r0, #0
    bx lr

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

.section .stub_cache_get,"ax",%progbits
.thumb
.thumb_func
stub_cache_get:
    ldr r0, =cache_entry
    bx lr
    .ltorg

.section .stub_cache_valid,"ax",%progbits
.thumb
.thumb_func
stub_cache_valid:
    movs r0, #1
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

.section .stub_cache_release,"ax",%progbits
.thumb
.thumb_func
stub_cache_release:
    bx lr

.section .stub_volume_unlock,"ax",%progbits
.thumb
.thumb_func
stub_volume_unlock:
    bx lr

.section .stub_volume_lock,"ax",%progbits
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

.section .stub_provider_lock,"ax",%progbits
.thumb
.thumb_func
stub_provider_lock:
    bx lr

.section .stub_file_error_check,"ax",%progbits
.thumb
.thumb_func
stub_file_error_check:
    movs r0, #0
    bx lr

.section .stub_is_open,"ax",%progbits
.thumb
.thumb_func
stub_is_open:
    movs r0, #1
    bx lr

.section .stub_provider_unlock,"ax",%progbits
.thumb
.thumb_func
stub_provider_unlock:
    bx lr

.section .stub_get_provider,"ax",%progbits
.thumb
.thumb_func
stub_get_provider:
    ldr r0, =provider_object
    bx lr
    .ltorg

.section .stub_handle_lookup,"ax",%progbits
.thumb
.thumb_func
stub_handle_lookup:
    ldr r0, =fat_handle
    str r0, [r2]
    movs r0, #1
    bx lr
    .ltorg

.section .stub_seek,"ax",%progbits
.thumb
.thumb_func
stub_seek:
    ldr r3, =handle_entry
    str r2, [r3, #8]
    movs r0, #0
    movs r1, #0
    bx lr
    .ltorg

.section .stub_provider_error,"ax",%progbits
.thumb
.thumb_func
stub_provider_error:
    movs r0, #0x22
    bx lr

.section .stub_cluster_extent,"ax",%progbits
.thumb
.thumb_func
stub_cluster_extent:
    ldr r4, =179788
    cmp r1, r4
    bne .Lno_cluster_extent
    str r1, [r2]
    movs r0, #1
    bx lr
.Lno_cluster_extent:
    movs r0, #0
    bx lr
    .ltorg

.section .provider_data,"aw",%progbits
.balign 4
provider_chunk_size_pointer:
    .word provider_chunk_size

.section .fat_helper_sentinel,"aw",%progbits
.balign 4
    .word 0xffff

.section .state,"aw",%progbits
.align 4
file_object:
    .space 0x40
provider_object:
    .word provider_vtable
    .space 0x3c
provider_vtable:
    .space 0x1c
    .word 0x0812ac01
provider_chunk_size:
    .word 0x100
fat_handle:
    .word 0xfeed0001
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
read_buffer:
    .space 0x2001
read_count:
    .word 0
pass_text:
    .ascii "PASS\n"
fail_text:
    .ascii "FAIL\n"
results:
    .space 0x1c
crossing_results:
    .space 0x34

.section .stack,"aw",%nobits
.space 0x2000
