
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# void *mempchr(const void *src, int c, size_t n);
#
# a0 = src, a1 = c, a2 = n
#
# i.e. return src+n if character is not found
#
    .global mempchr
mempchr:
    vsetvli a3, a2, e8, m8    # switch to 8 bit element size,
                              # i.e. 4 groups of 8 registers
    vlb.v v8, (a0)            # load a3 bytes
    vmseq.vx v0, v8, a1       # set mask bit if equal to scalar c
    vfirst.m a4, v0           # find lowest index of set mask bit
    bgez a4, 1f               # branch if greater-or-equal to zero
    add a0, a0, a3            # increment src
    sub a2, a2, a3            # decrement n
    bnez a2, mempchr          # branch if not-equal to zero, i.e. continue loop
    ret
1:
    add a0, a0, a4            # increment src by match offset
    ret
