############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for reading and writing sequence data from PIR formatted files.

package provide seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqData::Pir {

    # Export the package namespace.
    namespace export loadSequences saveSequences

    # Loads a series of sequences from a FASTA file into the sequence store.
    # arg:      filename - The name of the file to load.
    # return:   The list of sequences ids that were loaded from the file. 
    #           These ids are for use with the seqdata package.
    proc loadSequences {filename} {
                    
    }
    
    # Save a series of sequences into a PIR file into the sequence store.
    # arg:  sequences - The list of sequences ids that should be saved to the 
    #                       file. These ids should have come from the seqdata 
    #                       package.
    #       filename - The name of the file to save the sequences as.
    #       names - An optional list of strings to use to override the sequence names.
    proc saveSequences {sequences filename {names {}}} {
        
        # Open the file.
        set fp [open $filename w]
        
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequences]} {incr i} {
            
            # Get the sequence.
            set sequenceID [lindex $sequences $i]

            # Get the sequence name.            
            set sequenceName [::SeqData::getName $sequenceID]
            if {$i < [llength $names]} {
                set sequenceName [lindex $names $i]
            }
            
            # Get the sequence data.
            set sequenceData [::SeqData::getSeq $sequenceID]
    
            # Write the header line.
            puts $fp ">P1; $sequenceName"
            if {[::SeqData::hasStruct $sequenceID]} {
                set chain [lindex [::SeqData::VMD::getMolIDForSequence $sequenceID] 1]
                set firstResidue ""
                set lastResidue ""
                for {set j 0} {$j < [llength $sequenceData]} {incr j} {
                    if {[lindex $sequenceData $j] != "-"} {
                        set firstResidue [::SeqData::getResidueForElement $sequenceID $j]
                        break
                    }
                }
                for {set j [expr [llength $sequenceData]-1]} {$j >= 0} {incr j -1} {
                    if {[lindex $sequenceData $j] != "-"} {
                        set lastResidue [::SeqData::getResidueForElement $sequenceID $j]
                        break
                    }
                }
                puts $fp "structureX:$sequenceName\:$firstResidue\:$chain\:$lastResidue\:$chain\:::-1.00:-1.00"
            } else {
                puts $fp "sequence:$sequenceName\:::::::0.00:0.00"
            }
            
            # Write the sequence data, limiting the line length to 60.
            set elementsWritten 0
            foreach element $sequenceData {
                if {$elementsWritten >= 60} {
                    puts $fp ""
                    set elementsWritten 0
                }
                puts -nonewline $fp $element
                incr elementsWritten
            }
            
            #Write out two trailing newlines.
            puts $fp "*"
            puts $fp ""
        }
        
        # Close the file.
        close $fp
    }
}
