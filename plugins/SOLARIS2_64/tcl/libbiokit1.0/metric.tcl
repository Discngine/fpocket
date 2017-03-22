############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################


# This package implements a color map for the sequence editor that colors
# sequence elements based upon the q value of the element.

package provide libbiokit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::Libbiokit::Metric {

    # Export the package namespace.
    namespace export calculateRMSD

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculateRMSD {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Get the RMSD scores.
        set scores [::Libbiokit::getRMSDPerResidue $sequenceIDs]
                
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $i]
            
            # Go through each element in the sequence.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            
                # Set the score.
                set score [lindex [lindex $scores $i] $element]
                set metricMap($sequenceID,$element) $score
            }
        }
        
        # Return the color map.
        return [array get metricMap]
    }

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculateRMSDNormalized {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Get the RMSD scores.
        set scores [::Libbiokit::getRMSDPerResidue $sequenceIDs]
        
        # Figure out the maximum RMSD.
        set maxRMSD 0.0
        foreach scoreList $scores {
            foreach score $scoreList {
                if {$score > $maxRMSD} {
                    set maxRMSD $score
                }
            }
        }
                
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $i]
            
            # Go through each element in the sequence.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            
                # Set the score.
                set score [lindex [lindex $scores $i] $element]
                if {$score >= 0.0} {
                    set metricMap($sequenceID,$element) [expr 1.0-($score/$maxRMSD)]
                } else {
                    set metricMap($sequenceID,$element) 0.0
                }
            }
        }
        
        # Return the color map.
        return [array get metricMap]
    }
    
    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculateQres {sequenceIDs} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Get the q scores.
        set scores [::Libbiokit::getQPerResidue $sequenceIDs]
                
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $i]
            
            # Go through each element in the sequence.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            
                # Set the score.
                set score [lindex [lindex $scores $i] $element]
                set metricMap($sequenceID,$element) $score
            }
        }
        
        # Return the color map.
        return [array get metricMap]
    }
}
