OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
PHDRS
{
  start PT_LOAD FLAGS(7);
  lfn PT_LOAD FLAGS(5);
  copy PT_LOAD FLAGS(5);
  cache PT_LOAD FLAGS(5);
  utf PT_LOAD FLAGS(5);
  release PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start
  . = 0x08159128;
  .lfn : { *(.lfn) } :lfn
  . = 0x08160828;
  .copy : { *(.copy) } :copy
  . = 0x081c00f4;
  .utf_stub : { *(.utf_stub) } :utf
  . = 0x0821959c;
  .cache_get : { *(.cache_get) } :cache
  . = 0x082195ee;
  .release_stub : { *(.release_stub) } :release
  . = 0x08e55000;
  .data : { *(.data) } :data
  .text : { *(.text*) }
  .rodata : { *(.rodata*) }
  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
