############################################################################
#cr
#cr            (C) Copyright 1995-2006 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

############################################################################
#
# multiseqdialog
#
# provides an API to get paths where databases are stored on the user's system
#
############################################################################

package provide multiseqdialog 1.0

namespace eval ::MultiSeqDialog {

    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "multiseq"
    
    # The current CPU architecture.
    variable architecture ""
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        # Import global variables.
        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setArchitecture {newArchitecture} {

        # Import global variables.
        variable architecture
        
        # Set the temp directory and file prefix.
        set architecture $newArchitecture
    }    


    variable dialogWindow
    variable dialogWindowName ".multiseqDialogWindow"
    variable xmlValueList ""
    variable rcFileName
    variable changeNotifier ""
}

############################################################################
#
# loadRCFile
#
# reads the .multiseqrc file from the user's hard drive and puts the results
# into xmlValueList
#
# parameters: none
#
# returns: 1 if the file exists, otherwise 0
#
############################################################################

proc ::MultiSeqDialog::loadRCFile {} {
    
    # Import global variables.
    global env
    variable architecture
    variable rcFileName
    variable xmlValueList

    # Fgure out the home directory.
    set homeDir ""
    if {[catch {
        if {[info exists env(HOME)]} {
            set homeDir $env(HOME)
        }
    } errorMessage] != 0} {
        global errorInfo
        set callStack [list "MultiSeq Error) Error finding home directory: $errorInfo"]
        puts [join $callStack "\n"]
    }
    
    # If we couldn't find one, print out an error.
    if {$homeDir == ""} {
        puts "MultiSeq Error) Could not find home directory, using current directory"
    }
    
    # Construct the resource file name, if we don't have it already.
    if { ![info exists rcFileName] } {
        set rcFileName ".multiseqrc"
        if {$architecture == "WIN32"} {
            set rcFileName "multiseq.rc"
        }
        if {$homeDir != ""} {
            set rcFileName [file join $homeDir $rcFileName]
        }
    }

    # If the file exists, read it in.
    if {[file exists $rcFileName]} {
        set data ""
        if {[catch {
            puts "MultiSeq Info) Loading multiseq resource file: $rcFileName"
            set fp [open $rcFileName r]
            set data [read $fp]
            close $fp
        } errorMessage] != 0} {
            global errorInfo
            set callStack [list "MultiSeq Error) Could not load multiseq resource file: $errorInfo"]
            puts [join $callStack "\n"]
        }
        if {$data != ""} {
            puts "MultiSeq Info) Loaded multiseq preferences."
            set xmlValueList $data
            return 1
        }
    }
    
    # Otherwise return that we don't have a resource file yet.
    return 0
}

############################################################################
#
# saveRCFile
#
# writes the .multiseqrc file to the user's hard drive
#
# parameters: data - the data to write
#
# returns: none
#
############################################################################

proc ::MultiSeqDialog::saveRCFile {} {
    
    variable rcFileName
    variable xmlValueList

    if {$rcFileName != ""} {
        puts "MultiSeq Info) Saving multiseq resource file: $rcFileName"
        set fp [open $rcFileName w]
        puts $fp $xmlValueList
        close $fp
    }
}


############################################################################
#
# checkForMetadataUpdates
#
# checks to see if any new versions are available
#
############################################################################

proc ::MultiSeqDialog::checkForMetadataUpdates {} {

    # Import global variables.
    variable xmlValueList

    # Get the directory where the metadata is stored.
    set metadataDir [getDirectory "metadata"]
    if {$metadataDir != ""} {
        
        # Read the info file.
        set data [readInfoFile]
        
        # Parse the data.
        if {$data != ""} {
            set updateList {}
            foreach line [split $data "\n"] {
                if { [string first "\#" $line] == 0 || [string match $line ""] } {
                    continue
                } else {
            
                    # Format of data is as follows:
                    # Blank lines are ignored
                    # Each line consists of space-seperated fields in the following order:
                    #  Key - a unique key used by MultiSeq to identify this database
                    #  Description - a text description; MUST be in quotes (ie, "desc")
                    #  URL - location to download the file from
                    #  BackupURL - location to download the file from if URL is unavailable
                    #  Version - most recent version number of the database
                    #  Size - size in bytes of the downloaded file
                    #  Type - download type; "db" for database or "sw" for software
                    #  Required - is this download required for proper operation of MultiSeq?  Y or N
                    #  envVariables - additional variables. A list of name/value pairs
            
                    # Split up the line.
                    set columns [regexp -inline -all {\"[^\"]*\"|\S+} $line]
                    for {set i 0} {$i < [llength $columns]} {incr i} {
                        set columns [lreplace $columns $i $i [join [regexp -inline {[^\"]+} [lindex $columns $i]] " "]]
                    }
                    
                    # Process the line.
                    set key [lindex $columns 0]
                    set description [lindex $columns 1]
                    set url [lindex $columns 2]
                    set backupurl [lindex $columns 3]
                    set version [lindex $columns 4]
                    set size [lindex $columns 5]
                    set type [lindex $columns 6]
                    set required [lindex $columns 7]
                    set envVariables [lrange $columns 8 end]
                    
                    # If this is a database.
                    if {$type == "db"} {
                        
                        # See if the file needs updating.
                        set needsUpdating 1
                        set filename [file join $metadataDir [lindex [split $url /] end]]
                        if {[file exists $filename] && [file size $filename] == $size && [getVersion $key] == $version} {
                            set needsUpdating 0
                        }
                        
                        if {$needsUpdating} {
                            lappend updateList $columns
                        }
                    }
                }
            }
        
            # If any databases need updating, ask the user if they want to update.
            if {$updateList != {}} {
                array set options [::MultiSeqDialog::DownloadUpdates::showDownloadUpdatesDialog $updateList]
                if {[array size options] > 0 && $options(update) == 1} {
                    
                    ::MultiSeqDialog::Wait::showWaitDialog "Please wait while the updates are downloaded."
                    foreach update $updateList {
                    	if {[catch {
                            set key [lindex $update 0]
                            set url [lindex $update 2]
                            set backupurl [lindex $update 3]
                            set version [lindex $update 4]
                            ::MultiSeqDialog::downloadMetadata $url $metadataDir [lindex [split $url /] end] $key $version
                    	} errorMessage] != 0} {
                        ::MultiSeqDialog::Wait::hideWaitDialog
                        global errorInfo
                        set callStack [list "MultiSeq Error) " $errorInfo]
                        puts [join $callStack "\n"]
                        if {[string first "couldn't open socket" $errorMessage] != -1 } {
                           if {[catch {::MultiSeqDialog::downloadMetadata $backupurl $metadataDir [lindex [split $url /] end] $key $version} errorMessage] != 0} {
                        		if {[string first "couldn't open socket" $errorMessage] != -1 } {
                            	tk_messageBox -type ok -icon error -title "Error" -message "The file could not be downloaded. Please be sure that you have a working internet connection and try again."
														}
													}
                        } elseif {[string first "can't create" $errorMessage] != -1 || [string first "couldn't open" $errorMessage] != -1 || [string first "The specified directory was invalid" $errorMessage] != -1} {
                            tk_messageBox -type ok -icon error -title "Error" -message "The file could not be created. Please check that the metadata directory exists and is spelled correctly, and that you have permissions to write to the directory."
                        } else {
                            tk_messageBox -type ok -icon error -title "Error" -message "The download failed with the following message:\n\n$errorMessage"
                        }
                    }
									}
                  ::MultiSeqDialog::Wait::hideWaitDialog
                  
                  # Save the rc file.
                  saveRCFile
                }
            }
        }
    }
}

############################################################################
#
# showPreferencesDialog
#
# Opens the dialog window that allows a user to change the locations
# where databases are stored. Also allows the user to download the latest
# version
#
# Parameters: message - a message that appears at the top of the dialog,
#                       which could provide an error message, tell the user
#                       which database is needed, etc.
#
# Returns: none
#
############################################################################

proc ::MultiSeqDialog::showPreferencesDialog {message arg_changeNotifier} {

    # Import global variables.
    variable dialogWindow
    variable dialogWindowName
    variable xmlValueList
    variable rcFileName
    variable changeNotifier
    
    set changeNotifier $arg_changeNotifier

    set helpURL "http://www.scs.uiuc.edu/~schulten/multiseq"
    
    # If we haven't done so yet, read the preferences.
    if {$xmlValueList == ""} {
        loadRCFile
    }
    
    # Make sure a metadata directory has been set.
    set metadataDir [getDirectory "metadata"]
    if {$metadataDir == ""} {
        set metadataDir [file join [file dirname $rcFileName] ".multiseqdb"]
        tk_messageBox -title "MultiSeq Preferences Setup" -icon info -message "Before using MultiSeq, you must select a directory in which to store metadata. If you choose \"Cancel\", a default directory will be used." -type ok
        set dir [tk_chooseDirectory -title "Select Metadata Directory"]
        if {$dir != ""} {
            set metadataDir $dir
        }
        
        # Create the metadata directory.
        file mkdir $metadataDir
        setDirectory "metadata" $metadataDir
    }
    
    # Check for any updates.
    ::MultiSeqDialog::checkForMetadataUpdates

    puts "MultiSeq Info) Metadata directory: $metadataDir"

    # Build the window.    
    if { [winfo exists $dialogWindowName] } {
        foreach child [winfo children $dialogWindowName ] {
            destroy $child
        }
    } else {
        set dialogWindow [toplevel $dialogWindowName]
        wm title $dialogWindowName $message
    }

    set dbFrame [frame $dialogWindowName.dbFrame -relief sunken -borderwidth 1]
    set dbScrollFrame [::MultiSeqDialog::scrolledframe::scrolledframe $dbFrame.panel -fill both -yscrollcommand "$dbFrame.scroll set"]
    set dbScrollBar [scrollbar $dbFrame.scroll -command "$dbScrollFrame yview"]
    set swFrame [frame $dialogWindowName.swFrame -relief sunken -borderwidth 1]
    set swScrollFrame [::MultiSeqDialog::scrolledframe::scrolledframe $swFrame.panel -height 400 -width 200 -fill x -yscrollcommand "$swFrame.scroll set"]
    set swScrollBar [scrollbar $swFrame.scroll -command "$swScrollFrame yview"]

    set switchFrame [frame $dialogWindowName.switchFrame]
    set dbButton [button $switchFrame.dbButton -text "Metadata" -command "pack forget $swFrame; pack $dbFrame -side top -fill both -expand true"]
    set swButton [button $switchFrame.swButton -text "Software" -command "pack forget $dbFrame; pack $swFrame -side top -fill both -expand true"]

    set dirFrame [frame $dbScrollFrame.scrolled.dirFrame]
    set dirLabel [label $dirFrame.dirLabel -text "Metadata directory:"]
    set dirText [entry $dirFrame.dirText -width 50]
    $dirText insert 0 $metadataDir
    set chooseCommand { set newDir [tk_chooseDirectory -title "Select Metadata Directory"]; if {$newDir != ""} {.multiseqDialogWindow.dbFrame.panel.scrolled.dirFrame.dirText delete 0 end; .multiseqDialogWindow.dbFrame.panel.scrolled.dirFrame.dirText insert 0 $newDir } } 
    set chooseDirButton [button $dirFrame.chooseDirButton -text "Browse..." -command $chooseCommand]

    pack $switchFrame -side top -anchor nw -pady 10
    pack $dbButton -side left -anchor w
    pack $swButton -side left -anchor w

    pack $dirFrame -side top -anchor nw -pady 10
    pack $dirLabel -side left
    pack $dirText -side left -expand 1
    pack $chooseDirButton -side left

    grid $dbScrollFrame -row 0 -column 0 -sticky nsew
    grid $dbScrollBar   -row 0 -column 1 -sticky ns
    grid rowconfigure $dbFrame 0 -weight 1
    grid columnconfigure $dbFrame 0 -weight 1
    
    grid $swScrollFrame -row 0 -column 0 -sticky nsew
    grid $swScrollBar   -row 0 -column 1 -sticky ns
    grid rowconfigure $swFrame 0 -weight 1
    grid columnconfigure $swFrame 0 -weight 1

    # Build the screen based on the info file.
    set data [readInfoFile]
    if {$data != ""} {
        foreach line [split $data "\n"] {
            if {[string first "\#" $line] == 0 || [string match $line ""] } {
                continue
            } else {
        
                # Format of data is as follows:
                # Blank lines are ignored
                # Each line consists of space-seperated fields in the following order:
                #  Key - a unique key used by MultiSeq to identify this database
                #  Description - a text description; MUST be in quotes (ie, "desc")
                #  URL - location to download the file from
                #  BackupURL - location to download the file from if URL is unavailable
                #  Version - most recent version number of the database
                #  Size - size in bytes of the downloaded file
                #  Type - download type; "db" for database or "sw" for software
                #  Required - is this download required for proper operation of MultiSeq?  Y or N
                #  envVariables - additional variables. A list of name/value pairs
        
                # Split up the line.
                set columns [regexp -inline -all {\"[^\"]*\"|\S+} $line]
                for {set i 0} {$i < [llength $columns]} {incr i} {
                    set columns [lreplace $columns $i $i [join [regexp -inline {[^\"]+} [lindex $columns $i]] " "]]
                }
                
                # Process the line.
                set key [lindex $columns 0]
                set description [lindex $columns 1]
                set url [lindex $columns 2]
                set backupurl [lindex $columns 3]
                set version [lindex $columns 4]
                set size [lindex $columns 5]
                set type [lindex $columns 6]
                set required [lindex $columns 7]
                set envVariables [lrange $columns 8 end]
                
                # Create the dialog entry.
                addFieldToDialog $key $description $url $backupurl $version $size $type $required $envVariables
            }
        }
    } else {
        wm withdraw $dialogWindowName
        return
    }

    pack $dbFrame -side top -fill both -expand true
    
    set closeCommand {
        
        # Save the metadata directory.
        ::MultiSeqDialog::setDirectory "metadata" [.multiseqDialogWindow.dbFrame.panel.scrolled.dirFrame.dirText get];

        # Save the software values.
         foreach panel [winfo children $::MultiSeqDialog::dialogWindowName.swFrame] {
             
             foreach scrolledChildFrame [ winfo children $panel ] {
                 
                 foreach fieldFrame [ winfo children $scrolledChildFrame ] {
                     
                     set childFrames [winfo children $fieldFrame]
                     
                     set varFrameIndex [lsearch -regexp $childFrames .*variables]
                     if { $varFrameIndex != -1 } {
                         set varFrame [lindex $childFrames $varFrameIndex]
                         foreach var [winfo children $varFrame] {             
                             set varChildren [winfo children $var]
                             set keyIndex [lsearch -regexp $varChildren .*_label]
                             set keyName [lindex $varChildren $keyIndex]
                 
                             set valueIndex [lsearch -regexp $varChildren .*_text]
                             set valueName [lindex $varChildren $valueIndex]
                 
                             set key [$keyName cget -text]
                             set value [$valueName get]
                 
                             set widgets [split $keyName "."];
                             set widgetName [lindex $widgets 6];
                             regsub "_variables" $widgetName "" fieldName;
                             ::MultiSeqDialog::setVariable $fieldName $key $value
                         }
                     }
             
                     set textFrameIndex [lsearch -regexp $childFrames .*dirFrame]
                     if { $textFrameIndex == -1 } {
                         continue
                     }
                     set fieldFrames [winfo children [lindex $childFrames $textFrameIndex]]
                     set textField [lindex $fieldFrames [lsearch -regexp $fieldFrames .*_text]]
                     
                     set widgets [split $textField "."];
                     set widgetName [lindex $widgets 7];
                     regsub "_text" $widgetName "" fieldName;
                     ::MultiSeqDialog::setDirectory $fieldName [$textField get];
                }
             }
        }
         
        # Save the rc file.
        wm withdraw $::MultiSeqDialog::dialogWindowName;
        ::MultiSeqDialog::saveRCFile;
        if {$::MultiSeqDialog::changeNotifier != ""} {
            $::MultiSeqDialog::changeNotifier
        }
    }

    set bottomFrame [frame $dialogWindowName.bottom]
    set buttonFrame [frame $bottomFrame.buttonFrame]
    set okayButton [button $buttonFrame.okayButton -text "Close" -command $closeCommand]    
    set helpButton [button $buttonFrame.helpButton -text "Help" -command "vmd_open_url $helpURL"]
    bind $dialogWindow <Return> $closeCommand
    bind $dialogWindow <Escape> $closeCommand
    
    pack $bottomFrame  -fill x -side bottom
    pack $buttonFrame  -side bottom
    pack $okayButton   -side left -padx 5 -pady 5
    pack $helpButton   -side left -padx 5 -pady 5
    
    centerDialog
    wm state $dialogWindowName normal
}

# Centers the dialog.
proc ::MultiSeqDialog::centerDialog {{parent ""}} {
    
    # Import global variables.        
    variable dialogWindow
    
    # Set the width and height, since calculating doesn't work properly.
    set width 600
    set height [expr 400+22]
    
    # Figure out the x and y position.
    if {$parent != ""} {
        set cx [expr {int ([winfo rootx $parent] + [winfo width $parent] / 2)}]
        set cy [expr {int ([winfo rooty $parent] + [winfo height $parent] / 2)}]
        set x [expr {$cx - int ($width / 2)}]
        set y [expr {$cy - int ($height / 2)}]
        
    } else {
        set x [expr {int (([winfo screenwidth $dialogWindow] - $width) / 2)}]
        set y [expr {int (([winfo screenheight $dialogWindow] - $height) / 2)}]
    }
    
    # Make sure we are within the screen bounds.
    if {$x < 0} {
        set x 0
    } elseif {[expr $x+$width] > [winfo screenwidth $dialogWindow]} {
        set x [expr [winfo screenwidth $dialogWindow]-$width]
    }
    if {$y < 22} {
        set y 22
    } elseif {[expr $y+$height] > [winfo screenheight $dialogWindow]} {
        set y [expr [winfo screenheight $dialogWindow]-$height]
    }
        
    wm geometry $dialogWindow ${width}x${height}+${x}+${y}
    wm positionfrom $dialogWindow user
}
    
############################################################################
#
# addFieldToDialog
#
# Adds a new database field to the dialog box, with its name, path,
#  and download button
#
# parameters:
#  key - a unique key used by MultiSeq to identify this database
#  description - a text description; MUST be in quotes (ie, "desc")
#  url - location to download the file from
#  backupurl - location to download the file from if URL is unavailable
#  version - most recent version number of the database
#  size - size in bytes of the downloaded file
#  type - download type; "db" for database or "sw" for software
#  required - is this download required for proper operation of MultiSeq?  Y or N
#  envVariables - a list of name/value pairs of environment variables. Used for software
#
# returns:
#  none
#
############################################################################

proc ::MultiSeqDialog::addFieldToDialog { key description url backupurl version size type required { envVariables } } {

    global env
    variable dialogWindow
    variable dialogWindowName
    variable xmlValueList
    
    if { ![winfo exists $dialogWindowName] } {
	set dialogWindow [toplevel $dialogWindowName]
    }

    set fullDialogWindow ""
    if { [string match $type "db"] } {
        
        set metadataDir [getDirectory "metadata"]
        set filename [lindex [split $url "/"] end]
        set fullPath [file join $metadataDir $filename]

        # Create the frame.
        append fullDialogWindow $dialogWindowName . "dbFrame.panel.scrolled"
        append trayHandle $key _tray
        append trayName $fullDialogWindow . $trayHandle
        set $trayHandle [frame $trayName -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]
        append frameHandle $key _frame
        append frameName $trayName . $frameHandle
        set $frameHandle [frame $frameName]
    
        # Description.
        append labelHandle $key _label
        append labelName $frameName . $labelHandle
        set text $description
        if { [string match $required "Y" ] } {
        append text " (Required)"
        }
        set $labelHandle [label $labelName -text $text -font "-weight bold" ]
    
        # Version info.
        append versionHandle $key _version
        append versionName $frameName . $versionHandle
        set oldVersion [getVersion $key]
        if {$oldVersion == "" || ![file exists $fullPath]} {
            set oldVersion "(missing)"
        }
        set sizeLabel "Bytes"
        if {$size >= 1024} {
            set size [expr $size/1024]
            set sizeLabel "KB"
            if {$size >= 1024} {
                set size [expr $size/1024]
                set sizeLabel "MB"
            }
        }
        set $versionHandle [label $versionName -text "Current version: $oldVersion\nLatest version: $version\nSize: $size $sizeLabel" -justify left]
    
        # Download button.
        append downloadButtonHandle $key _downloadButton
        append downloadButtonName $frameName . $downloadButtonHandle
        set downloadCommand "::MultiSeqDialog::Wait::showWaitDialog \"Please wait while the file is downloaded.\"; ::MultiSeqDialog::downloadMetadata $url \[.multiseqDialogWindow.dbFrame.panel.scrolled.dirFrame.dirText get\] $filename $key $version; $versionName configure -text \"Current version: $version\nLatest version: $version\nSize: $size $sizeLabel\"; ::MultiSeqDialog::setVersion $key $version; ::MultiSeqDialog::Wait::hideWaitDialog"
        set $downloadButtonHandle [button $downloadButtonName -text "Download" -command $downloadCommand]
    
        # Layout the components.
        pack $trayName             -side top -fill x -anchor w    
        pack $frameName            -side left -fill x -anchor w    
        grid $labelName            -column 1 -row 1 -sticky w
        grid $versionName          -column 1 -row 2 -sticky w
        grid $downloadButtonName   -column 1 -row 3 -sticky w
    
    } elseif { [string match $type "sw"] } {
        
        append fullDialogWindow $dialogWindowName . "swFrame.panel.scrolled"
        append frameHandle $key _frame
        append frameName $fullDialogWindow . $frameHandle
    
        append dirFrameHandle $key _dirFrame
        append dirFrameName $frameName . $dirFrameHandle
    
        append labelFrameHandle $key _labelFrame
        append labelFrameName $frameName . $labelFrameHandle
    
        append labelHandle $key _label
        append labelName $labelFrameName . $labelHandle
    
        append textHandle $key _text
        append textName $dirFrameName . $textHandle
    
        append chooseDirButtonHandle $key _chooseDirButton
        append chooseDirButtonName $dirFrameName . $chooseDirButtonHandle
    
        set text $description
        if { [string match $required "Y" ] } {
            append text " (Required)"
        }
    
        set $frameHandle [frame $frameName -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]
    
        set $labelFrameHandle [frame $labelFrameName]
        set $dirFrameHandle [frame $dirFrameName]
    
        set $labelHandle [label $labelName -text $text -font "-weight bold" ]
        set $textHandle [entry $textName -width 50]
    
        eval [append q $ $textHandle] insert 0 [list [getDirectory $key]]
    
        set $chooseDirButtonHandle [button $chooseDirButtonName -text "Browse..." -command "::MultiSeqDialog::setBrowseDirectory \[$textName get\] $textName" ]
    
        pack $frameName -fill x -anchor nw
        pack $labelFrameName -side top -fill x -anchor nw
        pack $dirFrameName -side top -fill x -anchor nw
    
    
        pack $labelName -side left -fill x -anchor nw
        pack $textName  -side left -fill x -anchor nw
        pack $chooseDirButtonName -anchor w
    
    
        if { ![string match $envVariables ""] } {
        append variableFrameHandle $key _variables
        append variableFrameName $frameName . $variableFrameHandle
    
        set $variableFrameHandle [frame $variableFrameName]
        pack $variableFrameName -side top -anchor sw
        
        foreach { name value } $envVariables {
            set varFrameHandle [append varFrameHandle$name  var_ $name _frame]
            set varFrameName [append varFrame$name $variableFrameName . $varFrameHandle]
    
            set varLabelHandle [append varLabelHandle$name var_ $name _label]
            set varLabelName [append varLabel$name $varFrameName . $varLabelHandle]
    
            set varTextHandle [append varTextHandle$name var_ $name _text]
            set varTextName [append varText$name $varFrameName . $varTextHandle]
    
            set $varFrameHandle [frame $varFrameName]
    
            set $varLabelHandle [label $varLabelName -text $name]
            set $varTextHandle [entry $varTextName -width 50]
    
            set x ""
            if { [getVariable $key $name] != "" } {            
                eval [append x $ $varTextHandle] insert 0 [list [getVariable $key $name]]
            } else {
                eval [append x $ $varTextHandle] insert 0 [list $value]
            }
    
            pack $varFrameName -side top -fill x
            pack $varLabelName -side left -fill x
            pack $varTextName -side left -fill x
        }
        }
    }
}


############################################################################
#
# readInfoFile
#
# reads the web page with the list of latest databases and versions, and adds
#  corresponding fields to the dialog box
#
# parameters: none
#
# returns: -1 if the user cancels the operation, else none
#
############################################################################

proc ::MultiSeqDialog::readInfoFile { } {

    # Import global variables.
    global env
    variable tempDir
    variable filePrefix
    variable architecture

    # The URL locations.
    variable baseURL "http://www.scs.uiuc.edu/multiseq/beta"
    variable backupURL "http://www.ks.uiuc.edu/Research/vmd/multiseq/beta"
    
    # Figure out where to check.
    variable infoURL "$baseURL/versions.txt"
    variable platformInfoURL "$baseURL/versions_$architecture.txt"
    variable backupInfoURL "$backupURL/versions.txt"
    variable backupPlatformInfoURL "$backupURL/versions_$architecture.txt"
    variable infoFile [file join $env(VERSIONDIR) "versions.txt"]
    variable platformInfoFile [file join $env(VERSIONDIR) "versions_$architecture.txt"]
    
    # Try to get either the platform or generic version of the info file from the web.
    set data ""
    set tempFileName [file join $tempDir "$filePrefix.versions.txt"]
    foreach location [list $platformInfoURL $infoURL $backupPlatformInfoURL $backupInfoURL $platformInfoFile $infoFile] {
        
        if {[catch {
            puts "MultiSeq Info) Trying to retrieve multiseq db version from: $location"
            if {[string first "http" $location] == 0} {
                vmdhttpcopy $location $tempFileName
                if {[file exists $tempFileName]} {
                    set fp [open $tempFileName]
                    regexp {\%VERS\s1\.0\s*([^%]*)\%EVERS\s1\.0} [read $fp] unused data
                    close $fp
                    file delete $tempFileName
                }
            } else {
                if {[file exists $location]} {
                    set fp [open $location]	
                    regexp {\%VERS\s1\.0\s*([^%]*)\%EVERS\s1\.0} [read $fp] unused data
                    close $fp
                }
            }
        } errorMessage] != 0} {
            puts "MultiSeq Error) message: $errorMessage"
        }
        
        # If we got data, we are finished.
        if {$data != ""} {
            break
        }
    }
    
    return $data
}

############################################################################
#
# download
#
# downloads a database file
#
# parameters: url - the URL from which to download
#             path - the directory in which to put the file
#             filename - the name of the database file
#             key - the key used to reference the database
#             version - the version of the database to download
#
# returns: none
#
############################################################################

proc ::MultiSeqDialog::downloadMetadata {url path filename key version} {

    # Import global variables.
    variable architecture
    
    # Create the directory.
    file mkdir $path
    if {![file exists $path]} {
	    return -code error "The specified directory was invalid: $path"
    }
    
    # Delete the existing file, if it exists.
    set fullFilename [file join $path $filename]
    if {[file exists $fullFilename]} {
        file delete $fullFilename
    }

    # Download the file.
    puts "MultiSeq Info) Downloading $url to $fullFilename"
	vmdhttpcopy $url $fullFilename
	if {[string first ".gz" $filename] != -1 || [string first ".tgz" $filename] != -1} {
	    if {$architecture != "WIN32"} {
            if {[regexp {^(.+)\.tar\.gz$} $fullFilename unused prefix]} {
                puts "MultiSeq Info) Untaring $filename into $path"
                exec gunzip -c $fullFilename > $prefix.tar
                set pwd [pwd]
                cd $path
                exec tar -xf $prefix.tar
                cd $pwd
                file delete $prefix.tar
            } elseif {[regexp {^(.+)\.gz$} $fullFilename unused prefix]} {
                puts "MultiSeq Info) Unzipping $filename"
                exec gunzip -c $fullFilename > $prefix
            }
	    }
	}
	setVersion $key $version
	setFilename $key $filename    
}

########################
#
# toXML
#
# creates an XML string from name/value pairs
# 
# parameters:
#  tag: The tag name for the XML entry
#  entries: a list of name, value entries
#
# returns:
#  an XML String representing the name/value pairs

proc toXML { tag entries } {
    
    set xml "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append xml "<$tag>\n"
    foreach { name value } $entries {
       # character substitutions for valid XML
       regsub -all ">" $value "ampersandgt;" value
       regsub -all "<" $value "ampersandlt;" value
       regsub -all {\&} $value "ampersand" value
       regsub -all {\?} $value "questionmark" value
       regsub -all {\}} $value "ampersand\#123;" value
       regsub -all {\{} $value "ampersand\#125;" value

       append xml " <$name>\n  $value\n </$name>\n"
    }
    append xml "</$tag>"

    return $xml
}

proc toXMLMultiple { mainTag values } {

    set xml ""
    set xml "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append xml "<$mainTag>\n"
    

    foreach { tag fields } $values {
	
	append xml " <$tag>\n"
	
	foreach { name value } $fields {

	    append xml "  <$name>\n"
	    append xml "   $value\n"
	    append xml "  </$name>\n"
	}

	append xml " </$tag>\n"
	
    }
    append xml "</$mainTag>"

    return $xml
}




############################################################################
#
# getXMLValue
#
# gets the value of a key stored in an XML string
#
# parameters: tag - the tag to get the field of (such as "ncbi_tax")
#             field - the field to get the value of (such as "directory" or "version"
#             xml - the xml text to check
#
# returns: the value of the field, or an empty string if it doesn't exist.
#
############################################################################

proc ::MultiSeqDialog::getXMLValue { tag field xml } {
    set startIndex [string first "<$tag>" $xml]
    set endIndex [string first "</$tag>" $xml]

    if { $startIndex == -1 } {
        return ""
    }

    set substr [string range $xml $startIndex $endIndex]

    set startIndex [string first "<$field>" $substr]
    set endIndex [string first "</$field>" $substr]
    
    if { $startIndex == -1 } {
        return ""
    }

    set data [string range $substr [expr $startIndex + [string length "<$field>"]] [ expr $endIndex - 1] ]

    return [string trim $data]
}

############################################################################
#
# setXMLValue
#
# sets the value of a key stored in an XML string
#
# parameters: tag - the tag to get the field of (such as "ncbi_tax")
#             field - the field to get the value of (such as "directory" or "version"
#             value - the new value for the field
#             xml - the xml text to add the data to
#
# returns: the new value of the xml string with the updated value. If "tag"
#          does not exist, it is added, along with the new value. If "field"
#          does not exist within the given tag, it is added.
#
############################################################################

proc ::MultiSeqDialog::setXMLValue { tag field value xml } {

    if { [string match $xml ""] } {
	set xml "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<multiseq>\n</multiseq>"
    }

    set startIndex [string first "<$tag>" $xml]
    set endIndex [string first "</$tag>" $xml]

    if { $startIndex == -1 } {
	# insert it
	set lastIndex [string last "</" $xml]
	incr lastIndex -1
	set newXML [string replace $xml $lastIndex $lastIndex "\n <$tag>\n  <$field>\n   $value\n  </$field>\n </$tag>\n"]
	return $newXML
    }

    set fieldStart [string first "<$field>" $xml $startIndex]
    set fieldEnd [string first "</$field>" $xml $startIndex]
    if { $fieldStart == -1 || $fieldStart > $endIndex } {
        # insert it
        incr endIndex -1
        set newXML [string replace $xml $endIndex $endIndex "\n  <$field>\n   $value\n  </$field>\n"]
        return $newXML
    } else {
        
        # Replace it.
        set newXML [string range $xml 0 [expr $fieldStart+[string length "<$field>"]]]
        append newXML "   $value\n  "
        append newXML [string range $xml $fieldEnd end]
        return $newXML
    }
}


############################################################################
#
# setBrowseDirectory
#
# sets the directory to download a database
#
# parameters: oldDir - the previous directory
#             textName - the name of the tcl entry widget from which to get
#                        the new value
#
# Note: this changes the name in the text box, but does not change the 
#       xml in the xmlValueList data member
#
############################################################################

proc ::MultiSeqDialog::setBrowseDirectory {oldDir textName} {

    if {$oldDir != ""} {
        set newDirectory [tk_chooseDirectory -initialdir $oldDir -title "Choose Directory"]
    } else {
        set newDirectory [tk_chooseDirectory -title "Choose Directory"]
    }
    if { ![string match $newDirectory ""] } {
        $textName delete 0 end
        $textName insert 0 $newDirectory
    }
}


############################################################################
#
# getVariable
#
# shortcut to getting a preferences for a given software package
#
# parameters: swName - name of the software package
#             key - the name of the variable to get the value of
#
# returns: the value of the variable, or an empty string if it can't be found
#
############################################################################

proc ::MultiSeqDialog::getVariable {key variableName} {

    variable xmlValueList
    return [getXMLValue $key $variableName $xmlValueList]
}

############################################################################
#
# setVariable
#
# shortcut to setting a preference for a given software package
#
# parameters: swName - name of the software package
#             key - variable name
#             value - new value
#
# returns: the XML of xmlValueList with the new version
#
############################################################################

proc ::MultiSeqDialog::setVariable { key variableName variableValue } {

    variable xmlValueList
    return [set xmlValueList [setXMLValue $key $variableName $variableValue $xmlValueList]]
}

############################################################################
#
# getDirectory
#
# shortcut to getting a directory for a given database
#
# parameters: dbName - name of the database
#
# returns: the path to the database, or an empty string if it can't be found
#
############################################################################

proc ::MultiSeqDialog::getDirectory { key } {

    return [getVariable $key "directory"]
}

############################################################################
#
# setDirectory
#
# shortcut to setting a directory for a given database
#
# parameters: dbName - name of the database
#             newDirectory - the new value for the directory
#
# returns: the XML of xmlValueList with the new directory
#
############################################################################

proc ::MultiSeqDialog::setDirectory { key newDirectory } {
    
    return [setVariable $key "directory" $newDirectory]
}


############################################################################
#
# getVersion
#
# shortcut to getting a version for a given database
#
# parameters: dbName - name of the database
#
# returns: the version of the database, or an empty string if it can't be found
#
############################################################################

proc ::MultiSeqDialog::getVersion { key } {

    return [getVariable $key "version"]
}

############################################################################
#
# setVersion
#
# shortcut to setting a version for a given database
#
# parameters: dbName - name of the database
#             newVersion - the new value for the version
#
# returns: the XML of xmlValueList with the new version
#
############################################################################

proc ::MultiSeqDialog::setVersion { key newVersion } {

    return [setVariable $key "version" $newVersion]
}

proc ::MultiSeqDialog::getFilename { key } {
    
    set filename [getVariable $key "filename"]
    if {[file exists $filename]} {
        return $filename
    } else {
        set fullPath [file join [getDirectory "metadata"] $filename]
        if {[file exists $fullPath]} {
            return $fullPath
        }
    }
    
	return ""
}

proc ::MultiSeqDialog::setFilename { key newFilename } {

    return [setVariable $key "filename" $newFilename]
}
