#!/usr/bin/env python3
"""Search a flat ARM/Thumb image for direct branches to one virtual address.

This is a byte-pattern cross-check, not a disassembler: matches can be data
false positives and must be inspected in context.
"""
import argparse
from pathlib import Path


BASE = 0x08000000


def sign_extend(value: int, width: int) -> int:
    sign = 1 << (width - 1)
    return (value ^ sign) - sign


def scan_thumb(data: bytes, target: int):
    for off in range(0, len(data) - 3, 2):
        first = int.from_bytes(data[off:off + 2], "little")
        second = int.from_bytes(data[off + 2:off + 4], "little")
        if first & 0xF800 != 0xF000:
            continue
        branch_type = None
        if second & 0xD000 == 0xD000:
            branch_type = "Thumb BL"
        elif second & 0xD000 == 0x9000:
            branch_type = "Thumb B.W"
        if branch_type is None:
            continue
        s = (first >> 10) & 1
        j1 = (second >> 13) & 1
        j2 = (second >> 11) & 1
        i1 = 1 ^ (j1 ^ s)
        i2 = 1 ^ (j2 ^ s)
        imm10 = first & 0x03FF
        imm11 = second & 0x07FF
        encoded = (s << 24) | (i1 << 23) | (i2 << 22) | (imm10 << 12) | (imm11 << 1)
        dest = ((BASE + off + 4 + sign_extend(encoded, 25)) & 0xFFFFFFFF)
        if dest == target:
            raw = (second << 16) | first
            yield branch_type, BASE + off, raw


def scan_arm(data: bytes, target: int):
    for off in range(0, len(data) - 3, 4):
        word = int.from_bytes(data[off:off + 4], "little")
        if (word >> 25) & 0x7 != 0b101:
            continue
        imm24 = word & 0x00FFFFFF
        dest = (BASE + off + 8 + sign_extend(imm24 << 2, 26)) & 0xFFFFFFFF
        if dest == target:
            link = (word >> 24) & 1
            yield ("ARM BL" if link else "ARM B"), BASE + off, word


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("target", type=lambda s: int(s, 0))
    args = parser.parse_args()
    data = args.image.read_bytes()
    target = args.target & ~1
    matches = list(scan_thumb(data, target)) + list(scan_arm(data, target))
    print(f"IMAGE={args.image} SIZE={len(data)} BASE=0x{BASE:08x} TARGET=0x{target:08x}")
    print("NOTE=raw byte scan only; inspect every match as code before treating it as a caller")
    for kind, address, raw in sorted(matches, key=lambda row: row[1]):
        print(f"MATCH {kind} source=0x{address:08x} raw=0x{raw:08x}")
    print(f"MATCH_COUNT={len(matches)}")


if __name__ == "__main__":
    main()
