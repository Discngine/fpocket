#
# NAMD job execution plugin
#
# $Id: namdrun.tcl,v 1.21 2006/08/19 20:42:27 johns Exp $
#
# Dispatcher for submitting jobs; looks at the jobtype field of server
# and calls the appropriate routine. SubmitJob returns a "job specification",
# which is a Tcl list that uniquely describes a job and how to kill it.
# The first two items of this list are always the jobtype and hostname of the 
# running job's headnode.
# The following items depend on the job type and should be considered
# internal to NAMDRun (i.e. an external program should not access these
# items as their meaning can change on a whim)
# Alternatively, a value of "none" can be returned indicating that the job
# is complete.

package require exectool 1.2
package provide namdrun 0.3
namespace eval NAMDRun {}

proc NAMDRun::submitJob { server_ exec_command simdir nprocs logname } {
  upvar $server_ server
  if ![info exists server(jobtype)] {
    error "NAMDRun: No job type specified for submitJob"
  }
  set jobtype $server(jobtype)
  if ![namespace exists $jobtype] {
    error "Don't know how to submit a job of type '$jobtype'"
  }
  return [concat $jobtype [${jobtype}::submitJob server $exec_command $nprocs $simdir $logname]]
}


# Dispatcher for aborting jobs.
# It takes as its arg, a job specification return by submitJob
proc NAMDRun::abortJob { jobspec } {
  set jobtype [lindex $jobspec 0]
  if ![namespace exists $jobtype] {
    error "Don't know how to abort a job of type '$jobtype'"
  }
  ${jobtype}::abortJob [lrange $jobspec 2 end] ;# run the appropriate abortJob routine
}




###############################################################
# Namespaces for various types of jobs:
###############################################################


# Job type: none
# Description: does nothing
# Required parameters: none
# Optional parameters: none

namespace eval NAMDRun::none {

  proc submitJob {server_ exec_command nprocs simdir logname} {
    return "none"  ;# blank hostname
  } 
  
  proc abortJob {} {}
  
}



# Job type: local
# Description: runs job on local machine
# Required parameters: none
# Optional parameters: none

namespace eval NAMDRun::local {

  proc submitJob { server_ exec_command nprocs simdir logname } {
    #upvar $server_ server
    #if ![info exists server(namdbin)] {
    #  error "Server must specify NAMD location in 'namdbin'."
    #}
    
    set curdir [pwd]
    cd $simdir
    set executable [format $exec_command $nprocs]
    if [catch {set pid [eval ::ExecTool::exec $executable >& $logname &]} msg] {
      cd $curdir
      error $msg
    }
    cd $curdir
    
    return [list localhost $pid]
  }

  proc abortJob { procid } {
    exec kill $procid
  }

}



# Job type: localdqs
# Description: runs job through dqs on the local file system
#
# Required parameters: 
#   dqsflags - additional dqs flags specifying resources

namespace eval NAMDRun::localdqs {

  proc submitJob {server_ exec_command nprocs simdir logname} {
    upvar $server_ server
    set executable [format $exec_command $nprocs]
    set dqsflags [format "$server(dqsflags) -N autoimd" $nprocs]

    set submitfilename [file join $simdir submit.sh]
    set submitfile [open $submitfilename w]
    puts $submitfile "#!/bin/sh"  ;# very important to specify shell
    puts $submitfile "cd $simdir"
    puts $submitfile "$executable > $logname"
    close $submitfile
    set cmd "qsub $dqsflags $submitfilename"
    puts "NAMDRun) Submitting job: $cmd"
    
    # Parse "[Yy]our job 123 [("jobname")] has been submitted."
    scan [eval exec $cmd] "%*s job %d" procid 
    
    # Wait a period of time for log file to get created
    set logpath [file join $simdir $logname]
    set foundlog no
    for { set i 0 } { $i < 40 } { incr i } {
      if [catch {set fd [open $logpath a+]}] {
        # log file doesn't exist yet
        after 500
      } else {
        set foundlog yes
        break
      }
    }
    if !$foundlog {
      abortJob $procid
      error "Could not find the NAMD log file. Timeout expired!"
    }
    
    # Attempt to read the hostname out of the logfile
    for { set i 0 } { $i < 20 } { incr i } {
      after 1500
      # read what's there until we get to the info we're looking for
      while { [gets $fd line] != -1 } {
        #puts "NAMDRun) $line"  ;# XXX for debugging purposes
        if [scan $line "TCL: AUTOIMD HOST: %s PID %*d" run_host] { 
          close $fd
          return [list $run_host $procid]
        }
      }
    }
    abortJob $procid
    error "Could not get host name. Timeout expired! (This may happen if job takes too long to start, or does not start, after it has been submitted to the queue.)"
  } 
  
  proc abortJob { procid } {
    if ![string length $procid] {
      return "NAMDRun) Tried to delete queued job with invalid id"
    }
    
    exec qdel $procid &
  }
}



# Job type: remote
# Description: runs job through ssh on a remote machine.  You'll have to
# set up ssh so that it doesn't prompt for a password.  
# Required parameters:
#   remotedir - directory on remote machine to put files
#   remotelogin - username on remote machine

namespace eval NAMDRun::remote {

  proc submitJob {server_ exec_command nprocs simdir logname} {
    upvar $server_ server
    set remotedir $server(remotedir)
    set user $server(remotelogin)
    set host $server(host)

    # Create directory on remote machine
    puts "NAMDRun) Creating directory $remotedir on remote machine $host"
    exec ssh ${user}@${host} "mkdir -p $remotedir"

    # copy files
    NAMDRun::uploadFiles $user $host $simdir $remotedir

    # Launch executable
    set executable [format $exec_command $nprocs]
    cd $simdir
    exec ssh -f ${user}@${host} "cd $remotedir; $executable" >& $logname

    # Wait a period of time for stuff to show up in the log file.  
    set fd [open $logname r]
    for { set i 0 } { $i < 10 } { incr i } {
      after 1500
      # read what's there until we get to the info we're looking for
      while { [gets $fd line] != -1 } {
        puts "NAMDRun) $line"
        if { [scan $line "TCL: AUTOIMD HOST: %s PID: %d" run_host run_procid] == 2 } { 
          return [list $run_host $user $host $run_procid]
        }
      }
    }
    puts "NAMDRun) NAMD failed to start!"
    return "none"
  } 

  proc abortJob { user host procid } {
    exec ssh -f ${user}@${host} kill $procid
  }
}




namespace eval NAMDRun::remotedqs {

  proc submitJob {server_ exec_command nprocs simdir logname} {
    upvar $server_ server
    set remotedir $server(remotedir)
    set user $server(remotelogin)
    set host $server(host)
    
    set locallog [file join $simdir $logname]

    set nnodes $nprocs
    if [info exists server(procspernode)] {
      set nnodes [expr int(ceil(double($nprocs)/$server(procspernode)))]
    }
    set dqsflags [format "$server(dqsflags) -N autoimd" $nnodes]


    # copy files
    file delete $locallog
    close [open $locallog w] ;# touch $locallog
    NAMDRun::uploadFiles $user $host $simdir $remotedir

    # set up transfer of logfile to local disk through the Tcl event loop
    # (pretty nice, eh?)
    set localfd [open $locallog w]
    set remfd [open "|ssh -f ${user}@${host} \"tail -f [file join $remotedir $logname] &\"" r]
    set tailpid [lindex [gets $remfd] end]
    fcopy $remfd $localfd -command [list [namespace current]::endTail $localfd]

    # Launch executable
    set executable [format $exec_command $nprocs]
    set cmdfd [open "|echo \"cd $remotedir; $executable >> $logname\" | ssh ${user}@${host} qsub $dqsflags" r]
    set line [gets $cmdfd]
    if { [scan $line "your job %d has been submitted" procid] != 1 } {
      puts "NAMDRun) Could not understand output from qsub command:"
      puts "NAMDRun) '$line'"
      puts "NAMDRun) Job submission failed."
      abortJob $user $host $procid $tailpid
      return "none"
    }

    # Wait for hostname information to show up in the log file.
    set fd [open $locallog r]
    for { set i 0 } { $i < 10 } { incr i } {
      after 1500
      update ;# fcopy needs a running event loop in order to transfer data
      while { [gets $fd line] != -1 } {
        puts "NAMDRun) $line"
        if { [scan $line "TCL: AUTOIMD HOST: %s PID: %d" run_host run_procid] == 2 } { 
          return [list $run_host $user $host $procid $tailpid]
        }
      }
    }
    puts "NAMDRun) NAMD failed to start!"
    abortJob $user $host $procid $tailpid
    return "none"
  } 

  proc abortJob { user host procid tailpid} {
    # I call qdel three times because it doesn't always work the first time
    exec ssh -f ${user}@${host} "kill $tailpid; qdel $procid ; qdel $procid ; qdel $procid" &
  }
 
  proc endTail { args } {
    foreach { fd bytes } $args { break }
    # close the file descriptor to the local logfile so that remaining 
    # data gets flushed.
    close $fd
    puts "NAMDRun) $bytes bytes written to logfile."
    if { [llength $args] > 2 } {
      puts "NAMDRun) Error writing NAMD logfile: [lrange $args 2 end]"
    }
  }
}


###############################################################
# General-purpose commands for NAMDRun internal use
###############################################################

# Upload simdir to remote location using scp
proc NAMDRun::uploadFiles {user host localdir remotedir} {
    puts "NAMDRun) Creating directory $remotedir on remote host $host"
    exec ssh ${user}@${host} "mkdir -p $remotedir"
    
    puts "NAMDRun) Uploading files to remote host $host"
    eval exec scp -C [glob [file join $localdir *]] ${user}@${host}:$remotedir
    puts "NAMDRun) Done copying files"
}




