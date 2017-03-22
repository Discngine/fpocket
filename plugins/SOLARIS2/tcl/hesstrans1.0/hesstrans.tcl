package provide hesstrans 1.0


proc hessiantransform {cartcoor carthess bondlist anglelist dihedlist imprplist} {
   puts "Running HessianTransform..."
   set numCartesians [llength $cartcoor]
   set numBonds [llength $bondlist]
   set numAngles [llength $anglelist]
   set numDihedrals [llength $dihedlist]
   set numImpropers [llength $imprplist]

   set numInternals [expr $numBonds+$numAngles+$numDihedrals+$numImpropers]
   
   #puts "  Load Cartesians"
   set cartesianListW [join $cartcoor]

   # Contains cartesians and cartesian Hessian
   set cartesianArrayW [new_double [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]]
   #puts "  \$numCartesians = $numCartesians; expr \$numCartesians * 3 = [expr $numCartesians * 3]"
   #puts "cartesianArrayW=$cartesianArrayW"
   for {set i 0} {$i < [expr $numCartesians * 3]} {incr i} {
      set_double $cartesianArrayW $i [lindex $cartesianListW $i]
   }
   #puts "  llength \$cartesianListW = [llength $cartesianListW]"

   if {[llength $carthess]!=[expr 3*$numCartesians]} {
      error "Cartesian hessian has wrong size [llength $carthess]!=$numCartesians"
   }

   if {[llength [lindex $carthess 0]]!=1 || [llength [lindex $carthess end]]!=[expr 3*$numCartesians]} {
      error "Cartesian hessian doesn't have lower tridiag form!"
   }

   set hessianCartesianList [join [diag2square $carthess]]
   if {[llength $hessianCartesianList]!=[expr ($numCartesians*3) * ($numCartesians*3)]} {
      error "[llength $hessianCartesianList]!=[expr ($numCartesians*3) * ($numCartesians*3)]"
   }
   for {set i 0} {$i < [expr ($numCartesians*3) * ($numCartesians*3)]} {incr i} {
      set_double $cartesianArrayW [expr ($numCartesians*3) + $i] [lindex $hessianCartesianList $i]
   }
   #puts "  llength \$hessianCartesianList = [llength $hessianCartesianList]"

   set intArrayW [new_int [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]]
   set j 0

   #puts "  Load Bonds"
   set bondListW [join $bondlist]
   #puts "  \$numBonds = $numBonds; expr \$numBonds * 2 = [expr $numBonds * 2]"
   for {set i 0} {$i < [expr $numBonds * 2]} {incr i} {
      # We have to increase the indices because indexes in hesstrans start with 1
      set_int $intArrayW $j [expr [lindex $bondListW $i]+1]
      incr j
   }
   
   #puts "  Load Angles"
   set angleListW [join $anglelist]
   #puts "  \$numAngles = $numAngles; expr \$numAngles * 3 = [expr $numAngles * 3]"
   for {set i 0} {$i < [expr $numAngles * 3]} {incr i} {
      # We have to increase the indices because indexes in hesstrans start with 1
      set_int $intArrayW $j [expr [lindex $angleListW $i]+1]
      incr j
   }
   
   #puts "  Load Dihedrals"
   set dihedralListW [join $dihedlist ]
   #puts "  \$numDihedrals = $numDihedrals; expr \$numDihedrals * 4 = [expr $numDihedrals * 4]"
   for {set i 0} {$i < [expr $numDihedrals * 4]} {incr i} {
      # We have to increase the indices because indexes in hesstrans start with 1
      set_int $intArrayW $j [expr [lindex $dihedralListW $i]+1]
      incr j
   }
   
   #puts "  Load Impropers"
   set improperListW [join $imprplist]
   #puts "  \$numImpropers = $numImpropers; expr \$numImpropers * 4 = [expr $numImpropers * 4]"
   for {set i 0} {$i < [expr $numImpropers * 4]} {incr i} {
      # We have to increase the indices because indexes in hesstrans start with 1
      set_int $intArrayW $j [expr [lindex $improperListW $i]+1]
      incr j
   }


   set hessianInternal [new_double [expr $numInternals * $numInternals]]
   for {set i 0} {$i < [expr $numInternals * $numInternals]} {incr i} {
      set_double $hessianInternal $i 0
   }

   
   #puts "(\$numCartesians * 3) + ((\$numCartesians*3)*(\$numCartesians*3)) = [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]"
   #check_double $cartesianArrayW [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]
   #puts "(\$numBonds * 2) + (\$numAngles * 3) + (\$numDihedrals * 4) + (\$numImpropers * 4) = [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]"
   #check_int $intArrayW [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]

   #puts "  getInternalHessian"
   set ret [getInternalHessian $cartesianArrayW $intArrayW $hessianInternal $numCartesians $numBonds $numAngles $numDihedrals $numImpropers]

   set hessianint {}
   #puts "Hessian in internal coordinates:"
   for {set i 0} {$i < $numInternals} {incr i} {
      set row {}
      for {set j 0} {$j < $numInternals} {incr j} {
	 set index [expr ($i * $numInternals) + $j]
	 set val [get_double $hessianInternal $index]
	 #puts -nonewline $val
	 #puts -nonewline " "
	 lappend row $val
      }
      #puts " "
      lappend hessianint $row
   }

   delete_double $cartesianArrayW
   delete_int $intArrayW
   delete_double $hessianInternal

   puts "HessianTransform done."
   return $hessianint
}

proc diag2square { mat } {
   set ir 0
   set newmat {}
   foreach row $mat {
      set newrow $row
      # append the missing data
      set ic 0
      foreach row $mat {
	 if {$ic>$ir} {
	    lappend newrow [lindex $row $ir]
	 }
	 incr ic
      }
      lappend newmat $newrow
      incr ir
   }
   return $newmat
}