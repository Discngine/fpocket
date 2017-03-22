
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
