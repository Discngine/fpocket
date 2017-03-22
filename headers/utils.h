/*
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
