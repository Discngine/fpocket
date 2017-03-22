#***************************************************************************
# 
#            (C) Copyright 2000-2007 The Board of Trustees of the
#                        University of Illinois
#                         All Rights Reserved
#
#***************************************************************************

# biocore API in TCL
# usage:  In tcl, do a
#     source biocore.tcl
# and then you are in good shape (or, you should be able to put this in
# a package directory and be OK)

# Change Log
# 1.01:
#   login proc added
# 1.02:
#   get project list proc added
# 1.03:
#   is user currently valid proc added.
# 1.04:
#   file download proc added
# 1.05:
#   file upload proc added
# 1.06:
#   logout proc added
# 1.07:
#   biofs del file, del directory, and create dir procs added
# 1.08:
#   Added functions Biocore_getUserList for a list of users and their ids, 
#   and Biocore_deleteNotebookEntry for deleting a Notebook entry 
#   from the database.
# 1.09
#   Modifications to use collab.filesystem package
# 1.10
#   added the init method that reads in the session/url info from the
#   session file
# 1.11
#   added an initDefault proc that tries the default location of the
#   session file, which is at ~/.biocore/.biocoreSession
#   added the biocore_verify procedure that can be used to determine if
#   a url and session are valid.
# 1.12
#   added registerListener and other stuff necessary to get listeners
#   working via tcl
# 1.13 changed the format of the session API file that is written.  Reworked
#   the error throwing to present more information to the API user.
# 1.14 registration command
# 1.15 convert to actual namespace usage.
# 1.16 added getEligibleProjects, joinProject
# 1.17 converted login to use public/private key encryption
# 1.18 Added variable userId, which is set by init, initDefault and verify
# 1.19 init (and therefore initDefault) raise an error flag (which can be caught
#      by catch) if a bad situation exists)
# 1.20 added resetPassword, changePassword
# 1.21 added registerFullUser
# 1.22 saveNotebookEntry now can handle file uploads
# 1.23 exported deregisterListener, fixed a bug in registerListener that
#      was causing it to be ineffective
# 1.24 added findFile
# 1.25 passes in the source program name so that we can figure out what is
#      causing API errors on the server in a more fine grained way

package provide biocore 1.25

package require http 2.0
namespace eval ::biocore:: {

   variable API_VERSION 1.25

   namespace export setProxy getNotebookEntryListByOrder \
   getNotebookEntryListByUser getNotebookEntryList login logout \
   getConsentLicenseText registerFullUser registerUser \
   initDefault init getListenerPort \
   getListenerPrefs getLatestMessages getRecentChats getEligibleProjects \
   registerListener deregisterListener verify joinProject \
   createBiofsDirectory saveCPChat getProjectList getProjectName getUserList \
   getUserName \
   getNotebookEntryListFull getNotebookEntry getBiofsFile saveNotebookEntry \
   deleteNotebookEntry getBiofsDirectory putBiofsFile putBiofsFileSystem \
   delBiofsFile delBiofsDirectory getJobTypes getAccountsForJob runJob \
   getJobStatus getQueuesForAccount getRequiredJobParameters findFile

   variable BIOCORE_URL "nonsecure/api/APIResult.do"
   variable hasTLS 1
   variable viewedForms 0

   variable URL "http://biocore.ks.uiuc.edu/biocore/"
   variable Session
   variable Project -1
   variable userId -1
   variable sessionFileWritten "DATE"
   variable srcPrg "tclAPI"

   variable userNameCache

   variable lastVerifyCheck 0
   variable lastVerifyValue 0

   if [catch {
           package require tls 
           https::register https 443 ::tls::socket
           #http::register https 444 ::tls::socket

           } ] {
      set hasTLS 0
#   if {![info exists biocoreHush ]} {
#      puts "HTTPS not available. (no TLS package)  Connections must be made via HTTP."
#   }
   }

} ; # end of namespace eval

#if {![info exists biocoreHush ]} {
#   puts "BioCoRE (http://www.ks.uiuc.edu/Research/biocore/) API Version $BIOCORE_API_VERSION"
#}



# ----------------------------------  =  --------------------------------------
# -------------- standard code to give an object - oriented feel
# -------------- to what we are doing

# 'delete' procedure independent of the class
proc ::biocore::delete {args} {
   foreach name $args {
      upvar #0 $name arr
      unset arr        ; # Deletes the object's data
      rename $name {}  ; # Deletes the object command
   }
} ; # end of delete

# No more 'methods' argument here; 'vars' is optional
proc ::biocore::class {classname {vars ""}} {

   # Create the class command, which will allow new instances to be created.
   set template {
      proc @classname@ {obj_name args} {
         # The class command in turn creates an object command.
         # Fewer escape characters thanks to the '@' sign.
         proc $obj_name {command args} \
            "return \[eval dispatch_@classname@ $obj_name \$command \$args\]"

         # Set variable defaults, if any
         upvar #0 $obj_name arr
         @set_vars@

         # Then possibly override those defaults with user-supplied values
         if { [llength $args] > 0 } {
            eval $obj_name configure $args
         }
      }
   }

   set set_vars "array set arr {$vars}"
   regsub -all @classname@ $template $classname template
   if { $vars != "" } {
      regsub -all @set_vars@  $template $set_vars template
   } else {
      regsub -all @set_vars@  $template "" template
   }

   eval $template

   # Create the dispatcher, which does not check what it
   # dispatches to.
   set template {
      proc dispatch_@classname@ {obj_name command args} {
         upvar #0 $obj_name arr
         if { $command == "configure" || $command == "config" } {
            array set arr $args
            #puts "\n"
            #foreach i [array names arr] {
            #   puts "name:$i, value:$arr($i)."
            #}

         } elseif { $command == "cget" } {
            #foreach i [array names arr] {
            #   puts "name:$i, value:$arr($i)."
            #}
            return $arr([lindex $args 0])

         } elseif { $command == "toList" } {
            return [array get arr]

         } else {
            uplevel 1 @classname@_${command} $obj_name $args
         }
      }
   }

   regsub -all @classname@ $template $classname template

   eval $template
} ; # end of class

# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# helper URL classes
proc ::biocore::addIdentParms { strSess strProj otherParam } {
   #global BIOCORE_API_VERSION

   upvar $otherParam params

   # add in our api commands to tell the server that the API is
   # requesting this
   set params(src) "api"
   #set params(apiv) $BIOCORE_API_VERSION
   set params(apiv) $::biocore::API_VERSION

   set params(prg) $::biocore::srcPrg

   # set the session if one was given
   if { [string compare $strSess ""] != 0 } {
      set params(jsessionid) $strSess
   }
   # set the project if one was given
   if { [string compare $strProj ""] != 0 } {
      set params(p) $strProj
   }

   return [array get params]
} ; # end of addIdentparms

# ----------------------------------  =  --------------------------------------
proc ::biocore::encodeURLParams { strSess strProj otherParam } {
   upvar $otherParam pList

   set params [addIdentParms $strSess $strProj pList]

#   return [eval ::http::formatQuery [array get params]]
   return [eval ::http::formatQuery $params]

} ; # end of encodeURLParams


# ----------------------------------  =  --------------------------------------
proc ::biocore::encodeAndSendFile {strURL strSess strProj par binFileData \
                                strDataVar strRemoteName } {
#   puts "encodeAndSendFile: start.  url='$strURL', sess='$strSess', \
#   proj='$strProj', \
#   strDataVar='$strDataVar', remoteName='$strRemoteName'" 
   variable BIOCORE_URL
   package require http 2.2

   upvar $par otherParams

   # start preparing the query
   set binQuery {}
   set strDivider "-------------------[clock seconds][pid]"

   #append binQuery "--"

   append binQuery "--${strDivider}\r\nContent-Disposition: form-data;\
            name=\"$strDataVar\"; filename=\"$strRemoteName\"\r\n\r\n$binFileData\r\n"

   set parList [addIdentParms $strSess $strProj otherParams]

   # parList is now an array of the rest of the choices
   foreach {elem data} $parList {
#        puts "--$strDivider\r\nContent-Disposition: form-data;\
#                name=\"$elem\"\r\n\r\n$data\r\n"   
        append binQuery "--$strDivider\r\nContent-Disposition: form-data;\
                name=\"$elem\"\r\n\r\n$data\r\n"   
   }

   append binQuery "--${strDivider}--"

   # now the query 'string' is ready to go.


   set paramList [encodeURLParams $strSess $strProj otherParams]
#   puts "paramList='$paramList'"
#   set httpHandle [::http::geturl $strURL${BIOCORE_FILE_URL}?$paramList \
#            -type "multipart/form-data; boundary=$strDivider" \
#            -query $binQuery] 
   set httpHandle [::http::geturl $strURL$BIOCORE_URL \
            -type "multipart/form-data; boundary=$strDivider" \
            -query $binQuery] 
#   set httpHandle [::http::geturl $strURL$BIOCORE_URL?$paramList \
   
  # puts "encodeAndSendFile: end"
   return [::http::data $httpHandle]

} ; # end of encodeAndSendFile

# ----------------------------------  =  --------------------------------------
proc ::biocore::encodeAndSend {strMethodType strURL strSess strProj par} {

   variable BIOCORE_URL
   # have to use upvar to pass an array to a procedure
   upvar $par otherParam

   set strParamList [encodeURLParams $strSess $strProj otherParam]


   # test whether this is a GET or a POST
   if { [string match $strMethodType "get"] } {
      set strFullUrl "$strURL$BIOCORE_URL?$strParamList"
      set httpHandle  [::http::geturl $strFullUrl ]
   } else {
      set strFullUrl "$strURL$BIOCORE_URL"
      set httpHandle  [::http::geturl $strFullUrl -query $strParamList]
   }
   
   return [::http::data $httpHandle]

} ; # end of encodeAndSend

# ----------------------------------  
proc ::biocore::isValidBiocoreResponse { strResponse listR iSVer} {
   upvar $listR listResult
   upvar $iSVer iServerVersion

   set listSplit [ split $strResponse "\n" ]

   # first value sent back is the server version
   set iServerVersion [lindex $listSplit 0]

   #puts "isValid: iserver is $iServerVersion"
   # second value is a true/false
   set strValid [lindex $listSplit 1]

   # prepare the list for future use
   set listResult [ lrange $listSplit 2 end]
#   return [string match $strValid "0"]
   if { [string match $strValid "0"] } {
      return $strValid 
   } else {
      # puts "in error"
      error "[ lindex $listResult 0 ]" "isValidBiocoreResponse" $strValid
   }
} ; # end of isValidBiocoreResponse

# ----------------------------------  
proc ::biocore::biocoreHttpCopy {url file id {chunk 4096} } {
   set out [open $file w]
   set token [::http::geturl $url -channel $out -blocksize $chunk \
                                         -headers "Cookie jsessionid=$id"]
   close $out
   #puts "after close out"
   # This ends the line started by http::Progress
   upvar #0 $token state
   set max 0
   foreach {name value} $state(meta) {
      if {[string length $name] > $max} {
         set max [string length $name]
      }
   }
#  foreach {name value} $state(meta) {
#    puts [format "%-*s %s" $max $name: $value]
#  }
   return 0
}  


# ----------------------------------  =  --------------------------------------
# ----------------------------------  =  --------------------------------------
# ----------------------------------  
# -------- Biocore "classes"
::biocore::class UserInfo

::biocore::class NotebookEntry {Reply "" Description "" FileUploadName ""}

::biocore::class NotebookEntryInfo 

::biocore::class ControlPanelChat

::biocore::class BiofsDirectory


::biocore::class BiofsDirectoryEntry
proc ::biocore::BiofsDirectoryEntry_printDir {self} {
    puts "DIR Id: [$self cget Id], Par: '[$self cget Parent]', Name: '[$self cget Name]', Icon: '[$self cget Icon]', Time: '[$self cget Time]', Path: '[$self cget Path]'"
}
# ----
proc ::biocore::BiofsDirectoryEntry_printFile {self} {
   #puts "self is $self"
    puts "FILE Id: [[namespace current]::$self cget Id], Name: '[$self cget Name]',\nURL: '[$self cget URL]',\nIcon: '[$self cget Icon]', Length: [$self cget Length], User: '[$self cget User]', Time: '[$self cget Time]', Path: [$self cget Path]'"
}
# ----
proc ::biocore::BiofsDirectoryEntry_scanDir {self iCurLine listResult} {
   # the '2' was discovered after much trial and error.  Because this
   # method is hidden as part of a class, simply saying upvar $a b
   # doesn't work.  The calling method is actually 2 layers up the
   # stack
   upvar 2 $iCurLine iCurrentLine

   # first thing we get back now is the id of the directory
   $self configure Id [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back whether or not this is a 'parent'
   $self configure Parent [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the name of this directory entry
   $self configure Name [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the url of an icon for this directory entry
   $self configure Icon [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the time of this directory entry
   $self configure Time [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get the absolute path of this directory entry
   $self configure Path [lindex $listResult $iCurrentLine]
   incr iCurrentLine
} ; # end of BiofsDirectoryEntry_scanDir

# ----
proc ::biocore::BiofsDirectoryEntry_scanFile {self iCurLine listResult} {
   # see scanDir for an explanation of the '2'
   upvar 2 $iCurLine iCurrentLine

   # first thing we get back now is the id of the file
   #$self configure Id [lindex $listResult $iCurrentLine]
   $self configure Id \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the name of this file
   $self configure Name \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the URL of this file
   $self configure URL \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the URL of an icon for this file
   $self configure Icon \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the Length of this file
   $self configure Length \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the User of this file
   $self configure User \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the time of this file
   $self configure Time \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

   # next we get back the absolute path of this file
   $self configure Path \
                                          [lindex $listResult $iCurrentLine]
   incr iCurrentLine

} ; # end BiofsDirectoryEntry_scanFile

# ----------------------------
# set proxy information
proc ::biocore::setProxy {strHost iPort} {
   ::http::config -proxyhost $strHost -proxyport $iPort
} ; # end of setProxyInformation


proc ::biocore::getNotebookEntryListByOrder { iType iStart iEnd iOrder} {
    ::biocore::getNotebookEntryListFull $iType $iStart $iEnd $iOrder -1
}


proc ::biocore::getNotebookEntryListByUser { iType iStart iEnd iUser} {
    ::biocore::getNotebookEntryListFull $iType $iStart $iEnd 3 $iUser
}

proc ::biocore::getNotebookEntryList { iType iStart iEnd } {
    ::biocore::getNotebookEntryListFull $iType $iStart $iEnd 3 -1
}


# ----------------------------
# login to BioCoRE
proc ::biocore::login {strName strPass} {
   set params(type) "nonauth"
   set params(task) "getKey"

   # we are now ready to actually do the URL work
   set strResponse [::biocore::encodeAndSend post $::biocore::URL \
                                          0 0 params]

   set strResponse [string trim $strResponse]

   # is this a valid request?
   set ret [ ::biocore::isValidBiocoreResponse $strResponse \
                                              listResult iServerVersion]
   if { $ret == 0 } {
      set lll [ split [ lindex $listResult 0 ]]
      set pub [ lindex $lll 0 ]
      set modu [ lindex $lll 1 ]
   } 

   #puts "pub is $pub and modu is $modu"

   # we now have the public key and the mod.. let's encrypt
   # 'pub' is the public key as a large integer, 'mod' is the modulus
   set strEncrypted [::biocore::encryptPass $strPass $pub $modu]

   set logparams(type)  "nonauth"
   set logparams(task) "login"

   # sanitize the entries to handle {}
   regsub -all \{ $strPass {\&#123;} strPass
   regsub -all \} $strPass {\&#125;} strPass
   regsub -all \{ $strName {\&#123;} strName
   regsub -all \} $strName {\&#125;} strName
   set logparams(parameters) [toXML "login" "uname {$strName} pass {$strEncrypted}"]

   # we are now ready to actually do the URL work
   set strResponse [::biocore::encodeAndSend post $::biocore::URL 0 0 logparams]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ ::biocore::isValidBiocoreResponse $strResponse listResult \
                                                         iServerVersion]== 0 } {
      UserInfo ui

      # listResult is now a list of the remainder of the response from the
      # server
      set ::biocore::Session [ lindex $listResult 0 ]
      set ::biocore::userId [ lindex $listResult 1]

      ::biocore::writeDefaultSessionFile

      ui configure Id [ lindex $listResult 1 ]
   } 
   return [ui toList]
} ; # end of ::biocore::login

# ----------------------------
# change BioCoRE password.  It would be wise to make the user
# verify the new password before changing
proc ::biocore::changePassword {strOld strNew } {
   set params(type) "nonauth"
   set params(task) "getKey"

   # we are now ready to actually do the URL work
   set strResponse [::biocore::encodeAndSend post $::biocore::URL \
                             $::biocore::Session $::biocore::Project params]

   set strResponse [string trim $strResponse]

   # is this a valid request?
   set ret [ ::biocore::isValidBiocoreResponse $strResponse \
                                              listResult iServerVersion]
   if { $ret == 0 } {
      set lll [ split [ lindex $listResult 0 ]]
      set pub [ lindex $lll 0 ]
      set modu [ lindex $lll 1 ]
   } 

   #puts "pub is $pub and modu is $modu"

   # we now have the public key and the mod.. let's encrypt
   # 'pub' is the public key as a large integer, 'mod' is the modulus
   set strOldEncrypted [::biocore::encryptPass $strOld $pub $modu]
   set strNewEncrypted [::biocore::encryptPass $strNew $pub $modu]

   set logparams(type)  "utilities"
   set logparams(task) "changePassword"

   # sanitize the entries to handle {}
   set logparams(parameters) [toXML "changePassword" "old {$strOldEncrypted} new {$strNewEncrypted}"]

   # we are now ready to actually do the URL work
   set strResponse [::biocore::encodeAndSend post $::biocore::URL \
                         $::biocore::Session $::biocore::Project logparams]

   set strResponse [string trim $strResponse]

   # check to make sure the user is valid?
   ::biocore::isValidBiocoreResponse $strResponse listResult iServerVersion
} ; # end of ::biocore::changePassword

# ----------------------------
# logout of BioCoRE
proc ::biocore::logout {} {
   set parms(task) "logout"
   set parms(type) "nonauth"
   set parms(parameters) [toXML "logout" "noRedirect true"]
   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend get $::biocore::URL \
                               $::biocore::Session $::biocore::Project parms]
   
   set strResponse [string trim $strResponse]


   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      return 1
   } 
   return 0
} ;  # end of ::biocore::logout

# ----------------------------
# get license and consent text for registration
proc ::biocore::getConsentLicenseText {} {
   #puts "starting in getconsentlicensetext" 
   set params(type) "nonauth"
   set params(task) "consentLicense"

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL 0 0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
     _APItax::parse parseConsentLicense [join [lrange $listResult 0 end] "\n"]

     set response(license) $strLicense
     set response(consent) $strConsent
     variable viewedForms 
     set viewedForms 1
     return [array get response]
   } 
   return 0

} ; # end of ::biocore::getConsentLicenseText

# ----------------------------
# register a new partial user to BioCoRE
proc ::biocore::registerUser {strFirst strMiddle 
                                strLast strEmail strLogin listProjects} {
   variable viewedForms 
   if { $viewedForms == 0 } {
      error "Consent and License Text not yet viewed" "registerUser" -5
   }

   set params(type)  "nonauth"
   set params(task) "registerUser"

   # sanitize the entries to handle {} and set
   set params(parameters) [toXML "registerUser" \
   "first {[string map {\{ \&#123; \} \&#125;} $strFirst]} 
   middle {[string map {\{ \&#123; \} \&#125;} $strMiddle]} 
   last {[string map {\{ \&#123; \} \&#125;} $strLast]} 
   email {[string map {\{ \&#123; \} \&#125;} $strEmail]} 
   login {[string map {\{ \&#123; \} \&#125;} $strLogin]} 
   projList {$listProjects}"]

   # we are now ready to actually do the URL work
    set strResponse [encodeAndSend post $::biocore::URL 0 0 params]

    set strResponse [string trim $strResponse]

   # did this submit work?
   isValidBiocoreResponse $strResponse listResult iServerVersion

   # since we created the guest user fine, let's reset the
   # indicator of whether or not they have viewed the consent and
   # license text
   set viewedForms 0
} ; # end of registerUser

# ----------------------------
# register a new full user to BioCoRE
proc ::biocore::registerFullUser {strFirst strMiddle 
                                strLast strEmail strLogin 
                                strAffil strTitle strDept
                                strInst strFOS strYears
                                strGA strSpec strUseCollab
                                strCrossCollab strUseTeachGrads
                                strUseTeachUndergrads
                                strUseNonAc strUseOther
                                strUseOtherText strMostOften
                                strNumCollabs strCollabsYear
                                strSoftwareWork strFixProblems
                                strUseProgs strCommClearly
                                strFollowHappenings strRewarding
                                strVirtualCollab strGetWorkDone
                                strDevTrust strNotIsolated
                                listProjects} {
   variable viewedForms 
   if { $viewedForms == 0 } {
      error "Consent and License Text not yet viewed" "registerFullUser" -5
   }

   set params(type)  "nonauth"
   set params(task) "registerFullUser"

   # sanitize the entries to handle {} and set
   set params(parameters) [toXML "registerFullUser" \
   "first {[string map {\{ \&#123; \} \&#125;} $strFirst]} 
   middle {[string map {\{ \&#123; \} \&#125;} $strMiddle]} 
   last {[string map {\{ \&#123; \} \&#125;} $strLast]} 
   email {[string map {\{ \&#123; \} \&#125;} $strEmail]} 
   login {[string map {\{ \&#123; \} \&#125;} $strLogin]} 
   affil {[string map {\{ \&#123; \} \&#125;} $strAffil]} 
   title {[string map {\{ \&#123; \} \&#125;} $strTitle]} 
   dept {[string map {\{ \&#123; \} \&#125;} $strDept]} 
   inst {[string map {\{ \&#123; \} \&#125;} $strInst]} 
   fos {[string map {\{ \&#123; \} \&#125;} $strFOS]} 
   years {[string map {\{ \&#123; \} \&#125;} $strYears]} 
   ga {[string map {\{ \&#123; \} \&#125;} $strGA]} 
   spec {[string map {\{ \&#123; \} \&#125;} $strSpec]} 
   usecollab {[string map {\{ \&#123; \} \&#125;} $strUseCollab]} 
   crosscollab {[string map {\{ \&#123; \} \&#125;} $strCrossCollab]} 
   grads {[string map {\{ \&#123; \} \&#125;} $strUseTeachGrads]} 
   undergrads {[string map {\{ \&#123; \} \&#125;} $strUseTeachUndergrads]} 
   nonAc {[string map {\{ \&#123; \} \&#125;} $strUseNonAc]} 
   useOther {[string map {\{ \&#123; \} \&#125;} $strUseOther]} 
   otherText {[string map {\{ \&#123; \} \&#125;} $strUseOtherText]} 
   most {[string map {\{ \&#123; \} \&#125;} $strMostOften]} 
   num {[string map {\{ \&#123; \} \&#125;} $strNumCollabs]} 
   peryear {[string map {\{ \&#123; \} \&#125;} $strCollabsYear]} 
   softwork {[string map {\{ \&#123; \} \&#125;} $strSoftwareWork]} 
   fix {[string map {\{ \&#123; \} \&#125;} $strFixProblems]} 
   useprogs {[string map {\{ \&#123; \} \&#125;} $strUseProgs]} 
   commclearly {[string map {\{ \&#123; \} \&#125;} $strCommClearly]} 
   follow {[string map {\{ \&#123; \} \&#125;} $strFollowHappenings]} 
   rewarding {[string map {\{ \&#123; \} \&#125;} $strRewarding]} 
   virtual {[string map {\{ \&#123; \} \&#125;} $strVirtualCollab]} 
   getwork {[string map {\{ \&#123; \} \&#125;} $strGetWorkDone]} 
   devtrust {[string map {\{ \&#123; \} \&#125;} $strDevTrust]} 
   notIsolated {[string map {\{ \&#123; \} \&#125;} $strNotIsolated]} 
   projList {$listProjects}"]

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL 0 0 params]

   set strResponse [string trim $strResponse]

   # did this submit work?
   isValidBiocoreResponse $strResponse listResult iServerVersion

   # since we created the user fine, let's reset the
   # indicator of whether or not they have viewed the consent and
   # license text
   set viewedForms 0
} ; # end of registerFullUser

######################
#
# resetPassword
# 
# parameters:
#  strName: user who's password we want to reset
#
proc ::biocore::resetPassword {strName} {
   set params(type) "nonauth"
   set params(task) "resetPassword"
   #foobar.. might need to the regsubs to convert {}.  Need to verify
   set params(parameters) [toXML "resetPassword" "uname {$strName}"]

   # we are now ready to actually do the URL work
    set strResponse [encodeAndSend post $::biocore::URL 0 0 params]

    set strResponse [string trim $strResponse]

   # is this user valid?
   return [::biocore::isValidBiocoreResponse $strResponse \
                                             listResult iServerVersion]

} ; # end of ::biocore::resetPassword

# ----------------------------
# BioCoRE initialization
# proper usage might be something like:
#
#  set errorMessages [b init $sessionFileName ]
#  if { [string length $errorMessages] > 0 } {
#     # handle errors
#  }
#
proc ::biocore::initDefault {srcPrg} {
  ::biocore::init $srcPrg "~/.biocore/.biocoreSession"
} ;  # end of ::biocore::initDefault

# ----------------------------
# BioCoRE initialization
# proper usage might be something like:
#
#
proc ::biocore::init {sourcePrg sessionfile} {
  #puts "starting init"
  variable hasTLS 
  variable URL
  variable Session
  variable srcPrg
  variable sessionFileWritten

  set srcPrg $sourcePrg

  #set URL {}
  set sSession {}
  if [catch {
    set sessionstream [open $sessionfile r]
    set sessiondata [read $sessionstream]

    #puts "ready to parse '$sessiondata'"
    _APItax::parse parseSessionFile $sessiondata
    close $sessionstream

    #puts "after parse"
    if { $hasTLS == 1 } {
       set URL $urlsecure
    } else {
       set URL $urlnonsecure
    }

    #puts "before session check"
    if [info exists sSession ] {
       set Session $sSession
    }

#    set sessionFileWritten $written
    #puts "written is $::biocore::sessionFileWritten"

    
    # now that we've gotten the url and the session, let's
    # do a 'verify', so so we know that we are in good shape
    #puts "before verify"
    if {[catch {set i [::biocore::verify ]} errmsg]} {
       # if we make it in here, we had an error thrown
       global errorInfo errorCode
       #puts "Verification Error: <$errmsg> <$errorInfo> <$errorCode>"
       error "Verification Error: <$errmsg> <$errorInfo> <$errorCode>"
    } else {
       if {$i <= 0} {
          set Session ""
          error "Invalid User Info in sessionfile"
       }
    }
    #puts "after verify"
  } cmderrs] {
    #set URL ""
    set Session ""
    #puts "$cmderrs"
    error "Error reading $sessionfile.  ($cmderrs)"
  }

} ;  # end of ::biocore::init

# ----------------------------
proc ::biocore::writeDefaultSessionFile {} {
  file mkdir "~/.biocore"
  ::biocore::writeSessionFile "~/.biocore/.biocoreSession"
} ;  # end of ::biocore::writeDefaultSessionFile (no argument)

# ----------------------------
proc ::biocore::writeSessionFile {sessionfile} {
   #global BIOCORE_API_VERSION

   set theDate [clock format [clock seconds] -format "%a, %d %h %Y %T %Z"]

   #<version>$BIOCORE_API_VERSION</version>
   set data "<?xml version=\"1.0\"?>
<BioCoRE>
   <version>$::biocore::API_VERSION</version>
   <written>$theDate</written>
   <server>
      <URL>$::biocore::URL</URL>
      <URLsecure>$::biocore::URL</URLsecure>
      <URLnonsecure>$::biocore::URL</URLnonsecure>
      <Session>$::biocore::Session</Session>
   </server>
</BioCoRE>
"

   # open the filename for writing
   set fileId [open $sessionfile "w" 0600]

   # send the data to the file -
   puts $fileId $data

   # close the file, ensuring the data is written out before you continue
   #  with processing.
   close $fileId
} ; # end of writeSessionFile with file argument

# ----------------------------
# get the port that the server has set up for listener connections
proc ::biocore::getListenerPort {} {
  
   set params(type) "listener"
   set params(task) "getPort"

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                       0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      return [ lindex $listResult 0 ]
   } 

   return 0

} ; # end of ::biocore::getListenerPort

# ----------------------------
# get preferences for a particular type of listener
proc ::biocore::getListenerPrefs {listType} {
  
   set params(type) "listener"
   set params(task) "prefs"
   set params(parameters) [toXML "listType" "listType {$listType}"]

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                       0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
     return [join [lrange $listResult 0 end] "\n"]

   } 
   return 0

} ; # end of ::biocore::getListenerPrefs

# ----------------------------
# get 'num' recent chats from project 'projId'
proc ::biocore::getRecentChats {num projId} {
  
   set params(type) "chat"
   set params(task) "getRecentChats"
   set params(parameters) [toXML "getRecentChats" "number {$num} project {$projId}"]

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                                               0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
     return [join [lrange $listResult 0 end] "\n"]

   } 

   return 0

} ; # end of ::biocore::getRecentChats

# ----------------------------
# get latest messages for a listener..  Send in a -1 for the
# lastAction if you aren't keeping track of the last time this
# user did anything biocore related.  Otherwise, it needs to be
# the number of milliseconds since the user last did something.
proc ::biocore::getLatestMessages {listId lastAction} {
  
   set params(type) "listener"
   set params(task) "latest"
   set params(parameters) [toXML "latest" "listid {$listId} lastact {$lastAction}"]

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                                               0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
     return [join [lrange $listResult 0 end] "\n"]

   } 

   return 0

} ; # end of ::biocore::getLatestMessages

# ----------------------------------------------------------------------
###############
#
# join a project
#
#             iId - the id of the project to join
#
proc ::biocore::joinProject {iId} {

    set nbparams(type) "utilities"
    set nbparams(task) "joinProject"
    set nbparams(parameters) [toXML "joinProject" "id {$iId}"]
    # we are now ready to actually do the URL work
    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                              $::biocore::Project nbparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       return $listResult
    } 
} ; # end of joinProject

# ----------------------------
# get projects that I'm eligible to join
proc ::biocore::getEligibleProjects {} {
  
   set params(type) "utilities"
   set params(task) "getEligibleProjects"

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                                               0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
#       set result $listResult
#       #regsub "{" $result "" result
#       #regsub "}" $result "" result
#       #regsub -all ";" $result "," result
#       #set projList [split $result "\n"]
#       set numProjects [lindex $result 0]
#       set projList [lrange $result 1 end]
#       set newList ""
#       foreach { proj } $projList {
#          set newProj [split $proj ","]
#          lappend newList [lindex $newProj 2]
#          lappend newList [lindex $newProj 0]
#       }
#     puts "$listResult\n\n"
     set projList ""
     _APItax::parse parseProjectList $listResult

     return $projList
#     return [join [lrange $listResult 0 end] "\n"]

   } 

   return 0

} ; # end of ::biocore::getEligibleProjects

# ----------------------------
# Register a listener
proc ::biocore::registerListener {listenerType} {
  
   set params(type) "listener"
   set params(task) "register"

   set params(parameters) [toXML "register" "listType {$listenerType}"]
   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                       0 params]

   set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      return [ lindex $listResult 0 ]

   } 

   return 0

} ; # end of ::biocore::registerListener


# ----------------------------
# deregister a listener
proc ::biocore::deregisterListener {id} {
  
   set params(type) "listener"
   set params(task) "deregister"

   puts "deregistering $id"
   set params(parameters) [toXML "deregister" "listid $id"]
   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                       0 params]

   set strResponse [string trim $strResponse]
   #puts "deregister strResponse = $strResponse"
   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      return [ lindex $listResult 0 ]

   } 

   return 0

} ; # end of ::biocore::deregisterListener



# ----------------------------
# Is this a valid user?
proc ::biocore::verify {} {
   variable lastVerifyCheck
   variable lastVerifyValue
   variable URL
   variable Session

   if {[expr abs([clock clicks -milliseconds] - $lastVerifyCheck)] < 1000} {
      return $lastVerifyValue
   } else {
      #puts "checking verify"
      set params(type) "nonauth"
      set params(task) "verify"

      # we are now ready to actually do the URL work
      set strResponse [::biocore::encodeAndSend post $::biocore::URL \
                                          $::biocore::Session 0 params]
      set lastVerifyCheck [clock clicks -milliseconds]

      set strResponse [string trim $strResponse]

      # is this user valid?
      set ret [ ::biocore::isValidBiocoreResponse $strResponse \
                                              listResult iServerVersion]
      if { $ret == 0 } {
         set lastVerifyValue [ lindex $listResult 0 ]
         if {$lastVerifyValue > 0} {
            set ::biocore::userId $lastVerifyValue
         }
#     puts "verify.  returning  [ lindex $listResult 0 ]"
         return $lastVerifyValue
      } 

#   puts "verify.  returning  a zero"
      set lastVerifyValue 0
      return $lastVerifyValue
   }

} ; # end of ::biocore::verify

# ----------------------------------------------------------------------

######################
#
# createBiofsDirectory
# 
# Create a Directory in the Biofs
#
# parameters:
#  biofsPath: Path to the parent directory
#  strName: Name of the new directory
#
proc ::biocore::createBiofsDirectory {biofsPath strName} {
   set params(task) "createDir"
   set params(type) "biofs"
   #foobar.. might need to the regsubs to convert {}.  Need to verify
   set params(parameters) [toXML "createDir" "path \"$biofsPath\" dirName \"$strName\""]

   # we are now ready to actually do the URL work
    set strResponse [encodeAndSend post $::biocore::URL \
                             $::biocore::Session $::biocore::Project params]

    set strResponse [string trim $strResponse]

   # is this user valid?
   isValidBiocoreResponse $strResponse listResult iServerVersion

#   if [catch {[ isValidBiocoreResponse $strResponse listResult iServerVersion]} err] {
#      puts "in createbiofsdirectory error"
#      global errorCode
#      error $err createBiofsDirectory $errorCode
#   }
   

} ; # end of ::biocore::createBiofsDirectory



# ----------------------------------  =  --------------------------------------
# -----
# add a chat to the Control Panel
proc ::biocore::saveCPChat {cpchat projectId} {

    set cpparams(type) "chat"
    set cpparams(task) "send"

    # sanitize the chat
    set strChat [$cpchat cget Msg]
    set strChat [string map {\{ \&#123; \} \&#125;} $strChat]
#    regsub -all \{ $strChat {\&#123;} strChat
#    regsub -all \} $strChat {\&#125;} strChat
#    regsub -all \\ $strChat {\\\\} strChat

    #puts "strChat is '$strChat'"
    set parameters "msg {$strChat} type [$cpchat cget Send]"
    #if { [string compare [cpc cget Recip] "0"] != 0 } {}
    if { ![catch { $cpchat cget Recip } ] } {
      #set cpparams(recip) [cpc cget Recip]
       append parameters " priv true recip [$cpchat cget Recip]"
   }

    set cpparams(parameters) [toXML "send" $parameters]

   # we are now ready to actually do the URL work
    set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
			 $projectId  cpparams]

    set strResponse [string trim $strResponse]

   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      # listResult is now a list of the remainder of the response from the
      # server
      #set iSuccess [ lindex $listResult 0 ]

       #set iSuccess $listResult
       # no response is a good thing.  Let's just return zero
       set iSuccess 0
   } 

   return $iSuccess
} ; # end of ::biocore::saveCPChat

# ----------------------------------  =  --------------------------------------

#################
# 
# BioCore_getProjectList
#
# gets a list of all the projects a user is in
# 
# returns an list in the form of [Name1 Id1 Name2 Id2... ]
#
proc ::biocore::getProjectList {} {

    set fsparams(type) "utilities"
    set fsparams(task) "getProjectList"

    set projList ""

    set strResponse [encodeAndSend post $::biocore::URL \
                         $::biocore::Session $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
#    puts "strResponse after is $strResponse"
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       set result $listResult
       #regsub "{" $result "" result
       #regsub "}" $result "" result
       #regsub -all ";" $result "," result
       #set projList [split $result "\n"]
       set numProjects [lindex $result 0]
       set projList [lrange $result 1 end]
       set newList ""
       foreach { proj } $projList {
          set newProj [split $proj ","]
          lappend newList [lindex $newProj 2]
          lappend newList [lindex $newProj 0]
       }

    } 
    
    return $newList
} ; # end of getProjectList

# ----------------------------------------------------------------------
#################
#
# gets a project's name based on its id
#
# parameters:
#   id: Id of the project to get the name of
#
# returns the name of the project
#
proc ::biocore::getProjectName { id } {
    
    set projectList [::biocore::getProjectList]

    set index [lsearch $projectList $id]
    if { $index == -1 } {
       set params(type) "utilities"
       set params(task) "getProjectName"

       set params(parameters) [toXML "getProjectName" "projectId {$id}"]
	
       set strResponse [encodeAndSend get $::biocore::URL \
                             $::biocore::Session $::biocore::Project params]
       set strResponse [string trim $strResponse]
       if {[ isValidBiocoreResponse $strResponse listResult \
                                                    iServerVersion]== 0 } {
	       return [lindex $listResult 0]
       }
    }
    return [lindex $projectList [incr index -1]]
}


# ----------------------------------------------------------------------
#################
#
# gets a user name based on an id.  Values are cached.  foobar.  Need
# to eventually provide a way for the user to clear the cache, and it
# would also be good to have listeners set up so that they can send down
# a message to clear the cache.  
#
# parameters:
#   id: Id of the user we want
#
# returns the user name 
#
proc ::biocore::getUserName { id } {
   variable userNameCache

   if {[info exists userNameCache($id)]} {
      return $userNameCache($id)
   } else {
      set params(type) "utilities"
      set params(task) "getUserName"

      set params(parameters) [toXML "getUserName" "userId {$id}"]
	
      set strResponse [encodeAndSend post $::biocore::URL \
                             $::biocore::Session $::biocore::Project params]
      set strResponse [string trim $strResponse]
      if {[ isValidBiocoreResponse $strResponse listResult \
                                                    iServerVersion]== 0 } {
          set userNameCache($id) [lindex $listResult 0]
	       return [lindex $listResult 0]
      } 
   }
}


# ----------------------------------------------------------------------
#################
#
# gets a list of all the users in the current project
#
# returns an list in the form of [Name1 Id1 Name2 Id2... ]
#
proc ::biocore::getUserList { } {

    set fsparams(parameters) [toXML "getUserList" "projectId $::biocore::Project"]
    set fsparams(type) "utilities"
    set fsparams(task) "getUserList"
    set userList ""

    set strResponse [encodeAndSend get $::biocore::URL \
                           $::biocore::Session $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       set result $listResult
       regsub "{" $result "" result
       regsub "}" $result "" result
       regsub -all ";" $result "," result
       set userList [split $result ,]
    } 

    return $userList
}


proc ::biocore::getUsersLoggedIn { project } {


    #puts "getting users logged in..."
    #puts "::biocore::getUsersLoggedIn: project id = $project"

    set fsparams(parameters) [toXML "getUsersLoggedIn" "projectId $project"]
    set fsparams(type) "utilities"
    set fsparams(task) "getUsersLoggedIn"
    set userList ""

    set strResponse [encodeAndSend post $::biocore::URL \
                           $::biocore::Session $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]

    #puts "strResponse = $strResponse"

    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {

       set result $listResult
       regsub "{" $result "" result
       regsub "}" $result "" result
       regsub -all ";" $result "," result
       set userList [split $result ,]
    } 

    return $userList
}

# ----------------------------------------------------------------------
########################
#
# Gets a list of Notebook entries
#
# parameters:
#  - iType: An integer representing the type of message to get (2 is VMD, etc)
#  - iStart: Start time to get messages from (0 if none)
#  - iEnd: End time to get messages from (0 if none)
#  - iOrder: How to order the entries (1 is by name, 2 is by date, etc)
#  - iUser: Limit messages to those created by this user id (negative if none)
#
# returns: A list of NotebookEntryInfo lists
#
proc ::biocore::getNotebookEntryListFull { iType iStart iEnd iOrder iUser {iProject 0} {limit 0} {xml 0}} {
    
    if { $iProject == 0} {
	set iProject $::biocore::Project
    }

    set nbparams(type) "notebook"
    set nbparams(task) "getNotebookList"
    set nbparams(parameters) [toXML "getNotebookList" "msgType {$iType} start
    {$iStart} end {$iEnd} groupby {$iOrder} user {$iUser} projectId $iProject limit $limit xml $xml"]

    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                               $::biocore::Project nbparams]
    set strResponse [string trim $strResponse]

    set listNotebookEntries ""
   # is this user valid?
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {

       if { $xml } {
           return [join [lrange $listResult 1 end] "\n"]
       }


      # listResult is now a list of the remainder of the response from the
      # server
       set iCurrentLine 0
      # first thing we get back now is the number of notebook entries
      set iNumEntries [lindex $listResult $iCurrentLine]
      incr iCurrentLine

      for {set iCount 0} {$iCount < $iNumEntries} {incr iCount} {
         NotebookEntryInfo nei

         # first we get the ID
         nei configure Id [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # now we have to test to see if this is a 'deleted' message
         if {[nei cget Id] != -1} {
            # get the time
            nei configure Time [lindex $listResult $iCurrentLine]
            incr iCurrentLine

            # get the user
            nei configure User [lindex $listResult $iCurrentLine]
            incr iCurrentLine

            # Next we get the User Id
            nei configure UserId [lindex $listResult $iCurrentLine]
            incr iCurrentLine

            # get the title
            nei configure Title [lindex $listResult $iCurrentLine]
            incr iCurrentLine

            # get the description
            nei configure Description [lindex $listResult $iCurrentLine]
            incr iCurrentLine

            # get the user login name
            nei configure Login [lindex $listResult $iCurrentLine]
            incr iCurrentLine
         } ; # end the if on us not having a deleted message

         # add this notebook entry to the list
         lappend listNotebookEntries [nei toList]
      } ; # end the for loop over the notebook entries
   } 

    return [string trim $listNotebookEntries]
} ; # end of ::biocore::getNotebookEntryListFull


# ----------------------------------------------------------------------
#####################
#
# Gets a Notebook Entry
#
# parameters:
#  - iMsgId: Id of the message to get
#
# returns: a list of the NotebookEntry information
#
proc ::biocore::getNotebookEntry {iMsgId} {
   NotebookEntry ne
   set nbparams(type) "notebook"
   set nbparams(task) "getNotebookMessage"
    set nbparams(parameters) [toXML "getNotebookMessage" "id {$iMsgId}"]

   # we are now ready to actually do the URL work
   set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                               $::biocore::Project  nbparams]
    set strResponse [string trim $strResponse]
   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      # listResult is now a list of the remainder of the response from the
      # server

      # set the line in the listResult that we are currently reading
      set iCurrentLine 0

         # first we get the Type
         ne configure Type [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the Id
         ne configure Id [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the Title
         ne configure Title [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the User
         ne configure User [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the Description
         ne configure Description [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the Time
         ne configure Time [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Next we get the User Id
         ne configure UserId [lindex $listResult $iCurrentLine]
         incr iCurrentLine

         # Lastly we get the actual Text
         ne configure Text [join [lrange $listResult $iCurrentLine end] "\n"]

   } 
   return [ne toList]
} ; # end of ::biocore::getNotebookEntry 

# ----------------------------------------------------------------------
#########################
#
# BioCore_getBioFSFile
#
# save a file from the biofs onto the local filesystem
# 
# parameters:
#  - biofsPath: Biofs path of the file to get
#  - strFileLocation: local path to write the file to
#
proc ::biocore::getBiofsFile  { biofsPath strFileLocation } {

   #set params(id) $biofsID
   #set params(pureText) "true"
    #set params(type) "biofs"
    #set params(task) "downloadFile"
   #set strParamList [encodeURLParams $::biocore::Session $::biocore::Project params]

   #set strFullURL "::biocore::URLsecure/biofs/openfile.do?$strParamList"
   # set strFullURL ::biocore::URLbiofs[eval http::formatQuery $biofsPath]
    set biofsPath [regsub -all " " $biofsPath "%20"]
    set biofsPath [regsub -all "'" $biofsPath "%27"]
    set strFullURL ${::biocore::URL}biofs$biofsPath
    #puts "before biocorehttpcopy"
    ::biocore::biocoreHttpCopy $strFullURL $strFileLocation $::biocore::Session
    #puts "after biocorehttpcopy"
}

# ----------------------------------------------------------------------
#########################
#
# BioCore_saveNotebookEntry
#
# save a notebook entry to the database
# 
# parameters:
#  - ne: a NotebookEntry object with the necessary information
#        for adding the entry
#
# return: the id of the newly added entry, or -2 if there was an error
#
proc ::biocore::saveNotebookEntry {ne} { 

   set nbparams(type) "notebook"
   set nbparams(task) "saveNotebookEntry"
   set ampersand {\&}

   regsub -all \{ [ne cget Title] {\&#123;} title
   regsub -all \} $title {\&#125;} title

   regsub -all \{ [ne cget Description] {\&#123;} desc
   regsub -all \} $desc {\&#125;} desc

   regsub -all \{ [ne cget Text] {\&#123;} text
   regsub -all \} $text {\&#125;} text

    #set parameters "subject {[ne cget Title]} description {[ne cget Description]} data {[ne cget Text]} msgType [ne cget Type] project $::biocore::Project"

    set parameters "subject {$title} description {$desc} data {$text} msgType [ne cget Type]"
   if { [string compare [ne cget Reply] ""] != 0 } {
      #set nbparams(reply) [ne cget Reply]
       append parameters " reply " [ne cget Reply]
   }

   set nbparams(parameters) [toXML "saveNotebookEntry" $parameters] 

   # do we have a file?
   set fileName [ne cget FileUploadName]
   #puts "filename is '$fileName'"
   if { [string equal "" [string trim $fileName]] } {
      # we are now ready to actually do the URL work
      set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                              $::biocore::Project  nbparams]
      set strResponse [string trim $strResponse]
   } else {
      set fid [open "$fileName" r]
      fconfigure $fid -translation binary
      if {[catch {read $fid [file size "$fileName"]} binData]} {
          #puts "Error in saveNotebookEntry: $binData"
          return -3
      }
      close $fid

      set ind [string last "/" "$fileName"]
      incr ind
      set XXXX [string range "$fileName" $ind end]

      #puts " read in [file size $fileName] bytes"
      set strResponse [encodeAndSendFile $::biocore::URL $::biocore::Session \
               $::biocore::Project  nbparams $binData "upload_file" \
                                           "$XXXX"]
      set strResponse [string trim $strResponse]
   }
   set iResult -2
   # is this user valid?
   if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      # listResult is now a list of the remainder of the response from the
      # server
       set iResult [ lindex $listResult 0]
   } 

   return $iResult
} ; # end of ::biocore::saveNotebookEntry

# ----------------------------------------------------------------------
###############
#
# deletes a notebook entry
#
#             iId - the id of the message to delete
#
proc ::biocore::deleteNotebookEntry {iId} {

    set nbparams(type) "notebook"
    set nbparams(parameters) [toXML "deleteNotebookEntry" "id {$iId}"]
    set nbparams(task) "deleteNotebookEntry"
    # we are now ready to actually do the URL work
    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                              $::biocore::Project nbparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       return $listResult
    } 
}


# ----------------------------------------------------------------------
#####################
#
# Gets a biofs listing
#
# parameters:
#  - strPath: Biofs path of the directory to get
#  - iLimit: Limit on how many files to get
#  - suffixes: List of file types to get
#
# returns: A list of BiofsDirectoryEntry objects which list the
#          information for the files and folders in the directory
#
proc ::biocore::getBiofsDirectory {strPath iLimit suffixes} {
   BiofsDirectory bioDir

    set fsparams(type) "biofs"
    set fsparams(task) "getDirectory"

    # sanitize the entries
    regsub -all \{ $strPath {\&#123;} strPath
    regsub -all \} $strPath {\&#125;} strPath

    set params "projectId $::biocore::Project path {$strPath} suffixes {$suffixes}"
    if { $iLimit != 0 } {
       append params " projlimit true"
    }

    set fsparams(parameters) [toXML "getDirectory" $params]

    # we are now ready to actually do the URL work
    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                             $::biocore::Project  fsparams]
    set strResponse [string trim $strResponse]

    #puts "I got\n---\n$strResponse\n---"

    # is this user valid?
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       # listResult is now a list of the remainder of the response from the
       # server
       # set the line in the listResult that we are currently reading
       set iCurrentLine 0

       # first thing we get back now is the name of the directory
       bioDir configure Name [lindex $listResult $iCurrentLine]
       incr iCurrentLine

       # next, we get a number of directory entries
       set iNumEntries [lindex $listResult $iCurrentLine]
       incr iCurrentLine
 
       # make ourselves a list for the results
       set listEnt [list]

       for {set iCount 0} {$iCount < $iNumEntries} {incr iCount} {
          BiofsDirectoryEntry bioDE

          # first we get the type of this entry
          bioDE configure Type [lindex $listResult $iCurrentLine]
          incr iCurrentLine

          # test for whether it is a directory or a file
          if { [bioDE cget Type] == 0 } {
             bioDE scanDir iCurrentLine $listResult
          } else {
             bioDE scanFile iCurrentLine $listResult
          } ; # end the else

          # add this notebook entry to the list
          lappend listEnt [bioDE toList]
       } ; # end the for loop over the notebook entries
  
       bioDir configure Entries $listEnt
   } 

   return [bioDir toList]
} ; # end of ::biocore::getBiofsDirectory 

# When getBiofsDirectory is fixed, this code might work too
# RKB 2006-06-15
#
# proc ::biocore::isBiofsDirectory { biofsPath biofsName } {
#   ::biocore::BiofsDirectory biofsDir

#   if {[catch {eval ::biocore::biofsDir configure \
#                 [::biocore::getBiofsDirectory $biofsPath 0 ""]} errmsg]} {
#     # if we make it in here, we had an error thrown
#     global errorInfo errorCode
#     puts "getBiofsDirectory Error: <$errmsg> <$errorInfo> <$errorCode>"
#   } else {
#     puts "Directory name: '[::biocore::biofsDir cget Name]'"

#     set deList [::biocore::biofsDir cget Entries]
#     set iNumEntries [llength $deList]
#     puts "Number of Dir Entries: '$iNumEntries'   $deList"

#     # now we loop over the entries
#     for {set iCount 0} {$iCount < $iNumEntries} {incr iCount} {
#       ::biocore::BiofsDirectoryEntry bioDE
#       eval ::biocore::bioDE configure [lindex $deList $iCount]

#       puts "Name [::biocore::bioDE cget Name] Type<[::biocore::bioDE cget Type]>"
#       # do we have a directory, or a file?
#       if { [::biocore::bioDE cget Type] == 0 \
#         && "[::biocore::bioDE cget Name]" == "$biofsName" } {
#         puts "Directory exists!"
#         return 1
#       }
#     } ; # end the for loop over the directory entries
#   }

#   # None found, return 0
#   return 0
# }

# ----------------------------------  =  --------------------------------------
# BioCore_putBioFsFile
#
# save a file from the local filesystem into the Biofs
# 
# parameters:
#  - biofsDirPath: Biofs path of the directory in which to place the file
#  - strLocal: Name of the file on the client's machine
#  - strRemote: Name of the file to be put on the server
#
# return: The id of the new file
#
proc ::biocore::putBiofsFile  { biofsDirPath strLocal strRemote } {
    return [::biocore::putBiofsFileSystem $biofsDirPath $strLocal $strRemote 0]
}

# ----------------------------------  =  --------------------------------------
# BioCore_putBioFsFileSystem
#
# save a file from the local filesystem into the Biofs
# 
# parameters:
#  - biofsDirPath: Biofs path of the directory in which to place the file
#  - strLocal: Name of the file on the client's machine
#  - strRemote: Name of the file to be put on the server
#  - bSystem: 1 if this is to be written to the .ServerFiles dir, 0 if not
#
# return: The id of the new file
#
proc ::biocore::putBiofsFileSystem  { biofsDirPath strLocal strRemote bSystem} {
    set iId -1
    # load the file into   $binData   ....
    set fid [open $strLocal r]
    fconfigure $fid -translation binary
    if {[catch {read $fid [file size $strLocal]} binData]} {
       puts "Error in putBiofsFile: $binData"
       return -code error $binData
    }
    close $fid
    set owner -1

    if { !$bSystem } {
       set uparams(type) "utilities"
       set uparams(task) "currentUserId"
       set uparams(params) ""
       set ustrResponse [encodeAndSend post $::biocore::URL \
                            $::biocore::Session $::biocore::Project uparams]
       set strResponse [string trim $ustrResponse]
       if {[ isValidBiocoreResponse $strResponse listResult \
                                                       iServerVersion]== 0 } {
          set owner $listResult

       }
    }

    set params(type) "biofs"
    set params(task) "putBioFsFile"

    # sanitize the entries
    regsub -all \{ $biofsDirPath {\&#123;} biofsDirPath
    regsub -all \} $biofsDirPath {\&#125;} biofsDirPath
    regsub -all \{ $strLocal {\&#123;} strLocal
    regsub -all \} $strLocal {\&#125;} strLocal

    set params(parameters) [toXML "putBioFsFile" "destPath {$biofsDirPath} sourcePath {$strLocal} project $::biocore::Project owner {$owner}"]


    # we are now ready to actually do the URL work

    set strResponse [encodeAndSendFile $::biocore::URL $::biocore::Session \
                 $::biocore::Project  params $binData "upload_file" $strRemote]

    set strResponse [string trim $strResponse]

    # is this user valid?
    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
      # listResult is now a list of the remainder of the response from the
      # server
      set iId $listResult
   }

    return $biofsDirPath

} ; # end of ::biocore::putBiofsFile

# ----------------------------------------------------------------------
########################
#
# Delete a file from the BioFs
#
# parameters:
#  - id: The id of the file to delete
#
proc ::biocore::delBiofsFile { id } {

    set params(type) "biofs"
    set params(task) "deleteBioFsFile"
    set params(parameters) [toXML "deleteBioFsFile" "id {$id} jsessionid $::biocore::Session"]

    set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                                  $::biocore::Project  params]
    set strResponse [string trim $strResponse]

    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {

       puts "File \#$id deleted successfully"
    } 
}

# ----------------------------------------------------------------------
########################
#
# Deletes a directory from the BioFs
#
# parameters:
#  - id: Id of the directory to delete (must be empty)
#
proc ::biocore::delBiofsDirectory { id } {

    set params(type) "biofs"
    set params(task) "deleteBioFsDirectory"
    set params(parameters) [toXML "deleteBioFsDirectory" "id {$id}"]

    set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session \
                                                  $::biocore::Project params]
    set strResponse [string trim $strResponse]

    if {[ isValidBiocoreResponse $strResponse listResult iServerVersion]== 0 } {
       puts "Directory \#$id deleted successfully"
    } 
}

# ----------------------------------------------------------------------
########################
#
# Get types of jobs this user can run
#
# parameters:
#
proc ::biocore::getJobTypes { } {

    set fsparams(parameters) [toXML "getJobTypes" "projectId $::biocore::Project"]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "getJobTypes"
    set jobTypeList {}

    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
       $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseJobTypes $result
    }
    
    return $jobTypeList
}

# ----------------------------------------------------------------------
########################
#
# Get list of accounts that can run this type of job
#
# parameters:
#  - jobType: What type of job the user wants to run
#
proc ::biocore::getAccountsForJob { jobType } {

    set fsparams(parameters) [toXML "getAccountsForJob" \
        "projectId $::biocore::Project jobType {$jobType}" ]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "getAccountsForJob"
    set jobAccountsList {}

    #puts "fsparams is $fsparams(parameters)"
    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
                                               $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    
    #puts "strResponse $strResponse"
    
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseAccountsForJob $result
    }
    
    return $jobAccountsList
}

# ----------------------------------------------------------------------
########################
#
# Get list of accounts that can run this type of job
#
# parameters:
#  - jobType: What type of job the user wants to run
#
proc ::biocore::runJob { jobType accountId projectId jobName \
   jobDesc workDir cmd cmdParams stdout stderr queueName project numProcs \
   cpuTime memory inputFiles outputFiles } {    
    set fsparams(parameters) [toXML "runJob" \
        "jobType {$jobType} \
        accountId {$accountId} \
        projectId {$projectId} \
        jobName {$jobName} \
        jobDesc {$jobDesc} \
        workDir {$workDir} \
        cmd {$cmd} \
        cmdParams {$cmdParams} \
        stdout {$stdout} \
        stderr {$stderr} \
        queueName {$queueName} \
        projectToCharge {$project} \
        numProcs {$numProcs} \
        cpuTime {$cpuTime} \
        memory {$memory} \
        inputFiles { [makeStringFromList $inputFiles] } \
        outputFiles { [makeStringFromList $outputFiles] }" \
    ]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "runJob"

    #puts "fsparams is $fsparams(parameters)"
    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
       $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    
    #puts "strResponse $strResponse"
    
    set jobid {}
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseRunJob $result
    }

    return $jobid
}

# ----------------------------------------------------------------------
########################
#
# Get the status of a particular job
#
# parameters:
#
proc ::biocore::getJobStatus { jobid } {

    set fsparams(parameters) [toXML "getJobStatus" "jobId $jobid" ]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "getJobStatus"
    set status {}

    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
       $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseJobStatus $result
    }
    
    return $status
}

# ----------------------------------------------------------------------
########################
#
# Get the list of queue names for a particular account
#
# parameters:
#
proc ::biocore::getQueuesForAccount { accountid } {

    set fsparams(parameters) [toXML "getQueuesForAccount" \
      "accountId $accountid" ]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "getQueuesForAccount"
    set queueList {}

    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
       $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseQueuesForAcct $result
    }
    
    return $queueList
}


# ----------------------------------------------------------------------
########################
#
# Get the list of required field names for the specified job type
# running on the specified account
#
# parameters:
# accountid: The id of the selected account
# jobtype: The type of job being run
#
proc ::biocore::getRequiredJobParameters { accountid jobtype } {

    set fsparams(parameters) [toXML "getRequiredParameters" \
      "accountId $accountid jobType $jobtype" ]
    set fsparams(type) "jobmanagement"
    set fsparams(task) "getRequiredParameters"
    set paramList {}

    set strResponse [encodeAndSend get $::biocore::URL $::biocore::Session \
       $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if {[ isValidBiocoreResponse $strResponse result iServerVersion]== 0 } {
       _APItax::parse parseRequiredJobParams $result
    }
    
    return $paramList
}


# ----------------------------------------------------------------------
########################
#
#L
#
# creates an XML string from name/value pairs
# 
# parameters:
#  tag: The tag name for the XML entry
#  entries: a list of name, value entries
#
# returns:
#  an XML String representing the name/value pairs

proc ::biocore::toXML { tag entries } {
   
    #puts "converting '$entries'"
    regsub -all {\\} $entries {\&#092;} entries
    set xml "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append xml "<$tag>\n"
    foreach { name value } $entries {
       # character substitutions for valid XML
       regsub -all "\&(?!\#\[0-9\]\[0-9\]\[0-9\])" $value "&amp;" value
       regsub -all {\&#092;} $value {\\} value
       #puts "before gt. value: '$value'"
       regsub -all ">" $value "\\&gt;" value
#       puts "after gt. value: '$value'"
       regsub -all "<" $value "\\&lt;" value
#       puts "after lt. value: '$value'"
#       regsub -all ">" $value "ampersandgt;" value
#       regsub -all "<" $value "ampersandlt;" value
#       regsub -all {\&} $value "ampersand" value
#       regsub -all {\?} $value "questionmark" value
#       regsub -all {\}} $value "ampersand\#123;" value
#       regsub -all {\{} $value "ampersand\#125;" value

       append xml " <$name>\n  $value\n </$name>\n"
    }
    append xml "</$tag>"

    #puts stdout "result after toXML: '$xml'"
    return $xml
}

########################
#
# makeStringFromList
#
# creates a string from a list with "+" signs separating elements,
# real "+" characters escaped as "\+", and "\" escaped as "\\"
#

proc ::biocore::makeStringFromList { list } {
   set retstr ""
   # puts "list is $list"
   
   # escape all the \ chars first, because foreach parses them
   set list [string map { "\\" "\\\\" } [subst -nobackslashes $list] ]
   
   #puts "list is $list"

   foreach item $list {
      # foreach has stripped the \ chars, so escape them again
      set item [string map { "\\" "\\\\" } [subst -nobackslashes $item] ]
      
      # escape all the + chars now, because if we do it earlier, foreach
      # will undo it
      set item [string map { "+" "\\+" } [subst -nobackslashes $item] ]

      #puts "item is [subst -nobackslashes $item]"
      if { $retstr != "" } {
         append retstr "+"
      }
      append retstr [subst -nobackslashes $item]
      #puts "retstr is [subst -nobackslashes $retstr]"
   }
   return $retstr
}

proc ::biocore::rsaEncrypt { c key pq } {
   package require bignum 1.0
   #puts "RSA: [tostr $c] [tostr $key] [tostr $pq]"
   return [::bignum::powm $c $key $pq]
}

proc ::biocore::encryptPass { text pub mod } {
   package require bignum 1.0
   set crypted {}
   set key [::bignum::fromstr $pub]
   set pq [::bignum::fromstr $mod]
   lappend crypted [::bignum::tostr [::biocore::rsaEncrypt [::bignum::fromstr [string length $text]] $key $pq]]
   foreach char [split $text ""] {
       lappend crypted [::bignum::tostr [::biocore::rsaEncrypt [::bignum::fromstr [scan $char %c]] $key $pq]]
   }

   # now we pad it
   for {set i [expr 1 + [string length $text]]} {$i < 20} {incr i} {
       lappend crypted [::bignum::tostr [::biocore::rsaEncrypt [::bignum::fromstr [expr int(rand()*60) + 65]] $key $pq]]
   }

   return $crypted 
}

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
    # Namespace "tax" stands for "Tiny API for XML"
    #
namespace eval _APItax {
   variable parseAccountsForJobBuf
}

proc _APItax::compactws {s} { return [regsub -all -- {\s+} [string trim $s] " "] }

proc _APItax::parse {cmd xml {start docstart}} {
   set xml [string map {\{ \&ob; \} \%cb; \&quot; {\"} \&lt; < \&gt; > \&#039; \'} $xml]
   regsub -all {\&amp;} $xml {\&} xml
   #regsub -all \{ $xml {\{} xml
   #regsub -all \} $xml {\}} xml
   set exp {<(/?)([^\s/>]+)\s*([^/>]*)(/?)>}
   set sub "\}\n$cmd {\\2} \[expr \{{\\1} ne \"\"\}\] \[expr \{{\\4} ne \"\"\}\] \
      \[regsub -all -- \{\\s+|(\\s*=\\s*)\} {\\3} \" \"\] \{"
   regsub -all $exp $xml $sub xml
#   puts "getting ready to eval \"$cmd {$start} 0 0 {} \{ $xml \}\""
   eval "$cmd {$start} 0 0 {} \{ $xml \}"
#   puts "getting ready to eval \"$cmd {$start} 1 0 {} {}\""
   eval "$cmd {$start} 1 0 {} {}"
}


proc _APItax::parseConsentLicense {tag cl selfcl props body} {
#   puts "Starting in ConsentLicense : tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"
   if [string equal $tag {?xml}] {
      return
   }
#   puts "after check "
   switch $tag {
      {docstart} {}
      {forms} {}    
      {Generic Name Value Listing.  Good For Testing} {
         puts "$tag"
         foreach item [array names temp] {
            puts "[string totitle $item]: $temp($item)"
         }

      }
      {consent} {
#         puts "Got v: [compactws $body]"
         if {!$cl} {
            upvar 2 strConsent consent
            regsub -all "\&quot;" $body "\"" consent
#            set consent $body
#      puts "consent: $consent"
         }
      }
      {license} {
#         puts "Got w: [compactws $body]"
         if {!$cl} {
            upvar 2 strLicense license
            regsub -all "\&quot;" $body "\"" license
#            set license $body
#      puts "license: $license"
         }
      }
      default { 
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }

   } 
#   puts stdout "Received '$tag' '$cl' '$selfcl' '$props' '$body'"
#   if [info exists consent ] {
      #puts "consent: $consent"
#      upvar 2 $name var
#         set var $value
#      uplevel 2 set strConsent "$consent"
#   }
#   if [info exists license ] {
      #puts "license: $license"
#      uplevel 2 set strLicense "$license"
#   }
} ; # end of parseConsentLicense
proc _APItax::parseSessionFile {tag cl selfcl props body} {
#   puts "Starting in parseSession File: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"
   if [string equal $tag {?xml}] {
      return
   }
#   puts "after check "
   switch $tag {
      {docstart} {}
      {BioCoRE} {}    
      {Generic Name Value Listing.  Good For Testing} {
         puts "$tag"
         foreach item [array names temp] {
            puts "[string totitle $item]: $temp($item)"
         }

      }
      {version} {
#         puts "Got v: [compactws $body]"
         if {!$cl} {
            set version [compactws $body]
         }
      }
      {written} {
         #puts "Got w: [compactws $body]"
         if {!$cl} {
            set written [compactws $body]
            #uplevel 2 set sessionFileWritten {$written}
            if {[info exists written ]} {
               #puts "setting to '$written'"
               set ::biocore::sessionFileWritten "$written"
            }
         }
      }
      {server} {
# for parsing multiple servers, you want to do something here
#         puts "Got s"
         if {!$cl} {
            set inServer 0
         } else {
            set inServer 1
         }
      }
      {URL} {
#         puts "Got u: [compactws $body]"
         if {!$cl} {
            set url [compactws $body]
         }
      }
      {URLsecure} {
#         puts "Got us: [compactws $body]"
         if {!$cl} {
            set urlsecure [compactws $body]
         }
      }
      {URLnonsecure} {
#         puts "Got un: [compactws $body]"
         if {!$cl} {
            set urlnonsecure [compactws $body]
         }
      }
      {Session} {
#         puts "Got session: [compactws $body]"
         if {!$cl} {
            set sess [compactws $body]
         }
      }
      default { 
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }

   } 
#   puts stdout "Received '$tag' '$cl' '$selfcl' '$props' '$body'"
   if [info exists sess ] {
      uplevel 2 set sSession $sess 
   }
   if [info exists urlnonsecure ] {
      uplevel 2 set urlnonsecure $urlnonsecure 
   }
   if [info exists urlsecure ] {
      uplevel 2 set urlsecure $urlsecure 
   }
#   if [info exists written ] {
#      uplevel 2 set written $written 
#   }
} ; # end of parseSessionFile

proc _APItax::parseProjectList {tag cl selfcl props body} {
#   puts "Starting in parseJobTypes: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists projList] {
      upvar 2 projList projList
   }

   array set temp $props
   switch $tag {
      {docstart} { }
      {vector} { }

      {ProjectInfoMessage} { 
         foreach item [array names temp] {
            switch $item {
               {t} {set t $temp($item)}
               {d} {set d $temp($item)}
               {i} {set i $temp($item)}
               {in} {set in $temp($item)}
               {ci} {set ci $temp($item)}
               {ap} {set ap $temp($item)}
               {pa} {set pa $temp($item)}
               {dt} {set dt $temp($item)}
               {_p} {set p $temp($item)}
               {_time} {set ti $temp($item)}
            }
         }

         # now we store it in the projList
         lappend projList $ti $p $t $d $i $in $ci $ap $pa $dt

      }

      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseJobTypes {tag cl selfcl props body} {
#   puts "Starting in parseJobTypes: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists jobTypeList] {
      upvar 2 jobTypeList jobTypeList
   }
   
   switch $tag {
      {docstart} { }

      {jobtypelist} { 
         if {!$cl} {
            set jobTypeList {}
         } 
#        else { puts "jobtypelist is `$jobTypeList`" }
      }

      {jobtype} { 
         if {!$cl} {
            lappend jobTypeList [compactws $body]
         }
      }
      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseAccountsForJob {tag cl selfcl props body} {
#   puts "Starting in parseAccountsForJob: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"
   variable parseAccountsForJobBuf

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists jobAccountsList] {
      upvar 2 jobAccountsList jobAccountsList
   }
   
   switch $tag {
      {docstart} { }

      {accountlist} { 
         if {!$cl} {
            set jobAccountsList {}
         } 
#        else { puts "jobAccountslist is `$jobAccountsList`" }
      }

      {accountid} { 
         if {!$cl} {
            set parseAccountsForJobBuf(accountid) [compactws $body]
         }
      }
      {accountname} { 
         if {!$cl} {
            set parseAccountsForJobBuf(accountname) [compactws $body]
         }
      }
      {account} {
         if {$cl} {
            #puts "Account specified $parseAccountsForJobBuf(accountid) \
               #$parseAccountsForJobBuf(accountname)"
            lappend jobAccountsList [list $parseAccountsForJobBuf(accountid) \
               "$parseAccountsForJobBuf(accountname)" ]
         }
      }
      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseRunJob {tag cl selfcl props body} {
  #puts "Starting in parseJobTypes: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists jobid] {
      upvar 2 jobid jobid
   }
   
   switch $tag {
      {docstart} { }

      {jobid} { 
         if {!$cl} {
            set jobid [compactws $body]
         } 
      }

      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseJobStatus {tag cl selfcl props body} {
#puts "Starting in parseJobStatus: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists status] {
      upvar 2 status status
   }
   
   switch $tag {
      {docstart} { }

      {jobstatus} { 
         if {!$cl} {
            set status [compactws $body]
         } 
      }

      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseQueuesForAcct {tag cl selfcl props body} {
#   puts "Starting in parseQueuesForAcct: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"
   variable parseQueuesForAcctBuf

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists queueList] {
      upvar 2 queueList queueList
   }
   
   switch $tag {
      {docstart} { }

      {queuelist} { 
         if {!$cl} {
            set queueList {}
         } 
#        else { puts "queueList is `$queueList`" }
      }

      {queuename} { 
         if {!$cl} {
            set parseQueuesForAcctBuf(queuename) [compactws $body]
         }
      }
      {queuedesc} { 
         if {!$cl} {
            set parseQueuesForAcctBuf(queuedesc) [compactws $body]
         }
      }
      {queue} {
         if {$cl} {
            #puts "Queue specified $parseQueueForAcctBuf(queuename) \
               #$parseQueuesForAcctBuf(queuename)"
            lappend queueList [list "$parseQueuesForAcctBuf(queuename)" \
               "$parseQueuesForAcctBuf(queuedesc)" ]
         }
      }
      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

proc _APItax::parseRequiredJobParams {tag cl selfcl props body} {
#   puts "Starting in parseQueuesForAcct: tag: $tag cl: $cl selfcl: $selfcl props: $props body: $body"

   if [string equal $tag {?xml}] {
      return
   }
   
   if [uplevel 2 info exists paramList] {
      upvar 2 paramList paramList
   }
   
   switch $tag {
      {docstart} { }

      {paramlist} { 
         if {!$cl} {
            set paramList {}
         } 
#        else { puts "paramList is `$paramList`" }
      }

      {param} { 
         if {!$cl} {
            lappend paramList [compactws $body]
         }
      }

      default {
         puts stdout "Unknown tag: '$tag' '$cl' '$selfcl' '$props' '$body'" 
      }
   }
}

#################
#
# findFile
#
# finds a file or directory in a given directory
# 
# parameters:
#  directoryId: id of the directory to search
#  filename: name of the file or directory to find
#  
# return:
#  path of the file in the directory or -1 if the file is not found
#

proc ::biocore::findFile { directoryPath filename} {
    catch {
    #get id of .ServerFiles directory for this project
    #set dir [biocore_handle getBiofsDirectory $directoryPath 0]
    set dir [::biocore::getBiofsDirectory $directoryPath 0 ""]
    set fsparams(type) "biofs"
    #FOOBAR: findDirectory and findFile eventually...
    set fsparams(task) "findFile"

    #set params [toXML "findFile" "path {$directoryPath} findName {$filename} projectId [biocore_handle cget Project]"]
    set params [toXML "findFile" "path {$directoryPath} findName {$filename} projectId $::biocore::Project"]
    set fsparams(parameters) $params

   #set strResponse [encodeAndSend get [biocore_handle cget URL] [biocore_handle cget Session] [biocore_handle cget Project] fsparams]
    set strResponse [encodeAndSend post $::biocore::URL $::biocore::Session $::biocore::Project fsparams]
    set strResponse [string trim $strResponse]
    if { [ isValidBiocoreResponse $strResponse listResult iServerVersion ] } {
	return $listResult
    } else {

	return -1
    }
} foo
return $foo
}



