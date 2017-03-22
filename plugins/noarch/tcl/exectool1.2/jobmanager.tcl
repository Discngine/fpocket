package provide jobmanager 1.0

namespace eval JobManager {
  namespace eval jobs {}  ;# namespace for storing jobs descriptions
  if ![info exists jobcount] {variable jobcount 0}   ;# keeps track of job number (for naming)
}


###############################################################
# List of Job Manager Calls
###############################################################

# SubmitJob
#
# Dispatcher for submitting a job. It returns a "job identifier", which can be passed
# as an argument to subsequent JobManager calls. This job identifier should then be
# deleted with AbortJob
#required parameters:
#  servervar <server array's name>  # server describing where and how to run
#  cmd       <string>               # command to be executed
#optional parameters:
#  -dir      <dir path>             # temp dir in which local files are stored (absolute path)
#  -procs    <integer>              # override numprocs to use (for parallel programs)
#  -logname  <filename>             # override filename for stdout/stderr
#  -in       <list of filenames>    # NOT IMPLEMENTED YET list of input files to transfer (or else ALL files in dir are copied)
#  -out      <list of filenames>    # NOT IMPLEMENTED YET list of output files to tranfer back
#  -name     <string>               # NOT IMPLEMENTED YET a short identifier for this type of job (e.g, "apbs", "autoimd")
#NOTE: _all_ filenames must be relative to "dir"

proc JobManager::SubmitJob { server_ cmd args } {
  upvar $server_ server
  
  if ![info exists server(jobtype)] {
    error "JobManager) No job type specified for submitJob"
  }
  
  set jobtype $server(jobtype)
  if { ![namespace exists $jobtype] } {
    error "JobManager) Don't know how to submit a job of type '$jobtype'"
  }

  set jobid [new_job]
  upvar $jobid job
  
  #set default values first so that submitJob could override them if desired...  
  set job(type)    $jobtype
  set job(logname) "log"
  set job(status)  "waiting"         ;# not started yet
  set job(monitor) "none"            ;# method used to monitor job progress      
  if [info exists server(numprocs)] { set job(procs) $server(numprocs)}
    
  foreach {key val} $args { 
    # XXX this is a quick hack, eventually will be a switch on acceptable values
    set job([string trimleft $key "-"]) $val
  }
     
  set curdir [pwd]
  set err [catch { 
    cd $job(dir)
    ${jobtype}::submitJob server $cmd $jobid
    
    if {$job(monitor) == "pipe"} { ;# create logfile and start watching pipe output
      set job(outchannel) [open $job(logname) w]
      fconfigure $job(outchannel) -buffering line
      fileevent $job(inchannel) readable [list JobManager::pipe_monitor $jobid]
    }
    
    if {$job(monitor) == "watchfile"} { ;# start watching watchfile
      #fconfigure $job(watchchannel) -blocking no ;# not needed anymore
      fileevent $job(watchchannel) readable [list JobManager::watchfile_monitor $jobid]
    }        
        
  } errmsg] 
  cd $curdir
  
  if {$err} {
    catch {${job(type)}::abortJob $jobid}
    delete_job $jobid
    error "JobManager) Error submitting Job:\n$errmsg."
  }
  
  return $jobid
}



# AbortJob
#
# Dispatcher for deleting and/or halting a job. It takes a "job identifier" 
# returned by SubmitJob

proc JobManager::AbortJob { jobid } {
  if ![info exists $jobid] return   ;# dont produce error for non-existing job
  upvar $jobid job
  
  if {$job(status) == "done"} { ;# job is not running
    delete_job $jobid
    return 
  }
  
  if {$job(monitor) == "pipe"} { ;# close pipe-related channels
    catch {close $job(inchannel)}   ;# very important step!!!
    catch {close $job(outchannel)}
  }

  if {$job(monitor) == "watchfile"} { ;# close pipe-related channels
    catch {close $job(watchchannel)}
  }
    
  set err [catch {
    if ![namespace exists $job(type)] {
      error "Don't know how to abort a job of type '$jobtype'"
    }

    ${job(type)}::abortJob $jobid ;# run the appropriate abortJob routine
  } errmsg]
  
  delete_job $jobid
  
  if {$err} {error "JobManager) Error aborting Job:\n$errmsg"}
}



# GetJobStatus
#
# Returns the internal status of the current job: 
#   done:    job is not running 
#   running: job is still running (from JobManager's point of view)
#   dead:    job was deleted or not successfully created

proc JobManager::GetJobStatus { jobid } {
  if ![info exists $jobid] {return "dead"}
  upvar $jobid job
  
  return $job(status)
}



# NotifyWhenDone
#
# Calls the given callback script (in the global namespace) when the job finishes

proc JobManager::NotifyWhenDone { jobid callback } {
  upvar $jobid job

  if {"$job(status)" == "done"} {  ;# job is done call callback immediately
    DownloadFiles $jobid  ;# make sure requested files are available to the calling program
    namespace inscope :: $callback
    AbortJob $jobid
  } else {
    set job(jobdone_callback) $callback
  }
}



# NotifyWhenStart
#
# Calls the given callback script (in the global namespace) when the job starts (e.g. a job in a queue)

proc JobManager::NotifyWhenStart { jobid callback } {
  upvar $jobid job

  if {"$job(status)" != "waiting"} {  ;# job has started, call callback immediately
    namespace inscope :: $callback
  } else {
    set job(jobstart_callback) $callback
  }
}



# Upload the localdir contents OR the "in" files (if defined) to the remote location
# XXX TODO add option for specifying specific files
proc JobManager::UploadFiles {jobid args} {
  if ![info exists $jobid] return
  upvar $jobid job
  
  return ;# <== XXX remove this!!!
  # XXX This code is not wired for now...
}



# Download all the "out" files (if defined) from the remotedir back to the localdir
# XXX TODO add option for specifying specific files
proc JobManager::DownloadFiles {jobid args} {
  if ![info exists $jobid] return
  upvar $jobid job
  
  return ;# <== XXX remove this!!!
  # XXX This code is not wired for now...
 }



# GetRunHost
#
# Returns the name of the host on which the jobs is currently running. The job must have 
# already started, or else this returns an error.

proc JobManager::GetRunHost { jobid } {
  upvar $jobid job

  after 1500  ;#XXX TODO replace this with a "NotifyWhenStart" API call
  
  if ![info exists job(run_host)] {error "JobManager) Cannot determine job's host"}
  return $job(run_host)
}


###############################################################
# Namespaces for various types of jobs:
###############################################################

# submitJob - starts a new job, and if sets monitor=pipe, pipes the output into job(inchannel)
#             (does not worry about cd'ing to job(dir) or deleting the job in case of an error)

# typical common members of a job:
#   run_host   - name of head node on which job is running (e.g., for socket connections)
#   status     - "running"; "done"; "dead"
#   monitor    - "none": cant detect if job ended; "pipe": have direct access to stdout; 
#                "watchfile": sandwich commands around queued jobs to indicate when the job is done
#                "query": server-specific periodic query (NOT IMPLEMENTED UNLESS NEEDED)
#   inchannel  - if monitor=pipe, channel is the channelid of the stdout pipe
#   outchannel - if monitor=pipe, channel is the channelid for writing the logfile
#   watchname  - if monitor=watchfile, watchname is the filename of the watchfile
#   watchchannel - if monitor=watchfile, channel is the channelid for the open watchfile


###############################################################
# Job type: none
# Description: does nothing

namespace eval JobManager::none {

  proc submitJob { server_ cmd jobid } {
    upvar $jobid job
    set job(status) "done"  ;# no job is run
  } 
  
  proc abortJob  { jobid } {}
  
}



###############################################################
# Job type: local
# Description: runs job on local machine

namespace eval JobManager::local {

  proc submitJob { server_ cmd jobid } {
    upvar $jobid job
    set job(monitor)  "pipe"
    set job(run_host) "localhost"
      
    set execstr [format $cmd $job(procs)]
    set job(inchannel) [open  [concat | $execstr ] "r"]
    set job(procid)   [pid $job(inchannel)]
    set job(status)   "running" 
  }

  proc abortJob { jobid } {
    upvar $jobid job
    exec kill $job(procid) &
  }

}



###############################################################
# Job type: localdqs
# Description: runs job through dqs from the local machine, on the local filesystem
# Required server parameters: 
#   dqsflags - additional dqs flags specifying resources and options

namespace eval JobManager::localdqs {

  proc submitJob { server_ cmd jobid } {
    upvar $server_ server
    upvar $jobid job
    set execstr  [format $cmd $job(procs)]
    set dqsflags [format $server(dqsflags) $job(procs)]
    set job(monitor) "watchfile"
    set job(watchfile) "watchfile.[JobManager::get_suffix $jobid]"
    
    # create empty watchfile and open it for reading
    set job(watchchannel) [open $job(watchfile) "w+"] 
        
    # some queue managers do not read the first line so we put "true"...
    set dqscmd "echo \"true; cd $job(dir); echo HOST `hostname -f` >> $job(watchfile); $execstr > $job(logname); echo DONE >> $job(watchfile)\" | qsub $dqsflags"
    scan [eval exec $dqscmd] "your job %d has been submitted" dqsid
    set job(dqsid) $dqsid
  }


  proc abortJob { jobid } {
    upvar $jobid job
    exec qdel $job(dqsid) &
  }
  
}


###############################################################
# Job type: remote
# Description: runs job through ssh on a remote machine.  You'll have to
# set up ssh so that it doesn't prompt for a password.  
# Required parameters:
#   host         - machine to run job on
#   user         - username on remote machine
#   remotedir    - directory in which to run job on remote machine
# Optional parameters:
#   filetransfer - one of "none" (do nothing/keep local), "copy" (copy to 
#            remotedir on the local fs, or to remoteurl if specified) or "ssh" 
#            (use scp to copy to host; remotedir is on host). Default is ssh.
#   remoteurl    - if specified, serves as the file transfer destination in "copy" mode XXX NOT IMPLEMENTED YET

# NB: XXX RIGHT NOW, filetransfer always acts as if it was set to none (only "none" is implemented right now)

namespace eval JobManager::remote {

  proc submitJob {server_ cmd jobid} {
    upvar $server_ server
    upvar $jobid job
 
    # XXX catch for errors
    set job(user)  $server(user)
    set job(host)  $server(host)
    set job(filetransfer)  "ssh"   ;# default
    set job(run_host) $job(host)
    
    if [info exists server(filetransfer)] {set job(filetransfer) $server(filetransfer)}
    if {[string equal $job(filetransfer) "none"] && ![info exists server(remotedir)]} {set job(remotedir) $job(dir)} \
    else {set job(remotedir) $server(remotedir)}   ;# _must_ be set by user if not on local machine
        
    # transfer files
    JobManager::UploadFiles $jobid

    # Launch the executable
    set execstr [format $cmd $job(procs)]
    
    # is there a better way to get the remote procid?
    set job(monitor)  "pipe"
    set job(inchannel) [open [list | ssh -x ${job(user)}@${job(host)} "cd $job(remotedir); $execstr & echo \$! > jobsub.id"] r]
    scan [exec ssh -xf ${job(user)}@${job(host)} "cat [file join $job(remotedir) jobsub.id]"] "%d" job(remoteid)
    # XXX This gets the WRONG remoteid for NAMD2 (on TCBG machines only, bc the "namd2" script does not kill its children when it dies).
    # XXX This should be fixable by adjusting the namd2 script itself to call exec, or something like that
    set job(status)  "running" 
  } 

  proc abortJob { jobid } {
    upvar $jobid job 
    if {$job(status) == "running"} {
      exec ssh -xf ${job(user)}@${job(host)} kill $job(remoteid)
    }
  }
  
}



###############################################################
# Commands for JobManager _internal_ use
###############################################################


# creates a new job and returns a jobid for it
proc JobManager::new_job {} {
  variable jobcount
  global env
  
  incr jobcount
  set jobid ::JobManager::jobs::job$jobcount
  # these need to be defined for JobManager to work
  array set $jobid [list  dir $env(TMPDIR)  procs 1   filetransfer "none"] 
  return $jobid
}

# frees the memory associate with a job (called by abortJob)
# (if jobs are not freed, memory will leak, but in negligible amounts compared to 
# that leaked by atomselections)
proc JobManager::delete_job { jobid } {
  array unset $jobid   ;# this never raises an error (and shouldn't)
}

proc JobManager::get_suffix { jobid } {
  scan $jobid "::JobManager::jobs::%s" suffix
  return $suffix
}


# internal proc to read the log file, do things and call callbacks
proc JobManager::pipe_monitor { jobid } {
  if ![info exists $jobid] {puts "JobManager) ASSERT FAILED"; return} ;# should never get here XXX remove this when done
  upvar $jobid job
  
  if {[gets $job(inchannel) line] >= 0} {
    #XXX do regexp-based callbacks here
    puts $job(outchannel) $line  ;### todo: should use "tee" instead of doing this here; can cause problems
    return
  }
  if [eof $job(inchannel)] {
    close $job(inchannel) ;# close the pipe and stop looping on this monitor
    set job(status) "done"
    DownloadFiles $jobid  ;# make sure requested files are available to the calling program
    if [info exists job(jobdone_callback)] {
      namespace inscope :: $job(jobdone_callback)
      AbortJob $jobid
    }
  }
}


# internal proc to read the log file, do things and call callbacks
proc JobManager::watchfile_monitor { jobid } {
  if ![info exists $jobid] {puts "JobManager) ASSERT FAILED"; return} ;# should never get here XXX remove this when done
  upvar $jobid job
  if {[file channels $job(watchchannel)] == ""} {
    # XXX fix this behavior, caused by throwing a fileevent after a channel has been deleted
    return 
  }
  
  if {[gets $job(watchchannel) line] >= 0} {
    if {[scan $line "HOST %s" run_host] == 1} {
      set job(status) "running"
      set job(run_host) $run_host
      if [info exists job(jobstart_callback)] {namespace inscope :: $job(jobstart_callback)}
      return
    }
    if {"$line"=="DONE"} {
      close $job(watchchannel) ;# close the pipe and stop looping on this monitor
      set job(status) "done"
      DownloadFiles $jobid  ;# make sure requested files are available to the calling program
      if [info exists job(jobdone_callback)] {
        namespace inscope :: $job(jobdone_callback)
        AbortJob $jobid
      }
      return
    }

  }
  if [eof $job(watchchannel)] { 
    # if watching a file with an EOF, watchfile_monitor will be called so fast as to freeze
    # everything. So we add a 0.8s delay here to counter that
    fileevent $job(watchchannel) readable ""  ;# delete event
    # this is a workaround to "wake-up" the watchfile for localdqs (otherwise get a 4 sec delay!!) :
    exec touch [file join $job(dir) $job(watchfile)] 
    after 800 [list fileevent $job(watchchannel) readable [list JobManager::watchfile_monitor $jobid]]  ;# rethrow event 
  }
}

