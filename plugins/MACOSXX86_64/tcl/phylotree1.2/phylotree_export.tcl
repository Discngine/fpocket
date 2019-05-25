############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_export.tcl,v 1.4 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::Export {

    # Export the package functions.
    namespace export showExportDialog

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
    array set choices {"filename" ""
                       "formatType" "newick"
                       "newickIncludeInternalLabels" "1"
                       "newickIncludeBranchLengths" "1"
                       "nexusIncludeInternalLabels" "1"
                       "nexusIncludeBranchLengths" "1"}
    
    
    # Creates a dialog to get the user's options for running the data export.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showExportDialog {parent} {
    
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable choices
        set finished 0
    
        # Create a new top level window.
        set w [createModalDialog ".savetree" "Save Tree"]
        
        # Create the components.
        frame $w.center
            label $w.center.lfilename -text "Filename:"
            entry $w.center.filename -textvariable "::PhyloTree::Export::choices(filename)" -width 40
            button $w.center.filenamebrs -text "Browse..." -pady 2 -command "::PhyloTree::Export::but_browse"
            label $w.center.ltype -text "File Format:"
            frame $w.center.g2 -relief sunken -borderwidth 1
                frame $w.center.g2.b -relief raised -borderwidth 1
                    radiobutton $w.center.g2.b.newick -text "Newick" -variable "::PhyloTree::Export::choices(formatType)" -value "newick"
                        checkbutton $w.center.g2.b.newick1 -text "Include internal labels" -variable "::PhyloTree::Export::choices(newickIncludeInternalLabels)" -onvalue "1" -offvalue "0"
                        checkbutton $w.center.g2.b.newick2 -text "Include branch lengths" -variable "::PhyloTree::Export::choices(newickIncludeBranchLengths)" -onvalue "1" -offvalue "0"
                    radiobutton $w.center.g2.b.nexus -text "Nexus" -variable "::PhyloTree::Export::choices(formatType)" -value "nexus"
                        checkbutton $w.center.g2.b.nexus1 -text "Include internal labels" -variable "::PhyloTree::Export::choices(nexusIncludeInternalLabels)" -onvalue "1" -offvalue "0"
                        checkbutton $w.center.g2.b.nexus2 -text "Include branch lengths" -variable "::PhyloTree::Export::choices(nexusIncludeBranchLengths)" -onvalue "1" -offvalue "0"
                    
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::PhyloTree::Export::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::PhyloTree::Export::but_cancel"
                bind $w <Return> {::PhyloTree::Export::but_ok}
                bind $w <Escape> {::PhyloTree::Export::but_cancel}
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.lfilename        -column 1 -row 1 -sticky w
        grid $w.center.filename         -column 2 -row 1 -sticky w -padx 5
        grid $w.center.filenamebrs      -column 3 -row 1 -sticky w -padx 10
        grid $w.center.ltype            -column 1 -row 3 -sticky nw -pady 3
        grid $w.center.g2               -column 2 -row 3 -sticky nw -padx 5 -pady 3 -columnspan 2
        pack $w.center.g2.b                 -fill both -expand true -side left
        grid $w.center.g2.b.newick          -column 1 -row 1 -sticky w
        grid $w.center.g2.b.newick1         -column 1 -row 2 -sticky w -padx 20
        grid $w.center.g2.b.newick2         -column 1 -row 3 -sticky w -padx 20
        grid $w.center.g2.b.nexus           -column 1 -row 4 -sticky w
        grid $w.center.g2.b.nexus1          -column 1 -row 5 -sticky w -padx 20
        grid $w.center.g2.b.nexus2          -column 1 -row 6 -sticky w -padx 20

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Export::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::PhyloTree::Export::finished"
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
        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 472
        set height [expr 194+22]
        
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
    
    proc but_ok {} {
    
        variable w
        variable finished
        variable choices
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        variable finished
    
        # Close the window.    
        set finished 0
    }
    
    proc but_browse {} {
    
        variable w
        variable choices

        set filename [tk_getSaveFile -filetypes {{{All Files} * }} -title "Save Tree"]
        if {$filename != ""} {
            set choices(filename) $filename
        }
    }
}

