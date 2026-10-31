OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
    harness PT_LOAD FLAGS(5);
    trampoline PT_LOAD FLAGS(5);
    stack PT_LOAD FLAGS(6);
    input PT_LOAD FLAGS(4);
    bootloader PT_LOAD FLAGS(5);
    bss PT_LOAD FLAGS(6);
    sentinel PT_LOAD FLAGS(5);
}

SECTIONS
{
    . = 0x08010000;
    .text : { *(.text*) } :harness

    . = 0x08030cbc;
    .trampoline : { *(.trampoline) } :trampoline

    . = 0x08e54000;
    .test_stack (NOLOAD) : { . += 0x5000; stack_top = .; } :stack

    . = 0x08e60000;
    .input_field : { *(.input_field) } :input

    . = 0x09000000;
    .boot : { KEEP(*(.boot)) } :bootloader

    . = 0x09100000;
    .test_bss (NOLOAD) : { . += 0x9fd00; } :bss

    . = 0x09300000;
    .sentinel : { *(.sentinel) } :sentinel
}
