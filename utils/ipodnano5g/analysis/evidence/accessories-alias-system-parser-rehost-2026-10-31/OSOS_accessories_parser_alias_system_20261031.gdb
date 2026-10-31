set architecture arm
set pagination off
set confirm off
file utils/ipodnano5g/analysis/evidence/accessories-alias-system-parser-rehost-2026-10-31/OSOS_accessories_parser_alias_system_20261031.elf
target remote :12347
break *0x0bfc1000
break *0x08011000
break *0x0802c3c4
 hbreak *0x083531c0
 hbreak *0x8bf001c8
 hbreak *0x8bf00000
break *0x00000068
 hbreak fail
 hbreak *0x08010000
disable 9
continue
printf "STOP_BEFORE_MMU_SETUP\n"
info registers pc cpsr
disable 1
continue
printf "STOP_AFTER_MMU_SETUP_AT_HARNESS\n"
info registers pc cpsr
disable 2
continue
printf "STOP_AT_ORIGINAL_ACCESSORIES_PARSER_ENTRY\n"
info registers pc r0 r1 r2 r3 sp lr cpsr
disable 3
enable 9
continue
if $pc == 0x08010000
  printf "STOP_AT_UNEXPECTED_START_REENTRY_FROM_PARSER_CHAIN\n"
  info registers pc r0 r1 r2 r3 sp lr cpsr
  printf "PARSER_HARNESS_STATE_AT_REENTRY\n"
  x/32wx 0x08e64000
  printf "CALLER_STACK_AT_REENTRY\n"
  x/64wx 0x08e55100
  quit 1
end
if $pc == fail
  printf "STOP_AT_PARSER_FAILURE_PATH\n"
  info registers pc r0 r1 r2 r3 sp lr cpsr
  quit 1
end
if $pc == 0x68
  printf "STOP_IN_LOW_VECTOR_EXCEPTION_HANDLER\n"
  info registers pc cpsr lr
  x/6wx 0x08003f00
  quit 1
end
printf "STOP_AT_REAL_OSOS_DSB_HELPER\n"
info registers pc r0 r1 r2 r3 sp lr cpsr
continue
printf "STOP_AT_LOADER_BSS_INIT_THROUGH_ALIAS\n"
info registers pc r0 r1 r2 r3 sp lr cpsr
set {unsigned int}0x0bf20000 = 0xa5a5a5a5
set {unsigned int}0x0bf70000 = 0x33333333
set {unsigned int}0x0bfbfcfc = 0x5a5a5a5a
continue
printf "STOP_AT_LOADER_ENTRY_THROUGH_ALIAS_BEFORE_FIRST_INSTRUCTION\n"
info registers pc r0 r1 r2 r3 sp lr cpsr
printf "ALIAS_AND_IDENTITY_L1_DESCRIPTORS\n"
x/wx 0x0bfd02fc
x/wx 0x0bfd22fc
printf "BSS_MARKERS_AFTER_REAL_LOADER_BSS_INIT\n"
x/wx 0x0bf20000
x/wx 0x0bf70000
x/wx 0x0bfbfcfc
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-system-parser-rehost-2026-10-31/loader-alias-at-entry.bin 0x8bf00000 0x8bf10f80
dump binary memory utils/ipodnano5g/analysis/evidence/accessories-alias-system-parser-rehost-2026-10-31/loader-canonical-at-entry.bin 0x0bf00000 0x0bf10f80
kill
quit
