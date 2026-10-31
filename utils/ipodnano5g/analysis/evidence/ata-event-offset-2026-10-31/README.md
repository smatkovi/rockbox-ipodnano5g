# ATA virtual dispatch offset check

Read-only Ghidra exports used by
`OSOS-ATA-event-publisher-offset-clarification-followup-2026-10-31.md`.
They separate the wrapper VTable getters at `+0x24/+0x28` from the ATA parent
publisher at `+0x10` and the descriptor callback at slot 0.

Analysis used Ghidra 12.1.2 headless with `-noanalysis -readOnly` on the saved
runtime program. No device state or flash was accessed. `SHA256SUMS` covers
the copied exports.
