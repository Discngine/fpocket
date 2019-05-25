############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_newick.tcl,v 1.4 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::Newick {
   
# ------------------------------------------------------------------------
    proc countTreesInFile {filename} {
        
        # Count the number of trees in the file.
        set fp [open $filename "r"]
        set count 0
        while {![eof $fp]} {
            set data [read $fp 512]
            incr count [llength [regexp -inline -all {;} $data]]
        }
        close $fp
        return $count
    }
    
# ------------------------------------------------------------------------
    proc loadTreeFile {filename {name ""}} {
        
        # Read in the file.
        set fp [open $filename r]
        set fileData [read $fp]
        close $fp
        
        # Get the name of the file.
        if {$name == ""} {
            set name [file tail $filename]
        }
        
        # Load the tree data.
        return [loadTreeData $name $fileData]
    }
    
# ------------------------------------------------------------------------
    proc readNextTreeFromFile {name fileId} {

        # Figure out the position of the tree in the file.
        set start [tell $fileId]
        set end $start
        while {![eof $fileId]} {
            set char [read $fileId 1]
            set end [tell $fileId]
            if {$char == ";"} {
                break
            }
        }
        
        # Load the tree data.
        seek $fileId $start
        set treeData [read $fileId [expr $end-$start+1]]
        return [loadTreeData $name $treeData]
    }
    
# ------------------------------------------------------------------------
   proc loadTreeData {name treeData} {
        
      set treesIDs {}

      # Split the trees on semicolons.
      set treeStrings [regexp -inline -all {[^;]+;\s*} $treeData]
      if {[llength $treeStrings] == 0} {
         set treeStrings [regexp -inline -all {[^;]+;\s*} "$treeData;"]
      }

      foreach treeString $treeStrings {
         if {[llength $treeStrings] == 1} {
            lappend treesIDs [parseNewickTree $name $treeString]
         } else {
            lappend treesIDs [parseNewickTree "$name ([expr [llength $treesIDs]+1])" $treeString]
         }
      }
        
      return $treesIDs
   }
    
# ------------------------------------------------------------------------
    proc parseNewickTree {name tree} {
        
        # Tree of any root node wrappings.
        if {![regexp {^\s*(\([^;]+);\s*$} $tree unused tree]} {
            return -code error "The specified data was not a valid Newick tree."
        }
        
        # Create the tree.
        set treeID [::PhyloTree::Data::createTree $name]
        
        # Extract the root node.
        set node [extractNewickNode $tree]
        set descendantList [lindex $node 0]
        set label [lindex $node 1]
        set distanceToParent [lindex $node 2]
        
        # Set the label.
        set rootNode [::PhyloTree::Data::getTreeRootNode $treeID]
        ::PhyloTree::Data::setNodeLabel $treeID $rootNode $label
        
        # Process the descendant list.
        set subtrees [extractNewickSubtrees $descendantList]
        foreach subtree $subtrees {
            parseNewickSubtree $treeID $rootNode $subtree
        }
        
        return $treeID
    }
    
# ------------------------------------------------------------------------
    proc parseNewickSubtree {treeID parentNode subtree} {

        # Extract the node.
        set node [extractNewickNode $subtree]
        set descendantList [lindex $node 0]
        set label [lindex $node 1]
        set distanceToParent [lindex $node 2]
        
        # Create the child node.
        set node [::PhyloTree::Data::addChildNode $treeID $parentNode $distanceToParent]
            
        # See if this is node has children.
        if {$descendantList != {}} {
            
            # This is an internal node, so use the label as the label.
            ::PhyloTree::Data::setNodeLabel $treeID $node $label
            
            # Parse the child nodes.
            foreach descendant [extractNewickSubtrees $descendantList] {
                parseNewickSubtree $treeID $node $descendant
            }
        } else {
            
            # This is a leaf node, so use the label as the name.
            ::PhyloTree::Data::setNodeName $treeID $node $label
        }
    }
    
# ------------------------------------------------------------------------
    proc extractNewickNode {subtree} {
        
        set node {}
        
        # Find where the descendant list starts and ends.
        for {set dlstart 0} {$dlstart < [string length $subtree]} {incr dlstart} {
            if {[string index $subtree $dlstart] == "("} {
                incr dlstart
                break
            }
        }
        for {set dlend [expr [string length $subtree]-1]} {$dlend >= 0} {incr dlend -1} {
            if {[string index $subtree $dlend] == ")"} {
                incr dlend -1
                break
            }
        }
        
        # If we had a decendant list, extract it.
        if {$dlstart < [string length $subtree] && $dlend >= 0} {
            lappend node [string trim [string range $subtree $dlstart $dlend]]
            set subtree [string trim [string range $subtree [expr $dlend+2] end]]
            
        # Otherwise this must be a leaf.
        } else {
            lappend node {}
            set subtree [string trim $subtree]
        }
        
        # Extract the label and length.
        set colonIndex [string first ":" $subtree]
        if {$colonIndex == 0} {
            lappend node ""            
            lappend node [string trim [string range $subtree 1 end]]
        } elseif {$colonIndex != -1} {
            lappend node [string trim [string range $subtree 0 [expr $colonIndex-1]]]
            lappend node [string trim [string range $subtree [expr $colonIndex+1] end]]
        } else {
            lappend node [string trim $subtree]
            lappend node 0.1
        }
        
        return $node
    }
    
# ------------------------------------------------------------------------
    proc extractNewickSubtrees {descendantList} {
        
        # Find the subtrees.
        set depth 0
        set commas {}
        for {set i 0} {$i < [string length $descendantList]} {incr i} {
            if {[string index $descendantList $i] == "("} {
                incr depth
            } elseif {[string index $descendantList $i] == ")"} {
                incr depth -1
            } elseif {[string index $descendantList $i] == "," && $depth == 0} {
                lappend commas $i
            }
        }
        
        # Extracts the subtrees.
        set start 0
        set subtrees {}
        foreach comma $commas {
            set end [expr $comma-1]
            lappend subtrees [string trim [string range $descendantList $start $end]]
            set start [expr $comma+1]
        }
        lappend subtrees [string trim [string range $descendantList $start [expr [string length $descendantList]-1]]]
        return $subtrees
    }

# ------------------------------------------------------------------------
    proc saveTreeFile {filename treeIDs {includeInternalNodeLabels 1} {includeBranchLengths 1}} {
        
        # Read in the file.
        set fp [open $filename w]
        foreach treeID $treeIDs {
            puts $fp [generateTreeString $treeID $includeInternalNodeLabels $includeBranchLengths]
        }
        close $fp
    }
    
# ------------------------------------------------------------------------
    proc generateTreeString {treeID {includeInternalNodeLabels 1} {includeBranchLengths 1}} {
        
        set rootNode [::PhyloTree::Data::getTreeRootNode $treeID]
        set childNodes [::PhyloTree::Data::getChildNodes $treeID $rootNode]
        set treeString "("
        for {set i 0} {$i < [llength $childNodes]} {incr i} {
            set childNode [lindex $childNodes $i]
            set childTreeString [generateSubtreeString $treeID $childNode $includeInternalNodeLabels $includeBranchLengths]
            if {$i != 0} {
                append treeString ","
            }
            append treeString $childTreeString
        }
        append treeString ")"
        set label [::PhyloTree::Data::getNodeLabel $treeID $rootNode]
        if {$includeInternalNodeLabels && $label != ""} {
            append treeString $label
        }
        append treeString ";"
        return $treeString
    }
    
# ------------------------------------------------------------------------
    proc generateSubtreeString {treeID node {includeInternalNodeLabels 1} {includeBranchLengths 1}} {
        
        # Get our children.
        set childNodes [::PhyloTree::Data::getChildNodes $treeID $node]
        
        # See if we have any children.
        if {$childNodes == {}} {
            
            # We don't, so just return the node.
            set treeString [::PhyloTree::Data::getNodeName $treeID $node]
            if {$includeBranchLengths} {
                append treeString ":"
                append treeString [::PhyloTree::Data::getDistanceToParentNode $treeID $node]
            }
            return $treeString
            
        # Otherwise, return the subtree.
        } else {
            
            set treeString "("
            for {set i 0} {$i < [llength $childNodes]} {incr i} {
                set childNode [lindex $childNodes $i]
                set childTreeString [generateSubtreeString $treeID $childNode $includeInternalNodeLabels $includeBranchLengths]
                if {$i != 0} {
                    append treeString ","
                }
                append treeString $childTreeString
            }
            append treeString ")"
            set label [::PhyloTree::Data::getNodeLabel $treeID $node]
            if {$includeInternalNodeLabels && $label != ""} {
                append treeString $label
            }
            if {$includeBranchLengths} {
                append treeString ":"
                append treeString [::PhyloTree::Data::getDistanceToParentNode $treeID $node]
            }
            return $treeString
        }
    }

# ------------------------------------------------------------------------
}
