/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_MAINFP
#define DH_MAINFP

/* ------------------------------INCLUDES-------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#include "fpocket.h"
#include "rpdb.h"
#include "fparams.h"
#include "fpout.h"
#include "topology.h"
#include "read_mmcif.h"

#include "memhandler.h"

#include "libmolfile_plugin.h"
#include "molfile_plugin.h"

/* ------------------------------PROTOTYPES-----------------------------------*/


void process_pdb(char *pdbname, s_fparams *params) ;
s_pdb *open_file_format(char *fpath, const char *ligan, const int keep_lig, int model_number, s_fparams *par);
void read_file_format(s_pdb *pdb, const char *ligan, const int keep_lig, int model_number, s_fparams *par);
#endif
