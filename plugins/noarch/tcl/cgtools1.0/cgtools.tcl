# cgtools is a vmd package that allows conversion to and from coarse grain 
#  representations. See the docs for details on file formats.

package provide cgtools 0.1

namespace eval ::cgtools:: {

  # List of currently recognized conversions
  variable convbeads [list] 
  variable idxarray
  variable startposarray
  variable massarray
  namespace export read_db apply_reversal apply_database

}

proc ::cgtools::resetconvs {} {
  #Proc to reset the list of conversions currently being held
  variable convbeads
  set convbeads [list]
}

proc ::cgtools::read_db {file} {
  #Read all cg conversions in file and add them to the convbeads list
  variable convbeads

  set infile [open $file "r"]
  
  while {[gets $infile line] >= 0} {
    if {[regexp {^CGBEGIN} $line]} {
      set newbead [read_bead $infile]
      lappend convbeads $newbead
      puts $newbead
    }
  }

  close $infile
}

proc ::cgtools::make_anneal_config {pdb psf par conffile logfile {isRemote 0} } {
  variable idxarray
  variable massarray
  variable startposarray

#  set idxarray [list]
#  set massarray [list]
#  set startposarray [list]

  mol load psf $psf pdb $pdb
  set sel [atomselect top all]

  set min [lindex [measure minmax $sel] 0]
  set max [lindex [measure minmax $sel] 1]
  set center [measure center $sel]
  
  set diffvec [vecsub $max $min]
  set xvec [lindex $diffvec 0]
  set yvec [lindex $diffvec 1]
  set zvec [lindex $diffvec 2]
  set xpme [expr int(pow(2,(int(log($xvec)/log(2)) + 1)))]
  set ypme [expr int(pow(2,(int(log($yvec)/log(2)) + 1)))]
  set zpme [expr int(pow(2,(int(log($zvec)/log(2)) + 1)))]

  set conf [open $conffile "w"]

  #Now, write the file itself
  puts $conf "\# Automatically generated configuration for annealing a revcg structure"
  if { $isRemote } {
     puts $conf "structure          [file tail $psf]"
     puts $conf "coordinates        [file tail $pdb]"
     for {set i 0} {$i < [llength $par] } {incr i} {
        puts $conf "parameters         [file tail [lindex $par $i]]"
     }
  } else {
     puts $conf "structure          $psf"
     puts $conf "coordinates        $pdb"
     for {set i 0} {$i < [llength $par] } {incr i} {
        puts $conf "parameters         [lindex $par $i]"
     }
  }
  puts $conf "set temperature    298"
  puts $conf "set outputname     $conffile"
  puts $conf "firsttimestep      0"
  puts $conf "paraTypeCharmm	    on"
  puts $conf "temperature         298"
  puts $conf "exclude             scaled1-4"
  puts $conf "1-4scaling          1.0"
  puts $conf "cutoff              12."
  puts $conf "switching           on"
  puts $conf "switchdist          10."
  puts $conf "pairlistdist        13.5"
  puts $conf "timestep            1.0  "
  puts $conf "nonbondedFreq       1"
  puts $conf "fullElectFrequency  2  "
  puts $conf "stepspercycle       10"
#  puts $conf "langevin            on   "
#  puts $conf "langevinDamping     5    "
#  puts $conf "langevinTemp        298"
#  puts $conf "langevinHydrogen    off  "
  puts $conf "cellBasisVector1    $xvec    0.   0."
  puts $conf "cellBasisVector2     0.   $yvec   0. "
  puts $conf "cellBasisVector3     0.    0   $zvec"
  puts $conf "cellOrigin         $center"
  puts $conf "wrapAll             on"
  puts $conf "PME                 yes"
  puts $conf "PMEGridSizeX        $xpme"
  puts $conf "PMEGridSizeY        $ypme"
  puts $conf "PMEGridSizeZ        $zpme"
  puts $conf "useFlexibleCell       no"
  puts $conf "useConstantArea       no"
  puts $conf "outputName          $conffile"
  puts $conf "restartfreq         500"
  puts $conf "dcdfreq             150"
  puts $conf "xstFreq             200"
  puts $conf "outputEnergies      100"
  puts $conf "outputPressure      100"
  puts $conf "tclForces on"
  puts $conf "tclForcesScript     $conffile-constr.tcl"
  puts $conf "reassignFreq 500"
  puts $conf "reassignTemp 610"
  puts $conf "reassignIncr -10"
  puts $conf "reassignHold 300"
  puts $conf "minimize            5000"
  puts $conf "reinitvels          610"
  puts $conf "run 20000"
  puts $conf "minimize 1000"


  close $conf
  $sel delete

  #Write the tclforces file
  set tclf [open "$conffile-constr.tcl" "w"]
  puts $tclf "# Automatically generated tcl script for constraining centers of mass"
  puts $tclf "# Note that this is a hideously ugly way of doing things -- don't use this"
  puts $tclf "# for anything except annealing a cg structure"
  puts $tclf ""
  puts $tclf "set beadcenters {$startposarray}"
  puts $tclf "set atomlists {$idxarray}"
  puts $tclf "set atommasses {$massarray}"
  puts $tclf "set k 5.0"
  puts $tclf "set t 0"
  puts $tclf "set TclFreq 20"
  puts $tclf ""
  puts $tclf ""
  puts $tclf "# Add all the atoms"
  puts $tclf "foreach atomlist \$atomlists {"
  puts $tclf "  foreach atom \$atomlist {"
  puts $tclf "    addatom \$atom"
  puts $tclf "  }"
  puts $tclf "}"
  puts $tclf ""
  puts $tclf "proc calcforces {} {"
  puts $tclf "  global beadcenters atomlists atommasses k t TclFreq"
  puts $tclf ""
  puts $tclf ""
  puts $tclf "  # Get the coordinates for our timestep"
  puts $tclf "  loadcoords coordinate"
  puts $tclf ""
  puts $tclf "  # Loop through the ex-beads and constrain each center of mass"
  puts $tclf "  foreach bead \$beadcenters atomlist \$atomlists masslist \$atommasses {"
  puts $tclf "    # Loop over the atoms in the bead and find its center of mass"
  puts $tclf "    set com \[list 0 0 0\]"
  puts $tclf "    set mtot 0"
  puts $tclf "    foreach atom \$atomlist mass \$masslist {"
  puts $tclf "      set myx \[lindex \$coordinate(\$atom) 0\]"
  puts $tclf "      set myy \[lindex \$coordinate(\$atom) 1\]"
  puts $tclf "      set myz \[lindex \$coordinate(\$atom) 2\]"
  puts $tclf ""
  puts $tclf "      set mycoors \[list \$myx \$myy \$myz\]"
  puts $tclf ""
  puts $tclf "      set com \[vecadd \$com \[vecscale \$mycoors \$mass\]\]"
  puts $tclf "      set mtot \[expr \$mtot + \$mass\]"
  puts $tclf "    }"
  puts $tclf ""
  puts $tclf "    set com \[vecscale \$com \[expr 1.0 / \$mtot\]\]"
  puts $tclf ""
  puts $tclf "    # Find the vector between the center of mass and the anchor, and apply a force"
  puts $tclf "    set delvec \[vecsub \$bead \$com\]"
  puts $tclf "    set dist2 \[vecdot \$delvec \$delvec\]"
  puts $tclf "    set dist1 \[expr sqrt(\$dist2)\]"
  puts $tclf "    set fmag \[expr \$dist2 \* \$k\]"
  puts $tclf "    set delvec \[vecscale \$delvec \[expr 1.0 / \$dist1\]\]"
  puts $tclf "    set fvec \[vecscale \$delvec \$fmag\]"
  puts $tclf "    set fvec \[vecscale \$fvec \[expr 1.0 / \$mtot\]\]"
  puts $tclf ""
  puts $tclf "    # Loop through the atoms and apply a mass-weighted force to each"
  puts $tclf "    foreach atom \$atomlist mass \$masslist {"
  puts $tclf "      set myf \[vecscale \$fvec \$mass\]"
  puts $tclf "      addforce \$atom \$myf"
  puts $tclf "    }"
  puts $tclf ""
  puts $tclf "  }"
  puts $tclf ""
  puts $tclf "  return"
  puts $tclf "}"

  puts $tclf "# Auxilliary procs to use with vectors"
  puts $tclf "proc vecmult {vec scalar} {"
  puts $tclf "  set newarr \[list\]"
  puts $tclf "  foreach elem \$vec {"
  puts $tclf "    set newelem \[expr \$elem * \$scalar\]"
  puts $tclf "    lappend newarr \$newelem"
  puts $tclf "  }"
  puts $tclf "  return \$newarr"
  puts $tclf "}"
  puts $tclf ""
  puts $tclf "proc vecdot {vec1 vec2} {"
  puts $tclf "  set newval 0"
  puts $tclf "  foreach elem1 \$vec1 elem2 \$vec2 {"
  puts $tclf "    set newval \[expr \$newval + (\$elem1 * \$elem2)\]"
  puts $tclf "  }"
  puts $tclf "  return \$newval"
  puts $tclf "}"
  puts $tclf ""
  puts $tclf "proc vecsub {vec1 vec2} {"
  puts $tclf "  set newarr \[list\]"
  puts $tclf "  foreach elem1 \$vec1 elem2 \$vec2 {"
  puts $tclf "    set newelem \[expr \$elem1 - \$elem2\]"
  puts $tclf "    lappend newarr \$newelem"
  puts $tclf "  }"
  puts $tclf "  return \$newarr"
  puts $tclf "}"

  close $tclf


  mol delete top
}


  

proc ::cgtools::read_bead {fstream} {
  #Given a file stream currently starting a new bead, read the bead's components
  # and return the new atom list
  # The bead "object" is simply a list of beads and atoms, as defined in make_atom
  # The first entry in this list is the "bead"; the others are the target atoms

  set mybead [list]
  
  while {[gets $fstream line] && ![regexp {^CGEND} $line]} {
    if {[regexp {^\#} $line]} { 
     continue 
    }

    #split the line up into fields and make a new atom
    set linearray [split $line]
    set linearray [noblanks $linearray]
    set newatom [make_atom [lindex $linearray 0] [lindex $linearray 1] [lindex $linearray 2]]
    lappend mybead $newatom
  }

  return $mybead
}

proc ::cgtools::make_atom {resname atomname resoffset} {
  #Create a new cg bead/atom with atomname in element 0,resname in element 1, and a resid
  # offset in element 2

  set newatom [list]

#  set newatom(Resname) $resname
#  set newatom(Atomname) $atomname
#  set newatom(Offset) $resoffset
  
  lappend newatom $atomname
  lappend newatom $resname
  lappend newatom $resoffset

  return $newatom
}

proc ::cgtools::apply_reversal {molid revcgfile origmolid outputfile } {

  #Apply the reverse transformations in revcgfile to the cg molecule in molid, using the initial all atom structure from origmolid

  variable idxarray
  variable startposarray
  variable massarray

  #Read the reverse cg file line by line, and apply each in turn
  set infile [open $revcgfile "r"]
  set idxarray [list]
  set startposarray [list]
  set massarray [list]

#  set idxfile [open "revcg.idx" "w"]
#  set startfile [open "revcg_starts.dat" "w"]

  while {[gets $infile line] >= 0} {
    set linelist [split $line]
    set linelist [noblanks $linelist]
    set resname [lindex $linelist 0]
    set beadname [lindex $linelist 1]
    set resid [lindex $linelist 2]
    set segid [lindex $linelist 3]
    set indices [lreplace $linelist 0 3]
    
    set aasel [atomselect $origmolid "index $indices"]
    set cgsel [atomselect $molid "resname $resname and name $beadname and resid $resid and segid $segid"]
    
    set aacen [measure center $aasel weight mass]
    set cgcen [lindex [$cgsel get {x y z}] 0]
    
    set movevec [vecsub $cgcen $aacen]
    $aasel moveby $movevec

    #Write NAMD-tclforces indices to file
    set indlist [list]
    set masslist [list]
    foreach index [$aasel get index] mass [$aasel get mass] {
      set index [expr $index + 1]
      lappend indlist $index
      lappend masslist $mass
    }

    lappend idxarray $indlist
    lappend massarray $masslist

    #Write center of mass position to file
    lappend startposarray $cgcen

    $aasel delete
    $cgsel delete
  }

  close $infile

  set sel [atomselect $origmolid all]
  $sel writepdb $outputfile



}
  

proc ::cgtools::apply_database {molid outputfile revcgfile} {
  #Applies the contents of the current convbeads database to the
  # selected molecule, and writes the result to OUTPUTFILE

  variable convbeads

  #Open file for reverse coarse graining information
  # format of file is resname beadname segid index1 index2 index3...
  # where the first 3 fields come from the CG bead, and the indices are corresponding
  # all atom indices
  set rcgout [open $revcgfile "w"]

  #Beads which should be kept and written are tagged with occupancy 1
  # All other atoms should have occupancy 0
  set allsel [atomselect $molid all]
  set oldocc [$allsel get occupancy]
  set oldxyz [$allsel get {x y z}]
  $allsel set occupancy 0

  #Loop through the conversion database and do each bead type
  foreach cgbead $convbeads {
    apply_bead $cgbead $molid $rcgout
  }

  set writesel [atomselect $molid "occupancy 1"]
  $writesel writepdb $outputfile

  $writesel delete
  $allsel set occupancy $oldocc
  $allsel set {x y z} $oldxyz
  $allsel delete

  close $rcgout
}

proc ::cgtools::prepare_water {molid {simple 0}} {
# Make sure waters are consecutively numbered and spatially localized for CG procedure
  set watsel [atomselect $molid water] 
  $watsel set segid [lindex [$watsel get segid] 0]
  $watsel set resid 0
  $watsel delete

# Start looping over waters; pick one, and take the three unassigned waters closest to it to make a bead
  set watkeys [atomselect $molid "water and oxygen and resid 0"]
  set resnum 1
  set totalwat [$watkeys num]

  if {$simple != 0} {
    foreach index [$watkeys get index] {
    puts "Done with $resnum of $totalwat waters"
      set sel [atomselect $molid "same residue as index $index"]
      $sel set resid $resnum
      $sel delete
      incr resnum
    }
    $watkeys delete
    return
  }

  while {[$watkeys num] > 0} {
    puts "Done with $resnum of $totalwat waters"

    set mykey [lindex [$watkeys get index] 0]
    set keyres [atomselect $molid "same residue as index $mykey"]
    $keyres set resid $resnum
    incr resnum

# Grow a selection around the key until we find 3 other waters
    set r 4.0
    set othersel [atomselect $molid "water and oxygen and resid 0 and within $r of index [$keyres get index]"]

    while {[$othersel num] < 3} {
      set r [expr $r + 2.0]
      set othersel [atomselect $molid "water and oxygen and resid 0 and within $r of index [$keyres get index]"]
    }
    
    set otherkeys [$othersel get index]
    $othersel delete

    for {set i 0} {$i < [llength $otherkeys] && $i < 3} {incr i} {
      #puts "DEBUG: otherkeys $otherkeys i $i"
      set mywat [atomselect $molid "same residue as index [lindex $otherkeys $i]"]
      $mywat set resid $resnum
      incr resnum
      $mywat delete
    }

    set watkeys [atomselect $molid "water and oxygen and resid 0"]
}
}

proc ::cgtools::apply_bead {cgbead molid revcgfile} {
  #Applies the conversion specified in CGBEAD to the molecule MOLID
  # This means going though the molecule, matching everything that
  # corresponds to the first element of cgbead, and then building
  # each of those beads in turn

  set beadname [lindex [lindex $cgbead 0] 0]
  set beadres [lindex [lindex $cgbead 0] 1]
  set beadoff [lindex [lindex $cgbead 0] 2]
  set cgbead [lreplace $cgbead 0 0]
  set headname [lindex [lindex $cgbead 0] 0]
  set headres [lindex $[lindex $cgbead 0] 1]
  set headoff [lindex $[lindex $cgbead 0] 2]
  set cgbead [lreplace $cgbead 0 0]

#puts "DEBUG: Looking to make cgbead $beadname $beadres $beadoff with head atom $headname $headres $headoff"

  #Find all of the atoms matching the head definition
  if {$headres == "*"} {
    set headbeads [atomselect $molid "name $headname"]
  } else {
    set headbeads [atomselect $molid "name $headname and resname $headres"]
  }
  $headbeads set occupancy 1
  $headbeads set name $beadname
  if {$beadres != "*"} {$headbeads set resname $beadres}

  #Make three arrays of the qualifying characteristics of subordinate beads
  set names [list]
  set resnames [list]
  set offsets [list]
  foreach subatom $cgbead {
    lappend names [lindex $subatom 0]
    lappend resnames [lindex $subatom 1]
    lappend offsets [lindex $subatom 2]
  }

  #Now, for each head atom we've found, adjust its position according to where its
  # children are
  foreach index [$headbeads get index] resid [$headbeads get resid] segid [$headbeads get segid] {
    puts "Applying bead with head $index"
    set headatom [atomselect $molid "index $index"]
    $headatom set resid [expr $resid - $headoff]
    set resid [expr $resid - $headoff]

    set i 0
    set fullbeadsel "segid $segid and ( index $index"
    foreach name $names resname $resnames offset $offsets {
      if {$resname == "*"} {
        atomselect macro "cgmacro$i" "name $name and resid [expr $resid + $offset] and resname [$headatom get resname]"
      } else {
        atomselect macro "cgmacro$i" "name $name and resid [expr $resid + $offset] and resname $resname"
      }
      set fullbeadsel "$fullbeadsel or cgmacro$i"
      incr i
    }

    set fullbeadsel "$fullbeadsel )"

    set mybeadsel [atomselect $molid "$fullbeadsel"]
    $headatom moveto [measure center $mybeadsel weight mass]

    puts $revcgfile "[$headatom get resname] [$headatom get name] [$headatom get resid] [$headatom get segid] [$mybeadsel get index]"
    
    $headatom delete
    $mybeadsel delete
  }

    
}

proc noblanks {mylist} {
  set newlist [list]
  foreach elem $mylist {
    if {$elem != ""} {
      lappend newlist $elem
    }
  }

  return $newlist
}



