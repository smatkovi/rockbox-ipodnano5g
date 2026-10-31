#!/usr/bin/env bash
set -euo pipefail

root="$(git -C "$(dirname -- "$0")" rev-parse --show-toplevel)"
cd "$root"

evidence="utils/ipodnano5g/analysis/evidence/accessories-alias-parser-rehost-2026-10-31"
elf="$evidence/OSOS_accessories_parser_real_fat_entry_alias_copy_rehost_20261031.elf"
port="${GDB_PORT:-23459}"

clang --target=arm-linux-gnueabi -mcpu=arm1176jzf-s -nostdlib -no-pie \
    -fno-pie -fuse-ld=lld \
    -Wl,-T,"$evidence/OSOS_accessories_parser_real_fat_entry_alias_copy_rehost_20261031.ld" \
    -Wl,--build-id=none -o "$elf" \
    "$evidence/OSOS_accessories_parser_real_fat_entry_alias_copy_rehost_20261031.S"

qemu-arm -g "$port" "$elf" >"$evidence/qemu_alias_parser.stdout" 2>"$evidence/qemu_alias_parser.stderr" &
qemu_pid=$!
cleanup() {
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
}
trap cleanup EXIT

gdb -q -batch \
    -ex 'set architecture arm' \
    -ex 'set confirm off' \
    -ex "file $elf" \
    -ex "target remote :$port" \
    -ex 'break *0x8bf00000' \
    -ex 'continue' \
    -ex 'info registers pc r0 r1 r2 r3 r4 sp lr cpsr' \
    -ex 'x/16bx 0x8bf00000' \
    -ex "dump binary memory $evidence/loader-alias-postread.bin 0x8bf00000 0x8bf10f80" \
    -ex 'x/32wx 0x08e64000' \
    -ex 'kill' \
    -ex 'quit' >"$evidence/gdb_alias_parser_rehost.log" 2>&1

cmp "$evidence/loader-alias-postread.bin" \
    utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin
sha256sum "$evidence/loader-alias-postread.bin"
cat "$evidence/gdb_alias_parser_rehost.log"
