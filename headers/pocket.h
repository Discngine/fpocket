/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_POCKET
#define DH_POCKET


/* Maximal distance between two vertices in order to belong to the same 
 * pocket (single linkage clustering) */
#define MAX_CON_DIST 2.5

#define M_LIG_IN_POCKET_DIST 4.0  /**< maximum distance a ligand atom could have to a pocket barycenter to be considered inside the pocket*/
/* -----------------------------INCLUDES--------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "voronoi_lst.h"
#include "pscoring.h"
#include "fparams.h"
#include "aa.h"

#include "utils.h"
#include "memhandler.h"

/* ---------------------- PUBLIC STRUCTURES ----------------------------------*/

/**pocket containing structure*/
typedef struct s_pocket
{
    s_desc *pdesc ; /**< pointer to pocket descriptor structure */

    c_lst_vertices *v_lst ; /**< chained list of Voronoi vertices*/
    float score,	/**< Discretize different parts of the score */
	  ovlp,         /**< Atomic overlap	*/
	  ovlp2,        /**< second overlap criterion*/
	  vol_corresp,	/**< Volume overlap */
	  bary[3] ;			/**< Barycenter (center of mass) of the pocket */
    
    int rank,				/**< Rank of the pocket */
	size,
	nAlphaApol,			/**< Number of apolar alpha spheres*/
	nAlphaPol ;			/**< Number of polar alpha spheres */

} s_pocket ; 

/** Chained list stuff for pockets */
typedef struct node_pocket 
{
	struct node_pocket *next ; /**< pointer to next pocket*/
	struct node_pocket *prev ; /**< pointer to previous pocket*/
	s_pocket *pocket ;

} node_pocket ;

/** Chained list stuff for pockets */
typedef struct c_lst_pockets 
{
	struct node_pocket *first ; /**< pointer to the first pocket*/
	struct node_pocket *last ; /**< pointer to the last pocket*/
	struct node_pocket *current ; /**< pointer to the current pocket*/
	size_t n_pockets ;  /**< number of pockets in the chained list*/

	s_lst_vvertice *vertices ; /**< access to vertice list*/

} c_lst_pockets ;


/* ------------------------------PROTOTYPES----------------------------------*/


/* CLUSTERING FUNCTIONS */

int updateIds(s_lst_vvertice *lvvert, int i, int *vNb, int resid,int curPocket,c_lst_pockets *pockets, s_fparams *params);
void addStats(int resid, int size, int **stats,int *lenStats);
c_lst_pockets *assign_pockets(s_lst_vvertice *lvvert);

/* DESCRIPTOR FUNCTIONS */
void set_pockets_descriptors(c_lst_pockets *pockets,s_pdb *pdb,s_fparams *params, s_pdb *pdb_w_lig) ;
void set_normalized_descriptors(c_lst_pockets *pockets) ;
void set_pockets_bary(c_lst_pockets *pockets) ;
s_atm** get_pocket_contacted_atms(s_pocket *pocket, int *natoms) ;
int count_pocket_contacted_atms(s_pocket *pocket) ;
s_vvertice** get_pocket_pvertices(s_pocket *pocket) ;
void set_pocket_contacted_lig_name(s_pocket *pocket, s_pdb *pdb_w_lig);

float set_pocket_mtvolume(s_pocket *pocket, int niter) ;
float set_pocket_volume(s_pocket *pocket, int discret) ;

/* ALLOCATION AND CHAINED LIST OPERATIONS FUNCTIONS*/

s_pocket* alloc_pocket(void) ;
c_lst_pockets *c_lst_pockets_alloc(void);
node_pocket *node_pocket_alloc(s_pocket *pocket);
void c_lst_pocket_free(c_lst_pockets *lst);

node_pocket *c_lst_pockets_add_first(c_lst_pockets *lst, s_pocket *pocket);
node_pocket *c_lst_pockets_add_last(c_lst_pockets *lst,s_pocket *pocket,int cur_n_apol, int cur_n_pol);
void swap_pockets(c_lst_pockets *pockets, node_pocket *p1, node_pocket *p2) ;
void dropPocket(c_lst_pockets *pockets,node_pocket *pocket);
void mergePockets(node_pocket *pocket,node_pocket *pocket2,c_lst_pockets *pockets);
node_pocket *searchPocket(int resid,c_lst_pockets *pockets);

/* OTHER FUNCTON*/
void reset_pocket(s_pocket *pocket) ;
void print_pocket(FILE *f, s_pocket *pocket);
void print_pockets(FILE *f, c_lst_pockets *pockets) ;
void print_pockets_inv(FILE *f, c_lst_pockets *pockets) ;
void free_pocket(s_pocket *p);

#endif
