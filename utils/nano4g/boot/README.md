# iPod nano 4G bootloader

This bootloader loads `.rockbox/rockbox.ipod` from a FAT partition using the
read-only NAND/FTL driver. Hold MENU (or turn on the hold switch) for the
original firmware, or SELECT+PLAY for disk mode. These options load the
corresponding image already stored in the device's firmware partition.

The bootloader includes its own small SRAM startup stage. It initializes the
clock, GPIO, PMU and SDRAM hardware, then enters Rockbox's normal relocation
code. The bootloader runs at `0x09000000`, leaving `0x08000000` available for
Rockbox or the original firmware. This stage is built from C and assembly
source under `bootloader/nano4g-startup`; no external bootstub is required.

## Build the unsigned payload

Run from the Rockbox source root. An ARM bare-metal GCC/binutils toolchain and
Python 3 are required. The example uses the `arm-none-eabi-` compiler prefix;
substitute your installed prefix consistently if necessary.

```sh
mkdir build-nano4g-boot
cd build-nano4g-boot
../tools/configure --target=81 --type=b --compiler-prefix=arm-none-eabi-
make -j4
cd ..
python3 utils/nano4g/boot/build_payload.py \
  build-nano4g-boot/bootloader.bin \
  build-nano4g-boot/bootloader-native.bin
```

`bootloader-native.bin` contains the SRAM stage, a 16-byte payload descriptor,
and the compiled bootloader. It is **not** an installable image. Output paths
must be new; the tools refuse to overwrite an existing file.

## Make one image for DFU and reserved NAND

The combined format needs a 16-byte GID AES authentication value from the
S5L8720 on the device. The later reserved-area installer contribution provides
that service over USB. With that installer already running:

```sh
python3 utils/nano4g/boot/make_image.py \
  build-nano4g-boot/bootloader-native.bin \
  build-nano4g-boot/bootloader-dual.img1
```

The same `bootloader-dual.img1` bytes are intended for DFU transfer and the
reserved NAND installer. Image creation does not erase or write NAND. The
installer's README supplies its bootstrap, USB, backup and write commands;
make a verified backup before replacing the reserved image. Validate the new
bootloader through DFU before installing it persistently.

At the bootloader-only stage of the patch series, or with another GID AES
service, the two offline interfaces avoid a dependency on the later installer:

```sh
python3 utils/nano4g/boot/make_image.py \
  build-nano4g-boot/bootloader-native.bin --print-header-digest
```

Encrypt the displayed 16 bytes using AES-128-CBC, the device's hardware GID
key and a zero IV, without padding. Save the 16 result bytes as `header-auth.bin`
(binary bytes, not hexadecimal text), then run:

```sh
python3 utils/nano4g/boot/make_image.py \
  build-nano4g-boot/bootloader-native.bin \
  build-nano4g-boot/bootloader-dual.img1 --header-auth header-auth.bin
```

That authentication value belongs to the exact header used to produce the
digest. Obtain it again after changing payload size. The container uses the
GPL pwnage certificate chain already maintained in `utils/mks5lboot/mkdfu.c`;
no firmware file or downloaded certificate is an input.

## Why the same file can enter through both paths

The outer IMG1 header occupies `0x600` bytes. The body contains a duplicate
`0x50`-byte header prefix, followed by our SRAM stage and bootloader, then the
pwnage certificate. The certificate's entry address is `0x22000050`.

* NAND loads the body at SRAM base, placing our stage at that entry address.
* DFU retains the outer header at SRAM base. The instruction at header offset
  `0x50` branches to `0x22000650`, where the same stage begins in this layout.

The first-stage code uses PC-relative addressing to locate its descriptor and
payload, moves itself to `0x22026000`, initializes SDRAM, and jumps back to the
payload. Rockbox's entry code relocates itself to SDRAM. The complete file is
limited to 120 KiB, below the ROM's maximum, and no linker address is changed
between DFU and NAND packaging.

This format differs from the existing `mks5lboot --mkdfu-n4g` output. Do not
substitute that command for `make_image.py` or wrap an already built `.img1`.

## Original-firmware handoff

`applefw.c` reads the firmware partition through the driver's raw FTL accessor,
finds `disk` or `osos`, bounds-checks the IMG1 header, and decrypts
format-3 bodies using the hardware AES engine. It leaves the image unmodified.
The bootloader constructs the system-configuration record from this device's
private SysCfg sectors and hardware geometry, rather than embedding a dump.

Before jumping it disconnects USB, masks interrupts, restores clock selectors,
resets the interrupt-service state, and restores the polled I2C configuration.
The final assembly helper keeps the entry pointer in a register before changing
from SYS to SVC mode. It cleans and disables D-cache without any intervening
C stack accesses; keeping write-back caching active would conflict with the
original image's own relocation/invalidation sequence.

The red band is only a last pre-jump marker. It does not establish that the
next firmware has reached its disk-mode UI or enumerated USB.

## Scope and limitations

NAND filesystem access is read-only in this contribution. Rockbox can load its
main firmware, but this does not enable saving settings or general FTL writes.
Original firmware options require intact images in the device's firmware
partition; replacing its reserved bootloader does not create those images.

This cleaned contribution preserves the independently developed startup and
handoff fixes, but its rebuilt artifacts still require physical-device
validation. Treat an absent USB disk-mode device or a stopped startup as a
failure rather than repeating a NAND erase/install automatically.
