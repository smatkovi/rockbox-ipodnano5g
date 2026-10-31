OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

PHDRS
{
  start PT_LOAD FLAGS(5);
  runtime PT_LOAD FLAGS(5);
  stub_file_error PT_LOAD FLAGS(5);
  stub_lock PT_LOAD FLAGS(5);
  stub_is_open PT_LOAD FLAGS(5);
  stub_unlock PT_LOAD FLAGS(5);
  stub_get_provider PT_LOAD FLAGS(5);
  provider_read PT_LOAD FLAGS(5);
  stack PT_LOAD FLAGS(6);
  state PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start

  . = 0x081fd5e8;
  .runtime_function : { *(.runtime_function) } :runtime

  . = 0x08270700;
  .stub_file_error_check : { *(.stub_file_error_check) } :stub_file_error

  . = 0x0827310a;
  .stub_lock : { *(.stub_lock) } :stub_lock

  . = 0x08278cc2;
  .stub_is_open : { *(.stub_is_open) } :stub_is_open

  . = 0x08279d68;
  .stub_unlock : { *(.stub_unlock) } :stub_unlock

  . = 0x0827dce0;
  .stub_get_provider : { *(.stub_get_provider) } :stub_get_provider

  . = 0x08280000;
  .provider_read : { *(.provider_read) } :provider_read

  . = 0x08e55000;
  .stack_space (NOLOAD) : { . += 0x2000; } :stack
  stack_top = .;

  . = 0x08e58000;
  .state : { *(.state) } :state

  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
