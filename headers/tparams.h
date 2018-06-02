/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_TPARAMS
#define DH_TPARAMS

/* ------------------------------- INCLUDES ----------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>

#include "fparams.h"
#include "utils.h"
#include "memhandler.h"

// -------------------------------------- PUBLIC MACROS ---------------------------------------------

/* Options of the test program */
#define M_PAR_VALID_INPUT_FILE 'L' /**< input file flag*/
#define M_PAR_LIG_NEIG_DIST 'd' /**< ligand neighbour distance flag*/
#define M_PAR_P_STATS_OUT 'o' /**< output prefix (particular) flag*/
#define M_PAR_G_STATS_OUT 'g' /**< general output prefix flag*/
#define M_PAR_KEEP_FP_OUTPUT 'k' /**< flag to keep the fpocket output*/


/* Write the statistics output of tpocket to : */
#define M_STATS_OUTP "stats_p.txt" /**< standard per pocket output name*/
#define M_STATS_OUTG "stats_g.txt" /**< standard general output name*/
#define M_MAX_FILE_NAME_LENGTH 300 /**< max filename length */
/* #define M_PAR_P_STATS_OUT 'o' */
/* in order to get the atom set of the pocket, detect around x A of the ligand*/
#define M_LIG_NEIG_DIST 4.0 /**< ligand neighbour distance for explicit pocket definition*/

#define M_TP_USAGE "\
\n***** USAGE (tpocket) *****\n\
\n\
The program needs as input a file containing at each                 \n\
line a pdb file name (apo + complexe), a ligand code                 \n\
(3 letters), all separeted by a tabulation.                          \n\
The format of each line must therefore be:                           \n\n\
{PATH/}APO.pdb  {PATH/}HOLO.pdb  LIG.                                \n\n\
The ligand code is the resname of the ligand atoms in                \n\
the pdb file of the HOLO form of the protein.                        \n\n\
See the manual for more information.                                 \n\n\
Example of command using default parameters:                         \n\
\t./bin/tpocket -L file_path                                         \n\n\
Options:                                                             \n\
\t-g string  : Write global performance to this file                 \n\
\t             Default name: ./stats_g.txt.           (./stats_g.txt)\n\
\t-o string  : Write pocket detailed statistics to .                 \n\
\t             this file Default name: ./stats_p.txt  (./stats_p.txt)\n\
\t-d float   : Distance criteria for the 2 ways to                   \n\
\t             define the actual pocket               (4.0)          \n\n\
Options specific to fpocket are usable too.\n\
See the manual/documentation for mor information.\n\
***************************\n" /**< output for the tpocket usage*/

/* --------------------------- PUBLIC STRUCTURES -----------------------------*/

/**
 Container of the tpocket parameters
*/
typedef struct s_tparams
{
	char **fapo,    /**< path to the apo structure*/
		 **fcomplex, /**< path to the holo structure*/
		 **fligan; /**< name of the ligand residue*/
	
	char *p_output; /**< per pocket output path*/
	char *g_output; /**< general output path*/
	
	char stats_g[128] ; /* M_STATS_OUTG */
	char stats_p[128] ; /* M_STATS_OUTP */

	float lig_neigh_dist ; /**< ligand neighbour dist for explicit pocket definition */
	int nfiles ; /**< number of files to analyze*/
	int keep_fpout ; /**< keep the fpocket output (flag)*/

/* Parameters for the pocket finder program (also needed for validation program...) */

	s_fparams *fpar ; /**< fpocket parameter container*/

} s_tparams ;

/* ------------------------------ PROTOTYPES ---------------------------------*/

s_tparams* init_def_tparams(void) ;
s_tparams* get_tpocket_args(int nargs, char **args) ;
int add_list_data(char *str_list_file, s_tparams *par) ;
int add_prot(char *apo, char *complex, char *ligan, s_tparams *par) ;
int parse_lig_neigh_dist(char *str, s_tparams *p) ;

void free_tparams(s_tparams *p);
void print_test_usage(FILE *f) ;
void print_params(s_tparams *p, FILE *f) ;

#endif
