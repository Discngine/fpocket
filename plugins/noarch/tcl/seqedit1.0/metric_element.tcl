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
#       $RCSfile: metric_element.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.1 $       $Date: 2005/12/02 20:23:12 $
#
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Element {

    # Export the package namespace.
    namespace export calculate

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculate {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Go through each sequence in the list.
        foreach sequenceID $sequenceIDs {
        
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set length [llength $sequence]
            set elementIndex 0
            foreach element $sequence {
                
                # Set the metric for this entry.
                if {$element != "-"} {
                    set metricMap($sequenceID,$elementIndex) [expr 1.0-(double($elementIndex)/double($length))]
                } else {
                    set metricMap($sequenceID,$elementIndex) 0.0
                }
                
                # Increment the element counter.
                incr elementIndex
            }
        }
        # Return the metric map.
        return [array get metricMap]
    }
}