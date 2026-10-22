#!/usr/bin/env python3
"""ymodem.py [-d /dev/ttyACM0] FILE ADDR

Send FILE to the U-Boot shell's `loady ADDR` over the USB-ACM console with
YMODEM (1 KiB blocks, CRC-16), then return to the prompt. Unlike `loads`,
every block is acknowledged, so nothing is lost on the way.
"""
import argparse, os, select, sys, termios, time

SOH, STX, EOT, ACK, NAK, CAN, CRC = 0x01, 0x02, 0x04, 0x06, 0x15, 0x18, 0x43


def crc16(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xffff
    return crc


class Port:
    def __init__(self, dev):
        self.fd = os.open(dev, os.O_RDWR | os.O_NOCTTY)
        a = termios.tcgetattr(self.fd)
        a[0] = a[1] = a[3] = 0
        a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        termios.tcsetattr(self.fd, termios.TCSANOW, a)

    def write(self, b):
        os.write(self.fd, b)

    def read(self, timeout):
        r, _, _ = select.select([self.fd], [], [], timeout)
        return os.read(self.fd, 4096) if r else b""

    def wait_byte(self, wanted, timeout):
        """wait for one of the bytes in `wanted`; returns it or None"""
        end = time.time() + timeout
        while time.time() < end:
            for b in self.read(0.2):
                if b in wanted:
                    return b
        return None

    def read_until(self, s, timeout):
        buf, end = b"", time.time() + timeout
        while time.time() < end and not buf.endswith(s):
            buf += self.read(0.2)
        return buf


def block(seq, payload):
    size = 1024 if len(payload) > 128 else 128
    payload = payload.ljust(size, b"\x1a" if seq else b"\0")
    head = bytes([STX if size == 1024 else SOH, seq & 0xff, 0xff - (seq & 0xff)])
    c = crc16(payload)
    return head + payload + bytes([c >> 8, c & 0xff])


def send_block(p, pkt):
    for _ in range(10):
        p.write(pkt)
        r = p.wait_byte((ACK, NAK, CAN), 5)
        if r == ACK:
            return
        if r == CAN:
            sys.exit("receiver cancelled")
    sys.exit("block not acknowledged")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", default="/dev/ttyACM0")
    ap.add_argument("file")
    ap.add_argument("addr")
    a = ap.parse_args()
    data = open(a.file, "rb").read()
    name = os.path.basename(a.file).encode()

    p = Port(a.d)
    p.read(0.3)
    p.write(b"\n")
    p.read_until(b"=> ", 2)
    p.write(b"loady %s\n" % a.addr.encode())
    if p.wait_byte((CRC,), 10) is None:
        sys.exit("no YMODEM 'C' from loady")

    t0 = time.time()
    send_block(p, block(0, name + b"\0" + str(len(data)).encode() + b"\0"))
    p.wait_byte((CRC,), 5)
    seq = 1
    for off in range(0, len(data), 1024):
        send_block(p, block(seq, data[off:off + 1024]))
        seq += 1
    for _ in range(5):
        p.write(bytes([EOT]))
        if p.wait_byte((ACK, NAK), 5) == ACK:
            break
    p.wait_byte((CRC,), 5)
    send_block(p, block(0, b""))        # end of batch
    out = p.read_until(b"=> ", 10).decode(errors="replace")
    dt = time.time() - t0
    print(out.strip().splitlines()[-3:] if out.strip() else "")
    print("%d bytes in %.1f s (%.0f KB/s)" % (len(data), dt, len(data) / dt / 1024))


if __name__ == "__main__":
    main()
