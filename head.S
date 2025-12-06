.section .text.init
.global _start
_start:
    la sp, _stack_top
    call main

    # Exit Sequence
    slli t0, a0, 1
    ori  t0, t0, 1
    la t1, tohost
    sd t0, 0(t1)
1:  j 1b

.section .tohost
.align 6
.global tohost
tohost: .dword 0
.global fromhost
fromhost: .dword 0
