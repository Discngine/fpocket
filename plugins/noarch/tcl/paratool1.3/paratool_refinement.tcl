# Refinement
# ----------

# Our initial parameter set are the quantumchemical equilibrium geometries and
# force constants. When applied in a force field these steric parameters are
# combined with nonbonded interaction parameters which cause the force field
# equilibrium geometry to be different from the quantumchemical one.
# Thus we have to adjust the parameters accordingly.
# 1) Fit equilibrium geometry
# 2) Fit vibrational frequencies
# 3) 
# Moreover, the CHARMM energy
# function is not expected to reproduce the vibrational
# spectra of all the nucleic acid bases with the accuracy of the
# force fields used for individual molecules in vibrational
# spectroscopy. The limitations are two-fold: first, one seeks
# to minimize the number of atom types in the parametrization;
# second, cross-terms between internal coordinates used in most
# vibrational force fields are not included in the CHARMM energy
# function. Both of these limitations are introduced to obtain a
# simple and widely applicable potential energy function. We
# require that the calculated frequencies differ from the reference
# values by no more than 10%.

namespace eval ::Paratool::Refinement {
   proc initialize {} {
      variable effx0list {}
      variable effklist  {}
      variable targetx0list {}
      variable targetklist  {}
      variable dx0list {}
      variable dklist  {}
      variable paramlist {}
      variable fitureybradley 0
      variable vdw14list {}
      variable maxiter 50
      variable debug 0
      variable optmethod downhill
      variable rtol 0.01
      variable curatom1 {}
      variable curatom2 {}
   }
   initialize
}


proc ::Paratool::Refinement::gui { } {

   # If already initialized, just turn on
   if { [winfo exists .paratool_refinement] } {
      set geom [winfo geometry .paratool_refinement]
      wm withdraw  .paratool_refinement
      wm deiconify .paratool_refinement
      wm geometry  .paratool_refinement $geom
      focus .paratool_refinement

      update_paramlist
      return
   }

   variable ::Paratool::selectcolor
   variable ::Paratool::fixedfont
   set v [toplevel ".paratool_refinement"]
   wm title $v "Refinement of selected bonded parameters"
   wm resizable $v 0 0

   label $v.info -wraplength 11c -text "Refinement tries to tune the parameters x0 and k so that the effective x0 and k \
which include the nonbonded contributions match the target parameters as close as possible."
   labelframe $v.types -bd 2 -relief ridge -text "List of coordinates for parameter refinement" -padx 2m -pady 2m
   label $v.types.format -font $fixedfont -text [format "%4s %9s %9s  %9s %9s  %9s %9s  %9s %9s" Name x0 eff_x0 target_x0 delta_x0 k eff_k target_k delta_k] \
      -relief flat -bd 2 -justify left;

   frame $v.types.list
   scrollbar $v.types.list.scroll -command "$v.types.list.list yview"
   listbox $v.types.list.list -activestyle dotbox -yscroll "$v.types.list.scroll set" -font $fixedfont \
      -width 87 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::Refinement::paramlist
   pack $v.types.list.list    -side left -fill both -expand 1
   pack $v.types.list.scroll  -side left -fill y -expand 1
 
   pack $v.types.format  -anchor w
   pack $v.types.list    -expand 1 -fill both -anchor w

   pack $v.info
   pack $v.types -padx 1m -pady 1m -fill both -expand 1 

   frame  $v.fit
   frame $v.fit.maxiter
   label $v.fit.maxiter.label -text "Max. iterations: "
   entry $v.fit.maxiter.entry -textvariable ::Paratool::Refinement::maxiter -width 5
   pack $v.fit.maxiter.label $v.fit.maxiter.entry -side left 
   pack $v.fit.maxiter

   frame $v.fit.debug
   label $v.fit.debug.label -text "Debug level: "
   entry $v.fit.debug.entry -textvariable ::Paratool::Refinement::debug -width 5
   pack $v.fit.debug.label $v.fit.debug.entry -side left
   pack $v.fit.debug

   frame $v.fit.rtol
   label $v.fit.rtol.label -text "Relative tolerance: "
   entry $v.fit.rtol.entry -textvariable ::Paratool::Refinement::rtol -width 5
   pack $v.fit.rtol.label $v.fit.rtol.entry -side left
   pack $v.fit.rtol

   frame $v.fit.method
   label $v.fit.method.label -text "Optimization method: "
   tk_optionMenu $v.fit.method.button ::Paratool::Refinement::optmethod \
      "downhill" "annealing"
   pack $v.fit.method.label $v.fit.method.button -side left
   pack $v.fit.method
   pack $v.fit

   frame  $v.check
   checkbutton $v.check.ub -text "Refine Urey Bradley term instead of harmonic angle term" \
      -variable ::Paratool::Refinement::fitureybradley
   pack $v.check.ub
   pack $v.check

   frame  $v.buttons
   button $v.buttons.refine -text "Refine bonded parameters" -command ::Paratool::Refinement::run

   pack $v.buttons.refine  -side left
   pack $v.buttons

   # Initialize the lists for target and effective parameters
   #init_paramlist
   update_paramlist
}


#############################################################
# Initialize the lists for targets and effective parameters #
# and their difference.
#############################################################

proc ::Paratool::Refinement::init_paramlist {} {
   variable ::Paratool::zmat
   #variable targetx0list {}
   #variable targetklist  {}
   #variable effx0list    {}
   #variable effklist     {}
   variable dx0list      {}
   variable dklist       {}
   set intcoorlist {}
   for {set i 0} {$i<[expr [llength $zmat]-1]} {incr i} {
      #lappend targetx0list {}
      #lappend targetklist  {}
      #lappend effx0list    {}
      #lappend effklist     {}
      lappend dx0list      {}
      lappend dklist       {}
      lappend intcoorlist $i
   }

   # Get effective parameters for all internal coordinates
   foreach {d1list seleffklist seleffx0list} [::Paratool::Energy::compute_derivatives $intcoorlist -rebuild] {}

   update_paramlist
}


proc ::Paratool::Refinement::update_paramlist {{intcoorlist {}}} {
   if {![winfo exists .paratool_refinement]} { return }
   variable ::Paratool::zmat
   variable ::Paratool::selintcoorlist
   if {![llength $intcoorlist]} { set intcoorlist $selintcoorlist }
   variable effx0list
   variable effklist
   variable targetx0list
   variable targetklist 
   variable dx0list
   variable dklist
   variable paramlist {}
   foreach selintcoor $intcoorlist {
      set entry [lindex $zmat [expr $selintcoor+1]]
      if {[lindex $entry 1]=="dihed"} {
	 set n [lindex $entry 4 1]
	 set x0 [::Paratool::format_float "%9.3f" [lindex $entry 3]]
	 set k  [::Paratool::format_float "%9.3f" [expr [lindex $entry 4 0]*$n*$n*0.5]]
      } else {
	 set k  [::Paratool::format_float "%9.3f" [lindex $entry 4 0]]
	 set x0 [::Paratool::format_float "%9.3f" [lindex $entry 4 1]]
      }
      set effx0 [::Paratool::format_float "%9.3f" [lindex $effx0list $selintcoor]]
      set effk  [::Paratool::format_float "%9.3f" [lindex $effklist  $selintcoor]]
      set targetx0 [::Paratool::format_float "%9.3f" [lindex $targetx0list $selintcoor]]
      set targetk  [::Paratool::format_float "%9.3f" [lindex $targetklist  $selintcoor]]
      set dx0 [lindex $dx0list $selintcoor]
      set dk  [lindex $dklist  $selintcoor]
      if {[llength $dx0]} {
	 if {[lindex $entry 1]=="dihed"} {
	    set dx0 [::Paratool::format_float "%8.3f%%" [expr {100.0*abs($dx0/180.0)}]]
	 } else {
	    set dx0 [::Paratool::format_float "%8.3f%%" [expr {100.0*abs($dx0/$targetx0)}]]
	 }
      }
      if {[llength $dk]} {
	 set dk  [::Paratool::format_float "%8.3f%%" [expr {100.0*abs($dk /$targetk)}]]
      }
      lappend paramlist [format "%4s %9s %9s  %9s %9s  %9s %9s  %9s %9s" \
				      [lindex $entry 0] $x0 $effx0 $targetx0 $dx0 $k $effk $targetk $dk]
   }
}


###############################################################
# Provide new parameter values for the selected coordinates.  #
###############################################################

proc ::Paratool::Refinement::update_selected_fc {{format "-noformat"}} {
   variable ::Paratool::selintcoorlist
   variable ::Paratool::zmat
   variable params
   variable iparam
   foreach selintcoor $selintcoorlist {
      set izmat [expr $selintcoor+1]
      set entry [lindex $zmat $izmat]
      set k  [lindex $params $iparam($selintcoor,0)]
      set x0 [lindex $params $iparam($selintcoor,1)]
      if {[llength [array get iparam "$selintcoor,2"]]} {
	 set kub [lindex $params $iparam($selintcoor,2)]
	 set s0  [lindex $params $iparam($selintcoor,3)]
      } else {
	 set kub {}
	 set s0  {}
      }
      if {$format=="-format"} {
	 lset zmat $izmat 5 "[regsub -all {[QCRMA]} [lindex $entry 5] {}]R"
      }
      #puts "update_selected_fc $x0 $k"
      if {[lindex $entry 1]=="dihed"} {
	 set n [lindex $entry 4 1]
	 lset zmat $izmat 4 0 [expr 2.0*$k/pow($n,2)]
      } else {
	 if {[llength $kub]} {
	    lset zmat $izmat 4 [list $k $x0 $kub $s0]
	 } else {
	    lset zmat $izmat 4 0 $k
	    lset zmat $izmat 4 1 $x0
	 }
	 #puts "zmat $selintcoor: [lindex $entry 0] [lindex $zmat $izmat 4]"
      }
   }
}


#################################################
# Get the target values for the refinement.     #
#################################################

proc ::Paratool::Refinement::get_targets {} {
   variable ::Paratool::selintcoorlist
   variable targetx0list
   variable targetklist
   foreach selintcoor $selintcoorlist {
      lappend tx0list [lindex $targetx0list $selintcoor]
      lappend tklist  [lindex $targetklist  $selintcoor]
   }
   return [list $tx0list $tklist]
}


###################################################################
# Return a least squares error for the selected parameters.       #
# Numerical derivatives of the effective potential, i.e. the      #
# potential including the nonbonded interactions are computed.    #
# The second derivative/2 is the force contant k_eff.             #
# Parabolic extrapolation yields the effective potential minimum  #
# x0_eff. The errors in both parameters are squared and summed up #
# for all selected internal coordinates.                          #
# This is the function which is optimized in the refinement.      #
###################################################################

proc ::Paratool::Refinement::parameter_error {{newparams {}}} {
   variable ::Paratool::selintcoorlist
   if {[llength $newparams]} {
      variable params $newparams
      #puts "parameter_error: params=$params"

      # Expand the parameter list and set them in zmat.
      update_selected_fc 
   }
   foreach {d1list kefflist x0efflist} [::Paratool::Energy::compute_derivatives $selintcoorlist -norebuild] {}

   set xexp 2
   set kexp 2
   set err 0.0
   set err1 0.0
   set err2 0.0
   variable targetx0list
   variable targetklist
   variable dx0list 
   variable dklist  
   set i 0
   foreach selintcoor $selintcoorlist d1 $d1list {
      set dx0 [expr {[lindex $targetx0list $selintcoor]-[lindex $x0efflist $i]}]
      set dk  [expr {[lindex $targetklist  $selintcoor]-[lindex $kefflist  $i]}]
      lset dx0list $selintcoor $dx0
      lset dklist  $selintcoor $dk
      #puts "diff: dx0=$dx0 dk=$dk d1=$d1"
      set err1 [expr {$err1 + pow($dx0,$xexp)}]
      set err2 [expr {$err2 + pow($dk,$kexp)}]
      set err  [expr {$err  + pow($dx0,$xexp) + 0.1*pow($dk,$kexp)}]
      incr i
   }

   #puts "effective: $d1list $x0efflist; $kefflist;"
   #puts "target:    0.0     $targetx0list; $targetklist;"
   #puts "diff:      $d1list  $dx0list; $dklist;"
   puts "err=$err; err1=$err1; err2=$err2"
   return $err
}


###############################################################
# Tune the selected parameters x0 and k so that the effective #
# x0 and k which include the nonbonded contributions match    #
# the target parameters as close as possible.                 #
###############################################################

proc ::Paratool::Refinement::run {} {
   variable ::Paratool::zmat
   variable ::Paratool::selintcoorlist
   variable fitureybradley

   puts "Refining parameters of conformation(s):"
   foreach selintcoor $selintcoorlist {
      puts -nonewline " [lindex $zmat [expr $selintcoor+1] 0]"
   }
   puts ""

   # Multiple coordinate refinement:
   # -------------------------------------------

   if {[llength $selintcoorlist]>1 && !$fitureybradley} {

      # Check if we have equivalent internal coordinates
      # This case has to be handled. It means a reduction of free parameters for the fit.
      # (Currently we are just returning a warning.)
      set grouplist [::Paratool::get_equivalent_internal_coordinate_groups $selintcoorlist]
      if {[llength $selintcoorlist]>[llength $grouplist]} {
	 puts "WARNING: Equivalent parameters in selection!"
      }
      variable params {}
      variable iparam
      array unset iparam
      set i 0
      foreach group $grouplist {
	 # Parameters in a group are identical, so we just use the first coordinate.
	 set izmat [expr {[lindex $group 0]+1}]
	 # Make a parameter list containing one set per group
	 lappend params [lindex $zmat $izmat 4 0]
	 lappend params [lindex $zmat $izmat 4 1]
	 if {$fitureybradley} {
	    set kub [lindex $zmat $izmat 4 2]
	    set s0  [lindex $zmat $izmat 4 3]
	    if {![llength $kub]} {
	       # Initialize Kub with 0.0
	       lappend params 0.0
	    }
	    if {![llength $s0]} {
	       # Initialize s0 with current dist 
	       foreach {ind0 ind1 ind2} [lindex $zmat $izmat 2] {}
	       variable ::Paratool::molidbase
	       set sel [atomselect $molidbase "index $ind0 $ind2"]
	       set coor1 [lindex [$sel get {x y z}] 0]
	       set coor2 [lindex [$sel get {x y z}] 1]
	       lappend params [veclength [vecsub $coor1 $coor2]]
	    }
	 }
	 puts -nonewline "Group {[::Paratool::get_types_for_conf [lindex $zmat [expr 1+[lindex $group 0]] 2]]}:"
	 foreach intcoor $group {
	    puts -nonewline " [lindex $zmat [expr $intcoor+1] 0]"
	    set iparam($intcoor,0) $i;
	    set iparam($intcoor,1) [expr {$i+1}];
	    lappend ivparam($i)            "$intcoor,0";
	    lappend ivparam([expr {$i+1}]) "$intcoor,1";
	    if {$fitureybradley} {
	       set iparam($intcoor,2) [expr {$i+2}];
	       set iparam($intcoor,3) [expr {$i+3}];
	       lappend ivparam([expr {$i+2}]) "$intcoor,2";
	       lappend ivparam([expr {$i+3}]) "$intcoor,3";
	    }
	 }
	 puts ""
	 incr i 2
	 if {$fitureybradley} { incr i 2 }
      }
      

      puts "iparam=[array get iparam]"
      puts "ivparam=[array get ivparam]"

      lappend simplexp $params

      # We must prepare N+1 vertices for the simplex.
      # This is done by disturbing each coordinate in direction of the estimated effective minimum.
      # I.e. we choose vertices that are half way from the current parameters 
      # towards the estimated optimum of each value.
      variable dx0list 
      variable dklist  
      set vertex 0
      foreach p $params {
	 foreach {i j} [split [lindex $ivparam($vertex) 0] ","] {}
	 switch $j { 
	    0  { set d [lindex $dklist $i] }
	    1  { set d [lindex $dx0list $i] }
	    2  { set d 3.0 }
	    3  { set d 1.0 }
	 }
#	 set p [lindex $zmat [expr {$i+1}] 4 $j]
# 	 if {![llength $p] && $j>=2} {
# 	    # If Urey-Bradley paramns weren't initialized we must do so.
# 	    switch $j {
# 	       2 { 
# 		  # Initialize Kub with 0.0
# 		  set p 0.0
# 	       }
# 	       3 { 
# 		  # Initialize s0 with current dist 
# 		  foreach {ind0 ind1 ind2} [lindex $zmat [expr {$i+1}] 2] {}
# 		  variable ::Paratool::molidbase
# 		  set sel [atomselect $molidbase "index $ind0 $ind2"]
# 		  set coor1 [lindex [$sel get {x y z}] 0]
# 		  set coor2 [lindex [$sel get {x y z}] 1]
# 		  set p [veclength [vecsub $coor1 $coor2]]
# 	       }
# 	    }
# 	 }
	 puts "$vertex: $i,$j  [expr {$p + 0.5*$d}]"
	 lset params $vertex [expr {$p + 0.5*$d}]
	 lappend simplexp $params
	 incr vertex
      }
      set simplexp $simplexp



      # Do the multidimensional optimization
      variable debug
      variable maxiter
      variable optmethod
      variable rtol
      set ndim [llength $selintcoorlist]
      for {set c 0} {$c<$ndim} {incr c} { lappend pbounds {0.0 {}} }
      set opt [optimization -$optmethod -tol $rtol -function ::Paratool::Refinement::parameter_error]
      $opt configure -debug $debug -iter [expr {$maxiter*$ndim}] -miny [expr {$ndim*0.1}]
      $opt configure -simplex $simplexp -pbounds $pbounds -T 8.0 -Tsteps 3 -Texp 1
      foreach {plist ylist} [$opt start] {}

      set params $plist
      if {[$opt success]} {
	 puts "Refinement sucessful after [$opt numiter] steps."
      } else {
	 puts "Refinement not converged in [$opt numiter] steps."
      }

      puts "LOG [$opt log]"
      $opt analyze
      $opt quit


      update_selected_fc -format
      ::Paratool::update_intcoorlist

      # Update the refinement GUI
      update_paramlist
      return
   }

   # Single coordinate refinement including plot
   # -------------------------------------------

   # Scan potential of single selected coordinate
   foreach {xlist tylist izmat energies plothandle} [::Paratool::fofi_potential_scan -plot] {}

   variable ::Paratool::zmat
   set entry [lindex $zmat $izmat]
   set type  [lindex $entry 1]

   set conf  {}; # bond, angle, dihed or imprp energy
   set nonb  {}; 
   set total {}
   set diff  {}; # difference between ideal harmonic and real nonb energy, i.e the ideal bonded energy
   foreach energy $energies ty $tylist {
      if {$type=="bond"} {
	 set c [lindex $energy 2]
      } elseif {[regexp "angle|lbend" $type]} {
	 set c [lindex $energy 3]
      } elseif {$type=="dihed"} {
	 set c [lindex $energy 4]
      } elseif {$type=="imprp"} {
	 set c [lindex $energy 5]
      }
      lappend conf $c
      lappend nonb    [lindex $energy 9]
      lappend nonbinv [expr {-[lindex $energy 9]}]
      lappend total   [lindex $energy 10]
      #set bonded [expr [lindex $energy 8]-$c]

      # Difference between ideal harmonic pot. (target) and total potential without the
      # contribution of the harmonic component of selected bonded interaction.
      # For angles with Urey-Bradley term we must compute UB extra and add it back
      # to the total energy.
      lappend diff    [expr $ty-([lindex $energy 10]-$c)]
   }

   set xdeg $xlist
   set xlabel "bond distance (A)"
   if {[regexp "angle|dihed|imprp" $type]} {
      set xdeg {}
      foreach coor $xlist {
	 lappend xdeg [rad2deg $coor]
      }
      set xlabel "angle (deg)"
   }

   variable ::Paratool::molidbase
   variable fitureybradley
   foreach {k x0 kub s0} [lindex $entry 4] {break}
   set typetext $type
   if {[regexp "angle|lbend" $type] && (([llength $kub] && [llength $s0]) || $fitureybradley)} {
      foreach {a0 a1 a2} [lindex $entry 2] {break}
      set sa [atomselect $molidbase "index $a0 $a1"]
      set sb [atomselect $molidbase "index $a2 $a1"]
      set la [veclength [vecsub [lindex [$sa get {x y z}] 0] [lindex [$sa get {x y z}] 1]]]
      set lb [veclength [vecsub [lindex [$sb get {x y z}] 0] [lindex [$sb get {x y z}] 1]]]
      if {!$fitureybradley} {
	 # If we are not fitting UB we subtract it again from diff
	 set yub [::Paratool::generate_ureybradley_potential $xdeg $kub $s0 $la $lb]
	 set diff [vecsub $diff $yub]
	 set typetext harmonic$type
      } else {
	 # If we are not fitting harmonic angle we subtract it again from diff
	 set yharm [::Paratool::generate_harmonic_potential_deg $type $k $x0 $xdeg]
	 set diff [vecsub $diff $yharm]
	 set typetext ureybradley
      }
   }

   set izero [expr {[llength $xdeg]/2}]
   set newdiff  [::Paratool::shift_data $diff -izero $izero]
   $plothandle add $xdeg $newdiff -lines -linecolor orange -linewidth 4 -legend "target-(total-$typetext)"
   $plothandle configure -title "Refine $type [lindex $entry 0]" -xlabel $xlabel

   set min [format "%.4f" [lindex [lsort -real $xdeg] 0]]
   set max [format "%.4f" [lindex [lsort -real $xdeg] end]]
   set range [expr $max-$min]
   #foreach {x0 k} [get_targets] {}
   set k  [expr $k];  # removes possible braces
   set x0 [expr $x0]; # removes possible braces
   if {[regexp "angle|lbend|dihed|imprp" $type]} {
      #set x0 [deg2rad $x0]
   }

   # Perform the fit using gnuplot
   if {$fitureybradley && [regexp "angle|lbend" $type]} {
      # Prepare fit target for gnuplot
      #set newnonbinv  [::Paratool::shift_data $nonbinv -miny 0.0]
      set maxdist [expr {abs($max-$x0)}]
      set fid [open paratool_fit.dat w]
      foreach X $xdeg Y [::Paratool::shift_data $nonbinv -miny 0.0] {
	 set dist [expr {abs($X-$x0)}]
	 set weight 1.0
	 if {$dist>[expr {$range/32.0}]} {
	    # Introduce a strong bias on the weights for the center
	    # This makes us less dependent on nonlinear contributions
	    # which play a bigger role the further we are from the center.
	    set weight [expr {1+8.0*($dist-$range/32.0)/$maxdist}]
	 }
	 puts $fid [format "%10f %10f %10f" $X $Y $weight]
      }
      close $fid

      #foreach {a0 a1 a2} [lindex $entry 2] {break}
      #set sa [atomselect $molidbase "index $a0 $a1"]
      #set sb [atomselect $molidbase "index $a2 $a1"]
      #set la [veclength [vecsub [lindex [$sa get {x y z}] 0] [lindex [$sa get {x y z}] 1]]]
      #set lb [veclength [vecsub [lindex [$sb get {x y z}] 0] [lindex [$sb get {x y z}] 1]]]
      #foreach {q q kub s0} [lindex $entry 4] {break}
      if {![llength $kub]} { set kub 1.0 }
      if {![llength $s0]}  { set s0  [::Paratool::Energy::compute_ureybradley_x2s $x0 $la $lb] }
      set newparams [fit_ureybradley_potential paratool_fit.dat $kub $s0 $la $lb $min $max]
#      set newparams [fit_potential paratool_fit.dat $k $x0 $kub $s0 $la $lb $min $max]
      set newkub [lindex $newparams 0]
      set news0  [lindex $newparams 1]
   } else {
      # Prepare fit target for gnuplot
      set maxdist [expr abs($max-$x0)]
      set fid [open paratool_fit.dat w]
      # When we are fitting the data to the function f(x)=k*(x-x0)**2 there is
      # the problem that the result strongly depends on where we choose the zero
      # for our dataset. Actually one might think introducing an additional
      # parameter 'a'(f(x)=a+k(x-x0)**2) makes the fit independent of y-offset of
      # the dataset but it turns out that gnuplot bails out after fitting due to 
      # some singular matrix inversion problem. Instead a proper choice for the
      # offset (always worked in my test cases) is to just shift so that the lowest
      # value is at zero.
      foreach X $xdeg Y [::Paratool::shift_data $newdiff -miny 0.0] {
	 set dist [expr {abs($X-$x0)}]
	 set weight 1.0
	 if {$dist>$range/32.0} {
	    # Introduce a strong bias on the weights for the center
	    # This makes us less dependent on nonlinear contributions
	    # which play a bigger role the further we are from the center.
	    set weight [expr {1+8.0*($dist-$range/32.0)/$maxdist}]
	 }
	 puts $fid [format "%10f %10f %10f" $X $Y $weight]
      }
      close $fid

      set newparams [fit_harmonic_potential paratool_fit.dat $k $x0 $min $max $type]
      set newk  [lindex $newparams 0]
      set newx0 [lindex $newparams 1]
   }

   set yfit {}
   set newtotal {}
   set newfcvalub 0.0
#    foreach X $xlist t $total c $conf {
#       if {$fitureybradley && [regexp "angle|lbend" $type]} {
# 	 set newfcvalub [::Paratool::Energy::compute_ureybradley_x [rad2deg $X] $newkub $news0 $la $lb]
# 	 set newfcvalharm [expr {$k*pow(($X-$x0), 2)}]
#       } else {
# 	 set newfcvalharm [expr {$newk*pow(($X-$newx0), 2)}]
#       }
#       lappend yfit [expr {$newfcvalharm+$newfcvalub}]
#       lappend newtotal [expr {$t-$c+$newfcvalharm+$newfcvalub}]
#       puts "total=$t; c=$c"
#    }

   if {[regexp "angle|lbend" $type] && $fitureybradley} {
      set yharm [::Paratool::generate_harmonic_potential_deg $type $k $x0 $xdeg]
      set yub [::Paratool::generate_ureybradley_potential $xdeg $newkub $news0 $la $lb]
      set yfit [vecadd $yharm $yub]
   } elseif {[regexp "angle|lbend" $type] && !$fitureybradley} {
      set yfit [::Paratool::generate_harmonic_potential_deg $type $newk $newx0 $xdeg]
      if {[llength $kub] && [llength $s0]} {
	 set yub [::Paratool::generate_ureybradley_potential $xdeg $kub $s0 $la $lb]
	 set yfit [vecadd $yfit $yub]
      }
   } else {
      set yfit [::Paratool::generate_harmonic_potential_deg $type $newk $newx0 $xdeg]
   }
   set newtotal [vecadd $total [vecinvert $conf] $yfit]

   # Now shift the stuff back so that the center is at zero
   set yfit     [::Paratool::shift_data $yfit -izero $izero]
   set newtotal [::Paratool::shift_data $newtotal -izero $izero]
   $plothandle add $xdeg $yfit     -lines -fillcolor orange -marker circle -radius 3 -legend "refined conformational"
   $plothandle add $xdeg $newtotal -lines -fillcolor blue   -marker circle -radius 3 -legend "refined total"
   $plothandle replot

   if {$fitureybradley && [regexp "angle|lbend" $type]} {
      puts [format "new kub = %7.4f" $newkub]
      puts [format "new s0  = %7.4f" $news0]
      set kx0 [lrange [lindex $entry 4] 0 1]
      #puts "$kx0; $k $x0"
      lset zmat $izmat 4 [concat $kx0 $newkub $news0]
      lset zmat $izmat 5 "[regsub {[QCRMA]} [lindex $zmat $izmat 5] {}]R"
   } else {
      #if {[regexp "angle|dihed|imprp" $type]} {
	# set newx0 [rad2deg $newx0]
      #}
      puts [format "new k = %7.4f" $newk]
      puts [format "new x0 = %7.4f" $newx0]
      lset zmat $izmat 4 0 $newk
      lset zmat $izmat 4 1 $newx0
      lset zmat $izmat 5 "[regsub {[QCRMA]} [lindex $zmat $izmat 5] {}]R"
   }
   ::Paratool::update_zmat

   foreach {d1 kefflist x0efflist} [::Paratool::Energy::compute_derivatives $selintcoorlist] {}
   variable dx0list 
   variable dklist  
   variable targetx0list
   variable targetklist
   set i 0
   foreach selintcoor $selintcoorlist {
      set dx0 [expr [lindex $targetx0list $selintcoor]-[lindex $x0efflist $i]]
      set dk  [expr [lindex $targetklist  $selintcoor]-[lindex $kefflist  $i]]
      lset dx0list $selintcoor $dx0
      lset dklist  $selintcoor $dk
   }
   # Update the refinement GUI
   update_paramlist
}


proc ::Paratool::Refinement::fit_potential { datafile k x0 kub s0 la lb min max type } {
   set fid [open paratool_fit.gp w]
   puts $fid "set print \"paratool_fit.log\""
   puts $fid "set autoscale"
   puts $fid "FIT_LIMIT   = 1e-7"
   puts $fid "FIT_MAXITER = 1000"
   puts $fid "k = $k"
   puts $fid "x0 = $x0"
   if {[regexp "angle|lbend" $type]} {
      puts $fid "deg2rad = 0.0174532925199"
      if {[llength $kub] && [llength $s0]} {
	 puts $fid "kub = $kub"
	 puts $fid "s0 = $s0"
	 puts $fid "la = $la"
	 puts $fid "lb = $lb"
	 puts $fid "g(x) = kub*(sqrt(la**2 - 2.0*la*lb*cos(x*deg2rad) + lb**2)-s0)**2"
	 puts $fid "f(x) = k*(deg2rad*(x-x0))**2 + g(x)"
	 puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via k,kub,s0"
	 puts $fid "print \"<Paratool> k   = \", k"
	 puts $fid "print \"<Paratool> kub = \", kub"
	 puts $fid "print \"<Paratool> s0  = \", s0"
      } else {
	 puts $fid "f(x) = k*(deg2rad*(x-x0))**2"
	 puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via k,x0"
	 puts $fid "print \"<Paratool> k  = \", k"
	 puts $fid "print \"<Paratool> x0 = \", x0"
      }
   } else {
      puts $fid "f(x) = k*(x-x0)**2"
      puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via k,x0"
      puts $fid "print \"<Paratool> k  = \", k"
      puts $fid "print \"<Paratool> x0 = \", x0"
   }
   puts $fid "#print z, f(25)"
   puts $fid "#plot '$datafile'"
   puts $fid "#replot f(x)"
   puts $fid "#replot"
   close $fid

   set gnuplotcmd [::ExecTool::find -interactive \
      -description "Gnuplot (used for nonlinear fitting)" \
      -path [file join /usr/local/bin/gnuplot] gnuplot]

   set fitlog [exec -- $gnuplotcmd paratool_fit.gp >& fit.log]

   set newk  {}
   set newx0 {}
   set fid [open paratool_fit.log]
   while {![eof $fid]} {
      set line [gets $fid]
      if {[lindex $line 0]=="<Paratool>"} {
	 if {[lindex $line 1]=="k"}  { set newk  [lindex $line 3] }
	 if {[lindex $line 1]=="x0"} { set newx0 [lindex $line 3] }
      }
   }
   close $fid
   return [list $newk $newx0]
}

proc ::Paratool::Refinement::fit_harmonic_potential { datafile k x0 min max type } {
   set fid [open paratool_fit.gp w]
   puts $fid "set print \"paratool_fit.log\""
   puts $fid "set autoscale"
   puts $fid "k = $k"
   puts $fid "x0 = $x0"
   if {[regexp "angle|lbend" $type]} {
      puts $fid "deg2rad = 0.0174532925199"
      puts $fid "f(x) = k*(deg2rad*(x-x0))**2"
   } else {
      puts $fid "f(x) = k*(x-x0)**2"
   }
   puts $fid "FIT_LIMIT   = 1e-7"
   puts $fid "FIT_MAXITER = 1000"
   puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via k,x0"
   puts $fid "#print z, f(25)"
   puts $fid "plot '$datafile'"
   puts $fid "replot f(x)"
   puts $fid "replot"
   puts $fid "print \"<Paratool> k  = \", k"
   puts $fid "print \"<Paratool> x0 = \", x0"
   close $fid

   set gnuplotcmd [::ExecTool::find -interactive \
      -description "Gnuplot (used for nonlinear fitting)" \
      -path [file join /usr/local/bin/gnuplot] gnuplot]

   set fitlog [exec -- $gnuplotcmd paratool_fit.gp >& fit.log]

   set newk  {}
   set newx0 {}
   set fid [open paratool_fit.log]
   while {![eof $fid]} {
      set line [gets $fid]
      if {[lindex $line 0]=="<Paratool>"} {
	 if {[lindex $line 1]=="k"}  { set newk  [lindex $line 3] }
	 if {[lindex $line 1]=="x0"} { set newx0 [lindex $line 3] }
      }
   }
   close $fid
   return [list $newk $newx0]
}


################################################################
# Fit a urey Bradley term to the nonbonded potential.          #
################################################################

proc ::Paratool::Refinement::fit_ureybradley_potential { datafile kub s0 la lb min max } {
   set fid [open paratool_fit.gp w]
   puts $fid "set print \"paratool_fit.log\""
   puts $fid "set autoscale"
   puts $fid "kub = $kub"
   puts $fid "s0 = $s0"
   puts $fid "la = $la"
   puts $fid "lb = $lb"
   puts $fid "deg2rad =  0.0174532925199"
   puts $fid "f(x) = kub*(sqrt(la**2 - 2.0*la*lb*cos(x*deg2rad) + lb**2)-s0)**2"
   puts $fid "FIT_LIMIT   = 1e-7"
   puts $fid "FIT_MAXITER = 1000"
   puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via kub,s0"
   puts $fid "#print z, f(25)"
   puts $fid "#plot '$datafile'"
   puts $fid "#replot f(x)"
   puts $fid "#replot"
   puts $fid "print \"<Paratool> kub  = \", kub"
   puts $fid "print \"<Paratool> s0 = \", s0"
   close $fid

   set gnuplotcmd [::ExecTool::find -interactive \
      -description "Gnuplot (used for nonlinear fitting)" \
      -path [file join /usr/local/bin/gnuplot] gnuplot]

   set fitlog [exec -- $gnuplotcmd paratool_fit.gp >& fit.log]

   set newkub {}
   set news0  {}
   set fid [open paratool_fit.log]
   while {![eof $fid]} {
      set line [gets $fid]
      if {[lindex $line 0]=="<Paratool>"} {
	 if {[lindex $line 1]=="kub"} { set newkub [lindex $line 3] }
	 if {[lindex $line 1]=="s0"}  { set news0  [lindex $line 3] }
      }
   }
   close $fid
   return [list $newkub $news0]
}

################################################################
# Fit a Lennard-Jones term to the nonbonded potential.         #
################################################################

proc ::Paratool::Refinement::fit_lennardjones_potential { datafile rmin eps min max } {
   set fid [open paratool_fit.gp w]
   puts $fid "set print \"paratool_fit.log\""
   puts $fid "set autoscale"
   puts $fid "rmin = $rmin"
   puts $fid "eps = $eps"
   puts $fid "f(x) = eps*((rmin/x)**12 - 2.0*(rmin/x)**6)"
   puts $fid "FIT_LIMIT   = 1e-7"
   puts $fid "FIT_MAXITER = 1000"
   puts $fid "fit \[$min:$max\] f(x) 'paratool_fit.dat' using 1:2:3 via rmin,eps"
   puts $fid "#print z, f(25)"
   puts $fid "#plot '$datafile'"
   puts $fid "#replot f(x)"
   puts $fid "#replot"
   puts $fid "print \"<Paratool> rmin = \", rmin"
   puts $fid "print \"<Paratool> eps  = \", eps"
   close $fid

   set gnuplotcmd [::ExecTool::find -interactive \
      -description "Gnuplot (used for nonlinear fitting)" \
      -path [file join /usr/local/bin/gnuplot] gnuplot]

   set fitlog [exec -- $gnuplotcmd paratool_fit.gp >& fit.log]

   set newrmin {}
   set neweps  {}
   set fid [open paratool_fit.log]
   while {![eof $fid]} {
      set line [gets $fid]
      if {[lindex $line 0]=="<Paratool>"} {
	 if {[lindex $line 1]=="rmin"} { set newrmin [lindex $line 3] }
	 if {[lindex $line 1]=="eps"}  { set neweps  [lindex $line 3] }
      }
   }
   close $fid
   return [list $newrmin $neweps]
}


proc ::Paratool::Refinement::nonb_gui { } {

   # If already initialized, just turn on
   if { [winfo exists .paratool_nonb_refinement] } {
      set geom [winfo geometry .paratool_nonb_refinement]
      wm withdraw  .paratool_nonb_refinement
      wm deiconify .paratool_nonb_refinement
      wm geometry  .paratool_nonb_refinement $geom
      focus .paratool_nonb_refinement

      update_paramlist
      return
   }

   variable ::Paratool::selectcolor
   variable ::Paratool::fixedfont
   set v [toplevel ".paratool_nonb_refinement"]
   wm title $v "Refinement of VDW interactions"
   wm resizable $v 0 0

   label $v.info -wraplength 11c -text "Refinement tries to tune the VDW parameters of the selected VDW 1-4 pair\
 so that the minimum of the nonbonded function for this pair equals the equilibrium distance and that the\
 second derivative at this point matches the value from the Hessian. Refinement is only possible if not both\
 types come from the existing force field."

   labelframe $v.nonb -bd 2 -relief ridge -text "List of 1-4 interactions" -padx 2m -pady 2m
   label $v.nonb.format -font $fixedfont -text [format "%-10s %6s %6s %8s %8s %8s  %8s %8s %8s %7s" {  Names} R R0 Evdw Eelec Enonb Fvdw Felec Fnonb Refine] \
      -relief flat -bd 2 -justify left;

   frame $v.nonb.list
   scrollbar $v.nonb.list.scroll -command "$v.nonb.list.list yview"
   listbox $v.nonb.list.list -activestyle dotbox -yscroll "$v.nonb.list.scroll set" -font $fixedfont \
      -width 89 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::Refinement::onefourenergyforcelist
   pack $v.nonb.list.list    -side left -fill both -expand 1
   pack $v.nonb.list.scroll  -side left -fill y -expand 1
 
   pack $v.nonb.format  -anchor w
   pack $v.nonb.list    -expand 1 -fill both -anchor w

   label $v.nonb.atomformat  -font $fixedfont -text [format "%4s %4s %8s %8s %8s %8s %9s" Name Type VDWrmin VDWeps VDWrmin14 VDWeps14 KnownType]
   label $v.nonb.atom1 -font $fixedfont -textvariable ::Paratool::Refinement::curatom1
   label $v.nonb.atom2 -font $fixedfont -textvariable ::Paratool::Refinement::curatom2
   
   pack $v.nonb.atomformat -anchor w
   pack $v.nonb.atom1    -anchor w
   pack $v.nonb.atom2    -anchor w

   pack $v.info
   pack $v.nonb  -padx 1m -pady 1m -fill both -expand 1 

   frame  $v.buttons
   button $v.buttons.nonb -text "Refine 1-4 VDW parameters" \
      -command ::Paratool::Refinement::refine_14_nonb

   pack $v.buttons.nonb -side left
   pack $v.buttons

   bind $v.nonb.list.list <<ListboxSelect>> {
      ::Paratool::Refinement::select14
   }

   ::Paratool::Energy::update_14_list
   variable onefourenergyforcelist [::Paratool::Energy::get_formatted_14_interactions]
   select14 0
}

proc ::Paratool::Refinement::select14 { {cursel {}} } {
   # Highlight the atoms
   if {![llength $cursel]} {
      if {![winfo exists .paratool_nonb_refinement]} {
	 return
      }
      set cursel [.paratool_nonb_refinement.nonb.list.list curselection]
      if {![llength $cursel]} { return }
   }
   set onefour [lindex $::Paratool::Energy::onefourinter $cursel]

   foreach {ind1 ind2 name1 name2} [lrange $onefour 0 3] {}
   ::Paratool::select_atoms [list $ind1 $ind2]
   set vdweps1   [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWeps $ind1]]
   set vdw14eps1 [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWeps14 $ind1]]
   set vdweps2   [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWeps $ind2]]
   set vdw14eps2 [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWeps14 $ind2]]
   set vdwrmin1   [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWrmin $ind1]]
   set vdwrmin2   [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWrmin $ind2]]
   set vdw14rmin1 [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWrmin14 $ind1]]
   set vdw14rmin2 [::Paratool::format_float "%8.3f" [::Paratool::get_atomprop VDWrmin14 $ind2]]
   set knowntype1 [::Paratool::get_atomprop Known $ind1]
   set knowntype2 [::Paratool::get_atomprop Known $ind2]

   set type1  [::Paratool::get_atomprop Type $ind1]
   set type2  [::Paratool::get_atomprop Type $ind2]
   set ::Paratool::Refinement::curatom1 \
      [format "%4s %4s %8s %8s %8s %8s %5s" $name1 $type1 $vdwrmin1 $vdweps1 $vdw14rmin1 $vdw14eps1 $knowntype1]
   set ::Paratool::Refinement::curatom2 \
      [format "%4s %4s %8s %8s %8s %8s %5s" $name2 $type2 $vdwrmin2 $vdweps2 $vdw14rmin2 $vdw14eps2 $knowntype2]

   if {$knowntype1 && $knowntype2} {
      .paratool_nonb_refinement.buttons.nonb configure -state disabled
   } else {
      .paratool_nonb_refinement.buttons.nonb configure -state normal
   }
}


#######################################################################
# Refinement tries to tune the VDW parameters of the selected VDW     #
# 1-4 pair so that the minimum of the nonbonded function for this     #
# pair equals the equilibrium distance and that the second derivative #
# at this point matches the value from the Hessian.                   #
#######################################################################

proc ::Paratool::Refinement::refine_14_nonb { } {
   if {![winfo exists .paratool_nonb_refinement]} { return }
   set cursel [.paratool_nonb_refinement.nonb.list.list curselection]

#   ::Paratool::Energy::update_14_list
   variable ::Paratool::Energy::onefourinter

   set onefour [lindex $onefourinter $cursel]
   foreach {ind1 ind2} [lrange $onefour 0 1] {}

   # Estimate the curvature of the potential
   set ::Paratool::gendepangle 0
   set ::Paratool::gendepdihed 0
   variable ::Paratool::zmat
   variable ::Paratool::zmatqm
   set tmpzmat $zmat
   set tmpzmatqm $zmatqm
   ::Paratool::register_bond [list $ind1 $ind2]
   set ib [expr {[lsearch $zmat "*bond {$ind1 $ind2} *"]-1}]
   set fclist [::Paratool::transform_hessian_cartesian_to_internal -getfc]
   set curve [lindex $fclist $ib]
#error "curve=$curve"
   ::Paratool::select_intcoor $ib
   ::Paratool::del_coordinate
   #set fcorig [::Paratool::transform_hessian_cartesian_to_internal -getfc]
   set zmatqm $tmpzmatqm
   ::Paratool::update_zmat $tmpzmat

   set izmat 1
   set modfc {}
   foreach newfc [lreplace $fclist $ib $ib] entryqm [lrange $zmatqm 1 end] entry [lrange $zmat 1 end] {
      puts $entry
      set fc  [lindex $entryqm 4 0]
      set dfc [expr {$newfc-$fc}]
      set type [lindex $entryqm 1]
      if {$type=="dihed"} {
	 #set n   [lindex $entry 4 1]
	 #set nqm [lindex $entryqm 4 1]
	 #set rawfc    [expr {$newfc*pow($n,2)}]
	 #set rawnewfc [expr {$newfc*pow($n,2)}]
      	 set percent [expr {100.0*($fc-$newfc)/$fc}]
	 puts "[lindex $entry 0] $fc-->$newfc change=$percent%"
      } else {
	 set percent [expr {100.0*($fc-$newfc)/$fc}]
	 puts "[lindex $entry 0] $fc-->$newfc change=$percent%"
      }
      if {$percent>5.0} {
	 if {![regexp {C} [lindex $entry 5]]} {
	    lset zmat $izmat 4 0 $newfc
	    lset zmat $izmat 5 "[regsub -all {[QCRMA]} [lindex $entry 5] {}]R"     
	    lappend modfc [lindex $entry 0] $fc $newfc $dfc R
	 } else {
	    lappend modfc [lindex $entry 0] $fc $newfc $dfc C
	 }
      }
      incr izmat
   }
   lappend modvdw14 [list $ind1 $ind2] $modfc
   ::Paratool::update_zmat

   set q1         [::Paratool::get_complexcharge $ind1]; #[::Paratool::get_atomprop Charge  $ind1]
   set q2         [::Paratool::get_complexcharge $ind2]; #[::Paratool::get_atomprop Charge  $ind2]
   set vdwrmin1   [::Paratool::get_atomprop VDWrmin $ind1]
   set vdweps1    [::Paratool::get_atomprop VDWeps  $ind1]
   set vdw14rmin1 [::Paratool::get_atomprop VDWrmin14 $ind1]
   set vdw14eps1  [::Paratool::get_atomprop VDWeps14  $ind1]
   set vdwrmin2   [::Paratool::get_atomprop VDWrmin $ind2]
   set vdweps2    [::Paratool::get_atomprop VDWeps  $ind2]
   set vdw14rmin2 [::Paratool::get_atomprop VDWrmin14 $ind2]
   set vdw14eps2  [::Paratool::get_atomprop VDWeps14  $ind2]
   if {[llength $vdw14rmin1] && [llength $vdw14eps1] && [llength $vdw14rmin2] && [llength $vdw14eps2]} {
      set vdwrmin1 $vdw14rmin1
      set vdweps1  $vdw14eps1
      set vdwrmin2 $vdw14rmin2
      set vdweps2  $vdw14eps2
   }
   variable ::Paratool::molidbase
   set sel1 [atomselect $molidbase "index $ind1 $ind2"]
   set dist [veclength [vecsub [lindex [$sel1 get {x y z}] 0] [lindex [$sel1 get {x y z}] 1]]]

   set kcalmol 332.0636;
   set h 0.01
   set xlist [list [expr {$dist-$h}] $dist [expr {$dist+$h}]]
   foreach x $xlist {
      lappend elstat [expr {$kcalmol*$q1*$q2/$x}]
   }

   set targetk $curve
   variable nonbfixedfitparams [list $xlist $elstat $targetk]

   set opt [optimization -annealing -function ::Paratool::Refinement::err_vdw]
   $opt configure -T 5.0 -Tsteps 4 -Texp 2 -tol 0.0000001 -iter 500
   $opt configure -bounds [list {0.0 10.0} {-10.0 0.0}]
   $opt initsimplex [list $dist 0.1] ;#[list [expr {$vdwrmin1+$vdwrmin2}] [expr {sqrt($vdweps1*$vdweps2)}]]
   foreach {Reps errnonb} [$opt start] {}
   foreach {R eps} $Reps {}
   puts "R=$R eps=$eps errnonb=$errnonb"

   set Rminold [expr {$vdwrmin1+$vdwrmin2}]
   set epsold  [expr {sqrt($vdweps1*$vdweps2)}]
   set xlist [::Paratool::generate_scan_xlist bond $dist [expr {2.0*0.25}] 50]
   foreach x $xlist {
      set elstat [expr {$kcalmol*$q1*$q2/$x}]
      set term6 [expr {pow($R/$x,6)}]
      set vdw [expr {$eps*($term6*$term6 - 2.0*$term6)}]
      set term6 [expr {pow($Rminold/$x,6)}]
      set vdwold [expr {$epsold*($term6*$term6 - 2.0*$term6)}]
      lappend vdwlist $vdw
      lappend vdwoldlist $vdwold
      lappend eleclist $elstat
      lappend nonb [expr {$vdw+$elstat}]
   }
   set harm [::Paratool::generate_harmonic_potential bond $targetk $dist $xlist]
   set harm [::Paratool::shift_data $harm -miny [lindex $nonb 25]]
   set plothandle [multiplot -title "Nonbonded potential scan" -ysize 400 -xsize 600]
   $plothandle configure -xlabel "distance (A)" -ylabel "E (Kcal/mol)" 
   $plothandle add $xlist $harm -lines -linecolor red  -linewidth 4 -legend [format "harmonic k=%6.4f x0=%6.4f" $targetk $dist]
   $plothandle add $xlist $vdwlist -lines -linecolor cyan -linewidth 2 -legend [format "vdw Rmin=%7.4f eps=%7.4f" $R $eps]
   $plothandle add $xlist $vdwoldlist -lines -linecolor green -linewidth 2 -legend [format "vdwold Rmin=%8.5f eps=%8.5f" $Rminold $epsold]
   $plothandle add $xlist $eleclist -lines -linecolor magenta -linewidth 2 -legend "elstat"
   $plothandle add $xlist $nonb -lines -linecolor blue  -linewidth 2 -legend "nonbonded"
   $plothandle configure -vline [list $dist -dash .]
   $plothandle replot


   if {[::Paratool::get_atomprop Known $ind1] && ![::Paratool::get_atomprop Known $ind2]} {
      # Only atom 1 is known
      if {[llength $vdw14rmin1] && [llength $vdw14eps1]} {
	 set vdw14rmin2 [expr {$R-$vdw14rmin1}]
	 set vdw14eps2  [expr {pow($eps,2)/$vdw14eps1}]
	 ::Paratool::set_atomprop VDWrmin14 $ind2 $vdw14rmin2
	 ::Paratool::set_atomprop VDWeps14  $ind2 $vdw14eps2
      } else {
	 # The known atom has no VDW 1-4 term, the user has to change
	 # that manually in the input parameter file.
	 set type1 [::Paratool::get_atomprop Type $ind1]
	 variable ::Paratool::paramsetlist
	 variable ::Paratool::paramsetfiles
	 foreach paramset $paramsetlist paramfile paramsetfiles {
	    if {[llength [::Pararead::getvdwparam $paramset $type1]]} {
	       break
	    }
	 }
	 set vdw14rmin [expr {$R/2.0}]
	 set vdw14eps  [expr {sqrt($eps)}]
	 puts "Type $type1 from parameter file $paramfile has no VDW 1-4 term." 
	 puts "You must change the following type in your parameter files manually:"
	 puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind1] $vdw14eps]
	 puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind2] $vdw14eps]
	 puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind1] $vdw14rmin]
	 puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind2] $vdw14rmin]
	 puts "Modified internal coordinates:"
	 foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	    puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	 }
      }
   } elseif {![::Paratool::get_atomprop Known $ind1] && [::Paratool::get_atomprop Known $ind2]} {
      # Only atom 2 is known
      if {[llength $vdw14rmin2] && [llength $vdw14eps2]} {
	 set vdw14rmin1 [expr {$R-$vdw14rmin2}]
	 set vdw14eps1  [expr {pow($eps,2)/$vdw14eps2}]
	 ::Paratool::set_atomprop VDWrmin14 $ind1 $vdw14rmin1
	 ::Paratool::set_atomprop VDWeps14  $ind1 $vdw14eps1
      } else {
	 # The known atom has no VDW 1-4 term, the user has to change
	 # that manually in the input parameter file.
	 set type2 [::Paratool::get_atomprop Type $ind2]
	 variable ::Paratool::paramsetlist
	 variable ::Paratool::paramsetfiles
	 foreach paramset $paramsetlist paramfile paramsetfiles {
	    if {[llength [::Pararead::getvdwparam $paramset $type2]]} {
	       break
	    }
	 }
	 set vdw14rmin [expr {$R/2.0}]
	 set vdw14eps  [expr {sqrt($eps)}]
	 puts "Type $type2 from parameter file $paramfile has no VDW 1-4 term." 
	 puts "You must change the following type in your parameter files manually:"
	 puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind1] $vdw14eps]
	 puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind2] $vdw14eps]
	 puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind1] $vdw14rmin]
	 puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind2] $vdw14rmin]
	 puts "Modified internal coordinates:"
	 foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	    puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	 }
      }
   } elseif {![::Paratool::get_atomprop Known $ind1] && ![::Paratool::get_atomprop Known $ind2]} {
      # Both atoms are unknown
      if {[llength $vdw14rmin1] && [llength $vdw14eps1]} {
	 if {[llength $vdw14rmin2] && [llength $vdw14eps2]} {
	    # Both VDW 1-4 params are given
	    set vdw14rmin1 [expr {$R/2.0}]
	    set vdw14eps1  [expr {sqrt($eps)}]
	    set vdw14rmin2 [expr {$R/2.0}]
	    set vdw14eps2  [expr {sqrt($eps)}]
	    ::Paratool::set_atomprop VDWrmin14 $ind1 $vdw14rmin1
	    ::Paratool::set_atomprop VDWeps14  $ind1 $vdw14eps1
	    ::Paratool::set_atomprop VDWrmin14 $ind2 $vdw14rmin2
	    ::Paratool::set_atomprop VDWeps14  $ind2 $vdw14eps2
	 } else {
	    # VDW 1-4 params given only for atom 1
	    set vdw14rmin2 [expr {$R-$vdw14rmin1}]
	    set vdw14eps2  [expr {pow($eps,2)/$vdw14eps1}]
	    ::Paratool::set_atomprop VDWrmin14 $ind2 $vdw14rmin2
	    ::Paratool::set_atomprop VDWeps14  $ind2 $vdw14eps2
	 }
      } else {
	 if {[llength $vdw14rmin2] && [llength $vdw14eps2]} {
	    # VDW 1-4 params given only for atom 2
	    set vdw14rmin1 [expr {$R-$vdw14rmin2}]
	    set vdw14eps1  [expr {pow($eps,2)/$vdw14eps2}]
	    ::Paratool::set_atomprop VDWrmin14 $ind1 $vdw14rmin1
	    ::Paratool::set_atomprop VDWeps14  $ind1 $vdw14eps1
	 } else {
	    # No VDW 1-4 params are given
	    set vdw14rmin1 [expr {$R/2.0}]
	    set vdw14eps1  [expr {sqrt($eps)}]
	    set vdw14rmin2 [expr {$R/2.0}]
	    set vdw14eps2  [expr {sqrt($eps)}]
	    ::Paratool::set_atomprop VDWrmin14 $ind1 $vdw14rmin1
	    ::Paratool::set_atomprop VDWeps14  $ind1 $vdw14eps1
	    ::Paratool::set_atomprop VDWrmin14 $ind2 $vdw14rmin2
	    ::Paratool::set_atomprop VDWeps14  $ind2 $vdw14eps2
	 }
      }
   } else {
      if {[llength $vdw14rmin1] && [llength $vdw14eps1]} {
	 if {![llength $vdw14rmin2] && ![llength $vdw14eps2]} {
	    set vdw14rmin2 [expr {$R-$vdw14rmin1}]
	    set vdw14eps2  [expr {pow($eps,2)/$vdw14eps1}]
	    puts "You must change the following type in your parameter files manually:"
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind2] $vdw14eps2]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind2] $vdw14rmin2]
	    puts "Modified internal coordinates:"
	    foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	       puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	    }
	 } else {
	    # Both VDW 1-4 params are given
	    set vdw14rmin [expr {$R/2.0}]
	    set vdw14eps  [expr {sqrt($eps)}]
	    #puts "Type $type2 from parameter file $paramfile has no VDW 1-4 term." 
	    puts "You must change the following type in your parameter files manually:"
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind1] $vdw14eps]
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind2] $vdw14eps]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind1] $vdw14rmin]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind2] $vdw14rmin]
	    puts "Modified internal coordinates:"
	    foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	       puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	    }
	 }
      } else {
	 if {[llength $vdw14rmin2] && [llength $vdw14eps2]} {
	    # VDW 1-4 params given only for atom 2
	    set vdw14rmin1 [expr {$R-$vdw14rmin2}]
	    set vdw14eps1  [expr {pow($eps,2)/$vdw14eps2}]
	    puts "You must change the following type in your parameter files manually:"
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind1] $vdw14eps1]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind1] $vdw14rmin1]
	    puts "Modified internal coordinates:"
	    foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	       puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	    }
	 } else {
	    # No VDW 1-4 params are given
	    set vdw14rmin [expr {$R/2.0}]
	    set vdw14eps  [expr {sqrt($eps)}]
	    #puts "Type $type2 from parameter file $paramfile has no VDW 1-4 term." 
	    puts "You must change the following type in your parameter files manually:"
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind1] $vdw14eps]
	    puts [format "Type %4s vdw14eps=%6.3f"  [::Paratool::get_atomprop Type $ind2] $vdw14eps]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind1] $vdw14rmin]
	    puts [format "Type %4s vdw14rmin=%6.3f" [::Paratool::get_atomprop Type $ind2] $vdw14rmin]
	    puts "Modified internal coordinates:"
	    foreach {tag k newk dk flag} [lindex $modvdw14 1] {
	       puts [format "%5s k=%.3f newk=%.3f deltak=%.3f %s" $tag $k $newk $dk $flag]
	    }
	 }
      }

   }

   variable onefourenergyforcelist [::Paratool::Energy::get_formatted_14_interactions]
   .paratool_nonb_refinement.nonb.list.list selection set $cursel
   select14 $cursel
}


###########################################################
# Error function for the optimization of VDW parameters   #
# Rmin and eps.                                           #
###########################################################

proc ::Paratool::Refinement::err_vdw { Reps } {
   variable nonbfixedfitparams
   foreach {R eps} $Reps {}
   foreach {xlist elstat targetk} $nonbfixedfitparams {}
   set R0 [lindex $xlist 1]

   foreach x $xlist {
      set term6 [expr {pow($R/$x,6)}]
      lappend vdw [expr {$eps*($term6*$term6 - 2.0*$term6)}]
   }
   set nonb [vecadd $vdw $elstat]

   foreach {Elower Ecenter Eupper} $nonb {break}
   foreach {x0 x1 x2} $xlist {break}
   set h [expr {abs($x1-$x0)}]

   # First derivative f'(x) = (f(x+h) - f(x-h))/2h
   lappend deriv1 [expr {($Eupper-$Elower)/(2.0*$h)}]

   # Force constant f''(x)/2 = 0.5*(f(x-h) - 2f(x) + f(x+h))/h^2
   set effk [expr {0.5*($Elower - 2.0*$Ecenter + $Eupper)/pow($h,2)}]

   # Estimated effective minimum
   set effx0 [::Paratool::Energy::parabolic_extrapolation $x0 $x1 $x2 $Elower $Ecenter $Eupper]
   #puts "[expr {pow($deriv1,4)}], [expr {pow($effx0-$x1,4)}], [expr {0.0005*pow($effk-$targetk,2)}], [expr {0.2*pow($R-$R0,2)}] [expr {0.1*abs($eps)}]"
   # We optimizing eeffectice k and x0, the derivative and we are also adding a term 
   # that favours parameters where R is closer to the equilibrium value R0.
   set err [expr {10*pow($deriv1,4) + pow($effx0-$x1,4) + 0.001*pow($effk-$targetk,2) + 0.2*pow($R-$R0,2) + 0.1*pow($eps,2)}]

   return $err
}
