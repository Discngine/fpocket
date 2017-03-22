#
# Add ions to neutralize or achieve a desired concentration.
#
# Based on autoionize from Ilya Balabin
# Marcos Sotomayor.
# $Id: autoionizegui.tcl,v 1.3 2006/03/17 19:02:16 petefred Exp $
#
# TODO:
# - Incorporate in a more elegant way the option "neutralize" to
# autoionize core.
#
# - General cleanup and comments
#
# - Avoid use of "exec" (not available in Mac)

package require autoionize
package provide autoionizegui 1.0

proc autoigui {} {
  return [::Autoi::autoi_gui]
}
 
namespace eval ::Autoi:: {
  namespace export autoi_gui

  variable w

  variable psffile
  variable pdbfile
  variable outprefix
  variable concentrationc
  variable concentration
  variable neutralize
  variable userdef
  variable na
  variable cl
  variable mdistfmol
  variable mdistbion
  variable segid
  variable kclc
  
}

proc ::Autoi::autoi_gui {} {
  variable w

  ::Autoi::init_gui

  if { [winfo exists .autoigui] } {
    wm deiconify .autoigui
    return
  }
  set w [toplevel ".autoigui"]
  wm title $w "Autoionize"

  frame $w.intro
  grid [label $w.intro.label -text "Autoionize randomly places ions (NaCl/KCl)
in a previously solvated system."] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid columnconfigure $w.intro 1 -weight 1
  pack $w.intro -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.input
  grid [label $w.input.label -text "Input"] \
    -row 0 -column 0 -columnspan 3 -sticky w
  grid [label $w.input.psflabel -text "PSF: "] \
    -row 1 -column 0 -sticky w
  grid [entry $w.input.psfpath -width 30 -textvariable ::Autoi::psffile] \
    -row 1 -column 1 -sticky ew
  grid [button $w.input.psfbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Autoi::psffile $tempfile }
    }] -row 1 -column 2 -sticky w
  grid [label $w.input.pdblabel -text "PDB: "] \
    -row 2 -column 0 -sticky w
  grid [entry $w.input.pdbpath -width 30 -textvariable ::Autoi::pdbfile] \
    -row 2 -column 1 -sticky ew
  grid [button $w.input.pdbbutton -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} { set ::Autoi::pdbfile $tempfile }
    }] -row 2 -column 2 -sticky w
  grid columnconfigure $w.input 1 -weight 1
  pack $w.input -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.output
  grid [label $w.output.label -text "Output prefix:"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [entry $w.output.outpath -width 30 -textvariable ::Autoi::outprefix] \
    -row 0 -column 1 -sticky ew
#  grid [button $w.output.outbutton -text "Browse" \    -command {
#      set tempfile [tk_getOpenFile]
#      if {![string equal $tempfile ""]} { set ::Autoi::outprefix $tempfile }
#    }] -row 1 -column 1 -sticky w
  grid columnconfigure $w.output 0 -weight 1
  pack $w.output -side top -padx 10 -pady 10 -expand 1 -fill x

  

  frame $w.conc  
  grid [label $w.conc.label -text "Ionic Concentration (defined as (#Na + #Cl)/V)"] \
    -row 0 -column 0 -columnspan 2 -sticky w
  grid [checkbutton $w.conc.conc_button -text "Concentration (mol/L):" \
    -variable ::Autoi::concentrationc] -row 1 -column 0  -sticky w
  grid [entry $w.conc.concentry -width 8 -textvariable ::Autoi::concentration] \
    -row 1 -column 3 -sticky ew
  grid [checkbutton $w.conc.userd_button -text "User defined" \
    -variable ::Autoi::userdef] -row 2 -column 0 -sticky w
  grid [label $w.conc.nalabel -text "\# Na:"] \
    -row 2 -column 2 -sticky w
  grid [entry $w.conc.naentry -width 8 -textvariable ::Autoi::na] \
    -row 2 -column 3 -sticky ew
  grid [label $w.conc.cllabel -text "\# Cl:"] \
    -row 3 -column 2 -sticky w
  grid [entry $w.conc.clentry -width 8 -textvariable ::Autoi::cl] \
    -row 3 -column 3 -sticky ew
   ::Autoi::concentrationc_state
  grid [checkbutton $w.conc.neutr_button -text "Neutralize" \
    -variable ::Autoi::neutralize] -row 4 -column 0  -columnspan 3 -sticky w
  grid columnconfigure $w.conc 1 -weight 1
  pack $w.conc -side top -padx 10 -pady 10 -expand 1 -fill x 

  frame $w.dist
  grid [label $w.dist.distlabel -text "Min. distance from molecule (A):"] \
    -row 0 -column 0 -sticky w
  grid [entry $w.dist.distentry -width 8 -textvariable ::Autoi::mdistfmol] \
    -row 0 -column 3 -sticky ew
  grid [label $w.dist.dist2label -text "Min. distance between ions (A):"] \
    -row 1 -column 0 -sticky w
  grid [entry $w.dist.dist2entry -width 8 -textvariable ::Autoi::mdistbion] \
    -row 1 -column 3 -sticky ew
  grid columnconfigure $w.dist 1 -weight 1
  pack $w.dist -side top -padx 10 -pady 10 -expand 1 -fill x
  
  frame $w.seg
  grid [label $w.seg.seglabel -text "Segment ID:"] \
    -row 0 -column 0 -sticky w
  grid [entry $w.seg.segentry -width 8 -textvariable ::Autoi::segid] \
    -row 0 -column 3 -sticky ew
  grid columnconfigure $w.seg 1 -weight 1
  pack $w.seg -side top -padx 10 -pady 10 -expand 1 -fill x

  frame $w.kcl
  grid [checkbutton $w.kcl.kcl_button -text "Switch to KCl instead of NaCl" \
    -variable ::Autoi::kclc] -row 0 -column 0  -columnspan 3 -sticky w
  grid columnconfigure $w.kcl 1 -weight 1
  pack $w.kcl -side top -padx 10 -pady 10 -expand 1 -fill x 
 

  pack [button $w.autoi -text "Autoionize" -command ::Autoi::run_autoi] \
    -side top -padx 10 -pady 10 -expand 1 -fill x

 
  return $w
}

# Set up variables before opening the GUI
proc ::Autoi::init_gui {} {

  variable psffile
  variable pdbfile
  variable outprefix
  variable concentration
  variable concentrationc
  variable neutralize
  variable userdef
  variable na
  variable cl
  variable mdistfmol
  variable mdistbion
  variable segid
  variable kclc

  # 
  # Check if the top molecule has both pdb and psf files loaded: if it does,
  # use those as a default; otherwise, leave these fields blank.
  # 
  #
  set psffile {}
  set pdbfile {}
  set concentrationc 1
  set kclc 0
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

  set outprefix "ionized"
  set segid "ION"
  #set boundary 2.4
  #array set minpad {x 0 y 0 z 0}
  #array set maxpad {x 0 y 0 z 0}
  
  set concentration 0.5
  set neutralize 1
  set userdef 0
  set na 0
  set cl 0
  set mdistfmol 5
  set mdistbion 5


  # Add traces to the checkboxes, so various widgets can be disabled
  # appropriately
  if {[llength [trace info variable ::Autoi::concentrationc]] == 0} {
    trace add variable ::Autoi::concentrationc write ::Autoi::concentrationc_state
  }
  if {[llength [trace info variable ::Autoi::userdef]] == 0} {
    trace add variable ::Autoi::userdef write ::Autoi::userdef_state
  }

}

# Run autoionize from the GUI. Assembles a command line and passes it to
# autoionize
proc ::Autoi::run_autoi {} {
  variable psffile
  variable pdbfile
  variable outprefix
  variable concentration
  variable concentrationc
  variable neutralize
  variable userdef
  variable na
  variable cl
  variable mdistfmol
  variable mdistbion
  variable segid
  variable kclc

  set command_line {}

  
  if { ($psffile == {}) || ($pdbfile == {} ) } {
      puts "autoionize: need file names"
      return
  }
  append command_line [concat "-psf" $psffile "-pdb" $pdbfile]
  

  if { $outprefix == {} } {
    puts "autoionize: need output filename"
    return
  }
  set command_line [concat $command_line "-o" $outprefix]

  if { $segid == {} } {
    puts "autoionize: need segid"
    return
  }
  set command_line [concat $command_line "-seg" $segid]

  if {($concentrationc == 0 || $concentration == {}) && ($userdef ==0 || $na == {} || $cl == {}) && $neutralize == 0} {
    puts "autoionize: need concentration or number of Na and Cl ions or neutralize box checked"
    return
  }

  if {$concentrationc} {
    set command_line [concat $command_line "-is" $concentration]
  }
    
  if {$userdef} {
    if {$na == 0 && $cl == 0} {
	puts "autoionize: need a number of ions larger than 0"
        return
    }
    set command_line [concat $command_line "-nna" $na "-ncl" $cl]
  }

  if { $mdistfmol == {} } {
    puts "autoionize: need min distance from molecule "
    return
  }
  set command_line [concat $command_line "-from" $mdistfmol]

  if { $mdistfmol == {} } {
    puts "autoionize: need min distance between ions "
    return
  }
  set command_line [concat $command_line "-between" $mdistbion]
  
#  puts $command_line
  if {$concentrationc || $userdef} {
    eval package require autoionize
    eval autoionize $command_line
    mol delete top
  }
  if {$neutralize} {
    ::Autoi::neutralizer
  }
  if {$kclc} {
    ::Autoi::sod2pot
  }
}

proc ::Autoi::sod2pot {} {
#!/usr/local/bin/vmd -dispdev text
# replacing Na+ with K+ (or anything else with anything else)
# Ilya Balabin (ilya@ks.uiuc.edu), 2002-2003

variable outprefix

# define input files here
#set psffile "ionized.psf"
#set pdbfile "ionized.pdb"
#set prefix  "sod2pot"

# define what ions to replace with what ions
set ionfrom "SOD"
set ionto "POT"
#mol delete top

# do not change anything below this line
package require psfgen
global env
set topfile $env(AUTOIONIZEDIR)/ions.top
topology $topfile

puts "\nSod2pot) Reading ${outprefix}.psf/${outprefix}..."
resetpsf
readpsf ${outprefix}.psf
coordpdb ${outprefix}.pdb

mol load psf ${outprefix}.psf pdb ${outprefix}.pdb

set sel [atomselect top "name $ionfrom"]
set poslist [$sel get {x y z}]
set seglist [$sel get segid]
set reslist [$sel get resid]
set num [llength $reslist]
puts "Sod2pot) Found ${num} ${ionfrom} ions to replace..."

set num 0
foreach segid $seglist resid $reslist {
    delatom $segid $resid
    incr num
}
puts "Sod2pot) Deleted ${num} ${ionfrom} ions"

segment $ionto {
    first NONE
    last NONE
    foreach res $reslist {
	residue $res $ionto
    }
}
set num [llength $reslist]
puts "Sod2pot) Created ${num} topology entries for ${ionto} ions"

set num 0
foreach xyz $poslist res $reslist {
    coord $ionto $res $ionto $xyz
    incr num
}
puts "Sod2pot) Set coordinates for ${num} ${ionto} ions"

writepsf "${outprefix}.psf"
writepdb "${outprefix}.pdb"
puts "Sod2pot) Wrote ${outprefix}.psf/${outprefix}.pdb"
puts "Sod2pot) All done."

mol delete top
}


proc ::Autoi::neutralizer {} {
  variable psffile
  variable pdbfile
  variable outprefix
  variable concentration
  variable concentrationc
  variable neutralize
  variable userdef
  variable na
  variable cl
  variable mdistfmol
  variable mdistbion
  variable segid
  variable kclc
    

    set command_line2 {}

    if {$concentrationc || $userdef} {
	mol load psf ${outprefix}.psf pdb ${outprefix}.pdb  
	set charge [eval "vecadd [[atomselect top all] get charge]"]
        mol delete top
	if {[expr round($charge)] != 0} {	   
	    append command_line2 [concat "-psf" ${outprefix}.psf "-pdb" ${outprefix}.pdb "-o" $outprefix "-seg IO2"]
	    if {$charge>0} {
		set command_line2 [concat $command_line2 "-nna 0 -ncl [expr round($charge)]"]
	    } else { 
		set command_line2 [concat $command_line2 "-ncl 0 -nna [expr -1*round($charge)]"]
	    }
	    #puts $command_line2
	    #puts $charge
	    eval autoionize $command_line2
            mol delete top
	}
    } else {
	mol load psf $psffile pdb $pdbfile
        set charge [eval "vecadd [[atomselect top all] get charge]"]
        mol delete top
	if {[expr round($charge)] != 0} {
	    append command_line2 [concat "-psf" $psffile "-pdb" $pdbfile "-o" $outprefix "-seg IO2"]
	    if {$charge>0} {
		set command_line2 [concat $command_line2 "-nna 0 -ncl [expr round($charge)]"]
	    } else { 
		set command_line2 [concat $command_line2 "-ncl 0 -nna [expr -1*round($charge)]"]
	    }
	    #puts $command_line2
	    #puts $charge
	    eval autoionize $command_line2
            mol delete top
	} else {
	    puts "The system is already neutral"
            exec cp $psffile ${outprefix}.psf
	    exec cp $pdbfile ${outprefix}.pdb
	}
    }
}

# Disable or enable widgets according to the current status of the
# "Concentration" checkbutton
proc ::Autoi::concentrationc_state {args} {
  variable w
  variable concentrationc
  variable userdef

  # Disable the "User defined" button and Na Cl inputs
  if {$concentrationc} {
#    set userdef 0
    if {[winfo exists $w.conc.userd_button]} {
      $w.conc.userd_button configure -state disabled
    }
    if {[winfo exists $w.conc.clentry]} {
      $w.conc.clentry configure -state disabled
      $w.conc.cllabel configure -state disabled
    }
    if {[winfo exists $w.conc.naentry]} {
      $w.conc.naentry configure -state disabled
      $w.conc.nalabel configure -state disabled
    }
  } else {
    if {[winfo exists $w.conc.userd_button]} {
      $w.conc.userd_button configure -state normal
    }
    if {[winfo exists $w.conc.clentry]} {
      $w.conc.clentry configure -state normal
      $w.conc.cllabel configure -state normal
    }
    if {[winfo exists $w.conc.naentry]} {
      $w.conc.naentry configure -state normal
      $w.conc.nalabel configure -state normal
    }
  }

}

# Disable or enable widgets according to the current status of the
# "User defined" checkbutton
proc ::Autoi::userdef_state {args} {
  variable w
  variable concentrationc
  variable userdef

  if {$userdef} {
    if {[winfo exists $w.conc.conc_button]} {
      $w.conc.conc_button configure -state disabled
    }
    if {[winfo exists $w.conc.concentry]} {
      $w.conc.concentry configure -state disabled
    }    
  } else {
    if {[winfo exists $w.conc.conc_button]} {
      $w.conc.conc_button configure -state normal
    }
    if {[winfo exists $w.conc.concentry]} {
      $w.conc.concentry configure -state normal
    }
  }

}

proc ::Autoi::is_number {args} {
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

