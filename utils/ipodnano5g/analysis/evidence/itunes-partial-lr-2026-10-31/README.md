# iTunes partial-LR audit evidence

This directory backs
`OSOS-iTunes-partial-lr-target-gadget-audit-followup-2026-10-31.md`.
The current update traces the second epilog's PC value through the caller's
dynamic path-string object and checks the fixed string prefix and the
unresolved callback reachability.

## Evidence

- `ScanAsciiThumbTargets.java` and `ScanAsciiThumbGadgets.java` are the
  original read-only Ghidra scans. Their script outputs are the two
  `OSOS_iTunes_ascii_thumb_*.script.log` files. The gadget-window scan is
  heuristic; its count is not a count of usable gadgets.
- `OSOS_iTunes_overflow_lr_context_20261031.script.log` and
  `OSOS_iTunes_playlist_caller_stack_20261031.script.log` contain the original
  listing/decompiler results for the overwrite target and caller stack.
- `DumpCallersAndData.java`, `DumpMemoryWords.java`, and
  `DumpThumbTransientFunctions.java` are the follow-up query helpers. The
  matching `OSOS_iTunes_*_20261031.ghidra.log` exports preserve decompiler
  output for the caller, string helpers, allocator, vtable, cleanup/status
  paths, and handler call sites. Transient function creation is rolled back
  after each Thumb decompilation.
- `OSOS_iTunes_callback_handlers_thumb_20261031.disasm.txt` records the two
  callback-handler sequences. `OSOS_iTunes_heap_redirect_prefix_20261031.bin`
  is a fixed-string-plus-sentinel test vector, not a payload;
  `OSOS_iTunes_heap_redirect_prefix_20261031.disasm.txt` shows its ARM-state
  interpretation.
- `OSOS_iTunes_vulnerable_caller_parents_20261031.ghidra.log` and
  `OSOS_iTunes_playlist_handler_callers_20261031.ghidra.log` record direct
  callers and decompilation of the Genius/On-The-Go paths.
- `OSOS_iTunes_runtime_mapping_20261031.ghidra.log` records Ghidra program
  metadata. The executable SDRAM mapping and heap range are supported by the
  separate reports `OSOS-voice-audio-callback-list-followup-2026-10-28.md`
  and `OSOS-heap-and-rockbox-handoff-2026-10-25.md` in the analysis directory.
- `ScanVtableB4Dispatch.java` scans decoded instructions for loads with offset
  `0xb4` followed by an indirect branch through the same register. Its output
  reports 159 such-offset loads and zero matches in that narrow pattern; this
  does not rule out longer or differently compiled dispatches.
- `OSOS_iTunes_factory_registry_registration_callers_20261031.application.log`,
  `OSOS_iTunes_mainapp_factory_table_20261031.application.log`, and
  `OSOS_iTunes_mainapp_factory_callbacks_thumb_20261031.application.log`
  document the 24 MainApp factory entries. The `0x9c0`-byte object is traced
  through `FUN_080202cc` and `FUN_08023390` to the `Coverflow` descriptor at
  `0x084fc72c`; it does not establish reachability of the separate playlist
  callback table at `0x084f7558`.
- `OSOS_iTunes_factory_registry_initializers_20261031.application.log`,
  `OSOS_iTunes_large_controller_ctor_followup_20261031.application.log`, and
  `OSOS_iTunes_large_controller_class_descriptor_20261031.application.log`
  preserve the registry setup and the `Coverflow` object/class evidence.

The Ghidra queries used the saved `N5G_OSOS_runtime` program for
`osos_runtime_dram_20261025.bin` with `-noanalysis -readOnly`. They did not
write Ghidra project state. This is static/offline evidence; no device, USB,
DFU, NAND, NOR, or firmware operation was performed.

`SHA256SUMS` covers the retained raw inputs and outputs in this directory.
