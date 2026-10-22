#!/usr/bin/env python3
"""n5g-mailbox.py [-d /dev/ttyACM0]

Read the report Rockbox leaves at 0x0af00000 before it returns to the U-Boot
shell (devloop-nano5g.c) and print it: reason, USB CBW count, fault
registers, the DesignWare USB registers, the panic text, the thread list and
the logf log.
"""
import argparse, os, re, select, struct, termios, time

BASE = 0x0af00000
REASONS = {1: "reboot", 2: "exception/panic", 3: "USB storage silent", 4: "host ejected the drive"}


def shell(fd, cmd, timeout=30):
    os.write(fd, cmd.encode() + b"\n")
    buf, end = b"", time.time() + timeout
    while time.time() < end and not buf.endswith(b"=> "):
        r, _, _ = select.select([fd], [], [], 0.2)
        if r:
            buf += os.read(fd, 65536)
    return buf.decode(errors="replace")


def read_mem(fd, addr, nbytes):
    # small chunks: long md output over the U-Boot USB console can hang it
    data = b""
    for a in range(addr, addr + nbytes, 1024):
        out = shell(fd, "md.l %#x %#x" % (a, min(256, (addr + nbytes - a + 3) // 4)), 30)
        for line in out.splitlines():
            m = re.match(r"([0-9a-f]{8}): ((?:[0-9a-f]{8} ?){1,4})", line.strip())
            if m:
                for w in m.group(2).split():
                    data += struct.pack("<I", int(w, 16))
        time.sleep(0.05)
    return data[:nbytes]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", default="/dev/ttyACM0")
    a = ap.parse_args()
    fd = os.open(a.d, os.O_RDWR | os.O_NOCTTY)
    t = termios.tcgetattr(fd)
    t[0] = t[1] = t[3] = 0
    t[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    termios.tcsetattr(fd, termios.TCSANOW, t)
    shell(fd, "", 2)

    head = read_mem(fd, BASE, 7 * 4)
    magic, reason, tick, cbw, far, dfsr, ifsr = struct.unpack("<7I", head)
    if magic != 0x4e35474d:
        print("no report (magic %08x)" % magic)
        return
    print("reason: %s, tick %d, USB CBWs %d" % (REASONS.get(reason, reason), tick, cbw))
    print("FAR %08x DFSR %08x IFSR %08x" % (far, dfsr, ifsr))
    off = 7 * 4
    regs = read_mem(fd, BASE + off, (0x14 + 4 + 48 + 48) * 4)
    w = struct.unpack("<%dI" % (len(regs) // 4), regs)
    print("dwc global:", " ".join("%08x" % x for x in w[:0x14]))
    print("dwc dev   :", " ".join("%08x" % x for x in w[0x14:0x18]))
    for ep in range(6):
        print("in%d  %s" % (ep, " ".join("%08x" % x for x in w[0x18 + ep * 8:0x20 + ep * 8])))
    for ep in range(6):
        print("out%d %s" % (ep, " ".join("%08x" % x for x in w[0x48 + ep * 8:0x50 + ep * 8])))
    off += len(regs)
    panic = read_mem(fd, BASE + off, 128).split(b"\0")[0].decode(errors="replace")
    off += 128
    print("panic:", panic)
    threads = read_mem(fd, BASE + off, 1024).split(b"\0")[0].decode(errors="replace")
    off += 1024
    print("threads:")
    print(threads)
    nand = read_mem(fd, BASE + off, 768).split(b"\0")[0].decode(errors="replace")
    off += 768
    print("nandtest:")
    print(nand)
    idx, wrap = struct.unpack("<II", read_mem(fd, BASE + off, 8))
    off += 8
    n = 16384 if wrap else min(idx, 16384)
    logf = read_mem(fd, BASE + off, n)
    if wrap:
        logf = logf[idx:] + logf[:idx]
    print("logf:")
    print(logf.replace(b"\0", b"\n").decode(errors="replace"))


if __name__ == "__main__":
    main()
