set pagination off
set confirm off
file utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/alias_loader_handoff.elf
set architecture arm
set endian little
target remote 127.0.0.1:12346
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
printf "\nL1_DESCRIPTOR_LOW_VECTOR_ALIAS\n"
x/wx 0x08004000
printf "\nL1_DESCRIPTOR_DRAM_BASE\n"
x/wx 0x08004200
printf "\nL1_DESCRIPTOR_LOADER_ALIAS\n"
x/wx 0x080062fc
printf "\nL1_DESCRIPTOR_IRAM\n"
x/wx 0x08004880
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/loader-copy-at-startloc.bin 0x0bf00000 0x0bf10f80
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-arm1176-qemu-2026-10-31/loader-alias-at-startloc.bin 0x8bf00000 0x8bf10f80
detach
quit
