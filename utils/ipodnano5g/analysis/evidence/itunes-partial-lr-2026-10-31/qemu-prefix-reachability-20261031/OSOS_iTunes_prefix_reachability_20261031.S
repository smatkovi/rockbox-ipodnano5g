.syntax unified
.cpu arm1176jzf-s
.arm

.section .vectors,"ax",%progbits
.global vectors
vectors:
    b success_start
    b undefined_handler
    b semihost_exit
    b prefetch_abort_handler
    b data_abort_handler
    b reserved_handler
    b reserved_handler
    b reserved_handler

.section .text,"ax",%progbits
.global success_start
.global error_store_start
.global error_branch_start
.global error_branch_back_start
.global error_branch_epoch_start
.global error_branch_zero_time_start

success_start:
    bl low_vectors
    bl load_common_registers
    ldr r0, =path_success
    mov r1, #0                  @ N=0,V=0: parser-success hypothesis
    msr cpsr_f, r1
    bx r0                        @ even pointer enters ARM state

error_store_start:
    bl low_vectors
    bl load_common_registers
    ldr r5, =0xf0000000         @ deliberately unmapped store address
    mov r8, #1                  @ identify the unmapped-store probe at the trap
    ldr r0, =path_error_branch
    mov r1, #0
    orr r1, r1, #0x80000000     @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0

error_branch_start:
    bl low_vectors
    bl load_common_registers
    ldr r5, =0x2000             @ mapped store address, permit branch test
    mov r8, #0
    ldr r0, =path_error_branch
    mov r1, #0
    orr r1, r1, #0x80000000     @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0

error_branch_back_start:
    bl low_vectors
    bl load_common_registers
    ldr r5, =0x2000
    mov r8, #2                  @ identify the UTF-8 backward-branch probe
    ldr r0, =path_error_branch_back
    mov r1, #0
    orr r1, r1, #0x80000000     @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0

error_branch_epoch_start:
    bl low_vectors
    ldr r4, =0x4b3d3b00         @ 2010-01-01 UTC as Unix seconds
    ldr r5, =0x2000
    mov r3, #0x3c
    mov r8, #3
    ldr r0, =path_error_branch
    mov r1, #0
    orr r1, r1, #0x80000000     @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0

error_branch_zero_time_start:
    bl low_vectors
    mov r4, #0                  @ parse-failure/default-output hypothesis
    ldr r5, =0x2000
    mov r3, #0x3c
    mov r8, #4
    ldr r0, =path_error_branch
    mov r1, #0
    orr r1, r1, #0x80000000     @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0

low_vectors:
    mrc p15, 0, r2, c1, c0, 0
    bic r2, r2, #0x2000         @ SCTLR.V=0: vectors at address zero
    mcr p15, 0, r2, c1, c0, 0
    mov r2, #0
    mcr p15, 0, r2, c7, c5, 4  @ ARMv6 prefetch flush / synchronization
    bx lr

load_common_registers:
    ldr r4, =0x295c             @ LDRBVC [r4,#-0x95c] accesses 0x2000
    ldr r5, =0x2000
    mov r3, #0x3c               @ register value used by LDCLPL at +0x10
    mov r1, #0
    bx lr

undefined_handler:
    ldr sp, =0x7000
    sub r2, lr, #4              @ ARM undefined LR points four bytes ahead
    ldr r3, =path_success
    add r3, r3, #0x10
    cmp r2, r3
    ldreq r1, =message_ldc_undefined
    beq undefined_report
    ldr r3, =branch_trap
    cmp r2, r3
    beq controlled_target_report
    ldr r3, =branch_trap_back
    cmp r2, r3
    beq controlled_target_report
    ldr r1, =message_other_undefined
    b undefined_report
controlled_target_report:
    cmp r8, #1
    ldreq r1, =message_unmapped_store_ignored
    beq undefined_report
    cmp r8, #2
    ldreq r1, =message_utf8_backward_target
    beq undefined_report
    cmp r8, #3
    ldreq r1, =message_epoch_load_ignored
    beq undefined_report
    cmp r8, #4
    ldreq r1, =message_zero_time_load_ignored
    beq undefined_report
    ldr r1, =message_controlled_target
undefined_report:
    bl write0
    b semihost_exit

data_abort_handler:
    ldr sp, =0x7000
    sub r2, lr, #8              @ ARM data-abort LR points eight bytes ahead
    ldr r3, =path_error_branch
    add r3, r3, #0x0c
    cmp r2, r3
    beq controlled_load_report
    ldr r3, =path_error_branch
    add r3, r3, #0x24
    cmp r2, r3
    ldreq r1, =message_suffix_store_abort
    ldrne r1, =message_other_data_abort
    bl write0
    b semihost_exit

controlled_load_report:
    cmp r8, #3
    ldreq r1, =message_epoch_load_abort
    cmp r8, #4
    ldreq r1, =message_zero_time_load_abort
    bl write0
    b semihost_exit

prefetch_abort_handler:
    ldr sp, =0x7000
    ldr r1, =message_prefetch_abort
    bl write0
    b semihost_exit

reserved_handler:
    ldr sp, =0x7000
    ldr r1, =message_unexpected
    bl write0
    b semihost_exit

write0:
    mov r0, #0x04               @ SYS_WRITE0
    svc #0x123456
    bx lr

semihost_exit:
    ldr r1, =exit_block
    mov r0, #0x20               @ SYS_EXIT_EXTENDED
    svc #0x123456
1:
    b 1b

.section .path_success,"a",%progbits
.balign 4
path_success:
    .ascii "iPod_Control\\iTunes\\GeniusPlaylistABCDEFGHIJKL"
    .byte 0

.section .path_error_branch,"a",%progbits
.balign 4
path_error_branch:
    @ Bytes 6..9 of the filename suffix form B.MI to branch_trap.
    .ascii "iPod_Control\\iTunes\\GeniusPlaylistABCDEFAAAJ"
    .byte 0

.section .path_error_branch_back,"a",%progbits
.balign 4
path_error_branch_back:
    @ E2 80 80 is UTF-8 U+2000; followed by J, these bytes form B.MI.
    .ascii "iPod_Control\\iTunes\\GeniusPlaylistABCDEF"
    .byte 0xe2, 0x80, 0x80, 0x4a, 0

.section .branch_trap,"ax",%progbits
.global branch_trap
branch_trap:
    .word 0xe7f000f0             @ ARM UDF #0, the expected branch target

.section .branch_trap_back,"ax",%progbits
.global branch_trap_back
branch_trap_back:
    .word 0xe7f000f0             @ ARM UDF #0, backward target in OSOS SDRAM

.section .rodata,"a",%progbits
message_ldc_undefined:
    .asciz "SUCCESS_FLAGS: LDCLPL at path+0x10 raised undefined instruction\n"
message_controlled_target:
    .asciz "ERROR_FLAGS: filename-controlled BMI reached the exact UDF target\n"
message_unmapped_store_ignored:
    .asciz "ERROR_FLAGS: QEMU ignored the unmapped STRBMI and reached the controlled BMI target\n"
message_utf8_backward_target:
    .asciz "ERROR_FLAGS: UTF-8 filename bytes directed BMI backward to 0x08700000\n"
message_epoch_load_ignored:
    .asciz "ERROR_FLAGS: QEMU unassigned read at 2010 Unix-time r4 did not stop BMI\n"
message_zero_time_load_ignored:
    .asciz "ERROR_FLAGS: QEMU unassigned read at zero r4 did not stop BMI\n"
message_other_undefined:
    .asciz "UNDEFINED: exception did not match either expected instruction\n"
message_suffix_store_abort:
    .asciz "ERROR_FLAGS: controlled STRBMI at path+0x24 raised a data abort\n"
message_epoch_load_abort:
    .asciz "ERROR_FLAGS: 2010 Unix-time r4 made LDRBVC at path+0x10 abort before BMI\n"
message_zero_time_load_abort:
    .asciz "ERROR_FLAGS: zero r4 made LDRBVC at path+0x10 abort before BMI\n"
message_other_data_abort:
    .asciz "DATA_ABORT: exception did not match the expected controlled store\n"
message_prefetch_abort:
    .asciz "PREFETCH_ABORT: branch left mapped test memory\n"
message_unexpected:
    .asciz "UNEXPECTED: reserved exception vector\n"
exit_block:
    .word 0x20026, 0
