#
# Various helper routines
#
# $Id: qmtool_aux.tcl,v 1.21 2007/09/12 13:41:59 saam Exp $
#

proc ::QMtool::format_float { format float } {
   if {![llength $float] || $float=="{}"} {
      set len [string length [format "$format" 0.0]]
      return [format "%${len}s" "{}"]
   } else {
      return [format "$format" $float]
   }
}

####################################################
# Set the string and its color in the status line. #
####################################################

proc ::QMtool::setstatus { text color } {
   if { [winfo exists .qmtool.status.text] } {
      .qmtool.status.text configure -fg $color
   }
   variable statuscolor $color
   variable statustext  $text
}


#####################################################
# Autogenerate Z-matrix with redundant internal     #
# coordinates.                                      #
#####################################################

proc ::QMtool::autogenerate_zmat {} {
   variable w
   variable act
   set button [tk_messageBox -icon question -type okcancel \
	 -title Message -parent .qmtool_intcoor \
	 -message "Autogenerate all redundant internal coordinates that\ndepend on the bonds currently defined in VMD?"]
   if {$button=="cancel"} { return 0 }

   set tmpact $act
   variable zmat [modredundant_zmat]

   set act $tmpact
   update_zmat
   .qmtool_intcoor.l.zmat.pick.list see $act
   return 1
}

##############################################################
# Find a position for a newly added coordinate.of a certain  #
# type (bond|angle|dihed|improper).                          #
# Returns the first free index for the selected type and the #
# absolute index in the zmat.                                #
##############################################################

proc ::QMtool::find_new_coordinate_position { zmat type } {
   set act -1
   set num 1
   set oldnum 0
   foreach entry $zmat {
      if {$act==-1} { incr act; continue }
      if {$type=="bond"  && [lindex $entry 1]!="bond"}  { incr act; continue }
      if {$type=="angle" && [lindex $entry 1]!="angle"} { incr act; continue }
      if {$type=="dihed" && [lindex $entry 1]!="dihed"} { incr act; continue }
      if {$type=="imprp" && [lindex $entry 1]!="imprp"} { incr act; continue }
      if {[lindex $entry 1]!=$type} { continue }
      set num [string range [lindex $entry 0] 1 end]
      if {$num>[expr $oldnum+1]} { break }
      set oldnum $num
      incr act
   }
   set num [expr $oldnum+1];
   return [list $num $act]
}

##############################################################
# Check if a dihedral forms an improper dihedral, if yes,    #
# return 1 else return 0.                                    #
##############################################################

proc ::QMtool::is_zmat_improper {atomlist zmat} {
   # Get a list of all bonds
   set bondlist {}
   set Rind [lsearch -all -regexp $zmat {^[[:alnum:]]+\sbond\s.+}]
   if {[llength $Rind]} {
      set bondlist [lrange $zmat [lindex $Rind 0] [lindex $Rind end]]
   }

   foreach alist [list $atomlist [lrevert $atomlist]] {
      set atom0 [lindex $alist 0]
      set atom1 [lindex $alist 1]
      set atom2 [lindex $alist 2]
      set atom3 [lindex $alist 3]
      set bond01 [list $atom0 $atom1]
      set bond10 [list $atom1 $atom0]
      set bond02 [list $atom0 $atom2]
      set bond20 [list $atom2 $atom0]
      set bond03 [list $atom0 $atom3]
      set bond30 [list $atom3 $atom0]
      
      set f1 0
      set f2 0
      set f3 0
      foreach bond $bondlist {
	 set indices [lindex $bond 2]
	 if {$indices==$bond01 || $indices==$bond10} { set f1 1; }
	 if {$indices==$bond02 || $indices==$bond20} { set f2 1; }
	 if {$indices==$bond03 || $indices==$bond30} { set f3 1; }
	 if {$f1 && $f2 && $f3} { return 1 }
      }
   }

   return 0
}


###############################################################
# Identify dihedrals that describe out-of-plane bends and     #
# changes their type from dihed to imprp.                     #
# Returns the updated zmat.                                   #
# This is necessary because Gaussian does not recognize       #
# impropers (even though it is supposed to), it simply        #
# ignores them. Thus we have to model them by dihedrals and   #
# and recognize them as out-of-plane bends by their geometry. #
###############################################################

proc ::QMtool::find_improper_dihedrals { zmat } {
   set ndihed  [lindex $zmat 0 4]
   set nimprop [lindex $zmat 0 5]
   set index 0
   foreach entry $zmat {
      if {!$index} { incr index; continue }
      if {[lindex $entry 1]!="dihed"} { incr index; continue }
      set atomlist [lindex $entry 2]
      #puts "Checking dihed $entry"
      if {[is_zmat_improper $atomlist $zmat]} {
	 #puts "Improper found!"
	 set newind [find_new_coordinate_position $zmat imprp]
	 lset entry 1 "imprp"
	 lset entry 0 "O[lindex $newind 0]"
	 lset zmat $index $entry
	 incr nimprop
	 incr ndihed -1

      }
      incr index
   }
   lset zmat 0 4 $ndihed          	 
   lset zmat 0 5 $nimprop

   return $zmat; # [sort_zmat $zmat]
}


#################################################
# Update the bondlist that VMD keeps.           #
#################################################

proc ::QMtool::update_vmd_bondlist {} {
   variable zmat
   variable molid
   ::util::clear_bondlist $molid
   foreach entry $zmat {
      set type [lindex $entry 1]
      if {$type!="bond"} { continue }
      set atom0 [lindex $entry 2 0]
      set atom1 [lindex $entry 2 1]
      ::util::addbond $molid $atom0 $atom1
   }
}


###########################################################
# Generates redundant internal coordinates that depend on #
# the bonds currently defined in VMD.                     #
# Existing coordinates are not effected.                  #
###########################################################

proc ::QMtool::modredundant_zmat { {seltext all} } {
   variable autogendiheds
   variable molid
   set sel [atomselect $molid $seltext]
   set neighborlist [$sel getbonds]
   set bondlist  [::util::bondlist -molid $molid -sel $sel]
   set anglelist [::util::anglelist -sel $sel]

   if {$autogendiheds=="one"} {
      set dihedlist [::util::dihedlist -sel $sel -bonds $bondlist]
   } else {
      set dihedlist [::util::dihedlist -sel $sel -bonds $bondlist- all]
   }

   if {[lsearch [molinfo list] $molid]>=0} {
      if {[molinfo $molid get numframes]>0} {
	 set natoms [molinfo $molid get numatoms]
      }
   }

   set ncoords 0
   variable nbonds
   variable nangles 
   variable ndiheds
   variable nimprops
   set havepar 1
   set havefc 0
   set zmat [default_zmat]

   foreach ilist $bondlist {
      # See if the bond exists already
      set found [lsearch -regexp $zmat "bond\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch -regexp $zmat "bond\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
      }
      if {$found>=0} { continue }

      incr nbonds
      set name "R$nbonds"
      set val [measure bond $ilist molid $molid]
      # Find a name for the coordinate
      set act -1
      set num 1
      set oldnum 0
      foreach entry $zmat {
	 if {$act==-1} { incr act; continue }
	 if {[lindex $entry 1]!="bond"} { continue }
	 set num [string range [lindex $entry 0] 1 end]
	 if {$num>[expr $oldnum+1]} { break }
	 set oldnum $num
	 incr act
      }
      set num [expr $oldnum+1];

      lappend zmat [list R$num bond $ilist $val {} {}]
      set zmat [sort_zmat $zmat]
      puts "Added [list R$num bond $ilist $val {} {}]"
   }

   foreach ilist $anglelist {
      # See if the angle exists already
      set found [lsearch -regexp $zmat "(angle|lbend)\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 2] [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch -regexp $zmat "(angle|lbend)\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
      }
      if {$found>=0} { continue }

      incr nangles
      set name "A$nangles"
      set val [measure angle $ilist molid $molid]

      # Find a name for the coordinate
      set act -1
      set num 1
      set oldnum 0
      foreach entry $zmat {
	 if {$act==-1 || [lindex $entry 1]=="bond"} { incr act; continue }
	 if {!([lindex $entry 1]=="angle" || [lindex $entry 1]=="lbend")} { continue }
	 set num [string range [lindex $entry 0] 1 end]
	 if {$num!=[expr $oldnum+1]} { break }
	 set oldnum $num
	 incr act
      }
      set num [expr $oldnum+1];
      lappend zmat [list A$num angle $ilist $val {} {}]
      set zmat [sort_zmat $zmat]
      puts "Added [list A$num angle $ilist $val {} {}]"
   }

   foreach ilist $dihedlist {
      # See if the dihed exists already
      set found [lsearch -regexp $zmat "dihed\\s+\\{$ilist\\}"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 3] [lindex $ilist 2] [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch -regexp $zmat "dihed\\s+\\{$ilist\\}"]
      }
      if {$found>=0} { continue }

      incr ndiheds
      set name "D$ndiheds"
      set val [measure dihed $ilist molid $molid]

      # Find a name for the coordinate
      set act -1
      set num 1
      set oldnum 0
      foreach entry $zmat {
	 if {$act==-1 || [lindex $entry 1]=="bond" || 
	     [lindex $entry 1]=="angle" || [lindex $entry 1]=="lbend"} { incr act; continue }
	 if {[lindex $entry 1]!="dihed"} { continue }
	 set num [string range [lindex $entry 0] 1 end]
	 if {$num!=[expr $oldnum+1]} { break }
	 set oldnum $num
	 incr act
      }
      set num [expr $oldnum+1];
      lappend zmat [list D$num dihed $ilist $val {} {}]
      set zmat [sort_zmat $zmat]
      puts "Added [list D$num dihed $ilist $val {} {}]"
   }

   set ncoords [expr $nbonds+$nangles+$ndiheds+$nimprops]
   lset zmat 0 [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]
 
  # Sort the Z-matrix so that the bonds come first,then angles, then diheds
   return [sort_zmat $zmat]
}

proc ::QMtool::measure_imprp {molid ilist {frames now}} {
   return [measure_dihed $molid $ilist $frames]
}

proc ::QMtool::measure_imprp_label {molid ilist args} {
   label add Dihedrals $molid/[lindex $ilist 0] $molid/[lindex $ilist 1] \
      $molid/[lindex $ilist 2] $molid/[lindex $ilist 3]
   if {[lsearch $args "-all"]>=0} {
      set n [llength [label list Dihedrals]]
      set val [label graph Dihedrals [expr {$n-1}]]
   } else {
      set val [lindex [lindex [label list Dihedrals] end] 4]
   }
   label delete Dihedrals
 
   return $val
}


proc ::QMtool::measure_dihed {molid ilist {frames now}} {
   switch $frames {
      now { set frames [molinfo $molid get frame] }
      all { 
	 set frames {}
	 for {set f 0} {$f<[molinfo $molid get numframes]} {incr f} {
	    lappend frames $f
	 }
      }
   }

   set a0 [lindex $ilist 0]
   set a1 [lindex $ilist 1]
   set a2 [lindex $ilist 2]
   set a3 [lindex $ilist 3]
   set sel [atomselect $molid "index $a0 $a1 $a2 $a3"]
   foreach f $frames {
      $sel frame $f
      foreach i [$sel list] xyz [$sel get {x y z}] {
	 set p($i) $xyz
      }
      set v1 [vecsub $p($a0) $p($a1)]
      set v2 [vecsub $p($a2) $p($a1)]
      set v3 [vecsub $p($a3) $p($a2)]
      set cross1 [vecnorm [veccross $v2 $v1]]
      set cross2 [vecnorm [veccross $v2 $v3]]
      set dot [vecdot $cross1 $cross2]
      set acos [expr {acos($dot)}]
      lappend ret [expr {57.2957795131*$acos}]
   }
   return $ret
}

proc ::QMtool::measure_dihed_label {molid ilist args} {
   label add Dihedrals $molid/[lindex $ilist 0] $molid/[lindex $ilist 1] \
      $molid/[lindex $ilist 2] $molid/[lindex $ilist 3]
   if {[lsearch $args "-all"]>=0} {
      set n [llength [label list Dihedrals]]
      set val [label graph Dihedrals [expr {$n-1}]]
   } else {
      set val [lindex [lindex [label list Dihedrals] end] 4]
   }
   label delete Dihedrals
   
   return $val
}

# For numframes<8 measure_angle all is faster than the method using the labels
proc ::QMtool::measure_angle { molid ilist {frames now}} {
   switch $frames {
      now { set frames [molinfo $molid get frame] }
      all { 
	 set frames {}
	 for {set f 0} {$f<[molinfo $molid get numframes]} {incr f} {
	    lappend frames $f
	 }
      }
   }

   set a0 [lindex $ilist 0]
   set a1 [lindex $ilist 1]
   set a2 [lindex $ilist 2]
   set sel [atomselect $molid "index $a0 $a1 $a2"]
   foreach f $frames {
      $sel frame $f
      foreach i [$sel list] xyz [$sel get {x y z}] {
	 set p($i) $xyz
      }
      
      set x [vecnorm [vecsub $p($a0) $p($a1)]]
      set y [vecnorm [vecsub $p($a2) $p($a1)]]
      set dot [vecdot $x $y]
      set acos [expr {acos($dot)}]
      lappend ret [expr {57.2957795786*$acos}]
   }
   return $ret
}

proc ::QMtool::measure_angle_label {molid ilist args} {
   label add Angles $molid/[lindex $ilist 0] $molid/[lindex $ilist 1] \
      $molid/[lindex $ilist 2]
   if {[lsearch $args "-all"]>=0} {
      set n [llength [label list Angles]]
      set val [label graph Angles [expr {$n-1}]]
   } else {
      set val [lindex [lindex [label list Angles] end] 3]
   }
   label delete Angles
  
   return $val
}

proc ::QMtool::measure_bond {molid ilist {frames now}} {
   switch $frames {
      now { set frames [molinfo $molid get frame] }
      all { 
	 #set frames {}
	 #for {set f 0} {$f<[molinfo $molid get numframes]} {incr f} {
	 #   lappend frames $f
	 #}
	 label add Bonds $molid/[lindex $ilist 0] $molid/[lindex $ilist 1]
	 set n [llength [label list Bonds]]
	 set val [label graph Bonds [expr {$n-1}]]
	 label delete Bonds
	 return $val
      }
   }
   
   set a0 [lindex $ilist 0]
   set a1 [lindex $ilist 1]
   set sel [atomselect $molid "index $a0 $a1"]
   foreach f $frames {
      $sel frame $f
      lappend ret [veclength [vecsub [lindex [$sel get {x y z}] 0] [lindex [$sel get {x y z}] 1]]]
   }

   return $ret
}


######################################################
# Recalculate the bonds based on the atom distance.  #
# VMD's bondlist and zmat will be updated.           #
# Angles and dihedrals containing deleted bonds are  #
# not removed.                                       #
######################################################

proc ::QMtool::recalculate_bonds {} {
   variable zmat
   variable maxbondlength
   variable molid

   set sel [atomselect $molid all]
   set bondlist {}
   set newbondlist {}
   foreach entry $zmat {
      set type [lindex $entry 1]
      if {$type!="bond"} { continue }
      lappend bondlist $entry
   }

   #set ncoords [lindex [lindex $zmat 0] 1]
   set nbonds  [lindex [lindex $zmat 0] 2]
   set vmdbondlist {}
   set i 0
   foreach pos1 [$sel get {x y z}] {
      set j 0
      set sublist {}
      foreach pos2 [$sel get {x y z}] {
	 set dist [veclength [vecsub $pos1 $pos2]]
	 if {$dist<$maxbondlength && $i!=$j} {
	    foreach entry $bondlist {
	       set indexes [lindex $entry 2]
	       if {$indexes==[list $i $j] || $indexes==[list $j $i]} {
		  lappend newbondlist $entry
		  continue
	       }
	    }
	    lappend sublist $j
	 }
	 incr j
      }
      lappend vmdbondlist $sublist
      incr i
   }
   $sel setbonds $vmdbondlist

   set newbondlist [lsort -unique -dictionary -index 0 $newbondlist]
   set header [list [lindex $zmat 0]]
   lset header 0 2 [llength $newbondlist]
   set newzmat [join [list $header $newbondlist]]

   # Build angles and diheds for new zmat
   set i 0
   foreach entry $zmat {
      if {$i==0} {incr i; continue }
      set type  [lindex $entry 1]
      set ilist [lindex $entry 2]
      if {$type=="bond"} { continue }
      lappend newzmat $entry
   }
   variable ncoords [expr [llength $newzmat]-1]
   lset header 0 1 $ncoords

   # Remove the dependent coords of deleted bonds
   set i 0
   foreach entry $zmat {
      if {$i==0} {incr i; continue }
      set type  [lindex $entry 1]
      set ilist [lindex $entry 2]
      if {$type=="bond"} { 
	 set found [lsearch -regexp $newbondlist "bond\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
	 if {$found<0} { 
	    set ilist [list [lindex $ilist 1] [lindex $ilist 0]]
	    set found [lsearch -regexp $newbondlist "bond\\s+\\{[string map {{ } {\s}} $ilist]\\}"]
	 }
	 if {$found<0} { 
	    set newzmat [del_dependent $newzmat [lindex $ilist 0] [lindex $ilist 1]] 
	 } 
      }
   }

   variable zmat $newzmat
   update_zmat
   update_intcoorlabels
   return $vmdbondlist
}


################################################
# Translate atomic numbers in element symbols  #
################################################

proc ::QMtool::translate_elements { } {
   variable cartesians

   set element {{} H HE LI BE B C N O F NE NA MG AL SI P S CL AR K CA SC TI V CR MN FE CO \
		   NI CU ZN GA GE AS SE BR KR RB SR Y ZR NB MO TC RU RH PD AG CD IN SN SB \
		   TE I XE CS BA LA CE PR ND PM SM EU GD TB DY HO ER TM YB LU HF TA W RE OS \
		   IR PT AU HG TL PB BI PO AT RN}
   set i 0
   foreach atom $cartesians {
      if {![string is alpha [lindex $atom 0]]} {
	 lset cartesians $i 0 [lindex $element [lindex $atom 0]]
      }
      incr i
   }
}


################################################################
# Translate an atomic number into an element symbol.           #
# If $atomnum contains alpabetic characters then the one/two   #
# chracter element symbol is extracted from the string.        #
# If no element was recognized -1 is returned.                 #
# Atomic number 0 corresponds to a dummy atom X.               #
################################################################

proc ::QMtool::atomnum2element { symbol } {
   set periodic {X H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co \
		   Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb \
		   Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os \
		   Ir Pt Au Hg Tl Pb Bi Po At Rn}

   if {[string is integer $symbol]} {
      return  [lindex $periodic $symbol]
   }
   set atomnum [element2atomnum $symbol]
   return [lindex $periodic $atomnum]
}

######################################################################
# Translate an element symbol into the corresponding atomic number.  #
# If the element symbol was not recognized -1 is returned.           #
# Dummy atoms named X correspond to an atomic number 0.              #
# From the Gaussian manual:                                          #
# "Element-label is a character string consisting of either the      #
# chemical symbol for the atom or its atomic number. If the          #
# elemental symbol is used, it may be optionally followed by other   #
# alphanumeric characters to create an identifying label for that    #
# atom. A common practice is to follow the element name with a       #
# secondary identifying integer: C1, C2, C3, and so on; this         #
# technique is useful in following conventional chemical numbering." #
######################################################################

proc ::QMtool::element2atomnum { element } {
   set periodic {X H HE LI BE B C N O F NE NA MG AL SI P S CL AR K CA SC TI V CR MN FE CO \
		   NI CU ZN GA GE AS SE BR KR RB SR Y ZR NB MO TC RU RH PD AG CD IN SN SB \
		   TE I XE CS BA LA CE PR ND PM SM EU GD TB DY HO ER TM YB LU HF TA W RE OS \
		   IR PT AU HG TL PB BI PO AT RN}
   # Strip the trailing characters and check if the $element matches a two-character 
   # element symbol:
   if {[string length $element]>2 && [string is alpha [string index $element 2]]} { return -2 }
   set twochar [lsearch $periodic [string toupper [string range $element 0 1]]]
   if {$twochar>=0} { return $twochar }
   # Check for one-character element symbols
   if {[string is alpha [string index $element 1]]} { return -1 }
   set onechar [lsearch $periodic [string toupper [string index $element 0]]]
   return $onechar 
}

###########################################################
# Returns the bond angle between points $pos0 $pos1 $pos2 #
###########################################################

proc ::QMtool::bond_angle {pos0 pos1 pos2} {
   set x [vecnorm [vecsub $pos0 $pos1]]
   set y [vecnorm [vecsub $pos2 $pos1]]

   # Compute scalar-produt
   set dot [vecdot $x $y]

   set dot [expr $dot/([veclength $x] * [veclength $y])]
   # Correct numerical imprecision
   if {$dot>1.0 && $dot<1.0001} {set dot 1}
   if {$dot<-1.0 && $dot>-1.0001} {set dot -1}
   if {$dot>1.0 || $dot<-1.0} {
      puts "bond_angle: {$x} * {$y} = $dot"
      error "bond_angle: dot>1.0, cannot compute acos($dot)"
   }

    return [rad2deg [expr (acos($dot))]]
}


###########################################################
# Returns the dihedral angle between the four points.      #
###########################################################

proc ::QMtool::dihed_angle { coord1 coord2 coord3 coord4 } {
   set v1 [vecsub $coord1 $coord2]
   set v2 [vecsub $coord3 $coord2]
   set v3 [vecsub $coord4 $coord3]
   #if {[veclength [veccross $v2 $v3]]==0} {puts "$coord3; $coord4"; puts "$v2 $v3"}
   set cross1 [vecnorm [veccross $v2 $v1]]
   set cross2 [vecnorm [veccross $v2 $v3]]
   set dot [vecdot $cross1 $cross2]
   if {$dot>1.0 && $dot<1.0001} {set dot 1.0}
   if {$dot<-1.0 && $dot>-1.0001} {set dot -1.0}
   if {$dot>1.0 || $dot<-1.0} {
      puts "dihed_angle: dot>1.0, cannot compute acos($dot)"
   }
   set angle [rad2deg [expr acos($dot)]]
   return $angle
}

#######################################################################
# Atom names should be consisting of the element symbol and a number. #
#######################################################################

proc ::QMtool::alias_atomnames {{verbose "verbose"}} {
   variable atomproplist
   set i 0
   foreach atom $atomproplist {
      if {$verbose=="verbose"} {
	 puts "Aliased name [get_atomprop Name $i] --> [get_atomprop Elem $i][expr $i+1]"
      }
      set_atomprop Elem $i [get_atomprop Elem $i]
      set_atomprop Name $i [get_atomprop Elem $i][expr $i+1]
      incr i
   }
   atomedit_update_list
}

##########################################################
# Find a unique names for all atoms.                     #
##########################################################

proc ::QMtool::assign_unique_atomnames {{verbose "verbose"}} {
   variable molid
   set all [atomselect $molid all]
   foreach atom [$all get {name resid resname segid atomicnumber index}] {
      foreach {name resid resname segid atomnum index} $atom {}
      if {![llength $segid]} { set segid QMT }
      set sel [atomselect $molid "name '[string map {' \\'} $name]' and resid $resid and segid $segid"]
      if {[$sel num]>1} {
	 set elem [::QMtool::atomnum2element $atomnum]
	 set newname [find_new_atomname $resid $segid $elem]
	 set_atomprop Name $index $newname
	 if {$verbose=="verbose"} {
	    puts "Assigned unique name ([$sel num] equal atoms): $name -> $newname"
	 }
      }
      $sel delete
   }
   $all delete
}
