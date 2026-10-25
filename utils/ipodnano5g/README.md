# Rockbox on the iPod nano 5G (S5L8730) — experimental

Status (2026-10-24): the Rockbox main firmware boots **tethered from RAM** on
an iPod nano 5G (16 GB, Apple firmware 1.0.2). The current Rockbox files are
installed on the internal FAT volume, but there is still no persistent
cold-start entry point; a cold restart returns to Apple's firmware.

| Part | State |
|---|---|
| Boot | tethered: BootROM DFU → wInd3x → Apple's WTF (defanged) → U-Boot loader → Rockbox |
| CPU / SoC | S5L8730 shares the S5L8720 (nano 4G) code paths; clock gates verified identical |
| LCD | panel `38b3`, 240×376, controller as on the S5L8702; frames by PIO |
| Clickwheel | works with the existing `button-clickwheel.c` (protocol measured) |
| Storage | Host observed an 8-MiB RAM disk and a 15.1-GiB read-only iPod LUN exposing the full logical FTL; the N5G bootloader now maps the nested Apple data-disk/FAT layout and a live mount probe passed |
| PMU (Dialog D1759, as on the nano 4G) | battery ADC and hold switch over I2C; backlight brightness over the SWIF single-wire link |
| Audio | works: CS42L58 (driven like the CS42L55) on I2S2, DMAC0 request 0, codec as clock master |
| USB | mass-storage and CDC-ACM enumerate in the RAM boot; CDC is log-only, and the iPod LUN is host-read-only |
| RTC, charging | not driven |
| Known bug | System → Rockbox Info hangs |

This branch is based on Viktor Krapivin's nano 4G series on the Rockbox
Gerrit (changes 8189–8195), which brings the S5L8720/ARM1176 support the
nano 5G reuses.

## How it boots

The S5L8730 has no Rockbox-usable untethered entry yet. Apple's recovery
stage (WTF), defanged by wInd3x, sets up clocks and the 64 MiB SDRAM and runs
an unsigned payload. That payload is a small U-Boot (freemyipod's `n5g-wip`
branch with a loader environment) which accepts Rockbox and the RAM disk over
DFU and jumps to Rockbox:

```
mw.l 0x0a000000 0 0x300000; dfu 0 ram 0; dcache off; icache off; go 0x08000000
dfu_alt_info = rockbox ram 0x08000000 0x1000000; disk ram 0x0a000000 0xc00000
```

U-Boot changes (USB-ACM shell, watchdog `reset_cpu`, loader environment):
https://github.com/smatkovi/u-boot, branch `n5g-shell`.

## Build

```sh
mkdir build-n5g && cd build-n5g
../tools/configure        # target 82 (Nano 5G), type n (normal)
make -j$(nproc) && make zip
arm-elf-eabi-objcopy -O binary rockbox.elf rockbox-raw.bin
```

RAM disk image (FAT16 without partition table; Rockbox mounts it as a
"superfloppy"):

```sh
unzip rockbox.zip -d disk-root      # trim it: DFU runs at ~55 KB/s
truncate -s 12M disk.img
mkfs.vfat -F 16 -S 512 -n NANO5G disk.img
# loop-mount disk.img and copy disk-root/.rockbox into it
```

## Run

Needs [wInd3x](https://github.com/freemyipod/wInd3x) (Linux only for the
nano 5G), `dfu-util` and the U-Boot loader build:

```sh
utils/ipodnano5g/n5g-boot.sh build-n5g/rockbox-raw.bin build-n5g/disk.img
```

Then put the iPod in DFU mode: connected by USB, hold MENU+SELECT through the
Apple logo until the screen stays black.

For a RAM test that can return to the U-Boot shell, start the shell-enabled
U-Boot through wInd3x, wait for its USB-ACM console (`05ac:2137`), then run:

```sh
UBOOT_SHELL=/path/to/u-boot.bin \
  utils/ipodnano5g/n5g-shellboot.sh build-n5g/rockbox-raw.bin build-n5g/disk.img
```

This variant copies U-Boot to SDRAM before starting Rockbox. On the tested
unit, ejecting only the 8-MiB RAM disk (`eject /dev/sda`) returned to a
responsive U-Boot shell with the `DEVLOOP_HOST_EJECT` reason in its mailbox.
Both methods are tethered RAM boots; neither installs firmware in NAND or NOR.

`ubsh.py` talks to the U-Boot USB-ACM shell variant, for poking at hardware
(`md`, `mw`, `loads` + `go` for small test payloads).

## Read-only FTL backup view

The target configuration declares three storage drives: a RAM disk, the
NAND data area, and a read-only view of logical FTL pages starting at LPN 0.
The generic USB code intends to map these to LUNs 0, 1, and 2; its “USB skip
first drive” option shifts the NAND LUNs down by one. The full FTL view
includes the logical MBR, firmware area, and data area; each 8192-byte FTL
page maps to sixteen 512-byte sectors. It uses the Rockbox FTL reader and is
not a raw physical NAND image: spare/OOB bytes and physical block/bad-block
layout are omitted. `NAND_WRITABLE` remains undefined for Nano 5G, and storage
write requests are rejected. Host reads confirmed the MBR and FAT-region
sectors, but this is not a verified full backup or restore source.

In the 2026-10-24 host session Linux enumerated the RAM disk and one
15.1-GiB iPod LUN (`RO=1`). The MBR on that LUN listed the FAT partition at
start 49216 with 3901376 sectors; the 4096-byte BPB appeared at 512-byte LBA
393728 (8× the MBR start). That BPB had zero FAT size, root cluster, and
FSInfo fields. The FSInfo and backup boot sectors were erased-looking, and
the first FAT sector began with `0x00068401`, not the reserved FAT32 entries.
This matches the earlier Rockbox FAT-mount failure. No repair was attempted.

## N5G FAT data-disk mapping and Rockbox files

The flash FTL's outer MBR has a type `0x0c` entry starting at Apple LBA 49216
with 3901376 sectors, where these MBR units are 4096 bytes. This entry is an
Apple data-disk container, not the FAT boot sector. Its first LPN is
`49216 / 2 = 24608` because each 8192-byte FTL page contains two 4096-byte
Apple LBAs. The container has its own MBR: its FAT32 partition is type `0x0b`
at LBA 63. The bootloader exposes the container as 512-byte sectors, so the
inner partition begins at sector 504 (`63 * 8`).

A RAM-only probe of the revised `nand_find_data_start()` returned
`nand_get_data_start() = 0x6020` (24608), one NAND drive with 512-byte sectors
and 31,211,008 sectors, then `disk_mount_all() = 1`. It found the inner type
`0x0b` partition at sector 504 with 31,210,496 sectors. The probe returned to
U-Boot. This confirms the previous `No FAT partition found` error came from
treating the outer container as the FAT volume. The test did not write NAND or
NOR.

The Apple-exported FAT volume initially had no `/.rockbox/rockbox.ipod`. The
Rockbox package was built with `make -j16 zip` and copied to the otherwise
absent `/.rockbox` directory; no existing files were replaced. A later build
and 8-MiB RAM-disk image were also installed there. The current device files
and hashes are recorded under “RAM-disk root staging” below. The installed
file-start path from internal FAT has since been confirmed on the device.

## Apple OS fallback verified from RAM

The Apple firmware partition starts at MBR LBA 64 in 4096-byte units, while
Rockbox exposes NAND reads in 512-byte sectors. `applefw.c` now scales that
partition start by eight on Nano 5G; Nano 4G keeps its 512-byte MBR units. A
read-only capture of the 192-MiB firmware partition (SHA-256
`86a5aec173f8f9a00161ad50bdea237c73bd079800cada8786362fa908e59342`) contains
the expected STOP marker and an `osos` IMG1 entry. Its format-3 image has body
length `0x6f2624` and data length `0x6f3293`.

A RAM-only probe on the device returned `nand_init() == 0` and
`applefw_load("osos") == 0`; the decrypted body begins with a valid ARM branch.
The normal bootloader was then loaded at `0x09000000` from U-Boot, with the RAM
disk's first sector cleared so it could not load a Rockbox boot file. The
device re-enumerated as Apple `05ac:1265` with Apple mass-storage, audio, and
HID interfaces; Linux saw the 14.9-GiB `SEBIPOD` volume. This verifies the
Apple OS hand-off from the RAM bootloader. The test did not record whether the
hold-switch branch or the missing-FAT fallback selected OSOS. No NAND/NOR
write, erase, or flash operation occurred. It does not establish an untethered
Rockbox entry point.

The existing Rockbox installers do not provide a Nano 5G persistent install:
`mks5lboot`'s dual-boot installer table contains Classic 6G and Nano 3G only;
Nano 5G appears in its USB DFU/WTF identification table, not its installer
table. `ipodpatcher` likewise has no N33/Nano 5G target. A cold-start loader
that the device accepts is still required.

## Nano 7G ByteFau1t is not a direct Nano 5G path

The public [iPEMS repository](https://github.com/TGRgitx/ipodexecutionmethodswapper)
describes ByteFau1t for Nano 7 (2012/2015): it changes the `rsrc` IMG1 format
byte from `0x04` to `0x03`. The N33 IPSW's `rsrc` image is format 4, but the
S5L8730 BootROM first authenticates the 64-byte IMG1 header, including that
format byte, before accepting format 3 or 4. It then hashes the body and checks
the X.509/RSA footer; format-3 decryption happens only after that check. A
one-byte `0x04`→`0x03` edit therefore invalidates the existing header tag and
does not bypass the Nano 5G verifier. This is based on the local S5L8730 ROM
disassembly; ByteFau1t has not been tested on Nano 5G, and this comparison
does not rule out other bugs or a different cold-start path. The untethered
entry point remains unproven.

## OSOS startup and media factory reachability (2026-10-25)

Static analysis confirms that the OSOS startup constructor list registers the
`0x3280` media factory and its callback. A direct call graph from all 257
constructors does not reach the callback's known lookup callers; indirect task
and virtual dispatch remain unresolved. The full evidence and generated tables
are in [the OSOS factory cold-start report](analysis/OSOS-factory-coldstart-2026-10-25.md).

## Hardware notes (measured on this unit)

- LCD controller at `0x38300000`, same registers as the S5L8702. Panel id
  (cmd `0x04`, 8-bit mode `0x80000c20`) reads `04 00 38 b3`. RGB565 frames in
  9-bit mode `0x81100db8`.
- Clickwheel controller at `0x3c200000`, clock gate 33 (freemyipod name "TW");
  init `WHEELTX = 0x8000023a` answers `0x8000023a`; wheel packets
  `0x8000001a` with touch bit 30, position bits 16–22 (0–0x5f), buttons
  SELECT 0x100, RIGHT 0x200, LEFT 0x400, PLAY 0x800, MENU 0x1000.
- Clock gates (PWRCON numbering gate*32+bit) match Rockbox's S5L8720 table:
  LCD 1, USB-OTG 2, NAND 5, ECC 9, DMAC0/1 11/12, wheel 33, SPI0 34,
  USB-PHY 35, I2C0 36, timer 37, I2C1 38, UART0 41, GPIO 44.
- Watchdog reset as on the S5L8702: write `0x100000` to `0x3c800000`.
- PMU: Dialog D1759 (Apple diags module `DxeD1759Diagnostic`) on I2C bus 0
  at 0xe6, register layout as on the nano 4G: battery = ADC channel 4
  (`0x40 = 0x54`, result in `0x41/0x42`, 2500..4500 mV), hold switch =
  status B (`0x05`) bit 0, clear when locked. I2C writes to LEDOUT (`0x30`)
  are ignored; the brightness goes over SWIF.
- SWIF (single-wire link to the PMU) at `0x3de00000`, clock gates 66 and
  149: reset `+0x04 = 1` until clear, `+0x00 = 0x1703`; channel 0 control
  `+0x14`, data `+0x18`; write = control 2, data
  `(reg & 0x7f) << 8 | 0x80 | value`, then set control bit 0 and wait for it
  to clear. Apple's diags enable it with SYSCTRLA (`0x0a`) bits 4..5 and SWIF
  register 8 = 0x80; SWIF register 9 then sets LEDOUT (0..255).
- Audio (Apple's DxeCS42L58, I2s, DevicePowerManagement, DxeD1759 modules,
  then measured): codec Cirrus Logic CS42L58 on I2C bus 0 at 0x94, its init
  sequence the CS42L55 one byte for byte. Supply: D1759 regulator 19 =
  register 0x21 ((mV - 1200) / 100, 1800 mV) and enable 0x11 bit 2. Reset:
  GPIO 14.4 (low, 10 us, high). Data: I2S2 at 0x3d400000 (clock gate 48),
  codec as clock master with Apple's TXCON 0x03100099; its clock pins
  12.1/12.2 are in function 3 by default. TX DMA: DMAC0 request 0, IRQ 16.
  MCLK 12 MHz = oscillator / 2 on CG16_AUD0..2.
- GPIO commands as in Apple's Gpio driver: pin id (port << 16) | pin, write
  (port << 16) | (pin << 8) | function to 0x3cf00240; functions 0xe/0xf =
  output low/high.
- The clickwheel is a Cypress or Synaptics controller (Apple diags carry
  updaters for both); NAND seen: Toshiba `98 d7 94 32`.

## Next steps

Charging (D1759, as on the nano 4G), audio codec (Cirrus Logic CLI1480A),
USB, and the NAND/FMSS driver with Apple's VSVFL/FTL — the nano 4G series is
the closest reference. An untethered boot path remains unproven.

## RAM-disk root staging (2026-10-24)

Rockbox panicked when it tried to write sector 2,983,370 with error `-3`.
The N5G `nand_write_sectors()` path deliberately returns `-3` before calling
`ftl_write()` because `NAND_WRITABLE` is undefined for this target; the
current port has no validated NAND program/erase implementation. This is a
driver guard, not a Linux permission or FAT mount error.

The normal Rockbox build uses `STORAGE_RAMDISK_FIRST`, so a writable FAT root
can live in an 8 MiB RAM disk loaded by the N5G bootloader from
`/.rockbox/n5g-ramdisk.img`. `load_n5g_ramdisk()` checks its exact size and
FAT16 geometry before starting Rockbox, and falls back to Apple OSOS if the
file is missing or invalid. The normal main image and the RAM disk are
installed on the user FAT volume with SHA-256 values
`65276d4bf5b88af3c2ff5701a21fa6cd6654e24b4f147d7e7c31395a7023ec16` and
`6fb9df06b8083f8d27d18fdc2bfd70be383c5306b4691d767ef5c9e43c3a0cf5`.
Before replacement, the previous `.rockbox` directory was copied to
`/home/sebastian/ipod-re/device-backup-20261024/.rockbox`.

The write was through Apple's ordinary USB mass-storage FAT volume. It was
not a raw NAND page program/erase or firmware flash. The bootloader RAM test
loaded at `0x09000000`, then entered Apple's OSOS because the RAM-disk image
was not yet present. That hand-off ends the U-Boot session; there is no
known host command that takes Apple OS back to BootROM DFU, so one physical
DFU key sequence is required to resume.

Successful installed-file boot, 2026-10-24 21:08 CEST: from the already
enumerated U-Boot console, YMODEM loaded a padded U-Boot return copy to
`0x0ae00000` and `build-n5g-blramdisk/bootloader.bin` to `0x09000000`; `go`
started the loader. USB then enumerated as `05ac:1265`, with product string
“Rockbox media player”. The user confirmed Rockbox multimedia mode. The host
saw the 8-MiB `NANO5G` RAM disk and the 14.9-GiB `SEBIPOD` partition with
`RO=1`. A read-only mount verified `/.rockbox/rockbox.ipod` (1,079,128 bytes,
SHA-256 `65276d4bf5b88af3c2ff5701a21fa6cd6654e24b4f147d7e7c31395a7023ec16`)
and `/.rockbox/n5g-ramdisk.img` (8,388,608 bytes, SHA-256
`6fb9df06b8083f8d27d18fdc2bfd70be383c5306b4691d767ef5c9e43c3a0cf5`). The
mount was removed afterward. This confirms Rockbox boots from its installed
FAT files when the custom loader is first run from RAM; it is still tethered.

The user reports that Hold was unlocked during all these runs, so the previous
boot records do not establish a locked-Hold→Apple-OS test. No Hold-locked test
was performed. The `n5g-installed-boot.sh` DFU-to-U-Boot wrapper itself was
not run end-to-end in this step; its serial selection now defaults to the
stable `/dev/serial/by-id/usb-freemyipod_U-Boot_firmware_dbg-if00` path rather
than ambiguous `/dev/ttyACM0`. The same `TTY` override is available in
`n5g-shellboot.sh`.

At the end of this test the iPod is in Rockbox USB/multimedia mode, not Apple
OS mode. All YMODEM transfers targeted SDRAM. No NAND/NOR raw write, erase, or
firmware flash occurred.

A separate `N5G_COLD_BOOT` build also completed after guarding its remaining
USB-storage devloop references. Its main image hash is
`1316fb438435014865def9c5bfe758196412a675db1c5189d35febdd1ac88ccc`; its
8 MiB RAM disk hash is
`956844ef3b63b31e7b74245a6f95fecc0cb6d7c91319ceeed3d4af698ab17131`.
This variant was not installed or hardware-tested. Neither build supplies a
persistent BootROM-to-Rockbox entry point: the verified start still depends
on wInd3x/DFU and a RAM-loaded U-Boot.

### Fresh bootloader rebuild and fallback review (2026-10-25)

After the later N5G bootloader-source changes, `make -j16` in
`build-n5g-blramdisk` rebuilt `bootloader/ipodnano4g.c` and produced
`bootloader.bin` (69,504 bytes, SHA-256
`7788923c3d9cfd12596ba42436ff378d37a1980e83e4678f010632289279096b`) and
`bootloader-ipodnano5g.ipod` (69,512 bytes, SHA-256
`38e4b8c9f1efe3c19c8c431fc2e94a43a5dc6ac41383eee4f475fc9732136718`).
Disassembly of the rebuilt ELF confirms that a failed FAT mount branches to
the signed OSOS hand-off, and that a failed PMU status read makes
`pmu_holdswitch_locked()` return true. The Hold check occurs before storage
initialization, so the locked-Hold path does not depend on the data FAT.

This is a source-and-binary check only. At the time of the rebuild the iPod
was still in U-Boot (`05ac:2137`), not DFU. No payload was started and no
device storage was touched; the Hold and no-FAT branches still need a hardware
run when returning to BootROM DFU is available. A fallback to Apple OS ends
the current U-Boot session, so it was not triggered while the user was away.
