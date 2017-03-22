############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for reading and writing sequence data from FASTA formatted files.

package provide seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqData::VMD {
    
    # Export the package namespace.
    namespace export loadVMDSequences
    
    # The map of three letter to one letter amino acid codes.
    variable codes

    # The loaded parts.
    variable loadedMolecules

    # The loaded parts.
    variable loadedParts

    # The map of seqdata ids to vmd mol ids.
    variable sequenceIDToMolID
    
    # The map of vmd mol ids to seqdata ids.
    variable molIDToSequenceID                                 
    
    # The map of molecule and chain to residues.
    variable residueListsMap
    
    # The map of vmd residues to sequence elements.
    variable residueToElementMap

    # The map of sequence elements to vmd residues.
    variable elementToResidueMap
    
    # Whether the loader should ignor non registered structures.
    variable ignoreNonRegisteredStructures 0
    
    # Existing sequence ids that should be used for VMD structures.
    variable registeredSequences {}

    proc reset {} {
        array set ::SeqData::VMD::codes {ACE  *   ALA  A   ARG  R   ASN  N   ASP  D   ASX  B   CYS  C   CYX  C   GLN  Q   GLU  E
                       GLX  Z   GLY  G   HIS  H   HSE  H   HSD  H   HSP  H   ILE  I   LEU  L   LYS  K   MET  M   MSE  M   PHE  F
                       PRO  P   SER  S   THR  T   TRP  W   TYR  Y   VAL  V
                       A    A   C    C   G    G   T    T   U    U   ADE  A   CYT  C   GUA  G   THY  T   URA  U
                       TIP3 O   MG   M   MN   G   SOD  N   POT  K   HOH  O   ATP  *
                       1MA  E   MAD  E   T6A  F   OMC  B   5MC  H   OMG  J   1MG  K   2MG  L   M2G  R   7MG  M
                       G7M  M   5MU  T   RT   T   4SU  V   DHU  D   H2U  D   PSU  P   I    I   YG   Y}
        set ::SeqData::VMD::loadedMolecules {}
        array set ::SeqData::VMD::loadedParts {}
        array set ::SeqData::VMD::sequenceIDToMolID {}
        array set ::SeqData::VMD::molIDToSequenceID {}
        array set ::SeqData::VMD::residueListsMap {}
        array set ::SeqData::VMD::residueToElementMap {}
        array set ::SeqData::VMD::elementToResidueMap {}
        set ::SeqData::VMD::ignoreNonRegisteredStructures 0
        set ::SeqData::VMD::registeredSequences {}
    }
    reset
    
    proc setIgnoreNonRegisteredStructures {newValue} {
        
        # Import global variables.
        variable ignoreNonRegisteredStructures
        
        set ignoreNonRegisteredStructures $newValue
    }
    
    proc registerSequenceForVMDStructure {name chain sequenceID} {
        
        # Import global variables.
        variable registeredSequences
        
        lappend registeredSequences [list $name $chain $sequenceID]
    }
    
    # Updates the list of VMD sequences into the sequence store to correspond to what is currently
    # loaded into VMD.
    # return:   A list of two lists containing the updates. The first list contains any sequence ids
    #           that were newly loaded. The second list contains any sequence ids that were removed.
    proc updateVMDSequences {} {

        # Import global variables.
        variable loadedMolecules
        variable loadedParts
        
        # Go through each molecule in VMD.
        set addedSequenceIDs {}
        set vmdMolIDs [molinfo list]
        foreach molID $vmdMolIDs {
            
            # See if we have not yet loaded this molecule.
            if {[lsearch $loadedMolecules $molID] == -1} {
            
                # Assume the molecule is initialized.
                set moleculeIntialized 1
                
                #  Get a list of the chains in the molecule.
                set parts [getPartsInMolecule $molID]
            
                # If the molecule has no parts, it might later get some; for example, 
                # the script "mol new ; mol addfile 1atp" will initially generate a
                # molecule with no parts, but the later addition of structure doesn't
                # get noticed because the molecule is already registered.
                # Justin Gullingsrud; 8/16/06
                if {[llength $parts] < 1} {
                    set moleculeIntialized 0
                }
                
                # Go through each part.
                foreach part $parts {
                    
                    set chain [lindex $part 0]
                    set segname [lindex $part 1]
                        
                    if {![info exists loadedParts($molID,$chain,$segname)]} {
                    
                        # Get the atoms of the molecule.
                        if {$segname == ""} {
                            set atoms [atomselect $molID "chain $chain"]
                            set solvent [atomselect $molID "chain $chain and (water or lipid)"]
                        } else {
                            set atoms [atomselect $molID "chain $chain and segname \"$segname\""]
                            set solvent [atomselect $molID "chain $chain and segname \"$segname\" and (water or lipid)"]
                        }
                        
                        # Make sure this parts is not a bunch of MD waters or lipids.
                        #$numatoms < 300 || [expr $numSolventAtoms/$numatoms] < 0.95
                        set numatoms [$atoms num]
                        set numSolventAtoms [$solvent num]
                        if {$numatoms != $numSolventAtoms} {
                            
                            # Get the residue information.
                            set atomPropsList [$atoms get {resid insertion resname residue altloc}]
                            if {$numatoms == [llength $atomPropsList]} {
        
                                # Go through each residue.
                                set uniqueResIDs {}
                                set uniqueResidues {}
                                set residues {}
                                set sequence {}
                                foreach atomProps $atomPropsList {
                                    
                                    # Get the residue id.
                                    set resID [lindex $atomProps 0]
                                    set insertion [lindex $atomProps 1]
                                    set resName [lindex $atomProps 2]
                                    set residue [lindex $atomProps 3]
                                    set altloc [lindex $atomProps 4]
                                    
                                    # Make sure we process each unique resid only once.
                                    if {[lsearch $uniqueResIDs "$resID$insertion"] == -1} {
                                        lappend uniqueResIDs "$resID$insertion"
                                        
                                        # See if this is just a normal residue.
                                        if {$insertion == " " && $altloc == ""} {
                                            lappend residues $resID
                                            lappend sequence [lookupCode $resName]
                                            
                                        # We must have either an insertion or an alternate location.
                                        } else {
                                            
                                            # This is an insertion or an alternate, so save the residue as a list.
                                            lappend residues [list $resID $insertion $altloc]
                                            lappend sequence [lookupCode $resName]
                                            
                                            # See if we need to update any previous residues.
                                            set updateIndex [lsearch $residues $resID]
                                            if {$updateIndex != -1} {
                                                set residues [lreplace $residues $updateIndex $updateIndex [list $resID " " ""]]
                                            }
                                        }
                                    }             
                                    
                                    # Store the residue to check for VMD preload problem.
                                    if {[lsearch $uniqueResidues $residue] == -1} {
                                        lappend uniqueResidues $residue
                                    }                                
                                }
                                
                                # If we only have one residue, make sure we only have one resid to avoid VMD preload problem.
                                if {[llength $uniqueResidues] > 1 || [llength $uniqueResIDs] == 1} {
                                    
                                    # If there is more than one parts for this molecule, use the parts as the name suffix.
                                    set nameSuffix ""
                                    if {[llength $parts] > 1} {
                                        if {$segname != ""} {
                                            set nameSuffix "_$segname"
                                        } else {
                                            set nameSuffix "_$chain"
                                        }
                                    }
                                    
                                    # Add the sequence to the sequence store.
                                    set sequenceID [addVMDSequence $molID $chain $segname $sequence "[getMoleculeName $molID]$nameSuffix" [lindex $residues 0] $residues]
                                    if {$sequenceID != -1} {
                                        
                                        # Add the sequence to the list of sequence ids we have added.
                                        lappend addedSequenceIDs $sequenceID
                                    }
                                        
                                    # Mark that we have loaded this part.
                                    set loadedParts($molID,$chain,$segname) 1
                                    
                                } else {
                                    
                                    # Mark this molecule as not yet initialized.
                                    set moleculeIntialized 0
                                    break
                                }
                            }
                        }
                        
                        # Remove the atomselect.
                        $atoms delete
                        $solvent delete
                    }
                }
                
                # If we made it through all of the parts and the molecule was initialized, we have finished the entire molecule.
                if {$moleculeIntialized} {
                    lappend loadedMolecules $molID
                }
            }
        }
        
        # Go through each molecule that is currently loaded.
        set removedSequenceIDs {}
        for {set i 0} {$i < [llength $loadedMolecules]} {incr i} {
            
            # Get the mol id.
            set loadedMolID [lindex $loadedMolecules $i]
            
            # See if the molecule is no longer in VMD.
            if {[lsearch $vmdMolIDs $loadedMolID] == -1} {
                
                # Remove it from the list of loaded molecules.
                set loadedMolecules [lreplace $loadedMolecules $i $i]
                incr i -1
                
                # Add the sequence ids that correspond to this molecule to the list of remvoed ids.
                set removedSequenceIDs [concat $removedSequenceIDs [getSequenceIDsForMolecule $loadedMolID]]
            }
        }
        
        # Return the lists.
        return [list $addedSequenceIDs $removedSequenceIDs]
    }
    
    # This method gets the name of a molecule.
    # args:     molID - The molecule of whicht o retrieve the name.
    # return:   The name of the molecule.
    proc getMoleculeName {molID} {
        
        # Get the molecule name.
        set moleculeName [molinfo $molID get name]
        regsub -nocase {\.pdb$} $moleculeName "" moleculeName
        return $moleculeName
    }
    
    # This method gets a list of all of the chain and segname pairs in the specified molecule.
    # args:     molID - The VMD molecule id for the molecule.
    # return:   A list of the chain and segname pairs in the specified molecule.
    proc getPartsInMolecule {molID} {
        
        # Get the number of atoms and the number of frames.            
        set atoms [atomselect $molID "all"]
        
        #  Get a list of the chains in the molecule.
        set uniqueParts {}
        foreach part [$atoms get {chain segname}] {
            
            # Get the chain and segname.
            set chain [lindex $part 0]
            set segname [lindex $part 1]
            if {$chain != "X"} {
                set segname ""
            }
            
            # See if we have already found this part.
            set found 0
            foreach uniquePart $uniqueParts {
                if {$chain == [lindex $uniquePart 0] && $segname == [lindex $uniquePart 1]} {
                    set found 1
                    break
                }
            }
            if {!$found} {
                lappend uniqueParts [list $chain $segname]
            }
        }
        
        # Remove the atomselect.
        $atoms delete
        unset atoms

        return $uniqueParts        
    }
    
    # This method adds a VMD sequence to the sequence store.
    # args:     molID - The VMD molecule id for which this is the sequence.
    #           sequence - The sequence itself.
    #           name - The name of the sequence.
    #           startElementId - The "real" index of the first element in the sequence.
    # return:   The sequence ID of the added sequence.
    proc addVMDSequence {molID chain segname sequence name firstResidue residues} {
        
        # Import global variables.
        variable ignoreNonRegisteredStructures
        variable registeredSequences
        variable sequenceIDToMolID
        variable molIDToSequenceID
        variable residueListsMap
        
        # See if we have a sequence registered for this structure.
        set sequenceID -1
        for {set i 0} {$i < [llength $registeredSequences]} {incr i} {
            
            # Get the sequence registration info.
            set registeredSequence [lindex $registeredSequences $i]
            
            # If we found a match, use it.
            if {[lindex $registeredSequence 0] == [getMoleculeName $molID] && ([lindex $registeredSequence 1] == $chain || [lindex $registeredSequence 1] == "*")} {
                
                # Get the sequence id.
                set sequenceID [lindex $registeredSequence 2]
                
                # Adjust the data.
                ::SeqData::setHasStruct $sequenceID "Y"
                ::SeqData::setFirstResidue $sequenceID $firstResidue
                ::SeqData::setType $sequenceID [determineType $molID $chain $segname]  
                                
                # Remove the sequence from the registered list and stop the loop.
                set registeredSequences [lreplace $registeredSequences $i $i]
                break
            }
        }
        
        # Otherwise, create the new sequence in the sequence store.
        if {$sequenceID == -1} {
            
            # If we are ignoring non registered structures, quit.
            if {$ignoreNonRegisteredStructures} {return -1}

            # If this is a PDB file, set the source appropriately.            
            set sources {}
            if {[set pdbCode [::SeqData::PDB::isValidPDBName [getMoleculeName $molID]]] != ""} {
                set sources [list [list "pdb" [list $pdbCode $chain]]]
            }

            # Create the sequence.
            set sequenceID [::SeqData::addSeq $sequence $name "Y" $firstResidue $sources [determineType $molID $chain $segname]]
        }
        
        # Add a change handler to keeep the residue mappings up to date.
        ::SeqData::setCommand changeHandler $sequenceID "::SeqData::VMD::sequenceChanged"
        ::SeqData::setCommand elementToResidueMapping $sequenceID "::SeqData::VMD::getResidueForElement"
        ::SeqData::setCommand residueToElementMapping $sequenceID "::SeqData::VMD::getElementForResidue"
        ::SeqData::setCommand secondaryStructureCalculation $sequenceID "::SeqData::VMD::calculateSecondaryStructure"
        ::SeqData::setCommand copyAttributes $sequenceID "::SeqData::VMD::copyVMDAttributes"

        # Save the sequence to mol id mapping.
        set sequenceIDToMolID($sequenceID) [list $molID $chain $segname]
        if {![info exists molIDToSequenceID($molID,$chain,$segname)]} {
            set molIDToSequenceID($molID,$chain,$segname) {}
        }
        lappend molIDToSequenceID($molID,$chain,$segname) $sequenceID
        
        # Save the residue list.
        set residueListsMap($molID,$chain,$segname) $residues
        
        # Compute the residue/element mappings.
        computeResidueElementMappings $sequenceID $molID $chain $segname        
                    
        # Determine the first and last residues in the first segment.
        set residueListsMap($molID,$chain,$segname,firstRegionRange) [determineFirstRegionRange $sequenceID $molID]
        
        return $sequenceID 
    }
    
    # Figure out the first region starting and ending residues.
    proc determineFirstRegionRange {sequenceID molID} {
        
        # Import global variables.
        variable elementToResidueMap
        
        # Get the sequence type.
        set type [::SeqData::getType $sequenceID]
        
        set inRegion 0
        set lastResidueInRegion {}
        set regionRange {}

        # Go through each element.
        for {set i 0} {$i < [::SeqData::getSeqLength $sequenceID]} {incr i} {
                        
            # Get the selection string.
            set selectionString [::SeqData::VMD::getSelectionStringForElements $sequenceID $i]
            
            # See if we got an atom selection.
            if {$selectionString != "none"} {
            
                # Get the atom types.
                set atoms [atomselect $molID $selectionString]
                set atomTypes [$atoms get name]
                $atoms delete
                
                # See if we are in a region corresponding to our sequence type.
                if {($type == "protein" && [lsearch $atomTypes "CA"] != -1) || ($type == "nucleic" && [lsearch $atomTypes "P"] != -1)} {
                    
                    # If we are not yet tracking elements, start, and add this element to the list.
                    if {!$inRegion} {
                        set inRegion 1
                        lappend regionRange $elementToResidueMap($sequenceID,$i)
                    }
                    set lastResidueInRegion $elementToResidueMap($sequenceID,$i)
                    
                # Otherwise, we must have moved out of the region so we are done.
                } elseif {$inRegion} {
                    lappend regionRange $lastResidueInRegion
                    break                    
                }
            }
        }
        
        if {[llength $regionRange] == 1} {
            lappend regionRange $lastResidueInRegion
        }
        
        return $regionRange
    }
    
    # This method copies the VMD attributes from one sequence to another.
    # args:     oldSequenceID - The old sequence id.
    #           newSequenceID - The new sequence id.
    proc copyVMDAttributes {oldSequenceID newSequenceID} {

        # Import global variables.
        variable sequenceIDToMolID
        variable molIDToSequenceID
        
        # Copy the seqdata attributes
        ::SeqData::setHasStruct $newSequenceID "Y"
        
        # Add a change handler to keeep the residue mappings up to date.
        ::SeqData::setCommand changeHandler $newSequenceID "::SeqData::VMD::sequenceChanged"
        ::SeqData::setCommand elementToResidueMapping $newSequenceID "::SeqData::VMD::getResidueForElement"
        ::SeqData::setCommand residueToElementMapping $newSequenceID "::SeqData::VMD::getElementForResidue"
        ::SeqData::setCommand secondaryStructureCalculation $newSequenceID "::SeqData::VMD::calculateSecondaryStructure"
        ::SeqData::setCommand copyAttributes $newSequenceID "::SeqData::VMD::copyVMDAttributes"
        
        # Save the molid/sequence mappings.
        set molID [lindex $sequenceIDToMolID($oldSequenceID) 0]
        set chain [lindex $sequenceIDToMolID($oldSequenceID) 1]
        set segname [lindex $sequenceIDToMolID($oldSequenceID) 2]
        set sequenceIDToMolID($newSequenceID) [list $molID $chain $segname]
        if {![info exists molIDToSequenceID($molID,$chain,$segname)]} {
            set molIDToSequenceID($molID,$chain,$segname) {}
        }
        lappend molIDToSequenceID($molID,$chain,$segname) $newSequenceID
        
        # Compute the residue/element mappings.
        computeResidueElementMappings $newSequenceID $molID $chain $segname
    }
    
    proc extractFirstRegionFromStructures {sequenceIDs} {
        
        # Import global variables.
        variable sequenceIDToMolID
        variable residueListsMap
        variable residueToElementMap
        variable elementToResidueMap

        # The regions we are extracting.
        set regions {}
        
        # Go through each sequence.
        foreach sequenceID $sequenceIDs {

            # If this is a structure, extract the first segment that is of the correct type.
            if {[::SeqData::hasStruct $sequenceID] == "Y"} {
                # Get the sequence info.
                set molID [lindex $sequenceIDToMolID($sequenceID) 0]
                set chain [lindex $sequenceIDToMolID($sequenceID) 1]
                set segname [lindex $sequenceIDToMolID($sequenceID) 2]
            
                # Make sure we have a first region.
                if {[llength $residueListsMap($molID,$chain,$segname,firstRegionRange)] == 2} {
                    
                    # Get the residue list.
                    set residueList $residueListsMap($molID,$chain,$segname)
                    
                    # Get the range of the first region.
                    set firstResidueInRegion [lindex $residueListsMap($molID,$chain,$segname,firstRegionRange) 0]
                    set firstResidueInRegionIndex [lsearch $residueList $firstResidueInRegion]
                    set lastResidueInRegion [lindex $residueListsMap($molID,$chain,$segname,firstRegionRange) 1]
                    set lastResidueInRegionIndex [lsearch $residueList $lastResidueInRegion]
    
                    # Figure out the first element to use.
                    set firstElement 0
                    set firstResidueIndex [lsearch $residueList $elementToResidueMap($sequenceID,$firstElement)]
                    if {$firstResidueInRegionIndex != -1 && $firstResidueInRegionIndex > $firstResidueIndex} {
                        set firstElement $residueToElementMap($sequenceID,[join [lrange $firstResidueInRegion 0 1] ","])
                    }
                    
                    # Figure out the last element to use.
                    set lastElement [expr [::SeqData::getSeqLength $sequenceID]-1]
                    set lastResidueIndex [lsearch $residueList $elementToResidueMap($sequenceID,$lastElement)]
                    if {$lastResidueInRegionIndex != -1 && $lastResidueInRegionIndex < $lastResidueIndex} {
                        set lastElement $residueToElementMap($sequenceID,[join [lrange $lastResidueInRegion 0 1] ","])
                    }
                    
                    # Make sure to include any gaps on either side of the region.
                    while {$firstElement > 0 && [::SeqData::getElements $sequenceID [expr $firstElement-1]] == "-"} {
                        set firstElement [expr $firstElement-1]
                    }
                    while {$lastElement < [expr [::SeqData::getSeqLength $sequenceID]-1] && [::SeqData::getElements $sequenceID [expr $lastElement+1]] == "-"} {
                        set lastElement [expr $lastElement+1]
                    }
                    
                    # Add this region to the list.
                    set elements {}
                    for {set i $firstElement} {$i <= $lastElement} {incr i} {
                        lappend elements $i
                    }
                    lappend regions $sequenceID
                    lappend regions $elements
                    
                # Otherwise this structure has no first region, so use nothing.
                } else {
                    lappend regions $sequenceID
                    lappend regions {}
                }
                
            # Otherwise this is a sequence, so just use the whole thing.
            } else {
                set elements {}
                for {set i 0} {$i < [::SeqData::getSeqLength $sequenceID]} {incr i} {
                    lappend elements $i
                }
                lappend regions $sequenceID
                lappend regions $elements
            }
        }
        
        return [::SeqData::extractRegionsFromSequences $regions]
    }
    
    # Lookup one-letter code from three-letter code.
    proc lookupCode {resname} {
    
        # Import global variables.
        variable codes
        
    
        # Find the code.
        set result ""
        if {[catch { set result $codes($resname) } ]} {
          set result "?"
        } else {
          set result "$result"
        }
    
        return $result
    }
    
    # This method gets the secondary structure for the specified sequence.
    proc calculateSecondaryStructure {sequenceID} {
        
        # Import global variables.
        variable sequenceIDToMolID
        variable elementToResidueMap
        
        # Get the mol id and chain.
        set molID [lindex $sequenceIDToMolID($sequenceID) 0]
        
        # Go through the elements.
        set secondaryStructure {}
        for {set elementIndex 0} {$elementIndex < [::SeqData::getSeqLength $sequenceID]} {incr elementIndex} {
            
            # See if the element is not a gap.
            if {$elementToResidueMap($sequenceID,$elementIndex) != ""} {
                                
                # It is not a gap, so get the secondary structure type.
                set atoms [atomselect $molID [getSelectionStringForElements $sequenceID $elementIndex]]
                lappend secondaryStructure [lindex [$atoms get structure] 0]
                $atoms delete   
            }
        }
        
        return $secondaryStructure
    }
    
    # This method computes all of the residue to element mappings for a given sequence.
    # args:     sequenceID - The id of the sequence for which to recompute the mappings.
    proc computeResidueElementMappings {sequenceID molID chain segname} {
                
        # Import global variables.
        variable residueListsMap
        variable residueToElementMap
        variable elementToResidueMap
        
        # Get the first residue.
        set firstResidue [::SeqData::getFirstResidue $sequenceID]
        
        # Get the residue list.
        set residueList $residueListsMap($molID,$chain,$segname)
        
        # Search for the first residue, in case this is a fragment.
        set residueListIndex [lsearch $residueList $firstResidue]
        if {$residueListIndex == -1} {
            set residueListIndex 0
        }
        
        # Go through the elements and map non gaps to vmd residues.
        set elementIndex 0
        foreach element [::SeqData::getSeq $sequenceID] {
            
            # See if the element is a gap.
            if {$element != "-"} {
                
                # It is not a gap, so save its residue and also save the reverse mapping.
                set residue [lindex $residueList $residueListIndex]
                set elementToResidueMap($sequenceID,$elementIndex) $residue
                set residueToElementMap($sequenceID,[join [lrange $residue 0 1] ","]) $elementIndex
                incr residueListIndex
                
            } else {
                
                # It is a gap, so save that it maps to no residue.
                set elementToResidueMap($sequenceID,$elementIndex) ""
            }
            
            incr elementIndex            
        }
    }
    
    # Gets the VMD mol id associated with a sequence id.
    # args:     sequenceID - The sequence id.
    # return    A list containing the VMD mol id and chain that maps to the specified sequence id.
    proc getMolIDForSequence {sequenceID} {
        
        # Import global variables.
        variable sequenceIDToMolID
        
        return $sequenceIDToMolID($sequenceID)
    }
    
    # Gets all of the sequence ids associated with a VMD molecule.
    # args:     molID - The VMD mol id of the molecule.
    # return    A list containing all of the sequence ids associated with the molecule.
    proc getSequenceIDsForMolecule {molID} {
        
        # Import global variables.
        variable molIDToSequenceID
        
        # Go through all of the matches and add the sequences to the list.
        set sequenceIDs {}
        set names [array names molIDToSequenceID "$molID,*"]
        foreach name $names {
            set sequenceIDs [concat $sequenceIDs $molIDToSequenceID($name)]
        }
        
        return $sequenceIDs
    }
    
    # Gets the list of sequence ids associated with a VMD molecule and chain.
    # args:     molID - The VMD mol id of the molecule.
    # return    A list containing all of the sequence ids associated with the molecule and chain.
    proc getSequenceIDForMolecule {molID chain segname} {
        
        # Import global variables.
        variable molIDToSequenceID
        
        return $molIDToSequenceID($molID,$chain,$segname)
    }
    
    proc getResidues {sequenceID {atomType "all"}} {
        
        # Import global variables.
        variable sequenceIDToMolID
        
        set molID [lindex $sequenceIDToMolID($sequenceID) 0]
            
        # Get the selection string.
        set selectionString [getSelectionStringForElements $sequenceID]
        
        # If we are just writing a specific atom type, append it to the selection.
        if {$atomType != "" && $atomType != "all"} {
            append selectionString " and $atomType"
        }
                    
        # Get the residues.
        set uniqueResidues {}
        set residues {}
        set atoms [atomselect $molID $selectionString]
        set atomPropsList [$atoms get {resid insertion altloc}]
        $atoms delete
        unset atoms
        foreach atomProps $atomPropsList {
                            
            # Get the residue id.
            set resID [lindex $atomProps 0]
            set insertion [lindex $atomProps 1]
            set altloc [lindex $atomProps 2]
            
            if {[lsearch $uniqueResidues "$resID$insertion"] == -1} {
                lappend uniqueResidues "$resID$insertion"
                if {$insertion == " " && $altloc == ""} {
                    lappend residues $resID
                } else {
                    
                    lappend residues [list $resID $insertion $altloc]
                    set updateIndex [lsearch $residues $resID]
                    if {$updateIndex != -1} {
                        set residues [lreplace $residues $updateIndex $updateIndex [list $resID " " ""]]
                    }
                }
            }             
        }
        return $residues
    }
    
    # Gets the VMD mol id associated with a sequence id.
    # args:     sequenceID - The sequence id.
    # return    The VMD mol id that maps to the specified sequence id.
    proc getResidueForElement {sequenceID element} {
        
        # Import global variables.
        variable elementToResidueMap
        
        return $elementToResidueMap($sequenceID,$element)
    }
    
    # Gets the VMD mol id associated with a sequence id.
    # args:     sequenceID - The sequence id.
    # return    The VMD mol id that maps to the specified sequence id.
    proc getElementForResidue {sequenceID residue} {
        
        # Import global variables.
        variable residueToElementMap
        
        if {[info exists residueToElementMap($sequenceID,[join [lrange $residue 0 1] ","])]} {
            return $residueToElementMap($sequenceID,[join [lrange $residue 0 1] ","])
        } elseif {[llength $residue] > 1 && [info exists residueToElementMap($sequenceID,[lindex $residue 0])]} {
            return $residueToElementMap($sequenceID,[lindex $residue 0])
        }
        
        return -1
    }
    
    # This method determines the type of the molecule.
    # args:     sequenceID - The sequence if for which the type should be retrieved.
    # return:   The type of the sequence: nucleic, protein, or unknown.
    proc determineType {molID chain segname} {
        
        if {$segname == ""} {
            set proteinAtoms [atomselect $molID "chain $chain and protein"]
            set nucleicAtoms [atomselect $molID "chain $chain and nucleic"]
        } else {
            set proteinAtoms [atomselect $molID "chain $chain and segname \"$segname\" and protein"]
            set nucleicAtoms [atomselect $molID "chain $chain and segname \"$segname\" and nucleic"]
        }
        set proteinAtomCount [$proteinAtoms num]
        set nucleicAtomCount [$nucleicAtoms num]
        
        # See what type of molecule vmd thinks this is.
        set type "unknown"
        if {$proteinAtomCount > 0 && $nucleicAtomCount > 0} {
            if {$proteinAtomCount > $nucleicAtomCount} {
                set type "protein"
            } else {
                set type "nucleic"
            }
        } elseif {$proteinAtomCount > 0} {
            set type "protein"
        } elseif {$nucleicAtomCount > 0} {
            set type "nucleic"
        }
        
        # Delete the selection.
        $proteinAtoms delete
        unset proteinAtoms
        $nucleicAtoms delete
        unset nucleicAtoms
        
        # If vmd couldn't tell, try to figure it out ourselves.
        if {$type == "unknown"} {
            
            if {$segname == ""} {
                set proteinAtoms [atomselect $molID "chain $chain and name CA"]
                set nucleicAtoms [atomselect $molID "chain $chain and name P"]
            } else {
                set proteinAtoms [atomselect $molID "chain $chain and segname \"$segname\" and name CA"]
                set nucleicAtoms [atomselect $molID "chain $chain and segname \"$segname\" and name P"]
            }
            set proteinAtomCount [$proteinAtoms num]
            set nucleicAtomCount [$nucleicAtoms num]
            if {$proteinAtomCount > 0 && $nucleicAtomCount > 0} {
                if {$proteinAtomCount > $nucleicAtomCount} {
                    set type "protein"
                } else {
                    set type "nucleic"
                }
            } elseif {$proteinAtomCount > 0} {
                set type "protein"
            } elseif {$nucleicAtomCount > 0} {
                set type "nucleic"
            }
            $proteinAtoms delete
            unset proteinAtoms
            $nucleicAtoms delete
            unset nucleicAtoms            
        }
        
        return $type
    }
        
    proc writeStructure {sequenceID filename {atomType "all"} {elements "all"} {copyUser 0}} {
        
        # Import global variables.
        variable sequenceIDToMolID

        # Select the atoms and write them out to the file.        
        set molID [lindex $sequenceIDToMolID($sequenceID) 0]
        
        # Get the selection string.
        set selectionString [getSelectionStringForElements $sequenceID $elements]
        
        # If we are just writing a specific atom type, append it to the selection.
        if {$atomType != "" && $atomType != "all"} {
            append selectionString " and $atomType"
        }
        
        #Copy user data into beta feild
        if {$copyUser == 1} {
            set atoms [atomselect $molID $selectionString]
            set beta [$atoms get beta]
            $atoms set beta [$atoms get user]
            $atoms writepdb $filename
            $atoms set beta $beta
            $atoms delete
            unset atoms
        
        } else {
            # Write the atoms.
            set atoms [atomselect $molID $selectionString]
            $atoms writepdb $filename
            $atoms delete
            unset atoms
        }
    }
    
    proc getSelectionStringForSequence {sequenceID} {
        
        # Import global variables.
        variable sequenceIDToMolID
        
        # Select the atoms and write them out to the file.        
        set molID [lindex $sequenceIDToMolID($sequenceID) 0]
        set chain [lindex $sequenceIDToMolID($sequenceID) 1]
        set segname [lindex $sequenceIDToMolID($sequenceID) 2]
        
        if {$segname == ""} {
            return "chain $chain"
        } else {
            return "chain $chain and segname \"$segname\""
        }
    }

    proc getSelectionStringForElements {sequenceID {elements "all"}} {
        
        # Import global variables.
        variable sequenceIDToMolID
        variable elementToResidueMap

        # If we are using all elements, get the list.
        if {$elements == "all"} {
            set elements {}
            for {set i 0} {$i < [::SeqData::getSeqLength $sequenceID]} {incr i} {
                lappend elements $i
            }
        }
        
        # Select the atoms and write them out to the file.        
        set molID [lindex $sequenceIDToMolID($sequenceID) 0]
        set chain [lindex $sequenceIDToMolID($sequenceID) 1]
        set segname [lindex $sequenceIDToMolID($sequenceID) 2]
        
        set resIDSelection ""
        set exceptionSelection ""
        foreach element $elements {
            
            # Get the residue that corresponds to the element and, if it is valid, add it to the string.
            # resid 618 619 or (resid 620 and insertion "A")
            set residue $elementToResidueMap($sequenceID,$element)
            if {$residue != ""} {
                if {[llength $residue] == 1} {
                    set resID $residue
                    if {$resIDSelection == ""} {
                        set resIDSelection "resid"
                    }
                    if {$resID < 0} {
                        append resIDSelection " \"" $resID "\""
                    } else {
                        append resIDSelection " " $resID
                    }
                } else {
                    set resID [lindex $residue 0]
                    set insertion [lindex $residue 1]
                    set altloc [lindex $residue 2]
                    if {$exceptionSelection != ""} {
                        append exceptionSelection " or "
                    }
                    if {$insertion != " " && $altloc != ""} {
                        append exceptionSelection "(resid \"$resID\" and insertion \"$insertion\" and altloc \"$altloc\" \"\")"
                    } elseif {$insertion != " "} {
                        append exceptionSelection "(resid \"$resID\" and insertion \"$insertion\")"
                    } elseif {$altloc != ""} {
                        append exceptionSelection "(resid \"$resID\" and altloc \"$altloc\" \"\")"
                    } else {
                        append exceptionSelection "(resid \"$resID\" and insertion \" \")"
                    }
                }
            }
        }
        
        set segnameSelection ""
        if {$segname != ""} {
            set segnameSelection "segname \"$segname\" and"
        }
        
        if {$resIDSelection == "" && $exceptionSelection != ""} {
            return "chain $chain and $segnameSelection ($exceptionSelection)"
        } elseif {$resIDSelection != "" && $exceptionSelection == ""} {
            return "chain $chain and $segnameSelection ($resIDSelection)"
        } elseif {$resIDSelection != "" && $exceptionSelection != ""} {
            return "chain $chain and $segnameSelection ($resIDSelection or $exceptionSelection)"
        }
        
        return "none"
    }
    
    # This method is called by the SeqData package whenever one of the VMD sequences has been
    # changed.
    proc sequenceChanged {changeType sequenceID {arg1 ""} {arg2 ""}} {
        
        # Call the appropriate function.
        if {$changeType == "setSeq"} {
            return [setSeq $sequenceID $arg1]
        } elseif {$changeType == "removeElements"} {
            return [removeElements $sequenceID $arg1]
        } elseif {$changeType == "setElements"} {
            return [setElements $sequenceID $arg1 $arg2]
        } elseif {$changeType == "insertElements"} {
            return [insertElements $sequenceID $arg1 $arg2]
        } elseif {$changeType == "setFirstResidue"} {
            return [setFirstResidue $sequenceID $arg1]
        } else {
            return 0
        }
    }
    
    proc setSeq {sequenceID sequence} {
    
        # Import global variables.
        variable ::SeqData::seqs
        variable sequenceIDToMolID
        
        # Set the new sequence.
        set ::SeqData::seqs($sequenceID,seq) $sequence
        set ::SeqData::seqs($sequenceID,seqLength) [llength $sequence]
        
        # Recompute the mappings.
        computeResidueElementMappings $sequenceID [lindex $sequenceIDToMolID($sequenceID) 0] [lindex $sequenceIDToMolID($sequenceID) 1] [lindex $sequenceIDToMolID($sequenceID) 2]
        
        return 1
    }
    
    proc removeElements {sequenceID elementIndexes} {
    
        # Import global variables.
        variable ::SeqData::seqs
        variable sequenceIDToMolID
    
        # Get the sequence.
        set sequence $::SeqData::seqs($sequenceID,seq)
        
        # Make sure we are only removing gaps.
        foreach elementIndex $elementIndexes {
            if {[lindex $sequence $elementIndex] != "-"} {
                return 0
            }
        }
        
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
        set ::SeqData::seqs($sequenceID,seq) $sequence
        set ::SeqData::seqs($sequenceID,seqLength) [llength $sequence]

        # Recompute the mappings.
        computeResidueElementMappings $sequenceID [lindex $sequenceIDToMolID($sequenceID) 0] [lindex $sequenceIDToMolID($sequenceID) 1] [lindex $sequenceIDToMolID($sequenceID) 2]
        
        return 1
    }
    
    proc setElements {sequenceID elementIndexes newElement} {
    
         return 0
    }
    
    proc insertElements {sequenceID position newElements} {
    
        # Import global variables.
        variable ::SeqData::seqs
        variable sequenceIDToMolID
    
        # Make sure we are only inserting gaps.
        foreach newElement $newElements {
            if {$newElement != "-"} {
                return 0
            }
        }
        
        # Insert the new elements.
        if {$position == "end"} {
            set position [expr [llength $::SeqData::seqs($sequenceID,seq)]-1]
        }
        set ::SeqData::seqs($sequenceID,seq) [concat [lrange $::SeqData::seqs($sequenceID,seq) 0 [expr $position-1]] $newElements [lrange $::SeqData::seqs($sequenceID,seq) $position end]]
        
        # Set the new sequence length.
        set ::SeqData::seqs($sequenceID,seqLength) [llength $::SeqData::seqs($sequenceID,seq)]
        
        # Recompute the mappings.
        computeResidueElementMappings $sequenceID [lindex $sequenceIDToMolID($sequenceID) 0] [lindex $sequenceIDToMolID($sequenceID) 1] [lindex $sequenceIDToMolID($sequenceID) 2]
        
        return 1
    }
    
    proc setFirstResidue {sequenceID firstResidue} {
        
        # Import global variables.
        variable ::SeqData::seqs
        variable sequenceIDToMolID
    
        # Save the new first residue.
        set ::SeqData::seqs($sequenceID,firstResidue) $firstResidue
        
        # Recompute the mappings.
        computeResidueElementMappings $sequenceID [lindex $sequenceIDToMolID($sequenceID) 0] [lindex $sequenceIDToMolID($sequenceID) 1] [lindex $sequenceIDToMolID($sequenceID) 2]
        
        return 1
    }
}
