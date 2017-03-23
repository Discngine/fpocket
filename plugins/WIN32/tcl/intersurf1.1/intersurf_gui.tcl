package provide intersurf 1.1

namespace eval ::NicoStuff:: {
    namespace export intersurf
    
    variable mol_A_id "0"	;   # molid of current molecule
    variable mol_B_id "1"	;   # molid of current molecule
    variable mol_selectionA "all" ; # selection for first molecule
    variable mol_selectionB "all" ; # selection for second molecule
    variable seltext all  ;         # selection text in entry box
    variable w 		;           # handle to window
    variable transparent  0 ;       # whether or not to generate a transparent surface
    variable dist_threshold  30
    variable surface_id = 0;        # enables to edit the rendering mode of the surface
    variable surfaces  {};          # list of surfaces {mol_id warped_surface_ptr}
    variable snap_mode = middle;
    variable smooth_surface = 1;
    variable auto_update = 1;
    variable show_delaunay = 0;
    variable color_func = ;
}

# puts $env(INTERSURFDIR)
source [file join $env(INTERSURFDIR) nicostuf.tcl]
source [file join $env(INTERSURFDIR) color_func.tcl]

set ::NicoStuff::snap_mode  middle
set ::NicoStuff::smooth_surface  1
set ::NicoStuff::show_delaunay 0
set ::NicoStuff::auto_update 1
set ::NicoStuff::color_func color_white 


proc ::NicoStuff::drop_stats {} {
    #set filename [tk_getSaveFile]
    set filename "nimp.txt" 
    if {$filename == "" } {return}
    set file_id  [open $filename w+]
    set surface_id  $::NicoStuff::surface_id
    set surface [::NicoStuff::currentSurface $::NicoStuff::surface_id ]
    if {$surface == "" } { 
	puts "no current surface to save"
	return
    }
     

    set interface_id [::NicoStuff::get_interface_id $surface_id] 
    set molA_id  [lindex [lindex $::NicoStuff::surfaces $interface_id]  2]
    set molB_id  [lindex [lindex $::NicoStuff::surfaces $interface_id]  3]

    puts "have to drop the file for [molinfo $molA_id get filename] and [molinfo $molB_id get filename] "
    puts "the file is formatted as follow :"
    puts "    *first molecule name"
    puts "    *number of atoms in this molecule participating to the interface"
    puts "    *list of the atoms participating to the interface"
    puts " SAME ITEMS FOR THE OTHER MOLECULE"
    puts " list of pair of atoms (can be usefull)"
#molA
    puts $file_id "[molinfo $molA_id get filename]"
    set vertices_list ""
    for {set vertex_id 0} {$vertex_id<[VMDSurface_size_of_vertices $surface]} {incr vertex_id} { 
	set vertex [VMDSurface_vertex $surface $vertex_id]
	set id [VMDAtom_id_get [VMDSurfaceVertex_A_get $vertex] ]
	if { [lsearch $vertices_list $id] == -1 }  {
	    lappend vertices_list $id
	}
    }
    puts $file_id [llength $vertices_list]
    puts $file_id $vertices_list

#molB
    puts $file_id "[molinfo $molB_id get filename]"
    set vertices_list ""
    for {set vertex_id 0} {$vertex_id<[VMDSurface_size_of_vertices $surface]} {incr vertex_id} { 
	set vertex [VMDSurface_vertex $surface $vertex_id]
	set id [VMDAtom_id_get [VMDSurfaceVertex_B_get $vertex] ]
	if { [lsearch $vertices_list $id] == -1 }  {
	    lappend vertices_list $id
	}
    }
    puts $file_id [llength $vertices_list]
    puts $file_id $vertices_list
    for {set vertex_id 0} {$vertex_id<[VMDSurface_size_of_vertices $surface]} {incr vertex_id} { 
	set vertex [VMDSurface_vertex $surface $vertex_id]
	puts $file_id "[VMDAtom_id_get [VMDSurfaceVertex_A_get $vertex] ]  [VMDAtom_id_get [VMDSurfaceVertex_B_get $vertex] ]"
    }
}

proc ::NicoStuff::load_surface_gui {} {
    set filename [tk_getOpenFile]
    if {$filename == "" } {return}    
    #automatiquely set the interface as current
    set ::NicoStuff::surface_id [load_surface $filename ]
    nicoUpdateMolecules
}

proc ::NicoStuff::save_gui {} {  
    puts "proc ::NicoStuff::save_gui "
    set filename [tk_getSaveFile]
    if {$filename == "" } {return}    
    set surface_id  $::NicoStuff::surface_id
    set surface [::NicoStuff::currentSurface $::NicoStuff::surface_id ]
    if {$surface == "" } { 
	puts "no current surface to save"
	return
    }

    set interface_id [::NicoStuff::get_interface_id $surface_id] 
    set molA_id  [lindex [lindex $::NicoStuff::surfaces $interface_id]  2]
    set molB_id  [lindex [lindex $::NicoStuff::surfaces $interface_id]  3]

    ::NicoStuff::save $surface $filename  $molA_id $molB_id 
	
}


proc ::NicoStuff::updateRenderingMode_gui {} {
    set surface_id  $::NicoStuff::surface_id
    # retreive the corresponding surface
    set surface [::NicoStuff::currentSurface $::NicoStuff::surface_id ]
    if {$surface == "" } {
	return
    }
    ::NicoStuff::updateRenderingMode $surface_id \
	$::NicoStuff::snap_mode $::NicoStuff::transparent
}

proc ::NicoStuff::rendering_mode_changed {arg1 arg2 op} {
    if { $::NicoStuff::auto_update == 1 } {
	::NicoStuff::updateRenderingMode_gui
    }
}



proc ::NicoStuff::createInterface_gui {} {
    variable mol_selectionA
    variable mol_selectionB
    variable transparent 

    set sel_A [atomselect $::NicoStuff::mol_A_id $mol_selectionA]
    set sel_B [atomselect $::NicoStuff::mol_B_id $mol_selectionB]

    set surface [::NicoStuff::createInterface $sel_A $sel_B] 
    
    ::NicoStuff::add_surface_molecule $surface $::NicoStuff::mol_A_id $::NicoStuff::mol_B_id 

    set ::NicoStuff::surface_id [molinfo top]
    nicoUpdateMolecules
}

proc ::NicoStuff::intersurf {} {
    global env
    global vmd_frame
    global vmd_initialize_structure
    variable selection
    variable w
    variable createbin "$env(INTERSURFDIR)/bin/createinterface"    


    # If already initialized, just turn on 
    if { [winfo exists .nico] } {
	wm deiconify $w
	return
    }

    # to be removed: i do not remenber how this env variable is supposed to\
	be set...


    set w [toplevel ".nico"]
    wm title $w "Intersurf"
    wm resizable $w 0 0
    bind $w <Destroy> [namespace current]::destroy

    # This is necessary to make nicostuff update itself when first opened to
    # make sure it's displaying current information.
    bind $w <Map> [namespace current]::nicoUpdate
    
    frame $w.top
    frame $w.data


    label  $w.data.txt1 -text "Rendering Options" -padx 4 -pady 8
    pack  $w.data.txt1 -side top -anchor w

    frame $w.data.snapMode
    radiobutton  $w.data.snapMode.snapA -text snapA \
	-variable {::NicoStuff::snap_mode} -value snapA -anchor w
    radiobutton  $w.data.snapMode.middle -text middle \
	-variable {::NicoStuff::snap_mode} -value middle -anchor w
    radiobutton  $w.data.snapMode.snapB -text snapB \
	-variable {::NicoStuff::snap_mode} -value snapB -anchor w


    set ::NicoStuff::snap_mode middle
    pack  $w.data.snapMode.snapA -side left
    pack  $w.data.snapMode.snapB -side right 
    pack  $w.data.snapMode.middle -side right
    pack  $w.data.snapMode -side top -anchor w

    checkbutton  $w.data.smooth_surface -text smooth_surface \
	      -variable ::NicoStuff::smooth_surface  
    pack  $w.data.smooth_surface  -side top -anchor w
 
    checkbutton  $w.data.show_delaunay -text show_delaunay \
	      -variable ::NicoStuff::show_delaunay  
    pack  $w.data.show_delaunay  -side top -anchor w
    


   # try to have a selection for coloring mode
    frame $w.data.color
    label $w.data.color.l -text "coloring method" -anchor w
    menubutton $w.data.color.m -relief raised -bd 2 -direction flush \
	-textvariable ::NicoStuff::color_func \
	-menu $w.data.color.m.menu
    menu $w.data.color.m.menu 

    $w.data.color.m configure -state normal 
    $w.data.color.m.menu add radiobutton -value "color_from_distance" \
	-label "color_from_distance" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_white" \
	-label "color_white" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_yellow" \
	-label "color_yellow" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_from_charge" \
	-label "color_from_charge" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_from_resnameA" \
	-label "color_from_resnameA" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_from_resnameB" \
	-label "color_from_resnameB" \
	-variable ::NicoStuff::color_func
    $w.data.color.m.menu add radiobutton -value "color_residue_interaction" \
	-label "color_residue_interaction" \
	-variable ::NicoStuff::color_func

    pack $w.data.color.l -side left
    pack $w.data.color.m -side right
    pack $w.data.color -side top -anchor w

    # try to have a selection of graphics object
    frame $w.data.surface
    label $w.data.surface.l -text "Change surface rendering mode" -anchor w
    menubutton $w.data.surface.m -relief raised -bd 2 -direction flush \
	-textvariable ::NicoStuff::surface_id \
	-menu $w.data.surface.m.menu
    menu $w.data.surface.m.menu
    #trace variable ::NicoStuff::surface w [namespace code nicoChangeSurface]

    pack $w.data.surface.l -side left
    pack $w.data.surface.m -side right
    pack $w.data.surface -side top -anchor w
    
    frame $w.data.dist_threshold
    label $w.data.dist_threshold.text -text "Distance Threshold"
    scale $w.data.dist_threshold.entry -width 20 -orient horizontal \
	-relief sunken -bd 2 -variable ::NicoStuff::dist_threshold
    pack $w.data.dist_threshold.text $w.data.dist_threshold.entry \
	-side left -anchor w
    pack $w.data.dist_threshold -anchor w
    

    frame $w.data.trans
    checkbutton $w.data.trans.check  -text "Transparent Surface" \
        -variable "::NicoStuff::transparent"
    pack $w.data.trans.check
    pack $w.data.trans -anchor w

    checkbutton  $w.data.auto_update -text auto_update \
	      -variable ::NicoStuff::auto_update  
    pack  $w.data.auto_update  -side top -anchor w

    button $w.data.bRenderMode -text "Update Rendering Mode" \
	-command  ::NicoStuff::updateRenderingMode_gui  -height 2 -width 25
    pack $w.data.bRenderMode -side top


    label  $w.data.txt2 -text "Create Surface" -padx 4 -pady 8
    pack  $w.data.txt2 -side top -anchor w

    # Create molecule selection menu for molecule_id A
    frame $w.data.mol_A
    label $w.data.mol_A.l -text "Molecule A id" -anchor w
    menubutton $w.data.mol_A.m -relief raised -bd 2 -direction flush \
	-textvariable ::NicoStuff::mol_A_id \
	-menu $w.data.mol_A.m.menu
    menu $w.data.mol_A.m.menu
    trace variable ::NicoStuff::mol_A_id w [namespace code nicoChangeMolecule]

    pack $w.data.mol_A.l -side left
    pack $w.data.mol_A.m -side right
    pack $w.data.mol_A -side top -anchor w

    frame $w.data.seltextA
    label $w.data.seltextA.text -text "Molecule A Selection:"
    entry $w.data.seltextA.entry -width 20 -relief sunken -bd 2 \
	-textvariable ::NicoStuff::mol_selectionA
    pack $w.data.seltextA.text $w.data.seltextA.entry -side left -anchor w
    pack $w.data.seltextA -anchor w


    # Create molecule selection menu for molecule_id B
    frame $w.data.mol_B
    label $w.data.mol_B.l -text "Molecule B id" -anchor w
    menubutton $w.data.mol_B.m -relief raised -bd 2 -direction flush \
	-textvariable ::NicoStuff::mol_B_id \
	-menu $w.data.mol_B.m.menu
    menu $w.data.mol_B.m.menu 
    trace variable ::NicoStuff::mol_B_id w [namespace code nicoChangeMolecule]

    pack $w.data.mol_B.l -side left
    pack $w.data.mol_B.m -side right
    pack $w.data.mol_B -side top -anchor w


    frame $w.data.seltextB
    label $w.data.seltextB.text -text "Molecule B Selection:"
    entry $w.data.seltextB.entry -width 20 -relief sunken -bd 2 \
	-textvariable ::NicoStuff::mol_selectionB
    pack $w.data.seltextB.text $w.data.seltextB.entry -side left -anchor w
    pack $w.data.seltextB -anchor w

    button $w.data.binterface -text "Extract interface surface" \
	-command  ::NicoStuff::createInterface_gui -height 2 -width 25
    pack $w.data.binterface  -side top

    pack $w.data -in $w.top -side right
    pack $w.top -anchor w


#   label  $w.txt3 -text "Load / Save  Surfaces" -padx 4 -pady 8
#   pack  $w.txt3 -side top

#    button $w.bLoad -text "Load surface" \
#	-command  ::NicoStuff::load_surface_gui
#    pack $w.bLoad  -side top

#    button $w.bSave -text "Save surface" \
#	-command  ::NicoStuff::save_gui
#    pack $w.bSave  -side top


#    button $w.bDropStatFile -text "DropStatFile" \
#	-command  ::NicoStuff::drop_stats
#    pack $w.bDropStatFile  -side top

    # Update the marks every time there's a new frame
    trace variable vmd_frame w [namespace code nicoUpdate]

    # Update the molecules when molecules are deleted or added
    trace variable vmd_initialize_structure w \
	[namespace code nicoUpdateMolecules]

    # trace all change in rendering_mode
    trace variable ::NicoStuff::color_func w ::NicoStuff::rendering_mode_changed
    trace variable ::NicoStuff::show_delaunay w ::NicoStuff::rendering_mode_changed 
    trace variable ::NicoStuff::smooth_surface w ::NicoStuff::rendering_mode_changed     
    trace variable ::NicoStuff::snap_mode  w ::NicoStuff::rendering_mode_changed 

    trace variable ::NicoStuff::transparent  w ::NicoStuff::rendering_mode_changed 



    # Set up the molecule list list
    nicoUpdateMolecules
}




proc ::NicoStuff::destroy { args } {
    # Delete traces
    # Delete remaining select
    variable selection
    variable mol_A_id
    variable mol_B_id
    global vmd_frame
    global vmd_initialize_structure
    
    trace vdelete mol_A_id w [namespace code nicoChangeMolecule]
    trace vdelete mol_B_id w [namespace code nicoChangeMolecule]
    trace vdelete vmd_frame w [namespace code nicoUpdate]
    trace vdelete vmd_initianicoUpdatelize_structure w \
	[namespace code nicoUpdateMolecules]
    #destroy all surfaces
    foreach surf $::NicoStuff::surfaces {
	delete_VMDSurface [lindex $surf 1]
    }
    catch {$selection delete}
}

proc ::NicoStuff::nicoUpdateMolecules { args } {
    variable selection
    variable w
    variable mol_A_id
    variable mol_B_id
    variable surface_id

    set mollist [molinfo list]
    # Invalidate the selection if necessary
    if { [lsearch $mollist $mol_A_id] < 0 } {
	catch {$selection delete}
	set selection ""
    }

    # Update the molecule browser
    $w.data.mol_A.m.menu delete 0 end
    $w.data.mol_A.m configure -state disabled

    $w.data.mol_B.m.menu delete 0 end
    $w.data.mol_B.m configure -state disabled

    $w.data.surface.m.menu delete 0 end
    $w.data.surface.m configure -state disabled

    if { [llength $mollist] != 0 } {
	foreach id $mollist { 
	    #TODO test if "type!=graphics" instead of "type==pdb"...
	    # but i can't set the "interface" type to my graphics molécule..
	    if {[molinfo $id get name] != "interface"} {
		$w.data.mol_A.m configure -state normal 
		$w.data.mol_A.m.menu add radiobutton -value $id \
		    -label "$id [molinfo $id get name]" \
		    -variable ::NicoStuff::mol_A_id 

		$w.data.mol_B.m configure -state normal 
		$w.data.mol_B.m.menu add radiobutton -value $id \
		    -label "$id [molinfo $id get name]" \
		    -variable ::NicoStuff::mol_B_id
	    } else {
		$w.data.surface.m configure -state normal 
		$w.data.surface.m.menu add radiobutton -value $id \
		    -label "$id [molinfo $id get name]" \
		    -variable ::NicoStuff::surface_id
	    }
	}
    }
}


proc ::NicoStuff::nicoChangeSurface { args } {
    variable selection
    variable seltext
    variable surface
    variable mol_B_id
    variable data
    variable w
    puts "What am i supposed to do ? nothing ? sounds good...."
    
    catch {unset data}
    nicoUpdate
}

proc ::NicoStuff::nicoChangeMolecule { args } {
    variable selection
    variable seltext
    variable mol_A_id
    variable mol_B_id
    variable data
    variable w

    if { $mol_A_id == "" || [lsearch [molinfo list] $mol_A_id] < 0} {
	return
    }
    if { $seltext == "" } {
	set seltext all
    }
    if {![catch {set sel [atomselect $mol_A_id "name CA and $seltext"]}]} {
	catch {$selection delete}
	set selection $sel
	$selection global
    } else {
	puts "Unable to create new selection!"
	return
    }
    catch {unset data}  
    nicoUpdate
}

proc ::NicoStuff::nicoUpdate { args } {
    variable w
    # Don't update if the window isn't turned on
    if { [string compare [wm state $w] normal] } {
	return
    }
}

proc intersurf_cb {} {
    ::NicoStuff::intersurf   ;# start the PDB Tool
    return $NicoStuff::w
}


