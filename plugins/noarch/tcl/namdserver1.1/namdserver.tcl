##
## NAMD Server Plugin
##
## Provides an interface for starting NAMD in "server mode".
## NAMD is started exxternally and its output is piped back into VMD such that the
## energy output can be utilized. You can generate a NAMD input file that contains 
## code such that NAMD starts up, opens a socket and goes into waiting mode (event-loop,
## waiting for socket to be connected).
## The NMADserver plugin polls the server and as soon as it's up it will connect a client
## to it. In the following every line that the client sends to the server will be evaluated
## in NAMD as a command (TCL and NAMD commands). The results will be sent back to the client
## through the socket. Thus you can interactively control NAMD.

## NAMDserver is most useful, if you want to build a structure once and then want to
## evaluate energies for different coodinates or charges which you generate on the fly
## through another script. Thus you can save the startup phase of NAMD for the subsequent 
## calculations, if the structure was built once in NAMD.

## I prepared two function that simplify life even more:
## ::NAMDserver::namd_eval will send $cmd to the server and block until the
## return value is received or the timeout has been reached.

## ::NAMDserver::namd_compute_energies {sock dcdfile} 
## will request the evaluation of the energies for all frames of the given 
## dcdfile and block until the return value is received or the timeout has been 
## reached. The resulting energies are stored in ::NAMDserver::etitle and 
## ::NAMDserver::energy.
##

## NAMDserver works only in conjunction with namdenergy since you must use the latter is used 
## to build the NAMD input files using the -server flag.

## Example:
##   set sel [atomselect top "segid CWAT"]
##   namdenergy -sel $sel -bond -server -tempname "namdserver" \
##      -par par_all27_prot_lipid_na.inp

##   set sock [start_server "namdserver-temp.namd"]
##   set energy [namd_compute_energies $sock myfile.dcd]
##   set energy2 [namd_compute_energies $sock myotherfile.dcd]

## Author: Jan Saam
##          saam@charite.de

package require namdenergy
package require exectool   1.2
package provide namdserver 1.1

namespace eval ::NAMDserver {
   variable namd_button "Run NAMDserver"
   variable etitle {}
   variable energy {}
   variable processing 0
   variable srvretval {}
   variable namd_log_fd {}
   variable sock 0
   variable debug 0
   variable highprec 0
}

##################################################################
# Poll the existence of the server and try to connect client to  #
# the server. If successful, return the socket.                  #
##################################################################

proc NAMDserver::start_client {host port} {
   set maxpolls 25
   set delay 50
   set connected 0
   variable sock 
   variable debug
   # We are polling the NAMD server:
   for {set i 0} {$i<$maxpolls} {incr i} {
      if {$debug} { puts "$i) Try connecting client to server ($host $port)" }
      if { [catch [list socket $host $port] sock]} {
         if {$debug} { puts "Server not up, trying again" }
         after $delay
      } else {
	 if {$debug} { puts "Connected to NAMD server: $host $port" }
	 fconfigure $sock -buffering line
	 fileevent $sock readable [list ::NAMDserver::client_read_data $sock]
	 set connected 1
         break
      }
   }

   if {$connected} {
      return $sock
   } else {
      return 0
   }
}


##################################################################
# Read the data from the socket to the server.                   #
##################################################################

proc NAMDserver::client_read_data {socket} {
   variable debug
   #puts "Reading data from $socket"
   if {[eof $socket]} {
      if {$debug>1} { puts "NAMDserver::client_read_data) Received EOF on socket $socket" }
      close $socket
      variable sock 0
      namd_stop
   } elseif {[catch {gets $socket line}]} {
      puts "Couldn't read from socket $socket!"
   } else {
      if {$debug>1} { puts "NAMDserver: $line" }
      variable srvretval $line
      
      # The following lines parse high precision energies from the socket
      # which are provided by cutting edge versions of NAMD through 
      # the callback function.
      variable highprec
      if {$highprec} {
	 if {[lindex $line 0]=="ETITLE:"} {
	    variable etitle [lrange $line 1 end]	 
	 } elseif {[lindex $line 0]=="ENERGY:"} {
	    # There's a vwait set on variable processing in proc namd_compute_energies.
	    # When we reach the line "Info: Closing coordinate file." we know the dcd
	    # is finished and we set processing 0. Thus namd_compute_energies is notified
	    # that it can return the energies.
	    variable energy
	    lappend energy [lrange $line 1 end]
	 } elseif {[lindex $line 0]=="FINISHED"} {
	    # Release the vwait
	    variable processing 0
	 }
      }
   }
}


##################################################################
# Start NAMD in server mode, start and connect the client to the #
# server and return the socket.                                  #
##################################################################

proc NAMDserver::start_server {inputfile} {

   start_namd $inputfile

   variable debug
   if {$debug>0} { puts "NAMDserver started." }
   if {$debug>1} { puts [exec ps -ef | grep md] }

   set sock [start_client localhost 11554]
   if {$sock==0} {
      puts "Couldn't connect client to NAMDserver!"
      stop_server
   }
   return $sock
}


proc ::NAMDserver::stop_server {} {
   variable namd_button "Stop NAMDserver"
   start_namd {}
}


##################################################################
# Start the NAMD and pipe its output back. Connect a read        #
# handler to the pipe, so that we can get the energy output.     #
##################################################################

proc ::NAMDserver::start_namd {namd_input} {
   variable namd_fd
   variable namd_button
   variable debug
   
   # If NAMD is running, do nothing
   if {[string equal $namd_button "Stop NAMDserver"]} {
      # Try to kill the process.
      # XXX - this simply won't work on Windows without a seperate "kill"
      # program being installed, so fail gracefully.
      if {$debug} { puts "Stopping NAMDserver." }
      if { [catch {exec kill [pid $namd_fd]} err] } {
	 puts "NAMDserver: can't close NAMD:\n  $err"
      } else {
	 variable sock 0
      }
      variable namd_log_fd
      if {$namd_log_fd!=0 && [eof $namd_log_fd]} {
	 close $namd_log_fd
	 variable namd_log_fd 0
      }

      return
   }
   
   puts ""
   puts "Starting NAMD..."

   set logname [file rootname $namd_input].out

   set namdbin {}
   # Prompt the user for NAMD binary location if necessary
   switch [vmdinfo arch] {
      WIN64 -
      WIN32 {
	 set namdbin [::ExecTool::find -interactive namd2.exe]
      }
      default {
	 set namdbin [::ExecTool::find -interactive namd2]
      }
   }
   
   set ret [catch {
      file delete -force  $logname
      
      #::ExecTool::exec $namdbin ${basename}.namd >& $logname &
   } var]
   
   set pid 0
   
   variable namd_button "Stop NAMDserver"
   variable namd_status "Status: Running"
   variable namd_log_fd [open $logname w]

   # Cope with filenames containing spaces
   set namdcmd [format "\"%s\"" $namdbin]
   
   # Attach NAMD to a filehandle and print output as it becomes available
   if { [catch {set namd_fd [open "|$namdcmd $namd_input"]}] } {
      puts "NAMDserver: error running $namdbin"
      ::NAMDserver::namd_stop
   } else {
      if {$debug} { puts "NAMDserver send: $namdcmd $namd_input" }
      fconfigure $namd_fd -blocking false
      # Uncomment next line, if you want to process NAMD's stdout stream
      fileevent $namd_fd readable [list ::NAMDserver::namd_output_read_handler $namd_fd]
   }
   
   if {$ret} { error $var }
   
   return
}


##################################################################
# Call this function when namd is done.                          #
##################################################################

proc ::NAMDserver::namd_stop {} {
   variable namd_status
   variable namd_button
   variable namd_fd

   if { [catch "close $namd_fd" err] } {
      puts "NAMDserver) Warning: possible problem while running NAMD:\n  $err"
   }
   variable debug
   if {$debug>1} { puts "NAMDserver) NAMD stopped." }

   # Close the logfile, too.
   variable namd_log_fd
   if {$namd_log_fd!=0 && [eof $namd_log_fd]} {
      close $namd_log_fd
      variable namd_log_fd 0
   }


   set namd_status "Status: Ready"
   set namd_button "Run NAMDserver"
}

##################################################################
# Read and print a line of NAMD output to the logfile.           #
# If the line contains ETITLE: then the data are stored in       #
# variable etitle, whereas if it contains ENERGY: then it will   #
# be appended to variable energy.                                #
##################################################################
proc ::NAMDserver::namd_output_read_handler { chan } {
   if {[eof $chan]} {
      fileevent $chan readable ""
      ::NAMDserver::namd_stop
      return
   }

   if {[gets $chan line] > 0} {
      variable namd_log_fd
      puts $namd_log_fd "$line"
      flush $namd_log_fd 

      variable highprec
      if {!$highprec} {
	 # Read the energy titles
	 if {[lindex $line 0]=="ETITLE:"} {
	    variable etitle [lrange $line 1 end]
	 }
	 # There's a vwait set on variable processing in proc namd_compute_energies.
	 # When we reach the line "Info: Closing coordinate file." we know the dcd
	 # is finished and we set processing 0. Thus namd_compute_energies is notified
	 # that it can return the energies.
	 variable energy
	 if {[string match "Info: Closing coordinate file." $line]} {
	    variable processing 0
	 } elseif {[lindex $line 0]=="ENERGY:"} {
	    # We must skip the first pdb-based enery evaluation due to 
	    # it's lower precision compared to the dcd. But we still need the 
	    # pdb evaluation to get the ETITLE line.
	    if {[lindex $line 1]>0} {
	       lappend energy [lrange $line 1 end]
	    }
	 }
      }      
   }
}


##################################################################
# This will send $cmd to the server through $sock and block      #
# until the return value is received or the timeout has been     #
# reached.                                                       #
##################################################################

proc ::NAMDserver::namd_eval {sock cmd {timeout 3000}} {
   #puts $sock $cmd
   variable srvretval
   set id [after $timeout {set clientdata {}}]
   vwait ::NAMDserver::srvretval
   after cancel $id
   return $srvretval
}


##################################################################
# This will request the evaluation of the energies for all       #
# frames of the given dcdfile and block until the return value   #
# is received or the timeout has been reached.                   #
# The resulting energies are stored in ::NAMDserver::etitle and  #
# ::NAMDserver::energy.                                          #
##################################################################

proc ::NAMDserver::namd_compute_energies {sock dcdfile {elabel ALL} {timeout 3000}} {
   variable energy {}
   variable processing 1
   #puts "compute_coordset $dcdfile"
   puts $sock "compute_coordset $dcdfile $elabel"
   set id [after $timeout {set ::NAMDserver::processing 0}]
   vwait ::NAMDserver::processing
   after cancel $id
   return $energy
}


##########################################
# Just for my own debugging purposes...  #
##########################################

proc ::NAMDserver::test {} {
   set sel [atomselect top "segid CWAT"]
   namdenergy -sel $sel -bond -server -par thf_2coo.par -tempname "namdserver" \
      -par /usr/local/lib/vmd/plugins/noarch/tcl/readcharmmpar/par_all27_prot_lipid_na.inp
   set sock [start_server "namdserver-temp.namd"]
   puts "socket=$sock"

   # The string will be evaluated in NAMD and the result is returned.
   puts $sock "expr 2+3"

   foreach i {1 2 3 4 5 6} {
      puts "Step $i:"
      set energy [namd_compute_energies $sock namdserver-temp.dcd]
      foreach e $energy {
	 puts $etitle
	 puts $e
      }
   }
}
