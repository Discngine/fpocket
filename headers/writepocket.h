/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
 
#ifndef DH_WRITEPOCKET
#define DH_WRITEPOCKET

/* ------------------------------INCLUDES------------------------------------ */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "voronoi.h"
#include "pocket.h"
#include "writepdb.h"
#include "utils.h"
#include "asa.h"

/* ------------------------- PUBLIC STRUCTURES ------------------------------ */

/* -----------------------------PROTOTYPES----------------------------------- */

void write_pockets_single_pdb(const char out[], s_pdb *pdb, c_lst_pockets *pockets)  ;
void write_pockets_single_pqr(const char out[], c_lst_pockets *pockets);
void write_mdpockets_concat_pqr(FILE *f, c_lst_pockets *pockets);

void write_each_pocket(const char out_path[], c_lst_pockets *pockets) ;
void write_pocket_pdb(const char out[], s_pocket *pocket) ;
void write_pocket_pqr(const char out[], s_pocket *pocket) ;

void write_pdb_atoms(FILE *f, s_atm *atoms, int natoms) ;

void write_each_pocket_for_DB(const char out_path[], c_lst_pockets *pockets,s_pdb *pdb);
void write_pocket_pqr_DB(const char out[], s_pocket *pocket);
void write_pocket_pdb_DB(const char out[], s_pocket *pocket,s_pdb *pdb);

#endif
