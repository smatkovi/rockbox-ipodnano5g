#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"

cp "$ROOT/build-n5g-blramdisk/bootloader.bin" "$HERE/bootloader.bin"
python3 "$HERE/build_candidate_accessories_reg_bssinit.py"

cd "$HERE"
arm-none-eabi-as -march=armv6k -o bssinit_rehost.o bssinit_rehost.S
arm-none-eabi-ld -T bssinit_rehost.ld -o bssinit_rehost.elf bssinit_rehost.o
qemu-arm -cpu arm1176 ./bssinit_rehost.elf
printf 'PASS: original bootloader bss_init cleared the full range and returned cleanly\n'
