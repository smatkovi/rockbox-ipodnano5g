#!/usr/bin/env python3
"""ubsh.py [-d /dev/ttyACM0] [-t timeout] [--load FILE.bin@ADDR] 'cmd1' 'cmd2' ...

Send commands to the U-Boot USB-ACM console on the Nano 5G and print the
replies. Each command waits for the '=> ' prompt (or the timeout).
--load first sends FILE.bin to ADDR through 'loads' as S-records.
"""
import os, sys, termios, time, select, argparse, subprocess, tempfile

ap = argparse.ArgumentParser()
ap.add_argument("-d", default="/dev/ttyACM0")
ap.add_argument("-t", type=float, default=3.0)
ap.add_argument("--load")
ap.add_argument("cmds", nargs="*")
a = ap.parse_args()

fd = os.open(a.d, os.O_RDWR | os.O_NOCTTY)
attr = termios.tcgetattr(fd)
attr[0] = attr[1] = attr[3] = 0          # raw: no iflag/oflag/lflag processing
attr[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
termios.tcsetattr(fd, termios.TCSANOW, attr)


def read_until(prompt, timeout):
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            buf += os.read(fd, 4096)
            if buf.endswith(prompt):
                break
    return buf


# flush and wake the prompt
read_until(b"\x00", 0.3)
os.write(fd, b"\n")
read_until(b"=> ", 1.0)
if a.load:
    path, addr = a.load.rsplit("@", 1)
    # pad to whole cache lines, or U-Boot skips the cache flush after loads
    blob = open(path, "rb").read()
    blob += b"\0" * (-len(blob) % 64)
    with tempfile.NamedTemporaryFile(suffix=".bin") as b, \
         tempfile.NamedTemporaryFile(suffix=".srec") as t:
        b.write(blob)
        b.flush()
        subprocess.run(["arm-none-eabi-objcopy", "-I", "binary", "-O", "srec",
                        "--change-addresses", addr, b.name, t.name], check=True)
        srec = open(t.name, "rb").read()
    os.write(fd, b"loads\n")
    read_until(b"...\r\n", 2.0)
    for line in srec.splitlines():
        os.write(fd, line + b"\r\n")
        read_until(b"\x00", 0.002)
    sys.stdout.write(read_until(b"=> ", 10.0).decode(errors="replace").replace("\r", ""))
for c in a.cmds:
    os.write(fd, c.encode() + b"\n")
    out = read_until(b"=> ", a.t).decode(errors="replace")
    sys.stdout.write(out.replace("\r", ""))
    sys.stdout.flush()
print()
