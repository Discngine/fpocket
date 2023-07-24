/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

#ifndef DH_FPARAMS
#define DH_FPARAMS

/* ------------------------------- INCLUDES ----------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <assert.h>
#include <getopt.h>

#include "utils.h"
#include "memhandler.h"

/* ----------------------------- PUBLIC MACROS ------------------------------ */

/* Options of the pocket finder program */
/* standard parameters */

#define M_MIN_ASHAPE_SIZE_DEFAULT 3.4 /**< Use min alpha sphere radius of : 3.0 */ /*3.2, 2.6, */

#define M_MAX_ASHAPE_SIZE_DEFAULT 6.2 /**< Use max alpha sphere radius of : 6.0 */ /*7.0, 7.4, */

#define M_CLUST_MAX_DIST 2.4 /**< Use first connection distance (see report) : 2.0 */ /*1.8, 11.2, */

#define M_REFINE_DIST 4.5 /**< use second connection distance (see report) : 4.5 */

#define M_REFINE_MIN_PROP_APOL_AS 0.0 /**< At least a proportion of  M_REFINE_MIN_NAPOL_AS apolar alpha spheres in the pocket 0.0 */

#define M_MC_ITER 300 /**< Number of iterations for the Monte Carlo volume calculation 3000 */

#define M_BASIC_VOL_DIVISION -1 /**< Precision for "exact" volume integration, set to -1 if not used -1 */

#define M_MIN_POCK_NB_ASPH 15 /**< Minimum number of alpha spheres for a pocket to be kept */

#define M_MIN_APOL_NEIGH_DEFAULT 3 /**< Minimum number of atoms having a low electronegativity in order to declare an alpha sphere to be apolar 3 */

#define M_DISTANCE_MEASURE 'e' /**< By default use euclidean distance measure for clustering*/

#define M_CLUSTERING_METHOD 's' /**< Clustering method to be used for alpha sphere clustering*/ /*s*/

#define M_DB_RUN 0 /**< default value for running fpocket for populating a database, 0 default*/

#define M_MAX_CHAINS_DELETE 20

#define M_MIN_AS_DENSITY 0.7

#define M_MIN_N_EXPLICIT_POCKET 4 /**default value for minimum number of atoms part of the explicit pocket for an alpha sphere (between 0 and 4)*/

#define M_PAR_PDB_FILE 'f'		   /**< flag to give a single pdb input file*/
#define M_PAR_LONG_PDB_FILE "file" /**< flag to give a single pdb input file*/

#define M_PAR_PDB_LIST 'F'			   /**< flag to give a txt file containing paths to multiple pdb files*/
#define M_PAR_LONG_PDB_LIST "fileList" /**< flag to give a txt file containing paths to multiple pdb files*/

#define M_PAR_MAX_ASHAPE_SIZE 'M'					/**< flag for the maximum alpha sphere size*/
#define M_PAR_LONG_MAX_ASHAPE_SIZE "max_alpha_size" /**< flag for the maximum alpha sphere size*/

#define M_PAR_MIN_ASHAPE_SIZE 'm'					/**< flag for the minimum alpha sphere size*/
#define M_PAR_LONG_MIN_ASHAPE_SIZE "min_alpha_size" /**< flag for the minimum alpha sphere size*/

#define M_PAR_MIN_APOL_NEIGH 'A'							/**< flag for the minimum number of apolar neighbours for an alpha sphere to be considered as apolar*/
#define M_PAR_LONG_MIN_APOL_NEIGH "number_apol_asph_pocket" /**< flag for the minimum number of apolar neighbours for an alpha sphere to be considered as apolar*/

#define M_PAR_CLUST_MAX_DIST 'D'						/**< flag for clustering distance*/
#define M_PAR_LONG_CLUST_MAX_DIST "clustering_distance" /**< flag for clustering distance*/

#define M_PAR_MC_ITER 'v'						  /**< flag for how many iterations for the monte carlo volume calculation algorithm*/
#define M_PAR_LONG_MC_ITER "iterations_volume_mc" /**< flag for how many iterations for the monte carlo volume calculation algorithm*/

#define M_PAR_BASIC_VOL_DIVISION 'b'						 /**< flag for the space approximation of the MC*/
#define M_PAR_MIN_POCK_NB_ASPH 'i'							 /**< flag for the min number of alpha spheres in the pocket*/
#define M_PAR_LONG_MIN_POCK_NB_ASPH "min_spheres_per_pocket" /**< flag for the min number of alpha spheres in the pocket*/

#define M_PAR_REFINE_MIN_NAPOL_AS 'p'							   /**< flag for minimum proportion of apolar alpha spheres*/
#define M_PAR_LONG_REFINE_MIN_NAPOL_AS "ratio_apol_spheres_pocket" /**< flag for minimum proportion of apolar alpha spheres*/

#define M_PAR_DB_RUN 'd'						/**<flag for running fpocket as database run, more silent and special output is produced for automatic grabbing of results using other programs*/
#define M_PAR_LONG_DB_RUN "pocket_descr_stdout" /**<flag for running fpocket as database run, more silent and special output is produced for automatic grabbing of results using other programs*/

#define M_PAR_CLUSTERING_METHOD 'C'						 /**<flag for specifying the clustering method to use for alpha sphere clustering*/
#define M_PAR_LONG_CLUSTERING_METHOD "clustering_method" /**<flag for specifying the clustering method to use for alpha sphere clustering*/

#define M_PAR_DISTANCE_MEASURE 'e'						 /**<flag for specifying the distance measure*/
#define M_PAR_LONG_DISTANCE_MEASURE "clustering_measure" /**<flag for specifying the distance measure*/

#define M_PAR_GRID_CALCULATION 'x'								  /**<flag for specifying the distance measure*/
#define M_PAR_LONG_GRID_CALCULATION "calculate_interaction_grids" /**<flag for specifying the distance measure*/

#define M_PAR_TOPOLOGY 'y'					/**<flag for specifying a molecular topology suitable for FF calculations*/
#define M_PAR_LONG_TOPOLOGY "topology_file" /**<flag for specifying a molecular topology suitable for FF calculations*/

#define M_PAR_MODEL_FLAG 'l'				 /**<flag for analyzing a specific model in multimodel structures*/
#define M_PAR_MODEL_FLAG_LONG "model_number" /**<flag for anamyzing a specific model in multimodel structures*/

#define M_PAR_CUSTOM_LIGAND 'r' /**flag, to define detection of explicit pockets around the specified ligand*/
#define M_PAR_CUSTOM_LIGAND_LONG "custom_ligand"

#define M_PAR_CUSTOM_POCKET 'P' /** flag to define a specific location to calculate the binding site on*/
#define M_PAR_CUSTOM_POCKET_LONG "custom_pocket"

#define M_PAR_DROP_CHAINS 'c' /**flag, to define which chain are dropped before the pocket detection*/
#define M_PAR_DROP_CHAINS_LONG "drop_chains"

#define M_PAR_KEEP_CHAINS 'k' /**flag, to define which chains are kept before the pocket detection*/
#define M_PAR_KEEP_CHAINS_LONG "keep_chains"

#define M_PAR_CHAIN_AS_LIGAND 'a' /**flag, to define which chains are defined as a ligand*/
#define M_PAR_CHAIN_AS_LIGAND_LONG "chain_as_ligand"

#define M_PAR_WRITE_MODE 'w' /**flag, to define which chains are defined as a ligand*/
#define M_PAR_WRITE_MODE_LONG "write_mode"

#define M_PAR_MIN_N_EXPLICIT_POCKET 'u'
#define M_PAR_MIN_N_EXPLICIT_POCKET_LONG "min_n_explicit_pocket"

#define M_FP_USAGE "\n\
***** USAGE (fpocket) *****\n\
\n\
Pocket finding on a pdb - list of pdb - file(s):             \n\
\tfpocket -%s --%s pdbFile                                       \n\
\tfpocket -%s --%s fileList                                  \n\
\nOPTIONS (find standard parameters in brackets)           \n\n\
\t-m (float)  : Minimum radius of an alpha-sphere.      (3.0)\n\
\t-M (float)  : Maximum radius of an alpha-sphere.      (6.0)\n\
\t-A (int)    : Minimum number of apolar neighbor for        \n\
\t              an a-sphere to be considered as apolar.   (3)\n\
\t-i (int)    : Minimum number of a-sphere per pocket.   (30)\n\
\t-D (float)  : Distance threshold for clustering algorithm  \n\
\t-p (float)  : Minimum proportion of apolar sphere in       \n\
\t              a pocket (remove otherwise)             (0.0)\n\
\t-x          : Specify this flag if you want fpocket to     \n\
\t              calculate VdW and Coulomb grids for each pocket\n\
\t-v (integer): Number of Monte-Carlo iteration for the      \n\
\t              calculation of each pocket volume.     (2500)\n\
\t-b (integer): Space approximation for the basic method     \n\
\t              of the volume calculation. Not used by       \n\
\t              default (Monte Carlo approximation is)       \n\
\t-d flag     : Put this flag if you want to run fpocket for \n\
\t              database creation                            \n\
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
\t              s : single linkage clustering(default)\n\
\t              m : complete linkage clustering\n\
\t              a : average linkage clustering \n\
\t              c : centroid linkage clustering\n\
\nSee the manual (man fpocket), or the full documentation for\n\
more information.\n\
***************************\n", \
				   M_PAR_PDB_FILE, M_PAR_LONG_PDB_FILE, M_PAR_PDB_LIST, M_PAR_LONG_PDB_LIST /**< the usage print content*/

/* --------------------------- PUBLIC STRUCTURES ---------------------------- */
/**
	Structure containing all necessary parameters that can be changed by the user.
	This structure is commun to both programs (validation and pocket finding),
	even if the pocked finding programm doesn't need some parameters.
*/
typedef struct s_fparams
{
	char pdb_path[M_MAX_PDB_NAME_LEN];		/**< The pdb file */
	char topology_path[M_MAX_PDB_NAME_LEN]; /**< a putative topology file*/
	char custom_ligand[M_MAX_PDB_NAME_LEN]; /**container for custom pocket detection using a particular ligand*/
	char custom_pocket_arg[M_MAX_CUSTOM_POCKET_LEN];
	char **pdb_lst;
	char xlig_chain_code[3];
	char xlig_resname[3];
	int xlig_resnumber;
	int xpocket_n; /**number of residues defining the pocket to consider*/
	char *xpocket_chain_code;
	char *xpocket_insertion_code;
	unsigned short *xpocket_residue_number;
	char distance_measure;
	char clustering_method;
	int min_n_explicit_pocket_atoms; /**Minimum numer of atoms in contact with an alpha sphere part of the explicitly defined pocket in order to be considered as valid*/
	int npdb;						 /**< number of pdb files*/
	short fpocket_running;
	int flag_do_asa_and_volume_calculations;  /**<if 1, asa and volume calculations are performed(slower), if 0, not*/
	int db_run;								  /**< flag for running fpocket for db population*/
	int model_number;						  /**<number of model to be analyzed>*/
	unsigned short flag_do_grid_calculations; /**< if 1 do grid calculations and output these*/
	int min_apol_neigh,						  /**< Min number of apolar neighbours for an a-sphere
												 to be an apolar a-sphere */
		nb_mcv_iter,						  /**< Number of iteration for the Monte Carlo volume
												 calculation */
		basic_volume_div,					  /**< Box division factor for basic volume calculation */
		min_pock_nb_asph;					  /**< Minimump number of alpha spheres per pocket */

	float clust_max_dist,				/**< First clustering distance criteria */
		refine_min_apolar_asphere_prop, /**< Min proportion of apolar alpha
										spheres for each pocket */

		asph_min_size,						/**< Minimum size of alpha spheres to keep */
		min_as_density,						/**<Minimum alpha sphere density for a pocket to be retained*/
		asph_max_size;						/**< Maximum size of alpha spheres to keep */
	char chain_delete[M_MAX_CHAINS_DELETE]; /*chosen chain to delete before calculation*/
	char chain_as_ligand[M_MAX_CHAINS_DELETE];
	int chain_is_kept;	/* To choose if we keep the chains or not*/
	char write_par[10]; /*write mode : d -> default | b -> both pdb and mmcif | p ->pdb | m  -> mmcif*/

} s_fparams;

/* ------------------------------- PROTOTYPES ------------------------------- */

s_fparams *init_def_fparams(void);
s_fparams *get_fpocket_args(int nargs, char **args);

int parse_clust_max_dist(char *str, s_fparams *p);
int parse_clustering_method(char *str, s_fparams *p);

int parse_sclust_min_nneigh(char *str, s_fparams *p);
int parse_min_apol_neigh(char *str, s_fparams *p);
int parse_asph_min_size(char *str, s_fparams *p);
int parse_asph_max_size(char *str, s_fparams *p);
int parse_mc_niter(char *str, s_fparams *p);
int parse_basic_vol_div(char *str, s_fparams *p);
int parse_refine_dist(char *str, s_fparams *p);
int parse_distance_measure(char *str, s_fparams *p);
int parse_refine_minaap(char *str, s_fparams *p);
int parse_min_pock_nb_asph(char *str, s_fparams *p);

int is_fpocket_opt(const char opt);

void free_fparams(s_fparams *p);
void print_pocket_usage(FILE *f);
void print_fparams(s_fparams *p, FILE *f);

#endif
