/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */

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
