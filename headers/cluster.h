
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

*/

#ifndef DH_CLUSTER
#define DH_CLUSTER

/* ------------------------------INCLUDES-------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "voronoi.h"
#include "calc.h"
#include "pocket.h"
/* ------------------------------STRUCTURES-------------------------------------*/

typedef struct s_sorted_pocket_list
{
    int pid1;
    int pid2;
    float dist;
} s_sorted_pocket_list ;

/* ------------------------------PROTOTYPES---------------------------------- */

void pck_ml_clust(c_lst_pockets *pockets, s_fparams *params);
int comp_pocket(const void *el1, const void *el2);
void pck_final_clust(c_lst_pockets *pockets, s_fparams *params,float max_dist,int min_nneigh,s_pdb *pdb,s_pdb *pdb_w_lig);

#endif
