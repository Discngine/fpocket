catch { load  [file join $env(INTERSURFDIR) bin intersurf[info sharedlibextension]] intersurf}



proc ::NicoStuff::get_surface_from_mol_id {mol_id} {
    return [lindex [lindex $::NicoStuff::surfaces [::NicoStuff::get_interface_id $mol_id]] 1]
}


#retreive the position of mol "arg1" in ::NicoStuff::surfaces
proc ::NicoStuff::get_interface_id {surface_mol_id} {
    for {set surf_id 0} {$surf_id< [llength $::NicoStuff::surfaces]} {incr surf_id} {
	if {[lindex [lindex $::NicoStuff::surfaces $surf_id] 0]== $surface_mol_id} {
	    return $surf_id
	}
    } 
}


proc ::NicoStuff::mol_id_from_filename {filename} {
    set mollist [molinfo list]
    foreach id $mollist {
	if {[molinfo $id get filename] == $filename} { 
	    return $id
	}
    }
    return -1
}



proc ::NicoStuff::normalize_vector {p0} {
    if {[veclength2 $p0] == 0} {
	return {0 0 1}
    }
    return [vecnorm $p0]
}

proc ::NicoStuff::vector_diff {p0 p1} {
    return "[expr ([lindex $p1 0] - [lindex $p0 0])] \
            [expr ([lindex $p1 1] - [lindex $p0 1])] \
            [expr ([lindex $p1 2] - [lindex $p0 2])] "
}


proc ::NicoStuff::vector_bary {coeff p0 p1} {
    return "[expr $coeff * [lindex $p0 0] \
                      +(1-$coeff) *  [lindex $p1 0]] \
                     [expr $coeff * [lindex $p0 1] \
                      +(1-$coeff) *  [lindex $p1 1]] \
                      [expr $coeff * [lindex $p0 2] \
                      +(1-$coeff) *  [lindex $p1 2]] \
                     "
}

proc ::NicoStuff::vector_add {p0 p1} {
    return "[expr [lindex $p1 0] + [lindex $p0 0]]\
            [expr [lindex $p1 1] + [lindex $p0 1]]\
            [expr [lindex $p1 2] + [lindex $p0 2]]"
}



proc ::NicoStuff::estimate_triangle_normal {corners} {
    #puts "[vecdist [lindex $corners 0] [lindex $corners 1]]"
    set vA [::NicoStuff::vector_diff [lindex $corners 0] [lindex $corners 1]]
    set vB [::NicoStuff::vector_diff [lindex $corners 0] [lindex $corners 2]]
    set res [veccross $vA $vB]
    if {[veclength2 $res] == 0} {
	return {0 0 0}
    }   
    set res  [::NicoStuff::normalize_vector $res]
    return $res
}




proc ::NicoStuff::sendGeometry {mol surface molA_id molB_id} {
    set smooth $::NicoStuff::smooth_surface
    set color_func $::NicoStuff::color_func
    set show_delaunay $::NicoStuff::show_delaunay
    set snap_mode $::NicoStuff::snap_mode
    set transparent $::NicoStuff::transparent
    set ABcoeff 0.5 

    # Place the surface in the middle, snaped to molecule A or B ?
    if {$snap_mode == "middle" } {
	set ABcoeff 0.5 
    } else  {
	if {$snap_mode == "snapA" } {
	    set ABcoeff 0.1
	} else {
	    set ABcoeff 0.9
	}
    }
    # Set the graphics state
    graphics $mol  materials on
    if { $transparent } {
	graphics $mol material Transparent
    } else {
	graphics $mol material Opaque
    }

    #     #retreive molecules ids 
    #     set surf_id [::NicoStuff::get_interface_id $mol]
    #     set molA_id [lindex [lindex $::NicoStuff::surfaces $surf_id] 2]
    #     set molB_id [lindex [lindex $::NicoStuff::surfaces $surf_id] 3]


    # get all info we need from the atoms
    set selA [atomselect $molA_id  all]
    set selB [atomselect $molB_id  all]

    set arrayA [$selA get {x y z}]
    set arrayB [$selB get {x y z}]

    $selA delete
    $selB delete
    
    
    # list of nearer triangles of each vertex 
    set vertex_neighbourgs_triangles {}
    
    # list of the barycenter of each triangle
    set middle_of_triangle_pos {}
    # list of the normal of each triangle
    set triangle_normal {}

    # position, normal and color of each vertex
    set vertices_pos {}
    set vertices_normal {}
    set vertices_color {}



    # set the size of  vertex_neighbourgs_triangles,
    # then computes the barycenter of each triangle
    for {set vertex_id 0} {$vertex_id<[VMDSurface_size_of_vertices $surface]} {incr vertex_id} {
	lappend vertex_neighbourgs_triangles {}
    }    
    for {set x 0} {$x<[VMDSurface_size_of_triangles $surface]} {incr x} {
 	set triangle [VMDSurface_triangle $surface $x]
	set bary "0 0 0"
	set triangles_corners_pos {}
 	for {set i 0} {$i<3} {incr i} {
	    set vertex_id [VMDSurfaceTriangle_vertex $triangle $i]
	    
	    set tmp_list [lindex $vertex_neighbourgs_triangles $vertex_id ]
	    lappend tmp_list $x
	    lset vertex_neighbourgs_triangles $vertex_id $tmp_list
	    
	    set vertex [VMDSurface_vertex $surface $vertex_id]
	    set atomA [VMDSurfaceVertex_A_get $vertex]
	    set atomB [VMDSurfaceVertex_B_get $vertex]
	    set index_A [VMDAtom_id_get $atomA]
	    set index_B [VMDAtom_id_get $atomB]
	    set data_A [lindex $arrayA $index_A]
	    set data_B [lindex $arrayB $index_B]


	    set pos [::NicoStuff::vector_bary $ABcoeff $data_A $data_B]

	    lappend triangles_corners_pos $pos 
	    set bary "[expr [lindex $pos 0] \
                      +  [lindex $bary 0]] \
                     [expr [lindex $pos 1] \
                      +  [lindex $bary 1]] \
                      [expr [lindex $pos 2] \
                      +  [lindex $bary 2]] \
                     " 
	    unset data_A
	    unset data_B
 	}
	
	lappend triangle_normal [::NicoStuff::estimate_triangle_normal $triangles_corners_pos]  

	set bary "[expr [lindex $bary 0]/3.0] \
                  [expr [lindex $bary 1]/3.0] \
                  [expr [lindex $bary 2]/3.0]" 
	lappend  middle_of_triangle_pos $bary
	unset bary
    }

    
    # set the vertices positions
    for {set vertex_id 0} {$vertex_id<[VMDSurface_size_of_vertices $surface]} {incr vertex_id} {
	# just make twice the dual with barycenter repositioning to smooth
	set triangle_list [lindex $vertex_neighbourgs_triangles $vertex_id]
	set nb_neighbourgs 0.0
	set bary "0 0 0"
	set normal "0 0 0"
	#puts $triangle_list
	foreach tr $triangle_list {
	    set normal "[expr [lindex [lindex $triangle_normal $tr] 0] \
                      +  [lindex $normal 0]] \
                     [expr [lindex [lindex $triangle_normal $tr] 1] \
                      +  [lindex $normal 1]] \
                     [expr [lindex [lindex $triangle_normal $tr] 2] \
                      +  [lindex $normal 2]] \
                     "	    
	    set bary "[expr [lindex [lindex $middle_of_triangle_pos $tr] 0] \
                      +  [lindex $bary 0]] \
                     [expr [lindex [lindex $middle_of_triangle_pos $tr] 1] \
                      +  [lindex $bary 1]] \
                     [expr [lindex [lindex $middle_of_triangle_pos $tr] 2] \
                      +  [lindex $bary 2]] \
                     "	    
	    set nb_neighbourgs [expr $nb_neighbourgs + 1.0]
	}
	set normal "[expr [lindex $normal 0] / $nb_neighbourgs] \
                  [expr [lindex $normal 1] / $nb_neighbourgs] \
                  [expr [lindex $normal 2] / $nb_neighbourgs]" 
	set bary "[expr [lindex $bary 0] / $nb_neighbourgs] \
                  [expr [lindex $bary 1] / $nb_neighbourgs] \
                  [expr [lindex $bary 2] / $nb_neighbourgs]" 
	
	lappend vertices_normal [vecnorm $normal]
	set vertex [VMDSurface_vertex $surface $vertex_id]
	set atomA [VMDSurfaceVertex_A_get $vertex]
	set atomB [VMDSurfaceVertex_B_get $vertex]
	set index_A [VMDAtom_id_get $atomA]
	set index_B [VMDAtom_id_get $atomB]
	lappend vertices_color [$color_func $molA_id $index_A  $molB_id $index_B]
	set data_A [lindex $arrayA $index_A]
	set data_B [lindex $arrayB $index_B]
	
	if {[expr $::NicoStuff::dist_threshold > [vecdist  $data_A $data_B]] && [expr $show_delaunay != 0]} {
	    graphics $mol color yellow
	    graphics $mol line $data_A  $data_B
	}



	if {$smooth} {
	    lappend vertices_pos $bary
	} else {
	    
	    set pos "[expr $ABcoeff * [lindex $data_A 0] \
                      +(1-$ABcoeff) *  [lindex $data_B 0]] \
                     [expr $ABcoeff * [lindex $data_A 1] \
                      +(1-$ABcoeff) *  [lindex $data_B 1]] \
                      [expr $ABcoeff * [lindex $data_A 2] \
                      +(1-$ABcoeff) *  [lindex $data_B 2]] \
                     " 
	    lappend vertices_pos $pos
	    unset pos
	}
	unset vertex
	unset atomA
	unset atomB
	unset index_A
	unset index_B
	unset data_A
	unset data_B
	unset triangle_list
	unset nb_neighbourgs
	unset bary
	unset normal
	#puts $triangle_list

    }    


    # send the triangles to the vmd display list
    for {set x 0} {$x<[VMDSurface_size_of_triangles $surface]} {incr x} {
	set triangle [VMDSurface_triangle $surface $x]
	set current_triangle { }
	set current_normal { }
	set current_color { }
	set is_valid 1
	for {set i 0} {$i<3} {incr i} {
	    set vertex_id [VMDSurfaceTriangle_vertex $triangle $i]
	    set vertex [VMDSurface_vertex $surface $vertex_id]
	    set atomA [VMDSurfaceVertex_A_get $vertex]
	    set atomB [VMDSurfaceVertex_B_get $vertex]
	    set index_A [VMDAtom_id_get $atomA]
	    set index_B [VMDAtom_id_get $atomB]
	    set data_A [lindex $arrayA $index_A]
	    set data_B [lindex $arrayB $index_B]

 	    if {$::NicoStuff::dist_threshold < [vecdist  $data_A $data_B]} {
 		set is_valid 0	
 	    }
	    lappend current_color [lindex $vertices_color $vertex_id ]
	    lappend current_triangle [lindex $vertices_pos $vertex_id ]
	    lappend current_normal  [lindex $vertices_normal $vertex_id ]
	}

	if { $is_valid ==  1} {

	    # 	    graphics $mol triangle [lindex $current_triangle 0] \
				   #  		[lindex $current_triangle 1] \
				   #  		[lindex $current_triangle 2]

	    graphics $mol tricolor [lindex $current_triangle 0] \
 		[lindex $current_triangle 1] \
 		[lindex $current_triangle 2] \
		[lindex $current_normal 0] \
 		[lindex $current_normal 1] \
 		[lindex $current_normal 2] \
		[lindex $current_color 0] \
 		[lindex $current_color 1] \
 		[lindex $current_color 2]
	} 
    }

    unset vertex_neighbourgs_triangles
    unset middle_of_triangle_pos
    unset triangle_normal
    unset vertices_pos
    unset vertices_normal
    unset vertices_color   
    unset ABcoeff
    unset arrayA
    unset arrayB
    return

}


proc ::NicoStuff::currentSurface {surface_id } {
    if {$surface_id == "="} {
	puts "Create an interface first..."
	return ""
    }
    
    foreach surf $::NicoStuff::surfaces {
	if {[lindex $surf 0] == $surface_id} {
	    return [lindex $surf 1]
	}
    }
    return ""
}



# creates a graphic molecule representing the surface   
proc ::NicoStuff::add_surface_molecule {surface molidA molidB} {
    set mol [mol new]
    mol rename $mol "interface"
    
    lappend ::NicoStuff::surfaces "$mol $surface $molidA $molidB"    
    ::NicoStuff::sendGeometry  $mol $surface  $molidA $molidB
    display resetview
    return $mol
}


proc ::NicoStuff::load_surface {filename} {

    set filenameA ""
    set filenameB ""
    set f [open $filename "r"]
    gets $f filenameA
    gets $f filenameB
    close $f


    set A_id [::NicoStuff::mol_id_from_filename $filenameA]
    set B_id [::NicoStuff::mol_id_from_filename $filenameB]


    if { $B_id == -1 ||  $A_id == -1} {
	puts "The surface cannot be loaded since the corresponding molecules are not loaded yet"
	return ""
    }
    set surface [new_VMDSurface]
    VMDSurface_load $surface $filename

    
    set mol [::NicoStuff::add_surface_molecule $surface [::NicoStuff::mol_id_from_filename $filenameA] [::NicoStuff::mol_id_from_filename $filenameB] ]
    return $mol
}

proc ::NicoStuff::save {surface filename molA_id molB_id} {
    VMDSurface_merge_vertices $surface
    VMDSurface_save_as $surface $filename [molinfo $molA_id get filename] [molinfo $molB_id get filename] 
}


proc ::NicoStuff::updateRenderingMode {surface_id  snap_mode transparent} {
    set surface [::NicoStuff::currentSurface $surface_id]
    if {$surface == ""} {
	puts "surface_id $surface_id is not an interface"
	return
    }
    
    foreach primitive [graphics $surface_id list] {
	graphics $surface_id delete $primitive
    }

    #retreive molecules ids 
    set surf_id [::NicoStuff::get_interface_id $surface_id]
    set molA_id [lindex [lindex $::NicoStuff::surfaces $surf_id] 2]
    set molB_id [lindex [lindex $::NicoStuff::surfaces $surf_id] 3]
    
    
    ::NicoStuff::sendGeometry  $surface_id $surface $molA_id $molB_id
}



proc ::NicoStuff::createInterface {sel_A sel_B} {
    set surface_extractor [new_CoarseSurfaceExtractor]
    set surface [new_VMDSurface]
    # add atoms to the delaunay
    set infoA {}
    set infoA [$sel_A get {x y z index type charge mass}]
    foreach atom  $infoA {
	CoarseSurfaceExtractor_add_point $surface_extractor 1 \
	    [lindex $atom 0] [lindex $atom 1] [lindex $atom 2] \
	    [lindex $atom 3]
    }
    set infoB {}
    set infoB [$sel_B get {x y z index type charge mass}]
    foreach atom  $infoB {
	CoarseSurfaceExtractor_add_point $surface_extractor 2 \
	    [lindex $atom 0] [lindex $atom 1] [lindex $atom 2]  \
	    [lindex $atom 3]
    }

    #extract surface
    CoarseSurfaceExtractor_extract_interface $surface_extractor $surface 1 2
    delete_CoarseSurfaceExtractor $surface_extractor
    VMDSurface_merge_vertices $surface
    return $surface
}


