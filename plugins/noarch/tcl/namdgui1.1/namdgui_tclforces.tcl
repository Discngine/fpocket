proc ::NAMDgui::tclforces_gui {} {
   # If already initialized, just turn on
   if { [winfo exists .namdgui_tclforces] } {
      wm deiconify $w
      return
   }
   
   set w [toplevel ".namdgui_tclforces"]
   wm title $w "NAMDgui - TCL forces"
   wm resizable $w 0 0

   # TclForcesScript files
   frame $w.files
   labelframe  $w.files.tcl -bd 2 -text "TclForces scripts" -padx 1m -pady 1m

   frame $w.files.tcl.multi
   scrollbar $w.files.tcl.multi.scroll -command "$w.files.tcl.multi.list yview"
   listbox $w.files.tcl.multi.list -yscroll "$w.files.tcl.multi.scroll set" \
      -width 50 -height 3 -setgrid 1 -selectmode extended -listvariable ::NAMDgui::tclforcesscript
   pack $w.files.tcl.multi.list $w.files.tcl.multi.scroll -side left -fill y -expand 1

   frame  $w.files.tcl.multi.buttons
   button $w.files.tcl.multi.buttons.add -text "Add"    -command {
      ::NAMDgui::opendialog tcl
   }
   button $w.files.tcl.multi.buttons.delete -text "Delete" -command {
      foreach i [.namdgui.files.tcl.multi.list curselection] {
	 .namdgui.files.tcl.multi.list delete $i
      }
   }
   pack $w.files.tcl.multi.buttons.add $w.files.tcl.multi.buttons.delete -expand 1 -fill x
   pack $w.files.tcl.multi.list -side left  -fill x -expand 1
   pack $w.files.tcl.multi.scroll $w.files.tcl.multi.buttons -side left -fill y -expand 1
   pack $w.files.tcl.multi -expand 1 -fill x
   pack $w.files.tcl -pady 1m -padx 2m  -expand 1 -fill x -ipady 1 -ipadx 1
   pack $w.files
}

proc ::NAMDgui::simparams_gui {} {
   # If already initialized, just turn on
   if { [winfo exists .namdgui_simparams] } {
      wm deiconify .namdgui_simparams
      return
   }
   
   set w [toplevel ".namdgui_simparams"]
   wm title $w "NAMDgui - Simulation parameters"
   wm resizable $w 0 0

   ############# frame for output control #################
   labelframe $w.simpar -bd 2 -relief ridge -text "Output control"

   # DCD/XST Output frequency (steps)
   labelentryframe $w.simpar.freq "DCD/XST output frequency (steps):" ::NAMDgui::freq 12
   
   # Energy Output frequency (steps)
   labelentryframe $w.simpar.enout "Energy output frequency (steps):" ::NAMDgui::outputenergies 12
   
   # Restart file frequency (steps)
   labelentryframe $w.simpar.restartfreq "Restart file frequency (steps):" ::NAMDgui::restartfreq 12

   # Binary output
   checkbutton $w.simpar.binoutput -text "Binary output files" -variable ::NAMDgui::binoutput -relief flat \
      -onvalue "yes" -offvalue "no"

   # Binary restart
   checkbutton $w.simpar.binrestart -text "Binary restart files" -variable ::NAMDgui::binrestart -relief flat \
      -onvalue "yes" -offvalue "no"

   pack $w.simpar.freq $w.simpar.enout $w.simpar.restartfreq -pady 3 -padx 3 -anchor e
   pack $w.simpar.binoutput $w.simpar.binrestart -pady 3 -padx 3 -anchor w

   
   ############# frame for time stepping parameters #################
   labelframe $w.tstep -bd 2 -relief ridge -text "Multiple time stepping"

   # Timestep
   labelentryframe $w.tstep.timestep "TimeStep (femtoseconds):" ::NAMDgui::timestep 12
   
   # Nonbonded frequency (steps)
   labelentryframe $w.tstep.nonbfreq "NonbondedFreq (steps):" ::NAMDgui::nonbondedfreq 12
   
   # Full Electrostatic frequency (steps)
   labelentryframe $w.tstep.fullfreq "FullElectFreq (steps):" ::NAMDgui::fullelectfreq 12
   
   # Steps per cycle (steps)
   labelentryframe $w.tstep.stepcycle "StepsPerCycle (steps):" ::NAMDgui::stepspercycle 12
   
   pack $w.tstep.timestep $w.tstep.nonbfreq $w.tstep.fullfreq $w.tstep.stepcycle -pady 3 -padx 3 -anchor e


   ############# frame for basic dynamics parameters #################
   labelframe $w.basic -bd 2 -relief ridge -text "Basic dynamics:"

   # Exclusion policy (1-2, 1-3, 1-4, scaled1-4)
   labelmenubuttonframe $w.basic.exclude "Nonbonded exclusion:" ::NAMDgui::exclude 12 "1-2 1-3 1-4 scaled1-4"
   trace add variable ::NAMDgui::exclude write ::NAMDgui::toggle_exclude

   # 1-4 exclusion scaling factor
   labelentryframe $w.basic.scale14 "1-4 scaling factor:" ::NAMDgui::scale14 12

   toggle_exclude

   # Switch distance
   labelentryframe $w.basic.diel "Dielectric constant:" ::NAMDgui::dielectric 12

   # Toggle COM motion
   checkbutton     $w.basic.com -text "Allow initial COM motion" -variable ::NAMDgui::COMmotion \
      -onvalue "yes" -offvalue "no"

   pack $w.basic.exclude $w.basic.scale14 $w.basic.diel -pady 3 -padx 3 -anchor e
   pack $w.basic.com -pady 3 -padx 3 -anchor w


   ############# frame for simulation space partitioning #################
   labelframe $w.space -bd 2 -relief ridge -text "Simulation space partitioning:"

   # Cutoff distance
   labelentryframe $w.space.cutoff "Cutoff" ::NAMDgui::cutoff  12

   frame $w.space.switch
   # Toggle switching
   checkbutton     $w.space.switch.toggle -text "Switching" -variable ::NAMDgui::switching -onvalue "on" -offvalue "off" \
      -command ::NAMDgui::toggle_switching
   
   # Switch distance
   labelentryframe $w.space.switch.dist "Switch distance" ::NAMDgui::switchdist 12
   pack $w.space.switch.toggle -side left
   pack $w.space.switch.dist   -side right

   # Pairlist distance
   labelentryframe $w.space.pairlistdist "Pairlist distance" ::NAMDgui::pairlistdist 12

   toggle_switching

   pack $w.space.cutoff     -pady 3 -padx 3 -anchor e
   pack $w.space.switch     -pady 3 -padx 3 -anchor w -expand 1 -fill x 
   pack $w.space.pairlistdist -pady 3 -padx 3 -anchor e



   pack $w.simpar $w.tstep $w.basic $w.space -expand 1 -fill x -pady 3 -padx 3
}
  

proc ::NAMDgui::toggle_exclude { args } {
   variable exclude
   if {![winfo exists .namdgui_simparams.basic.scale14.entry]} { return }

   if {$exclude=="scaled1-4"} {
      .namdgui_simparams.basic.scale14.entry configure -state normal
   } else {
      .namdgui_simparams.basic.scale14.entry configure -state disabled
   }
}

proc ::NAMDgui::toggle_switching { args } {
   variable switching
   if {![winfo exists .namdgui_simparams.space.switch.dist.entry]} { return }

   if {$switching} {
      .namdgui_simparams.space.switch.dist.entry configure -state normal
   } else {
      .namdgui_simparams.space.switch.dist.entry configure -state disabled
   }
}

