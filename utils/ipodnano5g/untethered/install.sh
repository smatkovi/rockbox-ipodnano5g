#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [--restore] IPOD_MOUNT" >&2
    exit 2
}

mode=install
if [[ ${1:-} == --restore ]]; then
    mode=restore
    shift
fi
[[ $# == 1 ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mount_dir=$(realpath -- "$1")
[[ -d $mount_dir ]] || { echo "mount path is not a directory" >&2; exit 1; }
mountpoint -q -- "$mount_dir" || { echo "path is not a mount point" >&2; exit 1; }

fstype=$(findmnt -n -o FSTYPE --target "$mount_dir")
[[ $fstype == vfat || $fstype == fat ]] || {
    echo "expected a FAT iPod volume, found: $fstype" >&2
    exit 1
}
options=$(findmnt -n -o OPTIONS --target "$mount_dir")
[[ ,$options, == *,rw,* ]] || { echo "iPod volume is read-only" >&2; exit 1; }

device_dir=$mount_dir/iPod_Control/Device
backup_dir=$mount_dir/.rockbox-n5g-backup
[[ -d $device_dir ]] || { echo "not an iPod data volume" >&2; exit 1; }

if [[ $mode == restore ]]; then
    [[ -f $backup_dir/READY && -f $backup_dir/accessories.reg ]] || {
        echo "no complete Rockbox backup found" >&2
        exit 1
    }
    if [[ -f $backup_dir/BOOT.BIN ]]; then
        cp -- "$backup_dir/BOOT.BIN" "$mount_dir/BOOT.BIN"
    elif [[ -f $backup_dir/BOOT.BIN.absent ]]; then
        if [[ -f $mount_dir/BOOT.BIN ]]; then
            cmp -s -- "$script_dir/BOOT.BIN" "$mount_dir/BOOT.BIN" || {
                echo "BOOT.BIN changed since install; refusing to remove it" >&2
                exit 1
            }
            rm -- "$mount_dir/BOOT.BIN"
        fi
    else
        echo "backup is incomplete" >&2
        exit 1
    fi
    cp -- "$backup_dir/accessories.reg" "$device_dir/accessories.reg"
    sync
    echo "Original files restored; backup kept in $backup_dir"
    exit 0
fi

[[ -f $device_dir/accessories.reg ]] || {
    echo "accessories.reg not found" >&2
    exit 1
}
[[ -f $mount_dir/.rockbox/rockbox.ipod ]] || {
    echo "install a Nano 5G Rockbox build first" >&2
    exit 1
}
[[ -f $mount_dir/.rockbox/n5g-ramdisk.img ]] || {
    echo "missing .rockbox/n5g-ramdisk.img" >&2
    exit 1
}
[[ $(stat -c %s -- "$mount_dir/.rockbox/n5g-ramdisk.img") == 8388608 ]] || {
    echo "n5g-ramdisk.img must be 8 MiB" >&2
    exit 1
}

(
    cd -- "$script_dir"
    printf '%s  %s\n' \
        b19180df8a20ef7e5496885bf227827623d6c3115adef0e4d47ed2efe2e6f78e accessories.reg \
        ba355bf5771a686a07829d3df45772c2d4bc9c33ca9cf0346d17408a5f20b4b2 BOOT.BIN \
        | sha256sum --check --status
) || { echo "payload checksum mismatch" >&2; exit 1; }

if [[ ! -e $backup_dir ]]; then
    mkdir -- "$backup_dir"
    cp -- "$device_dir/accessories.reg" "$backup_dir/accessories.reg"
    if [[ -e $mount_dir/BOOT.BIN ]]; then
        cp -- "$mount_dir/BOOT.BIN" "$backup_dir/BOOT.BIN"
    else
        : > "$backup_dir/BOOT.BIN.absent"
    fi
    : > "$backup_dir/READY"
elif [[ ! -f $backup_dir/READY ]]; then
    echo "incomplete backup directory exists: $backup_dir" >&2
    exit 1
elif [[ ! -f $backup_dir/accessories.reg ]] || \
     { [[ ! -f $backup_dir/BOOT.BIN ]] && [[ ! -f $backup_dir/BOOT.BIN.absent ]]; }; then
    echo "backup is incomplete: $backup_dir" >&2
    exit 1
fi

cp -- "$script_dir/accessories.reg" "$device_dir/accessories.reg"
cp -- "$script_dir/BOOT.BIN" "$mount_dir/BOOT.BIN"
sync
cmp -s -- "$script_dir/accessories.reg" "$device_dir/accessories.reg"
cmp -s -- "$script_dir/BOOT.BIN" "$mount_dir/BOOT.BIN"
echo "Installed. Safely eject, unplug USB, and restart the iPod."
