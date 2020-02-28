#include <assert.h>
#include <stdio.h>

void *memrchr(const void *src, int c, size_t n);




int main()
{
    char v[4096] = {0};

    v[0] = 'X';

    char *p;

    p = memrchr(v, ' ', sizeof v);
    assert(!p);

    p = memrchr(v, 'X', sizeof v);
    assert(p == v);

    v[255] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+255);

    v[255] = ' ';
    v[256] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+256);

    v[255] = 'X';
    v[256] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+256);

    v[500] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+500);

    v[511] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+511);

    v[512] = 'X';
    p = memrchr(v, 'X', sizeof v);
    assert(p == v+512);

    p = memrchr(v, 'X', 512);
    assert(p == v+511);

    return 0;
}
