
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

#ifndef DH_PERTABLE
#define DH_PERTABLE

/* ----------------------------STRUCTURES------------------------------------ */

/* -----------------------------INCLUDES------------------------------------- */

#include <string.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>

#include "utils.h"


/* ---------------------------PROTOTYPES--------------------------------------*/

float pte_get_vdw_ray(const char *symbol) ;
float pte_get_mass(const char *symbol) ;
float pte_get_enegativity(const char *symbol) ;
int is_valid_element(const char *str, int ignore_case) ;
int element_in_std_res(char *res_name);
int element_in_nucl_acid(char *res_name);
int is_water(char *res_name);
int is_valid_prot_element(const char *str, int ignore_case);
int is_valid_nucl_acid_element(const char *str, int ignore_case);
#endif
 
