############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This function draws a color bar to show the color scale
# length = the length of the color bar
# width = the width of the color bar
# min = the minimum value to be mapped
# max = the maximum mapped value
# label_num = the number of labels to be displayed

package provide colorbar 1.0

namespace eval ::ColorBar:: {
  variable bar_mol -1
  variable colorBarState 0
  namespace export drawColorBar deleteColorBar toggleColorBar
}

proc ::ColorBar::init { } {
    
  variable bar_mol
  variable colorBarState
  
  # allocate molecule to be used for the color bar
  if {$bar_mol == -1} {
      set top [molinfo top]
      display resetview
      set bar_mol [mol new]
      if { $top >= 0 } {
        mol top $top
      }
      mol fix $bar_mol
      mol rename $bar_mol "Color scale"
      mol off $bar_mol
    
      # Watch state variable and turn on & off
      trace add variable ::ColorBar::colorBarState write "::ColorBar::dispatchStateChange"
    
      # Redraw when things happen to the coloring
      trace add execution ::SeqEditWidget::setColoring leave "::ColorBar::toggleColorBar"
      trace add execution ::SeqEditWidget::resetColoring leave "::ColorBar::stopColorBar"
  }
}

proc ::ColorBar::destroy { } {
  variable bar_mol

  if {$bar_mol > -1 && [string compare [molinfo $bar_mol get name] "{Color scale}"] == 0 } {
    mol delete $bar_mol
  }
  set bar_mol -1
}

proc ::ColorBar::reinit { } {
  variable bar_mol

  if { $bar_mol != -1 } {
    # Re-set the relative position of the bar so it works
    set top [molinfo top]
    if { $top == $bar_mol && $top != -1} {
      set top [expr $top+1]
    }
    mol delete $bar_mol
    if { $top >= 0 } {
      mol top $top
    }
    display resetview
    set bar_mol [mol new]
    mol fix $bar_mol
    mol rename $bar_mol "Color scale"
    mol off $bar_mol
  
    mol top $top
  }
}
  

proc ::ColorBar::drawColorBar { {length 0.5} {width 0.05} {label_num 3} } {
  variable bar_mol
  variable colorBarState

  # Switch on view of bar_mol, and clear it out before drawing
  mol on $bar_mol
  set top [molinfo top]
  mol top $bar_mol

  display update off
  draw delete all

  # If auto_scale was requested, go through all the loaded sequences
  # and find mix/max for current colormap
  set min 999
  set max -999
  foreach seq [::SeqEditWidget::getSequences] {
    for {set idx 0} {$idx < [::SeqData::getLen $seq]} {incr idx} {
      if {$min > $::SeqEditWidget::coloringMap($seq,$idx,raw)} {
        set min $::SeqEditWidget::coloringMap($seq,$idx,raw)} {
      }
      if {$max < $::SeqEditWidget::coloringMap($seq,$idx,raw)} {
        set max $::SeqEditWidget::coloringMap($seq,$idx,raw)
      }
    }
  }

  # round min/max to nice values
  set intmin [expr int($min*100)]
  set intmax [expr int($max*100)]

  set rnd5min [expr $intmin-($intmin%5)]
  set rnd5max [expr $intmax-($intmax%5)]

  if { $rnd5min > $intmin } { 
    set dispmin [expr double($rnd5min-5)/100.0]
  } else {
    set dispmin [expr double($rnd5min)/100.0]
  }
  if { $rnd5max < $intmax } { 
    set dispmax [expr double($rnd5max+5)/100.0]
  } else {
    set dispmax [expr double($rnd5max)/100.0]
  }

  # draw the color bar
  set start_y [expr (-0.5 * $length)-1.2]
  set use_x -1.0
  set use_z 0

  # get min/max colorid
  set vmdmincolorscaleid [colorinfo num]
  set vmdmaxcolorscaleid [colorinfo max]
  set vmdnumcolorscaleids [expr $vmdmaxcolorscaleid - $vmdmincolorscaleid]
  set vmdclampid [expr $vmdmaxcolorscaleid - 1]

  set step [expr $length / double($vmdnumcolorscaleids)]
  
  set mincolorid [expr int($dispmin*($vmdnumcolorscaleids-1))+$vmdmincolorscaleid]
  set maxcolorid [expr int($dispmax*($vmdnumcolorscaleids-1))+$vmdmincolorscaleid]
  set coloridrange [expr $maxcolorid-$mincolorid]
  set scalefactor [expr double($coloridrange)/double($vmdnumcolorscaleids)]

  for {set i 0} { $i < $vmdnumcolorscaleids} {incr i} {
    set drawcolor [expr int($mincolorid+$scalefactor*$i)]
    if { $drawcolor > $vmdclampid } { set drawcolor $vmdclampid }
    draw color $drawcolor
    set cur_y [ expr $start_y + $i * $step ]
    draw line "$use_x $cur_y $use_z"  "[expr $use_x+$width] $cur_y $use_z"
  }

  # draw the labels
  set coord_x [expr (1.2*$width)+$use_x];
  set step_size [expr $length/($label_num-1)]
  set value_step [expr ($dispmax-$dispmin )/double($label_num-1)]
  
  for {set i 0} {$i < $label_num } { incr i 1} {
    set cur_color_id white
    draw color $cur_color_id
    set coord_y [expr $start_y+$i*$step_size]
    set cur_text [expr $dispmin+$i*$value_step]
    draw text " $coord_x $coord_y $use_z"  "[format %6.2f  $cur_text]"
    draw line "[expr $use_x+$width] $coord_y $use_z" "[expr $use_x+(1.15*$width)] $coord_y $use_z"
  }

  # reset top mol, enable update
  if { $top >= 0 } {
    mol top $top
  }
  display update on
}

proc ::ColorBar::deleteColorBar { } {
  variable bar_mol

  mol off $bar_mol
}

proc ::ColorBar::toggleColorBar { args } {
  variable colorBarState

  # only toggle if it's being drawn
  if { $colorBarState == 1 } {
    deleteColorBar
    drawColorBar
  }
}

proc ::ColorBar::dispatchStateChange { args } {
  variable colorBarState

  if { $colorBarState == 0 } {
    deleteColorBar
  } else {
    drawColorBar
  }
}

proc ::ColorBar::stopColorBar { args } {
  variable colorBarState

  set colorBarState 0
}

