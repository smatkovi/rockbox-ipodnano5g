.syntax unified
.cpu arm926ej-s

.section .start,"ax",%progbits
.arm
.global _start
.type _start,%function
_start:
    ldr r0, =ctx
    ldr r1, =lfn_state
    ldr r2, =output
    ldr r3, =0x08159129
    blx r3
    ldr r1, =retmsg
    mov r0, #1
    mov r2, #3
    mov r7, #4
    svc #0
    mov r0, #0
    mov r7, #1
    svc #0
.size _start, .-_start

.section .lfn,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x159128, 128

.section .copy,"ax",%progbits
.incbin "/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin", 0x160828, 118

.section .cache_get,"ax",%progbits
.thumb
.thumb_func
.global cache_get
cache_get:
    ldr r0, =fake_cache
    bx lr

.section .utf_stub,"ax",%progbits
.thumb
.thumb_func
.global utf_stub
utf_stub:
    ldr r3, [r0]
    strb r1, [r3]
    adds r3, #1
    str r3, [r0]
    bx lr

.section .release_stub,"ax",%progbits
.thumb
.thumb_func
.global release_stub
release_stub:
    bx lr

.section .data,"aw",%progbits
.align 4
.global fake_cache
fake_cache:
    .space 4096
.global ctx
ctx:
    .space 4
.align 4
.global lfn_state
lfn_state:
    .word 1
    .word 0x08e54e4c
    .word 0
    .word 1
    .word 0
.global output
output:
    .space 256
retmsg:
    .ascii "RET"
