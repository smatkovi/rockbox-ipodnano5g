OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
    harness PT_LOAD FLAGS(5);
    trampoline PT_LOAD FLAGS(5);
    stack PT_LOAD FLAGS(6);
    input PT_LOAD FLAGS(4);
    packaged_loader PT_LOAD FLAGS(4);
    loader_area PT_LOAD FLAGS(7);
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

    . = 0x08fffff8;
    .loader_area (NOLOAD) : { . += 0x10f88; } :loader_area

    . = 0x09100000;
    .test_bss (NOLOAD) : { . += 0x9fd00; } :bss

    . = 0x09300000;
    .sentinel : { *(.sentinel) } :sentinel

    . = 0x09400000;
    .package_source : { *(.package_source) } :packaged_loader
}
