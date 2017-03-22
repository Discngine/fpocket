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
#       $RCSfile: metric_import.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.4 $       $Date: 2005/09/27 17:44:22 $
#
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Import {

    # Export the package namespace.
    namespace export calculate
    
    variable filename
    
    proc setFilename {newFilename} {
        variable filename
        set filename $newFilename
    }

    proc calculate {sequenceIDs} {
        
        variable filename
        
        if {$filename != ""} {
            
            # Initialize the color map.
            array set metricMap {}
    
            # Set the initial values to be 0.        
            foreach sequenceID $sequenceIDs {
                set sequence [SeqData::getSeq $sequenceID]
                set elementIndex 0
                for {set elementIndex 0} {$elementIndex < [llength $sequence]} {incr elementIndex} {
                    set metricMap($sequenceID,$elementIndex) 0.0
                }
            }
            
            # Open the data file.
            set fp [open $filename]
            
            # Read the data one line at a time.
            set firstLine 1
            set skipGaps 0
            set residues {}
            set matchedSequenceIDs {}
            while {![eof $fp] && [gets $fp line] >= 0} {                

                # Parse the columns.
                set columns [regexp -inline -all -- {\S+} $line]
                
                # If this is the first line and we understand it, parse it.
                if {$firstLine == 1 && [lindex $columns 0] == "SEQUENCE"} {
                    
                    # Mark that we should skip gaps while importing.
                    set skipGaps 1
                    continue
                    
                } elseif {$firstLine == 1 && ([lindex $columns 0] == "RESIDUES" || [lindex $columns 0] == "RESIDUE")} {
                    
                    # Extract the residue numbers.
                    set residues [lrange $columns 1 end]
                    continue
                }
                set firstLine 0
                
                # Use the first column as the sequence name.
                set name [lindex $columns 0]
                    
                # Find its matching sequence id.
                foreach sequenceID $sequenceIDs {
                    
                    # If the names match and we have not already matched this sequence, use it.
                    if {[string toupper $name] == [string toupper [SeqData::getName $sequenceID]] && [lsearch $matchedSequenceIDs [string toupper $name]] == -1} {
                        
                        # Go through each column and sets its value.
                        set element -1
                        set sequence [SeqData::getSeq $sequenceID]
                        for {set i 1} {$i < [llength $columns]} {incr i} {
                            
                            # Get the element that corresponds to this residue.
                            if {$residues != {}} {
                                set residue [expr [lindex $residues [expr $i-1]]-1]
                                set element [::SeqData::getElementForResidue $sequenceID $residue]
                            } elseif {$skipGaps} {
                                incr element
                                while {[lindex $sequence $element] == "-"} {
                                    incr element
                                }
                            } else {
                                set element [expr $i-1]
                            }
                            
                            # Set the metric map.
                            set metricMap($sequenceID,$element) [lindex $columns $i]
                        }
                        
                        # Add this sequence to the list of the ones we have used.
                        lappend matchedSequenceIDs $sequenceID
                        break
                    }
                }
            }
            close $fp
    
            # Return the color map.
            return [array get metricMap]
        }

        return {}
    }
}