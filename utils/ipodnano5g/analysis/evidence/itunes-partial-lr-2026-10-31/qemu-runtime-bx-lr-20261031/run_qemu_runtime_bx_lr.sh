#!/usr/bin/env bash
set -u

cd "$(dirname "$0")"
runtime_bin="${1:-/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin}"
if [[ ! -r "$runtime_bin" ]]; then
    printf 'Missing local runtime image: %s\n' "$runtime_bin" >&2
    exit 2
fi

arm-none-eabi-as -mcpu=arm1176jzf-s -o OSOS_runtime_bx_lr_20261031.o OSOS_runtime_bx_lr_20261031.S || exit 1
arm-none-eabi-ld -T OSOS_runtime_bx_lr_20261031.ld -o runtime-bx-lr.elf OSOS_runtime_bx_lr_20261031.o || exit 1

timeout 10s qemu-system-arm \
    -M versatilepb -cpu arm1176 -m 192M -nographic \
    -monitor none -serial none \
    -semihosting-config enable=on,target=native \
    -d in_asm,guest_errors -D runtime_bx_lr_trace.log \
    -device loader,file="$runtime_bin",addr=0x08000000,force-raw=on \
    -kernel runtime-bx-lr.elf >runtime_bx_lr_qemu.log 2>&1
rc=$?
printf 'runtime_bx_lr exit=%s log=runtime_bx_lr_qemu.log\n' "$rc"
cat runtime_bx_lr_qemu.log
exit "$rc"
