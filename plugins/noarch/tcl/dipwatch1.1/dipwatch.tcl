# hello emacs this is -*- tcl -*-
#
# Small package with GUI to add a (dynamic) representation 
# of a dipole to selections
#
# (c) 2006 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
#     
########################################################################
#
# create package and namespace and default all namespace global variables.
package provide dipwatch 1.1

namespace eval ::DipWatch:: {
    namespace export dipwatchgui

    variable w;               # handle to the base widget.
    variable numdips 6;       # number of dipoles (could be made dynamical)
    variable diptoggle;       # on/off flags for dipoles
    variable dipmolid;        # molecule id for dipoles
    variable dipoldmolid;     # old molecule id for dipoles
    variable dipselstr;       # selection string for dipoles
    variable dipcolor;        # color of dipoles
    variable dipscale;        # scaling factor for dipole arrow
    variable dipradius;       # radius for dipole arrow
    variable dipvalue;        # value of the dipole moment
    variable dipgidlist;      # dipole gid lists

    for {set i 0} {$i < $numdips} {incr i} {
        set diptoggle($i) 0
        set dipmolid($i)  0
        set dipoldmolid($i)  0
        set dipselstr($i) all
        set dipcolor($i) red
        set dipscale($i) 1.0
        set dipradius($i) 0.2
        set dipvalue($i) {  0.00 D}
        set dipgidlist($i) {}
    }
}


proc ::DipWatch::CheckMolID {dip} {
    variable diptoggle
    variable dipmolid
    variable dipoldmolid
    variable dipgidlist

    if {$dipmolid($dip) != $dipoldmolid($dip) } {
        if {$diptoggle($dip)} {
            foreach g $dipgidlist($dip) { 
                graphics $dipoldmolid($dip) delete $g
            }
        }
        set dipoldmolid($dip) $dipmolid($dip)
    }
    DrawDips
}

proc ::DipWatch::EntryUpdate {dip} {
    DrawDips
    return 1
}


# update molecule list
proc ::DipWatch::UpdateMolecule { args } {
    variable w
    variable diptoggle
    variable dipmolid
    global vmd_molecule

    set mollist [molinfo list]
    set f $w.frame

    # Update the molecule browsers (and enable/disable seletors)
    foreach i [lsort [array names diptoggle]] {
        $f.m$i.menu delete 0 end
        $f.m$i configure -state disabled
        $f.b$i configure -state disabled
        if { [llength $mollist] != 0 } {
            foreach id $mollist {
                $f.m$i.menu add radiobutton -value $id \
                    -label "$id [molinfo $id get name]" \
                    -variable ::DipWatch::dipmolid($i) \
                    -command "::DipWatch::CheckMolID $i"
            }
            $f.b$i configure -state normal
            $f.m$i configure -state normal 
            if { [lsearch -exact $mollist $dipmolid($i)] < 0} {
                set dipmolid($i) [lindex $mollist 0]
                set dipoldmolid($i) [lindex $mollist 0]
                set dipgidlist($i) {}
            }
        } else {
            set diptoggle($i) 0
        }
    }
}

#################
# the heart of the matter. draw a dipole.
proc ::DipWatch::draw_dipole {mol sel {color red} {scale 1.0} {radius 0.2} {dipidx 0}} {
    variable dipvalue

    set res 6
    set gidlist {}
    set filled yes
    set debye 4.77350732929

    if {[catch {measure center $sel} center]} {
        puts "problem computing dipole center: $center"
        return {}
    }
    if {[catch {measure dipole $sel} vector]} {
        puts "problem computing dipole vector: $vector"
        return {}
    }

    set dipvalue($dipidx) [format "%6.2f D" [expr $debye * [veclength $vector]]]
    set vechalf [vecscale [expr $scale * 0.5] $vector]

    lappend gidlist [graphics $mol color $color]
    lappend gidlist [graphics $mol cylinder [vecsub $center $vechalf] \
                         [vecadd $center [vecscale 0.7 $vechalf]] \
                         radius $radius resolution $res filled $filled]
    lappend gidlist [graphics $mol cone [vecadd $center [vecscale 0.7 $vechalf]] \
                         [vecadd $center $vechalf] radius [expr $radius * 1.7] \
                             resolution $res]
    return $gidlist
}

###########################3
# update all dipoles
proc ::DipWatch::DrawDips {args} {
    variable w;
    variable dipgidlist;
    variable diptoggle;
    variable dipmolid;
    variable dipselstr;
    variable dipcolor;
    variable dipscale;
    variable dipradius;

    display update off
    foreach i [array names dipgidlist] {
        if {$diptoggle($i)} {
            if {[catch {atomselect $dipmolid($i) $dipselstr($i)} sel]} {
                puts "problem creating atom selection for dipole $i: $sel"
                continue
            }
            foreach g $dipgidlist($i) { 
                graphics $dipmolid($i) delete $g
            }
            set dipgidlist($i) [draw_dipole $dipmolid($i) $sel \
                                    $dipcolor($i) $dipscale($i) $dipradius($i) $i]
            $sel delete
        }
    }
    display update on
}


#################
# fix up dipole drawing after an en-/disable event
proc ::DipWatch::ButtonToggle {args} {
    variable w
    variable diptoggle
    variable dipmolid
    variable dipgidlist


    set dip [lindex $args 0]
    if {$diptoggle($dip) == 0} {
        foreach g $dipgidlist($dip) { 
            graphics $dipmolid($dip) delete $g
        }
    }

    DrawDips
}
#################
# initialization.
# create main window layout
proc ::DipWatch::dipwatchgui {} {
    variable w
    variable dipgidlist
    variable diptoggle

    # main window frame
    set w .dipwatchgui
    catch {destroy $w}
    toplevel    $w
    wm title    $w "Dipole Monitoring Tool" 
    wm iconname $w "DipWatch" 
    wm minsize  $w 300 200

    # menubar
    frame $w.menubar -relief raised -bd 2
    pack $w.menubar -side top -padx 1 -fill x
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    # Help menu
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
        -command {tk_messageBox -type ok -title "About DipWatch" \
                      -message "The dipwatch plugin provides a script and a GUI to draw arrows inside a molecule to represent the dipole moment of a given selection.\n\nVersion 1.0\n(c) 2006 by Axel Kohlmeyer\n<akohlmey@cmm.chem.upenn.edu>"}
    $w.menubar.help.menu add command -label "Help..." \
        -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/dipwatch"
    pack $w.menubar.help -side right

    # main frame
    set f $w.frame
    frame $f -bd 2 -relief raised
    pack $f -side top -fill x

    grid configure $w.menubar -row 0 -column 0 -sticky "snew"
    grid configure $w.frame -row 1 -column 0 -sticky "snew"
    grid rowconfigure $w 0 -weight 0
    grid rowconfigure $w 1 -weight 1 -minsize 200
    grid columnconfigure $w 0 -weight 1 -minsize 200

    # create entries for the list of dipoles
    label $f.b -text "Dipole \#:"
    label $f.m -text "Molecule \#:"
    label $f.s -text "Selection:"
    label $f.c -text "Color:"
    label $f.f -text "Scaling:"
    label $f.r -text "Radius:"
    label $f.v -text "Value:"
    grid configure $f.b -row 0 -column 0 -sticky "snew"
    grid configure $f.m -row 0 -column 1 -sticky "snew"
    grid configure $f.s -row 0 -column 2 -sticky "snew"
    grid configure $f.c -row 0 -column 3 -sticky "snew"
    grid configure $f.f -row 0 -column 4 -sticky "snew"
    grid configure $f.r -row 0 -column 5 -sticky "snew"
    grid configure $f.v -row 0 -column 6 -sticky "snew"
    grid rowconfigure $f 0 -weight 0 -minsize 10

    set colors [colorinfo colors]

    foreach i [lsort [array names dipgidlist]] {
        checkbutton $f.b$i -variable ::DipWatch::diptoggle($i) \
            -text "Dipole $i:" -command "::DipWatch::ButtonToggle $i"
        entry $f.s$i -textvariable ::DipWatch::dipselstr($i) \
            -validatecommand "::DipWatch::EntryUpdate $i" \
            -validate focusout
        menubutton $f.m$i -relief raised -bd 2 -direction flush \
            -textvariable  ::DipWatch::dipmolid($i) \
            -menu $f.m$i.menu -width 10
        menu $f.m$i.menu -tearoff no
        menubutton $f.c$i -relief raised -bd 2 -direction flush \
            -textvariable  ::DipWatch::dipcolor($i) \
            -menu $f.c$i.menu -width 10
        menu $f.c$i.menu -tearoff no
        foreach c $colors {
            $f.c$i.menu add radiobutton -value $c \
                -variable ::DipWatch::dipcolor($i) -label $c \
                -command "::DipWatch::DrawDips $i"

        }
        entry $f.f$i -textvariable ::DipWatch::dipscale($i) -width 5 \
            -validatecommand "::DipWatch::EntryUpdate $i" \
            -validate focusout
        entry $f.r$i -textvariable ::DipWatch::dipradius($i) -width 5 \
            -validatecommand "::DipWatch::EntryUpdate $i" \
            -validate focusout
        label $f.v$i -textvariable ::DipWatch::dipvalue($i) -width 10 -relief raised 
        ButtonToggle $i
        pack $f.b$i -side left 
        pack $f.m$i -side left 
        pack $f.s$i -side left 
        pack $f.c$i -side left 
        pack $f.f$i -side left
        pack $f.r$i -side left
        pack $f.v$i -side left
        grid configure $f.b$i -row [expr $i + 1] -column 0 -sticky "snew"
        grid configure $f.m$i -row [expr $i + 1] -column 1 -sticky "snew"
        grid configure $f.s$i -row [expr $i + 1] -column 2 -sticky "snew"
        grid configure $f.c$i -row [expr $i + 1] -column 3 -sticky "snew"
        grid configure $f.f$i -row [expr $i + 1] -column 4 -sticky "snew"
        grid configure $f.r$i -row [expr $i + 1] -column 5 -sticky "snew"
        grid configure $f.v$i -row [expr $i + 1] -column 6 -sticky "snew"
        grid rowconfigure $f [expr $i + 1] -weight 0 
    }
    grid columnconfigure $f 0 -weight 0
    grid columnconfigure $f 1 -weight 1 -minsize 15
    grid columnconfigure $f 2 -weight 5 -minsize 15
    grid columnconfigure $f 3 -weight 1 -minsize 15
    grid columnconfigure $f 4 -weight 1 -minsize 10
    grid columnconfigure $f 5 -weight 1 -minsize 10 
    grid columnconfigure $f 6 -weight 1 -minsize 15 

    UpdateMolecule
    global vmd_molecule vmd_frame
    trace variable vmd_molecule w ::DipWatch::UpdateMolecule
    trace variable vmd_frame w    ::DipWatch::DrawDips
}

# callback for VMD menu entry
proc dipwatch_tk_cb {} {
    ::DipWatch::dipwatchgui
    return $::DipWatch::w
}

