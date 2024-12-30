#include <stdio.h>
#include <sys/ioctl.h>

/**
 * This is for running on platforms that use the _IOR() macro to determine the
 * value for the TIOCGWINSZ const.
 *
 * To compile:
 * 		$ cc -o get_tiocgwinsz get_tiocgwinsz.c
 */
int main() {
    printf("TIOCGWINSZ: %#lx\n", TIOCGWINSZ);
    return 0;
}
