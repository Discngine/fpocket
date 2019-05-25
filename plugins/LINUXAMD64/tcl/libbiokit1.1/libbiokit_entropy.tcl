# University of Illinois Open Source License
# Copyright 2007-2008 Luthey-Schulten Group, 
# All rights reserved.
# 
# $Id: libbiokit_entropy.tcl,v 1.3 2013/04/15 16:29:19 johns Exp $
# 
# Developed by: Luthey-Schulten Group
# 			     University of Illinois at Urbana-Champaign
# 			     http://www.scs.illinois.edu/~schulten
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the Software), to deal with 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
# of the Software, and to permit persons to whom the Software is furnished to 
# do so, subject to the following conditions:
# 
# - Redistributions of source code must retain the above copyright notice, 
# this list of conditions and the following disclaimers.
# 
# - Redistributions in binary form must reproduce the above copyright notice, 
# this list of conditions and the following disclaimers in the documentation 
# and/or other materials provided with the distribution.
# 
# - Neither the names of the Luthey-Schulten Group, University of Illinois at
# Urbana-Champaign, nor the names of its contributors may be used to endorse or
# promote products derived from this Software without specific prior written
# permission.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL 
# THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS WITH THE SOFTWARE.
#
# Author(s): Elijah Roberts

package provide libbiokit 1.1
package require seqdata 1.1

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
       
    proc calculateGroupMutualInformation {sequenceGroups {lnBase 0.69314718056} {normalize 0} {minValue 0.0} {maxGapFraction 1.0} {unknownChars "?"}} {
        
        # Figure out the number of sequence positions.
        set numberPositions -1
        foreach sequencesIDs $sequenceGroups {
            foreach sequenceID $sequencesIDs {
                set len [::SeqData::getSeqLength $sequenceID] 
                if {$numberPositions == -1} {
                    set numberPositions $len
                } elseif {$len != $numberPositions} {
                    error "Mutual information can only be calculated for aligned sequences."
                }
            }
        }
        
        # Get the mutual information per column.
        set miValues {}
        set Ngroup [llength $sequenceGroups]
        for {set positionIndex 0} {$positionIndex < $numberPositions} {incr positionIndex} {
            
            # Create the probability matrix.
            array set probabilityMatrix [caculateGroupProbabilityMatrix $sequenceGroups $positionIndex $unknownChars]
                
            # Calculate the mutual information.
            set miValue [::Libbiokit::Entropy::calculateMutualInformationByProbability [array get probabilityMatrix] $lnBase $normalize]
            if {$miValue >= $minValue} {
                lappend miValues $miValue
            } else {
                lappend miValues 0.0
            }
            unset probabilityMatrix
        }
        
        # See if we need to remove any columns with too many gaps.
        if {$maxGapFraction < 1.0} {
            
            # Get the fraction of gaps in each column.
            set filteredMiValues {}
            for {set positionIndex 0} {$positionIndex < $numberPositions} {incr positionIndex} {
                set excludePosition 0
                for {set groupIndex 0} {$groupIndex < $Ngroup} {incr groupIndex} {
                    set count 0
                    set Nseq 0
                    set sequencesIDs [lindex $sequenceGroups $groupIndex]
                    foreach sequenceID $sequencesIDs {
                        if {[::SeqData::getElement $sequenceID $positionIndex] == "-"} {
                            incr count
                        }
                        incr Nseq
                    }
                    if {[expr double($count)/double($Nseq)] > $maxGapFraction} {
                        set excludePosition 1
                        break
                    }
                }
                if {$excludePosition} {
                    lappend filteredMiValues 0.0
                } else {
                    lappend filteredMiValues [lindex $miValues $positionIndex]
                }
            }
            set miValues $filteredMiValues
        }
        
        return $miValues
    }
    
    proc caculateGroupProbabilityMatrix {sequenceGroups positionIndex {unknownChars "?"}} {
        
        # Split the unknown string into a list.
        set unknownChars [split $unknownChars ""]
        
        array unset probabilityMatrix 
        set Ngroup [llength $sequenceGroups]
        set values {}
        for {set groupIndex 0} {$groupIndex < $Ngroup} {incr groupIndex} {
            
            # Get the counts within this group.
            set Nval 0
            set sequencesIDs [lindex $sequenceGroups $groupIndex]
            foreach sequenceID $sequencesIDs {
                
                set value [::SeqData::getElement $sequenceID $positionIndex]
                if {[lsearch -exact $unknownChars $value] != -1} {
                    continue
                }
                
                # If we have not yet seen this value, create a new entry for it in the matrix.
                if {[lsearch -exact $values $value] == -1} {
                    for {set i 0} {$i < $Ngroup} {incr i} {
                        set probabilityMatrix($value,$i) 0
                    }
                    lappend values $value
                }
                
                # Increment the count in the matrix.
                incr probabilityMatrix($value,$groupIndex)
                incr Nval
            }
            
            # If there were no known characters, assume each as equally likely.
            if {$Nval == 0} {
                foreach value $values {
                    set probabilityMatrix($value,$groupIndex) [expr double(1.0/($Ngroup))*double(1.0/double([llength $values]))]
                }
                
            # Convert the counts for this in group into probabilities.
            } else {
                foreach value $values {
                    set pr [expr double(1.0/($Ngroup))*double($probabilityMatrix($value,$groupIndex))/double($Nval)]
                    set probabilityMatrix($value,$groupIndex) $pr
                }
            }
        }

        return [array get probabilityMatrix]
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
    
    proc calculateProbabilities {values} {
        
        # Zero out the counters.
        set usedValues {}
        array unset counts 
        
        # Go through each value and calculate the number of occurrences of each value.
        foreach value $values {
            if {[lsearch -exact $usedValues $value] == -1} {
                lappend usedValues $value
                set counts($value) 1
            } else {
                incr counts($value)
            }
        }
        
        # Calculate the probabilities.
        set probabilities {}
        set Nval [llength $values]
        foreach usedValue [lsort $usedValues] {
            lappend probabilities [expr double($counts($usedValue))/double($Nval)]
        }
        
        return $probabilities
    }
    
    proc calculateEntropyByProbability {probabilities {lnBase 0.69314718056}} {
        
        # Calculate the entropy.
        set H 0
        foreach pr $probabilities {
            if {$pr > 0.0} {
                set H [expr $H - $pr*log($pr)/$lnBase]
            }
        }
        return $H
    }
    
    proc calculateEntropy {values {lnBase 0.69314718056}} {
        
        return [calculateEntropyByProbability [calculateProbabilities $values] $lnBase]
    }
    
    proc calculateProbabilityMatrix {values1 values2} {
        
        # Make sure the values lists are of the same length.
        set Nval [llength $values1]
        if {[llength $values2] != $Nval} {
            error "A probability matrix can only be calculated from two lists of equal length."
        }
        
        # Get the used values.
        set usedValues1 {}
        set usedValues2 {}
        for {set i 0} {$i < $Nval} {incr i} {
            set value1 [lindex $values1 $i]
            set value2 [lindex $values2 $i]
            if {[lsearch -exact $usedValues1 $value1] == -1} {
                lappend usedValues1 $value1
            }
            if {[lsearch -exact $usedValues2 $value2] == -1} {
                lappend usedValues2 $value2
            }
        }
        set usedValues1 [lsort $usedValues1]
        set usedValues2 [lsort $usedValues2]
        
        # Create the array.
        array unset probabilityMatrix 
        foreach value1 $usedValues1 {
            foreach value2 $usedValues2 {
                set probabilityMatrix($value1,$value2) 0
            }
        }
        
        # Go through the values and count the number of occurrences of each pair.
        for {set i 0} {$i < $Nval} {incr i} {
            set value1 [lindex $values1 $i]
            set value2 [lindex $values2 $i]
            incr probabilityMatrix($value1,$value2)
        }
        
        # Calculate the probabilities.
        foreach value [array names probabilityMatrix] {
            set probabilityMatrix($value) [expr double($probabilityMatrix($value))/double($Nval)]
        }
        return [array get probabilityMatrix]
    }
    
    proc calculateJointEntropyByProbability {probabilityMatrixValues {lnBase 0.69314718056}} {
        
        # Reconstruct the matrix.
        array set probabilityMatrix $probabilityMatrixValues
        
        # Calculate the entropy.
        set H 0
        foreach value [array names probabilityMatrix] {
            set pr $probabilityMatrix($value)
            if {$pr > 0.0} {
                set H [expr $H - $pr*log($pr)/$lnBase]
            }
        }
        return $H
    }
    
    proc calculateJointEntropy {values1 values2 {lnBase 0.69314718056}} {
        
        return [calculateJointEntropyByProbability [calculateProbabilityMatrix $values1 $values2] $lnBase]        
    }
    
    proc extractIndividualProbabilities {probabilityMatrixValues} {
        
        # Get the matrix.
        array set probabilityMatrix $probabilityMatrixValues
        
        # Get the values.
        set values1 {}
        set values2 {}
        foreach value [array names probabilityMatrix] {
            set valuePairs [split $value ","]
            set value1 [lindex $valuePairs 0]
            set value2 [lindex $valuePairs 1]
            if {[lsearch -exact $values1 $value1] == -1} {
                lappend values1 $value1
            }
            if {[lsearch -exact $values2 $value2] == -1} {
                lappend values2 $value2
            }
        }
        set values1 [lsort $values1]
        set values2 [lsort $values2]
        
        # Get the probabilities for the individual values from the matrix.
        set probabilities1 {}
        foreach value1 $values1 {
            set pr 0.0
            foreach value2 $values2 {
                set pr [expr $pr+$probabilityMatrix($value1,$value2)]
            }
            lappend probabilities1 $pr
        }
        set probabilities2 {}
        foreach value2 $values2 {
            set pr 0.0
            foreach value1 $values1 {
                set pr [expr $pr+$probabilityMatrix($value1,$value2)]
            }
            lappend probabilities2 $pr
        }
        
        return [list $probabilities1 $probabilities2]
    }
        
    proc calculateMutualInformationByProbability {probabilityMatrixValues {lnBase 0.69314718056} {normalize 0}} {
        
        # Extract the probabilities of the variables.
        set probabilities [extractIndividualProbabilities $probabilityMatrixValues]
        
        # Calculate the individual entropies.
        set entropy1 [calculateEntropyByProbability [lindex $probabilities 0] $lnBase]
        set entropy2 [calculateEntropyByProbability [lindex $probabilities 1] $lnBase]
        
        # Calculate the joint entropy.
        set jointEntropy [calculateJointEntropyByProbability $probabilityMatrixValues $lnBase]
        
        set mi [expr $entropy1+$entropy2-$jointEntropy]
        
        # Return the mutual information.
        if {$normalize == 1} {
            if {$jointEntropy == 0.0} {
                set mi 0.0
            } else {
                set mi [expr $mi/$jointEntropy]
            }
        } elseif {$normalize == 2} {
            if {$entropy1 == 0.0} {
                set mi 0.0
            } else {
                set mi [expr $mi/$entropy1]
            }
        } elseif {$normalize == 3} {
            if {$entropy2 == 0.0} {
                set mi 0.0
            } else {
                set mi [expr $mi/$entropy2]
            }
        }
        
        return $mi
    }
    
    proc calculateMutualInformation {values1 values2 {lnBase 0.69314718056} {normalize 0}} {
        
        return [calculateMutualInformationByProbability [calculateProbabilityMatrix $values1 $values2] $lnBase $normalize]
    }    
}

