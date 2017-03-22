#
# Tk-based replacement for the old IMD status monitoring window in VMD
#
# $Id: imdmenu.tcl,v 1.3 2005/07/20 15:17:54 johns Exp $
#
package provide imdmenu 1.0

namespace eval IMD {
  # Define variables
  variable imdmol         -1   ;# molecule ID of the live IMD simulation  
  variable hostname
  variable imdport
  variable transferrate    0
  variable keeprate        0
  variable w
}


# the GUI
proc IMD::startGUI { } {
  variable w
  global env
  
  # make the initial window
  set w [toplevel ".imd"]
  wm title $w "IMD Connection"
  wm resizable $w no no

  set textfont [font create -family helvetica -size 10]
  set labelfont [font create -family helvetica -size 10]
  set buttonfont [font create -family helvetica -weight bold -size 10]
  
  frame $w.win ;# Main contents
  pack $w.win -padx 4 -pady 4
  frame $w.win.server
  label $w.win.server.hostlabel -text "Hostname" -font $labelfont -anchor w
  label $w.win.server.portlabel -text "Port" -font $labelfont -anchor w
  entry $w.win.server.hostname -width 20 -relief sunken -bd 1 -textvariable IMD::hostname -font $textfont
  entry $w.win.server.port -width 10 -relief sunken -bd 1 -textvariable IMD::port -font $textfont 
  grid $w.win.server.hostlabel $w.win.server.hostname -sticky news
  grid $w.win.server.portlabel $w.win.server.port -sticky nwes

  frame $w.win.controls
  button $w.win.controls.connect -text "Connect" -width 7 -font $buttonfont -command IMD::connect
  button $w.win.controls.detach -text "Detach Sim" -width 7 -font $buttonfont -command IMD::detach
  button $w.win.controls.stop -text "Stop Sim" -width 7 -font $buttonfont -command IMD::stop
  pack $w.win.controls.connect $w.win.controls.detach $w.win.controls.stop -side left

  frame $w.win.settings
  label $w.win.settings.transferlabel -text "Timestep transfer rate" -font $labelfont -anchor w 
  label $w.win.settings.keeplabel -text "Timestep keep rate" -font $labelfont -anchor w
  entry $w.win.settings.transfer -width 10 -relief sunken -bd 1 -textvariable IMD::transferrate -font $textfont 
  entry $w.win.settings.keep -width 10 -relief sunken -bd 1 -textvariable IMD::keeprate -font $textfont 
  grid $w.win.settings.transferlabel $w.win.settings.transfer -sticky news
  grid $w.win.settings.keeplabel $w.win.settings.keep -sticky news
  
  frame $w.win.energies
  listbox $w.win.energies.listbox -font $textfont -relief sunken -bd 1
  pack $w.win.energies.listbox

  # pack the frames
  set padx 20
  set pady 2
  pack $w.win.server -fill x -expand yes -anchor nw -pady $pady
  pack $w.win.controls -fill x -expand yes -padx $padx -pady $pady
  pack $w.win.settings -fill x -expand yes -padx $padx -pady $pady
  pack $w.win.energies -fill x -expand yes -padx $padx -pady $pady

  # set trace for energies
  global vmd_frame vmd_timestep
  trace variable vmd_frame w IMD::tracetimestep
  trace variable vmd_timestep w IMD::tracetimestep
  bind $w.win.settings.transfer <Return> IMD::transfer_cb
  bind $w.win.settings.keep <Return> IMD::keep_cb
}

proc IMD::transfer_cb { args } {
  variable transferrate
  if { ![string is integer $transferrate] || $transferrate < 0} {
    set transferrate 0
  }
  catch { imd transfer $transferrate }
}

proc IMD::keep_cb { args } {
  variable keeprate
  if { ![string is integer $keeprate] || $keeprate < 0} {
    set keeprate 0
  }
  catch { imd keep $keeprate }
}

# Must be run before everything else
proc IMD::startup {} {
  # If already initialized, just deiconify and return
  if { [winfo exists ".imd"] } {
    wm deiconify ".imd"
    raise ".imd"
    return
  }
  startGUI
}

proc IMD::connect { } {
  variable imdmol
  variable hostname
  variable port
  variable w
  set rc [catch { imd connect [string trim $hostname] $port } msg]
  if { $rc } {
    tk_messageBox -title "IMD Error" -parent $w -type ok -message $msg
  } else {
    set imdmol [molinfo top get id]
  }
}

proc IMD:::detach { } {
  variable imdmol
  variable w
  if { $imdmol < 0 } {
    set msg "Can't detach, not connected."
    tk_messageBox -title "IMD Error" -parent $w -type ok -message $msg
  } else {
    catch { imd detach }
    set imdmol -1
  }
}

proc IMD::stop { } {
  variable imdmol
  variable w
  if { $imdmol < 0 } {
    set msg "Can't stop sim; not connected."
    tk_messageBox -title "IMD Error" -parent $w -type ok -message $msg
  } else {
    catch { imd kill }
    set imdmol -1
  }
}

# Callback for whenever IMD receives a new frame
proc IMD::tracetimestep {args} {
  variable w
  # print energies for the top molecule
  $w.win.energies.listbox delete 0 end
  if { [molinfo top] == -1 } { return }
  foreach etype { timesteps temp energy bond angle dihedral improper vdw elec } {
    $w.win.energies.listbox insert end "$etype: [molinfo top get $etype]"
  }
}

proc imdmenu_tk {} {
  IMD::startup
  return $IMD::w  
}
