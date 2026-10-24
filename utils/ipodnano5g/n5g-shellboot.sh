#!/bin/bash
# n5g-shellboot.sh <rockbox-raw.bin> [disk.img]
#
# From the U-Boot USB-ACM shell (05ac:2137, /dev/ttyACM0): load a copy of
# U-Boot for Rockbox to return to (DEVLOOP_UBOOT_ADDR), the RAM disk and
# Rockbox over YMODEM, then start Rockbox. Rockbox comes back to the shell on
# reboot, panic, or when USB storage stays silent (devloop-nano5g.c), leaving
# a report that n5g-mailbox.py reads.
set -euo pipefail
RB=${1:?usage: n5g-shellboot.sh <rockbox-raw.bin> [disk.img]}
DISK=${2:-}
D=$(dirname "$(realpath "$0")")
UBOOT=${UBOOT_SHELL:-$HOME/ipod-re/ref/build-uboot-n5gwip/u-boot.bin}
TTY=${TTY:-/dev/serial/by-id/usb-freemyipod_U-Boot_firmware_dbg-if00}
SUDO=$([ "$(id -u)" = 0 ] || echo sudo)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

send() {    # send <file> <addr>, one retry
    $SUDO python3 -I "$D/ymodem.py" -d "$TTY" "$1" "$2" | tail -1 && return 0
    echo "retrying $2"; sleep 2
    $SUDO python3 -I "$D/ubsh.py" -d "$TTY" -t 3 "" >/dev/null 2>&1 || true
    $SUDO python3 -I "$D/ymodem.py" -d "$TTY" "$1" "$2" | tail -1
}

pad() {     # pad to whole cache lines, so loady's cache flush covers it all
    python3 -I -c 'import sys; d=open(sys.argv[1],"rb").read(); open(sys.argv[2],"wb").write(d+b"\0"*(-len(d)%64))' "$1" "$2"
}

$SUDO python3 -I "$D/ubsh.py" -d "$TTY" -t 20 "mw.l 0x0a000000 0 0x300000" "mw.l 0x0af00000 0 4" >/dev/null
pad "$UBOOT" "$T/uboot.bin"
send "$T/uboot.bin" 0x0ae00000
if [ -n "$DISK" ]; then
    python3 -I -c 'import sys; d=open(sys.argv[1],"rb").read().rstrip(b"\0"); open(sys.argv[2],"wb").write(d+b"\0"*(-len(d)%4096))' "$DISK" "$T/disk.bin"
    send "$T/disk.bin" 0x0a000000
fi
pad "$RB" "$T/rb.bin"
send "$T/rb.bin" 0x08000000
$SUDO python3 -I "$D/ubsh.py" -d "$TTY" -t 2 "go 0x08000000" >/dev/null 2>&1 || true
echo "Rockbox started"
