#!/usr/bin/env python3
"""Check OSOS startup call order and the exact DRAM BSS/table bounds."""

from hashlib import sha256
from pathlib import Path
import struct


REPO_ROOT = Path(__file__).resolve().parents[5]
INPUTS = REPO_ROOT.parent / "local-analysis" / "inputs"
PREFIX = INPUTS / "osos_bootprefix_22000000_20261031.bin"
DRAM = INPUTS / "osos_runtime_dram_20261025.bin"
TABLE_BASE = 0x086DC000
TABLE_SIZE = 4096 * 4
WITNESS = TABLE_BASE + 0x500 * 4


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def branch_target(instruction: int, pc: int) -> int:
    if instruction >> 28 == 0xF or instruction & 0x0E000000 != 0x0A000000:
        raise ValueError(f"not an A32 B/BL instruction: 0x{instruction:08x}")
    immediate = instruction & 0x00FFFFFF
    if immediate & 0x00800000:
        immediate -= 0x01000000
    return (pc + 8 + (immediate << 2)) & 0xFFFFFFFF


def main() -> None:
    prefix = PREFIX.read_bytes()
    dram = DRAM.read_bytes()
    print(f"prefix_sha256={sha256(prefix).hexdigest()}")
    print(f"dram_suffix_sha256={sha256(dram).hexdigest()}")
    print(f"startup_call_0x220050bc=0x{branch_target(u32(prefix, 0x50bc), 0x220050bc):08x}")
    print(f"startup_call_0x220050c8=0x{branch_target(u32(prefix, 0x50c8), 0x220050c8):08x}")
    print(f"bss_helper_call_0x22005ffc=0x{branch_target(u32(prefix, 0x5ffc), 0x22005ffc):08x}")

    values = {
        0x6038: u32(prefix, 0x6038),
        0x603c: u32(prefix, 0x603c),
        0x6040: u32(prefix, 0x6040),
        0x6044: u32(prefix, 0x6044),
        0x6048: u32(prefix, 0x6048),
        0x604c: u32(prefix, 0x604c),
        0x6050: u32(prefix, 0x6050),
        0x6054: u32(prefix, 0x6054),
    }
    for offset, value in values.items():
        print(f"prefix_literal_0x{offset:04x}=0x{value:08x}")

    dram_bss_start = values[0x6050]
    dram_bss_size = values[0x6054]
    dram_bss_end = dram_bss_start + dram_bss_size
    table_end = TABLE_BASE + TABLE_SIZE
    print(f"dram_bss=[0x{dram_bss_start:08x},0x{dram_bss_end:08x}) size=0x{dram_bss_size:x}")
    print(f"l1_table=[0x{TABLE_BASE:08x},0x{table_end:08x}) size=0x{TABLE_SIZE:x}")
    print(f"witness_entry=0x{WITNESS:08x}")
    print(f"dram_loaded_end=0x{0x08000000 + len(dram):08x}")

    assert branch_target(u32(prefix, 0x50bc), 0x220050bc) == 0x22005fec
    assert branch_target(u32(prefix, 0x50c8), 0x220050c8) == 0x22005d3c
    assert branch_target(u32(prefix, 0x5ffc), 0x22005ffc) == 0x22000074
    assert values == {
        0x6038: 0x2200E27C,
        0x603c: 0x00000BC4,
        0x6040: 0x22050000,
        0x6044: 0,
        0x6048: 0x086C3768,
        0x604c: 0,
        0x6050: 0x086C43A8,
        0x6054: 0x00790AA4,
    }
    assert 0x08000000 + len(dram) == dram_bss_start
    assert dram_bss_start <= TABLE_BASE < table_end <= dram_bss_end
    assert TABLE_BASE + 0x500 * 4 == WITNESS
    print("assertions=PASS; exact startup calls BSS clear before MMU setup; L1 table is fully inside DRAM BSS")
    print("scope=static offline images only; no live device RAM or MMU state")


if __name__ == "__main__":
    main()
