############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_nodeprops.tcl,v 1.4 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::NodeProperties {

    # Export the package functions.
    namespace export showNodePropertiesDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # Whether the info was changed.
    variable changed
    
    # The tree id.
    variable treeID
    
    # The node.
    variable node
    
    # Creates a dialog that allows the user to modify a listing of the groups that should appear in
    # the editor.
    # args:     groups - A list of the groups currently in the editor.
    # return:   The new name of the sequence if it was changed, otherwise an empty string.
    proc showNodePropertiesDialog {parent x y a_treeID a_node} {
    
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable changed
        variable treeID
        variable node
        set finished 0
        set changed 0
        set treeID $a_treeID
        set node $a_node
    
        # Create a new top level window.
        set w [createModalDialog ".nodeproperties" "Node Properties"]
        
        # Create the components.
        frame $w.center
            label $w.center.lname -text "Name:"
            entry $w.center.name -width 30
            $w.center.name insert 0 [::PhyloTree::Data::getNodeName $treeID $node]
            label $w.center.llabel -text "Label:"
            entry $w.center.label -width 30
            $w.center.label insert 0 [::PhyloTree::Data::getNodeLabel $treeID $node]
            
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::PhyloTree::NodeProperties::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::PhyloTree::NodeProperties::but_cancel"
                bind $w <Return> {::PhyloTree::NodeProperties::but_ok}
                bind $w <Escape> {::PhyloTree::NodeProperties::but_cancel}
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.lname            -column 1 -row 1 -sticky w
        grid $w.center.name             -column 2 -row 1 -sticky w
        grid $w.center.llabel           -column 1 -row 2 -sticky w
        grid $w.center.label            -column 2 -row 2 -sticky w
        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side right -padx 5 -pady 5
        
        # Bind the window closing event.
        bind $w <Destroy> {::PhyloTree::NodeProperties::but_cancel}
        
        # Place the dialog.
        placeDialog $parent $x $y
        
        # Wait for the user to interact with the dialog.
        tkwait variable ::PhyloTree::NodeProperties::finished
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"

        # Destroy the dialog.
        destroyDialog        
        
        # Return the groups.
        return $changed
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
    
    # Place the dialog.
    proc placeDialog {{parent ""} {x -1} {y -1}} {
        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 270
        set height [expr 90+22]
        
        set x [expr [winfo rootx $parent]+$x]
        set y [expr [winfo rooty $parent]+$y]
        
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
        variable changed
        variable treeID
        variable node
        
        # If we changed the name, save it.
        if {[$w.center.name get] != [::PhyloTree::Data::getNodeName $treeID $node]} {
            regsub -all {\s} [$w.center.name get] "_" s
            ::PhyloTree::Data::setNodeName $treeID $node $s
            set changed 1
        }

        # If we changed the name, save it.
        if {[$w.center.label get] != [::PhyloTree::Data::getNodeLabel $treeID $node]} {
            regsub -all {\s} [$w.center.label get] "_" s
            ::PhyloTree::Data::setNodeLabel $treeID $node $s
            set changed 1
        }

        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        variable finished
    
        # Close the window.    
        set finished 0
    }    
}

