#!/usr/bin/env python3
"""Cross-check OSOS section addresses and the early MMU mapper target."""

from hashlib import sha256
from pathlib import Path
import struct


BODY = Path("/home/sebastian/ipod-re/nano5g/osos_decrypted/osos_body.bin")
PREFIX = Path("/home/sebastian/ipod-re/local-analysis/inputs/osos_bootprefix_22000000_20261031.bin")
DRAM = Path("/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin")
BODY_BASE = 0x08000000
SRAM_BASE = 0x22000000
DRAM_FILE_OFFSET = 0x2E27C
SRAM_TEXT_SIZE = 0xE27C
ALIAS_TARGET = 0x080E3E84
MAPPER_BODY_FILE_OFFSET = 0x112100
MAPPER_LENGTH = 0x24


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def branch_target(instruction: int, pc: int) -> int:
    """Decode A32 B/BL immediate using the architectural PC value."""
    if instruction >> 28 == 0xF or instruction & 0x0E000000 != 0x0A000000:
        raise ValueError(f"not an A32 B/BL instruction: 0x{instruction:08x}")
    immediate = instruction & 0x00FFFFFF
    if immediate & 0x00800000:
        immediate -= 0x01000000
    return (pc + 8 + (immediate << 2)) & 0xFFFFFFFF


def report_file(label: str, path: Path, data: bytes) -> None:
    print(f"{label}: path={path} size=0x{len(data):x} sha256={sha256(data).hexdigest()}")


def main() -> None:
    body = BODY.read_bytes()
    prefix = PREFIX.read_bytes()
    dram = DRAM.read_bytes()
    report_file("IMG1 body", BODY, body)
    report_file("SRAM prefix extraction", PREFIX, prefix)
    report_file("offline DRAM suffix mapping (not a live RAM capture)", DRAM, dram)

    print("Section map: body file [0,0xe27c) -> SRAM VA 0x22000000;")
    print("            body file [0x2e27c,end) -> DRAM VA 0x08000000.")
    print(f"prefix_size_matches_0xe27c={len(prefix) == SRAM_TEXT_SIZE}")
    print(f"prefix_matches_body_start={prefix == body[:len(prefix)]}")
    print(f"dram_suffix_size_matches={len(dram) == len(body) - DRAM_FILE_OFFSET}")

    suffix = body[DRAM_FILE_OFFSET:]
    mismatch = [i for i, (a, b) in enumerate(zip(suffix, dram)) if a != b]
    print(f"dram_mapping_mismatch_count={len(mismatch)}")
    if mismatch:
        print(f"dram_mapping_mismatch_range=0x{mismatch[0]:x}..0x{mismatch[-1]:x}")

    entry = u32(prefix, 0)
    entry_target = branch_target(entry, SRAM_BASE)
    stack_branch = u32(prefix, 0x7044)
    stack_target = branch_target(stack_branch, SRAM_BASE + 0x7044)
    mmu_call = u32(prefix, 0x50C8)
    mmu_target = branch_target(mmu_call, SRAM_BASE + 0x50C8)
    print(f"entry_instruction=0x{entry:08x} target=0x{entry_target:08x}")
    print(f"startup_branch_fileoff=0x7044 instruction=0x{stack_branch:08x} target=0x{stack_target:08x}")
    print(f"mmu_call_fileoff=0x50c8 instruction=0x{mmu_call:08x} target=0x{mmu_target:08x}")

    thunk_insn = u32(prefix, 0x3970)
    thunk_target = u32(prefix, 0x3974)
    print(f"sram_mapper_thunk_va=0x{SRAM_BASE + 0x3970:08x} instruction=0x{thunk_insn:08x} literal=0x{thunk_target:08x}")

    dram_target_offset = ALIAS_TARGET - BODY_BASE
    source_body_offset = DRAM_FILE_OFFSET + dram_target_offset
    source_body_va = BODY_BASE + source_body_offset
    target_code = dram[dram_target_offset:dram_target_offset + MAPPER_LENGTH]
    source_code = body[source_body_offset:source_body_offset + MAPPER_LENGTH]
    target_ttbr = u32(dram, dram_target_offset + MAPPER_LENGTH)
    source_ttbr = u32(body, source_body_offset + MAPPER_LENGTH)
    print(f"mapper_runtime_va=0x{ALIAS_TARGET:08x}")
    print(f"mapper_source_body_fileoff=0x{source_body_offset:x} source_full_body_va=0x{source_body_va:08x}")
    print(f"mapper_code_length=0x{MAPPER_LENGTH:x} exact_match={target_code == source_code}")
    print(f"mapper_ttbr_literal_runtime=0x{target_ttbr:08x} body=0x{source_ttbr:08x}")
    print(f"alias_setup_literals_attr=0x{u32(prefix, 0x5e30):08x} ttbr=0x{u32(prefix, 0x5e40):08x}")
    print("alias_call_instruction_window=" + prefix[0x5db0:0x5dc0].hex())
    descriptor_index = 0x8BF
    descriptor_address = 0x086DC000 + 4 * descriptor_index
    descriptor_value = (0x08000000 + (descriptor_index - 0x880) * 0x100000) | 0x4C02
    print(f"alias_descriptor_count={0x8C0 - 0x880}")
    print(f"loader_alias_descriptor_va=0x8bf00000 address=0x{descriptor_address:08x} value=0x{descriptor_value:08x}")
    needle = (0x086DC000).to_bytes(4, "little")
    for label, data in (("sram_prefix", prefix), ("dram_suffix", dram)):
        offsets = [i for i in range(len(data) - 3) if data.startswith(needle, i)]
        print(f"ttbr_literal_occurrences_{label}=" + ",".join(f"0x{i:x}" for i in offsets))
    print("No statement here depends on a live device capture or runtime overlay.")


if __name__ == "__main__":
    main()
