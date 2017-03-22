# utilities - Generally useful procedures

package provide utilities 1.0

namespace eval ::util:: {}

#########################################################
# Converts degree to radians.                           #
#########################################################

proc ::util::deg2rad { deg } {
   return [expr {$deg*0.0174532925}]
}

#########################################################
# Converts radians to degree.                           #
#########################################################

proc ::util::rad2deg { rad } {
   return [expr {$rad*57.2957795786}]
}


##########################################################
# Returns the min/max value.                             #
##########################################################

proc ::util::min {a b} { return [expr {$a<$b ? $a : $b}] }
proc ::util::max {a b} { return [expr {$a>$b ? $a : $b}] }


#--------------------------------------------------------#
#--------------------------------------------------------#
#           Argument parsing                             #
#--------------------------------------------------------#
#--------------------------------------------------------#

##########################################################
# Extracts the arguments of an option from a list and    #
# returns them. If the option $tag was not found the     #
# default value $deflt is returned. The number of        #
# arguments that will be returned is specified with $n.  #
# Example:                                               #
# ::util::getargs {-a arg1 -b -c arg2 arg3 -d} "-c" {} 2 #
# --> arg1 arg2                                          #
##########################################################

proc ::util::getargs {arglist tag deflt {n 1}} {
   set pos [lsearch $arglist $tag]
   if {!$n} { return [expr {$pos<0 ? 0 : 1}] }
   if {$pos<0}  { return $deflt }
   return [join [lrange $arglist [expr {$pos+1}] [expr {$pos+$n}]]]
}


##########################################################
# Checks if a certain switch $tag occurs in $taglist.    #
# Example:                                               #
# ::util::getswich {-a 5 -b -c} "-b"                     #
# --> 1                                                  #
##########################################################

proc ::util::getswitch {arglist tag} {
   return [expr {[lsearch $arglist $tag]<0 ? 0 : 1}]
}


#--------------------------------------------------------#
#--------------------------------------------------------#
#           List procedures                              #
#--------------------------------------------------------#
#--------------------------------------------------------#

###################################################
# Returns the min/max values of a list of real or #
# integer numbers.                                #
###################################################

proc ::util::lmin {list} { return [lindex [lsort -real $list] 0] }
proc ::util::lmax {list} { return [lindex [lsort -real $list] end] }

###################################################
# Returns the difference of lists a and b,        #
# i.e all elements that occur in a, but not in b. #
###################################################

proc ::util::ldiff { a b } {
   set r {}
   foreach j $a {
      if { [lsearch $b $j]==-1 } {
         lappend r $j
      }
   }
   return $r
}


###########################################################
# Returns the opposite of the intersection of two lists,  #
# i.e. all elements that occur only in one of both lists. #
###########################################################

proc ::util::lnand { a b } {
   set r {}
   foreach j $a {
      if { [lsearch $b $j]==-1 } {
         lappend r $j
      }
   }
   foreach j $b {
      if { [lsearch $a $j]==-1 } {
         lappend r $j
      }
   }
   return $r
}


#############################################################
# Returns the intersection of two lists, i.e. all elements  #
# that occur at least once in both lists.                   #
#############################################################

proc ::util::lintersect { a b } {
   set r {}
   foreach j $a {
      if { [lsearch $b $j]>=0 } {
         lappend r $j
      }
   }
   foreach j $b {
      if { [lsearch $a $j]>=0 } {
         lappend r $j
      }
   }
   if { [llength $r]>0 } { return [lsort -unique $r] }
}


#############################################################
# Returns the last index in which two lists are equal.      #
# Returns -1 if the lists differ from the beginning.        #
#############################################################

proc ::util::lcompare { a b } {
   set c -1
   foreach i $a j $b {
      if { $i!=$j } {
	 return $c
      }
      incr c
   }
   return $c
}


#############################################################
# Returns the first sublist of b that is contained in a.    #
# If -all is specified, then all sublists are returned.     #
# Example:                                                  #
# ::util::lcontains {a b c d e f g} {x b c y e f z} -all    #
# --> {b c} {e f}                                           #
#############################################################

proc ::util::lcontains {a b args} {
   set all [getswitch $args "-all"]
   set listofsame {}
   set posb 0
   set last 0
   set first 0
   for {set posb 0} {$posb<[llength $b]} {incr posb} {
      set elem [lindex $b $posb]
      set posa [lsearch -start $first $a $elem]

      if {$posa>=$first && $first<[llength $a]} {
	 set last [lcompare [lrange $a $posa end] [lrange $b $posb end]]
	 lappend listofsame [lrange $b $posb [expr {$posb+$last}]]
	 #puts "last=$last first=$first posa=$posa posb=$posb"
	 set posb  [expr {$posb+$last}]
	 set first [expr {$posa+$last+1}]
	 if {!$all || $last<0} { return [join $listofsame] }
      } 
   }

   return $listofsame
}


################################################
# Returns the reverse of a list.               #
################################################

proc ::util::lrevert { list } {
   set newlist {}
   for {set i [expr [llength $list]-1]} {$i>=0} {incr i -1} {
      lappend newlist [lindex $list $i]
   }
   return $newlist
}


##########################################################
# Sorts elements in list1 in the same way as list2 would #
# be sorted using the rules given in args. The options   #
# in $args are passed on to the underlying TCL lsort     #
# command.                                               #
# Example:                                               #
# ::util::sort_alike {a b c d} {3 2 4 1} -integer        #
# --> c b d a                                            #
##########################################################

proc ::util::sort_alike { list1 list2 args } {
   set index {}
   if {[lsearch $args "-index"]>=0}  {
      set index [lindex $args [expr {1+[lsearch $args "-index"]}]]
   }

   foreach s $list1 t $list2 {
      if {[llength $index]} {
	 lappend combined [list $s [lindex $t $index]]
      } else {
	 lappend combined [list $s $t]
      }
   }

   foreach pair [eval lsort $args -index 1 [list $combined]] {
      lappend sorted1 [lindex $pair 0]
      lappend sorted2 [lindex $pair 1]
   }
   return [list $sorted1 $sorted2]
}


#--------------------------------------------------------#
#--------------------------------------------------------#
#           Ring finding procedures                      #
#--------------------------------------------------------#
#--------------------------------------------------------#

##########################################################
# Finds rings in the molecule.                           #
# For each ring a list of atom indices describing the    #
# ring is returned.                                      #
##########################################################

proc ::util::find_rings {molid} {
   set rings [_find_rings_recursive 0 $molid]
   if {![llength $rings]} {
      return {}
   }

   foreach ring $rings {
      lappend sorted [lsort -unique -integer $ring]
   }

   set allrings [lindex [sort_alike $rings $sorted -unique] 0]

   return [unique_rings $allrings]
}


##########################################################
# Recursive helper function for find_rings.              #
# Returns a non-unique list of rings which have to be    #
# sorted and cleaned by find_rings. I.e. rings appear    #
# multiple times in the list if they were entered from   #
# different points or traversed in different directions. #
##########################################################

proc ::util::_find_rings_recursive {index molid {atrace {}}} {
   set pos [lsearch $atrace $index]
   if {$pos>=0} {
      # Ring found!
      set found [lrange $atrace $pos end]
      set smallest [lsearch $found [lindex [lsort -integer $found] 0]]
      return [concat [lrange $found $smallest end] [lrange $found 0 [expr {$smallest-1}]]]
   }
   set rings {}
   set sel [atomselect $molid "index $index"]

   foreach child [join [$sel getbonds]] {
      if {$child == [lindex $atrace end]} {
	 # Don't just go back to grandma (avoid two membered rings)
	 continue
      }
      
      set ret [_find_rings_recursive $child $molid [concat $atrace $index]]
      if {[llength $ret]} {
	 if {[llength $ret]>1 && [string is integer [lindex $ret 0]]} {
	    lappend rings $ret
	 } else {
	    set rings [concat $rings $ret]
	 }
      }
   }
   $sel delete
   
   if {[llength $rings]} {
      # Crawling up the recursive tree
      return [lsort -unique $rings]
   }

   # If we have no children other than our own grandma we found a tree end
   return {}
}


#################################################################
# Removes rings that enclose other rings from the given list    #
# of rings.                                                     #
#################################################################

proc ::util::unique_rings {ringlist} {
   set i 1
   set badrings {}
   # Compare all rings, if the overlap>2 then the smaller ring
   # is part of the larger one.
   foreach ring1 $ringlist {
      foreach ring2 [lrange $ringlist $i end] {
	 #puts "$ring1 -- $ring2"
	 set compare [compare_rings $ring1 $ring2]	 
	 if {[llength $compare]>2} {
	    if {[llength $ring1]>[llength $ring2]} {
	       lappend badrings $ring1
	    } else {
	       lappend badrings $ring2
	    }
	 }
      }
      incr i
   }

   # Exclude the enclosing rings from the ringlist
   set uniquerings {}
   foreach ring $ringlist {
      if {[lsearch $badrings $ring]<0} {
	 lappend uniquerings $ring
      }
   }
   return $uniquerings
}


#################################################################
# Compare two rings, return the longest common chain.           #
#################################################################

proc ::util::compare_rings {ring1 ring2} {
   set d1 [concat $ring1 $ring1]
   set d2 [concat $ring2 $ring2]
   set sub [lcontains $d1 $d2 -all]
   set rsub [lcontains $d1 [lrevert $ring2] -all]

   set best {}
   set maxlen 0
   foreach frag [concat $sub $rsub] {
      if {[llength $frag]>$maxlen} {
	 set maxlen [llength $frag]
	 set best $frag
      }
   }

   #if {[llength $best]<1} { puts "SEPARATE" }
   #if {[llength $best]==1} { puts "TOUCH" }
   #if {[llength $best]==2} { puts "ADJACENT" }
   #if {[llength $best]>2} { puts "SUBRING" }
   return $best
}


#################################################################
# Return the ring, which is a list of atoms, in a different     #
# order, beginning with atom $ind1. If the second atom $ind2 is #
# given then the ring is returned in the according order        #
#  starting with $ind1 $ind2.                                   #
#################################################################

proc ::util::reorder_ring {ring ind1 {ind2 {}}} {
   set pos1 [lsearch $ring $ind1]
   if {$pos1<0} { return }
   set neworder [concat [lrange $ring $pos1 end] [lrange $ring 0 [expr {$pos1-1}]]]
   if {[llength $ind2]} {
      if {[lsearch $neworder $ind2]>[llength $ring]/2.0} {
	 set neworder [concat $ind1 [lrevert [lrange $neworder 1 end]]]
      }
   }
   return $neworder
}


#--------------------------------------------------------#
#--------------------------------------------------------#
#           Topology procedures                          #
#--------------------------------------------------------#
#--------------------------------------------------------#

#################################################
# Clear VMD's bondlist, no bond will be drawn   #
# on the screen anymore                         #
#################################################

proc ::util::clear_bondlist {molid} {
   set natoms [molinfo $molid get numatoms]
   set bondlist {}
   for {set i 0} {$i<$natoms} {incr i} {
      lappend bondlist {}
   }
   set sel [atomselect $molid all]
   $sel setbonds $bondlist
}


##############################################################
# If bond does not yet exist in vmd's bond list then add it. #
##############################################################

proc ::util::addbond {molid atom0 atom1} {
   set sel [atomselect $molid all]
   set bondlist [$sel getbonds]
   set bondatom0 [lindex $bondlist $atom0]
   set ind1 [lsearch $bondatom0 $atom1]
   if {$ind1<0} {
      set newlist [join [join [list $bondatom0 $atom1]]]
      #puts "newlist1: $newlist"
      lset bondlist $atom0 $newlist
   }

   set bondatom1 [lindex $bondlist $atom1]
   set ind2 [lsearch $bondatom1 $atom0]
   if {$ind2<0} {
      set newlist [join [join [list $bondatom1 $atom0]]]
      #puts "newlist2: $newlist"
      lset bondlist $atom1 $newlist
   }

   if {$ind1>=0 && $ind2>=0} { return 1 }
   $sel setbonds $bondlist
   return 0
}


##############################################################
# If bond does exist in vmd's bond list then remove it.      #
##############################################################

proc ::util::delbond {molid atom0 atom1} {
   set sel [atomselect $molid all]
   set bondlist [$sel getbonds]
   
   set bondatom0 [lindex $bondlist $atom0]
   set ind1 [lsearch $bondatom0 $atom1]
   set newlist [lreplace $bondatom0 $ind1 $ind1]
   lset bondlist $atom0 $newlist

   set bondatom1 [lindex $bondlist $atom1]
   set ind2 [lsearch $bondatom1 $atom0]
   set newlist [lreplace $bondatom1 $ind2 $ind2]
   lset bondlist $atom1 $newlist

   $sel setbonds $bondlist
   if {$ind1>=0 && $ind2>=0} { return 1 }
   return 0
}


###########################################################
# Returns a list of bonded atom pairs.                    #
# If no selection is specified all atoms are considered.  #
###########################################################

proc ::util::bondlist { args } {
   set molid [getargs $args "-molid" top]
   set sel   [getargs $args "-sel" {}]
   if {![llength $sel]} {
      set sel [atomselect $molid all]
   }
   set bondsperatom [$sel getbonds]

   set bonds {}
   foreach bpa $bondsperatom atom1 [$sel list] {
      foreach partner $bpa {
	 lappend bonds [lsort -integer [list $atom1 $partner]]
      }
   }

   return [lsort -dictionary -unique $bonds]
}


#############################################################
# Returns a list of triples defining bond angles that can   #
# be constructed from the existing bonds.                   #
# If no selection is specified all atoms are considered.    #
#############################################################

proc ::util::anglelist { args } {
   set molid [getargs $args "-molid" top]
   set sel   [getargs $args "-sel" {}]
   if {![llength $sel]} {
      set sel [atomselect $molid all]
   }
   set anglelist {}
   foreach neighborperatom [$sel getbonds] center [$sel list] {
      foreach neighbor1 $neighborperatom {
	 if {$neighbor1==$center} { continue }
	 foreach neighbor2 $neighborperatom {
	    if {$neighbor2==$center} { continue }
	    if {$neighbor1!=$neighbor2} {
	       lappend anglelist [list $neighbor1 $center $neighbor2]
	    }
	 }
      }
    }

   set reverse {}
   set compressedlist {} 
   foreach angle [lsort -dictionary -unique $anglelist] {
      lappend reverse [list [lindex $angle 2] [lindex $angle 1] [lindex $angle 0]]
      if {[lsearch $reverse $angle]<0} {
	 lappend compressedlist $angle
      }
   }
   return $compressedlist
}


##############################################################
# Returns a list of quadruples defining dihedral angles      #
# that can be constructed from the existing bonds. If you    #
# already have a bondlist as created by ::util::bondlist,    #
# you can provide it via -bonds, thus enabling faster        #
# computation. If you don't specify -all then only one       #
# dihedral angle will be generated per bond.                 #
##############################################################

proc ::util::dihedlist { args } {
   set molid    [getargs $args "-molid" top]
   set sel      [getargs $args "-sel" {}]
   set bondlist [getargs $args "-bonds" {}]
   set all   [getswitch $args "-all"]

   if {![llength $sel]} {
      set sel [atomselect $molid all]
   }
   if {![llength $bondlist]} {
      set bondlist [bondlist -sel $sel]
   }
   set atomlist [$sel list]
   set neighborlist [$sel getbonds]

   set dihedlist {}
   foreach bond $bondlist {
      set atom1 [lindex $bond 0]
      set atom2 [lindex $bond 1]
      if {$atom1==$atom2} { continue }
      set neighbors1 [lindex $neighborlist [lsearch $atomlist $atom1]]
      set neighbors2 [lindex $neighborlist [lsearch $atomlist $atom2]]

      set lfound 0
      foreach leftneighbor $neighbors1 {
	 if {$leftneighbor==$atom1 || $leftneighbor==$atom2} { continue }
	 if {!$all && $lfound} { continue }
	 set rfound 0
	 foreach rightneighbor $neighbors2 {
	    if {$rightneighbor==$atom1 || $rightneighbor==$atom2 || 
		$rightneighbor==$leftneighbor} { continue }
	    if {!$all && $rfound} { continue }
	    lappend dihedlist [list $leftneighbor $atom1 $atom2 $rightneighbor]
	    set rfound 1
	    set lfound 1
	 }
      }
   }
   return $dihedlist
}


#############################################################
# Returns a list of atoms that are part of the tree of      #
# bonded atoms starting with the root $atom0 continuing     #
# towards $atom1. If $atom1 is empty then the bonds in      #
# each direction are followed until $maxdepth is reached,   #
# respectively. If -all is specified, for instance in       #
# conjunction with -maxdepth 4, then the atoms bonded 1-2   #
# and 1-3 to $atom0 are also returned.                      #
# Example:                                                  #
#  ::util::bondedsel top 8 9 -maxdepth 3                    #
#  --> Returns all atoms that are bonded in 1-3 distance    #
#      to atom 8 in the direction of the bond 8--9.         #
#############################################################

proc ::util::bondedsel { molid atom0 atom1 args } {
   set maxdepth [getargs $args "-maxdepth" 20]
   set all [getswitch $args "-all"]

   if {![llength $atom1]} { set atom1 $atom0; set atom0 {} }
 
   if {$all} {
      return [_bondedsel $molid $atom1 $atom0 $maxdepth 0]
   } else {
      return [_bondedsel-n $molid $atom1 $atom0 $maxdepth 0 {}]
   }
}

#############################################################
# Recursive auxiliary proc for bondedsel;                   #
# (This is why I call the root $visited:                    #
# these are the atoms that were visited already and atom0   #
# is the first visited atom.)                               #
#############################################################
proc ::util::_bondedsel { molid atom1 {visited {}} {maxdepth 20} {depth 0} } {
   set sel1 [atomselect $molid "index $atom1"]
   set bonds [join [$sel1 getbonds]]
   if {![llength $bonds]} { return }
   if {[llength $visited]} {
      set nbsel [atomselect $molid "index [join [$sel1 getbonds]] and not index [join $visited]"]
   } else {
      set nbsel [atomselect $molid "index [join [$sel1 getbonds]]"]
   }
   #puts "atom1=$atom1; [$nbsel list]; $depth"

   incr depth
   if {$depth>$maxdepth} { return }

   lappend visited $atom1
   if {![$nbsel num]} { return $atom1 }

   foreach nb [$nbsel list] {
      lappend visited [_bondedsel $molid $nb $visited $maxdepth $depth]
   }

   return [lsort -unique -integer [join $visited]]
}


#############################################################
# Returns a list of atoms that are 1-n bonded with respect  #
# to atom $visited.                                         #
# Recursive auxiliary proc for bondedsel;                   #
# (This is why I call the root $visited:                    #
# these are the atoms that were visited already and atom0   #
# is the first visited atom.)                               #
#############################################################

proc ::util::_bondedsel-n { molid atom1 {visited {}} {maxdepth 20} {depth 0} {found {}} } {

   set sel1 [atomselect $molid "index $atom1"]
   set nbsel {}
   if {[llength $visited]} {
      set nbsel [atomselect $molid "index [join [$sel1 getbonds]] and not index [join $visited]"]
   } else {
      set nbsel [atomselect $molid "index [join [$sel1 getbonds]]"]
   }
   #puts "atom1=$atom1; nbsel=[$nbsel list]; depth=$depth; found=$found"

   incr depth
   if {$depth>$maxdepth} { return }

   lappend visited $atom1
   if {$depth==$maxdepth} { return [list $atom1 $atom1]}
   if {![$nbsel num]} { return [list $atom1 {}]}

   foreach nb [$nbsel list] {
      set ret [_bondedsel-n $molid $nb $visited $maxdepth $depth $found]
      lappend visited [lindex $ret 0]
      lappend found   [lindex $ret 1]
   }

   return [list [lsort -unique -integer [join $visited]] [lsort -unique -integer [join $found]]]
}


