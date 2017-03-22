#
# Read charmm parameter file
#

package provide readcharmmpar 1.0

namespace eval ::Pararead:: {
   namespace export getconf
   variable confsel  {}
   variable conflist {}
   variable coorlist {}
   variable par      {}; # par_all27_prot_lipid_na.inp
   variable psf      ""
   variable psfread  0
   variable parread  0
   variable pickmode 1
   variable type     "atom"
   variable index    {}
   variable oldtype  ""
   variable anglepsfconfs
   variable dihedpsfconfs
   variable improperpsfconfs
   variable params
   variable atomparams
   variable bondparams
   variable angleparams
   variable dihedparams
   variable improperparams
   variable molid [molinfo top]
}


#####################################################
### Read and assign the parameters.               ###
#####################################################

proc ::Pararead::getconf { args } {
   variable confsel
   variable conflist
   variable coorlist
   variable psf
   variable par
   variable psfread 
   variable parread
   variable type
   variable oldtype
   variable index
   variable anglepsfconfs
   variable dihedpsfconfs
   variable improperpsfconfs
   variable atomparams
   variable bondparams
   variable angleparams
   variable dihedparams
   variable improperparams
   variable molid 

   set molid [molinfo top]
   if {![llength $psf]} {
      # Get the psf filename
      foreach i [join [molinfo top get filetype]] j [join [molinfo top get filename]] {
	 if {$i=="psf"} { set psf $j }
      }
   }


   # If no atom picked yet then return
   if {![llength $index]} { return }

   set bonds {}
   set confs {}
   set vmdconfs {}

   if {$type=="atom"} {
      # For atom we just need the index. Charge and type are available in VMD.
      set vmdconfs $index
      $w.pick.format configure -text "Format: {index} {name} {type} {charge} {vdw params}"

   } elseif {$type=="bond"} {
      # For bonds we can use the vmd built in feature:
      set sel [atomselect top "index $index"]
      set bonds [$sel getbonds]
      foreach b [lindex $bonds 0] {
	 lappend vmdconfs [list $index $b]
      }
      $w.pick.format configure -text "Format: {index} {name} {type} {k R}"

   } else {
      # For all other conformations we have to parse the psf:
      if { !$psfread } { 
	 # Read the psf file:
	 set anglepsfconfs [readpsfinfo angle $psf]
	 set dihedpsfconfs [readpsfinfo dihed $psf]
	 set improperpsfconfs [readpsfinfo improper $psf]
	 set psfread 1
      }

      # Search for psf-conformations containing the atom
      eval set psfconfs $${type}psfconfs
      foreach c $psfconfs {
	 if {[lsearch -exact $c [expr $index+1]]>=0} {lappend confs $c}
      }

      # Convert to VMD format (indexes start from 0)
      set vmdconfs {}
      foreach c $confs {
	set newconf {}
	foreach i $c { 
	   set atom [expr $i-1]
	   lappend newconf $atom 
	}
	lappend vmdconfs $newconf
      }
      $w.pick.format configure -text "Format: {index} {name} {type} {params}"
   }

   if { !$parread } {
      foreach t {atom bond angle dihed improper} {
	 set tmppar {}
	 # Read the parameters for each file in $par
	 foreach p $par {
	    if {[llength $p]} { lappend tmppar [readparams $t $p] }
	 }
	 set ${t}params [join $tmppar]
	 #puts "$t numparams = [llength [join $tmppar]]"
      }
      set parread 1
   }

   # Assign parameters to conformations:
   set conflist {}
   set coorlist {}
   if {$type=="atom"} {
      lappend conflist [getvdwchargeparam $vmdconfs]
   } elseif {$type=="bond" || $type=="angle"} {
      foreach conf $vmdconfs {	
	 lappend conflist [getbondangleparam $conf]      
      }
   } elseif {$type=="dihed"} {
      foreach conf $vmdconfs {
	 lappend conflist [getdihedparam $conf]      
      }
   } elseif {$type=="improper"} {
      foreach conf $vmdconfs {
	 lappend conflist [getimproparam $conf]      
      }
   }

#    set i 0
#    foreach p $conflist {
#       puts "$i: $p"
#       incr i
#    }

}
 

#####################################################
### Get VDW parameters for atom with type $type.  ###
#####################################################

proc ::Pararead::getvdwparam { params type } {
   set par {}

   # Check for each param set if it matches normal or reverse
   set found 0
   set foundparam {}
   foreach pset [lindex $params 4] {
      set ptype [lindex $pset 0]
      set found [string equal $ptype $type]
      if {$found} { set foundparam $pset; break }
   }

   if {!$found} {
      #puts "No parameters found for $type"
      return
   } else {
      set eps   [format "%6.4f" [lindex $foundparam 1 0]]
      set Rmin2 [format "%6.4f" [lindex $foundparam 1 1]]
      if {[llength [lindex $foundparam 2]]} {
	 set eps_14   [format "%6.4f" [lindex $foundparam 2 0]]
	 set Rmin2_14 [format "%6.4f" [lindex $foundparam 2 1]]
	 set par [list $eps $Rmin2 $eps_14 $Rmin2_14]
      } else {
	 set par [list $eps $Rmin2 {} {}]
      }
   }

   return $par
}



#########################################################
# Assign Parameters to a bond.                          #
# Returns something like                                #
# {{HR3 CPH1} {365.000 1.0830}}                         #
#########################################################

proc ::Pararead::getbondparam { params types } {
   set par {}

   # Reversed typelist
   set revtypes [lrevert $types]

   # Check for each param set if it matches normal or reverse
   set found 0
   set foundparam {}
   foreach pset $params {
      set ptypes [lindex $pset 0]
      set found [string equal $ptypes $types]
      if {$found} { set foundparam $pset; break }
      set found [string equal $ptypes $revtypes]
      if {$found} { 
	 set foundparam $pset; 
	 break
      }
   }

   if {!$found} {
      #puts "No parameters found for $types / $revtypes"
      return {}
   } else {
      return [list [lindex $foundparam 0] [lindex $foundparam 1]]
   }
}

#########################################################
# Assign Parameters to an angle.                        #
# Returns something like                                #
# {{NR1 CPH1 HR3} {25.0 124.00} {20.00 2.14000}}        #
#########################################################

proc ::Pararead::getangleparam { params types } {
   set par {}

   # Reversed typelist
   set revtypes [lrevert $types]

   # Check for each param set if it matches normal or reverse
   set found 0
   set foundparam {}
   foreach pset $params {
      set ptypes [lindex $pset 0]
      set found [string equal $ptypes $types]
      if {$found} { set foundparam $pset; break }
      set found [string equal $ptypes $revtypes]
      if {$found} { 
	 set foundparam $pset; 
# 	 set angle [lrevert $angle]; 
# 	 set names [lrevert $names]; 
	 break
      }
   }

   if {!$found} {
      #puts "No parameters found for $types / $revtypes"
      return {}
   } else {
      return [list [lindex $foundparam 0] [lindex $foundparam 1] [lindex $foundparam 2]]
   }
}


#########################################################
# Assign Parameters to a dihedral.                      #
# Returns something like                                #
# {{ON5 CN7 CN7 ON6B} {0.4 6 0.0}}                      #
#########################################################

proc ::Pararead::getdihedparam { params types } {  
   set par {}

   # Reversed typelist
   set revtypes [lrevert $types]
   # Get wildcard typelist
   set xtypes [list X [lindex $types 1] [lindex $types 2] X]
   # Reversed wildcard typelist
   set rxtypes [list X [lindex $revtypes 1] [lindex $revtypes 2] X]

   # Check for each param set if it matches normal, reverse or including wildcards
   set found 0
   set foundparam {}
   foreach pset $params {
      set ptypes [lindex $pset 0]

      set found [string equal $ptypes $types]
      if {$found} { set foundparam $pset; break }

      set found [string equal $ptypes $revtypes]
      if {$found} { 
	 set foundparam $pset; 
	 break
      }

      set found [string equal $ptypes $xtypes]
      if {$found} { set foundparam $pset; break }

      set found [string equal $ptypes $rxtypes]
      if {$found} { 
	 set foundparam $pset
	 break 
      }
   }
   if {!$found} {
      #puts "No parameters found for dihed $types"
      return {}
   } else {
      return [list [lindex $foundparam 0] [lindex $foundparam 1]]
   }
}


#########################################################
# Assign Parameters to an improper.                     #
# Returns something like                                #
# {{NR1 CPH1 CPH2 CN7B} {0.60 0 0.00}}                  #
#########################################################

proc ::Pararead::getimproparam { params types } {  
   set par   {}

   # Reversed typelist
   set revtypes [lrevert $types]
   # Get wildcard typelist
   set xtypes [list [lindex $types 0] X X [lindex $types 3]]
   # Reversed wildcard typelist
   set rxtypes [list [lindex $revtypes 0] X X [lindex $revtypes 3]]

   # Check for each param set if it matches normal, reverse or including wildcards
   set found 0
   set foundparam {}
   foreach pset $params {
      set ptypes [lindex $pset 0]

      set found [string equal $ptypes $types]
      if {$found} { set foundparam $pset; break }

      set found [string equal $ptypes $revtypes]
      if {$found} {
 	 set foundparam $pset; 
	 break
      }
      set found [string equal $ptypes $xtypes]
      if {$found} { set foundparam $pset; break }
      set found [string equal $ptypes $rxtypes]
      if {$found} {
 	 set foundparam $pset; 
	 break
      }
   }
   if {!$found} {
      #puts "No parameters found for $types"
      return {}
   } else {
      return [list [lindex $foundparam 0] [lindex $foundparam 1]]
   }
}


######################################################################
### Read angle|dihed|improper lists from $psf.                     ###
### $type = angle|dihed|inproper                                   ###
### Returns a list of atom index lists.                            ###
######################################################################

proc ::Pararead::readpsfinfo { psf } {
   set fd [open $psf]

   # Read the psf file:
   set angles   [list]
   set diheds   [list]
   set imprps   [list]
   set excluded [list]
   set exclusions [list]
   set nangles 0
   set ndiheds 0
   set nimprps 0
   set ndonors 0
   set nacceptors 0
   set nexclude 0
   set iexcl 0
   set numread 0
   set lastindex 0
   set section {}
   foreach line [split [read -nonewline $fd] \n] {
      set keyword [lindex $line 1]

      # Look for beginning of next section
      if { [string match "!NTHETA*" $keyword] } { set section angl; puts $line; set nangles    [lindex $line 0]; continue }
      if { [string match "!NPHI*"   $keyword] } { set section dihe; puts $line; set ndiheds    [lindex $line 0]; continue }
      if { [string match "!NIMPHI*" $keyword] } { set section impr; puts $line; set nimprps    [lindex $line 0]; continue }
      if { [string match "!NDON*"   $keyword] } { set section dono; puts $line; set ndonors    [lindex $line 0]; continue }
      if { [string match "!NACC*"   $keyword] } { set section acce; puts $line; set nacceptors [lindex $line 0]; continue }
      if { [string match "!NNB*"    $keyword] } { set section excl; puts $line; set nexclude   [lindex $line 0]; continue }
      if { [string match "!NGRP*" [lindex $line 2]] } { set section ngrp; puts $line; set ngrp [lindex $line 0]; continue }

      if {$section=="angl"} {
	 foreach {i j k} $line {
	    lappend angles [list [expr {$i-1}] [expr {$j-1}] [expr {$k-1}]]
	 }
      } elseif {$section=="dihe"} { 
	 if {$nangles!=[llength $angles]} {
	    puts "Wrong number of angles listed!"
	 }	    
	 foreach {i j k l} $line {
	    lappend diheds [list [expr {$i-1}] [expr {$j-1}] [expr {$k-1}] [expr {$l-1}]]
	 }
      } elseif {$section=="impr"} { 
	 if {$ndiheds!=[llength $diheds]} {
	    puts "Wrong number of dihedrals listed!"
	 }	    
	 foreach {i j k l} $line {
	    lappend imprps [list [expr {$i-1}] [expr {$j-1}] [expr {$k-1}] [expr {$l-1}]]
	 }
      } elseif {$section=="dono"} { 
	 if {$nimprps!=[llength $imprps]} {
	    puts "Wrong number of impropers listed!"
	 }	
      } elseif {$section=="acce"} { 
	 #if {$ndonors!=[llength $donors]} {
	 #   puts "Wrong number of donors listed!"
	 #}	
      } elseif {$section=="excl"} { 
	 #if {$nacceptors!=[llength $acceptors]} {
	 #   puts "Wrong number of acceptors listed!"
	 #}
	 if {$iexcl<$nexclude} {
	    foreach item $line {
	       lappend excluded [expr $item-1]
	       incr iexcl
	    }
	 } else {
	    foreach curindex $line {
	       #lappend exclusions $curindex

	       #  Check for an illegal pointer     
	       if {$curindex>$nexclude} {
		  error [format "EXCLUSION INDEX %i LARGER THAN NUMBER OF EXLCUSIONS %i IN PSF FILE, EXCLUSION #%i\n"
			 [expr $curindex+1] $nexclude $numread];
	       }
	       #  Check to see if it matches the last index.  If so   
	       #  than this atom has no exclusions.  If not, then     
	       #  we have to build some exclusions      
	       if {$curindex != $lastindex} {
		  #puts "$curindex != $lastindex"
		  #  This atom has some exlcusions.  Loop from   
		  #  the last_index to the current index.  This  
		  #  will include how ever many exclusions this  
		  #  atom has          
		  for {set insertindex $lastindex} {$insertindex<$curindex} {incr insertindex} {
		     #  Assign the two atoms involved.      
		     #  The first one is our position in    
		     #  the list, the second is based on    
		     #  the pointer into the index list     
		     set a1 $numread;
		     set a2 [lindex $excluded $insertindex];
		     if { $a1 < $a2 } {
			lappend exclusions [list $a1 $a2]
		     } elseif { $a2 < $a1 } {
			lappend exclusions [list $a2 $a1];
		     } else {
			error "ATOM [expr $a1+1] EXCLUDED FROM ITSELF IN PSF FILE\n"
		     }
		  }
		  
		  set lastindex $curindex;
	       }
	       incr numread
	    }
	 }

      }    
   }

   close $fd
   return [list $angles $diheds $imprps $exclusions]
}

########################################################################
### Read bond, angle, dihed, improper, nonbonded, nbifx, hbond       ###
### parameters from $parfile and returns them in a list.             ###
########################################################################

proc ::Pararead::read_charmm_parameters { parfile } {
   set fd [open $parfile]

   # Read the parameter file:
   set bonds {}
   set angles {}
   set dihedrals {}
   set impropers {}
   set nonbonded {}
   set nbfix {};   # Explicit nonbonded pair interactions
   set hbonds {}
   set comment {}
   set section {}

   set skip 0
   foreach line [split [read -nonewline $fd] \n] {
      set trimmed [string trim $line]
      if {[string index $trimmed 0]=="!"} {
	 set comment $trimmed
	 continue
      }
      if {[string length $trimmed]==0} {
	 continue
      }
      set keyword [lindex $line 0]

      if {$skip} { set skip 0; continue }

      # Look for beginning of next section
      if { [string equal BONDS     $keyword] } { set section bond; continue }
      if { [string equal ANGLES    $keyword] } { set section angl; continue }
      if { [string equal DIHEDRALS $keyword] } { set section dihe; continue }
      if { [string equal IMPROPER  $keyword] } { set section impr; continue }
      if { [string equal NONBONDED $keyword] } { 
	 set section nonb; 
	 # Look for continued line
	 if {[lindex $line end] == "-"} {
	    # Skip line:
	    set skip 1
	 }
	 continue
      }
      if { [string equal NBFIX     $keyword] } { set section nbfi; continue }
      if { [string equal HBOND     $keyword] } { set section hbon; continue }

      if {$section=="nonb"} {
	 if {[llength $nonbonded] && [llength $comment] && [string first ! $line]>1} {
	    # append the second line comment if the ! is not at pos 0 or 1.
	    lset nonbonded end end [join [list [lindex $nonbonded end end] $comment]]
	 }
	 if {[lindex $line 4] == 0.0} {
	    set rem [lrange $line 7 end]
	    if {![llength $rem]} { set rem {{}} }
	    lappend nonbonded [list [lindex $line 0] [lrange $line 2 3] [lrange $line 5 6] $rem]
	 } else {
	    set rem [lrange $line 4 end]
	    if {![llength $rem]} { set rem {{}} }
	    lappend nonbonded [list [lindex $line 0] [lrange $line 2 3] {} $rem]
	 }
      } elseif {$section=="bond"} {
	 if {[llength $bonds] && [llength $comment]} {
	    # append the second line comment
	    lset bonds end end [join [list [lindex $bonds end end] $comment]]
	 }
	 lappend bonds     [list [lrange $line 0 1] [lrange $line 2 3] [lrange $line 4 end]]
      } elseif {$section=="angl"} {
	 if {[llength $angles] && [llength $comment]} {
	    # append the second line comment
	    lset angles end end [join [list [lindex $angles end end] $comment]]
	 }
	 set ub [lrange $line 5 6]
	 if {[string index $ub 0]=="!" || ![llength $ub]} {
	    lappend angles    [list [lrange $line 0 2] [lrange $line 3 4] [list] [lrange $line 5 end]]
	 } else  {
	    lappend angles    [list [lrange $line 0 2] [lrange $line 3 4] $ub [lrange $line 7 end]]
	 }
      } elseif {$section=="dihe"} {
	 if {[llength $dihedrals] && [llength $comment]} {
	    # append the second line comment
	    lset dihedrals end 2 [join [list [lindex $dihedrals end 2] $comment]]
	 }
	 lappend dihedrals [list [lrange $line 0 3] [lrange $line 4 6] [lrange $line 7 end]]
      } elseif {$section=="impr"} {
	 if {[llength $impropers] && [llength $comment]} {
	    # append the second line comment
	    lset impropers end 2 [join [list [lindex $impropers end 2] $comment]]
	 }
	 lappend impropers [list [lrange $line 0 3] [lrange $line 4 6] [lrange $line 7 end]]
      } elseif {$section=="nbfi"} {
	 lappend nbfix     [list [lrange $line 0 1] [lrange $line 2 3] [lrange $line 4 end]]
      } elseif {$section=="hbon"} {
	 lappend hbond     [list [lrange $line 0 1] [lrange $line 2 3] [lrange $line 4 end]]
      }
      set comment [list]
   }
   close $fd

   return [list $bonds $angles $dihedrals $impropers $nonbonded $nbfix $hbonds]
}




########################################
### Reverses the order of a list.    ###
########################################

proc ::Pararead::lrevert { list } {
   set newlist {}
   for {set i [expr [llength $list]-1]} {$i>=0} {incr i -1} {
      lappend newlist [lindex $list $i]
   }
   return $newlist
}


