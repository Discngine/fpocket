############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide multiseqdialog 1.0

namespace eval ::MultiSeqDialog::DownloadUpdates {

    # Export the package functions.
    namespace export showDownloadUpdatesDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    variable updateFont
    
    # The user's choices.
    variable choices
    array set choices {"update" "1"}
    
    
    # Creates a dialog to get the user's options for running the data export.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showDownloadUpdatesDialog {updates} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable updateFont
        variable choices
        set finished 0
    
        if {![info exists updateFont]} {
            set updateFont [font create updateFont -family Courier -size 12]
        }
    
        # Create a new top level window.
        set w [createModalDialog ".downloadupdates" "Updates Available"]
        
        # Create the components.
        frame $w.center
            label $w.center.label1 -text "New versions of the following metadata databases are available, would you like to download them now?"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.center
                    text $w.center.g1.center.updates -font $updateFont -wrap none -width 80 -height 30 -yscrollcommand "$w.center.g1.center.yscroll set" -xscrollcommand "$w.center.g1.bottom.xscroll set"
                    scrollbar $w.center.g1.center.yscroll -orient vertical -command "$w.center.g1.center.updates yview"
                frame $w.center.g1.bottom
                    scrollbar $w.center.g1.bottom.xscroll -orient horizontal -command "$w.center.g1.center.updates xview"
                    frame $w.center.g1.bottom.spacer -width [$w.center.g1.center.yscroll cget -width]
                    
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "Yes" -pady 2 -command "::MultiSeqDialog::DownloadUpdates::but_ok"
                button $w.bottom.buttons.cancel -text "No" -pady 2 -command "::MultiSeqDialog::DownloadUpdates::but_cancel"
                bind $w <Return> {::MultiSeqDialog::DownloadUpdates::but_ok}
                bind $w <Escape> {::MultiSeqDialog::DownloadUpdates::but_cancel}
                
        # Fill in the update text.
        set updateText ""
        foreach update $updates {
            set key [lindex $update 0]
            set description [lindex $update 1]
            set version [lindex $update 4]
            set size [lindex $update 5]
            set sizeLabel "Bytes"
            if {$size >= 1024} {
                set size [expr $size/1024]
                set sizeLabel "KB"
                if {$size >= 1024} {
                    set size [expr $size/1024]
                    set sizeLabel "MB"
                }
            }
            if {$updateText != ""} {
                append updateText "\n\n"
            }
            append updateText "$description:\n    New version: $version\n    Size:        $size $sizeLabel"
        }
        $w.center.g1.center.updates insert end $updateText
        
        # Layout the components.
        pack $w.center                   -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.label1            -column 1 -row 1 -sticky w
        grid $w.center.g1                -column 1 -row 2 -sticky w
        pack $w.center.g1.center         -side top -fill both -expand true
        pack $w.center.g1.center.updates -side left -fill both -expand true
        pack $w.center.g1.center.yscroll -side right -fill y        
        pack $w.center.g1.bottom         -side bottom -fill x
        pack $w.center.g1.bottom.xscroll -side left -fill x -expand true
        pack $w.center.g1.bottom.spacer  -side right

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"::MultiSeqDialog::DownloadUpdates::but_cancel"}
        
        # Center the dialog.
        centerDialog
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeqDialog::DownloadUpdates::finished"
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"
        
        # Destroy the dialog.
        destroyDialog        
        
        # Return the options.
        if {$finished == 1} {
            return [array get choices]
        } else {
            return {}
        }
    }
    
    # Creates a new modal dialog window given a prefix for the window name and a title for the dialog.
    # args:     prefix - The prefix for the window name of this dialog. This should start with a ".".
    #           dialogTitle - The title for the dialog.
    # return:   The name of the newly created dialog.
    proc createModalDialog {prefix dialogTitle} {

        # Import global variables.        
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        
        # Find a name for the dialog
        set unique 0
        set childList [winfo children .]
        while {[lsearch $childList $prefix$unique] != -1} {
            incr unique
        }

        # Create the dialog.        
        set w [toplevel $prefix$unique]
        
        # Set the dialog title.
        wm title $w $dialogTitle
        
        # Make the dialog modal.
        set oldFocus [focus]
        set oldGrab [grab current $w]
        if {$oldGrab != ""} {
            set grabStatus [grab status $oldGrab]
        }
        grab $w
        focus $w
        
        return $w
    }
    
    # Centers the dialog.
    proc centerDialog {{parent ""}} {
        
        # Import global variables.        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 596
        set height [expr 446+22]
        
        # Figure out the x and y position.
        if {$parent != ""} {
            set cx [expr {int ([winfo rootx $parent] + [winfo width $parent] / 2)}]
            set cy [expr {int ([winfo rooty $parent] + [winfo height $parent] / 2)}]
            set x [expr {$cx - int ($width / 2)}]
            set y [expr {$cy - int ($height / 2)}]
            
        } else {
            set x [expr {int (([winfo screenwidth $w] - $width) / 2)}]
            set y [expr {int (([winfo screenheight $w] - $height) / 2)}]
        }
        
        # Make sure we are within the screen bounds.
        if {$x < 0} {
            set x 0
        } elseif {[expr $x+$width] > [winfo screenwidth $w]} {
            set x [expr [winfo screenwidth $w]-$width]
        }
        if {$y < 22} {
            set y 22
        } elseif {[expr $y+$height] > [winfo screenheight $w]} {
            set y [expr [winfo screenheight $w]-$height]
        }
            
        wm geometry $w +${x}+${y}
        wm positionfrom $w user
    }
    
    # Destroys the dialog. This method releases the dialog resources and restores the system handlers.
    proc destroyDialog {} {
        
        # Import global variables.        
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        
        # Destroy the dialog.
        catch {focus $oldFocus}
        catch {
            bind $w <Destroy> {}
            destroy $w
        }
        if {$oldGrab != ""} {
            if {$grabStatus == "global"} {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }
    }
    
    proc but_ok {} {
    
        # Import global variables.
        variable w
        variable finished
        variable choices
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Close the window.    
        set finished 0
    }
}

