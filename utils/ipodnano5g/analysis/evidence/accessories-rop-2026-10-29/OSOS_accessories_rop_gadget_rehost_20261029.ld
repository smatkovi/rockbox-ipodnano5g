OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
stack_base = 0x08e55000;

PHDRS
{
  start PT_LOAD FLAGS(5);
  binary_reader PT_LOAD FLAGS(5);
  parser_epilogue PT_LOAD FLAGS(5);
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
  static_zero PT_LOAD FLAGS(4);
  stack PT_LOAD FLAGS(6);
  input PT_LOAD FLAGS(4);
  state PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start
  . = 0x08039048;
  .binary_reader : { *(.binary_reader) } :binary_reader
  . = 0x0802c504;
  .parser_epilogue : { *(.parser_epilogue) } :parser_epilogue
  . = 0x0802c528;
  .parser_epilogue_literal : { *(.parser_epilogue_literal) } :parser_epilogue
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
  . = 0x081ada60;
  .string_dtor_stub : { *(.string_dtor_stub) } :string_dtor
  . = 0x08198770;
  .constructor_stub : { *(.constructor_stub) } :constructor_stub
  . = 0x082721d8;
  .close_wrapper : { *(.close_wrapper) } :stream_functions
  . = 0x082721f0;
  .open_stub : { *(.open_stub) } :stream_functions
  . = 0x08268c3a;
  .read_entry : { *(.read_entry) } :read_stub
  . = 0x08268c40;
  .read_impl : { *(.read_impl) } :read_stub
  . = 0x0826dd26;
  .read_finish_stub : { *(.read_finish_stub) } :read_finish
  . = 0x09000000;
  .loader_entry : { *(.loader_entry) } :loader
  . = 0x09000040;
  .cleanup_probe : { *(.cleanup_probe) } :loader
  . = 0x09000100;
  .loader_impl : { *(.loader_impl) } :loader
  . = 0x084f59e0;
  .stream_close_sentinel : { *(.stream_close_sentinel) } :static_zero
  . = stack_base - 0x1000;
  .stack_space (NOLOAD) : { . += 0x2000; } :stack
  . = 0x08e56000;
  .state : { *(.state) } :state
  . = 0x08e57000;
  .input_field : { *(.input_field) } :input
  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
