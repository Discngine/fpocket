#
# Analysis routines
#
# $Id: qmtool_analysis.tcl,v 1.10 2006/08/02 22:01:44 johns Exp $
#

################################################
# Plot SCF energies.                           #
################################################

proc ::QMtool::plot_scf_energies { } {
   variable scfenergies
   if {[llength $scfenergies]<=1} {
      if { [winfo exists .qmtool.menu.analysis] } { .qmtool.menu.analysis entryconfigure 0 -state disabled }
      return 
   }

   set x {}
   set i 0
   foreach e $scfenergies {
      lappend x $i
      lappend y [lindex $e 1]
      incr i
   }
   multiplot -x $x -y $y -lines -title "SCF energies (relative to the first value)" \
      -xlabel "frame" -ylabel "E(kcal/mol)" -marker circle -plot
}


########################################################
# Plots the spectrum by replacing each spectral line   #
# with a lorentzian function with a half width at half #
# maximum of $hwhm.                                    #
########################################################

proc ::QMtool::plot_spectrum { {hwhm 2} {npoints 600}} {
   variable lineintensities
   variable linewavenumbers
   variable nimag
   set c 299792458; # lightspeed in m/s
   set pi 3.131592654
   set giga 1000000000.0
   set cutoff 5*$hwhm

   set minwvn [lindex $linewavenumbers 0]
   set maxwvn [lindex $linewavenumbers end]
   set rangewvn [expr $maxwvn-$minwvn]
   #set maxlam [expr 1.0e4/$minwvn]; # in microm
   #set minlam [expr 1.0e4/$maxwvn]; # in micromm
   #set rangelam [expr $maxlam-$minlam]
   puts "rangewvn: $maxwvn - $minwvn = $rangewvn"
   #puts "rangefreq [expr 100.0*$c*$maxwvn/$giga] - [expr 100.0*$c*$minwvn/$giga] = [expr 100.0*$c*$rangewvn/$giga]"
   puts "Computing spectrum..."

   set deltanu [expr $rangewvn/$npoints]
   
   set binnedwvn {}
   foreach wvn $linewavenumbers {
      set pos [expr ($wvn-$minwvn)]
      set n [expr int($pos/$deltanu)]
      set delta [expr $pos-$deltanu*$n]
      if {[expr $delta/$deltanu] >= 0.5} {
 	 lappend binnedwvn [expr $minwvn+($n+1)*$deltanu]; # NewFreq(int(position)+1)
      } else {
 	 lappend binnedwvn [expr $minwvn+($n)*$deltanu];   # NewFreq(int(position))
      }
   }

   set specint {}
   set specfreq {}
   for {set i 1} {$i<=$npoints} {incr i} {
      set intensity 0.0
      set wvn [expr $minwvn+$rangewvn*$i/$npoints]; # in 1/cm

      foreach lineint $lineintensities linefreq $binnedwvn {
	 set offset [expr $wvn-$linefreq]
	 if {$offset<$cutoff} {
	    set intensity [expr $intensity + $lineint * [lorentz [expr $offset/$hwhm]]]
	 }
      }
      lappend specint $intensity
      lappend specwvn $wvn
      #puts "$wvn $freq  $linefreq $intensity"
   }

   set plothandle [multiplot -x $specwvn -y $specint -lines -title "Harmonic spectrum" \
      -xlabel "wavenumber in 1/cm" -ylabel "intensity"]
   $plothandle add $linewavenumbers $lineintensities -nolines -marker circle -plot
}

proc ::QMtool::lorentz { offset } {
   return [expr 1.0 / (1.0 + $offset * $offset)]
}


proc ::QMtool::thermochemistry {} {
   variable selectcolor

   # If already initialized, just turn on
   if { [winfo exists .qmtool_thermo] } {
      wm deiconify .qmtool_thermo
      focus .qmtool_thermo
      return
   }

   set v [toplevel ".qmtool_thermo"]
   wm title $v "Thermochemistry"
   wm resizable $v 0 0

   frame $v.energy

   ############## frame for selected component energies #################
   labelframe $v.energy.comp -bd 2 -relief ridge -text "Energy of selected component" -padx 1m -pady 1m

   label $v.energy.comp.templabel -text "Temperature: "
   entry $v.energy.comp.tempentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::temperature
   grid $v.energy.comp.templabel -row 1 -column 0 -sticky w
   grid $v.energy.comp.tempentry -row 1 -column 1

   label $v.energy.comp.evaclabel -text "E(gas): "
   entry $v.energy.comp.evacentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::Evacuum
   grid $v.energy.comp.evaclabel -row 2 -column 0 -sticky w
   grid $v.energy.comp.evacentry -row 2 -column 1

   label $v.energy.comp.esolvlabel -text "E(solv): "
   entry $v.energy.comp.esolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::Esolv
   grid $v.energy.comp.esolvlabel -row 3 -column 0 -sticky w
   grid $v.energy.comp.esolventry -row 3 -column 1

   label $v.energy.comp.gvaclabel -text "G(gas): "
   entry $v.energy.comp.gvacentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::Gvacuum
   grid $v.energy.comp.gvaclabel -row 4 -column 0 -sticky w
   grid $v.energy.comp.gvacentry -row 4 -column 1

   label $v.energy.comp.gsolvlabel -text "G(solv): "
   entry $v.energy.comp.gsolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::Gsolv
   grid $v.energy.comp.gsolvlabel -row 5 -column 0 -sticky w
   grid $v.energy.comp.gsolventry -row 5 -column 1

   label $v.energy.comp.dgsolvlabel -text "Delta G_solvation: "
   entry $v.energy.comp.dgsolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGsolvation
   grid $v.energy.comp.dgsolvlabel -row 6 -column 0 -sticky w
   grid $v.energy.comp.dgsolventry -row 6 -column 1

   ############## frame for selected component energies #################
   labelframe $v.energy.react -bd 2 -relief ridge -text "Reaction Energies" -padx 1m -pady 1m

   label $v.energy.react.templabel -text "Delta G_solvation(Educts): "
   entry $v.energy.react.tempentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGsolvationE
   grid $v.energy.react.templabel -row 1 -column 0 -sticky w
   grid $v.energy.react.tempentry -row 1 -column 1

   label $v.energy.react.evaclabel -text "Delta G_solvation(Products): "
   entry $v.energy.react.evacentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGsolvationP
   grid $v.energy.react.evaclabel -row 2 -column 0 -sticky w
   grid $v.energy.react.evacentry -row 2 -column 1

   label $v.energy.react.dgsolvlabel -text "Total Delta G_solvation: "
   entry $v.energy.react.dgsolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGsolvationTotal
   grid $v.energy.react.dgsolvlabel -row 3 -column 0 -sticky w
   grid $v.energy.react.dgsolventry -row 3 -column 1

   label $v.energy.react.esolvlabel -text "Delta G_reaction(gas): "
   entry $v.energy.react.esolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGreactionGas
   grid $v.energy.react.esolvlabel -row 4 -column 0 -sticky w
   grid $v.energy.react.esolventry -row 4 -column 1

   label $v.energy.react.gvaclabel -text "Delta G_reaction(solution): "
   entry $v.energy.react.gvacentry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGreactionSol
   grid $v.energy.react.gvaclabel -row 5 -column 0 -sticky w
   grid $v.energy.react.gvacentry -row 5 -column 1

   label $v.energy.react.gsolvlabel -text "Delta G_reaction(cycle): "
   entry $v.energy.react.gsolventry -relief sunken -width 14 -justify right -state readonly \
      -font {tkFixed 9} -textvariable ::QMtool::dGreactionCycle
   grid $v.energy.react.gsolvlabel -row 6 -column 0 -sticky w
   grid $v.energy.react.gsolventry -row 6 -column 1

   pack $v.energy.comp $v.energy.react -side left -padx 1m


   ############## frame for educt file list #################
   labelframe $v.educt -bd 2 -relief ridge -text "Educts" -padx 1m -pady 1m
   frame $v.educt.list
   scrollbar $v.educt.list.scroll -command "$v.educt.list.list yview"
   listbox $v.educt.list.list -activestyle dotbox -yscroll "$v.educt.list.scroll set" \
      -width 60 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::QMtool::eductlist
   frame  $v.educt.list.buttons
   button $v.educt.list.buttons.add -text "Add"    -command { ::QMtool::add_educt }

   button $v.educt.list.buttons.delete -text "Delete" -command {
      foreach i [.qmtool_thermo.educt.list.list curselection] {
	 ::QMtool::molecule_delete [lindex $::QMtool::eductlist $i 0]
	 .qmtool_thermo.educt.list.list delete $i
	 set ::QMtool::thermElist [lreplace $::QMtool::thermElist $i $i] 
      }
      ::QMtool::update_reaction 
   }
   pack $v.educt.list.buttons.add $v.educt.list.buttons.delete -expand 1 -fill x
   pack $v.educt.list.list -side left  -fill x -expand 1
   pack $v.educt.list.scroll $v.educt.list.buttons -side left -fill y -expand 1
   pack $v.educt.list -expand 1 -fill x

   ############## frame for product file list #################
   labelframe $v.product -bd 2 -relief ridge -text "Products" -padx 1m -pady 1m
   frame $v.product.list
   scrollbar $v.product.list.scroll -command "$v.product.list.list yview"
   listbox $v.product.list.list -activestyle dotbox -yscroll "$v.product.list.scroll set" \
      -width 60 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::QMtool::productlist
   frame  $v.product.list.buttons
   button $v.product.list.buttons.add -text "Add"    -command { ::QMtool::add_product  }
   button $v.product.list.buttons.delete -text "Delete" -command {
      foreach i [.qmtool_thermo.product.list.list curselection] {
	 ::QMtool::molecule_delete [lindex $::QMtool::productlist $i 0]
	 .qmtool_thermo.product.list.list delete $i
	 set ::QMtool::thermPlist [lreplace $::QMtool::thermPlist $i $i] 
      }
      ::QMtool::update_reaction 
   }
   pack $v.product.list.buttons.add $v.product.list.buttons.delete -expand 1 -fill x
   pack $v.product.list.list -side left  -fill x -expand 1
   pack $v.product.list.scroll $v.product.list.buttons -side left -fill y -expand 1
   pack $v.product.list -expand 1 -fill x

   pack $v.energy -pady 1m -fill x
   pack $v.educt $v.product -padx 1m -pady 1m -fill x

   bind $v.educt.list.list <<ListboxSelect>> {
      ::QMtool::update_educt
   }

   bind $v.product.list.list <<ListboxSelect>> {
      ::QMtool::update_product
   }
}

proc ::QMtool::add_educt {} {
   ::QMtool::opendialog log
   array set molecules [join $::QMtool::molnamelist]
   variable Evacuum
   variable Esolv
   variable Gvacuum
   variable Gsolv
   variable EGvacuum
   variable EGsolv
   variable dGsolvation
   variable thermElist
   variable eductlist
   lappend thermElist [list $Evacuum $Esolv $Gvacuum $Gsolv $EGvacuum $EGsolv $dGsolvation]
   lappend eductlist [array get molecules $::QMtool::molid]
   update_reaction
}

proc ::QMtool::update_educt {} {
   set i [.qmtool_thermo.educt.list.list curselection]
   variable thermElist
   set E [lindex $thermElist $i]
   variable Evacuum     [lindex $E 0]
   variable Esolv       [lindex $E 1]
   variable Gvacuum     [lindex $E 2]
   variable Gsolv       [lindex $E 3]
   variable EGvacuum    [lindex $E 4]
   variable EGsolv      [lindex $E 5]
   variable dGsolvation [lindex $E 6]
}

proc ::QMtool::add_product {} {
   ::QMtool::opendialog log
   array set molecules [join $::QMtool::molnamelist]
   variable Evacuum
   variable Esolv
   variable Gvacuum
   variable Gsolv
   variable EGvacuum
   variable EGsolv
   variable dGsolvation
   variable thermPlist
   variable productlist
   lappend thermPlist [list $Evacuum $Esolv $Gvacuum $Gsolv $EGvacuum $EGsolv $dGsolvation]
   lappend productlist [array get molecules $::QMtool::molid]
   update_reaction
}

proc ::QMtool::update_product {} {
   set i [.qmtool_thermo.product.list.list curselection]
   variable thermPlist
   set E [lindex $thermPlist $i]
   variable Evacuum     [lindex $E 0]
   variable Esolv       [lindex $E 1]
   variable Gvacuum     [lindex $E 2]
   variable Gsolv       [lindex $E 3]
   variable EGvacuum    [lindex $E 4]
   variable EGsolv      [lindex $E 5]
   variable dGsolvation [lindex $E 6]
}

proc ::QMtool::update_reaction {} {
   set EtotEGvacuum 0.0
   set EtotEGsolv   0.0
   variable dGsolvationE 0.0

   variable thermElist
   foreach E $thermElist {
      #if {[llength $E]} {
	 set EtotEGvacuum    [expr [lindex $E 4]+$EtotEGvacuum]
	 set EtotEGsolv      [expr [lindex $E 5]+$EtotEGsolv  ]
	 set dGsolvationE    [expr [lindex $E 6]+$dGsolvationE]
      #}
   }

   set PtotEGvacuum 0.0
   set PtotEGsolv   0.0
   variable dGsolvationP 0.0

   variable thermPlist
   foreach E $thermPlist {
      #if {[llength $E]} {
	 set PtotEGvacuum    [expr [lindex $E 4]+$PtotEGvacuum]
	 set PtotEGsolv      [expr [lindex $E 5]+$PtotEGsolv  ]
	 set dGsolvationP    [expr [lindex $E 6]+$dGsolvationP]
      #}
   }
   variable dGsolvationTotal [expr -$dGsolvationE+$dGsolvationP]
   variable dGreactionGas    [expr $PtotEGvacuum -$EtotEGvacuum]
   variable dGreactionSol    [expr $PtotEGsolv   -$EtotEGsolv]
   variable dGreactionCycle  [expr $dGsolvationTotal+$dGreactionGas]
   if {[llength $dGsolvationE]}     { set dGsolvationE [format "%14.2f" $dGsolvationE]}
   if {[llength $dGsolvationP]}     { set dGsolvationP [format "%14.2f" $dGsolvationP]}
   if {[llength $dGsolvationTotal]} { set dGsolvationTotal [format "%14.2f" $dGsolvationTotal]}
   if {[llength $dGreactionGas]}    { set dGreactionGas    [format "%14.2f" $dGreactionGas]}
   if {[llength $dGreactionSol]}    { set dGreactionSol    [format "%14.2f" $dGreactionSol]}
   if {[llength $dGreactionCycle]}  { set dGreactionCycle  [format "%14.2f" $dGreactionCycle]}
}

proc ::QMtool::normalmode_gui {} {
   variable normalmodes
   variable lineintensities
   variable linewavenumbers
   variable formatnormalmodes {}
   #array set modelist $normalmodes
   set i 0
   foreach intens $lineintensities wvn $linewavenumbers {
      lappend formatnormalmodes [format "%3i: %8.2f %8.2f" $i $wvn $intens]
      incr i
   }

   variable selectcolor

   # If already initialized, just turn on
   if { [winfo exists .qmtool_nma] } {
      wm deiconify .qmtool_nma
      focus .qmtool_nma
      return
   }

   set v [toplevel ".qmtool_nma"]
   wm title $v "Normal mode analysis"
   wm resizable $v 0 0

   ############## frame for molecule list #################
   labelframe $v.mode -bd 2 -relief ridge -text "Normal modes" -padx 1m -pady 1m
   frame $v.mode.list
   scrollbar $v.mode.list.scroll -command "$v.mode.list.list yview"
   listbox $v.mode.list.list -activestyle dotbox -yscroll "$v.mode.list.scroll set" -font {tkFixed 9} \
      -width 72 -height 15 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::QMtool::formatnormalmodes
   pack $v.mode.list.list $v.mode.list.scroll -side left -fill y -expand 1
   pack $v.mode.list

   frame $v.buttons
   label $v.buttons.label -text "Scaling factor"
   spinbox $v.buttons.spinb -from 0 -to 10 -increment 0.05 -width 5 \
      -textvariable ::QMtool::normalmodescaling -command {
	 set mode [.qmtool_nma.mode.list.list curselection]
	 if {[llength $mode]} {
	    ::QMtool::show_normalmode $mode 0
	 }
      }
   label $v.buttons.label2 -text "Number of animation steps"
   entry $v.buttons.steps -textvariable ::QMtool::normalmodesteps -width 4
   checkbutton $v.buttons.arrows -text "Show arrows" -variable ::QMtool::normalmodearrows
   pack $v.buttons.label $v.buttons.spinb $v.buttons.label2 $v.buttons.steps $v.buttons.arrows -anchor w -side left -padx 1m

   bind $v.buttons.spinb <Return> {
      set mode [.qmtool_nma.mode.list.list curselection]
      if {[llength $mode]} {
	 ::QMtool::show_normalmode $mode nomovie
      }
   }

   pack $v.mode $v.buttons -padx 1m -pady 1m

   # This will be executed when a new molecule is selected:   
   bind $v.mode.list.list <<ListboxSelect>> {
      set mode [%W curselection]
      ::QMtool::show_normalmode $mode
   }


}

proc ::QMtool::show_normalmode { mode {ncycles 1} {movie "nomovie"} {arrows ""}} {
   variable normalmodes
   variable normalmodearrows
   if {![llength $arrows]} { 
      set arrows $normalmodearrows
   } elseif {$arrows!="arrows"} { set arrows 0 }

   draw delete all
   draw color yellow
   variable molid
   variable normalmodescaling
   set sel [atomselect $molid all]
   foreach atommode [lindex $normalmodes $mode] coord [$sel get {x y z}] {
      if {$arrows && [veclength $atommode]>0.2} {
	 ::QMtool::arrow $molid $coord [vecadd $coord [vecscale $atommode $normalmodescaling]] 0.1
      }
   }

   set initialcoords [$sel get {x y z}]
   set deg2rad [expr 3.14159265358979/180.0]
   variable normalmodesteps
   for {set cyc 0} {$cyc<$ncycles} {incr cyc} {
      for {set i 1} {$i<=$normalmodesteps} {incr i} {
	 set angle [expr 360.0*$i/double($normalmodesteps)]
	 set diff [expr $normalmodescaling*sin($deg2rad*$angle)]
	 puts "angle=$angle: $diff"
	 set poslist {}
	 foreach atommode [lindex $normalmodes $mode] coord $initialcoords {
	    lappend poslist [vecadd $coord [vecscale $atommode $diff]]
	 }
	 if {$movie=="movie"} { animate dup $molid }
	 $sel lmoveto $poslist
	 display update
      }
   }
   $sel lmoveto $initialcoords
}


proc ::QMtool::arrow {mol start end {rad 1} {res 6}} {
    # an arrow is made of a cylinder and a cone
    set middle [vecadd $start [vecscale 0.85 [vecsub $end $start]]]
    graphics $mol cone $middle $end radius [expr $rad*2.0] resolution $res
    graphics $mol cylinder $start $middle radius $rad resolution $res
    #puts "$middle $end"
}

