## Mutates protein residues.
##
## Based on psfgen
## Marcos Sotomayor.
##
## $Id: mutator_gui.tcl,v 1.8 2013/04/15 16:36:32 johns Exp $
##

# TODO:
# - Everything (check mutator.tcl)
#
# - General cleanup and comments
#


package require psfgen
  
namespace eval ::Mutator:: {
  namespace export mutator_gui

  variable w

  variable psffile
  variable pdbfile
  variable outprefix
  variable targetressegname
  variable targetresid
  variable mutation
  variable fep
  variable fepprefix
}

proc ::Mutator::mutator_gui {} {
  variable w

  ::Mutator::init_gui

  if { [winfo exists .mutatorgui] } {
    wm deiconify .mutatorgui
    return
  }
  set w [toplevel ".mutatorgui"]
  wm title $w "Mutator"

  frame $w.intro
  grid [label $w.intro.label -text "Mutator performs point mutations on a protein 
(based on internal coordinates)."] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid columnconfigure $w.intro 1 -weight 1
  pack $w.intro -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.input
  grid [label $w.input.label -text "Input"] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid [label $w.input.psflabel -text "PSF: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.input.psfpath -width 30 -textvariable ::Mutator::psffile] \
    -row 1 -column 1 -sticky ew
  grid [button $w.input.psfbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Mutator::psffile $tempfile }
    }] -row 1 -column 2 -sticky w
  grid [label $w.input.pdblabel -text "PDB: "] \
    -row 2 -column 0 -sticky w
  grid [entry $w.input.pdbpath -width 30 -textvariable ::Mutator::pdbfile] \
    -row 2 -column 1 -sticky ew
  grid [button $w.input.pdbbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Mutator::pdbfile $tempfile }
    }] -row 2 -column 2 -sticky w
  grid columnconfigure $w.input 1 -weight 1
  pack $w.input -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.output
  grid [label $w.output.label -text "Output prefix:"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [entry $w.output.outpath -width 30 -textvariable ::Mutator::outprefix] \
    -row 0 -column 1 -sticky ew
  grid [button $w.output.outbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Mutator::outprefix $tempfile }
    }] -row 0 -column 2 -sticky w
  grid columnconfigure $w.output 1 -weight 1
  pack $w.output -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.target  
  grid [label $w.target.label -text "Target Residue"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [label $w.target.labelseg -text "Segment name of target residue (optional):"]\
    -row 1 -column 0 -columnspan 2 -sticky w
  grid [entry $w.target.targetressegname -width 8 -textvariable ::Mutator::targetressegname] \
    -row 1 -column 2 -sticky ew
  grid [label $w.target.labelrid -text "ID of target residue:"]\
    -row 2 -column 0 -columnspan 2 -sticky w
  grid [entry $w.target.targetresid -width 8 -textvariable ::Mutator::targetresid] \
    -row 2 -column 2 -sticky ew
  grid columnconfigure $w.target 1 -weight 1
  pack $w.target -side top -padx 10 -pady 10 -expand 1 -fill x 

  frame $w.mutation
  grid [label $w.mutation.mlabel -text "Mutation (three letter residue name)"] \
    -row 0 -column 0 -sticky w
  grid [entry $w.mutation.mutation -width 8 -textvariable ::Mutator::mutation] \
    -row 0 -column 3 -sticky ew
  grid columnconfigure $w.mutation 1 -weight 1
  pack $w.mutation -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.fep
  grid [checkbutton $w.fep.fep_button -text "Generate Free Energy Perturbation (FEP) files " \
    -variable ::Mutator::fep] -row 0 -column 0 -columnspan 3 -sticky w
  grid [label $w.fep.prefixlabel -text "FEP Prefix: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.fep.prefixpath -width 30 -textvariable ::Mutator::fepprefix] \
    -row 1 -column 1 -sticky ew
  grid [button $w.fep.prefixbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Mutator::fepprefix $tempfile }
    }] -row 1 -column 2 -sticky w
  grid columnconfigure $w.fep 1 -weight 1
  pack $w.fep -side top -padx 10 -pady 10 -expand 1 -fill x

   frame $w.warning
  grid [label $w.warning.label -text "Mutator does not support DNA.
It is strongly recommended to perform a minimization 
on the resulting structure."] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid columnconfigure $w.warning 1 -weight 1
  pack $w.warning -side top -padx 10 -pady 10 -expand 1 -fill x


  pack [button $w.mutator -text "Run Mutator" -command ::Mutator::run_mutator] \
    -side top -padx 10 -pady 10 -expand 1 -fill x

  if {[winfo exists $w.fep]} {
      $w.fep.prefixlabel configure -state disabled
      $w.fep.prefixpath configure -state disabled
      $w.fep.prefixbutton configure -state disabled
  }
  return $w
}

# Set up variables before opening the GUI
proc ::Mutator::init_gui {} {

  variable psffile
  variable pdbfile
  variable outprefix
  variable targetressegname
  variable targetresid
  variable mutation
  variable fep
  variable fepprefix
  # 
  # Check if the top molecule has both pdb and psf files loaded: if it does,
  # use those as a default; otherwise, leave these fields blank.
  # 
  #
  set psffile {}
  set pdbfile {}
  set fep 0
  set fepprefix {}
  if {[molinfo num] != 0} {
    foreach filename [lindex [molinfo top get filename] 0] \
            filetype [lindex [molinfo top get filetype] 0] {
      if { [string equal $filetype "psf"] } {
        set psffile $filename
      } elseif { [string equal $filetype "pdb"] } {
        set pdbfile $filename
      }
    }
    # Make sure both a pdb and psf are loaded
    if { $psffile == {} || $pdbfile == {} } {
      set psffile {}
      set pdbfile {}
    } else {
      #set waterbox 0
      #set use_mol_box 1
    }
  }

  set outprefix "MUTATED"
  set targetressegname {}
  set targetresid {}
  set mutation {}

  # Add traces to the checkboxes, so various widgets can be disabled
  # appropriately
  if {[llength [trace info variable ::Mutator::fep]] == 0} {
    trace add variable ::Mutator::fep write ::Mutator::fep_state
  }
}


# Disable or enable widgets according to the current status of the
# "Waterbox Only" checkbutton
proc ::Mutator::fep_state {args} {
  variable w
  variable fep
#  variable use_fep
  variable fepprefix

  # Disable the prefix file field
  if {!$fep} {
#    set use_fep 0
    if {[winfo exists $w.fep]} {
      $w.fep.prefixlabel configure -state disabled
      $w.fep.prefixpath configure -state disabled
      $w.fep.prefixbutton configure -state disabled
    }
  } else {
    if {[winfo exists $w.fep]} {
      $w.fep.prefixlabel configure -state normal
      $w.fep.prefixpath configure -state normal
      $w.fep.prefixbutton configure -state normal
    }
  }

}



# Run Mutator from the GUI.
proc ::Mutator::run_mutator {} {
  variable psffile
  variable pdbfile
  variable outprefix
  variable targetressegname
  variable targetresid
  variable mutation
  variable fep
  variable fepprefix

  set command_line {}

  
  if { ($psffile == {}) || ($pdbfile == {} ) } {
      puts "Mutator: need file names"
      return
  }
    append command_line [concat "-psf" {$psffile} "-pdb" {$pdbfile}]
  

  if { $outprefix == {} } {
    puts "Mutator: need output filename prefix"
    return
  }
    set command_line [concat $command_line "-o" {$outprefix}]

  if { $targetressegname == {} } {
    puts "Mutator: all segments of protein will be mutated"
  } else {
    set command_line [concat $command_line "-ressegname" $targetressegname]
  }

  if { $targetresid == {} } {
    puts "Mutator: need ID of target residue"
    return
  }
  set command_line [concat $command_line "-resid" $targetresid]

  if { $mutation == {} } {
    puts "Mutator: need three letter residue name for mutation"
  } 
  set command_line [concat $command_line "-mut" $mutation]
    
  if { $fep } {
      if { $fepprefix == {}} {
	  puts "Mutator: need prefix for FEP files"
      }	
      set command_line [concat $command_line "-FEP" {$fepprefix}]
  }

  puts $command_line
  
  eval package require psfgen
  eval package require mutator
  eval mutator $command_line
}



proc ::Mutator::is_number {args} {
  if {[llength $args] != 1} {
    return 0
  }

  set x [lindex $args 0]
  if { ($x == {}) || [catch {expr $x + 0}]} {
    return 0
  } else {
    return 1
  }
}

proc mutator_tk {} {
  ::Mutator::mutator_gui
  return $::Mutator::w
}


