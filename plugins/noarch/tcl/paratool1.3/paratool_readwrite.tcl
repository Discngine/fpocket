#
# Routines for loading/saving paratool projects, internal coordinates, etc
#
# $Id: paratool_readwrite.tcl,v 1.40 2007/09/12 13:42:49 saam Exp $
#
proc ::Paratool::load_project { file } {
   variable projectname $file
   source $file

   variable topologyfiles
   variable topologylist {}
   variable paramsetfiles
   variable paramsetlist {}
   variable molidparent
   variable molidbase
   variable molidopt
   variable molidsip
   variable molnameparent
   variable molnamebase
   variable molnameopt
   variable molnamesip
   variable workdir [pwd]

   variable zmat
   # Store a copy of the loaded zmat and atomproplist because they get
   # overwritten when the molecules are loaded.
   set tmpzmat $zmat 
   variable atomproplist
   if {[llength [lindex $atomproplist 0]]<23} {
      # In case we are loading an older project file with a smaller number of 
      # atomprops, we must extend the list
      for {set i 0} {$i<23-[llength [lindex $atomproplist 0]]} {incr i} {
	 lappend ext {} 
      }
      foreach atom $atomproplist {
	 lappend tmpatomproplist [concat $atom $ext]
      }
   } else {
      set tmpatomproplist $atomproplist
   }
   set atomproplist $tmpatomproplist

   if {![winfo exists .paratool]} { paratool_gui }

#   if {[llength $workdir]} { cd workdir }
   
   # Load the topologies
   foreach file $topologyfiles {
      lappend topologylist [::Toporead::read_charmm_topology $file]
   }

   variable newtopofile
   if {[llength $newtopofile]} {
      set newtopology [::Toporead::read_charmm_topology $newtopofile]
   }

   # Load the parameters
   foreach file $paramsetfiles {
      lappend paramsetlist [::Pararead::read_charmm_parameters $file]
   }
#    if {[llength $newparamfile]} {
#       set newparamset [::Pararead::read_charmm_parameters $newparamfile]
#    }

   if {$molidparent>=0 && [file exists $molnameparent]} {
      set molidparent -1; load_parentmolecule $molnameparent
   }

   if {$molidbase>=0   && [file exists $molnamebase]}   {
      set molidbase -1;   load_basemolecule   $molnamebase
   }

   if {$molidopt>=0    && [file exists $molnameopt]}    {
      set molidopt -1;    load_molecule OPT   $molnameopt
   }

   if {$molidsip>=0    && [file exists $molnamesip]}    {
      set molidsip -1;    load_molecule SIP   $molnamesip
   }

   variable atomproplist $tmpatomproplist
   set i 0
   foreach atomprop $atomproplist {
      # Reassign Charge and Type through set_atomprop in order to get "{}" for empty fields
      set_atomprop Charge $i [get_atomprop Charge $i]
      set_atomprop Type   $i [get_atomprop Type   $i]
      set found No
      foreach topology $topologylist {
	 if {[::Toporead::topology_contains_type $topology [get_atomprop Type $i]]>=0} {
	    set found Yes; break
	 }
      }
      set_atomprop Known $i $found
      incr i
   }

   # Update the metal complex gui
   find_complex_centers $molidbase silent

   # Restore the loaded zmat
   update_zmat $tmpzmat

   # Lets not trust the internal coordinate values from file but measure them again:
   update_internal_coordinate_values 

   # Determinie rings in the molecule
   variable ringlist [::util::find_rings $molidbase]

   # Update the QM based zmat (implicitely)
   transform_hessian_cartesian_to_internal

   # The zmat got changed by the transform again, so we restore it one more time
   update_zmat $tmpzmat

   # Lets not trust the internal coordinate values from file but measure them again:
   update_internal_coordinate_values 

   update_zmat

   # These molecules have to be reloaded by CHARMMcharge
   set ::CHARMMcharge::molidwater     -1
   set ::CHARMMcharge::molidsyswat    -1
   set ::CHARMMcharge::molidsyswatopt -1
   set ::CHARMMcharge::molnamesyswat    {}
   set ::CHARMMcharge::molnamesyswatopt {}

   variable pickmode "conf"
   variable picklist {}

   if {$molidparent>=0 || $molidbase>=0} {
      # Set explicitly provided bonds
      set_extrabonds
   }
}

proc ::Paratool::save_project { file } {
   variable projectname $file

   set fid [open $file w]

   # Get a list of all variable names in the corresponding namespace:
   set varlist [info vars ::Paratool::*]
   set varlist [concat $varlist [info vars ::CHARMMcharge::*]]

   # Loop over the list and initialize all variables with the values from ::Paratool::
   foreach var $varlist {
      set localvarname $var; #"::Paratool::[namespace tail $var]"
      if {[array exists $localvarname]} {
	 puts $fid "variable $var"
	 if {[array size $localvarname]} {
	    puts $fid "array set $var [list [array get $localvarname]]"
	 } else {
	    puts $fid "array set $var {}"
	 }
      } else {
	 puts $fid "variable $var {[subst $${localvarname}]}"
      }
   }

   # Dump all children namespaces (associated to molecules)
   variable savenamespacelist
   foreach ns $savenamespacelist {

      # Create new namespace
      puts $fid "\nnamespace eval $ns {}"

      # Get a list of all variable names in the corresponding namespace:
      set varlist [info vars ${ns}::*]

      # Loop over the list and initialize all variables with the values from ::Paratool::
      foreach var $varlist {
	 set localvarname $var; #"::Paratool::[namespace tail $var]"
	 if {[array exists $localvarname]} {
	    puts $fid "variable $var"
	    if {[array size $localvarname]} {
	       puts $fid "array set $var [list [array get $localvarname]]"
	    } else {
	       puts $fid "array set $var {}"
	    }
	 } else {
	    puts $fid "variable $var {[subst $${localvarname}]}"
	 }
      }
   }

   close $fid
}   

####################################################
# Writes a selection into a xbgf file and appends  #
# VDW parameters as REMARKs.                       #
####################################################

proc ::Paratool::write_xbgf {xbgffile sel {vdwfields {}}} {
   $sel writexbgf $xbgffile

   # Find the END tag
   set fid [open $xbgffile r+]
   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [gets $fid]
      if {[lindex $line 0]=="END"} { break }
   }
   seek $fid $filepos

   variable molidbase
   if {[llength $vdwfields]} {
      # Here we're omitting VDW_1-4 parameters because we can only use the beta and
      # occupancy fields. But because this feature is currently only used in
      # paratool_charmmcharges for a water molecule this doesn't matter.
      set i 1
      foreach vdw [$sel get $vdwfields] {
	 set vdwrmin [lindex $vdw 0]
	 set vdweps  [lindex $vdw 1]
	 if {[string length $vdweps]}  { set vdweps  [format "%8.4f" $vdweps] }
	 if {[string length $vdwrmin]} { set vdwrmin [format "%8.4f" $vdwrmin] }
	 puts $fid [format "VDW %6i %8s %8s" $i $vdweps $vdwrmin]
	 incr i	 
      }
   } elseif {[$sel molid]==$molidbase} {
      set i 1
      foreach index [$sel list] {
	 set vdweps  [get_atomprop VDWeps $index] 
	 set vdwrmin [get_atomprop VDWrmin $index]
	 set vdweps14  [get_atomprop VDWeps14 $index] 
	 set vdwrmin14 [get_atomprop VDWrmin14 $index]
	 if {[string length $vdweps]}  { set vdweps  [format "%8.4f" $vdweps] }
	 if {[string length $vdwrmin]} { set vdwrmin [format "%8.4f" $vdwrmin] }
	 if {[string length $vdweps14]}  { set vdweps14  [format "%8.4f" $vdweps14] }
	 if {[string length $vdwrmin14]} { set vdwrmin14 [format "%8.4f" $vdwrmin14] }
	 puts $fid [format "VDW %6i %8s %8s %8s %8s" $i $vdweps $vdwrmin $vdweps14 $vdwrmin14]
	 incr i
      }
      set i 1
      foreach index [$sel list] {
	 set lewis [get_atomprop Lewis $index]
	 if {[string length $lewis]} { set lewis [format "%+3i" $lewis] }
	 puts $fid [format "LEWIS %6i %3s" $i $lewis]
	 incr i
      }
   }

   puts $fid "END"

   close $fid
}

####################################################
# This appends a selection to a given xbgf file    #
####################################################

proc ::Paratool::add_selection_to_xbgf {xbgffile sel {extrabonds {}} {vdwfields {}}} {
   if {![$sel num]} { return 0 }

   write_xbgf tempxbgf.xbgf $sel $vdwfields

   set oldxbgf [open "$xbgffile" r]
   set newxbgf [open "tempnewbgf" "w"]
   set tempxbgf [open "tempxbgf.xbgf" r]

   # Copy all atom from the old xbgf to the new one
   set offset 0
   set atomlist {}
   set oldline [gets $oldxbgf]
   while {[regexp {CONECT} $oldline]==0} {
      if {[regexp {^ATOM} $oldline]!=0} { incr offset }
      lappend atomlist [lrange $oldline 1 end]
      puts $newxbgf $oldline
      set oldline [gets $oldxbgf]
   }

   # Put all atoms from tempxbgf into newxbgf while increasing the indexes by $offset
   set line [gets $tempxbgf]
   while {[regexp {CONECT} $line]==0} {
      if {[regexp {^ATOM} $line]!=0} {
	 set currindex [string range $line 7 12]
	 set currindex [expr int($currindex) + $offset]
	 set indexstring [format "%6i" $currindex]
	 set line [string replace $line 7 12 $indexstring]
	 # ignore double defined atoms (they are used to define bonds between the two sets of atoms)
	 #if {[lsearch $atomlist "ATOM  [string range 7 end $line]"]<0} {
	    puts $newxbgf $line
	    lappend atomlist [lrange $line 1 end]
	 #}
      }
      set line [gets $tempxbgf]
   }

   # Generate a bondlist of the extrabonds for which both atoms exist
   set bondlist {}
   foreach bond [lsort -unique $extrabonds] {
      set def [lindex $bond 0]
      set bo  [lindex $bond 1]
      foreach {segid0 resid0 name0} [lindex $def 0] {}
      foreach {segid1 resid1 name1} [lindex $def 1] {}
      #puts "Add to XBGF: $segid0 $resid0 $name0 -- $segid1 $resid1 $name1"
      set pos0 [lsearch -inline -all -regexp $atomlist ".*\\s+$name0\\s+.+\\s+$resid0\\s+.*$segid0\$"]
      set pos1 [lsearch -inline -all -regexp $atomlist ".*\\s+$name1\\s+.+\\s+$resid1\\s+.*$segid1\$"]
      if {[llength $pos0]==1 && [llength $pos1]==1 && $pos0!=$pos1} {
	 lappend bondlist [list [lindex $pos0 0 0] [lindex $pos1 0 0] $bo]
      }
   }

   # Copy CONECT and ORDER records from the old xbgf to the new one
   # and add extrabonds
   set skip {}
   while {[regexp {END|LEWIS|VDW} $oldline]==0} {
      # If $bondlist includes the current atom than modify the record accordingly
      set idx [lindex $oldline 1]
      set mbonds [lsearch -inline -all $bondlist "$idx *"]
      if {[llength $mbonds]>0} {
	 foreach bond $mbonds {
	    if {[lindex $oldline 0]=="CONECT"} {
	       # Make sure we don't consider bonds twice
	       if {[lsearch [lrange $oldline 2 end] [lindex $bond 1]]>=0} { set skip [list $idx $bond]; continue }
	       append oldline [format "%6i" [lindex $bond 1]]
	    } elseif {[lindex $oldline 0]=="ORDER"} {
	       if {$skip==[list $idx $bond]} { continue }
	       append oldline [format "%6.3f" [lindex $bond 2]]
	    }
	 }
      }
      set mbonds [lsearch -inline -all $bondlist "* $idx *"]
      if {[llength $mbonds]>0} {
 	 foreach bond $mbonds {
 	    if {[lindex $oldline 0]=="CONECT"} {
	       # Make sure we don't consider bonds twice
	       if {[lsearch [lrange $oldline 2 end] [lindex $bond 0]]>=0} { set skip [list $idx $bond]; continue }
 	       append oldline [format "%6i" [lindex $bond 0]]
 	    } elseif {[lindex $oldline 0]=="ORDER"} {
	       if {$skip==[list $idx $bond]} { continue }
 	       append oldline [format "%6.3f" [lindex $bond 2]]
 	    }
 	 }
       }

      puts $newxbgf $oldline
      #puts "oldxbgf: $oldline"
      set oldline [gets $oldxbgf]
   }

   # Put all bonds from tempxbgf into newxbgf while increasing the indexes by $offset
   set skip {}
   set line [gets $tempxbgf]
   set line [gets $tempxbgf]
   while {[regexp {END|LEWIS|VDW} $line] == 0} {
     if {[regexp {^(CONECT|ORDER)} $line]!=0} {
        set fields [split $line]
        set fields [lreplace $fields 0 0]
	if {[regexp {^CONECT} $line]} { 
	   set outstring "CONECT"
	   #puts "$fields"
	   foreach field $fields {
	      if {$field == ""} { continue }
	      #puts $field
	      set field [expr [expr int($field)] + $offset]
	      set field [format "%6i" [expr int($field)]]
	      set outstring $outstring$field
	   }
	}
	if {[regexp {^ORDER} $line]} {
	   #set outstring "ORDER"
	   set currindex [string range $line 6 11]
	   if {$field == ""} { continue }
	   set currindex [expr int($currindex) + $offset]
	   set indexstring [format "%6i" $currindex]
	   set outstring [string replace $line 6 11 $indexstring]
	}
	
	# add extrabonds
	set idx [lindex $outstring 1]
	set mbonds [lsearch -inline -all $bondlist "$idx *"]
	if {[llength $mbonds]>0} {
	   foreach bond $mbonds {
	      if {[lindex $outstring 0]=="CONECT"} {
		 # Make sure we don't consider bonds twice
		 if {[lsearch [lrange $oldline 2 end] [lindex $bond 1]]>=0} { set skip [list $idx $bond]; continue }
		 append outstring [format "%6i" [lindex $bond 1]]
	      } elseif {[lindex $outstring 0]=="ORDER"} {
		 if {$skip==[list $idx $bond]} { continue }
		 append outstring [format "%6.3f" [lindex $bond 2]]
	      }
	   }
	}
	set mbonds [lsearch -inline -all $bondlist "* $idx *"]
	if {[llength $mbonds]>0} {
	   foreach bond $mbonds {
	      if {[lindex $outstring 0]=="CONECT"} {
		 # Make sure we don't consider bonds twice
		 if {[lsearch [lrange $oldline 2 end] [lindex $bond 0]]>=0} { set skip [list $idx $bond]; continue }
		 append outstring [format "%6i" [lindex $bond 0]]
	      } elseif {[lindex $outstring 0]=="ORDER"} {
		 if {$skip==[list $idx $bond]} { continue }
		 append outstring [format "%6.3f" [lindex $bond 2]]
	      }
	   }
	}

        puts $newxbgf $outstring
        #puts "xbgf: $outstring"
     }

     set line [gets $tempxbgf]
   }


   # Copy all VDW records from the old xbgf to the new one
   set offset 0
   set atomlist {}
   #set oldline [gets $oldxbgf]
   while {[regexp {END|LEWIS} $oldline]==0} {
      if {[regexp {^VDW} $oldline]!=0} { incr offset }
      puts $newxbgf $oldline
      set oldline [gets $oldxbgf]
   }

   # Put all VDW records from tempxbgf into newxbgf while increasing the indexes by $offset
   #set line [gets $tempxbgf]
   while {[regexp {END|LEWIS} $line]==0} {
      if {[regexp {^VDW} $line]!=0} {
	 set currindex [expr int([lindex $line 1]) + $offset]
	 set indexstring [format "%6i" $currindex]
	 set line [string replace $line 4 9 $indexstring]
	 puts $newxbgf $line
      }
      set line [gets $tempxbgf]
   }

   # Copy all LEWIS records from the old xbgf to the new one
   set offset 0
   set atomlist {}
   #set oldline [gets $oldxbgf]
   while {[regexp {END} $oldline]==0} {
      if {[regexp {^LEWIS} $oldline]!=0} { incr offset }
      puts $newxbgf $oldline
      set oldline [gets $oldxbgf]
   }

   # Put all LEWIS records from tempxbgf into newxbgf while increasing the indexes by $offset
   #set line [gets $tempxbgf]
   while {[regexp {END} $line]==0} {
      if {[regexp {^LEWIS} $line]!=0} {
	 set currindex [expr int([lindex $line 1]) + $offset]
	 set indexstring [format "%6i" $currindex]
	 set line [string replace $line 6 11 $indexstring]
	 puts $newxbgf $line
      }
      set line [gets $tempxbgf]
   }


   puts $newxbgf $line

   close $oldxbgf
   close $newxbgf
   close $tempxbgf

   #file copy $xbgffile old.xbgf
   if {[file exists $xbgffile]} { file delete $xbgffile }
   file copy tempnewbgf $xbgffile
   if {[file exists tempxbgf.xbgf]} { file delete tempxbgf.xbgf }
   if {[file exists tempnewbgf]}    { file delete tempnewbgf }
}


proc ::Paratool::read_intcoords { file {reload {}} } {
   variable cartesians {}
   variable filetype "Paratool internal coordinates"
   variable checkfile {};     # checkpoint file used for the simulation
   variable fromcheckfile {}; # copy simulation checkfile from this file
   variable nproc     {};     # number of processores requested
   variable memory    {};     # amount of memory requested
   variable totalcharge 0.0;   # total system charge
   variable multiplicity {};  # multiplicity
   variable route {}
   variable title {}
   variable nimag {}

   if {![llength $file]} { return 0 }
   
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Didn't find file \"$file\""
      return 0
   }
   
   set fid [open $file r]
   set newzmat {}
   while {![eof $fid]} {
      set line [string trim [gets $fid]]
      if {[lindex $line 0]=="title"}        { set title        [lindex $line 1]; continue }
      if {[lindex $line 0]=="multiplicity"} { set multiplicity [lindex $line 1]; continue }
      if {[lindex $line 0]=="totalcharge"}  { set totalcharge  [lindex $line 1]; continue }
      if {$line=="Cartesian coords:"} { break }
      if {[llength $line]} {
	 lappend newzmat $line
      }
   }
   while {![eof $fid]} {
      set line [string trim [gets $fid]]
      if {[llength $line]} {
	 lappend cartesians $line
      }
   }
   close $fid

   if {$reload=="reload"} {
      puts "read_intcoords: Trying..."
      set newmolid [reload_cartesians_as_pdb "[file rootname $file].pdb"]
      puts "read_intcoords: newmolid=$newmolid"


      # Add new molecule to the list
      if {$newmolid>=0 && [lsearch [molinfo list] $newmolid]>=0} {
	 variable molid $newmolid
      } else {
	 molecule_add $molid
      }
   }

   variable allcartesians $cartesians
   update_zmat
   update_vmd_bondlist
   init_atomproperties
}


proc ::Paratool::write_intcoords { file args } {
   variable zmat
   variable molnamebase
   variable molnameopt
   variable molnamesip
   variable totalcharge 
   variable multiplicity
   variable molidbase
   variable molidopt
   variable molidsip

   set molid -1
   set title {}
   if {[llength $molnamesip]} {
      set molid $molidsip
      set title $molnamesip
   } elseif {[llength $molnameopt]} {
      set molid $molidopt
      set title $molnameopt
   } elseif {[llength $molnamebase]} {
      set molid $molidbase
      set title $molnamebase
   } else { return -1 }

   set all [atomselect $molid all]
   set sel {}
   set newzmat $zmat
   set newcart [$all get {x y z}]
   foreach {i j} $args {
      if {$i=="-sel"}      then { set sel $j; }
      if {$i=="-zmat"}     then { set newzmat $j; }
      if {$i=="-cart"}     then { set newcart $j; }
      if {$i=="-title"}    then { set title $j; }
   }
   puts $title
   set fid [open $file w]
   puts $fid "title $title"
   puts $fid "multiplicity $multiplicity"
   puts $fid "totalcharge $totalcharge"

   if {[llength $sel]} {
      set index 0
      foreach conf $sel {
	 set entry [lindex $newzmat [expr $conf+1]]
	 puts $fid $entry
      }
   } else {
      foreach entry $newzmat {
	 puts $fid $entry
      }
   }

   puts $fid "Cartesian coords:"
   foreach entry $newcart {
      puts $fid $entry
   }
   close $fid
}

proc ::Paratool::read_asn1_file { file } {
   set fid [open $file r]
   set data [read -nonewline $fid]
   close $fid

   if {[lindex $data 0]!="PC-Compound"} { return -1 }
   #set data [split [lindex $data 2] ","]
   set data [string map {, {} \n {}} [lindex $data 2]]
   array set molecule $data
   set cid      [join [lindex [array get molecule cid] 1 1]]
   set atoms    [join [lindex [array get molecule atoms] 1 1]]
   set elements [join [lindex [array get molecule element] 1 1]]
   set charge   [join [lindex [array get molecule charge] 1 1]]
   set props    [join [lindex [array get molecule props] 1 1]]
   set iupac {}
   set smiles {}
   set molweight {}
   foreach prop $props {
      array set urn [lindex $prop 1]
      set label [array get urn label]
      set name  [array get urn name]
      if {$label=="IUPAC Name" && $name=="Preferred"} {
	 set iupac [lindex $prop 2 2]
      } elseif {$label=="SMILES" && $name=="Canonical"} {
	 set smiles [lindex $prop 2 2]
      } elseif {$label=="Molecular Weight"} {
	 set molweight [lindex $prop 2 2]
      }
   }
   array set bondarray [lindex [array get molecule bonds] 1]
   set bondlist {}
   foreach aid1 [array get bondarray aid1] aid2 [array get bondarray aid2] order [array get bondarray order] {
      set bo 0.0
      if {$order==single} { 
	 set bo 1.0 
      } elseif {$order==double} { 
	 set bo 2.0
      } elseif {$order==triple} { 
	 set bo 3.0
      } else { error "::Paratool::read_asn1_file: Unknown bond order $order" }
      lappend bondlist [list $aid1 $aid2 $bo]
   }

   #puts $atoms
}

proc ::Paratool::write_topology {} {
   #set suffix {}
   #foreach resname $::Paratool::compidlist { append suffix "_$resname" }
   #::Paratool::opendialog writetopo "[file rootname ${::Paratool::molnamebase}]$suffix.top"
 
   variable newtopofile
   set file {}
   if {[llength $newtopofile]} {
      set file $newtopofile
   } else { 
      set file "[file rootname ${::Paratool::molnamebase}].top"
   }
   ::Paratool::opendialog writetopo $file
}

proc ::Paratool::write_parameters {} {
   #set suffix {}
   #foreach resname $::Paratool::compidlist { append suffix "_$resname" }	 
   #::Paratool::opendialog writepara "[file rootname ${::Paratool::molnamebase}]$suffix.par"

   variable newparamfile
   set file {}
   if {[llength $newparamfile]} {
      set file $newparamfile
   } else { 
      set file "[file rootname ${::Paratool::molnamebase}].par"
   }
   ::Paratool::opendialog writepara $file
}

proc ::Paratool::namd_testsim {} {
   variable newparamfile
   if {![llength $newparamfile]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "You must first write the new parameter file!"
      return 0
   }

   variable psfgeninputfile
   if {![llength $psfgeninputfile]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "You must first run psfgen!"
      return 0
   }

   # We run psfgen again anyway since the topology might have changed
   write_psfgen_input -file $psfgeninputfile -build -force

   variable psf
   variable pdb
   if {![llength $psf] || ![llength $pdb]} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "You must first run psfgen!"
      return 0
   }

   variable paramsetfiles
   namdgui -par $paramsetfiles -addpar $newparamfile -psf $psf -pdb $pdb -NVT -min 1000 -run 2000
}



##########################################################
# Load the fragment that should be parametrized.         #
##########################################################

proc ::Paratool::load_basemolecule { file {file2 {}}} {
   puts "Loading base molecule $file"

   save_viewpoint_orig
   set newmolid [mol new $file]
   if {[llength $file2]} {
      mol addfile $file2
   }

   variable molidbase
   if {$newmolid>=0} {
      if {$molidbase>=0} { mol delete $molidbase }
      variable molidbase $newmolid
      restore_viewpoint_orig
   } else {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Could not load molecule $file"
      return 0
   }

   variable molnamebase [molinfo $newmolid get name]
   variable natoms      [molinfo $newmolid get numatoms]
   variable projectsaved 0

   # If no psf or xbgf file was loaded we have no realiable type info:
   if {[lsearch -regexp [molinfo $molidbase get filetype] "psf|xbgf"]<0} {
      set all [atomselect $molidbase all]
      $all set type {{}}
      $all delete
   }

   # Undraw all other molecules in VMD:
   variable molidparent
   foreach m [molinfo list] {
      if {$m==$newmolid}    { molinfo $m set drawn 1; continue }
      if {$m==$molidparent && $molidbase<0} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   # Set the representation to Bonds so that we can make use of the new bondorder feature
   variable bondthickness
   mol selection all
   mol representation "Bonds $bondthickness"
   mol modrep 0 $newmolid
   mol representation "VDW $bondthickness"
   mol addrep $newmolid 
   variable fragmentrepbase [mol repname $molidbase 0]

   # Setup a trace on the existence of this molecule
   global vmd_initialize_structure
   trace add variable vmd_initialize_structure($newmolid) write ::Paratool::molecule_assert

   # Setup a trace on the current frame of this molecule
   global vmd_frame
   trace add variable vmd_frame($molidbase) write ::Paratool::update_frame

   init_atomprops $natoms
   import_data_from_molecule $molidbase {Index Elem Name Type Resid Rname Segid Charge}
   variable atompropcanon
   variable atomproptags [concat $atompropcanon Lewis]

   # Populate ForceF charges field
#    set sel [atomselect $molidbase "not unparametrized"]
#    if {[$sel num]} {
#       foreach i [$sel list] charge [$sel get charge] {
# 	 set_atomprop ForceF $i $charge
#       }
#       lappend atomproptags ForceF
#       variable havefofi 1
#    }

   variable copychargetypes
   assign_ForceF_charges
   if {[lsearch $atomproptags ForceF]<0} {
      lappend atomproptags ForceF
   }
   if {[lsearch $copychargetypes ForceF]<0} {
      lappend copychargetypes ForceF
   }
   ::Atomedit::update_copycharge_menu .paratool_atomedit $copychargetypes
   ::CHARMMcharge::update_copycharge_menu  [concat "None" $copychargetypes]
   variable havefofi 1

   foreach remark [split [join [join [molinfo $molidbase get remarks]]] \n] {
      if {[lindex $remark 0]=="VDW"} {
	 set i [expr [lindex $remark 1]-1]
	 set_atomprop VDWeps  $i [lindex $remark 2]
	 set_atomprop VDWrmin $i [lindex $remark 3]
      } elseif {[lindex $remark 0]=="LEWIS"} {
	 set i [expr [lindex $remark 1]-1]
	 set_atomprop Lewis   $i [lindex $remark 2]
      }
   }

   # Set default segids
   set sel [atomselect $molidbase all]
   set segidlist [lsort -unique [join [$sel get segid]]]
   if {![llength $segidlist]} {
      foreach index [$sel get index] {
	 set_atomprop Segid $index PARA
      }
   } elseif {[llength $segidlist]==1} {
      foreach index [$sel get index] segid [$sel get segid] {
	 if {![string length $segid]} {
	    set_atomprop Segid $index [lindex $segidlist 0]
	 }
      }
   }

   if {$molidparent<=0} {
      init_componentlist
      variable compidlist
      if {![llength $compidlist]} {
	 set unparsel [atomselect $molidbase "none"]
      } else {
	 set unparsel [atomselect $molidbase "resname $compidlist"]
      }
      if {[$unparsel num]} {
	 set all [atomselect $molidbase all]
	 $all set beta 1.0
	 $unparsel set beta 0.2
	 #puts "[$unparsel get name]"
	 $all delete
      }
      $unparsel delete

      find_complex_centers $molidbase
   }

   # Determinie rings in the molecule
   variable ringlist [::util::find_rings $molidbase]

   assign_unique_atomnames
   assign_vdw_params
   atomedit_update_list nocomplexcheck

   variable zmat [default_zmat]
   update_zmat

   return $molidbase
}


##########################################################
# Load the QM optimized geometry | frequency calc. |     #
# singlepoint calc.                                      #
##########################################################

proc ::Paratool::load_molecule { type file } {
   switch $type {
      OPT { 
	 puts "Loading geometry optimization $file"
      }
      SCAN { 
	 puts "Loading potential scan $file"
      }
      SIP { 
	 puts "Loading single point calculation $file"
      }
   }
   # Load the new molecule silently:
   set newmolid [::QMtool::load_file $file [string range [file extension $file] 1 end]]

   if {$newmolid<0} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Could not load pdb file $file"
      return 0
   }

   variable natoms
   variable molidbase
   variable molidopt

   if {$natoms && [molinfo $newmolid get numatoms]!=$natoms} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Number of atoms in file $file doesn't match ([molinfo $newmolid get numatoms]:$natoms)!"
      mol delete $newmolid
      variable molidparent
      if {$molidbase>=0}   { molinfo $molidbase set drawn 1; }
      if {$molidparent>=0} { molinfo $molidparent set drawn 1; }
      return 0
   }
   variable natoms [molinfo $newmolid get numatoms]
   variable projectsaved 0

   # We have no reliable type info
   set all [atomselect $newmolid all]
   $all set type {{}}
   $all delete

   # If no basemolecule exists use new molecule as base
   if {$molidbase<0} {
      variable molidbase $newmolid

      # Determinie rings in the molecule
      variable ringlist [::util::find_rings $molidbase]
   }
   # If no optmolecule exists use new molecule as opt
   if {$molidopt<0} {
      variable molidopt $newmolid

      # If no optimized geometry exists, we can assume that the single point
      # run also contains the opt structure. So we append it to the base molecule.
      
      # Delete old appended opt geometry
      if {[molinfo $molidbase get numframes]>1} {
	 animate delete beg 1 $molidbase
      }
      # Duplicate first frame of $molidbase
      animate dup frame 0 $molidbase
      
      # Use optimized coordinates for new frame
      import_cartesians_from_molecule $molidopt
   }

   variable atomproplist
   if {![llength $atomproplist]} {
      init_atomprops $natoms
      import_data_from_molecule $newmolid {Index Elem Name Resid Rname Segid Charge}
   }
      
   switch $type {
      OPT { 
	 variable molidopt $newmolid
	 # The join in the next line is necessary to make it work on windoze, too.
	 variable molnameopt [join [molinfo $newmolid get name]]
	 
	 if {[llength [::QMtool::get_scfenergies]]} {
	    variable scfenergies [::QMtool::get_scfenergies]
	    set ::CHARMMcharge::scfsystem [format {%16.4f} [lindex $scfenergies end 0]]
	 }
	 variable chkfileopt  [::QMtool::get_checkfile]
	 variable optmethod   [::QMtool::get_method]
	 variable optbasisset [::QMtool::get_basisset]
	 variable dipolemoment $::QMtool::dipolemoment
	 # Just in case the user loads a potential scan as optimization:
	 set scanpot {}
	 foreach entry [::QMtool::get_internal_coordinates] {
	    if {[string match "*S*" [lindex $entry 5]]} { 
	       lappend scanpot [list [lindex $entry 0] [lindex $entry 6]]
	    }
	 }
	 
	 if {[llength $scanpot]==1} {
	    variable scanenergies $scfenergies
	    variable qmscanentry [lindex $scanpot 0 0]
	    variable qmscanwidth [lindex $scanpot 0 1 1]
	    variable qmscansteps [lindex $scanpot 0 1 0]
	 } elseif {[llength $scanpot]>1} {
	    puts "WARNING: More than one internal coordinate scanned!"
	 }
      }
      SCAN { 
	 if {[llength [::QMtool::get_scfenergies]]} {
	    variable scanenergies [::QMtool::get_scfenergies]
	 }

	 set scanpot {}
	 foreach entry [::QMtool::get_internal_coordinates] {
	    if {[string match "*S*" [lindex $entry 5]]} { 
	       lappend scanpot [list [lindex $entry 2] [lindex $entry 6]]
	    }
	 }

	 if {[llength $scanpot]==1} {
	    variable qmscanentry [lindex $scanpot 0 0]
	    variable qmscansteps [lindex $scanpot 0 1 0]
	    variable qmscanwidth [expr {$qmscansteps*[lindex $scanpot 0 1 1]}]
	    variable qmscantype  [lindex $::QMtool::simtype 0]
	 } elseif {[llength $scanpot]>1}  {
	    puts "WARNING: More than one internal coordinate scanned!"
	 }
      }
      SIP { 
	 variable molidsip $newmolid
	 # The join in the next line is necessary to make it work on windoze, too.
	 variable molnamesip [join [molinfo $newmolid get name]]

	 variable freqmethod   [::QMtool::get_method]
	 variable freqbasisset [::QMtool::get_basisset]
	 variable optmethod 
	 variable optbasisset
	 if {[llength $optmethod] && $freqmethod!=$optmethod} {
	    tk_messageBox -icon error -type ok -title Message -parent .paratool \
	       -message "QM methods for single point calc. ($freqmethod) and geometry optimization ($optmethod) differ!\nThis can lead to wrong results! You have been warned."
	 }
	 if {[llength $optbasisset] && $freqbasisset!=$optbasisset} {
	    tk_messageBox -icon error -type ok -title Message -parent .paratool \
	       -message "QM basis sets for single point calc. ($freqbasisset) and geometry optimization ($optbasisset) differ!\nThis can lead to wrong results! You have been warned."
	 }
	 variable chkfilefreq  [::QMtool::get_checkfile]
	 variable dipolemoment $::QMtool::dipolemoment
	 if {[llength [::QMtool::get_cartesian_hessian]]} {
	    variable hessian [::QMtool::get_cartesian_hessian]
	 }
	 if {[llength [::QMtool::get_internal_hessian]]} {
	    variable inthessian_kcal [::QMtool::get_internal_hessian_kcal]
	 }
	 set newzmat [::QMtool::get_internal_coordinates]
	 if {[llength $newzmat]>1} {
	    variable zmat
	    variable zmatqm $newzmat
	    if {[llength $zmat]<=1} {
	       # If no internal coords exist, we just import them from QMtool
	       puts "No internal coords exist, we just import them from QMtool."
	       set zmat $newzmat

	       ::Paratool::Hessian::compute_force_constants_from_inthessian

	       variable charmmoverridesqm
	       if {$charmmoverridesqm} { 
		  assign_known_bonded_charmm_params
	       }
	    } else {
	       # If internal coordinates are defined already, we just import the 
	       # missing force constants.
	       puts "Importing unknown internal coordinate force constants from QMtool."
	       ::Paratool::Hessian::compute_force_constants_from_inthessian
	       assign_unknown_force_constants_from_zmatqm
	    }
	 }

	 # Remeasure the current internal coordinate values
	 #update_internal_coordinate_values 
	 update_zmat
      }
   }

   if {$type!="SCAN"} {
      if {[llength [::QMtool::get_totalcharge]]} {
	 variable totalcharge  [::QMtool::get_totalcharge]
      }
      if {[llength [::QMtool::get_multiplicity]]} {
	 variable multiplicity [::QMtool::get_multiplicity]
      }
      
      import_charges_from_qmtool $newmolid {Mullik MulliGr NPA ESP}

      variable copychargetypes {Lewis}
      if {$::Paratool::havemulliken} { lappend copychargetypes Mullik MulliGr }
      if {$::Paratool::havenpa}      { lappend copychargetypes NPA }
      if {$::Paratool::haveesp}      { lappend copychargetypes ESP }
      if {$::Paratool::haveresp}     { lappend copychargetypes RESP }
      if {$::Paratool::havesupram}   { lappend copychargetypes SupraM }
      if {$::Paratool::havefofi}     { lappend copychargetypes ForceF }
   
      ::Atomedit::update_copycharge_menu .paratool_atomedit $copychargetypes
      ::CHARMMcharge::update_copycharge_menu [concat "None" $copychargetypes]

      variable atompropcanon
      variable atomproptags  [concat $atompropcanon $copychargetypes]
      atomedit_update_list
   }

   puts ""
   molinfo $newmolid  set drawn 0
   molinfo $molidbase set drawn 1
   molinfo $molidbase set top 1

   # Setup a trace on the existence of this molecule
   global vmd_initialize_structure
   trace add variable vmd_initialize_structure($newmolid) write ::Paratool::molecule_assert
}

proc ::Paratool::import_cartesians_from_molecule { molid args } {
   variable natoms
   if {[molinfo $molid get numatoms]!=$natoms} {
      error "import_cartesians_from_molecule: Current system and molecule $molid don't have the same number of atoms"
   }

   variable molidbase
   set from [molinfo $molid     get frame]
   set to   [molinfo $molidbase get frame]
   foreach {i j} $args {
      if {$i=="-from"} { set from $j }
      if {$i=="-to"}   { set to $j }
   }

   set sel [atomselect $molid all frame $from]
   set cartesians [$sel get {x y z}] 
   $sel delete

   set allbase [atomselect $molidbase all frame $to]
   $allbase set {x y z} $cartesians
   $allbase delete	 

   return $cartesians
}


####################################################################
# Generate an empty atomproplist with the right number of entries. #
####################################################################

proc ::Paratool::init_atomprops { natoms } {
   variable atomproplist {}
   for {set i 0} {$i<$natoms} {incr i} {
      lappend atomproplist [default_atomprop_entry]
   }
}


###########################################################
# Get atom based data from currently loaded basemolecule  #
# and set the atomproplist accordingly.                   #
###########################################################

proc ::Paratool::import_data_from_molecule { molid taglist } {
   variable natoms
   set sel [atomselect $molid all]
 
   if {[molinfo $molid get numatoms]!=$natoms} {
      error "import_types_from_molecule: Current and top molecules don't have the same number of atoms"
   }

   set vmdtaglist {}
   foreach tag [string tolower $taglist] {
      if {$tag=="rname"} {
         lappend vmdtaglist resname
      } elseif {$tag=="elem"} {
         lappend vmdtaglist atomicnumber
      } else { lappend vmdtaglist $tag }
   }

   set i 0
   foreach atomdata [$sel get $vmdtaglist] mass [$sel get mass] {
      foreach tag $taglist prop $atomdata {
         if {[llength $prop]} {
            if {$tag=="Type"} {
	       if {[string match {XX*} $prop] } { set prop {} }
	       #if {![string length $prop]||[string equal $prop {{}}]} { set prop {{{}}} }
	    } elseif {$tag=="Elem"} {
	       if {$prop<=0} {
		  set prop [mass2element $mass];
	       } else {
		  set prop [::QMtool::atomnum2element $prop]
	       }
	    }
            set_atomprop $tag $i $prop
         }
      }
      incr i
   }

}


#######################################################
# Get available charges from current QMtool molecule. #
#######################################################

proc ::Paratool::import_charges_from_qmtool { molid taglist } {
   variable natoms

   for {set i 0} {$i<$natoms} {incr i} {
      foreach tag $taglist  {
	 if {$tag=="Mullik"  && !$::QMtool::havemulliken} { continue }
	 if {$tag=="MulliGr" && !$::QMtool::havemulliken} { continue }
	 if {$tag=="NPA"     && !$::QMtool::havenpa}      { continue }
	 if {$tag=="ESP"     && !$::QMtool::haveesp}      { continue }

	 set_atomprop $tag $i [::QMtool::get_atomprop $tag $i]
      }
   }
   variable havemulliken [expr $::QMtool::havemulliken | $::Paratool::havemulliken]
   variable havenpa      [expr $::QMtool::havenpa      | $::Paratool::havenpa]
   variable haveesp      [expr $::QMtool::haveesp      | $::Paratool::haveesp]
}


##########################################################
# This is called when the VMD mol initialization state   #
# is changed, i.e. when a molecule is deleted from VMD's #
# list. If the deleted molecule exists in Paratool then  #
# delete its reference.                                  #
##########################################################

proc ::Paratool::molecule_assert { n id args } {
   global vmd_initialize_structure
   puts "assert trace ${n}($id) = $vmd_initialize_structure($id)"
   if {$vmd_initialize_structure($id)==0} { 
      variable molidparent
      variable molidbase
      variable molidopt
      variable molidsip
      if {$id==$molidparent} { set molidparent -1; variable molnameparent {(deleted)}; }
      if {$id==$molidbase}   { 
	 global vmd_frame
	 foreach t [trace info variable vmd_frame($molidbase)] {
	    trace remove variable vmd_frame($molidbase) write ::Paratool::update_frame
	 }
	 global vmd_initialize_structure
	 foreach t [trace info variable vmd_initialize_structure($molidbase)] {
	    trace remove variable vmd_initialize_structure($molidbase) write ::Paratool::molecule_assert
	 }
	 set molidbase   -1; 
	 variable molnamebase   {(deleted)}; 
      }
      if {$id==$molidsip}    { set molidsip    -1; variable molnamesip    {(deleted)}; }
      if {$id==$molidopt}    {
	 set molidopt    -1; 
	 variable molnameopt    {(deleted)}; 
	 animate delete beg 1 $molidbase
	 display resetview
      }
      #variable molidwater  
      #variable molidsyswat 
      #if {$id==$molidwater}  { set molidwater  -1; variable molnamewater  {(deleted)}; }
      #if {$id==$molidsyswat} { set molidsyswat -1; variable molnamesyswat {(deleted)}; }
   }
}

proc ::Paratool::save_viewpoint_orig {} {
   variable viewpointbase
   variable molidparent
   variable molidbase
#   if {[info exists viewpointbase]} { unset viewpointbase }
   if {$molidbase>=0} {
      set viewpointbase [molinfo $molidbase get { center_matrix rotate_matrix global_matrix }]
   }
}

proc ::Paratool::restore_viewpoint_orig {} {
   variable viewpointbase
   variable molidparent
   variable molidbase
   foreach mol [list $molidparent $molidbase] {
      if {[llength $viewpointbase] && $mol>=0} {
         molinfo $mol set { center_matrix rotate_matrix global_matrix } $viewpointbase
      }
   }
}

# From NAMD:
# ----------
#  Ok, first there is a list of atom indexes that is NumExclusions
#  long.  These are in some sense the atoms that will be exlcuded.
#  Following this list is a list of NumAtoms length that is a list
#  of indexes into the list of excluded atoms.  So an example.  Suppose
#  we have a 5 atom simulation with 3 explicit exclusions.  The .psf
#  file could look like:
#
#  3!NNB
#  3 4 5
#  0 1 3 3 3
#
#  This would mean that atom 1 has no explicit exclusions.  Atom 2
#  has an explicit exclusion with atom 3.  Atom 3 has an explicit
#  exclusion with atoms 4 AND 5.  And atoms 4 and 5 have no explicit
#  exclusions.  Got it!?!  I'm not sure who dreamed this up . . .

#  Atoms in list2 that have exclusions correspond to a range of excluded
#  atoms in list1. If the entry in list2 is zero then this atom has no exclusions.
#  If there is no increase in the index in list2 this also means that this
#  atom has no exclusions. If the increase is >0 then the following range of
#  exclusions corresponds to this atom n: Take the n-1th entry from list 2
#  and add 1 to obtain the beginning of the range, the end of the range is
#  denoted by the n-th entry

# We also add the pairlist to the remarks since the pairlist is human-readable.

proc ::Paratool::write_exclusions { psffile pairlist } {
   set numatoms [molinfo top get numatoms]
   set atomlist {}
   set newpairlist {}
   foreach pair $pairlist {
      lappend newpairlist [lsort -integer $pair]
   }
   if {[llength $newpairlist]>1} {
      set pairlist [lsort -dictionary $newpairlist]
   }

   # Generate a list long enough for all atoms:
   set curindex 0
   set exclusions {}
   for {set i 0} {$i<$numatoms} {incr i} {
      set poslist [lsearch -all $pairlist "$i *"]
      #puts "poslist=$poslist"
      incr curindex [llength $poslist]
      foreach pos  $poslist {
         set pair [lindex $pairlist $pos]
         lappend exclusions [expr [lindex $pair 1]+1]
      }
      lappend atomlist $curindex
   }

   set posref -1
   set oldatom0 0

   set fd [open $psffile r]
   set tmpfd [open tmp.psf w]


   # Copy all lines up to !NNB of the existing psf into the new psf
   set numexcl 0
   set remarks ""
   set nremarks 0
   set ntitle 0
   while {![eof $fd]} {
      set line [gets $fd]

      # Count the existing REMARKS lines
      if { [string match "*!NTITLE*" $line] } {
	 set ntitle [lindex $line 0]

      } elseif { [string match "REMARKS*" [string trim $line]] } {
	 # We are currently parsing the remarks section
	 append remarks $line "\n"
	 incr nremarks

      } elseif {$nremarks} {
	 # The remark section has ended, we append the exclusions:
	 foreach {p1 p2 p3 p4} $pairlist {
	    set newline " REMARKS exclusions "
	    foreach p [list $p1 $p2 $p3 $p4] {
	       if {[llength $p]} {
		  append newline "{$p} "
	       }
	    }
	    append remarks $newline "\n"
	    incr ntitle
	 }
	 puts $tmpfd [format "%8i !NTITLE" $ntitle]
	 puts $tmpfd $remarks
	 set nremarks 0

      } elseif { [string match "*!NNB*" $line] } {
         set numexcl [lindex [split $line "!"] 0]
         break

      } else {
         puts $tmpfd $line
      }
   }

   # Read explicit exclusions
   set numexclread 0
   while {![eof $fd]} {
      set line [gets $fd]

      set excl $line
      incr numexclread [llength $excl]

      if {$numexclread>$numexcl} {
         error [format "Number of exclusions read (%i) is greater than specified (%i)!" $numexclread >$numexcl]
      } elseif {$numexclread==$numexcl} {
         set nnb [format "%8i" [llength $exclusions]]
         puts $tmpfd "${nnb} !NNB: exclusions"
         # Write explicit exclusions
         set i 1
         foreach e $exclusions {
            puts -nonewline $tmpfd [format "%8i" $e]
            if {![expr $i%8] || $i==[llength $exclusions]} { puts $tmpfd "" }
            incr i
         }
         break
      }
   }

   # Read indices into exclusions
   set numatomsread 0
   while {![eof $fd]} {
      set line [gets $fd]
      set atoms $line
      incr numatomsread [llength $atoms]
      if { $numatomsread>=$numatoms} {

         # Write indices into exclusions
         set i 1
         foreach a $atomlist {
            puts -nonewline $tmpfd [format "%8i" $a]
            if {![expr $i%8] || $i==[llength $atomlist]} { puts $tmpfd "" }
            incr i
         }
         break
      }
   }

   # Copy the rest
   while {![eof $fd]} {
      set line [gets $fd]
      puts $tmpfd $line
   }

   close $fd
   close $tmpfd
   file copy -force tmp.psf $psffile
   file delete tmp.psf
}


####################################################################
# Write a psfgen input file and, if requested by -build, also run  #
# psfgen with this file.                                           #
# If basemolecule contains a metal complex or iron sulfur cluster  #
# use the specialized function write_tm_psfgen_input instead.      #
# If newtopofile is not specified, then return with a warning.     #
####################################################################

proc ::Paratool::write_psfgen_input { args } {
   set build 0
   set force 0
   set cwatfile {}
   set output {}
   set file {}
   set topfile {}
   if {[lsearch $args "-build"]>=0}  { set build 1 }
   if {[lsearch $args "-force"]>=0}  { set force 1 }
   if {[lsearch $args "-cwat"]>=0}   { set cwatfile [lindex $args [expr 1+[lsearch $args "-cwat"]]] }
   if {[lsearch $args "-output"]>=0} { set output [lindex $args [expr 1+[lsearch $args "-output"]]] }
   if {[lsearch $args "-file"]>=0}   { set file [lindex $args [expr 1+[lsearch $args "-file"]]] }
   if {[lsearch $args "-top"]>=0}    { set topfile [lindex $args [expr 1+[lsearch $args "-top"]]] }

   variable topologyfiles
   variable newtopofile
   if {![llength $topfile] && [llength $newtopofile]} {
      set topfile $newtopofile
   }
   if {![llength $topfile]} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "You must first write the new topology file."
      return 0      
   }

   if {![llength [glob -nocomplain $topfile]]} {
      error "::Paratool::write_psfgen_input: Topology file $topfile does not exist!"
   }

   if {![llength $file]} { 
      variable psfgeninputfile
      if {[llength $psfgeninputfile]} {
	 set file $psfgeninputfile
      } else { 
	 set file "[file rootname ${::Paratool::molnamebase}].pgn"
      }
   }
   if {![llength $output]} { 
      set output [file rootname $file]
   }

   if {!$force} {
      set file [opendialog writepsfgen $file]
   }
   variable psfgeninputfile $file

   # If we are in presence of a metal complex or iron sulfur cluster
   # use the specialized function instead.
   variable istmcomplex
   variable isironsulfur
   if {$istmcomplex || $isironsulfur} { 
      if {$build} {
	 return [write_tm_psfgen_input $file -build]
      } else {
	 return [write_tm_psfgen_input $file]
      }
   }

   set fid [open $file w]
   puts $fid "package require psfgen"
   puts $fid "psfcontext new delete"

   # We are writing the user specified topology file first, since duplicate 
   # RESI entries from further files are ignored.
   puts $fid "topology $topfile"
   foreach top $topologyfiles {
      puts $fid "topology $top"
   }
   puts $fid ""

   variable molidbase
   variable molnamebase
   set sel [atomselect $molidbase "all"]
   set segidlist [lsort -unique [$sel get segid]]
   $sel delete
   set segrestrans {}
   set i 1
   foreach segid $segidlist {
      # We must assure that the last frame is used, i.e. the optimized geometry.
      set segsel [atomselect $molidbase "segid $segid" frame last]
      set segfile [file rootname $molnamebase]_$segid.pdb
      $segsel writepdb $segfile
      $segsel delete
      puts $fid "segment $segid {"
      puts $fid "  pdb $segfile"
      puts $fid "  first NONE"
      puts $fid "  last  NONE"
      puts $fid "  auto none"
      puts $fid "}"
      puts $fid "coordpdb $segfile $segid"
      puts $fid ""
      incr i
   }

   if {[llength $cwatfile]} {
      puts $fid "segment CWAT {"
      puts $fid "  pdb $cwatfile"
      puts $fid "  first NONE"
      puts $fid "  last  NONE"
      puts $fid "  auto none"
      puts $fid "}"
      puts $fid "coordpdb $cwatfile CWAT"
      puts $fid ""      
   }

   puts $fid ""
   puts $fid ""
   puts $fid "writepsf ${output}.psf"
   puts $fid "writepdb ${output}.pdb"
   close $fid

   if {$build} {
      # Run psfgen
      source $file
      variable psf ${output}.psf
      variable pdb ${output}.pdb
      mol new $psf
      mol addfile $pdb   

      variable exclusions
      if {[llength $exclusions]} {
	 write_exclusions $::Paratool::psf $exclusions
      }
   }

   return {}
}


##################################################################
# Read cartesian Hessian in lower diagonal format from a file.   #
# Since the upper diagonal is simpply ignored one can also read  #
# in complete square matrices.                                   #
# Useful for people that want to use Hessian from a different    #
# source than Gaussian.                                          #
##################################################################

proc ::Paratool::read_raw_cartesian_hessian {file} {
   set fid [open $file r]
   
   set hess {}
   set i 1
   while {![eof $fid]} {
      set line [gets $fid]
      if {[llength $line]<$i} {
	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
	    -message "Bad format for cartesian Hessian in $file!"
	 return 0      
      }
      lappend hess $line
      incr i
   }

   if {[llength $hess]!=$natoms} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Wrong number of atoms in cartesian Hessian in $file!"
      return 0      
   }

   variable hessian $hess
}