#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

cp "$ROOT/build-n5g-blramdisk/bootloader-ipodnano5g.ipod" "$HERE/bootloader-ipodnano5g.ipod"
cp "$ROOT/build-n5g-blramdisk/bootloader.bin" "$HERE/bootloader.bin"
python3 "$HERE/build_candidate_accessories_reg_bssinit.py"
python3 "$HERE/build_candidate_accessories_reg_ipodpkg.py"
python3 "$HERE/build_bssinit_parser_rehost.py"
python3 "$HERE/build_ipodpkg_parser_rehost.py"
cmp -n 69504 -i 8:0 "$HERE/bootloader-ipodnano5g.ipod" "$HERE/bootloader.bin"

cd "$HERE"
clang --target=arm-linux-gnueabi -mcpu=arm1176jzf-s -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,ipodpkg_parser_wire_rehost.ld -Wl,--build-id=none \
  -o ipodpkg_parser_wire_rehost.elf ipodpkg_parser_wire_rehost.S
qemu-arm -cpu arm1176 -d in_asm,cpu -D ipodpkg_parser_wire_rehost.qemu-trace.log \
  ipodpkg_parser_wire_rehost.elf > ipodpkg_parser_wire_rehost.stdout.bin
printf 'PASS: original parser reached the packaged loader, restored +0x40, and cleared BSS\n'
