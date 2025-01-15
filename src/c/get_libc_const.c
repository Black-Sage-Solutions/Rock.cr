#include <stdio.h>
#include <sys/ioctl.h>
#include <termios.h>

/**
 * This is for running on platforms to find set constants that may not be in
 * the Crystal standard library.
 *
 * To compile:
 * 		$ cc -o get_libc_const get_libc_const.c
 *
 * For MacOS/Darwin, the _IOR() macro is used to determine the value for the
 * TIOCGWINSZ const.
 *
 */
int main() {
	printf("TIOCGWINSZ: %#lx\n", TIOCGWINSZ);
	printf("VMIN: %d\n", VMIN);
	printf("VTIME: %d\n", VTIME);
	return 0;
}
