#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

cp "$ROOT/build-n5g-blramdisk/bootloader-ipodnano5g.ipod" "$HERE/bootloader-ipodnano5g.ipod"
cp "$ROOT/build-n5g-blramdisk/bootloader.bin" "$HERE/bootloader.bin"
python3 "$HERE/build_candidate_accessories_reg_bssinit.py"
python3 "$HERE/build_candidate_accessories_reg_ipodpkg.py"
cmp -n 69504 -i 8:0 "$HERE/bootloader-ipodnano5g.ipod" "$HERE/bootloader.bin"

cd "$HERE"
arm-none-eabi-as -march=armv6k -o ipodpkg_chain_rehost.o ipodpkg_chain_rehost.S
arm-none-eabi-ld -T ipodpkg_chain_rehost.ld -o ipodpkg_chain_rehost.elf ipodpkg_chain_rehost.o
qemu-arm -cpu arm1176 -d in_asm,cpu -D ipodpkg_chain_rehost.qemu-trace.log \
  ./ipodpkg_chain_rehost.elf > ipodpkg_chain_rehost.stdout.bin
printf 'PASS: packaged header was skipped; raw entry and bss_init chain reached sentinel\n'
