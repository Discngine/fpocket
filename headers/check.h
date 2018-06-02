
#ifndef M_CHECK_H
#define	M_CHECK_H
/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */


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

