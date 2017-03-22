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
namespace eval ::SeqEdit::Metric::PercentIdentity {

    # Export the package namespace.
    namespace export calculate

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculate {sequenceIDs} {
        
        # Initialize the color map.
        array set counts {}
        array set metricMap {}
        
        # Go through each sequence in the list.
        foreach sequenceID $sequenceIDs {
        
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set elementIndex 0
            foreach element $sequence {
                
                # Set the count entry for this element.
                if {$element != "-"} {
                
                    if {[info exists counts($elementIndex,$element)] == 0} {
                        set counts($elementIndex,$element) 1
                    } else {
                        incr counts($elementIndex,$element)
                    }
                }
                
                # Increment the element counter.
                incr elementIndex
            }
        }
            
        # Get the number of sequences.
        set numSequences [llength $sequenceIDs]
        
        # Go through each sequence in the list.
        foreach sequenceID $sequenceIDs {
        
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set elementIndex 0
            foreach element $sequence {
                
                # Set the color for this entry.
                if {$element != "-"} {
                    if {$numSequences > 1} {
                        set percentIdentity [expr ($counts($elementIndex,$element)-1)/(double($numSequences)-1.0)]
                        set metricMap($sequenceID,$elementIndex) $percentIdentity
                    } else {
                        set metricMap($sequenceID,$elementIndex) 1.0
                    }
                } else {
                    set metricMap($sequenceID,$elementIndex) 0.0
                }
                
                # Increment the element counter.
                incr elementIndex
            }
        }
        # Return the color map.
        return [array get metricMap]
    }
}