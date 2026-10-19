#!/usr/bin/env python3
#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Copyright (C) 2026 Viktor Krapivin
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
# KIND, either express or implied.
#

"""Build nano4g SRAM startup and append a compiled ARM payload."""
import argparse
import hashlib
from pathlib import Path
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "bootloader/nano4g-startup"

def build_stage(toolchain="arm-none-eabi-", elf_output=None):
    """Return the linked startup binary."""
    with tempfile.TemporaryDirectory(prefix="nano4g-startup-") as directory:
        work = Path(directory)
        subprocess.run([
            toolchain + "gcc", "-mcpu=arm1176jz-s", "-marm",
            "-mno-unaligned-access", "-Os", "-ffreestanding", "-fno-builtin",
            "-fno-unwind-tables", "-fno-asynchronous-unwind-tables",
            "-fno-stack-protector", "-ffunction-sections", "-fdata-sections",
            "-Wall", "-Wextra", "-Werror", "-nostdlib", "-Wl,--gc-sections",
            "-Wl,--build-id=none", "-Wl,-z,noexecstack", "-T",
            str(SOURCE / "startup.lds"), str(SOURCE / "entry.S"),
            str(SOURCE / "early-init.c"), "-lgcc", "-o", str(work / "stage.elf")
        ], check=True)
        subprocess.run([toolchain + "objcopy", "-O", "binary",
                        str(work / "stage.elf"), str(work / "stage.bin")],
                       check=True)
        stage = (work / "stage.bin").read_bytes()
        if elf_output is not None:
            with Path(elf_output).open("xb") as output:
                output.write((work / "stage.elf").read_bytes())
    if (stage[4:8] != b"RB4S" or len(stage) % 32 or
            struct.unpack_from("<I", stage, 8)[0] != len(stage)):
        raise ValueError("startup header or alignment is invalid")
    return stage

def package_payload(payload, *, toolchain="arm-none-eabi-", elf_output=None):
    if len(payload) < 64 or len(payload) % 32:
        raise ValueError("payload must be at least 64 bytes and padded to 32 bytes")
    stage = build_stage(toolchain, elf_output)
    image = stage + struct.pack("<4I", len(payload), 0, 0, 0) + payload
    # Leave room for the dual container's headers/certificate under 120 KiB.
    if len(image) > 122880 - 0x600 - 0x50 - 0x2c0:
        raise ValueError("payload exceeds the combined DFU/NAND size limit")
    return image

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="compiled bootloader.bin")
    parser.add_argument("output", type=Path, help="unsigned startup + payload")
    parser.add_argument("--toolchain", default="arm-none-eabi-",
                        help="cross compiler prefix (default: arm-none-eabi-)")
    parser.add_argument("--elf-output", type=Path, help="also save startup ELF")
    args = parser.parse_args()
    if args.output.exists():
        parser.error("output exists; choose a new name")
    try:
        image = package_payload(args.input.read_bytes(), toolchain=args.toolchain,
                                elf_output=args.elf_output)
        with args.output.open("xb") as output:
            output.write(image)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + "\n")
    print(f"Wrote {args.output}: {len(image)} bytes")
    print("SHA-256:", hashlib.sha256(image).hexdigest())
    print("Unsigned payload: wrap with make_image.py before DFU or NAND use.")

if __name__ == "__main__":
    main()
