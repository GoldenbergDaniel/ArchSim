.equ ADDRESS 0x10000FF0

.byte BYTE 0xAA
.half HALF 0xBBBB
.word WORD 0xCCCCCCCC

.section .text
      add t0, t0, 3
      sb  t0, ADDRESS[0]
      lh  t1, ADDRESS[0]
      lb  t2, ADDRESS[1]
EXIT: nop
