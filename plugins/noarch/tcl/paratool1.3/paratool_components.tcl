#
# Routines for the Chemical Component Finder
#
# Author: Jan Saam
#

proc ::Paratool::init_componentlist {} {
   variable compidlist {}
   variable compdatalist {}
   variable molidbase
   variable molidparent

   # Select unparametrized components
   set sel {}
   if {$molidbase>=0} { 
      set sel [atomselect $molidbase "unparametrized"]
      if {![$sel num]} {
	 $sel delete
	 set sel [atomselect $molidbase "all"]
      }
   } elseif {$molidparent>=0} { 
      set sel [atomselect $molidparent "unparametrized"]
   } else { return 0 }

   variable topologylist
   set resilist {}
   foreach topo $topologylist {
      lappend resilist [::Toporead::topology_get resnames $topo]
   }
   set resilist [join $resilist]

   # Only list the resnames that can't be found in the topology files
   foreach resname [lsort -unique [$sel get resname]] {
      if {[lsearch $resilist $resname]<0} { 
	 lappend compidlist $resname
	 lappend compdatalist {}
      }
   }
   $sel delete

   variable compid [lindex $compidlist 0]
   update_component
}

proc ::Paratool::select_component {} {
   variable compid 
   variable compidlist
   variable compdatalist
   set pos [lsearch $compidlist $compid]
   variable compname     [lindex $compdatalist $pos 0]
   variable comptype     [lindex $compdatalist $pos 1]
   variable compformula  [lindex $compdatalist $pos 2]
   variable compsynonyms [lindex $compdatalist $pos 3]
   variable compatomlist [lindex $compdatalist $pos 4]
   variable compbondlist [lindex $compdatalist $pos 5]
}

proc ::Paratool::update_componentlist {} {
   variable molidbase
   variable compidlist
   variable compdatalist

   # Only consider resnames that are not definedd in the topology files
   variable topologylist
   set resilist {}
   foreach topo $topologylist {
      lappend resilist [::Toporead::topology_get resnames $topo]
   }
   set resilist [join $resilist]

   set sel [atomselect $molidbase all]
   set resnamelist {}
   foreach resname [lsort -unique [$sel get resname]] {
      if {[lsearch $resilist $resname]<0} { 
	 lappend resnamelist $resname
      }
   }
   $sel delete

   if {$resnamelist!=$compidlist} {
      # First eliminate deleted compounds
      foreach del [::util::ldiff $compidlist $resnamelist] {
	 set pos [lsearch $compidlist $del]
	 set compidlist   [lreplace $compidlist   $pos $pos]
	 set compdatalist [lreplace $compdatalist $pos $pos]
      }
      # Second we add all new components
      foreach new [::util::lnand $compidlist $resnamelist] {
	 set pos [lsearch $compidlist $new]
	 lappend compidlist   $new
	 lappend compdatalist {}
	 variable compid $new
	 select_component
      }
   }

   # Clear and refill the menu
   set m .components.comp.s.identry.menu
   if {[winfo exists $m]} {
      $m delete 0 end
      set i 0
      foreach compid $compidlist {
	 $m add command -label $compid -command { ::Paratool::select_component }      
	 incr i
      }
   }
}
proc ::Paratool::update_component {} {
   variable compid 
   variable compidlist
   variable compdatalist
   variable compname
   variable comptype
   variable compformula
   variable compsynonyms
   variable compatomlist
   variable compbondlist
   if {[llength $compdatalist]} {
      lset compdatalist [lsearch $compidlist $compid] [list $compname $comptype $compformula $compsynonyms $compatomlist $compbondlist]
   }
}

proc ::Paratool::component_finder {} {
   # If already initialized, just turn on
   if { [winfo exists .components] } {
      set geom [winfo geometry .components]
      wm withdraw  .components
      wm deiconify .components
      wm geometry  .components $geom
      return
   }

   init_componentlist

   set w [toplevel ".components"]
   wm title $w "Chemical Component Finder"
   wm resizable $w 0 0

   labelframe $w.info -text "Info"
   label $w.info.text1 -text "You can try to identify an unknown chemical compound by searching for it's resname \
in the Chemical Component Dictionary. Therefore you must specify the path on your computer where Paratool can find it. \
The database must be in mmCIF format. You can download the dictionary from the PDB website." -justify left -wraplength 13c
   label $w.info.text2 -text "Note:\n1) Check the protonation state of the found component! The default might not be \
appropriate for every system.\n2) Beware! Unfortunately some entries in the dictionary are faulty. \
Check manually. \nYou can always use Molefacture to edit molecules." -justify left -wraplength 13c
   pack $w.info.text1 $w.info.text2 -fill x -expand 1 -anchor w -padx 2m -pady 2m

   labelframe $w.db -text "Chemical Component Dictionary"
   label  $w.db.urllabel  -text "URL: "
   entry  $w.db.urlentry  -textvariable ::Paratool::componentdburl -width 50 -relief sunken -justify left
   button $w.db.urlbutton -text "Download" -command { 
      ::Paratool::download_db; 
   }
   grid $w.db.urllabel  -row 1 -column 0 -sticky w  -padx 1m
   grid $w.db.urlentry  -row 1 -column 1 -sticky w  -padx 1m
   grid $w.db.urlbutton -row 1 -column 2 -sticky we -padx 1m

   label  $w.db.pathlabel  -text "Path: "
   entry  $w.db.pathentry  -textvariable ::Paratool::componentdbpath -width 50 -relief sunken -justify left -state readonly
   button $w.db.pathbutton -text "Select" -command { 
      ::Paratool::opendialog compdbpath; 
   }
   grid $w.db.pathlabel  -row 2 -column 0 -sticky w -padx 1m
   grid $w.db.pathentry  -row 2 -column 1 -sticky w -padx 1m
   grid $w.db.pathbutton -row 2 -column 2 -sticky we -padx 1m
 
   labelframe $w.comp -text "Component search"
   frame $w.comp.s
   label  $w.comp.s.idlabel -text "Unknown ID (resname):"
   set m [tk_optionMenu $w.comp.s.identry ::Paratool::compid {}]
   $m delete 0 end
   set i 0
   foreach compid $::Paratool::compidlist {
      $m add radiobutton -label $compid -variable ::Paratool::compid -command { ::Paratool::select_component }
   }
   button $w.comp.s.find -text "Find component" -command {::Paratool::search_component}
   pack $w.comp.s.idlabel -anchor w -side left
   pack $w.comp.s.identry $w.comp.s.find -anchor w -side left -padx 2m

   labelframe $w.comp.r -text "Componont data"
   frame $w.comp.r.f; # need another frame for true left justification
   pack  $w.comp.r.f -anchor w -padx 1m -pady 1m
   set row 0
   label $w.comp.r.f.namelabel -text "Name:"
   label $w.comp.r.f.nameentry -textvariable [namespace current]::compname -justify left
   grid $w.comp.r.f.namelabel -row $row -column 0 -sticky wn
   grid $w.comp.r.f.nameentry -row $row -column 1 -sticky w

   incr row
   label $w.comp.r.f.typelabel -text "Type:"
   label $w.comp.r.f.typeentry -textvariable [namespace current]::comptype -justify left
   grid $w.comp.r.f.typelabel -row $row -column 0 -sticky wn
   grid $w.comp.r.f.typeentry -row $row -column 1 -sticky w

   incr row
   label $w.comp.r.f.formlabel -text "Formula:"
   label $w.comp.r.f.formentry -textvariable [namespace current]::compformula -justify left
   grid $w.comp.r.f.formlabel -row $row -column 0 -sticky w
   grid $w.comp.r.f.formentry -row $row -column 1 -sticky w

   incr row
   label $w.comp.r.f.synolabel -text "Synonym:"
   label $w.comp.r.f.synoentry -textvariable [namespace current]::compsynonyms -justify left
   grid $w.comp.r.f.synolabel -row $row -column 0 -sticky w
   grid $w.comp.r.f.synoentry -row $row -column 1 -sticky w

   frame $w.comp.check
   label $w.comp.check.label -textvariable [namespace current]::compchecktext
   pack $w.comp.check.label -anchor n

   pack $w.comp.s $w.comp.r $w.comp.check -padx 2m -pady 2m -fill x -expand 1

   pack $w.info $w.db $w.comp -padx 1m -pady 1m -fill x -expand 1
}


proc ::Paratool::download_db {} {
   variable componentdburl
   variable workdir
   set dbfile [file tail $componentdburl]
   variable componentdbpath [file join $workdir $dbfile]

   puts "Downloading PDB Chemical Component Dictionary file from URL:\n  $componentdburl"
   puts "to $dbfile."

   vmdhttpcopy $componentdburl $dbfile [expr {4*65536}]
   
   if {[file exists $dbfile] > 0} {
      if {[file size $dbfile] > 0} {
	 puts "PDB Chemical Component Dictionary download complete."
      } else {
	 file delete -force $dbfile
	 puts "Failed to download PDB Chemical Component Dictionary."
      }
   } else {
      puts "Failed to download PDB Chemical Component Dictionary."
   }
}


#######################################################
# Search for the component resname in the dictionary. #
#######################################################

proc ::Paratool::search_component {} {
   variable componentdbpath
   variable compid

   if {![llength $componentdbpath]} {
      tk_messageBox -icon error -type ok -title Message -parent .components \
		     -message "No path for Chemical Component Dictionary specified!"
      return 0
   }
     
   if {![file exists $componentdbpath]} {
      tk_messageBox -icon error -type ok -title Message -parent .components \
		     -message "File $componentdbpath doesn't exist!"
      return 0
   }
     

   set fid [open $componentdbpath r]
   set data [read -nonewline $fid]
   close $fid

   set atomname   {}
   set atomelem   {}
   set atomcharge {}
   variable compatomlist {}
   set bondatom1  {}
   set bondatom2  {}
   set bondorder -1
   variable compbondlist {}

   set found 0
   set section 0
   set loopatoms 0
   set loopbonds 0
   foreach line [split $data \n] {
      # Find the beginning of the entry
      if {![string equal $line "data_${compid}"]} { 
	 if {!$found} { continue }
      }
      set found 1

      # Read header
      set key [lindex $line 0]
      if {$section>0 && [string match "data_*" $key]} { break }
      if {[string equal "\#" $key]} { 
	 incr section
      }
      if {$section==1} {
	 # Read molecule info
	 if {[string equal "_chem_comp.id" $key] && ![string equal $compid [lindex $line 1]]} {
	    set found 0; break
	 } elseif {[string equal "_chem_comp.name" $key]} {
	    variable compname [string trim [lrange $line 1 end] ']
	 } elseif {[string equal "_chem_comp.type" $key]} {
	    variable comptype [lrange $line 1 end]
	 } elseif {[string equal "_chem_comp.formula" $key]} {
	    variable compformula [string trim [lrange $line 1 end] ']
	 } elseif {[string equal "_chem_comp.pdbx_synonyms" $key]} {
	    variable compsynonyms [string trim [lrange $line 1 end] ']
	 } elseif {[string equal "_chem_comp.parent" $key]} {
	    variable compparent [lrange $line 1 end]
	 }
      } elseif {$section==2} {
	 if {[string equal "loop_" $key]} { set loopatoms 1 }
	 if {!$loopatoms} {
	    # Read single atom entries      
	    if {[string equal "_chem_comp_atom.comp_id" $key]} {
	       continue
	    } elseif {[string equal "_chem_comp_atom.atom_id" $key]} {
	       set atomname [strip_enclosing_single_quotes [lindex $line 1]]
	    } elseif {[string equal "_chem_comp_atom.type_symbol" $key]} {
	       set atomelem [lindex $line 1]
	    } elseif {[string equal "_chem_comp_atom.charge" $key]} {
	       set atomcharge [lindex $line 1]
	    }
	 } else {
	    # Read multiple atom entries
	    if {[string match "_chem_comp_atom.*" $key]} { continue }
	    if {$key==$compid} {
	       set atomname   [strip_enclosing_single_quotes [lindex $line 1]]
	       set atomelem   [lindex $line 2]
	       set atomcharge [lindex $line 3]
	       #puts " [list $atomname $atomelem $atomcharge]"
	       lappend compatomlist [list $atomname $atomelem $atomcharge]
	    }
	 }
      } elseif {$section==3} {
	 # Store single atom enty from previous section
	 if {!$loopatoms && [llength $atomname]} {
	    lappend compatomlist [list $atomname $atomelem $atomcharge]
	 }

	 if {[string equal "loop_" $key]} { set loopbonds 1 }

	 if {!$loopbonds} {
	    # Read single bond entries
	    if {[string equal "_chem_comp_bond.comp_id" $key]} {
	       continue
	    } elseif {[string equal "_chem_comp_bond.atom_id_1" $key]} {
	       set bondatom1 [strip_enclosing_single_quotes [lindex $line 1]]
	    } elseif {[string equal "_chem_comp_bond.atom_id_2" $key]} {
	       set bondatom2 [strip_enclosing_single_quotes [lindex $line 1]]
	    } elseif {[string equal "_chem_comp_bond.value_order" $key]} {
	       set bondorder [lindex $line 1]
	    }
	 } else {
	    # Read multiple bond entries
	    if {[string match "_chem_comp_bond.*" $key]} { continue }
	    if {$key==$compid} {
	       set bondatom1  [strip_enclosing_single_quotes [lindex $line 1]]
	       set bondatom2  [strip_enclosing_single_quotes [lindex $line 2]]
	       set bondorder -1
	       switch [lindex $line 3] {
		  SING {set bondorder 1}
		  DOUB {set bondorder 2}
		  TRIP {set bondorder 3}
		  AROM {set bondorder 1.5}
	       }
	       #puts "$bondatom1 $bondatom2: bo=$bondorder"
	       lappend compbondlist [list $bondatom1 $bondatom2 $bondorder]
	    }
	 }
      }
   }
   # Store single bond entry from previous section
   if {!$loopbonds && [llength $bondatom1]} {
      lappend compbondlist [list $bondatom1 $bondatom2 $bondorder]
   }

   if {!$found} {
      tk_messageBox -icon question -type ok -title Message -parent .components \
	 -message "Sorry, there's no component $compid in the dictionary."
      return 0
   }

   # See if we can identify our atom with the one in the db entry
   set nfound [check_component]
   variable molidbase
   set sel  [atomselect $molidbase "unparametrized and resname '$compid'"]
   set nselatoms [$sel num]
   $sel delete
   if {$nfound!=$nselatoms} { 
      tk_messageBox -icon question -type ok -title Message -parent .components \
	 -message "Could not identify all atoms with dictionary entry $compid! \
That probaly means the residue name in your component matches the wrong entry or you have edited your molecule."
      return 0
   }

   puts "All atoms identified."

   update_component
   use_component_info
   return 1
}


proc ::Paratool::strip_enclosing_single_quotes { s } {
   if {[string index $s 0]=="'" && [string index $s end]=="'"} {
      return [string range $s 1 end-1]
   }
   return $s
}

####################################################
# Tries to identify atoms using the database entry.#
####################################################

proc ::Paratool::check_component {} {
   variable compatomlist
   variable compatomnamelist {}

   # Generate a name list for faster searching and correct names
   # with leading digits.
   set i 0
   foreach compatom $compatomlist {
      set name [lindex $compatom 0]
      # CHARMM format does not know atom names with leading digits.
      # We take the leading digits and append them to the name.
      set leadingdigits {}
      if {[regexp {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name leadingdigits]} { 
	 set newname [regsub {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name {}]${leadingdigits}
	 lset compatomlist $i 0 $newname
	 if {$newname!=$name} {
	    puts "Aliased $name -> $newname (CHARMM does not know atom names with leading digits)."
	    set name $newname
	 }
      }
      lappend compatomnamelist $name
      incr i
   }

   variable atomproplist
   variable compid
   variable molidbase
   #set all [atomselect $molidbase all]
   #puts "[$all get {name resid beta}]"
   set sel  [atomselect $molidbase "unparametrized and resname '$compid'"]
   set nfound 0
   foreach name [$sel get name] {      
      set pos [lsearch $compatomnamelist $name] 
      if {$pos>=0} {
	 lreplace $compatomnamelist $pos $pos
	 incr nfound
      }
   }
   variable compchecktext "Could match $nfound of [$sel num] atom names in fragment with $compid."
   $sel delete
   return $nfound
}

#########################################################
# Assigns information found in the database about the   #
# current component to the molecule.                    #
#
#
#########################################################

proc ::Paratool::use_component_info {} {
   variable compatomlist
   variable compbondlist
   variable compatomnamelist
   variable atomproplist
   variable molidbase
   set i 0
   set nfound 0
   foreach atom $atomproplist {      
      set name [get_atomprop Name $i]

      # CHARMM format does not know atom names with leading digits.
      # We take the leading digits and append them to the name.
      # We do the same for leading asterisks (*) because the first name
      # character is interpreted by VMD as the chemical element.
      set leadingdigits {}
      if {[regexp {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name leadingdigits]} { 
	 set newname [regsub {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name {}]${leadingdigits}
	 if {$newname!=$name} {
	    puts "Aliased $name -> $newname (CHARMM does not know atom names with leading digits)."
	    set name $newname
	 }
      }

      set pos [lsearch $compatomnamelist $name]
      if {$pos>=0} {
	 set_atomprop Name  $i $name
      }
      incr i
   }
   atomedit_update_list

   # We still have to alias the names of the atoms with unknown coords (i.e. hydrogens)
   set i 0
   foreach compatom $compatomlist {
      set name [lindex $compatom 0]
      set leadingdigits {}
      if {[regexp {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name leadingdigits]} { 
	 set newname [regsub {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name {}]${leadingdigits}
	 if {$newname!=$name} {
	    lset compatomlist $i 0 $newname
	    puts "Aliased $name -> $newname (CHARMM does not know atom names with leading digits)."
	 }
      }
      incr i
   }

   # Also the bondlist has to be aliased
   set i 0
   foreach compbond $compbondlist {
      set name [lindex $compbond 0]
      set leadingdigits {}
      if {[regexp {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name leadingdigits]} { 
	 set newname [regsub {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name {}]${leadingdigits}
	 if {$newname!=$name} {
    	    set name $newname
	 }
         lset compbondlist $i 0 $name
      }

      set name [lindex $compbond 1]
      set leadingdigits {}
      if {[regexp {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name leadingdigits]} { 
	 set newname [regsub {^([[:digit:]]*\**)|(\**[[:digit:]]*)} $name {}]${leadingdigits}
	 if {$newname!=$name} {
	    set name $newname
	 }
	 lset compbondlist $i 1 $name
      }
      incr i
   }

   # Write a temporary topology file for hydrogen addition
   variable compid
   variable molnamebase
   set basename [regsub {_hydrogen$} [file rootname $molnamebase] {}]
   set sel [atomselect $molidbase "unparametrized and resname '$compid'"]

   # Remove bonds longer than 3.2 A since they are probably due to erroneous Dictionary entries.
   set compbondlist [check_bondlist_sanity $sel $compbondlist]

   # Write a temporary topology file
   write_tmp_topo "paratool_${basename}_${compid}.top" $sel $compatomlist $compbondlist

   # Build the fragment with guessed hydrogen positions
   package require psfgen
   psfcontext new delete

   topology "paratool_${basename}_${compid}.top"
   variable topologylist
   variable topologyfiles
   lappend topologylist [::Toporead::read_charmm_topology "paratool_${basename}_${compid}.top"]
   lappend topologyfiles "paratool_${basename}_${compid}.top"

   # Write the unknown fragment and guess the coords for it
   set segid [lsort -unique [$sel get segid]]
   set resid [lsort -unique [$sel get resid]]
   $sel writepdb "${basename}_${segid}.pdb"
   $sel delete

   segment $segid {
      pdb "${basename}_${segid}.pdb"
   }
   coordpdb "${basename}_${segid}.pdb" $segid
   guesscoord

   writepdb "${basename}_hydrogen.pdb"; # occu 1
   writepsf "${basename}_hydrogen.psf"

   set tmpmolid [mol load psf ${basename}_hydrogen.psf pdb ${basename}_hydrogen.pdb]
   import_bondorders_from_topology $tmpmolid "paratool_${basename}_${compid}.top"

   set all [atomselect $tmpmolid all]
   write_xbgf ${basename}_hydrogen.xbgf $all 

   set heavynum [$all num]
   $all delete
   mol delete $tmpmolid

   # Cleanup tmpfiles
   if {[file exists "${basename}_${segid}.pdb"]} {
      file delete "${basename}_${segid}.pdb"
   }
   if {[file exists "${basename}_hydrogen.psf"]} {
      file delete "${basename}_hydrogen.psf"
   }

   # Merge the new fragment pdb with the other part of the selection
   set molid -1
   variable molidparent
   if {$molidbase>=0}   { set molid $molidbase }
   if {$molidparent>=0} { set molid $molidparent }
   if {$molid>=0} {
      variable fragmentseltext
      variable complexbondlist
      set fragselparent [atomselect $molid "($fragmentseltext) and not (resname '$compid')"]
      ::Paratool::add_selection_to_xbgf "${basename}_hydrogen.xbgf" $fragselparent $complexbondlist
      $fragselparent delete
   }

   # Count the number of atoms in unparametrized fragment
   set oldfragsel [atomselect $molidbase "unparametrized and resname '$compid'"]
   set fragatomnum [$oldfragsel num]
   $oldfragsel delete

   # Replace the current fragment molecule with the new one
   load_basemolecule "${basename}_hydrogen.xbgf"; # "${basename}_hydrogen.psf"

   # We must set the beta of the added hydrogens to 0.5,
   # the unpar fragment to 0.0 and the rest to 1.0.
   set hydro [atomselect $molidbase "occupancy<1"]
   $hydro set beta 0.5
   $hydro delete
   set frag    [atomselect $molidbase "segid $segid and resid $resid"]
   set fragnoh [atomselect $molidbase "segid $segid and resid $resid and occupancy 1"]
   $fragnoh set beta 0
   variable compchecktext
   append compchecktext " Added [expr [$frag num]-$fragatomnum] hydrogens."
   $frag delete
   $fragnoh delete
   #atomedit_update_list

   # Reassign elements and Lewis charges to the new molecule
   assign_atominfo $molidbase $compid $compatomlist
   atomedit_update_list
}

##############################################################
# There are corrupt entries is the Chemical Component        #
# Dictionary. This function tries to identify unlikely bonds #
# i.e. bond that are longer than 3.2 A and removes them from #
# the bondlist.                                              #
##############################################################

proc ::Paratool::check_bondlist_sanity { sel bondlist } {
   set molid [$sel molid]
   set resid [lsort -unique [$sel get resid]]
   if {[llength $resid]!=1} { return -1 }
   set segid [lsort -unique [$sel get segid]]
   if {[llength $segid]!=1} { return -2 }

   set corrupt {}
   set maxbonddist 3.0
   set sanebondlist {}
   foreach bond $bondlist {
      set valence0 [llength [lsearch -all [join $bondlist] [lindex $bond 0]]]
      set valence1 [llength [lsearch -all [join $bondlist] [lindex $bond 1]]]
      if {$valence0>6} { set corrupt [lindex $bond 0]; }
      if {$valence1>6} { set corrupt [lindex $bond 1]; }
      set bondsel [atomselect $molid "segid $segid and resid $resid and name $bond"]
      if {[$bondsel num]==1} { lappend sanebondlist $bond; continue }
      set dist [veclength [vecsub [lindex [$bondsel get {x y z}] 0] [lindex [$bondsel get {x y z}] 1]]]
      if {$dist < $maxbonddist} { 
	 lappend sanebondlist $bond
      } else {
	 puts "WARNING: Bond $bond longer than $maxbonddist Angstom ignored!"
	 set corrupt 1
      }
      $bondsel delete
   }

   if {[llength $corrupt]} {
      variable compid
      tk_messageBox -icon question -type ok -title Message -parent .components \
	 -message "Corrupt bond definitions in Component Dictionary for $compid (Bond longer than $maxbonddist Angstoms)! \
\nIgnoring bad bonds. Please edit bonds manually."
   }
   return $sanebondlist
} 

#############################################################
# Assigns elements and Lewis charges to the specified       #
# molecule.                                                 #
#############################################################

proc ::Paratool::assign_atominfo { molid compid compatomlist } {
   if {![llength $compatomlist]} { return }

   # Create a list of existing atom names for faster searching
   set compatomnamelist {}
   foreach compatom $compatomlist {
      lappend compatomnamelist [lindex $compatom 0]
   }
   set i 0
   set nfound 0
   variable atomproplist
   foreach atom $atomproplist {      
      set name [get_atomprop Name $i]
      set pos [lsearch $compatomnamelist $name] 
      if {$pos>=0} {
	 # Assign the atomproperties
	 set elem [lindex $compatomlist $pos 1]
	 set_atomprop Elem  $i $elem
	 set_atomprop Lewis $i [lindex $compatomlist $pos 2]
	 set sel [atomselect $molid "index [get_atomprop Index $i]"]
	 $sel set atomicnumber [::QMtool::element2atomnum $elem]
	 incr nfound
      }
      incr i
   }
}

#############################################################
# Assigns bonds and bondorders to the specified molecule.   #
#############################################################

proc ::Paratool::assign_bondinfo { molid compid compbondlist } {
   if {![llength $compbondlist]} { return }

   # Create a list of existing atom names for faster searching
   variable atomproplist
   set atomnamelist {}
   foreach atom $atomproplist {
      lappend atomnamelist [lindex $atom 2]
   }

   # Reset the bondlist
   set all [atomselect $molid all]
   set nobonds {}
   foreach i [$all list] { lappend nobonds {} }
   $all setbonds $nobonds

   set i 0
   foreach bond $compbondlist {
      # Look for the atomname of first atom in $atomproplist
      set ind0 [lsearch $atomnamelist [lindex $bond 0]]
      set ind1 [lsearch $atomnamelist [lindex $bond 1]]
      if {$ind0>=0 && $ind1>=0} {
	 # Both atoms are existent, we can set the bond:
	 set sel0 [atomselect $molid "resname '$compid' and name '[string map {' \\'} [lindex $bond 0]]'"]
	 set sel1 [atomselect $molid "resname '$compid' and name '[string map {' \\'} [lindex $bond 1]]'"]
	 if {[$sel0 num]>1} {
	    tk_messageBox -icon error -type ok -title Message -parent .components \
	       -message "Atom name [$sel0 get name] appears twice, but it should be unique!"
	    return 0
	 }
	 if {[$sel1 num]>1} {
	    tk_messageBox -icon error -type ok -title Message -parent .components \
	       -message "Atom name [$sel1 get name] appears twice, but it should be unique!"
	    return 0
	 }

	 set vmdbonds     [join [$sel0 getbonds]]
	 set vmdbondorder [join [$sel0 getbondorders]]
	 lappend vmdbonds [join [$sel1 list]]
	 lappend vmdbondorder [lindex $bond 2]
	 $sel0 setbonds [list $vmdbonds]
	 $sel0 setbondorders [list $vmdbondorder]

	 set vmdbonds     [join [$sel1 getbonds]]
	 set vmdbondorder [join [$sel1 getbondorders]]
	 lappend vmdbonds [join [$sel0 list]]
	 lappend vmdbondorder [lindex $bond 2]

	 $sel1 setbonds      [list $vmdbonds]
	 $sel1 setbondorders [list $vmdbondorder]
      }
      incr i
   }
}

