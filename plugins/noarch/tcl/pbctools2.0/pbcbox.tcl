############################################################
#
#   This file contains procedures to draw a box around the unit cell
# boundaries. The procedures required the VMD unit cell properties to
# be set. Use the procedure pbcset on this behalf.
#
#   This script copies a lot of the ideas and code from Jan Saams
# original pbctools script and Axel Kohlmeiers script 
# vmd_draw_unitcell.
#
# $Id: pbcbox.tcl,v 1.6 2007/07/31 16:06:06 johns Exp $
#

package provide pbctools 2.1

namespace eval ::PBCTools:: {
    namespace export pbc*

    ############################################################
    #
    # pbcbox_draw [OPTIONS...]
    #
    # OPTIONS:
    #   -molid $molid
    #   -parallelepiped|-rectangular
    #   -style lines|dashed|arrows|tubes
    #   -width $w
    #   -resolution $res
    #   -center origin|unitcell|$sel
    #   -shiftcenter $shift 
    #   -shiftcenterrel $shift
    #
    # AUTHORS: Olaf
    #
    proc pbcbox_draw { args } {
	# Set the defaults
	set molid "top"
	set style "lines"
	set rectangular 0
	set center "unitcell"
	set shiftcenter {0 0 0}
	set shiftcenterrel {}
	set width 3
	set resolution 8
	
	# Parse options
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr $argnum + 1]]
	    switch -- $arg {
		"-molid"      { set molid $val; incr argnum }
		"-parallelepiped" { set rectangular 0 }
		"-rectangular" { set rectangular 1 }
		"-center" { set center $val; incr argnum }
		"-shiftcenter" { set shiftcenter $val; incr argnum }
		"-shiftcenterrel" { set shiftcenterrel $val; incr argnum }
		"-style"      { set style $val; incr argnum }
		"-width"      { set width $val; incr argnum }
		"-resolution" { set resolution $val }
		default { error "error: pbcbox: unknown option: $arg" }
	    }
	}

	if { $molid=="top" } then { set molid [ molinfo top ] }

	# get the unit cell data
	set cell [lindex [ pbcget -check -namd -now -molid $molid ] 0]
	set A   [lindex $cell 0]
	set B   [lindex $cell 1]
	set C   [lindex $cell 2]
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
		if { [$centersel num] == 0 } then {
		    puts "Warning: Selection \"$center\" contains no atoms!"
		}
		set minmax [measure minmax $centersel]
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
	# shift the origin in units of the unit cell vectors
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

	if { $rectangular } then {
	    set A [list $Ax 0 0]
	    set B [list 0 $By 0 ]
	    set C [list 0 0 $Cz ]
	}

	# set up cell vertices
	set vert(0) $origin
	set vert(1) [vecadd $origin $A]
	set vert(2) [vecadd $origin $B]
	set vert(3) [vecadd $origin $A $B]
	set vert(4) [vecadd $origin $C]
	set vert(5) [vecadd $origin $A $C]
	set vert(6) [vecadd $origin $B $C]
	set vert(7) [vecadd $origin $A $B $C]

	set gid {}
	switch $style {
	    tubes {
		# set size and radius of spheres and cylinders 
		set srad [expr $width * 0.003 * [veclength [vecadd $A $B $C]]]
		set crad [expr 0.99 * $srad]
		
		# draw spheres into the vertices ...
		for {set i 0} {$i < 8} {incr i} {
		    lappend gid [graphics $molid sphere $vert($i) radius $srad resolution $resolution]
		}
		# ... and connect them with cylinders
		foreach {i j} {0 1  0 2  0 4  1 5  2 3  4 6  1 3  2 6  4 5  7 3  7 5  7 6}  {
		    lappend gid [graphics $molid cylinder $vert($i) $vert($j) radius $crad resolution $resolution]
		}
	    }
	    
	    lines {
		set width [expr int($width + 0.5)]
		foreach {i j} {0 1  0 2  0 4  1 5  2 3  4 6  1 3  2 6  4 5  7 3  7 5  7 6}  {
		    lappend gid [graphics $molid line $vert($i) $vert($j) width $width style solid]
		}
	    }
	    
	    dashed {
		set width [expr int($width + 0.5)]
		foreach {i j} {0 1  0 2  0 4  1 5  2 3  4 6  1 3  2 6  4 5  7 3  7 5  7 6}  {
		    lappend gid [graphics $molid line $vert($i) $vert($j) width $width style dashed]
		}
	    }
	    
	    arrows {
		set rad [expr $width * 0.003 * [veclength [vecadd $A $B $C]]]
		foreach { i j } {0 1  0 2  0 4} {
		    set middle [vecadd $vert($i) [vecscale 0.9 [vecsub $vert($j) $vert($i) ]]] 
		    lappend gid \
			[graphics $molid cylinder $vert($i) $middle \
			     radius $rad resolution $resolution filled yes ] \
			[graphics $molid cone $middle $vert($j) \
			     radius [expr $rad * 2.0] resolution $resolution ]
		}
	    }
	    default { error "pbcbox: unknown box style: $style" }
	    
	}

	return $gid
    }


    ############################################################
    #
    # pbcbox [OPTIONS...]
    #
    # OPTIONS:
    #   -on|off|toggle
    #   -color $color
    # 
    # All options from the pbcbox_draw procedure can be used.
    #
    # AUTHORS: Olaf
    #
    proc pbcbox { args } {
	global vmd_frame
	# namespace variables that save the gids, the args to the pbcbox
	# call, and the color
	variable pbcbox_gids 
	variable pbcbox_color 
	variable pbcbox_args
	variable pbcbox_state
	variable pbcbox_oldparams

	# Set the defaults
	set molid "top"
	set state "on"
	set color "blue"

	# Parse options
	set pass_args ""
	for { set argnum 0 } { $argnum < [llength $args] } { incr argnum } {
	    set arg [ lindex $args $argnum ]
	    set val [ lindex $args [expr $argnum + 1]]
	    switch -- $arg {
		"-molid"      { set molid $val; incr argnum }
		"-color"      { set color $val; incr argnum }
		"-off"        { set state 0 }
		"-on"         { set state 1 }
		"-toggle"     { set state "toggle" }
		default { lappend pass_args $arg }
	    }
	}
	if { $molid == "top" } then { set molid [ molinfo top ] }

	set oldstate [expr [array exists pbcbox_gids] \
			  && [info exists pbcbox_gids($molid)]]

	if { $state == "toggle"} then {
	    set state [expr !$oldstate]
	}

	set pbcbox_color($molid) $color
	set pbcbox_args($molid) "$pass_args"

	if { $oldstate && !$state } then {
	    # turn it off
	    # deactivate tracing
	    trace remove variable vmd_frame($molid) write ::PBCTools::box_update_callback
	    # unset the unit cell parameters
	    array unset pbcbox_oldparams "$molid"
	    # delete the pbcbox
	    box_update_delete $molid
	} elseif { !$oldstate && $state } then {
	    # turn it on
	    # save the unit cell parameters
	    set pbcbox_oldparams($molid) [pbcget -now -check]
	    # draw the box
	    box_update_draw $molid
	    # activate tracing
	    trace add variable vmd_frame($molid) write ::PBCTools::box_update_callback
	} elseif { $oldstate && $state } then {
	    # refresh it
	    box_update_delete $molid
	    box_update_draw $molid
	}
    }


    ############################################################
    #
    # Helper functions required by pbcbox
    #

    # draw the periodic box and save the gids
    proc box_update_draw { molid } {
	variable pbcbox_gids 
	variable pbcbox_args 
	variable pbcbox_color
	graphics $molid color $pbcbox_color($molid)
	if {[catch {set pbcbox_gids($molid) \
			[ eval "::PBCTools::pbcbox_draw -molid $molid $pbcbox_args($molid)" ] \
		    } errMsg] == 1 } then {
	    array unset pbcbox_gids $molid
	    error $errMsg
	}
    }

    # delete the periodic box and remove the gids
    proc box_update_delete { molid } {
	variable pbcbox_gids
	foreach gid $pbcbox_gids($molid) {
	    graphics $molid delete $gid
	}
	array unset pbcbox_gids $molid
    }

    # callback function for vmd_frame, used by "box_update on"
    proc box_update_callback { name1 molid op } {
	variable pbcbox_oldparams
	if { [pbc get -now] != $pbcbox_oldparams($molid) } then {
	    box_update_delete $molid
	    if { [catch { box_update_draw $molid } errMsg] == 1} then {
		# deactivate tracing
		trace remove variable vmd_frame($molid) write ::PBCTools::box_update_callback
		error $errMsg
	    }
	    # save the unit cell parameters
	    set pbcbox_oldparams($molid) $params
	}
    }
}

############################################################
#
# Main namespace function
#
# VMD interface for ::PBCTools::pbcbox_draw (usable via "draw pbcbox")
#
#  vmd_draw_pbcbox $molid [OPTIONS]
#
#      Procedure to be used with the VMD "draw" procedure. All options from 
#    the pbcbox_draw procedure can be used.
#
#   draw delete $box
#   draw pbcbox -width 7
#
# AUTHORS: Olaf 
#

proc vmd_draw_pbcbox { molid args } {
    return [ eval "::PBCTools::pbcbox -molid $molid $args" ]
}

