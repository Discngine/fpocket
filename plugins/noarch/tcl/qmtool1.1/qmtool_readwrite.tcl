#
# Routines for reading/writing various zmatrix and gaussian log files
# This is crap I admit, the code just grew organically without reorganization.
# We end up parsing several times through the whole file.
# When the C-based parser will be written this should be avoided!
# Nevertheless this is a good template for the different sections that must
# be parsed.
#
# $Id: qmtool_readwrite.tcl,v 1.43 2007/09/12 13:41:59 saam Exp $
#

################################################
# Read a Z-matrix from a file.                 #
# This is basically a wrapper for read_zmat.   #
################################################

proc ::QMtool::read_zmtfile { file } {
   # Save data from current molecule
   molecule_export

   # Clear current namespace
   init_variables [namespace current]

   variable filename $file
   variable filetype "Z-matrix"

   if {![llength $file]} { return 0 }
   
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Didn't find file \"$file\""
      return 0
   }

   # Read the data and populate $cartesians and $atomproplist
   set fid [open $file r]
   read_zmatrix $fid
   close $fid

   variable cartesians
   if {[llength [join $cartesians]]} {
      variable havecart 1
   }

   # Write $cartesians into a pdb file and load that into vmd:
   variable molid [reload_cartesians_as_pdb $file]
   mol rename $molid $file

   set numatoms 0
   if {[molinfo top]>=0} { set numatoms [molinfo top get numatoms] }

   if {!$havecart && ([molinfo top]<0 || $numatoms==0)} {
      tk_messageBox -icon error -type ok \
	 -title Message \
	 -message "File $file contains no cartesian coordinates.\nPlease load a molecule first."
      clear_zmat
      return 0
   }

   update_vmd_bondlist
   return $molid
}

##################################################
# Load a gaussian simulation logfile and process #
# the information. This is the frontend we use.  #
# The actual file parser is read_gaussian_log.   #
##################################################

proc ::QMtool::load_gaussian_log { file {molid -1}} {
   # Save data from current molecule
   molecule_export

   variable filename $file
   variable filetype
   variable havecart
   variable simtype

   if {![llength $file]} { return 0 }
   
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Didn't find file \"$file\""
      return -2
   }

   set newmolid [read_gaussian_log $file $molid]

   # Check if cartesian coords are present
   set numatoms 0
   if {[molinfo top]>=0} { set numatoms [molinfo top get numatoms] }
   if {!$havecart && ([molinfo top]<0 || $numatoms==0)} {
      tk_messageBox -icon error -type ok \
	 -title Message \
	 -message "File $file contains no cartesian coordinates.\nPlease load a molecule first."
      clear_zmat
      return -3
   }

   variable nimag 0
   variable normalterm
   variable zmat

   if {($simtype=="Frequency" || $simtype=="Coordinate transformation")} {
      variable inthessian
      variable inthessian_kcal
      variable carthessian
      variable nimag 
      variable method
      variable basename
      variable lineintensities {}
      variable linewavenumbers {}
      #variable ncoords 
      set ncoords [lindex [lindex $zmat 0] 1]
      set natoms  [lindex [lindex $zmat 0] 0]

      # Read Thermochemistry section
      set thermal_energy [read_thermal_energy $file]

      if {$normalterm} {
	 set inthessian  [read_hessian $file $ncoords "internal"]
	 set carthessian [read_hessian $file [expr {3*$natoms}] "cartesian"]
	 set inthessian_kcal [convert_inthessian_kcal $inthessian $method $zmat]

	 # Regenerate VMD bonds only if internal coordinates are present.
	 # We regenerate it here because we need the bondlist in assign_fc_zmat->get_dihedral_multiplicity
	 if {[llength $zmat]>1} { update_vmd_bondlist }
	 assign_fc_zmat $inthessian_kcal
      }
      set linespectrum [read_harmonic_frequencies $file]
      if {[llength $linespectrum]} {
	 if {[winfo exists .qmtool.menu.analysis]} {
	    .qmtool.menu.analysis entryconfigure 1 -state normal
	 }
	 puts "Harmonic frequencies: [llength $linespectrum] ($nimag imaginary)"
	 foreach f $linespectrum {
	    lappend linewavenumbers [lindex $f 0]
	    lappend lineintensities [lindex $f 1]
	    #puts "Frequency: [lindex $f 0] 1/cm;  IR Intensity: [lindex $f 1] KM/Mole"
	 }
	 set filetype "Gaussian frequency logfile"
      }
   }
   
   if {$simtype=="Geometry optimization"} {
      set filetype "Gaussian geometry optimization logfile"
   }
   if {$simtype=="Single point"} {
      set filetype "Gaussian single point calculation logfile"
   }
   if {$simtype=="Rigid potential scan"} {
      set filetype "Gaussian rigid potential scan logfile"
   }
   if {$simtype=="Relaxed potential scan"} {
      set filetype "Gaussian relaxed potential scan logfile"
   }
   
   variable cartesians
   if {[llength [join $cartesians]]} { 
      variable havecart 1 
   }

#    variable espdipolemoment
#    if {[llength $espdipolemoment]} {
#       puts "Dipole moment from ESP charge distribution: $espdipolemoment"
#       puts "In input coordinates: [compute_dipolemoment]"
#    }

   # Update zmat only if internal coordinates are present:
   if {[llength $zmat]>1} { 
      # Identify the dihedral angles that describe out-of-plane bends
      set newzmat [find_improper_dihedrals $zmat]
      update_zmat $newzmat

      # Regenerate VMD bonds 
      update_vmd_bondlist
   }
   return $newmolid
}


################################################################
# Read in a Z-matrix.                                          #
# The file ID of an open file must be given, the file pointer  #
# should point to the beginning of the Z-matrix. I.e. any      #
# headers must be parsed already, except for blank lines       #
# or lines starting with a hash '#'. Delimiters for the        #
# Z-matrix can be any combination of whitespace, comma and     #
# slash.                                                       #
# First the definition block is read, then the 'Variable' and  #
# 'Constants' blocks are read. The Z-matrix is assumed to be   #
# terminated by a blank line or by a user-provided termination #
# string.                                                      #
# The Z-matrix will be stored in the variable zmat. It is a    #
# list of internal coordinates (bonds, angles, diheds and      #
# impropers). zmat is a misnomer, because it can store more    #
# than 3N-6 internal coordinates. This occurs when a           #
# "ModRedundant" section is present in the file where you can  #
# define as many coordinates as you like.                      #
# If cartesian coordinates are given instead of a Z-matrix     #
# then they will be read and stores in the variable cartesians #
# while zmat will just contain the header with the number of   #
# atoms.                                                       #
################################################################

proc ::QMtool::read_zmatrix { fid {termstring {}}} {
   set natoms 0
   set ncoords 0
   set nbonds 0
   set nangles 0
   set ndiheds 0
   set nimprops 0
   set havefc 0
   set havepar 0
   set haveintcoor 0
   set cart {}
   variable havecart 0
   variable atomproplist {}

   # Initialize zmat header
   variable zmat [list [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]]

   # First read in the complete Z-matrix
   while {![eof $fid]} {
      set line [string map {, " " / " "} [string trim [gets $fid]]]
      # Skip comments starting with '#':
      if {[string first "\#" $line]==0} { continue }

      # Skip leading blank lines
      if {!$natoms && ![llength $line]} { continue }

      # Check for user provided termination string
      if {[string match $termstring $line]} { break }
      puts "natoms $natoms; $line"

      # A blank line denotes the end of the cartesian and zmatrix input
      if {![llength $line] || [regexp "^variable.*|^constants:.*" [string tolower $line]]} {
	 set haveintcoor 1
	 break
      }

      # Check if we have a z-matrix or cartesian coords
      if {$natoms==0  && [llength $line]>1} {
	 puts "Cartesian coordinates given."
	 set havecart 1
      } 

      lappend zmatrix $line
      incr natoms
   }

   # See if we have to read in a variables section
    set readvariables 0
    foreach line $zmatrix {
       foreach {atom0 atom1 bond atom2 angle atom3 dihed} $line {break}
       if {![string is double $bond] || ![string is double $angle] || ![string is double $dihed]} {
 	 set readvariables 1
       }
    }

   #set vararray {}
   if {$readvariables} {
      while {![eof $fid]} {
	 set line [string map {, " " / " " = " "} [string trim [gets $fid]]]

	 # Terminated by blank line
	 if {![string length $line]} { break }

	 # Check for user provided termination string
	 if {[string match $termstring $line]} { break }

	 set var   [lindex $line 0]
	 set value [lindex $line 1]
	 array set vararray [list $var $value]
      }     
   }

   puts "Variables: [array get vararray]"

   set natoms 0
   set noncartlines 0
   foreach line $zmatrix {
      set atomlist {}
      set bond {}
      set angle {}
      set dihed {}
      incr natoms

      set name    [lindex $line 0]
      if {[string is alpha [string index $name 0]]} {
	 # Get canonical element symbol
	 regexp {[a-zA-Z]} $name element
	 set element [atomnum2element [element2atomnum $element]]
      } else {
	 set element [atomnum2element $name]
      }
      lappend atomproplist [list [expr {$natoms-1}] $element $name {} {} {} {} {} {} {} {} {} {}]
      
      # Check if we have cartesian coordinates in this line, i.e the format is
      # "name 0 x y z" or "name 0 x y z" while x may not be an integer: 
      # Example:
      #  O1                    0.178     0.       -1.348
      # or
      #  C,0,-1.2680085197,0.,0.5811050822 (the comma has been replaced by whitespace before)
      if { ( ([llength $line]==4 && !([string is integer [lindex $line 1]])) \
		|| ([llength $line]==5 && [lindex $line 1]==0 && !([string is integer [lindex $line 2]])) ) } { 
	 # These are cartesian coords. Add them and continue.
	 lappend cart [lrange $line end-2 end]

	 # Print the coordinates
	 foreach {x y z} [lrange $line end-2 end] {break}
	 puts [format "%4i %5s % 10.3f % 10.3f % 10.3f" $natoms $name $x $y $z]

	 continue 
      } 


      # If here, this is a non-cartesian zmatrix line
      # Format example: 
      # H 
      # O 1 R1 
      # O 2 R2 1 A 
      # H 3 R1 2 A 1 D 
      incr noncartlines
      foreach {a0 a1 bond a2 angle a3 dihed} $line {break}

      if {![string is double $bond]} {
	 set bond [lindex [array get vararray $bond] 1]
      }
      if {![string is double $angle]} {
	 set angle [lindex [array get vararray $angle] 1]
      }
      if {![string is double $dihed]} {
	 set dihed [lindex [array get vararray $dihed] 1]
      }

      # Print the line with replaced variables:
      puts [format "%4i %5s %5s %6s %5s %7s %5s %7s" $natoms $a0 $a1 [join [format_float "%.3f" $bond]] $a2 [join [format_float "%.2f" $angle]] $a3 [join [format_float "%.2f" $dihed]]]

      foreach atom [join [list $a0 $a1 $a2 $a3]] {
	 if {![string is integer $atom]} {
	    regexp {[a-zA-Z]} element
	    set atomnum [element2atomnum $element]
	    # If we have an atom label like H1 or C1W we search it in the list of
	    # existing atoms. Otherwise, i.e. if its just an element label we use
	    # the current line number (this only works for the first of the four atoms).
	    if {$atomnum>=0 && [llength [regsub [atomnum2element $atomnum] [string toupper $atom] {}]]} {
	       # Check if this atom is already in the list
	       set pos [lsearch [lrange $atomproplist 0 end-1] "* * $atom *"]
	       #puts "atom=$atom pos=$pos {$atomproplist}"
	       if {$pos>=0} {
		  set atom $pos
	       } elseif {$pos==-1} { set atom [expr {$natoms-1}] }
	    } else {
	       set atom [expr {$natoms-1}]
	    }
	 } else { incr atom -1 }
	 lappend atomlist $atom
      }
      lappend cart [get_cartesian_from_zmat $cart $atomlist [list $bond $angle $dihed]]

   
      # Bonds
      if {$natoms>1} {
	 set name $bond
	 set type "bond"
	 set val {}
	 incr nbonds
	 if {[string is double $bond] || [string is integer $bond]} {
	    set name R$natoms
	    set val $bond
	    incr havepar
	 }
	 lappend zmat [list $name $type [lrange $atomlist 0 1] $val {{} {}} {} {}]
      }
      # Angle
      if {$natoms>2} {
	 set name $angle
	 set type "angle"
	 set val {}
	 incr nangles
	 if {[string is double $angle] || [string is integer $angle]} {
	    set name A$natoms
	    set val $angle
	    incr havepar
	 }
	 lappend zmat [list $name $type [lrange $atomlist 0 2] $val {{} {} {} {}} {} {}]
      }
      # Dihed
      if {$natoms>3} {
	 set name $dihed
	 set type "dihed"
	 set val {}
	 incr ndiheds
	 if {[string is double $dihed] || [string is integer $dihed]} {
	    set name D$natoms
	    set val $dihed
	    incr havepar
	 }
	 lappend zmat [list $name $type $atomlist $val {{} {} {}} {} {}]
      }
   }

   # Update zmat header
   set ncoords [expr {$nbonds+$nangles+$ndiheds+$nimprops}]
   lset zmat 0 [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]

   variable cartesians [list $cart]
   variable atomproptags [list Index Elem Name Flags]
   if {$havecart} {
      # Atom names should be consisting of the element symbol and a number 
      puts "QMtool: Assign unique names for all atoms:"
      alias_atomnames
      puts ""
   }

   # If no atoms were read return just the zmat header
   if {!$natoms} { return }  

   # Sort the Z-matrix so that the bonds come first, then angles, then diheds
   if {$havepar!=$ncoords || $noncartlines} {
      set zmat [sort_zmat $zmat]
   }

   if {$haveintcoor && [llength $zmat]>1} {
      read_zmat_intcoor $fid $ncoords $termstring
   }

   if {[llength $zmat]>1} {
      # Identify the diheral angles that describe out-of-plane bends
      set zmat [find_improper_dihedrals $zmat]
      update_zmat $zmat
   }
}

proc ::QMtool::get_cartesian_from_zmat {cart atomlist intcoor} {
   if {[llength $atomlist]==1} { return {0 0 0} }
   foreach {a0 a1 a2 a3}      $atomlist {break}
   foreach {bond angle dihed} $intcoor  {break}
   set p0 [lindex $cart $a0]
   set p1 [lindex $cart $a1]
   if {[llength $atomlist]==2} { return [vecadd $p1 [list $bond 0 0]] }

   set p2 [lindex $cart $a2]
   if {[llength $atomlist]==3} {
      set p0 [vecadd $p1 [list 0 $bond 0]]
   } else {
      set p3 [lindex $cart $a3]
      set v21 [vecnorm [vecsub $p1 $p2]]
      set v23 [vecnorm [vecsub $p3 $p2]]
      set v10 [vecscale [vecnorm [vecadd $v21 $v23]] $bond]
      set p0 [vecadd $p1 $v10]
   }

   # Measure the angle difference
   set dot [vecdot [vecnorm [vecsub $p0 $p1]] [vecnorm [vecsub $p2 $p1]]]
   set acos [expr {acos($dot)}]
   set delta [expr {$angle-57.2957795786*$acos}]

   # Rotate the angle
   set m [trans angle $p0 $p1 $p2 $delta deg]
   set p0 [coordtrans $m $p0]

   # Rotate the dihedral
   set m [trans bond $p1 $p2 $dihed deg]
   return [coordtrans $m $p0]
}

proc ::QMtool::read_zmat_intcoor { fid ncoords termstring } {
   variable zmat
   # Read the internal coordinate section
   set nvars 0
   while {![eof $fid]} {
      set line [string map {, " " / " " = " "} [string trim [gets $fid]]]

      # Skip comments starting with '#':
      if {[string first "\#" $line]==0} { continue }

      # Skip leading blank line
      #if {!$ncoords && ![llength $line]} { continue }

      # Skip 'Constants:' line
      if {[regexp "^constants:.*" [string tolower $line]]} { continue }

      # Skip lines like " 5 tetrahedral angles replaced."
      if {[string match "*replaced." [string tolower $line]]} { continue }

      # Block is terminated by blank line
      if {![llength $line]} { break }

      # Check for user provided termination string
      if {[string match $termstring $line]} { break }

      # Check if the current variable is scanned
      set scan {}
      if {[string match "*Scan*" $line]} {
	 # Due to fixed field width in the output "Scan" is sometimes not separated by space:
	 set line [string map {"Scan" " Scan"} $line]
	 variable scansteps    [lindex $line 3]
	 variable scanstepsize [lindex $line 4]
	 set scanwidth    [expr {$scansteps*$scanstepsize}]
	 set scan [list $scansteps $scanstepsize]
      }

      # The name of the variable
      set name [lindex $line 0]
      set ind 0; # Start counting with 1, as entry 0 is the header
      set curpos -1

      # Loop through atom list and try to find current variable
      foreach entry $zmat {
	 set curpos [lsearch -exact $entry $name]
	 if { $curpos==0 } { 
	    # Found the variable name
	    break
	 }
	 incr ind
      }
      if { $curpos!=0 } { continue }

      # Value of the coord entry
      set value [lindex $line 1]

      # Fetch the matching entry from zmat and insert value
      set newentry [lindex $zmat $ind]
      lset newentry 3 $value

      # Set the scanning values
      if {[llength $scan]}  {
	 lset newentry 5 [regsub {[S]} [lindex $entry 5] {}]S
	 lset newentry 6 $scan
      }

      # Update z-matrix
      lset zmat $ind $newentry
      incr nvars
   }
}


########################################################
# Read the ModRedundant field.                         #
# Here the user can add and modify as many cartesian   #
# and internal coordinates as he wishes. QMtool uses   #
# this to specify the internal coordinates explicitely #
# while the Z-matrix field is always filled with the   #
# cartesian coordinates.                               #
########################################################

proc ::QMtool::read_modredundant_coords { fid } {
   variable zmat
   variable atomproplist

   if {![llength $zmat]} {
      set natoms 0
      if {[molinfo top]>=0} {
	 set natoms [molinfo top get numatoms]
      }
      set zmat [list [list $natoms 0 0 0 0 0 0 0 0]]
   }

   set natoms   [lindex [lindex $zmat 0] 0]
   set ncoords  [lindex [lindex $zmat 0] 1]
   set nbonds   [lindex [lindex $zmat 0] 2]
   set nangles  [lindex [lindex $zmat 0] 3]
   set ndiheds  [lindex [lindex $zmat 0] 4]
   set nimprops [lindex [lindex $zmat 0] 5]
   variable cartesians
   set cart [join $cartesians]
   variable coordtype

   variable nmods 0
   set modred {}
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Skip leading blank lines
      if {!$nmods && ![llength $line]} { continue }

      # Skip comment on logfiles
      if {[string match {The following ModRedundant input*} $line]} { continue }

      # in input files the block is terminated by a blank line
      if {$nmods && ![llength $line]} { break }

      # We only read Link0
      if {[string tolower [lindex $line 0]]=="--link1--"} { break }

      # Block is terminated by blank line
      if { ![string is integer [lindex $line 0]] && [string length [lindex $line 0]]>1} { break }

      lappend modred $line

      # Get the type specifier and remove it from $line
      set gtype {}
      regexp {^[[:space:]]*[XBADLO]} $line gtype
      set line [regsub {^[[:space:]]*[XBADLO]} $line ""]

      # Count the number of atom indices:
      set nind 0
      set wild 0
      foreach t $line {
	 if {$t=="*"} { incr wild }
	 if {!([string is integer $t] || $t=="*")} { break }
	 incr nind
	 if {$nind>4} { break }
      }

      # Get the action flag:
      set flag {}
      regexp {[AFBKRDHS]} $line flag

      # Coordinate is deleted, we don't consider this at the moment
      #if {[lsearch -regexp $line {[KR]}]>=0} { continue }

      # Atoms
      if {$nind==1} {

	 # Add/Edit cartesian coordinates (THIS DOESN'T WORK RELIABLY YET)
# 	 if {($flag=="B" || ![llength $flag]) && !$wild} { 
# 	    set xyz [lrange $line 1 3]
# 	    set atomnum [expr {[lindex $line 0]-1}]
# 	    set ele [atomnum2element $atomnum]
# 	    set name $ele
# 	    set fixed {}
# 	    set index [expr {[lindex $line 0]-1}]
# 	    puts "index=$index; xyz=$xyz"
# 	    if {[lindex $line 0]<[llength $atomproplist]} {
# 	       # Modifying existing coordinate
# 	       if {[llength $xyz]==3} {
# 		  lset cart $index $xyz
# 	       }
# 	       set_atomprop Element $index $ele
# 	       set_atomprop Name    $index $name
# 	    } else {
# 	       # Appending new coordinate
# 	       if {[llength $xyz]==3} {
# 		  lappend cart $xyz 
# 	       }
# 	       lappend atomproplist [list $index $ele $name {} {} {} {} {} {} {} {} {} {}]
# 	       incr natoms
# 	    }
# 	    incr nmods
# 	    continue
# 	 } elseif { $flag=="B" || ![llength $flag]} { incr nmods; continue }

	 # Ignore the "B" flag
	 if {$flag=="B" || ![llength $flag]} { incr nmods; continue }

         # Read fixed atoms
	 if {$wild} {
	    if {[llength $flag]} {
	       set i 0
	       foreach atom $atomproplist {
		  set oldflag [lindex $atom [get_atomprop_index Flags]]; 
		  set newflag {}
		  if {$flag=="A"} {
		     set newflag [regsub {[F]} $oldflag {}]
		  } elseif {![regexp [subst {\[$flag\]}] $oldflag]} { 
		     append newflag $flag 
		  }
		  lset atomproplist $i [get_atomprop_index Flags] $newflag;
		  incr i
	       }
	    }
	 } else {
	    # Treat the flags, e.g. "F"
	    set atomnum [expr {[lindex $line 0]-1}]
	    set oldflag [lindex $atomproplist $atomnum [get_atomprop_index Flags]];
	    set newflag {}
	    if {$flag=="A"} {
	       set newflag [regsub {[F]} $oldflag {}]
	    } elseif {![regexp [subst {\[$flag\]}] $oldflag]} { 
	       append newflag $flag 
	    }
	    lset atomproplist $atomnum [get_atomprop_index Flags] $newflag; 
	 }
	 incr nmods;
	 continue
      }

      # We don't consider wildcards for internal coordinates:
      if {$wild && !($wild==$nind && [string match "*R*" $flag])} { incr nmods; continue }

      if {$flag=="B"} { set flag {}}
      if {$flag=="A"} { set flag {}}

      # Check if this coordinate was scanned
      set scan {}
      if {[string match "*S*" $flag]} {
	 set pos [lsearch $line "*S*"]
	 set scan [lrange $line [expr {$pos+1}] [expr {$pos+2}]]
	 puts "scan=$scan"
      }

      set name {}
      set val {}
      set ilist {}
      set type {}

      # Bonds
      if {$nind==2} {
	 if {[llength [lindex $line 2]] && [string is double [lindex $line 2]]} { 
	    if {[string match "+=*" [lindex $line 4]]} {
	       set val {}
	    } else {
	       set val [lindex $line 2]
	    }
	 }
	 incr nbonds
	 set name R$nbonds
	 # Check for "B * * R"
	 if {$wild==$nind && [string match "*R*" $flag]} { 
	    incr ncoords [expr {1-$nbonds}]
	    set zmat [lsearch -all -inline -not $zmat "R*"]
	    set nbonds 0
	    continue
	 }
	 set ilist [list [expr {[lindex $line 0]-1}] [expr {[lindex $line 1]-1}]]
	 set type "bond"

	 # Check if the bond was already defined
	 set pos [lsearch -regexp $zmat ".+bond\\s{($ilist|[lrevert $ilist])}"]
	 if {$pos>=0} {
	    lset zmat $pos [list $name $type $ilist $val {{} {}} $flag $scan]
	    #continue
	 } else {
	    lappend zmat [list $name $type $ilist $val {{} {}} $flag $scan]
	 }
      } elseif {$nind==3} {
	 # Angles
	 if {[llength [lindex $line 3]] && [string is double [lindex $line 3]]} {
	    if {[string match "+=*" [lindex $line 4]]} {
	       set val {}
	    } else {
	       set val [lindex $line 3]
	    }
	 }
	 incr nangles
	 set name A$nangles
	 # Check for "A * * * R"
	 if {$wild==$nind && [string match "*R*" $flag]} { 
	    incr ncoords [expr {1-$nangles}]
	    set zmat [lsearch -all -inline -not -regexp $zmat "^(A|L).+"]
	    set nangles 0
	    continue
	 }
	 set ilist [list [expr {[lindex $line 0]-1}] [expr {[lindex $line 1]-1}] [expr {[lindex $line 2]-1}]]
	 set type "angle" 
	 if {$gtype=="L"} { set type "lbend" } 

	 # Check if the angle was already defined
	 set pos [lsearch -regexp $zmat ".+(angle|lbend)\\s{($ilist|[lrevert $ilist])}"]
	 if {$pos>=0} {
	    set name [lindex $zmat $pos 0]
	    lset zmat $pos [list $name $type $ilist $val {{} {} {} {}} $flag $scan]
	    #continue
	 } else {
	    lappend zmat [list $name $type $ilist $val {{} {} {} {}} $flag $scan]
	 }
      } elseif {$nind==4} {
	 # Diheds
	 if {[llength [lindex $line 4]] && [string is double [lindex $line 4]]} {
	    if {[string match "+=*" [lindex $line 4]]} {
	       set val {}
	    } else {
	       set val [lindex $line 4]
	    }
	 }

	 if {$gtype=="O"} {
	    set type "imprp"
	    incr nimprops
	    set name O$nimprops
	    # Check for "O * * * * R"
	    if {$wild==$nind && [string match "*R*" $flag]} { 
	       incr ncoords [expr {1-$nimprops}]
	       set zmat [lsearch -all -inline -not $zmat "O*"]
	       set nimprops 0
	       continue
	    }
	 } else {
	    set type "dihed"
	    incr ndiheds
	    set name D$ndiheds
	    # Check for "D * * * * R"
	    if {$wild==$nind && [string match "*R*" $flag]} { 
	       incr ncoords [expr {1-$ndiheds}]
	       set zmat [lsearch -all -inline -not $zmat "D*"]
	       set ndiheds 0
	       continue
	    }
	 }
	 set ilist [list [expr {[lindex $line 0]-1}] [expr {[lindex $line 1]-1}] \
		       [expr {[lindex $line 2]-1}] [expr {[lindex $line 3]-1}]]

	 # Check if the dihed/imprp was already defined
	 set pos [lsearch -regexp $zmat ".+(dihed|imprp)\\s{($ilist|[lrevert $ilist])}"]
	 if {$pos>=0} {
	    lset zmat $pos [list $name $type $ilist $val {{} {} {}} $flag $scan]
	    #continue
	 } else {
	    lappend zmat [list $name $type $ilist $val {{} {} {}} $flag $scan]
	 }
      } else {
	 puts "read_modredundant: Unknown syntax in line $nmods:"
	 puts $line
      }


      if {[llength $scan]} {
	 # Get the scan range
	 variable scansteps    [lindex $scan 0]
	 variable scanstepsize [lindex $scan 1]
	 variable optmaxcycles
	 variable simtype "Relaxed potential scan"
	 if {$optmaxcycles==1} {
	    variable simtype "Rigid potential scan"
	 }
      }
      incr nmods
      incr ncoords
   }


   lset zmat {0 0} $natoms
   lset zmat {0 1} $ncoords
   lset zmat {0 2} $nbonds
   lset zmat {0 3} $nangles
   lset zmat {0 4} $ndiheds
   lset zmat {0 5} $nimprops

   # Identify the diheral angles that describe out-of-plane bends
   set newzmat [find_improper_dihedrals $zmat]
   update_zmat $newzmat

   # If all coordinates are killed at first, then we have explicit internal coords.
   # (Linear bends can be given with 3 or 4 wildcards, so we look for both.)
   if {[llength $modred] && $coordtype=="ModRedundant" && \
	  [regexp {^B[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 0]] && \
	  [regexp {^A[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 1]] && \
	 ([regexp {^L[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 2]] || \
	  [regexp {^L[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 2]]) && \
	  [regexp {^D[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 3]] && \
	  [regexp {^O[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*\*[[:space:]]*R$} [lindex $modred 4]] } {
      set coordtype "Internal (explicit)"
   }

   variable cartesians [list $cart]
   variable atomproptags [list Index Elem Name Flags]
}


#################################################
# Sort the zmat, so that bonds come first, then #
# angles, then linear bends, then diheds.       #
#################################################

proc ::QMtool::sort_zmat { zmat } {
   set header [list [lindex $zmat 0]]
   set R {}
   set A {}
   set L {}
   set D {}
   set T {}
   set O {}
   set zmat [lsort -dictionary -index 0 $zmat]

   # FIXME: Use glob instead of regexp
   set Rind [lsearch -all $zmat {* *bond *}]
   if {[llength $Rind]} {
      set R [lrange $zmat [lindex $Rind 0] [lindex $Rind end]]
   }
   
   set Aind [lsearch -all -regexp $zmat {^[[:alnum:]]+\sangle\s.+}]
   if {[llength $Aind]} {
      set A [lrange $zmat [lindex $Aind 0] [lindex $Aind end]]
   }

   set Lind [lsearch -all -regexp $zmat {^[[:alnum:]]+\slbend\s.+}]
   if {[llength $Lind]} {
      set L [lrange $zmat [lindex $Lind 0] [lindex $Lind end]]
   }

   set Dind [lsearch -all -regexp $zmat {^D[[:alnum:]]+\sdihed\s.+}]
   if {[llength $Dind]} {
      set D [lrange $zmat [lindex $Dind 0] [lindex $Dind end]]
   }

   set Tind [lsearch -all -regexp $zmat {^T[[:alnum:]]+\sdihed\s.+}]
   if {[llength $Tind]} {
      set T [lrange $zmat [lindex $Tind 0] [lindex $Tind end]]
   }

   set Oind [lsearch -all -regexp $zmat {^[[:alnum:]]+\simprp\s.+}]
   if {[llength $Oind]} {
      set O [lrange $zmat [lindex $Oind 0] [lindex $Oind end]]
   }
   
   set zmat [join [list $header $R $A $L $D $T $O]]

   return $zmat
}


###########################################################################
# We must sort the internal coordinates the same way Gaussian does it,    #
# in order to obtain the correct assignment of the force constants.       #
###########################################################################

proc ::QMtool::sort_zmat_like_gaussian {} {
   variable zmat

   # first we need temp lists for sorting: 
   set tmpbondlist  {}
   set tmpanglelist {}
   set tmplbendlist {}
   set tmpdihedlist {}
   set tmpimprplist {}
   foreach entry $zmat {
      if {[string match "*bond" [lindex $entry 1]]} {
	 lappend tmpbondlist  [concat [lindex $entry 0] [lindex $entry 2]]
      }
      if {[string equal "angle" [lindex $entry 1]]} {
	 lappend tmpanglelist [concat [lindex $entry 0] [lrange [lindex $entry 2] 1 end]]
      }
      if {[string equal "lbend" [lindex $entry 1]]} {
	 lappend tmplbendlist [concat [lindex $entry 0] [lrange [lindex $entry 2] 1 end]]
      }
      if {[string equal "dihed" [lindex $entry 1]]} {
	 if {[lindex $entry 2 1]<[lindex $entry 2 2]} {
	    lappend tmpdihedlist [concat [lindex $entry 0] [lrange [lindex $entry 2] 1 end]]
	 } else {
	    lappend tmpdihedlist [concat [lindex $entry 0] [lrange [lrevert [lindex $entry 2]] 1 end]]
	 }
      }
      if {[string equal "imprp" [lindex $entry 1]]} {
	 lappend tmpimprplist [concat [lindex $entry 0] [lrange [lindex $entry 2] 1 end]]
      }
   }

   set R [lsort -integer -index 1 $tmpbondlist]
   set A [lsort -integer -index 1 $tmpanglelist]
   set L [lsort -integer -index 1 $tmplbendlist]
   set D [lsort -integer -index 1 $tmpdihedlist]
   set O [lsort -integer -index 1 $tmpimprplist]
   
   set newzmat [list [lindex $zmat 0]]
   foreach entry $R {
      set pos [lsearch $zmat "[lindex $entry 0]*"]
      lappend newzmat [lindex $zmat $pos]
   }
   foreach entry $A {
      set pos [lsearch $zmat "[lindex $entry 0]*"]
      lappend newzmat [lindex $zmat $pos]
   }
   foreach entry $L {
      set pos [lsearch $zmat "[lindex $entry 0]*"]
      lappend newzmat [lindex $zmat $pos]
   }
   foreach entry $D {
      set pos [lsearch $zmat "[lindex $entry 0]*"]
      lappend newzmat [lindex $zmat $pos]
   }
   foreach entry $O {
      set pos [lsearch $zmat "[lindex $entry 0]*"]
      lappend newzmat [lindex $zmat $pos]
   }
   update_zmat $newzmat
}


##############################################
# Parse the route section for keywords:      #
##############################################

proc ::QMtool::parse_route_section { route } {
   variable method {}
   variable basisset {}
   variable geometry "Z-matrix"
   variable guess    "Guess (Harris)"
   variable coordtype {}
   variable simtype "Single point"
   variable otherkey {}
   variable calcesp 0
   variable calcnpa 0
   variable calcnbo 0
   variable optmaxcycles {}
   variable availmethods

   # case insensitive:
   set rt [string tolower $route]
   # get uniform keyword format:
   set rt [string map {" = " "=" " =" "=" "= " "=" "(" "=("} $rt]
   # repair some wrong mappings:
   set rt [string map {"==" "=" "iop=(" "iop("} $rt]

   # Remove route keyword
   set rt [lrange $rt 1 end]

   # Geom keyword
   set foundlist [lsearch -all -regexp $rt {geom=}]
   foreach hit $foundlist {
      # Must search for the index again, as it might have shifted
      set found [lsearch -regexp $rt {geom=}]
      if {$found>=0} { 
	 set keyword [lindex $rt $found]
	 set rt [join [lreplace $rt $found $found {}]]
	 set vlist [get_keyword_vlist $keyword]
	 if {[lsearch -regexp $vlist "check"]>=0} { set geometry "Checkpoint file" }
	 if {[lsearch -regexp $vlist "allcheck"]>=0} { 
	    set guess "Read geometry and wavefunction from checkfile"
	 }
	 if {[lsearch -regexp $vlist "modredundant"]>=0} { set coordtype "Modredundant" }
      }
   }
   
   # SP (single point) keyword
   set foundlist [lsearch -all -regexp $rt {\ssp\s}]
   foreach hit $foundlist {
      set found [lsearch -regexp $rt {\ssp\s}]
      set rt [join [lreplace $rt $found $found {}]]
      set simtype "Single point"
   }

   # Opt/Freq/Scan keyword
   set found [lsearch -regexp $rt {opt}]
   if {$found>=0} { set simtype "Geometry optimization" }
   set found [lsearch -regexp $rt {freq}]
   if {$found>=0} { set simtype "Frequency"; set coordtype "Internal (auto)" }
   set found [lsearch -regexp $rt {scan}]
   if {$found>=0} { set simtype "Rigid potential scan" }
   variable hinderedrotor 0

   set foundlist [lsearch -all -regexp $rt {opt|freq}]
   foreach hit $foundlist {
      set found [lsearch -regexp $rt {opt|freq}]
      if {$found>=0} { 
	 set keyword [lindex $rt $found]
	 set rt [join [lreplace $rt $found $found {}]]
	 set vlist [get_keyword_vlist $keyword]
	 if {[lsearch -regexp $vlist "^redun"]>=0} {
	    set coordtype "Internal (auto)" 
	 }
	 if {[lsearch -regexp $vlist "modred"]>=0} {
	    set coordtype "ModRedundant" 
	 }
	 if {[lsearch -regexp $vlist "hind"]>=0} {
	    set hinderedrotor 1
	 }
	 if {[lsearch -regexp $vlist "readfc"]>=0} {
	    if {$simtype=="Frequency"} {
	       set simtype "Coordinate transformation"
	    }
	 }
	 if {[lsearch -regexp $vlist "maxcycle="]>=0} {
	    variable optmaxcycles [lindex [split [lsearch -regexp -inline $vlist "maxcycle="] "="] 1]
	 }
      }
   }
   
   # SCRF solvent keyword
   variable availsolvents
   variable solvent "None"
   variable PCMmethod {}
   array set availsolv $availsolvents
   set foundlist [lsearch -all -regexp $rt {scrf=}]
   #puts "rt=$rt"
   #puts "foundlist=$foundlist"
   foreach hit $foundlist {
      # Must search for the index again, as it might have shifted
      set found [lsearch -regexp $rt {scrf=}]
      if {$found>=0} { 
	 set keyword [lindex $rt $found]
	 set rt [join [lreplace $rt $found $found {}]]
	 set vlist [get_keyword_vlist $keyword]
	 if {[lsearch -regexp $vlist "cpcm|iefpcm|scipcm|ipcm|dipole"]>=0} { 
	    variable PCMmethod [string toupper [lsearch -inline -regexp $vlist "cpcm|iefpcm|scipcm|ipcm|dipole"]]
	 }
	 if {[lsearch $vlist "solvent=*"]>=0}  { 
	    set solv [lindex [split [lsearch -inline $vlist "solvent=*"] "="] 1]
	    variable solvent [lindex [array get availsolv $solv] 1 0]
	    variable dielectric [lindex [array get availsolv $solv] 1 2]
	 }
      }
   }

   # Pop keyword
   set foundlist [lsearch -all -regexp $rt {pop=}]
   #puts $rt
   #puts $foundlist
   foreach hit $foundlist {
      # Must search for the index again, as it might have shifted
      set found [lsearch -regexp $rt {pop=}]
      if {$found>=0} { 
	 set keyword [lindex $rt $found]
	 set rt [join [lreplace $rt $found $found {}]]
	 set vlist [get_keyword_vlist $keyword]
	 if {[lsearch -regexp $vlist "esp"]>=0} { set calcesp 1 }
	 if {[lsearch -regexp $vlist "mk"]>=0}  { set calcesp 1 }
	 if {[lsearch -regexp $vlist "npa"]>=0}     { set calcnpa 1 }
	 if {[lsearch -regexp $vlist "nbo"]>=0}     { set calcnbo 1 }
	 if {[lsearch -regexp $vlist "nboread"]>=0} { set calcnboread 1 }
      }
      #puts $rt
   }

   # Guess keyword
   set foundlist [lsearch -all -regexp $rt {guess=}]
   foreach hit $foundlist {
      set found [lsearch -regexp $rt {guess=}]
      if {$found>=0} { 
	 set keyword [lindex $rt $found]
	 set rt [join [lreplace $rt $found $found ""]]
	 set vlist [get_keyword_vlist $keyword]
	 if {[lsearch -regexp $vlist "^read"]>=0} {
	    set guess "Take guess from checkpoint file" 
	 }
	 if {[lsearch -regexp $vlist "^harris"]>=0} {
	    set guess "Guess (Harris)" 
	 }
      }
   }
   
   set tmprt [join [split $rt "/"]]
   foreach key [string tolower $availmethods] {
      set found [lsearch $tmprt $key]
      if {$found>=0} { 
	 set method [string toupper $key]
	 set rt [regsub "$key/" $rt ""] 
      }
   }

   foreach key {"STO-3G" "3-21G" "6-31G" "6-31G*" "6-31+G*" "5D" "6D" "7F" "10F"} {
      set found [lsearch [string toupper $rt] $key]
      if {$found>=0} { 
	 if {$key=="5D" || $key=="7F"} {
	    append basisset " $key"
	 } else {
	    set basisset $key 
	 }
	 set rt [join [lreplace $rt $found $found {}]]
      }
   }

   # The rest is stored as 'other keywords'
   set otherkey [string trim $rt]
}

proc ::QMtool::get_keyword_vlist {keyword} {
   set value [string range $keyword [expr {[string first = $keyword]+1}] end]
#   set value [lindex [split $keyword "="] 1]
   return [split [string map {"(" {} ")" {}} $value] ","]
}


################################################
# Read a gaussian input file.                  #
################################################
# Gaussian 03 input consists of a series of lines in an ASCII text file. 
# The basic structure of a Gaussian input file includes several different sections:

#   * Link 0 Commands: Locate and name scratch files (not blank line terminated).
#   * Route section (# lines): Specify desired calculation type, model chemistry 
#     and other options (blank line terminated).
#   * Title section: Brief description of the calculation (blank line terminated).
#   * Molecule specification: Specify molecular system to be studied (blank line terminated).
#   * Optional additional sections: Additional input needed for specific job types
#     (usually blank line terminated).

# Many Gaussian 03 jobs will include only the second, third, and fourth sections.

proc ::QMtool::read_gaussian_input { file {intomolid -1} } {
   # Save data from current molecule
   molecule_export
   # Clear current namespace
   init_variables [namespace current]
   # (the new namespace will be generated later, if it is needed and when we know the new molecule number)

   variable filetype "Gaussian input"
   variable filename $file
   variable checkfile
   variable fromcheckfile
   variable nproc
   variable memory
   variable route {}
   variable title {}
   variable autotitle {}
   variable extratitle {}
   variable totalcharge {}
   variable multiplicity {}
   variable geometry
   variable nimag {}
   variable havecart 0

   if {![llength $file]} { return 0 }
   
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	 -message "Didn't find file \"$file\""
      return 0
   }

   variable basename [file rootname $file]
   set molspec 0
   set fid [open $file r]

   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Read leading % fields in Gaussian input files:
      if {[string first "%" $line]==0} { 
	 set line [split [string range $line 1 end] "="]
	 if {[lindex $line 0]=="chk"} {
	    set checkfile [lindex $line 1]
	    set basename [file rootname $checkfile]
	    continue
	 }
	 if {[lindex $line 0]=="nproc"} {
	    set nproc [lindex $line 1]
	    continue
	 }
	 if {[lindex $line 0]=="mem"} {
	    set memory [lindex $line 1]
	    continue
	 }
      }


      # Read the route section
      if {[string first "\#" $line]==0 || 
	  ([llength $route] && [llength $line] && ![llength $title])} {
	 append route $line
	 continue
      }

      # Check if title section is present:
      if {[llength $route] && [string match {*allcheck*} [string tolower $route]]} { break }

      # Read the title section
      if {![llength $line] && [llength $route] && ![llength $title]} { 
	 set title 1
	 continue 
      }
      if {[llength $line] && [llength $title] && [llength $line] && !$molspec} { 
	 if {$title==1} { 
	    set title "$line" 
	 } else {
	    append title "\n$line"
	 }
	 continue
      }

      # Read molecule specifications
      set line [join [split $line ",/"]]
      if {![llength $line] && [llength $route] && [llength $title] && !$molspec} { 
	 set molspec 1
	 continue
      }
      if {$molspec && [llength $line]} {
	 set totalcharge  [lindex $line 0]
	 set multiplicity [lindex $line 1]
	 break
      }

      # Else
      if {![llength $route]} {
	 error "Bad format in gaussian input file: No route section found!"
      }
   }

   # Remove autotitle and extratitle and determine $fromcheckfile
   set nnltitle [string map {"\n" " "} $title]
   if {[string match "*<qmtool> parent=*.chk </qmtool>*" $nnltitle]} { 
      regexp {<qmtool>\s*parent=.*.chk </qmtool>} $nnltitle extratitle
      set extratitle [string trim $extratitle]
      set fromcheckfile [lindex [split [lindex $extratitle 1] "="] 2]
      set title [regsub {<qmtool>\s*parent=.*\.chk\s*</qmtool>} $title ""]
   }

   # Support for very old format of autotitle. Cen be removed when code is reorganized
   regexp {___(Single|Transformation|Geometry|Frequency)\s.+___} $nnltitle autotitle
   set title [regsub {___(Single|Transformation|Geometry|Frequency)\s.+___} $title ""]
   set title [string trim $title]

   regexp {<qmtool>\s*simtype="(Single|Transformation|Geometry|Frequency|Rigid|Relaxed).+" </qmtool>} $nnltitle autotitle
   set title [regsub {<qmtool>\s*simtype="(Single|Transformation|Geometry|Frequency|Rigid|Relaxed).+" </qmtool>} $title ""]
   set title [string trim $title]
   

   if {[winfo exists .qm_setup.edit.titleentry]} {
      .qm_setup.edit.titleentry delete 0.0 end
      .qm_setup.edit.titleentry insert 0.0 $title
   }

   #puts "route=$route"
   #puts "title=$title"
   #puts "total charge=$totalcharge"
   #puts "multiplicity=$multiplicity"


   # Parse the route section for keywords:
   # -------------------------------------

   parse_route_section $route

   
   # Read the atom field:
   # --------------------

   variable zmat
   variable cartesians
   if {$geometry!="Checkpoint file"} {
      read_zmatrix $fid

      if {[llength [join $cartesians]]} { 
	 variable havecart 1; 
	 puts "Read [llength $cartesians] sets of [llength [lindex $cartesians 0]] Cartesian coordinates"
      }

      update_zmat
      puts "Read [lindex [lindex $zmat 0] 1] internal coordinates"
   }

   # Read the ModRedundant field
   # ---------------------------
   variable nmods
   read_modredundant_coords $fid
   close $fid
   puts "Read $nmods ModRedundant lines"

   variable molid
   variable molidlist
   if {$havecart} {
      set tmppdb "${basename}_tmp.pdb"
      set molid [reload_cartesians_as_pdb $tmppdb $intomolid]
      
      # Delete the tmp tmppdb file:
      if {[file exists $tmppdb]} { file delete $tmppdb }
      
      # Rename the molecule to the logfile name:
      mol rename $molid $file
   }

   # Check if cartesian coordinates are really present:
   set numatoms 0
   if {[molinfo top]>=0} { set numatoms [molinfo $molid get numatoms] }
   if {!$havecart && ([molinfo top]<0 || $numatoms==0)} {
      tk_messageBox -icon error -type ok \
	 -title Message \
	 -message "File $file contains no cartesian coordinates.\nPlease load a molecule first."
      clear_zmat
      return 0
   }


   # zmat was changed in read_modredundant
   update_zmat

   # Regenerate VMD bonds only if internal coordinates are present:
   if {[llength $zmat]>1} { update_vmd_bondlist }

   
   update_molidlist
   update_intcoorlist

   setstatus "Molecule loaded" green3
   return $molid
}

###############################################################
# Read a gaussian logfile and extract cartesian and internal  #
# coordinates which are stored in the variables $cartesian    #
# and $zmat. Atom names, the chemical element and the atom    #
# index are stored in $atomproplist.                          #
# If a molid was specified in the argument list load          #
# coordinates into that molecule.                             #
###############################################################

proc ::QMtool::read_gaussian_log { file {intomolid -1}} {
   # If a molid was specified in the argument list load coordinates into that molecule
   if {$intomolid>=0} {
      if {[lsearch [molinfo list] $intomolid]<0} {
	 error "::QMtool::read_gaussian_log: Couldn't insert data into molecule $intomolid. It doesn't exist!"
      }
      variable molid $intomolid
   }

   set fid [open $file r]

   variable checkfile {}
   variable nproc  {}
   variable memory {}
   variable basename {}
   variable simtype {}
   variable scfenergies {}
   variable normalterm 0
   variable orientation {}
  

   # Read the route section
   set dash 0
   set tmproute {}
   while {![eof $fid]} {
      set line [string trimleft [gets $fid]] 
      
      # Look for --- lines surrounding route and title sections
      if {[string first "-" $line]==0} { 
	 set dash [expr !$dash]; 
	 if {[llength $tmproute]} { break }
	 continue
      }
      
      # Read fields starting with % in Gaussian input files:
      if {[string first "%" $line]==0} { 
	 set line [split [string range $line 1 end] "="]
	 
	 if {[lindex $line 0]=="chk"} {
	    variable checkfile [lindex $line 1]
	    variable basename [file rootname $checkfile]
	    continue
	 }
	 if {[lindex $line 0]=="nproc"} {
	    variable nproc [lindex $line 1]
	    continue
	 }
	 if {[lindex $line 0]=="mem"} {
	    variable memory [lindex $line 1]
	    continue
	 }
      }
      
      # Read the route string
      if {[string first "\#" $line]==0 || ([llength $tmproute] && $dash)} {
	 append tmproute "$line"
	 continue
      }
   }


   # Parse the route section for keywords:
   # -------------------------------------
   
   parse_route_section $tmproute
   
   variable method    
   variable basisset  
   variable geometry  
   variable guess     
   variable coordtype 
   variable simtype   
   variable otherkey  
   variable calcesp   
   variable calcnbo   
   
   variable title {}
   variable autotitle {}
   variable extratitle {}
   variable fromcheckfile {}
   variable nimag 0
   variable route $tmproute
   
   # Read the title section:
   set dash 0
   while {![eof $fid]} {
      set line [string range [gets $fid] 1 end]
      
      # Look for --- lines surrounding route and title sections
      if {[string first "---" $line]==0} { 
	 set dash [expr !$dash]; 
	 if {[llength $title]} { break }
	 continue
      }
      
      # Read the title string
      if {$dash && [llength $tmproute]} {
	 append title $line
	 continue
      }
   }
   
   set title [string map {{\n} {}} $title]
   
   # Remove autotitle and extratitle and determine $fromcheckfile
   set nnltitle [string map {"\n" " "} $title]
   if {[string match "*<qmtool> parent=*.chk </qmtool>*" $nnltitle]} { 
      regexp {<qmtool>\s*parent=.*.chk </qmtool>} $nnltitle extratitle
      set extratitle [string trim $extratitle]
      set fromcheckfile [lindex [split [lindex $extratitle 1] "="] 2]
      set title [regsub {<qmtool>\s*parent=.*\.chk\s*</qmtool>} $title ""]
   }

   # Support for very old format of autotitle. Cen be removed when code is reorganized
   regexp {___(Single|Transformation|Geometry|Frequency)\s.+___} $nnltitle autotitle
   set title [regsub {___(Single|Transformation|Geometry|Frequency)\s.+___} $title ""]
   set title [string trim $title]
   
   regexp {<qmtool>\s*simtype="(Single|Transformation|Geometry|Frequency|Rigid|Relaxed).+" </qmtool>} $nnltitle autotitle
   set title [regsub {<qmtool>\s*simtype="(Single|Transformation|Geometry|Frequency|Rigid|Relaxed).+" </qmtool>} $title ""]
   set title [string trim $title]
   
   if {[winfo exists .qm_setup.edit.titleentry]} {
      .qm_setup.edit.titleentry delete 0.0 end
      .qm_setup.edit.titleentry insert 0.0 $title
   }
      

   # Read molecule specifications:
   set zmatgiven 0
   while {![eof $fid]} {
      set line [string trim [gets $fid]] 

      # Z-matrix given explicitely?      
      if {[string match "Z-Matrix taken from the checkpoint file:" $line] ||
          [string match "Symbolic Z-matrix:" $line] ||
	  [string match "Redundant internal coordinates taken from checkpoint file:" $line]} {
	 set zmatgiven 1 
      }

      if {[lindex $line 0]=="Charge" && [lindex $line 3]=="Multiplicity"} {
	 variable totalcharge 0
	 variable multiplicity 0
	 set totalcharge [lindex $line 2]
	 set multiplicity [lindex $line 5]
	 break
      }
   }

   variable zmat {}
   variable cartesians

   # Get the Z-matrix (but not from potential scans invoked by the "Scan" keyword.
   # It's too complicated to parse and we don't need it in this case):

   if {$zmatgiven} {
      read_zmatrix $fid "Recover connectivity data from disk."

      if {!($simtype=="Rigid potential scan")} {
	 # We read the ModRedundant section only to determine if we used explicit internal coords.
	 
	 # XXX  FIXME  XXX
	 # When the modredundant coordinates really mean a geometry modification, not just a 
	 # definition of internal coordinates, then incorrectt stuff would be returned.
	 # We must read the "Input orientation" accordinlgy!
	 # This is done a couple of lines below.
	 # 
	 # Read the ModRedundant field
	 # ---------------------------
	 variable nmods
	 read_modredundant_coords $fid
	 puts "Read $nmods ModRedundant lines"
      }
   }
      
#   if {$simtype!="Rigid potential scan" && $simtype!="Relaxed potential scan"} 
      # We always have to read the Initial Parameters field because Gaussian sometimes
      # reorders the internal coordinates.
      puts "Reading internal coordinates from 'Initial Parameters'."
      set natoms [lindex [lindex $zmat 0] 0]
      set ret [read_gaussian_intcoords $fid $natoms]
      
      if {!$ret && ($simtype=="Frequency" || $simtype=="Coordinate transformation")} {
	 if {[llength $zmat]<=1} {
	    # Try to read the internal coordinate definitions from the NMA in intcoords section
	    set ret [read_intcoords_from_nma $fid $natoms]
	 }
      }
      
      # Identify the diheral angles that describe out-of-plane bends
      set zmat [find_improper_dihedrals $zmat]
      update_zmat $zmat
      
      if {!$ret && ($simtype=="Frequency" || $simtype=="Coordinate transformation")} {
	 if {[llength $zmat]<=1} {
	    tk_messageBox -icon error -type ok -title Message \
	       -message "Couldn't read internal coordinate table!"
	    return {}      
	 }
	 
	 # Sort the Z-matrix the same way Gaussian does it (hopefully)
	 sort_zmat_like_gaussian 
	 puts "Couldn't read internal coordinate table, trying to use sorted modredundant input."
	 puts "This could in rare cases lead to a wrong assignment between force constants"
	 puts "and internal coordinates!"
      }
 # endif  

   # If no cartesian coords were given or ModRedundant coordinates were read,
   # we must read them from 'Input orientation'.
   variable nmods
   if {![llength [join $cartesians]] || $nmods>0} {
      if {![llength [join $cartesians]]} {
	 puts "No cartesian coordinates given in Z-matrix."
	 puts "Reading 'Input Orientation'."
	 set ret [read_gaussian_input_orientation $fid]
      } else {
	 puts "Replacing current cartesian coordinates by coordinates from 'Input Orientation'."
	 set ret [read_gaussian_input_orientation $fid -replace]
      }

      if {$ret<=0} {
	 tk_messageBox -icon error -type ok -title Message \
	    -message "Couldn't read 'Input orientation'!"
	 return {}
      }
   }

   # We need a tmp pdb file in order to load the cartesian coordinates 
   # into VMD.
   set rootname [file rootname $file]
   set tmppdb "${rootname}_qmtool_tmp.pdb"
   set newmolid -1


   set msgret {}
   if {$simtype=="Geometry optimization" || [string match {CBS-*} $method] || \
       $simtype=="Rigid potential scan" || $simtype=="Relaxed potential scan"} {
      # The following decision to read all frames of only the first or the last
      # is only done because TCL parsing very large logfiles can be quite slow.
      set msgret "all"; #[reload_cartesians_msgbox]

      if {$msgret=="all"} {
	 # This reads all coordinate frame and puts the cartesians into the pdb file.
	 # It also reads the Mulliken charges wich are given for the first and the last frame.
	 read_gaussian_cartesians $fid $tmppdb all
	 set numframes [llength $cartesians]
	 puts "Read $numframes sets of cartesian coordinates. XXX"

	 # If a molid was specified in the argument list load coordinates into that molecule
	 if {$intomolid>=0 && [lsearch [molinfo list] $intomolid]>=0} {
	    mol addfile $tmppdb $intomolid
	    #puts "imol=$intomolid"
	 } else {
	    set newmolid [mol load pdb $tmppdb]
	    #puts "mol=$newmolid"
	 }

	 # Remove old trace
	 if {$newmolid>=0} {
	    foreach t [trace info variable vmd_frame($newmolid)] {
	       trace remove variable vmd_frame($newmolid) write ::QMtool::update_frame
	    }
	 }

	 # Trace the current frame number
	 trace add variable ::vmd_frame($newmolid) write ::QMtool::update_frame

      } elseif {$msgret=="first"} {
	 # This reads the first coordinate frame and puts the cartesians into the pdb file.
	 # It also reads the Mulliken charges.
	 read_gaussian_cartesians $fid $tmppdb first

	 # If a molid was specified in the argument list load coordinates into that molecule
	 if {$intomolid>=0 && [lsearch [molinfo list] $intomolid]>=0} {
	    mol addfile $tmppdb $intomolid
	 } else {
	    set newmolid [mol load pdb $tmppdb]
	 }

	 variable numframespresent
	 puts "Read first frame of $numframespresent cartesian coordinate sets."

      } elseif {$msgret=="last"} {
	 # This reads the last coordinate frame and puts the cartesians into the pdb file.
	 # It also reads the Mulliken charges.
	 read_gaussian_cartesians $fid $tmppdb last
	 set numframes [llength $cartesians]

	 # If a molid was specified in the argument list load coordinates into that molecule
	 if {$intomolid>=0 && [lsearch [molinfo list] $intomolid]>=0} {
	    mol addfile $tmppdb $intomolid
	 } else {
	    set newmolid [mol load pdb $tmppdb]
	 }
	 variable numframespresent
	 puts "Read last frame of $numframespresent cartesian coordinate sets."
      } elseif {$msgret=="none"} { 
	 set newmolid [molinfo top]
      }

      # Add new molecule to the list
      if {$intomolid>=0 && [lsearch [molinfo list] $intomolid]>=0} {

	 trace add variable vmd_initialize_structure($::QMtool::molid) \
	    write ::QMtool::molecule_assert
      } else {
	 molecule_add $newmolid
      }

   } elseif {[llength [join $cartesians]]} {
      # Ok, this is no geometry optimization, i.e. we have only one frame.
      if {$simtype=="Rigid potential scan" || $simtype=="Relaxed potential scan"} {
	 #read_rigid_potscan $fid
      } else {
	 # Since this is no geometry opt, we just read the charges once.
	 
	 # Read the mulliken charges
	 puts "Reading Mulliken charges."
	 read_gaussian_mulliken $fid
	 
	 # Read the ESP charges, if present, and store them in $atomproplist
	 puts "Reading ESP charges."
	 read_gaussian_espcharges $fid
	 
	 # Read the NPA charges, if present, and store them in $atomproplist
	 puts "Reading NPA charges."
	 read_gaussian_npacharges $fid
      }

      # Load the molecule in VMD:
      set newmolid [reload_cartesians_as_pdb $tmppdb]
   }
   close $fid;

   # Delete the tmp tmppdb file:
   if {[file exists $tmppdb]} { file delete $tmppdb }

   # Rename the molecule to the logfile name:
   if {$newmolid>=0} {
      mol rename $newmolid $file
   }

   # Keeping QMtools lists up to date:
   update_molidlist
   update_intcoorlist

   # Read the SCF energies
   set scf [read_scf_energies $file]

   if {[llength $scf]} {
      variable scfenergies $scf
   }

   setstatus "Molecule loaded." green3
   variable molid
   return $molid
}

proc ::QMtool::reload_cartesians_msgbox { } {
   set m [toplevel ".msgbox"]
   wm title $m "Load molecule"
   wm resizable $m 0 0
   label $m.label -width 50 -font {Helvetica 12} \
      -text "Load cartesian coordinates as new molecule?"
   variable msgret "last"
   frame $m.buttons
   radiobutton $m.buttons.first -text "Load first coordinate frame only" \
      -variable ::QMtool::msgret -value "first"
   radiobutton $m.buttons.last -text "Load last coordinate frame only" \
      -variable ::QMtool::msgret -value "last"
   radiobutton $m.buttons.all -text "Load all coordinate frames" \
      -variable ::QMtool::msgret -value "all"
   if {[molinfo top]>=0} {
      if {[molinfo top get numframes]>0} {
	 radiobutton $m.buttons.none \
	    -text "Don't load cartesians, map internal coords on current top molecule" \
	    -variable ::QMtool::msgret -value "none"
	 pack $m.buttons.first $m.buttons.last $m.buttons.all $m.buttons.none -anchor w 
      }
   }
   pack $m.buttons.first $m.buttons.last $m.buttons.all -anchor w 

   
   button $m.ok -text Ok -width 8 -command {destroy .msgbox}
   pack $m.label $m.buttons $m.ok -pady 3
   tkwait window $m
   return $msgret
}

#########################################################
# Read internal coords from 'Initial Parameters section #
# of gaussian logfile and update the $zmat.             #
# If present the 'Definition' of the internal coords    #
# will be read to fill the 'atomlist' field in the      #
# Z-matrix.                                             #
#########################################################

proc ::QMtool::read_gaussian_intcoords { fid {natoms 0}} {
   set offset 0;
   set typelist {};
   set modredzmat $::QMtool::zmat
   set zmat {}

   set ncoords 0
   set nbonds 0
   set nangles 0
   set ndiheds 0
   set nimprops 0
   set havefc 0
   set havepar 0

   # Remember file position. In case no Initial Parameter section is found, we can rewind.
   set filepos [tell $fid]

   # Initialize zmat header
   set zmat [list [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]]
   set cart {}
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }
      if {[string match "!    Initial Parameters    !" $line]} {
	 incr offset;
      }
      
      # We must find out if the IC value is in the 2nd or 3rd field
      if {$offset==4} {
	 set tag [lindex $line  2];  # the second field is either Value or Definition
	 if {$tag=="Value"} {
	    set icfield 2;
	 } else {
	    set icfield 3;
	 }
      }

      if {$offset>5} {
	 if {[string match "----------------*" $line]} {
	    break
	 }

	 set name [lindex $line 1];
	 set type [string index $name 0]
	 switch $type {
	    R { set type bond; incr nbonds }
	    A { set type angle; incr nangles }
	    D { set type dihed; incr ndiheds }
	    T { set type dihed; incr ndiheds }
	    O { set type imprp; incr nimprops }
	    X { continue }
	    Y { continue }
	    Z { continue }
	 }

	 set indexlist {}
	 if {$icfield==3} {
	    # the first field is the Definition
	    set definition [lindex $line 2]; 
	    set atomlist [lindex [split $definition "()"] 1]
	    set atomlist [string map {, " "} $atomlist]
	    # if it is a linear bend coord we have to omit the last two indices
	    if {[string index $definition 0]=="L"} {
	       set atomlist [lrange $atomlist 0 2]
	       set type lbend
	    }
	    foreach atom $atomlist {
	       lappend indexlist [expr {$atom-1}]
	    }
	 }

	 set flag {}
	 set scan {}
	 if {[string match "*bond" $type]} {
	    set val [lindex $line $icfield]
	    # Check if the bond was already defined
	    set pos [lsearch -regexp $modredzmat ".+bond\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {}} $flag $scan]
	 } elseif {[string equal "angle" $type] || [string equal "lbend" $type]} {
	    set val [lindex $line $icfield]
	    # Check if the angle was already defined
	    set pos [lsearch -regexp $modredzmat ".+(angle|lbend)\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {} {} {}} $flag $scan]
	 } elseif {[string equal "dihed" $type]} {
	    set val [lindex $line $icfield]
	    # Check if the dihed/imprp was already defined
	    set pos [lsearch -regexp $modredzmat ".+(dihed|imprp)\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {} {}} $flag $scan]
	 }
	 incr ncoords;
      }
   }

   set havepar 1
   lset zmat 0 [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]

   if {[llength $zmat]<=1} { 
      puts "No 'Initial Parameters' section found!"
      seek $fid $filepos
      return 0 
   }

   update_zmat $zmat
   return 1
}

proc ::QMtool::read_intcoords_from_nma { fid {natoms 0}} {
   set found 0;
   set typelist {};
   set modredzmat $::QMtool::zmat
   set zmat {}

   set ncoords 0
   set nbonds 0
   set nangles 0
   set ndiheds 0
   set nimprops 0
   set havefc 0
   set havepar 0
   variable molid

   # Remember file position. In case no Initial Parameter section is found, we can rewind.
   set filepos [tell $fid]

   # Initialize zmat header
   set zmat [list [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]]
   set cart {}
   set planar 0
   set planarcenters {}
   while {![eof $fid]} {
      set line [gets $fid]

      # Look for planar centers, these must be removed from the internal coordinates list
      if {[string match " Check for planar centers*" $line]} { set planar 1; continue }

      if {$planar} {
	 if {![string is integer [lindex $line 0]]} { set planar 0; continue }
	 set indexes {}
	 foreach ind [lrange $line 0 3] {
	    lappend indexes [expr {$ind-1}]
	 }
	 set names [get_names_for_conf $indexes]
	 puts [format "Planar center: %4s %4s %4s %4s ($indexes) will be removed from internal coordinate list" \
		  [lindex $names 0] [lindex $names 1] [lindex $names 2] [lindex $names 3] [lindex $line 4]]
	 # If a planar tricoordinate center where A is bonded to B, C, D is found, then Gaussian adds 
	 # the explicit dihedrals CABD and DABC.
	 # These improper dihedrals will not show up in the internal coordinate set that is used to compute
	 # the internal hessian. Thus we log them here to exclude them when we read in the coordinate list.
	 lappend planarcenters [list [lindex $indexes 2] [lindex $indexes 0] \
				   [lindex $indexes 1] [lindex $indexes 3]]
	 lappend planarcenters [list [lindex $indexes 3] [lindex $indexes 0] \
				   [lindex $indexes 1] [lindex $indexes 2]]
	 continue
      }

      # Look for the beginning of parameter list
      if {[string match "   Reduced Moments ---*" $line]} {
	 set found 1
	 continue
      }
      
      if {$found} {
	 if {[string match " ----------------*" $line]} {
	    break
	 }

	 set indexlist {}
	 # The coordinate definition looks like R( 1, 3), A( 2, 1, 3) or D(15, 2, 5,10)
	 set definition [string range $line 0 20]; 
	 set type     [string index [lindex $definition 0] 0]
	 set atomlist [lindex [split $definition "()"] 1]
	 set atomlist [string map {, " "} $atomlist]
	 # if it is a linear bend coord we have to omit the last two indices
	 if {[string index $definition 0]=="L"} {
	    set atomlist [lrange $atomlist 0 2]
	    set type lbend
	 }

	 foreach atom $atomlist {
	    lappend indexlist [expr {$atom-1}]
	 }

	 # Remove planar centers from internal coordinate list:
	 if {[lsearch $planarcenters $indexlist]>=0} { continue }

	 switch $type {
	    R { incr nbonds;   set name $type$nbonds;   set type bond;  }
	    A { incr nangles;  set name $type$nangles;  set type angle; }
	    D { incr ndiheds;  set name $type$ndiheds;  set type dihed; }
	    T { incr ndiheds;  set name $type$ndiheds;  set type dihed; }
	    O { incr nimprops; set name $type$nimprops; set type imprp; }
	    X { continue }
	    Y { continue }
	    Z { continue }
	 }

	 set flag {}
	 set scan {}
	 set val {}
	 if {[string match "*bond" $type]} {
	    #set val [measure bond $indexlist molid $molid]
	    # Check if the bond was already defined
	    set pos [lsearch -regexp $modredzmat ".+bond\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {}} $flag $scan]
	 } elseif {[string equal "angle" $type] || [string equal "lbend" $type]} {
	    #set val [measure angle $indexlist molid $molid]
	    # Check if the angle was already defined
	    set pos [lsearch -regexp $modredzmat ".+(angle|lbend)\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {} {} {}} $flag $scan]
	 } elseif {[string equal "dihed" $type]} {
	    #set val [measure dihed $indexlist molid $molid]
	    # Check if the dihed/imprp was already defined
	    set pos [lsearch -regexp $modredzmat ".+(dihed|imprp)\\s{($indexlist|[lrevert $indexlist])}"]
	    if {$pos>=0} {
	       set flag [lindex $modredzmat $pos 5]
	       set scan [lindex $modredzmat $pos 6]
	    }
	    lappend zmat [list $name $type $indexlist $val {{} {} {}} $flag $scan]
	 }
	 incr ncoords;
      }
   }

   set havepar 1
   lset zmat 0 [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]

   # Rewind to the previous position
   seek $fid $filepos

   if {[llength $zmat]<=1} { 
      puts "No 'NMA in internal coordinates' section found!"
      return 0 
   }

   update_zmat $zmat
   return 1
}


#########################################################
# Load cartesian coordinates as pdb file.               #
# Creates a temp pdb file, loads the molecule and       #
# returns the molid of the new molecule. If a pdb file  #
# name is specified this one will be used instead of a  #
# tmpfile  and it will not be deleted after loading.    #
# If $into molid is specified then the coordinates will #
# be added to this molecule.                            #
#########################################################

proc ::QMtool::reload_cartesians_as_pdb { {pdbfile {}} {intomolid -1} } {
   set tmppdb "qmtool_tmpfile.pdb"
   if {![llength $pdbfile]} { set $pdbfile $tmppdb }

   if {![write_cartesians_as_pdb $pdbfile]} { return -1 }

   puts "Loading cartesians as autogenerated new molecule $pdbfile"

   set newmolid -1;

   # If a molid was specified in the argument list load coordinates into that molecule
   if {$intomolid>=0 && [lsearch [molinfo list] $intomolid]>=0} {
      set newmolid [mol addfile $pdbfile type pdb $intomolid]
   } else {
      set newmolid [mol load pdb $pdbfile]
      molecule_add $newmolid
   }

   # Delete the temporary pdb file
   if {[file exists $tmppdb]} { file delete $tmppdb }

   return $newmolid
}

#########################################################
# Write cartesian coordinates as pdb file.              #
#########################################################

proc ::QMtool::write_cartesians_as_pdb { pdbfile } {
   variable cartesians

   if {![llength $cartesians]} { return 0 }
 
   set fid [open $pdbfile w]
   foreach coordset $cartesians {
      set ret [write_coordset_to_pdb $fid $coordset]
      if {!$ret} { error "Couldn't write coordset to $pdbfile." }
   }

   close $fid
   return 1
}

proc ::QMtool::write_coordset_to_pdb { fid coordset } {
   variable atomproplist
   if {![llength $coordset]} { return 0 }

   set index 1
   set resid 1
   if {[llength $coordset]!=[llength $atomproplist]} {
      error "llength \$coordset=[llength $coordset]; llength \$atomproplist=[llength $atomproplist]"
   }
   foreach coord $coordset atomprop $atomproplist {
      set x [lindex $coord 0]
      set y [lindex $coord 1]
      set z [lindex $coord 2]
      set name [lindex $atomprop [get_atomprop_index Name]]
      set elem [lindex $atomprop [get_atomprop_index Elem]]
      puts $fid [format "ATOM  %5i %4s UNK  %4i    %8.3f%8.3f%8.3f  1.00  0.00      QMT %2s" \
		    $index $name $resid $x $y $z $elem]
      incr index
   }
   puts $fid "ENDMDL"

   return 1
}

#########################################################
# Read cartesian coordinates from input orientation     #
#########################################################

proc ::QMtool::read_gaussian_cartesians { fid pdbfile {frames last}} {
   variable optcompleted 0

   set pdb [open $pdbfile w]

   set skip "-skip"
   if {$frames=="all" || $frames=="first"} {
      set skip "-noskip"
   }

   set num 0
   set filepos 0
   set lastfilepos 0
   variable cartesians
   while {![eof $fid]} {
      set lastfilepos $filepos
      set filepos [tell $fid]
      # If $frames==last we skip the reading of the input ori, the function returns {}
      set ret [read_gaussian_input_orientation $fid $skip]

      # if -1 is returned no input orientation section was found
      if {$ret<0} { break }
      if {$ret!=0} { 
	 # If "first" is selected we only count the frames
	 if {$frames=="first" && $num>0} { incr num; continue }

	 if {$num==0} {
	    # Read the mulliken charges only for the first and later for the last frame
	    # (the others are not present in normal optimizations)
	    read_gaussian_mulliken $fid
	 }

	 write_coordset_to_pdb $pdb [lindex $cartesians end]
      }
      incr num
   }

   # If all frames were read we have to get the Mulliken charges for the last frame
   if {$frames=="all"} {
      seek $fid $lastfilepos
      # Read the mulliken charges
      read_gaussian_mulliken $fid
   }

   # if only the last frame was requested we rewind the file to the last filepos
   # and read the coordinates
   if {$frames=="last"} {
      seek $fid $lastfilepos
      set skip "-noskip"
      set ret [read_gaussian_input_orientation $fid $skip]
      if {$ret>0} { 
	 # Read the mulliken charges
	 read_gaussian_mulliken $fid
	 write_coordset_to_pdb $pdb [lindex $cartesians end]
      }
   }
   close $pdb

   variable numframespresent $num
}


#########################################################
# Read cartesian coordinates from input orientation     #
# for one frame and appends the data to $cartesians.    #
# Also the atomproplist will be updated.                #
#########################################################

proc ::QMtool::read_gaussian_input_orientation { fid args } {
   set natoms 0
   set offset 0;
   set xfield 0
   set skip 0;
   set addframe 1;
   if {[lsearch  $args "-replace"]>=0} { set addframe 0 }
   if {[lsearch  $args "-skip"]>=0}    { set skip 1 }
   variable optcompleted
   variable havecart
   variable cartesians
   variable orientation
   set cart {}; #$cartesians
   set atomprops {}

   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      if {[string match "-- Stationary point found." $line]} {
	 puts "Optimization completed. -- Stationary point found."
	 set optcompleted 1
	 #return -3
      }

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }

      if {[string match "SCF Done:*" $line] || [string match "Energy=* NIter=*" $line]} {
	 set newframe 1
      }

      if {[string match "*Input orientation:*" $line]} {
	 incr offset;
	 set orientation "Input"
	 if {$skip} { return 0 }
      } elseif {[string match "*Z-Matrix orientation:*" $line] && $orientation!="Input"} {
	 incr offset;
	 set orientation "Z-matrix"
	 if {$skip} { return 0 }
      } elseif {[string match "*Standard orientation:*" $line] && $orientation!="Input" && $orientation!="Z-matrix"} {
	 incr offset;
	 set orientation "Standard"
	 if {$skip} { return 0 }
      }
      
      
      # We must find out if the coordinates start in the 3rd or 4th field
      if {$offset==4} {
	 set xfield [lsearch $line X]
	 if {$xfield<0} { error "Error reading Gaussian cartesians! Couldn't determine coordinate field." }
      }

      if {$offset>5} {
	 if {[string match "--------*" $line]} {
	    variable havecart 1
	    break
	 }

	 set xyz [lrange $line $xfield end]
	 # if {[llength $cartesians]} { puts $cartesians; error "read_gaussian_input_orientation: Cartesians already given!" }
	 set atomnum [lindex $line 1]
	 set ele [atomnum2element $atomnum]
	 lappend atomprops [list $natoms $ele $ele {} {} {} {} {} {} {} {} {} {}]
	 lappend cart $xyz
	 incr natoms
      }
   }

   if {$offset==0} { return -1 }
   if {![llength $cart] && ![llength $cartesians]} { return -2 }
   variable havecart 1
   variable cartesians 
   variable atomproplist 
   if {[llength $cart]} {
      if {$addframe || ![llength $cartesians]} {
	 lappend cartesians $cart
      } else {
	 lset cartesians end $cart
      }
      if {![llength $atomproplist]} {
	 variable atomproplist $atomprops
	 variable atomproptags [list Index Elem Name Flags]
      }
   }
   return 1
}


#########################################################
# Read Mulliken charges from Gaussian logfile.          #
#########################################################

proc ::QMtool::read_gaussian_mulliken { fid } {
   variable havemulliken 0
   set offset 0;

   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [string trim [gets $fid]]

      # Stop reading on errors
      if {[string match "Error termination *" $line]} { puts $line; return 0 }

      # Stop reading when next section beginns
      if {[string match "* orientation:" $line]} {
	 puts "No mulliken charges found."
	 seek $fid $filepos
	 return 0
      }

      # We only read Link0
      if {[string match "Normal termination of Gaussian*" $line]} { 
	 puts $line; 
	 variable normalterm 1; 
	 return 1
      }

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }
      if {[string match "Mulliken atomic charges:" $line]} {
	 incr offset;
      }
      
      if {$offset>2} {
	 if {[string match "Sum of Mulliken charges=*" $line]} {
	    set totalcharge [lindex $line 4]
	    break
	 }
	 set index   [expr {[lindex $line 0]-1}]
	 set_atomprop Mullik $index [lindex $line 2]
      }
   }

   set offset 0
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Stop reading on errors
      if {[string match "Error termination *" $line]} { puts $line; return 0 }

      # We only read Link0
      if {[string match "Normal termination of Gaussian*" $line]} { 
	 puts $line;  variable normalterm 1; return 0
      }

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }
      if {[string match "Atomic charges with hydrogens summed into heavy atoms:" $line]} {
	 incr offset;
      }
      
      if {$offset>2} {
	 if {[string match "Sum of Mulliken charges=*" $line]} {
	    set totalcharge [lindex $line 4]
	    set havemulliken 1
	    break
	 }
	 set index   [expr {[lindex $line 0]-1}]
	 set_atomprop MulliGr $index [lindex $line 2]
      }
   }
   set offset 0
   while {![eof $fid]} {
      set line [string trim [gets $fid]]
      if {$offset==1} {
	 variable dipolemoment [list [lindex $line 1] [lindex $line 3] [lindex $line 5]]
	 puts "Dipole moment: $dipolemoment"
	 break
      }
      if {[string match "Dipole moment (field-independent basis, Debye):*" $line]} {
	 incr offset
      }
   }
   variable atomproptags
   lappend atomproptags Mullik MulliGr
   return 1
}


###########################################################
# assign internal coordinates to $allzmat for each frame  #
###########################################################

proc ::QMtool::assign_intcoords_to_all_frames { zmat molid } {
   variable allzmat {}

   if {$molid<0} { return }
   set numframes [molinfo $molid get numframes]

   # initialize empty zmat
   for {set i 0} {$i<$numframes} {incr i} {
      lappend allzmat $zmat
   }

   # Loop through all internal coordinates
   set e 0
   foreach entry $zmat {
      if {$e==0} { incr e; continue }

      set name  [lindex $entry 0]
      set type  [lindex $entry 1]
      set ilist [lindex $entry 2]
      set flag  [lindex $entry 5]
      set scan  [lindex $entry 6]
      set atom0 [lindex $ilist 0]
      set atom1 [lindex $ilist 1]
      set atom2 {}
      set atom3 {}
      set sel0 [atomselect $molid "index $atom0"]
      set sel1 [atomselect $molid "index $atom1"]
      set sel2 {}
      set sel3 {}
      if {$type=="angle" || $type=="lbend" || $type=="dihed"} {
	 set atom2 [lindex $ilist 2]
	 set sel2 [atomselect $molid "index $atom2"]
      }
      if {$type=="dihed"} {
	 set atom3 [lindex $ilist 3]
	 set sel3 [atomselect $molid "index $atom3"]
      }

      # Now loop the conformation through all frames
      for {set frame 0} {$frame<$numframes} {incr frame} {
	 molinfo $molid set frame $frame
	 $sel0 frame $frame
	 $sel1 frame $frame
	 set pos0 [join [$sel0 get {x y z}]]
	 set pos1 [join [$sel1 get {x y z}]]
	 if {[string match "*bond" $type]} {
	    set val [veclength [vecsub $pos0 $pos1]]
	    lset allzmat $frame $e [list $name $type $ilist $val {{} {}} $flag $scan]
	 }
	 if {$type=="angle" || $type=="lbend"} {
	    $sel2 frame $frame
	    set pos2 [join [$sel2 get {x y z}]]
	    set val [bond_angle $pos0 $pos1 $pos2]
	    lset allzmat $frame $e [list $name $type $ilist $val {{} {} {} {}} $flag $scan]
	 }
	 if {$type=="dihed"} {
	    $sel2 frame $frame
	    $sel3 frame $frame
	    set pos2 [join [$sel2 get {x y z}]]
	    set pos3 [join [$sel3 get {x y z}]]
	    set val [dihed_angle $pos0 $pos1 $pos2 $pos3]
	    lset allzmat $frame $e [list $name $type $ilist $val {{} {} {}} $flag $scan]
	 }
      }
      incr e
   }
}


################################################
# Read SCF energies from a file.               #
################################################

proc ::QMtool::read_scf_energies { file } {
   set scfenergies {}

   set fid [open $file r]
   set hart_kcal 1.041308e-21; # hartree in kcal
   set mol 6.02214e23;

   set num 0
   set ori 0
   set tmpscf {}
   set optstep 0
   set scanpoint 0
   variable simtype
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Stop reading on errors
      if {[string match "Error termination*" $line]} { puts $line; return $scfenergies }

      # We only read Link0
      if {[string match "Normal termination of Gaussian*" $line]} { variable normalterm 1; break }

      if {$simtype=="Relaxed potential scan"} {
	 if {[string match "Step number * out of a maximum of * on scan point * out of *" $line]} {
	    set optstep   [lindex $line 2]
	    set scanpoint [lindex $line 12]
	    set scansteps [lindex $line 15]
	    #puts "SCAN: optstep $optstep on scan point $scanpoint out of $scansteps"
	 }
      }

      if {[string match "SCF Done:*" $line] || [string match "Energy=* NIter=*" $line]} {
	 if {[string match "SCF Done:*" $line]} {
	    set scf [lindex $line 4]
	 } else {
	    set scf [lindex $line 1]
	 }
	 set scfkcal [expr {$scf*$hart_kcal*$mol}]
	 if {$num==0} { set ori $scf }
	 set scfkcalori [expr {($scf-$ori)*$hart_kcal*$mol}]
	 # In case of a relaxed potential scan we replace the previous energy of the same scanstep,
	 # otherwise we just append all new scf energies
	 if {$optstep==1 || !($simtype=="Relaxed potential scan")} {
	    if {[llength $tmpscf]} { lappend scfenergies $tmpscf; set tmpscf {} }
	    puts [format "%i: SCF = %f hart = %f kcal/mol; rel = %10.4f kcal/mol" $num $scf $scfkcal $scfkcalori]
	 }
	 set tmpscf [list $scfkcal $scfkcalori]

	 incr num
      }

   }
   close $fid
   if {[llength $tmpscf]} { lappend scfenergies $tmpscf }

   if { [llength $scfenergies]>1 && [winfo exists .qmtool] } { 
      .qmtool.menu.analysis entryconfigure 0 -state normal
   }

   return $scfenergies
}


######################################################
# Extract Hessian in internal coordinates from       #
# gaussian logfile and write it into another file    #
######################################################

proc ::QMtool::extract_internal_hessian { file hessianfile } {
   set fid [open $file r]
   set out [open $hessianfile w]

   set readfc 0
   while {![eof $fid]} {
      set line [gets $fid]
      if {[string first "Force constants in internal coordinates:" $line]>=0} {
	 set readfc 1
	 puts $line
      }
      if {[string first "Final forces over variables" $line]>=0} {
	 set readfc 0
	 puts $line
	 break
      }
      
      if {$readfc} {
	 puts $out $line
      }
   }
   close $fid
   close $out
}


#########################################################
# Read the harmonic frequencies from Gaussian frequency #
# logfile.                                              #
#########################################################

proc ::QMtool::read_harmonic_frequencies { file } {
   variable nimag 0
   set havenma 0
   set frequencies {}
   set intensities {}
   set fid [open $file r]
   set ready 0
   while {![eof $fid] && !$ready} {
      set line [gets $fid]
      # Look for the beginning of the NMA section
      if {[string match " Harmonic frequencies (cm\*\*-1),*" $line]} { set havenma 1; continue }

      if {!$havenma} { continue }

      # Look for the end of the NMA section
      if {[llength $frequencies]>0 && [string match " Harmonic frequencies *" line]} { break }

      if {[lrange $line 0 1]=="Frequencies ---"} {
	 lappend frequencies [lrange $line 2 end]
      }
      if {[lrange $line 0 2]=="IR Intensities ---"} {
	 lappend intensities [lrange $line 3 end]
      }

      # Read the atomic components of the normal modes
      if {[string match " Coord Atom Element:*" $line]} {
	 while {![eof $fid]} {
	    set line [gets $fid]
	    if {[string match "               *" [string range $line 0 18]]} { break }
	    if {[lrange $line 0 1]=="Harmonic frequencies"} { set ready 1; break }
	    foreach mode [lrange $line 3 end] {
	       lappend compo[lindex $line 0]([lindex $line 1]) $mode
	    }
	 }
      }
   }
   set frequencies [join $frequencies]
   set intensities [join $intensities]
   
   set i 1
   foreach atom [array names compo1] {
      set i 1
      foreach modex $compo1($atom) modey $compo2($atom) modez $compo3($atom) {
	 lappend modelist($i) [list $modex $modey $modez]
	 #puts "Mode $i: [list $modex $modey $modez]"
	 incr i
      }
   }
   variable normalmodes;# [array get modelist]
   foreach mode [lsort -integer [array names modelist]] {
      lappend normalmodes $modelist($mode)
   }

   set freq {}
   foreach i $frequencies j $intensities {
      lappend freq [list $i $j]
      if {$i<0} { incr nimag }
   }
   close $fid

   return $freq
}


########################################################
# Read hessian matrix in internal coordinates from     #
# Gaussian frequency logfile.                          #
########################################################

proc ::QMtool::read_hessian {file nparams coordset} {
   set fid [open $file r]
   
   set blockwidth 0;
   set block 0;
   set start -2;
   set rowinblock 0;
   set newblock 0
   set hess {}
   if {$coordset=="cartesian"} { set coordset "Cartesian" }

   while {![eof $fid]} {
      set line [gets $fid]

      if {[eof $fid]} {
	 break 
      }
    
      if {[string first "Force constants in $coordset coordinates:" $line]>=0} {
	 incr start; # start=-1
	 continue
      }
    
      if {$start==-1} {
	 set blockwidth [llength $line]
	 incr start; # start=0
	 continue
      }
      
      if {$start<0} {
	 continue
      }
      
      if {[string first "Final forces over variables," $line]>=0 || [string is alpha [lindex $line 0]]} {
	 break
      }

      if {![string is integer [lindex $line 0]]} {
	 break
      }
      
      set line [string map {"D" "e"} $line]
      set row [lindex $line 0]
      incr rowinblock
      
      if {$newblock} {
	 incr block
	 set rowinblock 0
	 set newblock 0
	 continue
      }

      # last line of new block
      if {$row==$nparams} {
	 set newblock 1
      }
      
      set rowdata [lrange $line 1 end]

      set row [expr {$row-1}]
      set currow [lindex $hess $row]
      set currow [concat $currow $rowdata]

      if {$block==0} {
	 lappend hess $currow
      } else {
	 lset hess $row $currow
      }
   
      incr start
  
   }
  
   close $fid

   puts "$coordset hessian size = [llength $hess]"
   return $hess
}


################################################################
# Unit conversion of internal Hessian matrix.                  #
# The force constants in the Hessian are not mass weighted and #
# given in Hartree/bohr^2 or Hartree/rad^2. They will be       #
# converted to kcal/(mol*Angstrom^2) or kcal/(mol*rad^2)       #
# In CHARMM force field k/2 is listed which is why we have to  #
# multiply by 0.5:                                             #
# CHARMM term:              V =     k(q-q0)^2                  #
# quadratic expansion term: V = 1/2*F(q-q0)^2                  #
# with the second derivative of the potential energy with      #
# respect to the coordinates F = d^2V/d(q-q0)^2.               #
# Thus we have k=F/2.                                          #
# The coupling constants in the off-diagonals between bonds    #
# and angles are converted to kcal/(mol*Angstrom*rad).         #
# The force constants are scaled down by a constant factor     #
# that cures the systematic overestimation of frequencies by   #
# HF calculations and to less extend by B3LYP.                 #
################################################################

proc ::QMtool::convert_inthessian_kcal { internalhessian qmmethod zmat {file {}} } {
#   variable zmat
   variable HFscalefac
   variable B3LYPscalefac
   variable AMBERdihed

   # There are different scaling factors for HF and B3LYP
   set fcscalefac [expr {$HFscalefac*$HFscalefac}]
   if {[string match "*B3LYP" $qmmethod]} {
      set fcscalefac [expr {$B3LYPscalefac*$B3LYPscalefac}]
   }
   puts "Force constant scaling factor=$fcscalefac for $qmmethod"

   set hart_kcal 1.041308e-21;
   set mol 6.02214e+23;
   set hart_kcalmol [expr {$hart_kcal*$mol}]
   set bohr_A 0.529177249;
   set sqrt2 [expr {sqrt(2.0)}]

   set fid {}
   if {[llength $file]} {
       set fid [open $file w]
   }

   set num -1
   set dimlist {}
   set namelist {}
   foreach coord $zmat {
      # Skip header
      if {$num==-1} { incr num; continue }

      if {[string match "*bond" [lindex $coord 1]]} {
	 set dim $bohr_A
      } else {
	 set dim 1.0
      }
#       if {$AMBERdihed && [string match "dihed" [lindex $coord 1]]} {
      # 	 set dim [expr {$fcscalefac/$sqrt2}]
#       } else {
# 	 set dim $fcscalefac
#       }

      lappend dimlist $dim

      set name [lindex $coord 0]
      lappend namelist $name

      if {[llength $fid]} {
	 set fc [lindex [lindex $internalhessian $num] end]
	 set fc_kcalA [expr {0.5 * $fc * $hart_kcalmol * $fcscalefac / ($dim*$dim)}]
	 puts $fid [format "%-5s  %3.3f" $name $fc_kcalA]
      }
      incr num
   }

   if {[llength $file]} {
      puts $fid "\nCoupling constants:"
   }

   set rnum 0
   set inthessian_kcalA {}
   set couplings {}
   foreach row $internalhessian {
      set row_kcalA {}
      set dim1  [lindex $dimlist $rnum]
      set name1 [lindex $namelist $rnum]
      set cnum 0
      foreach val $row {
	 set dim2  [lindex $dimlist $cnum]
	 set name2 [lindex $namelist $cnum]

	 set val_kcalA [expr {0.5 * $val * $hart_kcalmol * $fcscalefac / ($dim1*$dim2)}];
	 lappend row_kcalA [format "%.4f" $val_kcalA]

	 if {$cnum!=$rnum} {
	    lappend couplings [format "%-5s %-5s  %3.3f" $name1 $name2 $val_kcalA]
	 }
	 incr cnum
      }
      lappend inthessian_kcalA $row_kcalA
      incr rnum
   }

   if {[llength $fid]} {
      foreach coup [lsort -index 2 $couplings] {
	 puts $fid $coup
      }
      close $fid
   }

   return $inthessian_kcalA
}


#########################################################
# Assign the force constants to internal coordinates.   #
# Takes the hessian matrix in internal coordinates.     #
# Harmonic force constants for diheds are tranlated to  #
# periodic potentials.                                  #
#########################################################

proc ::QMtool::assign_fc_zmat { internalhessian } {
   variable molid
   variable zmat
   variable temperature
   set kcal 0.000239005; # 1.0/4184
   set R  8.31418729782; # ideal gas constant R=kL
   set RT [expr {$kcal*$R*$temperature}]

   set num 0
   foreach entry $zmat {
      # Skip header
      if {$num==0} { incr num; continue }

      set fc [lindex $internalhessian [expr {$num-1}] end]

      set type [lindex $entry 1]
      if {[string match "dihed" $type]} {
	 set delta 0.0
	 set n [get_dihed_periodicity $entry]
	 set dihed [lindex $entry 3]
	 if {![llength [lindex $entry 3]]} {
	    set dihed [measure dihed [lindex $entry 2] molid $molid]
	    lset zmat $num 3 $dihed
	 }
	 #set barrier [expr {2.0*$n*$n*$fc}]
	 # Nicer would be to have the reduced barrier height, i.e projected on the bonds.
	 #puts [format "%4s periodicity n=%-2i; Barrier V0=%f" [lindex $entry 0] $n $barrier]
	 set pot [expr {1+cos($n*$dihed/180.0*3.14159265)}]
	 if {$pot>1.0} { set delta 180.0 }
	 set pot [expr {1+cos(($n*$dihed-$delta)/180.0*3.14159265)}]
	 if {$pot>0.1} { 
	    # If the equilib energy would be higher than 5% of the barrier height we choose the
	    # exact actual angle for delta.
	    # Since the minimum of cos(x) is at 180 deg we need to use an angle relative to 180.
	    set delta [expr {180.0+$dihed}]
	 }
	 lset zmat $num 4 0 [expr {$fc/double($n*$n)}]
	 lset zmat $num 4 1 $n
	 lset zmat $num 4 2 $delta	 	 
      } else {
	 if {![llength [lindex $entry 3]]} {
	    set indexlist [lindex $entry 2]
	    if {[string match "*bond" $type]} {
	       lset zmat $num 3 [measure bond  $indexlist molid $molid]
	    } elseif {[regexp "angle|lbend" $type]} {
	       lset zmat $num 3 [measure angle $indexlist molid $molid]
	    } elseif {[string match "imprp" $type]} {
	       lset zmat $num 3 [measure dihed $indexlist molid $molid]
	    }
	 }
	 lset zmat $num 4 0 $fc
	 lset zmat $num 4 1 [join [lindex $zmat $num 3]]
      }
      lset zmat $num 5 "[regsub {[Q]} [lindex $zmat $num 5] {}]Q"
      incr num
   }
   variable havefc 1
   variable havepar 1
   lset zmat 0 6 $havepar
   lset zmat 0 7 $havefc
   update_zmat
}

proc ::QMtool::get_dihed_periodicity { zmatentry {mol {}} } {
   variable molid
   if {![llength $mol]} {
      set mol $molid
   }
   #set indexes [lindex $zmatentry 2]
   set atom2 [lindex $zmatentry 2 1]
   set atom3 [lindex $zmatentry 2 2]
   set sel2 [atomselect $mol "index $atom2"]
   set sel3 [atomselect $mol "index $atom3"]
   set nbonds2 [llength [join [$sel2 getbonds]]]
   set nbonds3 [llength [join [$sel3 getbonds]]]
   if {$nbonds2<=1 || $nbonds3<=1} { 
      puts "nbonds2=$nbonds2, nbonds3=$nbonds3"
      puts "WARNING (::QMtool::get_dihed_periodicity):"
      puts "Atoms in dihedral not directly bound:\n$zmatentry"
      return 1
   }
   $sel2 delete
   $sel3 delete
   if {$nbonds2==$nbonds3} {
      return [expr {$nbonds2-1}]
   } elseif {($nbonds2==3 && $nbonds3==4) || ($nbonds2==4 && $nbonds3==3)} {
      return 6
   } elseif {$nbonds2>$nbonds3} {
      return [expr {$nbonds2-1}]
   } elseif {$nbonds2<$nbonds3} {
      return [expr {$nbonds3-1}]
   } 
}

proc ::QMtool::read_rigid_potscan { fid } {
   set offset 0;
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # Look for the beginning of the summary
      if {$offset} { incr offset; }
      if {[string match "Summary of the potential surface scan:" $line]} {
	 incr offset
      }
      if {$offset>=3} {
	 lappend potscan $line
	 puts $line
      }
   }
}



# Other helper functions:
# =======================


##########################################################
# Breaks a text into lines of maximal $ncols characters. #
# Breaking occurs between words. When a maximum number   #
# of $nrows lines is reached the text is truncated.      #
# Newlines that are already present in $text are not     #
# affected.                                              #
##########################################################

proc ::QMtool::break_lines { text nrows ncols } {
   set newtext {}
   set oldbreak 0
   # title may not be longer than five lines:
   for {set i 0} {$i<$nrows} {incr i} {
      set wordbreak [tcl_wordBreakBefore $text [expr {$oldbreak+$ncols}]]
      if {$oldbreak+$ncols > [string length $text]} { 
	 set wordbreak [string length $text]
      }
      #puts "oldbreak=$oldbreak; wordbreak=$wordbreak; ncols=$ncols; [string index $text $wordbreak]"

      # if the word is broken at a colon we choose to break at the word before that
      # because the colon could be part of a filename.
      if {[string index $text [expr {$wordbreak-1}]]=="." &&
	  ![string is space [string index $text $wordbreak]]} { 
	 set wordbreak [tcl_wordBreakBefore $text [expr {$wordbreak-2}]]
      }

      # if the first word is too long, then split it:
      if {$wordbreak<0} { 
	 append newtext "[string range $text 0 $ncols]\n"
	 set oldbreak $ncols
	 continue
      }

      # Get the next $ncols characters and locate possible newlines
      set chunk [string range $text $oldbreak [expr {$oldbreak+$ncols}]]
      set newlinepos [string first "\n" $chunk]
      #puts "($oldbreak-[expr {$oldbreak+$ncols}]): \{$chunk\} $newlinepos"

      # If next $ncols characters contain '\n' then just break there
      if {$newlinepos>=0} { 
	 append newtext "[string range $chunk 0 $newlinepos]"
	 incr oldbreak [expr {$newlinepos+1}]
	 continue
      }

      # Last character has to be appended explicitely
      if {$wordbreak==$oldbreak} { 
 	 set newtext [string trimright $newtext]; # strip off last newline
	 append newtext [string index $text $wordbreak]; 
 	 break 
      }
      append newtext "[string range $text $oldbreak [expr {$wordbreak-1}]]\n"
      set oldbreak $wordbreak
   }
   return $newtext
}



proc ::QMtool::read_thermal_energy { file } {
#   set hart_kcal 1.041308e-21;
#   set mol 6.02214e+23;
   set hart2kcalmol 627.510636277
   set kBoltzmann 0.00198681871541

   set fid [open $file r]

   array set energy {}
   array set elabel {}
   set T {}
   set planar 0
   set hindrot 0
   set thermochem 0
   set normalmodes 0
   set solvated 0 
   variable calcdGsolv 0
   while {![eof $fid]} {
      set line [gets $fid]
      if {[string match " Check for planar centers*" $line]} { set planar 1; continue }
      if {[string match " Check reduced barrier height.*" $line]} { set hindrot 1; continue }
      if {[string match " Variational *PCM results*" $line]} { set solvated 1; continue }
      if {[string match " - Thermochemistry -*" $line]} { set thermochem 1; continue }
      #if {[string match " Harmonic frequencies (cm**-1),*" $line]} { set normalmodes 1; continue }

      #if {$normalmodes} {
#	 if {[string match " Frequencies --*" $line]} {#
#
	# }
#	 while {![eof $fid]} {
#	    set line [gets $fid]
#	 }
#      }

      if {$planar} {
	 if {![string is integer [lindex $line 0]]} { set planar 0; continue }
	 set indexes {}
	 foreach ind [lrange $line 0 3] {
	    lappend indexes [expr {$ind-1}]
	 }
	 set types [get_names_for_conf $indexes]
	 puts [format "Planar center: %4s %4s %4s %4s;  angle sum = %8.3f" \
		  [lindex $types 0] [lindex $types 1] [lindex $types 2] [lindex $types 3] [lindex $line 4]]
	 continue
      }

      if {$hindrot} {
	 if {[string match " Bond * frozen.*" $line]} {
	    set ind0 [expr {[lindex $line 1]-1}]
	    set ind1 [expr {[lindex $line 3]-1}]
	    set types [get_names_for_conf [list $ind0 $ind1]]
	    puts [format "Bond %4s - %4s frozen." [lindex $types 0] [lindex $types 1]]
	    continue
	 }
	 if {[string match "  * Estimated reduced barrier height*" $line]} {
	    puts [string trim $line]
	    continue
	 }
	 if {[string match " Number of internal rotation degrees of freedom*" $line]} {
	    puts [string trim $line]
	    continue
	 }
	 if {[string match "  One-to-one correspondance not acheived" $line]} {
	    puts $line
	    while {![eof $fid] && ![string match " Redo normal*" $line] && \
		      ![string match " One-to-one correspondance problem not solved*" $line]} {
	       set line [gets $fid]
	 
	       if {[string is integer [lindex $line 0]]} {
		  set ind0 [expr {[lindex $line 1]-1}]
		  set ind1 [expr {[lindex $line 2]-1}]
		  set indexlist [list $ind0 $ind1]
		  variable zmat
		  set pos [lsearch -regexp $zmat ".+bond\\s{($indexlist|[lrevert $indexlist])}"]
		  if {$pos>0} {
		     lset zmat $pos 5 "[regsub {[I]} [lindex $zmat $pos 5] {}]I"
		  }
		  set names [get_names_for_conf [list $ind0 $ind1]]
		  puts [format "Bond %2i  %4s - %4s %f" [lindex $line 0] [lindex $names 0] \
			   [lindex $names 1] [lindex $line 3]]
	       } else {
		  puts [string trim $line]
	       }
	    }
	 }
	 if {[string match " *Bond   Periodicity  Symmetry Number  Multiplicity*" $line]} {
	    puts $line
	    while {![eof $fid] && ![string match "  Kinetic energy matrix*" $line]} {
	       set line [gets $fid]
	       if {[string is integer [lindex $line 0]]} {
		  set ind0 [expr {[lindex $line 1]-1}]
		  set ind1 [expr {[lindex $line 2]-1}]
		  set indexlist [list $ind0 $ind1]
		  variable zmat
		  set pos [lsearch -regexp $zmat ".+bond\\s{($indexlist|[lrevert $indexlist])}"]
		  if {$pos>0} {
		     lset zmat $pos 5 "[regsub {[I]} [lindex $zmat $pos 5] {}]I"
		  }
		  set names [get_names_for_conf [list $ind0 $ind1]]		  
		  puts [format "%2i  %4s %4s %s" [lindex $line 0] [lindex $names 0] \
			   [lindex $names 1] [string range $line 14 end]]
	       } else {
		  puts [string trim $line]
	       }
	    }
	 }
      }

      if {$solvated} {
	 if {[string match " <psi(0)|   H    |psi(0)>*" $line]} {
	    array set energy [list PCM_Elec_vac [expr {$hart2kcalmol*[lindex $line 5]}]]
	    array set elabel [list PCM_Elec_vac "E(vacuum)"]
	 }
	 if {[string match " <psi(0)|H+V(0)/2|psi(0)>*" $line]} {
	    array set energy [list PCM_Elec_unpolsolute [expr {$hart2kcalmol*[lindex $line 3]}]]
	    array set elabel [list PCM_Elec_unpolsolute "E(unpolarized solute)"]
	 }
	 if {[string match " <psi(f)|   H    |psi(f)>*" $line]} {
	    array set energy [list PCM_Elec_polsolute [expr {$hart2kcalmol*[lindex $line 5]}]]
	    array set elabel [list PCM_Elec_polsolute "E(polarized solute)"]
	 }
	 if {[string match " <psi(0)|H+V(f)/2|psi(0)>*" $line]} {
	    array set energy [list PCM_Elec_polsolvent [expr {$hart2kcalmol*[lindex $line 3]}]]
	    array set elabel [list PCM_Elec_polsolvent "E(polarized solvent)"]
	 }
	 if {[string match " <psi(f)|H+V(f)/2|psi(f)>*" $line]} {
	    array set energy [list PCM_Elec [expr {$hart2kcalmol*[lindex $line 3]}]]
	    array set elabel [list PCM_Elec "Electronic energy  E(solvated)"]
	 }
	 if {[string match "  with all non electrostatic terms*" $line]} {
	    array set energy [list PCM_Elec+G [expr {$hart2kcalmol*[lindex $line 7]}]]
	    array set elabel [list PCM_Elec+G "Total free energy in solution:"]
	 }
	 if {[string match " (Polarized solute)-Solvent*" $line]} {
	    array set energy [list PCM_polarSS [lindex $line 4] ]
	    array set elabel [list PCM_polarSS "(Polarized solute)-Solvent"]
	 }
	 if {[string match " (Unpolarized solute)-Solvent*" $line]} {
	    array set energy [list PCM_unpolarSS [lindex $line 4] ]
	    array set elabel [list PCM_unpolarSS "(Unpolarized solute)-Solvent"]
	 }
	 if {[string match " Solute polarization*" $line]} {
	    array set energy [list PCM_SolutePol [lindex $line 4] ]
	    array set elabel [list PCM_SolutePol "Solute polarization"]
	 }
	 if {[string match " Total electrostatic*" $line]} {
	    array set energy [list PCM_Elstat [lindex $line 4] ]
	    array set elabel [list PCM_Elstat "Total electrostatic"]
	 }
	 if {[string match " Cavitation energy*" $line]} {
	    array set energy [list PCM_Cavitation [lindex $line 4]]
	    array set elabel [list PCM_Cavitation "Cavitation energy"]
	 }
	 if {[string match " Dispersion energy*" $line]} {
	    array set energy [list PCM_Dispersion [lindex $line 4]]
	    array set elabel [list PCM_Dispersion "Dispersion energy"]
	 }
	 if {[string match " Repulsion energy*" $line]} {
	    array set energy [list PCM_Repulsion [lindex $line 4]]
	    array set elabel [list PCM_Repulsion "Repulsion energy"]
	 }
	 if {[string match " Total non electrostatic*" $line]} {
	    array set energy [list PCM_NonElstat [lindex $line 5]]
	    array set elabel [list PCM_NonElstat "Total non electrostatic"]
	 }
	 if {[string match " DeltaG (solv)*" $line]} {
	    array set energy [list PCM_dG_solv [lindex $line 4]]
	    array set elabel [list PCM_dG_solv "DeltaG (solvation)"]
	    set calcdGsolv 1
	 }
      }

      if {$thermochem} {
	 set phase "(vacuum)"
	 set sphase ""
	 if {$solvated} { set phase "(solvated)"; }

	 if {[string match " Temperature * Kelvin. *" $line]} {
	    if {![llength $T]} { puts $line }
	    set T [lindex $line 1]
	    variable temperature $T
	 }
	 if {[string match " Zero-point correction=*" $line]} {
	    array set energy [list ZPE [expr {$hart2kcalmol*[lindex $line 2]}]]
	    array set elabel [list ZPE "Zero-point energy  ZPE"]
	 }
	 if {[string match " Thermal correction to Energy=*" $line]} {
	    array set energy [list U [expr {$hart2kcalmol*[lindex $line 4]}]]
	    array set elabel [list U "Internal energy    U${sphase}(${T}K)"]
	 }
	 if {[string match " Thermal correction to Enthalpy=*" $line]} {
	    array set energy [list H [expr {$hart2kcalmol*[lindex $line 4]}]]
	    array set elabel [list H "Enthalpy           H${sphase}(${T}K)"]
	 }
	 if {[string match " Thermal correction to Gibbs Free Energy=*" $line]} {
	    array set energy [list G [expr {$hart2kcalmol*[lindex $line 6]}]]
	    array set elabel [list G "Gibbs free energy  G${sphase}(${T}K)"]
	 }
	 if {[string match " Sum of electronic and zero-point Energies=*" $line]} {
	    array set energy [list Elec+ZPE [expr {$hart2kcalmol*[lindex $line 6]}]]
	    array set elabel [list Elec+ZPE "E$phase + ZPE"]
	 }
	 if {[string match " Sum of electronic and thermal Energies=*" $line]} {
	    array set energy [list Elec+U [expr {$hart2kcalmol*[lindex $line 6]}]]
	    array set elabel [list Elec+U "E$phase + U${sphase}(${T}K)"]
	 }
	 if {[string match " Sum of electronic and thermal Enthalpies=*" $line]} {
	    array set energy [list Elec+H [expr {$hart2kcalmol*[lindex $line 6]}]]
	    array set elabel [list Elec+H "E$phase + H${sphase}(${T}K)"]
	 }
	 if {[string match " Sum of electronic and thermal Free Energies=*" $line]} {
	    array set energy [list Elec+G [expr {$hart2kcalmol*[lindex $line 7]}]]
	    array set elabel [list Elec+G "E$phase + G${sphase}(${T}K)"]
	 }
	 if {[string match "                      KCal/Mol        Cal/Mol-Kelvin    Cal/Mol-Kelvin*" $line]} {
	    set line [gets $fid]
	    array set energy [list Etot [lindex $line 1]]
	    array set energy [list CV   [lindex $line 2]]
	    array set energy [list S    [expr {[lindex $line 3]/1000.0}]]
	    array set elabel [list Etot "Thermal internal energy     Etot(${T}K)"]
	    array set elabel [list CV   "Heat capacity      CV${sphase}"]
	    array set elabel [list S    "Entropy            S${sphase}"]
	    set line [gets $fid]   
	    if {[string match " Corrected for*" $line]} {
	       set line [gets $fid]
	       if {[string match " internal rot.*" $line]} {
		  array set energy [list HR_U    [lindex $line 2]]
		  array set energy [list HR_CV   [lindex $line 3]]
		  array set energy [list HR_S    [expr {[lindex $line 4]/1000.0}]]
		  array set elabel [list HR_U  "Internal energy    U${sphase}(${T}K)"]
		  array set elabel [list HR_CV "Heat capacity      CV${sphase}"]
		  array set elabel [list HR_S  "Entropy            S${sphase}"]
	       }
	    }
	 }
      }
   }
   close $fid


   variable normalterm
   if {!$normalterm} { return }

#   if {[llength $::QMtool::PCMmethod]} { set solvated 1 }

   set phase "(vacuum)"
   set sphase ""
   if {$solvated} { 
      set phase "(solvated)"; #set sphase "solv" 
      if {[llength [array get energy PCM_Elec_vac]]} {
	 array set energy [list Elec $energy(PCM_Elec_vac)]
	 array set elabel [list Elec "Eletronic energy  E(vacuum)"]
	 # We actually parsed the following values already but for the sake of documentation how they are
	 # derived we calculate them here. Also the parsd values have a lower precision which is bad for 
	 # comparison of energies.
	 array set energy [list PCM_unpolarSS [expr {$energy(PCM_Elec_unpolsolute)-$energy(PCM_Elec_vac)}]]
	 array set energy [list PCM_polarSS   [expr {$energy(PCM_Elec)            -$energy(PCM_Elec_polsolute)}]]
	 array set energy [list PCM_SolutePol [expr {$energy(PCM_Elec_polsolute)  -$energy(PCM_Elec_vac)}]]
	 array set energy [list PCM_Elstat    [expr {$energy(PCM_polarSS)         +$energy(PCM_SolutePol)}]]
	 array set energy [list PCM_dG_solv   [expr {$energy(PCM_Elstat)          +$energy(PCM_NonElstat)}]]
	 variable Evacuum     [format "%14.2f" $energy(PCM_Elec_vac)]
	 variable Esolv       [format "%14.2f" $energy(PCM_Elec)]
	 variable Gsolv       [format "%14.2f" $energy(G)]
	 variable EGsolv      [format "%14.2f" $energy(Elec+G)]
	 variable dGsolvation [format "%14.2f" $energy(PCM_dG_solv)]
      } else {
	 array set energy [list Elec $energy(PCM_Elec)]
	 array set elabel [list Elec "Eletronic energy  E(solvated)"]
	 variable Esolv       [format "%14.2f" $energy(PCM_Elec)]
	 variable Gsolv       [format "%14.2f" $energy(G)]
	 variable EGsolv      [format "%14.2f" $energy(Elec+G)]
	 variable dGsolvation [format "%14.2f" $energy(PCM_dG_solv)]
      }
   } else {
      array set energy [list Elec [expr {$energy(Elec+ZPE)-$energy(ZPE)}]]
      array set elabel [list Elec "Eletronic energy  E(vacuum)"]
      variable Evacuum  [format "%14.2f" $energy(Elec)]
      variable Gvacuum  [format "%14.2f" $energy(G)]
      variable EGvacuum [format "%14.2f" $energy(Elec+G)]
   }

   array set energy [list TS   [expr {$energy(S)*$T}]]
   array set elabel [list TS   "Entropic term      T*S${sphase}"]

   if {[llength [array get energy HR_U]]} {
      array set energy [list HR_H  [expr {$energy(HR_U)+$kBoltzmann*$T}]]
      array set energy [list HR_TS [expr {$T*$energy(HR_S)}]]
      array set energy [list HR_G  [expr {$energy(HR_H)-$energy(HR_TS)}]]
      if {$solvated} {
	 array set energy [list HR_Elec+U [expr {$energy(PCM_Elec)+$energy(HR_U)}]]
	 array set energy [list HR_Elec+H [expr {$energy(PCM_Elec)+$energy(HR_H)}]]
	 array set energy [list HR_Elec+G [expr {$energy(PCM_Elec)+$energy(HR_G)}]]
      } else {
	 array set energy [list HR_Elec+U [expr {$energy(Elec)+$energy(HR_U)}]]
	 array set energy [list HR_Elec+H [expr {$energy(Elec)+$energy(HR_H)}]]
	 array set energy [list HR_Elec+G [expr {$energy(Elec)+$energy(HR_G)}]]
      }
      array set elabel [list HR_H  "Enthalpy           H${sphase}(${T}K)"]
      array set elabel [list HR_G  "Gibbs free energy  G${sphase}(${T}K)"]
      array set elabel [list HR_TS "Entropic term      T*S"]
      array set elabel [list HR_Elec+U "E$phase + U${sphase}(${T}K)"]
      array set elabel [list HR_Elec+H "E$phase + H${sphase}(${T}K)"]
      array set elabel [list HR_Elec+G "E$phase + G${sphase}(${T}K)"]
      if {$solvated} { 
	 variable Gsolv  [format "%14.2f" $energy(HR_G)]
	 variable EGsolv [format "%14.2f" $energy(HR_Elec+G)]
      } else { 
	 variable Gvacuum  [format "%14.2f" $energy(HR_G)]
	 variable EGvacuum [format "%14.2f" $energy(HR_Elec+G)]
      }
   }

   puts "\n****************************************************************"
   puts "*********************   Thermochemistry   **********************"
   puts "*********************                     **********************"
   puts "****************************************************************"

   if {[llength [array get energy Elec]]} {
      puts "\nGas phase:"
      puts "================================================================"

      print_energies [array get energy] [array get elabel] {Elec}
   }

   if {!$solvated} { 
      print_energies [array get energy] [array get elabel] \
	 {ZPE U H TS G Elec+ZPE Elec+U Elec+H Elec+G S CV}

      if {[llength [array get energy HR_U]]} {
	 puts "\nHindered rotor correction (gas phase):"
	 puts "----------------------------------------"
	 print_energies [array get energy] [array get elabel] \
	    {HR_U HR_H HR_TS HR_G HR_Elec+U HR_Elec+H HR_Elec+G HR_S HR_CV}
      }
   }

   if {$solvated} {
      if {[llength [array get energy Elec]]} {
	 puts "\nEstimated energies using U,H,G from solvated system:"
	 array set energy [list GAS_Elec+U [expr {$energy(Elec)+$energy(U)}]]
	 array set energy [list GAS_Elec+H [expr {$energy(Elec)+$energy(H)}]]
	 array set energy [list GAS_Elec+G [expr {$energy(Elec)+$energy(G)}]]
	 array set elabel [list GAS_Elec+U "E(vacuum) + Usolv(${T}K)"]
	 array set elabel [list GAS_Elec+H "E(vacuum) + Hsolv(${T}K)"]
	 array set elabel [list GAS_Elec+G "E(vacuum) + Gsolv(${T}K)"]
	 variable EGvacuum [format "%14.2f" $energy(GAS_Elec+G)]

	 print_energies [array get energy] [array get elabel] {GAS_Elec+U GAS_Elec+H GAS_Elec+G}

	 if {[llength [array get energy HR_U]]} {
	    array set energy [list HR_GAS_Elec+U [expr {$energy(Elec)+$energy(HR_U)}]]
	    array set energy [list HR_GAS_Elec+H [expr {$energy(Elec)+$energy(HR_H)}]]
	    array set energy [list HR_GAS_Elec+G [expr {$energy(Elec)+$energy(HR_G)}]]
	    array set elabel [list HR_GAS_Elec+U "E(vacuum) + Usolv(${T}K)"]
	    array set elabel [list HR_GAS_Elec+H "E(vacuum) + Hsolv(${T}K)"]
	    array set elabel [list HR_GAS_Elec+G "E(vacuum) + Gsolv(${T}K)"]
	    variable EGvacuum [format "%14.2f" $energy(HR_GAS_Elec+G)]

	    puts "\nHindered rotor correction (gas phase):"
	    puts "----------------------------------------"
	    print_energies [array get energy] [array get elabel] \
	       {HR_GAS_U HR_GAS_H HR_GAS_TS HR_GAS_G HR_GAS_Elec+U HR_GAS_Elec+H HR_GAS_Elec+G}
	 }
      }


      variable solvent
      puts "\n\nSolvated system (solvent=$solvent):"
      puts "================================================================"

      print_energies [array get energy] [array get elabel] \
	 {PCM_Elec_vac PCM_Elec_unpolsolute PCM_Elec_polsolute PCM_Elec_polsolvent}

      puts "\nPolarization energies:"
      print_energies [array get energy] [array get elabel] \
	 {PCM_unpolarSS PCM_polarSS PCM_SolutePol PCM_Elstat}

      puts "\nNon electrostatic solvation energies:"
      print_energies [array get energy] [array get elabel] \
	 {PCM_Cavitation PCM_Dispersion PCM_Repulsion PCM_NonElstat}

      puts "------------------------------------------------------------"
      print_energies [array get energy] [array get elabel] {PCM_dG_solv}

      puts ""

      print_energies [array get energy] [array get elabel] \
	 {PCM_Elec ZPE U H TS G Elec+ZPE Elec+U Elec+H Elec+G S CV}


      #array set energy [list PCM_Elec [expr {$energy(PCM_Elec+G)-$energy(G)}]]
      array set elabel [list PCM_Elec "Eletronic energy"]
      if {[llength [array get energy HR_U]]} {
	 puts "\nHindered rotor correction (solvated system):"
	 puts "----------------------------------------------"
	 print_energies [array get energy] [array get elabel] \
	    {HR_U HR_H HR_TS HR_G HR_Elec+U HR_Elec+H HR_Elec+G HR_S HR_CV}
      }
     
   }
   
   puts "\n****************************************************************"
   puts "****************************************************************\n"

   variable thermalenergy [array get energy]
   return $thermalenergy
} 


################################################
# Print thermochemical energies.               #
################################################

proc ::QMtool::print_energies {E label taglist} {
   array set energy $E
   array set elabel $label
   foreach tag $taglist {
      if {[llength [array get energy $tag]]} {
	 set unit "Kcal/mol"
	 if {[regexp {^S$|^HR_S$}   $tag]} { set unit "Kcal/(mol*K)"; }
	 if {[regexp {^CV$|^HR_CV$} $tag]} { set unit " Cal/(mol*K)"; }
	 puts [format "%-31s = %14.2f %s" $elabel($tag) $energy($tag) $unit]
      }
   }
}


################################################
# Get names for the conformation.              #
################################################

proc ::QMtool::get_names_for_conf { indexes } {
   set namelist {}
   foreach ind $indexes {
      set name  [get_atomprop Name $ind]
      if {![llength $name]} { break }

      lappend namelist $name
   }

   return $namelist
}
