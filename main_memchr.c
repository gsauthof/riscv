#include <stdio.h>
#include <assert.h>

void *memchr(const void *src, int c, size_t n);
void *mempchr(const void *src, int c, size_t n);

int main()
{
    const char inp[] = "foo,bar;baz,xyz,aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:123\n";
    const char *end = inp + sizeof inp -1;

    const char *p = memchr(inp, ',', end - inp);
    puts(p);
    assert(p == inp + 3);

    p = memchr(p+1, ',', end - p - 1);
    puts(p);
    assert(p == inp + 11);

    p = memchr(inp, '|', end - inp);
    assert(!p);

    p = mempchr(inp, '|', end - inp);
    assert(p == end);

    p = memchr(inp, ':', end - inp);
    puts(p);
    assert(p == end - 5);

    return 0;
}
