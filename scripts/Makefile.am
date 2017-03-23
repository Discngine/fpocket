# Compiler and linkers:
CFLAGS = -Wall -O2 -Wextra -Wwrite-strings -Wstrict-prototypes
LDFLAGS = -fno-underscoring -lm
 
# Targets: bin means that programs will be installed in /usr/local/bin
# I guess the use of --prefix PATH when launching ./configure changes
# the prefix path from /usr/local to PATH
bin_PROGRAMS = fpocket tpocket dpocket
 
# Dependances
fpocket_SOURCES = ../src/fpmain.c ../src/psorting.c ../src/pscoring.c ../src/utils.c ../src/pertable.c ../src/memhandler.c ../src/voronoi.c ../src/sort.c ../src/calc.c ../src/writepdb.c ../src/rpdb.c ../src/tparams.c ../src/fparams.c ../src/pocket.c ../src/refine.c ../src/descriptors.c ../src/cluster.c ../src/aa.c ../src/fpocket.c ../src/write_visu.c  ../src/fpout.c ../src/atom.c ../src/writepocket.c ../src/voronoi_lst.c  ../headers/fpmain.h ../headers/psorting.h ../headers/pscoring.h ../headers/utils.h ../headers/pertable.h ../headers/memhandler.h ../headers/voronoi.h ../headers/sort.h ../headers/calc.h ../headers/writepdb.h ../headers/rpdb.h ../headers/tparams.h ../headers/fparams.h ../headers/pocket.h ../headers/refine.h ../headers/descriptors.h ../headers/cluster.h ../headers/aa.h ../headers/fpocket.h ../headers/write_visu.h  ../headers/fpout.h ../headers/atom.h ../headers/writepocket.h ../headers/voronoi_lst.h
 
tpocket_SOURCES = ../src/tpmain.c ../src/psorting.c ../src/pscoring.c ../src/utils.c ../src/pertable.c ../src/memhandler.c ../src/voronoi.c ../src/sort.c ../src/calc.c ../src/writepdb.c ../src/rpdb.c ../src/tparams.c ../src/fparams.c ../src/pocket.c ../src/refine.c ../src/tpocket.c  ../src/descriptors.c ../src/cluster.c ../src/aa.c ../src/fpocket.c ../src/write_visu.c ../src/fpout.c ../src/atom.c ../src/writepocket.c ../src/voronoi_lst.c ../src/neighbor.c ../headers/tpmain.h ../headers/psorting.h ../headers/pscoring.h ../headers/utils.h ../headers/pertable.h ../headers/memhandler.h ../headers/voronoi.h ../headers/sort.h ../headers/calc.h ../headers/writepdb.h ../headers/rpdb.h ../headers/tparams.h ../headers/fparams.h ../headers/pocket.h ../headers/refine.h ../headers/tpocket.h  ../headers/descriptors.h ../headers/cluster.h ../headers/aa.h ../headers/fpocket.h ../headers/write_visu.h ../headers/fpout.h ../headers/atom.h ../headers/writepocket.h ../headers/voronoi_lst.h ../headers/neighbor.h
 
dpocket_SOURCES =  ../src/dpmain.c ../src/psorting.c ../src/pscoring.c ../src/dpocket.c ../src/dparams.c  ../src/voronoi.c ../src/sort.c  ../src/rpdb.c ../src/descriptors.c ../src/neighbor.c ../src/atom.c ../src/aa.c ../src/pertable.c ../src/calc.c ../src/utils.c ../src/writepdb.c ../src/memhandler.c ../src/pocket.c ../src/refine.c ../src/cluster.c ../src/fparams.c ../src/voronoi_lst.c ../headers/dpmain.h ../headers/psorting.h ../headers/pscoring.h ../headers/dpocket.h ../headers/dparams.h  ../headers/voronoi.h ../headers/sort.h  ../headers/rpdb.h ../headers/descriptors.h ../headers/neighbor.h ../headers/atom.h ../headers/aa.h ../headers/pertable.h ../headers/calc.h ../headers/utils.h ../headers/writepdb.h ../headers/memhandler.h ../headers/pocket.h ../headers/refine.h ../headers/cluster.h ../headers/fparams.h ../headers/voronoi_lst.h


