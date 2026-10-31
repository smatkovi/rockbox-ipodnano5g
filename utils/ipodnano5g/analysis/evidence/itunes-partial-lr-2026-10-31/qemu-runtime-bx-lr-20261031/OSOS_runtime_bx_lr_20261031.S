.syntax unified
.cpu arm1176jzf-s
.arm

.section .vectors,"ax",%progbits
vectors:
    b runtime_start
    b undefined_handler
    b semihost_exit
    b prefetch_abort_handler
    b data_abort_handler
    b reserved_handler
    b reserved_handler
    b reserved_handler

.section .text,"ax",%progbits
.global runtime_start
runtime_start:
    bl low_vectors
    ldr r4, =0x295c             @ LDRBVC [r4,#-0x95c] accesses 0x2000
    ldr r5, =0x2000             @ mapped byte-store address
    mov r3, #0x3c               @ LDCLPL operand; skipped with N=1
    ldr lr, =thumb_return + 1   @ synthetic LR only for the rehost probe
    ldr r0, =path_buffer
    ldr r1, =0x80000000         @ N=1,V=0: parser-error hypothesis
    msr cpsr_f, r1
    bx r0                        @ even pointer enters ARM state

low_vectors:
    mrc p15, 0, r2, c1, c0, 0
    bic r2, r2, #0x2000         @ SCTLR.V=0: vectors at address zero
    mcr p15, 0, r2, c1, c0, 0
    mov r2, #0
    mcr p15, 0, r2, c7, c5, 4
    bx lr

undefined_handler:
    ldr sp, =0x7000
    ldr r1, =message_undefined
    b semihost_report

data_abort_handler:
    ldr sp, =0x7000
    ldr r1, =message_data_abort
    b semihost_report

prefetch_abort_handler:
    ldr sp, =0x7000
    ldr r1, =message_prefetch_abort
    b semihost_report

reserved_handler:
    ldr sp, =0x7000
    ldr r1, =message_unexpected

semihost_report:
    mov r0, #0x04               @ SYS_WRITE0
    svc #0x123456
    b semihost_exit

semihost_exit:
    ldr r1, =exit_block
    mov r0, #0x20               @ SYS_EXIT_EXTENDED
    svc #0x123456
1:
    b 1b

arm_runtime_return_report:
    ldr r1, =message_runtime_gadget_return
    b semihost_report

.section .path,"a",%progbits
.balign 4
path_buffer:
    .ascii "iPod_Control\\iTunes\\GeniusPlaylistABCDEF"
    .byte 0xe2, 0x80, 0x80, 0x4a, 0

.section .rodata,"a",%progbits
message_undefined:
    .asciz "UNDEFINED before the candidate runtime BX LR\n"
message_data_abort:
    .asciz "DATA_ABORT before the candidate runtime BX LR\n"
message_prefetch_abort:
    .asciz "PREFETCH_ABORT before the candidate runtime BX LR\n"
message_unexpected:
    .asciz "UNEXPECTED exception before the candidate runtime BX LR\n"
exit_block:
    .word 0x20026, 0

.section .thumb_probe,"ax",%progbits
.thumb
.thumb_func
.global thumb_return
thumb_return:
    ldr r3, =arm_runtime_return_report
    bx r3                        @ use ARM SVC semihosting for the report
2:
    b 2b

.section .rodata,"a",%progbits
message_runtime_gadget_return:
    .asciz "REAL OSOS IMAGE: BMI entered FUN_0818ece0; its BX LR epilog returned to the Thumb probe\n"
