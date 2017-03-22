# cgnetworking is a tcl version of Anton Arkhipov's C++ code.
#
#  Sample invocation
#   
#   package require cgnetworking 0.1
#   
#   mol new /Projects/anton/ReducedModels/networking/Flagellum/bonded_interactions/full_charge/input/flag_ref.pdb
#   mol addfile /Projects/anton/ReducedModels/networking/Flagellum/bonded_interactions/full_charge/input/flag.psf
#   
#   proc printStatus { logText } {
#      puts "Log: $logText"
#   }
#   
#   # call for flagellum
#   ::cgnetworking::networkCGMolecule printStatus 0 "FUP" "A" \
#          "out.pdb" "out-allAtom.pdb" "out.top" "out.par" \
#          15 3000 0.3 0.05 \
#          3.0 0.01 25 
#   
#   

# TODO:
#  * continue conversion from 1-based array numbering to 0-based
#  * getting a divide by zero error in the file writing if more than one
#    bead has no atoms assigned to it.  Seems to make it past the all
#    atom writing.  For real systems this shouldn't happen very often, but
#    it still needs tracked down.

# Version History
#   0.3 - pass in bondCutMethod to toNetworkingCG so that the user
#         can use the bond connectivity information from the all-atom model

package provide cgnetworking 0.3

namespace eval ::cgnetworking:: {

#  variable idxarray
#  variable startposarray
#  variable massarray
   namespace export networkCGMolecule

}

#
# networkCGMolecule  Main procedure for CGing a molecule
#
# Inputs:
#   statusProc - Name of tcl procedure that expects a single string
#                as an argument (see example above).  All status information
#                will be sent to this procedure, which can deal with it
#                as desired.
#   inMolId - Molecule number (or name, such as 'top') in VMD that we want
#             to have coarse grained.  This molecule needs to contain the
#             contents of both a PDB and PSF
#   cgResName - desired name of the CG residue.  Needs to be <= 3 letters.
#   cgPrefix - 1 letter prefix for the CG atom names and types.  If given
#              'A', atom names will be A1, A2, etc. 
#   outPDB - Destination filename for the CG'd PDB file
#   outAllAtom - Destination filename for the reference all atom PDB file
#                that contains information about which CG atom each of the
#                all-atom atoms corresponds to
#   outTop - Destination filename for the CG'd Topology file
#   outParm - Destination filename for the CG'd Parameter file
#   numBeads - Desired number of beads that we want
#   numSteps - Number of steps to use for learning the best positions
#              for the beads.  Example:  200 * numBeads
#   epsInit - Initial value for epsilon
#   epsFinal - Final value for epsilon
#   lambdaInit - Initial value for lambda
#   lambdaFinal - Final value for lambda
#   bondCutMethod - 0 to use backbone connectivity of all-atom model.  
#                   1 to use user-specified cutoff distance
#   bondCutDist - cut-off distance for bonds between beads (in angstroms)
#   massValue - user defined value for the total mass of the CG model.
#               If a negative number, this isn't used, and the values
#               that VMD knows about are used.  (typically for all atom
#               you will just want to use the masses of the atoms to
#               determine the total mass of the system, but for electron
#               density maps, this information isn't available, and can
#               be provided via this value)
#
proc ::cgnetworking::networkCGMolecule { statusProc inMolId cgResName \
                                      cgPrefix \
                                      outPDB outAllAtom outTop outParm \
                                      numBeads numSteps epsInit epsFinal \
                                      lambdaInit lambdaFinal \
                                      bondCutMethod bondCutDist \
                                      massValue} {

   set sel [atomselect $inMolId "all"]
   set numAtoms [$sel num]
   
   set a_x [concat {0} [$sel get x]]
   set a_y [concat {0} [$sel get y]]
   set a_z [concat {0} [$sel get z]]
   set a_m [concat {0} [$sel get mass]]
   set a_c [concat {0} [$sel get charge]]

   $sel delete

   ::cgnetworking::toNetworkingCG $statusProc $inMolId $cgResName \
                     $cgPrefix $outPDB $outAllAtom $outTop $outParm \
                     $numBeads $numSteps $epsInit $epsFinal \
                     $lambdaInit $lambdaFinal $bondCutMethod $bondCutDist \
                     $numAtoms $a_x $a_y $a_z $a_m $a_c $massValue
}


#
# networkCGEDM  Main procedure for CGing an electron density map
#
# Inputs:
#   statusProc - Name of tcl procedure that expects a single string
#                as an argument (see example above).  All status information
#                will be sent to this procedure, which can deal with it
#                as desired.
#   inMolId - Molecule number (or name, such as 'top') in VMD that we want
#             to have coarse grained.  This molecule needs to contain the
#             contents of both a PDB and PSF
#   cgResName - desired name of the CG residue.  Needs to be <= 3 letters.
#   cgPrefix - 1 letter prefix for the CG atom names and types.  If given
#              'A', atom names will be A1, A2, etc. 
#   outPDB - Destination filename for the CG'd PDB file
#   outAllAtom - Destination filename for the reference all atom PDB file
#                that contains information about which CG atom each of the
#                all-atom atoms corresponds to
#   outTop - Destination filename for the CG'd Topology file
#   outParm - Destination filename for the CG'd Parameter file
#   numBeads - Desired number of beads that we want
#   numSteps - Number of steps to use for learning the best positions
#              for the beads.  Example:  200 * numBeads
#   epsInit - Initial value for epsilon
#   epsFinal - Final value for epsilon
#   lambdaInit - Initial value for lambda
#   lambdaFinal - Final value for lambda
#   bondCutMethod - 0 to use backbone connectivity of all-atom model.  
#                   1 to use user-specified cutoff distance
#   bondCutDist - cut-off distance for bonds between beads (in angstroms)
#   fracCutoff should be defined by the user, and
#                should be 0 <= fracCutoff < 1. Default value should be 0.01.
#   massValue - user defined value for the total mass of the CG model.
#               If a negative number, this isn't used, and the values
#               that VMD knows about are used.  (typically for all atom
#               you will just want to use the masses of the atoms to
#               determine the total mass of the system, but for electron
#               density maps, this information isn't available, and can
#               be provided via this value)
#
proc ::cgnetworking::networkCGEDM { statusProc filename cgResName \
                                      cgPrefix \
                                      outPDB outTop outParm \
                                      numBeads numSteps epsInit epsFinal \
                                      lambdaInit lambdaFinal \
                                      bondCutMethod bondCutDist \
                                      fracCutoff massValue} {

   set line ""
   if [catch {set channel [open $filename r]}] {
      ::cgnetworking::log $statusProc \
                              "Error: opening input file ($filename) failed"
      return
   }

   # Let's figure out what type of file we are reading.
   set fileType [::cgnetworking::getFileType $filename]

   ::cgnetworking::log $statusProc "Reading $fileType file..."

   # skip comments
   set line_1 "#"
   while {$line_1 == "#"} {
      gets $channel line
      set line_1 [lindex $line 0]
   }

   set tmp_x 0.0
   set tmp_y 0.0
   set tmp_z 0.0
   set tmp_m 0.0
   
   if { $fileType == "DX" } {
      set Nx [lindex $line 5]
      set Ny [lindex $line 6]
      set Nz [lindex $line 7]
      set Ntot [expr {$Nx*$Ny*$Nz}]
   
      gets $channel line
      set xmin [lindex $line 1]
      set ymin [lindex $line 2]
      set zmin [lindex $line 3]
   
      gets $channel line
      set dx [lindex $line 1]
      gets $channel line
      set dy [lindex $line 2]
      gets $channel line
      set dz [lindex $line 3]
      gets $channel line
      gets $channel line

      while {([gets $channel line] >= 0) && ([lindex $line 0] != "attribute")} {
         lappend tmp_m [lindex $line 0]
         lappend tmp_m [lindex $line 1]
         lappend tmp_m [lindex $line 2]
      }
      close $channel
   
      for {set i 1} {$i <= $Nx} {incr i} {
         set x [expr {$xmin + ($i-1)*$dx}]
         for {set j 1} {$j <= $Ny} {incr j} {
            set y [expr {$ymin + ($j-1)*$dy}]
            for {set k 1} {$k <= $Nz} {incr k} {
               set z [expr {$zmin + ($k-1)*$dz}]
               set n [expr {($k-1)*$Nx*$Ny + ($j-1)*$Nx + $i}]
               lappend tmp_x $x
               lappend tmp_y $y
               lappend tmp_z $z
            }
         }
      }
   
   } elseif { $fileType == "SITUS" } {

      set dx [lindex $line 0]
      set dy $dx
      set dz $dx
      set xmin [lindex $line 1]
      set ymin [lindex $line 2]
      set zmin [lindex $line 3]
      set Nx [lindex $line 4]
      set Ny [lindex $line 5]
      set Nz [lindex $line 6]
      set Ntot [expr {$Nx*$Ny*$Nz}]

      while {[gets $channel line] >= 0} {
         set line_l [llength $line]
         for {set i 0} {$i < $line_l} {incr i} {
            lappend tmp_m [lindex $line $i]
         }
      }
      close $channel

      for {set k 1} {$k <= $Nz} {incr k} {
         set z [expr {$zmin + ($k-1)*$dz}]
         for {set j 1} {$j <= $Ny} {incr j} {
            set y [expr {$ymin + ($j-1)*$dy}]
            for {set i 1} {$i <= $Nx} {incr i} {
               set x [expr {$xmin + ($i-1)*$dx}]
               lappend tmp_x $x
               lappend tmp_y $y
               lappend tmp_z $z
            }
         }
      }

   } else {
      ::cgnetworking::log $statusProc "Unknown EDM File Type..."
   }
   
#   puts "Nx = $Nx"
#   puts "Ny = $Ny"
#   puts "Nz = $Nz"
#   puts "xmin = $xmin"
#   puts "ymin = $ymin"
#   puts "zmin = $zmin"
#   puts "dx = $dx"
#   puts "dy = $dy"
#   puts "dz = $dz"
#   puts "Ntot = $Ntot"
#   puts ""
   
# Now make the values in the map to be >= 0,
# then truncate the density map, leaving for consideration only
# the values above given cutoff.
# Find the minimal and maximum values of tmp_m.
   set tmp_m_min [lindex $tmp_m 1]
   set tmp_m_max [lindex $tmp_m 1]
   for {set n 1} {$n <= $Ntot} {incr n} {
      set tmp [lindex $tmp_m $n]
      if {$tmp < $tmp_m_min} {set tmp_m_min $tmp}
      if {$tmp > $tmp_m_max} {set tmp_m_max $tmp}
   }

   if {$tmp_m_min < 0.0} {
      set tmp_m_min 0.0
   }

   set a_m_cutoff [expr $fracCutoff*$tmp_m_max]

# Fill in the arrays now.
   set a_x 0.0
   set a_y 0.0
   set a_z 0.0
   set a_m 0.0
   set a_c 0.0
   set numAtoms 0
   for {set n 1} {$n <= $Ntot} {incr n} {
      set tmp [ expr {[lindex $tmp_m $n]}]
      if {($tmp > $a_m_cutoff) && ($tmp > 0.0) } {
         incr numAtoms
         lappend a_x [lindex $tmp_x $n]
         lappend a_y [lindex $tmp_y $n]
         lappend a_z [lindex $tmp_z $n]
         lappend a_m $tmp
     	   lappend a_c 0.0
      }
   }
#   puts "numAtoms = $numAtoms"
# Here one should delete unused lists from the memory,
# but for some reason this freezes the computer.
#   $tmp_x delete
#   $tmp_y delete
#   $tmp_z delete
#   $tmp_m delete
   
   if {$numAtoms < $numBeads} {
      ::cgnetworking::log $statusProc \
            "Number of points to be represented ($numAtoms) is less than number of CG beads ($numNeur)."
      ::cgnetworking::log $statusProc \
            "Stopping. Try to reduce the cutoff value or use fewer CG beads."
# ????      stopcbvbnng
   }

   ::cgnetworking::toNetworkingCG $statusProc -1 $cgResName \
                     $cgPrefix $outPDB "" $outTop $outParm \
                     $numBeads $numSteps $epsInit $epsFinal \
                     $lambdaInit $lambdaFinal $bondCutMethod $bondCutDist \
                     $numAtoms $a_x $a_y $a_z $a_m $a_c $massValue
}
#
# toNetworkingCG  Main procedure
#
# Inputs:
#   statusProc - Name of tcl procedure that expects a single string
#                as an argument (see example above).  All status information
#                will be sent to this procedure, which can deal with it
#                as desired.
#   inMolId - Molecule ID that is used for writing the all atom 
#             representation.  This value isn't used for anything else.
#             When electron density maps are used, this can be -1 for now.
#   cgResName - desired name of the CG residue.  Needs to be <= 3 letters.
#   cgPrefix - 1 letter prefix for the CG atom names and types.  If given
#              'A', atom names will be A1, A2, etc. 
#   outPDB - Destination filename for the CG'd PDB file
#   outAllAtom - Destination filename for the reference all atom PDB file
#                that contains information about which CG atom each of the
#                all-atom atoms corresponds to.  For doing electron density
#                maps, this value should be "", which will indicate that
#                an all-atom reference PDB shouldn't be written.
#   outTop - Destination filename for the CG'd Topology file
#   outParm - Destination filename for the CG'd Parameter file
#   numBeads - Desired number of beads that we want
#   numSteps - Number of steps to use for learning the best positions
#              for the beads.  Example:  200 * numBeads
#   epsInit - Initial value for epsilon
#   epsFinal - Final value for epsilon
#   lambdaInit - Initial value for lambda
#   lambdaFinal - Final value for lambda
#   bondCutMethod - 0 to use backbone connectivity of all-atom model.  
#                   1 to use user-specified cutoff distance
#   bondCutDist - cut-off distance for bonds between beads (in angstroms)
#                only used if bondCutMethod is set to 1
#   numAtoms - number of atoms in all-atom representation
#   a_x, a_y, a_z - coordinate lists.  List element zero is not used.  List
#                   element 1 corresponds to the first atom        
#   a_m, a_c  - atom masses and charges.  List element zero is not used.  List
#                   element 1 corresponds to the first atom        
#   input_mass - user defined value for the total mass of the CG model.
#               If a negative number, this isn't used, and the values
#               that VMD knows about are used.  (typically for all atom
#               you will just want to use the masses of the atoms to
#               determine the total mass of the system, but for electron
#               density maps, this information isn't available, and can
#               be provided via this value)
#
proc ::cgnetworking::toNetworkingCG { statusProc inMolId cgResName \
                                      cgPrefix \
                                      outPDB outAllAtom outTop outParm \
                                      numBeads numSteps epsInit epsFinal \
                                      lambdaInit lambdaFinal \
                                      bondCutMethod bondCutDist \
                                      numAtoms a_x a_y a_z a_m a_c \
                                      input_mass} {
#   ::cgnetworking::log $statusProc " ------  after createBoundaryList\n$boundaries\n [llength $boundaries] "
   # -----------------------------------------------------------------------
   #   initialize several lists



   set n_x [initList]
   set n_y [initList]
   set n_z [initList]
   set n_m [initList]
   set n_c [initList]

   set boundaries [::cgnetworking::createBoundaryList $a_m]

#   ::cgnetworking::log $statusProc " ------  after inits"
   for {set k 0} {$k < $numBeads} {incr k} {
      # initial coordinates chosen at random, with probability distribution as
      # for the masses of atoms
      set i [rand_interval $boundaries]
      lappend n_x [lindex $a_x $i]
      lappend n_y [lindex $a_y $i]
      lappend n_z [lindex $a_z $i]
      lappend n_m 0
      lappend n_c 0

   }
   # -----------------------------------------------------------------------
   #::cgnetworking::log $statusProc " ------  after coord inits \nn_x=$n_x\nn_y=$n_y\nn_z=$n_z"
#   ::cgnetworking::log $statusProc " ------  after coord inits"

   set eps $epsInit
   set lambda $lambdaInit

   set d_eps [expr {pow($epsFinal/$eps, 1.0/$numSteps)}]
   set d_lambda [expr {pow($lambdaFinal/$lambda, 1.0/$numSteps)}]

#   ::cgnetworking::log $statusProc " ------  before learning steps. d_eps=$d_eps d_lambda=$d_lambda "
   # learning steps

# let's choose a reasonable frequency to print out the status
   set printFrequency [ expr {(int($numSteps / 15) / 20) * 20} ]
   if { $printFrequency < 1 } {
      set printFrequency 1
   }

   for {set k1 0} {$k1 <= $numSteps} {incr k1} {
      if { $k1 % $printFrequency == 0} {
         ::cgnetworking::log $statusProc " --------------------------  learning step $k1 "
      }
      set eps [ expr {$eps * $d_eps }]
      set lambda [ expr {$lambda * $d_lambda }]

      # choice of stimulus
      set i [::cgnetworking::rand_interval $boundaries]
      set x [lindex $a_x $i]
      set y [lindex $a_y $i]
      set z [lindex $a_z $i]

#      ::cgnetworking::log $statusProc " ------  before for #1 x=$x y=$y z=$z"
      # for each "bead" determine the number n_k[i] of "neorons" j with
      # ||r - r_j|| < ||r - r_i||
      set n_r [initList]
      for {set k 1} {$k <= $numBeads} {incr k} {
#         ::cgnetworking::log $statusProc "k=$k n_x=[lindex $n_x $k] n_y=[lindex $n_y $k] n_z=[lindex $n_z $k]"
         lappend n_r [expr {pow([lindex $n_x $k] - $x, 2) +   \
                           pow([lindex $n_y $k] - $y, 2) +   \
                           pow([lindex $n_z $k] - $z, 2)}] 
      }

#     ::cgnetworking::log $statusProc " ------  before for #2 "
      set n_k [initList]
      for {set i 1} {$i <= $numBeads} {incr i} {
         set tmp [lindex $n_r $i]
         lappend n_k 0
         for {set j 1} {$j <= $numBeads} {incr j} {
            if {[lindex $n_r $j] < $tmp} {
               # foobar
               lset n_k $i [expr {[lindex $n_k $i] + 1}]
            }
         }
      }

#     ::cgnetworking::log $statusProc " ------  before adaption eps=$eps lambda=$lambda n_k=$n_k "
      # adaption
      for {set i 1} {$i <= $numBeads} {incr i} {
#        ::cgnetworking::log $statusProc "before tmp [expr {[lindex $n_k $i]/-$lambda }]"

         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   set tmp [expr {$eps * exp([lindex $n_k $i]/-$lambda)}]
         #  This was previous the above 'set'.  BUT, tcl was bombing
         # with number underruns 
         #    ( "floating-point value too small to represent" )
         # so, this check/hack just sets tmp to zero if we find ourselves
         # in that situation.  The number -745.1325 was determined by
         # simple testing.  it is very likely specific to the system
         # that I am running on.
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         #   foobar
         if {[ set power  [expr {[lindex $n_k $i]/-$lambda} ] ] < -745.1325 } {
            set tmp 0.0
         } else {
            set tmp [expr {$eps * exp($power)}]
         }
#        ::cgnetworking::log $statusProc "after tmp"
         set tmp1 [expr 1.0 - double($tmp)]
#        ::cgnetworking::log $statusProc "i=$i n_k=[lindex $n_k $i] n_x=[lindex $n_x $i] n_y=[lindex $n_y $i] n_z=[lindex $n_z $i] tmp=$tmp tmp1=$tmp1"
         lset n_x $i [expr {$tmp1 * [lindex $n_x $i] + $tmp * $x}]
         lset n_y $i [expr {$tmp1 * [lindex $n_y $i] + $tmp * $y}]
         lset n_z $i [expr {$tmp1 * [lindex $n_z $i] + $tmp * $z}]
#        ::cgnetworking::log $statusProc "i=$i n_x=[lindex $n_x $i] n_y=[lindex $n_y $i] n_z=[lindex $n_z $i]"
      }
   }

#   ::cgnetworking::log $statusProc " ------  after learning steps \nn_x=$n_x \nn_y=$n_y \nn_z=$n_z"
   ::cgnetworking::log $statusProc " ------  after learning steps"
   # find the domains of atoms around a "bead" - all atoms to which this 
   # "bead" is closer than any other
   set a_nk [initList]


   for {set k 0} {$k < $numAtoms} {incr k} {
      set kp1 [expr {$k + 1}]
      set x [lindex $a_x $kp1]
      set y [lindex $a_y $kp1]
      set z [lindex $a_z $kp1]

      set tmpFirst [expr {pow([lindex $n_x 1] - $x, 2) +   \
                           pow([lindex $n_y 1] - $y, 2) +   \
                           pow([lindex $n_z 1] - $z, 2)}] 
      set tmp $tmpFirst
      lappend a_nk 1

      for {set i 2} {$i <= $numBeads} {incr i} {
         set tmp1 [expr {pow([lindex $n_x $i] - $x, 2) +   \
                           pow([lindex $n_y $i] - $y, 2) +   \
                           pow([lindex $n_z $i] - $z, 2)}] 
         if {$tmp1 < $tmp} {
            set tmp $tmp1
            lset a_nk $kp1 $i
         }
      }

   }

   ::cgnetworking::log $statusProc " ------  after finding domains of atoms around beads "
   # calculate the mass and charge of each "bead" (as mass and charge of its
   # domain) and shift the "bead" to the center of mass of the domain

   # zero out the bead info
   for {set k 1} {$k <= $numBeads} {incr k} {
      lset n_m $k 0
      lset n_c $k 0
      lset n_x $k 0
      lset n_y $k 0
      lset n_z $k 0
   }

#   ::cgnetworking::log $statusProc " ------  bead arrays zeroed out..."
   for {set k 1} {$k <= $numAtoms} {incr k} {
      set am_of_k [lindex $a_m $k]
#      set am_of_k [lindex $a_m $k]
      set ank_of_k [lindex $a_nk $k]


      set tmpNum [lindex $n_m $ank_of_k]
#      if { $ank_of_k == 1 } {puts " ------  adding $am_of_k to n_m" }
      lset n_m $ank_of_k [expr { $tmpNum + $am_of_k }]

      set tmpNum [lindex $n_c $ank_of_k]
      lset n_c $ank_of_k [expr { $tmpNum + [lindex $a_c $k] } ]

      set tmpNum [lindex $n_x $ank_of_k]
      lset n_x $ank_of_k [expr { $tmpNum + $am_of_k * [lindex $a_x $k]}]
      set tmpNum [lindex $n_y $ank_of_k]
      lset n_y $ank_of_k [expr { $tmpNum + $am_of_k * [lindex $a_y $k]}]
      set tmpNum [lindex $n_z $ank_of_k]
      lset n_z $ank_of_k [expr { $tmpNum + $am_of_k * [lindex $a_z $k]}]
   }

   #::cgnetworking::log $statusProc " ------  normalizing coordinates\nbead masses=$n_m\nn_c=$n_c"
#   ::cgnetworking::log $statusProc " ------  normalizing coordinates"
   set c_full 0
   for {set k 1} {$k <= $numBeads} {incr k} {
#      puts "n_x\[$k\]=[lindex $n_x $k] n_y\[$k\]=[lindex $n_y $k] n_z\[$k\]=[lindex $n_z $k]"
      set nm_of_k [lindex $n_m $k]
      if { $nm_of_k == 0} {
         ::cgnetworking::log $statusProc " WARNING:  Bead #$k has no atoms assigned to it.  Run again and/or try reducing the number of desired beads."

#         puts "n_m\[$k\] was zero."
      } else {
         lset n_x $k [expr {[lindex $n_x $k] / $nm_of_k }]
         lset n_y $k [expr {[lindex $n_y $k] / $nm_of_k }]
         lset n_z $k [expr {[lindex $n_z $k] / $nm_of_k }]
      }
      set c_full [expr {$c_full + [lindex $n_c $k]}]
   }

   ::cgnetworking::log $statusProc " ------  establishing bonds between beads"
   # establish the bonds between the "beads"

   # not sure why we need to do this..
   lappend n_x 0

   set tempRowList [initList]
   set n_bond [initList]
   set n_bond_l [initList]

   for {set k 1} {$k <= $numBeads} {incr k} {
      lappend n_bond 0
      lappend n_bond_l 0
      lappend tempRowList 0
   }

   # we now have a single dim list in n_bond and n_bond_l
   for {set k 1} {$k <= $numBeads} {incr k} {
      lset n_bond $k $tempRowList
      lset n_bond_l $k $tempRowList
   }

#   ::cgnetworking::log $statusProc " ------  before setting bonds"

# In the GUI, if a user chooses to use bondCutMethod != 0 (a checkbox for that?),
# it's probably a good idea to make the field with bondCutDist inaccessible.

# Set bonds.  A couple of different ways to do it.  Can do it using the
# cutoff provided by the user...
   if {$bondCutMethod == 0} {
# Here, bondCutMethod == 0; establish bonds based on the distance cutoff.
      set tmp1 [expr {$bondCutDist * $bondCutDist}]

      for {set k 1} {$k <= $numBeads} {incr k} {
         set x [lindex $n_x $k]
         set y [lindex $n_y $k]
         set z [lindex $n_z $k]

         for {set i [expr {$k+1}]} {$i <= $numBeads} {incr i} {
            set tmp [expr { pow([lindex $n_x $i] - $x, 2) + \
                            pow([lindex $n_y $i] - $y, 2) + \
                            pow([lindex $n_z $i] - $z, 2) }]
            if {$tmp < $tmp1} {
               lset n_bond $k $i 1
               lset n_bond $i $k 1
               lset n_bond_l $k $i [expr {sqrt($tmp)}]
               lset n_bond_l $i $k [expr {sqrt($tmp)}]
#               incr n_N_bond

            }
         }
      }
   } else {
# An alternative approach to establishing bonds: track the backbone
# and establish a bond between two beads if the backbone runs between them.

# Write a temporary file with the backbone atoms only; this simplifies 
# the calculations.
# Write the beads' numbers to the beta field,
# so that the reassinment of atoms' indices does not harm the algorithm.
      set sel [atomselect $inMolId "all"]
      set savebeta [$sel get beta]
      $sel set beta [lrange $a_nk 1 [llength $a_nk]]
      set BBsel [atomselect top "backbone"]
      # Write a "fake" file with only one atom if no backbone atoms are found.
      if {[$BBsel num] < 1} {
         $BBsel delete
         set BBsel [atomselect top "index 0"]
         ::cgnetworking::log $statusProc "WARNING: no backbone atoms found, so no bonds will be established."
         ::cgnetworking::log $statusProc "You can establish bonds based on a cutoff distance between CG beads; to do that,"
         ::cgnetworking::log $statusProc "start the shape-based CG over again, and choose the appropriate method for bonds assignment."
      }
      $BBsel writepdb BB_tmp.pdb
      $BBsel writepsf BB_tmp.psf
      $sel set beta $savebeta
      $sel delete

      # Now the backbone files comprise the top molecule for a while.
      mol load psf BB_tmp.psf pdb BB_tmp.pdb
      # Renew the selection (remove the unused data from the memory first).
      $BBsel delete
      set BBsel [atomselect top all]
      set N_BB [$BBsel num]
      set list_BB_bonds [$BBsel getbonds]

      for {set i_BB 0} {$i_BB < $N_BB} {incr i_BB} {
# Find the list of all atoms to which atmom $i_BB is bonded
# (note that atomic indices here are from the PDB file for the backbone only,
# which in general is different from the original all-atom PDB file).
         set i_BB_bonds [lindex $list_BB_bonds $i_BB]
         set N_i_BB_bonds [llength $i_BB_bonds]
         set i_BB_bead [expr int([[atomselect top "index $i_BB"] get beta])]
         for {set j 0} {$j < $N_i_BB_bonds} {incr j} {
            set k_BB [lindex $i_BB_bonds $j]
            # Backbone atoms $i_BB and $k_BB are bonded.
            # Check if they are in the domains of different beads.
            set k_BB_bead [expr int([[atomselect top "index $k_BB"] get beta])]
            # If these are different beads, establish a bond between them.
            if {$i_BB_bead != $k_BB_bead} {
               set tmp [expr { pow([lindex $n_x $i_BB_bead] - \
                                   [lindex $n_x $k_BB_bead], 2) + \
                 pow([lindex $n_y $i_BB_bead] - [lindex $n_y $k_BB_bead], 2) + \
                 pow([lindex $n_z $i_BB_bead] - [lindex $n_z $k_BB_bead], 2) }]
               lset n_bond $k_BB_bead $i_BB_bead 1
               lset n_bond $i_BB_bead $k_BB_bead 1
               lset n_bond_l $k_BB_bead $i_BB_bead [expr {sqrt($tmp)}]
               lset n_bond_l $i_BB_bead $k_BB_bead [expr {sqrt($tmp)}]
            }
         }
      }

      # Remove temporary files, as well as unused selections and molecules.
      mol delete top
      $BBsel delete
      file delete BB_tmp.pdb
      file delete BB_tmp.psf
   }

#   set tmp1 [expr {$bondCutDist * $bondCutDist}]
#
#   for {set k 1} {$k <= $numBeads} {incr k} {
#      set x [lindex $n_x $k]
#      set y [lindex $n_y $k]
#      set z [lindex $n_z $k]
#
#      for {set i [expr {$k+1}]} {$i <= $numBeads} {incr i} {
#         set tmp [expr { pow([lindex $n_x $i] - $x, 2) + \
#            pow([lindex $n_y $i] - $y, 2) + \
#            pow([lindex $n_z $i] - $z, 2) }]
#         if {$tmp < $tmp1} {
#            lset n_bond $k $i 1
#            lset n_bond $i $k 1
#            lset n_bond_l $k $i [expr {sqrt($tmp)}]
#            lset n_bond_l $i $k [expr {sqrt($tmp)}]
##            incr n_N_bond
#
#         }
#      }
#   }


   # Scale masses of the neurons so that the total mass equals to input_mass.

   # sum up the bead masses
   if { $input_mass > 0} {
      ::cgnetworking::log $statusProc " ------  setting mass of CG beads"
      set m_tot_current 0.0
      for {set k 1} {$k <= $numBeads} {incr k} {
         set m_tot_current [expr {$m_tot_current + [lindex $n_m $k]}]
      }

      set scaling_factor [expr {$input_mass/$m_tot_current}]

      for {set k 1} {$k <= $numBeads} {incr k} {
         lset n_m $k [expr {[lindex $n_m $k] * $scaling_factor}]
      }
   }



   ::cgnetworking::log $statusProc " ------  writing output files"
   ::cgnetworking::writePdb $outPDB $numBeads $cgPrefix $cgResName \
                            $n_x $n_y $n_z

   if { $outAllAtom != "" } {
      ::cgnetworking::writeAllAtomPdb $outAllAtom $inMolId $a_nk 
   }

   ::cgnetworking::writeTop $outTop $numBeads $cgPrefix $n_m \
                            $cgResName $c_full $n_c $n_bond

   ::cgnetworking::writeParm $outParm $numBeads $cgPrefix $numAtoms $n_bond \
                            $n_bond_l $n_x $n_y $n_z $a_nk \
                            $a_x $a_y $a_z
   ::cgnetworking::log $statusProc " Shape-based coarse graining has completed"
}


# ----------------------------------------------------------------------
# 
# write the pdb file
#
proc ::cgnetworking::writePdb { outPDB numBeads cgPrefix cgResName \
                            n_x n_y n_z } {
   set output [open $outPDB "w"]

   puts $output "REMARK Generated by the networking algorithm developed"
   puts $output "REMARK in the Klaus Schulten group (Theoretical and"
   puts $output "REMARK Computational Biophysics Group; www.ks.uiuc.edu)"
   puts $output "REMARK Contact vmd@ks.uiuc.edu with questions"

   for {set k 1} {$k <= $numBeads} {incr k} {
      puts $output [format \
      "ATOM  %5d %4s%4s  %4d    %8.3f%8.3f%8.3f%6.2f%6.2f      %4s" \
      $k "$cgPrefix$k" $cgResName 1 [lindex $n_x $k] \
      [lindex $n_y $k] [lindex $n_z $k] 1.00 [expr {double($k)}] "P" ]
   }
   puts $output "END"

   close $output
}

# ----------------------------------------------------------------------
# 
# write the all atom pdb file
#
proc ::cgnetworking::writeAllAtomPdb { outAllAtom inMolId a_nk } {
#   puts $a_nk
   # save the old beta field
   set sel [atomselect $inMolId "all"]
   set savebeta [$sel get beta]
#   puts "old beta [$sel get beta]"

   $sel set beta [lrange $a_nk 1 [llength $a_nk]]
#   puts "new beta [$sel get beta]"

   $sel writepdb $outAllAtom

   $sel set beta $savebeta
#   puts "old beta [$sel get beta]"

   $sel delete
#   puts "after delete"
}

# ----------------------------------------------------------------------
# 
# write the topology file
#
proc ::cgnetworking::writeTop { outTop numBeads cgPrefix n_m \
                            cgResName c_full \
                            n_c n_bond } {
   set output [open $outTop "w"]

   puts $output "* Topology file in CG representation"
   puts $output "* Generated using the networking algorithm developed"
   puts $output "* in the Klaus Schulten group (Theoretical and"
   puts $output "* Computational Biophysics Group; www.ks.uiuc.edu)"
   puts $output "* Contact vmd@ks.uiuc.edu with questions"
   puts $output "\n27 1\n"

   # output the masses of the beads
   for {set k 1} {$k <= $numBeads} {incr k} {
      puts $output [format "MASS%10d%8s%14.4f" $k $cgPrefix$k \
                   [lindex $n_m $k]]
   }

   puts $output "\nDEFA FIRS NONE LAST NONE\nAUTO ANGLES\n"

   puts $output [format "RESI %s %14.6f" $cgResName $c_full]
   
   for {set k 1} {$k <= $numBeads} {incr k} {
      puts $output [format "ATOM%8s%8s%14.6f" "$cgPrefix$k" $cgPrefix$k [lindex $n_c $k]]
   }

   set numBonds 0
   for {set k 1} {$k <= $numBeads} {incr k} {
      for {set i [expr {$k+1}]} {$i <= $numBeads} {incr i} {
         # do we have a bond here?
         if { [lindex $n_bond $k $i] == 1 } {
            if { $numBonds == 0 } {
               # first one on the line
               set currentLine "BOND "
            }
            incr numBonds
            set currentLine "$currentLine $cgPrefix$k $cgPrefix$i"

            if { $numBonds == 4 } {
               puts $output $currentLine
               set numBonds 0
            }
         }
      }
   }

   if { $numBonds != 0 } {
      puts $output $currentLine
   }

   puts $output "END\n"

   close $output
}

# ----------------------------------------------------------------------
# 
# write the parameter file
#
proc ::cgnetworking::writeParm { outParm numBeads cgPrefix \
                            numAtoms n_bond n_bond_l \
                            n_x n_y n_z a_nk a_x a_y a_z } {

   set output [open $outParm "w"]

   puts $output "* Parameter file in the CG representation"
   puts $output "* Generated using the networking algorithm developed"
   puts $output "* in the Klaus Schulten group (Theoretical and"
   puts $output "* Computational Biophysics Group; www.ks.uiuc.edu)"
   puts $output "* Contact vmd@ks.uiuc.edu with questions"
   puts $output "\nBONDS\n!\n"
   puts $output "!V(bond) = Kb(b - b0)**2 "
   puts $output  "! "
   puts $output  "!Kb: kcal/mole/A**2 "
   puts $output  "!b0: A "
   puts $output  "! "
   puts $output  "!atom type Kb          b0 "
   puts $output  "! "
   for {set k 1} {$k <= $numBeads} {incr k} {
      for {set i [expr {$k+1}]} {$i <= $numBeads} {incr i} {
         if { [lindex $n_bond $k $i] == 1} {
            puts $output [format "%-5s%-5s%10.3f%10.4f" \
                  "$cgPrefix$k" \
                  "$cgPrefix$i" \
                  20.0 [lindex $n_bond_l $k $i]]
         }
      }
   }

   puts $output  "\nANGLES "
   puts $output  "! "
   puts $output  "!V(angle) = Ktheta(Theta - Theta0)**2 "
   puts $output  "! "
   puts $output  "!Ktheta: kcal/mole/rad**2 "
   puts $output  "!Theta0: degrees "
   puts $output  "! "
   puts $output  "!atom types     Ktheta    Theta0 "
   puts $output  "! "

   for {set k 1} {$k <= $numBeads} {incr k} {
      for {set i 1} {$i <= $numBeads} {incr i} {
         for {set l $k} {$l <= $numBeads} {incr l} {
            if {   $k != $l    &&
                   [lindex $n_bond $k $i] == 1     &&
                   [lindex $n_bond $i $l] == 1   } {
#               puts "k=$k, i=$i, l=$l"
               set x_ik [expr {[lindex $n_x $k] - [lindex $n_x $i]}]
               set y_ik [expr {[lindex $n_y $k] - [lindex $n_y $i]}]
               set z_ik [expr {[lindex $n_z $k] - [lindex $n_z $i]}]
               set x_il [expr {[lindex $n_x $l] - [lindex $n_x $i]}]
               set y_il [expr {[lindex $n_y $l] - [lindex $n_y $i]}]
               set z_il [expr {[lindex $n_z $l] - [lindex $n_z $i]}]
               set tmp [expr {$x_ik*$x_il + $y_ik*$y_il + $z_ik*$z_il}]
               set tmpk [expr {sqrt($x_ik*$x_ik + $y_ik*$y_ik + $z_ik*$z_ik)}]
               set tmpl [expr {sqrt($x_il*$x_il + $y_il*$y_il + $z_il*$z_il)}]
#               puts "tmp=$tmp ; tmpk=$tmpk ; tmpl=$tmpl calc=[expr {$tmp/($tmpk*$tmpl)}]"
               if { ($tmpk == 0) || ($tmpl == 0) } {
                  set tmp 1
               } else {
                  set tmp [expr {$tmp/($tmpk*$tmpl)}]
               }
               # foobar.  Sometimes tmp is getting set to a value 
               # infintessimally greater than 1, which is causing
               # problems.
               if { $tmp > 1.0 } {
                  set tmp 1.0
#                  puts "we're greater than 1"
               }
#               puts "calc=[expr {acos($tmp)}]"
# 180 / pi => 57.29577951308232087684
               set tmp [expr {57.29577951308232087684 * acos($tmp)} ]
               puts $output [format "%-5s%-5s%-5s%10.3f%10.4f" \
                            "$cgPrefix$k" \
                            "$cgPrefix$i" \
                            "$cgPrefix$l" \
                            20.0 $tmp]
            }
         }
      }
   }

   puts $output "\nDIHEDRALS "
   puts $output "! "
   puts $output "!V(dihedral) = Kchi(1 + cos(n(chi) - delta)) "
   puts $output "! "
   puts $output "!Kchi: kcal/mole "
   puts $output "!n: multiplicity "
   puts $output "!delta: degrees "
   puts $output "! "
   puts $output "!atom types             Kchi    n   delta "
   puts $output "! "
   puts $output "X    X    X    X    0.0        1     0.0 ! No dihedrals \n"

   puts $output "NONBONDED "
   puts $output "! "
   puts $output "!V(Lennard-Jones) = Eps,i,j\[(Rmin,i,j/ri,j)**12 - 2(Rmin,i,j/ri,j)**6\] "
   puts $output "! "
   puts $output "!epsilon: kcal/mole, Eps,i,j = sqrt(eps,i * eps,j) "
   puts $output "!Rmin/2: A, Rmin,i,j = Rmin/2,i + Rmin/2,j "
   puts $output "! "
   puts $output "!atom  ignored    epsilon      Rmin/2 "
   puts $output "! "

   set n_r_par [initList]
   set n_a_num [initList]

   for {set k 1} {$k <= $numBeads} {incr k} {
      lappend n_r_par 0
      lappend n_a_num 0
   }

   for {set i 1} {$i <= $numAtoms} {incr i} {

      set x [lindex $a_x $i]
      set y [lindex $a_y $i]
      set z [lindex $a_z $i]

      set ank_of_i [lindex $a_nk $i]

      lset n_r_par $ank_of_i [expr { [lindex $n_r_par $ank_of_i] +
                    pow( [lindex $n_x $ank_of_i] - $x,2) + 
                    pow( [lindex $n_y $ank_of_i] - $y,2) + 
                    pow( [lindex $n_z $ank_of_i] - $z,2) }]
      lset n_a_num $ank_of_i [expr { [lindex $n_a_num $ank_of_i] + 1.0} ]
   }

   for {set k 1} {$k <= $numBeads} {incr k} {
      if { [lindex $n_a_num $k] != 0 } {
#         puts "n_r_par\[$k\]=[lindex $n_r_par $k], n_a_num=[lindex $n_a_num $k]"
         puts $output [format "%-5s%10f%11.6f%12.6f" \
                            "$cgPrefix$k" \
                            0.0 -4.0 \
                            [expr {1.0 + 
                            sqrt([lindex $n_r_par $k] / [lindex $n_a_num $k])
                                  }]]
      }
   }

   puts $output "\nEND\n"

   close $output
}

# ----------------------------------------------------------------------
# 
#  Given a list with element '0' being zero and the last element 
#  being 1.0, where the elements are monotonically increasing.  
#      Example:    0.0 0.1 0.2 0.4 0.8 1.0
#
#  Choose a random number between 0 and 1, and return the list ID
#  such that distributionList [ id - 1] is less than the random
#  number, and distributionList [ id ] is greater than or equal to
#  the random number.
#
# Probability to get number k is proportional to the width of k'th interval:
# (b[k-1];b[k]).
#
#  This procedure doesn't call srand, so if you want random values
#  from call to call, you need to call it.
#
proc ::cgnetworking::rand_interval { distributionList } {
   set numIntervals [expr {[llength $distributionList] }]
   set x [expr { rand() }]
#   set x 0.9999999
#   set x 0.00000001
#   set x 0.50000001

   set i0 [expr { 1 + int(floor([expr { [expr { $numIntervals - 1} ] * rand() } ] ) ) } ]
#   set i0 [expr { 1 + int(floor( $numIntervals - 1) * rand()  ) )}  ]

   set i0_left 0
   set i0_right $numIntervals

   set i 0

#   puts "x=$x i0=$i0"

   #puts "before loop"
   while { $i == 0 } { 
      #puts "in loop. x=$x i0=$i0 i0_right=$i0_right i0_left=$i0_left"
      if {$x < [lindex $distributionList $i0]  } {
         if {$x >= [lindex $distributionList [expr {$i0 -1}]] } {
            set i $i0
         } else {
            set i0_right $i0
            set i0 [expr {$i0 - ($i0 - $i0_left)/2}]
         }
      } else {
         set i0_left $i0
         set i0 [expr {$i0 + (($i0_right - $i0) + 1)/2}]
      }
   }
#   puts -nonewline "i0:$i0, rand: [format "%14f" $x], returning "
#   for {set k 1} {$k <= $i} {incr k} {
#      puts -nonewline "  "
#   }
#   puts "[expr {$i-1}]"
   return [expr {$i-1}]

}

# ----------------------------------------------------------------------
# create a list where each element is the percentage of normalized masses
# represented by this atom and all atoms up to this point.
# Let's say we have a molecule with atom masses of:
#    10 12 3 15 8
# The sum of the masses is:  48
#
# element zero of the list will be 0.0.
# elemnt 1 would be 10/48 + 0.0  or  0.208333
# element 2 would be 12/48 + 0.208333   or   0.4583333
# element 3 would be 3/48 + 0.458333    or   0.5208333
# element 4 would be 15/48 + 0.5208333   or    0.833333
# element 5 would be 8/48 + 0.833333    or    1.0
#
proc ::cgnetworking::createBoundaryList { a_m } {
   set result [list]
   lappend result 0.0

   set massSum 0
   foreach mass $a_m {
      set massSum [expr {$massSum + $mass}]
   }

   set runningTotal 0.0

   foreach mass $a_m  {
      set runningTotal [expr {$mass/$massSum + $runningTotal     }]
      lappend result $runningTotal
   }
#   puts "list (size:[llength $result]): $result"
   return $result
}

# ----------------------------------------------------------------------
proc ::cgnetworking::initList { } {
   set a [list]
   lappend a 0
   return $a
}

# --------------------------------------------------------------------------
proc ::cgnetworking::log { statusProc strText } {
      if {[info exists statusProc]} {
               $statusProc $strText
      }
#   else {
#      puts $strText
#   }
}

proc ::cgnetworking::getFileType { name } {
#   puts "name is '$name'"
   #if { [string match -nocase {*.dx$} [string tolower $name]] } {}
   if { [regexp -nocase {\.dx$} $name blah] } {
      return "DX"
   } elseif { [regexp -nocase {\.sit} $name blah ] } { 
      return "SITUS"
   } else {
      return "UNKNOWN"
   }
}

# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------
# ----------------------------------------------------------------------


























