# Safe loader relocation evidence

This directory holds a separate 64-MiB SDRAM link of the current Rockbox
bootloader and two ARM1176 rehosts with the Accessories candidate's final
target changed to that link address. The original argument-only rehost ends at
a sentinel. A second rehost copies the embedded real loader bytes to the
target and stops under GDB at the loader entry before executing them.

See the German analysis report
[`OSOS-accessories-safe-loader-relocation-followup-2026-10-30.md`](../../OSOS-accessories-safe-loader-relocation-followup-2026-10-30.md)
and [`results.txt`](results.txt) for the conclusion and limits.

The large linker map and QEMU trace are stored as deterministic gzip files;
`gzip -dc <file>.gz` restores their original text. The rehost command below
recreates the uncompressed trace before archiving.

## Reproduction

From `rb-n5g/`:

```sh
make -C build-n5g-blramdisk -j16 /home/sebastian/ipod-re/rb-n5g/build-n5g-blramdisk/bootloader.elf

/home/sebastian/ipod-re/toolchain/bin/arm-elf-eabi-gcc \
  -W -Wall -Wextra -Wundef -Os -nostdlib -ffreestanding \
  -Wstrict-prototypes -pipe -std=gnu11 -funit-at-a-time \
  -fno-delete-null-pointer-checks -fno-strict-overflow -fno-common \
  -mcpu=arm1176jz-s -mno-unaligned-access -fomit-frame-pointer \
  -Wno-pointer-sign -Wno-override-init -Wimplicit-fallthrough=0 \
  -masm-syntax-unified -o utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.elf \
  build-n5g-blramdisk/bootloader/common.o \
  build-n5g-blramdisk/bootloader/format.o \
  build-n5g-blramdisk/bootloader/snprintf.o \
  build-n5g-blramdisk/bootloader/ipodnano4g.o \
  build-n5g-blramdisk/apps/bitmaps/mono/default_icons.o \
  build-n5g-blramdisk/apps/bitmaps/native/rockboxlogo.240x74x16.o \
  -Lbuild-n5g-blramdisk/firmware -lfirmware \
  -Lbuild-n5g-blramdisk/lib -lfirmware -lunwarminder -larm_support -lfixedpoint \
  -lfirmware -lunwarminder -larm_support -lfixedpoint -lgcc \
  -Tutils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/boot-safe.link \
  -Wl,--gc-sections \
  -Wl,-Map,utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.map

/home/sebastian/ipod-re/toolchain/bin/arm-elf-eabi-objcopy -O binary \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.elf \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.bin

clang --target=arm-linux-gnueabi -mcpu=arm1176jzf-s -nostdlib -no-pie -fno-pie -fuse-ld=lld \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.ld \
  -Wl,--build-id=none \
  -o utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.elf \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.S

prlimit --core=0 -- qemu-arm -cpu arm1176 -d in_asm,cpu \
  -D utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.qemu-trace.log \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.elf \
  > utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.stdout.bin

gzip -n -9 \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/bootloader-safe.map \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_rehost_20261030.qemu-trace.log
```

The candidate copy is made by replacing exactly the three occurrences of the
little-endian word `0x09000000` with `0x0bf00000` in the original 704-byte
input. Neither candidate was written to the device.

## Full loader-copy rehost

`OSOS_accessories_parser_real_fat_entry_topram_copy_rehost_20261030.S` and
`.ld` extend the argument-only rehost. Its successful loader-read stub copies
all `0x10f80` bytes from `bootloader-safe.bin` to `0x0bf00000`. A NOLOAD span
keeps the complete destination mapped writable in QEMU. The run is stopped by
GDB at `0x0bf00000`; `bootloader-copy-postcleanup.bin` is the memory dump from
that breakpoint. It compares byte-for-byte equal to `bootloader-safe.bin`.
`marker_timeline.gdb.txt` records byte `0x00` at `0x0bf00040` immediately
before the read and byte `0x08` after the copy, showing that the old sentinel
marker was an earlier parser state.

The file-read callback is still a harness stub backed by an embedded image;
the genuine FAT/VFS/ATA path, live DRAM occupancy, bootloader execution and
hardware handoff are not tested. `bootloader_safe_entry_20261030.txt` records
the relocated entry disassembly and relevant linker symbols. The first
failed copy attempt is retained in `copy_fault_probe.gdb.txt` and
`copy_fault_probe.qemu.log.gz`; the maps show the harness originally mapped
only one writable page at the target.

The linked startup later installs a 16-KiB translation table at
`0x09ffc000..0x0a000000` because this build keeps `MEMORYSIZE=32`; that range
overlaps the calculated OSOS heap. The bootloader clears its relocated BSS at
`0x0bf20000..0x0bfbfd00`. The table overlap is only consistent with a
one-way handoff that abandons OSOS. These writes are not exercised by the
GDB-stopped copy rehost.

Build the extended copy rehost from `rb-n5g/` with:

```sh
clang --target=arm-linux-gnueabi -mcpu=arm1176jzf-s -nostdlib -no-pie \
  -fno-pie -fuse-ld=lld \
  -Wl,-T,utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_copy_rehost_20261030.ld \
  -Wl,--build-id=none \
  -o utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_copy_rehost_20261030.elf \
  utils/ipodnano5g/analysis/evidence/accessories-safe-loader-relocation-2026-10-30/OSOS_accessories_parser_real_fat_entry_topram_copy_rehost_20261030.S
```

`loader_copy.gdb.txt` records the GDB breakpoint and dump command; the
matching compressed QEMU instruction trace is `loader_copy.qemu.log.gz`.
`marker_timeline.gdb.txt` records the pre-read marker and final entry byte.
