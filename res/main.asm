$define VAL_1 8
$define VAL_2 16

$section .text
            mov r1, VAL_1
            mov r2, VAL_2
            cmp r2, r1
            bgt GREATER
            mov r0, 1
            b   CONTINUE
GREATER:    mov r0, 2
CONTINUE:   mov r0, r0
