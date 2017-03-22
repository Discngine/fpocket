############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide multiseqdialog 1.0

namespace eval ::MultiSeqDialog::Wait {

    # Export the package functions.
    namespace export showWaitDialog hideWaitDialog

    # Dialog management variables.
    variable w ""
    
    # Creates a dialog to get the user's options for running the selection.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showWaitDialog {message} {
    
        # Import global variables.
        variable w

        # Create a new top level window.
        set w [toplevel ".wait"]
        wm title $w "Please Wait"
        
        # Create the components.
        frame $w.center
            label $w.center.message -text $message
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.message          -column 1 -row 1 -sticky nw -padx 15 -pady 15
        
        # Center the dialog.
        centerDialog
    }

    proc hideWaitDialog {} {
    
        # Import global variables.
        variable w
        
        if {$w != ""} {
            destroy $w
            set w ""
        }
    }
    
    # Centers the dialog.
    proc centerDialog {{parent ""}} {
        
        # Import global variables.        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 309
        set height [expr 192+22]
        
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
}

