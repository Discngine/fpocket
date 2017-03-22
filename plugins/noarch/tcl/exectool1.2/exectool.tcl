##
## Finder Tool 1.0 
##
## Set of utilities for finding programs. Maintains a "registry" of
## programs, allowing a simple mnemonic to be used to get the full path and
## an optional textural description of a program.
##
## ::ExecTool::find can be used by other extensions to search for
## programs. It accepts optional arguments, described below.
##
## ::ExecTool::exec allows other extensions to use these utilities with
## minimal changes.
##
## Author: Eamon Caddigan
##         eamon@ks.uiuc.edu
##         vmd@ks.uiuc.edu
##
## TODO: Much of the work done by ::find (searching the path, etc.) can be 
##       replaced with the Tcl built-in function ::auto_execok, and should 
##       probably be rewritten to take advantage of that.
##
## $Id: exectool.tcl,v 1.46 2007/03/09 21:22:21 kvandivo Exp $
##

## Tell Tcl that we're a package and any dependencies we may have
package require biocore 1.18
package provide exectool 1.2

namespace eval ::ExecTool:: {
  namespace export exectool

  # window handles
  variable w                         ;# handle to main window

  # global settings for the GUI
  variable program  ""
  variable location ""

  # The program registry. Stored as a hash of lists, where each key
  # represents the program mnemonic, and the value a list containing the
  # full path and a textural description of the program.
  variable registry

  # the list of directories to check for programs. This is initialized using
  # PATH the first time ::ExecTool::get_path is called, and user-selected
  # directories are appended to it through subsequent runs.
  variable pathlist

  # job submission state used by the remjob_xxx routines
  variable job_info_buf {}
  
  # BioCoRE job config window
  variable biocore_win
  variable biocore_input_fields {}
  variable biocore_default_projname {}
  variable biocore_default_acctname {}
  variable remjob_interactive_loggedin
}

##
## Main routine
## Create the window and initialize data structures
##
proc ::ExecTool::exectool {} {
  variable w
  variable program

  # If already initialized, just turn on
  if { [winfo exists .exectool] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".exectool"]
  wm title $w "Program Finder" 
  wm resizable $w no no

  set normalfont [font create -family helvetica -weight normal]
  set boldfont [font create -family helvetica -weight bold]

  ##
  ## make the menu bar
  ## 
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x -side top

  menubutton $w.menubar.help -text "Help" -underline 0 -menu $w.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5
  pack $w.menubar.help -side right

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About exectool" \
              -message "A simple tool used to find programs."}

  frame $w.inputframe
  label $w.inputframe.label -font $normalfont -text "Program name: "
  entry $w.inputframe.entry -font $normalfont -width 16 -relief sunken -bd 2 \
    -textvariable "::ExecTool::program"
  button $w.inputframe.search -font $normalfont -text "Locate" \
    -command "::ExecTool::update_gui"
  pack $w.inputframe.label $w.inputframe.entry $w.inputframe.search \
    -side left -anchor w

  frame $w.outputframe
  label $w.outputframe.resultlabel -font $boldfont \
    -textvariable ::ExecTool::location
  pack $w.outputframe.resultlabel \
    -side left -anchor w

  ## 
  ## pack up the main frame
  ##
  pack \
       $w.inputframe $w.outputframe \
       -side top -pady 10 -padx 10 -fill x
}

proc ::ExecTool::update_gui {} {
  variable program
  variable location

  set programpath [::ExecTool::find -interactive $program]

  if {[string length $programpath] > 0} {
    set location $programpath
  } else {
    set location "$program: Command not found."
  }
}

##
## Search for the mnemonic. 
## Returns: full path to executable if found, otherwise the empty list.
##
## Usage: ::ExecTool::find [-interactive] [-path <path>] [-description <text>] mnemonic
##
## If '-interactive' is specified and Tk is available, the user is prompted
## for missing information.
##
## If '-path' is specified, the given path is tested before continuing the
## search
##
## If '-description' is specified and the mnemonic is not registered, the
## description defaults to the given text while prompting the user and
## returning the path.
##
proc ::ExecTool::find { args } {
  global tk_version
  variable registry
  variable pathlist

  set execpath ""

  set mnemonic ""
  set description ""
  set trypath ""
  set interactive 0


  ## Parse the arguments

  if {[llength $args] == 0} {
    error "Insufficient arguments"
  }

  set mnemonic [lindex $args end]
  for {set i 0} {$i < [expr {[llength $args] - 1}]} {incr i} {
    set arg [lindex $args $i]

    if {[string match $arg "-interactive"]} {
      # Ignore '-interactive' flag if Tk isn't available
      set interactive [info exists tk_version]

    } elseif {[string match $arg "-path"]} {
      incr i
      if {$i < [expr {[llength $args] - 1}]} {
        set trypath [lindex $args $i]
      } else {
        error "Insufficient arguments: no path specified"
      }

    } elseif {[string match $arg "-description"]} {
      incr i
      if {$i < [expr {[llength $args] - 1}]} {
        set description [lindex $args $i]
      } else {
        error "Insufficient arguments: no description specified"
      }

    } else {
      error "Bad option \"$arg\""
    }
  }


  ## Search for the path (and description) of the mnemonic

  # Check the registry of programs first
  if {[info exists registry($mnemonic)]} {
    set execpath [lindex $registry($mnemonic) 0]
    set description [lindex $registry($mnemonic) 1]

  # Next, check the suggested path, if given
  } elseif { ($trypath != {}) && [file executable $trypath] && ![file isdirectory $trypath]} {
    set execpath $trypath
    set registry($mnemonic) [list $execpath $description]

  # Search the PATH next
  } else {
    set execpath [::ExecTool::get_path $mnemonic]
    # Add it to the registry if it was found
    if {$execpath != ""} {
      set registry($mnemonic) [list $execpath $description]
    }
  }


  ## Prompt for the path if not found (and running interactively)

  if {$interactive && ($execpath == "")} {
    set answer \
      [tk_messageBox -type yesno -title "Program not found" -message \
        [join [list "Could not locate `$mnemonic'" \
                    "Description: $description" \
                    "Would you like to specify its path?"] "\n"] ]

    while {$answer} {
      set answer no

      # XXX - not sure if getOpenFile is best here
      if {[catch \
          {set execpath [tk_getOpenFile -title "Please select a program"]}]} {
        set execpath {}
      }

      if {($execpath != {}) && ![file executable [file join $execpath]] || [file isdirectory [file join $execpath]]} {
        set answer \
          [tk_messageBox -type yesno -title "Warning" -message \
            [join [list "Warning, `$execpath' is not executable." \
                        "Would you like to change the selection?"] "\n"] ]
      }
    }

    # If the program was located interactively, add an entry to the registry
    # and append the directory in which it's located to the path list
    if {$execpath != {}} {
      set registry($mnemonic) [list $execpath $description]
      lappend pathlist "[file dirname $execpath]"
    }
  }

  return $execpath
}


##
## Search the PATH for an executable named 'mnemonic'.
## Returns: full path to executable if found, otherwise the empty list.
##
proc ::ExecTool::get_path { mnemonic } {
  global env
  variable pathlist

  set execpath ""

  # Check if the argument is actually a complete path
  if {[file executable $mnemonic] && ![file isdirectory $mnemonic]} {
    set execpath [file normalize $mnemonic]

  # Search the PATH
  } else {
    # If the path list is uninitialized, populate it with the directories
    # in the PATH environment variable
    if {![info exists pathlist]} {
      if {[info exists env(PATH)]} {
        switch [vmdinfo arch] {
          WIN64 -
          WIN32 {
            set pathlist [split $env(PATH) \;]
          }
          default {
            set pathlist [split $env(PATH) :]
          }
        }
      } else {
        set pathlist {}
      }
    }

    # Search the program in the path list
    foreach directory $pathlist {
      set tf [file join $directory $mnemonic]
      if {[file executable $tf] && ![file isdirectory $tf]} {
        set execpath $tf
        break
      }
    }
  }

  return $execpath
}


##
## Drop-in replacement for exec; before running the program, it first
## searches for the executable and prompts the user for its location if it's
## not found.
##
proc ::ExecTool::exec { args } {
  if {[llength $args] < 1} {
    error "insufficient arguments"
  }

  set exec_name [lindex $args 0]

  set exec_path [::ExecTool::find -interactive $exec_name]

  if {$exec_path == {}} {
    error "couldn't find program `$exec_name'"
  }

  eval ::exec [list $exec_path] [lrange $args 1 end]
}


# This gets called by VMD the first time the menu is opened.
proc exectool_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::ExecTool::w  }]  ;# destroy any old windows

  ::ExecTool::exectool   ;# start the tool 
  return $ExecTool::w
}




# remjob_create_job
# Create a job info buffer, initially unpopulated, and return the ID
# to the caller
# Return:
#   job_id The job handle
proc ::ExecTool::remjob_create_job { } {
  variable job_info_buf
  
  set job_id [llength $job_info_buf]
  array set job_info {}
  set job_info(job_id) $job_id
  set job_info(status) "INITIALIZING"
  set job_info(errorMsg) ""
  # Initialize some fields for later use
  set job_info(input_file_list) {}
  set job_info(output_file_list) {}
  set job_info(file_retrieve_list) {}
  set job_info(file_transfer_list) {}    
  lappend job_info_buf [ array get job_info ]
  return $job_id
}

# remjob_config_prog
# For known job types, initialize various job parameters
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   type   Type name (one of the supported job types)
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 Connection error
#  -3 Unknown job type
proc ::ExecTool::remjob_config_prog { job_id type interactive } {
  variable job_info_buf
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { $type == "biocore" } {
    set job(type) "$type"
    set job(biocore_type) "Generic"
    lset job_info_buf $job_id [array get job]
    
    # Initialize the biocore connection; try to log in
    # First, just try using the session id file
    set res -1
    while { [catch { set res  [ ::biocore::initDefault "exectool$type[package versions exectool]/[package versions biocore]" ] } errmsg ]} {
      # if we make it in here, we had an error thrown
      global errorInfo errorCode
#      puts "exectool) remjob_config_prog initDefault returned error: <$errmsg> <$errorInfo> <$errorCode>"
      if { $interactive } {
        set result [ remjob_interactive_login ]
        if { $result == 0 } {
          return -2
        }
      } else {
        # Non-interactive, just return the error code
        return -2
      }
    }
    
    if { $res != "" } {
      puts "exectool) remjob_config_prog initDefault res is $res"
      return -2
    }

    # Check what happened and get the user id
    if {[catch {set user_id [::biocore::verify ]} errmsg]} {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "exectool) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return -2
    }

    if { $user_id <= 0 } {
      puts "exectool) remjob_config_prog bad user id $user_id"
      return -2
    } else {
      if {[catch {set userName \
                  [::biocore::getUserName $::biocore::userId] } errmsg ]} {
        # if we make it in here, we had an error thrown
        global errorInfo errorCode
        puts "exectool) biocore_checkLogin Error: <$errmsg> <$errorInfo> <$errorCode>"
        return -2
      }
    }

    set job(biocore_userId) "$user_id"
    set job(biocore_userName) "$userName"
    lset job_info_buf $job_id [ array get job ]
    
    return 0;
  } else {
    return -3
  }
}

# remjob_config_account
# For known job types, initialize various job parameters
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   account_params A list in array format { key1 {val1 flags} key2...}
#                  containing required field values for the job
#                  type (e.g. { biocore_username { joesmith hidden } ...}
#                  Supported flags: hidden - Don't show field in GUI
#                                   readonly - Don't allow field to be changed
#                                              in GUI
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 Connection error (couldn't connect to remote resource)
#  -3 Required parameters missing
#  -4 Unknown job type
#  -5 No projects available
#  -6 No accounts available
proc ::ExecTool::remjob_config_account { job_id acct_params \
  { continue_cb "" } { cancel_cb "" } } {
  variable biocore_win
  variable biocore_default_projname
  variable biocore_default_acctname
  variable job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  # Read the pre-initialized array values
  set job(hiddenFields) {}
  set job(readonlyFields) {}
  
  foreach { index val } $acct_params {
    # If its a single item, then its just the initial value of the parameter
    # If its a list, the first item is the initial value, and the subsequent
    # are flags offering additional information about the presentation
    set job($index) [ lindex $val 0 ]
    if { [ llength $val ] > 1 } {
      # States supported: readonly, hidden
      if { [ lsearch $val "hidden" ] != -1 } {
        lappend job(hiddenFields) $index
      }
      if { [ lsearch $val "readonly" ] != -1 } {
        lappend job(readonlyFields) $index
      }
    }
  }
  
  # Save the callback for later use
  set job(continueCB) $continue_cb  
  set job(cancelCB) $cancel_cb  
  lset job_info_buf $job_id [ array get job ]
  
  if { $job(type) != "biocore" } {
    return -4
  }
  
  # If already initialized, just turn on
  if { [winfo exists .execbiocore] } {
    wm deiconify $biocore_win
    return 0
  }

  set biocore_win [toplevel ".execbiocore" -width 640 -height 480]
  wm title $biocore_win "BioCoRE Exec Setup" 
  # wm resizable $biocore_win no no

  set normalfont [font create -family helvetica -weight normal]
  set boldfont [font create -family helvetica -weight bold]

  ##
  ## make the menu bar
  ## 
  frame $biocore_win.menubar -relief raised -bd 2 ;# frame for menubar
  pack $biocore_win.menubar -padx 1 -fill x -side top

  menubutton $biocore_win.menubar.help -text "Help" -underline 0 \
    -menu $biocore_win.menubar.help.menu
    
  # XXX - set menubutton width to avoid truncation in OS X
  $biocore_win.menubar.help config -width 5
  pack $biocore_win.menubar.help -side right
  tk_menuBar $biocore_win.menubar $biocore_win.menubar.help
  focus $biocore_win.menubar
  
  ##
  ## help menu
  ##
  menu $biocore_win.menubar.help.menu -tearoff no
  $biocore_win.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About exectool" \
              -message "A simple tool used to find programs and run jobs."}
   $biocore_win.menubar.help.menu add command \
    -label "Running jobs with BioCoRE" \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/exectool/biocore.html"
  $biocore_win.menubar.help.menu add command -label "BioCoRE help" \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/biocore/"

  
  # Build the project and account selection menus
  frame $biocore_win.menus
  
  # Project menu
  # Build project list for first pulldown
  label $biocore_win.menus.projlabel -text "Project:"
  set projlist [ ::ExecTool::remjob_biocore_getprojects $job_id]
  if { $projlist == -1 || $projlist == -2 } {
    remjob_biocore_error_dialog "Connection to BioCoRE failed. Try checking your connection to BioCoRE via the web, or try logging in again via the Extensions : BioCoRE : Login menu, then run again. (1,$projlist)" \
    "[string trimright [vmdinfo www] /]/plugins/biocore/index.html#login"
    remjob_cancel_button $job_id
    return -2
  }
  if { [llength $projlist] == 0 } {
    remjob_biocore_error_dialog "Couldn't get any projects for your account. Log in via the web and make sure you belong to at least one project. Create a new project for yourself, or join an existing one." \
    "[string trimright [vmdinfo www] /]/plugins/exectool/biocore.html#joinproject"
    remjob_cancel_button $job_id
    return -5
  }
  set indexlist {}
  foreach { id name } $projlist {
    lappend indexlist [ list $id $name ]
  }
  set indexlist [ lsort -index 0 -integer $indexlist ]
  foreach val $indexlist {
    lappend projmenulist [ lindex $val 1]
  }    
  set ::ExecTool::biocore_projId -1
  set projmenu [ eval tk_optionMenu $biocore_win.menus.projlist junkproj \
    $projmenulist ]

  $projmenu configure -takefocus 1

  set default_proj_item -1
  set i 0
  foreach val $indexlist {
    set id [ lindex $val 0 ]
    set name [ lindex $val 1 ]
    if { $biocore_default_projname == $name } {
      set default_proj_item $i
    }
    $projmenu entryconfigure $i \
      -command "::ExecTool::remjob_update_projId $job_id $id"
    incr i
  }
  if { $biocore_default_projname != {} } {
    if { $default_proj_item == -1 } {
      puts "exectool) Default project $biocore_default_projname was not found for this BioCoRE account"
      set default_proj_item 0
    }
  } else {
    set default_proj_item 0
  }

  # Account menu
  label $biocore_win.menus.acctlabel -text "Account:"
  set acctlist [::ExecTool::remjob_biocore_getaccounts $job_id ]
  if { $acctlist == -1 || $acctlist == -2 } {
    remjob_biocore_error_dialog "Connection to BioCoRE failed. Try checking your connection to BioCoRE via the web, or try logging in again via the Extensions : BioCoRE : Login menu, then run again. (2,$acctlist)" \
      "[string trimright [vmdinfo www] /]/plugins/biocore/index.html#login"
    remjob_cancel_button $job_id
    return -2
  }
  if { [llength $acctlist] == 0 } {
    remjob_biocore_error_dialog "BioCoRE doesn't have any job accounts recorded for your user account. Log in via the web and make sure you have set up at least one job account." \
    "[string trimright [vmdinfo www] /]/plugins/exectool/biocore.html#jobaccounts"
    remjob_cancel_button $job_id
    return -6
  }

  set indexlist {}
  foreach { id name } $acctlist {
    lappend indexlist [ list $id $name ]
  }
  set indexlist [ lsort -index 0 -integer $indexlist ]
  foreach val $indexlist {
    lappend acctmenulist [ lindex $val 1]
  }    
  set acctmenu [ eval tk_optionMenu $biocore_win.menus.acctlist acctvar \
    $acctmenulist ]

  $acctmenu configure -takefocus 1
  
  set default_acct_item -1
  set i 0
  foreach val $indexlist {
    set id [ lindex $val 0 ]
    set name [ lindex $val 1 ]
    if { $biocore_default_acctname == $name } {
      set default_acct_item $i
    }
    $acctmenu entryconfigure $i -command \
      "::ExecTool::remjob_update_biocore_window $job_id $id"
    incr i
  }
  if { $biocore_default_acctname != {} } {
    if { $default_acct_item == -1 } {
      puts "exectool) Default project $biocore_default_projname was not found for this BioCoRE account"
      set default_acct_item 0
    }
  } else {
    set default_acct_item 0
  }


  # By default, pick the first account and save the job info. We need to
  # do this so that getRequiredJobParams works
  set job(biocore_accountId) [ lindex $indexlist 0 0 ]
  lset job_info_buf $job_id [ array get job ]
  
  # Get the required parameters for this job/account type, We can't do this
  # until we've gotten the account list, and picked one to use
  set required_params [ ::ExecTool::remjob_biocore_getRequiredJobParams \
    $job_id ]
  foreach p $required_params {
    if { [info exists params($p)] } {
      set job($p) $params($p)
    }
  }
  # save values so far, then initialize remaining fields
  lset job_info_buf $job_id [ array get job ]
  ::ExecTool::remjob_init_job_fields $job_id
  
  pack $biocore_win.menus.projlabel -side left
  pack $biocore_win.menus.projlist -side left
  pack $biocore_win.menus.acctlist -side right
  pack $biocore_win.menus.acctlabel -side right
  pack $biocore_win.menus -side top -fill x
  
  # now that everything is set up, refresh the windows with the
  # other fields
  $projmenu invoke $default_proj_item
  $acctmenu invoke $default_acct_item

  return 0
}

proc ::ExecTool::remjob_update_projId { job_id proj_id } {
  variable job_info_buf
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  set job(biocore_projectId) $proj_id

  # Save the job info, since we might have changed the status
  lset job_info_buf $job_id [ array get job ]
}
  
proc ::ExecTool::remjob_update_queue { job_id queue_id } {
  variable job_info_buf
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  set job(biocore_queueName) $queue_id

  # Save the job info, since we might have changed the status
  lset job_info_buf $job_id [ array get job ]
}
  
proc ::ExecTool::remjob_update_biocore_window { job_id acct_id } {
  variable job_info_buf
  variable biocore_win
  variable biocore_input_fields
  
  # If the window exists, we need to extract the previously-entered field
  # values and store them. Then erase the window
  set jobDesc ""
  if { [ winfo exists $biocore_win.jobdata ] } {
    processEntryFields $biocore_input_fields
    # jobDesc should always exist, and I can't figure out how to do a
    # callback, so just grab it here
    set jobDesc [ $biocore_win.jobdata.jobdesc.tw.val get 1.0 end ]
    destroy $biocore_win.jobdata
    set biocore_input_fields {}
  }

  # Make sure we get the job buf after destroying the windows, to get
  # any refreshed values
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  set myw 26
  
  set job(biocore_accountId) $acct_id
  # If we're re-drawing the window, restore the jobDesc
  if { $jobDesc != "" } { 
    set job(biocore_jobDesc) $jobDesc
  }
  
  # Save the job info, since we might have changed the account id
  lset job_info_buf $job_id [ array get job ]

  # Get the required parameters for this job/account type
  set required_params [ ::ExecTool::remjob_biocore_getRequiredJobParams \
    $job_id ]
  
  frame $biocore_win.jobdata
  
  if { [ lsearch $required_params "biocore_jobName" ] != -1 \
       && [ lsearch $job(hiddenFields) "biocore_jobName"] == -1 } {
    frame $biocore_win.jobdata.jobname
    label $biocore_win.jobdata.jobname.label -width $myw -anchor e \
      -text "Job name: "
    pack $biocore_win.jobdata.jobname.label -side left -anchor e
    entry $biocore_win.jobdata.jobname.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_jobName %W"
    if { [ info exists job(biocore_jobName) ] } {
      $biocore_win.jobdata.jobname.val insert end "$job(biocore_jobName)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_jobName" ] != -1 } {
      $biocore_win.jobdata.jobname.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.jobname.val
    
    pack $biocore_win.jobdata.jobname.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.jobname -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_jobDesc" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_jobDesc"] == -1 } {
    frame $biocore_win.jobdata.jobdesc
    label $biocore_win.jobdata.jobdesc.label -width $myw -anchor e \
      -text "Description: "
    pack $biocore_win.jobdata.jobdesc.label -side left -anchor e
    frame $biocore_win.jobdata.jobdesc.tw -borderwidth 1 -relief solid
    if { [ info exists job(biocore_jobDesc) ] } {
      set jobDesc $job(biocore_jobDesc)
    } else { set jobDesc "" }
    text $biocore_win.jobdata.jobdesc.tw.val -height 4 -width 20 \
      -yscrollcommand "$biocore_win.jobdata.jobdesc.tw.scroll set"
    $biocore_win.jobdata.jobdesc.tw.val insert end $jobDesc
    if { [ lsearch $job(readonlyFields) "biocore_jobDesc" ] != -1 } {
      $biocore_win.jobdata.jobdesc.val configure -state disabled
    }

    scrollbar $biocore_win.jobdata.jobdesc.tw.scroll \
      -command "$biocore_win.jobdata.jobdesc.tw.val yview"
    pack $biocore_win.jobdata.jobdesc.tw.scroll -side right -fill y
    pack $biocore_win.jobdata.jobdesc.tw.val -side left -fill both -expand 1
    pack $biocore_win.jobdata.jobdesc.tw -side right -anchor nw -expand 1 \
      -fill both
    pack $biocore_win.jobdata.jobdesc -expand 1 -fill both -padx 1m -pady 1m
  }
   
  if { [ lsearch $required_params "biocore_workDir" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_workDir"] == -1 } {
    frame $biocore_win.jobdata.workdir
    label $biocore_win.jobdata.workdir.label -width $myw -anchor e \
      -text "Remote work dir: "
    pack $biocore_win.jobdata.workdir.label -side left -anchor e
    entry $biocore_win.jobdata.workdir.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_workDir %W"
    if { [ info exists job(biocore_workDir) ] } {
      $biocore_win.jobdata.workdir.val insert end "$job(biocore_workDir)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_workDir" ] != -1 } {
      $biocore_win.jobdata.workdir.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.workdir.val
    
    pack $biocore_win.jobdata.workdir.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.workdir -fill x -padx 1m -pady 1m
  }
  
  if { [ lsearch $required_params "biocore_cmd" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_cmd"] == -1 } {
    frame $biocore_win.jobdata.cmd
    label $biocore_win.jobdata.cmd.label -width $myw -anchor e \
      -text "Command: "
    pack $biocore_win.jobdata.cmd.label -side left -anchor e
    entry $biocore_win.jobdata.cmd.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_cmd %W"
    if { [ info exists job(biocore_cmd) ] } {
      $biocore_win.jobdata.cmd.val insert end "$job(biocore_cmd)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_cmd" ] != -1 } {
      $biocore_win.jobdata.cmd.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.cmd.val
    
    pack $biocore_win.jobdata.cmd.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.cmd -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_cmdParams" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_cmdParams"] == -1 } {
    frame $biocore_win.jobdata.cmdparams
    label $biocore_win.jobdata.cmdparams.label -width $myw -anchor e \
      -text "Command parameters: "
    pack $biocore_win.jobdata.cmdparams.label -side left -anchor e
    entry $biocore_win.jobdata.cmdparams.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_cmdParams %W"
    if { [ info exists job(biocore_cmdParams) ] } {
      $biocore_win.jobdata.cmdparams.val insert end "$job(biocore_cmdParams)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_cmdParams" ] != -1 } {
      $biocore_win.jobdata.cmdparams.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.cmdparams.val

    pack $biocore_win.jobdata.cmdparams.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.cmdparams -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_queueName" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_queueName"] == -1 } {
    set queuelist [ remjob_biocore_getQueuesForAccount $job_id ]
    
    if { $queuelist == -1 || $queuelist == -2 } {l
      remjob_biocore_error_dialog "Connection to BioCoRE failed. Try checking your connection to BioCoRE via the web, or try logging in again via the Extensions : BioCoRE : Login menu, then run again. (3,$queulist)"  \
    "[string trimright [vmdinfo www] /]/plugins/biocore/index.html#login"
      return -2
    }
    if { [llength $queuelist] == 0 } {
      remjob_biocore_error_dialog "This account type requires that a queue be selected, but the server is not returning any options to select from. This indicates some sort of BioCoRE configuration error. Please contact your BioCoRE server administrator, or the BioCoRE developers by email to biocore@ks.uiuc.edu" \ 
    "[string trimright [vmdinfo www] /]/plugins/exectool/biocore.html"
      return -5
    }
    set queuelist [ lsort -index 1 $queuelist ]
    set queuemenulist {}
    if { [ info exists job(biocore_queueName) ] } {
      set old_queue_tag "$job(biocore_queueName)"
    } else { 
      set old_queue_tag ""
    }
    set invoke_item 0
    set i 0
    foreach val $queuelist {
      lappend queuemenulist [ lindex $val 1]
      if { "$old_queue_tag" == "[ lindex $val 0 ]" } {
        set invoke_item $i
      }
      incr i
    }    

    frame $biocore_win.jobdata.queue
    label $biocore_win.jobdata.queue.label -width $myw -anchor e \
      -text "Queue name: "
    
    set queuemenu [ eval tk_optionMenu $biocore_win.jobdata.queue.val \
      junkqueue $queuemenulist ]

    $queuemenu configure -takefocus 1
    set i 0
    foreach val $queuelist {
      set id [ lindex $val 0 ]
      $queuemenu entryconfigure $i \
        -command "::ExecTool::remjob_update_queue $job_id $id"
      incr i
    }
    $queuemenu invoke $invoke_item
    
    pack $biocore_win.jobdata.queue.label -side left -anchor e
    pack $biocore_win.jobdata.queue.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.queue -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_projectToCharge" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_projectToCharge"] == -1 } {
    frame $biocore_win.jobdata.proj_to_charge
    label $biocore_win.jobdata.proj_to_charge.label -width $myw -anchor e \
      -text "Project to charge (blank=default): "
    pack $biocore_win.jobdata.proj_to_charge.label -side left -anchor e
    entry $biocore_win.jobdata.proj_to_charge.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_projectToCharge %W"
    if { [ info exists job(biocore_project) ] } {
      $biocore_win.jobdata.proj_to_charge.val insert end \
        "$job(biocore_projectToCharge)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_projectToCharge" ] != -1 } {
      $biocore_win.jobdata.proj_to_charge.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.proj_to_charge.val

    pack $biocore_win.jobdata.proj_to_charge.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.proj_to_charge -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_numProcs" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_numProcs"] == -1 } {
    frame $biocore_win.jobdata.num_procs
    label $biocore_win.jobdata.num_procs.label -width $myw -anchor e \
      -text "Number of processors:"
    pack $biocore_win.jobdata.num_procs.label -side left -anchor e
    entry $biocore_win.jobdata.num_procs.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_numProcs %W"
    if { [ info exists job(biocore_numProcs) ] } {
      $biocore_win.jobdata.num_procs.val insert end "$job(biocore_numProcs)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_numProcs" ] != -1 } {
      $biocore_win.jobdata.num_procs.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.num_procs.val
    
    pack $biocore_win.jobdata.num_procs.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.num_procs -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_cpuTime" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_cpuTime"] == -1 } {
    frame $biocore_win.jobdata.cpu_time
    label $biocore_win.jobdata.cpu_time.label -width $myw -anchor e \
      -text "CPU time (minutes):"
    pack $biocore_win.jobdata.cpu_time.label -side left -anchor e
    entry $biocore_win.jobdata.cpu_time.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_cpuTime %W"
    if { [ info exists job(biocore_cpuTime) ] } {
      $biocore_win.jobdata.cpu_time.val insert end "$job(biocore_cpuTime)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_cpuTime" ] != -1 } {
      $biocore_win.jobdata.cpu_time.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.cpu_time.val
    
    pack $biocore_win.jobdata.cpu_time.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.cpu_time -fill x -padx 1m -pady 1m
  }

  if { [ lsearch $required_params "biocore_memory" ] != -1  \
       && [ lsearch $job(hiddenFields) "biocore_memory"] == -1 } {
    frame $biocore_win.jobdata.memory
    label $biocore_win.jobdata.memory.label -width $myw -anchor e \
      -text "Memory:"
    pack $biocore_win.jobdata.memory.label -side left -anchor e
    entry $biocore_win.jobdata.memory.val \
      -validate focusout \
      -vcmd "::ExecTool::processField $job_id biocore_memory %W"
    if { [ info exists job(biocore_memory) ] } {
      $biocore_win.jobdata.memory.val insert end "$job(biocore_memory)"
    }
    if { [ lsearch $job(readonlyFields) "biocore_memory" ] != -1 } {
      $biocore_win.jobdata.memory.val configure -state readonly
    }
    lappend biocore_input_fields $biocore_win.jobdata.memory.val
    
    pack $biocore_win.jobdata.memory.val -side right -expand 1 -fill x
    pack $biocore_win.jobdata.memory -fill x -padx 1m -pady 1m
  }

  frame $biocore_win.jobdata.buttons
  button $biocore_win.jobdata.buttons.cancel -text "Cancel" \
    -command "::ExecTool::remjob_cancel_button $job_id"
  pack $biocore_win.jobdata.buttons.cancel -side left -anchor e
  button $biocore_win.jobdata.buttons.continue -text "Start job" \
    -command "::ExecTool::remjob_continue_button $job_id"
  pack $biocore_win.jobdata.buttons.continue -side right -anchor w
  pack $biocore_win.jobdata.buttons -fill x -padx 1m -pady 1m
  
  pack $biocore_win.jobdata -expand 1 -fill both
  return 1
}

proc ::ExecTool::remjob_cancel_button { jobid } {
  variable job_info_buf
  variable biocore_win
  variable biocore_input_fields
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $jobid]] == -1 } {
    return -1
  }
  array set job $jobl
  
  # save current values
  processEntryFields $biocore_input_fields
  catch { set job(biocore_jobDesc) [ $biocore_win.jobdata.jobdesc.tw.val get 1.0 end ] }
  lset job_info_buf $jobid [ array get job ]

  if { $job(cancelCB) != "" } {
    set cb "$job(cancelCB) $jobid"
    after idle "eval $cb"
  }  
  catch {after idle destroy $biocore_win}
}

proc ::ExecTool::remjob_continue_button { jobid } {
  variable job_info_buf
  variable biocore_win
  variable biocore_input_fields
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $jobid]] == -1 } {
    return -1
  }
  array set job $jobl
  
  # save current values
  processEntryFields $biocore_input_fields
  catch { set job(biocore_jobDesc) [ $biocore_win.jobdata.jobdesc.tw.val get 1.0 end ] }
  lset job_info_buf $jobid [ array get job ]

  if { $job(continueCB) != "" } {
    set cb "$job(continueCB) $jobid"
    after idle "eval $cb"
  }
  catch {after idle destroy $biocore_win}
  return
}

proc ::ExecTool::processField { job_id fieldName win } {
  variable job_info_buf
  
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  set job($fieldName) [ $win get ]

  # Save the job info, since we might have changed the status
  lset job_info_buf $job_id [ array get job ]
  return 1
}

proc ::ExecTool::processEntryFields  { input_fields } {
  # Get the required parameters for the old job/account type
  #set required_params [ ::ExecTool::remjob_biocore_getRequiredJobParams \
  #  $job_id ]
  #puts "Old required_params $required_params"
  foreach w $input_fields {
    $w validate
  }
}

# remjob_config_account_biocore
# For known biocore job types, initialize various job parameters
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   params An array containing required field values for the job
#          job type (e.g. params(username) = "joesmith" )
#          Parameter names:
#            biocore_accountId : biocore job account id to use 
#                              (default: prompt user)
#            projectId : biocore project to save job to 
#                       (default: biocore_projName, or prompt user)
#            biocore_projName : If projectId not specified, use this 
#                              (default: prompt user)
#            biocore_jobName : Name
#            biocore_jobDesc : Description (optional)
#            biocore_workDir : Remote work dir (default: home dir)
#            biocore_cmd : Command to execute
#            biocore_cmdParams : Parameters (default: blank)
#            biocore_queueName : Queue name (if required by account)
#            biocore_projectToCharge : Remote project to charge (if 
#                required by account)
#            biocore_numProcs : Number of processors to request (if 
#                required by account)
#            biocore_cpuTime : Minutes to request (if required by account)
#            biocore_memory : Amount of memory to request (if 
#                required by account)
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 Connection error (couldn't connect to remote resource)
#  -3 Required parameters missing
#  -4 Bad project id or name
#  -5 Bad account id
proc ::ExecTool::remjob_config_account_biocore { job_id acct_params } {
  variable job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {  
    # First, just try using the session id file
    set res -1

    if { [ set res  [ ::biocore::initDefault exectool[package versions exectool]/[package versions biocore]] ] != "" } {
      puts "exectool) exectool::remjob_config_account_biocore: $res"
    }

    # Check what happened and get the user id
    if [catch {set user_id [::biocore::verify ]} errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "exectool) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return -2
    }

    if { $user_id <= 0 } {
      return -2
    } else {
      if {[catch {set userName \
                  [::biocore::getUserName $::biocore::userId] } errmsg ]} {
        # if we make it in here, we had an error thrown
        global errorInfo errorCode
        puts "exectool) biocore_checkLogin Error: <$errmsg> <$errorInfo> <$errorCode>"
      }
    }

    set job(biocore_userId) "$user_id"
    set job(biocore_userName) "$userName"

    # Turn the parameters back into an array
    array set params $acct_params
    
    # Get the required parameters for this job/account type
    # Need to get the account id in order to get the parameters
    if { ![info exists params(biocore_accountId)] } {
      # If account_id wasn't specified, prompt the user
      # I'm not checking for account validity here, but it wouldn't be
      # hard to add.
      puts "exectool) Selecting account"
      set done 0
      while { !$done } {
        set acct [ ::ExecTool::remjob_biocore_selectacct $job_id ]
        puts "exectool) Acct selected is $acct"
        if { $acct == -1 || $acct == -2 } {
          return $acct
        } else {
          set done 1
          set job(biocore_accountId) [lindex $acct 0]
        }
      }
    } else {
      set job(biocore_accountId) $params(biocore_accountId)
    }
    # Save the account info back into the permanent buffer
    lset job_info_buf $job_id [ array get job ]

    set required_params [ ::ExecTool::remjob_biocore_getRequiredJobParams \
      $job_id ]

    set missing 0
    foreach p $required_params {
      if { [info exists params($p)] } {
        puts "exectool) Getting param $p -- $params($p)"
        set job($p) $params($p)
      } else {
        puts "exectool) Couldn't get param $p"
        # We don't need certain parameters right now because they'll be set
        # later, or can be initialized to an empty string
        switch $p {
          biocore_projectId -
          biocore_jobDesc -
          biocore_workDir -
          biocore_cmd -
          biocore_cmdParams -
          biocore_projectToCharge -
          biocore_numProcs -
          biocore_cpuTime -
          biocore_memory -
          biocore_stdout -
          biocore_stderr -
          biocore_inputFiles -
          biocore_outputFiles { set job($p) "" }
          default {
            set missing 1
          }
        }
      }
    }
    if { $missing } {
      return -3
    }

    # Get the project list
    set projlist [ ::ExecTool::remjob_biocore_getprojects $job_id]
    if { $projlist == -1 || $projlist == -2 } {
      return $projlist
    }

    # Got the list, make it an array
    array set projects $projlist

    set projectId $job(biocore_projectId)
    #puts "Proj_id is -$projectId-"
    # If project id was unspecified, ask for it
    if { $projectId != {} } {
      # Id specified... See if its valid and use it
      if { [ info exists projects($projectId) ] } {
        set job(biocore_projectId) $projectId
      } else {
        #puts "ID -$projectId- specified, no match"
	return -4
      }
    } else {
      if { [ info exists job(biocore_projName) ] } {
        set proj_name $job(biocore_projName)
      } else {
        set proj_name {}
      }
        
      if { $proj_name != {} } {
        # Proj id not specified, but name was, so use it if its valid
	set ids [ array names projects ]
	set found 0
	foreach id $ids {
	  if {"$projects($id)" == "$proj_name" } {
	    #puts "Match found"
	    set job(biocore_projectId) $id
	    set found 1
	    break
	  }
	}
	if { !$found } {
	  #puts "Name $proj_name specified, not found"
	  return -4
	}
      } else {
        # Neither proj_name nor id was specified, prompt the user
        set done 0
        while { !$done } {
          set proj [ ::ExecTool::remjob_biocore_selectproj $job_id ]
          puts "exectool) Proj selected is $proj"
          if { $proj == -1 || $proj == -2 } {
            return $proj
          } else {
            if { $proj != -3 } {
	      set done 1
              set job(biocore_projectId) [lindex $proj 0]
	    }
          }
        }
      }
    }

    # save values so far, then initialize remaining fields
    lset job_info_buf $job_id [ array get job ]
    ::ExecTool::remjob_init_job_fields { $job_id }
  }

  return 0
}

proc ::ExecTool::remjob_init_job_fields { job_id } {
  variable job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  # The following tags are used by exectool, not biocore directly
  
  # Job-tag is a random number to reduce the chance of directory
  # naming collisions in file uploading. Note that code will still
  # work even if there is a collision, but it prevents the server
  # from complaining about the fact
  set job(biocore_jobTag) [expr round(1000 + 9000*rand())]
  set job(input_file_list) {}
  set job(output_file_list) {}
  # return values
  set job(biocore_jobId) -1
  set job(biocore_jobStatus) -1
  set job(file_retrieve_list) {}
  set job(file_transfer_list) {}    
  lset job_info_buf $job_id [ array get job ]
}

# remjob_config_input_file
# Add a file to the list of files that this job should send from the local
# machine to the remote machine
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   file Full path to the file on the local system
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 File not accessible
proc ::ExecTool::remjob_config_input_file { job_id file } {

  variable ::ExecTool::job_info_buf
  
  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { ![ file readable "$file" ] } {
    puts "exectool) File <$file> not readable"
    return -2
  }

  lappend job(input_file_list) "$file"

  lset job_info_buf $job_id [ array get job ]
  return 0;
}

# remjob_config_output_files
# Add a file name to the list of files we want to retrieve from the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   workdir Path to directory where files should be returned to
#   fname   File name on the remote system
#   size    Size estimate for file, to see if there's enough space
#           to store the file. Zero indicates that the client doesn't
#           wish to check for availble space. If there is insufficient space
#           the file will still be stored for future retrieval, in case
#           space later becomes available
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 File not writable
#  -3 Insufficient space
proc ::ExecTool::remjob_config_output_file { job_id workdir fname size} {
  variable ::ExecTool::job_info_buf

  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { ![ ::ExecTool::remjob_is_file_writable "$workdir" "$fname" ] } {
    return -2
  }

  set filespec [list "$fname" "$workdir" "$size" ]
  lappend job(output_file_list) $filespec

  # BioCoRE just wants the file names. They should be in the job work dir
  lappend job(biocore_outputFiles) "$fname"
  
  lset job_info_buf $job_id [ array get job ]
  return 0;
}

# remjob_config_stdout_file
# Add a file name to the list of files we want to retrieve from the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   workdir Path to directory where file should be returned to
#   fname   File name for stdout
#   size    Size estimate for file, to see if there's enough space
#           to store the file. Zero indicates that the client doesn't
#           wish to check for availble space. If there is insufficient space
#           the file will still be stored for future retrieval, in case
#           space later becomes available
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 File not writeable
#  -3 Insufficient space
proc ::ExecTool::remjob_config_stdout_file { job_id workdir fname size} {
  variable ::ExecTool::job_info_buf

  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { ![ ::ExecTool::remjob_is_file_writable "$workdir" "$fname" ] } {
    return -2
  }

  set filespec [list "$fname" "$workdir" "$size" ]
  lappend job(output_file_list) $filespec

  # Save the stdout file name separately
  set job(biocore_stdout) "$fname"
  
  lset job_info_buf $job_id [ array get job ]
  return 0;
}

# remjob_config_stderr_file
# Add a file name to the list of files we want to retrieve from the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   workdir Path to directory where file should be returned to
#   fname   File name for stderr
#   size    Size estimate for file, to see if there's enough space
#           to store the file. Zero indicates that the client doesn't
#           wish to check for availble space. If there is insufficient space
#           the file will still be stored for future retrieval, in case
#           space later becomes available
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 File not writeable
#  -3 Insufficient space
proc ::ExecTool::remjob_config_stderr_file { job_id workdir fname size} {
  variable ::ExecTool::job_info_buf

  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { ![ ::ExecTool::remjob_is_file_writable "$workdir" "$fname" ] } {
    return -2
  }

  set filespec [list "$fname" "$workdir" "$size" ]
  lappend job(output_file_list) $filespec

  # Save the stderr file name separately
  set job(biocore_stderr) "$fname"
  
  lset job_info_buf $job_id [ array get job ]
  return 0;
}

# remjob_config_validate
# For the given job id, check to see if it looks like all data is available
# to run the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 Connection error
#  -3 Something is unspecified
proc ::ExecTool::remjob_config_validate { job_id } {  
  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {  
    if [catch { ::biocore::verify } errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "exectool) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return -2
    }
  }

  return 0
}


# remjob_send_files
# Send files to the remote system
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Return:
#   0 Okay
#  -1 Unknown job id
#  -2 Connection error
#  -3 Transfer failed
proc ::ExecTool::remjob_send_files { job_id } {
  variable ::ExecTool::job_info_buf

  if { [ set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {  
    if [catch { ::biocore::verify } errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "exectool) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return -2
    }
        
    set i $::biocore::userId  
    set biocore_input_list {}
          
    # Create the work directory
    set jobName "$job(biocore_jobName)"
    set jobTag  "$job(biocore_jobTag)"
    set strDirPath "[biocore_createWorkDirectory "$jobName.$jobTag"]/"
    if { $strDirPath == "" } {
      return -3;
    }
          
    foreach f $job(input_file_list) {
      #puts "Uploading $f to $strDirPath"
      set fname "[file tail $f]"
      if {[catch { ::biocore::putBiofsFile "$strDirPath" \
                    "$f" "$fname" } errmsg]} {
        # if we make it in here, we had an error thrown
        global errorInfo errorCode
        puts "exectool) uploadBiofsFile Error: <$errmsg> <$errorInfo> <$errorCode>"
        return -3
      } else {
        lappend biocore_input_list "/Private/$jobName.$jobTag/$fname"
        #puts "File $f uploaded to $strDirPath"
      } ; # end the else on not having an error in the API request
    }
    set job(biocore_inputFiles) $biocore_input_list
  }

  lset job_info_buf $job_id [ array get job ]
  return 0
}

# biocore_createWorkDirectory
# Private function to set up a directory on BioCoRE for the input files
proc ::ExecTool::biocore_createWorkDirectory { dirName } {
  set strPath /Private/
  set strNewName "$dirName"

# The isBiofsDirectory call is not yet implemented because some code
# it depends on is broken. But when it works, we should uncomment this
# code to deal with directory name collisions more robustly than just
# catching the error (as is currently done in the if {[catch...]}
#   puts "Path=$strPath"
#   puts "Name=$jobName"
#   puts [ set dir_exists \
#     [::biocore::isBiofsDirectory "$strPath" "$strNewName"]]
#   if { $dir_exists} {
#     puts "Directory already exists"
#     return $strPath$strNewName
#   }
#   puts "Creating work dir $strPath $strNewName"

  if {[catch {::biocore::createBiofsDirectory "$strPath" "$strNewName"} \
       errmsg]} {
    # if we make it in here, we had an error thrown
    global errorInfo errorCode
    if { ![regexp "BioFsExistsException" "$errmsg"] } {
      # If the error was just that the dir already exists, ignore it,
      # otherwise complain
      puts "exectool) createBiofsDirectory Error: <$errmsg> <$errorInfo> <$errorCode>"
      return ""
    } else {
      puts "exectool) Directory not created - already exists?"
    }
  }
#  puts "Created $strPath$strNewName"
  return "$strPath$strNewName"
}

# remjob_run
# Starts the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   0 Job started
#  -1 Unknown job id
#  -2 Connection error
#  -3 Couldn't start job
proc ::ExecTool::remjob_run { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {  
    if [catch { ::biocore::verify } errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "exectool) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return -2
    }

    set jobType "$job(biocore_type)"

    # If any fields aren't set, set them to empty strings
    set fields { biocore_accountId biocore_projectId biocore_jobName \
      biocore_jobDesc biocore_workDir biocore_cmd \
      biocore_cmdParams biocore_stdout biocore_stderr biocore_queueName \
      biocore_projectToCharge biocore_numProcs biocore_cpuTime biocore_memory \
      biocore_inputFiles biocore_outputFiles }

    foreach field $fields {
      if { ![info exists job($field)] } {
        set job($field) ""
      }
    }
    
    if {[catch {set result [::biocore::runJob \
                             "$jobType" \
                             "$job(biocore_accountId)" \
                             "$job(biocore_projectId)" \
                             "$job(biocore_jobName)" \
                             "$job(biocore_jobDesc)" \
                             "$job(biocore_workDir)" \
                             "$job(biocore_cmd)" \
                             "$job(biocore_cmdParams)" \
                             "$job(biocore_stdout)" \
                             "$job(biocore_stderr)" \
                             "$job(biocore_queueName)" \
                             "$job(biocore_projectToCharge)" \
                             "$job(biocore_numProcs)" \
                             "$job(biocore_cpuTime)" \
                             "$job(biocore_memory)" \
                             "$job(biocore_inputFiles)" \
                             "$job(biocore_outputFiles)" ] } errmsg]} {
       # if we make it in here, we had an error thrown
       global errorInfo errorCode
       puts "exectool) submitJob Error: <$errmsg> <$errorInfo> <$errorCode>"
       return -3
    }
    set job(biocore_jobId) $result
  }

  lset job_info_buf $job_id [ array get job ]
  return 0
}

# remjob_get_file
# Initiate (and possibly completes) getting the files currently provided
# by _config_output_file
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   0 File valid
#  -1 Unknown job id
#  -2 File not in output list
#  -3 File not writable
proc ::ExecTool::remjob_get_file { job_id fname } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  # Check to make sure file is in the output list
  set found 0
  foreach f "$job(output_file_list)" {
    if { "[lindex $f 0]" == "$fname" } {
      set found 1
      set filespec "$f"
      # Make sure file is still writable
      if { ![::ExecTool::remjob_is_file_writable \
        "[ lindex $f 1 ]" "[ lindex $f 0 ]" ] } {
        return -3
      }
      break
    }
  }
  if { !$found } {
    return -2
  } 

  # Add the file to the get_file list
  lappend job(file_retrieve_list) "$filespec"
  
  lset job_info_buf $job_id [ array get job ]
  return 0
}

# remjob_start_transfer
# Initiate (and possibly completes) getting the files currently provided
# by _config_output_file
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   >= 0 Transfer handle
#  -1 Unknown job id
#  -2 Connection error
proc ::ExecTool::remjob_start_transfer { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  # Transfer retrieve_list to transfer_list
  # Structure of transfer list: { { list } status }
  set transfer_handle [ llength $job(file_transfer_list) ]

  if { [llength $job(file_retrieve_list)] == 0 } {
    # Nothing to transfer!
    set transfer_spec [ list {} "1" ]
    lappend job(file_transfer_list) "$transfer_spec"
  } else {
    set transfer_spec [ list $job(file_retrieve_list) "0" ]
    set job(file_retrieve_list) {}
    lappend job(file_transfer_list) "$transfer_spec"
  
    if { $job(type) == "biocore" } {
      # For BioCoRE, just transfer the files now
      # transfer the files
      foreach f [ lindex $transfer_spec 0 ] {
        set projname [ ::ExecTool::remjob_biocore_get_projname $job_id ]
	if { $projname == -1 || $projname == -2 } {
	  return $projname
	}

        set username "$job(biocore_userName)"
        set jobname "$job(biocore_jobName)"
        set biocorejid "$job(biocore_jobId)"

        set biocore_dir \
          "/$projname/.ServerFiles/Jobs/$username/$jobname.$biocorejid"
        set fname "[lindex $f 0]"
        set wd "[lindex $f 1]"
        set local_name "[ file join $wd $fname ]"
        set remote_name "$biocore_dir/$fname"
        if {[catch {::biocore::getBiofsFile "$remote_name" "$local_name"} \
          errmsg]} {
          # if we make it in here, we had an error thrown
          global errorInfo errorCode
          puts "exectool) getBiofsFile Error: <$errmsg> <$errorInfo> <$errorCode>"
          # Set an error condition for the transfer
          lset transfer_spec 0 "-3"
          return -2
        }
      }
      # Got here... Success
      lset transfer_spec 1 "1" 
      lset job(file_transfer_list) $transfer_handle "$transfer_spec"
    }
  }
  # Save the job info, since we might have changed the status
  lset job_info_buf $job_id [ array get job ]
  return $transfer_handle
}

# remjob_waitfor_transfer
# Returns 1 when the specified file transfer completes
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
#   transfer_handle Handle to this transfer
# Returns
#   1 Transfer complete
#   0 Transfer incomplete
#  -1 Unknown job id
#  -2 Unknown transfer handle
#  -3 Transfer error
proc ::ExecTool::remjob_waitfor_transfer { job_id transfer_handle } {
  # Check whether job_id is valid
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { $transfer_handle < 0 || \
    $transfer_handle >= [llength $job(file_transfer_list) ] } {
    return -2
  }
  
  return [ lindex [lindex $job(file_transfer_list) $transfer_handle] 1 ]
}

# remjob_kill
# Attempt to kill the job
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   0 Job killed
#  -1 Unknown job id
#  -2 Couldn't kill job
proc ::ExecTool::remjob_kill { job_id } {
  # Eventually, we'll do something on the server here
  return -2
}

# remjob_poll
# Return the job status, which can be checked by _isComplete{} etc.
# Parameters
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#  a list  Status retrieved (first field, job type, subsequent fields,
#          type-specific)
#  -1  Unknown job id
#  -2  Communication error
proc ::ExecTool::remjob_poll { job_id } {
  variable ::ExecTool::job_info_buf

  # Check whether job_id is valid
  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl
  
  if { $job(type) == "biocore" } {
    set jobstat -1
    set biocore_job_id $job(biocore_jobId)
    if {[catch {set jobstat [ ::biocore::getJobStatus $biocore_job_id] } \
         errmsg ]} {
       # if we make it in here, we had an error thrown
       global errorInfo errorCode
       puts "exectool) submitJob Error: <$errmsg> <$errorInfo> <$errorCode>"
       return -2
    }
  }
  set job(biocore_jobStatus) "$jobstat"
  # Save the job info, since we might have changed the status
  lset job_info_buf $job_id [ array get job ]
  return [list "biocore" "$jobstat" ]
}

# remjob_isComplete
# Checks the job status returned by previous call to remjob_poll
# Parameters
#   status Status returned by remjob_poll
# Returns
#   1 Job is complete
#   0 Job not complete
proc ::ExecTool::remjob_isComplete { status } {
  set type [lindex $status 0]
  if { $type == "biocore" } {
    set val [lindex $status 1]
    return [expr $val == "4"]
  }
  return 0
}

# remjob_isRunning
# Checks the job status returned by previous call to remjob_poll
# Parameters
#   status Status returned by remjob_poll
# Returns
#   1 Job is running
#   0 Job not running
proc ::ExecTool::remjob_isRunning { status } {
  set type [lindex $status 0]
  if { $type == "biocore" } {
    set val [lindex $status 1]
    return [expr $val == "3" || $val == "10" ]
  }
  return 0
}

# remjob_isSubmitted
# Checks the job status returned by previous call to remjob_poll
# Parameters
#   status Status returned by remjob_poll
# Returns
#   1 Job is submitted
#   0 Job not submitted
proc ::ExecTool::remjob_isSubmitted { status } {
  set type [lindex $status 0]
  if { $type == "biocore" } {
    set val [lindex $status 1]
    return [expr $val == "2"]
  }
  return 0
}

# remjob_cleanup
# Tell the job to clean up any temp files that it created.
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   0 Cleanup done
#  -1 Unknown job id
#  -2 Couldn't clean up
proc ::ExecTool::remjob_cleanup { job_id } {
  # We should probably do something on the server here, but for now,
  # nothing
  return 0
}

# remjob_delete
# Get rid of references to the job
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   0 Job deleted
#  -1 Unknown job id
#  -2 Couldn't delete job
proc ::ExecTool::remjob_delete { job_id } {
  variable ::ExecTool::job_info_buf

  if { [::ExecTool::remjob_get_jobinfo $job_id] == -1 } {
    return -1
  } else {
    # We should probably do something on the server here
    # Remove it from the job buf, replace it with an empty list
    lset job_info_buf $job_id {}
    return 0
  }
}

# Private remjob_get_jobinfo
# Gets the job info structure for a particular job id
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   -1 Job id invalid
proc ::ExecTool::remjob_get_jobinfo { job_id } {
  variable ::ExecTool::job_info_buf

  set count [llength $job_info_buf ]
  if { $job_id < 0 || $job_id >= $count } {
    return -1
  } else {
    if { [set job_info [lindex $job_info_buf $job_id]] == {} } {
      return -1
    } else {
      return $job_info
    }
  }
}

# remjob_set_default_projname
# A convenience function to allow a user to store the default 
# biocore project name for job submission
proc ::ExecTool::remjob_set_default_biocore_projname { projname } {
  set ::ExecTool::biocore_default_projname $projname
  return
}

# remjob_set_default_acctname
# A convenience function to allow a user to store the default 
# biocore project name for job submission
proc ::ExecTool::remjob_set_default_biocore_acctname { acctname } {
  set ::ExecTool::biocore_default_acctname $acctname
  return
}

# Private remjob_biocore_getprojects
# Gets the job info structure for a particular job id
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   project array: a list suitable for array set 
#   -1 Job id invalid
#   -2 Connection error
proc ::ExecTool::remjob_biocore_getprojects { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  # get the projectlist and print it
  if {[catch { set projectList [::biocore::getProjectList] } errmsg]} {
    # if we make it in here, we had an error thrown
    global errorInfo errorCode
    puts "exectool) getProjectList Error: <$errmsg> <$errorInfo> <$errorCode>"
    return -2
  } else {
    array set proj_name {}
    foreach { name id } $projectList {
      set proj_name($id) "$name"
    }
  }
  return [ array get proj_name ]
}

# Private remjob_interactive_login
# Print a warning dialog to let the user log in, keep trying until the user
# logs in or does cancel
# Returns
#   0: gave up
#   1: logged in
proc ::ExecTool::remjob_interactive_login {} {
  variable remjob_interactive_loggedin
  
  set result [tk_dialog .exectoolerr "BioCoRE Connection Problem" \
    "Connection to BioCoRE failed. Try logging in, then run job again" \
    error 0 "Login" "Cancel" ]

  if { $result == 0 } {
    # First, draw a retry dialog
    set w [toplevel .exectool_login]
    wm title $w "BioCoRE Connection Problem"
    
    set noVerify [frame $w.noVerify]
    pack [label $noVerify.text -text \
          "\nYou need to log in to BioCoRE to run a job.\n" ]
    frame $noVerify.buttonframe
    button $noVerify.buttonframe.retryButton -bg lightgrey \
      -command { \
         set ::ExecTool::remjob_interactive_loggedin "Retry" \
      } -text "Check again" 

    button $noVerify.buttonframe.loginButton -bg lightgrey \
      -command { \
         wm deiconify [biocorelogin_tk_cb] \
      } -text "Open login window"
        
    button $noVerify.buttonframe.cancelButton -bg lightgrey \
      -command { \
         set ::ExecTool::remjob_interactive_loggedin "Cancel" \
      } -text "Cancel"
      
    pack $noVerify.buttonframe.retryButton \
      $noVerify.buttonframe.loginButton \
      $noVerify.buttonframe.cancelButton -side left
    pack $noVerify.text -side top -fill both
    pack $noVerify.buttonframe -side bottom
    pack $noVerify
    
    # now, open the biocore login window
    set loginwindow [biocorelogin_tk_cb] 
    wm deiconify $loginwindow
    
    # Now wait for the variable to be set
    while { 1 } {
      vwait ::ExecTool::remjob_interactive_loggedin
    
      # Once its set, figure out what to do
      if { $remjob_interactive_loggedin == "Retry" } {
        if { [catch { set res  [ ::biocore::initDefault exectool[package versions exectool]/[package versions biocore]] } errmsg ]} {
          # if we make it in here, we aren't logged in
          global errorInfo errorCode
          tk_dialog .exectoolerr "BioCoRE Connection Problem" \
            "Still not able to connect to BioCoRE" \
            error 0 "Okay"
        } else {
          # Did log in!
          after idle { destroy .exectool_login }
          return 1
        }
      } elseif { $remjob_interactive_loggedin == "Cancel" } {
        # Gave up 
        after idle { destroy .exectool_login }
        return 0
      }
    }
  } else {
    # Gave up
    return 0
  }
}

# Private remjob_biocore_selectproj
# Let the user select which project to use
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   project: { id name } of selected project
#   -1 Job id invalid
#   -2 Connection error
#   -3 Invalid project
proc ::ExecTool::remjob_biocore_selectproj { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {
    set proj_list [::ExecTool::remjob_biocore_getprojects $job_id ]
    if { $proj_list == -1 || $proj_list == -2 } {
      return $proj_list
    } else {
      array set proj_names $proj_list
    }
    # we got a response.  We need to print it out
    puts "exectool)  Id   Project"
    puts "exectool) ----  -------"
    set ids [lsort -integer [ array names proj_names ]]
    foreach { id } $ids {
      puts "exectool) [format %3i $id]   $proj_names($id)"
    }

    puts "exectool) Select a project id:"
    gets stdin proj_id
    if { [info exists proj_names($proj_id)] } {
      set proj_selected [list $proj_id "$proj_names($proj_id)" ]
      puts "exectool) Selected $proj_id $proj_names($proj_id):$proj_selected"
      return $proj_selected
    } else {
      return -3
    }
  }
  return -2
}

# Private remjob_biocore_getprojname
# Gets the project name for this project. The id is stored in the job
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   project array: a list suitable for array set 
#   -1 Job id invalid
#   -2 Connection error
proc ::ExecTool::remjob_biocore_get_projname { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  set projlist [ ::ExecTool::remjob_biocore_getprojects $job_id ]
  if { $projlist == -1 || $projlist == -2 } {
    return $projlist
  } else {
    array set projects $projlist
    return $projects($job(biocore_projectId))
  }
}

# Private remjob_biocore_getaccounts
# Gets the job info structure for a particular job id
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   accoutn: { id name } of account user selected
#   -1 Job id invalid
#   -2 Connection error
proc ::ExecTool::remjob_biocore_getaccounts { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  set biocore_job_type "$job(biocore_type)"
  if {[catch {set acctList [::biocore::getAccountsForJob \
        $biocore_job_type ]} errmsg]} {
    # if we make it in here, we had an error thrown
    # This shouldn't ever happen
    global errorInfo errorCode
    if { $errmsg == "No accounts" } {
      return {}
    }
    puts "exectool) getAccountsForJob Error: <$errmsg> <$errorInfo> <$errorCode>"
    return -2
  } else {
    array set accounts {}
    foreach { account } $acctList {
      set acct_id "[lindex $account 0]"
      set acct_name "[lindex $account 1]"
      set accounts($acct_id) "$acct_name"
    }
  }
  return [ array get accounts ]
}

# Private remjob_biocore_selectacct
# Gets the job info structure for a particular job id
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   accoutn: { id name } of account user selected
#   -1 Job id invalid
#   -2 Connection error
#   -3 Invalid account
proc ::ExecTool::remjob_biocore_selectacct { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  if { $job(type) == "biocore" } {  
    set acct_list [::ExecTool::remjob_biocore_getaccounts $job_id ]
    if { $acct_list == -1 || $acct_list == -2 } {
      return $acct_list
    } else {
      array set accounts $acct_list
    }
    puts "exectool)  Id   Name"
    puts "exectool) ----  -------"
    set ids [lsort -integer [ array names accounts ]]
    foreach { id } $ids {
      puts "exectool) [format %3i $id]   $accounts($id)"
    }
    puts "exectool) -------------"

    puts "exectool) Select an account id:"
    gets stdin acct_id
    if { [info exists accounts($acct_id)] } {
      puts "exectool) Selected $acct_id $accounts($acct_id)"
      return [ list $acct_id "$accounts($acct_id)" ]
    } else {
      return -3
    }
  }
  return -2
}

# Private remjob_is_file_writable
# Given a directory and a file, determine whether the file can be written.
# If the file already exists, see if we can write to it. This will probably
# result in the file getting overwritten. If the file doesn't exist, see if
# we can create a file in that directory with that 
#
#   dirname Directory
#   filename file
# Returns
#   1 writeable
#   0 not writeable
proc ::ExecTool::remjob_is_file_writable { dirname filename } {
  if {![file exists "$dirname" ] || ![file isdirectory "$dirname"] } {
    return 0
  }
  # directory exists and is a directory. See if file exists
  set fullpath "[ file join "$dirname" "$filename" ]"
  if { ![ file exists "$fullpath" ] } {
    # File doesn't exist, see if directory is writable
    if { [ file writable "$dirname" ] } {
      #puts "$fullpath doesn't exist, but directory is writable, so we're good"
      return 1
    }
  }

  if { ![ file isfile "$fullpath" ]} {
    # if its not a plain file, we'll return 0
    #puts "$fullpath is not a regular file"
    return 0
  } else {
    # File exists, and is a regular file, so if its writeable, we're done
    if { [ file writable "$fullpath" ] } {
      #puts "$fullpath is a regular file and writable"
      return 1
    }
  }

  return 0
}

# Private remjob_biocore_getRequiredJobParams
# Gets the job info structure for a particular job id
#   job_id Handle to job (returned by remjob_create_job)
# Returns
#   account: { id name } of account user selected
#   -1 Job id invalid
#   -2 Connection error
proc ::ExecTool::remjob_biocore_getRequiredJobParams { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  set biocore_job_type "$job(biocore_type)"
  set biocore_accountId "$job(biocore_accountId)"
  if {[catch {set paramList [::biocore::getRequiredJobParameters \
        $biocore_accountId $biocore_job_type]} errmsg]} {
    # if we make it in here, we had an error thrown
    # This shouldn't ever happen
    global errorInfo errorCode
    puts "exectool) getRequiredJobParams Error: <$errmsg> <$errorInfo> <$errorCode>"
    return -2
  }
  set returnList {}
  foreach param $paramList {
    lappend returnList "biocore_$param"
  }
  return $returnList
}

# Private remjob_biocore_getQueuesForAccount
# Gets the job info structure for a particular job id
#   account_id User's account id
# Returns
#   account: { id name } of account user selected
#   -1 Job id invalid
#   -2 Connection error
proc ::ExecTool::remjob_biocore_getQueuesForAccount { job_id } {
  variable ::ExecTool::job_info_buf

  if { [set jobl [::ExecTool::remjob_get_jobinfo $job_id]] == -1 } {
    return -1
  }
  array set job $jobl

  set biocore_acct_id "$job(biocore_accountId)"
  if {[catch {set paramList [::biocore::getQueuesForAccount \
        $biocore_acct_id ]} errmsg]} {
    # if we make it in here, we had an error thrown
    # This shouldn't ever happen
    global errorInfo errorCode
    puts "exectool) getQueuesForAccount Error: <$errmsg> <$errorInfo> <$errorCode>"
    return -2
  }
  return $paramList
}

# Private remjob_biocore_error_dialog
# Convenience function for displaying a dialog box when some internal
# error occurs
proc ::ExecTool::remjob_biocore_error_dialog { msg { url {} } } {
  if { $url == {} } {
    set ret [tk_dialog .biocore_err "BioCoRE Error" \
      "BioCoRE error detected: \n$msg" \
      error 0 "Okay" ]
  } else {
    set ret [tk_dialog .biocore_err "BioCoRE Error" \
      "BioCoRE error detected: \n$msg" \
      error 0 "Help" "Okay" ]
    }
    if { $ret == 0 } {
      vmd_open_url $url
    }
  }
  return
}
