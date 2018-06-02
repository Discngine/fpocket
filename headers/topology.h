/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef TOPOLOGY_H
#define	TOPOLOGY_H


#include <math.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "fpocket.h"
#include "dparams.h"
#include "fparams.h"
#include "memhandler.h"
#include "utils.h"

/* 
 * Plugin header files; get plugin source from www.ks.uiuc.edu/Research/vmd"
 */
#include "libmolfile_plugin.h"
#include "molfile_plugin.h"

typedef struct s_topology {
    molfile_atom_t *topology_atoms; /** molfile atoms for topology*/
    int natoms_topology; /** number of atoms in topology*/
    float *ff_mass; /** FF mass of atoms **/
    float *ff_charge; /** FF charge of atoms **/
    float *ff_radius; /**FF radius of atoms**/
    char **ff_type; /**FF type of atom**/

} s_topology;

void read_topology(char *topology_path, s_pdb *pdb);
short get_ff_type(char *atom_name);
s_topology *init_topology(void);



#endif	/* TOPOLOGY_H */


