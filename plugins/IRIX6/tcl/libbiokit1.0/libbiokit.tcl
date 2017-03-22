############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################


package provide libbiokit 1.0

namespace eval ::Libbiokit {
    
    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "libbiokit"
    
    # This method sets the temp file options used by the libbiokit package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        # Import global variables.
        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
    # cutoffType 0=percent identity; 1=percent of sequences
    # method 0=protein; 1=binary; 2=nucleic acid
    proc getNonRedundantSequences {sequenceIDs {cutoffType 0} {cutoff 40} {gapScale 1.0} {numberToPreserve 0} {method 0} {norm 2}} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Figure out the method.
        set methodCode "-a"
        if {$method == 1} {
            set methodCode "-b"
        } elseif {$method == 2} {
            set methodCode "-r"
        }
        
        # Figure out the cutoff type.
        set cutoffCode "-i"
        if {$cutoffType == 1} {
            set cutoffCode "-l"
        }
        
        # Remove any previous qr ordering annotations.
        foreach sequenceID $sequenceIDs {
            ::SeqData::addAnnotation $sequenceID "qr-ordering" ""
        }
        
        # Write out the alignment in a FASTA file.
        writeSequenceAlignment $sequenceIDs
            
        # Run the command.  
        set out [run "$tempDir" "seqqr" "$methodCode" "$cutoffCode" "$cutoff" "-o" "$norm" "-s" "$gapScale" "-p" "$numberToPreserve" "$filePrefix.fasta" "$filePrefix.out"]
        
        # Read in the set of nr sequences.
        set nrSequenceIDs [::SeqData::Fasta::loadSequences "$tempDir/$filePrefix.out"]
        
        # Find the corresponding sequence ids in the original list.
        set orderNumber 1
        set ret {}
        foreach nrSequenceID $nrSequenceIDs {
            
            # The name of the loaded sequence is the original sequence id.
            set sequenceID [::SeqData::getName $nrSequenceID]
            
            # Check the id, to make sure something didn't go wrong.
            if {[lsearch -exact $sequenceIDs $sequenceID] != -1} {
                lappend ret $sequenceID
                ::SeqData::addAnnotation $sequenceID "qr-ordering" $orderNumber
                incr orderNumber
            }
        }
        
        # Delete the loaded sequences.
        ::SeqData::deleteSequences $nrSequenceIDs
        
        return $ret
    }
    
    proc getNonRedundantStructures {sequenceIDs {cutoff 0.75} {numberToPreserve 0} {cutoffMethod "qh"}} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Remove any previous qr ordering annotations.
        foreach sequenceID $sequenceIDs {
            ::SeqData::addAnnotation $sequenceID "qr-ordering" ""
        }
        
        # Write out a PDB file for each sequence and a FASTA file for the alignment.
        set writtenStructures [writeStructureFiles $sequenceIDs]
        set type [lindex $writtenStructures 0]
        set newSequenceIDs [lindex $writtenStructures 1]
        set writtenSequenceIDs [lindex $writtenStructures 2]
        
        set ordering {}
        if {[llength $writtenSequenceIDs] > 0} {
            
            # Run the correct command for the atom type.        
            if {$type == "nucleic"} {
                set out [run "$tempDir" "structqr" "-q" "-r" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "structqr" "-q" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            }
            
            # Read in the results.
            set dataFile [open "$tempDir/$filePrefix.out" r]
            while {![eof $dataFile]} {
                if {[gets $dataFile line] > 0} {
                    if {$line != ""} {
                        set ordering [split [string trim $line]]
                    }
                }
            }
            close $dataFile
        }
        
        # Get the QH values for the structures.
        set ret {}
        if {$cutoffMethod == "qh"} {
            
            # Get the pairwise QH values.
            set matrix [::Libbiokit::getPairwiseQH $sequenceIDs]
            
            # Only keep structures in the ordering until we go above the cutoff.
            for {set i 0} {$i < [llength $ordering]} {incr i} {
                
                # Get the index of the sequence at this spot in the ordering.
                set index [lindex $ordering $i]
                
                # Get the QH score of the sequence.
                set scores [lindex $matrix $index]
                
                # See if the sequence is above the cutoff with each sequence before it in the ordering.
                set aboveCutoff 0
                for {set j 0} {$j < $i} {incr j} {
                    if {[expr 1.0-[lindex $scores [lindex $ordering $j]]] > $cutoff} {
                        set aboveCutoff 1
                        break
                    }
                }
                
                # If we are above the cutoff, we are done.
                if {$aboveCutoff} {
                    break
                } else {
                    lappend ret [lindex $sequenceIDs $index]
                    ::SeqData::addAnnotation [lindex $sequenceIDs $index] "qr-ordering" [expr $i+1]
                }
            }
            
        } elseif {$cutoffMethod == "rmsd"} {
            
            # Get the pairwise RMSD values.
            set matrix [getPairwiseRMSD $sequenceIDs]
            
            # Only keep structures in the ordering until we go below the cutoff.
            for {set i 0} {$i < [llength $ordering]} {incr i} {
                
                # Get the index of the sequence at this spot in the ordering.
                set index [lindex $ordering $i]
                
                # Get the RMSD score of the sequence.
                set scores [lindex $matrix $index]
                
                # See if the sequence is below the cutoff with each sequence before it in the ordering.
                set belowCutoff 0
                for {set j 0} {$j < $i} {incr j} {
                    if {[expr [lindex $scores [lindex $ordering $j]]] <= $cutoff} {
                        set belowCutoff 1
                        break
                    }
                }
                
                # If we are above the cutoff, we are done.
                if {$belowCutoff} {
                    break
                } else {
                    lappend ret [lindex $sequenceIDs $index]
                    ::SeqData::addAnnotation [lindex $sequenceIDs $index] "qr-ordering" [expr $i+1]
                }
            }
        }
        
        return $ret
    }
    
    proc getPairwiseRMSD {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out a PDB file for each sequence and a FASTA file for the alignment.
        set writtenStructures [writeStructureFiles $sequenceIDs]
        set type [lindex $writtenStructures 0]
        set newSequenceIDs [lindex $writtenStructures 1]
        set writtenSequenceIDs [lindex $writtenStructures 2]
        
        set matrix {}
        if {[llength $writtenSequenceIDs] > 0} {
            
            # Run the correct command for the atom type.        
            if {$type == "nucleic"} {
                set out [run "$tempDir" "rmsd" "-r" "$filePrefix.fasta" "\"$tempDir/\"" "$filePrefix.out"]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "rmsd" "$filePrefix.fasta" "\"$tempDir/\"" "$filePrefix.out"]
            }
            
            # Read in the results.
            set fp [open "$tempDir/$filePrefix.out" r]
            set output [read $fp]
            close $fp
            
            # Get the pairwise RMSD values.
            set row {}
            foreach entry [split $output] {
                if {$entry != {}} {
                    lappend row $entry
                    if {[llength $row] >= [llength $sequenceIDs]} {
                        lappend matrix $row
                        set row {}                        
                    }
                }
            }
        }
        
        return $matrix
    }
    
    # This method gets the RMSD score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the RMSD score of.
    # return:   A list containing, for each sequence, a list of the RMSD score for its residues. 
    proc getRMSDPerResidue {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out a PDB file for each sequence and a FASTA file for the alignment.
        set writtenStructures [writeStructureFiles $sequenceIDs]
        set type [lindex $writtenStructures 0]
        set newSequenceIDs [lindex $writtenStructures 1]
        set writtenSequenceIDs [lindex $writtenStructures 2]
        
        set scores {}
        if {[llength $writtenSequenceIDs] > 0} {
            
            # Run the correct command for the atom type.        
            if {$type == "nucleic"} {
                set out [run "$tempDir" "rmsd" "-r" "-p" "$filePrefix.fasta" "\"$tempDir/\"" "$filePrefix.out"]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "rmsd" "-p" "$filePrefix.fasta" "\"$tempDir/\"" "$filePrefix.out"]
            }
            
            # Read in the results.
            set dataFile [open "$tempDir/$filePrefix.out" r]
            while {![eof $dataFile]} {
                if {[gets $dataFile line] > 0} {
                    set columns [split $line]
                    if {[lindex $columns end] == {}} {
                        set columns [lrange $columns 0 [expr [llength $columns]-2]]
                    }
                    lappend scores $columns
                }
            }
            close $dataFile
        }
        
        # Construct the list to be returned by adding lists for sequences that did not have structures.
        set ret {}
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
            
            # Get the sequence ids.
            set sequenceID [lindex $sequenceIDs $i]
            set newSequenceID [lindex $newSequenceIDs $i]
            
            # If this sequences was one that we ran RMSD on.
            set index [lsearch $writtenSequenceIDs $newSequenceID]
            if {$index != -1} {

                # Get the scores for the elements.
                set elementScores [lindex $scores $index]
                
                # Make sure we got the right number of scores.
                if {[::SeqData::getSeqLength $newSequenceID] != [llength $elementScores]} {
                    error "An unknown error occurred while processing [::SeqData::getName $sequenceID]: [::SeqData::getSeqLength $newSequenceID], [llength $elementScores]"
                }
                
                # If the original sequence was longer, add the remaining gaps.
                for {set j [::SeqData::getSeqLength $newSequenceID]} {$j < [::SeqData::getSeqLength $sequenceID]} {incr j} {
                    lappend elementScores -1.0
                }
                
                # Save the scores.
                lappend ret $elementScores
                
            # Otherwise was not run on this sequence.
            } else {
                
                # Add a list of zero scores for this sequence.
                set elementScores {}
                for {set j 0} {$j < [::SeqData::getSeqLength $sequenceID]} {incr j} {
                    lappend elementScores -1.0
                }
                lappend ret $elementScores
            }
        }
        
        return $ret
    }
    
    proc getPairwisePercentIdentity {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out the alignment in a FASTA file.
        writeSequenceAlignment $sequenceIDs
        
        # Run the command.        
        set out [run "$tempDir" "percid" "$filePrefix.fasta" "$filePrefix.out"]
        
        # Read in the results.
        set fp [open "$tempDir/$filePrefix.out" r]
        set output [read $fp]
        close $fp
        
        # Get the pairwise RMSD values.
        set matrix {}
        set row {}
        foreach entry [split $output] {
            if {$entry != {}} {
                lappend row $entry
                if {[llength $row] >= [llength $sequenceIDs]} {
                    lappend matrix $row
                    set row {}                        
                }
            }
        }
        
        return $matrix
    }
    
    # This method gets the Q score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the Q score of.
    # return:   A list containing, for each sequence, the QH for that sequence
    proc getPairwiseQH {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out a PDB file for each sequence and a FASTA file for the alignment.
        set writtenStructures [writeStructureFiles $sequenceIDs]
        set type [lindex $writtenStructures 0]
        set newSequenceIDs [lindex $writtenStructures 1]
        set writtenSequenceIDs [lindex $writtenStructures 2]
                        
        # Run the correct command for the atom type.        
        set matrix {}
        if {[llength $writtenSequenceIDs] > 0} {
                                    
            if {$type == "nucleic"} {
                set out [run "$tempDir" "qpair" "-r" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "qpair" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            }
            
            # Read in the results.
            set fp [open "$tempDir/$filePrefix.out" r]
            set output [read $fp]
            close $fp
            
            # Get the pairwise QH values.
            set row {}
            foreach entry [split $output] {
                if {$entry != {}} {
                    lappend row $entry
                    if {[llength $row] >= [llength $sequenceIDs]} {
                        lappend matrix $row
                        set row {}                        
                    }
                }
            }
        }
        
        return $matrix
    }
    
    # This method gets the Q score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the Q score of.
    # return:   A list containing, for each sequence, a list of the Q score for its residues. 
    proc getQPerResidue {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out a PDB file for each sequence and a FASTA file for the alignment.
        set writtenStructures [writeStructureFiles $sequenceIDs]
        set type [lindex $writtenStructures 0]
        set newSequenceIDs [lindex $writtenStructures 1]
        set writtenSequenceIDs [lindex $writtenStructures 2]
        
        set qScores {}
        if {[llength $writtenSequenceIDs] > 0} {
                                    
            # Run the correct command for the atom type.        
            if {$type == "nucleic"} {
                set out [run "$tempDir" "qpair" "-p" "-r" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "qpair" "-p" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            }
            
            # Read in the results.
            set dataFile [open "$tempDir/$filePrefix.out" r]
            while {![eof $dataFile]} {
                if {[gets $dataFile line] > 0} {
                    set scores [split $line]
                    if {[lindex $scores end] == {}} {
                        set scores [lrange $scores 0 [expr [llength $scores]-2]]
                    }
                    lappend qScores $scores
                }
            }
            close $dataFile
        }
        
        # Construct the list to be returned by adding lists for sequences that did not have structures.
        set ret {}
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
            
            # Get the sequence ids.
            set sequenceID [lindex $sequenceIDs $i]
            set newSequenceID [lindex $newSequenceIDs $i]
            
            # If this sequences was one that we ran.
            set index [lsearch $writtenSequenceIDs $newSequenceID]
            if {$index != -1} {

                # Get the scores for the residues.
                set residueScores [lindex $qScores $index]
                
                # Create a list of scores for the elements in the new sequence.
                set elementScores {}
                set residueIndex 0
                set sequence [::SeqData::getSeq $newSequenceID]
                for {set j 0} {$j < [::SeqData::getSeqLength $newSequenceID]} {incr j} {
                    if {[lindex $sequence $j] == "-"} {
                        lappend elementScores 0.0
                    } else {
                        lappend elementScores [lindex $residueScores $residueIndex]
                        incr residueIndex
                    }
                }
                
                # Make sure we used all of the scores.
                if {$residueIndex != [llength $residueScores]} {
                    error "An unknown error occurred while processing [::SeqData::getName $sequenceID]: $residueIndex, [llength $residueScores]"
                }
                
                # If the original sequence was longer, add the remaining gaps.
                for {set j [::SeqData::getSeqLength $newSequenceID]} {$j < [::SeqData::getSeqLength $sequenceID]} {incr j} {
                    lappend elementScores 0.0
                }
                
                # Save the scores.
                lappend ret $elementScores
                
            # Otherwise the operation not run on this sequence.
            } else {
                
                # Add a list of zero scores for this sequence.
                set elementScores {}
                for {set j 0} {$j < [::SeqData::getSeqLength $sequenceID]} {incr j} {
                    lappend elementScores 0.0
                }
                lappend ret $elementScores
            }
        }
        
        return $ret
    }
    
    proc writeSequenceAlignment {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
        
        # Extract the segments we will be using in the calculation.
        set extractedRegions [::SeqData::VMD::extractFirstRegionFromStructures $sequenceIDs]
        set newSequenceIDs [lindex $extractedRegions 1]
        set prefixes [lindex $extractedRegions 2]
        
        # Replace any removed prefix with gaps to preserve the alignment.
        for {set i 0} {$i < [llength $newSequenceIDs]} {incr i} {
            set newSequenceID [lindex $newSequenceIDs $i]
            set prefix [lindex $prefixes $i]
            if {$prefix != {}} {
                ::SeqData::setSeq $newSequenceID [concat [::SeqData::getGaps [llength $prefix]] [::SeqData::getSeq $newSequenceID]]
            }
        }

        # Make sure all of the sequences are aligned.
        set alignmentLength -1
        for {set i 0} {$i < [llength $newSequenceIDs]} {incr i} {
            set newSequenceID [lindex $newSequenceIDs $i]
            if {$alignmentLength == -1} {
                set alignmentLength [::SeqData::getSeqLength $newSequenceID]
            } elseif {[::SeqData::getSeqLength $newSequenceID] !=  $alignmentLength} {
                error "The operation could not be performed because the sequences were not aligned."
            }   
        }

        # Save the sequences.
        ::SeqData::Fasta::saveSequences $newSequenceIDs "$tempDir/$filePrefix.fasta" $sequenceIDs {} 0
        
        # Delete the new sequences.
        ::SeqData::deleteSequences $newSequenceIDs
    }
        
    proc writeStructureFiles {sequenceIDs} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
        
        # Extract the segments we will be using in the calculation.
        set extractedRegions [::SeqData::VMD::extractFirstRegionFromStructures $sequenceIDs]
        set newSequenceIDs [lindex $extractedRegions 1]
        set prefixes [lindex $extractedRegions 2]
        
        # Replace any removed prefix with gaps to preserve the alignment.
        for {set i 0} {$i < [llength $newSequenceIDs]} {incr i} {
            set newSequenceID [lindex $newSequenceIDs $i]
            set prefix [lindex $prefixes $i]
            if {$prefix != {}} {
                ::SeqData::setSeq $newSequenceID [concat [::SeqData::getGaps [llength $prefix]] [::SeqData::getSeq $newSequenceID]]
            }
        }

        # Make sure all of the sequences are aligned.
        set alignmentLength -1
        for {set i 0} {$i < [llength $newSequenceIDs]} {incr i} {
            set newSequenceID [lindex $newSequenceIDs $i]
            if {$alignmentLength == -1} {
                set alignmentLength [::SeqData::getSeqLength $newSequenceID]
            } elseif {[::SeqData::getSeqLength $newSequenceID] !=  $alignmentLength} {
                puts "Libbiokit Error) [::SeqData::getName $newSequenceID] was [::SeqData::getSeqLength $newSequenceID], alignment was $alignmentLength"
                error "The operation could not be performed because the sequences were not aligned."
            }   
        }

        # Go through the sequences and write out a PDB for each structure.
        set type ""
        set writtenSequenceIDs {}
        set writtenSequenceNames {}
        set writtenSequenceDescriptions {}
        for {set i 0} {$i < [llength $newSequenceIDs]} {incr i} {
            
            # Get the sequence. 
            set sequenceID [lindex $newSequenceIDs $i]
            
            # Make sure this is a structure.            
            if {[::SeqData::hasStruct $sequenceID] == "Y"} {

                # See what kind of sequence we are looking for, if we don't already know.
                if {$type == ""} {
                    set type [::SeqData::getType $sequenceID]
                    if {$type != "protein" && $type != "nucleic"} {
                        error "The operation could not be performed because [::SeqData::getName $sequenceID] was not a protein or nucleic structure."
                    }
                }
                
                # See if this sequence is of the right type.
                if {[::SeqData::getType $sequenceID] == $type} {
                    
                    # Write out the PDB files with the backbone atoms for stamp to use.
                    if {$type == "protein"} {
                        ::SeqData::VMD::writeStructure $sequenceID "$tempDir/$filePrefix.$i.pdb" "name CA"
                    } elseif {$type == "nucleic"} {
                        ::SeqData::VMD::writeStructure $sequenceID "$tempDir/$filePrefix.$i.pdb" "name P"
                    }
                    
                    # Add it to the list of sequences to write out in the FASTA file.
                    lappend writtenSequenceIDs $sequenceID
                    lappend writtenSequenceNames $filePrefix.$i.pdb
                    lappend writtenSequenceDescriptions ""
                    
                } else {
                    error "The operation could not be performed because [::SeqData::getName $sequenceID] was not a $type structure."
                }
            }
        }
        
        # Write out the alignment in a FASTA file.
        if {[llength $writtenSequenceIDs] > 0} {
            SeqData::Fasta::saveSequences $writtenSequenceIDs "$tempDir/$filePrefix.fasta" $writtenSequenceNames $writtenSequenceDescriptions 0
        }
        
        return [list $type $newSequenceIDs $writtenSequenceIDs]
    }
        
    proc run {wd program args} {
        
        global env
    
        set plugindir $env(LIBBIOKITPLUGINDIR)

        switch [vmdinfo arch] {
            WIN32 {
                set cmd "exec {$plugindir/$program.exe}"
                append wd "/" 
            }
            default {
                set cmd "exec {$plugindir/$program}"
            }
        }
    
        set pwd [pwd]
    
        cd "$wd"
    
        foreach arg $args {
            append cmd " $arg"
        }
    
        puts "Libbiokit Info) Running $program with command $cmd"
        
        # Run the command and then return to the working directory.
        set rc [catch {eval $cmd} out]        
        cd $pwd
        
        # If there was an error during execution, throw it.
        if {$rc != 0} {
            error $out
        }
    
        return $out
    }
}
