############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

package provide multiseq 2.0
package require multiseqdialog 1.0

# Declare global variables for this package.
namespace eval MultiSeq::Import {

    # Export the package functions.
    namespace export showImportOptionsDialog

    # Dialog management variables.
    variable w
    variable oldFocus
    variable oldGrab
    variable grabStatus
    
    # Variable for indicating the user is finished choosing the options.
    variable finished
    
    # Default parameters.    
    variable eScoreDefault 0.00001
    variable iterationsDefault 1
    
    # The user's choices.
    variable choices
    array set choices {"dataSource" "file"
                       "filenames" ""
                       "profileType" "all"
                       "database" ""
                       "eScore" "-5"
                       "iterations" "1"
                       "loadStructures" 0
                       "maxResults" "500"}
    
    
    # Creates a dialog to get the user's options for running the data import.
    # args:     parent - The parent wondow for this dialog.
    # return:   An array containing the user's choices.
    proc showImportOptionsDialog {parent} {
    
        # Import global variables.
        variable w
        variable oldFocus
        variable oldGrab
        variable grabStatus
        variable finished
        variable choices
        set finished 0
        
        # Load the last database used.
        set choices(database) [::MultiSeqDialog::getVariable "blast" "lastDatabaseUsed"]
    
        # Create a new top level window.
        set w [createModalDialog ".importdataoptions" "Import Data"]
        
        # Create the components.
        frame $w.center
            label $w.center.source -text "Data Source"
            frame $w.center.g1 -relief sunken -borderwidth 1
                frame $w.center.g1.b -relief raised -borderwidth 1
                    radiobutton $w.center.g1.b.file -text "From Files" -variable "::MultiSeq::Import::choices(dataSource)" -value "file"
                        label $w.center.g1.b.filenamelbl -text "Filenames:"
                        entry $w.center.g1.b.filename -textvariable "::MultiSeq::Import::choices(filenames)" -width 40
                        button $w.center.g1.b.filenamebrs -text "Browse..." -pady 2 -command "::MultiSeq::Import::but_browsefile"
                    radiobutton $w.center.g1.b.blast -text "From BLAST Search" -variable "::MultiSeq::Import::choices(dataSource)" -value "blast"
                        label $w.center.g1.b.profile -text "Search Profile:"
                        frame $w.center.g1.b.g1 -relief sunken -borderwidth 1
                            frame $w.center.g1.b.g1.b -relief raised -borderwidth 1
                                radiobutton $w.center.g1.b.g1.b.all -text "All Sequences" -variable "::MultiSeq::Import::choices(profileType)" -value "all"
                                radiobutton $w.center.g1.b.g1.b.marked -text "Marked Sequences" -variable "::MultiSeq::Import::choices(profileType)" -value "marked"                    
                                radiobutton $w.center.g1.b.g1.b.selected -text "Selected Regions" -variable "::MultiSeq::Import::choices(profileType)" -value "selected"                    
                        label $w.center.g1.b.databaselbl -text "Database:"
                        entry $w.center.g1.b.database -textvariable "::MultiSeq::Import::choices(database)" -width 40
                        button $w.center.g1.b.databasebrs -text "Browse..." -pady 2 -command "::MultiSeq::Import::but_browsedatabase"
                        label $w.center.g1.b.scorelbl -text "E Score:"
                        label $w.center.g1.b.scoreval -text ""
                        scale $w.center.g1.b.score -orient horizontal -length 180 -sliderlength 10 -from -20 -to 2 -resolution 1 -tickinterval 0 -showvalue 0 -variable "::MultiSeq::Import::choices(eScore)" -command "::MultiSeq::Import::scale_score"
                        label $w.center.g1.b.iteratnlbl -text "Iterations:"
                        label $w.center.g1.b.iteratnval -text ""
                        scale $w.center.g1.b.iterations -orient horizontal -length 180 -sliderlength 10 -from 1 -to 13 -resolution 1 -tickinterval 4 -showvalue 0 -variable "::MultiSeq::Import::choices(iterations)" -command "::MultiSeq::Import::scale_iterations"
                        label $w.center.g1.b.maxresultslbl -text "Max Results:"
                        label $w.center.g1.b.maxresultsval -text ""
                        scale $w.center.g1.b.maxresults -orient horizontal -length 180 -sliderlength 10 -from 0 -to 2000 -resolution 100 -tickinterval 500 -showvalue 0 -variable "::MultiSeq::Import::choices(maxResults)" -command "::MultiSeq::Import::scale_maxResults"
                    
            checkbutton $w.center.loadstructures -text "Automatically download corresponding structures for sequence data" -variable "::MultiSeq::Import::choices(loadStructures)" -onvalue 1 -offvalue 0
                    
        frame $w.bottom
            frame $w.bottom.buttons
                button $w.bottom.buttons.accept -text "OK" -pady 2 -command "::MultiSeq::Import::but_ok"
                button $w.bottom.buttons.cancel -text "Cancel" -pady 2 -command "::MultiSeq::Import::but_cancel"
                button $w.bottom.buttons.defaults -text "Defaults" -pady 2 -command "::MultiSeq::Import::but_defaults"
                bind $w <Return> {::MultiSeq::Import::but_ok}
                bind $w <Escape> {::MultiSeq::Import::but_cancel}
        
        # Layout the components.
        pack $w.center                  -fill both -expand true -side top -padx 5 -pady 5
        grid $w.center.source           -column 1 -row 1 -sticky nw
        grid $w.center.g1               -column 1 -row 2 -sticky nw -padx 5
        
        pack $w.center.g1.b             -fill both -expand true -side left
        grid $w.center.g1.b.file        -column 1 -row 1 -sticky w -columnspan 4
        grid $w.center.g1.b.filenamelbl -column 1 -row 2 -sticky w -padx 20
        grid $w.center.g1.b.filename    -column 2 -row 2 -sticky w -padx 5 -columnspan 2
        grid $w.center.g1.b.filenamebrs -column 4 -row 2 -sticky w -padx 10
        grid $w.center.g1.b.blast       -column 1 -row 3 -sticky w -columnspan 4 -pady 5
        grid $w.center.g1.b.profile     -column 1 -row 4 -sticky nw -padx 20 -pady 3
        grid $w.center.g1.b.g1          -column 2 -row 4 -sticky nw -padx 5 -columnspan 2 -pady 3
            pack $w.center.g1.b.g1.b            -fill both -expand true -side left
            grid $w.center.g1.b.g1.b.all        -column 1 -row 1 -sticky w
            grid $w.center.g1.b.g1.b.marked     -column 1 -row 2 -sticky w
            grid $w.center.g1.b.g1.b.selected   -column 1 -row 3 -sticky w
        grid $w.center.g1.b.databaselbl -column 1 -row 5 -sticky w -padx 20
        grid $w.center.g1.b.database    -column 2 -row 5 -sticky w -padx 5 -columnspan 2
        grid $w.center.g1.b.databasebrs -column 4 -row 5 -sticky w -padx 10
        grid $w.center.g1.b.scorelbl    -column 1 -row 6 -sticky w -padx 20
        grid $w.center.g1.b.scoreval    -column 2 -row 6 -sticky w
        grid $w.center.g1.b.score       -column 3 -row 6 -sticky w -padx 5
        grid $w.center.g1.b.iteratnlbl  -column 1 -row 7 -sticky w -padx 20
        grid $w.center.g1.b.iteratnval  -column 2 -row 7 -sticky w
        grid $w.center.g1.b.iterations  -column 3 -row 7 -sticky w -padx 5
        grid $w.center.g1.b.maxresultslbl  -column 1 -row 8 -sticky w -padx 20
        grid $w.center.g1.b.maxresultsval  -column 2 -row 8 -sticky w
        grid $w.center.g1.b.maxresults  -column 3 -row 8 -sticky w -padx 5
        
        grid $w.center.loadstructures   -column 1 -row 3 -sticky nw -padx 5 -pady 5

        pack $w.bottom                  -fill x -side bottom
        pack $w.bottom.buttons          -side bottom
        pack $w.bottom.buttons.accept   -side left -padx 5 -pady 5
        pack $w.bottom.buttons.cancel   -side left -pady 5
        pack $w.bottom.buttons.defaults -side left -padx 5 -pady 5

        # Bind the window closing event.
        bind $w <Destroy> {"MultiSeq::Import::but_cancel"}
        
        # Center the dialog.
        centerDialog $parent
        
        # Wait for the user to interact with the dialog.
        tkwait variable "::MultiSeq::Import::finished"
        puts "Size is [winfo reqwidth $w] [winfo reqheight $w]"
        
        # Destroy the dialog.
        destroyDialog        
        
        # Return the options.
        if {$finished == 1} {
            return [array get choices]
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
        set width 542
        set height [expr 359+22]
        
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
        variable choices
        
        # Save the last database used.
        if {$choices(database) != [::MultiSeqDialog::getVariable "blast" "lastDatabaseUsed"]} {
            ::MultiSeqDialog::setVariable "blast" "lastDatabaseUsed" $choices(database)
            ::MultiSeqDialog::saveRCFile
        }
            
        # Close the window.
        set finished 1
    }
    
    proc but_cancel {} {
    
        # Import global variables.
        variable finished
    
        # Close the window.    
        set finished 0
    }
    
    # Set the parameters to a default state
    proc but_defaults {} {
    
        # Import global variables.
        variable w
    
        # Set the variables to their default values.
        #set npass $npassDefault
        #set scan $scanDefault
        #set scanscore $scanscoreDefault
        #set scanslide $scanslideDefault
        #set slowscan $slowscanDefault
        
        # Set any controls that do not automatically update themselves.
        #$w.center.npass selection clear 0
        #$w.center.npass selection set [expr $npass-1]
    }
    
    proc but_browsefile {} {
    
        # Import global variables.
        variable w
        variable choices

        set filenames [tk_getOpenFile -multiple 1 -filetypes {{{FASTA Files} {.fasta}} {{PDB Files} {.pdb}} {{ALN Files} {.aln}} {{PHYLIP Files} {.phy .ph}} {{NEX Files} {.nex}} {{All Files} * }} -title "Import Sequences/Structures"]
        if {$filenames != {}} {
            set choices(filenames) "\"[join $filenames \",\"]\""
        }
    }
    
    proc but_browsedatabase {} {
    
        # Import global variables.
        variable w
        variable choices

        set database [tk_getOpenFile -multiple 0 -filetypes {{{All Files} * }} -title "Select BLAST Database"]
        if {$database != ""} {
            
            # If an index file was picked, use just the database name portion.
            if {[regexp {\.pal$|\.phr$|\.pin$|\.pnd$|\.pni$|\.psd$|\.psi$|\.psq$} $database] == 1} {
                set database [string range $database 0 [expr [string last "." $database]-1]]
            }
            
            set choices(database) $database
        }
    }
    
    proc scale_score {value} {
        
        # Import global variables.
        variable w
        
        # Update the label.
        if {$value >= 0} {        
            $w.center.g1.b.scoreval configure -text [expr pow(10,$value)]
        } else {
            $w.center.g1.b.scoreval configure -text "e$value"
        }
    }
    
    proc scale_iterations {value} {
        
        # Import global variables.
        variable w
        
        # Update the label.
        $w.center.g1.b.iteratnval configure -text $value    
    }
    
    proc scale_maxResults {value} {
        
        # Import global variables.
        variable w
        
        # Update the label.
        $w.center.g1.b.maxresultsval configure -text $value    
    }
}

