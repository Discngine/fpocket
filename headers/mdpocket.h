
/*
    COPYRIGHT

    Peter Schmidtke, hereby
	claims all copyright interest in the program “mdpocket” (which
	performs protein cavity detection on multiple conformations of proteins) 
        written by Peter Schmidtke.

    Peter Schmidtke      01 Decembre 2012

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

#ifndef DH_MDPOCKET
#define DH_MDPOCKET

/* ----------------------------INCLUDES-------------------------------------- */

#include <math.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "fpocket.h"
#include "fpout.h"
#include "atom.h"
#include "writepocket.h"
#include "tpocket.h"
#include "dparams.h"
#include "descriptors.h"
#include "neighbor.h"
#include "pocket.h"
#include "cluster.h"
#include "refine.h"
#include "aa.h"
#include "rpdb.h"
#include "utils.h"
#include "calc.h"
#include "mdparams.h"
#include "mdpbase.h"
#include "memhandler.h"
#include "mdpout.h"
#include "topology.h"

/* 
 * Plugin header files; get plugin source from www.ks.uiuc.edu/Research/vmd"
 */
#include "libmolfile_plugin.h"
#include "molfile_plugin.h"

/* ---------------------------------MACROS----------------------------------*/
#define M_MDP_OUTP_HEADER "snapshot pock_volume pock_asa pock_pol_asa pock_apol_asa pock_asa22 pock_pol_asa22 pock_apol_asa22 nb_AS mean_as_ray mean_as_solv_acc apol_as_prop mean_loc_hyd_dens hydrophobicity_score volume_score polarity_score charge_score prop_polar_atm as_density as_max_dst convex_hull_volume nb_abpa" /**< header for the dpocket output*/
#define M_MDP_OUTP_FORMAT "%d %4.2f %4.2f %4.2f %4.2f %4.2f %4.2f %4.2f %d %4.2f %4.2f %4.2f %4.2f %4.2f %4.2f %d %d %4.2f %4.2f %4.2f %4.2f %d" /**< format for the dpocket output*/
#define M_MDP_OUTP_VAR(i, d) i, d->volume, \
                              d->surf_vdw14, \
                              d->surf_pol_vdw14, \
                              d->surf_apol_vdw14, \
                              d->surf_vdw22, \
                              d->surf_pol_vdw22, \
                              d->surf_apol_vdw22, \
                              d->nb_asph,\
                              d->mean_asph_ray, \
                              d->masph_sacc, \
                              d->apolar_asphere_prop, \
                              d->mean_loc_hyd_dens, \
                              d->hydrophobicity_score, \
                              d->volume_score, \
                              d->polarity_score, \
                              d->charge_score, \
                              d->prop_polar_atm, \
                              d->as_density, \
                              d->as_max_dst, \
                              d->convex_hull_volume, \
                              d->n_abpa/**< list of descriptors to output in the dpocket output*/

/* -------------------------------PROTOTYPES--------------------------------*/
void mdpocket_detect(s_mdparams *par) ;
c_lst_pockets* mdprocess_pdb(s_pdb *pdb, s_mdparams *mdparams, int snnumber);

void mdpocket_characterize(s_mdparams *par) ;
s_pocket* extract_wanted_vertices(c_lst_pockets *pockets,s_pdb *pdb);
s_pdb *open_pdb_file(char *pdbname,s_mdparams *mdparams);
void write_md_descriptors(FILE *f, s_pocket *p, int i);
int *get_wanted_atom_ids(s_pdb *prot,s_pdb *pocket, int *n);

#endif
