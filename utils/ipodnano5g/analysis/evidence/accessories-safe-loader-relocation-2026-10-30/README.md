# Safe loader relocation evidence

This directory holds a separate 64-MiB SDRAM link of the current Rockbox
bootloader and an ARM1176 rehost with the Accessories candidate's final target
changed to that link address. The rehost still ends at a loader sentinel; it
does not load or execute the bootloader bytes.

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
