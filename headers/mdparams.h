/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_MDPARAMS
#define DH_MDPARAMS

/* ----------------------------- INCLUDES ------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>

#include "utils.h"
#include "memhandler.h"
#include "fparams.h"
#include <getopt.h>

/* --------------------------- PUBLIC MACROS ---------------------------------*/


/* Options of the test program */
#define M_MDPAR_INPUT_FILE 'L'
#define M_MDPAR_LONG_INPUT_FILE "pdb_list"
#define M_MDPAR_INPUT_FILE2 'w'
#define M_MDPAR_LONG_INPUT_FILE2 "selected_pocket"
#define M_MDPAR_OUTPUT_FILE 'o'
#define M_MDPAR_LONG_OUTPUT_FILE "output_prefix"
#define M_MDPAR_SCORING_MODE 'S'
#define M_MDPAR_LONG_SCORING_MODE "druggability_score"
#define M_MDPAR_OUTPUT_ALL_SNAPSHOTS 'a'
#define M_MDPAR_LONG_OUTPUT_ALL_SNAPSHOTS "output_all_snapshots"
#define M_MDPAR_TRAJECTORY 't'
#define M_MDPAR_LONG_TRAJECTORY "trajectory_file"
#define M_MDPAR_TRAJECTORY_FORMAT 'O'
#define M_MDPAR_LONG_TRAJECTORY_FORMAT "trajectory_format"
#define M_MDPAR_TOPOLOGY_FILE 'P'
#define M_MDPAR_LONG_TOPOLOGY_FILE "topology_file"
#define M_MDPAR_TOPOLOGY_FORMAT 'T'
#define M_MDPAR_LONG_TOPOLOGY_FORMAT "topology_format"



#define M_MDP_OUTPUT_FILE1_DEFAULT "mdpout_snapshots_concat.pqr"
#define M_MDP_OUTPUT_FILE2_DEFAULT "mdpout_freq_grid.dx"
#define M_MDP_OUTPUT_FILE3_DEFAULT "mdpout_freq_iso_0_5.pdb"
#define M_MDP_OUTPUT_FILE4_DEFAULT "mdpout_descriptors.txt"
#define M_MDP_OUTPUT_FILE5_DEFAULT "mdpout_mdpocket.pdb"
#define M_MDP_OUTPUT_FILE6_DEFAULT "mdpout_mdpocket_atoms.pdb"
#define M_MDP_OUTPUT_FILE7_DEFAULT "mdpout_all_atom_pdensities.pdb"
#define M_MDP_OUTPUT_FILE8_DEFAULT "mdpout_dens_grid.dx"
#define M_MDP_OUTPUT_FILE9_DEFAULT "mdpout_dens_iso_8.pdb"
#define M_MDP_OUTPUT_FILE10_DEFAULT "mdpout_elec_grid.dx"
#define M_MDP_OUTPUT_FILE11_DEFAULT "mdpout_vdw_grid.dx"
#define M_MDP_DEFAULT_ISO_VALUE_FREQ 0.5
#define M_MDP_DEFAULT_ISO_VALUE_DENS 8.0

#define M_MAX_FILE_NAME_LENGTH 300
#define M_MAX_FORMAT_NAME_LENGTH 10
#define M_NB_MC_ITER 2500
//#define M_MIN_ASPH_RAY 3.0
//#define M_MAX_ASPH_RAY 6.0


#define M_MDP_USAGE "\
***** USAGE (mdpocket) *****\n\
\n\
-> 1 : Pocket finding on a MD trajectory -> list of pre-aligned pdbs ordered by time file:\n\
\t./bin/mdpocket -L pdb_list                                  \n\
-> 2 : Pocket finding on a MD trajectory file:\n\
\t./bin/mdpocket -f topology.pdb -t trajectory_file -O trajectory_format\n\
\t     accepted trajectory formats (format in brackets) :\n\
\t                  Amber MDCRD without box information (crd)      \n\
\t                  Amber MDCRD with box information    (crdbox)      \n\
\t                  NetCDF                              (netcdf)         \n\
\t                  DCD                                 (dcd)        \n\
\t                  Gromacs TRR                         (trr)        \n\
\t                  Gromacs XTC                         (xtc)        \n\n\
-> 3 : Pocket characterization on a MD trajectory -> list of pre-aligned pdb ordered by \n\
    time file and wanted pocket pdb file \n\n\
\t./bin/mdpocket -L pdb_list -w wanted_pocket.pdb \n\
\t an example of a wanted pocket file can be obtained by running (1) \n\
\t (mdpout_iso_8.pdb) and non wanted grid points should be deleted by hand (i.e. PyMOL).\n\
\nOPTIONS (find standard parameters in brackets)           \n\n\
\t-o (char *) : common prefix of output file (mdpout) \n\n\
\t-S : if you put this flag, the druggability score is matched to the \n\
\t density grid \n\
\t-a : output all bfactor colored snapshots\n\n\
\t-m (float)  : Minimum radius of an alpha-sphere.      (3.0)\n\
\t-M (float)  : Maximum radius of an alpha-sphere.      (6.0)\n\
\t-A (int)    : Minimum number of apolar neighbor for        \n\
\t              an a-sphere to be considered as apolar.   (3)\n\
\t-i (int)    : Minimum number of a-sphere per pocket.   (30)\n\
\t-D (float)  : Distance threshold for clustering algorithm  \n\
\t-n (integer): Minimum number of neighbor close from        \n\
\t              each other (not merged otherwise).        (3)\n\
\t-p (float)  : Minimum proportion of apolar sphere in       \n\
\t              a pocket (remove otherwise)             (0.0)\n\
\t-v (integer): Number of Monte-Carlo iteration for the      \n\
\t              calculation of each pocket volume.     (2500)\n\
\t-e (char)   : Specify the distance measure for clustering  \n\
\t              e : euclidean distance (default)\n\
\t              b : Manhattan distance\n\
\t              u : Uncentered correlation\n\
\t              c : Pearson correlation\n\
\t              x : uncentered correlation (absolute value)\n\
\t              a : Pearson correlation (absolute value)\n\
\t              s : Spearman's rank correlation\n\
\t              k : Kendalls tau\n\
\t-C (char)   : Specify the clustering method wanted for     \n\
\t              grouping voronoi vertices together           \n\
\t              s : single linkage clustering\n\
\t              m : complete linkage clustering\n\
\t              a : average linkage clustering (default)\n\
\t              c : centroid linkage clustering\n\
\nSee the manual (man fpocket), or the full documentation for\n\
more information.\n\
***************************\n" /**< the usage print content*/

/* --------------------------- PUBLIC STRUCTURES -----------------------------*/

/**
 Structure containing input and output params for mdpocket
 **/
typedef struct s_mdparams {
    char **fsnapshot; /**< path of the snapshot form of the structure */
    char fwantedpocket[M_MAX_PDB_NAME_LEN]; /**< path of the wanted pocket file*/
    char *traj_format; /**< format string designating the trajectory format*/
    char *topo_format; /**< format string designating the topology format*/
    char *f_pqr, /**< name of the pqr concatenated snapshot file*/
            *f_densdx, /**< name of the density dx grid file*/
            *f_freqdx, /**< name of the frequency dx grid file*/
            *f_densiso, /**< name of the density iso pdb file*/
            *f_freqiso, /**< name of the frequency iso pdb file*/
            *f_desc, /**< name of the descriptor file*/
            *f_ppdb, /**< name of the pocket pdb output file */
            *f_apdb, /**< name of the atoms pdb output file */
            *f_appdb, /**< name of the all atoms pdb output file */
            *f_traj, /**< name of the input trajectory file*/
            *f_topo, /**< name of the topology input file*/
            *f_elec, /**< name of the electrostatic grid output*/
            *f_vdw; /** name of the vdw grid output*/
            int nfiles; /**< number of files to analyse*/
    s_fparams *fpar; /**< fparams container*/
    int flag_scoring; /**< perform fpocket scoring on grid points instead of voronoi vertice counting*/
    int bfact_on_all; /**< flag, if 1, output all snapshots with surface coloured by bfactors*/
    float grid_origin[3]; /**< origin of the grid, either specified by the user in the input file or guessed by MDpocket*/
    float grid_spacing; /**< grid spacing in Angstroems*/
    short flag_MD; /**< 1 if working on MD trajectory formats, 0 if on PDB list*/
    unsigned short grid_extent[3]; /**< grid extent in number of grid points per dimension*/
} s_mdparams;

/* ----------------------------- PROTOTYPES --------------------------------- */

s_mdparams* init_def_mdparams(void);
s_mdparams* get_mdpocket_args(int nargs, char **args);

int add_list_snapshots(char *str_list_file, s_mdparams *par);
int add_snapshot(char *snapbuf, s_mdparams *par);

int grid_user_data_missing(s_mdparams *par);

void print_mdparams(s_mdparams *p, FILE *f);
void print_mdpocket_usage(FILE *f);
void free_mdparams(s_mdparams *p);

#endif
