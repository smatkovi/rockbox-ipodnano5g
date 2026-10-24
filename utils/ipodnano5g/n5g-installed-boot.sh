#!/bin/bash
# n5g-installed-boot.sh
#
# Start the installed Rockbox firmware through the RAM-only N5G loader. The
# iPod must be in BootROM DFU with Hold unlocked. This starts a shell-enabled
# U-Boot, keeps a return copy in SDRAM for the Rockbox devloop, then transfers
# the N5G bootloader to 0x09000000. The bootloader reads
# /.rockbox/rockbox.ipod and /.rockbox/n5g-ramdisk.img from the iPod's FAT.
# Nothing is written to NAND or NOR by this script.

set -euo pipefail

D=$(cd "$(dirname "$(realpath "$0")")" && pwd)
ROOT=$(cd "$D/../.." && pwd)
WIND3X=${WIND3X:-$ROOT/../ref/wInd3x-upstream/wInd3x}
UBOOT_SHELL=${UBOOT_SHELL:-$ROOT/../ref/build-uboot-n5gwip/u-boot.bin}
BOOTLOADER=${BOOTLOADER:-$ROOT/build-n5g-blramdisk/bootloader.bin}
TTY=${TTY:-/dev/serial/by-id/usb-freemyipod_U-Boot_firmware_dbg-if00}
if [ "$(id -u)" = 0 ]; then SUDO=(); else SUDO=(sudo -n); fi

for f in "$WIND3X" "$UBOOT_SHELL" "$BOOTLOADER"; do
    [ -r "$f" ] || { echo "missing required file: $f" >&2; exit 1; }
done

wait_usb() {
    local id=$1 seconds=$2
    for ((i=0; i<seconds; i++)); do
        lsusb -d "$id" >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

echo "Waiting for iPod BootROM DFU (05ac:1231); unlock Hold for Rockbox..."
wait_usb 05ac:1231 1800 || { echo "no DFU device" >&2; exit 1; }

TMP=$(mktemp -d)
WIND_PID=
cleanup() {
    if [ -n "$WIND_PID" ]; then
        kill "$WIND_PID" 2>/dev/null || true
        wait "$WIND_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "Starting shell-enabled U-Boot through wInd3x..."
"${SUDO[@]}" env HOME="$HOME" XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" \
    "$WIND3X" cfw run "$UBOOT_SHELL" >"$TMP/wind3x.log" 2>&1 &
WIND_PID=$!
if ! wait_usb 05ac:2137 120; then
    cat "$TMP/wind3x.log" >&2
    echo "U-Boot did not enumerate" >&2
    exit 1
fi
kill "$WIND_PID" 2>/dev/null || true
wait "$WIND_PID" 2>/dev/null || true
WIND_PID=

for ((i=0; i<30; i++)); do
    [ -e "$TTY" ] && break
    sleep 1
done
[ -e "$TTY" ] || { echo "U-Boot ACM port $TTY not found" >&2; exit 1; }

pad64() {
    python3 -I -c 'import sys; d=open(sys.argv[1],"rb").read(); open(sys.argv[2],"wb").write(d+b"\0"*(-len(d)%64))' "$1" "$2"
}

pad64 "$UBOOT_SHELL" "$TMP/uboot.bin"
pad64 "$BOOTLOADER" "$TMP/bootloader.bin"

"${SUDO[@]}" python3 -I "$D/ubsh.py" -d "$TTY" -t 20 \
    "mw.l 0x0a000000 0 0x300000" "mw.l 0x0af00000 0 4" >/dev/null
"${SUDO[@]}" python3 -I "$D/ymodem.py" -d "$TTY" "$TMP/uboot.bin" 0x0ae00000
"${SUDO[@]}" python3 -I "$D/ymodem.py" -d "$TTY" "$TMP/bootloader.bin" 0x09000000
echo "Starting the installed Rockbox files from the N5G loader..."
"${SUDO[@]}" python3 -I "$D/ubsh.py" -d "$TTY" -t 5 "go 0x09000000" || true
