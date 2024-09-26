.equ ADDRESS 0x10000FF0

.byte BYTE 0xAA
.half HALF 0xBBBB
.word WORD 0xCCCCCCCC

.section .text
      mv  t0, 0x1000000C
      jr  t0
      mv  t0, -1
EXIT: nop
