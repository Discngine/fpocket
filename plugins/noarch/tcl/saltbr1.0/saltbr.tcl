# saltbr - finds salt bridges in a trajectory
# 
# Authors:
#     Leonardo Trabuco (ltrabuco@ks.uiuc.edu)
#     Elizabeth Villa (villa@ks.uiuc.edu)

#
# TODO:
#
# - store salt bridges and show in the gui
# 
#   * the user will be able to select some salt bridges and print only those
#   * the user will be able to create/manipulate reps based on this list
#
# - use multiplot

package provide saltbr 1.0

namespace eval ::saltbr:: {
  namespace export saltbr

  variable defaultCOMDist none
  variable defaultONDist 3.2
  variable defaultWriteAll 1
  variable defaultFrames "all"
  variable defaultOutdir
  variable defaultLogFile ""
  variable defaultUpdateSel 1
  variable debug 0
  variable currentMol none
  variable atomselectText "protein"
  variable statusMsg ""
}

proc ::saltbr::saltbr_gui {} {
  variable defaultCOMDist
  variable defaultONDist
  variable defaultWriteAll
  variable defaultFrames
  variable defaultLogFile
  variable defaultUpdateSel
  variable w
  
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
  
  variable atomselectText "protein"
  
  # If already initialized, just turn on
  if { [winfo exists .saltbr] } {
    wm deiconify $w
    return
  }
  set w [toplevel ".saltbr"]
  wm title $w "Salt Bridges"
  wm resizable $w 0 0

  variable statusMsg "Ready."
  variable guiCOMDist $defaultCOMDist
  variable guiONDist $defaultONDist
  variable guiWriteAll $defaultWriteAll
  variable guiFrames $defaultFrames
  variable guiLogFile $defaultLogFile
  variable guiUpdateSel $defaultUpdateSel
  variable guiOutdir [pwd]

  # Add a menu bar
  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

  # Help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About Saltbr" \
    -message "The Salt Bridges plugin searches for salt bridges in a protein throughout a trajectory. The search can be restricted to a selection and/or a frame range given by the user."}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/saltbr"

  pack $w.menubar.help -side right

  ############## frame for input options #################
  labelframe $w.in -bd 2 -relief ridge -text "Input options" -padx 1m -pady 1m
  
  set f [frame $w.in.all]
  set row 0
  
  grid [label $f.mollable -text "Molecule: "] \
    -row $row -column 0 -sticky e
  grid [menubutton $f.mol -textvar [namespace current]::molMenuButtonText \
    -menu $f.mol.menu -relief raised] \
    -row $row -column 1 -columnspan 3 -sticky ew
  menu $f.mol.menu -tearoff no
  incr row
  
  fill_mol_menu $f.mol.menu
  trace add variable ::vmd_initialize_structure write [namespace code "
    fill_mol_menu $f.mol.menu
  # " ]

  grid [label $f.sellabel -text "Selection: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.sel -width 50 \
    -textvariable [namespace current]::atomselectText] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [label $f.frameslabel -text "Frames: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.frames -width 10 \
    -textvariable [namespace current]::guiFrames] \
    -row $row -column 1 -sticky ew
  grid [label $f.framescomment -text "(now, all, b:e, or b:s:e)"] \
    -row $row -column 2 -columnspan 2 -sticky w
  incr row

  grid [checkbutton $f.check -text \
    "Update selections every frame" \
    -variable [namespace current]::guiUpdateSel] \
    -row $row -column 0 -columnspan 4 -sticky w
  incr row

  pack $f -side top -padx 0 -pady 0 -expand 1 -fill x

  set f [frame $w.in.cutoffs]
  set row 0
  grid [label $f.ondistlabel -text "Oxygen-nitrogen distance cut-off (A): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.ondist -width 5 \
    -textvariable [namespace current]::guiONDist] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [label $f.comdistlabel -text "Side-chain COM distance cut-off (A): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.comdist -width 5 \
    -textvariable [namespace current]::guiCOMDist] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $w.in -side top -pady 5 -padx 3 -fill x -anchor w

  ############## frame for output options #################
  labelframe $w.out -bd 2 -relief ridge -text "Output options" -padx 1m -pady 1m

  set f [frame $w.out.all]
  set row 0
  grid [checkbutton $f.check -text \
    "Write a file with the distances for each salt bridge" \
    -variable [namespace current]::guiWriteAll] \
    -row $row -column 0 -columnspan 3 -sticky w
  incr row
  grid [label $f.label -text "Output directory: "] \
    -row $row -column 0 -columnspan 1 -sticky e
  grid [entry $f.entry -textvariable [namespace current]::guiOutdir \
    -width 35 -relief sunken -justify left -state readonly] \
    -row $row -column 1 -columnspan 1 -sticky e
  grid [button $f.button -text "Choose" -command "::saltbr::getoutdir"] \
    -row $row -column 2 -columnspan 1 -sticky e
  incr row
  grid [label $f.loglabel -text "Log file: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.logname -width 30 \
    -textvariable [namespace current]::guiLogFile] \
    -row $row -column 1 -columnspan 2 -sticky ew

  pack $f -side left -padx 0 -pady 5 -expand 1 -fill x
  pack $w.out -side top -pady 5 -padx 3 -fill x -anchor w

  ############## frame for status #################
  labelframe $w.status -bd 2 -relief ridge -text "Status" -padx 1m -pady 1m

  set f [frame $w.status.all]
  label $f.label -textvariable [namespace current]::statusMsg
  pack $f $f.label
  pack $w.status -side top -pady 5 -padx 3 -fill x -anchor w

  set f [frame $w.control]
  button $f.button -text "Find salt bridges" -width 20 \
    -command {::saltbr::saltbr -gui 1 -ondist $::saltbr::guiONDist -comdist $::saltbr::guiCOMDist -writefiles $::saltbr::guiWriteAll -outdir $::saltbr::guiOutdir -frames $::saltbr::guiFrames -log $::saltbr::guiLogFile -upsel $::saltbr::guiUpdateSel}
  pack $f $f.button

}

# Adapted from pmepot gui
proc ::saltbr::fill_mol_menu {name} {

  variable usableMolLoaded
  variable currentMol
  variable nullMolString
  $name delete 0 end

  set molList ""
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      lappend molList $mm
      $name add radiobutton -variable [namespace current]::currentMol \
        -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
      set currentMol [molinfo top]
      set usableMolLoaded 1
    } else {
      set currentMol $nullMolString
      set usableMolLoaded  0
    }
  }

}

proc ::saltbr::getoutdir {} {
  variable guiOutdir

  set newdir [tk_chooseDirectory \
    -title "Choose output directory" \
    -initialdir $guiOutdir -mustexist true]

  if {[string length $newdir] > 0} {
    set guiOutdir $newdir 
  } 
}

proc saltbr { args } { return [eval ::saltbr::saltbr $args] }
proc saltbrgui { } { return [eval ::saltbr::saltbr_gui] }

proc ::saltbr::saltbr_usage { } {

  variable defaultCOMDist
  variable defaultONDist
  variable defaultWriteAll
  variable defaultFrames

  puts "Usage: saltbr -sel <atom selection> <option1> <option2> ..."
  #puts "  -sel <atom selection> (default: \[atomselect top protein\])"
  puts "Options:"
  puts "  -upsel <yes|no> (update atom selections every frame? default: yes)"
  puts "  -frames <begin:end> or <begin:step:end> or all or now (default: $defaultFrames)"
  puts "  -ondist <cutoff distance between oxygen and nitrogen atoms> (default: $defaultONDist)"
  puts "  -comdist <cutoff distance between centers of mass of side chains> (default: $defaultCOMDist)"
  puts "  -writefiles <yes|no> (default: yes)"
  puts "  -outdir <output directory> (default: current)"
  puts "  -log <log filename> (default: none)"
  return
}

proc ::saltbr::saltbr { args } {

  variable defaultCOMDist
  variable defaultONDist
  variable defaultFrames
  variable defaultWriteAll
  variable defaultFrames
  variable defaultUpdateSel
  variable currentMol
  variable atomselectText
  variable debug
  variable log
  variable statusMsg
  
  variable defaultOutdir [pwd]

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      saltbr_usage
      error ""
    }
    if { $nargs % 2 } {
      saltbr_usage
        error "error: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -sel { set arg(sel) $val }
      -upsel { set arg(upsel) $val }
      -frames { set arg(frames) $val }
      -comdist { set arg(comdist) $val }
      -ondist { set arg(ondist) $val }
      -writefiles { set arg(writefiles) $val }
      -outdir { set arg(outdir) $val }
      -log { set arg(log) $val }
      -gui { set arg(gui) $val }
      -debug { set arg(debug) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  # was I called by the gui?
  if [info exists arg(gui)] {
      set gui 1
  } else {
      set gui 0
  }

  # debug flag
  if [info exists arg(debug)] {
      set debug 1
  }

  # outdir
  if [info exists arg(outdir)] {
    set outdir $arg(outdir)
  } else {
    set outdir $defaultOutdir
  }
  if { ![file isdirectory $outdir] } {
    error "$outdir is not a directory."
  }

  # log file
  if { [info exists arg(log)] && $arg(log) != "" } {
    set log [open [file join $outdir $arg(log)] w]
  } else {
    set log "stdout"
  }

  # get selection
  if [info exists arg(sel)] {
	  set sel $arg(sel)
	  set molid [$sel molid]
  } elseif $gui {
    if { $currentMol == "none" } {
      error "No molecules were found."
    } else {
      set molid $currentMol
	    set sel [atomselect $currentMol $atomselectText]
    }
  } else {
    saltbr_usage
    error "No atomselection was given."
  }

  # update selections?
  if [info exists arg(upsel)] {
    if { $arg(upsel) == "no" || $arg(upsel) == 0 } {
      set updateSel 0
    } elseif { $arg(upsel) == "yes" || $arg(upsel) == 1 } {
      set updateSel 1
    } else {
      error "error: bad argument for option -upsel $arg(upsel): acceptable arguments are 'yes' or 'no'"
    }
  } else {
    set updateSel $defaultUpdateSel
  }

  # get frames
  set nowframe [molinfo $molid get frame]
  set lastframe [expr [molinfo $molid get numframes] - 1]
  if { ! [info exists arg(frames)] } { set arg(frames) $defaultFrames }
  if [info exists arg(frames)] {
    set fl [split $arg(frames) :]
    switch -- [llength $fl] {
      1 {
        switch -- $fl {
          all {
            set frames_begin 0
            set frames_end $lastframe
          }
          now {
            set frames_begin $nowframe
          }
          last {
            set frames_begin $lastframe
          }
          default {
            set frames_begin $fl
          }
        }
      }
      2 {
        set frames_begin [lindex $fl 0]
        set frames_end [lindex $fl 1]
      }
      3 {
        set frames_begin [lindex $fl 0]
        set frames_step [lindex $fl 1]
        set frames_end [lindex $fl 2]
      }
      default { error "bad -frames arg: $arg(frames)" }
    }
  } else {
    set frames_begin 0
  }
  if { ! [info exists frames_step] } { set frames_step 1 }
  if { ! [info exists frames_end] } { set frames_end $lastframe }
    switch -- $frames_end {
      end - last { set frames_end $lastframe }
  }
  if { [ catch {
    if { $frames_begin < 0 } {
      set frames_begin [expr $lastframe + 1 + $frames_begin]
    }
    if { $frames_end < 0 } {
      set frames_end [expr $lastframe + 1 + $frames_end]
    }
    if { ! ( [string is integer $frames_begin] && \
      ( $frames_begin >= 0 ) && ( $frames_begin <= $lastframe ) && \
	  [string is integer $frames_end] && \
  	  ( $frames_end >= 0 ) && ( $frames_end <= $lastframe ) && \
  	  ( $frames_begin <= $frames_end ) && \
  	  [string is integer $frames_step] && ( $frames_step > 0 ) ) } {
        error
      }
  } ok ] } { error "bad -frames arg: $arg(frames)" }
  if $debug {
    puts $log "frames_begin: $frames_begin"
    puts $log "frames_step: $frames_step"
    puts $log "frames_end: $frames_end"
    flush $log
  }
    
  # get COMDist
  if [info exists arg(comdist)] {
    set COMDist $arg(comdist)
  } else {
    set COMDist $defaultCOMDist
  }

  # get ONDIst
  if [info exists arg(ondist)] {
    set ONDist $arg(ondist)
  } else {
    set ONDist $defaultONDist
  }

  # write files?
  if [info exists arg(writefiles)] {
    if { $arg(writefiles) == "no" || $arg(writefiles) == 0 } {
      set writefiles 0
    } elseif { $arg(writefiles) == "yes" || $arg(writefiles) == 1 } {
      set writefiles 1
    } else {
      error "error: bad argument for option -writefiles $arg(writefiles): acceptable arguments are 'yes' or 'no'"
    }
  } else {
    set writefiles $defaultWriteAll
  }

  # print name, version and date of plugin
  puts $log "Salt Bridges Plugin, Version 1.0"
  puts $log "[clock format [clock scan now]]\n"
  puts $log "Parameters used in the calculation of salt bridges:"
  puts $log "- Atomselection: [$sel text]"
  if $updateSel {
    puts $log "- Update selections every frame: yes"
  } else {
    puts $log "- Update selections every frame: no"
  }
  puts $log "- Initial frame: $frames_begin"
  puts $log "- Frame step: $frames_step"
  puts $log "- Final frame: $frames_end"
  puts $log "- Oxygen-nitrogen cut-off: $ONDist"
  puts $log "- Center of mass cut-off: $COMDist"
  if $writefiles {
    puts $log "- Write a file for each salt bridge: yes"
  } else {
    puts $log "- Write a file for each salt bridge: no"
  }
  puts $log ""
  flush $log
  
  # pairs is an associative array containing the salt bridges
  findSaltBridges $sel $updateSel $COMDist $ONDist $frames_begin $frames_step $frames_end pairs idpairs
  if { $writefiles == 1 } {
    printSaltBridges $molid $frames_begin $frames_step $frames_end pairs idpairs $outdir
  }

  # delete the selection if it was created here
  if { ![info exists arg(sel)] } {
    $sel delete
  }

  if { $log != "stdout" } {
      close $log
  }

  set statusMsg "Done."
  update

  return

}

proc ::saltbr::findSaltBridges { selection updateSel COMDist ONDist frames_begin frames_step frames_end pairsName idpairsName } {

  variable debug
  variable statusMsg
  variable log

  if $debug {
    puts $log "updateSel = $updateSel"
  }

  upvar $pairsName finalPairs
  upvar $idpairsName idPairs

  set molid [$selection molid]
  set seltext [$selection text]

  set acsel [atomselect $molid "(protein and acidic and oxygen and not backbone) and $seltext"]
  set basel [atomselect $molid "(protein and basic and nitrogen and not backbone) and $seltext"]

  if { [$acsel num] == 0 || [$basel num] == 0 } {
    if { [$acsel num] == 0 } {
      set errMsg "No oxygens of acidic amino acid residues were found in the given selection."
    }
    if { [$basel num] == 0 } {
      append errMsg "\nNo nitrogens of basic amino acid residues were found in the given selection."
    }
    error $errMsg
  }

  set statusMsg "Searching for ion-pairs with oxygen-nitrogen distance\nwithin $ONDist Angstroms in the selected frames... "
  set statusMsg2 "Searching for ion-pairs with oxygen-nitrogen distance within $ONDist Angstroms in the selected frames... "
  update
  puts -nonewline $log $statusMsg2
  flush $log

  for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {
    $acsel frame $f
    $basel frame $f
    if $updateSel {
      $acsel update
      $basel update
    }
    set tmpList [measure contacts $ONDist $acsel $basel] 
      foreach i [lindex $tmpList 0] j [lindex $tmpList 1] {
        set potPairs($i,$j) 1
      }
  }
  append statusMsg "Done."
  puts $log "Done."
  flush $log

  # Remove redundancies in the list of salt bridges
  set statusMsg "Removing redundancies in the ion-pairs found... "
  update
  puts -nonewline $log $statusMsg
  flush $log
  foreach pair [array names potPairs] {
    
    foreach { ac ba } [split $pair ,] break

    set refAc [atomselect $molid "same residue as index $ac"]
    set refBa [atomselect $molid "same residue as index $ba"]
    set refAcIndex [lindex [$refAc list] 0]
    set refBaIndex [lindex [$refBa list] 0]
    $refAc delete
    $refBa delete

    if [info exists refPotPairs($refAcIndex,$refBaIndex)] {
      unset potPairs($ac,$ba)
    } else {
      set refPotPairs($refAcIndex,$refBaIndex) 1
    }

  }
  append statusMsg "Done."
  puts $log "Done."
  flush $log

  $acsel delete
  $basel delete


  if { $COMDist == "none" } {
    foreach key [array names potPairs] {
	    set finalPairs($key) $potPairs($key)
    }
  } else {
    set statusMsg "Selecting ion-pairs whose side chains' centers of mass\nare within $COMDist Angstroms... "
    set statusMsg2 "Selecting ion-pairs whose side chains' centers of mass are within $COMDist Angstroms... "
    update
    puts -nonewline $log $statusMsg2
    flush $log
    
    set aclist [list]
    set balist [list]
    foreach pair [array names potPairs] {
  
      foreach {ac ba} [split $pair ,] break
      
      # select heavy atoms of the side chains
      set acsel [atomselect $molid "not backbone and noh and same residue as index $ac"]
      set basel [atomselect $molid "not backbone and noh and same residue as index $ba"]
            
      for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {
        $acsel frame $f
        $basel frame $f
        if $updateSel {
          $acsel update
          $basel update
        }
    
        # find the center of mass of each side-chain
        set accenter [measure center $acsel weight mass]
        set bacenter [measure center $basel weight mass]

        if { [veclength [vecsub $accenter $bacenter]] <= $COMDist } {
	  lappend aclist $ac
          lappend balist $ba
          break
        }
      }
            
      $acsel delete
      $basel delete
    }

    foreach ac $aclist ba $balist {
      set finalPairs($ac,$ba) 1
    }

    append statusMsg "Done."
    puts $log "Done."
    flush $log

  }

  # extract identification of each pairs and store in idPairs
  set statusMsg "Extracting identification of each salt bridge... "
  update
  puts -nonewline $log $statusMsg
  flush $log

  set useChain 0
  set useSegname 0
  set extractId 1

  while { $extractId != 0 } {

    set extractId 0

    foreach pair [array names finalPairs] {
  
      foreach {ac ba} [split $pair ,] break
  
      # select heavy atoms of the side chains
      set acsel [atomselect $molid "not backbone and noh and same residue as index $ac"]
      set basel [atomselect $molid "not backbone and noh and same residue as index $ba"]
      set acseloxy [atomselect $molid "not backbone and oxygen and same residue as index $ac"]
      set baselnit [atomselect $molid "not backbone and nitrogen and same residue as index $ba"]
          
      # get resid, chain, and segname
      set acresid [lsort -unique [$acsel get resid]]
      set acresname [lsort -unique [$acsel get resname]]
      set acchain [lsort -unique [$acsel get chain]]
      set acsegname [lsort -unique [$acsel get segname]]
      set baresid [lsort -unique [$basel get resid]]
      set baresname [lsort -unique [$basel get resname]]
      set bachain [lsort -unique [$basel get chain]]
      set basegname [lsort -unique [$basel get segname]]
         
      set seltext "protein and not backbone and noh"
      set acid "$acresname$acresid"
      set baid "$baresname$baresid"

      # use chain in the identification?
      set acseltest [atomselect $molid "$seltext and resid $acresid"]
      if { $useChain != 0 && $acchain != 0 } {
        append acid "_chain$acchain"
      } elseif { [$acsel num] != [$acseltest num] && $acchain != 0 } {
        set useChain 1
        set extractId 1
        break
      }
      $acseltest delete

      # use segname in the identification?
      set acseltest [atomselect $molid "$seltext and resid $acresid and chain $acchain"]
      if { $useSegname != 0 && $acsegname != 0 && $acsegname != "{}" } {
        append acid "_segname$acsegname"
      } elseif { [$acsel num] != [$acseltest num] && $acsegname != 0 && $acsegname != "{}" } {
        set useSegname 1
        set extractId 1
        break
      }
      $acseltest delete

      # is this enough to identify the residue?
      if { $useChain != 0 && $useSegname != 0 } {
        set acseltest [atomselect $molid "$seltext and resid $acresid and chain $acchain and segname $acsegname"]
      } elseif { $useChain != 0 } {
        set acseltest [atomselect $molid "$seltext and resid $acresid and chain $acchain"]
      } elseif { $useSegname != 0 } {
        set acseltest [atomselect $molid "$seltext and resid $acresid and segname $acsegname"]
      } else {
        set acseltest [atomselect $molid "$seltext and resid $acresid"]
      }
      if { [$acsel num] != [$acseltest num] } {
        set statusMsg "\nWarning: the identification $acid is not unique."
        update
        puts $log $statusMsg
        flush $log
      }
      $acseltest delete

      # use chain in the identification?
      set baseltest [atomselect $molid "$seltext and resid $baresid"]
      if { $useChain != 0 && $bachain != 0 } {
        append baid "_chain$bachain"
      } elseif { [$basel num] != [$baseltest num] && $bachain != 0 } {
        set useChain 1
        set extractId 1
        break
      }
      $baseltest delete

      # use segname in the identification?
      set baseltest [atomselect $molid "$seltext and resid $baresid and chain $bachain"]
      if { $useSegname != 0 && $basegname != 0 && $basegname != "{}" } {
        append baid "_segname$basegname"
      } elseif { [$basel num] != [$baseltest num] && $basegname != 0 && $basegname != "{}" } {
        set useSegname 1
        set extractId 1
        break
      }
      $baseltest delete

      # is this enough to identify the residue?
      if { $useChain != 0 && $useSegname != 0 } {
        set baseltest [atomselect $molid "$seltext and resid $baresid and chain $bachain and segname $basegname"]
      } elseif { $useChain != 0 } {
        set baseltest [atomselect $molid "$seltext and resid $baresid and chain $bachain"]
      } elseif { $useSegname != 0 } {
        set baseltest [atomselect $molid "$seltext and resid $baresid and segname $basegname"]
      } else {
        set baseltest [atomselect $molid "$seltext and resid $baresid"]
      }
      if { [$basel num] != [$baseltest num] } {
        set statusMsg "\nWarning: the identification $baid is not unique."
        update
        puts $log $statusMsg
        flush $log
      }
      $baseltest delete
  
      set idPairs($pair) "$acid-$baid"
  
    }

  }

  append statusMsg "Done."
  puts $log "Done."
  flush $log

  set numpairs [llength [array names finalPairs]]
  set statusMsg "Found $numpairs salt bridges."
  update
  puts $log "$statusMsg\n"
  flush $log

  foreach pair [array names idPairs] {
      puts $log $idPairs($pair)
  }
  puts $log ""
  flush $log

  return 

}

proc ::saltbr::printSaltBridges { molid frames_begin frames_step frames_end pairsName idpairsName outdir } {
  variable debug
  variable statusMsg
  variable log

  upvar $pairsName pairs
  upvar $idpairsName idPairs

  set statusMsg "Printing distances over all frames for each salt-bridge... "
  update
  puts -nonewline $log $statusMsg
  flush $log

  foreach pair [array names pairs] {
    
    foreach {ac ba} [split $pair ,] break

    set pairid $idPairs($pair)
    set outfile [open [file join $outdir saltbr-$pairid.dat] w]
        
    if $debug {
      puts $log "Printing to file saltbr-$pairid.dat"
    }
        
    set acseloxy [atomselect $molid "not backbone and oxygen and same residue as index $ac"]
    set baselnit [atomselect $molid "not backbone and nitrogen and same residue as index $ba"]

    for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {
      $acseloxy frame $f
      $baselnit frame $f
        
      set accenter [measure center $acseloxy]
      set bacenter [measure center $baselnit]
        
      set dist [veclength [vecsub $accenter $bacenter]]
      puts $outfile "$f $dist"
    }
        
    $acseloxy delete
    $baselnit delete
       
    close $outfile
  }
    
  append statusMsg "Done."
  update
  puts $log "Done."
  flush $log
}

# This gets called by VMD the first time the menu is opened.
proc saltbr_tk_cb {} {
  saltbrgui   ;# start the PDB Tool
  return $::saltbr::w
}



