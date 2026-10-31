set pagination off
set confirm off
file utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-bss-2026-10-31/osos_startup_bss_mapper_handoff.elf
set architecture arm
set endian little
target remote 127.0.0.1:12349
hbreak *0x22005fec
hbreak *0x22005d3c
hbreak *0x0bf000e0
continue
printf "\nSTOP_AT_EXACT_OSOS_DRAM_BSS_CLEAR_ENTRY_MARKER_STILL_SET\n"
info registers pc cpsr
x/wx 0x086dd400
continue
printf "\nSTOP_AFTER_EXACT_OSOS_DRAM_BSS_CLEAR_BEFORE_MAPPER\n"
info registers pc cpsr
x/wx 0x086dd400
x/wx 0x086dc000
continue
printf "\nSTOP_AT_LOADER_STARTLOC_AFTER_EXACT_OSOS_MAPPER\n"
info registers pc cpsr
printf "\nOSOS_TABLE_AFTER_BSS_CLEAR_AND_MAPPER\n"
x/wx 0x086dd400
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
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-bss-2026-10-31/osos-bss-loader-copy-at-startloc.bin 0x0bf00000 0x0bf10f80
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-bss-2026-10-31/osos-bss-loader-alias-at-startloc.bin 0x8bf00000 0x8bf10f80
detach
quit
