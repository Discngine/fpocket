############################################################################
#cr
#cr            This scripts calculates the imbalance of a newick tree 
#                         using different metrics
#
#   Ref: Slatkin, M. and Kirkpatrick, M. Evolution,Vol47, 1171-1181 (1993)
#   Ref: Rogers, J. Systematic Biology Vol.45, 99-110 (1996)
############################################################################
#
# $Id: phylotree_analysis.tcl,v 1.2 2013/04/15 16:54:14 johns Exp $
#

package provide phylotree 1.1

namespace eval ::PhyloTree::Analysis {
    
    proc measureTreeBalance {args} {
        
        #Check usage
        if {[llength $args] < 1 || [llength $args] > 1} {
            puts "Here's how to use it:"
            puts "measureTreeBalance imputname.tre"
            puts "Where the imput tree must be in Newick format"
            error ""	
        }
        
        #Check if tree is in Newick format (Add)
        
        #Need to filter and make sure each node only has two chilren (Add)
        
        #Load tree file
        set treeID [::PhyloTree::Newick::loadTreeFile [lindex $args 0]]
    
        #Get root node
        set rootNode [::PhyloTree::Data::getTreeRootNode $treeID]
    
        #Generate a list of leaf nodes
        puts "The number of terminal taxa is [llength [::PhyloTree::Data::getLeafNodes $treeID $rootNode]]"
        
        #Generate a list of interior nodes
        #set interiorNodes [getInteriorNodes $treID $leafNodes $rootNode]
        #puts "The number of interior nodes are [llength $interiorNodes]"
    
        set NBarValues [calculateMeanBranchings $treeID]
        puts "N Bar               = [lindex $NBarValues 0]"
        puts "Sigma^2 N           = [lindex $NBarValues 1]"
        
        #set b2 [calculateB2 $treID $leafNodes $rootNode]
        #puts "B2 $b2"
        
        set Ic [calculateCollessIndex $treeID]
        puts "Colless' Index (Ic) = $Ic"
        
        #set Jindex [calculateJ $treID $leafNodes $interiorNodes]
        #puts "Jindex $Jindex"
    
    }
    
    proc calculateNbar {treeID} {
        
        # Get all of the branch counts
        set values [::PhyloTree::Data::getLeafBranchCounts $treeID]
        
        # Calculate the mean.
        set sum 0.0
        set count [llength $values]
        foreach value $values {
            set sum [expr $sum+$value]
        }
        set mean [expr $sum/double($count)]
    
        # Calculate the variance and standard deviation.
        set sum2 0.0
        foreach value $values {
            set sum2 [expr $sum2+(pow($value-$mean, 2))]
        }
        set variance [expr $sum2/(double($count))]
        
        return [list $mean $variance]
    }
    
    # Calculates Colless' index for a tree.
    proc calculateCollessIndex {treeID} {
        
        # Calculate the cumulative imbalance of the root node.
        set stats [getCumulativeImbalance $treeID [::PhyloTree::Data::getTreeRootNode $treeID]]
        set imbalance [lindex $stats 0]
        set n [lindex $stats 1]
        
        # Calculate normalization constant. Equivalent to (n-1)(n-2)/2.
        set norm [expr (($n*($n-3))+2)/2]
        
        return [expr double($imbalance)/double($norm)]
    }
    
    # Gets the cumulative imbalance of a node.
    #
    # Return: an array of length 2 containing the cumulative imbalance and the total number of leaf
    #         nodes descended from this node.
    proc getCumulativeImbalance {treeID node} {
        set childNodes [::PhyloTree::Data::getChildNodes $treeID $node]
        if {[llength $childNodes] == 0} {
            return {0 1}
        } elseif {[llength $childNodes] == 2} {
            set stats1 [getCumulativeImbalance $treeID [lindex $childNodes 0]]
            set I1 [lindex $stats1 0]
            set N1 [lindex $stats1 1]
            set stats2 [getCumulativeImbalance $treeID [lindex $childNodes 1]]
            set I2 [lindex $stats2 0]
            set N2 [lindex $stats2 1]
            return [list [expr $I1+$I2+abs($N1-$N2)] [expr $N1+$N2]]
        } else {
            error "Colless' Index can only be calculated for bifurcated trees."
        }
    }
    
    proc calculateB1 {treeID} {
        
        # Get all of the branch counts
        set values [getB1BranchCounts $treeID [::PhyloTree::Data::getTreeRootNode $treeID]]
        
        # Calculate the sum.
        set sum 0.0
        for {set i 0} {$i < [expr [llength $values]-1]} {incr i} {
            set value [lindex $values $i]
            if {$value > 0} {
                set sum [expr $sum+(1./$value)]
            }
        }
        
        return $sum
    }
    
    # Gets the cumulative imbalance of a node.
    #
    # Return: an array of length 2 containing the cumulative imbalance and the total number of leaf
    #         nodes descended from this node.
    proc getB1BranchCounts {treeID node} {
        set childNodes [::PhyloTree::Data::getChildNodes $treeID $node]
        if {[llength $childNodes] == 0} {
            return {0}
        } elseif {[llength $childNodes] == 2} {
            set l1 [getB1BranchCounts $treeID [lindex $childNodes 0]]
            set l2 [getB1BranchCounts $treeID [lindex $childNodes 1]]
            set c1 [lindex $l1 end]
            set c2 [lindex $l2 end]
            set cMax $c1
            if {$c2 > $cMax} {
                set cMax $c2
            }
            return [concat $l1 $l2 [expr $cMax+1]]
        } else {
            error "B1 can only be calculated for bifurcated trees."
        }
    }
    
    proc calculateB2 {tree leafsIn root} {
    
        
        set paths {}
        
        #Get paths for each leaf node from root
        for {set i 0} {$i < [expr [llength $leafsIn]]} {incr i} {
            
            set path [::PhyloTree::Data::getPathToDescendantNode $tree $root [lindex $leafsIn $i]]
            lappend paths $path
            
        }
        #puts "paths2 $paths"
    
        #Now add up all the path nodes calculate B2
        set sum 0
        foreach member $paths {
            set sum [expr $sum + double ([llength $member]-1)/double(pow(2,[llength $member]-1))]
        
        }
        
        #puts "sum2 $sum"
    
        return $sum
            
    }
    
    proc calculatePhylogeneticDiversity {treeID {node root}} {
        
        set pd 0.0
        
        if {$node == "root"} {
            set node [::PhyloTree::Data::getTreeRootNode $treeID]
        }
        
        set childNodes [::PhyloTree::Data::getChildNodes $treeID $node]
        if {$childNodes == {}} {
            return 0.0
        } else {
            foreach childNode $childNodes {
                set pd [expr $pd+[::PhyloTree::Data::getDistanceToParentNode $treeID $childNode]+[calculatePhylogeneticDiversity $treeID $childNode]]
            }
        }
        
        return $pd
    }
    
    proc calculateJ {tree leafsIn interNodes} {
        
        set nodeData {}
        #Get number of taxa that stem from each interior node
        for {set i 0} {$i < [expr [llength $interNodes]]} {incr i} {
            
            lappend nodeData [numberTaxa $tree [lindex $interNodes $i]]
        }
        
        set deltaForce 0
        
        foreach member $nodeData {
            if {[lindex $member 0] != [lindex $member 1]} {
                set deltaForce [expr $deltaForce + 1]
            }
        }
            
        #puts "nodeData $nodeData"
        #puts "J $deltaForce"
        
        #Calculate normalization constant
        set norm [expr [llength $leafsIn]-2]
        #puts "norm3 $norm"
        
        #Calculate Jindex
        set Jvalue [expr double($deltaForce)/double($norm)]
        
        return $Jvalue
        
    }
    
    proc getInteriorNodes {tree leafsIn root} {
    
        set paths {}
        
        for {set i 0} {$i < [expr [llength $leafsIn]]} {incr i} {
            
            set path [::PhyloTree::Data::getPathToDescendantNode $tree $root [lindex $leafsIn $i]]
            lappend paths $path
        }
        
        set newset {}
        foreach member $paths {
            
            for {set i 0} {$i < [expr [llength $member]-1]} {incr i} {
            
                lappend newset [lindex $member $i]
            }
        }
        
        set clean [lsort -unique -increasing $newset]
        #puts "clean $clean"
    
        return $clean	
    }
    
    #Given an interior node this procedure will determine the number of terminal taxa for the two child nodes
    proc numberTaxa {treid node} {
        
        set nodes [::PhyloTree::Data::getChildNodes $treid $node]
        set taxa {}
        for {set i 0} {$i < [expr [llength $nodes]]} {incr i} {
            lappend taxa [::PhyloTree::Data::getLeafNodes $treid [lindex $nodes $i]]
        }
        
        set theEnd {}
        foreach member $taxa {
            lappend theEnd [llength $member]
        }
    
        return $theEnd
    }
}

