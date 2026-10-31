#!/usr/bin/env python3
"""Generate a separate bounded-wire parser rehost for the BSS-init variant."""

from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = "OSOS_accessories_parser_bounded_wire_fat_rehost_20261029"
OUT = "bssinit_parser_wire_rehost"
OLD_CANDIDATE = str(HERE / "candidate_accessories_reg_unexecuted.bin")
NEW_CANDIDATE = "candidate_accessories_reg_bssinit_unexecuted.bin"


def replace_exact(data, old, new, expected, label):
    count = data.count(old)
    if count != expected:
        raise SystemExit(f"{label}: expected {expected} occurrences, got {count}")
    return data.replace(old, new)


source = (HERE / f"{BASE}.S").read_text()
linker = (HERE / f"{BASE}.ld").read_text()
source = replace_exact(source, OLD_CANDIDATE, NEW_CANDIDATE, 2, "candidate input")
source = replace_exact(source, "0x2c0", "0x2d0", 5, "file-size constants")
source = replace_exact(source, "0x2a8", "0x2b8", 1, "stream cursor assertion")

start_old = "\n".join([
    "    bl combined_setup",
    "    ldr r0, =stack_base + 0x140",
])
start_new = "\n".join([
    "    bl combined_setup",
    "    /* Rehost only: redirect the last target word to the sentinel. */",
    "    ldr r0, =candidate_file + 0x2a4",
    "    ldr r1, =0x09300000",
    "    str r1, [r0]",
    "    /* Poison BSS so the original bss_init must clear every word. */",
    "    ldr r0, =0x09100000",
    "    ldr r1, =0x0919fd00",
    "    ldr r2, =0xa5a5a5a5",
    "1:",
    "    str r2, [r0], #4",
    "    cmp r0, r1",
    "    blo 1b",
    "    ldr r0, =stack_base + 0x140",
])
source = replace_exact(source, start_old, start_new, 1, "parser setup insertion")

read_old = "\n".join([
    "    ldr r3, =0x09000000",
    "    cmp r2, r3",
    "    bne .Lbad_read",
    "    ldr r3, =read_called",
    "    movs r4, #1",
    "    str r4, [r3]",
    "    movs r0, #0",
    "    pop {r4, pc}",
])
read_new = "\n".join([
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
    "5:",
    "    ldrb r3, [r0]",
    "    strb r3, [r1]",
    "    adds r0, #1",
    "    adds r1, #1",
    "    subs r2, r2, #1",
    "    bne 5b",
    "    movs r0, #0",
    "    pop {r4, pc}",
])
source = replace_exact(source, read_old, read_new, 1, "loader-read model")

loader_sections_old = "\n".join([
    '.section .loader_entry,"ax",%progbits',
    ".arm",
    "loader_stub:",
    "    b loader_impl",
    "",
    '.section .cleanup_probe,"aw",%progbits',
    ".byte 0x7f",
    "",
    '.section .loader_impl,"ax",%progbits',
])
loader_sections_new = "\n".join([
    '.section .boot,"ax",%progbits',
    '.incbin "bootloader.bin"',
    "",
    '.section .boot_source,"a",%progbits',
    '.incbin "bootloader.bin"',
    "",
    '.section .loader_impl,"ax",%progbits',
])
source = replace_exact(source, loader_sections_old, loader_sections_new, 1, "loader sections")

probe_old = "\n".join([
    "    ldr r0, =0x09000040",
    "    ldrb r1, [r0]",
    "    cmp r1, #0",
    "    bne fail",
])
probe_new = "\n".join([
    "    /* A full read must restore the original instruction at +0x40. */",
    "    ldr r0, =0x09000040",
    "    ldr r1, [r0]",
    "    ldr r2, =0xe24fb008",
    "    cmp r1, r2",
    "    bne fail",
    "    /* The real Rockbox bss_init must clear its entire .bss range. */",
    "    ldr r0, =0x09100000",
    "    ldr r1, =0x0919fd00",
    "6:",
    "    ldr r2, [r0], #4",
    "    cmp r2, #0",
    "    bne fail",
    "    cmp r0, r1",
    "    blo 6b",
])
source = replace_exact(source, probe_old, probe_new, 1, "sentinel assertions")

linker = replace_exact(
    linker,
    "  loader PT_LOAD FLAGS(7);\n  static_zero PT_LOAD FLAGS(4);",
    "  loader PT_LOAD FLAGS(7);\n  bootloader PT_LOAD FLAGS(7);\n  rockbox_bss PT_LOAD FLAGS(6);\n  boot_source PT_LOAD FLAGS(4);\n  static_zero PT_LOAD FLAGS(4);",
    1,
    "program headers",
)
map_old = "\n".join([
    "  . = 0x09000000;",
    "  .loader_entry : { *(.loader_entry) } :loader",
    "  . = 0x09000040;",
    "  .cleanup_probe : { *(.cleanup_probe) } :loader",
    "  . = 0x09000100;",
    "  .loader_impl : { *(.loader_impl) } :loader",
])
map_new = "\n".join([
    "  . = 0x09000000;",
    "  .boot : { KEEP(*(.boot)) } :bootloader",
    "  . = 0x09100000;",
    "  .rockbox_bss (NOLOAD) : { . += 0x9fd00; } :rockbox_bss",
    "  . = 0x09300000;",
    "  .loader_impl : { *(.loader_impl) } :loader",
    "  . = 0x09400000;",
    "  .boot_source : { *(.boot_source) } :boot_source",
])
linker = replace_exact(linker, map_old, map_new, 1, "loader memory map")

(HERE / f"{OUT}.S").write_text(source)
(HERE / f"{OUT}.ld").write_text(linker)
print(f"generated {HERE / f'{OUT}.S'}")
print(f"generated {HERE / f'{OUT}.ld'}")
print("base rehost and original candidate were not modified")
