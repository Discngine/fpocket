# Ruler VMD plugin
#
# Author: Jordi Cohen
#
# Implements a tape rule, a grid, or a scale indicator
# 
# usage: ruler [tape|grid|off]

package provide ruler 1.0

namespace eval ::Ruler:: {
  set ruler_unit     1.  ;# base unit of scale
  set ruler_logunit -1   ;# base unit of scale
  set ruler_scale    1.  ;# actual scale of the top molecule
  set ruler_mol     -1   ;# mol in which the drawing is done
  set ruler_dirty    1   ;# recompute the ruler?
    
  set display_width  1.  ;# max x in OpenGL
  set display_height 1.  ;# max y in OpenGL  
  set display_front  1.  ;# max z in OpenGL  
  
  set ruler_color    black  ;# use a dark foreground color? 
  
  set grid_on  0
  set scale_on 0
  set ruler_on 0

  set scale_graphics_id     -1
  set indicator_graphics_id -1
}


proc ::Ruler::setup_ruler {} {
  variable ruler_mol

  if ![catch {molinfo $ruler_mol get name}] {return}
  
  set top [molinfo top]
  set ruler_mol [mol new]
  mol rename $ruler_mol "Ruler"
  if {$top >= 0} {
    mol top $top
    molinfo $ruler_mol set scale_matrix [molinfo $top get scale_matrix]  
  }
  
  reset_colors
  
  trace add variable ::vmd_logfile write ::Ruler::logfile_cb
}


proc ::Ruler::remove_ruler {} {
  variable ruler_mol
  
  trace remove variable ::vmd_logfile write ::Ruler::logfile_cb

  mol delete $ruler_mol
}


proc ::Ruler::reset_colors {} {
  variable ruler_color
  
  if [display get backgroundgradient] {
    set backlight [eval vecadd [colorinfo rgb [color Display BackgroundBot]]]
  } else {
    set backlight [eval vecadd [colorinfo rgb [color Display Background]]]
  }
  if {$backlight <= 1.2} {
    set ruler_color white
  } else {
    set ruler_color black
  }
}


proc ::Ruler::redraw {} {
  variable ruler_mol
  variable ruler_scale
  variable ruler_unit
  variable ruler_logunit
  variable grid_on
  variable ruler_on
  variable scale_on
  variable display_height
  variable display_width
  variable display_front
        
  molinfo $ruler_mol set center_matrix [list [transidentity]]
  molinfo $ruler_mol set rotate_matrix [list [transidentity]]
  molinfo $ruler_mol set global_matrix [list [transidentity]]
  molinfo $ruler_mol set scale_matrix  [molinfo top get scale_matrix]
  
  if $::Ruler::ruler_dirty {
    set ruler_scale [lindex [molinfo $ruler_mol get scale_matrix] 0 0 0]
    set logunit [expr ceil(-log10($ruler_scale))-1]
    set ruler_logunit $logunit
    set ruler_unit [expr pow(10.,$ruler_logunit)]

    set display_height [expr 0.25*[display get height]/$ruler_scale]
    set display_width [expr $display_height*[lindex [display get size] 0]/[lindex [display get size] 1]]
    
    if [string equal [display get projection] "Orthographic"] {
      set display_front [expr (2.-[display get nearclip]-0.001)/$ruler_scale]
    } else {
      set display_front 0.
    }
     
    graphics $ruler_mol delete all
    graphics $ruler_mol material Opaque
    
    if $grid_on  {draw_grid}
    if $scale_on {draw_scale}
    if $ruler_on {draw_ruler}
 
    if {$grid_on || $ruler_on} {draw_indicator}
    
    set ::Ruler::ruler_dirty 0
  }
}


proc ::Ruler::draw_grid {} {
  variable ruler_mol
  variable ruler_unit
  variable display_height
  variable display_width
  variable display_front

  set maxx $display_width  
  set minx [expr -ceil($display_width/(10.*$ruler_unit))*10.*$ruler_unit] 
  set maxy $display_height  
  set miny [expr -ceil($display_height/(10.*$ruler_unit))*10.*$ruler_unit] 
 
  graphics $ruler_mol color gray
  #draw material Transparent
  for {set tick $minx} {$tick <= $maxx} {set tick [expr $tick + $ruler_unit]} {
    graphics $ruler_mol  line "$tick $miny 0." "$tick $maxy 0." width 1 style dashed
  }
  for {set tick $miny} {$tick <= $maxy} {set tick [expr $tick + $ruler_unit]} {
    graphics $ruler_mol  line "$minx $tick 0." "$maxx $tick 0." width 1 style dashed
  }
 
  #draw material Opaque
  for {set tick $minx} {$tick <= $maxx} {set tick [expr $tick + 10.*$ruler_unit]} {
    graphics $ruler_mol line "$tick $miny 0." "$tick $maxy 0." width 2
  }
  for {set tick $miny} {$tick <= $maxy} {set tick [expr $tick + 10.*$ruler_unit]} {
    graphics $ruler_mol  line "$minx $tick 0." "$maxx $tick 0." width 2
  }
}


proc ::Ruler::draw_indicator {} {
  variable ruler_mol
  variable ruler_unit
  variable display_height
  variable display_width
  variable display_front
  
  graphics $ruler_mol color gray
  graphics $ruler_mol text "[expr -0.99*$display_width] [expr -0.97*$display_height] $display_front" "[format "%g" $ruler_unit]A" size 0.8
}


proc ::Ruler::draw_scale {} {
  variable ruler_mol
  variable ruler_unit
  variable display_height
  variable display_width
  variable display_front  

  graphics $ruler_mol color $::Ruler::ruler_color
  graphics $ruler_mol text "[expr -0.9*$display_width] [expr -0.95*$display_height] $display_front" "[format "%g" $ruler_unit] A" size 1.0
  graphics $ruler_mol line "[expr -0.9*$display_width] [expr -0.9*$display_height] $display_front" "[expr -0.9*$display_width+$ruler_unit] [expr -0.9*$display_height] $display_front" width 10
}


proc ::Ruler::draw_ruler {} {
  variable ruler_mol
  variable ruler_unit
  variable ruler_scale
  variable display_height
  variable display_width
  variable display_front
  
  set pixelwidth [expr 2.*$display_height/[lindex [display get size] 0]]
     
  set edgewidth [expr 0.01666*[display get height]/$ruler_scale]
  set edge_x  [expr -$display_width + $edgewidth]
  set edge_xp [expr $edge_x + $pixelwidth]
  set edge_x1 [expr -$display_width + 0.1*$edgewidth]
  set edge_x2 [expr -$display_width + 0.6*$edgewidth]
  set edge_y  [expr -$display_height + $edgewidth]
  set edge_yp [expr $edge_y + $pixelwidth]
  set edge_y1 [expr -$display_height + 0.1*$edgewidth]
  set edge_y2 [expr -$display_height + 0.6*$edgewidth]

  set maxx [expr ceil($display_width/(10.*$ruler_unit))*10.*$ruler_unit]  
  set minx $edge_x
  set maxy [expr ceil($display_height/(10.*$ruler_unit))*10.*$ruler_unit]
  set miny $edge_y

  graphics $ruler_mol color yellow

  graphics $ruler_mol  triangle "-$display_width $display_height $display_front" "$edge_x $display_height $display_front" "-$display_width -$display_height $display_front"
  graphics $ruler_mol  triangle "$edge_x $display_height $display_front" "$edge_x -$display_height $display_front" "-$display_width -$display_height $display_front"
  graphics $ruler_mol  triangle "-$display_width $edge_y $display_front" "$display_width $edge_y $display_front" "-$display_width -$display_height $display_front"
  graphics $ruler_mol  triangle "-$display_width -$display_height $display_front" "$display_width $edge_y $display_front" "$display_width -$display_height $display_front"

  graphics $ruler_mol color white
  graphics $ruler_mol line "$edge_x $display_height $display_front" "$edge_x $edge_y $display_front" width 3
  graphics $ruler_mol line "$edge_x $edge_y $display_front" "$display_width $edge_y $display_front" width 3
  
  graphics $ruler_mol color black
  graphics $ruler_mol line "$edge_xp $display_height $display_front" "$edge_xp $edge_yp $display_front" width 1
  graphics $ruler_mol line "$edge_xp $edge_yp $display_front" "$display_width $edge_yp $display_front" width 1
    
  graphics $ruler_mol color black        
  for {set tick $maxy} {$tick >= $miny} {set tick [expr $tick - 10.*$ruler_unit]} {
    graphics $ruler_mol line "$edge_x1 $tick $display_front" "$edge_xp $tick $display_front" width 2
  }
  for {set tick $maxy} {$tick >= $miny} {set tick [expr $tick - 1.*$ruler_unit]} {
    graphics $ruler_mol line "$edge_x2 $tick $display_front" "$edge_xp $tick $display_front" width 1
  }
  
  for {set tick $maxx} {$tick >= $minx} {set tick [expr $tick - 10.*$ruler_unit]} {
    graphics $ruler_mol line "$tick $edge_y1 $display_front" "$tick $edge_yp $display_front" width 2
  }
  for {set tick $maxx} {$tick >= $minx} {set tick [expr $tick - 1.*$ruler_unit]} {
    graphics $ruler_mol line "$tick $edge_y2 $display_front" "$tick $edge_yp $display_front" width 1
  }
}


proc ::Ruler::logfile_cb { args } {
  # Check for display transforms
  if {[string match "rotate *" $::vmd_logfile] || [string match "translate *" $::vmd_logfile]} { 
    redraw
  } elseif {[string match "scale *" $::vmd_logfile] || [string match "mol top *" $::vmd_logfile]} {
    set ::Ruler::ruler_dirty 1 
    redraw
  } elseif {[string match "color *" $::vmd_logfile] || [string match "display *" $::vmd_logfile]} {
    set ::Ruler::ruler_dirty 1 
    reset_colors
    redraw
  } 
}



proc ::Ruler::show {args} {
  variable ruler_mol
  variable grid_on
  variable ruler_on
  variable scale_on
  
  set overlay [lindex $args 0]
  set state [string is true [lindex $args 1]]
  
  if {"$overlay" == "grid"} {
    set ruler_on 0
    set scale_on 0
    set grid_on $state
  } elseif {"$overlay" == "tape"} {
    set ruler_on 1
    set scale_on 0
    set grid_on  0
  } elseif {"$overlay" == "scale"} {
    set ruler_on 0
    set scale_on 1
    set grid_on  0
  } elseif {"$overlay" == "off"} {
    set ruler_on 0
    set scale_on 0
    set grid_on  0
  } else {
    puts "usage: ruler \[tape|grid|scale|off\]"
    puts "Displays a dynamic ruler for the top molecule."
  }
  
  if {$grid_on || $ruler_on || $scale_on} {
    setup_ruler
    set ::Ruler::ruler_dirty 1
    redraw
  }
  if {!$grid_on && !$ruler_on && !$scale_on} {
    remove_ruler
  } 
}


proc ruler {args} {
  eval ::Ruler::show $args
}

