############################################################################
#cr
#cr            (C) Copyright 1995-2010 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: mafft.tcl,v 1.5 2015/05/20 22:19:06 kvandivo Exp $
#

# Package for using MAFFT on sequences obtained from the seqdata package.

package provide mafft 1.1
package require seqdata 1.1
package require phylotree 1.1
package require exectool

namespace eval ::Mafft:: {
    
    # Export the package namespace.
    namespace export Mafft

    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "mafft"
    
    # The directories where the MAFFT executables are located.
    variable mafftProgramDir ""

    # This method sets the dir options used by MAFFT
    proc setMafftProgramDirs {newMafftProgramDir } {

       variable mafftProgramDir

       set mafftProgramDir $newMafftProgramDir
    }

    # The current CPU architecture.
    variable architecture ""

    # This method sets the arch options used by MAFFT
    proc setArchitecture {newArchitecture} {

       variable architecture

       set architecture $newArchitecture
    }
    
    # Whether or not the reference has yet been printed.
    variable printedReference 0


    # The level of verbosity, 0=silent, 1=errors, 2=errors+info
    variable verbosity 1
    
# --------------------------------------------------------------------
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
    
# --------------------------------------------------------------------
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
    
        # Run MAFFT.
        set output [run mafft $alignedFilename --auto $originalFilename ]
    
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
    
# --------------------------------------------------------------------
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
        set profileIndices {}
        set sequenceIndices {}
        array set sequenceMap {}
        foreach sequenceID $profile {
            lappend profileIndices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        foreach sequenceID $sequences {
            lappend sequenceIndices $sequenceID
            set sequenceMap($sequenceID) [::SeqData::getName $sequenceID]
        }
        
        # Save the sequences as a fasta file.
        ::SeqData::Fasta::saveSequences $profile $profileFilename \
                                            $profileIndices {} 0 1
        ::SeqData::Fasta::saveSequences $sequences $sequencesFilename \
                                            $sequenceIndices {} 0 0 1
    
        # Run MAFFT.
#        set output [run mafft-linsi $alignedFilename --seed $profileFilename $sequencesFilename ]
        set output [run mafft $alignedFilename --localpair --maxiterate 1000  --seed $profileFilename $sequencesFilename ]
    
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
    
# --------------------------------------------------------------------
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
    
        # Run MAFFT.
#        set output [run mafft-profile $alignedFilename $profile1Filename $profile2Filename ]
        set output [run mafft $alignedFilename --maxiterate 1000 --addprofile $profile1Filename $profile2Filename ]
    
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
    
# --------------------------------------------------------------------
    # Creates a phylogenetic tree of the given sequences.
    # arg:      sequences - The list of sequence ids from whcih the tree should be created.
    # return:   A string containing the tree in Newick format.
    proc calculatePhylogeneticTree {sequenceIDs {sequenceNames {}}} {
        
        variable tempDir
        variable filePrefix
    
        # Figure out the input and output file names.
        set sequencesFilename "$tempDir/$filePrefix.sequences.fasta"
        set outFilename "$tempDir/$filePrefix.unused"
        set treeFilename "$sequencesFilename.tree"
        
        # Save the sequences as a fasta file with the index in the list as the sequence name.
        writeSequenceAlignment $sequenceIDs $sequencesFilename $sequenceNames
    
        # Run MAFFT.
        set output [run mafft $outFilename --treeout $sequencesFilename ]
    
        # Load the tree.
        return [::PhyloTree::Newick::loadTreeFile $treeFilename "MAFFT Sequence Tree"]
    }
    
# --------------------------------------------------------------------
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
        
# --------------------------------------------------------------------
    # Runs the MAFFT executable. This method should only be called from inside
    # the MAFFT package.
    # arg:    args - The list of arguments that should be passed to the program.
    proc run {program outputFile args} {

        global env
        variable verbosity
        variable mafftProgramDir
        variable architecture

        # If this is windows, append .exe to the program name.
        if {$architecture == "WIN32"} {
            append program ".bat"
        }

        # If we have a MAFFT program dir.
        set cmd ""

        if {$::env(MAFFTRUNDIR) != ""} {

           if {[file exists [file join $::env(MAFFTRUNDIR) $program]]} {
                   set cmd "::ExecTool::exec \"[file join $::env(MAFFTRUNDIR) $program]\""
           }
        }

        if {$cmd == ""} {
           if {$mafftProgramDir != ""} {

               # Try to find the binary.
               if {[file exists [file join $mafftProgramDir bin $program]]} {
                   set cmd "::ExecTool::exec \"[file join $mafftProgramDir bin $program]\""
               } elseif {[file exists [file join $mafftProgramDir $program]]} {
                   set cmd "::ExecTool::exec \"[file join $mafftProgramDir $program]\""
               }
           }
        }

        # If we don't have a binary, just rely on the path.
        if {$cmd == ""} {
            set cmd "::ExecTool::exec $program"
        }

        # Append the arguments.
        foreach arg $args {
            append cmd " \"$arg\""
        }

        append cmd " > $outputFile"

        # Print out the reference message.
        printReference        

        # Run the command and then return to the working directory.
        if {$verbosity >= 2} {
            puts "MAFFT Info) Running $program with command $cmd"
        }

# actually do the run
        set rc [catch {eval $cmd} out]
        if {$verbosity >= 2} {
            puts "MAFFT Info) $program returned with code $rc."
        }

        return $out
    }

    proc printReference {} {

        variable verbosity
        variable printedReference

        # Print out the reference message.
        if {!$printedReference} {
            set printedReference 1
            if {$verbosity >= 2} {
#puts "MAFFT Reference) In any publication of scientific results based in part or"
#puts "MAFFT Reference) completely on the use of the program MAFFT, please reference:"
            }
        }
    }

}


