# iTunes partial-LR prefix rehost

Read-only offline rehost evidence for the candidate prefix used by the iTunes
playlist path analysis. The harness starts at the ARM prefix bytes with
synthetic registers and flags; it does not invoke the actual parser, callback,
FAT layer, or S5L8730 CPU model.

## Reproduction

Run `bash run_qemu_prefix_reachability.sh` from any working directory. It
builds six temporary ELFs and runs them with `qemu-system-arm -M versatilepb
-cpu arm1176 -m 192M`. The script leaves the build products next to itself.

## Observations

- With the success hypothesis (`N=0,V=0`), QEMU raises Undefined Instruction
  at `LDCLPL` at path offset `+0x10`.
- With the error hypothesis (`N=1,V=0`), it skips that instruction and reaches
  filename-controlled ARM instructions. The ASCII case reaches the exact
  UDF sentinel. The unmapped `STRBMI` probe is ignored by this QEMU machine
  model, so it says nothing about S5L8730 store behavior.
- A three-byte UTF-8 sequence followed by `J` forms `BMI` and reaches the test
  sentinel at `0x08700000` from a deliberately chosen buffer address.
- Two additional cases set `r4` to a synthetic 2010 Unix timestamp and to zero.
  Both still reach the BMI sentinel because this QEMU board model ignores the
  unassigned byte loads at `r4-0x95c`. This is a model limitation, not evidence
  that the iPod's MMU or S5L8730 bus accepts either address.
- `branch_target_math_20261031.py` records displacement and heap-overlap
  arithmetic. The selected buffer addresses are mathematical examples, not
  measured allocator results.

`input_string_sources_20261031.ghidra.log`,
`playlist_input_owner_20261031.ghidra.log`,
`playlist_input_helpers_20261031.ghidra.log`,
`playlist_name_constants_20261031.ghidra.log`, and
`filename_character_encoding_20261031.ghidra.log` preserve the related
read-only Ghidra queries. The literals decode to `CurrentOnTheGoPlaylist.plist`
and `iPod_Control\\iTunes\\`. The UTF-8 helper supports two- and three-byte
sequences, but preservation of those bytes through the device FAT/LFN path is
not established.

The follow-up Ghidra queries in the sibling
`prefix-state-followup-20261031/` directory trace the caller's `r4` to a
date/time-like result from the fixed iTunesDB path. The first prefix read is
at `+0x0c` (`LDRBVC r6,[r4,#-0x95c]`); the coprocessor instruction is at
`+0x10`. The known identity-mapped SDRAM window would contain that read only
for `r4` from `0x0800095c` through `0x0c00095b`. Actual S5L8730 behavior for
addresses outside that window remains unknown.

See `OSOS-iTunes-partial-lr-qemu-reachability-followup-2026-10-31.md` for the
full findings and limitations. No device, USB, DFU, NAND, NOR, or firmware
operation was performed.
