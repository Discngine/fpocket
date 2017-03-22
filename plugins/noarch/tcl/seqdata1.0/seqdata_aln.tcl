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
namespace eval ::SeqData::Aln {

    # Export the package namespace.
    namespace export loadSequences saveSequences
    
    # The width of the name column.
    variable nameWidth 20
    
    # The name of the sequence column.
    variable sequenceWidth 60

    # Loads a series of sequences from an ALN file into the sequence store.
    # arg:      filename - The name of the file to load.
    # return:   The list of sequences ids that were loaded from the file. 
    #           These ids are for use with the seqdata package.
    proc loadSequences { filename } {
        variable nameWidth
        variable sequenceWidth

        # Variables for storing the sequence info during the reading process.
        set sequenceIDList {}
        array set sequenceData {}

        # Open file
        set fp [open $filename r]

        # read & parse all lines in file
        while {1} {
          set line [gets $fp]

          if {[string length $line] <= 1} {
            # A blank line
						# see if we're at EOF
          	if {[eof $fp]} {
            	# we're done, save data and stop looping
            	foreach name [array names sequenceData] {
              	set seqID [::SeqData::addSeq [split $sequenceData($name) {}] $name]
              	lappend sequenceIDList $seqID
            	}
            	break
          	}
          } else {
            # This is a sequence line, need to parse stuff out of it
						# must collapse all redundant space chars to a single space,
						# to avoid split stupidity
            set seqParts [split [regsub -all {\s+} $line { }]]
            set name [lindex $seqParts 0]
            set seq [lindex $seqParts 1]
            if {[array names sequenceData -exact $name] == ""} {
              # We don't have this sequence yet, need to add it
              array set sequenceData [list $name $seq]
            } else {
              append sequenceData($name) $seq
            }
          }
        }

        # close file and return
        close $fp

        return $sequenceIDList
    }
    
    # Loads a series of sequences from a FASTA file into the sequence store.
    # arg:  sequences - The list of sequences ids that should be saved to the 
    #                       file. These ids should have come from the seqdata 
    #                       package.
    #       filename - The name of the file to load.
    #       names - An optional list of strings to use to override the sequence names.
    proc saveSequences {sequenceIDs filename {names {}}} {
        
        # Import global variables.
        variable nameWidth
        variable sequenceWidth
    
        # Figure out the maximum sequence length.
        set maxLength 0
        foreach sequenceID $sequenceIDs {
            if {[SeqData::getSeqLength $sequenceID] > $maxLength} {
                set maxLength [SeqData::getSeqLength $sequenceID]
            }
        }
                    
        # Open the file.
        set fp [open $filename w]
        fconfigure $fp -translation lf
        
        # Go through all of the sequence data one column at a time.
        for {set i 0} {$i < $maxLength} {incr i $sequenceWidth} {
            
            # Go through each sequence.
            for {set j 0} {$j < [llength $sequenceIDs]} {incr j} {
                
                # Get the sequence.
                set sequenceID [lindex $sequenceIDs $j]
                
                # Figure out the name to use.
                set name [SeqData::getName $sequenceID]
                if {$j < [llength $names]} {
                    set name [lindex $names $j]
                }
                if {[string length $name] >= $nameWidth} {
                    set name [string range $name 0 [expr $nameWidth-2]]
                }
                
                # Write the name.
                puts -nonewline $fp $name
                
                # Fill out the column with spaces.
                for {set k 0} {$k < [expr $nameWidth-[string length $name]]} {incr k} {
                    puts -nonewline $fp " "
                }
                
                # Write out the sequence data.
                set sequenceData [SeqData::getSeq $sequenceID]
                for {set k $i} {$k < [expr $i+$sequenceWidth] && $k < $maxLength} {incr k} {
                    if {$k < [llength $sequenceData]} {
                        puts -nonewline $fp [lindex $sequenceData $k]
                    } else {
                        puts -nonewline $fp "-"
                    }
                }
                
                # Write out the newline.
                puts $fp ""
            }
            
            # Write a blank line between sections.
            puts $fp ""
        }
        
        # Close the file.
        close $fp
    }
}