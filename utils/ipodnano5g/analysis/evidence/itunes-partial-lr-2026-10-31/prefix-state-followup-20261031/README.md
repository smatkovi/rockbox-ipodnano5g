# iTunes path prefix state follow-up

Read-only Ghidra evidence for the register values that feed the synthetic
prefix rehost. The saved `N5G_OSOS_runtime` program was opened with
`-noanalysis -readOnly`; no Ghidra project state or device state was changed.

## Findings

- `FUN_08213400` loads `r4` from `FUN_080b0cb6()` at `0x08213418`. The helper
  builds `iPod_Control\\iTunes\\iTunesDB`, initializes a 0x48-byte result,
  and calls `FUN_08270164`. The parser initializes its output to zero, then on
  success stores a calendar-derived seconds value at offset `+8`. The caller's
  timezone correction occurs after `FUN_080b1904`; an overwritten return
  address diverts control before that correction. Thus `r4` at the vulnerable
  return is the unadjusted date/time-like value associated with the iTunesDB
  path. The exact on-device value and parser result are unknown.
- `FUN_080b1904` saves/restores `r4` and `r5`. At its call site in
  `FUN_08213400`, `r4` originates from the helper above and `r5` is the caller's
  first argument. Other callback entries pass either a singleton or a local
  stack object as that first argument. The actual field affected by the later
  conditional store has not been resolved.
- Prefix bytes decode as `LDRBVC r6,[r4,#-0x95c]` at path offset `+0x0c`,
  followed by `LDCLPL` at `+0x10`. In the known identity-mapped DRAM interval
  `0x08000000–0x0bffffff`, that load is in-range only when
  `0x0800095c <= r4 < 0x0c00095c`. If `r4` represents Unix seconds, that is
  approximately 1974-04-03 11:22:04 through 1976-05-19 04:43:07 UTC. A current
  timestamp and a zero default both point outside this known DRAM window.
- This address calculation does not determine the actual device outcome.
  Other MMU mappings, external bus responses, and the S5L8730's abort behavior
  have not been established. The QEMU `versatilepb` harness ignores these
  unassigned reads and is not a valid fault-behavior test for the iPod.
- On the actual `FUN_080b1904` call, `param_2` is non-null and `param_3` is
  zero. The parser's first compare therefore clears `V`; every examined return
  path retains `V=0`. The caller epilogue is `ADD SP` plus `POP`, neither of
  which changes flags. The prefix's `LDRBVC` is consequently enabled on the
  parser return paths examined. `N` still varies with parser status and controls
  the following conditional `LDCLPL`.

## Logs

- `FUN_08213400_context_20261031.ghidra.log`: caller listing and decompilation.
- `callback_argument_objects_20261031.ghidra.log`: fixed path helper and
  callback argument object origins.
- `r4_origin_20261031.ghidra.log` and `r4_string_parser_chain_20261031.ghidra.log`:
  path, parser, and date conversion chain.
- `prefix_return_helpers_20261031.ghidra.log` and
  `r4_helper_functions_20261031.ghidra.log`: parser return/status paths and
  helper semantics.
- `runtime_constants_20261031.ghidra.log`: date conversion constants.
- `external_initializer_pointer_20261031.ghidra.log`: initializer target.

The full analysis and its limitations are summarized in
`OSOS-iTunes-partial-lr-qemu-reachability-followup-2026-10-31.md`.
