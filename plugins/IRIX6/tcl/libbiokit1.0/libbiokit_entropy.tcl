############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide libbiokit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::Libbiokit::Entropy {

    # Export the package namespace.
    namespace export calculate

    proc calculateBlockEntropies {sequenceIDs {blockSize 1} {lnBase 0.69314718056}} {
        
        # Get all of the sequences.
        set alignment {}
        set Naln -1
        foreach sequenceID $sequenceIDs {
            lappend alignment [::SeqData::getSeq $sequenceID]
            if {$Naln == -1 || [::SeqData::getSeqLength $sequenceID] < $Naln} {
                set Naln [::SeqData::getSeqLength $sequenceID]
            }
        }
        
        # Get the number of sequences.
        set Nseq [llength $alignment]
        
        # Go through each block in the alignment.
        set entropies {}
        for {set i 0} {$i < $Naln} {incr i $blockSize} {
        
            # Get a list of the values in this block.
            set elements {}
            for {set j 0} {$j < $Nseq} {incr j} {
                
                # Get the element, mapping it if necessary.
                set element [lrange [lindex $alignment $j] $i [expr $i+$blockSize-1]]
                if {[info exists map($element)]} {
                    set element $map($element)
                }
                lappend elements $element
            }
            
            # Calculate the entropy.
            lappend entropies [calculateEntropy $elements $lnBase]
        }
        
        return $entropies
    }
    
    proc calculateMutualInformationMatrix {sequenceIDs {blockSize 1} {lnBase 0.69314718056}} {
        
        # Convert the mapping into a map.
        array set map $mapping
        
        # Get all of the sequences.
        set alignment {}
        set Naln -1
        foreach sequenceID $sequenceIDs {
            lappend alignment [::SeqData::getSeq $sequenceID]
            if {$Naln == -1 || [::SeqData::getSeqLength $sequenceID] < $Naln} {
                set Naln [::SeqData::getSeqLength $sequenceID]
            }
        }
        
        # Get the number of sequences.
        set Nseq [llength $alignment]
        
        # Go through each column in the alignment.
        set MIRows {}
        set lnBase [expr log([llength $alphabet])]
        for {set i 0} {$i < $Naln} {incr i} {
            
            # Get a list of values in column i.
            set iElements {}
            for {set k 0} {$k < $Nseq} {incr k} {
                set element [lindex [lindex $alignment $k] $i]
                if {[info exists map($element)]} {
                    set element $map($element)
                }
                lappend iElements $element
            }
            
            # Duplicate any previously calculated matrix elements.
            set MIs {}
            for {set j 0} {$j < $i} {incr j} {
                lappend MIs [lindex [lindex $MIRows $j] $i]
            }
            
            # Set the diagonal to 0.
            lappend MIs 0
            
            # Go through each pair and calculate the mutual information.
            for {set j [expr $i+1]} {$j < $Naln} {incr j} {
        
                # Get a list of the values in column j.
                set jElements {}
                for {set k 0} {$k < $Nseq} {incr k} {
                    
                    # Get the element, mapping it if necessary.
                    set element [lindex [lindex $alignment $k] $j]
                    if {[info exists map($element)]} {
                        set element $map($element)
                    }
                    lappend jElements $element
                }
                
                # Calculate the entropy.
                lappend MIs [calculateMutualInformation $iElements $jElements $alphabet $alphabet $maxMissingFraction $lnBase $normalize]
            }
            
            # Add the MIS to the matrix.
            lappend MIRows $MIs
        }
        
        return $MIRows
    }
    
    proc calculateJointEntropyMatrix {sequenceIDs {blockSize 1} {lnBase 0.69314718056}} {
        
        # Convert the mapping into a map.
        array set map $mapping
        
        # Get the number of sequences and the number of columns.
        set Nseq [llength $sequenceIDs]
        set Naln [::SeqData::getSeqLength [lindex $sequenceIDs 0]]
        
        # Get all of the columns.
        set columns {}
        for {set i 0} {$i < $Naln} {incr i} {
            set column {}
            for {set j 0} {$j < $Nseq} {incr j} {
                set element [::SeqData::getElement [lindex $sequenceIDs $j] $i]
                if {[info exists map($element)]} {
                    set element $map($element)
                }
                lappend column $element
            }
            lappend columns $column
        }
        
        # Go through each column in the alignment.
        set rows {}
        set lnBase [expr log([llength $alphabet])]
        for {set i 0} {$i < $Naln} {incr i} {
            
            # Duplicate any previously calculated matrix elements.
            set values {}
            for {set j 0} {$j < $i} {incr j} {
                lappend values [lindex [lindex $rows $j] $i]
            }
            
            # Set the diagonal to 0.
            lappend values 0
            
            # Go through each pair and calculate the mutual information.
            for {set j [expr $i+1]} {$j < $Naln} {incr j} {
        
                # Calculate the joint entropy.
                lappend values [calculateJointEntropy [lindex $columns $i] [lindex $columns $j] $alphabet $alphabet $maxMissingFraction $lnBase]
            }
            
            # Add the values to the matrix.
            lappend rows $values
        }
        
        return $rows
    }
    
    proc calculateEntropy {values {lnBase 0.69314718056}} {
        
        # Zero out the counters.
        set usedValues {}
        array set counts {}
        
        # Go through each value and calculate the number of occurrences of each value.
        foreach value $values {
            if {[lsearch -exact $usedValues $value] == -1} {
                lappend usedValues $value
                set counts($value) 1
            } else {
                incr counts($value)
            }
        }
        
        # Calculate the entropy.
        set H 0
        set Nval [llength $values]
        foreach usedValue $usedValues {
            set pr [expr double($counts($usedValue))/double($Nval)]
            set H [expr $H - $pr*log($pr)/$lnBase]
        }
        return $H
    }
    
    proc calculateJointEntropy {values1 values2 {lnBase 0.69314718056}} {
        
        # Make sure the values lists are of the same length.
        set Nval [llength $values1]
        if {[llength $values2] != $Nval} {
            return ""
        }
        
        # Zero out the counters.
        set usedValues {}
        array set counts {}
        
        # Go through the values and count the number of occurrences of each pair.
        for {set i 0} {$i < $Nval} {incr i} {
            set value "[lindex $values1 $i][lindex $values2 $i]"
            if {[lsearch -exact $usedValues $value] == -1} {
                lappend usedValues $value
                set counts($value) 1
            } else {
                incr counts($value)
            }
        }
        
        # Calculate the entropy.
        set H 0
        foreach usedValue $usedValues {
            set pr [expr double($counts($usedValue))/double($Nval)]
            set H [expr $H - $pr*log($pr)/$lnBase]
        }
        return $H
    }
    
    
    proc calculateMutualInformation {values1 values2 {lnBase 0.69314718056} {normalize 0}} {
        
        # Calculate the individual entropies.
        set entropy1 [calculateEntropy $values1 $lnBase]
        set entropy2 [calculateEntropy $values2 $lnBase]
        
        # Calculate the joint entropy.
        set jointEntropy [calculateJointEntropy $values1 $values2 $lnBase]
        
        # Return the mutual information.
        if {$jointEntropy != ""} {
            if {$normalize} {
                if {$jointEntropy == 0.0} {
                    return 0.0
                } else {
                    return [expr ($entropy1+$entropy2-$jointEntropy)/$jointEntropy]
                }
            } else {
                return [expr $entropy1+$entropy2-$jointEntropy]
            }
        }
        
        return ""
    }
    
}

