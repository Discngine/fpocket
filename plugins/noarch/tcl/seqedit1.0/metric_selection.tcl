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
#       $RCSfile: metric_selection.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.1 $       $Date: 2005/07/01 15:03:17 $
#
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Selection {

    # Export the package namespace.
    namespace export calculate

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculate {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Get the selected cells.
        set selected [::SeqEditWidget::getSelectedCells]
        
        # Go through each sequences that has something selected.
        for {set i 0} {$i < [llength $selected]} {incr i 2} {
    
            # Get the sequence id.
            set selectedSequenceID [lindex $selected $i]
            
            # See if this is in our list of sequences.
            if {[lsearch $sequenceIDs $selectedSequenceID] != -1} {
                
                # Mark all of the elements as selected.
                foreach element [lindex $selected [expr $i+1]] {
                    set metricMap($selectedSequenceID,$element) 1.0
                }                
            }
        }
        
        # Return the metric map.
        return [array get metricMap]
    }
}