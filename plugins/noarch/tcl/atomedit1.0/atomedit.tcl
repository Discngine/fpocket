#
# Atomedit provides a widget to display and modify atom based
# features in a list.
#
# $Id: atomedit.tcl,v 1.14 2007/05/07 15:43:43 saam Exp $
#
package provide atomedit 1.0

namespace eval ::Atomedit:: {
   namespace export atomedit_gui

   variable selectcolor lightsteelblue
   variable fixedfont {Courier 9}
}

proc atomedit { args } {
   ::Atomedit::atom_edit { args }
}


#####################################################
# This wrapper is for convenience. You can specify  #
# the input as command line options.                #
#####################################################

proc ::Atomedit::atomedit { args } {
   set window             {}
   set listvar            {}
   set atompropformat     {}
   set title              {}
   set copytypes          {}
   set atomsel            {}
   set editablelist       {}
   set editablenames      {}
   set copycallback       {}
   set selectcallback     {}
   set submitcallback     {}
   set choosetypecallback {}

   # Scan for options with one argument
   foreach {i j} $args {
      if {[string index $i 0]!="-"} { error "Unknown option $i" }
      set type [string range $i 1 end]
      switch $type {
	 window { set window $j }
	 list   { set listvar $j }
	 format { set atompropformat $j }
	 title  { set title $j }
	 copytypes      { set copytypes $j }
	 copycall       { set copycallback $j }
	 editablelist   { set editablelist $j }
	 editablenames  { set editablenames $j }
	 atomsel        { set atomsel $j }
	 selectcall     { set selectcallback $j }
	 submitcall     { set submitcallback $j }
	 choosetypecall { set choosetypecallback $j }
	 default { continue }
      }
   }

   atomedit_gui $window $listvar $atompropformat $selectcallback $submitcallback $title $copytypes \
      $copycallback $atomsel $editablelist $editablenames $choosetypecallback
}




#####################################################
# Add/Edit atom properties - Start the GUI.         #
#####################################################

proc ::Atomedit::atomedit_gui { window listvar atompropformtags selectcallback submitcallback \
				   {title Atomedit} {copychargetypes {}} {copychargecallback {}} \
				   {atomsel {}} {editablelist {}} {editablenames {}} \
				   {choosetypecallback {}} } {
   variable selectcolor
   variable fixedfont

   # We have to keep some window specific variables in the
   # namespace so that we can have multiple instances of this
   # GUI, owned by different programs.
   set prefix "[lindex [split $window .] 1]"
   variable ${prefix}_editablenames     $editablenames
   variable ${prefix}_listvar           $listvar
   variable ${prefix}_atompropformtags  $atompropformtags
   variable ${prefix}_selectcallback    $selectcallback
   variable ${prefix}_submitcallback    $submitcallback
   variable ${prefix}_atomsel           {}
   variable ${prefix}_copychargetypes   $copychargetypes
   variable ${prefix}_copycharge        [lindex $copychargetypes 0]
   variable ${prefix}_selection        
   if {![info exists ${prefix}_selection]} {
      variable ${prefix}_selection 0
   }

   # If already initialized, just turn on
   if { [winfo exists $window] } {
      set geom [wm    geometry $window]
      wm withdraw  $window
      wm deiconify $window
      wm geometry  $window $geom
      focus $window
      return
   }
   
   set v [toplevel $window]
   wm title $v $title
   wm resizable $v 1 1
   
   labelframe $v.cart -bd 2 -relief ridge -text "Select atoms"  -padx 2 -pady 2
   label $v.cart.label -wraplength 10c -justify left -text "-Pick atoms in VMD window or from the list.-" \
      -fg green3


   frame $v.cart.list
   label $v.cart.list.format -font $fixedfont -textvariable $atompropformtags -relief flat -bd 2 -justify left;
   #listbox $v.cart.list.format -font $fixedfont  -relief flat -bd 2 -height 1 -width 0 
   #eval $v.cart.list.format insert 0 "$$atompropformtags"
   #scrollbar $v.cart.list.xscroll -command "$v.cart.list.list xview" -orient horizontal
   scrollbar $v.cart.list.yscroll -command "$v.cart.list.list yview"
   listbox $v.cart.list.list -selectbackground $selectcolor -height 6 -width 0 \
      -yscroll "$v.cart.list.yscroll set" -font $fixedfont -selectmode extended \
      -activestyle dotbox -listvariable $listvar -setgrid 1
   pack $v.cart.list.format  -side top -anchor w
   pack $v.cart.list.list    -side left -fill both -expand 1
   pack $v.cart.list.yscroll -side right -fill y 

   pack $v.cart.label  -pady 2m
   pack $v.cart.list -padx 1m -pady 1m -fill y -expand 1


   # This adds buttons with which you can copy values from various charge fields
   # like Mullik or ESP into the charge field of the molecule, i.e. the charge that 
   # you can retrieve using atomselect.
   if {[llength $copychargetypes]} {
      frame  $v.cart.copy
      label  $v.cart.copy.title -text "Copy charges of selected atoms"
      label  $v.cart.copy.charges -text "Charges " -font $fixedfont
      button $v.cart.copy.button  -text "<--"  -font {-size 10 -weight bold} \
	 -command $copychargecallback

      eval tk_optionMenu $v.cart.copy.type ::Atomedit::${prefix}_copycharge \
		     [subst $[subst ${prefix}_copychargetypes]]
      $v.cart.copy.type configure -font $fixedfont

      grid   $v.cart.copy.title   -row 1 -columnspan 3
      grid   $v.cart.copy.charges -row 2 -column 0
      grid   $v.cart.copy.button  -row 2 -column 1
      grid   $v.cart.copy.type    -row 2 -column 2
      pack $v.cart.copy -padx 1m -pady 1m
   }

   # Entry for typing in VMD atomselections:
   if {$atomsel} {
      label $v.cart.atomsellabel -text "VMD atom selection:"
      entry $v.cart.atomsel -validate key -vcmd {
	 if {![string equal %V forced]} { return 1 }
	 set prefix "[lindex [split %W .] 1]"
	 set window ".[lindex [split %W .] 1]"
	 if {![catch { set ${prefix}_atomsel [atomselect top "%P"] }]} {
	    # Clear old selection
	    $window.cart.list.list selection clear 0 end

	    # Blank the background:
	    foreach i [subst $[subst ::Atomedit::${prefix}_selection]] {
	       $window.cart.list.list itemconfigure $i -background {}
	    }
	    # Make new selection
	    foreach i [[subst $${prefix}_atomsel] list] {
	       $window.cart.list.list selection set $i
	    }
	    # Delete the atomselection to save memory:
	    [subst $${prefix}_atomsel] delete

	    # Update the selection list
	    set ::Atomedit::${prefix}_selection [$window.cart.list.list curselection]

	    # Update the list
	    ::Atomedit::atomedit_select $window
	    return 1
	 } else {
	    tk_messageBox -icon error -type ok \
	       -title Message -parent %W \
	       -message "atomselect: cannot parse selection text: %P"
	    raise $window
	    focus %W
	    return 0
	 }
      }

      pack $v.cart.atomsellabel -anchor w
      pack $v.cart.atomsel $v.cart.atomsellabel -fill x -padx 1m -pady 1m

      # If you hit <Return> the atomselection will be validated:
      bind $v.cart.atomsel <Return> {
	 %W validate
      }
   }

   # Generate a list of entries that can be used to edit the corresponding
   # fields of the selected atoms. If multiple atoms are selected and a property
   # differs, i.e. they have different atom names "n/a" will be displayed in the
   # entry. I you edit an entry the new value will be set for all selected atoms
   # after you submit the changes. The string "n/a" is of course ignored.
   set len [llength $editablelist]
   if {$len} {
      labelframe $v.cart.sel -text "Editable atom properties" -padx 1m -pady 1m
      frame $v.cart.sel.edit
      set row 0
      foreach editablefield $editablelist name $editablenames {
	 set win [string tolower $name]
	 label $v.cart.sel.edit.${win}label -text " $name:"
	 entry $v.cart.sel.edit.${win}value -width 9 -textvariable ::Atomedit::${prefix}_selatom${name}
	 if {$row<=[expr ($len)/2]} {
	    # List properties in one column
	    grid $v.cart.sel.edit.${win}label -row $row -column 0 -sticky w
	    grid $v.cart.sel.edit.${win}value -row $row -column 1 -padx 2m
	 } else {
	    # List properties in two columns
	    grid $v.cart.sel.edit.${win}label -row [expr $row-(1+$len)/2] -column 2 -sticky w
	    grid $v.cart.sel.edit.${win}value -row [expr $row-(1+$len)/2] -column 3 -padx 2m
	 }

	 # Hitting <Return> is equivalent to pressing the submit button
	 bind $v.cart.sel.edit.${win}value <Return> {
	    set prefix [lindex [split %W .] 1]
	    eval [subst $[subst ::Atomedit::${prefix}_submitcallback]];# {{}} [lindex [split %W .] end]
	 }
	 incr row
      }
      pack $v.cart.sel.edit -pady 1m


      frame $v.cart.sel.buttons
      button $v.cart.sel.buttons.submit  -text "Submit changes" -command "$submitcallback"
      pack $v.cart.sel.buttons.submit -side right

      if {[lsearch $editablenames Type]>=0 && [llength $choosetypecallback]} {
	 button $v.cart.sel.buttons.choose  -text "Choose Type" -command "$choosetypecallback"
	 pack $v.cart.sel.buttons.choose -side right 

	 bind $v.cart.list.list <Double-1> {
	    set window ".[lindex [split %W .] 1]"
	    $window.cart.sel.buttons.choose invoke
	 }
      }

      pack $v.cart.sel.buttons

      pack $v.cart.sel -padx 1m -pady 1m;
   }


   pack $v.cart  -fill both -expand 1 -padx 1m -pady 1m


   # This will be executed when a new atom is selected:   
   bind $v.cart.list.list <<ListboxSelect>> {
      set prefix [lindex [split %W .] 1]
      # Store current selection
      set ::Atomedit::${prefix}_selection [%W curselection]
      ::Atomedit::atomedit_select ".[lindex [split %W .] 1]"
      #puts "Selected atom [subst $[subst ::Atomedit::${prefix}_selection]]"
   }

   bind $v <FocusIn> {
      set window ".[lindex [split %W .] 1]"
      if {![string match "$window.cart.sel*" %W] && ![string match "$window.cart.atomsel*" %W]} {
 	 focus $window.cart.list.list
      }
   }

   bind $v.cart.list.list <FocusIn> {
      set prefix [lindex [split %W .] 1]
      #::Atomedit::set_pickmode_editatom

      # Blank all item backgrounds
      for {set i 0} {$i<[%W index end]} {incr i} {
 	 %W itemconfigure $i -background {}
      }

      # Restore selection
      foreach i [subst $[subst ::Atomedit::${prefix}_selection]] {
	 %W selection set $i
      }
      
      %W see active
   }

   # This will be executed when the focus leaves the window
   bind $v.cart.list.list <FocusOut> {
      set prefix [lindex [split %W .] 1]

      # Store current selection
      set curselection [subst $[subst ::Atomedit::${prefix}_selection]]

      # Set background color for selected items
      foreach i $curselection {
	 %W itemconfigure $i -background $::Atomedit::selectcolor
      }
      
      #::Atomedit::update_drawing
   }
   

   #set_pickmode_editatom
   foreach index [subst $[subst ::Atomedit::${prefix}_selection]] {
      $v.cart.list.list selection set $index; 
      $v.cart.list.list activate $index; 
   }
   
   atomedit_select $v

 }

proc ::Atomedit::update_copycharge_menu { window taglist } {
   set prefix "[lindex [split $window .] 1]"
   variable ${prefix}_copychargetypes {}
   if {![winfo exists $window.cart.copy.type.menu]} { return }

   $window.cart.copy.type.menu delete 0 end
   foreach tag $taglist {
      lappend ${prefix}_copychargetypes $tag
      $window.cart.copy.type.menu add radiobutton -variable ::Atomedit::${prefix}_copycharge \
	 -label $tag
   }
   variable ${prefix}_copycharge [lindex $taglist 0]
}

proc ::Atomedit::atomedit_select { window } {
   if {![winfo exists $window]} { return }

   set prefix "[lindex [split $window .] 1]"
   variable ${prefix}_listvar
   variable ${prefix}_editablenames
   variable ${prefix}_selectcallback
   variable ${prefix}_atompropformtags
   set listvar          [subst $[subst $${prefix}_listvar]]
   set atompropformtags [subst $[subst $${prefix}_atompropformtags]]
   set editablenames    [subst $${prefix}_editablenames]
   set selectcallback   [subst $${prefix}_selectcallback]

   set atomind [subst $[subst ::Atomedit::${prefix}_selection]]

   if {![llength $atomind]} { return }

   if {[llength $atomind]==1} {
      foreach name $editablenames {
	 set field [lsearch $atompropformtags $name]
	 set value [lindex $listvar $atomind $field]
	 if {![llength $value]} { 
	    eval variable ${prefix}_selatom${name} {{}}
	 } else {
	    eval variable ${prefix}_selatom${name} $value
	 }
      }
   } else {
      foreach name $editablenames {
	 set field [lsearch $atompropformtags $name]
	 set oldvalue [lindex $listvar [lindex $atomind 0] $field]
	 set same 1
	 foreach i $atomind {
	    set value [lindex $listvar $i $field]
	    if {![string equal $value $oldvalue]} { set same 0; break }
	    set oldvalue $value
	 }
	 if {$same} {
	    variable ${prefix}_selatom${name} $value
	 } else {
	    variable ${prefix}_selatom${name} {n/a}
	 }
      }
   }

   # Execute a user provided function:
   $selectcallback
}


proc ::Atomedit::reset { window } {
   set prefix "[lindex [split $window .] 1]"

   # Clear selection
   $window.cart.list.list selection clear 0 end

   # This will delete all labels and markers because no atoms are selected
   variable ${prefix}_selectcallback
   eval [subst $[subst ${prefix}_selectcallback]]

   #mouse mode 0; 
   #set ::Atomedit::picklist {};
   #set ::Atomedit::pickmode none;
   eval unset [info vars ::Atomedit::${prefix}_*]
}


