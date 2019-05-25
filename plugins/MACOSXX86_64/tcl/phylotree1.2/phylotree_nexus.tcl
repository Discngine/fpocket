############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_nexus.tcl,v 1.3 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::Nexus {
    
    proc loadTreeFile {filename} {
        
        # Make sure it is really a nexus file.
        set fp [open $filename r]
        if {[gets $fp line] < 0 || $line != "#NEXUS"} {
            return -code error "The specified file was not a valid NEXUS file."
        }
        
        # Read in the file, discarding comments.
        set fileData ""
        set inComment 0
        while {![eof $fp] && [gets $fp line] >= 0} {

            # Add the newline back.
            append line "\n"
            
            # Process the line.
            while {[string length $line] > 0} { 
                set firstOpenBracket [string first "\[" $line]
                set firstCloseBracket [string first "\]" $line]
                if {!$inComment && $firstOpenBracket != -1 && $firstCloseBracket != -1} {
                    append fileData [string range $line 0 [expr $firstOpenBracket-1]] 
                    set line [string range $line [expr $firstCloseBracket+1] end] 
                } elseif {!$inComment && $firstOpenBracket != -1} {
                    append fileData [string range $line 0 [expr $firstOpenBracket-1]] 
                    set inComment 1
                    break
                } elseif {$inComment && $firstCloseBracket != -1} {
                    set line [string range $line [expr $firstCloseBracket+1] end] 
                    set inComment 0
                } elseif {$inComment} {
                    break
                } else {
                    append fileData $line
                    break
                }
            }
        }
        close $fp
        
        # Get the name of the file.
        set sourceName [file tail $filename]
        
        # Get any translation table.
        array set translationTable {}
        if {[regexp {translate\s+([^;]+);} $fileData unused tableString]} {
            foreach translationPair [regexp -inline -all {\s*\S+\s+[^,]+,?} $tableString] {
                if {[regexp {^\s*(\S+)\s+([^,]+),?\s*$} $translationPair unused key value]} {
                    set translationTable($key) $value
                }
            }
        }
        
        
        # Get all of the trees.
        set treesIDs {}
        set treeStrings [regexp -inline -all {tree\s+[^;]+;} $fileData]
        foreach treeString $treeStrings {
            if {[regexp {^tree\s+(\S+)\s*=\s*([^;]+;)} $treeString unused treeName newickData]} {
                
                # Create the tree.
                set treeID [::PhyloTree::Newick::parseNewickTree "$sourceName ([expr [llength $treesIDs]+1]:$treeName)" $newickData]
                
                # Replace any names from the translation table.
                foreach node [::PhyloTree::Data::getAllDescendantNodes $treeID [::PhyloTree::Data::getTreeRootNode $treeID]] {
                    set name [::PhyloTree::Data::getNodeName $treeID $node]
                    if {$name != "" && [info exists translationTable($name)]} {
                        ::PhyloTree::Data::setNodeName $treeID $node $translationTable($name)
                    }
                }
                
                # Add the tree to the list.
                lappend treesIDs $treeID
            }
        }
        
        return $treesIDs
    }
    
    proc saveTreeFile {filename treeIDs {includeInternalNodeLabels 1} {includeBranchLengths 1}} {
        
        # Read in the file.
        set fp [open $filename w]
        puts $fp "#NEXUS\n\n"
        puts $fp [generateNexusTreeBlock $treeIDs $includeInternalNodeLabels $includeBranchLengths]
        close $fp
    }
    
    proc generateNexusTreeBlock {treeIDs {includeInternalNodeLabels 1} {includeBranchLengths 1}} {
        
        set treeString "\[ID: None Available\]\nbegin trees;\n"
        
        for {set i 0} {$i < [llength $treeIDs]} {incr i} {
            set treeID [lindex $treeIDs $i]
            set name $i
            if {[regexp {\(([0-9]+)\)} [::PhyloTree::Data::getTreeName $treeID] unused newName]} {
                set name $newName
            } elseif {[regexp {\([0-9]+\:(\S+)\)} [::PhyloTree::Data::getTreeName $treeID] unused newName]} {
                set name $newName
            }
            append treeString "   tree $name = "
            append treeString [::PhyloTree::Newick::generateTreeString $treeID $includeInternalNodeLabels $includeBranchLengths]
            append treeString "\n"
        }
        append treeString "end;"
        return $treeString
    }
}
