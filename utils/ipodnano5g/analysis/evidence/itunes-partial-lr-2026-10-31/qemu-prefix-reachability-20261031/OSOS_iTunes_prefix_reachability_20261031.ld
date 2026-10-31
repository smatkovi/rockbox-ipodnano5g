ENTRY(success_start)
SECTIONS
{
    . = 0x00000000;
    .vectors : { KEEP(*(.vectors)) }
    . = 0x00010000;
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    . = 0x08020000;
    .path_success : { *(.path_success) }
    . = 0x08022000;
    .path_error_branch : { *(.path_error_branch) }
    . = 0x08700000;
    .branch_trap_back : { *(.branch_trap_back) }
    . = 0x09072534;
    .branch_trap : { *(.branch_trap) }
    . = 0x0a6dfc48;
    .path_error_branch_back : { *(.path_error_branch_back) }
    /DISCARD/ : { *(.ARM.attributes) *(.comment) }
}
