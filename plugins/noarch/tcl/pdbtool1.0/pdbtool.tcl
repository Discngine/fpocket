##
## PDB Tool 1.0 
##
## A script to download PDB files through a simple Tk interface
##
## Author: John E. Stone
##         johns@ks.uiuc.edu
##         vmd@ks.uiuc.edu
##
## $Id: pdbtool.tcl,v 1.10 2006/02/16 21:22:16 johns Exp $
##

##
## Example code to add this plugin to the VMD extensions menu:
##
#  if { [catch {package require pdbtool} msg] } {
#    puts "VMD PDBTool package could not be loaded:\n$msg"
#  } elseif { [catch {menu tk register "pdbtool" pdbtool} msg] } {
#    puts "VMD PDBTool could not be started:\n$msg"
#  }


## Tell Tcl that we're a package and any dependencies we may have
package provide pdbtool 1.0

package require http 2.4

namespace eval ::PDBTool:: {
  namespace export pdbtool

  # window handles
  variable w                         ;# handle to main window

  # global settings for work directories etc
  variable pdbcode     ""                  ;# PDB accession code 
  variable pdbfile     "$pdbcode.pdb"      ;# save to PDB filename
}
  
##
## Main routine
## Create the window and initialize data structures
##
proc ::PDBTool::pdbtool {} {
  variable w
  variable pdbfile

  # If already initialized, just turn on
  if { [winfo exists .pdbtool] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".pdbtool"]
  wm title $w "VMD PDB Tool" 
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
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/pdbtool"

  frame $w.pdbcode    ;# frame for PDB code
  label $w.pdbcode.label -text "PDB Accession Code:"
  entry $w.pdbcode.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::PDBTool::pdbcode
  pack $w.pdbcode.label $w.pdbcode.entry -side left -anchor w

  frame $w.pdbfile    ;# frame for data entry areas
  button $w.pdbfile.download -text "Download to local PDB file" \
    -command "::PDBTool::getpdbfile"
  button $w.pdbfile.pdbload -text "Load into new molecule in VMD" -command ::PDBTool::pdbload
  button $w.pdbfile.scop -text "Browse entry in the SCOP database" -command ::PDBTool::scop
  button $w.pdbfile.procheckbrowse -text "View Procheck at PDBsum server" -command ::PDBTool::procheckbrowse
  button $w.pdbfile.cathbrowse -text "Browse entry at CATH server" -command ::PDBTool::cathbrowse
  button $w.pdbfile.edsbrowse -text "Browse entry at Uppsala electron density server" -command ::PDBTool::edsbrowse
  button $w.pdbfile.ramabrowse -text "Browse entry at Uppsala Ramachandran server" -command ::PDBTool::ramabrowse
  button $w.pdbfile.browse -text "Browse entry on the PDB" -command ::PDBTool::browse
  button $w.pdbfile.pdbmain -text "Browse main PDB web site" -command {vmd_open_url http://www.rcsb.org/}
  pack $w.pdbfile.download $w.pdbfile.pdbload \
       $w.pdbfile.scop \
       $w.pdbfile.procheckbrowse $w.pdbfile.cathbrowse \
       $w.pdbfile.edsbrowse $w.pdbfile.ramabrowse \
       $w.pdbfile.browse $w.pdbfile.pdbmain \
       -anchor w -fill x


  ## 
  ## pack up the main frame
  ##
  pack \
       $w.pdbcode \
       $w.pdbfile \
       -side top -pady 10 -fill x -anchor w
}


##
## Get directory name
##
proc ::PDBTool::getpdbfile {} {
  variable pdbcode
  variable pdbfile 
  variable newfile

  set newfile [tk_getSaveFile \
    -title "Choose filename to save PDB" \
    -initialdir [file dirname $pdbfile] -initialfile $pdbcode.pdb -filetypes {{{PDB files} {.pdb}}} ]

  if {[string length $newfile] > 0} {
    set pdbfile $newfile
  }

  ::PDBTool::download ;# go get it
}

proc ::PDBTool::download {} {
  variable pdbfile
  variable pdbcode

  ## Adapted to new PDB website layout, changed on 1/1/2006
  set url [format "http://www.rcsb.org/pdb/downloadFile.do?fileFormat=pdb&compression=NO&structureId=%s" $pdbcode] 
  puts "Downloading PDB file from URL:\n  $url"

  vmdhttpcopy $url $pdbfile

  if {[file exists $pdbfile] > 0} {
    if {[file size $pdbfile] > 0} {
      puts "PDB download complete."
    } else {
      file delete -force $pdbfile
      puts "Failed to download PDB file."
    }
  } else {
    puts "Failed to download PDB file."
  }
}


proc ::PDBTool::browse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://www.rcsb.org/pdb/cgi/explore.cgi?pdbId=%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::scop {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://scop.mrc-lmb.cam.ac.uk/scop/search.cgi?key=%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::procheckbrowse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
     # Old site is now dead
     #    set url [format "http://www.biochem.ucl.ac.uk/bsm/pdbsum/%s/procheck.html" $pdbcode]

    # new PDBsum site
    set url [format "http://www.ebi.ac.uk/thornton-srv/databases/cgi-bin/pdbsum/GetPage.pl?template=main.html&o=PROCHECK&c=999&pdbcode=%s" $pdbcode]

    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::cathbrowse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://www.biochem.ucl.ac.uk/cgi-bin/cath/SearchPdb.pl?query=%s&type=PDB" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::edsbrowse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
# Old EDS server URL
#    set url [format "http://portray.bmc.uu.se/cgi-bin/neweds/uusfs?pdbCode=%s" $pdbcode]
# New EDS server URL
    set url [format "http://fsrv1.bmc.uu.se/cgi-bin/eds/uusfs?pdbCode=%s" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::ramabrowse {} {
  variable pdbfile
  variable pdbcode
  
  if {[string length $pdbcode] > 0} {
    set url [format "http://fsrv1.bmc.uu.se/cgi-bin/eds/rama?pdbCode=%s&ramaServer=YES" $pdbcode]
    vmd_open_url $url
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

proc ::PDBTool::pdbload {} {
  variable pdbfile
  variable pdbcode

  if {[string length $pdbcode] > 0} {
    mol new $pdbcode
  } else {
    puts "Please enter a valid PDB accession code."
  }
}

# This gets called by VMD the first time the menu is opened.
proc pdbtool_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::PDBTool::w  }]  ;# destroy any old windows

  ::PDBTool::pdbtool   ;# start the PDB Tool 
  return $PDBTool::w
}

