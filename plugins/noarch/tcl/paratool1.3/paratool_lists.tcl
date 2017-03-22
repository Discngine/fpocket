#
# Procs for maintaining consistency of VMD structure with paratool structure
#
# $Id: paratool_lists.tcl,v 1.32 2007/09/12 13:42:49 saam Exp $
#

# Autogenerate Z-matrix with redundant internal
# coordinates.
 proc ::Paratool::autogenerate_zmat {} {
    variable w
    variable zmat
    variable molidbase
    if {$molidbase<0} {
       tk_messageBox -icon question -type ok \
	  -title Message -parent .paratool_intcoor \
	  -message "You must load an optimized geometry for your molecule first (fragment for parametrization)!"
       return 0
    }

    if {[llength $zmat]>1} {
       set button [tk_messageBox -icon question -type okcancel \
		      -title Message -parent .paratool_intcoor \
		      -message "Autogenerate all redundant internal coordinates that\ndepend on the bonds currently defined in VMD?\n(All currently defined internal coordinates will be lost.)"]
       if {$button=="cancel"} { return 0 }
    }

    variable zmat [modredundant_zmat]
    update_zmat

    variable importknowntopo
    if {$importknowntopo} {
       import_known_impropers
    }

    update_zmat

    assign_known_bonded_charmm_params

    .paratool_intcoor.zmat.pick.list see [.paratool_intcoor.zmat.pick.list index active]
    return 1
 }


#############################################################
# Reads the known impropers from the psf file and adds them #
# to the molecule list.                                     #
#############################################################

proc ::Paratool::import_known_impropers {} {
   variable psfconformations
   variable fragmentseltext
   variable molidparent
   variable molidbase

   if {$molidparent<0} { return }
   set fragselparent [atomselect $molidparent "($fragmentseltext) and not unparametrized"]
   
   set imprplist [list]
   foreach imprp [lindex $psfconformations 2] {
      set sel [atomselect $molidparent "index $imprp and ($fragmentseltext) and not unparametrized"]
      if {[$sel num]==4} {
	 set sel0 [atomselect $molidparent "index [lindex $imprp 0]"]
	 set sel1 [atomselect $molidparent "index [lindex $imprp 1]"]
	 set sel2 [atomselect $molidparent "index [lindex $imprp 2]"]
	 set sel3 [atomselect $molidparent "index [lindex $imprp 3]"]
	 set bsel0 [atomselect $molidbase "name [$sel0 get name] and resid [$sel0 get resid] and segid [$sel0 get segid]"]
	 set bsel1 [atomselect $molidbase "name [$sel1 get name] and resid [$sel1 get resid] and segid [$sel1 get segid]"]
	 set bsel2 [atomselect $molidbase "name [$sel2 get name] and resid [$sel2 get resid] and segid [$sel2 get segid]"]
	 set bsel3 [atomselect $molidbase "name [$sel3 get name] and resid [$sel3 get resid] and segid [$sel3 get segid]"]

	 lappend imprplist [join [list [$bsel0 get index] [$bsel1 get index] [$bsel2 get index] [$bsel3 get index]]]
      }
   }

   variable zmat
   variable ncoords
   variable nimprops
   foreach imprp $imprplist {
      set atom0 [lindex $imprp 0]
      set atom1 [lindex $imprp 1]
      set atom2 [lindex $imprp 2]
      set atom3 [lindex $imprp 3]
     
      label add Dihedrals $molidparent/$atom0 $molidparent/$atom1 $molidparent/$atom2 $molidparent/$atom3
      set val [lindex [lindex [label list Dihedrals] end] 4]
      label delete Dihedrals all

      set ret [find_new_coordinate_position $zmat imprp]
      set num [lindex $ret 0]
      set newzmat $zmat
      lappend newzmat [list O$num imprp $imprp $val {} {}]
      incr ncoords
      incr nimprops
      lset newzmat {0 1} $ncoords
      lset newzmat {0 5} $nimprops
      set zmat $newzmat
   }

   return $imprplist
}


###########################################################
# Generates redundant internal coordinates that depend on #
# the bonds currently defined in VMD.                     #
# Existing coordinates are not effected.                  #
###########################################################

proc ::Paratool::modredundant_zmat { {seltext all} {debug 1} } {
   variable autogendiheds
   variable molidbase
   set sel [atomselect $molidbase $seltext]
   set neighborlist [$sel getbonds]
   set bondlist  [::util::bondlist -molid $molidbase -sel $sel]
   set anglelist [::util::anglelist -sel $sel]

   if {$autogendiheds=="one"} {
      set dihedlist [::util::dihedlist -sel $sel -bonds $bondlist]
   } else {
      set dihedlist [::util::dihedlist -sel $sel -bonds $bondlist -all]
   }

   if {$molidbase>=0} {
      if {[molinfo $molidbase get numframes]>0} {
	 set natoms [molinfo $molidbase get numatoms]
      }
   } else { return }

   set ncoords 0
   set nbonds   0
   set nangles  0
   set ndiheds  0
   set nimprops 0
   set havepar 1
   set havefc 0
   set zmat [default_zmat]

   foreach ilist $bondlist {
      # See if the bond exists already
      set found [lsearch $zmat "* bond \{$ilist\} *"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch $zmat "* bond \{$ilist\} *"]
      }
      if {$found>=0} { continue }

      incr nbonds
      set name "R$nbonds"
      set sel1  [atomselect $molidbase "index [lindex $ilist 0]"]
      set sel2  [atomselect $molidbase "index [lindex $ilist 1]"]
      set pos1  [join [$sel1 get {x y z}]]
      set pos2  [join [$sel2 get {x y z}]]
      set val   [veclength [vecsub $pos2 $pos1]]
      $sel1 delete
      $sel2 delete

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
      if {$debug} { puts "Added [list R$num bond $ilist $val {} {}]" }
   }

   foreach ilist $anglelist {
      # See if the angle exists already
      set found [lsearch -regexp $zmat "(angle|lbend)\\s+\\{$ilist\\}"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 2] [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch -regexp $zmat "(angle|lbend)\\s+\\{$ilist\\}"]
      }
      if {$found>=0} { continue }

      incr nangles
      set name "A$nangles"
      foreach {atom0 atom1 atom2} $ilist {break}
      label add Angles $molidbase/$atom0 $molidbase/$atom1 $molidbase/$atom2 
      set val [lindex [lindex [label list Angles] end] 3]
      label delete Angles

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
      #set zmat [::QMtool::sort_zmat $zmat]
      if {$debug} { puts "Added [list A$num angle $ilist $val {} {}]" }
   }

   foreach ilist $dihedlist {
      # See if the dihed exists already
      set found [lsearch $zmat "* dihed \{$ilist\} *"]
      if {$found<0} { 
	 set ilist [list [lindex $ilist 3] [lindex $ilist 2] [lindex $ilist 1] [lindex $ilist 0]]
	 set found [lsearch $zmat "* dihed \{$ilist\} *"];
      }
      if {$found>=0} { continue }

      incr ndiheds
      set name "D$ndiheds"
      foreach {atom0 atom1 atom2 atom3} $ilist {break}
      label add Dihedrals $molidbase/$atom0 $molidbase/$atom1 $molidbase/$atom2 $molidbase/$atom3
      set val [lindex [lindex [label list Dihedrals] end] 4]
      label delete Dihedrals

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
      if {$debug} { puts "Added [list D$num dihed $ilist $val {} {}]" }
   }

   set ncoords [expr $nbonds+$nangles+$ndiheds+$nimprops]
   lset zmat 0 [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]

   variable ringlist [::util::find_rings $molidbase]

  # Sort the Z-matrix so that the bonds come first,then angles, then diheds
   return [::QMtool::sort_zmat $zmat]
}

######################################################
# Recalculate the bonds based on the atom distance.  #
# VMD's bondlist and zmat will be updated.           #
# Angles and dihedrals containing deleted bonds are  #
# not removed.                                       #
######################################################

proc ::Paratool::recalculate_bonds {} {
   variable zmat
   variable maxbondlength
   variable molidbase
   set sel [atomselect $molidbase all]
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

##############################################################
# If bond does not yet exist in vmd's bond list then add it. #
# If the bondorder is specified then it is set acordingly.   #
##############################################################

proc ::Paratool::vmd_addbond {atom0 atom1 molid {bondorder {}}} {
   set sel [atomselect $molid all]
   set bondlist [$sel getbonds]
   set bondorders [$sel getbondorders]
   set bondatom0 [lindex $bondlist $atom0]
   set ind1 [lsearch $bondatom0 $atom1]
   if {$ind1<0} {
      set newlist [join [concat $bondatom0 $atom1]]
      #puts "newlist1: $newlist atom0=$atom0"
      lset bondlist $atom0 $newlist
      if {[llength $bondorder]} {
	 set bo0 [lindex $bondorders $atom0]
	 set newbo [join [concat $bo0 $bondorder]]
	 lset bondorders $atom0 $newbo
      }
   } else {
      if {[llength $bondorder]} {
	 lset bondorders $atom0 $ind1 $bondorder
      }      
   }

   set bondatom1 [lindex $bondlist $atom1]
   set ind2 [lsearch $bondatom1 $atom0]
   if {$ind2<0} {
      set newlist [join [concat $bondatom1 $atom0]]
      #puts "newlist2: $newlist atom0=$atom0"
      lset bondlist $atom1 $newlist
      if {[llength $bondorder]} {
	 set bo1 [lindex $bondorders $atom1]
	 set newbo [join [concat $bo1 $bondorder]]
	 lset bondorders $atom1 $newbo
      }
   } else {
      if {[llength $bondorder]} {
	 lset bondorders $atom1 $ind2 $bondorder
      }      
   }


   if {$ind1>=0 && $ind2>=0} { 
      if {[llength $bondorder]} {
	 $sel setbondorders $bondorders
      }
      return 1
   } elseif {$ind1>=0 || $ind2>=0} {
      return 1
   }

   $sel setbonds $bondlist
   if {[llength $bondorder]} {
      $sel setbondorders $bondorders
   }

   return 0
}

#################################################
# Update the bondlist that VMD keeps.           #
#################################################

proc ::Paratool::update_vmd_bondlist {} {
   variable zmat
   variable molidbase
   vmd_clear_bondlist $molidbase
   foreach entry $zmat {
      set type [lindex $entry 1]
      if {$type!="bond"} { continue }
      set atom0 [lindex [lindex $entry 2] 0]
      set atom1 [lindex [lindex $entry 2] 1]
      vmd_addbond $atom0 $atom1 $molidbase
   }
}


##############################################################
# If bond does exist in vmd's bond list then return 1, else  #
# return 0.                                                  #
##############################################################

proc ::Paratool::vmd_bond_exists {atom0 atom1 molid} {
   set sel [atomselect $molid all]
   set bondlist [$sel getbonds]
   set bondatom0 [lindex $bondlist $atom0]
   set ind [lsearch $bondatom0 $atom1]
   if {$ind>=0} { return 1 }
   return 0
}


##############################################################
# Find a position for a newly added coordinate.of a certain  #
# type (bond|angle|dihed|improper).                          #
# Returns the first free index for the selected type and the #
# absolute index in the zmat.                                #
##############################################################

 proc find_new_coordinate_position { zmat type } {
    set num 1
    set oldnum 0
    set namelist {}
    set entries [lsearch -inline -all $zmat "* $type *"]
    foreach entry $entries {
       lappend namelist [lindex $entry 0]
    }
    set name {}
    foreach name [lsort -dictionary $namelist] {
       set num [string range [lindex $name 0] 1 end]
       if {$num>[expr $oldnum+1]} { break }
       set oldnum $num
    }

    set num [expr $oldnum+1];
    if {[llength $name]} {
       set act [lsearch $zmat "$name *"]
    } else {
       # FIXM: Must handle the case where no coordinate of the given type is existing
       #set tlist {{bond R} {angle A} {lbend A} {dihed D} {imprp O}}
       set act $num
    }
    return [list $num $act]
 }


##############################################################
# Check if an atomlist (in arbitrary order) is registered    #
# as bond in $zmat. If yes, return it's index in zmat, else  #
# return -1.                                                 #
##############################################################

proc ::Paratool::is_zmat_bond {atomlist} {
   variable zmat
   # Check if the coordinate exists already
   return [lsearch -regexp $zmat "\\s.*bond\\s\\{($atomlist|[lrevert $atomlist])\\}\\s"]
}

##############################################################
# Check if an atomlist (in arbitrary order) forms a bond     #
# angle, i.e. the atoms must be bonded in a row. If this     #
# angle is in $zmat then return the index in zmat, else      #
# return -1.                                                 #
##############################################################

proc ::Paratool::is_zmat_angle {atomlist} {
   variable molidbase
   set chain [is_chain $atomlist $molidbase]
   if {![llength $chain]} { return -1 }
   
   variable zmat
   # Check if the coordinate exists already
   return [lsearch -regexp $zmat "\\s(angle|lbend)\\s\\{($chain|[lrevert $chain])\\}\\s"]
}

##############################################################
# Check if an atomlist (in arbitrary order) forms a dihedral #
# angle, i.e. the atoms must be bonded in a row. If this     #
# dihedral is in $zmat then return the index in zmat, else   #
# return -1.                                                 #
##############################################################

proc ::Paratool::is_zmat_dihedral {atomlist} {
   variable molidbase
   set chain [is_chain $atomlist $molidbase]
   if {![llength $chain]} { return -1 }

   variable zmat
   # Check if the coordinate exists already
   return [lsearch -regexp $zmat "\\sdihed\\s\\{($chain|[lrevert $chain])\\}\\s"]
}

proc ::Paratool::is_zmat_improper {atomlist} {
   variable molidbase
   set chain [is_improper $atomlist $molidbase]
   if {![llength $chain]} { return -1 }

   variable zmat
   # Check if the coordinate exists already
   return [lsearch -regexp $zmat "\\simprp\\s\\{($chain|[lrevert $chain])\\}\\s"]
}


##############################################################
# Check if an atomlist (in arbitrary order) forms a chain,   #
# i.e. the atoms must be bonded in a row. If yes, return the #
# atoms in chain order, else return {}.                      #
# Based on VMD's bondlist.                                   #
##############################################################

proc ::Paratool::is_chain {atomlist molid} {
   set sel [atomselect $molid "index [lindex $atomlist 0]"]
   set nbsel [atomselect $molid "index [join [$sel getbonds]] and index $atomlist"]
   set next [join [$nbsel list]]
   set chain {}
   if {[$nbsel num]==1} {
      set chain [walk_bond_chain [list [lindex $atomlist 0] $next] $next $atomlist $molid 4]
   } elseif {[$nbsel num]==2} {
      set left [lindex $next 0]
      set chainl [walk_bond_chain [list [lindex $atomlist 0] $left] $left $atomlist $molid 4]
      set right [lindex $next 1]
      set chainr [walk_bond_chain [list [lindex $atomlist 0] $right] $right $atomlist $molid 4]
      set chain [concat [lrevert [lrange $chainl 1 end]] [lindex $atomlist 0] [lrange $chainr 1 end]]
   }

   if {[llength $chain]==[llength $atomlist]} {
      return $chain
   } else {
      return {}
   }
}

proc ::Paratool::walk_bond_chain {chain chainend atomlist molid {maxdepth 4} {depth 0}} {
   set sel [atomselect $molid "index $chainend"]
   set nbsel [atomselect $molid "index [join [$sel getbonds]] and index $atomlist and not index $chain"]

   incr depth
   if {$depth>$maxdepth} { return $chain }

   if {[$nbsel num]!=1} { return $chain }
   lappend chain [join [$nbsel get index]]
   return [walk_bond_chain $chain [join [$nbsel get index]] $atomlist $molid $maxdepth $depth]
}


##############################################################
# Check if a dihedral forms an improper dihedral, if yes,    #
# return 1 else return 0. Based on VMD's bondlist.           #
##############################################################

proc ::Paratool::is_improper {atomlist molid} {
   set sel [atomselect $molid "index $atomlist"]
   set i 0
   foreach atom [$sel list] bonds [$sel getbonds] {
      set nbsel [atomselect $molid "index $bonds and index $atomlist"]
      if {[$nbsel num]==3} { 
	 if {$atom==[lindex $atomlist 0]} {
	    return [concat $atom [lrange $atomlist 1 end]]
	 }
	 return [concat $atom [$nbsel list]]
      }
      incr i
   }

   return {}
}


################################################
# Returns the reverse of a list.               #
################################################

proc ::Paratool::lrevert { list } {
   set newlist {}
   for {set i [expr [llength $list]-1]} {$i>=0} {incr i -1} {
      lappend newlist [lindex $list $i]
   }
   return $newlist
}

