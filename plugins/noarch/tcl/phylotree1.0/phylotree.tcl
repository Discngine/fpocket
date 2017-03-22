############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide phylotree 1.0

# Entry point to sequence editor from the global package level.
proc phylotree_gui {} {
    return [::PhyloTree::createWindow]
}

# Define the PhyloTree package.
namespace eval ::PhyloTree {

    # Export the package functions.
    namespace export createWindow

    # Handle to the window.
    variable w
    variable menuSuffix
    variable scale 512
    variable fontSize 12
    
    # The trees available in the window.
    variable treeIDs {}
    
    # The current tree.
    variable activeTreeID -1
    
    # Flag to indicate whether the native menu or a simulated menu should be used.
    variable useNativeMenu 1
        
    proc windowExists {} {
        return [winfo exists .phylotreegui]
    }
    
    # Creates a new sequence editor window.
    proc createWindow {{a_useNativeMenu 1}} {
    
        # Import global variables.
        variable w
        variable scale
        variable fontSize
        variable useNativeMenu
    
        # If a window already exsts, simply bring it to the front and return.    
        if { [winfo exists .phylotreegui] } {
            wm deiconify .phylotreegui
            return
        }
        
        # Reset the tree list.
        set treeIDs {}
        set activeTreeID -1
        
        set useNativeMenu $a_useNativeMenu
        
        # Create a new top level window.
        if {$useNativeMenu} {
            set w [toplevel .phylotreegui -menu .phylotreegui.menu]
        } else {
            set w [toplevel .phylotreegui]
            frame $w.menu -relief raised -bd 2
            pack $w.menu -padx 1 -fill x -side top
        }
        wm title $w "Tree Viewer"
        wm minsize $w 600 400
        
        # Create the window's menu.
        createMenu    
        
        # Create the main layout.
        frame $w.tree
        pack $w.tree -fill both -expand 1 -side right  -padx {0 1} -pady {0 1}
        
        # Create the sequence editor widget.
        ::PhyloTree::Widget::createWidget $w.tree $scale $fontSize
        
        # Bind the window closing event.
        bind $w <Destroy> {::PhyloTree::menu_exit}        
    }
    
    # Creates the menu for the main window.
    proc createMenu {} {
    
        # Import global variables.
        variable w
        variable useNativeMenu
        variable menuSuffix
        
        # Top level menu.
        if {$useNativeMenu} {
            menu $w.menu -tearoff no
            $w.menu add cascade -label "File" -menu $w.menu.file
            $w.menu add cascade -label "View" -menu $w.menu.view
            $w.menu add cascade -label "Trees" -menu $w.menu.trees
            set menuSuffix ""
        } else {
            menubutton $w.menu.file -text "File" -underline 0 -menu $w.menu.file.menu
            $w.menu.file config -width 5
            pack $w.menu.file -side left
            menubutton $w.menu.view -text "View" -menu $w.menu.view.menu
            $w.menu.view config -width 5
            pack $w.menu.view -side left
            menubutton $w.menu.trees -text "Trees" -underline 0 -menu $w.menu.trees.menu
            $w.menu.trees config -width 5
            pack $w.menu.trees -side left
            set menuSuffix ".menu"
        }
        
        # File menu.
        menu $w.menu.file$menuSuffix -tearoff no
        $w.menu.file$menuSuffix add command -label "Open..." -command "::PhyloTree::menu_open"
        $w.menu.file$menuSuffix add command -label "Save..." -command "::PhyloTree::menu_save current"
        $w.menu.file$menuSuffix add command -label "Save All..." -command "::PhyloTree::menu_save all"
        $w.menu.file$menuSuffix add command -label "Close" -command "::PhyloTree::menu_close"
        $w.menu.file$menuSuffix add separator
        $w.menu.file$menuSuffix add command -label "Save As PostScript..." -command "::PhyloTree::Widget::saveAsPS"
        $w.menu.file$menuSuffix add separator
        $w.menu.file$menuSuffix add command -label "Quit Tree Viewer" -command "::PhyloTree::menu_exit"
        
        # View menu.
        menu $w.menu.view$menuSuffix -tearoff no
        
        
        $w.menu.view$menuSuffix add command -label "Distance Matrix" -command "::PhyloTree::menu_viewmatrix"
        $w.menu.view$menuSuffix add separator
        $w.menu.view$menuSuffix add command -label "Zoom In" -accelerator "Ctrl +" -command "::PhyloTree::menu_zoomin"
        bind $w "<Control-plus>" {::PhyloTree::menu_zoomin}
        bind $w "<Control-equal>" {::PhyloTree::menu_zoomin}
        bind $w "<Command-plus>" {::PhyloTree::menu_zoomin}
        bind $w "<Command-equal>" {::PhyloTree::menu_zoomin}
        $w.menu.view$menuSuffix add command -label "Zoom Out" -accelerator "Ctrl -" -command "::PhyloTree::menu_zoomout"
        bind $w "<Control-minus>" {::PhyloTree::menu_zoomout}
        bind $w "<Command-minus>" {::PhyloTree::menu_zoomout}
        $w.menu.view$menuSuffix add command -label "Increase Scale" -accelerator "Ctrl 0" -command "::PhyloTree::menu_scaleup"
        bind $w "<Control-0>" {::PhyloTree::menu_scaleup}
        bind $w "<Command-0>" {::PhyloTree::menu_scaleup}
        $w.menu.view$menuSuffix add command -label "Decrease Scale" -accelerator "Ctrl 9" -command "::PhyloTree::menu_scaledown"
        bind $w "<Control-9>" {::PhyloTree::menu_scaledown}
        bind $w "<Command-9>" {::PhyloTree::menu_scaledown}
        $w.menu.view$menuSuffix add separator
        $w.menu.view$menuSuffix add checkbutton -label "Reverse Orientation" -variable "::PhyloTree::Widget::reverseOrientation" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
        $w.menu.view$menuSuffix add checkbutton -label "Show Internal Labels" -variable "::PhyloTree::Widget::showInternalLabels" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
        $w.menu.view$menuSuffix add checkbutton -label "Show Internal Nodes" -variable "::PhyloTree::Widget::showInternalNodes" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
        $w.menu.view$menuSuffix add separator
        $w.menu.view$menuSuffix add cascade -label "Leaf Text" -menu $w.menu.view$menuSuffix.leaflabels
        menu $w.menu.view$menuSuffix.leaflabels -tearoff no
        $w.menu.view$menuSuffix.leaflabels add checkbutton -label "Name" -variable "::PhyloTree::Widget::shownAttributes(name)" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
        $w.menu.view$menuSuffix add cascade -label "Leaf Color" -menu $w.menu.view$menuSuffix.leafcolor
        menu $w.menu.view$menuSuffix.leafcolor -tearoff no
        $w.menu.view$menuSuffix.leafcolor add command -label "Custom..." -command "::PhyloTree::menu_leafcolorcustom"
        $w.menu.view$menuSuffix add cascade -label "Background Color" -menu $w.menu.view$menuSuffix.colorby
        menu $w.menu.view$menuSuffix.colorby -tearoff no
        $w.menu.view$menuSuffix.colorby add command -label "Custom..." -command "::PhyloTree::menu_colorcustom"

        # Trees menu.
        menu $w.menu.trees$menuSuffix -tearoff no
        $w.menu.trees$menuSuffix add command -label "Next" -accelerator "Ctrl Tab" -command "::PhyloTree::menu_nexttree"
        bind $w "<Control-Tab>" {::PhyloTree::menu_nexttree}
        bind $w "<Command-Tab>" {::PhyloTree::menu_nexttree}
        $w.menu.trees$menuSuffix add command -label "Previous" -accelerator "Ctrl Shift Tab" -command "::PhyloTree::menu_previoustree"
        bind $w "<Control-Shift-Tab>" {::PhyloTree::menu_previoustree}
        bind $w "<Command-Shift-Tab>" {::PhyloTree::menu_previoustree}
        $w.menu.trees$menuSuffix add separator
    }
    
    proc addTrees {newTreeIDs} {
        
        # Import global variables.
        variable w
        variable treeIDs
        variable menuSuffix
        
        if {[llength $newTreeIDs] > 0} {
            
            # Go through the trees.
            foreach newTreeID $newTreeIDs {
                
                # Save the tree.
                lappend treeIDs $newTreeID
                
                # Add the tree to the menu.
                $w.menu.trees$menuSuffix add command -label [::PhyloTree::Data::getTreeName $newTreeID] -command "::PhyloTree::setActiveTree $newTreeID"
            }
            
            # Set this tree as active.
            setActiveTree [lindex $newTreeIDs 0]
        }
    }
    
    proc getActiveTree {} {
    
        # Import global variables.
        variable activeTreeID
        
        return $activeTreeID
    }
    
    proc setActiveTree {treeID} {
    
        # Import global variables.
        variable w
        variable menuSuffix
        variable treeIDs
        variable activeTreeID
        
        # Save the new index as the active tree.
        set activeTreeID $treeID
        
        # Remove old menu options.
        while {[$w.menu.view$menuSuffix.leaflabels entrycget 1 -label] != "Name"} {
            $w.menu.view$menuSuffix.leaflabels delete 1
        }
        while {[$w.menu.view$menuSuffix.leafcolor entrycget 1 -label] != "Custom..."} {
            $w.menu.view$menuSuffix.leafcolor delete 1
        }
        while {[$w.menu.view$menuSuffix.colorby entrycget 1 -label] != "Custom..."} {
            $w.menu.view$menuSuffix.colorby delete 1
        }
        
        # Set the window title and new menu options.
        if {$treeID != -1} {
            
            # Set the window title.
            wm title $w "Tree Viewer - [::PhyloTree::Data::getTreeName $activeTreeID]"
            
            # Set the menu options for this tree.
            foreach nodeAttribute [::PhyloTree::Data::getNodeAttributeKeys $activeTreeID] {
                $w.menu.view$menuSuffix.leaflabels add checkbutton -label $nodeAttribute -variable "::PhyloTree::Widget::shownAttributes($nodeAttribute)" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
                $w.menu.view$menuSuffix.leafcolor add radiobutton -label $nodeAttribute -variable "::PhyloTree::Widget::leafColoring" -value $nodeAttribute -command "::PhyloTree::Widget::redraw"
                $w.menu.view$menuSuffix.colorby add radiobutton -label $nodeAttribute -variable "::PhyloTree::Widget::backgroundColoring" -value $nodeAttribute -command "::PhyloTree::Widget::redraw"
            }
            
        } else {
            
            # Set the window title.
            wm title $w "Tree Viewer"
        }
        
        # Set the tree in the viewer.
        ::PhyloTree::Widget::setTree $activeTreeID
    }
    
    proc redraw {} {
    
        # Import global variables.
        variable w
        variable menuSuffix
        variable activeTreeID
        
        # Remove old menu options.
        while {[$w.menu.view$menuSuffix.leaflabels entrycget 1 -label] != "Name"} {
            $w.menu.view$menuSuffix.leaflabels delete 1
        }
        while {[$w.menu.view$menuSuffix.leafcolor entrycget 1 -label] != "Custom..."} {
            $w.menu.view$menuSuffix.leafcolor delete 1
        }
        while {[$w.menu.view$menuSuffix.colorby entrycget 1 -label] != "Custom..."} {
            $w.menu.view$menuSuffix.colorby delete 1
        }
        
        # Set the window title and new menu options.
        if {$activeTreeID != -1} {
            
            # Set the window title.
            wm title $w "Tree Viewer - [::PhyloTree::Data::getTreeName $activeTreeID]"
            
            # Set the menu options for this tree.
            foreach nodeAttribute [::PhyloTree::Data::getNodeAttributeKeys $activeTreeID] {
                $w.menu.view$menuSuffix.leaflabels add checkbutton -label $nodeAttribute -variable "::PhyloTree::Widget::shownAttributes($nodeAttribute)" -onvalue 1 -offvalue 0 -command "::PhyloTree::Widget::redraw"
                $w.menu.view$menuSuffix.leafcolor add radiobutton -label $nodeAttribute -variable "::PhyloTree::Widget::leafColoring" -value $nodeAttribute -command "::PhyloTree::Widget::redraw"
                $w.menu.view$menuSuffix.colorby add radiobutton -label $nodeAttribute -variable "::PhyloTree::Widget::backgroundColoring" -value $nodeAttribute -command "::PhyloTree::Widget::redraw"
            }
            
            # Redraw the widget.
            ::PhyloTree::Widget::redraw
        }        
    }
    
    proc menu_open {} {
    
        set filenames [tk_getOpenFile -multiple 1 -filetypes {{{Tree Files} {.dnd .ph .tre .nex .nxs .jet}} {{Phylip Tree Files} {.dnd .ph .tre}} {{NEXUS Tree Files} {.nex .nxs}} {{JE Tree Files} {.jet}} {{All Files} * }} -title "Open Tree"]
        
        foreach filename $filenames {
            
            # Read the tree.
            set extension [string tolower [file extension $filename]]
            if {$extension == ".jet"} {
                addTrees [::PhyloTree::JE::loadTreeFile $filename]                
            } elseif {$extension == ".nex" || $extension == ".nxs"} {
                addTrees [::PhyloTree::Nexus::loadTreeFile $filename]
            } elseif {$extension == ".dnd" || $extension == ".ph" || $extension == ".tre"} {
                addTrees [::PhyloTree::Newick::loadTreeFile $filename]
            } else {
                if {[catch {addTrees [::PhyloTree::Nexus::loadTreeFile $filename]} msg] == 0} {
                    return
                }
                if {[catch {addTrees [::PhyloTree::Newick::loadTreeFile $filename]} msg] == 0} {
                    return
                }
                if {[catch {addTrees [::PhyloTree::JE::loadTreeFile $filename]} msg] == 0} {
                    return
                }
            }
        }
    }
    
    proc menu_save {saveType} {
    
        # Import global variables.
        variable w
        variable treeIDs
        variable activeTreeID
        
        if {$activeTreeID != -1} {
            array set options [::PhyloTree::Export::showExportDialog $w]
            if {[array size options] > 0 && $options(filename) != ""} {
                
                # Figure out which trees to save.
                if {$saveType == "current"} {
                    set treesToSave $activeTreeID
                } elseif {$saveType == "all"} {
                    set treesToSave $treeIDs
                }
                
                # Save the trees n the specified format.
                if {$options(formatType) == "newick"} {
                    ::PhyloTree::Newick::saveTreeFile $options(filename) $treesToSave $options(newickIncludeInternalLabels) $options(newickIncludeBranchLengths)
                } elseif {$options(formatType) == "nexus"} {
                    ::PhyloTree::Nexus::saveTreeFile $options(filename) $treesToSave $options(nexusIncludeInternalLabels) $options(nexusIncludeBranchLengths)
                }
            }
        }
    }

    
    proc menu_close {} {
    
        # Import global variables.
        variable w
        variable menuSuffix
        variable treeIDs
        variable activeTreeID
        
        if {$activeTreeID != -1} {
            
            # Find the current tree.
            for {set i 0} {$i < [llength $treeIDs]} {incr i} {
                if {[lindex $treeIDs $i] == $activeTreeID} {
                    
                    # Remove it.
                    set treeIDs [lreplace $treeIDs $i $i]
                    
                    # Remove it from the trees menu.
                    $w.menu.trees$menuSuffix delete [expr $i+3]
                    
                    # Move to the next tree.
                    if {[llength $treeIDs] == 0} {
                        setActiveTree -1
                    } elseif {$i >= [llength $treeIDs]} {
                        setActiveTree [lindex $treeIDs 0]
                    } else {
                        setActiveTree [lindex $treeIDs $i]
                    }
                    break
                }
            }
        }
    }
    
    proc menu_exit {} {
        
        # Import global variables.
        variable w
        variable treeIDs
        variable activeTreeID
        
        # Delete any state.
        set treeIDs {}
        set activeTreeID -1
        
        # Remove any widget selection notification commands.
        #removeSelectionNotificationCommand
        
        # Close the window.
        destroy $w
    }
    
    proc menu_viewmatrix {} {
    
        # Import global variables.
        variable w
        variable activeTreeID
     
        if {$activeTreeID != -1} {
            set matrix [::PhyloTree::Data::getDistanceMatrix $activeTreeID]
            if {$matrix != {}} {
                ::PhyloTree::MatrixViewer::showMatrixViewerDialog $w $matrix
            } else {
                tk_messageBox -type ok -icon error -parent $w -title "Error" -message "The current tree does not have a distance matrix associated with it."
            }
        } else {
                tk_messageBox -type ok -icon error -parent $w -title "Error" -message "No trees are currently loaded."
        }
    }    
    
    proc menu_zoomin {} {
    
        # Import global variables.
        variable w
        variable scale
        variable fontSize
        
        if {$fontSize < 12} {
            set scale [expr $scale+$scale/$fontSize]
            set fontSize [expr $fontSize+1]
            ::PhyloTree::Widget::setScale $scale $fontSize
        } elseif {$fontSize < 26} {
            set scale [expr $scale+$scale/$fontSize]
            set fontSize [expr $fontSize+2]
            ::PhyloTree::Widget::setScale $scale $fontSize
        }
    }
    
    proc menu_zoomout {} {
    
        # Import global variables.
        variable w
        variable scale
        variable fontSize
        
        if {$fontSize > 12} {
            set fontSize [expr $fontSize-2]
            set scale [expr $scale-$scale/$fontSize]
            ::PhyloTree::Widget::setScale $scale $fontSize
        } elseif {$fontSize > 2} {
            set fontSize [expr $fontSize-1]
            set scale [expr $scale-$scale/$fontSize]
            ::PhyloTree::Widget::setScale $scale $fontSize
        }
    }
    
    proc menu_scaleup {} {
    
        # Import global variables.
        variable w
        variable scale
        variable fontSize
        
        if {$scale < 4096} {
            set scale [expr $scale*2]
            ::PhyloTree::Widget::setScale $scale $fontSize
        }
    }
    
    proc menu_scaledown {} {
    
        # Import global variables.
        variable w
        variable scale
        variable fontSize
        
        if {$scale > 1} {
            set scale [expr $scale/2]
            ::PhyloTree::Widget::setScale $scale $fontSize
        }
    }
    
    proc menu_nexttree {} {
    
        # Import global variables.
        variable treeIDs
        variable activeTreeID
        
        set index -1
        for {set i 0} {$i < [llength $treeIDs]} {incr i} {
            if {[lindex $treeIDs $i] == $activeTreeID} {
                set index [expr $i+1]
                if {$index >= [llength $treeIDs]} {
                    set index 0
                }
                setActiveTree [lindex $treeIDs $index]
                break
            }
        }
    }
    
    proc menu_previoustree {} {
    
        # Import global variables.
        variable treeIDs
        variable activeTreeID
        
        set index 0
        for {set i 0} {$i < [llength $treeIDs]} {incr i} {
            if {[lindex $treeIDs $i] == $activeTreeID} {
                set index [expr $i-1]
                if {$index < 0} {
                    set index [expr [llength $treeIDs]-1]
                }
                setActiveTree [lindex $treeIDs $index]
                break
            }
        }
    }

    proc menu_colorcustom {} {
        
        # Import global variables.
        variable w
        
        set newColor [tk_chooseColor -initialcolor [::PhyloTree::Widget::getBackgroundColor] -parent $w -title "Choose Tree Color"]
        if {$newColor != {}} {
            ::PhyloTree::Widget::setBackgroundColor $newColor
        }
    }
    
    proc menu_leafcolorcustom {} {
        
        # Import global variables.
        variable w
        
        set newColor [tk_chooseColor -initialcolor [::PhyloTree::Widget::getLeafColor] -parent $w -title "Choose Leaf Color"]
        if {$newColor != {}} {
            ::PhyloTree::Widget::setLeafColor $newColor
        }
    }
}
