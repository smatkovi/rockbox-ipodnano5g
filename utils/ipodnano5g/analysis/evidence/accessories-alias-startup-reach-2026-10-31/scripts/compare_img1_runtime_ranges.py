#!/usr/bin/env python3
"""Compare the OSOS DRAM-section mapping against its IMG1 source bytes.

The runtime input is an offline mapping of the IMG1 DRAM suffix, not a live
RAM capture. Prefix bytes use a separate SRAM address map.
"""

from hashlib import sha256
from pathlib import Path

BODY = Path("/home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin")
DRAM = Path("/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin")
BODY_DRAM_FILE_OFFSET = 0x2E27C
DRAM_BASE = 0x08000000
RANGES = (
    (0x08000000, 4, "DRAM text section start"),
    (0x080e3e84, 0x28, "section mapper and TTBR literal"),
)


def digest(data: bytes) -> str:
    return sha256(data).hexdigest()


def main() -> None:
    body = BODY.read_bytes()
    dram = DRAM.read_bytes()
    print("Offline OSOS section-map comparison; not a live RAM capture.")
    print(f"body size=0x{len(body):x} sha256={digest(body)}")
    print(f"dram mapping size=0x{len(dram):x} sha256={digest(dram)}")
    print("SRAM prefix: body file offset 0 -> VA 0x22000000.")
    print("DRAM section: body file offset 0x2e27c -> VA 0x08000000.")
    for address, length, label in RANGES:
        runtime_offset = address - DRAM_BASE
        body_offset = BODY_DRAM_FILE_OFFSET + runtime_offset
        expected = body[body_offset:body_offset + length]
        observed = dram[runtime_offset:runtime_offset + length]
        print(f"{label}: runtime=0x{address:08x} body_file=0x{body_offset:x} "
              f"flat_body_project=0x{DRAM_BASE + body_offset:08x}")
        print(f"  equal={expected == observed} body={expected.hex()} mapped={observed.hex()}")


if __name__ == "__main__":
    main()
