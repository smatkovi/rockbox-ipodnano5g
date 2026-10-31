#!/usr/bin/env python3
"""Reconstruct the OSOS initial-load to relocated-entry path from IMG1 bytes."""

from hashlib import sha256
from pathlib import Path
import struct


BODY = Path("/home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin")
LOAD_BASE = 0x08000000
SRAM_BASE = 0x22000000


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
    body = BODY.read_bytes()
    print(f"IMG1 body size=0x{len(body):x} sha256={sha256(body).hexdigest()}")
    print("IMG1 header cross-check: saved header report says entry offset=0;")
    print("local RetailOS layout documentation says the second-stage loader loads it into DRAM.")

    entry_insn = u32(body, 0)
    entry_initial = branch_target(entry_insn, LOAD_BASE)
    entry_relocated = branch_target(entry_insn, SRAM_BASE)
    stack_insn = u32(body, 0x7044)
    stack_initial = branch_target(stack_insn, LOAD_BASE + 0x7044)
    stack_relocated = branch_target(stack_insn, SRAM_BASE + 0x7044)
    print(f"entry_branch=0x{entry_insn:08x} initial_target=0x{entry_initial:08x} relocated_target=0x{entry_relocated:08x}")
    print(f"stack_stub_branch=0x{stack_insn:08x} initial_target=0x{stack_initial:08x} relocated_target=0x{stack_relocated:08x}")

    symbol_at_runtime = u32(body, 0x7078)
    current_symbol = LOAD_BASE + 0x7060
    relocation_delta = symbol_at_runtime - current_symbol
    print(f"relocation_delta_symbol=0x{symbol_at_runtime:08x} current_symbol=0x{current_symbol:08x} delta=0x{relocation_delta:08x}")

    # FUN_08005ec8 reads this table. The companion Ghidra log records the
    # copy/zero calls and the PC transition through FUN_08007070.
    table = {offset: u32(body, offset) for offset in (
        0x5FA0, 0x5FA4, 0x5FA8, 0x5FAC, 0x5FB0, 0x5FB4,
        0x5FB8, 0x5FBC, 0x5FC0, 0x5FC4, 0x5FC8, 0x5FCC,
    )}
    for offset, value in table.items():
        print(f"reloc_table[0x{offset:04x}]=0x{value:08x}")

    sections = [
        ("sram.text", LOAD_BASE, table[0x5FA0], table[0x5FA4]),
        ("relocator.zero_fill", None, table[0x5FA8], table[0x5FAC]),
        ("sram.bss+data_payload", LOAD_BASE + table[0x5FA4], table[0x5FB0], table[0x5FB4]),
        ("optional.zero_fill", None, table[0x5FB8], table[0x5FBC]),
        ("dram.textdata", LOAD_BASE + table[0x5FA4] + table[0x5FB4], table[0x5FC0], table[0x5FC4]),
        ("dram.frameworks", LOAD_BASE + table[0x5FA4] + table[0x5FB4] + table[0x5FC4], table[0x5FC8], table[0x5FCC]),
    ]
    for name, source, target, size in sections:
        source_text = "zero-fill" if source is None else f"source=0x{source:08x} body_fileoff=0x{source - LOAD_BASE:x}"
        print(f"section {name}: {source_text} destination=0x{target:08x} size=0x{size:x}")

    assert entry_initial == LOAD_BASE + 0x7038
    assert stack_initial == LOAD_BASE + 0x5058
    assert relocation_delta == 0x1A000000
    assert tuple(table[x] for x in (0x5FA0, 0x5FA4)) == (SRAM_BASE, 0xE27C)
    assert tuple(table[x] for x in (0x5FA8, 0x5FAC)) == (0x2200E27C, 0xBC4)
    assert tuple(table[x] for x in (0x5FB0, 0x5FB4)) == (0x22030000, 0x20000)
    assert tuple(table[x] for x in (0x5FB8, 0x5FBC)) == (0x22050000, 0)
    assert tuple(table[x] for x in (0x5FC0, 0x5FC4)) == (LOAD_BASE, 0x6C3768)
    assert tuple(table[x] for x in (0x5FC8, 0x5FCC)) == (0x086C3768, 0xC40)
    assert table[0x5FA4] + table[0x5FB4] == 0x2E27C
    assert table[0x5FC4] + table[0x5FCC] == len(body) - 0x2E27C
    print("assertions=PASS; static section-copy destinations and IMG1 body ranges are internally consistent")
    print("scope=static bytes plus local OSOS layout documentation; no live RAM/MMU/TTBR state was read")


if __name__ == "__main__":
    main()
