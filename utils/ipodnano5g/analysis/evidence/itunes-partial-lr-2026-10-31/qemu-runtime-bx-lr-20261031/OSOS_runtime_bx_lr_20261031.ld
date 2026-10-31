ENTRY(runtime_start)
SECTIONS
{
    . = 0x00000000;
    .vectors : { KEEP(*(.vectors)) }
    . = 0x00010000;
    .text : { *(.text) }
    .thumb_probe : { *(.thumb_probe) }
    .rodata : { *(.rodata) }
    . = 0x0a16e928;
    .path : { *(.path) }
    /DISCARD/ : { *(.ARM.attributes) *(.comment) }
}
