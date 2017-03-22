
############################################################
#
#    This file contains procedures to wrap atoms into the central
# image of a system with periodic boundary conditions. The procedures
# required the VMD unit cell properties to be set. Use the procedure
# pbcset on this behalf.
#
# $Id: pbcwrap.tcl,v 1.6 2007/07/31 16:06:06 johns Exp $
#

package provide pbctools 2.1

namespace eval ::PBCTools:: {
    namespace export pbc*

    ############################################################
    #
    # pbcwrap [OPTIONS...]
    #
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now 
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -parallelepiped|-rectangular
    #   -sel $sel
    #   -nocompound|-compound res[idue]|seg[ment]|chain
    #   -nocompundref|-compoundref $sel
    #   -center origin|unitcell|$sel
    #   -shiftcenter $shift 
    #   -shiftcenterrel $shift
    #   -[no]draw
    #   -verbose
    #
    # AUTHORS: Jan, Olaf
    #
    proc pbcwrap { args } {
	# Set the defaults
	set molid "top"
	set first "now"
	set last "now"
	set rectangular 0
	set sel "all"
	set compound "res"
	set compoundref ""
	set center "unitcell"
	set shiftcenter {0 0 0}
	set shiftcenterrel {}
	set draw 0
	set verbose 0

	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr $argnum + 1]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last" { set last $val; incr argnum }
		"-allframes" -
		"-all" { set last "last"; set first "first" }
		"-now" { set last "now"; set first "now" }
		"-parallelepiped" { set rectangular 0 }
		"-rectangular" { set rectangular 1 }
		"-sel" { set sel $val; incr argnum }
		"-nocompound" { set compound "" }
		"-compound" { set compound $val; incr argnum }
		"-nocompoundref" { set compoundref "" }
		"-compoundref" { set compoundref $val; incr argnum }
		"-center" { set center $val; incr argnum }
		"-shiftcenter" { set shiftcenter $val; incr argnum }
		"-shiftcenterrel" { set shiftcenterrel $val; incr argnum }
		"-draw" { set draw 1 }
		"-nodraw" { set draw 0 }
		"-verbose" { incr verbose }
		default { error "pbcwrap: unknown option: $arg" }
	    }
	}
	
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	# handle first and last frame
	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [molinfo $molid get numframes]
	    incr last -1
	}

	# handle compounds
	switch -- $compound {
	    "" {}
	    "res" -
	    "residue" { set compound "residue" }
	    "seg" -
	    "segment" { set compound "segment" }
	    "chain" { set compound "chain" }
	    default { 
		error "pbcwrap: bad argument to -compound: $compound" 
	    }
	}

	# handle the reference selection
	# $wrapsel will be used as format string
	if { [string length $compound] } then {
	    if { [string length $compoundref] } then {
		set wrapsel "($sel) and (not same $compound as (($compoundref) and (%s)))"
	    } else {
		set wrapsel "($sel) and (not same $compound as (%s))"
	    }
	} else {
	    # no compound case
	    set wrapsel "($sel) and (not %s)"
	}
	if { $verbose } then { puts "wrapsel=$wrapsel" }

	if { $verbose } then { puts "Wrapping..." }
	set next_time [clock clicks -milliseconds]
	set show_step 1000
	set fac [expr 100.0/($last - $first + 1)]
	# Loop over all frames
	for { set frame $first } { $frame <= $last } { incr frame } {
	    if { $verbose } then { puts "Wrapping frame $frame..." } 
	    
	    # Switch to the next frame
	    molinfo $molid set frame $frame

	    # get the unit cell data
	    set cell [lindex [ pbcget -check -namd -now -molid $molid ] 0]
	    set A [lindex $cell 0]
	    set B [lindex $cell 1]
	    set C [lindex $cell 2]
	    set Ax [lindex $A 0]
	    set By [lindex $B 1]
	    set Cz [lindex $C 2]

	    # compute the origin (lower left corner)
	    if { $rectangular } then {
		set origin [vecscale -0.5 [list $Ax $By $Cz]]
	    } else {
		set origin [vecscale -0.5 [vecadd $A $B $C]]
	    }
	    switch -- $center {
		"unitcell" { set origin { 0 0 0 } }
		"origin" {}
		default {
		    # set the origin to the center of the selection
		    set centersel [atomselect $molid "($center)"]
		    set minmax [measure minmax $centersel]
		    if { [$centersel num] == 0 } then {
			puts "Warning: Selection \"$center\" contains no atoms!"
		    }
		    $centersel delete
		    set origin \
			[vecadd $origin \
			     [vecscale 0.5 \
				  [vecadd \
				       [lindex $minmax 0] \
				       [lindex $minmax 1] \
				      ]]]
		}
	    }

	    # shift the origin
	    set origin [vecadd $origin $shiftcenter]
	    if { [llength $shiftcenterrel] } then {
		set shifta [lindex $shiftcenterrel 0]
		set shiftb [lindex $shiftcenterrel 1]
		set shiftc [lindex $shiftcenterrel 2]
		set origin [vecadd $origin \
				[vecscale $shifta $A] \
				[vecscale $shiftb $B] \
				[vecscale $shiftc $C] \
			       ]
	    }

	    # Wrap it
	    if { $rectangular } then {
		wrap_to_rectangular_unitcell \
		    $molid $A $B $C $origin $wrapsel
	    } else {
		wrap_to_unitcell \
		    $molid $A $B $C $origin $sel $wrapsel $draw
	    }

	    set time [clock clicks -milliseconds]
	    if {$verbose || $frame == $last || $time >= $next_time} then {
		set percentage [format "%3.1f" [expr $fac*($frame-$first+1)]]
		puts "$percentage% complete (frame $frame)"
		set next_time [expr $time + $show_step]
	    }
	}
	
	if  { $verbose } then {
	    puts "Wrapping complete."
	}

	# Rewind to original frame
	if { $verbose } then { puts "Rewinding to frame $frame_before." }
	animate goto $frame_before
    }

    #########################################################
    # Wrap the selection $seltext of molecule $molid
    # in the current frame into the unitcell parallelepiped
    # defined by $A, $B, $C and $origin.
    # When $draw is set, draw some test vectors (for
    # debugging).
    # $compoundsel contains a partial selection text that
    # is used to avoid splitting compounds.
    # Return the number of atoms that were wrapped.
    #########################################################
    proc wrap_to_unitcell { molid A B C origin seltext wrapsel draw } {
	# The wrapping of atoms is done by transforming the unit cell to a 
	# orthonormal cell which allows to easily select atoms outside the 
	# cell (x<1 or x>1, ...). After wrapping them along the coordinate axes 
	# into the cell, the system is transformed back.
	
	set a1 $A
	set a2 $B
	set a3 $C
	
	if {$draw} {
	    # Draw the unitcell vectors.
	    #draw delete all
	    draw color red
	    draw arrow $origin [vecadd $origin $a1]
	    draw arrow $origin [vecadd $origin $a2]
	    draw arrow $origin [vecadd $origin $a3]
	    #set offset [transoffset $ori]
	}
	
	# Orthogonalize system:
	# Find an orthonormal basis (in cartesian coords)
	set obase [orthonormal_basis $a1 $a2 $a3]
	
	if {$draw} {
	    # Draw the orthonormal base vectors (scaled by the 
	    # length of $a1 to make it visible).
	    set ob1 [lindex $obase 0]
	    set ob2 [lindex $obase 1]
	    set ob3 [lindex $obase 2]
	    draw color yellow
	    draw arrow $origin [vecadd $origin [vecscale $ob1 [veclength $a1]]]
	    draw arrow $origin [vecadd $origin [vecscale $ob2 [veclength $a1]]]
	    draw arrow $origin [vecadd $origin [vecscale $ob3 [veclength $a1]]]
	}
	
	# Get $obase in cartesian coordinates (it is the inverse of the
	# $obase->cartesian transformation):
	set obase_cartcoor  [basis_change $obase [list {1 0 0} {0 1 0} {0 0 1}] ]
	
	# Transform into 4x4 matrix:
	set obase2cartinv [trans_from_rotate $obase_cartcoor]
	
	# This is the matrix for the $obase->cartesian transformation:
	set obase2cart  [measure inverse $obase2cartinv]
	
	# Get coordinates of $a in terms of $obase
	set m [basis_change [list $a1 $a2 $a3] $obase]
	set rmat [measure inverse [trans_from_rotate $m]]
	
	# actually: [transmult $obase2cart $obase2cartinv $rmat $obase2cart]
	set mat4 [transmult $rmat $obase2cart [transoffset [vecinvert $origin]]]
	
	# apply the user selection
	set usersel [atomselect $molid $seltext]

	# Transform the unit cell to a orthonormal cell
	$usersel move $mat4
	
	# Now we can easily select the atoms outside the cell and
	# wrap them
	shift_sel $molid [format $wrapsel "x<1"] {-1 0 0}
	shift_sel $molid [format $wrapsel "x>0"] {1 0 0}
	shift_sel $molid [format $wrapsel "y<1"] {0 -1 0}
	shift_sel $molid [format $wrapsel "y>0"] {0 1 0}
	shift_sel $molid [format $wrapsel "z<1"] {0 0 -1}
	shift_sel $molid [format $wrapsel "z>0"] {0 0 1}
	
	$usersel move [measure inverse $mat4]
	$usersel delete

	if {$draw} {
	    # Draw the transformed unitcell vectors (scaled by the length of $a1)
	    # They should lie exactly on top of the orthogonal basis 
	    # (drawn before in yellow).
	    set c1 [vecscale [coordtrans $mat4 $a1] [veclength $a1]]
	    set c2 [vecscale [coordtrans $mat4 $a2] [veclength $a1]]
	    set c3 [vecscale [coordtrans $mat4 $a3] [veclength $a1]]
	    draw color green
	    draw arrow $origin [vecadd $origin $c1]
	    draw arrow $origin [vecadd $origin $c2]
	    draw arrow $origin [vecadd $origin $c3]
	}
    }


    ########################################################
    # Wrap the selection $seltext of molecule $molid
    # in the current frame into the rectangular unitcell
    # defined by $Ax, $By, $Cz and $origin.
    # $wrapsel is a format string that will be used together with 

    ########################################################
    proc wrap_to_rectangular_unitcell { molid A B C origin wrapsel } {
	foreach {ox oy oz} $origin {break}
	set cx [expr $ox + [lindex $A 0]]
	set cy [expr $oy + [lindex $B 1]]
	set cz [expr $oz + [lindex $C 2]]

	shift_sel $molid [format $wrapsel "z<$cz"] [vecinvert $C]
	shift_sel $molid [format $wrapsel "z>$oz"] $C
	shift_sel $molid [format $wrapsel "y<$cy"] [vecinvert $B]
	shift_sel $molid [format $wrapsel "y>$oy"] $B
	shift_sel $molid [format $wrapsel "x<$cx"] [vecinvert $A]
	shift_sel $molid [format $wrapsel "x>$ox"] $A
    }


    ########################################################
    # Shift the selection $seltext of molecule $molid in   #
    # the current frame by $shift, until the selection is  #
    # empty.                                               #
    ########################################################
    proc shift_sel { molid seltext shift {iter 50}} {
	set sel [atomselect $molid $seltext]
	set shifted_atoms [$sel num]

	set i 0
	while { [$sel num] > 0 && $i<$iter} {
	    $sel moveby $shift
	    $sel update
	    incr i
	}
	$sel delete
	return $shifted_atoms
    }


    ########################################################
    # Scale a 4x4 matrix by factors $s1 $s2 $s3 along the  #
    # coordinate axes.                                     #
    ########################################################

    proc scale_mat { s1 s2 s3 } {
	set v1 [list $s1 0 0 0]
	set v2 [list 0 $s2 0 0]
	set v3 [list 0 0 $s3 0]
	return [list $v1 $v2 $v3 {0.0 0.0 0.0 1.0}]
    }

    ########################################################
    # Returns vector $vec in coordinates of an orthonormal #
    # basis $obase.                                        #
    ########################################################

    proc basis_change { vec obase } {
	set dim1 [llength $vec]
	set dim2 [llength [lindex $obase 0]]
	if {$dim1!=$dim2} {
	    error "basis_change: dim of vector and basis differ; $dim1, $dim2"
	}
	set cc {}
	foreach i $obase {
	    set c {}
	    foreach j $vec {
		lappend c [vecdot $j $i]
	    }
	    lappend cc $c
	}
	return $cc
    }

    ###################################################
    # Find an orthogonal basis R^3 with $ob1=$b1      #
    ###################################################

    proc orthogonal_basis { b1 b2 b3 } {
	set ob1 $b1
	set e1  [vecnorm $ob1]
	set ob2 [vecsub $b2  [vecscale [vecdot $e1 $b2] $e1]]
	set e2  [vecnorm $ob2]
	set ob3 [vecsub $b3  [vecscale [vecdot $e1 $b3] $e1]]
	set ob3 [vecsub $ob3 [vecscale [vecdot $e2 $b3] $e2]]
	#draw color red
	#draw arrow {0 0 0} $b1
	#draw arrow {0 0 0} $b2
	#draw arrow {0 0 0} $b3
	#draw color yellow
	#draw arrow {0 0 1} $ob1
	#draw arrow {0 0 1} $ob2
	#draw arrow {0 0 1} $ob3
	return [list $ob1 $ob2 $ob3]
    }


    ###################################################
    # Find an orthogonal basis R^3 with $ob1 || $b1   #
    ###################################################

    proc orthonormal_basis { b1 b2 b3 } {
	set ob1 $b1
	set e1  [vecnorm $ob1]
	set ob2 [vecsub $b2  [vecscale [vecdot $e1 $b2] $e1]]
	set e2  [vecnorm $ob2]
	set ob3 [vecsub $b3  [vecscale [vecdot $e1 $b3] $e1]]
	set ob3 [vecsub $ob3 [vecscale [vecdot $e2 $b3] $e2]]
	set e3  [vecnorm $ob3]
	#draw color red
	#draw arrow {0 0 0} $b1
	#draw arrow {0 0 0} $b2
	#draw arrow {0 0 0} $b3
	#draw color yellow
	#draw arrow {0 0 1} $ob1
	#draw arrow {0 0 1} $ob2
	#draw arrow {0 0 1} $ob3
	return [list $e1 $e2 $e3]
    }


    ######################################
    # Just a test for my algorithm...    #
    ######################################
    proc orthogonalizationtest { } {
	package require vmd_draw_arrow
	draw delete all
	set a1 {2 0 3}
	set a2 {0 3 0}
	set a3 {0 2 4}
	# Find an orthonormal basis (in cartesian coords)
	set b [orthonormal_basis $a1 $a2 $a3]
	set b1 [lindex $b 0]
	set b2 [lindex $b 1]
	set b3 [lindex $b 2]
	puts "b = $b"
	# Get coordinates of $b in terms of cartesian coords
	set obase_cartcoor  [basis_change $b [list {1 0 0} {0 1 0} {0 0 1}] ]
	set obase2cartinv [trans_from_rotate $obase_cartcoor]
	set obase2cart  [measure inverse $obase2cartinv]
	set c1  [coordtrans $obase2cart $b1]
	set c2  [coordtrans $obase2cart $b2]
	set c3  [coordtrans $obase2cart $b3]

	draw color purple
	draw arrow {0 0 0} {1 0 0} 0.1
	draw arrow {0 0 0} {0 1 0} 0.1
	draw arrow {0 0 0} {0 0 1} 0.11
	if {0} {
	    draw color yellow
	    draw arrow {0 0 0} $c1 0.1
	    draw arrow {0 0 0} $c2 0.1
	    draw arrow {0 0 0} $c3 0.1
	}
	# Get coordinates of $a in terms of $b
	set m [basis_change [list $a1 $a2 $a3] $b]
	puts "m = $m"

	set rmat [measure inverse [trans_from_rotate $m]]
	puts $rmat

	# Scale vectors to their original length
	set smat [scale_mat [veclength $a1] [veclength $a2] [veclength $a3]]
	puts "smat = $smat"

	# Get transformation in cartesian coords
	# actually: [transmult $obase2cart $obase2cartinv $smat $rmat $obase2cart]
	set mat4 [transmult $smat $rmat $obase2cart]
	set c1  [coordtrans $mat4 $a1]
	set c2  [coordtrans $mat4 $a2]
	set c3  [coordtrans $mat4 $a3]

	draw color red
	draw arrow {0 0 0} $a1 0.1
	draw arrow {0 0 0} $a2 0.1
	draw arrow {0 0 0} $a3 0.1
	draw color yellow
	draw arrow {0 0 0} $b1 0.1
	draw arrow {0 0 0} $b2 0.1
	draw arrow {0 0 0} $b3 0.1
	draw color green
	draw arrow {0 0 0} $c1 0.09
	draw arrow {0 0 0} $c2 0.09
	draw arrow {0 0 0} $c3 0.09

    }

    # Wrap the coordinates in the variables referenced by var_xs,
    # var_ys and var_zs into the unitcell centered around the
    # coordinates in $rxs, $rys, $rzs.
    # The lists referenced by var_xs, var_ys and var_zs have to have
    # the same lengths. $rxs, $rys and $rzs may either be lists of the
    # same length, or scalar values.
    proc pbcwrap_coordinates {A B C var_xs var_ys var_zs rxs rys rzs} {
	upvar $var_xs xs $var_ys ys $var_zs zs

 	# If rxs, rys and rzs are single values, create a list of
 	# the length of $xs, 
 	if {[llength $rxs] == 1} then {
	    set rx $rxs
	    for {set i 1} {$i < [llength $xs]} {incr i} {
		lappend rxs $rx
	    }
	} elseif {[llength $rxs] != [llength $xs]} then {
	    error "pbcwrap_coordinates: rxs either has to be of length 1 or of the same length as $var_xs!"
	}
 	if {[llength $rys] == 1} then {
	    set ry $rys
	    for {set i 1} {$i < [llength $ys]} {incr i} {
		lappend rys $ry
	    }
	} elseif {[llength $rys] != [llength $ys]} then {
	    error "pbcwrap_coordinates: rys either has to be of length 1 or of the same length as $var_ys!"
	}
 	if {[llength $rzs] == 1} then {
	    set rz $rzs
	    for {set i 1} {$i < [llength $zs]} {incr i} {
		lappend rzs $rz
	    }
	} elseif {[llength $rzs] != [llength $zs]} then {
	    error "pbcwrap_coordinates: rzs either has to be of length 1 or of the same length as $var_zs!"
	}
	    
	# get the cell vectors
	set Ax   [lindex $A 0]
	set Bx   [lindex $B 0]
	set By   [lindex $B 1]
	set Cx   [lindex $C 0]
	set Cy   [lindex $C 1]
	set Cz   [lindex $C 2]
	
	set Ax2 [expr 0.5*$Ax]
	set By2 [expr 0.5*$By]
	set Cz2 [expr 0.5*$Cz]
	set iAx  [expr 1.0/$Ax]
	set iBy  [expr 1.0/$By]
	set iCz  [expr 1.0/$Cz]
	
	# create lists of the right lengths
	set shiftAs $xs
	set shiftBs $xs
	set shiftCs $xs
	
	# compute the differences in the z coordinate
	set dzs [vecsub $zs $rzs]
	# compute the required shift
	set i 0
	foreach dz $dzs {
	    set shift 0
	    if { $dz > $Cz2 } then {
		incr shift -1
		while { $dz+$shift*$Cz > $Cz2 } { incr shift -1 }
	    } elseif { $dz < -$Cz2 } then {
		incr shift
		while { $dz+$shift*$Cz < -$Cz2 } { incr shift }
	    }
	    lset shiftCs $i $shift
	    incr i
	}
	# apply shiftCs to zs
	set zs [vecadd $zs [vecscale $Cz $shiftCs]]
	
	# apply shiftC to ys
	set ys [vecadd $ys [vecscale $Cy $shiftCs]]
	# compute the differences in the y coordinate
	set dys [vecsub $ys $rys]
	# compute the required shift
	set i 0
	foreach dy $dys {
	    set shift 0
	    if { $dy > $By2 } then {
		incr shift -1
		while { $dy+$shift*$By > $By2 } { incr shift -1 }
	    } elseif { $dy < -$By2 } then {
		incr shift
		while { $dy+$shift*$By < -$By2 } { incr shift }
	    }
	    lset shiftBs $i $shift
	    incr i
	}
	# apply shiftB to ys
	set ys [vecadd $ys [vecscale $By $shiftBs]]
	
	# get the current x coordinates and apply shiftC and shiftB
	set xs [vecadd $xs [vecscale $Cx $shiftCs] [vecscale $Bx $shiftBs]]
	# compute the differences in the x coordinate
	set dxs [vecsub $xs $rxs]
	# compute the required shift
	set i 0
	foreach dx $dxs {
	    set shift 0
	    if { $dx > $Ax2 } then {
		incr shift -1
		while { $dx+$shift*$Ax > $Ax2 } { incr shift -1 }
	    } elseif { $dx < -$Ax2 } then {
		incr shift
		while { $dx+$shift*$Ax < -$Ax2 } { incr shift }
	    }
	    lset shiftAs $i $shift
	    incr i
	}
	# apply shiftA to xs
	set xs [vecadd $xs [vecscale $Ax $shiftAs]]
	
	return [list $shiftAs $shiftBs $shiftCs]
    }
}


