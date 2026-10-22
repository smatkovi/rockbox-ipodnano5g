# Rockbox on the iPod nano 5G (S5L8730) — experimental

Status (2026-10-22): the Rockbox main firmware boots **tethered from RAM** on
an iPod nano 5G (16 GB, Apple firmware 1.0.2) and the menus can be navigated
with the clickwheel. Nothing is installed on the iPod; after a restart it is
back to Apple's firmware.

| Part | State |
|---|---|
| Boot | tethered: BootROM DFU → wInd3x → Apple's WTF (defanged) → U-Boot loader → Rockbox |
| CPU / SoC | S5L8730 shares the S5L8720 (nano 4G) code paths; clock gates verified identical |
| LCD | panel `38b3`, 240×376, controller as on the S5L8702; frames by PIO |
| Clickwheel | works with the existing `button-clickwheel.c` (protocol measured) |
| Storage | RAM disk at `0x0a000000` (12 MiB FAT16 image), no NAND yet |
| PMU, backlight, battery, hold switch | stubs (backlight stays on, battery faked) |
| Audio, USB, RTC | not driven |
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
unzip rockbox.zip -d disk-root      # trim .rockbox/rocks to fit 12 MiB
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

`ubsh.py` talks to the U-Boot USB-ACM shell variant, for poking at hardware
(`md`, `mw`, `loads` + `go` for small test payloads).

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
- The clickwheel is a Cypress or Synaptics controller (Apple diags carry
  updaters for both); NAND seen: Toshiba `98 d7 94 32`.

## Next steps

PMU (backlight, battery, hold switch), audio codec (Cirrus Logic CLI1480A),
USB, and the NAND/FMSS driver with Apple's VSVFL/FTL — the nano 4G series is
the closest reference. An untethered boot path is open.
