/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
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
int *get_surrounding_atoms_idx(s_vvertice **tvert,int nvert,s_pdb *pdb, int *n_sa, s_atm **ua, int n_ua);

#endif
