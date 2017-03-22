/**
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

#ifndef DH_ASA
#define DH_ASA


/* Maximal distance between two vertices in order to belong to the same
 * pocket (single linkage clustering) */


/* -----------------------------INCLUDES--------------------------------------*/
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>

#include "rpdb.h"
#include "voronoi.h"

#include "pocket.h"
#include "psorting.h"
#include "cluster.h"
#include "refine.h"

#include "fparams.h"
#include "memhandler.h"

#ifndef M_PI
#define M_PI 3.1415926535897932384626433832795
#endif

#define M_NSPIRAL 100
#define M_PADDING 1.0
#define M_PROBE_SIZE 1.4
#define M_PROBE_SIZE2 2.2

/* ---------------------- PUBLIC STRUCTURES ----------------------------------*/




int atom_not_in_list(s_atm *a,s_atm **atoms,int natoms);
void set_ASA(s_desc *desc,s_pdb *pdb, s_vvertice **tvert,int nvert);
int *get_unique_atoms(s_vvertice **tvert,int nvert, int *n_ua,s_atm **p,int na);
float *get_points_on_sphere(int nop);
int *get_surrounding_atoms_idx(s_vvertice **tvert,int nvert,s_pdb *pdb, int *n_sa);

#endif
