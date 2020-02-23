#include <stdio.h>
#include <assert.h>


int memcmp(const void *u, const void *v, size_t n);

int main()
{
    unsigned char u[10] = "hello";
    unsigned char v[10] = "hello";

    int r;
    r = memcmp(u, v, 5);
    assert(!r);

    for (unsigned i = 0; i < 256; ++i)
        for (unsigned j = 0; j < 256; ++j) {
            u[2] = i;
            v[2] = j;
            int r = memcmp(u, v, 5);
            if (i == j) {
                if (r != 0) {
                    fprintf(stderr, "%u %u\n", i, j);
                }
                assert(r == 0);
            } else if (i < j) {
                if (r >= 0) {
                    fprintf(stderr, "%u %u\n", i, j);
                }
                assert(r < 0);
            } else if (i > j) {
                if (r <= 0) {
                    fprintf(stderr, "%u %u\n", i, j);
                }
                assert(r > 0);
            }
        }

    const char t[] =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    "Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris. Integer in mauris eu nibh euismod gravida. Duis ac tellus et risus vulputate vehicula. Donec lobortis risus a elit. Etiam tempor. Ut ullamcorper, ligula eu tempor congue, eros est euismod turpis, id tincidunt sapien risus a quam. Maecenas fermentum consequat mi. Donec fermentum. Pellentesque malesuada nulla a mi. Duis sapien sem, aliquet nec, commodo eget, consequat quis, neque. Aliquam faucibus, elit ut dictum aliquet, felis nisl adipiscing sapien, sed malesuada diam lacus eget erat. Cras mollis scelerisque nunc. Nullam arcu. Aliquam consequat. Curabitur augue lorem, dapibus quis, laoreet et, pretium ac, nisi. Aenean magna nisl, mollis quis, molestie eu, feugiat in, orci. In hac habitasse platea dictumst."
    ;
    const char *s = t;
    r = memcmp(t, s, sizeof t - 1);
    assert(!r);

    return 0;
}
