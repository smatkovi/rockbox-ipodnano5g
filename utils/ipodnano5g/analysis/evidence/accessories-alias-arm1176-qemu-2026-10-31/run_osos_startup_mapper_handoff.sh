#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
safe_loader="$repo_root/utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin"
runtime_sram="$repo_root/../local-analysis/inputs/osos_bootprefix_22000000_20261031.bin"
runtime_dram="$repo_root/../local-analysis/inputs/osos_runtime_dram_20261025.bin"
qemu_pid=""

cleanup() {
    if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

cd "$repo_root"
test -f "$safe_loader"
test -f "$runtime_sram"
test -f "$runtime_dram"
runtime_sram_sha=$(sha256sum "$runtime_sram" | cut -d ' ' -f1)
runtime_dram_sha=$(sha256sum "$runtime_dram" | cut -d ' ' -f1)
test "$runtime_sram_sha" = "0b01c47e51b562523ddce4747529bd9f41b14840337e76ede54af60a809f54e2"
test "$runtime_dram_sha" = "1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03"
clang --target=arm-none-eabi -mcpu=arm1176jzf-s -nostdlib -fno-pie -fuse-ld=lld -Wl,-T,"$script_dir/osos_startup_mapper_handoff.ld" -Wl,--build-id=none -o "$script_dir/osos_startup_mapper_handoff.elf" "$script_dir/osos_startup_mapper_handoff.S"

qemu-system-arm -machine none -cpu arm1176 -m 576M -display none -monitor none -serial none -S -gdb tcp:127.0.0.1:12348 -device loader,file="$runtime_sram",addr=0x22000000,force-raw=on -device loader,file="$runtime_dram",addr=0x08000000,force-raw=on -device loader,file="$safe_loader",addr=0x0a000000,force-raw=on -device loader,file="$script_dir/osos_startup_mapper_handoff.elf",cpu-num=0 > "$script_dir/qemu_osos_startup_mapper_handoff.log" 2>&1 &
qemu_pid=$!

sleep 1
gdb -q -batch -x "$script_dir/osos_startup_mapper_handoff.gdb" > "$script_dir/gdb_osos_startup_mapper_handoff.log" 2>&1

rg -q 'Breakpoint 1, 0x22005d3c' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q 'Breakpoint 2, 0x0bf000e0' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x90000e8:[[:space:]]*0x00c5187d' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x90000ec:[[:space:]]*0x00000007' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x90000f0:[[:space:]]*0x086dc000' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x90000f4:[[:space:]]*0x00000000' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x90000f8:[[:space:]]*0x00000001' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86dc000:[[:space:]]*0x2200c802' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86dc200:[[:space:]]*0x08007c0e' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86dc800:[[:space:]]*0x20006c0a' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86dc880:[[:space:]]*0x22004c02' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86dce00:[[:space:]]*0x38000c02' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86de200:[[:space:]]*0x08004c02' "$script_dir/gdb_osos_startup_mapper_handoff.log"
rg -q '0x86de2fc:[[:space:]]*0x0bf04c02' "$script_dir/gdb_osos_startup_mapper_handoff.log"
cmp "$safe_loader" "$script_dir/osos-startup-loader-copy-at-startloc.bin"
cmp "$safe_loader" "$script_dir/osos-startup-loader-alias-at-startloc.bin"
sha256sum "$runtime_sram" "$runtime_dram" "$safe_loader" "$script_dir/osos-startup-loader-copy-at-startloc.bin" "$script_dir/osos-startup-loader-alias-at-startloc.bin"
cat "$script_dir/gdb_osos_startup_mapper_handoff.log"
