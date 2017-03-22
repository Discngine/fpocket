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

#ifndef DH_TPOCKET
#define DH_TPOCKET

/* -----------------------------INCLUDES--------------------------------------*/

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "tparams.h"
#include "neighbor.h"
#include "fpocket.h"
#include "fpout.h"

#include "memhandler.h"

/* --------------------------------MACROS-------------------------------------*/
#define M_CRIT1_D 3.0
#define M_CRIT2_D 3.0
#define M_CRIT4_D 3.0
#define M_CRIT5_D 3.0

#define M_CRIT1_VAL 50.0
#define M_CRIT2_VAL 50.0
#define M_CRIT3_VAL 4.0 /*was 0.05 before*/
#define M_CRIT4_VAL 0.5
#define M_CRIT5_VAL 0.20

/* A set of index, giving the position of each value in the tab used to
 * store them. In the src file, those statistics values are stored in a tab
 * using indices given here.
 **/
#define M_NDDATA 16		/**< Number of floating values */
#define M_MAXPCT1 0		/**< Maximum observed overlap for the criteria 1 */
#define M_MAXPCT2 1		/**< Maximum observed overlap for the criteria 2 */
#define M_MINDST 2		/**< Minimum distance observed (barycenter/ligand), crit 3 */
#define M_CRIT4 3		/**< Minimum distance observed (barycenter/ligand), crit 4 */
#define M_CRIT5 4		/**< Minimum distance observed (barycenter/ligand), crit 5 */
#define M_CRIT6 5		/**< Minimum distance observed (barycenter/ligand), crit 5 */
#define M_OREL1 6		/**< Relative overlap of the pocket found for criteria 1 */
#define M_OREL2 7		/**< Relative overlap of the pocket found for criteria 2 */
#define M_OREL3 8		/**< Relative overlap of the pocket found for criteria 3 */
#define M_OREL4 9		/**< Relative overlap of the pocket found for criteria 3 */
#define M_OREL5 10		/**< Relative overlap of the pocket found for criteria 3 */
#define M_OREL6 11		/**< Relative overlap of the pocket found for criteria 3 */
#define M_LIGMASS 12		/**< Mass of the ligand */
#define M_LIGVOL 13		/**< Volume of the ligand */
#define M_POCKETVOL_C3 14       /**< Volume of the pocket found by the 1st criteria*/
#define M_POCKETVOL_C6 15       /**< Volume of the pocket found by the 6th criteria*/

#define M_NIDATA 9		/**< Number of interger values */
#define M_NPOCKET 0		/**< Total number of pocket found */
#define M_POS1 1		/**< Rank of the right pocket for the 1st criteria */
#define M_POS2 2		/**< Rank of the right pocket for the 2nd criteria */
#define M_POS3 3		/**< Rank of the right pocket for the 3rd criteria */
#define M_POS4 4		/**< Rank of the right pocket for the 4th criteria */
#define M_POS5 5		/**< Rank of the right pocket for the 5th criteria */
#define M_POS6 6		/**< Rank of the right pocket for the 6th criteria */
#define M_NATM3 7		/**< Rank of the right pocket for the 5th criteria */
#define M_NATM6 8		/**< Rank of the right pocket for the 6th criteria */

#define M_LIGNOTFOUND -2 /**< Flags used for the pocket detection */
#define M_PDBOPENFAILED -1 /**< Flags used for the pocket detection */
#define M_OK 0  /**< Flags used for the pocket detection */
#define M_NOPOCKETFOUND 1 /**< Flags used for the pocket detection */

/* ------------------------------SRUCTURES------------------------------------*/

/* -----------------------------PROTOTYPES------------------------------------*/

void test_fpocket(s_tparams *par) ;
int test_set(s_tparams *par, int i, float ddata [][M_NDDATA], int idata [][M_NIDATA]) ;

void check_pockets(c_lst_pockets *pockets, s_atm **accpck, int naccpck, s_atm **lig, 
				   int nalig, s_atm **alneigh, int nlneigh, 
				   float ddata [][M_NDDATA], int idata [][M_NIDATA], int i) ;

s_atm** get_actual_pocket(s_pdb *com_pdb, s_pdb *com_pdb_nolig, int i, s_tparams *par, int *nb_atm) ;
s_atm** get_actual_pocket_DEPRECATED(s_pdb *com_pdb, float lig_dist_crit, int *nb_atm) ;

float set_overlap_volumes(s_pocket *pocket, s_atm **lig, int natoms, float lig_vol, s_fparams *params) ;
float set_mc_overlap_volume(s_atm **lig, int natoms, float lig_vol,s_pocket *pocket, int niter) ;
float set_basic_overlap_volume(s_atm **lig, int natoms, float lig_vol,s_pocket *pocket, int idiscret) ;

/*void write_tpocket(c_lst_pockets *pockets, s_pdb *pdb, const char base_pdb_name[]) ;*/
void write_pockets_stats(c_lst_pockets *pockets, const char base_pdb_name[]);


#endif
