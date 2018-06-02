/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
#ifndef DH_NEIGHBOR
#define DH_NEIGHBOR

/* --------------------------------INCLUDES-----------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>

#include "voronoi.h"
#include "atom.h"
#include "rpdb.h"
#include "sort.h"
#include "memhandler.h"

/* --------------------------------MACROS------------------------------------ */

#define M_INTERFACE_SEARCH_DIST 8.0
#define M_INTERFACE_SEARCH 1
#define M_NO_INTERFACE_SEARCH 0

/* -------------------------- PUBLIC STRUCTURES ------------------------------*/

/* -------------------------------PROTOTYPES--------------------------------- */

s_atm** get_mol_atm_neigh(s_atm **atoms, int natoms, s_atm **all, int nall,
			  float dist_crit, int *nneigh) ;

s_atm** get_mol_ctd_atm_neigh(s_atm **atoms, int natoms,
                              s_vvertice **pvert, int nvert,
                              float vdist_crit, int interface_search, int *nneigh) ;

s_vvertice** get_mol_vert_neigh(s_atm **atoms, int natoms,
				s_vvertice **pvert, int nvert,
				float dist_crit, int *nneigh) ;

float count_pocket_lig_vert_ovlp(s_atm **lig, int nlig,
				 s_vvertice **pvert, int nvert,
				 float dist_crit) ;

float count_atm_prop_vert_neigh (s_atm **lig, int nlig,
				 s_vvertice **pvert, int nvert,
				 float dist_crit,int n_lig_molecules) ;


int count_vert_neigh_P(s_vvertice **pvert, int nvert,
                       s_vvertice **pvert_all, int nvert_all,
                       float dcrit) ;

int count_vert_neigh(s_vsort *lsort, s_vvertice **pvert, int nvert,float dcrit);

#endif
