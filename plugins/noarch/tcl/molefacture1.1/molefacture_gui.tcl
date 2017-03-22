#####################################################
# Add/Edit internal coordinate.                     #
#####################################################

proc ::Molefacture::molefacture_gui { {sel ""} } {
#puts "DEBUG A"
   variable atomlist 
   if {$sel == ""} {
     variable molidorig -1
   } elseif {[$sel num] == 0} {
      tk_messageBox -icon error -type ok -title Error \
      -message "You entered a selection containing no atoms. If you want to create a new molecule, invoke molefacture with no selection. Otherwise, please make a selection containing at least one atom."
      return
   } else {
     variable molidorig [$sel molid]
     set cursel  [atomselect $molidorig "index [$sel list]"]
     variable origsel [atomselect $molidorig "index [$sel list]"]
   }
   variable w
   variable selectcolor
   variable showvale
   variable showellp
   variable atomeditformtags
   variable atomlistformat
   variable taglist
   variable templist
   variable atomlistformat
   variable bondtaglist
   variable bondlistformat
   variable anglelistformat
   variable angletaglist
   set taglist "Index Name Type Elem Open  FormCharge OxState Charge"
   set templist [edit_update_list $taglist]
   set taglist [lindex $templist 0]
   set atomlistformat [lindex $templist 1]

   set bondtaglist "Atom1 Atom2 Order"
   set templist [edit_update_list $bondtaglist]
   set bondtaglist [lindex $templist 0]
   set bondlistformat [lindex $templist 1]

   set angletaglist "Atom1 Atom2 Atom3"
   set anglelistformat "%5i %5i %5i"



   #Put a trace on the display options
   trace add variable showvale write ::Molefacture::draw_openvalence_tr
   trace add variable showellp write ::Molefacture::draw_openvalence_tr

   if {$sel == ""} {
     new_mol
   } else { 
     reload_selection
   }

   mol selection      "occupancy > 0.4"
   mol representation "Bonds 0.1"
   mol color          Name
   mol modrep 0 top
   mol representation "VDW 0.1"
   mol addrep top
   display resetview
#puts "DEBUG C"
   variable bondlist [bondlist]
   variable anglelist [anglelist]

   variable atomaddlist {}
   if {$sel != ""} {
   foreach index [$sel list] {
#      lappend atomaddlist $index {}
   }
   }

   assign_elements

   init_oxidation

   update_openvalence

   set_pickmode_atomedit

   # If already initialized, just turn on
   if { [winfo exists .molefac] } {
      wm deiconify .molefac
      focus .molefac
      return
   }


   set w [toplevel ".molefac"]
   wm title $w "Molefacture - Molecule Builder"
   wm resizable $w 0 0

   #Add a menubar
   frame $w.menubar -relief raised -bd 2
   menubutton $w.menubar.file -text "File" -underline 0 \
   -menu $w.menubar.file.menu
   menubutton $w.menubar.build -text "Build" -underline 0 \
   -menu $w.menubar.build.menu
   menubutton $w.menubar.set -text "Settings" -underline 0 \
   -menu $w.menubar.set.menu
   menubutton $w.menubar.help -text "Help" -underline 0 \
   -menu $w.menubar.help.menu
   $w.menubar.file config -width 3 
   $w.menubar.build config -width 4 
   $w.menubar.set config -width 7 

   ## File menu
   menu $w.menubar.file.menu -tearoff no
   $w.menubar.file.menu add command -label "New" -command ::Molefacture::new_mol_gui
   $w.menubar.file.menu add command -label "Save" -command ::Molefacture::export_molecule_gui 
   $w.menubar.file.menu add command -label "Apply changes to parent" -command ::Molefacture::apply_changes_to_parent_mol
   $w.menubar.file.menu add command -label "Write top file" -command ::Molefacture::write_topology_gui
#   $w.menubar.file.menu add command -label "Undo unsaved changes" -command ::Molefacture::undo_changes
   $w.menubar.file.menu add command -label "Quit" -command ::Molefacture::done

   ## Build menu
   menu $w.menubar.build.menu -tearoff no
   $w.menubar.build.menu add command -label "Autotype/assign bonds" -command ::Molefacture::run_idatm
   $w.menubar.build.menu add command -label "Add all hydrogens" -command ::Molefacture::add_all_hydrogen
   menu $w.menubar.build.addfrag -title "Replace hydrogen with fragment" -tearoff no
   $w.menubar.build.addfrag add command -label "Add custom..." -command "::Molefacture::add_custom_frags"
   $w.menubar.build.addfrag add command -label "Reset menu" -command "::Molefacture::reset_frags_menu"
   $w.menubar.build.addfrag add separator
   read_fragment_file [file join $::env(MOLEFACTUREDIR) lib fragments frag.mdb]
   fill_fragment_menu
   menu $w.menubar.build.basefrag -tearoff no 
   $w.menubar.build.basefrag add command -label "Add custom..." -command "::Molefacture::add_custom_basefrags"
   $w.menubar.build.basefrag add command -label "Reset menu" -command "::Molefacture::reset_basefrags_menu"
   $w.menubar.build.basefrag add separator
   read_basefrag_file [file join $::env(MOLEFACTUREDIR) lib basemol basefrag.mdb]
   fill_basefrag_menu
   $w.menubar.build.menu add cascade -label "Replace hydrogen with fragment" -menu $w.menubar.build.addfrag
   $w.menubar.build.menu add cascade -label "New molecule from fragment" -menu $w.menubar.build.basefrag
   $w.menubar.build.menu add command -label "Protein Builder" -command ::Molefacture::protein_builder_gui

   ## Settings menu
   menu $w.menubar.set.menu -tearoff no
   $w.menubar.set.menu add checkbutton -label "Display valences" -variable [namespace current]::showvale
   $w.menubar.set.menu add checkbutton -label "Display electrons" -variable [namespace current]::showellp

   ## Help menu
   menu $w.menubar.help.menu -tearoff no
   $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About Molefacture" \
            -message "Molecule editing tool"}
   $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/molefacture"


   pack $w.menubar.file $w.menubar.build $w.menubar.set -side left 
   pack $w.menubar.help -side right
   grid $w.menubar -sticky ew -columnspan 2 -row 0 -column 0 -padx 0


   ############## frame for atom list and editing #################

   # Initialize atomlist formatting

#puts "Taglist: $taglist"
#puts "ALFormat: $atomlistformat"

   labelframe $w.val -bd 2 -relief ridge -text "Atoms" -padx 2 -pady 2
   label $w.val.label -wraplength 10c -justify left -text "-Pick atoms in VMD window or from the list.-"  -fg green3

   frame $w.val.list
   label $w.val.list.format -font {tkFixed 9} -textvariable ::Molefacture::taglist -relief flat -bd 2 -justify left;
#   label $w.val.list.format -font {tkFixed 9} -textvariable "test test" -relief flat -bd 2 -justify left;
   scrollbar $w.val.list.scroll -command "$w.val.list.list yview" -takefocus 0
   listbox $w.val.list.list -activestyle dotbox -yscroll "$w.val.list.scroll set" -font {tkFixed 9} \
      -width 60 -height 5 -setgrid 1 -selectmode extended -selectbackground $selectcolor -listvariable ::Molefacture::atomlist
   pack $w.val.list.format -side top -anchor w
   pack $w.val.list.list -side left -fill both -expand 1
   pack $w.val.list.scroll -side left -fill y
#   pack $w.val.list.list $w.val.list.scroll -side left -fill y -expand 1
#   pack $w.val.list.format -pady 2m 
   pack $w.val.label -pady 2m
   pack $w.val.list -padx 1m -pady 1m -fill y -expand 1

   #Editing tools
#   labelframe $w.atomedit -bd 2 -relief ridge -text "Edit Atoms" -padx 1m -pady 1m
   frame $w.val.f1
   button $w.val.f1.hyd    -text "Add hydrogen to selected atom" -command ::Molefacture::add_hydrogen_gui
   button $w.val.f1.del -text "Delete Selected Atom" -command ::Molefacture::del_atom_gui
   pack $w.val.f1.hyd $w.val.f1.del -side left -fill x -expand 1
   frame $w.val.f2
   button $w.val.f2.invert -text "Invert chirality" -command ::Molefacture::invert_gui
   button $w.val.f2.planar -text "Force planar" -command ::Molefacture::set_planar_gui
   button $w.val.f2.tetra -text "Force tetrahedral" -command ::Molefacture::set_tetra_gui
   frame $w.val.f3
   button $w.val.f3.raiseox -text "Raise oxidation state" -command ::Molefacture::raise_ox_gui
   button $w.val.f3.lowerox -text "Lower oxidation state" -command ::Molefacture::lower_ox_gui
   button $w.val.edit -text "Edit selected atom" -command ::Molefacture::edit_atom_gui
   pack $w.val.f2.invert $w.val.f2.planar $w.val.f2.tetra -side left -fill x -expand 1
   pack $w.val.f3.raiseox $w.val.f3.lowerox -side left -fill x -expand 1

   pack $w.val.f1  -side top -fill x
   pack $w.val.f2 -side top -fill x
   pack $w.val.f3 -side top -fill x
   pack $w.val.edit -side top -fill x


   ############## frame for bond list and editing #################
   labelframe $w.bonds -bd 2 -relief ridge -text "Bonds" -padx 1m -pady 1m
   frame $w.bonds.list
   label $w.bonds.list.format -font {tkFixed 9} -textvariable ::Molefacture::bondtaglist -relief flat -bd 2 -justify left;
   scrollbar $w.bonds.list.scroll -command "$w.bonds.list.list yview" -takefocus 0
   listbox $w.bonds.list.list -activestyle dotbox -yscroll "$w.bonds.list.scroll set" -font {tkFixed 9} \
      -width 20 -height 5 -setgrid 1 -selectmode browse -selectbackground $selectcolor -listvariable ::Molefacture::bondlist
   pack $w.bonds.list.format -side top -anchor w
   pack $w.bonds.list.list $w.bonds.list.scroll -side left -fill y -expand 1
   #labelframe $w.bondedit -bd 2 -relief ridge -text "Edit Bonds" -padx 1m -pady 1m
   frame $w.bonds.list.f1
   button $w.bonds.list.f1.raise -text "Raise bond order" -command ::Molefacture::raise_bondorder_gui
   button $w.bonds.list.f1.lower -text "Lower bond order" -command ::Molefacture::lower_bondorder_gui
   pack $w.bonds.list.f1.raise $w.bonds.list.f1.lower -side top
   pack $w.bonds.list.f1 -side left
   pack $w.bonds.list

   frame $w.bonds.f2
   ############## frame for distance spinbox #################
   frame $w.bonds.list.dist  -padx 2m -pady 2m
   label $w.bonds.list.dist.label -text "Adjust bond length:"
   spinbox $w.bonds.list.dist.spinb -from 0 -to 10 -increment 0.05 -width 5 \
      -textvariable ::Molefacture::bondlength -command {::Molefacture::adjust_bondlength}
   pack $w.bonds.list.dist.label $w.bonds.list.dist.spinb -anchor w -side top -padx 1m 
   pack $w.bonds.list.dist -side right


   ############## frame for dihedral scale #################
   frame $w.bonds.f2.angle  -padx 2m -pady 2m
   label $w.bonds.f2.angle.label -justify left -text "Rotate bond dihedral:"
   scale $w.bonds.f2.angle.scale -orient horizontal -length 284 -from -180 -to 180 \
      -command {::Molefacture::rotate_bond}  -tickinterval 60
   pack $w.bonds.f2.angle.label $w.bonds.f2.angle.scale -side left -expand yes -anchor w
   #$w.bonds.angle.scale set 0
   pack $w.bonds.f2.angle -side top
   pack $w.bonds.f2 -fill x

   bind $w.bonds.f2.angle.scale <ButtonRelease-1> {
      ::Molefacture::draw_openvalence      
   }

   frame $w.charge
   label $w.charge.label -text "Total charge: "
   label $w.charge.total -textvariable ::Molefacture::totalcharge
   pack  $w.charge.label  $w.charge.total -side left 


   ############## frame for angle list and editing #################
   labelframe $w.angles -bd 2 -relief ridge -text "Angles" -padx 1m -pady 1m
   frame $w.angles.list
   label $w.angles.list.format -font {tkFixed 9} -textvariable ::Molefacture::angletaglist -relief flat -bd 2 -justify left
   scrollbar $w.angles.list.scroll -command "$w.angles.list.list yview" -takefocus 0
   listbox $w.angles.list.list -activestyle dotbox -yscroll "$w.angles.list.scroll set" -font {tkFixed 9} \
      -width 20 -height 5 -setgrid 1 -selectmode browse -selectbackground $selectcolor -listvariable ::Molefacture::anglelist
   pack $w.angles.list.format -side top -anchor w
   pack $w.angles.list.list $w.angles.list.scroll -side left -fill y -expand 1
   pack $w.angles.list -side left
   ############## frame for angle scale #################
   frame $w.angles.realangle  -padx 1m -pady 1m
   label $w.angles.realangle.label -justify left -text "Adjust angle:"
   scale $w.angles.realangle.scale -orient horizontal -length 200 -from 0 -to 180 -command {::Molefacture::resize_angle}  -tickinterval 30

   frame $w.angles.realangle.chooser
   label $w.angles.realangle.chooser.label -justify left -text "Move: "
   radiobutton $w.angles.realangle.chooser.b1 -text "Group1" -width 6 -value "Atom1" -variable [namespace current]::anglemoveatom
   radiobutton $w.angles.realangle.chooser.b2 -text "Group2" -width 6 -value "Atom2" -variable [namespace current]::anglemoveatom
   radiobutton $w.angles.realangle.chooser.b3 -text "Both" -width 4 -value "Both" -variable [namespace current]::anglemoveatom
   pack $w.angles.realangle.chooser.label $w.angles.realangle.chooser.b1 $w.angles.realangle.chooser.b2 $w.angles.realangle.chooser.b3 -side left
   pack $w.angles.realangle.chooser -side bottom -expand yes -anchor s
   pack $w.angles.realangle.label $w.angles.realangle.scale -side left -expand yes -anchor w
   #$w.bonds.angle.scale set 0
   pack $w.angles.realangle -side top

   #Frame for building options
#   labelframe $w.builder -bd 2 -relief ridge -text "Build" -padx 1m -pady 1m
#   button $w.builder.allhyd -text "Add all hydrogens to molecule" -command ::Molefacture::add_all_hydrogen
#   pack $w.builder.allhyd -side left

   #Frame for saving options
#   labelframe $w.molecule -bd 2 -relief ridge -text "Molecule" -padx 1m -pady 1m
#   button $w.molecule.save -text "Save" -command ::Molefacture::export_molecule_gui
#   button $w.molecule.quit -text "Done" -command ::Molefacture::done
#   button $w.molecule.undo -text "Undo unsaved changes" -command ::Molefacture::undo_changes
#   pack $w.molecule.save -side left -anchor w
#   pack $w.molecule.quit -side left -anchor w -fill x -expand 1
#   pack $w.molecule.undo -side left

#   button $w.edit.fix -text "Apply changes" -command ::Molefacture::fix_changes

#   pack $w.val $w.bonds $w.angles $w.charge -padx 1m -pady 1m  
   grid $w.val -padx 1 -columnspan 1 -column 0 -row 1 -rowspan 2 -sticky ew
   grid $w.bonds -padx 1 -column 1 -row 1 -sticky ew
   grid $w.angles -padx 1 -column 1 -row 2 -sticky ew
   grid $w.charge -padx 1 -column 0 -columnspan 2 -row 3 -sticky ew

   # Enable manual editing of the spinbox entry value
   bind $w.bonds.list.dist.spinb <Return> {
      ::Molefacture::adjust_bondlength
   }

   # This will be executed when a bond is selected:   
   bind $w.bonds.list.list <<ListboxSelect>> [namespace code {
      focus %W
      # Blank all item backgrounds
      for {set i 0} {$i<[.molefac.bonds.list.list index end]} {incr i} {
	 .molefac.bonds.list.list itemconfigure $i -background {}
      }
      # Get current selection index
      set selbond [.molefac.bonds.list.list curselection]

      # Paint the background of the selected bond
      .molefac.bonds.list.list itemconfigure $selbond -background $::Molefacture::selectcolor
      .molefac.bonds.list.list activate $selbond

      # Get the selected bond
      set selindex [lrange [lindex $::Molefacture::bondlist $selbond] 0 1]

      # Select the corresponding atoms
      ::Molefacture::select_atoms_byvmdindex $selindex

      #puts "DEBUG 3"
      # Compute the bondlength
      variable tmpmolid
      if {![llength $tmpmolid]} { return }
      variable bondcoor
      variable dihedatom
      set dihedatom(1) [lindex $selindex 0]
      set dihedatom(2) [lindex $selindex 1]
      set sel1 [atomselect $tmpmolid "index $dihedatom(1)"]
      set sel2 [atomselect $tmpmolid "index $dihedatom(2)"]
      set bondcoor(1) [join [$sel1 get {x y z}]]
      set bondcoor(2) [join [$sel2 get {x y z}]]
      set ::Molefacture::bondlength [veclength [vecsub $bondcoor(2) $bondcoor(1)]]

      # Choose a dihedral for this bond
      set bonds1 [lsearch -all -inline -not [join [$sel1 getbonds]] $dihedatom(2)]
      set bonds2 [lsearch -all -inline -not [join [$sel2 getbonds]] $dihedatom(1)]
      set dihedatom(0) [lindex $bonds1 0]
      set dihedatom(3) [lindex $bonds2 0]
      # Delete the old marks
      variable dihedmarktags
      foreach tag $dihedmarktags {
	 graphics $tmpmolid delete $tag
      }

      if {[llength $dihedatom(0)] && [llength $dihedatom(3)]} {
	 #puts "dihedatom(0)=$dihedatom(0); [join [$sel1 getbonds]]; $bonds1"
	 #puts "dihedatom(1)=$dihedatom(1)"
	 #puts "dihedatom(2)=$dihedatom(2)"
	 #puts "dihedatom(3)=$dihedatom(3); [join [$sel2 getbonds]]; $bonds2"
	 set sel0 [atomselect $tmpmolid "index $dihedatom(0)"]
	 set bondcoor(0) [join [$sel0 get {x y z}]]
	 set sel3 [atomselect $tmpmolid "index $dihedatom(3)"]
	 set bondcoor(3) [join [$sel3 get {x y z}]]
	 lappend dihedmarktags [graphics $tmpmolid color yellow]
	 lappend dihedmarktags [graphics $tmpmolid sphere $bondcoor(0) radius 0.3]
	 lappend dihedmarktags [graphics $tmpmolid sphere $bondcoor(3) radius 0.3]

	 # Generate two selections for the two molecule halves
	 variable bondsel
	 set indexes1 [::Paratool::bondedsel $tmpmolid $dihedatom(1) $dihedatom(2) 50]
	 set indexes2 [::Paratool::bondedsel $tmpmolid $dihedatom(2) $dihedatom(1) 50]
   if {[havecommonelems $indexes1 $indexes2 [list $dihedatom(1) $dihedatom(2)]] > 0} {
     set indexes1 $dihedatom(1)
     set indexes2 $dihedatom(2)
   }
	 if {[array exists bondsel]} { $bondsel(1) delete; $bondsel(2) delete }
	 set bondsel(1) [atomselect $tmpmolid "index $indexes1 and not index $dihedatom(2)"]
	 set bondsel(2) [atomselect $tmpmolid "index $indexes2 and not index $dihedatom(1)"]
	 
	 # Compute the bond dihedral angle
	 label add Dihedrals $tmpmolid/$dihedatom(0) $tmpmolid/$dihedatom(1) $tmpmolid/$dihedatom(2) $tmpmolid/$dihedatom(3)
	 set ::Molefacture::dihedral [lindex [lindex [label list Dihedrals] end] 4]
	 label delete Dihedrals all
      }

      variable w
      $w.bonds.f2.angle.scale set $::Molefacture::dihedral
   }]

   # This will be executed when an angle is selected:   
   bind $w.angles.list.list <<ListboxSelect>> [namespace code {
      focus %W
      # Blank all item backgrounds
      for {set i 0} {$i<[.molefac.angles.list.list index end]} {incr i} {
	 .molefac.angles.list.list itemconfigure $i -background {}
      }
      # Get current selection index
      set selangle [.molefac.angles.list.list curselection]

      # Paint the background of the selected bond
      .molefac.angles.list.list itemconfigure $selangle -background $::Molefacture::selectcolor
      .molefac.angles.list.list activate $selangle

      # Get the selected bond
      set selindex [lrange [lindex $::Molefacture::anglelist $selangle] 0 2]

      # Select the corresponding atoms
      ::Molefacture::select_atoms_byvmdindex $selindex

      # Get information about this angle
      variable tmpmolid
      variable angle
      variable angleatom
      variable angleaxis
      variable anglesel
      variable anglepicklist
      variable anglemoveatom
      variable anglecoor
      variable dihedmarktags

      # Delete the dihedral marks
      foreach tag $::Molefacture::dihedmarktags {
	 graphics $::Molefacture::tmpmolid delete $tag
      }

      set angleatom(1) [lindex $selindex 0]
      set angleatom(2) [lindex $selindex 1]
      set angleatom(3) [lindex $selindex 2]

      set sel1 [atomselect $tmpmolid "index $angleatom(1)"]
      set sel2 [atomselect $tmpmolid "index $angleatom(2)"]
      set sel3 [atomselect $tmpmolid "index $angleatom(3)"]

      set coor2 [join [$sel2 get {x y z}]]
      set coor1 [join [$sel1 get {x y z}]]
      set coor3 [join [$sel3 get {x y z}]]

      set anglecoor(1) $coor1
      set anglecoor(2) $coor2
      set anglecoor(3) $coor3

#      puts "Subcoors: $coor1 $coor2 $coor3"
      set vec1 [vecsub $coor2 $coor1]
      set vec2 [vecsub $coor2 $coor3]

      set axis [veccross $vec1 $vec2]
#      puts "Doing norm of $axis"
      set angleaxis [vecscale [vecnorm $axis] 1.0]
#      puts "Done"

      # Generate two selections for the two molecule halves
      set indexes1 [::Paratool::bondedsel $tmpmolid $angleatom(1) $angleatom(2) 50]
      set indexes2 [::Paratool::bondedsel $tmpmolid $angleatom(3) $angleatom(2) 50]
      if {[havecommonelems $indexes1 $indexes2 [list $angleatom(1) $angleatom(2) $angleatom(3)]] > 0} {
        set indexes1 $angleatom(1)
        set indexes2 $angleatom(3)
      }
      if {[array exists anglesel]} { catch {$anglesel(1) delete}; catch {$anglesel(2) delete }}
      set anglesel(1) [atomselect $tmpmolid "index $indexes1 and not index $angleatom(2)"]
      set anglesel(2) [atomselect $tmpmolid "index $indexes2 and not index $angleatom(2)"]

      #Compute the angle
      label add Angles $tmpmolid/$angleatom(1) $tmpmolid/$angleatom(2) $tmpmolid/$angleatom(3)
      set angle [lindex [lindex [label list Angles] end] 3]
#      puts "Angle: $angle"
      label delete Angles all

      variable w
      $w.angles.realangle.scale set $::Molefacture::angle
   }]

   bind $w.angles.realangle.scale <ButtonRelease-1> {
      ::Molefacture::draw_openvalence      
   }

   # This will be executed when an atom is selected:   
   bind $w.val.list.list <<ListboxSelect>> {
      focus %W
      # ::Molefacture::set_pickmode_atomedit

      # Delete the dihedral marks
      foreach tag $::Molefacture::dihedmarktags {
	 graphics $::Molefacture::tmpmolid delete $tag
      }

      # Select the corresponding atoms
      ::Molefacture::select_atoms [.molefac.val.list.list curselection]
   }

   bind $w.bonds.list.list <Key-l> {
      ::Molefacture::lower_bondorder_gui
   }

   bind $w.bonds.list.list <Key-r> {
      ::Molefacture::raise_bondorder_gui
   }

   bind $w.val.list.list <Key-h> {
      ::Molefacture::add_hydrogen_gui
   }

   bind $w.val.list.list <Delete> {
      ::Molefacture::del_atom_gui
   }
#   puts "DEBUG B"

}

proc ::Molefacture::select_atoms_byvmdindex {indexlist} {
  #Helper proc that translates vmd indices into indices from .molefac.val.list.list
  variable atomlist
  set outputlist [list]
  set translist [list]
  foreach molefind $atomlist {
    lappend translist [lindex $molefind 0]
  }
#  puts "Translation indices $translist"

  foreach vmdind $indexlist {
#    puts "Looking for $vmdind in $translist"
    set i [lsearch -exact -integer $translist $vmdind]
    if {$i != -1} {lappend outputlist $i}
#    puts "Found $i"
  }

#  puts "found indices $outputlist"
  select_atoms $outputlist
}


####################################################################
# This function is used to select atoms.                           #
# It paints the background of the selected list items accordingly  #
# and appends the atomindexes to variable picklist in order to be  #
# independent of the window focus.                                 #
####################################################################

proc ::Molefacture::select_atoms { indexlist } {
#WARNING: The indices passed to this need to be the indices in .molefac.val.list.list
# DO NOT just send the atom indices. Bad things will happen.
   variable picklist {}
   if {![winfo exists .molefac.val.list.list]} { return }

   .molefac.val.list.list selection clear 0 end

   # Blank all item backgrounds
   for {set i 0} {$i<[.molefac.val.list.list index end]} {incr i} {
      .molefac.val.list.list itemconfigure $i -background {}
   }

   # Select the corresponding atoms
#   puts "DEBUG: Indexlist: $indexlist"
   add_atoms_to_selection $indexlist
}
 
proc ::Molefacture::add_atoms_to_selection { indexlist } {
   variable picklist
   variable atomlist
   variable selectcolor
   if {![llength $indexlist] || ![winfo exists .molefac.val.list.list]} { return }

#   puts "DEBUG: Indexlist: $indexlist"
   foreach index $indexlist {
#      set i [lsearch $atomlist "[format "%5s" $index] *"]
#      puts "DEBUG: found $i"
      .molefac.val.list.list selection set $index
      .molefac.val.list.list itemconfigure $index -background $selectcolor      
      set indexatomind [lindex [.molefac.val.list.list get $index] 0]
#      puts $indexatomind
      lappend picklist $indexatomind
   }

   draw_selatoms
   .molefac.val.list.list see $index
   .molefac.val.list.list activate $index
}


####################################################################
# This function can be used by external programs to select atoms.  #
####################################################################

proc ::Molefacture::user_select_atoms { atomdeflist } {
   variable tmpmolid

   # Select the corresponding atoms
   set indexlist {}
   foreach atomdef $atomdeflist {
      set sel [atomselect $tmpmolid "segid [lindex $atomdef 0] and resid [lindex $atomdef 1] and name [lindex $atomdef 2] "]
      lappend indexlist [join [$sel get index]]
      $sel delete
   }

   select_atoms $indexlist
}

proc ::Molefacture::raise_bondorder_gui { } {
   variable tmpmolid

   variable picklist; #[.molefac.val.list.list curselection]
   if {[llength $picklist]!=2} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "To modify the bond order, you should select exactly two atoms!"
      return
   } 

   raise_bondorder $picklist
}

proc ::Molefacture::lower_bondorder_gui { } {
   variable tmpmolid

   variable picklist; # [.molefac.val.list.list curselection]
   if {[llength $picklist]!=2} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "To modify the bond order, you should select exactly two atoms!"
      return
   } 
   lower_bondorder $picklist

}

proc ::Molefacture::invert_gui {} {
  variable tmpmolid

  variable picklist
  foreach mindex $picklist {
    invert_chir $mindex
  } 
  draw_openvalence
}

proc ::Molefacture::set_planar_gui { } {
  variable tmpmolid

  variable picklist;# [.molefac.val.list.list curselection]
  foreach mindex $picklist {
    set_planar $mindex
  }
  draw_openvalence
}


proc ::Molefacture::set_tetra_gui { } {
  variable tmpmolid

  variable picklist; # [.molefac.val.list.list curselection]
  foreach mindex $picklist {
    set_tetra $mindex
  }
}

proc ::Molefacture::del_atom_gui {} {
  variable picklist
  variable tmpmolid
  variable openvalencelist
  variable picklist
  set mother 0
  set curcoor {0 0 0}

  foreach delindex $picklist {
    set retlist [del_atom $delindex 0]
  }

  update_openvalence
  variable bondlist [bondlist]
  variable anglelist [anglelist]

  set mother [lindex $retlist 0]
  set curcoor [lindex $retlist 1]

   set cursel [atomselect $tmpmolid "occupancy > 0.4"]

   variable atomlist
   if {[lsearch $atomlist $mother]>=0} {
      select_atoms $mother
   } else {
      # Select the atom closest to the last deleted atom
      set sel [atomselect $tmpmolid "occupancy > 0.4"]
      set dist {}
      foreach coor [$sel get {x y z}] index [$sel get index] {
	 lappend dist [list $index [veclength [vecsub $coor $curcoor]]]
      }
      
      select_atoms [lindex [lsort -real -index 1 $dist] 0 0]
   }
   $cursel delete

}

proc ::Molefacture::add_hydrogen_gui {} {
  variable tmpmolid
  variable openvalencelist
#  variable atomaddlist
  variable picklist

  foreach mindex $picklist {
    add_hydrogen $mindex
  }
   select_atoms $picklist
}

proc ::Molefacture::export_molecule_gui {} {
   fix_changes
   variable tmpmolid
   set types {
           {{XBGF Files} {.xbgf} }
           {{PDB Files} {.pdb} }
           {{MOL2 Files} {.mol2} }
           }
   set filename [tk_getSaveFile -parent .molefac -filetypes $types -defaultextension ".pdb"]
   set sel [atomselect $tmpmolid "occupancy>=0.8"]
   if {[regexp {xbgf$} $filename] > 0 } {
     write_xbgf "$filename" $sel
   } elseif {[regexp {mol2$} $filename] > 0} {
     $sel writemol2 "$filename"
   } else {
     $sel writepdb "$filename"
   }

   variable projectsaved
   set projectsaved 1
}

proc ::Molefacture::edit_atom_gui {} {
  variable tmpmolid
  variable picklist
  variable periodic

  set tmpsel [atomselect $tmpmolid "index [lindex $picklist 0]"]
  variable editatom_name [$tmpsel get name]
  variable editatom_type [$tmpsel get type]
  variable editatom_element [$tmpsel get element]
  variable editatom_charge [$tmpsel get charge]
  variable editatom_index [$tmpsel get type]
  $tmpsel delete

  if {[llength $picklist] != 1} {
    tk_messageBox -icon error -type ok -title Message -message "You must select exactly one atom to edit"
    return
  }



  if {[winfo exists .atomeditor]} {
  wm deiconify .atomeditor
    raise .atomeditor
    return
  }

  set v [toplevel ".atomeditor"]
  wm title $v "Molefacture - Edit Atom"
  wm resizable $v 0 1

#  label $v.indexlabel -text "Index: "
#  label $v.index -textvariable "$editatom_index"
  frame $v.nametype
  label $v.nametype.namelabel -text "Name: "
  entry $v.nametype.name -textvariable [namespace current]::editatom_name
  label $v.nametype.typelabel -text "Type: "
  entry $v.nametype.type -textvariable [namespace current]::editatom_type
  pack $v.nametype.namelabel $v.nametype.name $v.nametype.typelabel $v.nametype.type -side left

  frame $v.charel
  label $v.charel.chargelabel -text "Charge: "
  entry $v.charel.charge -textvariable [namespace current]::editatom_charge
  label $v.charel.elementlabel -text "Element: "
  menubutton $v.charel.element -height 1 -relief raised -textvariable [namespace current]::editatom_element -menu $v.charel.element.menu
  menu $v.charel.element.menu -tearoff no
  pack $v.charel.chargelabel $v.charel.charge $v.charel.elementlabel $v.charel.element -side left

  frame $v.buttons
  button $v.buttons.finish -text "Done" -command [namespace current]::edit_atom 
  button $v.buttons.cancel -text "Cancel" -command "after idle destroy $v"
  pack $v.buttons.finish $v.buttons.cancel -side left

  #pack $v.indexlabel $v.index $v.namelabel $v.name $v.typelabel $v.type
#  pack $v.namelabel $v.name $v.typelabel $v.type
#  pack $v.chargelabel $v.charge $v.elementlabel $v.element
#  pack $v.finish $v.cancel
  pack $v.nametype $v.charel $v.buttons

  #Initialize the element menu
  foreach elementname $periodic {
    $v.charel.element.menu add radiobutton -variable [namespace current]::editatom_element -value $elementname -label $elementname
  }

}

#Procs to raise and lower oxidation state
proc ::Molefacture::raise_ox_gui {} {
  variable tmpmolid

  variable picklist;# [.molefac.val.list.list curselection]
  foreach mindex $picklist {
    raise_ox $mindex
  }
  update_openvalence
}

proc ::Molefacture::lower_ox_gui {} {
  variable tmpmolid

  variable picklist;# [.molefac.val.list.list curselection]
  foreach mindex $picklist {
    lower_ox $mindex
  }
  update_openvalence
}

proc ::Molefacture::fill_fragment_menu {} {
  # Looks through the current fragment database, and fills out the fragment menu
  # Each entry in the menu runs the replace hydrogen with fragment proc, using
  # the appropriate fragment
  # Currently clobbers all entries in the old menu, if any

  variable w
  variable addfrags

  foreach fragname [array names addfrags] {
    set fragfile $addfrags($fragname)
    $w.menubar.build.addfrag add command -label $fragname -command "::Molefacture::replace_hydrogen_with_fragment_gui {$fragfile}"
  }

}


proc ::Molefacture::replace_hydrogen_with_fragment_gui {fragpath} {
  # GUI dummy proc to find the atoms for replacement, and then replace them
  # with the appropriate fragment

  variable picklist
  foreach mindex $picklist {
    set returncode [replace_hydrogen_with_fragment $fragpath $mindex]
    if {$returncode == 1} {
      tk_messageBox -type ok -title "Error" -icon error -message "You can only replace singly bonded hydrogen atoms! The atom you picked doesn't meet one or both of these criteria"
    }
  }

}

proc ::Molefacture::add_custom_frags {} {
#First let them navigate to the file of interest
  variable w
  set fragfile [tk_getOpenFile]
  if {$fragfile == ""} {return}

  add_frag_file $fragfile
  $w.menubar.build.addfrag delete 3 end
  fill_fragment_menu
}

proc ::Molefacture::add_custom_basefrags {} {
#First let them navigate to the file of interest
  variable w
  set fragfile [tk_getOpenFile]
  if {$fragfile == ""} {return}

  add_basefrag_file $fragfile
  $w.menubar.build.basefrag delete 3 end
  fill_basefrag_menu
}

proc ::Molefacture::reset_basefrags_menu {} {
  variable w

  $w.menubar.build.basefrag delete 3 end
  read_basefrag_file [file join $::env(MOLEFACTUREDIR) lib basemol basefrag.mdb]
  fill_basefrag_menu
}

proc ::Molefacture::fill_basefrag_menu {} {
  # Looks through the current base fragment database, and fills out the fragment menu
  # Each entry in the menu creates a new molecule from 
  # the appropriate fragment
  # Currently clobbers all entries in the old menu, if any

  variable w
  variable basefrags

  #puts "deleting menu..."
  #menu $w.menubar.build.basefrag delete 3 end

#  puts [array names basefrags]
  foreach fragname [array names basefrags] {
    set fragfile $basefrags($fragname)
    $w.menubar.build.basefrag add command -label $fragname -command "::Molefacture::new_mol_from_fragment {$fragfile}"
  }

}

proc ::Molefacture::new_mol_gui {} {
  # Use whenever you want to start working on a blank molecule
  # Prompts the user to make sure they don't need to save anything, and then
  # opens up a blank molecule with some preallocated hydrogens
  # Return 0 if they say no at the prompt, 1 otherwise

  set answer [tk_messageBox -message "This will abandon all editing on the current molecule. Are you sure?" -type yesno -icon question]
  switch -- $answer {
    no return 0
    yes puts "Creating new molecule"
  }

  new_mol
  return 1
}

proc ::Molefacture::protein_builder_gui {} {

  variable phi
  variable psi
  variable aaseq

  if {[winfo exists .protbuilder]} {
    wm deiconify .protbuilder
    raise .protbuilder
    return
  }

  set w [toplevel ".protbuilder"]
  wm title $w "Molefacture Protein Builder"
  wm resizable $w no no

  #Frame for buttons for individual amino acids
  labelframe $w.aas -bd 2 -relief ridge -text "Add amino acids" -padx 1m -pady 1m
  frame $w.aas.buttons
  grid [button $w.aas.buttons.ala -text "ALA" -command {::Molefacture::add_aa ALA}] -row 0 -column 0 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.arg -text "ARG" -command {::Molefacture::add_aa ARG}] -row 0 -column 1 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.asn -text "ASN" -command {::Molefacture::add_aa ASN}] -row 0 -column 2 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.asp -text "ASP" -command {::Molefacture::add_aa ASP}] -row 0 -column 3 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.cys -text "CYS" -command {::Molefacture::add_aa CYS}] -row 0 -column 4 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.gln -text "GLN" -command {::Molefacture::add_aa GLN}] -row 0 -column 5 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.glu -text "GLU" -command {::Molefacture::add_aa GLU}] -row 0 -column 6 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.gly -text "GLY" -command {::Molefacture::add_aa GLY}] -row 0 -column 7 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.his -text "HIS" -command {::Molefacture::add_aa HIS}] -row 0 -column 8 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.ile -text "ILE" -command {::Molefacture::add_aa ILE}] -row 0 -column 9 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.leu -text "LEU" -command {::Molefacture::add_aa LEU}] -row 1 -column 0 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.lys -text "LYS" -command {::Molefacture::add_aa LYS}] -row 1 -column 1 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.met -text "MET" -command {::Molefacture::add_aa MET}] -row 1 -column 2 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.phe -text "PHE" -command {::Molefacture::add_aa PHE}] -row 1 -column 3 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.pro -text "PRO" -command {::Molefacture::add_proline}] -row 1 -column 4 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.ser -text "SER" -command {::Molefacture::add_aa SER}] -row 1 -column 5 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.thr -text "THR" -command {::Molefacture::add_aa THR}] -row 1 -column 6 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.trp -text "TRP" -command {::Molefacture::add_aa TRP}] -row 1 -column 7 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.tyr -text "TYR" -command {::Molefacture::add_aa TYR}] -row 1 -column 8 -columnspan 1 -sticky nsew
  grid [button $w.aas.buttons.val -text "VAL" -command {::Molefacture::add_aa VAL}] -row 1 -column 9 -columnspan 1 -sticky nsew

  pack $w.aas.buttons -side top
  pack $w.aas -side top

  # Alternative: build from a sequence
  frame $w.buildseq
  button $w.buildseq.set_parent_hyd -text "Set parent hydrogen" -command ::Molefacture::set_prot_parent
  label $w.buildseq.label -text "Add a sequence: "
  entry $w.buildseq.seq -textvar [namespace current]::aaseq
  button $w.buildseq.go -text "Build" -command {::Molefacture::build_textseq $::Molefacture::aaseq; set aaseq ""}

  pack $w.buildseq.set_parent_hyd -side left
  pack $w.buildseq.go -side right
  pack $w.buildseq.seq -side right 
  pack $w.buildseq.label -side right -fill x
  pack $w.buildseq -side top




  labelframe $w.ss -bd 2 -relief ridge -text "Phi/Psi Angles" -padx 1m -pady 1m
  frame $w.ss.row1
  frame $w.ss.row2
  label $w.ss.row1.philabel -text "Phi angle: "
  entry $w.ss.row1.phi -textvar [namespace current]::phi
  button $w.ss.row1.ahel -text "Alpha helix" -width 15 -command {::Molefacture::set_phipsi -57 -47}
  button $w.ss.row1.bs -text "Beta sheet" -width 15 -command {::Molefacture::set_phipsi -120 113}
  label $w.ss.row2.psilabel -text "Psi angle: "
  entry $w.ss.row2.psi -textvar [namespace current]::psi
  button $w.ss.row2.turn -text "Turn" -width 15 -command {::Molefacture::set_phipsi -60 30}
  button $w.ss.row2.straight -text "Straight" -width 15 -command {::Molefacture::set_phipsi -180 180}

  pack $w.ss.row1.philabel $w.ss.row1.phi $w.ss.row1.ahel $w.ss.row1.bs -side left
  pack $w.ss.row2.psilabel $w.ss.row2.psi $w.ss.row2.turn $w.ss.row2.straight -side left

  pack $w.ss.row1 $w.ss.row2 -side top
  pack $w.ss -side top

}

proc ::Molefacture::write_topology_gui {} {
   fix_changes

   variable tmpmolid
   set types {
           {{CHARMm topology file} {.top} }
           }
   set filename [tk_getSaveFile -parent .molefac -filetypes $types -defaultextension ".top"]

   write_topfile $filename "occupancy >= 0.5"
#   $sel delete
}

proc ::Molefacture::run_idatm {} {
  fix_changes
  variable tmpmolid

  set tmpsel [atomselect $tmpmolid "occupancy >= 0.8"]
  ::IDATM::runtyping $tmpsel
  $tmpsel delete
  update_openvalence
}
