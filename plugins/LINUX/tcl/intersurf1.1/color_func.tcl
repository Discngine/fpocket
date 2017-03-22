
proc color_from_distance {mol_idA indexA mol_idB indexB} {
    set selA [atomselect $mol_idA  "index $indexA"]
    set selB [atomselect $mol_idB  "index $indexB"]
    set dataA [$selA get {x y z}]
    set dataB [$selB get {x y z}]

    set mincolorid [colorinfo num]
    set maxcolorid [expr [colorinfo max] - 1]
    set numscaleids [expr $maxcolorid - $mincolorid]

    set result [expr $mincolorid+$numscaleids * 0.2* ([veclength [::NicoStuff::vector_diff [lindex $dataA 0]  [lindex $dataB 0] ]] -2.0) ]
    set colorid [expr int($result)]
    
    if {$colorid > $numscaleids} {set colorid $numscaleids}
    if {$colorid < $mincolorid} {set colorid $mincolorid}
    
    unset dataA
    unset dataB
    $selA delete
    $selB delete

    return $colorid
}



proc color_from_resname {mol_id index} {
    set sel [atomselect $mol_id  "index $index"]
    set data [$sel get resname ]
    if {[expr [string compare $data  GLU]==0]} { return 0 }
    if {[expr [string compare $data  ALA]==0]} { return 1 }
    if {[expr [string compare $data  VAL]==0]} { return 2 }
    if {[expr [string compare $data  LEU]==0]} { return 3 }
    if {[expr [string compare $data  LYS]==0]} { return 4 }
    if {[expr [string compare $data  PHE]==0]} { return 5 }
    if {[expr [string compare $data  ARG]==0]} { return 6 }
    if {[expr [string compare $data  HIS]==0]} { return 7 }
    if {[expr [string compare $data  ASP]==0]} { return 8 }
    unset data
    $sel delete
    return 17
    return $colorid
}

proc color_from_charge {mol_idA indexA mol_idB indexB} {
    set selA [atomselect $mol_idA  "index $indexA"]
    set dataA [$selA get charge ]
    $selA delete
    set result [expr int( 520 + $dataA*500)]
    unset dataA
    return  $result
}


proc color_from_resnameA {mol_idA indexA mol_idB indexB} {
    return [color_from_resname  $mol_idA $indexA]
    
}
proc color_from_resnameB {mol_idA indexA mol_idB indexB} {
    return [color_from_resname  $mol_idB $indexB]
}




proc kind_of_residue {res_name} {
    if {[expr [string compare $res_name  ALA]==0]} { return hydrophobe }
    if {[expr [string compare $res_name  PRO]==0]} { return hydrophobe }
    if {[expr [string compare $res_name  VAL]==0]} { return hydrophobe }
    if {[expr [string compare $res_name  ILE]==0]} { return hydrophobe }
    if {[expr [string compare $res_name  LEU]==0]} { return hydrophobe }
    if {[expr [string compare $res_name  MET]==0]} { return hydrophobe }

    if {[expr [string compare $res_name  LYS]==0]} { return pos_charged }
    if {[expr [string compare $res_name  ARG]==0]} { return pos_charged }

    if {[expr [string compare $res_name  GLU]==0]} { return neg_charged }
    if {[expr [string compare $res_name  ASP]==0]} { return neg_charged }

    if {[expr [string compare $res_name  CYS]==0]} { return polaire }
    if {[expr [string compare $res_name  SER]==0]} { return polaire }
    if {[expr [string compare $res_name  ASN]==0]} { return polaire }
    if {[expr [string compare $res_name  GLN]==0]} { return polaire }
    if {[expr [string compare $res_name  THR]==0]} { return polaire }

    if {[expr [string compare $res_name  PHE]==0]} { return aromatique }
    if {[expr [string compare $res_name  TYR]==0]} { return aromatique }
    if {[expr [string compare $res_name  HIS]==0]} { return aromatique }
    if {[expr [string compare $res_name  TRP]==0]} { return aromatique }

    return unknowned    
}

proc color_residue_interaction {mol_idA indexA mol_idB indexB} {
    set selA [atomselect $mol_idA  "index $indexA"]
    set res_name_A [$selA get resname ]
    set selB [atomselect $mol_idB  "index $indexB"]
    set res_name_B [$selB get resname ]

    if {[expr [string compare [kind_of_residue $res_name_A]  hydrophobe]==0]} { 
	# hydrophe link
	if {[expr [string compare [kind_of_residue $res_name_B]  hydrophobe]==0]} {return 0}
	
    }

    if {[expr [string compare [kind_of_residue $res_name_A] pos_charged ]==0]} { 
	# same charge
	if {[expr [string compare [kind_of_residue $res_name_B]  pos_charged]==0]} {return 1}

	# opposite charge
	if {[expr [string compare [kind_of_residue $res_name_B]  neg_charged]==0]} {return 2} 

	# PI_X
	if {[expr [string compare [kind_of_residue $res_name_B]  polaire]==0]} {return 3} 
    }

    if {[expr [string compare [kind_of_residue $res_name_A] neg_charged ]==0]} {
	# same charge
	if {[expr [string compare [kind_of_residue $res_name_B]  neg_charged]==0]} {return 1}	
	# opp charge
	if {[expr [string compare [kind_of_residue $res_name_B]  pos_charged]==0]} {return 2}
	# PI_X
	if {[expr [string compare [kind_of_residue $res_name_B]  polaire]==0]} {return 3} 	
    }

    if {[expr [string compare [kind_of_residue $res_name_A] polaire ]==0]} {
	# PI_X	
	if {[expr [string compare [kind_of_residue $res_name_B]  neg_charged]==0]} {return 3}	
	# PI_X
	if {[expr [string compare [kind_of_residue $res_name_B]  pos_charged]==0]} {return 3}	
    }
    
    if {[expr [string compare [kind_of_residue $res_name_A]  aromatique]==0]} {
	# PI_PI	
	if {[expr [string compare [kind_of_residue $res_name_B]  aromatique]==0]} {return 4}	
    }
    #puts $res_name_A 
    #puts [kind_of_residue $res_name_A]

    return 16
}



proc color_white {mol_idA indexA mol_idB indexB} {
    return 8
}


proc color_yellow {mol_idA indexA mol_idB indexB} {
    return 4 
}

