#
# Setup charmm charges
#
# $Id: paratool_charmmcharges.tcl,v 1.22 2007/05/07 15:38:17 saam Exp $
#

namespace eval ::CHARMMcharge:: {
   proc initialize {} {
      variable chargegroup     
      array set chargegroup {}
      variable formatchargegroup {}
      variable chargegrouplist {}
      variable formatchargegrouplist {}
      variable molidsystem -1
      variable molidwater  -1
      variable molidsyswat -1
      variable molidsyswatopt -1
      variable molnamewater  {}
      variable molnamesyswat {}
      variable molnamesyswatcom {}
      variable molnamesyswatopt {}
      variable targetpos   {}
      variable waterdir    {}
      variable waterangle  0
      variable waterdist   2.2
      variable waterinteract {}
      variable waterpartner {}; # The atom direct interacting with the group
      variable scfsyswat {}
      variable scfsystem {}
      variable scfwater  {}
      variable scfinter  {}
      variable desiredgroupcharge 0.0
      variable unpolargroup 0
      variable betaposhydrogen 1
      variable scaleindexes {}
      variable groupindexes {}
      variable scalesel {}
      variable groupsel {}
      variable curcenter {}
      variable curangle 0
      variable copychargetypes {None}
      variable copycharge "Mullik"
      variable namdserver 0; 
   }
   initialize
}

proc ::CHARMMcharge::setup_charmm_charges {} {
   if {$::Paratool::molidopt<0} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "You must load the optimized geommetry first!"
      return      
   }

   # If already initialized, just turn on
   if { [winfo exists .charmmcharge] } {
      wm deiconify .charmmcharge
      raise .charmmcharge
      return
   }

   set v [toplevel ".charmmcharge"]
   wm title $v "CHARMM style charges"
   wm resizable $v 0 0
   wm protocol $v WM_DELETE_WINDOW {
      # Delete system+water molecules
      if {$::CHARMMcharge::molidwater>=0} { mol delete $::CHARMMcharge::molidwater }
      if {$::CHARMMcharge::molidsyswat>=0} { mol delete $::CHARMMcharge::molidsyswat }
      if {$::CHARMMcharge::molidsyswatopt>=0} { mol delete $::CHARMMcharge::molidsyswatopt }

      # Remove traces
      global vmd_pick_atom
      trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn
      mouse mode 0
      mouse callback off;
      set ::Paratool::picklist {};
      set ::Paratool::pickmode "conf"; 
      destroy .charmmcharge
      destroy .charmmcharge_balance
   }

   variable ::Paratool::fixedfont

   ################ frame for charge group list #################
   labelframe $v.group -bd 2 -relief ridge -text "Select charge group"  -padx 2 -pady 2
   label $v.group.label -wraplength 13c -justify left -text "A charge group is a group of atoms whose charges are scaled such that the CHARMM interaction energy with TIP3 water equals the QM based interaction energy."

   frame $v.group.list
   label $v.group.list.format -text "Natoms  Initial   Supram Center" -font $fixedfont
   scrollbar $v.group.list.scroll -command "$v.group.list.list yview"
   listbox $v.group.list.list -activestyle dotbox -yscroll "$v.group.list.scroll set" -font $fixedfont \
      -width 36 -height 4 -setgrid 1 -selectmode browse -selectbackground $::Paratool::selectcolor \
      -listvariable ::CHARMMcharge::formatchargegrouplist
   frame $v.group.list.buttons
   button $v.group.list.buttons.delete -text "Delete" -command ::CHARMMcharge::del_chargegroup 
   button $v.group.list.buttons.add   -text "Add" -command ::CHARMMcharge::add_chargegroup 
   pack $v.group.list.buttons.add $v.group.list.buttons.delete -side top -fill x
   pack $v.group.list.format -anchor w
   pack $v.group.list.list $v.group.list.scroll -side left -fill y -expand 1
   pack $v.group.list.buttons -side left -anchor w

   bind $v.group.list.list <<ListboxSelect>> {
      set i [%W curselection]
      ::CHARMMcharge::select_chargegroup $i
   }

   frame $v.group.init
   label $v.group.init.label -text "Initialize charges with"
   eval tk_optionMenu $v.group.init.type ::CHARMMcharge::copycharge $::CHARMMcharge::copychargetypes
   $v.group.init.type configure -font $fixedfont
   pack $v.group.init.label $v.group.init.type -padx 2m -anchor n
   pack $v.group.label 
   pack $v.group.list $v.group.init -side left -anchor c -padx 2m -pady 2m

   ################ frame for group atom list ###################
   labelframe $v.sel -bd 2 -relief ridge -text "Edit selected charge group"  -padx 2 -pady 2
   label $v.sel.label -wraplength 13c -justify left -text "Pick charge group atoms using the mouse. The first atom is the direct water interaction partner which determines the position of the water molecule. The desired group charge should be set to an integer value."
   label $v.sel.direct -text "Direct interaction partner:" 

   frame $v.sel.list
   label $v.sel.list.format -text "Index  Name  Initial   Supram Center" -font $fixedfont
   scrollbar $v.sel.list.scroll -command "$v.sel.list.list yview"
   listbox $v.sel.list.list -activestyle none -yscroll "$v.sel.list.scroll set" -font $fixedfont \
      -width 36 -height 6 -setgrid 1 -selectmode browse -selectbackground $::Paratool::selectcolor \
      -listvariable ::CHARMMcharge::formatchargegroup
   frame $v.sel.list.buttons -pady 2m
   button $v.sel.list.buttons.reset -text "Reset" -command {
      array unset ::CHARMMcharge::chargegroup
      ::CHARMMcharge::update_formatchargegroup
      ::CHARMMcharge::update_chargegrouplist
      ::Paratool::select_atoms {}
      ::CHARMMcharge::reset_group
   }
   bind $v.sel.list.list <<ListboxSelect>> {
      set i [%W curselection]
      if {[llength $i]} {
	 ::Paratool::select_atoms [lindex $::CHARMMcharge::formatchargegroup $i 0]
      }
   }

   pack $v.sel.list.buttons.reset -side left -anchor w
   pack $v.sel.list.format -anchor w
   pack $v.sel.list.list $v.sel.list.scroll -side left -fill y -expand 1
   pack $v.sel.list.buttons -side left -anchor w

   frame $v.sel.total -padx 2m -pady 2m
   label $v.sel.total.label -text "Desired group charge: "
   entry $v.sel.total.value -textvariable ::CHARMMcharge::desiredgroupcharge  -width 6
   checkbutton $v.sel.total.check -text "unpolar group (group charge=0, hydrogens=0.09)" \
      -variable ::CHARMMcharge::unpolargroup -command ::CHARMMcharge::adjust_hydrogen_charges
   pack $v.sel.total.label $v.sel.total.value  -side left
   pack $v.sel.total.check -padx 2m -side left

   bind $v.sel.total.value <Return> {
      ::CHARMMcharge::set_desiredgroupcharge
      if {$::CHARMMcharge::betaposhydrogen || $::CHARMMcharge::unpolargroup} {
	 ::CHARMMcharge::adjust_hydrogen_charges
      }
   }

   checkbutton $v.sel.secondary -text "set hydrogens in beta position to 0.09" -variable ::CHARMMcharge::betaposhydrogen \
      -command ::CHARMMcharge::adjust_hydrogen_charges

   pack $v.sel.label $v.sel.list $v.sel.total $v.sel.secondary

   labelframe $v.poswat -bd 2 -relief ridge -text "Position water molecule"  -padx 2m -pady 2m
   #frame $v.poswat.load
   #label $v.poswat.load.label -text "Optimized water structure: "
   #entry $v.poswat.load.entry -textvariable ::CHARMMcharge::molnamewater -relief sunken \
   #   -justify left -state readonly -width 40
   #button $v.poswat.load.button -text "Load" -command {
	# set deffile [::CHARMMcharge::charmmcharge_find_optwater]
	# if {[llength $deffile]} {
	#    ::CHARMMcharge::load_water $deffile
	#    set ::CHARMMcharge::molnamewater "(PARATOOL) [file tail $deffile]"
	#    # Create and load a newmolecule containing the system and the water
	#    ::CHARMMcharge::merge_system_with_water#

	# } else {
	#    ::Paratool::opendialog optwat
	# }
     # }
   #pack $v.poswat.load.label $v.poswat.load.entry $v.poswat.load.button -side left -anchor e

   frame $v.poswat.syswat
   label $v.poswat.syswat.label -text "System + water merged: "
   entry $v.poswat.syswat.entry -textvariable ::CHARMMcharge::molnamesyswat -relief sunken \
      -justify left -state readonly -width 35
   button $v.poswat.syswat.load -text "Load" -command {::Paratool::opendialog syswat}
   # Disabling the Modify button for no, since it is difficult to work with basemolecule
   # and the modified molecule in parallel
   #button $v.poswat.syswat.modify -text "Modify" -command {::CHARMMcharge::molefacture_start}
   pack $v.poswat.syswat.label $v.poswat.syswat.entry $v.poswat.syswat.load -side left -anchor e

   ############## frame for type radiobuttons #################
   frame $v.poswat.type  -padx 2m -pady 2m
   label $v.poswat.type.label -text "Water atom directly interacting with charge group:"
   #frame $v.poswat.type.radio
   radiobutton $v.poswat.type.oxy -text "oxygen" -value oxygen \
      -variable ::CHARMMcharge::waterinteract -command {::CHARMMcharge::place_water}
   radiobutton $v.poswat.type.hyd -text "hydrogen" -value hydrogen \
      -variable ::CHARMMcharge::waterinteract -command {::CHARMMcharge::place_water}
#   pack $v.poswat.type.radio.oxy $v.poswat.type.radio.hyd -anchor w -side left
   pack $v.poswat.type.label $v.poswat.type.oxy $v.poswat.type.hyd -anchor w -side left

   frame $v.poswat.geom
   ############## frame for distance spinbox #################
   frame $v.poswat.geom.dist  -padx 2m -pady 2m
   label $v.poswat.geom.dist.label -text "Water interaction distance:"
   spinbox $v.poswat.geom.dist.spinb -from 0 -to 10 -increment 0.05 -width 5 \
      -textvariable ::CHARMMcharge::waterdist -command {::CHARMMcharge::place_water}
   pack $v.poswat.geom.dist.label $v.poswat.geom.dist.spinb  -padx 1m 
   bind $v.poswat.geom.dist.spinb <Return> {
      ::CHARMMcharge::place_water
   }

   ############## frame for angle scale #################
   frame $v.poswat.geom.angle  -padx 2m -pady 2m
   label $v.poswat.geom.angle.label -justify left -text "Rotate water molecule:"
   scale $v.poswat.geom.angle.scale -orient horizontal -length 284 -from -180 -to 180 \
      -command {::CHARMMcharge::rotate_water} -tickinterval 60
   pack $v.poswat.geom.angle.label $v.poswat.geom.angle.scale -side top -expand yes -anchor n
   $v.poswat.geom.angle.scale set 0

   pack $v.poswat.geom.dist $v.poswat.geom.angle -side left

   pack $v.poswat.syswat $v.poswat.type $v.poswat.geom

   labelframe $v.setup -text "QM based system+water optimization"  -padx 2m -pady 2m
   frame $v.setup.gauss
   label $v.setup.gauss.label -text "Gaussian input file:"
   entry $v.setup.gauss.entry -textvariable ::CHARMMcharge::molnamesyswatcom -relief sunken \
      -justify left -state readonly -width 40
   button $v.setup.gauss.button -text "Setup" -command ::CHARMMcharge::charmmwat_setup_gaussian_opt
   pack $v.setup.gauss.label $v.setup.gauss.entry $v.setup.gauss.button -side left -anchor e
   frame  $v.setup.log
   label $v.setup.log.label -text "Optimized system+water: "
   entry $v.setup.log.entry -textvariable ::CHARMMcharge::molnamesyswatopt -relief sunken \
      -justify left -state readonly -width 40
   button $v.setup.log.button -text "Load" -command ::CHARMMcharge::charmmcharge_find_optsyswat
   pack $v.setup.log.label $v.setup.log.entry $v.setup.log.button -side left -anchor e
   pack $v.setup.gauss $v.setup.log -anchor e

   pack $v.group $v.sel $v.poswat $v.setup -fill x -expand 1 -padx 1m -pady 1m

   # Open a new toplevel for the energy balance
   energy_balance_gui
   
   bind $v <FocusIn> {
      if {"%W"==".charmmcharge"} {
	 # Restore selection
	 .charmmcharge.group.list.list selection set active

	 # Blank all item backgrounds
	 for {set i 0} {$i<[.charmmcharge.group.list.list index end]} {incr i} {
	    .charmmcharge.group.list.list itemconfigure $i -background {}
	 }
	 focus .charmmcharge.group.list.list
      }
   }

   bind $v <FocusOut> {
      if {"%W"==".charmmcharge"} {
	 # Remember current selection
	 .charmmcharge.group.list.list selection set active
	 
	 # Set background color for selected items
	 foreach i [.charmmcharge.group.list.list curselection] {
	    .charmmcharge.group.list.list itemconfigure $i -background $::Paratool::selectcolor
	 }
      }
   }

   # Go to pickmode
   set_pickmode_chargegroup

   if {[llength [get_optwater_energy]]} {
      variable scfwater [get_optwater_energy]
      variable molnamewater "(PARATOOL) tip3.xbgf"
      if {[llength [lindex $::CHARMMcharge::chargegrouplist 0 13]]} {
	 load_water $molnamewater
      }
   } else {
      tk_messageBox -icon error -type ok -title Message -parent .charmmcharge \
	 -message "No default water SCF energy known for $::Paratool::optmethod/$::Paratool::optbasisset"
   }

   # If a matching optimized water logfile is present we load it automatically
#    variable molidwater
#    if {$molidwater<0} {
#       variable molnamewater [charmmcharge_find_optwater]
#       if {[llength $molnamewater]} {
# 	 variable molnamewater "(PARATOOL) [file tail $molnamewater]"
# 	 variable chargegroup
# 	 #array unset chargegroup
# 	 #array set chargegroup [lindex $::CHARMMcharge::chargegrouplist 0 13]
# 	 if {[llength $molnamewater] && [llength [lindex $::CHARMMcharge::chargegrouplist 0 13]]} {
# 	    puts "Loading optimized water $molnamewater"
# 	    load_water $molnamewater
# 	 }
#       }
#    }

   if {![llength $::CHARMMcharge::chargegrouplist]} {
      # Generate a first empty group
      reset_group
      $v.group.list.buttons.add invoke
   } else {
      select_chargegroup 0
   }

  # variable molidsyswatopt
  # variable molnamesyswatopt
  # if {$molidsyswatopt<0 && [llength $molnamesyswatopt]} {
  #    load_syswatopt $molnamesyswatopt
  # }
}


proc ::CHARMMcharge::energy_balance_gui {} {
   set v [toplevel ".charmmcharge_balance"]
   wm title $v "CHARMM style charges - Energy balance"
   wm resizable $v 0 0
   wm protocol $v WM_DELETE_WINDOW {
      destroy .charmmcharge_balance
   }
 
   #labelframe $v.energy -text "Energies"  -padx 2m -pady 2m
   frame $v.energy
   label $v.energy.bothlabel -text "  E(system+water) "
   label $v.energy.bothvalue -textvariable ::CHARMMcharge::scfsyswat
   label $v.energy.bothunit  -text "kcal/mol"
   grid $v.energy.bothlabel -row 0 -column 0 -sticky w
   grid $v.energy.bothvalue -row 0 -column 1 -sticky e
   grid $v.energy.bothunit  -row 0 -column 2 -sticky w

   label $v.energy.systemlabel -text "- E(system) "
   label $v.energy.systemvalue -textvariable ::CHARMMcharge::scfsystem
   label $v.energy.systemunit  -text "kcal/mol"
   grid $v.energy.systemlabel -row 1 -column 0 -sticky w
   grid $v.energy.systemvalue -row 1 -column 1 -sticky e
   grid $v.energy.systemunit  -row 1 -column 2 -sticky w

   label $v.energy.waterlabel -text "- E(water) "
   label $v.energy.watervalue -textvariable ::CHARMMcharge::scfwater
   label $v.energy.waterunit  -text "kcal/mol"
   grid $v.energy.waterlabel  -row 2 -column 0 -sticky w
   grid $v.energy.watervalue  -row 2 -column 1 -sticky e
   grid $v.energy.waterunit   -row 2 -column 2 -sticky w

   label $v.energy.dash1 -text "----------------------"
   label $v.energy.dash2 -text "-------------------------------"
   grid $v.energy.dash1 -row 3 -column 0 -sticky w
   grid $v.energy.dash2 -row 3 -column 1 -columnspan 2 -sticky w

   label $v.energy.interlabel -text "= E(interaction) "
   label $v.energy.intervalue -textvariable ::CHARMMcharge::scfinter
   label $v.energy.interunit  -text "kcal/mol"
   grid $v.energy.interlabel  -row 4 -column 0 -sticky w
   grid $v.energy.intervalue  -row 4 -column 1 -sticky e
   grid $v.energy.interunit   -row 4 -column 2 -sticky w

   label $v.energy.ddash -text "=================================================="
   grid $v.energy.ddash -row 5 -columnspan 3 -sticky w

   label $v.energy.charmmlabel -text "  E(CHARMM) "
   label $v.energy.charmmvalue -textvariable ::CHARMMcharge::charmmnonb
   label $v.energy.charmmunit  -text "kcal/mol"
   grid $v.energy.charmmlabel  -row 6 -column 0 -sticky w
   grid $v.energy.charmmvalue  -row 6 -column 1 -sticky e
   grid $v.energy.charmmunit   -row 6 -column 2 -sticky w

   button $v.scale -text "Scale charges to fit interaction energies" -command {
      ::CHARMMcharge::charmmcharge_scale_groupcharge
   }
   pack $v.energy $v.scale -padx 2m -pady 2m
}


proc ::CHARMMcharge::update_copycharge_menu { taglist } {
   variable copychargetypes $taglist

   if {![winfo exists .charge.group.init.type.menu]} { return }

   .charge.group.init.type.menu delete 0 end
   foreach tag $taglist {
      .charge.group.init.type.menu add radiobutton -variable ::CHARMMcharge::copycharge \
	 -label $tag
   }
   if {[lsearch $copychargetypes Mullik]>=0} {
      variable copycharge Mullik
   } else {
      variable copycharge [lindex $taglist 0]
   }
}


proc ::CHARMMcharge::set_pickmode_chargegroup {} {
   global vmd_pick_atom
   set ::Paratool::pickmode "chargegroup"
   set ::Paratool::picklist {}
   variable chargegroup
   array unset chargegroup

   update_formatchargegroup
   variable unpolargroup 0

   if {![winfo exists .paratool_atomedit]} {
      set ::Atomedit::paratool_atomedit_selection {}
      ::Paratool::update_atomlabels
      ::Paratool::atomedit_draw_selatoms
   }

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 0
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::Paratool::atom_picked_fctn
   #puts [trace info variable vmd_pick_atom]
}

proc ::CHARMMcharge::reset_group {} {
   variable scfsyswat {}
   variable scfinter  {}
   variable charmmelstat {}
   variable charmmvdw {}
   variable molidwater
   variable molidsyswat
   variable molidsyswatopt
   if {[lsearch [molinfo list] $molidsyswatopt]>=0} { mol delete $molidsyswatopt }
   if {[lsearch [molinfo list] $molidsyswat]>=0}    { mol delete $molidsyswat }
   #if {[lsearch [molinfo list] $molidwater]>=0}     { mol delete $molidwater; variable molnamewater {} }
   variable molnamesyswat {}
   variable molnamesyswatopt {}

   # Disable the gaussian setup and logfile buttons
   #if {$molidwater<=0} {
   #   .charmmcharge.setup.gauss.button configure -state disabled
   #   .charmmcharge.setup.log.button   configure -state disabled
   #}
   # Disable the "Load optimized water" button
   #.charmmcharge.poswat.load.button configure -state disabled
   # Disable the scale button
   if {[winfo exists .charmmcharge_balance]} {
      .charmmcharge_balance.scale  configure -state disabled
   }
}


proc ::CHARMMcharge::del_chargegroup {} {
   set i [.charmmcharge.group.list.list curselection]
   if {[llength $i]} {
      .charmmcharge.group.list.list delete $i
      if {[.charmmcharge.group.list.list size]} {
	 .charmmcharge.group.list.list selection set active
	 select_chargegroup [.charmmcharge.group.list.list index active]
      } else {
	 variable chargegroup
	 array unset chargegroup
	 update_formatchargegroup
      }
   }
}

proc ::CHARMMcharge::format_string { s } {
   if {![llength $s]} { return "{}" }
   return $s
}

proc ::CHARMMcharge::add_chargegroup {} {
   variable chargegrouplist
   variable formatchargegrouplist
   variable unpolargroup
   variable betaposhydrogen
   variable waterdist
   variable waterangle
   variable waterinteract {}
   variable molnamewater
   variable molnamesyswat    {}
   variable molnamesyswatcom {}
   variable molnamesyswatopt {}
   variable curcenter {}
   lappend chargegrouplist [list 0 0.0 0.0 $curcenter $unpolargroup $betaposhydrogen \
			       $waterinteract $waterdist $waterangle $molnamewater \
			       $molnamesyswat $molnamesyswatcom $molnamesyswatopt {}]
   lappend formatchargegrouplist [format "%6i  %7.4f  %7s %6s" 0 0.0 {{}} $curcenter]
   .charmmcharge.group.list.list selection clear 0 end
   .charmmcharge.group.list.list selection set end
   .charmmcharge.group.list.list activate end
   select_chargegroup [.charmmcharge.group.list.list index active]

   variable chargegroup
   array unset chargegroup
   update_formatchargegroup
}

proc ::CHARMMcharge::select_chargegroup { i } {
   if {![llength $i]} { return }
   .charmmcharge.group.list.list activate $i
   variable chargegroup
   variable chargegrouplist
   array unset chargegroup
   array set chargegroup [lindex $::CHARMMcharge::chargegrouplist $i 13]
   variable curcenter        [lindex $chargegrouplist $i 3]
   variable unpolargroup     [lindex $chargegrouplist $i 4]
   variable betaposhydrogen  [lindex $chargegrouplist $i 5]
   variable waterinteract    [lindex $chargegrouplist $i 6]
   variable waterdist        [lindex $chargegrouplist $i 7]
   variable waterangle       [lindex $chargegrouplist $i 8]
   variable molnamewater     [lindex $chargegrouplist $i 9]
   #variable molnamesyswat    [lindex $chargegrouplist $i 10]
   variable molnamesyswatcom [lindex $chargegrouplist $i 11]
   set syswatoptfile         [lindex $chargegrouplist $i 12]
   variable molnamesyswatopt {}
   # These energies are computed anew
   variable scfsyswat {}
   variable scfinter {}   
   variable charmmelstat {}
   variable charmmvdw {}

   # Disable/enable the "Load optimized water" button
   #if {![array size chargegroup]} {
   #   .charmmcharge.poswat.load.button configure -state disabled
   #} else {
   #   .charmmcharge.poswat.load.button configure -state normal
   #}

   # Disable the gaussian setup and logfile buttons
   # (they are going to be reenabled when syswat is loaded).
   .charmmcharge.setup.gauss.button configure -state disabled
   .charmmcharge.setup.log.button   configure -state disabled


   # Position the water in front of the interaction center
   variable molnamewater
   variable molidwater
   variable molidsyswat
   if {$molidwater>=0} {
      if {[array size chargegroup]} {
	 # Create and load a new molecule containing the system and the water
	 merge_system_with_water
      }
      rotate_water $waterangle

      if {$unpolargroup || ![array size chargegroup]} {
	 molinfo $molidsyswat set drawn 0
      }
   }

   if {[llength $syswatoptfile] && $molidsyswat>=0} {
      load_optsyswat $syswatoptfile
   } 

   ::Paratool::select_atoms [array names chargegroup]
   update_formatchargegroup

   # Disable/enable the scale charges button
   variable scfinter
   if {[llength $scfinter] && [winfo exists .charmmcharge_balance]} {
      .charmmcharge_balance.scale  configure -state normal
   } else {
      .charmmcharge_balance.scale  configure -state disabled
   }
}


proc ::CHARMMcharge::update_chargegrouplist {} {
   variable chargegroup
   variable chargegrouplist
   variable formatchargegrouplist
puts "update_chargegrouplist $chargegrouplist"
   if {![llength $chargegrouplist]} { return }

   set totalgroupinitial 0.0
   #set totalgroupsupram  0.0
   set totalgroupcharge  0.0
   set center {}
   foreach {ind data} [array get chargegroup] {
      # $data = {$name $charge $supram $center}
      puts "$ind data: $data"
      set totalgroupinitial [expr {[lindex $data 1]+$totalgroupinitial}]
      set totalgroupcharge  [expr {[::Paratool::get_atomprop Charge $ind]+$totalgroupcharge}]
      #set totalgroupsupram  [expr {[::Paratool::get_atomprop SupraM $ind]+$totalgroupsupram}]
      if {[llength [lindex $data 3]]} { set center [lindex $data 3] }
   }

   set ind [.charmmcharge.group.list.list index active]
   if {![llength $center]} {
      if {[array size chargegroup]} {
	 set center [lindex $chargegrouplist $ind 3]
      } else { 
	 set center "{}"
      }
   }
   variable curcenter $center
   variable unpolargroup
   variable betaposhydrogen
   variable waterdist
   variable waterangle
   variable waterinteract
   variable molnamewater
   variable molnamesyswat
   variable molnamesyswatcom
   variable molnamesyswatopt
   set totalgroupcharge [::Paratool::format_float "%7.4f" $totalgroupcharge]
   lset chargegrouplist $ind [list [array size chargegroup] \
		 $totalgroupinitial $totalgroupcharge $center $unpolargroup $betaposhydrogen \
		 $waterinteract $waterdist $waterangle $molnamewater $molnamesyswat \
		 $molnamesyswatcom $molnamesyswatopt [array get chargegroup]]
   set entry [format "%6i  %7.4f  %7s %6s" [array size chargegroup] \
		 $totalgroupinitial $totalgroupcharge $center]
   lset formatchargegrouplist $ind $entry
   variable desiredgroupcharge [::Paratool::format_float "%7.4f" $totalgroupcharge]
puts "finished update_chargegrouplist"
}


proc ::CHARMMcharge::update_formatchargegroup {} {
   variable chargegroup
   variable formatchargegroup {}
   foreach {ind data} [array get chargegroup] {
      set name   [lindex $data 0]
      set charge [lindex $data 1]
      set supram [::Paratool::format_float "%7.4f" [lindex $data 2]]
      set center ""
      if {$ind=="[lindex $data 3]"} {
	 set center "*"
      }
      lappend formatchargegroup [format {%5i %5s  %7.4f  %7s   %1s} $ind $name $charge $supram $center]
   }
}


proc ::CHARMMcharge::select_chargegroup_atoms { indexlist } {
   variable chargegroup 
   variable chargegrouplist
   if {![llength $chargegrouplist]} { return }

   array unset chargegroup
   variable curcenter {}
   if {[llength $indexlist]==1} { 
      set curcenter $indexlist
   } else {
      set curcenter [lindex $chargegrouplist [.charmmcharge.group.list.list index active] 3]
      if {[lsearch $indexlist $curcenter]<0} {
	 set curcenter [lindex $indexlist 0]
      }
   }

   variable copycharge
   set mark {}
   set i 0      
   foreach atom $indexlist {
      # if {$i==0} { set mark $atom }
      set sel [atomselect $::Paratool::molidbase "index $atom"]
      
      set name   [$sel get name]
      # Initialize charge
      if {$copycharge!="None"} {
	 set charge [::Paratool::get_atomprop $copycharge $atom]
	 ::Paratool::set_atomprop Charge $atom $charge
      } else {
	 set charge [$sel get charge]
      }
      ::Paratool::set_atomprop SupraM $atom $charge

      array set chargegroup [list $atom [list $name $charge $charge $curcenter]]
      $sel delete
      incr i
   }

   # We must set the charges in molidsyswat also
   variable molidsyswat
   if {$molidsyswat>=0} {
      # FIXME: This won't work when molidsyswat is different that molidbase (except for the water)
      set sel [atomselect $molidsyswat "not segid CWAT"]
      set sel2 [atomselect $::Paratool::molidbase "all"]
      $sel set charge [$sel2 get charge]
      $sel delete
      $sel2 delete
   }

   if {[llength [array names chargegroup]]>=1} {
      # Enable the "Load optimized water" button
      #.charmmcharge.poswat.load.button configure -state normal
      variable molidwater
      variable molnamewater

      if {[llength $molnamewater] && $molidwater<0} {
	 load_water $molnamewater

	 # Create and load a new molecule containing the system and the water
	 merge_system_with_water
      } else {
	 if {[llength $indexlist]==1} { 
	    puts merge
	    merge_system_with_water
	 } 
      }
   }

   ::Paratool::atomedit_update_list
   ::Paratool::update_atomlabels
   ::Paratool::select_atoms $indexlist
   update_formatchargegroup
   update_chargegrouplist
   adjust_hydrogen_charges

   variable molidsyswat
   if {$molidsyswat>=0} { 
      place_water
   }
}


proc ::CHARMMcharge::chargegroup_donepicking {} {
   set ::Paratool::picklist {}

   # Enable the "Load optimized water" button
   #.charmmcharge.poswat.load.button configure -state normal

   variable molidsyswat
   if {$molidsyswat>=0} { 
      if {[lsearch [molinfo list] $molidsyswat]<0} {
	 set molidsyswat {}
      } else {
	 place_water 
      }
   }
}

proc ::CHARMMcharge::set_water_targetpos {} {
   variable chargegroup
   variable waterdist
   variable curcenter
   variable molidsyswat
   if {![array size chargegroup]} { return }
   set sel [atomselect $molidsyswat "index $curcenter"]
   set pos0 [join [$sel get {x y z}]]
   set neighbors [join [$sel getbonds]]
   set nsel [atomselect $molidsyswat "index $neighbors"]
   set sum {0 0 0}
   foreach pos [$nsel get {x y z}] {
      set sum [vecadd $sum [vecnorm [vecsub $pos $pos0]]]
   }

   variable waterdir [vecnorm $sum]
   variable targetpos [vecadd $pos0 [vecscale $waterdir [expr {-$waterdist}]]]
}

proc ::CHARMMcharge::charmmcharge_find_optwater { } {
   chargegroup_donepicking
   global env
   set file "water_[string tolower $::Paratool::optmethod]_"
   append file [string map {+ d * p hf rhf} $::Paratool::optbasisset].log
   set deffile [file join $env(PARATOOLDIR) optwater $file]

   puts "Using default optimized water $deffile"
   if {![file exists $deffile]} {
      tk_messageBox -icon error -type ok -title Message -parent .charmmcharge \
	 -message "Didn't find default optimized water logfile \"$file\""
      set deffile {}
   }

   return $deffile
}

proc ::CHARMMcharge::get_optwater_energy {} {
   if {[regexp {hf|rhf|uhf} [string tolower $::Paratool::optmethod]]} {
      switch $::Paratool::optbasisset {
	 6-31G*   { return -47665.598 }
	 6-31+G*  { return -47669.986 }
	 default  { return {} }
      }
   }
   if {[regexp {b3lyp|ub3lyp} [string tolower $::Paratool::optmethod]]} {
      switch $::Paratool::optbasisset {
	 6-31G*   { return -47915.310 }
	 6-31+G*  { return -47923.003 }
	 default  { return {} }
      }
   }

   return {}
}

#################################################################################
# According to MacKerell et al. (1995) JACS 117:11946-11975:
# we use the experimental gas phase geometry here:
# "In the ab initio 6-31G* optimizations of the adenine and guanine
# interactions with water the base 3-21G optimized structures (58) and the
# water experimental gas-phase geometry (56) were fixed and only the
# distances and in some cases a single angel, as shown in Figure 1., were
# optimized. (...)"
# The gas phase avg geometry acccording to Cook et al., J. Mol. Spectrosc. 53,
# Issue 1, October 1974, Pages 62-76 is:
# R=0.9724 Å   theta=104.5°
# while the equilib geometry including an one-dimensional approximation to the 
# anharmonicity effects is
# R=0.9587 Å   theta=103.9°
# I don't know which one to take , so I'll use the TIP3 water geometry:
# R=0.9572 Å   theta=104.52°
###################################################################################

proc ::CHARMMcharge::load_water { {file {}} } {
   if {$::Paratool::molidopt<0 && [molinfo $::Paratool::molidbase get numframes]<2} { 
      tk_messageBox -icon error -type ok -title Message  \
	 -message "You must load the optimized system geometry first!"
      return
   }

   # Replace the "(PARATOOL) " tag in $file
   global env
   set tail [string map "{(PARATOOL) } {}" $file]
   set file [file join $env(PARATOOLDIR) $tail]

   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "Didn't find default optimized water logfile \"$file\""
      return 0
   }

   variable molidwater
   variable molidsyswat
   # Delete old molecules
   if {[lsearch [molinfo list] $molidsyswat]>=0}    { mol delete $molidsyswat }
   if {[lsearch [molinfo list] $molidwater]>=0}     { mol delete $molidwater }

   set viewpoint [molinfo $::Paratool::molidbase get {center_matrix rotate_matrix scale_matrix }]
   #variable molidwater [::QMtool::load_gaussian_log $file]
   variable molidwater [mol load xbgf [file join $env(PARATOOLDIR) tip3.xbgf]]
   mol rename $molidwater $tail

   # Setup a trace on the existence of this molecule
   global vmd_initialize_structure
   trace add variable vmd_initialize_structure($molidwater) write ::CHARMMcharge::molecule_assert
   
   molinfo $molidwater set {center_matrix rotate_matrix scale_matrix } $viewpoint
   molinfo $::Paratool::molidbase  set top 1
   molinfo $::Paratool::molidbase  set {center_matrix rotate_matrix scale_matrix } $viewpoint
   set wat [atomselect $molidwater all]

   if {[$wat num]>3} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "Water molecule coordinate file contains more than 3 atoms!"
      return 0
   }
   puts "load_water: wat=$molidwater sys=$::Paratool::molidopt"

   #variable scfwater [format {%16.4f} [lindex [::QMtool::get_scfenergies] end 0]]
   variable scfwater [get_optwater_energy]
}


##########################################################
# This is called when the VMD mol initialization state   #
# is changed, i.e. when a molecule is deleted from VMD's #
# list. If the deleted molecule exists in Paratool then  #
# delete its reference.                                  #
##########################################################

proc ::CHARMMcharge::molecule_assert { n id args } {
   global vmd_initialize_structure
   puts "::CHARMMcharge::molecule_assert trace ${n}($id) = $vmd_initialize_structure($id)"
   if {$vmd_initialize_structure($id)==0} { 
      variable molidwater  
      variable molidsyswat 
      if {$id==$molidwater}  { set molidwater  -1; variable molnamewater  {(deleted)}; }
      if {$id==$molidsyswat} { set molidsyswat -1; variable molnamesyswat {(deleted)}; }
   }
   if {$molidwater<0 || $molidsyswat<0} {
      # Disable the gaussian setup and logfile buttons
      .charmmcharge.setup.gauss.button configure -state disabled
      .charmmcharge.setup.log.button   configure -state disabled
   }
}


##########################################################
# Determines if water interacts through O or H with the  #
# group depending on the polarity of the interacting     #
# subgroup.                                              #
##########################################################

proc ::CHARMMcharge::init_water_orientation {} {
   variable chargegrouplist 
   variable curcenter

   # Get atoms in alpha position to the center
   set csel [atomselect $::Paratool::molidbase "index $curcenter"]
   set alphaposind [join [$csel getbonds]]
   $csel delete

   set asel [atomselect $::Paratool::molidbase "index $alphaposind"]
   set acharge 0.0
   foreach alpha $alphaposind {
      set acharge [expr {[::Paratool::get_atomprop Charge $alpha] + $acharge}]
   }

   if {[::Paratool::get_atomprop Charge $curcenter]>$acharge} {
      variable waterinteract "oxygen"
   } else {
      variable waterinteract "hydrogen"
   }
}

proc ::CHARMMcharge::merge_system_with_water {} {
   variable molidwater

   if {$molidwater<0} { 
      tk_messageBox -icon error -type ok -title Message  \
	 -message "You must load a water molecule first!"
      return
   }

   # Determine if water interacts with the oxygen or hydrogen atom
   variable waterinteract
   if {![llength $waterinteract]} {
      init_water_orientation
   }

   set seloxy [atomselect $molidwater "name \"O.*\""]
   set selhyd [atomselect $molidwater "name \"H.*\""]  

   # Set the TIP3 charges
   #$seloxy set charge -0.834
   #$selhyd set charge  0.417
   $seloxy set occupancy 1.7682;  # VDWrmin
   $selhyd set occupancy 0.2245;  # VDWrmin
   $seloxy set beta  -0.1521;  # VDWeps
   $selhyd set beta  -0.0460;  # VDWeps
   #$seloxy set type OT
   #$selhyd set type HT
   #$seloxy set name OH2
   #$selhyd set name {H1 H2}
   #$seloxy set resname TIP3
   #$selhyd set resname TIP3

   set primarysel $seloxy
   set secondarysel [atomselect $molidwater "index [lindex [$selhyd list] 0]"]
   
   if {$waterinteract=="hydrogen"} {
      set primarysel [atomselect $molidwater "index [lindex [$selhyd list] 0]"]
      set secondarysel $seloxy
   }

   # if $waterinteract=="hydrogen"
   set pripos [join [$primarysel get {name x y z}]]
   set secpos [join [$secondarysel get {name x y z}]]
   set terpos [lindex [$selhyd get {name x y z}] 1]
   if {$waterinteract=="oxygen"} {
      set secpos [lindex [$selhyd get {name x y z}] 0] 
      set terpos [lindex [$selhyd get {name x y z}] 1]
   }

   set basename [file rootname [molinfo $::Paratool::molidbase get name]]

   # Append water cartesians
   variable curcenter
   variable molnamesyswat "${basename}_charmmwater$curcenter.xbgf"
   set wat [atomselect $molidwater all]
   set opt [atomselect $::Paratool::molidbase all frame last]
   ::Paratool::write_xbgf $molnamesyswat $opt 
   $wat set segid "CWAT"

   ::Paratool::add_selection_to_xbgf $molnamesyswat $wat {} {occupancy beta}


   # Load the merged molecule
   load_syswat $molnamesyswat

   # Start the NAMDserver in order to compute the interaction energies
   #variable molidsyswat 
   #set sel [atomselect $molidsyswat "not segid CWAT"]
   #set wat [atomselect $molidsyswat "segid CWAT"]
   #::CHARMMcharge::start_namdserver $sel $wat -nonb
}

proc ::CHARMMcharge::load_syswat { file } {
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "Didn't find system+water file \"$file\""
      return 0
   }

   # Delete system+water molecule
   variable molidsyswat
   if {[lsearch [molinfo list] $molidsyswat]>=0} { mol delete $molidsyswat }

   # Load the merged molecule
   set viewpoint [molinfo $::Paratool::molidbase get {center_matrix rotate_matrix scale_matrix global_matrix}]
   variable molidsyswat [mol new $file];
   variable molnamesyswat $file; 
   
   # Set the VDW data
   foreach remark [split [join [join [molinfo $molidsyswat get remarks]]] \n] {
      if {[lindex $remark 0]=="VDW"} {
	 set i [expr {[lindex $remark 1]-1}]
	 set sel [atomselect $molidsyswat "index $i"]
	 set vdweps  [lindex $remark 2]
	 set vdwrmin [lindex $remark 3]
	 puts "VDW=$vdweps; $vdwrmin"
	 if {[llength $vdweps]} {
	    $sel set beta      $vdweps
	 }
	 if {[llength $vdwrmin]} {
	    $sel set occupancy $vdwrmin
	 }
      }
   }

   # Position the water molecule in front of the target group
   place_water

   display resetview
   molinfo $molidsyswat set {center_matrix rotate_matrix scale_matrix global_matrix} $viewpoint
   molinfo $::Paratool::molidbase  set top 1
   molinfo $::Paratool::molidbase  set {center_matrix rotate_matrix scale_matrix global_matrix} $viewpoint

   # Setup a trace on the existence of this molecule
   global vmd_initialize_structure
   trace add variable vmd_initialize_structure($molidsyswat) write ::CHARMMcharge::molecule_assert

   # Undraw all other molecules in VMD:
   foreach m [molinfo list] {
      if {$m==$molidsyswat || $m==$::Paratool::molidbase} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   mol selection all
   mol representation "Bonds [expr {$::Paratool::bondthickness}]"
   mol modrep 0 $molidsyswat
   mol representation "VDW [expr {$::Paratool::bondthickness}]"
   mol addrep $molidsyswat
   #mol modmaterial 0 $molidsyswat Transparent
   #mol modmaterial 1 $molidsyswat Transparent

   # Enable the gaussian setup and logfile buttons
   .charmmcharge.setup.gauss.button configure -state normal
   .charmmcharge.setup.log.button   configure -state normal
}


##########################################################
# Places the water in front of the interacting subgroup. #
##########################################################

proc ::CHARMMcharge::place_water {} {
   variable molidsyswat
   if {$molidsyswat<0} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "Optimized water molecule must be loaded first!"
      return 0
   }

   set_water_targetpos

   set seloxy [atomselect $molidsyswat "segid CWAT and name \"O.*\""]
   set selhyd [atomselect $molidsyswat "segid CWAT and name \"H.*\""]

   variable waterinteract
   set primarysel $seloxy
   set secondarysel [atomselect $molidsyswat "index [lindex [$selhyd list] 0]"]
   set tertiarysel  [atomselect $molidsyswat "index [lindex [$selhyd list] 1]"]
   if {$waterinteract=="hydrogen"} {
      set primarysel  [atomselect $molidsyswat "index [lindex [$selhyd list] 0]"]
      set tertiarysel [atomselect $molidsyswat "index [lindex [$selhyd list] 1]"]
      set secondarysel $seloxy
   }
   variable waterpartner [join [$primarysel get index]]
   set primarypos   [join [$primarysel get {x y z}]]
   set secondarypos [join [$secondarysel get {x y z}]]
   set wat [atomselect $molidsyswat "segid CWAT"]

   # First move water to origin
   $wat moveby [vecsub {0 0 0} $primarypos]

   # Rotate O-H axis parallel to x-axis
   set primarypos   [join [$primarysel   get {x y z}]]
   set secondarypos [join [$secondarysel get {x y z}]]
   set rot [transvecinv [vecsub $primarypos $secondarypos]]
   if {$waterinteract=="oxygen"} {
      set middle [vecadd [lindex [$selhyd get {x y z}] 0] [lindex [$selhyd get {x y z}] 1]]
      set rot [transvecinv [vecsub $primarypos $middle]]
   }
   $wat move $rot

   # Now it's easy to rotate O-H axis parallel to $waterdir
   variable waterdir
   set rot [transvec $waterdir]
   $wat move $rot
   variable waterangle 0
   variable curangle 0

   # Move water to its final target position
   variable targetpos
   set primarypos   [join [$primarysel get {x y z}]]
   set diff [vecsub $targetpos $primarypos]
   $wat moveby $diff

   # Rotate around the interaction axis $waterdir 
   variable curcenter
   set centersel  [atomselect $molidsyswat "index $curcenter"]
   set bonds [join [$centersel getbonds]]

   # Get atoms in alpha position to the center
   set csel [atomselect $molidsyswat "index $curcenter"]
   set alphaposind [join [$csel getbonds]]

   set asel [atomselect $molidsyswat "index $alphaposind and noh"]
   if {![$asel num]} {
      $asel delete
      set asel [atomselect $molidsyswat "index $alphaposind"]      
   }

   if {[$asel num]>0} {
      set rotdir [vecsub [join [$csel get {x y z}]] [lindex [$asel get {x y z}] 0]]
puts "[list $alphaposind $curcenter [join [$secondarysel list]] [join [$tertiarysel list]]]"
      set dihed [measure dihed [list [lindex [$asel list] 0] $curcenter [join [$secondarysel list]] [join [$tertiarysel list]]] molid $molidsyswat]
      set mat [trans bond [join [$csel get {x y z}]] [join [$secondarysel get {x y z}]] [expr {-$dihed}] deg]
      $tertiarysel move $mat
   }


#   foreach alpha $alphaposind [$asel get {index atomicnumber}] {
#   }


   $csel delete
   $primarysel   delete
   $secondarysel delete
   $tertiarysel  delete
   $wat delete


   update_energies

   # Store the new waterdist
   update_chargegrouplist
}


proc ::CHARMMcharge::rotate_water { angle } {
   variable targetpos
   variable chargegroup
   variable curangle
   variable molidsyswat

   if {![array size chargegroup]} { return }
   if {$molidsyswat<0} { return }

   set wat [atomselect $molidsyswat "segid CWAT"]
   if {![$wat num]} { return }

   variable curcenter
   set sel [atomselect $molidsyswat "index $curcenter"]
   set pos0 [join [$sel get {x y z}]]
   $sel delete

   set diffangle [expr {$angle-$curangle}]
   set curangle $angle

   # Make sure the scale is also updated when this proc was called manually
   .charmmcharge.poswat.geom.angle.scale set $angle

   set rot [trans bond $pos0 $targetpos $diffangle deg]
   $wat move $rot
   $wat delete


   update_energies
 
   # Store the new waterangle
   variable waterangle $curangle
   update_chargegrouplist
}

proc ::CHARMMcharge::update_energies {} {
   variable chargegroup
   set groupindexes {}
   foreach {ind data} [array get chargegroup] {
      lappend groupindexes $ind
   }

   variable molidsyswat
   set groupsel [atomselect $::Paratool::molidbase "index $groupindexes"]
   set watsel   [atomselect $molidsyswat "segid CWAT"]
   variable charmmelstat [compute_elstat_interaction $groupsel $watsel]
   variable charmmvdw    [compute_vdw_interaction $groupsel $watsel {occupancy beta}]
   variable charmmnonb   [expr {$charmmelstat+$charmmvdw}]
   variable charmmelstat [format "%16.4f" $charmmelstat]
   variable charmmvdw    [format "%16.4f" $charmmvdw]
   variable charmmnonb   [format "%16.4f" $charmmnonb]
   $watsel   delete
   $groupsel delete

   return $charmmnonb
}


proc ::CHARMMcharge::charmmwat_setup_gaussian_opt {} {
   variable molidsyswat
 
   set fromcheck {}
   set memory 1gb
   set nproc  1
   if {[::QMtool::get_molid]==$::Paratool::molidopt} {
      set fromcheck [::QMtool::get_checkfile]
      set memory    [::QMtool::get_memory]
      set nproc     [::QMtool::get_nproc]
      puts "[::QMtool::get_molid]: fromcheck=$fromcheck; mem=$memory; nproc=$nproc"
   } else {
      # Retrieve some parameters from the system optimization, if available
      if {[lsearch -integer [::QMtool::get_molidlist] $::Paratool::molidopt]>=0} {
	 ::QMtool::set_molid $::Paratool::molidopt
	 set fromcheck [::QMtool::get_checkfile]
	 set memory    [::QMtool::get_memory]
	 set nproc     [::QMtool::get_nproc]
	 puts "molidopt=$::Paratool::molidopt: fromcheck=$fromcheck; mem=$memory; nproc=$nproc"
      }
   }
  
   if {![llength $::QMtool::molidlist]} {
      ::QMtool::qmtool -mol $molidsyswat -nogui;
   } else {
      ::QMtool::use_vmd_molecule $molidsyswat
   }

   # Fix the system cartesian coordinates
   set sel [atomselect $molidsyswat "not segid CWAT"]
   ::QMtool::fix_atom_coordinates [$sel list]
   $sel delete

   # Use the internal coordinates from $basemolecule
   ::QMtool::set_internal_coordinates $::Paratool::zmat

   # Fix the water internal coordinates
   variable chargegroup
   variable waterinteract
   set indwater [molinfo $::Paratool::molidopt get numatoms]
   if {$waterinteract=="oxygen"} {
      ::QMtool::register_bond [list $indwater [expr {$indwater+1}]]
      ::QMtool::register_bond [list $indwater [expr {$indwater+2}]]
   } else {
      ::QMtool::register_bond [list $indwater [expr {$indwater+1}]]
      ::QMtool::register_bond [list [expr {$indwater+1}] [expr {$indwater+2}]]
   }
   # Fix all internal coordinates. Since we didn't fix the water cartesians and 
   # no internal coordinate connecting water and system was defined, the only degrees of
   # freedom are the position of water with repect to the molecule.
   ::QMtool::fix_all fix


   variable molnamesyswat
   variable curcenter
   variable molnamesyswatcom [file rootname $molnamesyswat].com

   ::QMtool::set_title     "${::Paratool::molnameopt} + water for CHARMM charge scaling"
   ::QMtool::set_basename  [file rootname $molnamesyswatcom]
   ::QMtool::set_simtype   "Geometry optimization"
   ::QMtool::set_otherkey  ""
   ::QMtool::set_guess     "Take guess from checkpoint file"
   ::QMtool::set_geometry  "Z-matrix"
   ::QMtool::set_method    $::Paratool::optmethod
   ::QMtool::set_basisset  $::Paratool::optbasisset
   ::QMtool::set_coordtype "ModRedundant"
   ::QMtool::set_fromcheckfile $fromcheck
   ::QMtool::set_memory $memory
   ::QMtool::set_nproc  $nproc
   ::QMtool::set_totalcharge   $::Paratool::totalcharge
   ::QMtool::set_multiplicity  $::Paratool::multiplicity
   ::Paratool::alias_qmtool_atomnames

   ::QMtool::setup_QM_simulation -force

   # Store molnamesyswat
   update_chargegrouplist
}


proc ::CHARMMcharge::charmmcharge_find_optsyswat { } {
   set basename [file rootname [molinfo $::Paratool::molidopt get name]]
   ::Paratool::opendialog optsyswat ${basename}_charmmwater.log
   ::Paratool::select_atoms [array names chargegroup]
}

proc ::CHARMMcharge::load_optsyswat { file } {
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message  \
	 -message "Didn't find default optimized water logfile \"$file\""
      return 0
   }

   set viewpoint [molinfo $::Paratool::molidbase get {center_matrix rotate_matrix scale_matrix global_matrix}]

   variable molidsyswat
   if {$molidsyswat>=0} {
      variable molidsyswat [::QMtool::load_gaussian_log $file $molidsyswat]
      ::QMtool::recalculate_bonds
      
   } else {
      variable molidsyswat [::QMtool::load_gaussian_log $file]
   }
   variable molidsyswatopt $molidsyswat
   variable molnamesyswatopt $file

   # Set the TIP3 charges and VDW parameters
   set seloxy [atomselect $molidsyswat "segid CWAT and name \"O.*\""]
   set selhyd [atomselect $molidsyswat "segid CWAT and name \"H.*\""]
   $seloxy set charge -0.834
   $selhyd set charge  0.417
   $seloxy set occupancy 1.7682;  # VDWrmin
   $selhyd set occupancy 0.2245;  # VDWrmin
   $seloxy set beta  -0.1521;  # VDWeps
   $selhyd set beta  -0.0460;  # VDWeps
   $seloxy set type OT
   $selhyd set type HT
   $seloxy set name OH2
   $selhyd set name {H1 H2}
   $seloxy set resname TIP3
   $selhyd set resname TIP3

   variable scfsystem
   variable scfwater
   variable scfsyswat [format {%16.4f} [lindex [::QMtool::get_scfenergies] end 0]]
   variable scfinter  [format {%16.4f} [expr {$scfsyswat-$scfsystem-$scfwater}]]

   update_energies

   # Enable the scale button
   if {[winfo exists .charmmcharge_balance]} {
      .charmmcharge_balance.scale  configure -state normal
   }

   # Store molnamesyswatopt
   update_chargegrouplist
}


proc ::CHARMMcharge::get_secondary_hydrogens {} {
   variable chargegroup
   set group [atomselect $::Paratool::molidbase "index [array names chargegroup]"]
   set hydrogengrouplist [get_hydrogen_groups $group]

  # Get a list of secondary hydrogens
   variable curcenter
   set asel [atomselect $::Paratool::molidbase "index $curcenter"]
   set secondary {}
   foreach hydrogengroup $hydrogengrouplist {
      set mother [lindex $hydrogengroup 0]
      
      # If the mother atom is bound to the interaction partner
      # then the hydrogens are in secondary position, otherwise return.
      if {[lsearch [join [$asel getbonds]] $mother]>=0} { return }

      lappend secondary [lindex $hydrogengroup 1]
   }
   $asel delete

   return [join $secondary]
}

proc ::CHARMMcharge::charmmcharge_scale_groupcharge {} {
   #tk_messageBox -icon error -type ok -title Message -parent .paratool \
   #   -message "Sorry, this doesn't work yet. Please check for a newer version of the plugins on \nhttp://www.ks.uiuc.edu/Research/vmd/ and \nhttp://bioinf.charite.de/biophys/research/paratool"
   #return 

   variable curcenter
   variable molidsyswat
   variable chargegroup
   set wat [atomselect $molidsyswat "segid CWAT"]
   set secondary [get_secondary_hydrogens]

   set indexpos {}
   set indexneg {}
   variable groupindexes {}
   variable scaleindexes {}
   foreach {ind data} [array get chargegroup] {
      lappend groupindexes $ind
      # Exclude secondary hydrogens from scaling
      # (FIXME) but not from energy calculation!!!
      if {[lsearch $secondary $ind]<0} {
	 lappend scaleindexes $ind
      }
      if {[lindex $data 1]>0} {
	 lappend indexpos $ind
      } else {
	 lappend indexneg $ind
      }
   }
   
   set sel [atomselect $::Paratool::molidbase "not index $groupindexes"]
   variable restelstat [compute_elstat_interaction $sel $wat]
   set restindexes [$sel list]
   $sel delete

   # Using namespave eval we obtain a persistent selection, i.e. it is not 
   # destroyed after the proc returns.
   namespace eval ::CHARMMcharge {
      set groupsel [atomselect $::Paratool::molidbase "index $groupindexes"]
      set scalesel [atomselect $::Paratool::molidbase "index $scaleindexes"]
   }

   variable groupsel
   variable equilibdist [compute_equilib_distance $groupsel $wat]
   variable groupelstat [compute_elstat_interaction $groupsel $wat]

   if {[llength $indexpos]} {
      set selpos [atomselect $::Paratool::molidbase "index $indexpos"]
   } else {
      set selpos [atomselect $::Paratool::molidbase "none"]
   }
   if {[llength $indexneg]} {
      set selneg [atomselect $::Paratool::molidbase "index $indexneg"]
   } else {
      set selneg [atomselect $::Paratool::molidbase "none"]
   }
   set totalpos 0.0
   foreach q [$selpos get charge] {
      set totalpos [expr {$totalpos+$q}]
   }
   set totalneg 0.0
   foreach q [$selneg get charge] {
      set totalneg [expr {$totalneg+$q}]
   }

   variable charmmelstat
   variable charmmvdw
   variable charmmnonb   
   puts "group: $groupindexes"
   puts "rest:  $restindexes" 
   puts "Before charge scaling:"
   puts [format "min distance = %16.4f Angstrom" $equilibdist]
   puts [format "group elstat = %16.4f kcal/mol" $groupelstat]
   puts [format "rest  elstat = %16.4f kcal/mol" $restelstat]
   puts [format "total elstat = %16.4f kcal/mol" $charmmelstat]
   puts [format "total vdw    = %16.4f kcal/mol" $charmmvdw]
   puts [format "total nonb   = %16.4f kcal/mol" $charmmnonb]
   puts [format "total +q = %7.4f" $totalpos]
   puts [format "total -q = %7.4f" $totalneg]
   puts [format "total  q = %7.4f" [expr {$totalpos+$totalneg}]]
   variable ::Paratool::dipolemoment
   foreach {dipolex dipoley dipolez} $dipolemoment {}
   puts [format "dipole moment = {%7.4f %7.4f %7.4f}" $dipolex $dipoley $dipolez]

   set maxiter 1000
   variable scfinter
   variable scalesel
   set opt [optimization -downhill -tol 0.0001 -function ::CHARMMcharge::scaling_error]
   $opt initsimplex [$scalesel get charge]
   foreach q [$scalesel get charge] { lappend pbounds {-2.0 2.0} }
   $opt configure -bounds $pbounds
   $opt start

#   puts "Converged after $i iterations."

   set totalpos 0.0
   foreach q [$selpos get charge] {
      set totalpos [expr {$totalpos+$q}]
   }
   set totalneg 0.0
   foreach q [$selneg get charge] {
      set totalneg [expr {$totalneg+$q}]
   }

   puts "After charge scaling:"
   puts [format "group elstat = %16.4f kcal/mol" $groupelstat]
   puts [format "rest  elstat = %16.4f kcal/mol" $restelstat]
   puts [format "total elstat = %16.4f kcal/mol" $charmmelstat]
   puts [format "total vdw    = %16.4f kcal/mol" $charmmvdw]
   puts [format "total +q = %7.4f" $totalpos]
   puts [format "total -q = %7.4f" $totalneg]
   puts [format "total  q = %7.4f" [expr {$totalpos+$totalneg}]]
   variable charmmnonb   [expr {$charmmelstat+$charmmvdw}]
   variable charmmelstat [format "%16.4f" $charmmelstat]
   variable charmmnonb   [format "%16.4f" $charmmnonb]

   variable chargegrouplist 
   variable curcenter

   # Set the SupraM charges in basemolecule and update chargegroup
   set newchargegroup {}
   array set supramarray [join [$groupsel get {index charge}]]
   foreach {ind data} [array get chargegroup] {
      if {[lsearch $groupindexes $ind]<0} { continue }
      set name [lindex $data 0]
      set charge $supramarray($ind) ;#[::Paratool::get_atomprop Charge $ind]
      ::Paratool::set_atomprop SupraM $ind $charge
      #set supram [::Paratool::format_float "%7.4f" $supramarray($ind)]
      lappend newchargegroup  $ind [list $name [lindex $chargegroup($ind) 1] $charge $curcenter]
   }
   array set chargegroup $newchargegroup

   if {[lsearch $::Paratool::atomproptags SupraM]<0} { lappend ::Paratool::atomproptags SupraM }
   variable copychargetypes 
   if {[lsearch $copychargetypes SupraM]<0} { lappend copychargetypes SupraM }
   if {[winfo exists .paratool_atomedit]} {
      ::Atomedit::update_copycharge_menu .paratool_atomedit $copychargetypes
   } 

   ::Paratool::atomedit_update_list
   ::Paratool::update_atomlabels
   update_chargegrouplist
   update_formatchargegroup
}




#########################################################
# In case $unpolargroup is 1 the total group charge is  #
# first scaled to 0.0, then the charge of all carbon    #
# connected hydrogens is set to 0.09. The charge of the #
# mother atom is adjusted such as to retain the total   #
# charge.                                               #
# In case $unpolargroup is 0 and $betaposhydrogen is 1, #
# only hydrogens in beta position with regard to the    #
# interaction center and their parents are set to 0.09  #
# and scaled, respectively.                             #
#########################################################

proc ::CHARMMcharge::adjust_hydrogen_charges {} {
   variable betaposhydrogen
   variable unpolargroup
   variable copycharge
   variable chargegroup
   variable formatchargegroup
   variable chargegrouplist 
   variable molidsyswat
   variable molidsyswatopt
   #if {!$unpolargroup && !$betaposhydrogen} { return }
   variable curcenter
   if {![llength $curcenter] || ![array size chargegroup]} { return }

   if {$unpolargroup} {
      # Neutralize group
      variable desiredgroupcharge 0.0
      set_desiredgroupcharge

      # Disable the scale button
      if {[winfo exists .charmmcharge_balance]} {
	 .charmmcharge_balance.scale  configure -state disabled
      }
      molinfo $molidsyswat set drawn 0
   } else {
      # Enable the scale button
      if {[winfo exists .charmmcharge_balance] && $molidsyswatopt>=0} {
	 .charmmcharge_balance.scale  configure -state normal
      }
      molinfo $molidsyswat set drawn 1
   }

   # Get atoms in alpha position to the center
   set csel [atomselect $::Paratool::molidbase "index $curcenter"]
   set alphapos [join [$csel getbonds]]
   $csel delete
   
   # Get the hydrogengroups
   set group [atomselect $::Paratool::molidbase "index [array names chargegroup] and not index $curcenter"]
   set hydrogengrouplist [get_hydrogen_groups $group]
   $group delete
   
   foreach hydrogengroup $hydrogengrouplist {
      set mother [lindex $hydrogengroup 0]
      
      # If the mother atom is bound to the interaction partner
      # then the hydrogens are in secondary position.
      set betapos 1
      if {[lsearch $alphapos $mother]>=0} { set betapos 0 }

      set diff 0.0
      foreach hydrogen [lindex $hydrogengroup 1] {
	 # set hydrogen charge to 0.09
	 set hsel [atomselect $::Paratool::molidbase "index $hydrogen"]
	 set name   [join [$hsel get name]]
	 set charge [join [$hsel get charge]]
	 set supram [::Paratool::get_atomprop SupraM $hydrogen]
	 if {$unpolargroup || ($betaposhydrogen && $betapos)} {
	    set diff [expr {$diff+$charge-0.09}]
	    set charge 0.09
	 } else {
	    # Reset to initial charge
	    set charge [::Paratool::get_atomprop $copycharge $hydrogen]
	 }
	 ::Paratool::set_atomprop SupraM $hydrogen $charge
	 set chargegroup($hydrogen) [list $name [lindex $chargegroup($hydrogen) 1] $charge $curcenter]
	 $hsel delete	 
      }
      
      # Adjust the mother atom
      set msel [atomselect $::Paratool::molidbase "index $mother"]
      set name [join [$msel get name]]
      set supram [::Paratool::get_atomprop SupraM $mother]
      set charge [join [$msel get charge]]
      if {$unpolargroup || ($betaposhydrogen && $betapos)} {
	 set charge [expr {$charge+$diff}]
      } else {
	 # Reset to initial charge
	 set charge [::Paratool::get_atomprop $copycharge $mother]
      }
      ::Paratool::set_atomprop SupraM $mother $charge
      set chargegroup($mother) [list $name [lindex $chargegroup($mother) 1] $charge $curcenter]
      $msel delete
   }
   ::Paratool::atomedit_update_list
   ::Paratool::update_atomlabels
   update_formatchargegroup
   update_chargegrouplist

   if {$betaposhydrogen} {
      set secondary [get_secondary_hydrogens]
      if {[llength $secondary]} {
	 set sel [atomselect $::Paratool::molidbase "not index $secondary"]
      } else {
	 set sel [atomselect $::Paratool::molidbase "all"]
      }
   } else {
      set sel [atomselect $::Paratool::molidbase "all"]; # XXX
   }
   set wat [atomselect $molidsyswat "segid CWAT"]
   variable charmmvdw
   variable charmmelstat [compute_elstat_interaction $sel $wat]
   variable charmmnonb   [expr {$charmmelstat+$charmmvdw}]
   variable charmmelstat [format "%16.4f" $charmmelstat]
   variable charmmnonb   [format "%16.4f" $charmmnonb]
}

proc ::CHARMMcharge::get_hydrogen_groups { sel } {
   set molid [$sel molid]

   set motherlist {}
   foreach i [$sel get index] atomicnum [$sel get atomicnumber] {
      # Consider hydrogens
      if {$atomicnum==1} {
	 set hyd [atomselect $molid "index $i"]
	 lappend motherlist [join [$hyd getbonds]]
	 $hyd delete
      }
   }

   set hgrouplist {}
   foreach mother [lsort -unique -integer $motherlist] {
      set mot [atomselect $::Paratool::molidbase "index $mother"]
      set children {}
      foreach child [join [$mot getbonds]] {
	 set chi [atomselect $molid "index $child and index [$sel list]"]
	 if {[join [$chi get atomicnumber]]==1} {
	    lappend children $child
	 }
      }
      lappend hgrouplist [list $mother $children]
      $mot delete
   }

   return $hgrouplist
}


proc ::CHARMMcharge::set_desiredgroupcharge {} {
   variable desiredgroupcharge
   variable chargegroup
   variable chargegrouplist
   variable curcenter

   set indexpos {}
   set indexneg {}
   foreach {ind data} [array get chargegroup] {
      lappend groupindexes $ind
      if {[lindex $data 1]>0} {
	 lappend indexpos $ind
      } else {
	 lappend indexneg $ind
      }
   }

   if {[llength $indexpos]} {
      set selpos [atomselect $::Paratool::molidbase "index $indexpos"]
   } else {
      set selpos [atomselect $::Paratool::molidbase "none"]
   }
   if {[llength $indexneg]} {
      set selneg [atomselect $::Paratool::molidbase "index $indexneg"]
   } else {
      set selneg [atomselect $::Paratool::molidbase "none"]
   }
   set totalpos 0.0
   foreach q [$selpos get charge] {
      set totalpos [expr {$totalpos+$q}]
   }
   set totalneg 0.0
   foreach q [$selneg get charge] {
      set totalneg [expr {$totalneg+$q}]
   }

   set totalcharge [expr {$totalpos+$totalneg}]
   set diff [expr {$desiredgroupcharge-$totalcharge}]
   set ta [expr {$totalpos+abs($totalneg)}]
   if {$diff==0.0} { return }

   foreach q [$selpos get charge] ind [$selpos get index] name [$selpos get name] {
      if {$ta==0.0} { 
	 set dq [expr {$diff/[$selpos num]}]
      } else {
	 set dq [expr {$q/$ta*$diff}]
      }
      ::Paratool::set_atomprop SupraM $ind [expr {$q+$dq}]
      ::Paratool::set_atomprop Charge $ind [expr {$q+$dq}]
#      set charge [::Paratool::get_atomprop Charge $ind]
      set chargegroup($ind) [list $name [lindex $chargegroup($ind) 1] [expr {$q+$dq}] $curcenter]
   }
   foreach q [$selneg get charge] ind [$selneg get index] name [$selneg get name] {
      if {$ta==0.0} { 
	 set dq [expr {-$diff/[$selneg num]}]
      } else {
	 set dq [expr {$q/$ta*$diff}]
      }
      ::Paratool::set_atomprop SupraM $ind [expr {$q-$dq}]
      ::Paratool::set_atomprop Charge $ind [expr {$q-$dq}]
      #set charge [::Paratool::get_atomprop Charge $ind]
      set chargegroup($ind) [list $name [lindex $chargegroup($ind) 1] [expr {$q-$dq}] $curcenter]
   }

   ::Paratool::atomedit_update_list
   ::Paratool::update_atomlabels
   update_formatchargegroup
   update_chargegrouplist

   variable molidsyswat
   variable betaposhydrogen
   if {$betaposhydrogen} {
      set secondary [get_secondary_hydrogens]
      if {[llength $secondary]} {
	 set sel [atomselect $::Paratool::molidbase "not index $secondary"]
      } else {
	 set sel [atomselect $::Paratool::molidbase "all"]
      }
   } else {
      set sel [atomselect $::Paratool::molidbase "all"]
   }
   set wat [atomselect $molidsyswat "segid CWAT"]
   variable charmmvdw
   variable charmmelstat [compute_elstat_interaction $sel $wat]
   variable charmmnonb   [expr {$charmmelstat+$charmmvdw}]
   variable charmmelstat [format "%16.4f" $charmmelstat]
   variable charmmnonb   [format "%16.4f" $charmmnonb]
}


proc ::CHARMMcharge::compute_water_interaction {dist} {
   variable curcenter
   variable waterdir
   variable waterpartner
   variable molidsyswat
   set selcenter  [atomselect $molidsyswat "index $curcenter"]
   set centerpos  [join [$selcenter get {x y z}]]
   set selpartner [atomselect $molidsyswat "index $waterpartner"]
   set partnerpos [join [$selpartner get {x y z}]]
   set dir [vecnorm [vecsub $partnerpos $centerpos]]
   set realdist [veclength [vecsub $partnerpos $centerpos]]
   set sel    [atomselect $molidsyswat "not segid CWAT"]
   set selwat [atomselect $molidsyswat "segid CWAT"]
   # Store the original water position
   set origpos [$selwat get {x y z}]
   # Move water to the desired distance
   $selwat moveby [vecscale [expr $dist-$realdist] $dir]
   draw arrow $partnerpos [vecadd $partnerpos [vecscale [expr $dist-$realdist] $dir]] 0.2

   #puts "E=[compute_energies]"
   #set vdw    [get_vdw_interaction]
   #set elstat [get_elec_interaction]
   set vdw    [compute_vdw_interaction $sel $selwat {occupancy beta}]
   set elstat [compute_elstat_interaction $sel $selwat]
   set centerpos  [join [$selcenter get {x y z}]]
   set partnerpos [join [$selpartner get {x y z}]]
   set real [veclength [vecsub $partnerpos $centerpos]]
puts "dist=$dist  realdist=$realdist real=$real vdw=$vdw elec=$elstat"
   # Restore water position
   $selwat lmoveto $origpos
   return [expr $vdw+$elstat]

}

proc ::CHARMMcharge::scaling_error { newq } {
   # Assign new charges
   variable scalesel
   $scalesel set charge $newq
   puts "newq={$newq}"
   # Get the difference of the total group charge to the target group charge
   variable desiredgroupcharge
   variable groupsel
   set totalq 0.0
   foreach q [$groupsel get charge] { set totalq [expr {$totalq+$q}] }
   set qdiff [expr {$totalq-$desiredgroupcharge}]

   # Compute the dipole moment
   set sel [atomselect $::Paratool::molidbase all]
   set dipole [::Paratool::compute_dipolemoment $sel]
   $sel delete

   # Get nonbonded interaction
   set nonb [::CHARMMcharge::update_energies]

   # Compare QM based and point charge based dipole moments
   variable ::Paratool::dipolemoment
   set dipoledir  [vecdot [vecnorm $dipole] [vecnorm $dipolemoment]]
   set dipolediff [expr {[veclength $dipole]-[veclength $dipolemoment]}]

   puts "[expr {pow($nonb-$::CHARMMcharge::scfinter,2)}] [expr {pow($dipoledir,2)}] [expr {pow($dipolediff,2)}] pow($qdiff,4)"
   return [expr {pow($nonb-$::CHARMMcharge::scfinter,2)+pow($dipoledir,2)+pow($dipolediff,2) + pow(10*$qdiff,4)}]
}

proc ::CHARMMcharge::compute_nonb_interaction { sel1 sel2 } {
   set vdw    [compute_vdw_interaction $sel1 $sel2]
   set elstat [compute_elstat_interaction $sel1 $sel2]
   return [expr $vdw+$elstat]
}

##########################################################
# Computes the electrostatic interaction between two     #
# selections. The cutoff can be specified as an optional #
# parameter.                                             #
##########################################################

proc ::CHARMMcharge::compute_elstat_interaction { sel1 sel2 {cut 0}} {
   set kcalmol 332.0636; # expr 1.0e10/(4.0*$pi*8.85419e-12*4184)*6.02214e23*pow(1.60218e-19,2)
   variable totalelstat 0.0
   foreach q1 [$sel1 get charge] r1 [$sel1 get {x y z}] {
      foreach q2 [$sel2 get charge] r2 [$sel2 get {x y z}] {
	 set q1 [format "%.4f" $q1]
	 set q2 [format "%.4f" $q2]
	 set dist [veclength [vecsub $r2 $r1]]
	 if {$cut!=0} {
	    set efac [expr 1.0-$dist*$dist/($cut*$cut)]
	    set elstat [expr $kcalmol*$q1*$q2/$dist*$efac*$efac]
	 } else {
	    set elstat [expr $kcalmol*$q1*$q2/$dist]
	 }
	 set totalelstat [expr $totalelstat+$elstat]
      }
   }

   return $totalelstat
}


##########################################################
# Computes the Van der Waals interaction between two     #
# selections. The vdw parameters must be stored in atom  #
# based fields e.g. {occupancy beta}.                    #
##########################################################

# !!! ATTENTION !!!
# I don't know why, but this function gives wrong VDW energies:-(
# I'm using the NAMDserver now, but one day I would like to find out what's the problem here...
# switchfactor = 1.f/((cutoff2 - switchdist2)*(cutoff2 - switchdist2)*(cutoff2 - switchdist2));
# vdw *= switchfactor*(cutoff2 - dist2)*(cutoff2 - dist2)*(cutoff2 - 3.f*switchdist2 + 2.f*dist2);
 proc ::CHARMMcharge::compute_vdw_interaction { sel1 sel2 {vdwfields {occupancy beta}}} {
    variable totalvdw 0.0
    foreach r1 [$sel1 get {x y z}] ind1 [$sel1 get index] {
       set vdwrmin1 [::Paratool::get_atomprop VDWrmin $ind1]
       set vdweps1  [::Paratool::get_atomprop VDWeps  $ind1]
       foreach r2 [$sel2 get {x y z}] vdwrmin2 [$sel2 get [lindex $vdwfields 0]] vdweps2 [$sel2 get [lindex $vdwfields 1]] ind2 [$sel2 get index] {
	  #set vdwrmin2 [::Paratool::get_atomprop VDWrmin $ind2]
	  #set vdweps2  [::Paratool::get_atomprop VDWeps  $ind2]
	  set rmin [expr {($vdwrmin1+$vdwrmin2)}]
	  set dist [veclength [vecsub $r2 $r1]]
	  set term6 [expr {pow($rmin/$dist,6)}]
	 
	  set vdwenergy [expr {sqrt($vdweps1*$vdweps2)*($term6*$term6 - 2.0*$term6)}]
	  #puts "$ind1-$ind2 rmin=$rmin dist=$dist e=$vdwenergy"
	  set totalvdw  [expr {$totalvdw+$vdwenergy}]
       }
    }

    return $totalvdw
 }


proc ::CHARMMcharge::compute_equilib_distance {sel1 sel2} {
   variable selmol $sel1
   variable selwat $sel2
   variable waterdist
   #set simplex [list $waterdist [expr $waterdist+0.1]]
   #set y [compute_water_interaction $waterdist]
   #lappend y [compute_water_interaction [expr $waterdist+0.1]]
   #   set equi [::Optimize::simplex_optimization $simplex $y 0.001 "::CHARMMcharge::compute_water_interaction" 100]
   puts [$sel2 get {occupancy beta}]
   set maxiter 10.0
   for {set i 0} {$i<$maxiter} {incr i} {
      set dist [expr 0.5+$i/$maxiter*2.0]
      set equi   [compute_water_interaction $dist]
      puts "$i: dist=$dist equi=$equi \n"
 }
   puts "equilib distance=$equi"
   return $equi
}



###################################################################
# Start molefacture with the base molecule.                       #
###################################################################

proc ::CHARMMcharge::molefacture_start { {msel {}} } {
   variable molidsyswat
   if {$molidsyswat<0} { 
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please load a system+water molecule first!"
      return 0
   }

   # Remove traces and leave pickmode "chargegroup"
   global vmd_pick_atom
   trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn
   mouse mode 0
   mouse callback off;
   set ::Paratool::picklist {};
   set ::Paratool::pickmode "none"; 

   if {![llength $msel]} {
      set msel [atomselect $molidsyswat "all"]
      ::Molefacture::molefacture_gui $msel
      $msel delete
   } else {
      ::Molefacture::molefacture_gui $msel
   }

   #puts "parent=$molidparent base=$molidbase msel=[$msel text] num=[$msel num] names=[$msel get {name atomicnumber}]"

   variable molnamesyswat
   #set filename "[regsub {_hydrogen|_molef} [file rootname ${molnamesyswat}] {}]_molef.xbgf"
   ::Molefacture::set_slavemode ::CHARMMcharge::molefacture_callback $molnamesyswat
}


###################################################################
# function to be called when editing in molefacture is finished.  #
###################################################################

proc ::CHARMMcharge::molefacture_callback { filename } {
   puts "Molefacture_callback $filename"
   load_syswat $filename

#   variable molidbase
#   set all   [atomselect $molidbase "all"]

#   set hydro [atomselect $molidbase "beta 0.8"]
#   $all   set beta 0.0
#   $hydro set beta 0.5
#   $all delete
#   $hydro delete

   if {[winfo exists .charmmcharge]} {
      set_pickmode_chargegroup
   }
}

