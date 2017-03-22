#
# Atom editing routines
#
# $Id: qmtool_atomedit.tcl,v 1.7 2005/11/24 18:04:11 saam Exp $
#

proc ::QMtool::edit_atom_properties {} {
   atomedit_update_list
   ::Atomedit::atomedit -window .qmtool_atomedit -list ::QMtool::atompropformlist \
      -format ::QMtool::atompropformtags -selectcall ::QMtool::atomedit_select_callback \
      -submitcall ::QMtool::atomedit_submit -title "QMtool - Edit atom properties" \
      -atomsel 1 -editablelist {Elem Name Flags} -editablenames {Elem Name Flags}

   set_pickmode_atomedit

   bind .qmtool_atomedit <FocusIn> {
      if {"%W"==".qmtool_atomedit" && [winfo exists .qmtool_atomedit]} {
	 ::QMtool::set_pickmode_atomedit
      }
   }

   # Clean up in case the window is destroyed:
   bind .qmtool_atomedit <Destroy> {
      mouse mode 0
      set ::QMtool::pickmode none
      trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn
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

proc ::QMtool::atomedit_update_list {} {
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
	    append formatfield {%\ 6.4f }
	 }
	 ESP     {
	    append formatstring {%7s }
	    append formatfield  {%\ 6.4f }
	 }
      }
   }

   # Build the formatted taglist
   set formatcommand "\[format \"$formatstring\" $atomproptags\]"
   eval set atompropformtags "$formatcommand"

   # Build the formatted list from formatted atom strings:
   # -----------------------------------------------------

   # Loop over all atoms
   foreach atom $atomproplist {
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
   }
         
} 

proc ::QMtool::atomedit_submit {} {
   set indexlist [.qmtool_atomedit.cart.list.list curselection]
   set active    [.qmtool_atomedit.cart.list.list index active]
   set yview     [.qmtool_atomedit.cart.list.list yview]

   if {![string equal "$::Atomedit::qmtool_atomedit_selatomElem" n/a]} {
      if {[element2atomnum $::Atomedit::qmtool_atomedit_selatomElem]<0 || 
	  ![string is alpha $::Atomedit::qmtool_atomedit_selatomElem]} { 
	 tk_messageBox -type ok -parent .qmtool_atomedit.cart.sel \
	    -message "Invalid element symbol $::Atomedit::qmtool_atomedit_selatomElem!"
	 focus .qmtool_atomedit.cart.sel.elemvalue
	 return 0 
      }
   }

   if {![string equal $::Atomedit::qmtool_atomedit_selatomName n/a]} { 
      if {![string is alnum $::Atomedit::qmtool_atomedit_selatomName]} { 
	 tk_messageBox -message "Atom name must consist of alphanumeric characters!" \
	    -type ok -parent .qmtool_atomedit.cart.sel
	 focus .qmtool_atomedit.cart.sel.namevalue
	 return 0 
      }
      if {[string length $::Atomedit::qmtool_atomedit_selatomName]>4} { 
	 tk_messageBox -message "Atom name cannot be longer than 4 alphanumeric characters!" \
	    -type ok -parent .qmtool_atomedit.cart.sel
	 focus .qmtool_atomedit.cart.sel.namevalue
	 return 0 
      }
   }

#    if {![string is integer $::Atomedit::qmtool_atomedit_selatomLewis]} { 
#       tk_messageBox -message "Atomic Lewis charge must be an integer number!" -type ok \
# 	 -parent .qmtool_atomedit.cart.sel
#       focus .qmtool_atomedit.cart.sel.lewisvalue
#       return 0
#    }

   variable atomproplist
   variable atomproptags

   foreach index $indexlist {
      foreach tag {Elem Name Flags} {
	 set value [subst $[subst ::Atomedit::qmtool_atomedit_selatom${tag}]]
	 if {![string equal $value "n/a"] && 
	     ![string equal $value [get_atomprop $tag $index]]} { 
	    set_atomprop $tag $index [subst $[subst ::Atomedit::qmtool_atomedit_selatom${tag}]]
	 }
      }
   }

   # Format the list
   atomedit_update_list

   # Restore the scrolling position
   .qmtool_atomedit.cart.list.list yview moveto [lindex $yview 0]

   focus .qmtool_atomedit.cart.list.list
}

proc ::QMtool::atomedit_select_callback { } {
   draw_selatoms
   update_atomlabels
}

proc ::QMtool::draw_selatoms {} {
   # Delete any previously generated atomlabels
   variable atommarktags
   foreach tag $atommarktags {
      draw delete $tag
   }
   set atommarktags {}

   set selatoms [.qmtool_atomedit.cart.list.list curselection]
   foreach atom $selatoms {
      set sel [atomselect top "index $atom"]
      draw color orange
      variable labelradius
      lappend atommarktags [draw sphere [join [$sel get {x y z}]] radius [expr $labelradius*2.0]]
   }
}

proc ::QMtool::set_pickmode_atomedit {} {
   global vmd_pick_atom
   variable pickmode "atomedit"
   draw delete all

   # Just to be sure we remove dangling traces
   trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn

   # Set mouse mode to pick atoms
   mouse mode 0
   mouse mode 4 2
   mouse callback on
   trace add variable vmd_pick_atom write ::QMtool::atom_picked_fctn
   puts "[trace info variable vmd_pick_atom]"
   puts "Set pickmode atomedit"
   draw_selatoms
   update_atomlabels
}

proc ::QMtool::update_atomlabels {} {

   # Don't do anything if the molecule doesn't exist or contains no frames
   variable molid
   if {[lsearch [molinfo list] $molid]<0} { return 0 }
   if {[molinfo $molid get numframes]<0}  { return 0 }

   variable natoms
   variable atomproptags
   variable labelsize

   # Delete any previously generated atomlabels
   variable atomlabeltags
   foreach labeltag $atomlabeltags {
      draw delete $labeltag
   }
   set atomlabeltags {}

   lappend atomlabeltags [draw color yellow]

   variable atomlabelselected
   set selatoms {}
   if {$atomlabelselected && [winfo exists .qmtool_atomedit.cart.list.list]} {
      set selatoms [.qmtool_atomedit.cart.list.list curselection]
   } else {
      for {set i 0} {$i<$natoms} {incr i} {
	 lappend selatoms $i
      }
   }

   foreach index $selatoms {
      set atomlabel { }
      foreach tag $atomproptags {
	 if {[subst $[subst ::QMtool::${tag}labels]]} { 
	    set value [get_atomprop $tag $index]
	    if {[llength $value]} {
	       append atomlabel " [get_atomprop $tag $index]"
	    }
	 }
      }
      
      if {![llength [string trim $atomlabel]]} { continue }
      set sel [atomselect top "index $index"]
      lappend atomlabeltags [draw text [join [$sel get {x y z}]] $atomlabel size $labelsize]

      # When we are drawing our own labels, we don't want VMD's labels
      label delete Atoms all
   }
}

proc ::QMtool::fix_atom_coordinates { indexlist } {
   foreach index $indexlist {
      set flags [get_atomprop Flags $index]
      if {![string match {*F*} $flags]} {
	 append flags F
	 set_atomprop Flags $index $flags
      }
   }
   # Format the list
   atomedit_update_list
}


proc ::QMtool::get_atomprop_index { tag } {
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
      default   { error "get_atomprop_index: Unknown atom property tag $tag" }
   }
}


proc ::QMtool::set_atomprop { type index value } {
   switch $type {
      Index   { lset ::QMtool::atomproplist $index 0 $value } 
      Elem    { lset ::QMtool::atomproplist $index 1 $value }
      Name    { lset ::QMtool::atomproplist $index 2 $value }
      Flags   { lset ::QMtool::atomproplist $index 3 $value } 
      Charge  { lset ::QMtool::atomproplist $index 4 $value } 
      Lewis   { lset ::QMtool::atomproplist $index 5 $value } 
      Mullik  { lset ::QMtool::atomproplist $index 6 $value } 
      MulliGr { lset ::QMtool::atomproplist $index 7 $value } 
      NPA     { lset ::QMtool::atomproplist $index 8 $value } 
      SupraM  { lset ::QMtool::atomproplist $index 9 $value } 
      ESP     { lset ::QMtool::atomproplist $index 10 $value }
      RESP    { lset ::QMtool::atomproplist $index 11 $value }
      ForceF  { lset ::QMtool::atomproplist $index 12 $value }
   }
}

proc ::QMtool::get_atomprop { type index } {
   switch $type {
      Index   { return [lindex $::QMtool::atomproplist $index 0] } 
      Elem    { return [lindex $::QMtool::atomproplist $index 1] }
      Name    { return [lindex $::QMtool::atomproplist $index 2] }
      Flags   { return [lindex $::QMtool::atomproplist $index 3] } 
      Charge  { return [lindex $::QMtool::atomproplist $index 4] } 
      Lewis   { return [lindex $::QMtool::atomproplist $index 5] } 
      Mullik  { return [lindex $::QMtool::atomproplist $index 6] } 
      MulliGr { return [lindex $::QMtool::atomproplist $index 7] } 
      NPA     { return [lindex $::QMtool::atomproplist $index 8] } 
      SupraM  { return [lindex $::QMtool::atomproplist $index 9] } 
      ESP     { return [lindex $::QMtool::atomproplist $index 10] }
      RESP    { return [lindex $::QMtool::atomproplist $index 11] }
      ForceF  { return [lindex $::QMtool::atomproplist $index 12] }
   }
}
