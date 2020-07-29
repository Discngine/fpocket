/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_RPDBB
#define DH_RPDBB

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "atom.h"
#include "pertable.h"
#include "utils.h"
#include "memhandler.h"
#include "math.h"
#include "fparams.h"

/* 
 * Plugin header files; get plugin source from www.ks.uiuc.edu/Research/vmd"
 */
#include "libmolfile_plugin.h"
#include "molfile_plugin.h"


#define M_PDB_LINE_LEN 80   /**< actual record size */
#define M_PDB_BUF_LEN  83    /**< size need to buffer + CR, LF, and NUL */
#define M_PDB_FILE_NAME_LEN 500 /**< size allocated for PDB file names*/
#define M_KEEP_LIG  1       /**< Keep ligand flag*/
#define M_DONT_KEEP_LIG 0   /**< Don't keep ligand flag*/

#define M_PDB_HEADER  1
#define M_PDB_REMARK  2
#define M_PDB_ATOM    3
#define M_PDB_CONECT  4
#define M_PDB_HETATM  5
#define M_PDB_CRYST1  6
#define M_PDB_EOF     7
#define M_PDB_END     8
#define M_PDB_UNKNOWN 9
#define NB_MM_TYPES   9

/*
 * API functions start here
 */
/**
 Container of the PDB structure
 */

typedef struct s_atom_ptr_list{
    s_atm **latoms;
    int natoms;
} s_atom_ptr_list;

typedef struct s_pdb_grid{
    s_atom_ptr_list ***atom_ptr;    /**< values of the md grid (i.e. number of alpha spheres nearby*/
    float *origin;          /**< origin of the grid (3 positons, xyz)*/
    int nx,ny,nz;           /**< gridsize at the x, y, z axis*/
    float resolution;       /**< resolution of the grid; in general 1A*/
} s_pdb_grid;


typedef struct s_pdb
{
    FILE *fpdb ;    /**< file handle of the pdb file*/
    s_pdb_grid *grid;
    s_atm *latoms ;     /**< The list of atoms: contains all atoms! */

    s_atm **latoms_p ;  /**< List of pointers to latoms elements. */
    s_atm **lhetatm ;	/**< List of pointer to heteroatoms in the latoms list. */
    s_atm **latm_lig ;	/**< List of pointer to the ligand atoms in the atom list*/
    float *xlig_x;      /**<coordinate array for ecplicit ligand*/
    float *xlig_y;
    float *xlig_z;
    int n_xlig_atoms;   /**number of atoms in xlig array ( number of atoms of selected atom*/
    int natoms,			/**< Number of atoms */
            nhetatm,		/**< Number of HETATM */
            natm_lig ;		/**< Number of ligand atoms */

    float A, B, C, 			/**< Side lengths of the unit cell */
          alpha, beta, gamma ;	/**< Angle between B and C, A and C, A and C */

    char header[M_PDB_BUF_LEN] ; /**< Header container*/
    char fname[M_PDB_FILE_NAME_LEN];    /**< File name container*/
    float avg_bfactor;  /**<overall average B factor*/

} s_pdb ;


typedef struct s_min_max_coords
{
    float minx;             /**< minimum x coordinate for all pockets in one snapshot*/
    float miny;             /**< minimum y coordinate for all pockets in one snapshot*/
    float minz;             /**< minimum z coordinate for all pockets in one snapshot*/
    float maxx;             /**< maximum x coordinate for all pockets in one snapshot*/
    float maxy;             /**< maximum y coordinate for all pockets in one snapshot*/
    float maxz;             /**< maximum z coordinate for all pockets in one snapshot*/
} s_min_max_coords;




/* ------------------------------ PUBLIC FUNCTIONS ---------------------------*/

s_pdb* rpdb_open(char *fpath, const char *ligan, const int keep_lig, int model_number,s_fparams *params) ;
void rpdb_read(s_pdb *pdb, const char *ligan, const int keep_lig, int model_number,s_fparams *params) ;

void rpdb_extract_atm_resname(char *pdb_line, char *res_name) ;
int rpdb_extract_atm_resumber(char *pdb_line);
int element_in_kept_res(char *res_name);
void guess_element(char *aname, char *element, char *res_name) ;

void rpdb_extract_cryst1(char *rstr, float *alpha, float *beta, float *gamma,
						 float *a, float *b, float *c) ;
void rpdb_extract_atom_values(char *pdb_line, float *x, float *y, float *z,
							  float *occ, float *beta) ;

void rpdb_extract_atom_coordinates(char *pdb_line, float *x, float *y, float *z);
void rpdb_extract_pdb_atom( char *pdb_line, char *type, int *atm_id, char *name,
							char *alt_loc, char *res_name, char *chain,
							int *res_id, char *insert,
							float *x, float *y, float *z, float *occ,
							float *bfactor, char *symbol, int *charge, int *guess_flag) ;

void rpdb_print(s_pdb *pdb);

int get_number_of_h_atoms(s_pdb *pdb);

void free_pdb_atoms(s_pdb *pdb) ;
s_min_max_coords *float_get_min_max_from_pdb(s_pdb *pdb);
void init_coord_grid(s_pdb *pdb);
void create_coord_grid(s_pdb *pdb);
void fill_coord_grid(s_pdb *pdb);
s_atom_ptr_list *init_atom_ptr_list(void);


short get_mm_type_from_element(char *symbol);
int chains_to_delete(char *chains_selected, char current_line_chain, int is_chain_kept);
int is_ligand(char *chains_selected, char current_line_chain);
#endif
