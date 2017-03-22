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
namespace eval ::SeqData::PDB {

    # Export the package namespace.
    namespace export getSwissProtName
    
    # The map of Swisprot organism identification codes
    variable swissProtMap

    proc isValidPDBName {sequenceName} {
        
        set pdbCode ""
        if {[regexp {^([[:digit:]][[:alnum:]]{3})$} $sequenceName unused pdbCode] == 1 ||
            [regexp {^([[:digit:]][[:alnum:]]{3})\_[[:alnum:]]?$} $sequenceName unused pdbCode] == 1 ||
            [regexp {^([[:digit:]][[:alnum:]]{3})[\-\.]} $sequenceName unused pdbCode] == 1} {
            return $pdbCode
        } else {
            return ""
        }
    }
    
    # Gets the Swiss-Prot code that corresponds to this PDB entry.
    # args:     sequenceName - The name of the sequence.
    # return:   The Swiss-Prot name or an empty string ("") if the name is not known.
    proc getSwissProtName {pdbCode} {
    
        # Import global variables.
        variable swissProtMap
    
        # If the index has not yet been loaded, load them.
        if {[array exists swissProtMap] != 1} {
            loadSwissProtMap
        }
        
        # Use the first four characters as the PDB code.
        if {[string length $pdbCode] >= 4} {
            
            set pdbCode [string toupper [string range $pdbCode 0 3]]
            
            # If this code is in the map, return the Swiss-Prot name.
            if {[info exists swissProtMap($pdbCode)] != 0} {
                return $swissProtMap($pdbCode)
            }
        }
        
        # The code could not be found, so return an empty string.
        return ""
    }
    
    proc isSwissProtPdbName {swissProtName} {
        
        # Import global variables.
        variable swissProtMap
        
        # If the index has not yet been loaded, load them.
        if {[array exists swissProtMap] != 1} {
            loadSwissProtMap
        }
        
        # If this code is in the map, return the PDB code.
        if {[info exists swissProtMap([string toupper $swissProtName])]} {
            return 1
        }
        return 0
    }
    
    proc getPdbCodeForSwissProtName {swissProtName} {
        
        # Import global variables.
        variable swissProtMap
    
        # If the index has not yet been loaded, load them.
        if {[array exists swissProtMap] != 1} {
            loadSwissProtMap
        }
        
        set swissProtName [string toupper $swissProtName]
            
        # If this code is in the map, return the PDB code.
        if {[info exists swissProtMap($swissProtName)] != 0} {
            return $swissProtMap($swissProtName)
        }
        
        # The code could not be found, so return an empty string.
        return ""
    }
    
    # Loads the Swiss-prot index.
    proc loadSwissProtMap {} {
    
        # Import global variables.
        variable swissProtMap
        
        # Reset the code map.
        array set swissProtMap {}
    
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "pdbtosp.txt"]]]} {
        
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
                
                    # Parse the line.
                    set fields [split $line " "]
                    if {[llength $fields] >= 2} {
                        
                        # Set the mapping.
                        set validFieldCount 0
                        foreach field $fields {
                            
                            # See if this is a real field.
                            if {$field != ""} {
                                incr validFieldCount
                                if {$validFieldCount == 3} {
                                    set swissProtMap([lindex $fields 0]) $field
                                    set swissProtMap($field) [lindex $fields 0]
                                    incr records
                                    break;
                                }
                            }
                        }
                    }
                }
                
                # If there are no more lines we are done.
                if {[eof $fp]} {break}
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.  
            puts "SeqData Info) Loaded PDB to SwissProt mapping from PDBTOSP.TXT: $records entries."
        }
    }
}
