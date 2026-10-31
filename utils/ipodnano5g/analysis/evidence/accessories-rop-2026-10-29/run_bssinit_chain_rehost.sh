#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

cp "$ROOT/build-n5g-blramdisk/bootloader.bin" "$HERE/bootloader.bin"
python3 "$HERE/build_candidate_accessories_reg_bssinit.py"

cd "$HERE"
arm-none-eabi-as -march=armv6k -o bssinit_chain_rehost.o bssinit_chain_rehost.S
arm-none-eabi-ld -T bssinit_chain_rehost.ld -o bssinit_chain_rehost.elf bssinit_chain_rehost.o
qemu-arm -cpu arm1176 ./bssinit_chain_rehost.elf
printf 'PASS: original trampoline called bootloader bss_init, then reached sentinel\n'
