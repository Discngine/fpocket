############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide seqedit 1.0
package require seqedit_widget 1.0
package require seqedit_preview 1.0
package require seqdata 1.0
package require clustalw 1.0

# Entry point to sequence editor from the global package level.
proc seqedit_gui {} {
    return [::SeqEdit::createWindow]
}

# Define the SeqEdit package.
namespace eval ::SeqEdit {
    
    # Export the namespace functions.
    namespace export createWindow

    # Handle to the sequence editor window.
    variable w

    # Handle to the sequence editor window.
    variable cellSize 16
    
    # The current color map handler.
    variable coloringMetric ""
    
    # Whether we should performing coloring by group.
    variable colorByGroup 0
    
    # Whether we should performing coloring on the marked sequences.
    variable colorByMarked 0
    
    # The original sequences used during alignment
    variable originalSequences {}
    
    # The lsitener variable.
    variable listener ""
    
    
    # Creates a new sequence editor window.
    proc createWindow {} {
    
        # Import global variables.
        variable w
        variable menubar
        variable cellSize
    
        # If a window already exsts, simply bring it to the front and return.    
        if { [winfo exists .seqeditgui] } {
            wm deiconify .seqeditgui
            return
        }
        
        # Create a new top level window.
        set w [toplevel .seqeditgui -menu .seqeditgui.menu]
        wm title $w "Sequence Editor"
        wm minsize $w 100 80
        
        # Create the window's menu.
        createMenu    
        
        # Create the main layout.
        frame $w.editor
        pack $w.editor -fill both -expand true -side right
        
        # Create the sequence editor widget.
        ::SeqEditWidget::createWidget $w.editor $cellSize $cellSize
        
        # Setup the sleection change listeners.
        ::SeqEditWidget::setSelectionNotificationCommand "::SeqEdit::notify_selectionChanged"
        ::SeqEditWidget::setSelectionNotificationVariable "::SeqEdit::listener"
        #trace variable "::SeqEdit::listener" w "::SeqEdit::notify_selectionChanged2"
        
        # Create a default group.
        ::SeqEditWidget::createGroup "Sequences"
        
        return $w
    }
    
    # Creates the menu for the main window.
    proc createMenu {} {
    
        # Import global variables.
        variable w
    
        # Top level menu.
        menu $w.menu -tearoff no
        $w.menu add cascade -label "File" -menu $w.menu.file
        $w.menu add cascade -label "Edit" -menu $w.menu.edit
        $w.menu add cascade -label "Utilities" -menu $w.menu.utilities
        $w.menu add cascade -label "Options" -menu $w.menu.options
        
        # File menu.
        menu $w.menu.file -tearoff no
        $w.menu.file add command -label "Open..." -command "::SeqEdit::menu_open"
        $w.menu.file add command -label "Add..." -command "::SeqEdit::menu_add"
        $w.menu.file add command -label "Save..." -command "::SeqEdit::menu_save"
        $w.menu.file add command -label "Save to PostScript..." -command "::SeqEditWidget::saveAsPS"
        $w.menu.file add separator
        $w.menu.file add command -label "Close" -command "::SeqEdit::menu_close"
        
        # Utilities menu.
        menu $w.menu.utilities -tearoff no
        $w.menu.utilities add command -label "Align With ClustalW" -command "::SeqEdit::menu_clustal"
        
        # Options menu.
        menu $w.menu.options -tearoff no
        $w.menu.options add cascade -label "Editing" -menu $w.menu.options.editing
        menu $w.menu.options.editing -tearoff no
        $w.menu.options.editing add radio -label "Off" -variable "::SeqEditWidget::editingMode" -value 0
        $w.menu.options.editing add radio -label "Gaps Only" -variable "::SeqEditWidget::editingMode" -value 1
        $w.menu.options.editing add radio -label "Full" -variable "::SeqEditWidget::editingMode" -value 2
        $w.menu.options add separator
        $w.menu.options add command -label "Zoom In" -accelerator "Ctrl +" -command "::SeqEdit::menu_zoomin"
        bind $w "<Control-plus>" {::SeqEdit::menu_zoomin}
        bind $w "<Control-equal>" {::SeqEdit::menu_zoomin}
        bind $w "<Command-plus>" {::SeqEdit::menu_zoomin}
        bind $w "<Command-equal>" {::SeqEdit::menu_zoomin}
        $w.menu.options add command -label "Zoom Out" -accelerator "Ctrl -" -command "::SeqEdit::menu_zoomout"
        bind $w "<Control-minus>" {::SeqEdit::menu_zoomout}
        bind $w "<Command-minus>" {::SeqEdit::menu_zoomout}
        $w.menu.options add separator
        $w.menu.options add cascade -label "Coloring" -menu $w.menu.options.colomap
        menu $w.menu.options.colomap -tearoff no
        $w.menu.options.colomap add checkbutton -label "Apply By Groups" -variable "::SeqEdit::colorByGroup" -onvalue 1 -offvalue 0
        $w.menu.options.colomap add checkbutton -label "Apply to Marked Only" -variable "::SeqEdit::colorByMarked" -onvalue 1 -offvalue 0
        $w.menu.options.colomap add separator
        $w.menu.options.colomap add command -label "None" -command "::SeqEdit::menu_changecolormap none"
        $w.menu.options.colomap add command -label "Type" -command "::SeqEdit::menu_changecolormap type"
        $w.menu.options.colomap add command -label "Conservation" -command "::SeqEdit::menu_changecolormap conservation"
        $w.menu.options.colomap add command -label "Percent Identity" -command "::SeqEdit::menu_changecolormap percentidentity"
        $w.menu.options.colomap add command -label "Selection" -command "::SeqEdit::menu_changecolormap selection"
        $w.menu.options.colomap add command -label "Import..." -command "::SeqEdit::menu_changecolormap import"
        $w.menu.options add separator
        $w.menu.options add cascade -label "Group By" -menu $w.menu.options.groupby
        menu $w.menu.options.groupby -tearoff no
        $w.menu.options.groupby add command -label "None" -command "::SeqEdit::menu_group none"
        $w.menu.options.groupby add command -label "Domain of Life" -command "::SeqEdit::menu_group domain"
        $w.menu.options.groupby add command -label "Customize..." -command "::SeqEdit::menu_group custom"
        
    }
    
    variable EDITINGMODE_NONE   0
    variable EDITINGMODE_GAP    1
    variable EDITINGMODE_ALL    2
    
    # The current editing mode
    variable editingMode $EDITINGMODE_NONE

    
    proc menu_open {} {
    
        set filename [tk_getOpenFile -filetypes {{{FASTA Files} {.fasta}} {{All Files} * }} -title "Open Sequence File"]
        if {$filename != ""} {
            set sequences [::SeqData::Fasta::loadSequences $filename]
            ::SeqEditWidget::setSequences $sequences
        }
    }
    
    proc menu_add {} {
    
        set filename [tk_getOpenFile -filetypes {{{FASTA Files} {.fasta}} {{All Files} * }} -title "Add Sequence File"]
        if {$filename != ""} {
            set sequences [::SeqData::Fasta::loadSequences $filename]
            ::SeqEditWidget::addSequences $sequences
        }
    }
    
    proc menu_close {} {
        # Import global variables.
        variable w
        
        # Close the window.
        destroy $w
    }
    
    proc menu_zoomin {} {
    
        # Import global variables.
        variable w
        variable cellSize
        
        if {$cellSize < 10} {
            set cellSize [expr $cellSize+1]
            ::SeqEditWidget::setCellSize $cellSize $cellSize
        } elseif {$cellSize >= 10 && $cellSize <= 28} {
            set cellSize [expr $cellSize+2]
            ::SeqEditWidget::setCellSize $cellSize $cellSize
        }
    }
    
    proc menu_zoomout {} {
    
        # Import global variables.
        variable w
        variable cellSize
        
        if {$cellSize > 4 && $cellSize <= 10} {
            set cellSize [expr $cellSize-1]
            ::SeqEditWidget::setCellSize $cellSize $cellSize
        } elseif {$cellSize >= 10} {
            set cellSize [expr $cellSize-2]
            ::SeqEditWidget::setCellSize $cellSize $cellSize
        }
    }
    
    proc menu_changecolormap {colorMapType} {
    
        # Import global variables.
        variable coloringMetric
        variable colorByGroup
        variable colorByMarked
        
        if {$colorByMarked} {
            set sequenceIDs [::SeqEditWidget::getMarkedSequences]
        } else {
            set sequenceIDs [::SeqEditWidget::getSequences]
        }
    
        if {$colorMapType == "none"} {
            set coloringMetric ""
            ::SeqEditWidget::resetColoring $sequenceIDs
        } elseif {$colorMapType == "type"} {
            set coloringMetric "::SeqEdit::Metric::Type::calculate"
            ::SeqEditWidget::setColoring $coloringMetric $sequenceIDs $colorByGroup
        } elseif {$colorMapType == "conservation"} {
            set coloringMetric "::SeqEdit::Metric::Conservation::calculate"
            ::SeqEditWidget::setColoring $coloringMetric $sequenceIDs $colorByGroup
        } elseif {$colorMapType == "percentidentity"} {
            set coloringMetric "::SeqEdit::Metric::PercentIdentity::calculate"
            ::SeqEditWidget::setColoring $coloringMetric $sequenceIDs $colorByGroup
        } elseif {$colorMapType == "selection"} {
            set coloringMetric "::SeqEdit::Metric::Selection::calculate"
            ::SeqEditWidget::setColoring $coloringMetric $sequenceIDs $colorByGroup
        } elseif {$colorMapType == "import"} {
            set coloringMetric "::SeqEdit::Metric::Import::calculate"
            ::SeqEditWidget::setColoring $coloringMetric $sequenceIDs $colorByGroup
        }
        
    }
    
    proc menu_group {groupType} {
    
        # Import global variables.
        variable w
        
        if {$groupType == "none"} {
            
            ::SeqEditWidget::setGroups {"Sequences"}
            
        } elseif {$groupType == "domain"} {
        
            # Create the groups.
            ::SeqEditWidget::setGroups {"Unknown Domain" "Eukaryota" "Archaea" "Bacteria" "Viruses"} 0 "Unknown Domain"
            
            # Go through each sequence in the unknown group and move it into the correct group, if it is known.
            set toE {}
            set toA {}
            set toB {}
            set toV {}
            set sequenceIDs [::SeqEditWidget::getSequencesInGroup "Unknown Domain"]
            foreach sequenceID $sequenceIDs {
                set group [::SeqData::getDomainOfLife $sequenceID]
                if {$group == "Eukaryota"} {
                    lappend toE $sequenceID
                } elseif {$group == "Archaea"} {
                    lappend toA $sequenceID
                } elseif {$group == "Bacteria"} {
                    lappend toB $sequenceID
                } elseif {$group == "Viruses"} {
                    lappend toV $sequenceID
                }
            }
            
            # Move the sequences to the proper groups.
            ::SeqEditWidget::moveSequences $toE "Eukaryota"
            ::SeqEditWidget::moveSequences $toA "Archaea"
            ::SeqEditWidget::moveSequences $toB "Bacteria"
            ::SeqEditWidget::moveSequences $toV "Viruses"
            
            # Remove any groups that are empty.
            foreach groupName {"Unknown Domain" "Eukaryota" "Archaea" "Bacteria" "Viruses"} {
                if {[llength [::SeqEditWidget::getSequencesInGroup $groupName]] == 0} {
                    ::SeqEditWidget::deleteGroup $groupName
                }
            }
            
            # Redraw the editor.
            ::SeqEditWidget::redraw
            
        } elseif {$groupType == "custom"} {
            set newGroups [CustomizeGroups::showCustomizeGroupsDialog $w [::SeqEditWidget::getGroups]]
            if {$newGroups != {}} {
                ::SeqEditWidget::setGroups $newGroups
            }
        }   
    }
    
    proc menu_clustal {} {
    
        # Import global variables.
        variable w
        
        array set options [Clustal::showClustalOptionsDialog $w [::SeqEditWidget::getGroups]]
        if {[info exists options(alignmentType)] && $options(alignmentType) == "multiple"} {
            performMultipleAlignment $options(multipleAlignmentType) $options(showPreview)
        } elseif {[info exists options(alignmentType)] && $options(alignmentType) == "profile"} {
            performProfileAlignment $options(profile) $options(showPreview)
        }
    }
    
    proc performMultipleAlignment {alignmentType showPreview} {
        
        # Import global variables.
        variable colorMap
        variable cellSize
        variable coloringMetric
        variable originalSequences
        
        if {$alignmentType == "marked"} {
            set originalSequences [::SeqEditWidget::getMarkedSequences]
        } else {
            set originalSequences [::SeqEditWidget::getSequences]
        }
        
        if {$showPreview == 1} {
            set previewWindow [::SeqEditPreview::createPreviewWindow $coloringMetric $cellSize "::SeqEdit::accept_alignment"]
            tkwait visibility $previewWindow
            set alignedSequences [::ClustalW::alignSequences $originalSequences]
            ::SeqEditPreview::setSequences $alignedSequences
        } else {
            set alignedSequences [::ClustalW::alignSequences $originalSequences]
            accept_alignment $alignedSequences
        }
    }
    
    proc performProfileAlignment {profile showPreview} {
        
        # Import global variables.
        variable colorMap
        variable cellSize
        variable coloringMetric
        variable originalSequences
    
        set profileSequences [::SeqEditWidget::getSequencesInGroup $profile]
        set markedSequences [::SeqEditWidget::getMarkedSequences]
        set originalSequences [concat $profileSequences $markedSequences]
        
        if {$showPreview == 1} {
            set previewWindow [::SeqEditPreview::createPreviewWindow $coloringMetric $cellSize "::SeqEdit::accept_alignment"]
            tkwait visibility $previewWindow
            set alignedSequences [::ClustalW::alignSequencesToProfile $profileSequences $markedSequences]
            ::SeqEditPreview::setSequences $alignedSequences
        } else {
            set alignedSequences [::ClustalW::alignSequencesToProfile $profileSequences $markedSequences]
            accept_alignment $alignedSequences
        }
    }
    
    proc accept_alignment {alignedSequences} {
    
        # Import global variables.
        variable originalSequences
    
        # Put the new sequences in the editor, replace the old ones.    
        ::SeqEditWidget::replaceSequences $originalSequences $alignedSequences
    }
    
    proc menu_save {} {
    
        set filename [tk_getSaveFile -filetypes {{{FASTA Files} {.fasta}}} -title "Save Sequence File"]
        if {$filename != ""} {
            SeqData::Fasta::saveSequences [::SeqEditWidget::getSequences] $filename
        }
    }
    
    proc notify_selectionChanged {} {
        puts "SeqEdit Info) The current selection in the sequence editor has changed."
        #puts "  -[::SeqEditWidget::getSelectionType]"
        #puts "  -[::SeqEditWidget::getSelectedSequences]"
        #puts "  -[::SeqEditWidget::getSelectedPositions]"
        #set cells [::SeqEditWidget::getSelectedCells]
        #puts "  -$cells"
        #puts "  -[lindex $cells 0],[lindex $cells 1],[lindex $cells 2],[lindex $cells 3]"
        #puts "  -[lindex [lindex $cells 1] 0],[lindex [lindex $cells 1] 1]"
    }
    
    proc notify_selectionChanged2 {varName index operation} {
        puts "SeqEdit Info) The current selection in the sequence editor has changed. (2)"
    }
}
