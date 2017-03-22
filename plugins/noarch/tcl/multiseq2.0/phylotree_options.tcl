############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide multiseq 2.0

# Declare global variables for this package.
namespace eval ::MultiSeq::Phylotree {

    # Export the package functions.
    namespace export showOptionsDialog
    
    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished 1
    
    # The user's choices.
    variable choices
    array set choices {"selectionType" "all"
                       "qh" "0"
                       "rmsd" "0"
                       "pid" "0"
                       "clustalw" "0"
                       "file" "0"
                       "filename" ""
                       "alignedOnly" "0"}
    
    # Creates a dialog to get the user's choices.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showOptionsDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable choices
        set finished 0
    
        # Create a new top level window.
        set w [createModalDialog ".phylotreeoptions" "Create Phylogenetic Tree"]
        
        # Create the components.
        frame $w.center
            label $w.center.choice -text "Create tree for:"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.all -text "All Sequences" -variable "::MultiSeq::Phylotree::choices(selectionType)" -value "all"
                    radiobutton $w.center.g1.b.marked -text "Marked Sequences" -variable "::MultiSeq::Phylotree::choices(selectionType)" -value "marked"
                    radiobutton $w.center.g1.b.selected -text "Selected Regions" -variable "::MultiSeq::Phylotree::choices(selectionType)" -value "selected"                    
                        
            checkbutton $w.center.aligned -text "Use only aligned columns" -variable "::MultiSeq::Phylotree::choices(alignedOnly)" -onvalue 1 -offvalue 0
            
            label $w.center.l1 -text "Create the following trees:"
            checkbutton $w.center.qh -text "Structural tree using QH" -variable "::MultiSeq::Phylotree::choices(qh)" -onvalue 1 -offvalue 0
            checkbutton $w.center.rmsd -text "Structural tree using RMSD" -variable "::MultiSeq::Phylotree::choices(rmsd)" -onvalue 1 -offvalue 0
            checkbutton $w.center.pid -text "Sequence tree using Percent Identity" -variable "::MultiSeq::Phylotree::choices(pid)" -onvalue 1 -offvalue 0
            checkbutton $w.center.clustalw -text "Sequence tree using CLUSTALW" -variable "::MultiSeq::Phylotree::choices(clustalw)" -onvalue 1 -offvalue 0
            checkbutton $w.center.file -text "From File:" -variable "::MultiSeq::Phylotree::choices(file)" -onvalue 1 -offvalue 0
            entry $w.center.filename -textvariable "::MultiSeq::Phylotree::choices(filename)" -width 35
            button $w.center.filebrowse -text "Browse..." -pady 2 -command "::MultiSeq::Phylotree::but_browsefile"
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::MultiSeq::Phylotree::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::MultiSeq::Phylotree::but_cancel"
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.choice           -column 1 -row 1 -sticky nw -pady 8
        grid $w.center.g1               -column 2 -row 1 -sticky nw -padx 5 -pady 8 -columnspan 2
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.all             -column 1 -row 1 -sticky w
        grid $w.center.g1.b.marked          -column 1 -row 2 -sticky w
        grid $w.center.g1.b.selected        -column 1 -row 3 -sticky w
        grid $w.center.aligned          -column 2 -row 3 -sticky nw -columnspan 2
        grid $w.center.l1               -column 1 -row 4 -sticky nw -columnspan 3 -pady 5
        grid $w.center.qh               -column 2 -row 5 -sticky nw -columnspan 2
        grid $w.center.rmsd             -column 2 -row 6 -sticky nw -columnspan 2
        grid $w.center.pid              -column 2 -row 7 -sticky nw -columnspan 2
        grid $w.center.clustalw         -column 2 -row 8 -sticky nw -columnspan 2
        grid $w.center.file             -column 2 -row 9 -sticky nw -columnspan 2
        grid $w.center.filename         -column 2 -row 10 -sticky w -padx 25
        grid $w.center.filebrowse       -column 3 -row 10 -sticky w

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -padx 5 -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Phylotree::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::Phylotree::finished"
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
        set width 474
        set height [expr 287+22]
        
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
    
    proc but_browsefile {} {
    
        # Import global variables.
        variable w
        variable choices

        set filename [tk_getOpenFile -filetypes {{{Tree Files} {.dnd .ph .tre .nex .nxs .jet}} {{Phylip Tree Files} {.dnd .ph .tre}} {{NEXUS Tree Files} {.nex .nxs}} {{JE Tree Files} {.jet}} {{All Files} * }} -title "Select Phylogenetic Tree"]
        if {$filename != ""} {
            set choices(filename) $filename
            $w.center.file select
            $w.center.filename icursor [string length $filename]
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
