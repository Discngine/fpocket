#
# NAMD log file plotting tool
#
# $Id: namdplot.tcl,v 1.13 2007/08/29 16:04:05 johns Exp $
#
# Authors:  Jim Phillips, John Stone
#
# Examples:
#   namdplot
#   namdplot apoa1.log
#   namdplot TIMING apoa1.log
#   namdplot MEMORY apoa1.log
#   namdplot ELECT VDW apoa1.log
#   namdplot zero ELECT VDW apoa1.log
#   namdplot diff TOTAL apoa1.log
#   namdplot TOTAL vs TEMP apoa1.log
#
#

package provide namdplot 1.0

# Use Jan's plotting tool to display NAMD data
package require multiplot

namespace eval ::NAMDPlot:: {
  namespace export namdplot
  variable w
  variable logfile         ""

  variable yplotts         "0"
  variable yplotbond       "0"
  variable yplotangle      "0"
  variable yplotdihed      "0"
  variable yplotimprp      "0"
  variable yplotelect      "0"
  variable yplotvdw        "0"
  variable yplotboundary   "0"
  variable yplotmisc       "0"
  variable yplotkinetic    "0"
  variable yplottotal      "0"
  variable yplottemp       "0"
  variable yplottotal2     "0"
  variable yplottotal3     "0"
  variable yplottempavg    "0"
  variable yplotpressure   "0"
  variable yplotgpressure  "0"
  variable yplotvolume     "0"
  variable yplotpressavg   "0"
  variable yplotgpressavg  "0"
  variable yplottiming     "0"
  variable yplotmemory     "0"
  variable xplot           "TS"
}

proc ::NAMDPlot::tclgrep { pattern filename } {
  set infile [open $filename "r"]
  while { [gets $infile line] >= 0 } {
    set match [regexp -- $pattern $line matchstr]
    if { $match } {
      puts "$line"
    }
  }
  close $infile
}


# parse NAMD output
# set foo [namdparse /home/johns/imd-glpf.log]
# examples retrieve ts value for 2nd energy output line
# puts [lindex [lindex [lindex [lindex $foo 0] 1] 1] 0]
proc ::NAMDPlot::namdparse { namdlogfilename } {
  set energydata {}
  set timingdata {}
  set energycolumns {}

  set timingcolumns [list TS "CPU Seconds" "CPU Seconds/step" \
    "Wall Seconds" "Wall Seconds/step" "Hours remaining" "kB memory in use" ]

  set infile [open $namdlogfilename "r"]
  while { [gets $infile line] >= 0 } {
    if { [regexp -- "ETITLE:" $line] } {
      set energycolumns [lrange [concat $line] 1 end]
      break
    }
  }
  set numenergycolumns [llength $energycolumns]
  while { [gets $infile line] >= 0 } {
    if { [regexp -- "ENERGY:" $line] } {
      set energies [lrange [concat $line] 1 end]
      if { [llength $energies] != $numenergycolumns } { break }
      lappend energydata $energies
    } elseif { [regexp -- "TIMING:" $line] }  { 
      scan $line "TIMING:%d  CPU: %f, %f/step  Wall:%f,%f/step, %f hours remaining, %d kB of memory in use." ts cpusec cpusecstep wallsec wallsecstep hoursremaining meminuse 
      lappend timingdata [list $ts $cpusec $cpusecstep \
        $wallsec $wallsecstep $hoursremaining $meminuse]
    }
  }

  return [list \
    [list $energycolumns $energydata] \
    [list $timingcolumns $timingdata] ]
}


# this is the syntax from the shell script we should replicate:
# namdplot [zero] [diff] [<yfield> [<yfield> ...] [vs <xfield>]] <file>
proc ::NAMDPlot::namdplot { args } {
  if { [llength $args] == 0 } {
    error "Usage: namdplot ?zero? ?diff? ?from <first>? ?to <last>? ?<yfield> ...? ?vs <xfield>? <file>\nPlotting TIMING or MEMORY are supported as special cases."
  }

  # strip off the last argument and parse it as a NAMD log file
  set namdlogfilename [lindex $args end]
  set args [lrange $args 0 end-1]
  set namddata [namdparse $namdlogfilename]
  set etitles [lindex [lindex $namddata 0] 0]
  set evalues [lindex [lindex $namddata 0] 1]
  set havetiming [llength [lindex [lindex $namddata 1] 1]]

  set alltitles $etitles
  if { $havetiming } { lappend alltitles TIMING MEMORY }

  # if nothing to plot just return available fields
  if { [llength $args] == 0 } {
    return $alltitles
  }

  set comment ""

  # check for "zero" flag (subtract off initial value)
  if { [string equal [lindex $args 0] "zero"] } {
    set comment " cumulative change in"
    set zero 1
    set args [lrange $args 1 end]
  } else {
    set zero 0
  }

  # check for "diff" flag (computing running difference)
  if { [string equal [lindex $args 0] "diff"] } {
    set comment " running change in"
    set diff 1
    set args [lrange $args 1 end]
  } else {
    set diff 0
  }

  # check for "from" flag (first step)
  if { [string equal [lindex $args 0] "from"] } {
    set first_step [lindex $args 1]
    set args [lrange $args 2 end]
  } else {
    set first_step -Inf
  }

  # check for "to" flag (last step)
  if { [string equal [lindex $args 0] "to"] } {
    set last_step [lindex $args 1]
    set args [lrange $args 2 end]
  } else {
    set last_step Inf
  }

  set ytargets [list]
  set ytargetnames [list]

  # check for special case y-axis variables TIMING and MEMORY
  while { [lsearch -exact [list TIMING MEMORY] [lindex $args 0]] != -1 } {
    if { ! $havetiming } {
      error "Timing and memory data not found."
    }
    set etitles [lindex [lindex $namddata 1] 0]
    set evalues [lindex [lindex $namddata 1] 1]
    switch -exact [lindex $args 0] {
      TIMING { set i 4 }
      MEMORY { set i 6 }
    }
    lappend ytargets $i
    lappend ytargetnames [lindex $etitles $i]
    set args [lrange $args 1 end]
  }

  # get list of y-axis variables to plot
  while { [llength $args] && ! [string equal [lindex $args 0] "vs"] } {
    set fieldname [lindex $args 0]
    set args [lrange $args 1 end]
    set pos [lsearch -exact $etitles $fieldname]
    if { $pos == -1 } {
      error "Y-axis field \"$fieldname\" not found.  Available fields: $etitles"
    }
    lappend ytargets $pos
    lappend ytargetnames $fieldname
  }
  if { [llength $ytargets] == 0 } {
    error "No y-axis fields specified.  Available fields: $etitles"
  }

  # get optional x-axis variable to plot against, indicated by "vs" flag
  set xtarget 0
  set xtargetname [lindex $etitles 0]
  if { [string equal [lindex $args 0] "vs"] } {
    if { [llength $args] < 2 } {
      error "No x-axis field specified after \"vs\"."
    }
    set fieldname [lindex $args 1]
    set args [lrange $args 2 end]
    set pos [lsearch -exact $etitles $fieldname]
    if { $pos == -1 } {
      error "X-axis field \"$fieldname\" not found.  Available fields: $etitles"
    }
    set xtarget $pos
    set xtargetname $fieldname
  }

  # build data arrays for plotter, modifying y-axis values if specified
  set xarr [list]
  foreach step $evalues {
    set ts [lindex $step 0]
    if { $ts < $first_step || $ts > $last_step } continue
    lappend xarr [lindex $step $xtarget]
  }
  set yarr [list]
  foreach i $ytargets {
    set arr [list]
    if { $diff } {
      # diff: running difference, first since "diff zero" is same as just diff
      set baseval [lindex [lindex $evalues 0] $i]
      foreach step $evalues {
        set ts [lindex $step 0]
        if { $ts < $first_step || $ts > $last_step } continue
        set val [lindex $step $i]
        lappend arr [expr $val - $baseval]
        set baseval $val
      }
    } elseif { $zero } {
      # zero: change from initial value
      set baseval [lindex [lindex $evalues 0] $i]
      foreach step $evalues {
        set ts [lindex $step 0]
        if { $ts < $first_step || $ts > $last_step } continue
        lappend arr [expr [lindex $step $i] - $baseval]
      }
    } else {
      # plot values as-is
      foreach step $evalues {
        set ts [lindex $step 0]
        if { $ts < $first_step || $ts > $last_step } continue
        lappend arr [lindex $step $i]
      }
    }
    lappend yarr $arr
  }

  # format the title, having the plotter allow a legend would be nice
  set title [format "%s%s %s vs %s" $namdlogfilename $comment [join $ytargetnames ", "] $xtargetname]

  # feed everything to the plotter
  #
  # XXX we should be selecting the Y-axis based on what has been selected
  # for plotting.
  #
  set plothandle [multiplot -title $title -xlabel $xtargetname -ylabel "E(kcal/mol)"]

  set colorlist {Skyblue3 red darkgreen orange pink cyan tan maroon purple green grey yellow white darkgreen silver lime}
  set i 0
  foreach y $yarr ename $ytargetnames {
     if {[llength $xarr]!=[llength $y]} { error "X and Y data vectors have different size ([llength $xarr]!=[llength $y])!" }
     set color [lindex $colorlist $i]
     # puts "Plotting $ename vs $xtargetname in $color ([llength $y] datapoints)."
     $plothandle add $xarr $y -lines -linewidth 1 -linecolor $color -marker none -legend $ename
     incr i
  }
  $plothandle replot
}

# make this available globally
namespace import ::NAMDPlot::namdplot


#
# Now on to the GUI..
#

proc ::NAMDPlot::guiplot {} {
  variable logfile
  variable yplotts
  variable yplotbond
  variable yplotangle
  variable yplotdihed
  variable yplotimprp
  variable yplotelect 
  variable yplotvdw
  variable yplotboundary
  variable yplotmisc
  variable yplotkinetic
  variable yplottotal
  variable yplottemp
  variable yplottotal2
  variable yplottotal3
  variable yplottempavg
  variable yplotpressure
  variable yplotgpressure
  variable yplotvolume
  variable yplotpressavg
  variable yplotgpressavg
  variable yplottiming
  variable yplotmemory
  variable xplot

  set ylist {}

  if { $yplotts        } { lappend ylist "TS"        }
  if { $yplotbond      } { lappend ylist "BOND"      }
  if { $yplotangle     } { lappend ylist "ANGLE"     }
  if { $yplotdihed     } { lappend ylist "DIHED"     }
  if { $yplotimprp     } { lappend ylist "IMPRP"     }
  if { $yplotelect     } { lappend ylist "ELECT"     }
  if { $yplotvdw       } { lappend ylist "VDW"       }
  if { $yplotboundary  } { lappend ylist "BOUNDARY"  }
  if { $yplotmisc      } { lappend ylist "MISC"      }
  if { $yplotkinetic   } { lappend ylist "KINETIC"   }
  if { $yplottotal     } { lappend ylist "TOTAL"     }
  if { $yplottemp      } { lappend ylist "TEMP"      }
  if { $yplottotal2    } { lappend ylist "TOTAL2"    }
  if { $yplottotal3    } { lappend ylist "TOTAL3"    }
  if { $yplottempavg   } { lappend ylist "TEMPAVG"   }
  if { $yplotpressure  } { lappend ylist "PRESSURE"  }
  if { $yplotgpressure } { lappend ylist "GPRESSURE" }
  if { $yplotvolume    } { lappend ylist "VOLUME"    }
  if { $yplotpressavg  } { lappend ylist "PRESSAVG"  }
  if { $yplotgpressavg } { lappend ylist "GPRESSAVG" }

#  if { $yplottiming    } { lappend ylist "TIMING"    }
#  if { $yplotmemory    } { lappend ylist "MEMORY"    }

  if { [string length $logfile] < 1 } {
    tk_dialog .errmsg {NamdPlot Error} "No logfile selected." error 0 Dismiss
    return
  }

  set len [llength $ylist]
  if { $len < 1 } {
    tk_dialog .errmsg {NamdPlot Error} "No data fields selected." error 0 Dismiss
    return
  } else {
    # check plot list versus what we really have here...
    set havedata [::NAMDPlot::namdplot $logfile]
    for { set i 0 } { $i < $len } { incr i } {
      set fieldname [lindex $ylist $i]
      if { [lsearch -exact $ylist $fieldname] == -1 } {
        tk_dialog .errmsg {NamdPlot Error} "Failed to find data field $fieldname in log file." error 0 Dismiss
        return 
      }
    }
  } 

  eval ::NAMDPlot::namdplot $ylist vs $xplot [list $logfile]
}


#
# Create the window and initialize data structures
#
proc ::NAMDPlot::namdplot_gui {} {
  variable w
  variable logfile

  # If already initialized, just turn on
  if { [winfo exists .namdplot] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".namdplot"]
  wm title $w "NAMD Plot"
  wm resizable $w 0 0

  ##
  ## make the menu bar
  ##
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
  menubutton $w.menubar.file -text File -underline 0 -menu $w.menubar.file.menu

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/namdplot"
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5

  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Select NAMD Log File" -command  { 
    set tempfile [tk_getOpenFile -title "NAMD Log File"]
    if {![string equal $tempfile ""]} { set ::NAMDPlot::logfile $tempfile }
  }
  $w.menubar.file.menu add command -label "Plot Selected Data" -command ::NAMDPlot::guiplot
  $w.menubar.file config -width 5
  pack $w.menubar.file -side left
  pack $w.menubar.help -side right


  ##
  ## main window area
  ## 
  frame $w.logfile
  label $w.logfile.text -text "NAMD Log File: " 
  label $w.logfile.label -textvariable ::NAMDPlot::logfile -width 30
  pack $w.logfile.text $w.logfile.label -side left -anchor w

  frame $w.options
  label $w.options.ytext -text "Plot on Y axis:"
  checkbutton $w.options.yp1  -anchor w -relief groove -width 12 -text "TS"         -variable ::NAMDPlot::yplotts
  checkbutton $w.options.yp2  -anchor w -relief groove -width 12 -text "BOND"       -variable ::NAMDPlot::yplotbond
  checkbutton $w.options.yp3  -anchor w -relief groove -width 12 -text "ANGLE"      -variable ::NAMDPlot::yplotangle
  checkbutton $w.options.yp4  -anchor w -relief groove -width 12 -text "DIHED"      -variable ::NAMDPlot::yplotdihed
  checkbutton $w.options.yp5  -anchor w -relief groove -width 12 -text "IMPRP"      -variable ::NAMDPlot::yplotimprp
  checkbutton $w.options.yp6  -anchor w -relief groove -width 12 -text "ELECT"      -variable ::NAMDPlot::yplotelect  
  checkbutton $w.options.yp7  -anchor w -relief groove -width 12 -text "VDW"        -variable ::NAMDPlot::yplotvdw
  checkbutton $w.options.yp8  -anchor w -relief groove -width 12 -text "BOUNDARY"   -variable ::NAMDPlot::yplotboundary
  checkbutton $w.options.yp9  -anchor w -relief groove -width 12 -text "MISC"       -variable ::NAMDPlot::yplotmisc
  checkbutton $w.options.yp10 -anchor w -relief groove -width 12 -text "KINETIC"    -variable ::NAMDPlot::yplotkinetic
  checkbutton $w.options.yp11 -anchor w -relief groove -width 12 -text "TOTAL"      -variable ::NAMDPlot::yplottotal
  checkbutton $w.options.yp12 -anchor w -relief groove -width 12 -text "TEMP"       -variable ::NAMDPlot::yplottemp
  checkbutton $w.options.yp13 -anchor w -relief groove -width 12 -text "TOTAL2"     -variable ::NAMDPlot::yplottotal2
  checkbutton $w.options.yp14 -anchor w -relief groove -width 12 -text "TOTAL3"     -variable ::NAMDPlot::yplottotal3
  checkbutton $w.options.yp15 -anchor w -relief groove -width 12 -text "TEMPAVG"    -variable ::NAMDPlot::yplottempavg
  checkbutton $w.options.yp16 -anchor w -relief groove -width 12 -text "PRESSURE"   -variable ::NAMDPlot::yplotpressure
  checkbutton $w.options.yp17 -anchor w -relief groove -width 12 -text "GPRESSURE"  -variable ::NAMDPlot::yplotgpressure
  checkbutton $w.options.yp18 -anchor w -relief groove -width 12 -text "VOLUME"     -variable ::NAMDPlot::yplotvolume
  checkbutton $w.options.yp19 -anchor w -relief groove -width 12 -text "PRESSAVG"   -variable ::NAMDPlot::yplotpressavg
  checkbutton $w.options.yp20 -anchor w -relief groove -width 12 -text "GPRESSAVG"  -variable ::NAMDPlot::yplotgpressavg
#  checkbutton $w.options.yp21 -width 12 -text "TIMING"     -variable ::NAMDPlot::yplottiming
#  checkbutton $w.options.yp22 -width 12 -text "MEMORY"     -variable ::NAMDPlot::yplotmemory

  label $w.options.xtext -text "Plot on X axis:" -anchor w
  radiobutton $w.options.xaxis -anchor w -text "TS"        -variable ::NAMDPlot::xplot -value "TS"


#  pack $w.options.ytext \
#       $w.options.yp1  $w.options.yp2  $w.options.yp3  $w.options.yp4 \
#       $w.options.yp5  $w.options.yp6  $w.options.yp7  $w.options.yp8 \
#       $w.options.yp9  $w.options.yp10 $w.options.yp11 $w.options.yp12 \
#       $w.options.yp13 $w.options.yp14 $w.options.yp15 $w.options.yp16 \
#       $w.options.yp17 $w.options.yp18 $w.options.yp19 $w.options.yp20 \
#       $w.options.xtext \
#       $w.options.xaxis -side bottom -anchor w
#
## disable timing and memory buttons for now
#       $w.options.yp21 $w.options.yp22 \

  grid $w.options.ytext -row 0
  grid $w.options.yp2  $w.options.yp3  $w.options.yp4  $w.options.yp5  -row 1 -sticky w
  grid $w.options.yp6  $w.options.yp7  $w.options.yp8  $w.options.yp9  -row 2 -sticky w
  grid $w.options.yp10 $w.options.yp11 $w.options.yp12 $w.options.yp13 -row 3 -sticky w
  grid $w.options.yp14 $w.options.yp15 $w.options.yp16 $w.options.yp17 -row 4 -sticky w
  grid $w.options.yp18 $w.options.yp19 $w.options.yp20 -row 5 -sticky w
  grid $w.options.xtext 
  grid $w.options.xaxis

  pack $w.menubar $w.logfile $w.options
}


proc namdplot_tk {} {
  ::NAMDPlot::namdplot_gui
  return $::NAMDPlot::w
}

