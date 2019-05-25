############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_je.tcl,v 1.3 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::JE {

    proc loadTreeFile {filename} {
        
        # Read in the file.
        set fp [open $filename r]
        set fileData [read $fp]
        close $fp
        
        # Get the name of the file.
        set name [file tail $filename]
        
        # Load the tree data.
        return [loadTreeData $name $fileData]
    }
    
    proc loadTreeData {name fileData} {
        
        # Get the tree.
        if {[regexp {^(\(.+\))\s+$} $fileData unused treeString]} {
            
            return [parseJETree $name $treeString]
            
        } elseif {[regexp {Tree\sString\:\s+(\(.+\))} $fileData unused treeString]} {
            
            # Create the tree.
            set treeID [parseJETree $name $treeString]
            
            # Get any distance matrix.
            if {[regexp {Initial\sdistance\smatrix\s+(.+)Step\s1} $fileData unused matrixString]} {
                ::PhyloTree::Data::setDistanceMatrix $treeID [parseDistanceMatrix $matrixString]
            }
            
            return $treeID
        }
        
        return ""
    }
    
    proc parseDistanceMatrix {matrixString} {
        
        set distanceMatrix {}
        set matrixLines [split $matrixString "\r\n"]
        set matrixColumnCount [llength [regexp -inline -all {\S+} [lindex $matrixLines 0]]]
        if {$matrixColumnCount > 0 && [llength $matrixLines] >= $matrixColumnCount} {
            for {set i 0} {$i < $matrixColumnCount} {incr i} {
                lappend distanceMatrix [concat $i [regexp -inline -all {\S+} [lindex $matrixLines $i]]]
            }
        }
        return $distanceMatrix
    }
    
    #( 0.27 ( 0.16 ( 0 2 )  ( 0 1 )  ) ( 0 0 )  )
    proc parseJETree {name tree} {
        
        # Tree of any root node wrappings.
        if {0} {
            return -code error "The specified data was not a valid JE tree."
        }
        
        # Create the tree.
        set treeID [::PhyloTree::Data::createTree $name]
        
        # Get the root node.
        set rootNode [::PhyloTree::Data::getTreeRootNode $treeID]
        
        # Get the tree as a list.
        set tree [regexp -inline -all {\S+} $tree]
        
        # Parse the child nodes.
        set distance [lindex $tree 1]
        set subtrees [extractJESubtrees $tree]
        foreach subtree $subtrees {
            parseJESubtree $treeID $rootNode $distance $subtree
        }
        
        return $treeID
    }
    
    proc parseJESubtree {treeID parentNode parentDistance subtree} {
        
        # Get the total distance from this node to the end of the branch.
        set distance [lindex $subtree 1]
    
        # Create the child node.
        set node [::PhyloTree::Data::addChildNode $treeID $parentNode [expr $parentDistance-$distance]]
            
        # See if the node is an internal node.
        if {![regexp {^0$} $distance]} {
            
            # Parse the child nodes.
            set childSubtrees [extractJESubtrees $subtree]
            foreach childSubtree $childSubtrees {
                parseJESubtree $treeID $node $distance $childSubtree
            }
            
        # Otherwise this must be a leaf node.
        } else {
            
            # This is a leaf node, so use the label as the name.
            ::PhyloTree::Data::setNodeName $treeID $node [lindex $subtree 2]
        }
    }
    
    proc extractJESubtrees {list} {
        
        set subtrees {}
        
        set depth 0
        set subtreeStartIndex -1
        for {set i 0} {$i < [llength $list]} {incr i} {
            set s [lindex $list $i]
            if {$s == "("} {
                if {$depth == 1} {
                    set subtreeStartIndex $i
                }
                incr depth
            } elseif {$s == ")"} {
                incr depth -1
                if {$depth == 1 && $subtreeStartIndex != -1} {
                    lappend subtrees [lrange $list $subtreeStartIndex $i]
                }
            }
        }
        
        return $subtrees
    }
}

