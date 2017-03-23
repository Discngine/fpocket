#include "../headers/mdpmem.h"


/*

## GENERAL INFORMATION
##
## FILE 					mdpmem.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			04-08-09
##
## SPECIFICATIONS
##
##	This file contains all main routines of the mdpocket program.
##	Given a set of snapshot PDB files, those routines will
##	calculate cavities on these snapshots and output these in a convenient
##      format. mdpocket currently has two different ways of running. The first
##      allows the user to explore transient and conserved cavities throughout
##      an MD trajectory. This first analysis is performed by the mdpocket_detect
##      function.
##      Once the analysis of the first run is done, the user can specify a zone
##      where he wants to measure some cavity descriptors. This task is performed
##      in a second run, but this time of the mdpocket_characterize function.
##      Both runs do not yield at all the same results and do not serve the same
##      purpose.
##      In order to get more informed about the mdpocket methodology, please refer
##      to the manual shipped with fpocket.
##
## MODIFICATIONS HISTORY
##
##
##      07-06-10        (p) Adding header + comments + doc
##	01-08-09	(vp) Created (random date...)
##
## TODO or SUGGESTIONS
##

*/


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




/**
   ## FUNCTION:
	init_md_concat

   ## SPECIFICATION:
        Allocate memory for the concatenated voronoi vertice structure
        Currently NOT USED

   ## PARAMETRES:
        void

   ## RETURN:
        s_mdconcat * : Structure containing allocated memory
*/

s_mdconcat *init_md_concat(void){
    s_mdconcat *m=(s_mdconcat *) my_malloc(sizeof(s_mdconcat));
    m->n_vertpos=0;
    m->vertpos=NULL;
    m->n_snapshots=0;
    return m;
}




/**
   ## FUNCTION:
	alloc_first_md_concat

   ## SPECIFICATION:
	Allocate memory for the md concat structure (first snapshot)

   ## PARAMETRES:
	@ s_mdconcat *m: Pointer to the structure to free,
        @ size_t n: Number of vertices in the snapshot to add to m

   ## RETURN:
	void
*/
void alloc_first_md_concat(s_mdconcat *m,size_t n){
    size_t z;
    m->vertpos=(float **) my_malloc(sizeof(float *)*n);
    for(z=0;z<n;z++){
        m->vertpos[z]=(float *)my_malloc(sizeof(float)*4);
        m->vertpos[z][0]=0.0;
        m->vertpos[z][1]=0.0;
        m->vertpos[z][2]=0.0;
        m->vertpos[z][3]=0.0;
    }
    m->n_vertpos=n;
}

/**
   ## FUNCTION:
	realloc_md_concat

   ## SPECIFICATION:
	Reallocate memory for the md concat structure (to add a new snapshot)

   ## PARAMETRES:
	@ s_mdconcat *m: Pointer to the structure to free,
        @ size_t n: Number of vertices in the snapshot to add to m

   ## RETURN:
	void

*/
void realloc_md_concat(s_mdconcat *m,size_t n){
    size_t z;
    m->vertpos=(float **) my_realloc(m->vertpos,sizeof(float *)*(m->n_vertpos+n));
    for(z=0;z<n;z++){
        m->vertpos[m->n_vertpos+z]=(float *)my_malloc(sizeof(float)*4);
        m->vertpos[m->n_vertpos+z][0]=0.0;
        m->vertpos[m->n_vertpos+z][1]=0.0;
        m->vertpos[m->n_vertpos+z][2]=0.0;
        m->vertpos[m->n_vertpos+z][3]=0.0;
    }
    m->n_vertpos+=n;
}

/**
   ## FUNCTION:
	free_mdconcat

   ## SPECIFICATION:
	Free the mdconcat structure

   ## PARAMETRES:
	@ s_mdconcat *m: Pointer to the structure to free

   ## RETURN:
	void

*/
void free_mdconcat(s_mdconcat *m){
    size_t i;
    for(i=0;i<m->n_vertpos;i++){
        my_free(m->vertpos[i]);
    }
    my_free(m->vertpos);
    my_free(m);
}


