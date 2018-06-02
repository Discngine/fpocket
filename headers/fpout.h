/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

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
void write_out_fpocket_info_file(c_lst_pockets *pockets,  char *output_file_name);
void write_descriptors_DB(c_lst_pockets *pockets, FILE *f);
void write_out_fpocket_DB(c_lst_pockets *pockets, s_pdb *pdb, char *input_name);


#endif
