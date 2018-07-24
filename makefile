#------------------------------------------------------------
# Makefile.
#------------------------------------------------------------
ARCH	    = LINUXAMD64

PLUGINDIR   = plugins

PATH_GSL    = /home/user/gsl/
PATH_OBJ    = obj/
PATH_SRC    = src/
PATH_HEADER = headers/
PATH_BIN    = bin/
PATH_MAN    = man/
PATH_QHULL  = src/qhull/src

BINDIR  = /usr/local/bin/
MANDIR  = /usr/local/man/man8/


FPOCKET     = fpocket
TPOCKET	    = tpocket
DPOCKET	    = dpocket
MDPOCKET    = mdpocket
CHECK	    = pcheck
MYPROGS	    = $(PATH_BIN)$(FPOCKET) $(PATH_BIN)$(TPOCKET) $(PATH_BIN)$(DPOCKET) $(PATH_BIN)$(MDPOCKET)

CC          = gcc
CCQHULL	    = gcc
LINKER      = gcc
LINKERQHULL = gcc

CGSL        = -DMD_NOT_USE_GSL -I$(PATH_GSL)include
COS         = -DM_OS_LINUX
CDEBUG      = -DMNO_MEM_DEBUG
CWARN       = -Wall -Wextra -Wwrite-strings -Wstrict-prototypes

CFLAGS      = $(CWARN) $(COS) $(CDEBUG) -O2 -g -pg -std=c99 -I$(PLUGINDIR)/include -I$(PLUGINDIR)/$(ARCH)/molfile #$(CGSL)
QCFLAGS     = -O -g -pg -ansi

LGSL        = -L$(PATH_GSL)lib -lgsl -lgslcblas 
LFLAGS	    = -lm -L$(PLUGINDIR)/$(ARCH)/molfile $(PLUGINDIR)/$(ARCH)/molfile/libmolfile_plugin.a -lnetcdf -lstdc++
#
#------------------------------------------------------------
# BINARIES OBJECTS 
#------------------------------------------------------------
#QOBJS = $(PATH_QHULL)/src/qvoronoi/qvoronoi.o $(PATH_QHULL)/src/qconvex/qconvex.o

QOBJS = $(PATH_QHULL)/libqhull/geom2.o $(PATH_QHULL)/libqhull/geom.o $(PATH_QHULL)/libqhull/global.o \
        $(PATH_QHULL)/libqhull/io.o $(PATH_QHULL)/libqhull/io.h $(PATH_QHULL)/libqhull/libqhull.o \
        $(PATH_QHULL)/libqhull/mem.o $(PATH_QHULL)/libqhull/merge.o $(PATH_QHULL)/libqhull/poly2.o \
        $(PATH_QHULL)/libqhull/poly.o $(PATH_QHULL)/libqhull/qset.o \
        $(PATH_QHULL)/libqhull/random.o $(PATH_QHULL)/libqhull/rboxlib.o \
        $(PATH_QHULL)/libqhull/stat.o $(PATH_QHULL)/libqhull/user.o \
        $(PATH_QHULL)/libqhull/usermem.o \
        $(PATH_QHULL)/libqhull/userprintf.o $(PATH_QHULL)/libqhull/userprintf_rbox.o $(PATH_QHULL)/qvoronoi/qvoronoi.o $(PATH_QHULL)/qconvex/qconvex.o

CHOBJ = $(PATH_OBJ)check.o $(PATH_OBJ)psorting.o $(PATH_OBJ)pscoring.o \
		$(PATH_OBJ)utils.o $(PATH_OBJ)pertable.o $(PATH_OBJ)memhandler.o \
		$(PATH_OBJ)voronoi.o $(PATH_OBJ)sort.o $(PATH_OBJ)calc.o \
		$(PATH_OBJ)writepdb.o $(PATH_OBJ)rpdb.o $(PATH_OBJ)tparams.o \
		$(PATH_OBJ)fparams.o $(PATH_OBJ)pocket.o $(PATH_OBJ)refine.o \
		$(PATH_OBJ)descriptors.o $(PATH_OBJ)aa.o \
		$(PATH_OBJ)fpocket.o $(PATH_OBJ)write_visu.o  $(PATH_OBJ)fpout.o \
		$(PATH_OBJ)atom.o $(PATH_OBJ)writepocket.o $(PATH_OBJ)voronoi_lst.o \
		$(PATH_OBJ)neighbor.o $(PATH_OBJ)asa.o $(PATH_OBJ)clusterlib.o $(PATH_OBJ)energy.o \
		

FPOBJ = $(PATH_OBJ)fpmain.o $(PATH_OBJ)psorting.o $(PATH_OBJ)pscoring.o \
		$(PATH_OBJ)utils.o $(PATH_OBJ)pertable.o $(PATH_OBJ)memhandler.o \
		$(PATH_OBJ)voronoi.o $(PATH_OBJ)sort.o $(PATH_OBJ)calc.o \
		$(PATH_OBJ)writepdb.o $(PATH_OBJ)rpdb.o $(PATH_OBJ)tparams.o \
		$(PATH_OBJ)fparams.o $(PATH_OBJ)pocket.o $(PATH_OBJ)refine.o \
		$(PATH_OBJ)descriptors.o $(PATH_OBJ)aa.o \
		$(PATH_OBJ)fpocket.o $(PATH_OBJ)write_visu.o  $(PATH_OBJ)fpout.o \
		$(PATH_OBJ)atom.o $(PATH_OBJ)writepocket.o $(PATH_OBJ)voronoi_lst.o $(PATH_OBJ)asa.o \
		$(PATH_OBJ)clusterlib.o $(PATH_OBJ)energy.o $(PATH_OBJ)topology.o  \
		$(QOBJS)

TPOBJ = $(PATH_OBJ)tpmain.o $(PATH_OBJ)psorting.o $(PATH_OBJ)pscoring.o \
		$(PATH_OBJ)utils.o $(PATH_OBJ)pertable.o $(PATH_OBJ)memhandler.o \
		$(PATH_OBJ)voronoi.o $(PATH_OBJ)sort.o $(PATH_OBJ)calc.o \
		$(PATH_OBJ)writepdb.o $(PATH_OBJ)rpdb.o $(PATH_OBJ)tparams.o \
		$(PATH_OBJ)fparams.o $(PATH_OBJ)pocket.o $(PATH_OBJ)refine.o \
		$(PATH_OBJ)tpocket.o  $(PATH_OBJ)descriptors.o \
		$(PATH_OBJ)aa.o $(PATH_OBJ)fpocket.o $(PATH_OBJ)write_visu.o \
		$(PATH_OBJ)fpout.o $(PATH_OBJ)atom.o $(PATH_OBJ)writepocket.o \
		$(PATH_OBJ)voronoi_lst.o $(PATH_OBJ)neighbor.o $(PATH_OBJ)asa.o\
		$(PATH_OBJ)clusterlib.o  $(PATH_OBJ)energy.o $(PATH_OBJ)topology.o\
		$(PATH_QHULL)/qvoronoi/qvoronoi.o $(PATH_QHULL)/qconvex/qconvex.o

DPOBJ = $(PATH_OBJ)dpmain.o $(PATH_OBJ)psorting.o $(PATH_OBJ)pscoring.o \
		$(PATH_OBJ)dpocket.o $(PATH_OBJ)dparams.o  $(PATH_OBJ)voronoi.o \
		$(PATH_OBJ)sort.o  $(PATH_OBJ)rpdb.o $(PATH_OBJ)descriptors.o \
		$(PATH_OBJ)neighbor.o $(PATH_OBJ)atom.o $(PATH_OBJ)aa.o \
		$(PATH_OBJ)pertable.o $(PATH_OBJ)calc.o $(PATH_OBJ)utils.o \
		$(PATH_OBJ)writepdb.o $(PATH_OBJ)memhandler.o $(PATH_OBJ)pocket.o \
		$(PATH_OBJ)refine.o $(PATH_OBJ)fparams.o \
		$(PATH_OBJ)fpocket.o $(PATH_OBJ)fpout.o $(PATH_OBJ)writepocket.o \
		$(PATH_OBJ)write_visu.o $(PATH_OBJ)asa.o\
		$(PATH_OBJ)voronoi_lst.o $(PATH_OBJ)clusterlib.o $(QOBJS) $(PATH_OBJ)energy.o \
		$(PATH_OBJ)topology.o

MDPOBJ = $(PATH_OBJ)mdpmain.o $(PATH_OBJ)mdpocket.o $(PATH_OBJ)mdpbase.o $(PATH_OBJ)mdpout.o $(PATH_OBJ)psorting.o $(PATH_OBJ)pscoring.o \
		$(PATH_OBJ)mdparams.o $(PATH_OBJ)voronoi.o \
		$(PATH_OBJ)sort.o  $(PATH_OBJ)rpdb.o $(PATH_OBJ)descriptors.o \
		$(PATH_OBJ)neighbor.o $(PATH_OBJ)atom.o $(PATH_OBJ)aa.o \
		$(PATH_OBJ)pertable.o $(PATH_OBJ)calc.o $(PATH_OBJ)utils.o \
		$(PATH_OBJ)writepdb.o $(PATH_OBJ)memhandler.o $(PATH_OBJ)pocket.o \
		$(PATH_OBJ)refine.o $(PATH_OBJ)fparams.o \
		$(PATH_OBJ)fpocket.o $(PATH_OBJ)fpout.o \
		$(PATH_OBJ)writepocket.o $(PATH_OBJ)write_visu.o $(PATH_OBJ)asa.o \
		$(PATH_OBJ)voronoi_lst.o $(PATH_OBJ)clusterlib.o $(QOBJS) $(PATH_OBJ)energy.o $(PATH_OBJ)topology.o

#------------------------------------------------------------
# GENERAL RULES FOR COMPILATION
#------------------------------------------------------------

$(PATH_QHULL)%.o: $(PATH_QHULL)%.c
	$(CCQHULL) $(QCFLAGS) -c $< -o $@

$(PATH_OBJ)%.o: $(PATH_SRC)%.c
	$(CC) $(CFLAGS) -c $< -o $@
	
$(PATH_OBJ)%.o: $(PATH_SRC)%.cpp
	$(CC) $(CFLAGS) -c $< -o $@
		
#-----------------------------------------------------------
# RULES FOR EXECUTABLES
#-----------------------------------------------------------

all: 
	make qhull
	make fpocket
fpocket: $(MYPROGS) # $(PATH_BIN)$(CHECK)

qhull:
	cd src/qhull/ && make -j 12

$(PATH_BIN)$(CHECK): $(CHOBJ) $(QOBJS)
	$(LINKER) $^ -o $@ $(LFLAGS)

$(PATH_BIN)$(FPOCKET): $(FPOBJ) $(QOBJS)
	$(LINKER) $^ -o $@ $(LFLAGS)

$(PATH_BIN)$(TPOCKET): $(TPOBJ) $(QOBJS)
	$(LINKER) $^ -o $@ $(LFLAGS)

$(PATH_BIN)$(DPOCKET): $(DPOBJ) $(QOBJS)
	$(LINKER) $^ -o $@ $(LFLAGS)

$(PATH_BIN)$(MDPOCKET): $(MDPOBJ) $(QOBJS)
	$(LINKER) $^ -o $@ $(LFLAGS)

install:
	mkdir -p $(BINDIR)
	mkdir -p $(MANDIR)
	cp $(PATH_BIN)$(FPOCKET) $(BINDIR)
	cp $(PATH_BIN)$(TPOCKET) $(BINDIR)
	cp $(PATH_BIN)$(DPOCKET) $(BINDIR)
	cp $(PATH_BIN)$(MDPOCKET) $(BINDIR)
	cp $(PATH_MAN)* $(MANDIR)

check:
	./$(PATH_BIN)$(CHECK)
		
test:
	./$(PATH_BIN)$(CHECK)

clean:
	rm -f $(PATH_QHULL)*.o
	rm -f $(PATH_OBJ)*.o
	rm -f $(PATH_BIN)$(FPOCKET)
	rm -f $(PATH_BIN)$(TPOCKET)
	rm -f $(PATH_BIN)$(DPOCKET)
	rm -f $(PATH_BIN)$(MDPOCKET)
	cd src/qhull && make clean

uninstall:
	rm -f $(PATH_BIN)$(FPOCKET) $(BINDIR)$(FPOCKET)
	rm -f $(PATH_BIN)$(TPOCKET) $(BINDIR)$(TPOCKET)
	rm -f $(PATH_BIN)$(DPOCKET) $(BINDIR)$(DPOCKET)
	rm -f $(PATH_BIN)$(MDPOCKET) $(BINDIR)$(MDPOCKET)
	rm -f $(MANDIR)fpocket.8 $(MANDIR)tpocket.8 $(MANDIR)dpocket.8
	
