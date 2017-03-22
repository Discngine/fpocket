
# Plugin: Data import maps data extracted from a txt file to the beta field 
# of a new pdb file. 
#
# Author: Marcos Sotomayor
# 
# TODO?
# Everything

package provide dataimport 1.0


namespace eval ::Dataimport:: {
  namespace export dataimport_gui
                                                                                
  variable w
                                                                                
  variable pdbfile
  variable txtfile
  variable outprefix
}


proc ::Dataimport::dataimport_gui {} {
  variable w

  variable pdbfile
  variable txtfile
  variable outprefix

  ::Dataimport::init_gui

  if { [winfo exists .dataimportgui] } {
    wm deiconify .dataimportgui
    return
  }
  set w [toplevel ".dataimportgui"]
  wm title $w "Data Import"

  frame $w.intro
  grid [label $w.intro.label -text "Data import maps data from a txt file to the beta column
of a pdb file. A new pdb file is generated."] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid columnconfigure $w.intro 1 -weight 1
  pack $w.intro -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.input
  grid [label $w.input.label -text "Input"] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid [label $w.input.pdblabel -text "PDB file: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.input.pdbpath -width 30 -textvariable ::Dataimport::pdbfile] \
    -row 1 -column 1 -sticky ew
  grid [button $w.input.pdbbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dataimport::pdbfile $tempfile }
    }] -row 1 -column 2 -sticky w
  grid [label $w.input.txtlabel -text "TXT file: "] \
    -row 2 -column 0 -sticky w
  grid [entry $w.input.txtpath -width 30 -textvariable ::Dataimport::txtfile] \
    -row 2 -column 1 -sticky ew
  grid [button $w.input.txtbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dataimport::txtfile $tempfile }
    }] -row 2 -column 2 -sticky w
  grid [label $w.input.label2 -text "Format:"] \
    -row 3 -column 0 -columnspan 3 -sticky w
  grid [label $w.input.label3 -text "<residue \#>  <chain>  <value>"] \
    -row 3 -column 1 -columnspan 3 -sticky w
  grid [label $w.input.label4 -text "<chain> = * => all protein chains"] \
    -row 4 -column 1 -columnspan 3 -sticky w

  grid columnconfigure $w.input 1 -weight 1
  pack $w.input -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.output
  grid [label $w.output.label -text "Output prefix:"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [entry $w.output.outpath -width 30 -textvariable ::Dataimport::outprefix] \
    -row 0 -column 1 -sticky ew
  grid columnconfigure $w.output 0 -weight 1
  pack $w.output -side top -padx 10 -pady 10 -expand 1 -fill x 

  pack [button $w.solvate -text "Map data to beta column" -command ::Dataimport::run_dataimport] \
    -side top -padx 10 -pady 10 -expand 1 -fill x

  return $w
}

# Set up variables before opening the GUI
proc ::Dataimport::init_gui {} {
  variable pdbfile
  variable txtfile
  variable outprefix

  # 
  # Check if the top molecule has pdb: if it does,
  # use that as a default; otherwise, leave these fields blank.
  #
  set pdbfile {}
  set txtfile {}
  set outprefix "mapped"
  #Check below, is not working
  if {[molinfo num] != 0} {
    foreach filename [lindex [molinfo top get filename] 0] \
            filetype [lindex [molinfo top get filetype] 0] {
      if { [string equal $filetype "pdb"] } {
        set pdbfile $filename
      }
    }
  }

  # Add traces to the checkboxes, so various widgets can be disabled
  # appropriately
#  if {[llength [trace info variable ::Solvate::waterbox]] == 0} {
#    trace add variable ::Solvate::waterbox write ::Solvate::waterbox_state
#  }
#  if {[llength [trace info variable ::Solvate::use_mol_box]] == 0} {
#    trace add variable ::Solvate::use_mol_box write ::Solvate::molbox_state
#  }
}

# Run map from the GUI. Reads txt file and maps the data to the
# beta field generating a new pdb file.
proc ::Dataimport::run_dataimport {} {
  variable pdbfile
  variable txtfile
  variable outprefix


#  set command_line {}

  if { $pdbfile == {} || $txtfile == {} } {
    puts "Dataimport: need pdb and txt files"
    return
  }


  if { $outprefix == {} } {
    puts "Dataimport: need output filename prefix"
    return
  } elseif { [file exists $outprefix.pdb] } {
    puts "Dataimport: Output pdb exists. Please choose
a different name in order to avoid overwriting your data."
    return
  }

  mol new $pdbfile type pdb waitfor all
  set all [atomselect top all]
  $all set beta 0
  set infile [open $txtfile r];
  set data [read -nonewline $infile]
  set lines [split $data \n]
  set n [llength $lines]
  for { set i 0} {$i < $n} {incr i} {
      set line [lindex $lines $i]
      set words [split $line]
      if {[llength $words] != 3} {
	  puts "Dataimport: format of txt file is unknown, check that
all lines contain 3 columns and no extra spaces or empty lines."
          puts "[llength $words]"
          puts "$words"
	  return
      }
      set res [lindex $words 0]
      if {[lindex $words 1]== "*"} {
	  set sel [atomselect top "protein and resid $res"]
          $sel set beta [lindex $words 2]
          $sel delete
      } else {
          set cha [lindex $words 1]
          #puts "$res $cha"
	  set sel [atomselect top "resid $res and chain $cha"]
	  $sel set beta [lindex $words 2]
	  $sel delete
      }
  }
  $all writepdb ${outprefix}.pdb
  mol modcolor 0 top beta
  puts "Dataimport: done"
}

proc dataimport_tk {} {
  ::Dataimport::dataimport_gui
  return $::Dataimport::w
}


