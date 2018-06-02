/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
 
#ifndef DH_VORONOI_LST
#define DH_VORONOI_LST

/* --------------------------------INCLUDES---------------------------------- */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "voronoi.h"
#include "atom.h"
#include "memhandler.h"

/* ---------------------------------MACROS----------------------------------- */


/* -------------------------------STRUCTURES-------------------------------- */

/** Chained list stuff for vertices in a pocket (to enable dynamic modifications) */
typedef struct node_vertice
{
	struct node_vertice *next;  /**<pointer to next node*/
	struct node_vertice *prev;  /**< pointer to previous node*/
	s_vvertice *vertice ; /**< pointer to current vertice*/

} node_vertice ;
/** Chained list stuff for vertices in a pocket (to enable dynamic modifications) */
typedef struct c_lst_vertices
{
	struct node_vertice *first ;    /**< pointer to first node*/
	struct node_vertice *last ;     /**< pointer to last node */
	struct node_vertice *current ;  /**< pointer to current node*/
	size_t n_vertices ;     /**< number of vertices*/

} c_lst_vertices ;

/* ---------------------------------PROTOTYPES------------------------------- */

c_lst_vertices *c_lst_vertices_alloc(void);
node_vertice *node_vertice_alloc(s_vvertice *vertice);
node_vertice *c_lst_vertices_add_first(c_lst_vertices *lst, s_vvertice *vertice);
node_vertice *c_lst_vertices_add_last(c_lst_vertices *lst,s_vvertice *vertice);
node_vertice *c_lst_vertices_drop(c_lst_vertices *lst, node_vertice *node) ;
void c_lst_vertices_free(c_lst_vertices *lst);

s_atm** get_vert_contacted_atms(c_lst_vertices *v_lst, int *nneigh) ;

#endif


