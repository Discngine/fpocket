
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

#ifndef DH_PSORTING
#define DH_PSORTING

/* -----------------------------INCLUDES--------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "pocket.h"

/* ---------------------- PUBLIC STRUCTURES ----------------------------------*/


/* ----------------------------PROTOTYPES-------------------------------------*/

void sort_pockets(c_lst_pockets *pockets, 
				  int (*fcmp)(const node_pocket*, const node_pocket*)) ;

int compare_pockets_nasph(const node_pocket *p1, const node_pocket *p2) ;
int compare_pockets_volume(const node_pocket *p1, const node_pocket *p2) ; 
int compare_pockets_score(const node_pocket *p1, const node_pocket *p2) ;
int compare_pockets_corresp(const node_pocket *p1, const node_pocket *p2) ;
int compare_pockets_vol_corresp(const node_pocket *p1, const node_pocket *p2) ;

#define M_VOLUME_SORT_FUNCT &compare_pockets_volume
#define M_SCORE_SORT_FUNCT &compare_pockets_score
#define M_NASPH_SORT_FUNCT &compare_pockets_nasph

#endif
