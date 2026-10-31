set pagination off
set confirm off
file utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos_startup_mapper_handoff.elf
set architecture arm
set endian little
target remote 127.0.0.1:12348
hbreak *0x22005d3c
hbreak *0x0bf000e0
continue
printf "\nSTOP_PC_OSOS_MAP_INITIALIZER\n"
info registers pc cpsr
continue
printf "\nSTOP_PC_EXPECTED_START_LOC\n"
info registers pc cpsr
printf "\nOSOS_STARTUP_CP15_READBACK\n"
x/wx 0x090000e8
x/wx 0x090000ec
x/wx 0x090000f0
x/wx 0x090000f4
x/wx 0x090000f8
x/wx 0x090000fc
printf "\nACTUAL_OSOS_STARTUP_TABLE\n"
x/wx 0x086dc000
x/wx 0x086dc200
x/wx 0x086dc880
x/wx 0x086de200
x/wx 0x086de2fc
x/wx 0x086dc800
x/wx 0x086dce00
printf "\nCANONICAL_ENTRY_WORDS\n"
x/4wx 0x0bf00000
printf "\nALIAS_ENTRY_WORDS\n"
x/4wx 0x8bf00000
printf "\nBSS_BEGIN_WORDS_AFTER_BSS_INIT\n"
x/4wx 0x0bf20000
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos-startup-loader-copy-at-startloc.bin 0x0bf00000 0x0bf10f80
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos-startup-loader-alias-at-startloc.bin 0x8bf00000 0x8bf10f80
detach
quit
