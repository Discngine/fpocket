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
namespace eval ::SeqData::Taxonomy {

    # The map of Swisprot organism identification codes
    variable nodeMap
    array set nodeMap {}
    variable speciesMap
    
    # Index values for the taxonomy files.
    variable nodeFileIndices
    variable nameFileIndices
    
    # The number of record indices per file.
    variable indicesPerFile 300

    # Gets the common name of an organism.
    # args:     taxonomyNode - The NCBI taxonomy node for the organism in question.
    # return:   The common name of the organism or an empty string if it is not known.
    proc getCommonName {taxonomyNode} {
    
        # Import global variables.
        variable nodeMap
        
        # If this node has not yet been loaded, load it.
        if {![info exists nodeMap($taxonomyNode)]} {
            loadNodeHierarchy $taxonomyNode
        }
    
        # See if we have a common name.
        if {[info exists nodeMap($taxonomyNode,common_name)]} {
            return $nodeMap($taxonomyNode,common_name)
        } elseif {[info exists nodeMap($taxonomyNode,genbank_common_name)]} {
            return $nodeMap($taxonomyNode,genbank_common_name)
        }
         
        # The name could not be found, so return an empty string.
        return ""
    }
    
    # Gets the scientific name of an organism.
    # args:     taxonomyNode - The NCBI taxonomy node for the organism in question.
    # return:   The scientific name of the organism or an empty string if it is not known.
    proc getScientificName {taxonomyNode} {
    
        # Import global variables.
        variable nodeMap
    
        # If this node has not yet been loaded, load it.
        if {![info exists nodeMap($taxonomyNode)]} {
            loadNodeHierarchy $taxonomyNode
        }
            
        # See if we have a scientific name.
        if {[info exists nodeMap($taxonomyNode,scientific_name)]} {
            return $nodeMap($taxonomyNode,scientific_name)
        }
        
        # The name could not be found, so return an empty string.
        return ""
    }
    
    # Gets the domain of life of an organism.
    # args:     taxonomyNode - The NCBI taxonomy node for the organism in question.
    # return:   A domain of life of the organism.
    proc getDomainOfLife {taxonomyNode} {
    
        # Import global variables.
        variable nodeMap
    
        # If this node has not yet been loaded, load it.
        if {![info exists nodeMap($taxonomyNode)]} {
            loadNodeHierarchy $taxonomyNode
        }
        
        # Make sure we have a parent node.
        if {[info exists nodeMap($taxonomyNode,parent)]} {
            
            # Start with out parent node.
            set parentNode $nodeMap($taxonomyNode,parent)
            
            # Search up the tree until we can't find any more valid nodes.
            while {$parentNode != $taxonomyNode && $parentNode != "" && [info exists nodeMap($parentNode)]} {
                
                # If our parent is the root of the tree, this must be the domain level node.
                if {$parentNode == 1 || $parentNode == 131567} {
                    if {[info exists nodeMap($taxonomyNode,scientific_name)]} {
                        return $nodeMap($taxonomyNode,scientific_name)
                    } else {
                        return ""
                    }
                }

                # Move one level up the tree.
                set taxonomyNode $parentNode                 
                set parentNode $nodeMap($taxonomyNode,parent)
            }
        }
        
        # The domain could not be found, so return an empty string.
        return ""
    }
    
    # Gets the lineage for an organism.
    # args:     taxonomyNode - The NCBI taxonomy node for the organism in question.
    # return:   A list containing the lineage of the organism.
    proc getLineage {taxonomyNode {showHidden 0} {includeRanks 0} {includeSelf 0}} {
    
        # Import global variables.
        variable nodeMap
        
        # If this node has not yet been loaded, load it.
        if {![info exists nodeMap($taxonomyNode)]} {
            loadNodeHierarchy $taxonomyNode
        }
        
        # Make sure we have a parent node.
        set lineage {}
        if {[info exists nodeMap($taxonomyNode,parent)]} {
            
            # Construct the lineage starting with either curent node or the parent node.
            if {$includeSelf} {
                set parentNode $taxonomyNode
                set taxonomyNode -1
            } else {
                set parentNode $nodeMap($taxonomyNode,parent)
            }
            
            # Search up the tree until we can't find any more valid nodes.
            while {$parentNode != $taxonomyNode && $parentNode != 1 && $parentNode != 131567 && [info exists nodeMap($parentNode)]} {
                
                # Insert the parent at the beginning of the list.
                if {!$nodeMap($parentNode,hidden) || $showHidden} {
                    if {$includeRanks} {
                        set lineage [linsert $lineage 0 [list $nodeMap($parentNode,scientific_name) $nodeMap($parentNode,rank)]]
                    } else {
                        set lineage [linsert $lineage 0 $nodeMap($parentNode,scientific_name)]
                    }
                }
                set taxonomyNode $parentNode
                set parentNode $nodeMap($taxonomyNode,parent)
            }
        }
        
        # Return the lineage.
        return $lineage
    }

    proc getLineageRank {taxonomyNode rank} {
    
        # Search the lineage for the specified rank.        
        set lineage [getLineage $taxonomyNode 1 1 1]
        foreach level $lineage {
            if {[lindex $level 1] == $rank} {
                return [lindex $level 0]
            }
        }
        
        return ""
    }
    
    #C.spAZ3_B1_Clostridium_sp._str._AZ3_B.1
    #Bor.hermsi_Borrelia_hermsii_str._M1001
    #Cas.ruddii.02_Carsonella_ruddii    
    proc findNodeBySpecies {name} {
        
        # Import global variables.
        variable speciesMap
        
        # Make sure the species map is loaded.
        loadSpeciesMap
        
        # See if we can identify the taxonomy node for this name.
        if {[info exists speciesMap($name)]} {
            return $speciesMap($name)
            
        # GENUS_SPECIES
        } elseif {[regexp {^([^\s\_]+)[\s\_]([^\s\_]+)} $name unused genus species] && [info exists speciesMap([join [concat $genus " " $species]])]} {
            return $speciesMap([join [concat $genus " " $species]])
            
        # XXXX_GENUS_SPECIES
        } elseif {[regexp {^[^\s\_]+[\s\_]([^\s\_]+)[\s\_]([^\s\_]+)} $name unused genus species] && [info exists speciesMap([join [concat $genus " " $species]])]} {
            return $speciesMap([join [concat $genus " " $species]])
            
        # XXXX_XXXX_GENUS_SPECIES
        } elseif {[regexp {^[^\s\_]+[\s\_][^\s\_]+[\s\_]([^\s\_]+)[\s\_]([^\s\_]+)} $name unused genus species] && [info exists speciesMap([join [concat $genus " " $species]])]} {
            return $speciesMap([join [concat $genus " " $species]])
        }
        
        return ""
    }
    
    #9	|	Buchnera aphidicola	|		|	scientific name	|
    #9	|	Buchnera aphidicola Munson et al. 1991	|		|	synonym	|
    proc loadSpeciesMap {} {
        
        # Import global variables.
        variable speciesMap
        
        if {![info exists speciesMap]} {
            
            #Initialize the map.
            array set speciesMap {}
            
            # Load the names from the taxonomy file.
            set datadir [::MultiSeqDialog::getDirectory "metadata"]
            if {$datadir != "" && [file exists [set filename [file join $datadir "names.dmp"]]]} {
            
                puts "SeqData Info) Building NCBI taxonomy name map."
                
                # Open the nodes file.
                set fp [open $filename r]
                
                # Scan through the lines until we find the node.
                set numberNamesLoaded 0
                while {![eof $fp]} {
                    
                    # Read the next line.
                    set line [gets $fp]
                    
                    # Parse the line into its fields.
                    set fields [split $line "|"]
                    
                    # Go through the fields and save them into the map.
                    if {[llength $fields] >= 4} {
                        
                        # Get the name.
                        set type [string trim [lindex $fields 3]]
                        
                        # See if this this a type we are looking for.
                        if {$type == "scientific name" || $type == "synonym" || $type == "genbank synonym" || $type == "misnomer" || $type == "misspelling" || $type == "equivalent name"} {
                            
                            # Add the code to the map
                            set node [string trim [lindex $fields 0]]
                            set name [string trim [lindex $fields 1]]
                            set speciesMap($name) $node
                            incr numberNamesLoaded
                        }
                    }
                }
                
                # Close the file.
                close $fp
                
                # Output an informational message.  
                puts "SeqData Info) Built NCBI taxonomy name map: $numberNamesLoaded entries."
            }
            
            # Load the names from the crw database file.
            set datadir [::MultiSeqDialog::getDirectory "metadata"]
            if {$datadir != "" && [file exists [set filename [file join $datadir "crwnames.dat"]]]} {
            
                # Open the nodes file.
                set fp [open $filename r]
                
                # Scan through the lines until we find the node.
                set numberNamesLoaded 0
                while {![eof $fp] && [gets $fp line] >= 0} {
                    if {[regexp {^\"([^\"]+)\"\,([0-9]+)} $line unused sequenceName taxonomyNode]} {
                        set speciesMap($sequenceName) $taxonomyNode
                        incr numberNamesLoaded
                    }
                }
                
                # Close the file.
                close $fp
                
                # Output an informational message.  
                puts "SeqData Info) Built CRW taxonomy name map: $numberNamesLoaded entries."
            }
        }
    }
    
    # Loads the Swiss-prot nodes index.
    #   nodes.dmp fields:
    #     tax_id					             -- node id in GenBank taxonomy database
    #     parent tax_id				             -- parent node id in GenBank taxonomy database
    #     rank					                 -- rank of this node (superkingdom, kingdom, ...) 
    #     embl code				                 -- locus-name prefix; not unique
    #     division id				             -- see division.dmp file
    #     inherited div flag  (1 or 0)		     -- 1 if node inherits division from parent
    #     genetic code id				         -- see gencode.dmp file
    #     inherited GC  flag  (1 or 0)		     -- 1 if node inherits genetic code from parent
    #     mitochondrial genetic code id		 -- see gencode.dmp file
    #     inherited MGC flag  (1 or 0)		     -- 1 if node inherits mitochondrial gencode from parent
    #     GenBank hidden flag (1 or 0)          -- 1 if name is suppressed in GenBank entry lineage
    #     hidden subtree root flag (1 or 0)     -- 1 if this subtree has no sequence data yet
    #     comments				                 -- free-text comments and citations
    #   names.dmp fields:
	#     tax_id					             -- the id of node associated with this name
	#     name_txt				                 -- name itself
	#     unique name				             -- the unique variant of this name if name not unique
	#     name class				             -- (synonym, common name, ...)
    proc loadNodeHierarchy {nodeToLoad} {
    
        # Import global variables.
        global env
        variable nodeMap
        
        # If we don't have the file indices yet, build them.
        buildFileIndices
        
        # Get the location of the file.
        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "nodes.dmp"]]]} {
        
            # Create a list of names to load.
            set namesToLoad {}
            
            # Open the nodes file.
            set fp [open $filename r]
            seek $fp [findNearestNodeFileLocation $nodeToLoad]
            
            # Scan through the lines until we find the node.
            set numberNodesLoaded 0
            while {![eof $fp]} {
                
                # Read the next line.
                set line [gets $fp]
                
                # Parse the line into its fields.
                set fields [split $line "|"]
                
                # Go through the fields and save them into the map.
                if {[llength $fields] >= 13} {
                    
                    # Get the node number.
                    set node [string trim [lindex $fields 0]]
                    
                    # See if this this a node we are looking for
                    if {$node == $nodeToLoad} {
                        
                        # Add the code to the map
                        set nodeMap($node) $node
                        set nodeMap($node,parent) [string trim [lindex $fields 1]]
                        set nodeMap($node,rank)   [string trim [lindex $fields 2]]
                        set nodeMap($node,hidden)   [string trim [lindex $fields 10]]
                        
                        # Increment the node count and add this node to the lsit of names to load.
                        lappend namesToLoad $node
                        incr numberNodesLoaded
                        
                        # If we don't have the parent node loaded, load it; otherwise we are done.
                        if {![info exists nodeMap($nodeMap($node,parent))]} {
                            set nodeToLoad $nodeMap($node,parent)
                            seek $fp [findNearestNodeFileLocation $nodeToLoad]
                        } else {
                            break
                        }
                        
                    # Otherwise, if we are past the node in question, there must not be one so we are done.
                    } elseif {$node > $nodeToLoad} {
                        break
                    }
                }
            }
            
            # Close the file.
            close $fp
        
            # Open the names file.
            set fp [open "$datadir/names.dmp" r]
            if {[llength $namesToLoad] > 0} {
                seek $fp [findNearestNameFileLocation [lindex $namesToLoad 0]]
            }
            
            # Read in all of the lines in the file.
            set numberNamesLoaded 0
            set currentNode ""
            while {[llength $namesToLoad] > 0} {
                
                # Read the next line.
                set line [gets $fp]
                
                # Parse the line into its fields.
                set fields [split $line "|"]
                
                # Go through the fields and save them into the map.
                if {[llength $fields] >= 4} {
                    
                    # Get the node number.
                    set node [string trim [lindex $fields 0]]
                    
                    # See if this is one of the names for the node that we are looking for.
                    if {$node == [lindex $namesToLoad 0]} {
                        
                        # Get the fields.
                        set nodeName [string trim [lindex $fields 1]]
                        set nameClass [string trim [lindex $fields 3]]
                        regsub -all " " $nameClass "_" nameClass
                                
                        # Add the name to the map
                        set nodeMap($node,$nameClass) $nodeName
                        
                        # Increment the node count.
                        incr numberNamesLoaded
                    
                    # Otherwise, if we are past the node in question, we must be finished with it.
                    } elseif {$node > [lindex $namesToLoad 0]} {
                        set namesToLoad [lreplace $namesToLoad 0 0]
                        if {[llength $namesToLoad] > 0} {
                            seek $fp [findNearestNameFileLocation [lindex $namesToLoad 0]]
                        }
                    }
                }
                
                # If we reach the end of the file, there must not be any names for this node.
                if {[eof $fp]} {
                    set namesToLoad [lreplace $namesToLoad 0 0]
                    if {[llength $namesToLoad] > 0} {
                        seek $fp [findNearestNameFileLocation [lindex $namesToLoad 0]]
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
        variable nodeFileIndices
        variable nameFileIndices
        variable indicesPerFile

        set datadir [::MultiSeqDialog::getDirectory "metadata"]
        if {$datadir != "" && [file exists [set filename [file join $datadir "nodes.dmp"]]]} {

            # Only do this once.
            if {![info exists nodeFileIndices]} {
    
                # Initialize the index.
                set nodeFileIndices {}
                
                # Get the size of the file.
                set fileSize [file size $filename]
                
                # Open the nodes file.
                set fp [open $filename r]
                
                # Build the indices.
                while {![eof $fp]} {
                    
                    # Get the current file pointer location.
                    set location [tell $fp]
                    
                    # Get the node number.
                    set node [string trim [lindex [split [gets $fp] "|"] 0]]
                    
                    # Add this node as an index.
                    lappend nodeFileIndices [list $node $location]
                    
                    # Move to the next location
                    seek $fp [expr int($fileSize/$indicesPerFile)] current
                    
                    # Read any remainder.
                    gets $fp
                }
                
                # Close the file.
                close $fp
                
                # Output an informational message.  
                puts "SeqData Info) Built NCBI taxonomy node index."
            }
            
            # Only do this once.
            if {![info exists nameFileIndices]} {
                
                # Initialize the index.
                set nameFileIndices {}
                
                # Get the size of the file.
                set fileSize [file size "$datadir/names.dmp"]
                
                # Open the nodes file.
                set fp [open "$datadir/names.dmp" r]
                
                # Build the indices.
                set lastNode ""
                while {![eof $fp]} {
                    
                    # Read until we have read the first line of a section.
                    while {![eof $fp]} {
                        
                        # Get the current file pointer location.
                        set location [tell $fp]
                        
                        # Get the node number.
                        set node [string trim [lindex [split [gets $fp] "|"] 0]]
                        
                        # See if this is the beginning of the file or a new section.
                        if {$location == 0 || ($lastNode != "" && $node != $lastNode)} {
                        
                            # Add this node as an index and move on.
                            lappend nameFileIndices [list $node $location]
                            break
                            
                        } else {
                            
                            # Save the node as the last node.
                            set lastNode $node
                        }
                    }
                    
                    # Move to the next location
                    seek $fp [expr int($fileSize/$indicesPerFile)] current
                    
                    # Read any remainder.
                    gets $fp
                    
                    # Reset the lsat node variable.
                    set lastNode ""
                }
                
                # Close the file.
                close $fp
                
                # Output an informational message.  
                puts "SeqData Info) Built NCBI taxonomy name index."
            }
        }
    }
    
    proc findNearestNodeFileLocation {node} {
    
        # Import global variables.
        variable nodeFileIndices
        
        # Go through the index and find the nearest location.
        set lastLocation 0
        foreach nodeFileIndex $nodeFileIndices {
            if {[lindex $nodeFileIndex 0] > $node} {
                return $lastLocation
            } else {
                set lastLocation [lindex $nodeFileIndex 1]
            }
        }
        
        return $lastLocation
    }
    
    proc findNearestNameFileLocation {node} {
    
        # Import global variables.
        variable nameFileIndices
        
        # Go through the index and find the nearest location.
        set lastLocation 0
        foreach nameFileIndex $nameFileIndices {
            if {[lindex $nameFileIndex 0] > $node} {
                return $lastLocation
            } else {
                set lastLocation [lindex $nameFileIndex 1]
            }
        }
        
        return $lastLocation
    }
}

