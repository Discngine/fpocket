# Fantastic Voyage plugin
# Authors: Jordi Cohen (jordi@ks.uiuc.edu) Paul R. McCreary (paul.mccreary@gmail.com)
#
# PMcC revisions 
# 3/2/06
# rotations governed by mouse (cursor) position in main window
# can modify parameters dt/dr by key presses or by typing entry in GUI window.
# ????Gui text????
#  Included tcl text page references for various tcl commands.
# Note that references are to pages in Practical Programming in Tcl and Tk 
# by Brent B. Welch, Prentice Hall, 1995

# $Id: navfly.tcl,v 1.2 2006/06/13 21:11:38 johns Exp $
#
# This scripts allows you to rotate the scene around the
# camera, allowing you to "turn your head". It work very well 
# for exploring large MSMS cavities, etc.
#
# Keep as comments the "vernier" adjustments by key presses, as follows
# i,k,j,l for rotations up/down/left/right and q,a for forward/backwards.

package provide navfly 1.0

namespace eval NavFly {
  # window
  variable w                         ;# handle to main window

  variable dt  3.0     ;# translation increment     
  variable dr  3.0       ;# rotation increment 
  variable fly 0	;# fly mode flag
  variable paws 1	;# pause flag
  variable directT 1 ;#direction of flight
  variable thrust 0 ;# thrust flag
  variable dx .01		;# rotation variable: how much to rotate about the y-axis
  variable dy .01		;# rotation variable: how much to rotate about the x-axis
}

##
## Main routine
## Create the window and initialize data structures
##
proc navfly_tk_cb {} {
  ::NavFly::navfly

  ::NavFly::constant_rotation; 

  return $::NavFly::w
}

proc ::NavFly::constant_rotation {} {
  variable paws
  variable fly
  variable thrust
  # whenever idle, unless paused, fly or turn, depending on fly-flag
  if {$paws==0} { 
    if {$fly==0} {
      do_rotations
    } else {
      do_flight_rotation
    } 
  }
  if {$thrust>0} {
     do_apply_thrust
  }
  display update
  after idle [list after 10 NavFly::constant_rotation]
}

proc ::NavFly::navfly {} {
  variable w
  variable dr
  variable dt
  variable fly
  variable paws
  variable directT
  variable thrust
  variable dx 		
  variable dy 		

  bind_keys

  # set near clipping plane as close to the eye/screen as possible
  display nearclip set 0.010000

  # If already initialized, just turn on
  if [winfo exists .navfly] {	#winfo command: p 314
    wm deiconify .navfly	;#wm (window manager) command: p 309; deiconify: p312
    raise .navfly		;#raise (in stacking order) p 131 
    return
  }

  # Initialize window ############################################
  set w [toplevel .navfly]		;#toplevel: ??
  wm title $w "Flying Camera Navigator" 	;#title: p310
  wm resizable $w 0 0			;#resizable: ??


  # Status Frame
  frame $w.info 			;#frame (one of 5 Tk widgets): p171
					#label (one of 5 Tk widgets): p171   #justify: p301
  label $w.info.descr -text \
  "Camera Navigator allows you to move the camera\nas if it were a spaceship, controlling with\nthe keyboard and mouse buttons.\nYou may wish to operate in perspective mode:" -justify left
  button $w.info.perspective -text "Set Perspective Mode" -command "display projection perspective\n"
  pack $w.info.descr $w.info.perspective -side top -expand 1 -padx 4 -pady 4
    

 # Navigation Settings
  labelframe $w.keys -bd 1  -text "Navigation Keys"

  label $w.keys.pawslabel -text  "(p)ause" -justify left
  label $w.keys.paws -textvariable ::NavFly::paws -width 3
  pack $w.keys.pawslabel $w.keys.paws -side left -padx 2 -pady 4

  label $w.keys.flylabel -text  "(f)ly" -justify center
  label $w.keys.fly -textvariable ::NavFly::fly -width 3
  pack $w.keys.flylabel $w.keys.fly -side left -padx 2 -pady 4

  label $w.keys.mausbutlabel -text  "(mouse buttons)" -justify center
  label $w.keys.thrust -textvariable ::NavFly::thrust -width 3
  pack $w.keys.mausbutlabel $w.keys.thrust -side left -padx 2 -pady 4
  
  label $w.keys.directlabel -text  "(d)irection:fore-back" -justify center
  label $w.keys.directT -textvariable ::NavFly::directT -width 3
  pack $w.keys.directlabel $w.keys.directT -side left -padx 2 -pady 4

  # Speed Settings
  labelframe $w.speed -bd 1  -text "Speed Controls"

  label $w.speed.dtlabel -text "     (s)peed:"
  entry $w.speed.dt -textvariable ::NavFly::dt -width 6
  label $w.speed.drlabel -text "     (r)otation:"
  entry $w.speed.dr -textvariable ::NavFly::dr -width 6
 
  pack $w.speed.dtlabel $w.speed.dt -side left -padx 4 -pady 6
  pack $w.speed.drlabel $w.speed.dr -side left -padx 4 -pady 6

  pack $w.info  $w.keys $w.speed  -fill x -expand 1 -padx 6 -pady 6  

}
#######
#######
#######
proc ::NavFly::do_mouse_pos_client { args } {
  variable dx
  variable dy
  variable thrust
  global vmd_mouse_pos

  set dx [lindex $vmd_mouse_pos 0]
  set dy [lindex $vmd_mouse_pos 1]
  set thrust [lindex $vmd_mouse_pos 2]

  set dx [expr $dx - 0.5]
  set dy [expr -($dy - 0.5)]

#  puts "mouse position: $dx $dy"
#  puts "mouse button: $thrust"
}

proc ::NavFly::mouseposon {} { 
  global vmd_mouse_pos
  trace add variable vmd_mouse_pos write ::NavFly::do_mouse_pos_client
  mouse mode userpoint

  puts "mouse mode userpoint..."
}

proc ::NavFly::mouseposoff {} { 
  global vmd_mouse_pos
  mouse mode rotate
  trace remove variable vmd_mouse_pos write ::NavFly::do_mouse_pos_client

  puts "mouse mode rotate..."
}


proc ::NavFly::do_flight_rotation {} {
  variable dx
  variable dy
  variable dr

  #includes moving rotation center to origin and then back
  NavFly::rotate_ship [transaxis y $dx*$dr] 
  NavFly::rotate_ship [transaxis x $dy*$dr] 
}

proc ::NavFly::do_rotations {} {
  variable dx
  variable dy
  variable dr

  NavFly::rotate_ship_wo_trans [transaxis y $dx*$dr] 
  NavFly::rotate_ship_wo_trans [transaxis x $dy*$dr] 
}

proc ::NavFly::do_apply_thrust {} {
  variable dt
  variable directT
  variable thrust
  if {$thrust == 1} { 
		NavFly::translate_ship [transoffset [list 0 0  [expr $dt*$directT*.01]]]
	} else { 
		NavFly::translate_ship [transoffset [list 0 0  [expr $dt*$directT*-.01]]] 
   } 
}

proc ::NavFly::transadd {A B} {
  set C {}
  foreach vA $A vB $B {
    lappend  C [vecadd $vA $vB]
  }
  return $C
}

proc ::NavFly::transsub {A B} {
  set C {}
  foreach vA $A vB $B {
    lappend  C [vecsub $vA $vB]
  }
  return $C
}


# r is a rotation matrix, which will be applied to the camera's 
# coordinate frame
proc ::NavFly::rotate_ship {r} {
  if { [molinfo num] < 1 } {
    return;
  }

  set t [transoffset {0 0 -2}]
  set R [lindex [molinfo top get rotate_matrix] 0]
  set T [lindex [molinfo top get global_matrix ] 0]
  set it [measure inverse $t]

  set R [transmult $r $R]
  set T [transmult $r $t $T]
  set T [transadd [transidentity] $T]
  set T [transsub $T $r]
  set T [transmult $it $T]

  foreach mol [molinfo list] {
    molinfo $mol set rotate_matrix [list $R]
    molinfo $mol set global_matrix [list $T]
  }
}

# r is a rotation matrix, which will be applied to the camera's 
# coordinate frame
proc ::NavFly::rotate_ship_wo_trans {r} {
  if { [molinfo num] < 1 } {
    return;
  }

  set R [lindex [molinfo top get rotate_matrix] 0]
  set R [transmult $r $R]

  foreach mol [molinfo list] {
    molinfo $mol set rotate_matrix [list $R]
  }
}

# M is a translation matrix, which will be applied to the camera's 
# coordinate frame
proc ::NavFly::translate_ship {M} {
  if { [molinfo num] < 1 } {
    return;
  }

  set T [lindex [molinfo top get global_matrix] 0]
  set T [transmult $M $T]
  
  foreach mol [molinfo list] {
    molinfo $mol set global_matrix [list $T]
  }
}

proc ::NavFly::turn_on_flying {} {
  variable paws
  set paws 0
  mouseposon 
}

proc ::NavFly::turn_off_flying {} {
  variable paws
  set paws 1
  mouseposoff 
}

#Key bindings
proc ::NavFly::bind_keys {} {
  
## Toggles for the fly and pause flags
  user add key f { if {$::NavFly::fly == 0} {set ::NavFly::fly 1} else {set ::NavFly::fly 0}	}
  user add key p { if {$::NavFly::paws == 1} {::NavFly::turn_on_flying} else {::NavFly::turn_off_flying}	}

## Speed controls: by key press or directly typing new value
  user add Key s { set ::NavFly::dt [expr $::NavFly::dt+0.1] }
  user add key S { set ::NavFly::dt [expr $::NavFly::dt-0.1] }
  user add key r { set ::NavFly::dr [expr $::NavFly::dr+0.1] }
  user add key R { set ::NavFly::dr [expr $::NavFly::dr-0.1] }

## Fake Mouse controls:  q/a will be mouse botton/SHIFT+mouse button.  x/y will be cursor postion.
######## user add key t { if {$::NavFly::thrust == 0} {set ::NavFly::thrust 1} else {set ::NavFly::thrust 0}	}
  user add key d { if {$::NavFly::directT == 1} {set ::NavFly::directT -1} else {set ::NavFly::directT 1}	}

}



# Tech Notes:
# View matrix = T R S C
# R G M iG -> rotates around the REAL Z axis going through origin

## Old key commands 
  #user add key u { NavFly::rotate_ship [transaxis z -$NavFly::dr] }
  #user add key o { NavFly::rotate_ship [transaxis z  $NavFly::dr] }
  #user add key j { NavFly::rotate_ship [transaxis y -$NavFly::dr] }
  #user add key l { NavFly::rotate_ship [transaxis y  $NavFly::dr] }
  #user add key i { NavFly::rotate_ship [transaxis x -$NavFly::dr] }
  #user add key k { NavFly::rotate_ship [transaxis x  $NavFly::dr] }
  #user add key d { NavFly::translate_ship [transoffset [list 0  $NavFly::dr 0]] }
  #user add key c { NavFly::translate_ship [transoffset [list 0 -$NavFly::dr 0]] }
  #user add key e { NavFly::translate_ship [transoffset [list  $NavFly::dr 0 0]] }
  #user add key r { NavFly::translate_ship [transoffset [list -$NavFly::dr 0 0]] }

## Development:
#  user add key r { ::NavFly::print_view }

#proc ::NavFly::print_view {} {
#  puts "T = [lindex [molinfo top get global_matrix ] 0]"
#}

#proc print_view{} {
#  puts "C = [lindex [molinfo top get center_matrix] 0]"
#  puts "R = [lindex [molinfo top get rotate_matrix] 0]"
#  puts "S = [lindex [molinfo top get scale_matrix ] 0]"
#  puts "T = [lindex [molinfo top get global_matrix ] 0]"
#}


