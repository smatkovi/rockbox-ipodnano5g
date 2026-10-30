# Slot-0 VFS Open prerequisite exports

These files are read-only Ghidra exports from the existing project
`/home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`
and program `osos_runtime_dram_20261025.bin` (SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`).
The queries used `-noanalysis -readOnly`; transient function creation in
`DumpTransientFunctions.java` is rolled back by that script. No device, USB,
DFU, boot, filesystem-write, NAND, NOR, or flash operation was performed.

## Findings

- A zero-initialized task VFS context supplies volume index 0 for an unprefixed
  path. `FUN_081fdd06` checks/initializes that volume via
  `FUN_0814e76c`/`FUN_0816039c` and then requires a valid volume table entry
  from `FUN_08240974`.
- For `(volume=0, reference=1, flags=0)`, `FUN_0816039c` may invoke
  `FUN_08158f90`; that reaches `FUN_0814ef74`, which reads/parses the volume
  boot record through `FUN_08158dd0` and initializes FAT state through
  `FUN_082015bc`. Thus the static path does not require a pre-seeded mount.
- The boot-record transfer uses `FUN_082192c4` → `FUN_08160a3a` →
  `FUN_0816a928`. For the read mode used here, `FUN_0816a928` calls the
  per-device object's VTable slot `+0x0c` indirectly. This identifies the
  static I/O dispatch, not a successful runtime read.
- `FUN_081fdb38` obtains a root handle for an absolute `/` path through
  `FUN_082014b6`; the root node is registered on demand with `FUN_081f8458`.
  `FUN_081382c2` separately allocates a file-handle-table slot with
  `FUN_08143974`.
- `FUN_082721f0(..., 0)` selects VFS registry slot 0, while the zero in the
  task's VFS context is a FAT volume index used by separate volume and block-I/O
  tables. The matching number does not prove those registrations are the same
  object.
- These facts narrow static prerequisites, but do not prove queue delivery,
  provider registration, successful physical reads, or a complete VFS
  Open/Read on the device.

## Export files

- `ghidra_accessories_open_prerequisites_20261030.application.log` — volume
  guard, task-relative default, path resolver, and root registration.
- `ghidra_vfs_volume_guard_callers_20261030.application.log` — inbound
  callsites for the volume guard.
- `ghidra_vfs_volume_guard_lifecycle_20261030.application.log` — guard
  lifecycle, return paths, and the status check used by FAT operations.
- `ghidra_vfs_volume_mount_inputs_20261030.application.log` — volume boot
  record parsing, cache initialization, and lazy root creation.
- `ghidra_vfs_volume_mount_io_dispatch_20261030.application.log` and
  `ghidra_vfs_volume_worker_dispatch_20261030.application.log` — BPB-read
  dispatch through the block worker to the device VTable.
- `ghidra_vfs_volume_raw_read_20261030.application.log` — supporting raw-read
  helper export; includes two incidental transient-address queries.
- `ghidra_accessories_open_slot_listing_20261030.application.log` and
  `ghidra_accessories_open_slot_path_20261030.application.log` — earlier
  dispatch and argument exports retained in this evidence set.

## Reproduction commands

All commands use the existing read-only project and preserve their output in
this directory:

```sh
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x0816039c 0x081fdd06 0x081fdb38 0x081f8458 0x08217fee 0x08217f50 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_accessories_open_prerequisites_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/speakable-2026-10-28/scripts -postScript DumpCallersMany.java 0x0816039c 0x0814e76c 0x08158f90 0x0814ef74 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_guard_callers_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x08160438 0x0814ef74 0x0814e8f0 0x0814e85c 0x0812a9ca 0x08158f90 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_guard_lifecycle_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x08158838 0x08158dd0 0x0815926c 0x08158fbe 0x082015bc 0x081f9f1c 0x0814f1d8 0x082014b6 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_mount_inputs_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x082192c4 0x081f139c 0x08188e98 0x0812a944 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_mount_io_dispatch_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x08160a3a 0x081f0d50 0x0814ed8c > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_raw_read_20261030.application.log 2>&1
/opt/ghidra/support/analyzeHeadless /home/sebastian/ipod-re/local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis N5G_OSOS_runtime -process osos_runtime_dram_20261025.bin -noanalysis -readOnly -scriptPath /home/sebastian/ipod-re/rb-n5g/utils/ipodnano5g/analysis/evidence/lfn-resolution-2026-10-28/scripts -postScript DumpTransientFunctions.java 0x082449da 0x08237fcc 0x0816a928 0x0833a944 0x0833a9f4 > utils/ipodnano5g/analysis/evidence/accessories-slot0-open-2026-10-30/ghidra_vfs_volume_worker_dispatch_20261030.application.log 2>&1
```

`SHA256SUMS` records hashes for all `.application.log` exports in this
directory. The transient helper queries that reported `created=true` only
created temporary Ghidra functions; the script rolls those transactions back
and the project was opened with `-readOnly`.
