# void *ascii2bcd(void* dst, const void* src, size_t n);
#
# a0 = dst, a1 = src, a2 = n
#
#            n: size of src in bytes, multiple of 2
# return value: dst + n/2

# Alternative declaration:
#
# struct Void_Pair { void *fst; void *snd; };
# typedef struct Void_Pair Void_Pair;
# Void_Pair ascii2bcd(void* dst, const void* src, size_t n);
#
# return value: (Void_Pair){dst + n/2, src + n}

# Regarding the comments:
# Register content is written right-to-left, starting with the
# least-significant element - enclosed by | |.
# Nibbles (i.e. 4 bit byte halves) are sometimes denoted by variables
# g, h, i, j, ...

# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text                     # Start text section
    #.balign 4                # align section to 4 bytes - which is also the default?
    .global ascii2bcd         # define global function symbol
ascii2bcd:
    li a3, 57                 # load immediate '9'
    # ## Main load,convert and store loop
.Loop:
    vsetvli a4, a2, e8, m8    # switch to 16 bit element size,
                              # i.e. 4 groups of 8 registers

    vlb.v v8, (a1)           # Load a4 bytes
    # --> v8  = | ..., a[2], a[1], a[0] |, ...,
    #     v15 = | ... |
    # --> v8  = | ..., l, k, j, i, h, g |
    add a1, a1, a4            # increment src by read bytes
    sub a2, a2, a4            # decrement n by read bytes

    vmsgtu.vx v0, v8, a3      # create mask for elements greater than '9'
    vadd.vi v8, v8, 9, v0.t   # masked add for the additional offset
    vand.vi v8, v8, 0xf       # mask low nibble, cf. 2x5 bit ASCII table
    # --> v8  = | ..., 0l, 0k, 0j, 0i, 0h, 0g |

    srli a4, a4, 1            # shift-right logical by 1 bit, i.e. divide by 2
    vsetvli a4, a4, e16, m8   # switch to 16 bit element size,
                              # i.e. 4 groups of 8 registers
    # --> v8  = | ..., 0l 0k, 0j 0i, 0h 0g |
    vsrl.vi v16, v8, 8        # shift-right logical each element by 8 bits
    # --> v16  = | ..., 00 0l, 00 0j, 00 0h |
    vsll.vi v24, v8, 4        # shift-left logical each element by 4 bits
    # --> v24  = | ..., l0 k0, j0 i0, h0 g0 |
    vor.vv  v24, v24, v16     # or each element
    # --> v24  = | ..., l0 kl, j0 ij, h0 gh |
    vsb.v v24, (a0)           # just store the lower 8 bits of each element
    # --> a0[0] = gh, a0[1] = ij, a0[2] = kl
    add a0, a0, a4            # increment dst by written bytes
    bnez a2, .Loop
    ret
