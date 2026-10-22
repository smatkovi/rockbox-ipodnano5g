#!/usr/bin/env python3
"""n5g-mailbox.py [-d /dev/ttyACM0]

Read the report Rockbox leaves at 0x0af00000 before it returns to the U-Boot
shell (devloop-nano5g.c) and print it: reason, USB CBW count, fault
registers, the DesignWare USB registers, the panic text, the thread list and
the logf log.
"""
import argparse, os, re, select, struct, termios, time

BASE = 0x0af00000
REASONS = {1: "reboot", 2: "exception/panic", 3: "USB storage silent", 4: "host ejected the drive", 5: "hang dump (MENU+PLAY)"}


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


def symbolizer(elf):
    """address -> "func+off" for the text symbols of elf, or None"""
    if not elf:
        return lambda a: None
    import bisect, subprocess
    syms = []
    nm = os.environ.get("NM", os.path.expanduser("~" + os.environ.get("SUDO_USER", "") + "/ipod-re/toolchain/bin/arm-elf-eabi-nm"))
    for line in subprocess.run([nm, "-n", elf], capture_output=True,
                               text=True).stdout.splitlines():
        p = line.split()
        if len(p) == 3 and p[1] in "tTwW":
            syms.append((int(p[0], 16), p[2]))
    addrs = [x[0] for x in syms]
    end = syms[-1][0] + 0x1000 if syms else 0

    def name(a):
        a &= ~1
        i = bisect.bisect_right(addrs, a) - 1
        if i < 0 or a >= end or a < 0x08000000:
            return None
        return "%s+%#x" % (syms[i][1], a - syms[i][0])
    return name


def print_hang(w, ts, threads, elf):
    sym = symbolizer(elf)
    spsr, sp, lr, irq_sp = w[:4]
    print("hang: interrupted mode %02x (spsr %08x) sp %08x lr %08x %s"
          % (spsr & 0x1f, spsr, sp, lr, sym(lr) or ""))
    names = {}
    for line in threads.splitlines():
        p = line.split(None, 3)
        if len(p) == 4 and p[0].isdigit():
            names[int(p[0])] = p[3]
    blocks = [("irq stack", irq_sp, w[100:148]), ("interrupted stack", sp, w[4:100])]
    for t in range(len(ts) // 64):
        if t in names:
            t_sp, t_lr = ts[64 * t], ts[64 * t + 1]
            blocks.append(("thread %d %s (saved lr %08x %s)" % (t, names[t], t_lr,
                           sym(t_lr) or ""), t_sp, ts[64 * t + 2:64 * t + 64]))
    for title, base, words in blocks:
        print("%s @ %08x, code addresses:" % (title, base))
        for i, x in enumerate(words):
            n = sym(x)
            if n:
                print("  +%03x %08x %s" % (4 * i, x, n))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", default="/dev/ttyACM0")
    ap.add_argument("--elf", help="rockbox.elf: name code addresses in the hang dump")
    ap.add_argument("--file", help="a report Rockbox saved to /devloop instead")
    a = ap.parse_args()
    if a.file:
        data = open(a.file, "rb").read()

        def rd(addr, n):
            return data[addr - BASE:addr - BASE + n].ljust(n, b"\0")
    else:
        fd = os.open(a.d, os.O_RDWR | os.O_NOCTTY)
        t = termios.tcgetattr(fd)
        t[0] = t[1] = t[3] = 0
        t[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
        termios.tcsetattr(fd, termios.TCSANOW, t)
        shell(fd, "", 2)

        def rd(addr, n):
            return read_mem(fd, addr, n)

    head = rd(BASE, 7 * 4)
    magic, reason, tick, cbw, far, dfsr, ifsr = struct.unpack("<7I", head)
    if magic != 0x4e35474d:
        print("no report (magic %08x)" % magic)
        return
    print("reason: %s, tick %d, USB CBWs %d" % (REASONS.get(reason, reason), tick, cbw))
    print("FAR %08x DFSR %08x IFSR %08x" % (far, dfsr, ifsr))
    off = 7 * 4
    regs = rd(BASE + off, (0x14 + 4 + 48 + 48) * 4)
    w = struct.unpack("<%dI" % (len(regs) // 4), regs)
    print("dwc global:", " ".join("%08x" % x for x in w[:0x14]))
    print("dwc dev   :", " ".join("%08x" % x for x in w[0x14:0x18]))
    for ep in range(6):
        print("in%d  %s" % (ep, " ".join("%08x" % x for x in w[0x18 + ep * 8:0x20 + ep * 8])))
    for ep in range(6):
        print("out%d %s" % (ep, " ".join("%08x" % x for x in w[0x48 + ep * 8:0x50 + ep * 8])))
    off += len(regs)
    panic = rd(BASE + off, 128).split(b"\0")[0].decode(errors="replace")
    off += 128
    print("panic:", panic)
    threads = rd(BASE + off, 1024).split(b"\0")[0].decode(errors="replace")
    off += 1024
    print("threads:")
    print(threads)
    nand = rd(BASE + off, 768).split(b"\0")[0].decode(errors="replace")
    off += 768
    print("nandtest:")
    print(nand)
    print(rd(BASE + off, 128).split(b"\0")[0].decode(errors="replace"))
    off += 128
    hang = rd(BASE + off, (4 + 96 + 48 + 1) * 4)
    off += len(hang)
    w = struct.unpack("<%dI" % (len(hang) // 4), hang)
    nt = w[-1] if w[-1] < 64 else 0
    ts = rd(BASE + off, nt * 64 * 4)
    off += len(ts)
    print_hang(w, struct.unpack("<%dI" % (len(ts) // 4), ts), threads, a.elf)
    idx, wrap = struct.unpack("<II", rd(BASE + off, 8))
    off += 8
    n = 16384 if wrap else min(idx, 16384)
    logf = rd(BASE + off, n)
    if wrap:
        logf = logf[idx:] + logf[:idx]
    print("logf:")
    print(logf.replace(b"\0", b"\n").decode(errors="replace"))


if __name__ == "__main__":
    main()
