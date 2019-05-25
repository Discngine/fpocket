############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: libbiokit.tcl,v 1.7 2013/04/15 16:29:19 johns Exp $
#

package provide libbiokit 1.1

namespace eval ::Libbiokit {

    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "libbiokit"

    # The level of verbosity, 0=silent, 1=errors, 2=errors+info
    variable verbosity 1

# ------------------------------------------------------------------------
    # This method sets the temp file options used by the libbiokit package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        variable tempDir
        variable filePrefix

        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }

# ------------------------------------------------------------------------
    proc cleanup {} {

        variable tempDir
        variable filePrefix

        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
    }

#--------------------------------------------------------------------------
    # cutoffType 0=percent identity; 1=percent of sequences
    # method 0=protein; 1=binary; 2=nucleic acid
    proc getNonRedundantSequences {sequenceIDs {cutoffType 0} {cutoff 40} {gapScale 1.0} {numberToPreserve 0} {method 0} {norm 2}} {

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

#--------------------------------------------------------------------------
    proc getNonRedundantStructures {sequenceIDs {cutoff 0.75} {numberToPreserve 0} {cutoffMethod "qh"}} {
#       puts "libbiokit.tcl.getNonRedundantStructures. seqIDs: $sequenceIDs, cutoff: $cutoff, num: $numberToPreserve, cutoffMethod: $cutoffMethod"

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

#       puts "libbiokit.tcl.getNonRedundantStructures. seqIDs: $sequenceIDs, cutoff: $cutoff, num: $numberToPreserve, cutoffMethod: $cutoffMethod, writtenStructs: $writtenStructures"
        set ordering {}
        if {[llength $writtenSequenceIDs] > 0} {

            # Run the correct command for the atom type.        
            if {$type == "dna" || $type == "rna"} {
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
#       puts "libbiokit.tcl.getNonRedundantStructures.end"

        return $ret
    }

# ------------------------------------------------------------------------
    proc getPairwiseRMSD {sequenceIDs} {

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
            if {$type == "dna" || $type == "rna" } {
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

# ------------------------------------------------------------------------
    # This method gets the RMSD score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the RMSD score of.
    # return:   A list containing, for each sequence, a list of the RMSD score for its residues. 
    proc getRMSDPerResidue {sequenceIDs} {

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
            if {$type == "dna" || $type == "rna" } {
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

# --------------------------------------------------------------------------
   proc getPairwisePercentIdentity {sequenceIDs} {
#      puts "libbiokit.tcl.getPairwisePercentIdentity.start seqIDs: $sequenceIDs";  
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
#      puts "getPairwise.. output is <$output>"


      # Get the pairwise RMSD values.
      set matrix {}
      set row {}
      foreach itm [split $output] {
#         puts "getPairwise.. itm is <$itm>"
         if {$itm != {}} {
            lappend row $itm
            if {[llength $row] >= [llength $sequenceIDs]} {
               lappend matrix $row
               set row {}                        
            }
         }
      }

      return $matrix
   }
# --------------------------------------------------------------------------
    # This method gets the Q score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the Q score of.
    # return:   A list containing, for each sequence, the QH for that sequence
    proc getPairwiseQH {sequenceIDs} {

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

            if {$type == "dna" || $type == "rna" } {
                set out [run "$tempDir" "qpair" "-r" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            } elseif {$type == "protein"} {
                set out [run "$tempDir" "qpair" "-o" "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
            } else {
               puts "libbiokit.getPairwiseQH.  bad type: $type"
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

# ------------------------------------------------------------------------
    # This method gets the Q score for each residue in the specified sequences.
    # args:     sequences - The seqences to compute the Q score of.
    # return:   A list containing, for each sequence, a list of the Q score for its residues. 
   proc getQPerResidue {sequenceIDs} {
#      puts "libbiokit.getQPerResidue.start.  seqIDs: {$sequenceIDs}"
      variable tempDir
      variable filePrefix

      # Delete any old files.
      foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
         file delete -force $file
      }

      # Write out a PDB file for each sequence and a FASTA file for alignment.
      set writtenStructures [writeStructureFiles $sequenceIDs]
#      puts "libbiokit.tcl.getQPerResidue:writtenStructs: {$writtenStructures}"
      set type [lindex $writtenStructures 0]
      set newSequenceIDs [lindex $writtenStructures 1]
      set writtenSequenceIDs [lindex $writtenStructures 2]

#      puts "getQPerResidue: writtenStruct: $writtenStructures"

      set qScores {}
      if {[llength $writtenSequenceIDs] > 0} {
         if {[llength $writtenSequenceIDs] == 1} {
            puts "libbiokit.getQPerResidue: Trying to get Q on a single structure.  Results are not likely to be useful."
         }
#         puts "getQPerResidue: inside IF.  filePrefix: $filePrefix, tempdir: $tempDir"
         # Run the correct command for the atom type.      
         if {$type == "dna" || $type == "rna" } {
            set out [run "$tempDir" "qpair" "-p" "-r" "-o" \
                         "$filePrefix.out" "$filePrefix.fasta" "\"$tempDir/\""]
         } elseif {$type == "protein"} {
            set out [run "$tempDir" "qpair" "-p" "-o" "$filePrefix.out" \
                                           "$filePrefix.fasta" "\"$tempDir/\""]
         } else {
            error "libbiokit.getQPerResidue.  bad type: $type"
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
#      puts "libbiokit.tcl.getQPerResidue:qScores: {$qScores}" 

      # Construct list to be returned by adding lists for 
      # sequences that did not have structures.
      set ret {}
      for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {

         # Get the sequence ids.
         set sequenceID [lindex $sequenceIDs $i]
         set newSequenceID [lindex $newSequenceIDs $i]

         # If this sequences was one that we ran.
         set index [lsearch $writtenSequenceIDs $newSequenceID]

#         puts "libbiokit.tcl.getQperRes: seqID:$sequenceID, nSeqID:$newSequenceID, ind: $index"
         if {$index != -1} {

            # Get the scores for the residues.
            set residueScores [lindex $qScores $index]

            # Create a list of scores for the elements in the new sequence.
            set elementScores {}
            set residueIndex 0
            set sequence [::SeqData::getSeq $newSequenceID]
#            puts "libbiokit.tcl.getQperRes: resScores: $residueScores, seq: $sequence"

            for {set j 0} {$j < [::SeqData::getSeqLength $newSequenceID]} \
                                                                    {incr j} {
               if {[lindex $sequence $j] == "-"} {
                  lappend elementScores 0.0
               } else {
                  lappend elementScores [lindex $residueScores $residueIndex]
                  incr residueIndex
               }
            }

            # Make sure we used all of the scores.
            if {$residueIndex != [llength $residueScores]} {
               error "getQPerResidue: An unknown error occurred while processing (residueIndex != num residueScores)  name '[::SeqData::getName $sequenceID]': resID: $residueIndex, residuescore Length: [llength $residueScores], residueScores: {$residueScores}, elementScores: {$elementScores}, elementScore length: [llength $elementScores]"
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

#      puts "libbiokit.tcl.getQPerResidue: Getting ready to return $ret"

      return $ret
   } ; # end of proc getQPerResidue 

# ------------------------------------------------------------------------

    proc getContacts {sequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        variable tempDir
        variable filePrefix

        if {[::SeqData::hasStruct $sequenceID] == "Y"} {

            # Write the structure. 
            ::SeqData::VMD::writeStructure $sequenceID "$tempDir/$filePrefix.contacts.pdb" $selection "all" 0 $frame

            # Run the contact analysis.
            set out [run "$tempDir" "q" "contacts" "-c" "$distanceCutoff" "-s" "$minSequenceDistance" "-smax" "$maxSequenceDistance" "$filePrefix.contacts.pdb"]
            return [parseContactOutput $sequenceID [split $out "\n"] [expr $minSequenceDistance <= 1]]
        }

        return {}
    }

# ------------------------------------------------------------------------
    proc getNativeContacts {nativeSequenceID comparisonSequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {maxDistanceDeviation 1.0} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        variable tempDir
        variable filePrefix

        if {[::SeqData::hasStruct $nativeSequenceID] == "Y" && [::SeqData::hasStruct $comparisonSequenceID] == "Y"} {

            # Write the structure. 
            ::SeqData::VMD::writeStructure $nativeSequenceID "$tempDir/$filePrefix.contacts.pdb" $selection "all" 0
            ::SeqData::VMD::writeStructure $comparisonSequenceID "$tempDir/$filePrefix.compare.pdb" $selection "all" 0 $frame

            # Run the contact analysis.
            set out [run "$tempDir" "q" "native_contacts" "-c" "$distanceCutoff" "-s" "$minSequenceDistance" "-smax" "$maxSequenceDistance" "-d" "$maxDistanceDeviation" "$filePrefix.contacts.pdb" "$filePrefix.compare.pdb"]
            return [parseContactOutput $nativeSequenceID [split $out "\n"] [expr $minSequenceDistance <= 1]] 
        }

        return {}
    }

# ------------------------------------------------------------------------
    proc parseContactOutput {sequenceID lines checkBondedDistances} {

        if {$checkBondedDistances} {
            ::SeqData::VMD::loadBondStructure $sequenceID
        }

        set contacts {}
        set startedParsing 0
        foreach line $lines {
            if {$startedParsing} {
                if {$line != ""} {
                    set columns [regexp -inline -all {\S+|\"[^\"]\"} $line]
                    set residue1 [lindex $columns 0]
                    set resid1 [lindex $columns 1]
                    set insertion1 [lindex $columns 2]
                    regexp {^\"(.)\"$} $insertion1 unused insertion1
                    set atom1 [lindex $columns 3]
                    set residue2 [lindex $columns 4]
                    set resid2 [lindex $columns 5]
                    set insertion2 [lindex $columns 6]
                    regexp {^\"(.)\"$} $insertion2 unused insertion2
                    set atom2 [lindex $columns 7]
                    set distance [lindex $columns 8]

                    # If these residues are within 1 of each other, make sure the atoms are not bonded.
                    if {$checkBondedDistances && ($residue1 == $residue2 || $residue1 == [expr $residue2-1])} {
                        if {[::SeqData::VMD::areAtLeastBondsBetween $sequenceID $resid1 $insertion1 $atom1 $resid2 $insertion2 $atom2 4]} {
                            lappend contacts [list $resid1 $insertion1 $atom1 $resid2 $insertion2 $atom2 $distance]
                        }

                    # Otherwise, just add the contact.
                    } else {
                        lappend contacts [list $resid1 $insertion1 $atom1 $resid2 $insertion2 $atom2 $distance]
                    }
                } else {
                    break
                }
            } elseif {$line == "RESIDUE RESID INSERTION ATOM RESIDUE RESID INSERTION ATOM DISTANCE"} {
                set startedParsing 1
            }
        }

        if {$checkBondedDistances} {
            ::SeqData::VMD::unloadBondStructure $sequenceID
        }

        return $contacts
    }

# ------------------------------------------------------------------------
    proc getContactsPerResidue {sequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        # Get the contacts.
        set contacts [getContacts $sequenceID $distanceCutoff $minSequenceDistance $selection $frame $maxSequenceDistance]
        return [sumContactsByResidue $sequenceID $contacts]
    }

# ------------------------------------------------------------------------
    proc getNativeContactsPerResidue {nativeSequenceID comparisonSequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {maxDistanceDeviation 1.0} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        # Get the native contacts.
        set nativeContacts [getNativeContacts $nativeSequenceID $comparisonSequenceID $distanceCutoff $minSequenceDistance $maxDistanceDeviation $selection $frame $maxSequenceDistance]
        return [sumContactsByResidue $comparisonSequenceID $nativeContacts]
    }

# ------------------------------------------------------------------------
    proc sumContactsByResidue {sequenceID contacts} {

        # Initialize the counts.
        array unset counts 
        for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            set counts($element) 0
        }

        # Compute the counts for each element
        foreach contact $contacts {
            set resid1 [lindex $contact 0]
            set insertion1 [lindex $contact 1]
            set resid2 [lindex $contact 3]
            set insertion2 [lindex $contact 4]

            set element1 [::SeqData::VMD::getElementForResidue $sequenceID [list $resid1 $insertion1]]
            set element2 [::SeqData::VMD::getElementForResidue $sequenceID [list $resid2 $insertion2]]

            if {$element1 != -1 && $element2 != -1} {
                incr counts($element1)
                incr counts($element2)
            }
        }

        # Return a list of the counts.
        set contactsPerResidue {}
        for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            lappend contactsPerResidue $counts($element)
        }
        return $contactsPerResidue
    }

# ------------------------------------------------------------------------
    proc getContactOrderPerResidue {sequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        # Get the contacts.
        set contacts [getContacts $sequenceID $distanceCutoff $minSequenceDistance $selection $frame $maxSequenceDistance]
        return [calculateContactOrderByResidue $sequenceID $contacts]
    }

# ------------------------------------------------------------------------
    proc getPartialContactOrderPerResidue {nativeSequenceID comparisonSequenceID {distanceCutoff 4.4} {minSequenceDistance 4} {maxDistanceDeviation 1.0} {selection "not hydrogen"} {frame now} {maxSequenceDistance -1}} {

        # Get the contacts.
        set nativeContacts [getNativeContacts $nativeSequenceID $comparisonSequenceID $distanceCutoff $minSequenceDistance $maxDistanceDeviation $selection $frame $maxSequenceDistance]
        return [calculateContactOrderByResidue $comparisonSequenceID $nativeContacts]
    }

# ------------------------------------------------------------------------
    proc calculateContactOrderByResidue {sequenceID contacts} {

        # Initialize the values.
        array unset values 
        for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            set values($element,value) 0
            set values($element,count) 0
        }

        # Compute the value for each element
        foreach contact $contacts {
            set resid1 [lindex $contact 0]
            set insertion1 [lindex $contact 1]
            set resid2 [lindex $contact 3]
            set insertion2 [lindex $contact 4]

            set element1 [::SeqData::VMD::getElementForResidue $sequenceID [list $resid1 $insertion1]]
            set element2 [::SeqData::VMD::getElementForResidue $sequenceID [list $resid2 $insertion2]]

            if {$element1 != -1 && $element2 != -1} {
                incr values($element1,value) [expr abs($resid2-$resid1)]
                incr values($element1,count)
                incr values($element2,value) [expr abs($resid2-$resid1)]
                incr values($element2,count)
            }
        }

        # Return a list of the counts.
        set contactOrderPerResidue {}
        for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            if {$values($element,count) > 0} {
                lappend contactOrderPerResidue [expr double($values($element,value))/double($values($element,count))]
            } else {
                lappend contactOrderPerResidue 0.0
            }
        }
        return $contactOrderPerResidue
    }

# ------------------------------------------------------------------------
    proc writeSequenceAlignment {sequenceIDs} {

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
                error "Writing Sequence Alignement: The operation could not be performed because the sequences were not aligned."
            }   
        }

        # Save the sequences.
        ::SeqData::Fasta::saveSequences $newSequenceIDs "$tempDir/$filePrefix.fasta" $sequenceIDs {} 0

        # Delete the new sequences.
        ::SeqData::deleteSequences $newSequenceIDs
    }

# ------------------------------------------------------------------------
    proc writeStructureFiles {sequenceIDs} {

        variable tempDir
        variable filePrefix
        variable verbosity

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
                if {$verbosity >= 1} {
                    puts "Libbiokit Error) [::SeqData::getName $newSequenceID] was [::SeqData::getSeqLength $newSequenceID], alignment length was $alignmentLength"
                }
                error "Sequences/Structures not aligned.  Writing Structure Files could not be performed."
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
                    if {$type != "protein" && $type != "rna" && $type != "dna" } {
                        error "The operation could not be performed because [::SeqData::getName $sequenceID] was not a protein or nucleic structure."
                    }
                }

                # See if this sequence is of the right type.
                if {[::SeqData::getType $sequenceID] == $type} {

                    # Write out the PDB files with the backbone atoms for stamp to use.
                    if {$type == "protein"} {
                        ::SeqData::VMD::writeStructure $sequenceID "$tempDir/$filePrefix.$i.pdb" "name CA"
                    } elseif {$type == "dna" || $type == "rna"} {
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

# ------------------------------------------------------------------------
    proc run {wd program args} {

        global env
        variable verbosity

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

        if {$verbosity >= 2} {
            puts "Libbiokit Info) Running $program with command $cmd"
        }

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

