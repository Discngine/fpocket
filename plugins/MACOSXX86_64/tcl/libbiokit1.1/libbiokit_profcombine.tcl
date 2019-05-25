# University of Illinois Open Source License
# Copyright 2007 Luthey-Schulten Group, 
# All rights reserved.
# 
# $Id: libbiokit_profcombine.tcl,v 1.3 2013/04/15 16:29:19 johns Exp $
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
# Author(s): Elijah Roberts, Jonathan Montoya

package provide libbiokit 1.1

namespace eval ::Libbiokit {
    
    proc combineAlignments {alignment1 alignment2 referenceAlignment} {
        
        # Group the reference sequences by which alignment they are present in.
        set ret [findReferenceSequences $alignment1 $referenceAlignment]
        set reference1 [lindex $ret 0]
        set cross1 [lindex $ret 1]
        set ret [findReferenceSequences $alignment2 $referenceAlignment]
        set reference2 [lindex $ret 0]
        set cross2 [lindex $ret 1]
        
        # Make sure each alignments has at least one reference sequence.
        if {[llength $reference1] == 0 || [llength $reference2] == 0} {
            error "Each alignment must contain at least one of the reference sequences."
        }
        
        # Get the positions in the full alignment that correspond to the reference alignment.
        set positions1 [correlateReferencePositions $reference1 $cross1]
        set positions2 [correlateReferencePositions $reference2 $cross2]
        
        # Make sure we have the correct number of positions.
        set referenceAlignmentLength [::SeqData::getSeqLength [lindex $referenceAlignment 0]]
        if {[llength $positions1] != $referenceAlignmentLength || [llength $positions2] != $referenceAlignmentLength} {
            error "Could not correlate the positions in the alignments: [llength $positions1], [llength $positions2], $referenceAlignmentLength"
        }
        
        #for {set i 0} {$i < [llength $positions1]} {incr i} {
        #    puts -nonewline "$i:[lindex $positions1 $i] "
        #}
        #puts ""
        #puts ""
        #for {set i 0} {$i < [llength $positions2]} {incr i} {
        #    puts -nonewline "$i:[lindex $positions2 $i] "
        #}
        #puts ""
        #puts ""
        
        # Insert positions that correspond to insertions relative to the reference alignment.
        set ret [reconcileAlignmentPositions $positions1 [::SeqData::getSeqLength [lindex $alignment1 0]] $positions2]
        set positions1 [lindex $ret 0]
        set positions2 [lindex $ret 1]
        set ret [reconcileAlignmentPositions $positions2 [::SeqData::getSeqLength [lindex $alignment2 0]] $positions1]
        set positions2 [lindex $ret 0]
        set positions1 [lindex $ret 1]
        
        # Make sure we have the correct number of positions.
        set referenceAlignmentLength [::SeqData::getSeqLength [lindex $referenceAlignment 0]]
        if {[llength $positions1] != [llength $positions2]} {
            error "Could not reconcile the positions in the alignments: [llength $positions1], [llength $positions2]"
        }
        
        # Adjust the alignments.
        adjustAlignment $alignment1 $positions1
        adjustAlignment $alignment2 $positions2
        
        return [concat $alignment1 $alignment2]
    }
    
    proc findReferenceSequences {alignment referenceAlignment} {
        
        set referenceIDs {}
        array unset crossReferences
        foreach referenceID $referenceAlignment {
            foreach sequenceID $alignment {
                if {[::SeqData::getName $sequenceID] == [::SeqData::getName $referenceID]} {
                    lappend referenceIDs $referenceID
                    set crossReferences($referenceID) $sequenceID
                    break
                }
            }
        }
        return [list $referenceIDs [array get crossReferences]]
    }
    
    proc correlateReferencePositions {referenceIDs crossReferencesList} {
        
        set positionsInAlignment {}
        
        # Go through the reference alignment.
        array set crossReferences $crossReferencesList
        set numberPositions [::SeqData::getSeqLength [lindex $referenceIDs 0]]
        for {set position 0} {$position < $numberPositions} {incr position} {
            
            # Find the first reference sequence with a residue at this position.
            set residue -1
            foreach referenceID $referenceIDs {
                set residue [::SeqData::getResidueForElement $referenceID $position]
                if {$residue != -1} {
                    break
                }
            }
            
            # If we found a residue, get its position in the full alignment.
            if {$residue != -1} {
                lappend positionsInAlignment [::SeqData::getElementForResidue $crossReferences($referenceID) $residue]
                
            # Otherwise, record that there are no residues at this position.
            } else {
                lappend positionsInAlignment -1
            }
        }
        
        return $positionsInAlignment
    }
    
    proc reconcileAlignmentPositions {refPositions1 numberAlignmentPositions refPositions2} {
        
        set newRefPositions1 {}
        set newRefPositions2 {}
        
        # Go through the positions in the reference alignment.
        set refPosition 0
        set alignmentPosition 0
        while {$refPosition < [llength $refPositions1]} {
            
            # If this is a gap, copy this position as is.
            if {[lindex $refPositions1 $refPosition] == -1} {
                lappend newRefPositions1 [lindex $refPositions1 $refPosition]
                lappend newRefPositions2 [lindex $refPositions2 $refPosition]
                incr refPosition
                
            # If this position is greater than the alignment position, insert the missing positions.
            } elseif {[lindex $refPositions1 $refPosition] > $alignmentPosition} {                
                while {$alignmentPosition < [lindex $refPositions1 $refPosition]} {
                    lappend newRefPositions1 $alignmentPosition
                    lappend newRefPositions2 -1
                    incr alignmentPosition
                }
                
                
            # If this position is equal to the reference position, copy it as is.
            } elseif {[lindex $refPositions1 $refPosition] == $alignmentPosition} {
                lappend newRefPositions1 [lindex $refPositions1 $refPosition]
                lappend newRefPositions2 [lindex $refPositions2 $refPosition]
                incr alignmentPosition
                incr refPosition
            
            # Otherwise something must have gone wrong.
            } else {
                error "Could not reconcile alignment insertions with the reference alignment: [lindex $refPositions1 $refPosition], $alignmentPosition."
            }
            
        }
        
        # If there are more positions at the end, add them.
        while {$alignmentPosition < $numberAlignmentPositions} {
            lappend newRefPositions1 $alignmentPosition
            lappend newRefPositions2 -1
            incr alignmentPosition
        }
        
        return [list $newRefPositions1 $newRefPositions2]
    }
    
    proc adjustAlignment {alignment positions} {
        
        foreach sequenceID $alignment {
            set seq [::SeqData::getSeq $sequenceID]
            set newSeq {}
            set nextPosition 0
            foreach position $positions {
                if {$position == -1} {
                    lappend newSeq "-"
                } elseif {$position == $nextPosition} {
                    lappend newSeq [lindex $seq $position]
                    incr nextPosition
                } else {
                    error "Could not adjust the alignment: $position, $nextPosition"
                }
            }
            ::SeqData::setSeq $sequenceID $newSeq
        }
    }
    
    proc combineAlignments2 {alignments referenceAlignment keepersGroups} {
        
        set returnSet {}
        set keepersGroups [lindex $keepersGroups 0]
        set data {}
        set refLen [llength $referenceAlignment]
        foreach member $alignments { 
            
            for {set i 0} {$i < [llength $member]} {incr i} {
                set flag 0
                set name1 [::SeqData::getName [lindex $member $i]]
                for {set j 0} {$j < $refLen} {incr j} {
                    
                    set name2 [::SeqData::getName [lindex $referenceAlignment $j]]
                    if {"$name1" == "$name2"} {
                        set flag 1
                        #Align group to reference sequence and remove/store data that does not agree
                        set sequence [::SeqData::getSeq [lindex $referenceAlignment $j]]
                        set sequence2 [::SeqData::getSeq [lindex $member $i]]
                        for {set k 0} {$k < [llength $sequence]} {incr k} {
        
                            set element1 [lindex $sequence $k]
                            set seqLen [llength $sequence2]
                            for {set l 0} {$l < $seqLen } {incr l} {
                                set element2 [lindex $sequence2 $l]
                                if {"$element1" == "$element2" && "$element2" != "-"} {
                                         set k [expr $k+1]
                                     set element2 [lindex $sequence2 $l]
                                     set element1 [lindex $sequence $k]
                                     
                                } elseif {"$element1" == "$element2" && "$element2" == "-"} {
                                    # See if the colum being compared only contains gaps
                                    set count 0
                                    foreach seq $member {
                                        
                                        set sequenceComp [::SeqData::getSeq $seq]
                                        set elementComp [lindex $sequenceComp $l]
                                        if {$elementComp != "-"} {
                                            set count [expr $count + 1]
                                        }
                                    }
                                    
                                    if {$count != 0} {
                                        # If there is data remove the column
                                        set tempDat {}
                                        lappend tempDat $k
                                        foreach seq $member {
                                            
                                            set seqs [::SeqData::getSeq $seq]
                                            set thing [lindex $seqs $l]
                                            lappend tempDat $seq $thing
                                            ::SeqData::removeElements $seq $l 
                                        }
                                        
                                        foreach member2 $alignments {
                                            
                                            set thing2 {-}
                                            if {$member != $member2} {
                                                foreach seq2 $member2 {	
                                                    set seqs2 [::SeqData::getSeq $seq2]
                                                    lappend tempDat $seq2 $thing2
                                                }
                                            }
                                        }
                                    
                                        lappend data $tempDat
                                        set k $k
                                        set l [expr $l-1]
                                        set sequence2 [::SeqData::getSeq [lindex $member $i]]
                                        set seqLen [expr $seqLen - 1]
                                        set element2 [lindex $sequence2 $l]
                                        set element1 [lindex $sequence $k]
                                    } else {
                                        # If empty move on
                                        set k [expr $k+1]
                                        set element2 [lindex $sequence2 $l]
                                        set element1 [lindex $sequence $k]
                                    }
                                    
                                } elseif { "$element1" == "-" && "$element2" != "-"} {
    
                                    set elementList {-}
                                    foreach seq $member {
                                        ::SeqData::insertElements $seq $l $elementList
                                    }
                                    set k [expr $k+1]
                                    set sequence2 [::SeqData::getSeq [lindex $member $i]]
                                    set seqLen [expr $seqLen + 1]
                                    set element2 [lindex $sequence2 $l]
                                    set element1 [lindex $sequence $k]
                                    
                                } else { 
    
                                    set tempDat {}
                                    lappend tempDat $k
                                    foreach seq $member {	
                                        
                                        set seqs [::SeqData::getSeq $seq]
                                        set thing [lindex $seqs $l]
                                        lappend tempDat $seq $thing
                                        ::SeqData::removeElements $seq $l 
                                    }
                                    
                                    foreach member2 $alignments {
                                        
                                        set thing2 {-}
                                        if {$member != $member2} {
                                            foreach seq2 $member2 {	
                                                set seqs2 [::SeqData::getSeq $seq2]
                                                lappend tempDat $seq2 $thing2
                                            }
                                        }
                                    }
                                    
                                    lappend data $tempDat
                                    set k $k
                                    set l [expr $l-1]
                                    set sequence2 [::SeqData::getSeq [lindex $member $i]]
                                    set seqLen [expr $seqLen - 1]
                                    set element2 [lindex $sequence2 $l]
                                    set element1 [lindex $sequence $k]
                                    
                                }
                                
                                #Check sequences are same length
                                if {$l == [expr $seqLen -1]} {
                                    if {[llength $sequence] != $seqLen} {
                                        set seqLen [llength $sequence]
                                    }
                                }
                                    
                            }
                            
                        }
                        set referenceAlignment [lreplace $referenceAlignment $j $j]
                        set refLen [expr $refLen -1]
                        break 
                    }
                    
                }
                if {$flag == 1} {
                    break
                }
            }
            
        }
        
        #Combine the sets
        set alignments [concatAlignments $alignments]
    
        #Now we need to put the data we removed back into the alignment
        set previous {}
        set lendata [llength $data]
        for {set i 0} {$i < $lendata} {incr i} {
            
            set counter 0
            set counter2 0
            set hombre [lindex $data $i]
            set listlen [expr ([llength $hombre] -1)]
            set refPos [lindex $hombre 0]
            # Need to accound for changes in position from new data
            foreach count $previous {
                
                if {$refPos == $count} {
                    set counter [expr $counter +1]
                } 
            }
            
            if {$refPos != 0 } {
                set counter2 [expr [llength $previous]- $counter]
            } 
            
            lappend previous $refPos
            set elementList {-}
            for {set t 1} {$t < $listlen} {incr t 2} { 
                
                ::SeqData::insertElements [lindex $hombre $t] [expr $refPos+$counter+$counter2] [list [lindex $hombre [expr $t+1]]]
            }
        }
            
        #Move preserved to top
        if {[llength $keepersGroups] == 0} {
            return $alignments
        } else {
    
            set count 0
            for {set i 0} {$i < [llength $keepersGroups]} {incr i} { 
                    
                set name1 [::SeqData::getName [lindex $keepersGroups $i]]
                for {set j 0} {$j < [llength $alignments]} {incr j} {
                                
                    set name2 [::SeqData::getName [lindex $alignments $j]]
                    if {"$name1" == "$name2"} {
                        if {$j == 0} {
                            set count 0
                        } else {
                            set count 1
                        }
                        set alignments [linsert $alignments $i [lindex $alignments $j]]
                        set alignments [lreplace $alignments [expr $j+ $count] [expr $j+ $count] ]
                        
                    }
                }
            }
            lappend returnSet $alignments
            return $returnSet
        }
    }
}
