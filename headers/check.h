
#ifndef M_CHECK_H
#define	M_CHECK_H

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


#include <stdlib.h>
#include <stdio.h>

#include "fpocket.h"
#include "fpout.h"
#include "rpdb.h"
#include "atom.h"
#include "fparams.h"

int check_qhull(void) ;
int check_fparams(void) ;
int check_fpocket (void );
int check_is_valid_element(void) ;
int check_pdb_reader(void) ;
void load_pdb_line(s_atm *atom, char *line) ;
void test_pdb_line( char test_case[], const char entry[], int id, const char name[],
                    char aloc, char chain, int resid, char insert,
                    float x, float y, float z, float occ, float bfactor,
                    const char symbol[], int charge, int N) ;

#endif	/* _CHECK_H */

