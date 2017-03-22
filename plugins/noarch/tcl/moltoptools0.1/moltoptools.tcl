package provide moltoptools 0.1

namespace eval ::moltoptools:: {

}

# Checks if a certain switch $tag occurs in $taglist
proc ::moltoptools::getswitch {arglist tag} {
   return [expr {[lsearch $arglist $tag]<0 ? 0 : 1}]
}

proc ::moltoptools::max {a b} { return [expr {$a>$b ? $a : $b}] }
proc ::moltoptools::min {a b} { return [expr {$a<$b ? $a : $b}] }

proc ::moltoptools::lrevert { list } {
   set newlist {}
   for {set i [expr [llength $list]-1]} {$i>=0} {incr i -1} {
      lappend newlist [lindex $list $i]
   }
   return $newlist
}


##########################################################
# Finds rings in the molecule.                           #
# For each ring a list of atom indices describing the    #
# ring is returned.                                      #
##########################################################

proc ::moltoptools::find_rings {molid} {
   set rings [_find_rings_recursive 0 $molid]
   if {![llength $rings]} {
      return {}
   }

   foreach ring $rings {
      lappend sorted [lsort -unique -integer $ring]
   }

   set allrings [lindex [sort_alike $rings $sorted -unique] 0]

   return [ring_unique $allrings]
}


##########################################################
# Recursive helper function for find_rings.              #
# Returns a non-unique list of rings which have to be    #
# sorted and cleaned by find_rings. I.e. rings appear    #
# multiple times in the list if they were entered from   #
# different points or traversed in different directions. #
##########################################################

proc ::moltoptools::_find_rings_recursive {index molid {atrace {}}} {
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

# Removes rings that enclose other rings from the ringlist
proc ::moltoptools::ring_unique {ringlist} {
   set i 1
   set badrings {}
   # Compare all rings, if the overlap>2 then the smaller ring
   # is part of the larger one.
   foreach ring1 $ringlist {
      foreach ring2 [lrange $ringlist $i end] {
	 #puts "$ring1 -- $ring2"
	 set compare [ring_compare $ring1 $ring2]	 
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


# Compare two rings, return the longest common chain
proc ::moltoptools::ring_compare {ring1 ring2} {
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


# Returns the last index in which two lists are equal.
# Returns -1 if the lists differ from the beginning.
proc lcompare { a b } {
   set c -1
   foreach i $a j $b {
      if { $i!=$j } {
	 return $c
      }
      incr c
   }
   return $c
}


# Returns the first sublist of b that is contained in a  
proc ::moltoptools::lcontains {a b args} {
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

proc ::moltoptools::ring_order {ring ind1 {ind2 {}}} {
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

proc ::moltoptools::atom_in_ring {index} {
   variable ringlist
   set found {}
   set i 0
   foreach ring $ringlist {
      set pos [lsearch $ring $index]
      if {$pos>=0} {
	 lappend found $i
      }
      incr i
   }
   return $found
}

proc ::moltoptools::bond_in_ring {ind1 ind2} {
   variable ringlist
   set found {}
   set i 0
   foreach ring $ringlist {
      set pos1 [lsearch $ring $ind1]
      if {$pos1>=0} {
	 set pos2 [lsearch $ring $ind2]
	 if {$pos2>=0 && (abs($pos2-$pos1)==1 || abs($pos2-$pos1)==[llength $ring]-1)} {
	    lappend found $i
	 }
      }
      incr i
   }
   return $found
}

proc ::moltoptools::angle_in_ring {ind1 ind2 ind3} {
   variable ringlist
   set found {}
   set i 0
   foreach ring $ringlist {
      set pos2 [lsearch $ring $ind2]
      if {$pos2>=0} {
	 set pos1 [lsearch $ring $ind1]
	 if {$pos1>=0 && (abs($pos1-$pos2)==1 || abs($pos1-$pos2)==[llength $ring]-1)} {
	    set pos3 [lsearch $ring $ind3]
	    if {$pos3>=0 && (abs($pos3-$pos2)==1 || abs($pos3-$pos2)==[llength $ring]-1)} {
	       lappend found $i
	    }
	 }
      }
      incr i
   }
   return $found
}

##########################################################
# Sorts elements in list1 in the same way as list2 would #
# be sorted using the rules given in args.               #
# Example:                                               #
# sort_alike {a b c d} {3 2 4 1} -integer                #
# --> c b d a                                            #
##########################################################

proc ::moltoptools::sort_alike { list1 list2 args } {
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

