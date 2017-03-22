#
# Add/Edit internal coordinates
#
# $Id: paratool_intcoor.tcl,v 1.15 2007/09/12 13:42:49 saam Exp $
#
proc ::Paratool::edit_internal_coords {} {
   variable w
   variable selectcolor
   variable fixedfont
   # If already initialized, just turn on
   if { [winfo exists .paratool_intcoor] } {
      set geom [winfo geometry .paratool_intcoor]
      wm withdraw  .paratool_intcoor
      wm deiconify .paratool_intcoor
      wm geometry  .paratool_intcoor $geom
      focus .paratool_intcoor
      return
   }

   set v [toplevel ".paratool_intcoor"]
   wm title $v "Add/Edit internal coordinates"
   wm resizable $v 0 0
   wm protocol $v WM_DELETE_WINDOW {
      # Clear all intcoor labels
      #.paratool_intcoor.zmat.pick.list selection clear 0 end;
      set ::Paratool::selintcoorlist {};
      ::Paratool::update_intcoorlabels; 
      if {![winfo exists .paratool_atomedit]} {
	 set ::Atomedit::paratool_atomedit_selection {}
	 ::Paratool::update_atomlabels
	 ::Paratool::atomedit_draw_selatoms
      }
      set ::Paratool::pickmode none
      mouse mode 0;
      #::Paratool::remove_traces; 
      destroy .paratool_intcoor
      destroy .paratool_potscan
      destroy .paratool_chooseanalog
      destroy .paratool_refinement
      ::Paratool::update_intcoorlabels
      focus .paratool
   }


   ############## frame for Z-matrix #################
   labelframe $v.zmat -bd 2  -text "Internal coordinates"
   
   frame $v.zmat.info
   label $v.zmat.info.natomslabel -text "Atoms:"
   label $v.zmat.info.natomsvar -textvariable ::Paratool::natoms
   grid $v.zmat.info.natomslabel -row 0 -column 0 -sticky e -padx 1m
   grid $v.zmat.info.natomsvar   -row 0 -column 1 -sticky e -padx 1m

   label $v.zmat.info.ncoordslabel -text "Coords:"
   label $v.zmat.info.ncoordsvar -textvariable ::Paratool::ncoords
   grid $v.zmat.info.ncoordslabel -row 0 -column 2 -sticky e -padx 1m
   grid $v.zmat.info.ncoordsvar   -row 0 -column 3 -sticky e -padx 1m

   label $v.zmat.info.nbondslabel -text "Bonds:"
   label $v.zmat.info.nbondsvar -textvariable ::Paratool::nbonds
   grid $v.zmat.info.nbondslabel -row 0 -column 4 -sticky e -padx 1m
   grid $v.zmat.info.nbondsvar   -row 0 -column 5 -sticky e -padx 1m

   label $v.zmat.info.nangleslabel -text "Angles:"
   label $v.zmat.info.nanglesvar -textvariable ::Paratool::nangles
   grid $v.zmat.info.nangleslabel -row 0 -column 6 -sticky e -padx 1m
   grid $v.zmat.info.nanglesvar   -row 0 -column 7 -sticky e -padx 1m

   label $v.zmat.info.ndihedslabel -text "Diheds:"
   label $v.zmat.info.ndihedsvar -textvariable ::Paratool::ndiheds
   grid $v.zmat.info.ndihedslabel -row 0 -column 8 -sticky e -padx 1m
   grid $v.zmat.info.ndihedsvar   -row 0 -column 9 -sticky e -padx 1m

   label $v.zmat.info.nimprpslabel -text "Impropers:"
   label $v.zmat.info.nimprpsvar -textvariable ::Paratool::nimprops
   grid $v.zmat.info.nimprpslabel -row 0 -column 10 -sticky e -padx 1m
   grid $v.zmat.info.nimprpsvar   -row 0 -column 11 -sticky e -padx 1m

   set labeltext "Pick a conformation using left mouse button"
   labelframe $v.zmat.pick -borderwidth 2 -pady 2m -padx 2m -text $labeltext   

   label $v.zmat.pick.format -textvariable ::Paratool::intcoorformat \
      -relief flat -bd 2 -justify left -font $fixedfont
   
   scrollbar $v.zmat.pick.scroll -command "$v.zmat.pick.list yview" -takefocus 0
   listbox $v.zmat.pick.list -yscroll "$v.zmat.pick.scroll set" \
      -width 115 -height 18 -activestyle none -setgrid 1 -selectmode extended -selectbackground $selectcolor \
      -listvariable ::Paratool::formatintcoorlist
   # we need a fixed font for proper formatting
   $v.zmat.pick.list configure -font $fixedfont

   grid $v.zmat.pick.format    -row 1 -column 0 -sticky w
   grid $v.zmat.pick.list      -row 2 -column 0 -sticky wns
   grid $v.zmat.pick.scroll    -row 2 -column 1 -sticky ns; #-side left -fill y -expand 1 

   # Pack the zmat frame
   pack $v.zmat.info $v.zmat.pick  -padx 2 -pady 2 -side top -expand 1 -fill y

   frame $v.frame2 -bd 0
   labelframe $v.frame2.type -bd 2 -text "Add coordinate" 
   radiobutton $v.frame2.type.bond  -text bond -variable ::Paratool::addtype -value bond \
      ;#-command ::Paratool::set_pickmode_bond
   checkbutton $v.frame2.type.vmdbond   -text "add bond only to VMD's bondlist (just draw it)" \
      -variable ::Paratool::genvmdbond -padx 5m -command {
	 if {$::Paratool::genvmdbond} { 
	    .paratool_intcoor.frame2.type.addangle configure -state disabled
	    .paratool_intcoor.frame2.type.adddihed configure -state disabled
 	 } else {
	    .paratool_intcoor.frame2.type.addangle configure -state normal
	    .paratool_intcoor.frame2.type.adddihed configure -state normal
	 }
      }
   checkbutton $v.frame2.type.addangle  -text "add all angles involving the bond" \
      -variable ::Paratool::gendepangle -padx 5m
   checkbutton $v.frame2.type.adddihed  -text "add all dihedrals involving the bond" \
      -variable ::Paratool::gendepdihed -padx 5m -command {
# 	 if {$::Paratool::gendepdihed} { 
# 	    .paratool_intcoor.frame2.type.adddihedone configure -state normal 
# 	    .paratool_intcoor.frame2.type.adddihedall configure -state normal 
# 	 } else {
# 	    .paratool_intcoor.frame2.type.adddihedone configure -state disabled
# 	    .paratool_intcoor.frame2.type.adddihedall configure -state disabled
# 	 }
      }
#    radiobutton $v.frame2.type.adddihedone  -text "add one dihedral per bond torsion" \
#       -variable ::Paratool::gendepdihedmode -value "one" -padx 9m
#    radiobutton $v.frame2.type.adddihedall  -text "add all dihedrals for the bond torsion" \
#       -variable ::Paratool::gendepdihedmode -value "all" -padx 9m
   radiobutton $v.frame2.type.angle -text angle -variable ::Paratool::addtype -value angle \
      ;# -command ::Paratool::set_pickmode_angle
   radiobutton $v.frame2.type.dihed -text dihed -variable ::Paratool::addtype -value dihed \
      ;# -command ::Paratool::set_pickmode_dihed
   radiobutton $v.frame2.type.imprp -text improper -variable ::Paratool::addtype -value imprp \
      ;#-command ::Paratool::set_pickmode_imprp
   pack $v.frame2.type.bond $v.frame2.type.vmdbond $v.frame2.type.addangle $v.frame2.type.adddihed $v.frame2.type.angle \
      $v.frame2.type.dihed $v.frame2.type.imprp -anchor w
   button $v.frame2.type.add -text "Add coordinate" -command ::Paratool::add_coordinate
   pack $v.frame2.type.add -anchor n  -expand 1

   labelframe $v.frame2.modify -text "Set/Modify selected parameters"
   button $v.frame2.modify.analogy  -text "Get parameters from analog conformations" \
      -command ::Paratool::choose_analog_parameters_gui
   frame $v.frame2.modify.use
   button $v.frame2.modify.use.qm    -text "Use QM parameters" \
      -command ::Paratool::use_qm_parameters
   button $v.frame2.modify.use.fofi  -text "Use force field parameters" \
      -command ::Paratool::use_fofi_parameters
   pack $v.frame2.modify.use.qm $v.frame2.modify.use.fofi -side left
   checkbutton $v.frame2.modify.override  -text "Use existing parameters where possible" \
       -variable ::Paratool::charmmoverridesqm -command ::Paratool::assign_unknown_force_constants_from_zmatqm
   checkbutton $v.frame2.modify.exactdel -text "Use exact dihedral delta values" -variable ::Paratool::exactdihedrals \
      -command { ::Paratool::toggle_exact_dihedrals }
   button $v.frame2.modify.refine  -text "Refine parameters of selected conformation" \
      -command ::Paratool::Refinement::gui
   button $v.frame2.modify.edit    -text "Edit parameters of selected conformation" \
      -command ::Paratool::edit_selected_parameters_gui
      

   pack $v.frame2.modify.analogy  -side top 
   pack $v.frame2.modify.use      -side top 
   pack $v.frame2.modify.override -side top 
   pack $v.frame2.modify.exactdel -side top 
   pack $v.frame2.modify.refine   -side top 
   pack $v.frame2.modify.edit     -side top 

   frame $v.frame2.c
   labelframe $v.frame2.c.del -bd 2 -text "Delete coordinates"
   checkbutton $v.frame2.c.del.dep -text "Delete dependent coordinates, too" -variable {::Paratool::removedependent}
   frame $v.frame2.c.del.button
   button $v.frame2.c.del.button.sel -text "Delete selected" -command {::Paratool::del_coordinate}
   button $v.frame2.c.del.button.all -text "Delete all" -command {::Paratool::clear_zmat}
   pack $v.frame2.c.del.button.sel $v.frame2.c.del.button.all -side left
   pack $v.frame2.c.del.dep $v.frame2.c.del.button


   labelframe $v.frame2.c.fix -text "Fix coordinates" 
   frame $v.frame2.c.fix.sel
   button $v.frame2.c.fix.sel.fix -text "Fix selected" -command {::Paratool::fix_coordinate -fix}
   button $v.frame2.c.fix.sel.unfix -text "Unfix selected" -command {::Paratool::fix_coordinate -unfix}
   frame $v.frame2.c.fix.all
   button $v.frame2.c.fix.all.fix -text "Fix all" -command {::Paratool::fix_all -fix}
   button $v.frame2.c.fix.all.unfix -text "Unfix all" -command {::Paratool::fix_all -unfix}
   pack $v.frame2.c.fix.sel.fix $v.frame2.c.fix.sel.unfix  -side left
   pack $v.frame2.c.fix.all.fix $v.frame2.c.fix.all.unfix  -side left
   pack $v.frame2.c.fix.sel $v.frame2.c.fix.all

   labelframe $v.frame2.c.recalc -bd 2 -text "Distance dependent bond recalculation" 
   frame   $v.frame2.c.recalc.labelspin
   label   $v.frame2.c.recalc.labelspin.label -text "maximum bond length:"
   spinbox $v.frame2.c.recalc.labelspin.spinb -from 0 -to 10 -increment 0.05 -width 5 \
      -textvariable ::Paratool::maxbondlength
   pack $v.frame2.c.recalc.labelspin.label $v.frame2.c.recalc.labelspin.spinb \
      -anchor w -side left -padx 1m 
   button $v.frame2.c.recalc.button -text "Recalculate bonds" -command {::Paratool::recalculate_bonds}
   pack $v.frame2.c.recalc.labelspin $v.frame2.c.recalc.button 

   pack $v.frame2.c.del -fill x    -expand 1
   pack $v.frame2.c.fix -fill x    -expand 1 -pady 2m
   pack $v.frame2.c.recalc -fill x -expand 1


   # Pack frame2
   pack $v.frame2.type   -side left -fill both -expand 1 -padx 1m -pady 1m
   pack $v.frame2.modify -side left -fill both -expand 1 -padx 1m -pady 1m
   pack $v.frame2.c      -side left -fill both -expand 1 -padx 1m -pady 1m


   frame $v.frame3
   labelframe $v.frame3.scaling -text "Labels and Markers"  -padx 2 -pady 2
   label $v.frame3.scaling.textlabel -text "Label text size:"
   spinbox $v.frame3.scaling.textspin -from 0.05 -to 10 -increment 0.05 -width 5 \
      -textvariable ::Paratool::labelsize -command {::Paratool::update_intcoorlabels}
   grid $v.frame3.scaling.textlabel -column 0 -row 0 -sticky w
   grid $v.frame3.scaling.textspin  -column 1 -row 0 -sticky w

   label $v.frame3.scaling.tubelabel -text "Marker radius scale factor:"
   spinbox $v.frame3.scaling.tubespin -from 0 -to 10 -increment 0.01 -width 5 \
      -textvariable ::Paratool::labelradius -command {::Paratool::update_intcoorlabels}
   grid $v.frame3.scaling.tubelabel -column 0 -row 1 -sticky w
   grid $v.frame3.scaling.tubespin  -column 1 -row 1 -sticky w

   label $v.frame3.scaling.thicklabel -text "Bond thickness:"
   spinbox $v.frame3.scaling.thickspin -from 0 -to 10 -increment 0.01 -width 5 \
      -textvariable ::Paratool::bondthickness -command [namespace code {
 	 variable molidbase
 	 variable fragmentrepbase
 	 variable bondthickness
 	 mol representation "Bonds $bondthickness"
 	 mol modrep [mol repindex $molidbase $fragmentrepbase] $molidbase
 	 mol representation "VDW $bondthickness"
 	 mol modrep [expr {[mol repindex $molidbase $fragmentrepbase]+1}] $molidbase
      }]

   grid $v.frame3.scaling.thicklabel -column 0 -row 2 -sticky w
   grid $v.frame3.scaling.thickspin  -column 1 -row 2 -sticky w

   checkbutton $v.frame3.scaling.check -text "Scale marker thickness with force constant" \
      -variable ::Paratool::labelscaling -command {::Paratool::update_intcoorlabels}
   grid $v.frame3.scaling.check -column 0 -row 3 -sticky wns -columnspan 2


   labelframe $v.frame3.gen -text "Automatic coordinate generation"  -padx 2 -pady 2
   radiobutton $v.frame3.gen.one -text "Generate one dihedral per torsion" -value one \
      -variable {::Paratool::autogendiheds}
   radiobutton $v.frame3.gen.all -text "Generate all dihedrals per torsion" -value all \
      -variable {::Paratool::autogendiheds}
   checkbutton $v.frame3.gen.top -text "Import impropers for known conformations" \
      -variable {::Paratool::importknowntopo}
   button $v.frame3.gen.auto -text "Autogenerate internal coordinates" -command {::Paratool::autogenerate_zmat}
   pack $v.frame3.gen.one $v.frame3.gen.all $v.frame3.gen.top $v.frame3.gen.auto -anchor w -fill x 


   labelframe $v.frame3.misc -text "Misc"   -padx 2 -pady 2
   button $v.frame3.misc.transform -text "Recalculate parameters from Hessian" \
      -command ::Paratool::transform_hessian_cartesian_to_internal
   button $v.frame3.misc.potscan -text "Potential energy scan" \
      -command { ::Paratool::potential_scan_gui }
   pack $v.frame3.misc.transform -side top -anchor w
   pack $v.frame3.misc.potscan   -side top -anchor w


   # Pack frame3
   pack $v.frame3.scaling $v.frame3.gen $v.frame3.misc -side left -anchor n -fill both -expand 1 -padx 1m -pady 1m

   # Pack the main frame
   pack $v.zmat $v.frame2 $v.frame3  -fill both -expand 1 -padx 1m -pady 1m 



   # This will be executed when items are selected:   
   bind $v.zmat.pick.list <<ListboxSelect>> {
      ::Paratool::select_intcoor [.paratool_intcoor.zmat.pick.list curselection]
   }

   # Set key bindings
   bind $v <Key-s> {
      ::Paratool::toggle_bondorder "single"
   }

   bind $v <Key-d> {
      ::Paratool::toggle_bondorder "double"
   }

   bind $v <Key-t> {
      ::Paratool::toggle_bondorder "triple"
   }

  bind $v <Control-a> {
     .paratool_intcoor.zmat.pick.list selection set 0 end
     ::Paratool::select_intcoor [.paratool_intcoor.zmat.pick.list curselection]
   }

   # This will be executed when the focus changes to the window
   bind $v <FocusIn> {
      if {"%W"==".paratool_intcoor"} {

	 # Restore selection
	 foreach i $::Paratool::selintcoorlist {
	    .paratool_intcoor.zmat.pick.list selection set $i
	 }

	 #puts "Focus on .paratool_intcoor; %W"
	 focus .paratool_intcoor.zmat.pick.list
      }
   }

   bind $v.zmat.pick.list <1> {
      focus %W
   }

   # Set bond mode as default
   set_pickmode_conf

   # Restore selection
   variable selintcoorlist
   .paratool_intcoor.zmat.pick.list selection clear 0 end
   foreach i $selintcoorlist {
      .paratool_intcoor.zmat.pick.list selection set $i
      .paratool_intcoor.zmat.pick.list see $i
   }
   select_intcoor $selintcoorlist

   update_intcoorlist
}


##################################################
# Updates the internal coordinates list.         #
##################################################

proc ::Paratool::update_zmat { {newzmat {}} } {
   variable zmat
   if {[llength $newzmat]} {
      variable zmat $newzmat
   }
   set header [lindex $zmat 0]
   variable natoms   [lindex $header 0]
   variable ncoords  [lindex $header 1]
   variable nbonds   [lindex $header 2]
   variable nangles  [lindex $header 3]
   variable ndiheds  [lindex $header 4]
   variable nimprops [lindex $header 5]
   variable havepar  [lindex $header 6]
   variable havefc   [lindex $header 7]

   # only update the picklist if a molecule is present:
   variable molidbase
   if {$molidbase>=0} {
      if {[molinfo $molidbase get numframes]>0} {
	 variable natoms   [molinfo $molidbase get numatoms]
	 update_intcoorlist
	 update_selectedpar
	 update_selparamlist
      }
   }

   return 1
}


#################################################
# Remeasure the internal coordinate values.     #
#################################################

proc ::Paratool::update_internal_coordinate_values {} {
   set i 0
   variable zmat
   variable molidbase

   foreach entry $zmat {
      if {$i==0} { incr i; continue }
      switch -glob [lindex $entry 0] {
	 R* { lset zmat $i 3 [measure bond  [lindex $entry 2] molid $molidbase frame last] }
	 A* { lset zmat $i 3 [measure angle [lindex $entry 2] molid $molidbase frame last] }
	 D* { lset zmat $i 3 [measure dihed [lindex $entry 2] molid $molidbase frame last] }
	 O* { lset zmat $i 3 [measure imprp [lindex $entry 2] molid $molidbase frame last] }
      }
      incr i
   }
}

##################################################
# Deletes all internal coordinate entries.       #
##################################################

proc ::Paratool::clear_zmat { } {
   variable zmat
   variable natoms  [lindex [lindex $zmat 0] 0]
   variable ncoords 0
   variable nbonds  0
   variable nangles 0
   variable ndiheds 0
   variable nimprops 0
   variable havepar 0
   variable havefc  0
   variable zmat [list [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]]
   variable selintcoorlist {}
   update_intcoorlist
   return 1
}


proc ::Paratool::select_intcoor { intcoorlist {update "updatepicklist"}} {
   variable selintcoorlist 

   if {[winfo exists  .paratool_intcoor.zmat.pick.list]} {
      # Blank all item backgrounds
      foreach i $selintcoorlist {
	 .paratool_intcoor.zmat.pick.list itemconfigure $i -background {}
      }
   }
   
   variable selintcoorlist [lsort -unique -integer $intcoorlist]
   foreach i $selintcoorlist {
      if {[winfo exists  .paratool_intcoor.zmat.pick.list]} {
	 # Set background color for selected items
	 .paratool_intcoor.zmat.pick.list itemconfigure $i -background $::Paratool::selectcolor
      }
      if {$update=="updatepicklist"} {
	 select_atoms [join [lindex $::Paratool::zmat [expr {$i+1}] 2]]
      }
   }

   update_intcoorlabels
   choose_analog_parameters
   update_intcoorformatstring
   update_selectedpar
   update_selparamlist
   ::Paratool::Refinement::update_paramlist
   after idle {::Paratool::Hessian::select_item $::Paratool::selintcoorlist}
}


####################################################################
# Updates the formatted internal coordinates list for the listbox. #
####################################################################

proc ::Paratool::update_intcoorlist {} {
   variable zmat
   set intcoorlist {}

   if {![winfo exists .paratool_intcoor.zmat.pick.list]} { return 0 }

   # These are the tags that appear in the listing:
   set num 0
   foreach t $zmat {
      if {$num>0} {
	 set typelist {}
	 foreach i [lindex $t 2] {
	    set atomtype [get_atomprop Type $i]
	    if {![llength $atomtype]} { set atomtype {{}} }
	    append typelist [format " %4s" $atomtype]
	 }
	 set type [lindex $t 1]
	 if {[string equal $type "angle"]} {
	    set x   [format_float "%.2f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.2f" [lindex $t 4 1]]
	    set kub [format_float "%.3f" [lindex $t 4 2]]
	    set s0  [format_float "%.4f" [lindex $t 4 3]]
	    set tag [format "%5s %5s %17s  %21s %9s %9s %9s %9s %9s %s" [lindex $t 0] [lindex $t 1] [lindex $t 2] \
			$typelist $x $k $x0 $kub $s0 [lindex $t 5]]
	 } elseif {[string equal $type "dihed"]} {
	    set x     [format_float "%.2f" [lindex $t 3]]
	    set k     [format_float "%.3f" [lindex $t 4 0]]
	    set delta [format_float "%.2f" [lindex $t 4 2]]
	    set tag [format "%5s %5s %17s  %21s %9s %9s %3s %9s %s" [lindex $t 0] [lindex $t 1] [lindex $t 2] \
			$typelist $x $k [lindex $t 4 1] $delta [lindex $t 5]]
	 } elseif  {[string equal $type "imprp"]} {
	    set x   [format_float "%.2f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.2f" [lindex $t 4 1]]
	    set tag [format "%5s %5s %17s  %21s %9s %9s %9s %s" [lindex $t 0] [lindex $t 1] [lindex $t 2] \
			$typelist $x $k $x0 [lindex $t 5]]
	 } else {
	    set x   [format_float "%.4f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.4f" [lindex $t 4 1]]
	    set tag [format "%5s %5s %17s  %21s %9s %9s %9s %s" [lindex $t 0] [lindex $t 1] [lindex $t 2] \
			$typelist $x $k $x0 [lindex $t 5]]
	 }
	 lappend intcoorlist "$tag"
      }
      incr num
   }

   variable formatintcoorlist $intcoorlist

   update_intcoorlabels;       # The graphics labels (tubes) in the OpenGL window  
   update_intcoorformatstring; # This is the legend on top of the listbox
   return 1
}

proc ::Paratool::update_intcoorlabels {} {
   variable molidbase
   # Don't do anything if the molecule doesn't exist or contains no frames
   if {$molidbase<0} { return 0 }
   if {[molinfo $molidbase get numframes]<0} { return 0 }

   variable zmat
   variable labelradius
   variable labelsize
   variable pickmode
   variable selintcoorlist
   variable intcoormarktags

   # Delete any previously generated atomlabels
   variable intcoormarktags
   foreach tag $intcoormarktags {
      graphics $molidbase delete $tag
   }
   set intcoormarktags {}
   
   # Return if there are no internal coords
   if {[llength $zmat]==1} { return 1 }

   # Update the internal coordinate labels
   if {[llength $selintcoorlist]} {
      set indexes {}
      foreach conf $selintcoorlist {
	 # Have to add +1 to the index because of the header entry
	 if {$conf+1<[llength $zmat]} {
	    fc_label [lindex $zmat [expr {$conf+1}]]
	    lappend indexes [lindex [lindex $zmat [expr {$conf+1}]] 2]
	 }
      }
   }	    
}

proc ::Paratool::update_intcoorformatstring {} {
   if {![winfo exists  .paratool_intcoor.zmat.pick.list]} { return }

   set i $::Paratool::selintcoorlist;

   if {[llength $i]!=1} { set i [.paratool_intcoor.zmat.pick.list index active] }
   variable zmat
   set type [lindex $zmat [expr {$i+1}] 1]
   if {[string match "*bond" $type]} {
      variable intcoorformat [format " %4s %5s %17s  %21s %9s %9s %9s %s" \
				 Name Type Indexes Atomtypes R  K_r R_0 Flags]
      variable selparformat [format "%5s %21s %9s %9s %9s" Name Atomtypes R K_r R_0]
      variable selpareditformat [format "%9s %9s" K_r R_0]
      variable scanwidth   0.4
      variable qmscanwidth 0.4
   } elseif {$type=="angle" || $type=="lbend"} {
      variable intcoorformat [format " %4s %5s %17s  %21s %9s %9s %9s %9s %9s %s" \
				 Name Type Indexes Atomtypes Theta K_theta Theta_0 K_ub S_0 Flags]
      variable selparformat [format "%5s %21s %9s %9s %9s %9s %9s" \
				Name Atomtypes Theta K_theta Theta_0 K_ub S_0]
      variable selpareditformat [format "%9s %9s %9s %9s" K_theta Theta_0 K_ub S_0]
      variable scanwidth   10.0
      variable qmscanwidth 10.0
   } elseif {$type=="dihed"} {
      variable intcoorformat [format " %4s %5s %17s  %21s %9s %9s %3s %9s %s" \
				 Name Type Indexes Atomtypes Chi K_chi n delta Flags]
      variable selparformat [format "%5s %21s %9s %9s %9s %9s" \
				Name Atomtypes Chi K_chi n delta]
      variable selpareditformat [format "%9s %9s %9s" K_chi n delta]
      variable scanwidth   360.0
      variable qmscanwidth 360.0
   } elseif {$type=="imprp"} {
      variable intcoorformat [format " %4s %5s %17s  %21s %9s %9s %9s %s" \
				 Name Type Indexes Atomtypes Psi K_psi Psi_0 Flags]
      variable selparformat [format "%5s %21s %9s %9s %9s" \
				Name Atomtypes Psi K_psi Psi_0]
      variable selpareditformat [format "%9s %9s" K_psi Psi_0]
      variable scanwidth   10.0
      variable qmscanwidth 10.0
   }
}

proc ::Paratool::add_coordinate { } {
   variable addtype
   variable picklist
   if {$addtype=="bond" && [llength $picklist]==2} {
      register_bond $picklist
   } elseif {$addtype=="angle" && [llength $picklist]==3} {
      register_angle $picklist
   } elseif {$addtype=="dihed" && [llength $picklist]==4} {
      register_dihed $picklist
   } elseif {$addtype=="imprp" && [llength $picklist]==4} {
      register_imprp $picklist
   }
 
   variable charmmoverridesqm
   if {$charmmoverridesqm} { 
      use_fofi_parameters
   }
}


#####################################################
# Set/unset scanning flag for selected internal     #
# coordinates.                                      #
#####################################################

proc ::Paratool::scan_coordinate { args } {
   set mode "-set"
   set rigid 1
   if {[lsearch $args "-set"]>=0}     { set mode "-set" }
   if {[lsearch $args "-rigid"]>=0}   { set rigid 1 }
   if {[lsearch $args "-relaxed"]>=0} { set rigid 0 }
   variable numfixed 0
   variable zmat
   variable selintcoorlist

   if {$rigid} {
      # Fix all other coordinates
      fix_all -fix
   } else {
      fix_all -unfix
      # Remove all other scanning flags
      set index 1
      foreach entry [lrange $zmat 1 end] {
	 lset zmat $index 5 [regsub -all {[S]} [lindex $zmat $index 5] {}]
	 incr index
      }
   }

   foreach selintcoor $selintcoorlist {
      set izmat [expr {$selintcoor+1}]
      set entry [lindex $zmat $izmat]

      # Find dependent conformations
      # Currently this check is only done for angles and diheds
      # FIXME: Should treat bonds that are in rings!
      set depend [find_linear_dependent_intcoor $izmat]
      foreach pos $depend {
	 set angleind  [lindex $zmat $pos 2]
	 #puts [lindex $zmat $pos]
	 lset zmat $pos 5 [regsub -all {[SF]} [lindex $zmat $pos 5] {}]
      }
     
      if {$mode=="-unset"} {
	 lset zmat $izmat 5 [regsub -all {[S]} [lindex $entry 5] {}]
      } else {
	 lset zmat $izmat 5 "[regsub -all {[SF]} [lindex $entry 5] {}]S"
      }
   }

   # count fixed atoms
   foreach entry $zmat {
      if {[string match "*F*" [lindex $entry 5]]} { incr numfixed }
   }
   update_intcoorlist
}

proc ::Paratool::find_linear_dependent_intcoor {izmatlist} {
   variable zmat
   variable molidbase
   set dep {}

   foreach izmat $izmatlist {
      set entry [lindex $zmat $izmat]
      set name [lindex $entry 0]
      set indexes [lindex $entry 2]

      switch -glob $name {
	 A* {
	    set left   [lindex $indexes 0]
	    set middle [lindex $indexes 1]
	    set right  [lindex $indexes 2]
	    set poslist [lsearch -all $zmat "A* {* $middle *}"]
	    foreach pos $poslist {
	       set angleind  [lindex $zmat $pos 2]
	       # Only consider adjacent angles 
	       if {[lindex $angleind 0]==$left || [lindex $angleind 0]==$right ||
		   [lindex $angleind 2]==$left || [lindex $angleind 2]==$right} {
		  lappend dep $pos
	       } 
	    }
	    if {[is_planar $molidbase $middle]} { continue }
	    set bond1 [lrange $indexes 0 1]
	    set bond2 [lrange $indexes 1 2]
	    # Find all diheds with the same left leg as one of the angle legs
	    set pattern1 "D.*\\s\{(($bond1|[lrevert $bond2])\\s.*)|(.*\\s([lrevert $bond1]|$bond2))\}"
	    # Find all diheds containing the angle
	    set pattern2 "D.*\\s\{(($indexes|[lrevert $indexes])\\s.*)|(.*\\s([lrevert $indexes]|$indexes))\}"
	    # We are looking for all angles matching pattern1 but not pattern2
	    lappend dep [::util::ldiff [lsearch -all -regexp $zmat $pattern1] [lsearch -all -regexp $zmat $pattern2]]
	 }
	 D* {
	    set middle [lrange $indexes 1 2]
	    lappend dep [lsearch -regexp -all $zmat "^D.+\\s\{.+\\s($middle|[lrevert $middle])\\s.+\}"]
	 }
	 O* {
	    # FIXME: I think we must also check the reverse case?
	    set first [lindex $indexes 0]
	    lappend dep [lsearch -all $zmat "O* {$first *}"]
	 }
      }
   }

   return [lsort -integer -unique [join $dep]]
}

proc ::Paratool::is_planar {molid atomind} {
   set sel [atomselect $molid "index $atomind"]
   if {[llength [join [$sel getbonds]]]==3} {
      return 1
   }
   return 0
}

proc ::Paratool::is_tetrahedral {molid atomind} {
   set sel [atomselect $molid "index $atomind"]
   if {[llength [join [$sel getbonds]]]==3} {
      return 1
   }
   return 0
}

#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::Paratool::fix_coordinate { {mode "-fix"} } {
   variable numfixed 0
   variable zmat
   variable selintcoorlist

   set sel [.paratool_intcoor.zmat.pick.list curselection]

   foreach selintcoor $selintcoorlist {
      set izmat [expr {$selintcoor+1}]
      set entry [lindex $zmat $izmat]
     
      if {$mode=="-fix"} {
	 lset zmat $izmat 5 "[regsub -all {[F]} [lindex $entry 5] {}]F"
      } else {
	 lset zmat $izmat 5 [regsub -all {[F]} $entry {}]
      }
   }

   # count fixed atoms
   foreach entry $zmat {
      if {[string match "*F*" [lindex $entry 5]]} { incr numfixed }
   }
   update_intcoorlist
}

#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::Paratool::fix_all { {mode "-fix"} } {
   variable ncoords
   variable numfixed 0
   if {$mode=="-fix"} {
      set numfixed $ncoords
   } 
   variable zmat

   set index 0
   foreach entry $zmat {
      if {$index==0} { incr index; continue }
      if {$mode=="-fix"} {
	 lset zmat $index 5 "[regsub -all {[SF]} [lindex $zmat $index 5] {}]F"
      } else {
	 lset zmat $index 5 [regsub -all {[F]} [lindex $zmat $index 5] {}]
      }
      incr index
   }
   update_intcoorlist
}

#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::Paratool::toggle_bondorder { order } {
   variable zmat

   set sel [.paratool_intcoor.zmat.pick.list curselection]
   set newzmat $zmat
   foreach conf $sel {
      set entry [lindex $zmat [expr {$conf+1}]]
      set type  [lindex $entry 1]
      if {[string match "*bond" $type]} {
	 if {$order=="single"} {
	    lset zmat [expr {$conf+1}] 1 "bond"
	 } elseif {$order=="double"} {
	    lset zmat [expr {$conf+1}] 1 "dbond"
	 } elseif {$order=="triple"} {
	    lset zmat [expr {$conf+1}] 1 "tbond"
	 }
      }
   }

   update_intcoorlist
}

proc ::Paratool::set_pickmode_conf {} {
   global vmd_pick_atom
   variable pickmode "conf"

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn

   # Set mouse mode to add/remove bonds
   mouse mode 0
   mouse mode 4 2; # "mouse mode 4 14" automatically adds bonds
   mouse callback on
   trace add variable vmd_pick_atom write ::Paratool::atom_picked_fctn
}

proc ::Paratool::set_pickmode_bond {} {
   global vmd_pick_atom
   variable pickmode "conf"

   if {$::Paratool::genvmdbond} { 
      .paratool_intcoor.frame2.type.addangle configure -state disabled
      .paratool_intcoor.frame2.type.adddihed configure -state disabled
   } else {
      .paratool_intcoor.frame2.type.addangle configure -state normal
      .paratool_intcoor.frame2.type.adddihed configure -state normal
   }
   .paratool_intcoor.frame2.type.addangle configure -state normal
   .paratool_intcoor.frame2.type.adddihed configure -state normal
#    .paratool_intcoor.frame2.type.adddihedall configure -state normal
}

proc ::Paratool::set_pickmode_angle {} {
   global vmd_pick_atom
   variable pickmode "conf"

   .paratool_intcoor.frame2.type.addangle configure -state disabled
   .paratool_intcoor.frame2.type.adddihed configure -state disabled
#    .paratool_intcoor.frame2.type.adddihedall configure -state disabled
}

proc ::Paratool::set_pickmode_dihed {} {
   global vmd_pick_atom
   variable pickmode "conf"

   .paratool_intcoor.frame2.type.addangle configure -state disabled
   .paratool_intcoor.frame2.type.adddihed configure -state disabled
#    .paratool_intcoor.frame2.type.adddihedall configure -state disabled
}

proc ::Paratool::set_pickmode_imprp {} {
   global vmd_pick_atom
   variable pickmode "conf"

   .paratool_intcoor.frame2.type.addangle configure -state disabled
   .paratool_intcoor.frame2.type.adddihed configure -state disabled
#    .paratool_intcoor.frame2.type.adddihedall configure -state disabled
}


proc ::Paratool::remove_bond {atom0 atom1} {
   variable zmat
   variable molidbase
   set ncoords [lindex [lindex $zmat 0] 1]
   set nbonds  [lindex [lindex $zmat 0] 2]

   set sel [atomselect $molidbase all]
   set bondatom0 [lindex [$sel getbonds] $atom0]
   if {[lsearch $bondatom0 $atom1]>=0} {
      puts "Bond existent, removing $atom0 $atom1."

      # Delete from VMD's bondlist
      ::util::delbond $molidbase $atom0 $atom1

      set count 0
      set newzmat {}
      foreach coord $zmat {
	 #puts "lsearch [lindex $coord 2] $atom0: [lsearch [lindex $coord 2] $atom0]"
	 #puts "lsearch [lindex $coord 2] $atom1: [lsearch [lindex $coord 2] $atom1]"
	 if {[lindex $coord 1]=="bond" &&
	     [lsearch [lindex $coord 2] $atom0]>=0 && 
	     [lsearch [lindex $coord 2] $atom1]>=0} {
	    incr ncoords -1
	    incr nbonds -1
	    incr count
	    lset newzmat {0 1} $ncoords
	    lset newzmat {0 2} $nbonds
	    continue
	 }
	 lappend newzmat $coord
      }

      variable removedependent
      if {$removedependent} {
	 # Remove all angles and dihedrals from zmat that contain the given bond:
	 set newzmat [del_dependent $newzmat $atom0 $atom1]
      }

      update_zmat $newzmat
      update_intcoorlabels 
      return $count
   }
   return 0
}


proc ::Paratool::register_bond {{indexlist {}}} {
   variable w
   variable zmat
   variable ncoords
   variable nbonds

   set atom0 [lindex $indexlist 0]
   set atom1 [lindex $indexlist 1]

   if {$atom0==$atom1} { return }

   if {[lsearch $zmat "*bond {$atom0 $atom1} *"]>=0 || [lsearch $zmat "*bond {$atom1 $atom0} *"]>=0} { 
      # Bond exists already
      return
   }

   variable molidbase
   vmd_addbond $atom0 $atom1 $molidbase

   variable genvmdbond
   if {$genvmdbond} { return }

   label add Bonds $molidbase/$atom0 $molidbase/$atom1
   set val [lindex [lindex [label list Bonds] end] 2]
   label delete Bonds all

   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat bond]
   set num [lindex $ret 0]

   set newzmat $zmat
   lappend newzmat [list R$num bond $indexlist $val {{} {}} {}]
   incr ncoords
   incr nbonds

   lset newzmat {0 1} $ncoords
   lset newzmat {0 2} $nbonds
   update_zmat [::QMtool::sort_zmat $newzmat]
   puts "Added [list R$num bond $indexlist $val {{} {}} {}]"

   # For manual use: the bond does not exist, because it was not picked, so add it:
   if {[llength $indexlist]} {   
      puts "Added bond $atom0 $atom1 to VMD's bondlist."
      vmd_addbond $atom0 $atom1 $molidbase
   }

   variable gendepangle
   if {$gendepangle} {
      # Add all angles containing the bond
      set newangles [::QMtool::angles_per_vmdbond $atom0 $atom1 $molidbase]
      foreach a $newangles {
	 register_angle $a noupdate
      }
   }

   variable gendepdihed
   variable gendepdihedmode
   if {$gendepdihed} {
      set newdihed {}
      if {$gendepdihedmode=="one"} {
	 # Add one dihed of torsion around the bond
	 set newdihed [::QMtool::diheds_per_vmdbond $atom0 $atom1 $molidbase "one"]
      } else {
	 # Add all diheds of torsion around the bond
	 set newdihed [::QMtool::diheds_per_vmdbond $atom0 $atom1 $molidbase "all"]
      }
      foreach a $newdihed {
	 register_dihed $a noupdate
      }
   }

   set pos [expr {[lsearch $zmat "* * {$atom0 $atom1} *"]-1}]
   if {[winfo exists .paratool_intcoor]} {
      .paratool_intcoor.zmat.pick.list selection clear 0 end
      .paratool_intcoor.zmat.pick.list selection set $pos
      .paratool_intcoor.zmat.pick.list see $pos
   }
   select_intcoor $pos

   variable ringlist [::util::find_rings $molidbase]
}

proc ::Paratool::register_angle { indexlist {update "update"} } {
   variable zmat
   variable ncoords
   variable nangles
   variable w
   variable molidbase
   set atom0 [lindex $indexlist 0]
   set atom1 [lindex $indexlist 1]
   set atom2 [lindex $indexlist 2]

   foreach conf $zmat {
      if {!([lindex $conf 1]=="angle" || [lindex $conf 1]=="lbend")} { continue }
      set angle [lindex $conf 2]
      set reverse [list [lindex $angle 2] [lindex $angle 1] [lindex $angle 0]]
      if {$indexlist==$angle || $indexlist==$reverse} {
	 puts "Angle {$indexlist} was defined already"
	 return
      }
   }

   label add Angles $molidbase/$atom0 $molidbase/$atom1 $molidbase/$atom2 
   set val [lindex [lindex [label list Angles] end] 3]
   label delete Angles all

   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat angle]
   set num    [lindex $ret 0]
   set tmpact [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list A$num angle $indexlist $val {{} {} {} {}} {}]
   incr ncoords
   incr nangles
   lset newzmat {0 1} $ncoords
   lset newzmat {0 3} $nangles
   update_zmat [::QMtool::sort_zmat $newzmat]
   puts "Added [list A$num angle $indexlist $val {{} {} {} {}} {}]"

   if {$update=="update"} { 
      set pos [expr {[lsearch $zmat "A$num *"]-1}]
      if {[winfo exists .paratool_intcoor]} {
	 .paratool_intcoor.zmat.pick.list selection clear 0 end
	 .paratool_intcoor.zmat.pick.list selection set $pos
	 .paratool_intcoor.zmat.pick.list see $pos
      }
      select_intcoor $pos
      variable ringlist [::util::find_rings $molidbase]
   }
}

proc ::Paratool::register_dihed { indexlist {update "update"} } {
   variable zmat
   set ncoords [lindex [lindex $zmat 0] 1]
   set ndiheds [lindex [lindex $zmat 0] 4]

   variable w
   variable molidbase
   set atom0 [lindex $indexlist 0]
   set atom1 [lindex $indexlist 1]
   set atom2 [lindex $indexlist 2]
   set atom3 [lindex $indexlist 3]

   foreach conf $zmat {
      if {[lindex $conf 1]!="dihed"} { continue }
      set dihed [lindex $conf 2]
      set reverse [list [lindex $dihed 3] [lindex $dihed 2] [lindex $dihed 1] [lindex $dihed 0]]
      if {$indexlist==$dihed || $indexlist==$reverse} {
	 puts "Dihed {$indexlist} was defined already"
	 return
      }
   }

   label add Dihedrals $molidbase/$atom0 $molidbase/$atom1 $molidbase/$atom2 $molidbase/$atom3
   set val [lindex [lindex [label list Dihedrals] end] 4]
   label delete Dihedrals all

   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat dihed]
   set num    [lindex $ret 0]
   set tmpact [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list D$num dihed $indexlist $val {} {}]
   incr ncoords
   incr ndiheds
   lset newzmat {0 1} $ncoords
   lset newzmat {0 4} $ndiheds
   update_zmat [::QMtool::sort_zmat $newzmat]
   puts "Added [list D$num dihed $indexlist $val {} {}]"

   if {$update=="update"} { 
      set pos [expr {[lsearch $zmat "D$num *"]-1}]
      if {[winfo exists .paratool_intcoor]} {
	 .paratool_intcoor.zmat.pick.list selection clear 0 end
	 .paratool_intcoor.zmat.pick.list selection set $pos
	 .paratool_intcoor.zmat.pick.list see $pos
      }
      select_intcoor $pos
      variable ringlist [::util::find_rings $molidbase]
   }
}

proc ::Paratool::register_imprp { indexlist {update "update"} } {
   variable zmat
   variable ncoords
   variable nimprops
   variable w
   variable molidbase
   set atom0 [lindex $indexlist 0]
   set atom1 [lindex $indexlist 1]
   set atom2 [lindex $indexlist 2]
   set atom3 [lindex $indexlist 3]

   foreach conf $zmat {
      if {[lindex $conf 1]!="imprp"} { continue }
      set dihed [lindex $conf 2]
      set reverse [list [lindex $dihed 3] [lindex $dihed 2] [lindex $dihed 1] [lindex $dihed 0]]
      if {$indexlist==$dihed || $indexlist==$reverse} {
	 puts "Improper {$indexlist} was defined already."
	 return
      }
   }

   label add Dihedrals $molidbase/$atom0 $molidbase/$atom1 $molidbase/$atom2 $molidbase/$atom3
   set val [lindex [lindex [label list Dihedrals] end] 4]
   label delete Dihedrals all

   set ret [find_new_coordinate_position $zmat imprp]
   set num    [lindex $ret 0]
   set tmpact [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list O$num imprp $indexlist $val {} {}]
   incr ncoords
   incr nimprops
   lset newzmat {0 1} $ncoords
   lset newzmat {0 5} $nimprops
   update_zmat [::QMtool::sort_zmat $newzmat]
   puts "Added [list O$num imprp $indexlist $val {} {}]"

   if {$update=="update"} { 
      set pos [expr {[lsearch $zmat "O$num *"]-1}]
      if {[winfo exists .paratool_intcoor]} {
	 .paratool_intcoor.zmat.pick.list selection clear 0 end
	 .paratool_intcoor.zmat.pick.list selection set $pos
	 .paratool_intcoor.zmat.pick.list see $pos
      }
      select_intcoor $pos
      variable ringlist [::util::find_rings $molidbase]
   }
}


proc ::Paratool::fc_label { conf } {

   if {![llength $conf]} {
      error "fc_label: Empty entry!"
   }

   if { [llength [lindex $conf 2]]==2 } {
      bond_label $conf
   } elseif { [llength [lindex $conf 2]]==3 } {
      angle_label $conf
   } elseif { [llength [lindex $conf 2]]==4 } {
      dihed_label $conf
   } else {
      error "fc_label: Bad zmat input format!"
   }
}


proc ::Paratool::bond_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels
   variable intcoormarktags
   variable labelsize
   variable molidbase

   set tag   [lindex $data 0]
   set type  [lindex $data 1]
   set index [lindex $data 2]
   set coord [format "%.3f" [lindex $data 3]]
   set fc    [join [lindex $data 4 0]]

   set sel1  [atomselect $molidbase "index [lindex $index 0]"]
   set sel2  [atomselect $molidbase "index [lindex $index 1]"]
   set pos1  [join [$sel1 get {x y z}]]
   set pos2  [join [$sel2 get {x y z}]]

   if {$type=="bond"} {
      graphics $molidbase color lime
   } elseif {$type=="dbond"} {
      graphics $molidbase color green
   } elseif {$type=="tbond"} {
      graphics $molidbase color red
   }
   variable labelscaling
   variable labelradius
   variable labelres
   set radius $labelradius

   if {$labelscaling && [llength $fc]==1} {
      set bigfc [expr {1500.0*0.2}]; # default labelradius=0.2
      set radius [expr {$fc/$bigfc*$labelradius}]
   }
   lappend intcoormarktags [graphics $molidbase cylinder $pos1 $pos2 radius $radius resolution $labelres]

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set name1 [join [$sel1 get type]]
      set name2 [join [$sel2 get type]]
      set atomnames [list $name1 $name2]
   
      set pos [vecadd $pos1 [vecscale [vecsub $pos2 $pos1] 0.5]]
      set labeltext " "
      for {set i 0} {$i<$radius/($labelsize*0.04)} {incr i} {
	 append labeltext " "
      }
      if {$intcoortaglabels}  {append labeltext " ${tag}"}
      if {$intcoornamelabels} {append labeltext " (${atomnames})"}
      if {$intcoorvallabels}  {append labeltext " $coord"}
      if {$intcoorfclabels}   {append labeltext " $fc"}
      lappend intcoormarktags [graphics $molidbase color white]
      lappend intcoormarktags [graphics $molidbase text $pos $labeltext size $labelsize]
   }

}

proc ::Paratool::angle_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels
   variable intcoormarktags
   variable molidbase

   set tag   [lindex $data 0]
   set index [lindex $data 2]
   set coord [format "%.2f" [lindex $data 3]]
   set fc    [lindex $data 4 0]

   set sel1 [atomselect $molidbase "index [lindex $index 0]"]
   set sel2 [atomselect $molidbase "index [lindex $index 1]"]
   set sel3 [atomselect $molidbase "index [lindex $index 2]"]
   set pos1 [join [$sel1 get {x y z}]]
   set pos2 [join [$sel2 get {x y z}]]
   set pos3 [join [$sel3 get {x y z}]]

   lappend intcoormarktags [graphics $molidbase color mauve]

   variable labelscaling
   variable labelradius
   variable labelres
   variable labeldist
   variable labelsize
   set radius $labelradius
   if {$labelscaling && [llength $fc]==1} {
      set bigfc [expr {120.0*0.2}]; # default labelradius=0.2
      set radius [expr {$fc/$bigfc*$labelradius}]
   }
   lappend intcoormarktags [graphics $molidbase cylinder $pos1 $pos2 radius $radius resolution $labelres]
   lappend intcoormarktags [graphics $molidbase cylinder $pos2 $pos3 radius $radius resolution $labelres]
   # XXX isn't the sphere alreay drawn by atomedit
   lappend intcoormarktags [graphics $molidbase sphere $pos2 radius $radius resolution $labelres]

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set name1 [join [$sel1 get type]]
      set name2 [join [$sel2 get type]]
      set name3 [join [$sel3 get type]]
      set atomnames [list $name1 $name2 $name3]

      set labeltext " "
      for {set i 0} {$i<$radius/($labelsize*0.04)} {incr i} {
	 append labeltext " "
      }
      if {$intcoortaglabels}  {append labeltext " ${tag}"}
      if {$intcoornamelabels} {append labeltext " (${atomnames})"}
      if {$intcoorvallabels}  {append labeltext " $coord"}
      if {$intcoorfclabels}   {append labeltext " $fc"}
      lappend intcoormarktags [graphics $molidbase color white]
      lappend intcoormarktags [graphics $molidbase text $pos2 $labeltext]
   }
}

proc ::Paratool::dihed_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels
   variable intcoormarktags
   variable molidbase

   set tag   [lindex $data 0]
   set type  [lindex $data 1]
   set index [lindex $data 2]
   set coord [format "%.2f" [lindex $data 3]]
   set fc    [lindex $data 4 0]

   set sel0 [atomselect $molidbase "index [lindex $index 0]"]
   set sel1 [atomselect $molidbase "index [lindex $index 1]"]
   set sel2 [atomselect $molidbase "index [lindex $index 2]"]
   set sel3 [atomselect $molidbase "index [lindex $index 3]"]
   set pos0 [join [$sel0 get {x y z}]]
   set pos1 [join [$sel1 get {x y z}]]
   set pos2 [join [$sel2 get {x y z}]]
   set pos3 [join [$sel3 get {x y z}]]

   if {$type=="dihed"} {
      lappend intcoormarktags [graphics $molidbase color purple]
   } elseif {$type=="imprp"} {
      lappend intcoormarktags [graphics $molidbase color iceblue]
   }

   variable labelscaling
   variable labelradius
   variable labelres
   set radius $labelradius
   if {$labelscaling && [llength $fc]==1} {
      set bigfc [expr {4.0*0.2}]; # default labelradius=0.2
      set radius [expr {$fc/$bigfc*$labelradius}]
   }
   lappend intcoormarktags [graphics $molidbase cylinder $pos0 $pos1 radius $radius resolution $labelres]
   lappend intcoormarktags [graphics $molidbase cylinder $pos1 $pos2 radius $radius resolution $labelres]
   lappend intcoormarktags [graphics $molidbase cylinder $pos2 $pos3 radius $radius resolution $labelres]
   lappend intcoormarktags [graphics $molidbase sphere $pos1 radius $radius resolution $labelres]
   lappend intcoormarktags [graphics $molidbase sphere $pos2 radius $radius resolution $labelres]

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set pos [vecadd $pos1 [vecscale [vecsub $pos2 $pos1] 0.5]]
      set name0 [join [$sel0 get type]]
      set name1 [join [$sel1 get type]]
      set name2 [join [$sel2 get type]]
      set name3 [join [$sel3 get type]]
      set atomnames [list $name0 $name1 $name2 $name3]

      variable labelsize
      set labeltext " "
      for {set i 0} {$i<$radius/($labelsize*0.04)} {incr i} {
	 append labeltext " "
      }
      if {$intcoortaglabels}  {append labeltext " ${tag}"}
      if {$intcoornamelabels} {append labeltext " (${atomnames})"}
      if {$intcoorvallabels}  {append labeltext " $coord"}
      if {$intcoorfclabels}   {append labeltext " $fc"}
      lappend intcoormarktags [graphics $molidbase color white]
      lappend intcoormarktags [graphics $molidbase text $pos $labeltext]
   }
}


#####################################################
# Delete internal coordinate.                       #
#####################################################

proc ::Paratool::del_coordinate {} {
   variable w
   variable zmat
   variable natoms
   variable ncoords
   variable nbonds
   variable nangles
   variable ndiheds
   variable nimprops
   variable picklist
   variable molidbase

   set sel $::Paratool::selintcoorlist;
   
   if {[llength $picklist]==2 && [lsearch $zmat "*bond {$picklist} *"]<0 && [lsearch $zmat "*bond {[lrevert $picklist]} *"]<0} {
      # Remove the bond from vmd's bondlist:
      ::util::delbond $molidbase [lindex $picklist 0] [lindex $picklist 1]
      update_intcoorlabels 
      return 0
   }


   set newzmat $zmat
   set index 0
   foreach conf $sel {
      set entry [lindex $zmat [expr {$conf+1}]]
      set type [lindex $entry 1]
      set atom0 [lindex [lindex $entry 2] 0]
      set atom1 [lindex [lindex $entry 2] 1]

      # Get the position of $entry in $newzmat
      set index [lsearch $newzmat $entry]

      # If $entry wasn't found, then the coordinate was previously deleted by del_dependent
      if {$index<0} { continue }

      if {[string match "*bond" $type]} {
	 incr nbonds -1
	 lset newzmat {0 2} $nbonds
	 # Remove the bond from vmd's bondlist:
	 ::util::delbond $molidbase $atom0 $atom1
      }
      switch $type {
	 angle { incr nangles -1;  lset newzmat {0 3} $nangles }
	 lbend { incr nangles -1;  lset newzmat {0 3} $nangles }
	 dihed { incr ndiheds -1;  lset newzmat {0 4} $ndiheds }
	 imprp { incr nimprops -1; lset newzmat {0 5} $nimprops }
      }      
      incr ncoords -1
      lset newzmat {0 1} $ncoords
      puts "Deleted [lindex $newzmat $index]"

      # Remove the conf from newzmat
      set newzmat [lreplace $newzmat $index $index]

      if {[string match "*bond" $type]} {
	 # Remove all angles and dihedrals that contain the given bond:
	 set newzmat [del_dependent $newzmat $atom0 $atom1]
      }
      if {$type=="angle" || $type=="lbend"} {
	 # Remove all dihedrals that contain the given bond:
	 set atom2 [lindex [lindex $entry 2] 2]	 
	 set newzmat [del_dependent $newzmat $atom0 $atom1 $atom2]
      }
   }

   update_zmat $newzmat
   set act 0
   if {$index>=[llength $newzmat]-1} {
      set act [expr {[llength $newzmat]-2}]
   } elseif {$index>0} {
      set act [expr {$index-1}]
   }

   if {[winfo exists .paratool_intcoor]} {
      .paratool_intcoor.zmat.pick.list selection clear 0 end
      .paratool_intcoor.zmat.pick.list selection set $act;
      .paratool_intcoor.zmat.pick.list see $act; 
   }
   variable selintcoorlist {}
   select_intcoor $act

   return 1
}


#####################################################
# Delete all angles and dihedrals that contain the  #
# given bond                                        #
# $newzmat must contain the zmatrix with the bond   #
# already removed. The angles and diheds will also  #
# be removed and the zmatrix is returned.           #
#####################################################

proc ::Paratool::del_dependent { newzmat atom0 atom1 {atom2 {}} } {
   variable removedependent
   set ncoords  [lindex [lindex $newzmat 0] 1]
   set nangles  [lindex [lindex $newzmat 0] 3]
   set ndiheds  [lindex [lindex $newzmat 0] 4]
   set nimprops [lindex [lindex $newzmat 0] 5]

   if {$removedependent} {
      set closebrace {\}}
      set confs {}
      if {[llength $atom2]} {
	 # Remove diheds that contain the bond
	 set confs [list [list $atom0 $atom1 $atom2]]
      } else {
	 # Remove angles and diheds that contain the bond
	 set entries {}
	 lappend entries [lsearch -all -regexp $newzmat "(angle|lbend)\\s+.+$atom0\\s$atom1\(\\s|$closebrace\)+"]
	 lappend entries [lsearch -all -regexp $newzmat "(angle|lbend)\\s+.+$atom1\\s$atom0\(\\s|$closebrace\)+"]
	 foreach entry [join $entries] {
	    lappend confs [lindex [lindex $newzmat $entry] 2]
	 }
	 # Remove imprps that contain the bond
	 set entries {}
	 lappend entries [lsearch -all -regexp $newzmat "imprp\\s+.+$atom0\\s\(\[0-9.\]+\\s\)*$atom1\(\\s|$closebrace\)+"]
	 lappend entries [lsearch -all -regexp $newzmat "imprp\\s+.+$atom1\\s\(\[0-9.\]+\\s\)*$atom0\(\\s|$closebrace\)+"]
	 foreach entry [join $entries] {
	    lappend confs [lindex [lindex $newzmat $entry] 2]
	 }
      }

      foreach a $confs {
	 # this finds angles AND dihedrals containing the atoms in order
	 set found [lsearch -all -regexp $newzmat "[string map {{ } {\s}} $a]\(\\s|$closebrace\)+"]

	 if {![llength $found]} {
	    # try the reverse atom order
	    set a [list [lindex $a 2] [lindex $a 1] [lindex $a 0]]
	    set found [lsearch -all -regexp $newzmat "[string map {{ } {\s}} $a]\(\\s|$closebrace\)+"]
	 }
	 if {![llength $found]} { continue }

	 # Loop through the found zmat entries and remove them
	 foreach i $found {
	    # We must do the search again, because $zmat changes
	    set j [lsearch -regexp $newzmat $a]
	    set type [lindex [lindex $newzmat $j] 1]

	    # if the angle was found, remove it:
	    puts "Deleted [lindex $newzmat $j]"
	    set newzmat [lreplace $newzmat $j $j]
	    if {$type=="angle" || $type=="lbend"} { incr nangles -1 }
	    if {$type=="dihed" } { incr ndiheds -1 }
	    if {$type=="imprp" } { incr nimprops -1 }
	    incr ncoords -1
	 }
      }
   }
   lset newzmat {0 1} $ncoords
   lset newzmat {0 3} $nangles
   lset newzmat {0 4} $ndiheds
   lset newzmat {0 5} $nimprops
   return $newzmat
}

#############################################################
# Gui to edit the parameters of the selected intcoor and    #
# it's equivalent ones.                                     #
#############################################################

proc ::Paratool::edit_selected_parameters_gui {} {
   variable selectcolor
   variable fixedfont
   # If already initialized, just turn on
   if { [winfo exists .paratool_editpar] } {
      set geom [winfo geometry .paratool_editpar]
      wm withdraw  .paratool_editpar
      wm deiconify .paratool_editpar
      wm geometry  .paratool_editpar $geom
      focus .paratool_editpar
      return
   }

   set v [toplevel ".paratool_editpar"]
   wm title $v "Edit parameters"
   wm resizable $v 0 1

   set labeltext "Conformations equivalent to selected one"
   labelframe $v.equiv -bd 2 -pady 2m -padx 2m -text $labeltext   

   frame $v.equiv.list
   label $v.equiv.format -textvariable ::Paratool::selparformat \
      -relief flat -bd 2 -justify left -font $fixedfont
   pack $v.equiv.format -anchor w
   
   scrollbar $v.equiv.list.scroll -command "$v.equiv.list.list yview"
   listbox $v.equiv.list.list -yscroll "$v.equiv.list.scroll set" -font $fixedfont \
      -width 80 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::selparamlist
   pack $v.equiv.list.list    -side left -fill both -expand 1
   pack $v.equiv.list.scroll  -side left -fill y    -expand 0
   pack $v.equiv.list -expand 1 -fill both
   
   labelframe $v.edit -text "Edit parameters" -bd 2 -pady 2m -padx 2m
   label $v.edit.format -font $fixedfont -textvariable ::Paratool::selpareditformat
   pack $v.edit.format -anchor w

   frame $v.edit.entries
   entry $v.edit.entries.p1 -width 10 -textvariable ::Paratool::selectedpar0
   entry $v.edit.entries.p2 -width 10 -textvariable ::Paratool::selectedpar1
   entry $v.edit.entries.p3 -width 10 -textvariable ::Paratool::selectedpar2
   entry $v.edit.entries.p4 -width 10 -textvariable ::Paratool::selectedpar3
   button $v.edit.entries.submit -text "Submit" -command ::Paratool::editparams_submit
   pack $v.edit.entries.p1 $v.edit.entries.p2 -side left
   pack $v.edit.entries.p3 $v.edit.entries.p4 $v.edit.entries.submit -side left
   pack $v.edit.entries -anchor w

   bind $v.edit.entries.p1 <Return> { ::Paratool::editparams_submit %W}
   bind $v.edit.entries.p2 <Return> { ::Paratool::editparams_submit %W}
   bind $v.edit.entries.p3 <Return> { ::Paratool::editparams_submit %W}
   bind $v.edit.entries.p4 <Return> { ::Paratool::editparams_submit %W}

   pack $v.equiv -expand 1 -fill both -padx 1m -pady 1m
   pack $v.edit -side top -fill x -ipadx 1m -ipady 1m -padx 1m -pady 1m

   update_selparamlist
   update_selectedpar
}


#############################################################
# Update the selected equivalent parameter list in the      #
# "Edit parameters" window.                                 #
#############################################################

proc ::Paratool::update_selparamlist {} {
   variable selintcoorlist
   if { ![winfo exists .paratool_editpar] || [llength $selintcoorlist]!=1} { return }

   variable selparamlist {}
   variable zmat
   variable formatintcoorlist
   set types [get_types_for_conf [lindex $zmat [expr {$selintcoorlist+1}] 2]]
   set zmattypelist [get_intcoor_typelist all]

   set equivalentlist [lsearch -all -regexp $zmattypelist "^($types|[lrevert $types])\$"]

   foreach equivalent $equivalentlist {
      set entry [lindex $zmat [expr {$equivalent+1}]]
      set types [get_types_for_conf [lindex $entry 2]]
      set k   [lindex $entry 4 0]
      set x0  [lindex $entry 4 1]
      set kub [lindex $entry 4 2]
      set s0  [lindex $entry 4 3]
      if {[llength $k]}   { set k   [format "%.4f" $k] }
      if {[llength $x0]}  { set x0  [format "%.4f" $x0] };  # also for dihed:n
      if {[llength $kub]} { set kub [format "%.4f" $kub] }; # also for dihed:delta
      if {[llength $s0]}  { set s0  [format "%.4f" $s0] }
      lappend selparamlist [format "%5s %21s %9.4f %9s %9s %9s %9s" [lindex $entry 0] $types \
			       [lindex $entry 3] $k $x0 $kub $s0]
   }
}


#############################################################
# Submit manual changes of selected parameters from the     #
# entries in the "Edit parameters" window.                  #
#############################################################

proc ::Paratool::editparams_submit { {win {}} } {
   variable zmat
   variable selparamlist
   variable selectedpar0
   variable selectedpar1
   variable selectedpar2
   variable selectedpar3

   foreach selparam $selparamlist {
      set izmat [lsearch $zmat "[lindex $selparam 0] *"]
      set type [lindex $zmat $izmat 1]
      set parlist {}
      if {[llength $selectedpar0]} {
	 if {[regexp "angle|lbend" $type]} {
	    lappend parlist $selectedpar0
	 } else {
	    lappend parlist $selectedpar0
	 }
      } else { lappend parlist {} }

      if {[llength $selectedpar1]} {
	 if {[string match $type "dihed"]} {
	    set oldn  [lindex $zmat $izmat 4 1]
	    set oldfc [lindex $zmat $izmat 4 0]
	    if {[llength $selectedpar0] && $selectedpar1!=$oldn} { 
	       set selectedpar0 [expr {$oldfc*$oldn*$oldn/double($selectedpar1*$selectedpar1)}]
	       lset parlist 0 $selectedpar0
	    }
	    lappend parlist [expr {int($selectedpar1)}]
	 } else {
	    lappend parlist $selectedpar1
	 }
      } else { lappend parlist {} }

      if {[llength $selectedpar2]} {
	 if {[string match $type "dihed"]} {
	    lappend parlist $selectedpar2
	 } else {
	    lappend parlist $selectedpar2
	 }
      } else { lappend parlist {} }

      if {[llength $selectedpar3]} {
	 lappend parlist $selectedpar3
      } else { lappend parlist {} }

      lset zmat $izmat 4 $parlist
      lset zmat $izmat 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $izmat 5] {}]M"
   }
   update_zmat

   ::Paratool::Refinement::parameter_error
   ::Paratool::Refinement::update_paramlist
}

#############################################################
# Update the parameter editing entries.                     #
#############################################################

proc ::Paratool::update_selectedpar {} {
   variable zmat
   variable selintcoorlist
   if {[llength $selintcoorlist]==1} {
      set parlist [lindex $zmat [expr {1+$selintcoorlist}] 4] 
      if {[llength $parlist]} {
	 foreach par $parlist i {0 1 2 3} {
	    if {[llength $par]} {
	       variable selectedpar$i [format "%.5f" $par]
	    } else {
	       variable selectedpar$i {}
	    }
	 }
      } else {
	 foreach i {0 1 2 3} {
	    variable selectedpar$i {}
	 }
      }
   } else {
      foreach i {0 1 2 3} {
	 variable selectedpar$i {}
      }
   }
   if {[winfo exists .paratool_editpar]} {
      if {[regexp {C} [lindex $zmat [expr {1+[lindex $selintcoorlist 0]}] 5]]} {
	 foreach i {1 2 3 4} {
	    .paratool_editpar.edit.entries.p$i    configure -state disabled
	    .paratool_editpar.edit.entries.submit configure -state disabled
	 }
      } else {
	 foreach i {1 2 3 4} {
	    .paratool_editpar.edit.entries.p$i    configure -state normal
	    .paratool_editpar.edit.entries.submit configure -state normal
	 }
      }
   }
}


proc ::Paratool::transform_hessian_cartesian_to_internal {args} {
   puts "Transform Hessian from cartesian to internal coordinates."
   if {[catch {package require hesstrans}]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Sorry, HessianTransform is not available on this platform.\nYou can transform the hessian into internal coordinates using Gaussian (see Menu->File)."
      return 0      
   }

   variable molidbase
   variable hessian
   variable zmat
   if {![llength $hessian] || [llength $zmat]<=1} { return }

   # Hesstrans returns a sorted zmat, thus we have to sort it before in order to be able 
   # to assign the force constants correctly
   update_zmat [::QMtool::sort_zmat $zmat]


   set bondlist {}
   set zmatbonds [lsearch -all -inline $zmat "*bond *"]
   foreach entry $zmatbonds {
      lappend bondlist [lindex $entry 2]
   }

   set anglelist {}
   set zmatangles [lsearch -all -inline -regexp $zmat ".+(angle|lbend)\\s"]
   foreach entry $zmatangles {
      lappend anglelist [lindex $entry 2]
   }

   set dihedlist {}
   set zmatdiheds [lsearch -all -inline $zmat "* dihed *"]
   foreach entry $zmatdiheds {
      lappend dihedlist [lindex $entry 2]
   }

   # Attention:
   # We add the impropers to the dihedral list since Gaussian doesn't distinguish them
   set imprplist {}
   set zmatimprps [lsearch -all -inline $zmat "* imprp *"]
   foreach entry $zmatimprps {
      lappend dihedlist [lindex $entry 2]
   }

   set sel [atomselect $molidbase all]
   set inthess [hesstrans [$sel get {x y z}] $hessian $bondlist $anglelist $dihedlist $imprplist]

   foreach row $inthess { puts $row }

   variable freqmethod
   variable inthessian_kcal [::QMtool::convert_inthessian_kcal $inthess $freqmethod $zmat]

   # If -getfc is specified we just return the force constants
   if {[lsearch $args "-getfc"]>=0} {
      # Extract the force constants from the main diagonal
      set i 0
      foreach row $inthessian_kcal {
	 lappend fclist [lindex $row $i]
	 incr i
      }
      
      # Assign new force constants to the internal coordinates in zmat 
      ::Paratool::Hessian::assign_fc_zmat $fclist
      ::Paratool::symmetrize_parameters -all zmatqm
      #::Paratool::assign_unknown_force_constants_from_zmatqm
      #::Paratool::update_zmat
      variable zmatqm
      foreach entry [lrange $zmatqm 1 end] {
	 lappend newfclist [lindex $entry 4 0]
      }
      return $newfclist
   }

  ::Paratool::Hessian::update_canvas

   return [::Paratool::Hessian::compute_force_constants_from_inthessian $args]
}


##################################################
# Use QM based parameters for selected atoms.    #
##################################################

proc ::Paratool::use_qm_parameters {} {
   variable zmat
   variable zmatqm
   variable selintcoorlist
   foreach i $selintcoorlist {
      set izmat [expr {$i+1}]
      set zmatentry [lindex $zmat $izmat]
      set pos [lsearch $zmatqm "* * {[lindex $zmatentry 2]} *"]
      if {$pos<1} { 
	 set pos [lsearch $zmatqm "* * {[lrevert [lindex $zmatentry 2]]} *"]
      }
      lset zmat $izmat 4 [lindex $zmatqm $pos 4]
      lset zmat $izmat 5 "[regsub -all {[QCRMA]} [lindex $zmatentry 5] {}]Q"      
   }
   update_zmat

   if {[winfo exists .paratool_refinement]} {
      # Update the refinement parameter error values
      ::Paratool::Refinement::parameter_error
      ::Paratool::Refinement::update_paramlist
   }
}


#########################################################
# Use force field based parameters for selected atoms.  #
#########################################################

proc ::Paratool::use_fofi_parameters {} {
   variable selintcoorlist
   set izmatlist {}
   foreach i $selintcoorlist {
      lappend izmatlist [expr {$i+1}]
   }
   assign_known_bonded_charmm_params $izmatlist

   # Update the refinement parameter error values
   if {[winfo exists .paratool_refinement]} {
      ::Paratool::Refinement::parameter_error
      ::Paratool::Refinement::update_paramlist
   }
}


############################################################
# Assign QM based force constants for unknown coordinates. #
# If charmmoverridesqm is set then assign known parameters #
# from CHARMM.                                             #
############################################################

proc ::Paratool::assign_unknown_force_constants_from_zmatqm {} {
   variable zmat
   variable zmatqm
   variable charmmoverridesqm
   set i 0
   foreach zmatentry $zmat {
      if {$i==0} { incr i; continue }
      
      # Search for the coordinate according to the indexes
      set pos [lsearch $zmatqm "* * {[lindex $zmatentry 2]} *"]
      if {$pos<1} { 
	 set pos [lsearch $zmatqm "* * {[lrevert [lindex $zmatentry 2]]} *"]
      }
      if {$pos<1} { 
	 #puts "No parameters found in Hessian for conformation {[lindex $zmatentry 2]}/{[lrevert [lindex $zmatentry 2]]}"
	 incr i; continue
      }
      
      # FIXME: Should impropers really be reverted?
      
      # Assign parameters from zmatqm
      if {(!$charmmoverridesqm) || ($charmmoverridesqm && ![llength [lindex $zmatentry 4 0]])} { 
	 lset zmat $i 4 [lindex $zmatqm $pos 4]
	 lset zmat $i 5 "[regsub -all {[QCRMA]} [lindex zmatentry 5] {}]Q"
      }
      incr i
   }
   if {$charmmoverridesqm} { 
      assign_known_bonded_charmm_params
   } else {
      update_zmat
   }

   # Update the refinement parameter error values
   if {[winfo exists .paratool_refinement]} {
      ::Paratool::Refinement::parameter_error
      ::Paratool::Refinement::update_paramlist
   }
}


############################################################
# Normally dihedrals should have a minimum at 0 degrees    #
# and the periodicity is set such the at the actual        #
# equilibrium angle we are also in a minimum, e.g. 120 deg #
# for n=3. This corresponds to a delta of 180 deg.         #
# Accordingly when delta=0 there's a potential maximum at  #
# 0 deg.                                                   #
# In case we have a really crooked molecule where          #
# periodicity and minima don't correspond we can set delta #
# to a different value than 180 deg, namely the exact      #
# equilibrium angle.                                       #
# This function switches between the two modes. In the     #
# exact dihedral delta mode the equilib. angle is used for #
# delta if the equilib energy would be higher than 5% of   #
# the barrier height.                                      #
############################################################

 proc ::Paratool::toggle_exact_dihedrals { } {
    variable exactdihedrals
    variable zmat
    set num -1
    foreach entry $zmat {
       # Skip header
       if {$num==-1} { incr num; continue }
       set fc [lindex $entry 4 0]
       set type [lindex $entry 1]
       if {[string match "dihed" $type]} {
	  set delta 180.0
	  set n [lindex $entry 4 1]
	  set dihed [lindex $entry 3]
	  set pot [expr {1+cos($n*$dihed/180.0*3.14159265)}]

	  if {$pot<1.0} { set delta 0.0 }
	  set pot [expr {1+cos(($n*$dihed-$delta)/180.0*3.14159265)}]

	  if {$exactdihedrals || $pot>0.1} { 
	     # If the equilib energy would be higher than 5% of the barrier height we choose the
	     # exact actual angle for delta.
	     # Since the minimum of cos(x) is at 180 deg we need to use an angle relative to 180.
	     set delta [expr {180.0+$dihed}]
	  }

	  lset zmat [expr {$num+1}] 4 [list $fc $n $delta]
       }
       # FIXME: This next line should go into the "if" above.
       lset zmat [expr {$num+1}] 5 "[regsub {[QCRMA]} [lindex $zmat [expr {$num+1}] 5] {}]Q"
       incr num
    }
    variable havefc 1
    variable havepar 1
    lset zmat 0 6 $havepar
    lset zmat 0 7 $havefc

    update_zmat
 }
