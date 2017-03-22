 
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
 

#ifndef DH_WRITEPDB
#define DH_WRITEPDB

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* -------------------------- PUBLIC FUNCTIONS ------------------------------ */

void write_pdb_atom_line(FILE *f, const char rec_name[], int id, const char atom_name[], 
						 char alt_loc, const char res_name[], const char chain[], 
						 int res_id, const char insert, float x, float y, float z, float occ, 
						 float bfactor, int abpa, const char *symbol, int charge,float abpa_prob)  ;
void write_pqr_atom_line(FILE *f, const char *rec_name, int id, const char *atom_name, 
						 char alt_loc, const char *res_name, const char *chain, 
						 int res_id, const char insert, float x, float y, float z, float charge, 
						 float radius);
#endif
