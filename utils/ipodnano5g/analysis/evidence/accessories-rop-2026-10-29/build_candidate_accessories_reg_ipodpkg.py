#!/usr/bin/env python3
"""Create an unexecuted accessories.reg variant for the packaged N5G loader.

The ordinary Rockbox build artifact has an 8-byte add-up/model header before
the exact raw bootloader image. This variant reads that package to 0x08fffff8,
so its raw code begins at the linked address 0x09000000.
"""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "candidate_accessories_reg_bssinit_unexecuted.bin"
OUTPUT = HERE / "candidate_accessories_reg_ipodpkg_unexecuted.bin"
SOURCE_SHA256 = "d9973abc3b223baceaf378a582e2b7acd3fd96b82ef548f40a8f31a4a957ecfa"
FIELD_LEN = 0x294
PACKAGE_READ_LEN = 0x10F88
PACKAGE_DEST = 0x08FFFFF8
RAW_ENTRY = 0x09000000
BSS_INIT = 0x090001C8


def word(buf: bytes | bytearray, offset: int) -> int:
    return struct.unpack_from("<I", buf, offset)[0]


source = SOURCE.read_bytes()
digest = hashlib.sha256(source).hexdigest()
if len(source) != 0x2D0 or digest != SOURCE_SHA256:
    raise SystemExit(f"unexpected BSS candidate: size={len(source):#x}, sha256={digest}")
if word(source, 0x1C) != FIELD_LEN:
    raise SystemExit("field length changed")
if source[0x20 + 0xBC : 0x20 + 0xC6] != b"/BOOT.BIN\0":
    raise SystemExit("loader path changed")

candidate = bytearray(source)
struct.pack_into("<I", candidate, 0x20 + 0x25C, PACKAGE_READ_LEN)
struct.pack_into("<I", candidate, 0x20 + 0x260, PACKAGE_DEST)

if word(candidate, 0x20 + 0x25C) != PACKAGE_READ_LEN:
    raise AssertionError("package read length mismatch")
if word(candidate, 0x20 + 0x260) != PACKAGE_DEST:
    raise AssertionError("package destination mismatch")
if word(candidate, 0x20 + 0x274) != BSS_INIT:
    raise AssertionError("bss_init target changed")
if word(candidate, 0x20 + 0x284) != RAW_ENTRY:
    raise AssertionError("raw bootloader entry changed")
if len(candidate) != 0x2D0:
    raise AssertionError(f"unexpected candidate size: {len(candidate):#x}")

OUTPUT.write_bytes(candidate)
print(f"wrote local candidate: {OUTPUT}")
print(f"size: {len(candidate)} bytes (0x{len(candidate):x})")
print(f"sha256: {hashlib.sha256(candidate).hexdigest()}")
print("loader read: /BOOT.BIN, length 0x10f88, destination 0x08fffff8")
print("raw bootloader body: 0x09000000; candidate remains unexecuted")
