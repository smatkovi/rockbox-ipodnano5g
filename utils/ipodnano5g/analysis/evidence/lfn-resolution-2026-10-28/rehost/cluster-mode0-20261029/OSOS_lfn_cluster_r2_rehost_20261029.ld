OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)
PHDRS
{
  start PT_LOAD FLAGS(7);
  advance PT_LOAD FLAGS(5);
  cluster PT_LOAD FLAGS(5);
  divhead PT_LOAD FLAGS(5);
  divtail PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS
{
  . = 0x08010000;
  .start : { *(.start) } :start
  . = 0x081608f8;
  .advance : { *(.advance) } :advance
  . = 0x0816a970;
  .cluster_test : { *(.cluster_test) } :cluster
  . = 0x0818e65c;
  .divider_entry : { *(.divider_entry) } :divhead
  . = 0x0818f720;
  .divider_tail : { *(.divider_tail) } :divtail
  . = 0x08e55000;
  .data : { *(.data) } :data
  /DISCARD/ : { *(.comment) *(.note*) *(.ARM.attributes) }
}
