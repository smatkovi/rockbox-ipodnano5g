#!/bin/bash
# n5g-cycle.sh [rockbox.ipod]
#
# One turn of the dev loop with Rockbox running (devloop-nano5g.c): wait for
# its RAM disk on USB, fetch the reports in /devloop (to ~/ipod-re/reports,
# decoded with n5g-mailbox.py), copy a new boot file if given, then eject.
# Rockbox starts the boot file on trial after the eject and falls back to
# the last good image on a panic, a hang dump or silent USB storage.
set -euo pipefail
NEW=${1:-}
D=$(dirname "$(realpath "$0")")
OUT=${N5G_REPORTS:-$HOME/ipod-re/reports}
SUDO=$([ "$(id -u)" = 0 ] || echo sudo)
mkdir -p "$OUT"

dev=""
for _ in $(seq 1 60); do
    dev=$(lsblk -dn -o NAME,MODEL | awk '$2 == "Ramdisk" {print $1; exit}')
    [ -n "$dev" ] && break
    sleep 2
done
[ -n "$dev" ] || { echo "no Rockbox RAM disk on USB"; exit 1; }
sleep 2
M=$(mktemp -d)
trap '$SUDO umount "$M" 2>/dev/null || true; rmdir "$M"' EXIT
$SUDO mount "/dev/$dev" "$M"
stamp=$(date +%Y%m%d-%H%M%S)
for f in "$M"/devloop/report*.bin; do
    [ -e "$f" ] || continue
    out="$OUT/$stamp-$(basename "$f" .bin)"
    cp "$f" "$out.bin"
    python3 -I "$D/n5g-mailbox.py" --file "$out.bin" \
        --elf "${N5G_ELF:-$D/../../build-n5g/rockbox.elf}" > "$out.txt" 2>&1 || true
    $SUDO rm "$f"
    echo "report: $out.txt ($(head -1 "$out.txt"))"
done
if [ -n "$NEW" ]; then
    $SUDO cp "$NEW" "$M/.rockbox/rockbox.ipod"
    echo "new boot file: $NEW"
fi
sync
$SUDO umount "$M"
$SUDO eject "/dev/$dev"
echo "ejected"
