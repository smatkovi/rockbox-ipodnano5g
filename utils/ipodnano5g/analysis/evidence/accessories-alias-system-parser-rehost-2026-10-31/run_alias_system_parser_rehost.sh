#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel)
qemu_pid=""

cleanup() {
    if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
}
trap cleanup EXIT

cd "$repo_root"
clang --target=arm-none-eabi -mcpu=arm1176jzf-s -nostdlib -fno-pie \
    -fuse-ld=lld \
    -Wl,-T,"$script_dir/OSOS_accessories_parser_alias_system_20261031.ld" \
    -Wl,--build-id=none \
    -o "$script_dir/OSOS_accessories_parser_alias_system_20261031.elf" \
    "$script_dir/OSOS_accessories_parser_alias_system_20261031.S"

qemu-system-arm -machine none -cpu arm1176 -m 576M -display none \
    -monitor none -serial none -S -gdb tcp:127.0.0.1:12347 \
    -device loader,file="$script_dir/OSOS_accessories_parser_alias_system_20261031.elf",cpu-num=0 \
    > "$script_dir/qemu_alias_system_parser.log" 2>&1 &
qemu_pid=$!

sleep 1
gdb -q -batch -x "$script_dir/OSOS_accessories_parser_alias_system_20261031.gdb" \
    > "$script_dir/gdb_alias_system_parser.log" 2>&1

rg -q 'STOP_AT_REAL_OSOS_DSB_HELPER' "$script_dir/gdb_alias_system_parser.log"
rg -q 'STOP_AT_LOADER_BSS_INIT_THROUGH_ALIAS' "$script_dir/gdb_alias_system_parser.log"
rg -q 'STOP_AT_LOADER_ENTRY_THROUGH_ALIAS_BEFORE_FIRST_INSTRUCTION' "$script_dir/gdb_alias_system_parser.log"
rg -q 'r1 +0x10f80' "$script_dir/gdb_alias_system_parser.log"
rg -q 'r2 +0x8bf10f80' "$script_dir/gdb_alias_system_parser.log"
rg -q '0xbfd22fc:.*0x0bf04c02' "$script_dir/gdb_alias_system_parser.log"
rg -q '0xbf20000:.*0x00000000' "$script_dir/gdb_alias_system_parser.log"
rg -q '0xbf70000:.*0x00000000' "$script_dir/gdb_alias_system_parser.log"
rg -q '0xbfbfcfc:.*0x00000000' "$script_dir/gdb_alias_system_parser.log"
cmp utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin \
    "$script_dir/loader-alias-at-entry.bin"
cmp utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin \
    "$script_dir/loader-canonical-at-entry.bin"
sha256sum utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin \
    "$script_dir/loader-alias-at-entry.bin" "$script_dir/loader-canonical-at-entry.bin"
cat "$script_dir/gdb_alias_system_parser.log"
