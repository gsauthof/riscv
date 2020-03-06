#include <stddef.h>

void *ascii2bcd(void* dst, const void* src, size_t n);

static const unsigned char inp[] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
    'f', 'e', 'd', 'c', 'b', 'a', '9', '8', '7', '6', '5', '4', '3', '2', '1', '0',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
    'f', 'e', 'd', 'c', 'b', 'a', '9', '8', '7', '6', '5', '4', '3', '2', '1', '0'
};

#include <stdio.h>

int main()
{
    unsigned char out[sizeof inp / 2 + 1] = {0};
    // expected output:
    // out = { 0x01, 0x23, ... }

    ascii2bcd(out, inp, sizeof inp);

    for (size_t i = 0; i < sizeof inp / 2; ++i)
        printf("%02hhx ", out[i]);
    puts("");

    return 0;
}
