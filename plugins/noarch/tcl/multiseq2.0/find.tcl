############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

############################################################################
# RCS INFORMATION:
#
#       $RCSfile: find.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.2 $       $Date: 2006/03/07 00:25:44 $
#
############################################################################

package provide multiseq 2.0

# Declare global variables for this package.
namespace eval ::MultiSeq::Find {

    # Export the package functions.
    namespace export showFindDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # The user's choices.
    variable choices
    array set choices {"selectionType" "all"
                       "searchString" ""}

    # Selection change listener for Find package
    # Clears find state once the user makes another selection
    proc findSelectionChangeListener { } {
      if {$::MultiSeq::inSetNewFind == 0} {
        set ::MultiSeq::findSelectionsActive 0
        set ::MultiSeq::findSelectionsPosition 0
        set ::MultiSeq::numFindSelections 0
        array set ::MultiSeq::findSelections {}
      }
    }

    # Add above to SeqEditWidget's list of selection change procs
    ::SeqEditWidget::setSelectionNotificationCommand "::MultiSeq::Find::findSelectionChangeListener"
    
    # Creates a dialog to get the user's options for running the selection.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showFindDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable choices
        set finished 0
    
        # Create a new top level window.
        set w [createModalDialog ".find" "Find Residues"]
        
        # Create the components.
        frame $w.center
            label $w.center.choice -text "Find In:"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.all -text "All Sequences" -variable "::MultiSeq::Find::choices(selectionType)" -value "all"
                    radiobutton $w.center.g1.b.marked -text "Marked Sequences" -variable "::MultiSeq::Find::choices(selectionType)" -value "marked"
                    
            label $w.center.find -text "Residues to Find:"
            frame $w.center.g2 -relief sunken -borderwidth 1
                frame $w.center.g2.b -relief raised -borderwidth 1
                    entry $w.center.g2.b.txt -width 20 -textvariable ::MultiSeq::Find::choices(searchString)
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::MultiSeq::Find::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::MultiSeq::Find::but_cancel"

				bind $w <Return> {::MultiSeq::Find::but_ok}
				bind $w <Escape> {::MultiSeq::Find::but_cancel}
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.choice           -column 1 -row 1 -sticky nw -pady 3
        grid $w.center.g1               -column 2 -row 1 -sticky nw -padx 1 -pady 3  -columnspan 2
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.all         -column 1 -row 1 -sticky w
        grid $w.center.g1.b.marked      -column 1 -row 2 -sticky w
        
        grid $w.center.find             -column 1 -row 2 -sticky w -pady 3
        grid $w.center.g2               -column 2 -row 2 -sticky nw -padx 1 -pady 3  -columnspan 2
        pack $w.center.g2.b             -fill both -expand true -side left
        grid $w.center.g2.b.txt         -column 1 -row 1 -sticky w
        
        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -padx 5 -pady 5

				# Set focus
				focus $w.center.g2.b.txt

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Find::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::Find::finished"
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
        set width 261
        set height [expr 118+22]
        
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

