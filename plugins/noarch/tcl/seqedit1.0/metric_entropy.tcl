############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide seqedit 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::Metric::Entropy {

    # Export the package namespace.
    namespace export calculate

    proc calculateStrict {sequenceIDs} {
        set alphabet {A C D E F G H I K L M N P Q R S T V W Y}
        return [calculate $sequenceIDs $alphabet]
    }
        
    proc calculateSimilar {sequenceIDs} {
        set alphabet {S C N F H V H Y}
        set mapping {A S C C D N E N F F G S H H I V K H L V M V N N P S Q N R H S S T S V V W F Y Y}
        return [calculate $sequenceIDs $alphabet $mapping]
    }
    
    # Calculates a metric for a given set of sequences.
    # args:     sequenceIDs - The list of sequences for which the metric should be calculated.
    # return:   A list containing the TCL array of sequence elements to values. The valued should be between 0.0 and 1.0.
    proc calculate {sequenceIDs alphabet {mapping {}} {maxMissingFraction 0.5}} {
        
        # Initialize the color map.
        array set metricMap {}
        
        # Calculate the entropies
        set entropies [calculateColumnEntropies $sequenceIDs $alphabet $mapping $maxMissingFraction]
        
        # Fill in the color map.
        foreach sequenceID $sequenceIDs {
            for {set i 0} {$i < [::SeqData::getSeqLength $sequenceID]} {incr i} {
                if {$i < [llength $entropies]} {
                    set H [lindex $entropies $i]
                    if {$H < 0} {
                        set metricMap($sequenceID,$i) 0.0
                    } else {
                        set metricMap($sequenceID,$i) [expr 1.0-$H]
                    }
                } else {
                    set metricMap($sequenceID,$i) 0.0
                }
            }
        }
        
        # Return the color map.
        return [array get metricMap]
    }
    
    proc calculateColumnEntropies {sequenceIDs alphabet {mapping {}} {maxMissingFraction 0.0}} {
        
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
        set entropies {}
        set lnBase [expr log([llength $alphabet])]
        for {set i 0} {$i < $Naln} {incr i} {
        
            # Get a list of the values in this column.
            set elements {}
            for {set j 0} {$j < $Nseq} {incr j} {
                
                # Get the element, mapping it if necessary.
                set element [lindex [lindex $alignment $j] $i]
                if {[info exists map($element)]} {
                    set element $map($element)
                }
                lappend elements $element
            }
            
            # Calculate the entropy.
            lappend entropies [calculateEntropy $elements $alphabet $maxMissingFraction $lnBase]
        }
        
        return $entropies
    }
    
    proc calculateEntropy {values alphabet maxMissingFraction lnBase} {
        
        # Zero out the counters.
        array set count {}
        set count(?) 0
        set count(-) 0
        foreach letter $alphabet {
            set count($letter) 0
        }
        
        # Go through each value and calculate the number of occurrences of each letter.
        foreach value $values {
            if {[lsearch -exact $alphabet $value] >= 0} {
                incr count($value)
            } else {
                incr count(?)
            }
        }
        
        # Calculate the entropy at this position.
        set H 0
        set Nval [llength $values]
        if {[expr $count(?)+$count(-)] <= [expr int(double($Nval)*double($maxMissingFraction))]} {
            foreach letter $alphabet {
                if {$count($letter) > 0} {
                    set pr [expr double($count($letter))/double($Nval)]
                    set H [expr $H - $pr*log($pr)/$lnBase]
                }
            }
        } else {
            set H -1
        }
        
        return $H
    }
    
    proc calculateMutualInformationMatrix {sequenceIDs alphabet mapping maxMissingFraction {normalize 0}} {
        
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
    
    proc calculateJointEntropyMatrix {sequenceIDs alphabet mapping maxMissingFraction} {
        
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
    
    proc calculateMutualInformation {values1 values2 alphabet1 alphabet2 maxMissingFraction lnBase {normalize 0}} {
        
        # Calculate the individual entropies.
        set entropy1 [calculateEntropy $values1 $alphabet1 $maxMissingFraction $lnBase]
        set entropy2 [calculateEntropy $values2 $alphabet2 $maxMissingFraction $lnBase]
        
        # Calculate the joint entropy.
        set jointEntropy [calculateJointEntropy $values1 $values2 $alphabet1 $alphabet2 $maxMissingFraction $lnBase]
        
        # Return the mutual information.
        if {$entropy1 != -1 && $entropy2 != -1 && $jointEntropy != -1} {
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
        
        return -1
    }

    proc calculateJointEntropy {values1 values2 alphabet1 alphabet2 maxMissingFraction lnBase} {
        
        # Make sure the values lists are of the same length.
        set Nval [llength $values1]
        if {[llength $values2] != $Nval} {
            return -1
        }
        
        # Zero out the counters.
        array set count {}
        set count(?) 0
        set count(-) 0
        
        # Go through the values and count the number of occurrences of each pair.
        for {set i 0} {$i < $Nval} {incr i} {
            set value1 [lindex $values1 $i]
            set value2 [lindex $values2 $i]
            if {$value1 == "-" || $value2 == "-"} {
                incr count(-)
            }
            if {[lsearch -exact $alphabet1 $value1] >= 0 && [lsearch -exact $alphabet2 $value2] >= 0} {
                set value "$value1$value2"
                if {[info exists count($value)]} {
                    incr count($value)
                } else {
                    set count($value) 1
                }
            } else {
                incr count(?)
            }
        }
        
        # Calculate the entropy at this position.
        set H 0
        if {[expr $count(?)+$count(-)] <= [expr int(double($Nval)*double($maxMissingFraction))]} {
            set values [array names count]
            set unknownIndex [lsearch $values "?"]
            set values [lreplace $values $unknownIndex $unknownIndex]
            foreach value $values  {
                if {$count($value) > 0} {
                    set pr [expr double($count($value))/double($Nval)]
                    set H [expr $H - $pr*log($pr)/$lnBase]
                }
            }
        } else {
            set H -1
        }
        
        return $H
    }
}

