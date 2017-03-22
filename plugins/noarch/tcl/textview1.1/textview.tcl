##
## Text Viewer 1.1
##
## A script to view textual (molecule) info via a simple Tk interface
##
## Author: John E. Stone
##         johns@ks.uiuc.edu
##         vmd@ks.uiuc.edu
##
## $Id: textview.tcl,v 1.4 2006/08/20 04:01:07 johns Exp $
##

## Tell Tcl that we're a package and any dependencies we may have
package provide textview 1.1

namespace eval ::TextView:: {
  namespace export textview

  # window handles
  variable w                                          ;# handle to main window
  variable textfile   "untitled.txt"                  ;# text file
}

#
# Create the window and initialize data structures
#
proc ::TextView::textview {{newfile ""}} {
  variable w
  variable textfile

  # If already initialized and no new file requested, just turn on
  if { [string length $newfile ] == 0 && [winfo exists .textview] } {
    wm deiconify $w
    return
  } else {
    if {[string compare $textfile "untitled.txt"] != 0 && [winfo exists .textview]} {
      if {[tk_dialog .textview_yesno {Text Viewer: Warning} "WARNING: Text Viewer can only operate on one file at a time. Currently the file '$textfile' is loaded. If you load '$newfile' instead, all contents and changes to the old text viewer window will be lost.\n\n Do you want to continue loading '$newfile'?" questhead 0 Yes No]} {
        return
      } 
    }
    set textfile "untitled.txt"
  }
 
  # create main window frame 
  set w .textview
  catch {destroy $w} 
  toplevel $w
  wm title $w "Text Viewer: $textfile"
  wm resizable $w 0 0
  wm protocol $w WM_DELETE_WINDOW "menu textview off"

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
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/textview"
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5

  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "New" -command  ::TextView::newfile
  $w.menubar.file.menu add command -label "Open" -command ::TextView::loadfile
  $w.menubar.file.menu add command -label "Save" -command  ::TextView::savefile
  $w.menubar.file.menu add command -label "Save As" -command  ::TextView::saveasfile
  $w.menubar.file config -width 5
  pack $w.menubar.file -side left
  pack $w.menubar.help -side right


  ##
  ## main window area
  ## 
  frame $w.txt
  label $w.txt.label -width 80 -relief sunken -bg White -textvariable ::TextView::textfile
  text $w.txt.text -bg White -bd 2 -yscrollcommand "$::TextView::w.txt.vscr set"
  scrollbar $w.txt.vscr -command "$::TextView::w.txt.text yview"
  pack $w.txt.label 
  pack $w.txt.text $w.txt.vscr -side left -fill y

  pack $w.menubar $w.txt

  ## read in new file, if requested.
  if {[string length $newfile] > 0} {
    set textfile "$newfile"
    if {[catch {open $textfile "r"} fd] } {
      set textfile "untitled.txt"
      return
    }
    wm title $w "Text Viewer: $textfile"
    set line ""
    while {[gets $fd line] != -1} {
      set dtext "$line\n"
      $w.txt.text insert end $dtext
    } 
    close $fd
  }
}

proc ::TextView::newfile { } {
  variable w
  variable textfile

  $w.txt.text delete 1.0 {end - 1c}
  set textfile "untitled.txt"
  wm title $w "Text Viewer: $textfile"
}

proc ::TextView::loadfile { } {
  variable w
  variable textfile

  newfile
   
  set file_types {
    {"Tcl Files" { .tcl .TCL .tk .TK} }
    {"Text Files" { .txt .TXT} }
    {"All Files" * }
  }

  set textfile [tk_getOpenFile -filetypes $file_types \
                -initialdir pwd -initialfile $::TextView::textfile \
                -defaultextension .txt]

  if {[catch {open $textfile "r"} fd] } {
    set textfile "untitled.txt"
    return
  }
  wm title $w "Text Viewer: $textfile"
 
  set line ""
  while {[gets $fd line] != -1} {
    set dtext "$line\n"
    $w.txt.text insert end $dtext
  } 

  close $fd
}

proc ::TextView::savefile { } {
  variable w
  variable textfile

  if {[catch {open $textfile "w"} fd] } {
    tk_dialog .errmsg {Text Viewer Error} "Failed to open file $textfile\n$fd" error 0 Dismiss
    return
  }

  puts $fd [$w.txt.text get 1.0 {end -1c}]

  close $fd
}

proc ::TextView::saveasfile { } {
  variable w
  variable textfile

  set file_types {
    {"Tcl Files" { .tcl .TCL .tk .TK} }
    {"Text Files" { .txt .TXT} }
    {"All Files" * }
  }

  set textfile [tk_getSaveFile -filetypes $file_types \
                -initialdir pwd -initialfile $::TextView::textfile \
                -defaultextension .txt]

  wm title $w "Text Viewer: $textfile"
  if {[catch {open $textfile "w"} fd] } {
    tk_dialog .errmsg {Text Viewer Error} "Failed to open file $textfile\n$fd" error 0 Dismiss
    return
  }

  puts $fd [$w.txt.text get 1.0 {end -1c}]

  close $fd
}

proc textview_tk {} {
  ::TextView::textview
  return $::TextView::w
}

