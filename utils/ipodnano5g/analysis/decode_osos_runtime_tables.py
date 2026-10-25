#!/usr/bin/env python3
"""Decode OSOS runtime relative constructors and the 0x3280 factory row."""

import argparse
import hashlib
import struct
from pathlib import Path


BASE = 0x08000000
CTOR_START_ADD = 0x08012A28
CTOR_START_LITERAL = 0x08012A40
CTOR_END_ADD = 0x08012A2E
CTOR_END_LITERAL = 0x08012A44
FACTORY_TABLE = 0x08553A00
FACTORY_IDS = [
    0xA700, 0x2980, 0xA500, 0xA300, 0xA480, 0xA980,
    0x8700, 0x8A00, 0x3580, 0x3280, 0xA600, 0xAD00,
    0xAC00, 0x8300, 0x5800, 0xA880, 0xA080, 0x7600,
    0xAF80, 0xA680, 0x7A80, 0x8F00, 0x9780, 0x8080,
]


def u32(data: bytes, address: int) -> int:
    offset = address - BASE
    return struct.unpack_from("<I", data, offset)[0]


def thumb_pc(instruction_address: int) -> int:
    return (instruction_address + 4) & ~3


def format_pointer(raw: int) -> tuple[str, str]:
    mode = "Thumb" if raw & 1 else "ARM"
    return mode, f"0x{raw & ~1:08x}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    data = args.image.read_bytes()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(data).hexdigest()

    start = thumb_pc(CTOR_START_ADD) + u32(data, CTOR_START_LITERAL)
    end = thumb_pc(CTOR_END_ADD) + u32(data, CTOR_END_LITERAL)
    if end < start or (end - start) % 4:
        raise ValueError(f"invalid constructor table bounds: {start:#x}..{end:#x}")

    ctor_path = args.output_dir / "osos_runtime_constructor_table.tsv"
    with ctor_path.open("w", encoding="utf-8") as out:
        out.write(f"# image={args.image}\n# size={len(data)}\n# sha256={digest}\n")
        out.write("index\tentry\trel_u32\trel_s32\ttarget_raw\tisa\tcode_addr\n")
        for index, entry in enumerate(range(start, end, 4)):
            rel_u32 = u32(data, entry)
            rel_s32 = struct.unpack("<i", struct.pack("<I", rel_u32))[0]
            target = (entry + rel_u32) & 0xFFFFFFFF
            isa, code_addr = format_pointer(target)
            out.write(
                f"{index}\t0x{entry:08x}\t0x{rel_u32:08x}\t{rel_s32}\t"
                f"0x{target:08x}\t{isa}\t{code_addr}\n"
            )

    factory_path = args.output_dir / "osos_runtime_factory_rows.tsv"
    with factory_path.open("w", encoding="utf-8") as out:
        out.write(f"# image={args.image}\n# size={len(data)}\n# sha256={digest}\n")
        out.write(
            "index\trow\tid_written_by_ctor\tinitial_id_word\t"
            "slot1_raw\tslot1_isa\tslot1_code\t"
            "slot2_raw\tslot2_isa\tslot2_code\n"
        )
        for index, identifier in enumerate(FACTORY_IDS):
            row = FACTORY_TABLE + 4 + index * 12
            initial_id, slot1, slot2 = (
                u32(data, row), u32(data, row + 4), u32(data, row + 8)
            )
            slot1_isa, slot1_code = format_pointer(slot1)
            slot2_isa, slot2_code = format_pointer(slot2)
            out.write(
                f"{index}\t0x{row:08x}\t0x{identifier:04x}\t0x{initial_id:08x}\t"
                f"0x{slot1:08x}\t{slot1_isa}\t{slot1_code}\t"
                f"0x{slot2:08x}\t{slot2_isa}\t{slot2_code}\n"
            )

    print(f"image_sha256={digest}")
    print(f"constructor_table=0x{start:08x}..0x{end:08x} entries={(end-start)//4}")
    print(f"wrote={ctor_path}")
    print(f"wrote={factory_path}")


if __name__ == "__main__":
    main()
