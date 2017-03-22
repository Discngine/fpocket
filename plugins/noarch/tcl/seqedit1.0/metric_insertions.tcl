############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Insertions {

    # Export the package namespace.
    namespace export calculate

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculate {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Make sure we have at least one sequence.
        if {[llength $sequenceIDs] == 0} {
            return {}
        }
        
        # Get the number of elements.
        set numberElements [::SeqData::getSeqLength [lindex $sequenceIDs 0]]
        
        # Find all of the sequences that have the same length.
        set matchingSequenceIDs {}
        foreach sequenceID $sequenceIDs {
        
            if {[::SeqData::getSeqLength $sequenceID] == $numberElements} {
                lappend matchingSequenceIDs $sequenceID
            }
        }
        set numberSequences [llength $matchingSequenceIDs]
        
        # Go through each element and calculate its insertion percentage.
        for {set i 0} {$i < $numberElements} {incr i} {
            
            # Get the total number of non-gaps elements at this position.
            set count 0
            foreach sequenceID $matchingSequenceIDs {
            
                # Get the element.
                set element [::SeqData::getElements $sequenceID $i]
                
                # If this is not a gap, increase the count.
                if {$element != "-"} {
                    incr count
                }
            }
            
            # Set the metric for each sequence.
            foreach sequenceID $matchingSequenceIDs {
                set metricMap($sequenceID,$i) [expr (double($count))/(double($numberSequences))]
            }
        }

        # Return the color map.
        return [array get metricMap]
    }
}