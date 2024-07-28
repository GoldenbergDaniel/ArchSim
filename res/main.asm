mov r0, 8
shr r1, r0, 1
shl r2, r0, 1
cmp r1, r2
jlt 0x6
jgt 0x8
mov r0, 0
j   0x9
mov r0, 1
mov r0, r0
