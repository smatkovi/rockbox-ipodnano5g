#ifndef NAME_LEN
#define NAME_LEN 82
#endif
#ifndef EXPECTED_HEADER_WORD
#define EXPECTED_HEADER_WORD 0x00004141
#endif
#ifndef EXPECTED_FOLLOWUP_PTR
#define EXPECTED_FOLLOWUP_PTR 0x091ff7bc
#endif
#ifndef HEAP_BASE
#define HEAP_BASE 0x09000000
#endif
#ifndef HEAP_BYTES
#define HEAP_BYTES 0x001ff000
#endif
#ifndef ARENA_BYTES
#define ARENA_BYTES 0x00200000
#endif

.syntax unified
.cpu arm1176jzf-s
.equ MANAGER, 0x086cfb9c
.equ SIZE_OFF, 0x4140
.equ HANDLER_REGISTRY, 0x086ca7cc
.equ HANDLER_REGISTRY_SLOTS, 0x086ca800
.equ FREE_HDR, HEAP_BASE
.equ HEAP_SIZE, HEAP_BYTES
.equ HEAP_END, FREE_HDR + HEAP_SIZE

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr sp, =stack_top
    bl setup_allocator
#ifdef PREALLOC_APP_LAYOUT
    /* Aggregate the statically counted early-startup heap chunks, then model
       MainAppTask's separately allocated 0x20000-byte stack and 0x44-byte
       descriptor. This deliberately preserves total high-end geometry while
       omitting the individual earlier chunk boundaries. */
    bl preallocate_app_layout
    bl dump_startup_layout
#endif
#ifdef MODEL_STREAM_SLOT
    /* Rehost the one helper slot allocated by FUN_0819878c for the loader's
       open-mode-1, 0x400-byte stream. This models owned allocations, not the
       VFS open or the outer stream object. */
    bl model_stream_slot_prepare
#endif

    /* The loader receiver is created before XML parsing in the application
       path. Keep just the iPodSettings entry and its reuse lookup. */
    bl create_handler_from_registry
    cmp r0, #0
    beq fail_handler_registry

    /* FUN_08252bb8(sax=0, user=0, first=4 bytes, len=4, options=0). */
    sub sp, sp, #8
    mov r0, #0
    mov r1, #0
    ldr r2, =xml_input
    mov r3, #4
    mov r4, #0
    str r4, [sp]
    ldr r5, =0x08252bb9
    blx r5
    add sp, sp, #8
    cmp r0, #0
    beq fail_parser_create
    mov r4, r0

    /* Feed the remaining XML, then the original parser's final-chunk flag. */
    mov r0, r4
    ldr r1, =xml_input + 4
#ifdef LOADER_ROOT
    mov r2, #(2*NAME_LEN+38)
#else
    mov r2, #(2*NAME_LEN+9)
#endif
    mov r3, #0
    ldr r5, =0x082779c9
    blx r5
    cmp r0, #0
    bne fail_parse_chunk

    mov r0, r4
    mov r1, #0
    mov r2, #0
    mov r3, #1
    blx r5
    cmp r0, #0
    bne fail_parse_final

    /* The default SAX2 table should have built doc -> parent -> X. */
    ldr r0, [r4, #8]
    cmp r0, #0
    beq fail_no_document
    mov r1, #0
    mov r2, #1
    ldr r3, =0x0827f2f1
    blx r3
    cmp r0, #0
    beq fail_no_parent
#ifdef LOADER_ROOT
    /* Check the fixed loader root and select its child as the long parent. */
    mov r5, r0
    ldr r0, [r5, #8]
    ldr r1, =loader_root_name
    bl string_equal
    cmp r0, #1
    bne fail_root_name
    mov r0, r5
    mov r1, #0
    mov r2, #1
    ldr r3, =0x0827f2f1
    blx r3
    cmp r0, #0
    beq fail_no_parent
#endif
    mov r6, r0

    ldr r0, [r6, #8]
    bl string_length
    cmp r0, #NAME_LEN
    bne fail_parent_name

    mov r0, r6
    mov r1, #0
    mov r2, #1
    ldr r3, =0x0827f2f1
    blx r3
    cmp r0, #0
    beq fail_no_child
    mov r7, r0
    ldr r0, [r0, #8]
    ldrb r1, [r0]
    cmp r1, #0x58
    bne fail_child_name
    ldrb r1, [r0, #1]
    cmp r1, #0
    bne fail_child_name

    /* The loader fetches the child's text node before dispatching the name. */
    mov r0, r7
    ldr r3, =0x0827e817
    blx r3
    cmp r0, #0
    beq fail_child_value
    ldrb r1, [r0]
    cmp r1, #0x31
    bne fail_child_value

#if defined(LOADER_ROOT) && defined(MODEL_ROOT_FIRST_CALLBACK)
    /* Model the loader's earlier root -> long-child callback first. The
       long XML name is the right-hand component here, so its copy crosses
       the adjacent allocator header before the later long-child -> X pair. */
    push {r4-r8,lr}
    ldr r0, =callback_input
    ldr r1, =0x08059cd4
    ldr r2, [r5, #8]
    ldr r3, [r6, #8]
    ldr r12, =0x08195635
    blx r12
    pop {r4-r8,lr}
    ldr r0, =callback_input
    bl string_length
    cmp r0, #(NAME_LEN+13)
    bne fail_formatted_name
    ldr r1, =msg_root_first_callback
    mov r2, #msg_root_first_callback_len
    push {r4-r8,lr}
    bl write_text
    pop {r4-r8,lr}
    ldr r0, =handler_instance
    ldr r0, [r0]
    ldr r1, =callback_input
    bl run_callback
    bl dump_allocator_observation
#endif

    /* Use the loader's original varargs formatter and its "%s.%s" literal. */
    push {r4-r8,lr}
    ldr r0, =callback_input
    ldr r1, =0x08059cd4
    ldr r2, [r6, #8]
    ldr r3, [r7, #8]
    ldr r12, =0x08195635
    blx r12
    pop {r4-r8,lr}
    ldr r0, =callback_input
    bl string_length
    cmp r0, #(NAME_LEN+2)
    bne fail_formatted_name
    ldr r0, =callback_input
    ldrb r1, [r0, #NAME_LEN]
    cmp r1, #0x2e
    bne fail_formatted_name
    ldrb r1, [r0, #(NAME_LEN+1)]
    cmp r1, #0x58
    bne fail_formatted_name
    ldrb r1, [r0, #(NAME_LEN+2)]
    cmp r1, #0
    bne fail_formatted_name

    /* All parser, registry and callback allocations now use one synthetic
       free block through the original generic allocator. */
    ldr r0, =callback_alloc_count
    mov r1, #0
    str r1, [r0]
    ldr r0, =callback_ptrs
    mov r1, #0
    str r1, [r0]
    str r1, [r0, #4]
    str r1, [r0, #8]
    ldr r0, =neighbor_captured
    str r1, [r0]
    ldr r0, =handler_instance
    ldr r0, [r0]
    ldr r1, =callback_input
    bl run_callback
    bl dump_allocator_observation

    ldr r0, =callback_alloc_count
    ldr r1, [r0]
    cmp r1, #3
    bne fail_callback_alloc
    ldr r0, =neighbor_during_free
    ldr r1, [r0]
    ldr r2, =EXPECTED_HEADER_WORD
    cmp r1, r2
    bne fail_callback_overwrite
    ldr r0, =neighbor_owner_before
    ldr r1, [r0]
    cmp r1, #3
    bne fail_callback_overwrite
    ldr r0, =neighbor_before
    ldr r1, [r0]
    cmp r1, #0x58
    bne fail_callback_overwrite
    ldr r0, =callback_ptrs
    ldr r1, [r0]
    sub r1, r1, #8
    ldr r0, [r0, #4]
    add r0, r0, #0x50
    cmp r0, r1
    bne fail_callback_overwrite

    /* Mirror the loader's sibling advances after one parent/child pair. */
    mov r0, r7
    ldr r3, =0x0827e801
    blx r3
    cmp r0, #0
    bne fail_extra_child
    mov r0, r6
    ldr r3, =0x0827e801
    blx r3
    cmp r0, #0
    bne fail_extra_parent

#ifdef MODEL_DOCUMENT_CLEANUP
    /* FUN_08059ab0 destroys the parsed document after its callback loop.
       r4 is the original pushparser and [r4+8] is its document root. Disable
       the optional external cleanup hook; this QEMU harness has no provider
       for its runtime-resolved callback. */
    ldr r0, =0x086724d8
    mov r1, #0
    str r1, [r0]
    ldr r0, [r4, #8]
    ldr r12, =0x0827ec11
    blx r12
#endif
#ifdef MODEL_STREAM_SLOT
    /* The real stream cleanup frees this vector after document cleanup.
       Invoke only the vector destructor; the VFS close and surrounding
       FUN_081ada78 state transitions remain outside this harness. */
    ldr r0, =stream_model + 0x40
    ldr r12, =0x08281cf5
    blx r12
#endif

    /* Reuse the original generic allocator on the manager after the three
       callback frees. This makes the corrupted geometry observable as a
       follow-up allocation result. */
    ldr r0, =MANAGER
    mov r1, #0x50
    mov r2, #0
    mov r3, #0
    ldr r12, =0x08020df5
    blx r12
    ldr r1, =followup_alloc_ptr
    str r0, [r1]
    cmp r0, #0
    beq fail_followup_alloc
    bl dump_followup_observation
    ldr r1, =EXPECTED_FOLLOWUP_PTR
    ldr r0, =followup_alloc_ptr
    ldr r0, [r0]
    cmp r0, r1
    bne fail_followup_ptr
#ifdef MODEL_POSTALLOC_SWEEP
    /* After the baseline 0x50 allocation, ask the original allocator for a
       fixed set of sizes. Print each size/result immediately so a later
       allocator fault still leaves the preceding observations in stdout. */
    ldr r1, =msg_postalloc
    mov r2, #msg_postalloc_len
    bl write_text
    ldr r6, =postalloc_sizes
    mov r5, #9
.Lpostalloc_loop:
    ldr r0, [r6]
    bl write_hex_word
    ldr r1, [r6], #4
    ldr r0, =MANAGER
    mov r2, #0
    mov r3, #0
    ldr r12, =0x08020df5
    blx r12
    bl write_hex_word
    subs r5, r5, #1
    bne .Lpostalloc_loop
    ldr r1, =msg_newline
    mov r2, #1
    bl write_text
#endif
#ifdef ASSERT_FOLLOWUP_IN_APP_STACK
    ldr r1, =startup_stack_ptr
    ldr r1, [r1]
    cmp r0, r1
    blo fail_followup_ptr
    add r1, r1, #0x20000
    cmp r0, r1
    bhs fail_followup_ptr
#endif

    ldr r1, =msg_pass
    mov r2, #msg_pass_len
    b write_exit_zero

fail_parser_create:
    ldr r1, =msg_create
    mov r2, #msg_create_len
    b write_exit_fail
fail_parse_chunk:
    ldr r1, =msg_chunk
    mov r2, #msg_chunk_len
    b write_exit_fail
fail_parse_final:
    ldr r1, =msg_final
    mov r2, #msg_final_len
    b write_exit_fail
fail_no_document:
    ldr r1, =msg_document
    mov r2, #msg_document_len
    b write_exit_fail
fail_no_parent:
    ldr r1, =msg_parent
    mov r2, #msg_parent_len
    b write_exit_fail
fail_root_name:
    ldr r1, =msg_root_name
    mov r2, #msg_root_name_len
    b write_exit_fail
fail_parent_name:
    ldr r1, =msg_parent_name
    mov r2, #msg_parent_name_len
    b write_exit_fail
fail_no_child:
    ldr r1, =msg_child
    mov r2, #msg_child_len
    b write_exit_fail
fail_child_name:
    ldr r1, =msg_child_name
    mov r2, #msg_child_name_len
    b write_exit_fail
fail_child_value:
    ldr r1, =msg_child_value
    mov r2, #msg_child_value_len
    b write_exit_fail
fail_callback_alloc:
    ldr r1, =msg_callback_alloc
    mov r2, #msg_callback_alloc_len
    b write_exit_fail
fail_callback_overwrite:
    ldr r1, =msg_callback_overwrite
    mov r2, #msg_callback_overwrite_len
    b write_exit_fail
fail_formatted_name:
    ldr r1, =msg_formatted_name
    mov r2, #msg_formatted_name_len
    b write_exit_fail
fail_followup_alloc:
    ldr r1, =msg_followup_alloc
    mov r2, #msg_followup_alloc_len
    b write_exit_fail
fail_followup_ptr:
    ldr r1, =msg_followup_ptr
    mov r2, #msg_followup_ptr_len
    b write_exit_fail
fail_extra_child:
    ldr r1, =msg_extra_child
    mov r2, #msg_extra_child_len
    b write_exit_fail
fail_extra_parent:
    ldr r1, =msg_extra_parent
    mov r2, #msg_extra_parent_len
    b write_exit_fail
fail_handler_registry:
    ldr r1, =msg_handler_registry
    mov r2, #msg_handler_registry_len
    b write_exit_fail

write_exit_zero:
    mov r0, #1
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0
write_exit_fail:
    mov r0, #2
    mov r7, #4
    svc #0
    mov r0, #1
    mov r7, #1
    svc #0
.size _start, .-_start
.ltorg

.section .harness_text,"ax",%progbits
.arm
.type seed_shared_heap,%function
seed_shared_heap:
    push {r4-r6,lr}
    ldr r0, =0x086cf000
    ldr r1, =0x2000
    mov r2, #0
.Lclear_manager:
    str r2, [r0], #4
    subs r1, r1, #4
    bne .Lclear_manager
    /* Match the runtime's actual region-registration path. The manager's
       vtable is DAT_08264a24; slot +0x14 is original FUN_0802502a. */
    ldr r0, =MANAGER
    ldr r1, =0x08535b3c
    str r1, [r0]
    ldr r0, =MANAGER
    ldr r1, =FREE_HDR
    ldr r2, =HEAP_SIZE
    mov r3, #0
    ldr r12, =0x08020ecd
    blx r12
    pop {r4-r6,pc}
.size seed_shared_heap, .-seed_shared_heap

.type setup_allocator,%function
setup_allocator:
    push {r4,lr}
    ldr r0, =0x08278fa0
    ldr r1, =0x47702000
    str r1, [r0]
    bl seed_shared_heap
    ldr r0, =0x0855132c
    ldr r1, =MANAGER
    str r1, [r0]
    ldr r0, =callback_alloc_count
    mov r1, #0
    str r1, [r0]
    ldr r0, =realloc_count
    str r1, [r0]
    ldr r0, =callback_ptrs
    str r1, [r0]
    str r1, [r0, #4]
    str r1, [r0, #8]

    /* Parser library allocation callbacks share the OSOS allocator wrappers. */
    ldr r0, =0x08672534
    ldr r1, =0x0818ea2d
    str r1, [r0]
    ldr r0, =0x08672530
    ldr r1, =0x0818e7a9
    str r1, [r0]
    ldr r0, =0x08672538
    ldr r1, =0x0818ea2d
    str r1, [r0]
    ldr r0, =0x0867253c
    ldr r1, =shared_realloc
    str r1, [r0]

    /* Keep the size/class ABI but replace OS locks with the single-threaded
       QEMU model and send both wrapper classes to the original generic heap. */
    ldr r0, =0x081935bc
    ldr r1, =0x47184b00
    str r1, [r0]
    ldr r1, =shared_alloc
    str r1, [r0, #4]
    ldr r0, =0x0819af00
    ldr r1, =0x47184b00
    str r1, [r0]
    ldr r1, =shared_free
    str r1, [r0, #4]
    pop {r4,pc}
.size setup_allocator, .-setup_allocator

#ifdef PREALLOC_APP_LAYOUT
.type preallocate_app_layout,%function
preallocate_app_layout:
    push {r4,lr}
    ldr r0, =MANAGER
    ldr r1, =0x1eac0
    mov r2, #0
    mov r3, #0
    ldr r12, =0x08020df5
    blx r12
    ldr r1, =startup_misc_ptr
    str r0, [r1]

    ldr r0, =MANAGER
    ldr r1, =0x20000
    mov r2, #0
    mov r3, #0
    ldr r12, =0x08020df5
    blx r12
    ldr r1, =startup_stack_ptr
    str r0, [r1]

    ldr r0, =MANAGER
    ldr r1, =0x44
    mov r2, #0
    mov r3, #0
    ldr r12, =0x08020df5
    blx r12
    ldr r1, =startup_task_descriptor_ptr
    str r0, [r1]
    pop {r4,pc}
.size preallocate_app_layout, .-preallocate_app_layout

.type dump_startup_layout,%function
dump_startup_layout:
    push {r4,lr}
    ldr r1, =msg_startup_layout
    mov r2, #msg_startup_layout_len
    bl write_text
    ldr r0, =startup_misc_ptr
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =startup_stack_ptr
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =startup_stack_ptr
    ldr r0, [r0]
    add r0, r0, #0x20000
    bl write_hex_word
    ldr r0, =startup_task_descriptor_ptr
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =HEAP_END
    bl write_hex_word
    ldr r1, =msg_newline
    mov r2, #1
    bl write_text
    pop {r4,pc}
.size dump_startup_layout, .-dump_startup_layout
#endif

#ifdef MODEL_STREAM_SLOT
.type model_stream_slot_prepare,%function
model_stream_slot_prepare:
    push {r4,lr}
    ldr r4, =stream_model
    mov r1, #0
    str r1, [r4, #4]
    str r1, [r4, #0x28]
    ldr r1, =0x400
    str r1, [r4, #0x2c]
    mov r1, #1
    str r1, [r4, #0x30]
    add r0, r4, #0x40
    mov r1, r4
    ldr r12, =0x0822491d
    blx r12
    pop {r4,pc}
.size model_stream_slot_prepare, .-model_stream_slot_prepare
#endif

.type arena_alloc,%function
arena_alloc:
    push {r4-r7,lr}
    ldr r5, =allocator_mode
    ldr r6, [r5]
    cmp r6, #0
    bne .Lcallback_alloc
    mov r4, r0
    add r4, r4, #7
    bic r4, r4, #7
    cmp r4, #8
    movlo r4, #8
    ldr r5, =arena_cursor
    ldr r6, [r5]
    add r7, r6, #8
    str r4, [r6]
    ldr r0, =0x0000584d
    str r0, [r6, #4]
    add r6, r7, r4
    str r6, [r5]
    mov r0, r7
    mov r1, #0
    mov r2, r4
.Lzero_alloc:
    cmp r2, #0
    beq .Lalloc_done
    strb r1, [r7], #1
    subs r2, r2, #1
    bne .Lzero_alloc
.Lalloc_done:
    pop {r4-r7,pc}
.Lcallback_alloc:
    ldr r5, =callback_alloc_count
    ldr r6, [r5]
    add r6, r6, #1
    str r6, [r5]
    cmp r6, #1
    beq .Lcallback_first
    cmp r6, #2
    beq .Lcallback_second
    cmp r6, #3
    beq .Lcallback_third
    mov r0, #0
    b .Lcallback_alloc_done
.Lcallback_first:
    ldr r0, =HIGH_HDR + 8
    b .Lcallback_alloc_done
.Lcallback_second:
    ldr r0, =LOW_HDR + 8
    b .Lcallback_alloc_done
.Lcallback_third:
    ldr r0, =TEMP_HDR + 8
.Lcallback_alloc_done:
    pop {r4-r7,pc}
.size arena_alloc, .-arena_alloc

.type arena_free,%function
arena_free:
    bx lr
.size arena_free, .-arena_free

.type shared_alloc,%function
shared_alloc:
    push {r4-r7,lr}
    mov r4, r0
    mov r5, r1
    ldr r0, =MANAGER
    mov r1, r4
    mov r2, r5
    ldr r12, =0x08020df5
    blx r12
    mov r6, r0
    cmp r5, #3
    bne .Lshared_alloc_done
    ldr r7, =callback_alloc_count
    ldr r0, [r7]
    cmp r0, #3
    bhs .Lshared_alloc_done
    ldr r1, =callback_ptrs
    str r6, [r1, r0, lsl #2]
    add r0, r0, #1
    str r0, [r7]
    cmp r0, #2
    bne .Lshared_alloc_done
    add r1, r6, #0x50
    ldr r2, [r1]
    ldr r3, =neighbor_before
    str r2, [r3]
    ldrh r2, [r1, #4]
    ldr r3, =neighbor_owner_before
    str r2, [r3]
    ldr r1, =callback_ptrs
    ldr r1, [r1]
    add r1, r1, #0x50
    ldr r2, [r1]
    ldr r3, =neighbor_high_before
    str r2, [r3]
.Lshared_alloc_done:
    mov r0, r6
    pop {r4-r7,pc}
.size shared_alloc, .-shared_alloc

.type shared_free,%function
shared_free:
    push {r4-r6,lr}
    mov r4, r0
    mov r5, r1
    cmp r5, #3
    bne .Lshared_free_call
    ldr r6, =callback_alloc_count
    ldr r6, [r6]
    cmp r6, #3
    bne .Lshared_free_call
    ldr r6, =neighbor_captured
    ldr r6, [r6]
    cmp r6, #0
    bne .Lshared_free_call
    ldr r6, =callback_ptrs
    ldr r6, [r6, #4]
    add r6, r6, #0x50
    ldr r6, [r6]
    ldr r3, =neighbor_during_free
    str r6, [r3]
    ldr r6, =callback_ptrs
    ldr r6, [r6]
    add r6, r6, #0x50
    ldr r6, [r6]
    ldr r3, =neighbor_high_during
    str r6, [r3]
    ldr r6, =neighbor_captured
    mov r3, #1
    str r3, [r6]
.Lshared_free_call:
    ldr r0, =MANAGER
    mov r1, r4
    ldr r12, =0x0802502b
    blx r12
    pop {r4-r6,pc}
.size shared_free, .-shared_free

.type shared_realloc,%function
shared_realloc:
    push {r4-r8,lr}
    mov r4, r0
    mov r5, r1
    ldr r0, =realloc_count
    ldr r1, [r0]
    add r1, r1, #1
    str r1, [r0]
    cmp r4, #0
    beq .Lshared_realloc_alloc
    cmp r5, #0
    beq .Lshared_realloc_free
    ldr r6, [r4, #-8]
    and r6, r6, #0xfffffffc
    sub r6, r6, #8
    mov r0, r5
    mov r1, #1
    bl shared_alloc
    mov r7, r0
    cmp r7, #0
    beq .Lshared_realloc_done
    cmp r6, r5
    movhi r6, r5
    mov r0, r4
    mov r1, r7
    mov r2, r6
    mov r0, r4
    mov r1, r7
.Lshared_realloc_copy:
    cmp r6, #0
    beq .Lshared_realloc_copied
    ldrb r2, [r0], #1
    strb r2, [r1], #1
    subs r6, r6, #1
    bne .Lshared_realloc_copy
.Lshared_realloc_copied:
    mov r0, r4
    bl shared_free
    mov r0, r7
    b .Lshared_realloc_done
.Lshared_realloc_alloc:
    mov r0, r5
    mov r1, #1
    bl shared_alloc
    b .Lshared_realloc_done
.Lshared_realloc_free:
    mov r0, r4
    bl shared_free
    mov r0, #0
.Lshared_realloc_done:
    pop {r4-r8,pc}
.size shared_realloc, .-shared_realloc

.type dump_allocator_observation,%function
dump_allocator_observation:
    push {r4-r7,lr}
    ldr r1, =msg_allocator_observation
    mov r2, #msg_allocator_observation_len
    bl write_text
    ldr r0, =callback_ptrs
    ldr r4, [r0]
    ldr r5, [r0, #4]
    mov r0, r4
    bl write_hex_word
    mov r0, r5
    bl write_hex_word
    add r0, r5, #0x50
    bl write_hex_word
    ldr r6, [r5, #0x50]
    ldr r1, =neighbor_after
    str r6, [r1]
    ldr r0, =neighbor_before
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =neighbor_owner_before
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =neighbor_during_free
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =neighbor_after
    ldr r0, [r0]
    bl write_hex_word
    add r6, r4, #0x50
    ldr r0, [r6]
    ldr r1, =neighbor_high_after
    str r0, [r1]
    mov r0, r6
    bl write_hex_word
    ldr r0, =neighbor_high_before
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =neighbor_high_during
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =neighbor_high_after
    ldr r0, [r0]
    bl write_hex_word
    ldr r1, =msg_newline
    mov r2, #1
    bl write_text
    pop {r4-r7,pc}
.size dump_allocator_observation, .-dump_allocator_observation

.type dump_followup_observation,%function
dump_followup_observation:
    push {r4-r7,lr}
    ldr r1, =msg_followup_observation
    mov r2, #msg_followup_observation_len
    bl write_text
    ldr r0, =followup_alloc_ptr
    ldr r4, [r0]
    mov r0, r4
    bl write_hex_word
    sub r0, r4, #8
    ldr r0, [r0]
    bl write_hex_word
    ldr r0, =HEAP_END
    bl write_hex_word
    sub r0, r4, #0
    ldr r1, =HEAP_END
    sub r0, r0, r1
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0xac]
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0xb4]
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0xc0]
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0x398]
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0x3b8]
    bl write_hex_word
    ldr r0, =MANAGER
    ldr r0, [r0, #0x3fc]
    bl write_hex_word
    ldr r0, =realloc_count
    ldr r0, [r0]
    bl write_hex_word
    ldr r1, =msg_newline
    mov r2, #1
    bl write_text
    pop {r4-r7,pc}
.size dump_followup_observation, .-dump_followup_observation

.type write_hex_word,%function
write_hex_word:
    push {r4-r7,lr}
    mov r4, r0
    ldr r5, =hex_buffer
    mov r6, #8
.Lhex_digit:
    mov r7, r4, lsr #28
    cmp r7, #9
    addls r7, r7, #48
    addhi r7, r7, #55
    strb r7, [r5], #1
    lsl r4, r4, #4
    subs r6, r6, #1
    bne .Lhex_digit
    mov r0, #1
    ldr r1, =hex_buffer
    mov r2, #8
    mov r7, #4
    svc #0
    mov r0, #1
    ldr r1, =hex_space
    mov r2, #1
    mov r7, #4
    svc #0
    pop {r4-r7,pc}
.size write_hex_word, .-write_hex_word

.type write_text,%function
write_text:
    push {r4,lr}
    mov r0, #1
    mov r7, #4
    svc #0
    pop {r4,pc}
.size write_text, .-write_text

.thumb
.thumb_func
stub_free:
    push {r4,lr}
    mov r4, r0
    ldr r1, =TEMP_HDR + 8
    cmp r4, r1
    beq .Lstub_free_call
    ldr r1, =free_first_ptr
    ldr r2, [r1]
    cmp r2, #0
    bne .Lstub_free_call
    str r4, [r1]
    ldr r1, =free_first_header
    ldr r2, =HIGH_HDR
    ldr r2, [r2]
    str r2, [r1]
.Lstub_free_call:
    mov r1, r4
    ldr r0, =MANAGER
    ldr r3, =0x0802502b
    blx r3
    pop {r4,pc}
.arm

.type arena_realloc,%function
arena_realloc:
    push {r4-r7,lr}
    mov r4, r0
    mov r5, r1
    mov r0, r5
    bl arena_alloc
    mov r6, r0
    cmp r4, #0
    beq .Lrealloc_done
    ldr r2, [r4, #-8]
    cmp r2, r5
    movhi r2, r5
    mov r7, r6
.Lrealloc_copy:
    cmp r2, #0
    beq .Lrealloc_done
    ldrb r3, [r4], #1
    strb r3, [r7], #1
    subs r2, r2, #1
    bne .Lrealloc_copy
.Lrealloc_done:
    mov r0, r6
    pop {r4-r7,pc}
.size arena_realloc, .-arena_realloc

.type string_length,%function
string_length:
    mov r1, r0
    mov r0, #0
.Lstrlen_loop:
    ldrb r2, [r1, r0]
    cmp r2, #0
    bxeq lr
    add r0, r0, #1
    b .Lstrlen_loop
.size string_length, .-string_length

.type string_equal,%function
string_equal:
    push {r4,lr}
    mov r2, r0
    mov r3, r1
.Lstring_equal_loop:
    ldrb r0, [r2], #1
    ldrb r1, [r3], #1
    cmp r0, r1
    bne .Lstring_not_equal
    cmp r0, #0
    bne .Lstring_equal_loop
    mov r0, #1
    pop {r4,pc}
.Lstring_not_equal:
    mov r0, #0
    pop {r4,pc}
.size string_equal, .-string_equal

.type create_handler_from_registry,%function
create_handler_from_registry:
    push {r4-r6,lr}
    /* Vector layout inferred from FUN_08239050/FUN_08245a76. */
    ldr r0, =HANDLER_REGISTRY
    ldr r1, =HANDLER_REGISTRY_SLOTS
    str r1, [r0]
    str r1, [r0, #4]
    add r2, r1, #16
    str r2, [r0, #8]
    mov r2, #0
    str r2, [r1]
    str r2, [r1, #4]
    str r2, [r1, #8]
    str r2, [r1, #12]

    ldr r0, =factory_key_a
    ldr r12, =0x08239051
    blx r12
    cmp r0, #0
    beq .Lregistry_fail
    mov r4, r0
    ldr r1, [r0, #0x80]
    ldr r2, =factory_key_a
    cmp r1, r2
    bne .Lregistry_fail
    ldr r0, =HANDLER_REGISTRY
    ldr r1, [r0, #4]
    ldr r2, =HANDLER_REGISTRY_SLOTS + 4
    cmp r1, r2
    bne .Lregistry_fail
    ldr r1, [r2, #-4]
    cmp r1, r4
    bne .Lregistry_fail

    /* The loader's fixed key must resolve and then be reusable. */
    ldr r0, =factory_key_a
    ldr r12, =0x08239051
    blx r12
    cmp r0, r4
    bne .Lregistry_fail
    ldr r0, =HANDLER_REGISTRY
    ldr r1, [r0, #4]
    ldr r2, =HANDLER_REGISTRY_SLOTS + 4
    cmp r1, r2
    bne .Lregistry_fail
    ldr r0, =handler_instance
    str r4, [r0]
    ldr r1, [r4]
    ldr r1, [r1, #0x64]
    ldr r2, =0x08063699
    cmp r1, r2
    bne .Lregistry_fail
    mov r0, #1
    pop {r4-r6,pc}
.Lregistry_fail:
    mov r0, #0
    pop {r4-r6,pc}
.size create_handler_from_registry, .-create_handler_from_registry

.type run_callback,%function
run_callback:
    push {r4-r7,lr}
    mov r4, r0
    mov r5, r1
    ldr r2, [r4]
    ldr r6, [r2, #0x64]
    mov r0, r4
    mov r1, r5
    mov r2, #0
    mov r3, #0
    blx r6
    pop {r4-r7,pc}
.ltorg

.section .xml_input,"a",%progbits
.macro qname_bytes
#ifdef NAME_MIDPATCH4
/* Optional four-byte QName patch window for deterministic malformed-chunk
   probes; the normal fixture remains all-A or NAME_TAIL4. */
#ifndef NAME_MIDPATCH_AT
#define NAME_MIDPATCH_AT 40
#endif
    .rept NAME_MIDPATCH_AT
    .byte 0x41
    .endr
    .byte (NAME_MIDPATCH4 & 0xff)
    .byte ((NAME_MIDPATCH4 >> 8) & 0xff)
    .byte ((NAME_MIDPATCH4 >> 16) & 0xff)
    .byte ((NAME_MIDPATCH4 >> 24) & 0xff)
#ifdef NAME_TAIL4
    .rept NAME_LEN - NAME_MIDPATCH_AT - 8
    .byte 0x41
    .endr
    .byte (NAME_TAIL4 & 0xff)
    .byte ((NAME_TAIL4 >> 8) & 0xff)
    .byte ((NAME_TAIL4 >> 16) & 0xff)
    .byte ((NAME_TAIL4 >> 24) & 0xff)
#else
    .rept NAME_LEN - NAME_MIDPATCH_AT - 4
    .byte 0x41
    .endr
#endif
#elif defined(NAME_TAIL4)
    .rept NAME_LEN - 4
    .byte 0x41
    .endr
    .byte (NAME_TAIL4 & 0xff)
    .byte ((NAME_TAIL4 >> 8) & 0xff)
    .byte ((NAME_TAIL4 >> 16) & 0xff)
    .byte ((NAME_TAIL4 >> 24) & 0xff)
#elif defined(NAME_TAIL3)
    .rept NAME_LEN - 3
    .byte 0x41
    .endr
    .byte (NAME_TAIL3 & 0xff)
    .byte ((NAME_TAIL3 >> 8) & 0xff)
    .byte ((NAME_TAIL3 >> 16) & 0xff)
#else
    .rept NAME_LEN
    .byte 0x41
    .endr
#endif
.endm
xml_input:
#ifdef LOADER_ROOT
    .ascii "<iPodSettings><"
#else
    .ascii "<"
#endif
    qname_bytes
    .ascii "><X>1</X></"
    qname_bytes
#ifdef LOADER_ROOT
    .ascii "></iPodSettings>"
#else
    .ascii ">"
#endif
xml_input_end:

.section .messages,"a",%progbits
msg_pass:        .ascii "PASS: parser and callback used one seeded manager and original generic alloc/free\n"
.equ msg_pass_len, .-msg_pass
msg_create:      .ascii "FAIL: parser constructor\n"
.equ msg_create_len, .-msg_create
msg_chunk:       .ascii "FAIL: parser data chunk\n"
.equ msg_chunk_len, .-msg_chunk
msg_final:       .ascii "FAIL: parser final chunk\n"
.equ msg_final_len, .-msg_final
msg_document:    .ascii "FAIL: no document tree\n"
.equ msg_document_len, .-msg_document
msg_parent:      .ascii "FAIL: no parent element\n"
.equ msg_parent_len, .-msg_parent
msg_root_name:   .ascii "FAIL: loader root name is not iPodSettings\n"
.equ msg_root_name_len, .-msg_root_name
msg_parent_name: .ascii "FAIL: parent QName length is not 82\n"
.equ msg_parent_name_len, .-msg_parent_name
msg_child:       .ascii "FAIL: no child element\n"
.equ msg_child_len, .-msg_child
msg_child_name:  .ascii "FAIL: child QName is not X\n"
.equ msg_child_name_len, .-msg_child_name
msg_child_value: .ascii "FAIL: child text is not 1\n"
.equ msg_child_value_len, .-msg_child_value
msg_callback_alloc: .ascii "FAIL: callback allocation sequence\n"
.equ msg_callback_alloc_len, .-msg_callback_alloc
msg_callback_overwrite: .ascii "FAIL: callback did not alter adjacent size word\n"
.equ msg_callback_overwrite_len, .-msg_callback_overwrite
msg_formatted_name: .ascii "FAIL: original formatter output\n"
.equ msg_formatted_name_len, .-msg_formatted_name
msg_followup_alloc: .ascii "FAIL: original allocator follow-up allocation\n"
.equ msg_followup_alloc_len, .-msg_followup_alloc
msg_followup_ptr: .ascii "FAIL: original allocator follow-up pointer\n"
.equ msg_followup_ptr_len, .-msg_followup_ptr
msg_extra_child: .ascii "FAIL: unexpected next child element\n"
.equ msg_extra_child_len, .-msg_extra_child
msg_extra_parent: .ascii "FAIL: unexpected next parent element\n"
.equ msg_extra_parent_len, .-msg_extra_parent
msg_handler_registry: .ascii "FAIL: original settings handler registry factory\n"
.equ msg_handler_registry_len, .-msg_handler_registry
msg_allocator_observation: .ascii "buf1 buf2 low_target low_before owner low_during low_after high_target high_before high_during high_after: "
.equ msg_allocator_observation_len, .-msg_allocator_observation
msg_followup_observation: .ascii "followup_ptr header heap_end ptr_delta free_head mgr_b4 mgr_c0 bin6 bin14 bin31 reallocs: "
.equ msg_followup_observation_len, .-msg_followup_observation
#ifdef MODEL_POSTALLOC_SWEEP
msg_postalloc: .ascii "size->ptr followup allocations: "
.equ msg_postalloc_len, .-msg_postalloc
#endif
msg_startup_layout: .ascii "startup_misc stack_payload stack_top task_descriptor heap_end: "
.equ msg_startup_layout_len, .-msg_startup_layout
msg_root_first_callback: .ascii "loader root -> long child callback: "
.equ msg_root_first_callback_len, .-msg_root_first_callback
msg_newline: .ascii "\n"

.section .harness_data,"aw",%progbits
.align 2
arena_cursor: .word 0
allocator_mode: .word 0
#ifdef MODEL_STREAM_SLOT
.align 2
stream_model: .space 0x80
#endif
callback_alloc_count: .word 0
realloc_count: .word 0
callback_ptrs: .space 12
neighbor_before: .word 0
neighbor_owner_before: .word 0
neighbor_during_free: .word 0
neighbor_captured: .word 0
neighbor_after: .word 0
neighbor_high_before: .word 0
neighbor_high_during: .word 0
neighbor_high_after: .word 0
hex_buffer: .space 8
hex_space: .ascii " "
free_first_ptr: .word 0
free_first_header: .word 0
followup_alloc_ptr: .word 0
#ifdef MODEL_POSTALLOC_SWEEP
.align 2
postalloc_sizes: .word 0x10,0x20,0x40,0x50,0x80,0x100,0x200,0x400,0x1000
#endif
#ifdef PREALLOC_APP_LAYOUT
startup_misc_ptr: .word 0
startup_stack_ptr: .word 0
startup_task_descriptor_ptr: .word 0
#endif
handler_instance: .word 0
#ifdef LOADER_ROOT
factory_key_a: .asciz "iPodSettings"
#else
factory_key_a: .asciz "DeviceSettingsA"
#endif
factory_key_b: .asciz "DeviceSettingsB"
callback_input: .space 0x100
loader_root_name: .asciz "iPodSettings"

.equ LOW_HDR, 0x0910ffa8
.equ HIGH_HDR, 0x09110000
.equ TEMP_HDR, LOW_HDR - 0x60

.section .external_data,"aw",%progbits
external_data_start:
    .space 0x0d78
    .word charset_case_table
    .space 0x1000 - (. - external_data_start)
charset_case_table:
    .rept 0x61
    .byte 0
    .endr
    .rept 26
    .byte 0x80
    .endr
    .rept 0x100 - 0x7b
    .byte 0
    .endr

.section .runtime,"awx",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin"

.section .manager,"aw",%nobits
.space 0x2000

.section .registry,"aw",%nobits
.space 0x7cc
handler_registry_host: .space 0x0c
.space 0x28
handler_registry_slots_host: .space 0x10
.space 0x7f0

.section .arena,"aw",%nobits
.space ARENA_BYTES

.section .stack,"aw",%nobits
.space 0x10000
stack_top:

.section .ext,"ax",%progbits
.arm
ext_start:
    .space 0x74
ext_external_heap_hook_74:
    bx lr
    .space 0xb4 - (. - ext_start)
ext_memcpy_b4:
    b ext_memcpy_common
    .space 0x198 - (. - ext_start)
ext_memset_198:
    b ext_memset_common
    .space 0x1ec - (. - ext_start)
ext_memcpy_1ec:
    b ext_memcpy_common
    .space 0x274 - (. - ext_start)
ext_memcpy_274:
    b ext_memcpy_common
    .space 0x3144 - (. - ext_start)
.thumb
.thumb_func
ext_ref_3144:
    bx lr
    .space 0x3156 - (. - ext_start)
.thumb
.thumb_func
ext_release_3156:
    bx lr
.arm

ext_memcpy_common:
    mov r3, r0
    cmp r2, #0
    beq .Lcopy_done
.Lcopy_loop:
    ldrb r12, [r1], #1
    strb r12, [r0], #1
    subs r2, r2, #1
    bne .Lcopy_loop
.Lcopy_done:
    mov r0, r3
    bx lr

ext_memset_common:
    mov r3, r0
    uxtb r1, r1
    cmp r2, #0
    beq .Lset_done
.Lset_loop:
    strb r1, [r0], #1
    subs r2, r2, #1
    bne .Lset_loop
.Lset_done:
    mov r0, r3
    bx lr

/* Minimal host stand-in for the OS task-info import used by the real
   handler constructor: operation 1 writes a nonzero synthetic task ID. */
.space 0x53f0 - (. - ext_start)
ext_task_info_53f0:
    mov r2, #1
    str r2, [r1]
    mov r0, #0
    bx lr
.space 0x573c - (. - ext_start)
ext_lock_573c:
    mov r0, #0
    bx lr
.space 0x5a14 - (. - ext_start)
ext_unlock_5a14:
    mov r0, #0
    bx lr

