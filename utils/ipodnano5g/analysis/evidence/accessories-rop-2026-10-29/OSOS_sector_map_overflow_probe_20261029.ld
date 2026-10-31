OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
PHDRS
{
  start PT_LOAD FLAGS(5);
  dir_map PT_LOAD FLAGS(5);
  sector_map PT_LOAD FLAGS(5);
  cluster_decode PT_LOAD FLAGS(5);
  mounted_stub PT_LOAD FLAGS(5);
  state PT_LOAD FLAGS(6);
  stack PT_LOAD FLAGS(6);
}
SECTIONS
{
  . = 0x08010000;
  .start : { KEEP(*(.start)) } :start
  .fail : { KEEP(*(.fail)) } :start

  . = 0x08158d00;
  .runtime_dir_entry_mapper : { KEEP(*(.runtime_dir_entry_mapper)) } :dir_map

  . = 0x0822641e;
  .runtime_sector_map : { KEEP(*(.runtime_sector_map)) } :sector_map

  . = 0x08229210;
  .runtime_cluster_decode : { KEEP(*(.runtime_cluster_decode)) } :cluster_decode

  . = 0x08229880;
  .stub_volume_mounted : { KEEP(*(.stub_volume_mounted)) } :mounted_stub

  . = 0x08e50000;
  .state : { KEEP(*(.state)) } :state
  .stack (NOLOAD) : { KEEP(*(.stack)) } :stack

  /DISCARD/ : { *(.interp) *(.dynamic) *(.dynsym) *(.dynstr) *(.comment) *(.note*) *(.ARM.attributes) }
}
