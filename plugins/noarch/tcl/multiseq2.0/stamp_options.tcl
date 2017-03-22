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
#       $RCSfile: stamp_options.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.6 $       $Date: 2005/09/28 17:32:09 $
#
############################################################################

package provide multiseq 2.0

# Declare global variables for this package.
namespace eval MultiSeq::Stamp {

    # Export the package functions.
    namespace export showStampOptionsDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # The stamp options.
    variable stampOptions
    array set stampOptions {}

    # Default Stamp parameters.    
    variable npassDefault 2
    variable scanDefault 1
    variable scanscoreDefault 6
    variable scanslideDefault 5
    variable slowscanDefault 0
    
    # Variables used by the widgets.
    variable showPreview 1
    variable alignmentType "all"
    variable npass $npassDefault    
    variable scan $scanDefault
    variable scanscore $scanscoreDefault
    variable scanslide $scanslideDefault
    variable slowscan $slowscanDefault
    
    # Creates a dialog to get the user's options for running Stamp.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showStampOptionsDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable stampOptions
        variable npass
        set finished 0
        unset stampOptions
        array set stampOptions {}
    
        # Create a new top level window.
        set w [createModalDialog ".stampoptions" "Stamp Alignment Options"]
        
        # Create the components.
        frame $w.center
            label $w.center.choice -text "Align the following:"
            frame $w.center.g1
                frame $w.center.g1.s
                frame $w.center.g1.a -relief sunken -borderwidth 1
                    frame $w.center.g1.a.b -relief raised -borderwidth 1
                        radiobutton $w.center.g1.a.b.all -text "All Structures" -variable "[namespace current]::alignmentType" -value "all"
                        radiobutton $w.center.g1.a.b.marked -text "Marked Structures" -variable "[namespace current]::alignmentType" -value "marked"
                        radiobutton $w.center.g1.a.b.selected -text "Selected Regions" -variable "[namespace current]::alignmentType" -value "selected"

            label $w.center.previewLabel -text "Show Alignment Preview:"
            checkbutton $w.center.preview -variable "[namespace current]::showPreview" -onvalue 1 -offvalue 0
            
            
            
            label $w.center.npassLabel -text "Number of Passes (npass):"
            listbox $w.center.npass -selectmode single -exportselection FALSE -height 2 -width 2
                $w.center.npass insert end 1
                $w.center.npass insert end 2
                $w.center.npass selection set [expr $npass-1]
            label $w.center.scanscoreLabel -text "Similarity (scanscore):"
            scale $w.center.scanscore -label "0=least similar, 6=most similar" -orient horizontal -length 80 -sliderlength 10 -from 0 -to 6 -resolution 1 -tickinterval 2 -variable "[namespace current]::scanscore"
            label $w.center.scanslideLabel -text "Comparison residues (scanslide):"
            scale $w.center.scanslide -orient horizontal -length 80 -sliderlength 10 -from 1 -to 10 -resolution 1 -tickinterval 4 -variable "[namespace current]::scanslide"
            label $w.center.slowscanLabel -text "Slow scan:"
            checkbutton $w.center.slowscan -variable "[namespace current]::slowscan" -onvalue 1 -offvalue 0
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "[namespace current]::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "[namespace current]::but_cancel"
                button $w.bottom.buttons.defaults -text "Defaults" -pady 2 -command "[namespace current]::but_defaults"
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.choice           -column 1 -row 1 -sticky nw -pady 3
        grid $w.center.g1               -column 2 -row 1 -sticky nw -padx 5 -pady 3 -columnspan 2
        pack $w.center.g1.s             -fill both -expand true -side left 
        pack $w.center.g1.a             -fill both -expand true -side left
        pack $w.center.g1.a.b           -fill both -expand true -side left
        grid $w.center.g1.a.b.all       -column 1 -row 1 -sticky w
        grid $w.center.g1.a.b.marked    -column 1 -row 2 -sticky w
        grid $w.center.g1.a.b.selected  -column 1 -row 3 -sticky w
        grid $w.center.previewLabel     -column 1 -row 2 -sticky nw -pady 3
        grid $w.center.preview          -column 2 -row 2 -sticky nw -padx 1 -pady 3 -columnspan 2
        grid $w.center.npassLabel       -column 1 -row 3 -sticky nw -pady 3
        grid $w.center.npass            -column 2 -row 3 -sticky nw -padx 5 -pady 3 -columnspan 2
        grid $w.center.scanscoreLabel   -column 1 -row 4 -sticky nw -pady 3
        grid $w.center.scanscore        -column 2 -row 4 -sticky nw -padx 5 -pady 3 -columnspan 2
        grid $w.center.scanslideLabel   -column 1 -row 5 -sticky nw -pady 3
        grid $w.center.scanslide        -column 2 -row 5 -sticky nw -padx 5 -pady 3 -columnspan 2
        grid $w.center.slowscanLabel    -column 1 -row 6 -sticky nw -pady 3
        grid $w.center.slowscan         -column 2 -row 6 -sticky nw -padx 5 -pady 3 -columnspan 2

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -pady 5
        pack $w.bottom.buttons.defaults -side left -padx 5 -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Stamp::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::Stamp::finished"
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"
        
        # Destroy the dialog.
        destroyDialog        
        
        # Return the options.
        return [array get stampOptions]
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
        set width 369
        set height [expr 350+22]
        
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
        variable stampOptions
        variable showPreview
        variable alignmentType
        variable npass
        variable scan
        variable scanscore
        variable scanslide
        variable slowscan

        # Save the options.        
        set stampOptions(showPreview) $showPreview;
        set stampOptions(alignmentType) $alignmentType;
        if {[$w.center.npass curselection] != ""} {
            set npass [$w.center.npass get [$w.center.npass curselection]]
        }
        set stampOptions(npass) $npass;
        set stampOptions(scanscore) $scanscore;
        set stampOptions(scanslide) $scanslide;
        set stampOptions(slowscan) $slowscan;
        set stampOptions(scan) $scan;
        set stampOptions(scan) $scan;
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Close the window.    
        set finished 0
    }
    
    # Set the STAMP parameters to a default state
    proc but_defaults {} {
    
        # Import global variables.
        variable w
        variable npassDefault
        variable scanDefault
        variable scanscoreDefault
        variable scanslideDefault
        variable slowscanDefault
        variable npass
        variable scan
        variable scanscore
        variable scanslide
        variable slowscan
    
        # Set the variables to their default values.
        set npass $npassDefault
        set scan $scanDefault
        set scanscore $scanscoreDefault
        set scanslide $scanslideDefault
        set slowscan $slowscanDefault
        
        # Set any controls that do not automatically update themselves.
        $w.center.npass selection clear 0
        $w.center.npass selection set [expr $npass-1]
    }
}

