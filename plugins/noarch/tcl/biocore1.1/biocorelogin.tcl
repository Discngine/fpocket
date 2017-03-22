##
## Plugin for logging into BioCoRE from VMD
##
## Authors: Michael Bach, John Stone
##          vmd@ks.uiuc.edu
##
## $Id: biocorelogin.tcl,v 1.24 2006/09/27 19:10:17 mbach Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/biocore
##
package provide biocorelogin 1.0

package require biocore 1.24
package require biocoreHelper 1.1
#puts "login"
namespace eval ::BiocoreLogin {
    variable w
    variable is_logged_in 0
#    variable m_server "http://biocore.ks.uiuc.edu/biocore/"
    variable m_cp
    #variable biocore
}


########################################
#
# function: BiocoreLogin_tk_cb
#
# callback function used by VMD to return
# a window
#
# parameters: none
# returns: none
#
########################################

proc biocorelogin_tk_cb { } {

    ::BiocoreLogin::open_login_window
    return .loginWindow
}

####################
#
# open_login_window
#
# Opens a login window in the main saved state
# window
#
proc ::BiocoreLogin::open_login_window { } {
    return [open_new_login_window 1 .loginWindow]
}

proc ::BiocoreLogin::doLogin {userName passWord} {
   if {[string equal "" [string trim $userName]]} {
      tk_messageBox -type ok -message "Username must be provided" -title "Error!"
   } elseif {[string equal "" [string trim $passWord]]} {
      tk_messageBox -type ok -message "Password must be provided" -title "Error!"
   } elseif {[string equal "" [string trim $::biocore::URL ]]} {
      tk_messageBox -type ok -message "Server URL must be provided" -title "Error!"
   } else {
#     set ::biocore::URL $::BiocoreLogin::m_server 
      if {[catch {eval ::biocore::ui configure [::biocore::login \
                                   $userName $passWord ]} errmsg]} { 
         global errorInfo errorCode 
         set msg $errmsg
         if {[string equal $errmsg "error.user.invalid" ]} {
            set msg "Invalid Username.  Please try again."
         } elseif {[string equal $errmsg "error.user.wrongpassword" ]} {
            set msg "Incorrect Password.  Please try again."
         }
         tk_messageBox -type ok -message "$msg" -title "Error!"
         #puts "<$errmsg> <$errorInfo> <$errorCode>"

      } else { 
         tk_messageBox -type ok -message \
{BioCoRE Login Successful.
You can now select other items in
the BioCoRE submenu from the VMD
Extensions} -title "Success"
         catch {wm withdraw .loginWindow};  
         catch { wm withdraw $parentWindow }; 
         #catch { wm destroy $parentWindow }; 
      }
   }
}


####################
#
# open_new_login_window
#
# Opens a login window, either in the main saved state
# window or in a separate window
#
# parameters: newWindow - if true, open the login window
# in a new window named .login_window. Else, open it in
# the saved states .w window
#
# parentWindow: the parent window in which to open the login display
#
proc ::BiocoreLogin::open_new_login_window { newWindow parentWindow} {

#puts "Opening login window"
    variable w

    set username ""
    set already_logged_in_text ""
    set height 14


    catch {

    if { !$newWindow } {
#puts "no newWindow"
	if { ![winfo exists $parentWindow] } {
	    set w [toplevel $parentWindow]
	} else {
	    set w $parentWindow
	}
	if { ![winfo exists $w.login_window] } {
	    set login_window [frame $w.login_window]
	} else {
	    set login_window $w.login_window
	}
	wm title $w "Login to BioCoRE"

    } else {
       # this seems to be the standard entry point
#puts "newWindow was there"

	if { ![winfo exists .loginWindow] } {
	    set login_window [toplevel .loginWindow]
	} else {
	    set login_window .loginWindow
	}
	wm title $login_window "Login to BioCoRE"
   ##
   ## make the menu bar
   ##
   frame $login_window.menubar -relief raised -bd 2 ;# frame for menubar
   pack $login_window.menubar -padx 1 -fill x

   menubutton $login_window.menubar.help -text Help -underline 0 \
                                 -menu $login_window.menubar.help.menu

   ##
   ## help menu
   ##
   menu $login_window.menubar.help.menu -tearoff no
   $login_window.menubar.help.menu add command -label "Help..." \
        -command "vmd_open_url \
        [string trimright [vmdinfo www] /]/plugins/biocore/index.html#login"
   # XXX - set menubutton width to avoid truncation in OS X
   $login_window.menubar.help config -width 5
 
   pack $login_window.menubar.help -side right

   pack $login_window.menubar
#  puts "done packing menu"

    }
    # Frames
	if { ![winfo exists $login_window.main_frame] } {

    set main_frame [frame $login_window.main_frame  -borderwidth 1 -highlightbackground black -relief solid -height 70 -width 20]
#    set info_frame [frame $main_frame.info_frame -borderwidth 1 -highlightbackground black -relief solid]
    set info_frame [frame $main_frame.info_frame ]
    #set login_frame [frame $main_frame.login_frame -borderwidth 1 -highlightbackground black -relief solid]
    set user_frame [frame $main_frame.user_frame  -borderwidth 1 -highlightbackground black -relief solid]
    set pass_frame [frame $main_frame.pass_frame  -borderwidth 1 -highlightbackground black -relief solid]
    set serverinfo_frame [frame $main_frame.serverinfo_frame -borderwidth 1 -highlightbackground black -relief solid]
    set server_frame [frame $main_frame.server_frame  -borderwidth 1 -highlightbackground black -relief solid]
    set checkbox_frame [frame $main_frame.checkbox_frame -borderwidth 1 -highlightbackground black -relief solid]
    set button_frame [frame $main_frame.button_frame -borderwidth 2 -highlightbackground black -relief groove]

    # labels
    #set info_label [label $info_frame.info_label -text $biocore_text -wraplength 400 -justify left]
    set cp_label [label $checkbox_frame.cp_label -text "Open a BioCoRE Control Panel" -wraplength 400 -justify left]

    set user_label [label $user_frame.user_label -text "Username:" -justify left]
    set user_text [entry $user_frame.user_text -textvariable userName]

    set pass_label [label $pass_frame.pass_label -text "Password:" -justify left]
    set pass_text [entry $pass_frame.pass_text -textvariable passWord -show "*"]

    set server_label [label $server_frame.server_label -text "BioCoRE server:" -justify left]
    set server_text [entry $server_frame.server_text -textvariable \
    ::biocore::URL ]
    # Checkbox
    set cp_checkbox [checkbutton $checkbox_frame.cp_checkbox -variable m_cp]

    bind $pass_text <KeyPress-Return>  { \
        ::BiocoreLogin::doLogin $userName $passWord ; set passWord "" }

    # Buttons
    #set logon_button [button $button_frame.logon_button -command {::BiocoreLogin::open_control_panel $::BiocoreLogin::m_server; if { $m_cp } { }; catch {wm withdraw .loginWindow}; catch { wm withdraw $parentWindow };} -text "Log in to BioCoRE"]
    set logon_button [button $button_frame.logon_button -bg lightgrey -command \
    {
        ::BiocoreLogin::doLogin $userName $passWord 
        set passWord "" 
    } -text "Log in to BioCoRE"]
    set cancel_button [button $button_frame.cancel_button -bg lightgrey -command {catch {wm withdraw .loginWindow}; catch { wm withdraw .w}} -text "Cancel"]


    # Pack
    pack $main_frame -side top -fill both -expand 1

    pack $info_frame -side top -fill both -expand 1 -anchor w
    pack $user_frame -side top -fill both -expand 1 -anchor w
    pack $pass_frame -side top -fill both -expand 1 -anchor w
    pack $serverinfo_frame -side top -fill both -expand 1 -anchor w
    pack $server_frame -side top -fill both -expand 1 -anchor w
    #pack $checkbox_frame -side top -fill both -expand 1 -anchor w
    pack $button_frame -side top -fill both -expand 1 -anchor w

    #pack $info_label -side left -fill both -expand 1 -anchor w

#    pack $biocore_text -side left -fill both -expand 1 -anchor w
    pack $server_label -side left -fill both -expand 1 -anchor w
    pack $server_text -side left -fill both -expand 1 -anchor w

    pack $user_label -side left -fill both -expand 1 -anchor w
    pack $user_text -side left -fill both -expand 1 -anchor w

    pack $pass_label -side left -fill both -expand 1 -anchor w
    pack $pass_text -side left -fill both -expand 1 -anchor w

    pack $cp_label -side left -fill both -expand 1 -anchor w
    pack $cp_checkbox -side left -fill both -expand 1 -anchor w

    pack $logon_button $cancel_button -side left 
    #pack $cancel_button -side left

#puts 5
    if { $newWindow } {
#after idle [bind $login_window <Map>  { if { [::BiocorePubSync::is_empty .loginWindow] } {::BiocoreLogin::open_login_window } }]
    }
   }
} foo

    # put biocore_text window out here, so the text can be changed if necessary

    if { [winfo exists $login_window.main_frame.info_frame.biocore_text] } {
       destroy $login_window.main_frame.info_frame.biocore_text
    }
    if { [winfo exists $login_window.main_frame.info_frame.biocore_text2] } {
       destroy $login_window.main_frame.info_frame.biocore_text2
    }
    if { [winfo exists $login_window.main_frame.info_frame.createaccount] } {
       destroy $login_window.main_frame.info_frame.createaccount
    }
    if { [winfo exists $login_window.main_frame.serverinfo_frame.serverinfo_text] } {
       destroy $login_window.main_frame.serverinfo_frame.serverinfo_text
    }


    set biocore_text [text $login_window.main_frame.info_frame.biocore_text \
                     -cursor {} -wrap word -width 70 -height 2 -relief flat]
    set biocore_text2 [text $login_window.main_frame.info_frame.biocore_text2 \
                     -cursor {} -wrap word -width 70 -height 9 -relief flat]

    set loginURL "https://biocore-s.ks.uiuc.edu/biocore/nonsecure/registration/printUserConsent.do"
    set helpURL "[string trimright [vmdinfo www] /]/plugins/biocore/"
    set biocoreURL "http://www.ks.uiuc.edu/Research/biocore/"


    # help link
    $biocore_text2 tag configure helpLink -underline on -foreground blue
    $biocore_text2 tag bind helpLink <Button-1> "vmd_open_url $helpURL"
    $biocore_text2 tag bind helpLink <Enter> "$biocore_text configure -cursor hand2"
    $biocore_text2 tag bind helpLink <Leave> "$biocore_text configure -cursor {}"

    # login link
    $biocore_text tag configure loginLink -underline on -foreground blue
    $biocore_text tag bind loginLink <Button-1> "vmd_open_url $loginURL"
    $biocore_text tag bind loginLink <Enter> "$biocore_text configure -cursor hand2"
    $biocore_text tag bind loginLink <Leave> "$biocore_text configure -cursor {}"

#puts 6
    $biocore_text insert 1.0 "To use BioCoRE, \
    the Biological Collaborative Research Environment, you must first log in. \
    If you don't yet have a BioCoRE account, you will need to create one.\n"
    $biocore_text configure -state disabled

    set create_account [button \
        $login_window.main_frame.info_frame.createaccount \
        -bg lightgrey -command \
            { ::biocoreHelper::registrationWindowWithProj "VMD (Public)" 127}  \
        -text "Create Account"]

#    $biocore_text insert end $loginURL loginLink
    $biocore_text2 insert 1.0 "For more information about BioCoRE within VMD, please visit:\n"
    $biocore_text2 insert end $helpURL helpLink

    $biocore_text2 insert end "\n\nOnce you have logged in, you can access \
    BioCoRE's VMD features by going to the BioCoRE submenu in the VMD \
    Extensions menu.\n\n"

    $biocore_text2 insert end "If you have forgotten your BioCoRE password, \
    enter your Username in the blank below and "

    $biocore_text2 tag configure resetHref -underline on -foreground blue
    $biocore_text2 tag bind resetHref <Button-1> { 
       if {[string equal "" [string trim $userName]]} {
          tk_messageBox -type ok -message "Username must be provided" -title "Error!"
       } else {
          set answer [tk_messageBox -type okcancel -title "Confirm " -message \
"To reset the password for user '$userName', click OK below. \
An email will be sent to the email address that you\
have registered with the BioCoRE server that will\
contain your new password."]
          if { $answer == "ok" } {
             # do all of the necessary biocore api calls to reset the password
             if {[catch {::biocore::resetPassword $userName } errmsg]} {
                # error
                global errorInfo 
                tk_messageBox -type ok -message \
                 "Error Communicating With BioCoRE:  $errmsg" -title \
                 "Error!"
             } else {
                tk_messageBox -type ok -message "Password reset.  Check your email for your new password" -title "Success!"
             }
          }
       }
    }
    $biocore_text2 tag bind resetHref <Enter> "$biocore_text2 configure -cursor hand2"
    $biocore_text2 tag bind resetHref <Leave> "$biocore_text2 configure -cursor {}"

    $biocore_text2 insert end "click here to reset your BioCoRE password.\n" resetHref

#puts 7
    $biocore_text2 configure -state disabled

#    pack $biocore_text -side left -expand 1 -anchor n
#    pack $create_account -side left -expand 1 -anchor s
#    pack $biocore_text2 -side left -expand 1 -anchor s
    pack $biocore_text 
    pack $create_account 
    pack $biocore_text2 


    set serverinfo_text [text $login_window.main_frame.serverinfo_frame.serverinfo_text -cursor {} -wrap word -width 70 -height 2]

    $serverinfo_text insert 1.0 "If you wish to connect to a different BioCoRE server, please input the URL of that server below.  You probably won't need to change this.\n"

    $serverinfo_text configure -state disabled

    pack $serverinfo_text -side left -fill both -expand 1 -anchor w

#puts 7
    if { !$newWindow } {
#puts 8

	pack $w.login_window -fill both -expand 1
	if { [winfo exists $w.error_window] } {
	    pack forget $w.error_window
	}
	if { [winfo exists $w.main_window] } {
	    pack forget $w.main_window
	}
	bind $w.login_window <Destroy> { pack forget $w.login_window }
#puts 9
	return $w
    } else {
#puts 10
	return $login_window
    }
}
