############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide multiseq 2.0

# Globals for this namespace
namespace eval MultiSeq::Plot {

    # Export the package functions.
    namespace export showPlotDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # Default parameters.    
    variable eScoreDefault 0.00001
    variable iterationsDefault 1
    
    # The user's choices.
    variable choices
    array set choices {"selectionType" "all"
                       "plotType" {"::Libbiokit::Metric::calculateQres" "Residue" "Qres" "Qres"}
                       "customMetric" ""}

    # Creates a dialog to get the user's options for running the data import.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showPlotDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable choices
        set finished 0

        # Create a new modal dlg
        set w [createModalDialog ".plotdialog" "Data Plotting"]
        
        # Set up the dialog widgets
        frame $w.center
            label $w.center.for -text "Create plot for:"
            frame $w.center.g2 -relief sunken -borderwidth 1
                frame $w.center.g2.b -relief raised -borderwidth 1
                    radiobutton $w.center.g2.b.all -text "All Sequences" -variable "::MultiSeq::Plot::choices(selectionType)" -value "all"
                    radiobutton $w.center.g2.b.marked -text "Marked Sequences" -variable "::MultiSeq::Plot::choices(selectionType)" -value "marked"
                    radiobutton $w.center.g2.b.selected -text "Selected Regions" -variable "::MultiSeq::Plot::choices(selectionType)" -value "selected"                    
            label $w.center.what -text "Per-residue data to plot:"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.q -text "Qres" -variable "::MultiSeq::Plot::choices(plotType)" -value {"::Libbiokit::Metric::calculateQres" "Residue" "Qres" "Qres"}
                    radiobutton $w.center.g1.b.rmsd -text "RMSD" -variable "::MultiSeq::Plot::choices(plotType)" -value {"::Libbiokit::Metric::calculateRMSD" "Residue" "RMSD" "RMSD Per Residue"}
                    radiobutton $w.center.g1.b.cons -text "Sequence Conservation" -variable "::MultiSeq::Plot::choices(plotType)" -value {"::SeqEdit::Metric::Conservation::calculate" "Residue" "Conservation" "Conservation"}
                    radiobutton $w.center.g1.b.identity -text "Sequence Identity" -variable "::MultiSeq::Plot::choices(plotType)" -value {"::SeqEdit::Metric::PercentIdentity::calculate" "Residue" "Percent Identity" "Percent Identity"}
                    radiobutton $w.center.g1.b.custom -text "Custom" -variable "::MultiSeq::Plot::choices(plotType)" -value {"customMetric" "Residue" "Metric" "Custom Metric"}
                    entry $w.center.g1.b.customtxt -textvariable "::MultiSeq::Plot::choices(customMetric)" -width 20
                    
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::MultiSeq::Plot::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::MultiSeq::Plot::but_cancel"
                bind $w <Return> {::MultiSeq::Plot::but_ok}
                bind $w <Escape> {::MultiSeq::Plot::but_cancel}

        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        
        grid $w.center.for              -column 1 -row 1 -sticky nw
        grid $w.center.g2               -column 2 -row 1 -sticky nw -padx 5
        pack $w.center.g2.b             -fill both -expand true -side left
        grid $w.center.g2.b.all         -column 1 -row 1 -sticky w
        grid $w.center.g2.b.marked      -column 1 -row 2 -sticky w
        grid $w.center.g2.b.selected    -column 1 -row 3 -sticky w
        
        grid $w.center.what             -column 1 -row 2 -sticky nw -pady 5
        grid $w.center.g1               -column 2 -row 2 -sticky nw -padx 5 -pady 5
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.q           -column 1 -row 1 -sticky w -columnspan 2
        grid $w.center.g1.b.rmsd        -column 1 -row 2 -sticky w -columnspan 2
        grid $w.center.g1.b.cons        -column 1 -row 3 -sticky w -columnspan 2
        grid $w.center.g1.b.identity    -column 1 -row 4 -sticky w -columnspan 2
        grid $w.center.g1.b.custom      -column 1 -row 5 -sticky w
        grid $w.center.g1.b.customtxt   -column 2 -row 5 -sticky w -padx 5

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Plot::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::Plot::finished"
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
        set width 381
        set height [expr 220+22]
        
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
