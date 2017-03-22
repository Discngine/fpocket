#
# Solvate plugin - generate a water box and add solute
#
# $Id: solvate.tcl,v 1.29 2007/02/27 07:55:30 ltrabuco Exp $
#
# generate water block coordinates (VMD)
# replicate water block (psfgen)
# combine water block and solute in psfgen (psfgen)
# Create pdb with just the water you want (VMD)
# merge the solute and the cutout water (psfen)
#
# Changes since version 1.0:
#   Fixed a bug in the water overlap code which left waters close to the
#     solute.  Never figured out what was wrong; probably just using the wrong
#     coordinates.
#
#   Added a sanity check to make sure that solvate didn't leave any waters 
#     near the solute.
#
# TODO?
# Seperate command-line parsing code from solvation code.  solvate{} should
# still handle the command line, and possibly load the PSF and PDB into VMD.
# A seperate proc should perform the actual solvation, accepting a VMD molid
# (rather than filenames) and other solvation parameters.
# 
# The command line could include a new -molid option (other options should
# remain unchanged to preserve backward-compatability with old scripts) and
# file paths can be removed entirely from GUI in favor of a drop-down menu
# of VMD molecules. In addition to the GUI improvement, these changes will
# allow users to use solvate with other file format combinations that
# provide the same information as the PSF/PDB combination.

package require psfgen 1.2
package provide solvate 1.2

proc solvate_usage { } {
  puts "Usage: solvate <psffile> <pdbfile> <option1?> <option2?>..."
  puts "Usage: solvate <option1?> <option2?>...  to just create a water box" 
  puts "Options:"
  puts "    -o <output prefix> (data will be written to output.psf/output.pdb)"
  puts "    -s <segid prefix> (should be either one or two letters; default WT)"
  puts "    -b <boundary> (minimum distance between water and solute, default 2.4)"
  puts "    -minmax {{xmin ymin zmin} {xmax ymax zmax}}"
  puts "    -rotate (rotate molecule to minimize water volume)"
  puts "    -rotsel <selection> (selection of atoms to check for rotation)"
  puts "    -rotinc <increment> (degree increment for rotation)"
  puts "    -t <pad in all directions> (override with any of the following)"
  puts "    -x <pad negative x>"
  puts "    -y <pad negative y>"
  puts "    -z <pad negative z>"
  puts "    +x <pad positive x>"
  puts "    +y <pad positive y>"
  puts "    +z <pad positive z>"
  puts "    The following options allow the use of solvent other than water:"
  puts "      -spsf <solventpsf> (PSF file for nonstandard solvent)"
  puts "      -spdb <solventpdb> (PDB file for nonstandard solvent)"
  puts "      -stop <solventtop> (Topology file for nonstandard solvent)"
  puts "      -ws <size> (Box length for nonstandard solvent)"
  puts "      -ks <keyatom> (Atom occuring once per residue for nonstandard solvent)"
  error ""
}

proc solvate {args} {
    global errorInfo errorCode
    set oldcontext [psfcontext new]  ;# new context
    set errflag [catch { eval solvate_core $args } errMsg]
    set savedInfo $errorInfo
    set savedCode $errorCode
    psfcontext $oldcontext delete  ;# revert to old context
    if $errflag { error $errMsg $savedInfo $savedCode }
}

proc solvate_core {args} {
  global env 
  global bounds

  set fullargs $args

# Set some defaults

  # PSF and PDB files, and other info, of the solvent box
  set solventpsf "$env(SOLVATEDIR)/wat.psf"
  set solventpdb "$env(SOLVATEDIR)/wat.pdb"
  set solventtop "$env(SOLVATEDIR)/wat.top"
  set watsize 65.4195 ;# side length of the solvent box
  set keysel "name OH2" ;# name of a key atom that occurs once per residue

 
  # Print usage information if no arguments are given
  if { ![llength $args] } {
    solvate_usage
  }

  # The first argument that starts with a "-" marks the start of the options.
  # Arguments preceding it, if any, must be the psf and pdb files.
  set arg0 [lindex $args 0]
  if { [llength $args] >= 2 && [string range $arg0 0 0] != "-" } {
    set psffile [lindex $args 0]
    set pdbfile [lindex $args 1]
    set args [lrange $args 2 end]
  }

  # Toggle the rotate flag if present
  set rot [lsearch $args "-rotate"]
  if {$rot != -1} {
    set rotate 1
    set args [lreplace $args $rot $rot]
  } else {
    set rotate 0
  }

  set rotselind [lsearch $args "-rotsel"]
  if {$rotselind != -1} {
    set rotsel [lindex $args [expr $rotselind + 1]]
    set args [lreplace $args $rotselind [expr $rotselind + 1]]
  } else {
    set rotsel "all"
  }
  
  set rotincind [lsearch $args "-rotinc"]
  if {$rotincind != -1} {
    set rotinc [lindex $args [expr $rotincind + 1]]
    set args [lreplace $args $rotincind [expr $rotincind + 1]]
    set rotinc [expr 360 / $rotinc]
  } else {
    set rotinc 36
  }
 
  foreach elem { -b +x +y +z -x -y -z -minmax -t -o -spsf -spdb -stop -ws -ks} {
    set bounds($elem) 0
  }
  set bounds(-s) WT
  set bounds(-b) 2.4

  set n [llength $args]
  # check for even number of args
  if { [expr fmod($n,2)] } { solvate_usage }
    
  #
  # Get all command line options
  #
  for { set i 0 } { $i < $n } { incr i 2 } {
    set key [lindex $args $i]
    set val [lindex $args [expr $i + 1]]
    if { ! [info exists bounds($key)] } {
      solvate_usage 
    }
    set cmdline($key) $val 
  }

  # Get a nonstandard solvent box, if specified
  if { [info exists cmdline(-spsf)] } {
    set solventpsf $cmdline(-spsf)
  }

  if { [info exists cmdline(-spdb)] } {
    set solventpdb $cmdline(-spdb)
  }

  if { [info exists cmdline(-stop)] } {
    set solventtop $cmdline(-stop)
  }
  if { [info exists cmdline(-ws)] } {
    set watsize $cmdline(-ws)
  }
  if { [info exists cmdline(-ks)] } {
    set keysel $cmdline(-ks)
  }

  # 
  # Get minmax if specified, or use minmax of solute
  #

  # 
  # If -t was specified, use it for all pads
  #
  if { [info exists cmdline(-t)] } {
    foreach elem { -x -y -z +x +y +z } {
      set bounds($elem) $cmdline(-t)
    }
  }

  # 
  # Fill in all other specified options
  #  
  set outputname solvate
  if { [info exists cmdline(-o)] } {
    set outputname $cmdline(-o)
  }

  #Open and use a logfile
  set logfile [open "$outputname.log" w]
  puts $logfile "Running solvate with arguments: $fullargs"

  # If the rotate flag is present, rotate the molecule
  # Note that rotate is meaningless if we're doing water box only
  if {$rotate == 1 && [info exists pdbfile]} {
    ::Solvate::rotate_save_water $pdbfile $rotsel $rotinc $logfile
  }

  if { [info exists cmdline(-minmax) ] } {
    set bounds(-minmax) $cmdline(-minmax)
  } else {
    if { [info exists psffile] } {  
      if {$rotate == 0} {
        mol new $psffile 
        mol addfile $pdbfile
      } else {
        mol new $psffile 
        mol addfile $pdbfile-rotated-tmp.pdb
      }

      if {[molinfo top get numframes] == 0} {
        error "Couldn't load psf/pdb files!"
        return
      }
      set sel [atomselect top all]
      set bounds(-minmax) [measure minmax $sel]
      mol delete top
    } else {
      error "No psf/pdb, so minmax must be specified."
    }
  }

  foreach elem [array names cmdline] {
    set bounds($elem) $cmdline($elem)
  }

  set env(SOLVATEPREFIX) $bounds(-s)
  set prefix $bounds(-s)

  foreach {min max} $bounds(-minmax) {} 
  set min [vecsub $min [list $bounds(-x) $bounds(-y) $bounds(-z)]]
  set max [vecadd $max [list $bounds(+x) $bounds(+y) $bounds(+z)]]


  #
  # generate combined psf/pdb containing solute and one replica of water
  # VMD can't do multi-molecule atom selections...
  #

  if { [info exists psffile] } {
    readpsf $psffile
    if {$rotate == 0} {
      coordpdb $pdbfile
    } else {
      coordpdb $pdbfile-rotated-tmp.pdb
      file delete $pdbfile-rotated-tmp.pdb
    }
  }

  readpsf $solventpsf
  coordpdb $solventpdb
  writepsf combine.psf
  writepdb combine.pdb
 
  delatom QQQ



  #
  # Extract info about where to put the water
  #
  foreach {xmin ymin zmin} $min {}
  foreach {xmax ymax zmax} $max {}

  set dx [expr $xmax - $xmin]
  set dy [expr $ymax - $ymin]
  set dz [expr $zmax - $zmin]

  set nx [expr int($dx/$watsize) + 1]
  set ny [expr int($dy/$watsize) + 1]
  set nz [expr int($dz/$watsize) + 1]

  puts "replicating $nx by $ny by $nz"
  puts $logfile "replicating $nx by $ny by $nz"

  #
  # Read combined structure back in and generate a new psf/pdb file with just
  # the waters we want.
  #
  mol load psf combine.psf pdb combine.pdb
  set wat [atomselect top "segid QQQ"]
  set wat_unique_res [lsort -unique -integer [$wat get resid]]
  set watres [$wat get resid]
  set watname [$wat get name] 

  topology $solventtop
  set n 0
  set rwat $bounds(-b)
  set seglist {}

  # check that we won't run out of segment name characters
  set numsegs [expr $nx * $ny * $nz]
  set segstrcheck "$prefix$numsegs"
  set usehex 0
  if { [string length $segstrcheck] > 4 } {
    puts "Warning: use of decimal numbering would overrun segname field size"
    puts "Warning: using hexadecimal numbering instead..."
    set usehex 1
  } 

  for { set i 0 } { $i < $nx } { incr i } {
    set movex [expr $xmin + $i * $watsize]
    for { set j 0 } { $j < $ny } { incr j } {
      set movey [expr $ymin + $j * $watsize]
      for { set k 0 } { $k < $nz } { incr k } {
        set movez [expr $zmin + $k * $watsize]
        set vec [list $movex $movey $movez]

        $wat moveby $vec 

        # Create new water replica... 
        incr n
        if { $usehex } {
          set nstr [string toupper [format "%x" $n]]
        } else {
          set nstr $n
        }
        segment ${prefix}$nstr {
          first NONE
          last NONE
          foreach res $wat_unique_res {
            residue $res TIP3
          }
        }
        lappend seglist ${prefix}$nstr
        foreach resid $watres name $watname pos [$wat get {x y z}] {
          coord ${prefix}$nstr $resid $name $pos
        }
        # ... and delete overlapping waters and those outside the box.
        set sel [atomselect top "segid QQQ and $keysel and same residue as \
	  (x < $xmin or x > $xmax or y < $ymin or y > $ymax or \
	  z < $zmin or z > $zmax or within $rwat of (not segid QQQ))"]
        foreach resid [$sel get resid] {
          # Use catch because the atom might have already been deleted 
          catch { delatom ${prefix}$nstr $resid }
        }
        unset upproc_var_$sel 
    
        $wat moveby [vecinvert $vec] 
      } 
    }
  }
  writepsf $outputname.psf
  writepdb $outputname.pdb

  # delete the current psfgen context before we load the newly 
  # generated files, otherwise we'll end up temporarily using over twice as
  # much memory until we return from this routine.
  resetpsf

  # Test to make sure we didn't miss any waters.  Add a fudge factor 
  # of sqrt(3 * .001^2) to the distance check because of limited precision
  # in the PDB file.
  mol delete top 
  mol load psf $outputname.psf pdb $outputname.pdb
  set rwat [expr $rwat - .001732]
  set sel [atomselect top "segid $seglist and within $rwat of (not segid $seglist)"]
  set num [$sel num]
  mol delete top
  if { $num != 0 } {
    puts "Found $num water atoms near the solute!  Please report this bug to"
    puts "vmd@ks.uiuc.edu, including, if possible, your psf and pdb file."
    error "Solvate 1.2 failed."  
  }
  puts "Solvate 1.2 completed successfully."
  puts $logfile "Solvate 1.2 completed successfully."
  mol load psf $outputname.psf pdb $outputname.pdb
  close $logfile
  return [list $min $max]
}
  
proc solvategui {} {
  return [::Solvate::solvate_gui]
}
 
namespace eval ::Solvate:: {
  namespace export solvate_gui

  variable w
  variable psffile
  variable pdbfile
  variable waterbox
  variable outprefix
  variable segid
  variable boundary
  variable min
  variable max
  variable use_mol_box
  variable minpad
  variable maxpad
  variable rotate
  variable rotsel
  variable rotinc
  set rotsel "all"
  set rotinc 10
  variable usealtsolv
  variable altsolvpdb
  variable altsolvpsf
  variable altsolvtop
  variable altsolvws
  variable altsolvks
  set usealtsolv 0
}

proc ::Solvate::solvate_gui {} {
  variable w
  ::Solvate::init_gui

  if { [winfo exists .solvategui] } {
    wm deiconify .solvategui
    return
  }
  set w [toplevel ".solvategui"]
  wm title $w "Solvate"

  frame $w.input
  grid [label $w.input.label -text "Input"] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid [label $w.input.psflabel -text "PSF: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.input.psfpath -width 30 -textvariable ::Solvate::psffile] \
    -row 1 -column 1 -sticky ew
  grid [button $w.input.psfbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Solvate::psffile $tempfile }
    }] -row 1 -column 2 -sticky w
  grid [label $w.input.pdblabel -text "PDB: "] \
    -row 2 -column 0 -sticky w
  grid [entry $w.input.pdbpath -width 30 -textvariable ::Solvate::pdbfile] \
    -row 2 -column 1 -sticky ew
  grid [button $w.input.pdbbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Solvate::pdbfile $tempfile }
    }] -row 2 -column 2 -sticky w
  grid [checkbutton $w.input.water_button -text "Waterbox Only" \
    -variable ::Solvate::waterbox] -row 3 -column 0 -columnspan 3 -sticky w
  grid [checkbutton $w.input.rotate_button -text "Rotate to minimize volume" \
    -variable ::Solvate::rotate] -row 4 -column 0 -columnspan 2 -sticky w
  grid [label $w.input.inclabel -text "Rotation Increment (deg): "] \
    -row 4 -column 1 -sticky e
  grid [entry $w.input.rotinc -width 8 -textvariable ::Solvate::rotinc] \
    -row 4 -column 2 -sticky w
  grid [label $w.input.sellabel -text "Selection for Rotation: "] \
   -row 5 -column 0 -sticky w
  grid [entry $w.input.rotsel -width 20 -textvariable ::Solvate::rotsel] \
    -row 5 -column 1 -sticky w
  grid columnconfigure $w.input 1 -weight 1
  pack $w.input -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.output
  grid [label $w.output.label -text "Output"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [entry $w.output.outpath -width 30 -textvariable ::Solvate::outprefix] \
    -row 1 -column 0 -sticky ew
  grid [button $w.output.outbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Solvate::outprefix $tempfile }
    }] -row 1 -column 1 -sticky w
  grid columnconfigure $w.output 0 -weight 1
  pack $w.output -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.seg
  grid [label $w.seg.seglabel -text "Segment ID Prefix:"] \
    -row 0 -column 0 -sticky w
  grid [entry $w.seg.segentry -width 8 -textvariable ::Solvate::segid] \
    -row 0 -column 1 -sticky ew
  grid [label $w.seg.boundlabel -text "Boundary: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.seg.boundentry -width 8 -textvariable ::Solvate::boundary] \
    -row 1 -column 1 -sticky ew
  grid columnconfigure $w.seg 1 -weight 1
  pack $w.seg -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.minmax
  grid [label $w.minmax.label -text "Box Size:"] \
    -row 0 -column 0 -columnspan 7 -sticky w
  grid [label $w.minmax.minlabel -text "Min: "] -row 1 -column 0 -sticky w
  grid [label $w.minmax.xminlabel -text "x: "] -row 1 -column 1 -sticky w
  grid [entry $w.minmax.xminentry -width 6 -textvar ::Solvate::min(x)] \
    -row 1 -column 2 -sticky ew
  grid [label $w.minmax.yminlabel -text "y: "] -row 1 -column 3 -sticky w
  grid [entry $w.minmax.yminentry -width 6 -textvar ::Solvate::min(y)] \
    -row 1 -column 4 -sticky ew
  grid [label $w.minmax.zminlabel -text "z: "] -row 1 -column 5 -sticky w
  grid [entry $w.minmax.zminentry -width 6 -textvar ::Solvate::min(z)] \
    -row 1 -column 6 -sticky ew
  grid [label $w.minmax.maxlabel -text "Max: "] -row 2 -column 0 -sticky w
  grid [label $w.minmax.xmaxlabel -text "x: "] -row 2 -column 1 -sticky w
  grid [entry $w.minmax.xmaxentry -width 6 -textvar ::Solvate::max(x)] \
    -row 2 -column 2 -sticky ew
  grid [label $w.minmax.ymaxlabel -text "y: "] -row 2 -column 3 -sticky w
  grid [entry $w.minmax.ymaxentry -width 6 -textvar ::Solvate::max(y)] \
    -row 2 -column 4 -sticky ew
  grid [label $w.minmax.zmaxlabel -text "z: "] -row 2 -column 5 -sticky w
  grid [entry $w.minmax.zmaxentry -width 6 -textvar ::Solvate::max(z)] \
    -row 2 -column 6 -sticky ew
  grid [checkbutton $w.minmax.boxbutton -text "Use Molecule Dimensions" \
    -variable ::Solvate::use_mol_box] -row 3 -column 0 -columnspan 7 -sticky w
  ::Solvate::waterbox_state
  grid columnconfigure $w.minmax {2 4 6} -weight 1
  pack $w.minmax -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.padding
  grid [label $w.padding.label -text "Box Padding:"] \
    -row 0 -column 0 -columnspan 7 -sticky w
  grid [label $w.padding.minlabel -text "Min: "] -row 1 -column 0 -sticky w
  grid [label $w.padding.xminlabel -text "x: "] -row 1 -column 1 -sticky w
  grid [entry $w.padding.xminentry -width 6 -textvar ::Solvate::minpad(x)] \
    -row 1 -column 2 -sticky ew
  grid [label $w.padding.yminlabel -text "y: "] -row 1 -column 3 -sticky w
  grid [entry $w.padding.yminentry -width 6 -textvar ::Solvate::minpad(y)] \
    -row 1 -column 4 -sticky ew
  grid [label $w.padding.zminlabel -text "z: "] -row 1 -column 5 -sticky w
  grid [entry $w.padding.zminentry -width 6 -textvar ::Solvate::minpad(z)] \
    -row 1 -column 6 -sticky ew
  grid [label $w.padding.maxlabel -text "Max: "] -row 2 -column 0 -sticky w
  grid [label $w.padding.xmaxlabel -text "x: "] -row 2 -column 1 -sticky w
  grid [entry $w.padding.xmaxentry -width 6 -textvar ::Solvate::maxpad(x)] \
    -row 2 -column 2 -sticky ew
  grid [label $w.padding.ymaxlabel -text "y: "] -row 2 -column 3 -sticky w
  grid [entry $w.padding.ymaxentry -width 6 -textvar ::Solvate::maxpad(y)] \
    -row 2 -column 4 -sticky ew
  grid [label $w.padding.zmaxlabel -text "z: "] -row 2 -column 5 -sticky w
  grid [entry $w.padding.zmaxentry -width 6 -textvar ::Solvate::maxpad(z)] \
    -row 2 -column 6 -sticky ew
  grid columnconfigure $w.padding {2 4 6} -weight 1
  pack $w.padding -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.altsolv
  grid [checkbutton $w.altsolv.usealtsolv -text "Use nonstandard solvent" -variable ::Solvate::usealtsolv] \
    -row 0 -column 0 -columnspan 7 -sticky w
  grid [label $w.altsolv.pdblabel -text "Solvent box PDB: "] -row 1 -column 0 -columnspan 3 -sticky w
  grid [entry $w.altsolv.pdbentry -width 20 -textvar ::Solvate::altsolvpdb] \
    -row 1 -column 3 -columnspan 4 -sticky ew
  grid [label $w.altsolv.psflabel -text "Solvent box PSF: "] -row 2 -column 0 -columnspan 3 -sticky w
  grid [entry $w.altsolv.psfentry -width 20 -textvar ::Solvate::altsolvpsf] \
    -row 2 -column 3 -columnspan 4 -sticky ew
  grid [label $w.altsolv.toplabel -text "Solvent box topology: "] -row 3 -column 0 -columnspan 3 -sticky w
  grid [entry $w.altsolv.topentry -width 20 -textvar ::Solvate::altsolvtop] \
    -row 3 -column 3 -columnspan 4 -sticky ew
  grid [label $w.altsolv.sizelabel -text "Solvent box side length: "] -row 4 -column 0 -columnspan 3 -sticky w
  grid [entry $w.altsolv.sizeentry -width 20 -textvar ::Solvate::altsolvws] \
    -row 4 -column 3 -columnspan 4 -sticky ew
  grid [label $w.altsolv.kslabel -text "Solvent box key selection: "] -row 5 -column 0 -columnspan 3 -sticky w
  grid [entry $w.altsolv.ksentry -width 20 -textvar ::Solvate::altsolvks] \
    -row 5 -column 3 -columnspan 4 -sticky ew
  grid columnconfigure $w.altsolv {2 4 6} -weight 1
  pack $w.altsolv -side top -padx 10 -pady 10 -expand 1 -fill x
  ::Solvate::altsolv_state

  pack [button $w.solvate -text "Solvate" -command ::Solvate::run_solvate] \
    -side top -padx 10 -pady 10 -expand 1 -fill x

 
  return $w
}

# Set up variables before opening the GUI
proc ::Solvate::init_gui {} {
  variable psffile
  variable pdbfile
  variable waterbox
  variable outprefix
  variable segid
  variable boundary
  variable min
  variable max
  variable use_mol_box
  variable minpad
  variable maxpad
  variable rotate

  # 
  # Check if the top molecule has both pdb and psf files loaded: if it does,
  # use those as a default; otherwise, leave these fields blank and create a
  # waterbox.
  #
  set psffile {}
  set pdbfile {}
  set waterbox 1
  set use_mol_box 0
  if {[molinfo num] != 0} {
    foreach filename [lindex [molinfo top get filename] 0] \
            filetype [lindex [molinfo top get filetype] 0] {
      if { [string equal $filetype "psf"] } {
        set psffile $filename
      } elseif { [string equal $filetype "pdb"] } {
        set pdbfile $filename
      }
    }
    # Make sure both a pdb and psf are loaded
    if { $psffile == {} || $pdbfile == {} } {
      set psffile {}
      set pdbfile {}
    } else {
      set waterbox 0
      set use_mol_box 1
    }
  }

  set rotate 0 
  set outprefix "solvate"
  set segid "WT"
  set boundary 2.4
  array set minpad {x 0 y 0 z 0}
  array set maxpad {x 0 y 0 z 0}

  # Add traces to the checkboxes, so various widgets can be disabled
  # appropriately
  if {[llength [trace info variable ::Solvate::waterbox]] == 0} {
    trace add variable ::Solvate::waterbox write ::Solvate::waterbox_state
  }
  if {[llength [trace info variable ::Solvate::use_mol_box]] == 0} {
    trace add variable ::Solvate::use_mol_box write ::Solvate::molbox_state
  }
  if {[llength [trace info variable ::Solvate::rotate]] == 0} {
    trace add variable ::Solvate::rotate write ::Solvate::rotate_state
#    set rotate 0
  }
  if {[llength [trace info variable ::Solvate::usealtsolv]] == 0} {
    trace add variable ::Solvate::usealtsolv write ::Solvate::altsolv_state
  }
}

# Run solvate from the GUI. Assembles a command line and passes it to
# solvate
proc ::Solvate::run_solvate {} {
  variable psffile
  variable pdbfile
  variable waterbox
  variable outprefix
  variable segid
  variable boundary
  variable min
  variable max
  variable use_mol_box
  variable minpad
  variable maxpad
  variable rotate
  variable rotsel
  variable rotinc
  variable usealtsolv
  variable altsolvpdb
  variable altsolvpsf
  variable altsolvtop
  variable altsolvws
  variable altsolvks

  set command_line {}

  if { !$waterbox } {
    if { ($psffile == {}) || ($pdbfile == {} ) } {
      puts "solvate: need file names"
      return
    }
    append command_line [concat $psffile $pdbfile]
  }

  if { $outprefix == {} } {
    puts "solvate: need output filename"
    return
  }
  set command_line [concat $command_line "-o" $outprefix]

  if { $segid == {} } {
    puts "solvate: need segid"
    return
  }
  set command_line [concat $command_line "-s" $segid]

  if { !$use_mol_box } {
    if { ![eval ::Solvate::is_number $min(x)] ||
         ![eval ::Solvate::is_number $min(y)] ||
         ![eval ::Solvate::is_number $min(z)] ||
         ![eval ::Solvate::is_number $max(x)] ||
         ![eval ::Solvate::is_number $max(y)] ||
         ![eval ::Solvate::is_number $max(z)] } {
      puts "solvate: need numeric minmax"
      return
    }
    set command_line [concat $command_line "-minmax" [list [list \
      [list $min(x) $min(y) $min(z)] [list $max(x) $max(y) $max(z)]]]]
  }

  if { $rotate != 0 } {
    set command_line [concat $command_line "-rotate"]
    set command_line [concat $command_line "-rotsel \"" $rotsel "\""]
    set command_line [concat $command_line "-rotinc " $rotinc]
  }

  if { ![eval ::Solvate::is_number $minpad(x)] ||
       ![eval ::Solvate::is_number $minpad(y)] ||
       ![eval ::Solvate::is_number $minpad(z)] ||
       ![eval ::Solvate::is_number $maxpad(x)] ||
       ![eval ::Solvate::is_number $maxpad(y)] ||
       ![eval ::Solvate::is_number $maxpad(z)] } {
    puts "solvate: need numeric padding"
    return
  }
  set command_line [concat $command_line "-x" $minpad(x)]
  set command_line [concat $command_line "-y" $minpad(y)]
  set command_line [concat $command_line "-z" $minpad(z)]
  set command_line [concat $command_line "+x" $maxpad(x)]
  set command_line [concat $command_line "+y" $maxpad(y)]
  set command_line [concat $command_line "+z" $maxpad(z)]

  set command_line [concat $command_line "-b" $boundary]

# Check if we want to use an alternate solvent, and apply it if needed
  if {$usealtsolv} {
    if {$altsolvpdb=="" || $altsolvpsf=="" || $altsolvtop=="" || $altsolvws=="" || $altsolvks==""} {
      error "Missing required information for alternative solvent! Please fill out all fields or uncheck 'Use nonstandard solvent'"
      return
    }
    set command_line [concat $command_line "-spdb" $altsolvpdb]
    set command_line [concat $command_line "-spsf" $altsolvpsf]
    set command_line [concat $command_line "-stop" $altsolvtop]
    set command_line [concat $command_line "-ws" $altsolvws]
    set command_line [concat $command_line "-ks \"$altsolvks\""]
  }


  eval solvate $command_line
}

# Disable or enable widgets according to the current status of the
# "Waterbox Only" checkbutton
proc ::Solvate::waterbox_state {args} {
  variable w
  variable waterbox
  variable use_mol_box

  # Disable the "Use Molecule Dimensions" button and input file fields
  if {$waterbox} {
    set use_mol_box 0
    if {[winfo exists $w.minmax.boxbutton]} {
      $w.minmax.boxbutton configure -state disabled
    }
    if {[winfo exists $w.input]} {
      $w.input.psfpath configure -state disabled
      $w.input.psfbutton configure -state disabled
      $w.input.pdbpath configure -state disabled
      $w.input.pdbbutton configure -state disabled
    }
  } else {
    if {[winfo exists $w.minmax.boxbutton]} {
      $w.minmax.boxbutton configure -state normal
    }
    if {[winfo exists $w.input]} {
      $w.input.psfpath configure -state normal
      $w.input.psfbutton configure -state normal
      $w.input.pdbpath configure -state normal
      $w.input.pdbbutton configure -state normal
    }
  }

}

# Disable the nonstandard solvent section unless we're using an alternate solvent
proc ::Solvate::altsolv_state {args} {
  variable w
  variable usealtsolv

  if {!$usealtsolv} {
    if {[winfo exists $w.altsolv]} {
      $w.altsolv.pdbentry configure -state disabled
      $w.altsolv.psfentry configure -state disabled
      $w.altsolv.topentry configure -state disabled
      $w.altsolv.sizeentry configure -state disabled
      $w.altsolv.ksentry configure -state disabled
    }
  } else {
    if {[winfo exists $w.altsolv]} {
      $w.altsolv.pdbentry configure -state normal
      $w.altsolv.psfentry configure -state normal
      $w.altsolv.topentry configure -state normal
      $w.altsolv.sizeentry configure -state normal
      $w.altsolv.ksentry configure -state normal
    }
  }

}

# Disable or enable widgets according to the current status of the
# "Use Molecule Dimensions" checkbutton
proc ::Solvate::molbox_state {args} {
  variable w
  variable use_mol_box

  # XXX - TODO: Display the molecule box size 
  # disable the boxsize fields if using molecule dimensions.
  if {[winfo exists $w.minmax]} {
    if {$use_mol_box} {
      $w.minmax.xminentry configure -state disabled
      $w.minmax.yminentry configure -state disabled
      $w.minmax.zminentry configure -state disabled
      $w.minmax.xmaxentry configure -state disabled
      $w.minmax.ymaxentry configure -state disabled
      $w.minmax.zmaxentry configure -state disabled
    } else {
      $w.minmax.xminentry configure -state normal
      $w.minmax.yminentry configure -state normal
      $w.minmax.zminentry configure -state normal
      $w.minmax.xmaxentry configure -state normal
      $w.minmax.ymaxentry configure -state normal
      $w.minmax.zmaxentry configure -state normal
    }
  }
}

# Disable or enable widgets according to the current status of the
# "Use Molecule Dimensions" checkbutton
proc ::Solvate::rotate_state {args} {
  variable w
  variable rotate

  if {[winfo exists $w.input]} {
    if {$rotate} {
      $w.input.rotinc configure -state normal
      $w.input.rotsel configure -state normal
    } else {
      $w.input.rotinc configure -state disabled
      $w.input.rotsel configure -state disabled
    }
  }
}

proc ::Solvate::is_number {args} {
  if {[llength $args] != 1} {
    return 0
  }

  set x [lindex $args 0]
  if { ($x == {}) || [catch {expr $x + 0}]} {
    return 0
  } else {
    return 1
  }
}

proc ::Solvate::rotate_save_water {pdbload selection N_rot logfile} {
global bounds

puts "Loading the structure for rotation..."
mol new $pdbload
puts "done"

##################################################
# Set the center to (0 0 0).
##################################################
set A [atomselect top all]
set minus_com [vecsub {0.0 0.0 0.0} [measure center $A]]
$A moveby $minus_com
##################################################

# Set the number of atoms.
set N [$A num]
# some error checking
if {$N <= 0} {
  error "No atoms in the molecule"
}

set B [atomselect top $selection]
set N_B [$B num]
if {$N_B <= 0} {
  error "need a selection with atoms"
}

set tmp [measure minmax $B]
set L_x [expr [lindex [lindex $tmp 1] 0] - [lindex [lindex $tmp 0] 0] + $bounds(-x) + $bounds(+x)]
set L_y [expr [lindex [lindex $tmp 1] 1] - [lindex [lindex $tmp 0] 1] + $bounds(-y) + $bounds(+y)] 
set L_z [expr [lindex [lindex $tmp 1] 2] - [lindex [lindex $tmp 0] 2] + $bounds(-z) + $bounds(+z)]

set V_0 [expr $L_x*$L_y*$L_z]
set kV1 0
set kV2 0
puts "Initial volume is $V_0"

##################################################
# Find the position (using rotations) corresponding to the smallest volume.
##################################################
puts "Rotating the system..."
set d_phi [expr 360.0/$N_rot]
set d_theta [expr 360.0/$N_rot]

for {set k1 1} {$k1 < [expr $N_rot + 1]} {incr k1} {
  $A move [trans axis z $d_phi deg]
  for {set k2 1} {$k2 < [expr $N_rot + 1]} {incr k2} {
    $A move [trans axis x $d_theta deg]

    set tmp [measure minmax $B]
    set L_x [expr [lindex [lindex $tmp 1] 0] - [lindex [lindex $tmp 0] 0] + $bounds(-x) + $bounds(+x)]
    set L_y [expr [lindex [lindex $tmp 1] 1] - [lindex [lindex $tmp 0] 1] + $bounds(-y) + $bounds(+y)]
    set L_z [expr [lindex [lindex $tmp 1] 2] - [lindex [lindex $tmp 0] 2] + $bounds(-z) + $bounds(+z)]
    set V [expr $L_x*$L_y*$L_z]

    if {$V < $V_0} {
      set V_0 $V
      set kV1 $k1
      set kV2 $k2
    }

  }
}
puts "done"
puts ""

##################################################

##################################################
# Make rotations.
##################################################
puts "New volume is $V_0"
puts $logfile "New volume is $V_0"
$A move [trans axis z [expr $kV1*$d_phi] deg]
$A move [trans axis x [expr $kV2*$d_theta] deg]
puts "The system was rotated by [expr $kV1*$d_phi] degrees around Z axis and [expr $kV2*$d_theta] degrees around X axis."
puts $logfile "The system was rotated by [expr $kV1*$d_phi] degrees around Z axis and [expr $kV2*$d_theta] degrees around X axis."
##################################################

$A writepdb $pdbload-rotated-tmp.pdb
}
