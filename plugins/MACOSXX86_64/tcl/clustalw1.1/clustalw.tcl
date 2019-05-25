############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: clustalw.tcl,v 1.7 2013/04/15 15:40:43 johns Exp $
#

# Package for using clustalw on sequences obtained from the seqdata package.

package provide clustalw 1.1
package require seqdata 1.1
package require phylotree 1.1

namespace eval ::ClustalW:: {
    
    # Export the package namespace.
    namespace export ClustalW

    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "clustalw"
    
    # The current CPU architecture.
    variable architecture ""
    
    # The level of verbosity, 0=silent, 1=errors, 2=errors+info
    variable verbosity 1
   
# -------------------------------------------------------------------
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
# -------------------------------------------------------------------
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setArchitecture {newArchitecture} {

        variable architecture
        
        # Set the temp directory and file prefix.
        set architecture $newArchitecture
    }    
    
# -------------------------------------------------------------------
    # Aligns the passed in sequences.
    # arg:      sequences - The list of sequence ids that should be aligned.
    # return:   The list of aligned sequences ids.
    proc alignSequences {sequenceIDs} {
        
        variable tempDir
        variable filePrefix
    
        # Figure out the input and output file names.
        set originalFilename "$tempDir/$filePrefix.original.fasta"
        set alignedFilename "$tempDir/$filePrefix.aligned.fasta"
        
        # Get the sequence ids.
        set sequenceIndices {}
        array set sequenceMap {}
        foreach sequenceID $sequenceIDs {
            lappend sequenceIndices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        
        # Save the sequences as a fasta file.
        SeqData::Fasta::saveSequences $sequenceIDs $originalFilename $sequenceIndices {} 0 0
    
        # Run clustalw.
        set output [run -align -infile=$originalFilename -output=fasta -outfile=$alignedFilename -outorder=input]
    
        # Load the new sequences.
        set newSequenceIDs [SeqData::Fasta::loadSequences $alignedFilename [array get sequenceMap]]
        
        # Copy the attributes
        set originalSequenceIDs $sequenceIDs
        for {set i 0} {$i < [llength $originalSequenceIDs] && $i < [llength $newSequenceIDs]} {incr i} {
            ::SeqData::copyAttributes [lindex $originalSequenceIDs $i] [lindex $newSequenceIDs $i]
        }
        
        # Return the sequences.
        return $newSequenceIDs
    }
    
# -------------------------------------------------------------------
    # Aligns the passed in sequences.
    # arg:      sequences - The list of sequence ids that should be aligned.
    # return:   The list of aligned sequences ids.
    proc alignSequencesToProfile { profile sequences } {
        
        variable tempDir
        variable filePrefix
    
        # Figure out the input and output file names.
        set profileFilename "$tempDir/$filePrefix.profile.fasta"
        set sequencesFilename "$tempDir/$filePrefix.sequences.fasta"
        set alignedFilename "$tempDir/$filePrefix.aligned.fasta"
        
        # Get the sequence ids.
        array set sequenceMap {}

        set profileIndices {}
        foreach sequenceID $profile {
            lappend profileIndices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }

        set sequenceIndices {}
        foreach sequenceID $sequences {
            lappend sequenceIndices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        
        # Save the sequences as a fasta file.
        ::SeqData::Fasta::saveSequences $profile $profileFilename \
                                              $profileIndices {} 0 1
        ::SeqData::Fasta::saveSequences $sequences $sequencesFilename \
                                              $sequenceIndices {} 0 0 1
    
        # Run clustalw.
        set output [run -align -profile1=$profileFilename -profile2=$sequencesFilename -sequences -output=fasta -outfile=$alignedFilename -outorder=input]
    
        # Load the new sequences.
        set newSequenceIDs [SeqData::Fasta::loadSequences $alignedFilename [array get sequenceMap]]
        
        # Copy the attributes
        set originalSequenceIDs [concat $profile $sequences]
        for {set i 0} {$i < [llength $originalSequenceIDs] && $i < [llength $newSequenceIDs]} {incr i} {
            ::SeqData::copyAttributes [lindex $originalSequenceIDs $i] [lindex $newSequenceIDs $i]
        }
        
        # Return the sequences.
        return $newSequenceIDs
    }
    
# -------------------------------------------------------------------
    proc alignProfiles { profile1 profile2 } {
        
        variable tempDir
        variable filePrefix
    
        # Figure out the input and output file names.
        set profile1Filename "$tempDir/$filePrefix.profile1.fasta"
        set profile2Filename "$tempDir/$filePrefix.profile2.fasta"
        set alignedFilename "$tempDir/$filePrefix.aligned.fasta"
        
        # Get the sequence ids.
        set profile1Indices {}
        set profile2Indices {}
        array set sequenceMap {}
        foreach sequenceID $profile1 {
            lappend profile1Indices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        foreach sequenceID $profile2 {
            lappend profile2Indices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        
        # Save the sequences as a fasta file.
        ::SeqData::Fasta::saveSequences $profile1 $profile1Filename $profile1Indices {} 0 1
        ::SeqData::Fasta::saveSequences $profile2 $profile2Filename $profile2Indices {} 0 1
    
        # Run clustalw.
        set output [run -align -profile1=$profile1Filename -profile2=$profile2Filename -profile -output=fasta -outfile=$alignedFilename -outorder=input]
    
        # Load the new sequences.
        set newSequenceIDs [SeqData::Fasta::loadSequences $alignedFilename [array get sequenceMap]]
        
        # Copy the attributes
        set originalSequenceIDs [concat $profile1 $profile2]
        for {set i 0} {$i < [llength $originalSequenceIDs] && $i < [llength $newSequenceIDs]} {incr i} {
            ::SeqData::copyAttributes [lindex $originalSequenceIDs $i] [lindex $newSequenceIDs $i]
        }
        
        # Return the sequences.
        return $newSequenceIDs
    }
    
# -------------------------------------------------------------------
    # Creates a phylogenetic tree of the given sequences.
    # arg:      sequences - The list of sequence ids from whcih the tree should be created.
    # return:   A string containing the tree in Newick format.
    proc calculatePhylogeneticTree {sequenceIDs {sequenceNames {}}} {
        
        variable tempDir
        variable filePrefix
    
        # Figure out the input and output file names.
        set sequencesFilename "$tempDir/$filePrefix.sequences.fasta"
        set treeFilename "$tempDir/$filePrefix.sequences.ph"
        
        # Save the sequences as a fasta file with the index in the list as the sequence name.
        writeSequenceAlignment $sequenceIDs $sequencesFilename $sequenceNames
    
        # Run clustalw.
        set output [run -tree -infile=$sequencesFilename -outputtree=phylip]
    
        # Load the tree.
        return [::PhyloTree::Newick::loadTreeFile $treeFilename "CLUSTALW Sequence Tree"]
    }
    
# -------------------------------------------------------------------
    proc writeSequenceAlignment {sequenceIDs sequencesFilename indices} {
        
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

        ::SeqData::Fasta::saveSequences $newSequenceIDs $sequencesFilename $indices {} 0
        
        ::SeqData::deleteSequences $newSequenceIDs
    }
        
# -------------------------------------------------------------------
    # Runs the clustal executable. This method should only be called from inside the ClustalW package.
    # arg:      args - The list of arguments that should be passed to the program.
    proc run { args } {
        
        global env
        variable verbosity
        variable architecture
        
        # Get the location of the executable
        set clustalwdir $env(CLUSTALWPLUGINDIR)
    
        # Build the name of the executable.    
        switch $architecture {
            WIN32 {
                set cmd "exec {$clustalwdir/clustalw.exe}"
            }
            default {
                set cmd "exec {$clustalwdir/clustalw}"
            }
        }
    
        # Append the arguments.
        foreach arg $args {
            append cmd " $arg"
        }
    
        if {$verbosity >= 2} {
            puts "ClustalW Info) Running CLUSTALW with command $cmd"
        }
        
        set rc [catch {eval $cmd} out]
    
        # If there was an error during execution, throw it.
        if {$rc != 0} {
            error $out
        }
        
        return $out
    }
# -------------------------------------------------------------------
}

