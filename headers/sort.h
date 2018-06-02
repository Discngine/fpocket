/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

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
