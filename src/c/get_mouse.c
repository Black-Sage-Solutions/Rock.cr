#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

int main (void)

{
  int ttyfd = open ("/dev/tty", O_RDWR);
  if (ttyfd < 0)
    {
      printf ("Cannot open /devv/tty: errno = %d, %s\r\n",
        errno, strerror (errno));
      exit (EXIT_FAILURE);
    }

  write (ttyfd, "\x1B[6n\n", 5);

  unsigned char answer[16];
  size_t answerlen = 0;
  while (answerlen < sizeof (answer) - 1 &&
         read (ttyfd, answer + answerlen, 1) == 1)
    if (answer [answerlen ++] == 'R') break;
  answer [answerlen] = '\0';

  printf ("Answerback = \"");
  for (size_t i = 0; i < answerlen; ++ i)
    if (answer [i] < ' ' || '~' < answer [i])
      printf ("\\x%02X", (unsigned char) answer [i]);
    else
      printf ("%c", answer [i]);
  printf ("\"\r\n");

  return EXIT_SUCCESS;
}
