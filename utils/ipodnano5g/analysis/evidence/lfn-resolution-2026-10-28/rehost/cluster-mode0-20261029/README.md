# Offline-QEMU-Rehosts: LFN mode 0

These runs execute selected original ARM functions from
`osos_runtime_dram_20261025.bin` with synthetic context and directory-cache
records. They do not access the iPod or emulate a complete OSOS startup.

The source image is
`/home/sebastian/ipod-re/local-analysis/inputs/osos_runtime_dram_20261025.bin`
(SHA-256 `1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`).

## Sector-advance register check

`OSOS_lfn_cluster_r2_rehost_20261029.S` maps the original
`FUN_081608f8`, `FUN_0816a970`, and `FUN_0818e65c`. With synthetic
`data_start=0x00100000` and four sectors per cluster, it checks:

- current LBA `0x00100006` advances to `0x00100007`, with `r2=0`;
- current LBA `0x00100008` advances to `0x00100009`, with `r2=1`.

Both assertions passed. This confirms the register behavior for those inputs;
it does not model FAT-chain lookup or iterator state.

## Two-block resolver check

`OSOS_lfn_cross_block_resolver_rehost_20261029.S` maps the original
`FUN_081f7f9c`, `FUN_081f8164`, `FUN_08159128`, and `FUN_08160828`. It calls
the original state helper twice with keys `0x22` then `0x11` and `r2=0`, then
checks that the resulting state has `state[0]=2`, `state[1]=0`, current key
`0x11`, and previous key `0x22`. The cache stub returns different synthetic
entries for those keys; release and UTF-16 conversion are also stubs.

The previous entry has LFN sequence `0x42` at record 15 with `N` through `Z`;
the current entry has sequence `0x01` at record 0 with `A` through `M`, followed
by the short entry `ROCKBO~1BIN`. Both LFN records carry checksum `0x08`, the
VFAT checksum of that 11-byte short name. Original `FUN_081f8164` computes
`0x08` for the short entry, which the harness asserts. It also checks all 26
output characters and the trailing NUL. It passed with exit status 0.

This confirms that the original state helper creates the tested state, the
original checksum helper returns the expected value, and the original resolver
copies and joins this synthetic mode-0 cross-block layout. It does not test the
directory scan, real cache management, the full VFAT checksum comparison,
OSOS path opening, or the device's actual volume geometry and slots.

## Reproduction

Run from the `rb-n5g` repository root. The ELF files are local build outputs
and are not tracked; source, linker scripts, traces, and run logs are tracked.
The output ELFs and traces here were built with these commands:

```sh
arm-none-eabi-gcc -nostdlib -Wl,-T,utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cluster_r2_rehost_20261029.ld -Wl,--build-id=none -o utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cluster_r2_rehost_20261029.elf utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cluster_r2_rehost_20261029.S
qemu-arm -d in_asm,cpu -D utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cluster_r2_rehost_20261029.qemu-trace.log utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cluster_r2_rehost_20261029.elf
arm-none-eabi-gcc -nostdlib -Wl,-T,utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cross_block_resolver_rehost_20261029.ld -Wl,--build-id=none -o utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cross_block_resolver_rehost_20261029.elf utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cross_block_resolver_rehost_20261029.S
qemu-arm -d in_asm,cpu -D utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cross_block_resolver_rehost_20261029.qemu-trace.log utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/rehost/cluster-mode0-20261029/OSOS_lfn_cross_block_resolver_rehost_20261029.elf
```

The adjacent `run.log` files contain the program output. `20261028/` retains
the earlier synthetic OOB-index case, whose out-of-range source pointer faults
under QEMU; it is separate from the valid cross-block reconstruction above.
