/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
