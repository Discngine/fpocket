############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_data.tcl,v 1.5 2013/04/15 16:54:14 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::Data {
    
    # A list of the current trees.
    set treeIDs {}
    
    # The map storing the tree data.
    variable treeData
    array set treeData {}

# ---------------------------------------------------------------------
    # Resets the sequence data store.
    proc reset {} {
    
        variable treeIDs
        variable treeData
        
        # Reset the data structures.
        set treeIDs {}
        unset treeData
        array set treeData {}
    }
    
# ---------------------------------------------------------------------
    # Gets the next available tree id.
    # return:   The next available tree id.
    proc getNextTreeID {} {
    
        variable treeIDs
        
        # Loop through the currently used sequence ids and find the maximum value.
        set nextID 0
        foreach treeID $treeIDs {
            if {$treeID >= $nextID} {
                set nextID [expr $treeID+1]
            }
        }
        
        # Return the next id.
        return $nextID
    }

# ---------------------------------------------------------------------
    proc createTree {name} {
    
        variable treeIDs
        variable treeData
        
        # Get the next tree id and add it to the list of used ids.
        set treeID [getNextTreeID]
        lappend treeIDs $treeID
        
        # Set the sequence data.
        set treeData($treeID,name) $name
        set treeData($treeID,maxDistance) 0.0
        set treeData($treeID,nextNode) 1
        set treeData($treeID,attributeKeys) {}
        set treeData($treeID,distanceMatrix) {}
        set rootNode 0
        set treeData($treeID,root) $rootNode
        set treeData($treeID,$rootNode,parent) -1
        set treeData($treeID,$rootNode,children) {}
        set treeData($treeID,$rootNode,distanceToParent) 0.0
        set treeData($treeID,$rootNode,distanceToRoot) 0.0
        set treeData($treeID,$rootNode,name) ""
        set treeData($treeID,$rootNode,label) ""
        
        # Return the tree id.
        return $treeID
    }
    
# ---------------------------------------------------------------------
    proc deleteTree {treeID} {
        
        variable treeIDs
        variable treeData
        
        # Remove the id from the list of ids.
        set index [lsearch -exact $treeIDs $treeID]
        if {$index != -1} {
            set treeIDs [lreplace $treeIDs $index $index]
        }
        
        # Remove all keys from the array associated with the id.
        foreach keyName [array names treeData "$treeID,*"] {
            unset treeData($keyName)
        }
    }
    
# ---------------------------------------------------------------------
    proc getTreeName {treeID} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        return $treeData($treeID,name)
    }
    
# ---------------------------------------------------------------------
    proc getTreeRootNode {treeID} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        return $treeData($treeID,root)
    }
    
# ---------------------------------------------------------------------
    proc getTreeDistance {treeID} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        return $treeData($treeID,maxDistance)
    }
    
# ---------------------------------------------------------------------
    proc getTreeUnits {treeID} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        if {[info exists treeData($treeID,units)]} {
            return $treeData($treeID,units)
        }
        return ""
    }
    
# ---------------------------------------------------------------------
    proc setTreeUnits {treeID units} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        set treeData($treeID,units) $units
    }
    
# ---------------------------------------------------------------------
    proc getDistanceMatrix {treeID} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        return $treeData($treeID,distanceMatrix)
    }
    
# ---------------------------------------------------------------------
    proc setDistanceMatrix {treeID distanceMatrix} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)]} {
            return -code error "The specified tree ($treeID) does not exist."
        }
        
        set treeData($treeID,distanceMatrix) $distanceMatrix
    }
    
# ---------------------------------------------------------------------
    proc getTreeAttributeKeys {treeID} {
        
        variable treeData

        return $treeData($treeID,attributeKeys)
    }
    
# ---------------------------------------------------------------------
    proc getTreeAttributeValues {treeID attribute} {
        
        variable treeData

        return $treeData($treeID,$attribute,attributeValues)
    }
    
# ---------------------------------------------------------------------
    proc getNodeName {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        return $treeData($treeID,$node,name)
    }
    
# ---------------------------------------------------------------------
    proc getNodesByName {treeID name {node root}} {
        
        variable treeData
        
        # Use the root node, if no other was passed in as the starting node.
        if {$node == "root" && [info exists treeData($treeID,root)]} {
            set node $treeData($treeID,root)
        }

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }

        # If this node matches the name, add it to the list.
        set matchingNodes {}
        if {$treeData($treeID,$node,name) == $name} {
            lappend matchingNodes $node
        }
        
        # Append any children that match.
        foreach childNode $treeData($treeID,$node,children) {
            set matchingNodes [concat $matchingNodes [getNodesByName $treeID $name $childNode]]
        }
        return $matchingNodes            
    }
    
# ---------------------------------------------------------------------
    proc setNodeName {treeID node name} {
        
        variable treeData

#        puts "phylotree_data.  setting node $node to $name"
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        set treeData($treeID,$node,name) $name
    }
    
# ---------------------------------------------------------------------
    proc getNodeLabel {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        return $treeData($treeID,$node,label)
    }
    
# ---------------------------------------------------------------------
    proc setNodeLabel {treeID node label} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        set treeData($treeID,$node,label) $label
    }
    
# ---------------------------------------------------------------------
    proc getNodeAttribute {treeID node attribute} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        if {[info exists treeData($treeID,$node,attribute,$attribute)]} {
            return $treeData($treeID,$node,attribute,$attribute)
        }
        return ""
    }
    
# ---------------------------------------------------------------------
    proc setNodeAttribute {treeID node attribute value {valueList {}} {hidden 0}} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        # Set the attribute.
        set treeData($treeID,$node,attribute,$attribute) $value
        
        # Add this to the list of available attributes.
        if {!$hidden} {
            if {[lsearch $treeData($treeID,attributeKeys) $attribute] == -1} {
                lappend treeData($treeID,attributeKeys) $attribute
                set treeData($treeID,$attribute,attributeValues) {}
            }
            foreach valueListItem $valueList {
                if {[lsearch $treeData($treeID,$attribute,attributeValues) $valueListItem] == -1} {
                    lappend treeData($treeID,$attribute,attributeValues) $valueListItem
                }
            }
            if {$value != "" && [lsearch $treeData($treeID,$attribute,attributeValues) $value] == -1} {
                lappend treeData($treeID,$attribute,attributeValues) $value
            }
        }
    }
    
# ---------------------------------------------------------------------
    proc getParentNode {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        return $treeData($treeID,$node,parent)
    }
    
# ---------------------------------------------------------------------
    proc addChildNode {treeID parentNode {distanceToParent 1.0}} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
        
        # Get the node index.
        set node $treeData($treeID,nextNode)
        incr treeData($treeID,nextNode)

        # Create the node.
        lappend treeData($treeID,$parentNode,children) $node
        set treeData($treeID,$node,parent) $parentNode
        set treeData($treeID,$node,children) {}
        set treeData($treeID,$node,distanceToParent) [expr double($distanceToParent)]
        set treeData($treeID,$node,distanceToRoot) [expr $treeData($treeID,$parentNode,distanceToRoot)+$distanceToParent]
        if {$treeData($treeID,$node,distanceToRoot) > $treeData($treeID,maxDistance)} {
            set treeData($treeID,maxDistance) $treeData($treeID,$node,distanceToRoot)
        }
        set treeData($treeID,$node,name) ""
        set treeData($treeID,$node,label) ""
        
        return $node
    }
    
# ---------------------------------------------------------------------
    # Collapses a node by adding its children to its parent.
    proc removeNode {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        # Get the parent node.
        set parentNode $treeData($treeID,$node,parent)
        
        # Make sure this is not the root node.
        if {$parentNode != -1} {
            
            # Get some proeprties of this node.
            set distance $treeData($treeID,$node,distanceToParent)
            set parentIndex [lsearch -exact $treeData($treeID,$parentNode,children) $node]
            if {$parentIndex != -1} {
            
                # Move each of the child nodes into the parent.
                set childOffset 1
                foreach childNode $treeData($treeID,$node,children) {
                    set treeData($treeID,$parentNode,children) [linsert $treeData($treeID,$parentNode,children) [expr $parentIndex+$childOffset] $childNode]
                    set treeData($treeID,$childNode,parent) $parentNode
                    set treeData($treeID,$childNode,distanceToParent) [expr $treeData($treeID,$childNode,distanceToParent)+$distance]
                    set childOffset [expr $childOffset+1]
                }
                
                # Remove this node from the parent's child list.
                set treeData($treeID,$parentNode,children) [lreplace $treeData($treeID,$parentNode,children) $parentIndex $parentIndex]
            }
        }
    }
    
# ---------------------------------------------------------------------
    proc removeSubtree {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        # If this is not a leaf node, remove all of its leaf descendants instead.
        if {$treeData($treeID,$node,children) != {}} {
            set leafNodes [getLeafNodes $treeID $node]
            foreach leafNode $leafNodes {
                removeNode $treeID $leafNode
            }
            
        # Otherwise this must be a leaf node.
        } else {
            
            # Remove the node from the parent's child list.
            set parentNode $treeData($treeID,$node,parent)
            set index [lsearch -exact $treeData($treeID,$parentNode,children) $node]
            if {$index != -1} {
                set treeData($treeID,$parentNode,children) [lreplace $treeData($treeID,$parentNode,children) $index $index]
            }
            
            # Delete the node.
            foreach keyName [array names treeData "$treeID,$node,*"] {
                unset treeData($keyName)
            }
            
            # If the parent has only one child left, remove the parent node too.
            if {[llength $treeData($treeID,$parentNode,children)] == 1} {
                
                # Make sure the parent isn't the root node.
                if {$treeData($treeID,root) != $parentNode} {                
                    set grandparentNode $treeData($treeID,$parentNode,parent)
                    set siblingNode [lindex $treeData($treeID,$parentNode,children) 0]
                    
                    # Replace the parent node in the grandparent's child list.
                    set index [lsearch -exact $treeData($treeID,$grandparentNode,children) $parentNode]
                    if {$index != -1} {
                        set treeData($treeID,$grandparentNode,children) [lreplace $treeData($treeID,$grandparentNode,children) $index $index $siblingNode]
                    }
                    
                    # Replace the sibling node's parent.
                    set treeData($treeID,$siblingNode,parent) $grandparentNode
                    
                    # Adjust the remaining child's distance to parent.
                    set treeData($treeID,$siblingNode,distanceToParent) [expr $treeData($treeID,$parentNode,distanceToParent)+$treeData($treeID,$siblingNode,distanceToParent)]
                    
                    # Delete the parent node.
                    foreach keyName [array names treeData "$treeID,$parentNode,*"] {
                        unset treeData($keyName)
                    }
                    
                # Otherwise, we have to change the root.
                } else {
                    
                    # Get the sibling node.
                    set siblingNode [lindex $treeData($treeID,$parentNode,children) 0]
                    
                    # Set the sibling as the new root.
                    set treeData($treeID,root) $siblingNode
                    set treeData($treeID,$siblingNode,parent) -1
                    set treeData($treeID,$siblingNode,distanceToParent) 0.0
                    set treeData($treeID,$siblingNode,distanceToRoot) 0.0
                    
                    # Adjust the distance to root for the rest of the tree.
                    # TODO
                    
                    # Delete the old root node.
                    foreach keyName [array names treeData "$treeID,$parentNode,*"] {
                        unset treeData($keyName)
                    }
                }
            }            
        }
    }
    
# ---------------------------------------------------------------------
    proc getChildNodes {treeID parentNode} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
        
        return $treeData($treeID,$parentNode,children)
    }

# ---------------------------------------------------------------------
    proc getChildNodeCount {treeID parentNode} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
        
        return [llength $treeData($treeID,$parentNode,children)]
    }

# ---------------------------------------------------------------------
    
    proc rotateChildNodes {treeID parentNode {direction left}} {
        
        variable treeData
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
                
        if {$direction == "left"} {
            set children $treeData($treeID,$parentNode,children)
            set numChildren [llength $children]
            set newChildren [lrange $children 1 [expr $numChildren-1]]
            lappend newChildren [lindex $children 0]
            set treeData($treeID,$parentNode,children) $newChildren
        } elseif {$direction == "right"} {
            set children $treeData($treeID,$parentNode,children)
            set numChildren [llength $children]
            set newChildren [list [lindex $children [expr $numChildren-1]]]
            set newChildren [concat $newChildren [lrange $children 0 [expr $numChildren-2]]]
            set treeData($treeID,$parentNode,children) $newChildren
        }
    }
    
# ---------------------------------------------------------------------
    proc getLeafNodeCount {treeID {parentNode root}} {
        
        variable treeData

        # Use the root node, if no other was passed in as the starting node.
        if {$parentNode == "root" && [info exists treeData($treeID,root)]} {
            set parentNode $treeData($treeID,root)
        }
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
                
        if {$treeData($treeID,$parentNode,children) == {}} {
            return 1
        } else {
            set leafNodes 0
            foreach childNode $treeData($treeID,$parentNode,children) {
                incr leafNodes [getLeafNodeCount $treeID $childNode]
            }
            return $leafNodes            
        }
    }
    
# ---------------------------------------------------------------------
    proc getLeafNodes {treeID {parentNode root}} {
        
        variable treeData

        # Use the root node, if no other was passed in as the starting node.
        if {$parentNode == "root" && [info exists treeData($treeID,root)]} {
            set parentNode $treeData($treeID,root)
        }
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
                
        if {$treeData($treeID,$parentNode,children) == {}} {
            return $parentNode
        } else {
            set leafNodes {}
            foreach childNode $treeData($treeID,$parentNode,children) {
                set leafNodes [concat $leafNodes [getLeafNodes $treeID $childNode]]
            }
            return $leafNodes            
        }
    }
    
# ---------------------------------------------------------------------
    proc getLeafBranchCounts {treeID {parentNode root} {depth 0}} {
        
        variable treeData

        # Use the root node, if no other was passed in as the starting node.
        if {$parentNode == "root" && [info exists treeData($treeID,root)]} {
            set parentNode $treeData($treeID,root)
        }
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
                
        if {$treeData($treeID,$parentNode,children) == {}} {
            return $depth
        } else {
            set branchCounts {}
            foreach childNode $treeData($treeID,$parentNode,children) {
                set branchCounts [concat $branchCounts [getLeafBranchCounts $treeID $childNode [expr $depth+1]]]
            }
            return $branchCounts            
        }
    }
    
# ---------------------------------------------------------------------
    proc getDistanceToParentNode {treeID node} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        return $treeData($treeID,$node,distanceToParent)
    }
    
# ---------------------------------------------------------------------
    proc setDistanceToParentNode {treeID node distance} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        set treeData($treeID,$node,distanceToParent) $distance
    }
    
# ---------------------------------------------------------------------
    proc getDistanceToRootNode {treeID node} {

        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        return $treeData($treeID,$node,distanceToRoot)
    }
    
# ---------------------------------------------------------------------
    proc scaleBranchLengths {treeID scale {node root}} {
        
        variable treeData

        # Use the root node, if no other was passed in as the starting node.
        if {$node == "root" && [info exists treeData($treeID,root)]} {
            set node $treeData($treeID,root)
        }
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)]} {
            return -code error "The specified tree ($treeID) or node ($node) does not exist."
        }
        
        # Change our child distances and then process their children.
        foreach childNode $treeData($treeID,$node,children) {
            set treeData($treeID,$childNode,distanceToParent) [expr $scale*$treeData($treeID,$childNode,distanceToParent)]
            set treeData($treeID,$childNode,distanceToRoot) [expr $treeData($treeID,$node,distanceToRoot)+$treeData($treeID,$childNode,distanceToParent)]
            scaleBranchLengths $treeID $scale $childNode
        }
    }
    
# ---------------------------------------------------------------------
    proc isAncestorNode {treeID node ancestor} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)] || ![info exists treeData($treeID,$ancestor,name)]} {
            return -code error "The specified tree ($treeID) or node ($node,$ancestor) does not exist."
        }
                
        # If this node is the root node, return 0.
        if {$treeData($treeID,$node,parent) == -1} {
            return 0
        
        # If the two node are parent child, return 1.
        } elseif {$treeData($treeID,$node,parent) == $ancestor} {
            return 1
            
        # Otherwise, move up the tree.
        } else {
            return [isAncestorNode $treeID $treeData($treeID,$node,parent) $ancestor]
        }
    }
    
# ---------------------------------------------------------------------
    proc isDescendantNode {treeID node descendant} {
        
        return [isAncestorNode $treeID $descendant $node]
    }
    
# ---------------------------------------------------------------------
    proc getPathToAncestorNode {treeID node ancestor} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)] || ![info exists treeData($treeID,$ancestor,name)]} {
            return -code error "The specified tree ($treeID) or node ($node,$ancestor) does not exist."
        }
        
        # If this node is the root node, return an error.
        if {$treeData($treeID,$node,parent) == -1} {
            return -code error "In the specified tree ($treeID) the nodes ($node,$ancestor) are not in the same lineage."
        
        # If the two node are parent child, just return the two.
        } elseif {$treeData($treeID,$node,parent) == $ancestor} {
            return [list $node $ancestor]
            
        # Otherwise, move down the tree.
        } else {
            
            # Get our parent's path.
            set parentPath [getPathToAncestorNode $treeID $treeData($treeID,$node,parent) $ancestor]
            
            # If our parent had a path, use it, otherwise we have no path.
            if {$parentPath != {}} {
                return [linsert $parentPath 0 $node]
            } else {
                return {}
            }
        }
    }
    
# ---------------------------------------------------------------------
        
    proc getDistanceToAncestorNode {treeID node ancestor} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node,name)] || ![info exists treeData($treeID,$ancestor,name)]} {
            return -code error "The specified tree ($treeID) or node ($node,$ancestor) does not exist."
        }

        # Get the path from the node to the descendant.
        set path [getPathToAncestorNode $treeID $node $ancestor]
        
        # Add up the distances in the path.
        set distance 0.0
        for {set i 0} {$i < [expr [llength $path]-1]} {incr i} {
            set node [lindex $path $i]
            set distance [expr $distance+$treeData($treeID,$node,distanceToParent)]
        }
        
        return $distance
    }
    
# ---------------------------------------------------------------------
    proc getPathToDescendantNode {treeID node descendant} {
        
        # Get the reverse path and then reverse it.
        set path [getPathToAncestorNode $treeID $descendant $node]
        set reversePath {}
        for {set i [expr [llength $path]-1]} {$i >= 0} {incr i -1} {
            lappend reversePath [lindex $path $i]
        }
        return $reversePath
    }
        
# ---------------------------------------------------------------------
    proc getDistanceToDescendantNode {treeID node descendant} {
        
        return [getDistanceToAncestorNode $treeID $descendant $node]
    }
        
# ---------------------------------------------------------------------
    proc getPathBetweenNodes {treeID node1 node2} {
        
        variable treeData

        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$node1,name)] || ![info exists treeData($treeID,$node2,name)]} {
            return -code error "The specified tree ($treeID) or node ($node1,$node2) does not exist."
        }

        # See if one of the nodes is a descendant of the other.
        if {[isAncestorNode $treeID $node1 $node2]} {
            return [list [getPathToAncestorNode $treeID $node1 $node2] [list $node2]]
        } elseif {[isDescendantNode $treeID $node1 $node2]} {
            return [list [list $node1] [getPathToDescendantNode $treeID $node1 $node2]]
            
        # Find the path using a common ancestor.
        } else {
            
            # Move up the tree until we find a common ancestor.
            set commonAncestor {}
            set ancestor1 $treeData($treeID,$node1,parent)
            set ancestor2 $treeData($treeID,$node2,parent)
            while {$ancestor1 != -1 && $ancestor2 != -1} {
                if {[isAncestorNode $treeID $node1 $ancestor2]} {
                    set commonAncestor $ancestor2
                    break
                } elseif {[isAncestorNode $treeID $node2 $ancestor1]} {
                    set commonAncestor $ancestor1
                    break
                }
                set ancestor1 $treeData($treeID,$ancestor1,parent)
                set ancestor2 $treeData($treeID,$ancestor2,parent)
            }
            
            # If we found a common ancestor, find the path for it to both nodes.
            if {$commonAncestor != {}} {
                return [list [getPathToAncestorNode $treeID $node1 $commonAncestor] [getPathToDescendantNode $treeID $commonAncestor $node2]]
            } else {
                return -code error "In the specified tree ($treeID) the nodes ($node1,$node2) do not share a common ancestor."
            }
        }
    }
    
# ---------------------------------------------------------------------
    proc getDistanceBetweenNodes {treeID node1 node2} {

        set paths [getPathBetweenNodes $treeID $node1 $node2]
        set distance 0.0
        if {[llength [lindex $paths 0]] >= 2} {
            set distance [expr $distance+[getDistanceToAncestorNode $treeID [lindex [lindex $paths 0] 0] [lindex [lindex $paths 0] end]]]
        }
        if {[llength [lindex $paths 1]] >= 2} {
            set distance [expr $distance+[getDistanceToDescendantNode $treeID [lindex [lindex $paths 1] 0] [lindex [lindex $paths 1] end]]]
        }
        
        return $distance
    }
    
# ---------------------------------------------------------------------
    proc getAllDescendantNodes {treeID {parentNode root}} {
        
        variable treeData

        # Use the root node, if no other was passed in as the starting node.
        if {$parentNode == "root" && [info exists treeData($treeID,root)]} {
            set parentNode $treeData($treeID,root)
        }
        
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$parentNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($parentNode) does not exist."
        }
                
        set descendantNodes [list $parentNode]
        foreach childNode $treeData($treeID,$parentNode,children) {
            set descendantNodes [concat $descendantNodes [getAllDescendantNodes $treeID $childNode]]
        }
        return $descendantNodes            
    }
    
# ---------------------------------------------------------------------

    ############################################################################
    #
    # Reroots the tree at a given point
    #
    # Arguments:
    # 
    # treeID: ID number of the tree
    # childNode ID of the child node just after the selected point
    # distanceToChild: distance the point is before the child
    #
    proc reroot { treeID childNode {distanceToChild 0.0}} {

catch {
	if { $distanceToChild < 0 } { set distanceToChild 0.0 }
	
	variable treeData
	

	    
        # Make sure this is a real tree.
        if {![info exists treeData($treeID,root)] || ![info exists treeData($treeID,$childNode,name)]} {
            return -code error "The specified tree ($treeID) or node ($childNode) does not exist."
        }	    
 
	set parentNode [getParentNode $treeID $childNode]
	set childIndex [lsearch $treeData($treeID,$parentNode,children) $childNode]
	set treeData($treeID,$parentNode,children) [lreplace $treeData($treeID,$parentNode,children) $childIndex $childIndex]
	

	if { $distanceToChild > 0 } {
		set newRootID $treeData($treeID,nextNode)

		# Create the new root node by adding one to the existing tree
		
		set newRoot [addChildNode $treeID $parentNode [expr [getDistanceToParentNode $treeID $childNode] - $distanceToChild]]
		set newDist [expr [getDistanceToParentNode $treeID $childNode] - $distanceToChild]
		if { $newDist < 0 } {
			set newDist 0 
		}

		set treeData($treeID,$childNode,parent) $newRoot
		lappend treeData($treeID,$newRoot,children) $childNode

		
		set treeData($treeID,$childNode,distanceToParent) $distanceToChild
		set treeData($treeID,$childNode,distanceToRoot) $distanceToChild		

		set treeData($treeID,$newRoot,distanceToRoot) 0
		set treeData($treeID,$newRoot,distanceToParent) 0
		set treeData($treeID,$newRoot,parent) -1
		set newParent $newRoot
		set prevdist $newDist
		
		set grandparent [getParentNode $treeID $parentNode]
		
		
		# Now, reorganize the tree so that the parent of the proper node becomes its child
		
		# In this loop,
		# "parentNode" is the node that is being currently rotated
		# "newParent" is its child, which will become its parent as the tree is rotated
		# "grandparent" is the parent of "parentNode", which will in turn become its child, etc.
		
		if { $grandparent == -1 } {
			set childNodes [getChildNodes $treeID $parentNode]
			set treeData($treeID,$newParent,children) [lappend treeData($treeID,$newParent,children) $parentNode]
	
			set childIndex [lsearch $childNodes $newParent]

			set treeData($treeID,$parentNode,children) [lreplace $childNodes $childIndex $childIndex]
			
			set treeData($treeID,$parentNode,parent) $newParent
			set treeData($treeID,$parentNode,distanceToParent) $newDist
			set treeData($treeID,$parentNode,distanceToRoot) $newDist
			
		}
		while { $grandparent != -1 && $grandparent != ""} {

			set grandparent [getParentNode $treeID $parentNode]
			
			if { $grandparent == -1 } {
				set childNodes [getChildNodes $treeID $parentNode]
				set treeData($treeID,$newParent,children) [lappend treeData($treeID,$newParent,children) $parentNode]
			
				set childIndex [lsearch $childNodes $newParent]
				set treeData($treeID,$parentNode,children) [lreplace $childNodes $childIndex $childIndex]

				set treeData($treeID,$parentNode,parent) $newParent

				set treeData($treeID,$parentNode,distanceToParent) $prevdist				
			
			} else {
		
			set childNodes [getChildNodes $treeID $parentNode]
			set treeData($treeID,$newParent,children) [lappend treeData($treeID,$newParent,children) $parentNode]
			
			set childIndex [lsearch $childNodes $newParent]
			set treeData($treeID,$parentNode,children) [lreplace $childNodes $childIndex $childIndex]

			set currDist $prevdist
			set prevdist [getDistanceToParentNode $treeID $parentNode]
			set treeData($treeID,$parentNode,distanceToParent) $currDist
			set newDist $currDist
			set treeData($treeID,$parentNode,parent) $newParent
			
			
			set newParent $parentNode
			set parentNode $grandparent
			}			
		}
		

		set treeData($treeID,root) $newRoot
		set treeData($treeID,$newRoot,parent) -1
		
		
		# Recalculate distance to root for all nodes
		
		set children [getTreeRootNode $treeID]
		set maxDist 0

		while { $children != "" } {
			set newDist 0
			set child [lindex $children 0]
			set children [lreplace $children 0 0]
			set childNodes [getChildNodes $treeID $child]
			if { [llength $childNodes] == 1 } {

				set grandparent [getParentNode $treeID $child]
				set grandchild [lindex $childNodes 0]
				set treeData($treeID,$grandchild,distanceToParent) [expr [getDistanceToParentNode $treeID $grandchild] + [getDistanceToParentNode $treeID $child]]
				set treeData($treeID,$grandchild,distanceToRoot) [expr [getDistanceToParentNode $treeID $grandchild] + [getDistanceToRootNode $treeID $grandparent]]

				lappend children $grandchild
				
				# Replace the parent node in the grandparent's child list.
				set index [lsearch -exact $treeData($treeID,$grandparent,children) $child]
				if {$index != -1} {
					set treeData($treeID,$grandparent,children) [lreplace $treeData($treeID,$grandparent,children) $index $index $grandchild]
				}
                    
				# Replace the sibling node's parent.
				set treeData($treeID,$grandchild,parent) $grandparent
				
				# Delete the parent node.
				foreach keyName [array names treeData "$treeID,$child,*"] {
					unset treeData($keyName)
				}
			
			} else {
				
			foreach newChild $childNodes {
				lappend children $newChild
			}
			set parent [getParentNode $treeID $child] 
	
			if { $parent != -1 } {
				set newDist [expr [getDistanceToRootNode $treeID $parent] + [getDistanceToParentNode $treeID $child]]
			} else {
				set newDist 0
			}

			set treeData($treeID,$child,distanceToRoot) $newDist

			if { $newDist > $maxDist } {
				set maxDist $newDist
			}
			}
			
		}
		
		set treeData($treeID,maxDistance) $maxDist
		
	
	}
	
	::PhyloTree::Widget::redraw
    } foo
    }

# ---------------------------------------------------------------------
	
}
