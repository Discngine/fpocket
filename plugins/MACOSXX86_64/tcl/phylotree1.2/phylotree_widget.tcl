############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: phylotree_widget.tcl,v 1.5 2013/04/15 16:54:15 johns Exp $
#

package provide phylotree 1.1

# Declare global variables for this package.
namespace eval ::PhyloTree::Widget {
    
    # Export the package namespace.
    namespace export createWidget

    # Setup some default colors.
    variable labelColor "#D2D2D2"
    variable labelColorForeground "black"
    variable treeLineColor "black"
    variable nodeColor "black"
    variable selectedNodeColor "orange"
    variable selectedCellColor "#FFFF3E"
    variable qrOrderingColor "orange"
    variable cutoffLineColor "orange"
    variable treeGreyedColored "grey"
    variable backgroundColor "#FFFFFF"
    variable backgroundColoring "default"
    variable backgroundColors {"#74A0BF" "#DB838E" "#7BBF76" "#DCD483" "#D6A685" "#A075B3" "#C073A8" "#92CBC1"}
    variable leafColor "black"
    variable leafColoring "default"
    variable leafColors {"#18599F" "#DE1F26" "#336E36" "#DDD323" "#DB8426" "#9B27D8" "#D628AD" "#41C1B2"}                       
    variable leafColors {"#0000FF" "#FF0000" "#00AA00" "#FF8000" "#DDDD00" "#808033" "#FF9999" "#40BFBF" "#A600A6" "#80E566" "#804D00" "#8080BF" "#E0F705" "#8CE505" "#00E50A" "#00E580" "#00E0FF" "#00C2FF" "#0561AB" "#030AED" "#4500FA" "#7300E5" "#E500E5" "#FF00A8" "#FA003B" "#CF0000" "#E35900" "#F5B800"}
    variable rowsPerWedge 4
    variable wedgeBackgroundColor "#EEEEEE"
    variable selectedWedgeBackgroundColor "#F4EFA4"
    
    # The name of the widget.
    variable widget
    
    # The name of the tree portion of the widget.
    variable tree
    
    # The current width of the widget.
    variable width

    # The current height of the widget.
    variable height
    
    # The width of the current tree.
    variable treeWidth 0
    
    # The height of the current tree.
    variable treeHeight 0
    
    # Whether the orientation of the tree should be reversed.
    variable reverseOrientation 0
    
    # Whether internal node labels should be shown.
    variable showInternalLabels 1
    
    # Whether internal nodes should be shown.
    variable showInternalNodes 1
    
    # The id of the tree currently being shown.
    variable treeID -1
    
    # The scale at which to draw the tree.
    variable scale

    # The size of font to use.
    variable fontSize

    # The x border for the tree.    
    variable borderX 10
    
    # The y border for the tree.    
    variable borderY 10
    
    # The height of a row in the tree.
    variable rowHeight
    
    # The height of a text line in the tree.
    variable rowTextHeight
    
    # The width of the lines in the tree.
    variable lineWidth
    
    # The radius of internal nodes.
    variable internalNodeWidth
    
    # The radius of leaf nodes.
    variable leafNodeWidth
    
    # The radius of node hotspots
    variable nodeHotspotWidth
    
    # The font used for internal tree labels.
    variable internalLabelFont ""

    # The font used for leaf tree labels.
    variable leafLabelFont ""
    
    # The objects that make up the grid columns.
    variable canvasObjectMap
	array set canvasObjectMap {}
    
    # The selected nodes.
    variable selectedNodes {}
    
    # The collapsed nodes.
    variable collapsedNodes {}
    
    # The extra attributes being shown in leaf labels.
    variable shownAttributes
    array set shownAttributes {"name" 1 "Abbr. Species" 1}
    
    # The font used for QR labels.
    variable qrLabelFont ""

    variable cutoffLine
    variable cutoffMinX
    variable cutoffMaxX
	
    # The current selection notification command, if any.
    variable selectionNotificationCommands [list updateStatusBar]         
    variable treeChangeNotificationCommands [list updateStatusBar]
    
    variable nodePopupMenu {}
    
    # The text currently being displayed in the status bar.
    variable statusBarText ""
    
    # Selection spot
    variable selectedSpot
    variable selectedX
    variable selectedY
    variable selectedChild
    variable distanceToChild

    

    ############################## PUBLIC METHODS #################################
    # Methods in this section can be called by external applications.             #
    ###############################################################################
        
# -------------------------------------------------------------------    
    # Creates a new phylogenetic tree.
    # args:     a_control - The frame that the widget should be shown in.
    proc createWidget {a_widget a_scale a_fontSize} {
    
        variable widget
        variable tree
        variable width
        variable height
        variable backgroundColor
        variable nodePopupMenu
        set widget $a_widget 
    
        #Create the components of the widget.
        frame $widget.center
        set tree [canvas $widget.center.tree -background $backgroundColor -yscrollcommand "$widget.center.yscroll set" -xscrollcommand "$widget.bottom.xscroll set"]
        scrollbar $widget.center.yscroll -orient vertical -command "$tree yview"
        
        frame $widget.bottom
        scrollbar $widget.bottom.xscroll -orient horizontal -command "$tree xview"
        frame $widget.bottom.spacer -width [$widget.center.yscroll cget -width]
        label $widget.bottom.statusbar -textvariable "::PhyloTree::Widget::statusBarText" -anchor w -relief sunken -borderwidth 1
    
        pack $widget.center -side top -fill both -expand true
        pack $widget.center.tree -side left -fill both -expand true
        pack $widget.center.yscroll -side right -fill y
        pack $widget.bottom -side bottom -fill x
        pack $widget.bottom.spacer -side right
        pack $widget.bottom.xscroll -side top -fill x -expand true
        pack $widget.bottom.statusbar -side bottom -fill x -expand true
        
        # Listen for resize events.
        bind $tree <Configure> {::PhyloTree::Widget::component_configured %W %w %h}
        
        # Calculate some basic information about the tree.
        set width [$tree cget -width]
        set height [$tree cget -height]
        
        setScale $a_scale $a_fontSize 

        # Set the scrollbars.
        setScrollbars
        
        # Set the keyboard focus to the tree.
        focus $tree
        
        # Create the group popup menu.
        set nodePopupMenu0 [menu $widget.nodePopupMenu0 -title "Node Options" -tearoff no]
        $nodePopupMenu0 add command -label "Rotate Up" -command "::PhyloTree::Widget::menu_rotatenode left"
        $nodePopupMenu0 add command -label "Rotate Down" -command "::PhyloTree::Widget::menu_rotatenode right"
        $nodePopupMenu0 add command -label "Properties" -command "::PhyloTree::Widget::menu_nodeproperties"
        set nodePopupMenu1 [menu $widget.nodePopupMenu1 -title "Node Options" -tearoff no]
        $nodePopupMenu1 add command -label "Rotate Up" -command "::PhyloTree::Widget::menu_rotatenode left"
        $nodePopupMenu1 add command -label "Rotate Down" -command "::PhyloTree::Widget::menu_rotatenode right"
        $nodePopupMenu1 add command -label "Collapse/Expand" -command "::PhyloTree::Widget::menu_collapsenode"
        $nodePopupMenu1 add command -label "Remove" -command "::PhyloTree::Widget::menu_removenode"
        $nodePopupMenu1 add command -label "Properties" -command "::PhyloTree::Widget::menu_nodeproperties"
        set nodePopupMenu2 [menu $widget.nodePopupMenu2 -title "Node Options" -tearoff no]
        $nodePopupMenu2 add command -label "Collapse/Expand" -command "::PhyloTree::Widget::menu_collapsenode"
        $nodePopupMenu2 add command -label "Properties" -command "::PhyloTree::Widget::menu_nodeproperties"
        set nodePopupMenu3 [menu $widget.nodePopupMenu3 -title "Node Options" -tearoff no]
        $nodePopupMenu3 add command -label "Remove" -command "::PhyloTree::Widget::menu_removenode"
        $nodePopupMenu3 add command -label "Properties" -command "::PhyloTree::Widget::menu_nodeproperties"
        set nodePopupMenu [list $nodePopupMenu0 $nodePopupMenu1 $nodePopupMenu2 $nodePopupMenu3]
    }
    
# -------------------------------------------------------------------    
    # Adds a command to be run when the current selection has changed.
    # args:     command - The command to be executed whenever the selection has changed.
    proc addSelectionNotificationCommand {command} {
        
        variable selectionNotificationCommands
        
        set index [lsearch $selectionNotificationCommands $command]
        if {$index == -1} {
            lappend selectionNotificationCommands $command
        }
    }
    
# -------------------------------------------------------------------    
    proc removeSelectionNotificationCommand {command} {
        
        variable selectionNotificationCommands
        
        set index [lsearch $selectionNotificationCommands $command]
        if {$index != -1} {
            set selectionNotificationCommands [lreplace $selectionNotificationCommands $index $index]
        }
    }
    
# -------------------------------------------------------------------    
    # Adds a command to be run when the current tree has changed.
    # args:     command - The command to be executed whenever the tree has changed.
    proc addTreeChangeNotificationCommand {command} {
        
        variable treeChangeNotificationCommands
        
        set index [lsearch $treeChangeNotificationCommands $command]
        if {$index == -1} {
            lappend treeChangeNotificationCommands $command
        }
    }
    
# -------------------------------------------------------------------    
    proc removeTreeChangeNotificationCommand {command} {
        
        variable treeChangeNotificationCommands
        
        set index [lsearch $treeChangeNotificationCommands $command]
        if {$index != -1} {
            set treeChangeNotificationCommands [lreplace $treeChangeNotificationCommands $index $index]
        }
    }
    
# -------------------------------------------------------------------    
    proc setScale {newScale newFontSize} {
        
        variable tree
        variable scale
        variable fontSize
        variable rowHeight
        variable rowTextHeight
        variable lineWidth
        variable internalNodeWidth    
        variable leafNodeWidth
        variable nodeHotspotWidth
        variable internalLabelFont
        variable leafLabelFont
        variable qrLabelFont
        
        # Set the new scale.
        set scale $newScale
        set fontSize $newFontSize
        
        # Figure out the new font and row size.
        set fontChecker [$tree create text 0 0 -anchor nw -text ""]
        if {$internalLabelFont != ""} {font delete $internalLabelFont}
        if {$leafLabelFont != ""} {font delete $leafLabelFont}
        if {$qrLabelFont != ""} {font delete $qrLabelFont}        
        set defaultFont [$tree itemcget $fontChecker -font]
        set internalLabelFont [font create treeInternalLabelFont -family [font actual $defaultFont -family] -size [expr $fontSize-2]]
        set leafLabelFont [font create treeLeafLabelFont -family [font actual $defaultFont -family] -size [expr $fontSize]]
        set qrLabelFont [font create qrLabelFont -family [font actual $defaultFont -family] -size [expr $fontSize] -weight bold]
        set rowTextHeight [font metrics $leafLabelFont -linespace]
        set rowHeight [expr $rowTextHeight+(2*$fontSize/3)]
        $tree delete $fontChecker
        
        # Figure out the new line width
        set lineWidth [expr ($fontSize/13)+1]
        set internalNodeWidth [expr $lineWidth+1]
        set leafNodeWidth [expr $lineWidth*2]
        set nodeHotspotWidth [expr $leafNodeWidth+4]
        
        # Redraw the tree.
        redraw
    }
    
# -------------------------------------------------------------------    
    # Sets the tree that is being displayed by the widget as a Newick format tree.
    # args:     tree - The phylogenetic tree to display in Newick format.
    proc setTree {newTreeID} {
        
        variable treeID
        variable selectedNodes
        variable collapsedNodes
        
        # Set some variables.
        set treeID $newTreeID
        set selectedNodes {}
        set collapsedNodes {}
        
        redraw
    }
    
# -------------------------------------------------------------------    
    proc getBackgroundColor {} {
        
        variable backgroundColor
        
        return $backgroundColor
    }
    
# -------------------------------------------------------------------    
    proc setBackgroundColor {newColor} {
        
        variable backgroundColor
        variable backgroundColoring
        
        # Set the new color.
        set backgroundColor $newColor
        set backgroundColoring "default"
        
        redraw
    }
        
# -------------------------------------------------------------------    
    proc getLeafColor {} {
        
        variable leafColor
        
        return $leafColor
    }
    
# -------------------------------------------------------------------    
    proc setLeafColor {newColor} {
        
        variable leafColor
        variable leafColoring
        
        # Set the new color.
        set leafColor $newColor
        set leafColoring "default"
        
        redraw
    }
    
# -------------------------------------------------------------------    
    proc getSelectedNodes {} {
        
        variable selectedNodes

        return $selectedNodes            
    }

# --------------------------------------------------------------------------
   # Set the selection status of nodes in the tree.
   # args:  sequenceID - The id of the sequence to select.
   #        add - (default 0) If the sequence should be added to the selection.
   #        flip - (default 0) 1 if selection for sequence should be flipped.
   proc setSelectedNodes {nodes {add 0} {flip 0} {notifyListeners 1}} {
      variable tree
      variable selectedNodes
      variable nodeColor
      variable selectedNodeColor
      variable selectedCellColor
      variable canvasObjectMap
        
      # If we are performing a set selection, deselect everything else first.
      if {!$add && !$flip} {
            
         # Reset any selected nodes to be their default color.
         foreach node $selectedNodes {
            $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                                        -fill $canvasObjectMap($node,fillcolor)
            $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                                  -outline $canvasObjectMap($node,outlinecolor)
            if {[info exists canvasObjectMap($node,cellid)]} {
               $tree itemconfigure $canvasObjectMap($node,cellid) \
                                        -fill $canvasObjectMap($node,cellcolor)
               $tree itemconfigure $canvasObjectMap($node,cellid) \
                                     -outline $canvasObjectMap($node,cellcolor)
            }
         }
         set selectedNodes {}
      }
            
      # Go through all of the nodes.
      foreach node $nodes {
            
         # See if we are flipping off a node that is on.
         if {$flip} {
            set index [lsearch $selectedNodes $node]
            if {$index != -1} {
               set selectedNodes [lreplace $selectedNodes $index $index]
               $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                                        -fill $canvasObjectMap($node,fillcolor)
               $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                                  -outline $canvasObjectMap($node,outlinecolor)
               if {[info exists canvasObjectMap($node,cellid)]} {
                  $tree itemconfigure $canvasObjectMap($node,cellid) \
                                        -fill $canvasObjectMap($node,cellcolor)
                  $tree itemconfigure $canvasObjectMap($node,cellid) \
                                     -outline $canvasObjectMap($node,cellcolor)
               }
            } else {
               lappend selectedNodes $node
               $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                               -fill $canvasObjectMap($node,selectedfillcolor)
               $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                           -outline $canvasObjectMap($node,selectedoutlinecolor)
               if {[info exists canvasObjectMap($node,cellid)]} {
                  $tree itemconfigure $canvasObjectMap($node,cellid) \
                                                      -fill $selectedCellColor
                  $tree itemconfigure $canvasObjectMap($node,cellid) \
                                                   -outline $selectedCellColor
               }
            }
         } else {
            lappend selectedNodes $node
            $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                                 -fill $canvasObjectMap($node,selectedfillcolor)
            $tree itemconfigure $canvasObjectMap($node,nodeboxid) \
                           -outline $canvasObjectMap($node,selectedoutlinecolor)
            if {[info exists canvasObjectMap($node,cellid)]} {
               $tree itemconfigure $canvasObjectMap($node,cellid) \
                                                      -fill $selectedCellColor
               $tree itemconfigure $canvasObjectMap($node,cellid) \
                                                   -outline $selectedCellColor
            }
         }
      }
    
      # Notify any selection listeners.        
      if {$notifyListeners} {
         notifySelectionChangeListeners
      }
   } ;# end of setSelectedNodes
   
# ----------------------------------------------------------------------------
    proc setSelectedNodeRange {startNode endNode {notifyListeners 1}} {
        
        variable treeID
        
        # Get a list fo the leaf nodes.
        set leafNodes [::PhyloTree::Data::getLeafNodes $treeID [::PhyloTree::Data::getTreeRootNode $treeID]]
        
        # Select the nodes.
        set selecting 0
        set nodesToSelect {}
        foreach leafNode $leafNodes {
            
            if {!$selecting && ($leafNode == $startNode ||$leafNode == $endNode)} {
                lappend nodesToSelect $leafNode
                set selecting 1
            } elseif {$selecting && ($leafNode == $startNode ||$leafNode == $endNode)} {
                lappend nodesToSelect $leafNode
                setSelectedNodes $nodesToSelect 0 0 $notifyListeners
                break
            } elseif {$selecting} {
                lappend nodesToSelect $leafNode
            }
        }
    }
    
# -------------------------------------------------------------------    
    proc rotateNode {node direction} {
        
        variable treeID
        
        ::PhyloTree::Data::rotateChildNodes $treeID $node $direction
        redraw
    }
    
# -------------------------------------------------------------------    
    proc getCollapsedNodes {} {
        
        variable collapsedNodes

        return $collapsedNodes            
    }
    
# -------------------------------------------------------------------    
    proc isNodeCollapsed {node} {
        
        variable collapsedNodes
        
        if {[lsearch $collapsedNodes $node] == -1} {
            return 0
        }
        return 1
    }
        
# -------------------------------------------------------------------    
    proc setNodeCollapsed {node collapsed} {
        
        variable collapsedNodes
        
        set index [lsearch $collapsedNodes $node]
        if {$collapsed && $index == -1} {
            lappend collapsedNodes $node
            redraw
        } elseif {!$collapsed && $index != -1} {
            set collapsedNodes [lreplace $collapsedNodes $index $index]
            redraw
        }
    }
    
# -------------------------------------------------------------------    
    proc expandAllNodes {} {
        
        variable collapsedNodes
        
        # Remove any collapsed nodes.
        set collapsedNodes {}
        
        redraw
    }
    
# -------------------------------------------------------------------    
    proc collapseNodesByAttribute {attribute {node root}} {
        
        variable treeID
        variable treeData
        
        # If we are starting from the root, get the node.
        if {$node == "root"} {
            set node [::PhyloTree::Data::getTreeRootNode $treeID]
        }
        
        # If this is a leaf node, return.
        if {[::PhyloTree::Data::getChildNodeCount $treeID $node] == 0} {
            return
        }
        
        # See if all of out child leaf nodes have the same attribute.
        set collapse 1
        set sharedAttributeValue ""
        foreach leafNode [::PhyloTree::Data::getLeafNodes $treeID $node] {
            set attributeValue [::PhyloTree::Data::getNodeAttribute $treeID $leafNode $attribute]
            if {$sharedAttributeValue == "" && $attributeValue != ""} {
                set sharedAttributeValue $attributeValue
            } elseif {$attributeValue != $sharedAttributeValue || $attributeValue == ""} {
                set collapse 0
                break
            }
        }
        
        # If we are collapsing this node, we are done.
        if {$collapse} {
            
            # Set the node name.
            ::PhyloTree::Data::setNodeName $treeID $node $sharedAttributeValue
            
            # Collapse the node.
            setNodeCollapsed $node 1
            
        # Otherwise, check our children.
        } else {
            foreach childNode [::PhyloTree::Data::getChildNodes $treeID $node] {
                collapseNodesByAttribute $attribute $childNode
            }
        }
    }
    
# -------------------------------------------------------------------    
    proc showCutoffLine {distance} {

        variable tree
        variable treeID
        variable scale
        variable cutoffLine
        variable cutoffMinX
        variable cutoffMaxX
        
        set maxDistance [::PhyloTree::Data::getTreeDistance $treeID]
        if {$distance < 0.0} {
            set distance 0.0
        } elseif {$distance > $maxDistance} {
            set distance $maxDistance
        }
        
        $tree itemconfigure $cutoffLine -state normal
        set coords [$tree coords $cutoffLine]
        set newX [expr $cutoffMaxX-($distance*$scale)]
        $tree coords $cutoffLine [list $newX [lindex $coords 1] $newX [lindex $coords 3]]
    }
    
# -------------------------------------------------------------------    
    proc hideCutoffLine {} {

        variable tree
        variable cutoffLine
        
        $tree itemconfigure $cutoffLine -state hidden
    }
        
# -------------------------------------------------------------------    
    proc getNodesBelowThreshold {distance} {
        
        set nodesBelowThreshold {}
        
        set leafNodes [getLeafNodes]
        if {[llength $leafNodes] <= 30} {
            for {set i 0} {$i < [llength $leafNodes]} {incr i} {
                for {set j [expr $i+1]} {$j < [llength $leafNodes]} {incr j} {
                    set node1 [lindex $leafNodes $i]
                    set node2 [lindex $leafNodes $j]
                    
                    set paths [getPathBetweenNodes $node1 $node2]
                    set path1 [lindex $paths 0]
                    set path2 [lindex $paths 1]
                    set distance1 [getDistanceToDescendant [lindex $path1 0] [lindex $path1 end]]
                    set distance2 [getDistanceToDescendant [lindex $path2 0] [lindex $path2 end]] 
                    
                    if {[expr $distance1+$distance2] <= $distance} {
                        foreach node [concat $path1 $path2] {
                            if {[lsearch $nodesBelowThreshold $node] == -1} {
                                lappend nodesBelowThreshold $node
                            }
                        }
                    }
                }
            }
        }
        
        return $nodesBelowThreshold
    }
    
# -------------------------------------------------------------------    
    ############################# PRIVATE METHODS #################################
    # Methods in this section should only be called from this file.               #
    ###############################################################################
    
    # This method is called be the window manager when a component of the widget has been reconfigured.
    # args:     a_name - The name of the component that was reconfigured.
    #           a_width - The new width of the component.
    #           a_height - The new height of the component.
    proc component_configured {a_name a_width a_height} {
    
        variable tree
        variable width
        variable height
        
        # Check to see if the window is being resized.
        if {$a_name == $tree && ($a_width != $width || $a_height != $height)} {
        
            # Save the new width and height.
            set width $a_width
            set height $a_height
            setScrollbars
        }
    }

# --------------------------------------------------------------------------
    proc redraw {} {

        variable treeID
        
        # Delete any existing tree.
        deleteTreeObjects
            
        # Draw the tree.
        if {$treeID != -1} {
            drawTree       
        }

        # Set the scrollbars.        
        setScrollbars
        
        # Notify any tree change listeners.
        notifyTreeChangeListeners
    }
    
# --------------------------------------------------------------------------
    proc deleteTreeObjects {} {
        
        variable tree
        variable canvasObjectMap
        variable treeWidth
        variable treeHeight        
    
        # Get a list of all of the objects on the canvas.
        set objectNames [array names canvasObjectMap]
        
        # Delete each object.
        foreach objectName $objectNames {
            if {[string first "id" $objectName] != -1} {
                $tree delete $canvasObjectMap($objectName)
            }
        }
        
        set treeWidth 0
        set treeHeight 0
        array set canvasObjectMap {}
    }
    
# -------------------------------------------------------------------    
    proc calculateMaxLabelLength {} {
        
        variable treeID
        variable internalLabelFont
        variable leafLabelFont
        variable qrLabelFont
        variable canvasObjectMap
        
        # Figure out the maximum label length.
        set maxLabelLength 0
        set leafNodes [::PhyloTree::Data::getLeafNodes $treeID [::PhyloTree::Data::getTreeRootNode $treeID]]
        foreach leafNode $leafNodes {
            set labelLength [font measure $leafLabelFont [getLeafLabel $leafNode]+[font measure $qrLabelFont "888"]+10]
            if {$labelLength > $maxLabelLength} {
                set maxLabelLength $labelLength
            }
        }
        
        return $maxLabelLength
    }
    
# -------------------------------------------------------------------    
    proc getLeafLabel {node} {
        
        variable treeID
        variable shownAttributes
        
        set label ""
        if {[info exists shownAttributes(name)] && $shownAttributes(name) == 1} {
            set label [::PhyloTree::Data::getNodeName $treeID $node]
        }
        set allNodeAttributes [::PhyloTree::Data::getTreeAttributeKeys $treeID]

        foreach shownAttributeName [lsort [array names shownAttributes]] {
            
            if {$shownAttributeName != "QR Ordering"} {
                if {$shownAttributes($shownAttributeName) == 1 && [lsearch $allNodeAttributes $shownAttributeName] != -1} {
                    
                    set attributeValue [::PhyloTree::Data::getNodeAttribute $treeID $node $shownAttributeName]
                    if {$attributeValue != ""} {
                        
                        if {$label != ""} {
                            set label "$label, $attributeValue"
                        } else {
                            set label $attributeValue
                        }
                    }
                }
            }
        }
        
        return $label
    }
    
# -------------------------------------------------------------------    
    # Sets the scroll bars.
    proc setScrollbars {} {
        
        variable widget
        variable tree
        variable width
        variable height
        variable treeWidth
        variable treeHeight        
        
        # Set the viewable area of the canvas.
        $tree configure -scrollregion [list 0 0 $treeWidth $treeHeight]
        
        # Set the scroll bars.
        if {$treeWidth > $width} {
            $widget.bottom.xscroll activate
            $widget.bottom.xscroll set 0 [expr $width/$treeWidth]
        } else {
            $widget.bottom.xscroll set 0 1
        }
        
        if {$treeHeight > $height} {
            $widget.center.yscroll activate
            $widget.center.yscroll set 0 [expr $height/$treeHeight]
        } else {
            $widget.center.yscroll set 0 1
        }
    }
    
# -------------------------------------------------------------------    
    proc drawObject {canvasObject type {p1 ""} {p2 ""} {p3 ""} {p4 ""} {p5 ""} {p6 ""} {p7 ""} {p8 ""} {p9 ""} {p10 ""}} {
        
        variable reverseOrientation
        variable treeWidth
        variable lineWidth
        variable treeLineColor
		
        if {!$reverseOrientation} {
            if {$type == "line"} {
                return [$canvasObject create line $p1 $p2 $p3 $p4 -width $lineWidth -capstyle round -fill $treeLineColor]
            } elseif {$type == "rectangle"} {
                return [$canvasObject create rectangle $p1 $p2 $p3 $p4 -fill $p5 -outline $p6]
            } elseif {$type == "triangle"} {
                return [$canvasObject create polygon $p1 $p2 $p3 $p4 $p5 $p6 -fill $p7 -outline $p8 -width $lineWidth]
            } elseif {$type == "wedge"} {
                return [$canvasObject create polygon $p1 $p2 $p3 $p4 $p5 $p6 $p7 $p8 -fill $p9 -outline $p10 -width $lineWidth]
            } elseif {$type == "text"} {
                return [$canvasObject create text $p1 $p2 -font $p3 -anchor $p4 -text $p5 -fill $p6]
            } elseif {$type == "dashedline"} {
                return [$canvasObject create line $p1 $p2 $p3 $p4 -width $p5 -capstyle round -fill $p6 -dash $p7]
            }
        } else {
            if {$type == "line"} {
                set p1 [expr $treeWidth-$p1]
                set p3 [expr $treeWidth-$p3]
                return [$canvasObject create line $p1 $p2 $p3 $p4 -width $lineWidth -capstyle round -fill $treeLineColor]
            } elseif {$type == "rectangle"} {
                set p1 [expr $treeWidth-$p1]
                set p3 [expr $treeWidth-$p3]
                return [$canvasObject create rectangle $p1 $p2 $p3 $p4 -fill $p5 -outline $p6]
            } elseif {$type == "triangle"} {
                set p1 [expr $treeWidth-$p1]
                set p3 [expr $treeWidth-$p3]
                set p5 [expr $treeWidth-$p5]
                return [$canvasObject create polygon $p1 $p2 $p3 $p4 $p5 $p6 -fill $p7 -outline $p8 -width $lineWidth]
            } elseif {$type == "wedge"} {
                set p1 [expr $treeWidth-$p1]
                set p3 [expr $treeWidth-$p3]
                set p5 [expr $treeWidth-$p5]
				set p7 [expr $treeWidth-$p7]
                return [$canvasObject create polygon $p1 $p2 $p3 $p4 $p5 $p6 $p7 $p8 -fill $p9 -outline $p10 -width $lineWidth]
            } elseif {$type == "text"} {
                set p1 [expr $treeWidth-$p1]
                if {$p4 == "ne"} {
                    set p4 "nw"
                } elseif {$p4 == "e"} {
                    set p4 "w"
                } elseif {$p4 == "se"} {
                    set p4 "sw"
                } elseif {$p4 == "nw"} {
                    set p4 "ne"
                } elseif {$p4 == "w"} {
                    set p4 "e"
                } elseif {$p4 == "sw"} {
                    set p4 "se"
                }
                return [$canvasObject create text $p1 $p2 -font $p3 -anchor $p4 -text $p5 -fill $p6]
            } elseif {$type == "dashedline"} {
                set p1 [expr $treeWidth-$p1]
                set p3 [expr $treeWidth-$p3]
                return [$canvasObject create line $p1 $p2 $p3 $p4 -width $p5 -capstyle round -fill $p6 -dash $p7]
            }
        }
    }
# ------------------------------------------------------------------------
   proc drawTree {} {
    
      variable tree
      variable treeID
      variable borderX
      variable borderY
      variable rowHeight
      variable lineWidth
      variable internalNodeWidth   
      variable nodeHotspotWidth
      variable scale
      variable canvasObjectMap
      variable treeWidth
      variable treeHeight
      variable labelColor
      variable labelColorForeground
      variable internalLabelFont
      variable treeLineColor
      variable backgroundColor
      variable nodeColor
      variable cutoffLine        
      variable cutoffMinX
      variable cutoffMaxX
      variable cutoffLineColor
      variable selectedNodes
      variable selectedNodeColor
      variable selectedCellColor
    
      # Get the root node.
      set rootNode [::PhyloTree::Data::getTreeRootNode $treeID]
      # Figure out some lengths.
      set maxLabelLength [calculateMaxLabelLength]
      set rootLabelLength [expr [font measure $internalLabelFont \
                  [::PhyloTree::Data::getNodeLabel $treeID $rootNode]]+\
                  $internalNodeWidth+1]
      set treeWidth [expr $borderX+$rootLabelLength+(\
                    [::PhyloTree::Data::getTreeDistance $treeID]*$scale)+\
                    $maxLabelLength+$borderX]
            
#      puts "rootNode is $rootNode, treeID is $treeID, maxLab is $maxLabelLength, rootLab is $rootLabelLength, treeWidth is $treeWidth"        
      # Draw the top border
      set x1 0
      set x2 [expr $x1+$treeWidth]
      set y1 0
      set y2 [expr $y1+$borderY]
      set topborderid [drawObject $tree rectangle $x1 $y1 $x2 $y2 \
                                        $backgroundColor $backgroundColor]
      set canvasObjectMap(topborderid) $topborderid
            
      # Set the starting coordinates of the tree.
      set x [expr $borderX+$rootLabelLength]
      set y $borderY
        
      # Draw the sub nodes.
      set minY $y
      set maxY $y
      set minX $x
      set maxX $x
      set minChildY ""
      set maxChildY ""
      set minChildX ""
      set maxChildX ""
      set childNodes [::PhyloTree::Data::getChildNodes $treeID $rootNode] 
#      puts "phylotree_widget.drawTree() childModes: <$childNodes>, length: [llength $childNodes]"
      if { [ llength $childNodes ] == 0 } {
         return
      }

      foreach childNode $childNodes {
         set childPosition [drawNode $childNode $x $y]

         if {[lindex $childPosition 0] < $minY} {
            set minY [lindex $childPosition 0]
         }
         if {$minChildY == "" || [lindex $childPosition 1] < $minChildY} {
            set minChildY [lindex $childPosition 1]
         }
         if {$maxChildY == "" || [lindex $childPosition 1] > $maxChildY} {
            set maxChildY [lindex $childPosition 1]
         }
         if {[lindex $childPosition 2] > $maxY} {
            set maxY [lindex $childPosition 2]
         }
         if {[lindex $childPosition 3] < $minX} {
            set minX [lindex $childPosition 3]
         }
         if {$minChildX == "" || [lindex $childPosition 4] < $minChildX} {
            set minChildX [lindex $childPosition 4]
         }
         if {$maxChildX == "" || [lindex $childPosition 4] > $maxChildX} {
            set maxChildX [lindex $childPosition 4]
         }
         if {[lindex $childPosition 5] > $maxX} {
            set maxX [lindex $childPosition 5]
         }
            
         set y $maxY
      }
            
      # Draw the root node.
      set y1 $minChildY
      set y2 $maxChildY
      set yc [expr $y1+(($y2-$y1)/2)]
      set joinlineid [drawObject $tree line $x $y1 $x $y2]
      if {[lsearch $selectedNodes $rootNode] == -1} {
         set nodeboxid [drawObject $tree rectangle [expr $x-$internalNodeWidth]\
                  [expr $yc-$internalNodeWidth] [expr $x+$internalNodeWidth] \
                  [expr $yc+$internalNodeWidth] $nodeColor $nodeColor]
      } else {
         set nodeboxid [drawObject $tree rectangle [expr $x-$internalNodeWidth]\
                  [expr $yc-$internalNodeWidth] [expr $x+$internalNodeWidth] \
                  [expr $yc+$internalNodeWidth] \
                  $selectedNodeColor $selectedNodeColor]
      }
      set nodehotspotid [drawObject $tree rectangle [expr $x-$nodeHotspotWidth]\
                  [expr $yc-$nodeHotspotWidth] [expr $x+$nodeHotspotWidth] \
                  [expr $yc+$nodeHotspotWidth] {} {}]
      set canvasObjectMap($rootNode,joinlineid) $joinlineid
      set canvasObjectMap($rootNode,nodeboxid) $nodeboxid
      set canvasObjectMap($rootNode,fillcolor) $nodeColor
      set canvasObjectMap($rootNode,outlinecolor) $nodeColor
      set canvasObjectMap($rootNode,selectedfillcolor) $selectedNodeColor
      set canvasObjectMap($rootNode,selectedoutlinecolor) $selectedNodeColor
      set canvasObjectMap($rootNode,nodehotspotid) $nodehotspotid
      bindMouseCommands $tree $nodehotspotid "::PhyloTree::Widget::click_nodelocation %x %y ${rootNode} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${rootNode} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${rootNode} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${rootNode} right 0"
        
      # Draw the node label.
      set nodelabeltextid [drawObject $tree text [expr $x-$internalNodeWidth-1]\
                   [expr $yc-$internalNodeWidth-1] $internalLabelFont se \
                   [::PhyloTree::Data::getNodeLabel $treeID $rootNode] \
                   $treeLineColor]
      set canvasObjectMap($rootNode,nodelabeltextid) $nodelabeltextid
            
      # Draw the cutoff line.
      set cutoffLine [drawObject $tree dashedline $x 0 $x $y \
                               [expr $lineWidth*2] $cutoffLineColor {10 10}]
      $tree itemconfigure $cutoffLine -state hidden
      set canvasObjectMap(cutofflineid) $cutoffLine
      set cutoffMinX $x
      set cutoffMaxX [expr $x+([::PhyloTree::Data::getTreeDistance \
                                                        $treeID]*$scale)]
            
      # Draw the scale bar.
      set y [drawScale $x $y]
      set y [drawLegend $x $y]
      set maxY $y
        
      # Draw the bottom border
      set y1 $y
      set y2 [expr $y1+$borderY]
      set botborderid [drawObject $tree rectangle $x1 $y1 $x2 $y2 \
                                         $backgroundColor $backgroundColor]
      set canvasObjectMap(botborderid) $botborderid
      set maxY $y2
            
      # Save the width and height of the tree.
      set treeHeight $maxY
   }

# -----------------------------------------------------------------------
    proc drawNode {node nextX nextY} {
        
        variable tree
        variable treeID
        variable borderX
        variable borderY
        variable rowHeight
        variable rowTextHeight
        variable lineWidth
        variable internalNodeWidth    
        variable leafNodeWidth
        variable nodeHotspotWidth
        variable scale
        variable canvasObjectMap
        variable treeWidth
        variable internalLabelFont
        variable leafLabelFont
        variable qrLabelFont
        variable labelColor
        variable labelColorForeground
        variable backgroundColor
        variable backgroundColoring
        variable backgroundColors
        variable treeLineColor
        variable leafColor
        variable leafColoring
        variable leafColors
        variable nodeColor
        variable colorByDomainOfLife
        variable colorLeafsByDomainOfLife
        variable domainOfLifeColors
        variable showLabel
        variable qrOrderingColor
        variable treeGreyedColored
        variable showInternalLabels
        variable showInternalNodes
        variable shownAttributes
        variable selectedNodes
        variable selectedNodeColor
        variable selectedCellColor
        variable rowsPerWedge
        variable wedgeBackgroundColor
        variable selectedWedgeBackgroundColor
    
        # See if this is a leaf.
        if {[::PhyloTree::Data::getChildNodes $treeID $node] == {}} {
            
            # Figure out the y positions of the cell.
            set y1 $nextY
            set yc [expr $y1+($rowHeight/2)]
            set y2 [expr $y1+$rowHeight]
            
            # Figure out the x positions of the cell.
            set cellx1 0
            set cellx2 [expr $cellx1+$treeWidth]
            
            # Draw the node's cell.
            set color $backgroundColor
            if {$backgroundColoring != "default" && [::PhyloTree::Data::getNodeAttribute $treeID $node $backgroundColoring] != ""} {
                set index [lsearch [::PhyloTree::Data::getTreeAttributeValues $treeID $backgroundColoring] [::PhyloTree::Data::getNodeAttribute $treeID $node $backgroundColoring]]
                if {$index != -1} {
                    set index [expr $index%[llength $backgroundColors]]
                    set color [lindex $backgroundColors $index]
                }
            }
            if {[lsearch $selectedNodes $node] == -1} {
                set cellid [drawObject $tree rectangle $cellx1 $y1 $cellx2 $y2 $color $color]
            } else {
                set cellid [drawObject $tree rectangle $cellx1 $y1 $cellx2 $y2 $selectedCellColor $selectedCellColor]
            }
            set canvasObjectMap($node,cellid) $cellid
            set canvasObjectMap($node,cellcolor) $color
            
            # Draw our descent line and node.
            set x1 $nextX
            set x2 [expr $nextX+([::PhyloTree::Data::getDistanceToParentNode $treeID $node]*$scale)]
            set descentlineid [drawObject $tree line $x1 $yc $x2 $yc]
            if {[lsearch $selectedNodes $node] == -1} {
                set nodeboxid [drawObject $tree rectangle [expr $x2-$leafNodeWidth] [expr $yc-$leafNodeWidth] [expr $x2+$leafNodeWidth] [expr $yc+$leafNodeWidth] $nodeColor $nodeColor]
            } else {
                set nodeboxid [drawObject $tree rectangle [expr $x2-$leafNodeWidth] [expr $yc-$leafNodeWidth] [expr $x2+$leafNodeWidth] [expr $yc+$leafNodeWidth] $selectedNodeColor $selectedNodeColor]
            }
            set nodehotspotid [drawObject $tree rectangle [expr $x2-$nodeHotspotWidth] [expr $yc-$nodeHotspotWidth] [expr $x2+$nodeHotspotWidth] [expr $yc+$nodeHotspotWidth] {} {}]
            set canvasObjectMap($node,descentlineid) $descentlineid
            set canvasObjectMap($node,nodeboxid) $nodeboxid
            set canvasObjectMap($node,fillcolor) $nodeColor
            set canvasObjectMap($node,outlinecolor) $nodeColor
            set canvasObjectMap($node,selectedfillcolor) $selectedNodeColor
            set canvasObjectMap($node,selectedoutlinecolor) $selectedNodeColor
            set canvasObjectMap($node,nodehotspotid) $nodehotspotid
            bindMouseCommands $tree $nodehotspotid "::PhyloTree::Widget::click_nodelocation %x %y ${node} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${node} right 3"
            bindMouseCommands $tree $descentlineid "::PhyloTree::Widget::drawRedNode %x $yc $node $descentlineid"
            # Draw the node label.
            set color $leafColor
            if {$leafColoring != "default" && [::PhyloTree::Data::getNodeAttribute $treeID $node $leafColoring] != ""} {
                set index [lsearch [::PhyloTree::Data::getTreeAttributeValues $treeID $leafColoring] [::PhyloTree::Data::getNodeAttribute $treeID $node $leafColoring]]
                if {$index != -1} {
                    set index [expr $index%[llength $leafColors]]
                    set color [lindex $leafColors $index]
                }
            }
            set nodelabeltextid [drawObject $tree text [expr $x2+$lineWidth+$lineWidth+4] $yc $leafLabelFont w [getLeafLabel $node] $color]
            set canvasObjectMap($node,nodelabeltextid) $nodelabeltextid            
            bindMouseCommands $tree $nodelabeltextid "::PhyloTree::Widget::click_nodelocation %x %y ${node} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${node} right 3"
    
            # Draw the QR ordering, if necessary.
            set qrAttributeName "QR Ordering"
            if {[info exists shownAttributes($qrAttributeName)] && $shownAttributes($qrAttributeName) == 1} {
                set ordering [::PhyloTree::Data::getNodeAttribute $treeID $node $qrAttributeName]
                if {$ordering != ""} {
                    set width [font measure $qrLabelFont "888"]
                    set qrorderingid [drawObject $tree text [expr $cellx2-4-($width/2)] $yc $qrLabelFont c $ordering $qrOrderingColor]
                    set canvasObjectMap($node,qrorderingid) $qrorderingid
                    bindMouseCommands $tree $qrorderingid "::PhyloTree::Widget::click_nodelocation %x %y ${node} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${node} right 3"
                }
            }
                
            return [list $y1 $yc $y2 $x1 $x2 $cellx2]
         
        # Otherwise see if this is a collapsed node
        } elseif {[isNodeCollapsed $node]} {
            
            # Figure out the y positions.
            set y1 $nextY
            set yc [expr $y1+($rowHeight*$rowsPerWedge/2)]
            set y2 [expr $y1+($rowHeight*$rowsPerWedge)]

            # Figure out the x positions of the cell.
            set cellx1 0
            set cellx2 [expr $cellx1+$treeWidth]
            
            # Draw the node's cell.
            set cellid [drawObject $tree rectangle $cellx1 $y1 $cellx2 $y2 $backgroundColor $backgroundColor]
            set canvasObjectMap($node,cellid) $cellid            
            set canvasObjectMap($node,cellcolor) $backgroundColor
            
            # Draw our descent line and node.
            set x1 $nextX
            set x2 [expr $nextX+([::PhyloTree::Data::getDistanceToParentNode $treeID $node]*$scale)]
            set descentlineid [drawObject $tree line $x1 $yc $x2 $yc]
            set wedgeHeight [expr ($rowTextHeight*$rowsPerWedge/2)]
            if {$wedgeHeight < $internalNodeWidth} {
                set wedgeHeight $internalNodeWidth
            }
			
			# Define the diversity of this collapsed node by the length of the longest and shortest branch.
			set maxLength 0
			set minLength -1
			set leafNodes [::PhyloTree::Data::getLeafNodes $treeID $node]
			foreach leafNode $leafNodes {
				set tempNode $leafNode
				set Length 0
				while {$tempNode != $node} {
					set l [expr [::PhyloTree::Data::getDistanceToParentNode $treeID $tempNode]*$scale]
					set Length [expr $l+$Length]
					set tempNode [::PhyloTree::Data::getParentNode $treeID $tempNode]
				}
				if {$Length > $maxLength} {
					set maxLength $Length
				} 
				if {$minLength == -1 || $Length < $minLength} {
					set minLength $Length
				}
			}
			if {$maxLength == 0 && $minLength == 0} {
				set maxLength $wedgeHeight
				set minLength $wedgeHeight
			}
			
			set wedgeHeight [expr $wedgeHeight+2]
            if {[lsearch $selectedNodes $node] == -1} {
                set nodeboxid [drawObject $tree triangle $x2 $yc [expr $x2+$maxLength] [expr $yc-$wedgeHeight] [expr $x2+$minLength] [expr $yc+$wedgeHeight] $wedgeBackgroundColor $nodeColor]
            } else {
                set nodeboxid [drawObject $tree triangle $x2 $yc [expr $x2+$maxLength] [expr $yc-$wedgeHeight] [expr $x2+$minLength] [expr $yc+$wedgeHeight] $selectedWedgeBackgroundColor $nodeColor]
            }
			
			#if {[lsearch $selectedNodes $node] == -1} {
            #    set nodeboxid [drawObject $tree wedge $x2 [expr $yc-$wedgeHeight] [expr $x2+$maxLength] [expr $yc-$wedgeHeight] [expr $x2+$minLength] [expr $yc+$wedgeHeight] $x2 [expr $yc+$wedgeHeight] $wedgeBackgroundColor $nodeColor]
            #} else {
            #    set nodeboxid [drawObject $tree wedge $x2 [expr $yc-$wedgeHeight] [expr $x2+$maxLength] [expr $yc-$wedgeHeight] [expr $x2+$minLength] [expr $yc+$wedgeHeight] $x2 [expr $yc+$wedgeHeight] $selectedNodeColor $selectedNodeColor]
            #}
            set canvasObjectMap($node,descentlineid) $descentlineid
            set canvasObjectMap($node,nodeboxid) $nodeboxid
            set canvasObjectMap($node,fillcolor) $wedgeBackgroundColor
            set canvasObjectMap($node,outlinecolor) $nodeColor
            set canvasObjectMap($node,selectedfillcolor) $selectedWedgeBackgroundColor
            set canvasObjectMap($node,selectedoutlinecolor) $nodeColor
            bindMouseCommands $tree $nodeboxid "::PhyloTree::Widget::click_nodelocation %x %y ${node} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${node} right 2"
            bindMouseCommands $tree $descentlineid "::PhyloTree::Widget::drawRedNode %x $yc $node $descentlineid"
            
            # Draw the clade label.
            set cladelabeltextid [drawObject $tree text [expr $x2+$maxLength+2] $yc $leafLabelFont w "[::PhyloTree::Data::getNodeName $treeID $node] ([::PhyloTree::Data::getLeafNodeCount $treeID $node])" $leafColor]
            set canvasObjectMap($node,cladelabeltextid) $cladelabeltextid
            
            # Draw the node label.
            if {$showInternalLabels} {
                set nodelabeltextid [drawObject $tree text [expr $x2-$internalNodeWidth-1] [expr $yc-$internalNodeWidth-1] $internalLabelFont se [::PhyloTree::Data::getNodeLabel $treeID $node] $treeLineColor]
                set canvasObjectMap($node,nodelabeltextid) $nodelabeltextid
            }
    
            return [list $y1 $yc $y2 $x1 $x2 $cellx2]
         
        # Otherwise this is an internal node.
        } else {
            
            # Draw the sub nodes.
            set minY $nextY
            set maxY $nextY
            set minX $nextX
            set maxX $nextX
            set minChildY ""
            set maxChildY ""
            set nextChildX [expr $nextX+([::PhyloTree::Data::getDistanceToParentNode $treeID $node]*$scale)]
            set nextChildY $nextY
            foreach childNode [::PhyloTree::Data::getChildNodes $treeID $node] {
                set childPosition [drawNode $childNode $nextChildX $nextChildY]
                if {[lindex $childPosition 0] < $minY} {
                    set minY [lindex $childPosition 0]
                }
                if {$minChildY == "" || [lindex $childPosition 1] < $minChildY} {
                    set minChildY [lindex $childPosition 1]
                }
                if {$maxChildY == "" || [lindex $childPosition 1] > $maxChildY} {
                    set maxChildY [lindex $childPosition 1]
                }
                if {[lindex $childPosition 2] > $maxY} {
                    set maxY [lindex $childPosition 2]
                }
                if {[lindex $childPosition 3] < $minX} {
                    set minX [lindex $childPosition 3]
                }
                if {[lindex $childPosition 5] > $maxX} {
                    set maxX [lindex $childPosition 5]
                }
                
                set nextChildY $maxY
            }

            # Figure out some positions.            
            set x1 $nextX
            set x2 $nextChildX
            set y1 $minChildY
            set y2 $maxChildY
            set yc [expr (($maxChildY-$minChildY)/2.0)+$minChildY]
            
            # Draw our join line, descent line, and node.
            set joinlineid [drawObject $tree line $x2 $y1 $x2 $y2]
            set descentlineid [drawObject $tree line $x1 $yc $x2 $yc]
            set canvasObjectMap($node,descentlineid) $descentlineid
            set canvasObjectMap($node,joinlineid) $joinlineid
            
            # Draw the node.
            if {$showInternalNodes} {
                if {[lsearch $selectedNodes $node] == -1} {
                    set nodeboxid [drawObject $tree rectangle [expr $x2-$internalNodeWidth] [expr $yc-$internalNodeWidth] [expr $x2+$internalNodeWidth] [expr $yc+$internalNodeWidth] $nodeColor $nodeColor]
                } else {
                    set nodeboxid [drawObject $tree rectangle [expr $x2-$internalNodeWidth] [expr $yc-$internalNodeWidth] [expr $x2+$internalNodeWidth] [expr $yc+$internalNodeWidth] $selectedNodeColor $selectedNodeColor]
                }
                set canvasObjectMap($node,nodeboxid) $nodeboxid
                set canvasObjectMap($node,fillcolor) $nodeColor
                set canvasObjectMap($node,outlinecolor) $nodeColor
                set canvasObjectMap($node,selectedfillcolor) $selectedNodeColor
                set canvasObjectMap($node,selectedoutlinecolor) $selectedNodeColor
            }
            set nodehotspotid [drawObject $tree rectangle [expr $x2-$nodeHotspotWidth] [expr $yc-$nodeHotspotWidth] [expr $x2+$nodeHotspotWidth] [expr $yc+$nodeHotspotWidth] {} {}]
            set canvasObjectMap($node,nodehotspotid) $nodehotspotid
            bindMouseCommands $tree $nodehotspotid "::PhyloTree::Widget::click_nodelocation %x %y ${node} left normal" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left shift" "::PhyloTree::Widget::click_nodelocation %x %y ${node} left control" "" "" "" "::PhyloTree::Widget::click_nodelocation %x %y ${node} right 1"
            bindMouseCommands $tree $descentlineid "::PhyloTree::Widget::drawRedNode %x $yc $node $descentlineid"
            
            # Draw the node label.
            if {$showInternalLabels} {
                set nodelabeltextid [drawObject $tree text [expr $x2-$internalNodeWidth-1] [expr $yc-$internalNodeWidth-1] $internalLabelFont se [::PhyloTree::Data::getNodeLabel $treeID $node] $treeLineColor]
                set canvasObjectMap($node,nodelabeltextid) $nodelabeltextid
            }
                
            return [list $minY $yc $maxY $minX $x2 $maxX]
        }
    }
    
# -------------------------------------------------------------------    
    # Draw a scale below an existing tree
    proc drawScale {x y} {
    
        variable tree
        variable treeID
        variable treeWidth
        variable rowHeight
        variable lineWidth
        variable nodeHeaderWidth
        variable borderX
        variable scale
        variable canvasObjectMap
        variable leafLabelFont
        variable backgroundColor
    
        # Draw the background.
        set x1 0
        set x2 [expr $x1+$treeWidth]
        set y1 $y
        set y2 [expr $y+(2*$rowHeight)]
        set backgroundid [drawObject $tree rectangle $x1 $y1 $x2 $y2 $backgroundColor $backgroundColor]
        set canvasObjectMap(scale,backgroundid) $backgroundid
        
        # Figure out the length of the bar.
        set totalLength [::PhyloTree::Data::getTreeDistance $treeID]
        set barLength 10000.0
        set divisor 2.0
        while {1} {
            if {$barLength >= [expr $totalLength/4]} {
                set barLength [expr $barLength/$divisor]
                if {$divisor == 2.0} {
                    set divisor 5.0
                } else {
                    set divisor 2.0
                }
            } else {
                break
            }
        }
            
        # Draw the scale bar.
        set x1 $x
        set x2 [expr $x+($barLength*$scale)]
        set yc [expr $y+($rowHeight/2)]
        set y1 [expr $yc-3]
        set y2 [expr $yc+3]
        set scalebarid [$tree create line $x1 $yc $x2 $yc -width $lineWidth -capstyle round]
        set scaleticksid [$tree create line $x1 $y1 $x1 $y2 -width $lineWidth -capstyle round]
        set scaletickeid [$tree create line $x2 $y1 $x2 $y2 -width $lineWidth -capstyle round]
        set canvasObjectMap(scale,scalebarid) $scalebarid
        set canvasObjectMap(scale,scaleticksid) $scaleticksid
        set canvasObjectMap(scale,scaletickeid) $scaletickeid

        # Draw the text.
        set yc [expr $yc+$rowHeight]
        set units [::PhyloTree::Data::getTreeUnits $treeID]
        if {$units != ""} {
            set units " $units"
        }
        set scaletextid [$tree create text $x1 $yc -font $leafLabelFont -anchor w -text "[format %1.2f $barLength]$units"]
        set canvasObjectMap(scale,scaletextid) $scaletextid
        
        # Draw the scale text.
        incr y [expr (2*$rowHeight)]
        
        return $y
    }
        
# -------------------------------------------------------------------    
    proc drawLegend {x y} {
    
        variable tree
        variable treeID
        variable treeWidth
        variable rowHeight
        variable lineWidth
        variable nodeHeaderWidth
        variable borderX
        variable scale
        variable canvasObjectMap
        variable leafLabelFont
        variable backgroundColor
        variable leafColoring
        variable leafColors
        variable backgroundColoring
        variable backgroundColors

        # Draw the leaf coloring legend.
        if {$leafColoring != "default"} {
            
            # Figure out the number of rows.
            set values [::PhyloTree::Data::getTreeAttributeValues $treeID $leafColoring]
            set valueCount [llength $values]
            set rows [expr 2+($valueCount/4)]
            if {[expr $valueCount%4] != 0} {
                incr rows
            }
            
            # Draw the background.
            set x1 0
            set x2 [expr $treeWidth]
            set y1 $y
            set y2 [expr $y+($rows*$rowHeight)]
            set backgroundid [drawObject $tree rectangle $x1 $y1 $x2 $y2 $backgroundColor $backgroundColor]
            set canvasObjectMap(leaflegend,backgroundid) $backgroundid
            
            # Draw the label.
            incr y $rowHeight
            set y1 [expr $y]
            set y2 [expr $y+$rowHeight]
            set yc [expr ($y1+$y2)/2]
            set textid [$tree create text $x $yc -font $leafLabelFont -anchor w -text "Leaf Colors"]
            set canvasObjectMap(leaflegend,labelid) $textid
            incr y $rowHeight
            
            # Figure out the maximum label length.
            set maxLength 0
            foreach value $values {
                set length [font measure $leafLabelFont $value]
                if {$length > $maxLength} {
                    set maxLength $length
                }
            }
        
            # Draw the legend.
            for {set i 0} {$i < $valueCount} {incr i} {
                set value [lindex $values $i]
                set color [lindex $leafColors [expr $i%[llength $leafColors]]]
                if {[expr $i%4] == 0} {
                    set x1 $x
                    set x2 [expr $x+$rowHeight-4]
                }
                set y1 [expr $y+2]
                set y2 [expr $y+$rowHeight-4]
                set yc [expr ($y1+$y2)/2]
                set swatchid [$tree create rectangle $x1 $y1 $x2 $y2 -fill $color -outline "black"]
                set textid [$tree create text [expr $x2+4] $yc -font $leafLabelFont -anchor w -text $value]
                set canvasObjectMap(leaflegend,$value,swatchid) $swatchid
                set canvasObjectMap(leaflegend,$value,textid) $textid
                incr x1 [expr $maxLength+$rowHeight+10]
                incr x2 [expr $maxLength+$rowHeight+10]
                if {[expr $i%4] == 3 || $i == [expr $valueCount-1]} {
                    incr y $rowHeight
                }
            }
        }

        # Draw the background coloring legend.
        if {$backgroundColoring != "default"} {
            
            # Figure out the number of rows.
            set values [::PhyloTree::Data::getTreeAttributeValues $treeID $backgroundColoring]
            set valueCount [llength $values]
            set rows [expr 2+($valueCount/4)]
            if {[expr $valueCount%4] != 0} {
                incr rows
            }
            
            # Draw the background.
            set x1 0
            set x2 [expr $treeWidth]
            set y1 $y
            set y2 [expr $y+($rows*$rowHeight)]
            set backgroundid [drawObject $tree rectangle $x1 $y1 $x2 $y2 $backgroundColor $backgroundColor]
            set canvasObjectMap(backgroundlegend,backgroundid) $backgroundid
            
            # Draw the label.
            incr y $rowHeight
            set y1 [expr $y]
            set y2 [expr $y+$rowHeight]
            set yc [expr ($y1+$y2)/2]
            set textid [$tree create text $x $yc -font $leafLabelFont -anchor w -text "Background Colors"]
            set canvasObjectMap(backgroundlegend,labelid) $textid
            incr y $rowHeight
            
            # Figure out the maximum label length.
            set maxLength 0
            foreach value $values {
                set length [font measure $leafLabelFont $value]
                if {$length > $maxLength} {
                    set maxLength $length
                }
            }
        
            # Draw the legend.
            set x1 $x
            set x2 [expr $x+$rowHeight-4]
            for {set i 0} {$i < $valueCount} {incr i} {
                set value [lindex $values $i]
                set color [lindex $backgroundColors [expr $i%[llength $backgroundColors]]]
                if {[expr $i%4] == 0} {
                    set x1 $x
                    set x2 [expr $x+$rowHeight-4]
                }
                set y1 [expr $y+2]
                set y2 [expr $y+$rowHeight-4]
                set yc [expr ($y1+$y2)/2]
                set swatchid [$tree create rectangle $x1 $y1 $x2 $y2 -fill $color -outline "black"]
                set textid [$tree create text [expr $x2+4] $yc -font $leafLabelFont -anchor w -text $value]
                set canvasObjectMap(backgroundlegend,$value,swatchid) $swatchid
                set canvasObjectMap(backgroundlegend,$value,textid) $textid
                incr x1 [expr $maxLength+$rowHeight+10]
                incr x2 [expr $maxLength+$rowHeight+10]
                if {[expr $i%4] == 3 || $i == [expr $valueCount-1]} {
                    incr y $rowHeight
                }
            }
        }
        
        return $y
    }
        
# -------------------------------------------------------------------    
    proc bindMouseCommands {canvas object {click ""} {shiftClick ""} {controlClick ""} {shiftControlClick ""} {motion ""} {release ""} {rightClick ""}} {
        
        if {$click != ""} {
            $canvas bind $object <ButtonPress-1> $click
        }
        if {$shiftClick != ""} {
            $canvas bind $object <Shift-ButtonPress-1> $shiftClick
        }
        if {$motion != ""} {
            $canvas bind $object <B1-Motion> $motion
        }
        if {$release != ""} {
            $canvas bind $object <ButtonRelease-1> $release
        }
        if {$::tcl_platform(os) == "Darwin"} {
            if {$controlClick != ""} {
                $canvas bind $object <Command-ButtonPress-1> $controlClick
            }
            if {$shiftControlClick != ""} {
                $canvas bind $object <Shift-Command-ButtonPress-1> $shiftControlClick
            }
            if {$rightClick != ""} {
                $canvas bind $object <Control-ButtonPress-1> $rightClick
            }
            if {$rightClick != ""} {
                $canvas bind $object <ButtonPress-2> $rightClick
            }
        } else {
            if {$controlClick != ""} {
                $canvas bind $object <Control-ButtonPress-1> $controlClick
            }
            if {$shiftControlClick != ""} {
                $canvas bind $object <Shift-Control-ButtonPress-1> $shiftControlClick
            }
            if {$rightClick != ""} {
                $canvas bind $object <ButtonPress-3> $rightClick
            }
        }
    }
    
# -------------------------------------------------------------------    
    variable tempNode -1
    variable tempX -1
    variable tempY -1
    
# -------------------------------------------------------------------    
    proc click_nodelocation {x y node modifier type} {
        
        variable widget
        variable nodePopupMenu
        variable tempNode
        variable tempX
        variable tempY
        set tempX $x
        set tempY $y
        
        if {$modifier == "left"} {
            if {$type == "normal"} {
                setSelectedNodes $node
                set tempNode $node
            } elseif {$type == "shift"} {
                if {$tempNode == -1} {
                    setSelectedNodes $node
                    set tempNode $node
                } else {
                    setSelectedNodeRange $tempNode $node
                }
            } elseif {$type == "control"} {
                setSelectedNodes $node 0 1
                set tempNode $node
            }
        } elseif {$modifier == "right"} {
            
            # Figure out the popup location.
            set px [expr $x+[winfo rootx $widget]]
            set py [expr $y+[winfo rooty $widget]]
                    
            # Bring up the group popup menu.
            set tempNode $node
            tk_popup [lindex $nodePopupMenu $type] $px $py
        }
    }
    
# -------------------------------------------------------------------    
    proc menu_rotatenode {direction} {
        
        variable tempNode
        
        rotateNode $tempNode $direction
    }
    
# -------------------------------------------------------------------    
    proc menu_collapsenode {} {
        
        variable tempNode
        
        if {[isNodeCollapsed $tempNode]} {
            setNodeCollapsed $tempNode 0
        } else {
            setNodeCollapsed $tempNode 1
        }
    }
    
# -------------------------------------------------------------------    
    proc menu_removenode {} {
            
	    variable treeID
        variable tempNode
	    
        # Remove the node and redraw the tree.
	    ::PhyloTree::Data::removeNode $treeID $tempNode        
        redraw
    }
    
# -------------------------------------------------------------------    
    proc menu_nodeproperties {} {
    
        variable widget
        variable treeID
        variable tempNode
        variable tempX
        variable tempY
        
        # Figure out some information about this node.
        if {[::PhyloTree::NodeProperties::showNodePropertiesDialog $widget $tempX $tempY $treeID $tempNode]} {
            redraw
        }
    }
    
# -------------------------------------------------------------------    
    proc notifySelectionChangeListeners {} {
        
        variable selectionNotificationCommands
        
        if {$selectionNotificationCommands != {}} {
            foreach selectionNotificationCommand $selectionNotificationCommands {
                $selectionNotificationCommand
            }
        }
    }
    
# -------------------------------------------------------------------    
    proc notifyTreeChangeListeners {} {
        
        variable treeChangeNotificationCommands
        
        if {$treeChangeNotificationCommands != {}} {
            foreach treeChangeNotificationCommand $treeChangeNotificationCommands {
                $treeChangeNotificationCommand
            }
        }
    }
    
# -------------------------------------------------------------------    
    proc updateStatusBar {} {
        
        variable treeID
        variable statusBarText
        
        set selectedNodes [getSelectedNodes]
        if {[llength $selectedNodes] == 2} {
            set statusBarText "Distance: [::PhyloTree::Data::getDistanceBetweenNodes $treeID [lindex $selectedNodes 0] [lindex $selectedNodes 1]]"
            return
        }
        
        # If we couldn't find a case, set the status bar to be blank.
        set statusBarText ""
    }

# -------------------------------------------------------------------    
    variable lastPSFile "tree.ps"
# -------------------------------------------------------------------    
    proc saveAsPS {} {
        
        variable tree
        variable treeWidth
        variable treeHeight
        variable lastPSFile
    
        set outFile [tk_getSaveFile -initialfile $lastPSFile -title "Save As"]
    
        if {$outFile != ""} {
            set lastPSFile [file tail $outFile]
            $tree postscript -x 0 -y 0 -width $treeWidth -height $treeHeight -file $outFile
        }
    }
    
# -------------------------------------------------------------------    
    proc drawRedNode { x y node lineid } {
	variable internalNodeWidth
	variable selectedSpot
	variable tree
	variable selectedX
	variable selectedY
	variable selectedChild
	variable scale
	variable treeID
	variable distanceToChild
	
	set selectedX $x
	set selectedY $y
	set selectedChild $node
	set width 1
	catch {
		$tree delete $selectedSpot
	}

	set coords [$tree coords $lineid]
	set lineLength [expr [lindex $coords 2] - [lindex $coords 0]]
	set distanceToPoint [expr $selectedX - [lindex $coords 0]]
	set distanceToChild [expr ($lineLength - $distanceToPoint) / $scale]
        set selectedSpot [drawObject $tree rectangle [expr $x-$internalNodeWidth] [expr $y-$internalNodeWidth] [expr $x+$internalNodeWidth] [expr $y+$internalNodeWidth] red red]

    }
    
# -------------------------------------------------------------------    
    proc rerootTree { } {
	    variable treeID
	    variable selectedChild
	    variable distanceToChild
	    
	    ::PhyloTree::Data::reroot $treeID $selectedChild $distanceToChild
    }
	    
}

