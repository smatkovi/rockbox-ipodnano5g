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
/* Original FUN_0822641e: cluster-to-512-byte-LBA mapper. */
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x22641e, 0x1e

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

.section .runtime_cache_allocator,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1f139c, 0x9c

.section .runtime_cache_pool_helper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x158994, 0x18

.section .runtime_cache_getter,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x21959c, 0x52

.section .runtime_cache_release,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2195ee, 0x26

.section .runtime_cache_sector_read,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2192c4, 0x4c

.section .runtime_cache_bulk_read,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x219310, 0x48

.section .runtime_cache_readback,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x219258, 0x28

.section .stub_cache_unlock,"ax",%progbits
.thumb
.thumb_func
stub_cache_unlock:
    bx lr

.section .stub_cache_lock,"ax",%progbits
.thumb
.thumb_func
stub_cache_lock:
    bx lr

.section .stub_device_ready,"ax",%progbits
.thumb
.thumb_func
stub_device_ready:
    movs r0, #1
    bx lr

.section .stub_local_sector_entry,"ax",%progbits
.thumb
.thumb_func
stub_local_sector_entry:
    b.n stub_local_sector_io

.section .stub_local_sector_io,"ax",%progbits
.thumb
.thumb_func
stub_local_sector_io:
    push {r4, r5, r6, r7, lr}
    cmp r0, #1
    bne .Lbad_local_sector
    cmp r3, #0
    beq .Lbad_local_sector
    mov r4, r1
    mov r5, r2
    mov r6, r3

.Lsector_dispatch:
    ldr r0, =0x0000067c
    cmp r4, r0
    beq .Lfat_sector
    ldr r0, =0x002c5ca0
    cmp r4, r0
    beq .Lcandidate_sector_zero
    ldr r0, =0x002c5ca1
    cmp r4, r0
    bne .Lbad_local_sector
    movs r7, #1
    b .Lcandidate_sector_ready
.Lcandidate_sector_zero:
    movs r7, #0
.Lcandidate_sector_ready:
    ldr r0, =sector_base_seen
    ldr r1, [r0]
    cmp r1, #0
    bne .Lcandidate_base_ready
    movs r1, #1
    str r1, [r0]
    ldr r0, =sector_base_lba
    str r4, [r0]
.Lcandidate_base_ready:
    ldr r0, =sector_bitmap
    ldr r1, [r0]
    movs r2, #1
    lsls r2, r2, r7
    orrs r1, r2
    str r1, [r0]
    lsls r7, r7, #9
    ldr r0, =candidate_file
    adds r0, r0, r7
    b .Lcopy_one_sector

.Lfat_sector:
    ldr r0, =fat_sector_seen
    ldr r1, [r0]
    adds r1, #1
    str r1, [r0]
    ldr r0, =fat_sector_capture

.Lcopy_one_sector:
    movs r7, #0x80
.Lcopy_sector_words:
    ldr r1, [r0]
    str r1, [r5]
    adds r0, #4
    adds r5, #4
    subs r7, #1
    bne .Lcopy_sector_words

    ldr r0, =sector_io_count
    ldr r1, [r0]
    adds r1, #1
    str r1, [r0]
    adds r4, #1
    movs r0, #2
    lsls r0, r0, #8
    adds r5, r5, r0
    subs r6, #1
    bne .Lsector_dispatch
    movs r0, #1
    pop {r4, r5, r6, r7, pc}
.Lbad_local_sector:
    FAIL_TO_ARM
    .balign 4
    .ltorg

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
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2014fc, 0xb2
.balign 4
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2015b0, 0x0c

.section .runtime_fat_entry_read,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x143ccc, 0x1c
.section .stub_fat_lock,"ax",%progbits
.thumb
.thumb_func
stub_fat_lock:
    movs r0, #1
    bx lr
.section .runtime_fat_sector_read,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2015bc, 0x192
.section .runtime_fat_value_read,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x22fbbc, 0xda
.section .runtime_fat_marker_filter,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x235b00, 0x46
.section .runtime_fat_marker_constants,"a",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x235b48, 0x0c
.section .parser_node_allocate_stub,"ax",%progbits
.thumb
.thumb_func
parser_node_allocate_stub:
    ldr r0, =parser_node_buffer
    bx lr
    .ltorg
    .space 0x18 - (. - parser_node_allocate_stub)
.section .runtime_divider_entry,"ax",%progbits
.arm
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18e65c, 0x1c
.section .runtime_stream_helper,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18eb5c, 0x20
.section .runtime_divider_tail,"ax",%progbits
.arm
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x18f6f0, 0x64
.section .runtime_stream_global_init,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1969c8, 0x2f0

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
    .space 0x02
    .word 0x00000000
    .word 0x00007800
    .hword 1
    .space 0x06
    .word 0x00000100
    .space 0x0c
    .hword 32
    .space 0x26
    .space 0x100
    .word fat_cache
    .space 0x10
    .hword 16
    .hword 4
    .space 8
    .word 0x01dc3c00
    .space 4
    .word 1904
    .space 0x1c
file_metadata:
    .space 0x1c
    .word 0x2c0
cache_entry:
    .space 0x18
cache_data:
    .space 0x200
cache_entry_1:
    .space 0x18
cache_data_1:
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

.section .fat_cache_data,"aw",%progbits
.balign 4
fat_sector_capture:
    .incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_FAT_cluster_179788_copy0_lba_0000067c_20261030.bin"
.balign 4
fat_cache:
    .space 0x10000
