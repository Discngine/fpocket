# hello emacs this is -*- tcl -*-
#
# GUI around 'measure gofr'.
#
# (c) 2006 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
########################################################################
#
# create package and namespace and default all namespace global variables.
package provide gofrgui 1.0

namespace eval ::GofrGUI:: {
    namespace export gofrgui

    variable w;                # handle to the base widget.
    variable version    "1.0"; # plugin version      

    variable molid        "0"; # molid of the molecule to grab
    variable moltxt        ""; # title the molecule to grab
    
    variable selstring1    ""; # selection string for first selection
    variable selstring2    ""; # selection string for second selection

    variable delta      "0.1"; # delta for histogram
    variable rmax      "10.0"; # max r in histogram

    variable usepbc       "1"; # apply PBC
    variable doupdate     "0"; # update selections during calculation

    variable first        "0"; # first frame
    variable last        "-1"; # last frame
    variable step         "1"; # frame step delta 

    variable cell_a     "0.0"; #
    variable cell_b     "0.0"; #
    variable cell_c     "0.0"; #
    variable cell_alpha "90.0"; #
    variable cell_beta  "90.0"; #
    variable cell_gamma "90.0"; #

    variable rlist         {}; # list of r values
    variable glist         {}; # list of normalized g(r) values   
    variable ilist         {}; # list of integrated g(r) values
    variable hlist         {}; # list of unnormalized histogram data
    variable frlist   "0 0 0"; # list of all, skipped, processed with alg1 frames, ...

    variable plotgofr     "1"; # plot the g(r) using multiplot
    variable plotint      "0"; # plot number integral

    variable dowrite      "0"; # write output to file.
    variable outfile "gofr.dat"; # name of output file

    variable cannotplot   "0"; # is multiplot available?
}


#################
# the heart of the matter. run 'measure gofr'.
proc ::GofrGUI::runmeasure {} {
    variable w

    variable molid
    variable selstring1
    variable selstring2
    variable delta
    variable rmax
    variable usepbc
    variable doupdate
    variable first
    variable last
    variable step

    variable rlist
    variable glist
    variable ilist
    variable hlist
    variable frlist

    variable cannotplot
    variable plotgofr
    variable plotint

    variable dowrite 
    variable outfile

    set errmsg {}
    set cannotplot [catch {package require multiplot}]

    set sel1 {}
    set sel2 {} 
    if {[catch {atomselect $molid "$selstring1"} sel1] \
         || [catch {atomselect $molid "$selstring2"} sel2] } then {
        tk_dialog .errmsg {g(r) Error} "There was an error creating the selections:\n$sel1\n$sel2" error 0 Dismiss
        return
    }

    if {[catch {measure gofr $sel1 $sel2 delta $delta rmax $rmax usepbc $usepbc \
                            selupdate $doupdate first $first last $last step $step} \
             errmsg ] } then {
        tk_dialog .errmsg {g(r) Error} "There was an error running 'measure gofr':\n\n$errmsg" error 0 Dismiss
        $sel1 delete
        $sel2 delete
        return
    } else {
        lassign $errmsg rlist glist ilist hlist frlist
        after 3000 {catch {destroy .succmsg}}
        tk_dialog .succmsg {g(r) Success} "g(r) calculation successful! [lindex $frlist 0] frames total, [lindex $frlist 2] frames processed, [lindex $frlist 1] frames skipped." info 0 OK
    }

    # display g(r)
    if {$plotgofr} {
        if {$cannotplot} then {
            tk_dialog .errmsg {g(r) Error} "Multiplot is not available. Enabling 'Save to File'." error 0 Dismiss
            set dowrite 1
        } else {
            set ph [multiplot -x $rlist -y $glist -title "g(r)" -lines -linewidth 3 -marker point -plot -hline {1 -width 1}]
        }
    }

    # display number integral
    if {$plotint} {
        if {$cannotplot} then {
            tk_dialog .errmsg {g(r) Error} "Multiplot is not available. Enabling 'Save to File'." error 0 Dismiss
            set dowrite 1
        } else {
            set ph [multiplot -x $rlist -y $ilist -title "Number integral over g(r)" -lines -linewidth 3 -marker point -plot -hline {5 -width 1} -hline {10 -width 1} -hline {20 -width 1}]
        }
    }

    # Save to File
    if {$dowrite} {
        set outfile [tk_getSaveFile -defaultextension .dat -initialfile $outfile \
                         -filetypes { { {Generic Data File} {.dat .data} } \
                          { {XmGrace Multi-Column Data File} {.nxy} } \
                          { {Generic Text File} {.txt} } \
                          { {All Files} {.*} } } \
                         -title {Save g(r) Data to File} -parent $w]
        set fp {}
        if {[string length $outfile]} {
            if {[catch {open $outfile w} fp]} then {
                tk_dialog .errmsg {g(r) Error} "There was an error opening the output file '$outfile':\n\n$fp" error 0 Dismiss
            } else {
                foreach r $rlist g $glist i $ilist {
                    puts $fp "$r $g $i"
                }
                close $fp
            }
        }
    }

    # clean up
    $sel1 delete
    $sel2 delete
}

#################
# set unit cell
proc ::GofrGUI::set_unitcell {} {
    variable molid
    variable unitcell_a
    variable unitcell_b
    variable unitcell_c
    variable unitcell_alpha
    variable unitcell_beta
    variable unitcell_gamma

    set n [molinfo $molid get numframes]

    for {set i 0} {$i < $n} {incr i} {
        molinfo $molid set frame $i
        molinfo $molid set a $unitcell_a
        molinfo $molid set b $unitcell_b
        molinfo $molid set c $unitcell_c
        molinfo $molid set alpha $unitcell_alpha
        molinfo $molid set beta $unitcell_beta
        molinfo $molid set gamma $unitcell_gamma
    }
}

#################
# set unit cell dialog
proc ::GofrGUI::unitcellgui {args} {
    variable clicked
    variable molid
    variable unitcell_a
    variable unitcell_b
    variable unitcell_c
    variable unitcell_alpha
    variable unitcell_beta
    variable unitcell_gamma

    set d .unitcellgui

    catch {destroy $d}
    toplevel $d -class Dialog
    wm title $d {Set Unit Cell}
    wm protocol $d WM_DELETE_WINDOW {set clicked -1}
    wm minsize  $d 200 200  

    # only make the dialog transient if the parent is viewable.
    if {[winfo viewable [winfo toplevel [winfo parent $d]]] } {
        wm transient $d [winfo toplevel [winfo parent $d]]
    }

    frame $d.bot
    frame $d.top
    $d.bot configure -relief raised -bd 1
    $d.top configure -relief raised -bd 1
    pack $d.bot -side bottom -fill both
    pack $d.top -side top -fill both -expand 1

    # retrieve current values for cell dimensions
    lassign [molinfo $molid get {a b c alpha beta gamma} ] \
         unitcell_a unitcell_b unitcell_c unitcell_alpha unitcell_beta unitcell_gamma

    # dialog contents:
    label $d.head -justify center -relief raised -text {Set unit cell parameters for all frames:}
    pack $d.head -in $d.top -side top -fill both -padx 6m -pady 6m
    grid $d.head -in $d.top -column 0 -row 0 -columnspan 2 -sticky snew 
    label $d.la  -justify left -text {Length a:}
    label $d.lb  -justify left -text {Length b:}
    label $d.lc  -justify left -text {Length c:}
    label $d.lal -justify left -text {Angle alpha:}
    label $d.lbe -justify left -text {Angle beta:}
    label $d.lga -justify left -text {Angle gamma:}
    set i 1
    grid columnconfigure $d.top 0 -weight 2
    foreach l "$d.la $d.lb $d.lc $d.lal $d.lbe $d.lga" {
        pack $l -in $d.top -side left -expand 1 -padx 3m -pady 3m
        grid $l -in $d.top -column 0 -row $i -sticky w 
        incr i
    }

    entry $d.ea  -justify left -textvariable ::GofrGUI::unitcell_a
    entry $d.eb  -justify left -textvariable ::GofrGUI::unitcell_b
    entry $d.ec  -justify left -textvariable ::GofrGUI::unitcell_c
    entry $d.eal -justify left -textvariable ::GofrGUI::unitcell_alpha
    entry $d.ebe -justify left -textvariable ::GofrGUI::unitcell_beta
    entry $d.ega -justify left -textvariable ::GofrGUI::unitcell_gamma
    set i 1
    grid columnconfigure $d.top 1 -weight 2
    foreach l "$d.ea $d.eb $d.ec $d.eal $d.ebe $d.ega" {
        pack $l -in $d.top -side left -expand 1 -padx 3m -pady 3m
        grid $l -in $d.top -column 1 -row $i -sticky w 
        incr i
    }
    
    # buttons
    button $d.ok -text {Set unit cell} -command {set clicked 1 ; ::GofrGUI::set_unitcell}
    grid $d.ok -in $d.bot -column 0 -row 0 -sticky ew -padx 10 -pady 4
    grid columnconfigure $d.bot 0
    button $d.cancel -text {Cancel} -command {set clicked 1}
    grid $d.cancel -in $d.bot -column 1 -row 0 -sticky ew -padx 10 -pady 4
    grid columnconfigure $d.bot 1

    bind $d <Destroy> {set clicked -1}
    set oldFocus [focus]
    set oldGrab [grab current $d]
    if {[string compare $oldGrab ""]} {
        set grabStatus [grab status $oldGrab]
    }
    grab $d
    focus $d

    # wait for user to click
    vwait clicked
    catch {focus $oldFocus}
    catch {
        bind $d <Destroy> {}
        destroy $d
    }
    if {[string compare $oldGrab ""]} {
      if {[string compare $grabStatus "global"]} {
            grab $oldGrab
      } else {
          grab -global $oldGrab
        }
    }
    return
}
#################
# build GUI.
proc ::GofrGUI::gofrgui {args} {
    variable w

    # main window frame
    set w .gofrgui
    catch {destroy $w}
    toplevel    $w
    wm title    $w "Radial Pair Distribution Function g(r)" 
    wm iconname $w "GofrGUI" 
    wm minsize  $w 520 200  

    # menubar
    frame $w.menubar -relief raised -bd 2 
    pack $w.menubar -side top -padx 1 -fill x
    menubutton $w.menubar.util -text Utilities -underline 0 -menu $w.menubar.util.menu
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    # Utilities menu.
    menu $w.menubar.util.menu -tearoff no
    $w.menubar.util.menu add command -label "Set unit cell dimensions" \
                           -command ::GofrGUI::unitcellgui
    # Help menu.
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
               -command {tk_messageBox -type ok -title "About g(r) GUI" \
                              -message "The g(r) GUI provides a convenient graphical interface to the 'measure gofr' command in VMD. g(r) refers to spherical atomic radial distribution functions, a special case of pair correlation functions, which provide insight into the averaged structure in dense materials.\n\nVersion $::GofrGUI::version\n(c) 2006 by Axel Kohlmeyer\n<akohlmey@cmm.chem.upenn.edu>"}
    $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/gofrgui"
    pack $w.menubar.util -side left
    pack $w.menubar.help -side right

    # frame for settings
    set in $w.in
    labelframe $in -bd 2 -relief ridge -text "Settings:" -padx 1m -pady 1m
    pack $in -side top -fill both


    # Molecule selector
    frame $in.molid
    label $in.molid.l -text "Use Molecule:" -anchor w
    menubutton $in.molid.m -relief raised -bd 2 -direction flush \
	-text "test text" -textvariable ::GofrGUI::moltxt \
	-menu $in.molid.m.menu
    menu $in.molid.m.menu -tearoff no
    pack $in.molid.l -side left
    pack $in.molid.m -side left
    pack $in.molid -side top
    grid config $in.molid.l  -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.molid.m  -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.molid 0 -weight 1 -minsize 10
    grid columnconfigure $in.molid 1 -weight 3 -minsize 10

    # Selections
    frame $in.sel
    label $in.sel.al -text "Selection 1:" -anchor e
    entry $in.sel.at -width 20 -textvariable ::GofrGUI::selstring1
    label $in.sel.bl -text "Selection 2:" -anchor e
    entry $in.sel.bt -width 20 -textvariable ::GofrGUI::selstring2
    pack $in.sel.al -side left
    pack $in.sel.at -side left
    pack $in.sel.bl -side left
    pack $in.sel.bt -side left
    pack $in.sel -side top
    grid config $in.sel.al -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel.at -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel.bl -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel.bt -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.sel 0 -weight 2
    grid columnconfigure $in.sel 1 -weight 2
    grid columnconfigure $in.sel 2 -weight 2
    grid columnconfigure $in.sel 3 -weight 2

    # Frame range
    frame $in.frame
    label $in.frame.t -text "Frames:" -anchor w
    label $in.frame.fl -text "First:" -anchor e
    entry $in.frame.ft -width 4 -textvariable ::GofrGUI::first
    label $in.frame.ll -text "Last:" -anchor e
    entry $in.frame.lt -width 4 -textvariable ::GofrGUI::last
    label $in.frame.sl -text "Step:" -anchor e
    entry $in.frame.st -width 4 -textvariable ::GofrGUI::step
    pack $in.frame.t -side left
    pack $in.frame.fl -side left
    pack $in.frame.ft -side left
    pack $in.frame.ll -side left
    pack $in.frame.lt -side left
    pack $in.frame.sl -side left
    pack $in.frame.st -side left
    pack $in.frame -side top
    grid config $in.frame.t -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.fl -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.ft -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.ll -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.lt -column 4 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.sl -column 5 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame.st -column 6 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.frame 0 -weight 1 -minsize 10
    grid columnconfigure $in.frame 1 -weight 3 -minsize 10
    grid columnconfigure $in.frame 2 -weight 2 -minsize 10
    grid columnconfigure $in.frame 3 -weight 3 -minsize 10
    grid columnconfigure $in.frame 4 -weight 2 -minsize 10
    grid columnconfigure $in.frame 5 -weight 3 -minsize 10
    grid columnconfigure $in.frame 6 -weight 2 -minsize 10

    # parameters
    frame $in.parm
    label $in.parm.l -text {Histogram Parameters: } -anchor w
    label $in.parm.deltal -text {delta r:} -anchor e
    entry $in.parm.deltat -width 5 -textvariable ::GofrGUI::delta
    label $in.parm.rmaxl -text {max. r:} -anchor e
    entry $in.parm.rmaxt -width  5 -textvariable ::GofrGUI::rmax
    pack $in.parm.l -side left
    pack $in.parm.deltal -side left
    pack $in.parm.deltat -side left
    pack $in.parm.rmaxl -side left
    pack $in.parm.rmaxt -side left
    pack $in.parm -side left
    grid config $in.parm.l      -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.deltal -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.deltat -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.rmaxl  -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.rmaxt  -column 4 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.parm 0 -weight 1 -minsize 10
    grid columnconfigure $in.parm 1 -weight 3 -minsize 10
    grid columnconfigure $in.parm 2 -weight 2 -minsize 10
    grid columnconfigure $in.parm 3 -weight 3 -minsize 10
    grid columnconfigure $in.parm 4 -weight 2 -minsize 10

    # options
    frame $in.opt
    checkbutton $in.opt.pbc -relief groove -text {Use PBC} -variable ::GofrGUI::usepbc
    checkbutton $in.opt.upd -relief groove -text {Update Selections} -variable ::GofrGUI::doupdate
    checkbutton $in.opt.plg -relief groove -text {Display g(r)} -variable ::GofrGUI::plotgofr
    checkbutton $in.opt.pli -relief groove -text {Display Int(g(r))} -variable ::GofrGUI::plotint
    checkbutton $in.opt.sav -relief groove -text {Save to File} -variable ::GofrGUI::dowrite
    pack $in.opt.pbc -side left -fill x
    pack $in.opt.upd -side left -fill x
    pack $in.opt.plg -side left -fill x
    pack $in.opt.pli -side left -fill x
    pack $in.opt.sav -side left -fill x
    pack $in.opt -side left -fill x
    grid columnconfigure $in.opt.pbc 0 -weight 2 -minsize 10
    grid columnconfigure $in.opt.upd 1 -weight 2 -minsize 10
    grid columnconfigure $in.opt.plg 2 -weight 2 -minsize 10
    grid columnconfigure $in.opt.pli 3 -weight 2 -minsize 10
    grid columnconfigure $in.opt.sav 4 -weight 2 -minsize 10
    grid config $in.opt  -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt  -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt  -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt  -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt  -column 4 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"

    # computation action buttons
    button $w.foot -text {Compute g(r)} -command [namespace code runmeasure]
    pack $w.foot -side bottom -fill x

    # manage layout for 
    grid config $in.molid  -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel    -column 0 -row 1 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame  -column 0 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm   -column 0 -row 3 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt    -column 0 -row 4 -columnspan 1 -rowspan 1 -sticky "snew"
    grid rowconfigure  $in 0 -weight 2 -minsize 20
    grid rowconfigure  $in 1 -weight 2 -minsize 20
    grid rowconfigure  $in 2 -weight 2 -minsize 20
    grid rowconfigure  $in 3 -weight 2 -minsize 20
    grid rowconfigure  $in 4 -weight 2 -minsize 20

    # layout main canvas
    grid config $w.menubar -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "new"
    grid config $w.in -column 0 -row 1 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $w.foot  -column 0 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $w 0 -weight 2 -minsize 250
    grid rowconfigure    $w 0 -weight 2 -minsize 20
    grid rowconfigure    $w 1 -weight 10 -minsize 150
    grid rowconfigure    $w 2 -weight 2 -minsize 20

    UpdateMolecule
    global vmd_molecule
    trace variable vmd_molecule w ::GofrGUI::UpdateMolecule
}

 
# callback for VMD menu entry
proc gofrgui_tk_cb {} {
  ::GofrGUI::gofrgui 
  return $::GofrGUI::w
}

# update molecule list
proc ::GofrGUI::UpdateMolecule {args} {
    variable w
    variable moltxt
    variable molid
    global vmd_molecule

    # Update the molecule browser
    set mollist [molinfo list]
    $w.foot configure -state disabled
    $w.in.molid.m configure -state disabled
    $w.in.molid.m.menu delete 0 end
    set moltxt "(none)"

    if { [llength $mollist] > 0 } {
        $w.foot configure -state normal
        $w.in.molid.m configure -state normal 
        foreach id $mollist {
            $w.in.molid.m.menu add radiobutton -value $id \
                -command {global vmd_molecule ; if {[info exists vmd_molecule($::GofrGUI::molid)]} {set ::GofrGUI::moltxt "$::GofrGUI::molid:[molinfo $::GofrGUI::molid get name]"} {set ::GofrGUI::moltxt "(none)" ; set molid -1} } \
                -label "$id [molinfo $id get name]" \
                -variable ::GofrGUI::molid
            if {$id == $molid} {
                if {[info exists vmd_molecule($molid)]} then {
                    set moltxt "$molid:[molinfo $molid get name]"  
                } else {
                    set moltxt "(none)"
                    set molid -1
                }
            }
        }
    }
}

############################################################
# Local Variables:
# mode: tcl
# time-stamp-format: "%u %02d.%02m.%y %02H:%02M:%02S %s"
# End:
############################################################


