/* 
 * File:   topology.h
 * Author: peter
 *
 * Created on August 4, 2013, 5:41 PM
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




#endif	/* TOPOLOGY_H */


