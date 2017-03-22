##
## ClipTool 1.0 
##
## A script to interactively set clipping planes that affect all reps
##
## Authors: Eamon Caddigan, original implementation
##          Jordi Cohen, multi-plane functionality + better GUI
##          vmd@ks.uiuc.edu
##
## $Id: cliptool.tcl,v 1.28 2007/02/19 20:22:57 jordi Exp $
##
## TODO: * Maybe handle reps independently, not sure how this would be
##       presented in the GUI.
##       * Load settings from current set of Molecules when selected mol 
##       is changed. 

##
## Example code to add this plugin to the VMD extensions menu:
##
#  if { [catch {package require cliptool} msg] } {
#    puts "VMD ClipTool package could not be loaded:\n$msg"
#  } elseif { [catch {menu tk register "cliptool" cliptool} msg] } {
#    puts "VMD ClipTool could not be started:\n$msg"
#  }


## Tell Tcl that we're a package and any dependencies we may have
package provide cliptool 1.0

namespace eval ::ClipTool:: {
  namespace export cliptool

  # window handles
  variable w                         ;# handle to main window
  variable scale                     ;# path to the scale widget
  variable normal_entry            ;# list of paths to normal entry boxes
  variable origin_entry            ;# list of paths to origin entry boxes
  variable distance_entry            ;# list of paths to dist entry boxes
  
  # global GUI settings
  variable follow_camera
  variable follow_center

  # what to apply to? (mols/reps)
  variable molselect_options
  variable molselect_text
  variable molselect
    
  # these are used to define the clipping plane
  # It may seem clumsy to use three values (origin, distance, & normal) to
  # define the clipping plane when only two (center & normal or distance
  # from origin & normal) are necessary, but this provides a more intuitive
  # interface.
  if ![info exists arrays_defined] {
    array set clip_on     {0 0 1 0 2 0 3 0 4 0 5 0}    ;# clipping planes is on or off
    array set clip_status {0 1 1 1 2 1 3 1 4 1 5 1}    ;# clipping planes type, currently 1-2
    array set clip_origin {}                           ;# origin (!center) of clipping plane
    array set clip_distance {0 0 1 0 2 0 3 0 4 0 5 0}  ;# distance from origin to clip center
    array set clip_normal {}                           ;# clipping plane normal
    set arrays_defined 1
  }

  # callback variables; these may someday be handled in VMD, but for now
  # they're set in the logfile callback.
  variable vmd_initialize_rep
  variable vmd_transform
  variable vmd_top_mol 0
  
  variable whichclip
  variable oldclip
  variable oldmol 0
  set maxclips 6
}


##
## Main routine
## Create the window and initialize data structures
##
proc ::ClipTool::cliptool {} {
  variable w
  variable scale
  variable normal_entry
  variable origin_entry
  variable distance_entry
  variable follow_camera
  variable follow_center
  variable molselect_options
  variable molselect_text
  variable molselect
  variable clip_on
  variable clip_status
  variable clip_origin
  variable clip_distance
  variable clip_normal
  variable whichclip
  variable oldclip
  variable maxclips
  variable molclips
  variable oldmol
  
  # If already initialized, just turn on
  if { [winfo exists .cliptool] } {
    wm deiconify $w
    return
  }

  # Initialize variables
  set w {}
  set scale {}
  
  set whichclip 0
  set oldclip 0
  
  set follow_camera 1
  set follow_center 1
  
  set molselect_options {"All Molecules" "Active Molecules" "Top Molecule"}
  set molselect_text [lindex $molselect_options 2]
  set molselect 2
  
  set clip_status_options {"Off" "Hollow" "Solid"}
  set clip_status_text [lindex $clip_status_options 0]

  set mol_center [center]
  for {set i 0} {$i < $maxclips} {incr i} {
    set clip_origin($i) $mol_center
  }
 
  set clip_normal($whichclip) {0 0 -1} ;# eye_vector needs this to be defined
  set eye_vector [eye_vector]
  for {set i 0} {$i < $maxclips} {incr i} {
    set clip_normal($i) $eye_vector
  }
  
  retrieve_clip_planes [molinfo top]
  set oldmol [molinfo top]
  
  # Initialize clipplanes
  update_clipplane

  set scale_max [max_atom_dist]

  # Set up traces
  trace add variable ::vmd_initialize_structure write ::ClipTool::mol_cb
  trace add variable ::vmd_logfile write ::ClipTool::logfile_cb
  trace add variable ::ClipTool::vmd_transform write ::ClipTool::rotate_cb
  trace add variable ::ClipTool::vmd_initialize_rep write ::ClipTool::rep_cb
  trace add variable ::ClipTool::clip_status_text write ::ClipTool::status_cb
  trace add variable ::ClipTool::vmd_top_mol write ::ClipTool::changemol_cb
  
  
  set w [toplevel ".cliptool"]
  wm title $w "Clip Tool" 
  wm resizable $w yes no

  # Cleanup traces when the plugin is destroyed
  bind $w <Destroy> {+trace remove variable \
    ::vmd_initialize_structure write ::ClipTool::mol_cb}
  bind $w <Destroy> {+trace remove variable \
    ::vmd_logfile write ::ClipTool::logfile_cb}
  bind $w <Destroy> {+trace remove variable \
    ::ClipTool::vmd_transform write ::ClipTool::rotate_cb}
  bind $w <Destroy> {+trace remove variable \
    ::ClipTool::vmd_initialize_rep write ::ClipTool::rep_cb}
  bind $w <Destroy> {+trace remove variable \
    ::ClipTool::clip_status_text write ::ClipTool::status_cb}
  bind $w <Destroy> {+trace remove variable \
    ::ClipTool::vmd_top_mol write ::ClipTool::changemol_cb}


  set frame $w.moltitle
  frame $frame  
  label $frame.title -text "Changes only apply to the top molecule (ID [molinfo top])"
  pack $frame.title -anchor w 
  pack $frame -expand 1 -fill x -padx 8 -pady 4 -anchor w



  # Clip Plane Switchboard  
  
  set frame $w.switch_title
  frame $frame  
  label $frame.title -text "Active Clipping Planes:" -background darkgrey
  pack $frame.title -anchor w -expand 1 -fill x
  pack $frame -expand 1 -fill x -padx 8 -pady 4

  set frame $w.switchboard
  frame $frame
  for {set i 0} {$i < $maxclips} {incr i} {
    checkbutton $frame.on$i -indicatoron yes -text "$i" -compound none -width 0 -border 1 -variable ::ClipTool::clip_on($i) -command "::ClipTool::activate_clip $i"
    grid $frame.on$i -column [expr $i] -row 3
  }
  pack $frame -side top -expand 1 -fill x -padx 8 -pady 8
  
  
  # Clip Plane Selector
 
  set frame $w.editor
  frame $frame
  label $frame.title -text "Edit Clipping Planes:" -background darkgrey
  pack $frame.title -anchor w -expand 1 -fill x
  pack $frame -expand 1 -fill x -padx 8 -pady 4
  

  set frame $w.clipchoose
  frame $frame
  grid columnconfigure $frame 1 -weight 1
    
  for {set i 0} {$i < $maxclips} {incr i} {
    radiobutton $frame.$i -text $i -indicatoron no -width 3 -variable ::ClipTool::whichclip -value $i -command ::ClipTool::selectclip_cb -border 1
        
    grid $frame.$i  -column [expr $i] -row 0 -sticky nw
  }
  
  
  
  set frame $w.clip
  labelframe $frame -labelwidget $w.clipchoose -relief ridge -bd 2 -labelanchor n
  pack $w.clip -side top -expand 1 -fill x -padx 8 -pady 4


  checkbutton $frame.on -text "Active" -variable ::ClipTool::clip_on($whichclip) -command ::ClipTool::update_clipplane -indicatoron no -height 2 -width 20 -border 1 -activebackground "violetred3"
  pack $frame.on -side top  -padx 4 -pady 4 
  
    
 
  
  set frame $w.clip.contents ;# XXX get rid of this
  frame $frame
  pack $frame -side top -expand 1 -fill x -padx 4 -pady 4
  grid columnconfigure $frame 1 -weight 1
  
  
  label $frame.distlabel -text "Distance:"
  set distance_entry [entry $frame.distentry -textvariable ::ClipTool::clip_distance($whichclip) -width 5 -relief sunken -border 1 -justify center]
  bind $frame.distentry <Return> ::ClipTool::update_clipplane
  set scale [scale $frame.distscale -variable ::ClipTool::clip_distance($whichclip) \
    -from [expr -$scale_max] -to $scale_max \
    -command [list ::ClipTool::update_clipplane -1] -orient horizontal -showvalue 0 -resolution 0.01] 
  grid $frame.distlabel -row 0 -sticky e -pady 4 -padx 2
  grid $frame.distentry -row 0 -column 2 -pady 4 -padx 2
  grid $frame.distscale -sticky ew -column 1 -row 0
  


  label $frame.normallabel -text "Normal:" -justify left
  set normal_entry [entry $frame.normalxyz -textvariable ClipTool::clip_normal($whichclip) -justify center -relief sunken -border 1 -validate focus -vcmd "ClipTool::validate_normal %P %V"]
  bind $normal_entry <Return> "$normal_entry validate"
  button $frame.flip -command ClipTool::flip -text "flip"
  grid $frame.normallabel -row 2 -sticky e -pady 4 -padx 2
  grid $frame.normalxyz   -row 2 -column 1 -pady 4 -padx 2 -sticky ew 
  grid $frame.flip        -row 2 -column 2 -pady 4 -padx 2


  label $frame.origlabel -text "Origin:" -justify left
  set origin_entry [entry $frame.origxyz -textvariable ::ClipTool::clip_origin($whichclip) -justify center -relief sunken -border 1 -validate focus -vcmd "ClipTool::validate_origin %P %V"]
  bind $origin_entry <Return> "$origin_entry validate"
  grid $frame.origlabel -row 3 -sticky e -pady 4 -padx 2
  grid $frame.origxyz   -row 3 -column 1 -pady 4 -padx 2 -sticky ew 
  
  set frame $w.clip.options
  frame $frame
  checkbutton $frame.solid -text "Render as solid color (POV-Ray)" -variable ::ClipTool::clip_status($whichclip) -offvalue 1 -onvalue 2 -command ::ClipTool::update_clipplane
  grid $frame.solid -sticky ew
  grid columnconfigure $frame 1 -weight 1
  pack $frame -side top -expand 1 -fill x -padx 4 -pady 4
  
  
  
  # Settings Frame
   
  set frame $w.settings_title
  frame $frame
  label $frame.title -text "Settings:" -background darkgrey
  pack $frame.title -anchor w -expand 1 -fill x
  pack $frame -expand 1 -fill x -padx 8 -pady 4


#  frame $w.applyto
#  set frame $w.applyto
#  grid columnconfigure $frame 2 -weight 1
#  label $frame.label -text "Apply To:" 
#  grid $frame.label -row 0
#  set molchooser [eval tk_optionMenu $frame.menu ::ClipTool::molselect_text $molselect_options]
#  grid $frame.menu -sticky w -row 0 -column 1
#  pack $frame -side top -expand 1 -fill x -padx 8 -pady 4 
  
  checkbutton $w.usecamera -variable ::ClipTool::follow_camera \
    -command ClipTool::toggle_camera -text "Normal follows view" -indicatoron yes -height 1 -width 26 -anchor nw
  pack $w.usecamera -side top -padx 8 -pady 4 -fill x -expand 1 
 
 
  checkbutton $w.usecenter -variable ::ClipTool::follow_center \
    -command ClipTool::toggle_center -text "Origin follows center" -anchor nw
  pack $w.usecenter -side top -padx 8 -pady 4 -fill x -expand 1


  toggle_camera 1
  toggle_center 1
}


proc ::ClipTool::retrieve_clip_planes { molid } {
  variable clip_on
  variable clip_status
  variable clip_origin
  variable clip_distance
  variable clip_normal
  variable maxclips
  variable molclips
  
  if ![info exists molclips($molid)] {
    set mol_center [center]
    set eye_vector [eye_vector]
  
    set molclips($molid) 1
    
    for {set i 0} {$i < $maxclips} {incr i} {
      set molclips($molid,$i,on) 0             ;# clip on
      set molclips($molid,$i,st) 1             ;# clip status
      set molclips($molid,$i,or) $mol_center   ;# clip origin
      set molclips($molid,$i,di) 0             ;# clip distance
      set molclips($molid,$i,no) $eye_vector   ;# clip normal
    }
  } 
  
  for {set i 0} {$i < $maxclips} {incr i} {
    set clip_on($i)       $molclips($molid,$i,on)    ;# clipping planes is on or off
    set clip_status($i)   $molclips($molid,$i,st)    ;# clipping planes type, currently 1-2
    set clip_origin($i)   $molclips($molid,$i,or)    ;# origin (!center) of clipping plane
    set clip_distance($i) $molclips($molid,$i,di)    ;# distance from origin to clip center
    set clip_normal($i)   $molclips($molid,$i,no)    ;# clipping plane normal
  }
}


proc ::ClipTool::store_clip_planes { molid } {
  variable clip_on
  variable clip_status
  variable clip_origin
  variable clip_distance
  variable clip_normal
  variable maxclips
  variable molclips
  

  for {set i 0} {$i < $maxclips} {incr i} {
    set molclips($molid,$i,on) $clip_on($i)
    set molclips($molid,$i,st) $clip_status($i)
    set molclips($molid,$i,or) $clip_origin($i)
    set molclips($molid,$i,di) $clip_distance($i)
    set molclips($molid,$i,no) $clip_normal($i)
  }
 
}


proc ::ClipTool::activate_clip {clipid} {
  if {$::ClipTool::clip_on($clipid)} {
    set ::ClipTool::whichclip $clipid
    selectclip_cb
  } else {
    ::ClipTool::update_clipplane $clipid
  }
}
 
 
 # Update the clipplane set when the top mol is changed
proc ::ClipTool::changemol_cb { args } {
  variable w
  
  $w.moltitle.title configure -text "Changes only apply to the top molecule (ID [molinfo top])"
  
  variable oldmol
  store_clip_planes $oldmol
  retrieve_clip_planes [molinfo top]
  set oldmol [molinfo top]
}
 
  
  
# Reset the scale and update all clipplanes when a molecule is added or deleted
proc ::ClipTool::mol_cb { args } {
  update_scale
  update_clipplane
}


# No callbacks exist for the changes we're interested in, so we track all
# changes in VMD and create our own callbacks
proc ::ClipTool::logfile_cb { args } {
  global vmd_logfile

  # Check for display transforms
  if { [string match "rotate*" $vmd_logfile] || \
    [string match "translate*" $vmd_logfile] || \
    [string match "scale*" $vmd_logfile] } {
    set ::ClipTool::vmd_transform $vmd_logfile

  # Check if a rep has been created or destroyed
  # Use the faster [string match] before applying the slower [regexp] to get
  # the molid.
  } elseif [string match "mol addrep*" $vmd_logfile] {
    regexp {mol addrep (\d+)} $vmd_logfile match molid
    set ::ClipTool::vmd_initialize_rep($molid) 1
  } elseif [string match "mol delrep*" $vmd_logfile] {
    regexp {mol delrep \d+ (\d+)} $vmd_logfile match molid
    set ::ClipTool::vmd_initialize_rep($molid) 0 
  } elseif [string match "mol top*" $vmd_logfile] {
    regexp {mol top (\d+)} $vmd_logfile match molid
    set ::ClipTool::vmd_top_mol $molid
  }

  # XXX - there should be a callback for changes in the molecule center.
  # Instead, these changes occur only after the normal is moved.
}

# Update the clipplanes when a new rep is created
proc ::ClipTool::rep_cb { args } {
  variable vmd_initialize_rep

  set index [lindex $args 1]

  if { $vmd_initialize_rep($index) } {
    update_clipplane
  }
}

# Follow changes in the molecule's rotation
# XXX - we might want to remove this trace when the center and camera aren't
# being followed. 
proc ::ClipTool::rotate_cb { args } {
  global vmd_logfile
  variable follow_camera

  if { [string match "rotate*" $vmd_logfile] && $follow_camera } {
    update_clipplane
  }
}


# Update the clipplane status when a different menu option is selected
proc ::ClipTool::status_cb { args } {
  variable clip_status_options
  variable clip_status_text
  variable whichclip
 
  set i 0
  foreach option $clip_status_options {
    if {[string match $clip_status_text $option]} {
      set ClipTool::clip_status($whichclip) $i
      set ClipTool::clip_on($whichclip) [expr $i != 0]
      break
    }
    incr i
  }

  update_clipplane
}



# Update when a different clip plane is selected
proc ::ClipTool::selectclip_cb { args } {
  variable clip_status_options
  variable clip_status_text
  variable follow_camera
  variable origin_entry
  variable normal_entry
  variable distance_entry
  variable scale
  variable whichclip
  variable oldclip
  variable w
  
  toggle_camera 0
  
  validate_normal $ClipTool::clip_normal($oldclip) internal $oldclip
  validate_origin $ClipTool::clip_origin($oldclip) internal $oldclip
  
  $w.clip.on configure -variable ::ClipTool::clip_on($whichclip)
  $w.clip.options.solid configure -variable ::ClipTool::clip_status($whichclip)
  $origin_entry configure -textvariable ::ClipTool::clip_origin($whichclip)
  $normal_entry configure -textvariable ::ClipTool::clip_normal($whichclip)
  $distance_entry configure -textvariable ::ClipTool::clip_distance($whichclip)
  $scale configure -variable ::ClipTool::clip_distance($whichclip)
  
  update_clipplane
  
  set oldclip $whichclip
}


proc ::ClipTool::is_vector {v} {
  if {[llength $v] != 3} {return 0}
  foreach elem $v {if ![string is double $elem] {return 0}}
  return 1
}

proc ::ClipTool::validate_normal {v vtype {clipid -1}} {
  variable old_valid_normal
  if {$clipid == -1} {set clipid $ClipTool::whichclip}
  if {"$vtype" == "focusin"} {set old_valid_normal $v; return yes}
  if {![is_vector $v] || ([lindex $v 0] == 0. && [lindex $v 1] == 0. && [lindex $v 2] == 0.)} {
    puts "Invalid value for clipplane normal."
    after idle [list set ClipTool::clip_normal($clipid) $old_valid_normal]
    return no
  }
  update_clipplane
  set old_valid_normal $v
  return yes
}

proc ::ClipTool::validate_origin {v vtype {clipid -1}} {
  variable old_valid_origin
  if {$clipid == -1} {set clipid $ClipTool::whichclip}
  if {"$vtype" == "focusin"} {set old_valid_origin $v; return yes}
  if ![is_vector $v] {
    puts "Invalid value for clipplane normal."
    after idle [list set ClipTool::clip_origin($clipid) $old_valid_origin]
    return no
  }
  update_clipplane
  set old_valid_origin $v
  return yes
}



# find the maximum distance between the clipplane origin and any atom
# XXX - this implementation is pretty lame, and should be improved
proc ::ClipTool::max_atom_dist {} {
  variable clip_origin
  variable molselect
  variable whichclip
  
  set origin $clip_origin($whichclip)

  set minmax {{0 0 0} {0 0 0}}
  foreach mol [molinfo list] {
    if {($molselect == 1) && ![molinfo $mol get active]} continue
    if {($molselect == 2) && ([molinfo top] != $mol)} continue 
    if {[molinfo top get numatoms] == 0} continue

    set sel [atomselect $mol all]
    if {[$sel num] > 0} {
      catch {
        set mol_minmax [measure minmax $sel]
        foreach i {0 1 2} {
          if {[lindex $mol_minmax 0 $i] < [lindex $minmax 0 $i]} {
            lset minmax 0 $i [lindex $mol_minmax 0 $i]
          }
        }
        foreach i {0 1 2} {
          if {[lindex $mol_minmax 1 $i] > [lindex $minmax 1 $i]} {
            lset minmax 1 $i [lindex $mol_minmax 1 $i]
          }
        }
      }
    }
    $sel delete
  }

  set min_dist [veclength [vecsub $origin [lindex $minmax 0]]]
  set max_dist [veclength [vecsub $origin [lindex $minmax 1]]]

  return [expr {($max_dist > $min_dist) ? $max_dist : $min_dist}]
}


proc ::ClipTool::flip {} {
  variable whichclip
  variable clip_normal
  variable clip_distance

  set tmplist {}
  lappend tmplist [expr -[lindex $clip_normal($whichclip) 0]]
  lappend tmplist [expr -[lindex $clip_normal($whichclip) 1]]
  lappend tmplist [expr -[lindex $clip_normal($whichclip) 2]]
  set clip_normal($whichclip) $tmplist
  
  set clip_distance($whichclip) [expr -$clip_distance($whichclip)]
  
  update_clipplane
}


# update the bounds of the scale widget
proc ::ClipTool::update_scale {} {
  variable scale

  set scale_max [max_atom_dist]
  $scale configure -from [expr -$scale_max] -to $scale_max
}

# Update the clipplanes with the current parameters
proc ::ClipTool::update_clipplane { {clipid -1} args } {
  variable follow_camera
  variable follow_center
  variable clip_status
  variable clip_on
  variable clip_origin
  variable clip_distance
  variable clip_normal
    
  variable molselect
  variable molselect_options
  variable molselect_text

  if {$clipid == -1} {set clipid $::ClipTool::whichclip}
    
  set i 0
  foreach option $molselect_options {
    if {[string match $molselect_text $option]} {
      set molselect $i
      break
    }
    incr i
  }
  
  set origin $clip_origin($clipid)

  # Update the clip_origin if it has changed and we're following the center
  if {$follow_center} {
    set mol_center [center]

    if { $origin != $mol_center } {
      set clip_origin($clipid) $mol_center
    }

    set origin $mol_center
    if {$::ClipTool::scale != {}} update_scale
  }

  # Set the clip normal to the eye vector of we're following the camera
  if {$follow_camera} {
    set eye_vector [eye_vector]
    set clip_normal($clipid) $eye_vector
    set normal_vector $eye_vector
  } else {
    set normal_vector [vecnorm $clip_normal($clipid)]
  }

  set clip_center [vecadd \
    $origin \
    [vecscale $clip_distance($clipid) $normal_vector] \
  ]

  # Change the clip plane normal for each rep
  foreach mol [molinfo list] {
    if {($molselect == 1) && ![molinfo $mol get active]} continue
    if {($molselect == 2) && ([molinfo top] != $mol)} continue 
    for {set rep 0} {$rep < [molinfo $mol get numreps]} {incr rep} {
      mol clipplane normal $clipid $rep $mol $normal_vector
      mol clipplane center $clipid $rep $mol $clip_center
      mol clipplane status $clipid $rep $mol [expr $clip_on($clipid)*$clip_status($clipid)]
    }
  }
}

# find the normalized eye vector
proc ::ClipTool::eye_vector {} {
  variable whichclip
  variable clip_normal
  
  if {[molinfo num]} {
    set eye_vector [vectrans \
      [measure inverse [lindex [molinfo top get rotate_matrix] 0]] \
      {0 0 -1}
    ]
    set sign [vecdot $eye_vector $clip_normal($whichclip)]
    if {$sign < 0} {set eye_vector [vecscale -1 $eye_vector]}
  } else {
    set eye_vector {0 0 -1}
  }

  # Round
  set tmp {}
  lappend tmp [expr round([lindex $eye_vector 0]*1000)/1000.]
  lappend tmp [expr round([lindex $eye_vector 1]*1000)/1000.]
  lappend tmp [expr round([lindex $eye_vector 2]*1000)/1000.]
  set eye_vector $tmp
  
  return $eye_vector
}

# find the center of the top molecule 
proc ::ClipTool::center {} {
  if {[molinfo num]} {
    set center [lindex [molinfo top get center] 0]
  } else {
    set center {0 0 0}
  }

  # Round
  set tmp {}
  lappend tmp [expr round([lindex $center 0]*1000)/1000.]
  lappend tmp [expr round([lindex $center 1]*1000)/1000.]
  lappend tmp [expr round([lindex $center 2]*1000)/1000.]
  set center $tmp
  
  return $center
}

# Turn camera following on and off
proc ::ClipTool::toggle_camera {{on -1}} {
  update_clipplane
  variable follow_camera
  variable normal_entry
  if {$on >= 0} {set follow_camera $on}
  
  # Disable/Enable entry widgets
  if {$follow_camera} {
    $normal_entry configure -state readonly -foreground darkgray
  } else {
    $normal_entry configure -state normal -foreground black
  }
}

# Turn center following on and off
proc ::ClipTool::toggle_center {{on -1}} {
  update_clipplane
  variable follow_center
  variable origin_entry
  if {$on > 0} {set follow_center $on}

  # Disable/Enable entry widgets
  if {$follow_center} {
    $origin_entry configure -state readonly -foreground darkgray
  } else {
    $origin_entry configure -state normal -foreground black
  }
}




# This gets called by VMD the first time the menu is opened.
proc cliptool_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::ClipTool::w  }]  ;# destroy any old windows

  ::ClipTool::cliptool   ;# start the ClipTool 
  return $ClipTool::w
}


# Updates the GUI and internal variables to reflect the state 
# of the selected molecule(s)
proc ::ClipTool::import_clip_settings {} {
  # Not Implemented yet
}


proc reset {} {
  destroy .cliptool
  package forget cliptool
  source cliptool.tcl
  ::ClipTool::cliptool
}
