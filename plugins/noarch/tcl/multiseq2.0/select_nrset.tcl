############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################


package provide multiseq 2.0

# Declare global variables for this package.
namespace eval ::MultiSeq::SelectNRSet {

    # Export the package functions.
    namespace export showSelectNRSetDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    variable initialized
    
    # The user's choices.
    variable choices
    array set choices {"selectionType" "all"
                       "method" "structure"
                       "identityCutoff" "40"
                       "seqPercentCutoff" "100"
                       "gapScale" "1.0"
                       "qhCutoff" "0.6"
                       "seedWithSelected" "0"}
    
    # Creates a dialog to get the user's options for running the selection.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showSelectNRSetDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable initialized
        variable choices
        set finished 0
        array set initialized {"qhcutoff" 0 "pidcutoff" 0 "spercutoff" 0}
    
        # Create a new top level window.
        set w [createModalDialog ".selectnrset" "Select Non-Redundant Set"]
        
        # Create the components.
        frame $w.center
            label $w.center.choice -text "Select from:    "
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.all -text "All Sequences" -variable "::MultiSeq::SelectNRSet::choices(selectionType)" -value "all"
                    radiobutton $w.center.g1.b.marked -text "Marked Sequences" -variable "::MultiSeq::SelectNRSet::choices(selectionType)" -value "marked"
                    
            radiobutton $w.center.structure -text "Using Structure QR" -variable "::MultiSeq::SelectNRSet::choices(method)" -value "structure"
            label $w.center.qhcutofflabel -text "QH Cutoff:"
            scale $w.center.qhcutoff -orient horizontal -length 120 -sliderlength 10 -from 0 -to 1.0 -resolution 0.01 -tickinterval 0.5 -variable "::MultiSeq::SelectNRSet::choices(qhCutoff)" -command "::MultiSeq::SelectNRSet::scale_changeQHCutoff"
            radiobutton $w.center.sequence -text "Using Sequence QR" -variable "::MultiSeq::SelectNRSet::choices(method)" -value "sequence"
            label $w.center.idcutofflabel -text "Maximum PID:"
            scale $w.center.idcutoff -orient horizontal -length 120 -sliderlength 10 -from 0 -to 100 -resolution 1 -tickinterval 50 -variable "::MultiSeq::SelectNRSet::choices(identityCutoff)" -command "::MultiSeq::SelectNRSet::scale_changeIDCutoff"
            label $w.center.spercutofflabel -text "Percent of Set:"
            scale $w.center.spercutoff -orient horizontal -length 120 -sliderlength 10 -from 0 -to 100 -resolution 1 -tickinterval 50 -variable "::MultiSeq::SelectNRSet::choices(seqPercentCutoff)" -command "::MultiSeq::SelectNRSet::scale_changeSeqPercentCutoff"
            label $w.center.gapscalelabel -text "Gap Scale Factor:"
            scale $w.center.gapscale -orient horizontal -length 120 -sliderlength 10 -from 0.0 -to 10.0 -resolution 0.5 -tickinterval 5.0 -variable "::MultiSeq::SelectNRSet::choices(gapScale)"
            checkbutton $w.center.seed -text "Seed with selected sequences" -variable "::MultiSeq::SelectNRSet::choices(seedWithSelected)" -onvalue 1 -offvalue 0
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::MultiSeq::SelectNRSet::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::MultiSeq::SelectNRSet::but_cancel"
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.choice           -column 1 -row 1 -sticky nw -pady 3
        grid $w.center.g1               -column 2 -row 1 -sticky nw -padx 1 -pady 3  -columnspan 2
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.all         -column 1 -row 1 -sticky w
        grid $w.center.g1.b.marked      -column 1 -row 2 -sticky w
        
        grid $w.center.structure        -column 1 -row 2 -sticky w -pady 3 -columnspan 3
        grid $w.center.qhcutofflabel    -column 2 -row 3 -sticky w
        grid $w.center.qhcutoff         -column 3 -row 3 -sticky w
        grid $w.center.sequence         -column 1 -row 4 -sticky w -pady 3 -columnspan 3
        grid $w.center.idcutofflabel    -column 2 -row 5 -sticky w
        grid $w.center.idcutoff         -column 3 -row 5 -sticky w
        grid $w.center.spercutofflabel  -column 2 -row 6 -sticky w
        grid $w.center.spercutoff       -column 3 -row 6 -sticky w
        grid $w.center.gapscalelabel    -column 2 -row 7 -sticky w
        grid $w.center.gapscale         -column 3 -row 7 -sticky w
        grid $w.center.seed             -column 1 -row 8 -sticky w -pady 8 -columnspan 3
        
        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -padx 5 -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::SelectNRSet::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::SelectNRSet::finished"
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
        set width 319
        set height [expr 345+22]
        
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

        # Hide the cutoff line, if a tree is visible.
        set treeID [::PhyloTree::getActiveTree]
        if {[::PhyloTree::windowExists] && $treeID != -1 && [::PhyloTree::Data::getTreeUnits $treeID] == "delta PID"} {
            ::PhyloTree::Widget::hideCutoffLine
        }
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Hide the cutoff line, if a tree is visible.
        set treeID [::PhyloTree::getActiveTree]
        if {[::PhyloTree::windowExists] && $treeID != -1 && [::PhyloTree::Data::getTreeUnits $treeID] == "delta PID"} {
            ::PhyloTree::Widget::hideCutoffLine
        }
            
        # Close the window.    
        set finished 0
    }
    
    proc scale_changeQHCutoff {value} {
        
        # Import global variables.
        variable choices
        variable initialized
        
        # See if this is a change call or an initialization call with the choice selected.
        if {$initialized(qhcutoff) || $choices(method) == "structure"} {
            
            # If this is a change call, make sure the structure method is selected
            if {$initialized(qhcutoff)} {
                set choices(method) "structure"
            }
            
            # Set the cutoff line, if appropriate.
            set treeID [::PhyloTree::getActiveTree]
            if {[::PhyloTree::windowExists] && $treeID != -1} {
                if {[::PhyloTree::Data::getTreeUnits $treeID] == "delta QH"} {
                    ::PhyloTree::Widget::showCutoffLine [expr (1.0-$value)/2.0]
                } else {
                    ::PhyloTree::Widget::hideCutoffLine
                }
            }
        }
        
        # Mark that we have been initialized.
        set initialized(qhcutoff) 1
    }
    
    proc scale_changeIDCutoff {value} {
        
        # Import global variables.
        variable choices
        variable initialized
        
        # See if this is a change call or an initialization call with the choice selected.
        if {$initialized(pidcutoff) || $choices(method) == "sequence"} {
            
            # If this is a change call, make sure the sequence method is selected
            if {$initialized(pidcutoff)} {
                set choices(method) "sequence"
            }
            
            # Make sure the other choice is set to 100.
            set choices(seqPercentCutoff) "100"
            
            # Set the cutoff line, if appropriate.
            set treeID [::PhyloTree::getActiveTree]
            if {[::PhyloTree::windowExists] && $treeID != -1} {
                if {[::PhyloTree::Data::getTreeUnits $treeID] == "delta PID"} {
                    ::PhyloTree::Widget::showCutoffLine [expr ((100.0-$value)/100.0)/2.0]
                } else {
                    ::PhyloTree::Widget::hideCutoffLine
                }
            }
        }
        
        # Mark that we have been initialized.
        set initialized(pidcutoff) 1            
    }
    
    proc scale_changeSeqPercentCutoff {value} {
        
        # Import global variables.
        variable choices
        variable initialized
        
        # See if this is a change call.
        if {$initialized(spercutoff)} {
            
            # Make sure the sequence method is selected
            set choices(method) "sequence"
            
            # Make sure the other choice is set to 100.
            set choices(identityCutoff) "100"
            
            # Set the cutoff line, if appropriate.
            set treeID [::PhyloTree::getActiveTree]
            if {[::PhyloTree::windowExists] && $treeID != -1} {
                ::PhyloTree::Widget::hideCutoffLine
            }
        }
        
        # Mark that we have been initialized.
        set initialized(spercutoff) 1            
    }
    
    
}

