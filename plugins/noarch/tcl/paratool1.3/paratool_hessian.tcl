namespace eval ::Paratool::Hessian {
   proc initialize {} {
      variable bgcolor
      variable canvas .paratool_hessian.c
      variable marklineardep 1
      variable markchemcoupled 1
      variable largecoupling 5
      variable selectedhess {}
      variable hesscursor   {}
      if {[info exists tk_version] && [winfo exists .paratool_hessian]} { destroy .paratool_hessian}
   }
   initialize
}

proc ::Paratool::Hessian::gui { } {

   # If already initialized, just turn on
   if { [winfo exists .paratool_hessian] } {
      set geom [winfo geometry .paratool_hessian]
      wm withdraw  .paratool_hessian
      wm deiconify .paratool_hessian
      wm geometry  .paratool_hessian $geom
      focus .paratool_hessian
      return
   }

   variable ::Paratool::zmat
   variable ::Paratool::inthessian_kcal
   if {[llength $zmat]<=2 || [llength $inthessian_kcal]==0} { return }

   variable ::Paratool::selectcolor
   set v [toplevel ".paratool_hessian"]
   wm title $v "Hessian in internal coordinates"
   wm resizable $v 1 1

   label $v.info -wraplength 11c -text "Refinement tries to tune the parameters x0 and k so that the effective x0 and k \
which include the nonbonded contributions match the target parameters as close as possible."
   labelframe $v.types -bd 2 -relief ridge -text "List of coordinates for parameter refinement" -padx 2m -pady 2m
   label $v.click -text "Click on the entries to highlight the corresponding internal coordinates"
   pack $v.click

   variable canvas $v.c
   frame $v.grid
   scrollbar $v.hscroll -orient horiz -command "$canvas xview"
   scrollbar $v.vscroll -command "$canvas yview"
   canvas $canvas -relief sunken -borderwidth 2  \
      -xscrollcommand "$v.hscroll set" \
      -yscrollcommand "$v.vscroll set"
   pack $v.grid -expand yes -fill both -padx 1 -pady 1
   grid rowconfig    $v.grid 0 -weight 1 -minsize 0
   grid columnconfig $v.grid 0 -weight 1 -minsize 0
   
   grid $canvas -padx 1 -in $v.grid -pady 1 \
      -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
   grid $v.vscroll -in $v.grid -padx 1 -pady 1 \
      -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
   grid $v.hscroll -in $v.grid -padx 1 -pady 1 \
      -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news

   update_canvas

#    frame $v.cursor
#    label $v.cursor.label1 -text "Current entry: "
#    label $v.cursor.label2 -textvariable ::Paratool::Hessian::hesscursor -bg chartreuse -width 12
#    pack $v.cursor.label1 $v.cursor.label2 -side left
#    pack $v.cursor

   frame $v.select
   label $v.select.clabel1 -text "Current entry: "
   label $v.select.clabel2 -textvariable ::Paratool::Hessian::hesscursor -bg chartreuse -width 12
   label $v.select.slabel1 -text "       Selected entry: "
   label $v.select.slabel2 -textvariable ::Paratool::Hessian::selectedhess -bg orange -width 12
   pack $v.select.clabel1 $v.select.clabel2 $v.select.slabel1 $v.select.slabel2 -side left
   pack $v.select

   checkbutton $v.lindep -text "Highlight all linear dependent entries" -bg khaki \
      -variable ::Paratool::Hessian::marklineardep -command ::Paratool::Hessian::mark_all_linear_dependent_intcoor
   pack $v.lindep

   frame  $v.check
   checkbutton $v.check.chemcoupled -text "Highlight all chemically coupled entries. Show couplings >" -bg pink \
      -variable ::Paratool::Hessian::markchemcoupled -command ::Paratool::Hessian::mark_all_chem_coupled_intcoor
   label $v.check.spinlabel -text "% of force constants"
   spinbox $v.check.spin -from 0 -to 100 -increment 1 -width 3 \
      -textvariable ::Paratool::Hessian::largecoupling -command ::Paratool::Hessian::mark_all_chem_coupled_intcoor
   pack $v.check.chemcoupled $v.check.spin $v.check.spinlabel -anchor w -side left
   pack $v.check
}

proc ::Paratool::Hessian::update_canvas {} {
   if {![winfo exists .paratool_hessian]} { return }
   set c .paratool_hessian.c
   $c delete all
   variable ::Paratool::zmat
   variable ::Paratool::inthessian_kcal
   
   # Measure the size of one matrix entry in the canvas
   set item [$c create text 0 0 -text 12345.1234 -anchor nw]
   set bbox [$c bbox $item]
   set labelheight [expr {int(1.0*([lindex $bbox 3]-[lindex $bbox 1]))}]
   set labelwidth  [expr {([lindex $bbox 2]-[lindex $bbox 0])}]
   puts "labelheight=$labelheight"
   $c delete $item

   set dimy [llength $inthessian_kcal]
   set dimx [llength [lindex $inthessian_kcal end]]
   $c configure -scrollregion [list [expr {-0.5*$labelwidth}] -$labelheight [expr {($dimx+0.5)*$labelwidth}] [expr {($dimy+1.5)*$labelheight}]]

   set x 0
   set y [expr {-$labelheight}]
   set i 1
   foreach entry [lrange $zmat 1 end] {
      $c create text [expr {$x+$labelwidth}] $y -text "[lindex $entry 0] " \
	 -anchor ne -justify right -tags [list label $i $i]
      $c create text [expr {$x+$labelwidth}] [expr {$dimy*$labelheight}] -text "[lindex $entry 0] " \
	 -anchor ne -justify right -tags [list label $i $dimy]
      incr x $labelwidth
      incr y $labelheight
   }
   variable bgcolor [lindex [$c config -bg] 4]
   set y 0
   set i 1
   foreach row $inthessian_kcal entry [lrange $zmat 1 end] {
      set x 0
      set j 1
      $c create text 0 [expr {$y}] -text "[lindex $entry 0] " \
	 -anchor ne -justify right -tags [list label $i $j] 
      foreach fc [lrange $row 0 [expr {$i-1}]] {
	 $c create rect ${x} ${y} [expr {$x+$labelwidth}] [expr {$y+$labelheight}] \
	    -outline grey -fill $bgcolor -tags [list rect row$i col$j]
	 $c create text [expr {$x+$labelwidth}] $y -text "$fc " \
	    -anchor ne -justify right -tags [list text row$i col$j] 
	 incr x $labelwidth
	 incr j
      }
      incr y $labelheight
      incr i
   }
   $c xview moveto 0
   $c yview moveto 0

   $c bind all <Any-Enter> "::Paratool::Hessian::enter_item"
   $c bind all <Any-Leave> "::Paratool::Hessian::leave_item"
   $c bind all <1> "::Paratool::Hessian::select_item"
   bind $c <2> "$c scan mark %x %y"
   bind $c <B2-Motion> "$c scan dragto %x %y"

   mark_all_linear_dependent_intcoor
   mark_all_chem_coupled_intcoor
}


proc ::Paratool::Hessian::enter_item {} {
   variable canvas
   variable bgcolor
   set id [$canvas find withtag current]
   if {[lsearch [$canvas gettags current] text] >= 0} {
      set id [$canvas find below current]
   } elseif {[lsearch [$canvas gettags current] label] >= 0} {
      return
   }
   set row [regsub row [lsearch -inline [$canvas gettags $id] "row*"] {}]
   set col [regsub col [lsearch -inline [$canvas gettags $id] "col*"] {}]
   variable ::Paratool::zmat
   variable hesscursor "[lindex $zmat $row 0] - [lindex $zmat $col 0]"
   $canvas itemconfigure $id -fill chartreuse
}

proc ::Paratool::Hessian::leave_item {} {
   variable canvas
   variable bgcolor
   set id [$canvas find withtag current]
   if {[lsearch [$canvas gettags current] text] >= 0} {
      set id [$canvas find below current]
   } elseif {[lsearch [$canvas gettags current] label] >= 0} {
      return
   }

   if {[lsearch -regexp [$canvas gettags $id] selected] < 0} {
      if {[lsearch [$canvas gettags $id] lindep] >= 0} {
	 $canvas itemconfigure "$id" -fill yellow
      } elseif {[lsearch [$canvas gettags $id] lindepall] >= 0} {
	 $canvas itemconfigure "$id" -fill khaki
      } elseif {[lsearch [$canvas gettags $id] coupled] >= 0} {
	 $canvas itemconfigure "$id" -fill pink
      } else {
	 $canvas itemconfigure "$id" -fill $bgcolor
      }
   } else {
      $canvas itemconfigure $id -fill orange
   }
   variable hesscursor ""
}


proc ::Paratool::Hessian::select_item { {intcoorlist {}} } {
   variable canvas
   if {![winfo exists $canvas]} { return }
   if {[llength $intcoorlist]} {
      set intcoor [expr {[lindex $intcoorlist 0]+1}]
      set id [$canvas find withtag row${intcoor}&&col${intcoor}&&rect]
      foreach {xmin ymin xmax ymax} [$canvas coords $id] {}
      foreach {w h} [lrange [$canvas cget -scrollregion] 2 3] {break}
      foreach {xvmin xvmax} [$canvas xview] {}
      foreach {yvmin yvmax} [$canvas yview] {}
      if {$xmin/$w<$xvmin || $xmax/$w>$xvmax} {
	 $canvas xview moveto [expr {$xmin/$w-($xvmax-$xvmin)/2.0}]
      }
      if {$ymin/$h<$yvmin || $ymax/$h>$yvmax} {
	 $canvas yview moveto [expr {$ymin/$h-($yvmax-$yvmin)/2.0}]
      }
   } else {
      set id [$canvas find withtag current]
      if {[lsearch [$canvas gettags current] text] >= 0} {
	 set id [$canvas find below current]
      }
   }

   # Unselect previous selected element
   variable bgcolor
   $canvas itemconfigure selected -fill $bgcolor
   $canvas dtag selected selected

   set row [regsub row [lsearch -inline [$canvas gettags $id] "row*"] {}]
   set col [regsub col [lsearch -inline [$canvas gettags $id] "col*"] {}]
   $canvas addtag selected withtag $id

   variable ::Paratool::zmat
   variable selectedhess "[lindex $zmat $row 0] - [lindex $zmat $col 0]"
   variable depcoorlist
   set deplist1 [lindex $depcoorlist [expr {$row-1}]]; #[::Paratool::find_linear_dependent_intcoor $row]
   set deplist2 [lindex $depcoorlist [expr {$col-1}]]; #[::Paratool::find_linear_dependent_intcoor $col]
   set deplist [lsort -unique -integer [lintersect $deplist1 $deplist2]]

   # Unselect previous linear dependent elements
   $canvas itemconfigure lindep -fill $bgcolor
   $canvas dtag lindep lindep

   # Tag all elements belonging to both linear dependent coords and paint then yellow
   set i 0
   foreach rdep $deplist {
      foreach cdep [lrange $deplist 0 $i] {
	 #puts "addtag row$rdep col$cdep"
	 $canvas addtag lindep withtag rect&&row$rdep&&col$cdep
      }
      incr i
   }
   $canvas itemconfigure lindepall -fill khaki
   $canvas itemconfigure lindep -fill yellow
   $canvas itemconfigure coupled&&!lindep&&!lindepall -fill pink

   # Paint the seleted element red
   $canvas itemconfigure $id -fill orange
   
   if {![llength $intcoorlist]} {
      # Select the all linear dependent coords in zmat
      ::Paratool::select_intcoor [list [expr {$row-1}] [expr {$col-1}]]
      if {[winfo exists .paratool_intcoor]} {
	 .paratool_intcoor.zmat.pick.list selection clear 0 end
      }
   }
}

proc ::Paratool::Hessian::find_opposite_angle {izmatlist} {
   variable ::Paratool::zmat
   set opp {}
   foreach izmat $izmatlist {
      set entry [lindex $zmat $izmat]
      set name [lindex $entry 0]
      set indexes [lindex $entry 2]
      switch -glob $name {
	 A* {
	    set left   [lindex $indexes 0]
	    set middle [lindex $indexes 1]
	    set right  [lindex $indexes 2]
	    set poslist [lsearch -all $zmat "A* {* $middle *}"]
	    foreach pos $poslist {
	       set angleind  [lindex $zmat $pos 2]
	       # Don't consider adjacent angles 
	       if {[lindex $angleind 0]==$left || [lindex $angleind 0]==$right ||
		   [lindex $angleind 2]==$left || [lindex $angleind 2]==$right} {
		  continue
	       } 
	       lappend opp $pos
	    }
	 }
      }
   }
   return [lsort -integer -unique [join $opp]]
}

proc ::Paratool::Hessian::mark_all_linear_dependent_intcoor {} {
   variable ::Paratool::zmat
   variable canvas
   variable bgcolor

   # Unselect previous linear dependent elements
   $canvas itemconfigure lindepall -fill $bgcolor
   $canvas dtag lindepall lindepall

   variable marklineardep
   if {!$marklineardep} { return }

   variable depcoorlist
   for {set i 1} {$i<=[llength $zmat]} {incr i} {
      set deplist [lindex $depcoorlist [expr {$i-1}]];# [::Paratool::find_linear_dependent_intcoor $i]
      if {[llength $deplist]<=1} { continue }
      #puts "dep [lindex $zmat $i 0] $deplist"
 
      # Tag all elements belonging to both linear dependent coords and paint them yellow
      foreach rdep $deplist {
	 if {$i>$rdep} { continue }
	 $canvas addtag lindepall withtag col${i}&&row${rdep}&&rect
      }
   }
   $canvas itemconfigure lindepall -fill khaki
   $canvas itemconfigure coupled&&!lindep&&!lindepall -fill pink
   $canvas itemconfigure lindep -fill yellow
}

proc ::Paratool::Hessian::mark_all_chem_coupled_intcoor {} {
   variable canvas
   variable bgcolor
   variable ::Paratool::inthessian_kcal
   variable largecoupling
   variable markchemcoupled

   # Unmark previous chemically coupled elements
   $canvas itemconfigure coupled -fill $bgcolor
   $canvas dtag coupled coupled

   if {!$markchemcoupled} { return }

   set i 0
   foreach row $inthessian_kcal {
      set fcrow [lindex $row $i]
      set j 0
      #puts "chem $fcrow"
      foreach elem [lrange $row 0 $i] {
	 set fccol [lindex $inthessian_kcal $j $j]
	 if {$elem*$elem>pow($largecoupling/100.0,2)*$fcrow*$fccol && $i!=$j} {
	 #puts "$fcrow $fccol"
	    $canvas addtag coupled withtag rect&&row[expr {$i+1}]&&col[expr {$j+1}]
	 }
	 incr j
      }
      incr i
   }
   $canvas itemconfigure lindepall -fill khaki
   $canvas itemconfigure coupled&&!lindep&&!lindepall -fill pink
   $canvas itemconfigure lindep -fill yellow
}

proc ::Paratool::Hessian::compute_force_constants_from_inthessian { args } {
   variable ::Paratool::inthessian_kcal
   variable ::Paratool::zmat
   variable ::Paratool::molidbase
   variable ::Paratool::zmattargetk {}
   variable ::Paratool::Refinement::targetklist {}
   variable ::Paratool::Refinement::targetx0list {}

   variable depcoorlist {}
   set fclist {}
   set intcoorlist {}
   #::Paratool::Refinement::init_paramlist
   variable ::Paratool::Energy::atomtrans
   variable ::Paratool::Energy::postrans
   array unset atomtrans
   array unset postrans
   set sel [atomselect $molidbase all frame last]
   foreach i [$sel get index] xyz [$sel get {x y z}] {
      set atomtrans($i) $i
      set postrans($i) $xyz
   }
   $sel delete

   for {set i 1} {$i<[llength $zmat]} {incr i} {
      #set targetk  [lindex $zmat $i 4 0]
      set targetx0 [lindex $zmat $i 3]

      set entry [lindex $zmat $i]
      set type  [lindex $entry 1]
      set atoms [lindex $entry 2]
      #set x0    [lindex $entry 3]
      set dx    0.1;  # for bonds 0.1 A
      if {[regexp "angle|lbend|dihed" $type]} {
	 set dx 5.0; # for angles 1.0 deg
      }

      set j 0
      foreach index [lindex $entry 2] {
	 set atom($j)  $index
	 set sel [atomselect $molidbase "index $index" frame last]
 	 set pos($j) [join [$sel get {x y z}]]
	 $sel delete
 	 incr j
      }
      
      # Generate two frames that represent a distortion of the current internal coordinate
      # in both directions. Since our set of internal coords is redundant, some coordinates
      # cannot be disturbed without changing other coordinates, too. These coordinates are
      # mutually dependent. We can then use measure $type to determine how much
      # other coordinates have changed with the perturbation. 

      # A general rule which coords are dependently distorted is as follows:
      # Bonds are all independent unless they are part of a ring. In that case everything
      # is kept fixed except the two atoms defining the bond.
      # Consequently the dependent conformations are all neighboring bonds and all angles these
      # atoms are involved in.
      # For angles the dependent coordinates are all other angles centered around the middle
      # atom. In case of a four-valent middle atom, the dihedrals ending in one (and only one)
      # leg of the angle are also dependent.
      # Impropers are always dependent on all angles made from the same atoms and all dihedrals
      # involving the same angles.

      set numframes [molinfo $molidbase get numframes]
      set icenter [expr {$numframes-1}]
      set ilower  [expr {$numframes}]
      set iupper  [expr {$numframes+1}]
      foreach {x h1} [::Paratool::Energy::make_distortion $molidbase $type \
			[array get pos] [array get atom] -dx $dx] {}
      #puts "xh $x $h1; numf=$numframes:[molinfo $molidbase get numframes]"

      set rad2deg 57.2957795131;   # [expr 180.0/3.14159265358979]
      set deg2rad 0.0174532925199; # [expr 3.14159265358979/180.0]

      set depcoor {}
      set energy {0 0 0}
      #set h1 $dx
      if {[regexp "angle|lbend|dihed|imprp" $type]} {
	 set h1 [expr {$deg2rad*$h1}]
      }
      for {set j 1} {$j<[llength $zmat]} {incr j} {
	 # Make sure to fetch kc from lower diagonal
	 if {$i>=$j} {
	    set kc [lindex $inthessian_kcal [expr {$i-1}] [expr {$j-1}]]
	 } else {
	    set kc [lindex $inthessian_kcal [expr {$j-1}] [expr {$i-1}]]
	 }
	 lappend kclist $kc

	 set geom [lindex $zmat $j 1]
	 if {$geom=="lbend"} { set geom "angle" }
	 set xcenter [measure $geom [lindex $zmat $j 2] molid $molidbase frame $icenter]
	 set xupper  [measure $geom [lindex $zmat $j 2] molid $molidbase frame $iupper]

	 if {[regexp "angle|lbend|dihed" $geom]} {
	    if {$xcenter<-90} { set xcenter [expr {$xcenter+360}] }
	    if {$xupper<-90}  { set xupper  [expr {$xupper+360}] }
	 }
	 set h2 [format "%.3f" [expr {($xupper-$xcenter)}]]
	 #if {$i==10} { puts "i=$i j=$j h2=$h2";}
	 #if {$i==2} { puts "[lindex $zmat $j 0]:: xmeasure=$xmeasure; xcenter=$xcenter xupper=$xupper h1=$h1 h2=$h2" }

	 if {abs($h2)<0.01} { continue }
	 if {[regexp "angle|lbend|dihed" $geom]} {
	    if {[format "%.2f" $h2]==180.0} { continue }
	    set h2 [expr {$h2*$deg2rad}]
	 }

	 # Since h2 is nonzero we are in presence of a dependent coordinate.
	 lappend depcoor $j

	 #set e [expr {($kc)*$h1*$h2}]
	 #set energy [vecadd $energy [list $e 0.0 $e]]	 	 
      }

      lappend depcoorlist $depcoor

      # Force constant f''(x)/2 = 0.5*(f(x-h) - 2f(x) + f(x+h))/h^2
      #foreach {Elower Ecenter Eupper} $energy {break}
      #puts " Elower=$Elower; Ecenter=$Ecenter; Eupper=$Eupper"
      #set rawk [expr {0.5*($Elower - 2.0*$Ecenter + $Eupper)/pow($h1,2)}]


      # Actually we want to generate a list of raw FCs and refine and scale them (and periodify the diheds).
      # For now this is ok.
      #lappend fclist $rawk
      lappend fclist [lindex $inthessian_kcal [expr {$i-1}] [expr {$i-1}]]
      #if {$i==26} { puts "[lindex $zmat $i 0]: kc=$kclist; e=$energy rawk=$rawk"; puts $depcoorlist; error "" }

      # Get the coupling constants and compute energies left and right of equilibrium in order
      # to calculate the target potential surface for this motion.
      set energy {0 0 0}
      foreach rdep $depcoor {
	 set geom [lindex $zmat $rdep 1]
	 if {$geom=="lbend"} { set geom "angle" }
	 set xcenter [measure $geom [lindex $zmat $rdep 2] molid $molidbase frame $icenter]
	 set xupper  [measure $geom [lindex $zmat $rdep 2] molid $molidbase frame $iupper]
	 if {$xcenter<-90} { set xcenter [expr {$xcenter+360}] }
	 if {$xupper<-90}  { set xupper  [expr {$xupper+360}] }
	 set h1 [expr {($xupper-$xcenter)}]
	 #puts "[lindex $zmat $rdep 0]:: xmeasure=$xmeasure; xcenter=$xcenter xupper=$xupper h1=$h1"
	 if {[regexp "angle|lbend|dihed" $geom]} {
	    if {[format "%.3f" $h1]==180.0} { continue }
	    set h1 [expr {$deg2rad*$h1}]
	 }
	 if {$h1==0.0} { continue }
	 foreach cdep $depcoor {
	    # Make sure to fetch kc from lower diagonal
	    if {$rdep>=$cdep} {
	       set kc [lindex $inthessian_kcal [expr {$rdep-1}] [expr {$cdep-1}]]
	    } else {
	       set kc [lindex $inthessian_kcal [expr {$cdep-1}] [expr {$rdep-1}]]
	    }

	    if {$kc==0.0} { continue }

	    set geom [lindex $zmat $cdep 1]
	    if {$geom=="lbend"} { set geom "angle" }
	    set xcenter [measure $geom [lindex $zmat $cdep 2] molid $molidbase frame $icenter]
	    set xupper  [measure $geom [lindex $zmat $cdep 2] molid $molidbase frame $iupper]
	    if {$xcenter<-90} { set xcenter [expr {$xcenter+360}] }
	    if {$xupper<-90}  { set xupper  [expr {$xupper+360}] }
	    set h2 [expr {($xupper-$xcenter)}]
	    if {[regexp "angle|lbend|dihed" $geom]} {
	       if {[format "%.3f" $h2]==180.0} { continue }
	       set h2 [expr {$h2*$deg2rad}]
	    }
	    if {$h2==0.0} { continue }

	    set e [expr {($kc)*$h1*$h2}]
	    #set e [::Paratool::generate_harmonic_potential_deg angle [expr {abs($kc)}] 0.0 [list -$h 0 $h]]
	    #set energy [vecadd $energy $e]
	    set energy [vecadd $energy [list $e 0.0 $e]]
	 }
      }

      # Now we can estimate the force constant for this potential by simply taking a numerical
      # derivative. 
      # Force constant f''(x)/2 = 0.5*(f(x-h) - 2f(x) + f(x+h))/h^2
      foreach {Elower Ecenter Eupper} $energy {break}
      #puts " Elower=$Elower; Ecenter=$Ecenter; Eupper=$Eupper"
      set targetk [expr 0.5*($Elower - 2.0*$Ecenter + $Eupper)/pow($dx,2)]
      if {[regexp "angle|lbend|dihed|imprp" $type]} {
	 set targetk [expr pow($rad2deg,2)*$targetk]
      }

      #puts "[lindex $zmat $i 0]: $depcoor; e=$energy targetk=$targetk"

      lappend zmattargetk $targetk
      lappend targetklist $targetk
      lappend targetx0list $targetx0
      lappend intcoorlist [expr {$i-1}]

      # Delete the tmp frames
      animate delete beg $numframes $molidbase ; 
   }


   # Assign new force constants to the internal coordinates in zmat 
   assign_fc_zmat $fclist
   ::Paratool::symmetrize_parameters -all zmatqm
   ::Paratool::assign_unknown_force_constants_from_zmatqm
   ::Paratool::update_zmat

   if {[lsearch $args "-getfc"]>=0} {
      return $fclist
   }

### Commented out to make sitevisit demo work!!!

#    # Compute effective parameters
#    foreach {d1list kefflist x0efflist} [::Paratool::Energy::compute_derivatives $intcoorlist -rebuild] {}

#    # Compute the difference between targets and effective parameters
#    variable ::Paratool::Refinement::dklist {}
#    variable ::Paratool::Refinement::dx0list {}
#    variable ::Paratool::Refinement::effklist $kefflist
#    variable ::Paratool::Refinement::effx0list $x0efflist
#    foreach targetx0 $targetx0list x0eff $x0efflist targetk $targetklist keff $kefflist {
#       set dx0 [expr {$targetx0-$x0eff}]
#       set dk  [expr {$targetk -$keff}]
#       lappend dx0list $dx0
#       lappend dklist  $dk
#    }

#    # Update the lists (eff, target, d) in the Refinement GUI
#    ::Paratool::Refinement::update_paramlist $intcoorlist

   return $fclist
}


#########################################################
# Assign the force constants to internal coordinates.   #
# Takes the hessian matrix in internal coordinates.     #
# Harmonic force constants for diheds are tranlated to  #
# periodic potentials.                                  #
#########################################################

proc ::Paratool::Hessian::assign_fc_zmat { fclist } {
   variable ::Paratool::molidbase
   variable ::Paratool::zmatqm
   variable ::Paratool::zmat
   variable ::Paratool::exactdihedrals
   set num -1
   foreach entry $zmat {
      # Skip header
      if {$num==-1} { incr num; continue }
      set fc [lindex $fclist $num]
      set type [lindex $entry 1]
      if {[string match "dihed" $type]} {
	 set delta 180.0
	 set n [::QMtool::get_dihed_periodicity $entry $molidbase]
	 set dihed [lindex $entry 3]
	 set pot [expr {1+cos($n*$dihed/180.0*3.14159265)}]

	 if {$pot<1.0} { set delta 0.0 }
	 set pot [expr {1+cos(($n*$dihed-$delta)/180.0*3.14159265)}]

	 if {$exactdihedrals || $pot>0.1} { 
	    # If the equilib energy would be higher than 5% of the barrier height we choose the
	    # exact actual angle for delta.
	    # Since the minimum of cos(x) is at 180 deg we need to use an angle relative to 180.
	    set delta [expr {180.0+$dihed}]
	    puts "[lindex $entry 0] pot=$pot dihed=$dihed delta=$delta"
	 }
	 #puts "dihed=$dihed; n=$n; delta=$delta; fc=$fc"
	 set fc [expr {$fc/double($n*$n)}]
	 lset zmat [expr {$num+1}] 4 [list $fc $n $delta]
      } else {
	 lset zmat [expr {$num+1}] 4 [list $fc [lindex $entry 3]]
      }
      lappend newfclist $fc
      lset zmat [expr {$num+1}] 5 "[regsub {[QCRMA]} [lindex $zmat [expr {$num+1}] 5] {}]Q"
      incr num
   }
   variable ::Paratool::havefc 1
   variable ::Paratool::havepar 1
   lset zmat 0 6 $havepar
   lset zmat 0 7 $havefc
   # Reset the QM based zmat
   set zmatqm $zmat

   variable ::Paratool::charmmoverridesqm
   if {$charmmoverridesqm} { 
      ::Paratool::assign_known_bonded_charmm_params
   } else {
      ::Paratool::update_zmat
   }
   
   return $newfclist
}

