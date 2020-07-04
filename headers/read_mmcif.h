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

void open_mmcif(const char *filepath, const char *filetype, int natoms);

#endif