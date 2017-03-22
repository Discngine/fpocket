package require moltoptools
package provide idatm 0.1

namespace eval ::IDATM:: {

  namespace export runtyping read_idatm_types

  proc initialize {} {
    variable basesel ;# Overall selection being operated on
    variable havarray ;# heavy atom valences of atoms in the system
    variable elements ;# Element names of the atoms being considered
    variable types ;# types of the atoms
    variable bonds ;# bonds of the atoms
    variable idatmbonds ;# bonds of the atom using idatm indices
    variable bondorders ;# bond orders of the bonds
    variable indices ;# indices of the atoms
    variable fftypes ;# the force field types being used
    variable molid ;# the molecule being operated on
    variable mindouble ;# Minimum number of double bonds needed for each type
    array set fftypes {}
  }

proc default_types {} {
# Set up the force field type naming to be that
#   from Meng & Lewis (1991)

  variable fftypes
  variable coordcuts
  variable mindouble
  variable maxbonds
  array unset fftypes
  array unset coordcuts

  array set fftypes {
    C3 C3
    C2 C2
    C1 C1
    Cac Cac
    N3p N3p
    N3 N3
    Npl Npl
    N1 N1
    Nox Nox
    Ntr Ntr
    Ngp Ngp
    O3 O3
    O2 O2
    Om Om
    S3p S3p
    S3 S3
    S2 S2
    Sac Sac
    Sox Sox
    S S
    Bac Bac
    Box Box
    B B
    Pac Pac
    Pox Pox
    P3p P3p
    P P
    HC HC
    H H
    DC DC
    D D
  }

# Array with the minimum number of double bonds for each type
  array set mindouble {
    C3 0
    C2 1
    C1 2
    Cac 1
    N3p 0
    N3 0
    Npl 1
    N1 2
    Nox 1
    Ntr 2
    Ngp 1
    O3 0
    O2 1
    Om 1
    S3p 0
    S3 0
    S2 1
    Sac 2
    Sox 2
    S 0
    Bac 0
    Box 0
    B 0
    Pac 2
    Pox 2
    P3p 0
    P 0
    HC 0
    H 0
    DC 0
    D 0
    X 0
    V 1
  }

# Array with the maximum total bond order sum for each type
  array set maxbonds {
    C3 4
    C2 4
    C1 4
    Cac 4
    N3p 4
    N3 3
    Npl 3
    N1 3
    Nox 3
    Ntr 3
    Ngp 3
    O3 2
    O2 2
    Om 2
    S3p 4
    S3 2
    S2 2
    Sac 6
    Sox 6
    S 2
    Bac 4
    Box 4
    B 3
    Pac 6
    Pox 6
    P3p 4
    P 3
    HC 1
    H 1
    DC 1
    D 1
    X 4
    V 5
  }

  array set coordcuts {
    C1C1dist 1.22
    C2Cdist 1.41
    C2Ndist 1.37
    N1C1dist 1.20
    N3Cdist 1.38
    O2C2dist 1.30
    S2C2dist 1.76
    C2Crdist 1.42
    C3Crdist 1.53
    C2Nrdist 1.41
    C3Nrdist 1.46
    C3Ordist 1.44
    N2Crdist 1.38
    N2Nrdist 1.32
  }
}

  initialize
  default_types
}

proc ::IDATM::read_idatm_types {filename} {
  variable fftypes

  set ins [open $filename "r"]
  
  while {[gets $ins line] >= 0} {
    array set fftypes $line
  }

  close $ins
}

proc ::IDATM::runtyping {selection} {
#Run the full typing routine on a given selection

  variable basesel
  variable molid

  set basesel $selection
  set molid [$selection molid]

#Set up the needed namespace variables
  puts "IDATM: Performing initial setup"
  resettypes
  init_arrays
  reset_bondorders
  puts "IDATM: Done with setup"

#Run the typing routines themselves
  puts "IDATM: Running typing routines"
  ::IDATM::get_HAV
#  puts $::IDATM::havarray
  ::IDATM::do_maintype
#  puts $::IDATM::types
  ::IDATM::do_hav1
#  puts $::IDATM::types
  ::IDATM::check_redos
#  puts $::IDATM::types
  ::IDATM::check_isoc2
#  puts $::IDATM::types
  ::IDATM::check_chargestates
#  puts $::IDATM::types
# This ends the standard IDATM algorithm

# Set bond orders according to the types we've found
# This is *not* part of the old idatm procedure
  set ambigs 9998
  set lastambigs 9999
  while {$ambigs > 0 && $ambigs < $lastambigs} {
    set lastambigs $ambigs
    set ambigs [::IDATM::make_bonds 0]
#    puts "*** $lastambigs $ambigs ***"
  }
  ::IDATM::resolve_rings
  incr lastambigs
  while {$ambigs > 0 && $ambigs < $lastambigs} {
    set lastambigs $ambigs
    set ambigs [::IDATM::make_bonds 0]
#    puts "*** $lastambigs $ambigs ***"
  }
  ::IDATM::make_bonds 1

#Apply the typing and clean up
  #check_types
  apply_types
  #make_bonds

}

proc ::IDATM::resettypes {} {
  variable basesel
  $basesel set type X
}

proc ::IDATM::init_arrays {} {
  # Initialize some useful arrays that make life simpler later on
  variable basesel
  variable elements
  variable types
  variable bonds
  variable indices
  variable bondorders
  variable havarray
  variable reconsider
  variable idatmbonds

  set elements [$basesel get element]
  set types [$basesel get type]
  set bonds [$basesel getbonds]
  set bondorders [$basesel getbondorders]
  set indices [$basesel get index]

  # If we can't get a real element, guess from the name
  set names [$basesel get name]
  for {set i 0} {$i < [llength $elements]} {incr i} {
    set myelem [lindex $elements $i]
    set myname [lindex $names $i]
    if {$myelem == "X"} {
      puts "Warning: Guessing element for atom $myname from name"
      regexp {\d*([A-Za-z]+)\d*} $myname matchinfo newtype
      puts "Guessing type $newtype for atom $myname"
      lset elements $i $newtype
    }
  }

  set havarray [list]
  set reconsider [list]
  set idatmbonds [list]

  foreach i $indices {
    lappend havarray -1
    lappend reconsider 0

    set templist [list]
    foreach bond [lindex $bonds [lsearch $indices $i]] {
      set bi [lsearch $indices $bond]
      if {$bi >= 0} {lappend templist $bi}
    }
    lappend idatmbonds $templist
  }

}



proc ::IDATM::get_HAV {} {
  # Get the heavy atom valence (HAV) for all atoms being operated on
  # HAVs are stored in the array havarray, with -1 for unassigned values,
  # and -2 for successfully assigned atoms

  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider ;# Atoms marked to be looked at again in more detail

  for {set i 0} {$i < [llength $indices]} {incr i} {
#    puts "DEBUG: Running typing for atom $i/[lindex $indices $i]"

    set mybonds [lindex $bonds $i]

    # If it is a hydrogen, we can already fully type it
    if {[lindex $elements $i] == "H"} {
      if {[llength $mybonds] == 0} {
        lset types $i $fftypes(H)
        lset havarray $i -2
        continue
      }

      if {[llength $mybonds] > 1} {
        puts "Warning: Untypeable hydrogen atom"
        lset types $i $fftypes(unknown)
        lset havarray $i -2
        continue
      }

      set bondedatom [lindex $indices [lindex $mybonds 0]]
      set baelem [lindex $elements $bondedatom]
      if {$baelem == "C"} {
        lset types $i $fftypes(HC)
        lset havarray $i -2
        continue
      } else {
        lset types $i $fftypes(H)
        lset havarray $i -2
        continue
      }
    }

    # Otherwise, count the nonhydrogen atoms bonded to it
    set nonh 0
    foreach bondedatom $mybonds  {
      set elem [lindex $elements [lsearch -exact $indices $bondedatom]]
#      puts "DEBUG: Atom $bondedatom is a $elem"
      if {$elem != "H"} {incr nonh}
    }
    lset havarray $i $nonh

  }
}

proc ::IDATM::do_maintype {} {
# Run the main typing loop
# Loop through each atom and identify it based on element,
# HAV, bonds, and angles

  variable elements
  variable indices
  variable types

  for {set i 0} {$i < [llength $indices]} {incr i} {
    # Run the proper typing for the element

    switch [lindex $elements $i] {
      C {type_carbon $i}
      O {type_oxygen $i}
      N {type_nitrogen $i}
      S {type_sulfur $i}
      B {type_boron $i}
      P {type_phos $i}
      default {
        lset types $i [lindex $elements $i]
      }
    }
  }

}

proc ::IDATM::do_hav1 {} {
# Run the HAV=1 typing routines, which include bond lengths in our considerations
  #puts "Running do_hav1 subroutine"

  variable elements
  variable indices
  variable havarray

  for {set i 0} {$i < [llength $indices]} {incr i} {
    # Run some typing iff the HAV is 1
    set hav [lindex $havarray $i]
    if {$hav == 1} {
      switch [lindex $elements $i] {
      C {type_hav1_carbon $i}
      O {type_hav1_oxygen $i}
      N {type_hav1_nitrogen $i}
      S {type_hav1_sulfur $i}
     }
    }
  }

  #puts "done with do_hav1"
}


#EVERYTHING BELOW THIS POINT SHOULD GO IN THE ATOMPROCS FILE

proc ::IDATM::type_carbon {i} {
#Type the target carbon
# Note that the index we're passing around is the IDATM index, *not*
# the native VMD index

  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider

  # Type according to the HAV
  set myhav [lindex $havarray $i]
  set index [lindex $indices $i]

  if {$myhav == 4} {
    lset types $i $fftypes(C3)
    return 
  }

  # Otherwise, we need to make some geometry-based decisions
  set oxbounds [count_bound_ox $index]

  if {$myhav == 3 || $myhav == 2} {
    set hybtype [get_hybtype $i]
#  puts "Got hybtype $hybtype for index $index"
  }
  
  if {$myhav == 3} {
    switch $hybtype {
      3 {lset types $i $fftypes(C3)}
      2 {
          if {$oxbounds >= 2} {
            lset types $i $fftypes(Cac)
          } else {
            lset types $i $fftypes(C2)
          }
        }
      1 {lset types $i $fftypes(C1)}
    }
  }

  if {$myhav == 2} {
    switch $hybtype {
      3 {
          lset types $i $fftypes(C3)
          lset reconsider $i 1
        }
      2 {
            lset types $i $fftypes(C2)
            lset reconsider $i 3
        }
      1 {lset types $i $fftypes(C1)}
    }
  }

}

proc ::IDATM::type_oxygen {i} {
# Type an oxygen identified by IDATM index i
# as with other procs like this, we only do first round typing

  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider

  set myhav [lindex $havarray $i]
  if {$myhav == 2} {
    lset types $i $fftypes(O3)
  } 
}

proc ::IDATM::type_nitrogen {i} {
#Type the target nitrogen
# Note that the index we're passing around is the IDATM index, *not*
# the native VMD index

  #puts "Running type_nitrogen"

  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider


  # Type according to the HAV
  set myhav [lindex $havarray $i]
  set index [lindex $indices $i]
  if {$myhav >= 2} { set hybtype [get_hybtype $i] }
  set oxbounds [count_bound_ox $index]

  if {$myhav == 4} {
    if {$oxbounds >= 1} {
      lset types $i $fftypes(Nox)
    } else {
      lset types $i $fftypes(N3p)
    }
    return
  }

  # Otherwise, we need to make some geometry-based decisions

  if {$myhav == 3} {

    switch $hybtype {
      3 {lset types $i $fftypes(N3)}
      default {
          if {$oxbounds >= 2} {
            lset types $i $fftypes(Ntr)
          } else {
            lset types $i $fftypes(Npl)
          }
        }
    }
  }

  if {$myhav == 2} {
    switch $hybtype {
      3 {
          lset types $i $fftypes(N3)
          lset reconsider $i 2
        }
      2 {
          lset types $i $fftypes(Npl)
        }
      1 {
          lset types $i $fftypes(N1)
        }
      }
    }
}

proc ::IDATM::type_sulfur {i} {
# Type a sulfur identified by IDATM index i
# as with other procs like this, we only do first round typing

  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider

  set index [lindex $indices $i]
  set oxbounds [count_bound_ox $index]
  set myhav [lindex $havarray $i]

  if {$oxbounds == 4} {
    lset types $i $fftypes(Sac)
    return
  }

  if {$myhav == 2} {
    lset types $i $fftypes(S3)
  } elseif {$myhav == 3} {
    if {$oxbounds > 0} {
      lset types $i $fftypes(Sox) 
    } else {
      lset types $i $fftypes(S3p)
    }
  }
}

proc ::IDATM::type_boron {i} {
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider

  set index [lindex $indices $i]
  set oxbounds [count_bound_ox $index]
  set myhav [lindex $havarray $i]

  if {$oxbounds >= 3} {
    lset types $i $fftypes(Bac)
  } elseif {$oxbounds > 0} {
    lset types $i $fftypes(Box)
  } else {
    lset types $i $fftypes(B)
  }
}

proc ::IDATM::type_phos {i} {
# Type a phosphorus atom with IDATM index i
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider

  set index [lindex $indices $i]
  set oxbounds [count_bound_ox $index]
  set myhav [lindex $havarray $i]
  #puts "Phos: $oxbounds"

  if {$myhav == 4} {
    if {$oxbounds >= 2} {
      lset types $i $fftypes(Pac)
    } elseif {$oxbounds ==1} {
      lset types $i $fftypes(Pox)
    } else {
      lset types $i $fftypes(P3p)
    } 
  }
}
  

proc ::IDATM::get_hybtype {index} {
  # Check whether an atom with HAV >1 is sp3, sp2, or sp hybridized
  # Returns 3,2, or 1 accordingly. Return 0 if the type cannot be determined
  # Remember that the index we're passed is the IDATM index

  #puts "Running get_hybtype"

  variable havarray
  variable bonds
  variable indices
  variable reconsider
  variable elements

  set myindex [lindex $indices $index]
  set mybonds [lindex $bonds $index]
  set myhav [lindex $havarray $index]
  set myangles [list]

  #puts "Running on atom $index $myindex $myhav"

  if {$myhav < 2} {
    puts "Error: Can't run get_hybtype on an atom with HAV < 2.\n My HAV is $myhav!"
    return 0
  }
  # Calculate the average angle around the center
  #puts "mybonds: $mybonds"
  foreach batom1 $mybonds {
    foreach batom2 $mybonds {
      if {$batom1 < $batom2} {
        lappend myangles [measure_angle $batom1 $myindex $batom2]
      }
    }
  }

  # Assign the type according to the average angle
  #puts "Got angles $myangles for atom $index"
  set avgangle [expr "([join $myangles +]) / [llength $myangles]"]
  #puts "Avgangle: $avgangle"

  if {$myhav >= 3} {
    if {$avgangle > 115.0} {return 2} else {return 3}
  } elseif {$myhav == 2} {
    if {$avgangle < 115.0} {
      return 3
    } elseif {$avgangle < 160.0} {
      return 2
    } else {
      return 1
    }
  } else {
    return 0
  }
}

proc ::IDATM::measure_angle {ind1 ind2 ind3} {
# Measure the angle ind1-ind2-ind3
# ind1, ind2, ind3 are all *VMD* indices
  #puts "running measure_angle"

  variable molid

  set sel1 [atomselect $molid "index $ind1"]
  set sel2 [atomselect $molid "index $ind2"]
  set sel3 [atomselect $molid "index $ind3"]
  set coor1 [lindex [$sel1 get {x y z}] 0]
  set coor2 [lindex [$sel2 get {x y z}] 0]
  set coor3 [lindex [$sel3 get {x y z}] 0]
  $sel1 delete
  $sel2 delete 
  $sel3 delete

  set vec1 [vecsub $coor1 $coor2]
  set vec2 [vecsub $coor3 $coor2]
#puts "Vectors: $vec1 $vec2"
  if {[veclength $vec1] != 0} {
    set vec1 [vecnorm $vec1]
  }
  if {[veclength $vec2] != 0} {
    set vec2 [vecnorm $vec2]
  }

  set dotprod [vecdot $vec1 $vec2]
  set angle [expr acos($dotprod)]
  set angle [expr ($angle * 180/3.14159)]

  #puts "done with measure_angle"
  return $angle
}

proc ::IDATM::count_bound_ox {index} {
# Count the number of free oxygen atoms bound to the atom of interest
  variable molid
  variable indices
  variable havarray

  set nox 0

  set me [atomselect $molid "index $index"]
  set mybonds [lindex [$me getbonds] 0]
  foreach bondindex  $mybonds {
    set bondsel [atomselect $molid "index $bondindex"]
    #puts "[$bondsel get element]"
    if {[lindex [$bondsel get element] 0] == "O"} {
      set bi [lsearch $indices $bondindex]
      if {$bi >= 0} {
        if {[lindex $havarray $bi] == 1} {incr nox}
      }
    }
    $bondsel delete
  }
  $me delete

  return $nox
}

proc ::IDATM::type_hav1_carbon {i} {
# Type a carbon with HAV of 1, using the types of its neighbors and bond lengths
  #puts "running type_hav1_carbon"
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider
  variable molid
  variable coordcuts

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  
# Get the assigned types and bond distances to the heavy atom bonded to this one
  foreach bondedatom $mybonds {
    set bondedsel [atomselect $molid "index $bondedatom"]
    if {[lindex [$bondedsel get element] 0] != "H"} {
      set bondelem [lindex [$bondedsel get element] 0]
      set bonddist [measure_dist $bondedatom $myindex]
      set bi [lsearch $indices $bondedatom]
      if {$bi >= 0} {
        set bondtype [lindex $types $bi]
      } else {
        set bondtype "XXX"
      }
  }
  }

# Type according to the bond length and type of the other atom
  if {$bondelem == "C"} {
    if {$bondtype == $fftypes(C1) && $bonddist <= $coordcuts(C1C1dist)} {
      lset types $i $fftypes(C1)
      return
    } elseif {$bonddist <= $coordcuts(C2Cdist)} {
      lset types $i $fftypes(C2)
      return
    } else {
      lset types $i $fftypes(C3)
      return
    }
  }
  
  if {$bondelem == "N"} {
    if {$bonddist <= $coordcuts(C2Ndist)} {
      lset types $i $fftypes(C2)
      return
    }
  }

  lset types $i $fftypes(C3)
  return
}

proc ::IDATM::type_hav1_nitrogen {i} {
# Type a carbon with HAV of 1, using the types of its neighbors and bond lengths
  #puts "running type_hav1_nitrogen"
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider
  variable molid
  variable coordcuts

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  
# Get the assigned types and bond distances to the heavy atom bonded to this one
  foreach bondedatom $mybonds {
    set bondedsel [atomselect $molid "index $bondedatom"]
    if {[lindex [$bondedsel get element] 0] != "H"} {
      set bondelem [lindex [$bondedsel get element] 0]
      set bonddist [measure_dist $bondedatom $myindex]
      set bi [lsearch $indices $bondedatom]
      if {$bi >= 0} {
        set bondtype [lindex $types $bi]
      } else {
        set bondtype "XXX"
      }
  }
  }

# Type according to the bond length and type of the other atom
  if {$bondelem == "C"} {
    if {$bondtype == $fftypes(C1) && $bonddist <= $coordcuts(N1C1dist)} {
      lset types $i $fftypes(N1)
      return
    } elseif {$bonddist >= $coordcuts(N3Cdist)} {
      lset types $i $fftypes(N3)
      return
    } else {
      lset types $i $fftypes(Npl)
      return
    }
  }
  
  if {$bondelem == "N"} {
    if {$bondtype == $fftypes(N3) && $bonddist >= $coordcuts(N3N3dist)} {
      lset types $i $fftypes(N3)
      return
    } elseif {$bondtype == $fftypes(Npl) && $bonddist >= $coordcuts(N3N2dist)} {
      lset types $i $fftypes(N3)
      return
    } else {
      lset types $i $fftypes(Npl)
      return
    }
  }

  lset types $i $fftypes(Npl)
  return

}

proc ::IDATM::type_hav1_oxygen {i} {
  #puts "running type_hav1_oxygen"
# Type an oxygen with HAV of 1, using the types of its neighbors and bond lengths
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider
  variable molid
  variable coordcuts

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  
# Get the assigned types and bond distances to the heavy atom bonded to this one
  foreach bondedatom $mybonds {
    set bondedsel [atomselect $molid "index $bondedatom"]
    if {[lindex [$bondedsel get element] 0] != "H"} {
      set bondelem [lindex [$bondedsel get element] 0]
      set bonddist [measure_dist $bondedatom $myindex]
      set bi [lsearch $indices $bondedatom]
      if {$bi >= 0} {
        set bondtype [lindex $types $bi]
      } else {
        set bondtype "XXX"
      }
  }
  }

# Type according to the bond length and type of the other atom
  #puts "Typing oxygen. $bondtype $bondelem $bonddist $coordcuts(O2C2dist)"
  if {$bondtype == $fftypes(Cac) || $bondtype == $fftypes(Sac) || $bondtype == $fftypes(Pac) || $bondtype == $fftypes(Ntr)} {
    lset types $i $fftypes(Om)
    return
  } elseif {$bondtype == $fftypes(Sox) || $bondtype == $fftypes(Pox) || $bondtype == $fftypes(Nox)} {
    lset types $i $fftypes(O2)
    return
  } elseif {$bondelem == "C" && $bonddist <= $coordcuts(O2C2dist)} {
    lset types $i $fftypes(O2)
    if {$bi >= 0} {
      lset types $bi $fftypes(C2)
      lset reconsider $bi 0
    }
    return
  } else {
    lset types $i $fftypes(O3)
    return
  }
}

proc ::IDATM::type_hav1_sulfur {i} {
  #puts "running type_hav1_sulfur"
# Type an sulfur with HAV of 1, using the types of its neighbors and bond lengths
  variable types
  variable elements
  variable indices
  variable bonds
  variable havarray
  variable fftypes
  variable reconsider
  variable molid
  variable coordcuts

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  
# Get the assigned types and bond distances to the heavy atom bonded to this one
  foreach bondedatom $mybonds {
    set bondedsel [atomselect $molid "index $bondedatom"]
    if {[lindex [$bondedsel get element] 0] != "H"} {
      set bondelem [lindex [$bondedsel get element] 0]
      set bonddist [measure_dist $bondedatom $myindex]
      set bi [lsearch $indices $bondedatom]
      if {$bi >= 0} {
        set bondtype [lindex $types $bi]
      } else {
        set bondtype "XXX"
      }
  }
  }

# Type according to the bond length and type of the other atom
  if {$bondelem == "P"} {
    lset types $i $fftypes(S2)
    return
  }

  if {$bondelem == "C" && $bonddist <= $coordcuts(S2C2dist)} {
    lset types $i $fftypes(S2)
    if {$bi >= 0} {
      lset types $bi $fftypes(C2)
      lset reconsider $bi 0
    }
    return
  }

  lset types $i $fftypes(S3)
  return
}

proc ::IDATM::measure_dist {i1 i2} {
# Measure the distance between atoms with indices i1 and i2
  #puts "running measure_dist"
  variable molid
  set sel [atomselect $molid "index $i1 $i2"]
  set dist [veclength [vecsub [lindex [$sel get {x y z}] 1] [lindex [$sel get {x y z}] 0]]]
  return $dist
}

proc ::IDATM::check_redos {} {
# Retype atoms with a nonzero redo value based on the types of their neighbors
# As in the original idatm, 1 => tentative c3, 2 => tentative n3, 3 => tentative c2
  #puts "Running check_redos subroutine"

  variable elements
  variable indices
  variable havarray
  variable reconsider

  for {set i 0} {$i < [llength $indices]} {incr i} {
    # Run some typing iff the redo is nonzero
    set redo [lindex $reconsider $i]
    switch $redo {
      1 {redo_c $i}
      2 {redo_n3 $i}
      3 {redo_c $i}
    }
  }

  #puts "done with check_redos"
}

proc ::IDATM::redo_c {i} {
# Recheck an atom that was tentatively assigned as c3 or c2
  variable indices
  variable elements
  variable bonds
  variable coordcuts
  variable types
  variable fftypes

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  foreach bond $mybonds {
    set bi [lsearch $indices $bond]
    if {$bi < 0} {continue}
    set bondelem [lindex $elements $bi]
    set dist [measure_dist $myindex $bond]

    switch $bondelem {
      "C" {
            if {$dist < $coordcuts(C2Crdist)} {
              lset types $i $fftypes(C2)
            } elseif {$dist > $coordcuts(C3Crdist)} {
              lset types $i $fftypes(C3)
            }
          }
      "N" {
            if {$dist < $coordcuts(C2Nrdist)} {
              lset types $i $fftypes(C2)
            } elseif {$dist > $coordcuts(C3Nrdist)} {
              lset types $i $fftypes(C3)
            }
          }
      "O" {
            if {$dist > $coordcuts(C3Ordist)} {
              lset types $i $fftypes(C3)
            }
          }
    }

  }
}

proc ::IDATM::redo_n3 {i} {
# Recheck an atom that was tentatively assigned as n3
  variable indices
  variable elements
  variable bonds
  variable coordcuts
  variable types
  variable fftypes

  set myindex [lindex $indices $i]
  set mybonds [lindex $bonds $i]
  foreach bond $mybonds {
    set bi [lsearch $indices $bond]
    if {$bi < 0} {continue}
    set bondelem [lindex $elements $bi]
    set dist [measure_dist $myindex $bond]

    switch $bondelem {
      "C" {
            if {$dist < $coordcuts(N2Crdist)} {
              lset types $i $fftypes(Npl)
            } 
          }
      "N" {
            if {$dist < $coordcuts(N2Nrdist)} {
              lset types $i $fftypes(Npl)
            } 
      }

  }
}
}

proc ::IDATM::check_isoc2 {} {
# Check every c2 to make sure it has at least one non-sp3 neighbor
# if it doesn't, make it c3 instead
  #puts "Running check_isoc2 subroutine"

  variable elements
  variable indices
  variable havarray
  variable reconsider
  variable types
  variable fftypes
  variable idatmbonds

  set badtypes [list $fftypes(C3) $fftypes(HC) $fftypes(H) $fftypes(DC) $fftypes(D) $fftypes(N3) $fftypes(N3p) $fftypes(O3) $fftypes(Cac) $fftypes(Pac) $fftypes(Sac) $fftypes(Sox) $fftypes(C1) $fftypes(S3)]

# Retype as C3 unless we find a non-bad type in the bonds somewhere
  foreach index $indices {
  if {[lindex $types $index] != "C2"} {continue}
  set foundgood 0
  foreach neighbor [lindex $idatmbonds $index] {
    set ntype [lindex $types $neighbor]
    if {[lsearch $badtypes $ntype] < 0} {set foundgood 1 ; break}
  }
  if {$foundgood == 0} {lset types $index $fftypes(C3)}
  }
    

  #puts "done with check_redos"
}

proc ::IDATM::check_chargestates {} {
# Check for charge states of nitrogen, and carboxylates
# This corresponds to the sixth pass of idatm.f, with some tweaks
  #puts "Running check_chargestates"

  variable elements
  variable indices
  variable idatmbonds
  variable types
  variable fftypes
  variable havarray

  set safeforn [list $fftypes(C3) $fftypes(HC) $fftypes(H) $fftypes(DC) $fftypes(D)]
  set badforguan [list $fftypes(C2) $fftypes(Npl)]

  foreach index $indices elem $elements type $types {
    switch $type {
      N3 {
           # See if we should make it charged
           set found 0
           foreach neighbor [lindex $idatmbonds $index] {
             set ntype [lindex $types $neighbor]
             if {[lsearch $safeforn $ntype] < 0} {set found 1; break}
           }
           if {$found == 0} {lset types $index $fftypes(N3p)}
         }
      C2 {
          # Make it a guanidinium group if appropriate
          set nnpl 0
          foreach neighbor [lindex $idatmbonds $index] {
            if {[lindex $types $neighbor] == $fftypes(Npl)} {
              incr nnpl
            }
          }

          # If we have a c2 with 3 neighboring N3s, assume guanidinium, but check
          if {$nnpl != 3} {continue}

          set foundbad 0
          foreach neighbor [lindex $idatmbonds $index] {
            if {[lindex $types $neighbor] == $fftypes(Npl)} {
              lset types $neighbor $fftypes(Ngp)
            }

            foreach nneighbor [lindex $idatmbonds $neighbor] {
              if {[lsearch $badforguan [lindex $types $nneighbor]] >= 0 && $nneighbor != [lsearch $indices $index]} {
                  set foundbad 1
                  break
              }
            }
          }

          # If we found something that rules out guanidinium, change them back
          if {$foundbad == 0} {continue}
          foreach neighbor [lindex $idatmbonds $index] {
            if {[lindex $types $neighbor] == $fftypes(Ngp)} {
              lset types $neighbor $fftypes(Npl)
            }
          }

      }
      Cac {
            # Retype neighboring oxygens if called for
            foreach neighbor [lindex $idatmbonds $index] {
              if {[lindex $elements $neighbor] == "O" && [lindex $havarray $neighbor] == 1} {
                lset types $neighbor $fftypes(Om)
              }
            }
      }
    }
  }

#  puts "Finished check_chargestates"
}


proc ::IDATM::make_bonds {make_ambiguous} {
# Use the typing that has been assigned to assign bonds
# Use the mindouble and maxdouble arrays to help with bond placement
# If make_ambiguous is 0, we don't touch atoms which have multiple choices
# Return the number of ambiguous atoms found

  #puts "Entering make_bonds"

  variable elements
  variable indices
  variable idatmbonds
  variable types
  variable fftypes
  variable molid
  variable mindouble
  variable havarray
  variable maxbonds
  variable bondorders
  set ambigcount 0

# Make an array with an atom selection for each atom
  set atomsels [list]
  foreach index $indices {
    set mysel [atomselect $molid "index $index"]
    lappend atomsels $mysel
  }

# Now, go in ascending order of heavy atom valence and assign multiple bonds
  foreach hav [lsort -unique $havarray] {
    #puts "DEBUG: on hav=$hav"

# Look at each atom with the current heavy atom valence
    set me -1
  foreach myhav $havarray sel $atomsels mytype $types bonds $idatmbonds {
    set type [revfflookup $mytype]
#    puts "Typing: $type $mytype"
    incr me
    if {$myhav != $hav} {continue}

    #puts "DEBUG:                     Considering atom $me"

    set myorders [lindex [$sel getbondorders] 0]
    if {[llength $myorders] == 0} {continue}
    #puts "DEBUG: $myorders"
    set diff [expr "$mindouble($type) - [countdoub $myorders]"]
    set myavail [expr "$maxbonds($type) - [countbonds $myorders]"]
    if {$myavail <= 0 || $diff <= 0} {continue}
    
    #puts $myorders

    # If we're not doing ambiguous assignments, see if we should skip this atom
    if {$make_ambiguous != 1} {
      set numchoices 0
      set mychoices [list]
      foreach neighbor $bonds {
        set nsel [lindex $atomsels $neighbor]
        set nbonds [lindex $idatmbonds $neighbor]
        set norders [lindex [$nsel getbondorders] 0]
        #puts "norders: $norders"
        set avail [expr "$mindouble([revfflookup [lindex $types $neighbor]]) - [countdoub [lindex [$nsel getbondorders] 0]]"]
        set bavail [expr "$maxbonds([revfflookup [lindex $types $neighbor]]) - [countbonds [lindex [$nsel getbondorders] 0]]"]
        if {$avail > 0 && $bavail > 0} {
          incr numchoices
          lappend mychoices $neighbor
        }
      }
       
#      puts "For atom $me, have $numchoices choices: $mychoices"

      if {$numchoices > 1} {
        incr ambigcount
        continue
      }
    }


    if {$diff == 1.0} {
      # Look for a good candidate to form a double bond
      set nnum 0
      foreach neighbor $bonds {
#        puts "looking at neighbor $neighbor of atom $me"
        set nsel [lindex $atomsels $neighbor]
        set nbonds [lindex $idatmbonds $neighbor]
        set norders [lindex [$nsel getbondorders] 0]
        #puts "norders: $norders"
        set avail [expr "$mindouble([revfflookup [lindex $types $neighbor]]) - [countdoub [lindex [$nsel getbondorders] 0]]"]
        set bavail [expr "$maxbonds([revfflookup [lindex $types $neighbor]]) - [countbonds [lindex [$nsel getbondorders] 0]]"]
        if {$avail > 0 && $bavail > 0} {
#          puts "DEBUG: forming a double bond"
          # Form a double bond
          set target [lsearch $bonds $neighbor]
          set myorders [lreplace $myorders $target $target 2.0]
          set target [lsearch $nbonds $me]
          #puts "$nbonds | $me"
          #puts "target: $target"
          set norders [lreplace $norders $target $target 2.0]
          [lindex $atomsels $me] setbondorders [list $myorders]
          [lindex $atomsels $neighbor] setbondorders [list $norders]
          set bondorders [lreplace $bondorders $neighbor $neighbor $norders]
          set bondorders [lreplace $bondorders $me $me $myorders]
#          puts "formed a double bond between [lindex $indices $me] and [lindex $indices $neighbor]"
          set diff 0
          break
        }
      }
    }

    if {$diff >= 2.0} {
      # Look for either a triple or double bond candidate
      set nnum 0
      foreach neighbor $bonds {
        set nsel [lindex $atomsels $neighbor]
        set nbonds [lindex $idatmbonds $neighbor]
        set norders [[lindex $atomsels $neighbor] getbonds]
        set avail [expr "$mindouble([revfflookup [lindex $types $neighbor]]) - [countdoub [lindex [$nsel getbondorders] 0]]"]
        set bavail [expr "$maxbonds([revfflookup [lindex $types $neighbor]]) - [countbond [lindex [$nsel getbondorders] 0]]"]
        if {$avail > 1 && $diff > 1 && $bavail > 0} {
          # Form a triple bond
          set target [lsearch $bonds $neighbor]
          set myorders [lreplace $myorders $target $target 3.0]
          set target [lsearch $nbonds $me]
          set norders [lreplace $norders $target $target 3.0]
          [lindex $atomsels $me] setbondorders $myorders
          [lindex $atomsels $neighbor] setbondorders $norders
          set bondorders [lreplace $bondorders $neighbor $neighbor $norders]
          set bondorders [lreplace $bondorders $me $me $myorders]
          set diff [expr $diff - 2]
          if {$diff <= 0} {break}
        } elseif {$avail == 1 && $bavail > 0} {
          # Form a double bond
          set target [lsearch $bonds $neighbor]
          set myorders [lreplace $myorders $target $target 2.0]
          set target [lsearch $nbonds $me]
          set norders [lreplace $norders $target $target 2.0]
          [lindex $atomsels $me] setbondorders [list $myorders]
          [lindex $atomsels $neighbor] setbondorders [list $norders]
          set bondorders [lreplace $bondorders $neighbor $neighbor $norders]
          set bondorders [lreplace $bondorders $me $me $myorders]
          set diff 0
          break
        }

      }
    }



  }

  }

  foreach sel $atomsels {
    $sel delete
  }

  return $ambigcount
}

proc ::IDATM::countdoub {bonds} {
# Count the number of multiple bonds an atom has formed
  #puts "mybonds: $mybonds | [llength $mybonds]"
  #set bonds [lindex $mybonds 0]
  #set bonds $mybonds
 # puts "bonds: $bonds | [llength $bonds]"
  set nbonds [llength $bonds]
  set total [expr "[join $bonds +]"]
  set diff [expr $total - $nbonds]
 # puts "result: $nbonds | $total | $diff"
  return $diff
}
    
proc ::IDATM::countbonds {bonds} {
# Count the number of bonds to an atom
  set total [expr "[join $bonds +]"]
  return $total
}



proc ::IDATM::reset_bondorders {} {
  variable indices
  variable molid

  foreach index $indices {
    set mysel [atomselect $molid "index $index"]
    set neworders [list]
    foreach bond [lindex [$mysel getbonds] 0] {
      lappend neworders 1.0
    }
    $mysel setbondorders [list $neworders]
    $mysel delete
  }
}
  
proc ::IDATM::resolve_rings {} {
# Form a proper resonance structure in all aromatic rings in the molecule
# We use a moltoptools helper function to find the rings
  variable indices
  variable molid
  variable types
  variable idatmbonds
  variable bondorders
  variable fftypes
  variable elements

  set ringlist [::moltoptools::find_rings $molid]
  set myrings [list]

# List of types allowed in an aromatic ring
  set artypes [list $fftypes(C2) $fftypes(Npl)]

# Loop over ring candidates; discard if they are not 6 atom aromatics in our base selection
#  puts "DEBUG: Ringlist -- $ringlist"
  foreach ring $ringlist {
    if {[llength $ring] != 6} {continue}
    set goodring 1
    set thisring [list]
    foreach index $ring {
      set idatmind [lsearch $indices $index]
      if {$idatmind == -1} {set goodring 0; break}
      if {[lsearch $artypes [lindex $types $idatmind]] == -1} {set goodring 0; break}
      lappend thisring $idatmind
    }

    if {$goodring == 0} {continue}
    lappend myrings $thisring
  }

#  puts "DEBUG: Myrings -- $myrings"
  foreach ring $myrings {
#      puts "DEBUG: Working on ring $ring"
    set ndoub 0
    set doubpos {0 0 0 0 0 0} ;# 1 means a double bond between atoms i and i+1
    set available [list]

# Since we have an aromatic ring, now see how many double bonds are already present
    lappend ring [lindex $ring 0]
    for {set i 0} {$i < 6} {incr i} {
      set me [lindex $ring $i]
      set him [lindex $ring [expr "$i + 1"]]
      set mybond [lindex $idatmbonds $me]
      set myord [lindex $bondorders $me]
      set bo [lindex $myord [lsearch $mybond $him]]
      set myelem [lindex $elements $me]
      if {$bo == 2.0} {set doubpos [lreplace $doubpos $i $i 1]}

      # Check to see if there is space for one more bond here
      set mybondtot [vecsum $myord]
#      puts "DEBUG: $i $myelem $mybondtot"
      if {$myelem == "C"} {
        if {$mybondtot < 4} {lappend available 1} else {lappend available 0}
      } elseif {$myelem == "N"} {
        if {$mybondtot < 3} {lappend available 1} else {lappend available 0}
      }

    }

# Form one of the two possible staggered sets of bonds

#    puts "DEBUG: Finding good bonds with doubpos $doubpos and avail $available"

    #First, check to see if one of the sets is already started
    set stag1 [expr "[lindex $doubpos 0] || [lindex $doubpos 2] || [lindex $doubpos 4]"]
    set stag2 [expr "[lindex $doubpos 1] || [lindex $doubpos 3] || [lindex $doubpos 5]"]

    if {$stag1 && !$stag2} {
      #Form the appropriate double bonds
      if {[lindex $available 0] == 1 && [lindex $available 1] == 1} {
        makedoub [lindex $ring 0] [lindex $ring 1]
      }
      if {[lindex $available 2] == 1 && [lindex $available 3] == 1} {
        makedoub [lindex $ring 2] [lindex $ring 3]
      }
      if {[lindex $available 4] == 1 && [lindex $available 5] == 1} {
        makedoub [lindex $ring 4] [lindex $ring 5]
      }
      continue 
    }

    if {!$stag1 && $stag2} {
      #Form the appropriate double bonds
      if {[lindex $available 1] == 1 && [lindex $available 2] == 1} {
        makedoub [lindex $ring 1] [lindex $ring 2]
      }
      if {[lindex $available 3] == 1 && [lindex $available 4] == 1} {
        makedoub [lindex $ring 3] [lindex $ring 4]
      }
      if {[lindex $available 5] == 1 && [lindex $available 0] == 1} {
        makedoub [lindex $ring 5] [lindex $ring 0]
      }
      continue

    }

# TODO: More sophisticated guessing can go here

    # If we've gotten to this point, arbitrarily choose one of the two possibilities
    if {[lindex $available 0] == 1 && [lindex $available 1] == 1} {
      makedoub [lindex $ring 0] [lindex $ring 1]
    }
    if {[lindex $available 2] == 1 && [lindex $available 3] == 1} {
      makedoub [lindex $ring 2] [lindex $ring 3]
    }
    if {[lindex $available 4] == 1 && [lindex $available 5] == 1} {
      makedoub [lindex $ring 4] [lindex $ring 5]
    }
  }
}

proc ::IDATM::makedoub {ind1 ind2} {
# Given two idatm indices, form a double bond between them
  variable molid
  variable indices
  variable idatmbonds
  variable bondorders

  set globind1 [lindex $indices $ind1]
  set globind2 [lindex $indices $ind2]
  set bonds1 [lindex $idatmbonds $ind1]
  set bonds2 [lindex $idatmbonds $ind2]
  set bo1 [lindex $bondorders $ind1]
  set bo2 [lindex $bondorders $ind2] 
  set partner1 [lsearch $bonds1 $ind2]
  set partner2 [lsearch $bonds2 $ind1]
  set sel1 [atomselect $molid "index $globind1"]
  set sel2 [atomselect $molid "index $globind2"]

  set bo1 [lreplace $bo1 $partner1 $partner1 2.0]
  set bo2 [lreplace $bo2 $partner2 $partner2 2.0]

  set bondorders [lreplace $bondorders $ind1 $ind1 $bo1]
  set bondorders [lreplace $bondorders $ind2 $ind2 $bo2]

  $sel1 setbondorders [list $bo1]
  $sel2 setbondorders [list $bo2]

  $sel1 delete
  $sel2 delete
}

proc ::IDATM::apply_types {} {
# Apply the types held in IDATM's array to the molecule
  variable basesel
  variable types

  $basesel set type $types
}

proc ::IDATM::revfflookup {elem} {
# Find the first key corresponding to elem in the fftypes array
  variable fftypes

#  puts "looking for $elem"

  foreach key [array names fftypes] {
    set myelem [lindex [array get fftypes $key] 1]
#    puts "$myelem $elem $key"
    if {$myelem == $elem} {return $key}
  }

  return "X"
}






