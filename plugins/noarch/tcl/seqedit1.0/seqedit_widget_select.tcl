############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide seqedit_widget 1.0

# Define the package
namespace eval ::SeqEditWidget {
    
    # Export the package namespace.
    namespace export setSelectionNotificationCommand setSelectionNotificationVariable resetSelection getSelectionType

    # The current selection notification command, if any.
    variable selectionNotificationCommands {}
    
    # The current selection notification variable, if any.
    variable selectionNotificationVariableNames {}
    
    # The current mapping of selections.
    variable selectionMap
    array set selectionMap {}
		
    # The map to store any mouse drag state.
    variable dragStateMap
    array set dragStateMap {}
    
    # The type of the last click.
    variable lastClickType ""

    
    ############################## PUBLIC METHODS ############################
    # Methods in this section can be called by external applications.        #
    ##########################################################################

    # Set a command to be run when the current selection has changed.
    # args:     command - The command to be executed whenever the selection has changed.
    proc setSelectionNotificationCommand {command} {
        
        # Import global variables.
        variable selectionNotificationCommands
        
        set index [lsearch $selectionNotificationCommands $command]
        if {$index == -1} {
            lappend selectionNotificationCommands $command
        }
    }
    
    # Set a command to be run when the current selection has changed.
    # args:     command - The command to be executed whenever the selection has changed.
    proc setSelectionNotificationVariable {varName} {
        
        # Import global variables.
        variable selectionNotificationVariableNames
        
        lappend selectionNotificationVariableNames $varName 
    }
    
    # Resets the editor selection so that nothing is selected.
    proc resetSelection {} {
    
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # Initialize the selection map.
        unset selectionMap
        array set selectionMap {}
    
        # Create entries for the column headers.    
        for {set i 0} {$i < $numberElements} {incr i} {
            set selectionMap(h,$i) 0
        }
        
        # Go through each group and create entries for its sequences.
        foreach groupName $groupNames {
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            foreach sequenceID $sequenceIDs {
                set selectionMap($sequenceID,h) 0
                set sequenceLength [SeqData::getSeqLength $sequenceID]
                for {set i 0} {$i < $sequenceLength} {incr i} {
                    set selectionMap($sequenceID,$i) 0
                }
            }
        }
        
        # Mark that we currently have no selection type.
        set selectionMap(type) "none"
    }
    
    # Gets the current selection type. Valid values are "sequence" for a 
	# selection of sequences,
    # "position" for a selection of positions across every sequence, "cell"
	# for a selection of
    # specific positions within a subset of sequences, and "none" if there 
	# is currently no selection.
    # return:   The current selection type as "sequence", "position", "cell",
	# or "none".
    proc getSelectionType {} {
        
        # Import global variables.
        variable selectionMap
        
        return $selectionMap(type)
    }
    
    
    # Gets the currently selected sequences. If the selection is not composed
    # completely
    # of fully selected sequences, this method returns an empty list.
    # return:   A list of the sequence ids of the currently selected sequences.
    proc getSelectedSequences {} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        
        # Make sure the selection is currently composed of sequences.
        if {$selectionMap(type) == "sequence"} {
            
            # Go through the selection list and get all of the currently selected sequence ids.
            set selectedSequenceIDs {}
            foreach groupName $groupNames {
                set sequenceIDs $groupMap($groupName,sequenceIDs)
                foreach sequenceID $sequenceIDs {
                    if {$selectionMap($sequenceID,h) == 1} {
                        lappend selectedSequenceIDs $sequenceID
                    }
                }
            }
            
            return $selectedSequenceIDs
        }
        
        return {}
    }

    
    proc setSelectedSequences {sequenceIDs {notifyListeners 1}} {
        
        deselectAllSequences
        foreach sequenceID $sequenceIDs {
            if {$sequenceID != ""} {
                setSelectedSequence $sequenceID 1 0
            }
        }
    
        # Notify any selection listeners.        
        if {$notifyListeners} {
            notifySelectionChangeListeners
        }
    }
    
    
    # Set the selection status of a sequence in the editor.
    # args:     sequenceID - The id of the sequence to select.
    #           add - (default 0) If the sequence should be added to the selection.
    #           flip - (default 0) 1 if the selection for the specified sequence should be flipped.
    proc setSelectedSequence {sequenceID {add 0} {flip 0}} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        
        # If we are not already selecting sequences, reset the map.
        if {$selectionMap(type) != "sequence" && $selectionMap(type) != "none"} {
            resetSelection
            redraw
        }
        
        # Set that we are selecting sequences.
        set selectionMap(type) "sequence"
        
        # Initialize the list of sequences to redraw.
        set sequenceIDsToRedraw {}
        
        # If we are not adding to the selection, reset any sequences that are currently selected.
        if {$add == 0 && $flip == 0} {
            foreach groupName $groupNames {
                set checkingSequenceIDs $groupMap($groupName,sequenceIDs)
                foreach checkingSequenceID $checkingSequenceIDs {
                    if {$selectionMap($checkingSequenceID,h) == 1} {
                        lappend sequenceIDsToRedraw $checkingSequenceID
                        set selectionMap($checkingSequenceID,h) 0
                        set sequenceLength [SeqData::getSeqLength $checkingSequenceID]
                        for {set i 0} {$i < $sequenceLength} {incr i} {
                            set selectionMap($checkingSequenceID,$i) 0
                        }
                    }
                }
            }
        }
    
        # Determine the value we are setting the selection to.
        set value 1
        if {$flip == 1 && $selectionMap($sequenceID,h) == 1} {
            set value 0
        }
    
        # Mark the sequence as selected in the selection map.
        set selectionMap($sequenceID,h) $value
        set sequenceLength [SeqData::getSeqLength $sequenceID]
        for {set i 0} {$i < $sequenceLength} {incr i} {
            set selectionMap($sequenceID,$i) $value
        }
        lappend sequenceIDsToRedraw $sequenceID
        
        # Show the selection changes.
        redraw $sequenceIDsToRedraw
    }
    
    proc deselectAllSequences {} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        
        set sequenceIDsToRedraw {}
        foreach groupName $groupNames {
            set checkingSequenceIDs $groupMap($groupName,sequenceIDs)
            foreach checkingSequenceID $checkingSequenceIDs {
                if {$selectionMap($checkingSequenceID,h) == 1} {
                    lappend sequenceIDsToRedraw $checkingSequenceID
                    set selectionMap($checkingSequenceID,h) 0
                    set sequenceLength [SeqData::getSeqLength $checkingSequenceID]
                    for {set i 0} {$i < $sequenceLength} {incr i} {
                        set selectionMap($checkingSequenceID,$i) 0
                    }
                }
            }
        }
        if {$sequenceIDsToRedraw != {}} {
            redraw $sequenceIDsToRedraw
        }
    }
    
    # Gets the currently selected positions. If the selection is not composed completely
    # of fully selected positions, this method returns an empty list.
    # return:   A list of the indices of the currently selected positions.
    proc getSelectedPositions {} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # Make sure the selection is currently composed of sequences.
        if {$selectionMap(type) == "position"} {
            
            # Go through the selection list and get all of the currently selected sequence ids.
            set selectedPositions {}
            for {set i 0} {$i < $numberElements} {incr i} {
                if {$selectionMap(h,$i) == 1} {
                    lappend selectedPositions $i
                }
            }
            
            return $selectedPositions
        }
        
        return {}
    }

    # Set the selection status of a specific position of each sequence in the editor.
    # args:     position - The position that should be selected in each sequence.
    #           add - (default 0) If the position should be added to the selection.
    #           flip - (default 0) 1 if the selection for the specified position should be flipped.
    proc setSelectedPosition {position {add 0} {flip 0}} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # If we are not already selecting positions, reset the map.
        if {$selectionMap(type) != "position" && $selectionMap(type) != "none"} {
            resetSelection
        }
        
        # Set that we are selecting positions.
        set selectionMap(type) "position"
        
        # Initialize the list of sequences to redraw.
        set positionsToRedraw {}
        
        # If we are not adding to the selection, reset any positions that are currently selected.
        if {$add == 0 && $flip == 0} {
            for {set i 0} {$i < $numberElements} {incr i} {
                if {$selectionMap(h,$i) == 1} {
                    lappend positionsToRedraw $i
                    set selectionMap(h,$i) 0
                    foreach groupName $groupNames {
                        set sequenceIDs $groupMap($groupName,sequenceIDs)
                        foreach sequenceID $sequenceIDs {
                            if {$i < [SeqData::getSeqLength $sequenceID]} {
                                set selectionMap($sequenceID,$i) 0
                            }
                        }
                    }
                }
            }
        }
    
        # Determine the value we are setting the selection to.
        set value 1
        if {$flip == 1 && $selectionMap(h,$position) == 1} {
            set value 0
        }
    
        # Mark the position as selected in the selection map.
        set selectionMap(h,$position) $value
        foreach groupName $groupNames {
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            foreach sequenceID $sequenceIDs {
                if {$position < [SeqData::getSeqLength $sequenceID]} {
                    set selectionMap($sequenceID,$position) $value
                }
            }
        }
        lappend positionsToRedraw $position
        
        # Show the selection changes.
        redraw
    }
    
    # Set the selection status of a specific range of positions of each sequence in the editor.
    # args:     startingPosition - The starting position within the sequences to select.
    #           endingPosition - The ending position within the sequences to select.
    proc setSelectedPositionRange {startingPosition endingPosition} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # If we are not already selecting positions, reset the map.
        if {$selectionMap(type) != "position" && $selectionMap(type) != "none"} {
            resetSelection
        }
        
        # Set that we are selecting positions.
        set selectionMap(type) "position"
        
        # Go through the map and make sure only the headers in the range are selected.
        for {set i 0} {$i < $numberElements} {incr i} {
            
            # If we are in range, make sure the header is selected.
            if {$i >= $startingPosition && $i <= $endingPosition} {
                set selectionMap(h,$i) 1
                
            # Otherwise make sure it is not selected.
            } else {
                set selectionMap(h,$i) 0
            }
        }

        # Go through the map and make sure only cells in the range are selected.
        foreach groupName $groupNames {
            
            # Go through each sequence in the group.
            set sequenceIDs $groupMap($groupName,sequenceIDs)        
            foreach sequenceID $sequenceIDs {
                
                # Go through each position in the sequence.
                set sequenceLength [SeqData::getSeqLength $sequenceID]
                for {set i 0} {$i < $sequenceLength} {incr i} {
                    
                    # If we are in range, make sure the cell is selected.
                    if {$i >= $startingPosition && $i <= $endingPosition} {
                        set selectionMap($sequenceID,$i) 1
                        
                    # Otherwise make sure it is not selected.
                    } else {
                        set selectionMap($sequenceID,$i) 0
                    }
                }
            }
        }
    
        # Show the selection changes.
        redraw
    }

    # Gets the currently selected cells. This method return all of the cells that are currently
    # selected regardless of whether they were selected directly or through a row or column
    # selection.
    # return:   The currently selected cells in the format:
    #           {seq1 {pos1 pos2 ...} seq2 {pos1 pos2 ...} ...}
    proc getSelectedCells {} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        
        # Go through the selection list and get all of the currently selected sequence ids.
        set selectedCells {}
        foreach groupName $groupNames {
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            foreach sequenceID $sequenceIDs {
                set sequenceLength [SeqData::getSeqLength $sequenceID]
                set selectedPositions {}
                for {set i 0} {$i < $sequenceLength} {incr i} {                
                    if {$selectionMap($sequenceID,$i) == 1} {
                        lappend selectedPositions $i
                    }
                }
                if {[llength $selectedPositions] > 0} {
                    lappend selectedCells $sequenceID
                    lappend selectedCells $selectedPositions
                }
            }
        }
        
        return $selectedCells
    }

    
    # Set the selection status of a specific cell in the editor.
    # args:     sequenceID - The sequence that contains the cell to select.
    #           position - The position within the sequence of the cell to select.
    #           add - (default 0) If the cell should be added to the selection.
    #           flip - (default 0) 1 if the selection for the specified cell should be flipped.
    proc setSelectedCell {sequenceID position {add 0} {flip 0} {redraw 1} {notify 1}} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # If we are not already selecting elements, reset the map.
        if {$selectionMap(type) != "cell" && $selectionMap(type) != "none"} {
            resetSelection
            redraw
        }
        
        # Set that we are selecting elements.
        set selectionMap(type) "cell"
        
        # Initialize the list of sequences to redraw.
        set sequenceIDsToRedraw {}
        
        # If we are not adding to the selection, reset any elements that are currently selected.
        if {$add == 0 && $flip == 0} {
            foreach groupName $groupNames {
                set checkingSequenceIDs $groupMap($groupName,sequenceIDs)
                foreach checkingSequenceID $checkingSequenceIDs {
                    set sequenceLength [SeqData::getSeqLength $checkingSequenceID]
                    for {set i 0} {$i < $sequenceLength} {incr i} {                
                        if {$selectionMap($checkingSequenceID,$i) == 1} {
                            set selectionMap($checkingSequenceID,$i) 0
                            if {[lsearch $sequenceIDsToRedraw $checkingSequenceID] == -1} {
                                lappend sequenceIDsToRedraw $checkingSequenceID
                            }
                        }
                    }
                }
            }
        }
    
        # Determine the value we are setting the selection to.
        set value 1
        if {$flip == 1 && $selectionMap($sequenceID,$position) == 1} {
            set value 0
        }
    
        # Mark the element as selected in the selection map.
        set selectionMap($sequenceID,$position) $value
        lappend sequenceIDsToRedraw $sequenceID
        
        # Show the selection changes.
        if {$redraw == 1} {
            if {[ensureCellIsVisible $sequenceID $position] == 0} {
                redraw $sequenceIDsToRedraw
            }
        }
        if {$notify == 1} {
            notifySelectionChangeListeners
        }
    }
    
    # Set the selection to be a specific range of cells.
    # args:     startingSequenceID - The first sequence to select that contains the cells to select.
    #           endingSequenceID - The last sequence to select that contains the cells to select.
    #           startingPosition - The starting position within the sequences of the cells to select.
    #           endingPosition - The ending position within the sequences of the cells to select.
    proc setSelectedCellRange {startingSequenceID endingSequenceID startingPosition endingPosition {add 0}} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        variable selectionMap
        variable numberElements
        
        # If we are not already selecting elements, reset the map.
        if {$selectionMap(type) != "cell" && $selectionMap(type) != "none"} {
            resetSelection
            redraw
        }
        
        # Set that we are selecting elements.
        set selectionMap(type) "cell"
        
        # Initialize the list of sequences to redraw.
        set sequenceIDsToRedraw {}
        
        # Go through the map and make sure only cells in the range are selected.
        set inSequenceRange 0
        foreach groupName $groupNames {
            
            # Go through each sequence in the group.
            set checkingSequenceIDs $groupMap($groupName,sequenceIDs)        
            foreach checkingSequenceID $checkingSequenceIDs {
                
                # If this is the starting sequence, we are in range.
                if {$checkingSequenceID == $startingSequenceID} {
                    set inSequenceRange 1
                }
                
                # Go through each position in the sequence.
                set sequenceLength [SeqData::getSeqLength $checkingSequenceID]
                for {set i 0} {$i < $sequenceLength} {incr i} {
                    
                    # If we are in range, make sure the cell is selected.
                    if {$inSequenceRange == 1 && $i >= $startingPosition && $i <= $endingPosition} {
                        if {$selectionMap($checkingSequenceID,$i) == 0} {
                            set selectionMap($checkingSequenceID,$i) 1
                            if {[lsearch $sequenceIDsToRedraw $checkingSequenceID] == -1} {
                                lappend sequenceIDsToRedraw $checkingSequenceID
                            }
                        }
                        
                    # Otherwise make sure it is not selected if we are not adding.
                    } elseif {$add == 0} {
                        if {$selectionMap($checkingSequenceID,$i) == 1} {
                            set selectionMap($checkingSequenceID,$i) 0
                            if {[lsearch $sequenceIDsToRedraw $checkingSequenceID] == -1} {
                                lappend sequenceIDsToRedraw $checkingSequenceID
                            }
                        }                    
                    }
                }
                
                # If this was the ending sequence, we are out of range.
                if {$checkingSequenceID == $endingSequenceID} {
                    set inSequenceRange 0
                }            
            }
        }
        
        # Show the selection changes.
        redraw $sequenceIDsToRedraw    
    }


    
    ############################# PRIVATE METHODS #################################
    # Methods in this section should only be called from this package.            #
    ###############################################################################
    
    proc notifySelectionChangeListeners {} {
        
        # Import global variables.
        variable selectionNotificationCommands
        variable selectionNotificationVariableNames
        
        if {$selectionNotificationCommands != {}} {
            foreach selectionNotificationCommand $selectionNotificationCommands {
                $selectionNotificationCommand
            }
        }
        if {$selectionNotificationVariableNames != {}} {
            foreach selectionNotificationVariableName $selectionNotificationVariableNames {
                set $selectionNotificationVariableName 1
            }
        }
    }
    
    # Handle clicks on the row header.
    proc click_rowheader {x y type} {
        
        # Import global variables.
        variable groupNames
        variable selectionMap
        variable dragStateMap
        variable lastClickType
        
        # If this was a release and we are dragging, consider it a drop.
        if {$type == "release" && [info exists dragStateMap(startedDragging)] && $dragStateMap(startedDragging) == 1} {
            drop_rowheader $x $y

        } else {
            
            # Get the row that was clicked on.
            set row [determineRowFromLocation $x $y]
            if {$row != -1} {
            
                # Get the sequence that is in the row.
                set sequence [determineSequenceFromRow $row]
                
                # Make sure there is a sequence in the row.
                if {$sequence != {}} {
                    
                    # Make sure it wasn't a group header.
                    if {[lindex $sequence 1] != -1} {
                        
                        # See if this sequence is already selected.
                        set isSequenceSelected 0
                        if {$selectionMap(type) == "sequence" && $selectionMap([getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]],h) == 1} {
                            set isSequenceSelected 1
                        }
                        
                        # If this wasn't a release, save the dragging start information.
                        if {$type != "release"} {
                            unset dragStateMap
                            array set dragStateMap {}            
                            set dragStateMap(type) "rowheader"
                            set dragStateMap(startingRow) $row
                            set dragStateMap(startedDragging) 0
                            set dragStateMap(destinationRow) ""
                            set dragStateMap(destinationPosition) ""
                            set dragStateMap(insertionMarkerID) ""
                        }
                        
                        # If the shift key was down for the click, select all of the rows in between the selections.
                        if {$type == "shift"} {    
                            if {$selectionMap(type) == "sequence" && [info exists selectionMap(startSequence)] != 0} {
                                set sequenceIDs [getSequencesInGroups [lindex $selectionMap(startSequence) 0] [lindex $selectionMap(startSequence) 1] [lindex $sequence 0] [lindex $sequence 1]]
                                set add 0
                                foreach sequenceID $sequenceIDs {
                                    setSelectedSequence $sequenceID $add 0
                                    set add 1
                                }
                                notifySelectionChangeListeners
                            }
                            
                        # Else if the control key was down, flip the selection.
                        } elseif {$type == "control"} {
                            set selectionMap(startSequence) $sequence
                            setSelectedSequence [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]] 0 1
                            notifySelectionChangeListeners
                            
                        # Else if this was a release and the last click was a normal click and we are on a selected sequence, set the selection to this sequence.
                        } elseif {$type == "release" && [info exists dragStateMap(startedDragging)] && $dragStateMap(startedDragging) == 0 && $lastClickType == "normal" && $isSequenceSelected == 1} {
                            set selectionMap(startSequence) $sequence
                            setSelectedSequence [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]] 0 0
                            notifySelectionChangeListeners
                            
                        # Otherwise it was just a normal click on an unselected sequence, set the selection to this one sequence.
                        } elseif {$type == "normal" && $isSequenceSelected == 0} {
                            set selectionMap(startSequence) $sequence
                            setSelectedSequence [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]] 0 0
                            notifySelectionChangeListeners
                        }
                        
                        # Set the last click type.
                        set lastClickType $type
                        
                    } else {
                        
                        # If this was a control click on a header row, pretend it was a right-click on a Mac.
                        if {$type == "control"} {
                            rightclick_rowheader $x $y
                        }
                    }
                }
            }
        }
    }
    
    # Handle drags on the row header.
    proc drag_rowheader {x y} {
        
        # Import global variables.
        variable editor
        variable groupNames
        variable groupMap
        variable numberRows
        variable firstGroup
        variable firstSequence
        variable cellColorForeground
        variable columnObjectMap
        variable dragStateMap
        
        # See if we are really dragging a row header.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "rowheader"} {
        
            # Get the row that is being dropped onto.
            set destinationRow [determineRowFromLocation $x $y]
            
            # See if we are dropping onto a row.
            if {$destinationRow != -1 && ($dragStateMap(startingRow) != $destinationRow || $dragStateMap(startedDragging) == 1)} {
                    
                set dragStateMap(startedDragging) 1
                set x1 $columnObjectMap(h,$destinationRow.x1)
                set x2 $columnObjectMap(h,$destinationRow.x2)
                set y1 $columnObjectMap(h,$destinationRow.y1)
                set y2 $columnObjectMap(h,$destinationRow.y2)
                
                # See if we are going above or below the new row.
                if {[expr $y-$y1] <= [expr $y2-$y]} {
                    set destinationPosition "before"
                } else {
                    set destinationPosition "after"
                }
                
                # If the destination has changed, update it.
                if {$dragStateMap(destinationRow) != $destinationRow || $dragStateMap(destinationPosition) != $destinationPosition} {
                    
                    # Get the sequence that is in the destination row.
                    set destinationSequence [determineSequenceFromRow $destinationRow]
                    
                    # Make sure there is a sequence in the destination row.
                    if {$destinationSequence != {}} {
                    
                        # Set the new destination variables.
                        set dragStateMap(destinationRow) $destinationRow
                        set dragStateMap(destinationPosition) $destinationPosition
            
                        # If we already have a marker, delete it.
                        if {$dragStateMap(insertionMarkerID) != ""} {
                            $editor delete $dragStateMap(insertionMarkerID)
                        }
                    
                        # Create a new marker.
                        if {$destinationPosition == "before"} {
                            set dragStateMap(insertionMarkerID) [$editor create line $x1 $y1 $x2 $y1 -width 2 -fill $cellColorForeground]
                        } else {
                            set dragStateMap(insertionMarkerID) [$editor create line $x1 [expr $y2+1] $x2 [expr $y2+1] -width 2 -fill $cellColorForeground]
                        }
                    }
                }
            }
            
            # See if we should try to scroll the screen up.
            if {$destinationRow == 0 || ($destinationRow == -1 && $y <= $columnObjectMap(h,0.y1))} {
                
                # If the screen can be scrolled up at all, scroll it up.
                if {($firstGroup == 0 && $firstSequence > -1) || ($firstGroup > 0)} {
                    scroll_vertical scroll -1 unit
                }
            
            # See if we should try to scroll the screen down.
            } elseif {$destinationRow == [expr $numberRows-1] || ($destinationRow == -1 && $y >= $columnObjectMap(h,[expr $numberRows-1].y1))} {
    
                # If the screen can be scrolled down at all, scroll it down.
                set lastSequence [determineSequenceFromRow [expr $numberRows-2]]
                if {$lastSequence != {}} {
                    set lastGroupIndex [lindex $lastSequence 0]
                    set lastSequenceIndex [lindex $lastSequence 1]
                    if {($lastGroupIndex < [expr [llength $groupNames]-1]) || ($lastGroupIndex == [expr [llength $groupNames]-1] && $lastSequenceIndex < [expr $groupMap([lindex $groupNames $lastGroupIndex],numberSequences)-1])} {
                        scroll_vertical scroll 1 unit
                    }
                }
            }
        }
    }
    
    # Handle drops on the row header.
    proc drop_rowheader {x y} {
        
        # Import global variables.
        variable editor
        variable dragStateMap
        variable groupNames
        
        # See if we were really dragging something.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "rowheader" && $dragStateMap(startedDragging) == 1} {
        
            # If we have a marker, delete it.
            if {$dragStateMap(insertionMarkerID) != ""} {
                $editor delete $dragStateMap(insertionMarkerID)
            }
            
            # Get the sequence that is in the destination row and make sure it is not a grouping.
            set sequence [determineSequenceFromRow $dragStateMap(destinationRow)]
            set groupIndex [lindex $sequence 0]
            set sequenceIndex [lindex $sequence 1]
            if {$dragStateMap(destinationPosition) == "after"} {incr sequenceIndex}
            if {$dragStateMap(destinationPosition) == "before" && $sequenceIndex == -1} {incr groupIndex -1; set sequenceIndex end}
            if {$groupIndex < 0} {set groupIndex 0; set sequenceIndex 0}
            
            # Get the current selection.
            set selectedSequenceIDs [getSelectedSequences]
            moveSequences $selectedSequenceIDs [lindex $groupNames $groupIndex] $sequenceIndex
            validateScrollRange 0 1
            setScrollbars
            redraw
        }
        
        # Remove everything from the drag state.
        unset dragStateMap
        array set dragStateMap {}
    }
    
    # Handle clicks on the column header.
    proc click_columnheader {x y type} {
                
        # Import global variables.
        variable dragStateMap
        variable selectionMap
        
        # Get the row that was clicked on.
        set column [determineColumnFromLocation $x $y]
        if {$column != -1} {
        
            # Get the sequence that is in the row.
            set position [determinePositionFromColumn $column]
            
            # Make sure there is an element in the row.
            if {$position != -1} {
                
                # Save the drag state in case the user tries to drag the selection.
                set dragStateMap(type) "position"
                set dragStateMap(startingColumn) $column
                set dragStateMap(startingPosition) $position
                set dragStateMap(destinationColumn) $column
                set dragStateMap(destinationPosition) $position
                set dragStateMap(startedDragging) 0
                
                # If the shift key was down for the click, select all of the rows in between the selections.
                if {$type == "shift"} {
                    if {$selectionMap(type) == "position" && [info exists selectionMap(lastPosition)] != 0} {
                        if {$selectionMap(lastPosition) < $position} {
                            set p1 $selectionMap(lastPosition)
                            set p2 $position
                        } else {
                            set p2 $selectionMap(lastPosition)
                            set p1 $position
                        }
                        setSelectedPositionRange $p1 $p2
                        notifySelectionChangeListeners
                    }    
                    
                # Else if the control key was down, flip the selection.
                } elseif {$type == "control"} {
                    setSelectedPosition $position 0 1
                    notifySelectionChangeListeners
                    if {[info exists selectionMap(lastPosition)] != 0} {
                        unset selectionMap(lastPosition)
                    }
                    
                # Otherwise it was just a normal click, set the selection to this one sequence.
                } else {
                    setSelectedPosition $position 0 0
                    notifySelectionChangeListeners
                    set selectionMap(lastPosition) $position
                }
            }
        }
    }
    
    # Handle drags on the row header.
    proc move_columnheader {x y} {
        
        # Import global variables.
        variable dragStateMap
        
        # See if we are really dragging a row header.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "position"} {
    
            # Get the that is being dragged onto.
            set destinationColumn [determineColumnFromLocation $x $y]
            
            # See if we are dragging onto a different row or column.
            if {$destinationColumn != -1 && $dragStateMap(destinationColumn) != $destinationColumn} {
                
                # Save that we are dragging.
                set dragStateMap(startedDragging) 1
                    
                # Set the new destination variable.
                set dragStateMap(destinationColumn) $destinationColumn
                        
                # Get the position that is in the destination column.
                set destinationPosition [determinePositionFromColumn $destinationColumn]
                set dragStateMap(destinationPosition) $destinationPosition
                
                # Make sure there is a real position in the column.
                if {$destinationPosition != -1} {
                
                    # Make sure we have the starting and ending ordered correctly.
                    if {$dragStateMap(startingColumn) < $destinationColumn} {
                        set p1 $dragStateMap(startingPosition)
                        set p2 $destinationPosition
                    } else {
                        set p2 $dragStateMap(startingPosition)
                        set p1 $destinationPosition
                    }
                    
                    # Select all of the cells between the start and the end point.
                    setSelectedPositionRange $p1 $p2                    
                }
            }
        }
    }
    
    proc release_columnheader {x y} {
        
        # Import global variables.
        variable dragStateMap
        
        # If we were dragging, send a notification that the selection has changed.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "position" && $dragStateMap(startedDragging) == 1} {
            notifySelectionChangeListeners
        }
    }

    # Handle clicks on the row header.
    proc click_cell {x y type} {
        
        # Import global variables.
        variable groupNames
        variable selectionMap
        variable dragStateMap
        
        # Rest the drag state.
        unset dragStateMap
        array set dragStateMap {}
        
        # Get the row that was clicked on.
        set row [determineRowFromLocation $x $y]
        set column [determineColumnFromLocation $x $y]
        if {$row != -1 && $column != -1} {
        
            # Get the sequence that is in the row and position that is in the column.
            set sequence [determineSequenceFromRow $row]
            set position [determinePositionFromColumn $column]
            
            # Make sure there is a real sequence in the row and a valid position in the column.
            if {$sequence != {} && [lindex $sequence 1] != -1 && $position != -1} {
                
                # Save the drag state in case the user tries to drag the selection.
                set dragStateMap(type) "cell"
                set dragStateMap(startingRow) $row
                set dragStateMap(startingColumn) $column
                set dragStateMap(startingSequence) $sequence
                set dragStateMap(startingPosition) $position
                set dragStateMap(destinationRow) $row
                set dragStateMap(destinationColumn) $column
                set dragStateMap(destinationSequence) $sequence
                set dragStateMap(destinationPosition) $position
                set dragStateMap(startedDragging) 0
                
                # If the shift key was down for the click, select all of the rows in between the selections.
                if {[lindex $type 0] == "shift"} {
                    if {$selectionMap(type) == "cell" && [info exists selectionMap(lastSequence)] != 0 && [info exists selectionMap(lastRow)] != 0 && [info exists selectionMap(lastPosition)] != 0} {
                        if {$selectionMap(lastRow) < $row} {
                            set s1 [getSequenceInGroup [lindex $groupNames [lindex $selectionMap(lastSequence) 0]] [lindex $selectionMap(lastSequence) 1]]
                            set s2 [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]]
                        } else {
                            set s2 [getSequenceInGroup [lindex $groupNames [lindex $selectionMap(lastSequence) 0]] [lindex $selectionMap(lastSequence) 1]]
                            set s1 [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]]
                        }
                        if {$selectionMap(lastPosition) < $position} {
                            set p1 $selectionMap(lastPosition)
                            set p2 $position
                        } else {
                            set p2 $selectionMap(lastPosition)
                            set p1 $position
                        }
                        if {[llength $type] == 2 && [lindex $type 1] == "control"} {
                            setSelectedCellRange $s1 $s2 $p1 $p2 1
                        } else {
                            setSelectedCellRange $s1 $s2 $p1 $p2
                        }
                        notifySelectionChangeListeners
                    }    
                        
                # Else if the control key was down, flip the selection.
                } elseif {[lindex $type 0] == "control"} {
                    setSelectedCell [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]] $position 0 1
                    set selectionMap(lastRow) $row
                    set selectionMap(lastSequence) $sequence
                    set selectionMap(lastPosition) $position
                        
                # Otherwise it was just a normal click, set the selection to this one sequence.
                } else {
                    setSelectedCell [getSequenceInGroup [lindex $groupNames [lindex $sequence 0]] [lindex $sequence 1]] $position 0 0
                    set selectionMap(lastRow) $row
                    set selectionMap(lastSequence) $sequence
                    set selectionMap(lastPosition) $position
                }
            }
        }
    }
    
    # Handle drags on the row header.
    proc move_cell {x y} {
        
        # Import global variables.
        variable editor
        variable groupNames
        variable groupMap
        variable numberRows
        variable firstGroup
        variable firstSequence
        variable cellColorForeground
        variable columnObjectMap
        variable dragStateMap
        
        # See if we are really dragging a row header.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "cell"} {
    
            # Get the row and column that are being dragged onto.
            set destinationRow [determineRowFromLocation $x $y]
            set destinationColumn [determineColumnFromLocation $x $y]
            
            # See if we are dragging onto a different row or column.
            if {$destinationRow != -1 && $destinationColumn != -1 && ($dragStateMap(destinationRow) != $destinationRow || $dragStateMap(destinationColumn) != $destinationColumn)} {
                
                # Save that we are dragging.
                set dragStateMap(startedDragging) 1
                    
                # Set the new destination variables.
                set dragStateMap(destinationRow) $destinationRow
                set dragStateMap(destinationColumn) $destinationColumn
                        
                # Get the sequence that is in the destination row.
                set destinationSequence [determineSequenceFromRow $destinationRow]
                set destinationPosition [determinePositionFromColumn $destinationColumn]
                set dragStateMap(destinationSequence) $destinationSequence
                set dragStateMap(destinationPosition) $destinationPosition
                
                # Make sure there is a real sequence in the row and a valid position in the column.
                if {$destinationSequence != {} && [lindex $destinationSequence 1] != -1 && $destinationPosition != -1} {
                
                    # Make sure we have the starting and ending ordered correctly.
                    if {$dragStateMap(startingRow) < $destinationRow} {
                        set s1 [getSequenceInGroup [lindex $groupNames [lindex $dragStateMap(startingSequence) 0]] [lindex $dragStateMap(startingSequence) 1]]
                        set s2 [getSequenceInGroup [lindex $groupNames [lindex $destinationSequence 0]] [lindex $destinationSequence 1]]
                    } else {
                        set s2 [getSequenceInGroup [lindex $groupNames [lindex $dragStateMap(startingSequence) 0]] [lindex $dragStateMap(startingSequence) 1]]
                        set s1 [getSequenceInGroup [lindex $groupNames [lindex $destinationSequence 0]] [lindex $destinationSequence 1]]
                    }
                    if {$dragStateMap(startingColumn) < $destinationColumn} {
                        set p1 $dragStateMap(startingPosition)
                        set p2 $destinationPosition
                    } else {
                        set p2 $dragStateMap(startingPosition)
                        set p1 $destinationPosition
                    }
                    
                    # Select all of the cells between the start and the end point.
                    setSelectedCellRange $s1 $s2 $p1 $p2                    
                }
            
            
            # See if we should try to scroll the screen up.
            #if {$destinationRow == 0 || ($destinationRow == -1 && $y <= $columnObjectMap(h,0.y1))} {
                
                # If the screen can be scrolled up at all, scroll it up.
            #    if {($firstGroup == 0 && $firstSequence > -1) || ($firstGroup > 0)} {
            #        scroll_vertical scroll -1 unit
            #    }
            
            # See if we should try to scroll the screen down.
            #} elseif {$destinationRow == [expr $numberRows-1] || ($destinationRow == -1 && $y >= $columnObjectMap(h,[expr $numberRows-1].y1))} {
    
                # If the screen can be scrolled down at all, scroll it down.
            #    set lastSequence [determineSequenceFromRow [expr $numberRows-2]]
            #    if {$lastSequence != {}} {
            #        set lastGroupIndex [lindex $lastSequence 0]
            #       set lastSequenceIndex [lindex $lastSequence 1]
            #        if {($lastGroupIndex < [expr [llength $groupNames]-1]) || ($lastGroupIndex == [expr [llength $groupNames]-1] && $lastSequenceIndex < [expr $groupMap([lindex $groupNames $lastGroupIndex],numberSequences)-1])} {
            #            scroll_vertical scroll 1 unit
            #        }
            #    }
            #}
            }
        }
    }
    
    proc release_cell {x y} {
        
        # Import global variables.
        variable dragStateMap
        
        # If we were dragging, send a notification that the selection has changed.
        if {[info exists dragStateMap(type)] != 0 && $dragStateMap(type) == "cell" && $dragStateMap(startedDragging) == 1} {
            notifySelectionChangeListeners
        }
    }
}
