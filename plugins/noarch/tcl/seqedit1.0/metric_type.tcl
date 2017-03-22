############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

############################################################################
# RCS INFORMATION:
#
#       $RCSfile: metric_type.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.2 $       $Date: 2006/12/28 21:37:46 $
#
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Type {

    # Export the package namespace.
    namespace export calculate

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculate {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Go through each sequence in the list
        foreach sequenceID $sequenceIDs {
            
            # Get the sequence
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set elementIndex 0
            foreach element $sequence {
                
                # Set the color map entry for this element.
                if {$element == "R" || $element == "K" || $element == "H"} {
                    set metricMap($sequenceID,$elementIndex) 1.0
                } elseif {$element == "D" || $element == "E"} {
                    set metricMap($sequenceID,$elementIndex) 0.0
                } else {
                    set metricMap($sequenceID,$elementIndex) 0.5
                }
                
                # Increment the element counter.
                incr elementIndex
            }
        }
        
        # Return the metric map.
        return [array get metricMap]
    }
}