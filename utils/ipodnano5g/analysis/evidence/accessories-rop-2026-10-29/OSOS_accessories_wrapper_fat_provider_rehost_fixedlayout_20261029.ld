OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
  start PT_LOAD FLAGS(5);
  isolated_start PT_LOAD FLAGS(5);
  provider PT_LOAD FLAGS(5);
  provider_data PT_LOAD FLAGS(7);
  fat_helper PT_LOAD FLAGS(5);
  fat_helper_data PT_LOAD FLAGS(7);
  fat_reader PT_LOAD FLAGS(5);
  no_next PT_LOAD FLAGS(5);
  cluster_map PT_LOAD FLAGS(5);
  file_wrapper PT_LOAD FLAGS(5);
  cluster_extent PT_LOAD FLAGS(5);
  volume_stubs PT_LOAD FLAGS(5);
  fat_io PT_LOAD FLAGS(5);
  handle_stubs PT_LOAD FLAGS(5);
  sector_map PT_LOAD FLAGS(5);
  seek_stub PT_LOAD FLAGS(5);
  fat_lookup PT_LOAD FLAGS(5);
  wrapper_stubs PT_LOAD FLAGS(5);
  stack PT_LOAD FLAGS(6);
  state PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start

  . = 0x08011000;
  .isolated_start : { *(.isolated_start) } :isolated_start

  . = 0x0812ac00;
  .runtime_provider : { *(.runtime_provider) } :provider
  . = 0x0812ac7c;
  .provider_data : { *(.provider_data) } :provider_data

  . = 0x081384b0;
  .runtime_fat_helper : { *(.runtime_fat_helper) } :fat_helper
  . = 0x081384c4;
  .fat_helper_sentinel : { *(.fat_helper_sentinel) } :fat_helper_data

  . = 0x0814346c;
  .runtime_fat_reader : { *(.runtime_fat_reader) } :fat_reader
  . = 0x0814ed8c;
  .stub_no_next_cluster : { *(.stub_no_next_cluster) } :no_next

  . = 0x081d7e1a;
  .runtime_cluster_map : { *(.runtime_cluster_map) } :cluster_map

  . = 0x081fd5e8;
  .runtime_file_wrapper : { *(.runtime_file_wrapper) } :file_wrapper

  . = 0x082014fc;
  .stub_cluster_extent : { *(.stub_cluster_extent) } :cluster_extent

  . = 0x082133ec;
  .stub_volume_unlock : { *(.stub_volume_unlock) } :volume_stubs
  . = 0x08213730;
  .stub_volume_lock : { *(.stub_volume_lock) } :volume_stubs
  . = 0x08213744;
  .stub_handle_unlock : { *(.stub_handle_unlock) } :volume_stubs
  . = 0x08213844;
  .stub_error_log : { *(.stub_error_log) } :volume_stubs

  . = 0x082191c2;
  .stub_memcpy : { *(.stub_memcpy) } :fat_io
  . = 0x08219258;
  .stub_cache_valid : { *(.stub_cache_valid) } :fat_io
  . = 0x08219310;
  .stub_bulk_read : { *(.stub_bulk_read) } :fat_io
  . = 0x0821959c;
  .stub_cache_get : { *(.stub_cache_get) } :fat_io
  . = 0x082195ee;
  .stub_cache_release : { *(.stub_cache_release) } :fat_io

  . = 0x0821aa3c;
  .stub_handle_lookup : { *(.stub_handle_lookup) } :handle_stubs
  . = 0x0821ab24;
  .stub_provider_error : { *(.stub_provider_error) } :handle_stubs

  . = 0x0822641e;
  .stub_sector_map : { *(.stub_sector_map) } :sector_map

  . = 0x0822c0d0;
  .stub_seek : { *(.stub_seek) } :seek_stub

  . = 0x08240624;
  .stub_fat_lookup : { *(.stub_fat_lookup) } :fat_lookup

  . = 0x08270700;
  .stub_file_error_check : { *(.stub_file_error_check) } :wrapper_stubs
  . = 0x0827310a;
  .stub_provider_lock : { *(.stub_provider_lock) } :wrapper_stubs
  . = 0x08278cc2;
  .stub_is_open : { *(.stub_is_open) } :wrapper_stubs
  . = 0x08279d68;
  .stub_provider_unlock : { *(.stub_provider_unlock) } :wrapper_stubs
  . = 0x0827dce0;
  .stub_get_provider : { *(.stub_get_provider) } :wrapper_stubs

  . = 0x08e55000;
  .stack_space (NOLOAD) : { *(.stack) } :stack
  stack_top = .;

  . = 0x08e58000;
  .state : { *(.state) } :state

  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
