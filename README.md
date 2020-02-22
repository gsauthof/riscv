This repository contains RISC-V assembly examples.

- bcd2ascii.s - uses RISC-V "V" vector instructions (version 0.8)
  for converting BCD strings into ASCII strings. See also
  https://gms.tf/riscv-vector.html for details.
- ascii2bcd.s - used RISC-V "V" vector instruction (version 0.8)
  for converting ASCII strings into BCD strings.
- rotate.s - the general purpose RISC-V instruction sets don't
  include rotate instructions, instead they are part of the
  Bitmanip "B" extension. This example shows how to bit-rotate
  without the "B" extension.

2020, Georg Sauthoff <mail@gms.tf>
