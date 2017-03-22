# hello emacs this is -*- tcl -*-
#
# GUI to allow interactive animations by stepping between molecules.
#
# (c) 2007 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
#
# thanks to Marco DeVivo for the inspiration.
#     
########################################################################
#
# create package and namespace and default all namespace global variables.
package provide multimolanim 1.0

namespace eval ::MultiMolAnim:: {
    namespace export molanimgui molmovie

    variable w;                         # handle to the base widget.
    variable current 0;                 # currently displayed molecule
    variable loopidx 0;                 # loop counter index
    variable loopmax 0;                 # loop counter end
    variable delay 500;                 # time between frames
    variable direction 1;               # direction of animation (1 forward, -1 backward)
    variable mlist [molinfo list];      # list of current molecules
    variable mnum [molinfo num];        # number of molecules
}

# stop animation
proc ::MultiMolAnim::StopAnim { args } {
    variable loopmax

    set loopmax 0
    return
}

# update molecule slider
proc ::MultiMolAnim::UpdateMolecule { args } {
    variable w
    variable mlist
    variable mnum

    set mlist [molinfo list]
    set mnum [molinfo num]
    set f $w.frame

    # update molecule slider range
    if {$mnum > 0} {
      $f.ms configure -state enabled -to [expr $mnum - 1] -resolution 1 -variable [namespace current]::current
    } else {
      $f.ms configure -state disabled
    }
}

#################
# the heart of the matter. switch visible molecule
proc ::MultiMolAnim::molmovie {{loops 10} {dir 1} {dummy 0}} {
    variable mnum
    variable mlist
    variable current
    variable delay
    variable direction
    variable loopmax
    variable loopidx

    # nothing to do for no molecules
    if { $mnum < 1 } {
       return
    }

    # handle stop request
    if { $loops == 0 } then {
        set loopmax 0
        return
    }

    # handle slider change
    if { $loops == -1 } then {
        foreach m $mlist {mol off $m}
        mol on [lindex $mlist $current]
        mol top [lindex $mlist $current]
        display update
        display update ui
        return
    }

    # animate (a few steps or longer)
    set direction $dir
    set loopmax $loops
    for {set loopidx 0} {$loopidx < $loopmax} {incr loopidx} {
        set current [expr ($current + $direction) % $mnum]
        foreach m $mlist {mol off $m}
        mol on [lindex $mlist $current]
        mol top [lindex $mlist $current]
        display update
        display update ui
        after $delay
    }
}

#################
# initialization.
# create main window layout
proc ::MultiMolAnim::molanimgui {} {
    variable w
    variable mlist
    variable mnum
    
    set mlist [molinfo list]
    set mnum [molinfo num]

    # main window frame
    set w .molanimgui
    catch {destroy $w}
    toplevel    $w
    wm title    $w "Multiple Molecule Animation" 
    wm iconname $w "MultiMolAnim" 
    wm minsize  $w 300 200

    # menubar
    frame $w.menubar -relief raised -bd 2
    pack $w.menubar -side top -padx 1 -fill x
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    # Help menu
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
        -command {tk_messageBox -type ok -title "About MultiMolAnim" \
                      -message "The the multimolanim plugin provides a script and a GUI to use multiple VMD 'molecules' for interactive animations and thus working around the VMD limit of not allowing frames with different structure or number of atoms in a single molecule for normal animations.\n\nVersion 1.0\n(c) 2007 by Axel Kohlmeyer\n<akohlmey@cmm.chem.upenn.edu>"}
    $w.menubar.help.menu add command -label "Help..." \
        -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/multimolanim"
    pack $w.menubar.help -side right

    # main frame
    set f $w.frame
    frame $f -bd 2 -relief raised
    pack $f -side top -fill x

    grid configure $w.menubar -row 0 -column 0 -sticky "snew"
    grid configure $w.frame -row 1 -column 0 -sticky "snew"
    grid rowconfigure $w 0 -weight 0
    grid rowconfigure $w 1 -weight 1 -minsize 40
    grid columnconfigure $w 0 -weight 1 -minsize 220

    label $f.m -relief groove -text "Molecule:"
    if {$mnum > 0} then {
        scale $f.ms -orient horizontal -length 180 -sliderlength 30 -from 0 -to [expr $mnum - 1] -resolution 1 -variable [namespace current]::current -command [namespace code {molmovie -1 1}]
    } else {
        scale $f.ms -state disabled -orient horizontal -length 180 -sliderlength 30 -from 0 -to 1 -resolution 1 -variable [namespace current]::current -command [namespace code {molmovie -1 1}]
    }
    label $f.s -relief groove -text "Delay:"
    scale $f.ss -orient horizontal -length 180 -sliderlength 30 -from 0 -to 2000 -resolution 10 -variable [namespace current]::delay
    label $f.c -relief flat -text ""
    button $f.cpb -text "Play Backw." -command [namespace code {molmovie 99999 -1}]
    button $f.csb -text "Step Backw." -command [namespace code {molmovie     1 -1}]
    button $f.cst -text "Stop"        -command [namespace code StopAnim]
    button $f.csf -text "Step Forw."  -command [namespace code {molmovie     1  1}]
    button $f.cpf -text "Play Forw."  -command [namespace code {molmovie 99999  1}]

    pack $f.m -side left 
    pack $f.ms -side left -fill x
    pack $f.s -side left 
    pack $f.ss -side left -fill x
    pack $f.c -side left
    pack $f.cpb -side left -fill x
    pack $f.csb -side left -fill x
    pack $f.cst -side left -fill x
    pack $f.csf -side left -fill x
    pack $f.cpf -side left -fill x

    
    grid configure $f.m -row 0 -column 0 -sticky "wnes"
    grid configure $f.ms -row 0 -column 1 -columnspan 5 -sticky "wnes"
    grid configure $f.s -row 1 -column 0 -sticky "wnes"
    grid configure $f.ss -row 1 -column 1 -columnspan 5 -sticky "wnes"
    grid configure $f.c -row 2 -column 0 -sticky "wnes"
    grid configure $f.cpb -row 2 -column 1 -sticky "wnes"
    grid configure $f.csb -row 2 -column 2 -sticky "wnes"
    grid configure $f.cst -row 2 -column 3 -sticky "wnes"
    grid configure $f.csf -row 2 -column 4 -sticky "wnes"
    grid configure $f.cpf -row 2 -column 5 -sticky "wnes"
    grid columnconfigure $f 0 -weight 0 -minsize 20
    grid columnconfigure $f 1 -weight 100 -minsize 40
    grid columnconfigure $f 2 -weight 100 -minsize 40
    grid columnconfigure $f 3 -weight 100 -minsize 40
    grid columnconfigure $f 4 -weight 100 -minsize 40
    grid columnconfigure $f 5 -weight 100 -minsize 40

    global vmd_molecule 
    global vmd_quit
    trace variable vmd_molecule w ::MultiMolAnim::UpdateMolecule
    trace variable vmd_quit w ::MultiMolAnim::StopAnim
}

# callback for VMD menu entry
proc molanim_tk_cb {} {
    ::MultiMolAnim::molanimgui
    return $::MultiMolAnim::w
}

