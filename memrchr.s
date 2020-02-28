
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
    vfirst.m a4, v0          # find lowest index of set mask bit
    bgez a4, .Lmatch         # branch if greater-than-or-equal-to-zero
    sub a2, a2, a3           # decrement n
    bnez a2, .Loop           # branch if not-equal to zero, i.e. continue loop
    li a0, 0                 # load-immediate NULL as return value
    ret

.Lmatch:                     # since we don't have vlast.m we use vid instead
    li a6, 256               # with vid, we can only index up to 256 elements
                             # i.e. a register group with more than
                             # 256 * 8 bits would overflow the index
    mv a2, a3                # limit remaining size to vl
.Loop2:
    # minu t0, a3, a6        # requires "B"itmanip extension
    mv t0, a3                # initialize t0 with current vl
    ble a3, a6, 1f           # branch if less-than-or-equal-to 256
    mv t0, a6                # otherwise set to 256, i.e. our minimum
1:
    vsetvli t1, t0, e8, m8   # make sure to consider the first 256 elements,
                             # at most

    # the code also works without limiting the vl to 256, but then we get into
    # O(n^2) comparisons

    vid.v v16, v0.t          # write element index in each masked element
    vredmaxu.vs v24, v16, v16, v0.t # v24[0] = max_unsigned(v16[*], v16[0])

    vmv.x.s a5, v24          # move first vector element to register
    andi    a5, a5, 0xff     # remove sign bits in case element
                             # was sign-extended
    add a7, a0, a5           # move possible result into extra register
                             
    ble a3, a6, .Ldone       # branch if less-than-or-equal-to 256,
                             # i.e. jump is the happy case

                             # tedious case: register group has more than 256
                             # elements, i.e. the remaining elements might contain
                             # another match

    vsetvli a3, a3, e8, m8   # restore previous config

    addi a5, a5, 1           # add immediate to skip over the current maximum
    add a0, a0, a5           # increment src
    sub a2, a2, a5           # decrement n

    vslidedown.vx v8, v8, a5 # move out the lowest already visited elements

    vsetvli a3, a2, e8, m8   # update config
    vmseq.vx v0, v8, a1      # set mask bit for each element equal to scalar
    vfirst.m a4, v0          # move index of first set mask bit into register
    bgez a4, .Loop2          # branch if greater-than-or-equal-to-zero
.Ldone:
    mv a0, a7                # move right-most match into ret val register
    ret
