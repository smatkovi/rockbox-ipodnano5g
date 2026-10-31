set pagination off
set confirm off
file utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos_exact_mapper_handoff.elf
set architecture arm
set endian little
target remote 127.0.0.1:12347
hbreak *0x0bf000e0
continue
printf "\nSTOP_PC_EXPECTED_START_LOC\n"
info registers pc cpsr
printf "\nCANONICAL_ENTRY_WORDS\n"
x/4wx 0x0bf00000
printf "\nALIAS_ENTRY_WORDS\n"
x/4wx 0x8bf00000
printf "\nBSS_BEGIN_WORDS_AFTER_BSS_INIT\n"
x/4wx 0x0bf20000
printf "\nACTUAL_OSOS_WRITER_DESCRIPTOR_READBACK\n"
x/wx 0x086dc200
x/wx 0x086de200
x/wx 0x086de2fc
x/wx 0x086dc000
x/wx 0x086dc880
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos-mapper-loader-copy-at-startloc.bin 0x0bf00000 0x0bf10f80
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/osos-mapper-loader-alias-at-startloc.bin 0x8bf00000 0x8bf10f80
detach
quit
