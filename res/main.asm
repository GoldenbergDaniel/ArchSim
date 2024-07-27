mov r0, 8
shr r1, r0, 1
shl r2, r0, 1
cmp r1, r2
jlt 6
jgt 8
mov r0, 0
jmp 9
mov r0, 1
mov r0, r0
