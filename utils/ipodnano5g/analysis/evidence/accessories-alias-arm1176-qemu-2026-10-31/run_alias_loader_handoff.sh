#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../../../../.." && pwd)
safe_loader="$repo_root/utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin"
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
    -fuse-ld=lld -Wl,-T,"$script_dir/alias_loader_handoff.ld" \
    -Wl,--build-id=none -o "$script_dir/alias_loader_handoff.elf" \
    "$script_dir/alias_loader_handoff.S"

qemu-system-arm -machine none -cpu arm1176 -m 576M -display none \
    -monitor none -serial none -S -gdb tcp:127.0.0.1:12346 \
    -device loader,file="$script_dir/alias_loader_handoff.elf",cpu-num=0 \
    -device loader,file="$safe_loader",addr=0x0a000000,force-raw=on \
    > "$script_dir/qemu_alias_handoff.log" 2>&1 &
qemu_pid=$!

sleep 1
gdb -q -batch -x "$script_dir/alias_loader_handoff.gdb" \
    > "$script_dir/gdb_alias_handoff.log" 2>&1

rg -q 'Breakpoint 1, 0x0bf000e0' "$script_dir/gdb_alias_handoff.log"
cmp "$safe_loader" "$script_dir/loader-copy-at-startloc.bin"
cmp "$safe_loader" "$script_dir/loader-alias-at-startloc.bin"
sha256sum "$safe_loader" "$script_dir/loader-copy-at-startloc.bin" \
    "$script_dir/loader-alias-at-startloc.bin"
cat "$script_dir/gdb_alias_handoff.log"
