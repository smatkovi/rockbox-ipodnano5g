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

"""Wrap a nano4g startup payload in one authenticated DFU/NAND IMG1 container.

Authentication uses the device GID AES engine through the reserved-area
installer, or a previously computed 16-byte authentication value. No NAND
write is performed by this program.
"""
import argparse
import ast
import hashlib
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[3]
HEADER_SIZE = 0x600
PREFIX_SIZE = 0x50
DFU_LIMIT = 122880

def certificate():
    """Read the pwnage certificate from mks5lboot and validate its length.
    """
    source = (ROOT / "utils/mks5lboot/mkdfu.c").read_text()
    match = re.search(r"\bs5l8720pwnage\s*\[702\][^=]*=\s*\{(.*?)\};",
                      source, re.S)
    if match is None:
        raise ValueError("cannot find the mks5lboot S5L8720 certificate")
    strings = re.findall(r'"(?:\\.|[^"\\])*"', match.group(1))
    chain = b"".join(ast.literal_eval("b" + item) for item in strings)
    if len(chain) != 702:
        raise ValueError("unexpected S5L8720 certificate length")
    return chain[:-4] + struct.pack("<I", 0x22000050)

def image_parts(payload):
    """Validate sizes before asking the device to encrypt anything."""
    if len(payload) < 32 or payload[4:8] != b"RB4S":
        raise ValueError("input must be the unsigned build_payload.py output")
    stage_size = struct.unpack_from("<I", payload, 8)[0]
    if stage_size < 32 or stage_size % 32 or stage_size + 16 > len(payload):
        raise ValueError("invalid startup descriptor")
    payload_size = struct.unpack_from("<I", payload, stage_size)[0]
    if payload_size < 64 or payload_size % 32 or stage_size + 16 + payload_size != len(payload):
        raise ValueError("invalid appended payload length")
    chain = certificate()
    padded = payload.ljust(max(0x640, (len(payload) + 15) & ~15), b"\0")
    cert_offset = PREFIX_SIZE + len(padded)
    body_length = cert_offset - 0x80
    data_length = cert_offset + len(chain)
    total = (HEADER_SIZE + data_length + 15) & ~15
    if data_length > 0x24c00 or total > DFU_LIMIT:
        raise ValueError("combined image exceeds the 120 KiB DFU limit")
    header = (b"87202.0\x03" + struct.pack("<5I", 0, body_length,
              data_length, cert_offset, len(chain))).ljust(0x40, b"\0")
    return header, padded, chain

def header_digest(payload):
    return hashlib.sha1(image_parts(payload)[0]).digest()[:16]

def build_image(payload, encrypt_header_digest):
    header, padded, chain = image_parts(payload)
    authentication = encrypt_header_digest(hashlib.sha1(header).digest()[:16])
    if len(authentication) != 16:
        raise ValueError("AES authentication must contain exactly 16 bytes")
    prefix = header + authentication
    outer = bytearray(prefix.ljust(HEADER_SIZE, b"\0"))
    # DFU retains the entire file in SRAM. NAND reads the first page into a
    # separate header buffer and loads the body at SRAM base. Both certificate
    # paths return to SRAM+0x50. This branch skips DFU's retained outer header.
    struct.pack_into("<I", outer, PREFIX_SIZE, 0xea00017e)
    image = bytes(outer) + prefix + padded + chain
    return image.ljust((len(image) + 15) & ~15, b"\0")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="unsigned native payload")
    parser.add_argument("output", type=Path, nargs="?", help="new .img1 file")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--header-auth", type=Path,
                      help="file containing exactly 16 GID AES encrypted bytes")
    mode.add_argument("--print-header-digest", action="store_true",
                      help="print the 16-byte digest to authenticate; no USB access")
    args = parser.parse_args()
    try:
        payload = args.input.read_bytes()
        digest = header_digest(payload)
        if args.print_header_digest:
            print(digest.hex())
            return
        if args.output is None:
            parser.error("output is required unless --print-header-digest is used")
        if args.output.exists():
            parser.error("output exists; choose a new name")
        if args.header_auth:
            authentication = args.header_auth.read_bytes()
            image = build_image(payload, lambda _: authentication)
        else:
            sys.path.insert(0, str(ROOT / "utils/nano4g/installer"))
            from nand_tool import Device
            with Device() as device:
                image = build_image(payload, device.encrypt_header)
        with args.output.open("xb") as output:
            output.write(image)
    except (OSError, ValueError, ImportError, RuntimeError) as error:
        parser.exit(1, str(error) + "\n")
    print(f"Wrote {args.output}: {len(image)} bytes")
    print("SHA-256:", hashlib.sha256(image).hexdigest())
    print("Use these same bytes for DFU and the reserved NAND region.")

if __name__ == "__main__":
    main()
