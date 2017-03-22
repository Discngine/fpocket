############################################################
# 
#   This file contains procedures to set and get the VMD unitcell
# parameters.
#
# $Id: pbcset.tcl,v 1.5 2007/07/31 16:06:06 johns Exp $
#

package provide pbctools 2.1

namespace eval ::PBCTools:: {
    namespace export pbc*

    ############################################################
    # 
    # pbcset $cell [OPTIONS...]
    #
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -namd|vmd
    #   -[no]alignx
    #
    # AUTHORS: Olaf
    #
    proc pbcset { cellparams args } {
	# Set the defaults
	set molid "top"
	set first "now"
	set last "now"
	set format "vmd"
	set alignx "0"

	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr {$argnum + 1}]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last"  { set last $val; incr argnum }
		"-allframes" -
		"-all"   { set last "last"; set first "first" }
		"-now"   { set last "now"; set first "now" }
		"-vmd"   { set format "vmd" }
		"-namd"  { set format "namd" }
		"-alignx" { set alignx 1 }
		"-noalignx" { set alignx 0 }
		default  { error "ERROR: pbcset: unknown option: $arg" }
	    }
	}


	# Handle symbolic options
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [expr {[molinfo $molid get numframes]-1}]
	}

	# Check the cell parameters
	if { ($format == "vmd" && [llength [lindex $cellparams 0]] == 1) || \
		 ($format == "namd" && [llength [lindex $cellparams 0 0]] == 1)} then {
	    # CELL PARAMETERS ARE A SINGLE SET
	    if { $format=="vmd" } then {
		# VMD case
		if { [llength $cellparams] == 3} then {
		    set cellparams [concat $cellparams 90 90 90]
		} elseif {[llength $cellparams] != 6} then {
		    error "ERROR: pbcset: cell parameters should be a b c \[alpha beta gamma\]"
		}
	    } else {
		# NAMD case
		set res [pbc_namd2vmd $cellparams]
		set cellparams [lrange $res 0 5]
		if { [llength $res] > 6 } then {
		    if { $alignx } then {
			set namd_rot [lrange $res 6 8]
		    } else {
			error [concat "ERROR: pbcset: NAMD unit cell vector is not aligned to the x-axis!\n" \
			       "Use \"-alignx\" to automatically rotate the system accordingly!" ]
		    }
		} else {
		    set namd_rot 1
		}
	    }
	    set single 1
	} else {
	    # CELL PARAMETERS ARE A LIST
	    # test whether the length of the list is sufficient
	    if { [llength $cellparams] < ($last - $first) } then {
		error "ERROR: pbcset: cell parameter list contains too few parameter sets!"
	    }
	    # now test whether the list elements are complete
	    if { $format=="namd" && $alignx } then { set namd_rot {} }
	    for { set i 0 } { $i < [llength $cellparams] } { incr i } { 
		set cell [lindex $cellparams $i]
		if { $format=="vmd" } then {
		    # VMD format
		    if {[llength $cell] == 3} then {
			set cell [concat $cell 90 90 90]
		    } elseif {[llength $cell] != 6} then {
			error "ERROR: pbcset: cell parameters should be {a b c \[alpha beta gamma\]}"
		    }
		    lset cellparams $i $cell
		} else {
		    # NAMD format
		    set res [pbc_namd2vmd $cell]
		    set cell [lrange $res 0 5]
		    if { [llength $res] > 6 } then {
			if { $alignx } then {
			    lappend namd_rot [list [lrange $res 6 8]]
			} else {
			    set msg \
				[concat \
				     "ERROR: pbcset: NAMD unit cell vector is not aligned to the x-axis!" \
				     "Use \"-alignx\" to automatically rotate the system accordingly!" \
				    ]
			    error $msg
			}
		    } else {
			lappend namd_rot 1
		    }
		    lset cellparams $i $cell
		}
	    }
	    set single 0
	}

	# Set the cell parameters
	for { set frame $first } { $frame <= $last } { incr frame } {
	    if { $single } then {
		set cell $cellparams
		if { $alignx && $namd_rot != 1} then { 
		    set sel [atomselect $molid all]
		    $sel move $namd_rot
		    $sel delete
		}
	    } else {
		set i [expr $frame-$first]
		set cell [lindex $cellparams $i]
		if { $alignx } then { 
		    set sel [atomselect $molid all]
		    $sel move [lindex $namd_rot $i]
		    $sel delete
		}
	    }

	    molinfo $molid set frame $frame
	    molinfo $molid set { a b c alpha beta gamma } $cell
	}
	molinfo $molid set frame $frame_before
    }


    ############################################################
    #
    # pbcget [OPTIONS...]
    #
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -namd|vmd
    #   -[no]check
    #
    # AUTHORS: Olaf
    #
    proc pbcget { args } { 
	# Set the defaults
	set molid "top"
	set first "now"
	set last "now"
	set format "vmd"
	set check 0

	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr {$argnum + 1}]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last"  { set last $val; incr argnum }
		"-allframes" -
		"-all"   { set last "last"; set first "first" }
		"-now"   { set last "now"; set first "now" }
		"-vmd"   { set format "vmd" }
		"-namd"  { set format "namd" }
		"-check" { set check 1 }
		"-nocheck" { set check 0 }
		default  { error "ERROR: pbcget: unknown option: $arg" }
	    }
	}

	# Handle symbolic options
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [expr {[molinfo $molid get numframes]-1}]
	}

	set res {}
	for { set frame $first } { $frame <= $last } { incr frame } {
	    molinfo $molid set frame $frame
	    set cell [molinfo $molid get { a b c alpha beta gamma }]
	    if { $check } then { pbc_check_cell $cell }
	    if { $format == "namd" } then {
		lappend res [pbc_vmd2namd $cell]
	    } else {
		lappend res $cell
	    }
	}
	molinfo $molid set frame $frame_before

	return $res
    }


    #####################################################
    # 
    # pbcreadxst $file [OPTIONS...]
    # 
    # OPTIONS:
    #   -molid $molid|top
    #   -first $first|first|now
    #   -last $last|last|now
    #   -all|allframes
    #   -now
    #   -stride $n
    #   -[no]alignx
    #   -[no]skipfirst
    #   -step2frame $num
    #   -log $l
    #
    # AUTHORS: Jan, Cameron
    #
    proc pbcreadxst { xstfile args } {
	# Defaults
	set molid  "top"
	set first  0
	set last   "last"
	set stride 1
	set alignx "-noalignx"
	if {[file extension $xstfile]==".xsc"} {
	    set skipfirst 0
	} else {
	    set skipfirst 1
	}
	set step2frame 0
	set log    {}

	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr {$argnum + 1}]]
	    switch -- $arg {
		"-molid" { set molid $val; incr argnum; }
		"-first" { set first $val; incr argnum }
		"-last"  { set last $val; incr argnum }
		"-allframes" -
		"-all"   { set last "last"; set first "first" }
		"-now"   { set last "now"; set first "now" }
		"-stride" { set stride $val; incr argnum; }
		"-alignx" -
		"-noalignx" { set alignx $arg }
		"-skipfirst" { set skipfirst 1 }
		"-noskipfirst" { set skipfirst 0 }
		"-step2frame" { set step2frame $val; incr argnum }
		"-log" { set log $val; incr argnum }
		default  { 
		    error "pbcset_xst: unknown option: $arg"
		}
	    }
	}

	# Handle symbolic options
	if { $molid=="top" } then { set molid [ molinfo top ] }

	# Save the current frame number
	set frame_before [ molinfo $molid get frame ]

	if { $first=="now" }   then { set first $frame_before }
	if { $first=="first" || $first=="start" || $first=="begin" } then { 
	    set first 0 
	}
	if { $last=="now" }    then { set last $frame_before }
	if { $last=="last" || $last=="end" } then {
	    set last [expr {[molinfo $molid get numframes]-1}]
	}

	# check file
	if {! [file exists $xstfile]} {
	    error "pbcreadxst: Didn't find XST file $xstfile"
	}

	set warn    0;  # If the axis was rotated, $warn is increased
	set dt      0
	set time    0
	set numline 0
	set frame   $first

	# Stream in the complete file at once
	set fd [open "$xstfile" r]
	set data [read -nonewline $fd]
	close $fd

	foreach line [split $data \n] {	    if {[string first \# $line]==-1 && [llength $line]>0} {
		# The first line is omitted, because xst info starts at frame 0 
		# while dcd record starts at frame 1.
		if {$skipfirst && $numline==0} { 
		    if {[llength $log]} { puts $log "Skipping first entry" }
		    incr numline
		    continue 
		}
		
		if {!($numline%$stride) && $frame<=$last} {
		    # Get the time
		    set oldtime $time;
		    set olddt $dt
		    set time [lrange $line 0 0]
		    # Get PBC vectors
		    set v1   [lrange $line 1 3]
		    set v2   [lrange $line 4 6]
		    set v3   [lrange $line 7 9]
		    set ori  [lrange $line 10 12]
		    set cell [list $v1 $v2 $v3 $ori]
		    
		    # Check if the number of timesteps per frame changed
		    set dt [expr {$time-$oldtime}];
		    if {!$numline==1 && $dt!=$olddt && [llength $log]} {
			puts $log "\nWARNING Stepsize in XST changed! dt=$dt, olddt=$olddt\n"
		    }
		    
		    # if provided, use conversion factor for times > 0:
		    if {$step2frame && $time} {
			if {$stride != 1} {
			    set effectiveframe [expr round( $time * $step2frame / $stride ) - 1]
			} else {
			    set effectiveframe [expr $time * $step2frame - 1]
			}
		    } else {
			set effectiveframe $frame
		    }

		    # Not nice: pbcset is called for every single frame. It
		    # would be better to first assemble a list of frames
		    # and then call pbcset once. However, the stride
		    # between the effective frames might be > 1, therefore
		    # this doesn't work.
		    pbcset $cell -namd -molid $molid -first $effectiveframe -last $effectiveframe $alignx

		    #DB puts "time = $time / effectiveframe = $effectiveframe"
		    if {[llength $log]} {
			puts $log "pbcreadxst: $frame $time $cell"
		    }
		    incr frame
		}
		incr numline
	    }
	}
	
	molinfo $molid set frame $frame_before
    }


    ###################################################################
    #
    # pbc_vmd2namd a b c [ alpha beta gamma ]
    #
    #   Transforms VMD style unit cell parameters into NAMD unit cell
    # vectors.
    #
    # From molfile_plugin.h:
    # Unit cell specification of the form A, B, C, alpha, beta, gamma.
    # A, B, and C are the lengths of the vectors.  alpha is angle 
    # between A and B, beta between A and C, and gamma between B and C.
    #      
    # AUTHORS: Jan
    #        
    proc pbc_vmd2namd { vmdcell } {
	if { [ llength $vmdcell ] >= 3 } then {
	    set a     [lindex $vmdcell 0]
	    set b     [lindex $vmdcell 1]
	    set c     [lindex $vmdcell 2]
	} else {
	    puts "usage: pbc_vmd2namd a b c \[ alpha beta gamma \]"
	    return
	}

	if { [ llength $vmdcell ] >= 6 } then {
	    set alpha [lindex $vmdcell 3]
	    set beta  [lindex $vmdcell 4]
	    set gamma [lindex $vmdcell 5]
	}
	
	# The following is taken from VMD Timestep.C
	# void Timestep::get_transforms(Matrix4 &a, Matrix4 &b, Matrix4 &c)

	# A will lie along the positive x axis.
	# B will lie in the x-y plane
	# The origin will be (0,0,0).

	# a, b, c are side lengths of the unit cell
	# alpha = angle between b and c
	# beta  = angle between a and c
	# gamma = angle between a and b

	set A {}; set B {}; set C {};

	# Note: Between VMD 1.8.2 and 1.8.3 the definition of the unitcell
	# parameters changed which is why we have to check the version
	if {[string compare "1.8.3" [vmdinfo version]]>0} {
	    #puts "VMD version <= 1.8.2"
	    set alphar [deg2rad $gamma];  # swapped!
	    set betar  [deg2rad $beta];
	    set gammar [deg2rad $alpha];  # swapped!

	    set cosAB  [expr {cos($alphar)}];
	    set sinAB  [expr {sin($alphar)}];
	    set cosAC  [expr {cos($betar)}];
	    set cosBC  [expr {cos($gammar)}];
	    
	    set Ax $a
	    set Bx [expr {$b*$cosAB}]
	    set By [expr {$b*$sinAB}]
	    set Cx [expr {$c*$cosAC}]
	    set Cy [expr {($b*$c*$cosBC-$Bx*$Cx)/$By}]
	    set Cz [expr {sqrt($c*$c-$Cx*$Cx-$Cy*$Cy)}]
	    
	    set A  [list $Ax 0.0 0.0]
	    set B  [list $Bx $By 0.0]
	    set C  [list $Cx $Cy $Cz]
	    
	    set phi [vecangle {0 0 1} $C]
	    set Cl [expr {$c/cos([deg2rad $phi])}]
	    set C [vecscale $Cl [vecnorm $C]]
	} else {
	    #puts "VMD version > 1.8.2 (including 1.8.3aXX)"
	    set cosBC [expr {cos([deg2rad $alpha])}]
	    set sinBC [expr {sin([deg2rad $alpha])}]
	    set cosAC [expr {cos([deg2rad $beta])}]
	    set cosAB [expr {cos([deg2rad $gamma])}]
	    set sinAB [expr {sin([deg2rad $gamma])}]
	    
	    set Ax $a
	    set Bx [expr {$b*$cosAB}]
	    set By [expr {$b*$sinAB}]
	    
	    # If sinAB is zero, then we can't determine C uniquely since it's defined
	    # in terms of the angle between A and B.
	    if {$sinAB>0} {
		set Cx $cosAC
		set Cy [expr {($cosBC - $cosAC * $cosAB) / $sinAB}]
		set Cz [expr {sqrt(1.0 - $Cx*$Cx - $Cy*$Cy)}]
	    } else {
		set Cx 0.0
		set Cy 0.0
		set Cz 0.0
	    }
	    
	    set A [list $Ax 0.0 0.0]
	    set B [list $Bx $By 0.0]
	    set C [list $Cx $Cy $Cz]
	    set C [vecscale $C $c]
	}

	return [list $A $B $C]
    }

    ###################################################################
    #
    # pbc_namd2vmd $a $b $c
    #
    #   Transforms NAMD unit cell vectors $a, $b and $c into VMD unit cell
    # parameters.
    # In NAMD, the vector A is not necessarily parallel to the
    # x-axis. Therefore, the procedure will also return the rotation
    # matrix required to rotate the coordinates so that it is parallel.
    #
    # AUTHORS: Jan
    #        
    proc pbc_namd2vmd { cell } {
	# Defaults
	set A [lindex $cell 0]
	set B [lindex $cell 1]
	set C [lindex $cell 2]

	# In molinfo the length of the cell vectors and the angles between 
	# them are saved. $a is assumed to point in x-direction.
	if {abs([vecdot [vecnorm $A] {1 0 0}]-1.0)>0.000001} {
	    # Compute transformation matrix to rotate A into x-axis
	    set rot [transvecinv $A]
	    set A [coordtrans $rot $A]
	    set B [coordtrans $rot $B]
	    set C [coordtrans $rot $C]
	}

	# Note: Between VMD 1.8.2 and 1.8.3 the definition of the unitcell
	# parameters changed which is why we have to check the version
	if {[string compare "1.8.3" [vmdinfo version]]>0} {
	    # puts "VMD version <= 1.8.2"
	    set gamma [vecangle $B $C]
	    set beta  [vecangle $A $C]
	    set alpha [vecangle $A $B]
	} else {
	    # puts "VMD version > 1.8.2 (including 1.8.3aXX)"
	    set alpha [vecangle $B $C]
	    set beta  [vecangle $A $C]
	    set gamma [vecangle $A $B]
	}

	set a [veclength $A]
	set b [veclength $B]
	set c [veclength $C]

	if {[info exists rot]} then {
	    return [list $a $b $c $alpha $beta $gamma $rot]
	} else {
	    return [list $a $b $c $alpha $beta $gamma]
	}
    }


    ###################################################################
    #
    # pbc_check_cell
    # 
    #   Test, whether the cell parameters $cell are reasonable, 
    # i.e. none of the sides has zero length, and none of the angles
    # is out of range.
    # Returns an error message if anything was out of range, otherwise
    # nothing.
    #
    proc pbc_check_cell { cell } {
	foreach { a b c alpha beta gamma } $cell {}
	if { $a < 1.0e-10 || $b < 1.0e-10 || $c < 1.0e-10 } then {
	    error "Suspicious pbc side length (a=$a b=$b c=$c). Have you forgotten to set the pbc parameters?"
	}
	if { [expr $alpha < 1.0e-10 || $alpha > 179.999 \
		  || $beta < 1.0e-10 || $beta > 179.999 \
		  || $gamma < 1.0e-10 || $gamma > 179.999 ] } then {
	    error "Suspicious pbc angle (alpha=$alpha beta=$beta gamma=$gamma)."
	} 
	return;
    }

    ###################################################################
    #
    # Internal helper procedures
    #
    # Computes the angle between two vectors x and y
    proc vecangle {x y} {
	if {[llength $x] != [llength $y]} {
	    error "vecangle needs arrays of the same size: $x : $y"
	}
	if {[llength $x]==0 || [llength $y]==0} {
	    error "vecangle: zero length vector: [llength $x] : [llength $y]"
	}
	# Compute scalar-produt
	set dot 0
	foreach t1 $x t2 $y {
	    set dot [expr $dot + $t1 * $t2]
	}
	set rr [rad2deg [expr (acos($dot/([veclength $x] * [veclength $y])))]]
	
	return $rr
    }

    # Transforms degrees to radians and back 
    proc deg2rad { deg } {
	return [expr ($deg/180.0*3.14159265)]
    }

    proc rad2deg { rad } {
	return [expr ($rad/3.14159265)*180.0]
    }
}
