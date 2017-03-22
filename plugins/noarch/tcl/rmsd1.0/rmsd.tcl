##
## RMSD Tool 1.0
##
## A GUI interface for RMSD alignment
##
## Authors: Alexander Balaeff, Pascal Mercier, John Stone
##
## $Id: rmsd.tcl,v 1.6 2003/07/22 15:26:18 johns Exp $
##

##
## Example code to add this plugin to the VMD extensions menu:
##
#  if { [catch {package require rmsdtool} msg] } {
#    puts "VMD RMSD package could not be loaded:\n$msg"
#  } elseif { [catch {menu tk register "rmsd" rmsdtool} msg] } {
#    puts "VMD RMSD could not be started:\n$msg"
#  }

# Plugin-ized version of a modified version of the VMD RMSD script

# Authors:
#   Alexander Balaeff, PhD, TB Group, UIUC
#   Pascal Mercier, PhD, Biochemistry Dept, Univ. of Alberta, Edmonton, Canada
#   John Stone, TB Group, UIUC

# Tell Tcl that we're a package and any dependencies we may have
package provide rmsdtool 1.0

namespace eval ::RMSDTool:: {
  namespace export rmsdtool
  variable w                         ;# handle to main window
  variable rms_ave                   ;# array of rms ave
  variable rms_list                  ;# list of rms values
  variable pdb_list                  ;# list of pdb files
  variable bb_only                   ;# backbon-only settings
  variable rms_sel                   ;# rms selection text
  variable rmsd_base                 ;# which molecule is the reference for rmsd calc.
  variable tot_rms                   ;# total rms value 
  variable RMSDhistory				 ;# history of selections
  
	option add *Font {Helvetica -12}
  # Original color scheme by Alexander/Pascal
  #  variable ftr_bgcol   \#2a4
  #  variable ftr_fgcol   \#ff0
  #  variable calc_bgcol  \#24a
  #  variable calc_fgcol  \#ff0
  #  variable sel_bgcol   \#333
  #  variable sel_fgcol   \#ccc
  #  variable act_bgcol   \#0b4
  #  variable act_fgcol   \#f00
  #  variable entry_bgcol \#a64da6
  #  variable but_abgcol  \#26c
  #  variable but_bgcol   \#338
  #  variable scr_trough  \#126

  # Calmer color scheme that looks like other plugins
  variable ftr_bgcol   \#d9d9d9
  variable ftr_fgcol   \#000
  variable calc_bgcol  \#d9d9d9
  variable calc_fgcol  \#000
  variable sel_bgcol   \#ff0
  variable sel_fgcol   \#000
  variable act_bgcol   \#d9d9d9
  variable act_fgcol   \#000
  variable entry_bgcol \#fff
  variable but_abgcol  \#d9d9d9
  variable but_bgcol   \#d9d9d9
  variable scr_trough  \#c3c3c3
}

proc ::RMSDTool::get_molid_from_pdb_list_to_operate_on {} { 
  variable pdb_list
  set all_mols {}
  set listedpdbs [$pdb_list get 0 end]

  foreach pdb $listedpdbs { lappend all_mols [lindex $pdb 0] }
    return $all_mols
}


proc ::RMSDTool::molactive {} {
  set mol_active_list {}
  set all_mols [molinfo list]
    
  foreach i $all_mols  {
    if { [molinfo $i get active] } {
      set mol_active_list [concat $mol_active_list $i]
    }
  }

  return $mol_active_list
}

proc ::RMSDTool::align { sel1 sel2 } {
  # tries to align sel1 with sel2, using the atoms of each selection.
  # If sel1 and sel2 contain a different number of atoms, it fails.

  set tmatrix [measure fit $sel1 $sel2]
  set molid [$sel1 molid]
  set move_sel [atomselect $molid "all"]
  $move_sel move $tmatrix
  return $tmatrix
}


proc ::RMSDTool::align_all {sel_text rmsd_base} {
  variable pdb_list
  set all_mols [get_molid_from_pdb_list_to_operate_on]
  
  
   foreach i $all_mols  {set sel($i) [atomselect $i $sel_text]}
  # do the top molecule as well, just in case it's not in the list
  set mol_on_top [molinfo top] 
  set sel($mol_on_top) [atomselect $mol_on_top $sel_text]
    
  switch $rmsd_base {
    top {set reference_for_alignment [molinfo top]}
    selected {set reference_for_alignment [lindex [$pdb_list get active] 0]}
  }
    
  foreach i $all_mols  {
    if { $i != $reference_for_alignment } {
      align $sel($i) $sel($reference_for_alignment)
    }
  }
}


proc ::RMSDTool::get_rmsd { mol1 mol2 sel_text } {
  set sel1 [atomselect $mol1 $sel_text] 
  set sel2 [atomselect $mol2 $sel_text]
  measure rmsd $sel1 $sel2
}


proc ::RMSDTool::ini_zero {length} {
  if {$length<=0} return {}

  set half_l [expr $length>>1]
  set s {{0 0 0}}
  for {set i 1} {$i<$half_l} {set i [expr $i<<1]} {
    set s [concat $s $s]
  }

  set more [expr $length-$i-1]
  set s [concat $s [lrange $s 0 $more]]

  return $s
}


proc ::RMSDTool::ave_struc {sel_text} {
  set all_mols [get_molid_from_pdb_list_to_operate_on]
  set n_mols [llength $all_mols]
  set factor [expr 1./$n_mols]
  set mol_on_top [molinfo top]

  foreach i $all_mols {
    set all_coor($i) [[atomselect $i $sel_text] get {x y z}]
  }
  
  set ave_coor {}
  set m0 [lindex $all_mols 0]
  set len [llength $all_coor($m0)]

  for {set j 0} {$j<$len} {incr j} {
    set b [veczero]
    foreach i $all_mols {
      set b [vecadd $b [lindex $all_coor($i) $j]]
    }
    lappend ave_coor [vecscale $b $factor]
  }

  return $ave_coor
}


proc ::RMSDTool::compute_rms {base sel_text} {
  variable rms_ave 
  variable rms_disp 
  variable pdb_list

  set all_mols [get_molid_from_pdb_list_to_operate_on]
  set mol_on_top [molinfo top]
  set n_mols [llength $all_mols]
  # 1 will be subtracted from n_mols if the RMSD is calculated against the top molecule 
  # and if the top molecule is part of the listed pdbs
  # or the selected item in the pdb list, see below
    
  foreach i $all_mols {
    set all_coor($i) [[atomselect $i $sel_text] get {x y z}]
  }
    
  # do the top molecule as well, just in case it's not in the pdb list and is selected for RMSD calculation
  set all_coor($mol_on_top) [[atomselect $mol_on_top $sel_text] get {x y z}]
  
  
  switch $base {
    top {
      set ave_coor $all_coor($mol_on_top)
      set len [llength $ave_coor]
      # check if the top molecule is listed in the pdb list
      # if so, need to adjust n_mols
      set isthere [lsearch $all_mols $mol_on_top]
      if {$isthere>=0} {incr n_mols -1}
    }
  
    ave {
      set ave_coor {}
      set m0 [lindex $all_mols 0]
      set len [llength $all_coor($m0)]
      set factor [expr 1./$n_mols]
      for {set j 0} {$j<$len} {incr j} {
        set b [veczero]
        foreach i $all_mols {
          set b [vecadd $b [lindex $all_coor($i) $j]]
        }
        lappend ave_coor [vecscale $b $factor]
      }
    }
  
    selected {
      set index [lindex [$pdb_list get active] 0]
      set ave_coor $all_coor($index) 
      set len [llength $ave_coor]
      incr n_mols -1
    }
  }

  set factor [expr 1./$n_mols]
 
  set tot_rms 0
  foreach i $all_mols {
    set r 0
    for {set j 0} {$j<$len} {incr j} {
      set v1 [lindex $ave_coor $j]
      set v2 [lindex $all_coor($i) $j]
      set r [expr $r + [veclength2 [vecsub $v1 $v2]]]
    }
    set r [expr $r/$len]
    set tot_rms [expr $tot_rms + $r]
    set rms_ave($i) [expr sqrt($r)]
    # set tot_rms [expr $tot_rms + $rms_ave($i)]
  }

  # set tot_rms [expr $tot_rms/$n_mols]
  set tot_rms [expr sqrt($tot_rms/$n_mols)]

  return $tot_rms
}


proc ::RMSDTool::reveal_rms {} {
  variable rms_ave 
  variable rms_list 
  variable pdb_list

  set all_mols [get_molid_from_pdb_list_to_operate_on]
 
  $pdb_list delete 0 end
  $rms_list delete 0 end
    
  foreach i $all_mols {
    $pdb_list insert end [format "%-4s%-10s" $i [molinfo $i get name]]
    $rms_list insert end $rms_ave($i)
  }
}



proc ::RMSDTool::two_scroll args {
	variable pdb_list 
	variable rms_list
	eval "$pdb_list yview $args"
	eval "$rms_list yview $args"
}



# This gets called by VMD the first time the menu is opened.
proc rmsdtool_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::RMSDTool::w  }]  ;# destroy any old windows

  ::RMSDTool::rmsdtool   ;# start the RMSD Tool
  return $RMSDTool::w
}


proc RMSDTool::ListHisotryPullDownMenu {} {
  variable RMSDhistory
  set rc_win .rmsdtool.top.left.inner
  $rc_win.selectionhistory.m delete 0 end
  foreach sel $RMSDhistory {
  	$rc_win.selectionhistory.m add command -label $sel \
  	 -command [list RMSDTool::chooseHistoryItem $sel]
  }
}


proc ::RMSDTool::chooseHistoryItem {sel} {
	variable rms_sel
	set rms_sel $sel
}



proc ::RMSDTool::rmsdtool {} {
  variable w ;# Tk window
  variable bb_only 
  variable pdb_list
  variable rms_ave 
  variable rms_list 
  variable rms_sel 
  variable rmsd_base
  variable tot_rms 
  variable rms_disp
  variable RMSDhistory
  
  variable ftr_bgcol 
  variable ftr_fgcol 
  variable calc_bgcol
  variable calc_fgcol
  variable sel_bgcol
  variable sel_fgcol
  variable act_bgcol   
  variable act_fgcol   
  variable entry_bgcol 
  variable but_abgcol  
  variable but_bgcol   
  variable scr_trough 

  #  Set several parameters.
  set bb_only 1
  set RMSDhistory ""
  set rms_sel {residue 5 to 85}
  set rmsd_base {top}
  set tot_rms {}

  # If already initialized, just turn on
  if { [winfo exists .rmsdtool] } {
    wm deiconify $w
    return
  }

  # Create the window for the RMSD calculations.
  set w [toplevel ".rmsdtool" -bg $calc_bgcol]
  wm title $w "RMSD Tool"
  wm resizable $w 0 0

  # Create the top part with selection windows and 
  # the "Calculate" button

  # Selection part.
  set calc_top [frame $w.top -bg $calc_bgcol]

  frame $calc_top.left -relief ridge -bd 4 -bg $calc_bgcol
  set rc_win [frame $calc_top.left.inner -bg $calc_bgcol -bd 0]
  frame $rc_win.selfr -relief sunken -bd 4 -bg $calc_bgcol

  entry $rc_win.selfr.sel -bd 0 -highlightthickness 0 -insertofftime 0 \
    -bg $entry_bgcol -selectbackground $sel_bgcol -selectforeground $sel_fgcol \
    -selectborderwidth 0 -exportselection yes \
    -textvariable [namespace current]::rms_sel


	bind $rc_win.selfr.sel <Return> [namespace code {
     lappend RMSDhistory [.rmsdtool.top.left.inner.selfr.sel get] 
     ListHisotryPullDownMenu
    } ]
    

  checkbutton $rc_win.bb -highlightthickness 0 \
    -activebackground $calc_bgcol -bg $calc_bgcol \
    -fg $calc_fgcol -activeforeground $calc_fgcol \
    -width 15 \
    -text {Backbone only} -variable [namespace current]::bb_only

  menubutton  $rc_win.selectionhistory \
        -menu $rc_win.selectionhistory.m -padx 5 -pady 4 \
        -text {History} -relief raised \
        -direction flush


   menu $rc_win.selectionhistory.m

  # Button part.
  frame $calc_top.right -bg $calc_bgcol
  frame $calc_top.right.pushfr -relief ridge -bd 4 -bg $calc_bgcol

  button $calc_top.right.rmsd -relief raised -bd 4 -highlightthickness 0 -text {RMSD} \
    -activebackground $but_abgcol -bg $but_bgcol \
    -fg $calc_fgcol -activeforeground $calc_fgcol \
    -command [namespace code { \
      if { $bb_only } { \
    set tot_rms [compute_rms $rmsd_base [concat "(" $rms_sel ") and backbone"]] \
      } else { \
    set tot_rms [compute_rms $rmsd_base $rms_sel]}; \
      reveal_rms  } ] 

  
   button $calc_top.right.align -relief raised -bd 4 -highlightthickness 0 -text {Align} \
    -activebackground $act_bgcol -bg $but_bgcol \
    -activeforeground $act_fgcol -fg $ftr_fgcol  \
    -command [namespace code {
    if {$rmsd_base=="ave"} {bell;puts "you must choose Top or Selected for Alignment";return}
    if { $bb_only } {
          set arg1  [concat "(" $rms_sel ") and backbone"] 
        } else {
          set arg1 $rms_sel 
        }
        align_all $arg1 $rmsd_base
      } ]
  
  
  frame $calc_top.right.switch -bg $calc_bgcol -relief ridge -bd 4

  radiobutton $calc_top.right.switch.0 -highlightthickness 0 \
    -activebackground $calc_bgcol -bg $calc_bgcol \
    -fg $calc_fgcol -activeforeground $calc_fgcol \
    -text {Top} -variable [namespace current]::rmsd_base -value "top"

  radiobutton $calc_top.right.switch.1 -highlightthickness 0 \
    -activebackground $calc_bgcol -bg $calc_bgcol \
    -fg $calc_fgcol -activeforeground $calc_fgcol \
    -text {Average} -variable [namespace current]::rmsd_base -value "ave"

  radiobutton $calc_top.right.switch.2 -highlightthickness 0 \
    -activebackground $calc_bgcol -bg $calc_bgcol \
    -fg $calc_fgcol -activeforeground $calc_fgcol \
    -text {Selected} -variable [namespace current]::rmsd_base -value "selected"

  # Pack the top part widgets.
  pack $calc_top -side top -fill both -expand 1 

  ### ...selection...
  pack $calc_top.left -side left -fill both -expand 1
  pack $rc_win -side left -fill both -expand 1
  pack $rc_win.selfr -side top -fill both -expand 1 -padx 4 -pady 4
  pack $rc_win.bb -side left 
  pack $rc_win.selectionhistory -side right
  pack $rc_win.selfr.sel -side top -fill both -expand 1
  pack $rc_win.selfr.sel -side top -fill both -expand 1
  
  ### ...button...
  pack $calc_top.right -side left -fill both
  pack $calc_top.right.pushfr -side top -fill x -expand 1
  pack $calc_top.right.rmsd $calc_top.right.align -side left -fill x -expand 1 -in $calc_top.right.pushfr
  pack $calc_top.right.switch -side top -fill both
  #pack $calc_top.right.switch.from $calc_top.right.switch.frame -side top -fill both
  #pack $calc_top.right.switch.frame -side top -fill both
  pack $calc_top.right.switch.0 $calc_top.right.switch.1 $calc_top.right.switch.2\
    -side left -fill both -padx 2 -pady 2


  # Create the bottom part, displaying the RMSDs of
  # all the molecules from the average structure.
  set calc_mid [frame $w.middle -relief ridge -bd 4 -bg $calc_bgcol]

frame $calc_mid.titlebar -bg $calc_bgcol -relief raised -bd 2
frame $calc_mid.titlebar.left -bg $calc_bgcol

grid rowconfigure    $calc_mid.titlebar	0 -pad 0  -weight 100
grid columnconfigure $calc_mid.titlebar 0 -pad 0  -weight 100
grid $calc_mid.titlebar.left -in $calc_mid.titlebar -column 0 -row 0 -columnspan 1 -rowspan 1 -ipadx 0 -ipady 0 -padx 0 -pady 0 -sticky nesw

frame $calc_mid.titlebar.right -bg $calc_bgcol
grid rowconfigure    $calc_mid.titlebar 0	 -pad 0  -weight 100
grid columnconfigure $calc_mid.titlebar 1  -pad 0  -weight 100
grid $calc_mid.titlebar.right -in $calc_mid.titlebar -column 1 -row 0 -columnspan 1 -rowspan 1 -ipadx 0 -ipady 0 -padx 0 -pady 0 -sticky nesw

 label $calc_mid.titlebar.left.label -text {ID   Molecule}  \
    -bg $calc_bgcol -fg $calc_fgcol \
    -padx 3 -pady 3
    
    label $calc_mid.titlebar.right.label -text {RMS deviations:} \
    -bg $calc_bgcol -fg $calc_fgcol \
    -padx 3 -pady 3
    
  set rms_disp [frame $w.middle.body -bg $calc_bgcol]
  frame $rms_disp.left -bg $calc_bgcol -bd 0
  frame $rms_disp.right -bg $calc_bgcol -bd 0

  set pdb_list [listbox $rms_disp.pdb_names -relief raised -bd 2 -height 10 \
      -bg $calc_bgcol -fg $calc_fgcol \
      -highlightthickness 0 -highlightbackground $calc_bgcol \
      -yscrollcommand [namespace code {$rms_disp.scrbar set}] \
			]

  set rms_list [listbox $rms_disp.rms_values -relief raised -bd 2 -height 10 \
      -bg $calc_bgcol -fg $calc_fgcol  \
      -highlightthickness 0 -highlightbackground $calc_bgcol \
      -yscrollcommand [namespace code {$rms_disp.scrbar set}] \
			]

  set all_mols [molactive]
  foreach i $all_mols {
    $pdb_list insert end [format "%-4s%-10s" [molinfo index $i] [molinfo $i get name]]
    set rms_ave($i) {}
    $rms_list insert end $rms_ave($i)
  }

  set rmstot_lbl [label $rms_disp.rmstot_lbl -text {Total RMSD:} -anchor w -pady 3 \
      -bg $calc_bgcol -relief raised -bd 2 -fg $calc_fgcol]
  set rmstot_val [label $rms_disp.rmstot_val -textvariable [namespace current]::tot_rms -anchor w -pady 3 \
      -bg $calc_bgcol -relief raised -bd 2 -fg $calc_fgcol]


  scrollbar $rms_disp.scrbar \
    -relief raised -activerelief raised -bd 2 -elementborderwidth 2 \
    -bg $calc_bgcol -troughcolor $scr_trough -highlightthickness 0 \
    -activebackground $but_abgcol \
    -orient vert \
    -command  {RMSDTool::two_scroll}
   

  # Pack the bottom part widgets.
  pack $calc_mid.titlebar.left.label  -side left -in  $calc_mid.titlebar.left
  pack $calc_mid.titlebar.right.label -side top -in  $calc_mid.titlebar.right
  
  pack $calc_mid.titlebar -side top -fill x -in  $calc_mid
  pack $calc_mid -side top -fill both -expand 1
  pack $rms_disp -side top -expand 1 -fill both
  pack $rms_disp.left $rms_disp.right -side left -fill both -expand 1
  pack $rms_disp.scrbar -side left -fill y
  pack $pdb_list -side top -fill both -expand 1 -in $rms_disp.left
  pack $rmstot_lbl -side top -fill x -in $rms_disp.left

  pack $rms_list -side top -fill both -expand 1 -in $rms_disp.right
  pack $rmstot_val -side bottom -fill x -in $rms_disp.right

  frame $w.bottom -bg white -height 100
  button $w.bottom.erase -relief raised -bd 4 -highlightthickness 0 -text {Erase from list} \
    -command [namespace code {
    	set indexnum [$pdb_list index active] 
    	$pdb_list delete active 
    	$rms_list delete $indexnum 
    	}] \
    -activebackground $but_abgcol -bg $but_bgcol 
   
  button $w.bottom.allinmem -relief raised -bd 4 -highlightthickness 0 -text {All in memory} \
    -activebackground $but_abgcol -bg $but_bgcol \
    -command [namespace code {
        $pdb_list delete 0 end
        for {set i 0} {$i<[molinfo num]} {incr i} {
          set molid [molinfo index $i]
          $pdb_list insert end [format "%-4s%-10s" [molinfo index $i] [molinfo $molid get name]]      
        }
      } ]

  button $w.bottom.onlyactive -relief raised -bd 4 -highlightthickness 0 -text {Only active} \
    -activebackground $but_abgcol -bg $but_bgcol \
    -command [namespace code {
        $pdb_list delete 0 end
        for {set i 0} {$i<[molinfo num]} {incr i} {
          set molid [molinfo index $i]
          if {[molinfo $molid get active]} {$pdb_list insert end [format "%-4s%-10s" $molid [molinfo $molid get name]]}      
        }
      } ]

  menubutton $w.bottom.assemblymenu \
        -menu $w.bottom.assemblymenu.m -padx 5 -pady 4 \
        -text {Assembly} -relief raised 
    
  pack $w.bottom.erase $w.bottom.allinmem $w.bottom.onlyactive $w.bottom.assemblymenu -in $w.bottom  -side left -fill x -expand 1
  pack $w.bottom -in $w -side bottom -fill x -expand 1    


  menu $w.bottom.assemblymenu.m -postcommand [namespace code {
      set menu $w.bottom.assemblymenu.m
      $menu delete 0 end
      if {[array exist assembly]} {
        set nameofassemblies [array names assembly]
        for {set i 0} {$i<[llength $nameofassemblies]} {incr i} {
          set nameofcurrentassembly [lindex $nameofassemblies $i]

          $menu add  radiobutton -label $nameofcurrentassembly -variable [namespace current]::selectedassembly -value $nameofcurrentassembly \
            -command [namespace code {
                $pdb_list delete 0 end
                $rms_list delete 0 end
          
                foreach pdb $assembly($selectedassembly) {
                  $pdb_list insert end $pdb
                }
              }] 
        }
      }
    } ]


# update the History menu
 RMSDTool::ListHisotryPullDownMenu
 

}
  
