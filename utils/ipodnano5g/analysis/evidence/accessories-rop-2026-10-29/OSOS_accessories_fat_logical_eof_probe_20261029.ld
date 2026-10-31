OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
  start PT_LOAD FLAGS(5);
  runtime PT_LOAD FLAGS(5);
  handle_lookup PT_LOAD FLAGS(5);
  cluster_map PT_LOAD FLAGS(5);
  sector_map PT_LOAD FLAGS(5);
  fat_io_stubs PT_LOAD FLAGS(5);
  volume_stubs PT_LOAD FLAGS(5);
  stack PT_LOAD FLAGS(6);
  state PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start

  . = 0x0814346c;
  .runtime_fat_reader : { *(.runtime_fat_reader) } :runtime
  . = 0x0814ed8c;
  .stub_no_next_cluster : { *(.stub_no_next_cluster) } :runtime

  . = 0x081d7e1a;
  .stub_cluster_map : { *(.stub_cluster_map) } :cluster_map

  . = 0x082133ec;
  .stub_volume_unlock : { *(.stub_volume_unlock) } :volume_stubs
  . = 0x08213730;
  .stub_volume_lock : { *(.stub_noop_lock) } :volume_stubs
  . = 0x08213744;
  .stub_handle_unlock : { *(.stub_handle_unlock) } :volume_stubs
  . = 0x08213844;
  .stub_error_log : { *(.stub_error_log) } :volume_stubs

  . = 0x082191c2;
  .stub_memcpy : { *(.stub_memcpy) } :fat_io_stubs
  . = 0x08219258;
  .stub_cache_valid : { *(.stub_cache_valid) } :fat_io_stubs
  . = 0x08219310;
  .stub_bulk_read : { *(.stub_bulk_read) } :fat_io_stubs
  . = 0x0821959c;
  .stub_cache_get : { *(.stub_cache_get) } :fat_io_stubs
  . = 0x082195ee;
  .stub_cache_release : { *(.stub_cache_release) } :fat_io_stubs

  . = 0x0822641e;
  .stub_sector_map : { *(.stub_sector_map) } :sector_map

  . = 0x08240624;
  .stub_handle_lookup : { *(.stub_handle_lookup) } :handle_lookup

  . = 0x08e55000;
  .stack_space (NOLOAD) : { *(.stack) } :stack
  stack_top = .;

  . = 0x08e58000;
  .state : { *(.state) } :state

  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
