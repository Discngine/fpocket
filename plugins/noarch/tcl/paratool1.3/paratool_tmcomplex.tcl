#
# Generate a CHARMM patch residue for a transition
# metal complex.
#
# $Id: paratool_tmcomplex.tcl,v 1.34 2007/09/12 13:42:49 saam Exp $
#

proc ::Paratool::metal_complex_gui {} {
   variable selectcolor
   variable fixedfont

   if { [winfo exists .paratool_metal] } {
      #set geom [wm geometry .paratool_metal]
      #wm withdraw  .paratool_metal
      wm deiconify .paratool_metal
      #wm geometry  .paratool_metal $geom
      return
   }

   set v [toplevel ".paratool_metal"]
   wm title $v "Metal complexes / Iron-sulfur clusters"
   wm resizable $v 1 1

   labelframe $v.simply -text "Modeling" -padx 2m -pady 2m
   label $v.simply.label  -text "You can speed up your QM calculation by using simpler models for some ligands:"
   checkbutton $v.simply.imid -variable ::Paratool::tmuseimidazole \
      -text "Use imidazole for histidine ligands" -command ::Paratool::toggle_use_imidazole
   checkbutton $v.simply.thio -variable ::Paratool::tmuseethanethiol \
      -text "Use methanethiol for cysteine ligands" -command ::Paratool::toggle_use_ethanethiol
   pack $v.simply.label -pady 1m -anchor w
   pack $v.simply.imid $v.simply.thio -anchor w

   labelframe $v.catoms -bd 2 -relief ridge -text "Core atoms"  -padx 2 -pady 2
   label $v.catoms.format -text "Name Resid Rname Segid  Charge  ForceF    NPA" -relief flat -bd 2 \
      -justify left -font $fixedfont
   frame $v.catoms.list
   scrollbar $v.catoms.list.scroll -command "$v.catoms.list.list yview" -takefocus 0
   listbox $v.catoms.list.list -selectbackground $selectcolor -yscroll "$v.catoms.list.scroll set" \
      -width 55 -height 4 -setgrid 1 -selectmode browse -font $fixedfont -activestyle none \
      -listvariable ::Paratool::formatcomplexlist
   pack $v.catoms.list.list $v.catoms.list.scroll -side left -fill y -expand 1
   label $v.catoms.total -font $fixedfont -textvariable ::Paratool::centertotalcharge
   pack $v.catoms.format  -anchor w
   pack $v.catoms.list    -anchor w -fill y -expand 1
   pack $v.catoms.total   -anchor w

   labelframe $v.ligands -bd 2 -relief ridge -text "Ligands"  -padx 2 -pady 2

   label $v.ligands.format -text "Rname Resid Segid    Bond      Charge ForceF    NPA" -relief flat -bd 2 \
      -justify left -font $fixedfont
   frame $v.ligands.list
   scrollbar $v.ligands.list.scroll -command "$v.ligands.list.list yview" -takefocus 0
   listbox $v.ligands.list.list -selectbackground $selectcolor -yscroll "$v.ligands.list.scroll set" \
      -width 55 -height 6 -setgrid 1 -selectmode browse -font $fixedfont -activestyle none \
      -listvariable ::Paratool::formatligandlist
   pack $v.ligands.list.list $v.ligands.list.scroll -side left -fill y -expand 1

   label $v.ligands.total -font $fixedfont -textvariable ::Paratool::ligandstotalcharge
   button $v.ligands.update -text "Update" -command { ::Paratool::find_complex_centers $::Paratool::molidbase }

   pack $v.ligands.format -anchor w
   pack $v.ligands.list   -anchor w -fill y -expand 1 
   pack $v.ligands.total  -anchor w
   pack $v.ligands.update -anchor w

   labelframe $v.topo -text "Topology/Parameters" -padx 2m -pady 2m
   frame $v.topo.patch
   label $v.topo.patch.label -text "Patch name"
   entry $v.topo.patch.entry -textvariable ::Paratool::tmpatchname -width 6
   pack $v.topo.patch.label $v.topo.patch.entry -side left -anchor w
   checkbutton $v.topo.simply -text "Use imidazole (IMD/IME) instead of histidine in topology" \
      -variable ::Paratool::tmimdtopology
   checkbutton $v.topo.angles -text "Include angles involving center and ligand atoms" \
      -variable ::Paratool::tmincludeangles
   checkbutton $v.topo.diheds -text "Include dihedrals involving center and ligand atoms" \
      -variable ::Paratool::tmincludediheds
   checkbutton $v.topo.imprps -text "Include impropers involving center and ligand atoms" \
      -variable ::Paratool::tmincludeimprps
   button $v.topo.excl -text "Edit explicit nonbonded exclusions" -command ::Paratool::exclusions_gui

   frame $v.topo.write
   button $v.topo.write.topo -text "Write topology patch PRES" \
      -command { ::Paratool::write_topology }
   button $v.topo.write.para -text "Write parameters" \
      -command { ::Paratool::write_parameters }
   button $v.topo.write.psfgen -text "Write psfgen input" \
      -command { ::Paratool::write_psfgen_input -file [file rootname $::Paratool::molnamebase].pgn -build }
   pack $v.topo.write.topo $v.topo.write.para $v.topo.write.psfgen -side left

   pack $v.topo.patch  -pady 1m -anchor w
   pack $v.topo.simply $v.topo.angles $v.topo.diheds $v.topo.imprps $v.topo.excl $v.topo.write -anchor w

   pack $v.simply  -fill x -padx 1m -pady 1m
   pack $v.catoms  -fill both -expand 1 -padx 1m -pady 1m
   pack $v.ligands -fill both -expand 1 -padx 1m -pady 1m
   pack $v.topo    -fill x -padx 1m -pady 1m


   bind $v.catoms.list.list <1> {
      focus .paratool_metal.catoms.list.list
   }

   bind $v.ligands.list.list <1> {
      focus .paratool_metal.ligands.list.list
   }

   # This will be executed when a complex center atom is selected:   
   bind $v.catoms.list.list <<ListboxSelect>> {
      set index [.paratool_metal.catoms.list.list curselection]
      set segid [lindex $::Paratool::tmcomplex $index 0]
      set resid [lindex $::Paratool::tmcomplex $index 1]
      set name  [lindex $::Paratool::tmcomplex $index 2]
      set sel [atomselect $::Paratool::molidbase "segid $segid and resid $resid and name $name"]
      ::Paratool::select_atoms [join [$sel get index]]
      $sel delete
   }

   # This will be executed when a ligand is selected:   
   bind $v.ligands.list.list <<ListboxSelect>> {
      set index [.paratool_metal.ligands.list.list curselection]
      set resid [lindex $::Paratool::tmligands $index 1]
      set segid [lindex $::Paratool::tmligands $index 2]
      set sel [atomselect $::Paratool::molidbase "segid $segid and resid $resid"]
      ::Paratool::select_atoms [$sel list]
      $sel delete
   }
 
   if {[winfo exists .paratool_metal.topo.simply]} {
      variable tmuseimidazole
      if {$tmuseimidazole} { 
	 .paratool_metal.topo.simply configure -state normal
      } else {
	 .paratool_metal.topo.simply configure -state disabled
      }
   }
   #.paratool_metal.ligands.list.list selection set 0

   #update_formatted_tmligands
   #update_formatted_tmcomplex
}

proc ::Paratool::update_formatted_tmcomplex {} {
   variable molidbase
   variable molidparent
   set molid $molidbase
   if {$molidparent>=0} {
      set molid $molidparent
   }

   variable tmcomplex
   variable formatcomplexlist {}
   set npacharge {}
   set forcefcharge {}
   set complexcharge 0.0
   set sel [atomselect $molid "curcomplex"]

   foreach i [$sel list] name [$sel get name] segid [$sel get segid] resid [$sel get resid] \
      resname [$sel get resname] charge [$sel get charge] {

      set npa    [get_atomprop NPA $i]
      set forcef [get_atomprop ForceF $i]
      if {[string is double $charge] && [llength $charge]} {
	 set complexcharge [expr $complexcharge+$charge]
	 set charge [format "%+7.3f" $charge]
      } 
      if {[string is double $npa] && [llength $npa]} {
	 set npacharge [expr $npacharge+$npa]
	 set npa [format "%+7.3f" $npa]
      } 
      if {[string is double $forcef] && [llength $forcef]} {
	 set forcefcharge [expr $forcefcharge+$forcef]
	 set forcef [format "%+7.3f" $forcef]
      } 

      lappend formatcomplexlist [format "%4s %5s %5s %5s %7s %7s %7s" $name $resid $resname $segid $charge $forcefcharge $npa]
   }

   if {[string is double $complexcharge] && [llength $complexcharge]} {
      set complexcharge [format "%+7.3f" $complexcharge]
   } 
   if {[string is double $forcefcharge] && [llength $forcefcharge]} {
      set forcefcharge [format "%+7.3f" $forcefcharge]
   } 
   if {[string is double $npacharge] && [llength $npacharge]} {
      set npacharge [format "%+7.3f" $npacharge]
   } 

   variable centertotalcharge [format "   Total core charges: %7s %7s %7s" $complexcharge $forcefcharge $npacharge]
   $sel delete
}

proc ::Paratool::update_formatted_tmligands {} {
   variable molidbase
   variable molidparent
   set molid $molidbase
   if {$molidparent>=0} {
      set molid $molidparent
   }

   variable tmligands
   variable formatligandlist {}
   set totalnpa {}
   set totalcharge 0.0
   set totalformal {}
   foreach ligand $tmligands {
      set sel0 [atomselect $molid "index [lindex $ligand 3]"]
      set centerbond [lindex $ligand 4 2]
      set charge       [lindex $ligand 5]
      set formalcharge [lindex $ligand 6]
      set npacharge    [lindex $ligand 7]
      if {[string is double $formalcharge] && [llength $formalcharge]} {
	 set totalformal [expr $totalformal+$formalcharge]
	 set formalcharge [format "%+7.3f" $formalcharge]
      } 
      if {[string is double $charge] && [llength $charge]} {
	 set totalcharge [expr $totalcharge+$charge]
	 set charge [format "%+7.3f" $charge]
      } 
      if {[string is double $npacharge] && [llength $npacharge]} {
	 set totalnpa [expr $totalnpa+$npacharge]
	 set npacharge [format "%+7.3f" $npacharge]
      } 

      lappend formatligandlist [format "%5s %5i %5s %4s--%-4s %7s %7s %7s" [lindex $ligand 0] [lindex $ligand 1] \
				   [lindex $ligand 2] [join [$sel0 get name]] $centerbond $charge $formalcharge \
				   $npacharge]

      $sel0 delete
   }

   if {[string is double $totalnpa] && [llength $totalnpa]} {
      set totalnpa [format "%+7.3f" $totalnpa]
   }
   if {[string is double $totalcharge] && [llength $totalcharge]} {
      set totalcharge [format "%+7.3f" $totalcharge]
   }
   if {[string is double $totalformal] && [llength $totalformal]} {
      set totalformal [format "%+7.3f" $totalformal]
   }

   variable ligandstotalcharge [format "     Total ligand charges:   %7s %7s %7s" $totalcharge $totalformal $totalnpa]
}


proc ::Paratool::find_complex_centers { molid {verbose verbose}} {
   variable molidbase
   variable molidparent
   variable tmliganddistance
   variable tmcomplexlist
   variable tmligandlist

    if {$molid<0} { return }

   # Macro for all transition metals, actinides, lanthanoids and metals of the 4th, 5th and 6th main group
   atomselect macro transitionmetal "((atomicnumber>=21 and atomicnumber<=31) or (atomicnumber>=39 and atomicnumber<=50) or (atomicnumber>=57 and atomicnumber<=84) or (atomicnumber>=89))"
   atomselect macro sulfur "(atomicnumber 16)"
   set transmetalsel [atomselect $molid "transitionmetal"]

   # Find all complex centers, i.e. residues that contain transition metals.
   # This includes transition metal complexes and iron-sulfur clusters.
   # Additionally find the ligands, i.e. all residues that have at least one atom
   # closer than $tmliganddist to one of the complex atoms
   set complexes {}
   set ligandlist {}
   if {[$transmetalsel num]} {
      foreach atom [$transmetalsel list] {
	 # Make sure to use metal atoms only once
	 if {[lsearch [join $complexes] $atom]<0} {
	    set tmpligandsel  [atomselect $molid "(same resid as within $tmliganddistance of index $atom) and same segid as within $tmliganddistance of index $atom"]
	    set clustersel [atomselect $molid "(same residue as (index [$tmpligandsel list] and index [$transmetalsel list])) and same segid as (index [$tmpligandsel list] and index [$transmetalsel list])"]

	    set segreslist {}
	    if {[$tmpligandsel num]} {
	       set ligandsel [atomselect $molid "index [$tmpligandsel list] and not index [$clustersel list]"]
	       set segreslist [lsort -unique [$ligandsel get {resname resid segid}]]
	    }
	    lappend ligandlist $segreslist
	    $tmpligandsel delete

	    if {[$clustersel num]>1} {
	       # Another metal atom is part of the same complex, i.e. we have a cluster
	       lappend complexes [lsort -unique [join [list $atom [$clustersel list]]]]
	    } else {
	       # This is a single atom centered complex
	       lappend complexes $atom 
	    }
	    $clustersel delete
	    $ligandsel delete
	 }
      }
   }
   $transmetalsel delete
   set tmcomplexlist $complexes
   set tmligandlist  $ligandlist
   #puts "tmcomplexlist $tmcomplexlist"
   #puts "tmligandlist $tmligandlist"

   update_unpar_complex $molid $verbose
}

proc ::Paratool::update_unpar_complex { molid {verbose verbose}} {
   variable molidbase
   variable molidparent
   variable tmligandlist
   variable tmcomplexlist
   variable tmliganddistance
   variable istmcomplex 
   variable isironsulfur
   atomselect macro imidazole "(resname HIS HSD HSE HSP and name CG CE1 ND1 CD2 CE2 NE2 HE1 HE2 HD2 HD1 HG)"
   atomselect macro hisnotimi "(resname HIS HSD HSE HSP and not (name CG CE1 ND1 CD2 CE2 NE2 HE1 HE2 HD2 HD1 HG))"
   atomselect macro cysside   "(resname CYS and sidechain)"


   # See if the unparametrized part includes a complex
   set curligandlist {}
   variable tmcomplex {}
   variable tmpatchname

   foreach complex $tmcomplexlist ligand $tmligandlist {
      set curcomplexsel [atomselect $molid "unparametrized and index $complex"]
      if {[$curcomplexsel num]} {
	 # Classify into TM-complex or FeS-cluster
	 set tmsel [atomselect $molid "unparametrized and index $complex and transitionmetal"]
	 set fessel [atomselect $molid "unparametrized and index $complex and sulfur"]
	 if {[$fessel num] && [lsearch [$tmsel get atomicnumber] 26]>=0} {
	    variable isironsulfur 1
	    set niron [llength [lsearch -all [$tmsel get atomicnumber] 26]]
	    set nsulf [$fessel num]
	    if {$verbose=="verbose"} {
	       puts "Unparametrized residue [lsort -unique [$curcomplexsel get resid]] contains iron-sulfur cluster (${niron}Fe, ${nsulf}S)." 
	    }
	 }  else {
	    variable istmcomplex 1
	    set elements {}
	    foreach tm [$tmsel get atomicnumber] {
	       lappend elements [::QMtool::atomnum2element $tm]
	    }
	    if {$verbose=="verbose"} {
	       puts "Unparametrized residue [lsort -unique [$curcomplexsel get resid]] contains metal-complex ($elements)." 
	    }
	 }
	 $fessel delete
	 $tmsel delete

	 # Look for IMD as model for HIS
	 variable histoimd {}
	 foreach lig $ligand {
	    set segid [lindex $lig 2]
	    set resid [lindex $lig 1]
	    set curligandsel [atomselect $molid "segid $segid and resid $resid"]
	    set names [lsort [$curligandsel get name]]
	    if {[string equal $names "CD2 CE1 CG HD1 HD2 HE1 HG ND1 NE2"] ||
		[string equal $names "CD2 CE1 CG HD2 HE1 HE2 HG ND1 NE2"]} {
	       lappend histoimd [list [list [lindex $lig 2] [lindex $lig 1]] [list [lindex $lig 0]]]
	    }
	    $curligandsel delete
	 }

	 set tmcomplex [$curcomplexsel get {segid resid name resname}]
	 if {![llength $tmpatchname]} {
	    set resname [join [$curcomplexsel get resname]]
	    set tmpatchname "[string range $resname 0 2]C"
	    # Check if the patch resname already exists
	    variable topologylist
	    set found 0
	    foreach topology $topologylist {
	       if {[::Toporead::topology_contains_resi $topology $resname]>=0} {
		  set found 1
		  break
	       }
	    }
	    if {$found} {
	       set tmpatchname {}
	    }
	 }

 	 set curligandreslist {}
 	 set curligandseglist {}
 	 foreach lig $ligand {
 	    lappend curligandreslist [lindex $lig 1]
 	    lappend curligandseglist [lindex $lig 2]
 	 }
 	 set curligandlist [list $curligandreslist $curligandseglist]
         variable tmligands $ligand
	 if {$verbose=="verbose"} {
	    puts "Complex: $tmcomplex"
	    puts "Ligands: $tmligands"
	    #puts "cur $curligandlist"
	    #puts "imi $histoimd"
	 }
	 atomselect macro ligandres none
	 atomselect macro ligands none
	 if {[llength [join $curligandlist]]} {
	    atomselect macro ligandres "(resid $curligandreslist and segid $curligandseglist)"
	 }
      }
      $curcomplexsel delete
   }
   if {$verbose=="verbose"} {
      puts ""
   }

   if {![llength $tmcomplex]} { return }

   # Define a macro for the complex center
   set seltext none
   foreach complex $tmcomplex {
      append seltext " or (segid [lindex $complex 0] and resid [lindex $complex 1] and name [lindex $complex 2])"
   }

   atomselect macro curcomplex "$seltext"

   # Find the centroids of the ligands and draw bonds to the center
   # The centroid is the ligand atom that binds to the center
   set curcomplexsel [atomselect $molid "curcomplex"]
   variable complexbondlist {}
   set i 0
   foreach ligand $tmligands {
      set segid   [lindex $ligand 2]
      set resid   [lindex $ligand 1]
      set resname [lindex $ligand 0]

      # Select potential centroids
      set centroidsel [atomselect $molid "segid $segid and resid $resid \
                       and (exwithin $tmliganddistance of index [$curcomplexsel list])"]

      # Calculate the distance for each pot. centroid-center pair
      set atomdist {}
      foreach latom [$centroidsel list] lcoor [$centroidsel get {x y z}] {
	 foreach catom [$curcomplexsel list] ccoor [$curcomplexsel get {x y z}] {
	    lappend atomdist [list $catom $latom [veclength [vecsub $lcoor $ccoor]]]
	 }
      }
      # Sort the pairlist according to the bond distances
      set sorteddist [lsort -real -index 2 $atomdist]

      # The centroid is the closest ligand atom
      set complexbond [lindex $sorteddist 0 0]
      set centroid    [lindex $sorteddist 0 1]
      #puts "centroid $centroid; complexbond $complexbond"
      $centroidsel delete

      # Add complex-centroid bond to VMD's bondlist
      set sel0 [atomselect $molid "index $complexbond"]
      set sel1 [atomselect $molid "index $centroid"]
      vmd_addbond [join [$sel0 list]] $centroid $molid

      # Get the ligand formal charge
      variable topologylist
      set formalcharge {}
      foreach topology $topologylist {
	 if {[::Toporead::topology_contains_resi $topology $resname]>=0} {
	    set formalcharge [::Toporead::topology_get_resid $topology $resname charge]
	    break
	 }
      }

      # Determine the ligand Charge and NPA
      set lignpa    0.0
      set ligcharge 0.0
      set ligsel [atomselect $molidbase "segid $segid and resid $resid"]
      foreach atom [$ligsel get {name atomicnumber charge type index}] {
	 foreach {name atomicnumber charge type index} $atom {}
	 set elem [::QMtool::atomnum2element $atomicnumber]
	 #set flags   [lindex $atom [get_atomprop_index Flags]]
	 set npa [get_atomprop NPA $index]

	 if {![llength $charge]} {
	    tk_messageBox -icon error -type ok -title Message \
	       -message "Undefined charge found! Please specify all charges!"      
	    return 0
	 }

	 if {[llength $npa]} {
	    set lignpa [expr {$lignpa+$npa}]
	 } 

	 set ligcharge [expr {$ligcharge+$charge}]
      }

      set ligcharge [format "%.5f" $ligcharge]
      if {abs([format "%7.3f" $ligcharge]-$ligcharge)>0.001} {
	 puts "WARNING: Non-integer ligand charge: q=$ligcharge" 
      }

      if {![llength $formalcharge]} { set formalcharge {{}} }
      if {![llength $lignpa]}       { set lignpa    {{}} }

      # Append centroid, complexbond and formalcharge to the entry in tmligands
      lset tmligands $i [join [list $ligand $centroid [$sel0 get {segid resid name}] $ligcharge $formalcharge $lignpa]]

      # This bondlist is needed by proc add_selection_to_xbgf
      lappend complexbondlist [list [list [join [$sel0 get {segid resid name}]] \
					[join [$sel1 get {segid resid name}]]] 1.0]
      incr i
   }
   $curcomplexsel delete

   update_formatted_tmcomplex
   update_formatted_tmligands

   #metal_complex_gui
   

   #update_fragment_selection

   # Use imidazole as a model for HIS?
   #toggle_use_imidazole

   # Use ethanethiol as a model for CYS?
   #toggle_use_ethanethiol

   atomselect macro ligands "(ligandres)"
   variable fragmentseltext "(unparametrized or ligands)"
   update_fragment_selection
}


#############################################################
# Get charge of an atom after applying the tmcomplex patch. #
# I.e. Center atoms get NPA charges, while ligand centroids #
# are modified by the appropriate NPA shift.                #
#############################################################
proc ::Paratool::get_complexcharge {index} {
   variable tmligands
   variable tmcomplexlist
   set charge [get_atomprop Charge $index]

   # Check if the atom is a ligand centroid, in that case we have to compute the
   # new effective charge on the atom
   set lig [lsearch -regexp $tmligands "^.+\\s.+\\s.+\\s$index\\s"]
   if {$lig>=0} {
      set lignpa    [lindex $tmligands $lig 7]
      set ligcharge [lindex $tmligands $lig 5]
      set charge [expr {$charge+$lignpa-$ligcharge}]
      #puts "charge=$charge npa=$lignpa ligcharge=$ligcharge"
   }
   if {[lsearch $tmcomplexlist $index]>=0} {
      set charge [get_atomprop NPA $index]
      #puts "center charge=$charge"
   }
   return $charge
}

proc ::Paratool::toggle_use_imidazole {} {
   variable molidbase
   variable tmuseimidazole
   variable tmuseethanethiol
   variable tmligands

   if {$molidbase<0} { return }

   if {$tmuseimidazole} {
      # Check if we have HG already
      set hgamma [atomselect $molidbase "ligandres and resname HIS HSE HSD HSP and name HG"]
      atomselect macro excludedhg none
      if {[$hgamma num]} {
	 atomselect macro excludedhg "index [$hgamma list]"
	 #$hgamma delete
	 #return
      }
      $hgamma delete

      if {$tmuseethanethiol} {
	 atomselect macro ligands "(ligandres and (not (resname HIS HSD HSE IMD IME and not imidazole)) and not (resname CYS and not cysside))"
      } else {
	 atomselect macro ligands "(ligandres and (not hisnotimi))"
      }

      # We are using imidazole as a model for HIS
      set cgamma [atomselect $molidbase "ligandres and resname HIS HSE HSD and name CG"]
      if {[$cgamma num]} {
	 set atomdeflist {}
	 foreach atom [$cgamma list] {
	    set sel [atomselect $molidbase "index $atom"]
	    lappend atomdeflist [join [$sel get {segid resid name}]]
	 }

	 variable fragmentseltext
	 set sel [atomselect $molidbase "($fragmentseltext) and (curcomplex or ligands) and not excludedhg"]
	 molefacture_start $sel
	 ::Molefacture::user_select_atoms $atomdeflist
	 ::Molefacture::add_hydrogen_noupdate
	 ::Molefacture::done

	 # We know the type is HR3, charge depends on HSE/HSD
	 set hmolf [atomselect $molidbase "ligandres and resname HSD and name \"HM.*\""]
	 $hmolf set beta 1.0
	 foreach i [$hmolf list] {
	    ::Paratool::set_atomprop Name   $i HG
	    ::Paratool::set_atomprop Type   $i HR3
	    ::Paratool::set_atomprop Charge $i 0.09
	 }
	 $hmolf delete
	 set hmolf [atomselect $molidbase "ligandres and resname HSE and name \"HM.*\""]
	 $hmolf set beta 1.0
	 foreach i [$hmolf list] {
	    ::Paratool::set_atomprop Name   $i HG
	    ::Paratool::set_atomprop Type   $i HR3
	    ::Paratool::set_atomprop Charge $i 0.10
	 }
	 $hmolf delete

	 rename_histoimi
	 set i 0
	 foreach lig $tmligands {
	    if {[lindex $lig 0]=="HSD"} {
	       lset tmligands $i 0 IMD
	    }
	    if {[lindex $lig 0]=="HSE"} {
	       lset tmligands $i 0 IME
	    }
	    incr i
	 }
	 assign_vdw_params
	 assign_ForceF_charges
	 atomedit_update_list nocomplexcheck
	 update_formatted_tmligands
      }
      if {[winfo exists .paratool_metal.topo.simply]} {
	 .paratool_metal.topo.simply configure -state normal
      }
   } else {
      rename_imitohis
      set i 0
      foreach lig $tmligands {
	 if {[lindex $lig 0]=="IMD"} {
	    lset tmligands $i 0 HSD
	 }
	 if {[lindex $lig 0]=="IME"} {
	    lset tmligands $i 0 HSE
	 }
	 incr i
      }

      if {$tmuseethanethiol} {
	 atomselect macro ligands "(ligandres and not (resname CYS and not cysside))"
      } else {
	 atomselect macro ligands "(ligandres and (not (resname HIS HSD HSE and name HG)))"
      }
      variable fragmentseltext "(unparametrized or ligands)"
      update_fragment_selection
      assign_vdw_params
      assign_ForceF_charges
      atomedit_update_list nocomplexcheck
      update_formatted_tmligands

      if {[winfo exists .paratool_metal.topo.simply]} {
	 .paratool_metal.topo.simply configure -state disabled
      }
   }
}

proc ::Paratool::toggle_use_ethanethiol {} {
   variable molidbase
   variable tmuseimidazole
   variable tmuseethanethiol

   if {$molidbase<0} { return }

   if {$tmuseethanethiol} {
      if {$tmuseimidazole} { 
	 atomselect macro ligands "(ligandres and (not (resname HIS HSD HSE HSD and not imidazole)) and not (resname CYS and not cysside))"
      } else {
	 atomselect macro ligands "(ligandres and not (resname CYS and not cysside))"	 
      }
      
      set cbeta [atomselect $molidbase "ligandres and resname CYS and name CB"]
      if {[$cbeta num]} {
	 set atomdeflist {}
	 foreach atom [$cbeta list] {
	    set sel [atomselect $molidbase "index $atom"]
	    lappend atomdeflist [join [$sel get {segid resid name}]]
	 }
	 molefacture_start 
	 ::Molefacture::user_select_atoms $atomdeflist
	 ::Molefacture::add_hydrogen
	 ::Molefacture::done
	 # We know the type is HA
	 set hmolf [atomselect $molidbase "ligandres and resname CYS and name \"HM.*\""]
	 foreach i [$hmolf list] {
	    ::Paratool::set_atomprop Name $i HB3
	    ::Paratool::set_atomprop Type $i HA
	 }
	 atomedit_update_list nocomplexcheck
      }
   } else {
      if {$tmuseimidazole} {
	 atomselect macro ligands "(ligandres and (not hisnotimi))"
      } else {
	 atomselect macro ligands "(ligandres and (not (resname HIS HSD HSE IMD IME and name HG)))"
      }
      variable fragmentseltext "(unparametrized or ligands)"
      update_fragment_selection
   }
}

proc ::Paratool::verify_patchname {} {
   variable tmpatchname
   if {[llength $tmpatchname]>4} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Residue patch name $tmpatchname too long!\nPlease specify another name (max. 4 characters)."
      focus .paratool_metal.topo.patch.entry
      return 0	 
   }
   if {[llength $tmpatchname]>4} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Residue patch name $tmpatchname too long!\nPlease specify another name (max. 4 characters)."
      focus .paratool_metal.topo.patch.entry
      return 0	 
   }
   if {![regexp {[A-Za-z_\*']*} $tmpatchname]} { 
      tk_messageBox -type ok -title Message \
	 -message "Residue patch name must consist of alphanumeric characters!" \
	 focus .paratool_metal.topo.patch.entry
      return 0 
   }
   variable topologylist
   set found 0
   foreach topology $topologylist {
      if {[::Toporead::topology_contains_resi $topology $tmpatchname]>=0} {
	 set found 1
	 break
      }
   }
   if {$found} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Residue patch name $tmpatchname already exists! Please specify another name."
      focus .paratool_metal.topo.patch.entry
      return 0
   }
}

# TODO:
# set center charges=NPA
# check total charge
# determine cross-conformations
# check if all ligands are known

proc ::Paratool::write_tmcomplex_patchresi { file } {
   variable molidbase
   variable tmligands
   variable tmcomplex
   variable tmpatchname
   if {![llength $tmpatchname]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please specify residue patch name!"
      return 0
   } else {
      verify_patchname
   }

   # Determine unparametrized resnames
   init_componentlist

   set lignpalist {}
   set ligchargelist {}
   set ligformalchargelist {}
   foreach lig $tmligands {
      set segid   [lindex $lig 2]
      set resid   [lindex $lig 1]
      set resname [lindex $lig 0]
      set ligcharge       [lindex $lig 5]
      set ligformalcharge [lindex $lig 6]
      set lignpacharge    [lindex $lig 7]

      set sel [atomselect $molidbase "segid $segid and resid $resid"]
      set csel [atomselect $molidbase "index [lindex $lig 3]"]

      # Check if we have a topology for the ligand
      variable topologylist
      set found 0
      foreach topology $topologylist {
	 if {[::Toporead::topology_contains_resi $topology $resname]>=0} {
	    set found 1
 	    break
 	 }
      }
      if {!$found} {
	 set message    "Undefined ligand $resname found!\n"
	 append message "Please first parametrize ligand separately or provide corresponding topology file."
 	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
 	    -message $message
 	 return 0
      }

      # Do some error checks
      foreach atom [$sel get {name resid segid charge type index}] {
	 foreach {name resid segid charge type index} $atom {}
	 set npa [get_atomprop NPA $index]

	 if {![llength $type] || $type=={}} { 
	    tk_messageBox -icon error -type ok -title Message -parent .paratool \
	       -message "Empty type name found in $segid:$resid! Please specify all type names."
	    return $index
	 }

	 if {![llength $charge]} {
	    tk_messageBox -icon error -type ok -title Message \
	       -message "Undefined charge in $segid:$resid $name found! Please specify all charges!"      
	    return 0
	 }

	 if {![llength $npa]} {
	    #tk_messageBox -icon error -type ok -title Message \
	     #  -message "Undefined NPA charge in $segid:$resid $name found! Please determine all NPA charges!"
	    puts "WARNING: Undefined NPA charge in $segid:$resid $name found! Please determine all NPA charges!"
	    #return 0
	 }
      }

      if {[expr abs([format "%7.3f" $ligcharge]-$ligcharge)]>0.001} {
	 puts "WARNING: Non-integer ligand charge: q=$ligcharge" 
      }

      if {[llength $ligformalcharge] && [expr abs($ligcharge-$ligformalcharge)]>0.001} {
	 puts "WARNING: Ligand total charge=$ligcharge differs from formal charge=$ligformalcharge."
	 puts "(Maybe the residue was patched.) Using ligand total charge."
      }

      lappend ligformalchargelist $ligformalcharge
      lappend ligchargelist       $ligcharge
      lappend lignpalist          $lignpacharge
   }


   set sel [atomselect $molidbase "curcomplex"]
   set resname [lsort -unique [$sel get resname]]
   if {[llength $resname]>1} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Multiple resnames $resname found for complex center!\nAll atoms in the complex center must have the same resname."
      return 0
   }

   set centernpa    0.0
   set centercharge 0.0
   foreach atom [$sel get {name resid segid charge type index}] {
      foreach {name resid segid charge type index} $atom {}
      set npa    [get_atomprop NPA $index]
      
      if {![llength $type] || $type=={}} { 
	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
	    -message "Empty type name found in $segid:$resid! Please specify all type names."
	 return $index
      }
      
      if {![llength $charge]} {
	 tk_messageBox -icon error -type ok -title Message \
	    -message "Undefined charge in $segid:$resid $name found! Please specify all charges!"      
	 return 0
      }
      
      if {![llength $npa]} {
	 #tk_messageBox -icon error -type ok -title Message \
	 #   -message "Undefined NPA charge in $segid:$resid $name found! Please determine all NPA charges!"      
	 puts "WARNING: Undefined NPA charge in $segid:$resid $name found! Please determine all NPA charges!"
	 set npa 0.0
	 #return 0
      }
      
      set centernpa    [expr $centernpa+$npa]
      set centercharge [expr $centercharge+$charge]
   }
      
   set fid [open $file w]
   write_charmmtop_header $fid

   puts $fid "!"
   puts $fid "! Residue topology for center of transition metal complex or Fe-S cluster:"
   puts $fid "!"
   write_resi_topology $fid $sel -noheader -noictable
   $sel delete

   set patchcharge $centercharge
   foreach ligcharge $ligchargelist {
      set patchcharge [expr $patchcharge+$ligcharge]
   }

   # Add some comments   
   puts $fid ""
   puts $fid "!"
   puts $fid "! Patch residue topology for transition metal complex or Fe-S cluster."
   puts $fid "! Ligand topologies must be provided independently."
   puts $fid "!"
   puts $fid "! Usage in psfgen:"
   puts -nonewline      "! patch $tmpatchname"
   puts -nonewline $fid "! patch $tmpatchname"
   variable tmpatch $tmpatchname
   foreach lig $tmligands {
      set segid   [lindex $lig 2]
      set resid   [lindex $lig 1]
      set resname [lindex $lig 0]
      puts -nonewline      " $segid:$resid"
      puts -nonewline $fid " $segid:$resid"
      append tmpatch " $segid:$resid"
   }
   foreach complex $tmcomplex {
      set segid   [lindex $complex 0]
      set resid   [lindex $complex 1]
      set name    [lindex $complex 2]
      puts -nonewline      " $segid:$resid"
      puts -nonewline $fid " $segid:$resid"
      append tmpatch " $segid:$resid"
   }
   puts ""
   puts $fid "\n!"
   variable exclusions
   if {[llength $exclusions]} {
      puts $fid "! Please use the following explicit exclusions:"
      foreach pair $exclusions {
	 set pairsel [atomselect $molidbase "index $pair"]
	 puts $fid "! [$pairsel get {segid resname resid name}]"
      }
      puts $fid "\n!"
   }

   # MASS records:
   # ------------
   # If there are ligands of the same type we must rename the
   # centroid atoms to be able to distinguish them
   variable tmnewtypes {}
   set newtypes [rename_centroids]
   # If there are atom whose types don't correspond to the RESI entry they
   # also have to be added to the list of new types in order to be considered in the
   # new topology/parameter file.
   foreach lig $tmligands {
      set segid   [lindex $lig 2]
      set resid   [lindex $lig 1]
      set resname [lindex $lig 0]
      set sel [atomselect $molidbase "segid $segid and resid $resid"]

      foreach atom [$sel get {name atomicnumber charge type index}] {
	 foreach {name atomicnumber charge type index} $atom {}

	 set oldtype {}
	 set found 0
	 foreach topology $topologylist {
	    if {[::Toporead::topology_resi_contains_atom_with_type $topology $resname $name $type]>=0} {
	       set found 1
	       break
	    } else {
	       set oldtype [lindex [::Toporead::topology_resi_contains_atom $topology $resname $name] 1]
	    }
	 }
 	 if {!$found} {
 	    set comment "New type for patch"
 	    lappend tmnewtypes [list $segid $resid $name $oldtype $type]
 	    lappend newtypes [list $type [::QMtool::atomnum2element $atomicnumber] $comment]
 	 }
      }
   }
   variable tmnewtypes [lsort -unique $tmnewtypes]
   write_charmmtop_masses $fid $newtypes


   # Start residue patch PRES
   puts $fid [format "PRES %4s %+7.3f" $tmpatchname $patchcharge]

   set ilig 1
   foreach lig $tmligands ligcharge $ligchargelist lignpa $lignpalist ligformalcharge $ligformalchargelist {
      set segid   [lindex $lig 2]
      set resid   [lindex $lig 1]
      set resname [lindex $lig 0]
      set chargediff [format "%+8.3f" [expr $lignpa-$ligcharge]]
      set ligcharge  [format "%+8.3f" $ligcharge]

      puts $fid ""
      puts $fid [format "GROUP  ! %4s:%-4s %6s   formal=%+7.3f; NPA=%+7.3f; diff=%+7.3f" \
		    $segid $resid ($resname) $ligcharge $lignpa $chargediff]
      set sel [atomselect $molidbase "segid $segid and resid $resid"]
      set csel [atomselect $molidbase "index [lindex $lig 3]"]

      foreach atom [$sel get {name atomicnumber charge type index}] {
	 foreach {name atomicnumber charge type index} $atom {}

	 set found 0
	 foreach topology $topologylist {
	    if {[::Toporead::topology_resi_contains_atom_with_type $topology $resname $name $type]>=0} {
	       set found 1
	       break
	    }
	 }

	 # Only consider the centroids or atoms with unknown types
	 if {[join [$csel get name]]!="$name" && $found} {
	    continue
	 }

	 if {[lsearch [$csel get name] $name]>=0} {
	    #set elem [::QMtool::atomnum2element $atomicnumber]
	    set charge [format "%+8.3f" $charge]
	    set comment {! }
	    append comment [format " orig=%+7.3f; diff=%+7.3f" $charge $chargediff]
	    if {[get_atomprop Known $index]>=0} {
	       append comment "  type from CHARMM"
	    }
	    
	    # Consider the renamed types
	    set newtype [lsearch -inline $tmnewtypes "$segid $resid $name $type *"]
	    if {[llength $newtype]} {
	       set type [lindex $newtype 4]
	    } 

	    puts $fid [format "ATOM %4s  %4s  %+8.3f %s" $ilig$name $type [expr {$charge+$chargediff}] $comment]
	 } else {
	    set comment "! changed type"
	    puts $fid [format "ATOM %4s  %4s  %+8.3f %s" $ilig$name $type $charge $comment]
	 }
      }
      incr ilig
   }

   set sel [atomselect $molidbase "curcomplex"]
   set segid   [join [lsort -unique [$sel get segid]]]
   set resid   [join [lsort -unique [$sel get resid]]]
   set resname [join [lsort -unique [$sel get resname]]]

   set chargediff   [format "%+8.3f" [expr {$centernpa-$centercharge}]]
   set centercharge [format "%+8.3f" $centercharge]
   puts $fid ""
   puts $fid [format "GROUP  ! %4s:%-4s %6s   formal=%+7.3f; NPA=%+7.3f; diff=%+7.3f" \
		 $segid $resid ($resname) $centercharge $centernpa $chargediff]
   
   
   foreach i [$sel list] name [$sel get name] type [$sel get type] charge [$sel get charge] {
      set npa    [get_atomprop NPA $i]
      if {![llength $npa]} { set npa 0.0 }

      set comment {! }
      append comment [format " NPA charge used"]

      puts $fid [format "ATOM %4s  %4s  %+8.3f %s" $ilig$name $type $npa $comment]   
   }

   puts $fid ""

   variable zmat
   set bondlist {}
   set anglelist {}
   set dihedlist {}
   set imprplist {}
   set ilig 1
   foreach lig $tmligands {
      set segid     [lindex $lig 2]
      set resid     [lindex $lig 1]
      set resname   [lindex $lig 0]
      set centroid  [lindex $lig 3]
      set centerdef [lindex $lig 4]
      set centroidsel [atomselect $molidbase "index $centroid"]
      set centersel [atomselect $molidbase "segid [lindex $centerdef 0] and resid [lindex $centerdef 1] and name [lindex $centerdef 2]"]
      set center [join [$centersel list]]
      set zmatbonds [lsearch -inline -regexp -all $zmat ".+bond\\s{(($center\\s$centroid)|($centroid\\s$center))}"]
      foreach bond $zmatbonds {
	 set bo 0
	 switch [lindex $bond 1] {
	    bond  { set bo 1 }
	    dbond { set bo 2 }
	    tbond { set bo 3 }
	 }
	 lappend bondlist [list [join [expr [llength $tmligands]+1][$centersel get name]] [join $ilig[$centroidsel get name]] $bo]
      }

      variable tmincludeangles
      if {$tmincludeangles} {
	 set zmatangles [get_dependent_zmat_angles $center $centroid]
	 foreach angle $zmatangles {
	    set namelist {}
	    foreach atom [lindex $angle 2] {
	       set sel [atomselect $molidbase "index $atom"]
	       if {$atom==$center} {
		  lappend namelist "[expr [llength $tmligands]+1][join [$sel get name]]"
	       } else {
		  set pos [lsearch $tmligands "* [join [$sel get {resid segid}]] *"]
		  lappend namelist "[expr $pos+1][join [$sel get name]]"
	       }
	    }
	    lappend anglelist $namelist
	 }
      }

      variable tmincludediheds
      if {$tmincludediheds} {
	 set zmatdiheds [get_dependent_zmat_diheds $center $centroid]
	 foreach dihed $zmatdiheds {
	    set namelist {}
	    foreach atom [lindex $dihed 2] {
	       set sel [atomselect $molidbase "index $atom"]
	       if {$atom==$center} {
		  lappend namelist "[expr [llength $tmligands]+1][join [$sel get name]]"
	       } else {
		  set pos [lsearch $tmligands "* [join [$sel get {resid segid}]] *"]
		  lappend namelist "[expr $pos+1][join [$sel get name]]"
	       }
	    }
	    lappend dihedlist $namelist
	 }
      }

      variable tmincludeimprps
      if {$tmincludeimprps} {
	 set zmatimprps [get_dependent_zmat_imprps $center $centroid]
	 foreach dihed $zmatimprps {
	    set namelist {}
	    foreach atom [lindex $dihed 2] {
	       set sel [atomselect $molidbase "index $atom"]
	       if {$atom==$center} {
		  lappend namelist "[expr [llength $tmligands]+1][join [$sel get name]]"
	       } else {
		  set pos [lsearch $tmligands "* [join [$sel get {resid segid}]] *"]
		  lappend namelist "[expr $pos+1][join [$sel get name]]"
	       }
	    }
	    lappend imprplist $namelist
	 }
      }
      incr ilig
   }
   set anglelist [lsort -unique $anglelist]
   set dihedlist [lsort -unique $dihedlist]

   set sbondlist {}
   set dbondlist {}
   set tbondlist {}
   foreach bond $bondlist {
      switch [lindex $bond 2] {
	 1 { lappend sbondlist [lindex $bond 0] [lindex $bond 1] }
	 2 { lappend dbondlist [lindex $bond 0] [lindex $bond 1] }
	 3 { lappend tbondlist [lindex $bond 0] [lindex $bond 1] }
	 SING { lappend sbondlist [lindex $bond 0] [lindex $bond 1] }
	 DOUB { lappend dbondlist [lindex $bond 0] [lindex $bond 1] }
	 TRIP { lappend tbondlist [lindex $bond 0] [lindex $bond 1] }
      }
   }

   foreach {b11 b12 b21 b22 b31 b32 b41 b42} $sbondlist {
      puts $fid [format "BOND %4s %4s  %4s %4s  %4s %4s  %4s %4s" $b11 $b12 $b21 $b22 $b31 $b32 $b41 $b42]  
   }

   foreach {b11 b12 b21 b22 b31 b32 b41 b42} $dbondlist {
      puts $fid [format "DOUBLE %4s %4s  %4s %4s  %4s %4s  %4s %4s" $b11 $b12 $b21 $b22 $b31 $b32 $b41 $b42]  
   }

   foreach {b11 b12 b21 b22 b31 b32 b41 b42} $tbondlist {
      puts $fid [format "TRIPLE %4s %4s %4s %4s %4s %4s %4s %4s" $b11 $b12 $b21 $b22 $b31 $b32 $b41 $b42]  
   }

   foreach {a1 a2 a3 b1 b2 b3 c1 c2 c3} [join $anglelist] {
      puts $fid [format "ANGLE %4s %4s %4s   %4s %4s %4s   %4s %4s %4s" $a1 $a2 $a3 $b1 $b2 $b3 $c1 $c2 $c3]  
   }

   foreach {a1 a2 a3 a4 b1 b2 b3 b4} [join $dihedlist] {
      puts $fid [format "DIHED %4s %4s %4s %4s   %4s %4s %4s %4s" $a1 $a2 $a3 $a4 $b1 $b2 $b3 $b4]  
   }

   foreach {a1 a2 a3 a4 b1 b2 b3 b4} [join $imprplist] {
      puts $fid [format "IMPR %4s %4s %4s %4s   %4s %4s %4s %4s" $a1 $a2 $a3 $a4 $b1 $b2 $b3 $b4]  
   }

   #write_charmmtop_resi $fid PRES $tmpatchname $patchcharge $atomlist $bondlist $anglelist $dihedlist $imprplist $comment
   puts $fid ""
   puts $fid END

   close $fid
   variable patchtopology $file
   variable newtopofile $file
}

proc ::Paratool::check_oldtype_params {entry oldtype newtype} {
   variable paramsetlist
   # Get types for the conformation
   set indexes [lindex $entry 2]
   set typelist [get_types_for_conf $indexes]
   set oldtypelist {}
   foreach type $typelist {
      if {$type==$newtype} {
	 lappend oldtypelist $oldtype
      } else {
	 lappend oldtypelist $type
      }
   }

   set bondedpar {}
   set conftype [lindex $entry 1]
   foreach paramset $paramsetlist {
      if {[string match "*bond" $conftype]} {
	 set bondedpar [::Pararead::getbondparam [lindex $paramset 0] $oldtypelist]
      } elseif {[regexp  "angle|lbend" $conftype] } {
	 set bondedpar [::Pararead::getangleparam [lindex $paramset 1] $oldtypelist]
      } elseif {[string equal $conftype "dihed"]} {
	 set bondedpar [::Pararead::getdihedparam [lindex $paramset 2] $oldtypelist]
      } elseif {[string equal $conftype "imprp"]} {
	 set bondedpar [::Pararead::getimproparam [lindex $paramset 3] $oldtypelist]
      }
      if {[llength [join $bondedpar]]} { break }
   }

   if {[llength [join $bondedpar]]} {
      return [list [lindex $bondedpar 1] $oldtypelist $typelist]
   } else {
      if {[llength [lindex $entry 4]]} {
	 return [list [lindex $entry 4] $oldtypelist $typelist]
      } else {
	 return {}
      }
   }
   return {}
}

proc ::Paratool::write_tmcomplex_parameters {file {temporary "-permanent"}} {
   variable tmpatchname
   if {![llength $tmpatchname]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please specify residue patch name!"
      return 0
   } else {
      verify_patchname
   }

   # In case the topology was not yet generated, we have to rename the centroids
   variable tmnewtypes
   rename_centroids
   variable tmnewtypes [lsort -unique $tmnewtypes]


   set fid [open $file w]

   write_charmm_para_header $fid

   variable paramsetfiles
   puts $fid "! Parameters for PRES $tmpatchname"
   puts $fid "! To be used in combination with:"
   foreach parafile $paramsetfiles {
      puts $fid "! $parafile"
   }

   variable zmat
   variable molidbase
   variable tmnewtypes
   variable paramsetlist
   set zmatbonds {}
   set zmatangles {}
   set zmatdiheds {}
   set zmatimprps {}
   set nonbondedlist {}

   # The minimum set of parameters that we have to consider are the ones involving 
   # the bonds between center and ligands:
   foreach {zmatbonds zmatangles zmatdiheds zmatimprps} [get_params_for_centerbonds] {}

   # Further we consider conformations involving renamed types and copy the respective 
   # parameter entries that exist already in the force field accordingly.
   foreach atom $tmnewtypes {
      set segid   [lindex $atom 0]
      set resid   [lindex $atom 1]
      set name    [lindex $atom 2]
      set oldtype [lindex $atom 3]
      set newtype [lindex $atom 4]
      set sel [atomselect $molidbase "segid $segid and resid $resid and name $name"]
      set resname [$sel get resname]

      set atomlist  {}
      set bonds {}
      set angles {}
      set diheds {}
      set imprs {}
      set oldparams {}
      foreach paramset $paramsetlist {
	 set  bonds  [lsearch -all -regexp -inline [lindex $paramset 0] \
			 "^\{(($oldtype\\s.+)|(.+\\s$oldtype))\}\\s.+"]
	 set  angles [lsearch -all -regexp -inline [lindex $paramset 1] \
			 "^\{(($oldtype\\s.+)|(.+\\s$oldtype\\s.+)|(.+\\s$oldtype))\}\\s.+"]
	 set  diheds [lsearch -all -regexp -inline [lindex $paramset 2] \
			 "^\{(($oldtype\\s.+)|(.+\\s$oldtype\\s.+)|(.+\\s$oldtype))\}\\s.+"]
	 set  imprps [lsearch -all -regexp -inline [lindex $paramset 3] \
			 "^\{(($oldtype\\s.+)|(.+\\s$oldtype\\s.+)|(.+\\s$oldtype))\}\\s.+"]

	 foreach bond $bonds {
	    set newtypelist {}
	    foreach type [lindex $bond 0] {
	       if {$type==$oldtype} {
		  lappend newtypelist $newtype
	       } else {
		  lappend newtypelist $type
	       }
	    }
	    lappend zmatbonds [list [list {} {bond} {x x} {} [lindex $bond 1] X $newtypelist]]
	 }
	 foreach angle $angles {
	    set newtypelist {}
	    foreach type [lindex $angle 0] {
	       if {$type==$oldtype} {
		  lappend newtypelist $newtype
	       } else {
		  lappend newtypelist $type
	       }
	    }
	    lappend zmatangles [list [list {} {angle} {x x x} {} [lindex $angle 1] X $newtypelist]]
	 }
	 foreach dihed $diheds {
	    set newtypelist {}
	    foreach type [lindex $dihed 0] {
	       if {$type==$oldtype} {
		  lappend newtypelist $newtype
	       } else {
		  lappend newtypelist $type
	       }
	    }
	    lappend zmatdiheds [list [list {} {dihed} {x x x x} {} [lindex $dihed 1] X $newtypelist]]
	 }
	 foreach imprp $imprps {
	    set newtypelist {}
	    foreach type [lindex $imprp 0] {
	       if {$type==$oldtype} {
		  lappend newtypelist $newtype
	       } else {
		  lappend newtypelist $type
	       }
	    }
	    lappend zmatimprps [list [list {} {imprp} {x x x x} {} [lindex $imprp 1] X $newtypelist]]
	 }
      }


      # Finally we must consider conformations involving the renamed centroid that
      # are not contained in the force field. We autogenerate a Z-matrix for each residue,
      # it will consist of a complete set of bonds, angles and diheds. This assures that all 
      # conformations that are possible based on the current VD-bonding pattern are represented
      # in the parameter file.
      set index [join [$sel get index]]
      set czmat [modredundant_zmat "segid $segid and resid $resid" 0]

      set bonds [lsearch -inline -regexp -all $czmat ".+bond\\s\{(($index\\s.+)|(.+\\s$index))\}"]
      foreach entry $bonds {
  	 set bondedpar [check_oldtype_params $entry $oldtype $newtype]
  	 set typelist [lindex $bondedpar 2]
  	 set params   [lindex $bondedpar 0]
      	 if {[llength $typelist]} {
      	    lappend zmatbonds [list [list B0 {bond} {x x} {} $params X $typelist]]
      	 }	 
      }

      set angles [lsearch -inline -regexp -all $czmat \
		     ".+(angle|lbend)\\s\{(($index\\s.+)|(.+\\s$index\\s.+)|(.+\\s$index))\}"]
      foreach entry $angles {
  	 set bondedpar [check_oldtype_params $entry $oldtype $newtype]
  	 set typelist [lindex $bondedpar 2]
  	 set params   [lindex $bondedpar 0]
   	 if {[llength $typelist]} {
   	    lappend zmatangles [list [list A0 {angle} {x x x} {} $params X $typelist]]; 
   	 }	 
      }

      set diheds [lsearch -inline -regexp -all $czmat ".+dihed\\s\{(($index\\s.+)|(.+\\s$index\\s.+)|(.+\\s$index))\}"]
      foreach entry $diheds {
  	 set bondedpar [check_oldtype_params $entry $oldtype $newtype]
  	 set typelist [lindex $bondedpar 2]
  	 set params   [lindex $bondedpar 0]
  	 if {[llength $params]} {
  	    lappend zmatdiheds [list [list D0 {dihed} {x x x x} {} $params X $typelist]];
  	 }	 
      }

      # modredundant_zmat does not generate imprps thus we can only use the ones which are already 
      # defined in $zmat
      set imprps [lsearch -inline -regexp -all $zmat ".+imprp\\s\{(($index\\s.+)|(.+\\s$index\\s.+)|(.+\\s$index))\}"]
      foreach entry $imprps {
       	 set bondedpar [check_oldtype_params $entry $oldtype $newtype]
	 set typelist [lindex $bondedpar 2]
       	 set params [lindex $bondedpar 0]
       	 if {[llength $params]} {
       	    lappend zmatimprps [list [list O0 {imprp} {x x x x} {} $params X $typelist]]
	 }	 
      }
      $sel delete
    }

   write_bond_parameters  $fid [lsort -unique [join $zmatbonds]]

   if {[llength [join $zmatangles]]} {
      write_angle_parameters $fid [lsort -unique [join $zmatangles]]
   }

   if {[llength [join $zmatdiheds]]} {
      write_dihed_parameters $fid [lsort -unique [join $zmatdiheds]]
   }

   if {[llength [join $zmatimprps]]} {
      write_imprp_parameters $fid [lsort -unique [join $zmatimprps]]
   }


   # Loop over all atoms of the complex
   set sel [atomselect $molidbase "curcomplex or ligands"]
   foreach i [$sel list] type [$sel get type] resid [$sel get resid] segid [$sel get segid] {
      if {![llength $type] || $type=={}} { 
	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
	    -message "Empty type name found in $segid:$resid! Please specify all type names."
	 return $index
      }
      
      set newtype [join [get_types_for_conf $i]]
      set comment ""
      if {$newtype!=$type} {
	 set comment "same as $type"
	 set type $newtype
      }
      
      # Check if current type exists in one of the parameter files
      set nonbonpar {}
      foreach paramset $paramsetlist {
	 set nonbonpar [::Pararead::getvdwparam $paramset $type]
	 if {[llength $nonbonpar]} { break }
      }
      
      # If this is a new type, we add it to the nonbonded list
      if {![llength $nonbonpar] && [lsearch $nonbondedlist "$type *"]<0} {
	 set vdweps [get_atomprop VDWeps $i]
	 set vdwrmin [get_atomprop VDWrmin $i]
	 set vdweps14 [get_atomprop VDWeps14 $i]
	 set vdwrmin14 [get_atomprop VDWrmin14 $i]
	 if {![llength $vdweps] || ![llength $vdwrmin]} {
	    tk_messageBox -icon error -type ok -title Message -parent .paratool \
	       -message "Empty VDW field found in $segid:$resid! Please specify all VDW parameters."
	    return
	 }
	 lappend nonbondedlist [list $type $vdweps $vdwrmin $vdweps14 $vdwrmin14 $comment]
      }
   }
   $sel delete

   write_nonb_parameters $fid $nonbondedlist

   puts $fid "\nEND"
   close $fid
   if {$temporary!="-temporary"} { variable newparamfile $file }
}


#############################################################
# Generate the parameters for all conformations involving   #
# bonds between center and centroids.                       #
#############################################################

proc ::Paratool::get_params_for_centerbonds {} {
   variable molidbase
   variable tmligands
   variable tmincludeangles
   variable tmincludediheds
   variable tmincludeimprps
   variable zmat
   set zmatbonds {}
   set zmatangles {}
   set zmatdiheds {}
   set zmatimprps {}

   foreach lig $tmligands {
      set segid     [lindex $lig 2]
      set resid     [lindex $lig 1]
      set resname   [lindex $lig 0]
      set centroid  [lindex $lig 3]
      set centerdef [lindex $lig 4]
      set ligandsel [atomselect $molidbase "segid $segid and resid $resid"]
      set centersel [atomselect $molidbase "segid [lindex $centerdef 0] and resid [lindex $centerdef 1] and name [lindex $centerdef 2]"]
      set center [join [$centersel list]]

      set bonds [lsearch -inline -regexp -all $zmat ".+bond\\s{(($center\\s$centroid)|($centroid\\s$center))}"]
      if {[llength $bonds]} { lappend zmatbonds $bonds }

      if {$tmincludeangles} {
	 set angles [get_dependent_zmat_angles $center $centroid]
	 if {[llength $angles]} { lappend zmatangles $angles }
      }

      if {$tmincludediheds} {
	 set diheds [get_dependent_zmat_diheds $center $centroid]
	 if {[llength $diheds]} { lappend zmatdiheds $diheds }
      }

      if {$tmincludeimprps} {
	 set imprps [get_dependent_zmat_imprps $center $centroid]
	 if {[llength $imprps]} { lappend zmatimprps $imprps }
      }

      $ligandsel delete
      $centersel delete
   }

   return [list $zmatbonds $zmatangles $zmatdiheds $zmatimprps]
}


proc ::Paratool::get_dependent_zmat_angles {ind0 ind1} {
   variable zmat
   set ilist "(($ind0\\s$ind1\\s.+)|(.+\\s$ind0\\s$ind1)|($ind1\\s$ind0.+)|(.+$ind1\\s$ind0))"
   return [lsearch -inline -regexp -all $zmat "(angle|lbend)\\s+\\{$ilist\\}"]
}

proc ::Paratool::get_dependent_zmat_diheds {ind0 ind1} {
   variable zmat
   set    ilist "((.+\\s$ind0\\s$ind1)|(.+\\s$ind0\\s$ind1\\s.+)|($ind0\\s$ind1\\s.+)"
   append ilist "|(.+\\s$ind1\\s$ind0)|(.+\\s$ind1\\s$ind0\\s.+)|($ind1\\s$ind0\\s.+))"
   return [lsearch -inline -regexp -all $zmat "dihed\\s{$ilist}"]
}

proc ::Paratool::get_dependent_zmat_imprps {ind0 ind1} {
   variable zmat
   set    ilist "((.+\\s$ind0\\s$ind1)|(.+\\s$ind0\\s$ind1\\s.+)|($ind0\\s$ind1\\s.+)"
   append ilist "|(.+\\s$ind1\\s$ind0)|(.+\\s$ind1\\s$ind0\\s.+)|($ind1\\s$ind0\\s.+))"
   return [lsearch -inline -regexp -all $zmat "imprp\\s{$ilist}"]
}

proc ::Paratool::rename_centroids {} {
   variable tmligands
   variable tmnewtypes
   variable molidbase

   variable topologylist
   set masslist {}
   foreach topo $topologylist {
      lappend masslist [::Toporead::topology_get types $topo]
   }
   set masslist [join $masslist]

   set alltypelist {}
   foreach massentry $masslist {
      lappend alltypelist [lindex $massentry 0]
   }


   # Loop over all ligand types
   set ligtypes {}
   set newmasslist {}
   foreach ligand $tmligands {
      set resname  [lindex $ligand 0]
      set resid    [lindex $ligand 1]
      set segid    [lindex $ligand 2]
      set centroid [lindex $ligand 3]

      set sel [atomselect $molidbase "index $centroid"]
      set type [join [$sel get type]]
      lappend ligtypes $type
      $sel delete
   }

   foreach ligand $tmligands {
      set resid    [lindex $ligand 1]
      set segid    [lindex $ligand 2]
      set centroid [lindex $ligand 3]
      set sel [atomselect $molidbase "index $centroid"]
      set type [join [$sel get type]]

      if {[llength [lsearch -all $ligtypes "$type"]]>1} {
	 set newtype [find_new_typename $resid $segid [string range $type 0 2] $alltypelist]
	 puts "Assigned unique type for centroid $resname: $type -> $newtype"
#	 set_atomprop Type [join [$sel get index]] $newtype

	 lappend alltypelist $newtype
	 lappend tmnewtypes [join [list [join [$sel get {segid resid name type}]] $newtype]]
	 set comment "Type $type renamed for complex binding"
	 lappend newmasslist [list $newtype [::QMtool::atomnum2element [join [$sel get atomicnumber]]] $comment]
      }
      $sel delete
   }
   return $newmasslist
}


proc ::Paratool::write_anglelist { subzmat } {
   if {$nangles!=[count_all_angles]} {
      write_explicit_angles
   }
}
 
proc ::Paratool::count_all_angles { zmat } {
   return [llength [generate_all_angles $zmat]]
}

proc ::Paratool::count_all_diheds { zmat } {
   return [llength [generate_all_diheds $zmat]]
}


####################################################################
# Write a psfgen input file and, if requested by -build, also run  #
# psfgen with this file.                                           #
# It is assumed that basemolecule contains a metal complex or      #
# iron-sulfur cluster. The patch connecting the ligands with the   #
# center is applied.                                               #
# If newtopofile is not specified, then return with a warning.     #
# We are going to use LIG$i as the segid since the segments of the #
# isolated molecule don't mach the one from the original context.  #
####################################################################

proc ::Paratool::write_tm_psfgen_input { file args } {
   variable topologyfiles
   variable patchtopology
   variable tmpatch
   variable tmligands
   if {![llength $patchtopology]} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "You must first write the patch topology file."
      return 0      
   }
   set build 0
   if {[lsearch $args "-build"]>=0} { set build 1 }

   variable tmimdtopology
   if {!$tmimdtopology} {
      rename_imitohis
   }

   if {!$tmimdtopology} {
      rename_histoimi
   }

   set fid [open $file w]
   puts $fid "package require psfgen"
   puts $fid "psfcontext new delete"

   foreach topfile $topologyfiles {
      puts $fid "topology $topfile"
   }
   puts $fid "topology $patchtopology"
   puts $fid ""

   variable molidbase
   variable molnamebase
   set sel [atomselect $molidbase all]
   set segidlist [lsort -unique [$sel get segid]]
   $sel delete
   variable tmsegrestrans {}
   set i 1
   foreach ligand $tmligands {
      set segid [lindex $ligand 2]
      set resid [lindex $ligand 1]
      # We are going to use LIG$i as the segid since the segments of the isolated
      # molecule don't mach the one from the original context.
      # array segrestrans is used as a lookup table
      set newsegid "LIG$i"
      lappend tmsegrestrans "$segid:$resid" $newsegid
      set segsel [atomselect $molidbase "segid $segid and resid $resid"]
      set segfile [file rootname $molnamebase]_$newsegid.pdb
      $segsel writepdb $segfile
      $segsel delete
      puts $fid "segment $newsegid {"
      puts $fid "  pdb $segfile"
      puts $fid "}"
      puts $fid "coordpdb $segfile $newsegid"
      puts $fid ""
      incr i
   }
   set sel [atomselect $molidbase "curcomplex"]
   set segid   [join [lsort -unique [$sel get segid]]]
   set resid   [join [lsort -unique [$sel get resid]]]
   set newsegid "CENT"
   lappend tmsegrestrans "$segid:$resid" $newsegid
   set segfile [file rootname $molnamebase]_$newsegid.pdb
   $sel writepdb $segfile
   $sel delete
   puts $fid "segment $newsegid {"
   puts $fid "  pdb $segfile"
   puts $fid "}"
   puts $fid "coordpdb $segfile $newsegid"
   puts $fid ""

   # Apply the patch connecting the ligands with the center
   array set sgt $tmsegrestrans
   puts -nonewline $fid "patch [lindex $tmpatch 0]"
   foreach segres [lrange $tmpatch 1 end] {
      puts -nonewline $fid " [lindex [array get sgt $segres] 1]:[lindex [split $segres :] 1]"
   }
   puts $fid ""
   # Print the segname lookup table as comment
   puts $fid "\# The segment names in this build correspond to the following segid:resid pairs"
   puts $fid "\# in the original molecule:"
   foreach segres [lrange $tmpatch 1 end] {
      puts $fid "\# $segres [lindex [array get sgt $segres] 1]:[lindex [split $segres :] 1]"
   }
   puts $fid ""
   puts $fid "writepsf [file rootname $file].psf"
   puts $fid "writepdb [file rootname $file].pdb"
   close $fid

   if {$build} {
      source $file
      variable psf [file rootname $file].psf
      variable pdb [file rootname $file].pdb
      mol new $psf
      mol addfile $pdb   

      variable exclusions
      if {[llength $exclusions]} {
	 write_exclusions [file rootname $::Paratool::molnamebase].psf $exclusions
      }
   }

   return $tmsegrestrans
}


proc ::Paratool::rename_histoimi {} {
   variable molidbase
   set hsd [atomselect $molidbase "ligandres and resname HSD"]
   foreach i [$hsd list] {
      set_atomprop Rname $i IMD
   }
   $hsd delete
   set hse [atomselect $molidbase "ligandres and resname HSE"]
   foreach i [$hse list] {
      set_atomprop Rname $i IME
   }
   $hse delete
}

proc ::Paratool::rename_imitohis {} {
   variable molidbase
   set hsd [atomselect $molidbase "ligandres and resname IMD"]
   foreach i [$hsd list] {
      set_atomprop Rname $i HSD
   }
   $hsd delete
   set hse [atomselect $molidbase "ligandres and resname IME"]
   foreach i [$hse list] {
      set_atomprop Rname $i HSE
   }
   $hse delete
}

proc ::Paratool::exclusions_gui {} {
   if {[winfo exists .paratool_exclusions]} {
      set geom [wm geometry .paratool_exclusions]
      wm withdraw  .paratool_exclusions
      wm deiconify .paratool_exclusions
      wm geometry  .paratool_exclusions $geom
      return
   }

   set w [toplevel ".paratool_exclusions"]
   wm title $w "Explicit nonbonded exclusions"
   wm resizable $w 1 1

   wm protocol .paratool_exclusions WM_DELETE_WINDOW {
      destroy .paratool_exclusions
   }

   choose_analog_parameters

   variable selectcolor
   variable fixedfont
   labelframe $w.pairs -bd 2 -relief ridge -text "Excluded pairs" -padx 2m -pady 2m
   #label $w.types.format -font $fixedfont -textvariable ::Paratool::exclusionsformat \
   #   -relief flat -bd 2 -justify left;

   frame $w.pairs.list
   
   scrollbar $w.pairs.list.scroll -command "$w.pairs.list.list yview" -takefocus 0
   listbox $w.pairs.list.list -yscroll "$w.pairs.list.scroll set" -font $fixedfont \
      -width 40 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::exclusions
   pack $w.pairs.list.list    -side left -fill both -expand 1
   pack $w.pairs.list.scroll  -side left -fill y    -expand 0
   #pack $w.pairs.format  -anchor w
   pack $w.pairs.list    -expand 1 -fill both

   frame  $w.pairs.buttons
   button $w.pairs.buttons.add -text "Add"    -command {
      # We must have an atomselection!
      if {![info exist ::Atomedit::paratool_atomedit_selection]} { return }

      set indexlist $::Atomedit::paratool_atomedit_selection
      if {[llength $indexlist]==2} {
	 if {[lsearch -regexp $::Paratool::exclusions "($indexlist|[lrevert $indexlist])"]<0} {
	    lappend ::Paratool::exclusions $indexlist
	    .paratool_exclusions.pairs.list.list selection clear 0 end
	    .paratool_exclusions.pairs.list.list selection set end
	    .paratool_exclusions.pairs.list.list see end
	    set ::Paratool::tmexclusion "custom"
	 }
      }
   }
   button $w.pairs.buttons.delete -text "Delete" -command {
      foreach i [.paratool_exclusions.pairs.list.list curselection] {
	 .paratool_exclusions.pairs.list.list delete $i
	 .paratool_exclusions.pairs.list.list selection set active
	 set pair [lindex $::Paratool::exclusions [.paratool_exclusions.pairs.list.list curselection]]
	 ::Paratool::select_atoms $pair 
	 set ::Paratool::tmexclusion "custom"
      }
   }
   button $w.pairs.buttons.delall -text "Delete all" -command {
      .paratool_exclusions.pairs.list.list delete 0 end
      set ::Paratool::tmexclusion "none"
   }
   pack $w.pairs.buttons.add $w.pairs.buttons.delete $w.pairs.buttons.delall -side left -expand 1 -fill x
   pack $w.pairs.buttons
   pack $w.pairs -padx 1m -pady 1m -expand 1 -fill both

   frame $w.policy
   label $w.policy.label -text "Explicit nonbonded exclusions within the complex:"
   set m [tk_optionMenu $w.policy.menu ::Paratool::tmexclusion \
	     "none" "custom" "1-4" "1-5" "1-6" "1-7" "1-8" "1-9"]
   for {set i 0} {$i<=[$m index end]} {incr i} {
      $m entryconfigure $i -command ::Paratool::set_exclusion_policy
   }
   pack  $w.policy.label $w.policy.menu -side left -anchor w
   pack $w.policy

   bind $w.pairs.list.list <<ListboxSelect>> {
      set pair [lindex $::Paratool::exclusions [%W curselection]]
      ::Paratool::select_atoms $pair 
   }

   bind $w <FocusIn> {
      focus .paratool_exclusions.pairs.list.list
   }

   # Initialize list
   ::Paratool::set_exclusion_policy
}

proc ::Paratool::set_exclusion_policy {} {
   variable molidbase
   variable tmexclusion
   variable tmligands
   set n [string index $tmexclusion 2]
   if {[string is integer $n]} {
      variable exclusions {}
      set sel [atomselect $molidbase "curcomplex"]
      foreach center [$sel list] {
	 foreach atom [::util::bondedsel $molidbase $center $center -maxdepth $n] {
	    if {$atom!=$center} {
	       lappend exclusions [list $center $atom]
	    }
	 }
      }
      $sel delete
      
      foreach ligand $tmligands {
	 set centroid [lindex $ligand 3]
	 foreach atom [::util::bondedsel $molidbase $centroid $centroid -maxdepth $n] {
	    if {$atom!=$centroid} {
	       lappend exclusions [list $centroid $atom]
	    }
	 }
      }
   }
}