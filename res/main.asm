$define ADDRESS 0x1000000C

$section .text
      mov r0, ADDRESS
      mov r3, -1
      br  r0
      mov r1, 69
EXIT: mov r0, r0
