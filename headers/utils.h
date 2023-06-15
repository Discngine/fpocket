/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */


#ifndef DH_UTILS
#define DH_UTILS

/* ------------------------------ INCLUDES ---------------------------------- */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <time.h>

#ifdef MD_USE_GSL 	/* GSL */

#include <gsl/gsl_rng.h>
#include <gsl/gsl_randist.h>

#endif 				/* /GSL */

#include "memhandler.h"

/* ------------------------------- PUBLIC MACROS ---------------------------- */

#define M_MAX_PDB_NAME_LEN 200  /**< maximum pdb filename length*/
#define M_MAX_CUSTOM_POCKET_LEN 8000 /** maximum length for a custom pocket string*/
#define M_SIGN 1
#define M_NO_SIGN 0


#ifdef MD_USE_GSL	/* GSL */

#define M_GEN_MTWISTER gsl_rng_mt19937
#define M_GEN_GFSR4 gsl_rng_gfsr4
#define M_GEN_TAUS gsl_rng_taus2
#define M_GEN_RANLXS0 gsl_rng_ranlxs0
#define M_GEN_RANLXS1 gsl_rng_ranlxs1

#endif				/* /GSL */

/* ------------------------------ PUBLIC STRUCTURES ------------------------- */

typedef struct tab_str 
{
	char **t_str ;
	int nb_str ;

} tab_str ; 


/* ------------------------------- PROTOTYPES ------------------------------- */

int str_is_number(const char *str, const int sign) ;
int str_is_float(const char *str, const int sign) ;
void str_trim(char *str) ;
tab_str* str_split(const char *str, const int sep) ;

short file_exists(const char * filename);


tab_str* f_readl(const char *fpath, int nchar_max) ;
void free_tab_str(tab_str *tstr) ;
void print_tab_str(tab_str* strings) ;

int in_tab(int *tab, int size, int val) ;
int index_of(int *tab, int size, int val)  ;


void remove_ext(char *str) ;
void remove_path(char *str) ;
void extract_ext(char *str, char *dest) ;
void extract_path(char *str, char *dest) ;

void start_rand_generator(void) ;
float rand_uniform(float min, float max) ;

FILE* fopen_pdb_check_case(char *name, const char *mode)  ;

float float_get_min_in_2D_array(float **t,size_t n,int col);
float float_get_max_in_2D_array(float **t,size_t n,int col);

#endif
