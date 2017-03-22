#
# AutoIMD Settings
#
# $Id: autoimd-settings.tcl,v 1.12 2006/02/02 20:43:42 saam Exp $
#
# Use this file to help yourself configure AutoIMD and specify on which servers
# to run your simulations.
# 
# Copy this file to your home directory and edit its contents. Make sure that
# it is sourced by VMD when VMD is loaded (i.e.: add "source <filename>") to
# your .vmdrc file
#
# Most AutoIMD variables will already have been set. You only need to override 
# the variables that you wish to change.
#

# Must activate AutoIMD before using it
package require autoimd

###############################################################################
### Customize the startup AutoIMD variables                                 
###############################################################################
#
# These will modify the default behavior of AutoIMD.
#
###############################################################################

# some variables should depend on the platform...

# the directory in which all the simulation-related files are stored
autoimd set scratchdir [file join $env(HOME) autoimd]

# space-separated list of all the CHARMM param files to be used 
package require readcharmmpar
autoimd set parfiles [list [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]]


# and some variables don't...

## initial text molten atom selection
#  autoimd set moltenseltext "atom selection"

## initial text fixed atom selection
#  autoimd set fixedseltext "atom selection"

## path to a NAMD template conf file (see "template.namd" example)
#  autoimd set namdtmplfile filename

## simulation temperature
#  autoimd set temperature 300

## timesteps to minimize
#  autoimd set minimizesteps 100

## DCD saving frequency (0 = no save)
#  autoimd set dcdfreq 0

## DCD saving frequency (0 = no save)
#  autoimd set vmdkeepfreq 0

## NAMD outputs coordinates to VMD every how many simulation steps? 
#  autoimd set namdoutputrate 2

## extra NAMD commands/parameters to be executed before running the simulation
#  autoimd set namdscript {print "Put NAMD commands here!"; print "And here!"}

## timesteps to run
#  autoimd set runsteps 1000000

## AutoIMD default graphical representations
#  set autoimd set imdrep {
#     mol representation Bonds 0.300000 6.000000
#     mol color Name
#     mol selection "imdprotein and noh"
#     mol material Opaque
#     mol addrep $imdmol
#
#     mol representation VDW 1.000000 8.000000
#     mol color ColorID 4
#     mol selection "imdhetero"
#     mol material Opaque
#     mol addrep $imdmol
#
#     mol representation Bonds 0.300000 6.000000
#     mol color Name
#     mol selection "imdwater"
#     mol material Opaque
#     mol addrep $imdmol
#   }
  


###############################################################################
### Add server configurations                                               
###############################################################################
#
# typing: "autoimd server add <servername> <array>" creates a new server type 
# A server here is just a description of the machines and means
# used to run the simulation (currently NAMD) that will be connected to VMD.
#
# NOTE: Since the server definitions are pairs of values, adding comments
# inside them will cause problems.
#
###############################################################################

# This line erases the default settings and lets you start anew.
# Uncomment it if you just want to merge your own servers to the default list.
autoimd clearservers

# EXAMPLE: Run sim on the local machine
autoimd addserver "Local" {
  jobtype  local
  namdbin  {/usr/local/bin/namd2 +p%d}
  maxprocs 1
  numprocs 1
  timeout  20
}


## EXAMPLE: Run on an example cluster via the DQS queue.
# autoimd addserver "DQS Clusters" {
#   jobtype  localdqs
#   dqsflags {-q beowulf_short}
#   namdbin  {/usr/local/bin/namd2 +netpoll +p%d}
#   maxprocs 48
#   numprocs 12
#   timeout  10
# }



# EXAMPLE: Do not run NAMD, just create the files
autoimd addserver "Create files" {
  jobtype none
}


# Set the default server configuration 
autoimd setserver "Local"
