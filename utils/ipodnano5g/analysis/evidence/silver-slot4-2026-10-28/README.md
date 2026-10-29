# SilverImagesDB Slot-4 Evidence

These logs were produced from the read-only Ghidra project
`local-analysis/ghidra-projects/N5G_OSOS_runtime_analysis/N5G_OSOS_runtime`
and image `osos_runtime_dram_20261025.bin` (SHA-256
`1326c547b1a97ddf35bf0df53949833fa3b9ec8fabaa1733cb399df7b537ff03`). The
Runtime image begins at Full-Body file offset `0x2e27c`, so a Full-Body VA must
be translated to Runtime VA by subtracting `0x2e27c` before querying this
project.

## Primary revalidated logs

- `OSOS_silver_slot4_rebased_provider_chain_20261029.log`: Runtime decompiles
  for the service singleton, registry, provider constructor, block-size
  dispatch and stream reader.
- `OSOS_silver_slot4_partition_lookup_bounds_20261029.log`: Runtime code for
  the Apple partition scan and resource-table parser; verifies APM-count and
  resource-entry checks.
- `OSOS_silver_slot4_resource_provider_trace_20261029.log` and
  `OSOS_silver_slot4_resource_registry_callers_20261029.log`: early slot-4
  initialization and callers.
- `OSOS_silver_slot4_provider_and_reader_functions_20261028.log`: original
  `FUN_080bbc1c` BMap parser and open wrapper.
- `OSOS_silver_slot4_resource_vtable_entries_20261029.log` and
  `OSOS_silver_slot4_fourcc_literal_20261029.log`: provider VTable and `crsr`
  literal.
- `OSOS_silver_partition_read_provider_20261029.log`,
  `OSOS_silver_partition_read_bounds_followup_20261029.log`, and
  `OSOS_silver_partition_read_vtable_disassembly_20261029.log`: raw-device
  read wrapper, 32-KiB cache behavior, DMA copy direction, and Thumb wrapper
  at the VTable target.
- `OSOS_silver_partition_instance_trace_20261029.log`,
  `OSOS_silver_raw_driver_vtable_20261029.log`,
  `OSOS_silver_raw_driver_vtable_entries_20261029.log`, and
  `OSOS_silver_raw_driver_ops_20261029.log`: Slot-4 object identity and the
  lower storage-driver dispatch. The cache-hit wrap does not invoke that
  lower driver.
- `OSOS_silver_image_reader_transfer_sizes_20261029.log` and
  `OSOS_silver_bmap_allocation_recheck_20261029.log`: stream-read path and
  confirmation that BMap allocation multiplies count and element size with
  unchecked 32-bit arithmetic.
- `OSOS_silver_slot4_startup_context_xrefs_20261029.log`,
  `OSOS_silver_slot4_startup_dispatch_probe_20261029.log`,
  `OSOS_silver_startup_call_raw_listing_20261029.log`,
  `OSOS_silver_startup_context_field_refs_20261029.log`,
  `OSOS_silver_startup_function_refs_20261029.log`, and
  `OSOS_silver_startup_callback_pointer_scan_20261029.txt`: direct caller
  context, alternate global gate, and the negative static-reference scan.
- `OSOS_silver_early_startup_auto_inputs_20261029.log` and
  `OSOS_silver_photodb_startup_reach_20261029.log`: nearby automatic input
  paths and the remaining `FUN_081ac420` context gate.
- `OSOS_silver_photodb_factory_callsite_context_20261029.log`,
  `OSOS_silver_photodb_early_factory_thumb_20261029.log`, and
  `OSOS_silver_photodb_factory_callers_20261029.log`: direct startup factory
  callsite and static-caller check.
- `OSOS_silver_slot4_address_audit_20261029.log` and
  `scripts/InspectContainingFunctions.java`: useful only for identifying the
  numerical contents of the Runtime image; the script was initially given
  several Full-Body VAs without rebasing.
- `OSOS_silver_scheduler_dispatch_and_context_fields_20261029.log`,
  `OSOS_silver_scheduler_dispatch_followup_20261029.log`, and
  `OSOS_silver_scheduler_callback_pointer_xrefs_20261029.log`: distinguish the
  queued `" run"` tag from a function pointer and retain the conditional
  `TMusicLoadingTask` caller chain.
- `OSOS_silver_scheduler_timer_expiration_followup_20261029.log`,
  `OSOS_silver_timer_enqueue_callers_20261029.log`,
  `OSOS_silver_scheduler_queue_head_xrefs_20261029.log`,
  `OSOS_silver_scheduler_timer_worker_followup_20261029.log`,
  `OSOS_silver_scheduler_time_task_and_tmusic_join_20261029.log`,
  `OSOS_silver_scheduler_tmusic_entry_refs_20261029.log`,
  `OSOS_silver_tmusic_timer_producer_path_20261029.log`,
  `OSOS_silver_tmusic_event_timer_join_20261029.log`,
  `OSOS_silver_tmusic_timer_event_delivery_20261029.log`,
  `OSOS_silver_tmusic_timer_event_callback_trace_20261029.log`,
  `OSOS_silver_tmusic_task_alloc_bounds_20261029.log`,
  `OSOS_silver_tmusic_task_object_allocation_trace_20261029.log`,
  `OSOS_silver_scheduler_boot_init_owner_20261029.log`,
  `OSOS_silver_scheduler_boot_init_listing_20261029.log`, and
  `OSOS_silver_scheduler_time_manager_registration_20261029.log`: establish
  the generic timer expiration/callback dispatch and TimeManager startup setup
  while leaving its connection to the TMusic callback unresolved.
- `OSOS_silver_raw_storage_write_api_20261029.log`,
  `OSOS_silver_storage_vtable_wrapper_followup_20261029.log`,
  `OSOS_silver_storage_vtable_thumb_entries_20261029.log`,
  `OSOS_silver_storage_write_helpers_thumb_20261029.log`,
  `OSOS_silver_storage_raw_write_reachability_20261029.log`,
  `OSOS_silver_storage_write_method_xrefs_20261029.log`,
  `OSOS_silver_storage_secondary_factory_20261029.log`, and
  `OSOS_silver_storage_init_callers_20261029.log`: raw provider read/write
  VTables, constructor paths, and static caller limits. The write method's
  externally controllable reachability is unresolved.
- `OSOS_silver_resource_provider_read_write_methods_20261029.log`,
  `OSOS_silver_resource_slice_write_path_20261029.log`, and
  `OSOS_silver_resource_backing_io_thumb_20261029.log`: resource provider
  read/write entrypoints and backing I/O helpers. The BMap consumer's verified
  path uses the read entrypoint; open-mode semantics are not fully resolved.
- `OSOS_silver_bmap_allocator_abi_followup_20261029.log`,
  `OSOS_silver_bmap_allocator_semantics_20261029.log`,
  `OSOS_silver_bmap_pool_allocator_followup_20261029.log`,
  `OSOS_silver_bmap_heap_manager_dispatch_20261029.log`,
  `OSOS_silver_bmap_allocator_impl_followup_20261029.log`,
  `OSOS_silver_bmap_pool_allocator_fallback_20261029.log`, and
  `OSOS_silver_bmap_heap_manager_constants_20261029.log`: confirm the BMap
  element initializer is called with a 24-byte stride after unchecked 32-bit
  size multiplication; `count=0x15555556` requests 16 bytes for the record
  array and 8 for the 12-byte table. This is a conditional object-bounds/DoS
  finding if the malformed count can reach the parser and allocation succeeds;
  attacker-controlled source, adjacent-object effect, and code execution remain
  unproven.
- `OSOS_silver_raw_write_backend_followup_20261029.log`,
  `OSOS_silver_raw_write_vtable_targets_20261029.log`,
  `OSOS_silver_controller_vtable_extended_20261029.log`,
  `OSOS_silver_controller_write_targets_20261029.log`,
  `OSOS_silver_controller_io_helpers_20261029.log`,
  `OSOS_silver_vfs_open_factory_callers_20261029.log`,
  `OSOS_silver_vfs_open_callsite_windows_20261029.log`,
  `OSOS_silver_slot4_open_mode_semantics_followup_20261029.log`,
  `OSOS_silver_vfs_open_mode_dispatch_20261029.log`,
  `OSOS_silver_vfs_open_object_vtables_20261029.log`,
  `OSOS_silver_vfs_open_object_vtable_entries_20261029.log`, and
  `OSOS_silver_vfs_file_object_methods_20261029.log`: trace the raw storage
  write method through `FUN_081c3fa4` to the controller dispatcher and enumerate
  direct users of the generic VFS open factory. No whole-device bound is
  visible in the immediate wrappers, but writable resource-mode semantics
  and any host-controlled path to `APPLE_MDFW` remain unresolved. One
  controller branch checks only that the high four LBA bits are clear; the
  alternate branch has no visible LBA bound.

## Logs that must not be used to dispute Full-Body findings

`OSOS_silver_slot4_volume_io_writeability_thumb_20261029.log`,
`OSOS_silver_slot4_correct_function_entries_20261029.log`,
`OSOS_silver_slot4_volume_io_writeability_followup_20261029.log`, and
`OSOS_silver_mbr_claim_recheck_20261029.log` include unrebased Full-Body
addresses queried against the Runtime project. Their decompilations refer to
different Runtime locations (or report no function) and do not invalidate the
older Full-Body labels. Use the mapping and corrected interpretation in
`../../OSOS-SilverImagesDB-rebased-provider-followup-2026-10-29.md`.

Every Ghidra headless run used `-noanalysis -readOnly`. The logs are covered by
`SHA256SUMS`.
