###########################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################


# A Tcl/Tk plotting window.  
#
# Takes a list of x/y coords for input, and plots them.  Auto-scales to 
# current winsize.  Can output current plot to a PS file.  Can take 
# xmgr-like input files -- list of x/y coords, 1 per line.
#
# Written by Dan Wright (dtwright@uiuc.edu)
#
# Change 1.0 to 1.1: add functions to translate a given plot coord to a canvas
#                    coord (rather then having the calc written out in each
#                    place...)
# Change 1.1 to 1.2: add wtitle arg to plotFiles
#

package provide plotter 1.2

namespace eval ::Plotter:: {
  variable w
  variable defwidth 400
  variable defheight 400
  variable data [list]
  variable dataLabels [list]
  variable colors [list black red green blue]
  variable nDataItems 0

  # Variables for coord-plotting math
  variable xOrigin  
  variable yOrigin 
  variable gXmax
  variable gYmax
  variable Xscale
  variable Yscale
  variable addXscale
  variable addYscale

  variable margins 20
  variable xLabel ""
  variable yLabel ""

  # Export main proc
  namespace export plotFiles plotData plotterNData
}

proc ::Plotter::plotter { } {
  variable w
  variable data
  variable defwidth
  variable defheight

  if { [winfo exists ".plotter"] } {
    # Just clear the window for re-use
    clear
    return
  }
    
  set w [toplevel ".plotter"]

  wm title $w "Simple x/y plot"
  wm minsize $w 300 300
  bind $w <Destroy> "[namespace current]::clear"

  frame $w.top -border 0 -background ""
  canvas $w.top.plot -background white -width $defwidth -height $defheight 
  pack $w.top.plot -fill both -expand 1
  pack $w.top -fill both -expand 1

  frame $w.bottom -background white -width $defwidth -height 50 -border 0
  button $w.bottom.print -command [namespace current]::PSout \
    -text "Save plot to PostScript file"

  pack $w.bottom.print -side left 
  pack $w.bottom -fill x -side bottom 

  bind $w.top.plot <Configure> [namespace current]::drawCanvas
}

proc ::Plotter::readFile { file } {
  # read x/y data from $file 
  if { ! [file exists $file] } {
    puts "Plotter Error) can't open datafile $file"
    return
  }

  set mydata [list]

  set fdata [open $file r]
  while {![eof $fdata]} {
    if {[gets $fdata line] > 0} {
      lappend mydata [split $line]
    }
  }

  close $fdata

  return $mydata
}

proc ::Plotter::addData { newdata label } {
  # Add a set of data points to the plot.  $newdata is a list of 
  # x/y pairs (an x/y pair is a 2-item list of floating-point numbers).
  # Returns the data set number for the newly-added data.
  # Adds a label to the dataLabels list.
  variable data
  variable dataLabels
  variable nDataItems

  incr nDataItems
  lappend data $newdata
  lappend dataLabels $label

  return $nDataItems
}

proc ::Plotter::delData { idx } {
  # Deletes a set of data from the list of data.  idx is the number of
  # the data set; this is the number returned from "addData" when the 
  # set in question was added. Returns the number of data items now held.
  variable data
  variable dataLabels
  variable nDataItems

  if { $idx > $nDataItems } {
    return "value out of range"
  }
  if { $idx < 1 } {
    return "value out of range"
  }
    
  set nDataItems [expr $nDataItems-1]
  set newData [list]
  set newDataLabels [list]
  for {set i 0} {$i <= $nDataItems} {incr i} {
    if { [expr $i+1] != $idx } {
      lappend newData [lindex $data $i]
      lappend newDataLabels [lindex $dataLabels $i]
    }
  }
  set data $newData
  set dataLabels $newDataLabels

  return $nDataItems
}

proc ::Plotter::addDataInFiles { args } {
    # will read data from files in $args and add them to the data-list.
    # sets the label to $file also.
    
    #puts "In addDataInFiles"
    
    foreach file $args {
      addData [readFile $file] [file tail $file]
    }
    
    # Update display.
    drawCanvas
    
    #puts "Out addDataInFiles"

    return
}

proc ::Plotter::drawCanvas { } {
  variable w

  variable xOrigin  
  variable yOrigin 
  variable gXmax
  variable gYmax
  variable Xscale
  variable Yscale
  variable addXscale
  variable addYscale

  variable colors
  variable data
  variable dataLabels
  variable margins
  variable nDataItems
  variable yLabel
  variable xLabel

  #puts "In drawCanvas"

  clearCanvas

  # If there are no data items, do nothing.
  if { $nDataItems < 1 } {
      puts "Plotter Error) No Data"
    return
  }

  # Get the current size of the canvas to set origin, etc.
  # xOrigin always 20 from the left, yOrigin is 20 up from bottom 
  # and therefore depends on current height
  set cursize [winfo geometry $w.top.plot]
  set XY [lindex [split $cursize "+"] 0]
  set curX [lindex [split $XY "x"] 0]
  set curY [lindex [split $XY "x"] 1]
  
  set xOrigin 50
  set yOrigin [expr $curY - 30]

  # Find min/max for each set of data, the find global min/max.
  set xminmaxlist [list]
  set yminmaxlist [list]
    #puts "yo1"
  foreach coords $data {
		# puts $coords
    lappend xminmaxlist [findMinMax $coords x]
    lappend yminmaxlist [findMinMax $coords y]
  }

  set gXmin "unset"
  set gXmax "unset"
    #puts "yo2"
  foreach minmax $xminmaxlist {
    if { $gXmin == "unset" } {
      set gXmin [lindex $minmax 0]
    } else {
      if { $gXmin > [lindex $minmax 0] } {
        set gXmin [lindex $minmax 0]
      }
    }
    if { $gXmax == "unset" } {
      set gXmax [lindex $minmax 1]
    } else {
      if { $gXmax < [lindex $minmax 1] } {
        set gXmax [lindex $minmax 1]
      }
    }
  }
  set gYmin "unset"
  set gYmax "unset"
    #puts "yo3"
  foreach minmax $yminmaxlist {
    if { $gYmin == "unset" } {
      set gYmin [lindex $minmax 0]
    } else {
      if { $gYmin > [lindex $minmax 0] } {
        set gYmin [lindex $minmax 0]
      }
    }
    if { $gYmax == "unset" } {
      set gYmax [lindex $minmax 1]
    } else {
      if { $gYmax < [lindex $minmax 1] } {
        set gYmax [lindex $minmax 1]
      }
    }
  }
  # end find global min/max.

  # Set scaling factors so data always fills the display.
  # we always want the total width/height to be $margins less then the 
  # total canvas area.

  set addXscale 0
  if { $gXmin < 0 } {
    set addXscale [expr $gXmin*-1]
  } 
  set addYscale 0
  if { $gYmin < 0 } {
    set addYscale [expr $gYmin*-1]
  } 

  set Xscale [expr ($curX.0-$margins.0-$xOrigin)/($gXmax+$addXscale)]
  set Yscale [expr ($curY.0-$margins.0-($curY-$yOrigin))/($gYmax+$addYscale)]

  set dataIdx 0
  set colorIndex 0
    #puts "yo4"
  foreach coords $data {
    set tmpCoordList [list]
    foreach coord $coords {
    	if { ([lindex $coord 0] != "") && ([lindex $coord 1] != "") } {
				if {[llength $tmpCoordList] == 2} {
					# puts "tmpCoordList: $tmpCoordList, len tmpCoordList: [llength $tmpCoordList], coord 0 [lindex $coord 0], coord 1 [lindex $coord 1]"
					set plotCoords {}
					lappend plotCoords [join $tmpCoordList] [translateX [lindex $coord 0]] [translateY [lindex $coord 1]]
					# puts "plotCoords: $plotCoords"
    			$w.top.plot create line [join $plotCoords] \
      			-fill [lindex $colors $colorIndex] \
      			-tags [list dataLine [append dataLine $dataIdx]]

       		lset tmpCoordList [list \
         		[translateX [lindex $coord 0]] \
         		[translateY [lindex $coord 1]] ]
				} else {
       		lset tmpCoordList [list \
         		[translateX [lindex $coord 0]] \
         		[translateY [lindex $coord 1]] ]
				}
			} else {
				set tmpCoordList {}
			}
    }
    # $w.top.plot create line [join $tmpCoordList] \
    #   -fill [lindex $colors $colorIndex] \
    #   -tags [list dataLine [append dataLine $dataIdx]]
    if { $colorIndex < [expr [llength $colors]-1] } {
      incr colorIndex
    } else {
      set colorIndex 0
    }
  }
  incr dataIdx

  # Draw line labels.
  set colorIndex 0
  set labelIndex 0
    #puts "yo5"
  foreach label $dataLabels {
    $w.top.plot create text [expr $xOrigin+30] \
      [expr [translateY $gYmax]+(30+12*$labelIndex)] \
      -fill [lindex $colors $colorIndex] \
      -text $label -tags label -anchor w
    if { $colorIndex < [expr [llength $colors]-1] } {
      incr colorIndex
    } else {
      set colorIndex 0
    }
    incr labelIndex
  }

  # Add labels
  $w.top.plot create text [expr $xOrigin-10] \
    [translateY [expr $gYmax/2.0]] -text $yLabel \
    -anchor e -tags axisLabel -justify center
  $w.top.plot create text [translateX [expr $gXmax/2.0]] \
    [expr $yOrigin+10] -text $xLabel -anchor n -tags axisLabel

  # Draw Y scale
  if { $gYmax >= 0 } {
    $w.top.plot create text [expr $xOrigin-10] \
      [translateY $gYmax] \
      -text [format "%.2f" $gYmax] \
      -fill black \
      -anchor e -tags scale
    $w.top.plot create line [expr $xOrigin-7] \
      [translateY $gYmax] $xOrigin \
      [translateY $gYmax] -fill black -tags scale
  }

  if { ($gYmin != 0) && ($gYmax != 0) } {
    $w.top.plot create text [expr $xOrigin-10] \
      [translateY 0] -text "0.00" -fill black -anchor e \
      -tags scale
    $w.top.plot create line [expr $xOrigin-7] \
      [translateY 0] $xOrigin \
      [translateY 0] -fill black -tags scale
  }

  if { $gYmin <= 0 } {
    $w.top.plot create text [expr $xOrigin-10] \
      [translateY $gYmin] \
      -text [format "%.2f" $gYmin] \
      -fill black \
      -anchor e -tags scale
    $w.top.plot create line [expr $xOrigin-7] \
      [translateY $gYmin] $xOrigin \
      [translateY $gYmin] -fill black -tags scale
  }

  $w.top.plot create line $xOrigin $yOrigin $xOrigin \
    [translateY $gYmax] \
    -tags scale

  # End Y scale


  # Draw X scale
  if { $gXmax >= 0 } {
    $w.top.plot create text [translateX $gXmax] \
      [expr $yOrigin+10] -text [format "%.2f" $gXmax] \
      -fill black -anchor n -tags scale
    $w.top.plot create line [translateX $gXmax] \
      [expr $yOrigin+7] [translateX $gXmax] \
      $yOrigin -fill black -tags scale
  }

  if { ($gXmax != 0) && ($gXmin != 0) } {
    $w.top.plot create text [translateX 0] \
      [expr $yOrigin+10] -text "0.00" -fill black -anchor n \
      -tags scale
    $w.top.plot create line [translateX 0] \
      [expr $yOrigin+7] [expr $xOrigin + 0*$Xscale] \
      $yOrigin -fill black -tags scale
  }

  if { $gXmin <= 0 } {
    $w.top.plot create text [translateX $gXmin] \
      [expr $yOrigin+10] -text [format "%.2f" $gXmin] \
      -fill black -anchor n -tags scale
    $w.top.plot create line [translateX $gXmin] \
      [expr $yOrigin+7] [translateX $gXmin] \
      $yOrigin -fill black -tags scale
  }

  $w.top.plot create line $xOrigin $yOrigin \
      [translateX $gXmax] $yOrigin \
      -tags scale
    # End X scale
    
    # Draw scale markings.
    #puts "gXmax: $gXmax; gXmin: $gXmin; gYmax: $gYmax; gYmin: $gYmin"
    set Xincr [format "%.0f" [expr ($gXmax-$gXmin)/10]]
    if { $Xincr < 0 } { set Xincr [expr $Xincr*-1] }
    if { $Xincr == 0 } { set Xincr 0.1 }
    set Yincr [format "%.0f" [expr ($gYmax-$gYmin)/10]]
    if { $Yincr < 0 } { set Yincr [expr $Yincr*-1] }
    if { $Yincr == 0 } { set Yincr 0.5 }
    #puts "yo6"
    for {set i [expr $gXmin+$Xincr]} {$i < [expr $gXmax-$Xincr]} \
      {set i [expr $i+$Xincr]} {
    if { [lsearch [$w.top.plot gettags \
           [$w.top.plot find closest [translateX $i] [expr $yOrigin+10] 5]] \
        "axisLabel" ] == -1 } {
        $w.top.plot create text [translateX $i] \
      [expr $yOrigin+10] -text $i \
      -fill black -anchor n -tags scale
        $w.top.plot create line [translateX $i] \
      [expr $yOrigin+7] [translateX $i] \
      $yOrigin -fill black -tags scale
    }
      }
    #puts "yo7"
    #puts "gYmax: $gYmax; Yincr: $Yincr"
    for {set i [expr $gYmin+$Yincr]} {$i < [expr $gYmax-$Yincr]} \
      {set i [expr $i+$Yincr]} {
    if { [lsearch [$w.top.plot gettags \
           [$w.top.plot find closest [expr $xOrigin-10] [translateY $i] 5]] \
        "axisLabel" ] == -1 } {
        $w.top.plot create text [expr $xOrigin-10] \
      [translateY $i] \
      -text $i \
      -fill black \
      -anchor e -tags scale
        $w.top.plot create line [expr $xOrigin-7] \
      [translateY $i] $xOrigin \
      [translateY $i] -fill black -tags scale
    }
      }
    
    #puts "Out drawCanvas"
    
  return 
}

proc ::Plotter::translateX { x } {
  variable xOrigin  
  variable Xscale
  variable addXscale

  return [expr $xOrigin + ($x+$addXscale)*$Xscale] 
}

proc ::Plotter::translateY { y } {
  variable yOrigin 
  variable Yscale
  variable addYscale

  return [expr $yOrigin - ($y+$addYscale)*$Yscale]
}

proc ::Plotter::clearCanvas { } {
  variable w
  $w.top.plot delete dataLine
  $w.top.plot delete scale
  $w.top.plot delete label
  $w.top.plot delete axisLabel
}

proc ::Plotter::setLabels { x y } {
  # This just sets the graph x and y axis labels.
  variable xLabel
  variable yLabel

  set xLabel $x
  set yLabel [join [split $y ""] "\n"]

  return
}

proc ::Plotter::findMinMax { coords dim } {
  # This will find the min and max of the specified dimension in a list of
  # coordinates.  The first arg is a list of x/y pairs, the second should
  # be "x" or "y".  
  #
  # This proc returns a list with "min" as the first element and "max"
  # as the second element.
  switch $dim {
    x {
      set dimIndex 0
    }
    y {
      set dimIndex 1
    }
    default {
      return "You must specify 'x' or 'y' for dim"
    }
  }

  set max "unset"
  set min "unset"
  foreach coord $coords {
    if {[lindex $coord $dimIndex] != ""} {
      if { $min == "unset" } {
        set min [lindex $coord $dimIndex]
      } else {
        if { $min > [lindex $coord $dimIndex] } {
          set min [lindex $coord $dimIndex]
        }
      }
      if { $max == "unset" } {
        set max [lindex $coord $dimIndex]
      } else {
        if { $max < [lindex $coord $dimIndex] } {
          set max [lindex $coord $dimIndex]
        }
      }
    }
  }

  return [list $min $max]
}

proc ::Plotter::plotFiles { xlabel ylabel wtitle args } {
    # This proc is one that will probably be called from other VMD plugins.
    # It takes as its arguments a label for the X axis, label for the Y axis,
    # and a list of files to plot.
    
    variable w
    
    #puts "In plotFiles"
    
    # First start the window.
    plotter
    
    # Set the window title.
    if {$wtitle != ""} {
      wm title $w $wtitle
    }
    
    # Set labels.
    setLabels $xlabel $ylabel
    
    # Read data into main window
    set to_call "addDataInFiles "
    foreach arg $args {
      append to_call " $arg"
    }
    eval $to_call

    #puts "Out plotFiles"

}

proc ::Plotter::plotData { xlabel ylabel wtitle data_list } {
    # This proc is one that will probably be called from other VMD plugins.
    # It takes as its arguments a label for the X axis, label for the Y axis,
    # and a list of data.  The format of the data list is:
    # {{ {{x1 y1}...{xN yN}} {label} } { {{x1 y1}...{xN yN}} {label} } .... }
    # That is, it is a list with sub-lists composed of a list of x/y coords
    # (which is a 2-element list) and a label.  phew.

    variable w

    #puts "In plotData"
    
    # First start the window.
    plotter
    
    # Set the window title.
    if {$wtitle != ""} {
      wm title $w $wtitle
    }

    # Set labels.
    setLabels $xlabel $ylabel

    # Add data to the display.
    foreach data $data_list {
      addData [lindex $data 0] [lindex $data 1]
    }

    # Update the display.
    drawCanvas
}

proc ::Plotter::plotterNData { } {
  # Returns the number of data items currently held in the plotter.
  variable nDataItems 0

  return nDataItems
}

proc ::Plotter::PSout { } {
  # Output current plot to a PostScript file.
  variable w

  set outFile [tk_getSaveFile -initialfile "plot.ps" \
               -title "Enter filename for PS output"]

  if { $outFile == "" } {
    puts "Plotter Error) must enter a filename for save to PS"
    return
  }

  $w.top.plot postscript -file $outFile -pagewidth 8i

  return
}

proc ::Plotter::clear { } {
  # Clear all global vars so re-invoking plotter will not recall old
  # data.
  variable data
  variable dataLabels
  variable nDataItems
  variable xLabel
  variable yLabel

  set data [list]
  set dataLabels [list]
  set nDataItems 0
  set xLabel ""
  set yLabel ""
}

