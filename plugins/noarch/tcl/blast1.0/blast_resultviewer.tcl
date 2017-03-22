############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide blast 1.0
package require seqdata 1.0
package require libbiokit 1.0

# Declare global variables for this package.
namespace eval ::Blast::ResultViewer {

    # Export the package functions.
    namespace export showBlastResultViewerDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
        
    # Setup some default colors.
    variable headerBoxColor "#D3D3D3"
    variable headerEScoreBoxColor "white"
    variable headerEScoreBarColor "#000060"
    variable headerForegroundColor "black"
    variable headerInactiveColor "#D3D3D3"
    variable cellAlignedBoxColor "#FFFFFF"    
    variable cellUnalignedBoxColor "#E0E0E0"
    variable cellAlignedTextColor "#000060"
    variable cellUnalignedTextColor "#909090"
    variable cellForegroundColor "black"
    variable cellInactiveColor "#C0C0C0"
    
    # The original sequences.
    variable originalQuerySequenceID {}
    variable originalBlastSequenceIDs {}
    
    # The sequence ids that are being previewed.
    variable sequenceIDs {}
    
    # The map for storing the combined sequence and BLAST data.
    variable sequenceData
    array set sequenceData {}
    
    # The first element that is part of the BLAST alignment.
    variable firstAlignedElement 0

    # The last element that is part of the BLAST alignment.
    variable lastAlignedElement 0

    # The name of the editor widget.
    variable widget
    
    # The name of the editor portion of the widget.
    variable editor

    # The current width of the sequence
    variable width

    # Handle to the sequence editor window.
    variable height

    # The size of the border around the viewer.
    variable border 4
    
    # The size of a cell in the window.
    variable cellSize 16
    
    # The total width of the header cell.
    variable headerCellWidth 200
    
    # The widths of the columns in the header cell.
    variable headerCellColumnWidths {100 50 50}
    
    # The names of the columns in the ehader cell.
    variable headerCellColumnNames {"Name" "E Score"}
    
    # The current height of a cell in the editor.
    variable headerCellHeight 18
    
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
    
	# The font being used for the header display.
	variable headerFont ""
	
	# The font being used for the cell display.
	variable cellFont ""
    
    # The current filters.
    variable eScoreFilter 2
    variable nrCutoffFilter 100
    variable superkingdomFilters {All}
    variable kingdomFilters {All}
    variable phylumFilters {All}
    
    # The minimum viewer height
    variable minViewerHeight 150
    

    # Creates a dialog to get the user's options for running the data import.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showBlastResultViewerDialog {parent querySequenceID blastSequenceIDs {eScore 2}} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable cellSize
        variable firstElement
        variable firstAlignedElement
        variable originalQuerySequenceID
        variable originalBlastSequenceIDs
        variable sequenceIDs
        variable eScoreFilter
        variable nrCutoffFilter
        variable superkingdomFilters
        variable kingdomFilters
        variable phylumFilters
        set finished 0
        set originalQuerySequenceID $querySequenceID
        set originalBlastSequenceIDs $blastSequenceIDs
        
        # Reset some variables.
        set firstElement 0
        set firstAlignedElement 0
        set eScoreFilter $eScore
        set nrCutoffFilter 100
        set superkingdomFilters {All}
        set kingdomFilters {All}
        set phylumFilters {All}
    
        # Create a new top level window.
        set w [createModalDialog ".blastresultviewer" "BLAST Search Results"]
        
        # Create the components.
        frame $w.center
        frame $w.bottom
            frame $w.bottom.controls
                frame $w.bottom.controls.panel
                    label $w.bottom.controls.panel.matches -text "Matches:"
                    label $w.bottom.controls.panel.lg1 -text "Filter Options"
                    frame $w.bottom.controls.panel.g1 -relief sunken -borderwidth 1
                        frame $w.bottom.controls.panel.g1.b -relief raised -borderwidth 1
                            label $w.bottom.controls.panel.g1.b.lescore -text "E Score:"
                            label $w.bottom.controls.panel.g1.b.vescore -text ""
                            scale $w.bottom.controls.panel.g1.b.escore -orient horizontal -length 180 -sliderlength 10 -from -20 -to 2 -resolution 1 -tickinterval 0 -showvalue 0 -variable "::Blast::ResultViewer::eScoreFilter" -command "::Blast::ResultViewer::scale_escore"
                            label $w.bottom.controls.panel.g1.b.lnr -text "Percentage to return:"
                            label $w.bottom.controls.panel.g1.b.vnr -text ""
                            scale $w.bottom.controls.panel.g1.b.nr -orient horizontal -length 180 -sliderlength 10 -from 0 -to 100 -resolution 1 -tickinterval 0 -showvalue 0 -variable "::Blast::ResultViewer::nrCutoffFilter" -command "::Blast::ResultViewer::scale_nrcutoff"
                            label $w.bottom.controls.panel.g1.b.ltaxonomy1 -text "Domain:"
                            frame $w.bottom.controls.panel.g1.b.taxonomy1 -relief sunken -borderwidth 1
                                listbox $w.bottom.controls.panel.g1.b.taxonomy1.list -selectmode multiple -exportselection FALSE -width 30 -height 5 -yscrollcommand "$w.bottom.controls.panel.g1.b.taxonomy1.scroll set"
                                scrollbar $w.bottom.controls.panel.g1.b.taxonomy1.scroll -command "$w.bottom.controls.panel.g1.b.taxonomy1.list yview"
                            label $w.bottom.controls.panel.g1.b.ltaxonomy2 -text "Kingdom:"
                            frame $w.bottom.controls.panel.g1.b.taxonomy2 -relief sunken -borderwidth 1
                                listbox $w.bottom.controls.panel.g1.b.taxonomy2.list -selectmode multiple -exportselection FALSE -width 30 -height 5 -yscrollcommand "$w.bottom.controls.panel.g1.b.taxonomy2.scroll set"
                                scrollbar $w.bottom.controls.panel.g1.b.taxonomy2.scroll -command "$w.bottom.controls.panel.g1.b.taxonomy2.list yview"
                            label $w.bottom.controls.panel.g1.b.ltaxonomy3 -text "Phylum:"
                            frame $w.bottom.controls.panel.g1.b.taxonomy3 -relief sunken -borderwidth 1
                                listbox $w.bottom.controls.panel.g1.b.taxonomy3.list -selectmode multiple -exportselection FALSE -width 30 -height 5 -yscrollcommand "$w.bottom.controls.panel.g1.b.taxonomy3.scroll set"
                                scrollbar $w.bottom.controls.panel.g1.b.taxonomy3.scroll -command "$w.bottom.controls.panel.g1.b.taxonomy3.list yview"
                            button $w.bottom.controls.panel.g1.b.apply -text "Apply Filter" -command "::Blast::ResultViewer::but_applyfilter"
                    label $w.bottom.controls.panel.lg2 -text "View Options"
                    frame $w.bottom.controls.panel.g2 -relief sunken -borderwidth 1
                        frame $w.bottom.controls.panel.g2.b -relief raised -borderwidth 1
                            label $w.bottom.controls.panel.g2.b.lzoom -text "Zoom:"
                            scale $w.bottom.controls.panel.g2.b.zoom -orient horizontal -length 180 -sliderlength 10 -from 4 -to 20 -resolution 1 -tickinterval 4 -showvalue 0 -variable "::Blast::ResultViewer::cellSize"
                            button $w.bottom.controls.panel.g2.b.apply -text "Apply View" -command "::Blast::ResultViewer::but_applyview"
                                
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "Accept" -pady 2 -command "::Blast::ResultViewer::but_ok"
                button $w.bottom.buttons.cancel -text "Discard" -pady 2 -command "::Blast::ResultViewer::but_cancel"
        
        # Layout the components.
        pack $w.center                        -fill both -expand true -side top
        pack $w.bottom                        -fill x -side bottom
        pack $w.bottom.controls               -fill x -side top
        pack $w.bottom.controls.panel         -fill x -side top
        grid $w.bottom.controls.panel.matches -column 1 -row 1 -sticky nw -padx 5 -pady 10
        grid $w.bottom.controls.panel.lg1     -column 1 -row 2 -sticky nw -padx 5
        grid $w.bottom.controls.panel.g1      -column 1 -row 3 -sticky nw -padx 5
        pack $w.bottom.controls.panel.g1.b              -fill both -expand true -side left
        grid $w.bottom.controls.panel.g1.b.lescore      -column 1 -row 1 -sticky w -padx 10
        grid $w.bottom.controls.panel.g1.b.vescore      -column 2 -row 1 -sticky w
        grid $w.bottom.controls.panel.g1.b.escore       -column 3 -row 1 -sticky w -padx 15
        grid $w.bottom.controls.panel.g1.b.lnr          -column 1 -row 2 -sticky w -padx 10
        grid $w.bottom.controls.panel.g1.b.vnr          -column 2 -row 2 -sticky w
        grid $w.bottom.controls.panel.g1.b.nr           -column 3 -row 2 -sticky w -padx 15
        grid $w.bottom.controls.panel.g1.b.ltaxonomy1   -column 1 -row 3 -sticky nw -padx 10 -pady 4
        grid $w.bottom.controls.panel.g1.b.taxonomy1    -column 2 -row 3 -sticky w -pady 4 -columnspan 2
        pack $w.bottom.controls.panel.g1.b.taxonomy1.list         -fill both -expand true -side left
        pack $w.bottom.controls.panel.g1.b.taxonomy1.scroll       -side right -fill y
        grid $w.bottom.controls.panel.g1.b.ltaxonomy2   -column 1 -row 4 -sticky nw -padx 10 -pady 4
        grid $w.bottom.controls.panel.g1.b.taxonomy2    -column 2 -row 4 -sticky w -pady 4 -columnspan 2
        pack $w.bottom.controls.panel.g1.b.taxonomy2.list         -fill both -expand true -side left
        pack $w.bottom.controls.panel.g1.b.taxonomy2.scroll       -side right -fill y
        grid $w.bottom.controls.panel.g1.b.ltaxonomy3   -column 1 -row 5 -sticky nw -padx 10 -pady 4
        grid $w.bottom.controls.panel.g1.b.taxonomy3    -column 2 -row 5 -sticky w -pady 4 -columnspan 2
        pack $w.bottom.controls.panel.g1.b.taxonomy3.list         -fill both -expand true -side left
        pack $w.bottom.controls.panel.g1.b.taxonomy3.scroll       -side right -fill y
        grid $w.bottom.controls.panel.g1.b.apply        -column 2 -row 6 -sticky w -pady 4 -columnspan 2
        grid $w.bottom.controls.panel.lg2     -column 2 -row 2 -sticky nw -padx 5
        grid $w.bottom.controls.panel.g2      -column 2 -row 3 -sticky nw -padx 5
        pack $w.bottom.controls.panel.g2.b              -fill both -expand true -side left
        grid $w.bottom.controls.panel.g2.b.lzoom        -column 1 -row 1 -sticky nw -padx 10 -pady 3
        grid $w.bottom.controls.panel.g2.b.zoom         -column 2 -row 1 -sticky nw -padx 10
        grid $w.bottom.controls.panel.g2.b.apply        -column 2 -row 2 -sticky w -pady 4
        
        pack $w.bottom.buttons                -side bottom
        pack $w.bottom.buttons.accept         -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel         -side left -pady 5

        # Create the preview grid.
        createViewerWidget $w.center
    
        # Fill taxonomy lists.
        fillTaxonomyListboxes $blastSequenceIDs
        
        # Bind the window closing event.
        bind $w <Destroy> {"::Blast::ResultViewer::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Set the sequences in the window.
        setSequences $querySequenceID $blastSequenceIDs
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::Blast::ResultViewer::finished"
        #puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"
        
        # Destroy the dialog.
        destroyDialog        
        
        # Return the options.
        if {$finished == 1} {
            return [lrange $sequenceIDs 1 end]
        } else {
            return {}
        }        
    }
    
    # Creates a new modal dialog window given a prefix for the window name and a title for the dialog.
    # args:     prefix - The prefix for the window name of this dialog. This should start with a ".".
    #           dialogTitle - The title for the dialog.
    # return:   The name of the newly created dialog.
    proc createModalDialog {prefix dialogTitle} {

        # Import global variables.        
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        
        # Find a name for the dialog
        set unique 0
        set childList [winfo children .]
        while {[lsearch $childList $prefix$unique] != -1} {
            incr unique
        }

        # Create the dialog.        
        set w [toplevel $prefix$unique]
        
        # Set the dialog title.
        wm title $w $dialogTitle
        
        # Make the dialog modal.
        set oldFocus [focus]
        set oldGrab [grab current $w]
        if {$oldGrab != ""} {
            set grabStatus [grab status $oldGrab]
        }
        grab $w
        focus $w
        
        return $w
    }
    
    # Centers the dialog.
    proc centerDialog {{parent ""}} {
        
        # Import global variables.        
        variable w
        
        # Set the width and height, since calculating doesn't work properly.
        set width 652
        set height [expr 500+22]
        
        # Figure out the x and y position.
        if {$parent != ""} {
            set cx [expr {int ([winfo rootx $parent] + [winfo width $parent] / 2)}]
            set cy [expr {int ([winfo rooty $parent] + [winfo height $parent] / 2)}]
            set x [expr {$cx - int ($width / 2)}]
            set y [expr {$cy - int ($height / 2)}]
            
        } else {
            set x [expr {int (([winfo screenwidth $w] - [winfo reqwidth $w]) / 2)}]
            set y [expr {int (([winfo screenheight $w] - [winfo reqheight $w]) / 2)}]
        }
        
        # Make sure we are within the screen bounds.
        if {$x < 0} {
            set x 0
        } elseif {[expr $x+$width] > [winfo screenwidth $w]} {
            set x [expr [winfo screenwidth $w]-$width]
        }
        if {$y < 22} {
            set y 22
        } elseif {[expr $y+$height] > [winfo screenheight $w]} {
            set y [expr [winfo screenheight $w]-$height]
        }
            
        wm geometry $w +${x}+${y}
        wm positionfrom $w user
    }
    
    # Destroys the dialog. This method releases the dialog resources and restores the system handlers.
    proc destroyDialog {} {
        
        # Import global variables.        
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        
        # Destroy the dialog.
        catch {focus $oldFocus}
        catch {
            bind $w <Destroy> {}
            destroy $w
        }
        if {$oldGrab != ""} {
            if {$grabStatus == "global"} {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }
    }
    
    proc but_ok {} {
    
        # Import global variables.
        variable w
        variable finished
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Close the window.    
        set finished 0
    }

    proc fillTaxonomyListboxes {sequenceIDs} {

        # Import global variables.        
        variable w
        
        # Initialize the three lists.
        set superkingdoms {}
        set kingdoms {}
        set phylums {}
        
        # Variable to indicate that we have unknown entries.
        set unknownSuperkingdoms 0
        set unknownKingdoms 0
        set unknownPhylums 0
        
        # Go through the seqences and construct the lists.
        foreach sequenceID $sequenceIDs {
            
            set foundSuperkingdom 0
            set foundKingdom 0
            set foundPhylum 0
            
            # Go through the lineage.
            set lineage [::SeqData::getLineage $sequenceID 0 1]
            foreach level $lineage {
                if {[lindex $level 1] == "superkingdom"} {
                    set foundSuperkingdom 1
                    if {[lsearch $superkingdoms [lindex $level 0]] == -1} {
                        lappend superkingdoms [lindex $level 0]
                    }
                } elseif {[lindex $level 1] == "kingdom"} {
                    set foundKingdom 1
                    if {[lsearch $kingdoms [lindex $level 0]] == -1} {
                        lappend kingdoms [lindex $level 0]
                    }
                } elseif {[lindex $level 1] == "phylum"} {
                    set foundPhylum 1
                    if {[lsearch $phylums [lindex $level 0]] == -1} {
                        lappend phylums [lindex $level 0]
                    }
                }
            }
            
            # If we didn't find a level, mark that we need an unknown in that list.
            if {!$foundSuperkingdom} {
                set unknownSuperkingdoms 1
            }
            if {!$foundKingdom} {
                set unknownKingdoms 1
            }
            if {!$foundPhylum} {
                set unknownPhylums 1
            }
        }
        
        # Set the listboxes.
        $w.bottom.controls.panel.g1.b.taxonomy1.list insert end All
        if {$unknownSuperkingdoms} {
            $w.bottom.controls.panel.g1.b.taxonomy1.list insert end Unknown
        }
        foreach name [lsort -dictionary $superkingdoms] {
            $w.bottom.controls.panel.g1.b.taxonomy1.list insert end $name
        }
        $w.bottom.controls.panel.g1.b.taxonomy1.list selection set 0
        
        $w.bottom.controls.panel.g1.b.taxonomy2.list insert end All
        if {$unknownKingdoms} {
            $w.bottom.controls.panel.g1.b.taxonomy2.list insert end Unknown
        }
        foreach name [lsort -dictionary $kingdoms] {
            $w.bottom.controls.panel.g1.b.taxonomy2.list insert end $name
        }
        $w.bottom.controls.panel.g1.b.taxonomy2.list selection set 0
        
        $w.bottom.controls.panel.g1.b.taxonomy3.list insert end All
        if {$unknownPhylums} {
            $w.bottom.controls.panel.g1.b.taxonomy3.list insert end Unknown
        }
        foreach name [lsort -dictionary $phylums] {
            $w.bottom.controls.panel.g1.b.taxonomy3.list insert end $name
        }
        $w.bottom.controls.panel.g1.b.taxonomy3.list selection set 0
    }

    # Sets the sequences that are currently being displayed by the editor.
    # args:     a_sequenceIDs - A list of the sequence ids.
    proc setSequences {querySequenceID blastSequenceIDs} {
    
        # Import global variables.
        variable w
        variable sequenceIDs
        variable sequenceData
        variable numberSequences
        variable firstSequence
        variable numberElements
        variable firstElement
        variable firstAlignedElement
        variable lastAlignedElement
        variable eScoreFilter
        variable nrCutoffFilter
        variable superkingdomFilters
        variable kingdomFilters
        variable phylumFilters
        
        # See if we need to keep the first element in synch with the blast alignment.
        set synchFirstElement 0
        if {$firstElement == $firstAlignedElement} {
            set synchFirstElement 1
        }
        
        # Filter out any undesired sequences.
        set filteredSequenceIDs {}
        foreach blastSequenceID $blastSequenceIDs {
            
            set passedFilters 1
            
            # Check the e score.
            if {[SeqData::getAnnotation $blastSequenceID blast-e-score] > [expr pow(10,$eScoreFilter)]} {
                set passedFilters 0
            }
            
            # Check the superkingdom.
            set superkingdom [::SeqData::getLineageRank $blastSequenceID "superkingdom"]
            if {$superkingdom == ""} {
                set superkingdom "Unknown"
            }
            if {[lsearch $superkingdomFilters "All"] == -1 && [lsearch $superkingdomFilters $superkingdom] == -1} {
                set passedFilters 0
            }
            
            # Check the kingdom.
            set kingdom [::SeqData::getLineageRank $blastSequenceID "kingdom"]
            if {$kingdom == ""} {
                set kingdom "Unknown"
            }
            if {[lsearch $kingdomFilters "All"] == -1 && [lsearch $kingdomFilters $kingdom] == -1} {
                set passedFilters 0
            }
            
            # Check the phylum.
            set phylum [::SeqData::getLineageRank $blastSequenceID "phylum"]
            if {$phylum == ""} {
                set phylum "Unknown"
            }
            if {[lsearch $phylumFilters "All"] == -1 && [lsearch $phylumFilters $phylum] == -1} {
                set passedFilters 0
            }
            
            # If we passed all of the filters, add it to the list.
            if {$passedFilters} {
                lappend filteredSequenceIDs $blastSequenceID
            }
        }
        
        # Run the sequence qr on the sequences, if needed.
        if {$nrCutoffFilter < 100} {
            
            # Create versions of the sequences containing the BLAST aligned data.
            set alignedSequenceIDs {}
            foreach filteredSequenceID $filteredSequenceIDs {
                set alignedSequenceID [::SeqData::duplicateSequence $filteredSequenceID]
                ::SeqData::setSeq $alignedSequenceID [::SeqData::getAnnotation $filteredSequenceID blast-alignment]
                lappend alignedSequenceIDs $alignedSequenceID
            }
            
            # Get an nr set.
            set nrAlignedSequenceIDs [::Libbiokit::getNonRedundantSequences $alignedSequenceIDs 1 $nrCutoffFilter 1.0 0 1]
            
            # Match the NR set with the source sequences.
            set nrFilteredSequenceIDs {}
            foreach nrAlignedSequenceID $nrAlignedSequenceIDs {
                lappend nrFilteredSequenceIDs [lindex $filteredSequenceIDs [lsearch $alignedSequenceIDs $nrAlignedSequenceID]]
            }
            
            # Use the nr set.
            set filteredSequenceIDs $nrFilteredSequenceIDs
        }
        
        # Set the total matches label.
        $w.bottom.controls.panel.matches configure -text "Matches: [llength $filteredSequenceIDs]"
        
        # Create a list of all the sequences.
        set sequenceIDs [concat $querySequenceID $filteredSequenceIDs]
        
        # Get the total number of sequences.
        set numberSequences [llength $sequenceIDs]
        
        # Get the maximum length before the aligned section.
        set maxLengthBeforeAligment 0
        foreach sequenceID $sequenceIDs {
            if {[expr [::SeqData::getAnnotation $sequenceID blast-start-position]-1] > $maxLengthBeforeAligment} {
                set maxLengthBeforeAligment [expr [::SeqData::getAnnotation $sequenceID blast-start-position]-1]
            }
        }
        
        # Get the maximum length after the aligned section.
        set maxLengthAfterAligment 0
        foreach sequenceID $sequenceIDs {
            if {[expr [::SeqData::getSeqLength $sequenceID]-[::SeqData::getAnnotation $sequenceID blast-end-position]] > $maxLengthAfterAligment} {
                set maxLengthAfterAligment [expr [::SeqData::getSeqLength $sequenceID]-[::SeqData::getAnnotation $sequenceID blast-end-position]]
            }
        }
        
        # Initialize the sequence data map.
        unset sequenceData
        array set sequenceData {}
        
        # Construct version of the sequences with the BLAST aligned portions inserted.
        foreach sequenceID $sequenceIDs {
            set sequence [concat [getSpaces [expr $maxLengthBeforeAligment-([::SeqData::getAnnotation $sequenceID blast-start-position]-1)]] \
                                 [lrange [::SeqData::getSeq $sequenceID] 0 [expr [::SeqData::getAnnotation $sequenceID blast-start-position]-2]] \
                                 [::SeqData::getAnnotation $sequenceID blast-alignment] \
                                 [lrange [::SeqData::getSeq $sequenceID] [::SeqData::getAnnotation $sequenceID blast-end-position] [expr [::SeqData::getSeqLength $sequenceID]-1]] \
                                 [getSpaces [expr $maxLengthAfterAligment-([::SeqData::getSeqLength $sequenceID]-[::SeqData::getAnnotation $sequenceID blast-end-position])]]]
           set sequenceData($sequenceID) $sequence
        }
        
        # Save the total number of elements as well as the first and last alignment positions.
        set numberElements [llength $sequenceData([lindex $sequenceIDs 0])]
        set firstAlignedElement $maxLengthBeforeAligment
        set lastAlignedElement [expr $firstAlignedElement+[llength [::SeqData::getAnnotation [lindex $sequenceIDs 0] blast-alignment]]-1]
                        
        # Synch the first element to the blast alignment, if necessary.
        if {$synchFirstElement} {
            set firstElement $firstAlignedElement
        }
        set firstSequence 0
        
        # Set the scrollbars.
        setScrollbars
        
        #Redraw the widget.
        redraw
    }
    
    proc getSpaces {number} {
        set ret {}
        for {set i 0} {$i < $number} {incr i} {
            lappend ret " "
        }
        return $ret
    }
    
    # Creates a new sequence viewer.
    # args:     a_widget - The frame that the widget should be shown in.
    proc createViewerWidget {a_widget} {
    
        # Import global variables.
        variable widget
        variable editor
        variable width
        variable height
        variable minViewerHeight
        variable cellSize
        variable cellInactiveColor
        set widget $a_widget 
    
        #Create the components of the widget.
        frame $widget.center
        set editor [canvas $widget.center.editor -background $cellInactiveColor -height $minViewerHeight]
        scrollbar $widget.center.yscroll -orient vertical -command {::Blast::ResultViewer::scroll_vertical}
        
        frame $widget.bottom
        scrollbar $widget.bottom.xscroll -orient horizontal -command {::Blast::ResultViewer::scroll_horzizontal}
        frame $widget.bottom.spacer -width [$widget.center.yscroll cget -width]
        
        pack $widget.center -side top -fill both -expand true
        pack $widget.center.editor -side left -fill both -expand true
        pack $widget.center.yscroll -side right -fill y
        
        pack $widget.bottom -side bottom -fill x
        pack $widget.bottom.spacer -side right
        pack $widget.bottom.xscroll -side left -fill x -expand true
        
        # Listen for resize events.
        bind $editor <Configure> {::Blast::ResultViewer::component_configured %W %w %h}
        
        # Calculate some basic information about the editor.
        set width [$editor cget -width]
        set height [$editor cget -height]
        
        # Set the cell size.
        setCellSize $cellSize false
    
        # Set the scrollbars.
        setScrollbars
        
        # Create the grid.
        createCells
    }

    # Creates a new sequence editor.
    # args:     a_cellSize - The new cell size.
    proc setCellSize {a_cellSize {redraw true}} {
    
        # Import global variables.
        variable editor
        variable width
        variable height
        variable cellSize
        variable headerCellWidth
        variable headerCellHeight
        variable numberCols
        variable numberRows
        variable headerFont
        variable cellFont
        variable firstElement
        variable firstSequence
        variable numberSequences
        variable numberElements
        set cellSize $a_cellSize
        
        # Set up any settings that are based on the cell size.
        set numberCols [expr (($width-$headerCellWidth)/$cellSize)+1]
        set numberRows [expr (($height-$headerCellHeight)/$cellSize)+1]
        
        # Get the default font.
        set fontChecker [$editor create text 0 0 -anchor nw -text ""]
        set defaultFont [$editor itemcget $fontChecker -font]
        $editor delete $fontChecker
        
        # Create new fonts.
        if {$headerFont != ""} {font delete $headerFont}
        if {$cellFont != ""} {font delete $cellFont}
        set headerFont [font create blastPreviewHeaderFont -family [lindex $defaultFont 0] -size [lindex $defaultFont 1]]
        if {$cellSize >= 12} {
            set cellFont [font create blastPreviewCellFont -family [lindex $defaultFont 0] -size [expr ($cellSize+3)/2]]
        } else {
            set cellFont ""
        }
        
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
    
    # This method is called be the window manager when a component of the widget has been reconfigured.
    # args:     a_name - The name of the component that was reconfigured.
    #           a_width - The new width of the component.
    #           a_height - The new height of the component.
    proc component_configured {a_name a_width a_height} {
    
        # Import global variables.
        variable editor
        variable width
        variable height
        variable cellSize
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
            if {$numberCols != [expr (($width-$headerCellWidth)/$cellSize)+1] || $numberRows != [expr (($height-$headerCellHeight)/$cellSize)+1]} {
            
                # Save the new number of rows and columns.
                set numberCols [expr (($width-$headerCellWidth)/$cellSize)+1]
                set numberRows [expr (($height-$headerCellHeight)/$cellSize)+1]
    
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
    
    # Sets the scroll bars.
    proc setScrollbars {} {
        
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
    
    # This method is called be the horizontal scroll bar when its state has changed.
    proc scroll_horzizontal {{action 0} {amount 0} {type 0}} {
    
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
    proc scroll_vertical {{action 0} {amount 0} {type 0}} {
    
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
    
    # Delete the cells in the current editor.
    proc deleteCells {} {
        
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
    
    # Creates a new grid of cells in the editor
    proc createCells {} {
        
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
    proc createHeaderColumn {} {
    
        # Import global variables.
        variable editor
        variable cellSize
        variable border
        variable headerCellWidth
        variable headerCellColumnWidths
        variable headerCellColumnNames
        variable headerCellHeight
        variable columnObjectMap
        variable numberRows
        variable headerBoxColor
        variable headerForegroundColor
        variable headerEScoreBoxColor
        variable headerEScoreBarColor
        variable cellInactiveColor
        variable headerFont
        variable cellFont
        
        # Create the header cell.
        set cellx1 $border
        set cellx2 [expr $cellx1+$headerCellWidth]
        set cellxc [expr ($cellx1+$cellx2)/2]
        set celly1 $border
        set celly2 [expr $celly1+$headerCellHeight]
        set cellyc [expr ($celly1+$celly2)/2]
        
        # Create the box.
        set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $headerBoxColor -outline $headerBoxColor]
        set columnObjectMap(h,h.boxid) $boxid
        
        # Create the column names.
        set columnx $cellx1
        for {set i 0} {$i < [llength $headerCellColumnNames]} {incr i} {
            set textid [$editor create text $columnx $cellyc -font $headerFont -anchor w -text [lindex $headerCellColumnNames $i]]
            set columnObjectMap(h,h.text.$i.id) $textid
            incr columnx [lindex $headerCellColumnWidths $i]
        }
        
        # Create the separator and tick lines.
        set separatorid [$editor create line $cellx1 [expr $celly2-1] $cellx2 [expr $celly2-1] -fill $headerForegroundColor]
        set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] $celly2 -fill $headerForegroundColor]
        set columnObjectMap(h,h.separatorid) $separatorid    
        set columnObjectMap(h,h.tickid) $tickid
        
        # Go through each row and create its row header.
        for {set row 0} {$row < $numberRows} {incr row} {
        
            # Create the cell for this row.
            set celly1 [expr $border+$headerCellHeight+($cellSize*$row)]
            set celly2 [expr $celly1+$cellSize]
            set cellyc [expr ($celly1+$celly2)/2]
            set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $cellInactiveColor -outline $cellInactiveColor]
            set separatorid [$editor create line $cellx1 [expr $celly2-1] $cellx2 [expr $celly2-1] -fill $cellInactiveColor]
            set tickid [$editor create line [expr $cellx2-1] $celly1 [expr $cellx2-1] $celly2 -fill $cellInactiveColor]
            set columnObjectMap(h,$row.active) 0
            set columnObjectMap(h,$row.boxid) $boxid
            set columnObjectMap(h,$row.boxcolor) $cellInactiveColor
            set columnObjectMap(h,$row.separatorid) $separatorid
            set columnObjectMap(h,$row.separatorcolor) $cellInactiveColor
            set columnObjectMap(h,$row.tickid) $tickid
            set columnObjectMap(h,$row.tickcolor) $cellInactiveColor

            # Create the cell text for this row, if we have a font.
            if {$cellFont != ""} {
                set columnx $cellx1
                for {set i 0} {$i < [llength $headerCellColumnNames]} {incr i} {
                    set textid [$editor create text $columnx $cellyc -font $cellFont -anchor w]
                    set columnObjectMap(h,$row.text.$i.id) $textid
                    set columnObjectMap(h,$row.text.$i.string) ""
                    incr columnx [lindex $headerCellColumnWidths $i]
                }
            }
            
            # Create the escore bar.
            set boxBorder [expr $cellSize/8]
            set boxx1 [expr $cellx2-[lindex $headerCellColumnWidths end]]
            set boxx2 [expr $boxx1+[expr [lindex $headerCellColumnWidths end]-$boxBorder-1]]
            set boxid [$editor create rectangle $boxx1 [expr $celly1+$boxBorder] $boxx2 [expr $celly2-$boxBorder-1] -fill $cellInactiveColor -outline $cellInactiveColor]
            set columnObjectMap(h,$row.escoreboxid) $boxid
            set columnObjectMap(h,$row.escoreboxcolor) $cellInactiveColor
            set barBorder [expr $cellSize/4]
            set barx1 [expr $boxx1+1]
            set barx2 [expr $boxx2-1]
            set bary1 [expr $celly1+$barBorder]
            set bary2 [expr $celly2-$barBorder-1]
            set barid [$editor create rectangle $barx1 $bary1 $barx2 $bary2 -fill $cellInactiveColor -outline $cellInactiveColor]
            set columnObjectMap(h,$row.escorebarid) $barid
            set columnObjectMap(h,$row.escorebarx1) $barx1
            set columnObjectMap(h,$row.escorebarx2) $barx2
            set columnObjectMap(h,$row.escorebary1) $bary1
            set columnObjectMap(h,$row.escorebary2) $bary2
            set columnObjectMap(h,$row.escorebarlength) [expr $barx2-$barx1]
        }    
    }
    
    # Creates a new column in the editor.
    # args:     col - The index of the column to create.
    proc createColumn {col} {
    
        # Import global variables.
        variable editor
        variable cellSize
        variable border
        variable headerCellWidth
        variable headerCellHeight
        variable columnObjectMap
        variable numberRows
        variable headerInactiveColor
        variable cellInactiveColor
        variable headerFont
        variable cellFont
        
        # Create the header cell.
        set cellx1 [expr $border+$headerCellWidth+($col*$cellSize)]
        set cellx2 [expr $cellx1+$cellSize]
        set cellxc [expr ($cellx1+$cellx2)/2]
        set celly1 $border
        set celly2 [expr $celly1+$headerCellHeight]
        set cellyc [expr ($celly1+$celly2)/2]
        set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $headerInactiveColor -outline $headerInactiveColor]
        set textid [$editor create text $cellxc $cellyc -font $headerFont -anchor center]
        set columnObjectMap($col,h.active) 0
        set columnObjectMap($col,h.boxid) $boxid
        set columnObjectMap($col,h.boxcolor) $headerInactiveColor
        set columnObjectMap($col,h.textid) $textid    
        set columnObjectMap($col,h.textstring) ""
        
        # Create the separator and tick lines.
        set separatorid [$editor create line $cellx1 [expr $celly2-1] $cellx2 [expr $celly2-1] -fill $headerInactiveColor]
        set tickid [$editor create line [expr $cellx2-1] [expr $celly2-3] [expr $cellx2-1] [expr $celly2-1] -fill $headerInactiveColor]
        set columnObjectMap($col,h.separatorid) $separatorid    
        set columnObjectMap($col,h.tickid) $tickid
        
        # If we are overlapping a text object from the previous column header, bring it to the front.
        if {$col > 0} {
            $editor raise $columnObjectMap([expr $col-1],h.textid) $boxid
        }
        
        # Go through each row and create its components for this column.
        for {set row 0} {$row < $numberRows} {incr row} {
        
            # Create the cell for this row.
            set celly1 [expr $border+$headerCellHeight+($cellSize*$row)]
            set celly2 [expr $celly1+$cellSize]
            set cellyc [expr ($celly1+$celly2)/2]
            set boxid [$editor create rectangle $cellx1 $celly1 $cellx2 $celly2 -fill $cellInactiveColor -outline $cellInactiveColor]
            set columnObjectMap($col,$row.boxid) $boxid
            set columnObjectMap($col,$row.active) 0
            set columnObjectMap($col,$row.boxcolor) $cellInactiveColor
            
            # Create the cell text for this row, if we have a font.
            if {$cellFont != ""} {
                set textid [$editor create text $cellxc $cellyc -font $cellFont -anchor center -fill $cellInactiveColor]
                set columnObjectMap($col,$row.textid) $textid
                set columnObjectMap($col,$row.textstring) ""
                set columnObjectMap($col,$row.textcolor) $cellInactiveColor
            } else {
                set barid [$editor create rectangle $cellx1 [expr $celly1+($cellSize/4)] $cellx2 [expr $celly2-($cellSize/4)]  -fill $cellInactiveColor -outline $cellInactiveColor]
                set columnObjectMap($col,$row.barid) $barid
                set columnObjectMap($col,$row.barcolor) $cellInactiveColor
            }
        }    
    }
    
    # Redraws the widget.
    proc redraw {} {
    
        # Import global variables.
        variable editor
        variable columnObjectMap
        variable firstElement
        variable firstSequence
        variable numberRows
        variable sequenceIDs
        variable sequenceData
        variable numberSequences
        variable numberElements
        variable firstAlignedElement
        variable lastAlignedElement
        variable numberCols    
        variable headerBoxColor
        variable headerEScoreBoxColor
        variable headerEScoreBarColor
        variable headerInactiveColor
        variable headerForegroundColor
        variable cellAlignedBoxColor
        variable cellUnalignedBoxColor
        variable cellAlignedTextColor
        variable cellUnalignedTextColor
        variable cellForegroundColor
        variable cellInactiveColor
        variable cellFont
        
        # Draw the column header row.
        for {set col 0; set elementIndex $firstElement} {$col < $numberCols} {incr col; incr elementIndex} {
            
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
                if {$columnObjectMap($col,h.boxcolor) != $headerForegroundColor} {
                    set columnObjectMap($col,h.boxcolor) $headerForegroundColor
                    $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerBoxColor
                    $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerBoxColor
                    $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerForegroundColor
                    $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerForegroundColor
                }
                
            } elseif {$columnObjectMap($col,h.active) == 1} {
             
                # Draw the cell as inactive.
                set columnObjectMap($col,h.active) 0
                set columnObjectMap($col,h.boxcolor) $headerInactiveColor
                $editor itemconfigure $columnObjectMap($col,h.textid) -text ""
                $editor itemconfigure $columnObjectMap($col,h.boxid) -fill $headerInactiveColor
                $editor itemconfigure $columnObjectMap($col,h.boxid) -outline $headerInactiveColor
                $editor itemconfigure $columnObjectMap($col,h.separatorid) -fill $headerInactiveColor
                $editor itemconfigure $columnObjectMap($col,h.tickid) -fill $headerInactiveColor
            }
        }
            
        # Go through each row and draw it.
        for {set row 0} {$row < $numberRows} {incr row} {
        
            # Figure out which sequence goes into this row.
            set sequenceIndex [expr $firstSequence+$row]
            
            # See if this row has a sequence in it.
            if {$sequenceIndex < $numberSequences} {
            
                # Get the sequence id.
                set sequenceID [lindex $sequenceIDs $sequenceIndex]
            
                # Mark that the row is active.
                set columnObjectMap(h,$row.active) 1
                
                # Update the header box, if necessary.
                if {$columnObjectMap(h,$row.boxcolor) != $headerBoxColor} {
                    set columnObjectMap(h,$row.boxcolor) $headerBoxColor
                    set columnObjectMap(h,$row.separatorcolor) $headerForegroundColor
                    set columnObjectMap(h,$row.tickcolor) $headerForegroundColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $headerBoxColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $headerBoxColor
                    $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $headerForegroundColor
                    $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $headerForegroundColor
                }
                
                # Update the header text, if necessary.
                set sequenceName [SeqData::getName $sequenceID]
                set eScore [SeqData::getAnnotation $sequenceID blast-e-score]
                if {$cellFont != ""} {
                    if {$columnObjectMap(h,$row.text.0.string) != $sequenceName} {
                        set columnObjectMap(h,$row.text.0.string) $sequenceName
                        $editor itemconfigure $columnObjectMap(h,$row.text.0.id) -text $sequenceName
                    }
                    if {$columnObjectMap(h,$row.text.1.string) != $eScore} {
                        set columnObjectMap(h,$row.text.1.string) $eScore
                        $editor itemconfigure $columnObjectMap(h,$row.text.1.id) -text $eScore
                    }                    
                }
                
                # Update the escore box, if necessary.
                if {$columnObjectMap(h,$row.escoreboxcolor) != $headerEScoreBoxColor} {
                    set columnObjectMap(h,$row.escoreboxcolor) $headerEScoreBoxColor
                    $editor itemconfigure $columnObjectMap(h,$row.escoreboxid) -fill $headerEScoreBoxColor
                    $editor itemconfigure $columnObjectMap(h,$row.escoreboxid) -outline $headerForegroundColor
                    $editor itemconfigure $columnObjectMap(h,$row.escorebarid) -fill $headerEScoreBarColor
                    $editor itemconfigure $columnObjectMap(h,$row.escorebarid) -outline $headerEScoreBarColor
                }
                
                # Update the escore bar length, if necessary.
                set barLength 100
                if {$eScore != "query" && $eScore != 0.0} {
                    set barLength [expr -log($eScore)]
                    if {$barLength < 0} {
                        set barLength 0
                    }
                }
                if {$columnObjectMap(h,$row.escorebarlength) != $barLength} {
                    set columnObjectMap(h,$row.escorebarlength) $barLength
                    set x2 [expr $columnObjectMap(h,$row.escorebarx1)+$barLength]
                    if {$x2 > $columnObjectMap(h,$row.escorebarx2)} {
                        set x2 $columnObjectMap(h,$row.escorebarx2)
                    }
                    $editor coords $columnObjectMap(h,$row.escorebarid) $columnObjectMap(h,$row.escorebarx1) $columnObjectMap(h,$row.escorebary1) $x2 $columnObjectMap(h,$row.escorebary2)
                }
    
                # Get the sequence.
                set sequence [lrange $sequenceData($sequenceID) $firstElement [expr $firstElement+$numberCols-1]]
    
                # Set up some variables.
                set col 0
                set elementIndex $firstElement
                
                # See if we are showing text in the cells.
                if {$cellFont != ""} {
                        
                    # Go through each column that has an element in it.
                    foreach element $sequence {

                        # Figure out the colors.
                        if {$elementIndex >= $firstAlignedElement && $elementIndex <= $lastAlignedElement} {
                            set boxColor $cellAlignedBoxColor
                            set textColor $cellAlignedTextColor
                        } else {
                            set boxColor $cellUnalignedBoxColor
                            set textColor $cellUnalignedTextColor
                        }
    
                        # Change gaps to a period.
                        if {$element == "-"} {
                            set element "."
                        }
                     
                        # Update the box.
                        set columnObjectMap($col,$row.active) 1
                        if {$columnObjectMap($col,$row.boxcolor) != $boxColor} {
                            set columnObjectMap($col,$row.boxcolor) $boxColor
                            $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $boxColor
                            $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $boxColor
                        }
                        
                        # Update the text.
                        if {$columnObjectMap($col,$row.textstring) != $element} {
                            set columnObjectMap($col,$row.textstring) $element
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -text $element
                        }
                        if {$columnObjectMap($col,$row.textcolor) != $textColor} {
                            set columnObjectMap($col,$row.textcolor) $textColor
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -fill $textColor
                        }
                        
                        incr col
                        incr elementIndex
                    }
                        
                # Otherwise we must not be showing text.
                } else {

                    # Go through each column that has an element in it.
                    set col 0
                    set elementIndex $firstElement
                    foreach element $sequence {

                        # Figure out the colors.
                        if {$elementIndex >= $firstAlignedElement && $elementIndex <= $lastAlignedElement} {
                            set boxColor $cellAlignedBoxColor
                            if {$element == "-" || $element == " "} {
                                set barColor $cellAlignedBoxColor
                            } else {
                                set barColor $cellAlignedTextColor
                            }
                        } else {
                            set boxColor $cellUnalignedBoxColor
                            if {$element == "-" || $element == " "} {
                                set barColor $cellUnalignedBoxColor
                            } else {
                                set barColor $cellUnalignedTextColor
                            }
                        }
                        
                        # Update the box.
                        set columnObjectMap($col,$row.active) 1
                        if {$columnObjectMap($col,$row.boxcolor) != $boxColor} {
                            set columnObjectMap($col,$row.boxcolor) $boxColor
                            $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $boxColor
                            $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $boxColor
                        }
                        
                        # Update the bar.
                        if {$columnObjectMap($col,$row.barcolor) != $barColor} {
                            set columnObjectMap($col,$row.barcolor) $barColor
                            $editor itemconfigure $columnObjectMap($col,$row.barid) -fill $barColor
                            $editor itemconfigure $columnObjectMap($col,$row.barid) -outline $barColor
                        }
                                        
                        incr col
                        incr elementIndex
                    }
                }
                
                # Go through the rest of the columns and make them inactive.
                for {} {$col < $numberCols} {incr col} {
                    if {$columnObjectMap($col,$row.active) == 1} {
                
                        # Draw the cell as inactive.
                        set columnObjectMap($col,$row.active) 0
                        if {$cellFont != ""} {
                            set columnObjectMap($col,$row.textstring) ""
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -text ""
                        }
                        set columnObjectMap($col,$row.boxcolor) $cellInactiveColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellInactiveColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellInactiveColor
                    } else {
                        break
                    }
                }
            
            } else {
            
                # Draw the header cell as inactive.
                if {$columnObjectMap(h,$row.active) == 1} {
                    set columnObjectMap(h,$row.active) 0
                    if {$cellFont != ""} {
                        set columnObjectMap(h,$row.text.0.string) ""
                        $editor itemconfigure $columnObjectMap(h,$row.text.0.id) -text ""
                        set columnObjectMap(h,$row.text.1.string) ""
                        $editor itemconfigure $columnObjectMap(h,$row.text.1.id) -text ""
                    }
                    set columnObjectMap(h,$row.boxcolor) $cellInactiveColor
                    set columnObjectMap(h,$row.separatorcolor) $cellInactiveColor
                    set columnObjectMap(h,$row.tickcolor) $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -fill $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.boxid) -outline $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.separatorid) -fill $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.tickid) -fill $cellInactiveColor
                    set columnObjectMap(h,$row.escoreboxcolor) $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.escoreboxid) -fill $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.escoreboxid) -outline $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.escorebarid) -fill $cellInactiveColor
                    $editor itemconfigure $columnObjectMap(h,$row.escorebarid) -outline $cellInactiveColor
                }
                
                # Go through each column.            
                for {set col 0} {$col < $numberCols} {incr col} {
    
                    if {$columnObjectMap($col,$row.active) == 1} {
                
                        # Draw the cell as inactive.
                        set columnObjectMap($col,$row.active) 0
                        if {$cellFont != ""} {
                            set columnObjectMap($col,$row.textstring) ""
                            $editor itemconfigure $columnObjectMap($col,$row.textid) -text ""
                        }
                        set columnObjectMap($col,$row.boxcolor) $cellInactiveColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -fill $cellInactiveColor
                        $editor itemconfigure $columnObjectMap($col,$row.boxid) -outline $cellInactiveColor
                    } else {
                        break
                    }
                }
            }
        }
    }
    
    proc scale_escore {value} {
        
        # Import global variables.
        variable w
        
        # Update the label.
        if {$value >= 0} {        
            $w.bottom.controls.panel.g1.b.vescore configure -text [expr pow(10,$value)]
        } else {
            $w.bottom.controls.panel.g1.b.vescore configure -text "e$value"
        }
    }
    
    proc scale_nrcutoff {value} {
        
        # Import global variables.
        variable w
        
        # Update the label.
        $w.bottom.controls.panel.g1.b.vnr configure -text "$value"
    }
    
    proc but_applyfilter {} {
    
        # Import global variables.
        variable w
        variable originalQuerySequenceID
        variable originalBlastSequenceIDs
        variable superkingdomFilters
        variable kingdomFilters
        variable phylumFilters
        
        # Initialize the filters.
        set superkingdomFilters {}
        set kingdomFilters {}
        set phylumFilters {}
        
        # Create the taxonomy filters from the listboxes.
        set indices [$w.bottom.controls.panel.g1.b.taxonomy1.list curselection]
        foreach index $indices {
            lappend superkingdomFilters [$w.bottom.controls.panel.g1.b.taxonomy1.list get $index]
        }
        set indices [$w.bottom.controls.panel.g1.b.taxonomy2.list curselection]
        foreach index $indices {
            lappend kingdomFilters [$w.bottom.controls.panel.g1.b.taxonomy2.list get $index]
        }
        set indices [$w.bottom.controls.panel.g1.b.taxonomy3.list curselection]
        foreach index $indices {
            lappend phylumFilters [$w.bottom.controls.panel.g1.b.taxonomy3.list get $index]
        }

        # Apply the new filter.
        setSequences $originalQuerySequenceID $originalBlastSequenceIDs
    }    
    
    proc but_applyview {} {
        
        # Import global variables.
        variable w
        variable cellSize
        
        # Update the cell size.
        ::Blast::ResultViewer::setCellSize $cellSize
    }    
}
