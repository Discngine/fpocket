#
#             RMSD Trajectory Tool v2.0
#
# A GUI interface for RMSD alignment and analysis of trajectories
#
# http://physiology.med.cornell.edu/faculty/hweinstein/vmdplugins/rmsdtt

# Author
# ------
#      Luis Gracia, PhD
#      Weill Medical College, Cornel University, NY
#      lug2002@med.cornell.edu

# This plugin is based on the RMSD Tool plugin written by
#   Alexander Balaeff, PhD, TB Group, UIUC
#   Pascal Mercier, PhD, Biochemistry Dept, Univ. of Alberta, Edmonton, Canada
#   John Stone, TB Group, UIUC

# Documentation
# -------------
# See the index.html file distributed with this file. For more update documentation see
# http://physiology.med.cornell.edu/faculty/hweinstein/vmdplugins/rmsdtt

# $Id: rmsdtt.tcl,v 1.4 2006/06/22 19:53:33 johns Exp $

package provide rmsdtt 2.01

namespace eval ::rmsdtt:: {
  namespace export rmsdtt
}


proc rmsdtt_tk_cb {} {
  # This gets called by VMD the first time the menu is opened.
  #variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::rmsdtt::w  }]  ;# destroy any old windows

  # start RMSDTT
  ::rmsdtt::rmsdtt
  return $rmsdtt::w
}


proc rmsdtt::rmsdtt {} {
  variable w
  variable bb_only    0
  variable trace_only 0
  variable noh        1
  variable swap_use   1
  variable swap_sw    0
  variable swap_type  "all"
  variable swap_print 1
  variable rmsd_base  "top"
  variable traj_sw    1
  variable traj_ref   0
  variable traj_all   0
  variable skip_sw    0
  variable skip_start 0
  variable skip_end   "end"
  variable skip_steps 1
  variable time_sw    0
  variable time_ini   0.0
  variable time_step  1.0
  variable save_sw    0
  variable save_file  "trajrmsd.dat"
  variable plot_sw    0
  variable plot_program "multiplot"
  variable colorize   1
  variable bb_def     "C CA N"
  variable stats      1
  variable datalist
  variable datatot

  # If already initialized, just turn on
  if { [winfo exists .rmsdtt] } {
    wm deiconify $w
    return
  }
  
  # GUI look
  #option add *rmsdtt.*font {Helvetica 9}
  #option add *rmsdtt.top.left.sel.background white
  #option add *rmsdtt.*Text.background white
  option add *rmsdtt.*borderWidth 1
  option add *rmsdtt.*Button.padY 0
  option add *rmsdtt.*Menubutton.padY 0

  # Main window
  set w [toplevel ".rmsdtt"]
  wm title $w "WMC PhysBio - RMSD Trajectory Tool"

  # Menu
  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -fill x

  menubutton $w.menubar.file -text "File" -menu $w.menubar.file.menu -underline 0 -pady 2
  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Save data..." -command "[namespace current]::SaveDataBrowse data" -underline 0
  $w.menubar.file.menu add command -label "Save summary..." -command "[namespace current]::SaveDataBrowse summary" -underline 0
  $w.menubar.file.menu add command -label "Plot data" -command [namespace current]::doPlot -underline 0
  pack $w.menubar.file -side left

  menubutton $w.menubar.options -text "Options" -menu $w.menubar.options.menu -underline 0 -pady 2
  menu $w.menubar.options.menu -tearoff no
  $w.menubar.options.menu add cascade -label "Plotting program..." -menu $w.menubar.options.menu.plot -underline 0
  menu $w.menubar.options.menu.plot -tearoff no
  $w.menubar.options.menu.plot add radiobutton -label "Multiplot (all)" -variable [namespace current]::plot_program -value "multiplot" -underline 0
  $w.menubar.options.menu.plot add radiobutton -label "Xmgrace (Unix)" -variable [namespace current]::plot_program -value "xmgrace" -underline 0
  $w.menubar.options.menu.plot add radiobutton -label "MS Excel (Windows)" -variable [namespace current]::plot_program -value "excel" -underline 4
  $w.menubar.options.menu add checkbutton -label "Colorize table" -variable [namespace current]::colorize -underline 0
  $w.menubar.options.menu add cascade -label "Backbone def..." -menu $w.menubar.options.menu.bbdef -underline 0
  menu $w.menubar.options.menu.bbdef
  $w.menubar.options.menu.bbdef add radiobutton -label "C CA N" -variable [namespace current]::bb_def -value "C CA N"
  $w.menubar.options.menu.bbdef add radiobutton -label "C CA N O" -variable [namespace current]::bb_def -value "C CA N O"
  $w.menubar.options.menu add checkbutton -label "Statistics" -variable [namespace current]::stats -underline 0
  pack $w.menubar.options -side left
  
  menubutton $w.menubar.help -text "Help" -menu $w.menubar.help.menu -underline 0 -pady 2 
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" -command [namespace current]::help_about
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url http://physiology.med.cornell.edu/faculty/hweinstein/vmdplugins/rmsdtt/index.html"
  pack $w.menubar.help -side right
  
  # top frame
  frame $w.top
  pack $w.top -side top -fill x
  
  # Selection
  frame $w.top.left -relief ridge
  pack $w.top.left -side left -fill both -expand yes
  
  text $w.top.left.sel -height 5 -width 25 -highlightthickness 0 -selectborderwidth 0 -exportselection yes -wrap word -relief sunken -bd 1
  pack $w.top.left.sel -side top -fill both -expand yes
  $w.top.left.sel insert end "protein"

  frame $w.top.left.mods -relief ridge -bd 2
  pack $w.top.left.mods -side top -fill x
  checkbutton $w.top.left.mods.bb -text "Backbone" -variable [namespace current]::bb_only -command "[namespace current]::ctrlbb bb"
  checkbutton $w.top.left.mods.tr -text "Trace" -variable [namespace current]::trace_only -command "[namespace current]::ctrlbb trace"
  checkbutton $w.top.left.mods.noh -text "noh" -variable [namespace current]::noh -command "[namespace current]::ctrlbb noh"
  menubutton  $w.top.left.mods.selectionhistory -menu $w.top.left.mods.selectionhistory.m -text "History" -relief raised -direction flush
  menu $w.top.left.mods.selectionhistory.m -tearoff no
  pack $w.top.left.mods.bb $w.top.left.mods.tr $w.top.left.mods.noh -side left -anchor w
  pack $w.top.left.mods.selectionhistory -side right

  # Swap
  if {[catch {package require swap} msg]} {
    set swap_use 0
  }
  if {$swap_use} {
    frame $w.top.left.swap -relief ridge -bd 2
    pack $w.top.left.swap -side top -fill x
    
    checkbutton $w.top.left.swap.0 -text "Swap_atoms:" -variable [namespace current]::swap_sw -command [namespace current]::ctrlgui
    menubutton $w.top.left.swap.type -relief raised -direction flush -textvariable [namespace current]::swap_type -menu $w.top.left.swap.type.menu
    menu $w.top.left.swap.type.menu -tearoff no
    checkbutton $w.top.left.swap.print -text "verbose" -variable [namespace current]::swap_print
    button $w.top.left.swap.list -relief raised -text "List" -command [namespace code {::swap::list $swap_type}]
    pack $w.top.left.swap.0 $w.top.left.swap.type $w.top.left.swap.print -side left -anchor w
    pack $w.top.left.swap.list -side right
  }
  
  # Buttons
  frame $w.top.right
  pack $w.top.right -side right

  frame $w.top.right.pushfr -relief ridge -bd 2
  pack $w.top.right.pushfr -side top -fill x

  button $w.top.right.pushfr.rmsd -text "RMSD" -relief raised -command [namespace current]::doRmsd -pady 2 -bd 2
  button $w.top.right.pushfr.align -text "Align" -relief raised -command [namespace current]::doAlign -pady 2 -bd 2
  pack $w.top.right.pushfr.rmsd $w.top.right.pushfr.align -side left -fill x -expand yes
  
  # Ref mol
  frame $w.top.right.ref -relief ridge -bd 2
  pack $w.top.right.ref -side top -fill x

  label $w.top.right.ref.label -text "Ref:"
  radiobutton $w.top.right.ref.0 -text "Top" -variable [namespace current]::rmsd_base -value "top" -command [namespace current]::ctrlgui
  radiobutton $w.top.right.ref.1 -text "Average" -variable [namespace current]::rmsd_base -value "ave" -command [namespace current]::ctrlgui
  radiobutton $w.top.right.ref.2 -text "Selected" -variable [namespace current]::rmsd_base -value "selected" -command [namespace current]::ctrlgui
  pack $w.top.right.ref.label $w.top.right.ref.0 $w.top.right.ref.1 $w.top.right.ref.2 -side left -expand yes

  # Trajectory
  frame $w.top.right.traj -relief ridge -bd 2
  pack $w.top.right.traj -side top

  frame $w.top.right.traj.frames -relief ridge -bd 0
  pack $w.top.right.traj.frames -side top -fill x

  checkbutton $w.top.right.traj.frames.0 -text "Trajectory" -variable [namespace current]::traj_sw -command [namespace current]::ctrlgui
  label $w.top.right.traj.frames.reflabel -text "Frame ref:"
  entry $w.top.right.traj.frames.ref -width 5 -textvariable [namespace current]::traj_ref
  checkbutton $w.top.right.traj.frames.all -text "All" -variable [namespace current]::traj_all -command [namespace current]::ctrlgui
  pack $w.top.right.traj.frames.0 $w.top.right.traj.frames.reflabel $w.top.right.traj.frames.ref -side left -anchor w -fill x
  pack $w.top.right.traj.frames.all -side right
  
  frame $w.top.right.traj.skip -relief ridge -bd 0
  pack $w.top.right.traj.skip -side top -fill x

  checkbutton $w.top.right.traj.skip.0 -text "Skip" -variable [namespace current]::skip_sw -command [namespace current]::ctrlgui
  label $w.top.right.traj.skip.inilabel -text "Start:"
  entry $w.top.right.traj.skip.ini -width 5 -textvariable [namespace current]::skip_start
  label $w.top.right.traj.skip.endlabel -text "End:"
  entry $w.top.right.traj.skip.end -width 5 -textvariable [namespace current]::skip_end
  label $w.top.right.traj.skip.stepslabel -text "Steps:"
  entry $w.top.right.traj.skip.steps -width 5 -textvariable [namespace current]::skip_steps
  pack $w.top.right.traj.skip.0 $w.top.right.traj.skip.inilabel $w.top.right.traj.skip.ini $w.top.right.traj.skip.stepslabel $w.top.right.traj.skip.steps -side left -anchor w
  # $w.top.right.traj.skip.endlabel $w.top.right.traj.skip.end 

  frame $w.top.right.traj.time -relief ridge -bd 0
  pack $w.top.right.traj.time -side top -fill x

  checkbutton $w.top.right.traj.time.0 -text "Time" -variable [namespace current]::time_sw -command [namespace current]::ctrlgui
  label $w.top.right.traj.time.inilabel -text "Ini:"
  entry $w.top.right.traj.time.inival -width 6 -textvariable [namespace current]::time_ini
  label $w.top.right.traj.time.steplabel -text "Step:"
  entry $w.top.right.traj.time.stepval -width 6 -textvariable [namespace current]::time_step
  pack $w.top.right.traj.time.0 $w.top.right.traj.time.inilabel $w.top.right.traj.time.inival $w.top.right.traj.time.steplabel $w.top.right.traj.time.stepval -side left -anchor w

  frame $w.top.right.traj.file -relief ridge -bd 0
  pack $w.top.right.traj.file -side top -fill x

  checkbutton $w.top.right.traj.file.plot -text "Plot" -variable [namespace current]::plot_sw
  checkbutton $w.top.right.traj.file.0 -text "Save to file:" -variable [namespace current]::save_sw\
    -command [namespace code {
      if {$save_sw} {
	$w.top.right.traj.file.name config -state normal
      } else {
	$w.top.right.traj.file.name config -state disable
      }
    }]
  entry $w.top.right.traj.file.name -width 15 -textvariable [namespace current]::save_file -state disable
  pack $w.top.right.traj.file.plot $w.top.right.traj.file.0 $w.top.right.traj.file.name -side left -anchor w

  # Data
  frame $w.data -relief ridge -bd 2
  pack $w.data -side top -fill both -expand yes
  
  grid columnconfigure $w.data 1 -weight 1
  grid rowconfigure $w.data 1 -weight 1

  label $w.data.header_id  -text "id"  -width 2  -relief sunken
  label $w.data.header_mol -text "mol" -width 30 -relief sunken
  label $w.data.header_avg -text "avg" -width 7  -relief sunken
  label $w.data.header_sd  -text "sd"  -width 7  -relief sunken
  label $w.data.header_min -text "min" -width 7  -relief sunken
  label $w.data.header_max -text "max" -width 7  -relief sunken
  label $w.data.header_num -text "num" -width 4  -relief sunken
  grid $w.data.header_id  -column 0 -row 0
  grid $w.data.header_mol -column 1 -row 0 -sticky we
  grid $w.data.header_avg -column 2 -row 0
  grid $w.data.header_sd  -column 3 -row 0
  grid $w.data.header_min -column 4 -row 0
  grid $w.data.header_max -column 5 -row 0
  grid $w.data.header_num -column 6 -row 0
  
  set datalist(id)  [listbox $w.data.body_id  -height 10 -width 2  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(mol) [listbox $w.data.body_mol -height 10 -width 30 -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(avg) [listbox $w.data.body_avg -height 10 -width 7  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(sd)  [listbox $w.data.body_sd  -height 10 -width 7  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(min) [listbox $w.data.body_min -height 10 -width 7  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(max) [listbox $w.data.body_max -height 10 -width 7  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  set datalist(num) [listbox $w.data.body_num -height 10 -width 4  -relief sunken -exportselection 0 -yscrollcommand [namespace current]::data_yset -selectmode extended]
  grid $w.data.body_id  -column 0 -row 1 -sticky ns
  grid $w.data.body_mol -column 1 -row 1 -sticky nswe
  grid $w.data.body_avg -column 2 -row 1 -sticky ns
  grid $w.data.body_sd  -column 3 -row 1 -sticky ns
  grid $w.data.body_min -column 4 -row 1 -sticky ns
  grid $w.data.body_max -column 5 -row 1 -sticky ns
  grid $w.data.body_num -column 6 -row 1 -sticky ns

  foreach key [array names datalist] {
    bind $w.data.body_$key <<ListboxSelect>> "[namespace current]::multiple_sel %W"
  }

  label $w.data.footer_id  -text ""                                        -width 2  -anchor e -relief sunken
  label $w.data.footer_mol -text "Overall:"                                -width 30 -anchor e -relief sunken
  label $w.data.footer_avg -textvariable [namespace current]::datatot(avg) -width 7  -anchor e -relief sunken
  label $w.data.footer_sd  -textvariable [namespace current]::datatot(sd)  -width 7  -anchor e -relief sunken
  label $w.data.footer_min -textvariable [namespace current]::datatot(min) -width 7  -anchor e -relief sunken
  label $w.data.footer_max -textvariable [namespace current]::datatot(max) -width 7  -anchor e -relief sunken
  label $w.data.footer_num -textvariable [namespace current]::datatot(num) -width 4  -anchor e -relief sunken
  grid $w.data.footer_id  -column 0 -row 2
  grid $w.data.footer_mol -column 1 -row 2 -sticky we
  grid $w.data.footer_avg -column 2 -row 2
  grid $w.data.footer_sd  -column 3 -row 2
  grid $w.data.footer_min -column 4 -row 2
  grid $w.data.footer_max -column 5 -row 2
  grid $w.data.footer_num -column 6 -row 2
  
  # Scrollbar
  scrollbar $w.data.scrbar -orient vert -command [namespace current]::data_yview
  #scrollbar $w.scrbar.scrbar -relief raised -activerelief raised -bd 2 -elementborderwidth 2 -orient vert -command {rmsdtt::scroll_data}
  grid $w.data.scrbar -column 7 -row 0 -rowspan 3 -sticky ns
  
  # Add/remove molecules from the list
  frame $w.bottom
  pack $w.bottom -side bottom -fill x
  
  button $w.bottom.delall -text "Erase all" -relief raised -command [namespace current]::mol_del
  button $w.bottom.del    -text "Erase selected" -relief raised -command "[namespace current]::mol_del 1"
  button $w.bottom.addall -text "Add all" -relief raised -command [namespace current]::mol_add
  button $w.bottom.add    -text "Add active" -relief raised -command "[namespace current]::mol_add 1"
  pack $w.bottom.delall $w.bottom.del $w.bottom.addall $w.bottom.add -side left -fill x -expand yes

  # Final code
  [namespace current]::mol_add 1
  [namespace current]::update_swap_types
  [namespace current]::ctrlgui
  
  update
  wm minsize $w [winfo width $w] [winfo height $w]
  wm resizable $w 1 1
}


proc rmsdtt::doRmsd {} {
  variable traj_sw
  variable traj_all
  variable traj_ref
  variable save_sw
  variable save_file
  variable plot_sw
  variable colorize
  variable rmsd_base
  variable swap_sw
  variable swap_print
  variable rmsd
  variable ref_mol
  variable ref_frames
  variable rms_sel
  variable datalist
  variable datatot
  variable stats

  # Parse selection
  set rms_sel [[namespace current]::set_sel]
  if {$rms_sel == ""} {
    showMessage "Selection is empty selection!"
    return -code return
  }
  #puts "DEBUG: rms_sel: $rms_sel"

  # Get reference mol/frames
  switch $rmsd_base {
    top {
      set ref_mol [molinfo top]
    }
    ave {
      set ref_mol "ave"
    }
    selected {
      set sel_index [lindex [$datalist(mol) curselection] 0]
      if {$sel_index == ""} {
	showMessage "No molecule has been selected!"
	return -code return
      }
      set ref_mol [$datalist(id) get $sel_index]
    }
  }
  if {$rmsd_base == "ave"} {
    set ref_frames 0
  } else {
    set ref_frames {}
    if {$traj_sw} {
      if {$traj_all} {
	for {set i 0} {$i < [molinfo $ref_mol get numframes]} {incr i} {
	  lappend ref_frames $i
	}
      } else {
	if {$traj_ref >= [molinfo $ref_mol get numframes]} {
	  showMessage "Frame ref out of range (max is [expr [molinfo $ref_mol get numframes]-1])"
	  return -code return
	}
	lappend ref_frames $traj_ref
      }
    } else {
      lappend ref_frames [molinfo $ref_mol get frame]
    }
  }

  #puts "DEBUG: ref_mol: $ref_mol"
  #puts "DEBUG: ref_frames: $ref_frames"
  
  # Get target mol/frames
  # Get all mols to work with
  set target_mol [$datalist(id) get 0 end]
  #puts "DEBUG: target_mol: $target_mol"
  
  # Calculate average structure
  if {$rmsd_base == "ave"} {
    set ave_coor [get_ave_coor $target_mol $rms_sel]
    #puts $ave_coor
  }

  # Check number of atoms
  if {$rmsd_base == "ave"} {
    set ref_natoms [llength $ave_coor]
  } else {
    set ref_natoms [[atomselect $ref_mol $rms_sel frame 0] num]
  }
  if {$ref_natoms == 0} {
    showMessage "No atoms have been selected!"
    return -code return
  }

  set message ""
  foreach i $target_mol {
    if {[[atomselect $i $rms_sel frame 0] num] != $ref_natoms } {
      append message "$ref_mol ($ref_natoms)\t\t$i ([[atomselect $i $rms_sel frame 0] num])\n"
    }
  }
  if {$message != ""} {
    set message "Number of atoms selected differ for molecules:\n$message"
    showMessage $message
    return -code return
  }

  # Calculate rmsd and averages
  array unset rmsd
  array unset rms_ave
  array unset rms_val
  set rms_tot 0.0
  if {$rmsd_base != "ave"} {
    set ref_sel [atomselect $ref_mol $rms_sel]
  }
  foreach i $target_mol {
    set target_frames [[namespace current]::get_frames_for_mol $i]
    #puts "DEBUG: target_frames($i): $target_frames"
    set target_sel [atomselect $i $rms_sel]
    set rms_ave($i) 0.0
    foreach j $ref_frames {
      if {$rmsd_base != "ave"} {
	$ref_sel frame $j
      }
      foreach k $target_frames {
	if {$ref_mol == $i && $j == $k} {
	  continue
	}
	#puts -nonewline "DEBUG: computing rmsd($ref_mol:$j,$i:$k)"
	$target_sel frame $k
	if {$rmsd_base == "ave"} {
	  set rmsd($ref_mol:$j,$i:$k) [get_rmsd_ave $ave_coor $target_sel]
	} else {
	  set rmsd($ref_mol:$j,$i:$k) [get_rmsd $ref_sel $target_sel]
	}
	#puts "   = $rmsd($ref_mol:$j,$i:$k)"
	set rms_ave($i) [expr $rms_ave($i) + $rmsd($ref_mol:$j,$i:$k)]
      }
    }
    set rms_tot [expr $rms_tot + $rms_ave($i)]
    set count($i) [llength [array names rmsd *,$i:*]]
    #puts "DEBUG: rms_sum($i) = $rms_ave($i) ; count($i) = $count($i)"
    if {$count($i) != 0} {
      set rms_ave($i) [expr $rms_ave($i)/$count($i)]
    }
    #puts "DEBUG: rms_ave($i) = $rms_ave($i)"
  }
  set rms_tot [expr $rms_tot/[array size rmsd]]
  #puts "DEBUG: rms_tot = $rms_tot (count = [array size rmsd])"

  # Calculate statistics: standard deviation, min and max
  if {$stats} {
    set sd_tot 0.0
    set random $rmsd([lindex [array names rmsd] 0])
    set min_tot $random
    set max_tot $random
    foreach i $target_mol {
      set rms_sd($i) 0.0
      if {$count($i) == 0} {
	set rms_min($i) 0.0
	set rms_max($i) 0.0
	continue
      }
      set random $rmsd([lindex [array names rmsd *,$i:*] 0])
      set rms_min($i) $random
      set rms_max($i) $random
      foreach data [array names rmsd *,$i:*] {
	set temp [expr $rmsd($data) - $rms_ave($i)]
	set rms_sd($i) [expr $rms_sd($i) + $temp*$temp]
	if {$rmsd($data) < $rms_min($i) } {set rms_min($i) $rmsd($data)}
	if {$rmsd($data) > $rms_max($i) } {set rms_max($i) $rmsd($data)}
      }
      set sd_tot [expr $sd_tot + $rms_sd($i)]
      if {$count($i) == 1} {
	set rms_sd($i) [expr sqrt($rms_sd($i))]
      } else {
	set rms_sd($i) [expr sqrt( $rms_sd($i) / ($count($i)-1) )]
      }
      #puts "DEBUG: rms_sd($i) = $rms_sd($i)"
      if {$rms_min($i) < $min_tot} {set min_tot $rms_min($i)}
      if {$rms_max($i) > $max_tot} {set max_tot $rms_max($i)}
    }
    set count_tot [array size rmsd]
    if {$count_tot == 1} {
      set sd_tot [expr sqrt($sd_tot)]
    } else {
      set sd_tot [expr sqrt($sd_tot / ($count_tot - 1))]
    }
    #puts "DEBUG: sd_tot = $sd_tot"
  }

  # Reveal values in GUI
  foreach v [array names datalist] {
    $datalist($v) delete 0 end
  }
  foreach i $target_mol {
    $datalist(id)  insert end [format "%2s"    $i]
    $datalist(mol) insert end [format "%s"     [molinfo $i get name]]
    $datalist(avg) insert end [format "%8.3f" $rms_ave($i)]
    if {$stats} {
      $datalist(sd)  insert end [format "%8.3f"  $rms_sd($i)]
      $datalist(min) insert end [format "%8.3f" $rms_min($i)]
      $datalist(max) insert end [format "%8.3f" $rms_max($i)]
      $datalist(num) insert end [format "%4d"    $count($i)]
    } else {
      $datalist(sd)  insert end ""
      $datalist(min) insert end ""
      $datalist(max) insert end ""
      $datalist(num) insert end ""
    }
  }

  if {$rmsd_base == "selected"} {
    foreach key [array names datalist] {
      $datalist($key) selection clear 0 end
      $datalist($key) selection set $sel_index
    }
  }

  set datatot(avg) [format "%8.3f" $rms_tot]
  if {$stats} {
    set datatot(sd)  [format "%8.3f"  $sd_tot]
    set datatot(min) [format "%8.3f" $min_tot]
    set datatot(max) [format "%8.3f" $max_tot]
    set datatot(num) [format "%4d"    [array size rmsd]]
  }

  if {$traj_sw && $plot_sw  && !$traj_all && $colorize} {
    [namespace current]::color_data 1
  } else {
    [namespace current]::color_data 0
  }

  # Save and plot data
  if {$traj_sw && $save_sw} { saveData $save_file }
  if {$traj_sw && $plot_sw && !$traj_all} { doPlot }

  #puts "DEBUG: ---------------------------------"

  [namespace current]::ListHisotryPullDownMenu
}


proc rmsdtt::get_rmsd { sel1 sel2 } {
  variable swap_sw
  variable swap_print

  set rmsd [measure rmsd $sel1 $sel2]

  if {$swap_sw} {
    if {$swap_print} {
      puts "\nDEBUG: Swapped residues:"
    }
    set swapped {}
    set mol2 [$sel2 molid]
    set frame2 [$sel2 frame]
    set sel_text [$sel2 text]
    set res [lsort -unique -integer [[atomselect $mol2 "$sel_text and resname [array names ::swap::swap_list]" frame $frame2] get residue]]
    foreach r $res {
      set s [atomselect $mol2 "residue $r"]
      ::swap::swap_residue $s $frame2
      set rmsd2 [measure rmsd $sel1 $sel2]
      if {$rmsd2 < $rmsd} {
	if {$swap_print} {
	  puts "swapped mol $mol2 frame $frame2 residue $r ([lindex [$s get {resname resid chain segname}] 0]) $rmsd $rmsd2"
	}
	set rmsd $rmsd2
	lappend swapped $s
      } else {
	::swap::swap_residue $s $frame2
      }
    }

    foreach s $swapped {
      if {$s == ""} {
	continue
      } else {
	::swap::swap_residue $s $frame2
      }
    }
  }
  
  return $rmsd
}


proc rmsdtt::get_ave_coor {mols sel_text} {
  variable traj_sw

  set natoms [[atomselect [lindex $mols 0] $sel_text frame 0] num]

  set initialize 1
  set ave_coor {}
  set tot_frames 0
  foreach i $mols {
    set nframes [molinfo $i get numframes]
    if {$traj_sw && $nframes > 1} {
      set avpos [measure avpos [atomselect $i $sel_text] first 0 last [expr $nframes-1] step 1]
      #puts "$i avpos: $avpos"
      if {$initialize} {
	for {set j 0} {$j < $natoms} {incr j} {
	  lappend ave_coor [vecscale [lindex $avpos $j] $nframes]
	}
	set initialize 0
      } else {
	for {set j 0} {$j < $natoms} {incr j} {
	  lset ave_coor $j [vecadd [lindex $ave_coor $j] [vecscale [lindex $avpos $j] $nframes]]
	}
      }
    } else {
      set coor [[atomselect $i $sel_text frame [molinfo $i get frame]] get {x y z}]
      #puts "$i coor: $coor"
      set nframes 1
      if {$initialize} {
	set ave_coor $coor
	set initialize 0
      } else {
	for {set j 0} {$j < $natoms} {incr j} {
	  lset ave_coor $j [vecadd [lindex $ave_coor $j] [lindex $coor $j]]
	}
      }
    }
    set tot_frames [expr $tot_frames + $nframes]
    #puts "$i sum: $ave_coor"
  }
  
  #puts "tot_frames: $tot_frames"
  for {set j 0} {$j < $natoms} {incr j} {
    lset ave_coor $j [vecscale [lindex $ave_coor $j] [expr 1./$tot_frames]]
  }
  #puts "AVE_COOR: $ave_coor"
  
  return $ave_coor
}


proc rmsdtt::get_rmsd_ave {ref_coor target_sel} {
  set target_coor [$target_sel get {x y z}]
  set numatoms [llength $ref_coor]
  set rmsd 0
  # for each atom
  for {set k 0} {$k < $numatoms} {incr k} {
    set rmsd [expr $rmsd + [veclength2 [vecsub [lindex $ref_coor $k] [lindex $target_coor $k]]]]
  }
  set rmsd [expr sqrt($rmsd/$numatoms)]

  return $rmsd
}


proc rmsdtt::doAlign {} {
  variable w
  variable rmsd_base
  variable traj_ref
  variable traj_sw
  variable traj_all
  variable datalist
  
  if {$traj_all} {
    showMessage "All option not available for Alignment! Deselect it and select a frame reference."
    return -code return
  }

  switch $rmsd_base {
    top {
      set ref_mol [molinfo top]
    }
    selected {
      set sel_index [lindex [$datalist(mol) curselection] 0]
      if {$sel_index == ""} {
	showMessage "No molecule has been selected!"
	return -code return
      }
      set ref_mol [$datalist(id) get $sel_index]
    }
    ave {
      showMessage "Average option not available for Alignment!"
      return -code return
    }
  }

  set rms_sel [[namespace current]::set_sel]
  set sel_ref [atomselect $ref_mol $rms_sel frame $traj_ref]
  set target_mol [$datalist(id) get 0 end]
  foreach i $target_mol  {
    set sel [atomselect $i $rms_sel]
    if {$traj_sw == 0} {
      if {$i != $ref_mol} {
	align $sel [molinfo $i get frame] $sel_ref
      }
    } else {
      for {set j 0} {$j < [molinfo $i get numframes]} {incr j} {
	if {$i == $ref_mol && $j == $traj_ref} {
	  continue
	}
	align $sel $j $sel_ref
      }
    }
  }

  if {$rmsd_base == "selected"} {
    foreach key [array names datalist] {
      $datalist($key) selection clear 0 end
      $datalist($key) selection set $sel_index
    }
  }
}


proc rmsdtt::align {sel1 frame1 sel2} {
  $sel1 frame $frame1
  set tmatrix [measure fit $sel1 $sel2]
  set move_sel [atomselect [$sel1 molid] "all" frame $frame1]
  $move_sel move $tmatrix
  return $tmatrix
}


proc rmsdtt::SaveDataBrowse { {type "data"} } {
  variable rmsd

  if {![array exists rmsd]} {
    showMessage "No data available to save yet!"
    return -code return
  }

  set typeList {
    {"Data Files" ".dat .txt .out"}
    {"Postscript Files" ".ps"}
    {"All files" ".*"}
  }
  
  set file [tk_getSaveFile -filetypes $typeList -defaultextension ".dat" -title "Select file to save data" -parent .rmsdtt]
  
  if {$file == ""} {
    return
  }
  
  if {$type == "data"} {
    [namespace current]::saveData $file
  } else {
    [namespace current]::saveSummary $file
  }
}


proc rmsdtt::saveData { file } {
  variable traj_sw
  variable traj_all
  variable time_sw
  variable time_ini
  variable time_step
  variable skip_sw
  variable skip_start
  variable skip_end
  variable skip_steps
  variable rmsd
  variable ref_mol
  variable ref_frames

  if {$file == ""} {
    showMessage "Filename is missing!"
    return -code return
  }

  if {$skip_sw} {
    set ini $skip_start
    if {$skip_end == "end"} {
      #set end [expr [llength $list] -1]
    } else {
      #set end [lsearch $list $skip_end]
    }
    set steps [expr $skip_steps+1]
  } else {
    set ini 0
    set steps 1
  }

  # Retrieve mols and frames
  set maxframe 0
  foreach key [array names rmsd] {
    set indices [split $key :,]
    set mol [lindex $indices 2]
    set frame [lindex $indices 3]
    lappend target_mol $mol
    lappend target_frames($mol) $frame
    if {$frame > $maxframe} {
      set maxframe $frame
    }
  }
  set target_mol [lsort -unique -integer $target_mol]
  foreach i $target_mol {
    set target_frames($i) [lsort -unique -integer $target_frames($i)]
  }
  
  if {$traj_sw && $traj_all} {
    # Header
    if {$time_sw} {
      set output "ref_mol\tref_time\tmol\t    time\t   rmsd\n"
    } else {
      set output "ref_mol\tref_frame\tmol\tframe\t   rmsd\n"
    }
   
    foreach k $ref_frames {
      set ref_time [expr $time_ini + $time_step * $k]
      foreach i $target_mol {
	foreach j $target_frames($i) {
	  if {![info exists rmsd($ref_mol:$k,$i:$j)]} {
	    continue
	  }
	  if {$time_sw} {
	    set time [expr $time_ini + $time_step * $j]
	    append output [format "%7d\t%8.2f\t%3d\t%8.2f\t" $ref_mol $ref_time $i $time]
	  } else {
	    append output [format "%7d\t%9d\t%3d\t%5d\t" $ref_mol $k $i $j]
	  }
	  append output [format "%7.3f\n" $rmsd($ref_mol:$k,$i:$j)]
	}
      }
    }
    
  } else {
    set ref "$ref_mol:[lindex $ref_frames 0]"

    # Header
    if {$time_sw} {
      set output "time"
    } else {
      set output "frame"
    }
    foreach i $target_mol {
      append output [format " %7s" "mol$i"]
    }
    append output "\n"
    
    # Data
    for {set j $ini} {$j <= $maxframe} {incr j $steps} {
      if {$time_sw} {
	set time [expr $time_ini + $time_step * $j]
	append output [format "%8.2f" $time]
      } else {
	append output [format "%5d" $j]
      }
      
      foreach i $target_mol {
	if {[info exists rmsd($ref,$i:$j)]} {
	  append output [format " %7.3f" $rmsd($ref,$i:$j)]
	} else {
	  append output [format " %7s" {NA}]
	}
      }
      
      append output "\n"
    }
  }

  # Save to file
  set fid [open $file w]
  fconfigure $fid
  puts $fid $output
  close $fid
}


proc rmsdtt::saveSummary { file } {
  variable datalist

  if {$file == ""} {
    showMessage "Filename is missing!"
    return -code return
  }

  # Header
  set output [format "%3s  %-25s  %8s  %8s  %8s  %8s  %4s\n" id mol avg sd min max num]
  for {set i 0} {$i < [$datalist(id) size]} {incr i} {
    append output [format "%3d  %-25s  %8.3f  %8.3f  %8.3f  %8.3f  %4d\n" [$datalist(id) get $i] \
		     [$datalist(mol) get $i] [$datalist(avg) get $i] [$datalist(sd) get $i] \
		     [$datalist(min) get $i] [$datalist(max) get $i] [$datalist(num) get $i]
		  ]
  }

  # Save to file
  set fid [open $file w]
  fconfigure $fid
  puts $fid $output
  close $fid
}


proc rmsdtt::tempfile {prefix suffix} {
  # From wiki.tcl.tk/772
  set chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  set nrand_chars 10
  set maxtries 10
  set access [list RDWR CREAT EXCL TRUNC]
  set permission 0600
  set channel ""
  set checked_dir_writable 0
  set mypid [pid]
  for {set i 0} {$i < $maxtries} {incr i} {
    set newname $prefix
    for {set j 0} {$j < $nrand_chars} {incr j} {
      append newname [string index $chars \
			[expr ([clock clicks] ^ $mypid) % 62]]
    }
    append newname $suffix
    if {[file exists $newname]} {
      after 1
    } else {
      if {[catch {open $newname $access $permission} channel]} {
	if {!$checked_dir_writable} {
	  set dirname [file dirname $newname]
	  if {![file writable $dirname]} {
	    error "Directory $dirname is not writable"
	  }
	  set checked_dir_writable 1
	}
      } else {
	# Success
	return [list $newname $channel]
      }
    }
  }
  if {[string compare $channel ""]} {
    error "Failed to open a temporary file: $chanel"
  } else {
    error "Failed to find an unused temporary file name"
  }
}


proc rmsdtt::index2rgb {i} {
  set len 2
  lassign [colorinfo rgb $i] r g b
  set r [expr int($r*255)]
  set g [expr int($g*255)]
  set b [expr int($b*255)]
  #puts "$i      $r $g $b"
  return [format "#%.${len}X%.${len}X%.${len}X" $r $g $b]
}

proc rmsdtt::doPlot {} {
  variable rmsd
  variable rms_sel
  variable time_sw
  variable time_ini
  variable time_step
  variable skip_sw
  variable skip_start
  variable skip_end
  variable skip_steps
  variable ref_mol
  variable ref_frames
  variable plot_program
  global tcl_platform
  
  if {![array exists rmsd]} {
    showMessage "No data available to plot yet!"
    return -code return
  }
  

  if {$skip_sw} {
    set ini $skip_start
    set steps [expr $skip_steps+1]
  } else {
    set ini 0
    set steps 1
  }

  # Retrieve mols and frames
  set maxframe 0
  foreach key [array names rmsd] {
    set indices [split $key :,]
    set mol [lindex $indices 2]
    set frame [lindex $indices 3]
    lappend target_mol $mol
    lappend target_frames($mol) $frame
    if {$frame > $maxframe} {
      set maxframe $frame
    }
  }
  set target_mol [lsort -unique -integer $target_mol]
  foreach i $target_mol {
    set target_frames($i) [lsort -unique -integer $target_frames($i)]
  }
  
  # Prepare sets
  set ref "$ref_mol:[lindex $ref_frames 0]"
  foreach i $target_mol {
    for {set j $ini} {$j <= $maxframe} {incr j $steps} {
      if {[info exists rmsd($ref,$i:$j)]} {
	if {$time_sw} {
	  lappend x($i) [expr $time_ini + $time_step * $j]
	} else {
	  lappend x($i) $j
	}
	lappend y($i) $rmsd($ref,$i:$j)
      }
    }
  }
  

  # Multiplot
  # ---------
  if {$plot_program == "multiplot"} {
    if [catch {package require multiplot} msg] {
      showMessage "Plotting in Multiplot not available: package multiplot not installed!\nDo you have the latest VMD version?"
      return
    }
    
    if {$time_sw} {
      set title "Rmsd vs Time \"$rms_sel)\""
      set xlab "Time"
    } else {
      set title "Rmsd vs Frame \"$rms_sel\""
      set xlab "Frame"
    }
    set ylab "Rmsd (A)"
    set plothandle [multiplot -title $title -xlabel $xlab -ylabel $ylab -nostats]
    
    set k 0
    foreach i $target_mol {
      set coln $i
      while {$coln > 15} {
	set coln [expr $coln - 16]
      }
      set color [index2rgb $coln]
      set iname "[molinfo $i get name] ($i)"
      
      if {[llength $y($i)] == 1} {
	$plothandle add $x($i) $y($i) -marker circle -radius 4 -nolines -fillcolor $color -linecolor $color -nostats -legend $iname
      } else {
	$plothandle add $x($i) $y($i) -marker point -radius 2 -fillcolor $color -linecolor $color -nostats -legend $iname
      }
      incr k
    }
    $plothandle replot


    # Xmgrace
    # -------
  } elseif {$plot_program == "xmgrace"} {
    if {$tcl_platform(platform) == "unix" } {
      
      set f [tempfile rmsdtt .tmp]
      set filename [lindex $f 0]
      set pipe_id [lindex $f 1]
      fconfigure $pipe_id -buffering line
      
      puts $pipe_id "@ page size 576, 432"
      puts $pipe_id "@ g0 on"
      puts $pipe_id "@ with g0"
      puts $pipe_id "@ subtitle \"$rms_sel\""
      if {$time_sw} {
	puts $pipe_id "@ title \"Rmsd vs Time\""
	puts $pipe_id "@ xaxis  label \"Time\""
      } else {
	puts $pipe_id "@ title \"Rmsd vs Frame\""
	puts $pipe_id "@ xaxis  label \"Frame\""
      }
      puts $pipe_id "@ yaxis  label \"Rmsd (A)\""
      puts $pipe_id "@ TYPE xy"
      puts $pipe_id "@ view 0.15, 0.15, 0.75, 0.85"
      puts $pipe_id "@ legend on"
      puts $pipe_id "@ legend box on"

      set k 0
      foreach i $target_mol {
	set iname "[molinfo $i get name] ($i)"
	puts $pipe_id "@ s$k legend \"$iname\""
	if {[llength $y($i)] == 1} {
	  puts $pipe_id "@ s$k symbol 1"
	}
	for {set j 0} {$j < [llength $y($i)]} {incr j} {
	  puts $pipe_id "[lindex $x($i) $j] [lindex $y($i) $j]"
	}
      	puts $pipe_id ""
	incr k
      }
      
      close $pipe_id
      set status [catch {exec xmgrace $filename &} msg]
      if { $status } {
	showMessage "Could not open xmgrace. Error returned:\n $msg"
	file delete -force $filename
	return -code return
      } 
    } else {
      showMessage "Plotting in Xmgrace only availabe for Unix systems"
    }


    # Excel
    # -----
  } elseif {$plot_program == "excel"} {
    if {$tcl_platform(platform) == "windows" } {
      if [catch {package require tcom} msg] {
	showMessage "Plotting in MS Excel not available: package tcom not installed!\nFollow instruction at http://physiology.med.cornell.edu/faculty/hweinstein/vmdplugins/rmsdtt/index.html#RMSDTT_install"
	return
      }
      set excel [::tcom::ref createobject "Excel.Application"]
      #set excel [::tcom::ref getactiveobject "Excel.Application"]
      $excel Visible 1
      
      set workbooks [$excel Workbooks]
      set workbook [$workbooks Add]
      set worksheets [$workbook Worksheets]
      [$worksheets Item [expr 2]] Delete
      [$worksheets Item [expr 2]] Delete
      set worksheet [$worksheets Item [expr 1]]
      $worksheet Name "RMSDTT data"
      
      set cells [$worksheet Cells]
      if {$time_sw} {
	set exceltitle "Rmsd vs Time"
	$cells Item 1 1 "Time"
      } else {
	set exceltitle "Rmsd vs Frame"
	$cells Item 1 1 "Frame"
      }

      set k 1
      foreach i $target_mol {
	incr k
	set iname "[molinfo $i get name] ($i)"
	$cells Item 1 $k $iname
	for {set j 0} {$j < [llength $y($i)]} {incr j} {
	  $cells Item [expr $j+2] 1 [lindex $x($i) $j]
	  $cells Item [expr $j+2] $k [lindex $y($i) $j]
	}
      }
      
      set charts [$workbook Charts]
      set chart [$charts Add]
      $chart Name "RMSDTT graph"
      set endrange [int2word $k]
      append endrange [expr [llength $y($i)]+2]
      $chart ChartWizard [$worksheet Range "A1" $endrange] -4169 [::tcom::na] 2 1 [expr $k-1] 1 "$exceltitle\n($rms_sel)"
      $chart ChartType 75
      [[$chart PlotArea] Interior] ColorIndex 0
      
      set axes [$chart Axes]
      set xaxis [$axes Item 1]
      $xaxis HasMajorGridlines 0
      $xaxis HasTitle 1
      if {$time_sw} {
	[$xaxis AxisTitle] Text "Time"
      } else {
	[$xaxis AxisTitle] Text "Frame"
      }
      set yaxis [$axes Item 2]
      $yaxis HasMajorGridlines 0
      $yaxis HasTitle 1
      [$yaxis AxisTitle] Text "Rmsd (A)"
    
    } else {
      showMessage "Plotting in MS Excel only availabe for Windows systems"
    }
  }
}


proc rmsdtt::set_sel {} {
  variable w
  variable bb_only
  variable trace_only
  variable noh
  variable swap_sw
  variable bb_def

#  set a [$w.top.left.sel get 1.0 end]
#  puts "a <$a>"
  regsub -all "\#.*?\n" [$w.top.left.sel get 1.0 end] "" temp1
  regsub -all "\n" $temp1 " " temp2
  regsub -all " $" $temp2 "" temp3
#  puts "c <$temp3>"
  if { $trace_only } {
    append rms_sel "($temp3) and name CA"
  } elseif { $bb_only } {
    append rms_sel "($temp3) and name $bb_def"
  } elseif { $noh || $swap_sw} {
    append rms_sel "($temp3) and noh"
  } else {
    append rms_sel $temp3
  }
  return $rms_sel
}


proc rmsdtt::get_frames_for_mol { mol } {
  variable skip_sw
  variable skip_start
  variable skip_end
  variable skip_steps
  variable traj_sw

  set list {}

  if {$traj_sw} {
    for {set n 0} {$n < [molinfo $mol get numframes]} {incr n} {
      lappend list $n
    }
    
    if {$skip_sw} {
      set result {}
      set steps [expr $skip_steps + 1]
      if {$skip_end == "end"} {
	set end [expr [llength $list] -1]
      } else {
	set end [lsearch $list $skip_end]
      }
      for {set i $skip_start} {$i <= $end} {incr i $steps} {
	lappend result [lindex $list $i]
      }
      set list $result
    }
  } else {
    lappend list [molinfo $mol get frame]
  }

  return $list
}

proc rmsdtt::showMessage {mess} {
  bell
  toplevel .messpop 
  grab .messpop
  wm title .messpop "Warning"
    message .messpop.msg -relief groove -bd 2 -text $mess -aspect 400 -justify center -padx 20 -pady 20
  
  button .messpop.okb -text OK -command {destroy .messpop ; return 0}
  pack .messpop.msg .messpop.okb -side top 
}


proc rmsdtt::int2word {int} {
  # http://wiki.tcl.tk/10915
  set alphabet [a-z]
  set word ""
  set la [llength $alphabet]
  while {$int > 0} {
    incr int -1
    set word  [lindex $alphabet [expr {$int % $la}]]$word
    set int   [expr {$int/$la}]
  }
  set word
}


proc a-z {} {list a b c d e f g h i j k l m n o p q r s t u v w x y z}


proc rmsdtt::ctrlgui {} {
  variable w
  variable traj_sw
  variable traj_all
  variable save_sw
  variable plot_sw
  variable rmsd_base
  variable time_sw
  variable skip_sw
  variable swap_sw
  variable swap_use
  variable noh

  if {$traj_sw} {
    if {$traj_all} {
      $w.top.right.traj.file.plot config -state disable
      $w.top.right.pushfr.align config -state disable
    } else {
      $w.top.right.traj.file.plot config -state normal
      $w.top.right.pushfr.align config -state normal
    }
    $w.top.right.traj.file.0 config -state normal
    if {$save_sw} {
      $w.top.right.traj.file.name config -state normal
    } else {
      $w.top.right.traj.file.name config -state disable
    }
    if {$rmsd_base == "ave"} {
      $w.top.right.traj.frames.reflabel config -state disable
      $w.top.right.traj.frames.all config -state disable
      $w.top.right.traj.frames.ref config -state disable
     } else {
      $w.top.right.traj.frames.reflabel config -state normal
      $w.top.right.traj.frames.all config -state normal
      if {$traj_all} {
	$w.top.right.traj.frames.ref config -state disable
      } else {
	$w.top.right.traj.frames.ref config -state normal
      }
    }
    $w.top.right.traj.time.0 config -state normal
    $w.top.right.traj.skip.0 config -state normal
  } else {
    $w.top.right.traj.file.plot config -state disable
    $w.top.right.traj.file.0 config -state disable
    $w.top.right.traj.file.name config -state disable
    $w.top.right.traj.frames.reflabel config -state disable
    $w.top.right.traj.frames.all config -state disable
    $w.top.right.traj.frames.ref config -state disable
    $w.top.right.traj.time.0 config -state disable
    $w.top.right.traj.skip.0 config -state disable
  }

  if {$rmsd_base == "ave"} {
    $w.top.right.pushfr.align config -state disable
    if {$swap_use} {
      set swap_sw 0
      $w.top.left.swap.0 config -state disable
    }
  } else {
    $w.top.right.pushfr.align config -state normal
    if {$swap_use} {
      $w.top.left.swap.0 config -state normal
    }
  }

  if {$time_sw && $traj_sw} {
    $w.top.right.traj.time.inilabel config -state normal
    $w.top.right.traj.time.inival config -state normal
    $w.top.right.traj.time.steplabel config -state normal
    $w.top.right.traj.time.stepval config -state normal
  } else {
    $w.top.right.traj.time.inilabel config -state disable
    $w.top.right.traj.time.inival config -state disable
    $w.top.right.traj.time.steplabel config -state disable
    $w.top.right.traj.time.stepval config -state disable
  }

  if {$skip_sw && $traj_sw} {
    $w.top.right.traj.skip.inilabel config -state normal
    $w.top.right.traj.skip.ini config -state normal
    $w.top.right.traj.skip.stepslabel config -state normal
    $w.top.right.traj.skip.steps config -state normal
  } else {
    $w.top.right.traj.skip.inilabel config -state disable
    $w.top.right.traj.skip.ini config -state disable
    $w.top.right.traj.skip.stepslabel config -state disable
    $w.top.right.traj.skip.steps config -state disable
  }

  if {$swap_use} {
    if {$swap_sw} {
      set noh 0
      [namespace current]::ctrlbb noh
      $w.top.left.mods.noh config -state disable
      $w.top.left.swap.type config -state normal
      $w.top.left.swap.print config -state normal
      $w.top.left.swap.list config -state normal
    } else {
      $w.top.left.mods.noh config -state normal
      $w.top.left.swap.type config -state disable
      $w.top.left.swap.print config -state disable
      $w.top.left.swap.list config -state disable
    }
    [namespace current]::update_swap_types
  }
}


proc rmsdtt::ctrlbb { obj } {
  variable w
  variable bb_only
  variable trace_only
  variable noh

  if {$obj == "bb"} {
    set trace_only 0
    set noh 0
  } elseif {$obj == "trace"} {
    set bb_only 0
    set noh 0
  } elseif {$obj == "noh"} {
    set trace_only 0
    set bb_only 0
  }
}


proc rmsdtt::update_swap_types {} {
  variable w
  variable swap_type
  variable swap_use

  if {!$swap_use} {return}
  
  $w.top.left.swap.type.menu delete 0 end
  $w.top.left.swap.type.menu add radiobutton -value "all" -label "all" -variable ::rmsdtt::swap_type

  foreach r [array names ::swap::swap_list] {
    lappend types [lindex $::swap::swap_list($r) 0]
  }
  foreach t [lsort -unique $types] {
    $w.top.left.swap.type.menu add radiobutton -value $t -label $t -variable ::rmsdtt::swap_type
  }
  
}


proc rmsdtt::data_yset args {
  variable w
  eval [linsert $args 0 $w.data.scrbar set]
  [namespace current]::data_yview moveto [lindex [$w.data.scrbar get] 0]
}


proc rmsdtt::data_yview args {
  variable datalist
  foreach key [array names datalist] {
    eval [linsert $args 0 $datalist($key) yview]
  }
}


proc rmsdtt::multiple_sel {widget} {
  variable datalist

  set sel [$widget curselection]
  foreach key [array names datalist] {
    $datalist($key) selection clear 0 end
    foreach item $sel {
      $datalist($key) selection set $item
    }
  }
}


proc rmsdtt::mol_del { {selected 0} } {
  variable datalist
  
  if {$selected} {
    set sele [lsort -integer -decreasing [$datalist(mol) curselection]]
    foreach key [array names datalist] {
      foreach s $sele {
	$datalist($key) delete $s
      }
    }
    [namespace current]::color_data
  } else {
    foreach key [array names datalist] {
      $datalist($key) delete 0 end
    }
  }
}


proc rmsdtt::mol_add { {active 0} } {
  variable datalist
  
  foreach key [array names datalist] {
    $datalist($key) delete 0 end
  }
  for {set i 0} {$i < [molinfo num]} {incr i} {
    set molid [molinfo index $i]
    if {$active && ![molinfo $molid get active]} {
      continue
    }      
    foreach key [list avg sd min max num] {
      $datalist($key) insert end ""
    }
    $datalist(id) insert end [format "%2s" $molid]
    $datalist(mol) insert end [format "%s" [molinfo $molid get name]]
  }
  [namespace current]::color_data
}


proc rmsdtt::color_data { {colorize 0} } {
  variable datalist

  set color "grey85"
  for {set i 0} {$i < [$datalist(id) size]} {incr i} {
    if {$colorize} {
      set coln [$datalist(id) get $i]
      while {$coln > 15} {
	set coln [expr $coln - 16]
      }
      set color [index2rgb $coln]
    } else {
      if {$color == "grey80"} {
	set color "grey85"
      } else {
	set color "grey80"
      }
    }
    foreach key [array names datalist] {
      $datalist($key) itemconfigure $i -background $color
    }
  }
}



proc rmsdtt::ListHisotryPullDownMenu {} {
  variable w
  variable bb_only
  variable trace_only
  variable noh

  regsub -all "\#.*?\n" [$w.top.left.sel get 1.0 end] "" temp1
  regsub -all "\n" $temp1 " " temp2
  regsub -all " $" $temp2 "" sel
  if { $trace_only } {
    append sel { [sw: trace]}
  } elseif { $bb_only } {
    append sel { [sw: bb]}
  } elseif { $noh } {
    append sel { [sw: noh]}
  }

  $w.top.left.mods.selectionhistory.m add command -label $sel \
    -command [list rmsdtt::chooseHistoryItem $sel]

}


proc rmsdtt::chooseHistoryItem {sel} {
  variable w
  variable bb_only
  variable trace_only
  variable noh

  regexp {(.*)\s+\[sw:\s+(.*)\]} $sel foo sel_text mod
  $w.top.left.sel delete 1.0 end
  $w.top.left.sel insert end $sel_text
  
  switch $mod {
    trace {
      set trace_only 1
    }
    bb {
      set bb_only 1
    }
    noh {
      set noh 1
    }
  }
  [namespace current]::ctrlbb $mod
}


proc rmsdtt::help_about { {parent .rmsdtt} } {
  set vn [package present rmsdtt]
  tk_messageBox -title "WMC PhysBio - About RMSDTT v$vn" -parent $parent -message \
    "RMSDTT v$vn plugin for VMD

Luis Gracia
Department of Physiology & Biophysics
Weill Medical College of Cornell University
1300 York Avenue
New York, NY 10021

Copyright (C) 2006 Luis Gracia <lug2002@med.cornell.edu> 

"
}
