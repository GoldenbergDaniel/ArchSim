$define ADDRESS 0x10000FF0

$section .text
      add t0, t0, 2300 
      sh  t0, ADDRESS[0]
      lb  t0, ADDRESS[0]
      lb  t1, ADDRESS[1]
      lh  t2, ADDRESS[0]
EXIT: nop
