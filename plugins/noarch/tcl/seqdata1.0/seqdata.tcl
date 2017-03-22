############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# Sequence data structures and procedures for use in VMD sequence manipulation 
# plugins.

package provide seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqData:: {

    # Export the package namespace.
    namespace export SeqEditWidget
    
    # A list of the currently used sequenced ids.
    variable seqlist {}
    
    # An array of the data for the sequences.
    variable seqs
    array set seqs {}
    
    # A map of the notifications commands.
    variable sequenceCommands
    array set sequenceCommands {}
  
    # The map of residues to sequence elements.
    variable residueToElementMap
    array set residueToElementMap {}

    # The map of sequence elements to residues.
    variable elementToResidueMap
    array set elementToResidueMap {}
    
  # The file were sequence annotations are stored.
  variable annotationsFile "$env(HOME)/.ms-annotations"

  # Type of backend we're using for annotations.  
  # Could be a file, database, ???
  variable backend "FILE"
}

# Resets the sequence data store.
proc ::SeqData::reset { } {

    # Import global variables.
    variable seqlist
    variable seqs
    variable sequenceCommands
    variable residueToElementMap
    variable elementToResidueMap
    
    # Reset the data structures.
    set seqlist {}
    unset seqs
    array set seqs {}
    unset sequenceCommands
    array set sequenceCommands {}
    unset residueToElementMap
    array set residueToElementMap {}
    unset elementToResidueMap
    array set elementToResidueMap {}
}

# Gets the next available sequence id.
# return:   The next available sequence.
proc ::SeqData::nextSeq { } {

  # Import global variables.
  variable seqlist

  # Loop through the currently used sequence ids and find the maximum value.
  set ret -1
  foreach seq $seqlist {
    if {$seq > $ret} {
      set ret $seq
    }
  }
  
  # Return the next id.
  return [expr $ret+1]
}

# Adds a sequence to the current sequence store.
# args:     seq - A list of the elements in the sequence to be added.
#           name - The name of the sequence.
#           hasStruct - Y if this sequence has a structure associated with it 
#                       in VMD, otherwise N.
#           firstResidue - The id of the first element of the sequence in 
#                            the real world. For example, if a protein sequence
#                            is missing the first 6 residues, this value should
#                            be set to 6. This will aid in displaying 
#                            meaningful sequence identities.
# return:   The id of the newly added sequence.
proc ::SeqData::addSeq { seq name {hasStruct "N"} {firstResidue 1} {sources {}} {type unknown}} {

    # Import global variables.
    variable seqlist
    variable seqs
    
    # Get the next sequence id and add it to the list of used ids.
    set seqNum [nextSeq]
    lappend seqlist $seqNum
    
    # Set the sequence data.
    set seqs($seqNum,seq) $seq
    set seqs($seqNum,seqLength) [llength $seq]
    set seqs($seqNum,secondaryStructure) {}
    set seqs($seqNum,name) $name
    set seqs($seqNum,hasStruct) $hasStruct
    set seqs($seqNum,firstResidue) $firstResidue
    set seqs($seqNum,annotations) {}
    set seqs($seqNum,annotations,name) $name
    set seqs($seqNum,annotations_current) 0
    set seqs($seqNum,sources) $sources
    set seqs($seqNum,type) $type
    
    # Try to guess any sources we are mising.
    fillInMissingSources $seqNum $name
    
    # Figure out this sequences taxonomy node, if we can.
    set seqs($seqNum,taxonomyNode) [findTaxonomyNode $seqNum]
    set seqs($seqNum,ecNumber) [findEnzymeCommisionNumber $seqNum]
  
    # If this is not a structure, run update the mapping.
    if {!$seqs($seqNum,hasStruct)} {
        computeResidueElementMappings $seqNum
    }
  
    # Return the sequnce id.
    return $seqNum
}

# This method allows the caller to specify handlers to receive notification events whenever the
# specified sequence is changed.
# args:     sequenceID - The id of the sequence to monitor.
#           notificationCommand - The command to execute whenever the sequence is changed. 
proc ::SeqData::setCommand {commandName sequenceID newCommand} {
    
    # Import global variables.
    variable sequenceCommands
    
    set sequenceCommands($commandName,$sequenceID) $newCommand
}

proc ::SeqData::duplicateSequence {sequenceID {startingElement 0} {endingElement end}} {
    
    # Import global variables.
    variable seqlist
    variable seqs
    variable sequenceCommands
    
    # Get the next sequence id and add it to the list of used ids.
    set newSequenceID [nextSeq]
    lappend seqlist $newSequenceID
    
    # Copy the sequence data.
    if {$startingElement == "" || $startingElement == -1} {
        set sequence {}
        set startingElement 0
    } else {
        set sequence [lrange $seqs($sequenceID,seq) $startingElement $endingElement]
    }
    set seqs($newSequenceID,seq) $sequence
    set seqs($newSequenceID,seqLength) [llength $sequence]
    set seqs($newSequenceID,secondaryStructure) {}
    
    # Figure out the first residue index.
    set seqs($newSequenceID,firstResidue) ""
    for {set i 0} {$i <= [llength $sequence]} {incr i} {
        set seqs($newSequenceID,firstResidue) [getResidueForElement $sequenceID [expr $i+$startingElement]]
        if {$seqs($newSequenceID,firstResidue) != ""} {
            break
        }
    }
    
    # Copy the other attributes.
    copyAttributes $sequenceID $newSequenceID
    
    # If this is not a structure, run update the mapping.
    if {!$seqs($newSequenceID,hasStruct)} {
        computeResidueElementMappings $newSequenceID
    }
    
    return $newSequenceID
}

proc ::SeqData::deleteSequences {sequenceIDs} {
    
    # Import global variables.
    variable seqlist
    variable seqs
    variable sequenceCommands
    variable residueToElementMap
    variable elementToResidueMap
    
    # Go through each sequence and delete it.
    foreach sequenceID $sequenceIDs {
        
        # Remove it from the sequence list.
        set index [lsearch $seqlist $sequenceID]
        if {$index != -1} {
            set seqlist [lreplace $seqlist $index $index]
        }
        
        # Remove it from the sequence data store.
        foreach keyName [array names seqs "$sequenceID,*"] {
            unset seqs($keyName)
        }
        
        # Remove any commands associated with it.
        foreach keyName [array names sequenceCommands "*,$sequenceID"] {
            unset sequenceCommands($keyName)
        }
        
        # Remove any residue/element mappings associated with it.
        foreach keyName [array names residueToElementMap "$sequenceID,*"] {
            unset residueToElementMap($keyName)
        }
        foreach keyName [array names elementToResidueMap "$sequenceID,*"] {
            unset elementToResidueMap($keyName)
        }
    }
}

proc ::SeqData::copyAttributes {oldSequenceID newSequenceID} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
        
    # Copy the other attributes.
    set seqs($newSequenceID,name) $seqs($oldSequenceID,name)
    set seqs($newSequenceID,hasStruct) "N"
    set seqs($newSequenceID,sources) $seqs($oldSequenceID,sources)
    set seqs($newSequenceID,taxonomyNode) $seqs($oldSequenceID,taxonomyNode)
    set seqs($newSequenceID,ecNumber) $seqs($oldSequenceID,ecNumber)
    set seqs($newSequenceID,annotations_current) $seqs($oldSequenceID,annotations_current)
    set seqs($newSequenceID,type) $seqs($oldSequenceID,type)
    
    # If we have a notification command, call it.
    if {[info exists sequenceCommands(copyAttributes,$oldSequenceID)]} {
        $sequenceCommands(copyAttributes,$oldSequenceID) $oldSequenceID $newSequenceID
    }
        
    # Copy the annotations.
    copyAnnotations $oldSequenceID $newSequenceID
}


proc ::SeqData::extractRegionsFromSequences {regions} {
    
    # Go through each region.
    set originalSequenceIDs {}
    set newSequenceIDs {}
    set prefixes {}
    set suffixes {}
    set prefixEndPositions {}
    set suffixStartPositions {}
    for {set i 0} {$i < [llength $regions]} {incr i 2} {

        # Get the sequence id and elements of the region.
        set regionSequenceID [lindex $regions $i]
        set regionPositions [lindex $regions [expr $i+1]]
        lappend originalSequenceIDs $regionSequenceID
        
        # Make sure that the region is continguous.
        set previousElement -1
        foreach element $regionPositions {
            
            # If one region was not contiguous, we can not process anything, so return.
            if {$previousElement != -1 && $element != [expr $previousElement+1]} {
                return {}
            }
            set previousElement $element
        }
        
        # Create a new sequence from the region.
        lappend newSequenceIDs [::SeqData::duplicateSequence $regionSequenceID [lindex $regionPositions 0] [lindex $regionPositions end]]
        
        # Get the sequence.
        set fullSequence [::SeqData::getSeq $regionSequenceID]
        
        # Save the portion of the sequence before the region.
        set prefix {}
        set prefixEndPosition [expr [lindex $regionPositions 0]-1]
        if {$prefixEndPosition >= 0} {
            set prefix [lrange $fullSequence 0 $prefixEndPosition]
        }
        lappend prefixes $prefix
        lappend prefixEndPositions $prefixEndPosition
        
        # Save the portion of the sequence after the region.
        set suffix {}
        set suffixStartPosition [expr [lindex $regionPositions end]+1]
        if {$suffixStartPosition < [::SeqData::getSeqLength $regionSequenceID]} {
            set suffix [lrange $fullSequence $suffixStartPosition end]
        }
        lappend suffixes $suffix
        lappend suffixStartPositions $suffixStartPosition
    }
    
    return [list $originalSequenceIDs $newSequenceIDs $prefixes $prefixEndPositions $suffixes $suffixStartPositions]
}
        
proc ::SeqData::fillInMissingSources {sequenceID name} {
    
    # If we don't have a SwissProt source, see if we have a SwissProt name.
    if {[getSourceData $sequenceID "sp"] == {}} {
        if {[::SeqData::SwissProt::isValidSwissProtName $name]} {
            setSourceData $sequenceID "sp" [list "*" $name]
        }
    }
    
    # If we don't have a PDB source, see if we have a PDB name.
    if {[getSourceData $sequenceID "pdb"] == {}} {
        if {[set pdbCode [::SeqData::PDB::isValidPDBName $name]] != ""} {
            setSourceData $sequenceID "pdb" [list $pdbCode "*"]
        }
    }
    
    # If we don't have a SCOP source, see if we have a SCOP name.
    if {[getSourceData $sequenceID "scop"] == {}} {
        if {[::SeqData::SCOP::isValidSCOPName $name]} {
            setSourceData $sequenceID "scop" [list $name]
        }
    }
    
    # Fill in any data we can from known good sources.
    if {[llength [getSourceData $sequenceID "pdb"]] == 2 && [set swisssProtName [::SeqData::PDB::getSwissProtName [lindex [getSourceData $sequenceID "pdb"] 0]]] != ""} {
        setSourceData $sequenceID "sp" [list "*" $swisssProtName]
    } elseif {[llength [getSourceData $sequenceID "scop"]] == 1 && [set swisssProtName [::SeqData::SCOP::getSwissProtName [lindex [getSourceData $sequenceID "scop"] 0]]] != ""} {
        setSourceData $sequenceID "sp" [list "*" $swisssProtName]
    } elseif {[llength [getSourceData $sequenceID "sp"]] == 2 && [set pdbCode [::SeqData::PDB::getPdbCodeForSwissProtName [lindex [getSourceData $sequenceID "sp"] 1]]] != ""} {
        setSourceData $sequenceID "pdb" [list $pdbCode "*"]
    }
}

# Gets the lineage of the organism from which the sequence came.
# args:     seqNum - The id of the sequence to lookup.
# return:   A list containing the organism's lineage or an empty list if it is unknown.
proc ::SeqData::findTaxonomyNode {sequenceID} {

    set taxonomyNode ""
    
    # See if it is in the Swiss Prot database.
    if {[llength [getSourceData $sequenceID "sp"]] == 2} {
        set taxonomyNode [::SeqData::SwissProt::getTaxonomyNode [lindex [getSourceData $sequenceID "sp"] 1]]
    
    # See if it is in the GenBank database.
    } elseif {[llength [getSourceData $sequenceID "gi"]] == 1} {    
        set taxonomyNode [::SeqData::GenBank::getTaxonomyNode [lindex [getSourceData $sequenceID "gi"] 0]]
    
    # Otherwise, see if the name is a species name.
    } else {    
        set taxonomyNode [::SeqData::Taxonomy::findNodeBySpecies [getName $sequenceID]]
    }
    
    return $taxonomyNode
}

proc ::SeqData::findEnzymeCommisionNumber {sequenceID} {

    set ecNumber ""
    
    # See if it is in the Swiss Prot database.
    if {[llength [getSourceData $sequenceID "sp"]] == 2} {
        set ecNumber [::SeqData::SwissProt::getEnzymeCommisionNumber [lindex [getSourceData $sequenceID "sp"] 1]]
    }
    
    return $ecNumber
}

# Get the sequence from the sequence store.
# args:     seqNum - The id of the sequence to retrieve.
# return:   The list of the elements in the sequence.
proc ::SeqData::getSeq { seqNum } {

  # Import global variables.
  variable seqs

  # Get the sequence.
  if {[info exists seqs($seqNum,seq)]} {
    return $seqs($seqNum,seq)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

# Get the sequence from the sequence store.
# args:     seqNum - The id of the sequence to retrieve.
# return:   The length of the sequence
proc ::SeqData::getLen { seqNum } {

  # Import global variables.
  variable seqs

  # Get the sequence.
  if {[info exists seqs($seqNum,seqLength)]} {
    return $seqs($seqNum,seqLength)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::setSeq {sequenceID sequence} {

    # Import global variables.
    variable seqs
    variable sequenceCommands
    
    # Get the sequence.
    if {[info exists seqs($sequenceID,seq)]} {
        
        # If we have an override behavior, call it.
        if {[info exists sequenceCommands(changeHandler,$sequenceID)]} {
             return [$sequenceCommands(changeHandler,$sequenceID) "setSeq" $sequenceID $sequence]
             
        # Otherwise just use the default behavior.
        } else {
            
            # Set the new sequence.
            set seqs($sequenceID,seq) $sequence
            set seqs($sequenceID,seqLength) [llength $sequence]
            if {[llength $seqs($sequenceID,secondaryStructure)] != [getResidueCount $sequenceID]} {
                set seqs($sequenceID,secondaryStructure) {}
            }
            
            # Recompute the mappings.
            computeResidueElementMappings $sequenceID
            
            return 1
        }
        
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

# Get the length of a sequence from the sequence store.
# args:     seqNum - The id of the sequence length to retrieve.
# return:   The length of the sequence.
proc ::SeqData::getSeqLength { seqNum } {

  # Import global variables.
  variable seqs

  # Get the sequence.
  if {[info exists seqs($seqNum,seq)]} {
    return $seqs($seqNum,seqLength)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::getSecondaryStructure {sequenceID {includeGaps 0}} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    
    if {[info exists seqs($sequenceID,seq)]} {
        
        # If the secondary structure has not been calculated, calculate it.
        if {$seqs($sequenceID,secondaryStructure) == {}} {
            
            # See if we have a calculation command for this sequence.
            if {[info exists sequenceCommands(secondaryStructureCalculation,$sequenceID)]} {
                
                # Call the command and save the secondary structure.
                setSecondaryStructure $sequenceID [$sequenceCommands(secondaryStructureCalculation,$sequenceID) $sequenceID]
                 
            # Otherwise assume the sequence is all coil.
            } else {
                set ss {}
                for {set i 0} {$i < [getResidueCount $sequenceID]} {incr i} {
                    lappend ss "C"
                }
                setSecondaryStructure $sequenceID $ss 
            }
        }
        
        if {$seqs($sequenceID,secondaryStructure) != {}} {
            
            # If we need gaps, add them.
            if {$includeGaps} {
                set gappedSecondaryStructure {}
                for {set elementIndex 0; set residueIndex 0} {$elementIndex < [getSeqLength $sequenceID]} {incr elementIndex} {
                    
                    # See if the element is a gap.
                    if {[getElement $sequenceID $elementIndex] == "-"} {
                        lappend gappedSecondaryStructure "-"
                    } else {
                        lappend gappedSecondaryStructure [lindex $seqs($sequenceID,secondaryStructure) $residueIndex]
                        incr residueIndex
                    }
                }
                return $gappedSecondaryStructure
            } else {
                return $seqs($sequenceID,secondaryStructure)
            }
        }
        return {}
        
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::setSecondaryStructure {sequenceID secondaryStructure} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    
    if {[info exists seqs($sequenceID,seq)]} {
        
        if {[llength $secondaryStructure] == [getResidueCount $sequenceID]} {
            set seqs($sequenceID,secondaryStructure) $secondaryStructure
        }
        
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

# Removes a list of elements from a sequence.
# args:     seqNum - The id of the sequence to modify. NOTE: These MUST be in increasing order.
#           elements - A list of the indexes of the element that should be removed from the sequence.
proc ::SeqData::removeElements {seqNum elementIndexes} {

    # Import global variables.
    variable seqs
    variable sequenceCommands

    # Make sure the sequence exists.
    if {[info exists seqs($seqNum,seq)]} {
      
        # If we have an override behavior, call it.
        if {[info exists sequenceCommands(changeHandler,$seqNum)]} {
             return [$sequenceCommands(changeHandler,$seqNum) "removeElements" $seqNum $elementIndexes]
             
        # Otherwise just use the default behavior.
        } else {
            
            # Get the sequence.
            set sequence $seqs($seqNum,seq)
            
            # Remove all of the elements.
            set indexesRemoved 0
            foreach elementIndex $elementIndexes {
                
                # Adjust the index to account for the previously removed elements.
                incr elementIndex -$indexesRemoved
                
                # If this element exists, remove it.
                if {$elementIndex < [llength $sequence]} {
                    set sequence [lreplace $sequence $elementIndex $elementIndex]
                    incr indexesRemoved
                }
            }
            
            # Save the new sequence.
            set seqs($seqNum,seq) $sequence
                
            # Save the new sequence length.
            set seqs($seqNum,seqLength) [llength $sequence]
            
            # Reset the secondary structure, if necessary.
            if {[llength $seqs($seqNum,secondaryStructure)] != [getResidueCount $seqNum]} {
                set seqs($seqNum,secondaryStructure) {}
            }

            # Recompute the mappings.
            computeResidueElementMappings $seqNum
            
            return 1
        }
        
    } else {
        
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::getElement {seqNum elementIndex} {

    # Import global variables.
    variable seqs

    # Make sure the sequence exists.
    if {[info exists seqs($seqNum,seq)]} {
        return [lindex $seqs($seqNum,seq) $elementIndex]
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::getElements {seqNum elementIndexes} {

    # Import global variables.
    variable seqs

    # Make sure the sequence exists.
    if {[info exists seqs($seqNum,seq)]} {
        set elements {}
        foreach elementIndex $elementIndexes {
            lappend elements [lindex $seqs($seqNum,seq) $elementIndex]
        }
        return $elements
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

# Set a list of elements from a sequence to be a specific element.
# args:     seqNum - The id of the sequence to modify. NOTE: These MUST be in increasing order.
#           elements - A list of the indexes of the element that should be removed from the sequence.
#           newElement - The new element.
proc ::SeqData::setElements {seqNum elementIndexes newElement} {

    # Import global variables.
    variable seqs
    variable sequenceCommands

    # Make sure the sequence exists.
    if {[info exists seqs($seqNum,seq)]} {
      
        # If we have an override behavior, call it.
        if {[info exists sequenceCommands(changeHandler,$seqNum)]} {
             return [$sequenceCommands(changeHandler,$seqNum) "setElements" $seqNum $elementIndexes $newElement]
             
        # Otherwise just use the default behavior.
        } else {
            
            # Get the sequence.
            set sequence $seqs($seqNum,seq)
            
            # Go through all for the elements to be changed.
            foreach elementIndex $elementIndexes {
                
                # If this element exists, replace it.
                if {$elementIndex < [llength $sequence]} {
                    set sequence [lreplace $sequence $elementIndex $elementIndex $newElement]
                }
            }
            
            # Save the new sequence.
            set seqs($seqNum,seq) $sequence
            
            # Set the new sequence length.
            set seqs($seqNum,seqLength) [llength $seqs($seqNum,seq)]
            
            # Reset the secondary structure, if necessary.
            if {[llength $seqs($seqNum,secondaryStructure)] != [getResidueCount $seqNum]} {
                set seqs($seqNum,secondaryStructure) {}
            }
            
            # Recompute the mappings.
            computeResidueElementMappings $seqNum
            
            return 1
        }
        
    } else {
        
        return -code error "seq $seqNum doesn't exist"
    }
}

# Inserts a new element into a sequence.
# args:     seqNum - The id of the sequence to modify.
#           position - The position at which to insert the new elements.
#           newElement - A list of the new elements.
proc ::SeqData::insertElements {seqNum position newElements} {

    # Import global variables.
    variable seqs
    variable sequenceCommands

    # Make sure the sequence exists.
    if {[info exists seqs($seqNum,seq)]} {
      
        # If we have an override behavior, call it.
        if {[info exists sequenceCommands(changeHandler,$seqNum)]} {
             return [$sequenceCommands(changeHandler,$seqNum) "insertElements" $seqNum $position $newElements]
             
        # Otherwise just use the default behavior.
        } else {
            
            # Insert the new elements.
            if {$position == "end"} {
                set position [expr [llength $seqs($seqNum,seq)]-1]
            }
            set seqs($seqNum,seq) [concat [lrange $seqs($seqNum,seq) 0 [expr $position-1]] $newElements [lrange $seqs($seqNum,seq) $position end]]
            
            # Set the new sequence length.
            set seqs($seqNum,seqLength) [llength $seqs($seqNum,seq)]
            
            # Reset the secondary structure, if necessary.
            if {[llength $seqs($seqNum,secondaryStructure)] != [getResidueCount $seqNum]} {
                set seqs($seqNum,secondaryStructure) {}
            }
            
            # Recompute the mappings.
            computeResidueElementMappings $seqNum
            
            return 1
        }
        
    } else {
        
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::removeGaps {sequenceIDs firstElement lastElement {removalType all}} {
    
    # Initialize the lists of elements to remove.
    if {[info exists elementsToRemove]} {
        unset elementsToRemove
    }
    array set elementsToRemove {}
    foreach sequenceID $sequenceIDs {
        set elementsToRemove($sequenceID) {}
    }
    
    # Remove duplicate sequence ids.
    set newSequenceIDs {}
    foreach sequenceID $sequenceIDs {
        if {[lsearch -exact $newSequenceIDs $sequenceID] == -1} {
            lappend newSequenceIDs $sequenceID
        }
    }
    set sequenceIDs $newSequenceIDs
    
    # Figure out which gaps to remove.
    for {set i $firstElement} {$i <= $lastElement} {incr i} {
        
        # See if we should remove this gap.
        set removeGap 0
        if {$removalType == "redundant"} {
            set removeGap 1
            foreach sequenceID $sequenceIDs {
                if {$i < [::SeqData::getSeqLength $sequenceID] && [::SeqData::getElements $sequenceID $i] != "-"} {
                    set removeGap 0
                }
            }
        } elseif {$removalType == "all"} {
            set removeGap 1
        }
        
        # Get the elements to remove.
        if {$removeGap} {
            foreach sequenceID $sequenceIDs {
                if {$i < [::SeqData::getSeqLength $sequenceID] && [::SeqData::getElements $sequenceID $i] == "-"} {
                    lappend elementsToRemove($sequenceID) $i
                }
            }
        }   
    }
    
    # Remove the gaps.
    foreach sequenceID $sequenceIDs {
        ::SeqData::removeElements $sequenceID $elementsToRemove($sequenceID)
    }
}

# Get the sequence name from the sequence store.
# args:     seqNum - The id of the sequence whose name is to be retrieved.
# return:   The name of the requested sequence.
proc ::SeqData::getName { seqNum } {

  # Import global variables.
  variable seqs

  # Get the sequence name.
  if {[info exists seqs($seqNum,seq)]} {
    return $seqs($seqNum,name)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

# Sets the sequence name.
# args:     seqNum - The id of the sequence whose name is to be set.
#           newName - The new name of the sequence.
proc ::SeqData::setName {sequenceID newName} {

  # Import global variables.
  variable seqs

  # Get the sequence name.
  if {[info exists seqs($sequenceID,seq)]} {
    set seqs($sequenceID,name) $newName
  } else {
    return -code error "seq $sequenceID doesn't exist"
  }
}

proc ::SeqData::getSources {sequenceID} {

    # Import global variables.
    variable seqs
    
    # Get the sequence name.
    if {[info exists seqs($sequenceID,seq)]} {
        return $seqs($sequenceID,sources)
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::setSources {sequenceID sources} {

    # Import global variables.
    variable seqs
    
    # Get the sequence name.
    if {[info exists seqs($sequenceID,seq)]} {
        set seqs($sequenceID,sources) $sources
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::getSourceData {sequenceID sourceName} {

    # Import global variables.
    variable seqs
    
    # Get the sequence name.
    if {[info exists seqs($sequenceID,seq)]} {
        foreach source $seqs($sequenceID,sources) {
            if {[lindex $source 0] == $sourceName} {
                return [lindex $source 1]
            }
        }
        return {}
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::setSourceData {sequenceID sourceName sourceData} {

    # Import global variables.
    variable seqs
    
    # Get the sequence name.
    if {[info exists seqs($sequenceID,seq)]} {
        
        # Try to replace the existing entry.
        for {set i 0} {$i < [llength $seqs($sequenceID,sources)]} {incr i} {
            if {[lindex [lindex $seqs($sequenceID,sources) $i] 0] == $sourceName} {
                set seqs($sequenceID,sources) [lreplace $seqs($sequenceID,sources) $i $i [list $sourceName $sourceData]]
                return
            }
        }
        
        # Otherwise just add it.
        lappend seqs($sequenceID,sources) [list $sourceName $sourceData]
        
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}


proc ::SeqData::hasStruct { seqNum } {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    return $seqs($seqNum,hasStruct)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::setHasStruct {seqNum hasStruct} {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    set seqs($seqNum,hasStruct) $hasStruct
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::getFirstResidue {seqNum} {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    return $seqs($seqNum,firstResidue)
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::setFirstResidue {sequenceID firstResidue} {
    
    # Import global variables.
    variable sequenceCommands
    variable seqs

    # Make sure the sequence exists.
    if {[info exists seqs($sequenceID,seq)]} {
        
        # If we have an override behavior, call it.
        if {[info exists sequenceCommands(changeHandler,$sequenceID)]} {
             return [$sequenceCommands(changeHandler,$sequenceID) "setFirstResidue" $sequenceID $firstResidue]
             
        # Otherwise just use the default behavior.
        } else {
            
            # Save the new first residue.
            set seqs($sequenceID,firstResidue) $firstResidue
            
            # Recompute the mappings.
            computeResidueElementMappings $sequenceID
            
            return 1
        }
    
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::getResidueCount {seqNum} {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    set residueCount 0
    foreach element $seqs($seqNum,seq) {
        if {$element != "-"} {
            incr residueCount
        }
    }
    return $residueCount
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}


# This method computes all of the residue to element mappings for a given sequence.
# args:     sequenceID - The id of the sequence for which to recompute the mappings.
proc ::SeqData::computeResidueElementMappings {sequenceID} {
            
    # Import global variables.
    variable residueToElementMap
    variable elementToResidueMap
    
    # Get the first residue.
    set residue [::SeqData::getFirstResidue $sequenceID]
    
    # Go through the elements and map non gaps to residues.
    set element 0
    foreach elementValue [::SeqData::getSeq $sequenceID] {
        
        # See if the element contains a gap.
        if {$elementValue != "-"} {
            
            # It is not a gap, so save the mappings.
            set elementToResidueMap($sequenceID,$element) $residue
            set residueToElementMap($sequenceID,$residue) $element
            incr residue
            
        } else {
            
            # It is a gap, so save that it maps to no residue.
            set elementToResidueMap($sequenceID,$element) ""
        }
        
        incr element            
    }
}

proc ::SeqData::getResidueForElement {sequenceID element} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    variable elementToResidueMap
    
    if {[info exists seqs($sequenceID,seq)]} {
        if {[info exists sequenceCommands(elementToResidueMapping,$sequenceID)]} {
             $sequenceCommands(elementToResidueMapping,$sequenceID) $sequenceID $element
        } else {
            return $elementToResidueMap($sequenceID,$element)
        }
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

proc ::SeqData::getElementForResidue {sequenceID residue} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    variable residueToElementMap
    
    if {[info exists seqs($sequenceID,seq)]} {
        if {[info exists sequenceCommands(residueToElementMapping,$sequenceID)]} {
             $sequenceCommands(residueToElementMapping,$sequenceID) $sequenceID $residue
        } else {
            return $residueToElementMap($sequenceID,$residue)
        }
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}

# This method gets the type of the specified sequence.
# args:     sequenceID - The sequence if for which the type should be retrieved.
# return:   The type of the sequence: nucleic, protein, or unknown.
proc ::SeqData::getType {sequenceID} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    
    if {[info exists seqs($sequenceID,seq)]} {
        return $seqs($sequenceID,type)
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}
    
# This method gets the type of the specified sequence.
# args:     sequenceID - The sequence if for which the type should be retrieved.
# return:   The type of the sequence: nucleic, protein, or unknown.
proc ::SeqData::setType {sequenceID type} {
    
    # Import global variables.
    variable seqs
    variable sequenceCommands
    
    if {[info exists seqs($sequenceID,seq)]} {
        set seqs($sequenceID,type) $type
    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}
    
# Gets the domain of life for the specified sequence.
# args:     seqNum - The id of the sequence to lookup.
# return:   The doamin of life (Eukaryota|Archaea|Bacteria) or and empty string ("") if the domain
#           of life is not known.
proc ::SeqData::getDomainOfLife {seqNum} {

    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($seqNum,seq)]} {
        
        # Try to get the domain of life from the annotations.
        set domain [getAnnotation $seqNum "domain-of-life"]
        
        # If we don't have a name in the annotations, see if we have a taxonomy node.
        if {$domain == "" && $seqs($seqNum,taxonomyNode) != ""} {
            
            # Get the name from the taxonomy tree.
            set domain [::SeqData::Taxonomy::getDomainOfLife $seqs($seqNum,taxonomyNode)]
        }
        
        return $domain
        
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

# Gets the lineage of the organism from which the sequence came.
# args:     seqNum - The id of the sequence to lookup.
# return:   A list containing the organism's lineage or an empty list if it is unknown.
proc ::SeqData::getCommonName {seqNum} {

    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($seqNum,seq)]} {
        
        # Try to get the name from the annotations.
        set commonName [getAnnotation $seqNum "common-name"]
        
        # If we don't have a name in the annotations, see if we have a taxonomy node.
        if {$commonName == "" && $seqs($seqNum,taxonomyNode) != ""} {
            
            # Get the name from the taxonomy tree.
            set commonName [::SeqData::Taxonomy::getCommonName $seqs($seqNum,taxonomyNode)]
        }
        
        return $commonName
        
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

# Gets the lineage of the organism from which the sequence came.
# args:     seqNum - The id of the sequence to lookup.
# return:   A list containing the organism's lineage or an empty list if it is unknown.
proc ::SeqData::getScientificName {seqNum} {

    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($seqNum,seq)]} {
        
        # Try to get the name from the annotations.
        set scientificName [getAnnotation $seqNum "scientific-name"]
        
        # If we don't have a name in the annotations, see if we have a taxonomy node.
        if {$scientificName == "" && $seqs($seqNum,taxonomyNode) != ""} {
            
            # Get the name from the taxonomy tree.
            set scientificName [::SeqData::Taxonomy::getScientificName $seqs($seqNum,taxonomyNode)]
        }
        
        return $scientificName
        
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::getShortScientificName {seqNum} {

    set name [getScientificName $seqNum]
    set nameParts [split $name]
    if {[llength $nameParts] <= 1} {
        return $name
    } elseif {[llength $nameParts] >= 2} {
        return "[string index [lindex $nameParts 0] 0]. [lindex $nameParts 1]"
    }
    return $name
}

# Gets the lineage of the organism from which the sequence came.
# args:     seqNum - The id of the sequence to lookup.
# return:   A list containing the organism's lineage or an empty list if it is unknown.
proc ::SeqData::getLineage {seqNum {showHidden 0} {includeRanks 0} {includeSelf 0}} {

    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($seqNum,seq)]} {
        
        # Try to get the name from the annotations.
        set lineage [getAnnotation $seqNum "lineage"]
        if {$lineage == ""} {
            set lineage {}
        }
        
        # If we don't have a name in the annotations, see if we have a taxonomy node.
        if {$lineage == {} && $seqs($seqNum,taxonomyNode) != ""} {
            
            # Get the name from the taxonomy tree.
            set lineage [::SeqData::Taxonomy::getLineage $seqs($seqNum,taxonomyNode) $showHidden $includeRanks $includeSelf]
        }
        
        return $lineage
        
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::getLineageRank {sequenceID rank} {


    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($sequenceID,seq)]} {

        # Search the lineage for the specified rank.        
        set lineage [::SeqData::Taxonomy::getLineage $seqs($sequenceID,taxonomyNode) 1 1 1]
        foreach level $lineage {
            if {[lindex $level 1] == $rank} {
                return [lindex $level 0]
            }
        }
        
        return ""

    } else {
        return -code error "seq $sequenceID doesn't exist"
    }
}


proc ::SeqData::getEnzymeCommisionNumber {seqNum} {

    # Import global variables.
    variable seqs
    
    # Make sure this is a valid sequence.
    if {[info exists seqs($seqNum,seq)]} {
        
        # Try to get the name from the annotations.
        set ecNumber [getAnnotation $seqNum "ec-number"]
        
        # If we don't have a name in the annotations, see if we have a taxonomy node.
        if {$ecNumber == "" && $seqs($seqNum,ecNumber) != ""} {
            set ecNumber $seqs($seqNum,ecNumber)
        }
        
        return $ecNumber
        
    } else {
        return -code error "seq $seqNum doesn't exist"
    }
}

proc ::SeqData::getEnzymeCommisionDescription {seqNum} {

    # If we have an annotation, use it.
    if {[getAnnotation $seqNum "ec-description"] != ""} {
        return [getAnnotation $seqNum "ec-description"]
    }

    # Otherwise, lookup the code.
    return [::SeqData::Enzyme::getDescription [getEnzymeCommisionNumber $seqNum]]
}

proc ::SeqData::addAnnotation { seqNum key value } {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    set seqs($seqNum,annotations,$key) $value
    #saveAnnotations $seqNum
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

proc ::SeqData::getAnnotation { seqNum key } {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
      
    if {[info exists seqs($seqNum,annotations,$key)]} {
      return $seqs($seqNum,annotations,$key)
    } else {
      if { $seqs($seqNum,annotations_current) == 0 } {
        #loadAnnotations $seqNum
        set seqs($seqNum,annotations_current) 1
      }
      if {[info exists seqs($seqNum,annotations,$key)]} {
        return $seqs($seqNum,annotations,$key)
      } else {
        return ""
      }
    }
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

# Return all this seq's annotations as an array
proc ::SeqData::getAllAnnotations { seqNum } {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
    return [array get seqs "$seqNum,annotations,*"]
  } else {
    return -code error "Seq $seqNum doesn't exist"
  }
}

proc ::SeqData::getAnnotation { seqNum key } {
  variable seqs

  if {[info exists seqs($seqNum,seq)]} {
      
    if {[info exists seqs($seqNum,annotations,$key)]} {
      return $seqs($seqNum,annotations,$key)
    } else {
      if { $seqs($seqNum,annotations_current) == 0 } {
        #loadAnnotations $seqNum
        set seqs($seqNum,annotations_current) 1
      }
      if {[info exists seqs($seqNum,annotations,$key)]} {
        return $seqs($seqNum,annotations,$key)
      } else {
        return ""
      }
    }
  } else {
    return -code error "seq $seqNum doesn't exist"
  }
}

# Copies all annotations from seqId1 to seqId2
# args: seqId1 - source sequence
#       seqId2 - destination sequence
proc ::SeqData::copyAnnotations { seqId1 seqId2 } {
  variable seqs

  foreach annotation [array names seqs "$seqId1,annotations,*"] {
    set key [lindex [split $annotation ","] 2]
    set seqs($seqId2,annotations,$key) $seqs($annotation)
  }
}

# Writes seq annotations into the annotations back-end.
# args:  seqNum - the number of the sequence the annotation is for
# return:   1/0 success/fail  (from the backend function)
proc ::SeqData::saveAnnotations { seqNum } {
  variable backend
  variable seqs

  switch $backend {
    FILE { 
      foreach key [array names $seqs($seqNum,annotations)] {
        return [writeAnnotationToFileBackend $seqs($seqNum,name) \
          $key $seqs($seqNum,annotations,$key)]
      }
    }
    default {
      return -code error "saveAnnotations: No such backend $backend!"
    }
  }
}
 
# Gets seq annotations from the annotations back-end.
# args:  seqNum - the number of the sequence to get annotations for
# return:   none
proc ::SeqData::loadAnnotations { seqNum } {
  variable backend
  variable seqs

  switch $backend {
    FILE { 
      set $seqs($seqNum,annotations) \
        [getAnnotationsFromFileBackend $seqs($seqNum,name)]
    }
    default {
       return -code error "loadAnnotations: No such backend $backend!"
    }
  }
}  


# FILE backend functions
# The format for the annotations file is as follows:
#
# name1|key1=note 1|key2=note 2|key3=....
# name2|key5=note 1|key1=note 2|key7=....
# 
# any newlines that were embedded in the original user entry should be encoded 
# as "<NL>" for entry into the annotations file, and decoded back to a newline
# when the annotation is read out.
 
# Annotation writing function for FILE backend.
# args:   name - name of seq. to save the annotations under
#         key - name of the annotation
#         annotation - content of the annotation
# return: 1/0 success/fail
proc ::SeqData::writeAnnotationToFileBackend { name key annotation } {
  variable seqs
  variable annotationsFile

  if { ! [set fp [open $annotationsFile r]] } {
    return -code error "Can't open $annotationsFile for read!"
  }
  
  # Search out the annotations for this particular name



}

# Annotation loading function for FILE backend.
# args:   name - name of seq. to load the annotations for
# return: an array of keys/annotations
proc ::SeqData::getAnnotationsFromFileBackend { name } {
  variable seqs
  variable annotationsFile

  if { ! [set fp [open $annotationsFile r]] } {
    return -code error "Can't open $annotationsFile for read!"
  }
}

proc ::SeqData::getGaps {number} {
    set ret {}
    for {set i 0} {$i < $number} {incr i} {
        lappend ret "-"
    }
    return $ret
}
