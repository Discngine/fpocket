############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for reading and writing sequence data from FASTA formatted files.

package provide seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqData::Fasta {

    # Export the package namespace.
    namespace export loadSequences saveSequences

    # Loads a series of sequences from a FASTA file into the sequence store.
    # arg:      filename - The name of the file to load.
    # return:   The list of sequences ids that were loaded from the file. 
    #           These ids are for use with the seqdata package.
    proc loadSequences { filename {arg_nameMap {}}} {
        
        # Create an empty list for the sequence ids.
        set sequenceIDList {}
        
        # Open the file.
        set fp [open $filename r]
        
        # Get the name mapping, if one was passed in.
        array set nameMap $arg_nameMap
        
        # Variables for storing the sequence info during the reading process.
        set sequenceName ""
        set sequenceNamePriority -1
        set sequenceSources {}
        set sequenceDescriptions {}
        set sequenceData {}
    
        #>gi|24378190|gb|AAN59447.1| putative aspartyl-tRNA synthetase [Streptococcus mutans UA159] >gi|24380186|ref|NP_722141.1| putative aspartyl-tRNA synthetase [Streptococcus mutans UA159] >gi|46577481|sp|Q8DSG3|SYD1_STRMU Aspartyl-tRNA synthetase 1 (Aspartate--tRNA ligase 1) (AspRS 1)
        # Read in all of the lines in the file.
        while {1} {
            
            # Read the next line.
            set line [gets $fp]
            
            # If the line is a marker line, start reading a new sequence.
            if {[string index $line 0] == ">"} {
            
                # If we are already working on a sequence, save it.
                if {$sequenceName != ""} {
                    set sequenceID [SeqData::addSeq $sequenceData $sequenceName "N" 1 $sequenceSources]
                    if {[llength sequenceDescriptions] > 0} {SeqData::addAnnotation $sequenceID description [lindex $sequenceDescriptions 0]}
                    lappend sequenceIDList $sequenceID
                    
                    #Reset the sequence variables.
                    set sequenceName ""
                    set sequenceNamePriority -1
                    set sequenceSources {}
                    set sequenceDescriptions {}
                    set sequenceData {}
                }
                
                # Break the line into its individual parts.
                foreach part [regexp -inline -all {[^>]+} $line] {

                    # Parse the part.
                    if {[regexp {(\S+)\s*(.*)} [string trim $part] unused headerString description] == 1} {
                     
                        # Parse the headers.
                        set headers [regexp -inline -all {[^\|]+} $headerString]
                        for {set i 0} {$i < [llength $headers]} {incr i} {
                            
                            set header [lindex $headers $i]
                            if {$header == "gi" || $header == "gb" || $header == "ref" || $header == "scop"} {
                                lappend sequenceSources [list $header [lindex $headers [expr $i+1]]]
                                if {$sequenceNamePriority < 0} {
                                    set sequenceName [lindex $headers [expr $i+1]]
                                    set sequenceNamePriority 0
                                }
                                incr i
                            } elseif {$header == "sp"} {
                                lappend sequenceSources [list $header [list [lindex $headers [expr $i+1]] [lindex $headers [expr $i+2]]]]
                                if {$sequenceNamePriority < 2} {
                                    set sequenceName [lindex $headers [expr $i+2]]
                                    set sequenceNamePriority 2
                                }
                                incr i 2
                            } elseif {$header == "pdb"} {
                                lappend sequenceSources [list $header [list [lindex $headers [expr $i+1]] [lindex $headers [expr $i+2]]]]
                                if {$sequenceNamePriority < 1} {
                                    set sequenceName [lindex $headers [expr $i+1]]
                                    set sequenceNamePriority 1
                                }
                                incr i 2
                            } elseif {$header == "ms"} {
                                lappend sequenceSources [list $header [list [lindex $headers [expr $i+1]] [lindex $headers [expr $i+2]] [lindex $headers [expr $i+3]] [lindex $headers [expr $i+4]]]]
                                if {$sequenceNamePriority < 10} {
                                    set sequenceName [lindex $headers [expr $i+1]]
                                    set sequenceNamePriority 10
                                }
                                incr i 4
                            } elseif {$header == "ms2"} {
                                set optionCount [lindex $headers [expr $i+1]]
                                set options {}
                                for {set j 0} {$j < $optionCount} {incr j} {
                                    lappend options [lindex $headers [expr $i+2+$j]]
                                }
                                lappend sequenceSources [list $header $options]
                                if {$sequenceNamePriority < 11} {
                                    set sequenceName [lindex $options 0]
                                    set sequenceNamePriority 11
                                }
                                incr i [expr $optionCount+1]
                            }
                        }
                        
                        # If we don't have a name yet, use the last header.
                        if {$sequenceName == ""} {
                            set sequenceName [lindex $headers end]
                        }
                        
                        # Get the name mapping, if we have one.
                        if {[info exists nameMap($sequenceName)]} {
                            set sequenceName $nameMap($sequenceName)
                        }
                        
                        # Add the description.
                        lappend sequenceDescriptions $description
                    }
                }
                
            } else {
             
                # Otherwise this must be a part of the sequence data, so append it to the data.
                set sequenceData [concat $sequenceData [split [string toupper $line] {}]]
            }
             
            # If there are no more lines we are done.
            if {[eof $fp]} {
                
                # Save the last sequence we were reading and stop the loop.
                set sequenceID [SeqData::addSeq $sequenceData $sequenceName "N" 1 $sequenceSources]
                if {[llength sequenceDescriptions] > 0} {SeqData::addAnnotation $sequenceID description [lindex $sequenceDescriptions 0]}
                lappend sequenceIDList $sequenceID
                break
            }
        }
        
        # Close the file.
        close $fp
    
        # Return the list.    
        return $sequenceIDList
    }
    
    # Loads a series of sequences from a FASTA file into the sequence store.
    # arg:  sequences - The list of sequences ids that should be saved to the 
    #                       file. These ids should have come from the seqdata 
    #                       package.
    #       filename - The name of the file to load.
    #       names - An optional list of strings to use to override the sequence names.
    #       descriptions - An optional list of strings to use to override the sequence descriptions.
    proc saveSequences {sequences filename {names {}} {descriptions {}} {includeSources 1} {includeGaps 1}} {
        
        # Open the file.
        set fp [open $filename w]
        
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequences]} {incr i} {
            
            # Get the sequence.
            set sequenceID [lindex $sequences $i]

            # Get the sequence name.            
            set sequenceName [SeqData::getName $sequenceID]
            if {$i < [llength $names]} {
                set sequenceName [lindex $names $i]
            }
            
            # Get the sequence soruces.
            set sequenceSources ""
            if {$includeSources} {
                if {[llength [::SeqData::getSources $sequenceID]] > 0} {
                    foreach sequenceSource [::SeqData::getSources $sequenceID] {
                        if {[lindex $sequenceSource 0] == "ms2"} {
                            append sequenceSources [lindex $sequenceSource 0] "|" [llength [lindex $sequenceSource 1]] "|" [join [lindex $sequenceSource 1] "|"] "|"
                        } else {
                            append sequenceSources [lindex $sequenceSource 0] "|" [join [lindex $sequenceSource 1] "|"] "|"
                        }
                    }
                }
            }
                            
            # Get the sequence descripion.
            if { [catch {SeqData::getAnnotation $sequenceID description} desc] } {
                set sequenceDescription ""
            } else {
                set sequenceDescription $desc
            }
            if {$i < [llength $descriptions]} {
                set sequenceDescription [lindex $descriptions $i]
            }
            if {$sequenceDescription != ""} {
                set sequenceDescription " $sequenceDescription"
            }
            
            # Make sure the description doesn't contain any newlines.
            regsub -all {\n} $sequenceDescription " " sequenceDescription
            
            # Get the sequence data.
            set sequenceData [SeqData::getSeq $sequenceID]
    
            # Write the header line.
            puts $fp ">$sequenceSources$sequenceName$sequenceDescription"
            
            # Write the sequence data, limiting the line length to 80.
            set elementsWritten 0
            foreach element $sequenceData {
                if {$element != "-" || $includeGaps} {
                    if {$elementsWritten >= 60} {
                        puts $fp ""
                        set elementsWritten 0
                    }
                    puts -nonewline $fp $element
                    incr elementsWritten
                }
            }
            
            #Write out a trailing newline.
            puts $fp ""
        }
        
        # Close the file.
        close $fp
    }
    
    proc getFastaData {sequences {names {}} {descriptions {}} {includeSources 1} {includeGaps 1}} {
        
        set fastaData ""
        
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequences]} {incr i} {
            
            # Get the sequence.
            set sequenceID [lindex $sequences $i]

            # Get the sequence name.            
            set sequenceName [SeqData::getName $sequenceID]
            if {$i < [llength $names]} {
                set sequenceName [lindex $names $i]
            }
            
            # Get the sequence sources.
            set sequenceSources ""
            if {$includeSources} {
                if {[llength [::SeqData::getSources $sequenceID]] > 0} {
                    foreach sequenceSource [::SeqData::getSources $sequenceID] {
                        if {[lindex $sequenceSource 0] == "ms2"} {
                            append sequenceSources [lindex $sequenceSource 0] "|" [llength [lindex $sequenceSource 1]] "|" [join [lindex $sequenceSource 1] "|"] "|"
                        } else {
                            append sequenceSources [lindex $sequenceSource 0] "|" [join [lindex $sequenceSource 1] "|"] "|"
                        }
                    }
                }
            }
                            
            # Get the sequence descripion.
            if { [catch {SeqData::getAnnotation $sequenceID description} desc] } {
                set sequenceDescription ""
            } else {
                set sequenceDescription $desc
            }
            if {$i < [llength $descriptions]} {
                set sequenceDescription [lindex $descriptions $i]
            }
            if {$sequenceDescription != ""} {
                set sequenceDescription " $sequenceDescription"
            }
            
            # Make sure the description doesn't contain any newlines.
            regsub -all {\n} $sequenceDescription " " sequenceDescription
            
            # Get the sequence data.
            set sequenceData [SeqData::getSeq $sequenceID]
    
            # Write the header line.
            append fastaData ">$sequenceSources$sequenceName$sequenceDescription\n"
            
            # Write the sequence data, limiting the line length to 80.
            set elementsWritten 0
            foreach element $sequenceData {
                if {$element != "-" || $includeGaps} {
                    if {$elementsWritten >= 60} {
                        append fastaData "\n"
                        set elementsWritten 0
                    }
                    append fastaData $element
                    incr elementsWritten
                }
            }
            
            # Append a trailing newline.
            append fastaData "\n"
        }
        
        return $fastaData
    }
    
    proc saveSecondaryStructure {sequencesIDs filename} {
        
        # Open the file.
        set fp [open $filename w]
        
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequencesIDs]} {incr i} {
            
            # Get the sequence.
            set sequenceID [lindex $sequencesIDs $i]

            # Get the sequence name.            
            set sequenceName [SeqData::getName $sequenceID]
            
            # Get the sequence data.
            set data [SeqData::getSecondaryStructure $sequenceID 1]
    
            # Write the header line.
            puts $fp ">$sequenceName"
            
            # Write the sequence data, limiting the line length to 80.
            set elementsWritten 0
            foreach element $data {
                if {$elementsWritten >= 60} {
                    puts $fp ""
                    set elementsWritten 0
                }
                puts -nonewline $fp $element
                incr elementsWritten
            }
            
            #Write out a trailing newline.
            puts $fp ""
        }
        
        # Close the file.
        close $fp
    }
}
