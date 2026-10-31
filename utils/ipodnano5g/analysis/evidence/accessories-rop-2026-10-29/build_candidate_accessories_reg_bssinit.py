#!/usr/bin/env python3
"""Create a separate, unexecuted accessories.reg variant that clears Rockbox BSS.

The input is the already reviewed 704-byte candidate. This script does not
contact an iPod and never changes that input candidate.
"""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "candidate_accessories_reg_unexecuted.bin"
OUTPUT = HERE / "candidate_accessories_reg_bssinit_unexecuted.bin"
SOURCE_SHA256 = "7045ca2fe6a5f2660a815bdd182ff015691d90991ddc6f023972affcbd54e851"
OLD_SIZE = 0x2C0
OLD_FIELD_LEN = 0x284
NEW_FIELD_LEN = 0x294
TAIL_OFFSET = 0x20 + OLD_FIELD_LEN
BSS_INIT = 0x090001C8
LOADER_ENTRY = 0x09000000
TRAMPOLINE_THUMB = 0x08030CBD


def put_u32(buf: bytearray, offset: int, value: int) -> None:
    struct.pack_into("<I", buf, offset, value)


source = SOURCE.read_bytes()
source_hash = hashlib.sha256(source).hexdigest()
if len(source) != OLD_SIZE or source_hash != SOURCE_SHA256:
    raise SystemExit(
        f"unexpected base candidate: size={len(source):#x}, sha256={source_hash}"
    )
if struct.unpack_from("<I", source, 0x1C)[0] != OLD_FIELD_LEN:
    raise SystemExit("base field length does not match the reviewed candidate")

candidate = bytearray(source)
# Move the registry tail out by 16 bytes and extend the parser's field.
candidate[TAIL_OFFSET:TAIL_OFFSET] = bytes(NEW_FIELD_LEN - OLD_FIELD_LEN)
put_u32(candidate, 0x1C, NEW_FIELD_LEN)
put_u32(candidate, 0x20 + 0x274, BSS_INIT)
put_u32(candidate, 0x20 + 0x284, LOADER_ENTRY)
put_u32(candidate, 0x20 + 0x288, 0)
put_u32(candidate, 0x20 + 0x28C, 0)
put_u32(candidate, 0x20 + 0x290, TRAMPOLINE_THUMB)

if len(candidate) != 0x2D0:
    raise AssertionError(f"unexpected candidate size: {len(candidate):#x}")
if candidate[0x20 + 0xBC : 0x20 + 0xC6] != b"/BOOT.BIN\0":
    raise AssertionError("loader path changed")
for offset, expected in (
    (0x274, BSS_INIT),
    (0x280, TRAMPOLINE_THUMB),
    (0x284, LOADER_ENTRY),
    (0x290, TRAMPOLINE_THUMB),
):
    actual = struct.unpack_from("<I", candidate, 0x20 + offset)[0]
    if actual != expected:
        raise AssertionError(f"field word {offset:#x}: {actual:#x} != {expected:#x}")
if struct.unpack_from("<I", candidate, 0x20 + NEW_FIELD_LEN)[0] != 0x80000044:
    raise AssertionError("field terminator was not moved after the extended field")

OUTPUT.write_bytes(candidate)
print(f"wrote local candidate: {OUTPUT}")
print(f"size: {len(candidate)} bytes (0x{len(candidate):x})")
print(f"sha256: {hashlib.sha256(candidate).hexdigest()}")
print("status: not executed and not written to a device")
