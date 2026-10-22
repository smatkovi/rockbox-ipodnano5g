#!/bin/bash
# n5g-mkdisk.sh <rockbox.zip> <disk.img> [music files...]
#
# Build the nano 5G RAM disk image: an 8 MiB FAT16 "superfloppy" with a
# trimmed .rockbox (DFU uploads run at ~55 KB/s, so it is kept small) and
# optional music in /Music. Needs root for the loop mount.
set -eu
ZIP=$(realpath "$1"); IMG=$2; shift 2
SUDO=$([ "$(id -u)" = 0 ] || echo sudo)
T=$(mktemp -d)
trap '$SUDO umount "$T/mnt" 2>/dev/null || true; rm -rf "$T"' EXIT

mkdir -p "$T/root" "$T/mnt"
(cd "$T/root" && unzip -q "$ZIP")
R="$T/root/.rockbox"
rm -rf "$R/debug"
find "$R/langs" -type f ! -name english.lng ! -name deutsch.lng -delete
find "$R/codecs" -type f ! -name 'mpa.codec' ! -name 'flac.codec' ! -name 'vorbis.codec' \
     ! -name 'wav.codec' ! -name 'aac.codec' ! -name 'alac.codec' -delete
mv "$R/rocks" "$T/rocks.all"
mkdir -p "$R/rocks/games" "$R/rocks/apps" "$R/rocks/demos" "$R/rocks/viewers"
for g in 2048 brickmania bubbles jewels minesweeper pong rockblox snake sudoku wormlet spacerocks solitaire; do
    cp "$T/rocks.all/games/$g.rock" "$R/rocks/games/" 2>/dev/null || true
done
for a in calculator calendar stopwatch rockpaint text_editor; do
    cp "$T/rocks.all/apps/$a.rock" "$R/rocks/apps/" 2>/dev/null || true
done
for d in starfield plasma mosaique fire bounce; do
    cp "$T/rocks.all/demos/$d.rock" "$R/rocks/demos/" 2>/dev/null || true
done
for v in bmp.ovl gif.ovl imageviewer.rock jpeg.ovl jpegp.ovl png.ovl ppm.ovl text_viewer.rock \
         view_text.rock mpegplayer.rock properties.rock open_plugins.rock shortcuts_view.rock shortcuts_append.rock \
         credits.rock search.rock sort.rock file_picker.rock cue_playlist.rock db_folder_select.rock \
         rockbox-fonts.config wavview.rock pitch_screen.rock chip8.rock; do
    cp -r "$T/rocks.all/viewers/$v" "$R/rocks/viewers/" 2>/dev/null || true
done
cp "$T/rocks.all/viewers.config" "$R/" 2>/dev/null || true
if [ $# -gt 0 ]; then
    mkdir -p "$T/root/Music"
    cp "$@" "$T/root/Music/"
fi

rm -f "$IMG"
truncate -s 8M "$IMG"   # RAMDISK_SECTORS; the dev loop keeps images above
mkfs.vfat -F 16 -S 512 -s 2 -n NANO5G "$IMG" >/dev/null
$SUDO mount -o loop,uid="$(id -u)" "$IMG" "$T/mnt"
cp -r "$T/root/." "$T/mnt/"
sync
df -h "$T/mnt" | tail -1
