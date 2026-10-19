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

"""Back up, install, restore and verify nano4g ROM-visible block zero.

Requires the standalone nano4g installer payload, Python 3 and PyUSB.
No operation is retried automatically. Install/restore are dry runs by default.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
import zlib

PAGE_BYTES = 0x600
BLOCK_PAGES = 128
BLOCK_BYTES = PAGE_BYTES * BLOCK_PAGES
MAGIC = 0x4934474E
CONFIRM = 0x45534152
ERRORS = ("OK", "BUSY", "bad request", "invalid session state", "hardware timeout",
          "uncorrectable ECC", "NAND program/erase failure", "verification failed",
          "unsupported NAND chip", "USB failure")

class Device:
    """One USB handle for the entire transaction; never reconnect on failure."""

    def __init__(self, *, allow_active=False):
        import usb.core
        import usb.util
        self.util = usb.util
        self.usb_error = usb.core.USBError
        self.device = None
        found = list(usb.core.find(find_all=True, idVendor=0xFFFF, idProduct=0xE004))
        if len(found) != 1:
            raise RuntimeError(f"expected exactly one nano4g installer, found {len(found)}")
        self.device = found[0]
        try:
            try:
                configured = self.device.get_active_configuration().bConfigurationValue
            except usb.core.USBError:
                configured = 0
            if configured != 1:
                self.device.set_configuration(1)
            self.util.claim_interface(self.device, 0)
            status = self.status()
            if status[0:2] != (MAGIC, 1):
                raise RuntimeError("unexpected installer protocol; refusing device")
            if not allow_active and (status[3] not in (0, 1, 5) or status[2] != 0):
                raise RuntimeError("session failed or write unfinished; reload the installer before continuing")
        except Exception:
            self.close()
            raise

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def close(self):
        if self.device is not None:
            self.util.dispose_resources(self.device)
            self.device = None

    def transfer(self, input_, request, value, data):
        try:
            result = self.device.ctrl_transfer(0xC0 if input_ else 0x40,
                                               request, value, 0, data, timeout=3000)
        except self.usb_error as error:
            direction = "IN" if input_ else "OUT"
            length = data if input_ else len(data)
            raise RuntimeError(
                f"USB {direction} request 0x{request:02x}, value 0x{value:04x}, "
                f"length {length} failed; operation not retried: {error}") from error
        expected = data if input_ else len(data)
        actual = len(result) if input_ else result
        if actual != expected:
            raise RuntimeError(f"short USB transfer ({actual}/{expected}); stop, do not retry writes")
        return bytes(result) if input_ else None

    def status(self):
        return struct.unpack("<8I", self.transfer(True, 0x42, 0, 32))

    def command(self, operation, page=0, token=0, argument=0):
        self.transfer(False, 0x41, 0, struct.pack("<4I", operation, page, token, argument))
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            status = self.status()
            if status[:2] != (MAGIC, 1):
                raise RuntimeError("bad protocol response")
            if status[2] == 1:
                time.sleep(0.02)
                continue
            if status[2]:
                error = ERRORS[status[2]] if status[2] < len(ERRORS) else str(status[2])
                raise RuntimeError(f"device stopped: {error}, page {status[4]}; do not retry writes")
            return status
        raise RuntimeError("job timed out; outcome unknown, no automatic retry")

    def upload(self, data):
        if len(data) not in (16, PAGE_BYTES):
            raise ValueError("upload must be one complete page or one AES block")
        for offset in range(0, len(data), 64):
            self.transfer(False, 0x40, offset, data[offset:offset + 64])

    def download(self, length):
        return b"".join(self.transfer(True, 0x43, offset, min(64, length - offset))
                        for offset in range(0, length, 64))

    def encrypt_header(self, digest):
        if len(digest) != 16:
            raise ValueError("header digest must contain exactly 16 bytes")
        self.upload(digest)
        self.command(7)
        return self.download(16)

    def initialize_flash(self):
        status = self.command(1)
        # Firmware validates the complete CE population and reserved geometry.
        if status[7] in (0, 0xffffffff):
            raise RuntimeError("installer did not identify NAND")

    def read_page(self, page):
        if not 0 <= page < BLOCK_PAGES:
            raise ValueError("page outside reserved block")
        self.command(2, page)
        return self.download(PAGE_BYTES)

    def read_block(self):
        data = bytearray()
        for page in range(BLOCK_PAGES):
            if page % 16 == 0:
                print(f"Read reserved page {page}/{BLOCK_PAGES}", flush=True)
            data.extend(self.read_page(page))
        return bytes(data)

    def write_block(self, data, backup_crc):
        if len(data) != BLOCK_BYTES:
            raise ValueError("write requires the entire ROM-visible block")
        self.command(3, token=CONFIRM, argument=backup_crc)
        print("Erase CE0 block0; verify all 128 pages are erased", flush=True)
        self.command(4, token=CONFIRM)
        for page in range(BLOCK_PAGES):
            chunk = data[page * PAGE_BYTES:(page + 1) * PAGE_BYTES]
            erased = chunk == b"\xff" * PAGE_BYTES
            print(f"{'Keep erased' if erased else 'Program'} page {page}; then verify", flush=True)
            self.upload(chunk)
            self.command(6 if erased else 5, page, CONFIRM, zlib.crc32(chunk))
            if self.download(PAGE_BYTES) != chunk:
                raise RuntimeError(f"host readback mismatch at page {page}; stopped")
        verify_block(self, data)

def validate_image(data):
    """Accept only the combined pwnage container from boot/make_image.py."""
    if len(data) < 0x680 or len(data) > 122880 or len(data) % 16:
        raise ValueError("invalid combined-image length/alignment")
    if data[:8] != b"87202.0\x03":
        raise ValueError("expected a format-3 S5L8720 IMG1")
    entry, body_length, data_length, cert_offset, cert_length = struct.unpack_from("<5I", data, 8)
    if entry or body_length + 0x80 != cert_offset or cert_length != 702:
        raise ValueError("unexpected image/certificate layout")
    if cert_offset + cert_length != data_length or data_length > 0x24C00:
        raise ValueError("invalid image data length")
    expected = (0x600 + data_length + 15) & ~15
    if len(data) != expected or any(data[0x600 + data_length:]):
        raise ValueError("truncated image or unexpected trailing data")
    if data[:0x50] != data[0x600:0x650] or data[0x50:0x54] != struct.pack("<I", 0xEA00017E):
        raise ValueError("not a combined NAND/DFU image; compact DFU images cannot be installed")
    if data[0x654:0x658] != b"RB4S":
        raise ValueError("missing independent Rockbox startup")
    if data[0x600 + data_length - 4:0x600 + data_length] != struct.pack("<I", 0x22000050):
        raise ValueError("unexpected pwnage entry target")
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "boot"))
    from make_image import certificate
    if data[0x600 + cert_offset:0x600 + data_length] != certificate():
        raise ValueError("certificate differs from the maintained pwnage chain")
    stage_size = struct.unpack_from("<I", data, 0x658)[0]
    if stage_size < 32 or stage_size % 32 or 0x650 + stage_size + 16 > 0x600 + cert_offset:
        raise ValueError("invalid SRAM stage descriptor")
    payload_size = struct.unpack_from("<I", data, 0x650 + stage_size)[0]
    if payload_size < 64 or payload_size % 32 or 0x650 + stage_size + 16 + payload_size > 0x600 + cert_offset:
        raise ValueError("invalid bootloader payload descriptor")
    return data.ljust(BLOCK_BYTES, b"\0")

def fsync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)

def save_backup(device, path):
    metadata_path = Path(str(path) + ".json")
    if path.exists() or metadata_path.exists():
        raise ValueError("backup or manifest already exists; choose new names")
    data = device.read_block()
    with path.open("xb") as output:
        output.write(data)
        output.flush()
        os.fsync(output.fileno())
    # Compare the actual saved bytes, then independently reread every page.
    saved = path.read_bytes()
    if saved != data:
        raise RuntimeError("saved backup differs from device data")
    verify_block(device, saved)
    crc = zlib.crc32(saved)
    if device.status()[5] != crc:
        raise RuntimeError("device snapshot CRC differs from the saved backup")
    metadata = {"format": "nano4g-reserved-v1", "bytes": BLOCK_BYTES,
                "pages": BLOCK_PAGES, "page_bytes": PAGE_BYTES, "ce": 0, "block": 0,
                "chip_id": "b614d5ad", "sha256": hashlib.sha256(saved).hexdigest()}
    with metadata_path.open("x") as output:
        json.dump(metadata, output, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())
    fsync_directory(path.parent)
    # Require the manifest to survive rereading too before authorizing erase.
    if load_backup(path) != saved:
        raise RuntimeError("backup/manifest reread failed")
    print(f"Saved and verified {path}; SHA-256 {metadata['sha256']}", flush=True)
    return crc

def load_backup(path):
    data = path.read_bytes()
    metadata = json.loads(Path(str(path) + ".json").read_text())
    if (len(data) != BLOCK_BYTES or metadata.get("format") != "nano4g-reserved-v1" or
        metadata.get("bytes") != BLOCK_BYTES or metadata.get("pages") != BLOCK_PAGES or
        metadata.get("page_bytes") != PAGE_BYTES or metadata.get("ce") != 0 or
        metadata.get("block") != 0 or metadata.get("chip_id") != "b614d5ad" or
        metadata.get("sha256") != hashlib.sha256(data).hexdigest()):
        raise ValueError("backup length, geometry or SHA-256 manifest is invalid")
    return data

def verify_block(device, expected):
    for page in range(BLOCK_PAGES):
        if page % 16 == 0:
            print(f"Verify reserved page {page}/{BLOCK_PAGES}", flush=True)
        if device.read_page(page) != expected[page * PAGE_BYTES:(page + 1) * PAGE_BYTES]:
            raise RuntimeError(f"reserved page {page} differs; stopped")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("info", help="read installer identity, no NAND access")
    backup = commands.add_parser("backup", help="save and verify all ROM-visible block0 pages")
    backup.add_argument("output", type=Path)
    for name in ("install", "restore"):
        sub = commands.add_parser(name)
        sub.add_argument("input", type=Path)
        sub.add_argument("--backup", required=True, type=Path, help="new pre-erase backup file")
        sub.add_argument("--go", action="store_true")
        sub.add_argument("--i-understand-this-is-destructive", action="store_true")
    verify = commands.add_parser("verify")
    verify.add_argument("input", type=Path)
    verify.add_argument("--backup", action="store_true", help="input is a full-block backup with manifest")
    args = parser.parse_args()
    try:
        data = None
        if args.command == "restore" or (args.command == "verify" and args.backup):
            data = load_backup(args.input)
        elif args.command in ("install", "verify"):
            data = validate_image(args.input.read_bytes())
        destructive = args.command in ("install", "restore")
        if destructive:
            print(f"Plan: save+verify {args.backup}, erase CE0/block0, program ascending, verify each page and full block")
            if not args.go:
                print("Dry run: no USB connection or NAND operation")
                return
            if not args.i_understand_this_is_destructive:
                raise ValueError("--go also requires --i-understand-this-is-destructive")
            if args.backup.exists() or Path(str(args.backup) + ".json").exists():
                raise ValueError("pre-erase backup already exists; choose a new name")
        with Device(allow_active=args.command == "info") as device:
            if args.command == "info":
                print("S5L8720 installer protocol 1; 128 pages x 1536 bytes; CE0/block0 only")
                status = device.status()
                print(f"Result {status[2]}, state {status[3]}, page {status[4]}, "
                      f"next page {status[6]}, chip {status[7]:08x}")
                return
            if args.command == "install":
                authentication = device.encrypt_header(hashlib.sha1(data[:0x40]).digest()[:16])
                if authentication != data[0x40:0x50]:
                    raise ValueError("image header authentication does not match this device")
            device.initialize_flash()
            if args.command == "backup":
                save_backup(device, args.output)
            elif args.command == "verify":
                verify_block(device, data)
            else:
                crc = save_backup(device, args.backup)
                device.write_block(data, crc)
                print("Verified all 128 ROM-visible pages. No reboot was requested.")
    except (OSError, ValueError, ImportError, RuntimeError) as error:
        parser.exit(1, f"ERROR: {error}\nKeep backups and output. No destructive command was retried.\n")

if __name__ == "__main__":
    main()
