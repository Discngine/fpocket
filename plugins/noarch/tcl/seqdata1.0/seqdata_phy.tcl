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
#       $RCSfile: seqdata_phy.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.5 $       $Date: 2007/01/10 19:46:18 $
#
############################################################################

# This file provides functions for reading and writing sequence data from 
# NEXUS format files

package provide seqdata 1.0

# Sample file format:
#    88    697
#MmazeAla   ---------- ---------- N-ISEM--RE YYLSFFEA-- --RG--HTRI 
#PaeroAla   ---------- ---------- DSLTEL--RE RFLRFFER-- --RG--HARI 
#
#           NRYP-VVARW ---------- ---------- ---------- ---------- 
#           KRYP-VVARW ---------- ---------- ---------- ---------- 
#
#           TIYDALF--- ---------- ---------- ---------- -------
#           TIYDAVF--- ---------- ---------- ---------- -------
namespace eval ::SeqData::Phy {

    # Export the package namespace.
    namespace export saveSequences
    
    # The width of the name column.
    variable nameWidth 9
    
    # The width of the data columns.
    variable columnWidth 10
    
    # The number of data columns per line.
    variable columnsPerLine 5
    
    proc countAlignmentsInFile {filename} {
        
        # Count the number of trees in the file.
        set fp [open $filename "r"]
        set count 0
        while {![eof $fp]} {
            if {[parseHeaderLine [gets $fp]] != {}} {
                incr count 1
            }
        }
        close $fp
        return $count
    }
    
    # Loads a series of sequences from an PHY file into the sequence store.
    # arg:      filename - The name of the file to load.
    # return:   The list of sequences ids that were loaded from the file. 
    #           These ids are for use with the seqdata package.
    proc loadSequences {filename} {
        return [loadFirstAlignment $filename]
    }
    
    proc loadFirstAlignment {filename} {
        
        # Variables for storing the sequence info during the reading process.
        array set sequenceNames {}
        array set sequenceCharacters {}

        # Open file.
        set fp [open $filename r]

        # Read the first alignment.
        set sequenceIDs [readNextAlignmentFromFile $fp]

        # Close file.
        close $fp
        
        # Retrun the alignment.
        return $sequenceIDs
    }
    
    proc readNextAlignmentFromFile {fileID} {
        
        # Read the first line and get the sequence count and length.
        if {![eof $fileID] && [gets $fileID line] >= 0} {
            set counts [parseHeaderLine $line]
            if {[llength $counts] == 2} {
                set sequenceCount [lindex $counts 0]
                set sequenceLength [lindex $counts 1]
            } else {
                error "The specified file was not a valid PHYLIP file."
            }
        } else {
            error "The specified file did not contain any data."
        }
        
        # Keep reading until we have read all of the characters or the file is empty.
        set charactersRead 0
        while {![eof $fileID] && $charactersRead < $sequenceLength} {
            
            # Read the spacer line.
            if {$charactersRead > 0} {
                if {[gets $fileID line] != 0} {
                    error "The specified file did not contain valid PHYLIP formatted data. (4)"
                }
            }
            
            # Read one line per sequence.
            set characterCount ""
            for {set i 0} {$i < $sequenceCount} {incr i} {
                if {[gets $fileID line] >= 0} {
                    
                    # If this is the first line, read the name.
                    if {$charactersRead == 0} {
                        set fields [parseNameLine $line]
                        set sequenceNames($i) [lindex $fields 0]
                        set sequenceCharacters($i) {}
                        set characters [lindex $fields 1]
                        
                    # Otherwise just read the data.
                    } else {
                        set characters [parseCharacterLine $line]
                    }
                    
                    # Make sure this line has the correct number of characters.
                    if {$characterCount == ""} {
                        set characterCount [llength $characters]
                    } elseif {$characterCount != [llength $characters]} {
                        error "The specified file did not contain valid PHYLIP formatted data. (2)"
                    }
                    
                    # Save the characters.
                    set sequenceCharacters($i) [concat $sequenceCharacters($i) $characters]
                    
                } else {
                    error "The specified file did not contain valid PHYLIP formatted data. (3)"
                }
            }
            
            # Increment the characters read.
            incr charactersRead $characterCount
        }
        
        # Create the sequences.
        set sequenceIDs {}
        for {set i 0} {$i < $sequenceCount} {incr i} {
            lappend sequenceIDs [::SeqData::addSeq $sequenceCharacters($i) $sequenceNames($i)]
        }

        return $sequenceIDs
    }
    
    proc parseHeaderLine {line} {
        
        if {[regexp {^\W*([0-9]+)\W+([0-9]+)\W*$} $line unused count length] == 1} {
            return [list $count $length]
        }
        return {}
    }
    
    proc parseNameLine {line} {
        set columns [regexp -inline -all {\S+} $line]
        set name [lindex $columns 0]
        set characters {}       
        foreach column [lrange $columns 1 end] {
            set characters [concat $characters [split $column ""]]
        }
        return [list $name $characters]
    }
    
    proc parseCharacterLine {line} {
        set characters {}       
        set columns [regexp -inline -all {\S+} $line]
        foreach column $columns {
            set characters [concat $characters [split $column ""]]
        }
        return $characters
    }

    
    # Save a series of sequences into a PHY file from the sequence store.
    # arg:  sequences - The list of sequences ids that should be saved to the 
    #                       file. These ids should have come from the seqdata 
    #                       package.
    #       filename - The name of the file to load.
    #       names - An optional list of strings to use to override the sequence names.
    proc saveSequences {sequenceIDs filename {names {}}} {
        
        # Import global variables.
        variable nameWidth
        variable columnWidth
        variable columnsPerLine
    
        # Figure out the maximum sequence length.
        set maxLength 0
        foreach sequenceID $sequenceIDs {
            if {[SeqData::getSeqLength $sequenceID] > $maxLength} {
                set maxLength [SeqData::getSeqLength $sequenceID]
            }
        }
                    
        # Open the file.
        set fp [open $filename w]

        # Write out the header
        puts $fp "[getFixedLengthString [llength $sequenceIDs] 6 left] [getFixedLengthString $maxLength 6 left]"
        
        # Go through all of the sequence data one block at a time.
        for {set i 0} {$i < $maxLength} {incr i [expr $columnWidth*$columnsPerLine]} {
            
            # Write a blank line between sections.
            if {$i != 0} {
            	puts $fp ""
            }
            
            # Go through each sequence.
            for {set j 0} {$j < [llength $sequenceIDs]} {incr j} {
                
                # Get the sequence.
                set sequenceID [lindex $sequenceIDs $j]
                
                # If this is the first block, write out the name.
                if {$i == 0} {
                    
                    # Figure out the name to use.
                    set name [SeqData::getName $sequenceID]
                    if {$j < [llength $names]} {
                        set name [lindex $names $j]
                    }
                    
                    # Replace any invalid characters in the name.
                    regsub {\-} $name "_" name
                    regsub {\_+$} $name "" name
                    
                    # Write the name.
                    puts -nonewline $fp [getFixedLengthString $name $nameWidth]
                
                # Otherwise write an empty block.
                } else {
                    puts -nonewline $fp [getFixedLengthString "" $nameWidth]
                }
                
                # Write out the name spacer.
                puts -nonewline $fp " "
                
                # Get the sequence data.
                set sequenceData [SeqData::getSeq $sequenceID]
                    
                # Write out each column, one at a time.
                for {set k 0} {$k < $columnsPerLine} {incr k} {
                    
                    # Write out the sequence data.
                    set startPos [expr $i+($k*$columnWidth)]
                    set endPos [expr $startPos+$columnWidth-1]
                    if {$endPos >= $maxLength} {
                        set endPos [expr $maxLength-1]   
                    }
                    if {$k > 0} {
                        puts -nonewline $fp " "
                    }
                    puts -nonewline $fp [join [lrange $sequenceData $startPos $endPos] ""]                    
                }
                # Write out the newline.
                puts $fp ""
            }
        }

        # Close the file.
        close $fp
    }
    
    proc getFixedLengthString {str count {paddingSide right}} {
        
        if {$paddingSide == "right"} {
            while {[string length $str] < $count} {
                append str " "
            }
            if {[string length $str] > $count} {
                return [string range $str 0 [expr $count-1]]
            } else {
                return $str
            }
        } elseif {$paddingSide == "left"} {
            while {[string length $str] < $count} {
                set str " $str"
            }
            if {[string length $str] > $count} {
                return [string range $str [expr [string length $str]-$count] [expr [string length $str]-1]]
            } else {
                return $str
            }
        }
    }    
}
