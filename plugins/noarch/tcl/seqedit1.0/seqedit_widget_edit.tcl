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
    
    # Valid editing modes.
    variable EDITINGMODE_NONE   0
    variable EDITINGMODE_GAP    1
    variable EDITINGMODE_ALL    2
    
    # The current editing mode
    variable editingMode $EDITINGMODE_NONE
    
    # The current selection notification variable, if any.
    variable insertMode 1
    
    
    ############################## PUBLIC METHODS #################################
    # Methods in this section can be called by external applications.             #
    ###############################################################################

    
    # Deletes the current selection from the editor. The behavior of this method depends upon the
    # current selection type.
    # args:     backspace - Whether the deletion type should be considered a "backspace" delete. (0/1)
    proc deleteSelection {{backspace 0}} {
        
        # See what type of selection type we currently have.
        set selectionType [getSelectionType]
        if {$selectionType == "sequence"} {
            removeSequences [getSelectedSequences]
        } elseif {$selectionType == "position"} {
            deletePositions [getSelectedPositions]
        } elseif {$selectionType == "cell"} {
            
            # Get the current selection.
            set selectedCells [getSelectedCells]
            
            # See if we are in single cell mode.
            if {[llength $selectedCells] == 2 && [llength [lindex $selectedCells 1]] == 1} {
                set sequenceID [lindex $selectedCells 0]
                set position [lindex [lindex $selectedCells 1] 0]
                if {$backspace == 0} {
                    
                    # Delete the cell.
                    if {[deleteCells2 $selectedCells] == 1} {
                        
                        # Make sure the position is not past the end of the sequence.
                        set maxPosition [expr [SeqData::getSeqLength $sequenceID]-1]
                        if {$position >= $maxPosition} {
                            set position $maxPosition
                        }
                        
                        # Set the new selection.
                        setSelectedCell $sequenceID $position
                    }
                } else {
                    if {$position > 0} {
                        
                        # Delete the cells.
                        if {[deleteCells2 [list $sequenceID [list [expr $position-1]]]] == 1} {
                        
                            # Set the new selection.
                            setSelectedCell $sequenceID [expr $position-1]
                        }
                    }
                }
            } else {
                # Delete the cell.
                if {[deleteCells2 $selectedCells] == 1} {
                
                    # Set the new selection.
                    set sequenceID [lindex $selectedCells 0]
                    set position [lindex [lindex $selectedCells 1] 0]
                    set maxPosition [expr [SeqData::getSeqLength $sequenceID]-1]
                    if {$position >= $maxPosition} {
                        set position $maxPosition
                    }                
                    setSelectedCell [lindex $selectedCells 0] [lindex [lindex $selectedCells 1] 0]
                }
            }
        }
    }
    
    proc setSelection {newElement} {

        # Import global variables.
        variable insertMode
        
        # Get the current selection.
        set selectedCells [getSelectedCells] 
        
        # See if we are in editing mode.
        if {[llength $selectedCells] == 2 && [llength [lindex $selectedCells 1]] == 1} {
            
            set sequenceID [lindex $selectedCells 0]
            set position [lindex [lindex $selectedCells 1] 0]
            if {$insertMode == 1} {
                
                # Insert the gap.
                if {[insertElements $sequenceID $position $newElement] == 1} {
                    
                    # Set the new position
                    set position [expr $position+1]
                    
                    # Make sure the position is not past the end of the sequence.
                    set maxPosition [expr [SeqData::getSeqLength $sequenceID]-1]
                    if {$position >= $maxPosition} {
                        set position $maxPosition
                    }
                        
                    # Set the new selection.
                    setSelectedCell $sequenceID $position
                }
            } else {
            
                # Replace the cells.
                if {[setCells $selectedCells $newElement] == 1} {
                
                    # Set the new position
                    set position [expr $position+1]
                    
                    # Make sure the position is not past the end of the sequence.
                    set maxPosition [expr [SeqData::getSeqLength $sequenceID]-1]
                    if {$position >= $maxPosition} {
                        set position $maxPosition
                    }
                        
                    # Set the new selection.
                    setSelectedCell $sequenceID $position
                }
            }
        } else {
            
            # Figure out if one column is selected in each sequence.
            set allOneLong 1
            for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                if {[llength [lindex $selectedCells [expr $i+1]]] != 1} {
                    set allOneLong 0
                }
            }
            
            # If one cell in each row is selected, insert the new selection before the selected cells.
            if {$allOneLong && $insertMode} {
                
                # Figure out the insertion parameters.
                set sequenceIDs {}
                set positions {}
                set newElementValuesLists {}               
                for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                    lappend sequenceIDs [lindex $selectedCells $i]
                    lappend positions [lindex $selectedCells [expr $i+1]]
                    lappend newElementValuesLists [list $newElement]
                }
                
                # Perform the insertion.
                if {[insertElements $sequenceIDs $positions $newElementValuesLists]} {
                    
                    # Move the selection.
                    set addPosition 0
                    for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                        setSelectedCell [lindex $selectedCells $i] [expr [lindex $selectedCells [expr $i+1]]+1] $addPosition 0
                        set addPosition 1
                    }
                }
                
            } else {
                
                # Replace the cells.
                setCells $selectedCells $newElement
            }
        }
    }
    
    # Deletes the specified positions from all of the sequences in the editor.
    # args:     positions -  A list of the positions to delete from the sequences. NOTE: These MUST
    #                        be in increasing order.
    proc deletePositions {positions} {

        # Import global variables.
        variable EDITINGMODE_NONE
        variable EDITINGMODE_GAP
        variable EDITINGMODE_ALL
        variable editingMode        
        variable numberElements
        variable groupNames
        variable groupMap
    
        # If we are violating our current editing mode, stop.            
        if {$editingMode == $EDITINGMODE_NONE} {
            return 0
        } elseif {$editingMode == $EDITINGMODE_GAP} {
            
            # If there is anything other than gaps in the selection, stop.
            foreach groupName $groupNames {
                set sequenceIDs $groupMap($groupName,sequenceIDs)
                foreach sequenceID $sequenceIDs {
                    set sequence [SeqData::getSeq $sequenceID]
                    foreach position $positions {
                        if {[lindex $sequence $position] != "-"} {
                            return 0
                        }
                    }
                }
            }
        }
            
        # Go through the sequences and delete the elements at the positions from each one.
        foreach groupName $groupNames {
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            foreach sequenceID $sequenceIDs {
                
                # Save the original sequence length.
                set oldSequenceLength [::SeqData::getSeqLength $sequenceID]
                
                # Remove the elements from the sequence.
                ::SeqData::removeElements $sequenceID $positions
                
                # Update the color map.
                updateColorMap $sequenceID $oldSequenceLength [::SeqData::getSeqLength $sequenceID] "delete" $positions        
            }
        }
        
        # Decrement the number of positions in the editor.
        incr numberElements -[llength $positions]

        # Refresh the editor display.
        resetSelection
        setScrollbars
        redraw
        
        return 1        
    }
    
    # Deletes the specified cells from the editor.     
    # args:     cells - The cells to delete in the format:
    #                   {seq1 {pos1 pos2 ...} seq2 {pos1 pos2 ...} ...}
    #                   NOTE: The positions within a sequence MUST be in increasing order.
    proc deleteCells2 {cells} {
        
        # Import global variables.
        variable EDITINGMODE_NONE
        variable EDITINGMODE_GAP
        variable EDITINGMODE_ALL
        variable editingMode        
        variable numberElements
        variable groupNames
        variable groupMap
    
        # If we are violating our current editing mode, stop.            
        if {$editingMode == $EDITINGMODE_NONE} {
            return 0
        } elseif {$editingMode == $EDITINGMODE_GAP} {
            
            # If there is anything other than gaps in the selection, stop.
            for {set i 0} {$i < [llength $cells]} {incr i 2} {
                set sequence [SeqData::getSeq [lindex $cells $i]]
                set deletedElements [lindex $cells [expr $i+1]]
                foreach deletedElement $deletedElements {
                    if {[lindex $sequence $deletedElement] != "-"} {
                        return 0
                    }
                }
            }            
        }
            
        # Remove the elements from the sequences.
        set sequenceIDsToRedraw {}
        for {set i 0} {$i < [llength $cells]} {incr i 2} {
            
            # Get the sequence id and the element to remove.
            set sequenceID [lindex $cells $i]
            set deletedElements [lindex $cells [expr $i+1]]
            
            # Save the original sequence length.
            set oldSequenceLength [::SeqData::getSeqLength $sequenceID]
            
            # Remove the elements from the sequence.
            ::SeqData::removeElements $sequenceID $deletedElements
            
            # Update the color map.
            updateColorMap $sequenceID $oldSequenceLength [::SeqData::getSeqLength $sequenceID] "delete" $deletedElements
        
            # Mark that we need to redraw this sequence.
            lappend sequenceIDsToRedraw $sequenceID
        }        

        # Recalculate the number of positions in the editor.
        set numberElements 0
        foreach groupName $groupNames {
            set sequenceIDs $groupMap($groupName,sequenceIDs)
            foreach sequenceID $sequenceIDs {
                set sequenceLength [SeqData::getSeqLength $sequenceID]
                if {$sequenceLength > $numberElements} {
                    set numberElements $sequenceLength
                }
            }
        }
        
        # Refresh the editor display.
        setScrollbars
        redraw $sequenceIDsToRedraw
        
        return 1
    }
        
    # Set the elements in the specified cells in the editor to a new element.     
    # args:     cells - The cells to replace in the format:
    #                   {seq1 {pos1 pos2 ...} seq2 {pos1 pos2 ...} ...}
    #                   NOTE: The positions within a sequence MUST be in increasing order.
    #           newElement - The new element to placed in the cells.
    proc setCells {cells newElements} {
        
        # Import global variables.
        variable EDITINGMODE_NONE
        variable EDITINGMODE_GAP
        variable EDITINGMODE_ALL
        variable editingMode        
        variable groupNames
        variable groupMap
    
        # If we are violating our current editing mode, stop.            
        if {$editingMode == $EDITINGMODE_NONE} {
            return 0
        } elseif {$editingMode == $EDITINGMODE_GAP} {
            
            foreach newElement $newElements {
                if {$newElement != "-"} {
                    return 0
                }
            }
            
            # If there is anything other than gaps in the selection, stop.
            for {set i 0} {$i < [llength $cells]} {incr i 2} {
                set sequence [SeqData::getSeq [lindex $cells $i]]
                set positions [lindex $cells [expr $i+1]]
                foreach position $positions {
                    if {[lindex $sequence $position] != "-"} {
                        return 0
                    }
                }
            }            
        }
            
        # Remove the positions from the sequences.
        set sequenceIDsToRedraw {}
        set newElementIndex 0
        for {set i 0} {$i < [llength $cells]} {incr i 2} {
            set sequenceID [lindex $cells $i]
            set positions [lindex $cells [expr $i+1]]
            SeqData::setElements $sequenceID $positions [lindex $newElements $newElementIndex]
            if {$newElementIndex < [expr [llength $newElements]-1]} {
                incr newElementIndex
            }
            lappend sequenceIDsToRedraw $sequenceID
        }
        
        # Refresh the editor display.
        redraw $sequenceIDsToRedraw
        
        return 1        
    }
    
    proc insertElements {sequenceIDs atElements newElementValuesLists} {
        
        # Import global variables.
        variable EDITINGMODE_NONE
        variable EDITINGMODE_GAP
        variable EDITINGMODE_ALL
        variable editingMode        
        variable numberElements
        variable selectionMap
        
        # If only a single sequence id was passed in, readjust the parameters.
        if {[llength $sequenceIDs] == 1 && [llength $newElementValuesLists] != 1} {
            set newElementValuesLists [list $newElementValuesLists]
        }
        
        # If we are violating our current editing mode, stop.            
        if {$editingMode == $EDITINGMODE_NONE} {
            return 0
        } elseif {$editingMode == $EDITINGMODE_GAP} {
            
            # If there is anything other than gaps in the selection, stop.
            foreach newElementValues $newElementValuesLists {
                foreach newElementValue $newElementValues {
                    if {$newElementValue != "-"} {
                        return 0
                    }
                }
            }
        }

        set sequenceIDsToRedraw {}
        for {set i 0} {$i < [llength $sequenceIDs] && $i < [llength $atElements] && $i < [llength $newElementValuesLists]} {incr i} {
            
            set sequenceID [lindex $sequenceIDs $i]
            set atElement [lindex $atElements $i]
            set newElementValues [lindex $newElementValuesLists $i]
            
            # Insert the new elements.
            set oldSequenceLength [SeqData::getSeqLength $sequenceID]
            ::SeqData::insertElements $sequenceID $atElement $newElementValues
            set newSequenceLength [SeqData::getSeqLength $sequenceID]
            
            # Update the color map.
            updateColorMap $sequenceID $oldSequenceLength $newSequenceLength "insert" $atElement
            
            # Extend the selection map for this sequence.
            for {set j $oldSequenceLength} {$j < $newSequenceLength} {incr j} {
                set selectionMap($sequenceID,$j) 0
            }
            
            # See if we need to increase the total number of elements in the editor.
            if {$numberElements < $newSequenceLength} {
                for {set j $numberElements} {$j < $newSequenceLength} {incr j} {
                    set selectionMap(h,$j) 0
                }
                set numberElements $newSequenceLength
            }
            
            lappend sequenceIDsToRedraw $sequenceID
        }
        
        # Refresh the editor display.
        setScrollbars
        redraw $sequenceIDsToRedraw
        
        return 1        
    }
        
    proc updateColorMap {sequenceID oldSequenceLength newSequenceLength updateType updateParameter} {

        # Import global variables.
        variable coloringMap
        
        # See what type of update we are performing.
        if {$updateType == "insert"} {
            
            set insertAtElement $updateParameter
            
            # Copy over the old values.
            set addedElements [expr $newSequenceLength-$oldSequenceLength]
            for {set oldElement [expr $oldSequenceLength-1]} {$oldElement >= $insertAtElement} {incr oldElement -1} {
                
                # Calculate the new element.
                set newElement [expr $oldElement+$addedElements]
                
                # Copy the coloring.
                set coloringMap($sequenceID,$newElement,rgb) $coloringMap($sequenceID,$oldElement,rgb)
                set coloringMap($sequenceID,$newElement,raw) $coloringMap($sequenceID,$oldElement,raw)
            }
            
            # Create empty values for the new elements.
            for {set i 0} {$i < $addedElements} {incr i} {
                
                # Calculate the new element.
                set newElement [expr $insertAtElement+$i]
                
                # Create  the new elements.
                set coloringMap($sequenceID,$newElement,rgb) "#FFFFFF"
                set coloringMap($sequenceID,$newElement,raw) 0.0
            }
            
        } elseif {$updateType == "delete"} {
            
            set updatedElements $updateParameter
    
            # Go through each element in the original sequence.
            set removedIndex 0
            set newElement 0
            for {set oldElement 0} {$oldElement < $oldSequenceLength} {incr oldElement} {
                
                # If this element was removed.
                if {$oldElement == [lindex $updatedElements $removedIndex]} {
                    
                    # Skip this element and increment our position in the removed list.
                    incr removedIndex
                    
                # Otherwise, this element was not removed.
                } else {
                
                    # Copy the coloring.
                    set coloringMap($sequenceID,$newElement,rgb) $coloringMap($sequenceID,$oldElement,rgb)
                    set coloringMap($sequenceID,$newElement,raw) $coloringMap($sequenceID,$oldElement,raw)
                    
                    # Increment the new element counter.
                    incr newElement
                }
            }
        }
    }
    
    proc moveCursor {horizontalSpaces verticalSpaces} {
        
        # Import global variables.
        variable groupNames
        variable groupMap
        
        # If we have a selection, use its top-left as the starting position.
        set selectedCells [getSelectedCells] 
        if {[llength $selectedCells] >= 2 && [llength [lindex $selectedCells 1]] >= 1} {
            set sequenceID [lindex $selectedCells 0]
            set position [lindex [lindex $selectedCells 1] 0]
        }
        
        # If we are moving vertically, figure out the new sequence id.
        if {$verticalSpaces != 0} {
            
            # Figure out the group and sequence indexes of the current sequence.
            set groupIndex 0
            set sequenceIndex 0
            for {set i 0} {$i < [llength $groupNames]} {incr i} {
                set sequenceIDs $groupMap([lindex $groupNames $i],sequenceIDs)
                for {set j 0} {$j < [llength $sequenceIDs]} {incr j} {
                    if {$sequenceID == [lindex $sequenceIDs $j]} {
                        set groupIndex $i
                        set sequenceIndex $j
                        break;
                    }
                }
            }
            
            # Figure out the new sequence index.
            set sequenceIndex [expr $sequenceIndex+$verticalSpaces]
            
            # If we have gone above the current group, find the right group.
            while {$sequenceIndex < 0 && $groupIndex > 0} {
                incr groupIndex -1
                set sequenceIndex [expr $sequenceIndex+$groupMap([lindex $groupNames $groupIndex],numberSequences)]
            }
            
            # If we are above all of the groups, set it to be the first sequence.
            if {$sequenceIndex < 0} {
                for {set i 0} {$i < [llength $groupNames]} {incr i} {
                    if {$groupMap([lindex $groupNames $i],numberSequences) > 0} {
                        set groupIndex $i
                        set sequenceIndex 0
                        break;
                    }
                }
            }
            
            # If we have gone below the current group, find the right group.
            while {$sequenceIndex >= $groupMap([lindex $groupNames $groupIndex],numberSequences) && $groupIndex < [expr [llength $groupNames]-1]} {
                set sequenceIndex [expr $sequenceIndex-$groupMap([lindex $groupNames $groupIndex],numberSequences)]
                incr groupIndex
            }
            
            # If we are below all of the groups, set it to be the last sequence.
            if {$sequenceIndex >= $groupMap([lindex $groupNames $groupIndex],numberSequences)} {
                for {set i [expr [llength $groupNames]-1]} {$i >= 0} {incr i -1} {
                    if {$groupMap([lindex $groupNames $i],numberSequences) > 0} {
                        set groupIndex $i
                        set sequenceIndex [expr $groupMap([lindex $groupNames $i],numberSequences)-1]
                        break;
                    }
                }
            }
            
            # Set the new sequence id.
            set sequenceID [lindex $groupMap([lindex $groupNames $groupIndex],sequenceIDs) $sequenceIndex]
        }
        
        # If we are moving horizontally, figure out the new position.
        if {$horizontalSpaces != 0} {
            set position [expr $position+$horizontalSpaces]
            if {$position < 0} {
                set position 0
            }
        }
        
        # Make sure the position is not past the end of the sequence.
        set maxPosition [expr [SeqData::getSeqLength $sequenceID]-1]
        if {$position >= $maxPosition} {
            set position $maxPosition
        }
        
        # Set the new selection.
        setSelectedCell $sequenceID $position
    }
    
    proc toggleInsertMode {} {

        # Import global variables.
        variable insertMode
        
        if {$insertMode == 0} {
            set insertMode 1
        } else {
            set insertMode 0
        }
    }
    
    
    ############################# PRIVATE METHODS #################################
    # Methods in this section should only be called from this package.            #
    ###############################################################################
    
    proc editor_keypress {key} {
        
        # See what to do with the key press.
        if {$key == "Delete"} {
            deleteSelection
        } elseif {$key == "BackSpace"} {
            deleteSelection 1
        } elseif {$key == "Left"} {
            moveCursor -1 0
        } elseif {$key == "Right"} {
            moveCursor 1 0
        } elseif {$key == "Up"} {
            moveCursor 0 -1
        } elseif {$key == "Down"} {
            moveCursor 0 1
        } elseif {$key == "Home"} {
            moveCursor -999999 0
        } elseif {$key == "End"} {
            moveCursor 999999 0
        } elseif {$key == "space" || $key == "period" || $key == "minus"} {
            setSelection "-"
        } elseif {[string length $key] == 1 && [regexp {[A-Z]|[a-z]} $key] == 1} {
            setSelection [string toupper $key]
        } elseif {$key == "Insert" || $key == "Help"} {
            toggleInsertMode
        }
    }
    
    proc editor_cut {} {
        editor_copy
        deleteSelection
    }
    
    proc editor_copy {} {

        # See what type of selection we currently have.
        set selectionType [getSelectionType]
        if {$selectionType == "sequence"} {
            clipboard clear
            clipboard append [::SeqData::Fasta::getFastaData [getSelectedSequences]]
        } elseif {$selectionType == "position" || $selectionType == "cell"} {
            
            # Copy the selected cells to the clipboard.
            set selectionLines {}
            set selectedCells [getSelectedCells]
            for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                set sequence [SeqData::getSeq [lindex $selectedCells $i]]
                set selectionValues {}
                set elements [lindex $selectedCells [expr $i+1]]
                foreach element $elements {
                    lappend selectionValues [lindex $sequence $element]
                }
                lappend selectionLines [join $selectionValues ""]
            }
            
            set selectionString [join $selectionLines "\n"]
            clipboard clear
            clipboard append $selectionString
        }
    }
    
    proc editor_paste {} {
        
        # Import global variables.
        variable EDITINGMODE_NONE
        variable EDITINGMODE_GAP
        variable EDITINGMODE_ALL
        variable editingMode        
        variable groupNames
        variable groupMap
    
        # Parse the incoming data.
        set pastedSelections [split [selection get -selection CLIPBOARD]]
        
        # Get the current seelction.
        set selectedCells [getSelectedCells]
        
        # See if only a single cell is selected.
        if {[llength $selectedCells] == 2 && [llength [lindex $selectedCells 1]] == 1} {
            
            # Get a list of all of the sequences in the editor.
            set allSequenceIDs [::SeqEditWidget::getSequences]
            
            # Figure out where the selected sequence is positioned.
            set firstSequence [lsearch $allSequenceIDs [lindex $selectedCells 0]]
            if {$firstSequence != -1 && [expr $firstSequence+[llength $pastedSelections]] < [llength $allSequenceIDs]} {
            
                # Figure out the insertion parameters.
                set sequenceIDs {}
                set positions {}
                set newElementValuesLists {}               
                for {set i 0} {$i < [llength $pastedSelections]} {incr i} {
                    lappend sequenceIDs [lindex $allSequenceIDs [expr $firstSequence+$i]]
                    lappend positions [lindex [lindex $selectedCells 1] 0]
                    lappend newElementValuesLists [split [lindex $pastedSelections [expr $i]] ""]
                }
                
                # Perform the insertion.
                insertElements $sequenceIDs $positions $newElementValuesLists
            }
        
        # See if the number of lines in the paste match the number of sequences currently selected.
        } elseif {[expr [llength $selectedCells]/2] == [llength $pastedSelections]} {
            
            # Figure out if either one column is selected in each sequence or the size of the selection match the paste.
            set allOneLong 1
            set allMatchPasteLength 1
            for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                if {[llength [lindex $selectedCells [expr $i+1]]] != 1} {
                    set allOneLong 0
                }
                if {[llength [lindex $selectedCells [expr $i+1]]] != [string length [lindex $pastedSelections [expr $i/2]]]} {
                    set allMatchPasteLength 0
                }
            }
            
            # If one cell in each row is selected, insert the new selection before the selected cells.
            if {$allOneLong} {
                
                # Figure out the insertion parameters.
                set sequenceIDs {}
                set positions {}
                set newElementValuesLists {}               
                for {set i 0} {$i < [llength $selectedCells]} {incr i 2} {
                    lappend sequenceIDs [lindex $selectedCells $i]
                    lappend positions [lindex $selectedCells [expr $i+1]]
                    lappend newElementValuesLists [split [lindex $pastedSelections [expr $i/2]] ""]
                }
                
                # Perform the insertion.
                insertElements $sequenceIDs $positions $newElementValuesLists
                
            # Otherwise, if the region matches exactly, overwrite the current selection.
            } elseif {$allMatchPasteLength} {
                
                # Get a list of the new elements.
                set newElements {}
                foreach pastedSelection $pastedSelections {
                    set newElements [concat $newElements [split $pastedSelection ""]]
                }
                
                # Set the cells.
                setCells $selectedCells $newElements
            }
        }
    }
}
