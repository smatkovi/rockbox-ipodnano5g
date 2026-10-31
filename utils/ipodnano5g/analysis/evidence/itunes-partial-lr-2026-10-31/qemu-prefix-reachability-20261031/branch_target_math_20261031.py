#!/usr/bin/env python3
"""Recompute the filename-controlled ARM B.MI target windows."""

HEAP_START = 0x08E54E4C
HEAP_END = 0x0BBA5EE0
LOADER_START = 0x09000000
LOADER_TEXT_END = 0x09013780
LOADER_BSS_START = 0x09100000
LOADER_BSS_END = LOADER_BSS_START + 0x9FD00
BRANCH_PC_DELTA = 0x30

# Conservative printable ASCII subset: exclude VFAT-invalid punctuation and
# spaces. The fourth byte is fixed to 'J' so the word decodes as B.MI.
invalid_vfat_ascii = set(b'"*/:<>?\\|')
safe_ascii = [value for value in range(0x21, 0x7F) if value not in invalid_vfat_ascii]
ascii_immediates = [a | (b << 8) | (c << 16)
                    for a in safe_ascii for b in safe_ascii for c in safe_ascii]
ascii_displacements = [((value << 2) & 0xFFFFFFFF) for value in ascii_immediates]
ascii_min = min(ascii_displacements)
ascii_max = max(ascii_displacements)
ascii_target_min = HEAP_START + BRANCH_PC_DELTA + ascii_min
ascii_target_max_at_heap_start = HEAP_START + BRANCH_PC_DELTA + ascii_max

utf8_u2000 = bytes.fromhex("e2 80 80")
utf8_imm = int.from_bytes(utf8_u2000, "little")
utf8_signed_imm = utf8_imm - 0x1000000
utf8_displacement = utf8_signed_imm << 2

def path_for_target(target):
    return target - BRANCH_PC_DELTA - utf8_displacement

print(f"heap={HEAP_START:#010x}..{HEAP_END:#010x}")
print(f"safe_printable_ascii={len(safe_ascii)} values; branch triples={len(ascii_immediates)}")
print(f"ASCII B.MI displacement={ascii_min:#010x}..{ascii_max:#010x}")
print(f"ASCII target from heap start={ascii_target_min:#010x}..{ascii_target_max_at_heap_start:#010x}")
print(f"Rockbox loader text={LOADER_START:#010x}..{LOADER_TEXT_END:#010x}; BSS={LOADER_BSS_START:#010x}..{LOADER_BSS_END:#010x}")
print(f"ASCII direct overlap with loader text/BSS={not (ascii_target_min >= LOADER_BSS_END or ascii_target_max_at_heap_start < LOADER_START)}")
print(f"UTF-8 U+2000 bytes={utf8_u2000.hex(' ')} immediate={utf8_imm:#08x} signed={utf8_signed_imm:#x} displacement={utf8_displacement:#x}")
for label, target in (("FUN_0818ece0", 0x0818ECE0), ("Rockbox loader entry", LOADER_START)):
    path = path_for_target(target)
    print(f"UTF-8 target {label}={target:#010x} requires path buffer={path:#010x}; within heap={HEAP_START <= path < HEAP_END}")
