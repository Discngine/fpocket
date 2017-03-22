############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

############################################################################
# RCS INFORMATION:
#
#       $RCSfile: seqedit_preview.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.2 $       $Date: 2004/10/24 22:44:04 $
#
############################################################################

package provide seqedit_preview 1.0
package require seqedit_widget 1.0
package require seqdata 1.0

# Declare global variables for this package.
namespace eval ::SeqEditPreview:: {

    # Export the package namespace.
    namespace export SeqEditPreview

    # Handle to the sequence editor window.
    variable w
    
    # The sequence ids that are being previewed.
    variable sequenceIDs {}

    # Handle to the sequence editor window.
    variable colorMap
	array set colorMap {}
	
    # Handle to the sequence editor window.
    variable cellSize 16
    
    # The command to execute if the preview is accepted.
    variable acceptCommand

    # Setup some default colors.
    variable headerColorActive "#D3D3D3"
    variable headerColorInactive "#D3D3D3"
    variable headerColorForeground "black"
    variable cellColorActive "#FFFFFF"
    variable cellColorInactive "#C0C0C0"
    variable cellColorForeground "black"
    
    # The name of the editor widget.
    variable widget
    
    # The name of the editor portion of the widget.
    variable editor

    # The current width of the sequence
    variable width

    # Handle to the sequence editor window.
    variable height

    # The current width of a cell in the editor.
    variable cellWidth 0
    
    # The current height of a cell in the editor.
    variable cellHeight 0
    
    # The current width of a cell in the editor.
    variable headerCellWidth 0
    
    # The current height of a cell in the editor.
    variable headerCellHeight 0
    
    # The objects that make up the grid columns.
    variable columnObjectMap
	array set columnObjectMap {}
    
    # The number of columns currently present in the editor.
    variable numberCols 0
    
    # The number of rows currently present in the editor.
    variable numberRows 0
    
    # The current sequences in the editor.
    variable sequenceIDs {}
    
    # The first sequence element being displayed.
    variable firstElement 0
    
    # The first sequence being displayed.
    variable firstSequence 0
    
    # The number of sequences in the editor.
    variable numberSequences 0
    
    # The length of the longest sequence.
    variable numberElements 0
    
    # The current color map handler
    variable colorMapHandler ""
    
    # The current mapping of sequence elements to colors.
    variable sequenceColorMap
	array set sequenceColorMap {}
	
	# The font being used for the header display.
	variable previewHeaderFont ""
	
	# The font being used for the cell display.
	variable previewCellFont ""
}


# Creates a new preview window.
# args:     a_sequenceIDs - The list of sequence ids that should be shown in the preview window.
#           a_colorMap - The initial color map to use in the sequence preview.
#           a_cellsize - The initial cell size to use in the sequence preview.
#           a_acceptCommand - The command to execute if the preview is accepted. The sequence id list
#                             will be passed as an argument to this command.
proc ::SeqEditPreview::createPreviewWindow {a_colorMapHandler a_cellSize a_acceptCommand} {

    # Import global variables.
    variable w
    variable colorMap
    variable acceptCommand
    set sequenceIDs {}
    set acceptCommand $a_acceptCommand

    # Create a new top level window.
    set w [toplevel .seqeditpreview -menu .seqeditpreview.menu]
    wm title $w "Alignment Preview"
    wm minsize $w 400 200
    
    # Create the window's menu.
    createMenu    
    
    # Create the main layout.
    frame $w.viewer
    frame $w.bottom
    frame $w.bottom.buttons
    button $w.bottom.buttons.accept -text "Accept" -pady 2 -command "::SeqEditPreview::accept"
    button $w.bottom.buttons.cancel -text "Discard" -pady 2 -command "::SeqEditPreview::discard"
    pack $w.viewer -fill both -expand true -side top
    pack $w.bottom -fill x -side bottom
    pack $w.bottom.buttons -side bottom
    pack $w.bottom.buttons.accept -side left -padx 5 -pady 5
    pack $w.bottom.buttons.cancel -side right -padx 5 -pady 5

    createPreviewWidget $w.viewer $a_cellSize $a_cellSize
    setColorMapHandler $a_colorMapHandler
    
    return $w
}

# Creates the menu for the main window.
proc ::SeqEditPreview::createMenu {} {

    # Import global variables.
    variable w

    # Top level menu.
    menu $w.menu -tearoff no
    $w.menu add cascade -label "Options" -menu $w.menu.options
    
    # Options menu.
    menu $w.menu.options -tearoff no
    $w.menu.options add command -label "Zoom In" -accelerator "Ctrl +" -command "::SeqEditPreview::menu_zoomin"
    bind $w "<Control-plus>" {::SeqEditPreview::menu_zoomin}
    bind $w "<Control-equal>" {::SeqEditPreview::menu_zoomin}
    bind $w "<Command-plus>" {::SeqEditPreview::menu_zoomin}
    bind $w "<Command-equal>" {::SeqEditPreview::menu_zoomin}
    $w.menu.options add command -label "Zoom Out" -accelerator "Ctrl -" -command "::SeqEditPreview::menu_zoomout"
    bind $w "<Control-minus>" {::SeqEditPreview::menu_zoomout}
    bind $w "<Command-minus>" {::SeqEditPreview::menu_zoomout}
    $w.menu.options add separator
    $w.menu.options add cascade -label "Color Map" -menu $w.menu.options.colomap
    menu $w.menu.options.colomap -tearoff no
    $w.menu.options.colomap add radio -label "None" -indicatoron TRUE -command "::SeqEditPreview::menu_changecolormap none"
    $w.menu.options.colomap add radio -label "Resdiue Type" -command "::SeqEditPreview::menu_changecolormap residuetype"
    $w.menu.options.colomap add radio -label "Sequence Conservation" -command "::SeqEditPreview::menu_changecolormap conservation"    
}

proc ::SeqEditPreview::menu_zoomin {} {

    # Import global variables.
    variable w
    variable cellSize
    
    if {$cellSize < 10} {
        set cellSize [expr $cellSize+1]
        ::SeqEditPreview::setCellSize $cellSize $cellSize
    } elseif {$cellSize >= 10 && $cellSize <= 28} {
        set cellSize [expr $cellSize+2]
        ::SeqEditPreview::setCellSize $cellSize $cellSize
    }
}

proc ::SeqEditPreview::menu_zoomout {} {

    # Import global variables.
    variable w
    variable cellSize
    
    if {$cellSize > 4 && $cellSize <= 10} {
        set cellSize [expr $cellSize-1]
        ::SeqEditPreview::setCellSize $cellSize $cellSize
    } elseif {$cellSize >= 10} {
        set cellSize [expr $cellSize-2]
        ::SeqEditPreview::setCellSize $cellSize $cellSize
    }
}

proc ::SeqEditPreview::menu_changecolormap {colorMapType} {

    if {$colorMapType == "none"} {
        setColorMapHandler ""
    } elseif {$colorMapType == "residuetype"} {
        setColorMapHandler "::ColorMapIdentity::getColorMap"
    } elseif {$colorMapType == "conservation"} {
        setColorMapHandler "::ColorMapConservation::getColorMap"
    } elseif {$colorMapType == "custom"} {
        setColorMapHandler ""
    }
}

proc ::SeqEditPreview::accept {} {

    # Import global variables.
    variable w
    variable sequenceIDs
    variable acceptCommand
    
    # Call the accept command and close the window.
    $acceptCommand $sequenceIDs
    destroy $w
    
}

proc ::SeqEditPreview::discard {} {

    # Import global variables.
    variable w

    # Close the window.    
    destroy $w
}

# Creates a new sequence viewer.
# args:     a_widget - The frame that the widget should be shown in.
#           a_cellWidth - The width of a cell in the editor.
#           a_cellWidth - The height of a cell in the editor.
proc ::SeqEditPreview::createPreviewWidget {a_widget a_cellWidth a_cellHeight} {

    # Import global variables.
    variable widget
    variable editor
    variable width
    variable height
    variable cellColorInactive
    set widget $a_widget 

    #Create the components of the widget.
    frame $widget.center
    set editor [canvas $widget.center.editor -background $cellColorInactive]
    scrollbar $widget.center.yscroll -orient vertical -command {::SeqEditPreview::scroll_vertical}
    
    frame $widget.bottom
    scrollbar $widget.bottom.xscroll -orient horizontal -command {::SeqEditPreview::scroll_horzizontal}
    frame $widget.bottom.spacer -width [$widget.center.yscroll cget -width]
    
    pack $widget.center -side top -fill both -expand true
    pack $widget.center.editor -side left -fill both -expand true
    pack $widget.center.yscroll -side right -fill y
    
    pack $widget.bottom -side bottom -fill x
    pack $widget.bottom.spacer -side right
    pack $widget.bottom.xscroll -side left -fill x -expand true
    
    # Listen for resize events.
    bind $editor <Configure> {::SeqEditPreview::component_configured %W %w %h}
    
    # Calculate some basic information about the editor.
    set width [$editor cget -width]
    set height [$editor cget -height]
    
    # Set the cell size.
    setCellSize $a_cellWidth $a_cellHeight false

    # Set the scrollbars.
    setScrollbars
    
    # Create the grid.
    createCells
}


# Creates a new sequence editor.
# args:     a_control - The frame that the widget should be shown in.
#           a_cellWidth - The width of a cell in the editor.
#           a_cellWidth - The height of a cell in the editor.
proc ::::SeqEditPreview::setCellSize {a_cellWidth a_cellHeight {redraw true}} {

    # Import global variables.
    variable editor
    variable width
    variable height
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable numberCols
    variable numberRows
    variable previewHeaderFont
    variable previewCellFont
    variable firstElement
    variable firstSequence
    variable numberSequences
    variable numberElements
    set cellWidth $a_cellWidth
    set cellHeight $a_cellHeight
    
    # Set up any settings that are based on the cell size.
    set headerCellWidth 200
    set headerCellHeight 18
    set numberCols [expr (($width-$headerCellWidth)/$cellWidth)+1]
    set numberRows [expr (($height-$headerCellHeight)/$cellHeight)+1]
    set fontChecker [$editor create text 0 0 -anchor nw -text ""]
    if {$previewHeaderFont != ""} {font delete $previewHeaderFont}
    if {$previewCellFont != ""} {font delete $previewCellFont}
    set defaultFont [$editor itemcget $fontChecker -font]
    set previewHeaderFont [font create previewHeaderFont -family [lindex $defaultFont 0] -size [lindex $defaultFont 1]]
    if {$cellHeight >= 12 && $cellWidth >= 12} {
        set previewCellFont [font create previewCellFont -family [lindex $defaultFont 0] -size [expr ($cellHeight+3)/2]]
    } else {
        set previewCellFont ""
    }
    $editor delete $fontChecker
    
    # Make sure we are not out of scroll range.
    if {$numberElements > $numberCols} {
        if {$firstElement > ($numberElements-$numberCols+1)} {set firstElement [expr $numberElements-$numberCols+1]}
    } else {
        set firstElement 0
    }
    if {$numberSequences > $numberRows} {
        if {$firstSequence > ($numberSequences-$numberRows+1)} {set firstSequence [expr $numberSequences-$numberRows+1]}
    } else {
        set firstSequence 0
    }
            
    # Redraw the component, if requested to.
    if {$redraw == 1 || $redraw == "true" || $redraw == "TRUE"} {
        deleteCells
        setScrollbars
        createCells
        redraw
    }
}

# Sets the sequences that are currently being displayed by the editor.
# args:     a_sequenceIDs - A list of the sequence ids.
proc ::SeqEditPreview::setSequences {a_sequenceIDs} {

    # Import global variables.
    variable sequenceIDs
    variable numberSequences
    variable numberElements
    set sequenceIDs $a_sequenceIDs
    
    #Get the total number of sequences.
    set numberSequences [llength $sequenceIDs]
    
    #Figure out the max sequence length.
    set numberElements 0
    foreach sequenceID $sequenceIDs {
    
        #Get the sequence.
        set sequence [SeqData::getSeq $sequenceID]
        
        #Compare the length to the max.
        if {[llength $sequence] > $numberElements} {
            set numberElements [llength $sequence]
        }
    }
    
    # Calculate the new color map.
    recalculateColorMap
    
    # Set the scrollbars.
    setScrollbars
    
    #Redraw the widget.
    redraw
}

# The the color map used by the editor to map sequence elements to a color.
# args:     a_colorMapHandler - The new color map handler.
proc ::SeqEditPreview::setColorMapHandler {a_colorMapHandler} {

    # Import global variables.
    variable colorMapHandler
    set colorMapHandler $a_colorMapHandler
    
    # Calculate the new color map.
    recalculateColorMap

    # Redraw the widget.
    redraw
}

# Recalculates the current color map.
proc ::SeqEditPreview::recalculateColorMap {} {

    # Import global variables.
    variable sequenceIDs
    variable colorMapHandler
    variable sequenceColorMap
    
    # Call the color map handler and save the new color map.
    unset sequenceColorMap
    if {$colorMapHandler != ""} {
        array set sequenceColorMap [$colorMapHandler $sequenceIDs]
    } else {
        array set sequenceColorMap {}
    }
}

# Sets the scroll bars.
proc ::SeqEditPreview::setScrollbars {} {
    
    # Import global variables.
    variable widget
    variable firstElement
    variable firstSequence
    variable numberCols
    variable numberRows
    variable numberSequences
    variable numberElements
    
    # Set the scroll bars.
    if {$numberElements > $numberCols} {
        $widget.bottom.xscroll set [expr $firstElement/($numberElements.0+1.0)] [expr ($firstElement+$numberCols)/($numberElements.0+1.0)]
    } else {
        $widget.bottom.xscroll set 0 1
    }
    if {$numberSequences > $numberRows} {
        $widget.center.yscroll set [expr $firstSequence/($numberSequences.0+1.0)] [expr ($firstSequence+$numberRows)/($numberSequences.0+1.0)]
    } else {
        $widget.center.yscroll set 0 1
    }
    
}

# Creates a new grid of cells in the editor
proc ::SeqEditPreview::createCells {} {
    
    # Import global variables.
    variable editor
    variable numberCols

    # Create all of the columns for the editor
    createHeaderColumn
    for {set i 0} {$i < $numberCols} {incr i} {
        createColumn $i
    }
}

# Creates a new header column in the editor.
proc ::SeqEditPreview::createHeaderColumn {} {

    # Import global variables.
    variable editor
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable columnObjectMap
    variable numberRows
    variable headerColorActive
    variable headerColorForeground
    variable cellColorInactive
    variable previewHeaderFont
    variable previewCellFont
    
    # Set the starting location.
    set x 4
    set y 2
    
    # Create the header cell.
    set cellx1 $x
    set cellx2 [expr $headerCellWidth]
    set cellxc [expr $cellx1+(($cellx2-$cellx1)/2)]
    set celly1 $y
    set celly2 [expr $headerCellHeight-2]
    set cellyc [expr $celly1+(($celly2-$celly1)/2)]
    set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $headerColorActive -outline $headerColorActive]
    set textid [$editor create text $cellx1 $cellyc -font $previewHeaderFont -anchor w -text "Sequence Name"]
    
    # Create the separator and tick lines.
    set separatorid [$editor create line $cellx1 [expr $celly2+1] [expr $cellx2+1] [expr $celly2+1] -fill $headerColorForeground]
    set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] [expr $celly2+1] -fill $headerColorForeground]
    
    # Store the header cell objects.
    set columnObjectMap(h,h.boxid) $boxid
    set columnObjectMap(h,h.textid) $textid    
    set columnObjectMap(h,h.separatorid) $separatorid    
    set columnObjectMap(h,h.tickid) $tickid
    
    # Go through each row and create its row header.
    set y $headerCellHeight
    for {set row 0} {$row < $numberRows} {incr row} {
    
        # Create the cell for this row.
        set celly1 $y
        set celly2 [expr $celly1+$cellHeight-1]
        set cellyc [expr $celly1+(($celly2-$celly1)/2)]
        set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $cellColorInactive -outline $cellColorInactive]
        set separatorid [$editor create line $cellx1 $celly2 $cellx2 $celly2 -fill $cellColorInactive]
        set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] $celly2 -fill $cellColorInactive]
        set y [expr $celly2+1]
        
        #Store the row cell objects.
        set columnObjectMap(h,$row.active) 0
        set columnObjectMap(h,$row.boxid) $boxid
        set columnObjectMap(h,$row.boxcolor) $cellColorInactive
        set columnObjectMap(h,$row.separatorid) $separatorid
        set columnObjectMap(h,$row.separatorcolor) $cellColorInactive
        set columnObjectMap(h,$row.tickid) $tickid
        set columnObjectMap(h,$row.tickcolor) $cellColorInactive

        # Create the cell text for this row, if we have a font.
        if {$previewCellFont != ""} {
            set textid [$editor create text $cellx1 $cellyc -font $previewCellFont -anchor w]
            set columnObjectMap(h,$row.textid) $textid
            set columnObjectMap(h,$row.textstring) ""
        }
    }    
}

# Creates a new column in the editor.
# args:     col - The index of the column to create.
proc ::SeqEditPreview::createColumn {col} {

    # Import global variables.
    variable editor
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable columnObjectMap
    variable numberRows
    variable headerColorInactive
    variable cellColorInactive
    variable previewHeaderFont
    variable previewCellFont
    
    # Set the starting location.
    set x $headerCellWidth
    set y 2
    
    # Create the header cell.
    set cellx1 [expr $x+$col*$cellWidth]
    set cellx2 [expr $cellx1+$cellWidth-1]
    set cellxc [expr $cellx1+($cellWidth/2)]
    set celly1 $y
    set celly2 [expr $headerCellHeight-2]
    set cellyc [expr $celly1+(($celly2-$celly1)/2)]
    set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $headerColorInactive -outline $headerColorInactive]
    set textid [$editor create text $cellxc $cellyc -font $previewHeaderFont -anchor center]
    
    # Create the separator and tick lines.
    set separatorid [$editor create line $cellx1 [expr $celly2+1] [expr $cellx2+1] [expr $celly2+1] -fill $headerColorInactive]
    set tickid [$editor create line $cellx2 [expr $celly2-1] $cellx2 [expr $celly2+1] -fill $headerColorInactive]
    
    # Store the header cell objects.
    set columnObjectMap($col,h.active) 0
    set columnObjectMap($col,h.boxid) $boxid
    set columnObjectMap($col,h.textid) $textid    
    set columnObjectMap($col,h.textstring) ""
    set columnObjectMap($col,h.separatorid) $separatorid    
    set columnObjectMap($col,h.tickid) $tickid
    set columnObjectMap($col,h.boxcolor) $headerColorInactive
    
    # If we are overlapping a text object from the previous column header, bring it to the front.
    if {$col > 0} {
        $editor raise $columnObjectMap([expr $col-1],h.textid) $boxid
    }
    
    # Go through each row and create its components for this column.
    set y $headerCellHeight
    for {set row 0} {$row < $numberRows} {incr row} {
    
        # Create the cell for this row.
        set celly1 $y
        set celly2 [expr $celly1+$cellHeight-1]
        set cellyc [expr $celly1+($cellHeight/2)]
        set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $cellColorInactive -outline $cellColorInactive]
        set y [expr $celly2+1]
    
        # Store the row cell objects.
        set columnObjectMap($col,$row.boxid) $boxid
        set columnObjectMap($col,$row.active) 0
        set columnObjectMap($col,$row.boxcolor) $cellColorInactive
        
        # Create the cell text for this row, if we have a font.
        if {$previewCellFont != ""} {
            set textid [$editor create text $cellxc $cellyc -font $previewCellFont -anchor center]
            set columnObjectMap($col,$row.textid) $textid
            set columnObjectMap($col,$row.textstring) ""
        }
    }    
}

# Delete the cells in the current editor.
proc ::SeqEditPreview::deleteCells {} {
    
    # Import global variables.
    variable editor
    variable columnObjectMap

    # Get a list of all of the objects on the canvas.
    set objectNames [array names columnObjectMap]
    
    # Delete each object.
    foreach objectName $objectNames {
        if {[string first "id" $objectName] != -1} {
            $editor delete $columnObjectMap($objectName)
        }
    }    

    # Reinitialize the object map.
    unset columnObjectMap
    array set columnObjectMap {}
}


# Redraws the widget.
proc ::SeqEditPreview::redraw {} {

    # Import global variables.
    variable editor
    variable columnObjectMap
    variable firstElement
    variable firstSequence
    variable numberRows
    variable sequenceIDs
    variable numberSequences
    variable numberElements
    variable numberCols    
    variable headerColorActive
    variable headerColorInactive
    variable headerColorForeground
    variable cellColorActive
    variable cellColorInactive
    variable cellColorForeground
    variable colorMapHandler
    variable sequenceColorMap
    variable previewCellFont
    
    # Draw the column header row.
    set elementIndex $firstElement
    for {set col 0} {$col < $numberCols} {incr col} {
        
        # See if this column has data in it.
        if {$elementIndex < $numberElements} {
            
            # Get the header text.
            set headertext ""
            if {$elementIndex == 0 || [expr $elementIndex%10] == 9} {
                set headertext "[expr $elementIndex+1]"
            }
            
            # Update the parts of the cell that have changed.
            set columnObjectMap($col,h.active) 1
            if {$columnObjectMap($col,h.textstring) != $headertext} {
                set columnObjectMap($col,h.textstring) $headertext
                $editor itemconfigure $columnObjectMap($col,h.textid) -text $headertext
            }
            if {$columnObjectMap($col,h.boxcolor) != $headerColorForeground} {
                set columnObjectMap($col,h.boxcolor) $headerColorForeground
                $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerColorActive
                $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerColorActive
                $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerColorForeground
                $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerColorForeground
            }
            
        } elseif {$columnObjectMap($col,h.active) == 1} {
         
             # Draw the cell as inactive.
             set columnObjectMap($col,h.active) 0
             $editor itemconfigure $columnObjectMap($col,h.textid) -text ""
             $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerColorInactive
             $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerColorInactive
             $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerColorInactive
             $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerColorInactive
             
        }
        incr elementIndex
    }
        
    # Go through each row and draw it.
    for {set row 0} {$row < $numberRows} {incr row} {
    
        # Figure out which sequence goes into this row.
        set sequenceIndex [expr $firstSequence+$row]
        
        # See if this row has a sequence in it.
        if {$sequenceIndex < $numberSequences} {
        
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $sequenceIndex]
        
            # Get the sequence name.
            set sequenceName [SeqData::getName $sequenceID]
            
            # Update the parts of the header cell that have changed.
            set columnObjectMap(h,$row.active) 1
            if {$previewCellFont != ""} {
                if {$columnObjectMap(h,$row.textstring) != $sequenceName} {
                    set columnObjectMap(h,$row.textstring) $sequenceName
                    $editor itemconfigure $columnObjectMap(h,$row.textid) -text $sequenceName
                }
            }
            if {$columnObjectMap(h,$row.boxcolor) != $headerColorActive} {
                set columnObjectMap(h,$row.boxcolor) $headerColorActive
                set columnObjectMap(h,$row.separatorcolor) $cellColorForeground
                set columnObjectMap(h,$row.tickcolor) $cellColorForeground
                $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $headerColorActive
                $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $headerColorActive
                $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellColorForeground
                $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellColorForeground
            }

            # Get the sequence.
            set sequence [lrange [SeqData::getSeq $sequenceID] $firstElement [expr $firstElement+$numberCols-1]]

            # Go through each column that has an element in it.
            set col 0
            set elementIndex $firstElement
            foreach element $sequence {

                #Get some info about the element.
                set elementColor "#FFFFFF"
                if {$colorMapHandler != ""} {
                    set elementColor $sequenceColorMap($sequenceID,$elementIndex)
                }
                if {$element == "-"} {
                    if {$previewCellFont == ""} {
                        set element ""
                    } else {
                        set element "."
                    }
                } else {
                    if {$previewCellFont == "" && $elementColor == "#FFFFFF"} {
                        set elementColor "#F4F4F4"
                    }
                }
                
                # Update the parts of the cell that have changed.
                set columnObjectMap($col,$row.active) 1
                if {$previewCellFont != ""} {            
                    if {$columnObjectMap($col,$row.textstring) != $element} {
                        set columnObjectMap($col,$row.textstring) $element
                        $editor itemconfigure $columnObjectMap($col,$row.textid) -text $element
                    }
                }
                if {$columnObjectMap($col,$row.boxcolor) != $elementColor} {
                    set columnObjectMap($col,$row.boxcolor) $elementColor
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $elementColor
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $elementColor
                }
                
                incr col
                incr elementIndex
            }
            
            # Go through the rest of the columns and make them inactive.
            for {} {$col < $numberCols} {incr col} {
                if {$columnObjectMap($col,$row.active) == 1} {
            
                    # Draw the cell as inactive.
                    set columnObjectMap($col,$row.active) 0
                    if {$previewCellFont != ""} {
                        set columnObjectMap($col,$row.textstring) ""
                        $editor itemconfigure $columnObjectMap($col,$row.textid) -text ""
                    }
                    set columnObjectMap($col,$row.boxcolor) $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellColorInactive
                } else {
                    break
                }
            }
        
        } else {
        
            # Draw the header cell as inactive.
            if {$columnObjectMap(h,$row.active) == 1} {
                set columnObjectMap(h,$row.active) 0
                if {$previewCellFont != ""} {
                    set columnObjectMap(h,$row.textstring) ""
                    $editor itemconfigure $columnObjectMap(h,$row.textid) -text ""
                }
                set columnObjectMap(h,$row.boxcolor) $cellColorInactive
                set columnObjectMap(h,$row.separatorcolor) $cellColorInactive
                set columnObjectMap(h,$row.tickcolor) $cellColorInactive
                $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $cellColorInactive
                $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $cellColorInactive
                $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellColorInactive
                $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellColorInactive
            }
            
            # Go through each column.            
            for {set col 0} {$col < $numberCols} {incr col} {

                if {$columnObjectMap($col,$row.active) == 1} {
            
                    # Draw the cell as inactive.
                    set columnObjectMap($col,$row.active) 0
                    if {$previewCellFont != ""} {
                        set columnObjectMap($col,$row.textstring) ""
                        $editor itemconfigure $columnObjectMap($col,$row.textid) -text ""
                    }
                    set columnObjectMap($col,$row.boxcolor) $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellColorInactive
                    $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellColorInactive
                } else {
                    break
                }
            }
        }
    }
}

# This method is called be the window manager when a component of the widget has been reconfigured.
# args:     a_name - The name of the component that was reconfigured.
#           a_width - The new width of the component.
#           a_height - The new height of the component.
proc ::SeqEditPreview::component_configured {a_name a_width a_height} {

    # Import global variables.
    variable editor
    variable width
    variable height
    variable cellWidth
    variable cellHeight
    variable headerCellWidth
    variable headerCellHeight
    variable numberCols
    variable numberRows
    variable firstElement
    variable numberElements
    variable firstSequence
    variable numberSequences
    
    
    # Check to see if the window is being resized.
    if {$a_name == $editor && ($a_width != $width || $a_height != $height)} {
    
        # Save the new width and height.
        set width $a_width
        
        set height $a_height

        # See if the number of rows or columns has changed.
        if {$numberCols != [expr (($width-$headerCellWidth)/$cellWidth)+1] || $numberRows != [expr (($height-$headerCellHeight)/$cellHeight)+1]} {
        
            # Save the new number of rows and columns.
            set numberCols [expr (($width-$headerCellWidth)/$cellWidth)+1]
            set numberRows [expr (($height-$headerCellHeight)/$cellHeight)+1]

            # Make sure we are not out of scroll range.
            if {$numberElements > $numberCols} {
                if {$firstElement > ($numberElements-$numberCols+1)} {set firstElement [expr $numberElements-$numberCols+1]}
            } else {
                set firstElement 0
            }
            if {$numberSequences > $numberRows} {
                if {$firstSequence > ($numberSequences-$numberRows+1)} {set firstSequence [expr $numberSequences-$numberRows+1]}
            } else {
                set firstSequence 0
            }

            # Create the new editor and redraw it.
            deleteCells
            setScrollbars
            createCells
            redraw
        }
    }
}

# This method is called be the horizontal scroll bar when its state has changed.
proc ::SeqEditPreview::scroll_horzizontal {{action 0} {amount 0} {type 0}} {

    # Import global variables.
    variable firstElement
    variable numberCols
    variable numberElements
    
    # Perform the scroll.
    if {$action == "scroll" && ($type == "units" || $type == "unit")} {
        set firstElement [expr $firstElement+$amount]
    } elseif {$action == "scroll" && ($type == "pages" || $type == "page")} {
        set firstElement [expr $firstElement+($numberCols-2)*$amount]
    } elseif {$action == "moveto"} {
        set firstElement [expr int(($numberElements+1)*$amount)]
    }
    
    # Make sure we didn't scroll out of range.
    if {$firstElement < 0} { set firstElement 0 }
    if {$firstElement > ($numberElements-$numberCols+1)} {set firstElement [expr $numberElements-$numberCols+1]}
    
    # Set the scroll bars.
    setScrollbars
    redraw
}

# This method is called be the vertical scroll bar when its state has changed.
proc ::SeqEditPreview::scroll_vertical {{action 0} {amount 0} {type 0}} {

    # Import global variables.
    variable firstSequence
    variable numberRows
    variable numberSequences
    
    # Perform the scroll.
    if {$action == "scroll" && ($type == "units" || $type == "unit")} {
        set firstSequence [expr $firstSequence+$amount]
    } elseif {$action == "scroll" && ($type == "pages" || $type == "page")} {
        set firstSequence [expr $firstSequence+($numberRows-2)*$amount]
    } elseif {$action == "moveto"} {
        set firstSequence [expr int(($numberSequences+1)*$amount)]
    }

    # Make sure we didn't scroll out of range.
    if {$firstSequence < 0} { set firstSequence 0 }
    if {$firstSequence > ($numberSequences-$numberRows+1)} {set firstSequence [expr $numberSequences-$numberRows+1]}
    
    # Set the scroll bars.
    setScrollbars
    redraw
}
