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
#       $RCSfile: select_residues.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.4 $       $Date: 2006/03/05 04:58:30 $
#
############################################################################

package provide multiseq 2.0

# Declare global variables for this package.
namespace eval ::MultiSeq::SelectResidues {

    # Export the package functions.
    namespace export showSelectResiduesDialog

    # Dialog management variables.
    variable w
    
    # The user's choices.
    variable choices
    array set choices {"selectionType" "all"
                       "identityOperator" ">="
                       "identity" ""
                       "qscoreOperator" ">="
                       "qscore" ""}
    
    # Creates a dialog to get the user's options for running the selection.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showSelectResiduesDialog {parent} {
    
        # Import global variables.
        variable w
        variable choices

        # If already initialized, just turn on
        if {[winfo exists ".selectresidues"] } {
          wm deiconify ".selectresidues"
          return
        }
    
        # Create a new top level window.
        set w [toplevel ".selectresidues"]
        wm title $w "Select Residues"
        
        # Create the components.
        frame $w.center
            label $w.center.choice -text "Select residues in:"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.all -text "All Sequences" -variable "::MultiSeq::SelectResidues::choices(selectionType)" -value "all"
                    radiobutton $w.center.g1.b.marked -text "Marked Sequences" -variable "::MultiSeq::SelectResidues::choices(selectionType)" -value "marked"
            label $w.center.identityLabel -text "Where Sequence Identity is "
            frame $w.center.id -relief sunken -borderwidth 1
                frame $w.center.id.b -relief raised -borderwidth 1
                    radiobutton $w.center.id.b.g -text ">=" -variable "::MultiSeq::SelectResidues::choices(identityOperator)" -value ">="
                    radiobutton $w.center.id.b.l -text "<=" -variable "::MultiSeq::SelectResidues::choices(identityOperator)" -value "<="
            entry $w.center.identity -text "" -width 6
            label $w.center.identityInstr -text "(0-100)"
            label $w.center.qscoreLabel -text "Where Qres is "
            frame $w.center.q -relief sunken -borderwidth 1
                frame $w.center.q.b -relief raised -borderwidth 1
                    radiobutton $w.center.q.b.g -text ">=" -variable "::MultiSeq::SelectResidues::choices(qscoreOperator)" -value ">="
                    radiobutton $w.center.q.b.l -text "<=" -variable "::MultiSeq::SelectResidues::choices(qscoreOperator)" -value "<="
            entry $w.center.qscore -text "" -width 6
            label $w.center.qscoreInstr -text "(0-1)"
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "Select" -pady 2 -command "::MultiSeq::SelectResidues::but_select"
                button $w.bottom.buttons.cancel -text "Close" -pady 2 -command "::MultiSeq::SelectResidues::but_close"
                bind $w <Return> {::MultiSeq::SelectResidues::but_select}
                bind $w <Escape> {::MultiSeq::SelectResidues::but_close}
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.choice           -column 1 -row 1 -sticky nw -pady 3
        grid $w.center.g1               -column 2 -row 1 -sticky nw -padx 1 -pady 3 -columnspan 3
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.all         -column 1 -row 1 -sticky w
        grid $w.center.g1.b.marked      -column 1 -row 2 -sticky w
        
        grid $w.center.identityLabel    -column 1 -row 2 -sticky w -pady 3
        grid $w.center.id               -column 2 -row 2 -sticky w -padx 1 -pady 3
        pack $w.center.id.b             -fill both -expand true -side left
        grid $w.center.id.b.g           -column 1 -row 1 -sticky w
        grid $w.center.id.b.l           -column 1 -row 2 -sticky w
        grid $w.center.identity         -column 3 -row 2 -sticky w -padx 1 -pady 3
        grid $w.center.identityInstr    -column 4 -row 2 -sticky w -padx 1 -pady 3
        
        grid $w.center.qscoreLabel      -column 1 -row 3 -sticky w -pady 3
        grid $w.center.q                -column 2 -row 3 -sticky w -padx 1 -pady 3
        pack $w.center.q.b              -fill both -expand true -side left
        grid $w.center.q.b.g            -column 1 -row 1 -sticky w
        grid $w.center.q.b.l            -column 1 -row 2 -sticky w
        grid $w.center.qscore           -column 3 -row 3 -sticky w -padx 1 -pady 3
        grid $w.center.qscoreInstr      -column 4 -row 3 -sticky w -padx 1 -pady 3

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -padx 5 -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::SelectResidues::but_close"}
        
        # Center the dialog.
        centerDialog $parent
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
    
    proc but_select {} {
    
        # Import global variables.
        variable w
        variable choices

        # Save the options.
        set choices(identity) [$w.center.identity get]
        set choices(qscore) [$w.center.qscore get]
        
        ::MultiSeq::selectResidues [array get choices]
    }
    
    proc but_close {} {
    
        # Import global variables.
        variable w
        
        destroy $w
    }

}

