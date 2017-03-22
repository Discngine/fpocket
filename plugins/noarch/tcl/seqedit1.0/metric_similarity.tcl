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
namespace eval ::SeqEdit::Metric::Similarity {

    # Export the package namespace.
    namespace export calculate

    proc calculate30 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum30.bla" $sequenceIDs]
    }
    
    proc calculate40 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum40.bla" $sequenceIDs]
    }
    
    proc calculate50 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum50.bla" $sequenceIDs]
    }
    
    proc calculate60 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum60.bla" $sequenceIDs]
    }
    
    proc calculate70 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum70.bla" $sequenceIDs]
    }
    
    proc calculate80 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum80.bla" $sequenceIDs]
    }
    
    proc calculate90 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum90.bla" $sequenceIDs]
    }
    
    proc calculate100 {sequenceIDs} {
        global env
        return [calculate "$env(BLOSUMDIR)/blosum100.bla" $sequenceIDs]
    }
    
    proc calculateCustom {sequenceIDs} {
        global env
        set filename [tk_getOpenFile -filetypes {{{All Files} * }} -title "Load Custom Similarity Matrix"]
        if {$filename != ""} {
            return [calculate $filename $sequenceIDs]
        }
    }
    
    # Calculates a metric for a given set of sequences.
    # args:     sequenceIDs - The list of sequences for which the metric should be calculated.
    # return:   A list containing the TCL array of sequence elements to values. The valued should be between 0.0 and 1.0.
    proc calculate {matrix sequenceIDs} {
       
       # Initialize the color map and other arrays and vars
        array set counts {}
        array set metricMap {}
        array set SimilarityMatrix {}
        array set alphabet {}
        array set SubMatAlphabet {}
        set countGaps 1
        
        # Flag used to determine is similarity matrix has negative values
        set MatrixHasNegativeValues 0
        
        # Read in substitution matrix. 
        set fp [open $matrix r]
        set beginRead 0         
        while {![eof $fp] && [gets $fp line] >= 0} {
            
            # Trim off anything after the first pound.
            if {[string first "#" $line] != -1} {
                set line [string range $line 0 [expr [string first "#" $line]-1]]
            }
            
            # Trim off any leading or trailing spaces.
            set line [string trim $line]
            
            # Make sure the line had some data.
            if {[string length $line] > 0} {
                
                # Break the line into columns.
                set columns [regexp -inline -all {\S+} $line]
            
                # Assume the first line with data has the column headings. 
                if {$beginRead == 0} {
                    
                    # Read the alphabet of amino acids.
                    set i 0
                    foreach column $columns {
                        set SubMatAlphabet($i) $column
                        set SubMatAlphabet($column) "Y"
                        incr i
                    }
                    set SubMatAlphabet(length) $i
                    set beginRead 1 
                    set lineIndex 0
                    
                # Otherwise this must be a line in the matrix.
                } elseif {$beginRead == 1 && $lineIndex < $SubMatAlphabet(length)} {
                                        
                    # If we have one more column than alphabet members, assume first column is element name.
                    if {[llength $columns] == [expr $SubMatAlphabet(length)+1]} {
                        set lineElement [lindex $columns 0]
                        set columns [lrange $columns 1 end]
                    
                    # Otherwise if we have equal numbers, assume they go in order vertically.
                    } elseif {[llength $columns] == $SubMatAlphabet(length)} {
                        set lineElement $SubMatAlphabet($lineIndex)
                        
                    # Otherwise we don't know how to process this line.
                    } else {
                        puts "SeqEdit Error) Unknown similarity matrix format at line:"
                        puts "       $line"
                        return {}
                    }
                    
                    # If we figured out what data was in this row, process it.
                    if {$lineElement != "" } {
                        set i 0
                        foreach column $columns {
                            set otherElement $SubMatAlphabet($i)
                            set SimilarityMatrix($lineElement,$otherElement) $column
                            if { $column < 0 } { 
                                set MatrixHasNegativeValues 1 
                            }                        
                            incr i
                        }
                    }
                        
                    # Track what data line we are on.
                    incr lineIndex
                }
            }
        }
        
        # Close the file.
        close $fp
        
        # Go through each sequence in the list.
        foreach sequenceID $sequenceIDs {
        
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set elementIndex 0
            foreach element $sequence {
                
                if {$countGaps && $element == "-"} {
                    set element "*"
                }
                
                # If this element is in the alphabet, count it.
                if {[info exists SubMatAlphabet($element)]} {
                    
                    # Increment the counter.
                    if {![info exists counts($elementIndex,$element)]} {
                        set counts($elementIndex,$element) 1                    
                     } else {
                        incr counts($elementIndex,$element)
                    }
    
                    # Increment the total.
                    if {![info exists counts($elementIndex,total)]} {
                        set counts($elementIndex,total) 1
                     } else {
                        incr counts($elementIndex,total)
                    }
    
                    # Add the element to the alphabet used at this position.            
                    if {![info exists alphabet($elementIndex)]} {
                        set alphabet($elementIndex) [list $element]
                    } elseif {[lsearch -exact $alphabet($elementIndex) $element] == -1} {
                        lappend alphabet($elementIndex) $element
                    }
                }
		
                incr elementIndex
            }
	    
        }
            
        # Go through each sequence in the list.
        foreach sequenceID $sequenceIDs {
        
            # Get the sequence.
            set sequence [SeqData::getSeq $sequenceID]
            
            # Go through each element in the sequence.
            set elementIndex 0
            foreach element $sequence {
                
                # See if this element is in our matrix alphabet.
                if {[info exists SubMatAlphabet($element)]} {
                    
                    # See if there are any other elements in this column.
                    if {$counts($elementIndex,total) > 1} {
                        set simSum 0
                        foreach tempElement $alphabet($elementIndex) {
    
                            if {$tempElement == $element} {
                               set simSum [expr $SimilarityMatrix($element,$tempElement)*($counts($elementIndex,$tempElement)-1.0) + $simSum]
                            } else {
                               set simSum [expr $SimilarityMatrix($element,$tempElement)*$counts($elementIndex,$tempElement) + $simSum]
                            }
                        }
                        set averageSimSum [expr ($simSum)/(double($counts($elementIndex,total))-1.0)]
                        if {$simSum > 0} {
                            set largestCorrelation $SimilarityMatrix($element,$element)
                            set normalizedSimSum [expr $averageSimSum/(double($largestCorrelation))]  
                        } elseif {$simSum < 0} {
                             set largestAntiCorrelation [expr abs($SimilarityMatrix($element,*))]
                            if {$largestAntiCorrelation == 0} {
                                set largestAntiCorrelation 1
                            }
                            set normalizedSimSum [expr $averageSimSum/(double($largestAntiCorrelation))] 
                            
                        } elseif {$simSum == 0} {
                            set normalizedSimSum 0.0
                        }
                        
                        if { $MatrixHasNegativeValues == 1 } {
                            #use this only if the similatiry matrix has positive, 0 and negative values. 
                            set fractionSimilarity [expr (($normalizedSimSum +1.0)/2)]
                            set metricMap($sequenceID,$elementIndex) $fractionSimilarity
                        } else {
                            set metricMap($sequenceID,$elementIndex) $normalizedSimSum
                        }
                    } else {
                        set metricMap($sequenceID,$elementIndex) 1.0
                    }
                    
                } else {
                    set metricMap($sequenceID,$elementIndex) 0.0
                }
                
                # Increment the element counter.
                incr elementIndex            
            }
        }

    

        # Return the color map.
        return [array get metricMap]
    }
}
