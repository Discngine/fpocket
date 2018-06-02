/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
#ifndef DH_MDPBASE
#define DH_MDPBASE

/* ----------------------------- INCLUDES ------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>
#include <math.h>

#include "fpocket.h"
#include "fpout.h"
#include "writepocket.h"
#include "tpocket.h"
#include "dparams.h"
#include "descriptors.h"
#include "neighbor.h"
#include "pocket.h"
#include "cluster.h"
#include "refine.h"
#include "aa.h"
#include "utils.h"
#include "mdparams.h"
#include "memhandler.h"

/* ---------------------------------MACROS----------------------------------*/

#define M_MDP_GRID_RESOLUTION 1.0   /**< grid resolution in Angstroems*/
#define M_MDP_CUBE_SIDE 2.0         /**< size of the side of the cube to count vvertices*/
#define M_MDP_WP_ATOM_DIST 4.0      /**< max distance for constructing the atom set of the pocket with voronoi vertices*/
#define M_MDP_ATOM_DENSITY_DIST 2.0 /**< max distance (for each dimension) for mapping pocket densities to neighbouring atoms*/
#define M_MIN_G_DENS 20.0            /**< minimum density of alpha spheres around a grid point for it to be taken into account for further processing using */
/* -------------------------------STRUCTURES--------------------------------*/

/**
 Structure handle for the md concat object
 */
typedef struct s_mdconcat
{
    float **vertpos;    /**< nx4 array of alpha sphere center + radius */
    size_t n_vertpos;   /**< number of vertices in all snapshots*/
    int n_snapshots;    /**< number of snapshots of the trajectory*/
} s_mdconcat ;

/**
 Structure handle for the grid
 */
typedef struct s_mdgrid
{
    float ***gridvalues;    /**< values of the md grid (i.e. number of alpha spheres nearby*/
    float *origin;          /**< origin of the grid (3 positons, xyz)*/
    int nx,ny,nz;           /**< gridsize at the x, y, z axis*/
    float resolution;       /**< resolution of the grid; in general 1A*/
    int n_snapshots;        /**< number of snapshots of the trajectory*/
} s_mdgrid;


typedef struct s_min_max_pockets
{
    float minx;             /**< minimum x coordinate for all pockets in one snapshot*/
    float miny;             /**< minimum y coordinate for all pockets in one snapshot*/
    float minz;             /**< minimum z coordinate for all pockets in one snapshot*/
    float maxx;             /**< maximum x coordinate for all pockets in one snapshot*/
    float maxy;             /**< maximum y coordinate for all pockets in one snapshot*/
    float maxz;             /**< maximum z coordinate for all pockets in one snapshot*/
} s_min_max_pockets;

/* -------------------------------PROTOTYPES--------------------------------*/

void store_vertice_positions(s_mdconcat *m,c_lst_pockets *pockets);
s_min_max_pockets *float_get_min_max_from_pockets(c_lst_pockets *pockets);
void calculate_md_dens_grid(s_mdgrid *g,c_lst_pockets *pockets,s_mdparams *par);
void update_md_grid(s_mdgrid *g, s_mdgrid *refg, c_lst_pockets *pockets,s_mdparams *par);
void project_grid_on_atoms(s_mdgrid *g,s_pdb *pdb);
s_mdconcat *init_md_concat(void);
void reset_grid(s_mdgrid *g);
s_mdgrid *init_md_grid(c_lst_pockets *pockets,s_mdparams *par);
void normalize_grid(s_mdgrid *g, int n);
void alloc_first_md_concat(s_mdconcat *m,size_t n);
void realloc_md_concat(s_mdconcat *m,size_t n);
void free_mdconcat(s_mdconcat *m);
void free_md_grid(s_mdgrid *g);
void writeAlphaSpheresToFile(FILE *f,c_lst_pockets *pockets);
s_min_max_pockets *assign_min_max_from_user_input(s_mdparams *par);



#endif
