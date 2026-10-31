#!/usr/bin/env python3
"""Create an unexecuted wrap-length variant of the local accessories.reg candidate."""

from pathlib import Path


HERE = Path(__file__).resolve().parent
SOURCE = HERE / "candidate_accessories_reg_unexecuted.bin"
OUTPUT = HERE / "candidate_accessories_reg_wrap_unexecuted.bin"
LENGTH_OFFSET = 0x1C
ORIGINAL_LENGTH = 0x284
WRAP_LENGTH = 0xFFFFFFF0

data = bytearray(SOURCE.read_bytes())
assert len(data) == 0x2C0
assert int.from_bytes(data[LENGTH_OFFSET:LENGTH_OFFSET + 4], "little") == ORIGINAL_LENGTH
data[LENGTH_OFFSET:LENGTH_OFFSET + 4] = WRAP_LENGTH.to_bytes(4, "little")
assert int.from_bytes(data[LENGTH_OFFSET:LENGTH_OFFSET + 4], "little") == WRAP_LENGTH
assert data[0x20:0x2A4] == SOURCE.read_bytes()[0x20:0x2A4]
OUTPUT.write_bytes(data)
print(f"wrote {OUTPUT.name}: {len(data)} bytes, length=0x{WRAP_LENGTH:08x}")
