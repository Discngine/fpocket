#
# Graphical interface for PME plugin
#
# $Id: pmepot_gui.tcl,v 1.7 2011/03/09 17:14:31 johns Exp $
#
package provide pmepot_gui 1.0.1

namespace eval ::PMEPot::GUI {

  package require pmepot 1.0.4

  namespace export pmepot_gui

  variable nullMolString "none"
  variable currentMol
  variable molMenuButtonText
  trace add variable [namespace current]::currentMol write [namespace code {
    variable currentMol
    variable molMenuButtonText
    if { ! [catch { molinfo $currentMol get name } name ] } {
      set molMenuButtonText "$currentMol: $name"
    } else {
      set molMenuButtonText $currentMol
    }
  # } ]
  set currentMol $nullMolString
  variable usableMolLoaded 0

#  variable default_grid_resolution 1.0
#  variable default_grid_max_dim 512
#  variable default_cell_padding 10.0
#  variable default_ewald_factor 1.0

  variable atomselectText "all"
  variable frames "now"
  variable gridResolution [set [namespace parent]::default_grid_resolution]
  variable gridMaxDim [set [namespace parent]::default_grid_max_dim]
  variable gridA 8
  variable gridB 8
  variable gridC 8
  variable ewaldFactor [set [namespace parent]::default_ewald_factor]
  variable cellPadding [set [namespace parent]::default_cell_padding]
  variable dxFile ""
  variable loadMol "new"
  variable createSlice 1
  variable createSurface 0
  variable allowUnaligned 0
  variable updateSelection 0
  variable cellSet 0

  proc variable_cell { } {
    uplevel {
      variable cellOx
      variable cellOy
      variable cellOz
      variable cellAx
      variable cellAy
      variable cellAz
      variable cellBx
      variable cellBy
      variable cellBz
      variable cellCx
      variable cellCy
      variable cellCz
      variable cellA
      variable cellB
      variable cellC
      variable cellAlpha
      variable cellBeta
      variable cellGamma
      variable allowUnaligned
    }
  }

  proc get_cell { } {
    variable_cell
    return [list \
      [list $cellOx $cellOy $cellOz] \
      [list $cellAx $cellAy $cellAz] \
      [list $cellBx $cellBy $cellBz] \
      [list $cellCx $cellCy $cellCz] \
    ]
  }
  proc get_vmd_cell { } {
    variable_cell
    return [list $cellA $cellB $cellC $cellAlpha $cellBeta $cellGamma]
  }
  proc get_cell_origin { } {
    variable_cell
    return [list $cellOx $cellOy $cellOz]
  }
  proc get_cell_avec { } {
    variable_cell
    return [list $cellAx $cellAy $cellAz]
  }
  proc get_cell_bvec { } {
    variable_cell
    return [list $cellBx $cellBy $cellBz]
  }
  proc get_cell_cvec { } {
    variable_cell
    return [list $cellCx $cellCy $cellCz]
  }

  proc set_cell { cell } {
    variable_cell
    foreach {cellOx cellOy cellOz} [lindex $cell 0] { break }
    foreach {cellAx cellAy cellAz} [lindex $cell 1] { break }
    foreach {cellBx cellBy cellBz} [lindex $cell 2] { break }
    foreach {cellCx cellCy cellCz} [lindex $cell 3] { break }
    cellupdate
  }
  proc cellupdate { } {
    variable_cell
    if { $cellAy == 0. && $cellAz == 0. && $cellBz == 0. } {
      if {[catch {[namespace parent]::make_vmd_cell [get_cell]} vmdcell]} {
        tk_dialog .errmsg {PME Electrostatics Error} "Error updating the cell information:\n$vmdcell" error 0 Dismiss
        return
      }
      foreach {cellA cellB cellC cellAlpha cellBeta cellGamma} $vmdcell {break}
    } else {
      set allowUnaligned 1
    }
    gridupdate
  }

  proc set_vmd_cell { vmdcell } {
    variable_cell
    foreach {cellA cellB cellC cellAlpha cellBeta cellGamma} $vmdcell { break }
    vmdcellupdate
  }
  proc vmdcellupdate { } {
    variable_cell
    set cell [[namespace parent]::make_namd_cell \
                  [get_cell_origin] [get_vmd_cell]]
    foreach {cellOx cellOy cellOz} [lindex $cell 0] { break }
    foreach {cellAx cellAy cellAz} [lindex $cell 1] { break }
    foreach {cellBx cellBy cellBz} [lindex $cell 2] { break }
    foreach {cellCx cellCy cellCz} [lindex $cell 3] { break }
    set allowUnaligned 0
    gridupdate
  }

  proc gridupdate { } {
    variable gridResolution
    variable gridMaxDim
    variable gridA
    variable gridB
    variable gridC
    foreach {gridA gridB gridC} [[namespace parent]::make_grid_from_cell \
      [get_cell] $gridResolution $gridMaxDim] { break }
  }

  variable_cell

  set_cell {{0. 0. 0.} {10. 0. 0.} {0. 10. 0.} {0. 0. 10.}}

  variable debug 1
}

proc pmepot_gui { args } {
  if { [catch { eval ::PMEPot::GUI::pmepot_gui $args } out] } {
    global errorInfo
    puts "$out\n$errorInfo"
    error $out
  } else {
    return $out
  }
}

#####################
# read cell from VMD info
proc ::PMEPot::GUI::vmdsetcell {{errmsg 1}} {
  variable currentMol

  set vmdcell {0.0 0.0 0.0 0.0 0.0 0.0}
  if { [catch {molinfo $currentMol get {a b c alpha beta gamma} } vmdcell ] } {
    if {$errmsg} {
      tk_dialog .errmsg {PME Electrostatics Error} "Could not read cell info:\n$vmdcell" error 0 Dismiss
    }
    return -1
  }
  lassign $vmdcell a b c alpha beta gamma
  if { [expr $a * $b * $c ] < 1.0 } {
    if {$errmsg} {
      tk_dialog .errmsg {PME Electrostatics Error} "Periodic cell information not present for molecule $currentMol" error 0 Dismiss
    }
    return -2
  }
  set_vmd_cell $vmdcell
  return 0
}

#####################
# copy charges from beta field
proc ::PMEPot::GUI::copybtocharge {} {
    variable currentMol
    variable atomselectText

    set sel {}
    if {[catch {atomselect $currentMol "$selstring"} sel] } then {
        tk_dialog .errmsg {PME Electrostatics Error} "There was an error creating the selection:\n$sel" error 0 Dismiss
        return
    }
    $sel set charge [$sel get beta]
    $sel delete
}

#####################
# guess charges via APBSrun (could it be using autopsf???)
proc ::PMEPot::GUI::guesscharge {} {
    variable currentMol
    variable atomselectText

    set errmsg {}
    set sel {}
    if {[catch {package require apbsrun 1.2} errmsg] } {
        tk_dialog .errmsg {PME Electrostatics Error} "Could not load the APBSrun package needed to guess charges:\n$errmsg" error 0 Dismiss
        return
    }
    if {[catch {atomselect $currentMol "$atomselectText"} sel] } then {
        tk_dialog .errmsg {PME Electrostatics Error} "There was an error creating the selection:\n$sel" error 0 Dismiss
        return
    }
    ::APBSRun::set_parameter_charges $sel 
    $sel delete
}

#####################
# read charges from file.
proc ::PMEPot::GUI::readcharge {} {
    variable w
    variable currentMol

    set fname [tk_getOpenFile -defaultextension .dat -initialfile "charges.dat" \
                         -filetypes { { {Generic Data File} {.dat .data} } \
                          { {Generic Text File} {.txt} } \
                          { {All Files} {.*} } } \
                         -title {Load atom name to charge mapping file} -parent $w]
    if {! [string length $fname] } return ; # user has canceled file selection.
    if { ![file exists $fname] || [catch {set fp [open $fname r]} errmsg] } {
        tk_dialog .errmsg {PME Electrostatics Error} "Could not open file $fname for reading:\n$errmsg" error 0 Dismiss
        return
    } else {
        # Load the charges
        while {-1 != [gets $fp line]} {
            if {![regexp {^\s*#} $line]} {
                set line [regexp -all -inline {\S+} $line]
                if {[llength $line] >= 2} {
                    set sel [atomselect $currentMol "name [lindex $line 0]"]
                    $sel set charge [lindex $line 1]
                    $sel delete
                }
            }
        }
        close $fp
    }
}

proc ::PMEPot::GUI::pmepot_gui {} {
  variable w

  if { [winfo exists .pmepot] } {
    wm deiconify .pmepot
    return
  }
  set w [toplevel ".pmepot"]
  wm title $w "PME Electrostatics"

  variable nullMolString
  variable currentMol

  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -side top -padx 1 -fill x
  menubutton $w.menubar.util -text Utilities -underline 0 -menu $w.menubar.util.menu
  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.util config -width 8
  $w.menubar.help config -width 5

  # Utilities menu.
  menu $w.menubar.util.menu -tearoff no
  $w.menubar.util.menu add command -label "Guess atomic charges from CHARMM parameters." \
                         -command ::PMEPot::GUI::guesscharge
  $w.menubar.util.menu add command -label "Load name<->charge map from file." \
                         -command ::PMEPot::GUI::readcharge
  $w.menubar.util.menu add command -label "Copy charges from beta field." \
                         -command ::PMEPot::GUI::copybtocharge

  # Help menu.
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
             -command {tk_messageBox -type ok -title "About PME Electrostatics" \
                              -message "The 'pmepot' plugin evaluates the reciprocal sum of the smooth particle-mesh Ewald method (PME), producing a smoothed electrostatic potential grid, and writes it to a DX file, and reads it into the molecule."}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/pmepot"
  pack $w.menubar.util -side left
  pack $w.menubar.help -side right

  set f [frame $w.all]
  set row 0

  grid [label $f.mollable -text "Molecule: "] \
    -row $row -column 0 -sticky e
  grid [menubutton $f.mol -textvar [namespace current]::molMenuButtonText \
    -menu $f.mol.menu -relief raised] \
    -row $row -column 1 -columnspan 3 -sticky ew
  menu $f.mol.menu -tearoff no
  incr row

  grid [label $f.sellabel -text "Selection: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.sel -width 30 \
    -textvariable [namespace current]::atomselectText] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [label $f.padlabel -text "Not Periodic: "] \
    -row $row -column 0 -sticky e
  grid [label $f.padcomment -text "Pad By: "] \
    -row $row -column 1 -sticky e
  grid [entry $f.pad -width 10 \
    -textvariable [namespace current]::cellPadding] \
    -row $row -column 2 -sticky ew
  grid [button $f.padbutton -text "Enclose" \
    -command [namespace code {
      variable currentMol
      variable cellPadding
      variable atomselectText
      set sel [atomselect $currentMol $atomselectText]
      set err [catch {[namespace parent]::make_padded_cell \
				 $currentMol $cellPadding $sel} cell]
      $sel delete
      if { $err } { error $cell } else { set_cell $cell }
    # } ] ] \
    -row $row -column 3 -sticky ew
  incr row

  grid [label $f.fromlabel -text "Cell From: "] \
    -row $row -column 0 -sticky e
  grid [button $f.vmdbutton -text "VMD Info" \
    -command ::PMEPot::GUI::vmdsetcell ] -row $row -column 1 -sticky ew
  grid [button $f.xscbutton -text "NAMD .xsc File" \
    -command [namespace code {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} {
        if { [catch {[namespace parent]::read_xsc_file $tempfile} newcell] } {
          tk_messageBox -type ok -title $newcell -message $errorInfo
          return
        }
        set_cell $newcell
      }
    }]] -row $row -column 2 -columnspan 2 -sticky ew
  incr row

  grid [label $f.olabel -text "Origin: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.ox -width 10 -textvariable [namespace current]::cellOx] \
    -row $row -column 1 -sticky ew
  grid [entry $f.oy -width 10 -textvariable [namespace current]::cellOy] \
    -row $row -column 2 -sticky ew
  grid [entry $f.oz -width 10 -textvariable [namespace current]::cellOz] \
    -row $row -column 3 -sticky ew
  incr row

  grid [label $f.lengthlabel -text "Lengths: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.alen -width 10 -textvariable [namespace current]::cellA] \
    -row $row -column 1 -sticky ew
  grid [entry $f.blen -width 10 -textvariable [namespace current]::cellB] \
    -row $row -column 2 -sticky ew
  grid [entry $f.clen -width 10 -textvariable [namespace current]::cellC] \
    -row $row -column 3 -sticky ew
  incr row
  grid [label $f.anglelabel -text "Angles: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.alpha -width 10 -textvariable [namespace current]::cellAlpha] \
    -row $row -column 1 -sticky ew
  grid [entry $f.beta -width 10 -textvariable [namespace current]::cellBeta] \
    -row $row -column 2 -sticky ew
  grid [entry $f.gamma -width 10 -textvariable [namespace current]::cellGamma] \
    -row $row -column 3 -sticky ew
  incr row

  grid [label $f.alabel -text "A Vector: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.ax -width 10 -textvariable [namespace current]::cellAx] \
    -row $row -column 1 -sticky ew
  grid [entry $f.ay -width 10 -textvariable [namespace current]::cellAy] \
    -row $row -column 2 -sticky ew
  grid [entry $f.az -width 10 -textvariable [namespace current]::cellAz] \
    -row $row -column 3 -sticky ew
  incr row
  grid [label $f.blabel -text "B Vector: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.bx -width 10 -textvariable [namespace current]::cellBx] \
    -row $row -column 1 -sticky ew
  grid [entry $f.by -width 10 -textvariable [namespace current]::cellBy] \
    -row $row -column 2 -sticky ew
  grid [entry $f.bz -width 10 -textvariable [namespace current]::cellBz] \
    -row $row -column 3 -sticky ew
  incr row
  grid [label $f.clabel -text "C Vector: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.cx -width 10 -textvariable [namespace current]::cellCx] \
    -row $row -column 1 -sticky ew
  grid [entry $f.cy -width 10 -textvariable [namespace current]::cellCy] \
    -row $row -column 2 -sticky ew
  grid [entry $f.cz -width 10 -textvariable [namespace current]::cellCz] \
    -row $row -column 3 -sticky ew
  incr row

  grid [checkbutton $f.align -text "Allow Unaligned Cells" \
    -variable [namespace current]::allowUnaligned] \
    -row $row -column 1 -columnspan 3 -sticky w
  trace add variable [namespace current]::allowUnaligned write [namespace code "
    variable allowUnaligned
    if { \$allowUnaligned } {
      set s1 normal; set s2 disabled
    } {
      set s1 disabled; set s2 normal
      variable cellAy 0
      variable cellAz 0
      variable cellBz 0
      cellupdate
    }
    foreach field {ay az bz} \{ $f.\$field configure -state \$s1 \}
    foreach field {alen blen clen alpha beta gamma} \{ $f.\$field configure -state \$s2 \}
  # " ]
  variable allowUnaligned
  set allowUnaligned $allowUnaligned
  incr row

  grid [label $f.reslabel -text "Resolution: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.res -width 10 \
    -textvariable [namespace current]::gridResolution] \
    -row $row -column 1 -sticky ew
  grid [label $f.rescomment -text "(A per grid point)"] \
    -row $row -column 2 -columnspan 2 -sticky w
  incr row

  grid [label $f.maxlabel -text "Max Size: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.max -width 10 \
    -textvariable [namespace current]::gridMaxDim] \
    -row $row -column 1 -sticky ew
  grid [label $f.maxcomment -text "(for any dimension)"] \
    -row $row -column 2 -columnspan 2 -sticky w
  incr row

  grid [label $f.numlabel -text "Grid Sizes: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.a -width 10 -textvariable [namespace current]::gridA] \
    -row $row -column 1 -sticky ew
  grid [entry $f.b -width 10 -textvariable [namespace current]::gridB] \
    -row $row -column 2 -sticky ew
  grid [entry $f.c -width 10 -textvariable [namespace current]::gridC] \
    -row $row -column 3 -sticky ew
  incr row

  grid [label $f.factorlabel -text "Ewald Factor: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.factor -width 10 \
    -textvariable [namespace current]::ewaldFactor] \
    -row $row -column 1 -sticky ew
  grid [label $f.factorcomment -text "(Gaussian sharpness, 1/A)"] \
    -row $row -column 2 -columnspan 2 -sticky w
  incr row

  grid [label $f.frameslabel -text "Avg Frames: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.frames -width 10 \
    -textvariable [namespace current]::frames] \
    -row $row -column 1 -sticky ew
  grid [label $f.framescomment -text "(now, all, b:e, or b:s:e)"] \
    -row $row -column 2 -columnspan 2 -sticky w
  incr row

  grid [checkbutton $f.updatesel -text "Update Selection for Each Frame" \
    -variable [namespace current]::updateSelection] \
    -row $row -column 1 -columnspan 3 -sticky w
  incr row

  grid [label $f.dxlabel -text "Output File: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.dxfile -width 20 \
    -textvariable [namespace current]::dxFile] \
    -row $row -column 1 -columnspan 2 -sticky ew
  grid [label $f.dxcomment -text "(.dx, optional)"] \
    -row $row -column 3 -sticky w
  incr row

  grid [label $f.loadlabel -text "Load Into: "] \
    -row $row -column 0 -sticky e
  grid [radiobutton $f.loadnew -value "new" -text "new" \
    -variable [namespace current]::loadMol] \
    -row $row -column 1 -sticky w
  grid [radiobutton $f.loadsame -value "same" -text "same" \
    -variable [namespace current]::loadMol] \
    -row $row -column 2 -sticky w
  grid [radiobutton $f.loadnone -value "none" -text "none" \
    -variable [namespace current]::loadMol \
    -command [namespace code {
      variable dxFile
      if { [string equal $dxFile ""] } {
        set dxFile [[namespace parent]::tempfile "pmedx_"]
      }
    }] ] -row $row -column 3 -sticky w
  incr row

  grid [label $f.createlabel -text "Create New: "] \
    -row $row -column 0 -sticky e
  set f2 [frame $f.create -border 1]
  pack [checkbutton $f2.slice -text "Volume Slice" \
    -variable [namespace current]::createSlice] \
    -side left -padx 0 -pady 0
  pack [checkbutton $f2.surface -text "Isosurface" \
    -variable [namespace current]::createSurface] \
    -side right -padx 0 -pady 0
  grid $f2 -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [button $f.button -text "Run PME" \
    -command [namespace code {
        variable currentMol
        variable atomselectText
        variable frames
        variable updateSelection
        variable gridA
        variable gridB
        variable gridC
        variable ewaldFactor
        variable dxFile
        variable loadMol
        variable createSlice
        variable createSurface
        if { [string equal $loadMol "none"] && [string equal $dxFile ""] } {
          set dxFile [[namespace parent]::tempfile "pmedx_"]
          tk_messageBox -type ok -title "Configuration Error" \
            -message "Output file must be provided when not loading data."
          return
        }
        if { [catch {
          set sel [atomselect $currentMol "($atomselectText) and charge != 0"]
          if { [$sel num] == 0 } { error "no atoms with charges in selection" }
          if { $updateSelection } { set updatesel yes } { set updatesel no }
          set args [list -sel $sel -cell [get_cell] -loadmol $loadMol \
            -grid [list $gridA $gridB $gridC] -ewaldfactor $ewaldFactor \
            -frames $frames -updatesel $updatesel]
          if { ! [string equal "" $dxFile] } { lappend args -dxfile $dxFile }
          set repMol [eval [namespace parent]::pmepot $args]
          $sel delete
        } errMsg ] } {
          catch {$sel delete}
          tk_messageBox -type ok -title $errMsg -message $errorInfo
          return
        }
        if { ! [string equal $loadMol "none"] } {
          if { ! [string equal $repMol $currentMol] } {
            mol delrep 0 $repMol
          }
          if { $createSlice } {
            mol representation VolumeSlice 0.5 0. 2. 0.
            mol color Volume 0
            mol selection {none}
            mol material Opaque
            mol addrep $repMol
          }
          if { $createSurface } {
            mol representation Isosurface 0. 0. 2. 2. 1
            mol color Volume 0
            mol selection {none}
            mol material Opaque
            mol addrep $repMol
          }
        }
    }]] -row $row -column 1 -columnspan 3 -sticky ew

  pack $f -side top -padx 0 -pady 10 -expand 1 -fill x

  foreach event {<FocusOut> <KeyRelease-Return> <KeyRelease-KP_Enter>} {
    foreach field {ox oy oz ax ay az bx by bz cx cy cz} {
      bind $w.all.$field $event +[namespace current]::cellupdate
    }
    foreach field {alen blen clen alpha beta gamma} {
      bind $w.all.$field $event +[namespace current]::vmdcellupdate
    }
    foreach field {res max} {
      bind $w.all.$field $event +[namespace current]::gridupdate
    }
  }
  foreach event {<KeyRelease-Return> <KeyRelease-KP_Enter>} {
    foreach field {pad} {
      bind $w.all.$field $event "+\
        $w.all.padbutton configure -relief sunken; \
        $w.all.padbutton flash; \
        $w.all.padbutton invoke; \
        $w.all.padbutton configure -relief raised"
    }
  }

  # this is here because default cell invokes buttons
  fill_mol_menu $f.mol.menu
  trace add variable ::vmd_initialize_structure write [namespace code "
    fill_mol_menu $f.mol.menu
  # " ]

  return $w
}

proc ::PMEPot::GUI::set_default_cell { } {
#  catch {
    variable w
    variable currentMol
    variable cellPadding
    variable cellSet
    if { $cellSet } { return }
    set cellSet 1
    if {[vmdsetcell 0] == 0 } { return }
    if {! [catch "$w.all.padbutton invoke"]} { return }
#  }
}

proc ::PMEPot::GUI::fill_mol_menu {name} {

  variable usableMolLoaded
  variable currentMol
  variable nullMolString
  $name delete 0 end

  set molList ""
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      lappend molList $mm
      $name add radiobutton -variable [namespace current]::currentMol \
        -command [namespace current]::set_default_cell \
        -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
      set currentMol [molinfo top]
      set_default_cell
      set usableMolLoaded 1
    } else {
      set currentMol $nullMolString
      set usableMolLoaded  0
    }
  }

}


