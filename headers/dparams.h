
/**
    COPYRIGHT DISCLAIMER

    Vincent Le Guilloux, Peter Schmidtke and Pierre Tuffery, hereby
	claim all copyright interest in the program “fpocket” (which
	performs protein cavity detection) written by Vincent Le Guilloux and Peter
	Schmidtke.

    Vincent Le Guilloux  01 Decembre 2012
    Peter Schmidtke      01 Decembre 2012
    Pierre Tuffery       01 Decembre 2012

    GNU GPL

    This file is part of the fpocket package.

    fpocket is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fpocket is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with fpocket.  If not, see <http://www.gnu.org/licenses/>.

**/

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
