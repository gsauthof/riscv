.section .text
.globl _start
_start:

    li a0, 1                    # stdout

#   la a0, msg                  # load address (pseudo instruction)
#                               # i.e. PC relative

    # alternatively:
#1: auipc a1,     %pcrel_hi(msg)
#   addi  a1, a1, %pcrel_lo(1b)

    # alternatively (absolute/position dependent):
    lui  a1,     %hi(msg)
    addi a1, a1, %lo(msg)

    li a2, 12                   # string length
    li a7, 64                   # _NR_sys_write
    ecall                       # invoke system call


    li a0, 0                    # exit status
    li a7, 93                   # _NR_sys_exit
    ecall                       # invoke system call

.Loop:
    j .Loop                     # in case exit syscall fails ...

.section .rodata
msg:
    .string "Hello World\n"
