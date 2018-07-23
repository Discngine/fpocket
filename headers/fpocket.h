/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_FPOCKET
#define DH_FPOCKET

/* --------------------------------INCLUDES-----------------------------------*/

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
#include "descriptors.h"
#include "clusterlib.h"

#include "fparams.h"
#include "memhandler.h"
#include "energy.h"

#include "topology.h"

#define DEBUG 0

#define DEBUG_STREAM stdout     /**< define on zhich stream you want to see the debug messages, valid are stdout or stderr*/

/* ------------------------------PROTOTYPES-----------------------------------*/

c_lst_pockets* search_pocket(s_pdb *pdb, s_fparams *params,s_pdb *pdb_w_lig) ;

#endif
