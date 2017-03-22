#
# Routines for writing and reading extended pdb files
# including bond, bondorder and charge information.
# These data are stored as remarks which can be read using
# 'molinfo top get remarks'.
#
# Author: Jan Saam
#

package provide extendedpdb 1.0

namespace eval ::ExtPDB:: {
   namespace export load_extpdb
   namespace export add_selection_to_pdb
   namespace export extract_extpdb_remarks
   namespace export write_extpdb
   namespace export write_pdb_atom
   namespace export open_pdb_end 
   namespace export write_pdb_bonds
   namespace export write_pdb_charges
   namespace export write_pdb_types
}

############################################################
# Append the atoms of a selection to an existing pdb file. #
############################################################

proc ::ExtPDB::add_selection_to_pdb { file addsel } {
   set fid [open $file r+]
   # Find the END tag
   set maxind 0
   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [gets $fid]
      if {[string equal $line "END"]} { break }
      if {[string equal [lindex $line 0] "ATOM"] && [lindex $line 1]>$maxind} {
	 set maxind [lindex $line 1]
      }
   }
   set chain  {}
   set altloc {}
   set insert {}
   set charge {}
   seek $fid $filepos
   foreach name [$addsel get name] index [$addsel get index] resid [$addsel get resid] resname [$addsel get resname] xyz [$addsel get {x y z}] segid [$addsel get segid] beta [$addsel get beta] occu [$addsel get occupancy] atomic [$addsel get atomicnumber] {
      set elem [::QMtool::atomnum2element $atomic]
      write_pdb_atom $fid $index $name $altloc $resname $chain $resid $insert $xyz $occu $beta \
	             $segid $elem $charge
   }
   puts $fid "END"                                                                                                                              
   close $fid
}

############################################################
# Load an extended pdb file including bond and lewischarge #
# info.                                                    #
############################################################

proc ::ExtPDB::load_extpdb { file } {
   set molid [mol new $file]
   extract_extpdb_remarks $molid
   return $molid
}

proc ::ExtPDB::extract_extpdb_remarks { molid } {
   set bonds {}
   set bondorders {}
   set lewischarges {}
   set types {}
   # Parse the REMARK 9 lines and extract BOND, ORDER, CHARGE and TYPE
   foreach remark [split [join [join [molinfo $molid get remarks]]] ";"] {
      if {[lindex $remark 1]==9} {
	 if {[lindex $remark 2]=="ORDER"} {
	    set bondorders [linsert $bondorders [lindex $remark 3] [lrange $remark 4 end]]
	 } elseif {[lindex $remark 2]=="BOND"} {
	    set bonds      [linsert $bonds      [lindex $remark 3] [lrange $remark 4 end]]
	 } elseif {[lindex $remark 2]=="CHARGE"} {
	    set lewischarges [linsert $lewischarges [lindex $remark 3] [lrange $remark 4 end]]
	 } elseif {[lindex $remark 2]=="TYPE"} {
	    set types      [linsert $types [lindex $remark 3] [lrange $remark 4 end]]
	 }
      }
   }

   set all [atomselect top "all"]

   if {[llength $bonds]==[$all num]}        { $all setbonds $bonds }
   if {[llength $bondorders]==[$all num]}   { $all setbondorders $bondorders }
   if {[llength $lewischarges]==[$all num]} { $all set charge $lewischarges }
   if {[llength $types]==[$all num]}        { $all set type $types }
   $all delete
}

############################################################
# Write the atoms of a selection to an extended pdb file   #
# including bond and lewischarge info.                     #
############################################################

proc ::ExtPDB::write_extpdb { file sel {writetypes includetypes} } {
   set fid [open $file w]

   # First write all atoms
   set chain  {}
   set altloc {}
   set insert {}
   set charge {}
   foreach name [$sel get name] index [$sel get index] resid [$sel get resid] resname [$sel get resname] xyz [$sel get {x y z}] segid [$sel get segid] beta [$sel get beta] occu [$sel get occupancy] atomic [$sel get atomicnumber] {
      set elem [::QMtool::atomnum2element $atomic]
      write_pdb_atom $fid $index $name $altloc $resname $chain $resid $insert $xyz $occu $beta \
	 $segid $elem $charge
   }

   # Write the bond list
   write_pdb_bonds $fid $sel

   # Write the bond list
   write_pdb_charges $fid $sel

   if {$writetypes!="notypes"} {
      # Write the type list
      write_pdb_types $fid $sel 0 $writetypes
   }

   puts $fid "END"
   close $fid
}


#############################################################
# Adds an atom record to a pdb file.                        #
# Note: The pdb format actually specifies that the resname  #
# has only 3 characters (format field 18-20). CHARMM knows  #
# 4 character resnames such as HEME and the empty field 21  #
# in the atom record is used to store the fourth character. #
#############################################################

proc ::ExtPDB::write_pdb_atom {fid index name altloc resname chain resid insert xyz occu beta segid elem charge} {
      set x [lindex $xyz 0]
      set y [lindex $xyz 1]
      set z [lindex $xyz 2]
      puts $fid [format "ATOM  %5i %4s%1s%4s%1s%4i%1s   %8.3f%8.3f%8.3f%6.2f%6.2f      %-4s%2s%2s" \
		    $index $name $altloc $resname $chain $resid $insert $x $y $z $occu $beta $segid \
		    $elem $charge]
}

#######################################################
# Open a pdbfile and place the pointer just before    #
# the END tag. Returns the file descriptor.           #
# Useful for appending stuff to a pdbfile.            #
# #####################################################

proc ::ExtPDB::open_pdb_end { file } {
   set fid [open $file r+]
   # Find the END tag
   set maxind 0
   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [gets $fid]
      if {[string equal $line "END"]} { break }
   }
   seek $fid $filepos
   return $fid
}

proc ::ExtPDB::write_pdb_bonds { fid sel {offset 0}} {
   set index $offset
   foreach bondsperatom [$sel getbonds] bosperatom [$sel getbondorders] {
      set nbonds 0
      set bpa {}
      set opa {}
      foreach bond $bondsperatom bondorder $bosperatom  {
	 if {![llength $bond]} { continue }
	 if {$offset} {
	    set bond [lsearch [$sel list] [expr $bond]]
	    if {$bond<0} { continue }
	 }
	    lappend bpa [expr $bond+$offset]
	    lappend opa $bondorder
	 incr nbonds
      }
      puts $fid [format "REMARK 9 BOND  %5i %s ;" $index [join $bpa]]
      puts $fid [format "REMARK 9 ORDER %5i %s ;" $index $opa]
      incr index
   }
}


proc ::ExtPDB::write_pdb_charges { fid sel {offset 0}} {
   set index $offset
   foreach charge [$sel get charge] {
      puts $fid [format "REMARK 9 CHARGE %5i %10.6f ;" $index $charge]
      incr index
   }
}

proc ::ExtPDB::write_pdb_types { fid sel {offset 0} {writetypes normal}} {
   set index $offset
   if {$writetypes=="emptytypes"} {
      foreach type [$sel get type] {
	 puts $fid [format "REMARK 9 TYPE %5i ;" $index]
	 incr index
      }
   } else {
      foreach type [$sel get type] {
	 puts $fid [format "REMARK 9 TYPE %5i %4s ;" $index $type]
	 incr index
      }
   }
}
