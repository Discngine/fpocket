#
# 2-D plotting tool
#
# $Id: multiplot.tcl,v 1.26 2007/08/10 15:55:53 saam Exp $
#
# Author:
# Jan Saam
# Institute of Biochemistry
# Charite Berlin
# Germany
# saam@charite.de

# You can have several independent instances of "multiplot" runnning at the 
# same time because the data are kept in different namespaces.
# It returns a plothandle which you can use to control an existing plot,
# add new datasets or quit it.

# Usage:
# set plothandle [multiplot ?reset|list? ?options?]
# reset --- Closes all windows and deletes all namespaces and plothandles
# list  --- Lists all existing plothandles

# You can use the returned plothandle to control the plot:
# $plothandle add|replot|namespace|configure|data|export|quit ?options?

# $plothandle add X Y ?options?   --- Adds a dataset to the plot
# $plothandle replot              --- Replots the current data
# $plothandle namespace           --- Returns the current namespace
# $plothandle configure ?options? --- Modifies the existing plot according to the options
#                                     These modifications are silent until you call 'replot'
#                                     unless you specify the flag -plot
# $plothandle nsets               --- Returns the number of datasets in the plot
# $plothandle data                --- Returns all x and y datasets of the plot
# $plothandle xdata               --- Returns all x datasets of the plot
# $plothandle ydata               --- Returns all y datasets of the plot
# $plothandle export program filename  --- Export plot to external program
# $plothandle draw <item> ?options?    --- Draws arbitrary item into canvas. 
#                                          The item can be one of the items defined in Tk's
#                                          'canvas' command (arc, bitmap, image, line, oval,
#                                          polygon, rectangle, text, window). The options are
#                                          the same as for the corresponding 'canvas create <item>'
#                                          command (they are directly passed to canvas create).
#                                          Don't dare to ask me about these options, read the Tk manual!
#					   For your convenience I have added wrappers for the oval
#                                          and rectangle items where you can specify the center 
#                                          coordinates instead of the two opposite corners of the
#                                          bounding box. These two additional items are called
#                                          'circle' and 'square'. The size is controlled by the
#                                          additional flag -radius (which in case of square denotes
#                                          the half side length).
# $plothandle quit                --- Destroy the window of the plot and delete all data

# Options for the plothandle:
# ===========================
# Switches:
# -lines       --- Connect datapoint with lines
# -nolines     --- Don't connect datapoint with lines
# -stats       --- Print some statistics of the last added dataset
# -nostats     --- Get rid of the statistics
# -plot        --- Actually plot the data otherwise only the canvas and the axes are drawn
#                  This is equivalent to '$plothandle replot'.
#                  If you have multiple datasets it is a good idea to add all data first and 
#                  then plot them all at once since this will be a lot faster.
# -xanglescale --- Use 90 degree as major tic unit for the x-axis
# -yanglescale --- Use 90 degree as major tic unit for the y-axis

# Options with argument:
# -set i           --- Apply all dataset specific modifications to dataset i
# -x X             --- Supply the x-values for a dataset in a list
# -y Y             --- Supply the y-values for a dataset in a list
# -title text      --- Title of the plot
# -xlabel text     --- Text for the x-axis label
# -ylabel text     --- Text for the y-axis label
# -xmajortics i    --- Distance between two x-axis ticlabels
# -ymajortics i    --- Distance between two y-axis ticlabels
# -xminortics i    --- Distance between two x-axis minor tic marks
# -yminortics i    --- Distance between two y-axis minor tic marks
# -xsize s         --- Width of the canvas
# -ysize s         --- Height of the canvas
# -marker type     --- Draw markers at datapoints (none|point|circle|square)
# -radius r        --- Data point marker (radius of circle and point, size of square)
# -fillcolor color --- Fill color of datapoint markers (option can be abbreviated with -fill)
# -linewidth w     --- Width of the lines connecting datapoints
# -linecolor color --- Color of the lines connecting datapoints
# -dash pattern    --- Draw dashed lines. The dash pattern is specified by one of the
#                      following characters "-,._" (uses the same format as -dash for Tk canvas)
#                      Note that each line segment is dashed. Hence you'll get a solid line when
#                      the datapoints are so dense that the line segments are shorter than the dashes!
# -legend text     --- Add an entry for this dataset to the legend
#                      Note that the legend is drawn in the upper left corner of the plot
#                      but you can drag the legend anywhere you want using the mouse.
# -hline {y args}  --- Draw a horizontal line at position y, args are arguments for the Tk canvas 
#                      'create line' command. Through args like '-width 2 -fill red -dash "-"' you can 
#                      determine the line style.
# -vline {x args}  --- Draw a vertical line at position x, args are arguments for the Tk canvas 
#                      'create line' command. Through args like '-width 2 -fill red -dash "-"' you can 
#                      determine the line style.

# Examples:
# ---------
#   package require multiplot
#   set x {-2 -1 0 1 2 3 4 5 6 7 8 9 10}
#   set y {-2  0 2 3 4 5 5 4 3 2 1 0 1}

### This plot will be immediately created because we specified -plot 
#   set plothandle [multiplot -x $x -y $y -title "Example plot" -lines -linewidth 3 -marker point -plot]

### Now we change the appearence of the existing plot.
### BUT WE WON'T SEE THIS change until the next replot is requested!
#   $plothandle configure -fillcolor yellow -radius 6 -plot

### Let's add a vertical dotted line at x=3
#   $plothandle configure -vline {3 -width 2 -fill red -dash "."} -plot

### And now redraw the plot so that the changes become visible:
#   $plothandle replot;
  
### It's time to add a second dataset to the same plot
#   set y2 {6 7 8 7 6 6 5 4 4 3 2 3 4}
#   $plothandle add $x $y2 -marker circle  -fillcolor green -radius 4 -plot

### Of course we can change the appearence of the the two sets independently:
#   $plothandle configure -set 1 -lines -linewidth 4 -dash "," -plot

### Export to xmgrace, load with 'xmgrace -nxy /tmp/foo.plot'
#   $plothandle export xmgrace /tmp/foo.plot

### Close the plot
#   $plothandle quit

package require exectool  1.2
package provide multiplot 1.1

namespace eval ::MultiPlot:: {
   proc initialize {} {
      variable plotcount -1
   }
   initialize
}

proc ::MultiPlot::init_plot { } {
   incr ::MultiPlot::plotcount
   set ns "::MultiPlot::Plot${::MultiPlot::plotcount}"

   if {[namespace exists $ns]} {
      puts "Reinitializing namespace $ns."
   } else {
      puts "Creating namespace $ns"
   }

   namespace eval $ns {
      # Default values
      variable nsets 0
      variable datasets
      array unset datasets
      lappend args -set 0
      variable curset 0
      variable title {}
      variable titlefontsize 10
      variable ticfontsize   8
      variable labelfontsize 10
      variable titlefont  "Helvetica $titlefontsize"
      variable ticfont    "Helvetica $ticfontsize"
      variable labelfont  "Helvetica $labelfontsize"
      variable infoFont   {Courier 9}
      variable postscript "multiplot.ps"
      variable printstats 0
      variable replot 0
      variable canh   700;   # canvas height
      variable canw   1000;  # canvas width
      variable resize 0
      variable ticlen 10; # length of the major tic marks
      variable rim    8;  # extra space around the plot
      variable xlabeloffset
      variable xlabeltext ""
      variable ylabeloffset
      variable ylabeltext ""
      variable lines     1;        # connect data points with lines?
      variable marker    "none";   # display data points [circle|point|square|none]
      variable radius    2;        # radius of circles and points , size of squares
      variable linewidth 1;        # width of the line connecting data points
      variable fillcolor Skyblue2; # fill color of data point markers   
      variable linecolor black;    # color of lines connecting data points
      variable dashed    {{}};     # Draw dashed lines (uses the same format as -dash for Tk canvas)
      variable legend    {{}};     # legend string for current dataset
      variable colorlist {black red green blue magenta orange OliveDrab2 cyan maroon gold2 yellow gray60 SkyBlue2 orchid3 ForestGreen PeachPuff LightSlateBlue}
      variable xmin   0
      variable xmin_y 0
      variable ymin   0
      variable ymin_x 0
      variable xmax   0
      variable xmax_y 0
      variable ymax   0
      variable ymax_x 0
      variable spanx  0
      variable spany  0
      variable anglescalex 0
      variable anglescaley 0
      variable xmajortics {}
      variable ymajortics {}
      variable xminortics {}
      variable yminortics {}

      variable hline    {}
      variable vline    {}
      variable xplotmin {}
      variable yplotmin {}
      variable xplotmax {}
      variable yplotmax {}
      variable scalex {}
      variable scalex {}
      variable dimx 0
      variable dimy 0
      variable minorticx 5
      variable minorticy 5

      variable objectlist {}; # other drawn objects like circles, text, lines,...
      variable redraw 0;      # redraw all objects
      variable w .plotwindow${::MultiPlot::plotcount}
      variable c
      variable namespace ::Plothandle${::MultiPlot::plotcount}

      catch {destroy $w}
      toplevel $w
      wm title $w "MultiPlot"
      wm iconname $w "MultiPlot"
      wm protocol $w WM_DELETE_WINDOW "[namespace current]::plothandle quit"
      wm withdraw $w

      menu $w.menu -tearoff 0
      menu $w.menu.file -tearoff 0
      $w.menu add cascade -label "File" -menu $w.menu.file -underline 0
      
      menu $w.menu.file.open -tearoff 0
      
      $w.menu.file add command -label "Export to PostScript" -command "[namespace current]::savedialog "
      $w.menu.file add command -label "Export to Xmgrace" -command "[namespace current]::xmgracedialog "
      $w.menu.file add command -label "Print plothandle in TKcon" -command "puts [namespace current]::plothandle"
      $w.menu.file add command -label "Quit" -command "[namespace current]::plothandle quit"
      $w configure -menu $w.menu

      if {![winfo exists $w.cf]} {
	 variable canw
	 variable canh
	 variable c $w.cf
	 canvas $c -relief flat -borderwidth 0 -width $canw -height $canh
	 pack   $c -side top -fill x 
      }

      # Create a plothandle procedure that provides some commands to control the plot.
      # It's full name will be returned when you invoke multiplot.
      proc plothandle { command args } {
	 variable w
	 switch $command {
	    namespace { return [namespace current] }
	    replot    { variable replot 1; plot_update; return }
	    add       { 
	       set newX [lindex $args 0]
	       set newY [lindex $args 1]

	       set lenX [llength $newX]
	       set lenY [llength $newY]
	       if {!$lenX} { error "X data vector is empty!" }
	       if {!$lenY} { error "Y data vector is empty!" }

	       # Check, if we have several coordinate sets:
	       if {[llength [join $newX]]>$lenX || [llength [join $newY]]>$lenY} {
		  if {$lenX != $lenY} {
		     error "Different number of datasets for x and y ($lenX!=$lenY)"
		  }
		  foreach x $newX y $newY {
		     eval add_data [list $x] [list $y] [lrange $args 2 end]
		  }
	       } else {
		  eval add_data [list $newX] [list $newY] [lrange $args 2 end]
	       }
	       plot_update 
	    }
	    draw {
	       # Register the new object
	       variable objectlist
	       lappend objectlist $args

	       # Make sure that the plot geometry was calculated already and draw
	       variable xplotmin
	       if {![llength $xplotmin]} {
	          variable redraw 1;
		  variable resize 1;
		  plot_update; # implicitely draws all objects
	       } else {
		  draw_object $args
	       }
	    }
	    configure { 
	       variable datasets
	       variable nsets
	       variable resize

	       variable curset {} 
 	       set pos [lsearch $args "-set"]
 	       if {$pos>=0 && $pos+1<[llength $args]} { 
 		  variable curset [lindex $args [expr $pos+1]]
 		  set args [lreplace $args $pos [expr $pos+1]]
 	       }
	       if {![llength $curset]} { set curset 0 }

	       set havedata 0
 	       set pos [lsearch $args "-x"]
 	       if {$pos>=0 && $pos+1<[llength $args]} { 
		  if {$nsets==0} {
		     lappend datasets(X) {}
		     lappend datasets(Y) {}
		     lappend datasets(xmin) {}
		     lappend datasets(xmax) {}
		     lappend datasets(xmin_y) {}
		     lappend datasets(xmax_y) {}
		     lappend datasets(ymin) {}
		     lappend datasets(ymax) {}
		     lappend datasets(ymin_x) {}
		     lappend datasets(ymax_x) {}
		     incr nsets
		  }
 		  lset datasets(X) $curset [lindex $args [expr $pos+1]]
 		  set args [lreplace $args $pos [expr $pos+1]]
 		  variable resize 1
		  set havedata 1
 	       }

 	       set pos [lsearch $args "-y"]
 	       if {$pos>=0 && $pos+1<[llength $args]} { 
		  if {$nsets==0} {
		     lappend datasets(X) {}
		     lappend datasets(Y) {}
		     lappend datasets(xmin) {}
		     lappend datasets(xmax) {}
		     lappend datasets(xmin_y) {}
		     lappend datasets(xmax_y) {}
		     lappend datasets(ymin) {}
		     lappend datasets(ymax) {}
		     lappend datasets(ymin_x) {}
		     lappend datasets(ymax_x) {}
		     incr nsets
		  }
 		  lset datasets(Y) $curset [lindex $args [expr $pos+1]]
 		  set args [lreplace $args $pos [expr $pos+1]]
      variable resize 1
		  set havedata 1
 	       }

	       plot_scan_options $args; 

	       if {$resize && $havedata} {
		  init_dataset
	       }

	       plot_update 
	    }
	    nsets      {
	       variable datasets;
	       return [llength $datasets(Y)]
	    }
            xdata      {
	       variable datasets;
	       return $datasets(X)
	    }
	    ydata      {
	       variable datasets;
	       return $datasets(Y)
            }
	    data      { 
	       variable datasets;
	       return [list $datasets(X) $datasets(Y)]
	    }
            export    {
              variable datasets
              variable title
              variable legend
              variable nsets
              if { [llength $args] < 2} {
                puts "Incorrect export syntax"
                return
              }
              set progname [lindex $args 0]
              set filename [lindex $args 1] 

              switch $progname {
                grace - 
                xmgr  -
                xmgrace {
                  puts "Exporting plot in xmgrace format as filename $filename"
                  set fd [open $filename "w"]
                  puts $fd "@type xy"
                  puts $fd "@title \"$title\""
                  set ylen [llength $datasets(Y)]
	          for {set s 0} {$s < $nsets} {incr s} {
                    if {[lindex $legend $s] != ""} {
                      puts $fd "@s$s legend \"[lindex $legend $s]\""
                    }
                  }
	          for {set s 0} {$s < $nsets} {incr s} {
                    set xlen [llength [lindex $datasets(X) $s]]
                    for {set i 0} {$i < $xlen} {incr i} {
                      puts $fd "[lindex $datasets(X) $s $i] [lindex $datasets(Y) $s $i]"
                    }
		    puts $fd "&"
                  }                    
                  close $fd
                }
              }

              return
            }
	    quit   { 
	       destroy $w;
	       namespace delete [namespace current]
	       return
	    }
	 }
      }

      proc init_dataset {} {
	 variable datasets
	 variable curset
	 set minx [lindex $datasets(X) $curset 0]
	 set maxx [lindex $datasets(X) $curset end]
	 set miny [lindex $datasets(Y) $curset 0]
	 set maxy [lindex $datasets(Y) $curset end]
	 set minx_y [lindex $datasets(Y) $curset 0]
	 set maxx_y [lindex $datasets(Y) $curset end]
	 set miny_x [lindex $datasets(X) $curset 0]
	 set maxy_x [lindex $datasets(X) $curset end]
	 foreach x [lindex $datasets(X) $curset] y [lindex $datasets(Y) $curset] {
	    if {$x<$minx} {
	       set minx   $x
	       set minx_y $y
	    }
	    if {$x>$maxx} {
	       set maxx   $x
	       set maxx_y $y
	    }
	    if {$y<$miny} {
	       set miny   $y
	       set miny_x $x
	    }
	    if {$y>$maxy} {
	       set maxy   $y
	       set maxy_x $x
	    }
	 }
	 lset datasets(xmin)   $curset $minx
	 lset datasets(xmin_y) $curset $minx_y
	 lset datasets(xmax)   $curset $maxx
	 lset datasets(xmax_y) $curset $maxx_y
	 lset datasets(ymin)   $curset $miny
	 lset datasets(ymin_x) $curset $miny_x
	 lset datasets(ymax)   $curset $maxy
	 lset datasets(ymax_x) $curset $maxy_x
      }

      proc plot_scan_options { arg } {
	 set drawlines {}
	 set points 0
	 variable printstats
	 variable anglescalex
	 variable anglescaley

	 # Scan for single options
	 set argnum 0
	 set arglist $arg
	 foreach i $arg {
	    if {$i=="-lines"}  then {
	       set drawlines 1
	       set arglist [lreplace $arglist $argnum $argnum]
	       continue
	    }
	    if {$i=="-nolines"}  then {
	       set drawlines 0
	       set arglist [lreplace $arglist $argnum $argnum]
	       variable resize 1 
	       continue
	    }
	    if {$i=="-stats"}  then {
	       set printstats 1
	       set arglist [lreplace $arglist $argnum $argnum]
	       continue
	    }
	    if {$i=="-plot"}  then {
	       variable replot 1
	       set arglist [lreplace $arglist $argnum $argnum]
	       continue
	    }
	    if {$i=="-nostats"}  then {
	       set printstats 0
	       set arglist [lreplace $arglist $argnum $argnum]
	       continue
	    }
	    if {$i=="-xanglescale"}  then {
	       set anglescalex 1
	       set arglist [lreplace $arglist $argnum $argnum]
	       variable resize 1 
	       continue
	    }
	    if {$i=="-yanglescale"}  then {
	       set anglescaley 1
	       set arglist [lreplace $arglist $argnum $argnum]
	       variable resize 1 
	       continue
	    }
	    incr argnum
	 }

	 # must search for the dataset option first
	 variable nsets
	 variable curset 
	 foreach {i j} $arglist {
	    if {$i=="-set"}       then { 
	       if {$j>=$nsets} {
		  error "Dataset $j doesn't exist"
	       }
	       variable curset $j;
	    }
	 }

	 #variable curset
	 if {[llength $drawlines]} {
	    variable lines
	    if {![llength $curset]} {
	       for {set s 0} {$s<$nsets} {incr s} {
		  lset lines $s $drawlines
	       }
	    } else {
	       lset lines $curset $drawlines
	    }
	 }

	 # Scan for options with one argument
	 variable hline
	 variable vline
	 variable datasets
	 foreach {i j} $arglist {
# 	    if {$i=="-x"}          then { 
# 	       if {![llength [array get datasets X]]} {
# 		  lappend datasets(X) $curset $j;
# 	       } else {
# 	       lset datasets(X) $curset $j
# 	       }
# 	       variable resize 1
# 	    }
# 	    if {$i=="-y"}          then { 
# 	       if {![llength [array get datasets Y]]} {
# 		  lappend datasets(Y) $curset $j;
# 	       } else {
# 		  lset datasets(Y) $curset $j
# 	       }
# 	       variable resize 1
# 	    }
	    if {$i=="-title"}      then { variable title $j; variable resize 1 }
	    if {$i=="-xlabel"}     then { variable xlabeltext $j; variable resize 1 }
	    if {$i=="-ylabel"}     then { variable ylabeltext $j; variable resize 1 }
	    if {$i=="-xmajortics"} then { variable xmajortics $j; variable resize 1 }
	    if {$i=="-ymajortics"} then { variable ymajortics $j; variable resize 1 }
	    if {$i=="-xminortics"} then { variable xminortics $j; variable resize 1 }
	    if {$i=="-yminortics"} then { variable yminortics $j; variable resize 1 }
	    if {$i=="-xsize"}      then { variable canw $j; variable resize 1 }
	    if {$i=="-ysize"}      then { variable canh $j; variable resize 1 }
	    if {$i=="-hline"}      then { lappend hline $j; variable resize 1 }
	    if {$i=="-vline"}      then { lappend vline $j; variable resize 1 }
	    if {$i=="-radius"}     then { 
	       variable radius 
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset radius $s $j
		  }
	       } else {
		  lset radius $curset $j
	       }
	    }
	    if {$i=="-dash"}     then { 
	       variable dashed
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset dashed $s $j
		  }
	       } else {
		  lset dashed $curset $j
	       }
	    }
	    if {[string match "-fill*" $i]} then { 
	       variable fillcolor 
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset fillcolor $s $j;
		  }
	       } else {
		  lset fillcolor $curset $j
	       }
	    }
	    if {$i=="-linewidth"} then { 
	       variable linewidth 
	       variable datasets
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset linewidth $s $j
		  }
	       } else {
		  lset linewidth $curset $j
	       }
	    }
	    if {$i=="-linecolor"} then {
	       variable linecolor 
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset linecolor $s $j;
		  }
	       } else {
		  lset linecolor $curset $j
	       }
	    }
	    if {[string match "-mark*" $i]} then { 
	       variable marker
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset marker $s $j
		  }
	       } else {
		  lset marker $curset $j
	       }
	    }
	    if {$i=="-legend"}      then { 
	       variable legend
	       if {![llength $curset]} {
		  for {set s 0} {$s<$nsets} {incr s} {
		     lset legend $s $j
		  }
	       } else {
		  lset legend $curset $j
	       }
	    }
	 }
      }
      
      proc add_data {x y args} {
	 if {[llength $x] != [llength $y]} {
	    error "Different number of x and y coordinates ([llength $x]!=[llength $y])"
	 }
	 variable datasets
	 variable nsets
	 variable curset $nsets
	 variable lines 
	 variable linewidth 
	 variable linecolor
	 variable marker
	 variable fillcolor 
	 variable dashed
	 variable radius
	 variable legend
	 variable colorlist

	 lappend datasets(X) $x
	 lappend datasets(Y) $y
	 lappend datasets(xmin)   {}
	 lappend datasets(xmax)   {}
	 lappend datasets(xmin_y) {}
	 lappend datasets(xmax_y) {}
	 lappend datasets(ymin)   {}
	 lappend datasets(ymax)   {}
	 lappend datasets(ymin_x) {}
	 lappend datasets(ymax_x) {}
	 lappend lines     1
	 lappend linewidth 1
	 lappend linecolor [lindex $colorlist [expr {(1+$nsets)%[llength $colorlist]}]]
	 lappend marker    "none"
	 lappend fillcolor [lindex $colorlist [expr {(1+$nsets)%[llength $colorlist]}]]
	 lappend radius    2
	 lappend dashed    {}
	 lappend legend    {}

	 # Evaluate the command line options
	 lappend args -set $nsets
	 incr nsets
	 plot_scan_options $args

	 #variable replot 1
	 init_dataset
      }

      proc plot_update {} {
	 variable datasets
	 set lenx [llength [lindex [array get datasets X] 1 0]]
	 set leny [llength [lindex [array get datasets Y] 1 0]]
	 if {!$leny} {
	    puts "multiplot: Warning: Data vector empty, ignoring plot!"
	    variable replot 0; return
	 }
	 if {$lenx && $lenx!=$leny} {
	    puts "multiplot: Warning: Different size of X and Y data, ignoring plot!"
	    variable replot 0; return
	 }

	 variable replot 
	 variable redraw

	 if {!$replot && !$redraw} { return }

	 # Use index number if no X-coordinate was specified
	 set j 0
	 foreach X $datasets(X) Y $datasets(Y) {
	    if {![llength $X]} {
	       set x {}
	       for {set i 0} {$i<[llength $Y]} {incr i} {
		  lappend x $i
	       }
	       lset datasets(X) $j $x
	       init_dataset
	    }
	    incr j
	 }

	 variable w
	 variable c
	 variable resize

	 # Display some statistics in an info frame
	 variable printstats
	 if {![winfo exists $w.info] && $printstats} { draw_infobox }
	 if {[winfo exists $w.info] && !$printstats} { destroy $w.info; pack $w.cf }

	 if {[winfo exists $c] && $resize} {
	    variable canw
	    variable canh
	    $c configure -width $canw -height $canh
	 }

	 calculate_range
	 calculate_ticspacing

	 if {$resize} {
 	    # Clear the canvas
 	    $c addtag all all
 	    $c delete all
	    calculate_labelsize
	    calculate_plot_geometry
	    draw_periphery
	    redraw_objects 
	    variable redraw 0
	    variable resize 0
	 }

	 if {$replot} {
	    wm deiconify $w
	    plot_data
	    variable replot 0
	 }
      }

      proc plot_data {} {
	 # Plot the values
	 variable c
	 variable datasets
	 variable marker
	 variable radius
	 variable dashed
	 variable fillcolor
	 variable lines
	 variable linewidth
	 variable linecolor

	 variable xmin
	 variable ymin
	 variable xplotmin
	 variable xplotmax
	 variable yplotmin
	 variable yplotmax
	 variable scalex
	 variable scaley
	 variable legend
	 variable legendheight
	 $c delete legend
	 $c delete point
	 $c delete lines

	 set ds 0
	 foreach X $datasets(X) Y $datasets(Y) dsxmin $datasets(xmin) dsxmin_y $datasets(xmin_y) {
	    set stride 1
	    #set len [llength $dset(X)]
	    #if {$len>[expr 2*($xplotmax-$xplotmin)]} { 
	    #   set stride [expr int([llength $dset(X)]/[expr $xplotmax-$xplotmin])]
	    #   puts "Using stride $stride for data set $ds ([llength $dset(X)]/[expr $xplotmax-$xplotmin])"
	    #}
	    set oldx [expr {$xplotmin + ($scalex*($dsxmin-$xmin))}]
	    set oldy [expr {$yplotmin + ($scaley*($dsxmin_y-$ymin))}]
	    set fc   [lindex $fillcolor $ds]
	    set lc   [lindex $linecolor $ds]
	    set rad  [lindex $radius $ds]
	    set dash [lindex $dashed $ds]
	    set leg  [lindex $legend $ds]

	    if {[lindex $lines $ds]} {
	       set i 0
	       foreach cx $X cy $Y {
		  incr i
		  if {[expr $i%$stride]} { continue }
		  set x [expr {$xplotmin + ($scalex*($cx-$xmin))}]
		  set y [expr {$yplotmin + ($scaley*($cy-$ymin))}]
		  
		  set item [$c create line $oldx $oldy $x $y -width [lindex $linewidth $ds] -fill $lc -dash $dash]
		  $c addtag lines withtag $item
		  set oldx $x
		  set oldy $y
	       }
	    }
	    if {[lindex $marker $ds]!="none"} {
	       set i 0
	       foreach cx $X cy $Y {
		  incr i
		  if {[expr $i%$stride]} { continue }
		  set x [expr {$xplotmin + ($scalex*($cx-$xmin))}]
		  set y [expr {$yplotmin + ($scaley*($cy-$ymin))}]
		  if {[string match "point*" [lindex $marker $ds]]} {
		     set item [$c create oval [expr {$x-$rad}] [expr {$y-$rad}] \
				  [expr {$x+$rad}] [expr {$y+$rad}] -width 0 -fill $fc]
				  
		     $c addtag point withtag $item
		  } elseif {[lindex $marker $ds]=="circle"} {
		     set item [$c create oval [expr {$x-$rad}] [expr {$y-$rad}] \
				  [expr {$x+$rad}] [expr {$y+$rad}] -width 1 -outline $lc \
				  -fill $fc]
		     $c addtag point withtag $item
		  } elseif {[lindex $marker $ds]=="square"} {
		     set item [$c create rectangle [expr {$x-$rad}] [expr {$y-$rad}] \
				  [expr {$x+$rad}] [expr {$y+$rad}] -width 1 -outline $lc \
				  -fill $fc]
		     $c addtag point withtag $item
		  }
	       }
	    }

	    # Draw the legend
	    if {[llength $leg]} {
	       variable ticfont
	       variable ticfontsize
	       set ylegpos [expr $yplotmax+2*$ticfontsize+$ds*2.2*$ticfontsize]
	       set xlegpos [expr $xplotmin+30]
	       set item [$c create line $xlegpos $ylegpos [expr $xlegpos+30] $ylegpos \
		  -width [lindex $linewidth $ds] -fill $lc -dash $dash]
	       $c addtag legend withtag $item
	       set item [$c create text [expr $xlegpos+30+$ticfontsize] $ylegpos -text $leg \
			    -font $ticfont -anchor w]
	       $c addtag legend withtag $item
	       if {[lindex $marker $ds]=="points"} {
		  set item [$c create oval [expr {$xlegpos-$rad}] [expr {$ylegpos-$rad}] \
			       [expr {$xlegpos+$rad}] [expr {$ylegpos+$rad}] -width 1 -fill $fc]
		  $c addtag legend withtag $item
		  set item [$c create oval [expr {$xlegpos+30-$rad}] [expr {$ylegpos-$rad}] \
			       [expr {$xlegpos+30+$rad}] [expr {$ylegpos+$rad}] -width 1 -fill $fc]
		  $c addtag legend withtag $item
	       } elseif {[lindex $marker $ds]=="circle"} {
		  set item [$c create oval [expr {$xlegpos-$rad}] [expr {$ylegpos-$rad}] \
			       [expr {$xlegpos+$rad}] [expr {$ylegpos+$rad}] -width 1 -outline $lc \
			       -fill $fc]
		  $c addtag legend withtag $item
		  set item [$c create oval [expr {$xlegpos+30-$rad}] [expr {$ylegpos-$rad}] \
			       [expr {$xlegpos+30+$rad}] [expr {$ylegpos+$rad}] -width 1 -outline $lc \
			       -fill $fc]
		  $c addtag legend withtag $item
	       }
	    }

	    incr ds
	 }	    
	 $c bind point <Any-Enter> [namespace code {
	    #$c itemconfig current -fill red; 
	    print_datapoint %x %y
	 }]
	 #$c bind point <Any-Leave> "$c itemconfig current -fill $fc"
	 $c bind legend <1> "[namespace current]::grab_legend $c %x %y"
	 $c bind legend <B1-Motion> "[namespace current]::move_legend $c %x %y"
      }

      # Transforms coordinates from plot coordinates to canvas coords
      proc world2canvascoor {wx wy} {
         variable xplotmin
	 variable yplotmin
	 variable scalex
	 variable scaley
	 variable xmin
	 variable ymin
	 set x [expr {$xplotmin + ($scalex*($wx-$xmin))}]
	 set y [expr {$yplotmin + ($scaley*($wy-$ymin))}]
	 return [list $x $y]
      }			   
      
      proc redraw_objects {} {
      	variable objectlist
	foreach object $objectlist {
	   draw_object $object
	}
      }
      
      proc draw_object {object} {
        variable c
      	set oname [lindex $object 0]
	set optpos [lsearch -regexp $object {^-[^[:digit:]]}]
	set options {}
	if {$optpos<0} {
	  set optpos end
        } else {
	  set options [lrange $object $optpos end]
	  incr optpos -1
	}
	set coords [join [lrange $object 1 $optpos]]
	foreach {wx wy} $coords {
	  lappend plotcoords [world2canvascoor $wx $wy]
	}
	if {$oname=="circle" || $oname=="square"} {
	  set rad 1.0
	  set pos [lsearch $options "-radius"]
	  if {$pos>=0} {
	     if {$pos+1<[llength $options]} {
	        set rad [lindex $options [expr {$pos+1}]]
	     }
	     set options [lreplace $options $pos [expr {$pos+1}]]
	  }
	  foreach {x y} [join $plotcoords] {break}
	  set plotcoords  [list [expr {$x-$rad}] [expr {$y-$rad}] [expr {$x+$rad}] [expr {$y+$rad}]]
	  if {$oname=="circle"} { 
	     set oname "oval"
	  } else { set oname "rectangle" }
	}
	
	set evalstr "$c create $oname [join $plotcoords] $options"
	set item [eval $evalstr]
	$c addtag objects withtag $item
      }
      
      # grab_legend --
      # This procedure is invoked when the mouse is pressed over one of the
      # legend items.  It sets up state to allow the legend to be dragged.
      #
      # Arguments:
      # w -		The canvas window.
      # x, y -	The coordinates of the mouse press.

      proc grab_legend {w x y} {
	 variable legendpos
	 #$w dtag selected
	 #$w addtag selected withtag current
	 $w raise legend
	 set legendpos(lastX) $x
	 set legendpos(lastY) $y
      }

      # move_legend --
      # This procedure is invoked during mouse motion events.  It drags the
      # legend.
      #
      # Arguments:
      # w -		The canvas window.
      # x, y -	The coordinates of the mouse.

      proc move_legend {w x y} {
	 variable legendpos
	 $w move legend [expr {$x-$legendpos(lastX)}] [expr {$y-$legendpos(lastY)}]
	 set legendpos(lastX) $x
	 set legendpos(lastY) $y
      }

      proc calculate_range {} {
	 # Get min/max values
	 variable datasets
	 set lxmin {}
	 set lxmax {}
	 set lymin {}
	 set lymax {}
	 foreach dsxmin $datasets(xmin) dsxmax $datasets(xmax) \
 	         dsymin $datasets(ymin) dsymax $datasets(ymax) \
	         dsxmin_y $datasets(xmin_y) dsxmax_y $datasets(xmax_y) \
	         dsymin_x $datasets(ymin_x) dsymax_x $datasets(ymax_x) {
	       lappend lxmin [list $dsxmin $dsxmin_y]
	       lappend lymin [list $dsymin $dsymin_x]
	       lappend lxmax [list $dsxmax $dsxmax_y]
	       lappend lymax [list $dsymax $dsymax_x]
	    }

	 set tmpxmin [lindex [lsort -real -index 0 $lxmin] 0 0]
	 set tmpymin [lindex [lsort -real -index 0 $lymin] 0 0]
	 set tmpxmax [lindex [lsort -real -index 0 $lxmax] end 0]
	 set tmpymax [lindex [lsort -real -index 0 $lymax] end 0]
         variable xmin     
         variable ymin     
         variable xmax     
         variable ymax     
	 if {$tmpxmin<$xmin || $tmpxmax>$xmax || $tmpymin<$ymin || $tmpymax>$ymax} {
	    variable resize 1
	 }

         variable xmin     [format "%10g" $tmpxmin]
         variable xmin_y   [format "%10g" [lindex [lsort -real -index 0 $lxmin] 0 1]]
         variable ymin     [format "%10g" $tmpymin]
         variable ymin_x   [format "%10g" [lindex [lsort -real -index 0 $lymin] 0 1]]
         variable xmax     [format "%10g" $tmpxmax]
         variable xmax_y   [format "%10g" [lindex [lsort -real -index 0 $lxmax] end 1]]
         variable ymax     [format "%10g" $tmpymax]
         variable ymax_x   [format "%10g" [lindex [lsort -real -index 0 $lymax] end 1]]
         variable spanx    [expr $xmax-$xmin]
         variable spany    [expr $ymax-$ymin]

	 # Order of magnitude of value range
	 if {$spanx==0.0} { variable spanx 1 } 
	 if {$spany==0.0} { variable spany 1 } 
	 variable dimx [expr 0.5*pow(10,floor(log10($spanx)))]
	 variable dimy [expr 0.5*pow(10,floor(log10($spany)))]
      }
	 
      proc calculate_ticspacing {} {
	 variable spanx
	 variable spany
	 variable dimx
	 variable dimy

	 # Total number of tics between two major tics
	 variable minorticx 5
	 if {[expr $spanx/$dimx]>5} {
	    variable minorticx 2
	 }
	 
	 variable minorticy 5
	 if {[expr $spany/$dimy]>5} {
	    variable minorticy 2
	 }

	 variable anglescalex
	 variable anglescaley
	 if {$anglescalex} {
	    set dimx 90
	    set minorticx 3
	 }
	 if {$anglescaley} {
	    set dimy 90
	    set minorticy 3
	 }

	 variable xmajortics
	 variable ymajortics
	 variable xminortics
	 variable yminortics
	 if {[llength $xmajortics]} { set dimx $xmajortics }
	 if {[llength $ymajortics]} { set dimy $ymajortics }
	 if {[llength $xminortics]} { set minorticx $xminortics }
	 if {[llength $yminortics]} { set minorticy $yminortics }
# 	 set i 0
# 	 while {1} {
# 	    variable loticx [expr $i*$minorticx]
# 	    if {$loticx<$xmin} { return [expr $i*$minorticx]}
# 	    incr i
# 	 }
	 variable xmin
	 variable ymin
	 variable xmax
	 variable ymax
	 puts "dimx=$dimx xmin=$xmin xmax=$xmax ceil=[expr ceil($xmin/$dimx*$minorticx)]"
	 puts "dimy=$dimy ymin=$ymin ymax=$ymax ceil=[expr ceil($ymin/$dimy*$minorticy)]"
	 variable loticx [expr $dimx*ceil($xmin/$dimx*$minorticx)/$minorticx]
	 variable loticy [expr $dimy*ceil($ymin/$dimy*$minorticy)/$minorticy]
	 variable hiticx [expr $dimx*floor($xmax/$dimx*$minorticx)/$minorticx]
	 variable hiticy [expr $dimy*floor($ymax/$dimy*$minorticy)/$minorticy]
      }

      proc calculate_labelsize {} {
	 # Measure y-axis label size
	 variable c
	 variable labelfont
	 variable xlabeltext
	 variable ylabeltext
	 if {[llength $ylabeltext]} {
	    set item [$c create text 0 0 -text $ylabeltext -font $labelfont -anchor nw]
	    set bbox [$c bbox $item]
	    variable ylabelheight [expr [lindex $bbox 3]-[lindex $bbox 1]]
	    variable ylabelwidth [expr [lindex $bbox 2]-[lindex $bbox 0] + $ylabelheight]
	    $c delete $item
	 } else {
	    variable ylabelwidth 0.0
	 }

	 # Measure x-axis label height
	 if {[llength $xlabeltext]} {
	    set item [$c create text 0 0 -text $xlabeltext -font $labelfont -anchor nw]
	    set bbox [$c bbox $item]
	    $c delete $item
	    variable xlabelheight  [expr 1.5*[lindex $bbox 3]-[lindex $bbox 1]]
	 } else {
	    variable xlabelheight 0.0
	 }

	 
	 ## Measure x-axis ticlabel size
	 variable loticx
	 variable hiticx
	 variable ticfont
	 # Compare smallest and biggest tics
	 set absxmax [lindex [lsort -real [list [expr abs($loticx)] [expr abs($hiticx)]]] end]
	 set item [$c create text 0 0 -text [format "-%g" $absxmax] -font $ticfont -anchor nw]
	 set bbox [$c bbox $item]
	 $c delete $item
	 variable ticlabelheight [expr 1.5*[lindex $bbox 3]-[lindex $bbox 1]]
	 variable xticlabelwidth [expr [lindex $bbox 2]-[lindex $bbox 0]]

	 ## Measure y-axis ticlabel size
	 variable dimx
	 variable loticy
	 variable hiticy
	 variable ticfont
	 # Compare smallest and biggest tics
	 set absymax [lindex [lsort -real [list [expr abs($loticy)] [expr abs($hiticy)]]] end]
	 set item [$c create text 0 0 -text [format "-%g" $absymax] -font $ticfont -anchor nw]
	 set bbox [$c bbox $item]
	 $c delete $item
	 variable ticlabelheight [expr 1.5*[lindex $bbox 3]-[lindex $bbox 1]]
	 variable yticlabelwidth [expr [lindex $bbox 2]-[lindex $bbox 0]]
	 # Check if the neighboring ticlabel is wider since it could involve more decimal places
	 set item [$c create text 0 0 -text [format "-%g" [expr $absymax+$dimx]] -font $ticfont -anchor nw]
	 set bbox [$c bbox $item]
	 $c delete $item
	 if {[expr 1.5*[lindex $bbox 2]-[lindex $bbox 0]]>$yticlabelwidth} {
	    variable yticlabelwidth [expr [lindex $bbox 2]-[lindex $bbox 0]]
	 }

	 # Measure title height
	 variable title
	 variable titlefont
	 if {![llength $title]} { set title [namespace current] }
	 set item [$c create text 0 0 -text $title -font $titlefont -anchor nw]
	 set bbox [$c bbox $item]
	 $c delete $item
	 variable titleheight [expr 1.5*[lindex $bbox 3]-[lindex $bbox 1]]
      } 
      
      proc calculate_plot_geometry {} {
	 # Compute legend height
	 variable legend	 
	 variable ticfontsize
	 variable legendheight 0.0
	 foreach legitem $legend {
	    if {[llength $legitem]} {
	       set legendheight [expr $legendheight+1.8*$ticfontsize]
	    }
	 }
	 
	 ## Plot geometry
	 variable rim
	 variable canh
	 variable canw
	 variable ticlen
	 variable xlabelheight
	 variable ylabelwidth
	 variable xticlabelwidth
	 variable yticlabelwidth
	 variable ticlabelheight
	 variable titleheight
	 variable xplotmin [expr $rim+$ylabelwidth+$yticlabelwidth+$ticlen]
	 variable yplotmin [expr $canh-($rim+$xlabelheight+$ticlabelheight+$ticlen)]
	 variable xplotmax [expr $canw-$rim-0.5*$xticlabelwidth]
	 variable yplotmax [expr $rim+$titleheight]

	 # Scaling factor to convert world coordinates into plot coordinates
	 variable spanx
	 variable spany
	 variable scalex [expr ($xplotmax-$xplotmin)/(1.0*$spanx)]	
	 variable scaley [expr ($yplotmax-$yplotmin)/(1.0*$spany)]	

	 variable dimx
	 variable scalex
	 if {[expr $xticlabelwidth]>[expr $dimx*$scalex*0.7]} {
	    set dimx [expr 2.0*$dimx]
	    calculate_ticspacing
	    calculate_labelsize
	    calculate_plot_geometry
	 }
      }

      proc draw_periphery {} {
	 # Draw title
	 variable c
	 variable rim
	 variable canw
	 variable canh
	 variable title
	 variable titlefont
	 $c create text [expr $canw/2] $rim -anchor n -text $title -font $titlefont -fill brown

	 # Draw bounding box
	 variable xplotmin
	 variable yplotmin
	 variable xplotmax
	 variable yplotmax
	 $c create line $xplotmin $yplotmin $xplotmax $yplotmin -width 2
	 $c create line $xplotmin $yplotmin $xplotmin $yplotmax -width 2
	 $c create line $xplotmax $yplotmin $xplotmax $yplotmax -width 2
	 $c create line $xplotmin $yplotmax $xplotmax $yplotmax -width 2

	 # Scaling factor to convert plot coordinates into canvas coordinates
	 variable spanx
	 variable spany
	 variable scalex	
	 variable scaley
	 variable xmin  
	 variable ymin  
	 variable xmax  
	 variable ymax  

	 # x-axis, y=0
	 if {$ymin<0 && $ymax>0} {
	    set zero [expr $yplotmin-($scaley*$ymin)]
	    $c create line $xplotmin $zero $xplotmax $zero -width 1 -dash -
	 }
	 # y-axis, x=0
	 if {$xmin<0 && $xmax>0} {
	    set zero [expr $xplotmin-($scalex*$xmin)]
	    $c create line $zero $yplotmin $zero $yplotmax -width 1 -dash -
	 }

	 # x-label
	 variable ticlen
	 variable labelfont
	 variable xlabeltext
	 variable xlabelheight
	 if {[llength $xlabeltext]} {
	    set labelposx [expr $xplotmin+($xplotmax-$xplotmin)*0.5]
	    #set labelposy [expr $yplotmin+$ticlen+$ticlabelheight+0.2*$xlabelheight]
	    set labelposy [expr $canh-$rim-0.2*$xlabelheight]
	    $c create text $labelposx $labelposy -text $xlabeltext -font $labelfont -anchor s
	 }

	 # y-label
	 variable ylabeltext
	 if {[llength $ylabeltext]} {
	    set labelposy [expr $yplotmin+($yplotmax-$yplotmin)*0.5]
	    $c create text $rim $labelposy -text $ylabeltext -font $labelfont -anchor w
	 }

	 # Draw x-tics
	 variable ticfont
	 set i 0 
	 set ticval $xmin
	 variable dimx
	 variable hiticx
	 variable loticx
	 variable minorticx
	 variable ticlabelheight
	 set firstmajor [expr abs(int($loticx-int($loticx/$minorticx)*$minorticx))]
	 #set firstmajor [expr $loticx%$minorticx]
	 set ticlabelposy [expr $yplotmin+$ticlen+0.2*$ticlabelheight]
	 while {$ticval<$hiticx} {
	    set ticval [expr $loticx+$i*$dimx/$minorticx]
	    set x [expr $xplotmin + ($ticval-$xmin)*$scalex]
	    if {![expr ($i-$firstmajor)%$minorticx]} {
	       $c create line $x $yplotmin $x [expr $yplotmin+$ticlen] -width 2
	       $c create text $x $ticlabelposy -text [format "%g" $ticval] -anchor n -font $ticfont
	    } else {
	       $c create line $x $yplotmin $x [expr $yplotmin+0.5*$ticlen] -width 2
	    }
	    incr i
	 }

	 # Draw y-tics
	 set i 0
	 variable dimy
	 variable hiticy
	 variable loticy
	 variable minorticy
	 set firstmajor [expr abs(int($loticy-int($loticx/$minorticy)*$minorticy))]
	 set ticlabelposx [expr $xplotmin-$ticlen-0.2*$ticlabelheight]
	 set ticval $ymin
	 while {$ticval<$hiticy} {
	    set ticval [expr $loticy+$i*$dimy/$minorticy]
	    set y [expr $yplotmin + ($ticval-$ymin)*$scaley]
	    if {![expr ($i-$firstmajor)%$minorticy]} {
	       $c create line $xplotmin $y [expr $xplotmin-$ticlen] $y -width 2
	       $c create text $ticlabelposx $y -text [format "%g" $ticval] -anchor e -font $ticfont
	    } else {
	       $c create line $xplotmin $y [expr $xplotmin-0.5*$ticlen] $y -width 2
	    }
	    incr i
	 }

	 # Draw user specified horizontal lines
	 variable hline
	 foreach line $hline {
	    set y [lindex $line 0]
	    set zero [expr $yplotmin-($scaley*$ymin)]
	    set opt [lrange $line 1 end]
	    set ypos [expr $yplotmin+($scaley*($y-$ymin))]
	    puts "$c create line $xplotmin $ypos $xplotmax $ypos $opt"
	    eval $c create line $xplotmin $ypos $xplotmax $ypos $opt
	 }

	 # Draw user specified vertical lines
	 variable vline
	 foreach line $vline {
	    set x [lindex $line 0]
	    set opt [lrange $line 1 end]
	    set xpos [expr $xplotmin+($scalex*($x-$xmin))]
	    eval $c create line $xpos $yplotmin $xpos $yplotmax $opt
	 }
      }

      proc print_datapoint {x y} {
	 variable xplotmin
	 variable yplotmin
	 variable scalex
	 variable scaley
	 variable xmin
	 variable ymin
	 set coords [format "%8g %8g" [expr ($x-$xplotmin)/$scalex+$xmin] [expr ($y-$yplotmin)/$scaley+$ymin]]
	 puts $coords
      }

      proc draw_infobox {} {
	 variable w
	 variable infoFont
	 labelframe $w.info -text "Info"
	 label $w.info.headx -text [format "%10s" "x"] -font $infoFont
	 label $w.info.heady -text [format "%10s" "y"] -font $infoFont
	 grid $w.info.headx -row 1 -column 2
	 grid $w.info.heady -row 1 -column 3
	 label $w.info.xmint -text "X min: "       -font $infoFont
	 label $w.info.xmin  -textvariable [namespace current]::xmin   -font $infoFont
	 label $w.info.xminy -textvariable [namespace current]::xmin_y -font $infoFont
	 grid $w.info.xmint  -row 2 -column 1
	 grid $w.info.xmin   -row 2 -column 2
	 grid $w.info.xminy  -row 2 -column 3
	 label $w.info.xmaxt -text "X max: "       -font $infoFont
	 label $w.info.xmax  -textvariable [namespace current]::xmax   -font $infoFont
	 label $w.info.xmaxy -textvariable [namespace current]::xmax_y -font $infoFont
	 grid $w.info.xmaxt  -row 3 -column 1
	 grid $w.info.xmax   -row 3 -column 2
	 grid $w.info.xmaxy  -row 3 -column 3
	 label $w.info.ymint -text "Y min: "       -font $infoFont
	 label $w.info.ymin  -textvariable [namespace current]::ymin   -font $infoFont
	 label $w.info.yminx -textvariable [namespace current]::ymin_x -font $infoFont
	 grid $w.info.ymint  -row 4 -column 1
	 grid $w.info.ymin   -row 4 -column 2
	 grid $w.info.yminx  -row 4 -column 3
	 label $w.info.ymaxt -text "Y max: "       -font $infoFont
	 label $w.info.ymax  -textvariable [namespace current]::ymax   -font $infoFont
	 label $w.info.ymaxx -textvariable [namespace current]::ymax_x -font $infoFont
	 grid $w.info.ymaxt  -row 5 -column 1
	 grid $w.info.ymax   -row 5 -column 2
	 grid $w.info.ymaxx  -row 5 -column 3
	 pack  $w.info -side top -pady 2m -ipadx 5m -ipady 2m
      }

      proc savedialog {} {
	 variable w
	 set types {
	    {{Postscript files} {.ps}}
	    {{All files}        *   }
	 }
	 variable postscript
	 set newfile [tk_getSaveFile \
			     -title "Choose file name" -parent $w \
			     -initialdir [pwd] -filetypes $types -initialfile $postscript]
	 variable c
	 if {[llength $newfile]} {
	    $c postscript -file $newfile
	    puts "Printed plot to $newfile."
	 }
      }

      proc xmgracedialog {} {
	 variable w
	 set types {
	    {{xmgrace files} {.agr}}
	    {{All files}        *  }
	 }
	 set newfile [tk_getSaveFile \
                      -title "Choose file name" -parent $w \
                     -initialdir [pwd] -filetypes $types -initialfile "multiplot.agr"]
	 if {[llength $newfile]} {
           [namespace current]::plothandle export xmgrace $newfile
           puts "Printed plot to $newfile, running xmgrace..."
           ::ExecTool::exec xmgrace $newfile &
	 }
      }

   } ; # END namespace $ns

   return "::MultiPlot::Plot${::MultiPlot::plotcount}::plothandle"
}

proc multiplot { args } {
   set keyword [lindex $args 0]
   if {![llength $keyword]} { return }
   if {$keyword=="list"} {
      set plist {}
      foreach plot [namespace children ::MultiPlot "Plot*"] { 
	 lappend plist [subst $plot]::plothandle
      }
      return $plist
   } elseif {$keyword=="reset"} {
      foreach ploth [namespace children ::MultiPlot "Plot*"] {
	 destroy $[subst $ploth]::w;
	 namespace delete $ploth
      }
      return
   }

   set plothandle [::MultiPlot::init_plot]
   #puts "$plothandle configure $args"
   eval $plothandle configure $args

   return $plothandle
}
