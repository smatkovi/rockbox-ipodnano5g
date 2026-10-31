.syntax unified
.arm
.section .text, "ax", %progbits
.global _start
.type _start, %function
_start:
    ldr sp, =stack_top

    /* Poison the real bootloader BSS range before calling its raw-code routine. */
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
    ldr r2, =0xa5a5a5a5
1:
    str r2, [r0], #4
    cmp r0, r1
    blo 1b

    /* Check that the routine preserves its callee-saved registers and SP. */
    ldr r4, =0x44444444
    ldr r5, =0x55555555
    ldr r6, =0x66666666
    ldr r7, =0x77777777
    ldr r8, =0x88888888
    ldr r9, =0x99999999
    mov r10, sp
    ldr r3, =0x090001c8
    blx r3

    cmp sp, r10
    bne fail
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
2:
    ldr r2, [r0], #4
    cmp r2, #0
    bne fail
    cmp r0, r1
    blo 2b

    ldr r0, =0x44444444
    cmp r4, r0
    bne fail
    ldr r0, =0x55555555
    cmp r5, r0
    bne fail
    ldr r0, =0x66666666
    cmp r6, r0
    bne fail
    ldr r0, =0x77777777
    cmp r7, r0
    bne fail
    ldr r0, =0x88888888
    cmp r8, r0
    bne fail
    ldr r0, =0x99999999
    cmp r9, r0
    bne fail

    mov r0, #0
    b exit
fail:
    mov r0, #1
exit:
    mov r7, #1          /* Linux ARM sys_exit */
    svc #0
.size _start, .-_start

.section .boot, "ax", %progbits
.incbin "bootloader.bin"
