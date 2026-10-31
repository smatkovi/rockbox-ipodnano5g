#!/usr/bin/env python3
"""Search extracted Nano 5G code images for queue-1 setup imports/veneers.

This is a literal little-endian word scan, not a control-flow proof. It records
all searched files and their hashes so absence claims stay scoped and
reproducible.
"""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path


NANO5G_ROOT = Path("/home/sebastian/ipod-re/nano5g")
EXTRA_INPUTS = [
    Path("/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin"),
    Path("/home/sebastian/ipod-re/local-analysis/inputs/osos_bootprefix_22000000_20261031.bin"),
]
SUFFIXES = {".pe32", ".bin", ".ibss", ".ipod", ".img"}
MAX_SIZE = 16 * 1024 * 1024
NEEDLES = {
    0x22005248: "prefix queue-setup API literal",
    0x22005249: "prefix queue-setup Thumb pointer",
    0x22007008: "prefix SVC dispatcher literal",
    0x22007009: "prefix SVC dispatcher Thumb pointer",
    0x0823B7A8: "OSOS-body queue-setup veneer pointer",
    0x0823B7A9: "OSOS-body queue-setup Thumb pointer",
    0x0820D52C: "OSOS-runtime queue-setup veneer pointer",
    0x0820D52D: "OSOS-runtime queue-setup Thumb pointer",
}


def find_words(data: bytes, word: int):
    needle = struct.pack("<I", word)
    start = 0
    while True:
        offset = data.find(needle, start)
        if offset < 0:
            return
        yield offset
        start = offset + 1


files = {
    path
    for path in NANO5G_ROOT.rglob("*")
    if path.is_file() and path.suffix.lower() in SUFFIXES and path.stat().st_size <= MAX_SIZE
}
files.update(path for path in EXTRA_INPUTS if path.is_file())

print("literal-scan=LE32")
print(f"root={NANO5G_ROOT}")
print(f"max_size={MAX_SIZE}")
print("needles=" + ",".join(f"{value:#010x}" for value in NEEDLES))
hits = 0
for path in sorted(files):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    file_hits = []
    for value, label in NEEDLES.items():
        file_hits.extend((offset, value, label) for offset in find_words(data, value))
    if file_hits:
        for offset, value, label in sorted(file_hits):
            print(
                f"HIT path={path} sha256={digest} value={value:#010x} "
                f"offset={offset:#x} meaning={label}"
            )
            hits += 1
print(f"SCANNED_FILES={len(files)} HITS={hits}")
