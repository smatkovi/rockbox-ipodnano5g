# iPod nano 4G reserved-region installer

USB recovery tool for backing up, installing and restoring the ROM boot area.
Runs from RAM. Hardware validation is pending.

The LCD shows startup, USB connection and operation progress. An error stays
on screen; the installer does not restart automatically.

Uses the NAND driver's chip table. Operations are restricted to CE0/block 0,
with 128 pages per block.

## Build and bootstrap

Run all commands below from the Rockbox source root. Requirements are a
bare-metal ARM GCC/binutils toolchain (`arm-none-eabi-` in these examples),
Python 3, PyUSB, and libusb development files for `mks5lboot`. Build tools
never connect to a device unless their command explicitly performs USB I/O.

```sh
make -C utils/nano4g/installer
make -C utils/mks5lboot
python3 -m pip install pyusb
```

The build uses `tools/fmssasm.c` to assemble the shared reset/READ ID programs
and the reserved read/program/erase sources into a generated header under
`build/`. No sequencer bytes are stored in the source tree.

The unsigned recovery payload is
`utils/nano4g/installer/build/installer-native.bin`. It contains Rockbox's
SRAM hardware initialization followed by this small recovery application.
It is not a DFU container and must not be sent or written directly.

For the first launch, authenticate and wrap `installer-native.bin` with your
working pwnage 2.0 DFU signing tool. The installer runs independently and
provides its own USB header-signing service once booted. An already-running
installer can sign a replacement using `utils/nano4g/boot/make_image.py`.

Put the nano 4G into ROM DFU mode (`05ac:1225`). Then send the signed recovery
image, which runs entirely from RAM:

```sh
utils/mks5lboot/mks5lboot --dfusend \
  installer-signed.dfu -p 0x1225
python3 utils/nano4g/installer/nand_tool.py info
```

The running installer enumerates as experimental USB `ffff:e004`. These are
development IDs, not an assigned production identity. USB access permissions
must allow this recovery device. The host tools require exactly one matching
device and check the protocol signature.
They do not silently detach arbitrary drivers or choose a different device.

## Sign and test the Rockbox bootloader

Build `build-nano4g-boot/bootloader-native.bin` using the instructions in
[`../boot/README.md`](../boot/README.md). With this installer
running, create the bootloader's combined DFU/NAND image:

```sh
python3 utils/nano4g/boot/make_image.py \
  build-nano4g-boot/bootloader-native.bin \
  build-nano4g-boot/bootloader-dual.img1
```

`make_image.py` uses the installer's own restricted AES service.
Test the bootloader through DFU before persistent install:
enter DFU, send the bootloader image, and check Rockbox and required boot-menu
paths. Then return to DFU and reload the installer for NAND operations.

```sh
utils/mks5lboot/mks5lboot --dfusend \
  build-nano4g-boot/bootloader-dual.img1 -p 0x1225
```

After the bootloader test, enter DFU again and run:

```sh
utils/mks5lboot/mks5lboot --dfusend \
  installer-signed.dfu -p 0x1225
```

## Backup, install, verify, restore

Keep the original backup on the host. A backup is **196608 bytes**:
128 ROM-visible pages of 1536 bytes. It includes all pages of block zero,
including the tail beyond the image. It is not a raw physical NAND dump:
additional sectors and spare/OOB bytes outside the ROM's three codewords per
page are not captured. The block must be dedicated to this ROM boot format.

```sh
python3 utils/nano4g/installer/nand_tool.py backup original-reserved.bin
```

This writes `original-reserved.bin` and `original-reserved.bin.json`. The
manifest records geometry and SHA-256. Both files are required for restore.
The tool fsyncs and rereads the saved file, rereads every NAND page and compares
it, checks the device's rolling CRC, writes/fsyncs the manifest, and fsyncs
the containing directory. Existing files are never overwritten. An unreadable
page or mismatched backup stops before any erase; there is no force override.

Inspect the installation plan (no USB access):

```sh
python3 utils/nano4g/installer/nand_tool.py install \
  build-nano4g-boot/bootloader-dual.img1 --backup before-install.bin
```

Perform the installation only after the hardware validation described above:

```sh
python3 utils/nano4g/installer/nand_tool.py install \
  build-nano4g-boot/bootloader-dual.img1 --backup before-install.bin \
  --go --i-understand-this-is-destructive
```

The tool validates the container sizes, duplicate headers, startup descriptor,
complete maintained pwnage certificate and device-generated header
authentication. Compact DFU containers and unsigned payloads are rejected.
It makes a fresh verified backup in the current session before authorizing
the erase. Header authentication checks the header, not arbitrary payload
code: use the image produced from your reviewed build.

The firmware erases only CE0/block0, verifies that every ROM-visible page is
erased, then programs **page 0 first and pages 1 through 127 in ascending
order**. Each operation stages exactly one 1536-byte page, checks its upload
CRC, programs it once, reads it back and compares it on the device. The host
then downloads that readback and compares it independently before proceeding.
It finally rereads and compares the complete block. The image's last partial
page and remaining pages are zero-filled, matching the established reserved
image writer's full-block policy. This order respects the conservative NAND
program-order requirement; it is **not an atomic header-last install**.

An explicit separate verification command is:

```sh
python3 utils/nano4g/installer/nand_tool.py verify \
  build-nano4g-boot/bootloader-dual.img1
```

Restore uses a full backup plus its manifest and makes another fresh backup
of the current contents before erasing. Blank pages in the backup are kept
erased and verified without issuing unnecessary program commands.

```sh
python3 utils/nano4g/installer/nand_tool.py restore original-reserved.bin \
  --backup before-restore.bin
python3 utils/nano4g/installer/nand_tool.py restore original-reserved.bin \
  --backup before-restore.bin --go --i-understand-this-is-destructive
python3 utils/nano4g/installer/nand_tool.py verify original-reserved.bin --backup
```

Successful read-only or complete write sessions can be followed by another
command in the same boot. Any error locks the firmware's write session. A
USB reset invalidates its backup authorization. Reload the installer to
investigate a failed session; there are no automatic destructive retries or
automatic reboot commands. A corrupt current page that cannot be read with
ECC blocks the backup gate even for restore; this tool deliberately has no
raw/force recovery bypass. Keep the first valid backup and the output.

## Hardware interface

The FMC is at `0x38a00000`; command/address/DMA registers occupy offsets
`0x00..0x60`, BCH registers `0x800..0x81c`. Bits 5 and 9 of `0x3c500048`
gate the controller clocks. Detection resets and reads all eight chip enables;
reserved reads, programs and erases select CE0 only.

A ROM-format page contains three codewords, each holding 26 BCH16 parity
bytes followed by 512 data bytes. There is no FTL metadata. Hardware generates
and corrects parity. Reads check every sector and bound all FMC/ECC waits.

Dedicated sequencer programs alternate the two sector buffers, encode BCH16
and send parity before data. Buffers are reused after DMA, ECC and transfer
completion. Reads preserve each sector's uncorrectable and erased indications;
an erased indication is accepted only when that sector's data is all `ff`.
Program and erase completion check NAND status bit 0. Controller faults,
handshake timeouts and program failures stop the current session.

USB uses a polled EP0 state machine. Attribution is retained in `usb.c` and
`aes.c`.
Transfers use PIO, with at most 64 data bytes per vendor request. SETUP aborts
a stale IN transfer. IRQs, MMU and caches stay disabled; SRAM startup initializes
SDRAM and the recovery entry relocates the payload to `0x09000000`.

## USB protocol

All fields are little-endian. Vendor requests target the device recipient,
with `wIndex=0`. Firmware version 1 returns eight 32-bit status words:
signature `0x4934474e` (`N4GI`), version, result, session state, current page,
snapshot CRC32, next permitted program page, and chip ID. Result 0 is success,
1 means busy, and values 2..9 are terminal request/state/timeout/ECC/NAND/
verification/chip/USB errors. CRC32 uses the standard reflected polynomial
`0xedb88320`, initial/final XOR `0xffffffff`; it detects transfer corruption,
not an untrusted host.

| Request | Direction | Meaning |
| --- | --- | --- |
| `0x40` | OUT | Upload 1..64 bytes; `wValue` is exact next offset in the page staging buffer |
| `0x41` | OUT | Submit 16 bytes: operation, page, confirmation, argument |
| `0x42` | IN | Read the 32-byte status record |
| `0x43` | IN | Read 1..64 result bytes at offset `wValue` |

Operations are initialize (1), read page (2), arm after backup (3), erase (4),
program one page (5), verify an erased page and advance (6), and encrypt one
16-byte header digest (7). Destructive operations require confirmation
`0x45534152`. Arm also requires the CRC from an ordered successful 128-page
read in this session. Program requires a complete new page upload and its
CRC. Firmware consumes erase authorization once, enforces increasing page
numbers and latches failure. Jobs start only after the command's USB status
stage completes; host output identifies each destructive step before issuing
it. Nothing relies on diagnostics surviving a reset.
