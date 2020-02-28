

ASFLAGS = -march=rv64gcv

AS = riscv64-unknown-elf-as
CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-ld

CFLAGSW_GCC = -Wall -Wextra -Wno-missing-field-initializers \
    -Wno-parentheses -Wno-missing-braces \
    -Wmissing-prototypes -Wfloat-equal \
    -Wwrite-strings -Wpointer-arith -Wcast-align \
    -Wnull-dereference \
    -Werror=multichar -Werror=sizeof-pointer-memaccess -Werror=return-type \
    -fstrict-aliasing

CFLAGS = $(CFLAGSW_GCC) $(CFLAGS0) $(CFLAGS1)


.PHONY: all
all: bcd2a bcd2asc a2bcd memchr memcmp memrchr


bcd2a: bcd2ascii.o start_bcd2a.o 
	$(LD) $(LDFLAGS) $^ -o $@

TEMP += bcd2a bcd2ascii.o start_bcd2a.o


bcd2asc: bcd2ascii.o main_bcd2a.o
	$(CC) $(LDFLAGS) $^ -o $@

TEMP += bcd2asc main_bcd2a.o

a2bcd: ascii2bcd.o main_a2bcd.o
	$(CC) $(LDFLAGS) $^ -o $@

TEMP += ascii2bcd.o main_a2bcd.o

memchr: main_memchr.o memchr.o mempchr.o
	$(CC) $(LDFLAGS) $^ -o $@

TEMP += main_memchr.o memchr.o mempchr.o

memrchr: main_memrchr.o memrchr.o
	$(CC) $(LDFLAGS) $^ -o $@

TEMP += main_memrchr.o memrchr.o

memcmp: main_memcmp.o memcmp.o
	$(CC) $(LDFLAGS) $^ -o $@

TEMP += main_memcmp.o memcmp.o

.PHONY: clean
clean:
	rm -f $(TEMP)
