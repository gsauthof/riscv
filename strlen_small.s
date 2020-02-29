
# 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .text
    # .balign 4

# size_t strlen(const void *src);
#
# optimize for code size here

#
# a0 = src
#
    .global strlen
strlen:
    mv a4, a0          # preserve src
    # we can do this only because we control the implementation of rawmemchr
    # and we know that it doesn't clobber a4 and a5
    # (otherwise we would have to store them on the stack)
    mv a5, ra          # preserve return address
    li a1, 0           # search for null-terminator
    jal rawmemchr      # jump and store pc+4 in ra
    sub a0, a0, a4     # subtract the start address
    mv ra, a5          # restore return address
    ret

