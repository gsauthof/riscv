
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# void *rawmemchr(const void *src, int c);
#
# a0 = src, a1 = c
#
    .global rawmemchr
rawmemchr:
    li t0, -1                 # set to maximum length
.Loop:
    vsetvli a2, t0, e8, m8    # switch to 8 bit element size,
                              # i.e. 4 groups of 8 registers
    vlbff.v v8, (a0)          # load a2 bytes, only fault on first byte,
                              # for other faults: set vl to #loaded bytes
    csrr a2, vl               # adjust a2 in case there was a fault

    vmseq.vx v0, v8, a1       # set mask bit if equal to scalar c
    vfirst.m a3, v0           # find lowest index of set mask bit

    add a0, a0, a2            # increment src in case there was no match
    bltz a3, .Loop            # branch if less-than-zero

    sub a0, a0, a2            # correct src because there was a match
    add a0, a0, a3            # add match index
    ret
