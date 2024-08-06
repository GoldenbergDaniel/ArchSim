$define VAL_1 8
$define VAL_2 16

$section .data
val = 1

$section .text
          mov x1, VAL_1
          mov r2, VAL_2
          cmp r1, r2
          bgt LABEL_1
          blt LABEL_2
LABEL_1:  mov r0, 1
          b   LABEL_3   
LABEL_2:  mov r0, 2
LABEL_3:  mov r0, r0

