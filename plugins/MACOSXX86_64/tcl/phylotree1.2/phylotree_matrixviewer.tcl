############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_matrixviewer.tcl,v 1.5 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::MatrixViewer {

    # Export the package functions.
    namespace export showMatrixViewerDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    variable matrixFont
    
    # Creates a dialog that allows the user to modify a listing of the groups that should appear in
    # the editor.
    # args:     groups - A list of the groups currently in the editor.
    # return:   The new name of the sequence if it was changed, otherwise an empty string.
    proc showMatrixViewerDialog {parent matrix} {
    
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable matrixFont
        set finished 0
    
        # Create a new top level window.
        set w [createModalDialog ".matrixviewer" "Distance Matrix"]
        if {![info exists matrixFont]} {
            variable matrixFont [font create matrixFont -family Courier -size 12]
        }
        
        # Create the components.
        frame $w.center
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.center
                    text $w.center.g1.center.matrix -font $matrixFont -wrap none -width 80 -height 30 -yscrollcommand "$w.center.g1.center.yscroll set" -xscrollcommand "$w.center.g1.bottom.xscroll set"
                    scrollbar $w.center.g1.center.yscroll -orient vertical -command "$w.center.g1.center.matrix yview"
                frame $w.center.g1.bottom
                    scrollbar $w.center.g1.bottom.xscroll -orient horizontal -command "$w.center.g1.center.matrix xview"
                    frame $w.center.g1.bottom.spacer -width [$w.center.g1.center.yscroll cget -width]
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.close -text "Close" -pady 2 -command "::PhyloTree::MatrixViewer::but_close"
                bind $w <Return> {::PhyloTree::MatrixViewer::but_close}
                bind $w <Escape> {::PhyloTree::MatrixViewer::but_close}

        # Fill in the text area with the matrix.
        set nameWidth 0
        set numberWidth 0
        foreach row $matrix {
            set column 0
            foreach columnValue $row {
                if {$column == 0} {
                    if {[string length $columnValue] > $nameWidth} {
                        set nameWidth [string length $columnValue]
                    }
                } else {
                    if {[string length $columnValue] > $numberWidth} {
                        set numberWidth [string length $columnValue]
                    }
                }
                incr column
            }
        }
        set matrixString ""
        foreach row $matrix {
            set column 0
            foreach columnValue $row {
                if {$column == 0} {
                    append matrixString [getPaddedString $columnValue $nameWidth right]
                } else {
                    append matrixString "  " [getPaddedString $columnValue $numberWidth right]
                }
                incr column
            }
            append matrixString "\n"
        }
        $w.center.g1.center.matrix insert 0.0 $matrixString
        
        # Layout the components.
        pack $w.center                   -fill both -expand true -side top -padx 5 -pady 5
        pack $w.center.g1                -fill both -expand true -side top
        pack $w.center.g1.center         -side top -fill both -expand true
        pack $w.center.g1.center.matrix  -side left -fill both -expand true
        pack $w.center.g1.center.yscroll -side right -fill y        
        pack $w.center.g1.bottom         -side bottom -fill x
        pack $w.center.g1.bottom.xscroll -side left -fill x -expand true
        pack $w.center.g1.bottom.spacer  -side right
        pack $w.bottom                   -fill x -side bottom
        pack $w.bottom.buttons           -side bottom
        pack $w.bottom.buttons.close     -side left -padx 5 -pady 5
        
        # Bind the window closing event.
        bind $w <Destroy> {::PhyloTree::MatrixViewer::but_close}
        
        # Place the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable ::PhyloTree::MatrixViewer::finished
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"

        # Destroy the dialog.
        destroyDialog        
        
        # Return.
        return 1
    }
    
    proc getPaddedString {str count {side right}} {
        
        if {[string length $str] > $count} {
            set str [string range 0 [expr $count-1]]
        }
        if {$side == "right"} {
            while {[string length $str] < $count} {
                append str " "
            }
            return $str
        } elseif {$side == "left"} {
            while {[string length $str] < $count} {
                set str " $str"
            }
            return $str
        }
    }   

    
    # Creates a new modal dialog window given a prefix for the window name and a title for the dialog.
    # args:     prefix - The prefix for the window name of this dialog. This should start with a ".".
    #           dialogTitle - The title for the dialog.
    # return:   The name of the newly created dialog.
    proc createModalDialog {prefix dialogTitle} {

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
        #grab $w
        focus $w
        
        return $w
    }
    
    # Centers the dialog.
    proc centerDialog {{parent ""}} {
        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 596
        set height [expr 432+22]
        
        # Figure out the x and y position.
        if {$parent != ""} {
            set cx [expr {int ([winfo rootx $parent] + [winfo width $parent] / 2)}]
            set cy [expr {int ([winfo rooty $parent] + [winfo height $parent] / 2)}]
            set x [expr {$cx - int ($width / 2)}]
            set y [expr {$cy - int ($height / 2)}]
            
        } else {
            set x [expr {int (([winfo screenwidth $w] - [winfo reqwidth $w]) / 2)}]
            set y [expr {int (([winfo screenheight $w] - [winfo reqheight $w]) / 2)}]
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
    
    proc but_close {} {
    
        variable finished

        # Close the window.
        set finished 1
    }
}

