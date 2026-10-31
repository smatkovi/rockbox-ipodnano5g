OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
stack_base = 0x08e55000;

PHDRS
{
  start PT_LOAD FLAGS(5);
  binary_reader PT_LOAD FLAGS(5);
  parser_function PT_LOAD FLAGS(5);
  parser_initializer_a PT_LOAD FLAGS(5);
  parser_initializer_b PT_LOAD FLAGS(5);
  parser_path_create PT_LOAD FLAGS(5);
  parser_temp_destructor PT_LOAD FLAGS(5);
  string_valid PT_LOAD FLAGS(5);
  string_assign PT_LOAD FLAGS(5);
  string_vtable PT_LOAD FLAGS(4);
  parser_tag_helpers PT_LOAD FLAGS(5);
  read_word PT_LOAD FLAGS(5);
  global_string_object PT_LOAD FLAGS(4);
  initial_pop PT_LOAD FLAGS(5);
  stack_pointer PT_LOAD FLAGS(5);
  stack_return PT_LOAD FLAGS(5);
  sub_e0 PT_LOAD FLAGS(5);
  sub_20 PT_LOAD FLAGS(5);
  sub_18 PT_LOAD FLAGS(5);
  trampoline PT_LOAD FLAGS(5);
  writer PT_LOAD FLAGS(5);
  sub_8c PT_LOAD FLAGS(5);
  sub_28 PT_LOAD FLAGS(5);
  sub_18_pc PT_LOAD FLAGS(5);
  copy_r0_to_r1 PT_LOAD FLAGS(5);
  string_dtor PT_LOAD FLAGS(5);
  constructor_stub PT_LOAD FLAGS(5);
  stream_functions PT_LOAD FLAGS(5);
  read_stub PT_LOAD FLAGS(5);
  read_finish PT_LOAD FLAGS(5);
  loader PT_LOAD FLAGS(7);
  loader_area PT_LOAD FLAGS(7);
  rockbox_bss PT_LOAD FLAGS(6);
  boot_source PT_LOAD FLAGS(4);
  static_zero PT_LOAD FLAGS(4);
  stack PT_LOAD FLAGS(6);
  input PT_LOAD FLAGS(4);
  state PT_LOAD FLAGS(6);
  combined_setup PT_LOAD FLAGS(5);
  dispatcher_copy PT_LOAD FLAGS(5);
  wrapper_router PT_LOAD FLAGS(5);
  provider PT_LOAD FLAGS(7);
  fat_helper PT_LOAD FLAGS(7);
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
  wrapper_fileerr PT_LOAD FLAGS(5);
  wrapper_lock PT_LOAD FLAGS(5);
  wrapper_is_open PT_LOAD FLAGS(5);
  wrapper_unlock PT_LOAD FLAGS(5);
  wrapper_getprovider PT_LOAD FLAGS(5);
  stream_0819887c PT_LOAD FLAGS(5);
  stream_081b832e PT_LOAD FLAGS(5);
  stream_memcpy PT_LOAD FLAGS(5);
  stream_0820cc90 PT_LOAD FLAGS(5);
  stream_0823c9c0 PT_LOAD FLAGS(5);
  stream_082783be PT_LOAD FLAGS(5);
  stream_082a2c48 PT_LOAD FLAGS(5);
  parser_object PT_LOAD FLAGS(6);
  provider_state PT_LOAD FLAGS(6);
  parser_runtime_data PT_LOAD FLAGS(6);
  scratch PT_LOAD FLAGS(6);
  read_entry_prefix PT_LOAD FLAGS(5);
}

SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start
  . = 0x08011000;
  .combined_setup : { *(.combined_setup) } :combined_setup
  . = 0x08012000;
  .dispatcher_copy : { *(.dispatcher_copy) } :dispatcher_copy
  . = 0x08013000;
  .wrapper_router : { *(.wrapper_router) } :wrapper_router
  . = 0x08039048;
  .binary_reader : { *(.binary_reader) } :binary_reader
  . = 0x0802c3c4;
  .parser_function : { *(.parser_function) } :parser_function
  . = 0x0802c520;
  .parser_literals : { *(.parser_literals) } :parser_function
  . = 0x08007106;
  .initial_pop : { *(.initial_pop) } :initial_pop
  . = 0x0800396c;
  .stack_pointer : { *(.stack_pointer) } :stack_pointer
  . = 0x08190ab6;
  .stack_return : { *(.stack_return) } :stack_return
  . = 0x08005cc2;
  .sub_e0 : { *(.sub_e0) } :sub_e0
  . = 0x080066b2;
  .sub_20 : { *(.sub_20) } :sub_20
  . = 0x0809cf54;
  .sub_18 : { *(.sub_18) } :sub_18
  . = 0x08030cbc;
  .trampoline : { *(.trampoline) } :trampoline
  . = 0x0805b090;
  .writer : { *(.writer) } :writer
  . = 0x08262d50;
  .sub_8c : { *(.sub_8c) } :sub_8c
  . = 0x081df4be;
  .sub_28 : { *(.sub_28) } :sub_28
  . = 0x080f8a32;
  .sub_18_pc : { *(.sub_18_pc) } :sub_18_pc
  . = 0x0818a910;
  .copy_r0_to_r1 : { *(.copy_r0_to_r1) } :copy_r0_to_r1
  . = 0x0818ebc0;
  .parser_temp_destructor : { *(.parser_temp_destructor) } :parser_temp_destructor
  . = 0x081936ec;
  .string_assign_original : { *(.string_assign_original) } :string_assign
  . = 0x0819e9a4;
  .parser_path_create : { *(.parser_path_create) } :parser_path_create
  . = 0x081965fe;
  .string_valid_original : { *(.string_valid_original) } :string_valid
  . = 0x081a3790;
  .parser_initializer_b : { *(.parser_initializer_b) } :parser_initializer_b
  . = 0x0827e7ca;
  .parser_initializer_a : { *(.parser_initializer_a) } :parser_initializer_a
  . = 0x081ada60;
  .string_dtor_stub : { *(.string_dtor_stub) } :string_dtor
  . = 0x08198770;
  .constructor_stub : { *(.constructor_stub) } :constructor_stub
  . = 0x0826abb0;
  .integer_reader_original 0x0826ab24 : { *(.integer_reader_original) } :parser_tag_helpers
  .container_check_original 0x0826abb0 : { *(.container_check_original) } :parser_tag_helpers
  . = 0x0823f4f4;
  .read_word_original : { *(.read_word_original) } :read_word
  . = 0x085354d8;
  .string_vtable : { *(.string_vtable) } :string_vtable
  . = 0x0866cc38;
  .global_string_object : { *(.global_string_object) } :global_string_object
  . = 0x082721d8;
  .close_wrapper : { *(.close_wrapper) } :stream_functions
  . = 0x082721f0;
  .open_stub : { *(.open_stub) } :stream_functions
  . = 0x08268c3a;
  .read_entry_prefix : { *(.read_entry_prefix) } :read_entry_prefix
  . = 0x08268c3c;
  .read_entry : { *(.read_entry) } :read_stub
  . = 0x0826dd26;
  .token_reader_original : { *(.token_reader_original) } :read_finish

  . = 0x0812ac00;
  .runtime_provider : { *(.runtime_provider) } :provider
  . = 0x0812ac7c;
  .provider_data : { *(.provider_data) } :provider
  . = 0x081384b0;
  .runtime_fat_helper : { *(.runtime_fat_helper) } :fat_helper
  . = 0x081384c4;
  .fat_helper_sentinel : { *(.fat_helper_sentinel) } :fat_helper
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
  .stub_file_error_check : { *(.stub_file_error_check) } :wrapper_fileerr
  . = 0x0827310a;
  .stub_provider_lock : { *(.stub_provider_lock) } :wrapper_lock
  . = 0x08278cc2;
  .stub_is_open : { *(.stub_is_open) } :wrapper_is_open
  . = 0x08279d68;
  .stub_provider_unlock : { *(.stub_provider_unlock) } :wrapper_unlock
  . = 0x0827dce0;
  .stub_get_provider : { *(.stub_get_provider) } :wrapper_getprovider
  . = 0x08200600;
  .stream_memcpy : { *(.stream_memcpy) } :stream_memcpy
  . = 0x0819887c;
  . = 0x081b832e;
  .runtime_081b832e : { *(.runtime_081b832e) } :stream_081b832e
  . = 0x0820cc90;
  .runtime_0820cc90 : { *(.runtime_0820cc90) } :stream_0820cc90
  . = 0x0823c9c0;
  .runtime_0823c9c0 : { *(.runtime_0823c9c0) } :stream_0823c9c0
  . = 0x082783be;
  .runtime_082783be : { *(.runtime_082783be) } :stream_082783be
  . = 0x082a2c48;
  .runtime_082a2c48 : { *(.runtime_082a2c48) } :stream_082a2c48
  . = 0x08fffff8;
  .loader_area (NOLOAD) : { . += 0x10f88; } :loader_area
  . = 0x09100000;
  .rockbox_bss (NOLOAD) : { . += 0x9fd00; } :rockbox_bss
  . = 0x09300000;
  .loader_impl : { *(.loader_impl) } :loader
  . = 0x09400000;
  .boot_source : { *(.boot_source) } :boot_source
  . = 0x084f59e0;
  .stream_close_sentinel : { *(.stream_close_sentinel) } :static_zero
  . = stack_base - 0x1000;
  .stack_space (NOLOAD) : { . += 0x4000; stack_top = .; } :stack
  . = 0x08e58000;
  .parser_object : { *(.parser_object) } :parser_object
  . = 0x08e5a000;
  .provider_state : { *(.provider_state) } :provider_state
  . = 0x08e5d000;
  .parser_runtime_data : { *(.parser_runtime_data) } :parser_runtime_data
  . = 0x08e60000;
  .scratch (NOLOAD) : { . += 0x1000; } :scratch
  . = 0x08e61000;
  .input_wire : { *(.input_wire) } :input
  . = 0x08e64000;
  .state : { *(.state) } :state
  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
