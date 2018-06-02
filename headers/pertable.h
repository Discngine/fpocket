/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

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
 
