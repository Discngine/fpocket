
##
## Sting Tool 1.0 
##
## A script to download Sting files through a simple Tk interface
##
## Author: John E. Stone
##         johns@ks.uiuc.edu
##         vmd@ks.uiuc.edu
##
## $Id: stingtool.tcl,v 1.2 2005/07/06 18:08:02 johns Exp $
##

##
## Example code to add this plugin to the VMD extensions menu:
##
#  if { [catch {package require stingtool} msg] } {
#    puts "VMD StingTool package could not be loaded:\n$msg"
#  } elseif { [catch {menu tk register "stingtool" stingtool} msg] } {
#    puts "VMD StingTool could not be started:\n$msg"
#  }


## Tell Tcl that we're a package and any dependencies we may have
package provide stingtool 1.0

package require http 2.4

namespace eval ::StingTool:: {
  namespace export stingtool

  # window handles
  variable w                         ;# handle to main window

  # global settings for work directories etc
  variable pdbcode     ""                  ;# PDB accession code 
  variable chainid     ""                  ;# PDB chain ID
  variable resid     ""                    ;# PDB residue ID
  variable pdbfile     "$pdbcode.pdb"      ;# save to PDB filename
}
  
##
## Main routine
## Create the window and initialize data structures
##
proc ::StingTool::stingtool {} {
  variable w
  variable pdbfile

  # If already initialized, just turn on
  if { [winfo exists .stingtool] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".stingtool"]
  wm title $w "VMD Sting Tool" 
  wm resizable $w 0 0

  ##
  ## make the menu bar
  ## 
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/stingtool"

  frame $w.pdbcode    ;# frame for Sting code
  label $w.pdbcode.label -text "PDB Accession Code:"
  entry $w.pdbcode.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::StingTool::pdbcode
  frame $w.pdbchain
  label $w.pdbchain.label -text "PDB Chain ID:"
  entry $w.pdbchain.entry -width 2 -relief sunken -bd 2 \
    -textvariable ::StingTool::pdbchain
  frame $w.pdbresid
  label $w.pdbresid.label -text "PDB Residue ID:"
  entry $w.pdbresid.entry -width 2 -relief sunken -bd 2 \
    -textvariable ::StingTool::pdbresid
  pack $w.pdbcode.label $w.pdbcode.entry \
       -side left -anchor w
  pack $w.pdbchain.label $w.pdbchain.entry \
       -side left -anchor w
  pack $w.pdbresid.label $w.pdbresid.entry \
       -side left -anchor w

  frame $w.pdbfile    ;# frame for data entry areas
  button $w.pdbfile.download -text "Download to local PDB file" \
    -command "::StingTool::getpdbfile"
  button $w.pdbfile.pdbload -text "Load into new molecule in VMD" -command ::StingTool::pdbload
  button $w.pdbfile.stingreport -text "Browse STING report" -command ::StingTool::stingreport
  button $w.pdbfile.stingmillenium -text "Open STING Millenium" -command ::StingTool::stingmillenium
  button $w.pdbfile.stingramabrowse -text "Browse STING ramachandran server" -command ::StingTool::stingramabrowse
  button $w.pdbfile.stingramaimage -text "Browse STING ramachandran image" -command ::StingTool::stingramaimage
  button $w.pdbfile.pdbmain -text "Browse main Sting web site" -command {vmd_open_url http://trantor.bioc.columbia.edu/SMS/}
  pack $w.pdbfile.download $w.pdbfile.pdbload \
       $w.pdbfile.stingreport \
       $w.pdbfile.stingmillenium \
       $w.pdbfile.stingramabrowse \
       $w.pdbfile.stingramaimage \
       $w.pdbfile.pdbmain \
       -anchor w -fill x


  ## 
  ## pack up the main frame
  ##
  pack \
       $w.pdbcode \
       $w.pdbchain \
       $w.pdbresid \
       $w.pdbfile \
       -side top -pady 10 -fill x -anchor w

  ## trace for picks
  ## disabled until there's a control for it
#  trace variable ::vmd_pick_atom w [namespace code pickhandler]
}


##
## Get directory name
##
proc ::StingTool::getpdbfile {} {
  variable pdbfile 
  variable newfile

  set newfile [tk_getSaveFile \
    -title "Choose filename to save Sting" \
    -initialdir $pdbfile -filetypes {{{Sting files} {.pdb}}} ]

  if {[string length $newfile] > 0} {
    set pdbfile $newfile
  }

  ::StingTool::download ;# go get it
}

proc ::StingTool::download {} {
  variable pdbfile
  variable pdbcode

  set url [format "http://www.rcsb.org/pdb/cgi/export.cgi/%s.pdb?pdbId=%s;format=Sting" $pdbcode $pdbcode] 
  puts "Downloading Sting file from URL:\n  $url"

  vmdhttpcopy $url $pdbfile

  if {[file exists $pdbfile] > 0} {
    if {[file size $pdbfile] > 0} {
      puts "Sting download complete."
    } else {
      file delete -force $pdbfile
      puts "Failed to download Sting file."
    }
  } else {
    puts "Failed to download Sting file."
  }
}

proc ::StingTool::pickhandler {name element op} {
  variable pdbcode
  variable pdbchain
  variable pdbresid
  global vmd_pick_atom
  global vmd_pick_mol
  global vmd_pick_shift_state

  set sel [atomselect $vmd_pick_mol "index $vmd_pick_atom"]
  set pdbchain [$sel get chain]
  set pdbresid [$sel get resid]
  puts "Pick info:"
  puts "  molecule: $pdbcode"
  puts "  chain: $pdbchain"
  if {![string compare "X" $pdbchain]} {
    puts "  Renaming chain X back to blank chain"
    set pdbchain ""
  }
  puts "  resid: $pdbresid"
  puts " running stingreport..."

  ::StingTool::stingreport

  puts " finished stingreport..."
}

proc ::StingTool::browse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://www.rcsb.org/pdb/cgi/explore.cgi?pdbId=%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid Sting accession code."
  }
}


proc ::StingTool::stingreport {} {
  variable pdbcode
  variable pdbchain
  variable pdbresid
 
  puts "calling sting report ... "
 
  if {[string length $pdbcode] > 0} {
    set url [format "http://trantor.bioc.columbia.edu/cgi-bin/SMS/smsReport/smsReport.pl?%s,%s,%s" $pdbcode $pdbchain $pdbresid]
    vmd_open_url $url
  } else {
    puts "Please enter a valid Sting accession code."
  }
}

proc ::StingTool::stingmillenium {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://trantor.bioc.columbia.edu/cgi-bin/SMS/STINGm/frame_java.pl?%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid Sting accession code."
  }
}

proc ::StingTool::stingramabrowse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://trantor.bioc.columbia.edu/cgi-bin/SMS/STINGm/frame_java.pl?moduleOpen=Ramachandran&%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid Sting accession code."
  }
}

proc ::StingTool::stingramaimage {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://trantor.bioc.columbia.edu/cgi-bin/SMS/ramachandran/ramachandran.pl?pdb=%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid Sting accession code."
  }
}

proc ::StingTool::pdbload {} {
  variable pdbfile
  variable pdbcode

  if {[string length $pdbcode] > 0} {
    mol new $pdbcode
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

# This gets called by VMD the first time the menu is opened.
proc stingtool_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::StingTool::w  }]  ;# destroy any old windows

  ::StingTool::stingtool   ;# start the Sting Tool 
  return $StingTool::w
}
