OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
    harness PT_LOAD FLAGS(5);
    bootloader PT_LOAD FLAGS(5);
    bss PT_LOAD FLAGS(6);
    stack PT_LOAD FLAGS(6);
}

SECTIONS
{
    . = 0x08000000;
    .text : { *(.text*) } :harness
    .rodata : { *(.rodata*) } :harness

    . = 0x09000000;
    .boot : { KEEP(*(.boot)) } :bootloader

    . = 0x09100000;
    .test_bss (NOLOAD) : { . += 0x9fd00; } :bss

    . = 0x09200000;
    .test_stack (NOLOAD) : { . += 0x10000; } :stack
    stack_top = .;
}
