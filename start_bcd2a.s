    .text                     # Start text section
    .balign 4                 # align 4 byte instructions by 4 bytes
    .global _start            # global 
_start:
                              # check if vector extension is enabled
                              # user-mode doesn't have privileges to
                              # read mstatus/sstatus/misa CSRs
                              # thus, unclear how to check for V support
    li    t1, 0x1800000       # disable this check for now
    #csrr  t1, mstatus        # control and status register, i.e. read the
                              # mstatus register
    li    t2, 0b11            # load immediate mask
    slli  t2, t2, 23          # shift left logical immediate by 23 bits
                              # because "V" draft 0.8 defines the vector
                              # context status field VS as mstatus[24:23]
                              # (0b00 -> off, 0b01 -> initial, 0b10 -> clean,
                              #  0b11 -> dirty)
    and   t3, t1, t2
    beqz  t3, v_disabled_error

                              # Prepare calling bcd2ascii()
    addi  sp, sp, -68         # grow stack by 64+4 bytes, some additional
                              # space but keep it 4 byte aligned
    mv    a0, sp              # store output on stack
    lui   a1, %hi(inp)        # load start address of
    addi  a1, a1, %lo(inp)    # the input string
    li    a2, 32              # load immediate: sizeof inp
    call  bcd2ascii           # we don't need to save/restore our
                              # return address because we don't return ...
    li    t0, 0xa             # load immediate: newline
    sb    t0, 64(sp)          # store byte
                              # i.e. terminate output string with '\n'
    li    a0, 1               # stdout
    mv    a1, sp              # read output located on the stack
    li    a2, 65              # i.e. 64+1 characters
    li    a7, 64              # write syscall number
    ecall                     # call write(2)

    li    a0, 0               # set exit status to zero
exit:
    li    a7, 93              # exit syscall number
    ecall                     # call exit(2)
1:
    j     1b                  # loop forever in case exit failed ...

v_disabled_error:
    li    a0, 2               # stderr
    lui   a1, %hi(err_msg)    # load error message start address
    addi  a1, a1, %lo(err_msg)
    lui   a2, %hi(err_msg_size)     # load error message size
    addi  a2, a2, %lo(err_msg_size)
    li    a7, 64              # write syscall number
    ecall                     # call write(2)
    li    a0, 1               # load immediate exit argument
    j     exit
    

    .section .rodata          # Start read-only data section
    .balign 4                 # align to 4 bytes
inp:
    .byte 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef
    .byte 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
    .byte 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef
    .byte 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
err_msg:
    .string "ERROR: RISC-V 'V' vector extension is disabled!\n"
    .set err_msg_size, . - err_msg
