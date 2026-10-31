# iTunes partial-LR target audit

This evidence backs
`OSOS-iTunes-partial-lr-target-gadget-audit-followup-2026-10-31.md`.
It contains read-only Ghidra exports, the two scanning scripts, and a SHA-256
manifest. The gadget-window scan is heuristic; its match count must not be
read as a count of usable ROP gadgets.

The scans used Ghidra 12.1.2 headless with `-noanalysis -readOnly` on the
saved `N5G_OSOS_runtime` program for `osos_runtime_dram_20261025.bin`. No
device, USB, DFU, filesystem-write, or flash operation was performed.
