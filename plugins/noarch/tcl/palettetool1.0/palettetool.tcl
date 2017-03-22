##
## Simple tool for displaying the VMD colors and materials
## as a palette of spheres
##
## John Stone
## $Id: palettetool.tcl,v 1.3 2006/08/17 19:50:05 johns Exp $
##

package provide palettetool 1.0

namespace eval ::PaletteTool:: {
  variable w               ;# window handle
  variable moldispstat ""  ;# store displayed status before hiding
}

proc ::PaletteTool::palettetool {} {
  variable w

  if { [winfo exists ".palettetool"] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".palettetool"]
  wm title $w "Palette Tool"
  wm resizable $w 0 0 

  button $w.colpal -text "Draw Color Palette" -command { ::PaletteTool::drawpalette colors }
  button $w.matpal -text "Draw Material Palette" -command { ::PaletteTool::drawpalette materials }
  button $w.delpal -text "Delete Palette" -command { ::PaletteTool::delpalette }
  pack $w.colpal $w.matpal $w.delpal -side top -fill x -anchor w
}

proc palettetool_tk_cb {} {
  ::PaletteTool::palettetool
  return $::PaletteTool::w
}

proc ::PaletteTool::drawpalette {{tabletype "colors"}} {
  variable moldispstat
  set fgcolor [colorinfo category Display Foreground]

  # turn off all existing molecules and save their views.
  save_viewpoint
  set moldispstat {}
  foreach mol [molinfo list] {
    lappend moldispstat [molinfo $mol get {id drawn}]
    mol off $mol
  }

  # (re-)create dummy molecule to draw into
  foreach m [molinfo list] {
    if {[molinfo $m get name] == "{Color/Material Palette}"} {
       mol delete $m
    }
  }

  set mol [mol new]
  mol rename top {Color/Material Palette}
  if { $tabletype == "colors" } {
    set numviscolors [colorinfo num]
    axes location off
    draw color $fgcolor
    draw text {-2.2 5 0} "VMD Color Palette" size 1.5
    for {set i 0} {$i < $numviscolors} {incr i} {
      set y [expr -($i / 4) + ($numviscolors / 8)]
      set x [expr (($i % 4) - 2) * 1.5]
  
      set textcoord [list [expr $x + 0.3] $y 0]
      set colidstr [format "%2d" $i]
      draw color $fgcolor
      draw text $textcoord "$colidstr"
      set spherecoord [list $x $y 0]
      draw color $i
      draw sphere $spherecoord radius 0.25 resolution 20
    }
  } elseif { $tabletype == "materials" } {
    set matlist [material list]
    set nummaterials [llength $matlist]
    axes location off

    draw color $fgcolor
    set numballs 16
    set tx -6 
    set titley [expr ($nummaterials / 2.0 + 1)]
    draw text "$tx $titley 0" "VMD Material Palette" size 1.5

    set moltop $mol
    set molhalf [expr $nummaterials / 2]
    for {set i 0} {$i < $nummaterials} {incr i} {
      set mol [mol new]
      mol rename top {Color/Material Palette}
      if { $i == $molhalf } {
        set moltop $mol
      }

      set y [expr -$i + ($nummaterials / 2.0)]
      set textcoord [list $tx $y 0]
      set matstr [lindex $matlist $i]
      draw color $fgcolor
      draw text $textcoord "$matstr"
      draw material $matstr
      for {set c 0} {$c < $numballs} {incr c} {
        set x [expr ($c / 2.0) - 1]
        draw color $c
        set spherecoord [list $x $y 0]
        draw sphere $spherecoord radius 0.25 resolution 20
      } 
    }

    # set middle material top, so things look nicer
    mol top $moltop
  }

  display resetview
}

proc ::PaletteTool::delpalette { } {
  variable moldispstat

  set deleted 0
  foreach m [molinfo list] {
    if {[string compare [molinfo $m get name] "{Color/Material Palette}"] == 0} {
      mol delete $m
      set deleted 1
    }
  }

  # no restore if there was non 3d graph.
  if {$deleted == 0 } {
    return
  }
  foreach stat $moldispstat {
    if {[lindex $stat 1]} {
      mol on [lindex $stat 0]
    }
  }
  restore_viewpoint
}


