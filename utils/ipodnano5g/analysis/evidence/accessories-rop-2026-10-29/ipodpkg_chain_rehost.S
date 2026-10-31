.syntax unified
.cpu arm1176jzf-s
.section .text, "ax", %progbits
.arm
.global _start
.type _start, %function
_start:
    ldr sp, =stack_top

    /* Guard the two file-read arguments serialized in this candidate. */
    ldr r0, =candidate_field + 0x25c
    ldr r1, [r0]
    ldr r2, =0x10f88
    cmp r1, r2
    bne fail
    ldr r0, =candidate_field + 0x260
    ldr r1, [r0]
    ldr r2, =0x08fffff8
    cmp r1, r2
    bne fail

    /* Poison BSS so the original routine must clear it. */
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
    ldr r2, =0xa5a5a5a5
1:
    str r2, [r0], #4
    cmp r0, r1
    blo 1b

    /* Install the exact candidate field, then redirect only its final target. */
    ldr r0, =0x08e55004
    ldr r1, =candidate_field
    ldr r2, =0x294
2:
    ldrb r3, [r1], #1
    strb r3, [r0], #1
    subs r2, r2, #1
    bne 2b
    ldr r0, =0x08e55288
    ldr r1, =0x09300000
    str r1, [r0]

    /* Model the successful read of the packaged image to its serialized dest. */
    ldr r0, =0x09400000
    ldr r1, =0x08fffff8
    ldr r2, =0x10f88
3:
    ldrb r3, [r0], #1
    strb r3, [r1], #1
    subs r2, r2, #1
    bne 3b

    /* The package header ends at 0x09000000; verify the actual ARM entry. */
    ldr r0, =0x09000000
    ldr r1, [r0]
    ldr r2, =0xea00000d
    cmp r1, r2
    bne fail

    /* Enter the candidate's original BLX/pop chain after a successful read. */
    ldr sp, =0x08e55278
    ldr r3, =0x08030cbf
    bx r3
.size _start, .-_start

.section .trampoline, "ax", %progbits
.thumb
    blx r3
    pop {r3, r4, r5, pc}

.section .input_field, "a", %progbits
candidate_field:
.incbin "candidate_accessories_reg_ipodpkg_unexecuted.bin", 0x20, 0x294

.section .package_source, "a", %progbits
.incbin "bootloader-ipodnano5g.ipod"

.section .sentinel, "ax", %progbits
.arm
sentinel:
    ldr r0, =0x09300000
    cmp r3, r0
    bne fail
    ldr r0, =0x08e55298
    cmp sp, r0
    bne fail
    /* Confirm the read restored the parser-cleanup byte in the raw image. */
    ldr r0, =0x09000040
    ldr r1, [r0]
    ldr r2, =0xe24fb008
    cmp r1, r2
    bne fail
    /* Confirm bss_init cleared the complete linked BSS range. */
    ldr r0, =0x09100000
    ldr r1, =0x0919fd00
4:
    ldr r2, [r0], #4
    cmp r2, #0
    bne fail
    cmp r0, r1
    blo 4b
    mov r0, #0
    b exit
fail:
    mov r0, #1
exit:
    mov r7, #1
    svc #0
