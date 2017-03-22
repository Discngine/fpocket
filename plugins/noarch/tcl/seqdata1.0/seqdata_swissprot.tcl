############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for obtaining information about Swiss Prot sequences.

package provide seqdata 1.0
package require multiseqdialog 1.0

# Declare global variables for this package.
namespace eval ::SeqData::SwissProt {

    # Export the package namespace.
    namespace export getDomainOfLife
    
    # The map of Swisprot organism identification codes
    variable swissProtIndex
    
    # The list of all entries in Swiss-Prot
    variable swissProtEntries

    proc isValidSwissProtName {sequenceName} {
        
        if {[regexp {^[[:alnum:]]{1,5}_[[:alnum:]]{1,5}$} $sequenceName] == 1} {
            return 1
        } else {
            return 0
        }
    }
    
    # Gets the taxonomy node for the organism of a sequence from the Swiss-prot index.
    # args:     sequenceName - The name of the sequence.
    # return:   The taxonomy node or an empty string if it is not known.
    proc getTaxonomyNode {sequenceName} {
    
        # Import global variables.
        variable swissProtIndex
    
        # If the index has not yet been loaded, load them.
        if {[array exists swissProtIndex] != 1} {
            loadIndex
        }
        
        # Use after the first underscore as the organism code.
        set i [string first "_" $sequenceName]
        if {$i != -1} {
            
            # Parse out the code.
            set code [string toupper [string range $sequenceName [expr $i+1] [expr [string length $sequenceName]-1]]]
            
            # If this code is in the map, return the domain of life.
            if {[info exists swissProtIndex($code,taxonomyNode)] != 0} {
                
                return $swissProtIndex($code,taxonomyNode)
            }
        }
        
        # The code could not be found, so return an empty string.
        return ""
    }
    
    # Gets the enzyme commision number for the sequence.
    # args:     sequenceName - The name of the sequence.
    # return:   The EC number or an empty string if it is not known.
    proc getEnzymeCommisionNumber {sequenceName} {
    
        # Import global variables.
        variable swissProtIndex
    
        # If the index has not yet been loaded, load them.
        if {[array exists swissProtIndex] != 1} {
            loadIndex
        }
        
        # If this name is in the map, return the enzyme code.
        if {[info exists swissProtIndex($sequenceName,ecNumber)] != 0} {
            
            return $swissProtIndex($sequenceName,ecNumber)
        }
        
        # The name could not be found, so return an empty string.
        return ""
    }
    
    proc getEntries {prefix} {
        
        # Import global variables.
        variable swissProtEntries
        
        # If the index has not yet been loaded, load them.
        if {![array exists swissProtEntries]} {
            loadEntryIndex
        }
        
        if {[info exists swissProtEntries($prefix)]} {
            return $swissProtEntries($prefix)
        }
        
        return ""
    }
    
    proc loadIndex {} {
        loadSpeciesIndex
        loadEnzymeIndex
    }
    
    # Loads the Swiss-prot index.
    proc loadSpeciesIndex {} {
    
        # Import global variables.
        global env
        variable swissProtIndex
        
        # Reset the code map.
        array set swissProtIndex {}
    
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "speclist.txt"]]]} {
    
            # Open the file.
            set fp [open $filename r]
            
            # Read in all of the lines in the file.
            set records 0
            set readingCodes 0
            while {1} {
                
                # Read the next line.
                set line [gets $fp]
                
                # If we are not reading codes and the line starts with an '_', start reading codes.
                if {$readingCodes == 0 && [string index $line 0] == "_"} {
                    set readingCodes 1
                
                # If we are reading codes and the line starts with a '-', stop reading codes.
                } elseif {$readingCodes == 1 && [string index $line 0] == "-"} {
                    set readingCodes 0
                
                # If we are reading codes and the line starts with a real character, read the code.
                } elseif {$readingCodes == 1 && [string index $line 0] != " "} {
                
                    # Use up until the first space as the code.
                    set i [string first " " $line]
                    if {$i != -1} {
                        
                        # Parse out the code and domain of life.
                        set code [string range $line 0 [expr $i-1]]
                        set domain [string index $line 6]
                        set taxonomyNode [string trim [string range $line 8 13]]
                        
                        # Add the code to the map
                        set swissProtIndex($code,domain) $domain
                        set swissProtIndex($code,taxonomyNode) $taxonomyNode
                        incr records
                    }
                }
                
                # If there are no more lines we are done.
                if {[eof $fp]} {break}
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.  
            puts "SeqData Info) Loaded SwissProt organism codes from SPECLIST.TXT: $records entries."
        }
    }
    
    # Loads the Swiss-prot index.
    #ID   1.1.1.1
    #DE   Alcohol dehydrogenase.
    #AN   Aldehyde reductase.
    #CA   An alcohol + NAD(+) = an aldehyde or ketone + NADH.
    #CF   Zinc or Iron.
    #CC   -!- Acts on primary or secondary alcohols or hemiacetals.
    #CC   -!- The animal, but not the yeast, enzyme acts also on cyclic secondary
    #CC       alcohols.
    #PR   PROSITE; PDOC00058;
    #PR   PROSITE; PDOC00059;
    #PR   PROSITE; PDOC00060;
    #DR   P80222, ADH1_ALLMI ;  P49645, ADH1_APTAU ;  P06525, ADH1_ARATH ;
    proc loadEnzymeIndex {} {
    
        # Import global variables.
        global env
        variable swissProtIndex
        
        # Reset the code map.
        array set swissProtIndex {}
    
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "enzyme.dat"]]]} {
    
            # Open the file.
            set fp [open $filename r]
            
            # Read in all of the lines in the file.
            set records 0
            set ecNumber ""
            while {![eof $fp]} {
                
                # Read the next line.
                set line [gets $fp]
                if {$line != ""} {
                    
                    # See if this is an ec number line.
                    if {[regexp {^ID\s+(\S+)$} $line unused match1] == 1} {
                        set ecNumber $match1
                        
                    # See if this is a record line.
                    } elseif {$ecNumber != "" && [regexp {^DR(?:\s+\S+,\s*(\S+)\s*;)(?:\s+\S+,\s*(\S+)\s*;)?(?:\s+\S+,\s*(\S+)\s*;)?$} $line unused match1 match2 match3] == 1} {
                            
                        if {$match1 != ""} {
                            set swissProtIndex($match1,ecNumber) $ecNumber
                            incr records
                        }
                        if {$match2 != ""} {
                            set swissProtIndex($match2,ecNumber) $ecNumber
                            incr records
                        }
                        if {$match3 != ""} {
                            set swissProtIndex($match3,ecNumber) $ecNumber
                            incr records
                        }
                        
                    } elseif {$ecNumber != "" && [regexp {^DE\s+(\S.*)$} $line unused match1] == 1} {
                    
                        ::SeqData::Enzyme::addEnzyme $ecNumber $match1
                    }
                }
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.  
            puts "SeqData Info) Loaded SwissProt enzyme codes from ENZYME.DAT: $records entries."
        }
    }
    
    #AC      Entry
    #number  name(s)
    #______  ___________
    #O00016  YO051_YEAST
    #O00017  YO052_YEAST
    #O00019  VHS3_YEAST
    #O00022  YO059_YEAST
    #Q6S6P3  UL32_EHV1A, UL32_EHV1B
    #Q6S6P5  UL34_EHV1B, UL34_EHV1V
    proc loadEntryIndex {} {
    
        # Import global variables.
        global env
        variable swissProtEntries
        
        # Reset the code map.
        array set swissProtEntries {}
    
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "acindex.txt"]]]} {
    
            # Open the file.
            set fp [open $filename r]
            
            # Read in all of the lines in the file.
            set records 0
            set readingCodes 0
            while {![eof $fp]} {
                
                # Read the next line.
                set line [gets $fp]
                
                if {$line != ""} {
                    
                    # If we are not reading codes and the line starts with an '_', start reading codes.
                    if {$readingCodes == 0 && [string index $line 0] == "_"} {
                        set readingCodes 1
                    
                    # If we are reading codes and the line starts with a '-', stop reading codes.
                    } elseif {$readingCodes == 1 && [string index $line 0] == "-"} {
                        set readingCodes 0
                    
                    # If we are reading codes and the line starts with a real character, read the code.
                    } elseif {$readingCodes == 1 && [regexp {^\S+\s+(.+)$} $line unused entries]} {
                    
                        set entryList [regexp -inline -all {[^\s\,]+} $entries]
                        
                        # Use up until the first space as the code.
                        foreach entry $entryList {
                            
                            # Add the entry to the map.
                            if {[regexp {^([^\_]+)\_.+$} $entry unused enzyme]} {
                                if {[info exists swissProtEntries($enzyme)]} {
                                    if {[lsearch -exact $swissProtEntries($enzyme) $entry] == -1} {
                                        lappend swissProtEntries($enzyme) $entry
                                        incr records
                                    }
                                } else {
                                    set swissProtEntries($enzyme) [list $entry]
                                    incr records
                                }
                            }
                        }
                    }
                }
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.
            puts "SeqData Info) Loaded SwissProt entries from ACINDEX.TXT: $records entries."
        }
    }
}
