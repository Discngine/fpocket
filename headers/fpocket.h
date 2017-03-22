
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
