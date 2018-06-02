/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
