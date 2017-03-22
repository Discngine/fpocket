##
## VMD DemoMaster plugin
##
## This plugin provides a complete solution for creating simple 
## demonstrations with Tk menus, keyboard/joystick/spaceball control buttons,
## and fully-automatic timed demo loops.  Future versions of the plugin
## will integrate with the Movie plugin and provide a means to automatically
## build a movie sequence from the demo.
##
## Author: John E. Stone
##         vmd@ks.uiuc.edu
##
## $Id: demomaster.tcl,v 1.5 2006/03/31 19:36:38 johns Exp $
##

package provide demomaster 0.1

##
## Everything below makes up the core of the plugin
##
namespace eval ::DemoMaster:: {
  variable usetkwindow  0
  variable tkw          ""
  variable buttonnames  {}
  variable buttoncmds   {}
  variable buttonindex  -1
  variable currentindex  0
  variable nextkey      "+"
  variable prevkey      "-"
  variable verbose       0
}

proc ::DemoMaster::reset {} {
  variable usetkwindow
  variable tkw
  variable buttonnames 
  variable buttoncmds
  variable buttontimes
  variable buttonindex
  variable nextkey
  variable prevkey
  variable verbose

  if { $usetkwindow } {
    puts "deleting existing Tk demo window"
    # after idle destroy $tkw
    destroy $tkw
  }

  set usetkwindow   0
  set buttonnames  {} 
  set buttoncmds   {}
  set buttontimes  {}
  set buttonindex  -1
  set currentindex  0
  set nextkey      "+"
  set prevkey      "-"
  set verbose       0
}

proc ::DemoMaster::printstatus {} {
  variable usetkwindow
  variable buttonnames 
  variable buttoncmds
  variable buttontimes
  variable buttonindex
  variable nextkey
  variable prevkey

  if { $usetkwindow } {
    puts "Using Tk Window for demo button controls"
  } else {
    puts "Using Hotkeys for demo button controls"
  }
  puts "Assigned Next Hotkey: '$nextkey'"
  puts "Assigned Prev Hotkey: '$prevkey'"
  for {set j 0} {$j <= $buttonindex} {incr j} {
    set cmd [lindex $buttoncmds $j]
    puts "  Button $j: '$cmd'" 
  }  
}


proc ::DemoMaster::verbose { mode } {
  variable verbose
  set verbose $mode
}


proc ::DemoMaster::usewindow { windowname windowtitle } {
  variable usetkwindow
  variable tkw
  global tk_version

  if { [info exists tk_version] } {
    set usetkwindow 1
    set tkw [toplevel $windowname]
    wm title $tkw $windowtitle
  } else {
    puts "Tk not available for demo control window"
    set usetkwindow 0
  }
}

proc ::DemoMaster::addbutton { text cmd seconds } {
  variable usetkwindow
  variable tkw
  variable buttonnames 
  variable buttoncmds
  variable buttontimes
  variable buttonindex

  incr buttonindex 
  lappend buttonnames $text
  lappend buttoncmds  $cmd
  lappend buttontimes $seconds
  if { $usetkwindow } {
    set newcmd [format "::DemoMaster::runbutton $buttonindex"]
    return [button $tkw.b_$buttonindex -text $text -width 12 \
            -command $newcmd]
  }
}

proc ::DemoMaster::addcheckbutton { text var cmd } {
  variable usetkwindow
  variable tkw
  variable buttonnames 
  variable buttoncmds
  variable buttontimes
  variable buttonindex

  incr buttonindex 
  lappend buttonnames $text
  lappend buttoncmds  $cmd

  if { $usetkwindow } {
    set newcmd [format "::DemoMaster::runbutton $buttonindex"]
    return [checkbutton $tkw.b_$buttonindex \
            -text $text \
            -variable $var \
            -anchor center \
            -indicatoron false \
            -selectcolor darkgray \
            -highlightthickness 0 \
            -width 15 \
            -command $newcmd]
  }
}

proc ::DemoMaster::packbuttons {} {
  variable usetkwindow
  variable tkw
  variable buttonindex
 
  if { $usetkwindow } {
    for { set j 0} {$j <= $buttonindex} {incr j} {
#      puts "packing: $tkw.b_$j"
      pack $tkw.b_$j
    }
  }
}


proc ::DemoMaster::runbutton { button } {
  variable buttonnames 
  variable buttoncmds
  variable buttonindex

  if { $button < 0} {
    puts "DemoMaster: illegal button $button specified"
    return
  } elseif { $button > $buttonindex } {
    puts "DemoMaster: illegal button $button specified"
    return
  }
  
  puts "Demo button: [lindex $buttonnames $button]"
  eval [lindex $buttoncmds $button]
}

proc ::DemoMaster::wrapbuttonindex { index } {
  variable buttonindex
  if { $index > $buttonindex } {
    set index 0
  } elseif { $index < 0 } {
    set index $buttonindex
  }

  return $index
}

proc ::DemoMaster::next {} {
  variable buttonnames 
  variable buttoncmds
  variable buttonindex
  variable currentindex
 
  incr currentindex
  set currentindex [wrapbuttonindex $currentindex]

  runbutton $currentindex
}

proc ::DemoMaster::prev {} {
  variable buttonnames 
  variable buttoncmds
  variable buttonindex
  variable currentindex

  incr currentindex -1
  set currentindex [wrapbuttonindex $currentindex]

  runbutton $currentindex
}

proc ::DemoMaster::autorun { } {
  variable buttonnames 
  variable buttoncmds
  variable buttontimes
  variable buttonindex
  variable currentindex
  variable verbose

  for { set i 0 } { $i <= $buttonindex } { incr i } {
    set starttime [clock seconds]
    set waittime [lindex $buttontimes $i]
    if { $verbose } {
      puts "Running button $i for $waittime seconds..."
    }
    runbutton $i
    while {[expr [clock seconds] - $starttime < $waittime]} {
      update
      flush stdout
      display update ui
    }
  }
}


proc ::DemoMaster::registernexthotkey { hotkey } {
  variable nextkey
  set nextkey $hotkey
  user add key $hotkey { ::DemoMaster::next }
}

proc ::DemoMaster::registerprevhotkey { hotkey } {
  variable prevkey
  set prevkey $hotkey
  user add key $hotkey { ::DemoMaster::prev }
}



##
## Example proc, illustrating how one can create a simple demo toolbar
## with keyboard and joystick forward/back controls, etc.
##
proc ::DemoMaster::selftest {} {
  ::DemoMaster::reset
  ::DemoMaster::usewindow .test "Test VMD Demo Window #1"

  ::DemoMaster::addbutton {Start Demo} { puts "start demo" }  1 
  ::DemoMaster::addbutton {Button 1} { puts "button 1" }  1 
  ::DemoMaster::addbutton {Button 2} { puts "button 2" }  1 
  ::DemoMaster::addbutton {Button 3} { puts "button 3" }  1 
  ::DemoMaster::addbutton {Button 4} { puts "button 4" }  1 

  ::DemoMaster::packbuttons

  ::DemoMaster::registernexthotkey 1
  ::DemoMaster::registerprevhotkey 2

  ::DemoMaster::printstatus

  ::DemoMaster::autorun
}




