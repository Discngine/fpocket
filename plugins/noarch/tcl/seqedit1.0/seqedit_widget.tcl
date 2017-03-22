############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reservedscr
#cr
############################################################################

package provide seqedit_widget 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEditWidget:: {
    
    # Export the package namespace.
    namespace export SeqEditWidget

    # Setup some default colors.
    variable headerColorActive "#D2D2D2"
    variable headerColorInactive "#D3D3D3"
    variable headerColorForeground "#000000"
    variable headerNumberingColor "#808080"
    variable cellColorActive "#FFFFFF"
    variable cellColorInactive "#C0C0C0"
    variable cellColorForeground "#000000"
    variable cellTextReplacementColor "#D3D3D3"
    variable selectionColor "#FFFF3E"
    variable checkColorActive "#000080"
    variable infobuttonColorActive "#005479"
    variable infobuttonFontColorActive "#FFFFFF"
    variable repbuttonColorActive "#005479"
    variable repbuttonFontColorActive "#FFFFFF"
    variable vmdbuttonColorActive "#D60811"
    variable vmdbuttonFontColorActive "#FFFFFF"
    
    # The name of the editor widget.
    variable widget
    
    # The name of the editor portion of the widget.
    variable editor
    
    # The status bar.
    variable statusBar
    
    # The group popup menu.
    variable groupPopupMenu

    # The representation popup menu.
    variable repPopupMenu
    
    # The vmd popup menu.
    variable vmdPopupMenu
    
    # Parameters for the popup menu.
    variable popupMenuParameters

    # The current width of the sequence
    variable width

    # Handle to the sequence editor window.
    variable height

    # The current width of a cell in the editor.
    variable cellWidth
    
    # The current height of a cell in the editor.
    variable cellHeight
    
    # The current width of a cell in the editor.
    variable headerCellWidth
    
    # The current height of a cell in the editor.
    variable headerCellHeight
    
    # The objects that make up the grid columns.
    variable columnObjectMap
    
    # The number of columns currently present in the editor.
    variable numberCols
    
    # The number of rows currently present in the editor.
    variable numberRows
    
    # The current groups in the editor.
    variable groupNames
    
    # The data for the groups.
    variable groupMap
    
    # The first sequence element being displayed.
    variable firstElement
    
    # The first group being displayed.
    variable firstGroup
    
    # The first sequence being displayed.
    variable firstSequence
    
    # The length of the longest sequence.
    variable numberElements
    
    # The current color map handler
    variable colorMapper
    
    # The current mapping of sequence elements to colors.
    variable coloringMap
    
    # The current mapping of sequence ids to representation.
    variable representationMap
  
    # The font being used for the header display.
    variable headerFont
  
    # The font being used for the cell display.
    variable cellFont
    
    # The width of a number in the current cell font.
    variable cellFontNumberWidth
  
    # The font being used for the group headings.
    variable groupHeaderFont
    
    # The font being used for the header buttons.
    variable buttonFont
  
    # The current mapping of marked sequences.
    variable markMap
    
    # The last clicked group.
    variable clickedGroup
    
    # The current sequence removal notification commands.
    variable sequenceRemovalNotificationCommands
        
    # The scale of the zoomed out image
    variable imageScale 1.0
    
    variable drawZoom 0
    
    # Scaled first column
    variable firstx 0
    
    variable lastx 0
    
    # Scaled first row
    variable firsty 0
    
    # Scaled last row
    variable lasty 0
    
    # Width of the zoomed window
    variable zoomWidth 0
    
    # Reset the package to get initial variable values.
    proc reset {} {
    
        # Reset the package variables.
        set ::SeqEditWidget::widget ""
        set ::SeqEditWidget::editor ""
        set ::SeqEditWidget::statusBar ""
        set ::SeqEditWidget::groupPopupMenu ""
        set ::SeqEditWidget::repPopupMenu ""
        set ::SeqEditWidget::vmdPopupMenu ""
        set ::SeqEditWidget::popupMenuParameters ""
        set ::SeqEditWidget::width 0
        set ::SeqEditWidget::height 0
        set ::SeqEditWidget::cellWidth 0
        set ::SeqEditWidget::cellHeight 0
        set ::SeqEditWidget::headerCellWidth 0
        set ::SeqEditWidget::headerCellHeight 0
        array set ::SeqEditWidget::columnObjectMap {}
        set ::SeqEditWidget::numberCols 0
        set ::SeqEditWidget::numberRows 0
        set ::SeqEditWidget::groupNames {}
        array set ::SeqEditWidget::groupMap {}
        set ::SeqEditWidget::firstElement 0
        set ::SeqEditWidget::firstGroup 0
        set ::SeqEditWidget::firstSequence -1
        set ::SeqEditWidget::numberElements 0
        set ::SeqEditWidget::colorMapper "::SeqEdit::ColorMap::Default::getColor"
        array set ::SeqEditWidget::coloringMap {}
        array set ::SeqEditWidget::representationMap {}
        set ::SeqEditWidget::headerFont ""
        set ::SeqEditWidget::cellFont ""
        set ::SeqEditWidget::cellFontNumberWidth 0
        set ::SeqEditWidget::groupHeaderFont ""
        set ::SeqEditWidget::buttonFont ""
        array set ::SeqEditWidget::markMap {}
        set ::SeqEditWidget::clickedGroup ""
        set ::SeqEditWidget::sequenceRemovalNotificationCommands {}
    }
    reset
}


############################## PUBLIC METHODS #################################
# Methods in this section can be called by external applications.             #
###############################################################################


# Creates a new sequence editor.
# args:     a_control - The frame that the widget should be shown in.
#           a_cellWidth - The width of a cell in the editor.
#           a_cellWidth - The height of a cell in the editor.
proc ::SeqEditWidget::createWidget {a_widget a_cellWidth a_cellHeight} {

    # Import global variables.
    variable widget
    variable editor
    variable groupPopupMenu
    variable repPopupMenu
    variable width
    variable height
    variable cellColorInactive
    set widget $a_widget
    
    #Create the components of the widget.
    frame $widget.center
    set editor [canvas $widget.center.editor -background $cellColorInactive]
    scrollbar $widget.center.yscroll -orient vertical -command {::SeqEditWidget::scroll_vertical}
    
    frame $widget.bottom
    scrollbar $widget.bottom.xscroll -orient horizontal -command {::SeqEditWidget::scroll_horzizontal}
    frame $widget.bottom.spacer -width [$widget.center.yscroll cget -width]
    set statusBar [label $widget.bottom.statusbar -textvariable "::SeqEditWidget::statusBarText" -anchor w -relief sunken -borderwidth 1]

    pack $widget.center -side top -fill both -expand true
    pack $widget.center.editor -side left -fill both -expand true
    pack $widget.center.yscroll -side right -fill y
    pack $widget.bottom -side bottom -fill x
    pack $widget.bottom.spacer -side right
    pack $widget.bottom.xscroll -side top -fill x -expand true
    pack $widget.bottom.statusbar -side bottom -fill x -expand true
    
    # Listen for resize events.
    bind $editor <Configure> {::SeqEditWidget::component_configured %W %w %h}
    
    # Calculate some basic information about the editor.
    set width [$editor cget -width]
    set height [$editor cget -height]
    
    # Set the cell size.
    setCellSize $a_cellWidth $a_cellHeight false

    # Set the scrollbars.
    setScrollbars
    
    # Create the grid.
    createCells
    
    # Create the group popup menu.
    set groupPopupMenu [menu $widget.groupPopupMenu -title "Grouping" -tearoff no]
    $groupPopupMenu add command -label "Insert Group..." -command "::SeqEditWidget::menu_insertgroup"
    $groupPopupMenu add command -label "Rename Group..." -command "::SeqEditWidget::menu_renamegroup"
    $groupPopupMenu add command -label "Delete Group" -command "::SeqEditWidget::menu_deletegroup"
    $groupPopupMenu add command -label "Add to Group..." -command "::SeqEditWidget::menu_addtogroup"
    $groupPopupMenu add separator
    $groupPopupMenu add command -label "Mark Group" -command "::SeqEditWidget::menu_markgroup 1"
    $groupPopupMenu add command -label "Unmark Group" -command "::SeqEditWidget::menu_markgroup 0"
    $groupPopupMenu add command -label "Mark All" -command "::SeqEditWidget::menu_markall 1"
    $groupPopupMenu add command -label "Unmark All" -command "::SeqEditWidget::menu_markall 0"
    
    # Create the representation popup menu.
    set repPopupMenu [menu $widget.repPopupMenu -title "Representation" -tearoff no]
    $repPopupMenu add command -label "Duplicate" -command "::SeqEditWidget::menu_duplicate"
    $repPopupMenu add separator
    $repPopupMenu add command -label "Sequence" -command "::SeqEditWidget::menu_setrepresentation sequence"
    $repPopupMenu add command -label "Bar" -command "::SeqEditWidget::menu_setrepresentation bar"
    $repPopupMenu add command -label "Secondary Structure" -command "::SeqEditWidget::menu_setrepresentation secondary"
    
    # set the key listener.
    bind $editor <KeyPress> {::SeqEditWidget::editor_keypress %K}
    bind $editor <<Cut>>  {::SeqEditWidget::editor_cut}
    bind $editor <<Copy>>  {::SeqEditWidget::editor_copy}
    bind $editor <<Paste>>  {::SeqEditWidget::editor_paste}
    focus $editor
    
    # Initialize the status bar.
    initializeStatusBar
}

# Adds a command to be run when sequences have been removed from the editor.
# args:     command - The command to be executed whenever sequences have been removed.
proc ::SeqEditWidget::addRemovalNotificationCommand {command} {
    
    # Import global variables.
    variable sequenceRemovalNotificationCommands
    
    lappend sequenceRemovalNotificationCommands $command
}    

# Creates a new sequence editor.
# args:     a_control - The frame that the widget should be shown in.
#           a_cellWidth - The width of a cell in the editor.
#           a_cellWidth - The height of a cell in the editor.
proc ::SeqEditWidget::setCellSize {a_cellWidth a_cellHeight {redraw true}} {

    # Import global variables.
    variable editor
    variable width
    variable height
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable numberCols
    variable numberRows
    variable headerFont
    variable cellFont
    variable cellFontNumberWidth
    variable groupHeaderFont
    variable buttonFont
    set cellWidth $a_cellWidth
    set cellHeight $a_cellHeight
    
    # Set up any settings that are based on the cell size.
    set headerCellWidth 200
    set headerCellHeight 18
    set numberCols [expr (($width-$headerCellWidth)/$cellWidth)+1]
    set numberRows [expr (($height-$headerCellHeight)/$cellHeight)+1]
    set fontChecker [$editor create text 0 0 -anchor nw -text ""]
    if {$headerFont != ""} {font delete $headerFont}
    if {$cellFont != ""} {font delete $cellFont}
    if {$groupHeaderFont != ""} {font delete $groupHeaderFont}
    if {$buttonFont != ""} {font delete $buttonFont}
    set defaultFont [$editor itemcget $fontChecker -font]
    set headerFont [font create headerFont -family [lindex $defaultFont 0] -size [lindex $defaultFont 1]]
    set buttonFont [font create buttonFont -family "courier" -size 10]
    if {$cellHeight >= 12 && $cellWidth >= 12} {
        set cellFont [font create cellFont -family [lindex $defaultFont 0] -size [expr ($cellHeight+3)/2]]
        set cellFontNumberWidth [font measure $cellFont "9"]
        set groupHeaderFont [font create groupHeaderFont -family [lindex $defaultFont 0] -size [expr ($cellHeight+3)/2] -weight bold]
    } else {
        set cellFont ""
        set cellFontNumberWidth 0
        set groupHeaderFont ""
    }
    $editor delete $fontChecker
    
    validateScrollRange
    
    # Redraw the component, if requested to.
    if {$redraw == 1 || $redraw == "true" || $redraw == "TRUE"} {
        deleteCells
        setScrollbars
        createCells
        redraw
    }
}

# Gets the length of the current alignment.
proc ::SeqEditWidget::getNumberPositions {} {
    
    # Import global variables.
    variable numberElements
    
    return $numberElements
}

# Gets the sequences that are currently being displayed by the editor.
proc ::SeqEditWidget::getSequences {} {

    # Import global variables.
    variable groupNames
    variable groupMap
    
    set sequenceIDs {}
    foreach groupName $groupNames {
        set groupSequenceIDs $groupMap($groupName,sequenceIDs)
        set sequenceIDs [concat $sequenceIDs $groupSequenceIDs]
    }
    return $sequenceIDs
}

proc ::SeqEditWidget::containsSequence {sequenceID} {
    
    # Import global variables.
    variable groupNames
    variable groupMap
    
    foreach groupName $groupNames {
        if {[lsearch $groupMap($groupName,sequenceIDs) $sequenceID] != -1} {
            return 1
        }
    }
    
    return 0
}

# Sets the sequences that are currently being displayed by the editor.
# args:     sequenceIDs - A list of the sequence ids.
#           groupName - The 
proc ::SeqEditWidget::setSequences {sequenceIDs {groupName ""}} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable firstElement
    variable firstGroup
    variable firstSequence
    variable numberElements
    
    # Reset all of the sequence storage variables.
    foreach groupName $groupNames {
        removeAllSequencesFromGroup $groupName
    }
    set numberElements 0
    set firstElement 0
    set firstGroup 0
    set firstSequence -1
    resetColoring all 0
    setRepresentations $sequenceIDs "sequence" 0
    
    # Add the sequences to the specified group.
    addSequences $sequenceIDs $groupName    
}

# Add the specified sequences to those that are currently being displayed by the editor.
# args:     sequenceIDs - A list of the sequence ids to add.
proc ::SeqEditWidget::addSequences {sequenceIDs {groupName ""} {position end} {redraw 1}} {

    # Import global variables.
    variable numberElements
    variable groupNames
    variable groupMap
    
    #Figure out if the max sequence length has increased.
    foreach sequenceID $sequenceIDs {
    
        #Get the sequence.
        set sequenceLength [SeqData::getSeqLength $sequenceID]
        
        #Compare the length to the max.
        if {$sequenceLength > $numberElements} {
            set numberElements $sequenceLength
        }
    }
    
    # If a group wasn't specified, use the first group.
    if {$groupName == ""} {
        set groupName [lindex $groupNames 0]
    }
    
    # If the group doesn't exists, create it.
    createGroup $groupName 0
    
    # If we are inserting at the end, translate to an integer.
    if {$position == "end"} {set position $groupMap($groupName,numberSequences)}
    
    # Add the sequences to the specified group.
    set groupMap($groupName,sequenceIDs) [concat [lrange $groupMap($groupName,sequenceIDs) 0 [expr $position-1]] $sequenceIDs [lrange $groupMap($groupName,sequenceIDs) $position end]]
    set groupMap($groupName,numberSequences) [llength $groupMap($groupName,sequenceIDs)]
    
    # Reset the coloring map for the new sequences.
    resetColoring $sequenceIDs 0
    setRepresentations $sequenceIDs "sequence" 0
    
    # Reset the mark and selection maps.
    resetMarks 1
    resetSelection

    # Set the scrollbars.
    setScrollbars

    #Redraw the widget.
    if {$redraw == 1} {redraw}
}

# Remove all of the sequences from a given group.
# args:     groupName - The index of the group from which to remove all of the sequences.
proc ::SeqEditWidget::removeAllSequences {{redraw 1}} {
    
    # Import global variables.
    variable groupNames
    variable firstElement
    variable firstGroup
    variable firstSequence
    variable numberElements
    
    # Reset all of the sequence storage variables.
    set groupNames {}
    array set groupMap {}
    set numberElements 0
    set firstElement 0
    set firstGroup 0
    set firstSequence -1
    resetColoring all 0
    
    #Redraw the widget.
    if {$redraw == 1} {redraw}
}

# Removes the specified sequences from the editor
# args: sequenceIDs - A list of sequence ids to be removed from the editor.
#       redraw - Whether to redraw the editor after removing the sequence. (0/1)
proc ::SeqEditWidget::removeSequences {sequenceIDs {redraw 1}} {
    
    # Import global variables.
    variable numberElements
    variable groupNames
    variable groupMap
    variable sequenceRemovalNotificationCommands

    # Go through each group and remove any sequences in the list.
    set recalculateNumberElements 0
    foreach groupName $groupNames {
        
        # If the group has any sequences.
        if {$groupMap($groupName,numberSequences) > 0 } {
                
            # Go through each sequence.
            foreach sequenceID $sequenceIDs {
                if {[set lidx [lsearch $groupMap($groupName,sequenceIDs) $sequenceID]] != -1 } {
                            
                    # Remove each one from the list and decrement the sequence counter for the group.
                    set groupMap($groupName,sequenceIDs) [lreplace $groupMap($groupName,sequenceIDs) $lidx $lidx]
                    incr groupMap($groupName,numberSequences) -1
                            
                    # If this sequence was the longest one in the editor, mark that we need to recalculate the max.
                    if {[SeqData::getSeqLength $sequenceID] == $numberElements} {
                        set recalculateNumberElements 1
                    }
                }
            }
        }
    }
    
    #Figure out the new maximum sequence length, if necessary.
    if {$recalculateNumberElements == 1} {
        set numberElements 0
        foreach groupName $groupNames {
            set groupSequenceIDs $groupMap($groupName,sequenceIDs)
            foreach groupSequenceID $groupSequenceIDs {
                set sequenceLength [SeqData::getSeqLength $groupSequenceID]
                if {$sequenceLength > $numberElements} {
                    set numberElements $sequenceLength
                }
            }
        }
    }
    
    # Reset the mark and selection maps.
    resetMarks 1
    resetSelection
    
    # Set the scrollbars.
    setScrollbars

    if {$redraw == 1} {redraw}
    
    # Notify any listeners.
    foreach sequenceRemovalNotificationCommand $sequenceRemovalNotificationCommands {
        $sequenceRemovalNotificationCommand $sequenceIDs
    }
}

# Updates the specified sequences in the editor.
proc ::SeqEditWidget::updateSequences {sequenceIDs} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable numberElements
    variable markMap

    # Go through each of the new sequences.
    foreach sequenceID $sequenceIDs {
    
        # Figure out if the max sequence length has increased.
        if {[SeqData::getSeqLength $sequenceID] > $numberElements} {
            set numberElements [SeqData::getSeqLength $sequenceID]
        }
    }
    
    # Reset the coloring map for the new sequences.
    resetColoring $sequenceIDs 0
    
    # Reset the mark and selection maps.
    resetMarks 1
    resetSelection
    
    # Set the scrollbars.
    setScrollbars
    
    #Redraw the widget.
    redraw
}

proc ::SeqEditWidget::duplicateSequences {sequenceIDs {redraw 1}} {
    
    # Import global variables.
    variable numberElements
    variable groupNames
    variable groupMap
    
    # Go through each sequence.
    foreach sequenceID $sequenceIDs {
        
        # Create a copy of the sequence.
        set newSequenceID [::SeqData::duplicateSequence $sequenceID]

        # Find the group and position of the original sequence.
        set addGroupName ""
        set addGroupPosition -1
        foreach groupName $groupNames {
            set position [lsearch $groupMap($groupName,sequenceIDs) $sequenceID]
            if {$position != -1} {
                set addGroupName $groupName
                set addGroupPosition [expr $position+1]
                break
            }
        }
        
        # If we found the source sequence, add the new one right after it.
        if {$addGroupName != "" && $addGroupPosition != -1}  {
            
            # Add the sequences to the specified group.
            set groupMap($addGroupName,sequenceIDs) [concat [lrange $groupMap($addGroupName,sequenceIDs) 0 [expr $addGroupPosition-1]] $newSequenceID [lrange $groupMap($addGroupName,sequenceIDs) $addGroupPosition end]]
            set groupMap($addGroupName,numberSequences) [llength $groupMap($addGroupName,sequenceIDs)]            
        }
        
        # Reset the coloring map for the new sequence.
        resetColoring $newSequenceID 0
        setRepresentations $newSequenceID [getRepresentations $sequenceID] 0
    }
    
    # Reset the mark and selection maps.
    resetMarks 1
    resetSelection

    # Set the scrollbars.
    setScrollbars

    #Redraw the widget.
    if {$redraw == 1} {redraw}
}

# Replaces each sequence in the first list with the corresponding sequence in the second list.
# args:     originalSequenceIDs - The sequences to be replaced.
#           replacementSequenceIDs - The new sequences.
proc ::SeqEditWidget::replaceSequences {originalSequenceIDs replacementSequenceIDs} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable numberElements
    variable markMap

    # Go through each of the new sequences.
    for {set i 0} {$i < [llength $replacementSequenceIDs]} {incr i} {
    
        # Get the sequence.
        set sequenceID [lindex $replacementSequenceIDs $i]
        set sequence [SeqData::getSeq $sequenceID]
        
        # Figure out if the max sequence length has increased.
        if {[llength $sequence] > $numberElements} {
            set numberElements [llength $sequence]
        }
        
        # See if we can find this sequence's old identity.
        if {$i < [llength $originalSequenceIDs]} {
            
            # Get the id of the old sequence.
            set oldSequenceID [lindex $originalSequenceIDs $i]
            
            # Go through the groups and replace any occurrences of the old id with the new one.
            foreach groupName $groupNames {
                
                # Get the sequence ids.
                set groupSequenceIDs $groupMap($groupName,sequenceIDs)
                
                # See if the old sequence id is in the list.
                set position [lsearch $groupSequenceIDs $oldSequenceID]
                if {$position != -1} {
                    set groupMap($groupName,sequenceIDs) [lreplace $groupSequenceIDs $position $position $sequenceID]
                }
            }
            
            # Preserve the mark state of the old sequence.
            set markMap($sequenceID) $markMap($oldSequenceID)
        
        # Otherwise, just add the it to the first group.
        } else {
            addSequences $sequenceID [lindex $groupNames 0] 
        }
    
    }
    
    # Reset the coloring map for the new sequences.
    resetColoring $replacementSequenceIDs 0
    setRepresentations $replacementSequenceIDs [getRepresentations $originalSequenceIDs] 0
    
    # Reset the mark and selection maps.
    resetMarks 1
    resetSelection
    
    # Set the scrollbars.
    setScrollbars
    
    #Redraw the widget.
    redraw
}

# Moves a list of sequences ids from their existing locations into the specified group,
# optionally at a specified position.
# args:     groupName - The group to which to add the sequences.
#           movingSequenceIDs - The list of sequences ids to move to the group.
#           position - (default end) If the list should be added at a specific position in
#               the group, specify it here. An empty string signifies the end of the list.
proc ::SeqEditWidget::moveSequences {movingSequenceIDs moveToGroupName {position end} {redraw 1}} {

    # Import global variables.
    variable groupMap
    variable groupNames

    # Create the group, if it does not exist.
    createGroup $moveToGroupName 0
    
    # Figure out the default position, if necessary.
    if {$position == "end"} {set position $groupMap($moveToGroupName,numberSequences)}
    
    # Go through all of the groups.
    foreach groupName $groupNames {
    
        # Go through all of the sequence ids in the group and create a new list without the moving elements.
        set sequenceIDs $groupMap($groupName,sequenceIDs)
        set newSequenceIDs {}
        for {set j 0} {$j < [llength $sequenceIDs]} {incr j} {
                    
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $j]

            # Add the sequence id to the new list if it is not in the moving list.
            if {[lsearch $movingSequenceIDs $sequenceID] == -1} {
                lappend newSequenceIDs $sequenceID
                
            # Otherwise, see if we need to adjust the position to account for removing this sequence id.
            } elseif {$groupName == $moveToGroupName && $j < $position} {
                incr position -1
            }
        }
        
        # Set the new list for the group.
        set groupMap($groupName,sequenceIDs) $newSequenceIDs
        set groupMap($groupName,numberSequences) [llength $newSequenceIDs]
    }
    
    # Add the sequences to the specified group.
    set groupMap($moveToGroupName,sequenceIDs) [concat [lrange $groupMap($moveToGroupName,sequenceIDs) 0 [expr $position-1]] $movingSequenceIDs [lrange $groupMap($moveToGroupName,sequenceIDs) $position end]]
    set groupMap($moveToGroupName,numberSequences) [llength $groupMap($moveToGroupName,sequenceIDs)]
    
    if {$redraw == 1} {redraw}
}

# Creates a new group and returns its index. If a group with the name already exists,
# the index of the existing group is returned.
# args:     groupName - The name of the group to create.
# return:   The index of the newly created group.
proc ::SeqEditWidget::createGroup {groupName {redraw 1}} {
    
    # Import global variables.
    variable groupNames
    
    return [insertGroup $groupName end $redraw]
}

# Renames a group. If a group with the name already exists, nothing is done.
# args:     groupName - The old name of the group.
#           newName - The new name of the group.
proc ::SeqEditWidget::renameGroup {groupName newName {redraw 1}} {
    
    # Import global variables.
    variable groupNames
    variable groupMap

    # Rename the group if it exists and the new name des not.
    if {[lsearch $groupNames $groupName] != -1 && [lsearch $groupNames $newName] == -1} {
        set groupIndex [lsearch $groupNames $groupName]
        set groupNames [lreplace $groupNames $groupIndex $groupIndex $newName]
        set groupMap($newName,sequenceIDs) $groupMap($groupName,sequenceIDs)
        set groupMap($newName,numberSequences) $groupMap($groupName,numberSequences)
        unset groupMap($groupName,sequenceIDs)
        unset groupMap($groupName,numberSequences)
        if {$redraw == 1} {redraw}
    }
}

# Inserts a new group at the specified position. If a group with the name already exists,
# the index of the existing group is returned.
# args:     groupName - The name of the group to create.
#           position - The position at which the group should be created.
proc ::SeqEditWidget::insertGroup {groupName {position end} {redraw 1}} {
    
    # Import global variables.
    variable groupNames
    variable groupMap

    # Add the group if it does not yet exist.
    set index [lsearch $groupNames $groupName]
    if {$index == -1} {
        set groupNames [linsert $groupNames $position $groupName]
        set groupMap($groupName,sequenceIDs) {}
        set groupMap($groupName,numberSequences) 0
        set index $position
        if {$redraw == 1} {redraw}
    }
}

# Delete the specified group. All of the groups sequences will be placed in the previous group.
# args:     groupName - The name of the group to delete.
proc ::SeqEditWidget::deleteGroup {groupName {redraw 1}} {
    
    # Import global variables.
    variable groupNames
    variable groupMap
    
    # Find the group in the list.    
    set index [lsearch $groupNames $groupName]
    if {$index != -1 && [llength $groupNames] > 1} {
        
        if {$index > 0} {
            
            # Figure out the previous group.
            set previousGroup [lindex $groupNames [expr $index-1]]
            
            # Remove this group from the list.
            set groupNames [lreplace $groupNames $index $index]
            
            # Append this group's sequences to the end of the previous group.
            set groupMap($previousGroup,sequenceIDs) [concat $groupMap($previousGroup,sequenceIDs) $groupMap($groupName,sequenceIDs)]
            set groupMap($previousGroup,numberSequences) [llength $groupMap($previousGroup,sequenceIDs)]
            
            # Remove the sequences from this group.
            unset groupMap($groupName,sequenceIDs)
            unset groupMap($groupName,numberSequences)
            
        } else {
            
            # Figure out the next group.
            set nextGroup [lindex $groupNames [expr $index+1]]
            
            # Remove this group from the list.
            set groupNames [lreplace $groupNames $index $index]
            
            # Append this group's sequences to the beginning of the next group.
            set groupMap($nextGroup,sequenceIDs) [concat $groupMap($groupName,sequenceIDs) $groupMap($nextGroup,sequenceIDs)]
            set groupMap($nextGroup,numberSequences) [llength $groupMap($nextGroup,sequenceIDs)]
            
            # Remove the sequences from this group.
            unset groupMap($groupName,sequenceIDs)
            unset groupMap($groupName,numberSequences)
        }
        
        if {$redraw == 1} {redraw}
    }
}

# Sets the groups that are currently in the editor. Sequences that are in a group whose name matches
# the name of a new group, will be put into that group. All other sequences will be put into the first
# group.
# args:     newGroupNames - A list of the new group names.
proc ::SeqEditWidget::setGroups {newGroupNames {redraw 1} {defaultGroupName ""}} {
    
    # Import global variables.
    variable groupNames
    variable groupMap
    
    # Get the initial sequences in the new first group.
    if {$defaultGroupName == ""} {
        set defaultGroupName [lindex $newGroupNames 0]
    }
    set defaultGroupSequenceIDs {}
    
    # Go through the existing groups and if they do not have a match, move the sequences to the new first group.
    foreach groupName $groupNames {
        
        # See if this group has no match or it is the new first group.
        if {[lsearch $newGroupNames $groupName] == -1 || $groupName == $defaultGroupName} {
            
            # Add the sequences to the new first group.
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            set numberSequences $groupMap($groupName,numberSequences)
            foreach sequenceID $sequenceIDs {
                lappend defaultGroupSequenceIDs $sequenceID
            }
            
            # Zero out the old group.
            set groupMap($groupName,sequenceIDs) {}
            set groupMap($groupName,numberSequences) 0
        }
    }
    
    # Set the new first group.
    set groupMap($defaultGroupName,sequenceIDs) $defaultGroupSequenceIDs
    set groupMap($defaultGroupName,numberSequences) [llength $defaultGroupSequenceIDs]
    
    # Set the new group name list.
    set groupNames $newGroupNames
    
    # Create any new groups that do not yet exist.
    foreach groupName $groupNames {
        if {[info exists groupMap($groupName,sequenceIDs)] == 0} {
            set groupMap($groupName,sequenceIDs) {}
            set groupMap($groupName,numberSequences) 0
        }
    }
    
    # Redraw the editor, if we were supposed to.
    if {$redraw == 1} {redraw}
}

# Gets a list of the current group names.
# return:   A list of the groups currently in the editor.
proc ::SeqEditWidget::getGroups {} {

    # Import global variables.
    variable groupNames
    
    return $groupNames
}

# Gets the group name that the specified sequence is currently a member of.
# arguments: seqId - sequence to find
# return: group name of the group containing the sequence, or "" if it was not found.
proc ::SeqEditWidget::getGroup {sequenceId} {
    
    # Import global variables.
    variable groupMap
    variable firstGroup
    variable groupNames

    foreach groupName $groupNames {
        if {[lsearch $groupMap($groupName,sequenceIDs) $sequenceId] != -1} {
            return $groupName
        }
    }
    
    return "Unknown"
}

# Gets all of the sequence ids of the sequences that are in the specified group.
# args:     groupName - The name of the group.
# return:   The sequence ids that is at the position.
proc ::SeqEditWidget::getSequencesInGroup {groupName} {

    # Import global variables.
    variable groupNames
    variable groupMap
    
    return $groupMap($groupName,sequenceIDs)
}

# Gets the sequence id of the sequence that is at the specified index of the specified group.
# args:     groupName - The name of the group.
#           sequenceIndex - The index of the sequence.
# return:   The sequence id that is at the position.
proc ::SeqEditWidget::getSequenceInGroup {groupName sequenceIndex} {

    # Import global variables.
    variable groupNames
    variable groupMap
    
    return [lindex $groupMap($groupName,sequenceIDs) $sequenceIndex]
}

# Gets the sequence ids that are contained in the specified range of grouped sequences.
# args:     startGroupIndex - The index of the starting group.
#           startSequenceIndex - The index of the starting sequence in the starting group.
#           endGroupIndex - The index of the ending sequence in the starting group.
#           endSequenceIndex - The index of the ending sequence in the starting group.
# return:   A list of the sequence ids that are in the specified range.
proc ::SeqEditWidget::getSequencesInGroups {startGroupIndex startSequenceIndex endGroupIndex endSequenceIndex} {

    # Import global variables.
    variable groupNames
    variable groupMap
    
    # If the indexes are out of order, reverse them.
    if {$startGroupIndex > $endGroupIndex || ($startGroupIndex == $endGroupIndex && $startSequenceIndex > $endSequenceIndex)} {
        set temp $startGroupIndex
        set startGroupIndex $endGroupIndex
        set endGroupIndex $temp
        set temp $startSequenceIndex
        set startSequenceIndex $endSequenceIndex
        set endSequenceIndex $temp
    }

    # Go through the groups and get the sequence ids.
    set returningSequenceIDs {}
    for {set i $startGroupIndex} {$i <= $endGroupIndex} {incr i} {
    
        set sequenceIDs $groupMap([lindex $groupNames $i],sequenceIDs)
    
        set first 0
        if {$i == $startGroupIndex} {set first $startSequenceIndex}
        set last [expr [llength $sequenceIDs]-1]
        if {$i == $endGroupIndex} {set last $endSequenceIndex}
        
        for {set j $first} {$j <= $last} {incr j} {
            lappend returningSequenceIDs [lindex $sequenceIDs $j]
        }
    }
    
    return $returningSequenceIDs
}

# Get the index of a group given its name.
# args:     groupName - The name of the group for which to retrieve the index.
# return:   The index of the group or -1 if it was not found.
proc ::SeqEditWidget::getGroupIndex {groupName} {
    
    # Import global variables.
    variable groupNames

    return [lsearch $groupNames $groupName]
}

# Remove all of the sequences from a given group.
# args:     groupName - The index of the group from which to remove all of the sequences.
proc ::SeqEditWidget::removeAllSequencesFromGroup {groupName} {
    
    # Import global variables.
    variable groupMap

    set groupMap($groupName,sequenceIDs) {}
    set groupMap($groupName,numberSequences) 0
}

# Resets the editor selection so that nothing is selected.
proc ::SeqEditWidget::resetMarks {{preserveMarks 0}} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable markMap
    
    # Go through each group and create or update entries for its sequences.
    foreach groupName $groupNames {
        set sequenceIDs $groupMap($groupName,sequenceIDs)
        foreach sequenceID $sequenceIDs {
            if {[info exists markMap($sequenceID)] == 0 || $preserveMarks == 0} {
                set markMap($sequenceID) 0
            } else {
            }
        }
    }
}

# Gets the currently marked sequences.
# return:   A list of the sequence ids that are currently marked.
proc ::SeqEditWidget::getMarkedSequences {} {
    
    # Import global variables.
    variable groupNames
    variable groupMap
    variable markMap
    
    # Go through the selection list and get all of the currently selected sequence ids.
    set markedSequenceIDs {}
    foreach groupName $groupNames {
        set sequenceIDs $groupMap($groupName,sequenceIDs)
        foreach sequenceID $sequenceIDs {
            if {$markMap($sequenceID) == 1} {
                lappend markedSequenceIDs $sequenceID
            }
        }
    }
        
        return $markedSequenceIDs
}

# Set the passed in sequences ids to the specified mark state.
# args:     sequenceIDs - The list of sequence ids that should be marked.
proc ::SeqEditWidget::setMarksOnSequences {sequenceIDs {value 1}} {

    # Import global variables.
    variable markMap
    
    # Initialize the list of sequences to redraw.
    set sequenceIDsToRedraw {}
    
    # Mark the sequence as selected in the mark map.
    foreach sequenceID $sequenceIDs {
        set markMap($sequenceID) $value
        lappend sequenceIDsToRedraw $sequenceID
    }
    
    # Show the selection changes.
    redraw $sequenceIDsToRedraw
}

# Gets the color mapper used by the editor to map metrics to a color.
# return:   The current color map handler.
proc ::SeqEditWidget::getColorMapper {} {

    # Import global variables.
    variable colorMapper
    
    return $colorMapper
}

# Sets the color mapper used by the editor to map metrics to a color.
# args:     newColorMapper - The new color mapper.
proc ::SeqEditWidget::setColorMapper {newColorMapper} {

    # Import global variables.
    variable coloringMap
    variable colorMapper
    set colorMapper $newColorMapper
    
    # Recalculate the color mappings for each sequences.
    foreach sequenceID [getSequences] {
        
        # See if this sequence has been colored yet.
        if {$coloringMap($sequenceID,used)} {
            
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            for {set i 0} {$i < [llength $sequence]} {incr i} {
                
                # Remap the coloring for this elements.
                set coloringMap($sequenceID,$i,rgb) [$colorMapper $coloringMap($sequenceID,$i,raw)]
            }
        }
    }

    # Redraw the widget.
    redraw
}

# This method resets the coloring of the specified sequences. It can also be used to initialize the
# coloring map for new sequences.
# args:     sequenceIDs - The sequences to reset or all to reset every sequence in the editor.
proc ::SeqEditWidget::resetColoring {{sequenceIDs "all"} {redraw 1}} {
    
    # Import global variables.
    variable coloringMap
    variable colorMapper
    
    # If we are resetting everything, delete the array first.
    if {$sequenceIDs == "all"} {
        
        # Delete the array.
        unset coloringMap
        array set coloringMap {}
        
        # Reset all of the sequences in the editor.
        set sequenceIDs [getSequences]
    }
    
    # Reset the coloring of the specified sequences.
    foreach sequenceID $sequenceIDs {
        
        # Mark that this sequence has not yet been colored.
        set coloringMap($sequenceID,used) 0
        
        # Get the sequence.
        set sequence [SeqData::getSeq $sequenceID]
        
        # Go through each element in the sequence.
        for {set i 0} {$i < [llength $sequence]} {incr i} {
            
            # Set the color map entry for this element.
            set coloringMap($sequenceID,$i,raw) 0.0
            set coloringMap($sequenceID,$i,rgb) "#FFFFFF"
        }
    }
    
    if {$redraw == 1} {redraw $sequenceIDs}
}

# Gets the current coloring of the sequences.
# return:   The current cooring map.
proc ::SeqEditWidget::getColoring {} {

    # Import global variables.
    variable coloringMap
    
    return [array get coloringMap]
}
    
# Sets the coloring of the specified sequences using the specified coloringMetric.
# args:     coloringMetric - The metric to use for the calculation.
#           sequenceIDs - The sequence ids of which to set the coloring.
#           colorByGroup - 1 if the coloring metric should be run per group, otherwise 0.
proc ::SeqEditWidget::setColoring {coloringMetric {sequenceIDs "all"} {colorByGroup 0} {redraw 1}} {

    # Import global variables.
    variable groupNames
    variable colorMapper
    variable coloringMap

    if {$coloringMetric != ""} {
            
        # If we are coloring everything, get the ids.
        if {$sequenceIDs == "all"} {
            set sequenceIDs [getSequences]
        }
        
        # If we are coloring by group, process one group at a time.
        if {$colorByGroup} {
            
            # Go through each group.
            foreach groupName $groupNames {
                
                # Get the subset of the passed in sequences that are in this group.
                set metricSequenceIDs {}
                set groupSequenceIDs [::SeqEditWidget::getSequencesInGroup $groupName]
                foreach sequenceID $sequenceIDs {
                    if {[lsearch $groupSequenceIDs $sequenceID] != -1} {
                        lappend metricSequenceIDs $sequenceID
                    }
                }
                
                # Process this set.
                setColoring $coloringMetric $metricSequenceIDs 0 0
            }
            
        # Otherwise, process all of the sequences.
        } else {

            # Get the coloring metrics for the sequences.
            array set coloringMetricMap [$coloringMetric $sequenceIDs]
            
            # Copy the coloring metrics into the coloring map.
            set coloringMetricKeys [array names coloringMetricMap]
            foreach coloringMetricKey $coloringMetricKeys {
                set coloringMap($coloringMetricKey,raw) $coloringMetricMap($coloringMetricKey)
                set coloringMap($coloringMetricKey,rgb) [$colorMapper $coloringMetricMap($coloringMetricKey)]
            }

        }
        
        # Mark that coloring has been set for all of the sequences.
        foreach sequenceID $sequenceIDs {
            set coloringMap($sequenceID,used) 1
        }
    
        if {$redraw == 1} {redraw $sequenceIDs}
    }
}

proc ::SeqEditWidget::getRepresentations {sequenceIDs} {
    
    # Import global variables.
    variable representationMap

    # Go through each sequence id and add its representation to the list.
    set ret {}
    foreach sequenceID $sequenceIDs {
        lappend ret $representationMap($sequenceID)
    }
    
    return $ret
}

proc ::SeqEditWidget::setRepresentations {sequenceIDs representations {redraw 1}} {
    
    # Import global variables.
    variable representationMap

    # Make sure we have a valid representation list.
    if {[llength $representations] == 1 || [llength $representations] == [llength $sequenceIDs]} {
        
        # Go through each sequence id and set its representation.
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
            set sequenceID [lindex $sequenceIDs $i]
            if {[llength $representations] == 1} {
                set representationMap($sequenceID) [lindex $representations 0]
            } else {
                set representationMap($sequenceID) [lindex $representations $i]
            }
        }
    }
    
    if {$redraw == 1} {redraw $sequenceIDs}
}




############################# PRIVATE METHODS #################################
# Methods in this section should only be called from this file.               #
###############################################################################


proc ::SeqEditWidget::validateScrollRange {{checkHorizontal 1} {checkVertical 1}} {
    
    # Import global variables.
    variable numberCols
    variable numberRows
    variable groupNames
    variable groupMap
    variable firstElement
    variable numberElements
    variable firstGroup
    variable firstSequence  

    # Check the horizontal scroll range.
    if {$checkHorizontal == 1} {
        if {$numberElements > $numberCols} {
            if {$firstElement > ($numberElements-$numberCols+1)} {
                set firstElement [expr $numberElements-$numberCols+1]
            } elseif {$firstElement < 0} {
                set firstElement 0
            }
        } else {
            set firstElement 0
        }
    }
    
    # Check the vertical scroll range.
    if {$checkVertical == 1} {
        # Figure out what the maximum values are for the first group and first sequence.
        set maxGroup 0
        set maxSequence -1
        set range [expr $numberRows-1]
        for {set i [expr [llength $groupNames]-1]} {$i >= 0} {incr i -1} {
        
            set numberSequences $groupMap([lindex $groupNames $i],numberSequences)
            
            # See if the sequences from this group fit.
            if {$range <= $numberSequences} {
                set maxGroup $i
                set maxSequence [expr $numberSequences-$range]
                break;
            }
            incr range -$numberSequences
            
            # See if the title row for this group fits.
            if {$range == 1} {
                set maxGroup $i
                set maxSequence -1
                break;
            }
            incr range -1
        }
        
        # If the group and sequence are past the limit, set them to the limit.
        if {$firstGroup == $maxGroup} {
            if {$firstSequence > $maxSequence} {
                set firstSequence $maxSequence
            }
        } elseif {$firstGroup > $maxGroup} {
            set firstGroup $maxGroup
            set firstSequence $maxSequence
        }
    }
}

# Sets the scroll bars.
proc ::SeqEditWidget::setScrollbars {} {

    # Import global variables.
    variable widget
    variable groupNames
    variable groupMap
    variable firstElement
    variable firstGroup
    variable firstSequence
    variable numberCols
    variable numberRows
    variable numberElements
    
    # Set the scroll bars.
    if {$numberElements > $numberCols} {
        $widget.bottom.xscroll set [expr $firstElement/($numberElements.0+1.0)] [expr ($firstElement+$numberCols)/($numberElements.0+1.0)]
    } else {
        $widget.bottom.xscroll set 0 1
    }
    


    #
    set currentLine 0
    set maxLines 0
    set numberGroups [expr [llength $groupNames]]
    for {set i 0} {$i < $numberGroups} {incr i} {
    
        # Get the number of sequences in this group.
        set numberSequences $groupMap([lindex $groupNames $i],numberSequences)
        
        # Increment the max totals.
        incr maxLines 1
        incr maxLines $numberSequences
        
        # If we have not yet reached the current group, increment the current totals.
        if {$i < $firstGroup} {
            incr currentLine 1
            incr currentLine $numberSequences
        } elseif {$i == $firstGroup} {
            incr currentLine [expr $firstSequence+1]
        }
    }
    
    if {$maxLines >= $numberRows} {
        $widget.center.yscroll set [expr $currentLine/double($maxLines+1)] [expr ($currentLine+$numberRows)/double($maxLines+1)]
    } else {
        $widget.center.yscroll set 0 1
    }
    catch {
	    #drawImage
	    drawBox
    } drawImageErr
    #puts "Multiseq Zoom) Error in drawbox in setScrollbars: $drawImageErr"
}

# Creates a new grid of cells in the editor
proc ::SeqEditWidget::createCells {} {
    
    # Import global variables.
    variable editor
    variable numberCols

    # Create all of the columns for the editor
    createHeaderColumn
    for {set i 0} {$i < $numberCols} {incr i} {
        createColumn $i
    }
}

# Creates a new header column in the editor.
proc ::SeqEditWidget::createHeaderColumn {} {

    # Import global variables.
    variable editor
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable columnObjectMap
    variable numberRows
    variable headerColorActive
    variable headerColorForeground
    variable cellColorInactive
    variable cellColorActive
    variable cellColorForeground
    variable headerNumberingColor
    variable checkColorActive
    variable infobuttonColorActive
    variable infobuttonFontColorActive
    variable repbuttonColorActive
    variable repbuttonFontColorActive
    variable vmdbuttonColorActive
    variable vmdbuttonFontColorActive
    variable headerFont
    variable cellFont
    variable cellFontNumberWidth
    variable buttonFont
    
    # Set the starting location.
    set x 4
    set y 2
    
    # Create the header cell.
    set cellx1 $x
    set cellx2 [expr $headerCellWidth]
    set cellxc [expr $cellx1+(($cellx2-$cellx1)/2)]
    set celly1 $y
    set celly2 [expr $headerCellHeight-2]
    set cellyc [expr $celly1+(($celly2-$celly1)/2)]
    set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $headerColorActive -outline $headerColorActive]
    set textid [$editor create text $cellx1 $cellyc -font $headerFont -anchor w -text "Sequence Name"]
    
    # Create the separator and tick lines.
    set separatorid [$editor create line $cellx1 [expr $celly2+1] [expr $cellx2+1] [expr $celly2+1] -fill $headerColorForeground]
    set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] [expr $celly2+1] -fill $headerColorForeground]
        
    # Store the header cell objects.
    set columnObjectMap(h,h.boxid) $boxid
    set columnObjectMap(h,h.textid) $textid    
    set columnObjectMap(h,h.separatorid) $separatorid    
    set columnObjectMap(h,h.tickid) $tickid
    
    # Go through each row and create its row header.
    set y $headerCellHeight
    for {set row 0} {$row < $numberRows} {incr row} {
    
        # Create the cell for this row.
        set celly1 $y
        set celly2 [expr $celly1+$cellHeight-1]
        set cellyc [expr $celly1+(($celly2-$celly1)/2)]
        set columnObjectMap(h,$row.x1) $cellx1
        set columnObjectMap(h,$row.x2) $cellx2
        set columnObjectMap(h,$row.y1) $celly1
        set columnObjectMap(h,$row.y2) $celly2
        
        # Create the checkbox.
        if {[expr $celly2-$celly1-5] < 10} {
            set checkboxSize [expr $celly2-$celly1-5]
            set checkboxx1 [expr $cellx1+2]
            set checkboxy1 [expr $celly1+2]
            set checkboxx2 [expr $checkboxx1+$checkboxSize]
            set checkboxy2 [expr $checkboxy1+$checkboxSize]
            set checkboxid [$editor create rectangle $checkboxx1 $checkboxy1 $checkboxx2 $checkboxy2 -fill $cellColorActive -outline $cellColorForeground]
            set checkid [$editor create rectangle [expr $checkboxx1+1] [expr $checkboxy1+1] [expr $checkboxx2-1] [expr $checkboxy2-1] -fill $checkColorActive -outline $checkColorActive]
        } else {
            set checkboxSize 10
            set checkboxx1 [expr $cellx1+2]
            set checkboxy1 [expr $cellyc-5]
            set checkboxx2 [expr $checkboxx1+$checkboxSize]
            set checkboxy2 [expr $checkboxy1+$checkboxSize]
            set checkboxid [$editor create rectangle $checkboxx1 $checkboxy1 $checkboxx2 $checkboxy2 -fill $cellColorActive -outline $cellColorForeground]
            set checkid [$editor create polygon [expr $checkboxx1+2] [expr $checkboxy1+4] [expr $checkboxx1+4] [expr $checkboxy1+6] [expr $checkboxx1+8] [expr $checkboxy1+2]  [expr $checkboxx1+8] [expr $checkboxy1+4] [expr $checkboxx1+4] [expr $checkboxy1+8] [expr $checkboxx1+2] [expr $checkboxy1+6] -fill $checkColorActive -outline $checkColorActive]
        }
        set columnObjectMap(h,$row.checkboxid) $checkboxid
        set columnObjectMap(h,$row.checkid) $checkid
        bindMouseCommands $editor $checkboxid "::SeqEditWidget::click_rowcheckbox %x %y"
        bindMouseCommands $editor $checkid "::SeqEditWidget::click_rowcheckbox %x %y"
        
        # Create the cell text for this row, if we have a font.
        if {$cellFont != ""} {
        
            set textid [$editor create text [expr $cellx1+$checkboxSize+4] $cellyc -font $cellFont -anchor w]
            set columnObjectMap(h,$row.textid) $textid
            set columnObjectMap(h,$row.textstring) ""
            set columnObjectMap(h,$row.font) $cellFont
            bindMouseCommands $editor $textid "::SeqEditWidget::click_rowheader %x %y normal" "::SeqEditWidget::click_rowheader %x %y shift" "::SeqEditWidget::click_rowheader %x %y control" "" "::SeqEditWidget::drag_rowheader %x %y" "::SeqEditWidget::click_rowheader %x %y release" "::SeqEditWidget::rightclick_rowheader %x %y"
        }
        
        # Create the cell numbering for this row, if we have a font.
        set numberWidth 0
        if {$cellFont != ""} {
        
            set numberWidth [expr ($cellFontNumberWidth*4)+4]
            set numberid [$editor create text [expr $cellx2-4] $cellyc -font $cellFont -anchor e -fill $headerNumberingColor]
            set columnObjectMap(h,$row.numberid) $numberid
            set columnObjectMap(h,$row.numberstring) ""
            bindMouseCommands $editor $numberid "::SeqEditWidget::click_rowheader %x %y normal" "::SeqEditWidget::click_rowheader %x %y shift" "::SeqEditWidget::click_rowheader %x %y control" "" "::SeqEditWidget::drag_rowheader %x %y" "::SeqEditWidget::click_rowheader %x %y release" "::SeqEditWidget::rightclick_rowheader %x %y"
        }

        # Create the info button.
        if {[expr $celly2-$celly1-5] < 10} {
            set infobuttonSize [expr $celly2-$celly1-5]
            set infobuttonx1 [expr $cellx2-$numberWidth-4-$infobuttonSize]
            set infobuttony1 [expr $celly1+2]
            set infobuttonx2 [expr $infobuttonx1+$infobuttonSize]
            set infobuttony2 [expr $infobuttony1+$infobuttonSize]
            set infobuttonid [$editor create rectangle $infobuttonx1 $infobuttony1 $infobuttonx2 $infobuttony2 -fill $infobuttonColorActive -outline $cellColorForeground]
            set infobuttontextid -1 
        } else {
            set infobuttonSize 10
            set infobuttonx1 [expr $cellx2-$numberWidth-4-$infobuttonSize]
            set infobuttony1 [expr $cellyc-5]
            set infobuttonx2 [expr $infobuttonx1+$infobuttonSize+1]
            set infobuttony2 [expr $infobuttony1+$infobuttonSize]
            set infobuttonid [$editor create rectangle $infobuttonx1 $infobuttony1 $infobuttonx2 $infobuttony2 -fill $infobuttonColorActive -outline $cellColorForeground]
            set infobuttontextid [$editor create text [expr $infobuttonx1+3] [expr $infobuttony1-1] -font $buttonFont -anchor nw -text "i" -fill $infobuttonFontColorActive] 
        }
        set columnObjectMap(h,$row.infobuttonid) $infobuttonid
        set columnObjectMap(h,$row.infobuttontextid) $infobuttontextid
        bindMouseCommands $editor $infobuttonid "::SeqEditWidget::click_rownotes %x %y"
        if {$infobuttontextid != -1} {
            bindMouseCommands $editor $infobuttontextid "::SeqEditWidget::click_rownotes %x %y"
        }
        
        # Create the representation button.
        if {[expr $celly2-$celly1-5] < 10} {
            set repbuttonSize [expr $celly2-$celly1-5]
            set repbuttonx1 [expr $cellx2-$numberWidth-4-($repbuttonSize*2)-2]
            set repbuttony1 [expr $celly1+2]
            set repbuttonx2 [expr $repbuttonx1+$repbuttonSize]
            set repbuttony2 [expr $repbuttony1+$repbuttonSize]
            set repbuttonid [$editor create rectangle $repbuttonx1 $repbuttony1 $repbuttonx2 $repbuttony2 -fill $repbuttonColorActive -outline $cellColorForeground]
            set repbuttontextid -1 
        } else {
            set repbuttonSize 10
            set repbuttonx1 [expr $cellx2-$numberWidth-4-($repbuttonSize*2)-2]
            set repbuttony1 [expr $cellyc-5]
            set repbuttonx2 [expr $repbuttonx1+$repbuttonSize+1]
            set repbuttony2 [expr $repbuttony1+$repbuttonSize]
            set repbuttonid [$editor create rectangle $repbuttonx1 $repbuttony1 $repbuttonx2 $repbuttony2 -fill $repbuttonColorActive -outline $cellColorForeground]
            set repbuttontextid [$editor create text [expr $repbuttonx1+3] [expr $repbuttony1-1] -font $buttonFont -anchor nw -text "r" -fill $repbuttonFontColorActive] 
        }
        set columnObjectMap(h,$row.repbuttonid) $repbuttonid
        set columnObjectMap(h,$row.repbuttontextid) $repbuttontextid
        bindMouseCommands $editor $repbuttonid "::SeqEditWidget::click_rowbutton rep %x %y"
        if {$repbuttontextid != -1} {
            bindMouseCommands $editor $repbuttontextid "::SeqEditWidget::click_rowbutton rep %x %y"
        }
        
        # Create the vmd button.
        if {[expr $celly2-$celly1-5] < 10} {
            set vmdbuttonSize [expr $celly2-$celly1-5]
            set vmdbuttonx1 [expr $cellx2-$numberWidth-4-($vmdbuttonSize*3)-4]
            set vmdbuttony1 [expr $celly1+2]
            set vmdbuttonx2 [expr $vmdbuttonx1+$vmdbuttonSize]
            set vmdbuttony2 [expr $vmdbuttony1+$vmdbuttonSize]
            set vmdbuttonid [$editor create rectangle $vmdbuttonx1 $vmdbuttony1 $vmdbuttonx2 $vmdbuttony2 -fill $vmdbuttonColorActive -outline $cellColorForeground]
            set vmdbuttontextid -1 
        } else {
            set vmdbuttonSize 10
            set vmdbuttonx1 [expr $cellx2-$numberWidth-4-($vmdbuttonSize*3)-4]
            set vmdbuttony1 [expr $cellyc-5]
            set vmdbuttonx2 [expr $vmdbuttonx1+$vmdbuttonSize+1]
            set vmdbuttony2 [expr $vmdbuttony1+$vmdbuttonSize]
            set vmdbuttonid [$editor create rectangle $vmdbuttonx1 $vmdbuttony1 $vmdbuttonx2 $vmdbuttony2 -fill $vmdbuttonColorActive -outline $cellColorForeground]
            set vmdbuttontextid [$editor create text [expr $vmdbuttonx1+3] [expr $vmdbuttony1-1] -font $buttonFont -anchor nw -text "v" -fill $vmdbuttonFontColorActive] 
        }
        set columnObjectMap(h,$row.vmdbuttonid) $vmdbuttonid
        set columnObjectMap(h,$row.vmdbuttontextid) $vmdbuttontextid
        bindMouseCommands $editor $vmdbuttonid "::SeqEditWidget::click_rowbutton vmd %x %y"
        if {$vmdbuttontextid != -1} {
            bindMouseCommands $editor $vmdbuttontextid "::SeqEditWidget::click_rowbutton vmd %x %y"
        }
        
        # Create the background.
        set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $cellColorInactive -outline $cellColorInactive]
        set separatorid [$editor create line $cellx1 $celly2 $cellx2 $celly2 -fill $cellColorInactive]
        set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] $celly2 -fill $cellColorInactive]
        set columnObjectMap(h,$row.boxid) $boxid
        set columnObjectMap(h,$row.boxcolor) $cellColorInactive
        set columnObjectMap(h,$row.separatorid) $separatorid
        set columnObjectMap(h,$row.tickid) $tickid
        bindMouseCommands $editor $boxid "::SeqEditWidget::click_rowheader %x %y normal" "::SeqEditWidget::click_rowheader %x %y shift" "::SeqEditWidget::click_rowheader %x %y control" "" "::SeqEditWidget::drag_rowheader %x %y" "::SeqEditWidget::click_rowheader %x %y release" "::SeqEditWidget::rightclick_rowheader %x %y"
        
        # Mark that the header is in an inactive state.
        set columnObjectMap(h,$row.active) 0
        
        # Move the y down.
        set y [expr $celly2+1]        
    }    
}

# Creates a new column in the editor.
# args:     col - The index of the column to create.
proc ::SeqEditWidget::createColumn {col} {

    # Import global variables.
    variable editor
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable columnObjectMap
    variable numberRows
    variable headerColorInactive
    variable cellColorInactive
    variable cellColorForeground
    variable headerFont
    variable cellFont
    
    # Set the starting location.
    set x $headerCellWidth
    set y 2
    
    # Create the header cell.
    set cellx1 [expr $x+$col*$cellWidth]
    set cellx2 [expr $cellx1+$cellWidth-1]
    set cellxc [expr $cellx1+($cellWidth/2)]
    set cellxq1 [expr $cellx1+($cellWidth/4)-1]
    set cellxq3 [expr $cellx2-($cellWidth/4)+1]
    set celly1 $y
    set celly2 [expr $headerCellHeight-2]
    set cellyc [expr $celly1+(($celly2-$celly1)/2)]
    set boxid [$editor create rectangle $cellx1 $celly1 [expr $cellx2+1] [expr $celly2+1] -fill $headerColorInactive -outline $headerColorInactive]
    set textid [$editor create text $cellxc $cellyc -font $headerFont -anchor center]
    
    # Set up the selection bindings.
    bindMouseCommands $editor $boxid  "::SeqEditWidget::click_columnheader %x %y none" "::SeqEditWidget::click_columnheader %x %y shift" "::SeqEditWidget::click_columnheader %x %y control" "" "::SeqEditWidget::move_columnheader %x %y" "::SeqEditWidget::release_columnheader %x %y" 
    bindMouseCommands $editor $textid  "::SeqEditWidget::click_columnheader %x %y none" "::SeqEditWidget::click_columnheader %x %y shift" "::SeqEditWidget::click_columnheader %x %y control" "" "::SeqEditWidget::move_columnheader %x %y" "::SeqEditWidget::release_columnheader %x %y" 
    
    # Create the separator and tick lines.
    set separatorid [$editor create line $cellx1 [expr $celly2+1] [expr $cellx2+1] [expr $celly2+1] -fill $headerColorInactive]
    set tickid [$editor create line $cellx2 [expr $celly2-1] $cellx2 [expr $celly2+1] -fill $headerColorInactive]
    
    # Store the header cell objects.
    set columnObjectMap($col,h.active) 0
    set columnObjectMap($col,h.boxid) $boxid
    set columnObjectMap($col,h.textid) $textid    
    set columnObjectMap($col,h.textstring) ""
    set columnObjectMap($col,h.separatorid) $separatorid    
    set columnObjectMap($col,h.tickid) $tickid
    set columnObjectMap($col,h.boxcolor) $headerColorInactive
    set columnObjectMap($col,h.x1) $cellx1
    set columnObjectMap($col,h.x2) $cellx2
    set columnObjectMap($col,h.y1) $celly1
    set columnObjectMap($col,h.y2) $celly2
    
    # If we are overlapping a text object from the previous column header, bring it to the front.
    if {$col > 0} {
        $editor raise $columnObjectMap([expr $col-1],h.textid) $boxid
    }
    
    # Go through each row and create its components for this column.
    set y $headerCellHeight
    for {set row 0} {$row < $numberRows} {incr row} {
    
        # Calculate some coordinates.
        set celly1 $y
        set celly2 [expr $celly1+$cellHeight-1]
        set cellyc [expr $celly1+($cellHeight/2)]
        set cellyq1 [expr $celly1+($cellHeight/4)-1]
        set cellyq3 [expr $celly2-($cellHeight/4)+1]
        
        # Create the box.
        set boxid [$editor create rectangle $cellx1 $celly1 [expr $cellx2+1] [expr $celly2+1] -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.boxid) $boxid
        set columnObjectMap($col,$row.boxcolor) $cellColorInactive
        bindCellObject $boxid
        
        # Move the box to below the previous column's box so all of the boxes are beneath everything else.
        if {$col > 0} {
            $editor lower $boxid $columnObjectMap([expr $col-1],$row.boxid)
        }
        
        # Create the text for this cell, if we have a font.
        if {$cellFont != ""} {
            set textid [$editor create text $cellxc $cellyc -state hidden -font $cellFont -anchor center]
            set columnObjectMap($col,$row.textid) $textid
            set columnObjectMap($col,$row.textstring) ""
            bindCellObject $textid
        }
        
        # Figure out the left and right sides for icons.
        set cellxf $cellx1
        set cellxr [expr $cellx2+1]
        
        # Create the bar and line for this cell
        set barid [$editor create polygon $cellxf $cellyq1 $cellxr $cellyq1 $cellxr $cellyq3 $cellxf $cellyq3 -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set lineid [$editor create line $cellxf $cellyc $cellxr $cellyc -state hidden -fill $cellColorForeground]
        set columnObjectMap($col,$row.barid) $barid
        set columnObjectMap($col,$row.barcolor) $cellColorInactive
        set columnObjectMap($col,$row.lineid) $lineid
        set columnObjectMap($col,$row.linecolor) $cellColorInactive
        bindCellObject $barid
        bindCellObject $lineid
        
        # Create the alpha helix icons for this cell.
        set cellyt [expr $celly1+1]
        set cellyb [expr $celly2-1]
        set alpha0 [$editor create polygon $cellxf $cellyt $cellxr $cellyt $cellxr $cellyc $cellxf $cellyb -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.alpha0id) $alpha0
        set columnObjectMap($col,$row.alpha0color) $cellColorInactive
        set alpha1 [$editor create polygon $cellxf $cellyt $cellxr $cellyt $cellxr $cellyb $cellxf $cellyc -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.alpha1id) $alpha1
        set columnObjectMap($col,$row.alpha1color) $cellColorInactive
        set alpha2 [$editor create polygon $cellxf $cellyt $cellxr $cellyc $cellxr $cellyb $cellxf $cellyb -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.alpha2id) $alpha2
        set columnObjectMap($col,$row.alpha2color) $cellColorInactive
        set alpha3 [$editor create polygon $cellxf $cellyc $cellxr $cellyt $cellxr $cellyb $cellxf $cellyb -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.alpha3id) $alpha3
        set columnObjectMap($col,$row.alpha3color) $cellColorInactive
        bindCellObject $alpha0
        bindCellObject $alpha1
        bindCellObject $alpha2
        bindCellObject $alpha3
        
        # Create the beta sheet icons for this cell.
        set arrow [$editor create polygon $cellxf $cellyq1 $cellxc $cellyq1 $cellxc $cellyt $cellxr $cellyc $cellxc $cellyb $cellxc $cellyq3 $cellxf $cellyq3 -state hidden -fill $cellColorInactive -outline $cellColorInactive]
        set columnObjectMap($col,$row.arrowid) $arrow
        set columnObjectMap($col,$row.arrowcolor) $cellColorInactive
        bindCellObject $arrow        
                
        # Mark that the row is inactive.
        set columnObjectMap($col,$row.active) 0
        
        # Move down to the next row.
        set y [expr $celly2+1]
    }    
}

proc ::SeqEditWidget::bindMouseCommands {canvas object {click ""} {shiftClick ""} {controlClick ""} {shiftControlClick ""} {motion ""} {release ""} {rightClick ""}} {
    
    if {$click != ""} {
        $canvas bind $object <ButtonPress-1> $click
    }
    if {$shiftClick != ""} {
        $canvas bind $object <Shift-ButtonPress-1> $shiftClick
    }
    if {$motion != ""} {
        $canvas bind $object <B1-Motion> $motion
    }
    if {$release != ""} {
        $canvas bind $object <ButtonRelease-1> $release
    }
    if {$::tcl_platform(os) == "Darwin"} {
        if {$controlClick != ""} {
            $canvas bind $object <Command-ButtonPress-1> $controlClick
        }
        if {$shiftControlClick != ""} {
            $canvas bind $object <Shift-Command-ButtonPress-1> $shiftControlClick
        }
        if {$rightClick != ""} {
            $canvas bind $object <Control-ButtonPress-1> $rightClick
        }
        if {$rightClick != ""} {
            $canvas bind $object <ButtonPress-2> $rightClick
        }
    } else {
        if {$controlClick != ""} {
            $canvas bind $object <Control-ButtonPress-1> $controlClick
        }
        if {$shiftControlClick != ""} {
            $canvas bind $object <Shift-Control-ButtonPress-1> $shiftControlClick
        }
        if {$rightClick != ""} {
            $canvas bind $object <ButtonPress-3> $rightClick
        }
    }
}

proc ::SeqEditWidget::bindCellObject {objectID} {

    # Import global variables.
    variable editor
    
    bindMouseCommands $editor $objectID "::SeqEditWidget::click_cell %x %y none" "::SeqEditWidget::click_cell %x %y shift" "::SeqEditWidget::click_cell %x %y control" "::SeqEditWidget::click_cell %x %y {shift control}" "::SeqEditWidget::move_cell %x %y" "::SeqEditWidget::release_cell %x %y"
}

# Delete the cells in the current editor.
proc ::SeqEditWidget::deleteCells {} {
    
    # Import global variables.
    variable editor
    variable columnObjectMap

    # Get a list of all of the objects on the canvas.
    set objectNames [array names columnObjectMap]
    
    # Delete each object.
    foreach objectName $objectNames {
        if {[string first "id" $objectName] != -1} {
            $editor delete $columnObjectMap($objectName)
        }
    }    

    # Reinitialize the object map.
    unset columnObjectMap
    array set columnObjectMap {}
}


# Redraws the widget.
# args:     redrawSequenceID - (default {}) A list of the specific sequence ids to redraw
#               or an empty list to redraw all of the sequences.
proc ::SeqEditWidget::redraw {{redrawSequenceID {}}} {

    # Import global variables.
    variable editor
    variable columnObjectMap
    variable firstElement
    variable firstGroup
    variable firstSequence
    variable numberRows
    variable groupNames
    variable groupMap
    variable numberElements
    variable numberCols    
    variable headerColorActive
    variable headerColorInactive
    variable headerColorForeground
    variable cellColorActive
    variable cellColorInactive
    variable cellColorForeground
    variable cellTextReplacementColor
    variable selectionColor
    variable checkColorActive
    variable infobuttonColorActive
    variable infobuttonFontColorActive
    variable repbuttonColorActive
    variable repbuttonFontColorActive
    variable vmdbuttonColorActive
    variable vmdbuttonFontColorActive
    variable coloringMap
    variable representationMap
    variable cellFont
    variable groupHeaderFont
    variable markMap
    variable selectionMap
    
    # If we are updating the whole editor, redraw the column header row.
    if {$redrawSequenceID == {}} {
        set elementIndex $firstElement
        for {set col 0} {$col < $numberCols} {incr col} {
            
            # See if this column has data in it.
            if {$elementIndex < $numberElements} {
                
                # Get the header text.
                set headertext ""
                if {$elementIndex == 0 || [expr $elementIndex%10] == 9} {
                    set headertext "[expr $elementIndex+1]"
                }
                
                # See if the header is selected.
                if {$selectionMap(h,$elementIndex) == 1} {
                    set headerColor $selectionColor
                } else {
                    set headerColor $headerColorActive
                }
                
                # Update the parts of the cell that have changed.
                set columnObjectMap($col,h.active) 1
                if {$columnObjectMap($col,h.textstring) != $headertext} {
                    set columnObjectMap($col,h.textstring) $headertext
                    $editor itemconfigure $columnObjectMap($col,h.textid) -text $headertext
                }
                if {$columnObjectMap($col,h.boxcolor) != $headerColor} {
                    set columnObjectMap($col,h.boxcolor) $headerColor
                    $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerColor
                    $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerColor
                    $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerColorForeground
                    $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerColorForeground
                }
                
            } elseif {$columnObjectMap($col,h.active) == 1} {
             
                 # Draw the cell as inactive.
                 set columnObjectMap($col,h.active) 0
                 $editor itemconfigure $columnObjectMap($col,h.textid) -text ""
                 $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerColorInactive
                 $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerColorInactive
                 $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerColorInactive
                 $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerColorInactive
                 
            }
            incr elementIndex
        }
    }

    # Figure out which group and sequence we are working with.
    set groupIndex $firstGroup
    set maxGroup [expr [llength $groupNames]-1]
    if {$groupIndex <= $maxGroup} { 
        set groupName [lindex $groupNames $groupIndex]
        set sequenceIndex $firstSequence
        set numberSequences $groupMap($groupName,numberSequences)
    } else {

        set groupName ""
        set sequenceIndex 0
        set numberSequences 0
    }
  
    # Go through each row and draw it.
    for {set row 0} {$row < $numberRows} {incr row; incr sequenceIndex} {

        # If we are finished with the current group and there is another one, move to it.
        if {$sequenceIndex >= $numberSequences && $groupIndex < $maxGroup} {  

            incr groupIndex
            set groupName [lindex $groupNames $groupIndex]
            set sequenceIndex -1
            set numberSequences $groupMap($groupName,numberSequences)
        }
    
        # See if this row has a sequence in it.
        if {$sequenceIndex < $numberSequences} {

	# See if this row is a grouping row.
            if {$sequenceIndex == -1} {
            
                # If we are just redrawing a set of sequences, we don't need to worry about grouping rows so continue on.
                if {$redrawSequenceID != {}} {
                    continue
                }
                
                # If we are not in the correct active state, adjust the order of the items.
                if {$columnObjectMap(h,$row.active) != 1} {
                    
                    # Rearrange the necessary items.
                    set columnObjectMap(h,$row.active) 1
                    if {$cellFont != ""} {
                        $editor raise $columnObjectMap(h,$row.textid) $columnObjectMap(h,$row.boxid)
                        $editor lower $columnObjectMap(h,$row.numberid) $columnObjectMap(h,$row.boxid)
                    }
                    $editor lower $columnObjectMap(h,$row.checkboxid) $columnObjectMap(h,$row.boxid)
                    $editor lower $columnObjectMap(h,$row.checkid) $columnObjectMap(h,$row.boxid)
                    $editor lower $columnObjectMap(h,$row.infobuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.infobuttontextid) != -1} {
                        $editor lower $columnObjectMap(h,$row.infobuttontextid) $columnObjectMap(h,$row.boxid)
                    }
                    $editor lower $columnObjectMap(h,$row.repbuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.repbuttontextid) != -1} {
                        $editor lower $columnObjectMap(h,$row.repbuttontextid) $columnObjectMap(h,$row.boxid)
                    }
                    $editor lower $columnObjectMap(h,$row.vmdbuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.vmdbuttontextid) != -1} {
                        $editor lower $columnObjectMap(h,$row.vmdbuttontextid) $columnObjectMap(h,$row.boxid)
                    }
                }
                
                # Redraw any visible items.
                if {$cellFont != ""} {
                    
                    # If the font has changed, update the necessary fields.
                    if {$columnObjectMap(h,$row.font) != $groupHeaderFont} {
                        set columnObjectMap(h,$row.font) $groupHeaderFont
                        $editor itemconfigure $columnObjectMap(h,$row.textid) -font $groupHeaderFont
                    }
                    
                    # If the sequence name has changed, update the name field.
                    if {$columnObjectMap(h,$row.textstring) != $groupName} {
                        set columnObjectMap(h,$row.textstring) $groupName
                        $editor itemconfigure $columnObjectMap(h,$row.textid) -text $groupName
                    }
                }
                if {$columnObjectMap(h,$row.boxcolor) != $headerColorActive} {
                    set columnObjectMap(h,$row.boxcolor) $headerColorActive
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $headerColorActive
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $headerColorActive
                    $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellColorForeground
                    $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellColorForeground
                }
                
                # No sequence data is associated with a group header.
                set sequence {}
                    
            # Otherwise this must be a regular row.
            } else {
            
                # Get the sequence id.
                set sequenceID [lindex $groupMap($groupName,sequenceIDs) $sequenceIndex]
                # If we are just redrawing a set of sequences and this is not one of them, continue on.
                if {$redrawSequenceID != {}} {
                    if {[lsearch $redrawSequenceID $sequenceID] == -1} {
                        continue
                    }
                }                
                
                # If we are not in the correct active state, adjust the order of the items.
                if {$columnObjectMap(h,$row.active) != 2} {
                    
                    # Rearrange the necessary items.
                    set columnObjectMap(h,$row.active) 2
                    if {$cellFont != ""} {
                        $editor raise $columnObjectMap(h,$row.textid) $columnObjectMap(h,$row.boxid)
                        $editor raise $columnObjectMap(h,$row.numberid) $columnObjectMap(h,$row.boxid)
                    }
                    $editor raise $columnObjectMap(h,$row.checkboxid) $columnObjectMap(h,$row.boxid)
                    $editor raise $columnObjectMap(h,$row.infobuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.infobuttontextid) != -1} {
                        $editor raise $columnObjectMap(h,$row.infobuttontextid) $columnObjectMap(h,$row.infobuttonid)
                    }
                    $editor raise $columnObjectMap(h,$row.repbuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.repbuttontextid) != -1} {
                        $editor raise $columnObjectMap(h,$row.repbuttontextid) $columnObjectMap(h,$row.repbuttonid)
                    }
                }
                
                # If this sequence is marked, show the check.
                if {$sequenceID != "" && $markMap($sequenceID) == 1} {
                    $editor raise $columnObjectMap(h,$row.checkid) $columnObjectMap(h,$row.checkboxid)
                } else {
                    $editor lower $columnObjectMap(h,$row.checkid) $columnObjectMap(h,$row.boxid)
                }
                
                # If we have a structure, show the vmd button.

                if { [::SeqData::hasStruct $sequenceID] == "Y"} {
                    $editor raise $columnObjectMap(h,$row.vmdbuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.vmdbuttontextid) != -1} {
                        $editor raise $columnObjectMap(h,$row.vmdbuttontextid) $columnObjectMap(h,$row.vmdbuttonid)
                    }
                } else {
                    $editor lower $columnObjectMap(h,$row.vmdbuttonid) $columnObjectMap(h,$row.boxid)
                    if {$columnObjectMap(h,$row.vmdbuttontextid) != -1} {
                        $editor lower $columnObjectMap(h,$row.vmdbuttontextid) $columnObjectMap(h,$row.boxid)
                    }
                }
                
                # Redraw any visible items.
                if {$cellFont != ""} {
                    
                    # If the font has changed, update the necessary fields.
                    if {$columnObjectMap(h,$row.font) != $cellFont} {
                        set columnObjectMap(h,$row.font) $cellFont
                        $editor itemconfigure $columnObjectMap(h,$row.textid) -font $cellFont
                        $editor itemconfigure $columnObjectMap(h,$row.numberid) -font $cellFont
                    }

                    # If the sequence name has changed, update the name field.
                    set sequenceName "  [SeqData::getName $sequenceID]"
                    if {$columnObjectMap(h,$row.textstring) != $sequenceName} {
                        set columnObjectMap(h,$row.textstring) $sequenceName
                        $editor itemconfigure $columnObjectMap(h,$row.textid) -text $sequenceName
                    }

                    # If the first residue number has changed, update the number field.
                    set firstResidueIndex ""
                    set maxElement [expr $firstElement+$numberCols-1]
                    if {$maxElement > [::SeqData::getSeqLength $sequenceID]} {
                        set maxElement [::SeqData::getSeqLength $sequenceID]
                    }
                    for {set i $firstElement} {$i < $maxElement} {incr i} {
                        set firstResidueIndex [::SeqData::getResidueForElement $sequenceID $i]
                        if {$firstResidueIndex != ""} {
                            set firstResidueIndex [string trim [join [lrange $firstResidueIndex 0 1] ""]]
                            break
                        }
                    }
                    if {$columnObjectMap(h,$row.numberstring) != $firstResidueIndex} {
                        set columnObjectMap(h,$row.numberstring) $firstResidueIndex
                        $editor itemconfigure $columnObjectMap(h,$row.numberid) -text $firstResidueIndex
                    }
                }
                
                # Figure out the color for the box.
                if {$selectionMap($sequenceID,h) == 1} {
                    set headerColor $selectionColor
                } else {
                    set headerColor $headerColorActive
                }
                if {$columnObjectMap(h,$row.boxcolor) != $headerColor} {
                    set columnObjectMap(h,$row.boxcolor) $headerColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $headerColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $headerColor
                    $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellColorForeground
                    $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellColorForeground
                }
                
                # Get the sequence data for the representation.
                if {$representationMap($sequenceID) == "secondary"} {
                    
                    # Get the secondary structure.
                    set sequence [lrange [SeqData::getSecondaryStructure $sequenceID 1] $firstElement [expr $firstElement+$numberCols-1]]
                    
                    # Figure out the starting helix count.
                    set helixCount 0
                    
                    # Figure out if the last element is the end of a beta strand.
                    set endsWithBetaArrow 0
                    
                } else {
                    set sequence [lrange [SeqData::getSeq $sequenceID] $firstElement [expr $firstElement+$numberCols-1]]
                }
            }

            # Go through each column that has an element in it.
            set col 0
            set elementIndex $firstElement
            foreach element $sequence {

                # See which representations we are showing.
                if {$representationMap($sequenceID) == "sequence"} {
                    
                    # If we are not in the correct active state, adjust the order of the items.
                    if {$columnObjectMap($col,$row.active) != 1} {
                        
                        # Rearrange the necessary items.
                        set columnObjectMap($col,$row.active) 1
                        if {$cellFont != ""} {
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -state normal
                        }
                        $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden
                    }
                    
                    # See if we need to adjust the text of the element.
                    if {$element == "-"} {
                        
                        set elementColor "#FFFFFF"
                        if {$cellFont == ""} {
                            set element ""
                        } else {
                            set element "."
                        }
                    } else {
                        
                        # Get some info about the element.
                        set elementColor $coloringMap($sequenceID,$elementIndex,rgb)
                    
                        if {$cellFont == "" && $elementColor == "#FFFFFF"} {
                            set elementColor $cellTextReplacementColor
                        }
                    }
                    
                    # See if we need to highlight this element
                    if {$selectionMap($sequenceID,$elementIndex) == 1} {
                        set intensityDecrease [expr -((1.0-[getIntesity $elementColor])/2.0)]
                        set elementColor [getBrightenedColor $selectionColor $intensityDecrease $intensityDecrease $intensityDecrease]
                    }
                    
                    # Update the parts of the cell that have changed.
                    if {$cellFont != ""} {            
                        if {$columnObjectMap($col,$row.textstring) != $element} {
                            set columnObjectMap($col,$row.textstring) $element
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -text $element
                        }
                    }
                    if {$columnObjectMap($col,$row.boxcolor) != $elementColor} {
                        set columnObjectMap($col,$row.boxcolor) $elementColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $elementColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $elementColor
                    }
                    
                } elseif {$representationMap($sequenceID) == "bar"} {
                    
                    # If we are not in the correct active state, adjust the order of the items.
                    if {$columnObjectMap($col,$row.active) != 2} {
                        
                        # Rearrange the necessary items.
                        set columnObjectMap($col,$row.active) 2
                        if {$cellFont != ""} {
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -state hidden
                        }
                        $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden
                    }

                    # Hide the bar and the line.                    
                    $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                        
                    # Make sure the box is the correct color.
                    set boxColor $cellColorActive
                    if {$selectionMap($sequenceID,$elementIndex) == 1} {
                        set boxColor $selectionColor
                    }
                    if {$columnObjectMap($col,$row.boxcolor) != $boxColor} {
                        set columnObjectMap($col,$row.boxcolor) $boxColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $boxColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $boxColor
                    }
                    
                    # Setup the item colors; if this is a gap, set the bar and line to the box color.
                    if {$element == "-"} {
                        
                        set iconName ""
                        set iconColorName ""
                        set iconColor ""
                        
                    # If this value is zero, just show the line.
                    } elseif {$coloringMap($sequenceID,$elementIndex,raw) == 0.0} {
                        
                        set iconName "lineid"
                        set iconColorName "linecolor"
                        set iconColor $cellColorForeground
                        
                    # Otherwise, show just the bar.
                    } else {
                        
                        set iconName "barid"
                        set iconColorName "barcolor"
                        set iconColor $coloringMap($sequenceID,$elementIndex,rgb)
                    }                    
                    
                    if {$iconName != ""} {
                        
                        # Adjust the color for any selection.
                        if {$selectionMap($sequenceID,$elementIndex) == 1} {
                            set intensityDecrease [expr -((1.0-[getIntesity $iconColor])/2.0)]
                            if {$intensityDecrease > -0.2} {
                                set intensityDecrease -0.2
                            }
                            set iconColor [getBrightenedColor $selectionColor $intensityDecrease $intensityDecrease $intensityDecrease]
                        }

                        # Make the canvas changes.                        
                        $editor itemconfigure $columnObjectMap($col,$row.$iconName) -state normal
                        if {$columnObjectMap($col,$row.$iconColorName) != $iconColor} {
                            set columnObjectMap($col,$row.$iconColorName) $iconColor
                            $editor itemconfigure $columnObjectMap($col,$row.$iconName) -fill $iconColor
                            if {$iconName != "lineid"} {
                                $editor itemconfigure $columnObjectMap($col,$row.$iconName) -outline $iconColor
                            }
                        }
                    }
                        
                } elseif {$representationMap($sequenceID) == "secondary"} {
                    
                    # If we are not in the correct active state, adjust the order of the items.
                    if {$columnObjectMap($col,$row.active) != 3} {
                        
                        # Rearrange the necessary items.
                        set columnObjectMap($col,$row.active) 3
                        if {$cellFont != ""} {
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -state hidden
                        }
                    }
                    
                    # Move all of the possible icons back.
                    $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden
                    
                    # Make sure the box is the correct color.
                    set boxColor $cellColorActive
                    if {$selectionMap($sequenceID,$elementIndex) == 1} {
                        set boxColor $selectionColor
                    }
                    if {$columnObjectMap($col,$row.boxcolor) != $boxColor} {
                        set columnObjectMap($col,$row.boxcolor) $boxColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $boxColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $boxColor
                    }
                    
                    # Setup the item colors; if this is a gap, just show the box.
                    if {$element == "-"} {
                        
                        set iconName ""
                        set iconColorName ""
                        set iconColor ""
                        
                    # If this is a helix, show the proper icon.
                    } elseif {$element == "H" || $element == "G" || $element == "I"} {
                        
                        # Set the stuff.
                        set iconName "alpha$helixCount"
                        append iconName "id"
                        set iconColorName "alpha$helixCount"
                        append iconColorName "color"
                        set iconColor $coloringMap($sequenceID,$elementIndex,rgb)
                        if {$iconColor == "#FFFFFF" || $iconColor == "white"} {
                            set iconColor $cellColorForeground
                        }
                    
                        # Increment the helix section.
                        incr helixCount
                        if {$helixCount > 3} {
                            set helixCount 0
                        }
                        
                    # If this is a strand, show the proper icon.
                    } elseif {$element == "E"} {
                        
                        set iconName "barid"
                        set iconColorName "barcolor"
                        set iconColor $coloringMap($sequenceID,$elementIndex,rgb)
                        if {$iconColor == "#FFFFFF" || $iconColor == "white"} {
                            set iconColor $cellColorForeground
                        }
                        set helixCount 0
                        
                        # See if this should really be an arrow.
                        if {[expr $col+1] < [llength $sequence]} {
                            for {set i [expr $col+1]} {$i < [llength $sequence]} {incr i} {
                                set nextElement [lindex $sequence $i]
                                if {$nextElement == "-"} {
                                    continue
                                } elseif {$nextElement == "E"} {
                                    break
                                } else {
                                    set iconName "arrowid"
                                    set iconColorName "arrowcolor"
                                    break
                                }
                            }
                        } elseif {$endsWithBetaArrow} {
                            set iconName "arrowid"
                            set iconColorName "arrowcolor"
                        }                        
                        
                    # Otherwise, just show the line.
                    } else {
                        
                        set iconName "lineid"
                        set iconColorName "linecolor"
                        set iconColor $cellColorForeground
                        set helixCount 0
                    }
                    
                    # Raise and color the correct icon.
                    if {$iconName != ""} {
                        
                        # Adjust the color for any selection.
                        if {$selectionMap($sequenceID,$elementIndex) == 1} {
                            set intensityDecrease [expr -((1.0-[getIntesity $iconColor])/2.0)]
                            if {$intensityDecrease > -0.2} {
                                set intensityDecrease -0.2
                            }
                            set iconColor [getBrightenedColor $selectionColor $intensityDecrease $intensityDecrease $intensityDecrease]
                        }

                        # Make the canvas changes.
                        $editor itemconfigure $columnObjectMap($col,$row.$iconName) -state normal
                        if {$columnObjectMap($col,$row.$iconColorName) != $iconColor} {
                            set columnObjectMap($col,$row.$iconColorName) $iconColor
                            $editor itemconfigure $columnObjectMap($col,$row.$iconName) -fill $iconColor
                            if {$iconName != "lineid"} {
                                $editor itemconfigure $columnObjectMap($col,$row.$iconName) -outline $iconColor
                            }
                        }
                    }
                    
                } else {
              
                    # If we are not in the correct active state, adjust the order of the items.
                    if {$columnObjectMap($col,$row.active) != 0} {
                        
                        # Rearrange the necessary items.
                        set columnObjectMap($col,$row.active) 0
                        if {$cellFont != ""} {
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -state hidden
                        }
                        $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                        $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden
    
                        # Draw the cell as inactive.
                        set columnObjectMap($col,$row.boxcolor) $cellColorInactive
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellColorInactive
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellColorInactive
                        
                    }
                }
                
                incr col
                incr elementIndex
            }

            # Go through the rest of the columns and make them inactive.
            for {} {$col < $numberCols} {incr col} {
            
                # If we are not in the correct active state, adjust the order of the items.
                if {$columnObjectMap($col,$row.active) != 0} {
                    
                    # Rearrange the necessary items.
                    set columnObjectMap($col,$row.active) 0
                    if {$cellFont != ""} {
                        $editor itemconfigure $columnObjectMap($col,$row.textid) -state hidden
                    }
                    $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden

                    # Draw the cell as inactive.
                    set columnObjectMap($col,$row.boxcolor) $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellColorInactive
                    
                } else {
                    break
                }
            }
        
        } else {

            # Draw the header cell as inactive.
            if {$columnObjectMap(h,$row.active) != 0} {
                
                set columnObjectMap(h,$row.active) 0
                if {$cellFont != ""} {
                    $editor lower $columnObjectMap(h,$row.textid) $columnObjectMap(h,$row.boxid)
                    $editor lower $columnObjectMap(h,$row.numberid) $columnObjectMap(h,$row.boxid)
                }
                $editor lower $columnObjectMap(h,$row.checkboxid) $columnObjectMap(h,$row.boxid)
                $editor lower $columnObjectMap(h,$row.checkid) $columnObjectMap(h,$row.boxid)
                $editor lower $columnObjectMap(h,$row.infobuttonid) $columnObjectMap(h,$row.boxid)
                if {$columnObjectMap(h,$row.infobuttontextid) != -1} {
                    $editor lower $columnObjectMap(h,$row.infobuttontextid) $columnObjectMap(h,$row.boxid)
                }
                $editor lower $columnObjectMap(h,$row.repbuttonid) $columnObjectMap(h,$row.boxid)
                if {$columnObjectMap(h,$row.repbuttontextid) != -1} {
                    $editor lower $columnObjectMap(h,$row.repbuttontextid) $columnObjectMap(h,$row.boxid)
                }
                $editor lower $columnObjectMap(h,$row.vmdbuttonid) $columnObjectMap(h,$row.boxid)
                if {$columnObjectMap(h,$row.vmdbuttontextid) != -1} {
                    $editor lower $columnObjectMap(h,$row.vmdbuttontextid) $columnObjectMap(h,$row.boxid)
                }
                if {$columnObjectMap(h,$row.boxcolor) != $cellColorInactive} {
                    set columnObjectMap(h,$row.boxcolor) $cellColorInactive
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $cellColorInactive
                    $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellColorInactive
                }
            }

            # Go through each column.            
            for {set col 0} {$col < $numberCols} {incr col} {

                # If we are not in the correct active state, adjust the order of the items.
                if {$columnObjectMap($col,$row.active) != 0} {
                    
                    # Rearrange the necessary items.
                    set columnObjectMap($col,$row.active) 0
                    if {$cellFont != ""} {
                        $editor itemconfigure $columnObjectMap($col,$row.textid) -state hidden
                    }
                    $editor itemconfigure $columnObjectMap($col,$row.barid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.lineid) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha0id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha1id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha2id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.alpha3id) -state hidden
                    $editor itemconfigure $columnObjectMap($col,$row.arrowid) -state hidden

                    # Draw the cell as inactive.
                    set columnObjectMap($col,$row.boxcolor) $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellColorInactive
                    
                } else {

                    break
                }
            }
        }
    }

}

# This method is called be the window manager when a component of the widget has been reconfigured.
# args:     a_name - The name of the component that was reconfigured.
#           a_width - The new width of the component.
#           a_height - The new height of the component.
proc ::SeqEditWidget::component_configured {a_name a_width a_height} {

    # Import global variables.
    variable editor
    variable width
    variable height
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable numberCols
    variable numberRows
    variable firstElement
    variable numberElements
    variable firstGroup
    variable firstSequence
    
    
    # Check to see if the window is being resized.
    if {$a_name == $editor && ($a_width != $width || $a_height != $height)} {
    
        # Save the new width and height.
        set width $a_width
        
        set height $a_height

        # See if the number of rows or columns has changed.
        if {$numberCols != [expr (($width-$headerCellWidth)/$cellWidth)+1] || $numberRows != [expr (($height-$headerCellHeight)/$cellHeight)+1]} {
        
            # Save the new number of rows and columns.
            set numberCols [expr (($width-$headerCellWidth)/$cellWidth)+1]
            set numberRows [expr (($height-$headerCellHeight)/$cellHeight)+1]

            # Make sure we are not out of scroll range.
            validateScrollRange

            # Create the new editor and redraw it.
            deleteCells
            setScrollbars
            createCells
            redraw
        }
    }
}

# This method is called be the horizontal scroll bar when its state has changed.
proc ::SeqEditWidget::scroll_horzizontal {{action 0} {amount 0} {type 0}} {

    # Import global variables.
    variable firstElement
    variable numberCols
    variable numberElements
    
    # Perform the scroll.
    if {$action == "scroll" && ($type == "units" || $type == "unit")} {
        set firstElement [expr $firstElement+$amount]
    } elseif {$action == "scroll" && ($type == "pages" || $type == "page")} {
        set firstElement [expr $firstElement+($numberCols-2)*$amount]
    } elseif {$action == "moveto"} {
        set firstElement [expr int(($numberElements+1)*$amount)]
    }
    # Make sure we didn't scroll out of range.
    validateScrollRange 1 0
    
    # Set the scroll bars.
    setScrollbars
    #puts "Redraw took [time redraw]"
    redraw
}

# This method is called to ensure that a cell is visible.
proc ::SeqEditWidget::ensureCellIsVisible {sequenceID position} {

    # Import global variables.
    variable firstElement
    variable numberCols
    variable numberElements
    
    # Track if we need to scroll.
    set needToScroll 0
    
    # See if we are out of the horizontal range.
    if {$position < $firstElement} {
        set firstElement $position
        set needToScroll 1
    } elseif { $position >= [expr $firstElement+$numberCols-1]} {
        set firstElement [expr $position-$numberCols+2]
        set needToScroll 1
    }
    
    # Make sure we didn't scroll out of range and then redraw.
    if {$needToScroll == 1} {
        validateScrollRange
        setScrollbars
        redraw
        
        return 1
    }
    
    return 0
}

    

# This method is called be the vertical scroll bar when its state has changed.
proc ::SeqEditWidget::scroll_vertical {{action 0} {amount 0} {type 0}} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable firstGroup
    variable firstSequence
    variable numberRows
    
    # See what kind of scroll this was.
    if {$action == "scroll"} {
        
        # Figure out how far we moved.
        set lines 0
        if {$type == "units" || $type == "unit"} {
            set lines $amount
        } elseif {$type == "pages" || $type == "page"} {
            set lines [expr ($numberRows-2)*$amount]
        }
    
        # If we moved some amount, figure out where we are now and redraw.
        if {$lines != 0} {
            while {$lines != 0} {
                if {$lines > 0} {
                    set numberSequences $groupMap([lindex $groupNames $firstGroup],numberSequences)
                    if {$lines < [expr $numberSequences-($firstSequence)]} {
                        incr firstSequence $lines
                        break
                    } elseif {$firstGroup == [expr [llength $groupNames]-1]} {
                        set firstSequence $groupMap([lindex $groupNames $firstGroup],numberSequences)
                        break
                    } else {
                        incr lines [expr -($numberSequences-($firstSequence))]
                        incr firstGroup
                        set firstSequence -1
                    }
                } elseif {$lines < 0} {
                    set numberSequences $groupMap([lindex $groupNames $firstGroup],numberSequences)
                    if {$lines > [expr -($firstSequence+2)]} {
                        incr firstSequence $lines
                        break
                    } elseif {$firstGroup == 0} {
                        set firstSequence -1
                        break
                    } else {
                        incr lines [expr $firstSequence+2]
                        incr firstGroup -1
                        set firstSequence [expr $groupMap([lindex $groupNames $firstGroup],numberSequences)-1]
                    }
                }
            }
        }
    
        # Make sure we didn't scroll out of range.
        validateScrollRange 0 1
        
        # Set the scroll bars.
        setScrollbars
        redraw
        
    } elseif {$action == "moveto"} {
        
        set lines {}
        set numberGroups [expr [llength $groupNames]]
        for {set i 0} {$i < $numberGroups} {incr i} {
        
            # Add a line for the group header.
            lappend lines [list $i -1]
            
            # Get the number of sequences in this group.
            set numberSequences $groupMap([lindex $groupNames $i],numberSequences)
            for {set j 0} {$j < $numberSequences} {incr j} {
                lappend lines [list $i $j]
            }
        }
        
        set lineIndex [expr int(([llength $lines]-1)*$amount)]
        if {$lineIndex < 0} {
            set lineIndex 0
        } elseif {$lineIndex >= [llength $lines]} {
            set lineIndex [expr [llength $lines]-1]
        }
        set line [lindex $lines $lineIndex]
        set newFirstGroup [lindex $line 0]
        set newFirstSequence [lindex $line 1]

        # If we change position, perform the scroll.
        if {$newFirstGroup != $firstGroup || $newFirstSequence != $firstSequence} {
            
            set firstGroup $newFirstGroup
            set firstSequence $newFirstSequence
            validateScrollRange 0 1
            setScrollbars
            redraw
        }
    }
}

# Handle clicks on the row header.
proc ::SeqEditWidget::click_rowcheckbox {x y} {

    # Import global variables.
    variable groupNames
    variable markMap
    
    # Get the row that was clicked on.
    set row [determineRowFromLocation $x $y]
    if {$row != -1} {
    
        # Get the sequence that is in the row.
        set sequence [determineSequenceFromRow $row]
        
        # Make sure there is a sequence in the row.
        if {$sequence != {}} {
        
            # Get the new mark state.
            set sequenceID [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]]
            set state $markMap($sequenceID)
            if {$state == 0} {
                set state 1
            } else {
                set state 0
            }
            
            # Get the lsit of currently selecetd sequences.
            set selectedSequenceIDs [getSelectedSequences]
            
            # If this sequence in in the selected list, set all of them as marked.
            if {[lsearch $selectedSequenceIDs $sequenceID] != -1} {
                setMarksOnSequences $selectedSequenceIDs $state
            
            # Otherwise just set this sequence as marked.
            } else {
                setMarksOnSequences [list $sequenceID] $state
            }
        }
    }    
}

# Handle clicks on the row header.
proc ::SeqEditWidget::click_rownotes {x y} {

    # Import global variables.
    variable widget
    variable groupNames
    
    # Get the row that was clicked on.
    set row [determineRowFromLocation $x $y]
    if {$row != -1} {
    
        # Get the sequence that is in the row.
        set sequence [determineSequenceFromRow $row]
        
        # Make sure there is a sequence in the row.
        if {$sequence != {} && [lindex $sequence 1] != -1} {
            set sequenceID [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]]
            if {[::SeqData::Notes::showEditNotesDialog $widget $sequenceID]} {
                redraw $sequenceID
            }
        }
    }    
}

# Handle clicks on the row header.
proc ::SeqEditWidget::click_rowbutton {buttonType x y} {

    # Import global variables.
    variable widget
    variable groupNames
    variable repPopupMenu
    variable vmdPopupMenu
    variable popupMenuParameters
    
    # Get the row that was clicked on.
    set row [determineRowFromLocation $x $y]
    if {$row != -1} {
    
        # Get the sequence that is in the row.
        set sequence [determineSequenceFromRow $row]
        
        # Make sure there is a sequence in the row.
        if {$sequence != {} && [lindex $sequence 1] != -1} {
            
            # Get the sequence id.
            set sequenceID [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]]
            
            # Get the currently selected sequences.
            set selectedSequenceIDs [getSelectedSequences]
            
            # If this sequence is in the selected list, set that all of them should be affected.
            if {[lsearch $selectedSequenceIDs $sequenceID] != -1} {
                set popupMenuParameters $selectedSequenceIDs
            
            # Otherwise set that just this sequence should be affected.
            } else {                
                set popupMenuParameters $sequenceID
            }
            
            # Figure out the popup location.
            set px [expr $x+[winfo rootx $widget]]
            set py [expr $y+[winfo rooty $widget]]
            
            # Bring up the group popup menu.
            if {$buttonType == "rep"} {
                tk_popup $repPopupMenu $px $py
            } elseif {$buttonType == "vmd" && $vmdPopupMenu != ""} {
                tk_popup $vmdPopupMenu $px $py
            }
        }
    }    
}

proc ::SeqEditWidget::rightclick_rowheader {x y} {
    
    # Import global variables.
    variable widget
    variable clickedGroup
    variable groupPopupMenu
    
    # Get the row that was clicked on.
    set row [determineRowFromLocation $x $y]
    if {$row != -1} {
    
        # Get the sequence that is in the row.
        set sequence [determineSequenceFromRow $row]
        
        # Make sure there is a sequence in the row.
        if {$sequence != {}} {
            
            # If this is a group row, save the group index and popup the group menu.
            if {[lindex $sequence 1] == -1} {
                
                set clickedGroup [lindex $sequence 0]
    
                # Figure out the popup location.
                set px [expr $x+[winfo rootx $widget]]
                set py [expr $y+[winfo rooty $widget]]
                        
                # Bring up the group popup menu.
                tk_popup $groupPopupMenu $px $py
            }
        }
    }
    
}

proc ::SeqEditWidget::menu_insertgroup {} {
    
    # Import global variables.
    variable widget
    variable groupNames
    variable clickedGroup

    array set options [::SeqEdit::GetGroupName::showGetGroupNameDialog $widget "Insert Group" "Enter group name"]
    if {[array size options] > 0 && $options(name) != ""} {
        insertGroup $options(name) $clickedGroup
    }
}

proc ::SeqEditWidget::menu_renamegroup {} {
    
    # Import global variables.
    variable widget
    variable groupNames
    variable clickedGroup

    array set options [::SeqEdit::GetGroupName::showGetGroupNameDialog $widget "Rename Group" "Enter new group name" [lindex $groupNames $clickedGroup]]
    if {[array size options] > 0 && $options(name) != ""} {
        renameGroup [lindex $groupNames $clickedGroup] $options(name)
    }
}

proc ::SeqEditWidget::menu_deletegroup {} {
    
    # Import global variables.
    variable groupNames
    variable clickedGroup

    deleteGroup [lindex $groupNames $clickedGroup]
}

proc ::SeqEditWidget::menu_addtogroup {} {
    
    # Import global variables.
    variable groupNames
    variable clickedGroup

    set filename [tk_getOpenFile -filetypes {{{FASTA Files} {.fasta}} {{All Files} * }} -title "Add Sequences to [lindex $groupNames $clickedGroup] Group"]
    if {$filename != ""} {
        set sequences [::SeqData::Fasta::loadSequences $filename]
        addSequences $sequences [lindex $groupNames $clickedGroup]
    }
}

proc ::SeqEditWidget::menu_markgroup {{value 1}} {
    
    # Import global variables.
    variable groupNames
    variable clickedGroup

    setMarksOnSequences [getSequencesInGroup [lindex $groupNames $clickedGroup]] $value
}
    
proc ::SeqEditWidget::menu_markall {{value 1}} {
    
    setMarksOnSequences [getSequences] $value
}
    

proc ::SeqEditWidget::menu_duplicate {} {
    
    # Import global variables.
    variable popupMenuParameters

    duplicateSequences $popupMenuParameters
}
    
proc ::SeqEditWidget::menu_setrepresentation {type} {
    
    # Import global variables.
    variable popupMenuParameters

    setRepresentations $popupMenuParameters $type
}
    
# Gets the row that contains the specified x and y position.
# return:   The row the is at the specified position or -1 if it there is no valid row there.
proc ::SeqEditWidget::determineRowFromLocation {x y} {
    
    # Import global variables.
    variable columnObjectMap
    variable numberRows
    
    for {set i 0} {$i < $numberRows} {incr i} {
        if {$y >= $columnObjectMap(h,$i.y1) && $y <= $columnObjectMap(h,$i.y2)} {
            return $i
        }
    }
    
    return -1
}

# Gets the sequence that is currently being displayed in the specified row.
# args:     row - The row to check.
# return:   A list containing two elements: 1. the index of the group; 2. the index of the sequence
#           in the group. If no sequence were in the row an empty list is returned.
proc ::SeqEditWidget::determineSequenceFromRow {row} {

    # Import global variables.
    variable groupNames
    variable groupMap
    variable firstGroup
    variable firstSequence
    variable numberRows
    
    # Go through each group.
    set offset $firstSequence
    set numberGroups [llength $groupNames]
    for {set groupIndex $firstGroup} {$groupIndex < $numberGroups && $row >= 0} {incr groupIndex} {
    
        # Get the number of sequences in this group.
        set numberSequences $groupMap([lindex $groupNames $groupIndex],numberSequences)
        
        # See if the row is in this group.
        if {[expr $row+$offset] < $numberSequences} {
        
            # It is, so figure out and return the sequence info.
            return [list $groupIndex [expr $row+$offset]]
            
        } else {
        
            # It is not, so go to the next group.
            incr row [expr -($numberSequences-$offset)]
            set offset -1
        }
    }
        
    return {}
}


# Gets the column that contains the specified x and y location.
# return:   The column the is at the specified location or -1 if it there is no valid column there.
proc ::SeqEditWidget::determineColumnFromLocation {x y} {
    
    # Import global variables.
    variable columnObjectMap
    variable numberCols
    
    for {set i 0} {$i < $numberCols} {incr i} {
        if {$x >= $columnObjectMap($i,h.x1) && $x <= $columnObjectMap($i,h.x2)} {
            return $i
        }
    }
    
    return -1
}

# Gets the element that is currently being displayed in the specified column.
# args:     column - The column to check.
# return:   The index of the element in the specified column. or -1 no element is in the column.
proc ::SeqEditWidget::determinePositionFromColumn {column} {

    # Import global variables.
    variable firstElement
    variable numberElements
            
    set elementIndex [expr $firstElement+$column]
    if {$elementIndex < $numberElements} {return $elementIndex}
    return -1
}

proc ::SeqEditWidget::getColorComponents {color} {
    
    # Get the color components
    set r "0x[string range $color 1 2]"
    if {$r == "0x 0"} {
        set r 0.0
    } else {
        set r [expr double($r)]
    }
    set g "0x[string range $color 3 4]"
    if {$g == "0x 0"} {
        set g 0.0
    } else {
        set g [expr double($g)]
    }
    set b "0x[string range $color 5 6]"
    if {$b == "0x 0"} {
        set b 0.0
    } else {
        set b [expr double($b)]
    }
    
    return [list $r $g $b]
}

proc ::SeqEditWidget::getBrightenedColor {color rPercentage gPercentage bPercentage} {

    set components [getColorComponents $color]
    set r [lindex $components 0]
    set g [lindex $components 1]
    set b [lindex $components 2]
    
    set r [expr int($r+($r*$rPercentage))]
    set g [expr int($g+($g*$gPercentage))]
    set b [expr int($b+($b*$bPercentage))]
        
    set color "#[format %2X $r][format %2X $g][format %2X $b]"
    return $color
}

proc ::SeqEditWidget::getIntesity {color} {
    
    set components [getColorComponents $color]
    set max 0.0
    if {[lindex $components 0] > $max} {
        set max [lindex $components 0]
    }
    
    if {[lindex $components 1] > $max} {
        set max [lindex $components 1]
    }
    
    if {[lindex $components 2] > $max} {
        set max [lindex $components 2]
    }
    
    return [expr $max/255.0]
}

proc ::SeqEditWidget::saveAsPS { } {
  variable editor

  set outFile [tk_getSaveFile -initialfile "plot.ps" \
                 -title "Enter filename for PS output"]

  if { $outFile == "" } {
    return
  }

  $editor postscript -file $outFile

  return
}

#####################################
#
# drawImage
#
# Creates a window with an image of a zoomed out view of the sequences
# The window is originally the same size as the Multiseq window
# 
# 
proc ::SeqEditWidget::drawImage { } {

	variable drawZoom
	
	variable colorMapper
	variable coloringMap
	
	variable imageScale
	variable firstElement
	variable numberCols
	variable firstSequence
	variable numberRows
	variable numberElements
	
	variable firstx
	variable firsty
	variable lastx
	variable lasty
	
	variable zoomWidth
	
	#variable width
	variable height
	
	variable columnObjectMap

	set photo ""
	
	variable headerColorInactive
	
	if { $zoomWidth == 0 } {
		set zoomWidth [winfo width .multiseq]
	}
	
	if { !$drawZoom } {
		set imageScale [expr $zoomWidth / [llength [getSequences]]]
		return
	}
	

	set photo ""
	catch {
		set photo [drawCanvas]
	} drawcanvaserr


	#set height 30
	#set width 200
	
	if { [winfo exists .multiseq] } {
		#set width [winfo width .multiseq]
		#set height [winfo height .multiseq]
	}

	if { ![winfo exists .photoWindow] } {
		set photoWindow [toplevel .photoWindow]
		bind $photoWindow <Destroy> { ::SeqEditWidget::turnOffZoom }
		#set photoWindow [frame .multiseq.photoWindow -height $height -width $width]
		set imageFrame [frame $photoWindow.imageFrame -width [expr $zoomWidth ] -borderwidth 0]


	} else {
		#set photoWindow .multiseq.photoWindow
		set photoWindow .photoWindow
		set imageFrame $photoWindow.imageFrame
		#$photoWindow configure -height $height
		#$photoWindow configure -width $width
	}
	
	set boxColor "\#000000"
	
	catch {
		set firstx 0
		set firsty 0
		set lastx 0
		set lasty 0
		drawBox
	}

	wm title $photoWindow "Scaled image"

	if { ![winfo exists $imageFrame.photoImageCanvas] } {
		set photoImageCanvas [canvas $imageFrame.photoImageCanvas  -background black -width [expr $zoomWidth ] -borderwidth 0]
		$photoImageCanvas create image 0 0 -image $photo -anchor nw
		set imageScrollbar [scrollbar $imageFrame.imageScrollbar -orient vertical -command "$photoImageCanvas yview"]
		$photoImageCanvas configure -yscrollcommand "$imageScrollbar set"
		$photoImageCanvas configure -scrollregion [$photoImageCanvas bbox all]
	} else {

		set photoImageCanvas $imageFrame.photoImageCanvas
		$photoImageCanvas create image 0 0 -image $photo -anchor nw
		$photoImageCanvas configure -width [expr $zoomWidth]
		#$photoImageCanvas configure -height [expr $height + 1]
		
		#$photoWindow configure -width $zoomWidth
		set imageScrollbar $imageFrame.imageScrollbar

		$photoImageCanvas configure -yscrollcommand "$imageScrollbar set"
		$photoImageCanvas configure -scrollregion [$photoImageCanvas bbox all]
	}

	bind $photoImageCanvas <ButtonPress-1> "::SeqEditWidget::imageCanvasScroll %x %y"
	bind $photoWindow <Configure> {if { $::SeqEditWidget::zoomWidth != [winfo width .photoWindow] } {.photoWindow configure -width [winfo width .photoWindow]; set ::SeqEditWidget::zoomWidth [.photoWindow cget -width]; ::SeqEditWidget::drawCanvas}  }

	pack $imageScrollbar -side left -fill y -expand 0 -anchor nw
	pack $photoImageCanvas -side left -anchor nw -expand 1 -fill both -ipadx 0 -ipady 0 -padx 0 -pady 0

	pack $imageFrame -side left -anchor nw -fill both -expand 1 -ipadx 0 -ipady 0 -padx 0 -pady 0

	
} ; #end drawImage



####################################
#
# drawCanvas
#
# Redraws the zoomed out image canvas
#
proc ::SeqEditWidget::drawCanvas { } {
	variable drawZoom
	
	variable colorMapper
	variable coloringMap
	
	variable imageScale
	variable firstElement
	variable numberCols
	variable firstSequence
	variable numberRows
	variable numberElements
	
	variable zoomWidth
	
	set imgbytes {}
	set imgrow {}
	set length [llength [getSequences]]
	if { $length == 0 } {
		return
	}
	set groupList [getGroups]
	catch {
	foreach groupName $groupList {

		set sequencesInGroup [getSequencesInGroup $groupName]
		set imgrow {}
		for { set i 0 } { $i <= $numberElements } { incr i } {
			lappend imgrow "\#999999"

		}
		lappend imgbytes $imgrow
		
		foreach seq $sequencesInGroup {

		set imgrow {}
		catch { set a $coloringMap($seq,used) } coloringMapErr
		#if { $coloringMapErr != 1 } { puts "coloringMapErr = $coloringMapErr" } else { puts "coloringMap($seq,used) = $coloringMap($seq,used)"}

			set sequence [SeqData::getSeq $seq]
			set lengthSeq [llength $sequence]
			for {set i 0} { $i <= $numberElements} { incr i } {
				if { $coloringMapErr == 1 && $coloringMap($seq,used)} {

					if { $i >= $lengthSeq } {
						lappend imgrow "\#FFFFFF"
					} elseif { [lindex $sequence $i] == "-" } {
						lappend imgrow "\#FFFFFF"
						#if { [catch {
						#	set a $columnObjectMap($seq,$i.boxcolor)
						#} ] } {
						#	lappend imgrow $coloringMap($seq,$i,rgb)
						#} else {
						#	lappend imgrow "\#FFFFFF"
						#}
					} else {
							lappend imgrow $coloringMap($seq,$i,rgb)
						#if { [catch {
						#	set a $columnObjectMap($seq,$i.boxcolor)
						#} ] } {
						#	lappend imgrow $coloringMap($seq,$i,rgb)
						#} else {
						#	lappend imgrow $columnObjectMap($seq,$i.boxcolor)
						#}
					}
				} else {
					lappend imgrow "\#FFFFFF"
				}
			}
		
			lappend imgbytes $imgrow

	}
	}
	} drawErr
	#puts "Multiseq Zoom) Error in drawingImage: $drawErr"
	set photoOrig [ image create photo PhotoOrig -palette 256/256/256 ]
	

		#set photo [ image create photo Photo -palette 256/256/256 ]
	catch {

		$photoOrig put $imgbytes
	} photoError
	#puts "Multiseq Zoom) error in putting imagebytes: $photoError"
	
		set imageScale [expr 1.0 * $zoomWidth / [image width $photoOrig]]

		catch {
			image delete Photo
		}
	set photo [resize $photoOrig $zoomWidth [expr round([image height $photoOrig] * $imageScale)] "Photo"]

	#set photo $photoOrig
	if { [winfo exists .photoWindow]} {
	set imageScrollbar .photoWindow.imageFrame.imageScrollbar
	set photoImageCanvas .photoWindow.imageFrame.photoImageCanvas
	set imageFrame .photoWindow.imageFrame
	set photoWindow .photoWindow
	
	catch {
		pack forget $imageScrollbar
		pack forget $imageFrame
		pack forget $photoImageCanvas
	} forgetErr
	#puts "Multiseq Zoom) Error in pack forget: $forgetErr"
	
	catch {
		$photoImageCanvas configure -height [winfo height .photoWindow]
		$imageFrame configure -height 50
		$photoImageCanvas configure -scrollregion [$photoImageCanvas bbox all]

	bind $photoImageCanvas <ButtonPress-1> "::SeqEditWidget::imageCanvasScroll %x %y"
	bind $photoWindow <Configure> {if { $::SeqEditWidget::zoomWidth != [winfo width .photoWindow] } {.photoWindow configure -width [winfo width .photoWindow]; set ::SeqEditWidget::zoomWidth [.photoWindow cget -width]; ::SeqEditWidget::drawCanvas} }

	pack $imageScrollbar -side left -fill y -expand 0 -anchor nw
	pack $photoImageCanvas -side left -anchor nw -expand 1 -fill both -ipadx 0 -ipady 0 -padx 0 -pady 0

	pack $imageFrame -side left -anchor nw -fill both -expand 1 -ipadx 0 -ipady 0 -padx 0 -pady 0		
	} packErr
	#puts "Multiseq Zoom) Error in packing: $packErr"
		}
	
	return $photo
}; #end drawCanvas


####################################
#
# drawBox
#
# Draws the box in the zoomed out image, by creating
# transparent pixels in the image.
#
proc ::SeqEditWidget::drawBox {  } {

	variable firstx
	variable firsty
	variable lastx
	variable lasty
	

	variable numberRows
	variable numberElements
	variable numberCols
	variable firstElement
	variable firstSequence
	variable imageScale
	variable firstGroup
	variable groupMap
	variable drawZoom

	
	if { !$drawZoom } {
		return
	}
	
	catch {
	
	set length [llength [getSequences]]
	set lengthWindow [incr length [llength [getGroups]]]
	if { $length == 0 } {
		return
	}

	set firstRow $firstSequence
	set firstCol $firstElement
	
	set foo ""
	set seqsInGroup 0
	for { set i 0 } { $i < $firstGroup } { incr i } {
		if { [catch {
		incr firstRow
		set groupName [lindex [getGroups] $i]
		incr firstRow $groupMap($groupName,numberSequences)
		set seqsInGroup $groupMap($groupName,numberSequences)
		} foo] } {
			#puts "Multiseq Zoom) Error in setting firstGroup: $foo"
		}
	}

	
	set numSequences $numberRows
	if { $numSequences > $length} {
		set numSequences $length
	}
	set lastRow [expr $firstRow + $numSequences ]
	if { $lastRow > $length} {
		set lastRow $length
		set lastGroup [expr [llength [getGroups]] - 1]
		set firstSequence $groupMap([lindex [getGroups] $lastGroup],numberSequences)
		for { set i 0 } { $i <= $numSequences } { incr i } {
			incr firstSequence -1
			if { $i > $groupMap([lindex [getGroups] $lastGroup],numberSequences)} {
				set firstSequence -1
				incr lastGroup -1
			}
		}
	}
	set lastCol [expr $firstElement + $numberCols - 1]
	if { $lastCol >= [ expr $numberElements] } {
		set lastCol [expr $numberElements ]
		set firstCol [expr $numberElements - $numberCols + 1]
		set firstElement $firstCol
	}	
	
	
	set imageScrollbar .photoWindow.imageFrame.imageScrollbar
	set imageCanvas .photoWindow.imageFrame.photoImageCanvas
	
	set canvasHeight [Photo cget -height]
	set canvasWidth [Photo cget -width]
	
	set coords [$imageScrollbar get]
	set firstHeight [lindex $coords 0]
	set lastHeight [lindex $coords 1]

	set scaledFirstCol [expr round(($firstCol * $imageScale))]
	set scaledLastCol [expr round(($lastCol * $imageScale))]
	set scaledFirstRow [expr round((($firstRow+1) * $imageScale))]
	set scaledLastRow [expr round(($lastRow * $imageScale))]

	if { $scaledFirstRow < 0 } {
		set scaledFirstRow 0
	}
	if { $scaledFirstCol < 0 } {
		set scaledFirstCol 0

	}
	
	if { $scaledLastRow >= $canvasHeight } {
		set scaledLastRow [expr $canvasHeight - 1]

	}
	
	if { $scaledLastCol > $canvasWidth } {
		set scaledLastCol $canvasWidth

	}
	
	for { set j $firsty } { $j < $lasty } { incr j } {

		Photo transparency set $firstx $j false
		Photo transparency set $lastx $j false
		
		Photo transparency set [expr $firstx + 1] $j false
		Photo transparency set [expr $lastx - 1] $j false
	}

	for { set i $firstx } { $i < $lastx } { incr i } {
		Photo transparency set $i $firsty false
		Photo transparency set $i $lasty false
		
		Photo transparency set $i [expr $firsty + 1] false
		Photo transparency set $i [expr $lasty - 1] false
	}
	
	for { set j $scaledFirstRow } { $j < $scaledLastRow } { incr j } {
		
		Photo transparency set $scaledFirstCol $j true
		Photo transparency set $scaledLastCol $j true
		
		Photo transparency set [expr $scaledFirstCol + 1] $j true
		Photo transparency set [expr $scaledLastCol - 1] $j true
	}

	for { set i $scaledFirstCol } { $i < $scaledLastCol } { incr i } {
	
		Photo transparency set $i $scaledFirstRow true
		Photo transparency set $i $scaledLastRow true
		
		Photo transparency set $i [expr $scaledFirstRow + 1] true
		Photo transparency set $i [expr $scaledLastRow - 1] true
	}
	
	set firstx $scaledFirstCol
	set lastx $scaledLastCol
	set firsty $scaledFirstRow
	set lasty $scaledLastRow
	
	} foo
	#puts "Multiseq Zoom) Error in drawBox: $foo"
}

####################################
#
# imageCanvasScroll
#
# Scrolls the zoomed out image
#
# parameters:
#  x: the x-coordinate of the zoomed out image
#  y: the y-coordinate of the zoomed out image
#
proc ::SeqEditWidget::imageCanvasScroll { x y } {

	variable imageScale
	variable groupMap
	variable firstGroup
	variable firstSequence
	variable numberRows
	variable numberElements
	
	if { [image names] == "" || [lsearch [image names] "Photo"] == -1 }  {
		return
	}
	
	set colWidth [expr [image width Photo] / $numberElements]
	set y [expr $y - (.5 * $colWidth) ]
	set x [expr $x - (.5 * $colWidth)]
	
	set imageScrollbar .photoWindow.imageFrame.imageScrollbar
	set imageCanvas .photoWindow.imageFrame.photoImageCanvas

	set canvasHeight [Photo cget -height]
	
	set coords [$imageScrollbar get]
	set firstHeight [lindex $coords 0]
	set lastHeight [lindex $coords 1]


	set scaledx [expr round($x / $imageScale)]
	set scaledy [expr round(($y + ($firstHeight * $canvasHeight))/ $imageScale )]
	
	set numseqs 0
	set y $scaledy
	foreach groupName [getGroups] {
		if { $y >= $numseqs } {
			incr scaledy
			incr numseqs $groupMap($groupName,numberSequences)
			incr numseqs
		} else {
			break
		}
	}
	incr scaledy -2
	set SeqEditWidget::firstElement $scaledx
	set ::SeqEditWidget::firstSequence $scaledy
	
	set numseqs 0
	set groupId 0
	set foo ""
	set done 0
	set firstGroup 0
	set firstSequence 0


	set relativeRow 0
	if { $scaledy < 0 } {
		set relativeRow -1
	}
	set groupId 0
	set firstGroup 0
	set currGroup [lindex [getGroups] $groupId]
	for { set i 0 } { $i < $scaledy } { incr i } {
		if { $relativeRow == $groupMap($currGroup,numberSequences) } {
			set relativeRow -1
			incr groupId
			set firstGroup $groupId
			set currGroup [lindex [getGroups] $groupId]
		} else {
			incr relativeRow
		}
	}
	
	set firstSequence $relativeRow
		
	scroll_vertical
	scroll_horzizontal
	drawBox
	catch {
		::SeqEditWidget::redraw
	} foo
	#puts "Multiseq Zoom) Error in redraw: $foo"

}; #end imageCanvasScroll

####################################
#
# turnOffZoom
#
# Disables the zoom window
#
proc ::SeqEditWidget::turnOffZoom { } {
	variable drawZoom
	set drawZoom 0
	#pack forget .multiseq.photoWindow
	catch {
		wm state .photoWindow withdrawn
	}
}

####################################
#
# turnOnZoom
#
# Enables the zoom window
#
proc ::SeqEditWidget::turnOnZoom { } {

	variable drawZoom
	set drawZoom 1
	drawImage
	wm state .photoWindow normal
}

#####################################
#
# toggleZoom
#
# Switches the current state of the 
# Zoom window
#
proc ::SeqEditWidget::toggleZoom { } {

	variable drawZoom

	if { !$drawZoom } {

		turnOffZoom
	} else {

		turnOnZoom
	}
}
  
###################################################
 #
 #  Name:         resize
 #
 #  Decsription:  Copies a source image to a destination
 #                image and resizes it using linear interpolation
 #
 #  Parameters:   newx   - Width of new image
 #                newy   - Height of new image
 #                src    - Source image
 #                dest   - Destination image (optional)
 #
 #  Returns:      destination image
 #
 ###################################################
 proc resize {src newx newy name {dest ""} } {

     set mx [image width $src]
     set my [image height $src]

     if { "$dest" == ""} {
         set dest [image create photo $name]
     }
     $dest configure -width $newx -height $newy

     # Check if we can just zoom using -zoom option on copy
     if { $newx % $mx == 0 && $newy % $my == 0} {

         set ix [expr {$newx / $mx}]
         set iy [expr {$newy / $my}]
         $dest copy $src -zoom $ix $iy
         return $dest
     }

     set ny 0
     set ytot $my

     for {set y 0} {$y < $my} {incr y} {

         #
         # Do horizontal resize
         #

         foreach {pr pg pb} [$src get 0 $y] {break}

         set row [list]
         set thisrow [list]

         set nx 0
         set xtot $mx

         for {set x 1} {$x < $mx} {incr x} {

             # Add whole pixels as necessary
             while { $xtot <= $newx } {
                 lappend row [format "#%02x%02x%02x" $pr $pg $pb]
                 lappend thisrow $pr $pg $pb
                 incr xtot $mx
                 incr nx
             }

             # Now add mixed pixels

             foreach {r g b} [$src get $x $y] {break}

             # Calculate ratios to use

             set xtot [expr {$xtot - $newx}]
             set rn $xtot
             set rp [expr {$mx - $xtot}]

             # This section covers shrinking an image where
             # more than 1 source pixel may be required to
             # define the destination pixel

             set xr 0
             set xg 0
             set xb 0

             while { $xtot > $newx } {
                 incr xr $r
                 incr xg $g
                 incr xb $b

                 set xtot [expr {$xtot - $newx}]
                 incr x
                 foreach {r g b} [$src get $x $y] {break}
             }

             # Work out the new pixel colours

             set tr [expr {int( ($rn*$r + $xr + $rp*$pr) / $mx)}]
             set tg [expr {int( ($rn*$g + $xg + $rp*$pg) / $mx)}]
             set tb [expr {int( ($rn*$b + $xb + $rp*$pb) / $mx)}]

             if {$tr > 255} {set tr 255}
             if {$tg > 255} {set tg 255}
             if {$tb > 255} {set tb 255}

             # Output the pixel

             lappend row [format "#%02x%02x%02x" $tr $tg $tb]
             lappend thisrow $tr $tg $tb
             incr xtot $mx
             incr nx

             set pr $r
             set pg $g
             set pb $b
         }

         # Finish off pixels on this row
         while { $nx < $newx } {
             lappend row [format "#%02x%02x%02x" $r $g $b]
             lappend thisrow $r $g $b
             incr nx
         }

         #
         # Do vertical resize
         #

         if {[info exists prevrow]} {

             set nrow [list]

             # Add whole lines as necessary
             while { $ytot <= $newy } {

                 $dest put -to 0 $ny [list $prow]

                 incr ytot $my
                 incr ny
             }

             # Now add mixed line
             # Calculate ratios to use

             set ytot [expr {$ytot - $newy}]
             set rn $ytot
             set rp [expr {$my - $rn}]

             # This section covers shrinking an image
             # where a single pixel is made from more than
             # 2 others.  Actually we cheat and just remove
             # a line of pixels which is not as good as it should be

             while { $ytot > $newy } {

                 set ytot [expr {$ytot - $newy}]
                 incr y
                 continue
             }

             # Calculate new row

             foreach {pr pg pb} $prevrow {r g b} $thisrow {

                 set tr [expr {int( ($rn*$r + $rp*$pr) / $my)}]
                 set tg [expr {int( ($rn*$g + $rp*$pg) / $my)}]
                 set tb [expr {int( ($rn*$b + $rp*$pb) / $my)}]

                 lappend nrow [format "#%02x%02x%02x" $tr $tg $tb]
             }

             $dest put -to 0 $ny [list $nrow]

             incr ytot $my
             incr ny
         }

         set prevrow $thisrow
         set prow $row

         update idletasks
     }

     # Finish off last rows
     while { $ny < $newy } {
         $dest put -to 0 $ny [list $row]
         incr ny
     }
     update idletasks

     return $dest
 }  


