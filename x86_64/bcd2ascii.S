
## 2020, Georg Sauthoff <mail@gms.tf>, LGPLv3+

    .intel_syntax noprefix

## Comments use 2 hash characters to protect against accidental
## clashes with C-pre-processor directives.

#ifndef BCD2ASCII_LOOP_BYTES

    ## loop in increments of up to 32 source bytes

    #define BCD2ASCII_LOOP_BYTES 32
#endif
#ifndef BCD2ASCII_SSE4_1
    #define BCD2ASCII_SSE4_1 1
#endif

## We only need to zero the upper lanes if other libraries execute
## non-VEX SIMD instructions. Apparently, as of 2020, e.g. Fedora 31, glibc
## and others don't execute non-VEX legacy SIMD instructions, anymore.

#if BCD2ASCII_ZEROUPPER
    #define vzeroupper vzeroupper
#else
    #define vzeroupper
#endif

    .text
    .balign 16
    #
    ## void *bcd2ascii(void* dst, const void* src, size_t n);
    #
    ## or:
    #
    ## struct Void_Pair { void *fst; void *snd; };
    ## typedef struct Void_Pair Void_Pair;
    ## Void_Pair bcd2ascii(void* dst, const void* src, size_t n);
    #
    ## rdi = dst, rsi = src, rdx = n
    ## return values in: rax, rdx
    #
    .global bcd2ascii
bcd2ascii:
    mov r11, rdx           ## backup n

    lea rax, [rdi + 2 * rdx]
    add rdx, rsi


    cmp r11, 1             ## shortcut for tiny input
    je  .Lbegin1


    ## ## prepare lookup table

#if ! BCD2ASCII_NO_STATIC

  ## Yeah, loading the table from memory is cheaper than constructing it
  ## by issuing a bunch of instructions.

  #if BCD2ASCII_WIDTH != 128
    vmovdqa ymm10, [.Lookup_table]
  #else
    vmovdqa xmm10, [.Lookup_table]
  #endif
#else
    mov   r8, 0x3736353433323130   ## '7', '6', ..., '0'
    mov   r9, 0x6665646362613938   ## 'f', 'e', ..., '8'
    vmovq xmm8, r8         ## move quad-word (64 bit) into low half of xmm
    #if BCD2ASCII_SSE4_1
        ## insert general-purpose register quad-word (64 bit) with offset 1
        vpinsrq xmm10, xmm8, r9, 1  ## into xmm10 and use other half of xmm8
    #else
        vmovq xmm9, r9         ## move quad-word (64 bit) into low half of xmm
        ## unpack (interleave) low quad-words (64 bit) into double-quad-words (128 bit)
        ## i.e. ymm10 = low(ymm9)low(ymm8)
        vpunpcklqdq xmm10, xmm8, xmm9  ## i.e. lower 128 bit contain the table
    #endif
  #if BCD2ASCII_WIDTH != 128
    ## we need to copy it to the upper 128 bit, since shuffle uses
    ## a separate table for each 128 bit half
    vinserti128 ymm10, ymm10, xmm10, 1
  #endif // BCD2ASCII_WIDTH != 128
#endif // BCD2ASCII_NO_STATIC

    ## ## prepare low-nibble mask

#if ! BCD2ASCII_NO_STATIC

  ## Yes, loading the mask from memory is cheaper than constructing with
  ## three instructions.

  #if BCD2ASCII_WIDTH != 128
    vmovdqa ymm4, [.Low_nibble_mask]
  #else
    vmovdqa xmm4, [.Low_nibble_mask]
  #endif
#else
    mov rcx, 0x0f0f0f0f
    ## with AVX512VL/VW, vpbroadcastb also supports broadcasting a byte
    ## from a general purpose register:
    ## vpbroadcastb ymm4, rcx # set each element to 0xf, i.e. mask low nibble
    ## alternatively:
    vmovd xmm4, rcx         ## move double-word (32 bit)
    #vpbroadcastb ymm4, xmm4 ## broadcast lowest xmm byte to all ymm bytes
    vpbroadcastd ymm4, xmm4 ## broadcast lowest xmm double-word to all elems
#endif // BCD2ASCII_NO_STATIC

#if BCD2ASCII_LOOP_BYTES >= 32

    add rsi, 32
    cmp rsi, rdx
    jnbe .Lskip32

#if BCD2ASCII_ALIGN_LOOP
    ## Align jump target to 16 bytes as recommended by Intel
    .balign 16
#endif
.Loop0:
    vmovdqu ymm0, [rsi-32]
    add   rsi, 32          ## increment src

    vpsrlw ymm1, ymm0, 4   ## shift-right-logical each 16 bit word element

    ## interleave/unpack each byte pair of the low 64 bit half
    ## into 16 bit words of a full 128 bit lane, for each 128 bit lane
    vpunpcklbw ymm2, ymm1, ymm0
    ## interleave/unpack byte pairs of the high 64 bit half into 16 bit words,
    ## for each 128 bit lane
    vpunpckhbw ymm3, ymm1, ymm0

    vpand ymm2, ymm2, ymm4 ## bit-and, i.e. mask with 0x0f0f...0f
    vpand ymm3, ymm3, ymm4 ## bit-and, i.e. mask with 0x0f0f...0f

    ## ymm5 = concat(xmm3, xmm2)
    vinserti128 ymm5, ymm2, xmm3, 1
    ## ymm6 = concat(hilane(ymm3), hilane(ymm2))
    ## i.e. permute 2 128 bit integer values
    vperm2i128 ymm6, ymm2, ymm3, 0x31

    ## lookup each byte in table ymm10 using indices in ymm5,
    ## for each 128 bit lane
    vpshufb ymm5, ymm10, ymm5
    vpshufb ymm6, ymm10, ymm6

    vmovdqu [rdi], ymm5
    vmovdqu [rdi+32], ymm6
    add rdi, 64            ## increment dst

    cmp rsi, rdx           ## compare src with end
    jbe .Loop0             ## branch if below-or-equal
.Lskip32:
    sub rsi, 32
#endif // BCD2ASCII_LOOP_BYTES >= 32

#if BCD2ASCII_LOOP_BYTES >= 16

    add rsi, 16
    cmp rsi, rdx
    jnbe .Lskip16

#if BCD2ASCII_ALIGN_LOOP
    ## Align jump target to 16 bytes as recommended by Intel
    .balign 16
#endif
.Loop1:

    /* There are basically 2 ways to deal with 16 source bytes:
       - low/high unpack them in just one 128 bit lane
       - do a 16 bit wideining load into a full 2 lane register (i.e. 256 bit)
       */


#if BCD2ASCII_UNPACK16
    /* this branch is slower */

    vmovdqu xmm0, [rsi-16]
    add   rsi, 16          ## increment src

    vpsrlw xmm1, xmm0, 4   ## shift-right-logical each 16 bit word element

    ## interleave/unpack each byte pair in the low part into 16 bit words
    vpunpcklbw xmm2, xmm1, xmm0

    vpunpckhbw xmm3, xmm1, xmm0

    vpand xmm2, xmm2, xmm4 ## bit-and, i.e. mask with 0x0f0f...0f
    vpand xmm3, xmm3, xmm4 ## bit-and, i.e. mask with 0x0f0f...0f

    ## lookup each byte in table xmm10 using indices in xmm3
    vpshufb xmm2, xmm10, xmm2
    vpshufb xmm3, xmm10, xmm3

    vmovdqu [rdi], xmm2    ## move double-quad-word (128 bit) to dst
    vmovdqu [rdi+16], xmm3    ## move double-quad-word (128 bit) to dst
    add rdi, 32            ## increment dst

#else // BCD2ASCII_UNPACK16
    /* this branch is faster */

    ## vpmovzxbw  ymm0, XMMWORD PTR [rsi] # XMMWORD PTR annotation is optional
    vpmovzxbw  ymm0, [rsi-16] ## move and zero-extend 16 bytes into 16 16-bit words
    add rsi, 16            ## increment src

    vpsllw ymm2, ymm0, 8   ## shift-left-logical each 16-bit word by 8 bits
    vpsrlw ymm3, ymm0, 4   ## shift-right-logical each 16-bit word by 8 bits
    vpand  ymm5, ymm2, ymm4   ## bit-and, i.e. mask with 0x0f0f...0f

    vpor   ymm6, ymm5, ymm3   ## bit-or

    ## shuffle each each 128 bit half of ymm6 according to each lookup table
    ## in ymm10
    vpshufb ymm7, ymm10, ymm6

    ## move 2 double-quad-words (i.e. the complete register) to unaligned dst
    vmovdqu [rdi], ymm7
    add rdi, 32            ## increment dst

#endif // else: BCD2ASCII_UNPACK16

    cmp rsi, rdx           ## compare src with mid
    jbe .Loop1             ## branch if bfelow-or-equal
.Lskip16:
    sub rsi, 16
#endif // BCD2ASCII_LOOP_BYTES >= 16

    add rsi, 8
    cmp rsi, rdx
    jnbe .Lskip8

#if BCD2ASCII_ALIGN_LOOP
    ## Align jump target to 16 bytes as recommended by Intel
    .balign 16
#endif
.Loop2:
    vmovq xmm0, [rsi-8]      ## load quad-word (64 bit) into lower xmm half
    add   rsi, 8           ## increment src

    vpsrlw xmm1, xmm0, 4   ## shift-right-logical each 16 bit word element

    ## interleave/unpack each byte pair in the low part into 16 bit words
    vpunpcklbw xmm2, xmm1, xmm0

    vpand xmm3, xmm2, xmm4 ## bit-and, i.e. mask with 0x0f0f...0f

    ## lookup each byte in table xmm10 using indices in xmm3
    vpshufb xmm5, xmm10, xmm3

    vmovdqu [rdi], xmm5    ## move double-quad-word (128 bit) to dst
    add rdi, 16            ## increment dst

    cmp rsi, rdx           ## compare src with end
    jbe .Loop2             ## branch if below-equal
.Lskip8:
    sub rsi, 8

    mov r11, rdx
    sub r11, rsi

    ## indirectly jump to process the last remaining input bytes
    jmp [r11 * 8 + .Ljump_table0]

    ## Doesn't make a difference:
    ## .balign 16
.Lbegin0:
    ## avoid speed-penalty in case other functions that are executed next
    ## contain non-VEX SIMD instructions
    vzeroupper
    ret
.Lbegin1:
    ## mov r8b, [rsi] # would yield false dependency on register half
    movzx r8, BYTE PTR [rsi]   ## move and zero-extend one byte
    ## Yes, a lookup-table is faster than other alternatives
    movzx r9, WORD PTR [r8 * 2 + .Lookup_bcd_byte]
    mov WORD PTR [rdi], r9w

    vzeroupper
    ret

    ## slower alternative
#if 0
    movzx r8, BYTE PTR [rsi]   ## move and zero-extend one byte

    jmp .Ldone
#endif
.Lbegin2:
    movzx r8, BYTE PTR  [rsi]  ## move and zero-extend one byte
    movzx r10, BYTE PTR [rsi+1]
    movzx r9,  WORD PTR [ r8 * 2 + .Lookup_bcd_byte]
    movzx r11, WORD PTR [r10 * 2 + .Lookup_bcd_byte]
    mov WORD PTR [rdi], r9w
    mov WORD PTR [rdi+2], r11w

    vzeroupper
    ret

    ## slower alternative
#if 0
    movzx r8, WORD PTR [rsi]   ## move and zero-extend 2 bytes
    ## shouldn't make a difference:
    ## movzx r8d, WORD PTR [rsi]

    jmp .Ldone
#endif
.Lbegin3:
    movzx r8, WORD PTR [rsi]
    movzx r9, BYTE PTR [rsi+2]
    shl r9, 16             ## shift-left-logical
    or r8, r9              ## bit-or

    jmp .Ldone
.Lbegin4:
    ## moving a double-word always zero-extends
    mov   r8d, DWORD PTR [rsi]  ## i.e. 32 bit

    jmp .Ldone
.Lbegin5:
    mov   r8d, DWORD PTR [rsi+1]
    shl r8, 8
    mov   r8b, BYTE PTR [rsi]   ## save the or instruction ...

    jmp .Ldone
.Lbegin6:
    mov   r8d, DWORD PTR [rsi+2]
    shl r8, 16
    mov   r8w, WORD PTR [rsi]

    jmp .Ldone
.Lbegin7:
    mov   r8d, DWORD PTR [rsi+3]
    shl r8, 16
    mov   r8w, WORD PTR [rsi+1]
    shl r8, 8
    mov   r8b, BYTE PTR [rsi]

.Ldone:

    vmovq xmm0, r8         ## move quad-word (64 bit) into lower xmm half

    vpsrlw xmm1, xmm0, 4   ## shift-right-logical each 16 bit word element

    ## interleave/unpack each byte pair in the low part into 16 bit words
    vpunpcklbw xmm2, xmm1, xmm0

    vpand xmm3, xmm2, xmm4 ## bit-and, i.e. mask with 0x0f0f...0f

    ## lookup each byte in table xmm10 using indices in xmm3
    vpshufb xmm5, xmm10, xmm3


    jmp [r11 * 8 + .Ljump_table1]

.Lend1:
    vmovd r8, xmm5         ## move low double-word (32 bit), we can't move less
    mov   [rdi], r8w       ## only move the lower word (16 bit)
    vzeroupper
    ret
.Lend2:
    vmovd [rdi], xmm5
    vzeroupper
    ret
.Lend3:
    vmovq r8, xmm5         ## move low quad-word (64 bit)
    mov   [rdi], r8d
    shr r8, 32
    mov   [rdi+4], r8w
    vzeroupper
    ret
.Lend4:
    vmovq [rdi], xmm5
    vzeroupper
    ret
.Lend5:
    vmovq [rdi], xmm5
    ## move high 64 bit to low 64 bit
    ## (i.e. move packed single-precision floats high to low)
    vmovhlps xmm6, xmm5, xmm5
    vmovd r9, xmm6
    mov   [rdi+8], r9w
    vzeroupper
    ret
.Lend6:
    vmovq [rdi], xmm5
    vmovhlps xmm6, xmm5, xmm5
    vmovd [rdi+8], xmm6
    vzeroupper
    ret
.Lend7:
    vmovq [rdi], xmm5
    vmovhlps xmm6, xmm5, xmm5
    vmovq r9, xmm6
    mov   [rdi+8], r9d
    shr r9, 32
    mov   [rdi+12], r9w
    vzeroupper
    ret


    .section .rodata
    .balign 32
.Lookup_table:
    .quad 0x3736353433323130   ## '7', '6', ..., '0'
    .quad 0x6665646362613938   ## 'f', 'e', ..., '8'
    .quad 0x3736353433323130   ## '7', '6', ..., '0'
    .quad 0x6665646362613938   ## 'f', 'e', ..., '8'
.Low_nibble_mask:
    .quad 0x0f0f0f0f0f0f0f0f
    .quad 0x0f0f0f0f0f0f0f0f
    .quad 0x0f0f0f0f0f0f0f0f
    .quad 0x0f0f0f0f0f0f0f0f
.Ljump_table0:
    .quad .Lbegin0
    .quad .Lbegin1
    .quad .Lbegin2
    .quad .Lbegin3
    .quad .Lbegin4
    .quad .Lbegin5
    .quad .Lbegin6
    .quad .Lbegin7
.Ljump_table1:
    .quad 0 ## should not happend as we already returned via .Lbegin0
    .quad .Lend1
    .quad .Lend2
    .quad .Lend3
    .quad .Lend4
    .quad .Lend5
    .quad .Lend6
    .quad .Lend7
.Lookup_bcd_byte:
    .word /* 0x00 => */ 0x3030
    .word /* 0x01 => */ 0x3130
    .word /* 0x02 => */ 0x3230
    .word /* 0x03 => */ 0x3330
    .word /* 0x04 => */ 0x3430
    .word /* 0x05 => */ 0x3530
    .word /* 0x06 => */ 0x3630
    .word /* 0x07 => */ 0x3730
    .word /* 0x08 => */ 0x3830
    .word /* 0x09 => */ 0x3930
    .word /* 0x0a => */ 0x6130
    .word /* 0x0b => */ 0x6230
    .word /* 0x0c => */ 0x6330
    .word /* 0x0d => */ 0x6430
    .word /* 0x0e => */ 0x6530
    .word /* 0x0f => */ 0x6630
    .word /* 0x10 => */ 0x3031
    .word /* 0x11 => */ 0x3131
    .word /* 0x12 => */ 0x3231
    .word /* 0x13 => */ 0x3331
    .word /* 0x14 => */ 0x3431
    .word /* 0x15 => */ 0x3531
    .word /* 0x16 => */ 0x3631
    .word /* 0x17 => */ 0x3731
    .word /* 0x18 => */ 0x3831
    .word /* 0x19 => */ 0x3931
    .word /* 0x1a => */ 0x6131
    .word /* 0x1b => */ 0x6231
    .word /* 0x1c => */ 0x6331
    .word /* 0x1d => */ 0x6431
    .word /* 0x1e => */ 0x6531
    .word /* 0x1f => */ 0x6631
    .word /* 0x20 => */ 0x3032
    .word /* 0x21 => */ 0x3132
    .word /* 0x22 => */ 0x3232
    .word /* 0x23 => */ 0x3332
    .word /* 0x24 => */ 0x3432
    .word /* 0x25 => */ 0x3532
    .word /* 0x26 => */ 0x3632
    .word /* 0x27 => */ 0x3732
    .word /* 0x28 => */ 0x3832
    .word /* 0x29 => */ 0x3932
    .word /* 0x2a => */ 0x6132
    .word /* 0x2b => */ 0x6232
    .word /* 0x2c => */ 0x6332
    .word /* 0x2d => */ 0x6432
    .word /* 0x2e => */ 0x6532
    .word /* 0x2f => */ 0x6632
    .word /* 0x30 => */ 0x3033
    .word /* 0x31 => */ 0x3133
    .word /* 0x32 => */ 0x3233
    .word /* 0x33 => */ 0x3333
    .word /* 0x34 => */ 0x3433
    .word /* 0x35 => */ 0x3533
    .word /* 0x36 => */ 0x3633
    .word /* 0x37 => */ 0x3733
    .word /* 0x38 => */ 0x3833
    .word /* 0x39 => */ 0x3933
    .word /* 0x3a => */ 0x6133
    .word /* 0x3b => */ 0x6233
    .word /* 0x3c => */ 0x6333
    .word /* 0x3d => */ 0x6433
    .word /* 0x3e => */ 0x6533
    .word /* 0x3f => */ 0x6633
    .word /* 0x40 => */ 0x3034
    .word /* 0x41 => */ 0x3134
    .word /* 0x42 => */ 0x3234
    .word /* 0x43 => */ 0x3334
    .word /* 0x44 => */ 0x3434
    .word /* 0x45 => */ 0x3534
    .word /* 0x46 => */ 0x3634
    .word /* 0x47 => */ 0x3734
    .word /* 0x48 => */ 0x3834
    .word /* 0x49 => */ 0x3934
    .word /* 0x4a => */ 0x6134
    .word /* 0x4b => */ 0x6234
    .word /* 0x4c => */ 0x6334
    .word /* 0x4d => */ 0x6434
    .word /* 0x4e => */ 0x6534
    .word /* 0x4f => */ 0x6634
    .word /* 0x50 => */ 0x3035
    .word /* 0x51 => */ 0x3135
    .word /* 0x52 => */ 0x3235
    .word /* 0x53 => */ 0x3335
    .word /* 0x54 => */ 0x3435
    .word /* 0x55 => */ 0x3535
    .word /* 0x56 => */ 0x3635
    .word /* 0x57 => */ 0x3735
    .word /* 0x58 => */ 0x3835
    .word /* 0x59 => */ 0x3935
    .word /* 0x5a => */ 0x6135
    .word /* 0x5b => */ 0x6235
    .word /* 0x5c => */ 0x6335
    .word /* 0x5d => */ 0x6435
    .word /* 0x5e => */ 0x6535
    .word /* 0x5f => */ 0x6635
    .word /* 0x60 => */ 0x3036
    .word /* 0x61 => */ 0x3136
    .word /* 0x62 => */ 0x3236
    .word /* 0x63 => */ 0x3336
    .word /* 0x64 => */ 0x3436
    .word /* 0x65 => */ 0x3536
    .word /* 0x66 => */ 0x3636
    .word /* 0x67 => */ 0x3736
    .word /* 0x68 => */ 0x3836
    .word /* 0x69 => */ 0x3936
    .word /* 0x6a => */ 0x6136
    .word /* 0x6b => */ 0x6236
    .word /* 0x6c => */ 0x6336
    .word /* 0x6d => */ 0x6436
    .word /* 0x6e => */ 0x6536
    .word /* 0x6f => */ 0x6636
    .word /* 0x70 => */ 0x3037
    .word /* 0x71 => */ 0x3137
    .word /* 0x72 => */ 0x3237
    .word /* 0x73 => */ 0x3337
    .word /* 0x74 => */ 0x3437
    .word /* 0x75 => */ 0x3537
    .word /* 0x76 => */ 0x3637
    .word /* 0x77 => */ 0x3737
    .word /* 0x78 => */ 0x3837
    .word /* 0x79 => */ 0x3937
    .word /* 0x7a => */ 0x6137
    .word /* 0x7b => */ 0x6237
    .word /* 0x7c => */ 0x6337
    .word /* 0x7d => */ 0x6437
    .word /* 0x7e => */ 0x6537
    .word /* 0x7f => */ 0x6637
    .word /* 0x80 => */ 0x3038
    .word /* 0x81 => */ 0x3138
    .word /* 0x82 => */ 0x3238
    .word /* 0x83 => */ 0x3338
    .word /* 0x84 => */ 0x3438
    .word /* 0x85 => */ 0x3538
    .word /* 0x86 => */ 0x3638
    .word /* 0x87 => */ 0x3738
    .word /* 0x88 => */ 0x3838
    .word /* 0x89 => */ 0x3938
    .word /* 0x8a => */ 0x6138
    .word /* 0x8b => */ 0x6238
    .word /* 0x8c => */ 0x6338
    .word /* 0x8d => */ 0x6438
    .word /* 0x8e => */ 0x6538
    .word /* 0x8f => */ 0x6638
    .word /* 0x90 => */ 0x3039
    .word /* 0x91 => */ 0x3139
    .word /* 0x92 => */ 0x3239
    .word /* 0x93 => */ 0x3339
    .word /* 0x94 => */ 0x3439
    .word /* 0x95 => */ 0x3539
    .word /* 0x96 => */ 0x3639
    .word /* 0x97 => */ 0x3739
    .word /* 0x98 => */ 0x3839
    .word /* 0x99 => */ 0x3939
    .word /* 0x9a => */ 0x6139
    .word /* 0x9b => */ 0x6239
    .word /* 0x9c => */ 0x6339
    .word /* 0x9d => */ 0x6439
    .word /* 0x9e => */ 0x6539
    .word /* 0x9f => */ 0x6639
    .word /* 0xa0 => */ 0x3061
    .word /* 0xa1 => */ 0x3161
    .word /* 0xa2 => */ 0x3261
    .word /* 0xa3 => */ 0x3361
    .word /* 0xa4 => */ 0x3461
    .word /* 0xa5 => */ 0x3561
    .word /* 0xa6 => */ 0x3661
    .word /* 0xa7 => */ 0x3761
    .word /* 0xa8 => */ 0x3861
    .word /* 0xa9 => */ 0x3961
    .word /* 0xaa => */ 0x6161
    .word /* 0xab => */ 0x6261
    .word /* 0xac => */ 0x6361
    .word /* 0xad => */ 0x6461
    .word /* 0xae => */ 0x6561
    .word /* 0xaf => */ 0x6661
    .word /* 0xb0 => */ 0x3062
    .word /* 0xb1 => */ 0x3162
    .word /* 0xb2 => */ 0x3262
    .word /* 0xb3 => */ 0x3362
    .word /* 0xb4 => */ 0x3462
    .word /* 0xb5 => */ 0x3562
    .word /* 0xb6 => */ 0x3662
    .word /* 0xb7 => */ 0x3762
    .word /* 0xb8 => */ 0x3862
    .word /* 0xb9 => */ 0x3962
    .word /* 0xba => */ 0x6162
    .word /* 0xbb => */ 0x6262
    .word /* 0xbc => */ 0x6362
    .word /* 0xbd => */ 0x6462
    .word /* 0xbe => */ 0x6562
    .word /* 0xbf => */ 0x6662
    .word /* 0xc0 => */ 0x3063
    .word /* 0xc1 => */ 0x3163
    .word /* 0xc2 => */ 0x3263
    .word /* 0xc3 => */ 0x3363
    .word /* 0xc4 => */ 0x3463
    .word /* 0xc5 => */ 0x3563
    .word /* 0xc6 => */ 0x3663
    .word /* 0xc7 => */ 0x3763
    .word /* 0xc8 => */ 0x3863
    .word /* 0xc9 => */ 0x3963
    .word /* 0xca => */ 0x6163
    .word /* 0xcb => */ 0x6263
    .word /* 0xcc => */ 0x6363
    .word /* 0xcd => */ 0x6463
    .word /* 0xce => */ 0x6563
    .word /* 0xcf => */ 0x6663
    .word /* 0xd0 => */ 0x3064
    .word /* 0xd1 => */ 0x3164
    .word /* 0xd2 => */ 0x3264
    .word /* 0xd3 => */ 0x3364
    .word /* 0xd4 => */ 0x3464
    .word /* 0xd5 => */ 0x3564
    .word /* 0xd6 => */ 0x3664
    .word /* 0xd7 => */ 0x3764
    .word /* 0xd8 => */ 0x3864
    .word /* 0xd9 => */ 0x3964
    .word /* 0xda => */ 0x6164
    .word /* 0xdb => */ 0x6264
    .word /* 0xdc => */ 0x6364
    .word /* 0xdd => */ 0x6464
    .word /* 0xde => */ 0x6564
    .word /* 0xdf => */ 0x6664
    .word /* 0xe0 => */ 0x3065
    .word /* 0xe1 => */ 0x3165
    .word /* 0xe2 => */ 0x3265
    .word /* 0xe3 => */ 0x3365
    .word /* 0xe4 => */ 0x3465
    .word /* 0xe5 => */ 0x3565
    .word /* 0xe6 => */ 0x3665
    .word /* 0xe7 => */ 0x3765
    .word /* 0xe8 => */ 0x3865
    .word /* 0xe9 => */ 0x3965
    .word /* 0xea => */ 0x6165
    .word /* 0xeb => */ 0x6265
    .word /* 0xec => */ 0x6365
    .word /* 0xed => */ 0x6465
    .word /* 0xee => */ 0x6565
    .word /* 0xef => */ 0x6665
    .word /* 0xf0 => */ 0x3066
    .word /* 0xf1 => */ 0x3166
    .word /* 0xf2 => */ 0x3266
    .word /* 0xf3 => */ 0x3366
    .word /* 0xf4 => */ 0x3466
    .word /* 0xf5 => */ 0x3566
    .word /* 0xf6 => */ 0x3666
    .word /* 0xf7 => */ 0x3766
    .word /* 0xf8 => */ 0x3866
    .word /* 0xf9 => */ 0x3966
    .word /* 0xfa => */ 0x6166
    .word /* 0xfb => */ 0x6266
    .word /* 0xfc => */ 0x6366
    .word /* 0xfd => */ 0x6466
    .word /* 0xfe => */ 0x6566
    .word /* 0xff => */ 0x6666
