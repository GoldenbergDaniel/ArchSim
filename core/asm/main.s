.equ ADDRESS 0x10000FF0

.section .data
.byte BYTE 0xAA, 0xBB, 0xCC
.half HALF 0xBBBB
.word WORD 0xCCCCCCCC
.ascii STRING "hellope!"

.section .text
      j   MAIN


// Add a0 to s1
PROC:       
      add  s1, s1, a0
      ret


MAIN:
      li  a0, 'A'
      jal PROC
      lb  t0, BYTE[0]
EXIT: 
      mv  s1, s1