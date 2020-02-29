
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# void *memrchr(const void *src, int c, size_t n);
#
# a0 = src, a1 = c, a2 = n
#
    .global memrchr
memrchr:
    add a0, a0, a2           # set to one past the last char
.Loop:
    vsetvli a3, a2, e8, m8   # switch to 8 bit element size,
                             # i.e. 4 groups of 8 registers
    sub a0, a0, a3           # decrement end pointer
    vlb.v v8, (a0)           # load a3 bytes
    vmseq.vx v0, v8, a1      # set mask bit if equal to scalar c

    # since there is no vlast.m, we have to use vfirst.m and post-process

    vfirst.m a4, v0          # find lowest index of set mask bit
    bgez a4, .Lmatch         # branch if greater-than-or-equal-to-zero
    sub a2, a2, a3           # decrement n
    bnez a2, .Loop           # branch if not-equal to zero, i.e. continue loop
    li a0, 0                 # load-immediate NULL as return value
    ret
.Lmatch:
    li a7, 256               # maximum vl that doesn't overflow 8bit indices
.Loop2:
    ble a3, a7, .Ldone       # branch if less-than-or-equal-to 256,
                             # i.e. jump is the happy case

    # otherwise, divide & conquer the vector

    srli a5, a3, 1           # divide vl by 2
    sub a6, a3, a5           # in case vl was odd, i.e.
                             # high_part_size = a6, low_part_size = a5

                             # move the high part into v16
    vslidedown.vx v16, v8, a5

    vsetvli t0, a6, e8, m8   # ignore tailing bytes in the high_part

    vmseq.vx v24, v16, a1    # check for matches in the high part
    vfirst.m a4, v24         # store index of first match

    vsetvli a3, a5, e8, m8   # update config for lower part, in case we branch
    bltz a4, .Loop2          # branch if less-than-zero

    vsetvli a3, a6, e8, m8   # restore config for higher part
    vmv.v.v v8, v16          # vector mv high part to low part
    vmcpy.m v0, v24          # restore mask in higher part
    add a0, a0, a5           # increment src by size of low part

    j .Loop2                 # unconditionally branch to loop head
.Ldone:
    vid.v v16, v0.t          # write element index in each masked element

                             # v24[0] = max_unsigned(v16[*], v16[0])
    vredmaxu.vs v24, v16, v16, v0.t

    vmv.x.s a5, v24          # move first vector element to register
    andi    a5, a5, 0xff     # remove sign bits in case element

    add a0, a0, a5
    ret
