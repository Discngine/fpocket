#
# Graphical interfaces for setting up a Gaussian job
#
# $Id: qmtool_setup.tcl,v 1.28 2007/03/02 12:14:12 saam Exp $
#

#####################################################
# Open window to edit gaussian setup file.          #
#####################################################

proc ::QMtool::setup_QM_simulation {args} {
   set writemode "ask"
   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      if {$i=="-force"}  then {
         set writemode "force"
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      incr argnum
   }
   variable basename
   variable checkfile
   variable fromcheckfile
   variable memory
   variable nproc
   variable method
   variable basisset
   variable simtype
   variable otherkey
   variable geometry
   variable guess
   variable title
   variable coordtype
   variable totalcharge
   variable multiplicity
   variable availmethods
   variable ncoords

   set oldvalues [list $basename $checkfile $fromcheckfile $memory $nproc $method $basisset \
		     $simtype $geometry $guess $title $coordtype $totalcharge $multiplicity]
   if {![llength $basename]}  { 
      if {[molinfo top]>=0} {
	 set basename [file rootname [molinfo top get name]]
      }
   }
   if {![llength $checkfile] && [llength $basename]} { set checkfile "$basename.chk" }
   if {![llength $memory]}    { set memory 1GB }
   if {![llength $nproc]}     { set nproc 1 }
   if {![llength $method] || $method=="HF"} { set method RHF }
   if {![llength $basisset]}  { set basisset "6-31G*" }
   if {![llength $simtype]}   { set simtype "Geometry optimization" }
   if {![llength $geometry]}  { set geometry "Z-matrix" }
   if {![llength $guess]}     { set guess "Guess (Harris)" }
   if {![llength $coordtype]} { 
      set coordtype "Internal (explicit)" 
      if {$ncoords==0} {set coordtype "Internal (auto)"}
   }
   if {![llength $title]}     { set title $basename }

   # If already initialized, just turn on
   if { [winfo exists .qm_setup] } {
      wm deiconify .qm_setup
      raise .qm_setup
      return
   }

   set v [toplevel ".qm_setup"]
   wm title $v "Setup GAMESS/Gaussian simulation"
   wm resizable $v 0 0

   labelframe $v.edit -text "Gaussian input settings" -bd 2 -padx 8 -pady 8
   label $v.edit.basenamelabel -text "Simulation basename:"
   entry $v.edit.basenameentry -textvariable ::QMtool::basename -width 60
   grid $v.edit.basenamelabel -column 0 -row 0 -sticky w
   grid $v.edit.basenameentry -column 1 -row 0 -sticky w 

   #label $v.edit.checkfilelabel -text "Checkpoint file:"
   #entry $v.edit.checkfileentry -textvariable ::QMtool::checkfile -width 60
   #grid $v.edit.checkfilelabel -column 0 -row 1 -sticky w
   #grid $v.edit.checkfileentry -column 1 -row 1 -sticky w

   label $v.edit.fcheckfilelabel -text "Based on checkpoint file:"
   entry $v.edit.fcheckfileentry -textvariable ::QMtool::fromcheckfile -width 60
   button $v.edit.fcheckfileopen -text "Choose" -command {::QMtool::opendialog check}
   grid $v.edit.fcheckfilelabel -column 0 -row 2 -sticky w
   grid $v.edit.fcheckfileentry -column 1 -row 2 -sticky w
   grid $v.edit.fcheckfileopen  -column 2 -row 2 -sticky we

   label $v.edit.memorylabel -text "Requested memory:"
   entry $v.edit.memoryentry -textvariable ::QMtool::memory -width 13
   grid $v.edit.memorylabel -column 0 -row 3 -sticky w
   grid $v.edit.memoryentry -column 1 -row 3 -sticky w

   label $v.edit.nproclabel -text "Number of processors:"
   entry $v.edit.nprocentry -textvariable ::QMtool::nproc -width 13
   grid $v.edit.nproclabel -column 0 -row 4 -sticky w
   grid $v.edit.nprocentry -column 1 -row 4 -sticky w

   label $v.edit.methodlabel -text "Method:"
   frame $v.edit.method
   entry $v.edit.method.entry -textvariable ::QMtool::method -width 13 -validate all

   set m [eval [subst "tk_optionMenu $v.edit.method.button ::QMtool::method $availmethods"]]
   pack  $v.edit.method.entry $v.edit.method.button -side left -anchor w
   grid $v.edit.methodlabel  -column 0 -row 5 -sticky w
   grid $v.edit.method       -column 1 -row 5 -sticky w
#    foreach amethod $availmethods {
#       set pos [lsearch $availmethods $amethod]
#       if {[string match {CBS-*} $amethod]} {
# puts "$pos $amethod"
# 	 $m entryconfigure $pos -vcmd {
# puts DISABLED
# 	    set ::QMtool::simtype "Single point"
# 	    .qm_setup.edit.type.simtypebutton configure -state disabled
# 	 }
#        } else {
# 	 $m entryconfigure $pos -command {
# 	    .qm_setup.edit.type.simtypebutton configure -state normal
# 	 }
#       }
#    }

   label $v.edit.basislabel -text "Basis set:"
   frame $v.edit.basis
   entry $v.edit.basis.entry -textvariable ::QMtool::basisset -width 13
   tk_optionMenu $v.edit.basis.button ::QMtool::basisset \
      "STO-3G" "3-21G" "6-31G" "6-31G*" "6-31+G*" "6-31+G* 5D 7F" "6-31+G* 6D 10F"
   pack $v.edit.basis.entry $v.edit.basis.button -side left -anchor w
   grid $v.edit.basislabel  -column 0 -row 6 -sticky w
   grid $v.edit.basis       -column 1 -row 6 -sticky w

   $v.edit.method.entry configure -vcmd { 
      if {[regexp {AM1|PM3|MNDO|CNDO|INDO} $::QMtool::method] || [string match "CBS-*" $::QMtool::method] } { 
	 .qm_setup.edit.basis.entry  configure -state disabled
	 .qm_setup.edit.basis.button configure -state disabled
      } else {
	 .qm_setup.edit.basis.entry  configure -state normal
	 .qm_setup.edit.basis.button configure -state normal
      }
      if {[string match "CBS-*" $::QMtool::method]} {
	 set ::QMtool::simtype "Single point"
	 .qm_setup.edit.type.simtypebutton configure -state disabled
      } else {
	 .qm_setup.edit.type.simtypebutton configure -state normal
      }
      return 1
   }

   label $v.edit.typelabel -text "Simulation type:"
   frame $v.edit.type
#    checkbutton $v.edit.type.simtypebutton.opt  -text "Geometry optimization" -variable ::QMtool::optimize \
#       -command { 
# 	 if {$::QMtool::optimize} {
# 	    .qm_setup.edit.guessbutton configure -state normal
# 	    .qm_setup.edit.coordbutton configure -state normal
# 	 } else {

# 	 }
#       }
#   checkbutton $v.edit.type.simtypebutton.freq -text "Frequency calculation" -variable ::QMtool::frequency
#   pack $v.edit.type.simtypebutton.opt $v.edit.type.simtypebutton.freq -anchor w
   set m [tk_optionMenu $v.edit.type.simtypebutton ::QMtool::simtype "Single point" "Geometry optimization" "Frequency" \
	      "Coordinate transformation"]
   $m entryconfigure 0 -command {
      .qm_setup.edit.guessbutton configure -state normal
      .qm_setup.edit.coordbutton configure -state disabled
      .qm_setup.edit.type.hindrot configure -state disabled
   }
   $m entryconfigure 1 -command {
      .qm_setup.edit.guessbutton configure -state normal
      .qm_setup.edit.coordbutton configure -state normal
      .qm_setup.edit.type.hindrot configure -state disabled
   }
   $m entryconfigure 2 -command {
      .qm_setup.edit.guessbutton configure -state normal
      .qm_setup.edit.coordbutton configure -state normal
      .qm_setup.edit.type.hindrot configure -state normal
   }
   $m entryconfigure 3 -command {
      .qm_setup.edit.guessbutton configure -state disabled
      .qm_setup.edit.coordbutton configure -state normal
      .qm_setup.edit.type.hindrot configure -state disabled
   }
   pack $v.edit.type.simtypebutton -side left -anchor w

   checkbutton $v.edit.type.hindrot -text "Hindered Rotor Analysis" -variable ::QMtool::hinderedrotor
   pack $v.edit.type.hindrot -padx 3m -side left -anchor w

   grid $v.edit.typelabel  -column 0 -row 7 -sticky w
   grid $v.edit.type       -column 1 -row 7 -sticky w


   label $v.edit.geomlabel -text "Geometry from:"
   set m [tk_optionMenu $v.edit.geombutton ::QMtool::geometry "Z-matrix" "Checkpoint file"]
   $m entryconfigure 0 -command {
      .qm_setup.edit.chargeentry configure -state normal
      .qm_setup.edit.multipentry configure -state normal
      if {$::QMtool::guess=="Guess (Harris)"} {
	 .qm_setup.edit.fcheckfileentry configure -state disabled
      }
      if {$::QMtool::guess=="Read geometry and wavefunction from checkfile"} {
	 set ::QMtool::guess "Take guess from checkpoint file"
      }
   }
   $m entryconfigure 1 -command {
      .qm_setup.edit.fcheckfileentry configure -state normal
   }
   grid $v.edit.geomlabel -column 0 -row 8 -sticky w
   grid $v.edit.geombutton -column 1 -row 8 -sticky w

   label $v.edit.guesslabel -text "Initial wavefunction:"
   set m [tk_optionMenu $v.edit.guessbutton ::QMtool::guess "Guess (Harris)" \
	     "Take guess from checkpoint file" "Read geometry and wavefunction from checkfile"]
   $m entryconfigure 0 -command {
      .qm_setup.edit.chargeentry configure -state normal
      .qm_setup.edit.multipentry configure -state normal
      if {$::QMtool::geometry=="Z-matrix"} {
	 .qm_setup.edit.fcheckfileentry configure -state disabled
      }
   }
   $m entryconfigure 1 -command {
      .qm_setup.edit.chargeentry configure -state normal
      .qm_setup.edit.multipentry configure -state normal
      .qm_setup.edit.fcheckfileentry configure -state normal
   }
   $m entryconfigure 2 -command {
      set ::QMtool::geometry "Checkpoint file"
      .qm_setup.edit.chargeentry configure -state disabled
      .qm_setup.edit.multipentry configure -state disabled
      .qm_setup.edit.fcheckfileentry configure -state normal
   }
   grid $v.edit.guesslabel -column 0 -row 9 -sticky w
   grid $v.edit.guessbutton -column 1 -row 9 -sticky w

   label $v.edit.coordlabel -text "Coordinates for Opt/Freq:"
   tk_optionMenu $v.edit.coordbutton ::QMtool::coordtype "Internal (auto)" \
      "Internal (explicit)" "ModRedundant" 
   grid $v.edit.coordlabel  -column 0 -row 10 -sticky w
   grid $v.edit.coordbutton -column 1 -row 10 -sticky w

   label $v.edit.solvlabel -text "Solvent:"
   tk_optionMenu $v.edit.solvbutton ::QMtool::solvent None \
      Water Acetonitrile DiMethylSulfoxide Methanol Ethanol Isoquinoline Quinoline \
      Chloroform Ether DiChloroMethane DiChloroEthane CarbonTetrachloride Benzene Toluene \
      ChloroBenzene NitroMethane Heptane CycloHexane Aniline Acetone TetraHydroFuran \
      Argon Krypton Xenon
   grid $v.edit.solvlabel  -column 0 -row 11 -sticky w
   grid $v.edit.solvbutton -column 1 -row 11 -sticky w

   label $v.edit.pcmlabel -text "PCM Method:"
   tk_optionMenu $v.edit.pcmbutton ::QMtool::PCMmethod IEFPCM CPCM IPCM SCIPCM DIPOLE
   grid $v.edit.pcmlabel  -column 0 -row 12 -sticky w
   grid $v.edit.pcmbutton -column 1 -row 12 -sticky w

   checkbutton $v.edit.dgsolv  -text "Calculate dG of solvation"  -variable ::QMtool::calcdGsolv
   grid $v.edit.dgsolv   -column 1 -row 13 -sticky w

   label $v.edit.chargeslabel -text "Charges:"
   checkbutton $v.edit.chargesesp  -text "ESP charges"  -variable ::QMtool::calcesp
   checkbutton $v.edit.chargesnpa  -text "NPA charges"  -variable ::QMtool::calcnpa
   grid $v.edit.chargeslabel -column 0 -row 14 -sticky w
   grid $v.edit.chargesesp   -column 1 -row 14 -sticky w
   grid $v.edit.chargesnpa   -column 1 -row 15 -sticky w

   label $v.edit.nbolabel -text "Natural Bond Orbitals:"
   checkbutton $v.edit.nbopop -text "NBO population analysis" -variable ::QMtool::calcnbo -command {
      if {$::QMtool::calcnbo} { 
	 .qm_setup.edit.nbolewis.check configure -state normal
      } else {
	 .qm_setup.edit.nbolewis.check configure -state disabled
      }
   }

   frame $v.edit.nbolewis
   checkbutton $v.edit.nbolewis.check -text "Specify Lewis structure in 'CHOOSE' statement  " \
      -variable ::QMtool::calcnboread 
   button $v.edit.nbolewis.edit -text "Edit Lewis structure in Molefacture" -command [namespace code {
      molefacture_start
   }]
   pack  $v.edit.nbolewis.check $v.edit.nbolewis.edit -side left
   if {$::QMtool::calcnbo} { 
      .qm_setup.edit.nbolewis.check configure -state normal
   } else {
      .qm_setup.edit.nbolewis.check configure -state disabled
   }

   grid $v.edit.nbolabel -column 0 -row 16 -sticky w
   grid $v.edit.nbopop   -column 1 -row 16 -sticky w
   grid $v.edit.nbolewis -column 1 -row 17 -sticky w


   label $v.edit.otherlabel -text "Other keywords:"
   entry $v.edit.otherentry -textvariable ::QMtool::otherkey  -width 72
   grid $v.edit.otherlabel -column 0 -row 18 -sticky w
   grid $v.edit.otherentry -column 1 -row 18 -sticky w -columnspan 2

   variable autotitle
   variable extratitle
   label $v.edit.titlelabel -text "Title string:"
   label $v.edit.extratitle -textvariable ::QMtool::extratitle -width 70
   text $v.edit.titleentry -setgrid 1 -width 72 -height 2; 
   $v.edit.titleentry insert 0.0 $title
   grid $v.edit.titlelabel -column 0 -row 19 -sticky nw
   grid $v.edit.titleentry -column 1 -row 19 -sticky w -columnspan 2

   label $v.edit.chargelabel -text "Total charge:"
   entry $v.edit.chargeentry -textvariable ::QMtool::totalcharge  -width 11
   grid $v.edit.chargelabel -column 0 -row 20 -sticky w
   grid $v.edit.chargeentry -column 1 -row 20 -sticky w

   label $v.edit.multiplabel -text "Multiplicity:"
   entry $v.edit.multipentry -textvariable ::QMtool::multiplicity  -width 11
   grid $v.edit.multiplabel -column 0 -row 21 -sticky w
   grid $v.edit.multipentry -column 1 -row 21 -sticky w


   # frame for Ok/Cancel buttons
   frame $v.okcancel     
   button $v.okcancel.gamess  -text "Write GAMESS input file" \
      -command {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "Sorry, this feature will be available in a future version!"
      }
   button $v.okcancel.gauss  -text "Write Gaussian input file" \
      -command "::QMtool::edit_gaussian_ok $writemode"

   pack  $v.okcancel.gamess $v.okcancel.gauss -side left -anchor w


   pack $v.edit -padx 6 -pady 6
   pack $v.okcancel -padx 2 -pady 2

   
   # Invoke some GUI updates
   if {$simtype=="Coordinate transformation"} { 
      .qm_setup.edit.guessbutton configure -state disabled
      .qm_setup.edit.type.hindrot configure -state disabled
   }
   if {$simtype=="Single point"} { 
      .qm_setup.edit.coordbutton configure -state disabled
      .qm_setup.edit.type.hindrot configure -state disabled
   }
   if {$simtype=="Geometry optimization"} { 
	 .qm_setup.edit.type.hindrot configure -state disabled
   }

   $v.edit.method.entry validate

}

proc ::QMtool::edit_gaussian_cancel { oldvalues } {
   variable basename
   variable checkfile
   variable fromcheckfile
   variable memory
   variable nproc
   variable method
   variable basisset
   variable simtype
   variable otherkey
   variable geometry
   variable guess
   variable title
   variable coordtype
   variable totalcharge
   variable multiplicity

   set basename  [lindex $oldvalues 0]
   set fromcheckfile [lindex $oldvalues 1]
   set checkfile [lindex $oldvalues 2]
   set memory    [lindex $oldvalues 3]
   set nproc     [lindex $oldvalues 4]
   set method    [lindex $oldvalues 5]
   set basisset  [lindex $oldvalues 6]
   set simtype   [lindex $oldvalues 7]
   set otherkey  [lindex $oldvalues 8]
   set geometry  [lindex $oldvalues 9]
   set guess     [lindex $oldvalues 10]
   set title     [lindex $oldvalues 11]
   set coordtype [lindex $oldvalues 12]
   set totalcharge  [lindex $oldvalues 13]
   set multiplicity [lindex $oldvalues 14]
   destroy .qm_setup
}

proc ::QMtool::edit_gaussian_ok { {action "close"}} {

   variable w
   variable basename
   variable checkfile
   variable fromcheckfile
   variable memory
   variable nproc
   variable method
   variable basisset
   variable simtype
   variable otherkey
   variable geometry
   variable guess
   variable autotitle {}
   variable extratitle {}
   variable coordtype
   variable route "#"
   variable totalcharge
   variable multiplicity
   variable ncoords
   variable natoms
   variable calcesp
   variable calcnpa
   variable calcnbo
   variable calcnboread
   variable havelewis
   set iops {}
   set popkeys {}

   if {$action!="close"} {
      if {$guess!="Read geometry and wavefunction from checkfile" && \
	     (![llength $totalcharge] || ![llength $multiplicity])} {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "Total charge and multiplicity must be defined!" 
	 focus .qm_setup.edit.chargeentry
	 return 0
      }
      
      if {($simtype=="Coordinate transformation" || $geometry=="Checkpoint file" || \
	      $guess!="Guess (Harris)") && ![llength $fromcheckfile]} {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "Checkpoint file must be defined!" 
	 focus .qm_setup.edit.fcheckfileentry
	 return 0
      }

      if {($simtype=="Coordinate transformation" || $geometry=="Checkpoint file" || \
	      $guess!="Guess (Harris)") && [llength $fromcheckfile] && ![file exists $fromcheckfile]} {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "Couln't find checkpoint file $fromcheckfile! \nCopy file into working directory manually or choose \"Geometry from: Z-matrix\" and \"Initial wavefunction: Guess\"." 
	 return 0
      }
      
      if {$coordtype=="Internal (explicit)" && $ncoords<3*$natoms-6} {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "Must have at least 3*natoms-6=[expr {3*$natoms-6}] coordinates.\nCurrently only $ncoords coordinates are defined."
	 return 0
      }
   }

   # The basisset is not needed in semiempirical methods, its always STO-3G.
   append route " $method"
   if {![regexp {AM1|PM3|MNDO|CNDO|INDO} $method] && ![string match "CBS-*" $method]} {
      append route "/$basisset"
   }

   if {$geometry=="Checkpoint file"} {
      if {$guess=="Read geometry and wavefunction from checkfile"} {
	 if {$coordtype=="ModRedundant" || $coordtype=="Internal (explicit)"} {
	    append route " Geom=(AllCheck,ModRedundant)"
	 } elseif {$coordtype=="Internal (auto)"} {
	    append route " Geom=(AllCheck,NewRedundant)"
	 } else {
	    append route " Geom=AllCheck"
	 }
      } else {
	 append route " Geom=Checkpoint"
      }
   } 

   if {$guess=="Take guess from checkpoint file" && $simtype!="Coordinate transformation"} {
      append route " Guess=Read"
   }

   if {$simtype=="Geometry optimization" || $simtype=="Relaxed potential scan" || $simtype=="Rigid potential scan"} {
      variable optmaxcycles
      if {$coordtype=="Internal (auto)"} {
	 append route " Opt=(Redundant"
	 if {[llength $optmaxcycles]} { append route ",MaxCycle=$optmaxcycles" }
	 append route ")"
      } else {
	 append route " Opt=(ModRedundant"
	 if {[llength $optmaxcycles]} { append route ",MaxCycle=$optmaxcycles" }
	 append route ")"
      }
      if {$simtype=="Relaxed potential scan"} {
	 lappend popkeys "None"
	 append autotitle "<qmtool> simtype=\"Relaxed potential scan\" </qmtool>"
      } elseif {$simtype=="Rigid potential scan"} {
	 lappend popkeys "None"
	 append autotitle "<qmtool> simtype=\"Rigid potential scan\" </qmtool>"
      } else {
	 append autotitle "<qmtool> simtype=\"Geometry optimization\" </qmtool>"
      }
   } elseif {$simtype=="Frequency"} {
      variable hinderedrotor
      if {$coordtype=="Internal (auto)"} {
	 if {$hinderedrotor} { 
	    append route " Freq=(HinderedRotor)" 
	 } else {
	    append route " Freq"
	 }
      } else {
	 if {$hinderedrotor} { 
	    append route " Freq=(ModRedundant,HinderedRotor)" 
	 } else {
	    append route " Freq=(ModRedundant)"
	 }
      }
      lappend iops "7/33=1"
      set otherkey [string trim [regsub -nocase {iop\(7/33=1\)} $otherkey ""]]
      append autotitle "<qmtool> simtype=\"Frequency analysis\" </qmtool>"
   } elseif {$simtype=="Coordinate transformation"} {
      append route " Freq=(Modredundant,ReadFC)"
      lappend iops "7/33=2"
      set otherkey [string trim [regsub -nocase -all {iop\(7/33=[12]\)} $otherkey ""]]   
      append autotitle "<qmtool> simtype=\"Transformation of force constants from cartesian to internal coordinates\" </qmtool>"
   #} elseif {$simtype=="Rigid potential scan"} {
   #   append route " Scan NoSymm"
   #   append autotitle "<qmtool> simtype=\"Rigid potential scan\" </qmtool>"
   } else {
      append autotitle "<qmtool> simtype=\"Single point calculation\" </qmtool>"
   }

   if {$calcesp} {
      variable molid
      lappend popkeys "ESP" 
      set sel [atomselect $molid "atomicnumber>17"]
      if {[$sel num]} { lappend popkeys "ReadRadii" }
      $sel delete

      # Print the fitting points
      # For paranoid quality also use 6/41=10, 6/42=15" (10 layers, desity 17=^2500 points/atom; 10=^1000points/atom)
      lappend iops    "6/33=2"; 
      append route " NoSymm"
   }
   if {$calcnpa} {
      lappend popkeys "NPA"
   }
   if {$calcnbo} {
      lappend popkeys "NBO"
   }
   if {$calcnboread} {
      lappend popkeys "NBORead"
      if {![llength $havelewis]} {
	 tk_messageBox -icon error -type ok -title Message -parent .qm_setup \
	    -message "NBO analysis: No Lewis structure defined!\nUse Molefacture to define it." 
	 return 0
      }
   }

   variable PCMmethod
   variable solvent
   if {$solvent!="None"} {
      append route " SCRF=($PCMmethod,Solvent=$solvent"
      if {![regexp "SCIPCM|IPCM" $PCMmethod]} {
	 append route ",Read"
      }
      append route ")"
   }

   set iops    [join [lsort -unique -ascii $iops] ","]
   set popkeys [join [lsort -unique -ascii $popkeys] ","]
   if {[llength $popkeys]} {
      append route " Pop=($popkeys)"
   }
   if {[llength $iops]} {
      append route " IOp($iops)"
   }
   append route " $otherkey"


   if {$action=="close"} { after idle {destroy .qm_setup} }
   
   if {[llength $fromcheckfile]} {
      append extratitle "<qmtool> parent=$fromcheckfile </qmtool>"
   }

   if {[llength $fromcheckfile]} {
      if {[file exists $basename.chk]} {
	 file rename -force $basename.chk $basename.chk.BAK
      }
      file copy -force $fromcheckfile $basename.chk
      file mtime $basename.chk [clock seconds]
   }
   set checkfile $basename.chk

   set ::QMtool::title [string trimright [.qm_setup.edit.titleentry get 0.0 end]]

   if {$action=="ask"} { 
      opendialog writecom $basename.com
   } elseif {$action=="force"} {
      write_gaussian_input $basename.com
      destroy .qm_setup
   }
}


proc ::QMtool::write_gaussian_input { file } {
   variable route
   variable title
   variable autotitle
   variable extratitle
   variable totalcharge
   variable multiplicity
   variable checkfile
   variable nproc
   variable memory
   variable guess
   variable route
   variable title 
   variable coordtype
   variable geometry
   variable atoms
   variable zmat
   variable calcesp
   variable calcresp
   variable calcnbo
   variable calcnboread
   variable solvent
   puts "checkfile2=$checkfile"

   set fid [open $file w]
   puts $fid "%chk=$checkfile"
   puts $fid "%nproc=$nproc"
   puts $fid "%mem=$memory"
   puts $fid $route
   puts $fid ""

   # title and coordinates are not put out if Geom=AllCheck:
   if {!($guess=="Read geometry and wavefunction from checkfile")} {
      set alltitle {}
      if {[llength $autotitle]}  {append alltitle "${autotitle}"}
      if {[llength $extratitle]} {append alltitle "\n${extratitle}"}
      if {[llength $title]}      {append alltitle "\n${title}"}
      
      # title line may not be longer than 80 chars, break it if necessary
      if {[llength $alltitle]} { 
	 set newtitle [break_lines $alltitle 5 79]
	 puts $fid $newtitle
      }
      puts $fid ""
      puts $fid "$totalcharge $multiplicity"
      
      if {$geometry!="Checkpoint file"} {
 	 variable molid
 	 set sel [atomselect $molid all]
 	 foreach coord [$sel get {x y z}] atom [$sel get index] {
 	    # We have to get the name from atomproplist instead of $sel 
 	    # since Paratool might change the names in QMtool.
 	    set name [get_atomprop Name $atom]
	    puts $fid "$name $coord"
 	 }
 	 $sel delete
	 puts $fid ""
      }  
   }

   if {$coordtype=="Internal (explicit)" && [llength $zmat]} {
      # First delete all existing coordinates
      puts $fid "B * * R"
      puts $fid "A * * * R"
      puts $fid "L * * * R"
      puts $fid "D * * * * R"
      puts $fid "O * * * * R"
   }

   if {$coordtype=="ModRedundant" || $coordtype=="Internal (explicit)"} {
      # Fixed cartesian coordinates
      variable atomproplist
      set num 1
      foreach atom $atomproplist {
	 if {[string match {*F*} [get_atomprop Flags [expr {$num-1}]]]} {
	    puts $fid "X $num B"
	    puts $fid "X $num F"
	 }
	 incr num
      }
      # Add internal coordinates explicitly:
      set num 0
      foreach entry $zmat {
	 if {$num==0} { incr num; continue }
	 set indexes {}
	 foreach ind [lindex $entry 2] {
	    lappend indexes [expr {$ind+1}]
	 }
	 set type [string toupper [string index [lindex $entry 1] 0]]
	 # We must model impropers as dihedrals because Gaussian ignores
	 # out-of-plane bends.
	 if {$type=="I"} { set type "D" }
	 if {$type=="O"} { set type "D" }
	 # Something is weird with the linear bend format in Gaussian:
	 if {$type=="L"} { 
	    set val {}
	 } else {
	    set val [lindex $entry 3]
	 }
	 set scan {}
	 if {[string match {*S*} [lindex $entry 5]]} {
	    variable scansteps
	    variable scanstepsize
	    set val "[expr {[lindex $entry 3]-0.5*$scansteps*$scanstepsize}]"
	    set scan "$scansteps $scanstepsize"
	 } else { 
	 }
	 puts $fid "$type $indexes $val [regsub {[QCRM]} [lindex $entry 5] {}]  $scan"
	 incr num
      }
      puts $fid ""
   }

   variable PCMmethod
   variable calcdGsolv
   variable solvent
   if {![regexp "SCIPCM|IPCM" $PCMmethod] && $solvent!="None"} {
      puts $fid "RADII=UAHF"
      if {$calcdGsolv} {
	 puts $fid "SCFVAC"
      }
      puts $fid ""
   }

   if {$calcesp} {
      variable molid
      set sel [atomselect $molid all]
      foreach atomicnum [$sel get atomicnumber] {
	 # Merz-Kollman radii in Gaussian are only defined from H - Cl
	 # thus we have to specify the others explicitely
	 if {$atomicnum>17} { 
	    set element [atomnum2element $atomicnum]
	    set radius  [get_esp_radius $element]
	    puts $fid "$element $radius"
	 }
      }
      $sel delete
      puts $fid ""
   }

   if {$calcnboread} {
      write_nbo_input $fid
      puts $fid ""
   }

   close $fid
}

proc ::QMtool::write_gamess_input { file } {
   variable route
   variable title
   variable autotitle
   variable extratitle
   variable totalcharge
   variable multiplicity
   variable checkfile
   variable nproc
   variable memory
   variable guess
   variable route
   variable title 
   variable coordtype
   variable geometry
   variable atoms
   variable zmat
   variable calcesp
   variable calcresp
   variable calcnbo
   variable calcnboread
   variable solvent

   set fid [open $file w]

   # title and coordinates are not put out if Geom=AllCheck:
   set alltitle {}
   if {[llength $autotitle]}  {append alltitle "${autotitle}"}
   if {[llength $extratitle]} {append alltitle "\n${extratitle}"}
   if {[llength $title]}      {append alltitle "\n${title}"}
   
   # In Gaussian the title line may not be longer than 80 chars, break it if necessary
   if {[llength $alltitle]} { 
      set newtitle [break_lines $alltitle 5 79]
      foreach line [split $newtitle {\n}] {
	 puts $fid "! $line"
      }
   }
   puts $fid ""
   
   puts $fid " \$CONTRL SCFTYP=$method RUNTYP=OPTIMIZE COORD=CART NZVAR=36"
   puts $fid "ICHARG=$totalcharge MULT=$multiplicity \$END"
   puts $fid " \$SYSTEM MEMORY=$memory \$END"
   puts $fid " \$BASIS NGAUSS=6 GBASIS=N31 \$END"
   puts $fid " \$DATA"
   puts $fid "C1"; # Symmetry group
   variable molid
   set sel [atomselect $molid all]
   foreach coord [$sel get {x y z}] atom [$sel get index] atomicnum [$sel get atomicnumber] {
      # We have to get the name from atomproplist instead of $sel 
      # since Paratool might change the names in QMtool.
      set name [get_atomprop Name $atom]
      puts $fid "$name $atomicnum $coord"
   }
   $sel delete
   puts $fid " \$END"



   if {$coordtype=="Internal (explicit)" && [llength $zmat]} {
      # First delete all existing coordinates
      puts $fid "B * * R"
      puts $fid "A * * * R"
      puts $fid "L * * * R"
      puts $fid "D * * * * R"
      puts $fid "O * * * * R"
   }

   if {$coordtype=="ModRedundant" || $coordtype=="Internal (explicit)"} {
      # Fixed cartesian coordinates
      variable atomproplist
      set num 1
      foreach atom $atomproplist {
	 if {[string match {*F*} [get_atomprop Flags [expr {$num-1}]]]} {
	    puts $fid "X $num B"
	    puts $fid "X $num F"
	 }
	 incr num
      }
      # Add internal coordinates explicitly:
      set num 0
      foreach entry $zmat {
	 if {$num==0} { incr num; continue }
	 set indexes {}
	 foreach ind [lindex $entry 2] {
	    lappend indexes [expr {$ind+1}]
	 }
	 set type [string toupper [string index [lindex $entry 1] 0]]
	 # We must model impropers as dihedrals because Gaussian ignores
	 # out-of-plane bends.
	 if {$type=="I"} { set type "D" }
	 if {$type=="O"} { set type "D" }
	 # Something is weird with the linear bend format in Gaussian:
	 if {$type=="L"} { 
	    set val {}
	 } else {
	    set val [lindex $entry 3]
	 }
	 set scan {}
	 if {[string match {*S*} [lindex $entry 5]]} {
	    variable scansteps
	    variable scanstepsize
	    set val "[expr {[lindex $entry 3]-0.5*$scansteps*$scanstepsize}]"
	    set scan "$scansteps $scanstepsize"
	 } else { 
	 }
	 puts $fid "$type $indexes $val [regsub {[QCRM]} [lindex $entry 5] {}]  $scan"
	 incr num
      }
      puts $fid ""
   }

   variable PCMmethod
   variable calcdGsolv
   variable solvent
   if {![regexp "SCIPCM|IPCM" $PCMmethod] && $solvent!="None"} {
      puts $fid "RADII=UAHF"
      if {$calcdGsolv} {
	 puts $fid "SCFVAC"
      }
      puts $fid ""
   }

   if {$calcesp} {
      variable molid
      set sel [atomselect $molid all]
      foreach atomicnum [$sel get atomicnumber] {
	 # Merz-Kollman radii in Gaussian are only defined from H - Cl
	 # thus we have to specify the others explicitely
	 if {$atomicnum>17} { 
	    set element [atomnum2element $atomicnum]
	    set radius  [get_esp_radius $element]
	    puts $fid "$element $radius"
	 }
      }
      $sel delete
      puts $fid ""
   }

   if {$calcnboread} {
      write_nbo_input $fid
      puts $fid ""
   }

   close $fid
}


################################################################################################
# Merz-Kollman radii (actually Pauling's radii) are only defined from H - Cl and for Br.       #
# Mopac has defined default radii to complete the table trough Bi and uses them whenever       #
# there are no MK-radii. We'll follow the same strategy here and shamelessly steal th radii    #
# from Mopacs manual.                                                                          #
# This is the complete list of radii for all elements from H-Bi.                               #
# The function returns the radius for the given element.                                       #
################################################################################################

proc ::QMtool::get_esp_radius { element } {
   array set radii {H 1.20 He 1.20 Li 1.37 Be 1.45 B 1.45 C 1.50 N 1.50 O 1.40 F 1.35 Ne 1.30 Na 1.57 Mg 1.36 Al 1.24 Si 1.17 P 1.80 S 1.75 Cl 1.70 Ar 1.88 K 2.75 Ca 2.17 Sc 2.26 Ti 2.26 V 2.15 Cr 2.05 Mn 2.10 Fe 2.06 Co 2.05 Ni 1.63 Cu 1.40 Zn 1.39 Ga 1.87 Ge 2.10 As 1.85 Se 1.90 Br 1.80 Kr 2.02 Rb 3.23 Sr 2.94 Y 2.90 Zr 2.85 Nb 2.80 Mo 2.20 Tc 2.20 Ru 2.20 Rh 2.20 Pd 1.63 Ag 1.72 Cd 1.58 In 1.93 Sn 2.17 Sb 2.16 Te 2.06 I 1.98 Xe 2.16 Cs 3.42 Ba 2.97 La 2.40 Hf 2.20 Ta 2.20 W 2.20 Re 2.20 Os 2.20 Ir 2.20 Pt 1.75 Au 1.66 Hg 1.55 Tl 1.96 Pb 2.02 Bi 2.26}

   return [lindex [array get radii $element] 1]
}

proc ::QMtool::write_nbo_input { fid } {
   variable method
   variable zmat
   variable lewislonepairs {}
   variable molid
   array set octet {{} 0 H 2 HE 2 \
			LI 8 BE 8 B 8 C 8 N 8 O 8 F 8 NE 8 NA 8 MG 8 AL 8 SI 8 P 12 S 8 CL 8 AR 8 \
			K 18 CA 18 SC 18 TI 18 V 18 CR 18 MN 18 FE 18 CO 18 NI 18 CU 18 ZN 18 \
			GA 18 GE 18 AS 18 SE 18 BR 18 KR 18 RB 18 SR 18 Y 18 ZR 18 \
			NB 18 MO 18 TC 18 RU 18 RH 18 PD 18 AG 18 CD 18 IN 18 SN 18 SB 18 \
			TE 18  I 18 XE 18 CS 32 BA 0 LA 0 CE 0 PR 0 ND 0 PM 0 SM 0 EU 0 GD 0 TB 0 \
			DY 0 HO 0 ER 0 TM 0 YB 0 LU 0 HF 0 TA 0 W 0 RE 0 OS 0 \
			IR 0 PT 0 AU 0 HG 0 TL 0 PB 0 BI 0 PO 0 AT 0 RN 0 }

   set sel [atomselect $molid all]
   foreach i [$sel list] bonds [$sel getbonds] bos [$sel getbondorders] {
      set lewischarge [get_atomprop Lewis $i]
      set element     [string toupper [get_atomprop Elem  $i]]
      set nbonds 0 
      foreach bo $bos {
	 set bo [expr {int($bo)}]
	 if {$bo < 0} { set bo 1 } 
	 incr nbonds $bo
      }
      set valence [expr {$nbonds-$lewischarge}]
      set numlonepairs [expr {[lindex [array get octet $element] 1]/2-$valence}]
      lappend lewislonepairs $numlonepairs
   }
   $sel delete

   variable molid
   variable molidlist  
   variable molnamelist  
   set filename [lindex $molnamelist [lsearch $molidlist $molid] 1]
   set nbofilename [regsub {(_opt)|(_sp)$} [file rootname $filename] {}]_nbo
   

   puts $fid "\$NBO RESONANCE NLMO PLOT"
   if {[llength $nbofilename]} { puts $fid "     FILE=$nbofilename" }
   puts $fid "\$END"
   puts $fid "\$CHOOSE"
   
   if {[string index $method 0]=="U"} { puts $fid "  ALPHA" }
   
   # Lone pairs
   puts -nonewline $fid "  LONE "
   set index 0
   foreach lp $lewislonepairs {
      puts -nonewline $fid "$index $lp "
      incr index
      if {!($index%8)} { puts -nonewline $fid "\n       " }
   }
   puts $fid " END"
   
   # Bonds
   puts -nonewline $fid "  BOND "
   set i 0
   foreach entry $zmat {
      set type [lindex $entry 1]
      if {![string match "*bond" $type]} { continue }
      set atom0 [lindex $entry 2 0]
      set atom1 [lindex $entry 2 1]
      #set bo [string index $type 0]
      set sel0 [atomselect $molid "index $atom0"]
      set sel1 [atomselect $molid "index $atom1"]
      set pos1in0 [lsearch [join [$sel0 getbonds]] $atom1]
      if {$pos1in0<0} { error "::QMtool::write_nbo_input: Didn't find $atom1 in [$sel0 getbonds]!" }
      set bo0 [lindex [join [$sel0 getbondorders]] $pos1in0]
puts "find $atom1 in [$sel0 getbonds] - $pos1in0 - [$sel0 getbondorders]"
      set pos0in1 [lsearch [join [$sel1 getbonds]] $atom0]
      if {$pos0in1<0} { error "::QMtool::write_nbo_input: Didn't find $atom0 in [$sel1 getbonds]!" }
      set bo1 [lindex [join [$sel1 getbondorders]] $pos0in1]
puts "find $atom0 in [$sel1 getbonds] - $pos0in1 - [$sel1 getbondorders]"
      if {$bo0!=$bo1} { 
	 error "::QMtool::write_nbo_input: Bad bondorder $bo0:$bo1!"
      }
      set bo {}
      if {$bo0==1} { 
	 set bo S
      } elseif {$bo0==2} {
	 set bo D
      } elseif {$bo0==3} {
	 set bo T
      } else { incr i; continue }
      puts -nonewline $fid "$bo $atom0 $atom1 "
      incr i
      if {!($i%4)} { puts -nonewline $fid "\n       " }
   }
   puts $fid " END"
   
   # End of alpha
   if {[string index $method 0]=="U"} { puts $fid "  END" }

#    if {[string index $method 0]=="U"} { 
#       variable lewislonepairsbeta
#       puts $fid "  BETA" 

#       # Lone pairs
#       puts -nonewline $fid "  LONE "
#       set index 0
#       foreach lp $lewislonepairsbeta {
# 	 puts -nonewline $fid "$index $lp "
# 	 incr index
#       }
#       puts $fid " END"
      
#       # Bonds (same as for alpha)
#       puts -nonewline $fid "  BOND "
#       set i 0
#       foreach entry $zmat {
# 	 set type [lindex $entry 1]
# 	 if {![string match "*bond" $type]} { continue }
# 	 set t "S"
# 	 switch $type {
# 	    dbond { set t D }
# 	    dbond { set t T }
# 	 }
# 	 set atom0 [lindex [lindex $entry 2] 0]
# 	 set atom1 [lindex [lindex $entry 2] 1]
# 	 puts -nonewline $fid "$t $atom0 $atom1 "
# 	 incr i
# 	 if {!($i%4)} { puts $fid "" }
#       }
#       puts $fid " END"      
#    }

    puts $fid "\$END"
}
