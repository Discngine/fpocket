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
namespace eval ::SeqData::GenBank {

    # The map of Swisprot organism identification codes
    variable genBankMap

    # Index values for the taxonomy files.
    variable taxonomyNodeFileIndices
    
    # The number of record indices per file.
    variable indicesPerFile 800

    # Gets the taxonomy node for the organism of a sequence from the Swiss-prot index.
    # args:     sequenceName - The name of the sequence.
    # return:   The taxonomy node or an empty string if it is not known.
    proc getTaxonomyNode {genBankID} {
    
        # Import global variables.
        variable genBankMap
        
        # Make sure this is a valid GenBank identifier.
        if {[regexp -inline {[0-9]+} $genBankID] != $genBankID} {
            return ""
        }
    
        # If this node has not yet been loaded, load it.
        if {![info exists genBankMap($genBankID)]} {
            loadTaxonomyNode $genBankID
        }
            
        # See if we have a scientific name.
        if {[info exists genBankMap($genBankID,taxonomyNode)]} {
            return $genBankMap($genBankID,taxonomyNode)
        }
        
        # The name could not be found, so return an empty string.
        return ""
    }
    proc loadTaxonomyNode {genBankIDToLoad} {
    
        # Import global variables.
        global env
        variable genBankMap
        
        # If we don't have the file indices yet, build them.
        buildFileIndices
        
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "gi_taxid_prot.dmp"]]]} {
            
            # Mark the we have laoded this node.
            set genBankMap($genBankIDToLoad) $genBankIDToLoad
            
            # Open the nodes file.
            set fp [open $filename r]
            seek $fp [findNearestTaxonomyNodeFileLocation $genBankIDToLoad]
            
            # Scan through the lines until we find the node.
            while {![eof $fp]} {
                
                # Parse the line into its fields.
                set fields [regexp -inline -all -- {\S+} [gets $fp]]
                
                # Go through the fields and save them into the map.
                if {[llength $fields] >= 2} {
                    
                    # Get the node number.
                    set genBankID [lindex $fields 0]
                    
                    # See if this this the id we are looking for
                    if {$genBankID == $genBankIDToLoad} {
                
                        # Add the code to the map
                        set genBankMap($genBankID,taxonomyNode) [lindex $fields 1]
    
                    # Otherwise if we have passed the identifier, it must not be present.                    
                    } elseif {$genBankID > $genBankIDToLoad} {
                        break
                    }
                }
            }
            
            # Close the file.
            close $fp
        }
    }

    proc buildFileIndices {} {
    
        # Import global variables.
        global env
        variable taxonomyNodeFileIndices
        variable indicesPerFile
        
        # Only do this once.
        if {![info exists taxonomyNodeFileIndices]} {

            set datadir [::MultiSeqDialog::getDirectory "metadata"]
            if {$datadir != "" && [file exists [set filename [file join $datadir "gi_taxid_prot.dmp"]]]} {
                
                # Initialize the index.
                set taxonomyNodeFileIndices {}
                
                # Get the size of the file.
                set fileSize [file size $filename]
                
                # Open the nodes file.
                set fp [open $filename r]
                
                # Build the indices.
                while {![eof $fp]} {
                    
                    # Get the current file pointer location.
                    set location [tell $fp]
                    
                    # Get the node number.
                    set genBankID [lindex [regexp -inline -all -- {\S+} [gets $fp]] 0]
                    
                    # Add this node as an index.
                    lappend taxonomyNodeFileIndices [list $genBankID $location]
                    
                    # Move to the next location
                    seek $fp [expr int($fileSize/$indicesPerFile)] current
                    
                    # Read any remainder.
                    gets $fp
                }
                
                # Close the file.
                close $fp
                
                # Output an informational message.  
                puts "SeqData Info) Built NCBI GenBank identifier index."
            }
        }
    }
    
    proc findNearestTaxonomyNodeFileLocation {genBankID} {
    
        # Import global variables.
        variable taxonomyNodeFileIndices
        
        # Go through the index and find the nearest location.
        set lastLocation 0
        foreach taxonomyNodeFileIndex $taxonomyNodeFileIndices {
            if {[lindex $taxonomyNodeFileIndex 0] > $genBankID} {
                return $lastLocation
            } else {
                set lastLocation [lindex $taxonomyNodeFileIndex 1]
            }
        }
        
        return $lastLocation
    }
}
