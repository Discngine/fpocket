# Procedure to retrieve force field energies and derivatives
# ----------------------------------------------------------

# This is somewhat sophisticated since it's optimized for speed.
# Our goal is to get potential energies for the molecule computed by NAMD
# We are using the NAMDserver plugin to calculate these energies.
# This is easy an efficient when only the coordinates change since these
# can be sent without restarting NAMD. The problem is that sometimes,
# e.g. in refinement, we have to frequently reevaluate energies for the 
# same structure but with different parameters. Sending "reloadCharges"
# updates the charges on the fly but a similar approach is not available
# for VDW interactions and bobded parameters. Since bonded energies for
# selected internal coordinates are fast and easy to compute even in TCL,
# we will compute the total energy once, subtract the contribution of
# the selected internal coordinates and cache these energies.
# If the bonded parameters of the selected internal coordinates are 
# changed we only have to recompute the respective bonded contribution.
# The same is done for the energy triples used for the calculation of
# derivatives.


namespace eval ::Paratool::Energy {
   proc initialize {} {
      variable energy  {}; # Current computed energy list
      variable etitle  {}; # List of labels for the currently computed energies
      variable selsteric 0.0
      variable selgeomlist  {}
      variable selparamlist {}
      variable oldintcoorlist {}; # Selected internal coords of previous run.
      variable hbond  0.02;  #
      variable hangle 5.0; #0.2
      variable hdihed 5.0; #2.0
      variable himprp 0.2
      variable Estericnosel {}; # steric energy w/o contribution from selected intcoor
      variable atomtrans; # array translating atom indexes of $molidbase into $molid
      variable postrans;  # array of atom positions in $molid by $molidbase indexes
      variable molid -1
      variable namdserver 0;   # socket for the NAMD communication
      variable onefourlist  {}
      variable onefourinter {}
      variable excluded13   {}
   }
   initialize
}

proc ::Paratool::Energy::parabolic_extrapolation {a b c fa fb fc} {
   set r [expr {($b-$a)*($fb-$fc)}];
   set q [expr {($b-$c)*($fb-$fa)}];
   set p [expr {($b-$c)*$q-($b-$a)*$r}];
   set q [expr {2.0*($q-$r)}];

   if {abs($q)<1e-16} { 
      puts "WARNING: parabolic_extrapolation: The 3 test points are collinear! (denom=$q)"
      puts "a=$a b=$b c=$c; fa=$fa fb=$fb fc=$fc;"
      return $b
   }
   return [expr {$b - $p/$q}]
}

proc ::Paratool::Energy::make_distortion {molid type arrpos arratom args} {
   variable ::Paratool::molidbase
   array set pos  $arrpos
   array set atom $arratom
   array set base $arratom

   set dx {}
   set i [lsearch $args "-dx"]
   if {$i>=0 && $i<[llength $args]-1} {
      set dx [lindex $args [expr {$i+1}]]
   }
   set i [lsearch $args "-basemolindexes"]
   if {$i>=0 && $i<[llength $args]-1} {
      set i 0
      foreach ind [lindex $args [expr {$i+1}]] {
	 set base($i) $ind
	 incr i
      }
   }

   variable atomtrans
   variable postrans
   # Construct selections left and right of the conformation
   if {[string match "*bond" $type]} {
      # FIXME: I'm just using the first ring in case the bond belongs to 2 rings.
      set inring [lindex [::Paratool::bond_in_ring $base(0) $base(1)] 0]
      if {[llength $inring]} {
	 variable ::Paratool::ringlist
	 puts "BOND $base(0)--$base(1) IN RING $inring: [lindex $ringlist $inring]"
	 set vis {}; # will contain the two ring neighbors of atom(0)
	 set sel [atomselect $molidbase "index $base(0)"]
	 foreach nb [join [$sel getbonds]] {
	    if {[lsearch [lindex $ringlist $inring] $nb]>=0} {
	       # This neighbor of atom(0) is part of the ring
	       lappend vis $atomtrans($nb)
	       if {$nb!=$base(1)} { set base(-1) $nb }
	    }
	 }
	 $sel delete
	 set atom(-1) [::util::ldiff $vis $atom(1)]
	 #puts "base(-1)=$base(-1); atom(-1)=$atom(-1)"
	 set base(-2) [lindex [::util::reorder_ring [lindex $ringlist $inring] $base(0) $base(-1)] 2]
	 #puts "base(-2)=$base(-2); [lindex $ringlist $inring] $base(0) $base(-1)"
	 set atom(-2) $atomtrans($base(-2))
	 #puts "base(-2)=$base(-2); atom(-2)=$atom(-2)"
	 set pos(-1)  $postrans($base(-1))
	 set pos(-2)  $postrans($base(-2))
	 set indexes1 [::util::ldiff [::util::bondedsel $molid $atom(0) $vis -all] $vis]
	 #puts "$atom(0): vis=$vis, [::Paratool::bondedsel $molid $atom(0) $vis] indexes1=$indexes1"
	 set vis {}
	 set sel [atomselect $molidbase "index $base(1)"]
	 foreach nb [join [$sel getbonds]] {
	    if {[lsearch [lindex $ringlist $inring] $nb]>=0} {
	       lappend vis $atomtrans($nb)
	       if {$nb!=$base(0)} { set base(2) $nb }
	    }
	 }
	 #puts "vis=$vis base(0)=$base(0) nb of (1): [$sel getbonds]"
	 $sel delete
	 set atom(2) [::util::ldiff $vis $atom(0)]
	 #puts "base(2)=$base(2); atom(2)=$atom(2)"
	 set base(3) [lindex [::util::reorder_ring [lindex $ringlist $inring] $base(1) $base(2)] 2]
	 set atom(3) $atomtrans($base(3))
	 #puts "base(3)=$base(3); atom(3)=$atom(3)"
	 set pos(2)  $postrans($base(2))
	 set pos(3)  $postrans($base(3))
	 set indexes2 [::util::ldiff [::util::bondedsel $molid $atom(1) $vis -all] $vis]
	 set type bondring
	 #puts "$atom(1): vis=$vis, [::Paratool::bondedsel $molid $atom(1) $vis] indexes2=$indexes2"
      } else {
	 set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
	 set indexes2 [::util::bondedsel $molid $atom(1) $atom(0) -all]
      }
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(0)"]      
      variable hbond  
      set del [expr {$hbond/2.0}]
   } elseif {[regexp "angle|lbend" $type]} {
      set inring [::Paratool::angle_in_ring $base(0) $base(1) $base(2)]
      if {[llength $inring]} {
	 puts "ANGLE $base(0)--$base(1)--$base(2) IN RING"
	 set vis [list $atom(0) $atom(2)]
	 set indexes2 [::util::ldiff [::util::bondedsel $molid $atom(1) $vis -all] $vis]
	 #puts "$atom(1): vis=$vis, [::Paratool::bondedsel $molid $atom(1) $vis] indexes2=$indexes2"
	 set sel2 [atomselect $molid "index $indexes2 $atom(1)"]
	 set sel1 [atomselect $molid "(not index $indexes2)"]
	 set indexes1 [$sel1 list]
	 set type anglering
      } else {
	 set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
	 set indexes2 [::util::bondedsel $molid $atom(2) $atom(1) -all]
	 set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
	 set sel2 [atomselect $molid "index $indexes2 and not index $atom(1)"]      
      }
      variable hangle 
      set del [expr {$hangle/2.0}]
   } elseif {$type=="dihed"} {
      set indexes1 [::util::bondedsel $molid $atom(1) $atom(2) -all]
      set indexes2 [::util::bondedsel $molid $atom(2) $atom(1) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(2)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(1)"]      
      variable hdihed 
      set del [expr {$hdihed/2.0}]
   } elseif {$type=="imprp"} {
      set indexes1 [::util::bondedsel $molid $atom(0) $atom(1) -all]
      set indexes2 [::util::bondedsel $molid $atom(1) $atom(0) -all]
      set sel1 [atomselect $molid "index $indexes1 and not index $atom(1)"]
      set sel2 [atomselect $molid "index $indexes2 and not index $atom(0)"]      
      variable himprp 
      set del [expr {$himprp/2.0}]
   } else { error "::Paratool::fofi_potential_scan: Unknown conformation type $type!" }
   
   # Optional user defined delta
   if {[llength $dx]} {
      set del [expr {$dx/2.0}]
   }

   set numframes [molinfo $molid get numframes]
   set last [expr {$numframes-1}]

   # Generate 2 new frames for f(x+h) and f(x-h)
   mol top $molid
   animate goto end;
   animate dup $molid
   animate dup $molid
   $sel1 frame [expr {$last+1}];
   $sel2 frame [expr {$last+1}];

   if {[string match "*bond" $type]} {
      # FIXME: Should have a bondring type in which we correct for the change of 
      # neighboring bonds
      set bondvec [vecsub $pos(0) $pos(1)]
      set dir     [vecnorm $bondvec]

      $sel1 moveby [vecinvert [vecscale $del $dir]]
      $sel2 moveby [vecscale $del $dir]

      set del [expr {-$del}]
      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      $sel1 moveby [vecinvert [vecscale $del $dir]]
      $sel2 moveby [vecscale $del $dir]

      set x       [veclength $bondvec]
   } elseif {[regexp "bondring" $type]} {
      set bondvec [vecsub $pos(0) $pos(1)]
      set dir     [vecnorm $bondvec]
      #set bondvec1 [vecsub $pos(-1) $pos(0)]
      #set bondvec2 [vecsub $pos(2) $pos(1)]
      #set c1 [veclength $bondvec1]
      #set c2 [veclength $bondvec2]
      #set a1 [::Paratool::vecangle3 $pos(-2) $pos(-1) $pos(0)]
      #set a2 [::Paratool::vecangle3 $pos(3)  $pos(2)  $pos(1)]
      #set sel [atomselect $molid "index $atom(-1)"]
      #set pos(-1) [join [$sel get {x y z}]]
      #set h1 [expr {$a1-acos(($del-$c1*cos($a1))/$c1)}]
      #set h2 [expr {$a2-acos(($del-$c2*cos($a2))/$c2)}]
      set h 5.0
      set mat [trans angle $pos(-2) $pos(-1) $pos(0)  $h deg]
      $sel1 move $mat
      set mat [trans angle $pos(3)  $pos(2)  $pos(1)  $h deg]
      $sel2 move $mat

      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      set mat [trans angle $pos(-2) $pos(-1) $pos(0) -$h deg]
      $sel1 move $mat
      set mat [trans angle $pos(3)  $pos(2)  $pos(1) -$h deg]
      $sel2 move $mat

      set xupper [measure bond [list $atom(0) $atom(1)] molid $molid frame [expr {$last+2}]]
      set x  [veclength $bondvec]
      set del [expr {($xupper-$x)/2.0}]
   } elseif {[regexp "anglering" $type]} {
      #set x  [measure angle [list $atom(0) $atom(1) $atom(2)] molid $molid]
      set x  [::Paratool::angle_from_coords $pos(0) $pos(1) $pos(2)]

      set deg2rad 0.0174532925199;
      set c1 [veclength [vecsub $pos(0) $pos(1)]]
      set c2 [veclength [vecsub $pos(2) $pos(1)]]
      set h [expr {0.5*$c1*$c2*(cos((0.5*$x+$del)*$deg2rad)-cos((0.5*$x)*$deg2rad))}]
      set dir [vecnorm [vecadd [vecnorm [vecsub $pos(0) $pos(1)]] [vecnorm [vecsub $pos(2) $pos(1)]]]]
      $sel1 moveby [vecinvert [vecscale $h $dir]]
      $sel2 moveby [vecscale $h $dir]

      set h [expr {-$h}]
      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      $sel1 moveby [vecinvert [vecscale $h $dir]]
      $sel2 moveby [vecscale $h $dir]
   } elseif {[regexp "angle|lbend" $type]} {
      set mat [trans angle $pos(2) $pos(1) $pos(0)  $del deg]
      $sel1 move $mat
      set mat [trans angle $pos(2) $pos(1) $pos(0) -$del deg]
      $sel2 move $mat

      set del [expr {-$del}]

      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      set mat [trans angle $pos(2) $pos(1) $pos(0)  $del deg]
      $sel1 move $mat
      set mat [trans angle $pos(2) $pos(1) $pos(0) -$del deg]
      $sel2 move $mat

      #set x  [measure angle [list $atom(0) $atom(1) $atom(2)] molid $molid]
      set x  [::Paratool::angle_from_coords $pos(0) $pos(1) $pos(2)]
   } elseif {[regexp  "dihed" $type]} {
      # FIXME: Should check how diheds behave in rings!
      set mat [trans bond $pos(2) $pos(1) -$del deg]
      $sel1 move $mat
      set mat [trans bond $pos(2) $pos(1)  $del deg]
      $sel2 move $mat

      #set del [expr {-$del}]
      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      set mat [trans bond $pos(2) $pos(1)  $del deg]
      $sel1 move $mat
      set mat [trans bond $pos(2) $pos(1) -$del deg]
      $sel2 move $mat

      #set x [measure dihed [list $atom(0) $atom(1) $atom(2) $atom(3)] molid $molid]
      set x [::Paratool::dihed_from_coords $pos(0) $pos(1) $pos(2) $pos(3)]
   } elseif {[regexp  "imprp" $type]} {
      set cb [vecsub $pos(1) $pos(2)]
      set cd [vecsub $pos(3) $pos(2)]
      set ab [vecsub $pos(1) $pos(0)]
      set s  [veccross $cb $cd]
      set r  [veccross $ab $s]
      set mat [trans bond [vecadd $pos(0) $r] $pos(0) -$del deg]
      $sel1 move $mat
      set mat [trans bond [vecadd $pos(0) $r] $pos(0)  $del deg]
      $sel2 move $mat

      set del [expr {-$del}]
      $sel1 frame [expr {$last+2}]
      $sel2 frame [expr {$last+2}]
      set mat [trans bond [vecadd $pos(0) $r] $pos(0) -$del deg]
      $sel1 move $mat
      set mat [trans bond [vecadd $pos(0) $r] $pos(0)  $del deg]
      $sel2 move $mat

      #set x [measure imprp [list $atom(0) $atom(1) $atom(2) $atom(3)] molid $molid]
      set x [::Paratool::dihed_from_coords $pos(0) $pos(1) $pos(2) $pos(3)]
   } else { return }

   return [list $x [expr {abs($del*2.0)}]]
}


################################################################
# Compute the first and second derivative of the potential     #
# energy for all selected internal coordinates based on thee   #
# points: E(x-h), E(x) and E(x+h).                             #
# If namdserver is not running it will be started and the      #
# energies are computed directly from NAMD. If namdserver is   #
# already running then we only recompute the selected bonded   #
# energies using TCL.                                          #
# Further, an estimate (by parabolic extrapolation) of the     #
# effective potential energy minimum is returned.              #
################################################################

proc ::Paratool::Energy::compute_derivatives { intcoorlist args } {
   set rebuild 1
   set rebuildflag "-rebuild"
   set plot 0
   if {[lsearch $args "-norebuild"]>=0} {
      set rebuild 0
      set rebuildflag "-norebuild"
   }
   if {[lsearch $args "-plot"]>=0} {
      set plot 1
   }

   variable ::Paratool::molidbase
   variable molid 
   variable namdserver
   variable atomtrans
   variable postrans
   variable oldintcoorlist
   # If NAMDserver already exists, we can use the cheaper method
   # just updating the bonded energies using TCL. Otherwise we would have to
   # write and reload a new parameter file.
   #if {$namdserver!=0 && [lsort -integer $intcoorlist]==$oldintcoorlist} {
   #   return [update_selected_derivatives $intcoorlist]
   #}

   set oldintcoorlist [lsort -integer $intcoorlist]

   if {$namdserver==0} {
      # Ok, since NAMDserver is apparently not running, we'll start it.
      # But first we must get rid of the old molecule:
      if {$molid>=0 && $rebuild} {
	 mol delete $molid
	 variable molid -1
      }
      set sel [atomselect $molidbase all]
      start_namdserver $sel -all $rebuildflag

      # We must work with the newly build molecule
      variable molid [molinfo top]

      foreach t [trace info variable ::Paratool::zmat] {
	 trace remove variable ::Paratool::zmat write ::Paratool::Energy::stop_namdserver
      }
      # Set a trace on zmat to monitor changes in parameters
      trace add variable ::Paratool::zmat write ::Paratool::Energy::stop_namdserver

      # Translate the atom indexes from $molidbase to the new $molid
      if {$rebuild} {
	 array unset atomtrans
	 array unset postrans
	 set all  [atomselect $molidbase all]
	 foreach atomspec [$all get {segid resid name index}] {
	    foreach {segid resid name index} $atomspec {}
	    variable ::Paratool::tmsegrestrans
	    if {[llength $tmsegrestrans]} {
	       array set sgt $tmsegrestrans
	       set segres "$segid:$resid"
	       set segid [lindex [array get sgt $segres] 1]
	    }
	    set asel [atomselect $molid "segid $segid and resid $resid and name $name"]
	    set atomtrans($index) [join [$asel list]]
	    set postrans($index)  [join [$asel get {x y z}]]
	    puts "atom $index->$atomtrans($index): segid $segid and resid $resid and name $name"
	    $asel delete
	 }
	 $all delete
      }
   }


   set deg2rad 0.0174532925199; # [expr 3.14159265358979/180.0]
   set rad2deg 57.2957795131;   # [expr 180.0/3.14159265358979]

   variable selgeomlist {}
   variable selparamlist {}
   variable Estericnosel {}
   set deriv1 {}
   variable ::Paratool::Refinement::effklist  
   variable ::Paratool::Refinement::effx0list 
   variable ::Paratool::Refinement::targetklist  
   variable ::Paratool::Refinement::targetx0list 
   variable ::Paratool::Refinement::dklist  
   variable ::Paratool::Refinement::dx0list 
   set seleffklist  {}
   set seleffx0list {}
   set x0list {}
   set klist  {}
   set dcdfile namdserver-tmp.dcd

   variable ::Paratool::zmat
   foreach intcoor $intcoorlist {
      set izmat [expr {$intcoor+1}]
      set entry [lindex $zmat $izmat]
      set tag  [lindex $entry 0]
      set type [lindex $entry 1]

      #set x0 [lindex $entry 3]

      # Set atom indexes and coordinates
      set i 0
      variable atomtrans
      variable postrans
      foreach index [lindex $entry 2] {
 	 set pos($i)  $postrans($index)
 	 set atom($i) $atomtrans($index)
 	 incr i
      }
      
      foreach {x h} [make_distortion $molid $type [array get pos] [array get atom] -basemolindexes [lindex $entry 2]] {}

#       if {[string match "*bond" $type]} {
# 	 lappend selgeomlist $x
# 	 foreach {k x0} [lindex $entry 4] {break}
# 	 lappend selparamlist [list $tag [list $k $x0]]
# 	 set Esteric0 [compute_bond  [expr {$x-$h}] $k $x0]
# 	 set Esteric1 [compute_bond  $x $k $x0]
# 	 set Esteric2 [compute_bond  [expr {$x+$h}] $k $x0]
#       } elseif {[regexp "angle|lbend" $type]} {
# 	 set v1 [vecsub $pos(0) $pos(1)]
# 	 set v2 [vecsub $pos(2) $pos(1)]
# 	 set la [veclength $v1]
# 	 set lb [veclength $v2]

# 	 lappend selgeomlist [list $x $la $lb]
# 	 foreach {k x0 kub s0} [lindex $entry 4] {break}
# 	 lappend selparamlist [list $tag [list $k $x0 $kub $s0]]
# 	 # Compute 1-3 distance from angle and 1-2 an 2-3 dist
# 	 set s [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos($x*$deg2rad) + pow($lb,2))}]
# 	 set Esteric1 [compute_angle  $x $k $x0 $s $kub $x0]
# 	 set s [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos(($x-$h)*$deg2rad) + pow($lb,2))}]
# 	 set Esteric0 [compute_angle  [expr {$x-$h}] $k $x0 $s $kub $s0]
# 	 set s [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos(($x+$h)*$deg2rad) + pow($lb,2))}]
# 	 set Esteric2 [compute_angle  [expr {$x+$h}] $k $x0 $s $kub $s0]
#       } elseif {[regexp  "dihed" $type]} {
# 	 #set v1 [vecsub $pos(0) $pos(1)]
# 	 #set v2 [vecsub $pos(3) $pos(2)]

# 	 lappend selgeomlist $x
# 	 foreach {K n delta} [lindex $entry 4] {break}
# 	 lappend selparamlist [list $tag [list $K $n $delta]]
# 	 #set k [expr $K*$n*$n*0.5]; # force constant for harmonic potential
# 	 set Esteric0 [compute_dihed  [expr {$x-$h}] $K $n $delta]
# 	 set Esteric1 [compute_dihed  $x $K $n $delta]
# 	 set Esteric2 [compute_dihed  [expr {$x+$h}] $K $n $delta]
#       } elseif {[regexp  "imprp" $type]} {
# 	 set v1 [vecsub $pos(0) $pos(1)]
# 	 set v2 [vecsub $pos(3) $pos(2)]
# 	 set cb [vecsub $pos(1) $pos(2)]
# 	 set cd [vecsub $pos(3) $pos(2)]
# 	 set ab [vecsub $pos(1) $pos(0)]
# 	 set s  [veccross $cb $cd]
# 	 set r  [veccross $ab $s]

# 	 lappend selgeomlist $x
# 	 foreach {k x0} [lindex $entry 4] {break}
# 	 lappend selparamlist [list $tag [list $k $x0]]
# 	 set Esteric0 [compute_imprp  [expr {$x-$h}] $k $x0]
# 	 set Esteric1 [compute_imprp  $x $k $x0]
# 	 set Esteric2 [compute_imprp  [expr {$x+$h}] $k $x0]
#       }


      # Write a dcd to run the simulation on; contains the last frame of $molidbase
      variable molidbase
      animate write dcd $dcdfile beg 0 waitfor all  $molid

      variable energy [::NAMDserver::namd_compute_energies $namdserver $dcdfile TOTAL]
      variable etitle $::NAMDserver::etitle
#puts "energy=$energy"
      # We must multiply $del by 2 because we changed the coordinate symmetrically
      #set h [expr abs(2.0*$del)]

      # Get the actual total energies for the selected intcoor
      foreach {Ecenter Elower Eupper} [get_total_energy] {break}
      #set Etotalderiv [list $Elower $Ecenter $Eupper]

      # Get the steric energy with out the contribution from the selected intcoor
      #lappend Estericnosel [vecsub $Etotalderiv [list $Esteric0 $Esteric1 $Esteric2]]

      puts "$tag [expr {$x-$h}]   $x    [expr {$x+$h}]"
      puts "$tag Elower=$Elower; Ecenter=$Ecenter; Eupper=$Eupper"

      # First derivative f'(x) = (f(x+h) - f(x-h))/2h
      lappend deriv1 [expr {($Eupper-$Elower)/(2.0*$h)}]

      # Force constant f''(x)/2 = 0.5*(f(x-h) - 2f(x) + f(x+h))/h^2
      set effk [expr {0.5*($Elower - 2.0*$Ecenter + $Eupper)/pow($h,2)}]
      if {[regexp "angle|lbend|dihed|imprp" $type]} {
	 set effk [expr {pow($rad2deg,2)*$effk}]
      }

      # Estimated effective minimum
      set effx0 [parabolic_extrapolation [expr {$x-$h}] $x [expr {$x+$h}] $Elower $Ecenter $Eupper]


      # Delete the tmp frames
      animate delete beg 1  $molid ; 


      if  {[llength $effklist]} {
	 lset effklist $intcoor $effk
      }
      if  {[llength $effx0list]} {
	 lset effx0list $intcoor $effx0
      }
#       if  {[llength $dklist]} {
# 	 lset dklist $intcoor [expr {$effk+[lindex $targetklist $intcoor]}]
#       }
#       if  {[llength $dx0list]} {
# 	 lset dx0list $intcoor [expr {$effx0+[lindex $targetx0list $intcoor]}]
#       }
      lappend seleffklist  $effk
      lappend seleffx0list $effx0
      #puts "effx0=$effx0 effk=$effk d1=[expr ($Eupper-$Elower)/(2.0*$h)]"

      # For debugging: Plot potentials
      if {$plot} {
	 set derivx [list [expr {$x-$h}] $x [expr {$x+$h}]] 
	 set derivE [vecsub [list $Elower $Ecenter $Eupper] [list $center $center $center]]
	 lappend x0list $x
	 lappend klist $k
	 variable scanwidth
	 variable scansteps
	 set center [lindex $entry 3]
	 set start  [expr {$center-0.2*$scanwidth}]
	 set end    [expr {$center+0.2*$scanwidth}]
	 set del    [expr {-0.1*$scanwidth}]
	 #puts "center=$center; del=[expr {$center-$start}]"
	 set stepsize [expr {($end-$start)/double($scansteps)}]

	 variable targetx0list
	 variable targetklist
	 set targetx0 [lindex $targetx0list $intcoor]
	 set targetk  [lindex $targetklist  $intcoor]
	 set xlist $start
	 set ylist [expr {$k*pow(($start-$x0), 2)}]
	 set yestlist [expr {$effk*pow(($start-$effx0), 2)}]
	 set ytlist [expr {$targetk*pow(($start-$targetx0), 2)}]
	 for {set i 1} {$i<=$scansteps} {incr i} {
	    set xi [expr {$start+$i*$stepsize}]
	    set yi [expr {$k*pow(($xi-$x0), 2)}]
	    set yest [expr {$effk*pow(($xi-$effx0), 2)}]
	    set yt [expr {$targetk*pow(($xi-$targetx0), 2)}]
	    lappend xlist $xi
	    lappend ylist $yi
	    lappend yestlist $yest
	    lappend ytlist $yt
	    #puts "$i:  $x  $y $yest"
	 }
	 set xlabel "bond distance (A)"
	 set plothandle [multiplot -x $xlist -y $ytlist -title "Derivatives $type [lindex $entry 0]" \
			    -linecolor red -lines -linewidth 4 -marker none \
			    -ysize 400 -xsize 600 -legend "target harmonic potential x0=$targetx0 k=$targetk"]
	 $plothandle configure -xlabel $xlabel -ylabel "E (Kcal/mol)"
	 $plothandle add $xlist $yestlist -lines -linecolor blue -linewidth 2 -legend "estimated harmonic potential x0=$effx0 k=$effk"
	 $plothandle add $xlist $ylist -lines -linecolor green -linewidth 2 -legend "given harmonic potential x0=$x0 k=$k"
	 $plothandle add $derivx $derivE \
	    -lines -fillcolor orange -marker circle -radius 3 -legend "numerical derivative"
	 $plothandle replot
      }
   }

   # Cleanup the tmp files
   if {[file exists $dcdfile]} { file delete $dcdfile }

   return [list $deriv1 $seleffklist $seleffx0list]
}

proc ::Paratool::Energy::stop_namdserver {args} {
   variable namdserver
   if {$namdserver!=0} {
      #::NAMDserver::stop_server
      puts $namdserver quit
      set id [after 4000 {set ::NAMDserver::sock 0; puts TIMEOUT}]
      vwait ::NAMDserver::sock
      after cancel $id
      variable namdserver 0
      variable energy  {}
      variable etitle  {}
   }
}


########################################################################
# This is called by a trace callback on ::NAMDserver::sock in case     #
# that sock is set to zero which means the NAMDserver is disconnected. #
########################################################################

proc ::Paratool::Energy::namdserver_killed_cb {args} {
   if {$::NAMDserver::sock==0} {
      #puts "NAMDserver was killed, resetting $::Paratool::namdserver"
      set ::Paratool::namdserver 0
   }
}


proc ::Paratool::Energy::start_namdserver {sel1 {etype "-all"} {rebuild "-rebuild"}} {
   variable namdserver
   # Stop any existing NAMDserver # Return if NAMDserver exists
   if {$namdserver!=0} {
      stop_namdserver
   }

   if {$rebuild=="-rebuild"} {
      # We run psfgen again anyway since the topology might have changed
      # We build separately since write_psfgen_input also sets psf
      ::Paratool::write_topology_file  namdserver-tmp.top

      ::Paratool::write_psfgen_input -file namdserver-tmp.pgn -force -top namdserver-tmp.top \
	 -output namdserver-tmp -build
      if {![llength [glob -nocomplain namdserver-tmp.pgn]]} {
	 error "::Paratool::Energy::start_namdserver: File namdserver-tmp.pgn not existent!"
      }
   }

   ::Paratool::write_parameter_file namdserver-tmp.par -temporary

   # Generate list of parameter files. 
   # Our own parameter file must be the last to override existing parameters!
   set par ""
   foreach p $::Paratool::paramsetfiles {
      append par " -par $p"
   }
   append par " -par namdserver-tmp.par"

   variable ::Paratool::molidbase
   # Prepare a NAMD config file:
   # We need a huge cutoff to get the full direct interaction
   #puts "namdenergy -server -sel $sel1 $etype $par -psf $::Paratool::psf -tempname namdserver \
   #   -switch 10000 -cutoff 20000 -mol $molidbase"
   eval namdenergy -server -sel $sel1 $etype $par -psf namdserver-tmp.psf -tempname "namdserver" \
      -switch 10000 -cutoff 20000 -mol $molidbase

   # Remove old traces
   foreach t [trace info variable ::NAMDserver::sock] {
      trace remove variable ::NAMDserver::sock write ::Paratool::Energy::namdserver_killed_cb
   }

   # Start the new server and set a trace on it's sock variable.
   # When sock is set 0 this notifies that namdserver was stopped.
   variable namdserver [::NAMDserver::start_server "namdserver-temp.namd"]
   trace add variable ::NAMDserver::sock write ::Paratool::Energy::namdserver_killed_cb

   variable energy  {}
   variable etitle  {}

   return $namdserver
}


proc ::Paratool::Energy::compute_energies {} {
   variable namdserver
   if {$namdserver==0} { return }

   # Write a dcd to run the simulation on; contains the last frame of $molidbase
   variable molidbase
   set dcdfile namdserver-tmp.dcd
   animate write dcd $dcdfile waitfor all beg [expr {[molinfo $molidbase get numframes]+1}] $molidbase

   # Write charges into tmpfile
   set all [atomselect $molidsyswat all]
   set fd [open tmpchargefile.dat w]
   puts $fd [$all get charge]
   close $fd

   # Reload new charges in NAMD
   puts $namdserver "reloadCharges tmpchargefile.dat"

   variable energy [::NAMDserver::namd_compute_energies $namdserver $dcdfile]
   variable etitle $::NAMDserver::etitle
   return [list $etitle $energy]
}

proc ::Paratool::Energy::get_total_energy {} {
   variable energy
   variable etitle
   set total {}
   set pos [lsearch $etitle "TOTAL"]
   foreach line $energy {
      lappend total [lindex $line $pos]
   }
   return $total
}


#####################################################################
# We assume the $selparamlist is set to the desired expanded        #
# parameter list. The derivatives are updated by recomputing the    #
# nonbonded interaction via TCL. Thus we caan change parameters in  #
# memory and don't have to rewrite a parameter file.                #
#####################################################################

proc ::Paratool::Energy::update_selected_derivatives {intcoorlist} {
   variable selparamlist
   variable selgeomlist
   variable Estericnosel
   variable hbond
   variable hangle
   variable hdihed
   variable himprp
   variable ::Paratool::Refinement::effklist  
   variable ::Paratool::Refinement::effx0list 
   set deg2rad 0.0174532925199; # [expr 3.14159265358979/180.0]
   set rad2deg 57.2957795131;   # [expr 180.0/3.14159265358979]

puts "Estericnosel=$Estericnosel"
   set h 0.0
   set Esteric {0.0 0.0 0.0}
   foreach selparam $selparamlist selgeom $selgeomlist stericnosel $Estericnosel intcoor $intcoorlist {
      set energy {}
      foreach {g la lb} $selgeom {break}

      set tag [lindex $selparam 0]

      switch -glob $tag {
	 R* {
	    set h $hbond
	    foreach x [list [expr {$g-$h}] $g [expr {$g+$h}]] {
	       foreach {k x0} [lindex $selparam 1] {break}
	       lappend energy [compute_bond  $x $k $x0]
	    }
	    set Esteric [vecadd $Esteric $energy]
	 }
	 A* { 
	    set h $hangle
	    foreach x [list [expr {$g-$hangle}] $g [expr {$g+$hangle}]] {
	       foreach {k x0 kub s0} [lindex $selparam 1] {break}
puts "k=$k x0=$x0 kub=$kub s0=$s0"
	       # Compute 1-3 distance from angle and 1-2 an 2-3 dist
	       set s [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos($x*$deg2rad) + pow($lb,2))}]
	       lappend energy [compute_angle $x $k $x0 $s $kub $s0]
	    }
	    set Esteric [vecadd $Esteric $energy]
	 }
	 D* {
	    set h $hdihed
	    foreach x [list [expr {$g-$hdihed}] $g [expr {$g+$hdihed}]] { 
	       foreach {K n delta} [lindex $selparam 1] {break}
	       lappend energy [compute_dihed $x $K $n $delta]
	    }
	    set Esteric [vecadd $Esteric $energy]
	 }
	 O* {
	    set h $himprp
	    foreach x [list [expr {$g-$himprp}] $g [expr {$g+$himprp}]] { 
	       foreach {k x0} [lindex $selparam 1] {break}
	       lappend energy [compute_bond  $x $k $x0]
	    }
	    set Esteric [vecadd $Esteric $energy]
	 }
      }

      # Get the total energies with the new steric contributions
      set Elower  [expr {[lindex $stericnosel 0]+[lindex $Esteric 0]}]
      set Ecenter [expr {[lindex $stericnosel 1]+[lindex $Esteric 1]}]
      set Eupper  [expr {[lindex $stericnosel 2]+[lindex $Esteric 2]}]

      puts "$tag [expr {$g-$h}]   $g   [expr {$g+$h}]"
      puts "$tag Elower=$Elower; Ecenter=$Ecenter; Eupper=$Eupper"

      # First derivative f'(x) = (f(x+h) - f(x-h))/2h
      lappend deriv1 [expr {($Eupper-$Elower)/(2.0*$h)}]

      # Force constant f''(x)/2 = 0.5*(f(x-h) - 2f(x) + f(x+h))/h^2
      set effk [expr {0.5*($Elower - 2.0*$Ecenter + $Eupper)/pow($h,2)}]
      if {![string match "R*" $tag]} {
puts "SCALING WITH RAD2DEG"
	 set effk [expr {pow($rad2deg,2)*$effk}]
      }

      # Estimated effective minimum
      set effx0 [parabolic_extrapolation [expr {$g-$h}] $g [expr {$g+$h}] $Elower $Ecenter $Eupper]

      if  {[llength $effklist]} {
	 lset effklist $intcoor $effk
      }
      if  {[llength $effx0list]} {
	 lset effx0list $intcoor $effx0
      }
      lappend seleffklist  $effk
      lappend seleffx0list $effx0
      puts "effx0=$effx0 effk=$effk d1=[expr {($Eupper-$Elower)/(2.0*$h)}]"
   }

   return [list $deriv1 $seleffklist $seleffx0list]
}


proc ::Paratool::Energy::compute_selected_bonded_energies {} {
   variable ::Paratool::selintcoorlist
   variable ::Paratool::zmat
   variable selparamlist
   variable selgeomlist
   foreach selparam $selparamlist selgeom $selgeomlist {
      switch [lindex $selparam 0] {
	 R* {
	    foreach {k x0} [lindex $selparam 1] {break}
	    set energy [expr {$energy + [compute_bond  $selgeom $k $x0]}]
	 }
	 A* { 
	    foreach {k x0 kub s0} [lindex $selparam 1] {break}
	    foreach {x s} $selgeom {break}
	    set energy [expr {$energy + [compute_angle $x $k $x0 $s $kub $s0]}]
	 }
	 D* { 
	    foreach {K n delta} [lindex $selparam 1] {break}
	    set energy [expr {$energy + [compute_dihed $selgeom $K $n $delta [lindex $entry 3]]}]
	 }
	 O* { 
	    foreach {k x0} [lindex $selparam 1] {break}
	    set energy [expr {$energy + [compute_bond  $selgeom $k $x0]}]
	 }
      }
   }
   return $energy
}

proc ::Paratool::Energy::compute_bond {x k x0} {
   return [expr {$k*pow($x-$x0,2)}]
}

proc ::Paratool::Energy::compute_angle {x k x0 s kub s0} {
   if {[llength $kub] && [llength $s0]} {
      return [expr {$k*pow($x-$x0,2) + $kub*pow($s-$s0,2)}]
   } else {
      return [expr {$k*pow($x-$x0,2)}]
   }
}

proc ::Paratool::Energy::compute_ureybradley {s kub s0} {
   return [expr {$kub*pow($s-$s0,2)}]
}

proc ::Paratool::Energy::compute_ureybradley_x {x kub s0 la lb} {
   set deg2rad 0.0174532925199
   set s [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos($x*$deg2rad) + pow($lb,2))}]
   return [expr {$kub*pow($s-$s0,2)}]   
}   

proc ::Paratool::Energy::compute_ureybradley_x2s {x la lb} {
   set deg2rad 0.0174532925199
   return [expr {sqrt(pow($la,2)-2.0*$la*$lb*cos($x*$deg2rad) + pow($lb,2))}]
}   

proc ::Paratool::Energy::compute_dihed {x K n delta} {
   set deg2rad 0.0174532925199
   return [expr {$K*(1+cos($deg2rad*($n*$x-$delta)))}]
}

proc ::Paratool::Energy::compute_imprp {x k x0} {
   set deg2rad 0.0174532925199
   return [expr {$k*pow($deg2rad*($x-$x0),2)}]
}

#############################################################
# VDW energy:                                               #
# Evdw = eps * ((Rmin/dist)**12 - 2*(Rmin/dist)**6)         #
# eps = sqrt(eps1*eps2),  Rmin = Rmin1+Rmin2                #
#############################################################
proc ::Paratool::Energy::compute_vdw {dist rmin1 eps1 rmin2 eps2} {
   set term6 [expr {pow(($rmin1+$rmin2)/$dist,6)}]
   return [expr {sqrt($eps1*$eps2)*($term6*$term6 - 2.0*$term6)}]
}

#############################################################
# VDW force:                                                #
# Fvdw = eps * 12/dist * ((Rmin/dist)**12 - (Rmin/dist)**6) #
#############################################################

proc ::Paratool::Energy::compute_vdw_force {dist rmin1 eps1 rmin2 eps2} {
   set term6 [expr {pow(($rmin1+$rmin2)/$dist,6)}]
   return [expr {sqrt($eps1*$eps2) * ($term6*$term6 - $term6) * 12.0/$dist}]
}

##########################################################
# Computes the Van der Waals interaction between two     #
# selections. The vdw parameters must be stored in atom  #
# based fields e.g. {occupancy beta}.                    #
##########################################################

# switchfactor = 1.f/((cutoff2 - switchdist2)*(cutoff2 - switchdist2)*(cutoff2 - switchdist2));
# vdw *= switchfactor*(cutoff2 - dist2)*(cutoff2 - dist2)*(cutoff2 - 3.f*switchdist2 + 2.f*dist2);
proc ::Paratool::Energy::compute_vdw_interaction { sel1 sel2 args } {
   set force 0
   set pos [lsearch $args "-force"]
   if {$pos>=0} { set force 1 }

   set totalvdw 0.0
   foreach r1 [$sel1 get {x y z}] ind1 [$sel1 get index] {
      set vdwrmin1 [::Paratool::get_atomprop VDWrmin $ind1]
      set vdweps1  [::Paratool::get_atomprop VDWeps  $ind1]
      set vdw14rmin1 [::Paratool::get_atomprop VDWrmin14 $ind1]
      set vdw14eps1  [::Paratool::get_atomprop VDWeps14  $ind1]
      foreach r2 [$sel2 get {x y z}] ind2 [$sel2 get index] {
	 if {[is_excluded $ind1 $ind2]} { continue }
	 if {[is_onefour $ind1 $ind2]} {
	    set vdw14rmin2 [::Paratool::get_atomprop VDWrmin14 $ind2]
	    set vdw14eps2  [::Paratool::get_atomprop VDWeps14  $ind2]
	    if {[llength $vdw14rmin1] && [llength $vdw14eps1] && [llength $vdw14rmin2] && [llength $vdw14eps2]} {
	       set vdwrmin1 $vdw14rmin1
	       set vdweps1  $vdw14eps1
	       set vdwrmin2 $vdw14rmin2
	       set vdweps2  $vdw14eps2
	    } else {
	       set vdwrmin2 [::Paratool::get_atomprop VDWrmin $ind2]
	       set vdweps2  [::Paratool::get_atomprop VDWeps  $ind2]
	    }
	 } else {
	    set vdwrmin2 [::Paratool::get_atomprop VDWrmin $ind2]
	    set vdweps2  [::Paratool::get_atomprop VDWeps  $ind2]
	 }
 	 set dist [veclength [vecsub $r2 $r1]]

	 if {$force} {
	    set vdw [compute_vdw_force $dist $vdwrmin1 $vdweps1 $vdwrmin2 $vdweps2]
	 } else {
	    set vdw [compute_vdw $dist $vdwrmin1 $vdweps1 $vdwrmin2 $vdweps2]
	 }

 	 #puts "$ind1-$ind2 rmin=rmin dist=$dist e=$vdw"
 	 set totalvdw  [expr {$totalvdw+$vdw}]
      }
   }

   return $totalvdw
}

##########################################################
# Computes the electrostatic interaction between two     #
# selections. The cutoff can be specified as an optional #
# parameter.                                             #
##########################################################

proc ::Paratool::Energy::compute_elstat_interaction { sel1 sel2 args} {
   set cut 0
   set force 0
   set pos [lsearch $args "-cutoff"]
   if {$pos>=0 && $pos<[llength $args]-1} {
      set cut [lindex $args [expr {$pos+1}]]
   }
   set pos [lsearch $args "-force"]
   if {$pos>=0} { set force 1 }


   set kcalmol 332.0636; # expr 1.0e10/(4.0*$pi*8.85419e-12*4184)*6.02214e23*pow(1.60218e-19,2)
   set totalelstat 0.0
   foreach q1 [$sel1 get charge] r1 [$sel1 get {x y z}] ind1 [$sel1 get index] {
      foreach q2 [$sel2 get charge] r2 [$sel2 get {x y z}] ind2 [$sel2 get index] {
	 if {[is_excluded $ind1 $ind2]} { continue }
	 set q1 [format "%.4f" [::Paratool::get_complexcharge $ind1]]
	 set q2 [format "%.4f" [::Paratool::get_complexcharge $ind2]]
	 #set q1 [format "%.4f" $q1]
	 #set q2 [format "%.4f" $q2]
	 set dist [veclength [vecsub $r2 $r1]]
	 if {$cut!=0} {
	    set efac [expr {1.0-$dist*$dist/($cut*$cut)}]
	    set elstat [expr {$kcalmol*$q1*$q2/$dist*$efac*$efac}]
	 } else {
	    set elstat [expr {$kcalmol*$q1*$q2/$dist}]
	 }
	 #puts "$ind1-$ind2 elstat=$elstat"
	 if {$force} {
	    set totalelstat [expr {$totalelstat-$elstat/$dist}]
	 } else {
	    set totalelstat [expr {$totalelstat+$elstat}]
	 }
      }
   }

   return $totalelstat
}


##########################################################
# Computes the electrostatic force between two           #
# selections. The cutoff can be specified as an optional #
# parameter.                                             #
##########################################################

proc ::Paratool::Energy::compute_elstat_force { sel1 sel2 {cut 0}} {
   set kcalmol 332.0636; # expr 1.0e10/(4.0*$pi*8.85419e-12*4184)*6.02214e23*pow(1.60218e-19,2)
   set totalelstat 0.0
   foreach q1 [$sel1 get charge] r1 [$sel1 get {x y z}] ind1 [$sel1 get index] {
      foreach q2 [$sel2 get charge] r2 [$sel2 get {x y z}] ind2 [$sel2 get index] {
	 if {[is_excluded $ind1 $ind2]} { continue }
	 set q1 [format "%.4f" [::Paratool::get_complexcharge $ind1]]
	 set q2 [format "%.4f" [::Paratool::get_complexcharge $ind2]]
	 set dist [veclength [vecsub $r2 $r1]]
	 if {$cut!=0} {
	    set efac [expr {1.0-$dist*$dist/($cut*$cut)}]
	    set elstat [expr {$kcalmol*$q1*$q2/pow($dist,2)*$efac*$efac}]
	 } else {
	    set elstat [expr {$kcalmol*$q1*$q2/pow($dist,2)}]
	 }
	 #puts "$ind1-$ind2 elstat=$elstat"
	 set totalelstat [expr {$totalelstat+$elstat}]
      }
   }

   return $totalelstat
}

proc ::Paratool::Energy::get_formatted_14_interactions { } {
   variable onefourlist
   variable onefourinter {}
   variable ::Paratool::atomproplist
   variable ::Paratool::molidbase

   set i 0
   foreach atom $onefourlist {
      set sel1 [atomselect $molidbase "index $i" frame last]
      set vdwrmin1   [::Paratool::get_atomprop VDWrmin $i]
      set vdw14rmin1 [::Paratool::get_atomprop VDWrmin14 $i]
      foreach j $atom {
	 if {$j>=$i} { continue }
	 set sel2 [atomselect $molidbase "index $j" frame last]
	 set R    [veclength [vecsub [join [$sel1 get {x y z}]] [join [$sel2 get {x y z}]]]]
	 set vdwrmin2   [::Paratool::get_atomprop VDWrmin $j]
	 set vdw14rmin2 [::Paratool::get_atomprop VDWrmin14 $j]
	 if {[llength $vdw14rmin1] && [llength $vdw14rmin2]} {
	    set vdwrmin1 $vdw14rmin1
	    set vdwrmin2 $vdw14rmin2
	 }
	 set Rmin [expr {$vdwrmin1+$vdwrmin2}]

	 set vdw  [compute_vdw_interaction $sel1 $sel2]
	 set elec [compute_elstat_interaction $sel1 $sel2]
	 set nonb [expr {$vdw+$elec}]
	 set fvdw  [compute_vdw_interaction $sel1 $sel2 -force]
	 set felec [compute_elstat_force $sel1 $sel2]
	 set fnonb [expr {$fvdw+$felec}]
	 set name1 [::Paratool::get_atomprop Name $i]
	 set name2 [::Paratool::get_atomprop Name $j]
	 lappend onefourinter [list $i $j $name1 $name2 $R $Rmin $vdw $elec $nonb $fvdw $felec $fnonb [expr {abs($fnonb)}]]
      }
      incr i
   }

   set formatted {}
   set onefourinter [lsort -real -decreasing -index 12 $onefourinter] 
   foreach pair $onefourinter {
      foreach {ind1 ind2 name1 name2 R Rmin Evdw Eelec Enonb Fvdw Felec Fnonb buf} $pair {}
      set knowntype1 [::Paratool::get_atomprop Known $ind1]
      set knowntype2 [::Paratool::get_atomprop Known $ind2]
      set refine Yes
      if {$knowntype1 && $knowntype2} {
	 set refine No
      }
      # The last three elements are invisible in the listbox
      lappend formatted [format "%4s--%-4s %6.3f %6.3f %8.3f %8.3f %8.3f  %8.3f %8.3f %8.3f %5s" \
			    $name1 $name2 $R $Rmin $Evdw $Eelec $Enonb $Fvdw $Felec $Fnonb $refine]
   }

   return $formatted
}

proc ::Paratool::Energy::compute_14_forces { } {
   variable onefourlist
   variable ::Paratool::atomproplist
   variable ::Paratool::molidbase
   set onefourinter {}
   set i 0
   foreach atom $onefourlist {
      set sel1 [atomselect $molidbase "index $i"]
      foreach j $atom {
	 set sel2 [atomselect $molidbase "index $j"]
	 set vdw  [compute_vdw_interaction $sel1 $sel2 -force]
	 set elec [compute_elstat_force $sel1 $sel2]
	 set nonb [expr {$vdw+$elec}]
	 lappend onefourinter [list $i $j $vdw $elec $nonb]
      }
      incr i
   }
   return [lsort -index 4 $onefourinter]
}

proc ::Paratool::Energy::update_14_list {} {
   variable onefourlist {}
   variable ::Paratool::molidbase
   set sel [atomselect $molidbase all]

   foreach i [$sel get index] onetwo [$sel getbonds] {
      set onefour  [lindex [::util::bondedsel $molidbase $i {} -maxdepth 4] 1]
      set onethree [lindex [::util::bondedsel $molidbase $i {} -maxdepth 3] 1]

      lappend onefourlist [::util::ldiff [::util::ldiff $onefour $onethree] $onetwo]
   }
   
   return $onefourlist
}


proc ::Paratool::Energy::compute_13_exclusions {} {
   variable excluded13 {}
   variable ::Paratool::molidbase
   set sel [atomselect $molidbase all]

   foreach i [$sel get index] {
      lappend excluded13 [::util::bondedsel $molidbase $i {} -maxdepth 3]
   }
   
   return $excluded13
}


#########################################################
# Checks if the two selected atoms are excluded by      #
# the 1-3 rule.                                         #
#########################################################

proc ::Paratool::Energy::is_excluded {ind1 ind2} {
   variable excluded13
   return [expr {[lsearch [lindex $excluded13 $ind1] $ind2]<0 ? 0 : 1}]
}

#########################################################
# Checks if the two seleccted atoms are excluded by     #
# the 1-3 rule.                                         #
#########################################################

proc ::Paratool::Energy::is_onefour {ind1 ind2} {
   variable onefourlist
   return [expr {[lsearch [lindex $onefourlist $ind1] $ind2]<0 ? 0 : 1}]
}

proc ::Paratool::Energy::update_selected_geometries {molid} {
   variable selgeomlist
   [measure bond [list $atom(0) $atom(1)] molid $molid]
}

###########################################################
# We are using a local copy of the parameters for the     #
# energy calculations. This function gets them from zmat. #
###########################################################

proc ::Paratool::Energy::read_bonded_params_from_zmat {} {
   variable ::Paratool::selintcoorlist
   variable selparamlist {}
   foreach selintcoor $selintcoorlist {
      set entry [$zmat [expr {$selintcoor+1}]]
      lappend selparamlist [list [lindex $entry 0] [lindex $entry 4]]
   }
}


###########################################################
# Update params in zmat from our local copy.              #
###########################################################

proc ::Paratool::Energy::write_bonded_params_to_zmat {} {
   variable ::Paratool::selintcoorlist
   variable ::Paratool::zmat
   variable selparamlist
   foreach selintcoor $selintcoorlist selparam $selparamlist {
      lset zmat [expr {$selintcoor+1}] [lindex $selparam 1]
   }
}