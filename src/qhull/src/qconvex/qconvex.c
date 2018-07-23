/*<html><pre>  -<a                             href="../libqhull/qh-qhull.htm"
  >-------------------------------</a><a name="TOP">-</a>

   qconvex.c
      compute convex hulls using qhull

   see unix.c for full interface

   Copyright (c) 1993-2015, The Geometry Center
*/

#include "libqhull/libqhull.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#if __cplusplus
extern "C" {
  int isatty(int);
}

#elif _MSC_VER
#include <io.h>
#define isatty _isatty
/* int _isatty(int); */

#else
int isatty(int);  /* returns 1 if stdin is a tty
                   if "Undefined symbol" this can be deleted along with call in main() */
#endif


char hidden_options_qx[]=" d v H Qbb Qf Qg Qm Qr Qu Qv Qx Qz TR E V Fp Gt Q0 Q1 Q2 Q3 Q4 Q5 Q6 Q7 Q8 Q9 ";

int run_qconvex(FILE *fin,FILE *fout) {
  int curlong, totlong; /* used !qh_NOmem */
  int exitcode, numpoints, dim;
  coordT *points;
  boolT ismalloc;

  int argc=2;
  char *argv[2];
  argv[0]=malloc(sizeof(char)*200);
  argv[0]="src/qhull/qconvex\0";
  argv[1]=malloc(sizeof(char)*2);
  argv[1]="FS\0";
  
#if __MWERKS__ && __POWERPC__
  char inBuf[BUFSIZ], outBuf[BUFSIZ], errBuf[BUFSIZ];
  SIOUXSettings.showstatusline= false;
  SIOUXSettings.tabspaces= 1;
  SIOUXSettings.rows= 40;
  if (setvbuf(stdin, inBuf, _IOFBF, sizeof(inBuf)) < 0   /* w/o, SIOUX I/O is slow*/
  || setvbuf(stdout, outBuf, _IOFBF, sizeof(outBuf)) < 0
  || (stdout != stderr && setvbuf(stderr, errBuf, _IOFBF, sizeof(errBuf)) < 0))
    fprintf(stderr, "qhull internal warning (main): could not change stdio to fully buffered.\n");
  argc= ccommand(&argv);
#endif

  if ((argc == 1) && isatty( 0 /*stdin*/)) {
    exit(qh_ERRnone);
  }
  if (argc > 1 && *argv[1] == '-' && !*(argv[1]+1)) {
    exit(qh_ERRnone);
  }
  if (argc >1 && *argv[1] == '.' && !*(argv[1]+1)) {
    exit(qh_ERRnone);
  }
  qh_init_A(fin, fout, stderr, argc, argv);  /* sets qh qhull_command */
  exitcode= setjmp(qh errexit); /* simple statement for CRAY J916 */
  if (!exitcode) {
    qh_checkflags(qh qhull_command, hidden_options_qx);
    qh_initflags(qh qhull_command);
    points= qh_readpoints(&numpoints, &dim, &ismalloc);
    if (dim >= 5) {
      qh_option("Qxact_merge", NULL, NULL);
      qh MERGEexact= True; /* 'Qx' always */
    }
    qh_init_B(points, numpoints, dim, ismalloc);
    qh_qhull();
    qh_check_output();
    qh_produce_output();
    if (qh VERIFYoutput && !qh FORCEoutput && !qh STOPpoint && !qh STOPcone)
      qh_check_points();
    exitcode= qh_ERRnone;
  }
  qh NOerrexit= True;  /* no more setjmp */
#ifdef qh_NOmem
  qh_freeqhull( True);
#else
  qh_freeqhull( False);
  qh_memfreeshort(&curlong, &totlong);
  if (curlong || totlong)
    fprintf(stderr, "qhull internal warning (main): did not free %d bytes of long memory(%d pieces)\n",
       totlong, curlong);
#endif
  return exitcode;
} /* main */
