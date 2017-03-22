############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for obtaining information about Swiss Prot sequences.

package provide seqdata 1.0
package require http 2.4

# Declare global variables for this package.
namespace eval ::SeqData::Astral {

    # Export the package namespace.
    namespace export getSwissProtName
    
    # Saves the coordinates for the specified scop domain as the given file.
    proc saveStructure {scopDomain filename} {
        
        # Down the specified domain.
        set url [format "http://astral.berkeley.edu/pdbstyle.cgi?id=%s&output=text" $scopDomain] 
        puts "SeqData Info) Downloading SCOP domain from: $url"
        set fp [open $filename w]
        set connection [::http::geturl $url -channel $fp]
        ::http::cleanup $connection
        close $fp
    }
}
