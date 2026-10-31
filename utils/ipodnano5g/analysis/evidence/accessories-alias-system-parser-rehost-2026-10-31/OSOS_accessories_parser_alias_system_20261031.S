.syntax unified
.cpu arm1176jzf-s

.macro FAIL_TO_ARM
    ldr r3, =fail
    bx r3
.endm

.section .system_start,"ax",%progbits
.arm
.global system_start
.type system_start,%function
system_start:
    msr cpsr_c, #0xd3
    ldr sp, =0x08003000
    bl initialize_mmu
    ldr pc, =_start
.size system_start, .-system_start
.ltorg

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr sp, =stack_top
    bl combined_setup
    ldr r0, =stack_base + 0x140
    mov sp, r0
    ldr r0, =0x08e58000
    ldr r1, =0x0802c3c5
    blx r1
    b fail
.size _start, .-_start

.section .mmu_setup,"ax",%progbits
.arm
/* Set up the same DRAM identity and SDRAM alias descriptors used by OSOS.
   The high alias is virtual 0x88000000..0x8bffffff -> physical
   0x08000000..0x0bffffff, with the non-cacheable 0x4c02 descriptor. */
.type initialize_mmu,%function
initialize_mmu:
    ldr r0, =0x0bfd0000
    mov r1, #4096
    mov r2, #0
1:
    str r2, [r0], #4
    subs r1, r1, #1
    bne 1b

    ldr r7, =0x0bfd0000
    ldr r9, =0x00100000
    ldr r4, =0x08000000
    ldr r5, =0x08000000
    mov r6, #64
    ldr r8, =0x00007c0e
2:
    mov r0, r4, lsr #20
    add r0, r7, r0, lsl #2
    orr r1, r5, r8
    str r1, [r0]
    add r4, r4, r9
    add r5, r5, r9
    subs r6, r6, #1
    bne 2b

    ldr r4, =0x88000000
    ldr r5, =0x08000000
    mov r6, #64
    ldr r8, =0x00004c02
3:
    mov r0, r4, lsr #20
    add r0, r7, r0, lsl #2
    orr r1, r5, r8
    str r1, [r0]
    add r4, r4, r9
    add r5, r5, r9
    subs r6, r6, #1
    bne 3b

    /* Match OSOS low-vector alias and IRAM identity descriptors. */
    ldr r0, =0x2200c802
    str r0, [r7]
    ldr r0, =0x22004c02
    str r0, [r7, #0x880]

    mov r0, #0
    mcr p15, 0, r0, c2, c0, 2
    ldr r0, =0x0bfd0000
    mcr p15, 0, r0, c2, c0, 0
    mov r0, #1
    mcr p15, 0, r0, c3, c0, 0
    mov r0, #0
    mcr p15, 0, r0, c8, c7, 0
    mcr p15, 0, r0, c7, c10, 4
    mcr p15, 0, r0, c7, c5, 0
    mrc p15, 0, r1, c1, c0, 0
    ldr r2, =0x10001004
    bic r1, r1, r2
    ldr r2, =0x00801005
    orr r1, r1, r2
    mcr p15, 0, r1, c1, c0, 0
    mcr p15, 0, r0, c7, c10, 4
    mcr p15, 0, r0, c7, c5, 4
    bx lr
.size initialize_mmu, .-initialize_mmu
.ltorg

.section .fault_vectors,"ax",%progbits
.arm
.global fault_vectors
fault_vectors:
    b fault_halt
    b fault_undefined
    b fault_swi
    b fault_prefetch_abort
    b fault_data_abort
    b fault_halt
    b fault_irq
    b fault_fiq
fault_undefined:
    mov r2, #1
    b capture_fault
fault_swi:
    mov r2, #2
    b capture_fault
fault_prefetch_abort:
    mov r2, #3
    b capture_fault
fault_data_abort:
    mov r2, #4
    b capture_fault
fault_irq:
    mov r2, #6
    b capture_fault
fault_fiq:
    mov r2, #7
capture_fault:
    mrs r0, spsr
    mov r1, lr
    mrc p15, 0, r3, c5, c0, 0
    mrc p15, 0, r4, c6, c0, 0
    ldr r5, =0x08003f00
    stmia r5, {r0-r4}
    str r2, [r5, #0x14]
fault_halt:
    b fault_halt
.ltorg

.section .combined_setup,"ax",%progbits
.arm
.type combined_setup,%function
combined_setup:
    ldr r0, =handle_record
    ldr r1, =volume_context
    str r1, [r0]
    ldr r1, =file_metadata
    str r1, [r0, #4]

    ldr r0, =handle_entry
    ldr r1, =0x2e0
    str r1, [r0, #8]
    ldr r1, =179788
    str r1, [r0, #12]
    mov r1, #0
    str r1, [r0, #0x14]

    ldr r0, =file_metadata
    ldr r1, =0x2e0
    str r1, [r0, #0x1c]

    ldr r0, =file_object
    ldr r1, =0xfeed0001
    str r1, [r0, #0x18]
    ldr r1, =0x2e0
    str r1, [r0, #0x20]
    mov r1, #0
    str r1, [r0, #0x34]
    str r1, [r0, #0x38]

    /* Two cache records are linked for the original LRU/cache manager. */
    ldr r0, =cache_entry
    ldr r1, =cache_entry_1
    str r1, [r0]

    /* Captured BPB data start, expressed in the runtime's 512-byte LBA unit. */
    ldr r0, =volume_context
    ldr r1, =0x00007800
    str r1, [r0, #0x74]
    /* BPB-derived maximum cluster and volume end in runtime LBA units. */
    ldr r1, =0x001dbc41
    str r1, [r0, #0x7c]
    ldr r1, =0x01dc3c00
    str r1, [r0, #0x1d8]

    /* Exercise original FUN_082014fc against the captured FAT entry. */
    ldr r0, =volume_context
    ldr r1, =179788
    ldr r2, =extent_cluster
    ldr r3, =0x100
    ldr r4, =0x082014fd
    push {lr}
    blx r4
    pop {lr}
    cmp r0, #1
    bne fail
    ldr r1, =extent_result
    str r0, [r1]
    ldr r1, =extent_cluster
    ldr r1, [r1]
    ldr r2, =179788
    cmp r1, r2
    bne fail

    /* Seed the file handle from the original runtime cluster-to-LBA mapper. */
    ldr r0, =volume_context
    ldr r1, =179788
    ldr r2, =0x0822641f
    push {lr}
    blx r2
    pop {lr}
    ldr r1, =0x002c5ca0
    cmp r0, r1
    bne fail
    ldr r1, =handle_entry
    str r0, [r1, #0x10]

    ldr r0, =stream_object
    ldr r1, =stream_vtable
    str r1, [r0]
    mvn r1, #0
    str r1, [r0, #4]
    ldr r1, =candidate_file
    str r1, [r0, #0x0c]
    ldr r1, =stream_buffer
    str r1, [r0, #0x14]
    ldr r1, =0x8000
    str r1, [r0, #0x18]
    mov r1, #0
    str r1, [r0, #0x1c]
    /* Begin at the wire prefix; the original token reader must consume it. */
    mov r1, #0
    str r1, [r0, #0x20]
    mov r1, #0
    str r1, [r0, #0x24]
    str r1, [r0, #0x28]
    str r1, [r0, #0x2c]
    ldr r1, =file_object
    str r1, [r0, #0x30]
    bx lr
.size combined_setup, .-combined_setup
.ltorg

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
    /* Keep the caller-saved r3 away from the flag: a later wrapper call uses
       r3 as its out-count pointer and stores through it. */
    ldr r3, =0x08e6000c
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
.ltorg
.space 0x10c - (. - constructor_stub)
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x19887c, 0x10

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
    ldr r3, =stream_object
    str r3, [r0]
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
.thumb_func
read_gate:
    push {r4, lr}
    ldr r3, =0x08e58034
    cmp r0, r3
    bne .Lloader_read
    ldr r3, =stream_dispatch_count
    ldr r4, [r3]
    adds r4, #1
    str r4, [r3]
    ldr r4, =0x08012001
    blx r4
    pop {r4, pc}
.Lloader_read:
    ldr r3, =stack_base + 0x40
    cmp r0, r3
    bne .Lbad_read
    ldr r3, =0x10f80
    cmp r1, r3
    bne .Lbad_read
    ldr r3, =0x8bf00000
    cmp r2, r3
    bne .Lbad_read
    /* Model the successful FAT/VFS read by copying the exact current linked
       loader bytes into the requested guest address. The underlying file
       read remains stubbed; this isolates post-read cleanup effects. Use the
       byte accesses seen in the OSOS FAT reader. */
    ldr r3, =loader_file_image
    ldr r4, =0x10f80
.Lcopy_loader:
    ldrb r0, [r3]
    strb r0, [r2]
    adds r3, #1
    adds r2, #1
    subs r4, #1
    bne .Lcopy_loader
    ldr r3, =read_called
    movs r4, #1
    str r4, [r3]
    movs r0, #0
    pop {r4, pc}
.Lbad_read:
    FAIL_TO_ARM
.ltorg

.section .loader_file_image,"a",%progbits
.align 2
.global loader_file_image
loader_file_image:
.incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin"

.section .read_entry_prefix,"ax",%progbits
.thumb
    b.n read_gate

.section .dispatcher_copy,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x268c3a, 0x0e

.section .token_reader_original,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x26dd26, 0x0c

.section .dsb_helper_stub,"ax",%progbits
.arm
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x3531c0, 0x0c

.section .loader_entry,"ax",%progbits
.arm
loader_stub:
    b loader_impl

.section .cleanup_probe,"aw",%progbits
.byte 0x7f

.section .loader_impl,"ax",%progbits
.arm
loader_impl:
    ldr r0, =0x0bf00040
    ldrb r1, [r0]
    cmp r1, #0
    bne fail
    /* The candidate's word at file offset 0x158 is copied to the parser's
       saved-PC slot S+0x13c (payload starts at S+4, file offset 0x20). */
    ldr r0, =stack_base + 0x13c
    ldr r1, [r0]
    ldr r2, =0x08007107
    cmp r1, r2
    bne fail
    ldr r0, =string_dtor_called
    ldr r1, [r0]
    /* The original token reader consumes the candidate's complete wire
       prefix before the 0x44 field; three parser string objects are destroyed. */
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
    ldr r0, =stream_dispatch_count
    ldr r1, [r0]
    cmp r1, #1
    beq fail
    ldr r0, =stream_object
    ldr r1, [r0, #0x20]
    ldr r2, =0x2b8
    cmp r1, r2
    bne fail
    ldrb r1, [r0, #0x28]
    cmp r1, #1
    bne fail
    ldr r0, =file_object
    ldr r1, [r0, #0x34]
    ldr r2, =0x2e0
    cmp r1, r2
    bne fail
    ldr r0, =handle_entry
    ldr r1, [r0, #8]
    cmp r1, r2
    bne fail
    ldr r0, =file_metadata
    ldr r1, [r0, #0x1c]
    cmp r1, r2
    bne fail
    /* Confirm that the cache source supplied bytes on both sides of the
       512-byte sector boundary and the in-file terminator. */
    ldr r0, =stream_buffer
    ldr r1, [r0, #0x200]
    ldr r0, =candidate_file
    ldr r3, [r0, #0x200]
    cmp r1, r3
    bne fail
    ldr r0, =stream_buffer
    ldr r1, [r0, #0x2a4]
    ldr r0, =candidate_file
    ldr r3, [r0, #0x2a4]
    cmp r1, r3
    bne fail
    ldr r0, =sector_io_count
    ldr r1, [r0]
    cmp r1, #2
    blo fail
    ldr r0, =sector_bitmap
    ldr r1, [r0]
    cmp r1, #3
    bne fail
    /* The first actual mapper result must equal the captured file LBA. */
    ldr r0, =fat_sector_seen
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =extent_result
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =extent_cluster
    ldr r1, [r0]
    ldr r2, =179788
    cmp r1, r2
    bne fail
    ldr r0, =sector_base_seen
    ldr r1, [r0]
    cmp r1, #1
    bne fail
    ldr r0, =sector_base_lba
    ldr r1, [r0]
    ldr r2, =0x002c5ca0
    cmp r1, r2
    bne fail
    ldr r0, =cache_timestamp
    ldr r1, [r0]
    cmp r1, #0
    beq fail
    /* The original allocator selects the last free node; the FAT reader
       releases it with clear-key set after copying the cached sector. */
    ldr r0, =cache_entry_1
    ldr r1, [r0, #8]
    cmp r1, #0
    bne fail
    ldr r1, [r0, #0x10]
    cmp r1, #0
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
    ldr r0, =failure_marker
    ldr r1, =0xbad00001
    str r1, [r0]
1:
    b 1b

.section .input_wire,"a",%progbits
.global input_wire
input_wire:
.incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-cache-alias-2026-10-31/candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin"

.section .parser_object,"aw",%progbits
.space 0x34
.word 0
.space 0x08

.section .state,"aw",%progbits
.align 2
string_dtor_called: .word 0
constructor_called: .word 0
parser_init_a_called: .word 0
parser_init_b_called: .word 0
parser_string_init_called: .word 0
path_create_called: .word 0
temp_destructor_called: .word 0
token_called: .word 0
loader_wrapper_count: .word 0
loader_wrapper_args: .word 0, 0, 0, 0
wire_offset: .word 0
parser_open_called: .word 0
open_called: .word 0
read_called: .word 0
read_call_count: .word 0
wrap_length_seen: .word 0
read_error_seen: .word 0
partial_copy_bytes: .word 0
cluster_slack_bytes: .word 0
stream_dispatch_count: .word 0
sector_io_count: .word 0
sector_base_seen: .word 0
sector_base_lba: .word 0
sector_bitmap: .word 0
fat_sector_seen: .word 0
extent_cluster: .word 0
extent_result: .word 0
pass_message: .ascii "PASS\n"
failure_marker: .word 0
fault_state: .space 0x18

.section .cache_globals,"aw",%progbits
.align 2
cache_pool_root: .word cache_entry
.space 0x14
cache_timestamp: .word 0
.space 4
cache_allocator_accumulator: .word 0

.section .global_string_object,"a",%progbits
.word 0
.word 0x08e58080

.include "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29/real-fat-entry-20261030/OSOS_accessories_parser_real_fat_entry_core_20261030.inc.S"

.section .stream_memcpy,"ax",%progbits
.arm
stream_memcpy_stub:
    cmp r2, #0
    bxeq lr
1:
    ldrb r3, [r1], #1
    strb r3, [r0], #1
    subs r2, r2, #1
    bne 1b
    bx lr

.section .runtime_081b832e,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x1b832e, 0x32

.section .runtime_0820cc90,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x20cc90, 0x78

.section .runtime_0823c9c0,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x23c9c0, 0x76

.section .runtime_082783be,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2783be, 0x18

.section .runtime_082a2c48,"ax",%progbits
.thumb
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x2a2c48, 0x2a

.section .parser_runtime_data,"aw",%progbits
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
candidate_file:
    .incbin "/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-cache-alias-2026-10-31/candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin"
    /* Guard space makes the modeled second 512-byte sector safe to copy. */
    .space 0x200
.align 4
 .section .stream_buffer_data,"aw",%progbits
stream_buffer:
    .space 0x8000
