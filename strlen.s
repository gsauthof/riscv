
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# size_t strlen(const void *src);
#
# a0 = src
#
    .global strlen
strlen:
    li t0, -1                 # set to maximum length
    mv a1, a0                 # preserve src
.Loop:
    vsetvli a2, t0, e8, m8    # switch to 8 bit element size,
                              # i.e. 4 groups of 8 registers
    vlbff.v v8, (a0)          # load a2 bytes, only fault on first byte,
                              # for other faults: set vl to #loaded bytes
    csrr a2, vl               # adjust a2 in case there was a fault

    vmseq.vi v0, v8, 0        # set mask bit if equal to immediate 0
    vfirst.m a3, v0           # find lowest index of set mask bit

    add a0, a0, a2            # increment src in case there was no match
    bltz a3, .Loop            # branch if less-than-zero

    sub a0, a0, a2            # correct src because there was a match
    add a0, a0, a3            # add match index
    sub a0, a0, a1            # subtract the start address
    ret
