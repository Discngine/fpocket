# hbonds - finds hydrogen bonds in a trajectory
# 
# Author:
#     JC Gumbart (gumbart@ks.uiuc.edu)
#     with thanks to Leo Trabuco and Elizabeth Villa whose salt bridge plugin provided the foundation for this one

#
# TODO:
#
# - show hbonds in the gui?
#

package provide hbonds 1.0

namespace eval ::hbonds:: {
  namespace export hbonds

  variable defaultAng 20
  variable defaultDist 3.0
  variable defaultWrite 0
  variable defaultFrames "all"
  variable defaultOutdir
  variable defaultLogFile ""
  variable defaultUpdateSel 1
  variable defaultPlot 1
  variable debug 0
  variable currentMol none
  variable atomselectText1 "protein"
  variable atomselectText2 ""
  variable defaultDatFile "hbonds.dat"
  variable statusMsg ""
}

proc ::hbonds::hbonds_gui {} {
  variable defaultDist
  variable defaultAng
  variable defaultWrite
  variable defaultPlot
  variable defaultFrames
  variable defaultLogFile
  variable defaultUpdateSel
  variable defaultDatFile
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
  
  variable atomselectText1 "protein"
  variable atomselectText2 ""
  
  # If already initialized, just turn on
  if { [winfo exists .hbonds] } {
    wm deiconify $w
    return
  }
  set w [toplevel ".hbonds"]
  wm title $w "Hydrogen Bonds"
  wm resizable $w 0 0

  variable statusMsg "Ready."
  variable guiDist $defaultDist
  variable guiAng $defaultAng
  variable guiWrite $defaultWrite
  variable guiPlot $defaultPlot
  variable guiFrames $defaultFrames
  variable guiLogFile $defaultLogFile
  variable guiUpdateSel $defaultUpdateSel
  variable guiDatFile $defaultDatFile
  variable guiOutdir [pwd]

  # Add a menu bar
  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

  # Help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About Hbonds" \
    -message "The H Bonds plugin searches for hydrogen bonds (subject to user criteria) within one selection or between two selections and then outputs the number of bonds as a function of time."}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/hbonds"

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

  grid [label $f.sellabel1 -text "Selection 1 (Required): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.sel1 -width 50 \
    -textvariable [namespace current]::atomselectText1] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [label $f.sellabel2 -text "Selection 2 (Optional): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.sel2 -width 50 \
    -textvariable [namespace current]::atomselectText2] \
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
  grid [label $f.ondistlabel -text "Donor-Acceptor distance (A): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.ondist -width 5 \
    -textvariable [namespace current]::guiDist] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  grid [label $f.comdistlabel -text "Angle cutoff (degrees): "] \
    -row $row -column 0 -sticky e
  grid [entry $f.comdist -width 5 \
    -textvariable [namespace current]::guiAng] \
    -row $row -column 1 -columnspan 3 -sticky ew
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $w.in -side top -pady 5 -padx 3 -fill x -anchor w

  ############## frame for output options #################
  labelframe $w.out -bd 2 -relief ridge -text "Output options" -padx 1m -pady 1m

  set f [frame $w.out.all]
  set row 0

  grid [checkbutton $f.check1 -text \
    "Plot the data with MultiPlot?" \
    -variable [namespace current]::guiPlot] \
    -row $row -column 0 -columnspan 2 -sticky w
  incr row
  grid [label $f.label -text "Output directory: "] \
    -row $row -column 0 -columnspan 1 -sticky e
  grid [entry $f.entry -textvariable [namespace current]::guiOutdir \
    -width 35 -relief sunken -justify left -state readonly] \
    -row $row -column 1 -columnspan 1 -sticky e
  grid [button $f.button -text "Choose" -command "::hbonds::getoutdir"] \
    -row $row -column 2 -columnspan 1 -sticky e
  incr row
  grid [label $f.loglabel -text "Log file? "] \
    -row $row -column 0 -sticky e
  grid [entry $f.logname -width 30 \
    -textvariable [namespace current]::guiLogFile] \
    -row $row -column 1 -columnspan 2 -sticky ew
  incr row
  grid [checkbutton $f.check2 -text \
    "Write a file with the frame/bond data?" \
    -variable [namespace current]::guiWrite] \
    -row $row -column 0 -columnspan 3 -sticky w
    incr row
    grid [entry $f.datname -width 30 \
    -textvariable [namespace current]::guiDatFile] \
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
  button $f.button -text "Find hydrogen bonds!" -width 20 \
    -command {::hbonds::hbonds -gui 1 -dist $::hbonds::guiDist -ang $::hbonds::guiAng -writefile $::hbonds::guiWrite -outdir $::hbonds::guiOutdir -frames $::hbonds::guiFrames -log $::hbonds::guiLogFile -upsel $::hbonds::guiUpdateSel -plot $::hbonds::guiPlot -outfile $::hbonds::guiDatFile}
  pack $f $f.button

}

# Adapted from pmepot gui
proc ::hbonds::fill_mol_menu {name} {

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

proc ::hbonds::getoutdir {} {
  variable guiOutdir

  set newdir [tk_chooseDirectory \
    -title "Choose output directory" \
    -initialdir $guiOutdir -mustexist true]

  if {[string length $newdir] > 0} {
    set guiOutdir $newdir 
  } 
}

proc hbonds { args } { return [eval ::hbonds::hbonds $args] }
proc hbondsgui { } { return [eval ::hbonds::hbonds_gui] }

proc ::hbonds::hbonds_usage { } {

  variable defaultDist
  variable defaultAng
  variable defaultWrite
  variable defaultPlot
  variable defaultFrames
  variable defaultDatFile

  puts "Usage: hbonds -sel1 <atom selection> <option1> <option2> ..."
  puts "Options:"
  puts "  -sel2 <atom selection> (default: none)"
  if $defaultWrite {
     puts "  -writefile <yes|no> (default: yes)"
  } else {
     puts "  -writefile <yes|no> (default: no)"
  }

  puts "  -upsel <yes|no> (update atom selections every frame? default: yes)"
  puts "  -frames <begin:end> or <begin:step:end> or all or now (default: $defaultFrames)"
  puts "  -dist <cutoff distance between donor and acceptor> (default: $defaultDist)"
  puts "  -ang <angle cutoff> (default: $defaultAng)"
  puts "  -plot <yes|no> (plot with MultiPlot, default: yes)"
  puts "  -outdir <output directory> (default: current)"
  puts "  -log <log filename> (default: none)"
  puts "  -writefile <yes|no> (default: no)"
  puts "  -outfile <dat filename> (default: $defaultDatFile)"
  return
}

proc ::hbonds::hbonds { args } {

  variable defaultDist
  variable defaultAng
  variable defaultFrames
  variable defaultWrite
  variable defaultPlot
  variable defaultFrames
  variable defaultUpdateSel
  variable defaultDatFile
  variable currentMol
  variable atomselectText1
  variable atomselectText2
  variable debug
  variable log
  variable statusMsg
  variable plotHbonds
  
  variable defaultOutdir [pwd]

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      hbonds_usage
      error ""
    }
    if { $nargs % 2 } {
      hbonds_usage
        error "error: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -sel1 { set arg(sel1) $val }
      -sel2 { set arg(sel2) $val }
      -upsel { set arg(upsel) $val }
      -frames { set arg(frames) $val }
      -dist { set arg(dist) $val }
      -ang { set arg(ang) $val }
      -writefile { set arg(writefile) $val }
      -outdir { set arg(outdir) $val }
      -log { set arg(log) $val }
      -gui { set arg(gui) $val }
      -debug { set arg(debug) $val }
      -plot {set arg(plot) $val}
      -outfile {set arg(outfile) $val}
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
  if [info exists arg(sel1)] {
     set sel1 $arg(sel1)
     set molid [$sel1 molid]
     if [info exists arg(sel2)] {
        set sel2 $arg(sel2)
     }

  } elseif $gui {
    if { $currentMol == "none" } {
      error "No molecules were found."
    } else {
      set molid $currentMol
      set sel1 [atomselect $currentMol $atomselectText1]
      if {$atomselectText2 != ""} {
         set sel2 [atomselect $currentMol $atomselectText2]
      }
    }
  } else {
    hbonds_usage
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

# SETTING FRAMES

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

# DONE SETTING FRAMES
    
  # get Dist
  if [info exists arg(dist)] {
    set dist $arg(dist)
  } else {
    set dist $defaultDist
  }

  # get Ang
  if [info exists arg(ang)] {
    set ang $arg(ang)
  } else {
    set ang $defaultAng
  }

  # write files?
  if [info exists arg(writefile)] {
     if { $arg(writefile) == "no" || $arg(writefile) == 0 } {
        set writefile 0
     } elseif { $arg(writefile) == "yes" || $arg(writefile) == 1 } {
        set writefile 1
        if [info exists arg(outfile)] {
           if {$arg(outfile) != ""} {
              set datfile $arg(outfile)
           } else {
              set datfile $defaultDatFile
           }
        } else {
           set datfile $defaultDatFile
        }
     } else {
       error "error: bad argument for option -writefile $arg(writefile): acceptable arguments are 'yes' or 'no'"
     }
  } else {
    set writefile $defaultWrite
    set datfile $defaultDatFile
  }

  # Plot?
  if [info exists arg(plot)] {
    if { ($arg(plot) == "no" || $arg(plot) == 0) && $writefile } {
      set plotHbonds 0
    } elseif { ($arg(plot) == "yes" || $arg(plot) == 1) || !$writefile } {
      set plotHbonds 1
    } else {
      error "error: bad argument for option -plot $arg(plot): acceptable arguments are 'yes' or 'no'"
    }
  } else {
    set plotHbonds $defaultPlot
  }
  

  # print name, version and date of plugin
  puts $log "H-Bonds Plugin, Version 1.0"
  puts $log "[clock format [clock scan now]]\n"
  puts $log "Parameters used in the calculation of hydrogen bonds:"
  puts $log "- Atomselection 1: [$sel1 text]"
  if [info exists sel2] {
      puts $log "- Atomselection 2: [$sel2 text]"
  }
  if $updateSel {
      puts $log "- Update selections every frame: yes"
  } else {
      puts $log "- Update selections every frame: no"
  }
  puts $log "- Initial frame: $frames_begin"
  puts $log "- Frame step: $frames_step"
  puts $log "- Final frame: $frames_end"
  puts $log "- Donor-Acceptor distance: $dist"
  puts $log "- Angle cutoff: $ang"
  if $writefile {
    puts $log "- Write a file with H bond/frame data: yes"
    puts $log "- Filename: $datfile"
  } else {
    puts $log "- Write a file with H bond/frame data: no"
  }
  puts $log ""
  flush $log
  

### CALCULATES HBONDS HERE

  for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {

     $sel1 frame $f
     if {[info exists sel2]} {
        $sel2 frame $f
     }

     if $updateSel {
        $sel1 update
        if {[info exists sel2]} {
           $sel2 update
        }
     }

     if {[info exists sel2]} {
        set count1 [llength [lindex [measure hbonds $dist $ang $sel1 $sel2] 0]]
        set count2 [llength [lindex [measure hbonds $dist $ang $sel2 $sel1] 0]]

        lappend framecount $f     
        lappend numHbonds [expr $count1 + $count2]

     } else {
        set count1 [llength [lindex [measure hbonds $dist $ang $sel1] 0]]

        lappend framecount $f     
        lappend numHbonds $count1
     }
  }

### DONE CALCULATING


  # delete the selection if it was created here
  if { ![info exists arg(sel1)] } {
    $sel1 delete
  }

  if {[info exists sel2]} {
     if { ![info exists arg(sel2)] } {
        $sel2 delete
     }
  }

  if { $writefile } {

     set statusMsg "Printing frame/hbond data to file... "
     update
     puts -nonewline $log $statusMsg
     flush $log

     set outfile [open [file join $outdir $datfile] w]
     if $debug {
       puts $log "Printing to file $datfile"
     }

     foreach fr $framecount hb $numHbonds {
        puts $outfile "$fr $hb"
     }

     unset fr hb

     close $outfile
     
     append statusMsg "Done."
     update
     puts $log "Done."
     flush $log

   }


  if { $plotHbonds } {

     set title [format "%s %s %s: %s" Molecule $molid, [molinfo $molid get name]  "H-Bonds vs. Frame"]

     # feed everything to the plotter
     set plothandle [multiplot -title $title -xlabel "Frame " -ylabel "No. Bonds"]

     $plothandle add $framecount $numHbonds -lines -linewidth 1 -linecolor black -marker none 
     $plothandle replot
  }

  if { $log != "stdout" } {
      close $log
  }

  set statusMsg "Done."
  update

  return

}


# This gets called by VMD the first time the menu is opened.
proc hbonds_tk_cb {} {
  hbondsgui   ;# start the PDB Tool
  return $::hbonds::w
}
