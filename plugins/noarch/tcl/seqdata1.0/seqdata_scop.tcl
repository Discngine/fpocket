############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This file provides functions for obtaining information about Swiss Prot sequences.

package provide seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqData::SCOP {

    # Export the package namespace.
    namespace export isValidSCOPName getSwissProtName
    
    # The map of scop data.
    variable scopData

    proc isValidSCOPName {sequenceName} {
        if {[regexp {^[dD][[:digit:]][[:alnum:]]{3}\w{2}$} $sequenceName] == 1 || [regexp {^[dD][[:digit:]][[:alnum:]]{3}\w{2}[\-\.]} $sequenceName] == 1} {
            return 1
        } else {
            return 0
        }
    }
    
    #a.1
    #a.1.1
    #a.1.1.1
    proc isValidSCOPIdentifier {identifier} {
        if {[regexp {^[[:alpha:]]\.[[:digit:]]{1,3}$} $identifier] == 1} {
            return 1
        } elseif {[regexp {^[[:alpha:]]\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}$} $identifier] == 1} {
            return 1
        } elseif {[regexp {^[[:alpha:]]\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}$} $identifier] == 1} {
            return 1
        } else {
            return 0
        }
    }
    
    # Gets the Swiss-Prot code that corresponds to this SCOP entry.
    # args:     sequenceName - The name of the sequence.
    # return:   The Swiss-Prot name or an empty string ("") if the name is not known.
    proc getSwissProtName {sequenceName} {
    
        # See if it is a valid name.
        if {[isValidSCOPName $sequenceName]} {
            
            # Convert to the PDB code and use the PDB library to find the Swiss-Prot code.
            return [::SeqData::PDB::getSwissProtName [string range $sequenceName 1 4]] 
        }
        
        # The code could not be found, so return an empty string.
        return ""
    }
    
    proc getStructureNamesForIdentifier {identifier {onePerSpecies 1}} {
        
        # Import global variables.
        variable scopData
        
        # Make sure the data is loaded.
        loadData
        
        # Get the node for the identifier.
        set ret {}
        set node [getNodeForIdentifier $identifier]
        if {$node != ""} {
            set nodes [getProteinRecords $node $onePerSpecies]
            foreach node $nodes {
                lappend ret $scopData($node,name)
            }
        }
        
        return $ret
    }
    
    proc getNodeForIdentifier {identifier {startingNode 0}} {
        
        # Import global variables.
        variable scopData
        
        # Make sure the data is loaded.
        loadData
        
        # Go through the tree and find the node that corresponds to the identifier.
        if {$scopData($startingNode,identifier) == $identifier} {
           return $startingNode
        } elseif {$scopData($startingNode,children) != {}} {
            foreach child $scopData($startingNode,children) {
                if {$scopData($child,identifier) == $identifier || [string first "$scopData($child,identifier)." $identifier] == 0} { 
                    return [getNodeForIdentifier $identifier $child]
                }
            }
        }
        
        return ""
    }
    
    proc getProteinRecords {startingNode {onePerSpecies 1}} {
        
        # Import global variables.
        variable scopData
        
        # Make sure the data is loaded.
        loadData
        
        # If this is a species node, add our children
        if {$scopData($startingNode,level) == "sp" && $scopData($startingNode,children) != {}} {
            if {$onePerSpecies} {
                return [lindex $scopData($startingNode,children) 0]
            } else {
                return $scopData($startingNode,children)
            }
        } elseif {$scopData($startingNode,children) != {}} {
            set ret {}
            foreach child $scopData($startingNode,children) {
                set ret [concat $ret [getProteinRecords $child $onePerSpecies]]
            }
            return $ret
        }
        
        return {}
    }
    
    proc loadData {} {
    
        # Import global variables.
        variable scopData
        
        if {![info exists scopData]} {
            
            # Load the scop data.
            array set scopData {}
            loadHierarchy
            loadDescriptions
        }
    }
    
    # Loads the Swiss-prot index.
    ## Copyright (c) 1994-2005 the scop authors; see http://scop.mrc-lmb.cam.ac.uk/scop/lic/copy.html
    #0	-	46456,48724,51349,53931,56572,56835,56992,57942,58117,58231,58788
    #46456	0	46457,46556,63445,63450,109639,46625,46688,81602,46928,81297,46954,46965,46996,47004,47013,47026,47039,47044,47049,47054,47059,47071,63500,47076,47081,47089,47094,47112,47143,81729,47161,63519,47239,47265,47322,47335,47363,47379,47390,89042,47395,47400,47405,47412,47445,47453,47458,47472,47575,47586,47591,81766,47597,47615,47643,101214,47654,47667,89063,47680,63561,101223,89068,47685,47693,81777,81782,47698,47718,69035,47723,47728,47740,47751,63569,47756,101232,47761,81789,101237,109853,109858,47768,47835,101256,47851,47856,101261,109879,109884,47861,47873,47894,47911,47916,47927,47932,47937,47942,47953,69059,69064,47972,48018,81632,69069,89081,109904,109909,109914,109919,101277,47978,69074,101282,101287,109924,47985,48007,48012,101306,48023,101311,48033,48044,101316,48049,48055,48064,48075,81821,81826,48080,101321,48091,48096,81831,74747,101326,101331,48107,48112,48139,89094,109603,101343,48144,48149,48162,101352,48167,81836,48172,48178,48200,48207,48255,48263,63591,48299,48304,48309,48316,81871,81877,81274,88945,48333,81885,101385,101390,89123,48339,48344,101398,48349,48365,63599,81890,48370,48483,48492,48497,81384,81385,48507,48536,109992,109997,110003,110008,110013,110018,48551,48556,101446,48575,48591,89154,48599,48607,48612,69117,81922,81929,101472,101477,89161,81934,48618,48646,48651,110034,48656,69124,101488,48661,48694
    #46457	46456	46458,46548
    #46458	46457	46459,74660,46463,46532
    #46459	46458	46460
    #46460	46459	46461,46462,81667,63437,88965
    #46461	46460	14982,100068
    #14982	46461	-
    proc loadHierarchy {} {
    
        # Import global variables.
        global env
        variable scopData
        
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [set filename [lindex [glob -nocomplain [file join $datadir "dir.hie.scop.txt_*"]] 0]] != "" && [file exists $filename]} {
    
            # Open the file.
            set fp [open $filename r]
            
            # Read in all of the lines in the file.
            set records 0
            while {1} {
                
                # Read the next line.
                set line [gets $fp]
                
                # If the line doesn't start with a #, process it.
                if {[string index $line 0] != "#"} {
                    
                    # Break the line up.
                    set columns [split $line]
                
                    if {[llength $columns] == 3} {
                        
                        set node [lindex $columns 0]
                        set parentNode [lindex $columns 1]
                        if {$parentNode == "-"} {
                            set parentNode ""
                        }
                        set childNodes [split [lindex $columns 2] ","]
                        if {[llength $childNodes] == 1 && [lindex $childNodes 0] == "-"} {
                            set childNodes {}
                        }
                        
                        # Add the data to the map.
                        set scopData($node,parent) $parentNode
                        set scopData($node,children) $childNodes
                        set scopData($node,level) ""
                        set scopData($node,identifier) ""
                        set scopData($node,name) ""
                        set scopData($node,description) ""
                        incr records
                    }
                }
                
                # If there are no more lines we are done.
                if {[eof $fp]} {break}
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.  
            puts "SeqData Info) Loaded SCOP hierarchy: $records nodes."
        }
    }
    
    # Loads the SCOP descriptions.
    ## Copyright (c) 1994-2005 the scop authors; see http://scop.mrc-lmb.cam.ac.uk/scop/lic/copy.html
    #46456	cl	a	-	All alpha proteins
    #46457	cf	a.1	-	Globin-like
    #46458	sf	a.1.1	-	Globin-like
    #46459	fa	a.1.1.1	-	Truncated hemoglobin
    #46460	dm	a.1.1.1	-	Protozoan/bacterial hemoglobin
    #46461	sp	a.1.1.1	-	Ciliate (Paramecium caudatum)
    #14982	px	a.1.1.1	d1dlwa_	1dlw A:
    #100068	px	a.1.1.1	d1uvya_	1uvy A:
    proc loadDescriptions {} {
    
        # Import global variables.
        global env
        variable scopData
        
        # Get the location of the file
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [set filename [lindex [glob -nocomplain [file join $datadir "dir.des.scop.txt_*"]] 0]] != "" && [file exists $filename]} {
    
            # Open the file.
            set fp [open $filename r]
            
            # Read in all of the lines in the file.
            set records 0
            while {1} {
                
                # Read the next line.
                set line [gets $fp]
                
                # If the line doesn't start with a #, process it.
                if {[string index $line 0] != "#"} {
                    
                    # Break the line up.
                    set columns [split $line]
                
                    if {[llength $columns] >= 5} {
                        
                        set node [lindex $columns 0]
                        set level [lindex $columns 1]
                        set identifier [lindex $columns 2]
                        set name [lindex $columns 3]
                        if {$name == "-"} {
                            set name ""
                        }
                        set description [join [lrange $columns 4 end] " "]
                        
                        # Add the data to the map.
                        set scopData($node,level) $level
                        set scopData($node,identifier) $identifier
                        set scopData($node,name) $name
                        set scopData($node,description) $description
                        incr records
                    }
                }
                
                # If there are no more lines we are done.
                if {[eof $fp]} {break}
            }
            
            # Close the file.
            close $fp
        
            # Output an informational message.  
            puts "SeqData Info) Loaded SCOP descriptions: $records records."
        }
    }
}
