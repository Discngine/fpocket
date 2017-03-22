#
package provide volmapgui 1.0
package require readcharmmpar

namespace eval VolMapGUI {
  # window
  variable w                         ;# handle to main window
  variable whichmode        "generate"

  #volmap parameters
  variable output_destination  "mol"
  variable dest_molid        top
  variable dest_filename     volmap_out.dx

  variable input_allframes   0
  variable input_combine     "avg"

  variable input_sel         "protein"
  variable input_mol         "top"
  variable input_voltype     "density"
  variable input_res         1.0
  variable input_dist_cutoff 3.0
  variable input_radscale    1.0
  variable input_weight      "mass"
  variable input_usepoints   0
      
  array set volreps          {}
  
  trace remove variable ::vmd_trajectory_read write ::VolMapGUI::update_mol_menus
  trace remove variable ::vmd_molecule write ::VolMapGUI::update_mol_menus
}

##
## Main routine
## Create the window and initialize data structures
##
proc volmapgui_tk {} {
  VolMapGUI::create_gui
  return $VolMapGUI::w
}

proc VolMapGUI::create_gui {} {
  variable w

  # If already initialized, just turn on
  if [winfo exists .volmap] {
    wm deiconify .volmap
    raise .volmap
    return
  }

  # Initialize window
  set w [toplevel .volmap]
  wm title $w "VolMap Tool" 
  wm resizable $w 0 0
  


  # FRAME: header
  frame $w.header
  
if {0} {  ;# Activate then 3 mode panes when feature is available
  grid [label $w.header.descr -text "Select a volumetric map operation:" -justify center] -row 1 -column 1 -columnspan 3 -sticky ew
  
  # FRAME: 3-mode panel
  frame $w.modetitle -padx 1
  grid [radiobutton $w.modetitle.create    -text "Generate"  -indicatoron no -command {VolMapGUI::switch_mode_pane "generate"} -variable VolMapGUI::whichmode -value "generate"  -width 15]  -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [radiobutton $w.modetitle.transform -text "Transform" -indicatoron no -command {VolMapGUI::switch_mode_pane "transform"} -variable VolMapGUI::whichmode -value "transform" -width 15] -row 2 -column 2 -columnspan 1 -sticky ew -pady 2
  grid [radiobutton $w.modetitle.combine   -text "Combine"   -indicatoron no -command {VolMapGUI::switch_mode_pane "combine"} -variable VolMapGUI::whichmode  -value "combine"   -width 15]  -row 2 -column 3 -columnspan 1 -sticky ew -pady 2
  grid columnconfigure $w.modetitle {1 2 3} -uniform 1
    
  labelframe $w.mode -labelwidget $w.modetitle -bd 2 -labelanchor n
} else {
  labelframe $w.mode -text "Generate Volumetric Map:" -bd 2
}


  # SUBFRAME: Generate
  set frame $w.mode.gen
  frame $frame -padx 10 -pady 6
  grid [label $frame.descr -text "Create a volumetric map based on an atomic selection:" -justify left] -row 1 -column 1 -columnspan 3 -sticky w -pady 2

  grid [label $frame.sellabel -text "selection:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.inputsel -textvariable ::VolMapGUI::input_sel] -row 2 -column 2 -columnspan 2 -sticky ew -pady 2  
  grid [label $frame.mollabel -text "molecule:" -anchor w] -row 3 -column 1 -columnspan 1 -sticky ew -pady 2
  #grid [entry $frame.inputmol -textvariable ::VolMapGUI::input_mol] -row 3 -column 2 -columnspan 1 -sticky ew -pady 2  
  tk_optionMenu $frame.inputmol VolMapGUI::input_mol {}
  grid $frame.inputmol -row 3 -column 2 -columnspan 1 -sticky w -pady 2  
  
  
  grid [label $frame.voltypelabel -text "volmap type:" -anchor w] -row 5 -column 1 -columnspan 1 -sticky w -pady 2
  tk_optionMenu $frame.voltypemenu VolMapGUI::input_voltype {}
  grid $frame.voltypemenu -row 5 -column 2 -columnspan 1 -sticky w -pady 2
  $frame.voltypemenu.menu delete 0 last 
  $frame.voltypemenu.menu add radiobutton -label density -value density -variable VolMapGUI::input_voltype -command {VolMapGUI::switch_voltype_pane "density"}  
  $frame.voltypemenu.menu add radiobutton -label distance -value distance -variable VolMapGUI::input_voltype -command {VolMapGUI::switch_voltype_pane "distance"}  
  #$frame.voltypemenu.menu add radiobutton -label ligand -value ligand -variable VolMapGUI::input_voltype -command {VolMapGUI::switch_voltype_pane "ligand"}
  $frame.voltypemenu.menu add radiobutton -label mask -value mask -variable VolMapGUI::input_voltype -command {VolMapGUI::switch_voltype_pane "mask"}
  $frame.voltypemenu.menu add radiobutton -label occupancy -value occupancy -variable VolMapGUI::input_voltype -command {VolMapGUI::switch_voltype_pane "occupancy"}


  labelframe $frame.options -text "Options" -labelanchor n -relief sunken -bd 1;# already created
  grid $frame.options -row 10 -column 1 -columnspan 3 -sticky ew -pady 8 -ipady 6
   
   
  ########## PER VOLTYPE SUB-FRAMES HERE #########

  # VOLTYPE: density
  set frame $w.mode.gen.options.density
  frame $frame
  grid [label $frame.reslabel -text "resolution:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.res -textvariable ::VolMapGUI::input_res] -row 2 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.resunits -text "A" -anchor w] -row 2 -column 4 -columnspan 1 -sticky ew -pady 2
  grid [label $frame.numptslabel -text "atom size:" -anchor w] -row 3 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.numpts -textvariable ::VolMapGUI::input_radscale] -row 3 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.numptsunits -text "x radius" -anchor w] -row 3 -column 4 -columnspan 1 -sticky ew -pady 2
  grid [label $frame.weightlabel -text "weights:" -anchor w] -row 4 -column 1 -columnspan 1 -sticky ew -pady 2
  tk_optionMenu $frame.weight VolMapGUI::input_weight none beta occupancy user mass charge
  grid $frame.weight -row 4 -column 3 -columnspan 1 -sticky ew -pady 2     
  
  # VOLTYPE: distance
  set frame $w.mode.gen.options.distance
  frame $frame
  grid [label $frame.reslabel -text "resolution:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.res -textvariable ::VolMapGUI::input_res] -row 2 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.resunits -text "A" -anchor w] -row 2 -column 4 -columnspan 1 -sticky ew -pady 2
  grid [label $frame.culabel -text "cutoff:" -anchor w] -row 3 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.cut -textvariable ::VolMapGUI::input_dist_cutoff] -row 3 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.cutunits -text "A" -anchor w] -row 3 -column 4 -columnspan 1 -sticky ew -pady 2

  # VOLTYPE: ligand
  set frame $w.mode.gen.options.ligand
  frame $frame
  grid [label $frame.reslabel -text "resolution:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.res -textvariable ::VolMapGUI::input_res] -row 2 -column 3 -columnspan 1 -sticky ew -pady 2 
  grid [label $frame.resunits -text "A" -anchor w] -row 2 -column 4 -columnspan 1 -sticky ew -pady 2 
  grid [label $frame.culabel -text "cutoff:" -anchor w] -row 3 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.cut -textvariable ::VolMapGUI::input_dist_cutoff] -row 3 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.cutunits -text "A" -anchor w] -row 3 -column 4 -columnspan 1 -sticky ew -pady 2 
  
  # VOLTYPE: mask
  set frame $w.mode.gen.options.mask
  frame $frame
  grid [label $frame.reslabel -text "resolution:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.res -textvariable ::VolMapGUI::input_res] -row 2 -column 3 -columnspan 1 -sticky ew -pady 2 
  grid [label $frame.resunits -text "A" -anchor w] -row 2 -column 4 -columnspan 1 -sticky ew -pady 2 
  grid [label $frame.culabel -text "cutoff:" -anchor w] -row 3 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.cut -textvariable ::VolMapGUI::input_dist_cutoff] -row 3 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.cutunits -text "A" -anchor w] -row 3 -column 4 -columnspan 1 -sticky ew -pady 2
  
  # VOLTYPE: occupancy
  set frame $w.mode.gen.options.occupancy
  frame $frame
  grid [label $frame.reslabel -text "resolution:" -anchor w] -row 2 -column 1 -columnspan 1 -sticky ew -pady 2
  grid [entry $frame.res -textvariable ::VolMapGUI::input_res] -row 2 -column 3 -columnspan 1 -sticky ew -pady 2  
  grid [label $frame.resunits -text "A" -anchor w] -row 2 -column 4 -columnspan 1 -sticky ew -pady 2 
  grid [checkbutton $frame.usepoints -text "use point particles (radius = 0)" \
    -variable ::VolMapGUI::input_usepoints] -row 3 -column 1 -columnspan 3 -sticky w -pady 2
    
  ########## END OF VOLTYPE SUB-FRAMES #########
  
  
  set frame $w.mode.gen 
  grid [checkbutton $frame.allframes -text "compute for all frames, and combine using:" \
    -variable ::VolMapGUI::input_allframes] -row 200 -column 1 -columnspan 2 -sticky w -pady 2
  tk_optionMenu $frame.combinemenu VolMapGUI::input_combine avg min max stdev
  grid $frame.combinemenu -row 200 -column 3 -columnspan 1 -sticky ew -pady 2    
  grid columnconfigure $frame {1} -weight 0
  grid columnconfigure $frame {2 3} -weight 1
  grid columnconfigure $frame 3 -minsize 75

  # SUBFRAME: Transform
  set frame $w.mode.trans
  frame $frame -padx 10 -pady 6
  grid [label $frame.descr -text "Apply a sequence of transformations to a given volmap:" -justify left] -row 1 -column 1 -columnspan 3 -sticky w -pady 2
  grid [label $frame.na -text "NOT AVAILABLE YET"] -row 2 -column 1 -columnspan 3 -sticky ew -pady 2
  
  # SUBFRAME: Combine
  set frame $w.mode.combo
  frame $frame -padx 10 -pady 6
  grid [label $frame.descr -text "Apply an operation combining 2 volmaps:"] -row 1 -column 1 -columnspan 3 -sticky ew -pady 2
  grid [label $frame.na -text "NOT AVAILABLE YET"] -row 2 -column 1 -columnspan 3 -sticky ew -pady 2
     
  # FRAME: Output
  labelframe $w.output -text "Output Destination:" -pady 5 -padx 5 -bd 2 -relief groove
  grid [radiobutton $w.output.usedestmol -text "Append to molecule:" \
    -variable ::VolMapGUI::output_destination -value "mol"] -row 1 -column 1 -columnspan 1 -sticky w -pady 2
  tk_optionMenu $w.output.destmol VolMapGUI::dest_molid {}
  grid $w.output.destmol -row 1 -column 2 -columnspan 1 -sticky w -pady 2  
  #grid [entry $w.output.destmol \
  #  -textvariable ::VolMapGUI::dest_molid] -row 1 -column 3 -columnspan 1 -sticky w -pady 2  
  grid [radiobutton $w.output.usedestfile -text "Write to file:" \
    -variable ::VolMapGUI::output_destination -value "file"] -row 2 -column 1 -columnspan 1 -sticky w -pady 2
  grid [entry $w.output.destfile \
    -textvariable ::VolMapGUI::dest_filename] -row 2 -column 2 -columnspan 1 -sticky w -pady 2    
  grid [button $w.output.browse -text "Browse..." -command "VolMapGUI::dialog_getdestfile $w" -width 7] -row 2 -column 3 -columnspan 1 -sticky w -pady 2 -padx 2
  grid columnconfigure $w.output 2 -minsize 10 ;# spacer
  
  
  # FRAME: do it button
  frame $w.doit
  grid [button $w.doit.button -text "Create Map" -justify center -command VolMapGUI::go ] -row 1 -column 2 -columnspan 2 -sticky ew
  grid [button $w.doit.helpbutton -text "?" -justify center -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/volmapgui" -anchor w] -row 1 -column 5 -columnspan 1 -sticky w
  grid columnconfigure $w.doit {1 2 3 4 5} -minsize 10;# spacer
   
  pack $w.header $w.mode $w.output $w.doit -side top -padx 10 -pady 5 -fill x -expand 1



  # Update panes
  VolMapGUI::update_mol_menus
  VolMapGUI::switch_mode_pane $VolMapGUI::whichmode
  VolMapGUI::switch_voltype_pane $VolMapGUI::input_voltype
  trace add variable ::vmd_trajectory_read write ::VolMapGUI::update_mol_menus
  trace add variable ::vmd_molecule write ::VolMapGUI::update_mol_menus
}




proc VolMapGUI::switch_mode_pane {whichpane} {
  variable w

  pack forget $w.mode.gen $w.mode.trans $w.mode.combo
  
  switch $whichpane {
    "generate" {
      pack $w.mode.gen -expand 1 -fill x -anchor center 
    }
    "transform" {
      pack $w.mode.trans -expand 1 -fill x -anchor center 
    }
    "combine" {
      pack $w.mode.combo -expand 1 -fill x -anchor center
    }
  }
}


proc VolMapGUI::switch_voltype_pane {whichvoltype} {
  variable w
  set frame $w.mode.gen.options
  grid forget $frame.density $frame.distance $frame.occupancy $frame.mask $frame.ligand
  grid $frame.$whichvoltype -row 20 -column 1 -columnspan 3 -sticky ew
}


# traced command to autoupdate menus when number of mols is changed
proc VolMapGUI::update_mol_menus {args} {
  variable w
  
  set mollist [molinfo list]
  set some_mols_have_coords 0
  
  set menu $w.mode.gen.inputmol.menu
  $menu delete 0 last
  $menu add radiobutton -label top -value top -variable VolMapGUI::input_mol
  if [llength $mollist] {
    $menu add separator
  } 
  foreach mol $mollist {
    $menu add radiobutton -label "$mol: [molinfo $mol get name]" -value $mol -variable VolMapGUI::input_mol
    if {[molinfo $mol get frame] < 0} {
      $menu entryconfigure [expr $mol + 2] -state disabled
    } else {
      set some_mols_have_coords 1
    }
  }
  if {!$some_mols_have_coords} {
    $menu entryconfigure 0 -state disabled
  }
  
  set menu $w.output.destmol.menu
  $menu delete 0 last
  $menu add radiobutton -label top -value top -variable VolMapGUI::dest_molid
  $menu add radiobutton -label new -value new -variable VolMapGUI::dest_molid
  if [llength $mollist] {
    $menu add separator
  } else {
    $menu entryconfigure 0 -state disabled
  }
  foreach mol $mollist {
    $menu add radiobutton -label "$mol: [molinfo $mol get name]" -value $mol -variable VolMapGUI::dest_molid
  }
}





proc VolMapGUI::go {} {
  variable w
  
  switch $VolMapGUI::whichmode {
    "generate" {
      set sel [atomselect $VolMapGUI::input_mol $VolMapGUI::input_sel]
      set volcmd [list volmap $VolMapGUI::input_voltype $sel -res $VolMapGUI::input_res]
    }
    "transform" {
      puts "OPERATION NOT SUPPRTED YET"
      return
    }
    "combine" {
      puts "OPERATION NOT SUPPRTED YET"
      return
    }
  }
  
  
  if { $VolMapGUI::whichmode == "generate" }  {
    # param: cutoff
    if { $VolMapGUI::input_voltype == "distance" || $VolMapGUI::input_voltype == "mask"}  {
      lappend volcmd -cutoff
      lappend volcmd $VolMapGUI::input_dist_cutoff
    }

    # param: radscale
    if { $VolMapGUI::input_voltype == "density"}  {
      lappend volcmd -radscale
      lappend volcmd $VolMapGUI::input_radscale
    }
    
    # param: weights
    if { $VolMapGUI::input_voltype == "density" && "$VolMapGUI::input_weight" != "none" }  {
      lappend volcmd -weight
      lappend volcmd $VolMapGUI::input_weight
    }
     
    # param: usepoints
    if { $VolMapGUI::input_voltype == "occupancy" && [string is true $VolMapGUI::input_usepoints] }  {
      lappend volcmd -points
    }
    
    # param: allframes
    if { $VolMapGUI::input_allframes }  {
      lappend volcmd -allframes
      lappend volcmd -combine
      lappend volcmd $VolMapGUI::input_combine
    }
  }
  
  if { $VolMapGUI::output_destination == "mol" }  {
    if { "$VolMapGUI::dest_molid" == "new" } {
      set VolMapGUI::dest_molid [mol new]
      VolMapGUI::update_mol_menus
    }
    lappend volcmd -mol
    lappend volcmd $VolMapGUI::dest_molid
  }
  
  if { $VolMapGUI::output_destination == "file"} {
    lappend volcmd -o
    lappend volcmd $VolMapGUI::dest_filename
  }

  puts "running: $volcmd"
  eval $volcmd
  
  if { $VolMapGUI::output_destination == "mol" }  {
  ### The goal here is to show the computed rep. However, since its impossible
  ### to get the num volids for a molecules, this can't be done!
  ### So we chest and show the last volumetric map by assuming that all volmaps
  ### are generated by this plugin, and simply counting...
    set mol $VolMapGUI::dest_molid
    if {"$mol" == "top"} {set mol [molinfo top]}
    
    if {![info exists VolMapGUI::volreps($mol,repname)] || [mol repindex $mol $VolMapGUI::volreps($mol,repname)] < 0} {
      # create new rep:
      mol color ColorID 8
      mol rep Isosurface 0.5 0 0 0 1  ;# find way to show last volume!!!
      mol selection all
      mol material Opaque
      mol addrep $mol
     
      set VolMapGUI::volreps($mol,repname) [mol repname $mol [expr [molinfo top get numreps] - 1]]
      set VolMapGUI::volreps($mol,volid) 0
    } else {
      #update old rep:
      set rep [mol repindex $mol $VolMapGUI::volreps($mol,repname)]
      incr VolMapGUI::volreps($mol,volid)
      mol modstyle $rep $mol Isosurface 0.5 $VolMapGUI::volreps($mol,volid) 0 0 1
    }
  }
}



proc VolMapGUI::dialog_getdestfile {parent} {
  set newfile [tk_getSaveFile -title "Save volmap as..." -parent $parent -defaultextension .dx -filetypes {{"DX File" .dx} {"All files" *}}]
  if {[string length $newfile] > 0} {
    set VolMapGUI::dest_filename $newfile
    set VolMapGUI::output_destination "file"
  }
}




##################################################################################
#
#  The following procs are used to get VDW parameters from a list of charmm params 
#  files, for use with the ligand and slow ligand map types. They should be 
#  supplanted by the use of the readcharmmpar package, and also needs to be made 
#  safer (i.e. reentrant). But for now, this works well.
#
##################################################################################


proc VolMapGUI::readcharmmparams {args} {
  global nonbonded_table nonbonded_wildcard_list
  set nonbonded_list {}
  set nonbonded_wildcard_list {}
  
  if ![llength $args] {
    set args [list [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]]
  }
  
  foreach parfile $args {
    set file [open $parfile "r"]

    #Find start of NONBONDED section
    while {[gets $file line] >= 0} {
      if {[lindex [split $line] 0] == "NONBONDED"} {break}
    }
  
    #Read NONBONDED params
    while {[gets $file line] >= 0} {
      if {[lindex [split $line] 0] == "HBOND"} break
      if {[lindex [split $line] 0] == "END"} break
      if {[lindex [split $line] 0] == "BONDS"} break
      if {[lindex [split $line] 0] == "IMPROPER"} break
      if {[lindex [split $line] 0] == "ANGLES"} break
      if {[lindex [split $line] 0] == "DIHEDRALS"} break
            
      if {[scan $line "%s %*f %f %f" type epsilon rmin] == 3} {
        if {[string index $line 0] == "!"} {
          set type [string range $type 1 end]
          if [string match "*\[%/*]*" $type] {
            set replaceindex [string first "%" $type]
            if {$replaceindex >= 0} {set type [string replace $type $replaceindex $replaceindex "?"]}
            #puts "WILDCARD $type $epsilon $rmin"
            set nonbonded_wildcard_list [linsert $nonbonded_wildcard_list 0 "$epsilon $rmin"]
            set nonbonded_wildcard_list [linsert $nonbonded_wildcard_list 0 $type]
          }
        } else {
          #puts "$type $epsilon $rmin"
          lappend nonbonded_list $type
          lappend nonbonded_list "$epsilon $rmin"
        }
      }
    }
  
    close $file
  }

  array unset nonbonded_table
  array unset nonbonded_wc_table
  array set nonbonded_table $nonbonded_list
  
  #puts  $nonbonded_wildcard_list

}




proc VolMapGUI::assigncharmmparams {{molid top}} {
  global nonbonded_table nonbonded_wildcard_list
  set atomtypes [[atomselect $molid all] get type]

  set atomradii {}
  set atomepsilon {}
  set atomnotfound {}
  
  foreach type $atomtypes {
    if [catch {
      lappend atomradii [lindex $nonbonded_table($type) 1]
      lappend atomepsilon [lindex $nonbonded_table($type) 0]
    }] {
      set foundmatch false 
      foreach {pattern data} $nonbonded_wildcard_list {
        if [string match $pattern $type] {
          lappend atomradii [lindex $data 1]
          lappend atomepsilon [lindex $data 0]
          set foundmatch true
          break
        }
      }
      
      if !$foundmatch {
        lappend atomradii 0.
        lappend atomepsilon 0.
        lappend atomnotfound $type
      }
    } 
  }
  
  if {[llength $atomnotfound] > 0} {
     set atomnotfound [lsort -unique $atomnotfound]
     foreach type $atomnotfound {
       puts "Could not find parameters for atom type $type"
     }
  }
  
  [atomselect $molid all] set radius $atomradii
  [atomselect $molid all] set occupancy $atomepsilon
}


