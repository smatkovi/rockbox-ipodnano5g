PHDRS
{
  harness PT_LOAD FLAGS(7);
  runtime PT_LOAD FLAGS(7);
  external_data PT_LOAD FLAGS(6);
  registry PT_LOAD FLAGS(6);
  manager PT_LOAD FLAGS(6);
  arena PT_LOAD FLAGS(6);
  ext PT_LOAD FLAGS(5);
  stack PT_LOAD FLAGS(6);
}

SECTIONS
{
  . = 0x00010000;
  .start : { *(.start) } :harness
  .harness_text : { *(.harness_text) } :harness
  .xml_input : { *(.xml_input) } :harness
  .messages : { *(.messages) } :harness
  .harness_data : { *(.harness_data) } :harness

  . = 0x08000000;
  .runtime : { *(.runtime) } :runtime

  . = 0x08e53000;
  .external_data : { *(.external_data) } :external_data

  . = 0x086ca000;
  .registry (NOLOAD) : { *(.registry) } :registry

  . = 0x086cf000;
  .manager (NOLOAD) : { *(.manager) } :manager

  /* The mapped arena starts on the page after the original charset table.
     HEAP_BASE may be 0x08e54e4c, in the zero-filled tail of that prior page. */
  . = 0x08e55000;
  .arena (NOLOAD) : { *(.arena) } :arena

  . = 0x22000000;
  .ext : { *(.ext) } :ext

  . = 0x23000000;
  .stack (NOLOAD) : { *(.stack) } :stack

  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) *(.eh_frame*) }
}
