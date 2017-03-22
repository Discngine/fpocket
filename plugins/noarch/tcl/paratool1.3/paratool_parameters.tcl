#
# Routines for finding existing CHARMM and UFF parameters
#

#######################################################
# Assign the VDW parameters for all known atom types. #
#######################################################

proc ::Paratool::assign_vdw_params {} {
   variable molidbase
   variable paramsetlist
   if {$molidbase<0} { return }

   set all [atomselect $molidbase all]
   set i 0
   foreach type [$all get type] {
      if {[llength $type]} {
	 foreach paramset $paramsetlist {
	    set nonbonpar [::Pararead::getvdwparam $paramset $type]
	    if {![llength $nonbonpar]} { 
	       # Set flag N for new (unknown) atom types
	       #set_atomprop Flags $i [regsub -all {N} [get_atomprop $i Flags] {}]N
	       set_atomprop Known $i No 
	       continue
	    }
	    set_atomprop VDWeps  $i [lindex $nonbonpar 0]
	    set_atomprop VDWrmin $i [lindex $nonbonpar 1]
	    set_atomprop VDWeps14  $i [lindex $nonbonpar 2]
	    set_atomprop VDWrmin14 $i [lindex $nonbonpar 3]
	    #set_atomprop Flags $i [regsub -all {N} [get_atomprop $i Flags] {}]
	    set_atomprop Known $i Yes
	    break
	 }
      }
      incr i
   }
   $all delete
   #atomedit_update_list
}


#######################################################
# Automatic assignment of VDW parameters for atoms    #
# that don't have VDW params yet.                     #
#######################################################

proc ::Paratool::autoassign_vdw_params {} {
   variable molidbase
   variable atomproplist
   foreach atom $atomproplist {
      set index [lindex $atom [get_atomprop_index Index]]
      set elem [get_atomprop Elem $index ]
      if {![llength [get_atomprop VDWeps $index]]} {
	 set_atomprop VDWeps $index [get_UFF_vdw VDWeps  $elem]
	 #set_atomprop Flags  $index [regsub -all {N} [get_atomprop $i Flags] {}]N
	 set_atomprop Known $index No
      }
      if {![llength [get_atomprop VDWrmin $index]]} {
	 set_atomprop VDWrmin $index [get_UFF_vdw VDWrmin $elem]
	 #set_atomprop Flags  $index [regsub -all {N} [get_atomprop $i Flags] {}]N
	 set_atomprop Known $index No 
      }
   }
   atomedit_update_list
}


#######################################################
# Copies ForceF charges to the Charge field for all   #
# atoms belonging to known resnames.                  #
# Correction for imidazole as a model for HSD/HSE is  #
# included.                                           #
#######################################################

proc ::Paratool::assign_ForceF_charges {} {
   variable molidbase
   variable topologylist
   if {$molidbase<0} { return }

   set all [atomselect $molidbase "all"]
   foreach resname [lsort -unique [$all get resname]] {
      # Get the atomlist for the current resname
      set atomlist {}
      foreach topology $topologylist {
	 if {[::Toporead::topology_contains_resi $topology $resname]>=0} {
	    set atomlist [::Toporead::topology_get_resid $topology $resname atomlist]
	    break
	 }
      }
      set sel [atomselect $molidbase "resname $resname"]
      foreach index [$sel list] name [$sel get name] {
	 set charge [lindex [lsearch -inline $atomlist "$name * *"] 2]
	 if {$name=="HG"} {
	    # This must be an imidazole
	    if {[string equal $resname "HSD"]} {
	       set charge 0.09
	       puts "ForceF $index $resname $charge"
	    } elseif {[string equal $resname "HSE"]} {
	       set charge 0.10
	    }
	 }
	 set_atomprop ForceF $index $charge
      }
      $sel delete
   }
   $all delete
}


##############################################################
# Assign the bonded parameters for all known atom types.     #
# If a list of indexes of zmat entries $izmatlist is         #
# provided, then consider only these conformations.          #
##############################################################

proc ::Paratool::assign_known_bonded_charmm_params { {izmatlist {}} } {
   variable molidbase
   variable paramsetlist
   variable zmat

   set i 0
   foreach t $zmat {
      # Skip zmat header
      if {$i==0} { incr i; continue }

      set indexes [lindex $t 2]

      # If $izmatlist is specified consider only these conformations.
      if {[llength $izmatlist]} {
	 if {[lsearch $izmatlist $i]<0} { incr i; continue }
      }

      # Get types for the conformation
      set typelist [get_types_for_conf $indexes]
      #puts "[lindex $t 0] izmatlist=$izmatlist typelist=$typelist"
      # Continue only if all types are known
      if {[llength $typelist]!=[llength $indexes]} { incr i; continue }
      
      set bondedpar {}
      switch [llength $typelist] {
	 2 { 
	    foreach paramset $paramsetlist {
	       set bondedpar [::Pararead::getbondparam [lindex $paramset 0] $typelist]
	       if {[llength [join $bondedpar]]} { break }
	    }
	    
	    if {[llength [join $bondedpar]]} {
	       lset ::Paratool::zmat $i 4 [lindex $bondedpar 1]
	       lset ::Paratool::zmat $i 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $i 5] {}]C"
	    } else {
	       # Remove the CHARMM flag
	       lset ::Paratool::zmat $i 5 "[regsub {[C]} [lindex $::Paratool::zmat $i 5] {}]"
	    }
	 }
	 3 {
	    foreach paramset $paramsetlist {
	       set bondedpar [::Pararead::getangleparam [lindex $paramset 1] $typelist]
	       if {[llength [join $bondedpar]]} { break }
	    }
	    if {[llength [join $bondedpar]]} {
	       set Kub [lindex $bondedpar 2 0]
	       set S0  [lindex $bondedpar 2 1]
	       if {[llength $Kub] && [llength $S0]} {
		  lset ::Paratool::zmat $i 4 [concat [lindex $bondedpar 1] $Kub $S0]
	       } else {
		  lset ::Paratool::zmat $i 4 [lindex $bondedpar 1]
	       }
	       lset ::Paratool::zmat $i 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $i 5] {}]C"
	    } else {
	       # Remove the CHARMM flag
	       lset ::Paratool::zmat $i 5 "[regsub {[C]} [lindex $::Paratool::zmat $i 5] {}]"
	    }
	 }
	 4 {
	    set conftype [lindex $t 1]
	    if {$conftype=="dihed"} {
	       foreach paramset $paramsetlist {
		  set bondedpar [::Pararead::getdihedparam [lindex $paramset 2] $typelist] 
		  if {[llength [join $bondedpar]]} { break }
	       }
	       if {[llength [join $bondedpar]]} {
		  lset ::Paratool::zmat $i 4 [lindex $bondedpar 1]
		  lset ::Paratool::zmat $i 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $i 5] {}]C"
	       } else {
		  # Remove the CHARMM flag
		  lset ::Paratool::zmat $i 5 "[regsub {[C]} [lindex $::Paratool::zmat $i 5] {}]"
	       }
	       
	    } elseif {$conftype=="imprp"} {
	       foreach paramset $paramsetlist {
		  set bondedpar [::Pararead::getimproparam [lindex $paramset 3] $typelist] 
		  if {[llength [join $bondedpar]]} { break }
	       }
	       if {[llength [join $bondedpar]]} {
		  lset ::Paratool::zmat $i 4 [lindex $bondedpar 1]
		  lset ::Paratool::zmat $i 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $i 5] {}]C"
	       } else {
		  # Remove the CHARMM flag
		  lset ::Paratool::zmat $i 5 "[regsub {[C]} [lindex $::Paratool::zmat $i 5] {}]"
	       }
	    }
	 }
      }
      incr i
   }; #END zmat loop

   update_intcoorlist
}


proc ::Paratool::choose_analog_parameters {} {
   variable molidbase
   variable zmat
   if {![winfo exists .paratool_intcoor] || ![winfo exists .paratool_chooseanalog]} { return }

   set i $::Paratool::selintcoorlist;

   if {![llength $i]} { return 0  }

   if {[llength $i]>1} { 
      # Raise the choose_analog_parameters GUI
      choose_analog_parameters_gui

      tk_messageBox -icon error -type ok -title Message -parent .paratool_intcoor \
	 -message "Too many conformations selected!\nFor choosing analog parametes you must select a single conformation!"
      return 0
   }
   #puts "choose_analog_parameters"

   incr i
   set indexes  [lindex $zmat $i 2]
   set conftype [lindex $zmat $i 1]
   set fconst   [lindex $zmat $i 4]

   set typepattern {}
   foreach index $indexes {
      set type [get_atomprop Type $index]
      if {[llength $type]} {
	 lappend typepattern $type
      } else {
	 lappend typepattern {*}
      }
   }
   variable matchtypespattern "{$typepattern} / {[lrevert $typepattern]}"
   variable matchingtypes
   if {!$matchingtypes} {
      set typepattern {}
   }

   # Determine periodic elements of all atoms
   set elemlist {}
   foreach index $indexes {
      lappend elemlist [get_atomprop Elem $index]
   }

   # Get a list of all known atomtypes
   variable topologylist
   set knowntypelist {}
   foreach topology $topologylist {
      lappend knowntypelist [::Toporead::topology_get types $topology]
   }
   set knowntypelist [join $knowntypelist]

   # Generate a list of atomtypes with the same element
   set elemtypelist [list]
   foreach elem $elemlist {
      set tmpelemtypelist [list]
      set pattern {[A-Za-z0-9]* [0-9.]* }
      append pattern "$elem *"
      set foundtypespecs [lsearch -all -inline $knowntypelist $pattern]
      foreach typespec $foundtypespecs {
	 lappend tmpelemtypelist [lindex $typespec 0]
      }
      lappend elemtypelist $tmpelemtypelist
   }

   if {[string match "*bond" $conftype]} {
      get_analog_bond_params $elemtypelist $typepattern
   } elseif {$conftype=="angle" || $conftype=="lbend"} {
      get_analog_angle_params $elemtypelist $typepattern
   } elseif {$conftype=="dihed"} {
      get_analog_dihed_params $elemtypelist $typepattern
   } elseif {$conftype=="imprp"} {
      get_analog_imprp_params $elemtypelist $typepattern
   }
}

proc ::Paratool::choose_analog_parameters_gui {} {
   if {[winfo exists .paratool_chooseanalog]} {
      set geom [wm geometry .paratool_chooseanalog]
      wm withdraw  .paratool_chooseanalog
      wm deiconify .paratool_chooseanalog
      wm geometry  .paratool_chooseanalog $geom
      return
   }

   set w [toplevel ".paratool_chooseanalog"]
   wm title $w "Choose analog parameters from force field"
   wm resizable $w 1 1

   wm protocol .paratool_chooseanalog WM_DELETE_WINDOW {
      #.paratool_chooseanalog.types.list.list selection clear 0 end
      destroy .paratool_chooseanalog
   }

   choose_analog_parameters

   variable selectcolor
   variable fixedfont
   labelframe $w.types -bd 2 -relief ridge -text "Atom types & bonded parameters" -padx 2m -pady 2m
   label $w.types.format -font $fixedfont -textvariable ::Paratool::chooseanalogformat \
      -relief flat -bd 2 -justify left;

   frame $w.types.list
   scrollbar $w.types.list.scroll -command "$w.types.list.list yview"
   listbox $w.types.list.list -yscroll "$w.types.list.scroll set" -font $fixedfont \
      -width 90 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::chooseanaloglist
   pack $w.types.list.list    -side left -fill both -expand 1
   pack $w.types.list.scroll  -side left -fill y    -expand 0

   frame $w.types.match
   checkbutton $w.types.match.check -text "List parameters for matching types only" \
      -variable ::Paratool::matchingtypes -command ::Paratool::choose_analog_parameters
   label $w.types.match.pattern -textvariable ::Paratool::matchtypespattern
   pack $w.types.match.check $w.types.match.pattern -anchor w -side left

   frame  $w.buttons
   button $w.buttons.add -text "Use parameters"    -command {
      set i [.paratool_chooseanalog.types.list.list curselection]
      set izmat [expr {$::Paratool::selintcoorlist+1}]
      if {[llength $izmat]!=1 || [llength $i]!=1} { return }
      if {[lindex $::Paratool::zmat $izmat 1]=="dihed"} {
	 lset ::Paratool::zmat $izmat 4 [lrange $::Paratool::chooseanaloglist end-3 end-1]; # Kchi, n, delta
      } elseif {[lindex $::Paratool::zmat $izmat 1]=="angle" || [lindex $::Paratool::zmat $izmat 1]=="lbend"} {
	 lset ::Paratool::zmat $izmat 4 [list [lindex $::Paratool::chooseanaloglist $i 3] \
					    [lindex $::Paratool::chooseanaloglist $i 4] \
					    [lindex $::Paratool::chooseanaloglist $i 5] \
					    [lindex $::Paratool::chooseanaloglist $i 6]]; # Theta,Ktheta,Kub,S0
      } else {
	 lset ::Paratool::zmat $izmat 4 [list [lindex $::Paratool::chooseanaloglist $i end-2] \
					    [lindex $::Paratool::chooseanaloglist $i end-1]]; # Equilib length, force const
      }
      lset ::Paratool::zmat $izmat 5 "[regsub {[QCRMA]} [lindex $::Paratool::zmat $i 5] {}]A"
      ::Paratool::update_intcoorlist
      focus .paratool_intcoor.zmat.pick.list
   }
   pack $w.buttons.add -side left

   pack $w.types.format  -anchor w
   pack $w.types.list    -expand 1 -fill both
   pack $w.types.match
   pack $w.types -padx 1m -pady 1m -expand 1 -fill both
   pack $w.buttons

   bind $w.types.list.list <Double-1> {
      .paratool_chooseanalog.buttons.add invoke
   }
}


##################################################################
# Populate the list of analog parameters.                        #
# $elemtypelistconsists of two sublists for the existing         #
# atomtypes with matching chemical element.                      #
##################################################################

proc ::Paratool::get_analog_bond_params { elemtypelist {knowntypes {}}} {
   variable paramsetlist
   variable chooseanalogformat [format "%10s  %8s %8s  %s" Atomtypes K_r r_0 Comment]
   set bondparamlist {}
   foreach paramset $paramsetlist {
      lappend bondparamlist [lindex $paramset 0]
   }
   set bondparamlist [join $bondparamlist]
   # The entries in bondparamlist look like this example:
   # {{HR3 CPH1} {365.000 1.0830} {! From imidazole (NF)}}
   set bondtypelist {}
   foreach bondparam $bondparamlist {
      lappend bondtypelist  [lindex $bondparam 0]
   }

   if {[llength $knowntypes]} {
      set newtypes0 [lsearch -inline -all [lindex $elemtypelist 0] [lindex $knowntypes 0]]
      set newtypes1 [lsearch -inline -all [lindex $elemtypelist 1] [lindex $knowntypes 1]]
      set elemtypelist [list $newtypes0 $newtypes1]
   }

   set bondcandidatelist [list]
   set pattern0 [join [lindex $elemtypelist 0] "|"]
   set pattern1 [join [lindex $elemtypelist 1] "|"]
   # Look for the types in forward and reverse order
   set poslist [lsearch -all -regexp $bondtypelist "(^($pattern0)\\s($pattern1)\$)|(^($pattern1)\\s($pattern0)\$)"]

   foreach pos $poslist {
      set bond [lindex $bondparamlist $pos]
      # format of $bond: {{HR3 CPH1} {365.000 1.0830} {! From imidazole (NF)}}
      lappend bondcandidatelist [format "%4s %4s  %8.4f %8.4f  %s" [lindex $bond 0 0] [lindex $bond 0 1] \
					     [lindex $bond 1 0] [lindex $bond 1 1] [list [lindex $bond 2]]]
   }


   #puts $bondcandidatelist

   variable chooseanaloglist $bondcandidatelist
   return $bondcandidatelist
}


proc ::Paratool::get_analog_angle_params { elemtypelist {knowntypes {}} } {
   variable paramsetlist
   variable chooseanalogformat [format "%14s  %8s %8s %8s %8s  %s" Atomtypes K_theta Theta_0 K_ub S_0 Comment]
   set angleparamlist {}
   foreach paramset $paramsetlist {
      lappend angleparamlist [lindex $paramset 1]
   }
   set angleparamlist [join $angleparamlist]
   # The entries in angleparamlist look like this example:
   # {{NR1 CPH1 HR3} {25.0 124.00} {20.00 2.14000} {! From imidazole (NF)}}
   set angletypelist {}
   foreach angleparam $angleparamlist {
      lappend angletypelist  [lindex $angleparam 0]
   }

   if {[llength $knowntypes]} {
      set newtypes0 [lsearch -inline -all [lindex $elemtypelist 0] [lindex $knowntypes 0]]
      set newtypes1 [lsearch -inline -all [lindex $elemtypelist 1] [lindex $knowntypes 1]]
      set newtypes2 [lsearch -inline -all [lindex $elemtypelist 2] [lindex $knowntypes 2]]
      set elemtypelist [list $newtypes0 $newtypes1 $newtypes2]
   }

   set anglecandidatelist [list]
   set pattern0 [join [lindex $elemtypelist 0] "|"]
   set pattern1 [join [lindex $elemtypelist 1] "|"]
   set pattern2 [join [lindex $elemtypelist 2] "|"]
   set poslist [lsearch -all -regexp $angletypelist \
		   "(^($pattern0)\\s($pattern1)\\s($pattern2)\$)|(^($pattern2)\\s($pattern1)\\s($pattern0)\$)"]
   foreach pos $poslist {
      set angle [lindex $angleparamlist $pos]
      # format of $angle {{NR1 CPH1 HR3} {25.0 124.00} {20.00 2.14000} {! From imidazole (NF)}}
      set kub [lindex $angle 2 0]
      set s0  [lindex $angle 2 1]
      if {![llength $kub]} { set kub {{}} }
      if {![llength $s0]}  { set s0  {{}} }
      lappend anglecandidatelist [format "%4s %4s %4s  %8.2f %8.4f %8s %8s %s" [lindex $angle 0 0] [lindex $angle 0 1] \
				     [lindex $angle 0 2] [lindex $angle 1 0] [lindex $angle 1 1] $kub $s0 [list [lindex $angle 3]]]
   }

   #puts $anglecandidatelist

   variable chooseanaloglist $anglecandidatelist
   return $anglecandidatelist
}

proc ::Paratool::get_analog_dihed_params { elemtypelist {knowntypes {}} } {
   set elemtypelist [list [join [list [lindex $elemtypelist 0] X]] [lindex $elemtypelist 1] \
			[lindex $elemtypelist 2] [join [list [lindex $elemtypelist 3] X]]]

   variable paramsetlist
   variable chooseanalogformat [format "%19s  %8s %2s %8s  %s" Atomtypes K_chi n delta Comment]
   set dihedparamlist {}
   foreach paramset $paramsetlist {
      lappend dihedparamlist [lindex $paramset 2]
   }
   set dihedparamlist [join $dihedparamlist]
   # The entries in bondparamlist look like this example:
   # {{ON5 CN7 CN7 ON6B} {0.4 6 0.0} !RNA}
   set dihedtypelist {}
   foreach dihedparam $dihedparamlist {
      lappend dihedtypelist  [lindex $dihedparam 0]
   }

   if {[llength $knowntypes]} {
      set newtypes0 [lsearch -inline -all [lindex $elemtypelist 0] [lindex $knowntypes 0]]
      set newtypes1 [lsearch -inline -all [lindex $elemtypelist 1] [lindex $knowntypes 1]]
      set newtypes2 [lsearch -inline -all [lindex $elemtypelist 2] [lindex $knowntypes 2]]
      set newtypes3 [lsearch -inline -all [lindex $elemtypelist 3] [lindex $knowntypes 3]]
      set elemtypelist [list $newtypes0 $newtypes1 $newtypes2 $newtypes3]
   }

   set anglecandidatelist [list]

   set dihedcandidatelist [list]
   set pattern0 [join [lindex $elemtypelist 0] "|"]
   set pattern1 [join [lindex $elemtypelist 1] "|"]
   set pattern2 [join [lindex $elemtypelist 2] "|"]
   set pattern3 [join [lindex $elemtypelist 3] "|"]
   set poslist [lsearch -regexp -all $dihedtypelist \
		   "(^($pattern0)\\s($pattern1)\\s($pattern2)\\s($pattern3)\$)|(^($pattern3)\\s($pattern2)\\s($pattern1)\\s($pattern0)\$)"]
   foreach pos $poslist {
      set dihed [lindex $dihedparamlist $pos]
      lappend dihedcandidatelist [format "%4s %4s %4s %4s  %8.4f %2i %8.1f  %s" [lindex $dihed 0 0] [lindex $dihed 0 1] \
				     [lindex $dihed 0 2] [lindex $dihed 0 3] [lindex $dihed 1 0] [lindex $dihed 1 1] \
				     [lindex $dihed 1 2] [list [lindex $dihed 2]]]
   }
   #puts $dihedcandidatelist

   variable chooseanaloglist $dihedcandidatelist
   return $dihedcandidatelist
}


proc ::Paratool::get_analog_imprp_params { elemtypelist {knowntypes {}} } {
   set elemtypelist [list [lindex $elemtypelist 0] [join [list [lindex $elemtypelist 1] X]] \
			[join [list [lindex $elemtypelist 2] X]] [lindex $elemtypelist 3]]

   variable chooseanalogformat [format "%19s  %8s %8s  %s" Atomtypes K_psi psi_0 Comment]
   variable paramsetlist
   set imprpparamlist {}
   foreach paramset $paramsetlist {
      lappend imprpparamlist [lindex $paramset 3]
   }
   # The entries in imprpparamlist look like this example:
   # {{NR1 CPH1 CPH2 CN7B} {0.60 0 0.00} {! From imidazole (NF), k increased}}
   set imprpparamlist [join $imprpparamlist]
   set imprptypelist {}
   foreach imprpparam $imprpparamlist {
      lappend imprptypelist  [lindex $imprpparam 0]
   }

   if {[llength $knowntypes]} {
      set newtypes0 [lsearch -inline -all [lindex $elemtypelist 0] [lindex $knowntypes 0]]
      set newtypes1 [lsearch -inline -all [lindex $elemtypelist 1] [lindex $knowntypes 1]]
      set newtypes2 [lsearch -inline -all [lindex $elemtypelist 2] [lindex $knowntypes 2]]
      set newtypes3 [lsearch -inline -all [lindex $elemtypelist 3] [lindex $knowntypes 3]]
      set elemtypelist [list $newtypes0 $newtypes1 $newtypes2 $newtypes3]
   }

   set imprpcandidatelist [list]
   set pattern0 [join [lindex $elemtypelist 0] "|"]
   set pattern1 [join [lindex $elemtypelist 1] "|"]
   set pattern2 [join [lindex $elemtypelist 2] "|"]
   set pattern3 [join [lindex $elemtypelist 3] "|"]
   set poslist [lsearch -regexp -all $imprptypelist "(^($pattern0)\\s($pattern1)\\s($pattern2)\\s($pattern3)\$)|(^($pattern3)\\s($pattern2)\\s($pattern1)\\s($pattern0)\$)"]
   foreach pos $poslist {
      set imprp [lindex $imprpparamlist $pos]
      lappend imprpcandidatelist [format "%4s %4s %4s %4s  %8.4f %8.1f  %s" [lindex $imprp 0 0] [lindex $imprp 0 1] \
				     [lindex $imprp 0 2] [lindex $imprp 0 3] [lindex $imprp 1 0] [lindex $imprp 1 1] \
				     [list [lindex $imprp 2]]]
   }
   
   #puts $imprpcandidatelist

   variable chooseanaloglist $imprpcandidatelist
   return $imprpcandidatelist
}


proc ::Paratool::get_UFFdata { } {
   return {
      H_    {0.354 180.0  2.886  0.044  12.0   0.712 4.5280 null}
      H_b   {0.460 83.5   2.886  0.044  12.0   0.712 4.5280 null}
      He4+4 {0.849 90.0   2.362  0.056  15.24  0.098 9.66   null}
      Li    {1.336 180.0  2.451  0.025  12.0   1.026 3.006  null}
      Be3+2 {1.074 109.47 2.745  0.085  12.0   1.565 4.877  null}
      B_3   {0.838 109.47 4.083  0.180  12.052 1.755 5.11   null}
      B_2   {0.828 120.0  4.083  0.180  12.052 1.755 5.11   sp2 }
      C_3   {0.757 109.47 3.851  0.105  12.73  1.912 5.343  sp3 }
      C_R   {0.729 120.0  3.851  0.105  12.73  1.912 5.343  sp2 }
      C_2   {0.732 120.0  3.851  0.105  12.73  1.912 5.343  sp2 }
      C_1   {0.706 180.0  3.851  0.105  12.73  1.912 5.343  null}
      N_3   {0.700 106.7  3.660  0.069  13.407 2.544 6.899  sp3 }
      N_R   {0.699 120.0  3.660  0.069  13.407 2.544 6.899  sp2 }
      N_2   {0.685 111.2  3.660  0.069  13.407 2.544 6.899  sp2 } 
      N_1   {0.656 180.0  3.660  0.069  13.407 2.544 6.899  null}
      O_3   {0.658 104.51 3.500  0.060  14.085 2.300 8.741  sp3 } 
      O_3_z {0.528 146.0  3.500  0.060  14.085 2.300 8.741  sp3 }
      O_R   {0.680 110.0  3.500  0.060  14.085 2.300 8.741  s   }
      O_2   {0.634 120.0  3.500  0.060  14.085 2.300 8.741  null}
      O_1   {0.639 180.0  3.500  0.060  14.085 2.300 8.741  null}
      F_    {0.668 180.0  3.364  0.050  14.762 1.735 10.874 null}
      Ne4+4 {0.920  90.0  3.243  0.042  15.440 0.194 11.04  null}
      Na    {1.539 180.0  2.983  0.030  12.0   1.081 2.843  null}
      Mg3+2 {1.421 109.47 3.021  0.111  12.0   1.787 3.951  null}
      A13   {1.244 109.47 4.499  0.505  11.278 1.792 4.06   null}
      Si3   {1.117 109.47 4.295  0.402  12.175 2.323 4.168  sp3 }
      P_3+3 {1.101  93.8  4.147  0.305  13.072 2.863 5.463  sp3 }
      P_3+5 {1.056 109.47 4.147  0.305  13.072 2.863 5.463  sp3 }
      P_3+q {1.056 109.47 4.147  0.305  13.072 2.863 5.463  sp3 }
      S_3+2 {1.064  92.1  4.035  0.274  13.969 2.703 6.928  sp3 }
      S_3+4 {1.049 103.20 4.035  0.274  13.969 2.703 6.928  sp3 }
      S_3+6 {1.027 109.47 4.035  0.274  13.969 2.703 6.928  sp3 } 
      S_R   {1.077  92.2  4.035  0.274  13.969 2.703 6.928  s   } 
      S_2   {0.854 120.0  4.035  0.274  13.969 2.703 6.928  sp2 } 
      Cl    {1.044 180.0  3.947  0.227  14.866 2.348 8.564  null} 
      Ar4+4 {1.032  90.0  3.868  0.185  15.763 0.300 9.465  null} 
      K     {1.953 180.0  3.812  0.035  12.0   1.165 2.421  null} 
      Ca6+2 {1.761  90.0  3.399  0.238  12.0   2.141 3.231  null} 
      Sc3+3 {1.513 109.47 3.295  0.019  12.0   2.592 3.395  null} 
      Ti3+4 {1.412 109.47 3.175  0.017  12.0   2.659 3.47   null} 
      Ti6+4 {1.412  90.0  3.175  0.017  12.0   2.659 3.47   null} 
      V_3+5 {1.402 109.47 3.144  0.016  12.0   2.679 3.65   null} 
      Cr6+3 {1.345  90.0  3.023  0.015  12.0   2.463 3.415  null} 
      Mn6+2 {1.382  90.0  2.961  0.013  12.0   2.43  3.325  null}  
      Fe3+2 {1.270 109.47 2.912  0.013  12.0   2.43  3.76   null}  
      Fe6+2 {1.335  90.0  2.912  0.013  12.0   2.43  3.76   null}  
      Co6+3 {1.241  90.0  2.872  0.014  12.0   2.43  4.105  null}  
      Ni4+2 {1.164  90.0  2.834  0.015  12.0   2.43  4.465  null}  
      Cu3+1 {1.302 109.47 3.495  0.005  12.0   1.756 3.729  null} 
      Zn3+2 {1.193 109.47 2.763  0.124  12.0   1.308 5.106  null} 
      Ga3+3 {1.260 109.47 4.383  0.415  11.0   1.821 3.641  null} 
      Ge3   {1.197 109.47 4.280  0.379  12.0   2.789 4.051  sp3 } 
      As3+3 {1.211  92.1  4.230  0.309  13.0   2.864 5.188  sp3 } 
      Se3+2 {1.190  90.6  4.205  0.291  14.0   2.764 6.428  sp3 } 
      Br    {1.192 180.0  4.189  0.251  15.0   2.519 7.790  null} 
      Kr4+4 {1.147  90.0  4.141  0.220  16.0   0.452 8.505  null} 
      Rb    {2.260 180.0  4.114  0.04   12.0   1.592 2.331  null} 
      Sr6+2 {2.052  90.0  3.641  0.235  12.0   2.449 3.024  null} 
      Y_3+3 {1.698 109.47 3.345  0.072  12.0   3.257 3.83   null} 
      Zr3+4 {1.564 109.47 3.124  0.069  12.0   3.667 3.40   null} 
      Nb3+5 {1.473 109.47 3.165  0.059  12.0   3.618 3.55   null} 
      Mo6+6 {1.467  90.0  3.052  0.056  12.0   3.40  3.465  null}  
      Mo3+6 {1.484 109.47 3.052  0.056  12.0   3.40  3.465  null}  
      Tc6+5 {1.322  90.0  2.998  0.048  12.0   3.40  3.29   null}
      Ru6+2 {1.478  90.0  2.963  0.056  12.0   3.40  3.575  null}
      Rh6+3 {1.332  90.0  2.929  0.053  12.0   3.508 3.975  null}
      Pd4+2 {1.338  90.0  2.899  0.048  12.0   3.21  4.32   null}
      Agl+l {1.386 180.0  3.148  0.036  12.0   1.956 4.439  null}
      Cd3+2 {1.403 109.47 2.848  0.228  12.0   1.65  5.034  null}
      In3+3 {1.459 109.47 4.463  0.599  11.0   2.07  3.506  null}
      Sn3   {1.398 109.47 4.392  0.567  12.0   2.961 3.987  sp3 }
      Sb3+3 {1.407  91.6  4.420  0.449  13.0   2.704 4.899  sp3 }
      Te3+2 {1.386  90.25 4.470  0.398  14.0   2.882 5.816  sp3 }
      I_    {1.382 180.0  4.50   0.339  15.0   2.65  6.822  null}
      Xe4+4 {1.267  90.0  4.404  0.332  12.0   0.556 7.595  null}
      Cs    {2.570 180.0  4.517  0.045  12.0   1.573 2.183  null}
      Ba6+2 {2.277  90.0  3.703  0.364  12.0   2.727 2.814  null}
      La3+3 {1.943 109.47 3.522  0.017  12.0   3.30  2.8355 null}
      Ce6+3 {1.841  90.0  3.556  0.013  12.0   3.30  2.774  null}
      Pr6+3 {1.823  90.0  3.606  0.010  12.0   3.30  2.858  null}
      Nd6+3 {1.816  90.0  3.575  0.010  12.0   3.30  2.8685 null}
      Pm6+3 {1.801 90.0   3.547  0.009  12.0   3.30  2.881  null}
      Sm6+3 {1.780  90.0  3.520  0.008  12.0   3.30  2.9115 null}
      Eu6+3 {1.771  90.0  3.493  0.008  12.0   3.30  2.8785 null}
      Gd6+3 {1.735  90.0  3.368  0.009  12.0   3.30  3.1665 null}
      Tb6+3 {1.732  90.0  3.451  0.007  12.0   3.30  3.018  null}
      Dy6+3 {1.710  90.0  3.428  0.007  12.0   3.30  3.0555 null}
      Ho6+3 {1.696  90.0  3.409  0.007  12.0   3.416 3.127  null}
      Er6+3 {1.673  90.0  3.391  0.007  12.0   3.30  3.1865 null}
      Tm6+3 {1.660  90.0  3.374  0.006  12.0   3.30  3.2514 null}
      Yb6+3 {1.637  90.0  3.355  0.228  12.0   2.618 3.2889 null}
      Lu6+3 {1.671  90.0  3.640  0.041  12.0   3.271 2.9629 null}
      Hf3+4 {1.611 109.47 3.141  0.072  12.0   3.921 3.70   null}
      Ta3+5 {1.511 109.47 3.170  0.081  12.0   4.075 5.10   null}
      W_6+6 {1.392  90.0  3.069  0.067  12.0   3.70  4.63   null}
      W_3+4 {1.526 109.47 3.069  0.067  12.0   3.70  4.63   null} 
      W_3+6 {1.380 109.47 3.069  0.067  12.0   3.70  4.63   null} 
      Re6+5 {1.372  90.0  2.954  0.066  12.0   3.70  3.96   null} 
      Re3+7 {1.314 109.47 2.954  0.066  12.0   3.70  3.96   null} 
      Os6+6 {1.372  90.0  3.120  0.037  12.0   3.70  5.14   null} 
      Ir6+3 {1.371  90.0  2.840  0.073  12.0   3.731 5.00   null}
      Pt4+2 {1.364  90.0  2.754  0.080  12.0   3.382 4.79   null}
      Au4+3 {1.262  90.0  3.293  0.039  12.0   2.625 4.894  null}
      Hg1+2 {1.340 180.0  2.705  0.385  12.0   1.75  6.27   null} 
      T13+3 {1.518 120.0  4.347  0.680  11.0   2.068 3.20   null}
      Pb3   {1.459 109.47 4.297  0.663  12.0   2.846 3.90   sp3 }
      Bi3+3 {1.512  90.0  4.370  0.518  13.0   2.470 4.69   sp3 }
      Po3+2 {1.50   90.0  4.709  0.325  14.0   2.33  4.21   sp3 } 
      At    {1.545 180.0  4.750  0.284  15.0   2.24  4.75   null} 
      Rn4+4 {1.420  90.0  4.765  0.248  16.0   0.583 5.37   null}
      Fr    {2.880 180.0  4.90   0.050  12.0   1.847 2.00   null}
      Ra6+2 {2.512  90.0  3.677  0.404  12.0   2.92  2.843  null} 
      Ac6+3 {1.983  90.0  3.478  0.033  12.0   3.90  2.835  null} 
      Th6+4 {1.721  90.0  3.396  0.026  12.0   4.202 3.175  null}
      Pa6+4 {1.711  90.0  3.424  0.022  12.0   3.90  2.985  null} 
      U_6+4 {1.684  90.0  3.395  0.022  12.0   3.90  3.341  null} 
      Np6+4 {1.666  90.0  3.424  0.019  12.0   3.90  3.549  null} 
      Pu6+4 {1.657  90.0  3.424  0.016  12.0   3.90  3.243  null} 
      Am6+4 {1.660  90.0  3.381  0.014  12.0   3.90  2.9895 null} 
      Cm6+3 {1.801  90.0  3.326  0.013  12.0   3.90  2.8315 null} 
      Bk6+3 {1.761  90.0  3.339  0.013  12.0   3.90  3.1935 null} 
      Cf6+3 {1.750  90.0  3.313  0.013  12.0   3.90  3.197  null} 
      Es6+3 {1.724  90.0  3.299  0.012  12.0   3.90  3.333  null} 
      Fm6+3 {1.712  90.0  3.286  0.012  12.0   3.90  3.40   null} 
      Md6+3 {1.689  90.0  3.274  0.011  12.0   3.90  3.47   null} 
      No6+3 {1.679  90.0  3.248  0.011  12.0   3.90  3.475  null} 
      Lr6+3 {1.698  90.0  3.236  0.011  12.0   3.90  3.500  null} 
   }
}

proc ::Paratool::get_UFF_elem { elem } {
   array set UFFatomicdata [get_UFFdata]

   if {[string length $elem]>1} {
      set elem "[string index $elem 0][string tolower [string index $elem 1]]"
   }
   if {[string length $elem]==1} { append elem "_" }

   set entryarray [array get UFFatomicdata "${elem}*"]

   set entries {}
   foreach {type data} $entryarray {
      lappend entries [join [list $type $data]]
   }
   return $entries
}

proc ::Paratool::get_UFF_vdw { type elem } {
   # The VDW data are the same for all types of the same element
   # so we need only one entry.
   set entry [lindex [get_UFF_elem $elem] 1]

   switch $type {
      VDWrmin { return [expr {0.5*[lindex $entry 3]}] }
      VDWeps  { return [expr {-[lindex $entry 4]}] }
   }
}

#############################################################
# Returns UFF bond parameters for the given types.          #
# Needs the bondorder as input.                             #
# This is only roughly correct, I still have to add code    #
# For special cases...                                      #
#############################################################

proc ::Paratool::get_UFF_bond { type1 type2 bondorder } {
   array set UFFdata [get_UFFdata]
   set entry1 [lindex [array get UFFdata "$type1"] 1]
   set entry2 [lindex [array get UFFdata "$type2"] 1]
   set ri [lindex $entry1 0]
   set rj [lindex $entry2 0]
   set Xi [lindex $entry1 6]
   set Xj [lindex $entry2 6]
   set rbo [expr {0.1332*($ri+$rj)*log($bondorder)}]
   set ren [expr {$ri*$rj*pow(sqrt($Xi)-sqrt($Xj),2)/($Xi*$ri+$Xj*$rj)}]
   set rij [expr {$ri+$rj+$rbo-$ren}]
   
   set Zi [lindex $entry1 5]
   set Zj [lindex $entry2 5]
   set kij [expr {664.12*($Zi*$Zj)/pow($rij,3)}]
   return [list $rij $kij]
}

###############################################################
# Returns UFF angle parameters.                               #
#                                                             #
# PROBLEM: The angles in UFF are described using a periodic   #
# potential to account for geometries with different angles   #
# for the same types like opposite and adjacent ligands in    #
# octahedral complexes.                                       #
# We are just using the harmonic equivalent of the force      #
# constant with an equilibrium angle of 90 deg for these      #
# cases. Thus octahedral complexes will be wrong!             #
# No idea yet how to resolve this issue...                    #
###############################################################

proc ::Paratool::get_UFF_angle { type1 type2 type3 rij rjk } {
   array set UFFdata [get_UFFdata]
   set entry1 [lindex [array get UFFdata "$type1"] 1]
   set entry2 [lindex [array get UFFdata "$type2"] 1]
   set entry3 [lindex [array get UFFdata "$type3"] 1]
   set theta1 [lindex $entry1 1]
   set theta2 [lindex $entry2 1]
   set theta3 [lindex $entry3 1]
   set theta [expr {($theta1+$theta2+$theta3)/3.0}]

   set beta [expr {664.12/($rij*$rjk)}]
   set kijk [expr {$beta*($Zi*$Zk)/pow($rij,5)*$rij*$rjk*(3.0*$rij*$rjk*(1-pow(cos($theta),2)) - $rik*$rik*cos($theta))}]
   return [list $theta $kijk]
}


proc ::Paratool::get_intcoor_typelist {intcoorlist args} {
   set ignoreflagC 0
   if {[lindex $args 0]=="-ignoreflagC"} { set ignoreflagC 1 }

   variable zmat
   if {$intcoorlist=="all"} {
      # Generate a zero based list of all intcoords
      set intcoorlist {}
      for {set i 0} {$i<[llength $zmat]-1} {incr i} {
	 lappend intcoorlist $i
      }
   }

   set i -1
   set zmattypelist {}
   foreach entry $zmat {
      if {$i==-1} { incr i; continue }

      if {[lsearch $intcoorlist $i]<0} {
	 lappend zmattypelist {}; incr i; continue
      }

      # Don't consider entries with flag "C" if -ignoreflagC was set
      if {$ignoreflagC && [string match {*C*} [lindex $entry 5]]} {
	 lappend zmattypelist {}; incr i; continue
      }

      # Don't consider entries with missing parameters
      if {[llength [lindex $entry 4]]<2} { 
	 lappend zmattypelist {}; incr i; continue
      }

      set types [get_types_for_conf [lindex $entry 2]]

      # We only consider entries with known types for all atoms
      if {[llength [join $types]]!=[llength [lindex $entry 2]]} { lappend zmattypelist {}; incr i; continue }

      lappend zmattypelist $types
      incr i; 
   }

   return $zmattypelist
}


#################################################################
# Takes a list of internal coordinate  (zero based) and groups  #
# them into equivalent entries, i.e. coordinates consisting of  #
# the same atomtypes.                                           #
# The internal coordinates are specified by zero based indices. #
# Internal coordinate whose parameters are listed in the force  #
# field (flag "C") are ignored.                                 #
# Example:                                                      #
# get_equivalent_internal_coordinate_groups {3 4 5 6 7 8 9 10}  #
# > 3 4 {5 7} 6 {8 9 10}                                        #
# this would mean entries 5, 7  and 8, 9, 10 are equivalent     #
#################################################################

proc ::Paratool::get_equivalent_internal_coordinate_groups {intcoorlist args} {
   set zmattypelist [get_intcoor_typelist $intcoorlist $args]

   # Group into equivalent entries
   set grouplist {}
   foreach entry [lsort -unique $zmattypelist] {
      if {![llength $entry]} { continue }
      set pos    [lsearch -all $zmattypelist $entry]
      set revpos [lsearch -all $zmattypelist [lrevert $entry]]
      set allpos [lsort -unique -integer [concat $pos $revpos]]
      #puts "entry=$entry; allpos=$allpos"
      if {[llength $pos]} {
	 lappend grouplist $allpos
      }
   }

   return [lsort -unique -dictionary $grouplist]
}

proc ::Paratool::symmetrize_parameters { {intcoorlist {}} {zmattype zmat}} {
   variable zmat
   variable zmatqm
   # Initialize zmt to zmat or zmatqm
   set zmt [subst $$zmattype]

   variable selintcoorlist

   if {![llength $intcoorlist]} {
      if {[llength $selintcoorlist]} {
	 set intcoorlist $selintcoorlist
      } else {
	 return
      }
   } else {
      if {$intcoorlist=="-all"} {
	 set intcoorlist {}
	 for {set i 0} {$i<=[llength $zmt]} {incr i} {
	    lappend intcoorlist $i
	 }
      }
   }

   # First we process the impropers since they're a special case:
   # Symmetrizing here means rounding the equilibrium angle to 0.0
   # or 180.0 deg if we are within 5 degrees of these targets.
   # Otherwise either something is wrong with the structure or the user has 
   # assigned an improper where under normal conditions there should be none.
   foreach selintcoor $intcoorlist {
      set izmat [expr {$selintcoor+1}]
      set entry [lindex $zmt $izmat]
      # We are ignoring entries with flag "C"
      if {[string match {*C*} [lindex $entry 5]]} { continue }

      if {[string equal imprp [lindex $entry 1]]} {
	 set imprp [lindex $entry 4 1]
	 if {$imprp>175.0 && $imprp<185.0} {
	    lset zmt $izmat 4 1 180.0
	 } elseif {$imprp>-5.0 && $imprp<5.0} {
	    lset zmt $izmat 4 1 0.0
	 }
      }
   }

   set grouplist [get_equivalent_internal_coordinate_groups $intcoorlist -ignoreflagC]

   foreach group $grouplist {
      if {[llength $group]<=1} { continue }
      set equi 0.0
      set para 0.0
      set kub  0.0
      set s0   0.0
      puts "Group [get_types_for_conf [lindex $zmt [expr {1+[lindex $group 0]}] 2]]:"

      # Get the average parameter values for the current group
      foreach intcoor $group {
	 set zmatentry [lindex $zmt [expr {$intcoor+1}]]
	 set conftype [lindex $zmatentry 1]
	 if {![llength [lindex $zmatentry 4]] ||
	     ![llength [lindex $zmatentry 4 0]] || ![llength [lindex $zmatentry 4 1]]} { 
	    continue
	 }
	 set equi [expr {$equi+[lindex $zmatentry 4 1]}]
	 if {[regexp "angle|lbend" $conftype]} {
	    set para [expr {$para+[lindex $zmatentry 4 0]}]
	    puts "add [lindex $zmatentry 0] [lindex $zmatentry 4 0]"
	    if {[llength [lindex $zmatentry 4 2]]} {
	       set kub  [expr {$kub+[lindex $zmatentry 4 2]}]
	    }
	    if {[llength [lindex $zmatentry 4 3]]} {
	       set s0   [expr {$s0+[lindex $zmatentry 4 3]}]
	    }
	 } elseif {[string equal "dihed" $conftype]} {
	    set para [expr {$para+[lindex $zmatentry 4 0]}]
	 } else {
	    set para [expr {$para+[lindex $zmatentry 4 0]}]
	 }
      }
      set grouplen [expr {double([llength $group])}]
      set equi [expr {$equi/$grouplen}]
      set para [expr {$para/$grouplen}]
      set kub  [expr {$kub/$grouplen}]
      set s0   [expr {$s0/$grouplen}]

      foreach intcoor $group {
	 set izmat [expr {$intcoor+1}]
	 set entry [lindex $zmt $izmat]
	 set conftype [lindex $entry 1]
	 if {![llength [lindex $entry 4]] ||
	     ![llength [lindex $entry 4 0]] || ![llength [lindex $entry 4 1]]} { 
	    continue
	 }
	 set grouptypes [get_types_for_conf [lindex $entry 2]]
	 puts -nonewline [format "Symmetrizing %-4s %s" [lindex $entry 0] $grouptypes]
	 puts ": $equi; $para";
	 if {[regexp ".*bond|imprp" $conftype]} {
	    lset zmt $izmat 4 0 $para
	    lset zmt $izmat 4 1 $equi
	 } elseif {[regexp "angle|lbend" $conftype]} {
	    lset zmt $izmat 4 0 $para
	    lset zmt $izmat 4 1 $equi
	    if {[llength [lindex $entry 4 2]]} {
	       lset zmt $izmat 4 2 $kub
	    }
	    if {[llength [lindex $entry 4 3]]} {
	       lset zmt $izmat 4 3 $s0
	    }
	 } elseif {[string equal "dihed" $conftype]} {
	    lset zmt $izmat 4 0 $para
	 }
      }
   }
   set $zmattype $zmt
   update_intcoorlist
}


######################################################
# Write a CHARMM parameter file.                     #
######################################################

proc ::Paratool::write_parameter_file { file {temporary "-permanent"}} {
   variable istmcomplex
   variable isironsulfur
   if {$istmcomplex || $isironsulfur} { 
      write_tmcomplex_parameters $file
      return 
   }


   variable molidbase
   variable zmat
   set fid [open $file w]

   write_charmm_para_header $fid


   set all [atomselect $molidbase all]
   set resnamelist [lsort -unique [$all get resname]]

   variable paramsetfiles
   variable paramsetlist
   puts $fid "! Parameters for components $resnamelist"
   puts $fid "! To be used in combination with:"
   foreach parafile $paramsetfiles {
      puts $fid "! $parafile"
   }

   write_bond_parameters  $fid [lsearch -inline -all $zmat {* *bond *}]
   write_angle_parameters $fid [lsearch -regexp -all -inline $zmat "(angle|lbend)\\s+"]
   write_dihed_parameters $fid [lsearch -inline -all $zmat {* dihed *}]
   write_imprp_parameters $fid [lsearch -inline -all $zmat {* imprp *}]

   set nonbondedlist {}
   # Loop over all atoms
   foreach i [$all list] type [$all get type] {
      if {![llength $type] || $type=={}} { 
	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
	    -message "Empty type name found for atom $i! Please specify all type names."
	 return $i
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
	 set vdweps  [get_atomprop VDWeps $i]
	 set vdwrmin [get_atomprop VDWrmin $i]
	 set vdweps14  [get_atomprop VDWeps14 $i]
	 set vdwrmin14 [get_atomprop VDWrmin14 $i]
	 if {![llength $vdweps] || ![llength $vdwrmin]} {
	    tk_messageBox -icon error -type ok -title Message -parent .paratool \
	       -message "Empty VDW parameters for atom $i! Please specify all VDW parameters."
	    return $i
	 }
	 lappend nonbondedlist [list $type $vdweps $vdwrmin $vdweps14 $vdwrmin14 $comment]
      }
   }

   write_nonb_parameters $fid $nonbondedlist

   puts $fid "END"
   close $fid
   $all delete
   if {$temporary!="-temporary"} { variable newparamfile $file }
   #puts "Wrote parameter file $file"
}


proc ::Paratool::write_bond_parameters { fid zmatbonds }  {
   puts $fid "

BONDS
!
!V(bond) = Kb(b - b0)**2
!
!Kb: kcal/mole/A**2
!b0: A
!
!atom type   Kb         b0
!
"

   foreach entry $zmatbonds {
      set params [lindex $entry 4]
      if {[lindex $entry 5]=="C" || ![llength $params]} { continue }

      set indexes [lindex $entry 2]

      set typelist [lindex $entry 6]
      if {![llength $typelist]} {
	 set typelist [get_types_for_conf [string trim [string map {x ""} [lindex $entry 2]]]]
      }

      # Continue only if all types are known
      if {[llength $typelist]!=[llength $indexes]} { continue }

      puts $fid [format "%-4s %-4s  %9.3f %9.4f" [lindex $typelist 0] [lindex $typelist 1] \
		    [lindex $params 0] [lindex $params 1]]
   }

}


proc ::Paratool::write_angle_parameters { fid zmatangles }  {
   puts $fid "

ANGLES
!
!V(angle) = Ktheta(Theta - Theta0)**2
!
!V(Urey-Bradley) = Kub(S - S0)**2
!
!Ktheta: kcal/mole/rad**2
!Theta0: degrees
!Kub: kcal/mole/A**2 (Urey-Bradley)
!S0: A
!
!atom types        Ktheta    Theta0    Kub      S0
!
"

   foreach entry $zmatangles {
      set params [lindex $entry 4]
      if {[lindex $entry 5]=="C" || ![llength $params]} { continue }

      set indexes [lindex $entry 2]
      set typelist [lindex $entry 6]
      if {![llength $typelist]} {
         set typelist [get_types_for_conf [string trim [string map {x ""} $indexes]]]
      }

      # Continue only if all types are known
      if {[llength $typelist]!=[llength $indexes]} { continue }

      set kub [lindex $params 2] 
      set s0  [lindex $params 3]
      if {[llength $kub] && [llength $s0]} {
	 puts $fid [format "%-4s %-4s %-4s  %9.3f %9.2f %9.2f %9.4f" [lindex $typelist 0] [lindex $typelist 1] \
		       [lindex $typelist 2] [lindex $params 0] [lindex $params 1] $kub $s0]
      } else {
	 puts $fid [format "%-4s %-4s %-4s  %9.3f %9.2f" [lindex $typelist 0] [lindex $typelist 1] \
		       [lindex $typelist 2] [lindex $params 0] [lindex $params 1]]
      }
   }
}


proc ::Paratool::write_dihed_parameters { fid zmatdiheds }  {
   puts $fid "

DIHEDRALS
!
!V(dihedral) = Kchi(1 + cos(n(chi) - delta))
!
!Kchi: kcal/mole
!n: multiplicity
!delta: degrees
!
!atom types             Kchi     n    delta
!
"

   foreach entry $zmatdiheds {
      set params [lindex $entry 4]
      if {[lindex $entry 5]=="C" || ![llength $params]} { continue }

      set indexes [lindex $entry 2]
      set typelist [lindex $entry 6]
      if {![llength $typelist]} {
	 set typelist [get_types_for_conf [string trim [string map {x ""} $indexes]]]
      }

      # Continue only if all types are known
      if {[llength $typelist]!=[llength $indexes]} { continue }

      puts $fid [format "%-4s %-4s %-4s %-4s  %9.4f %3i %9.2f" [lindex $typelist 0] [lindex $typelist 1] \
		    [lindex $typelist 2] [lindex $typelist 3] [lindex $params 0] [lindex $params 1] [lindex $params 2]]
   }
}

proc ::Paratool::write_imprp_parameters { fid zmatimprps }  {
   puts $fid "
IMPROPER
!
!V(improper) = Kpsi(psi - psi0)**2
!
!Kpsi: kcal/mole/rad**2
!psi0: degrees
!note that the second column of numbers (0) is ignored
!
!atom types             Kpsi        0  psi0
!
"

   foreach entry $zmatimprps {
      set params [lindex $entry 4]
      if {[lindex $entry 5]=="C" || ![llength $params]} { continue }

      set indexes [lindex $entry 2]
      set typelist [lindex $entry 6]
      if {![llength $typelist]} {
         set typelist [get_types_for_conf [string trim [string map {x ""} $indexes]]]
      }


      # Continue only if all types are known
      if {[llength $typelist]!=[llength $indexes]} { continue }

      puts $fid [format "%-4s %-4s %-4s %-4s  %9.4f    0  %9.4f" [lindex $typelist 0] [lindex $typelist 1] \
		    [lindex $typelist 2] [lindex $typelist 3] [lindex $params 0] [lindex $params 1]]
   }
}


proc ::Paratool::get_types_for_conf { indexes } {
   variable tmnewtypes

   # Get types for the conformation
   set typelist {}
   foreach ind $indexes {
      set segid [get_atomprop Segid $ind]
      set resid [get_atomprop Resid $ind]
      set name  [get_atomprop Name $ind]
      set type  [get_atomprop Type $ind]
      if {![llength $type]} { break }

      set newtype [lsearch -inline $tmnewtypes "$segid $resid $name $type *"]

      if {[llength $newtype]} {
	 set type [lindex $newtype 4]
      }

      lappend typelist $type
   }

   return $typelist
}


proc ::Paratool::write_charmm_para_header { fid } {
puts $fid "!>>>>>> Combined CHARMM All-Hydrogen Parameter File for <<<<<<<<<
!>>>>>>>>> CHARMM22 Proteins and CHARMM27 Lipids <<<<<<<<<<
!from
!>>>> CHARMM22 All-Hydrogen Parameter File for Proteins <<<<<<<<<<
!>>>>>>>>>>>>>>>>>>>>>> August 1999 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<
!>>>>>>> Direct comments to Alexander D. MacKerell Jr. <<<<<<<<<
!>>>>>> 410-706-7442 or email: alex,mmiris.ab.umd.edu  <<<<<<<<<
!and\
!  \\\\\\\ CHARMM27 All-Hydrogen Lipid Parameter File ///////
!  \\\\\\\\\\\\\\\\\\ Developmental /////////////////////////
!              Alexander D. MacKerell Jr.
!                     August 1999
! All comments to ADM jr.  email:alex,mmiris.ab.umd.edu
!              telephone: 410-706-7442
!

"
   write_citation $fid
}



proc ::Paratool::write_nonb_parameters { fid nonbondedlist }  {
   puts $fid "

NONBONDED nbxmod  5 atom cdiel shift vatom vdistance vswitch -
cutnb 14.0 ctofnb 12.0 ctonnb 10.0 eps 1.0 e14fac 1.0 wmin 1.5
                !adm jr., 5/08/91, suggested cutoff scheme
!
!V(Lennard-Jones) = Eps(i,j)*\[(Rmin(i,j)/r(i,j))**12 - 2(Rmin(i,j)/r(i,j))**6\]
!
!epsilon \[kcal/mole\]: Eps(i,j) = sqrt(eps(i) * eps(j))
!Rmin/2  \[A\]:         Rmin(i,j) = Rmin/2(i) + Rmin/2(j)
!
!atom  ignored   epsilon     Rmin/2  ignored   eps,1-4     Rmin/2,1-4
!
"
   foreach nonbonded $nonbondedlist {
      set eps    [format_float "%8.4f" [lindex $nonbonded 1] {}]
      set rmin   [format_float "%8.4f" [lindex $nonbonded 2] {}]
      set eps14  [format_float "%8.4f" [lindex $nonbonded 3] {}]
      set rmin14 [format_float "%8.4f" [lindex $nonbonded 4] {}]
      if {[llength $eps14]} {
         puts $fid [format "%-4s     0.0    %8s   %8s    0.0    %8s   %8s  ! %s" \
            [lindex $nonbonded 0] $eps $rmin $eps14 $rmin14 [lindex $nonbonded 5]]
      } else {
         puts $fid [format "%-4s     0.0    %8s   %8s    ! %s" \
            [lindex $nonbonded 0] $eps $rmin [lindex $nonbonded 5]]
      }
   }
}


proc ::Paratool::write_nbfix_parameters { fid nbfixlist }  {
   puts $fid "
NBFIX ! Explicit nonbonded pair interactions
!
!atom atom   epsilon      Rmin/2
!

"

   foreach nbfix $nbfixlist {
      puts $fid [format "%-4s %-4s %8.4f %8.4f  ! %s" [lindex $nbfix 0] [lindex $nbfix 1] \
		    [lindex $nbfix 2] [lindex $nbfix 3] [lindex $nbfix 4]]
   }
}