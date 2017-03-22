proc ::Molefacture::measure_angle {coor1 coor2 coor3} {
  #Nondestructively measures the angle a1-a2-a3
  #puts "$coor1 $coor2 $coor3"

  set vec1 [vecsub $coor1 $coor2]
  set vec2 [vecsub $coor3 $coor2]
#puts "Vectors: $vec1 $vec2"
  if {[veclength $vec1] != 0} {
    set vec1 [vecnorm $vec1]
  }
  if {[veclength $vec2] != 0} {
    set vec2 [vecnorm $vec2]
  }

#  puts "here"
  set dotprod [vecdot $vec1 $vec2]
#  puts "$dotprod"
  set angle [expr acos($dotprod)]
#  puts "$angle"
  set angle [expr ($angle * 180/3.14159)]
#  puts "Final: $angle"
  return $angle
}

###########################################################
# Returns a list of bonded atom pairs.                    #
###########################################################

 proc ::Molefacture::bondlist {} {
    variable tmpmolid
    variable bondlistformat
    set sel [atomselect $tmpmolid "occupancy >= 0.5"]
    set bondsperatom  [$sel getbonds]
    set ordersperatom [$sel getbondorders]
    set indices [$sel get index]

    set bonds [list]
#  puts "Bonds: $bondsperatom"

    foreach bpa $bondsperatom opa $ordersperatom atom1 $indices {
       foreach partner $bpa order $opa {
#         puts "Partner: $partner"
	      set indexes [lsort -integer [list $atom1 $partner]]
#    puts "Working bonds: $bonds"
	      lappend bonds [format "$bondlistformat" [lindex $indexes 0] [lindex $indexes 1] [expr abs($order)]]
       }

    }

#    puts $bonds
    $sel delete
    return [lsort -dictionary -unique $bonds]
 }

###########################################################
# Returns a list of triples that form angles
###########################################################

 proc ::Molefacture::anglelist {} {
    variable tmpmolid
    variable anglelistformat
    set sel [atomselect $tmpmolid "occupancy >= 0.5"]
    set bondsperatom  [$sel getbonds]
    set atom1arr [$sel get index]

    set atom1 0
    set angles {}
    foreach bonds $bondsperatom atom1 $atom1arr {
       set atom1sel [atomselect $tmpmolid "index $atom1"]
       set atom1coor [lindex [$atom1sel get {x y z}] 0]
       $atom1sel delete
       foreach partner1 $bonds {
       foreach partner2 $bonds {
         if {$partner1 < $partner2} {
	   set psel1 [atomselect $tmpmolid "index $partner1"]
	   set psel2 [atomselect $tmpmolid "index $partner2"]
	   set thisangle [measure_angle [lindex [$psel1 get {x y z}] 0] $atom1coor [lindex [$psel2 get {x y z}] 0]]
#	Use this version if we want to display the angle in the menu:
#	   lappend angles [format "$anglelistformat" $partner1 $atom1 $partner2  $thisangle]
	   lappend angles [format "$anglelistformat" $partner1 $atom1 $partner2]
	   $psel1 delete
	   $psel2 delete
       	}
       }
       }
    }

    #return [lsort -dictionary -unique $bonds]
    return $angles
 }

##############################################################
# If bond does not yet exist in vmd's bond list then add it. #
##############################################################

proc ::Molefacture::vmd_addbond {atom0 atom1 {order -1}} {

  variable tmpmolid
   set sel [atomselect $tmpmolid all]
   set bondlist   [$sel getbonds]
   set bondorders [$sel getbondorders]
   set bondatom0  [lindex $bondlist   $atom0]
   set bondorder0 [lindex $bondorders $atom0]
   set ind1 [lsearch $bondatom0 $atom1]
   if {$ind1<0} {
      set newlist  [join [join [list $bondatom0  $atom1]]]
      set neworder [join [join [list $bondorder0 $order]]]
      #puts "newlist1: $newlist"
      lset bondlist   $atom0 $newlist
      lset bondorders $atom0 $neworder
   }

   set bondatom1  [lindex $bondlist   $atom1]
   set bondorder1 [lindex $bondorders $atom1]
   set ind2 [lsearch $bondatom1 $atom0]
   if {$ind2<0} {
      set newlist  [join [join [list $bondatom1  $atom0]]]
      set neworder [join [join [list $bondorder1 $order]]]
      #puts "newlist2: $newlist"
      lset bondlist   $atom1 $newlist
      lset bondorders $atom1 $neworder
   }

   if {$ind1>=0 && $ind2>=0} { return 1 }
   $sel setbonds      $bondlist
#   puts "$atom0 | $atom1 | $bondorders"
   $sel setbondorders $bondorders
   return 0
}

proc ::Molefacture::vmd_delbond {atom0 atom1} {
   #GOTCHA WARNING: This only deletes the atom0-atom1 bond, NOT the atom1-atom0
   #bond. This is not a bug but a feature, useful in deleting atoms.
   variable tmpmolid 

   set sel [atomselect $tmpmolid all]
   set bondlist   [$sel getbonds]
   set bondorders [$sel getbondorders]
   set bondatom0  [lindex $bondlist   $atom0]
   set bondorder0 [lindex $bondorders $atom0]
   set ind1 [lsearch $bondatom0 $atom1]
   #puts "Deleting: $atom0 $atom1"
   #puts "Old: $bondatom0"
   if {$ind1>-1} {
      set newlist  [join [join [lreplace $bondatom0  $ind1 $ind1]]]
      set neworder [join [join [lreplace $bondorder0 $ind1 $ind1]]]
      #puts "New: $newlist"
      lset bondlist   $atom0 $newlist
      lset bondorders $atom0 $neworder
  }

  set bondatom1 [lindex $bondlist $atom1]
#  set ind2 [lsearch $bondatom1 $atom0]
#puts "Old: $bondatom1"
#  if {$ind2>-1} {
#    set newlist [join [join [lreplace $bondatom1 $ind2 $ind2]]]
#puts "New: $newlist"
#    lset bondlist $atom1 $newlist
#  }

   $sel setbonds      $bondlist
   $sel setbondorders $bondorders
   update_bondlist
   update_openvalence
  return 0
}



proc ::Molefacture::get_element {name resname mass} {
  #Returns the atomic symbol for the element it is called on
  #Tries to use topology file and then mass for this determination
  variable toplist
  variable periodic

  set restopindex [lsearch [::Toporead::topology_get names $toplist] $resname]
  if {$restopindex != -1} {
    set resatomlist [join [lindex [::Toporead::topology_get residues $toplist] $restopindex 3]] ;# This is one list with the atom/type/charge info
    set type [get_atom_type $name $resatomlist]
    if {$type != -1} {
    set element [get_element_type $type [::Toporead::topology_get types $toplist]]
    if {$element != -1} {return $element}
  }
  }
  #If this has failed, try to assign by name
#  puts $name
  regexp {([A-Z|a-z]+)\d*} $name -> namehead
#puts $namehead
  set namehead [string toupper $namehead]
  if {[lsearch $periodic $namehead] >= 0} {
    return $namehead
  }
  #Else, try assignment based on mass
  #WARNING: This is bogus for anything beyond the common organic stuff
  if {$mass != 0} {
    return [lindex $periodic [expr int($mass/2.0+0.5)]]
  }
  return "X"
}

proc ::Molefacture::get_atom_type {name atoms} {
  #This function takes a nested list of atoms, with each atom defined by a 
  #list of form {name type charge}, and returns the type of the atom with
  #name $name
  foreach atom $atoms {
    if {[lindex $atom 0] == $name} {return [lindex $atom 1]}
  }
  return -1
}

proc ::Molefacture::get_element_type {type types} {
  #Returns the element name of the type $type

  foreach atom $types {
#puts $atom
    if {[lindex $atom 0] == $type} {return [lindex $atom 2]}
  }

  return -1
}

proc ::Molefacture::new_mol {} {
  # Create a new molecule with some dummy hydrogens, and transition molefacture
  # to work on it

  variable availablehyd
  variable protlasthyd
  variable tmpmolid

  set oldmolid $tmpmolid

  set protlasthyd -1

  set repository [list 0 0 0]
  set x [lindex $repository 0]
  set y [lindex $repository 1]
  set z [lindex $repository 2]

   set ofile [open Molefacture_newmol.xbgf "w"]

  #Set up characteristics of dummy atoms
  set hind 1
  set resid 9999

  # Write hydrogens to xbgf file
  puts $ofile "BIOGRF 332"
  puts $ofile "REMARK NATOM 100"
  puts $ofile "FORCEFIELD DREIDING"
  puts $ofile "FORMAT ATOM   (a6,1x,i6,1x,a5,1x,a4,1x,a1,1x,i5,3f10.5,1x,a5,i3,i2,1x,f8.5,1x,f6.3,1x,f6.3,1x,i3,1x,a4)"
   for {set index [expr 1]} {$index<=100} {incr index} {
      set name "HM$hind"
      puts $ofile [format "ATOM   %6i %5s  UNK X %5i%10.5f%10.5f%10.5f %-5s%3i%2i %8.5f %6.3f %6.3f %3i %4s" $index $name $resid $x $y $z "XXH" 0 0 0.00000 0.000 0.000 1 "MOLF"]
      incr hind
   }

   puts $ofile "FORMAT CONECT (a6,14i6)"
   puts $ofile "FORMAT ORDER (a6,i6,13f6.3)"
   puts $ofile "END"
   close $ofile
  
   # Load the file including the dummy atom repository
   set tmpmolid [mol new "Molefacture_newmol.xbgf"]
   set availablehyd 100

   # Undraw all other molecules in VMD:
   foreach m [molinfo list] {
      if {$m==$tmpmolid} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   mol selection      "occupancy > 0.4"
   mol representation "Bonds 0.1"
   mol color          Name
   mol modrep 0 top
   mol representation "VDW 0.1"
   mol addrep top
   display resetview

   #mol delete $oldmolid

   variable bondlist
   variable anglelist
   variable atomlist

   set atomlist [list]
   set bondlist [bondlist]
   set anglelist [anglelist]

   variable oxidation
   set oxidation [list]
   for {set i 0} {$i < 100} {incr i} {
     lappend oxidation 0
   }
}

###################################################
# Reload the selection as a temporary molecule    #
# with a bunch of dummy atoms to add them to the  #
# actual molecule. Dummies have occupancy 0 while #
# all other atoms have occupancy 1.               #
###################################################

proc ::Molefacture::reload_selection {} {
   variable availablehyd
   variable origsel
   set tmptmpfile Moltmp.xbgf
   set tmpfile Molefacture_tmpmol.xbgf

   # Write the selection as XBGF to which the dummy atoms will be appended
   $origsel set occupancy 1.0
   write_xbgf $tmptmpfile $origsel

   # Determine location of the atom repository
   set resid 9999
   set mincoord [lindex [measure minmax $origsel] 0]
   set repository [vecadd $mincoord {-5 -5 -5}]
   set x [lindex $repository 0]
   set y [lindex $repository 1]
   set z [lindex $repository 2]
   set maxind [lindex [lsort -integer [$origsel list]] end]

   # Find highest index in any existing repository hydrogen names
   set hind 1
   foreach name [$origsel get name] {
      if {[string match "HM*" $name]} {
	 set ind [string range $name 1 end] 
	 if {[string is integer $ind]} { 
	    if {$ind>$hind} { set hind $ind }
	 }
      }
   }

   # Add dummy atoms to xbgf file
   set fid [open $tmptmpfile r]
   set ofile [open $tmpfile "w"]

   # Find the end of the atom section
   set maxind 0
   set line [gets $fid]
   while {[regexp {CONECT} $line]==0} {
     if {[regexp {^ATOM} $line]} {incr maxind}
     puts $ofile $line
     set line [gets $fid]
   }

   for {set index [expr $maxind+1]} {$index<=[expr $maxind+100]} {incr index} {
      set name "HM$hind"
      puts $ofile [format "ATOM   %6i %5s  UNK X %5i%10.5f%10.5f%10.5f %-5s%3i%2i %8.5f %6.3f %6.3f %3i %4s" $index $name $resid $x $y $z "XXH" 0 0 0.00000 0.000 0.000 1 "MOLF"]
      incr hind
   }

   set availablehyd 100

   while {![eof $fid]} {
     puts $ofile $line
     set line [gets $fid]
   }

   close $fid
   close $ofile
   if {[file exists $tmptmpfile]} { file delete $tmptmpfile }

   # Load the file including the dummy atom repository
   variable tmpmolid [mol new $tmpfile]

   # Undraw all other molecules in VMD:
   foreach m [molinfo list] {
      if {$m==$tmpmolid} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   set sel [atomselect $tmpmolid "occupancy 1.0"]
   if {[lindex [$sel get atomicnumber] 0] == -1} {assign_elements}
   $sel delete
}


proc ::Molefacture::export_molecule {filename} {
   variable tmpmolid
   set sel [atomselect $tmpmolid "occupancy>=0.8"]
   write_xbgf $filename $sel
   $sel delete
}

####################################################
# Writes a selection into a xbgf file and appends  #
# VDW parameters as REMARKs.                       #
####################################################

proc ::Molefacture::write_xbgf {xbgffile sel} {
   $sel writexbgf $xbgffile

   # Find the END tag
   set fid [open $xbgffile r+]
   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [gets $fid]
      if {[lindex $line 0]=="END"} { break }
   }
   seek $fid $filepos

   set VDWdata {}
   foreach remark [molinfo [$sel molid] get remarks] {
      if {[lindex $remark 0]=="VDW"} {
	 lappend VDWdata [lrange $remark 1 end]
      }
   }
   set i 1
   foreach index [$sel list] {
      #puts      [format "VDW %6i %s" $i [lindex $VDWdata $index]]
      puts $fid [format "VDW %6i %s" $i [lindex $VDWdata $index]]
      incr i
   }
   variable chargelist
   set i 1
   foreach index [$sel list] {
      #puts      [format "LEWIS %6i %3s" $i [lindex $chargelist $index]]
      puts $fid [format "LEWIS %6i %3s" $i [lindex $chargelist $index]]
      incr i
   }
   puts $fid "END"

   close $fid
}

proc ::Molefacture::set_pickmode_atomedit {} {
   global vmd_pick_atom
   variable pickmode "atomedit"

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::Molefacture::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 0
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::Molefacture::atom_picked_fctn
   #puts "[trace info variable vmd_pick_atom]"
   puts "Set pickmode atomedit"
   draw_selatoms
}



############################################################
### This function is invoked whenever an atom is picked. ###
############################################################

proc ::Molefacture::atom_picked_fctn { args } {
  global vmd_pick_atom
  global vmd_pick_shift_state
  variable picklist
  variable pickmode
  variable tmpmolid
  variable bondlist

  # Delete old dihedral tags
  variable dihedmarktags
  foreach tag $dihedmarktags {
	  graphics $tmpmolid delete $tag
  }

  #puts "pickmode=$pickmode; picked atom $vmd_pick_atom; $picklist"
  lappend picklist $vmd_pick_atom
  set sel [atomselect $tmpmolid "index $vmd_pick_atom"]

  if {$pickmode=="bond"} {
    variable labelradius
    graphics $tmpmolid color yellow
    graphics $tmpmolid sphere [join [$sel get {x y z}]] radius [expr 1.21*$labelradius]

    if {[llength $picklist]==2} {
      set i 0
  #    puts "DEBUG: We have 2 picks, so checking for a bond..."
      foreach bond $bondlist {
  #      puts "DEBUG: $bond $picklist"
        if {([lindex $bond 0] == [lindex $picklist 0] && [lindex $bond 1] == [lindex $picklist 1]) || ([lindex $bond 0] == [lindex $picklist 1] && [lindex $bond 1] == [lindex $picklist 0])} {
  #        puts "DEBUG: Got a match!"
          hilight_bond [lindex $picklist 0] [lindex $picklist 1] $i
          break
        }
        incr i
    } 
    label delete Atoms all
  }

 } elseif {$pickmode=="atomedit"} {
  # puts "Selected atom $vmd_pick_atom"
   if {!$vmd_pick_shift_state} { 
     set picklist $vmd_pick_atom 
     label delete Atoms all
    }

    #      set i [lsearch $atomlist "[format "%5s" $index] *"]
    set newpicklist [list]
    #      puts "1"
    set allatomlist [.molefac.val.list.list get 0 end]
    foreach atomind $picklist {
      #        puts "DEBUG: ATOMIND: $atomind"
      set newind [::Molefacture::search_atomlist $allatomlist $atomind]
      #        puts "DEBUG: NEWIND: $newind"
      #        puts $newind
      lappend newpicklist $newind
    }
    #      puts "2"
    #      puts "$picklist | $newpicklist"

    select_atoms $newpicklist
  #  puts "DEBUG: Picklist $picklist"
    if {[llength $picklist]==2} {
      set i 0
  #    puts "DEBUG: We have 2 picks, so checking for a bond..."
      foreach bond $bondlist {
  #      puts "DEBUG: $bond $picklist"
        if {([lindex $bond 0] == [lindex $picklist 0] && [lindex $bond 1] == [lindex $picklist 1]) || ([lindex $bond 0] == [lindex $picklist 1] && [lindex $bond 1] == [lindex $picklist 0])} {
  #        puts "DEBUG: Got a match!"
          hilight_bond [lindex $picklist 0] [lindex $picklist 1] $i
          break
        }
        incr i
    } 
    #      if {[llength $picklist] == 2} {
    # }

    }

    if {[llength $picklist] == 3} {
      # See if we have an angle to pick
      #puts "Looking for an angle"
      set i 0
      #puts $picklist
      #puts "$::Molefacture::anglelist"
      foreach angle $::Molefacture::anglelist {
        if {([lindex $angle 1] == [lindex $picklist 1]) && (([lindex $angle 0] == [lindex $picklist 0] && [lindex $angle 2] == [lindex $picklist 2]) || ([lindex $angle 2] == [lindex $picklist 0] && [lindex $angle 0] == [lindex $picklist 2]))} {
          #puts "Found it!"
          hilight_angle [lindex $picklist 0] [lindex $picklist 1] [lindex $picklist 2] $i
        } 
        incr i
      }
  }
 }
}

proc ::Molefacture::hilight_angle {atom1 atom2 atom3 angleindex} {
# Procedure to select an angle in molefacture, including updating the angle list
    # Blank all item backgrounds
#  puts "DEBUG: Entering hilight_angle"
      for {set i 0} {$i<[.molefac.angles.list.list index end]} {incr i} {
	      .molefac.angles.list.list itemconfigure $i -background {}
      }
      # Get current selection index
      set selangle [.molefac.angles.list.list curselection]

      # Paint the background of the selected bond
      .molefac.angles.list.list itemconfigure $angleindex -background $::Molefacture::selectcolor
      .molefac.angles.list.list activate $angleindex
      .molefac.angles.list.list yview $angleindex

      # Get the selected bond
      set selindex [lrange [lindex $::Molefacture::anglelist $angleindex] 0 2]

      # Get information about this angle
      variable tmpmolid
      variable angle
      variable angleatom
      variable angleaxis
      variable anglesel
      variable anglepicklist
      variable anglemoveatom
      variable anglecoor
      variable dihedmarktags

      # Delete the dihedral marks
      foreach tag $::Molefacture::dihedmarktags {
	      graphics $::Molefacture::tmpmolid delete $tag
      }

      set angleatom(1) [lindex $selindex 0]
      set angleatom(2) [lindex $selindex 1]
      set angleatom(3) [lindex $selindex 2]

      set sel1 [atomselect $tmpmolid "index $angleatom(1)"]
      set sel2 [atomselect $tmpmolid "index $angleatom(2)"]
      set sel3 [atomselect $tmpmolid "index $angleatom(3)"]

      set coor2 [join [$sel2 get {x y z}]]
      set coor1 [join [$sel1 get {x y z}]]
      set coor3 [join [$sel3 get {x y z}]]

      set anglecoor(1) $coor1
      set anglecoor(2) $coor2
      set anglecoor(3) $coor3

#      puts "Subcoors: $coor1 $coor2 $coor3"
      set vec1 [vecsub $coor2 $coor1]
      set vec2 [vecsub $coor2 $coor3]

      set axis [veccross $vec1 $vec2]
#      puts "Doing norm of $axis"
      set angleaxis [vecscale [vecnorm $axis] 1.0]
#      puts "Done"

      # Generate two selections for the two molecule halves
      set indexes1 [::Paratool::bondedsel $tmpmolid $angleatom(1) $angleatom(2) 50]
      set indexes2 [::Paratool::bondedsel $tmpmolid $angleatom(3) $angleatom(2) 50]
      if {[havecommonelems $indexes1 $indexes2 [list $angleatom(1) $angleatom(2) $angleatom(3)]] > 0} {
        set indexes1 $angleatom(1)
        set indexes2 $angleatom(3)
      }
      if {[array exists anglesel]} { catch {$anglesel(1) delete}; catch {$anglesel(2) delete }}
      set mysel1 [uplevel 2 "atomselect $tmpmolid \"index $indexes1 and not index $angleatom(2)\""]
      set mysel2 [uplevel 2 "atomselect $tmpmolid \"index $indexes2 and not index $angleatom(2)\""]
      array set anglesel [list 1 $mysel1]
      array set anglesel [list 2 $mysel2]

      #Compute the angle
      label add Angles $tmpmolid/$angleatom(1) $tmpmolid/$angleatom(2) $tmpmolid/$angleatom(3)
      set angle [lindex [lindex [label list Angles] end] 3]
#      puts "Angle: $angle"
      label delete Angles all

      .molefac.angles.realangle.scale set $::Molefacture::angle
}

proc ::Molefacture::hilight_bond {atom1 atom2 bondindex} {
# Carry out all the background stuff required when you select a bond in molefacture
# Includes updating the bond list, highlighting dihedral, and so forth
# Must be given the two atom indices and the index of the bond in bondlist
  #puts "DEBUG: Running hilight_bond for $atom1 $atom2 $bondindex"

  ## Update the highlighted bonds in the list

  for {set i 0} {$i<[.molefac.bonds.list.list index end]} {incr i} {
	  .molefac.bonds.list.list itemconfigure $i -background {}
  }

  .molefac.bonds.list.list itemconfigure $bondindex -background $::Molefacture::selectcolor
  .molefac.bonds.list.list activate $bondindex
  .molefac.bonds.list.list yview $bondindex

  # Set up the bond and dihedral values

  variable tmpmolid
  if {![llength $tmpmolid]} { return }
  variable bondcoor
  variable dihedatom
  set dihedatom(1) $atom1
  set dihedatom(2) $atom2
  set sel1 [atomselect $tmpmolid "index $dihedatom(1)"]
  set sel2 [atomselect $tmpmolid "index $dihedatom(2)"]
  set bondcoor(1) [join [$sel1 get {x y z}]]
  set bondcoor(2) [join [$sel2 get {x y z}]]
  set ::Molefacture::bondlength [veclength [vecsub $bondcoor(2) $bondcoor(1)]]

  # Choose a dihedral for this bond
  set bonds1 [lsearch -all -inline -not [join [$sel1 getbonds]] $dihedatom(2)]
  set bonds2 [lsearch -all -inline -not [join [$sel2 getbonds]] $dihedatom(1)]
  set dihedatom(0) [lindex $bonds1 0]
  set dihedatom(3) [lindex $bonds2 0]
  # Delete the old marks
  variable dihedmarktags
  foreach tag $dihedmarktags {
	  graphics $tmpmolid delete $tag
  }

   if {[llength $dihedatom(0)] && [llength $dihedatom(3)]} {
     #puts "dihedatom(0)=$dihedatom(0); [join [$sel1 getbonds]]; $bonds1"
     #puts "dihedatom(1)=$dihedatom(1)"
     #puts "dihedatom(2)=$dihedatom(2)"
     #puts "dihedatom(3)=$dihedatom(3); [join [$sel2 getbonds]]; $bonds2"
     set sel0 [atomselect $tmpmolid "index $dihedatom(0)"]
     set bondcoor(0) [join [$sel0 get {x y z}]]
     set sel3 [atomselect $tmpmolid "index $dihedatom(3)"]
     set bondcoor(3) [join [$sel3 get {x y z}]]
     lappend dihedmarktags [graphics $tmpmolid color yellow]
     lappend dihedmarktags [graphics $tmpmolid sphere $bondcoor(0) radius 0.3]
     lappend dihedmarktags [graphics $tmpmolid sphere $bondcoor(3) radius 0.3]

     #puts "DEBUG: Generating molecule half selections"
     # Generate two selections for the two molecule halves
     variable bondsel
     set indexes1 [::Paratool::bondedsel $tmpmolid $dihedatom(1) $dihedatom(2) 50]
     set indexes2 [::Paratool::bondedsel $tmpmolid $dihedatom(2) $dihedatom(1) 50]
     if {[havecommonelems $indexes1 $indexes2 [list $dihedatom(1) $dihedatom(2)]] > 0} {
       set indexes1 $dihedatom(1)
       set indexes2 $dihedatom(2)
 }
     #puts [array get bondsel]
 if {[array exists bondsel]} {catch {$bondsel(1) delete}; catch {$bondsel(2) delete}}
 set mysel1 [uplevel 2 "atomselect $tmpmolid \"index $indexes1 and not index $dihedatom(2)\""]
 set mysel2 [uplevel 2 "atomselect $tmpmolid \"index $indexes2 and not index $dihedatom(1)\""]
 array set bondsel [list 1 $mysel1]
 array set bondsel [list 2 $mysel2]

 # Compute the bond dihedral angle
  label add Dihedrals $tmpmolid/$dihedatom(0) $tmpmolid/$dihedatom(1) $tmpmolid/$dihedatom(2) $tmpmolid/$dihedatom(3)
   set ::Molefacture::dihedral [lindex [lindex [label list Dihedrals] end] 4]
   label delete Dihedrals all
 }

   variable w
   $w.bonds.f2.angle.scale set $::Molefacture::dihedral

}

proc ::Molefacture::draw_selatoms {} {
   variable tmpmolid

   # Delete any previously generated atomlabels
   variable atommarktags
   foreach tag $atommarktags {
      graphics $tmpmolid delete $tag
   }
   set atommarktags {}

   if {![winfo exists .molefac.val.list.list]} { return }

   variable labelradius
   variable picklist
   set selatoms $picklist; #[.molefac.val.list.list curselection]
   foreach atom $selatoms {
      set sel [atomselect $tmpmolid "index $atom"]
      lappend atommarktags [graphics $tmpmolid color orange]
      lappend atommarktags [graphics $tmpmolid sphere [join [$sel get {x y z}]] radius [expr $labelradius*1.5]]
      $sel delete
   }
}

proc ::Molefacture::edit_update_list {taglist} {

   # This function generates a formatted list from the columns in taglist
   # It returns both a formatted header for a table using the given column types
   # and a string and list containing the appropriate formatting codes

   set formatstring {}
   set formatfield {}
   
   foreach tag $taglist {
      switch $tag {
	 Index {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
         Atom1 {
            append formatstring {%5s }
            append formatfield  {%5s }
         }
         Atom2 {
            append formatstring {%5s }
            append formatfield  {%5s }
         }
         Atom3 {
            append formatstring {%5s }
            append formatfield  {%5s }
         }
	 Elem {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Name    {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Flags    {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Type    {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Rname {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Resid   {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Segid   {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 VDWeps  {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 Order  {
	    append formatstring {%5s }
	    append formatfield  {% 4.1f }
	 }
	 VDWrmin {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 FormCharge     {
	    append formatstring {% 12s }
	    append formatfield  {% 12.4f }
	 }
	 Charge     {
	    append formatstring {%7s}
	    append formatfield  {% 7.4f }
	 }
	 Lewis {
	    append formatstring {%5s }
	    append formatfield  {%5i }
	 }
	 Mullik     {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 MulliGr {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 NPA    {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 SupraM    {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 ESP     {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 RESP    {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 ForceF    {
	    append formatstring {%7s }
	    append formatfield  {% 7.4f }
	 }
	 Open    {
	    append formatstring {%5s}
	    append formatfield  {% 4i }
	 }
	 OxState    {
	    append formatstring { %7s}
	    append formatfield  {% 6i }
	 }
      }
   }

   # Build the formatted atomproptags
   set formatcommand "\[format \"$formatstring\" $taglist\]"
   eval set taglist "$formatcommand"
   #puts "Taglist: $taglist Format: $formatstring"
   set returnlist [list]
   lappend returnlist $taglist
   lappend returnlist $formatfield

   return $returnlist

} 

proc ::Molefacture::add_atom {name type resname resid segname segid element x y z charge} {
  # Proc to add an arbitrary atom; this should be used as a base for ALL atom
  # addition, so that any allocation of new atoms is done here in the future
  # returns the index of the newly added atom
  variable tmpmolid

   variable availablehyd

#   puts "Checking: $availablehyd"
   #Check to make sure we don't need more dummy hydrogens
   if {$availablehyd <= 0} {
     set sel [atomselect $tmpmolid all]
     hrealloc $sel
     $sel delete
   }

  set dummies [atomselect $tmpmolid "occupancy 0"]
  set hindex [lindex [$dummies list] 0]
  set newatom [atomselect $tmpmolid "index $hindex"]

  # Assign the proper characteristics
  $newatom set name $name
  $newatom set type $type
  $newatom set resname $resname
  $newatom set resid $resid
  $newatom set segname $segname
  $newatom set segid $segid
  $newatom set element $element
  $newatom set x $x
  $newatom set y $y
  $newatom set z $z
  $newatom set charge $charge

  #Set the occupancy to indicate its new status
  if {$element == "H"} {
    $newatom set occupancy 0.5
  } else {
    $newatom set occupancy 0.8
  }

  incr availablehyd -1
  return $hindex
}
  
proc ::Molefacture::noblanks {mylist} {
  set newlist [list]
  foreach elem $mylist {
    if {$elem != ""} {lappend newlist $elem}
  }

  return $newlist
}

proc ::Molefacture::hrealloc {selection} {
   variable availablehyd
   #puts "Availablehyd: $availablehyd"
   set tmptmpfile Moltmp.xbgf
   set tmpfile Molefacture_tmpmol.xbgf

   # Write the selection as XBGF to which the dummy atoms will be appended
   write_xbgf $tmptmpfile $selection
   #puts "Done writing xbgf"

   # Determine location of the atom repository
   set resid 9999
   set mincoord {0 0 0}
   set repository [vecadd $mincoord {-5 -5 -5}]
   set x [lindex $repository 0]
   set y [lindex $repository 1]
   set z [lindex $repository 2]
   set maxind 0

   # Find highest index in any existing repository hydrogen names
   set hind 1
   foreach name [$selection get name] {
      if {[string match "HM*" $name]} {
	 set ind [string range $name 1 end] 
	 if {[string is integer $ind]} { 
	    if {$ind>$hind} { set hind $ind }
	 }
      }
   }

   # Add dummy atoms to xbgf file
   set fid [open $tmptmpfile r]
   set ofile [open $tmpfile "w"]

   # Find the end of the atom section
   set maxind 0
   set line [gets $fid]
   while {[regexp {CONECT} $line]==0} {
     if {[regexp {^ATOM} $line]} {incr maxind}
     puts $ofile $line
     set line [gets $fid]
   }

   for {set index [expr $maxind+1]} {$index<=[expr $maxind+100]} {incr index} {
      set name "HM$hind"
      puts $ofile [format "ATOM   %6i %5s  UNK X %5i%10.5f%10.5f%10.5f %-5s%3i%2i %8.5f %6.3f %6.3f %3i %4s" $index $name $resid $x $y $z "XXH" 0 0 0.00000 0.000 0.000 1 "MOLF"]
      incr hind
   }

   set availablehyd 100

   while {![eof $fid]} {
     puts $ofile $line
     set line [gets $fid]
   }

   close $fid
   close $ofile
#   if {[file exists $tmptmpfile]} { file delete $tmptmpfile }

   # Load the file including the dummy atom repository
   variable tmpmolid
   set oldmolid $tmpmolid
   set tmpmolid [mol new $tmpfile]

   # Undraw all other molecules in VMD:
   foreach m [molinfo list] {
      if {$m==$tmpmolid} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   set sel [atomselect $tmpmolid "occupancy 1.0"]
   if {[lindex [$sel get atomicnumber] 0] == -1} {assign_elements}
   $sel delete

   #Reset the display
    mol selection      "occupancy > 0.4"
    mol representation "Bonds 0.1"
    mol color          Name
    mol modrep 0 top
    mol representation "VDW 0.1"
    mol addrep top
    display resetview
    init_oxidation
   #mol delete $oldmolid

}

proc ::Molefacture::set_phipsi {newphi newpsi} {
  variable phi
  variable psi
  set phi $newphi
  set psi $newpsi
}

proc ::Molefacture::build_textseq {sequence} {
  set seqlist [split $sequence ""]
  foreach aa $seqlist {
    switch $aa {
      A {::Molefacture::add_aa ALA}
      C {::Molefacture::add_aa CYS}
      D {::Molefacture::add_aa ASP}
      E {::Molefacture::add_aa GLU}
      F {::Molefacture::add_aa PHE}
      G {::Molefacture::add_aa GLY}
      H {::Molefacture::add_aa HIS}
      I {::Molefacture::add_aa ILE}
      K {::Molefacture::add_aa LYS}
      L {::Molefacture::add_aa LEU}
      M {::Molefacture::add_aa MET}
      N {::Molefacture::add_aa ASN}
      P {::Molefacture::add_aa PRO}
      Q {::Molefacture::add_aa GLN}
      R {::Molefacture::add_aa ARG}
      S {::Molefacture::add_aa SER}
      T {::Molefacture::add_aa THR}
      V {::Molefacture::add_aa VAL}
      W {::Molefacture::add_aa TRP}
      Y {::Molefacture::add_aa TYR}
      default {error "Warning: I didn't recognize the amino acid $aa. Please use one letter code and the standard 20 amino acids. I'm skipping this entry."}
    }
  }
}

proc ::Molefacture::search_atomlist {mylist myindex} {
  #Search a list of lists for an element where the first field matches myindex
  set index 0
  foreach elem $mylist {
#    puts "Comparing $myindex with [lindex $elem 0]"
    if {[lindex $elem 0] == $myindex} {
      return $index
    }
    incr index
  }

  return -1
}

proc ::Molefacture::havecommonelems {list1 list2 {excludelist {}}} {
# Check to see if list1 and list2 have any common elements
# Return 1 if they do, -1 if they don't
# Common elements that are in excludelist will be ignored
# Yes yes, I know this isn't the most efficient algorithm for this operation

  foreach elem1 $list1 {
    if {[lsearch -exact $list2 $elem1] >= 0 && [lsearch -exact $excludelist $elem1] == -1} {
      return 1
    }
  }

  return -1
}

proc ::Molefacture::update_bondlist {} {
  variable bondlist
  variable anglelist

#  puts "Before: $bondlist"
  set bondlist [::Molefacture::bondlist]
  set anglelist [::Molefacture::anglelist]
#  puts "After: $bondlist"

  return
}

proc ::Molefacture::apply_changes_to_parent_mol {} {
# Merge all applied changes back into the parent molecule
# We do this by writing and then reading an xbgf with data from both files
# First, all atoms in the original molecule are written, then those in the modified,
# and then all the remaining atoms in the original
  variable origmolid
  variable tmpmolid
  variable origseltext

  set xbgf_fstring "ATOM  %7i  %-4s  %3s %1s  %4i% 10.5f% 10.5f% 10.5f %-5s  0 0 % 8.5f %6.3f %6.3f  %3i    "


  if {$origseltext == ""} {
    tk_messageBox -type warning -title "No parent molecule exists" -message "Since molefacture was started with no selection, there's no parent molecule to merge changes into."
    return
  }

  set notmysel [atomselect $origmolid "not ($origseltext)"]
  set notmyselind [$notmysel get index]
  ::Molefacture::fix_changes

  set oldmol [$notmysel molid]
  set origsel [atomselect $oldmol "$origseltext"]

  set modifiedsel [atomselect $tmpmolid "occupancy >= 0.8"]

  set oldatoms [$notmysel num]
  set newatoms [$modifiedsel num]

  set minindex [lindex [lsort -integer [$origsel get index]] 0]

## Now, start writing the xbgf
  set ofile [open "molef_tmpfile_merge.xbgf" "w"]

# First write the header
  puts $ofile "BIOGRF  332"
  puts $ofile [format "REMARK NATOM  %i" [expr $oldatoms + $newatoms]]
  puts $ofile "FORCEFIELD DREIDING"
  puts $ofile "FORMAT ATOM   (a6,1x,i6,1x,a5,1x,a4,1x,a1,1x,i5,3f10.5,1x,a5,i3,i2,1x,f8.5,1x,f6.3,1x,f6.3,1x,i3,1x,a4)"

  foreach field {index name type resid resname chain x y z atomicnumber beta occupancy charge} {
    array set oldinfo [list $field [$notmysel get $field]]
    array set newinfo [list $field [$modifiedsel get $field]]
  }

#write all atoms in the pre-modified region
  set i 0
  set j 0

  array set transoldtonew {} ;# These variables hold index translations
  array set transmodtonew {}

  for {set i 0} {$i < $minindex} {incr i} {
    puts $ofile [format $xbgf_fstring [expr $i + 1] [lindex $oldinfo(name) $i] [lindex $oldinfo(resname) $i] "[lindex $oldinfo(chain) $i]" [lindex $oldinfo(resid) $i] [lindex $oldinfo(x) $i] [lindex $oldinfo(y) $i] [lindex $oldinfo(z) $i] [lindex $oldinfo(type) $i] [lindex $oldinfo(charge) $i] [lindex $oldinfo(beta) $i] [lindex $oldinfo(occupancy) $i] [lindex $oldinfo(atomicnumber) $i]]
    array set transoldtonew [list [lindex $oldinfo(index) $i] $i]
  }

#write atoms from the modified region
  for {set j 0} {$j < $newatoms} {incr i; incr j} {
    puts $ofile [format $xbgf_fstring [expr $i + 1] [lindex $newinfo(name) $j] [lindex $newinfo(resname) $j] "[lindex $newinfo(chain) $j]" [lindex $newinfo(resid) $j] [lindex $newinfo(x) $j] [lindex $newinfo(y) $j] [lindex $newinfo(z) $j] [lindex $newinfo(type) $j] [lindex $newinfo(charge) $j] [lindex $newinfo(beta) $j] [lindex $newinfo(occupancy) $j] [lindex $newinfo(atomicnumber) $j]]
    array set transmodtonew [list [lindex $newinfo(index) $j] $i]
  }

# write the rest of the original file
  for {set j 0; set k $minindex} {$j < [expr $oldatoms - $minindex]} {incr i; incr j; incr k} {
    puts $ofile [format $xbgf_fstring [expr $i + 1] [lindex $oldinfo(name) $k] [lindex $oldinfo(resname) $k] "[lindex $oldinfo(chain) $k]" [lindex $oldinfo(resid) $k] [lindex $oldinfo(x) $k] [lindex $oldinfo(y) $k] [lindex $oldinfo(z) $k] [lindex $oldinfo(type) $k] [lindex $oldinfo(charge) $k] [lindex $oldinfo(beta) $k] [lindex $oldinfo(occupancy) $k] [lindex $oldinfo(atomicnumber) $k]]
    array set transoldtonew [list [lindex $oldinfo(index) $k] $i]
  }

  set maxind $i


## Do stuff necessary to write the bonds
  puts $ofile "FORMAT CONECT (a6,14i6)"
  puts $ofile "FORMAT ORDER (a6,i6,13f6.3)"

# Find translations between the edited region of the old molecule, and the fresh version
# we assume that if name, segname, and resid match, it's the same atom
  array set oldnewpairs {}

  foreach name [$origsel get name] segname [$origsel get segname] resid [$origsel get resid] index [$origsel get index] {
    foreach newname [$modifiedsel get name] newsegname [$modifiedsel get segname] newresid [$modifiedsel get resid] newindex [$modifiedsel get index] {
      if {$name == $newname && $segname == $newsegname && $resid == $newresid} {
        array set oldnewpairs [list $index $newindex]
      }
    }
  }

# make an array of all bonds needed for output
  array set bondarray {}
  array set boarray {}


# First get all bonds internal to the *old* selection
  foreach ind [$notmysel get index] bonds [$notmysel getbonds] bos [$notmysel getbondorders] {
    set newind $transoldtonew($ind)
    set bondarray($newind) {}
    set boarray($newind) {}
    foreach bond $bonds bo $bos {
      if {[lsearch $notmyselind $bond] >= 0} {
        set bondarray($newind) [lappend bondarray($newind) $transoldtonew($bond)]
        set boarray($newind) [lappend boarray($newind) $bo]
      }
    }
  }
    
# Now get all bonds internal to the *new* selection
  foreach ind [$modifiedsel get index] bonds [$modifiedsel getbonds] bos [$modifiedsel getbondorders] {
    set newind $transmodtonew($ind)
    set bondarray($newind) {}
    set boarray($newind) {}
    foreach bond $bonds bo $bos {
      set bondarray($newind) [lappend bondarray($newind) $transmodtonew($bond)]
      set boarray($newind) [lappend boarray($newind) $bo]
    }
  }

  #puts [array get bondarray]


# Finish with all bonds *between* the old and new selection
# We use the old selection as a key for this, and assume the bonds still
#   exist if the partner atoms in the modified selection do
  foreach ind [$notmysel get index] bonds [$notmysel getbonds] bos [$notmysel getbondorders] {
    set newind $transoldtonew($ind)
    foreach bond $bonds bo $bos {
      if {[lsearch $notmyselind $bond] < 0} {
        set modind $oldnewpairs($bond)
        if {$modind == {}} {continue}
        set bondarray($newind) [lappend bondarray($newind) $transmodtonew($modind)]
        set boarray($newind) [lappend boarray($newind) $bo]
      }
    }
  }

# FINALLY, we get to write the bonds
  for {set i 0} {$i < $maxind} {incr i} {
    set bonds $bondarray($i)
    set bos $boarray($i)

    puts -nonewline $ofile [format "CONECT%6i" [expr $i + 1]]
    foreach bond $bonds {
      puts -nonewline $ofile [format "%6i" [expr int($bond + 1)]]
    }
    puts -nonewline $ofile "\n"

    puts -nonewline $ofile [format "ORDER %6i" [expr $i + 1]]
    foreach bo $bos {
      puts -nonewline $ofile [format "%6.3f" $bo]
    }
    puts -nonewline $ofile "\n"
  }


  puts $ofile "END"

# clean up
  close $ofile
  mol new "molef_tmpfile_merge.xbgf"
  done 1
}
