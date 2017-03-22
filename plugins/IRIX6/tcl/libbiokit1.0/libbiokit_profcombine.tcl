############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################


package provide libbiokit 1.0

namespace eval ::Libbiokit {
    
    proc combineAlignments {alignments referenceAlignment keepersGroups} {
        
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
    
    proc concatAlignments {alignments} {
       
       set combinedAlignment {}
       foreach alignment $alignments {
           set combinedAlignment [concat $combinedAlignment $alignment]
       }       
       return $combinedAlignment
    } 
}
