$define ADDRESS 0x1000000C

$section .text
      mv  t0, 3
      mv  t1, 4
      add t1, t1, t0
      bne t0, t1, EXIT
      mv  t1, 69
EXIT: mv  t0, t0
