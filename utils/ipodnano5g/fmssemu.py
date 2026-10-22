#!/usr/bin/env python3
"""fmssemu.py - run an S5L87xx flash sequencer READ program on a model and
print its MMIO/memory access trace.

  fmssemu.py PROG.bin PAGES CHUNKS [--ecc u|e|N,...] [--no-sectors]

Every WAIT succeeds at once. ECC_RESULT/ECC_STATUS answer per decoded
sector from --ecc (u = uncorrectable, e = erased, N = N corrected bits,
cycled). Parameter words point into a fake memory; the trace lists every
register write ("W reg val"), every memory store ("M addr val") and a
"DECODE n" marker per ECC run, so two programs can be compared with diff.
"""
import argparse, struct, sys

MASK = 0xffffffff


def run(prog, pages, chunks, ecc, trace):
    words = struct.unpack("<%dI" % (len(prog) // 4), prog)
    regs = {}
    mem = {}
    # parameter lists in fake memory
    base = {"rows": 0x10000, "ce": 0x11000, "meta": 0x12000, "dma": 0x13000,
            "stats": 0x14000, "eccbuf": 0x15000}
    for i in range(pages):
        mem[base["rows"] + 4 * i] = 0x1000 + i
        mem[base["ce"] + 4 * i] = 1 << (i % 4)
        for c in range(chunks):
            mem[base["dma"] + 4 * (i * chunks + c)] = 0x08000000 + i * chunks * 2048 + c * 2048
    for i in range(18):
        mem[base["stats"] + 4 * i] = 0
    regs.update({0xd0c: base["rows"], 0xd10: base["ce"], 0xd18: pages,
                 0xd1c: base["meta"], 0xd20: base["dma"], 0xd24: base["stats"],
                 0xd14: base["eccbuf"], 0xd28: chunks, 0xd2c: 0x1, 0xd30: 0xa01,
                 0xd34: 22, 0xd38: 12, 0xd4c: 0x10013000})
    r = [0] * 8
    pc = 0
    ndec = 0
    steps = 0
    while True:
        steps += 1
        if steps > 200000:
            sys.exit("runaway")
        w0, imm = words[pc // 4], words[pc // 4 + 1]
        op, rr, arg = w0 >> 24, (w0 >> 16) & 0xff, w0 & 0xffff
        npc = pc + 8
        if op == 0x00:
            trace.append("END r6=%08x" % r[6])
            break
        elif op == 0x01:
            if arg != 0x810:    # ECC_STATUS is write-1-to-clear: keep the model's value
                regs[arg] = imm
            trace.append("W %03x %08x" % (arg, imm))
            if arg == 0x804:   # ECC start: produce a result
                e = ecc[ndec % len(ecc)]
                ndec += 1
                trace.append("DECODE %d" % ndec)
                regs[0x80c] = 1 if e == "u" else (0 if e == "e" else int(e) << 16)
                regs[0x810] = 0x40 if e == "e" else 0
        elif op == 0x02:
            if arg != 0x810:
                regs[arg] = r[rr]
            trace.append("W %03x %08x" % (arg, r[rr]))
            if arg == 0x804:
                e = ecc[ndec % len(ecc)]
                ndec += 1
                trace.append("DECODE %d" % ndec)
                regs[0x80c] = 1 if e == "u" else (0 if e == "e" else int(e) << 16)
                regs[0x810] = 0x40 if e == "e" else 0
        elif op == 0x03:
            r[rr] = mem.get(r[arg], 0)
        elif op == 0x04:
            v = regs.get(arg, 0)
            if arg == 0x040:
                v = 0           # meta latch never busy
            r[rr] = v & imm
        elif op == 0x05:
            r[rr] = imm
        elif op == 0x06:
            r[rr] = r[arg]
        elif op == 0x07:
            trace.append("WAIT %d" % rr)
        elif op in (0x0a, 0x0b, 0x0c, 0x0d, 0x13, 0x14):
            a, b = (r[arg], imm) if imm else (r[rr], r[arg])
            r[rr] = {0x0a: a & b, 0x0b: a | b, 0x0c: (a + b) & MASK, 0x0d: (a - b) & MASK,
                     0x13: (a << b) & MASK if b < 32 else 0, 0x14: a >> b if b < 32 else 0}[op]
        elif op == 0x0e:
            if r[rr]:
                npc = imm
        elif op == 0x17:
            if not r[rr]:
                npc = imm
        elif op == 0x11:
            mem[r[arg]] = r[rr]
            trace.append("M %05x %08x" % (r[arg], r[rr]))
        else:
            sys.exit("unknown op %02x at %x" % (op, pc))
        pc = npc
    return mem, base


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prog")
    ap.add_argument("pages", type=int)
    ap.add_argument("chunks", type=int)
    ap.add_argument("--ecc", default="0")
    a = ap.parse_args()
    trace = []
    run(open(a.prog, "rb").read(), a.pages, a.chunks, a.ecc.split(","), trace)
    print("\n".join(trace))


if __name__ == "__main__":
    main()
