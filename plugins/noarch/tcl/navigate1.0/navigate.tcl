# Fantastic Voyage plugin
# Author: Jordi Cohen (jordi@ks.uiuc.edu)
#
# $Id: navigate.tcl,v 1.6 2005/07/20 15:24:18 johns Exp $
#
# This scripts allows you to rotate the scene  around the
# camera, allowing you to "turn your head". It work very well 
# for exploring large MSMS cavities, etc.
#
# The key mappings can easily be changed. Right now i,k,j,l for
# rotations up/down/left/right and q,a for forward/backwards.
#

package provide navigate 1.0

namespace eval Navigate {
  # window
  variable w                         ;# handle to main window

  variable dt  3.0     ;# rotation increment     
  variable dr  3.0       ;# translation increment 
}

##
## Main routine
## Create the window and initialize data structures
##
proc navigate_tk_cb {} {
  Navigate::navigate
  return $Navigate::w
}

proc Navigate::navigate {} {
  variable w
  variable dr
  variable dt

  bind_keys

  # If already initialized, just turn on
  if [winfo exists .navigate] {
    wm deiconify .navigate
    raise .navigate
    return
  }

  # Initialize window
  set w [toplevel .navigate]
  wm title $w "Camera Navigator" 
  wm resizable $w 0 0


  # Status Frame
  frame $w.info 

  label $w.info.descr -text \
  "Camera Navigator allows you to move the camera\nas if it were a spaceship, using the keyboard.\nThis only works properly in perspective mode:" -justify left
  button $w.info.perspective -text "Set Perspective Mode" -command "display projection perspective\n"
  pack $w.info.descr $w.info.perspective -side top -expand 1 -padx 4 -pady 4
    

 # Speed Settings
  labelframe $w.keys -bd 1  -text "Navigation Keys"

 label $w.keys.text -text  "Q/A:\tthrust forward/backward\nJ/L:\trotate sideways left/right\nI/K:\trotate up/down\nU/O:\troll left/right" -justify left

  pack $w.keys.text -side left -padx 8 -pady 6


    
  # Speed Settings
  labelframe $w.speed -bd 1  -text "Speed Controls"

  label $w.speed.dtlabel -text "     thrust:"
  entry $w.speed.dt -textvariable Navigate::dt -width 6
  label $w.speed.drlabel -text "     rotation:"
  entry $w.speed.dr -textvariable Navigate::dr -width 6

  pack $w.speed.dtlabel $w.speed.dt -side left -padx 4 -pady 6
  pack $w.speed.drlabel $w.speed.dr -side left -padx 4 -pady 6
  
  pack $w.info  $w.keys $w.speed  -fill x -padx 6 -pady 6  -expand 1
}

proc Navigate::transadd {A B} {
  set C {}
  foreach vA $A vB $B {
    lappend  C [vecadd $vA $vB]
  }
  return $C
}

proc Navigate::transsub {A B} {
  set C {}
  foreach vA $A vB $B {
    lappend  C [vecsub $vA $vB]
  }
  return $C
}


# r is a rotation matrix, which will be applied to the camera's 
# coordinate frame
proc Navigate::rotate_ship {r} {
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

# M is a translation matrix, which will be applied to the camera's 
# coordinate frame
proc Navigate::translate_ship {M} {
  set T [lindex [molinfo top get global_matrix] 0]
  set T [transmult $M $T]
  
  foreach mol [molinfo list] {
    molinfo $mol set global_matrix [list $T]
  }
}

#Key bindings
proc Navigate::bind_keys {} {
  user add key u { Navigate::rotate_ship [transaxis z -$Navigate::dr] }
  user add key o { Navigate::rotate_ship [transaxis z  $Navigate::dr] }
  user add key j { Navigate::rotate_ship [transaxis y -$Navigate::dr] }
  user add key l { Navigate::rotate_ship [transaxis y  $Navigate::dr] }
  user add key i { Navigate::rotate_ship [transaxis x -$Navigate::dr] }
  user add key k { Navigate::rotate_ship [transaxis x  $Navigate::dr] }

  user add key q { Navigate::translate_ship [transoffset [list 0 0  [expr $Navigate::dt*0.01]]] }
  user add key a { Navigate::translate_ship [transoffset [list 0 0  [expr $Navigate::dt*-0.01]]] }
  #user add key d { Navigate::translate_ship [transoffset [list 0  $Navigate::dr 0]] }
  #user add key c { Navigate::translate_ship [transoffset [list 0 -$Navigate::dr 0]] }
  #user add key e { Navigate::translate_ship [transoffset [list  $Navigate::dr 0 0]] }
  #user add key r { Navigate::translate_ship [transoffset [list -$Navigate::dr 0 0]] }
}



# Tech Notes:
# View matrix = T R S C
# R G M iG -> rotates around the REAL Z axis going through origin

#proc print_view{} {
#  puts "C = [lindex [molinfo top get center_matrix] 0]"
#  puts "R = [lindex [molinfo top get rotate_matrix] 0]"
#  puts "S = [lindex [molinfo top get scale_matrix ] 0]"
#  puts "T = [lindex [molinfo top get global_matrix ] 0]"
#}

