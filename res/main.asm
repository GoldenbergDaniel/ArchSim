$define ADDRESS 0x1000000C

$section .text
      add t0, t0, 3
      add t1, t1, 4
      sub t1, t1, t0
      beq t0, t1, EXIT
      mv  t1, t0
EXIT: nop
