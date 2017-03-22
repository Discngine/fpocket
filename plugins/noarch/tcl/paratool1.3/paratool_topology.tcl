#################################################################
# This function is used to write a temporary topology file for  #
# use by psfgen to add guessed hydrogens to an unparametrized   #
# component.                                                    #
# $sel must provide the atomselection of the corresponding      #
# component. It should only contain one resname.                #
# $compatomlist and $compbondlist provide the atom names types  #
# charges and bonds.                                            #
# This function is a lot simpler than "write_topology_file"     #
# and thus faster.                                              #
#################################################################

proc ::Paratool::write_tmp_topo { file sel compatomlist compbondlist } {
   set fid [open $file w]
   set typelist {}
   set atomlist {}
   set resnamelist [lsort -unique [$sel get resname]]
   if {[llength $resnamelist]>1} {
      error "::Paratool::write_tmp_topo: Fragment contains more than one resname!"
   }

   foreach atom $compatomlist {
      set name   [lindex $atom 0]
      set elem   [lindex $atom 1]
      set charge [lindex $atom 2]
      set type "XX[string toupper ${elem}]"
      lappend typelist [list $type $elem]
      lappend atomlist [list $name $type $charge {}]
   }

   set typelist [lsort -unique $typelist]

   write_charmmtop_header $fid
   write_charmmtop_masses $fid $typelist

   # This is not necessary here, but it serves as a stub for later development
   # of the final topology writer.
   set totalcharge 0
   foreach charge [$sel get charge] {
      set totalcharge [expr $totalcharge+$charge]
   }

   set comment "temporary topology"
   # We leave the angles, diheds and impropers undefined as we don't need them now.
   write_charmmtop_resi $fid RESI [lindex $resnamelist 0] $totalcharge $atomlist $compbondlist {} {} {} $comment
   puts $fid "END"
   close $fid
}


###################################################################
# Write a topology file containing RESI entries for all resnames. #
###################################################################

proc ::Paratool::write_topology_file { file } {
   variable molidbase
   variable istmcomplex
   variable isironsulfur
   if {$istmcomplex || $isironsulfur} { 
      write_tmcomplex_patchresi $file
      return
   }

   set fid [open $file w]

   write_charmmtop_header $fid

   set all [atomselect $molidbase all]
   set resnamelist [lsort -unique [$all get resname]]
   $all delete

   variable topologyfiles 
   variable topologylist 
   # Write topologies for each resname
   foreach resname $resnamelist {
      # Check if this resname already exists, only write nonexisting ones
      foreach topo $topologylist tfile $topologyfiles {
	 if {[::Toporead::topology_contains_resi $topo $resname]>=0} {
	    puts "WARNING: Ignoring duplicate RESI $resname from file $tfile!"
	 }
      }
      set sel [atomselect $molidbase "resname $resname"]
      set ret [write_resi_topology $fid $sel -noheader]
      if {[llength $ret]} {
	 set atom [atomselect $molidbase "index $ret"]
	 set ans [tk_messageBox -icon error -type okcancel -title Message \
		     -message "Atom [$atom get resname]:[$atom get name] has no type.\nDo you want to automatically choose all missing types now?"]
	 if {$ans=="ok"} {
	    assign_unique_atomtypes
	    write_resi_topology $fid $sel -noheader
	 }
      }
      $sel delete
   }

   puts $fid "END"
   close $fid

   variable newtopofile $file
}


##################################################################
# Extracts topology info from the residue of the given selection #
# and writes the complete RESI section including IC table.       #
##################################################################

proc ::Paratool::write_resi_topology { fid sel args } {
   set header  1
   set ictable 1
   set commment {}
   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      if {$i=="-noheader"}  then {
         set header 0
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      if {$i=="-noictable"}  then {
         set ictable 0
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      incr argnum
   }
   # Scan for options with one argument
   foreach {i j} $arglist {
      if {$i=="-comment"}      then { 
	 set comment $j
      }
   }

   variable molidbase
   set typelist {}
   set atomlist {}
   set bondlist {}
   set anglelist {}
   set dihedlist {}
   set imprplist {}
   set resnamelist [lsort -unique [$sel get resname]]
   if {[llength $resnamelist]>1} {
      error "::Paratool::write_topology_file: fragment contains more than one resname!"
   }
   set residuelist [lsort -unique [$sel get {resname resid segid}]] 
   if {[llength $residuelist]>1} {
      # We consider each resname only once
      set sel [atomselect $molidbase "segid [lindex $residuelist 2] and resid [lindex $residuelist 1]"]
   }

  foreach atom [$sel get {name atomicnumber charge type index}] {
      foreach {name atomicnumber charge type index} $atom {}
      if {![llength $type] || $type=={}} { return $index }
      set elem [::QMtool::atomnum2element $atomicnumber]
      set flags   [lindex $atom [get_atomprop_index Flags]]
      set comment {}
      if {[string match {*C*} $flags]>=0} {
	 set comment "type from CHARMM"
      }
      #puts [list $name $type $charge $comment]
      lappend typelist [list $type $elem]
      lappend atomlist [list $name $type $charge $comment]
   }
   set typelist [lsort -unique $typelist]

   variable zmat
   set zmatbonds [lsearch -inline -all $zmat {* *bond *}]
   foreach bond $zmatbonds {
      set bo 0
      switch [lindex $bond 1] {
	 bond  { set bo 1 }
	 dbond { set bo 2 }
	 tbond { set bo 3 }
      }
      set ind1 [lindex $bond 2 0]
      set ind2 [lindex $bond 2 1]
      if {[lsearch [$sel list] $ind1]<0 || [lsearch [$sel list] $ind2]<0} { continue }

      set sel1 [atomselect $molidbase "index [lindex $bond 2 0]"]
      set sel2 [atomselect $molidbase "index [lindex $bond 2 1]"]
      if {[$sel1 get resid]==[$sel2 get resid]} {
	 lappend bondlist [join [join [list [$sel1 get name] [$sel2 get name] $bo]]]
      } else {
	 puts "WARNING: Bond between different resids [$sel1 get resid]-[$sel2 get resid] skipped."
      }
   }

   set zmatangles [lsearch -regexp -all -inline $zmat "(angle|lbend)\\s+"]
   foreach angle $zmatangles {
      set ind1 [lindex $angle 2 0]
      set ind2 [lindex $angle 2 1]
      set ind3 [lindex $angle 2 2]
      if {[lsearch [$sel list] $ind1]<0 || [lsearch [$sel list] $ind2]<0 || [lsearch [$sel list] $ind3]<0} { continue }
      set sel1 [atomselect $molidbase "index [lindex $angle 2 0]"]
      set sel2 [atomselect $molidbase "index [lindex $angle 2 1]"]
      set sel3 [atomselect $molidbase "index [lindex $angle 2 2]"]
      if {[$sel1 get resid]==[$sel2 get resid] && [$sel1 get resid]==[$sel3 get resid]} {
	 lappend anglelist [join [list [$sel1 get name] [$sel2 get name] [$sel3 get name]]]
      } else {
	 puts "WARNING: Angle between different resids [$sel1 get resid]-[$sel2 get resid]-[$sel3 get resid] skipped."
      }
   }

   set zmatdihedsresi {}
   set zmatdiheds [lsearch -inline -all $zmat {* dihed *}]
   foreach dihed $zmatdiheds {
      set ind1 [lindex $dihed 2 0]
      set ind2 [lindex $dihed 2 1]
      set ind3 [lindex $dihed 2 2]
      set ind4 [lindex $dihed 2 3]
      if {[lsearch [$sel list] $ind1]<0 || [lsearch [$sel list] $ind2]<0 || 
	  [lsearch [$sel list] $ind3]<0 || [lsearch [$sel list] $ind4]<0} { continue }
      set sel1 [atomselect $molidbase "index [lindex $dihed 2 0]"]
      set sel2 [atomselect $molidbase "index [lindex $dihed 2 1]"]
      set sel3 [atomselect $molidbase "index [lindex $dihed 2 2]"]
      set sel4 [atomselect $molidbase "index [lindex $dihed 2 3]"]
      if {[$sel1 get resid]==[$sel2 get resid] && [$sel1 get resid]==[$sel3 get resid] && [$sel1 get resid]==[$sel4 get resid]} {
	 lappend dihedlist [join [list [$sel1 get name] [$sel2 get name] [$sel3 get name] [$sel4 get name]]]
	 lappend zmatdihedsresi $dihed
      } else {
	 puts "WARNING: Dihedral between different resids [$sel1 get resid]-[$sel2 get resid]-[$sel3 get resid]-[$sel4 get resid] skipped."
      }
   }

   set zmatimprpsresi {}
   set zmatimprps [lsearch -inline -all $zmat {* imprp *}]
   foreach imprp $zmatimprps {
      set ind1 [lindex $imprp 2 0]
      set ind2 [lindex $imprp 2 1]
      set ind3 [lindex $imprp 2 2]
      set ind4 [lindex $imprp 2 3]
      if {[lsearch [$sel list] $ind1]<0 || [lsearch [$sel list] $ind2]<0 || 
	  [lsearch [$sel list] $ind3]<0 || [lsearch [$sel list] $ind4]<0} { continue }
      set sel1 [atomselect $molidbase "index [lindex $imprp 2 0]"]
      set sel2 [atomselect $molidbase "index [lindex $imprp 2 1]"]
      set sel3 [atomselect $molidbase "index [lindex $imprp 2 2]"]
      set sel4 [atomselect $molidbase "index [lindex $imprp 2 3]"]
      if {[$sel1 get resid]==[$sel2 get resid] && [$sel1 get resid]==[$sel3 get resid] && [$sel1 get resid]==[$sel4 get resid]} {
	 lappend imprplist [join [list [$sel1 get name] [$sel2 get name] [$sel3 get name] [$sel4 get name]]]
	 lappend zmatimprpsresi $imprp
      } else {
	 puts "WARNING: Improper between different resids [$sel1 get resid]-[$sel2 get resid]-[$sel3 get resid]-[$sel4 get resid] skipped."
      }
   }


   if {$header} {
      write_charmmtop_header $fid
   }
   write_charmmtop_masses $fid $typelist

   set totalcharge 0.0
   foreach charge [$sel get charge] {
      set totalcharge [expr $charge+$totalcharge]
   }
   if {[expr abs($totalcharge-round($totalcharge))]>0.001} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "WARNING: Total charge ($totalcharge) should sum up to an integer value!"      
   } else {
      set totalcharge [expr round($totalcharge)]
   }

   write_charmmtop_resi $fid RESI [lindex $resnamelist 0] $totalcharge $atomlist $bondlist $anglelist \
      $dihedlist $imprplist $comment

   if {$ictable} {
      write_charmmtop_ictable $fid $dihedlist $imprplist $zmatbonds $zmatangles $zmatdihedsresi $zmatimprpsresi
   }
   return 
}


######################################################################
# Write the CHARMM27 header to topology file.                        #
######################################################################

proc ::Paratool::write_charmmtop_header { fid } {
puts $fid "*>>>>>> Combined CHARMM All-Hydrogen Topology File for <<<<<<<<<
*>>>>>>>>> CHARMM22 Proteins and CHARMM27 Lipids <<<<<<<<<<
*from
*>>>>>>>>CHARMM22 All-Hydrogen Topology File for Proteins <<<<<<
*>>>>>>>>>>>>>>>>>>>>> August 1999 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<
*>>>>>>> Direct comments to Alexander D. MacKerell Jr. <<<<<<<<<
*>>>>>> 410-706-7442 or email: alex,mmiris.ab.umd.edu  <<<<<<<<<
*and
*  \\\\\\\ CHARMM27 All-Hydrogen Lipid Topology File ///////
*  \\\\\\\\\\\\\\\\\\ Developmental /////////////////////////
*              Alexander D. MacKerell Jr.
*                     August 1999
* All comments to ADM jr.  email: alex,mmiris.ab.umd.edu
*              telephone: 410-706-7442
*
27  1

"
   write_citation $fid
}


proc ::Paratool::write_citation { fid } {
   puts $fid ""
   puts $fid "! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
   puts $fid "! + Residue topologies/parameters generated by PARATOOL.                      +"
   puts $fid "! +                                                                           +"
   puts $fid "! + PARATOOL is an interactive tool for generation of force field parameters. +"
   puts $fid "! + and can be obtained free of charge from                                   +"
   puts $fid "! + http://bioinf.charite.de/biophys/paratool                                 +"
   puts $fid "! +                                                                           +"
   puts $fid "! + Author:                                                                   +"
   puts $fid "! + Jan Saam                                                                  +"
   puts $fid "! + Institute of Biochemistry                                                 +"
   puts $fid "! + Charite Berlin                                                            +"
   puts $fid "! + Germany                                                                   +"
   puts $fid "! + saam@charite.de                                                           +"
   puts $fid "! +                                                                           +"
   puts $fid "! + CITATION:                                                                 +"
   puts $fid "! + If you use PARATOOL or topologies/parameters generated by this program,   +"
   puts $fid "! + please cite the following work:                                           +"
   puts $fid "! + Saam, et al. (2006), ...                                                  +"
   puts $fid "! +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
   puts $fid ""
   puts $fid ""
}


######################################################################
# Write the type list (MASS section) to topology file.               #
######################################################################

proc ::Paratool::write_charmmtop_masses { fid typelist } {
   set tind 1
   foreach atom $typelist {
      set type [lindex $atom 0]
      set elem [lindex $atom 1]
      set mass    [get_periodic_element MASS $elem]
      set comment [lindex $atom 2]
      puts $fid [format "MASS %5i %4s %8.5f %2s ! %s" $tind $type $mass $elem $comment]
      incr tind
   }
   puts $fid ""
}


######################################################################
# Write residue (excluding IC table) based data to topology file.    #
######################################################################

proc ::Paratool::write_charmmtop_resi { fid key resname totalcharge atomlist compbondlist anglelist dihedlist imprplist comment {first NONE} {last NONE}} {
   puts $fid [format "$key %4s         %+6.3f ! %s" $resname $totalcharge $comment]
   puts $fid "GROUP"
   foreach atom $atomlist {
      set name    [lindex $atom 0]
      set type    [lindex $atom 1]
      set charge  [lindex $atom 2]
      set comment [lindex $atom 3]
      puts $fid [format "ATOM %4s %4s     %+6.3f  ! %s" $name $type $charge $comment]
   }
 
   set sbondlist {}
   set dbondlist {}
   set tbondlist {}
   foreach bond $compbondlist {
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
   puts $fid "PATCHING FIRS $first LAST $last"
   puts $fid ""
}


######################################################################
# Write IC table to topology file.                                   #
# We are looping ocver all dihedral entries of zmat and construct an #
# IC table line from the involved bonds, angles and the dihedral     #
# itself. This table will not correspond to the internal coordinates #
# in zmat since impropers are ignored.                               #
#                                                                    #
# Normal IC table entry:   I                                         #
#	                    \                                        #
#                            J----K                                  #
#                                  \                                 #
#                                   L                                #
#                                                                    #
# Each entry in the IC table (see below) lists 4 connected atoms,    #
# I, J, K and L,; for a normal IC table entry, the following values  #
# are listed:                                                        #
# * I-J bond length                                                  #
# * I-J-K bond angle                                                 #
# * I-J-K-L dihedral angle                                           #
# * J-K-L bond angle                                                 #
# * K-L bond length                                                  #
#                                                                    #
# Improper dihedral entry:  I    L                                   #
#                            \  /                                    #
#                             K*                                     #
#                             |                                      #
#                             J                                      #
#                                                                    #
# Improper dihedral angles, which are used to keep sp2 atoms planar  #
# and sp3 atoms in a tetrahedral geometry, are marked with a star.   #
# The center atom of an improper dihedral angle is marked with a     #
# star. For an improper dihedral angle entry, the following values   #
# are listed:                                                        #
# * I-K bond length                                                  #
# * I-K-J bond angle                                                 #
# * I-J-K-L dihedral angle                                           #
# * J-K-L bond angle                                                 #
# * K-L bond length                                                  #
#                                                                    #
######################################################################

proc ::Paratool::write_charmmtop_ictable { fid dihedlist imprplist zmatbonds zmatangles zmatdiheds zmatimprps } {
   foreach dihed [concat $zmatdiheds $zmatimprps] names [concat $dihedlist $imprplist] {
      if {![llength $names]} { continue }

      if {[lindex $dihed 1]=="imprp"} {
	 # IC entries based on impropers
	 foreach {K I J L} [lindex $dihed 2] {break}
	 set bond1  [list $I $K]
	 set bond2  [list $K $L]
	 set angle1 [list $I $K $J]
	 set angle2 [list $J $K $L]
      } else {
	 # IC entries based on dihedrals
	 foreach {I J K L} [lindex $dihed 2] {break}
	 set bond1  [list $I $J]
	 set bond2  [list $K $L]
	 set angle1 [list $I $J $K]
	 set angle2 [list $J $K $L]
      }

      set bondentry1 [lsearch -inline $zmatbonds "* * {$bond1} *"]
      if {![llength $bondentry1]} {
	 set bondentry1 [lsearch -inline $zmatbonds "* * {[lrevert $bond1]} *"]
      }
      if {![llength $bondentry1]} {
	 puts "Warning ::Paratool::write_charmmtop_ictable: Bond $bond1 not found!"
	 continue
      }

      set bondentry2 [lsearch -inline $zmatbonds "* * {$bond2} *"]
      if {![llength $bondentry2]} {
	 set bondentry2 [lsearch -inline $zmatbonds "* * {[lrevert $bond2]} *"]
      }
      if {![llength $bondentry2]} {
	 puts "Warning ::Paratool::write_charmmtop_ictable: Bond $bond2 not found!"
	 continue
      }

      set angleentry1 [lsearch -inline $zmatangles "* * {$angle1} *"]
      if {![llength $angleentry1]} {
	 set angleentry1 [lsearch -inline $zmatangles "* * {[lrevert $angle1]} *"]
      }
      if {![llength $angleentry1]} {
	 puts "Warning ::Paratool::write_charmmtop_ictable: Angle $angle1 not found!"
	 continue
      }

      set angleentry2 [lsearch -inline $zmatangles "* * {$angle2} *"]
      if {![llength $angleentry2]} {
	 set angleentry2 [lsearch -inline $zmatangles "* * {[lrevert $angle2]} *"]
      }
      if {![llength $angleentry2]} {
	 puts "Warning ::Paratool::write_charmmtop_ictable: Angle $angle2 not found!"
	 continue
      }

      if {[lindex $dihed 1]=="imprp"} {
	 # IC entries based on impropers
	 foreach {K I J L} $names {break}
	 puts $fid [format "IC %-4s %-4s *%-5s %-4s %6.3f %7.2f %7.2f %7.2f %6.3f" \
		    $I $J $K $L [lindex $bondentry1 3] [lindex $angleentry1 3] \
		    [lindex $dihed 3] [lindex $angleentry2 3] [lindex $bondentry2 3]]
      } else {
	 # IC entries based on dihedrals
	 foreach {I J K L} $names {break}
	 puts $fid [format "IC %-4s %-4s %-4s %-4s %6.3f %7.2f %7.2f %7.2f %6.3f" \
		    $I $J $K $L [lindex $bondentry1 3] [lindex $angleentry1 3] \
		    [lindex $dihed 3] [lindex $angleentry2 3] [lindex $bondentry2 3]]
      }
   }
}


######################################################################
# Open topology file and and set the file pointer just before the    #
# END tag (which will then be overwritten).                          #
######################################################################

proc ::Paratool::open_topo_end { file } {
   set fid [open $file r+]
   # Find the END tag
   set maxind 0
   while {![eof $fid]} {
      set filepos [tell $fid]
      set line [gets $fid]
      if {[string equal $line "END"]} { break }
   }
   seek $fid $filepos
   return $fid
}


###########################################################
# Imports the bondorder info from the loaded topology     #
# lists.                                                  #
###########################################################

proc ::Paratool::import_bondorders_from_topology { molid {topofile {}} } {
   if {$molid<0} { return }
   puts "Import bondorder info from topology files..."

   # Set all bondorders to 1
   set all [atomselect $molid all]
   set neworders {}
   foreach bpa [$all getbondorders] {
      set newbpa {}
      foreach bond $bpa {
	 lappend newbpa 1
      }
      lappend neworders $newbpa
   }
   $all setbondorders $neworders
   $all delete

   variable topologylist
   set topolist $topologylist
   if {[llength $topofile]} {
      lappend topolist [::Toporead::read_charmm_topology $topofile]
   }

   set all [atomselect $molid all]
   foreach resname [lsort -unique [$all get resname]] {
      # Get the double/triple bond definitions for this resname
      set dbondlist {}
      set tbondlist {}
      set dfound 0
      set tfound 0
      foreach topo $topolist {
	 set dbondlist [::Toporead::topology_get_resid $topo $resname doublebonds]
	 if {$dfound} {
	    puts "Duplicate residue key $resname, using latest instance."
	 }
	 if {[llength $dbondlist]} { set dfound 1 }
	 set tbondlist [::Toporead::topology_get_resid $topo $resname triplebonds]
	 if {$tfound} {
	    puts "Duplicate residue key $resname, using latest instance."
	 }
	 if {[llength $tbondlist]} { set tfound 1 }
      }

      set reslist [atomselect $molid "resname $resname"]
      set segkey {}
      set chains [join [lsort -unique [$reslist get {chain}]]]
      if {[llength $chains]} {
	 set segkey "chain"
      } elseif {[llength $segids]} {
	 set segids [join [lsort -unique [$reslist get {segid}]]]
	 set segkey "segid"
      }

      foreach segid [lsort -unique [join [$reslist get $segkey]]] {
	 set resids [atomselect $molid "resname $resname and $segkey $segid"]
	 foreach resid [lsort -unique [$resids get resid]] {
	    set count 0
	    foreach dbond [join [list $dbondlist $tbondlist]] {
	       set bond0 [lindex $dbond 0]
	       set bond1 [lindex $dbond 1]
	       set atom0 [atomselect $molid "$segkey $segid and resname $resname and resid $resid and name '[string map {' \\'} $bond0]'"]
	       set atom1 [atomselect $molid "$segkey $segid and resname $resname and resid $resid and name '[string map {' \\'} $bond1]'"]
	       set index0 [join [$atom0 get index]]
	       set index1 [join [$atom1 get index]]
	       set bo 2.0
	       if {$count>=[llength $dbondlist]} { set bo 3.0 }
	       incr count
	       # If we don't find the atom then we probably have a patch
	       # Since it's difficult to find out which patch was applied,
	       # we ignore this bond for now.
	       if {![llength $index0]} {
		  puts "WARNING: Couldn't find atom $resname$resid:$bond0 in segid $segid."
		  puts "         Probably a patch was applied to this residue."
		  continue
	       }
	       if {![llength $index1]} {
		  puts "WARNING: Couldn't find atom $resname$resid:$bond1 in segid $segid."
		  puts "         Probably a patch was applied to this residue."
		  continue
	       }
	       set pos0 [lsearch [join [$atom0 getbonds]] $index1]
	       set pos1 [lsearch [join [$atom1 getbonds]] $index0]
	       set bondorder0 [lreplace [join [$atom0 getbondorders]] $pos0 $pos0 $bo]
	       set bondorder1 [lreplace [join [$atom1 getbondorders]] $pos1 $pos1 $bo]
	       $atom0 setbondorders [list $bondorder0]
	       $atom1 setbondorders [list $bondorder1]
	       $atom0 delete
	       $atom1 delete
	    }
	 }
	 $resids delete
      }
      $reslist delete

   }
   $all delete


   #### Set double bonds for patches ###

   # Load structure info
   set psf ""
   # Get coordinate and structure files from VMD
   foreach i [join [molinfo $molid get filetype]] j [join [molinfo $molid get filename]] {
      if {$i=="psf"} {
         set psf $j
      }
   }
   if {![llength $psf]} { return }

   set pdbondlist {}
   set patchlist [read_psf_patchlist $psf]
   foreach patch $patchlist {
      set presname [lindex $patch 0];
      set dbondlist {}
      set tbondlist {}
      set dfound 0
      set tfound 0
      foreach topo $topolist {
	 set dbondlist [::Toporead::topology_get_resid $topo $presname doublebonds]
	 if {$dfound} {
	    puts "Duplicate residue key $resname, using latest instance."
	 }
	 if {[llength $dbondlist]} { set found 1 }
	 set tbondlist [::Toporead::topology_get_resid $topo $presname triplebonds]
	 if {$tfound} {
	    puts "Duplicate residue key $resname, using latest instance."
	 }
	 if {[llength $tbondlist]} { set found 1 }
      }
      set count 0
      foreach dbond [join [list $dbondlist $tbondlist]] {
	 set bond0 [string map {' \\'} [lindex $dbond 0]]
	 set bond1 [string map {' \\'} [lindex $dbond 1]]
	 set bo 2.0
	 if {$count>=[llength $dbondlist]} { set bo 3.0 }
	 incr count
	 foreach {segid resid} [lrange $patch 1 end] {
	    #puts "$segkey $segid:$resid; $bond0; $bond1;"
	    set atom0 [atomselect $molid "segid $segid and resid $resid and name '$bond0'"]
	    set atom1 [atomselect $molid "segid $segid and resid $resid and name '$bond1'"]
	    set index0 [join [$atom0 get index]]
	    set index1 [join [$atom1 get index]]
	    if {[llength $index0] && [llength $index1]} {
	       set pos0 [lsearch [join [$atom0 getbonds]] $index1]
	       set pos1 [lsearch [join [$atom1 getbonds]] $index0]
	       set bondorder0 [lreplace [join [$atom0 getbondorders]] $pos0 $pos0 $bo]
	       set bondorder1 [lreplace [join [$atom1 getbondorders]] $pos1 $pos1 $bo]
	       $atom0 setbondorders [list $bondorder0]
	       $atom1 setbondorders [list $bondorder1]
	       $atom0 delete
	       $atom1 delete
	    }
	 }
      }
   }

}


#################################################################
# Reads the patch info from the psfgen REMARKS in the psf file. #
#################################################################

proc ::Paratool::read_psf_patchlist { file } {
   set patchlist {}
   set fid [open $file r]
   while {![eof $fid]} {
      set line [string trim [gets $fid]]
      if {[string match "*REMARKS *patch*" $line]} {
	 if {[llength $line]>3} {
	    set patch [lindex $line 2]
	    foreach segres [lrange $line 3 end] {
	       lappend patch [split $segres ":"]
	    }
	    lappend patchlist [join $patch]
	 }
      } elseif {[string match "!NATOMS" $line]} {
	 break
      }
   }
   return $patchlist
}


#################################################################
# Get the angles, dihedrals and impropers that are defined in   #
# the psf file that belongs to the loaded parent molecule.      #
#################################################################

proc ::Paratool::import_conformations_from_psf { molidparent } {
   set psf [get_psffilename $molidparent]
   variable psfconformations [::Pararead::readpsfinfo $psf]
}