#
# AutoIMD
#
# $Id: autoimd.tcl,v 1.96 2007/05/19 19:09:34 jordi Exp $
#
# Authors: Paul Grayson, Jordi Cohen, Justin Gullingsrud
# Maintainer: Jordi Cohen
#
# This package requires a VMD version >= 1.8
# Call "autoimd" to create the AutoIMD window

#
# TODO: handle user errors more gracefully.
#       presently, if the user loads just a PSF, and then tries to submit
#       a job, the script gets an internal error from a failed atom selection
#       because the molecule has no frames (no coordinates loaded yet)
#

package require namdrun 0.2
package require psfgen

package provide autoimd 1.6

namespace eval AutoIMD {
  global env
 
  # The "settings" namespace contains variables that can be set externally 
  namespace eval settings {
    variable scratchdir     ""
    variable namdtmplfile   [file join $env(AUTOIMDDIR) autoimd-template.namd]
    variable parfiles       {}
      
    ##variable presubmitscript
    variable namdscript     {}
  
    variable moltenseltext  ""
    variable fixedseltext   "within 8 of imdmolten"
    
    variable namdoutputrate 1 ;# ratio of steps sent by NAMD
    variable dcdfreq 0        ;# ratio of steps saved to DCD (0 = none)
    variable vmdkeepfreq 0    ;# ratio of steps saved kept by VMD (0 = none)
    
    variable sim_mode       "equilibrate" ;# allows different types of NAMD jobs
    variable minimizesteps  100        ;# no. of timesteps to minimize
    variable runsteps       1000000    ;# no. of timesteps to run
    variable temperature    300        ;# temperature of the sim

    variable imdrep {
      mol representation Bonds 0.300000 6.000000
      mol color Name
      mol selection "imdprotein and noh"
      mol material Opaque
      mol addrep $imdmol

      mol representation Bonds 0.300000 6.000000
      mol color Name
      mol selection "imdwater"
      mol material Opaque
      mol addrep $imdmol
      
      mol representation VDW 1.000000 8.000000
      mol color ColorID 4
      mol selection "imdhetero"
      mol material Opaque
      mol addrep $imdmol
    }
  }
  
  
  # Define internal/private variables
  variable backgroundmol  -1
  variable imdmol         -1   ;# molecule ID of the live IMD simulation  
  variable startmol       top  ;# molecule ID for the initial coordinates 

  variable imdstate       "uninitialized"
  
  variable imdhost
  variable imdcurrenthost ;# The actual host the simulation is running on (cached).
  variable imdport
  variable imdcurrentport
  variable imdjobspec     ;# IMD job specification returned by NAMDRun
  variable numprocs       ;# gui-settable number of processors to use
  variable psffile
  variable pdbfile

  # text variable associated with server chooser
  variable currentserver 
  variable namdbin
  variable maxprocs
  variable connectiontimeout  ;# seconds till stops attempting to connect
  
  variable statustext
  variable w
  
  namespace eval servers {} ;# create the "servers" namespace
}





# Must be run before everything else
proc AutoIMD::startup {} {
  variable w
  variable currentserver
  
  # If already initialized, just deiconify and return
  if { [winfo exists .autoimd] } {
    wm deiconify $w
    raise $w
    return
  }
  
  atomselect macro imdmolten "none"
  atomselect macro imdexclude "all"
    
  atomselect macro imdfixed "none"
  atomselect macro imdwater "none"
  atomselect macro imdhetero  "none"
  atomselect macro imdprotein "none" 
  
  startGUI
  
  setstate "uninitialized"
  loadsettings $AutoIMD::currentserver
}
  
  

proc AutoIMD::loadsettings { servername } {
  variable w
  variable numprocs
  variable maxprocs
  variable connectiontimeout
  variable imdport
  variable namdbin
    
  # Test that this is not needed  
  ##if { "$AutoIMD::imdstate" != "uninitialized"} {
  ##  error "Cannot change setup while simulation is running!"
  ##}

  #XXX deal with in-server "presumbitscript" here

  #XXX do this a bit differently:
    
  if [info exists servers::$servername] {
    upvar AutoIMD::servers::$servername arr
    # if required values weren't specified, then use defaults...
    if ![info exists arr(numprocs)] {set numprocs 1          ;# numprocs
    } else { set numprocs $arr(numprocs)}
    if ![info exists arr(maxprocs)] {set maxprocs 1          ;# maxprocs
    } else { set maxprocs $arr(maxprocs)}
    if ![info exists arr(timeout)] {set connectiontimeout 15 ;# timeout
    } else { set connectiontimeout $arr(timeout)}
    if ![info exists arr(imdport)] {set imdport "random"     ;# imdport
    } else { set imdport $arr(imdport)}
    if ![info exists arr(namdbin)] {set namdbin "/usr/local/bin/namd2" ;# namdbin
    } else { set namdbin $arr(namdbin)}
  }
  
  set AutoIMD::currentserver $servername
}

 
# keep track of the state
# uninitialized, initialized, submitted, ready, connected
proc AutoIMD::setstate { newstate } {
  variable imdstate
  variable w

  $w.win.controls.submit configure -state disabled
  $w.win.controls.connect configure -state disabled
  $w.win.controls.pause configure -state disabled
  $w.win.controls.finish configure -state disabled
  $w.win.controls.discard configure -state disabled
  $w.win.procs.server.servermenu configure -state disabled

  if { $newstate == "uninitialized" } {
    AutoIMD::showstatus "Waiting for user input"
    set imdstate $newstate
    $w.win.controls.submit configure -state normal
    $w.win.procs.server.servermenu configure -state normal
  } elseif { $newstate == "waitforsubmit" } { ;# waiting to be submitted
    AutoIMD::showstatus  "Ready to submit"
    set imdstate $newstate
    $w.win.controls.submit configure -state active
  } elseif { $newstate == "ready" } {  ;#ready to be connected
    AutoIMD::showstatus "Ready to connect"
    set imdstate $newstate
    $w.win.controls.connect configure -state normal
    $w.win.controls.discard configure -state normal
  } elseif { $newstate == "connected" } {
    AutoIMD::showstatus "Connected to simulation"
    set imdstate $newstate
    $w.win.controls.pause configure -state normal
    $w.win.controls.finish configure -state normal
    $w.win.controls.discard configure -state normal
  } else {
    error "Unknown state: $newstate"
  }
  
  #update display:
  #update idletasks  
}


# save the reps that the user set
proc AutoIMD::get_reps { {mol top} } {
  set ret ""
  for {set i 0} {$i < [molinfo $mol get numreps]} {incr i} {
    append ret "mol representation [molinfo $mol get "\"rep $i\""]\n"
    append ret "mol color [molinfo $mol get "\"color $i\""]\n"
    append ret "mol selection [molinfo $mol get "\"selection $i\""]\n"
    append ret "mol material [molinfo $mol get "\"material $i\""]\n"
    append ret "mol addrep top\n"
    append ret "mol showrep top $i [mol showrep $mol $i]\n"
    append ret "mol drawframes top $i [mol drawframes $mol $i]\n"
    append ret "\n"
  }
  return $ret;
}



# delete all the reps of mol <mol>
proc AutoIMD::delreps { mol } {
  while { [molinfo $mol get numreps] > 0 } {
    mol delrep 0 $mol
  }
}


proc AutoIMD::savestructure { } {
    global errorInfo errorCode
    set oldcontext [psfcontext new]  ;# new context
    set errflag [catch { AutoIMD::savestructure_core } errMsg]
    set savedInfo $errorInfo
    set savedCode $errorCode
    psfcontext $oldcontext delete  ;# revert to old context
    if $errflag { error $errMsg $savedInfo $savedCode }
}

proc AutoIMD::savestructure_core { } {
  variable psffile
  variable pdbfile
  variable backgroundmol

  AutoIMD::showstatus "Loading structure and coordinates..."
	
  resetpsf
  readpsf $psffile
  
  AutoIMD::showstatus "Generating reduced psf/pdb files..."
  set sel [atomselect $backgroundmol "imdexclude"]
  set deletelist [$sel get {segname resid}]
  $sel delete
  
  set previtem {null 0}
  foreach item $deletelist {
    if {$item == $previtem} continue
    set previtem $item
    delatom [lindex $item 0] [lindex $item 1]
  }

  writepsf [file join "$settings::scratchdir" autoimd.psf]
  
  set imdsel [atomselect $backgroundmol "not imdexclude"]
  set savebeta [$imdsel get beta] ;# save old values
  $imdsel set beta 0
  set imdfixedsel [atomselect $backgroundmol "imdfixed"] 
  $imdfixedsel set beta 1
  $imdsel writepdb [file join "$settings::scratchdir" autoimd.pdb]
  $imdsel set beta $savebeta ;# restore old values
  
  $imdsel delete
  $imdfixedsel delete
}



proc AutoIMD::generate_namd_conf { } {
  variable imdport
  variable imdcurrentport
  variable currentserver

  AutoIMD::showstatus "Generating NAMD config file..."
	
  if {"$AutoIMD::imdport" == "random"} {
    set imdcurrentport [expr int(rand()*5000+2000)]
  } else {
    set imdcurrentport $AutoIMD::imdport
  }
  
  set shortparfiles {}
  foreach filepath $settings::parfiles {
    lappend shortparfiles [file tail $filepath]
  }
      
  # open up the conf file for writing
  set conffile [open [file join "$settings::scratchdir" autoimd.namd] w]
  
  puts $conffile "set paramfile_list \{$shortparfiles\}" 
  puts $conffile "set imdport $imdcurrentport" 
  puts $conffile "set sim_mode $settings::sim_mode" 
  puts $conffile "set namdoutputrate $settings::namdoutputrate" 
  puts $conffile "set dcdfreq $settings::dcdfreq" 
  puts $conffile "set temperature $settings::temperature" 
  
  if { "$settings::sim_mode" == "minimize" }  {
    puts $conffile "set minimizesteps 1000000" 
  } else { 
    puts $conffile "set minimizesteps $settings::minimizesteps" 
  }
  puts $conffile "set runsteps $settings::runsteps" 
  
  puts $conffile "set MYSCRIPT \{$settings::namdscript\}"
          
  # copy over the predefined NAMD config. template
  set templatefile [open "$settings::namdtmplfile" r]
  puts $conffile [read "$templatefile"]
  close $templatefile
  
  close $conffile
}



proc AutoIMD::load_imd_molecule { } {
  variable imdmol
  variable backgroundmol

  AutoIMD::showstatus "Reloading the view..."
		
  # now load the new molecule
  set viewpoint [molinfo $backgroundmol get { \
      center_matrix rotate_matrix scale_matrix global_matrix}]
  display update off

  mol load psf [file join "$settings::scratchdir" autoimd.psf] pdb [file join "$settings::scratchdir" autoimd.pdb]
  set imdmol [molinfo top]
  mol rename $imdmol "AutoIMD Simulation"

  foreach mol [molinfo list] {
    molinfo $mol set {
      center_matrix rotate_matrix scale_matrix
      global_matrix
    } $viewpoint
  }
  display update on
}



proc AutoIMD::autoconnect {} {
  variable connectiontimeout
  variable imdcurrentport
  variable imdmol
  variable imdhost
  
  set attempt_delay 1500   ;# delay between attepmts to connect in ms
  set attempt_timeout [expr $connectiontimeout * 1000] ;# timeout in ms
   
  mol top $imdmol
  
  AutoIMD::showstatus "Trying to connect (waiting for NAMD)..."
  
  for { set timecounter 0 } { $timecounter <= $attempt_timeout } {incr timecounter $attempt_delay} {
    if ![catch { imd connect $imdhost $imdcurrentport }] {
      imd keep $::AutoIMD::settings::vmdkeepfreq
      setstate "connected"
      trace add variable ::vmd_timestep($imdmol) write AutoIMD::tracetimestep
      return
    }
    # else give NAMD more time
    after $attempt_delay
  }
  
  
  puts "##################################################################"
  puts ""
  puts "LOGFILE ERRORS:"
  set file [open [file join $settings::scratchdir autoimd.log] "r"]
  set errmsg ""
   
  while {[gets $file line] != -1} {
    if [regexp "^Reason:" $line] {
      set errmsg $line
      puts "$line"
    }
  }
  close $file
  puts ""
  
  error "Attempt to connnect to the simulation timed out!\n\nNAMD Logfile:\n$errmsg" -type ok

}


# XXX Old unused method
proc AutoIMD::connect { } {
  mol top $AutoIMD::imdmol
  foreach host $AutoIMD::hosts {
    if {! [catch { imd connect $host $AutoIMD::imdcurrentport }]} {
      imd keep $::AutoIMD::settings::vmdkeepfreq
      setstate "connected"  ;# success!
    }
  }
}



proc AutoIMD::add_exclude_to_background { } {
  variable backgroundmol
  for {set i 0} {$i < [molinfo $backgroundmol get numreps]} {incr i} {
    set sel [lindex [molinfo $backgroundmol get "\"selection $i\""] 0]
    if { [lindex $sel [expr [llength $sel]-1]] != "imdmolten" } {
      set newsel "($sel) and not imdmolten"
      mol modselect $i $backgroundmol $newsel
    }
  }
 }
 
  

proc AutoIMD::restore_background {} {
  mol top $AutoIMD::backgroundmol
  
  atomselect macro imdmolten "none"
  atomselect macro imdexclude "all"
    
  atomselect macro imdfixed "none"
  atomselect macro imdwater "none"
  atomselect macro imdhetero  "none"
  atomselect macro imdprotein "none"    
      
  redrawbackgroundrep
}


proc AutoIMD::redrawbackgroundrep {} {
  variable backgroundmol

  for {set i 0} {$i < [molinfo $backgroundmol get numreps]} {incr i} {
    mol modselect $i $backgroundmol \
        [lindex [molinfo $backgroundmol get "\"selection $i\""] 0]
  }
}


# initialize the system IF necessary
proc AutoIMD::initparams {} {
  variable pdbfile
  variable psffile
  variable imdmol 
  variable backgroundmol 
  variable startmol
  variable imdstate
  variable w
  
  setstate "waitforsubmit"
  AutoIMD::showstatus "Initializing AutoIMD..."

  # Require a scratch directory
  if ![file exists $settings::scratchdir] {
    set answer [tk_messageBox -message "Your AutoIMD scratch directory \($settings::scratchdir\) does not exist! Do you want AutoIMD to try to create it for you? (Click No if you wish to create it yourself.)" -type yesno -default "yes" -parent $w -icon question]
    if {"$answer" == "yes"} {
      if [catch {file mkdir $settings::scratchdir}] {
        setstate "uninitialized"
        error "Could not create the directory \($settings::scratchdir\). Please setup your AutoIMD scratch directory."
      }
    } else {
      setstate "uninitialized"
      return false
    }
  }

  set AutoIMD::pdbfile [file join $settings::scratchdir autoimd_final.pdb]
  
  set psffile ""
  foreach filename [lindex [molinfo $startmol get filename] 0] filetype [lindex [molinfo $startmol get filetype] 0] {
  # make sure to get the *last* psf file in the list
    if {![string compare "$filetype" "psf"]} {
      set psffile "$filename"
    }
  }
  # make sure that we have a PSF - we need this for psfgen
  if { "$psffile" == "" } {
    setstate "uninitialized"
    error "You must have a PSF file loaded."
  }
		
  set backgroundmol [molinfo $startmol]

  # Make the initial finishfile.
  set all [atomselect $backgroundmol all]
  if { [ file exists $pdbfile ] } {
    file rename -force "$pdbfile" "$pdbfile.BAK"
  }
  $all writepdb "$pdbfile"
  $all delete

  # copy paramfiles
  foreach filepath $settings::parfiles {
    set localfilepath "[file join "$settings::scratchdir" "[file tail $filepath]"]" 
    if {"$filepath" != "$localfilepath"} {
      file copy -force "$filepath" "$localfilepath"
    }
  }
  
  # make the background molecule look right
  add_exclude_to_background
  
  return true
}



proc AutoIMD::submit { seltext } {
  variable pdbfile
  variable pdbfile
  variable imdmol
  variable backgroundmol
  variable namdbin
  variable currentserver
  variable numprocs
  variable imdjobspec
  variable imdhost
    
  if ![initparams] return
  
  if [catch {      
    atomselect macro imdmolten "\{$seltext\}"
   }] {
    setstate "uninitialized"
    error "Invalid selection for imdmolten: $seltext"
  }
  
  # check validity of fixed atoms text selection:
  if [catch {      
    atomselect macro imd_tmp_test "\{$settings::fixedseltext\}"
    atomselect delmacro imd_tmp_test
   }] {
    setstate "uninitialized"
    error "Invalid selection for imdfixed: $settings::fixedseltext"
  }
  
  if [catch {  
    # check that molten selection is not empty (to prevent later nastiness):
    set testsel [atomselect $backgroundmol imdmolten]
    if {[$testsel num] == 0} {error "IMD atom selection contains no atoms!"}
    $testsel delete
    
    #The extra words around fixedseltext are necessary for the proper functioning of AutoIMD.   
    atomselect macro imdfixed "(same residue as (\{$settings::fixedseltext\} or imdmolten)) and not imdmolten"
    atomselect macro imdexclude "not imdfixed and not imdmolten"
    
    atomselect macro imdwater   "imdmolten and water"
    atomselect macro imdprotein "imdmolten and (protein or nucleic)"   
    atomselect macro imdhetero  "imdmolten and not imdwater and not imdprotein"
  } mesg ] {
    setstate "uninitialized"
    error "$mesg"
  }

  # the current coordinates are in pdbfile, so we are ready!
  savestructure
  generate_namd_conf

#  set scripterr [catch {eval $AutoIMD::presubmitscript} msg]
#  if {$scripterr == 1} {
#    setstate "uninitialized"
#    error "Error in AutoIMD::presubmitscript.\n$msg"
#  }
#  if {$scripterr == 2} { ;#relay "return" from presubmitscript
#    setstate "uninitialized"
#    return
#  } 


  AutoIMD::showstatus "Submitting your job..."

  if [catch {
    file delete [file join $settings::scratchdir autoimd.log] 
    set exec_command "$namdbin autoimd.namd"
    set imdjobspec [NAMDRun::submitJob servers::$currentserver $exec_command $settings::scratchdir $numprocs autoimd.log] 
  } msg] {
    restore_background
    setstate "uninitialized"
    dialog_error "There was an error while submitting your job:\n\n$msg"
    return
  }
  
  # No error; continue
  puts "submitJob returned $imdjobspec"
  if [string equal [lindex $imdjobspec 1] "none"] {
    # Nothing more to do; this server didn't actually run a simulation
    setstate "uninitialized"
    return
  }
  set imdhost [lindex $imdjobspec 1]


if {0} { ;# Old code
  if [catch { 
    set AutoIMD::imdjobspec [eval NAMDRun::submitJob "$settings::scratchdir" \"$AutoIMD::namd_args\" "autoimd" "autoimd.namd" "autoimd.log"]
  } msg] {
    restore_background
    setstate "uninitialized"
    error $msg
  }
}
  
  load_imd_molecule  
    
  # set up a nice view
  redrawbackgroundrep
    
  # set up a nice representation
  mol delrep all $imdmol
  eval $settings::imdrep
    
  setstate "ready"
}


# This kills the IMD connection
proc AutoIMD::killsimulation {} {
  variable imdstate
  variable imdjobspec

  if { $imdstate == "connected" } {
    catch {imd kill}
  }
  
  NAMDRun::abortJob $imdjobspec
  
  # This is here bc there are still cases in which a sim does not get properly deleted
  puts "Please make sure that the simulation has been properly killed!"
}



proc AutoIMD::finish { args } {
  variable pdbfile
  variable imdmol
  
  if [ catch {  
  trace vdelete vmd_timestep($imdmol) w AutoIMD::tracetimestep

  # parse arguments  
  set savefile yes ;# update coords of background molecule?
  foreach arg $args {
    if {![string compare "$arg" "-nosave"]} {set savefile no}
  }
  
  if { [catch {killsimulation} msg] } {
    puts "Error killing simulation.\n$msg"
  }  

  set settings::imdrep [get_reps $imdmol]

  if { "$savefile" == "yes" } {
    if { [ file exists $pdbfile ] } { file rename -force "$pdbfile" "$pdbfile.BAK" }
    writecompletepdb $pdbfile -updatecoords
  }
  
  AutoIMD::showstatus "Cleaning up..."
    
  mol delete $imdmol
  restore_background
  } msg] {
    tk_messageBox -parent $AutoIMD::w -title "AutoIMD Error" -message  "Could not save final coordinates!\n$msg" -type ok
  }
  
  puts "Done with AutoIMD."
  # Must run the following lines even if an error has occured
  setstate "uninitialized"
}



# Saves a copy of the "complete" coordinates to a PDB file
proc AutoIMD::writecompletepdb {pdbfilename args} {
  if [ catch {
  variable imdmol
  variable backgroundmol

  if { "$pdbfilename" == "" } return

  # parse arguments  
  set updatecoords no ;# update coords of background molecule?
  foreach arg $args {
    if {![string compare "$arg" "-updatecoords"]} {set updatecoords yes}
  }
  
  AutoIMD::showstatus "Saving coordinates to file..."
  set updatesel [atomselect $backgroundmol "not imdexclude"]
  if { "$updatecoords" == "no" } {set oldcoords [$updatesel get {x y z}]} ;#make backup of coords
  
  # save the coords to file
  $updatesel set {x y z} [[atomselect $imdmol all frame last] get {x y z}]
  $updatesel delete
  set all [atomselect $backgroundmol all] 
  $all writepdb "$pdbfilename"
  $all delete
  
  if {"$updatecoords" == "no"} {$updatesel set {x y z} $oldcoords} ;#reinstate the old coordinates
  } msg] {
    tk_messageBox -parent $AutoIMD::w -title "AutoIMD Error" -message "Could not save final coordinates!\n$msg" -type ok
  }
}


# This line loads additional code when the package is loaded
source [file join $env(AUTOIMDDIR) autoimd-api.tcl]
source [file join $env(AUTOIMDDIR) autoimd-gui.tcl]
source [file join $env(AUTOIMDDIR) autoimd-settings.tcl]


# Load system-wide AutoIMD config file
if {[info exists env(VMDAUTOIMDRC)] && [file exists $env(VMDAUTOIMDRC)]} {
  set err [catch {source $env(VMDAUTOIMDRC)} msg]
  if $err {puts "Error reading env(VMDAUTOIMDRC): $msg."}
}

