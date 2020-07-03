#ifndef DH_READ_MMCIF
#define DH_READ_MMCIF


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

void open_mmcif(const char *filepath, const char *filetype, int natoms);

#endif