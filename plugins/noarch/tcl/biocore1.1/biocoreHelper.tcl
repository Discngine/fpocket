#***************************************************************************
# 
#            (C) Copyright 2000-2006 The Board of Trustees of the
#                        University of Illinois
#                         All Rights Reserved
#
#***************************************************************************

# BioCoRE helper procedures in TCL 

package provide biocoreHelper 1.1

package require biocore 1.21


namespace eval ::biocoreHelper:: {
   namespace export registrationWindow

   variable w
   variable guestFrame
   variable fullFrame1
   variable fullFrame2
   variable licenseAgreeButton 
   variable consentAgreeButton 
   variable strFirst 
   variable strMiddle 
   variable strLast 
   variable strEmail 
   variable strLogin
   variable joinProjectCheckbox "1"
   variable projId

   variable titleOptionMenu

   variable affiliation
   variable title
   variable dept
   variable institution
   variable fieldofstudy
   variable yearsexperience
   variable generalApproach

   variable specialty

   variable useCollabResearch
   variable useCrossCollab
   variable useTeachGrads
   variable useTeachUndergrads
   variable useNonAcademicTraining
   variable useOther
   variable otherUseText
   variable mostOften

   variable numCollabs
   variable collabsYear

   variable softwareWork
   variable fixProblems
   variable usePrograms
   variable communicateClearly
   variable followHappenings
   variable rewarding
   variable virtualCollab
   variable getWorkDoneEasily
   variable developTrustEasily
   variable notIsolated

}


proc ::biocoreHelper::registrationWindow {} {
   ::biocoreHelper::registrationWindowWithProj "" 0
}
# ----------------------------------------------------------------------
#  convenience procedure to print a Tk window for handling the consents
#  and registration.
#   if [catch {set clText [Biocore_getConsentLicenseText self ]} errmsg] {
#   if [catch {set clText [Biocore_getConsentLicenseText ]} errmsg] {
#   if [catch {set clText [getConsentLicenseText ]} errmsg] {
#   if [catch {set clText [getConsentLicenseText self ]} errmsg] {
proc ::biocoreHelper::registrationWindowWithProj {strProjName iProjId} {

   package require Tk

   # let's see if this is being done from within VMD.  
   if {[catch {[format catch] [vmdinfo version]}]} {
      set helpCommand {tk_messageBox -title "Help" -message \
        "You can create a BioCoRE account here.  Agree to the \
        forms provided, and give your name, a valid email address, \
        and the login name that you wish to have." }
   } else {
      set helpCommand "vmd_open_url http://biocore.ks.uiuc.edu/biocore/docs/tclLogin.html"
   }


   variable w
   variable guestFrame
   variable fullFrame1
   variable fullFrame2
   variable licenseAgreeButton 
   variable consentAgreeButton 
   variable strFirst 
   variable strMiddle 
   variable strLast 
   variable strEmail 
   variable strLogin
   variable titleOptionMenu
#   global licenseAgreeButton consentAgreeButton strFirst strMiddle strLast \
#  variable         strEmail strLogin

   wm withdraw .

   if [catch {set clText [::biocore::getConsentLicenseText ]} errmsg] {

      global errorInfo errorCode
      tk_messageBox -title "Error!" -message  "Error Communicating with the
BioCoRE Server:\n\n$errmsg\n\nPlease Try Again Later."
      return
   } else {
      foreach { name val } $clText {
         switch $name {
            {license} {
               # get rid of the \"
               regsub -all "\\\\\"" $val "\"" licenseText
            }
            {consent} {
               set consentText $val
               regsub -all "&#039;" $consentText "'" consentText
# doesn't work              regsub -all "\\\"" $consentText "\"" consentText
            }
         }
      }
   }

   if { [winfo exists .consentLoginWindow] } {
      wm deiconify $w
      return
   }


   set w [toplevel .consentLoginWindow ]
   wm title $w "License and Consent Agreement"


   #  ---------------------------------------- Help Menu
   frame $w.menubar -relief raised -bd 2 ;# frame for menubar
   pack $w.menubar -padx 1 -fill x

   menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

   ##
   ## help menu
   ##
   menu $w.menubar.help.menu -tearoff no 
   $w.menubar.help.menu add command -label "Help..."  -command $helpCommand
#           {puts "Help would be here.  Fix the source file."}
#           "vmd_open_url http://biocore.ks.uiuc.edu/biocore/docs/tclLogin.html"
   # XXX - set menubutton width to avoid truncation in OS X
   $w.menubar.help config -width 5

   pack $w.menubar.help -side right


## ---------------- begin  guestFrame ----------------------------------
   set guestFrame [ frame $w.guest ]

   # let's put some text at the top.
   set descT [text $guestFrame.descText -height 11 -wrap word -relief flat]
   $descT insert end \
"There are two different levels of BioCoRE registration.  The Guest registration
gives you the ability to see public projects that other BioCoRE members have
created and allows you to evaluate the BioCoRE environment.  To obtain a Guest
registration, all you need to do is provide your name, suggested login, and a
valid email address.  However, there are a lot of additional features within
BioCoRE that you can get by providing slightly more information about yourself.
By giving a little more background information (about your field of research,
etc) you can become fully registered within the BioCoRE environment.  This will
allow you to join private projects that you have been invited to, and will also
let you create your own projects that others can join.  You can upgrade to a
full account after you have tried out the Guest account for a while."

   $descT configure -state disabled
   pack $descT -expand true

   #  ----------------------------------------License text box and checkbutton
   set f [frame $guestFrame.license]
   pack [label $guestFrame.label -width 80 -text "BioCoRE User License"]

   # h (text box and scroll bar)
   set h [frame $f.textBox]
   text $h.text -height 10 -bd 2 -yscrollcommand "$h.vscr set"
   scrollbar $h.vscr -command "$h.text yview"
   $h.text insert end $licenseText
   $h.text configure -state disabled 
   pack $h.text $h.vscr -side left -fill y

   # g (checkbox and label)
   set g [frame $f.check]
   
   set agreeLicense [checkbutton $g.licenseAgree -variable ::biocoreHelper::licenseAgreeButton]
   pack $agreeLicense [label $g.agreeText \
         -text "I agree to the BioCoRE license*"] \
         -side left 
    
   pack $h 
   pack $g -side left
   pack $f
   #  end ------------------------------------License text box and checkbutton

   #  ----------------------------------------Consent text box and checkbutton
   set f [frame $guestFrame.consent]
   pack [label $f.label -width 80 -text "Consent Form for BioCoRE Users"]
   set h [frame $f.textBox]
   text $h.text -height 10 -bd 2 \
         -yscrollcommand "$h.vscr set" -wrap word
   scrollbar $h.vscr -command "$h.text yview"
   $h.text insert end $consentText
   $h.text configure -state disabled 
   pack $h.text $h.vscr -side left -fill y

   # g (checkbox and label)
   set g [frame $f.check]
   set agreeConsent [checkbutton $g.consentAgree -variable ::biocoreHelper::consentAgreeButton]
   pack $agreeConsent [label $g.agreeText \
      -text "I agree to participate in the study described above*"] \
      -side left 
    
   pack $h 
   pack $g -side left
   pack $f
   #  end ------------------------------------Consent text box and checkbutton

   set f [frame $guestFrame.name]
   pack [label $f.fnLabel -text "First Name*"] -side left
   pack [entry $f.firstName -width 15 -textvariable ::biocoreHelper::strFirst] -side left 

   pack [label $f.miLabel -text "Middle Initial"] -side left
   pack [entry $f.middleInitial -width 2 -textvariable ::biocoreHelper::strMiddle] -side left 

   pack [label $f.lnLabel -text "Last Name*"] -side left
   pack [entry $f.lastName -width 15 -textvariable ::biocoreHelper::strLast] -side left 

   pack $f -fill x -pady 10

   set f [frame $guestFrame.emailLogin]

   pack [label $f.emLabel -text "Email Address*"] -side left
   pack [entry $f.email -width 25 -textvariable ::biocoreHelper::strEmail] -side left 

   pack [label $f.loLabel -text "Desired Login Name*"] -side left
   pack [entry $f.login -width 10 -textvariable ::biocoreHelper::strLogin] -side left 

   pack $f -fill x

   set ::biocoreHelper::projId $iProjId
   if {$iProjId > 0} {
      set g [frame $guestFrame.joinProj]
      set joinProjButton [checkbutton $g.joinCheckbox \
                              -variable ::biocoreHelper::joinProjectCheckbox]
      pack $joinProjButton [label $g.joinText -text \
                       "Automatically join project: $strProjName"] -side left 
      pack $g -fill x
   }

   set f [frame $guestFrame.buttons]
   button $f.b1 -text {Register Guest Account} -default normal -command \
                  {::biocoreHelper::check_consent ::biocoreHelper::w partial}
   button $f.b3 -text {Continue With Full Account} -default normal -command \
                  {::biocoreHelper::check_consent ::biocoreHelper::w full}
   button $f.b2 -text Cancel -default normal -command {
      destroy $::biocoreHelper::w
#      wm withdraw $::biocoreHelper::w
#      puts "in cancel"
   }
   pack $f.b1 $f.b3 $f.b2 -side left
   pack $f -pady 2 -side left


   pack [label $f.required -text "* denotes a required field" -anchor e ] \
                                                                -side bottom 
## ---------------- end guestFrame ----------------------------------

## --------------- begin fullFrame1 ----------------------------------------
   set fullFrame1 [ frame $w.full1 ]

   grid [label $fullFrame1.introText -text "Full User Registration"] -columnspan 2

   # Affiliation
   tk_optionMenu $fullFrame1.affil ::biocoreHelper::affiliation \
    "" "Academic" "Government" "Corporate" "Non-profit" "Other"

   trace add variable ::biocoreHelper::affiliation write \
                                      "::biocoreHelper::changeTitleDrop;#"

   grid [label $fullFrame1.affilText -text "Affiliation*"]  $fullFrame1.affil 
      #                         -side left -anchor w -fill x

   # Title
   set titleOptionMenu [tk_optionMenu $fullFrame1.title ::biocoreHelper::title \
    "" "Full Professor" "Assistant Professor" "Associate Professor" \
    "Post Doc Associate" "Graduate Student" "Undergraduate" \
    "Programmer" "Other" ]

   grid [label $fullFrame1.titleText -text "Title*"]  $fullFrame1.title 
      #                         -side left -anchor w -fill x

   # Department
   grid [label $fullFrame1.deptDesc -text "Department(s)*"]  \
        [entry $fullFrame1.dept -width 25 -textvariable ::biocoreHelper::dept] 

   # Institution
   grid [label $fullFrame1.institutionDesc -text "Institution(s)*"]  \
        [entry $fullFrame1.institution -width 25  \
                                 -textvariable ::biocoreHelper::institution] 

   # Field of study
   grid [label $fullFrame1.fosDesc -text "Field Of Study*"]  \
        [entry $fullFrame1.fos -width 25  \
                                 -textvariable ::biocoreHelper::fieldofstudy] 

   # years experience
   grid [label $fullFrame1.yeDesc -text \
                             "Years of Experience in Field of Study*"]  \
        [entry $fullFrame1.ye -width 25  \
                             -textvariable ::biocoreHelper::yearsexperience] 

   # general approach
   set gaFrame [ frame $fullFrame1.gaRadio ]
   pack [ radiobutton $gaFrame.theo -text Theoretician \
              -variable ::biocoreHelper::generalApproach -value theoretician] 
   pack [ radiobutton $gaFrame.exp -text Experimentalist \
              -variable ::biocoreHelper::generalApproach -value experimentalist]
   grid [label $fullFrame1.gaDesc -text \
"General Approach to 
Field of Study*"]  \
        $gaFrame


   # specialty 
   grid [label $fullFrame1.specDesc -text "Specialty*"]  \
        [entry $fullFrame1.spec -width 25  \
                             -textvariable ::biocoreHelper::specialty] 

   # How to use BioCoRE?
   set htuFrame [ frame $fullFrame1.htuChecks ]
   pack [ checkbutton $htuFrame.useCollabResearch -text \
              "Collaborative research within my field" \
              -variable ::biocoreHelper::useCollabResearch]
   pack [ checkbutton $htuFrame.useCrossCollab -text \
              "Cross-disciplinary collaborative research" \
              -variable ::biocoreHelper::useCrossCollab ]
   pack [ checkbutton $htuFrame.useTeachGrads -text \
              "Teaching/mentoring graduate students" \
              -variable ::biocoreHelper::useTeachGrads ]
   pack [ checkbutton $htuFrame.useTeachUndergrads -text \
              "Teaching/mentoring undergraduate students" \
              -variable ::biocoreHelper::useTeachUndergrads ]
   pack [ checkbutton $htuFrame.useNonAcademicTraining -text \
              "Non-academic training" \
              -variable ::biocoreHelper::useNonAcademicTraining ]
   set htuOtherFrame [ frame $htuFrame.other ]
   pack [ checkbutton $htuOtherFrame.useOther -text \
              "Other use: " \
              -variable ::biocoreHelper::useOther ] -side left
   pack [entry $htuOtherFrame.otherText -width 15  \
                     -textvariable ::biocoreHelper::otherUseText] -side right
   pack $htuOtherFrame

   grid [label $fullFrame1.howToUseDesc -text \
"How do you intend to use   
BioCoRE? Choose all that apply.*"]  \
        $htuFrame

   # Which use most often?
   set mostOftenOptionMenu [tk_optionMenu $fullFrame1.mostOften \
                         ::biocoreHelper::mostOften \
    "" "Collaborative research within my field" \
    "Cross-disciplinary collaborative research" \
    "Teaching/mentoring graduate students" \
    "Teaching/mentoring undergraduate students" \
    "Non-academic training" \
    "Other Use" ]

   grid [label $fullFrame1.mostOftenText -text \
"Which of the above do you think you 
will use BioCoRE for most often?*"]  $fullFrame1.mostOften 


   # How many collaborations are you presently involved in?*
   grid [label $fullFrame1.numCollabsDesc -text \
"How many collaborations are 
you presently involved in?*"]  \
        [entry $fullFrame1.numCollabs -width 5  \
                             -textvariable ::biocoreHelper::numCollabs] 

   # How many collaborations do you average in a year?*
   grid [label $fullFrame1.collabsYearDesc -text \
"How many collaborations do 
you average in a year?*"]  \
        [entry $fullFrame1.collabsYear -width 5  \
                             -textvariable ::biocoreHelper::collabsYear] 


   set f [frame $fullFrame1.buttons]
   button $f.b1 -text {Previous Page} -default normal -command \
                  {pack forget $::biocoreHelper::fullFrame1 
                   pack $::biocoreHelper::guestFrame}
   button $f.b3 -text {Next Page} -default normal -command \
                  {::biocoreHelper::check_full1 ::biocoreHelper::w }
   button $f.b2 -text {Cancel Registration} -default normal -command {
      destroy $::biocoreHelper::w
   }
#   pack $f.b3 $f.b1 $f.b2 -side left
   pack $f.b1 $f.b3 $f.b2 -side left
#   pack $f -pady 2 -side left -fill x
   set reqFields [label $fullFrame1.required -text "* denotes a required field"]
   grid $f -columnspan 2
   grid $reqFields -columnspan 2 -sticky se
#   pack $f -pady 2 -side left -fill x


#   pack [label $f.required -text "* denotes a required field" -anchor e ] \
#                                                                -side bottom 

## --------------- end fullFrame1 ----------------------------------------


## --------------- begin fullFrame2 ----------------------------------------
   set fullFrame2 [ frame $w.full2 ]

   grid [label $fullFrame2.introText -text "Full User Registration Page 2"] -columnspan 2

   # optional question
   set opMenu [tk_optionMenu $fullFrame2.op1 \
                         ::biocoreHelper::softwareWork \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op1Text -text \
"I can get most software programs to do 
what I want in a short amount of time." ]  $fullFrame2.op1 

   set opMenu [tk_optionMenu $fullFrame2.op2 \
                         ::biocoreHelper::fixProblems \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op2Text -text \
"I can fix most problems with 
software programs without help." ]  $fullFrame2.op2

   set opMenu [tk_optionMenu $fullFrame2.op3 \
                         ::biocoreHelper::usePrograms \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op3Text -text \
"I can use programs meant to assist 
collaborative work without difficulty."]  $fullFrame2.op3

   set opMenu [tk_optionMenu $fullFrame2.op4 \
                         ::biocoreHelper::communicateClearly \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op4Text -text \
"Communicating clearly with others 
in a virtual group is not a problem."]  $fullFrame2.op4

   set opMenu [tk_optionMenu $fullFrame2.op5 \
                         ::biocoreHelper::followHappenings \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op5Text -text \
"I can follow what is happening in 
a virtual group without difficulty."]  $fullFrame2.op5

   set opMenu [tk_optionMenu $fullFrame2.op6 \
                         ::biocoreHelper::rewarding \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op6Text -text \
"Collaborating with others on scientific 
projects is always a rewarding experience."]  $fullFrame2.op6

   set opMenu [tk_optionMenu $fullFrame2.op7 \
                         ::biocoreHelper::virtualCollab \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op7Text -text \
"You get as much out of working with a virtual 
group as you do working with any group."]  $fullFrame2.op7

   set opMenu [tk_optionMenu $fullFrame2.op8 \
                         ::biocoreHelper::getWorkDoneEasily \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op8Text -text \
"It is easy to get work done in a virtual 
group."]  $fullFrame2.op8

   set opMenu [tk_optionMenu $fullFrame2.op9 \
                         ::biocoreHelper::developTrustEasily \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op9Text -text \
"It is easy to develop trust in other group 
members with part of a virtual group."]  $fullFrame2.op9

   set opMenu [tk_optionMenu $fullFrame2.op10 \
                         ::biocoreHelper::notIsolated \
    "" "Strongly Agree" "Moderately Agree" "Somewhat Agree" \
    "Unsure" "Somewhat Disagree" "Moderately Disagree" "Strongly Disagree" ]
   grid [label $fullFrame2.op10Text -text \
"You do not feel isolated when you 
work as part of a virtual group."]  $fullFrame2.op10

   set f [frame $fullFrame2.buttons]
   button $f.b1 -text {Previous Page} -default normal -command \
                  {pack forget $::biocoreHelper::fullFrame2 
                   pack $::biocoreHelper::fullFrame1}
   button $f.b3 -text {Register Full Account} -default normal -command \
                  {::biocoreHelper::check_full2 ::biocoreHelper::w }
   button $f.b2 -text {Cancel Registration} -default normal -command {
      destroy $::biocoreHelper::w
   }
#   pack $f.b3 $f.b1 $f.b2 -side left
   pack $f.b1 $f.b3 $f.b2 -side left
#   pack $f -pady 2 -side left -fill x
   grid $f -columnspan 2
#   pack $f -pady 2 -side left -fill x

## --------------- end fullFrame2 ----------------------------------------









   pack $guestFrame

   tkwait window $w

} ; # end of consentLoginWindow

# ------------------------------------------------------------------
proc ::biocoreHelper::check_consent {w type}  {
   variable licenseAgreeButton 
   variable consentAgreeButton 
   variable strFirst 
   variable strMiddle 
   variable strLast 
   variable strEmail 
   variable strLogin
#   global licenseAgreeButton consentAgreeButton strFirst strMiddle strLast \
#          strEmail strLogin

   # foobar.  There's got to be a better way to do this
   set errMsg "You Must Fill Out The Following:\n"
   set wasError 0

   if {$::biocoreHelper::licenseAgreeButton == 0} {
      set wasError 1
      set errMsg "$errMsg * BioCoRE License Checkbox\n"
   }
   if {$::biocoreHelper::consentAgreeButton == 0} {
      set wasError 1
      set errMsg "$errMsg * Consent for Study Checkbox\n"
   }
   set strFirst [string trim $::biocoreHelper::strFirst]
   if {$strFirst == ""} {
      set wasError 1
      set errMsg "$errMsg * First Name\n"
   }
   set strLast [string trim $::biocoreHelper::strLast]
   if {$strLast == ""} {
      set wasError 1
      set errMsg "$errMsg * Last Name\n"
   }
   set strEmail [string trim $::biocoreHelper::strEmail]
   if {$strEmail == ""} {
      set wasError 1
      set errMsg "$errMsg * Email\n"
   } elseif {[regexp {^.*@.*\..*} $strEmail] == 0} {
      set wasError 1
      set errMsg "$errMsg * Properly formed Email (jdoe@example.com)\n"
   }
   set strLogin [string trim $::biocoreHelper::strLogin]
   if {$strLogin == ""} {
      set wasError 1
      set errMsg "$errMsg * Login\n"
   }

#   puts "license: $licenseAgreeButton"
#   puts "consent: $consentAgreeButton"
#   puts "First Name: $strFirst"
#   puts "Middle : $strMiddle"
#   puts "Last Name: $strLast"
#   puts "Email: $strEmail"
#   puts "Login: $strLogin"

   if {$wasError == 1} {
      tk_messageBox -message  "$errMsg" -title "Must Fill Out Form"
   } else { ;# the user filled out the form
      if {$type == "partial"} {
         if {[catch { ::biocore::registerUser $strFirst \
                              $::biocoreHelper::strMiddle \
                              $strLast $strEmail $strLogin \
                              [::biocoreHelper::getProjects] \
                              } serverError]} {
            # if we make it in here, we had an error thrown
            global errorInfo errorCode
            tk_messageBox -message \
                "Error Communicating with the BioCoRE Server:\n\n$serverError" \
                 -title "Error Talking To BioCoRE"
         } else {
            tk_messageBox -title "Success!" -message \
                "You have been registered with BioCoRE.  Check your email for login instructions."
            destroy $::biocoreHelper::w
         } ; # end the else on not having an error in the API request
      } else {
         # full user request.  We need to clean up and show the next
         # screen
         pack forget $::biocoreHelper::guestFrame
         pack $::biocoreHelper::fullFrame1
         wm title $::biocoreHelper::w "Full Account Registration"
      }

   }

} ; # end of check_consent

# ------------------------------------------------------------------
proc ::biocoreHelper::check_full1 {w }  {
# error check everything
   set errMsg "You Must Fill Out The Following:\n"
   set wasError 0

   if {$::biocoreHelper::affiliation == ""} {
      set wasError 1
      set errMsg "$errMsg * Affiliation\n"
   }
   if {$::biocoreHelper::title == ""} {
      set wasError 1
      set errMsg "$errMsg * Title\n"
   }
   if {[string trim $::biocoreHelper::dept] == ""} {
      set wasError 1
      set errMsg "$errMsg * Department\n"
   }
   if {[string trim $::biocoreHelper::institution] == ""} {
      set wasError 1
      set errMsg "$errMsg * Institution\n"
   }
   if {[string trim $::biocoreHelper::fieldofstudy] == ""} {
      set wasError 1
      set errMsg "$errMsg * Field Of Study\n"
   }
   if {[string trim $::biocoreHelper::yearsexperience] == ""} {
      set wasError 1
      set errMsg "$errMsg * Years of Experience\n"
   } elseif { ![regexp {^[0-9]+$} $::biocoreHelper::yearsexperience ] } {
      set wasError 1
      set errMsg "$errMsg * Years Experience Must Be Integer\n"
   }
   if {[string trim $::biocoreHelper::generalApproach] == ""} {
      set wasError 1
      set errMsg "$errMsg * General Approach to Field\n"
   }
   if {[string trim $::biocoreHelper::specialty] == ""} {
      set wasError 1
      set errMsg "$errMsg * Specialty\n"
   }
   # how do you intend to use BioCoRE
   if {$::biocoreHelper::useCollabResearch == 0   &&
       $::biocoreHelper::useCrossCollab == 0   &&
       $::biocoreHelper::useTeachGrads == 0   &&
       $::biocoreHelper::useTeachUndergrads == 0   &&
       $::biocoreHelper::useNonAcademicTraining == 0   &&
       $::biocoreHelper::useOther == 0 } {
      set wasError 1
      set errMsg "$errMsg * How You Intend To Use BioCoRE\n"
   }
   if {$::biocoreHelper::useOther == 1 && 
       [string trim $::biocoreHelper::otherUseText] == ""} {
      set wasError 1
      set errMsg "$errMsg * Other Use For BioCoRE Text\n"
   }
   if {[string trim $::biocoreHelper::mostOften] == ""} {
      set wasError 1
      set errMsg "$errMsg * Use Most Often\n"
   }
   if {[string trim $::biocoreHelper::numCollabs] == ""} {
      set wasError 1
      set errMsg "$errMsg * Number of Present Collabs\n"
   } elseif { ![regexp {^[0-9]+$} $::biocoreHelper::numCollabs ] } {
      set wasError 1
      set errMsg "$errMsg * Number of Present Collab Must Be Integer\n"
   }
   if {[string trim $::biocoreHelper::collabsYear] == ""} {
      set wasError 1
      set errMsg "$errMsg * Avg Collabs Per Year\n"
   } elseif { ![regexp {^[0-9]+$} $::biocoreHelper::collabsYear ] } {
      set wasError 1
      set errMsg "$errMsg * Avg Collabs Per Year Must Be Integer\n"
   }

   if {$wasError == 1} {
      tk_messageBox -message  "$errMsg" -title "Must Fill Out Form"
   } else { ;# the user filled out the form
      # full user request.  We need to clean up and show the next
      # screen
      pack forget $::biocoreHelper::fullFrame1
      pack $::biocoreHelper::fullFrame2
      wm title $::biocoreHelper::w "Full Account Registration (Page 2)"
   }

} ; # end of check_full1

# ------------------------------------------------------------------
proc ::biocoreHelper::translate {word}  {
   #puts "translating $word"
   if {$word == "Strongly Agree" } {
      return 7
   } elseif {$word == "Moderately Agree" } {
      return 6
   } elseif {$word == "Somewhat Agree" } {
      return 5
   } elseif {$word == "Unsure" } {
      return 4
   } elseif {$word == "Somewhat Disagree" } {
      return 3
   } elseif {$word == "Moderately Disagree" } {
      return 2
   } elseif {$word == "Strongly Disagree" } {
      return 1
   } else {
      return 0
   }
}
# ------------------------------------------------------------------
proc ::biocoreHelper::check_full2 {w}  {
   # submit everything
   variable translate
   if {[catch { ::biocore::registerFullUser \
                              [string trim $::biocoreHelper::strFirst] \
                              [string trim $::biocoreHelper::strMiddle] \
                              [string trim $::biocoreHelper::strLast] \
                              [string trim $::biocoreHelper::strEmail] \
                              [string trim $::biocoreHelper::strLogin] \
                              $::biocoreHelper::affiliation \
                              $::biocoreHelper::title \
                              [string trim $::biocoreHelper::dept] \
                              [string trim $::biocoreHelper::institution] \
                              [string trim $::biocoreHelper::fieldofstudy] \
                              [string trim $::biocoreHelper::yearsexperience] \
                              $::biocoreHelper::generalApproach \
                              [string trim $::biocoreHelper::specialty] \
                              $::biocoreHelper::useCollabResearch \
                              $::biocoreHelper::useCrossCollab \
                              $::biocoreHelper::useTeachGrads \
                              $::biocoreHelper::useTeachUndergrads \
                              $::biocoreHelper::useNonAcademicTraining \
                              $::biocoreHelper::useOther \
                              [string trim $::biocoreHelper::otherUseText] \
                              $::biocoreHelper::mostOften \
                              [string trim $::biocoreHelper::numCollabs] \
                              [string trim $::biocoreHelper::collabsYear] \
                              [translate $::biocoreHelper::softwareWork] \
                              [translate $::biocoreHelper::fixProblems] \
                              [translate $::biocoreHelper::usePrograms] \
                              [translate $::biocoreHelper::communicateClearly] \
                              [translate $::biocoreHelper::followHappenings] \
                              [translate $::biocoreHelper::rewarding] \
                              [translate $::biocoreHelper::virtualCollab] \
                              [translate $::biocoreHelper::getWorkDoneEasily] \
                              [translate $::biocoreHelper::developTrustEasily] \
                              [translate $::biocoreHelper::notIsolated] \
                              [::biocoreHelper::getProjects] \
                              } serverError]} {
      # if we make it in here, we had an error thrown
      global errorInfo errorCode
      tk_messageBox -message \
                "Error Communicating with the BioCoRE Server:\n\n$serverError" \
                 -title "Error Talking To BioCoRE"
   } else {
      tk_messageBox -title "Success!" -message \
         "You have been registered with BioCoRE.  Check your email for login instructions."
      destroy $::biocoreHelper::w
   } ; # end the else on not having an error in the API request

} ; # end of check_full2

proc ::biocoreHelper::getProjects {} {
   if {$::biocoreHelper::joinProjectCheckbox != 0} {
      return $::biocoreHelper::projId
   } else {
      return 0
   }
}

# deal with changing the title dropbox based on what the user
# has chosen for the Affiliation dropbox
proc ::biocoreHelper::changeTitleDrop {} {
   if { $::biocoreHelper::affiliation == "Academic" } {
      $::biocoreHelper::titleOptionMenu delete 0 last
      $::biocoreHelper::titleOptionMenu add radiobutton -label "" \
           -value "" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Full Professor" \
           -value "Full Professor" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Assistant Professor" \
           -value "Assistant Professor" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Associate Professor" \
           -value "Associate Professor" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Post Doc Associate" \
           -value "Post Doc Associate" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Graduate Student" \
           -value "Graduate Student" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton -label "Undergraduate" \
           -value "Undergraduate" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton -label "Programmer" \
           -value "Programmer" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton -label "Other" \
           -value "Other" -variable ::biocoreHelper::title 
      set ::biocoreHelper::title ""
   } elseif { $::biocoreHelper::affiliation != ""} {
      $::biocoreHelper::titleOptionMenu delete 0 last
      $::biocoreHelper::titleOptionMenu add radiobutton -label "" \
           -value "" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Research Scientist" \
           -value "Research Scientist" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton \
           -label "Lab Technician" \
           -value "Lab Technician" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton -label "Programmer" \
           -value "Programmer" -variable ::biocoreHelper::title 
      $::biocoreHelper::titleOptionMenu add radiobutton -label "Other" \
           -value "Other" -variable ::biocoreHelper::title 
      set ::biocoreHelper::title ""
   } else {
      $::biocoreHelper::titleOptionMenu delete 0 last
      set ::biocoreHelper::title ""
   }

}

