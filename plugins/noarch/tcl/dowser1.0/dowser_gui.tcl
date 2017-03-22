#
# GUI for Dowser
#

package provide dowser_gui 1.0

namespace eval ::Dowser::GUI:: {

  package require dowser 1.0

  proc resetGUI { } {

    variable workDir [pwd]
    variable inputPSF {}
    variable inputPDB {}
    variable naType "auto"
    variable naTerm "auto"
    variable processedFile "processed-for-dowser.pdb"
    variable processSelection {all}
    variable forceKeepWaters 0
    variable deleteProcFiles 1

    variable dowserWatFile "placed-waters.pdb"
    variable dowserLogFile "dowser.log"

    # command-line options to dowser
    variable dowserHetero 0
    variable dowserProbe "0.2"
    variable dowserSeparation "1.0"
    variable dowserXtalWater "default"
    variable dowserTypeFile {}
    variable dowserParmFile {}

    # for combining waters
    variable selectcolor lightsteelblue; # Background color selected listbox elements 
    variable combinedPrefix {combined}
    variable waterFilesCount 0
    # reset the list of placed waters
    if { [winfo exists .dowsercomb] } {
      .dowsercomb.waters.list.list delete 0 end
      return
    }

  }
  resetGUI

}

proc dowser_gui { } { return [eval ::Dowser::GUI::dowser_gui] }

proc ::Dowser::GUI::dowser_gui { } {

  variable inputPSF
  variable inputPDB
  variable workDir
  variable naType
  variable naTerm
  variable processedFile
  variable dowserLogFile
  variable forceKeepWaters
  variable w

  variable nullMolString "none"
  variable currentMol
  variable molMenuButtonText
  trace add variable [namespace current]::currentMol write [namespace code {
    variable currentMol
    variable molMenuButtonText
    if { ! [catch { molinfo $currentMol get name } name ] } {
      set molMenuButtonText "$currentMol: $name"
    } else {
      set molMenuButtonText $currentMol
    }
  # } ]
  set currentMol $nullMolString
  variable usableMolLoaded 0

  # If already initialized, just turn on
  if { [winfo exists .dowser] } {
    wm deiconify $w
    return
  }
  set w [toplevel ".dowser"]
  wm title $w "Dowser"
  wm resizable $w 0 0

  # Add a menu bar
  frame $w.menubar -relief raised -bd 2
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.file -text "File" -underline 0 -menu $w.menubar.file.menu
  menubutton $w.menubar.set -text "Settings" -underline 0 -menu $w.menubar.set.menu
  menubutton $w.menubar.help -text "Help" -underline 0 -menu $w.menubar.help.menu

  # File menu
  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Combine waters..." -command ::Dowser::GUI::combineWaters
  $w.menubar.file.menu add command -label "Reset all" -command ::Dowser::GUI::resetGUI

  # Settings menu
  menu $w.menubar.set.menu -tearoff no
  $w.menubar.set.menu add checkbutton -label "Delete intermediate files" -variable [namespace current]::deleteProcFiles
  $w.menubar.set.menu add command -label "Dowser options..." -command ::Dowser::GUI::changeDowserOptions

  # Help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About Dowser" \
    -message "Dowser plugin"}
  $w.menubar.help.menu add command -label "Dowser manual..." \
    -command "vmd_open_url $::Dowser::dowserManual"
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url {http://www.ks.uiuc.edu/~ltrabuco/vmd/dowser/dowser.html}"
    #-command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/dowser"

  pack $w.menubar.file $w.menubar.set -side left
  pack $w.menubar.help -side right

  set f [frame $w.workdir]
  set row 0

  grid [label $f.workdirlabel -text "Working directory: "] \
    -row $row -column 0 -columnspan 1 -sticky e
  grid [entry $f.workdirentry -textvariable [namespace current]::workDir \
    -width 35 -relief sunken -justify left -state readonly] \
    -row $row -column 1 -columnspan 1 -sticky e
  grid [button $f.workdirbutton -text "Choose" -command "::Dowser::GUI::getworkdir"] \
    -row $row -column 2 -columnspan 1 -sticky e
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  ############## frame for input file preparation #################
  labelframe $w.input -bd 2 -relief ridge -text "Process input structure" -padx 1m -pady 1m
  
  set f [frame $w.input.files]
  set row 0

  grid [label $f.mollabel -text "Molecule: "] \
    -row $row -column 0 -sticky e
  grid [menubutton $f.mol -textvar [namespace current]::molMenuButtonText \
    -menu $f.mol.menu -relief raised] \
    -row $row -column 1 -columnspan 1 -sticky ew
  menu $f.mol.menu -tearoff no
  incr row
  
  fill_mol_menu $f.mol.menu
  trace add variable ::vmd_initialize_structure write [namespace code "
    fill_mol_menu $f.mol.menu
  # " ]

  grid [label $f.sellabel -text "Selection: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.sel -width 30 \
    -textvariable [namespace current]::processSelection] \
    -row $row -column 1 -columnspan 1 -sticky ew
  incr row

#  grid [label $f.inpdbinlabel -text "Input PDB: "] \
#    -row $row -column 0 -sticky w
#  grid [entry $f.inpdbin -width 30 -textvariable ::Dowser::GUI::inputPDB] \
#    -row $row -column 1 -sticky ew
#  grid [button $f.inpdbinbutton -text "Browse" \
#    -command {
#      set tempfile [tk_getOpenFile]
#      if {![string equal $tempfile ""]} { set ::Dowser::GUI::inputPDB $tempfile }
#    }] -row $row -column 2 -sticky w
#  incr row
#
#  grid [label $f.inpsflabel -text "Input PSF (optional): "] \
#    -row $row -column 0 -sticky e
#  grid [entry $f.inpsf -width 30 -textvariable ::Dowser::GUI::inputPSF] \
#    -row $row -column 1 -sticky ew
#  grid [button $f.inpsfbutton -text "Browse" \
#    -command {
#      set tempfile [tk_getOpenFile]
#      if {![string equal $tempfile ""]} { set ::Dowser::GUI::inputPSF $tempfile }
#    }] -row $row -column 2 -sticky ew
#  incr row

  grid [label $f.outpdblabel -text "Processed PDB: "] \
    -row $row -column 0 -sticky w
  grid [entry $f.outpdb -width 30 -textvariable ::Dowser::GUI::processedFile] \
    -row $row -column 1 -sticky ew
  incr row

  grid [checkbutton $f.keepwat -text \
    "Force dowser to keep all water molecules present" \
    -variable [namespace current]::forceKeepWaters] \
    -row $row -column 0 -columnspan 2 -sticky ew -pady 10
  grid [button $f.keepwathelp -padx 2 -pady 1 -text "?" \
    -command {tk_messageBox -type ok \
    -title "Keeping water molecules" -message "This option forces dowser to keep all water molecules without testing their energies."}] \
    -row $row -column 2 -sticky w 
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  ########### OPTIONS FOR NUCLEIC ACIDS #####################
  
  labelframe $w.input.na -text "Options for structures with nucleic acids" -labelanchor n -relief sunken -bd 1;# already created

  set f [frame $w.input.na.all]
  set row 0

  grid [label $f.natype -text "Nucleic acid type: "] \
    -row $row -column 0 -sticky e
  grid [radiobutton $f.natyperna -value "rna" -text "RNA" \
    -variable [namespace current]::naType] \
    -row $row -column 1 -sticky w
  grid [radiobutton $f.natypedna -value "dna" -text "DNA" \
    -variable [namespace current]::naType] \
    -row $row -column 2 -sticky w
  grid [radiobutton $f.natypeauto -value "auto" -text "auto" \
    -variable [namespace current]::naType] \
    -row $row -column 3 -sticky w
  grid [button $f.natypehelp -padx 2 -pady 1 -text "?" \
    -command {tk_messageBox -type ok \
    -title "Nucleic acid type" -message "The auto option is recommended only for structures without nucleic acids or cases where the structure contains both DNA and RNA."}] \
    -row $row -column 4 -sticky w 
  incr row
  incr row

  grid [label $f.naterm -text "Identify strands by: "] \
    -row $row -column 0 -sticky e
  grid [radiobutton $f.natermchain -value "chain" -text "chain" \
    -variable [namespace current]::naTerm] \
    -row $row -column 1 -sticky w
  grid [radiobutton $f.natermsegname -value "segname" -text "segname" \
    -variable [namespace current]::naTerm] \
    -row $row -column 2 -sticky w
  grid [radiobutton $f.natermfragment -value "fragment" -text "fragment" \
    -variable [namespace current]::naTerm] \
    -row $row -column 3 -sticky w
  incr row 

  grid [radiobutton $f.natermautopsf -value "autopsf" -text "autopsf" \
    -state disabled -variable [namespace current]::naTerm] \
    -row $row -column 1 -sticky w
  grid [radiobutton $f.natermauto -value "auto" -text "auto" \
    -variable [namespace current]::naTerm] \
    -row $row -column 2 -sticky w
  grid [button $f.natermhelp -padx 2 -pady 1 -text "?" \
    -command {tk_messageBox -type ok \
    -title "Method to identify strands" -message "In order to process nucleic acid chain termini, nucleic acid strands have to be identified. The available methods are described in the documentation.\n\nThe recommended way is to have each nucleic acid strand with a different chain or segname identifier and to use the \"chain\" or \"segname\" option, respectively."}] \
    -row $row -column 3 -sticky w 
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $w.input.na -side top -padx 10 -pady 2 -expand 1 -fill x
  
  ########### END OF OPTIONS FOR NUCLEIC ACIDS #############

  set f [frame $w.input.options]
  set row 0

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  set f [frame $w.input.button]
  set row 0

  button $f.processbutton -text "Process input structure" \
    -command {
      ::Dowser::GUI::processInputFile 
    }

  pack $f.processbutton -side bottom -expand 1 -fill x
  pack $f -side bottom -expand 1 -fill x

  pack $w.input -side top -padx 10 -pady 10 -expand 1 -fill x

  ############## frame for job execution #################
  labelframe $w.run -bd 2 -relief ridge -text "Run dowser" -padx 1m -pady 1m
  
  set f [frame $w.run.options]
  set row 0

  grid [label $f.inputfilelabel -text "Processed PDB file: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.inputfile -width 30 -textvariable ::Dowser::GUI::processedFile] \
    -row $row -column 1 -sticky ew
  grid [button $f.inputfilebutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dowser::GUI::processedFile $tempfile }
    }] -row $row -column 2 -sticky w
  incr row

#  grid [label $f.dowserwatlabel -text "File with placed waters: "] \
#    -row $row -column 0 -sticky e
#  grid [entry $f.dowserwat -width 30 -textvariable ::Dowser::GUI::dowserWatFile] \
#    -row $row -column 1 -sticky ew
#  incr row

  grid [label $f.dowserloglabel -text "Log file: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.dowserlog -width 30 -textvariable ::Dowser::GUI::dowserLogFile] \
    -row $row -column 1 -sticky ew
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  set f [frame $w.run.button]
  set row 0

  button $f.rundowserbutton -text "dowser" \
    -command {
      #::ExecTool::exec rundowser $::Dowser::GUI::processedFile >>& $::Dowser::GUI::dowserLogFile < /dev/null &
      #rundowser_from_gui dowser
      ::Dowser::GUI::rundowser_from_gui dowser
    }
  #pack $f.rundowserbutton -side top -expand 1 -fill x
  pack $f.rundowserbutton -side left -expand 1 -fill x

  button $f.rundowserxbutton -text "dowserx" \
    -command {
      #::ExecTool::exec rundowserx $::Dowser::GUI::processedFile >>& $::Dowser::GUI::dowserLogFile < /dev/null &
      ::Dowser::GUI::rundowser_from_gui dowserx
    }
  #pack $f.rundowserxbutton -side top -expand 1 -fill x
  pack $f.rundowserxbutton -side left -expand 1 -fill x

  button $f.rundowserrepeatbutton -text "dowser-repeat" \
    -command {
      #::ExecTool::exec rundowser-repeat $::Dowser::GUI::processedFile >>& $::Dowser::GUI::dowserLogFile < /dev/null &
      ::Dowser::GUI::rundowser_from_gui dowser-repeat
    }
  #pack $f.rundowserrepeatbutton -side top -expand 1 -fill x
  pack $f.rundowserrepeatbutton -side left -expand 1 -fill x

  pack $f -side bottom -expand 1 -fill x -pady 5

  pack $w.run -side top -padx 10 -pady 10 -expand 1 -fill x 


}

proc ::Dowser::GUI::getworkdir { } {

  variable workDir

  set newdir [tk_chooseDirectory \
    -title "Choose working directory" \
    -initialdir $workDir -mustexist true]

  if {[string length $newdir] > 0} {
    set workDir $newdir 
  } 
}

proc ::Dowser::GUI::changeDowserOptions { } {

  variable dowserTypeFile
  variable dowserParmFile
  variable dowserHetero 0
  variable dowserProbe "0.2"
  variable dowserSeparation "1.0"
  variable dowserXtalWater "default"
  variable ws


  # If already initialized, just turn on
  if { [winfo exists .dowserset] } {
    wm deiconify $ws
    return
  }
  set ws [toplevel ".dowserset"]
  wm title $ws "Dowser Options"
  wm resizable $ws 0 0

  set f [frame $ws.desc]
  label $f.desclabel  -text "These are command-line options passed directly to dowser.\nFor more information, please check dowser documentation."
  pack $f.desclabel
  pack $f -side top -padx 5 -pady 5 -expand 1 -fill x

  ############## frame for additional dictionary entries #################
  labelframe $ws.dict -bd 2 -relief ridge -text "Provide additional dowser dictionary files" -padx 1m -pady 1m
  
  set f [frame $ws.dict.files]
  set row 0

  grid [label $f.typefilelabel -text "Residue descriptions (type file):"] \
    -row $row -column 0 -columnspan 2 -sticky w
  incr row
  grid [entry $f.typefile -width 37 -textvariable ::Dowser::GUI::dowserTypeFile] \
    -row $row -column 0 -sticky ew
  grid [button $f.typefilebutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dowser::GUI::dowserTypeFile $tempfile }
    }] -row $row -column 1 -sticky ew
  incr row

  grid [label $f.parmfilelabel -text "LJ parameters and MS radii (parm file):"] \
    -row $row -column 0 -columnspan 2 -sticky w
  incr row
  grid [entry $f.parmfilepsf -width 37 -textvariable ::Dowser::GUI::dowserParmFile] \
    -row $row -column 0 -sticky ew
  grid [button $f.parmfilebutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dowser::GUI::dowserParmFile $tempfile }
    }] -row $row -column 1 -sticky ew
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $ws.dict -side top -padx 10 -pady 10 -expand 1 -fill x

  ############## frame for other options #################
  labelframe $ws.waters -bd 2 -relief ridge -text "Handling waters present in the initial structure" -padx 1m -pady 1m
  
  set f [frame $ws.waters.all]
  set row 0

  grid [radiobutton $f.noxtalwater -value "noxtalwater" -text "Do not test existing water positions (-noxtalwater)" \
    -variable [namespace current]::dowserXtalWater] \
    -row $row -column 0 -sticky w
  incr row
  grid [radiobutton $f.onlyxtalwater -value "onlyxtalwater" -text "Test only positions of existing waters (-onlyxtalwater)" \
    -variable [namespace current]::dowserXtalWater] \
    -row $row -column 0 -sticky w
  incr row
  grid [radiobutton $f.nonextalwater -value "default" -text "Default" \
    -variable [namespace current]::dowserXtalWater] \
    -row $row -column 0 -sticky w
  incr row


  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $ws.waters -side top -padx 10 -pady 10 -expand 1 -fill x

  ############## frame for other options #################
  labelframe $ws.options -bd 2 -relief ridge -text "Other options" -padx 1m -pady 1m
  
  set f [frame $ws.options.all]
  set row 0

  grid [checkbutton $f.hetero -text \
    "Include hetero atoms, except HOH residues (-hetero)" \
    -variable [namespace current]::dowserHetero] \
    -row $row -column 0 -columnspan 2 -sticky w -pady 5
  grid [button $f.heterohelp -padx 2 -pady 1 -text "?" \
    -command {tk_messageBox -type ok \
    -title "Dowser hetero option" -message "This option is uneffective with files processed by VMD, since VMD converts all HETATM entries to ATOM (thus ALL atoms are always included). If you do not want to include heteroatoms, remove them from the PDB before you start using the plugin."}] \
    -row $row -column 2 -sticky w 
  incr row

  grid [label $f.probelabel -text "Molecular surface probe size"] \
    -row $row -column 0 -sticky w
  grid [entry $f.probe -width 7 \
    -textvariable [namespace current]::dowserProbe] \
    -row $row -column 1 -sticky ew
  grid [label $f.probelabelcomment -text "(Angstrom)"] \
    -row $row -column 2 -sticky w
  incr row

  grid [label $f.seplabel -text "Separation between internal points"] \
    -row $row -column 0 -sticky w
  grid [entry $f.sep -width 7 \
    -textvariable [namespace current]::dowserSeparation] \
    -row $row -column 1 -sticky ew
  grid [label $f.seplabelcomment -text "(Angstrom)"] \
    -row $row -column 2 -sticky w
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x

  pack $ws.options -side top -padx 10 -pady 10 -expand 1 -fill x

}

proc ::Dowser::GUI::processInputFile { } {

  variable workDir
  variable inputPSF
  variable inputPDB
  variable naType
  variable naTerm
  variable processedFile
  variable forceKeepWaters
  variable deleteProcFiles
  variable processSelection
  variable currentMol

  set outFiles(input_pdb) [file join $workDir "dowser_input_tmp.pdb"]
  set outFiles(convert_resnames) [file join $workDir "convert_resnames.pdb"]
  set outFiles(convert_na_resnames) [file join $workDir "convert_na_resnames.pdb"]
  set outFiles(convert_na_termini) [file join $workDir "convert_na_termini.pdb"]
  set outFiles(convert_names) [file join $workDir "convert_names.pdb"]
  set outFiles(convert_na_names) [file join $workDir "convert_na_names.pdb"]
  set outFiles(keep_waters) [file join $workDir "force_keep_waters.pdb"]
  set outFiles(convert_hoh_hetatm) [file join $workDir "convert_hoh_hetatm.pdb"]

  if { $currentMol == "none" } {
    tk_messageBox -type ok -message "Please load the molecule to be processed."
    return
  }
  set sel [atomselect $currentMol "$processSelection"]
  $sel writepdb $outFiles(input_pdb)
  $sel delete
  set inputPDB $outFiles(input_pdb)

  if { $inputPSF != {} } {
    ::Dowser::convert_resnames -pdb $inputPDB -o $outFiles(convert_resnames) -psf $inputPSF
    ::Dowser::convert_na_resnames -pdb $outFiles(convert_resnames) -o $outFiles(convert_na_resnames) -na $naType -psf $inputPSF
    ::Dowser::convert_na_termini -pdb $outFiles(convert_na_resnames) -o $outFiles(convert_na_termini) -split $naTerm -na $naType -psf $inputPSF
    ::Dowser::convert_names -pdb $outFiles(convert_na_termini) -o $outFiles(convert_names) -psf $inputPSF
    ::Dowser::convert_na_names -pdb $outFiles(convert_names) -o $outFiles(convert_na_names) -psf $inputPSF
  } else {
    ::Dowser::convert_resnames -pdb $inputPDB -o $outFiles(convert_resnames)
    ::Dowser::convert_na_resnames -pdb $outFiles(convert_resnames) -o $outFiles(convert_na_resnames) -na $naType
    ::Dowser::convert_na_termini -pdb $outFiles(convert_na_resnames) -o $outFiles(convert_na_termini) -split $naTerm -na $naType
    ::Dowser::convert_names -pdb $outFiles(convert_na_termini) -o $outFiles(convert_names)
    ::Dowser::convert_na_names -pdb $outFiles(convert_names) -o $outFiles(convert_na_names)
  }

  if { $forceKeepWaters == 1 } {
    ::Dowser::keep_waters -pdb $outFiles(convert_na_names) -o $outFiles(keep_waters)
    file copy -force $outFiles(keep_waters) $processedFile
  } else {
    ::Dowser::convert_hoh_hetatm -pdb $outFiles(convert_na_names) -o $outFiles(convert_hoh_hetatm)
    file copy -force $outFiles(convert_hoh_hetatm) $processedFile
  }

  if { $deleteProcFiles == 1 } {
    puts ""
    puts -nonewline "Dowser) Deleting intermediate files... "
    foreach filename [array names outFiles] {
      file delete -force $outFiles($filename)
    }
    puts "Done."
  }

  mol new [file join $workDir $processedFile] type pdb waitfor all

  puts ""
  puts "Dowser) *************************************************************"
  puts "Dowser) Processing of input file is complete. You may now run dowser."
  puts "Dowser) *************************************************************"
  puts ""

}

proc ::Dowser::GUI::rundowser_from_gui { dowser_command } {

  variable dowserHetero
  variable dowserProbe
  variable dowserSeparation
  variable dowserTypeFile
  variable dowserParmFile
  variable dowserXtalWater
  variable dowserLogFile
  variable processedFile
  variable workDir
  variable waterFiles
  variable waterFilesCount

  set argList {}
  lappend argList $processedFile
  lappend argList "-cmd"
  lappend argList $dowser_command
  lappend argList "-log" 
  lappend argList $dowserLogFile
  lappend argList "-hetero"
  lappend argList $dowserHetero
  lappend argList "-probe"
  lappend argList $dowserProbe
  lappend argList "-separation"
  lappend argList $dowserSeparation
  lappend argList "-xtal"
  lappend argList $dowserXtalWater

  if { $dowserTypeFile != {} } {
    lappend argList "-atomtypes"
    lappend argList $dowserTypeFile
  }
  if { $dowserParmFile != {} } {
    lappend argList "-atomparms"
    lappend argList $dowserParmsFile
  }

  set argList [join $argList]

  #puts "DEBUG: ::Dowser::rundowser_wrapper $argList"
  ::Dowser::rundowser_wrapper $argList

  # After dowser-repeat, update processedFile
  if { $dowser_command == "dowser-repeat" } {
    set processedFile "ext_$processedFile"
  }

  incr waterFilesCount
  set fileName [file join $workDir "placed_waters_$waterFilesCount.pdb"]
  file copy -force [file join $workDir dowserwat.pdb] $fileName

  if { [catch { mol new $fileName waitfor all } err] } {
    tk_messageBox -type ok -message "Dowser did not place any additional water molecules."
    return
} else {
  lappend waterFiles $fileName
}

  set sel [atomselect top {noh}]
  tk_messageBox -type ok -message "Dowser placed [$sel num] water molecules."
  $sel delete
  
  return

}

# Adapted from pmepot gui
proc ::Dowser::GUI::fill_mol_menu {name} {

  variable usableMolLoaded
  variable currentMol
  variable nullMolString
  $name delete 0 end

  set molList ""
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      lappend molList $mm
      $name add radiobutton -variable [namespace current]::currentMol \
        -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
      set currentMol [molinfo top]
      set usableMolLoaded 1
    } else {
      set currentMol $nullMolString
      set usableMolLoaded  0
    }
  }

}

proc ::Dowser::GUI::combineWaters { } {

  variable combinePSF
  variable combinePDB
  variable waterFiles
  variable combinedPrefix

  variable selectcolor
  variable wc
  variable currentMol

  # Adapted from autoionize
  set combinePSF {}
  set combinePDB {}
  if {[molinfo num] != 0 && $currentMol != "none"} {
    foreach filename [lindex [molinfo $currentMol get filename] 0] \
            filetype [lindex [molinfo $currentMol get filetype] 0] {
      if { [string equal $filetype "psf"] } {
        set combinePSF $filename
      } elseif { [string equal $filetype "pdb"] } {
        set combinePDB $filename
      }
    }
    # Make sure both a pdb and psf are loaded
    if { $combinePSF == {} || $combinePDB == {} } {
      set combinePSF {}
      set combinePDB {}
    }
  }

  # If already initialized, just turn on
  if { [winfo exists .dowsercomb] } {
    wm deiconify $wc
    return
  }
  set wc [toplevel ".dowsercomb"]
  wm title $wc "Combine waters"
  wm resizable $wc 0 0

  set f [frame $wc.desc]
  label $f.desclabel  -text "Add waters placed by dowser to an existing psf/pdb combo"
  pack $f.desclabel
  pack $f -side top -padx 5 -pady 5 -expand 1 -fill x

  labelframe $wc.input -bd 2 -relief ridge -text "Initial structure" -padx 1m -pady 1m

  set f [frame $wc.input.input]
  set row 0

  grid [label $f.inpsflabel -text "PSF: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.inpsf -width 45 -textvariable ::Dowser::GUI::combinePSF] \
    -row $row -column 1 -sticky ew
  grid [button $f.inpsfbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dowser::GUI::combinePSF $tempfile }
    }] -row $row -column 2 -sticky ew
  incr row

  grid [label $f.inpdbinlabel -text "PDB: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.inpdbin -width 45 -textvariable ::Dowser::GUI::combinePDB] \
    -row $row -column 1 -sticky ew
  grid [button $f.inpdbinbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Dowser::GUI::combinePDB $tempfile }
    }] -row $row -column 2 -sticky w
  incr row

  pack $f -side top -padx 0 -pady 5 -expand 1 -fill x
  pack $wc.input -side top -padx 5 -pady 5 -expand 1 -fill x

  labelframe $wc.waters -bd 2 -relief ridge -text "PDB files with placed waters" -padx 1m -pady 1m
  frame $wc.waters.list
  scrollbar $wc.waters.list.scroll -command "$wc.waters.list.list yview"
  listbox $wc.waters.list.list -activestyle dotbox -yscroll "$wc.waters.list.scroll set" -font {tkFixed 9} \
     -width 55 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
     -listvariable [namespace current]::waterFiles
  frame $wc.waters.list.buttons
  button $wc.waters.list.buttons.add -text "Add" -command [namespace code {
    set filetypes {
      {{PDB Files} {.pdb}}
       {{All Files} {*}}
    }
    set temploc [tk_getOpenFile -filetypes $filetypes]
      if {$temploc != ""} {lappend waterFiles $temploc}
  }]
  button $wc.waters.list.buttons.delete -text "Delete" -command [namespace code {
    foreach i [.dowsercomb.waters.list.list curselection] {
      .dowsercomb.waters.list.list delete $i
    }
  }]
  pack $wc.waters.list.buttons.add $wc.waters.list.buttons.delete -expand 1 -fill x -side top
  pack $wc.waters.list.list $wc.waters.list.scroll -side left -fill y -expand 1
  pack $wc.waters.list.buttons -side left
  pack $wc.waters.list
  pack $wc.waters  -side top -padx 5 -pady 5 -expand 1 -fill x

  set f [frame $wc.output]

  grid [label $f.dowserloglabel -text "Output prefix: "] \
    -row $row -column 0 -sticky e
  grid [entry $f.dowserlog -width 40 -textvariable ::Dowser::GUI::combinedPrefix] \
    -row $row -column 1 -sticky ew
  incr row

  pack $f -side top -padx 5 -pady 5 -expand 1 -fill x

  set f [frame $wc.button]
  set row 0

  button $f.combinebutton -text "Add placed waters to psf/pdb" \
    -command {
      ::Dowser::GUI::combine_waters_gui
    }

  pack $f.combinebutton -side bottom -expand 1 -fill x
  pack $f -side bottom -expand 1 -fill x -padx 5 -pady 5

}

proc ::Dowser::GUI::combine_waters_gui {} {

  variable combinePSF
  variable combinePDB
  variable waterFiles
  variable combinedPrefix

  ::Dowser::combine_waters -psf $combinePSF -pdb $combinePDB -dow $waterFiles -o $combinedPrefix

}


# This gets called by VMD the first time the menu is opened.
proc dowser_tk_cb {} {
  dowser_gui   ;# start the GUI
  return $::Dowser::GUI::w
}

