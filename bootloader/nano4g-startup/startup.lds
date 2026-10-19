ENTRY(_start)
OUTPUT_FORMAT(elf32-littlearm)
OUTPUT_ARCH(arm)
SECTIONS
{
    . = 0x22026000;
    .text : { KEEP(*(.entry)) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) BYTE(0) . = ALIGN(32); }
    _image_end = .;
    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss*) *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    }
    _stack_bottom = 0x2202e000;
    _stack_top = 0x22030000;
    ASSERT(_bss_end <= _stack_bottom, "startup overlaps its 8 KiB SRAM stack")
    /DISCARD/ : { *(.comment) *(.note*) *(.ARM.exidx*) *(.ARM.extab*) }
}
