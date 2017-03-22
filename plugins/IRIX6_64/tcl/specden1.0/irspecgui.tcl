# hello emacs this is -*- tcl -*-
#
# GUI around 'specden'.
#
# (c) 2006 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
########################################################################
#
# create package and namespace and default all namespace global variables.
package require specden
package provide irspecgui 1.0

namespace eval ::IRspecGUI:: {
    namespace export irspecgui

    variable w;                # handle to the base widget.
    variable version    "1.0"; # plugin version      

    variable molid        "0"; # molid of the molecule to grab
    variable moltxt        ""; # title the molecule to grab
    
    variable selstring  "all"; # selection string for selection
    variable doupdate     "0"; # update selection during calculation

    variable deltat   "0.001"; # time delta between frames
    variable tunit        "2"; # unit for time delta (0=a.u.,1=fs,2=ps) 
    variable tunittxt    "ps"; # unit for time delta (0=a.u.,1=fs,2=ps) 
    variable maxfreq "2000.0"; # max frequency

    variable temp     "300.0"; # temperature in Kelvin
    variable correct "harmonic" ; # correction method

    variable oversampl    "1"; # oversampling

    variable first        "0"; # first frame
    variable last        "-1"; # last frame
    variable step         "1"; # frame step delta 

    variable flist         {}; # list of frequencies
    variable slist         {}; # list of spectral densities

    variable doplot       "1"; # plot the spectrum using multiplot
    variable dowrite      "0"; # write output to file.
    variable outfile "spec.dat"; # name of output file

    variable cannotplot   "0"; # is multiplot available?
}


#####################
# copy charges from beta field
proc ::IRspecGUI::copybtocharge {} {
    variable molid
    variable selstring

    set sel {}
    if {[catch {atomselect $molid "$selstring"} sel] } then {
        tk_dialog .errmsg {IRspec Error} "There was an error creating the selection:\n$sel" error 0 Dismiss
        return
    }
    $sel set charge [$sel get beta]
    $sel delete
}

#####################
# guess charges via APBSrun (could it be using autopsf???)
proc ::IRspecGUI::guesscharge {} {
    variable molid
    variable selstring

    set errmsg {}
    set sel {}
    if {[catch {package require apbsrun 1.2} errmsg] } {
        tk_dialog .errmsg {IRspec Error} "Could not load the APBSrun package needed to guess charges:\n$errmsg" error 0 Dismiss
        return
    }
    if {[catch {atomselect $molid "$selstring"} sel] } then {
        tk_dialog .errmsg {IRspec Error} "There was an error creating the selection:\n$sel" error 0 Dismiss
        return
    }
    ::APBSRun::set_parameter_charges $sel 
    $sel delete
}

#####################
# read charges from file.
proc ::IRspecGUI::readcharge {} {
    variable w
    variable molid

    set fname [tk_getOpenFile -defaultextension .dat -initialfile "charges.dat" \
                         -filetypes { { {Generic Data File} {.dat .data} } \
                          { {Generic Text File} {.txt} } \
                          { {All Files} {.*} } } \
                         -title {Load atom name to charge mapping file} -parent $w]
    if {! [string length $fname] } return ; # user has canceled file selection.
    if { ![file exists $fname] || [catch {set fp [open $fname r]} errmsg] } {
        tk_dialog .errmsg {IRspec Error} "Could not open file $fname for reading:\n$errmsg" error 0 Dismiss
        return
    } else {
        # Load the charges
        while {-1 != [gets $fp line]} {
            if {![regexp {^\s*#} $line]} {
                set line [regexp -all -inline {\S+} $line]
                if {[llength $line] >= 2} {
                    set sel [atomselect $molid "name [lindex $line 0]"]
                    $sel set charge [lindex $line 1]
                    $sel delete
                }
            }
        }
        close $fp
    }
}

#################
# the heart of the matter. run 'measure dipole' and compute spectral densities.
proc ::IRspecGUI::runmeasure {} {
    variable w

    variable molid
    variable selstring
    variable doupdate

    variable deltat
    variable tunit
    variable maxfreq
    variable oversampl
    variable temp
    variable correct

    variable first
    variable last
    variable step

    variable flist
    variable slist

    variable cannotplot
    variable doplot
    variable dowrite 
    variable outfile

    set errmsg {}
    set cannotplot [catch {package require multiplot}]

    # we need a selection for 'measure dipole'...
    set sel {}
    if {[catch {atomselect $molid "$selstring"} sel] } then {
        tk_dialog .errmsg {IRspec Error} "There was an error creating the selection:\n$sel" error 0 Dismiss
        return
    }

    # we need some frames
    set nframes [molinfo $molid get numframes]
    set from $first
    set to $last
    if {$last == -1} {set to $nframes}
    if {($to < $first) || ($first < 0) || ($step < 0) || ($step > $nframes)} {
        tk_dialog .errmsg {IRspec Error} "Invalid frame range given: $first:$last:$step" error 0 Dismiss
        return
    }
    set diplist {}
    set flist {}
    set slist {}

    # Make sure that we have a dipole moment.
    set p_sum 0.0
    set n_sum 0.0
    foreach charge [$sel get charge] {
        if {$charge < 0} {
            set n_sum [expr {$n_sum - $charge}]
        } else {
            set p_sum [expr {$p_sum + $charge}]
        }
    }
    if { ($p_sum < 0.1) || ($n_sum < 0.1) } {
        tk_dialog .errmsg {IRspec Error} "Insufficent charges to form a dipole. Please check your selection, load a proper topology file or assign charges manually." error 0 Dismiss
        $sel delete
        return
    }
    
    # detect if we have enough data available.
    set tval [expr $step * $deltat * [lindex "1.0 41.3413741313826 41341.3741313825" $tunit]]
    set ndat [expr {($to - $from) / $step}]
    set nn [expr {$ndat*$maxfreq/219474.0*$tval/(2.0*3.14159265358979)}]
    if { [expr {$nn + 2}] > $ndat } {
        tk_dialog .errmsg {IRspec Error} "Not enough data for frequency range. Please lower the maximum frequency or load more frames to the trajectory." error 0 Dismiss
        $sel delete
        return
    }

    # collect time series data for trajectory.
    for {set i $from} {$i<$to} {set i [expr {$i + $step}]} {
        $sel frame $i
        if {$doupdate} {
             catch {$sel update}
        }
        lappend diplist [measure dipole $sel]
    }
    if {[catch {specden $diplist $tval $maxfreq $correct $temp $oversampl} errmsg ] } then {
        tk_dialog .errmsg {IRspec Error} "There was an error running 'specden':\n\n$errmsg" error 0 Dismiss
        $sel delete
        return
    } else {
        lassign $errmsg flist slist
    }

    # detect when specden produces crap. memory allocation bug in specden?
    set nans [lsearch -all $slist "nan"]
    if {[llength $nans] > 0 } {
        tk_dialog .errmsg {IRspec Error} "There was an internal error in 'specden':\n Please try changing some parameters slightly and recalculate" error 0 Dismiss
        $sel delete
        return
    }

    # display spectrum
    if {$doplot} {
        if {$cannotplot} then {
            tk_dialog .errmsg {IRspec Error} "Multiplot is not available. Enabling 'Save to File'." error 0 Dismiss
            set dowrite 1
        } else {
            set ph [multiplot -x $flist -y $slist -title "Spectral Densities" -lines -linewidth 3 -marker point -plot ]
        }
    }

    # Save to File
    if {$dowrite} {
        set outfile [tk_getSaveFile -defaultextension dat -initialfile $outfile \
                         -filetypes { { {Generic Data File} {.dat .data} } \
                          { {XmGrace Multi-Column Data File} {.nxy} } \
                          { {Generic Text File} {.txt} } \
                          { {All Files} {.*} } } \
                         -title {Save Spectral Density to File} -parent $w]
        set fp {}
        if {[string length $outfile]} {
            if {[catch {open $outfile w} fp]} then {
                tk_dialog .errmsg {IRspec Error} "There was an error opening the output file '$outfile':\n\n$fp" error 0 Dismiss
            } else {
                foreach f $flist s $slist {
                    puts $fp "$f $s"
                }
                close $fp
            }
        }
    }

    # clean up
    $sel delete
}

#################
# build GUI.
proc ::IRspecGUI::irspecgui {args} {
    variable w

    # main window frame
    set w .irspecgui
    catch {destroy $w}
    toplevel    $w
    wm title    $w "IR Spectra Calculation" 
    wm iconname $w "IRspecGUI" 
    wm minsize  $w 400 200  

    # menubar
    frame $w.menubar -relief raised -bd 2 
    pack $w.menubar -side top -padx 1 -fill x
    menubutton $w.menubar.util -text Utilities -underline 0 -menu $w.menubar.util.menu
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
    # Utilities menu.
    menu $w.menubar.util.menu -tearoff no
    $w.menubar.util.menu add command -label "Guess atomic charges from CHARMM parameters." \
                           -command ::IRspecGUI::guesscharge
    $w.menubar.util.menu add command -label "Load name<->charge map from file." \
                           -command ::IRspecGUI::readcharge
    $w.menubar.util.menu add command -label "Copy charges from beta field." \
                           -command ::IRspecGUI::copybtocharge

    # Help menu.
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
               -command {tk_messageBox -type ok -title "About IRspec GUI" \
                              -message "The IRspec GUI provides a graphical interface to compute spectral densities from dipole time series data using the 'measure dipole' command in VMD. Several corrections for intensities can be applied.\n\nVersion $::IRspecGUI::version\n(c) 2006 by Axel Kohlmeyer\n<akohlmey@cmm.chem.upenn.edu>"}
    $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/irspecgui"
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
	-textvariable ::IRspecGUI::moltxt \
	-menu $in.molid.m.menu
    menu $in.molid.m.menu -tearoff no
    pack $in.molid.l -side left
    pack $in.molid.m -side left
    pack $in.molid -side top
    grid config $in.molid.l  -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.molid.m  -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.molid 0 -weight 1 -minsize 10
    grid columnconfigure $in.molid 1 -weight 3 -minsize 10

    # Selection
    frame $in.sel
    label $in.sel.al -text "Selection:" -anchor w
    entry $in.sel.at -width 20 -textvariable ::IRspecGUI::selstring
    checkbutton $in.sel.upd -relief groove -text {Update Selection} -variable ::IRspecGUI::doupdate
    pack $in.sel.al -side left
    pack $in.sel.at -side left
    pack $in.sel.upd -side left
    pack $in.sel -side top
    grid config $in.sel.al -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel.at -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel.upd -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.sel 0 -weight 1
    grid columnconfigure $in.sel 1 -weight 3
    grid columnconfigure $in.sel 2 -weight 4

    # Frame range
    frame $in.frame
    label $in.frame.t -text "Frames:" -anchor w
    label $in.frame.fl -text "First:" -anchor e
    entry $in.frame.ft -width 4 -textvariable ::IRspecGUI::first
    label $in.frame.ll -text "Last:" -anchor e
    entry $in.frame.lt -width 4 -textvariable ::IRspecGUI::last
    label $in.frame.sl -text "Step:" -anchor e
    entry $in.frame.st -width 4 -textvariable ::IRspecGUI::step
    pack $in.frame.t -side left
    pack $in.frame.fl -side left
    pack $in.frame.ft -side left
    pack $in.frame.ll -side left
    pack $in.frame.lt -side left
    pack $in.frame.sl -side left
    pack $in.frame.st -side left
    pack $in.frame -side top -fill x
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
    label $in.parm.l -text {Time between frames: } -anchor w
    entry $in.parm.deltat -width 5 -textvariable ::IRspecGUI::deltat
    menubutton $in.parm.unit -relief raised -bd 2 -direction flush \
	-textvariable ::IRspecGUI::tunittxt -menu $in.parm.unit.menu
    menu $in.parm.unit.menu -tearoff no
    $in.parm.unit.menu add radiobutton -value 0 \
                -command {set ::IRspecGUI::tunittxt "a.u."} \
                -label "a.u. (0.0242 fs)" \
                -variable ::IRspecGUI::tunit
    $in.parm.unit.menu add radiobutton -value 1 \
                -command {set ::IRspecGUI::tunittxt "fs"} \
                -label "fs" \
                -variable ::IRspecGUI::tunit
    $in.parm.unit.menu add radiobutton -value 2 \
                -command {set ::IRspecGUI::tunittxt "ps"} \
                -label "ps" \
                -variable ::IRspecGUI::tunit
    label $in.parm.mfl -text {   max Freq (cm^-1):} 
    entry $in.parm.maxf -width 8 -textvariable ::IRspecGUI::maxfreq
    pack $in.parm.l -side left -fill x
    pack $in.parm.deltat -side left -fill x
    pack $in.parm.unit -side left -fill x
    pack $in.parm.mfl -side left -fill x
    pack $in.parm.maxf -side left -fill x
    pack $in.parm -side left -fill x
    grid config $in.parm.l      -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.deltat -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.unit   -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.mfl    -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm.maxf   -column 4 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.parm 0 -weight 1 -minsize 10
    grid columnconfigure $in.parm 1 -weight 3 -minsize 10
    grid columnconfigure $in.parm 2 -weight 1 -minsize 10
    grid columnconfigure $in.parm 3 -weight 5 -minsize 10
    grid columnconfigure $in.parm 4 -weight 2 -minsize 10

    # Correction
    frame $in.corr
    label $in.corr.al -text "Temperature in K:" -anchor w
    entry $in.corr.at -width 20 -textvariable ::IRspecGUI::temp
    label $in.corr.ml -text "   Correction:" -anchor w
    menubutton $in.corr.meth -relief raised -bd 2 -direction flush \
	-textvariable ::IRspecGUI::correct -menu $in.corr.meth.menu
    menu $in.corr.meth.menu -tearoff no
    foreach m "harmonic fourier classic kubo schofield" {
        $in.corr.meth.menu add radiobutton -value $m \
                -variable ::IRspecGUI::correct -label $m
    }
    pack $in.corr.al -side left
    pack $in.corr.at -side left
    pack $in.corr.ml -side left
    pack $in.corr.meth -side left
    pack $in.corr -side top
    grid config $in.corr.al -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.corr.at -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.corr.ml -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.corr.meth -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.corr 0 -weight 1
    grid columnconfigure $in.corr 1 -weight 2
    grid columnconfigure $in.corr 2 -weight 1
    grid columnconfigure $in.corr 3 -weight 2 -minsize 150

    # Frame range
    # options
    frame $in.opt
    label $in.opt.ovl -text {Oversampling:} -anchor w
    entry $in.opt.ovr -width 8 -textvariable ::IRspecGUI::oversampl
    checkbutton $in.opt.plt -relief groove -text {Display Spectrum} -variable ::IRspecGUI::doplot
    checkbutton $in.opt.sav -relief groove -text {Save to File} -variable ::IRspecGUI::dowrite
    pack $in.opt.ovl -side left
    pack $in.opt.ovr -side left
    pack $in.opt.plt -side left
    pack $in.opt.sav -side left
    pack $in.opt -side top
    grid config $in.opt.ovl -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt.ovr -column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt.plt -column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt.sav -column 3 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid columnconfigure $in.opt 0 -weight 1 -minsize 10
    grid columnconfigure $in.opt 1 -weight 2 -minsize 10
    grid columnconfigure $in.opt 2 -weight 2 -minsize 10
    grid columnconfigure $in.opt 3 -weight 2 -minsize 10

    # computation action buttons
    button $w.foot -text {Compute Spectrum} -command [namespace code runmeasure]
    pack $w.foot -side bottom -fill x

    # manage layout for 
    grid config $in.molid  -column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.sel    -column 0 -row 1 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.frame  -column 0 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.parm   -column 0 -row 3 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.corr   -column 0 -row 4 -columnspan 1 -rowspan 1 -sticky "snew"
    grid config $in.opt    -column 0 -row 5 -columnspan 1 -rowspan 1 -sticky "snew"
    grid rowconfigure  $in 0 -weight 2 -minsize 20
    grid rowconfigure  $in 1 -weight 2 -minsize 20
    grid rowconfigure  $in 2 -weight 2 -minsize 20
    grid rowconfigure  $in 3 -weight 2 -minsize 20
    grid rowconfigure  $in 4 -weight 2 -minsize 20
    grid rowconfigure  $in 5 -weight 2 -minsize 20

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
    trace variable vmd_molecule w ::IRspecGUI::UpdateMolecule
}

 
# callback for VMD menu entry
proc irspecgui_tk_cb {} {
  ::IRspecGUI::irspecgui 
  return $::IRspecGUI::w
}

# update molecule list
proc ::IRspecGUI::UpdateMolecule {args} {
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
                -command {global vmd_molecule ; if {[info exists vmd_molecule($::IRspecGUI::molid)]} {set ::IRspecGUI::moltxt "$::IRspecGUI::molid:[molinfo $::IRspecGUI::molid get name]"} {set ::IRspecGUI::moltxt "(none)" ; set molid -1} } \
                -label "$id [molinfo $id get name]" \
                -variable ::IRspecGUI::molid
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

