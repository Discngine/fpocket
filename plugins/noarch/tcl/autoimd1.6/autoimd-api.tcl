#
# API - USER CALLS FOR SCRIPTING, ETC.
#
# $Id: autoimd-api.tcl,v 1.3 2005/07/20 21:35:48 johns Exp $
#


# To be used to reset server list
proc AutoIMD::api_clearservers {args} {
  variable w
  
  if {[llength $args] != 0} {
    puts "usage: autoimd clearservers"
    return
  }
  
  foreach var [info vars servers::*] { unset -nocomplain $var }
  if [winfo exists ".autoimd"] {
    $w.win.procs.server.servermenu.menu delete 0 last
  }
}

# To be used to add a new server configuration
proc AutoIMD::api_addserver {args} {
  variable w
  
  if {[llength $args] != 2} {
    puts "usage: autoimd addserver <name> <definition array>"
    return
  }
  
  set servername "[lindex $args 0]"
  set opts [lindex $args 1]
    
  array set "::AutoIMD::servers::$servername" $opts

  if [winfo exists ".autoimd"] {AutoIMD::update_server_menu}
}


# Sets the current active server
proc AutoIMD::api_setserver {args} {
  if {[llength $args] != 1} {
    puts "usage: autoimd setserver \<name\>"
    return
  }
  
  set servername "[lindex $args 0]"
  
  if { [info exists "servers::$servername"] } {
    set AutoIMD::currentserver "$servername"
  } else {
    error "Unrecognized server name '$servername'"
  }
}



######################################################################
### USER CALLS                                                     ###
######################################################################

# run this first!
proc autoimd {args} {
  global env
  
  if {[llength $args] == 0} { # if run without any arguments
      puts "usage: autoimd <command> options..."
      puts "  showwindow"
      puts "  clearservers"
      puts "  addserver \<name\> \<definition array\>"
      puts "  setserver \<name\>"
      puts "  set \<var\> \<value\>"
  }

  set command [lindex $args 0]
  switch $command {
    showwindow   { AutoIMD::startup }
    addserver    { eval AutoIMD::api_addserver [lrange $args 1 end] }
    clearservers { eval AutoIMD::api_clearservers [lrange $args 1 end] }
    setserver    { eval AutoIMD::api_setserver [lrange $args 1 1] }
    set          { eval set AutoIMD::settings::[lindex $args 1] [lrange $args 2 end] }
  }
}
