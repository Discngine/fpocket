#
# Internal coordinate editing routines
#
# $Id: qmtool_intcoor.tcl,v 1.16 2007/09/12 13:41:59 saam Exp $
#

#####################################################
# Add/Edit internal coordinate.                     #
#####################################################

proc ::QMtool::edit_internal_coords {} {
   variable w
   variable selectcolor
   # If already initialized, just turn on
   if { [winfo exists .qmtool_intcoor] } {
      wm deiconify .qmtool_intcoor
      focus .qmtool_intcoor
      return
   }

   set v [toplevel ".qmtool_intcoor"]
   wm title $v "Add/Edit internal coordinates"
   wm resizable $v 0 0

   # Left side of widget
   frame $v.l

   ############## frame for Z-matrix #################
   labelframe $v.l.zmat -bd 2  -relief ridge -text "Internal coordinates"
   
   frame $v.l.zmat.info
   label $v.l.zmat.info.natomslabel -text "Atoms: "
   label $v.l.zmat.info.natomsvar -textvariable ::QMtool::natoms
   grid $v.l.zmat.info.natomslabel -column 0 -row 0 -sticky e
   grid $v.l.zmat.info.natomsvar   -column 1 -row 0 -sticky e

   label $v.l.zmat.info.ncoordslabel -text "Coords: "
   label $v.l.zmat.info.ncoordsvar -textvariable ::QMtool::ncoords
   grid $v.l.zmat.info.ncoordslabel -row 1 -column 0 -sticky e
   grid $v.l.zmat.info.ncoordsvar   -row 1 -column 1 -sticky e

   label $v.l.zmat.info.nbondslabel -text "Bonds: "
   label $v.l.zmat.info.nbondsvar -textvariable ::QMtool::nbonds
   grid $v.l.zmat.info.nbondslabel -row 2 -column 0 -sticky e
   grid $v.l.zmat.info.nbondsvar   -row 2 -column 1 -sticky e

   label $v.l.zmat.info.nangleslabel -text "Angles: "
   label $v.l.zmat.info.nanglesvar -textvariable ::QMtool::nangles
   grid $v.l.zmat.info.nangleslabel -row 3 -column 0 -sticky e
   grid $v.l.zmat.info.nanglesvar   -row 3 -column 1 -sticky e

   label $v.l.zmat.info.ndihedslabel -text "Diheds: "
   label $v.l.zmat.info.ndihedsvar -textvariable ::QMtool::ndiheds
   grid $v.l.zmat.info.ndihedslabel -row 4 -column 0 -sticky e
   grid $v.l.zmat.info.ndihedsvar   -row 4 -column 1 -sticky e

   label $v.l.zmat.info.nimprpslabel -text "Impropers: "
   label $v.l.zmat.info.nimprpsvar -textvariable ::QMtool::nimprops
   grid $v.l.zmat.info.nimprpslabel -row 5 -column 0 -sticky e
   grid $v.l.zmat.info.nimprpsvar   -row 5 -column 1 -sticky e

   set labeltext "Pick a conformation using left mouse button"
   labelframe $v.l.zmat.pick -borderwidth 2 -pady 2m -padx 2m -relief ridge -text $labeltext   

   label $v.l.zmat.pick.format -text "Format: name type {indexes} length|angle k fixed"
   
   scrollbar $v.l.zmat.pick.scroll -command "$v.l.zmat.pick.list yview"
   listbox $v.l.zmat.pick.list -yscroll "$v.l.zmat.pick.scroll set" \
      -width 80 -height 18 -setgrid 1 -selectmode extended -selectbackground $selectcolor
   # we need a fixed font for proper formatting
   $v.l.zmat.pick.list configure -font {tkFixed 9}
   pack $v.l.zmat.pick.format
   pack $v.l.zmat.pick.list  $v.l.zmat.pick.scroll -side left -fill y -expand 1 

   frame $v.l.zmat.scaling
   label $v.l.zmat.scaling.textlabel -text "Label text size:"
   spinbox $v.l.zmat.scaling.textspin -from 0.05 -to 10 -increment 0.05 -width 5 \
      -textvariable ::QMtool::labelsize -command {::QMtool::update_intcoorlabels}
   grid $v.l.zmat.scaling.textlabel -column 0 -row 0 -sticky w
   grid $v.l.zmat.scaling.textspin  -column 1 -row 0 -sticky w

   label $v.l.zmat.scaling.tubelabel -text "Label radius scale factor:"
   spinbox $v.l.zmat.scaling.tubespin -from 0 -to 10 -increment 0.01 -width 5 \
      -textvariable ::QMtool::labelradius -command {::QMtool::update_intcoorlabels}
   grid $v.l.zmat.scaling.tubelabel -column 0 -row 1 -sticky w
   grid $v.l.zmat.scaling.tubespin  -column 1 -row 1 -sticky w

   checkbutton $v.l.zmat.scaling.check -text "Scale coordinate label thickness with force constant values" \
      -variable ::QMtool::labelscaling -command {::QMtool::update_intcoorlabels}
   grid $v.l.zmat.scaling.check -column 0 -row 2 -sticky w -columnspan 2

   variable havefc
   if {$havefc==0} {
      $v.l.zmat.scaling.check configure    -state disabled
      $v.l.zmat.scaling.tubespin configure -state disabled
   }

   # Pack the zmat frame
   pack $v.l.zmat.info $v.l.zmat.pick $v.l.zmat.scaling  -padx 2 -pady 2 -side top -expand yes -fill y

   # frame for Go/Quit buttons
   frame $v.l.goquit     
   button $v.l.goquit.close -text "Close" -command {
      set ::QMtool::pickmode none
      mouse mode 0';
      ::QMtool::remove_traces; 
      destroy .qmtool_intcoor
      ::QMtool::update_intcoorlabels
      focus .qmtool
   }
   pack $v.l.goquit.close -side left -anchor w -fill x -expand 1

   # Pack the left frame
   pack $v.l.zmat   -fill y -expand 1 -padx 1m -pady 1m 
   pack $v.l.goquit -fill x -expand 1 -padx 1m -pady 1m -side bottom -anchor s


   # Right half of the widget:
   frame $v.r
   variable addcoorddoctext
   labelframe $v.r.type -bd 2 -relief ridge -text "Add coordinate" 
   radiobutton $v.r.type.bond  -text bond -variable ::QMtool::addtype -value bond \
      -command ::QMtool::set_pickmode_bond
   checkbutton $v.r.type.addangle  -text "add all angles involving the bond" \
      -variable ::QMtool::gendepangle -padx 5m
   checkbutton $v.r.type.adddihed  -text "add dependent dihedrals" \
      -variable ::QMtool::gendepdihed -padx 5m -command {
	 if {$::QMtool::gendepdihed} { 
	    .qmtool_intcoor.r.type.adddihedone configure -state normal 
	    .qmtool_intcoor.r.type.adddihedall configure -state normal 
	 } else {
	    .qmtool_intcoor.r.type.adddihedone configure -state disabled
	    .qmtool_intcoor.r.type.adddihedall configure -state disabled
	 }
      }
   radiobutton $v.r.type.adddihedone  -text "add one dihedral per bond torsion" \
      -variable ::QMtool::gendepdihedmode -value "one" -padx 9m
   radiobutton $v.r.type.adddihedall  -text "add all dihedrals for the bond torsion" \
      -variable ::QMtool::gendepdihedmode -value "all" -padx 9m
   radiobutton $v.r.type.angle -text angle -variable ::QMtool::addtype -value angle \
      -command ::QMtool::set_pickmode_angle
   radiobutton $v.r.type.dihed -text dihed -variable ::QMtool::addtype -value dihed \
      -command ::QMtool::set_pickmode_dihed
   radiobutton $v.r.type.imprp -text improper -variable ::QMtool::addtype -value imprp \
      -command ::QMtool::set_pickmode_imprp
   label $v.r.type.doc -textvariable ::QMtool::addcoorddoctext -fg green3
   pack $v.r.type.bond $v.r.type.addangle $v.r.type.adddihed $v.r.type.adddihedone $v.r.type.adddihedall $v.r.type.angle \
      $v.r.type.dihed $v.r.type.imprp -anchor w
   pack $v.r.type.doc -anchor center

   labelframe $v.r.del -bd 2 -relief ridge -text "Delete"  -padx 2 -pady 2
   checkbutton $v.r.del.dep -text "Delete dependent coordinates, too" -variable {::QMtool::removedependent}
   button $v.r.del.sel -text "Delete selected coordinates" -command {::QMtool::del_coordinate}
   button $v.r.del.all -text "Delete all coordinates" -command {::QMtool::clear_zmat}
   pack $v.r.del.dep $v.r.del.sel $v.r.del.all

   labelframe $v.r.fix -bd 2 -relief ridge -text "Fix coordinates"  -padx 2 -pady 2
   button $v.r.fix.fixsel -text "Fix selected coordinates" -command {::QMtool::fix_coordinate fix}
   button $v.r.fix.unfixsel -text "Unfix selected coordinates" -command {::QMtool::fix_coordinate unfix}
   button $v.r.fix.fixall -text "Fix all coordinates" -command {::QMtool::fix_all fix}
   button $v.r.fix.unfixall -text "Unfix all coordinates" -command {::QMtool::fix_all unfix}
   pack $v.r.fix.fixsel $v.r.fix.unfixsel $v.r.fix.fixall $v.r.fix.unfixall

   labelframe $v.r.recalc -bd 2 -relief ridge -text "Distance dependent bond recalculation" -padx 2 -pady 2
   frame $v.r.recalc.labelspin
   label $v.r.recalc.labelspin.label -text "maximum bond length:"
   spinbox $v.r.recalc.labelspin.spinb -from 0 -to 10 -increment 0.05 -width 5 \
      -textvariable ::QMtool::maxbondlength
   pack $v.r.recalc.labelspin.label $v.r.recalc.labelspin.spinb -anchor w -side left -padx 1m 
   button $v.r.recalc.button -text "Recalculate bonds" -command {::QMtool::recalculate_bonds}
   pack $v.r.recalc.labelspin $v.r.recalc.button 

   labelframe $v.r.gen -bd 2 -relief ridge -text "Automatic coordinate generation"  -padx 2 -pady 2
   radiobutton $v.r.gen.one -text "Generate one dihedral per torsion" -value one \
      -variable {::QMtool::autogendiheds}
   radiobutton $v.r.gen.all -text "Generate all dihedrals per torsion" -value all \
      -variable {::QMtool::autogendiheds}
   button $v.r.gen.auto -text "Autogenerate internal coordinates" -command {::QMtool::autogenerate_zmat}
   pack $v.r.gen.one $v.r.gen.all $v.r.gen.auto

   pack $v.r.type $v.r.del $v.r.fix $v.r.recalc $v.r.gen -fill x -expand 1 -padx 1m -pady 1m


   # Pack everything
   pack $v.l $v.r -side left -fill y -expand 1 -padx 2 -pady 2


   # This will be executed when the mouse button is released in the picklist:   
   bind .qmtool_intcoor.l.zmat.pick.list <ButtonRelease> {
      set mousepos "%x,%y"
      set ::QMtool::act [expr [%W index @$mousepos]]
      if {[llength [%W curselection]]>1} {
	 set ::QMtool::seldelete 0
      }
      #::QMtool::update_coorselection
      ::QMtool::update_intcoorlabels
   }

   # This will be executed when items are selected:   
   bind $v.l.zmat.pick.list <<ListboxSelect>> {
      ::QMtool::update_intcoorlabels
   }

   # Set key bindings for scrolling
   bind $v <Key-Down> {
      ::QMtool::scroll down
   }

   bind $v <Key-Up> {
      ::QMtool::scroll up
   }

#    bind $v <Shift-Key-Down> {
#       ::QMtool::scroll sh-down
#    }

#    bind $v <Shift-Key-Up> {
#       ::QMtool::scroll sh-up
#    }

   bind $v <Control-Key-Down> {
      ::QMtool::scroll ctrl-down
   }

   bind $v <Control-Key-Up> {
      ::QMtool::scroll ctrl-up
   }

   bind $v <BackSpace> {
      ::QMtool::scroll delete
   }

   bind $v <Delete> {
      ::QMtool::del_coordinate
   }

   bind $v <Key-s> {
      ::QMtool::toggle_bondorder "single"
   }

   bind $v <Key-d> {
      ::QMtool::toggle_bondorder "double"
   }

   bind $v <Key-t> {
      ::QMtool::toggle_bondorder "triple"
   }

   # This will be executed when the focus changes to the window
   bind $v <FocusIn> {
      if {"%W"==".qmtool_intcoor"} {
	 switch $::QMtool::addtype {
	    bond  { ::QMtool::set_pickmode_bond }
	    angle { ::QMtool::set_pickmode_angle }
	    dihed { ::QMtool::set_pickmode_dihed }
	    imprp { ::QMtool::set_pickmode_imprp }
	 }

	 # Restore selection
	 foreach i $::QMtool::selintcoorlist {
	    .qmtool_intcoor.l.zmat.pick.list selection set $i
	 }

	 # Blank all item backgrounds
	 for {set i 0} {$i<[.qmtool_intcoor.l.zmat.pick.list index end]} {incr i} {
	    .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background {}
	 }
	 #puts "Focus on .qmtool_intcoor; %W"
	 ::QMtool::update_intcoorlabels
      }
   }

   # This will be executed when the focus leaves the window
   bind $v <FocusOut> {
      if {"%W"==".qmtool_intcoor"} {
	 # Remember current selection
	 set ::QMtool::selintcoorlist [.qmtool_intcoor.l.zmat.pick.list curselection]

	 # Set beckground color for selected items
	 foreach i [.qmtool_intcoor.l.zmat.pick.list curselection] {
	    .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background $::QMtool::selectcolor
	 }

	 ::QMtool::update_intcoorlabels
      }      
   }

   # Set bond mode as default
   set_pickmode_bond

   # Restore selection
   foreach i $::QMtool::selintcoorlist {
      .qmtool_intcoor.l.zmat.pick.list selection set $i
   }

   update_intcoorlist
}


########################################################
### Scroll selected item in listbox                  ###
########################################################

proc ::QMtool::scroll { direction } {
   variable act
   variable seldelete

   set cursel [.qmtool_intcoor.l.zmat.pick.list curselection]
   if {![llength $act]} { return }
   
   if {$direction=="up"} {
      if {$seldelete} {
	 .qmtool_intcoor.l.zmat.pick.list selection clear $act
      }
      set seldelete 1
      if { $act>0 } { incr act -1 }
      .qmtool_intcoor.l.zmat.pick.list selection anchor $act
      .qmtool_intcoor.l.zmat.pick.list selection set $act
   } elseif {$direction=="down"} {
      if {$seldelete} {
	 .qmtool_intcoor.l.zmat.pick.list selection clear $act
      }
      set seldelete 1
      if { $act<=[expr [.qmtool_intcoor.l.zmat.pick.list size]-2] } { incr act }
      .qmtool_intcoor.l.zmat.pick.list selection anchor $act
      .qmtool_intcoor.l.zmat.pick.list selection set $act
   } elseif {$direction=="sh-up"} {
      if { $act>0 } { incr act -1 }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set anchor $act
      set seldelete 0
   } elseif {$direction=="sh-down"} {
      if { $act<=[expr [.qmtool_intcoor.l.zmat.pick.list size]-2] } { incr act }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set anchor $act
      set seldelete 0
   } elseif {$direction=="ctrl-up"} {
      if {$seldelete} {
	 .qmtool_intcoor.l.zmat.pick.list selection clear $act
      }
      set seldelete 1
      if { $act>0 } { incr act -1 }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      foreach ele $cursel {
	 .qmtool_intcoor.l.zmat.pick.list selection set $ele
      }
      .qmtool_intcoor.l.zmat.pick.list selection set $act
   } elseif {$direction=="ctrl-down"} {
      if {$seldelete} {
	 .qmtool_intcoor.l.zmat.pick.list selection clear $act
      }
      set seldelete 1
      if { $act<=[expr [.qmtool_intcoor.l.zmat.pick.list size]-2] } { incr act }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      foreach ele $cursel {
	 .qmtool_intcoor.l.zmat.pick.list selection set $ele
      }
      .qmtool_intcoor.l.zmat.pick.list selection set $act
   } else {
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      #.qmtool_intcoor.l.zmat.pick.list selection set $act
   }
   .qmtool_intcoor.l.zmat.pick.list see $act

   update_intcoorlabels
}


proc ::QMtool::update_intcoorlist {} {
   variable zmat
   variable act 
   set intcoorlist {}

   if {![winfo exists .qmtool_intcoor.l.zmat.pick.list]} { return 1 }

   # These are the tags that appear in the listing:
   set num 0
   foreach t $zmat {
      if {$num>0} {
	 set type [lindex $t 1]
	 if {[string equal $type "angle"]} {
	    set x   [format_float "%.2f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.2f" [lindex $t 4 1]]
	    set kub [format_float "%.3f" [lindex $t 4 2]]
	    set s0  [format_float "%.4f" [lindex $t 4 3]]
	    set tag [format "%5s %5s %17s %7s %7s %7s %7s %7s %s" [lindex $t 0] [lindex $t 1] [list [lindex $t 2]] \
			 $x $k $x0 $kub $s0 [lindex $t 5]]
	 } elseif {[string equal $type "dihed"]} {
	    set x     [format_float "%.2f" [lindex $t 3]]
	    set k     [format_float "%.3f" [lindex $t 4 0]]
	    set delta [format_float "%.2f" [lindex $t 4 2]]
	    set tag [format "%5s %5s %17s %8s %8s %3s %8s %s" [lindex $t 0] [lindex $t 1] [list [lindex $t 2]] \
			$x $k [lindex $t 4 1] $delta [lindex $t 5]]
	 } elseif  {[string equal $type "imprp"]} {
	    set x   [format_float "%.2f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.2f" [lindex $t 4 1]]
	    set tag [format "%5s %5s %17s %8s %8s %8s %s" [lindex $t 0] [lindex $t 1] [list [lindex $t 2]] \
			$x $k $x0 [lindex $t 5]]
	 } else {
	    set x   [format_float "%.4f" [lindex $t 3]]
	    set k   [format_float "%.3f" [lindex $t 4 0]]
	    set x0  [format_float "%.4f" [lindex $t 4 1]]
	    set tag [format "%5s %5s %17s %8s %8s %8s %s" [lindex $t 0] [lindex $t 1] [list [lindex $t 2]] \
			$x $k $x0 [lindex $t 5]]
	 }
	 lappend intcoorlist "$tag"
      }
      incr num
   }

   if {[winfo exists .qmtool_intcoor.l.zmat.pick.list]} {
      .qmtool_intcoor.l.zmat.pick.list delete 0 end
      eval .qmtool_intcoor.l.zmat.pick.list insert 0 $intcoorlist
      .qmtool_intcoor.l.zmat.pick.list selection set $act
      .qmtool_intcoor.l.zmat.pick.list selection anchor $act
   }
   update_intcoorlabels
   return 1
}


#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::QMtool::fix_coordinate { mode } {
   variable numfixed 0
   variable zmat

   set sel [.qmtool_intcoor.l.zmat.pick.list curselection]

   foreach conf $sel {
       set index [expr $conf+1]
      set entry [lindex $zmat $index]
     
      if {$mode=="fix"} {
	 lset zmat $index 5 "F"
      } else {
	 lset zmat $index 5 {}
      }
      incr index
   }

   # count fixed atoms
   foreach entry $zmat {
      if {[lindex $entry 5]=="F"} { incr numfixed }
   }
   update_intcoorlist
}

#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::QMtool::fix_all { mode } {
   variable ncoords
   variable numfixed 0
   if {$mode=="fix"} {
      set numfixed $ncoords
   } 
   variable zmat

   set index 0
   foreach entry $zmat {
      if {$index==0} { incr index; continue }
      if {$mode=="fix"} {
	 lset zmat $index 5 "F"
      } else {
	 lset zmat $index 5 {}
      }
      incr index
   }
   update_intcoorlist
}

#####################################################
# Fix/unfix selected internal coordinates.          #
#####################################################

proc ::QMtool::toggle_bondorder { order } {
   variable zmat

   set sel [.qmtool_intcoor.l.zmat.pick.list curselection]
   set newzmat $zmat
   foreach conf $sel {
      set entry [lindex $zmat [expr $conf+1]]
      set type  [lindex $entry 1]
      if {[string match "*bond" $type]} {
	 if {$order=="single"} {
	    lset zmat [expr $conf+1] 1 "bond"
	 } elseif {$order=="double"} {
	    lset zmat [expr $conf+1] 1 "dbond"
	 } elseif {$order=="triple"} {
	    lset zmat [expr $conf+1] 1 "tbond"
	 }
      }
   }

   update_intcoorlist
}

proc ::QMtool::set_pickmode_bond {} {
puts "set_pickmode_bond"
   global vmd_pick_atom
   variable pickmode "conf"
   variable addcoorddoctext "-Pick two atoms-"
   variable picklist {}
   .qmtool_intcoor.r.type.addangle configure -state normal
   .qmtool_intcoor.r.type.adddihedone configure -state normal
   .qmtool_intcoor.r.type.adddihedall configure -state normal

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn

   # Set mouse mode to add/remove bonds
   mouse mode 0
   mouse mode 4 14
   mouse callback on
   trace add variable vmd_pick_atom write ::QMtool::atom_picked_fctn
}

proc ::QMtool::set_pickmode_angle {} {
   global vmd_pick_atom
   variable pickmode "conf"
   variable addcoorddoctext "-Pick tree atoms-"
   variable picklist {}

   .qmtool_intcoor.r.type.addangle configure -state disabled
   .qmtool_intcoor.r.type.adddihedone configure -state disabled
   .qmtool_intcoor.r.type.adddihedall configure -state disabled

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::QMtool::atom_picked_fctn
}

proc ::QMtool::set_pickmode_dihed {} {
   global vmd_pick_atom
   variable pickmode "conf"
   variable addcoorddoctext "-Pick four atoms-"
   variable picklist {}
   .qmtool_intcoor.r.type.addangle configure -state disabled
   .qmtool_intcoor.r.type.adddihedone configure -state disabled
   .qmtool_intcoor.r.type.adddihedall configure -state disabled

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::QMtool::atom_picked_fctn
}

proc ::QMtool::set_pickmode_imprp {} {
   global vmd_pick_atom
   variable pickmode "conf"
   variable addcoorddoctext "-Pick four atoms, central atom first-"
   variable picklist {}
   .qmtool_intcoor.r.type.addangle configure -state disabled
   .qmtool_intcoor.r.type.adddihedone configure -state disabled
   .qmtool_intcoor.r.type.adddihedall configure -state disabled

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::QMtool::atom_picked_fctn
}


proc ::QMtool::remove_bond {atom0 atom1} {
   variable zmat
   set ncoords [lindex [lindex $zmat 0] 1]
   set nbonds  [lindex [lindex $zmat 0] 2]

   set sel [atomselect top all]
   set bondatom0 [lindex [$sel getbonds] $atom0]
   if {[lsearch $bondatom0 $atom1]>=0} {
      puts "Bond existent, removing $atom0 $atom1."
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

      # Remove all angles and dihedrals that contain the given bond:
      set newzmat [del_dependent $newzmat $atom0 $atom1]

      update_zmat $newzmat
      update_intcoorlabels 
      return $count
   }
   return 0
}


proc ::QMtool::register_bond {{indexlist {}}} {
   variable w
   variable zmat
   variable picklist
   variable ncoords
   variable nbonds

   if {[llength $indexlist]} {
      set picklist $indexlist
   }

   set atom0 [lindex $picklist 0]
   set atom1 [lindex $picklist 1]

   if {$atom0==$atom1} { set picklist {}; return }

   set removed [remove_bond $atom0 $atom1]
   if {$removed>0} { 
      puts "Removed $removed bonds"
      set picklist {}
      return 
   }

   variable molid
   set val [measure bond $picklist molid $molid]


   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat bond]
   set num [lindex $ret 0]

   set newzmat $zmat
   lappend newzmat [list R$num bond $picklist $val {{} {}} {} {}]
   incr ncoords
   incr nbonds

   lset newzmat {0 1} $ncoords
   lset newzmat {0 2} $nbonds
   update_zmat [sort_zmat $newzmat]

   puts "Added [list R$num bond $picklist $val {{} {}} {} {}]"
   set picklist {}   

   # For manual use: the bond does not exist, because it was not picked, so add it:
   if {[llength $indexlist]} {   
      puts "Added bond $atom0 $atom1 to VMD's bondlist."
      ::util::addbond $molid $atom0 $atom1
   }

   variable gendepangle
   if {$gendepangle} {
      # Add all angles containing the bond
      set newangles [angles_per_vmdbond $atom0 $atom1 $molid]
      foreach a $newangles {
	 set picklist $a
	 register_angle noupdate
      }
   }

   variable gendepdihed
   variable gendepdihedmode
   if {$gendepdihed} {
      set newdihed {}
      if {$gendepdihedmode=="one"} {
	 # Add one dihed of torsion around the bond
	 set newdihed [diheds_per_vmdbond $atom0 $atom1 $molid "one"]
      } else {
	 # Add all diheds of torsion around the bond
	 set newdihed [diheds_per_vmdbond $atom0 $atom1 $molid "all"]
      }
      foreach a $newdihed {
	 set picklist $a
	 register_dihed noupdate
      }
   }
   set act [expr [lsearch $zmat "* * {$atom0 $atom1} *"]-1]
   set picklist {}   

   if {[winfo exists .qmtool_intcoor.l.zmat.pick.list]} { 
      # Blank all item backgrounds
      for {set i 0} {$i<[.qmtool_intcoor.l.zmat.pick.list index end]} {incr i} {
	 .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background {}
      }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set $act
      .qmtool_intcoor.l.zmat.pick.list see $act
      update_intcoorlabels 
   }
}

proc ::QMtool::register_angle { {update "update"} } {
   variable zmat
   variable picklist
   variable ncoords
   variable nangles
   variable act
   variable w

   foreach conf $zmat {
      if {!([lindex $conf 1]=="angle" || [lindex $conf 1]=="lbend")} { continue }
      set angle [lindex $conf 2]
      set reverse [list [lindex $angle 2] [lindex $angle 1] [lindex $angle 0]]
      if {$picklist==$angle || $picklist==$reverse} {
	 puts "Angle {$picklist} was defined already"
	 set picklist {}
	 return
      }
   }

   variable molid
   set val [measure angle $picklist molid $molid]

   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat angle]
   set num [lindex $ret 0]
   set act [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list A$num angle $picklist $val {{} {} {} {}} {} {}]
   incr ncoords
   incr nangles
   lset newzmat {0 1} $ncoords
   lset newzmat {0 3} $nangles
   update_zmat [sort_zmat $newzmat]
   puts "Added [list A$num angle $picklist $val {{} {} {} {}} {} {}]"
   set picklist {} 

   if {$update=="update"} { 
      # Blank all item backgrounds
      for {set i 0} {$i<[.qmtool_intcoor.l.zmat.pick.list index end]} {incr i} {
	 .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background {}
      }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set $act
      .qmtool_intcoor.l.zmat.pick.list see $act
      update_intcoorlabels
   }
}

proc ::QMtool::register_dihed { {update "update"} } {
   variable zmat
   variable picklist
   set ncoords [lindex [lindex $zmat 0] 1]
   set ndiheds [lindex [lindex $zmat 0] 4]
   variable act
   variable w

   foreach conf $zmat {
      if {[lindex $conf 1]!="dihed"} { continue }
      set dihed [lindex $conf 2]
      set reverse [list [lindex $dihed 3] [lindex $dihed 2] [lindex $dihed 1] [lindex $dihed 0]]
      if {$picklist==$dihed || $picklist==$reverse} {
	 puts "Dihed {$picklist} was defined already"
	 set picklist {}
	 return
      }
   }

   variable molid
   set val [measure dihed $picklist molid $molid]

   # Find a name for the coordinate
   set ret [find_new_coordinate_position $zmat dihed]
   set num [lindex $ret 0]
   set act [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list D$num dihed $picklist $val {{} {} {}} {} {}]
   incr ncoords
   incr ndiheds
   lset newzmat {0 1} $ncoords
   lset newzmat {0 4} $ndiheds
   update_zmat [sort_zmat $newzmat]
   puts "Added [list D$num dihed $picklist $val {{} {} {}} {} {}]"
   set picklist {} 

   if {$update=="update"} { 
      # Blank all item backgrounds
      for {set i 0} {$i<[.qmtool_intcoor.l.zmat.pick.list index end]} {incr i} {
	 .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background {}
      }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set $act
      .qmtool_intcoor.l.zmat.pick.list see $act
      update_intcoorlabels
   }
}

proc ::QMtool::register_imprp { {update "update"} } {
   variable zmat
   variable picklist
   variable ncoords
   variable nimprops
   variable act
   variable w

   foreach conf $zmat {
      if {[lindex $conf 1]!="imprp"} { continue }
      set dihed [lindex $conf 2]
      set reverse [list [lindex $dihed 3] [lindex $dihed 2] [lindex $dihed 1] [lindex $dihed 0]]
      if {$picklist==$dihed || $picklist==$reverse} {
	 puts "Improper {$picklist} was defined already."
	 set picklist {}
	 return
      }
   }

   variable molid
   set val [measure dihed $picklist molid $molid]

   set ret [find_new_coordinate_position $zmat imprp]
   set num [lindex $ret 0]
   set act [lindex $ret 1]
   set newzmat $zmat
   lappend newzmat [list O$num imprp $picklist $val {{} {}} {} {}]
   incr ncoords
   incr nimprops
   lset newzmat {0 1} $ncoords
   lset newzmat {0 5} $nimprops
   update_zmat [sort_zmat $newzmat]
   puts "Added [list O$num imprp $picklist $val {{} {}} {} {}]"
   set picklist {} 

   if {$update=="update"} { 
       # Blank all item backgrounds
      for {set i 0} {$i<[.qmtool_intcoor.l.zmat.pick.list index end]} {incr i} {
	 .qmtool_intcoor.l.zmat.pick.list itemconfigure $i -background {}
      }
      .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
      .qmtool_intcoor.l.zmat.pick.list selection set $act
      .qmtool_intcoor.l.zmat.pick.list see $act
      update_intcoorlabels
   }
}


proc ::QMtool::fc_label { conf } {
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


proc ::QMtool::bond_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels
   variable labelsize

   set tag   [lindex $data 0]
   set type  [lindex $data 1]
   set index [lindex $data 2]
   set coord [lindex $data 3]
   set fc    [lindex $data 4 1]
   
   set sel1  [atomselect top "index [lindex $index 0]"]
   set sel2  [atomselect top "index [lindex $index 1]"]
   set pos1  [join [$sel1 get {x y z}]]
   set pos2  [join [$sel2 get {x y z}]]

   if {$type=="bond"} {
      draw color orange
   } elseif {$type=="dbond"} {
      draw color red
   } elseif {$type=="tbond"} {
      draw color green
   }
   variable labelscaling
   variable labelradius
   set radius $labelradius
   if {$labelscaling && [llength $fc]==1} {
      set bigfc 300.0
      set radius [expr $fc/$bigfc*$labelradius]
   }
   draw cylinder $pos1 $pos2 radius $radius

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set name1 [join [$sel1 get name]]
      set name2 [join [$sel2 get name]]
      set atomnames [list $name1 $name2]
   
      #set dist [precn 2 [veclength [vecsub $pos2 $pos1]]]
      set pos [vecadd $pos1 [vecscale [vecsub $pos2 $pos1] 0.5]]
      set labeltext " "
      for {set i 0} {$i<$radius/($labelsize*0.04)} {incr i} {
	 append labeltext " "
      }
      if {$intcoortaglabels}  {append labeltext " ${tag}"}
      if {$intcoornamelabels} {append labeltext " (${atomnames})"}
      if {$intcoorvallabels}  {append labeltext " $coord"}
      if {$intcoorfclabels}   {append labeltext " $fc"}
      draw color white
      draw text $pos $labeltext size $labelsize
   }

}

proc ::QMtool::angle_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels

   set tag   [lindex $data 0]
   set index [lindex $data 2]
   set coord [lindex $data 3]
   set fc    [lindex $data 4 1]

   set sel1 [atomselect top "index [lindex $index 0]"]
   set sel2 [atomselect top "index [lindex $index 1]"]
   set sel3 [atomselect top "index [lindex $index 2]"]
   set pos1 [join [$sel1 get {x y z}]]
   set pos2 [join [$sel2 get {x y z}]]
   set pos3 [join [$sel3 get {x y z}]]

   draw color mauve

   variable labelscaling
   variable labelradius
   set radius $labelradius
   if {$labelscaling && [llength $fc]==1} {
      set bigfc 50.0
      set radius [expr $fc/$bigfc*$labelradius]
   }
   draw cylinder $pos1 $pos2 radius $radius
   draw cylinder $pos2 $pos3 radius $radius
   draw sphere $pos2 radius $radius

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set name1 [join [$sel1 get name]]
      set name2 [join [$sel2 get name]]
      set name3 [join [$sel3 get name]]
      set atomnames [list $name1 $name2 $name3]

      variable labelsize
      set labeltext " "
      for {set i 0} {$i<$radius/($labelsize*0.04)} {incr i} {
	 append labeltext " "
      }
      if {$intcoortaglabels}  {append labeltext " ${tag}"}
      if {$intcoornamelabels} {append labeltext " (${atomnames})"}
      if {$intcoorvallabels}  {append labeltext " $coord"}
      if {$intcoorfclabels}   {append labeltext " $fc"}
      draw color white
      draw text $pos2 $labeltext
   }
}

proc ::QMtool::dihed_label { data } {
   variable intcoortaglabels
   variable intcoornamelabels
   variable intcoorvallabels
   variable intcoorfclabels

   set tag   [lindex $data 0]
   set type  [lindex $data 1]
   set index [lindex $data 2]
   set coord [lindex $data 3]
   set fc    [lindex $data 4 0]

   set sel0 [atomselect top "index [lindex $index 0]"]
   set sel1 [atomselect top "index [lindex $index 1]"]
   set sel2 [atomselect top "index [lindex $index 2]"]
   set sel3 [atomselect top "index [lindex $index 3]"]
   set pos0 [join [$sel0 get {x y z}]]
   set pos1 [join [$sel1 get {x y z}]]
   set pos2 [join [$sel2 get {x y z}]]
   set pos3 [join [$sel3 get {x y z}]]

   if {$type=="dihed"} {
      draw color purple
   } elseif {$type=="imprp"} {
      draw color iceblue
   }

   variable labelscaling
   variable labelradius
   set radius $labelradius
   if {$labelscaling && [llength $fc]==1} {
      set bigfc 18.0
      set radius [expr $fc/$bigfc*$labelradius]
   }
   draw cylinder $pos0 $pos1 radius $radius
   draw cylinder $pos1 $pos2 radius $radius
   draw cylinder $pos2 $pos3 radius $radius
   draw sphere $pos1 radius $radius
   draw sphere $pos2 radius $radius

   if {$intcoortaglabels || $intcoornamelabels || $intcoorvallabels || $intcoorfclabels} {
      set pos [vecadd $pos1 [vecscale [vecsub $pos2 $pos1] 0.5]]
      set name0 [join [$sel0 get name]]
      set name1 [join [$sel1 get name]]
      set name2 [join [$sel2 get name]]
      set name3 [join [$sel3 get name]]
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
      draw color white
      draw text $pos $labeltext
   }
}


#####################################################
# Delete internal coordinate.                       #
#####################################################

proc ::QMtool::del_coordinate {} {
   variable w
   variable act
   variable zmat
   variable natoms
   variable ncoords
   variable nbonds
   variable nangles
   variable ndiheds
   variable nimprops

   set sel [.qmtool_intcoor.l.zmat.pick.list curselection]
   set newzmat $zmat
   set index 0
   foreach conf $sel {
      set entry [lindex $zmat [expr $conf+1]]
      set type [lindex $entry 1]
      set atom0 [lindex [lindex $entry 2] 0]
      set atom1 [lindex [lindex $entry 2] 1]

      # Get the position of $entry in $newzmat
      set index [lsearch $newzmat $entry]

      # If $entry wasn't found, then the coordinate was previously deleted by del_dependent
      if {$index<0} { continue }

      if {[string match "* bond" $type]} {
	 incr nbonds -1
	 lset newzmat {0 2} $nbonds
	 # Remove the bond from vmd's bondlist:
	 ::util::delbond top $atom0 $atom1
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
   if {$index>=[expr [llength $newzmat]-1]} {
      set act [expr [llength $newzmat]-2]
   } elseif {$index>0} {
      set act [expr $index-1]
   } else {
      set act 0
   }

   .qmtool_intcoor.l.zmat.pick.list selection clear 0 end
   .qmtool_intcoor.l.zmat.pick.list selection set $act
   .qmtool_intcoor.l.zmat.pick.list see $act
   update_intcoorlabels 
   return 1
}


#####################################################
# Delete all angles and dihedrals that contain the  #
# given bond                                        #
# $newzmat must contain the zmatrix with the bond   #
# already removed. The angles and diheds will also  #
# be removed and the zmatrix is returned.           #
#####################################################

proc ::QMtool::del_dependent { newzmat atom0 atom1 {atom2 {}} } {
   variable removedependent
   set ncoords  [lindex [lindex $newzmat 0] 1]
   set nangles  [lindex [lindex $newzmat 0] 3]
   set ndiheds  [lindex [lindex $newzmat 0] 4]
   set nimprops [lindex [lindex $newzmat 0] 5]

   if {$removedependent} {
      set angles {}
      if {[llength $atom2]} {
	 # Remove diheds that contain the bond
	 set angles [list [list $atom0 $atom1 $atom2]]
      } else {
	 # Remove angles that contain the bond
	 set entries {}
	 lappend entries [lsearch -all -regexp $newzmat "(angle|lbend)\\s+.+$atom0\\s$atom1"]
	 lappend entries [lsearch -all -regexp $newzmat "(angle|lbend)\\s+.+$atom1\\s$atom0"]
	 foreach entry [join $entries] {
	    lappend angles [lindex [lindex $newzmat $entry] 2]
	 }
      }

      foreach a $angles {
	 # this finds angles AND dihedrals containing the atoms in order
	 set found [lsearch -all -regexp $newzmat "[string map {{ } {\s}} $a]"]

	 if {![llength $found]} {
	    # try the reverse atom order
	    set a [list [lindex $a 2] [lindex $a 1] [lindex $a 0]]
	    set found [lsearch -all -regexp $newzmat "[string map {{ } {\s}} $a]"]
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

proc ::QMtool::update_intcoorlabels {} {

   # Don't do anything if the molecule doesn't exist or contains no frames
   if {[molinfo top]<0} { return 0 }
   if {[molinfo top get numframes]<0} { return 0 }

   variable zmat
   variable act 
   variable labelradius
   variable labelsize
   variable pickmode
   variable selintcoorlist
   variable intcoorlabeltags
   variable intcoormarktags

   # Clear everything
   draw delete all
   
   # Return if there are no internal coords
   if {[llength $zmat]==1} { return 1 }

   # Update the internal coordinate labels
   if {$pickmode=="conf"} {
      if {[winfo exists .qmtool_intcoor.l.zmat.pick.list]} {
	 set sel [.qmtool_intcoor.l.zmat.pick.list curselection]
	 if {![llength $sel]} { set sel $selintcoorlist }
	 
	 foreach conf $sel {
	    # Have to add +1 to the index because of the header entry
	    fc_label [lindex $zmat [expr $conf+1]]
	 }
	 
	 set actconf [lindex $zmat [expr $act+1]]
	 set indexes [lindex $actconf 2]
	 draw color lime
	 foreach ind $indexes {
	    set asel [atomselect top "index $ind"]
	    lappend intcoormarktags [draw sphere [join [$asel get {x y z}]] radius [expr $labelradius*1.1]]
	 }
      }	    
   }
}


#############################################################
# Returns a list of angles for the given bond.              #
#############################################################

proc ::QMtool::angles_per_vmdbond { atom0 atom1 molid } {
   set sel0 [atomselect $molid "index $atom0"]
   set sel1 [atomselect $molid "index $atom1"]
   set anglelist {}
   foreach neighbor0 [join [$sel0 getbonds]] {
      if {$neighbor0==$atom1} { continue }
      lappend anglelist [list $neighbor0 $atom0 $atom1]
   }
   foreach neighbor1 [join [$sel1 getbonds]] {
      if {$neighbor1==$atom0} { continue }
      lappend anglelist [list $neighbor1 $atom1 $atom0]
   }
   return $anglelist
}


#############################################################
# Returns a list of dihedrals for the given bond.           #
# Option "all": Return all possible dihedrals.              #
# Option "one": Return only one dihedral.                   #
#############################################################

proc ::QMtool::diheds_per_vmdbond { atom0 atom1 molid {complete "one"}} {
   set sel0 [atomselect $molid "index $atom0"]
   set sel1 [atomselect $molid "index $atom1"]
   set dihedlist {}
   foreach neighbor0 [join [$sel0 getbonds]] {
      if {$neighbor0==$atom1} { continue }
      foreach neighbor1 [join [$sel1 getbonds]] {
	 if {$neighbor1==$atom0} { continue }
	 if {$neighbor1==$neighbor0} { continue }
	 lappend dihedlist [list $neighbor0 $atom0 $atom1 $neighbor1]
	 if {$complete=="one"} { return $dihedlist }
      }
   }

   return $dihedlist
}
