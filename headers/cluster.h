/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
