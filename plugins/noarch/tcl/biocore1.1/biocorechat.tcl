#***************************************************************************
#
#            (C) Copyright 1995-2006 The Board of Trustees of the
#                        University of Illinois
#                         All Rights Reserved
#
#***************************************************************************  
##
## BioCoRE Pub/Sync Plugin
##
## Authors: Michael Bach, John Stone, Kirby Vandivort
##          vmd@ks.uiuc.edu
##
## $Id: biocorechat.tcl,v 1.40 2007/02/28 22:39:31 mbach Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/biocore
##
package provide biocorechat 1.1

# biocore proof of concept control panel.  No statements that this is
# the best or only way to accomplish this.. Just a way that works.
#
package require biocore 1.25
package require biocorelogin 1.0
package require biocorepubsync 1.1

package require Tk

namespace eval ::BiocoreChat {

    global env

    variable w

    variable chatWindowName ".biocoreChatWindow"

    variable chatWindow $chatWindowName.chatWindow
    
    variable notificationSock
    
    variable mostRecent 10

    variable mostRecentSaves 5

    variable strId

    variable vmdType 2

    variable currentProject 1

}

# -----------------
# -----------------

# -----------------
# register this listener with the server.  
proc ::BiocoreChat::register_listener {listType} {

   
   if [catch {set listId [::biocore::registerListener $listType ]} errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "biocorechat) Error registering listener: <$errmsg> <$errorInfo> <$errorCode>"
      return -1
   } else {
      # we got a response, which is the listener ID
      return $listId
   }
} ; # end of register_listener


# deregister this listener with the server. 
proc ::BiocoreChat::deregister_listener {listType} {

   variable strId

   if [catch {set result [::biocore::deregisterListener $strId ]} errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "biocorechat) Error registering listener: <$errmsg> <$errorInfo> <$errorCode>"
      return -1
   } else {
      # we got a response, which is the listener ID
       set strId -1
      return 1
   }
} ; # end of register_listener

# -----------------
proc ::BiocoreChat::test_getProjectList { } {
    
    # get the list
    if [catch { set projectList [::biocore::getProjectList] } errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "biocorechat) Error getting the project list: <$errmsg> <$errorInfo> <$errorCode>"
   } else {
      # we got a response.  We need to print it out
      puts "biocorechat)  Id   Project"
      puts "biocorechat) ----  -------"
      foreach { name id } $projectList {
         puts "biocorechat) [format %3i $id]   $name"
#         puts "biocorechat) Project: $name  -  Id $id"
      }
  }
} ; # end of test_getProjectList

# -----------------
proc ::BiocoreChat::test_getListenerPrefs { listType} {
   puts "biocorechat) Testing biocore_getListenerPrefs"
    
    # get the list
    if [catch { set prefs [::biocore::getListenerPrefs $listType] } errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "biocorechat) Error getting listener preferences: <$errmsg> <$errorInfo> <$errorCode>"
    } else {
      # we got a response.  We need to print it out
      puts "biocorechat) Listener Prefs"
      puts "biocorechat) $prefs"
#         puts "biocorechat) Project: $name  -  Id $id"
    }
} ; # end of test_getListenerPrefs

# -----------------
# is the current session id/ as well as the currently chosen project
# valid for this user? proc test_verify {} {
proc ::BiocoreChat::test_verify {} {
   #puts "biocorechat) Testing biocore_verify"
                                                                                
   if [catch {set i [::biocore::verify ]} errmsg] {
      # if we make it in here, we had an error thrown
      global errorInfo
      global errorCode
      puts "biocorechat) Error verifying user's validity: <$errmsg> <$errorInfo> <$errorCode>"
      return 0
   } else {
      # we got a response.  We need to print it out
      #puts "biocorechat) User is valid: $i"
      return 1
   } 
} ; # end of test_verify


############################################################
    # From: http://wiki.tcl.tk/14534
    # Based heavily on Stephen Uhler's HTML parser in 10 lines
    # Modified by Eric Kemp-Benedict for XML
    #
    # Turn XML into TCL commands
    #   xml     A string containing an html document
    #   cmd     A command to run for each html tag found
    #   start   The name of the dummy html start/stop tags
    #
proc ::BiocoreChat::taxparse {cmd xml {start docstart}} {
    if { [catch {
	set xml [string map {\\ \\\\ \{ \&\#123; \} \&\#125; \&quot; {\"} \&lt; < \&\#039; \'} $xml]
   #regsub -all \{ $xml {\{} xml
   #regsub -all \} $xml {\}} xml
   set exp {<(/?)([^\s/>]+)\s*([^/>]*)(/?)>}

   set sub "\}\n$cmd {\\2} \[expr \{{\\1} ne \"\"\}\] \[expr \{{\\4} ne \"\"\}\] \
      \[regsub -all -- \{\\s+|(\\s*=\\s*)\} {\\3} \" \"\] \{"
  
   regsub -all $exp $xml $sub xml
   #puts "taxparse3.  xml=<<<<<'$xml'>>>>>"
   regsub -all {\&\#123;} $xml {\{} xml
   regsub -all {\&\#125;} $xml {\}} xml
   regsub -all {\&\#47;} $xml {/} xml
   regsub -all {\&gt;} $xml > xml
   regsub -all {\&amp;} $xml {\&} xml
   #puts "\ntaxparse4.  xml=<<<<<'$xml'>>>>>"

#   puts "biocorechat) getting ready to eval \"$cmd {$start} 0 0 {} \{ $xml \}\""
   eval "$cmd {$start} 0 0 {} \{ $xml \}"
#   puts "biocorechat) getting ready to eval \"$cmd {$start} 1 0 {} {}\""
   eval "$cmd {$start} 1 0 {} {}"
	} taxParseError] } {
	global errorInfo
	global errorCode
	puts "biocorechat) Error in taxparse: <$taxParseError> <$errorInfo> <$errorCode>"
   }

}

proc ::BiocoreChat::compactws {s} { return [regsub -all -- {\s+} [string trim $s] " "] }

proc ::BiocoreChat::parseListenerMessages {tag cl selfcl props body} {
    catch {
    #puts "parseListenerMessages.  tag='$tag', cl='$cl', selfcl='$selfcl', props='$props', body='$body'"

   variable chatWindow

    variable vmdType

    if { [string equal $tag {?xml}] } {
      return
   }
   array set temp $props
   switch $tag {
      {docstart} {}    
      {vector} {}
      {Generic Name Value Listing.  Good For Testing} {
         #puts "biocorechat) $tag"
         foreach item [array names temp] {
            #puts "biocorechat) [string totitle $item]: $temp($item)"
         }

     }
      {ChatMessage} {

         foreach item [array names temp] {
            switch $item {
               {m} {
                  set m $temp($item)
                  regsub -all {\&\#61;} $m {=} m
	       }
               {ty} {set ty $temp($item)}
               {pr} {set pr $temp($item)}
               {r} {set r $temp($item)}
               {s} {set s $temp($item)}
               {_p} {set p $temp($item)}
               {_time} {set ti $temp($item)}
            }
	 }

     set username ""
     #puts "biocorechat: s=$s, pr=$pr, ty=$ty"

     if { $ty != "3" } {  ; # not a server message
        if [catch {set username [::biocore::getUserName $s ]} errmsg] {
           # if we make it in here, we had an error thrown
           global errorInfo
           global errorCode
           puts "biocorechat) Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
        }
     }

	  set ti [string range $ti 0 9]
	  set ti [clock format $ti -format "%a, %b %d, %Y - %k:%M"]

	  #http://www.codecomments.com/message603378.html
	  while {[regexp {&\#(\d+);} $m -> dec]} {

	      if { [string first "0" $dec] == 0 } {
		  set sub [string range $dec 1 end]
	      } else {
		  set sub $dec
	      }
	      regsub "&\#$dec;" $m [format %c $sub] m
	  }

	  append chat_window $chatWindow.pastChatsFrame.chats_text_ $p

	  $chat_window configure -state normal
	  
	  $chat_window insert end $ti date
	  $chat_window insert end ":" date

#  $chat_window insert end " "
     if { $username != ""} {
        $chat_window insert end $username user
     }

     if { $pr == "true"} {; #it's a private message
        $chat_window insert end " (PRIVATE" user
        if { $username != "" && $s == $::biocore::userId } {
           if { $r != 0 } {
              if [catch {set recipName [::biocore::getUserName $r ]} errmsg] {
                 # if we make it in here, we had an error thrown
                 global errorInfo
                 global errorCode
                 puts "biocorechat) Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
              }
              $chat_window insert end " TO $recipName" user
           }
        }
        $chat_window insert end ")" user
     }

     if { $ty != "2" } { ; #not an emote
        $chat_window insert end ">" user
        $chat_window insert end $m
     } else {
        $chat_window insert end " " user
        $chat_window insert end $m user
     }

	  $chat_window insert end \n
	  
	  $chat_window configure -state disabled
	  $chat_window yview moveto 1.0
	  #puts "biocorechat) user $username ($s) says: $m in proj: $p at time: $ti"
     }

      {UserLoggedVectorMessage} {
         foreach item [array names temp] {
            switch $item {
               {pl} {set pl $temp($item)}
               {_p} {set p $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }
         #puts "biocorechat) UserLoggedVector: userlist: $pl project: $p at time: $ti"
	  populate_user_list $::biocore::Project
      }
       {NotebookMessage} {
	   catch {
	   foreach item [array names temp] {
	       #puts "biocorechat) NotebookMessage item $item = $temp($item)"
	       switch $item {
		   {su} { set subject $temp($item) }
		   {se} { set sender $temp($item) }
		   {id} { set id $temp($item) }
		   {t} { set type $temp($item) }
		   {op} { set operation $temp($item) }
		   {_time} { set ti $temp($item) }
		   {_p} { set p $temp($item) }
	       }
	   }
	       if { [string match $type $vmdType] } {
	   set username ""
	   
	   if [catch {set username [::biocore::getUserName $sender ]} errmsg] {
	       # if we make it in here, we had an error thrown
	       global errorInfo
	       global errorCode
	       puts "biocorechat) Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
	   } 	       
	   

	   set ti [string range $ti 0 9]
	   set ti [clock format $ti -format "%a, %b %d, %Y - %k:%M"]
 
	   #http://www.codecomments.com/message603378.html
	   while {[regexp {&\#(\d+);} $subject -> dec]} {
	       
	      if { [string first "0" $dec] == 0 } {
		  set sub [string range $dec 1 end]
	      } else {
		  set sub $dec
	      }
	      regsub "&\#$dec;" $m [format %c $sub] m
	  }
	   
	   append chat_window $chatWindow.pastChatsFrame.chats_text_ $p
  
	   set i ""
	   append i  $chat_window
	   #eval $i tag configure state$id -foreground blue -underline on
	   #eval $i tag bind state$id <Enter> "state$id configure -cursor hand2"
	   #eval $i tag bind state$id <Leave> "state$id configure -cursor {}"
	   #eval $i tag bind state$id <Enter> "::BiocorePubSync::biocore_synchronize $id"
	   
	   $chat_window tag configure state$id -foreground blue -underline on
	   $chat_window tag bind state$id <Enter> "$chat_window configure -cursor hand2"
	   $chat_window tag bind state$id <Leave> "$chat_window configure -cursor {}"

	   $chat_window tag bind state$id <Button-1> "::BiocorePubSync::biocore_synchronize $id 0 $::BiocoreChat::chatWindowName"
	   
	   
	   $chat_window configure -state normal
	   
	   $chat_window insert end $ti date
	   $chat_window insert end ":" date
	   $chat_window insert end " "
	   $chat_window insert end $username user
	   $chat_window insert end ">" user
	   $chat_window insert end " "
	   $chat_window insert end " (VMD State) $subject" state$id
	   $chat_window insert end "\n"
	   
	   $chat_window configure -state disabled
           $chat_window yview moveto 1.0
	   #puts "biocorechat) Got MessageBoardMessage"
	       }
	   }
       }
      {NumLoggedInMessage} {
         foreach item [array names temp] {
            switch $item {
               {n} {set n $temp($item)}
               {_p} {set p $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }
         #puts "biocorechat) NumLoggedIn: number: $n project: $p at time: $ti"
      }

      {BioFsMessage} {
         foreach item [array names temp] {
            switch $item {
               {id} {set id $temp($item)}
               {s} {set s $temp($item)}
               {n} {set n {$temp($item)}}
               {ap} {set ap $temp($item)}
               {ct} {set ct $temp($item)}
               {eT} {set eT $temp($item)}
               {_p} {set proj $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }
         #puts "biocorechat) Biofs: Id: $id name: $n folder: $ap proj: $proj time: $ti  XX"
      }
      {UserProfileMessage} {
         foreach item [array names temp] {
            switch $item {
               {id} {set id $temp($item)}
               {u} {set nick $temp($item)}
               {f} {set F $temp($item)}
               {m} {set M $temp($item)}
               {l} {set L $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }
         #puts "biocorechat) User Profile: Id: $id nick: $nick name: $F $M $L at time: $ti"
      }
      {LoginoutMessage} {
         foreach item [array names temp] {
            switch $item {
               {pl} {set projList $temp($item)}
               {id} {set id $temp($item)}
               {a} {set op $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }

         set username ""

         if [catch {set username [::biocore::getUserName $id ]} errmsg] {
            # if we make it in here, we had an error thrown
            global errorInfo
            global errorCode
            puts "biocorechat) Error getting username: <$errmsg> <$errorInfo> <$errorCode>"
        }


        if { [string compare $username ""] != 0} {
           set ti [string range $ti 0 9]
           set ti [clock format $ti -format "%a, %b %d, %Y - %k:%M"]

           # this loginout is attached to multiple projects.  We have to
           # decide what to do about it.
           if {[catch {regexp {([0-9]+)\,(.*)} $projList a b} errmsg]} {
             set b $projList
           }

           append chat_window $chatWindow.pastChatsFrame.chats_text_ $b

           $chat_window configure -state normal
           $chat_window insert end $ti loginOut
           $chat_window insert end ":" loginOut

           $chat_window insert end "$username " loginOut

           if { $op == "LOGIN"} {
              $chat_window insert end "has logged in." loginOut
           } elseif { $op == "LOGOUT"} {
              $chat_window insert end "has logged out." loginOut
           } elseif { $op == "AUTOLOGOUT"} {
              $chat_window insert end "has been logged out due to inactivity." loginOut
           } elseif { $op == "RELOG"} {
              $chat_window insert end "has relogged in." loginOut
           } elseif { $op == "OPENCP"} {
              $chat_window insert end "has opened the Control Panel." loginOut
           } elseif { $op == "CLOSECP"} {
              $chat_window insert end "has closed the Control Panel." loginOut
           } elseif { $op == "AUTOCLOSECP"} {
              $chat_window insert end "has had their Control Panel closed due to inactivity." loginOut
           } elseif { $op == "AcceptInvitation"} {
              $chat_window insert end "has joined the $pn project." loginOut
           }

           $chat_window insert end \n
           $chat_window configure -state disabled
           $chat_window yview moveto 1.0
        }
         #puts "biocorechat) Loginout: Usr: $id oper: $op to projects: $projList at time: $ti"
      }
      default { 
         #puts stdout "biocorechat) Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
    } foo
    #puts "Error in parseListenerMessages: $foo"
   #puts stdout "biocorechat) Received '$tag' '$cl' '$selfcl' '$props' '$body'"
}; #end parseListenerMessaages

# ------------------------------------------------------------------
# Read data from a channel (the server socket) and put it to stdout
# this implements receiving and handling (viewing) a server reply 
proc ::BiocoreChat::read_sock {sock myid} {
    #variable notificationSock

   #puts stdout "biocorechat) preparing to read from server socket"
   set l [read $sock 1]

   if { $l == 2 } {
       #close $notificationSock
      ::BiocoreChat::openWindow
   } else {

      # OK.  We've got a message from the server that there are messages
      # waiting for us.. let's get them
      #puts stdout "biocorechat) Note from server: '$l'"

       #if { ![info exists ::BiocoreChat::notificationSock] } {
       #   ::BiocoreChat::init
       #}

      set strMessages [::biocore::getLatestMessages $myid -1]
      #puts stdout "biocorechat) $strMessages"
      taxparse parseListenerMessages $strMessages
   }
}; #end read_sock

# ------------------------------------------------------------------
proc ::BiocoreChat::check_latest {myid} {
    if { [catch {
   global checkLatestTag

   set strMessages [::biocore::getLatestMessages $myid -1]
   #puts stdout "biocorechat) $strMessages"
   taxparse parseListenerMessages $strMessages
   set checkLatestTag [after 300000 ::BiocoreChat::check_latest $myid]
    } checkLatestError ] } {
	global errorInfo
	global errorCode
	if { [string match $checkLatestError  "Invalid User"] } {
	    set ok [tk_dialog .loggedOut "Logged out" "You have been logged out of BioCoRE. The BioCoRE Chat Window in VMD will now close. If you wish to continue using the BioCoRE chat window, please log in again." "" 0 "Okay"]
	    wm withdraw $::BiocoreChat::chatWindowName
	    #deregister_listener $myid

	}
	#puts "biocorechat) Error in checkLatest: <$checkLatestError> <$errorInfo> <$errorCode>"	
    }
}
# ------------------------------------------------------------------
# Read a line of text from stdin and deal with it.  A control panel
# with an actual gui wouldn't have something like this, of course
proc ::BiocoreChat::read_stdin {wsock} {
  global  eventLoop
  set l [gets stdin]

  # parse l
  if {[string equal -length 4 $l "quit"] } {
    close $wsock             ;# close the socket client connection
    set eventLoop "done"     ;# terminate the vwait (eventloop)
    return
  }

  if {[string equal -length 8 $l "sendchat"] } {
     regexp {sendchat ([1-9]*) (.*)} $l all iProjId strMsg
#     scan $l "%s %i [*]" blah iProjId strMsg
#     puts stdout "biocorechat) all:$all"
#     puts stdout "biocorechat) cmd:$cmd"
#     puts stdout "biocorechat) iProjId:$iProjId"
#     puts stdout "biocorechat) strMsg:$strMsg"
     puts stdout "biocorechat) Ready to send $strMsg to project $iProjId"
     ::biocore::ControlPanelChat cpc 
     cpc configure Send 0
     cpc configure Msg $strMsg

     if [catch {set iRetVal [::biocore::saveCPChat ::biocore::cpc \
                                                   $iProjId]} errmsg] {
        global errorInfo
        global errorCode
        #puts "biocorechat) Error sending chat: <$errmsg> <$errorInfo> <$errorCode>"
     } else {
        #puts "biocorechat) iRetVal was $iRetVal"
     }
     ::biocore::delete cpc
  }

  printMenu
}

# ------------------------------------------------------------------
proc ::BiocoreChat::printMenu {} {
   puts "biocorechat) sendchat XX YY - send message YY to project id XX"
   puts "biocorechat) quit - quit the program"
}

# -------------------------------------------------------------------------
# -------------------------------------------------------------------------

proc ::BiocoreChat::init { } {

    variable mostRecent
    variable w
    variable strId
    variable notificationSock
    variable currentProject

    # get info from the biocore api file (written by the control
    # panel)

    #set anyErrors [::biocore::initDefault "vmdChat"]
    if { [catch { ::biocore::initDefault "vmdChat" }  anyErrors]  } {
	return 0
    } else {
	set isOk [test_verify]
    }


    if { [winfo exists $::BiocoreChat::chatWindowName.login_window] } {
	pack forget $::BiocoreChat::chatWindowName.login_window
    }

    if { $isOk == 0 } {
       error "ERROR: user isn't valid"
	return 0
    }
    
    return 1

}; #end init

# -------------------------------------------------------------------------
# -------------------------------------------------------------------------


proc BiocoreChat::openWindow { } {

variable strId
variable mostRecentSaves
variable vmdType
variable currentProject

    catch {


    #variable chatWindowName
    variable chatWindow
    variable w
variable mostRecent


    if { [winfo exists $::BiocoreChat::chatWindowName] } {
	destroy $::BiocoreChat::chatWindow
    }


    if { ![winfo exists $::BiocoreChat::chatWindowName] } { set w [toplevel $::BiocoreChat::chatWindowName] }

    if { ![::BiocoreChat::init] } {

	set w [::BiocoreLogin::open_new_login_window 0 $::BiocoreChat::chatWindowName]
	after idle [bind $w <Map> { if { [::BiocoreChat::redraw] } { ::BiocoreChat::openWindow }} ]	
	return $w
    }

    after idle [bind $::BiocoreChat::chatWindowName <Map> { if { [::BiocoreChat::redraw] } { ::BiocoreChat::openWindow }}]

    set chatWindowName $w.chatWindow
    
    set chatWindow [frame $w.chatWindow]
    set menuFrame [frame $chatWindowName.menuFrame -padx 5 -pady 5]

    set projectMenuButton [menubutton $menuFrame.projectMenuButton -relief flat -menu $menuFrame.projectMenuButton.projectMenu -text "Project" -width 7 ]

    set projectMenu [menu $projectMenuButton.projectMenu -tearoff 0]

     set helpMenubutton [menubutton $menuFrame.helpMenubutton -menu $menuFrame.helpMenubutton.helpMenu -text "Help" -width 4]
     set helpMenu [menu $menuFrame.helpMenubutton.helpMenu -type normal -title "Help" -tearoff 0]

     $helpMenu add command -label "Biocore Chat Help" -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/biocore/index.html\#chat"

    set pastChatsFrame [frame $chatWindowName.pastChatsFrame]

    set chatScroll [scrollbar $pastChatsFrame.chatScroll  -command ::BiocoreChat::scroll]

    set title "BioCoRE Chat:"
    set projList [::biocore::getProjectList]

    foreach { project id } $projList {

	if { [string match $id $::biocore::Project] } {
	#if { [string match $id $currentProject] } {}
	    wm title $::BiocoreChat::chatWindowName "$title $project"
	}
	set command "::BiocoreChat::switchProject $id; wm title $::BiocoreChat::chatWindowName \"$title $project\""

	$projectMenu add radiobutton -label $project -variable "project" -value $id \
		-command $command

	set var ""
	append var chats_text_ $id

	set $var [text $pastChatsFrame.$var -wrap word -background white -state disabled -yscrollcommand "$chatScroll set"]


	set i ""
	append i $ $var

	eval $i tag configure date -foreground green4
	eval $i tag configure user -foreground red
   eval $i tag configure loginOut -foreground magenta

	#eval $i configure -yscrollcommand {$chatScroll set}

	#getRecentSaves 5 $id

	#getRecentChats $mostRecent $id

    }


    #set curr_id $::biocore::Project
    set curr_id $currentProject

    append currProj $::BiocoreChat::chatWindowName .chatWindow .pastChatsFrame. chats_text_ $curr_id

    #set chats_text [text $pastChatsFrame.chats_text -wrap word -background white -state disabled]

    #$chats_text tag configure date -foreground green4
    #$chats_text tag configure user -foreground red
    
    set entryFrame [frame $chatWindowName.entryFrame]
    set messageLabel [label $entryFrame.messageLabel -text "Message"]
    set chatEntry [entry $entryFrame.chatEntry -background white]

    bind $chatEntry <KeyPress-Return> {::BiocoreChat::sendChat [$::BiocoreChat::chatWindowName.chatWindow.entryFrame.chatEntry get]; $::BiocoreChat::chatWindowName.chatWindow.entryFrame.chatEntry delete 0 end}

    set submitButton [button $entryFrame.chatButton -text "Submit" -command {::BiocoreChat::sendChat [$::BiocoreChat::chatWindowName.chatWindow.entryFrame.chatEntry get];$::BiocoreChat::chatWindowName.chatWindow.entryFrame.chatEntry delete 0 end}]

    set userFrame [frame $pastChatsFrame.userFrame]
    set userScroll [scrollbar $userFrame.userScroll -command {::BiocoreChat::usersScroll } -background white]

    set userList [listbox $userFrame.userList  -selectmode single -exportselection false -yscrollcommand "$userScroll set" -background white]

    #set ::biocore::Project 1
    set currentProject 1

    set projList [::biocore::getProjectList]

    #puts "biocorechat) projList = $projList"
    #puts "biocorechat) proj 1 = [lindex $projList 1]"
    set ::biocore::Project [lindex $projList 1]


    populate_user_list $::biocore::Project
    #populate_user_list $currentProject

    $userScroll configure -command "$userList yview"
pack $userFrame -side right -fill y -anchor e
pack $userScroll -side right -fill y -expand y
pack $userList -side right -fill y -expand y

     pack $helpMenubutton -side right -fill x

    pack $chatWindow -fill both -expand 1

    pack $menuFrame -side top -fill both
    pack $pastChatsFrame -side top -fill both -expand 1
    pack $projectMenuButton -side left
    eval pack $currProj -side left -fill both -expand 1 -anchor w
    pack $chatScroll -side left -fill y  -anchor e
    pack $entryFrame -side bottom -fill x  -anchor s
    pack $messageLabel -side left
    pack $chatEntry -side left -fill x -expand 1
    pack $submitButton -side left

    $currProj yview moveto 1.0

    #getRecentSaves 5 $::biocore::Project
    #getRecentChats $mostRecent $::biocore::Project

    # at this point, we should be a registered user, or we should have
    # printed failure, anyway..  In a real app you would do something
    # different in test_verify than just print an error
    set listId [register_listener "cp"]
    scan $listId "%s %s" strId strLast
    #puts "biocorechat) Listener is registered. Listener ID: $strId last access: $strLast"

    
    set listPort [::biocore::getListenerPort]
    
    # the java control panel adds projects here.  That code has already
    # been tested, though.
    
    #test_getListenerPrefs "tclTestCP"
    
    # now we are ready to start the socket listening
    # this is a synchronous connection: 
    # The command does not return until the server responds to the 
    #  connection request
    regexp "://(.*?)\[:/\]" $::biocore::URL Junk strMachine
    #puts "biocorechat) opening connection to $strMachine on port $listPort"
    set notificationSock [socket $strMachine $listPort]
    puts $notificationSock "<SessionID>"
    flush $notificationSock
    puts $notificationSock $::biocore::Session
    flush $notificationSock
    puts $notificationSock "</SessionID>"
    flush $notificationSock
    puts $notificationSock "<CPID>"
    flush $notificationSock
    puts $notificationSock "$strId"
    flush $notificationSock
    puts $notificationSock "</CPID>"
    flush $notificationSock
    #puts "biocorechat) done opening connection"
    
    #if {[eof $esvrSock]} { # connection closed .. abort }
    
    # configure channel modes
    # ensure the socket is NOT line buffered so we don't wait for a line of text 
    # at a time 
    # Depending on your needs you may also want this unbuffered so 
    # you don't block in reading a chunk larger than has been fed 
    #  into the socket
    # i.e fconfigure $esvrSock -blocking off
    fconfigure $notificationSock -buffering none -blocking off -encoding binary
    
    # Setup monitoring on the socket so that when there is data to be 
    # read the proc "read_sock" is called
    fileevent $notificationSock readable [list ::BiocoreChat::read_sock $notificationSock $strId]

    set checkLatestTag [after 1000 ::BiocoreChat::check_latest $strId]

::BiocorePubSync::bio_startup

    return $w
} foo
#puts "biocorechat) error in opening window: $foo"

}


proc ::BiocoreChat::sendChat { message } {

variable currentProject

    if { ![string match $message ""] } {    
    ::biocore::ControlPanelChat cpc 
    ::biocore::cpc configure Send 0
    ::biocore::cpc configure Msg $message

    #if [catch {set iRetVal [::biocore::saveCPChat ::biocore::cpc \
	\#$::biocore::Project]} errmsg] {}
if [catch {set iRetVal [::biocore::saveCPChat ::biocore::cpc $currentProject]} errmsg] {
        global errorInfo
        global errorCode
        puts "biocorechat) Error sending chat: <$errmsg> <$errorInfo> <$errorCode>"
	 if { [string first "couldn't open socket" $errmsg] != -1 } {
	     set okay [tk_dialog .error "Error" "There was an error in performing the task you requested.\nPlease be sure the server name you specified is correct, and that you have a working Internet\nconnection and try again." "" 0 "Okay"]
	 }
    } else {
        #puts "biocorechat) iRetVal was $iRetVal"
    }
    ::biocore::delete cpc
    }
    
}

proc ::BiocoreChat::switchProject { newProj } {

    #variable chatWindowName
    variable chatWindow
    variable mostRecent
    variable strId
    variable currentProject

    set chatWindowName $::BiocoreChat::chatWindowName.chatWindow

    append currProj $::BiocoreChat::chatWindowName .chatWindow .pastChatsFrame. chats_text_ $currentProject
    append newProject  $::BiocoreChat::chatWindowName .chatWindow .pastChatsFrame. chats_text_ $newProj
    append scrollbar $chatWindow .pastChatsFrame.chatScroll

    $newProject configure -state normal

    eval pack forget $currProj
    pack forget $scrollbar

    eval pack $newProject -side left -fill both -expand 1 -anchor w
    pack $scrollbar -side left -fill y  -anchor e

    #set ::biocore::Project $newProj
    set currentProject $newProj
    set text [$newProject get 0.0 end]

    if { [string match  [string trim [$newProject get 0.0 end]] ""] } {
       #getRecentChats $mostRecent $newProj

	::biocore::getLatestMessages $strId -1
    }

    populate_user_list $newProj

    $newProject yview moveto 1.0
    $newProject configure -state disabled

}

proc ::BiocoreChat::getRecentChats { num projId } {

   if [catch {set strMessages [::biocore::getRecentChats $num $projId]} \
                                                              errmsg] {
      global errorInfo
      global errorCode
      puts "biocorechat) Error getting recent chats: <$errmsg> <$errorInfo> <$errorCode>"
   } else {
       taxparse parseListenerMessages $strMessages
   }
}

proc ::BiocoreChat::getRecentSaves { num projId } {
    
    variable mostRecentSaves
    variable vmdType
    if [catch {set strMessages [::biocore::getNotebookEntryListFull $vmdType 0 0 -3 -1 $projId $num 1]} \
                                                              errmsg] {
      global errorInfo
      global errorCode
      puts "biocorechat) Error getting recent saves: <$errmsg> <$errorInfo> <$errorCode>"
   } else {

       # reverse order
       set messages [split $strMessages "\n"]
       set newList ""
       foreach item $messages {
	   set newList [append item $newList "\n"]
       }
       taxparse parseListenerMessages $newList
   }
}



proc ::BiocoreChat::scroll { args } {
    variable chatWindow

    set chatFrame $chatWindow.pastChatsFrame

    foreach window [winfo children $chatFrame] { 
	if { [winfo viewable $window] && [string first "chatScroll" $window ] == -1 && [string first "user" $window] == -1} {
	    eval "$window yview" $args
	}
    }
}


proc ::BiocoreChat::usersScroll { args } {
 
    variable chatWindow

    set scrollFrame $chatWindow.pastChatsFrame.userFrame.userScroll
  
    eval "$scrollFrame yview" $args

}

proc ::BiocoreChat::populate_user_list { project } {

    variable strId

    set userList "$::BiocoreChat::chatWindowName.chatWindow.pastChatsFrame.userFrame.userList"

    $userList delete 0 [$userList size]

    if { $project == 1 } {
	# AUTP
	$userList insert end "Usernames are not"
	$userList insert end "shown for the"
	$userList insert end "All User Test Project"
	return
    }
    set users [::biocore::getUsersLoggedIn $project]

    foreach {name id} $users {
	if { ![string match $name ""] && ![string match $name "null"]} {
	    $userList insert end $name
	}
    }

}

proc biocorechat_tk_cb { } {

    ::BiocoreChat::openWindow
    return $::BiocoreChat::w
}





##############################
#
# redraw
#
# determines if the window needs to be redrawn
# because the user logged in as a different user
#
proc ::BiocoreChat::redraw { } {

# somehow, we don't have a base .w window
   if { ![winfo exists $::BiocoreChat::chatWindowName] } {
      #puts "biocorechat) $::BiocoreChat::chatWindowName doesn't exist: redrawing"
      return 1
   }

# we have an error window right now
   if { [winfo exists $::BiocoreChat::chatWindowName.error_window] } {
      #puts "biocorechat) $::BiocoreChat::chatWindowName.error_window exists"
      # if they previously returned the error window,
      # check again in case they corrected the problem.
# foobar.  how can we have an error window, but no children for .w ?
      if { [winfo children $::BiocoreChat::chatWindowName] == "" || ![winfo ismapped .w.error_window]} {
         #puts "biocorechat) No children, or error_window isn't mapped"
         return 1
      }
   }

   set userId -1
   # Let's see if we have a valid user
   catch { [set userId [::biocore::verify] ] verifyError } {
       if { [string first "couldn't open socket" $verifyError] != -1 } {
	   tk_messageBox -type ok -message "There was an error in performing the task you requested.\nPlease be sure the server name you specified is correct, and that you have a working Internet\nconnection and try again."
	   return 0
       }
   }

   if { $userId < 0 && [winfo exists $::BiocoreChat::chatWindowName.chatWindow] } {
       # the chat window had previously been open, but they logged out (so userId = -1),
       # so redraw
       return 1 
   }

   # if a user exists, we should be on the main window...
   if {$userId > 0} {
      #puts "biocorechat) user ( $userId) is good."
      if { ! [winfo exists $::BiocoreChat::chatWindowName.chatWindow] } {
         #puts "biocorechat) user is good, but $::BiocoreChat::chatWindowName.chatWindow doesn't exist.  need to redraw"
         return 1
      }
   }

   # foobar.  The code below was checking to see if the user's session
   # had changed in the session file.  Ok to do that, but probably not
   # needed in redraw, since redraw seems to get called 20 times to show
   # the window anyway

   return 0 


    if { [catch {
       #puts "biocorechat) in late catch"
    #Biocore newBio
    #newBio initDefault
	set currSession $::biocore::Session
	::biocore::initDefault "vmdChat"

   if { ![string match $currSession $::biocore::Session] } {

      if { [winfo exists .w.main_window] } {
         #destroy .w.main_window
      }
	#::BiocorePubSync::biocore_handle initDefault
	# reset project (set to 1 for now, (AUTP), but this will have to change)
	#::BiocorePubSync::biocore_handle configure Project 1
      #puts "biocorechat) Sessions differ"
      after idle [return 1]
    }

    } error ] } {
	#puts "biocorechat) Error: $error"
   return 1
    }

    if { $error == 1 } {
	#puts "error = 1: $error"
   return 1
    }
    #puts "biocorechat) returning 0"
   return 0
}; # end redraw

