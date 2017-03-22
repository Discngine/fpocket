
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

*/

#ifndef DH_DPOCKET
#define DH_DPOCKET

/* ----------------------------INCLUDES-------------------------------------- */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "fpocket.h"
#include "fpout.h"
#include "tpocket.h"
#include "dparams.h"
#include "descriptors.h"
#include "neighbor.h"
#include "pocket.h"
#include "cluster.h"
#include "refine.h"
#include "aa.h"
#include "utils.h"

#include "memhandler.h"

/* ----------------------------------MACROS----------------------------------*/

#define M_DP_EXPLICIT 1
#define M_DP_POCKET   2
#define M_DP_POCETLIG 3

#define M_DP_OUTP_HEADER "pdb lig overlap PP-crit PP-dst crit4 crit5 crit6 crit6_continue lig_vol pock_vol nb_AS nb_AS_norm mean_as_ray mean_as_solv_acc apol_as_prop apol_as_prop_norm mean_loc_hyd_dens mean_loc_hyd_dens_norm hydrophobicity_score volume_score polarity_score polarity_score_norm charge_score flex prop_polar_atm as_density as_density_norm as_max_dst as_max_dst_norm drug_score convex_hull_volume surf_pol_vdw14 surf_pol_vdw22 surf_apol_vdw14 surf_apol_vdw22 n_abpa"/**< header for the dpocket output*/
#define M_DP_OUTP_FORMAT "%s %s %6.2f %2d %6.2f %4.2f %4.2f %2d %5.2f %8.2f %10.2f %5d %4.2f %6.2f %6.2f %5.2f %4.2f %7.2f %4.2f %9.2f %7.2f %5d %5.2f %5d %6.2f %7.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5.2f %5d" /**< format for the dpocket output*/
#define M_DP_OUTP_VAR(fc, l, ovlp, status, dst, c4, c5, c6, c6_c, lv, d) fc, l, ovlp, status, dst, c4, c5, c6, c6_c, lv, \
                                          d->volume, \
                                          d->nb_asph, d->nas_norm,\
					  d->mean_asph_ray, \
					  d->masph_sacc, \
                                          d->apolar_asphere_prop, \
                                          d->prop_asapol_norm, \
					  d->mean_loc_hyd_dens, \
                                          d->mean_loc_hyd_dens_norm, \
                                          d->hydrophobicity_score, \
					  d->volume_score, \
                                          d->polarity_score, \
                                          d->polarity_score_norm, \
                                          d->charge_score, \
					  d->flex, \
                                          d->prop_polar_atm, \
                                          d->as_density, \
                                          d->as_density_norm, \
                                          d->as_max_dst, \
                                          d->as_max_dst_norm, \
                                          d->drug_score,\
                                          d->convex_hull_volume, \
                                          d->surf_pol_vdw14, \
                                          d->surf_pol_vdw22, \
                                          d->surf_apol_vdw14, \
                                          d->surf_apol_vdw22, \
                                          d->n_abpa 


/* ------------------------------PROTOTYPES-----------------------------------*/

void dpocket(s_dparams *par) ;
void desc_pocket(char fcomplexe[], const char ligname[], s_dparams *par, 
				 FILE *f[3]) ;

s_atm** get_explicit_desc(s_pdb *pdb_cplx_l, s_lst_vvertice *verts, s_atm **lig, 
						  int nal, s_dparams *par, int *nai, s_desc *desc) ;

void write_pocket_desc(const char fc[], const char l[], s_desc *d, float lv,
                       float ovlp, float dst, float c4, float c5, FILE *f) ;

#endif
