# VTable slot +0xb4 follow-up query

`ScanB4Decomp.java` scans the instruction listing already present in the
saved Ghidra program for `LDR` operands at offset `0xb4`, groups those 159
loads into 70 recognized functions, and decompiles those functions read-only.
The query output is `ScanB4Decomp_20261031.ghidra.log`.

The query found four decompiled functions containing `+0xb4` expressions;
the emitted lines are data-field reads/writes and calls to named helpers, not a
resolved indirect call to the playlist callback. This is only a bounded query:
it does not decode unrecognized code, recover every transient function, or
rule out dispatch sequences that compute the slot address differently. It
therefore does not close callback reachability.

The Ghidra project was opened with `-noanalysis -readOnly`. No project state
was saved.
