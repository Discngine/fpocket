
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

#ifndef DH_FPOUT
#define DH_FPOUT

// ---------------------------INCLUDES--------------------------------------- */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#include "pocket.h"
#include "utils.h"
#include "writepdb.h"
#include "writepocket.h"
#include "write_visu.h"
#include "fparams.h"

/* -----------------------------PROTOTYPES------------------------------------*/

void write_out_fpocket(c_lst_pockets *pockets, s_pdb *pdb, char *pdbname) ;

void write_descriptors_DB(c_lst_pockets *pockets, FILE *f);
void write_out_fpocket_DB(c_lst_pockets *pockets, s_pdb *pdb, char *input_name);
void write_out_fpocket_info_file(c_lst_pockets *pockets, char *output_file_name);



#endif
