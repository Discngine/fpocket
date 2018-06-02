/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_DPARAMS
#define DH_DPARAMS

/* ----------------------------- INCLUDES ------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>

#include "utils.h"
#include "memhandler.h"
#include "fparams.h"

/* --------------------------- PUBLIC MACROS ---------------------------------*/


/* Options of the test program */
#define M_DPAR_INTERFACE_METHOD1 'e'
#define M_DPAR_INTERFACE_METHOD2 'E'
#define M_DPAR_DISTANCE_CRITERIA 'd'
#define M_DPAR_INPUT_FILE 'f'
#define M_DPAR_OUTPUT_FILE 'o'

/* Two way of defining the interface: */
/* 1 - Get atoms ocontacted by vertices within M_VERT_LIG_NEIG_DIST of the ligand. */
/* 2 - Just get atoms within M_LIG_NEIG_DIST of the ligand, based on each ligand atom. */
#define M_INTERFACE_METHOD1 1	
#define M_VERT_LIG_NEIG_DIST 4.0

#define M_INTERFACE_METHOD2 2
#define M_LIG_NEIG_DIST 4.0

#define M_OUTPUT_FILE1_DEFAULT "dpout_explicitp.txt"
#define M_OUTPUT_FILE2_DEFAULT "dpout_fpocketp.txt"
#define M_OUTPUT_FILE3_DEFAULT "dpout_fpocketnp.txt"

#define M_MAX_FILE_NAME_LENGTH 300
#define M_NB_MC_ITER 2500
#define M_MIN_ASPH_RAY 2.8
#define M_MAX_ASPH_RAY 10.0

#define M_DP_USAGE "\
\n***** USAGE (dpocket) *****\n\
\n\
The program needs as input a file containing at each                \n\
line a pdb file name and a ligand code (3 letters).                 \n\
The format of each line must be:                                    \n\n\
{PATH/}2fej.pdb  LIG                                                \n\n\
The ligand code is the resname of the ligand atoms in               \n\
the pdb file and has to separated by a tab from the                 \n\
pdb structure in the input file.                                    \n\n\
See the manual for more information.                                \n\n\
Example of command using default parameters:                        \n\
\t./bin/dpocket -f file_path                                        \n\n\
Options:                                                            \n\
\t-o string  : Prefix of the output file.               (./dpout_*) \n\
\t-e         : Use the first protein-ligand explicit                \n\
\t             interface definition (default).                      \n\
\t-E         : Use the second protein-ligand explicit               \n\
\t             interface definition.                                \n\
\t-d float   : Distance criteria for the choosen                    \n\
\t             interface definition.                          (4.0) \n\n\
Options specific to fpocket are usable too.                         \n\
See the manual/tutorial for mor information.                        \n\
***************************\n"

/* --------------------------- PUBLIC STRUCTURES -----------------------------*/


typedef struct s_dparams
{
	char **fcomplex,    /**< path of the holo form of the structure */
		 **ligs ;   /**< HET residue name of the ligand */

	char *f_exp,    /**< name of the explicit pocket definition output file*/
		 *f_fpckp, /**< name of the pocket definition output file*/
		 *f_fpcknp ; /**< name of the non pocket definition output file*/

	float interface_dist_crit;  /**< distance for explicit binding pocket definition*/

	int nfiles,         /**< number of files to analyse*/
	    interface_method ;  /**< how to identify the explicit binding pocket*/

	s_fparams *fpar ;   /**< fparams container*/

} s_dparams ;

/* ----------------------------- PROTOTYPES --------------------------------- */

s_dparams* init_def_dparams(void) ;
s_dparams* get_dpocket_args(int nargs, char **args) ;

int add_list_complexes(char *str_list_file, s_dparams *par) ;
int add_complexe(char *complex, char *ligand, s_dparams *par) ;
int parse_dist_crit(char *str, s_dparams *p) ;

void print_dparams(s_dparams *p, FILE *f) ;
void print_dpocket_usage(FILE *f) ;
void free_dparams(s_dparams *p) ;

#endif
