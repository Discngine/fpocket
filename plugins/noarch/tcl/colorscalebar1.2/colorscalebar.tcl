## NAME: color_scale_bar
## 
## $Id: colorscalebar.tcl,v 1.18 2006/08/17 19:46:14 johns Exp $
##
## SYNOPSIS:
##   color_scale_bar draws a color bar on the screen to show all of the
##   current colors. It also shows labels beside the 
##   color bar to show the range of the mapped values.
##
## VERSION: 3.0
##    Uses VMD version:  VMD Version 1.8.5 or greater
## 
## PROCEDURES:
##    color_scale bar
## 
## DESCRIPTION:
##    To draw a color scale bar with length=1.5, width=0.25, the range of
##    mapped values is 0~128, and you want 8 labels.
##    color_scale_bar 1.5  0.25  0  128 8
## 
## COMMENTS: The size of the bar also depends on the zoom scale.
## 
## AUTHOR:
##    Wuwei Liang (gtg088c@prism.gatech.edu)
##
##    New version 2 built on Wuwei Liang's code, by Dan Wright 
##                  <dtwright@uiuc.edu>
## 
##    Plugin-ized version by John Stone
##    Various subsequent bug fixes by John Stone
##

# This function draws a color bar to show the color scale
# length = the length of the color bar
# width = the width of the color bar
# min = the minimum value to be mapped
# max = the maximum mapped value
# label_num = the number of labels to be displayed

package provide colorscalebar 1.2

namespace eval ::ColorScaleBar:: {
  namespace export color_scale_bar delete_color_scale_bar
  variable w
  variable bar_mol          -1
  variable lengthsetting    0.8
  variable widthsetting     0.05
  variable autoscale        0
  variable fixedsetting     1
  variable minvalue         0
  variable maxvalue         100
  variable axislabels       5
  variable textcolor        white
  variable fpformat         1      # 0=decimal, 1=scientific
}

proc ::ColorScaleBar::color_scale_bar {{length 0.5} {width 0.05} {auto_scale 1} {fixed 1} {min 0} {max 100} {label_num 5} {text 16} {fp_format 0} {x_pos -1.0} {y_pos -1.0} {replacebar 1}} {
  variable bar_mol

  # if there's already a color scale bar molecule, delete and replace it
  if {$replacebar == 1} {
    delete_color_scale_bar
  }

  # So that the draw cmds will work right, must save top mol and set top
  # to our new created mol, then set it back later.
  set old_top [molinfo top]
  if { $old_top == -1 } {
    puts "Color Scale Bar Plugin: No molecules loaded"
    return -1;
  }

  # don't update the display while we do this since otherwise there
  # will be thousands of individual draw commands going on 
  display update off
  display resetview

  # If auto_scale was requested, go through all the mols and find the min/max
  # scale ranges for setting the bar.
  if {$auto_scale == 1} {
    set min  999999
    set max -999999
    foreach m [molinfo list] {
      if {$m != $bar_mol && [string compare [molinfo $m get name] "{Color Scale Bar}"] != 0} {
        if { [catch {set minmax [split [mol scaleminmax $m 0]]}] } {
          continue
        }

        if {$min > [lindex $minmax 0]} {
          set min [lindex $minmax 0]
        }
        if {$max < [lindex $minmax 1]} {
          set max [lindex $minmax 1]
        }
      }
    }
  }

  # check for situation where all mols were skipped by the catch statement
  if { $min > $max } {
    set min 0
    set max 0
  }

  # Create a seperate molid to draw in, so it's possible for the user to 
  # delete the bar.
  set bar_mol [mol new]
  mol top $bar_mol
  mol rename top "Color Scale Bar"

  # If a fixed bar was requested...
  if {$fixed == 1} {
    mol fix $bar_mol
  }

  # set position relative to top molecule 
  # We want to draw relative to the location of the top mol so that the bar 
  # will always show up nicely.
  #set center [molinfo $old_top get center]
  #set center [regsub -all {[{}]} $center ""]
  #set center [split $center]
  #set start_y [expr [lindex $center 1] - (0.5 * $length)]
  #set use_x [expr 1+[lindex $center 0]]
  #set use_z [lindex $center 2]

  # set in absolute screen position
  set start_y [expr (-0.5 * $length) + $y_pos]
  set use_x $x_pos
  set use_z 0

  # draw background border behind bar, same color as text
  draw color $text

  # disable material properties for the color scale bar background
  # so that it looks truly black (no specular) when it's set black
  set bw [expr $width * 0.05]
  set lx [expr $use_x             - $bw]
  set rx [expr $use_x   + $width  + $bw] 
  set ly [expr $start_y           - $bw]
  set uy [expr $start_y + $length + $bw]
  set bz [expr $use_z - 0.00001]
  
  draw line "$lx $ly $bz" "$lx $uy $bz" width 2
  draw line "$lx $uy $bz" "$rx $uy $bz" width 2
  draw line "$rx $uy $bz" "$rx $ly $bz" width 2
  draw line "$rx $ly $bz" "$lx $ly $bz" width 2

  # draw the color bar
  set mincolorid [colorinfo num] 
  set maxcolorid [expr [colorinfo max] - 1]
  set numscaleids [expr $maxcolorid - $mincolorid]
  set step [expr $length / double($numscaleids)]
  for {set colorid $mincolorid } { $colorid <= $maxcolorid } {incr colorid 1 } {
    draw color $colorid
    set cur_y [ expr $start_y + ($colorid - $mincolorid) * $step ]
    draw line "$use_x $cur_y $use_z"  "[expr $use_x+$width] $cur_y $use_z"
  }

  # draw the labels
  set coord_x [expr (1.2*$width)+$use_x];
  set step_size [expr $length / $label_num]
  set color_step [expr double($numscaleids)/$label_num]
  set value_step [expr ($max - $min ) / double ($label_num)]
  for {set i 0} {$i <= $label_num } { incr i 1} {
    draw color $text
    set coord_y [expr $start_y+$i * $step_size ]
    set cur_text [expr $min + $i * $value_step ]

    set labeltxt ""
    if { $fp_format == 0 } {
      # format the string in decimal notation
      # we save a spot for a leading '-' sign
      set labeltxt [format "% 7.2f"  $cur_text]
    } else {
      # format the string in scientific notation
      # we save a spot for a leading '-' sign
      # since there are only 1024 distinct colors, there's no point in 
      # displaying more than 3 decimal places after the decimal point
      set labeltxt [format "% #.3e"  $cur_text]
    }
    draw text  "$coord_x $coord_y $use_z" "$labeltxt"
    draw line "[expr $use_x+$width] $coord_y $use_z" "[expr $use_x+(1.45*$width)] $coord_y $use_z" width 2
  }

  # re-set top
  if { $old_top != -1 } {
    mol top $old_top
  }
  display update on

  return 0
}

# if there's a color scale bar molecule, delete and replace it
proc ::ColorScaleBar::delete_color_scale_bar { } {
  variable bar_mol

  foreach m [molinfo list] {
    if {$m == $bar_mol || [string compare [molinfo $m get name] "{Color Scale Bar}"] == 0} {
      mol delete $m
    }
  }

  # invalidate bar_mol
  set bar_mol -1
}


proc ::ColorScaleBar::gui { } {
  variable w
  variable lengthsetting
  variable widthsetting
  variable minvalue
  variable maxvalue
  variable axislabels
  variable textcolor
  variable fpformat

  # If already initialized, just turn on
  if { [winfo exists .colorscalebargui] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".colorscalebargui"]
  wm title $w "Color Scale Bar"
  wm resizable $w 0 0

  ##
  ## make the menu bar
  ##
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x
  menubutton $w.menubar.help -text "Help   " -underline 0 -menu $w.menubar.help.menu

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/colorscalebar"
  pack $w.menubar.help

  frame $w.length
  label $w.length.label -text "Bar length"
  entry $w.length.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::ColorScaleBar::lengthsetting
  pack $w.length.label $w.length.entry -side left -anchor w

  frame $w.width
  label $w.width.label -text "Bar width"
  entry $w.width.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::ColorScaleBar::widthsetting
  pack $w.width.label $w.width.entry -side left -anchor w

  frame $w.autoscale  
  label $w.autoscale.label -text "Autoscale"
  radiobutton $w.autoscale.off -text "Off" -value "0" \
    -variable "::ColorScaleBar::autoscale"
  radiobutton $w.autoscale.on  -text "On"  -value "1" \
    -variable "::ColorScaleBar::autoscale"
  pack $w.autoscale.label $w.autoscale.off $w.autoscale.on \
    -side left -anchor w

  frame $w.minvalue
  label $w.minvalue.label -text "Minimum scale value"
  entry $w.minvalue.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::ColorScaleBar::minvalue
  pack $w.minvalue.label $w.minvalue.entry -side left -anchor w

  frame $w.maxvalue
  label $w.maxvalue.label -text "Maximum scale value"
  entry $w.maxvalue.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::ColorScaleBar::maxvalue
  pack $w.maxvalue.label $w.maxvalue.entry -side left -anchor w

  frame $w.axislabels
  label $w.axislabels.label -text "Number of axis labels"
  entry $w.axislabels.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::ColorScaleBar::axislabels
  pack $w.axislabels.label $w.axislabels.entry -side left -anchor w

  frame $w.textcolor
  label $w.textcolor.label -text "Color of labels"
  tk_optionMenu $w.textcolor.chooser ::ColorScaleBar::textcolor \
    "blue" \
    "red" \
    "gray" \
    "orange" \
    "yellow" \
    "tan" \
    "silver" \
    "green" \
    "white" \
    "pink" \
    "cyan" \
    "purple" \
    "lime" \
    "mauve" \
    "ochre" \
    "iceblue" \
    "black" 
  pack $w.textcolor.label $w.textcolor.chooser -side left -anchor w

  frame $w.labelformat
  label $w.labelformat.label -text "Label format"
  radiobutton $w.labelformat.decimal -text "Decimal" -value "0" \
    -variable "::ColorScaleBar::fpformat"
  radiobutton $w.labelformat.scientific -text "Scientific" -value "1" \
    -variable "::ColorScaleBar::fpformat"
  pack $w.labelformat.label $w.labelformat.decimal $w.labelformat.scientific \
    -side left -anchor w

  button $w.drawcolorscale -text "Draw Color Scale Bar" \
    -command { 
      if { [::ColorScaleBar::color_scale_bar $::ColorScaleBar::lengthsetting $::ColorScaleBar::widthsetting $::ColorScaleBar::autoscale $::ColorScaleBar::fixedsetting $::ColorScaleBar::minvalue $::ColorScaleBar::maxvalue $::ColorScaleBar::axislabels $::ColorScaleBar::textcolor $::ColorScaleBar::fpformat] == -1 } { 
        tk_dialog .errmsg "Color Scale Bar Error" "Color Scale Bar Plugin: No molecules loaded" error 0 Dismiss
      }
    }
  button $w.delcolorscale -text "Delete Color Scale Bar" \
    -command ::ColorScaleBar::delete_color_scale_bar 

  pack $w.menubar $w.length $w.width \
    $w.autoscale $w.minvalue $w.maxvalue \
    $w.axislabels $w.textcolor $w.labelformat \
    $w.drawcolorscale $w.delcolorscale -anchor w -fill x 

  return $w
}

proc colorscalebar_tk_cb { } {
  ::ColorScaleBar::gui
  return $::ColorScaleBar::w
}

