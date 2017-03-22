#***************************************************************************
# 
#            (C) Copyright 1995-2005 The Board of Trustees of the
#                        University of Illinois
#                         All Rights Reserved
#
#***************************************************************************
##
## BioCoRE Pub/Sync Plugin
##
## Authors: Michael Bach, John Stone
##          vmd@ks.uiuc.edu
##
## $Id: biocorepubsync.tcl,v 1.51 2007/02/28 22:39:31 mbach Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/biocore
##
package provide biocorepubsync 1.1

package require biocore 1.25

namespace eval ::BiocorePubSync {
    global env

    variable w

    variable open

    variable load_scroll
    variable files_list
    variable load_frame
    variable path

    variable file_indx

    # list of psf file id's that have been loaded
    variable biofs_psf_file

    # list of pdb file id's that have been loaded
    variable biofs_pdb_file

    # list of dcd file id's that have been loaded
    variable biofs_dcd_file
    variable biofs_file

    # list of names of files that have been loaded, so they can be deleted
    variable fileList

    # top menubar of main window
    variable menubar

    # scrollList of state names
    variable name_list

    # scrollList of user names
    variable username_list

    #variable date_list

    #scrollList of state ids
    variable id_list

    # scroll list of user names
    variable user_list

    # text area with state name
    variable name_text
    # text area with state description
    variable desc_text

    # scroll list of user id's
    variable userIdList

    # scrollbar to scroll through states
    variable state_scroll
    
    # popup window for state tables
    variable popup

    variable m_orderSort
    variable m_userSort

    # title of the main window
    variable m_window_title

    # flag for saving snapshot
    variable m_snapshot 0

    variable fileId

    # flag to determine if a state in the list has been clicked once
    variable m_one_click 0

    # list of file id's
    variable file_list

    # highest id of the states in the project. Used to determine if new states
    # have been added after a refresh
    variable maxId -1

    # current user to show states of (-1 if all states are shown)
    variable m_userSort -1
    # current order sort (by id, user, or subject)
    variable m_orderSort -1
    # current sort direction (ascending ("asc") or descending ("desc"))
    variable m_orderDirection "desc"
    
    # flag to determine if a state is being added
    variable m_adding 0
    # flag to determine if a state is being loaded
    variable m_loading 0


    # vmdPath is the full path to the vmd .ServerFiles directory
    # for the current project directory in BioCoRE
    variable vmdPath


    # directory to store temporary files
    variable tmpdir

    # file to save temporary state for "Undo"
    variable tmp_save

    #save_state $tmp_save

    # pub/synch version number
    variable version .80

    # biocore handle
    #variable biocore_handle

    # determines if user is logged in
    variable is_logged_in 0


    # timeout for http transactions (milliseconds)
    variable m_timeout 5000

    variable newfilename

    # listener id
    variable listId

    # notification socket
    variable notificationSock

}

###################
#
# session_window
#
# Displays the main window
# 
# parameters: none
#

proc ::BiocorePubSync::session_window { } {

    #variable biocore_handle

    #::BiocorePubSync::biocore_handle initDefault
    ::biocore::initDefault "vmdPubSync"

    variable w

    if {[catch {

    set m_WindowTitle "BioCoRE-VMD:"

    set m_File "File"
    set m_Edit "Edit"
    set m_Load "Load File from BioFS"
    set m_Show "Show State info"
    set m_Undo "Undo last State load"
    set m_Delete "Delete selected state"
    #set m_All "All"
    set m_UserList "User States"
    set m_Search "Search States"
    set m_Close "Close state window"

    set m_Help "Help"
    set m_PubSynchHelp "Load/Save state window help"
    set m_VMDHelp "VMD Help"
    set m_BiocorePluginHelp "BioCoRE Plugin help"

    #set m_Date "Date"
    set m_User "User"
    set m_Name "State Name"
    set m_username "User Name"
    set m_Desc "Description"
    set m_Id "Id"

    set m_Save "Save State"
    set m_SaveSnapshot "Save snapshot"
    set m_Refresh "Refresh List"
    set m_LoadState "Load selected state"


    variable menubar


    variable name_list
    variable username_list
    #variable date_list
    variable id_list

    variable user_list

    variable name_text
    variable desc_text

    variable userIdList

    variable state_scroll
    
    variable popup
    variable m_orderSort
    variable m_userSort

    variable m_window_title
    variable m_snapshot

    variable notificationSock
    variable listId

    global env
    catch {
	if { ![winfo exists .w] } {
	    set w [toplevel .w]
	}

    pack forget $w.error_window
    }

    if { ![winfo exists $w.main_window] } {
	set main_window [frame $w.main_window]
    } else {

	catch {

	set main_window $w.main_window
	wm title .w $m_window_title

	if { [winfo exists $w.main_window.menu_frame.project_menubutton.project_menu] } {
	    
	    #set projList [::BiocorePubSync::biocore_handle getProjectList]
	    #biocore_handle configure Project [lindex $projList 1]
	    set projList [::biocore::getProjectList]
	    set ::biocore::Project [lindex $projList 1]
	    
	    set index 0
	    set current_proj 0
	    .w.main_window.menu_frame.project_menubutton.project_menu delete 0 end
	    
	    foreach { project id } $projList {

		if { [string equal $id $::biocore::Project] } {
		    set current_proj $index;
		    set m_window_title $m_WindowTitle$project
		    wm title .w $m_WindowTitle$project
		}
		set command "::BiocorePubSync::switch_project $id; set ::BiocorePubSync::m_window_title \"$m_WindowTitle$project\"; wm title .w \"$m_WindowTitle$project\""
		.w.main_window.menu_frame.project_menubutton.project_menu add radiobutton -label $project -variable "project" -value $id \
		    -command $command
		incr index
	    }
	}
	} foo

	#switch_project [biocore_handle cget Project]
	switch_project $::biocore::Project

	return $w
	
    }
	set m_window_title $m_WindowTitle
    wm title .w $m_WindowTitle

    variable open 1
    
    bind $w <Destroy> { if { $::BiocorePubSync::open } { set ::BiocorePubSync::open 0 ; wm withdraw $::BiocorePubSync::w;}}

    # Frames

    set menu_frame [frame $main_window.menu_frame -padx 5 -pady 5]
    
    set left_frame [frame $main_window.left_frame -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]

    set state_frame [frame $left_frame.state_frame -borderwidth 1 -highlightbackground black -relief solid]
    
    set bottom_frame [frame $main_window.bottom_frame -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]
    set user_frame [frame $bottom_frame.user_frame -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]
    set save_frame [frame $bottom_frame.save_frame -borderwidth 1 -highlightbackground black -relief solid -padx 3 -pady 3]

    set inner_name_frame [frame $save_frame.inner1 -borderwidth 1 -highlightbackground black -relief solid]
    set inner_desc_frame [frame $save_frame.inner2 -borderwidth 1 -highlightbackground black -relief solid]
    set inner_button_frame [frame $save_frame.inner3 ]

    set header_frame [frame $left_frame.header_frame]

    set username_frame [frame $header_frame.username_frame -borderwidth 1 -highlightbackground black -relief solid]
    set name_frame [frame $header_frame.name_frame -borderwidth 1 -highlightbackground black -relief solid]
    set id_frame [frame $header_frame.id_frame -borderwidth 1 -highlightbackground black -relief solid]

    set server_frame [frame $main_window.server_frame -borderwidth 1 -highlightbackground black -relief solid -padx 5 -pady 5]
	
	if [catch {
	image create photo "locked" -file "$env(VMDDIR)/plugins/noarch/tcl/biocore1.0/locked.gif" -format "gif"
	image create photo "unlocked" -file "$env(VMDDIR)/plugins/noarch/tcl/biocore1.0/unlocked.gif" -format "gif"
	
	if { [string first "https:" $::biocore::URL] == 0 } {
	    set icon_label [label $server_frame.icon_label -image locked]
	} elseif { [string first "http:" $::biocore::URL] == 0 } {
	    set icon_label [label $server_frame.icon_label -image unlocked]
	}
	}] {
	    # Error: No icon found
	    set icon_label [label $server_frame.icon_label]
	}
	set server_label [label $server_frame.server_label -text "Server: $::biocore::URL"]


    set scroll_frame [frame $left_frame.scroll_frame -borderwidth 1 -highlightbackground black -relief solid]

    # Text areas
    set name_text [text $inner_name_frame.name_text -width 20 -height 1 -wrap word]
    set desc_text [text $inner_desc_frame.name_desc -width 20 -height 4 -wrap word]
    
    #Buttons
    set save_button [button $inner_button_frame.save_button -text $m_Save -width 17 -command { ::BiocorePubSync::biocore_publish [$::BiocorePubSync::name_text get 0.0 end] [$::BiocorePubSync::desc_text get 0.0 end] 1 } ]

    # Checkbox
    set save_snapshot_checkbox [checkbutton $inner_button_frame.save_snapshot_checkbox -variable ::BiocorePubSync::m_snapshot ]

    # Labels
    set name_label [label $inner_name_frame.name -text $m_Name -width 11]
    set desc_label [label $inner_desc_frame.desc -text $m_Desc -width 11]
    set snapshot_label [label $inner_button_frame.snapshot_label -text $m_SaveSnapshot]

    set username_button [button $username_frame.username_button -text $m_username -width 11 -padx 1 -pady 1 -relief solid -state normal -foreground black -borderwidth 0 -command { ::BiocorePubSync::switch_order 2; set ::BiocorePubSync::m_orderSort 2; ::BiocorePubSync::populate_table_by_order $::BiocorePubSync::m_userSort $::BiocorePubSync::m_orderSort }]

    set name_button [button $name_frame.name_button -text $m_Name -padx 1 -pady 1  -relief solid -state normal -foreground black -borderwidth 0 -command { ::BiocorePubSync::switch_order 1; set ::BiocorePubSync::m_orderSort 1; ::BiocorePubSync::populate_table_by_order $::BiocorePubSync::m_userSort $::BiocorePubSync::m_orderSort }]

    set id_button [button $id_frame.id_button -text $m_Id -width 5 -padx 1 -pady 1  -relief solid -state normal -foreground black -borderwidth 0 -command { ::BiocorePubSync::switch_order 3; set ::BiocorePubSync::m_orderSort 3; ::BiocorePubSync::populate_table_by_order $::BiocorePubSync::m_userSort $::BiocorePubSync::m_orderSort}]
    set user_list_label [label $user_frame.user_list_label -text $m_UserList]

    # Scrollbars
    set state_scroll [scrollbar $scroll_frame.state_scroll -command {scrollListBoxes}]
    set user_scroll [scrollbar $user_frame.user_scroll -command {user_scroll yview}]

    # Listboxes
    set username_list [listbox $state_frame.username_list -height 5 -width 11 -selectmode single -exportselection false -yscrollcommand {$state_scroll set}]
    set name_list [listbox $state_frame.name_list -height 5 -selectmode single -exportselection false -yscrollcommand {$state_scroll set}]
    set id_list [listbox $state_frame.id_list -height 5 -width 5 -selectmode single -exportselection false -yscrollcommand {$state_scroll set}]

    set user_list [listbox $user_frame.user_list -height 5 -width 8 -selectmode single -exportselection false -yscrollcommand {$user_scroll set}]

    # popup menu
    set popup [menu $menu_frame.popup -type normal -tearoff 0]
    $popup add command -label "Load this state" -command { if { [catch {::BiocorePubSync::biocore_synchronize [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection]] 0 } ] } { ::BiocorePubSync::no_state_selected "No state selected for load" "" } }
    $popup add command -label "Delete this state" -command { if { [catch { ::BiocorePubSync::delete_entry [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection]] } ] } { ::BiocorePubSync::no_state_selected "No state selected for deletion" "" } }
    $popup add command -label "Show only this user's states" \
	-command { set ::BiocorePubSync::m_userSort [::BiocorePubSync::getUserOfSelectedState]; ::BiocorePubSync::populate_table_by_user $::BiocorePubSync::m_userSort }
    $popup add command -label "Show state info" \
	-command { if { [catch { ::BiocorePubSync::show_state_info [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection]] }]} { ::BiocorePubSync::no_state_selected "No state selected for info" "" } }
    $popup add separator
    $popup add command -label $m_Refresh -command {::BiocorePubSync::populate_table}

    #
    # Bindings for mouse button clicks

    # Left-button single-click for state lists: show info in name & description areas
    bind $username_list <ButtonRelease-1> { ::BiocorePubSync::one_click $::BiocorePubSync::username_list}
    bind $name_list <ButtonRelease-1>  { ::BiocorePubSync::one_click $::BiocorePubSync::name_list}
    bind $id_list <ButtonRelease-1> { ::BiocorePubSync::one_click $::BiocorePubSync::id_list}
    
    # Left-button double click for state lists: Show info and load state
    bind $name_list <Double-ButtonPress-1> { ::BiocorePubSync::double_click $::BiocorePubSync::name_list }
    bind $id_list <Double-ButtonPress-1> { ::BiocorePubSync::double_click $::BiocorePubSync::id_list }
    bind $username_list <Double-ButtonPress-1> { ::BiocorePubSync::double_click $::BiocorePubSync::username_list }
    
    # Left-button Double-click on user list: load that user's most recent state
    bind $user_list <Double-ButtonRelease-1> { 
	::BiocorePubSync::load_users_most_recent [lindex $::BiocorePubSync::userIdList [$::BiocorePubSync::user_list nearest %y]]; \
	    $::BiocorePubSync::user_list itemconfigure [$::BiocorePubSync::user_list nearest %y] -background ""  
    }
    
    # Left button Single-click on user list: Show only states of that user
    bind $user_list <ButtonPress-1> {
	$::BiocorePubSync::id_list delete 0 [$::BiocorePubSync::id_list size]; \
	    $::BiocorePubSync::user_list selection clear 0 end; \
	    $::BiocorePubSync::user_list selection set [$::BiocorePubSync::user_list nearest %y]; \
	    set ::BiocorePubSync::m_userSort [lindex $::BiocorePubSync::userIdList [$::BiocorePubSync::user_list curselection]]; \
	    ::BiocorePubSync::populate_table_by_user $::BiocorePubSync::m_userSort; \
	    $::BiocorePubSync::user_list itemconfigure [$::BiocorePubSync::user_list nearest %y] -background "" }
    
    # Middle- and Right-button clicks on state lists: Show pop-up menu
    bind $name_list <ButtonPress-2> { ::BiocorePubSync::popup_menu %X %Y %y}
    bind $name_list <ButtonPress-3> { ::BiocorePubSync::popup_menu %X %Y %y}

    bind $username_list <ButtonPress-2> { ::BiocorePubSync::popup_menu %X %Y %y}
    bind $username_list <ButtonPress-3> { ::BiocorePubSync::popup_menu %X %Y %y}

    bind $id_list <ButtonPress-2> { ::BiocorePubSync::popup_menu %X %Y %y}
    bind $id_list <ButtonPress-3> { ::BiocorePubSync::popup_menu %X %Y %y}

    bind $id_list <Button-4> { $::BiocorePubSync::name_list yview scroll -5 units; $::BiocorePubSync::username_list yview scroll -5 units }
    bind $id_list <Button-5> { $::BiocorePubSync::name_list yview scroll 5 units; $::BiocorePubSync::username_list yview scroll 5 units }

    bind $name_list <Button-4> { $::BiocorePubSync::id_list yview scroll -5 units; $::BiocorePubSync::username_list yview scroll -5 units }
    bind $name_list <Button-5> { $::BiocorePubSync::id_list yview scroll 5 units; $::BiocorePubSync::username_list yview scroll 5 units }

    bind $username_list <Button-4> { $::BiocorePubSync::name_list yview scroll -5 units; $::BiocorePubSync::id_list yview scroll -5 units }
    bind $username_list <Button-5> { $::BiocorePubSync::name_list yview scroll 5 units; $::BiocorePubSync::id_list yview scroll 5 units }


    # Configure scrollbars
    $state_scroll configure -command "::BiocorePubSync::scrollListBoxes"
    $username_list configure -yscrollcommand "$state_scroll set"
    $name_list configure -yscrollcommand "$state_scroll set"
    $id_list configure -yscrollcommand "$state_scroll set"

    $user_scroll configure -command "$user_list yview"
    $user_list configure -yscrollcommand "$user_scroll set"

    
    # Menus

    #set projList [biocore_handle getProjectList]
    set projList [::biocore::getProjectList]

    set project_menubutton [menubutton $menu_frame.project_menubutton -relief flat -menu $menu_frame.project_menubutton.project_menu -text "Project" -width 7]
    set project_menu [menu $menu_frame.project_menubutton.project_menu -tearoff 0]

    set index 0
    set current_proj 0

    foreach { project id } $projList {
	if { [string equal $id $::biocore::Project ] } {
	    set current_proj $index;
            set m_window_title $m_WindowTitle$project
	    wm title .w $m_WindowTitle$project
	}
	set command "::BiocorePubSync::switch_project $id; set ::BiocorePubSync::m_window_title \"$m_WindowTitle$project\"; wm title .w \"$m_WindowTitle$project\""
	$project_menu add radiobutton -label $project -variable "project" -value $id \
		-command $command
	incr index
    }
    
    #$project_menu activate $id
    variable  fileId
    set fileId -1
    catch {
	set fileId [$id_list get [$id_list curselection]]
    }

    set file_menubutton [menubutton $menu_frame.file_menubutton -relief flat -menu $menu_frame.file_menubutton.file_menu -text $m_File -width 4]
    set file_menu [menu $menu_frame.file_menubutton.file_menu -type normal -title "File" -tearoff 0]
    $file_menu add command -label $m_Load -command { ::BiocorePubSync::load_from_biofs_window } 
    $file_menu add command -label $m_Show -command { if { [catch { ::BiocorePubSync::show_state_info [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection]] }]} { ::BiocorePubSync::no_state_selected "No state selected for info" "" } }

    $file_menu add command -label $m_Save -command { if { [::BiocorePubSync::biocore_publish [$::BiocorePubSync::name_text get 0.0 end] [$::BiocorePubSync::desc_text get 0.0 end] 1] == 1 } {  ::BiocorePubSync::populate_table; } }
    
    $file_menu add command -label $m_LoadState -command { if { [catch {::BiocorePubSync::biocore_synchronize [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection]] 0 }] } { ::BiocorePubSync::no_state_selected "No state selected for load" ""} }
    
     $file_menu add command -label $m_Refresh -command { ::BiocorePubSync::populate_table }
    
    $file_menu add command -label $m_Delete -command { if { [catch { ::BiocorePubSync::delete_entry [$::BiocorePubSync::id_list get [$::BiocorePubSync::id_list curselection] ] } ] } {::BiocorePubSync::no_state_selected "No state selected for deletion" "" } }
    $file_menu add command -label $m_Close -command { after idle [wm withdraw $::BiocorePubSync::w] }
    
    set edit_menubutton [menubutton $menu_frame.edit_menubutton -menu $menu_frame.edit_menubutton.edit_menu -text "Edit" -width 4]
    set edit_menu [menu $menu_frame.edit_menubutton.edit_menu -type normal -title $m_Edit -tearoff 0]
    $edit_menu add command -label $m_Undo -command { mol delete all; ::BiocorePubSync::biocore_synchronize "0" 1 }
    $edit_menu add command -label $m_Search -command { ::BiocorePubSync::search_window }
    
    set help_menubutton [menubutton $menu_frame.help_menubutton -menu $menu_frame.help_menubutton.help_menu -text "Help" -width 4]
    set help_menu [menu $menu_frame.help_menubutton.help_menu -type normal -title $m_Help -tearoff 0]

    set URL $::biocore::URL
    
    set index [string first "/" $URL 8]
    
    set index2 [string first "/" $URL [expr { $index+1 }]]

    variable helpURL
    set helpURL "[string range $URL 0 $index2]docs/pubsynch.html"
    
    $help_menu add command -label $m_PubSynchHelp -command { vmd_open_url $::BiocorePubSync::helpURL }
    $help_menu add command -label $m_BiocorePluginHelp -command { vmd_open_url "[string trimright [vmdinfo www] /]/plugins/biocore"}
    #$help_menu add command -label $m_VMDHelp -command { vmd_open_url "http://www.ks.uiuc.edu/Research/vmd/vmd_help.html" }

    #set users [biocore_handle getUserList]
    set users [ ::biocore::getUserList ]

    set userIdList ""
    $user_list insert end " - All - "
    set userIdList [linsert $userIdList end -1]

    #switch_project [biocore_handle cget Project]
    switch_project $::biocore::Project

    # Pack...
    
    pack $menu_frame -side top -fill x
    pack $file_menubutton -side left -fill x
    pack $edit_menubutton -side left -fill x
    pack $project_menubutton -side left -fill x
    pack $help_menubutton -side right -fill x


    pack $server_frame -side top -fill x
    pack $icon_label -side left
    pack $server_label -side left

    pack $username_list -side left -fill y
    pack $name_list -side left -fill both -expand 1
    pack $id_list -side left -fill y

    pack $scroll_frame -side right -fill y -anchor w
    pack $state_scroll -side left -fill y

    pack $user_list_label -side top -fill x
    pack $user_list -side left -fill y -expand 1
    pack $user_scroll -side left -fill y

    pack $name_label -side left
    pack $name_text -side left -expand 1 -fill x

    pack $desc_label -side left
    pack $desc_text -side left -expand 1 -fill both -anchor n

    pack $save_button -side left
    pack $save_snapshot_checkbox -side right
    pack $snapshot_label -side right

    pack $inner_button_frame -side bottom -anchor s -pady 5
    pack $inner_name_frame -side top -anchor nw -fill x
    pack $inner_desc_frame -side top -expand 1 -fill both -anchor n

    pack $header_frame -side top -anchor w -fill x

    pack $save_frame -side left -fill both -expand 1 -anchor n
    pack $state_frame -side top -anchor n -expand 1 -fill both
    pack $bottom_frame -side bottom -fill both -expand 1

    pack $left_frame -side top -fill both -expand 1
    pack $user_frame -side right -fill y  -anchor e -padx 5 -pady 5

    pack $username_button -side left
    pack $name_button -side left -fill x -expand 1
    pack $id_button -side left


    pack $username_frame -side left
    pack $name_frame -side left -fill x -expand 1
    pack $id_frame -side left
    

    populate_table

    # Open molec, if need be
    if { [info exists env(LOADVMDSESSION)] } {
	#puts "biocorepubsync) Loading State \#$env(LOADVMDSESSION)"
	after idle ::BiocorePubSync::biocore_synchronize $env(LOADVMDSESSION) 0
    }

} foo3 ]} {
    #puts "biocorepubsync) Error in session_window2: $foo3"
	if { ![string match $foo3 ".w"] } {
	    return [error_window]
	}
    }
    if { [winfo exists $w.login_window] } {
	pack forget $w.login_window
    }
    if { [winfo exists $w.error_window] } {
	pack forget $w.error_window
    }
    pack $main_window -fill both -expand 1
    after idle [bind $w <Map> {if { [::BiocorePubSync::redraw] } { after idle [::BiocorePubSync::biocorePlugin] } }]

    set currentProject 1

    set projList [::biocore::getProjectList]

    set currentProject [lindex $projList 1]

    # at this point, we should be a registered user, or we should have
    # printed failure, anyway..  In a real app you would do something
    # different in test_verify than just print an error
    set listId [lindex [::biocore::registerListener "cp"] 0]

    set checkLatestTag [after 1000 ::BiocorePubSync::check_latest $listId]

    #scan $listId "%s %s" strId strLast
    #puts "biocorepubsync) Listener is registered. Listener ID: $strId last access: $strLast"

    
    set listPort [::biocore::getListenerPort]
    
    # the java control panel adds projects here.  That code has already
    # been tested, though.
    
    #test_getListenerPrefs "tclTestCP"
    
    # now we are ready to start the socket listening
    # this is a synchronous connection: 
    # The command does not return until the server responds to the 
    #  connection request
    regexp "://(.*?)\[:/\]" $::biocore::URL Junk strMachine
    #puts "biocorepubsync) opening connection to $strMachine on port $listPort"
    set notificationSock [socket $strMachine $listPort]
    puts $notificationSock "<SessionID>"
    flush $notificationSock
    puts $notificationSock $::biocore::Session
    flush $notificationSock
    puts $notificationSock "</SessionID>"
    flush $notificationSock
    puts $notificationSock "<CPID>"
    flush $notificationSock
    puts $notificationSock "$listId"
    flush $notificationSock
    puts $notificationSock "</CPID>"
    flush $notificationSock
    #puts "biocorechat) done opening connection"
    
    #if {[eof $esvrSock]} { # connection closed .. abort }
    
    # configure channel modes
    # ensure the socket is NOT line buffered so we don't wait for a line of text 
    # at a time 
    # Depending on your needs you may also want this unbuffered so 
    # you don't block in reading a chunk larger than has been fed 
    #  into the socket
    # i.e fconfigure $esvrSock -blocking off
    fconfigure $notificationSock -buffering none -blocking off -encoding binary
    
    # Setup monitoring on the socket so that when there is data to be 
    # read the proc "read_sock" is called
    fileevent $notificationSock readable [list ::BiocorePubSync::read_sock $notificationSock $listId]

    return $w

    #puts "biocorepubsync) Error in session_window: $foo"
    
}; #end session_window

###################
#
# scrollListBoxes
#
# scrolls all the table listboxes,
# (name list, state name list, and id list)
# when one scrollbar is changed
#
# parameters: args - all items following the command
#
proc ::BiocorePubSync::scrollListBoxes { args } {

    variable name_list
    variable username_list
    variable id_list

    eval $name_list yview $args
    eval $username_list yview $args
    eval $id_list yview $args
    
}

###################
#
# highlight_all
#
# highlights the rows of respective listboxes
#
# parameters: index - index of the entry of the listbox that was clicked
#
# returns: the file id of the state that was highlighted
#
proc ::BiocorePubSync::highlight_all { index } {

    variable m_one_click

    catch {
	variable name_list
	variable username_list
	variable id_list
	
	variable name_text
	variable desc_text
	
	variable file_list
	
	variable m_loading
	$name_list selection clear 0 end
	$username_list selection clear 0 end
	$id_list selection clear 0 end
	
	$name_list selection set $index
	$username_list selection set $index
	$id_list selection set $index
	
	$name_text delete 1.0 end
	$desc_text delete 1.0 end
	
	
	set fileId [$id_list get [$id_list curselection]]
	
	$name_text insert end [$name_list get [$name_list curselection]]
	$desc_text insert end [get_description $fileId]
	
	
	return $fileId
    } foo
    #puts "biocorepubsync) error: $foo"
    #puts "biocorepubsync) No states have been saved"
    set m_one_click 0
    return 0
} ; # end highlight_all

###################
#
# one_click
#
# handles a single-click event in the State List
#
# parameters:
#  list: the scroll list the single click event took place in
#
proc ::BiocorePubSync::one_click { list } {
    
    variable m_one_click
    variable id_list
    variable name_list
    variable username_list
    variable userIdList
    variable user_list
	if { $m_one_click } {
	    return
	} else {
	    catch {
		set m_one_click 1
		highlight_all [$list curselection] 
		$name_list itemconfigure [$list curselection] -background ""
		$id_list itemconfigure [$list curselection] -background ""
		$username_list itemconfigure [$list curselection] -background ""
		
		if { $::biocore::Project != 1 } {
		    # clear user list
		    # For single or double click?
		    set userId [ getUserOfSelectedState]
		    set index [lsearch $userIdList $userId]
		    $user_list itemconfigure $index -background ""
		}
	    } foo
	    #puts "biocorepubsync) Error in one_click: $foo"
	    return $foo
	}
}


###################
#
# double_click
#
# handles a double-click event in the State List
#
# parameters: 
#    list: the scroll list the double-click event took place in
#
proc ::BiocorePubSync::double_click { list } {
    variable m_loading
    variable id_list
    catch {
	if { $m_loading } { 
	    return
	} else { 
	
	    set m_loading 1
	    #wm title .w "Loading..."
	    if { [catch {
		::BiocorePubSync::biocore_synchronize [$id_list get [$list curselection]] 0
	    } foo] } {
	     #puts "biocorepubsync) Error in double_click: $foo"
		set m_loading 0
		}
	}
    }
}
    
###################
#
# switch_order
#
# changes the order direction of the lists (ascending or descending)
#
# parameters
#  order: the order to sort the state list: Ascending ("asc")
#  or Descending ("desc")
#
proc ::BiocorePubSync::switch_order { order } {

    variable m_orderSort
    variable m_orderDirection

    if { $order == $m_orderSort } {
	if { [string match $m_orderDirection "asc"] } {
	    set m_orderDirection "desc"
	} else {
	    set m_orderDirection "asc"
	}
    } else {
	
	if { $order == -1 || $order == 3 } {
	    set m_orderDirection "desc"
	} else {
	    set m_orderDirection "asc"
	
	}
    }
}

###################
#
# populate_table_by_order
#
# populates the listbox with the saved VMD entries from the notebook, given a
# specific order, and only showing the entries of a specific user
#
# parameters: user - Id of the user of which to display messages. 
#                    If user is -1, all messages are displayed
#             order - How to order the table (from the Notebook constants:
#                     -1 (default) = by id (or date)
#                     2 = by subject
#                     3 = by user
#                     4 = by id (or date)
#                      
#
proc ::BiocorePubSync::populate_table_by_order { user order } {

    variable m_userSort
    variable m_orderSort
    variable m_orderDirection

    variable username_list
    variable name_list
    variable id_list
    
    variable user_list
    variable userIdList

    variable maxId

    variable file_list
    set file_list ""
    set start 0
    set end 0

    if { [catch {
	set m_orderSort $order
	set m_userSort $user
	
	set curr_size [$id_list size]
	# clear listboxes
	$username_list delete 0 [$username_list size]
	$name_list delete 0 [$name_list size]
	$id_list delete 0 [$id_list size]

	# get list of NotebookEntrys
	if { $order == -1 } {
	    #set entry_info_list [biocore_handle getNotebookEntryList 2 $start $end]
	    set entry_info_list [::biocore::getNotebookEntryList 2 $start $end]
	} else {
	    #set entry_info_list [biocore_handle getNotebookEntryListByOrder 2 $start $end $order]
	    set entry_info_list [::biocore::getNotebookEntryListByOrder 2 $start $end $order]
	}
	
	
	#create an associative array to relate the Entry's id number with its 
	#index in the list. (Shown by title)
	set tmpId 0
	set highlightList ""
	set userHighlightList ""
	
	set tmpMax $maxId
	
	for { set i 0 } { $i < [llength $entry_info_list] } { incr i } {
	    set curr_entry [lindex $entry_info_list $i]
	    
	    set title ""
	    set id -1
	    set userId -1
	    set curr_user ""
	    for { set j 0 } { $j < [llength $curr_entry] } { incr j } {
		if { [string match "Title" [lindex $curr_entry $j]] } {
		    set title [lindex $curr_entry [incr j]]
		}
		if { [string match [lindex $curr_entry $j] "Id"] } {
		    set id [lindex $curr_entry [incr j]]
		    if { $id > $maxId } {
			set tmpMax $id
		    }
		}
		
		if { [string match "UserId" [lindex $curr_entry $j]] } {
		    set userId [lindex $curr_entry [incr j]]
		}
		if { [string match "Login" [lindex $curr_entry $j]] } {
		    set curr_user [lindex $curr_entry [incr j]]
		    
		}
		
	    }
	    # file_list is a list of the file id's
	    # element i of file_list corresponds to element i in 
	    # the listboxes

	    if { $user == -1  || $user == $userId } {
		if {$id >= 0 } {
		    
		    if { [string match $m_orderDirection "desc"] } {
			# most recent at the top
			set file_list [linsert $file_list 0 $id]
			$name_list insert 0 $title
			$id_list insert 0 $id
			$username_list insert 0 $curr_user
		    } else {
			
			set file_list [linsert $file_list end $id]
			$name_list insert end $title
			$id_list insert end $id
			$username_list insert end $curr_user
		    }
		    if { $curr_size > 0 } {
			if { $maxId > 0 && $id > $maxId } {
			    set userIndex [lsearch $userIdList $userId]
			    if { $::biocore::Project != 1 } {
				$user_list itemconfigure $userIndex -background red
			    }
			    #$name_list itemconfigure 0 -background red
			    #$id_list itemconfigure 0 -background red
			    #$username_list itemconfigure 0 -background red
			    
			    set tmpMax $id
			    lappend highlightList $id
			    #lappend userHighlightList $userIndex
			    
			}
		    }
		}
	    }
	    incr tmpId
	}

	foreach i $highlightList {
	    set id [lsearch $file_list $i]
	    
	    $name_list itemconfigure $id -background red
	    $id_list itemconfigure $id -background red
	    $username_list itemconfigure $id -background red
	}
	
	#foreach i $userHighlightList {
	#	$user_list itemconfigure $userIndex -background red
	#    }
	if { [llength $entry_info_list] == 0 } {
	    #puts "biocorepubsync) No states have been saved yet."
	} else {
	    set maxId $tmpMax
	}
    } populate_error] } {
       puts "biocorepubsync) Error: $populate_error"
       if { [string first "Invalid User" $populate_error] != -1 } {
          ::BiocorePubSync::biocorePlugin
       }

	if { [string first "couldn't open socket" $populate_error] != -1 } {
	    new_error_window 
	}
    }
} ; # end populate_table_by_order

###################
#
# populate_table_by_user
#
# populates the listbox with the saved VMD entries from the notebook,
#  listing only those of a specific user
#
# parameters: user - Id of the user of which to display messages. 
#                    If user is -1, all messages are displayed
#                      
#
proc ::BiocorePubSync::populate_table_by_user { user } {

    variable m_userSort
    variable m_orderSort

    set m_userSort $user
    ::BiocorePubSync::populate_table_by_order $user $m_orderSort

}

###################
#
# populate_table
#
# populates the listbox with the saved VMD entries, with the last specified
# user and order
#
proc ::BiocorePubSync::populate_table { } {
    
    variable m_userSort
    variable m_orderSort

    populate_table_by_order $m_userSort $m_orderSort
    
}

###################
#
# populate_table_by_search
#
# populates the listbox with the saved VMD entries from the notebook,
# taking only those containing certain text
#
# parameters: 
#  text - text to search for
#  search_desc - if 1, search the description, else only search the name
# 
proc ::BiocorePubSync::populate_table_by_search { text search_desc } {

    variable username_list
    variable name_list
    variable id_list
    
    variable user_list
    variable userIdList

    variable m_window_title

    variable file_list
    set file_list ""
    set start 0
    set end 0

    if { [catch {
	wm title .w "Searching..."
    set curr_size [$id_list size]
    # clear listboxes
    $username_list delete 0 [$username_list size]
    $name_list delete 0 [$name_list size]
    $id_list delete 0 [$id_list size]

    # get list of NotebookEntrys
    #set entry_info_list [biocore_handle getNotebookEntryList 2 $start $end]
	set entry_info_list [::biocore::getNotebookEntryList 2 $start $end]

    #create an associative array to relate the Entry's id number with its 
    #index in the list. (Shown by title)
    set tmpId 0
    for { set i 0 } { $i < [llength $entry_info_list] } { incr i } {
	set curr_entry [lindex $entry_info_list $i]

	set title ""
	set id -1
	set userId -1
	set curr_user ""
	set description ""
	for { set j 0 } { $j < [llength $curr_entry] } { incr j } {

	    if { [string match "Title" [lindex $curr_entry $j]] } {
		set title [lindex $curr_entry [incr j]]
	    }
	    if { [string match [lindex $curr_entry $j] "Id"] } {
		set id [lindex $curr_entry [incr j]]
	    }

	    if { [string match "UserId" [lindex $curr_entry $j]] } {
		set userId [lindex $curr_entry [incr j]]
	    }
	    if { [string match "Login" [lindex $curr_entry $j]] } {
		set curr_user [lindex $curr_entry [incr j]]
		
	    }
	
	}
	if { $search_desc } {
	    set description [get_description $id]
	}
	# file_list is a list of the file id's
	# element i of file_list corresponds to element i in 
	# the listboxes
	if {$id >= 0 } {

	    set wordList [split $text]
	    foreach { word } $wordList {
		if { [string match -nocase "*$word*" $title] || [expr { $search_desc && [string match -nocase "*$word*" $description]}] } {
		    set file_list [linsert $file_list 0 $id]
		    $name_list insert 0 $title
		    $id_list insert 0 $id
		    $username_list insert 0 $curr_user
		    
		}
	    }
	    incr tmpId
	}
    }
	wm title .w $m_window_title
    } foo ] } {
	if { [string first "couldn't open socket" $foo] != -1 } {
	    new_error_window
	    return
	}
    }
    #puts "biocorepubsync) Error in search: $foo"
} ; # end populate_table_by_search

###################
#
# search_window
#
# opens the search window
#
#
proc ::BiocorePubSync::search_window { } {

    catch {
	set search_frame [toplevel .search_frame]
	set top_frame [frame $search_frame.top_frame]
	set middle_frame [frame $search_frame.middle_frame]
	set mid_frame1 [frame $middle_frame.frame1]
	set mid_frame2 [frame $middle_frame.frame2]
	set bottom_frame [frame $search_frame.bottom_frame]

	set title_text "Search titles"
	set desc_text "Search descriptions and titles"

	set check_desc 1
	
	#set title_check [checkbutton $mid_frame1.title_check -variable check_title]
	set title_label [label $mid_frame1.title_label -text $title_text]

	set desc_check [checkbutton $mid_frame2.desc_check -variable check_desc]
	set desc_label [label $mid_frame2.desc_label -text $desc_text]

	wm title .search_frame "Search State Titles"
	set search_entry [entry $top_frame.search_entry -textvariable search_text]

	set search_button [button $bottom_frame.search_button -text "Search" \
			       -command { ::BiocorePubSync::populate_table_by_search $search_text $check_desc; after idle destroy .search_frame; }]

	set cancel_button [button $bottom_frame.cancel_button -text "Cancel" \
			       -command { after idle destroy .search_frame }]
					      
	
	pack $search_entry -side left -fill both -expand 1
	pack $search_button -side left
	pack $cancel_button -side right
	pack $top_frame -side top -fill both -expand 1 -padx 5 -pady 5
	pack $middle_frame -side top -fill both -expand 1

	pack $mid_frame2 -side top -fill both -expand 1
	pack $desc_check -side left -anchor w
	pack $desc_label -side left -anchor w

	pack $bottom_frame -side bottom -fill both -expand 1 -padx 5 -pady 5

	pack $search_frame -side top -fill both -expand 1

    } search_already_open
}


###################
#
# add_latest_entry
#
# adds the last entry a user published to the listboxes
#
# parameters: userId - Id of the user to get the last entry of
#                    If it is -1, the last entry submitted by anyone is added
#
proc ::BiocorePubSync::add_latest_entry { userId } {
    variable username_list
    variable name_list
    variable id_list

    variable file_list
    variable m_adding
    variable maxId
    
    set file_list ""
    set start 0
    set end 0
    set lastIndex 0
    
    catch {

    #set entry_info_list [biocore_handle getNotebookEntryList 2 $start $end]
	set entry_info_list [::biocore::getNotebookEntryList 2 $start $end]
    set lastIndex [expr { [llength $entry_info_list] - 1 }]
    set lastEntry [lindex $entry_info_list $lastIndex]

    set title ""
    set id 0
    set desc ""
    set user ""
    for { set j 0 } { $j < [llength $lastEntry] } { incr j } {
	if { [string match "Title" [lindex $lastEntry $j]] } {
	    set title [lindex $lastEntry [incr j]]
	}
	if { [string match [lindex $lastEntry $j] "Id"] } {
	    set id [lindex $lastEntry [incr j]]
	}
	if { [string match [lindex $lastEntry $j] "Description"] } {
	    set desc [lindex $lastEntry [incr j]]
	}
	if { [string match "Login" [lindex $lastEntry $j]] } {
	    set user [lindex $lastEntry [incr j]]
	}
    }
    
    # file_list is a list of the file id's
    # element i of file_list corresponds to element i in 
    # the listboxes
    
    if {$id >= 0 } {
	set file_list [linsert $file_list 0 $id]
	$name_list insert 0 $title
	$id_list insert 0 $id
	$username_list insert 0 $user
	set maxId $id
    }
    }
    set m_adding 0
}

################################
# 
# switch_project
#
# changes the project for the main window
#
# parameters:
#  id - the new project id
#
proc ::BiocorePubSync::switch_project { id } {

    variable vmdPath
    variable user_list
    variable userIdList
    variable id_list
    variable m_userSort

    if { [catch {
    set m_userSort -1
    # delete all from id_list since populate_table checks
    # the size of id_list to determine if anyone should be highlighted
    $id_list delete 0 [$id_list size]
    #biocore_handle configure Project $id

	set ::biocore::Project $id

    populate_table

    set vmdPath [get_vmd_path]

    if { $id != 1 } {

	#set users [biocore_handle getUserList]
	set users [ ::biocore::getUserList ]

	set userIdList ""
	$user_list delete 0 end
	$user_list insert end " - All - "
	set userIdList [linsert $userIdList end -1]
	foreach { name uid } $users {
	    $user_list insert end $name
	    set userIdList [linsert $userIdList end $uid]
	}
    } else {

	# All User Test Project
	#set users [biocore_handle getUserList]
	set users [ ::biocore::getUserList ]
	set userIdList ""
	$user_list delete 0 end
	$user_list insert end " - All - "
	set userIdList [linsert $userIdList end -1]
	foreach { name uid } $users {
	    #$user_list insert end $name
	    set userIdList [linsert $userIdList end $uid]
	}
    }
    } switch_error ] } {
	if { [string match "couldn't open socket" $switch_error] != -1 } {
	    #new_error_window
	    #return
	}
    }
}; # end switch_project

###################
# 
# biocore_synchronize
#
# retrieves a VMD state from the Notebook
# 
# parameters:
#  state: the id of the Notebook message
#  loadTmp: 1 if you're loading a temporary file (so get the data from
#           the temporary save file), 0 if you're not (so save the current
#           state before synchronizing)
#

proc ::BiocorePubSync::biocore_synchronize { state loadTmp { window .w }} {
    catch {

    global env
    variable biofs_psf_file
    variable biofs_pdb_file
    variable biofs_dcd_file
    variable biofs_file

    variable fileList

    variable tmpdir

    variable tmp_save

    variable m_loading
    variable m_window_title

    catch {
	if { ![winfo exists .w] } {
	    set .w $window
	}
	set m_loading 1
	
	if { !$loadTmp } {
	    catch {
		biocore_publish "0" "0" 0
	    }
	}
	catch {
	wm title .w "Loading..."
	}
	# TODO: clear screen of other objects? (floor, lights, etc)
	#set topMolId [molinfo top]
	mol delete all

	set saved_file_list ""
	
	# entry is a list
	set entry_text 0
	set biofs_psf_file ""
	set biofs_pdb_file ""
	set biofs_dcd_file ""
	set biofs_file ""
	
	if { $loadTmp } {
	    set tmpfile [open $tmp_save]
	    set tmptext [read $tmpfile]
	    close $tmpfile
	    set entry_text $tmptext
	} else {
	    if { [catch {
		#set entry [biocore_handle getNotebookEntry $state]
		set entry [::biocore::getNotebookEntry $state]
	    } notebookError ] } {
		#puts "biocorepubsync) Error in getting notebook entry: $notebookError"
		if { [string first "couldn't open socket" $notebookError] != -1 } {
		    puts "biocorepubsync) Notebook error = $notebookError"
		    new_error_window
		    return
		}
	    }
	    for { set j 0 } { $j < [llength $entry] } { incr j } {
		if { [string match "Text" [lindex $entry $j]] } {
		    set entry_text [lindex $entry [incr j]]
		    
		}
	    }
	}
	# make the url start with the user's server url. This will correct problems
	# if a state was saved from a different server.
	if { [regexp -linestop {(http:+)(.*)(/biocore)} $entry_text urltest] } {

	    #regsub -all $urltest $entry_text "[biocore_handle cget URL]" entry_text
	    regsub -all $urltest $entry_text $::biocore::URL entry_text
	}

	regsub -all "session_id" $entry_text "jsessionid" entry_text
	
	#replace saved jsessionid with current jsessionid
	#if save and current id's are the same, do nothing
	if {  [regexp -linestop {jsessionid=([\-]?)([0-9, A-F]+)} $entry_text test] } {
	    if { ![string match $test "jsessionid=$::biocore::Session"] } {	    
		regsub -all $test $entry_text "jsessionid=$::biocore::Session " entry_text
	    }
	}
	
	# if OS is windows, download molecule files to the user's machine
    # and load molecule from there
	
	#set foo ""
	#set os [vmdinfo arch]
	#regexp WIN32 $os foo

	# get current version of VMD (1.8 will be a greater version than 1.8aXXX)
	set eq18 [expr {[string compare [vmdinfo version] "1.8"] == 0}]
	set lt1825 [expr {[string compare [vmdinfo version] "1.8a25"] <= 0}]
	set usingoldversion [expr { !$eq18 && $lt1825 }]
	
	# get version of published state (1.8 will be a greater version than 1.8aXXX)
	set savedVerText ""
	regexp -linestop {VMD version: (.*)} $entry_text savedVerText
	set savedVer [string range $savedVerText 13 end]
	
	set eq18 [expr {[string compare $savedVer "1.8"] == 0}]
	set lt1825 [expr {[string compare $savedVer "1.8a25"] <= 0}]
	set savedoldversion [expr { !$eq18 && $lt1825 }]
	
	# replace "mol load" with "mol new" if saved with an older version
	
	# replace ?'s and &'s since they mess up regsub
	regsub -all {\?} $entry_text "questionmark" entry_text
	regsub -all & $entry_text "ampersand" entry_text

	while { [regexp -linestop "mol load pdb (.)*" $entry_text line ] } {
	    regsub "mol load pdb" $line "mol new" newLine
	    regsub -all $line $entry_text "$newLine type pdb" entry_text
	}
	
	while { [regexp -linestop "mol load psf (.)*" $entry_text line ] } {
	    regsub "mol load psf" $line "mol new" newLine
	    regsub -all $line $entry_text "$newLine type psf" entry_text
	}
    
	regsub -all "ampersand" $entry_text {\&} entry_text
	regsub -all "questionmark" $entry_text {?} entry_text
	
	# replace "mol new" with "mol load webpdb" for webpdb's if
	# user is using an old version
	if { $usingoldversion && !$savedoldversion } {
	    if { [regexp "mol load webpdb" $entry_text webpdb] ||
		 [regexp "type webpdb" $entry_text webpdb2] } {
		regsub -all "mol new" $entry_text "mol load webpdb" entry_text
		#regsub -all "type pdb" $entry_text "" entry_text
	    }
	}
	set fileList ""
	    
	    # the text was saved with 1.8a25 or greater, 
	    #and we're loading from a url, so change the text appropriately
	    # check for pdb files
	    set pdbline ""
	    set ends ""
	    set start 0
	    set end 0
	    set leftToCheck $entry_text

	    # replace URLs in the script with local file names.
	    while { [regexp -linestop {mol (new|addfile) (.*)\.pdb} $leftToCheck pdbline] } {
		regexp -linestop -indices {mol (new|addfile) (.*)\.pdb} $leftToCheck ends
		if { [string first "webpdb" $pdbline] != -1 } {
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    continue
		}

		if { [regexp {http} $pdbline pdbline2] } {
		    
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    
		    
		    regsub -all {\?} $entry_text "questionmark" entry_text
		    regsub -all {\?} $pdbline "questionmark" pdbline
		    regsub -all "&" $entry_text "ampersand" entry_text
		    regsub -all "&" $pdbline "ampersand" pdbline
		    
		    set url $pdbline
		    regsub "mol (new|addfile) " $url "" url
		    #regsub " type pdb" $url "" url
		    set encodedURL $url
		    regsub -all "questionmark" $url {?} url

		    regsub -all "ampersand" $url {\&} url
		    regsub -all "\{" $url "" url
		    regsub -all "\}" $url "" url

		    lappend biofs_pdb_file $url
		    set url [string trim $url]

		    if { [string first "mol addfile" $pdbline] != -1 } {
			set tmpfile [file join $tmpdir tmpfile[clock seconds].pdb]
			set j 0
			while { [file exists $tmpfile] } {
			    set tmpfile [file join $tmpdir tmpfile[clock seconds][incr j].pdb]
			}

			biocorehttpcopy $url $tmpfile $::biocore::Session

			regsub -all $encodedURL $entry_text $tmpfile entry_text

		    } else {

			set tmpfile [file join $tmpdir tmpfile[clock seconds].pdb]
			set j 0
			while { [file exists $tmpfile] } {
			    set tmpfile [file join $tmpdir tmpfile[clock seconds][incr j].pdb]
			}

			biocorehttpcopy $url $tmpfile $::biocore::Session

			regsub -all $encodedURL $entry_text $tmpfile entry_text
			lappend biofs_file $url
		    }
		    
		    regsub -all "mol new" $pdbline "mol urlload pdb" newpdbline
		    
		    #regsub -all " type pdb" $newpdbline "" newpdbline
		    regsub -all $pdbline $entry_text $newpdbline entry_text
		    regsub -all "questionmark" $entry_text {?} entry_text
		    regsub -all "ampersand" $entry_text {\&} entry_text
		    
		    
		} else {
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    continue
		}
	    }

	    # check for psf files
	    set psfline ""
	    set ends ""
	    set start 0
	    set end 0
	    set leftToCheck $entry_text

	    while { [regexp -linestop {mol (new|addfile) (.*)psf} $leftToCheck psfline] } {
		regexp -linestop -indices {mol (new|addfile) (.*)psf} $leftToCheck ends
		if { [string first "webpsf" $psfline] != -1 } {
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    continue
		}

		if { [regexp {http} $psfline psfline2] } {
		    
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    
		    
		    regsub -all {\?} $entry_text "questionmark" entry_text
		    regsub -all {\?} $psfline "questionmark" psfline
		    regsub -all "&" $entry_text "ampersand" entry_text
		    regsub -all "&" $psfline "ampersand" psfline
		    
		    set url $psfline
		    regsub "mol (new|addfile) " $url "" url
		    regsub " type psf" $url "" url
		    set encodedURL $url
		    regsub -all "questionmark" $url {?} url

		    regsub -all "ampersand" $url {\&} url
		    regsub -all "\{" $url "" url
		    regsub -all "\}" $url "" url

		    lappend biofs_psf_file $url
		    set url [string trim $url]

		    if { [string first "mol addfile" $psfline] != -1 } {
			set tmpfile [file join $tmpdir tmpfile[clock seconds].psf]
			set j 0
			while { [file exists $tmpfile] } {
			    set tmpfile [file join $tmpdir tmpfile[clock seconds][incr j].psf]
			}
			#biocorehttpcopy $url $tmpfile [biocore_handle cget Session]
			biocorehttpcopy $url $tmpfile $::biocore::Session

			regsub -all $encodedURL $entry_text $tmpfile entry_text

		    } else {

			set tmpfile [file join $tmpdir tmpfile[clock seconds].psf]
			set j 0
			while { [file exists $tmpfile] } {
			    set tmpfile [file join $tmpdir tmpfile[clock seconds][incr j].psf]
			}
		    
			#biocorehttpcopy $url $tmpfile [biocore_handle cget Session]
			biocorehttpcopy $url $tmpfile $::biocore::Session
			regsub -all $encodedURL $entry_text $tmpfile entry_text
			lappend biofs_file $url
		    }
		    
		    regsub -all "mol new" $psfline "mol urlload psf" newpsfline
		    
		    regsub -all " type psf" $newpsfline "" newpsfline
		    regsub -all $psfline $entry_text $newpsfline entry_text
		    regsub -all "questionmark" $entry_text {?} entry_text
		    regsub -all "ampersand" $entry_text {\&} entry_text
		    
		    
		} else {
		    set ends [split $ends]
		    set start [lindex $ends 0]
		    set end [lindex $ends 1]
		    set leftToCheck [string range $leftToCheck $end end]
		    continue
		}
	    }

	    #regsub -all "mol new" $entry_text "mol urlload pdb" entry_text
	    #regsub -all "type pdb" $entry_text "" entry_text
	    regsub -all "type psf" $entry_text "" entry_text
	    
	    # convert dcd files    
	    set dcdfile [file join $tmpdir tempDCD[clock seconds].dcd]
	    set j 0
	    while { [file exists $dcdfile] } {
		set dcdfile [file join $tmpdir tempDCD[clock seconds][incr j].dcd]
	    }
	    if { [regexp -linestop {mol (new|addfile) (.*)dcd} $entry_text url] } {
		
		set downloadDCD_frame [toplevel .downloadDCD_frame]
		set answer [tk_dialog $downloadDCD_frame "Warning!" "This saved state involves downloading a DCD file. DCD files are typically very large, and downloading it may take some time. Do you wish to proceed?" "" 1 "Yes" "No"]
		if { $answer != 0 } {
		    #puts "biocorepubsync) State not loaded"
		    set m_loading 0
		    catch {
		    wm title .w $m_window_title
		    }
		    return
		}
		set index [string first "http" $url]
		set url [string range $url $index end]
		regsub " type dcd" $url "" url
		set url [string trim $url]
		lappend biofs_dcd_file $url
		# vmdhttpcopy found in VMD's biocore.tcl
		#vmdhttpcopy $url $dcdfile

		biocorehttpcopy $url $dcdfile $::biocore::Session

		regsub -all -linestop {mol (new|addfile) (.*)dcd} $entry_text "animate read dcd $dcdfile" entry_text
	    }

	#regsub -all "waitfor all" $entry_text "" entry_text
    
	# Labels
	catch {
	    set i [incr topMolId]
	    set foundList ""
	    set foundLabel ""
	    set foundList [regexp -all -linestop -inline {label add Atoms.*|label add Bonds.*|label add Angles.*|label add Dihedrals.*} $entry_text]
	    set replList ""

	    set oldIndexList ""
	    set newIndexList ""
	    foreach found $foundList {
		set repl $found
		#regexp -linestop {label add Atoms [\d]*|label add Bonds [\d]*|label add Angles [\d]*|label add Dihedrals [\d]*} $found start
		
		set currList [regexp -all -inline { [\d]+/} $found]
		set currIndexList [regexp -all -inline -indices { [\d]+/} $found]
		foreach molId $currList molIndex $currIndexList {
		    if { [lsearch $oldIndexList $molId] == -1 } {
			lappend oldIndexList $molId
			lappend newIndexList $i
			regsub -start [expr {[lindex $molIndex 0] - 1}] $molId $repl " $i/" repl
			incr i
		    } else {
			set newIndex [lindex $newIndexList [lsearch $oldIndexList $molId]]
			
			regsub -start [expr {[lindex $molIndex 0] - 1}] $molId $repl " $newIndex/" repl
		    }
		}
		lappend replList $repl
	    }
	    
	    foreach i $foundList j $replList {
		regsub $i $entry_text $j entry_text
	    }
	} foo
    
	# The command, "eval entry_text" won't work
	# since eval behaves like source, and doesn't execute commands
	# in sequence. So we write the output to a file,
	# and play that file, so commands are executed in sequence
	# and orientation is displayed correctly, etc
	#puts "entry text = $entry_text"
    
	#eval $entry_text
	set tmpfilename [file join $tmpdir tmpfile[pid]]
    
    file delete $tmpfilename
    
	set tmpfile [open $tmpfilename a+]
	#regsub -all " top " $entry_text " \[molinfo top\] " entry_text

	puts $tmpfile $entry_text
	close $tmpfile
	#play $tmpfilename
	#file delete $tmpfile
    
	if { [catch {

	    playLines $tmpfilename

	} foo2] } {
	    set ok [tk_dialog .loadErrorWindow "Error in loading state" "There has been an error\nin loading the state. The state may have been saved with an older\nversion of VMD, or there may be another problem\nwith the code.\nThe resulting state may not be displayed correctly.\n\nError: $foo2" "" 0 "Okay"]
	}
	# delete the files, but
	# "play" may not be done reading in dcd files, so
	# put it within a "catch"
	catch {
	    foreach dfile $fileList {
		#file delete $dfile
		#puts "biocorepubsync) deleted file $dfile"
	    }
	}
	#file delete $tmpfilename
	set m_loading 0
    
    } foo
    if { [string match $foo "couldn't open socket: host is unreachable"] } {
	set m_loading 0
	puts "biocorepubsync) Couldn't open socket: $foo"
	new_error_window

	return
    }
    catch {
    wm title .w $m_window_title
    } 

} foo3
    set m_loading 0
    #puts "biocorepubsync) Total error in synch: $foo3"

}; # end biocore_synchronize

###################
# 
# biocore_publish
#
# saves a VMD state to the Notebook
# 
# parameters:
#   name: The name given to the state to be saved
#   desc: a description of the state to be saved
#   save: 1 if you want to save to the Notebook, 0 if not (such as when 
#         publishing a temporary save file)

proc ::BiocorePubSync::biocore_publish { name desc save } {

    variable m_adding

    variable version
    variable biofs_pdb_file
    variable biofs_psf_file
    variable biofs_dcd_file
    variable biofs_file
    global env
    variable m_snapshot
    variable tmpdir
	variable biocore_handle

    variable m_window_title
    variable tmp_save

    set foo ""
    set os [vmdinfo arch]
    regexp WIN32 $os foo

    if {[catch {
	if { $m_adding } {
	    return 0
	}
    set m_adding 1
	if { $save } {
	    wm title .w "Saving state..."
	}
    set name [string trim $name]
    set desc [string trim $desc]

	if { $save } {
    if { [string match $name ""] } {
	set m_adding 0
	set ok [tk_dialog .noName "No name given" "You must enter a name for the state. No state has been saved." "" 0 "Okay"]
	return 0;
	#set name "No name given"
    }
    if { [string match $desc ""]} {
	set m_adding 0
	set ok [tk_dialog .noDesc "No description given" "You must enter a description for the state. No state has been saved." "" 0 "Okay"]
	return 0;
	#set desc "No description given"
    }
	}

    # save the information 
    # XXX Eliminate the need for a temporary file
    #     We could probably modify save_state in save_state.tcl to do this
    ::biocore::NotebookEntry ne

    #set vmdVersion "\# VMD version: [vmdinfo version]\n\n"
    #set psVersion "\# Pub/synch version: $version\n\n"
    #set date "\# Description: Published on: [clock format [clock seconds]]\n\n"

    regsub -all "\n" $desc "\n\# Description: " desc

    #set dtext "$vmdVersion$psVersion$date\# Description: $desc"

    set dtext "\# Description: $desc"

    # create a new unique filename
	#set filename [file join $tmpdir vmdtmp[biocore_handle cget Session]]
	set filename [file join $tmpdir vmdtmp$::biocore::Session]
    save_state $filename
    set tmp_file [open $filename]
    set tmptext [read $tmp_file]
    close $tmp_file
    file delete $filename

    set text ""
    # save snapshot
    set image ""

	if { $save && $m_snapshot } {
      #tk_messageBox -type ok -message "Snapshot saving temporarily disabled.  State will be saved without."
      wm title .w "Saving snapshot..."

	   regsub -all {/} $name {} snapFileName
	   regsub -all {\\} $snapFileName {} snapFileName
      ::BiocorePubSync::save_snapshot $snapFileName

      #puts "picture path is '$picturePath'"
      if { [string match $foo WIN32] } {
         set picturePath  [file join $tmpdir $snapFileName].bmp
      } else {
         set picturePath  [file join $tmpdir $snapFileName].jpg
      }
      #puts "picture path is '$picturePath'"

      if { $picturePath != "" } {

         set ind [string last "/" $picturePath]
         incr ind
         set XXXX [string range $picturePath $ind end]

         set image "\# Image:<BR><A HREF=\"<<<notebookAttach $XXXX>>>\"><IMG SRC=\"<<<notebookAttach $XXXX>>>\" height=100 width=100></IMG></A>"
         ::biocore::ne configure FileUploadName "$picturePath"
      } else {
         tk_messageBox -type ok -message "Didn't get path for saved snapshot"
         return 0
      }


#puts "saving snapshot..."
#gets stdin
#	    if { [catch {
#	    wm title .w "Saving snapshot..."
#puts "name = $name"
#gets stdin
#       set picturePath [ ::BiocorePubSync::save_snapshot $name ]
#	    catch { 
#          save_snapshot $name
#	    } foo
#puts "before call to set save_snapshot"
#	    set picturePath [ ::BiocorePubSync::save_snapshot $name ]
#puts "after call to save_snapshot"
#puts "Error in save_snapshot: $foo"
#puts "picturePath = $picturePath"
#gets stdin
#	    if { $picturePath != "" } {
		
#		set picURL [append $::biocore::URL biofs/$picturePath]
#puts "picURL = $picURL"
#		regsub -all " " $picURL "%20" picURL
#		regsub -all "<" $picURL "%3C" picURL
#		regsub -all ">" $picURL "%3E" picURL
#		regsub -all "\"" $picURL "%22" picURL

#		set image "\# Image:<BR><A HREF=\"/biocore/$picURL\"><IMG SRC=/biocore/$picURL height=100 width=100></IMG></A>"
#	    } 
#	    } foo ]} { 
#		puts "Could not save snapshot: $foo"
#	    }
	} else {
	}

	append apiVersions "\n\# biocore api version: [package versions biocore]"
	append apiVersions "\n\# biocorelogin version: [package versions biocorelogin]"
	append apiVersions "\n\# biocorepubsync version: [package versions biocorepubsync]\n\n"

	append text $image "\n\n" $dtext "\n\# Description:\n\n" $apiVersions $tmptext
	if { $save } {
	    wm title .w "Saving state..."
	}

	# if we opened this file in Windows, it is loaded as a local file.
	# When publishing, we must publish the biofs file names, stored in
	# the variable, "biofs_file".
	# biofs_file is a list of the current molecule urls

	# It gets a bit screwy here. In "regsub",
	# if there is an "&" in the substituted string ($biofs_file here),
	# then all the "&"'s get replaced with the found string 
	# ("C:/Temp...pdb", here).
	# So regsub the "&"'s with "ampersand" in biofs_file first,
	# then substitute,
	# then regsub the "ampersand"'s back to "&"'s

	# change pdbs
set fileSeparator [file separator]
set space " "

append pdbRegexp ($space|\{) $tmpdir $fileSeparator tmp(.)*.pdb ($space|\})
regsub -all "\\\\" $pdbRegexp "(\\\\\\\\|/)" pdbRegexp
	if  { [regexp -linestop $pdbRegexp $text file] } {
	    set i 0
	    regsub -all & $biofs_pdb_file ampersand biofs_pdb_file
	    while { [regexp -linestop $pdbRegexp $text file] } {
		regsub -all $file $text $space[lindex $biofs_pdb_file $i]$space text
		incr i
	    }
	    regsub -all ampersand $text {\&} text
	}

append psfRegexp ($space|\{) $tmpdir $fileSeparator tmp(.)*.psf ($space|\})
regsub -all "\\\\" $psfRegexp "(\\\\\\\\|/)" psfRegexp
	# change pdfs
	if  { [regexp -linestop $psfRegexp $text file] } {
	    set i 0
	    regsub -all & $biofs_psf_file ampersand biofs_psf_file
	    while { [regexp -linestop $psfRegexp $text file] } {

		regsub -all $file $text $space[lindex $biofs_psf_file $i]$space text
		incr i
	    }
	    regsub -all ampersand $text {\&} text
	}
append dcdRegexp ($space|\{) $tmpdir $fileSeparator tempDCD(.)*.dcd ($space|\})
regsub -all "\\\\" $dcdRegexp "(\\\\\\\\|/)" dcdRegexp	
	# change dcds
	if  { [regexp -linestop $dcdRegexp $text file] } {
	    set i 0
	    regsub -all & $biofs_dcd_file ampersand biofs_dcd_file
	    while { [regexp -linestop $dcdRegexp $text file] } {
		regsub -all $file $text $space[lindex $biofs_dcd_file $i]$space text
		incr i
	    }
	    regsub -all ampersand $text {\&} text
	}

	set space " "
	# in VMD versions 1.8+, mol urlload writes a temporary file
	# on the user's system and reads it from there. We have to 
	# replace the "/tmp/urlload" with the file url
	if { [regexp /tmp/urlload $text ]} {
	    set i 0
	    regsub -all & $biofs_file ampersand biofs_file
	    while { [regexp ($space|\{)/tmp/urlload($space|\}) $text result]} {
		regsub $result $text $space[lindex $biofs_file $i]$space text


		incr i

	    }
	    regsub -all ampersand $text {\&} text
	}
append dcdtmp $tmpdir $fileSeparator tmpDCD(.)*.dcd (\}|$space)
regsub -all "\\\\" $dcdtmp "\\\\\\\\" dcdtmp
	# replace /tmp file with DCD url for publishing
	if { [regexp -linestop $dcdtmp $text file] } {
	    set i 0
	    regsub -all & $biofs_dcd_file ampersand biofs_dcd_file
	    while { [regexp -linestop $dcdtmp $text file]} {
		#set file [string range $file 0 [expr {[string length $file] - 2} ] ]

		regsub -all $file $text $space[lindex $biofs_dcd_file $i]$space text
		incr i
	    }
	    regsub -all ampersand $text {\&} text
	}	    

    # replace the pdbs from the biofs to the user's system, and update
    # the saved state script accordingly.
#puts "text = $text"
    if { $save != 0 } {

	set text [upload_local $text "pdb"]
	
	set text [upload_local $text "psf"]
	
	set text [upload_local $text "dcd"]


	if { [string match "-1" $text] } {
	    #puts "biocorepubsync) State not saved"
	    return 0;
	}
    }


    # get rid of jsessionid in text
    if {  [regexp -linestop {jsessionid=([\-]?)([0-9, A-F]+)} $text session] } {
	regsub -all $session $text "jsessionid=0 " text
    }

    ::biocore::ne configure Type 2
    ::biocore::ne configure Reply 0
    ::biocore::ne configure Title $name
    ::biocore::ne configure Text $text
    ::biocore::ne configure Description $desc

    # save the entry in API
    if { $save } {
	#set i [biocore_handle saveNotebookEntry ne]
   #puts "getting ready to save the entry"
	set i [::biocore::saveNotebookEntry ::biocore::ne]
   #puts "done saving the entry"
    }
	
    file delete $tmp_save
    set tmpSaveFile [open $tmp_save a+]
    puts $tmpSaveFile $text
    close $tmpSaveFile
    
    #after idle destroy .pub_frame

    if { $save } {
	#add_latest_entry -1
    } else {
	set m_adding 0
    }
} foo]} {
	
	if { [string match "couldn't open socket" $foo] != -1 } {
	    set m_adding 0
	    wm title .w $m_window_title
       puts "biocorepubsync) Publish: Couldn't open socket: '$foo'"
	    new_error_window
	    return 0
	}
}
wm title .w $m_window_title

set m_adding 0
return 1
}; # end biocore_publish


###################
# 
# get_description
#
# gets the description from the message of a saved VMD state
# 
# parameters:
#  state: the id of the Notebook message from which to get the description
#

proc ::BiocorePubSync::get_description { state } {
    
    variable file_list
    #if { [llength $file_list] == 0 } {
#	return "There are no saved sessions for this project."
#    }

    set final_desc ""
    set desc ""
    #set entry [biocore_handle getNotebookEntry $state]
    set entry [::biocore::getNotebookEntry $state]

    for { set j 0 } { $j < [llength $entry] } { incr j } {
	if { [string match "Text" [lindex $entry $j]] } {
	    set text [lindex $entry [incr j]]
	}
	if { [string match "User" [lindex $entry $j]] } {
	    set user [lindex $entry [incr j]]
	}
    }
    if { [regexp {(\# Description:(.)*\# Description:\n\n)} $text desc ] } {
	regsub -all {\n\# Description:\n\n} $desc {} desc
	regsub -all {\n\# Description: } $desc "\n" desc
	regsub -all {\# Description: } $desc {} final_desc

	#set final_desc  "Published by: $user\n\n$final_desc"
    } else {
	set final_desc "No description"
    }
    
    
    return $final_desc
}


###################
#
# load_from_biofs_window
#
# displays the window that allows users to select a pdb file from the biofs
#  to show in VMD
#
# parameters: none
#

proc ::BiocorePubSync::load_from_biofs_window { } {
    variable tmp_save
    
    variable load_scroll
    variable files_list
    variable load_frame
    variable path

    ::biocore::BiofsDirectory bioDir

    if {[catch {

	set load_frame [toplevel .load_frame]
	set top_frame [frame $load_frame.top_frame]
	
	wm title .load_frame "Load a file from the BioFS"
	
	set load_scroll [scrollbar $top_frame.load_scroll \
			     -command {$::BiocorePubSync::files_list yview}]
	
	set loadInto 0
	set loadInto_frame [frame $load_frame.loadInto_frame]
	set loadIntoText "Load this file into\nthe top molecule"
	set loadInto_check [checkbutton $loadInto_frame.loadInto_check -variable loadInto]
	set loadInto_label [label $loadInto_frame.loadInto_label -text $loadIntoText]
	
	set path ""
	#append path "/" [biocore_handle getProjectName [biocore_handle cget Project]] "/"
	#set bioDir [biocore_handle getBiofsDirectory $path 0 ""]
	if { $::biocore::Project == -1 } {
	    set projList [::biocore::getProjectList]
	    set ::biocore::Project [lindex $projList 1]
	}
	append path "/" [::biocore::getProjectName $::biocore::Project] "/"
	set ::biocore::bioDir [::biocore::getBiofsDirectory $path 0 ""]

	set files_list [listbox $top_frame.files_list -height 5 -width 25 \
			    -selectmode single -exportselection false \
			    -yscrollcommand {$load_scroll set} ]

	$files_list configure -yscrollcommand "$load_scroll set"
	$load_scroll configure -command "$files_list yview"
	
	bind $files_list <Double-Button-1> {
		       set name [$::BiocorePubSync::files_list get [$::BiocorePubSync::files_list curselection]]; \
		       if {![string match $name \
			"There are no pdb files in this project."] } {
			   # get extension so we know what type of file to load
			   set id $::BiocorePubSync::file_indx($name)
			   set length [string length $name]
			   set extStart [expr {$length - 3 }]
			   set ext [string range $name $extStart end]
			   #save_state $tmp_save
			   ::BiocorePubSync::biocore_publish "" "" 0
			   #::BiocorePubSync::load_url [::BiocorePubSync::biocore_handle cget URL] $name $ext $loadInto
			   ::BiocorePubSync::load_url $::biocore::URL $name $ext $loadInto
			   mol rename top $name
			   
		       }; \
		   after idle destroy $::BiocorePubSync::load_frame 
		   }
	
	# set up listbox with names of pdb files in this project
	
	#get_files bioDir $files_list "pdb" ""
	#set bioDir [biocore_handle getBiofsDirectory $path 0]
	#get_files bioDir $files_list "psf" ""
	#set bioDir [biocore_handle getBiofsDirectory $path 0]
	#get_files bioDir $files_list "dcd" ""
	#set bioDir [biocore_handle getBiofsDirectory $path 0 ""]
	#puts "biodir = $::biocore::bioDir"
	get_files $::biocore::bioDir $files_list "pdb psf dcd" ""

	if { [$files_list size] == 0 } {
	    $files_list insert end "There are no pdb files in this project."
	}
	
	set load_button [button $top_frame.load_button -text "Load" \
		-command {\
		 if { ![catch [$::BiocorePubSync::files_list curselection]]} { \
			puts "biocorepubsync) Please select an item from the list" 
		 } \
		   else {
		       set name [$::BiocorePubSync::files_list get [$::BiocorePubSync::files_list curselection]]; \
		       if {![string match $name \
			"There are no pdb files in this project."] } {
			   # get extension so we know what type of file to load
			   set id $::BiocorePubSync::file_indx($name)
			   set length [string length $name]
			   set extStart [expr {$length - 3 }]
			   set ext [string range $name $extStart end]
			   #save_state $tmp_save
			   ::BiocorePubSync::biocore_publish "" "" 0
			   #::BiocorePubSync::load_url [::BiocorePubSync::biocore_handle cget URL] $name $ext $loadInto
			   ::BiocorePubSync::load_url $::biocore::URL $name $ext $loadInto
			   mol rename top $name
			   
		       }; \
		   after idle destroy $::BiocorePubSync::load_frame 
		   }
		}
			]
	
	set cancel_button [button $top_frame.cancel_biofs -text "Cancel" \
			       -command { after idle destroy $::BiocorePubSync::load_frame }]
	pack $top_frame -side top -fill both -expand 1
	pack $cancel_button -side bottom
	pack $load_button -side bottom
	pack $files_list -side left -fill both -expand 1
	pack $load_scroll -side right -fill y
	pack $loadInto_frame -side bottom
	pack $loadInto_check -side left -anchor w
	pack $loadInto_label -side left -anchor w
	
    } biofs_error] } {
	if { [string match "couldn't open socket" $biofs_error] != -1 } {
	    puts "biocorepubsync) Error: $biofs_error"
	    new_error_window
	    destroy $load_frame
	    return
	}
    }
    #puts "Error in load: $load_already_open"
} ; # end load_from_biofs_window


###################
#
# load_users_most_recent
#
# Loads the most recent state published by a user
#
# parameters:
#  userId: Id of the user of which to get the last published state
#          If it is -1, get the most recent state published by anyone

proc ::BiocorePubSync::load_users_most_recent { userId } {
    #set entry_info_list [biocore_handle getNotebookEntryListByUser 2 0 0 $userId]
    set entry_info_list [ ::biocore::getNotebookEntryListByUser 2 0 0 $userId ]

    set lastMsg [lindex $entry_info_list end]
    set idIndex 0
    for { set j 0 } { $j < [llength $lastMsg] } { incr j } {
	if { [string match [lindex $lastMsg $j] "Id"] } {
	    set idIndex [incr j]
	}
    }
    set lastId [lindex $lastMsg $idIndex]
    if { [info exists $lastId ] } {
    after idle ::BiocorePubSync::biocore_synchronize $lastId 0
    }
    
}


###################
# 
# playLines
#
# helper function to load a script one line at a time
#
# parameters:
#  sourceFile: name of the script file to load
#
proc ::BiocorePubSync::playLines { sourceFile } {
    
    set i 0
    set dontShow 0
    set tmpfile [open $sourceFile]
    set tmptext [read $tmpfile]
    close $tmpfile

    set lines [split $tmptext "\n"]

    set currLine 0

    set numLines [llength $lines]
    for { set playLinesi 0 } { $playLinesi < $numLines } { incr playLinesi } {
	set currLine [lindex $lines $playLinesi]
	if { [string first "\{" $currLine] > -1 } {
	    set numOpen [regsub -all "\{" $currLine "" foo]
	    set numClose [regsub -all "\}" $currLine "" foo]
	    while { $numOpen > $numClose } {
		incr playLinesi
		set nextLine [lindex $lines $playLinesi]
		if { [string first "\{" $nextLine] > -1 } {
		    set numOpenInLine [regsub -all "\{" $nextLine "" foo]
		    set numOpen [expr { $numOpen + $numOpenInLine } ]
		}
		if { [string first "\}" $nextLine] > -1 } {
		    set numCloseInLine [regsub -all "\}" $nextLine "" foo]
		    set numClose [expr { $numClose + $numCloseInLine } ]
		}
		append currLine "\n" $nextLine
	    
	    }
	}

# FOOBAR:
# When you load a molecule, it may contain unique color information for
# data specific to that molecule, such as "color Resname {ACE} silver".
# If you delete that molecule, and load a new one, that color data remains 
# and is displayed in the vmdrestoremycolors proc when you save_state. 
# Since the original molecule is no longer there, vmdrestoremycolors gives a 
# "Unable to change color name" error.

	#puts "currLine $i = $currLine"
#	if { [string first "type webpdb" $currLine] != -1 } {
#	    eval $currLine
#	} else {
#	    after idle $currLine
#	}
#	#puts "done with line $i"
#	incr i

	if { [catch {
	    eval $currLine
	    #puts "line $playLinesi = $currLine"
	} foo2] } {
	    if { !$dontShow } {
		#puts "currLine = $currLine"
		#set clip [string first "mol clipplane" $currLine]
		#puts "'mol clipplane' exists in currLine: $clip"
		#puts "current line is <<<<<<<<<<<<$currLine>>>>>>>>>>>>>>>>>>>>"
		if { [string first "Invalid molid specified:top" $foo2] != -1} {
		    regsub " top " $currLine " [molinfo top] " currLine

		    eval $currLine
		} else {

		    set ok [tk_dialog .loadErrorWindow "Error in loading state" "There has been an error\nin loading the state. The state may have been saved with an older\nversion of VMD, or there may be another problem\nwith the code.\nThe resulting state may not be displayed correctly.\n\nError: $foo2" "" 0 "Okay" "Skip error messages"]
		    if { $ok == 1 } {
			set dontShow 1
		    }
		}
	    }
	}
    }
}



###################
#
# load_url
#
# loads a molecule
#
# parameters:
#  base: the base for the url (http://.../)
#  path: the Biofs path for the Biofs file to be loaded
#  type: type of file to load (pdb, psf, dcd)
#  loadInto: If 0, regulary load the molecule. If 1, load the new molecule
#            into the top molecule
#
proc ::BiocorePubSync::load_url { base path type loadInto} {

    variable tmpdir

    set fid [clock seconds]
    set file [file join $tmpdir tempDCD$fid.dcd]
    while { [file exists $file] > 0 } {
	set id [clock seconds]
	set file [file join $tmpdir tempDCD$fid.dcd]
    }

    variable biocore_handle
    global env
    variable biofs_file
    variable biofs_pdb_file
    variable biofs_psf_file
    variable biofs_dcd_file

    if { [molinfo num] == 0 } {
	set biofs_file ""
	set biofs_pdb_file ""
	set biofs_psf_file ""
    }

    append url $base "biofs$path"
    
    regsub -all " " $url "%20" url

    # set the original BioFS file name for the file, so we can use it
    # if we're publishing.
    # Append it to the end of biofs_file for a list of current molecules
    if { !$loadInto } {
	lappend biofs_file $url
    }
    if { [string match $type "psf"] } {
	lappend biofs_psf_file $url
    } elseif { [string match $type "pdb"] } {
	lappend biofs_pdb_file $url
    }
    
    set foo ""
    set os [vmdinfo arch]
    regexp WIN32 $os foo
    
    if { [string match $type "dcd"] } {
	
	lappend biofs_dcd_file $url

	set tmpdirect [file join $tmpdir tempDCD$fid.dcd]
	if { [string match $foo WIN32] } {
	    set tmpdirect [file join $tmpdir tempDCD$fid.dcd]
	}

	#vmdhttpcopy $url $tmpdirect
	biocorehttpcopy $url $tmpdirect $::biocore::Session

	animate read dcd $tmpdirect
    } else {

	# It is Windows, so download a temporary file and load it from
	# there.	   

	set file [file join $tmpdir tmp$fid.$type]
	
	# vmdhttpcopy found in VMD's biocore.tcl
	#vmdhttpcopy $url $file
	biocorehttpcopy $url $file $::biocore::Session
	
	if { $loadInto } {
	    mol addfile $file type $type
	} else {
	    mol load $type $file
	}

    }

    file delete [file join $tmpdir tmp$fid.type]
    after idle file delete [file join $tmpdir tmpDCD$fid.dcd]

} ; # end load_url


###################
#
# get_files
#
# gets all the pdb files from a project and adds them to the listbox
#
# parameters:
#  directory: either a biofsDirectory object or a list representation of one
#  file_list: the listbox to add the file names to
#  suffixes: list of suffixes to look for (i.e. "pdb psf dcd")
#  prefix: path to file
#

proc ::BiocorePubSync::get_files { directory file_list suffixes prefix } {

    #variable biocore_handle
    set entries ""
    set name ""
    set id ""
    variable file_indx
    # get the entries
    # if this is a list, find the "Entries" element...
    for { set k 0 } {$k < [llength $directory] } {incr k } {
	if {[string match "Entries" [lindex $directory $k]]} {
	    set entries [lindex $directory [incr k]]
	}
    }

    # ...else, this is an API object, and get the element with "cget"
    if { [string match $entries ""] } {
	set entries [$directory cget "Entries"]
    }

    append search {[.]*\.} "("
    #set search [lappend {[.]*\.} $suffix]
    foreach suffix $suffixes {
	append search "$suffix|"
    }
    set index [string last "|" $search]
    incr index -1
    set search [string range $search 0 $index]

    append search ")"
    for {set i 0} { $i < [llength $entries]} {incr i} {
	set curr [lindex $entries $i]

	set isDir 0
	set isParent 0
	
	set name ""
	set id ""
	set directory ""
	set path ""

	for { set j 0 } { $j < [llength $curr] } { incr j } {
	    if {[string match "Name" [lindex $curr $j]]} {
		set name [lindex $curr [incr j]]
	    }
	    if {[string match "Id" [lindex $curr $j]]} {
		set id [lindex $curr [incr j]]
	    }
	    if {[string match "Type" [lindex $curr $j]]} {

		if {[lindex $curr [incr j]] == 0 } {
		    set isDir 1;
		}
	    }
	    if {[string match "Parent" [lindex $curr $j]]} {
		set isParent [lindex $curr [incr j]]
	    }
	    if {[string match "Path" [lindex $curr $j]]} {
		set path [lindex $curr [incr j]]
	    }
	}

	# if this is a directory, search subdirectories
	if { $isDir == 1 } {
	    # don't search .ServerFiles directory
	    if { ![string match ".ServerFiles" $name] } {
		# don't search Parent directory
		if { $isParent != 1 } {
		    #set dir [biocore_handle getBiofsDirectory $path 0 ""]
		    set dir [::biocore::getBiofsDirectory $path 0 ""]
		    get_files $dir $file_list $suffixes $path
		}
	    }
	} elseif { [regexp $search $name] } {
	    set file_indx($path) $path
	    #$file_list insert end "$prefix/$name"
	    $file_list insert end "$path"
	}
    }
} ; # end get_files


#################
#
# save_snapshot
#
# Creates a snapshot of the vmd state 
#
# parameters:
#  filename: name of the file to save
#
# returns:
#  path to the local file
#
proc ::BiocorePubSync::save_snapshot { filename } {
   variable tmpdir

   if [catch {
      # suffix for temporary file on user's machine
      set tmp_suffix "rgb"
      set picname $filename

      # suffix for file in biofs
      set suffix "jpg"

      set file  [file join $tmpdir $filename]
      set homefile $file

      set foo ""
      set os [vmdinfo arch]
      regexp WIN32 $os foo
      if { [string match $foo WIN32] } {
          set tmp_suffix "bmp"
          set newPicname $picname

          render snapshot $homefile.$tmp_suffix

          return $homefile.$tmp_suffix
      } else {

         # using SGI's 'snapshot' program
         render snapshot $homefile.$tmp_suffix

         # using SGI's 'convert' program
         exec convert $homefile.$tmp_suffix $homefile.$suffix
         file delete $homefile.$tmp_suffix

         #puts "ready to return $homefile.$suffix"
         return 0
#         return "$homefile.$suffix"
      }

   } snapshotError] {
      tk_messageBox -type ok -message "Unable to render and convert \n
snapshot:  $snapshotError"
   }

} 
# end of save_snapshot 


#################
#
# gets the id for the vmd directory in the .ServerFiles directory
# this is where vmd snapshots will be stored
#
# parameters: none
#
# returns: path of the vmd directory for the current project
#
proc ::BiocorePubSync::get_vmd_path {} {

    variable biocore_handle

    #set projectName [biocore_handle getProjectName [biocore_handle cget Project]]
	if { $::biocore::Project == -1 } {
	    set projList [::biocore::getProjectList]
	    set ::biocore::Project [lindex $projList 1]
	}
    set projectName [::biocore::getProjectName $::biocore::Project]
    set path  "/$projectName/.ServerFiles/vmd/"
    return $path
}

#################
#
# find_file
#
# finds a file or directory in a given directory
# 
# parameters:
#  directoryId: id of the directory to search
#  filename: name of the file or directory to find
#  
# return:
#  path of the file in the directory or -1 if the file is not found
#

#proc ::BiocorePubSync::find_file { directoryPath filename } {
#    # get id of .ServerFiles directory for this project
#    #set dir [biocore_handle getBiofsDirectory $directoryPath 0]
#    set fsparams(type) "biofs"
#    # FOOBAR: findDirectory and findFile eventually...
#    set fsparams(task) "findFile"
#
#    set params [toXML "findFile" "path {$directoryPath} findName {$filename} projectId [biocore_handle cget Project]"]
#
#    set fsparams(parameters) $params
#
#   set strResponse [encodeAndSend get [biocore_handle cget URL] [biocore_handle cget Session] [biocore_handle cget Project] fsparams]
#    set strResponse [string trim $strResponse]
#    if { [ isValidBiocoreResponse $strResponse listResult iServerVersion ] } {
#	return $listResult
#    } else {
#	#puts "Error: listResult=$listResult"
#	return -1
#    }
#}


######################
#
# convert
#
# converts the file from one form to another
# and puts the new file in the BioFs
#
# Parameters:
#  filename the base name of the file
#  directoryPath: the BioFS path of the directory to put this file into
#  convertFrom: suffix that this file currently has (.bmp, .rgb, etc)
#  convertTo: suffix for new file to have (.jpg, etc)
#
# return:
#  the id of the newly created file

#proc ::BiocorePubSync::convert { filename directoryPath convertFrom convertTo } {
#    set iId -1
#    
#    # strLocal is the local filename
#    set strLocal $filename.$convertFrom
#
#    # load the file into   $binData   ....
#    set fid [open $strLocal r]
#    fconfigure $fid -translation binary
#    if {[catch {read $fid [file size $strLocal]} binData]} {
#	return -code error $binData
#    }
#    close $fid
#    
#    set sourcePath [file join $tmpdir $strLocal]
#    set destPath [file join $tmpdir $filename.$convertTo]
#
#    set params(type) "utilities"
#    set params(task) "convert"
#    set parameters "sourcePath {$sourcePath} filename {$destPath} from $convertFrom to $convertTo"
#    set params(parameters) [toXML "convert" $parameters]
#
#    set convertResponse [encodeAndSend get [biocore_handle cget URL] [biocore_handle cget Session] [biocore_handle cget Project] params]
#
#    set strPath "";
#    if { [ isValidBiocoreResponse $convertResponse listResult1 iServerVersion ] } {
#	set strPath [biocore_handle putBiofsFileSystem "$destPath" "$directoryPath" $filename.$convertTo]
#
#    } else {
#	error "Could not convert file $sourcePath to file $destPath and upload to directory $directoryPath"
#    }
#
#    return $strPath
#
#}

################################
#
# upload_local
#
# uploads a local file from the user's system 
# to the BioFS when publishing
#
# parameters:
#  tmptext: saved state text to check for substituting new file URL
#  suffix: suffix (such as pdb, psf, dcd) to check for
#
proc ::BiocorePubSync::upload_local { tmptext suffix } {
    catch {
    variable biofs_pdb_file
    variable biofs_pdf_file
    variable biofs_dcd_file
	
	variable newfilename
    set newfilename ""
    set space " "
    set leftToCheck $tmptext
    set ends ""
    set start 0
    set end 0
    # find the file name
    set i 0

    while { [regexp -linestop "mol (new|addfile)(.)*$suffix" $leftToCheck molfile] } { 
	regexp -linestop -indices "mol (new|addfile)(.)*$suffix" $leftToCheck ends
	set ends [split $ends]
	set start [lindex $ends 0]
	set end [lindex $ends 1]
	set leftToCheck [string range $leftToCheck $end end]
	regsub "type $suffix" $molfile "" molfile
	regsub "mol new " $molfile "" molfile
	regsub "mol addfile " $molfile "" molfile
	regsub "\{" $molfile "" molfile
	regsub "\}" $molfile "" molfile

	#set listName [append a "biofs_" $suffix "_file"]
	
	switch suffix {
	    pdb {
		set listName $biofs_pdb_file
	    }
	    pdf {
		set listName $biofs_psf_file
	    }
	    dcd {
		set listName $biofs_dcd_file
	    }
	    default {
		set listName $biofs_pdb_file
	    }
	}
	set newfile [lindex $listName $i]
	if { [string match $newfile ""]} {
	    set newfile $molfile
	}

	incr i

	set newfile [string trim $newfile]
	#puts "newfile = $newfile"
	set newfilename [string range $newfile [ expr { [string last "/" $newfile] + 1 } ] end ]
	#puts "newfilename = $newfilename"
	#puts "molfile = $molfile"

	if { [regexp "http" $molfile httpTest] || [regexp "type webpdb" $molfile httpTest2] } {
	} elseif { [set found [lsearch $listName $newfile]] != -1 } {
	    regsub -all $newfile $tmptext [lindex $listName $found] tmptext
	} else {
	    set local_frame [toplevel .local_frame]
	    set answer [tk_dialog $local_frame "Warning!" "The file $newfile has not been identified as a public file. It may be a local file, meaning other people in your project will not be able to load this session. Do you wish to save the file to the BioFS and continue?" "" 0 "Save file to BioFS" "Continue without save" "Cancel"]
	    if { $answer == 2 } {
		return -1
	    }
	    if { $answer == 0 } {

		set dirPath "/[::biocore::getProjectName $::biocore::Project]/"

		set length [string length $newfilename]
		set extStart [expr {$length - 4 }]

		set fname [string range $newfilename 0 [expr {$extStart - 1}]]
		set suffix [string range $newfilename $extStart end]

		#set i 1
		set changed 0
		set origfile $newfile
		set end 0

		while { [::biocore::findFile $dirPath $::BiocorePubSync::newfilename] == -1 && !$end } {
		catch {
		    
		    # A file already exists with this name; ask user to 
		    # rename or overwrite it

		    set renameAnswer [tk_dialog .fileExists "File exists" "The file $::BiocorePubSync::newfilename already exists in the BioFS. Do you wish to rename it, or overwrite it?" "" 0 "Rename" "Overwrite" "Cancel"]

		    set done 0

		    if { $renameAnswer == 0 } {

			set newNameFrame [toplevel .newNameFrame -takefocus 1]
			wm title $newNameFrame "Enter new name for file"
			set labelFrame [frame $newNameFrame.labelFrame]
			set entryFrame [frame $newNameFrame.entryFrame]
			set buttonFrame [frame $newNameFrame.buttonFrame]
			set newNameLabel [label $labelFrame.newNameLabel -text "Please enter a name for the file:"]
			set newNameEntry [entry $entryFrame.newNameEntry -width 40 -textvariable ::BiocorePubSync::newfilename]
			#$newNameEntry insert end $newfilename

			set okayButton [button $buttonFrame.okayButton -text "Okay" -command "puts \"newfilename = \$::BiocorePubSync::newfilename\"; set ::BiocorePubSync::newfilename \$::BiocorePubSync::newfilename; puts \"OKAY\"; destroy .newNameFrame; set done 1;"]
			set cancelButton [button $buttonFrame.cancelButton -text "Cancel" -command "destroy .newNameFrame; set ::BiocorePubSync::newfilename \$::BiocorePubSync::newfilename; set done 1"]


			pack $labelFrame -side top
			pack $entryFrame -side top
			pack $buttonFrame -side top
			
			pack $newNameLabel -side left
			
			pack $newNameEntry -side left

			pack $okayButton -side left
			pack $cancelButton -side left



			vwait done
		    } elseif { $renameAnswer == 1 } {
			set end 1
		    } else {
			set end 1
			return -1
		    }

	    } errFoo
		    #puts "Error in rename: $errFoo"
		    if { $errFoo == -1 } {
			return -1
		    }
		}


		if { $changed == 1 } {
		    #puts "File $origfile already exists in the BioFs. The file is being renamed to $newfilename."
		}

		#set path [biocore_handle putBiofsFile "$dirPath$newfilename" "$origfile" "$newfilename"]
		set path [::biocore::putBiofsFile "$dirPath$newfilename" "$origfile" "$newfilename"]

		#set newURL [biocore_handle cget URL]biofs$dirPath$newfilename
		set newURL ""
		append newURL $::biocore::URL biofs$dirPath$newfilename

		regsub -all " " $newURL "%20" newURL

		regsub -all $origfile $tmptext $space$newURL$space tmptext
		regsub -all ampersand $tmptext {\&} tmptext

		
	    } else {
		#puts "biocorepubsync) File not saved."
		return -1
	    }
	}
    }
    } foo 
    #puts "biocorepubsync) Error in upload_local: $foo"
    if { $foo == -1 } {
	return -1
    }
    return $tmptext

}

################################
#
# replace_URL_with_localFile
#
# When synchronizing on Windows, this function downloads a file from
# the BioFs to a local file, and replaces the text in the script.
#
# Parameters:
#  text - the save state script
#  linestart - start of the line to search for (ie: "mol load")
#  url - url or regexp to search for
#  lineend end of the line to search for (ie: "type pdb")
#  suffix - filetype to search for (ie: pdb, psf, dcd)
#
# Returns:
#  a modified version of the original "text" parameter that replaces
#  all instances of specified URL's with local file names of files
#  that it downloaded
#

proc ::BiocorePubSync::replace_URL_with_localFile { text linestart url lineend suffix} {

    # "fileList is a list of the names of the files downloaded
    # when synchronizing a state on Windows. It is used for deleting
    # the files when the synch is done
    variable fileList
    variable biofs_file
    variable biofs_psf_file
    variable biofs_pdb_file
    variable biofs_dcd_file

    variable tmpdir

    set tmpFileStart [file join $tmpdir tmp]

    set leftToCheck $text
    set endText $text
    set ends ""
    set start 0
    set end 0

    set index [molinfo num]

    append newLine $linestart "(.)*" $url "(.)*" $lineend
    while { [regexp -linestop "$newLine" $leftToCheck line] } { 

	set localFile ""

	regexp -linestop -indices "$newLine" $leftToCheck ends

	set ends [split $ends]
	set start [lindex $ends 0]
	set end [lindex $ends 1]
	if { [string match $end ""] } { set end "end" }
	set leftToCheck [string range $leftToCheck $end end]

	# replace URL with path to local file
	regsub -all {\?} $endText "questionmark" endText
	regsub -all {\?} $line "questionmark" line
	
	set len [ string length $line ]
	set urlend [ expr { $len - [string length $lineend] } ]
	set foundURL [string trim [ string range $line [string first "http" $line 0] $urlend ] ]

	append localFile $tmpFileStart $index "." $suffix
	incr index

	regsub -all -linestop $foundURL $endText $localFile endText

	regsub -all "questionmark" $endText {?} endText
	regsub -all "questionmark" $foundURL {?} foundURL
	#regsub -all "waitfor all" $foundURL "" foundURL
	#regsub -all "type pdb" $foundURL "" foundURL
	regsub -all "type psf" $foundURL "" foundURL
	regsub -all "type dcd" $foundURL "" foundURL

	#vmdhttpcopy $foundURL $localFile

	if { [string match $suffix "dcd"] } {
	    set downloadDCD_frame [toplevel .downloadDCD_frame]
	    set answer [tk_dialog $downloadDCD_frame "Warning!" "This saved state involves downloading a DCD file. DCD files are typically very large, and downloading it may take some time. Do you wish to proceed?" "" 1 "Yes" "No"]
	    if { $answer != 0 } {
		#puts "biocorepubsync) State not loaded"
		return
	    }
	}

	#after idle ::BiocorePubSync::biocorehttpcopy $foundURL $localFile [biocore_handle cget Session]
	after idle ::BiocorePubSync::biocorehttpcopy $foundURL $localFile $::biocore::Session

	after idle lappend fileList $localFile

	if { [string match $suffix "dcd"] } {
	    #append biofs_dcd_file " $foundURL"
	    lappend biofs_dcd_file $foundURL
	} else {
	    lappend biofs_file $foundURL
	    if { [string match $suffix "psf"]} {
		lappend biofs_psf_file $foundURL
	    } elseif { [string match $suffix "pdb"]} {
		lappend biofs_pdb_file $foundURL
	    }
	}
    }
    return $endText

}

#########################
#
# show_state_info
#
# gets information on a given state
# (currently just opens up the vmd state page in the notebook)
#
# parameters: id - id of the message
#
proc ::BiocorePubSync::show_state_info { id } {

    #variable biocore_handle 
    catch { 
	# Set up a dummy Biocore object to test internet connection
	#biocore_handle verify
      set userId [::biocore::verify]
      if {userId == "-1"} {
         new_error_window
      }
    } loginError
    if { [string first "couldn't open socket" $loginError] != -1} {

	new_error_window
	return
    }

    if { $id == -1 } { 
	#puts "biocorepubsync) No state selected"
	return
    }
    #append url $::biocore::URL secure/notebook/notebookEntry.do?id=$id&p=[biocore_handle cget Project]&jsessionid= [biocore_handle cget Session]
    append url $::biocore::URL secure/notebook/notebookEntry.do?id= $id \&p= $::biocore::Project &jsessionid= $::biocore::Session
    #puts "url = $url"

    vmd_open_url $url
}

#########################
#
# delete_entry
#
# deletes an state from the database
#
# parameters: id - the message of the VMD entry
#
proc ::BiocorePubSync::delete_entry { id } {

    if { [catch {
    #set result [biocore_handle deleteNotebookEntry $id ]
	set result [::biocore::deleteNotebookEntry $id]
    if { -1 == $result } {
	set delete_error_frame [toplevel .delete_error_frame]
	tk_dialog $delete_error_frame "Cannot delete" "Message has replies, cannot delete." "" 0 "Ok"
    }
    if { -2 == $result } {
	set delete_error_frame [toplevel .delete_error_frame]
	tk_dialog $delete_error_frame "Cannot delete" "You cannot delete a state you did not create." "" 0 "Ok"
    }


    populate_table
    } delete_error]  } {
	if { [string first "couldn't open socket" $delete_error] != -1 } {
	    new_error_window
	    return
	}
    }
}

#########################
#
# popup_menu
#
# opens up the popup menu for the state lists
#
# parameters:
#       x: Screen X coordinate to open window at
#       y: Screen Y coordinate to open window at
#       iy: Window Y coordinate, to highlight state
#
proc ::BiocorePubSync::popup_menu { x y iy} {

    variable menubar
    variable popup
    variable name_list
    variable username_list
    variable id_list
    
    $name_list selection clear 0 end
    $username_list selection clear 0 end
    $id_list selection clear 0 end

    set index [$name_list nearest $iy]

    $name_list selection set $index
    $username_list selection set $index
    $id_list selection set $index

    tk_popup $popup $x $y

}

####################
#
# getUserOfSelectedState
#
# gets the user id of the selected state
#
proc ::BiocorePubSync::getUserOfSelectedState { } {
    variable username_list
    catch {
	#set allUserList [biocore_handle getUserList]
	set allUserList [::biocore::getUserList]
    
	set userIndex [lsearch $allUserList [$username_list get [$username_list curselection]]]; 
	if { $userIndex == -1 } { 
	    return [::biocore::getUserIdByName $name]
	    
	} else {
	    incr userIndex; 
	    set userId [lindex $allUserList $userIndex];
	    return $userId;
	}
    } foo
    return $foo
    #puts "Error in getUserOfSelectedState: $foo"
}

###############################
#
# biocorehttpcopy
# 
# direct copy of vmdhttpcopy, with an extra -headers
# element to pass the session cookie
#

# Copy a URL to a file and print meta-data
proc ::BiocorePubSync::biocorehttpcopy { url file id {chunk 4096} } {
if {[catch {

    variable m_timeout
  set out [open $file w]
  set token [::http::geturl $url -channel $out -progress vmdhttpProgress \
	-blocksize $chunk -binary 1 -headers "Cookie jsessionid=$id"]

  close $out
  # This ends the line started by http::Progress
  puts stderr ""
  upvar #0 $token state
  set max 0
  foreach {name value} $state(meta) {
    if {[string length $name] > $max} {
      set max [string length $name]
    }
    if {[regexp -nocase ^location$ $name]} {
      # Handle URL redirects
      #puts "Location:$value"
      return [copy [string trim $value] $file $chunk]
    }
  }
  incr max

#  foreach {name value} $state(meta) {
#    puts [format "%-*s %s" $max $name: $value]
#  }

  return $token
} error]} {
puts "biocorepubsync) Error in biocorehttpcopy: $error"
}

}


#########################
#
# bio_startup
#
# initialize settings for pub/synch
#
proc ::BiocorePubSync::bio_startup { } {

    global env
    variable biofs_file
    variable biofs_dcd_file
    variable biofs_pdb_file
    variable biofs_psf_file
    variable tmpdir
    variable tmp_save

    variable biocore_handle

    set biofs_file ""
    set biofs_psf_file ""
    set biofs_pdb_file ""
    set biofs_dcd_file ""

    set foo ""
    set os [vmdinfo arch]
    regexp WIN32 $os foo
    if { [string match $foo WIN32] } {
	catch { set tmpdir $env(TEMP)}
	catch { set tmpdir $env(TMP) }
    } else {
	set tmpdir $env(TMPDIR)
    }
    set tmp_save [file join $tmpdir tmp_save[pid]]
    vmdinfo version
    vmdinfo authors
    
    set vmdPath [get_vmd_path]

    if { [info exists env(LOADVMDSESSION)] } {
	puts "biocorepubsync) Loading Session \#$env(LOADVMDSESSION)"
	after idle ::BiocorePubSync::biocore_synchronize $env(LOADVMDSESSION) 0
    }
    
    if { [info exists env(PDB)] } {
	mol pdbload $env(PDB)
    }

}; # end bio_startup

####################
#
# biocorestates
#
# opens up the pub/synch window
#
proc biocorestates { } {
    if [winfo exists .w] {
	wm deiconify .w
    } else {
	::BiocorePubSync::bio_startup
	return [::BiocorePubSync::session_window]
    }    
}

###############################################################################
###############################################################################
###############################################################################

#################################
#
# VMD BioCoRE Plugin procs
#
#################################


########################################
#
# package: BiocorePubSync
# function: BiocorePubSync
#
# Opens the VMD pub/synch window, or prompts a user
# to log in to BioCoRE if it cannot find the
# session file
#
# parameters: none
# returns: a window; either the saved states window or
#          a login window
#
########################################
proc ::BiocorePubSync::biocorePlugin { } {
#puts "PLUGIN $::biocore::URL"
    global env
    global tcl_platform

    variable w

    variable listId

    variable is_logged_in 0

    if { [catch { ::biocore::verify } verifyError ] } {
	#Biocore ::BiocorePubSync::biocore_handle
    } else {
	#puts $verifyError
    }
#puts "after verify $::biocore::URL"


     if { [winfo exists .w.error_window] } {
	# if they previously returned the error window,
	# check again in case they corrected the problem.
	destroy .w.error_window
    }
   
    catch {
#    if [catch {
#	package require tls 
#	http::register https 443 ::tls::socket
#	
#    } ] {
#	set TLS 0
#    } else {
#	set TLS 1
#    }

    if [catch {
#puts "before initDefault $::biocore::URL"
	::biocore::initDefault "vmdPubSync"
#puts "after initDefault $::biocore::URL"
	check_biocore
#puts "after check_biocore $::biocore::URL"
    } cmderrs] {

	#puts "Error in loading BioCoRE: $cmderrs\n"
	#puts "To interface with BioCoRE, you first need to start up the BioCoRE Control Panel. For more information, please visit http://www.ks.uiuc.edu/Research/biocore/."

   #puts "before the biocorelogin code"
	package require biocorelogin 1.0
	set w [::BiocoreLogin::open_new_login_window 0 .w]
	after idle [bind $w <Map> { if { [::BiocorePubSync::redraw] } { ::BiocorePubSync::biocorePlugin } }]
	return $w
    }
	#puts "after all that code"

	catch {

	    #set errorMessages [::biocore::initDefault]
	#set verify [::BiocorePubSync::biocore_handle verify]
	
#	if { [string length $errorMessages] > 0 ||                                }
	if { \
	     [string match $::biocore::URL ""] ||
	     ![::biocore::verify]  } {
	    

       #puts "before the biocorelogin code second time"
	    # they need to start the Control Panel
	    #puts "Error: could not init BioCoRE"
	    package require biocorelogin 1.0
	    set w [::BiocoreLogin::open_new_login_window 0 .w]
	    after idle [bind $w <Map> { if { [::BiocorePubSync::redraw] } { ::BiocorePubSync::biocorePlugin } }]
	    return $w
} else {
   #puts "before the return 0"
    return 0
}
    }  verifyError 
	#puts "verifyError = $verifyError"

	if { [string first "couldn't open socket" $verifyError] != -1 } {
       #puts "before the couldn't open socket"
	    return [error_window]
	}
	if { $verifyError == ".w" } {
       #puts "verifyError == .w"
	    return .w
	}
   #puts "before the catch Project"
    
    # if they get here, open the VMD load/save state window
	if { [catch { $::biocore::Project }] } { 
	    #set m_server [biocore_handle cget URL]
	    #biocore_handle configure Project 1
	    #set projectList [biocore_handle getProjectList]
	    #biocore_handle configure Project [lindex $projectList 1]

	    set ::biocore::Project 1

	    set projectList [::biocore::getProjectList]

	    set ::biocore::Project [lindex $projectList 1]

	}

    bio_startup


    set w [session_window]

    if { [winfo exists $w.error_window] } {
	pack forget $w.error_window
    }

    #set checkLatestTag [after 1000 ::BiocorePubSync::check_latest $listId]

    return $w
    } foo

    if { [string first "couldn't open socket" $foo] != -1 } {
	return [error_window]
    }

}

########################################
#
# function: BiocorePubSync_tk_cb
#
# callback function used by VMD to return
# a window
#
# parameters: none
# returns: none
#
########################################

proc biocorepubsync_tk_cb { } {

    #puts "Start of biocorepubsync_tk_cb $::biocore::URL"
    ::BiocorePubSync::biocorePlugin
    return $::BiocorePubSync::w

}

################
#
# new_error_window
#
# Opens up an error window in a new frame
#
# parameters: none
#
# returns: none; but opens a new error frame
#
proc BiocorePubSync::new_error_window { } {

    set error_window [toplevel .error_window]
    set okay [tk_dialog $error_window "Error" "There was an error in performing the task you requested.\nPlease be sure the server name you specified is correct, and that you have a working Internet\nconnection and try again." "" 0 "Okay"]

}
    
################
#
# error_window
#
# Opens up an error window in the main .w frame
#
# parameters: none
#
# returns: the error window
#
proc BiocorePubSync::error_window { } {

    variable w

    if { ![winfo exists .w] } {
	set w [toplevel .w]
    }
    catch {
	pack forget $w.login_window
	pack forget $w.main_window

	if { ![winfo exists $w.error_window ]} {
    set error_window [frame $w.error_window]
    wm title .w "Error"
    set error_label [label $error_window.error_label -text "There was an error in performing the task you requested.\nPlease be sure the server name you specified is correct, and that you have a working internet\nconnection and try again."]
	set ok_button [button $error_window.ok_button -text "Okay" -command { wm withdraw .w; pack forget .w.error_window}]

    pack $error_label -side top
	pack $ok_button -side top
    pack $error_window		
    
    after idle [bind $w <Map> { if { [::BiocorePubSync::redraw] } { ::BiocorePubSync::biocorePlugin } }]
	} else {
	    pack $w.error_window
	}
	   
    } foo
    #puts "Error in error_window: $foo"
    
    after idle [return $w]
    
}

######################
#
# no_state_selected
#
# Helper function that pops up a dialog box 
# alerting the user if no state has been selected for
# such functions as loading and deleting.
#
# parameters: title - the title of the window
#             message - an additional message to add to the window (optional)
#
# returns: none
#
proc ::BiocorePubSync::no_state_selected { title message } {
    
    set info "No state has been selected."
    if { ![string match $message ""] } {
	append info "\n" $message
    }

    tk_dialog .noStateSelected $title $info "" 0 "Okay"
}


##############################
#
# redraw
#
# determines if the window needs to be redrawn
# because the user logged in as a different user
#
proc ::BiocorePubSync::redraw { } {
#puts "REDRAW:"

# somehow, we don't have a base .w window
   if { ![winfo exists .w] } {
      puts ".w doesn't exist: redrawing"
      return 1
   }

# we have an error window right now
   if { [winfo exists .w.error_window] } {
      puts ".w.error_window exists"
      # if they previously returned the error window,
      # check again in case they corrected the problem.
# foobar.  how can we have an error window, but no children for .w ?
      if { [winfo children .w] == "" || ![winfo ismapped .w.error_window]} {
         #puts "No children, or error_window isn't mapped"
         return 1
      }
   }

   # Let's see if we have a valid user
   set userId [::biocore::verify]

   # if a user exists, we should be on the main window...
   if {$userId > 0} {
      #puts "user ( $userId) is good."
      if { ! [winfo exists .w.main_window] } {
         #puts "user is good, but .w.main_window doesn't exist.  need to redraw"
         return 1
      }
   }

   # foobar.  The code below was checking to see if the user's session
   # had changed in the session file.  Ok to do that, but probably not
   # needed in redraw, since redraw seems to get called 39 times to show
   # the window anyway

   return 0 



#    if { ![winfo exists .w] } {
#	puts ".w doesn't exist: redrawing"
#   return 1
#    }

#    if { [winfo exists .w.error_window] } {
#       puts ".w.error_window exists"
#	# if they previously returned the error window,
#	# check again in case they corrected the problem.
#	if { [winfo children .w] == "" || ![winfo ismapped .w.error_window]} {
#	    puts "No children, or error_window isn't mapped"
#       return 1
#	}
#    }

#	catch { 
#      ::biocore::verify 
#      if { ! [winfo exists .w.main_window] } {
#         puts ".w.main_window doesn't exist.  need to redraw"
#         return 1
#      }
#   } foo
#	if { [string first "couldn't open socket" $foo] == -1 } {
#	    puts "couldn't open socket in redraw: '$foo'"
#		return 1
#	}
    if { [catch {
       #puts "in late catch"
    #Biocore newBio
    #newBio initDefault
	set currSession $::biocore::Session
	::biocore::initDefault "vmdPubSync"

   if { ![string match $currSession $::biocore::Session] } {

      if { [winfo exists .w.main_window] } {
         #destroy .w.main_window
      }
	#::BiocorePubSync::biocore_handle initDefault
	# reset project (set to 1 for now, (AUTP), but this will have to change)
	#::BiocorePubSync::biocore_handle configure Project 1
      puts "Sessions differ"
      after idle [return 1]
    }

    } error ] } {
	puts "Error: $error"
   return 1
    }

    if { $error == 1 } {
	puts "error = 1: $error"
   return 1
    }
    puts "returning 0"
   return 0
}




############################################################
    # From: http://wiki.tcl.tk/14534
    # Based heavily on Stephen Uhler's HTML parser in 10 lines
    # Modified by Eric Kemp-Benedict for XML
    #
    # Turn XML into TCL commands
    #   xml     A string containing an html document
    #   cmd     A command to run for each html tag found
    #   start   The name of the dummy html start/stop tags
    #
proc ::BiocorePubSync::taxparse {cmd xml {start docstart}} {
    if { [catch {
   set xml [string map {\\ \\\\ \{ \&#123; \} \&#125; \&quot; {\"} \&lt; < \&#039; \'} $xml]
   #regsub -all \{ $xml {\{} xml
   #regsub -all \} $xml {\}} xml
   set exp {<(/?)([^\s/>]+)\s*([^/>]*)(/?)>}

   set sub "\}\n$cmd {\\2} \[expr \{{\\1} ne \"\"\}\] \[expr \{{\\4} ne \"\"\}\] \
      \[regsub -all -- \{\\s+|(\\s*=\\s*)\} {\\3} \" \"\] \{"
  
   regsub -all $exp $xml $sub xml
   #puts "taxparse3.  xml=<<<<<'$xml'>>>>>"
   regsub -all {\&#123;} $xml {\{} xml
   regsub -all {\&#125;} $xml {\}} xml
   regsub -all {\&#47;} $xml {/} xml
   regsub -all {\&gt;} $xml > xml
   regsub -all {\&amp;} $xml {\&} xml
   #puts "\ntaxparse4.  xml=<<<<<'$xml'>>>>>"

#   puts "biocorechat) getting ready to eval \"$cmd {$start} 0 0 {} \{ $xml \}\""
   eval "$cmd {$start} 0 0 {} \{ $xml \}"
#   puts "biocorechat) getting ready to eval \"$cmd {$start} 1 0 {} {}\""
   eval "$cmd {$start} 1 0 {} {}"
    } taxParseError] } {
	global errorInfo
	global errorCode
	#puts "biocorechat) Error in taxparse: <$taxParseError> <$errorInfo> <$errorCode>"
    }

}

proc ::BiocorePubSync::compactws {s} { return [regsub -all -- {\s+} [string trim $s] " "] }

proc ::BiocorePubSync::parseListenerMessages {tag cl selfcl props body} {
    #puts "parseListenerMessages.  tag='$tag', cl='$cl', selfcl='$selfcl', props='$props', body='$body'"

    set vmdType 2

    if [string equal $tag {?xml}] {
      return
   }
   array set temp $props
   switch $tag {
      {docstart} {}    
      {vector} {}
      {Generic Name Value Listing.  Good For Testing} {
         #puts "biocorechat) $tag"
         foreach item [array names temp] {
            #puts "biocorechat) [string totitle $item]: $temp($item)"
         }

      }
      {ChatMessage} {

      }
      {UserLoggedVectorMessage} {

      }
       {NotebookMessage} {
	   catch {
	   foreach item [array names temp] {
	       #puts "biocorechat) NotebookMessage item $item = $temp($item)"
	       switch $item {
		   {su} { set subject $temp($item) }
		   {se} { set sender $temp($item) }
		   {id} { set id $temp($item) }
		   {t} { set type $temp($item) }
		   {op} { set operation $temp($item) }
		   {_time} { set ti $temp($item) }
		   {_p} { set p $temp($item) }
	       }
	   }
	       #puts "type = $type"
	       if { [string match $type $vmdType]} {
		   populate_table
		   #add_latest_entry $sender
	       }
	   }
       }

      {NumLoggedInMessage} {

      }

      {BioFsMessage} {

      }
      {UserProfileMessage} {

      }
      {LoginoutMessage} {
         foreach item [array names temp] {
            switch $item {
               {pl} {set projList $temp($item)}
               {id} {set id $temp($item)}
               {a} {set op $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }

         set username ""

         if [catch {set username [::biocore::getUserName $id ]} errmsg] {
            # if we make it in here, we had an error thrown
            global errorInfo
            global errorCode
            puts "biocorechat) Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
        }


        if { [string compare $username ""] != 0} {

           if { $op == "LOGIN"} {
              #$chat_window insert end "has logged in." loginOut
           } elseif { $op == "LOGOUT"} {
              #$chat_window insert end "has logged out." loginOut
           } elseif { $op == "AUTOLOGOUT"} {
              #$chat_window insert end "has been logged out due to inactivity." loginOut
           } elseif { $op == "RELOG"} {
              #$chat_window insert end "has relogged in." loginOut
           } elseif { $op == "OPENCP"} {
              #$chat_window insert end "has opened the Control Panel." loginOut
           } elseif { $op == "CLOSECP"} {
              #$chat_window insert end "has closed the Control Panel." loginOut
           } elseif { $op == "AUTOCLOSECP"} {
              #$chat_window insert end "has had their Control Panel closed due to inactivity." loginOut
#puts "AUTOCLOSECP received"
           } elseif { $op == "AcceptInvitation"} {
              #$chat_window insert end "has joined the $pn project." loginOut
           }

           #$chat_window insert end \n
           #$chat_window configure -state disabled
           #$chat_window yview moveto 1.0
        }
         #puts "biocorechat) Loginout: Usr: $id oper: $op to projects: $projList at time: $ti"
      }
      default { 
         #puts stdout "biocorechat) Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }

   } 
   #puts stdout "biocorechat) Received '$tag' '$cl' '$selfcl' '$props' '$body'"
}

# ------------------------------------------------------------------
# Read data from a channel (the server socket) and put it to stdout
# this implements receiving and handling (viewing) a server reply 
proc ::BiocorePubSync::read_sock {sock myid} {
#puts "reading sock $sock $myid"
    variable notificationSock

   #puts stdout "biocorechat) preparing to read from server socket"
   set l [read $sock 1]

   if { $l == 2 } {
	    #puts "CLOSING"
	    #tk_messageBox -type ok -message "The user has been logged out.\nPlease log in again. 1"
       fileevent $notificationSock readable ""
       close $notificationSock
       set notificationSock ""
tk_messageBox -type ok -message "The user has been logged out of BioCoRE. The BioCoRE Saved State Window in VMD will now close. If you wish to continue using the Saved State window, please log in again."
       wm withdraw .w

      #::BiocorePubSync::openWindow
   } else {

      # OK.  We've got a message from the server that there are messages
      # waiting for us.. let's get them
      #puts stdout "biocorechat) Note from server: '$l'"

       #if { ![info exists ::BiocorePubSync::notificationSock] } {
       #   ::BiocorePubSync::init
       #}
      set strMessages [::biocore::getLatestMessages $myid -1]
      #puts stdout "biocorechat) $strMessages"
      taxparse parseListenerMessages $strMessages
   }
}

# ------------------------------------------------------------------
proc ::BiocorePubSync::check_latest {myid} {
#puts "check_latest $myid"
    if { [catch {
   global checkLatestTag
   set strMessages [::biocore::getLatestMessages $myid -1]
   #puts stdout "biocorechat) $strMessages"
   taxparse parseListenerMessages $strMessages
   set checkLatestTag [after 300000 ::BiocorePubSync::check_latest $myid]
    } checkLatestError ] } {
	global errorInfo
	global errorCode
	if { [string match $checkLatestError  "Invalid User"] } {
	    #set ok [tk_dialog .loggedOut "Logged out" "You have been logged out of BioCoRE. The BioCoRE Chat Window in VMD will now close. If you wish to continue using the BioCoRE chat window, please log in again." "" 0 "Okay"]
	    #wm withdraw $::BiocorePubSync::chatWindowName
	    #deregister_listener $myid

	}
	#puts "biocorechat) Error in checkLatest: <$checkLatestError> <$errorInfo> <$errorCode>"	
    }
}
