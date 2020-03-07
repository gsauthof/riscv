This repository contains RISC-V assembly examples.


## RISC-V Vector Assembly Code Examples

These example use RISC-V "V" vector instructions (version 0.8).

- bcd2ascii.s - convert BCD strings into ASCII strings. See also
  https://gms.tf/riscv-vector.html for details.
- ascii2bcd.s - convert ASCII strings into BCD strings.
- memchr.s - vector version of the well-known
  [`memchr()`](https://manpath.be/c8/3/memchr) libc function
- mempchr.s - similar to `memchr()`, but `mempchr()` returns the
  one-past-the-end pointer instead of `NULL`. This is more useful
  e.g.  in text scanning code.
- memrchr.s - vector version of the well-known
  [`memrchr()`](https://manpath.be/c8/3/memrchr) libc function
- memcmp.s - vector version of the well-known
  [`memcmp()`](https://manpath.be/c8/3/memcmp) libc function
- rawmemchr.s - vector version of the well-known
  [`rawmemchr()`](https://manpath.be/c8/3/rawmemchr) glibc function
- strlen.s, strlen_small.s - vector versions of the well-known
  [`strlen()`](https://manpath.be/c8/3/strlen) libc function

### See Also

The RISC-V "V" extension specification contains several
vector assembly code example, e.g. [vector versions of `memcpy()`,
`strcpy()`, `strncpy()` and `strlen()`](https://github.com/gsauthof/riscv-v-spec/tree/example-files/example).

## Other Examples

- rotate.s - the general purpose RISC-V instruction sets don't
  include rotate instructions, instead they are part of the
  Bitmanip "B" extension. This example shows how to bit-rotate
  without the "B" extension.

## Comparison with x86 SIMD

To stress the point that a length agnostic vector instruction set
allows to write very compact (and arguably elegant) code (cf.
https://gms.tf/riscv-vector.html), this repository also contains
an x86 SIMD version of `bcd2ascii.s`: `x86_64/bcd2ascii.S` It
requires many more instructions because of extra code that deals
with input that isn't dividable by the SIMD register size.

It also demonstrates how many x86 SIMD instructions encode into
4 or more bytes due to the bloated x86 opcode space:

    $ objdump -M intel -d bcd2ascii.o | grep '^.*\<v[^ ]*' -o \
         | awk '{ print NF-2, $NF }'

(whereas RISC-V vector instructions uniformly encode into 4 bytes)

2020, Georg Sauthoff <mail@gms.tf>
