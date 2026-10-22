#!/bin/bash
# n5g-boot.sh <rockbox-raw.bin> [disk.img]
#
# Tethered boot of Rockbox on an iPod nano 5G:
#   BootROM DFU -> wInd3x (haxed DFU) -> Apple's WTF, defanged (sets up clocks
#   and SDRAM) -> U-Boot loader -> DFU upload of Rockbox (0x08000000) and the
#   RAM disk image (0x0a000000) -> go 0x08000000
#
# Put the iPod in DFU mode (hold MENU+SELECT through the Apple logo until the
# screen stays black) while this waits. Needs root for USB access.
#
# Environment: WIND3X (wInd3x binary), UBOOT (loader-variant u-boot.bin).
set -u
RB=${1:?usage: n5g-boot.sh <rockbox-raw.bin> [disk.img]}
DISK=${2:-}
WIND3X=${WIND3X:-$HOME/ipod-re/ref/wInd3x-upstream/wInd3x}
UBOOT=${UBOOT:-$HOME/ipod-re/ref/build-uboot-n5gload/u-boot.bin}
SUDO=$([ "$(id -u)" = 0 ] || echo sudo)

wait_usb() {   # wait_usb <vid:pid> <seconds>
    for _ in $(seq 1 "$2"); do
        lsusb -d "$1" >/dev/null 2>&1 && return 0
        sleep 1
    done
    return 1
}

echo "Waiting for the iPod in DFU mode (05ac:1231)..."
wait_usb 05ac:1231 1800 || { echo "no DFU device"; exit 1; }
command -v paplay >/dev/null && paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
sleep 2

echo "Starting the U-Boot loader through wInd3x..."
$SUDO env HOME="$HOME" XDG_DATA_HOME="$HOME/.local/share" \
    timeout 150 "$WIND3X" cfw run "$UBOOT" 2>&1 | grep -v "Error when sending" | tail -3

echo "Waiting for the U-Boot DFU device (05ac:2137)..."
wait_usb 05ac:2137 60 || { echo "U-Boot did not come up"; exit 1; }
sleep 1

$SUDO dfu-util -d 05ac:2137 -a rockbox -D "$RB" 2>&1 | grep -E "done|rror" | tail -2
if [ -n "$DISK" ]; then
    # U-Boot zeroes the RAM disk first, so only the used part of the image is
    # sent: trailing zero bytes are cut off
    TRIM=$(mktemp)
    python3 -I -c 'import sys; d=open(sys.argv[1],"rb").read().rstrip(b"\0"); open(sys.argv[2],"wb").write(d+b"\0"*(-len(d)%4096))' "$DISK" "$TRIM"
    T0=$(date +%s)
    $SUDO timeout 300 dfu-util -d 05ac:2137 -a disk -D "$TRIM" 2>&1 | grep -E "done|rror|MANIFEST" | tail -2
    echo "disk image: $(stat -c %s "$TRIM") bytes in $(( $(date +%s) - T0 )) s"
    rm -f "$TRIM"
fi
echo "Starting Rockbox..."
$SUDO dfu-util -d 05ac:2137 -a rockbox -e >/dev/null 2>&1
echo "done"
