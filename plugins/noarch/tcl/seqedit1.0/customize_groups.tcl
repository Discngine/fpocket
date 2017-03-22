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
#       $RCSfile: customize_groups.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.4 $       $Date: 2005/10/25 16:10:45 $
#
############################################################################

package provide seqedit 1.0

# Declare global variables for this package.
namespace eval SeqEdit::CustomizeGroups {

    # Export the package functions.
    namespace export showCustomizeGroupsDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # The new groups.
    variable newGroups {}
    
    # Variables used by the widgets.
    
    # Creates a dialog that allows the user to modify a listing of the groups that should appear in
    # the editor.
    # args:     groups - A list of the groups currently in the editor.
    # return:   A list of the groups that should be present in the editor.
    proc showCustomizeGroupsDialog {parent groups} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable newGroups
        set finished 0
        set newGroups {}
    
        # Create a new top level window.
        set w [createModalDialog ".customizegroups" "Customize Groups"]
        
        # Create the components.
        frame $w.center
            label $w.center.label -text "Groups"
            frame $w.center.g1 -relief sunken -borderwidth 1
                listbox $w.center.g1.groups -selectmode single -exportselection FALSE -height 15 -yscrollcommand "$w.center.g1.yscroll set"
                foreach groupName $groups {
                    $w.center.g1.groups insert end $groupName
                }
                scrollbar $w.center.g1.yscroll -command "$w.center.g1.groups yview"
                
            frame $w.center.controls
                button $w.center.controls.up -text "Move Up" -pady 2 -command "::SeqEdit::CustomizeGroups::but_up"
                button $w.center.controls.delete -text "Delete" -pady 2 -command "::SeqEdit::CustomizeGroups::but_delete"
                button $w.center.controls.down -text "Move Down" -pady 2 -command "::SeqEdit::CustomizeGroups::but_down"
            entry $w.center.name
            button $w.center.add -text "Add" -pady 2 -command "::SeqEdit::CustomizeGroups::but_add"
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::SeqEdit::CustomizeGroups::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::SeqEdit::CustomizeGroups::but_cancel"
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.label            -column 1 -row 1 -sticky w
        grid $w.center.g1               -column 1 -row 2 -sticky w -pady 4
        pack $w.center.g1.groups        -fill both -expand true -side left -fill x
        pack $w.center.g1.yscroll       -side right -fill y
        grid $w.center.controls         -column 2 -row 2 -sticky w
        pack $w.center.controls.up      -side top
        pack $w.center.controls.delete  -side top
        pack $w.center.controls.down    -side top
        grid $w.center.name             -column 1 -row 3 -sticky w
        grid $w.center.add              -column 2 -row 3 -sticky w
        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side right -padx 5 -pady 5


        

        
        # Bind the window closing event.
        bind $w <Destroy> {::SeqEdit::CustomizeGroups::but_cancel}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable ::SeqEdit::CustomizeGroups::finished
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"

        # Destroy the dialog.
        destroyDialog        
        
        # Return the groups.
        return $newGroups
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
        set width 263
        set height [expr 289+22]
        
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
        variable newGroups

        # Save the groups.        
        if {[$w.center.g1.groups size] > 0} {
            set newGroups [$w.center.g1.groups get 0 [expr [$w.center.g1.groups size]-1]]
        }
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Close the window.    
        set finished 0
    }
    
    
    # Adds a new group to the list.
    proc but_up {} {
        variable w
        set currentIndex [$w.center.g1.groups curselection]
        if {$currentIndex != "" && $currentIndex > 0} {
            set currentName [$w.center.g1.groups get $currentIndex]
            $w.center.g1.groups delete $currentIndex
            $w.center.g1.groups insert [expr $currentIndex-1] $currentName
            $w.center.g1.groups selection set [expr $currentIndex-1]
        }        
    }
        
    # Adds a new group to the list.
    proc but_delete {} {
        variable w
        set currentIndex [$w.center.g1.groups curselection]
        if {$currentIndex != ""} {
            $w.center.g1.groups delete $currentIndex
        }        
    }
        
    # Adds a new group to the list.
    proc but_down {} {
        variable w
        set currentIndex [$w.center.g1.groups curselection]
        if {$currentIndex != "" && $currentIndex < [expr [$w.center.g1.groups size]-1]} {
            set currentName [$w.center.g1.groups get $currentIndex]
            $w.center.g1.groups delete $currentIndex
            $w.center.g1.groups insert [expr $currentIndex+1] $currentName
            $w.center.g1.groups selection set [expr $currentIndex+1]
        }        
    }

    # Adds a new group to the list.
    proc but_add {} {
        variable w
        set newName [$w.center.name get]
        if {$newName != ""} {
            $w.center.g1.groups insert end $newName
            $w.center.name delete 0 [string length $newName]
        }
    }
}

