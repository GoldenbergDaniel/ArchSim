.equ ADDRESS 0x10000FF0

.byte BYTE 0xAA
.half HALF 0xBBBB
.word WORD 0xCCCCCCCC

.section .text
      lw  t0, BYTE[0]
EXIT: nop
