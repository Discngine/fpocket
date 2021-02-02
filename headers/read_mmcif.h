#ifndef DH_READ_MMCIF
#define DH_READ_MMCIF

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "atom.h"
#include "pertable.h"
#include "utils.h"
#include "memhandler.h"
#include "math.h"
#include "fparams.h"
#include "rpdb.h"


/* 
 * Plugin header files; get plugin source from www.ks.uiuc.edu/Research/vmd"
 */
#include "libmolfile_plugin.h"
#include "molfile_plugin.h"

s_pdb *open_mmcif(char *fpath, const char *ligan, const int keep_lig, int model_number, s_fparams *par);

void print_molfile_atom_t(molfile_atom_t *at_in, molfile_timestep_t ts_in, int inatoms);
void write_files(molfile_atom_t *at_in, molfile_timestep_t ts_in, int inatoms, int optflags, char *filetype);
void read_mmcif(s_pdb *pdb, const char *ligan, const int keep_lig, int model_number, s_fparams *params);
#endif