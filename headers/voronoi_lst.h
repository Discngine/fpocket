
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


