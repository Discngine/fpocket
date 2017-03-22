# 
# RESPTool -- for setting up RESP runs for working with AMBER forcefield
#             
# $Id: resptool.tcl,v 1.17 2007/03/02 12:09:15 saam Exp $
#

# TODO

# * Clicking a selected atom should deselect it
# * Clear selection button

package require paratool
package require exectool 1.2
package provide resptool 1.1

namespace eval ::RESPTool:: {
  variable w

  proc initialize {} {
      variable selectcolor lightsteelblue

      variable origsel     {}
      variable cursel      {}
      variable tmpmolid    -1
      variable pickmode    "off"

      # The list of RESP constraints. This variable has the 
      # following format:
      #
      # { {mol {atomlist} charge weight} ... }
      # mol: the RESP molecule number (NOT VMD molid!)
      #      for now always 0, but we might want to do
      #      multi-molecule RESP in the future
      # atomlist: list of atom indices for this constraint
      # charge: the desired target charge; UNK if not specified
      # weight: the weight of this constraint for the RESP
      #         algorithm; UNK if not specified; currently unused
      variable constraintlist {}

      variable picklist       {}
      variable constraintlist_display {}
      variable picklist_display       {}

      variable gaussianinput ""
      variable respinput     ""
      variable respoutput    ""
      variable espfile       ""
      variable chargefile    ""

      variable chargetmp     ""

      variable origmolid
      variable espcanvas

      variable spheresize 0.5

      variable drawlist
      array set drawlist {}
      variable lastshift 0

      variable totalcharge   {}
      variable espfitcenters {}
      variable atomiccenters {}
      variable atomicradii   {}
      variable potential     {}
      variable alignmol      -1
      variable showesp        0
      variable stage          1


      variable resp_charge_list {}
      variable resp_charges_done 0
      variable respbinary "/usr/local/bin/resp"

      variable respchargelist {}
      variable callbackfctn {}

      variable respqwt   0.0005; # stage 1

   }
   initialize
}

#####################################################
# GUI for setting up the RESP input file            #
# Allows user to set up constraints, etc            #
#####################################################

proc ::RESPTool::resp_gui { sel } {
  variable origmolid [$sel molid]
  variable cursel $sel
  variable origsel $sel
  variable w

  variable selectcolor 

  # If already initialized, just turn on
  if { [winfo exists .resptool] } {
     wm deiconify .resptool
     focus .resptool
     set_view
     start_picking
     return
  }

  set w [toplevel ".resptool"]
  wm title $w "RESPTool"
  wm resizable $w 0 0
  wm protocol .resptool WM_DELETE_WINDOW {
     if {[llength $::RESPTool::callbackfctn]} {
	::RESPTool::cleanup
     } else {
	::RESPTool::stop_picking
     }
     wm withdraw .resptool
  }

  ############## frame for input files ###############
  labelframe $w.files -bd 2 -relief ridge -text "Input Files" -padx 1m -pady 1m
  label $w.files.glabel -text "Gaussian log: "
  entry $w.files.glogfile  -textvariable ::RESPTool::gaussianinput -width 50 \
         -relief sunken -justify left -state readonly
  button $w.files.gbutton -text "Choose" -command {::RESPTool::choose_log_file}

  label $w.files.rlabel -text "RESP logfile: "
  entry $w.files.rfile  -textvariable ::RESPTool::respoutput -width 50 \
        -relief sunken -justify left -state readonly
  button $w.files.rbutton -text "Choose" -command {::RESPTool::choose_resp_out}

  pack $w.files          -side top -fill x -expand 1 -padx 1m
  grid $w.files.glabel   -row 0 -column 0 -sticky w 
  grid $w.files.glogfile -row 0 -column 1 -sticky w
  grid $w.files.gbutton  -row 0 -column 2 -sticky w
  grid $w.files.rlabel   -row 1 -column 0 -sticky w
  grid $w.files.rfile    -row 1 -column 1 -sticky w
  grid $w.files.rbutton  -row 1 -column 2 -sticky w
  
  ############## Total charge #########################
  frame $w.totalcharge
  label $w.totalcharge.label -text "Total Charge: "
  entry $w.totalcharge.totalcharge  -textvariable ::RESPTool::totalcharge \
        -width 8 -relief sunken -justify left 
  pack $w.totalcharge.label -side left -pady 2m
  pack $w.totalcharge.totalcharge -side left -pady 2m

  checkbutton $w.totalcharge.showesp -text "Show ESP fit centers" -variable ::RESPTool::showesp \
     -command ::RESPTool::show_esp_fit_centers
  pack $w.totalcharge.showesp -side left -padx 2m
  pack $w.totalcharge

  ############## frame for picked atom list ###########
  labelframe $w.atoms -bd 2 -relief ridge -text "Picked Atoms" -padx 1m -pady 1m
  frame $w.atoms.list
  #frame $w.atoms.list.header
  #label $w.atoms.list.header.header -font {tkFixed} -width 72 -text [format "%6s %16s %16s %16s %6s" "Name" "Type" "Index" "Chain" " "]
  scrollbar $w.atoms.list.scroll -command "$w.atoms.list.list yview" -takefocus 0
  listbox $w.atoms.list.list -activestyle dotbox -yscroll "$w.atoms.list.scroll set" \
     -font {tkFixed} -width 72 -height 5 -setgrid 1 -selectmode single \
     -state disabled -disabledforeground black \
     -selectbackground $selectcolor -listvariable ::RESPTool::picklist_display
  frame $w.atoms.buttons
  button $w.atoms.buttons.addconstraint -text "Add Constraint" -command {::RESPTool::add_constraint}
  button $w.atoms.buttons.clear -text "Clear selection" -command [namespace code {
     variable picklist
     foreach atom $picklist
     # This atom needs to be un-picked
     set picklist [clean_list_remove $picklist $atom]
     draw delete $drawlist($atom)
  }]
  #pack $w.atoms.list.header -side top -fill y -expand 1
  #pack $w.atoms.list.header.header -side left -fill y -expand 1
  pack $w.atoms.list.list $w.atoms.list.scroll -side left -fill y -expand 1 
  pack $w.atoms.list 
  pack $w.atoms.buttons.addconstraint $w.atoms.buttons.clear -side left
  pack $w.atoms.buttons -side bottom -padx 1m
  pack $w.atoms -fill x -expand 1 -padx 1m

  ############## frame for constraint list ############
  labelframe $w.constraints -bd 2 -relief ridge -text "RESP Constraints" -padx 1m -pady 1m
  frame $w.constraints.list
  scrollbar $w.constraints.list.scroll -command "$w.constraints.list.list yview" \
     -takefocus 0
  listbox $w.constraints.list.list -activestyle dotbox \
     -yscroll "$w.constraints.list.scroll set" \
     -font {tkFixed} -width 72 -height 5 -setgrid 1 -selectmode single \
     -selectbackground $selectcolor -listvariable ::RESPTool::constraintlist_display 
  frame $w.constraints.charge
  entry $w.constraints.charge.charge  -textvariable ::RESPTool::chargetmp -width 8 \
        -relief sunken -justify left 
  button $w.constraints.charge.setcharge -text "Set Charge" \
         -command {::RESPTool::set_charge}
  button $w.constraints.remconstraint -text "Remove Constraint" \
         -command {::RESPTool::rem_constraint}
  pack $w.constraints.list.list $w.constraints.list.scroll -side left -fill y -expand 1 
  pack $w.constraints.list 
  pack $w.constraints.charge.charge -side left
  pack $w.constraints.charge.setcharge -side left
  pack $w.constraints.charge
  pack $w.constraints.remconstraint -side bottom
  pack $w.constraints -fill x -expand 1 -padx 1m -pady 1m

  bind $w.constraints.charge.charge <Return> {
     ::RESPTool::set_charge
  }

  ############## frame for output file ##############
  labelframe $w.out -bd 2 -relief ridge -text "Run RESP" -padx 1m -pady 1m
  radiobutton $w.out.stage1 -text "RESP fit stage 1" -variable ::RESPTool::stage -value 1 -command ::RESPTool::setup_stage_one
  radiobutton $w.out.stage2 -text "RESP fit stage 2" -variable ::RESPTool::stage -value 2 -command ::RESPTool::setup_stage_two
  label $w.out.label -text "RESP input file: "
  entry $w.out.file  -textvariable ::RESPTool::respinput -width 50 \
         -relief sunken -justify left -state readonly
  button $w.out.button -text "Choose" -command {::RESPTool::choose_resp_in}

  label $w.out.binlabel -text "RESP binary: "
  entry $w.out.binfile  -textvariable ::RESPTool::respbinary -width 50 \
         -relief sunken -justify left -state readonly
  button $w.out.binbutton -text "Find" -command {
     set ::RESPTool::respcmd [::ExecTool::find -interactive \
	   -description "RESP binary" -path [file join $::RESPTool::respbinary] resp]
  }

  pack $w.out          -side top -fill x -expand 1 -padx 1m
  grid $w.out.stage1   -row 0 -columnspan 2 -sticky w 
  grid $w.out.stage2   -row 1 -columnspan 2 -sticky w 
  grid $w.out.label    -row 2 -column 0 -sticky w 
  grid $w.out.file     -row 2 -column 1 -sticky w
  grid $w.out.button   -row 2 -column 2 -sticky w
  grid $w.out.binlabel    -row 3 -column 0 -sticky w 
  grid $w.out.binfile     -row 3 -column 1 -sticky w
  grid $w.out.binbutton   -row 3 -column 2 -sticky w

  ############## frame for confirm button ###########
  frame $w.out.go
  button $w.out.go.write -text "Write RESP input file" \
         -command {::RESPTool::write_resp_input}
  button $w.out.go.run -text "Write RESP input & run RESP" \
     -command {
	::RESPTool::write_resp_input
	::RESPTool::run_resp 
     }

  #pack $w.out.go.write -side left
  pack $w.out.go.write $w.out.go.run   -side left -pady 1m
  grid $w.out.go      -row 4 -columnspan 3 

  label $w.status -text ""
  pack $w.status
  ############# done with GUI setup #################

  ############# set up window bindings ##############
  bind $w <Destroy> {
    set wtmp ${::RESPTool::w}
    if {"%W" == "$wtmp"} {
       ::RESPTool::cleanup;
    }
  }

  # clear and re-start atom picking on loose/regain focus
  bind $w <FocusIn> {
    set wtmp ${::RESPTool::w}
    if {"%W" == "$wtmp"} {
      ::RESPTool::stop_picking
      ::RESPTool::start_picking
    }
  }

   # pick atoms that belong to the selected constraint
   bind $w.constraints.list.list <<ListboxSelect>> [namespace code {
      variable picklist {}
      variable constraintlist
      set i [%W curselection]
      set picklist [join [lindex $constraintlist $i 1]]
     

      variable spheresize
      variable drawlist
      variable tmpmolid
      label delete Atoms all
      draw delete all; #   foreach gid [array get drawlist] {draw delete $gid}
      draw color yellow
      foreach index $picklist {
	 set sel [atomselect $tmpmolid "index $index"]
	 set drawlist($index) [draw sphere [join [$sel get {x y z}]] \
					  radius $spheresize]
	 $sel delete
      }
      ::RESPTool::update_picklist_display
   }]

  set_view

  start_picking

   variable respbinary 
   set respbinary [::ExecTool::find -interactive \
      -description "RESP binary" -path [file join $respbinary] resp]

}

#######################################################
# Pick the Gaussian log file                          #
#######################################################
proc ::RESPTool::choose_log_file { } {
  variable gaussianinput

  set types {{{Gaussian logfiles} {.log}}}

  set tmp [tk_getOpenFile -title "Choose Log File" \
              -filetypes $types]

  if {[string length $tmp] > 0} {
    set gaussianinput $tmp
  }

  parse_gaussian_log
}

proc ::RESPTool::parse_gaussian_log {} {
   variable gaussianinput
   variable totalcharge
   variable espfitcenters
   variable atomiccenters
   variable atomicradii
   variable potential

   if {![string length $gaussianinput]} { return }

   set gotespline 0
   set gotatomicradii 0
   set gotpotential 0

   # Parse out total charge from the log file
   set file [open $gaussianinput r]
   #set data [read -nonewline $file]
   while {![eof $file]} {
      set line [gets $file]
      if {[string match "*Atom Element Radius*" $line]} {
	 set gotatomicradii 1
	 continue
      }
   
      if {$gotatomicradii} { 
	 if {![string match {*Generate *} $line]} {
	    lappend atomicradii [lindex $line 2]
	    #puts $line
	    continue
	 } else {
	    set gotatomicradii 0
	    continue 
	 }
      }

      if {[string match {* Atomic Center *} $line]} {
	 lappend atomiccenters [lrange $line 5 7]
	 continue
      } elseif {[string match {* ESP Fit Center*} $line]} {
	 lappend espfitcenters [lrange $line 6 8]
	 continue
      }

      if {$gotespline == 0} {
	 if {[string match {*Charges from ESP fit*} "$line"] > 0} {
	    set gotespline 1
	 }
      } else {
	 if {[regexp {Charge=\s+([\-0-9.]*).*} "$line" junk totalcharge] > 0} {
	    continue
	 }
      }

      if {$gotpotential == 0} {
	 if {[string match {*Center     Electric *} "$line"] > 0} {
	    set gotpotential 1
	 }
      } else {
	 if {[lindex "$line" 1]=="Fit"} {
	    lappend potential [lindex $line 2]
	    continue
	 } elseif {[string match { ----*} $line]} {
	    if {$gotpotential>1} { break }
	    incr gotpotential
	 }
      }
   }
   close $file

   if {![llength $potential]} {
      tk_messageBox -icon error -type ok -title Message -parent .resptool \
	 -message "No potential fit points found in $gaussianinput"
      return 0
   }

   # Write a tmpmolecule with ESP fit centers as atoms and ESP values as beta
   set fid [open resptool_espfitcenters_tmp.pdb w]

   set i 1
   foreach center $atomiccenters radius $atomicradii {
      write_pdb_atom $fid $i COOR {} ATM {} 1 {} $center 1 $radius RESP 
      incr i
   }

   set sorted [lsort -real -increasing $potential]
   set range  [expr [lindex $sorted end]-[lindex $sorted 0]]
   set offset [lindex $sorted 0]
   if {$offset<0} { set offset [expr -$offset]}

   foreach center $espfitcenters elpot $potential {
      set elpot [expr ($elpot+$offset)/$range]
      write_pdb_atom $fid $i CEN {} FIT {} 2 {} $center 1 $elpot RESP 
      incr i
   }
   close $fid

   variable espcanvas [mol new resptool_espfitcenters_tmp.pdb]
   color scale method RWB
   set sel [atomselect $espcanvas "resname ATM"]
   $sel set radius $atomicradii
   $sel delete
   mol modselect 0 $espcanvas {resname FIT}
   mol modcolor  0 $espcanvas Beta
   mol modstyle  0 $espcanvas {Points 20}

   mol addrep $espcanvas
   mol modselect   1 $espcanvas {resname ATM}
   mol modcolor    1 $espcanvas {ColorID 5}
   mol modstyle    1 $espcanvas {VDW 1}

   if {[lsearch [material list] Translux]<0} {
      set newmat [material add copy Transparent]
      material rename $newmat Translux
      material change opacity Translux 0.300000
      mol modmaterial 1 $espcanvas Translux
      color scale midpoint 0.5
   }
   variable tmpmolid
   mol top $tmpmolid

   # We have to align Gaussians Standard orientation to input orientation.
   # This has to be done by hand since "measure fit" doesn't work with small structures
   variable alignmol
   set sela [atomselect $alignmol all]
   set selb [atomselect $espcanvas "resname ATM"]
   set allb [atomselect $espcanvas  all]

   set coorb0 [lindex [$selb get {x y z}] 0]
   set coorb1 [lindex [$selb get {x y z}] 1]
   set atoma1 [lindex [$sela list] 1]
   set atoma2 [lindex [$sela list] 2]
   set atomb0 [lindex [$selb list] 0]
   set atomb1 [lindex [$selb list] 1]
   set atomb2 [lindex [$selb list] 2]

   set coora0 [lindex [$sela get {x y z}] 0]
   set coora1 [lindex [$sela get {x y z}] 1]
   set coorb0 [lindex [$selb get {x y z}] 0]
   set coorb1 [lindex [$selb get {x y z}] 1]
   set offset [vecsub $coora0 $coorb0]

   $allb move [transoffset $offset]

   label add Angles $espcanvas/$atomb1 $espcanvas/$atomb0 $alignmol/$atoma1
   set angle [format {%5.2f} [lindex [lindex [label list Angles] end] 3]]
   label delete Angles

   set coorb0 [lindex [$selb get {x y z}] 0]
   set coorb1 [lindex [$selb get {x y z}] 1]
   set coora1 [lindex [$sela get {x y z}] 1]
   
   $allb move [trans angle $coorb1 $coorb0 $coora1 -$angle deg]

   set coorb1 [lindex [$selb get {x y z}] 1]

   label add Dihedrals $espcanvas/$atomb2 $espcanvas/$atomb1 $espcanvas/$atomb0 $alignmol/$atoma2
   set dihed [format {%5.2f} [lindex [lindex [label list Dihedrals] end] 4]]
   label delete Dihedrals

   $allb move [trans bond $coorb0 $coorb1 -$dihed deg]
   $allb delete
   $sela delete
   $selb delete

   show_esp_fit_centers
}


proc ::RESPTool::write_pdb_atom {fid index name altloc resname chain resid insert xyz occu beta segid} {
      set x [lindex $xyz 0]
      set y [lindex $xyz 1]
      set z [lindex $xyz 2]
      puts $fid [format "ATOM  %5i %4s%1s%4s%1s%4i%1s   %8.3f%8.3f%8.3f%6.2f%6.2f      %-4s" \
		    $index $name $altloc $resname $chain $resid $insert $x $y $z $occu $beta $segid]
}

proc ::RESPTool::write_esp_file { file } {
   variable atomiccenters
   variable espfitcenters
   variable potential

   set fid [open $file w]
   puts $fid [format "%5i%5i" [llength $atomiccenters] [llength $espfitcenters]]
   
   foreach atom $atomiccenters {
      set x [expr [lindex $atom 0]/0.529177249]
      set y [expr [lindex $atom 1]/0.529177249]
      set z [expr [lindex $atom 2]/0.529177249]
      puts $fid [format "%1s%16.7e%16.7e%16.7e" {} $x $y $z]
   }

   foreach center $espfitcenters elpot $potential {
      set x [expr [lindex $center 0]/0.529177249]
      set y [expr [lindex $center 1]/0.529177249]
      set z [expr [lindex $center 2]/0.529177249]
      puts $fid [format "%16.7e%16.7e%16.7e%16.7e" $elpot $x $y $z]
   }

   close $fid
}


#######################################################
# Pick the RESP input file to write to                #
#######################################################
proc ::RESPTool::choose_resp_in { } {
  variable respinput

  set types {{{RESP input files} {.inp}} {{All files} *}} 

  set tmp [tk_getSaveFile -title "Choose Input File" \
              -filetypes $types]

  if {[string length $tmp] > 0} {
    set respinput $tmp
  }

}


#######################################################
# Pick the RESP output file from previous run         #
#######################################################

proc ::RESPTool::choose_resp_out { } {
  variable respoutput
  variable respchargelist

  set types {{{RESP output files} {.out}} {{All files} *}}

  set tmp [tk_getOpenFile -title "Choose Output File" \
              -filetypes $types]

  if {[string length $tmp] > 0} {
    set respoutput $tmp
  }

  set respchargelist [parse_resp_charges $respoutput]
}

#######################################################
# Parse charges out of a RESP output file             #
# Returns a list of 2-element lists; format is        #
# { {atomnum charge} {atomnum charge} }               #
# Atomnum is the atom number from the RESP file,      #
# converted to 0-indexed (so that is matches the way  #
# VMD works)                                          #
#######################################################
proc ::RESPTool::parse_resp_charges {resp_outfile} {

  # Parse file to find charges
  set file [open $resp_outfile r]

  set incharges 0
  set tmp_charge_list {}

  while {[gets $file line] >= 0} {
    if { $incharges == 0 } {
      if {[regexp {Point Charges} "$line"] > 0} {
        set incharges 1
      }
    } else {
      if {[regexp {\s+([0-9]+)\s+[0-9]+\s+[-0-9.]+\s+([-0-9.]+).*} "$line" junk tmpatom tmpcharge] 
          > 0} {
        lappend tmp_charge_list [list [expr $tmpatom-1] $tmpcharge]
      }
    }
  }
  return $tmp_charge_list
}


#######################################################
# Set the view. This is done in a new mol so the      #
# user doesn't loose whatever they're working on.     #
# Taken from $cursel                                  #
#######################################################
proc ::RESPTool::set_view { } {
  variable cursel
  variable origmolid
  variable tmpmolid

  global env

  set tmpfile "$env(TMPDIR)/RESP_[molinfo $origmolid get name]"
  $cursel writepdb $tmpfile

  set tmpmolid [mol load pdb $tmpfile]

  # Undraw all other molecules in VMD:
  foreach m [molinfo list] {
    if {$m==$tmpmolid} { molinfo $m set drawn 1; continue }
    molinfo $m set drawn 0
  }

  # Set rep for our mol
  mol modstyle 0 $tmpmolid {Bonds 0.1}
  mol representation {VDW 0.1}
  mol addrep $tmpmolid

  # reset display
  mol top $tmpmolid
  display resetview

  file delete -force $tmpfile
}

############################################################
# This function is invoked whenever an atom is picked.     #
############################################################
proc ::RESPTool::atom_picked_fctn { args } {
  global vmd_pick_atom
  global vmd_pick_shift_state
  variable picklist
  variable pickmode
  variable spheresize
  variable drawlist
  variable lastshift
  variable tmpmolid

  # If pickmode=="off", just return, it means we don't have
  # pick focus
  if { $pickmode == "off" } {
    return
  }

  set sel [atomselect $tmpmolid "index $vmd_pick_atom"]

  if { $pickmode == "pick" } {
    # if shift is held, add atoms to pick list
    if {$vmd_pick_shift_state} {
      set lastshift 1
      if {[set lidx [lsearch -exact $picklist $vmd_pick_atom]] == -1} {
        lappend picklist $vmd_pick_atom
        draw color yellow
        set drawlist($vmd_pick_atom) [draw sphere [join [$sel get {x y z}]] \
                                      radius $spheresize]
      } else {
        # This atom needs to be un-picked
        set picklist [clean_list_remove $picklist $vmd_pick_atom]
        draw delete $drawlist($vmd_pick_atom)
      }
    } else {
      label delete Atoms all
      draw delete all; #foreach gid [array get drawlist] {draw delete $gid}
      array set drawlist {}
      if {[lsearch -exact $picklist $vmd_pick_atom] == -1 || $lastshift == 1} {
        set lastshift 0
        set picklist {}
        lappend picklist $vmd_pick_atom
        draw color yellow
        set drawlist($vmd_pick_atom) [draw sphere [join [$sel get {x y z}]] \
                                            radius $spheresize]
      } else {
        set picklist {}
      }
    }
  }
  update_picklist_display
  $sel delete
}


############################################################
# This function sets up atom picking.                      #
############################################################
proc ::RESPTool::start_picking { args } {
  variable pickmode
  global vmd_pick_atom
  
  mouse mode 4 2
  mouse callback on
  trace add variable vmd_pick_atom write ::RESPTool::atom_picked_fctn

  set pickmode "pick"
}

############################################################
# This function stops atom picking.                      #
############################################################
proc ::RESPTool::stop_picking { args } {
  variable pickmode
  global vmd_pick_atom
  
  mouse mode 0
  trace remove variable vmd_pick_atom write ::RESPTool::atom_picked_fctn

  set pickmode "off"
}

############################################################
# Proc to remove an element from a list without leaving    #
# a null element behind.                                   #
############################################################
proc ::RESPTool::clean_list_remove { l rem } {
  # first look for the thing
  if {[set lidx [lsearch -exact $l $rem]] == -1} {
    # the thing isn't in the list, just return the list
    return $l
  }
  # do unclean replace
  lset l $lidx ""
  # clean the resulting list
  set tmplist {}
  foreach elem $l {
    if { [llength $elem] > 0 } { 
      lappend tmplist $elem 
    }
  } 

  # return the clean list
  return $tmplist
}


############################################################
# Updates the picked atom list as it's displayed in the    #
# GUI                                                      #
############################################################
proc ::RESPTool::update_picklist_display { } {
  variable picklist
  variable picklist_display
  variable tmpmolid
  variable respchargelist

  # Clear display
  set picklist_display {}

  # re-load
  foreach atom $picklist {
    set sel [atomselect $tmpmolid "index $atom"]
		# if the resp_charge_list exists, display the charge for
		# this atom as well
		if {[llength $respchargelist] > 0} {
			# Find the charge for this atom
			set chargeidx [lsearch -glob $respchargelist "$atom *"]
			set charge [lindex $respchargelist $chargeidx 1]
    	lappend picklist_display [format "%4i %10s %10s %10s    %10.5f" \
                              	$atom [$sel get name] [$sel get type] [$sel get resname] $charge]
		} else {
    	lappend picklist_display [format "%4i %10s %10s %10s    No RESP charges loaded" \
                              	$atom [$sel get name] [$sel get type] [$sel get resname]]
		}
    $sel delete
  }
}


############################################################
# Adds a constraint to the internal list of constraints    #
# Translated into a RESP-compatible format upon file       #
# writing                                                  #
############################################################
proc ::RESPTool::add_constraint { {indexlist {}} } {
  variable picklist
  variable constraintlist
  variable tmpmolid
  if {![llength $indexlist]} { set indexlist $picklist }

  if {[llength $indexlist] < 1} {
    return
  }

  # First, check and see if a constraint for this set of atoms already
  # exists
  foreach constraint $constraintlist {
    if {[lsearch $constraint [lsort -integer $indexlist]] > -1} {
      tk_messageBox -type ok \
                    -message "You already have specified a constraint on these atoms. Please edit the existing constraint instead."
      return
    }
  }

  # The constraint doesn't exist already; add it
  set tmpl {}
  lappend tmpl 0
  lappend tmpl [lsort -integer $indexlist]
  lappend tmpl "UNK"
  lappend tmpl "UNK"
  lappend constraintlist $tmpl

  # Update the displayed list of constraints
  update_constraintlist_display
}

############################################################
# Removes a constraint                                     #
############################################################
proc ::RESPTool::rem_constraint { } {
  variable constraintlist
  variable w

  # Get index of constraint to remove
  set idx [$w.constraints.list.list curselection]
  if {$idx == ""} {
    return
  }
  
  # remove it
  set constraintlist [clean_list_remove $constraintlist [lindex $constraintlist $idx]]

  # update display
  update_constraintlist_display
}

############################################################
# Set charge for a constraint                              #
############################################################
proc ::RESPTool::set_charge { } {
  variable constraintlist
  variable chargetmp
  variable w

  # Get index of constraint to add charge to
  set idx [$w.constraints.list.list curselection]
  if {$idx == ""} {
    return
  }
  
  # Set the charge
  if {$chargetmp == ""} {
    set constraintlist [lreplace $constraintlist $idx $idx \
                        [lreplace [lindex $constraintlist $idx] 2 2 "UNK"]]
  } else {
    set constraintlist [lreplace $constraintlist $idx $idx \
                        [lreplace [lindex $constraintlist $idx] 2 2 $chargetmp]]
  }

  # update display
  update_constraintlist_display

  # re-select item in constraintlist
  $w.constraints.list.list selection set $idx

  # clear charge box
  set chargetmp ""
}

############################################################
# Updates the constraint list as it's displayed in the GUI #
############################################################
proc ::RESPTool::update_constraintlist_display { } {
  variable constraintlist
  variable constraintlist_display
  variable tmpmolid
  variable w

  # Clear display
  set constraintlist_display {}

  # re-load display
  foreach constraint $constraintlist {
    if {[lindex $constraint 2] == "UNK"} {
      set charge "unspecified"
    } else {
      set charge "[lindex $constraint 2]"
    }
    lappend constraintlist_display [format "Atoms: %40s    Charge: %5s" "[join [lindex $constraint 1]]" $charge]
  }

  # focus the most-recently added constraint
  $w.constraints.list.list selection set [expr [$w.constraints.list.list size]-1]
}

######################################################################
# Translate an element symbol into the corresponding atomic number.  #
# If the element symbol was not recognized -1 is returned.           #
# From the Gaussian manual:                                          #
# "Element-label is a character string consisting of either the      #
# chemical symbol for the atom or its atomic number. If the          #
# elemental symbol is used, it may be optionally followed by other   #
# alphanumeric characters to create an identifying label for that    #
# atom. A common practice is to follow the element name with a       #
# secondary identifying integer: C1, C2, C3, and so on; this         #
# technique is useful in following conventional chemical numbering." #
#                                                                    #
# Yanked from Jan's QMTool, because I didn't want to depend on all   #
# of QMTool for just this one function                               #
######################################################################
proc ::RESPTool::element2atomnum { element } {
  set periodic {{} H HE LI BE B C N O F NE NA MG AL SI P S CL AR K CA SC TI V CR MN \
                   FE CO NI CU ZN GA GE AS SE BR KR RB SR Y ZR NB MO TC RU RH PD AG \
                   CD IN SN SB TE I XE CS BA LA CE PR ND PM SM EU GD TB DY HO ER TM \
                   YB LU HF TA W RE OS IR PT AU HG TL PB BI PO AT RN}
  # Strip the trailing characters and check if the $element matches a two-character 
  # element symbol:
  if {[string length $element]>2 && [string is alpha [string index $element 2]]} { 
    return -2 
  }
  set twochar [lsearch $periodic [string toupper [string range $element 0 1]]]
  if {$twochar>=0} { 
    return $twochar 
  }
  # Check for one-character element symbols
  if {[string is alpha [string index $element 1]]} { 
    return -1 
  }
  set onechar [lsearch $periodic [string toupper [string index $element 0]]]
  return $onechar 
}


proc ::RESPTool::setup_stage_one {} {
   puts "Setting up RESP stage 1"
   # Hydrogens are unrestrained, weak restraints on other atoms, 
   # equivalent atoms except for methyl groups are constrained to the same charge
   variable respqwt   0.0005
   variable methylgroups [find_methyl_and_methylene_groups]
   variable tmpmolid
   set all [atomselect $tmpmolid all]
   set grouplist {}
   set processedatoms {}
   foreach atom [$all get {type resid segid atomicnumber index}] {
      foreach {type resid segid atomnum index} $atom {}
      if {[lsearch [join $processedatoms] $index]<0} {
	 # Finding the equivalent types is not dependent on the internal state 
	 # of paratool. It's just a helper function.
	 set equiv [::Paratool::find_equivalent_types $tmpmolid $index 3] 
	 if {[llength $equiv]} {
	    lappend processedatoms $equiv
	    lappend grouplist [join [list $index $equiv]]
	 }
      }
   }
   $all delete

   set methylhydrogens {}
   foreach methyl $methylgroups {
      lappend methylhydrogens [lindex $methyl 1]
   }

   # Add all equivalent atom groups, except for methyl
   foreach group $grouplist {
      if {[lsearch $methylhydrogens [lsort -integer $group]]<0} {
	 ::RESPTool::add_constraint $group
      }
   }

}

proc ::RESPTool::setup_stage_two {} {
   puts "Setting up RESP stage 2"
   # Hydrogens are unrestrained, weak restraints on other atoms
   variable respqwt   0.001
   variable constraintlist {}
   variable methylgroups [find_methyl_and_methylene_groups]

   set grouplist {}
   foreach methyl $methylgroups {
      lappend grouplist [lindex $methyl 1]
   }

   # Add all methyl and methylene groups to the constraints
   foreach group $grouplist {
      ::RESPTool::add_constraint $group
   }
}

proc ::RESPTool::find_methyl_and_methylene_groups {} {
   variable tmpmolid
   set methyl {}
   set sel [atomselect $tmpmolid "atomicnumber 6"]
   foreach index [$sel list] {
      set asel [atomselect $tmpmolid "index $index"]
      set children [join [$asel getbonds]]
      if {[llength $children]==4} {
	 set hsel [atomselect $tmpmolid "index $children and atomicnumber 1"]
	 if {[$hsel num]==3} { 
	    lappend methyl [list $index [$hsel list]]
	 }
      } elseif {[llength $children]==3} {
	 set hsel [atomselect $tmpmolid "index $children and atomicnumber 1"]
	 if {[$hsel num]==2} { 
	    lappend methyl [list $index [$hsel list]]
	 }
      }
   }
   return $methyl
}

############################################################
# Writes the input file to be fed to RESP                  #
############################################################
proc ::RESPTool::write_resp_input { } {
   variable constraintlist
   variable respoutput
   variable respinput
   variable tmpmolid
   variable totalcharge
   variable w

   # Set up constraintlist such that user can write a file with
   # no explicit constraints
   set fakeconstraints 0
   if {[llength $constraintlist] < 1} {
      set constraintlist {{-1 -1 -1 -1}}
      set fakeconstraints 1
   }

   # Check for totalcharge
   if {$totalcharge == ""} {
      tk_messageBox -type ok -icon error \
	 -message "Total charge must be set! Perhaps you didn't load a Gaussian log file?"
      return 
   }

   # If respinput is not defined, tell the user...
   if {$respinput == ""} {
      tk_messageBox -type ok -icon error \
	 -message "You must select an input file name first!"
      return 
   }

   # If respoutput is not writable, tell the user.
   #if {[file writable $respoutput] == 0} {
   #tk_messageBox -type ok -icon error \
      #-message "The selected output file is not writable! Please pick another one."
   #return 
   #}

   # Get number of atoms
   set tmpsel [atomselect $tmpmolid all]
   set natoms [$tmpsel num]
   $tmpsel delete


   # Currently we support only one molecule, but in principle RESP can
   # handle several conformations at the same time.
   set nmols 1
   set mol   1
   set moltitle " Molecule $mol"

   variable respqwt
   variable stage
   variable chargefile
   if {$stage==1} {
      variable chargefile [file rootname $respinput].qout
   } 


   # Hydrogens are always unrestrained
   set fid [open $respinput w]
   puts $fid " RESP input file: $respinput"
   puts $fid " &cntrl"
   puts $fid "  ioutopt=1,iqopt=$stage,nmol=$nmols,ihfree=1,irstrnt=1,qwt=$respqwt,iunits=0"
   puts $fid " &end"
   puts $fid " 1.0"
   puts $fid $moltitle

   # reformat totalcharge as an int to put in next line
   set intcharge [expr int($totalcharge)]
   # puts "RESPtool: natoms=$natoms; intcharge=$intcharge"
   puts $fid [format "%5i%5i" $intcharge $natoms]

   variable methylgroups
   set methylcarbons {}
   foreach methyl $methylgroups {
      lappend methylcarbons [lindex $methyl 0]
   }

   variable stage
   # Notice that through all these loops, atom indices are always
   # written out 1-indexed, not 0-indexed!  So there's always an
   # expr $atom+1 when writing out an atom index.
   for {set i 0} {$i < $natoms} {incr i} {
      set tmpsel [atomselect $tmpmolid "index $i"]
      set atomnum [join [$tmpsel get atomicnumber]]
      $tmpsel delete
      # Check to see if this atom shows up in any constraints, to build
      # the atomlist
      # This is only for atoms constrained together, not to some particular
      # charge (that's handled in the next section)
      set out {}
      foreach constraint $constraintlist {
	 set idx [lsearch -exact [lindex $constraint 1] $i]
	 if {$idx==0} {
	    # Vary this charge independently
	    set out [format "%5i%5i" $atomnum 0]
	    break
	 } elseif {$idx > 0} {
	    # Not first, needs to be referenced to the first atom in this constraint
	    set refatom [lindex $constraint {1 0}]
	    set out [format "%5i%5i" $atomnum [expr $refatom+1]]
	    break
	 } 
      }
      if {![llength $out]} {
	 # doesn't need special treatment
	 if {$stage==1 || ($stage==2 && [lsearch $methylcarbons $i]>=0)} {
	    # Vary this charge independently
	    set out [format "%5i%5i" $atomnum 0]
	 } else {
	    # Stage 2: Charges frozen, except for methyl groups
	    set out [format "%5i%5i" $atomnum -99]
	 }
      }

      puts $fid $out
   }

   # Now do the charge-constrainted atom lists
   foreach constraint $constraintlist {
      if {[lindex $constraint 2] != "UNK"} {
	 # Need to add a charge constraint for this group
	 set out_line1 [format "%5i%10.5f" [llength [lindex $constraint 1]] \
			   [lindex $constraint 2] ]
	 set out_line2 ""
	 foreach atom [lindex $constraint 1] {
	    append out_line2 [format "%5i%5i" $mol [expr $atom+1]]
	 }
	 puts $fid $out_line1
	 puts $fid $out_line2
      }
   }

   # Blank line termination of charge constraint section
   puts $fid ""

   # Intermolecular charge constraint section
   puts $fid ""

   # Intermolecular constraint section
   puts $fid ""
   close $fid

   if {$fakeconstraints == 1} {
      set constraintlist {}
   }
   $w.status configure -text "Wrote file $respinput"

   variable espfile [file rootname $respinput].esp
   write_esp_file $espfile
}

proc ::RESPTool::show_esp_fit_centers {} {
   variable showesp
   variable espcanvas

   if {$showesp} {
      mol on $espcanvas
   } else {
      mol off $espcanvas
   }
}

proc ::RESPTool::run_resp {} {
   variable w
   variable respinput
   variable espfile
   variable chargefile
   variable stage
   if {![llength $respinput]} { return -1 }
   set logfile [file rootname $respinput].out
   $w.status configure -text "Running RESP stage $stage..."


   if {$stage==1} {
      puts "$::RESPTool::respbinary -O -i $respinput -o $logfile -e $espfile -t $chargefile"
      exec -- $::RESPTool::respbinary -O -i $respinput -o $logfile -e $espfile -t $chargefile
   } else {
      if {![string length $chargefile]} { return -2 }
      puts "$::RESPTool::respbinary -O -i $respinput -o $logfile -e $espfile -q $chargefile"
      exec -- $::RESPTool::respbinary -O -i $respinput -o $logfile -e $espfile -q $chargefile
   }
   variable respoutput $logfile
   variable respchargelist [parse_resp_charges $respoutput]
   $w.status configure -text "Finished RESP stage $stage."

   # invoke the callback function
   variable callbackfctn
   if {[llength $callbackfctn]} { $callbackfctn $respchargelist }
}

proc ::RESPTool::cleanup {} {
   variable origmolid
   stop_picking
   molinfo $origmolid set drawn 1
   mol top $origmolid
   mol delete ${::RESPTool::tmpmolid}
   mol delete ${::RESPTool::espcanvas}
   initialize
}