$define ADDRESS 0x1000000C

$section .text
      mv  t0, 3
      mv  t1, 4
      beq t0, t1, ADDRESS
      j   EXIT
      mv  t1, 69
EXIT: mv  t0, t0
