# hello emacs this is -*- tcl -*-
#
# Small package with GUI to clone the full set of representations
# from one molecule to another.
#
# (c) 2004-2006 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
#     
# the clone all/active/displayed molecule feature based on 
# a patch by Luis Gracia <lug2002@med.cornell.edu>
########################################################################
#
# create package and namespace and default all namespace global variables.
package provide clonerep 1.1

namespace eval ::CloneRep:: {
    namespace export clonerepgui
    namespace export clone_reps

    variable w;               # handle to the base widget.

    variable fromid  "top";   # molid of the molecule to grab
    variable toid    "all";   # molid to clone the representations to
}


#################
# the heart of the matter. clone representations.
proc ::CloneRep::clone_reps {{fromid top} {toid all}} {
    variable w;

    # parse non-numerical arguments
    if { $fromid == "top" } {
        set fromid [molinfo top]
    }
    set togroup 0 ; # target is a group of molecules
    if { $toid == "all" || $toid == "active" || $toid == "displayed" } {
        set togroup 1
    }

    # check arguments
    if {$fromid == $toid} {
        if {[info exists w]} then {
            tk_dialog .errmsg {CloneRep Error} "Cannot clone representations from molecule $fromid onto itself." error 0 Dismiss 
        } else {
            puts "clone_reps: cannot clone a representation on itself."
        }
        return
    }
    if { [lsearch -exact [molinfo list] $fromid] < 0} {
        if {[info exists w]} then {
            tk_dialog .errmsg {CloneRep Error} "Source molecule $fromid does not exists." error 0 Dismiss 
        } else {
            puts "clone_reps: source molecule id $fromid does not exist"
        }
        return
    }
    if { !$togroup && [lsearch -exact [molinfo list] $toid] < 0} {
        if {[info exists w]} then {
            tk_dialog .errmsg {CloneRep Error} "Target molecule $toid does not exists." error 0 Dismiss 
        } else {
            puts "clone_reps: target molecule id $toid does not exist"
        }
        return
    }

    set mlist {}
    if {$togroup} {
        switch $toid {
            all { set mlist [molinfo list] }
            active -
            displayed { 
                foreach m [molinfo list] {
                    if {[molinfo $m get $toid]} {
                        lappend mlist $m
                    }
                }
            }
            default {error "'cannot happen' bug in CloneRep::clone_reps"}
        }
    } else {
        lappend mlist $toid
    }

    # loop over list of target molecules
    foreach toid $mlist {
        # don't operate on the source for all reps
        if {$toid == $fromid} {continue}

        # clean reps on target (note they will always be renumbered).
        set numreps [molinfo $toid get numreps]
        for {set i 0} {$i < $numreps} {incr i} {
            mol delrep 0 $toid
        }

        # copy reps one by one
        set numreps [molinfo $fromid get numreps]
        for {set i 0} {$i < [molinfo $fromid get numreps]} {incr i} {

            # gather info about the representation
            set mi [molinfo $fromid get "{rep $i} {selection $i} {color $i} {material $i}"] 
            lassign $mi rep sel col mat
            set pbc    [mol showperiodic $fromid $i]
            set numpbc [mol numperiodic $fromid $i]
            set on     [mol showrep $fromid $i]
            set selupd [mol selupdate $i $fromid]
            set colupd [mol colupdate $i $fromid]
            set colminmax [mol scaleminmax $fromid $i]
            set smooth [mol smoothrep $fromid $i]
            set framespec [mol drawframes $fromid $i]
            # save per-representation clipping planes...
            set cplist {}
            for {set cp 0} {$cp < [mol clipplane num]} {incr cp} {
                set newcp {}
                foreach cpstat { center color normal status } {
                    lappend newcp [mol clipplane $cpstat $cp $i $fromid]
                }
                lappend cplist $newcp
            }

            # clone representation
            mol representation $rep
            mol color $col
            mol selection "$sel"
            mol material $mat
            mol addrep $toid
            if {[string length $pbc]} {
                mol showperiodic $toid $i $pbc
                mol numperiodic  $toid $i $numpbc
            }
            mol selupdate $i $toid $selupd
            mol colupdate $i $toid $colupd
            mol scaleminmax $toid $i [lindex $colminmax 0] [lindex $colminmax 1]
            mol smoothrep $toid $i $smooth
            mol drawframes $toid $i "$framespec"

            # restore per-representation clipping planes...
            set cpnum 0
            foreach cp $cplist {
                foreach { center color normal status } $cp { break }
                mol clipplane center $cpnum $i $toid $center
                mol clipplane color  $cpnum $i $toid $color
                mol clipplane normal $cpnum $i $toid $normal
                mol clipplane status $cpnum $i $toid $status
                incr cpnum
            }

            if { !$on } {
                mol showrep $toid $i off
            }
        }
    }
}

#################
# initialization.
# create main window layout
proc ::CloneRep::clonerepgui {} {
    variable w
    variable fromid 
    variable toid 

    # main window frame
    set w .clonerepgui
    catch {destroy $w}
    toplevel    $w
    wm title    $w "Clone Representations" 
    wm iconname $w "CloneRep" 
    wm minsize  $w 200 0

    # menubar
    frame $w.menubar -relief raised -bd 2
    pack $w.menubar -side top -padx 1 -fill x
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    # Help menu
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
         -command {tk_messageBox -type ok -title "About CloneRep" \
                        -message "The clonerep plugin provides a script and a GUI to copy a whole set of representations from one molecule to another. All previous representations of the target molecule are deleted.\n\nVersion 1.1\n(c) 2004-2006 by Axel Kohlmeyer\n<akohlmey@cmm.chem.upenn.edu>"}
    $w.menubar.help.menu add command -label "Help..." \
        -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/clonerep"
    pack $w.menubar.help -side right

    # from selector
    frame $w.from
    frame $w.from.mol
    label $w.from.mol.l -text "From Molecule:" -anchor w
    menubutton $w.from.mol.m -relief raised -bd 2 -direction flush \
	-textvariable ::CloneRep::fromid \
	-menu $w.from.mol.m.menu
    menu $w.from.mol.m.menu -tearoff no
    pack $w.from.mol.l -side left
    pack $w.from.mol.m -side right
    pack $w.from.mol -side top
    pack $w.from -side left

    # to selector
    frame $w.to
    frame $w.to.mol
    label $w.to.mol.l -text "To Molecule:" -anchor w
    menubutton $w.to.mol.m -relief raised -bd 2 -direction flush \
	-textvariable ::CloneRep::toid \
        -menu $w.to.mol.m.menu
    menu $w.to.mol.m.menu -tearoff no

    pack $w.to.mol.l -side left
    pack $w.to.mol.m -side right
    pack $w.to.mol -side top
    pack $w.to -side left

    # cloning
    button $w.foot -text Clone  -command [namespace code CloneRepDoClone]
    pack $w.foot -side bottom -fill x
    grid columnconfigure $w.foot 0 -weight 2 -minsize 10
    grid columnconfigure $w.foot 1 -weight 4 -minsize 10

    # layout main canvas
    grid config $w.menubar -column 0 -row 0  -columnspan 2 -rowspan 1 -sticky "snew"
    grid config $w.from  -column 0 -row 1  -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $w.to    -column 1 -row 1  -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $w.foot  -column 0 -row 2  -columnspan 2 -rowspan 1 -sticky "snew"
    grid columnconfigure $w 0 -weight 2 -minsize 150
    grid columnconfigure $w 1 -weight 1 -minsize 150

    UpdateMolecule
    global vmd_molecule
    trace variable vmd_molecule w ::CloneRep::UpdateMolecule

}

# callback for VMD menu entry
proc clonerep_tk_cb {} {
  ::CloneRep::clonerepgui
  return $::CloneRep::w
}

# update molecule list
proc ::CloneRep::UpdateMolecule { args } {
  variable w
  variable fromid
  variable toid
  global vmd_molecule

  set mollist [molinfo list]
  
  # Update the molecule browsers
  $w.from.mol.m.menu delete 0 end
  $w.from.mol.m configure -state disabled
  $w.from.mol.m.menu add radiobutton -value "top" \
    -label "Current Top Molecule" \
    -variable ::CloneRep::fromid
  $w.from.mol.m.menu add separator

  $w.to.mol.m.menu delete 0 end
  $w.to.mol.m configure -state disabled
  $w.to.mol.m.menu add radiobutton -value "all" \
    -label "All Molecules" \
    -variable ::CloneRep::toid 
  $w.to.mol.m.menu add radiobutton -value "active" \
    -label "Active Molecules" \
    -variable ::CloneRep::toid 
  $w.to.mol.m.menu add radiobutton -value "displayed" \
    -label "Displayed Molecules" \
    -variable ::CloneRep::toid 
  $w.to.mol.m.menu add separator
 
  if { [llength $mollist] != 0 } {
    foreach id $mollist {
      if {[molinfo $id get filetype] != "graphics"} {

        $w.from.mol.m configure -state normal 
        $w.from.mol.m.menu add radiobutton -value $id \
	  -label "$id [molinfo $id get name]" \
	  -variable ::CloneRep::fromid 

        $w.to.mol.m configure -state normal 
        $w.to.mol.m.menu add radiobutton -value $id \
	  -label "$id [molinfo $id get name]" \
	  -variable ::CloneRep::toid 
      }
    }
  }
}

proc ::CloneRep::CloneRepDoClone { args } {
    variable fromid
    variable toid

    ::CloneRep::clone_reps $fromid $toid
}
