# Rockbox on the iPod nano 5G (S5L8730) — experimental

Status (2026-10-24): the Rockbox main firmware boots **tethered from RAM** on
an iPod nano 5G (16 GB, Apple firmware 1.0.2). The Rockbox USB runtime was
verified from the host, but no persistent installation is available; a cold
restart returns to Apple's firmware.

| Part | State |
|---|---|
| Boot | tethered: BootROM DFU → wInd3x → Apple's WTF (defanged) → U-Boot loader → Rockbox |
| CPU / SoC | S5L8730 shares the S5L8720 (nano 4G) code paths; clock gates verified identical |
| LCD | panel `38b3`, 240×376, controller as on the S5L8702; frames by PIO |
| Clickwheel | works with the existing `button-clickwheel.c` (protocol measured) |
| Storage | Host observed an 8-MiB RAM disk and a 15.1-GiB read-only iPod LUN exposing the full logical FTL; a separate data-only LUN was not enumerated |
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
the closest reference. An untethered boot path is open.
