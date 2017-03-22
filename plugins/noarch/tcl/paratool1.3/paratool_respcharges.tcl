#
# Interface to the RESPtool plugin 
#
# $Id: paratool_respcharges.tcl,v 1.2 2006/05/07 18:12:04 johns Exp $
#

proc ::Paratool::resp_charges {} {
   variable molidsip
   variable molidbase
   variable molnamesip

   # We are requiring resptool on the fly:
   if {[catch {package require resptool}]} {
      tk_messageBox -icon error -type ok -title Message \
         -message "Couldn't load RESP Tool Plugin"
      return 0
   }

   if {$molidsip<0} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please load single point calculation with ESP potential first!"
      return 0
   }
   set all [atomselect $molidbase all]
   ::RESPTool::resp_gui $all 
   set ::RESPTool::gaussianinput $molnamesip
   set ::RESPTool::alignmol $molidsip
   ::RESPTool::parse_gaussian_log

   set ::RESPTool::stage 1
   ::RESPTool::setup_stage_one

   set ::RESPTool::callbackfctn ::Paratool::resp_callback
   set ::RESPTool::respinput [file rootname $molnamesip]_resp_stage1.inp
   #::RESPTool::run_resp
}

proc ::Paratool::resp_callback { charges } {
   variable molnamesip
   if {$::RESPTool::stage==1} {
      # Run stage 2
      set ::RESPTool::stage 2
      ::RESPTool::setup_stage_two
      set ::RESPTool::respinput [file rootname $molnamesip]_resp_stage2.inp
      ::RESPTool::write_resp_input
      ::RESPTool::run_resp
      return
   }

   foreach atom $charges {
      set_atomprop RESP [lindex $atom 0] [lindex $atom 1]
   }

   variable haveresp 1
   variable copychargetypes
   if {[lsearch $copychargetypes RESP]<0} { lappend copychargetypes RESP }
   
   if {[winfo exists .paratool_atomedit]} {
      ::Atomedit::update_copycharge_menu .paratool_atomedit $copychargetypes
   } 

   variable atomproptags 
   if {[lsearch $atomproptags RESP]<0} {
      lappend atomproptags RESP
   }

   atomedit_update_list

   if {[winfo exists .paratool_atomedit]} {
      set_pickmode_atomedit
   }
}

