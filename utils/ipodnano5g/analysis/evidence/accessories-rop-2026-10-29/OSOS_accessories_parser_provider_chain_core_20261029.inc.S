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
push {r3}
ldr r3, [pc, #4]
bx r3
nop
.word wrapper_router
.hword 0x46c0
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1fd5f6, 0x1d2

.section .wrapper_router,"ax",%progbits
.thumb
.thumb_func
wrapper_router:
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne .Lwrapper_original
    ldr r3, =loader_wrapper_args
    str r0, [r3]
    str r1, [r3, #4]
    str r2, [r3, #8]
    ldr r2, [sp]
    str r2, [r3, #12]
    ldr r3, =loader_wrapper_count
    ldr r2, [r3]
    adds r2, #1
    str r2, [r3]
    add sp, #4
    movs r0, #0
    bx lr
.Lwrapper_original:
    /* The entry veneer saved r3. Restore it, reproduce the original 12-byte
       prologue, then continue at the first untouched instruction. */
    pop {r3}
    push {r4, r5, r6, r7, lr}
    sub sp, #0x2c
    mov r7, r1
    mov r4, r0
    mov r6, r2
    mov r5, r3
    ldr r3, =0x081fd5f7
    bx r3
.ltorg

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

.section .provider_state,"aw",%progbits
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
