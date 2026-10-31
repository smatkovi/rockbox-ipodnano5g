.syntax unified
.cpu arm1176jzf-s
.section .text, "ax", %progbits
.arm
.global _start
.type _start, %function
_start:
    ldr sp, =stack_top

    /* Poison the real Rockbox BSS so the later check proves the call ran. */
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
    ldr r2, =0xa5a5a5a5
1:
    str r2, [r0], #4
    cmp r0, r1
    blo 1b

    /* Install the exact 0x294-byte field from the separate candidate file. */
    ldr r0, =0x08e55004
    ldr r1, =candidate_field
    ldr r2, =0x294
2:
    ldrb r3, [r1], #1
    strb r3, [r0], #1
    subs r2, r2, #1
    bne 2b

    /* Rehost-only substitution: second-stage target becomes the sentinel. */
    ldr r0, =0x08e55288
    ldr r1, =0x09300000
    str r1, [r0]

    /* Model the post-read SP and enter the original Thumb BLX/pop gadget. */
    ldr sp, =0x08e55278
    ldr r3, =0x08030cbf
    bx r3
.size _start, .-_start

.section .trampoline, "ax", %progbits
.thumb
    blx r3
    pop {r3, r4, r5, pc}

.section .boot, "ax", %progbits
.incbin "bootloader.bin"

.section .input_field, "a", %progbits
candidate_field:
.incbin "candidate_accessories_reg_bssinit_unexecuted.bin", 0x20, 0x294

.section .sentinel, "ax", %progbits
.arm
sentinel:
    /* The final candidate word is redirected here only in this rehost. */
    ldr r0, =0x09300000
    cmp r3, r0
    bne fail
    ldr r0, =0x08e55298
    cmp sp, r0
    bne fail
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
3:
    ldr r2, [r0], #4
    cmp r2, #0
    bne fail
    cmp r0, r1
    blo 3b
    mov r0, #0
    b exit
fail:
    mov r0, #1
exit:
    mov r7, #1
    svc #0
