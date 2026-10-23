#!/bin/bash
# n5g-cycle.sh [rockbox.ipod [build dir]]
#
# One turn of the dev loop with Rockbox running (devloop-nano5g.c): wait for
# its RAM disk on USB, fetch the reports in /devloop (to ~/ipod-re/reports,
# decoded with n5g-mailbox.py), copy a new boot file if given, then eject.
# Rockbox starts the boot file on trial after the eject and falls back to
# the last good image on a panic, a hang dump or silent USB storage. With
# a build dir, the plugins and codecs on the RAM disk are refreshed from it
# too (needed whenever the plugin or codec API changes).
set -euo pipefail
NEW=${1:-}
BUILD=${2:-}
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
if [ -e "$M/i2cscan.txt" ]; then
    cp "$M/i2cscan.txt" "$OUT/$stamp-i2cscan.txt"
    echo "i2c scan: $OUT/$stamp-i2cscan.txt"
fi
if [ -n "$NEW" ]; then
    $SUDO cp "$NEW" "$M/.rockbox/rockbox.ipod"
    echo "new boot file: $NEW"
fi
if [ -n "$BUILD" ]; then
    (cd "$M/.rockbox" && find rocks codecs -name '*.rock' -o -name '*.ovl' -o -name '*.codec') |
    while read -r r; do
        f=$(find "$BUILD/apps/plugins" "$BUILD/lib/rbcodec/codecs" -name "$(basename "$r")" 2>/dev/null | head -1)
        if [ -n "$f" ] && ! cmp -s "$f" "$M/.rockbox/$r"; then
            $SUDO cp "$f" "$M/.rockbox/$r" && echo "updated $r"
        fi
    done
fi
sync
$SUDO umount "$M"
# every LUN of the device (the read-only NAND too): Rockbox leaves USB mode
# only when all of its drives are ejected
usbdev=$(readlink -f "/sys/block/$dev/device" | sed 's|/host[0-9]*/.*||')
for b in /sys/block/sd*; do
    case "$(readlink -f "$b/device")" in
        "$usbdev"/*) n=$(basename "$b")
                     for p in /dev/"$n"?*; do $SUDO umount "$p" 2>/dev/null || true; done
                     $SUDO eject "/dev/$n" && echo "ejected $n" ;;
    esac
done
