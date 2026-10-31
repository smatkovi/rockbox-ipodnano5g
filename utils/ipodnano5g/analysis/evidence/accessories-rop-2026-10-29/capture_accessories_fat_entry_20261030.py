#!/usr/bin/env python3
"""Read only the FAT sectors containing accessories.reg's cluster entry."""
import hashlib
import os
import stat
import struct
from pathlib import Path

BY_ID = Path('/dev/disk/by-id/usb-Apple_iPod_000A27001E9B0F77-0:0-part1')
OUT = Path('/home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/accessories-rop-2026-10-29')
CLUSTER = 179788
EXPECTED = (4096, 2, 32, 2, 3901312, 1904, 2)

if os.geteuid() != 0:
    raise SystemExit('Run via sudo; the block device is opened O_RDONLY only.')
if 'SUDO_UID' not in os.environ or 'SUDO_GID' not in os.environ:
    raise SystemExit('Refusing to create evidence as root without the invoking user IDs.')

fd = os.open(BY_ID, os.O_RDONLY | os.O_CLOEXEC)
try:
    st = os.fstat(fd)
    if not stat.S_ISBLK(st.st_mode):
        raise SystemExit('Refusing: stable Apple iPod path is not a block device.')
    bpb = os.pread(fd, 4096, 0)
    if len(bpb) != 4096 or bpb[510:512] != b'\x55\xaa':
        raise SystemExit('Refusing: BPB sector length or boot signature is unexpected.')

    bps = struct.unpack_from('<H', bpb, 11)[0]
    spc = bpb[13]
    reserved = struct.unpack_from('<H', bpb, 14)[0]
    nfats = bpb[16]
    total = struct.unpack_from('<I', bpb, 32)[0]
    fatsz = struct.unpack_from('<I', bpb, 36)[0]
    extflags = struct.unpack_from('<H', bpb, 40)[0]
    root = struct.unpack_from('<I', bpb, 44)[0]
    geometry = (bps, spc, reserved, nfats, total, fatsz, root)
    if geometry != EXPECTED:
        raise SystemExit(f'Refusing changed/unexpected volume geometry: {geometry!r}')

    ratio = bps // 512
    data_start = (reserved + nfats * fatsz) * ratio
    cluster_count = (total - (reserved + nfats * fatsz)) // spc
    max_cluster = cluster_count + 1
    mirrored = (extflags & 0x80) == 0
    active_copy = 0 if mirrored else extflags & 0x0f
    if not mirrored and active_copy >= nfats:
        raise SystemExit(f'Refusing invalid active FAT selector {active_copy} for {nfats} FATs')

    fat_size_512 = fatsz * ratio
    entry_pos = CLUSTER * 4
    sector_in_fat = entry_pos // 512
    byte_offset = entry_pos % 512
    captured = []
    for copy in range(nfats):
        fat_base = reserved * ratio + copy * fat_size_512
        lba = fat_base + sector_in_fat
        sector = os.pread(fd, 512, lba * 512)
        if len(sector) != 512:
            raise SystemExit(f'Refusing short read for FAT copy {copy} at LBA 0x{lba:x}')
        raw = struct.unpack_from('<I', sector, byte_offset)[0]
        captured.append((copy, fat_base, lba, raw, raw & 0x0fffffff, sector))
finally:
    os.close(fd)

# Drop to the invoking user before writing any persistent local evidence.
uid = int(os.environ['SUDO_UID'])
gid = int(os.environ['SUDO_GID'])
os.setgroups([])
os.setgid(gid)
os.setuid(uid)

lines = [
    'Read-only capture of FAT32 allocation entries for accessories.reg',
    'date=2026-10-30',
    f'device_by_id={BY_ID.name}',
    'partition_read=O_RDONLY; no mount; no partition writes; no USB/DFU query',
    f'bpb_first_4096_sha256={hashlib.sha256(bpb).hexdigest()}',
    f'bytes_per_sector={bps} sectors_per_cluster={spc} reserved_sectors={reserved}',
    f'fat_count={nfats} fat_size_sectors={fatsz} total_sectors={total} extflags=0x{extflags:04x} root_cluster={root}',
    f'data_start_lba_512=0x{data_start:x} blocks_per_cluster_512={spc * ratio} max_cluster=0x{max_cluster:x}',
    f'fat_mirrored={str(mirrored).lower()} active_copy={"all mirrored copies" if mirrored else active_copy}',
    f'cluster={CLUSTER} entry_byte_offset=0x{byte_offset:x} sector_index_in_each_fat=0x{sector_in_fat:x}',
]
for copy, fat_base, lba, raw, masked, sector in captured:
    filename = f'OSOS_accessories_FAT_cluster_{CLUSTER}_copy{copy}_lba_{lba:08x}_20261030.bin'
    path = OUT / filename
    with path.open('xb') as f:
        f.write(sector)
    lines.append(f'copy{copy}_fat_base_lba=0x{fat_base:x} entry_lba=0x{lba:x} raw=0x{raw:08x} masked=0x{masked:07x}')
    lines.append(f'copy{copy}_sector_sha256={hashlib.sha256(sector).hexdigest()} file={filename}')
if mirrored and len({item[3] for item in captured}) != 1:
    lines.append('warning=mirrored FAT copies disagree at this entry')
if not mirrored:
    active_raw = captured[active_copy][3]
    lines.append(f'active_fat_entry_raw=0x{active_raw:08x} masked=0x{active_raw & 0x0fffffff:07x}')

result = OUT / 'OSOS_accessories_FAT_cluster_179788_capture_20261030.txt'
with result.open('x') as f:
    f.write('\n'.join(lines) + '\n')
print('\n'.join(lines))
