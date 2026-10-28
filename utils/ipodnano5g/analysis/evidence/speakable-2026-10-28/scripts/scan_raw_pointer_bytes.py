#!/usr/bin/env python3
"""Find exact little-endian 32-bit pointer values at any byte alignment."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("targets", nargs="+", type=lambda s: int(s, 0))
    args = parser.parse_args()
    data = args.image.read_bytes()
    print(f"IMAGE={args.image} SIZE={len(data)}")
    for target in args.targets:
        needle = (target & 0xFFFFFFFF).to_bytes(4, "little")
        offsets = []
        start = 0
        while True:
            found = data.find(needle, start)
            if found < 0:
                break
            offsets.append(found)
            start = found + 1
        print(f"TARGET=0x{target & 0xFFFFFFFF:08x} COUNT={len(offsets)}")
        for off in offsets:
            print(f"  OFFSET=0x{off:08x} ADDRESS=0x{0x08000000 + off:08x}")


if __name__ == "__main__":
    main()
