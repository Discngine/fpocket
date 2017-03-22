proc ::Paratool::potential_scan_gui { } {
   variable w
   variable selectcolor
   # If already initialized, just turn on
   if { [winfo exists .paratool_potscan] } {
      set geom [winfo geometry .paratool_potscan]
      wm withdraw  .paratool_potscan
      wm deiconify .paratool_potscan
      wm geometry  .paratool_potscan $geom
      focus .paratool_potscan
      return
   }

   set v [toplevel ".paratool_potscan"]
   wm title $v "Potential scan of selected coordinates"
   wm resizable $v 0 0


   labelframe $v.fofi -text "Force field based scan"
   label $v.fofi.widthlabel -text "Scan width: " 
   entry $v.fofi.widthentry -textvariable ::Paratool::scanwidth -width 6
   grid $v.fofi.widthlabel -row 1 -column 0 -pady 1 -padx 1m
   grid $v.fofi.widthentry -row 1 -column 1 -pady 1 -padx 1m
   label $v.fofi.nstepslabel -text "Number of steps: " 
   entry $v.fofi.nstepsentry -textvariable ::Paratool::scansteps -width 6
   grid $v.fofi.nstepslabel -row 2 -column 0 -pady 1 -padx 1m
   grid $v.fofi.nstepsentry -row 2 -column 1 -pady 1 -padx 1m
   button $v.fofi.scanbutton -text "Potential scan" \
      -command { ::Paratool::fofi_potential_scan -plot }
   grid $v.fofi.scanbutton -row 3 -columnspan 2 -pady 1m
   pack $v.fofi -side top -padx 1m -pady 1m -ipady 1m  -fill x

   labelframe $v.qm -text "QM potential scan"
   label $v.qm.widthlabel -text "Scan width: " 
   entry $v.qm.widthentry -textvariable ::Paratool::qmscanwidth -width 6
   grid $v.qm.widthlabel -row 1 -column 0 -padx 1m
   grid $v.qm.widthentry -row 1 -column 1 -padx 1m
   label $v.qm.nstepslabel -text "Number of steps: " 
   entry $v.qm.nstepsentry -textvariable ::Paratool::qmscansteps -width 6
   grid $v.qm.nstepslabel -row 2 -column 0 -pady 1m
   grid $v.qm.nstepsentry -row 2 -column 1 -pady 1m
   radiobutton $v.qm.scantype1 -text rigid   -variable ::Paratool::qmscantype -value Rigid
   radiobutton $v.qm.scantype2 -text relaxed -variable ::Paratool::qmscantype -value Relaxed
   grid $v.qm.scantype1 -row 3 -column 0 -padx 1m -sticky w
   grid $v.qm.scantype2 -row 4 -column 0 -padx 1m -sticky w
   button $v.qm.scanbutton -text "QM potential scan setup" \
      -command { ::Paratool::setup_qm_potscan }
   grid $v.qm.scanbutton -row 5 -columnspan 2
   button $v.qm.readbutton -text "Read logfile and plot potential" \
      -command { ::Paratool::read_qmpotscan }
   grid $v.qm.readbutton -row 6 -columnspan 2 
   pack $v.qm -side top -padx 1m -pady 1m -ipady 1m -ipadx 1m -fill x

}

proc ::Paratool::fofi_potential_scan { args } {
   set plot 0
   set estimate 0
   set deg2rad [expr 3.14159265358979/180.0]
   set rad2deg [expr 180.0/3.14159265358979]

   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      if {$i=="-plot"}  then {
         set plot 1
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      if {$i=="-estimate"}  then {
         set estimate 1
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      incr argnum
   }

   variable scanwidth
   variable scansteps

   # Scan for options with one argument
   foreach {i j} $arglist {
      if {$i=="-scanwidth"}     then { 
	 scanwidth $j
      }
      if {$i=="-stepsize"}      then { 
	 stepsize $j
      }
   }
   variable molidbase
   variable zmat
   variable zmatqm
   variable selintcoorlist
puts "selintcoorlist=$selintcoorlist"

   if {[llength $selintcoorlist]==0} {
      error "::Paratool::fofi_potential_scan: No coordinate selected!"
   }

   if {[llength $selintcoorlist]>1} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "For potential scans exactly one internal coordinate must be selected!"
      return 
   }

   set izmat [expr {$selintcoorlist+1}]
   set entry [lindex $zmat $izmat]
   #set entryqm [lsearch -inline -regexp $zmatqm ".+\\s{([lindex $entry 2]|[lrevert [lindex $entry 2]])}\\s.+"]
   
   set type  [lindex $entry 1]

puts "entry=$entry"

   write_topology_file  [file rootname $::Paratool::molnamebase]_tmp.top
   write_parameter_file [file rootname $::Paratool::molnamebase]_tmp.par -temporary
   
   write_psfgen_input -file [file rootname $::Paratool::molnamebase].pgn \
		    -top [file rootname $::Paratool::molnamebase]_tmp.top -force -build

   set molid [molinfo top]

   set ilist [lindex $entry 2]

   # Determine correct orientation of the imprp:
   # The first atom must be the center, so we select the first one and
   # check, if all other atoms are in that bondlist.
   if {$type=="imprp"} {
      set sel [atomselect top "index [lindex $ilist 0]"]
      foreach a [lrange $ilist 1 end] {
	 if {[lsearch [$sel getbonds] $a]<=0} {
	    set ilist [lrevert $ilist]
	 }
      }
   }

   # Translate the atom indexes from $molidbase to the new $molid
   set pos(0) {}
   set pos(1) {}
   set pos(2) {}
   set pos(3) {}
   set atom(0) {}; # atom index in $molid
   set atom(1) {}; # atom index in $molid
   set i 0
   foreach index $ilist {
      # Must select atoms one by one to preserve the order!
      set sel  [atomselect $molidbase "index $index"]   
      foreach {segid resid name index} [join [$sel get {segid resid name index}]] {}
      variable ::Paratool::tmsegrestrans
      if {[llength $tmsegrestrans]} {
	 array set sgt $tmsegrestrans
	 set segres "$segid:$resid"
	 set segid [lindex [array get sgt $segres] 1]
      }
      set asel [atomselect $molid "segid $segid and resid $resid and name $name" frame last]
      $asel frame last
      set atom($i) [join [$asel list]]
      set pos($i)  [join [$asel get {x y z}]]
      puts "atom $index->$atom($i): segid $segid and resid $resid and name $name"
      $asel delete
      incr i
   }
   $sel delete

   # Construct selections left and right of the conformation
   if {[string match "*bond" $type]} {
      set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
      set indexes2 [::util::bondedsel $molid $atom(1) $atom(0) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(0)"]      
   } elseif {[regexp "angle|lbend" $type]} {
      set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
      set indexes2 [::util::bondedsel $molid $atom(2) $atom(1) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(1)"]      
      set ureysel  [atomselect $molid "index $atom(0) $atom(2)"]
      $ureysel frame now
   } elseif {$type=="dihed"} {
      set indexes1 [::util::bondedsel $molid $atom(1) $atom(2) -all]
      set indexes2 [::util::bondedsel $molid $atom(2) $atom(1) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(2)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(1)"]      
   } elseif {$type=="imprp"} {
      set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
      set indexes2 [::util::bondedsel $molid $atom(1) $atom(0) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(0)"]      
   } else { error "::Paratool::fofi_potential_scan: Unknown conformation type $type!" }

   $sel1 frame now
   $sel2 frame now
   puts "sel1=[$sel1 list]"
   puts "sel2=[$sel2 list]"
   #puts "atom(0)=$atom(0)"
   #puts "atom(1)=$atom(1)"
   #puts "numfr= [molinfo $molid get numframes]"

   set center [lindex $entry 3]
   set start  [expr {$center-0.5*$scanwidth}]
   set end    [expr {$center+0.5*$scanwidth}]
   set del    [expr {-0.25*$scanwidth}]
   puts "center=$center; del=[expr $center-$start]"

   set stepsize [expr {($end-$start)/double($scansteps)}]
   set harmonicdihedx {}
   set harmonicdihedy {}
   set slist  {}
   set sylist {}
   if {[string match "*bond" $type]} {
      set dir    [vecnorm [vecsub $pos(0) $pos(1)]]

      $sel1 moveby [vecscale $del $dir]
      $sel2 moveby [vecinvert [vecscale $del $dir]]

      set diff [vecscale $dir [expr {0.5*$stepsize}]]

      for {set i 0} {$i<$scansteps} {incr i} {
	 animate dup $molid
	 $sel1 moveby $diff
	 $sel2 moveby [vecinvert $diff]
      }
   } elseif {[regexp "angle|lbend" $type]} {
      set v1 [vecsub $pos(0) $pos(1)]
      set v2 [vecsub $pos(2) $pos(1)]

      set mat [trans angle $pos(2) $pos(1) $pos(0) -$del deg]
      $sel1 move $mat
      set mat [trans angle $pos(2) $pos(1) $pos(0)  $del deg]
      $sel2 move $mat

      set diffmat  [trans angle $pos(2) $pos(1) $pos(0) [expr {-0.5*$stepsize}] deg]
      set diffmatn [trans angle $pos(2) $pos(1) $pos(0) [expr { 0.5*$stepsize}] deg]

      foreach {a1 a3} [$ureysel get {x y z}] {break}
      set slist [veclength [vecsub $a1 $a3]]
      for {set i 1} {$i<=$scansteps} {incr i} {
	 animate dup $molid
	 $sel1 move $diffmat
	 $sel2 move $diffmatn
	 # 1-3 distance for Urey-Bradley term
	 foreach {a1 a3} [$ureysel get {x y z}] {break}
	 lappend slist [veclength [vecsub $a1 $a3]]
      }
      
   } elseif {[regexp  "dihed" $type]} {
      set v1 [vecsub $pos(0) $pos(1)]
      set v2 [vecsub $pos(3) $pos(2)]

      set mat [trans bond $pos(2) $pos(1) -$del deg]
      $sel1 move $mat
      set mat [trans bond $pos(2) $pos(1)  $del deg]
      $sel2 move $mat

      set diffmat  [trans bond $pos(2) $pos(1) [expr { 0.5*$stepsize}] deg]
      set diffmatn [trans bond $pos(2) $pos(1) [expr {-0.5*$stepsize}] deg]
      for {set i 1} {$i<=$scansteps} {incr i} {
	 animate dup $molid
	 $sel1 move $diffmatn
	 $sel2 move $diffmat
      }
      
   } elseif {[regexp  "imprp" $type]} {
      set v1 [vecsub $pos(0) $pos(1)]
      set v2 [vecsub $pos(3) $pos(2)]
      set cb [vecsub $pos(1) $pos(2)]
      set cd [vecsub $pos(3) $pos(2)]
      set ab [vecsub $pos(1) $pos(0)]
      set s  [veccross $cb $cd]
      set r  [veccross $ab $s]

      set mat [trans bond [vecadd $pos(0) $r] $pos(0) -$del deg]
      $sel1 move $mat
      set mat [trans bond [vecadd $pos(0) $r] $pos(0)  $del deg]
      $sel2 move $mat

      set diffmat  [trans bond [vecadd $pos(0) $r] $pos(0) [expr { 0.5*$stepsize}] deg]
      set diffmatn [trans bond [vecadd $pos(0) $r] $pos(0) [expr {-0.5*$stepsize}] deg]
      for {set i 1} {$i<=$scansteps} {incr i} {
	 animate dup $molid
	 $sel1 move $diffmatn
	 $sel2 move $diffmat
      }
      
   } else { return }

   animate write dcd scan.dcd  waitfor all $molid
#   animate delete beg 0 end 0

   # Compute the energies using NAMDenergy plugin
   set energies [run_namdenergy $molid -tmppar [file rootname $::Paratool::molnamebase]_tmp.par]

   # Compute the ideal target potential
   variable Refinement::targetx0list
   variable Refinement::targetklist
   set tx0 [lindex $targetx0list $selintcoorlist]
   set tk  [lindex $targetklist  $selintcoorlist]
   puts "TK=$tk; TX0=$tx0"
   set xlist [generate_scan_xlist $type $center $scanwidth $scansteps]
   set tylist {}
   if {[llength $tx0] && [llength $tk]} {
      if {$type=="dihed"} {
	 foreach {K n delta} [lindex $entry 4] {break}
	 set k     [expr {$K*$n*$n*0.5}]; # force constant for harmonic potential
	 set angle0 [lindex $entry 3]
	 set tylist  [generate_periodic_potential $K $n $delta $angle0 $xlist]
	 set hylist [generate_harmonic_potential $type $tk $tx0 $xlist]
	 # Get the largest value of tylist
	 set ymax [lindex [lsort -real $tylist] end]
	 foreach x $xlist hy $hylist {
	    if {$hy<=$ymax} {
	       lappend harmonicdihedx [rad2deg $x]
	       lappend harmonicdihedy $hy
	    }
	 }
      } else {
	 set tylist [generate_harmonic_potential $type $tk $tx0 $xlist]
      }
   }
    
   # Compute the Urey-Bradley potential 
   foreach {k x0 kub s0} [lindex $entry 4] {break}
puts "k=$k x0=$x0"
   if {$type=="angle" && [llength $kub] && [llength $s0]} {
      set sylist [generate_harmonic_potential bond $kub $s0 $slist]
      #set tylist  [generate_harmonic_potential angle $k  $x0 $xlist]
   }


   # Compute the estimated effective parameters from derivatives of total energy:
   #if {$estimate} {
   #   foreach {d1 effx0 effk} [get_second_derivatives $selintcoorlist -rebuild]
      
   #}

   if {$plot} {
      set plothandle [plot_potential_scan $xlist $tylist $izmat $energies]
      $plothandle configure -vline [list $center -dash .]
      if {$type=="dihed" && [llength $harmonicdihedx]} {
	 #if {![llength $harmonicdihedx]} { error "harmonicdihedx = {}" }
	 $plothandle add $harmonicdihedx $harmonicdihedy -lines -linecolor yellow -linewidth 4 \
	    -legend "local harmonic dihedral approximation" -xanglescale
      } elseif {$type=="angle" && [llength $sylist]} {
	 $plothandle add [vecscale $rad2deg $xlist] $sylist -lines -linecolor cyan -linewidth 2 \
	    -legend "Urey-Bradley"
      }
      $plothandle replot
   }
   return [list $xlist $tylist $izmat $energies $plothandle]
}


proc ::Paratool::generate_scan_xlist {type center scanwidth scansteps} {
   set deg2rad 1.0
   if {[regexp "angle|lbend|imprp|dihed" $type]} {
      set deg2rad 0.0174532925199; #[expr 3.14159265358979/180.0]
   }
   set start    [expr {$center-0.5*$scanwidth}]
   set stepsize [expr {$scanwidth/double($scansteps)}]
   set xlist {}
   for {set i 0} {$i<=$scansteps} {incr i} {
      lappend xlist [expr {$deg2rad*($start+$i*$stepsize)}]
   }
   return $xlist
}

proc ::Paratool::generate_scan_xlist_deg {type center scanwidth scansteps} {
   set start    [expr {$center-0.5*$scanwidth}]
   set stepsize [expr {$scanwidth/double($scansteps)}]
   set xlist {}
   for {set i 0} {$i<=$scansteps} {incr i} {
      lappend xlist [expr {$start+$i*$stepsize}]
   }
   return $xlist
}

proc ::Paratool::generate_harmonic_potential {type k x0 xlist} {
   set deg2rad 1.0
   if {[regexp "angle|lbend|imprp|dihed" $type]} {
      set deg2rad 0.0174532925199; #[expr 3.14159265358979/180.0]
   }
   set x0 [expr {$deg2rad*$x0}]
   set ylist {}
   foreach x $xlist {
      lappend ylist [expr {$k*pow(($x-$x0), 2)}]
      #puts "$x [expr {$k*pow(($x-$x0), 2)}]"
   }

   return $ylist
}

proc ::Paratool::generate_harmonic_potential_deg {type k x0 xdeg} {
   set deg2rad 1.0
   if {[regexp "angle|lbend|imprp|dihed" $type]} {
      set deg2rad 0.0174532925199; #[expr 3.14159265358979/180.0]
   }

   set ylist {}
   foreach x $xdeg {
      lappend ylist [expr {$k*pow($deg2rad*($x-$x0), 2)}]
      #puts "$x [expr {$k*pow($deg2rad*($x-$x0), 2)}]"
   }

   return $ylist
}

proc ::Paratool::generate_ureybradley_potential {xdeg kub s0 la lb} {
   set ylist {}
   foreach x $xdeg {
      lappend ylist [::Paratool::Energy::compute_ureybradley_x $x $kub $s0 $la $lb]
   }
   return $ylist
}

proc ::Paratool::generate_lennardjones_potential {xlist Rmin eps} {
   set ylist {}
   foreach x $xlist {
      set term6 [expr {pow($Rmin/$x,6)}]
      lappend ylist [expr {$eps*($term6*$term6 - 2.0*$term6)}]
   }
   return $ylist
}

# Angles in $xlist must be provided in rad.
proc ::Paratool::generate_periodic_potential {K n delta angle0 xlist} {
   set deg2rad 0.0174532925199; #[expr 3.14159265358979/180.0]
   set delta  [expr $deg2rad*$delta]
   set angle0 [expr $deg2rad*$angle0]

   set ylist {}
   foreach angle $xlist {
      lappend ylist [expr {$K*(1+cos($n*($angle-$angle0)-$delta))}]
   }

   return $ylist
}

proc ::Paratool::run_namdenergy { molid args } {
   variable paramsetfiles
#   variable newparamfile
#   if {![llength $newparamfile]} {
#      tk_messageBox -icon error -type ok -title Message \
\#	 -message "You must first write the new parameter file!"
#      return 0
#   }
   set pos [lsearch $args "-tmppar"]
   if {$pos>=0} { set tmpparamfile [lindex $args [expr {$pos+1}]] }
   set all [atomselect $molid all]

   set params ""
   foreach parfile $paramsetfiles {
      append params " -par $parfile"
   }
   return [eval namdenergy -sel $all -all $params -par $tmpparamfile -ofile paratool_scan.out -debug]
}


proc ::Paratool::plot_potential_scan { xlist ytarget izmat energies } {
   variable zmat
   variable zmatqm
   set entry [lindex $zmat $izmat]
   set type  [lindex $entry 1]
   
   set conf   {}
   set elec   {}
   set vdw    {}
   set bonded {}
   set nonb   {}
   set total  {}
   #set diff  {}
   foreach energy $energies yt $ytarget {
      if {$type=="bond"} {
	 lappend conf  [lindex $energy 2]
      } elseif {[regexp "angle|lbend" $type]} {
	 lappend conf [lindex $energy 3]
      } elseif {$type=="dihed"} {
	 lappend conf [lindex $energy 4]
      } elseif {$type=="imprp"} {
	 lappend conf [lindex $energy 5]
      }
      lappend elec   [lindex $energy 6]
      lappend vdw    [lindex $energy 7]
      lappend bonded [lindex $energy 8]
      lappend nonb   [lindex $energy 9]
      lappend total  [lindex $energy 10]
      #lappend diff  [expr $yt-[lindex $energy 9]]
   }

   set xdeg $xlist
   set xlabel "bond distance (A)"
   if {[regexp "angle|lbend|dihed|imprp" $type]} {
      set xdeg {}
      foreach coor $xlist {
	 lappend xdeg [rad2deg $coor]
      }
      set xlabel "angle (deg)"
   }

   if {[regexp "angle" $type]} {
      # Compute the Urey-Bradley potential 
      foreach {k x0 kub s0} [lindex $entry 4] {break}
      puts "k=$k x0=$x0"
      if {$type=="angle" && [llength $kub] && [llength $s0]} {
	 #set sylist [generate_harmonic_potential bond $kub $s0 $slist]
      }
      set ylist  [generate_harmonic_potential angle $k  $x0 $xlist]
      set conf $ylist

   }

   # Shift elec to zero
   set izero [expr {[llength $xdeg]/2}]
   set newconf   [shift_data $conf  -miny 0.0]
   set newelec   [shift_data $elec  -izero $izero]
   set newvdw    [shift_data $vdw   -izero $izero]
   set newbonded [shift_data $bonded -miny 0.0]
   set newnonb   [shift_data $nonb  -izero $izero]
   set newtotal  [shift_data $total -miny 0.0]
   #set newdiff  [shift_data $diff  -izero $izero]
   set plothandle [multiplot -title "Potential scan $type [lindex $entry 0]" -ysize 400 -xsize 600]
   $plothandle configure -xlabel $xlabel -ylabel "E (Kcal/mol)" 
   if {[llength $ytarget]} {
      variable Refinement::targetx0list
      variable Refinement::targetklist
      set tx0 [lindex $targetx0list [expr {$izmat-1}]]
      set tk  [lindex $targetklist  [expr {$izmat-1}]]
      $plothandle add $xdeg $ytarget -lines -linecolor red    -linewidth 4 \
	 -legend "target potential k=$tk x0=$tx0"
   }
   $plothandle add $xdeg $newnonb   -lines -linecolor magenta -linewidth 2 -legend "nonbonded"
   $plothandle add $xdeg $newbonded -lines -linecolor yellow  -linewidth 2 -legend "bonded"
   $plothandle add $xdeg $newconf   -lines -linecolor green   -linewidth 2 -legend "$type"
   $plothandle add $xdeg $newtotal  -lines -linecolor blue    -linewidth 2 -legend "total"

   return $plothandle
}


proc ::Paratool::shift_data { data args } {
   set offset 0.0
   set min 0.0
   set pos [lsearch $args "-izero"]
   if {$pos>=0 && $pos<[llength $args]-1} {
      set izero [lindex $args [expr {$pos+1}]]
      set min [lindex $data $izero]
   }
   set pos [lsearch $args "-miny"]
   if {$pos>=0 && $pos<[llength $args]-1} {
      set offset [lindex $args [expr {$pos+1}]]
      set min [lindex [lsort -real $data] 0]
   }

   set newdata {}
   foreach val $data {
      lappend newdata [expr {$val-$min+$offset}]
   }
   return $newdata
}

proc ::Paratool::read_qmpotscan {} {
   opendialog potscan

   # Compare with the ideal potential:
   variable qmscanentry
   variable zmat
   variable zmatqm
   set entry [lsearch -inline  -regexp $zmat "{($qmscanentry|[lrevert $qmscanentry])}"]
   set confname [lindex $entry 0]
   set entryqm [lsearch -inline  -regexp $zmatqm "{($qmscanentry|[lrevert $qmscanentry])}"]
   puts "Scanned {$qmscanentry|[lrevert $qmscanentry]}: $entry"

   variable qmscansteps
   variable qmscanwidth
   set stepsize [expr {$qmscanwidth/double($qmscansteps)}]
   set type   [lindex $entryqm 1]
   set center [lindex $entryqm 3]
   set start  [expr {$center-0.5*$qmscanwidth}]
   set end    [expr {$center+0.5*$qmscanwidth}]
   puts "center=$center; del=[expr $center-$start]"
   set nsteps 100
   set k  [lindex $entry 4 0]
   set x0 [lindex $entry 4 1]

   set xlist [generate_scan_xlist_deg $type $center $qmscanwidth $nsteps]
   set ylist [generate_harmonic_potential_deg $type $k $x0 $xlist]

   # Get the scanned potential
   variable scanenergies 

   set xdata {}
   set i 0
   foreach e $scanenergies {
      lappend xdata [expr {$center-0.5*$qmscanwidth+$i*$stepsize}]
      lappend ydata [lindex $e 1]
      incr i
   }
   set ydata [shift_data $ydata -miny 0.0 ]

   set xlabel "bond distance (A)"
   if {[regexp "angle|lbend|dihed|imprp" $type]} {
      set xlabel "angle (deg)"
   }

   variable qmscantype
   set plothandle [multiplot -title "$qmscantype potential scan for $confname [lrange $entryqm 1 2]"]
   $plothandle configure -ysize 400 -xsize 600 -vline [list $center -dash .]
   $plothandle configure -xlabel $xlabel -ylabel "E (Kcal/mol)" 
   $plothandle add $xlist $ylist -lines -linecolor red -linewidth 4 \
      -legend "force field based potential: k=$k, x0=$x0"

   $plothandle add $xdata $ydata -legend "QM scan potential" -marker circle -radius 4 -fillcolor orange


   # Fit harmonic potential to QM scan 
   set min [format "%.4f" [lindex [lsort -real $xdata] 0]]
   set max [format "%.4f" [lindex [lsort -real $xdata] end]]
   set range [expr $max-$min]
   set maxdist [expr abs($max-$x0)]
   set fid [open paratool_fit.dat w]
   foreach X $xdata Y $ydata {
      set dist [expr abs($X-$x0)]
      set weight 1.0
      if {$dist>[expr $range/32.0]} {
	 # Introduce a strong bias on the weights for the center
	 # This makes us less dependent on nonlinear contributions
	 # which play a bigger role the further we are from the center.
	 set weight [expr 1+8.0*($dist-$range/32.0)/$maxdist]
      }
      puts $fid [format "%10f %10f %10f" $X $Y $weight]
   }
   close $fid

   set min [format "%.4f" [lindex [lsort -real $xdata] 0]]
   set max [format "%.4f" [lindex [lsort -real $xdata] end]]
   set newparams [::Paratool::Refinement::fit_harmonic_potential paratool_fit.dat [lindex $entryqm 4 0] [lindex $entryqm 4 1] $min $max $type]

   set x0 [format "%.4f" [lindex $newparams 1]]
   set k  [format "%.4f" [lindex $newparams 0]]

   set ylist [generate_harmonic_potential_deg $type $k $x0 $xlist]

   $plothandle add $xlist $ylist -lines -linecolor orange -linewidth 2 -legend "fitted potential: k=$k, x0=$x0"
   puts "Fitted scan: k=$k; x0=$x0"
   $plothandle replot
}


