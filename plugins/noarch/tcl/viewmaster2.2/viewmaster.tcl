# ViewMaster version 2.2
# Copyright (C) 2004 Justin Gullingsrud <jgulling@mccammon.ucsd.edu>
#
# $Id: viewmaster.tcl,v 1.7 2007/08/27 21:49:04 johns Exp $
#

# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/2.0/ or send a letter to
# Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305,
# USA.

# Installation instructions: Put this file and pkgIndex.tcl in 
# /your/choice/of/path, and add /your/choice/of/path to the auto_path
# Tcl variable.  You can do this from within your .vmdrc file with
# "lappend auto_path /your/choice/of/path".  Once this is done, 
# "package require ViewMaster" will start it up.  

#
# TODO:
# - fix viewmaster so it doesn't bomb if the user starts from a 
#   non-existent directory (call to pwd returns an unhandled error when
#   viewmaster sets up its session filename)
#

package provide ViewMaster 2.2

namespace eval ViewMaster {
    global env
    variable w
    variable note_entry
    variable tmpdir
    variable imageid 0

    variable sessionfile [file join [pwd] viewmaster-session.vmd]
    variable autosave 1
    variable save_after_id {}

    # keep track of what order the views are in
    variable viewlist [list]  

    # The master array of view state information.  Each key is of the
    # form "id,field", where id is the viewid and field is something like
    # frame, reps, mols, etc.  For each key, there is an associated list of
    # values.  The list must always contain the same number of elements as
    # the number of molecules loaded.  update_molecules is responsible for
    # ensuring that this remains the case even when molecules are created
    # and deleted. 
    variable states
    variable current_view -1

    if { [info exists env(TMPDIR)] } {
        set tmpdir $env(TMPDIR)
    } else {
        set tmpdir /tmp
    }
    variable oldlist [list]
}


# Create the GUI
proc ViewMaster::init {} {
    variable w
    variable note_entry

    if { [winfo exists .viewmaster] } {
        wm deiconify $w
        return
    }
    set w [toplevel .viewmaster -width 50 -height 100]
    wm title $w "VMD ViewMaster"
    wm resizable $w 0 0

    #
    # menubar
    #
    frame $w.menubar -relief raised -bd 2
    menubutton $w.menubar.file -text File -underline 0 -menu $w.menubar.file.menu -width 4
    menu $w.menubar.file.menu -tearoff no
    $w.menubar.file.menu add command -label "Load Views..." -command [namespace current]::load_state
    $w.menubar.file.menu add command -label "Save As..." -command [namespace current]::save_state_dialog
    $w.menubar.file.menu add command -label "Set Session File..." -command [namespace current]::session_file_dialog
    pack $w.menubar.file -side left -padx 1

    menubutton $w.menubar.settings -text Settings -underline 0 -menu $w.menubar.settings.menu -width 8
    menu $w.menubar.settings.menu -tearoff no
    $w.menubar.settings.menu add checkbutton -label Autosave -variable [namespace current]::autosave
    pack $w.menubar.settings -side left -padx 1
    menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu -width 4
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/viewmaster"
    $w.menubar.help.menu add command -label "About..." -command [namespace current]::help_about
    pack $w.menubar.help -side right
    pack $w.menubar -padx 1 -fill x


    #
    # top row of buttons
    # 
    frame $w.top
    button $w.top.new -text "Create New" -command [namespace current]::do_save
    pack $w.top.new -side left -fill x
    pack $w.top

    labelframe $w.top2 -text "Selected View:" -fg black
    button $w.top2.save -text "Replace" -width 8 -command [namespace code {do_save $current_view}] -state disabled
    button $w.top2.dup -text "Duplicate" -width 8 -command [namespace code {do_duplicate $current_view}] -state disabled
    button $w.top2.del -text "Delete" -width 8 -command [namespace code {do_delete $current_view}] -state disabled
    pack $w.top2.save $w.top2.dup $w.top2.del -side left
    pack $w.top2

    # text entry - write a note for each view
    frame $w.top3
    set note_entry [entry $w.top3.note -relief sunken -selectbackground yellow -bg white -validate key -vcmd [namespace current]::noteentry_save]
    trace variable [namespace current]::current_view w [namespace current]::update_noteentry
    pack $note_entry -fill x -expand yes
    pack $w.top3 -expand yes -fill x

    frame $w.views
    pack $w.views

    global vmd_initialize_structure
    trace variable vmd_initialize_structure w [namespace current]::update_molecules
    update_molecules
}

# This gets called whenever molecules are created or deleted.  If 
# molecules have been deleted, corresponding entries from each 
# key must be deleted as well.  If molecules have been added, default
# entries must be created for each molecule.  The exception is thumb and
# notes, for which there exists just one element for each view.
proc ViewMaster::update_molecules { args } {
    variable oldlist
    variable states
    variable viewlist

    set newlist [molinfo list]
    if { [llength $oldlist] > [llength $newlist] } {
        # molecules have been deleted
        set ind 0
        set wentaway [list]
        foreach o $oldlist {
            if { [lsearch $newlist $o] < 0 } {
                lappend wentaway $ind
            }
            incr ind
        }
        foreach key [array names states] {
            if {![string match *,thumb $key] || ![string match *,note $key]} {
                set states($key) [mask_list $states($key) $wentaway]
            }
        }
    } elseif { [llength $oldlist] < [llength $newlist] } {
        # new molecules!  We assume that the new molid's are higher than
        # any existing molid that we've been keep track of; thus the new
        # state data can be appended to the end of each key.
        set oldnum [llength $oldlist]
        set newmols [lrange [save_molecules] $oldnum end]
        set newreps [lrange [save_reps] $oldnum end]
        set newframes [lrange [save_frames] $oldnum end]
        foreach n $viewlist {
            set states($n,mols) [concat $states($n,mols) $newmols]
            set states($n,reps) [concat $states($n,reps) $newreps]
            set states($n,frames) [concat $states($n,frames) $newframes]
        }
    }
    set oldlist $newlist
    return
}
    
proc ViewMaster::update_buttons {} {
    variable states
    variable w
    if [llength [array names states]] {
        set state normal
    } else {
        set state disabled
    }
    foreach b [list $w.top2.save $w.top2.dup $w.top2.del] {
        $b configure -state $state 
    }
}

proc ViewMaster::update_noteentry { args } {
    variable current_view
    variable states
    variable note_entry
    if ![info exists states($current_view,note)] {
        set notetext ""
    }
    $note_entry configure -textvariable [namespace current]::states($current_view,note)
    $note_entry selection clear
    $note_entry icursor end
}

proc ViewMaster::noteentry_save { args } {
    variable save_after_id
    variable autosave
    # the note entry has been edited.  We want to save state without waiting
    # for a Replace or other event, but we can't save after every keystroke
    # because that would incur excessive overhead.  Instead, we arrange for
    # state to be saved after one second.

    if $autosave {
        # first, cancel any pending save
        after cancel $save_after_id
        set save_after_id [after 1000 [namespace current]::save_session]
    }
    return 1
}


# save data for each molecule as a { key value } list.
# views -> view matrices
proc ViewMaster::save_molecules {} {
    set result [list]
    foreach mol [molinfo list] {
        set moldata [list]
        lappend moldata [list views [molinfo $mol get {rotate_matrix center_matrix scale_matrix global_matrix}]]
        lappend moldata [list displayed [molinfo $mol get displayed]]
        lappend moldata [list fixed [molinfo $mol get fixed]]
        lappend moldata [list active [molinfo $mol get active]]
        lappend result $moldata
    }
    return $result
}

proc ViewMaster::restore_molecules { id } {
    variable states 
    foreach molid [molinfo list] moldata $states($id,mols) {
        foreach elem $moldata {
            foreach { key val } $elem { break }
            switch $key {
                views { molinfo $molid set {rotate_matrix center_matrix scale_matrix global_matrix} $val }
                displayed { if $val { mol on $molid } else { mol off $molid } }
                fixed { if $val { mol fix $molid } else { mol free $molid }}
                active { if $val { mol active $molid } else { mol inactive $molid }}
            }
        }
    }
}

# save the data for each rep as a { key value } list, so that we maintain
# backwards compatability, and so that older versions of the program can
# continue to use files saved by newer versions.  Cool, eh?
proc ViewMaster::save_reps {} {
    set repdata [list]
    foreach mol [molinfo list] {
        set moldata [list]
        for {set i 0} {$i < [molinfo $mol get numreps]} {incr i} {
            set rep [list]
            foreach {r s c m} [molinfo $mol get "{rep $i} {selection $i} {color $i} {material $i}"] { break }
            lappend rep [list rep $r]
            lappend rep [list selection $s]
            lappend rep [list color $c]
            lappend rep [list material $m]
            lappend rep [list showperiodic [mol showperiodic $mol $i]]
            lappend rep [list numperiodic  [mol numperiodic $mol $i]]
            lappend rep [list showrep      [mol showrep $mol $i]]
            lappend rep [list selupdate    [mol selupdate $i $mol]]
            lappend rep [list colupdate    [mol colupdate $i $mol]]
            lappend rep [list scaleminmax  [mol scaleminmax $mol $i]]
            lappend rep [list smoothrep    [mol smoothrep $mol $i]]
            lappend rep [list drawframes   [mol drawframes $mol $i]]
            lappend moldata $rep
        } 
        lappend repdata $moldata
    }
    return $repdata
  }
  
proc ViewMaster::restore_reps { id } {
    variable states
    # make sure the current default rep and color is something 
    # innocuous so we don't trigger unncessary calculations when
    # we add new ones.  Unfortunately there's no way to get the
    # current default; we can only set it.
    mol rep Lines
    mol color Name
    foreach mol [molinfo list] reps $states($id,reps) {
        set nreps [llength $reps]
        set n [molinfo $mol get numreps]
        # Delete reps starting from the end of the list; this lets us
        # minimize state changes.
        for { set i $nreps } { $i < $n } { incr i } {
            mol delrep $i $mol
        }
        while { $n < $nreps } {
            mol addrep $mol
            incr n
        }
        set n 0
        foreach rep $reps {
            # get current rep state so we don't make unnecessary expensive  
            # state changes.
            foreach {r s c m} [molinfo $mol get "{rep $n} {selection $n} {color $n} {material $n}"] { break }
            foreach elem $rep { 
                foreach { key val } $elem { break }
                switch $key {
                    rep       { 
                        if ![string equal $r $val] { 
                            mol modstyle $n $mol $val 
                        }
                    }
                    selection { 
                        if ![string equal $s $val] {
                            mol modselect $n $mol $val 
                        }
                    }
                    color     { 
                        if ![string equal $c $val] {
                            mol modcolor $n $mol $val 
                        }
                    }
                    material  { 
                        if ![string equal $m $val] {
                            mol modmaterial $n $mol $val 
                        }
                    }
                    showperiodic { mol showperiodic $mol $n $val }
                    numperiodic  { mol numperiodic $mol $n $val }
                    showrep      { mol showrep $mol $n $val }
                    selupdate    { mol selupdate $n $mol $val }
                    colupdate    { mol colupdate $n $mol $val }
                    scaleminmax  { mol scaleminmax $mol $n [lindex $val 0] [lindex $val 1] }
                    smoothrep    { mol smoothrep $mol $n $val }
                    drawframes   { mol drawframes $mol $n $val }
                    default {
                        puts "Warning, ignoring rep data of type '$key'"
                    }
                }
            }
            incr n
        }
    }
}

proc ViewMaster::save_frames {} {
    foreach mol [molinfo list] {
        set f [molinfo $mol get frame]
        # when the molecule is first created, there are no frames, and
        # get frame returns -1, which is an invalid value.  Check for this
        # and use zero instead.
        if { $f < 0 } { set f 0 }
        lappend frames $f
    }
    return $frames
}

proc ViewMaster::save_graphics {} {
    set result [list]
    foreach mol [molinfo list] {
        set grdata [list]
        foreach id [graphics $mol list] {
            lappend grdata [graphics $mol info $id]
        }
        lappend result $grdata
    }
    return $result
}

proc ViewMaster::restore_graphics { id } {
    variable states
    foreach mol [molinfo list] grdata $states($id,graphics) {
        graphics $mol delete all
        foreach info $grdata {
            eval graphics $mol $info
        }
    }
}

# color info is saved as 
#  category1 elem1 color1 category elem2 color2 ...
proc ViewMaster::save_colors {} {
    set result [list]
    foreach cat [colorinfo categories] {
        foreach elem [colorinfo category $cat] {
            lappend result $cat $elem [colorinfo category $cat $elem]
        }
    }
    return $result
}

proc ViewMaster::save_colordefs {} {
    set result [list]
    foreach color [colorinfo colors] {
        lappend result $color [colorinfo rgb $color]
    }
    return $result
}

proc ViewMaster::save_colorscale {} {
    set result [list]
    foreach key [list method midpoint min max] {
        lappend result $key [colorinfo scale $key]
    }
    return $result
}

proc ViewMaster::restore_colors { id } {
    variable states
    foreach {cat elem color} $states($id,colors) {
        catch {color $cat $elem $color}
    }
}

proc ViewMaster::restore_colordefs { id } {
    variable states
    foreach {name val} $states($id,colordefs) {
        foreach {r g b} $val { break }
        color change rgb $name $r $g $b
    }
}

proc ViewMaster::restore_colorscale { id } {
    variable states
    foreach {name val} $states($id,colorscale) {
        color scale $name $val
    }
}

proc ViewMaster::save_screenshot {} {
    variable tmpdir
    # Use the new tkrender command if available; otherwise render to file
    if [string length [info commands tkrender]] {
        set tmp [image create photo]
        tkrender $tmp
    } else {
        set imgfile [file join $tmpdir viewmaster.[pid].ppm]
        render snapshot $imgfile
        set tmp [image create photo -file $imgfile]
    }

    # shrink/expand to 50x50
    set img [resize $tmp 50 50]
    image delete $tmp
    return $img
}

proc ViewMaster::restore_frames { id } {
    variable states
    # Find the top molecule and call "animate goto" first.  Then go
    # through the other molecules and set their frame manually, through
    # molinfo.  We do it this way because otherwise DrawMolecule()
    # doesn't realize that its frame changed, and the GUI's don't get updated
    # properly.
    set topframe -1
    foreach molid [molinfo list] frame $states($id,frames) {
        if { $molid == [molinfo top] } {
            set topframe $frame
            break
        }
    }
    if { $topframe >= 0 } { 
        animate goto $topframe
    }
    set top [molinfo top]
    foreach molid [molinfo list] frame $states($id,frames) {
        if { $molid != $top } {
            molinfo $molid set frame $frame
        }
    }
}

proc ViewMaster::do_duplicate { id } {
    variable imageid
    variable states
    variable viewlist
    variable autosave

    # copy all state data, but make an actual copy of the thumbnail
    # image since the original copy may be deleted.
    foreach key [array names states $id,*] {
        set field [lindex [split $key ,] 1]
        if [string equal $field thumb] {
            set oldimg $states($key)
            set img [image create photo]
            $img copy $oldimg
            set states($imageid,$field) $img
        } else {
            set states($imageid,$field) $states($key)
        }
    }
    lappend viewlist $imageid
    add_widgets $imageid $states($imageid,thumb)
    incr imageid
    if $autosave save_session
}

proc ViewMaster::do_delete { id } {
    variable w
    variable states
    variable current_view
    variable viewlist
    variable autosave

    # figure out what to use for the new view after we delete this one
    set ind [lsearch $viewlist $id]
    incr ind
    set newview -1
    if { $ind < [llength $viewlist] } {
        set newview [lindex $viewlist $ind]
    } else {
        incr ind -2
        if { $ind >= 0 } {
            set newview [lindex $viewlist $ind]
        }
    }
    # otherwise there must not be any states

    # clean up data associated with state: delete gui entry and image handle,
    # and clean out entries in states table.

    destroy $w.views.$id
    image delete $states($id,thumb)
    foreach key [array names states $id,*] {
        unset states($key)
    }

    # remove entry in viewlist
    set viewlist [mask_list $viewlist [lsearch $viewlist $id]]

    # re-grid all the remaining views
    set row 0
    set col 0
    foreach v $viewlist {
        grid configure $w.views.$v -row $row -column $col
        incr col
        if { $col == 3 } { 
            set col 0
            incr row
        }
    }
    set current_view $newview
    update_buttons
    if $autosave save_session
    return
}
   


proc ViewMaster::do_save { args } {
    variable tmpdir
    variable imageid
    variable w
    variable states
    variable current_view
    variable viewlist
    variable autosave

    # If no molecules are loaded, there's nothing for us to do.
    if ![molinfo num] return

    # If an imageid is given, use that, otherwise generate a new unique id.
    if [llength $args] {
        set id $args
    } else {
        set id $imageid
        incr imageid
    }

    # If it's a new id, add it to viewlist
    if { [lsearch $viewlist $id] < 0 } { lappend viewlist $id }


    # save thumbnail, and delete old one if it exists
    if [info exists states($id,thumb)] {
        catch {image delete $states($id,thumb)}
    }
    set states($id,thumb) [save_screenshot]

    # save viewpoints
    set states($id,mols) [save_molecules]

    # save reps
    set states($id,reps) [save_reps]

    # save frame
    set states($id,frames) [save_frames]

    # save colors
    set states($id,colors) [save_colors]

    # save color definitions
    set states($id,colordefs) [save_colordefs]

    # save color scale definitions
    set states($id,colorscale) [save_colorscale]

    # save user-defined graphics
    set states($id,graphics) [save_graphics]

    # add the widget controls
    add_widgets $id $states($id,thumb)

    set current_view $id
    # a view exists now, so activate the Replace button
    update_buttons

    if $autosave save_session
}

proc ViewMaster::add_widgets { id img } {
    variable w
    variable viewlist

    # For each new view, create:
    #   1. A radio button to select the view for various operations defined
    #      below, such as delete, move up/down, replicate, etc.
    #   2. A button with the scene as its image.  Pressing the button restores
    #      the view and all the reps.

    if { [lsearch [info commands] $w.views.$id] < 0 } {
        # new view; create all new controls
        set fr [frame $w.views.$id]
        set rd [radiobutton $fr.rd -variable [namespace current]::current_view -value $id -command [list [namespace current]::do_restore $id]] 
    
        set btn [button $fr.btn -image $img -command [list [namespace current]::do_restore $id]]

        pack $rd $btn -side left
        #pack $fr -padx 1 -fill x -side top
        set n [llength $viewlist]
        set row [expr {int($n-1)/3}]
        set col [expr {$n-3*$row-1 }]
        grid $fr -column $col -row $row 
    } else {
        # just update the button image
        $w.views.${id}.btn configure -image $img
    }
}
    
proc ViewMaster::do_restore { id } {
    variable current_view
    restore_molecules $id 
    restore_reps $id
    restore_frames $id
    restore_colors $id
    restore_colordefs $id
    restore_colorscale $id
    restore_graphics $id
    set current_view $id
    return
}

proc ViewMaster::save_state_dialog { } {
    set fname [tk_getSaveFile -defaultextension tcl -title "ViewMaster: Save Views"]
    if [string length $fname] { 
        save_state $fname
    }
}

proc ViewMaster::session_file_dialog { } {
    variable sessionfile
    set fname [tk_getSaveFile -defaultextension tcl -title "ViewMaster: Set Session File:" -initialdir [file dirname $sessionfile] -initialfile [lindex [file split $sessionfile] end]]
    if [string length $fname] { 
        set sessionfile $fname
        save_state $fname 
    }
}

proc ViewMaster::save_session { } {
    variable sessionfile
    save_state $sessionfile
}

proc ViewMaster::save_state { fname } {
    variable states
    variable imageid
    variable oldlist
    variable viewlist

    set fd [open $fname w]
    puts $fd "# ViewMaster save state"
    puts $fd "package require ViewMaster [package present ViewMaster]"
    puts $fd "menu viewmaster on"
    puts $fd "proc __view__doit {} {"
    
    # Write instructions to restore the currently loaded molecules
    set cwd [pwd]
    foreach id [molinfo list] {
        set types [lindex [molinfo $id get filetype] 0]
        set files [lindex [molinfo $id get filename] 0]
        puts $fd [list ViewMaster::load_molecule $cwd $types $files]
    }

    # Recreate the current materials
    foreach mat [material list] {
        lappend matprops $mat [material settings $mat]
    }
    puts $fd [list ViewMaster::load_materials $matprops]

    # Recreate the saved views.  Strip off the view id since this won't
    # necessarily be valid when we reload.
    foreach id [lsort -integer $viewlist] {
        # gather all data from this state
        set keys [list]
        set vals [list]
        foreach key [array names states $id,*] {
            if [string match *,thumb $key] { continue }
            lappend keys [lindex [split $key ,] 1]
            lappend vals $states($key)
        }
        puts $fd [list ViewMaster::load_view $keys $vals]
    }
    puts $fd "}"
    puts $fd "__view__doit"
    puts $fd "rename __view__doit {}"
    close $fd
}

# This is just a wrapper around "source", which restores the old views if 
# an error is encountered while sourcing the file.
proc ViewMaster::load_state { } {
    variable states
    set fname [tk_getOpenFile -defaultextension tcl -title "ViewMaster: Load Views"]
    if ![string length $fname] { return }
    foreach key [array names states] {
        set tmp($key) $states($key)
    }
    if [catch {source $fname} msg] {
        catch {unset states}
        foreach key [array names tmp] {
            set states($key) $tmp($key)
        }
        error "ViewMaster could not load state file '$fname':\n$msg"
    }
}

# Creates a new molecule and tries to load the files specified by types and
# files.  $cwd is prepended to the path of all non-webpdb files.  If the
# file could not be located, the user is given the choice of either finding
# the file manually, in which case a load dialog is presented, or just 
# skipping it.  
proc ViewMaster::load_molecule { cwd types files } {
    # first pass: make sure files are present and readable
    set newfiles [list]
    set newtypes [list]
    foreach type $types file $files {
        if [string equal $type webpdb] {
            # assume webpdb files are always valid
            lappend newfiles $file
            lappend newtypes $type
        } else {
            set fname [file normalize [file join $cwd $file]]
            if ![file readable $fname] {
                set result [tk_messageBox \
                    -type retrycancel \
                    -title "ViewMaster: File not found!" \
                    -message "Could not read file '$fname'.  Click Retry to try to find this file, or Cancel to skip it."]
                if [string equal $result retry] {
                    set fname [tk_getOpenFile \
                        -defaultextension $type \
                        -title "ViewMaster: Select a $type file"]
                } else {
                    # skip it
                    set fname ""
                }
            }
            if [string length $fname] {
                lappend newfiles $fname
                lappend newtypes $type
            }
        }
    }
    # always create a new molecule, even if there are non files to load,
    # because the views expect to be provided with the correct number of
    # molecules.
    set id [mol new]
    foreach file $newfiles type $newtypes {
        set rc [catch [list mol addfile $file type $type waitfor all] msg]
        if $rc {
            puts "ERROR) Unable to load file '$file' as type '$type'."
            puts "ERROR) $msg"
        }
    }
    # rename according to the first molecule in the list, even if it
    # was skipped.
    mol rename top [lindex [file split [lindex $files 0]] end]
}

# restore material settings, creating new materials as necessary
proc ViewMaster::load_materials { matprops } {
    set curmat [material list]
    foreach { mat prop } $matprops {
        if { [lsearch $curmat $mat] < 0 } {
            material add $mat
        }
        foreach { ambn spec diff shin opct } $prop {
            material change ambient   $mat $ambn
            material change specular  $mat $spec
            material change diffuse   $mat $diff
            material change shininess $mat $shin
            material change opacity   $mat $opct
        }
    }
}

proc ViewMaster::load_view { keys vals } {
    variable states
    variable imageid
    variable autosave

    # turn off session file autosaving, since we don't want to overwrite
    # a file we might be reading from!
    set autosave_old $autosave
    set autosave 0

    # save the current view so that we get a new view which we can
    # overwrite with our new data.  Cache imageid first, since it
    # will be incremented when do_save is done.
    set id $imageid
    do_save

    # restore the autosave variable
    set autosave $autosave_old

    set nomols [list note colors colordefs colorscale]

    # replace the last n elements of view $id with the data in keys, vals,
    # where n is the number of keys/vals.
    foreach key $keys val $vals {
        if [info exists states($id,$key)] {
            # special cases
            if { [lsearch $nomols $key] >= 0 } {
                set states($id,$key) $val
            } else {
                set n [llength $val]
                set states($id,$key) [lrange $states($id,$key) 0 end-$n]
                set states($id,$key) [concat $states($id,$key) $val]
            }
        } else {
            set states($id,$key) $val
        }
    }
    # fix up the screenshot, since we hadn't created the view yet
    do_restore $id
    display update
    image delete $states($id,thumb)
    set img [save_screenshot]
    set states($id,thumb) $img
    add_widgets $id $img
}

proc ViewMaster::resize {src newx newy {dest ""} } {
    # taken from http://wiki.tcl.tk/11196
    # This is surprisingly fast - 800x800 images are resized to 50x50 in
    # only a couple of seconds on my 700 MHz G3. 

     set mx [image width $src]
     set my [image height $src]

     if { "$dest" == ""} {
         set dest [image create photo]
     }
     $dest configure -width $newx -height $newy

     # Check if we can just zoom using -zoom option on copy
     if { $newx % $mx == 0 && $newy % $my == 0} {

         set ix [expr {$newx / $mx}]
         set iy [expr {$newy / $my}]
         $dest copy $src -zoom $ix $iy
         return $dest
     }

     set ny 0
     set ytot $my

     for {set y 0} {$y < $my} {incr y} {

         #
         # Do horizontal resize
         #

         foreach {pr pg pb} [$src get 0 $y] {break}

         set row [list]
         set thisrow [list]

         set nx 0
         set xtot $mx

         for {set x 1} {$x < $mx} {incr x} {

             # Add whole pixels as necessary
             while { $xtot <= $newx } {
                 lappend row [format "#%02x%02x%02x" $pr $pg $pb]
                 lappend thisrow $pr $pg $pb
                 incr xtot $mx
                 incr nx
             }

             # Now add mixed pixels

             foreach {r g b} [$src get $x $y] {break}

             # Calculate ratios to use

             set xtot [expr {$xtot - $newx}]
             set rn $xtot
             set rp [expr {$mx - $xtot}]

             # This section covers shrinking an image where
             # more than 1 source pixel may be required to
             # define the destination pixel

             set xr 0
             set xg 0
             set xb 0

             while { $xtot > $newx } {
                 incr xr $r
                 incr xg $g
                 incr xb $b

                 set xtot [expr {$xtot - $newx}]
                 incr x
                 foreach {r g b} [$src get $x $y] {break}
             }

             # Work out the new pixel colours

             set tr [expr {int( ($rn*$r + $xr + $rp*$pr) / $mx)}]
             set tg [expr {int( ($rn*$g + $xg + $rp*$pg) / $mx)}]
             set tb [expr {int( ($rn*$b + $xb + $rp*$pb) / $mx)}]

             if {$tr > 255} {set tr 255}
             if {$tg > 255} {set tg 255}
             if {$tb > 255} {set tb 255}

             # Output the pixel

             lappend row [format "#%02x%02x%02x" $tr $tg $tb]
             lappend thisrow $tr $tg $tb
             incr xtot $mx
             incr nx

             set pr $r
             set pg $g
             set pb $b
         }

         # Finish off pixels on this row
         while { $nx < $newx } {
             lappend row [format "#%02x%02x%02x" $r $g $b]
             lappend thisrow $r $g $b
             incr nx
         }

         #
         # Do vertical resize
         #

         if {[info exists prevrow]} {

             set nrow [list]

             # Add whole lines as necessary
             while { $ytot <= $newy } {

                 $dest put -to 0 $ny [list $prow]

                 incr ytot $my
                 incr ny
             }

             # Now add mixed line
             # Calculate ratios to use

             set ytot [expr {$ytot - $newy}]
             set rn $ytot
             set rp [expr {$my - $rn}]

             # This section covers shrinking an image
             # where a single pixel is made from more than
             # 2 others.  Actually we cheat and just remove
             # a line of pixels which is not as good as it should be

             while { $ytot > $newy } {

                 set ytot [expr {$ytot - $newy}]
                 incr y
                 continue
             }

             # Calculate new row

             foreach {pr pg pb} $prevrow {r g b} $thisrow {

                 set tr [expr {int( ($rn*$r + $rp*$pr) / $my)}]
                 set tg [expr {int( ($rn*$g + $rp*$pg) / $my)}]
                 set tb [expr {int( ($rn*$b + $rp*$pb) / $my)}]

                 lappend nrow [format "#%02x%02x%02x" $tr $tg $tb]
             }

             $dest put -to 0 $ny [list $nrow]

             incr ytot $my
             incr ny
         }

         set prevrow $thisrow
         set prow $row

         update idletasks
     }

     # Finish off last rows
     while { $ny < $newy } {
         $dest put -to 0 $ny [list $row]
         incr ny
     }
     update idletasks

     return $dest
}

# another useful utility routine: give a list and a list of indices, 
# remove the elements of list corresponding to the indices.
proc ViewMaster::mask_list { lst mask } {
    set i 0
    set result [list]
    foreach elem $lst {
        # if i is not in mask...
        if { [lsearch $mask $i] < 0 } {
            # add it to the new list
            lappend result $elem
        }
        incr i
    }
    return $result
}
proc ViewMaster::help_about { } {
    set vn [package present ViewMaster]
    tk_messageBox -title "About ViewMaster $vn" -message \
"ViewMaster version $vn

Copyright (C) Justin Gullingsrud <jgulling@mccammon.ucsd.edu> 

This work is licensed under the Creative Commons Attribution-ShareAlike License. To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA."
}

# Boilerplate code for adding this widget to VMD's main menu.
proc viewmaster_tk_cb {} {
    ::ViewMaster::init
    return $ViewMaster::w
}

# after idle menu tk register viewmaster viewmaster_tk_cb ViewMaster

