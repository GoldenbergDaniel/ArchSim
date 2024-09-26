.equ ADDRESS 0x10000FF0

.section .data
.byte BYTE 0xAA
.half HALF 0xBBBB
.word WORD 0xCCCCCCCC

.section .text
            j   MAIN


// Add a0 to s1
PROC:       add  s1, a0
            ret


MAIN:       li  a0, 3
            jal PROC
            lb  t0, BYTE[0]
EXIT:       mv  s1, s1
