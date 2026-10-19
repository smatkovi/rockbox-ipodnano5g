ENTRY(_start)
SECTIONS {
    . = 0x09000000;
    .text : { KEEP(*(.entry)) *(.text*) *(.rodata*) }
    .data : { *(.data*) BYTE(0) . = ALIGN(32); }
    _image_end = .;
    .bss (NOLOAD) : {
        _bss_start = .; *(.bss*) *(COMMON) . = ALIGN(32); _bss_end = .;
    }
    .stack (NOLOAD) : { . += 8192; _stack_top = .; }
    ASSERT(_stack_top < 0x09100000, "Installer exceeds reserved SDRAM space")
    /DISCARD/ : { *(.comment*) *(.note*) *(.ARM.exidx*) *(.ARM.extab*) }
}
