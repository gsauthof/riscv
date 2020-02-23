
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# int memcmp(const void *u, const void *v, size_t n);
#
# a0 = u, a1 = v, a2 = n
#
    .global memcmp
memcmp:
    vsetvli a3, a2, e8, m8     # switch to 8 bit element size,
                               # i.e. 4 groups of 8 registers
    vlb.v v8,  (a0)            # load a3 bytes from u
    vlb.v v16, (a1)            # load a3 bytes from v
    vmsne.vv v0, v8, v16       # set mask bit if elements are not equal
    vfirst.m a4, v0            # find lowest index of set mask bit
    bgez a4, 1f                # branch if greater-or-equal to zero
    add a0, a0, a3             # increment u
    add a1, a1, a3             # increment v
    sub a2, a2, a3             # decrement n
    bnez a2, memcmp            # branch if not-equal to zero, i.e. cont. loop
    li a0, 0                   # return 0
    ret
1:
    vslidedown.vx v0, v8, a4   # move matching element to the first position
    vslidedown.vx v24, v16, a4 # move matching element to the first position
    li a5, 1                   # load immediate
    vsetvli t0, a5, e8, m1     # change number of groups for the widening op
                               # (with m8 it would yield an illegal instr.)
    vwsubu.vv v8, v0, v24      # widening unsigned subtract,
                               # i.e. zero-extend operands
    vsetvli t0, a5, e16, m1    # update config to access the widened result
    vmv.x.s a0, v8             # move the first element in v8 to scalar a0
                               # (also sign-extends it)
    ret
