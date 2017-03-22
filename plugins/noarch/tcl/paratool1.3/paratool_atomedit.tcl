#
# Atom editing procs
#
# $Id: paratool_atomedit.tcl,v 1.42 2007/05/07 15:38:17 saam Exp $
#


#################################################################
# Calls ::Atomedit::atomedit {} to open a window with a listbox #
# for editing atom properties.                                  #
#################################################################

proc ::Paratool::edit_atom_properties {} {
   variable atompropeditabletags
   variable atompropeditablenames
   variable copychargetypes

   atomedit_update_list
   ::Atomedit::atomedit -window .paratool_atomedit -list ::Paratool::atompropformlist \
      -format ::Paratool::atompropformtags -selectcall ::Paratool::atomedit_select_callback \
      -submitcall ::Paratool::atomedit_submit -title "Paratool - Edit atom properties" \
      -copytypes $copychargetypes -copycall ::Paratool::atomedit_copycharge_callback \
      -atomsel 1 -editablelist $atompropeditabletags \
      -editablenames $atompropeditablenames -choosetypecall ::Paratool::atomedit_choose_type_gui

   set_pickmode_atomedit
   

   # Clean up in case the window is destroyed:
   bind .paratool_atomedit <Destroy> {
      if {"%W"==".qmtool_atomedit" && [winfo exists .paratool_atomedit]} {
	 puts "Destroyed window atomedit."
	 mouse mode 0
	 set ::Paratool::pickmode none
	 trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn
      }
   }
}

###############################################################
# This function generates a formatted list from the columns   #
# in $atomproplist that correspond to the tags in $taglist.   #
# The result will be stored in 'variable atompropformlist'.   #
# Further the taglist will also be formatted and stored in    #
# 'variable atompropformtags.                                 #
# The formatted lists can be passed to the 'atomedit' widget  #
# that displays the data in a listbox.                        #
###############################################################

proc ::Paratool::atomedit_update_list { {complexcheck check} } {
   variable atomproptags
   variable atomproplist
   variable atompropformtags
   variable atompropformlist {}
   if {![llength $atomproptags]} { return }

   set formatstring {}
   set formatfield {}
   foreach tag $atomproptags {
      switch $tag {
	 Index {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Elem {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Name    {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Flags    {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Type    {
	    append formatstring {%4s }
	    append formatfield  {%4s }
	 }
	 Known    {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Rname {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Resid   {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 Segid   {
	    append formatstring {%5s }
	    append formatfield  {%5s }
	 }
	 VDWeps  {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 VDWrmin {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 VDWeps14  {
	    append formatstring {%8s }
	    append formatfield  {%\ 8.4f }
	 }
	 VDWrmin14 {
	    append formatstring {%9s }
	    append formatfield  {%\ 9.4f }
	 }
	 Charge     {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 Lewis {
	    append formatstring {%5s }
	    append formatfield  {%+5i }
	 }
	 Mullik     {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 MulliGr {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 NPA    {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 SupraM    {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 ESP     {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 RESP    {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 ForceF    {
	    append formatstring {%7s }
	    append formatfield  {%\ 7.4f }
	 }
	 Comment   {
	    append formatstring {%20s }
	    append formatfield  {%20s }
	 }
      }
   }

   # Build the formatted atomproptags
   set formatcommand "\[format \"$formatstring\" $atomproptags\]"
   eval set atompropformtags "$formatcommand"

   # Build the formatted list from formatted atom strings:
   # -----------------------------------------------------

   # Loop over all atoms
   set i 0
   variable totalcharge
   if {[llength [get_atomprop Lewis 0]]} { set totalcharge 0.0 }
   foreach atom $atomproplist {
      set lewischarge [get_atomprop Lewis $i]
      if {[llength $lewischarge]} { set totalcharge [expr {$totalcharge+$lewischarge}] }

      # Loop over all properties
      set formattedatom {}
      foreach tag $atomproptags fstring $formatstring ffield $formatfield {
	 set aprop [lindex $atom [get_atomprop_index $tag]]
	 #puts "tag $tag num [get_atomprop_index $tag] aprop $aprop"
	 if {![llength $aprop]} { 
	    append formattedatom [format "$fstring " "{}"] 
	 } else {
	    set fcom "\[format \"$ffield \" $aprop\]"
	    eval append formattedatom "$fcom"
	 }
      }
      lappend atompropformlist $formattedatom
      incr i
   }

   # Recalculate existing TM-complexes
   if {$complexcheck=="check"} {
      variable molidbase
      update_unpar_complex $molidbase
   }
} 


#############################################################
# Return the indexes of the zmat entries of bonded confs    #
# that involve the atom $index.                             #
#############################################################

proc ::Paratool::atomedit_find_related_bonded_confs { index } {
   variable zmat
   set i 0
   set entrylist [list]
   foreach entry $zmat {
      if {$i==0} { incr i; continue }
      if {[lsearch $entry $index]>=0} {
	 lappend entrylist $i
      }
      incr i
   }
   return $entrylist
}


#############################################################
# Generates a list of types of the same chemical element    #
# and opens a window with a listbox to choose from if the   #
# doesn't exist yet.                                        #
#############################################################

proc ::Paratool::atomedit_choose_type {} {
   variable paramsetlist
   variable topologylist

   set indexlist $::Atomedit::paratool_atomedit_selection

   set elemlist {}
   foreach index $indexlist {
      lappend elemlist [get_atomprop Elem $index]
   }

   if {[llength [lsort -unique $elemlist]]>1} {
      variable choosetypelist {{--NONE--} {} {To choose an atom type the periodic elements} \
				  {of all selected atom must be the same!}}
      return 0
   }

   set typelist {}
   set elem [lindex $elemlist 0]
   foreach topology $topologylist {
      lappend typelist [::Toporead::topology_get types $topology]
   }
   set typelist [join $typelist]
   set pattern {^[A-Za-z0-9]+\s+[0-9.]+\s+}
   append pattern "$elem\\s+.*"
   set elemtypelist [lsearch -all -inline -regexp $typelist $pattern]

   set vdwparamlist {}
   foreach paramset $paramsetlist {
      lappend vdwparamlist [lindex $paramset 4]
   }

   variable choosetypelist {}
   foreach type $elemtypelist {
      set vdwparam [lrange [join [lsearch  -inline [join $vdwparamlist] "[lindex $type 0] *"]] 1 end]
      set vdweps14  {}
      set vdwrmin14 {}
      set vdweps  [format_float "%10.5f" [lindex $vdwparam 0] {}]
      set vdwrmin [format_float "%10.5f" [lindex $vdwparam 1] {}]
      if {[llength $vdwparam]>4 && [string index [lindex $vdwparam 2] 0]!="!"} {
	 set vdweps14  [format_float "%10.5f" [lindex $vdwparam 2] {}]
	 set vdwrmin14 [format_float "%10.5f" [lindex $vdwparam 3] {}]
      }
      lappend choosetypelist [format "%4s %10s %10s %10s %10s  %s" [lindex $type 0] $vdweps $vdwrmin \
				 $vdweps14 $vdwrmin14 [lindex $type 3]]
   }

   # Append type from UFF
   set uff [::Paratool::get_UFF_elem $elem]

   set i 1
   foreach uffentry $uff {
      set vdwrmin [format "%10.5f" [expr {0.5*[lindex $uffentry 3]}]]
      set comment "type [lindex $uffentry 0] from Universal force field"
      lappend choosetypelist [format "%4s %10s %10s  %s" ${elem}U$i \
				 [format "%10.5f" [expr {-[lindex $uffentry 4]}]] $vdwrmin $comment]
      incr i
   }
}


#############################################################
# GUI-version.                                              #
# Generates a list of types of the same chemical element    #
# and opens a window with a listbox to choose from if the   #
# doesn't exist yet.                                        #
#############################################################

proc ::Paratool::atomedit_choose_type_gui {} {
   atomedit_choose_type

   if {[winfo exists .paratool_choosetype]} {
      set geom [wm geometry .paratool_choosetype]
      wm withdraw  .paratool_choosetype
      wm deiconify .paratool_choosetype
      wm geometry  .paratool_choosetype $geom
      return
   }

   set w [toplevel ".paratool_choosetype"]
   wm title $w "Choose atom type"
   wm resizable $w 1 1

   wm protocol .paratool_choosetype WM_DELETE_WINDOW {
      .paratool_choosetype.types.list.list selection clear 0 end
      ::Paratool::atomedit_draw_selatoms
      ::Paratool::update_atomlabels
      wm withdraw .paratool_choosetype
   }

   variable selectcolor
   variable fixedfont
   labelframe $w.types -bd 2 -relief ridge -text "Atom types & VDW parameters" -padx 2m -pady 2m
   label $w.types.format -font $fixedfont -text [format "%4s %10s %10s %10s %10s  %s" Type VDWeps VDWrmin VDWeps14 VDWrmin14 Comment] \
      -relief flat -bd 2 -justify left;

   frame $w.types.list
   scrollbar $w.types.list.scroll -command "$w.types.list.list yview"
   listbox $w.types.list.list -activestyle dotbox -yscroll "$w.types.list.scroll set" -font $fixedfont \
      -width 80 -height 12 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::choosetypelist
   pack $w.types.list.list    -side left -fill both -expand 1
   pack $w.types.list.scroll  -side left -fill y -expand 1
 
   frame  $w.types.buttons
   button $w.types.buttons.set -text "Set type for selected atoms" -command ::Paratool::atomedit_set_choosetype
   button $w.types.buttons.setequiv -text "Set type for selected and equivalent atoms" \
      -command [namespace code {
	 variable molidbase
	 # Extend the current selection to all equivalent types
	 foreach selected $::Atomedit::paratool_atomedit_selection {
	    eval lappend ::Atomedit::paratool_atomedit_selection [::Paratool::find_all_equivalent_types $molidbase $selected 3]
	 }
	 set ::Atomedit::paratool_atomedit_selection [lsort -integer -unique $::Atomedit::paratool_atomedit_selection]
	 if {[winfo exists .paratool_atomedit.cart.list.list]} {
	    foreach selected $::Atomedit::paratool_atomedit_selection {
	       .paratool_atomedit.cart.list.list selection set $selected
	    }
	 }
	 ::Atomedit::atomedit_select .paratool_atomedit

	 atomedit_set_choosetype
      }]

   pack $w.types.buttons.setequiv $w.types.buttons.set -expand 1 -fill x -side left

   pack $w.types.format  -anchor w
   pack $w.types.list    -expand 1 -fill both -anchor w
   pack $w.types.buttons
   pack $w.types -padx 1m -pady 1m -fill both -expand 1 

   bind $w.types.list.list <Double-1> {
      #puts [.paratool_choosetype.types.list.list get active]
      .paratool_choosetype.types.buttons.setequiv invoke
   }
}

proc ::Paratool::atomedit_set_choosetype {} {
   variable choosetypelist
   set indexlist $::Atomedit::paratool_atomedit_selection
   set itype [.paratool_choosetype.types.list.list index active]

   set ::Atomedit::paratool_atomedit_selatomType      [lindex $choosetypelist $itype 0]
   set ::Atomedit::paratool_atomedit_selatomVDWeps    [lindex $choosetypelist $itype 1]
   set ::Atomedit::paratool_atomedit_selatomVDWrmin   [lindex $choosetypelist $itype 2]
   set ::Atomedit::paratool_atomedit_selatomVDWeps14  [lindex $choosetypelist $itype 3]
   set ::Atomedit::paratool_atomedit_selatomVDWrmin14 [lindex $choosetypelist $itype 4]
   set ::Atomedit::paratool_atomedit_selatomComment   [lindex $choosetypelist $itype 5]
   variable charmmoverridesqm
   foreach index $indexlist {
      atomedit_submit {} type
   }
   #atomedit_update_list nocomplexcheck
   focus .paratool_atomedit.cart.list.list
}


############################################################
# Try to find and assign VDW parameters for this type.     #
# Used by ::Paratool::atomedit_submit.                     #
# The new parameters are put into the interactive entries  #
# and will be set when the user submits his changes.       #
############################################################

proc ::Paratool::atomedit_assign_vdw_for_type { type } {
   # Look for this typename among the existing types
   set typelist {}
   variable topologylist
   foreach topology $topologylist {
      lappend typelist [::Toporead::topology_get types $topology]
   }
   set typelist [join $typelist]
   set pattern "$type *"
   set found [lsearch -all $typelist $pattern]

   if {[llength $found]} {
      set vdwparamlist {}
      variable paramsetlist
      foreach paramset $paramsetlist {
	 lappend vdwparamlist [lindex $paramset 4]
      }

      set vdwparam [lrange [join [lsearch  -inline [join $vdwparamlist] $pattern]] 1 end]
      set vdweps14  {}
      set vdwrmin14 {}
      set comment {}
      set vdweps    [format_float "%10.5f" [lindex $vdwparam 0] {}]
      set vdwrmin   [format_float "%10.5f" [lindex $vdwparam 1] {}]
      if {[llength $vdwparam]>4 && [string index [lindex $vdwparam 2] 0]!="!"} {
	 set vdweps14  [format_float "%10.5f" [lindex $vdwparam 2] {}]
	 set vdwrmin14 [format_float "%10.5f" [lindex $vdwparam 3] {}]
	 if {[llength [lindex $vdwparam 4]]} { set comment [format "%s" [lindex $vdwparam 5]] }
      } else {
	 if {[llength [lindex $vdwparam 2]]} { set comment [format "%s" [lindex $vdwparam 2]] }
      }

      set ::Atomedit::paratool_atomedit_selatomVDWeps  $vdweps
      set ::Atomedit::paratool_atomedit_selatomVDWrmin $vdwrmin
      set ::Atomedit::paratool_atomedit_selatomVDWeps14  $vdweps14
      set ::Atomedit::paratool_atomedit_selatomVDWrmin14 $vdwrmin14
      set ::Atomedit::paratool_atomedit_selatomComment $comment
   }
}


######################################################################
# This is called when changed atom properties shall be submittted.   #
# The new properties are updated in the list for all selected atoms. #
######################################################################

proc ::Paratool::atomedit_submit { {index {}} {field {}}} {
   variable molidbase

   set indexlist $index
   if {![llength $indexlist]} {
      set indexlist $::Atomedit::paratool_atomedit_selection
   }
   if {![llength $field]} {
      if {[string match ".paratool_atomedit.cart.sel.edit.*" [focus]]} {
	 set field [lindex [split [focus] .] end]
      }

   }
   set active    [.paratool_atomedit.cart.list.list index active]
   set yview     [.paratool_atomedit.cart.list.list yview]

   if {![string equal "$::Atomedit::paratool_atomedit_selatomElem" n/a]} {
      if {[::QMtool::element2atomnum $::Atomedit::paratool_atomedit_selatomElem]<0 || 
	  ![string is alpha $::Atomedit::paratool_atomedit_selatomElem]} { 
	 tk_messageBox -type ok -parent .paratool_atomedit.cart.sel \
	    -message "Invalid element symbol $::Atomedit::paratool_atomedit_selatomElem!"
	 focus .paratool_atomedit.cart.sel.edit.elemvalue
	 return 0 
      }
      if {![string length $::Atomedit::paratool_atomedit_selatomElem]} { 
	 tk_messageBox -type ok -parent .paratool_atomedit.cart.sel \
	    -message "You must specify a chemical element for each atom!"
	 focus .paratool_atomedit.cart.sel.edit.elemvalue
	 return 0 
      }
   }

   set lookforvdw 0
   if {![string equal $::Atomedit::paratool_atomedit_selatomName n/a]} { 
      if {![regexp {[[:alnum:]_\*']*} $::Atomedit::paratool_atomedit_selatomName]} { 
	 tk_messageBox -message "Atom name must consist of alphanumeric characters!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.namevalue
	 return 0 
      }
      if {[string length $::Atomedit::paratool_atomedit_selatomName]>4} { 
	 tk_messageBox -message "Atom name cannot be longer than 4 alphanumeric characters!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.namevalue
	 return 0 
      }
      if {![string length $::Atomedit::paratool_atomedit_selatomName]} { 
	 tk_messageBox -message "You must specify a name for each atom!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.namevalue
	 return 0 
      }

      set name $::Atomedit::paratool_atomedit_selatomName
      if {[llength $name]} {
	 foreach i $indexlist {
	    set atom [atomselect $molidbase "index $i"]
	    set resid   [join [$atom get resid]]
	    set segid   [join [$atom get segid]]
	    set resname [join [$atom get resname]]
	    $atom delete
	    if {[llength $resid] && [llength $segid]} {
	       set sel [atomselect $molidbase "segid $segid and resid $resid and name '[string map {' \\'} $name]'"]
	       if {[$sel num]>1} {
		  set ret [tk_messageBox -message "Atom name $name is not unique in residue $segid:$resid!\nUse $name anyway?" \
			      -type yesno -parent .paratool_atomedit.cart.sel]
		  if {$ret=="no"} {
		     focus .paratool_atomedit.cart.sel.edit.namevalue
		     return 0
		  }
	       }
	       $sel delete
	    }

	    # Look for this name in the appropriate RESI entry and assign the type accordingly
	    if {![string match "type*" $field]} {
	       variable topologylist
	       set namelist {}
	       # We are reading the topolist backward so that in case of a multiple resi 
	       # the last one is found
	       foreach topology [lrevert $topologylist] {
		  lappend namelist [::Toporead::topology_get_resid $topology $resname atomlist]
	       }
	       set namelist [join $namelist]
	       set type [lindex [lsearch -inline $namelist "$name *"] 1]
	       if {[llength $type] && ![string match "vdw*" $field]} {
		  set lookforvdw 1
		  set ::Atomedit::paratool_atomedit_selatomType $type
		  atomedit_assign_vdw_for_type $type
	       }
	    }
	 }
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomType n/a]} { 
      if {![regexp {[[:alnum:]_\*']*} $::Atomedit::paratool_atomedit_selatomType]} { 
	 tk_messageBox -message "Atom type must consist of alphanumeric characters!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.typevalue
	 return 0 
      }
      if {[string length $::Atomedit::paratool_atomedit_selatomType]>4} { 
	 tk_messageBox -message "Atom type cannot be longer than 4 alphanumeric characters!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.typevalue
	 return 0 
      }

      if {[string length $::Atomedit::paratool_atomedit_selatomType]} {
	 set sel [atomselect $molidbase "index $indexlist"]
	 if {[llength [lsort -unique [$sel get atomicnumber]]]>1} {
	    tk_messageBox -message "If you want to set atom types the chemical elements for all atoms must be the same!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	    focus .paratool_atomedit.cart.sel.edit.typevalue
	    return 0	    
	 }
	 $sel delete

	 foreach curind $indexlist { 
	    lappend typelist [get_atomprop Type $curind]
	 }
	 # See if one of the types has changed:
	 if {[lsearch -not $typelist $::Atomedit::paratool_atomedit_selatomType]>=0} {
	    # If a type has changed, we have to check if it is an existing type
	    variable topologylist
	    set found 0
	    foreach topology $topologylist {
	       if {[::Toporead::topology_contains_type $topology $::Atomedit::paratool_atomedit_selatomType]>=0} {
		  set found 1; break
	       }
	    }
	    # If it is an existing type we make the VDW fields readonly.
	    if {$found} {   
	       .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state disabled
	       .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state disabled
	       .paratool_atomedit.cart.sel.edit.vdweps14value configure -state disabled
	       .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state disabled
	       foreach i $indexlist {
		  set_atomprop Known $i Yes
	       }
	    } else {
	       .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state normal
	       .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state normal
	       .paratool_atomedit.cart.sel.edit.vdweps14value configure -state normal
	       .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state normal
	       foreach i $indexlist {
		  set_atomprop Known $i No
	       }
	    }
	 }
	 if {![string match "vdw*" $field]} {
	    # Try to find and assign VDW parameters for this type
	    atomedit_assign_vdw_for_type $::Atomedit::paratool_atomedit_selatomType
	 }
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomVDWeps n/a]} { 
      if {![string is double $::Atomedit::paratool_atomedit_selatomVDWeps]} { 
	 tk_messageBox -message "VDW well depth (epsilon) must be a floating point number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.vdwepsvalue
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomVDWrmin n/a]} { 
      if {![string is double $::Atomedit::paratool_atomedit_selatomVDWrmin]} { 
	 tk_messageBox -message "VDW equilibrium distance (Rmin) must be a floating point number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.vdwrminvalue
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomVDWeps14 n/a]} { 
      if {![string is double $::Atomedit::paratool_atomedit_selatomVDWeps14]} { 
	 tk_messageBox -message "VDW 1-4 well depth (epsilon) must be a floating point number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.vdweps14value
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomVDWrmin14 n/a]} { 
      if {![string is double $::Atomedit::paratool_atomedit_selatomVDWrmin14]} { 
	 tk_messageBox -message "VDW 1-4 equilibrium distance (Rmin) must be a floating point number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.vdwrmin14value
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomLewis n/a]} { 
      if {![string is integer $::Atomedit::paratool_atomedit_selatomLewis]} { 
	 tk_messageBox -message "Atomic Lewis charge must be an integer number!" -type ok \
	    -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.lewisvalue
	 return 0
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomCharge n/a]} { 
      if {![string is double $::Atomedit::paratool_atomedit_selatomCharge]} { 
	 tk_messageBox -message "Atomic partial charge must be a floating point number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.chargevalue
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomResid n/a]} { 
      if {![string is integer $::Atomedit::paratool_atomedit_selatomResid]} { 
	 tk_messageBox -message "Residue ID must be an integer number!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.residvalue
	 return 0 
      }
      if {![string length $::Atomedit::paratool_atomedit_selatomResid]} { 
	 tk_messageBox -message "You must specify a residue ID for each atom!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.residvalue
	 return 0 
      }
   }

   if {![string equal $::Atomedit::paratool_atomedit_selatomSegid n/a]} { 
      if {![string length $::Atomedit::paratool_atomedit_selatomSegid]} { 
	 tk_messageBox -message "You must specify a segment ID for each atom!" \
	    -type ok -parent .paratool_atomedit.cart.sel
	 focus .paratool_atomedit.cart.sel.edit.segidvalue
	 return 0 
      }
   }

   variable atomproplist
   variable atomproptags
   variable atompropeditabletags
   foreach index $indexlist {
      foreach tag $atompropeditabletags {
	 set value [subst $[subst ::Atomedit::paratool_atomedit_selatom${tag}]]
	 if {![string equal $value "n/a"] && 
	     ![string equal $value [get_atomprop $tag $index]]} {
	    set_atomprop $tag $index $value
	 }
      }
   }

   # In case the type was set manually, search for related bonded conformations
   # and set the CHARMM parameters accordingly, if they exist.
   if {([string length $::Atomedit::paratool_atomedit_selatomType] && \
	   ![string equal $::Atomedit::paratool_atomedit_selatomType n/a]) || $lookforvdw} {
      variable charmmoverridesqm
      if {$charmmoverridesqm} {
	 foreach index $indexlist {
	    set relconfs [atomedit_find_related_bonded_confs $index]
	    assign_known_bonded_charmm_params $relconfs
	 }
      }
   }
    
   # Format the entries
   atomedit_update_list
   assign_ForceF_charges

   # Restore the selection
   .paratool_atomedit.cart.list.list selection clear 0 end
   foreach index $::Atomedit::paratool_atomedit_selection {
      .paratool_atomedit.cart.list.list selection set $index
   }

   # Restore the scrolling position
   .paratool_atomedit.cart.list.list yview moveto [lindex $yview 0]
   
   focus .paratool_atomedit.cart.list.list

   # Update the selected residues in the component finder
   update_componentlist

   update_intcoorlist

   set ::Paratool::Refinement::onefourenergyforcelist [::Paratool::Energy::get_formatted_14_interactions]
}


####################################################
# This function is called when the user copies     #
# charges in the atomedit window.                  #
####################################################

proc ::Paratool::atomedit_copycharge_callback {} {
   foreach i [.paratool_atomedit.cart.list.list curselection] {
      set value [::Paratool::get_atomprop $::Atomedit::paratool_atomedit_copycharge $i]
      if {[llength $value]} {
	 ::Paratool::set_atomprop Charge $i $value
      }
   }

   atomedit_update_list
}


###########################################################
# Select the atoms with the given indexes, mark them in   #
# the atomedit list and draw spheres as markers into the  #
# molecule.                                               #
# This is called by atom_picked_fctn.                     #
###########################################################

proc ::Paratool::select_atoms { selatoms args } {
   set mode   clear
   set redraw 1
   set mark   {}
   # Scan for options with one argument
   foreach {i j} $args {
      if {$i=="-mode"}      then { 
	 set mode $j
      }
      if {$i=="-redraw"}    then { 
	 set redraw $j
      }
      if {$i=="-mark"}      then { 
	 set mark $j
      }
   }

   variable picklist 
   if {$mode=="add"} {
      set picklist [lsort -unique [concat $picklist $selatoms]]
   } else {
      set picklist $selatoms
   }

   if {[winfo exists .paratool_atomedit.cart.list.list]} {
      set ::Atomedit::paratool_atomedit_selection $picklist

      ::Atomedit::atomedit_select .paratool_atomedit.cart.list.list

      # Clearing the list
      if {$mode=="clear"} {
	 .paratool_atomedit.cart.list.list selection clear 0 end
      }

      # Blank all item backgrounds
      for {set i 0} {$i<[.paratool_atomedit.cart.list.list index end]} {incr i} {
	 .paratool_atomedit.cart.list.list itemconfigure $i -background {}
      }
      
      # Restore selection
      set i 0
      foreach i $::Atomedit::paratool_atomedit_selection {
	 .paratool_atomedit.cart.list.list itemconfigure $i -background $::Atomedit::selectcolor
      }
      .paratool_atomedit.cart.list.list activate $i
      .paratool_atomedit.cart.list.list see $i
   } 

   if {$redraw==1} {
      atomedit_draw_selatoms $mark
   }
   update_atomlabels
   if {[winfo exists .paratool_choosetype]} {
      atomedit_choose_type
   }
   foreach i $picklist {
      if {[get_atomprop Known $i]} {
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwepsvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrminvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdweps14value]} {
	    .paratool_atomedit.cart.sel.edit.vdweps14value configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrmin14value]} {
	    .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state disabled	 
	 }
      } else {
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwepsvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrminvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdweps14value]} {
	    .paratool_atomedit.cart.sel.edit.vdweps14value configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrmin14value]} {
	    .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state normal
	 }
      }
   }
}

proc ::Paratool::atomedit_select_callback { } {
   variable picklist $::Atomedit::paratool_atomedit_selection
   atomedit_draw_selatoms
   update_atomlabels
   if {[winfo exists .paratool_choosetype]} {
      atomedit_choose_type
   }
   foreach i $picklist {
      if {[get_atomprop Known $i]} {
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwepsvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrminvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdweps14value]} {
	    .paratool_atomedit.cart.sel.edit.vdweps14value configure -state disabled
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrmin14value]} {
	    .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state disabled	 
	 }
      } else {
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwepsvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwepsvalue  configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrminvalue]} {
	    .paratool_atomedit.cart.sel.edit.vdwrminvalue configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdweps14value]} {
	    .paratool_atomedit.cart.sel.edit.vdweps14value configure -state normal
	 }
	 if {[winfo exists .paratool_atomedit.cart.sel.edit.vdwrmin14value]} {
	    .paratool_atomedit.cart.sel.edit.vdwrmin14value configure -state normal
	 }
      }
   }
}


proc ::Paratool::set_pickmode_atomedit {} {
   global vmd_pick_atom
   variable molidbase
   variable pickmode "atomedit"
   graphics $molidbase delete all

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 0
   mouse mode 4 2
   #mouse callback on
   trace add variable vmd_pick_atom write ::Paratool::atom_picked_fctn
   #puts "[trace info variable vmd_pick_atom]"
   puts "Set pickmode atomedit"
   atomedit_draw_selatoms
   update_atomlabels
}


###########################################################
# Draw an orange sphere for all atoms that are selected.  #
# Through the option "mark" you can speccify a list of    #
# atom indexes that are marked, i.e. colored pink.        #
###########################################################

proc ::Paratool::atomedit_draw_selatoms { {mark {}} } {
   variable molidbase
   if {$molidbase<0} { return }

   # Delete any previously generated atomlabels
   variable atommarktags
   foreach tag $atommarktags {
      graphics $molidbase delete $tag
   }
   set atommarktags {}

   #set selatoms $::Atomedit::paratool_atomedit_selection
   variable labelradius
   variable labelres
   variable picklist
   foreach atom $picklist {
      set color orange
      if {$atom==$mark} { set color pink }
      set sel [atomselect $molidbase "index $atom"]
      lappend atommarktags [graphics $molidbase color $color]
      lappend atommarktags [graphics $molidbase sphere [join [$sel get {x y z}]] radius [expr {$labelradius*2}] resolution $labelres]
      $sel delete
   }
   label delete Atoms all
}


####################################################################
# Updates the atom text labels according to the atomproplist       #
####################################################################

proc ::Paratool::update_atomlabels {} {
   variable molidbase

   # Don't do anything if the molecule doesn't exist or contains no frames
   if {$molidbase<0} { return 0 }
   if {[molinfo $molidbase get numframes]<0} { return 0 }

   variable natoms
   variable atomproptags
   variable labelsize
   variable labeloffset 2

   # Delete any previously generated atomlabels
   variable atomlabeltags
   foreach labeltag $atomlabeltags {
      graphics $molidbase delete $labeltag
   }
   set atomlabeltags {}

   lappend atomlabeltags [graphics $molidbase color yellow]

   variable atomlabelselected
   set selatoms {}
   if {$atomlabelselected && [winfo exists .paratool_atomedit.cart.list.list]} {
      set selatoms $::Atomedit::paratool_atomedit_selection;
   } else {
      for {set i 0} {$i<$natoms} {incr i} {
	 lappend selatoms $i
      }
   }

   foreach index $selatoms {
      set atomlabel [string repeat " " $labeloffset]
      
      foreach tag $atomproptags {
	 if {[subst $[subst ::Paratool::${tag}labels]]} { 
	    set value [get_atomprop $tag $index]
	    if {[llength $value]} {
	       append atomlabel " [get_atomprop $tag $index]"
	    }
	 }
      }
      
      if {![llength [string trim $atomlabel]]} { continue }
      set sel [atomselect $molidbase "index $index"]
      lappend atomlabeltags [graphics $molidbase text [join [$sel get {x y z}]] $atomlabel size $labelsize]

      # When we are drawing our own labels, we don't want VMD's labels
      label delete Atoms all
   }
}


#############################################################
# Return the index (position) of a property in an entry of  #
# the atomporplist.                                         #
#############################################################

proc ::Paratool::get_atomprop_index { tag } {
   switch $tag {
      Index     { return 0 }
      Elem      { return 1 }
      Name      { return 2 }
      Flags     { return 3 }
      Charge    { return 4 }
      Lewis     { return 5 }
      Mullik    { return 6 }
      MulliGr   { return 7 }
      NPA       { return 8 }
      SupraM    { return 9 }
      ESP       { return 10 }
      RESP      { return 11 }
      ForceF    { return 12 }
      Type      { return 13 }
      Resid     { return 14 }
      Rname     { return 15 }
      Segid     { return 16 }
      VDWeps    { return 17 }
      VDWrmin   { return 18 }
      VDWeps14  { return 19 }
      VDWrmin14 { return 20 }
      Comment   { return 21 }
      Known     { return 22 }
      default   { error "get_atomprop_index: Unknown atom property tag $tag" }
   }
}


####################################################################
# Set the atom property $type of atom $index to $value.            #
####################################################################

proc ::Paratool::set_atomprop { type index value } {
   variable molidbase
   switch $type {
      Index   { lset ::Paratool::atomproplist $index 0 $value } 
      Elem    {
	 lset ::Paratool::atomproplist $index 1 $value;
	 set sel [atomselect $molidbase "index $index"]
	 $sel set atomicnumber [::QMtool::element2atomnum $value]
	 $sel delete
      }
      Name    {
	 lset ::Paratool::atomproplist $index 2 $value;
	 set sel [atomselect $molidbase "index $index"]
	 $sel set name $value
	 $sel delete
      }
      Flags   { lset ::Paratool::atomproplist $index 3 $value } 
      Charge  {
	 if {![string length $value]} { set value "0.0" }
	 lset ::Paratool::atomproplist $index 4 $value
	 set sel [atomselect $molidbase "index $index"]
	 $sel set charge $value
	 $sel delete
      } 
      Lewis   { lset ::Paratool::atomproplist $index 5 $value } 
      Mullik  { lset ::Paratool::atomproplist $index 6 $value } 
      MulliGr { lset ::Paratool::atomproplist $index 7 $value } 
      NPA     { lset ::Paratool::atomproplist $index 8 $value } 
      SupraM  { lset ::Paratool::atomproplist $index 9 $value } 
      ESP     { lset ::Paratool::atomproplist $index 10 $value }
      RESP    { lset ::Paratool::atomproplist $index 11 $value }
      ForceF  { lset ::Paratool::atomproplist $index 12 $value }
      Type    {
	 if {![llength $value]} { set value {{}} }
	 lset ::Paratool::atomproplist $index 13 $value
      	 set sel [atomselect $molidbase "index $index"]
	 $sel set type $value
	 $sel delete
      }
      Resid   {
	 lset ::Paratool::atomproplist $index 14 $value
	 set sel [atomselect $molidbase "index $index"]
	 $sel set resid $value
	 $sel delete
      }
      Rname   {
	 lset ::Paratool::atomproplist $index 15 $value
	 set sel [atomselect $molidbase "index $index"]
	 if {![llength $value]} { set value {{}} }
	 $sel set resname $value
	 $sel delete
      }
      Segid   {
	 lset ::Paratool::atomproplist $index 16 $value
	 set sel [atomselect $molidbase "index $index"]
	 $sel set segid $value
	 $sel delete
      }
      VDWeps  { lset ::Paratool::atomproplist $index 17 $value }
      VDWrmin { lset ::Paratool::atomproplist $index 18 $value }
      VDWeps14  { lset ::Paratool::atomproplist $index 19 $value }
      VDWrmin14 { lset ::Paratool::atomproplist $index 20 $value }
      Comment { lset ::Paratool::atomproplist $index 21 $value }
      Known   { lset ::Paratool::atomproplist $index 22 $value }
   }
}

proc ::Paratool::get_atomprop { type index } {
   switch $type {
      Index   { return [lindex $::Paratool::atomproplist $index 0] } 
      Elem    { return [lindex $::Paratool::atomproplist $index 1] }
      Name    { return [lindex $::Paratool::atomproplist $index 2] }
      Flags   { return [lindex $::Paratool::atomproplist $index 3] } 
      Charge  { return [lindex $::Paratool::atomproplist $index 4] } 
      Lewis   { return [lindex $::Paratool::atomproplist $index 5] } 
      Mullik  { return [lindex $::Paratool::atomproplist $index 6] } 
      MulliGr { return [lindex $::Paratool::atomproplist $index 7] } 
      NPA     { return [lindex $::Paratool::atomproplist $index 8] } 
      SupraM  { return [lindex $::Paratool::atomproplist $index 9] } 
      ESP     { return [lindex $::Paratool::atomproplist $index 10] }
      RESP    { return [lindex $::Paratool::atomproplist $index 11] }
      ForceF  { return [lindex $::Paratool::atomproplist $index 12] }
      Type    { return [lindex $::Paratool::atomproplist $index 13] }
      Resid   { return [lindex $::Paratool::atomproplist $index 14] }
      Rname   { return [lindex $::Paratool::atomproplist $index 15] }
      Segid   { return [lindex $::Paratool::atomproplist $index 16] }
      VDWeps  { return [lindex $::Paratool::atomproplist $index 17] }
      VDWrmin { return [lindex $::Paratool::atomproplist $index 18] }
      VDWeps14  { return [lindex $::Paratool::atomproplist $index 19] }
      VDWrmin14 { return [lindex $::Paratool::atomproplist $index 20] }
      Comment { return [lindex $::Paratool::atomproplist $index 21] }
      Known   { return [lindex $::Paratool::atomproplist $index 22] }
   }
}

proc ::Paratool::default_atomprop_entry {} {
   return [list {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} {} No]
}

