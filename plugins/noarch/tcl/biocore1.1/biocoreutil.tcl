##
## Utility features we need exposed in the interface 
##
## Author: BioCoRE
##         biocore@ks.uiuc.edu
##         vmd@ks.uiuc.edu
##
## $Id: biocoreutil.tcl,v 1.11 2006/08/22 22:35:52 kvandivo Exp $
##

## Tell Tcl that we're a package and any dependencies we may have
package provide biocoreutil 1.0

package require biocorelogin 1.0
package require biocore 1.20

namespace eval ::BioCoREUtil:: {
  namespace export biocoreutil

  # window handles
  variable w                                          ;# handle to main window
  variable noVerify
  variable mainMenu
  variable infoFrame
  variable changePass
  variable joinProject
  variable projListBox
  variable rawProjList
  variable plTitle 
  variable plDesc "No Project Selected"
  variable plIsPublic 
  variable plCreator 
  variable descTextBox 
  variable joinProjSubmitButton
  variable retryPacked
  variable retryButton
}

#
# Create the window and initialize data structures
#
proc ::BioCoREUtil::biocoreutil {} {
  variable w
  variable noVerify
  variable mainMenu
  variable infoFrame
  variable changePass
  variable joinProject

  # If already initialized, just turn on
  if { [winfo exists .biocoreutil] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".biocoreutil"]
  wm title $w "BioCoRE Utilities"

  #puts "before initDefault."
  if {[catch {::biocore::initDefault } errmsg]} {
     set validUser 0
     #global errorInfo errorCode
     #puts "init Error: <$errmsg> <$errorInfo> <$errorCode>"
  } else {
     set validUser 1
  }

  #puts "after initDefault. $validUser"

  ##
  ## make the menu bar
  ##
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url \
      [string trimright [vmdinfo www] /]/plugins/biocore/index.html#utilities"
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5

  pack $w.menubar.help -side right

  pack $w.menubar
  pack [label $w.introText -text "Miscellaneous BioCoRE Utilities"]

  # let's define our various frames
## ------------------  START login frame --
  set noVerify [frame $w.noVerify]
  pack [label $noVerify.text -text \
                    "You need to login to BioCoRE to access these utilities."]

  set ::BioCoREUtil::retryButton  \
            [button $::BioCoREUtil::noVerify.retryButton -bg lightgrey \
            -command { \
               if {[catch {::biocore::initDefault } errmsg]} {
                  global errorInfo errorCode
               } else {
                  pack forget $::BioCoREUtil::noVerify
                  pack $::BioCoREUtil::mainMenu
               }
            } -text "I've Logged In Now.  Retry"] 

  set ::BioCoREUtil::retryPacked 0

  set nvLoginButton [button \
     $noVerify.loginButton \
     -bg lightgrey -command { \
           wm deiconify [biocorelogin_tk_cb] 
           if {$::BioCoREUtil::retryPacked == 0} {
              set ::BioCoREUtil::retryPacked  1
              pack $::BioCoREUtil::retryButton
           }
        }  \
     -text "Login"]
  pack $nvLoginButton
## ------------------  END login frame --

## ------------------  START main menu frame --
  set mainMenu [frame $w.mainMenu]
  pack [label $mainMenu.introText -text "Main Menu"]
  set mmChangePasswordButton [button \
     $mainMenu.changePasswordButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::mainMenu 
        pack $::BioCoREUtil::changePass }  -text "Change Password"]
  pack $mmChangePasswordButton 

  set mmInfoButton [button \
     $mainMenu.infoButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::mainMenu 
        pack $::BioCoREUtil::infoFrame }  -text "Information"]
  pack $mmInfoButton

  set mmJoinProjectButton [button \
     $mainMenu.joinProjectButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::mainMenu 
        ::BioCoREUtil::populateProj
        pack $::BioCoREUtil::joinProject }  -text "Join Project"]
  pack $mmJoinProjectButton
## ------------------  END main menu frame --

## ------------------  START info frame --
  set infoFrame [frame $w.infoFrame]
  grid [label $infoFrame.introText -text "BioCoRE Information"] -columnspan 2

  # username
  if {[catch {set uName [::biocore::getUserName $::biocore::userId ]} errmsg]} {
     # if we make it in here, we had an error thrown
     global errorInfo
     global errorCode
#     puts "Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
  } else {
     grid [label $infoFrame.unDesc -text "User Name: "] \
         [label $infoFrame.unText -text "$uName"] 

  }

  # logged in since
  grid [label $infoFrame.loggedinDesc -text "Logged In Since: "] \
      [label $infoFrame.loggedinText -text "$::biocore::sessionFileWritten"] 

  # biocore server attached to
  grid [label $infoFrame.bsDesc -text "Server URL: "] \
      [label $infoFrame.bsText -text "$::biocore::URL"] 

  # User ID 
  grid [label $infoFrame.uidDesc -text "User ID: "] \
      [label $infoFrame.uidText -text "$::biocore::userId"] 


  set infoCancelButton [button \
     $infoFrame.cancelButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::infoFrame 
        pack $::BioCoREUtil::mainMenu }  \
     -text "Return To Utilities"]
  grid $infoCancelButton -columnspan 2
## ------------------  END info frame --

## ------------------  START change password frame --
  set changePass [frame $w.changePass]
  pack [label $changePass.introText -text "Change Password"]
  set oldFrame [frame $changePass.old]
  set old_label [label $changePass.old.label -text "Old Password:"]
  set old_entry [entry $changePass.old.entry -textvariable oldPass -show "*"]
  pack $changePass.old.label $changePass.old.entry
  set new1Frame [frame $changePass.new1]
  set new1_label [label $changePass.new1.label -text "New Password:"]
  set new1_entry [entry $changePass.new1.entry -textvariable new1Pass -show "*"]
  pack $changePass.new1.label $changePass.new1.entry
  set new2Frame [frame $changePass.new2]
  set new2_label [label $changePass.new2.label -text "New Password (confirm):"]
  set new2_entry [entry $changePass.new2.entry -textvariable new2Pass -show "*"]
  pack $changePass.new2.label $changePass.new2.entry

  set changePassSubmitButton [button \
     $changePass.submitButton \
     -bg lightgrey -command {  \
        if {[::BioCoREUtil::submitPassword $oldPass $new1Pass $new2Pass] == 0} {
            pack forget $::BioCoREUtil::changePass 
            pack $::BioCoREUtil::mainMenu
        }
        set oldPass ""
        set new1Pass ""
        set new2Pass ""
     } \
     -text "Submit"]
  set changePassCancelButton [button \
     $changePass.cancelButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::changePass 
        pack $::BioCoREUtil::mainMenu }  \
     -text "Cancel"]
  pack $oldFrame $new1Frame $new2Frame \
                           $changePassSubmitButton $changePassCancelButton
## ------------------  END change password frame --

## ------------------  START join project frame --
  set joinProject [frame $w.joinProj]
  pack [label $joinProject.introText -text "Choose Project To Join"] -side top

  set jpLeftFrame [ frame $joinProject.left ]
  pack [label $jpLeftFrame.descText -text \
              "You are currently eligible to join the following projects:"]
  variable projListBox
  set projListBox [listbox $jpLeftFrame.lb -yscrollcommand \
                                          "$jpLeftFrame.sb set" -height 5]
  bind $projListBox <<ListboxSelect>> [list ::BioCoREUtil::myProjSelectHandler]

  pack $projListBox  -side left -fill both -expand true
  pack [scrollbar $jpLeftFrame.sb -command "$jpLeftFrame.lb yview"] -side left -fill y


  set jpRightFrame [ frame $joinProject.right ]
  set jpRightTitle [ frame $jpRightFrame.title]
  pack [label $jpRightTitle.label -text "Title:"] -side left
  set titleText [label $jpRightTitle.text -width 30 \
                                        -textvariable ::BioCoREUtil::plTitle]
  pack $titleText -side right
  set jpRightDesc [ frame $jpRightFrame.desc]
  pack [label $jpRightDesc.label -text "Description:"] -side left
  variable descTextBox
  set descTextBox [text $jpRightDesc.text -height 2 -wrap word -width 30 \
                                            -state disabled -relief flat]
  pack $descTextBox -side right
  set jpRightPublic [ frame $jpRightFrame.public]
  pack [label $jpRightPublic.label -text "Public:"] -side left
  set publicText [label $jpRightPublic.text -width 30 \
                                    -textvariable ::BioCoREUtil::plIsPublic]
  pack $publicText -side right
  set jpRightCreator [ frame $jpRightFrame.creator]
  pack [label $jpRightCreator.label -text "Creator:"] -side left
  set creatorText [label $jpRightCreator.text -width 30 \
                                    -textvariable ::BioCoREUtil::plCreator]
  pack $creatorText -side right

  pack $jpRightTitle $jpRightDesc $jpRightPublic $jpRightCreator


  set jpButtonFrame [frame $joinProject.buttons]
  variable joinProjSubmitButton
  set joinProjSubmitButton [button \
     $jpButtonFrame.submitButton \
     -bg lightgrey -command { 
        set projId [lindex $::BioCoREUtil::rawProjList \
                        [expr [$::BioCoREUtil::projListBox curselection]*10+1]]
        if {[::BioCoREUtil::submitJoinProj $projId] == 0} {
            pack forget $::BioCoREUtil::joinProject 
            pack $::BioCoREUtil::mainMenu
        }
     }  \
     -text "Join Project"]
  $joinProjSubmitButton configure -state disabled
  set joinProjCancelButton [button \
     $jpButtonFrame.cancelButton \
     -bg lightgrey -command { 
        pack forget $::BioCoREUtil::joinProject 
        pack $::BioCoREUtil::mainMenu}  \
     -text "Cancel"]
  pack $joinProjSubmitButton $joinProjCancelButton  -side left -fill x
  pack $jpButtonFrame -side bottom 
  pack $jpLeftFrame -side left
  pack $jpRightFrame -side right

## ------------------  END join project frame --


  if {$validUser == 0} {
     pack $noVerify
  } else {
     pack $mainMenu
  }

#  pack $mainMenu 
#  pack $changePass 
#  pack $noVerify

}

proc ::BioCoREUtil::submitPassword { oldPass new1Pass new2Pass } {
   if {[string equal "" [string trim $oldPass]]} {
      tk_messageBox -type ok -message "Old Password must be provided" \
                                                               -title "Error!"
      return 1
   } elseif {[string equal "" [string trim $new1Pass ]]} {
      tk_messageBox -type ok -message "New Password must be provided" \
                                                               -title "Error!"
      return 2
   } elseif {[string equal "" [string trim $new2Pass ]]} {
      tk_messageBox -type ok -message \
                  "New Confirmation Password must be provided" -title "Error!"
      return 3
   } elseif { [string compare $new1Pass $new2Pass] != 0 } {
      tk_messageBox -type ok -message "New Passwords Don't Match!" \
                                                            -title "Error!"
      return 4
   } else {
      if {[catch {::biocore::changePassword $oldPass $new1Pass } errmsg]} {
         # if we make it in here, we had an error thrown
         tk_messageBox -type ok -message \
                     "Error Communicating with BioCoRE: $errmsg" -title "Error!"
         return 5
      } else {
         tk_messageBox -type ok -message "Password Changed!" -title "Success"
         return 0
      }
   }
}

proc ::BioCoREUtil::submitJoinProj { projId } {
   if {[catch {::biocore::joinProject $projId } errmsg]} {
      # if we make it in here, we had an error thrown
      tk_messageBox -type ok -message \
                    "Error Communicating with BioCoRE: $errmsg" -title "Error!"
      return 1
   } else {
      tk_messageBox -type ok -message "Project Joined Successfully!" \
                                                              -title "Success"
      return 0
   }
}

proc ::BioCoREUtil::populateProj {} {
  variable projListBox
  variable rawProjList
  variable plTitle ""
  variable plDesc "No Project Selected"
  variable plIsPublic ""
  variable plCreator ""


  $projListBox delete 0 end

  if {[catch { set rawProjList [::biocore::getEligibleProjects] } errmsg]} {
  } else {
      foreach { ti p t d i in ci ap pa dt } $rawProjList {
         $projListBox insert end $t
         #puts "$ti [format %3i $p] [format %18s $t] [format %40s $d] $i $in $ci $ap $pa $dt"
      }

  }

}

proc ::BioCoREUtil::myProjSelectHandler {} {
   variable projListBox
   variable descTextBox

   set numSelected [$projListBox curselection]
   if {[string length $numSelected] > 0} {
#   puts "currently selected is :  [$projListBox curselection]"
      set ::BioCoREUtil::plTitle [lindex $::BioCoREUtil::rawProjList \
                                 [expr $numSelected*10+2]]
      $descTextBox configure -state normal
      $descTextBox delete 1.0 {end -1c}
      $descTextBox insert end [lindex $::BioCoREUtil::rawProjList \
                                 [expr $numSelected*10+3]]
      $descTextBox configure -state disabled
      set ::BioCoREUtil::plIsPublic [lindex $::BioCoREUtil::rawProjList \
                                 [expr $numSelected*10+4]]

      set userId [lindex $::BioCoREUtil::rawProjList  \
                              [expr  $numSelected*10+6]]

      if {[catch {set ::BioCoREUtil::plCreator \
                                 [::biocore::getUserName $userId ]} errmsg]} {
           # if we make it in here, we had an error thrown
           set ::BioCoREUtil::plCreator "Unknown"
      } 
      $::BioCoREUtil::joinProjSubmitButton configure -state normal
   }
}


proc biocoreutil_tk {} {
  ::BioCoREUtil::biocoreutil
  return $::BioCoREUtil::w
}

