
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

#ifndef DH_SORT
#define DH_SORT

/* ------------------------------INCLUDES-------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#include "rpdb.h"
#include "voronoi.h"

#include "memhandler.h"

/* ---------------------------------MACROS------------------------------------*/

#define M_ATOM_TYPE 0
#define M_VERTICE_TYPE 1

#define M_SORT_X 1
#define M_SORT_Y 2
#define M_SORT_Z 3

/* ------------------------------------STRUCTURES-----------------------------*/
/**
	A vector (here it will be  either atoms or vertices)
*/
typedef struct s_vect_elem 
{
	void *data ;	/**< Pointer to data */
	int type ;		/**< Type of data (either s_atm or s_vvertice) */

} s_vect_elem ;

/**
	A list of vector (basicly this structure contains atoms and vertices)
*/
typedef struct s_vsort
{
	s_vect_elem *xsort ;	/**< Elements sorted by x coord */
	int nelem ;				/**< Number of elements */

} s_vsort ;


/* --------------------------------PROTOTYPES---------------------------------*/

s_vsort* get_sorted_list(s_atm **atoms, int natms, s_vvertice **pvert, int nvert) ;
void print_sorted_lst(s_vsort *lsort, FILE *buf) ;
void free_s_vsort(s_vsort *lsort) ;

#endif
