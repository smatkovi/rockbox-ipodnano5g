# OSOS runtime BX LR rehost

This harness maps the unmodified `osos_runtime_dram_20261025.bin` at
`0x08000000` in QEMU ARM1176, then branches from a synthetic filename buffer
to the actual runtime function at `0x0818ece0`. The harness uses a selected
buffer address and synthetic CPU flags/registers; it does not emulate the
playlist parser, callback invocation, FAT/LFN layer, or S5L8730 hardware.

## Reproduction

Run `./run_qemu_runtime_bx_lr.sh /path/to/osos_runtime_dram_20261025.bin`.
If no path is supplied, it uses the original local input path under
`/home/sebastian/ipod-re/local-analysis/inputs/`.

The verified output is `runtime_bx_lr_qemu.log`; the QEMU instruction trace is
`runtime_bx_lr_trace.log`. The actual runtime code at `0x0818ece0` stores
`1` to `DAT_0818ecf8[1]`, stores `0` to `DAT_0818ecf8[0]`, executes `BX LR`,
and returns to the harness probe. These are two data stores and a return, not
arbitrary code execution or a Rockbox handoff.

No copy of the firmware image is included. No device, USB, DFU, NAND, NOR, or
firmware operation was performed.
