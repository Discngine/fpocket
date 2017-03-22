#
# AUTOIMD USER INTERFACE ELEMENTS AND COMMANDS
#
# $Id: autoimd-gui.tcl,v 1.9 2005/11/01 02:41:55 jordi Exp $
#

# Start the GUI's main window
proc AutoIMD::startGUI { } {
  variable w
  
  # make the initial window
  set w [toplevel ".autoimd"]
  wm title $w "AutoIMD Controls"
  wm resizable $w no no
   
  set buttonfont [font create -family helvetica -weight bold -size 9]
  set labelwidth 9
    
  ##############################
  # Create menubar
  
  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -fill x -side top
  
  menubutton $w.menubar.file -text "File   " -menu $w.menubar.file.menu
  menubutton $w.menubar.settings -text "Settings   " -menu $w.menubar.settings.menu
  pack $w.menubar.file $w.menubar.settings -side left
  
  # File menu
  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Save Full PDB As..." -command "AutoIMD::dialog_savepdb"
  $w.menubar.file.menu add separator
  $w.menubar.file.menu add command -label "Show Simulation Window" -command "menu imd on"
  $w.menubar.file.menu add command -label "Show Tool Window" -command "menu tool on"
  #$w.menubar.file.menu add separator
  #$w.menubar.file.menu add command -label "Show NAMD Log" -command ""

  # Settings menu
  menu $w.menubar.settings.menu -tearoff no
  $w.menubar.settings.menu add command -label "Simulation Parameters..." -command "AutoIMD::dialog_simsettings"
  $w.menubar.settings.menu add separator
  $w.menubar.settings.menu add radiobutton -label "Minimization Mode" -variable AutoIMD::settings::sim_mode -value "minimize"
  $w.menubar.settings.menu add radiobutton -label "Equilibration Mode" -variable AutoIMD::settings::sim_mode -value "equilibrate"
  
  # Help menu
  menubutton $w.menubar.help -text "Help   " -menu $w.menubar.help.menu
  pack $w.menubar.help -side right 
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "AutoIMD Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/autoimd"
              
  ##############################
  # Create Main Window  

  frame $w.win ;# Main contents
  pack $w.win -padx 4 -pady 4
			
  # make a frame for the manipulation selection
  frame $w.win.maniplabel
  label $w.win.maniplabel.label -text "1. Type in the atom selections for imd (top molecule):" -justify right
  pack $w.win.maniplabel.label -anchor nw
  
  frame $w.win.manip
  label $w.win.manip.label -text "imdmolten:" -width $labelwidth -justify left -anchor nw
  entry $w.win.manip.entry -width 30 -textvariable AutoIMD::settings::moltenseltext
  pack  $w.win.manip.label -side left
  pack $w.win.manip.entry -side left -fill x -expand yes
  
  frame $w.win.fixed
  label $w.win.fixed.label -text "imdfixed:" -width $labelwidth -justify left -anchor nw
#  label $w.win.fixed.label2 -text "same residue as" -justify left -anchor nw
  entry $w.win.fixed.entry -width 30 -textvariable  AutoIMD::settings::fixedseltext
  pack $w.win.fixed.label -side left ;#$w.win.fixed.label2 
  pack  $w.win.fixed.entry  -side left -fill x -expand yes
  
  # make a frame for the simulation options
  frame $w.win.procslabel
  label $w.win.procslabel.label -text "2. Choose where and how to run the simulation:" -justify right
  pack $w.win.procslabel.label -anchor nw
  
  frame $w.win.procs
  frame $w.win.procs.server -width 20  ;# XXX DOESN'T WORK AS INTENDED
  tk_optionMenu $w.win.procs.server.servermenu AutoIMD::currentserver {}
  pack $w.win.procs.server.servermenu -expand yes -fill x ;# XXX DOESN'T WORK AS INTENDED
  
  label $w.win.procs.usingtxt -text "using "
  entry $w.win.procs.scale -textvariable AutoIMD::numprocs -width 3
  label $w.win.procs.slash -text "/"
  label $w.win.procs.maxprocs -textvariable AutoIMD::maxprocs
  label $w.win.procs.proctxt -text "processors"
  # Unused for now "Options" button to customize server options in RAM:
  ## button $w.win.procs.options -text "Options..." -command AutoIMD::dialog_customizeServer
  pack $w.win.procs.server $w.win.procs.usingtxt $w.win.procs.scale $w.win.procs.slash $w.win.procs.maxprocs $w.win.procs.proctxt -side left
		
  # make a frame to put the basic controls in
  frame $w.win.controlslabel
  label $w.win.controlslabel.label -text "3. Submit your job:" -justify right
  pack $w.win.controlslabel.label -anchor nw
  
  frame $w.win.controls
  button $w.win.controls.submit -text "Submit" -width 7 -font $buttonfont -command {AutoIMD::submit "$AutoIMD::settings::moltenseltext"}
  button $w.win.controls.connect -text "Connect" -command "AutoIMD::autoconnect" \
      -font $buttonfont
  button $w.win.controls.pause   -text "Pause" -width 7 -command "imd pause toggle" -font $buttonfont
  button $w.win.controls.finish  -text "Finish" -width 7  -command "AutoIMD::finish" -font $buttonfont
  button $w.win.controls.discard -text "Discard" -width 7 -command "AutoIMD::finish -nosave" -font $buttonfont
  pack $w.win.controls.submit $w.win.controls.connect $w.win.controls.pause $w.win.controls.finish $w.win.controls.discard -side left

  # add a status bar indicating what is being done
  frame $w.win.status
  label $w.win.status.label -text "status:"
  label $w.win.status.text -width 30 -anchor nw -textvariable AutoIMD::statustext
  pack $w.win.status.label -side left
  pack $w.win.status.text -side left -fill x -expand yes
  
  # pack the frames
  set padx 10
  set pady 3
  pack $w.win.maniplabel -fill x -expand yes -anchor nw -pady $pady
  pack $w.win.manip -fill x -expand yes -pady $pady -padx $padx
  pack $w.win.fixed -fill x -expand yes -pady $pady -padx $padx 
  pack $w.win.procslabel -fill x -expand yes -anchor nw -pady $pady
  pack $w.win.procs -padx $padx -pady $pady -anchor nw
  pack $w.win.controlslabel -fill x -expand yes -anchor nw -pady $pady
  pack $w.win.controls -padx $padx -pady $pady -anchor nw
  pack $w.win.status -fill x -expand yes -anchor nw -pady $pady
  
  AutoIMD::update_server_menu
}




proc AutoIMD::showstatus {messagetext} {
  set AutoIMD::statustext "$messagetext"
  #update display:
  update idletasks
}

# To be used to update the server configuration
proc AutoIMD::update_server_menu {} {
  variable w

  # Get all servers defined in the AutoIMD::servers namespace
  set servers [list]
  foreach s [lsort [info vars servers::*]] {
    lappend servers [namespace tail $s]
  }

  if ![winfo exists .autoimd] return
  # Rebuild the chooser
  $w.win.procs.server.servermenu.menu delete 0 last
  foreach servername $servers {
    $w.win.procs.server.servermenu.menu add radiobutton -label "$servername" -value "$servername" -variable "AutoIMD::currentserver" -command "AutoIMD::loadsettings \"$servername\""
  }
  
  #	initialize "currentserver" variable
  if {![info exists AutoIMD::currentserver] && [llength $servers]} {
    if {![info exists AutoIMD::currentserver]} {set AutoIMD::currentserver [lindex $servers 0]}
    loadsettings $AutoIMD::currentserver
  }
}



# Callback for whenever IMD receives a new frame
proc AutoIMD::tracetimestep {args} {
  variable imdmol
  
  if { "$settings::sim_mode" == "minimize" }  {
    set AutoIMD::statustext "Minimizing [molinfo $imdmol get timesteps]"
  } else {  
    set timesteps [molinfo $imdmol get timesteps]
    if {$timesteps <= $settings::minimizesteps} {
      set AutoIMD::statustext "Minimizing (timesteps: $timesteps)"
    } else {    
      set force [eval vecadd [[atomselect top all] get {ufx ufy ufz}]]
      set forcenorm [expr sqrt([lindex $force 0]*[lindex $force 0] + [lindex $force 1]*[lindex $force 1] + [lindex $force 2]*[lindex $force 2])]
      set AutoIMD::statustext "Simulating (time: [format "%.2f" [expr 2.*($timesteps - $settings::minimizesteps)/1000.]] ps, force: [format "%.3g" $forcenorm] kcal/mol/A)"
    }
  }
}



######################################################################
### USER DIALOG BOXES                                              ###
######################################################################


proc AutoIMD::dialog_simsettings {} {
  if { [winfo exists ".autoimd_simsettings"] } {
    wm deiconify ".autoimd_simsettings"
    return
  }

  set ws [toplevel ".autoimd_simsettings"]
  wm title $ws "Simulation Parameters"
  wm resizable $ws no no

  # Essential Options...
    
  set labelwidth 15
  
  labelframe $ws.essential -text "Essential Options" -labelanchor n
  labelframe $ws.advanced -text "Advanced Options" -labelanchor n
  pack $ws.essential $ws.advanced -padx 8 -pady 10 -fill x -expand yes 
      
  set frame $ws.essential.scrdir
  frame $frame
  label $frame.label -text "scratch directory:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::scratchdir -width 30 -relief sunken
  button $frame.browse -text "Browse..." -command "AutoIMD::dialog_getscratchdir $ws" -width 7 -pady 1
  pack $frame.label -side left
  pack $frame.entry -side left -fill x -expand yes
  pack $frame.browse -side right -padx 3
  
  set frame $ws.essential.parfiles
  frame $frame
  label $frame.label -text "CHARMM params:" -width $labelwidth -justify right -anchor ne
  frame $frame.list
  scrollbar $frame.list.scroll -command "$frame.list.list yview"
  listbox $frame.list.list -activestyle dotbox -yscroll "$frame.list.scroll set" -setgrid 1 \
      -selectmode browse -listvariable AutoIMD::settings::parfiles -width 40 -height 3
  frame $frame.list.buttons
  button $frame.list.buttons.add -text "Add..." -command "AutoIMD::dialog_getCHARMMparam $ws" -width 7 -pady 1
  set ::AutoIMD::charmmparamslistbox $frame.list.list
  button $frame.list.buttons.delete -text "Delete" -command {
      foreach i [$::AutoIMD::charmmparamslistbox curselection] {
        $::AutoIMD::charmmparamslistbox delete $i
      }
   }  -width 7 -pady 1
  pack $frame.list.buttons.add $frame.list.buttons.delete
  pack $frame.label $frame.list.list $frame.list.scroll  -side left -fill y
  pack $frame.list.buttons  -padx 3
  pack $frame.list 
    
  set frame $ws.essential.temp
  frame $frame
  label $frame.label -text "temperature:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::temperature -width 10 -relief sunken
  label $frame.units -text "K" -justify right
  pack  $frame.label $frame.entry $frame.units -side left
  
  
  # Advanced Options...
  
  set labelwidth 20
  
  set frame $ws.advanced.namdtmpl
  frame $frame
  label $frame.label -text "NAMD config template:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::namdtmplfile -width 30 -relief sunken
  button $frame.browse -text "Browse..." -command "AutoIMD::dialog_getNAMDfile $ws" -width 7 -pady 1
  pack $frame.label -side left
  pack $frame.entry -side left -fill x -expand yes
  pack $frame.browse -side right -padx 3
  
  set frame $ws.advanced.min
  frame $frame
  label $frame.label -text "initial minimization:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::minimizesteps -width 10 -relief sunken
  label $frame.units -text "steps" -justify right
  pack  $frame.label $frame.entry $frame.units -side left
  
  set frame $ws.advanced.dcd
  frame $frame
  label $frame.label -text "DCD save frequency:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::dcdfreq -width 10 -relief sunken
  label $frame.units -text "steps (this uses up disk space!)" -justify right
  pack  $frame.label $frame.entry $frame.units -side left
  
  set frame $ws.advanced.keep
  frame $frame
  label $frame.label -text "VMD keep frequency:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::vmdkeepfreq -width 10 -relief sunken
  label $frame.units -text "steps (this uses up RAM!)" -justify right
  pack  $frame.label $frame.entry $frame.units -side left

  set frame $ws.advanced.imdrate
  frame $frame
  label $frame.label -text "IMD communication rate:" -width $labelwidth -justify right -anchor ne
  entry $frame.entry -textvariable AutoIMD::settings::namdoutputrate -width 10 -relief sunken
  label $frame.units -text "steps" -justify right
  pack  $frame.label $frame.entry $frame.units -side left 
     
  pack $ws.essential.scrdir $ws.essential.parfiles $ws.essential.temp -padx 4 -pady 4 -fill x -expand yes
  pack $ws.advanced.namdtmpl $ws.advanced.min $ws.advanced.dcd $ws.advanced.keep $ws.advanced.imdrate -padx 4 -pady 6 -fill x -expand yes
       
  frame $ws.okbutton
  button $ws.okbutton.okbutton -text "OK" -command "wm withdraw $ws" -width 10 -pady 1
  pack $ws.okbutton.okbutton -side bottom
  pack $ws.okbutton -pady 8
}


proc AutoIMD::dialog_getscratchdir {parent} {
  set newscratchdir [tk_chooseDirectory -title "Choose the scratch directory" -mustexist true -initialdir $settings::scratchdir -parent $parent ]
  if {[string length $newscratchdir] > 0} {set settings::scratchdir $newscratchdir}
}


proc AutoIMD::dialog_savepdb {} {
  set filename [tk_getSaveFile -title "Write to PDB" -parent $AutoIMD::w -filetypes {{"PDB files" {".pdb"}} {"All files" {"*"}}}]
  if {[string length $filename] > 0} {
    if {"$AutoIMD::imdstate" == "connected"} {
      writecompletepdb "$filename"
    } elseif {"$AutoIMD::backgroundmol" != -1} {
      set sel [atomselect $AutoIMD::backgroundmol all] 
      $sel writepdb "$filename"
      $sel delete
    } else {
      set sel [atomselect top all]
      $sel writepdb "$filename"
      $sel delete
    }
  }
}


proc AutoIMD::dialog_getNAMDfile {parent} {
  set filename [tk_getOpenFile -title "Choose a NAMD config file" -parent $parent -filetypes {{"NAMD config files" {"*.namd" "*.conf"}} {"All files files" {"*"}}}]
  if {[string length $filename] > 0} {set settings::namdtmplfile $filename}
}


proc AutoIMD::dialog_getCHARMMparam {parent} {
  set filename [tk_getOpenFile -title "Choose a CHARMM parameter file" -parent $parent -filetypes {{"All files files" {"*"}} {"CHARMM Parameters" {"par*.inp"}} }]
  if {[string length $filename] > 0} {lappend settings::parfiles $filename}
}


proc AutoIMD::dialog_customizeServer { } {
  variable currentserver
  variable buttonfont

  upvar AutoIMD::servers::$currentserver arr
  set ws [toplevel .autoimd.customize]
  wm title $ws "'$currentserver' options"
  wm resizable $ws no no
  frame $ws.controls
  # Can't edit nprocs, maxprocs, or jobtype
  array set dontchange {numprocs 1 maxprocs 1 jobtype 1}
  foreach key [lsort [array names arr]] {
    if [info exists dontchange($key)] { continue }
    label $ws.controls.label$key -text $key 
    entry $ws.controls.entry$key -textvariable AutoIMD::servers::${currentserver}($key) -width 30 -relief sunken
    grid $ws.controls.label$key $ws.controls.entry$key -sticky news
  }
  pack $ws.controls -side top
  button $ws.close -text Close -command "after idle destroy $ws"
  pack $ws.close -side top 
}


proc AutoIMD::dialog_error {errmsg} {
  puts "AutoIMD) $errmsg"
  tk_dialog .autoimd_error "Error" $errmsg {} 0 OK
}


######################################################################
### OTHER                                                          ###
######################################################################

# To register autoimd in VMD's extension menu
proc autoimd_tk {} {
  AutoIMD::startup
  return $AutoIMD::w  
}
