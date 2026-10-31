#!/usr/bin/env python3
"""Generate a parser-to-BSS rehost using the packaged N5G bootloader."""

from pathlib import Path


HERE = Path(__file__).resolve().parent
BASE = "bssinit_parser_wire_rehost"
OUT = "ipodpkg_parser_wire_rehost"
OLD_CANDIDATE = "candidate_accessories_reg_bssinit_unexecuted.bin"
NEW_CANDIDATE = "candidate_accessories_reg_ipodpkg_unexecuted.bin"


def replace_exact(data: str, old: str, new: str, count: int, label: str) -> str:
    actual = data.count(old)
    if actual != count:
        raise SystemExit(f"{label}: expected {count} occurrences, got {actual}")
    return data.replace(old, new)


source = (HERE / f"{BASE}.S").read_text()
linker = (HERE / f"{BASE}.ld").read_text()
source = replace_exact(source, OLD_CANDIDATE, NEW_CANDIDATE, 2, "candidate input")

read_old = "\n".join([
    "    ldr r3, =0x10f80",
    "    cmp r1, r3",
    "    bne .Lbad_read",
    "    ldr r3, =0x09000000",
    "    cmp r2, r3",
    "    bne .Lbad_read",
    "    ldr r3, =read_called",
    "    movs r4, #1",
    "    str r4, [r3]",
    "    /* Copy the file image; this restores the earlier +0x40 cleanup store. */",
    "    ldr r0, =0x09400000",
    "    ldr r1, =0x09000000",
    "    ldr r2, =0x10f80",
])
read_new = "\n".join([
    "    ldr r3, =0x10f88",
    "    cmp r1, r3",
    "    bne .Lbad_read",
    "    ldr r3, =0x08fffff8",
    "    cmp r2, r3",
    "    bne .Lbad_read",
    "    ldr r3, =read_called",
    "    movs r4, #1",
    "    str r4, [r3]",
    "    /* Read the package header before the raw image at 0x09000000. */",
    "    ldr r0, =0x09400000",
    "    ldr r1, =0x08fffff8",
    "    ldr r2, =0x10f88",
])
source = replace_exact(source, read_old, read_new, 1, "loader-read model")

boot_sections_old = "\n".join([
    '.section .boot,"ax",%progbits',
    '.incbin "bootloader.bin"',
    "",
    '.section .boot_source,"a",%progbits',
    '.incbin "bootloader.bin"',
])
boot_sections_new = "\n".join([
    '.section .boot_source,"a",%progbits',
    '.incbin "bootloader-ipodnano5g.ipod"',
])
source = replace_exact(source, boot_sections_old, boot_sections_new, 1, "package source")

entry_old = "\n".join([
    "    /* A full read must restore the original instruction at +0x40. */",
    "    ldr r0, =0x09000040",
    "    ldr r1, [r0]",
    "    ldr r2, =0xe24fb008",
])
entry_new = "\n".join([
    "    /* The 8-byte package prefix must leave the raw ARM entry in place. */",
    "    ldr r0, =0x09000000",
    "    ldr r1, [r0]",
    "    ldr r2, =0xea00000d",
    "    cmp r1, r2",
    "    bne fail",
    "    /* A full read must restore the original instruction at +0x40. */",
    "    ldr r0, =0x09000040",
    "    ldr r1, [r0]",
    "    ldr r2, =0xe24fb008",
])
source = replace_exact(source, entry_old, entry_new, 1, "entry assertion")

linker = replace_exact(
    linker,
    "  bootloader PT_LOAD FLAGS(7);\n  rockbox_bss PT_LOAD FLAGS(6);",
    "  loader_area PT_LOAD FLAGS(7);\n  rockbox_bss PT_LOAD FLAGS(6);",
    1,
    "loader-area segment",
)
map_old = "\n".join([
    "  . = 0x09000000;",
    "  .boot : { KEEP(*(.boot)) } :bootloader",
    "  . = 0x09100000;",
    "  .rockbox_bss (NOLOAD) : { . += 0x9fd00; } :rockbox_bss",
])
map_new = "\n".join([
    "  . = 0x08fffff8;",
    "  .loader_area (NOLOAD) : { . += 0x10f88; } :loader_area",
    "  . = 0x09100000;",
    "  .rockbox_bss (NOLOAD) : { . += 0x9fd00; } :rockbox_bss",
])
linker = replace_exact(linker, map_old, map_new, 1, "package destination map")

(HERE / f"{OUT}.S").write_text(source)
(HERE / f"{OUT}.ld").write_text(linker)
print(f"generated {HERE / f'{OUT}.S'}")
print(f"generated {HERE / f'{OUT}.ld'}")
print("original parser rehost and candidates were not modified")
