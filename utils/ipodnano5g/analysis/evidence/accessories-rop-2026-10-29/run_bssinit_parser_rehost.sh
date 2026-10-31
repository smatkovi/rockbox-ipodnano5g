#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

cp "$ROOT/build-n5g-blramdisk/bootloader.bin" "$HERE/bootloader.bin"
python3 "$HERE/build_candidate_accessories_reg_bssinit.py"
python3 "$HERE/build_bssinit_parser_rehost.py"

cd "$HERE"
clang --target=arm-linux-gnueabi -mcpu=arm1176jzf-s -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,bssinit_parser_wire_rehost.ld -Wl,--build-id=none \
  -o bssinit_parser_wire_rehost.elf bssinit_parser_wire_rehost.S
qemu-arm -cpu arm1176 -d in_asm,cpu -D bssinit_parser_wire_rehost.qemu-trace.log \
  bssinit_parser_wire_rehost.elf > bssinit_parser_wire_rehost.stdout.bin
printf 'PASS: parser cleanup was restored by file read; bss_init then cleared BSS\n'
