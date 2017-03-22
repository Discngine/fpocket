## APBS Run 1.2
##
## GUI plugin for APBS. More info on APBS can be found at
## <http://agave.wustl.edu/apbs/>
##
## Authors: Eamon Caddigan, John Stone, Robert Brunner, Axel Kohlmeyer
##          vmd@ks.uiuc.edu
##
## $Id: apbsrun.tcl,v 1.135 2007/08/29 16:48:00 johns Exp $
##
## TODO:
## * Load charges and radii from ff-parameter files better.
## * User-defined ff-parameter file location.
## * Specify which molecule maps should be loaded into upon completion.
## * Real modal dialogs -- stop stealing focus from other VMD plugins.
## * In main window, display descriptive names for ELEC statements (e.g.,
##   molecule and calculation type) instead of simply displaying their
##   indecies.
## * Kill APBS on windows.
## * User-defined map names for write statements (also prevent clobbering).
## * GUI elements for counterion declarations, calcenergy, calcforce, 
##   writemat, usemap.
## * Display new molecules in drop-down menus immediately after loading them.
## * Progress bar during run (by parsing io.mc?).
## * New defaults.

## Tell Tcl that we're a package and any dependencies we may have
package require Tcl 8.4
package require exectool 1.2
package provide apbsrun 1.3

namespace eval ::APBSRun:: {
  namespace export apbsrun

  # window handles
  variable main_win      ;# handle to main window
  variable elec_win      ;# handle to elec-statement editing window 
  variable settings_win  ;# handle to settings window
  variable map_win       ;# handle to map-loading window
  variable edition_win   ;# handle to ion editing window

  # global settings
  variable elec_listbox  ;# the listbox displaying the elec statements
  variable elec_list     ;# a list containing the elements of elec_listbox
  variable elec_index    ;# next unused index for new elec_listbox elements
  variable elec_current_index ;# elec item being edited
  variable apbs_status   ;# status of the current apbs run
  variable apbs_button   ;# text of the APBS Button
  variable apbs_type     ;# type of apbs run
  variable apbs_fd       ;# file handle of running APBS process


  # Default and user-edited apbs input information, stored as a hash with
  # each key representing a "type" and each element consisting of a list
  # of elec settings, where each elec setting is a list containing pairs of
  # elements (for setting with 'array set')
  variable default_apbs_config
  variable current_apbs_config

  variable elec_temp

  # APBSRun Configuration variables
  variable workdir
  variable workdirsuffix
  variable apbsbin
  variable setup_only
  variable use_dat_radii
  variable use_dat_charges
  variable datfile

  variable apbs_input
  variable ff_radii
  variable ff_charges
  variable pqrfiles
  variable elec_keyword
  variable molids
  variable output_files
  variable load_files
  variable load_files_dest_mol    1

  # ion editor temporary vars
  variable use_ions  1
  variable ionconc   0.150
  variable ionrad    2.0

  # where to run the job
  variable apbs_job_type  "local"

  # some vars used for running remote jobs and accessing BioCoRE
  variable remjob_id -1
  variable remjob_outfiles
  variable remjob_abort

  proc ff_parameter_init {} {
    variable datfile
    variable ff_radii
    variable ff_charges
  
    set datfile [file join $::env(APBSRUNDIR) radii.dat]
    if { ![file exists $datfile] || [catch {set file [open $datfile]}] } {
      puts "apbsrun) warning, can't find parameter file"
      set datfile {}
    } else {
      # Load the radii and charges
      while {-1 != [gets $file line]} {
        if {![regexp {\s*#} $line]} {
          set line [split $line \t]
          set ff_radii([lindex $line 0],[lindex $line 1]) [lindex $line 3]
          set ff_charges([lindex $line 0],[lindex $line 1]) [lindex $line 2]
        }
      }
      close $file
    }
  }

  ##
  ## read parameters immediately during package load, so they are made
  ## available for access by other plugins.
  ##
  ## XXX this is a hack, and the code should probably be migrated out
  ## of apbsrun altogether now that other plugins want to use it.
  ##
  ff_parameter_init
}

##
## Initialize the values, then launch the main window
##
proc ::APBSRun::apbsrun {} {
  variable apbs_status
  variable apbs_button
  variable apbs_type
  variable workdir
  variable workdirsuffix
  variable apbsbin
  variable setup_only
  variable use_dat_radii
  variable use_dat_charges
  variable file_list
  global env

  if [info exists env(TMPDIR)] {
    set workdir $env(TMPDIR)
  } else {
    switch [vmdinfo arch] {
      WIN64 -
      WIN32 {
        set workdir "c:/"
      }
      MACOSXX86 -
      MACOSX {
        set workdir "/"
      }
      default {
        set workdir "/tmp"
      }
    }
  }
  
  switch [vmdinfo arch] {
    WIN64 -
    WIN32 {
      set apbsbin [::ExecTool::find apbs.exe]
    }
    default {
      set apbsbin [::ExecTool::find apbs]
    }
  }

  set setup_only 0
  set use_dat_radii 0
  set use_dat_charges 0
  set apbs_status "Status: Ready"
  set apbs_button "Run APBS"

  # Maintain a list of VMD's molecules 
  ::APBSRun::update_file_list
  trace add variable ::vmd_initialize_structure write \
    ::APBSRun::update_file_list

  # Set the default for all types
  trace remove variable ::APBSRun::apbs_type write \
    ::APBSRun::update_elec_list
  set apbs_type {}
  ::APBSRun::set_default 

  # Update the elec list every time the type is changed
  trace add variable ::APBSRun::apbs_type write \
    ::APBSRun::update_elec_list

  # Launch the main window
  ::APBSRun::apbs_mainwin
}


# Update the list of elec statements, to reflect the current type of APBS
# run
proc ::APBSRun::update_elec_list {args} {
  variable elec_list
  variable elec_index
  variable current_apbs_config
  variable apbs_type

  set elec_list {}
  for {set i 0} {$i < [llength $current_apbs_config($apbs_type)]} {incr i} {
    if {[lindex $::APBSRun::current_apbs_config($apbs_type) $i] != {}} {
      lappend elec_list $i
    }
  }
  set elec_index $i
}

proc ::APBSRun::update_file_list {args} {
  variable file_list

  set file_list {}

  # Append each loaded molecule to the list of files
  # XXX - Omitting molecules without atoms or coordinates would be
  # preferable, but the vmd_initialize_structure variable is only written
  # when a new molecule is created, so there's no way to know what other
  # information will be loaded into a molecule later
  foreach molid [molinfo list] {
    lappend file_list [concat $molid [molinfo $molid get name]]
  }

  # If there are no valid molecules loaded, add an empty item to the list
  if { [llength $file_list] == 0 } {
    lappend file_list {}
  }
}


##
## Create the main window
##
proc ::APBSRun::apbs_mainwin {} {
  variable main_win
  variable elec_listbox
  variable elec_list
  variable elec_index

  # If already initialized, just turn on
  if { [winfo exists .apbsrun] } {
    wm deiconify $main_win
    return
  }

  set main_win [toplevel ".apbsrun"]
  wm title $main_win "APBS Tool" 
  wm resizable $main_win yes yes

  ## make the menu bar
  frame $main_win.menubar -relief raised -bd 2 ;# frame for menubar
  pack $main_win.menubar -padx 1 -fill x -side top

  menubutton $main_win.menubar.edit -text "Edit" -underline 0 \
    -menu $main_win.menubar.edit.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $main_win.menubar.edit config -width 5
  pack $main_win.menubar.edit -side left

  menubutton $main_win.menubar.help -text "Help" -underline 0 \
    -menu $main_win.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $main_win.menubar.help config -width 5
  pack $main_win.menubar.help -side right

  ## edit menu
  menu $main_win.menubar.edit.menu -tearoff no
  $main_win.menubar.edit.menu add command -label "Settings..." \
    -command ::APBSRun::apbs_settings

  ## help menu
  menu $main_win.menubar.help.menu -tearoff no
  $main_win.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About apbsrun" \
              -message "GUI for initiating APBS runs."}
  $main_win.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/apbsrun"

  ## Main window
  frame $main_win.edit
  tk_optionMenu $main_win.edit.type ::APBSRun::apbs_type \
    "Electrostatic Potential" "Solvent Accessibility" "Custom"
  $main_win.edit.type config -width 25
  pack $main_win.edit.type -fill x -expand yes
  button $main_win.edit.button -text "Default" -width 8 \
    -command ::APBSRun::set_default
  pack $main_win.edit.type $main_win.edit.button \
    -side left -anchor w -fill x
  pack $main_win.edit \
    -side top -anchor w -padx 10 -pady 10

  frame $main_win.list
  pack [label $main_win.list.label -anchor w \
    -text "Individual PB calculations (ELEC):"] -side top -anchor w
  set elec_listbox [listbox $main_win.list.names \
    -yscrollcommand {$::APBSRun::main_win.list.scroll set} \
    -listvariable ::APBSRun::elec_list -relief sunken -bd 2 -height 5]
  pack [scrollbar $main_win.list.scroll \
    -command {$::APBSRun::main_win.list.names yview}] -side right -fill y
  pack $main_win.list.names \
    -side top -anchor w -fill both -expand yes
  pack $main_win.list \
    -side top -anchor w -fill both -expand yes -padx 10 -pady 10

  frame $main_win.elec_buttons
  button $main_win.elec_buttons.add -text "Add" -width 8 \
    -command ::APBSRun::elec_add
  button $main_win.elec_buttons.edit -text "Edit" -width 8 \
    -command ::APBSRun::elec_edit
  button $main_win.elec_buttons.del -text "Delete" -width 8 \
    -command ::APBSRun::elec_del
  pack $main_win.elec_buttons.add $main_win.elec_buttons.edit \
    $main_win.elec_buttons.del \
    -side left
  pack $main_win.elec_buttons \
    -side top -anchor w -padx 10 -pady 10
  
  frame $main_win.apbs
  label $main_win.apbs.status -textvar ::APBSRun::apbs_status
  frame $main_win.apbs.buttons
  button $main_win.apbs.buttons.run -textvar ::APBSRun::apbs_button \
    -width 10 -command ::APBSRun::apbs_start

  frame $main_win.apbs.buttons.jobloc
  radiobutton $main_win.apbs.buttons.jobloc.uselocal \
    -text "Run job locally"  -value "local" \
    -variable ::APBSRun::apbs_job_type

  radiobutton $main_win.apbs.buttons.jobloc.usebiocore \
    -text "Run job remotely (BioCoRE)"  -value "biocore" \
    -variable ::APBSRun::apbs_job_type

  pack $main_win.apbs.buttons.jobloc.uselocal \
       $main_win.apbs.buttons.jobloc.usebiocore \
       -side top -anchor w

  pack $main_win.apbs.buttons.run $main_win.apbs.buttons.jobloc -side left 

  pack $main_win.apbs.status $main_win.apbs.buttons \
    -side top -anchor w
  pack $main_win.apbs \
    -side top -anchor w -padx 10 -pady 10
}

proc ::APBSRun::apbs_start {} {
  if { $APBSRun::apbs_job_type == "biocore" } {
    return [ ::APBSRun::apbs_setup biocore ]
  } elseif {$APBSRun::apbs_job_type == "local"} {
    return [ ::APBSRun::apbs_setup normal ]
  } else {
    tk_dialog .errmsg {APBS Tool Error} "Unsupported job type." error 0 Dismiss
  }
}

# Validate values, set up the files for APBS, and run it
proc ::APBSRun::apbs_setup { mode } {
  variable apbs_status
  variable apbs_button
  variable apbs_fd
  variable current_apbs_config
  variable selected_apbs_config 
  variable apbs_type
  variable elec_temp
  variable workdir
  variable workdirsuffix
  variable apbs_input
  variable apbsbin
  variable setup_only
  variable pqrfiles
  variable molids

  
  # find a unique dir name for work files
  puts "apbsrun) Running job mode=$mode"
  
  set dirindx [expr int(rand() * 100000)]
  set workdirsuffix apbs.$dirindx
    while {[catch {close [open [file join $workdir $workdirsuffix] \
           {RDWR CREAT EXCL}]}]} {
    set dirindx [expr rand() * 100000]
    set workdirsuffix apbs.$dirindx
  }
  puts "apbsrun) dir is [file join $workdir $workdirsuffix]"
  # we reserved the name, but its not a dir. Delete it and remake it
  # Unfortunately, this is not atomic. I can't think of a way to make
  # it more robust
  file delete [file join $workdir $workdirsuffix]
  file mkdir [file join $workdir $workdirsuffix]

  if { $mode == "normal" } {
    # If APBS is running, do nothing
    if {[string equal $apbs_button "Stop APBS"]} {
      # Try to kill the process. 
      # XXX - this simply won't work on Windows without a seperate "kill"
      # program being installed, so fail gracefully.
      if { [catch {exec kill [pid $apbs_fd]} err] } {
        tk_dialog .errmsg {APBS Tool Error} "Cannot close APBS:\n $err" error 0 Dismiss
      }
      return
    }

    # Check that we have a valid location for apbs before proceeding
    if {$apbsbin == {} && !$setup_only} {
      # Prompt the user for its location
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set apbsbin [::ExecTool::find -interactive -path "c:/Program files/APBS/apbs.exe" -description "APBS" apbs.exe]
        }
        default {
          set apbsbin [::ExecTool::find -interactive apbs]
        }
      }
      if {$apbsbin == {}} {
        tk_dialog .errmsg {APBS Tool Error} "Please specify the location of the APBS binary in the Settings Menu" error 0 Dismiss
        return
      }
    }
  }

  set pqrfiles {}

  # Copy the data (a list of elec statements) into selected_apbs_config
  set selected_apbs_config $current_apbs_config($apbs_type)

  # XXX - this implementation won't work when the user wants to use the same
  # molecule with more than one unique selection in different elec
  # statements

  # Create a list of all molecules used by the plugin
  array unset molids
  array unset selections
  set molid_list {}
  set mol_index 1
  for {set i 0} {$i < [llength $selected_apbs_config]} {incr i} {
    array set elec_temp [lindex $selected_apbs_config $i]

    # Check the elec statement for errors
    if { ![::APBSRun::elec_check elec_temp] } {
      puts "apbsrun) Exiting."
      return
    }

    set vmd_molid [string index $elec_temp(mol) 0]
    set vmd_cgcent_molid [string index $elec_temp(cgcent_mol) 0]
    set vmd_fgcent_molid [string index $elec_temp(fgcent_mol) 0]

    if {![info exists molids($vmd_molid)]} {
      set molids($vmd_molid) $mol_index
      lappend molid_list $vmd_molid
      set selections($vmd_molid) $elec_temp(atomsel)
      incr mol_index
    }

    if {[string equal $elec_temp(cgcent_method) "molid"] &&
        ![info exists molids($vmd_cgcent_molid)]} {
      set molids($vmd_cgcent_molid) $mol_index
      lappend molid_list $vmd_cgcent_molid
      incr mol_index
    }

    if {[string equal $elec_temp(fgcent_method) "molid"] &&
        ![info exists molids($vmd_fgcent_molid)]} {
      set molids($vmd_fgcent_molid) $mol_index
      lappend molid_list $vmd_fgcent_molid
      incr mol_index
    }
  }

  # Write a pqr file for each molecule referenced in the plugin
  foreach vmd_molid $molid_list {
    if {[info exists selections($vmd_molid)]} {
      set sel [atomselect $vmd_molid $selections($vmd_molid)]
    } else {
      set sel [atomselect $vmd_molid all]
    }
    set filename [file rootname [molinfo $vmd_molid get name]]
    set filename [file join $workdir $workdirsuffix "$filename.pqr"]
    lappend pqrfiles $filename

    set apbs_status "Status: Writing PQR file: $filename"
    if { [catch {::APBSRun::write_mol $sel $filename} err] } {
      tk_dialog .errmsg {APBS Tool Error} "Error writing PQR file $filename:\n$err" error 0 Dismiss
      set apbs_status "Status: Ready"
      return
    }

    $sel delete
  }

  if { $mode == "normal" } {
    set use_relative_files 1
  } else {
    set use_relative_files 0
  }
  # Write the APBS input file to dir
  set apbs_input [file join $workdir $workdirsuffix apbs.in]
  set apbs_status "Status: Writing APBS input file: $apbs_input"
  if { [catch {::APBSRun::write_input $apbs_input \
                 $use_relative_files } err] } {
    tk_dialog .errmsg {APBS Tool Error} "Error writing APBS input file $apbs_input:\n$err" error 0 Dismiss
    set apbs_status "Status: Ready"
    return
  }

  if { $mode == "normal" } {
    # Run apbs in the working directory
    if {! $setup_only} {
      set currentdir [pwd]
      cd [file join $workdir $workdirsuffix]
      set apbs_status "Status: Running APBS"
      set apbs_button "Stop APBS"
      ::APBSRun::apbs_run
      cd $currentdir
      puts "apbsrun) Output files $::APBSRun::output_files"
    } else {
      set apbs_status "Status: Ready"
      set apbs_button "Run APBS"
    }
  } else {
      set apbs_status "Status: Running on BioCoRE"
      ::APBSRun::apbs_run_biocore
  }
}

proc ::APBSRun::apbs_run_biocore {} {
  variable remjob_id
  
  set apbs_status "Status: Setting up job"
  if { $remjob_id == -1 } {
    set remjob_id [ ::ExecTool::remjob_create_job ]
  } else {
    set res [tk_dialog .biocore_err "Job already running" \
      "It looks like there's already a job running. Forget about old job?" \
      error 0 "Forget old job" "Keep waiting" ]
    if { $res == 0 } {
      biocore_job_cancelled $remjob_id
      puts "apbsrun) It looks like there was already a job running. I will ignore it."
    } else {
      puts "apbsrun) It looks like there's already a job running. To ignore it, run \"::APBSRun::biocore_job_cancelled $remjob_id\""
    }
    return
  }
  
  # check error code here
  set err [::ExecTool::remjob_config_prog $remjob_id "biocore" 1 ]
  if { $err < 0 } {
    puts "apbsrun) Error $err in remjob_config_prog"
    tk_dialog .biocore_err "BioCoRE Connection Problem" \
      "Connection to BioCoRE failed. Job cancelled" \
      error 0 "Ok"
    biocore_job_cancelled $remjob_id
    return
  }

  # Configure job
  set err [ ::APBSRun::biocore_config_run "::APBSRun::biocore_setup_files" \
    "::APBSRun::biocore_job_cancelled" ]
    
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "Error detected in biocore_config_run:\n$err" error 0 Dismiss
    puts "apbsrun) Error $err detected in biocore_config_run"
    biocore_job_cancelled $remjob_id
    set apbs_status "Status: Ready"
    return
  }
  # After the user clicks okay, jump to biocore_setup_files callback
}

proc ::APBSRun::biocore_setup_files { job_id } {
  variable workdir
  variable workdirsuffix
  variable output_files
  variable remjob_id
  variable remjob_outlist

  puts "apbsrun) staging input and output files"
  # Get the list of files from the work dir and send it
  # to my biocore /Private directory
  set local_dir [file join $workdir $workdirsuffix]
  set infiles [glob -dir $local_dir *]
  foreach f $infiles {
    set err [::ExecTool::remjob_config_input_file $remjob_id $f]
    if { $err != 0 } {
      tk_dialog .errmsg {APBS Tool Error} "config_input_file error\[$f\]: $err" error 0 Dismiss
      set apbs_status "Status: Ready"
      return
    }
  }

  # Config stdout and stderr
  set err [::ExecTool::remjob_config_stdout_file $remjob_id $local_dir \
      "apbs.out" 0]
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "config_stdout_file error: $err" error 0 Dismiss
    set apbs_status "Status: Ready"
    return
  }
  set err [::ExecTool::remjob_config_stderr_file $remjob_id $local_dir \
      "apbs.err" 0]
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "config_stderr_file error: $err" error 0 Dismiss
    set apbs_status "Status: Ready"
    return
  }
  
  # Build the list of files that need to be retrieved, then
  # exec the command. We'll use $workdirsuffix for the job name
  set remjob_outlist [ ::APBSRun::biocore_build_output_list $output_files ]

  # Make sure the job is set up correctly  
  set err [::ExecTool::remjob_config_validate $remjob_id ]
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "config_validate error: $err" error 0 Dismiss
    set apbs_status "Status: Ready"
    return
  }

  # Send the input files
  set apbs_status "Status: Sending input files"
  set err [::ExecTool::remjob_send_files $remjob_id]
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "send_files error: $err" error 0 Dismiss
    set apb_status "Status: Ready"
    return
  }
  
  # Start the job
  set apbs_status "Status: Starting job"
  set err [::ExecTool::remjob_run $remjob_id]
  if { $err != 0 } {
    tk_dialog .errmsg {APBS Tool Error} "remjob_run error: $err" error 0 Dismiss
    set apb_status "Status: Ready"
    return
  }
  
  # Install watcher for completion
  ::APBSRun::biocore_reschedule_status_check
}

proc ::APBSRun::biocore_config_run { run_cb cancelled_cb} {
  variable remjob_id
  variable remjob_abort
  variable workdirsuffix
  
  set remjob_abort 0 

  # Pack params in a list to preserve spaces
  set job(biocore_jobName) [ list $workdirsuffix ]
  set job(biocore_jobDesc) [ list "VMD APBS run" ]
  set job(biocore_workDir) [ list $workdirsuffix ]
  set job(biocore_cmd) "apbs"
  set job(biocore_cmdParams) [list "apbs.in" readonly]
  
  set err [::ExecTool::remjob_config_account $remjob_id \
    [array get job] $run_cb $cancelled_cb ]
  
  if { $err != 0 } {
    puts "apbsrun) biocore_config_run error $err"
  }
  
  return $err    
}

proc ::APBSRun::biocore_job_cancelled { job_id } {
  variable remjob_id
  variable apbs_status
  
  set apbs_status "Ready"
  set remjob_id -1
}

# The var output_files has the list of file types that must be returned
# but the .dx extension needs to be added
proc ::APBSRun::biocore_build_output_list { output_files } {
  variable remjob_id
  variable workdir
  variable workdirsuffix
  
  set retrieve_list { }
  foreach f $output_files {
    lappend retrieve_list "$f.dx"
  }
  lappend retrieve_list "io.mc"
  
  set local_dir [ file join $workdir $workdirsuffix ]
  foreach f $retrieve_list {
    set err [ ::ExecTool::remjob_config_output_file $remjob_id \
      $local_dir $f 0 ]
    if { $err != 0 } {
      puts "apbsrun) Config_output_file error \[$f\]: $err"
    }
  }
  
  return $retrieve_list
}

proc ::APBSRun::biocore_check_status {} {
  variable remjob_id
  
  set status [ ::ExecTool::remjob_poll $remjob_id ]
  if { $status == -1 || $status == -2 } {
    puts "apbsrun) Error retrieving status $status"
  }
  
  if { [ ::ExecTool::remjob_isComplete $status ] } {
    after idle { ::APBSRun::biocore_retrieve_files }
    return
  }

  if { !$::APBSRun::remjob_abort } {
    # Wait 5 seconds, then check again
    after 5000 { ::APBSRun::biocore_reschedule_status_check }
  } else {
    puts "apbsrun) APBSRun status check aborted"
    set remjob_id -1
  }
}

proc ::APBSRun::biocore_reschedule_status_check {} {
  # Only check if we are otherwise idle
  after idle { after 0 ::APBSRun::biocore_check_status }
}

proc ::APBSRun::biocore_retrieve_files {} {
  variable remjob_id
  variable remjob_outlist
  variable workdir
  variable workdirsuffix
  
  # Specify which files we want. Add stdout and err to list...
  set file_list [ concat $remjob_outlist "apbs.out" "apbs.err"]
  foreach f $file_list {
    set err [ ::ExecTool::remjob_get_file $remjob_id $f ]
    if { $err != 0 } {
      puts "apbsrun) Error retrieving $f: $err"
    }
  }
  
  # Actually go get the files
  set handle [ ::ExecTool::remjob_start_transfer $remjob_id ]
  if { $handle < 0 }  {
    puts "apbsrun) Error start_transfer: $handle"
  }
  
  # Wait for transfer to complete
  set file_status 0
  while { $file_status != 1 } {
    after 10000
    set file_status [ ::ExecTool::remjob_waitfor_transfer $remjob_id $handle ]
    if { $file_status < 0 } {
      puts "apbsrun) File transfer status: $file_status"
      break
    }
  }
  
  # HACK--- If we specified files that were not produced, we'll get back
  # zero-length files instead. So we'll scan through the files we got back
  # and delete them if they're empty
  set local_dir [ file join $workdir $workdirsuffix ]
  foreach f $file_list {
    set fpath [ file join $local_dir $f]
    if { [file size $fpath ] == 0 } {
      puts "apbsrun) Output file $fpath not retrieved"
      file delete $fpath
    }
  }
  
  # Finish up. Display the results menu
  set remjob_id -1
  ::APBSRun::apbs_stop biocore
  return
}

#
# Procs for running and stopping APBS. These can be overridden locally.
#
proc ::APBSRun::apbs_run {} {
  variable apbsbin
  variable apbs_input
  variable apbs_fd

  # cope with filenames containing spaces
  set apbscmd [format "\"%s\"" $apbsbin]

  # Attach APBS to a filehandle and print output as it becomes available
  if { [catch {set apbs_fd [open "|$apbscmd $apbs_input"]}] } {
    puts "apbsrun: error running $apbsbin"
    ::APBSRun::apbs_stop
  } else {
    fconfigure $apbs_fd -blocking false
    fileevent $apbs_fd readable [list ::APBSRun::read_handler $apbs_fd]
  }
}

# Call this function when apbs is done
proc ::APBSRun::apbs_stop { { mode "normal" } } {
  variable apbs_status
  variable apbs_button
  variable apbs_fd

  if { $mode == "normal" } {
    if { [catch {close $apbs_fd} err] } {
      puts "apbsrun) Warning: possible problem while running APBS:\n  $err"
    } 
  }

  # check whether or not output files exist, are readable, and have
  # non-zero size, and if so prompt the user to load them into VMD
  if { [check_maps_ok] } {
    ::APBSRun::prompt_load_maps
  } else {
    tk_dialog .errmsg "APBSRun Error" "APBSRun: output files missing or unreadable" error 0 Dismiss
  }

  set apbs_status "Status: Ready"
  set apbs_button "Run APBS"
}

# Read and print a line of APBS output.
proc ::APBSRun::read_handler { chan } {
  if {[eof $chan]} {
    fileevent $chan readable ""
    ::APBSRun::apbs_stop
    return
  }
  if {[gets $chan line] > 0} {
    puts "$line"
  }
}


# Write an apbs input file. Return error if the file can't be written.
proc ::APBSRun::write_input {outfile { use_rel_dir 0 } } {
  variable selected_apbs_config 
  variable pqrfiles
  variable molids
  variable output_files

  if { [catch {set file [open $outfile w]}] } {
    error "apbsrun: can't open $outfile for writing"
  }

  # Write the READ section, a list of molecules to use 
  puts $file "read"
  foreach pqrfile $pqrfiles {
    if { $use_rel_dir } {
      set pqrfile [file normalize $pqrfile]
    } else {
      set pqrfile [file tail $pqrfile]
    }
    puts $file "  mol pqr $pqrfile"
  }
  puts $file "end"

  # Write the ELEC statements
  for {set i 0} {$i < [llength $selected_apbs_config]} {incr i} {
    array set elec_statement [lindex $selected_apbs_config $i]
    set apbs_cgcent $molids([string index $elec_statement(cgcent_mol) 0])
    set apbs_fgcent $molids([string index $elec_statement(fgcent_mol) 0])

    puts $file "elec"

    # mg-manual|mg-auto|mg-para|mg-dummy
    puts $file "  $elec_statement(calc_type)"

    # dime
    puts $file "  dime $elec_statement(dime_x) $elec_statement(dime_y) $elec_statement(dime_z)"

    if {[string equal $elec_statement(calc_type) "mg-manual"] ||
        [string equal $elec_statement(calc_type) "mg-dummy"]} {
      # nlev
      puts $file "  nlev $elec_statement(nlev)"

      # glen
      puts $file "  glen $elec_statement(cglen_x) $elec_statement(cglen_y) $elec_statement(cglen_z)" 

      # gcent
      if {[string equal $elec_statement(cgcent_method) "molid"]} {
        puts $file "  gcent mol $apbs_cgcent"
      } else {
        puts $file "  gcent $elec_statement(cgcent_x) $elec_statement(cgcent_y) $elec_statement(cgcent_z)"
      }
    } elseif {[string equal $elec_statement(calc_type) "mg-auto"] ||
              [string equal $elec_statement(calc_type) "mg-para"]} {
      # cglen
      puts $file "  cglen $elec_statement(cglen_x) $elec_statement(cglen_y) $elec_statement(cglen_z)" 

      # cgcent
      if {[string equal $elec_statement(cgcent_method) "molid"]} {
        puts $file "  cgcent mol $apbs_cgcent"
      } else {
        puts $file "  cgcent $elec_statement(cgcent_x) $elec_statement(cgcent_y) $elec_statement(cgcent_z)"
      }

      # fglen
      puts $file "  fglen $elec_statement(fglen_x) $elec_statement(fglen_y) $elec_statement(fglen_z)" 

      # fgcent
      if {[string equal $elec_statement(fgcent_method) "molid"]} {
        puts $file "  fgcent mol $apbs_fgcent"
      } else {
        puts $file "  fgcent $elec_statement(fgcent_x) $elec_statement(fgcent_y) $elec_statement(fgcent_z)"
      }

      if {[string equal $elec_statement(calc_type) "mg-para"]} {
        # pdime
        puts $file "  pdime $elec_statement(pdime_x) $elec_statement(pdime_y) $elec_statement(pdime_z)"

        # ofrac
        puts $file "  ofrac $elec_statement(ofrac)"
      }
    } else {
      puts "apbsrun) unknown calc_type $elec_statement(calc_type)"
    }

    # mol
    set apbs_molid $molids([string index $elec_statement(mol) 0])
    puts $file "  mol $apbs_molid"

    # lpbe|npbe
    puts $file "  $elec_statement(pbe)"

    # bcfl
    if {[string equal $elec_statement(bcfl) "Zero boundary conditions"]} {
      puts $file "  bcfl zero"
    } elseif {[string equal $elec_statement(bcfl) "Single ion for molecule"]} {
      puts $file "  bcfl sdh"
    } elseif {[string equal $elec_statement(bcfl) "Single ion for each ion"]} {
      puts $file "  bcfl mdh"
    } elseif {[string equal $elec_statement(bcfl) "Solution from previous calculation"]} {
      puts $file "  bcfl focus"
    } else {
      puts "apbsrun) unknown bcfl $elec_statement(bcfl)"
    }

    # srfm
    if {[string equal $elec_statement(srfm) "No smoothing"]} {
      puts $file "  srfm mol"
    } elseif {[string equal $elec_statement(srfm) "Harmonic average smoothing"]} {
      puts $file "  srfm smol"
    } elseif {[string equal $elec_statement(srfm) "Spline-based surface definitions"]} {
      puts $file "  srfm spl2"
    } else {
      puts "apbsrun) unknown srfm $elec_statement(srfm)"
    }

    # chgm
    if {[string equal $elec_statement(chgm) "Trilinear hat-function"]} {
      puts $file "  chgm spl0"
    } elseif {[string equal $elec_statement(chgm) "Cubic B-Spline"]} {
      puts $file "  chgm spl2"
    } else {
      puts "apbsrun) unknown chgm $elec_statement(chgm)"
    }

    # ion (optional)
    if {[info exists elec_statement(ion)] && [llength $elec_statement(ion)] != 0} {
      foreach ion $elec_statement(ion) {
        puts $file "  ion $ion"
      }
    }

    # pdie sdie sdens srad swin temp gamma
    foreach keyword {pdie sdie sdens srad swin temp gamma} {
      puts $file "  $keyword  $elec_statement($keyword)"
    }

    #XXX - fix these
    puts $file "  calcenergy no"
    puts $file "  calcforce no"

    # write (optional)
    # XXX - this *will* break when multiple ELEC statements attempt to
    # output the same type of file.
    set output_files {}
    foreach type {charge pot smol sspl vdw ivdw lap edens ndens qdens dielx diely dielz kappa} {
      if { [info exists elec_statement(write,$type)] &&
           ($elec_statement(write,$type) == 1) } {
        puts $file "  write $type dx $type"
        lappend output_files $type
      }
    }

    # XXX - writemat (optional)

    puts $file "end"
  }

  puts $file "quit"
  close $file
}

# Overwrite the selection's radii with those found in the CHARMM parameter
# file
proc ::APBSRun::set_parameter_radii {sel} {
  variable ff_radii

  set radiusOK yes
  set newradius {}

  foreach {resname} [$sel get resname] {name} [$sel get name] {radius} [$sel get radius] {
    if {[info exists ff_radii($resname,$name)]} {
      lappend newradius $ff_radii($resname,$name)
    } else {
      lappend newradius $radius
      set radiusOK no
    }
  }

  $sel set radius $newradius
  if {!$radiusOK} {
    puts "apbsrun) warning, parameter file does not contain entries for all selected"
    puts "apbsrun) atoms, using VMD radii for these."
  }
}

# Overwrite the selection's charges with those found in the CHARMM parameter
# file
proc ::APBSRun::set_parameter_charges {sel} {
  variable ff_charges

  set chargeOK yes
  set newcharge {}

  foreach {resname} [$sel get resname] {name} [$sel get name] {charge} [$sel get charge] {
    if {[info exists ff_charges($resname,$name)]} {
      lappend newcharge $ff_charges($resname,$name)
    } else {
      lappend newcharge $charge
      set chargeOK no
    }
  }

  $sel set charge $newcharge
  if {!$chargeOK} {
    puts "apbsrun) warning, parameter file does not contain entries for all selected"
    puts "apbsrun) atoms, using VMD charges for these."
  }
}


# Create a pqr file for the given atom selection with the given name
proc ::APBSRun::write_mol {sel file} {
  variable datfile
  variable use_dat_radii
  variable use_dat_charges

  # Save the radius and charge before overriding with parameter values
  set oldradius [$sel get radius]
  set oldcharge [$sel get charge]

  # Override current VMD values with CHARMM parameter values
  if { $datfile != {} } {
    if { $use_dat_radii } {
      puts "apbsrun) using CHARMM radii"
      ::APBSRun::set_parameter_radii $sel
    } else {
      puts "apbsrun) using VMD radii"
    }

#XXX - Disabled until the parameter assigning code is improved
#    if { $use_dat_charges } {
#      puts "apbsrun) using CHARMM charges"
#      ::APBSRun::set_parameter_charges $sel
#    } else {
#      puts "apbsrun) using VMD charges"
#    }
  }

  # Make sure the molecule is charged.
  # XXX - APBS should (maybe?) allow uncharged molecules for mg-dummy
  # calculation, but it currently doens't. If future versions allow it, we
  # should add a simple if statement to do so as well.
  set chargeOK 0
  foreach charge [$sel get charge] {
    if {$charge != 0} {
      set chargeOK 1
      break
    }
  }
  if {!$chargeOK && 
      [string equal "no" [tk_messageBox -type yesno \
       -title "Uncharged Molecule" -icon warning \
       -message "Molecule is uncharged. Proceed?\n(Use pdb2pqr or the AutoPSF plugin to correct this)"]]  } {
    error "apbsrun: refusing to write uncharged molecule"
  }

  # Check for the availability of the pqrplugin
  set plugin_available [plugin info {mol file reader} pqr plugin_info]
  if {$plugin_available} {
    puts "apbsrun) using pqrplugin for $file"
    if { [catch {$sel writepqr $file}] } {
      error "apbsrun: couldn't write $file"
    }
  } else {
    puts "apbsrun) creating $file"
    if { [catch {set fd [open $file w]}] } {
      error "apbsrun: can't open $file for writing"
    }
    set i 0

    foreach name [$sel get name] resname [$sel get resname] \
      resid [$sel get resid] x [$sel get x] y [$sel get y] z [$sel get z] \
      charge [$sel get charge] radius [$sel get radius] {
      puts $fd [format "ATOM  %5d %-4s %s %5d    %8.3f%8.3f%8.3f %.3f %.3f" \
        $i [string range $name 0 3] [string range $resname 0 3] \
        [string range $resid 0 6] $x $y $z $charge $radius]
      incr i
    }

    close $fd
  }

  # Restore original values
  $sel set radius $oldradius
  $sel set charge $oldcharge
}


# 
# Open a window for changing APBSRun settings
# 
proc ::APBSRun::apbs_settings {} {
  variable main_win
  variable settings_win

  set ::APBSRun::use_dat_charges_temp $::APBSRun::use_dat_charges
  set ::APBSRun::use_dat_radii_temp $::APBSRun::use_dat_radii
  set ::APBSRun::setup_only_temp $::APBSRun::setup_only
  set ::APBSRun::apbsbin_temp $::APBSRun::apbsbin
  set ::APBSRun::workdir_temp $::APBSRun::workdir

  # If already initialized, just turn on
  if { [winfo exists $main_win.settings] } {
    wm deiconify $settings_win
    return
  }

  set settings_win [toplevel "$main_win.settings"]
  wm title $settings_win "Settings" 
  wm resizable $settings_win yes yes

  # Make this window modal.
  grab $settings_win
  wm transient $settings_win $main_win
  wm protocol $settings_win WM_DELETE_WINDOW {
    grab release $::APBSRun::settings_win
    after idle destroy $::APBSRun::settings_win
  }
  raise $settings_win

  frame $settings_win.workdir
  grid [label $settings_win.workdir.label -anchor w \
    -text "Working Directory"] -row 0 -column 0 -sticky ew
  grid [entry $settings_win.workdir.value -width 30 \
    -textvariable ::APBSRun::workdir_temp] -row 1 -column 0 -sticky nsew
  grid [button $settings_win.workdir.button -text "Browse" \
    -command {
      set tempdir [tk_chooseDirectory]
      if {![string equal $tempdir ""]} {
        set ::APBSRun::workdir_temp $tempdir
      }}] -row 1 -column 1 -sticky ew
  grid columnconfigure $settings_win.workdir 0 -weight 1
  grid rowconfigure $settings_win.workdir 1 -weight 1

  frame $settings_win.apbsbin
  grid [label $settings_win.apbsbin.label -anchor w \
    -text "APBS Location"] -row 0 -column 0 -sticky ew
  grid [entry $settings_win.apbsbin.value -width 30 \
    -textvariable ::APBSRun::apbsbin_temp] -row 1 -column 0 -sticky nsew
  grid [button $settings_win.apbsbin.button -text "Browse" \
    -command {
      set tempfile [tk_getOpenFile]
      if {![string equal $tempfile ""]} {
        set ::APBSRun::apbsbin_temp $tempfile
      }}] -row 1 -column 1 -sticky ew
  grid columnconfigure $settings_win.apbsbin 0 -weight 1
  grid rowconfigure $settings_win.apbsbin 1 -weight 1

  frame $settings_win.apbssetup
  checkbutton $settings_win.apbssetup.setup_button \
    -text "Setup files only, do not run APBS" \
    -variable ::APBSRun::setup_only_temp
  checkbutton $settings_win.apbssetup.radii_button \
    -text "Use CHARMM radii" \
    -variable ::APBSRun::use_dat_radii_temp
#XXX - Disabled until the parameter assigning code is improved
#  checkbutton $settings_win.apbssetup.charges_button \
#    -text "Use CHARMM charges" \
#    -variable ::APBSRun::use_dat_charges_temp
  pack $settings_win.apbssetup.setup_button \
    $settings_win.apbssetup.radii_button \
    -side top -anchor w 
  
  frame $settings_win.okaycancel
  button $settings_win.okaycancel.okay -text OK -width 6 \
    -command {
      set ::APBSRun::use_dat_charges $::APBSRun::use_dat_charges_temp
      set ::APBSRun::use_dat_radii $::APBSRun::use_dat_radii_temp
      set ::APBSRun::setup_only $::APBSRun::setup_only_temp
      set ::APBSRun::apbsbin $::APBSRun::apbsbin_temp
      set ::APBSRun::workdir $::APBSRun::workdir_temp
      grab release $::APBSRun::settings_win
      after idle destroy $::APBSRun::settings_win
    }
  button $settings_win.okaycancel.cancel -text "Cancel" -width 6 \
    -command {
      grab release $::APBSRun::settings_win
      after idle destroy $::APBSRun::settings_win
    }
  pack $settings_win.okaycancel.okay $settings_win.okaycancel.cancel \
    -side left -anchor w

  pack $settings_win.workdir $settings_win.apbsbin $settings_win.apbssetup \
    $settings_win.okaycancel \
    -side top -anchor w -fill both -expand yes -padx 10 -pady 10
}


# Reset the current apbs configuration to the default values and 
# reset the current *default* apbs configuration to reflect the top molecule
proc ::APBSRun::set_default {} {
  variable default_apbs_config
  variable current_apbs_config
  variable apbs_type
  variable elec_list
  variable elec_index
  variable file_list

  # Get information about the top mol to set the defaults
  if { $file_list == {{}} } {
    set topmol {}
  } else {
    set topmol [lsearch -inline $file_list [molinfo top]*]
    if {$topmol == {}} {
      set topmol [lindex $file_list 0]
    }

    # Make sure this molecule contains atoms and coordinates. If not, use
    # the first molecule that does.
    foreach loaded_mol [concat [list $topmol] $file_list] {
      set topmol_id [string index $loaded_mol 0]
      if { [molinfo $topmol_id get numatoms] != 0  &&
           [molinfo $topmol_id get numframes] != 0 } {
        set topmol $loaded_mol
        break
      } else {
        set topmol {}
      }
    }
  }

  if {$topmol == {}} {
    set selection_text "all"
    set molsize_x 0
    set molsize_y 0
    set molsize_z 0
  } else {
    set topmol_id [string index $topmol 0]
    set selection_text [lindex [molinfo $topmol_id get {"selection 0"}] 0]

    # Find the size of the molecule
    set sel [atomselect $topmol_id all]
    set minmax [measure minmax $sel]
    $sel delete

    set molsize_x [expr [lindex $minmax 1 0] - [lindex $minmax 0 0]]
    set molsize_y [expr [lindex $minmax 1 1] - [lindex $minmax 0 1]]
    set molsize_z [expr [lindex $minmax 1 2] - [lindex $minmax 0 2]]
  }

  # Set Default APBS info
  set default_apbs_config([concat "Electrostatic" "Potential"]) [list [list \
    mol $topmol atomsel $selection_text pbe lpbe \
    bcfl "Single ion for molecule" pdie 1.0 sdie 78.54 \
    srfm "Harmonic average smoothing" chgm "Cubic B-Spline" \
    sdens 10.0 srad 1.4 swin 0.3 temp 298.15 gamma 0.105 \
    write,pot 1 \
    ion { {1 0.150 2.0} {-1 0.150 2.0} } \
    calc_type {mg-auto} dime_x 129 dime_y 129 dime_z 129 \
    cglen_x [expr 1.5 * $molsize_x] cglen_y [expr 1.5 * $molsize_y] \
    cglen_z [expr 1.5 * $molsize_z] cgcent_method {molid} \
    cgcent_x {} cgcent_y {} cgcent_z {} cgcent_mol $topmol \
    fglen_x [expr 1.5 * $molsize_x] fglen_y [expr 1.5 * $molsize_y] \
    fglen_z [expr 1.5 * $molsize_z] fgcent_method {molid} \
    fgcent_x {} fgcent_y {} fgcent_z {} fgcent_mol $topmol \
    nlev 4 ofrac 0.1 pdime_x 4 pdime_y 4 pdime_z 4 ] ]

  set default_apbs_config([concat "Solvent" "Accessibility"]) [list [list \
    mol $topmol atomsel $selection_text pbe lpbe \
    bcfl "Single ion for molecule" pdie 1.0 sdie 78.54 \
    srfm "Harmonic average smoothing" chgm "Cubic B-Spline" \
    sdens 10.0 srad 1.4 swin 0.3 temp 298.15 gamma 0.105 \
    write,sspl 1 \
    ion { {1 0.150 2.0} {-1 0.150 2.0} } \
    calc_type {mg-dummy} dime_x 129 dime_y 129 dime_z 129 \
    cglen_x [expr 1.5 * $molsize_x] cglen_y [expr 1.5 * $molsize_y] \
    cglen_z [expr 1.5 * $molsize_z] cgcent_method {molid} \
    cgcent_x {} cgcent_y {} cgcent_z {} cgcent_mol $topmol \
    fglen_x [expr 1.5 * $molsize_x] fglen_y [expr 1.5 * $molsize_y] \
    fglen_z [expr 1.5 * $molsize_z] fgcent_method {molid} \
    fgcent_x {} fgcent_y {} fgcent_z {} fgcent_mol $topmol \
    nlev 4 ofrac 0.1 pdime_x 4 pdime_y 4 pdime_z 4 ] ]

  set default_apbs_config(Custom) {}

  # Copy the defaults to the user-edited APBS info
  if {$apbs_type == {}} {
    array set current_apbs_config [array get default_apbs_config]
    set apbs_type "Electrostatic Potential"
  } else {
    set current_apbs_config($apbs_type) $default_apbs_config($apbs_type)
  }

  ::APBSRun::update_elec_list
}


# Add an ELEC statement to elec_vals
proc ::APBSRun::elec_add {} {
  variable elec_temp
  variable elec_index
  variable elec_current_index

  # Clear the temp array
  array unset elec_temp

  # Launch the elec-editing window
  set elec_current_index $elec_index
  ::APBSRun::elecmenu
}


# Edit an ELEC statement in elec_vals
proc ::APBSRun::elec_edit {} {
  variable elec_temp
  variable elec_listbox
  variable elec_list
  variable elec_current_index
  variable current_apbs_config
  variable apbs_type

  # Can't edit anything if no ELEC statements exist
  if {[llength $elec_list] == 0} {
    return
  }
 
  set elec_current_index [string index [$elec_listbox get active] 0]

  # Clear the temporary array, and load it with previous values
  array unset elec_temp
  array set elec_temp \
    [lindex $current_apbs_config($apbs_type) $elec_current_index]

  # Launch the elec-editing window
  ::APBSRun::elecmenu
}


# Remove an ELEC statement from elec_vals
proc ::APBSRun::elec_del {} {
  variable elec_listbox
  variable current_apbs_config
  variable apbs_type

  set index [string index [$elec_listbox get active] 0]

  # Remove the entry from the listbox
  $elec_listbox delete active

  # Set the appropriate item in current_apbs_config to nothing
  #XXX - this is ugly
  lset current_apbs_config($apbs_type) $index {}
}


# Open a window for editing the values of an elec statement
proc ::APBSRun::elecmenu {} {
  variable main_win
  variable elec_win
  variable elec_temp
  variable file_list
  variable elec_keyword

  # If already initialized, just turn on
  if { [winfo exists $main_win.elec] } {
    wm deiconify $elec_win
    return
  }

  set elec_win [toplevel "$main_win.elec"]
  wm title $elec_win "ELEC values" 
  wm resizable $elec_win yes yes

  # Make this window modal.
  grab $elec_win
  wm transient $elec_win $main_win
  wm protocol $elec_win WM_DELETE_WINDOW {
    grab release $::APBSRun::elec_win
    after idle destroy $::APBSRun::elec_win
  }
  raise $elec_win

  # make the menu bar
  frame $elec_win.menubar -relief raised -bd 2 ;# frame for menubar
  grid $elec_win.menubar -padx 1 -column 0 -columnspan 2 -row 0 -sticky ew 

  menubutton $elec_win.menubar.calc -text "Calculation" -underline 0 \
    -menu $elec_win.menubar.calc.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $elec_win.menubar.calc config -width 11
  menubutton $elec_win.menubar.output -text "Output" -underline 0 \
    -menu $elec_win.menubar.output.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $elec_win.menubar.output config -width 7
  pack $elec_win.menubar.calc $elec_win.menubar.output -side left

  # calculation menu
  menu $elec_win.menubar.calc.menu -tearoff no
  $elec_win.menubar.calc.menu add radiobutton -label "Automatic" \
    -variable ::APBSRun::elec_temp(calc_type) -value {mg-auto}
  $elec_win.menubar.calc.menu add radiobutton -label "Manual" \
    -variable ::APBSRun::elec_temp(calc_type) -value {mg-manual}
  $elec_win.menubar.calc.menu add radiobutton -label "Parallel" \
    -variable ::APBSRun::elec_temp(calc_type) -value {mg-para}
  $elec_win.menubar.calc.menu add radiobutton -label "Dummy" \
    -variable ::APBSRun::elec_temp(calc_type) -value {mg-dummy}
  $elec_win.menubar.calc.menu add separator 
  $elec_win.menubar.calc.menu add radiobutton -label "Linearized PBE" \
    -variable ::APBSRun::elec_temp(pbe) -value {lpbe}
  $elec_win.menubar.calc.menu add radiobutton -label "Nonlinear PBE"\
    -variable ::APBSRun::elec_temp(pbe) -value {npbe}

  # output menu
  menu $elec_win.menubar.output.menu -tearoff no
  $elec_win.menubar.output.menu add checkbutton -label "Charge distribution" \
    -variable ::APBSRun::elec_temp(write,charge)
  $elec_win.menubar.output.menu add checkbutton -label "Potential" \
    -variable ::APBSRun::elec_temp(write,pot)
  $elec_win.menubar.output.menu add checkbutton -label "Solvent accessibility" \
    -variable ::APBSRun::elec_temp(write,sspl)
  $elec_win.menubar.output.menu add checkbutton -label "Van der Waals accessibility" \
    -variable ::APBSRun::elec_temp(write,vdw)
  $elec_win.menubar.output.menu add checkbutton -label "Ion accessibility" \
    -variable ::APBSRun::elec_temp(write,ivdw)
  $elec_win.menubar.output.menu add checkbutton -label "Laplacian of potential" \
    -variable ::APBSRun::elec_temp(write,lap)
  $elec_win.menubar.output.menu add checkbutton -label "Energy density" \
    -variable ::APBSRun::elec_temp(write,edens)
  $elec_win.menubar.output.menu add checkbutton -label "Ion number density" \
    -variable ::APBSRun::elec_temp(write,ndens)
  $elec_win.menubar.output.menu add checkbutton -label "Ion charge density" \
    -variable ::APBSRun::elec_temp(write,qdens)
  $elec_win.menubar.output.menu add checkbutton -label "x-shifted dielectric map" \
    -variable ::APBSRun::elec_temp(write,dielx)
  $elec_win.menubar.output.menu add checkbutton -label "y-shifted dielectric map" \
    -variable ::APBSRun::elec_temp(write,diely)
  $elec_win.menubar.output.menu add checkbutton -label "z-shifted dielectric map" \
    -variable ::APBSRun::elec_temp(write,dielz)
  $elec_win.menubar.output.menu add checkbutton -label "Map function" \
    -variable ::APBSRun::elec_temp(write,kappa)


  if {![info exists ::APBSRun::elec_temp(calc_type)]} {
    set ::APBSRun::elec_temp(calc_type) {mg-auto}
  }

  # Trace the keyword variable so different options can be displayed when it
  # changes
  trace add variable ::APBSRun::elec_temp(calc_type) write \
    ::APBSRun::change_keyword

  # Remove the trace when this window is destroyed
  bind $elec_win <Destroy> {+trace remove variable \
    ::APBSRun::elec_temp(calc_type) write ::APBSRun::change_keyword}

  ### frame for options used by all ELEC keyworks
  frame $elec_win.options

  # mol
  # XXX this code fails to propagate changes to the selected molecule
  #     due to an interaction between the 'top' molecule, and the 
  #     molecule selected in the edit interface.
  frame $elec_win.options.mol
  label $elec_win.options.mol.label -text "Molecule: " \
    -anchor w
  eval tk_optionMenu $elec_win.options.mol.id ::APBSRun::elec_temp(mol) \
    $file_list
  $elec_win.options.mol.id configure -width 12
  pack $elec_win.options.mol.label $elec_win.options.mol.id \
    -side left -anchor w -fill x -expand yes

  # selection
  frame $elec_win.options.atomsel
  label $elec_win.options.atomsel.label -text "Selection: " \
    -anchor w
  entry $elec_win.options.atomsel.entry -width 20 \
    -textvar ::APBSRun::elec_temp(atomsel)
  pack $elec_win.options.atomsel.label $elec_win.options.atomsel.entry \
    -side left -anchor w -fill x -expand yes

  # bcfl
  frame $elec_win.options.bcfl
  label $elec_win.options.bcfl.label -text "Boundary condition: "
  tk_optionMenu $elec_win.options.bcfl.menu ::APBSRun::elec_temp(bcfl) \
    "Zero boundary conditions" \
    "Single ion for molecule" \
    "Single ion for each ion" \
    "Solution from previous calculation"
  $elec_win.options.bcfl.menu config -width 25
  pack $elec_win.options.bcfl.label $elec_win.options.bcfl.menu \
    -side top -anchor w

  # ion (optional)
  frame $elec_win.options.ions
  label $elec_win.options.ions.label -text "Mobile Ions: "
  button $elec_win.options.ions.edit -text "Edit..." -command ::APBSRun::edit_ions
  pack $elec_win.options.ions.label $elec_win.options.ions.edit \
       -side left -anchor w

  # pdie
  # sdie
  frame $elec_win.options.diel
  label $elec_win.options.diel.label -text "Dielectric constants: "
  frame $elec_win.options.diel.vals
  label $elec_win.options.diel.vals.plabel -text "solute: "
  entry $elec_win.options.diel.vals.pval -width 6 -textvar ::APBSRun::elec_temp(pdie)
  label $elec_win.options.diel.vals.slabel -text " solvent: "
  entry $elec_win.options.diel.vals.sval -width 6 -textvar ::APBSRun::elec_temp(sdie)
  pack $elec_win.options.diel.vals.plabel $elec_win.options.diel.vals.pval \
    $elec_win.options.diel.vals.slabel $elec_win.options.diel.vals.sval \
    -side left -anchor w
  pack $elec_win.options.diel.label $elec_win.options.diel.vals \
    -side top -anchor w

  # chgm
  frame $elec_win.options.chgm
  label $elec_win.options.chgm.label -text "Charge discretization: "
  tk_optionMenu $elec_win.options.chgm.menu ::APBSRun::elec_temp(chgm) \
    "Trilinear hat-function" \
    "Cubic B-Spline" 
  $elec_win.options.chgm.menu config -width 25
  pack $elec_win.options.chgm.label $elec_win.options.chgm.menu \
    -side top -anchor w

  # srfm
  frame $elec_win.options.srfm
  label $elec_win.options.srfm.label -text "Surface definition: "
  tk_optionMenu $elec_win.options.srfm.menu ::APBSRun::elec_temp(srfm) \
    "No smoothing" \
    "Harmonic average smoothing" \
    "Spline-based surface definitions"
  $elec_win.options.srfm.menu config -width 25
  pack $elec_win.options.srfm.label $elec_win.options.srfm.menu \
    -side top -anchor w

  # usemap (optional)
  # XXX - TODO
 
  # Grid containing a few system options
  frame $elec_win.options.system

  # sdens added for APBS 0.4.0 
  label $elec_win.options.system.sdensl -text "Vacc sphere density: " \
    -anchor w
  entry $elec_win.options.system.sdensval -width 6 \
    -textvar ::APBSRun::elec_temp(sdens)
  grid $elec_win.options.system.sdensl $elec_win.options.system.sdensval \
    -row 0 -sticky ew

  # srad
  label $elec_win.options.system.sradl -text "Solvent radius: " \
    -anchor w
  entry $elec_win.options.system.sradval -width 6 \
    -textvar ::APBSRun::elec_temp(srad)
  grid $elec_win.options.system.sradl $elec_win.options.system.sradval \
    -row 1 -sticky ew
  
  # swin
  label $elec_win.options.system.swinl -text "Spline window: " \
    -anchor w
  entry $elec_win.options.system.swinval -width 6  \
    -textvar ::APBSRun::elec_temp(swin)
  grid $elec_win.options.system.swinl $elec_win.options.system.swinval \
    -row 2 -sticky ew

  # temp
  label $elec_win.options.system.templ -text "System temperature (K): " \
    -anchor w
  entry $elec_win.options.system.tempval -width 6 \
    -textvar ::APBSRun::elec_temp(temp)
  grid $elec_win.options.system.templ $elec_win.options.system.tempval \
    -row 3 -sticky ew

  # gamma
  label $elec_win.options.system.gammal -text "Surface tension: " \
    -anchor w
  entry $elec_win.options.system.gammaval -width 6 \
    -textvar ::APBSRun::elec_temp(gamma)
  grid $elec_win.options.system.gammal $elec_win.options.system.gammaval \
    -row 4 -sticky ew

  grid columnconfigure $elec_win.options.system 1 -weight 1

  # XXX calcforce and calcenergy -- write results to stdout

  # write (optional)
  # XXX - TODO

  # writemat (optional)
  # XXX - TODO

  pack $elec_win.options.mol $elec_win.options.atomsel \
    $elec_win.options.bcfl $elec_win.options.ions $elec_win.options.diel \
    $elec_win.options.chgm $elec_win.options.srfm \
    $elec_win.options.system \
    -side top -pady 8 -padx 8 -fill x -anchor w

  # End the frame for selecting general APBS options
  grid $elec_win.options -column 0 -row 1 \
    -sticky nsew -padx 8 -pady 0


  ### Grid (and keyword) specific options
  frame $elec_win.grid

  # dime
  frame $elec_win.grid.dime
  label $elec_win.grid.dime.label -text "Number of gridpoints: "
  frame $elec_win.grid.dime.coord
  label $elec_win.grid.dime.coord.xlabel -text "x: "
  entry $elec_win.grid.dime.coord.xentry -width 6 -textvar ::APBSRun::elec_temp(dime_x)
  label $elec_win.grid.dime.coord.ylabel -text " y: "
  entry $elec_win.grid.dime.coord.yentry -width 6 -textvar ::APBSRun::elec_temp(dime_y)
  label $elec_win.grid.dime.coord.zlabel -text " z: "
  entry $elec_win.grid.dime.coord.zentry -width 6 -textvar ::APBSRun::elec_temp(dime_z)
  pack $elec_win.grid.dime.coord.xlabel $elec_win.grid.dime.coord.xentry $elec_win.grid.dime.coord.ylabel \
    $elec_win.grid.dime.coord.yentry $elec_win.grid.dime.coord.zlabel $elec_win.grid.dime.coord.zentry \
    -side left
  pack $elec_win.grid.dime.label $elec_win.grid.dime.coord \
    -side top -anchor w
  pack $elec_win.grid.dime -side top -anchor w -fill x \
    -pady 8 -padx 8

  # Draw the appropriate keyword options
  draw_mg_para $elec_win.grid.mg_para
  draw_mg_auto $elec_win.grid.mg_auto
  draw_mg_manual $elec_win.grid.mg_manual
  set elec_keyword $elec_win.grid.mg_auto
  ::APBSRun::change_keyword
  
  # End the frame for selecting ELEC keyword and keyword-specific options
  grid $elec_win.grid -column 1 -row 1 -rowspan 2 \
    -sticky nsew -padx 8 -pady 0

  frame $elec_win.okaycancel
  button $elec_win.okaycancel.okay -text OK -width 6 \
    -command {
      if { [::APBSRun::elec_check ::APBSRun::elec_temp] } {
        ::APBSRun::elec_save ::APBSRun::elec_temp
        grab release $::APBSRun::elec_win
        after idle destroy $::APBSRun::elec_win
      }
    }
  button $elec_win.okaycancel.cancel -text Cancel -width 6 \
    -command {
      grab release $::APBSRun::elec_win
      after idle destroy $::APBSRun::elec_win
    }
  pack $elec_win.okaycancel.okay $elec_win.okaycancel.cancel \
    -side left 
  grid $elec_win.okaycancel -column 0 -row 2 \
    -sticky w -padx 8 -pady 8

  grid columnconfigure $elec_win {0 1} -weight 1
  grid rowconfigure $elec_win 1 -weight 1
}


# When elec_temp(calc_type) changes, change the contents of the elec_win
proc ::APBSRun::change_keyword {args} {
  variable elec_win
  variable elec_temp
  variable elec_keyword

  pack forget $elec_keyword

  if {[string equal $elec_temp(calc_type) "mg-para"]} {
    set elec_keyword $elec_win.grid.mg_para
  } elseif {[string equal $elec_temp(calc_type) "mg-auto"]} {
    set elec_keyword $elec_win.grid.mg_auto
  } elseif {[string equal $elec_temp(calc_type) "mg-manual"] ||
            [string equal $elec_temp(calc_type) "mg-dummy"]} {
    set elec_keyword $elec_win.grid.mg_manual
  }

  pack $elec_keyword -side top -anchor w
}


# Edit ion settings
proc ::APBSRun::edit_ions { } {
  variable elec_win
  variable edition_win
  variable use_ions
  variable ionconc
  variable ionrad

  # this is a hack until we have a full ion editing browser
  # Users will generally add equal concentrations of +1 and -1 ions, 
  # both with equal radii
  if { [info exists ::APBSRun::elec_temp(ion)] } {
    set ionlist $::APBSRun::elec_temp(ion)

    if { [llength ionlist] == 0 } {
#puts "apbsrun) edit_ion: selecting sane defaults1"
      set ionconc 0.150 
      set ionrad  2.0 
    } else {
#puts "apbsrun) edit_ion: using existing settings"
      set ionconc [lindex $ionlist 0 1]
      set ionrad  [lindex $ionlist 0 2] 
    }
  } else {
#puts "apbsrun) edit_ion: selecting sane defaults2"
    set ionconc 0.150 
    set ionrad  2.0 
  }

  set w [toplevel "$elec_win.editions"]
  set edition_win $w

  wm title $w "APBSRun - Edit Mobile Ions"
  wm resizable $w 0 0

  # Make this window modal.
  grab $w
  wm transient $w $elec_win
  wm protocol $w WM_DELETE_WINDOW {
    grab release $::APBSRun::edition_win
    after idle destroy $::APBSRun::edition_win
  }
  raise $w

  frame $w.enable 
  checkbutton $w.enable.check \
    -text "Enable mobile ions" -variable ::APBSRun::use_ions
  pack $w.enable.check -side left -anchor w
 
  frame $w.conc
  label $w.conc.label -text "Mobile ion concentration (M)"
  entry $w.conc.entry -textvar ::APBSRun::ionconc 
  pack $w.conc.label $w.conc.entry -side left -anchor w

  frame $w.rad
  label $w.rad.label -text "Mobile ion species radius (Angstroms)"
  entry $w.rad.entry -textvar ::APBSRun::ionrad
  pack $w.rad.label $w.rad.entry -side left -anchor w

  button $w.done -text "Done" -command {
    if { $::APBSRun::use_ions } {
#puts "apbsrun) using ions..."
      set ionlist [list [list  1 $::APBSRun::ionconc $::APBSRun::ionrad] \
                        [list -1 $::APBSRun::ionconc $::APBSRun::ionrad]]
      set ::APBSRun::elec_temp(ion) $ionlist
    } else {
#puts "apbsrun) not using ions..."
      if { [info exists ::APBSRun::elec_temp(ion)] } {
        unset ::APBSRun::elec_temp(ion)
      }
    }
    after idle destroy $::APBSRun::edition_win
  }

  pack $w.enable $w.conc $w.rad $w.done -side top -anchor w
}



# Draw the mg_manual frame
proc ::APBSRun::draw_mg_manual {pathName} {
  variable elec_temp
  variable file_list

  frame $pathName

  #
  # Grid
  #
  frame $pathName.g -relief groove -bd 2
  pack [label $pathName.g.label -text "Grid Options"] \
    -side top -anchor w -padx 8 -pady 4

  # glen
  frame $pathName.g.len
  label $pathName.g.len.label -text "Mesh Lengths:"

  frame $pathName.g.len.coord
  label $pathName.g.len.coord.xlabel -text "x: "
  entry $pathName.g.len.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_x)
  label $pathName.g.len.coord.ylabel -text " y: "
  entry $pathName.g.len.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_y)
  label $pathName.g.len.coord.zlabel -text " z: "
  entry $pathName.g.len.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_z)
  pack $pathName.g.len.coord.xlabel $pathName.g.len.coord.xvalue \
    $pathName.g.len.coord.ylabel $pathName.g.len.coord.yvalue \
    $pathName.g.len.coord.zlabel $pathName.g.len.coord.zvalue \
    -side left -anchor w

  pack $pathName.g.len.label $pathName.g.len.coord \
    -side top -anchor w
  pack $pathName.g.len -side top -anchor w -padx 8 -pady 4
  
  # gcent
  frame $pathName.g.cent
  label $pathName.g.cent.label -text "Center:" -anchor w

  frame $pathName.g.cent.mol
  radiobutton $pathName.g.cent.mol.button -anchor w \
    -variable ::APBSRun::elec_temp(cgcent_method) -value "molid"
  eval tk_optionMenu $pathName.g.cent.mol.id \
    ::APBSRun::elec_temp(cgcent_mol) $file_list
  $pathName.g.cent.mol.id configure -width 12
  pack $pathName.g.cent.mol.button $pathName.g.cent.mol.id \
    -side left

  frame $pathName.g.cent.coord
  radiobutton $pathName.g.cent.coord.button -anchor w \
    -variable ::APBSRun::elec_temp(cgcent_method) -value "coord"
  label $pathName.g.cent.coord.xlabel -text "x: "
  entry $pathName.g.cent.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_x)
  label $pathName.g.cent.coord.ylabel -text " y: "
  entry $pathName.g.cent.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_y)
  label $pathName.g.cent.coord.zlabel -text " z: "
  entry $pathName.g.cent.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_z)
  pack $pathName.g.cent.coord.button \
    $pathName.g.cent.coord.xlabel $pathName.g.cent.coord.xvalue \
    $pathName.g.cent.coord.ylabel $pathName.g.cent.coord.yvalue \
    $pathName.g.cent.coord.zlabel $pathName.g.cent.coord.zvalue \
    -side left

  pack $pathName.g.cent.label $pathName.g.cent.mol $pathName.g.cent.coord \
    -side top -anchor e -fill x
  pack $pathName.g.cent -side top -anchor w -padx 8 -pady 4

  pack $pathName.g -side top -anchor w -pady 4

  # nlev
  frame $pathName.nlev
  label $pathName.nlev.label -text "Number of levels: "
  entry $pathName.nlev.entry -width 6 -textvariable ::APBSRun::elec_temp(nlev)
  pack $pathName.nlev.label $pathName.nlev.entry -side left -anchor w
  pack $pathName.nlev -side top -anchor w -pady 8 -padx 8
}


# Draw the mg_auto frame
proc ::APBSRun::draw_mg_auto {pathName} {
  variable elec_temp
  variable file_list

  frame $pathName

  #
  # Coarse Grid
  #
  frame $pathName.cg -relief groove -bd 2
  pack [label $pathName.cg.label -text "Coarse Grid Options"] \
    -side top -anchor w -padx 8 -pady 4

  # cglen
  frame $pathName.cg.len
  label $pathName.cg.len.label -text "Mesh Lengths:"

  frame $pathName.cg.len.coord
  label $pathName.cg.len.coord.xlabel -text "x: "
  entry $pathName.cg.len.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_x)
  label $pathName.cg.len.coord.ylabel -text " y: "
  entry $pathName.cg.len.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_y)
  label $pathName.cg.len.coord.zlabel -text " z: "
  entry $pathName.cg.len.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cglen_z)
  pack $pathName.cg.len.coord.xlabel $pathName.cg.len.coord.xvalue \
    $pathName.cg.len.coord.ylabel $pathName.cg.len.coord.yvalue \
    $pathName.cg.len.coord.zlabel $pathName.cg.len.coord.zvalue \
    -side left -anchor w

  pack $pathName.cg.len.label $pathName.cg.len.coord \
    -side top -anchor w
  pack $pathName.cg.len -side top -anchor w -padx 8 -pady 4
  
  # cgcent
  frame $pathName.cg.cent
  label $pathName.cg.cent.label -text "Center:" -anchor w

  frame $pathName.cg.cent.mol
  radiobutton $pathName.cg.cent.mol.button -anchor w \
    -variable ::APBSRun::elec_temp(cgcent_method) -value "molid"
  eval tk_optionMenu $pathName.cg.cent.mol.id \
    ::APBSRun::elec_temp(cgcent_mol) $file_list
  $pathName.cg.cent.mol.id configure -width 12
  pack $pathName.cg.cent.mol.button $pathName.cg.cent.mol.id \
    -side left

  frame $pathName.cg.cent.coord
  radiobutton $pathName.cg.cent.coord.button -anchor w \
    -variable ::APBSRun::elec_temp(cgcent_method) -value "coord"
  label $pathName.cg.cent.coord.xlabel -text "x: "
  entry $pathName.cg.cent.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_x)
  label $pathName.cg.cent.coord.ylabel -text " y: "
  entry $pathName.cg.cent.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_y)
  label $pathName.cg.cent.coord.zlabel -text " z: "
  entry $pathName.cg.cent.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(cgcent_z)
  pack $pathName.cg.cent.coord.button \
    $pathName.cg.cent.coord.xlabel $pathName.cg.cent.coord.xvalue \
    $pathName.cg.cent.coord.ylabel $pathName.cg.cent.coord.yvalue \
    $pathName.cg.cent.coord.zlabel $pathName.cg.cent.coord.zvalue \
    -side left

  pack $pathName.cg.cent.label $pathName.cg.cent.mol $pathName.cg.cent.coord \
    -side top -anchor e -fill x
  pack $pathName.cg.cent -side top -anchor w -padx 8 -pady 4

  pack $pathName.cg -side top -anchor w -pady 4

  #
  # Fine Grid
  #
  frame $pathName.fg -relief groove -bd 2
  pack [label $pathName.fg.label -text "Fine Grid Options"] \
    -side top -anchor w -padx 8 -pady 4

  # fglen
  frame $pathName.fg.len
  label $pathName.fg.len.label -text "Mesh Lengths:"

  frame $pathName.fg.len.coord
  label $pathName.fg.len.coord.xlabel -text "x: "
  entry $pathName.fg.len.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fglen_x)
  label $pathName.fg.len.coord.ylabel -text " y: "
  entry $pathName.fg.len.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fglen_y)
  label $pathName.fg.len.coord.zlabel -text " z: "
  entry $pathName.fg.len.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fglen_z)
  pack $pathName.fg.len.coord.xlabel $pathName.fg.len.coord.xvalue \
    $pathName.fg.len.coord.ylabel $pathName.fg.len.coord.yvalue \
    $pathName.fg.len.coord.zlabel $pathName.fg.len.coord.zvalue \
    -side left -anchor w

  pack $pathName.fg.len.label $pathName.fg.len.coord \
    -side top -anchor w
  pack $pathName.fg.len -side top -anchor w -padx 8 -pady 4
  
  # fgcent
  frame $pathName.fg.cent
  label $pathName.fg.cent.label -text "Center:" -anchor w

  frame $pathName.fg.cent.mol
  radiobutton $pathName.fg.cent.mol.button -anchor w \
    -variable ::APBSRun::elec_temp(fgcent_method) -value "molid"
  eval tk_optionMenu $pathName.fg.cent.mol.id \
    ::APBSRun::elec_temp(fgcent_mol) $file_list
  $pathName.fg.cent.mol.id configure -width 12
  pack $pathName.fg.cent.mol.button $pathName.fg.cent.mol.id \
    -side left

  frame $pathName.fg.cent.coord
  radiobutton $pathName.fg.cent.coord.button -anchor w \
    -variable ::APBSRun::elec_temp(fgcent_method) -value "coord"
  label $pathName.fg.cent.coord.xlabel -text "x: "
  entry $pathName.fg.cent.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fgcent_x)
  label $pathName.fg.cent.coord.ylabel -text " y: "
  entry $pathName.fg.cent.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fgcent_y)
  label $pathName.fg.cent.coord.zlabel -text " z: "
  entry $pathName.fg.cent.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(fgcent_z)
  pack $pathName.fg.cent.coord.button \
    $pathName.fg.cent.coord.xlabel $pathName.fg.cent.coord.xvalue \
    $pathName.fg.cent.coord.ylabel $pathName.fg.cent.coord.yvalue \
    $pathName.fg.cent.coord.zlabel $pathName.fg.cent.coord.zvalue \
    -side left

  pack $pathName.fg.cent.label $pathName.fg.cent.mol $pathName.fg.cent.coord \
    -side top -anchor e -fill x
  pack $pathName.fg.cent -side top -anchor w -padx 8 -pady 4

  pack $pathName.fg -side top -anchor w -pady 4
}


# Draw the mg_para frame
proc ::APBSRun::draw_mg_para {pathName} {
  variable elec_temp
  variable file_list

  frame $pathName

  draw_mg_auto $pathName.mg_auto
  pack $pathName.mg_auto -side top -anchor w

  # pdime
  frame $pathName.pdime
  label $pathName.pdime.label -text "Number of Processors:"

  frame $pathName.pdime.coord
  label $pathName.pdime.coord.xlabel -text "x: "
  entry $pathName.pdime.coord.xvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(pdime_x)
  label $pathName.pdime.coord.ylabel -text " y: "
  entry $pathName.pdime.coord.yvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(pdime_y)
  label $pathName.pdime.coord.zlabel -text " z: "
  entry $pathName.pdime.coord.zvalue -width 6 \
    -textvariable ::APBSRun::elec_temp(pdime_z)
  pack $pathName.pdime.coord.xlabel $pathName.pdime.coord.xvalue \
    $pathName.pdime.coord.ylabel $pathName.pdime.coord.yvalue \
    $pathName.pdime.coord.zlabel $pathName.pdime.coord.zvalue \
    -side left -anchor w

  pack $pathName.pdime.label $pathName.pdime.coord \
    -side top -anchor w
  pack $pathName.pdime -side top -anchor w -pady {8 4} -padx 8

  # ofrac
  frame $pathName.ofrac
  label $pathName.ofrac.label -text "Mesh Overlap:"
  entry $pathName.ofrac.entry -width 6 -textvariable ::APBSRun::elec_temp(ofrac)
  pack $pathName.ofrac.label $pathName.ofrac.entry -side left -anchor w
  pack $pathName.ofrac -side top -anchor w -pady {4 8} -padx 8
}


proc ::APBSRun::is_integer {args} {
  if { [llength $args] != 1 } {
    return 0
  }

  set x [lindex $args 0]
  if { [catch {incr x 0}] } {
    return 0
  } else {
    return 1
  }
}

proc ::APBSRun::is_real {args} {
  if { [llength $args] != 1 } {
    return 0
  }

  set n [lindex $args 0]
  if { [catch {expr $n + 0}] } {
    return 0
  } else {
    return 1
  }
}

#
# Check for legal APBS grid dimensions:  n = a * 2^b + 1
#   where n is the number of grid points, b is an integer >= 5 
#   (ideally 5), and a is a positive integer.  
#   The test is pretty easy; I simply make sure I can divide 
#   (n-1) by 2 at least 5 times.
#
# Some valid dimension sizes are thus:
#  33, 65, 97, 129, 161, 193, 225, 257, 289, 321, 353, 385, 417, 449, 481, 513,
#  545, 577, 609, 641, 673, 705, 737, 769, 801, 833, 865, 897, 929, 961, 993
#
proc ::APBSRun::is_valid_dime {args} {
  if { ![is_integer $args] } {
    return 0
  }

  set n [lindex $args 0]
  if { $n <= 1 ||
       [expr (32 * round(($n-1)/32))+1] != $n } {
    return 0
  } else {
    return 1
  }
}


# Validate the elec statement return 1 on success, 0 on failure
proc ::APBSRun::elec_check {elec_ref} {
  upvar $elec_ref elec_statement

  # dime - must be (n = a * 2^b + 1)
  if { ![is_valid_dime $elec_statement(dime_x)] ||
       ![is_valid_dime $elec_statement(dime_y)] ||
       ![is_valid_dime $elec_statement(dime_z)] } {
    tk_dialog .errmsg {APBS Tool Error} "Invalid grid dimension: $elec_statement(dime_x) x $elec_statement(dime_y) x $elec_statement(dime_z)" error 0 Dismiss
    return 0
  }

  # (c)gcent
  if { [string equal $elec_statement(cgcent_method) "molid"] } {
    if { [catch {molinfo [string index $elec_statement(cgcent_mol) 0] \
                   get id}] } {
      tk_dialog .errmsg {APBS Tool Error} "Invalid molecule: $elec_statement(cgcent_mol)." error 0 Dismiss
      return 0
    }
  } else {
    if { ![is_real $elec_statement(cgcent_x)] ||
         ![is_real $elec_statement(cgcent_y)] ||
         ![is_real $elec_statement(cgcent_z)] } {
      tk_dialog .errmsg {APBS Tool Error} "Invalid grid center: $elec_statement(cgcent_x), $elec_statement(cgcent_y), $elec_statement(cgcent_z)." error 0 Dismiss
      return 0
    }
  }

  # (c)glen
  if { ![is_real $elec_statement(cglen_x)] ||
       ($elec_statement(cglen_x) <= 0) ||
       ![is_real $elec_statement(cglen_y)] ||
       ($elec_statement(cglen_y) <= 0) ||
       ![is_real $elec_statement(cglen_z)] ||
       ($elec_statement(cglen_z) <= 0) } {
    tk_dialog .errmsg {APBS Tool Error} "Invalid grid lengths: $elec_statement(cglen_x), $elec_statement(cglen_y), $elec_statement(cglen_z)." error 0 Dismiss
    return 0
  }

  if { [string equal $elec_statement(calc_type) "mg-manual"] ||
       [string equal $elec_statement(calc_type) "mg-dummy"] } {
    # nlev must be a positive integer
    if { ![is_integer $elec_statement(nlev)] || 
         ($elec_statement(nlev) <= 0) } {
      tk_dialog .errmsg {APBS Tool Error} "Number of levels must be a positive integer: nlev=$elec_statement(nlev)" error 0 Dismiss
      return 0
    }
  } elseif { [string equal $elec_statement(calc_type) "mg-auto"] ||
             [string equal $elec_statement(calc_type) "mg-para"] } {
    # fgcent
    if { [string equal $elec_statement(fgcent_method) "molid"] } {
      if { [catch {molinfo [string index $elec_statement(fgcent_mol) 0] \
                   get id}] } {
        tk_dialog .errmsg {APBS Tool Error} "Invalid molecule: $elec_statement(fgcent_mol)." error 0 Dismiss
        return 0
      }
    } else {
      if { ![is_real $elec_statement(fgcent_x)] ||
           ![is_real $elec_statement(fgcent_y)] ||
           ![is_real $elec_statement(fgcent_z)] } {
        tk_dialog .errmsg {APBS Tool Error} "Invalid fine grid center: $elec_statement(fgcent_x), $elec_statement(fgcent_y), $elec_statement(fgcent_z)." error 0 Dismiss
        return 0
      }
    }

    # fglen
    if { ![is_real $elec_statement(fglen_x)] ||
         ($elec_statement(fglen_x) <= 0) ||
         ![is_real $elec_statement(fglen_y)] ||
         ($elec_statement(fglen_y) <= 0) ||
         ![is_real $elec_statement(fglen_z)] ||
         ($elec_statement(fglen_z) <= 0) } {
      tk_dialog .errmsg {APBS Tool Error} "Invalid fine grid lengths: $elec_statement(fglen_x), $elec_statement(fglen_y), $elec_statement(fglen_z)." error 0 Dismiss
      return 0
    }

    if {[string equal $elec_statement(calc_type) "mg-para"]} {
      # pdime
      if { ![is_integer $elec_statement(pdime_x)] ||
           ($elec_statement(pdime_x) <= 0) ||
           ![is_integer $elec_statement(pdime_y)] ||
           ($elec_statement(pdime_y) <= 0) ||
           ![is_integer $elec_statement(pdime_z)] ||
           ($elec_statement(pdime_z) <= 0) } {
        tk_dialog .errmsg {APBS Tool Error} "Invalid processor array: $elec_statement(pdime_x), $elec_statement(pdime_y), $elec_statement(pdime_z)." error 0 Dismiss
        return 0
      }
 
      # ofrac
      if { ![is_real $elec_statement(ofrac)] || 
           ($elec_statement(ofrac) <= 0) || ($elec_statement(ofrac) >= 1) } {
        tk_dialog .errmsg {APBS Tool Error} "Mesh overlap must be between 0 an 1: $elec_statement(ofrac)." error 0 Dismiss
        return 0
      }
    }
  } else {
    tk_dialog .errmsg {APBS Tool Error} "Invalid calculation type $elec_statement(calc_type)." error 0 Dismiss
    return 0
  }

  # mol: make sure it's loaded in VMD and has atoms and structure
  if { [catch {molinfo [string index $elec_statement(mol) 0] get id}] ||
       [molinfo [string index $elec_statement(mol) 0] get numatoms] == 0  ||
       [molinfo [string index $elec_statement(mol) 0] get numframes] == 0 } {
    tk_dialog .errmsg {APBS Tool Error} "Invalid molecule: $elec_statement(mol)." error 0 Dismiss
    return 0
  }

  # TODO: Maybe check these; they should always be valid since they're
  # selected from a drop-down menu.
  # lpbe
  # bcfl
  # srfm
  # chgm

  # pdie sdie sdens srad swin temp gamma
  foreach keyword {pdie sdie sdens srad swin temp gamma} {
    if { ![is_real $elec_statement($keyword)] } {
      puts "apbsrun) $keyword invalid"
    }
  }

  # XXX - TODO: writemat, ion.

  return 1
}

# Save the elec statement to current_apbs_config 
# add/edit the entry in the elec_list with the given index
proc ::APBSRun::elec_save {elec_ref} {
  variable elec_win
  variable elec_list
  variable elec_index
  variable elec_current_index
  variable current_apbs_config
  variable apbs_type

  upvar $elec_ref elec_statement 

  # Copy the contents of elec_statement into an element in current_apbs_config

  if {$elec_current_index == $elec_index} {
    # Add an entry to the listbox
    lappend elec_list $elec_current_index
    incr elec_index
    
    # Append the data to current_apbs_config
    lappend current_apbs_config($apbs_type) [array get elec_statement]
  } else {
    # Change an entry in the listbox
    #lset elec_list $index $index

    # Change the data in current_apbs_config
    lset current_apbs_config($apbs_type) $elec_current_index [array get elec_statement]
  }
}

# check existence and readability of output files
proc ::APBSRun::check_maps_ok {} {
  variable output_files
  variable workdir
  variable workdirsuffix

  foreach type $output_files {
    set tf [file join $workdir $workdirsuffix "$type.dx"] 
    if { ![file exists $tf] || ![file readable $tf] || [file size $tf] == 0} {
      puts "apbsrun) Cannot access output file $tf"
      return 0
    }
  }
  return 1
}

# Prompt the user with a list of the maps created by APBS
proc ::APBSRun::prompt_load_maps {} {
  variable main_win
  variable map_win
  variable output_files
  variable load_files
  variable load_files_dest_mol

  # If already initialized, just turn on
  if { [winfo exists $main_win.maps] } {
    wm deiconify $map_win
    return
  }

  set map_win [toplevel "$main_win.maps"]
  wm title $map_win "APBSRun: Load APBS Maps" 
  wm resizable $map_win yes yes

  # Make this window modal.
  grab $map_win
  wm transient $map_win $main_win
  wm protocol $map_win WM_DELETE_WINDOW {
    grab release $::APBSRun::map_win
    after idle destroy $::APBSRun::map_win
  }
  raise $map_win

  label $map_win.label -text "APBSRun: Load APBS Maps"
  pack $map_win.label -side top -anchor nw 

  radiobutton $map_win.loadtopmol \
    -text "Load files into top molecule"  -value "1" \
    -variable ::APBSRun::load_files_dest_mol

  radiobutton $map_win.loadnewmol \
    -text "Load files into a new molecule"  -value "2" \
    -variable ::APBSRun::load_files_dest_mol

  radiobutton $map_win.loadnewmols \
    -text "Load files into separate molecules"  -value "3" \
    -variable ::APBSRun::load_files_dest_mol

  pack $map_win.loadtopmol $map_win.loadnewmol $map_win.loadnewmols -side top -anchor w

  frame $map_win.filelist
  label $map_win.filelist.label -text "Output maps to load:"
  pack $map_win.filelist.label -side top -anchor w

  array unset load_files

  foreach type $output_files {
    set ::APBSRun::load_files($type) 1        ;# default "on"
    checkbutton $map_win.filelist.$type \
      -text $type -variable ::APBSRun::load_files($type) 
    pack $map_win.filelist.$type -side top -anchor w
  }
  pack $map_win.filelist -side top -anchor w

  frame $map_win.buttons
  button $map_win.buttons.okay -text "OK" -width 6 \
    -command {
      ::APBSRun::load_maps
      grab release $::APBSRun::map_win
      after idle destroy $::APBSRun::map_win
    }
  button $map_win.buttons.cancel -text "Cancel" -width 6 \
    -command {
      grab release $::APBSRun::map_win
      after idle destroy $::APBSRun::map_win
    }
  pack $map_win.buttons.okay $map_win.buttons.cancel \
    -side left -fill x -expand yes
  pack $map_win.buttons -side top -anchor nw -padx 4 -pady 4
}


# Load the maps into VMD
proc ::APBSRun::load_maps {} {
  variable load_files
  variable workdir
  variable workdirsuffix
  variable load_files_dest_mol

  if { $load_files_dest_mol == 1 } {
    foreach file [array names load_files] {
      if { $load_files($file) } {
        mol addfile [file join $workdir $workdirsuffix "$file.dx"] type dx
      }
    }
  } elseif { $load_files_dest_mol == 2 } {
    set newapbsmol [mol new]
    mol rename $newapbsmol "APBS Output" 
    foreach file [array names load_files] {
      if { $load_files($file) } {
        mol addfile [file join $workdir $workdirsuffix "$file.dx"] type dx
      }
    }
  } else {
    foreach file [array names load_files] {
      if { $load_files($file) } {
        set newapbsmol [mol new [file join $workdir $workdirsuffix "$file.dx"] type dx]
        mol rename $newapbsmol "APBS $file"
      }
    }
  }
}


# This gets called by VMD the first time the menu is opened.
proc apbsrun_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {after idle destroy $::APBSRun::main_win}] ;# destroy any old windows

  ::APBSRun::apbsrun   ;# start the tool 
  return $APBSRun::main_win
}

