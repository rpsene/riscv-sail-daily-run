OUTPUT_ARCH( "riscv" )
ENTRY( _start )
PHDRS {
  text PT_LOAD FLAGS(5);
  data PT_LOAD FLAGS(6);
}
SECTIONS {
  . = 0x80000000;
  .text : { *(.text.init) *(.text) } :text
  . = ALIGN(0x1000);
  .data : { *(.tohost) *(.data) } :data
  .bss : { *(.bss) } :data
  . = . + 0x1000;
  _stack_top = .;
}
