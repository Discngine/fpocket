##
## VMD Movie Generator version 1.4
##
## A script to generate movies through a simple Tk interface
## Supports a number of built-in movie types, can be easily modified
## or customized by the user to make new kinds of movies.
##
## Authors: John E. Stone, Justin Gullingsrud
##          vmd@ks.uiuc.edu
##
## $Id: vmdmovie.tcl,v 1.100 2007/09/17 21:35:04 johns Exp $
##
##
## Home Page
## ---------
##   http://www.ks.uiuc.edu/Research/vmd/plugins/vmdmovie
##
## Instructions:
## -------------
##   Make sure you have the NetPBM 9.23 (or later) package in 
##   your command path if you're using Unix or MacOS X (required)
##
##   Make sure you have ImageMagick in your command path 
##   (required for "animated GIF" movies)
##
##   On Windows, you must install VideoMach 2.7.2 
##     http://www.gromada.com/VideoMach.html
##
##   On SGI, make sure you have "dmconvert" in your command path
##   (required for all SGI-specific compressor modes)
##
##   Make sure you have "ffmpeg" in your command path
##   (optional MPEG-1 video encoder)
##
##   After you have checked that these programs are avaiable,
##   source this script via "source movie.tcl".  Having sourced
##   the script, you can run it with "vmdmovie".
##    
##   Once the script loads up and you get your GUI window, you
##   can select one of the available movie types, configure the
##   working directory, etc.
##
## If you have problems:
## ---------------------
##   Several of the back-end video encoders are very touchy/flaky
##   about the input files they can handle, and many of them have 
##   little or no error handling.  Try changing the size of the 
##   VMD window you're rendering from, or changing the output resolution
##   if the video encoders give you trouble.
##

## Tell Tcl that we're a package and any dependencies we may have
package require exectool 1.2
package provide vmdmovie 1.6

namespace eval ::MovieMaker:: {
  namespace export moviemaker

  # window handles
  variable w                         ;# handle to main window

  # global settings for work directories etc
  variable workdir     "frames"      ;# area for temp and output files
  variable basename    "untitled"    ;# basename for animation files 

  # parameters for the movie generator routines
  variable movietype   "rockandroll" ;# what kind of movie we're making
  variable numframes     1           ;# number of real frames in animation
  variable anglestep     1           ;# change in angle per frame step 
  variable trjstart      0           ;# first trajectory frame in anim
  variable trjend        1           ;# last trajectory frame in anim
  variable trjstep       1           ;# step size for trajectory playback
  variable movieduration 10          ;# desired movie duration
  variable rotateangle   180         ;# how much rotation

  # parameters for renderers and video encoders
  variable framerate    24           ;# playback frame rate of animation
  variable renderer    "snapshot"    ;# which rendering method to use
  variable imgformat   "tga"         ;# which format generated images will use
  variable movieformat "ppmtompeg"   ;# which compress video format to use
  variable bitrate     "8000000"     ;# bitrate for movie encoders

  # post-processing, pre-compression settings and options
  variable presmooth    "0"           ;# smooth images prior to compression
  variable prescale     "0"           ;# post blur enlargement/decimation
  variable scalefactor  "0.5"         ;# post blur enlargement/decimation factor
  ;# default string for  image text labels
  variable prelabel     "0"
  variable labeltext    {Produced by VMD: http://www.ks.uiuc.edu/Research/vmd/}
  variable labelsize    "7"           ;# height of characters above baseline
  variable labelrow     "auto"        ;# baseline pixel row
  variable labelcolor   "gray"        ;# color to use, black, gray, or white
  variable labelbgcolor "transparent" ;# background color or transparent      

  # rendering/compression status information
  variable statusmsg   "Ready      " ;# most recent status message
  variable statusstep  "0"           ;# what step we're on in the process
  variable statussteps "0"           ;# how many steps to complete in process
  variable statusfrac  "0"           ;# fraction of total work to complete
  variable statustotal "0"           ;# total work units to complete for phase
  variable usercancel  "0"           ;# user cancellation of running anim

  # post-compression steps
  variable cleanfiles   "1"           ;# delete intermediate image frames etc

  # place to stuff exception info from catch
  variable foo                       ;# for catching exceptions
  variable viewpoints                ;# used by the rock+roll code

  # variables meant to be used by user-defined movie procs
  variable userframe     "0"         ;# traceable variable
}
  
##
## Main routine
## Create the window and initialize data structures
##
proc ::MovieMaker::moviemaker {} {
  variable w
  variable workdir
  variable movietype
  variable movieformat
  variable statusmsg
  variable statusstep
  variable statussteps
  variable statusfrac
  variable statustotal
  global tcl_platform 
  global env
  if [info exists env(TMPDIR)] {
    set workdir $env(TMPDIR)
  } else {
    switch [vmdinfo arch] { 
      WIN64 -
      WIN32 {
        set workdir "c:/"
      }
      MACOSXX86 -
      MACOSX {
        set workdir "/"
      }
      default {
        set workdir "/tmp"
      } 
    }
  }

  if { [vmdinfo arch] == "WIN32" || [vmdinfo arch] == "WIN64" } {
    set movieformat "videomachmpeg" 
  }
 
  # If already initialized, just turn on
  if { [winfo exists .movie] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".movie"]
  wm title $w "VMD Movie Generator" 
  wm resizable $w 0 0

  ##
  ## make the menu bar
  ## 
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.renderer -text "Renderer" -underline 0 -menu $w.menubar.renderer.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.renderer config -width 9
  menubutton $w.menubar.movietype -text "Movie Settings" -underline 0 -menu $w.menubar.movietype.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.movietype config -width 15
  menubutton $w.menubar.format -text "Format" -underline 0 -menu $w.menubar.format.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.format config -width 7
  menubutton $w.menubar.help -text "Help" -underline 0 -menu $w.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5

  ##
  ## movie type menu
  ##
  menu $w.menubar.movietype.menu -tearoff no
  $w.menubar.movietype.menu add radiobutton -label "Rock and Roll (XY lemniscate)" \
    -value "rockandroll" -variable "::MovieMaker::movietype"  -command ::MovieMaker::durationChanged
  $w.menubar.movietype.menu add radiobutton -label "Rotation about Y axis" \
    -value "rotation" -variable "::MovieMaker::movietype" -command ::MovieMaker::durationChanged
  $w.menubar.movietype.menu add radiobutton -label "Trajectory" \
    -value "trajectory" -variable "::MovieMaker::movietype" -command ::MovieMaker::durationChanged
  $w.menubar.movietype.menu add radiobutton -label "Trajectory Rock" \
    -value "trajectoryrock" -variable "::MovieMaker::movietype" -command ::MovieMaker::durationChanged
  $w.menubar.movietype.menu add radiobutton -label "User Defined Procedure" \
    -value "userdefined" -variable "::MovieMaker::movietype" -command ::MovieMaker::durationChanged



  ##
  ## pre/post-compression processing buttons
  ##
  $w.menubar.movietype.menu add separator 
  switch [vmdinfo arch] {
    WIN64 -
    WIN32 {
      $w.menubar.movietype.menu add checkbutton -label "Delete image files" \
        -variable "::MovieMaker::cleanfiles"
    }
    default {
      $w.menubar.movietype.menu add checkbutton -label "1: Image smoothing" \
        -variable "::MovieMaker::presmooth"
      $w.menubar.movietype.menu add checkbutton -label "2: Half-size rescaling"\
        -variable "::MovieMaker::prescale"
      $w.menubar.movietype.menu add checkbutton -label "3: Text labelling" \
        -variable "::MovieMaker::prelabel"
      $w.menubar.movietype.menu add checkbutton -label "4: Delete image files" \
        -variable "::MovieMaker::cleanfiles"
      $w.menubar.movietype.menu add command -label "Text label settings..." \
        -command "::MovieMaker::labelconfig"
    }
  }

  ##
  ## What renderer to use 
  ## 
  menu $w.menubar.renderer.menu -tearoff no

  # until program paths are fixed, Windows won't work for ray tracers
  switch $tcl_platform(platform) { 
    windows {
      $w.menubar.renderer.menu add radiobutton -label "Snapshot (Screen Capture)" \
        -value "snapshot" -variable "::MovieMaker::renderer" 
      $w.menubar.renderer.menu add radiobutton -label "Tachyon (Ray Tracer)" \
        -value "tachyon" -variable "::MovieMaker::renderer"  
      $w.menubar.renderer.menu add radiobutton -label "POV-Ray (Ray Tracer)" \
        -value "povray" -variable "::MovieMaker::renderer"  
    }

    default {
      $w.menubar.renderer.menu add radiobutton -label "Snapshot (Screen Capture)" \
        -value "snapshot" -variable "::MovieMaker::renderer" 
      $w.menubar.renderer.menu add radiobutton -label "Internal Tachyon (Ray Tracer)" \
        -value "libtachyon" -variable "::MovieMaker::renderer"  
      $w.menubar.renderer.menu add radiobutton -label "Tachyon (Ray Tracer)" \
        -value "tachyon" -variable "::MovieMaker::renderer"  
      $w.menubar.renderer.menu add radiobutton -label "POV-Ray (Ray Tracer)" \
        -value "povray" -variable "::MovieMaker::renderer"  
    }
  }


  ##
  ## compression format menu
  ##
  menu $w.menubar.format.menu -tearoff no
  switch [vmdinfo arch] {
    IRIX6 -
    IRIX6_64 {
      $w.menubar.format.menu add radiobutton -label "Animated GIF (ImageMagick)" \
        -value "imgif" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "JPEG frames (ImageMagick)" \
        -value "jpegframes" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "Targa frames (ImageMagick)" \
        -value "targaframes" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "AVI (SGI dmconvert)" \
        -value "sgiavi" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "MPEG-1 (SGI dmconvert)" \
        -value "sgimpeg1v" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "SGI Movie (SGI dmconvert)" \
        -value "sgimv" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "Quicktime (SGI dmconvert)" \
        -value "sgiqt"  -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "Animated GIF (ImageMagick)" \
        -value "imgif" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "MPEG-1 (ppmtompeg)" \
        -value "ppmtompeg" -variable "::MovieMaker::movieformat"
#      $w.menubar.format.menu add radiobutton -label "MPEG-1 (ffmpeg)" \
#        -value "ffmpeg" -variable "::MovieMaker::movieformat"
    }

    WIN64 -
    WIN32 {
      $w.menubar.format.menu add radiobutton -label "AVI (VideoMach)" \
        -value "videomachavi" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "MPEG-1 (VideoMach)" \
        -value "videomachmpeg" -variable "::MovieMaker::movieformat"
    }

    default {
      $w.menubar.format.menu add radiobutton -label "Animated GIF (ImageMagick)" \
        -value "imgif" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "JPEG frames (ImageMagick)" \
        -value "jpegframes" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "Targa frames (ImageMagick)" \
        -value "targaframes" -variable "::MovieMaker::movieformat"
      $w.menubar.format.menu add radiobutton -label "MPEG-1 (ppmtompeg)" \
        -value "ppmtompeg" -variable "::MovieMaker::movieformat"
#      $w.menubar.format.menu add radiobutton -label "MPEG-1 (ffmpeg)" \
#        -value "ffmpeg" -variable "::MovieMaker::movieformat"
    }
  }
  $w.menubar.format.menu add command -label "Change Compression Settings..." \
    -command "::MovieMaker::movieconfig"

   
  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/vmdmovie"

  pack $w.menubar.renderer $w.menubar.movietype $w.menubar.format -side left 
  pack $w.menubar.help -side right

  frame $w.workdir    ;# frame for data entry areas
  button $w.workdir.button -text "Set working directory:" \
    -command "::MovieMaker::getworkdir"
  label $w.workdir.label -textvariable ::MovieMaker::workdir
  pack $w.workdir.button $w.workdir.label -side left -anchor w

  frame $w.basename   ;# frame for basename of animation files
  label $w.basename.label -text "Name of movie:"
  entry $w.basename.entry -width 15 -relief sunken -bd 2 \
    -textvariable ::MovieMaker::basename
  pack $w.basename.label $w.basename.entry -side left -anchor w


  ##
  ## Rotation angle for rotate movies
  ## 
  frame $w.rotate;# frame for movie parameters
  label $w.rotate.label -text "Rotation angle:"
  entry $w.rotate.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::MovieMaker::rotateangle \
    -validate key -vcmd [list ::MovieMaker::angleChanged %P]
  pack $w.rotate.label $w.rotate.entry -side left -anchor w

  ##
  ## Trajectory step size 
  ##
  frame $w.trjstep;# frame for movie parameters
  label $w.trjstep.label -text "Trajectory step size:"
  entry $w.trjstep.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::MovieMaker::trjstep \
    -validate key -vcmd [list ::MovieMaker::trajstepChanged %P]
  pack $w.trjstep.label $w.trjstep.entry -side left -anchor w

  ##
  ## Movie duration.  Editable only for rotate and rock 'n roll.
  ##
  frame $w.duration
  label $w.duration.label -text "Movie duration (seconds):"
  entry $w.duration.entry -width 4 -relief sunken -bd 2 \
      -textvariable ::MovieMaker::movieduration \
      -validate key -vcmd [list ::MovieMaker::durationChanged %P]
  pack $w.duration.label $w.duration.entry -side left -anchor w

  ## 
  ## Progress area
  ##
  frame $w.status ;# status frame
  frame $w.status.cond
  label $w.status.cond.label -text "  Status: "
  label $w.status.cond.msg   -textvariable ::MovieMaker::statusmsg
  pack  $w.status.cond.label $w.status.cond.msg -side left -anchor w

  frame $w.status.step
  label $w.status.step.label -text "   Stage: "
  label $w.status.step.step  -textvariable ::MovieMaker::statusstep
  label $w.status.step.slash -text " of "
  label $w.status.step.steps -textvariable ::MovieMaker::statussteps
  pack  $w.status.step.label $w.status.step.step $w.status.step.slash \
    $w.status.step.steps -side left -anchor w

  frame $w.status.frac
  label $w.status.frac.label -text "Progress: "
  label $w.status.frac.frac  -textvariable ::MovieMaker::statusfrac
  label $w.status.frac.slash -text " of "
  label $w.status.frac.total -textvariable ::MovieMaker::statustotal
  pack  $w.status.frac.label $w.status.frac.frac $w.status.frac.slash \
    $w.status.frac.total -side left -anchor w
 
  pack $w.status.cond $w.status.step $w.status.frac -side top -anchor w

  frame $w.goabort        ;# frame for Go/Abort buttons
  button $w.goabort.gobutton     -text "Make Movie" -command ::MovieMaker::buildmovie
  button $w.goabort.abortbutton  -text "Abort" -command ::MovieMaker::abort
  pack $w.goabort.gobutton $w.goabort.abortbutton -side left -anchor w

  ## 
  ## pack up the main frame
  ##
  pack $w.workdir $w.basename $w.rotate $w.trjstep $w.duration \
       $w.status \
       $w.goabort \
       -side top -pady 10 -fill x -anchor w
}

proc ::MovieMaker::angleChanged { newval } {
  variable movietype
  variable numframes
  variable anglestep

  if { $movietype != "rotation" } { return 1 }
  if { ![string length $newval] } { return 1 }
  if { ![string is integer $newval] } { return 0 }
  set anglestep [expr double($newval) / $numframes]
  if { $anglestep == 0 } {
    set numframes 1
  } else {
    set numframes [expr round($newval / $anglestep)]
  }
  return 1
}

proc ::MovieMaker::trajstepChanged { newval } {
  variable movietype
  variable numframes
  variable movieduration
  variable framerate

  # XXX trajectory_rock ignore trjstep for no apparent reason, so we only
  # recalculate numframes and movieduration for 'trajectory'
  if { $movietype != "trajectory" } { return 1 }
  if { ![string length $newval] } { return 1 }
  if { ![string is integer $newval] } { return 0 }
  if { $newval < 1 } { return 0 }
  set totframes [molinfo top get numframes]
  set numframes [expr round(double($totframes / $newval))]
  set movieduration [expr round(double($numframes / $framerate))]
  return 1
}

##
## movie duration was edited.  Check if that's allowed, and, if so,
## change any other settings that depend on that variable.
## This proc also gets called when we change movie types; we detect this
## situation when args has zero length.
##
proc ::MovieMaker::durationChanged { args } {
  variable movietype
  variable framerate
  variable numframes
  variable anglestep
  variable rotateangle
  variable movieduration
  variable trjstep

  set oldval $movieduration
  if [llength $args] { 
    set iarg [lindex $args 0] 
    if { [catch { set tmp [expr 1 * $iarg] } ] } {
      set newval $oldval
    } else {
      if { $tmp > 0 } {
        set newval $tmp
      } else {
        set newval 1
      }
    }
  } else {
    set newval $oldval
  }

  switch $movietype {
    rockandroll { 
      if [llength $args] {
        if { ![string length $newval] } { return 1 }
        if { ![string is integer $newval] } { return 0 }
      }
      set numframes [expr $newval * $framerate] 
      return 1
    }
    rotation { 
      if [llength $args] {
        if { ![string length $newval] } { return 1 }
        if { ![string is integer $newval] } { return 0 }
      }
      set numframes [expr $newval * $framerate]
      set anglestep [expr double($rotateangle) / $numframes]
      return 1
    }
    trajectory {
      if [llength $args] {
        if { [expr $oldval] != [expr $newval] } {
          tk_messageBox -type ok -message "Sorry, can't change duration for movie of type $movietype."
          return 0
        }
      }
      if {[llength [molinfo list]] > 0} {
        set totframes [molinfo top get numframes]
        if { ![string length $trjstep] } {
          set numframes $totframes
        } else {
          set numframes [expr round(double($totframes)/$trjstep)]
        }
      } else {
        set numframes 1
      }
      set movieduration [expr {round($numframes / $framerate)}]
    }
    trajectoryrock {
      if [llength $args] {
        if { [expr $oldval] != [expr $newval] } {
          tk_messageBox -type ok -message "Sorry, can't change duration for movie of type $movietype."
          return 0
        }
      }
      if {[llength [molinfo list]] > 0} {
        set numframes [expr ([molinfo top get numframes] * 2)]
      } else {
        set numframes 1
      }
      set movieduration [expr {round($numframes / $framerate)}]
    }
    default {
      set numframes [expr $newval * $framerate]
    }
  }

  # return success by default
  return 1
}

##
## Test for file creation capability for work areas
##
proc ::MovieMaker::testfilesystem {} {
  variable workdir;
 
  # test access permissions on working directory
  if {[file isdirectory $workdir] != 1} {
    return 0; # failure 
  }    
  if {[file readable  $workdir] != 1} {
    return 0; # failure 
  }    
  if {[file writable  $workdir] != 1} {
    return 0; # failure 
  }    

  return 1; # success  
}

proc ::MovieMaker::abort { } {
  variable usercancel 
  set usercancel "1"
}

##
## Window for setting options for the selected renderer 
##
proc ::MovieMaker::renderconfig {} {
  variable sw

  set sw [toplevel ".renderconfig"]
  wm title $sw "Renderer Settings"  
  wm resizable $sw 0 0

  frame $sw.bottom        ;# frame for ok/cancel buttons
  button $sw.bottom.ok     -text "Ok"     -command "after idle destroy $sw"
  pack $sw.bottom.ok -side left -anchor w

  # pack up all of the frames
  pack $sw.bottom \
    -side top -pady 10 -fill x

}

##
## Get directory name
##
proc ::MovieMaker::getworkdir {} {
  variable workdir
  variable newdir

  set newdir [tk_chooseDirectory \
    -title "Choose working directory for temp files" \
    -initialdir $workdir -mustexist true]

  if {[string length $newdir] > 0} {
    set workdir $newdir 
  } 
}


##
## Window for setting options for the text label option
##
proc ::MovieMaker::labelconfig {} {
  variable sw

  set sw [toplevel ".labelconfig"]
  wm title $sw "Text Label Settings"  
  wm resizable $sw 0 0

  frame $sw.textlabel      ;# frame for text label settings

  label $sw.textlabel.textlabel -text "Text Label:"
  entry $sw.textlabel.entry -width 60 -relief sunken -bd 2 \
    -textvariable ::MovieMaker::labeltext

  label $sw.textlabel.size  -text "Text Size:"
  entry $sw.textlabel.labelsize -width 2 -relief sunken -bd 2 \
    -textvariable ::MovieMaker::labelsize

  label $sw.textlabel.label -text "Text Color:"
  radiobutton $sw.textlabel.white -text "White" -value "white" \
    -variable "::MovieMaker::labelcolor"  
  radiobutton $sw.textlabel.gray  -text "Gray"  -value "gray" \
    -variable "::MovieMaker::labelcolor"  
  radiobutton $sw.textlabel.black -text "Black" -value "black" \
    -variable "::MovieMaker::labelcolor"  

  label $sw.textlabel.bglabel -text "Text Background Color:"
  radiobutton $sw.textlabel.bgtrans -text "Transparent" -value "transparent" \
    -variable "::MovieMaker::labelbgcolor"  
  radiobutton $sw.textlabel.bgwhite -text "White" -value "white" \
    -variable "::MovieMaker::labelbgcolor"  
  radiobutton $sw.textlabel.bggray  -text "Gray"  -value "gray" \
    -variable "::MovieMaker::labelbgcolor"  
  radiobutton $sw.textlabel.bgblack -text "Black" -value "black" \
    -variable "::MovieMaker::labelbgcolor"  

  pack $sw.textlabel.textlabel $sw.textlabel.entry \
    $sw.textlabel.size $sw.textlabel.labelsize \
    $sw.textlabel.label \
    $sw.textlabel.white $sw.textlabel.gray $sw.textlabel.black \
    $sw.textlabel.bglabel $sw.textlabel.bgtrans \
    $sw.textlabel.bgwhite $sw.textlabel.bggray $sw.textlabel.bgblack \
    -side top -anchor w

  frame $sw.bottom        ;# frame for ok/cancel buttons
  button $sw.bottom.ok     -text "Ok"     -command "after idle destroy $sw"
  pack $sw.bottom.ok -side left -anchor w

  # pack up all of the frames
  pack $sw.textlabel $sw.bottom \
    -side top -pady 10 -fill x
}

##
## Window for setting options for the selected movie compression format
##
proc ::MovieMaker::movieconfig {} {
  variable sw

  set sw [toplevel ".movieconfig"]
  wm title $sw "Movie Settings"  
  wm resizable $sw 0 0

  # determine what configurable options this compressor has
  frame $sw.animrate      ;# frame for animation frame rate
  label $sw.animrate.label -text "Animation frame rate:"
  radiobutton $sw.animrate.24 -text "24 (Film)" -value "24" \
    -variable "::MovieMaker::framerate" -command ::MovieMaker::durationChanged
  radiobutton $sw.animrate.25 -text "25 (PAL Video)" -value "25" \
    -variable "::MovieMaker::framerate" -command ::MovieMaker::durationChanged
  radiobutton $sw.animrate.30 -text "30 (NTSC Video)" -value "30" \
    -variable "::MovieMaker::framerate" -command ::MovieMaker::durationChanged
  pack $sw.animrate.label $sw.animrate.24 $sw.animrate.25 $sw.animrate.30 \
    -side top -anchor w

  frame $sw.bottom        ;# frame for ok/cancel buttons
  button $sw.bottom.ok     -text "Ok"     -command "after idle destroy $sw"
  pack $sw.bottom.ok -side left -anchor w

  # pack up all of the frames
  pack $sw.animrate $sw.bottom \
    -side top -pady 10 -fill x
}


##
## simple proc that can be called from text mode to generate a movie
##
proc ::MovieMaker::makemovie { wd bname format rendermode duration } {
  variable workdir 
  variable basename
  variable movieduration
  variable movietype
  variable renderer

  set workdir $wd
  set basename $bname
  set movieformat $format
  set renderer $rendermode
  set movieduration $duration
  set movietype "rockandroll"
  durationChanged

  puts "Making movie..."
  buildmovie
}


proc ::MovieMaker::buildmovie {} {
  global tcl_platform
  variable imgformat 
  variable renderer
  variable statusmsg
  variable statusstep
  variable statussteps
  variable statusfrac
  variable statustotal
  variable usercancel
  variable foo
  variable movietype
  variable movieformat
  variable workdir
  variable numframes
  variable presmooth
  variable cleanfiles
  variable prescale
  variable prelabel
  variable scalefactor

  # begin process
  set usercancel "0"
  set statusmsg "Preparing  " 
  set statusstep  "1"
  set statussteps "8"
  update    ;# update the Tk window, callbacks, etc

  # check to make sure the destination filesystem is writable
  # and that output files can be written.
  if {[::MovieMaker::testfilesystem] != 1} {
    puts "Temporary working directory $workdir is not usable."
    puts "Please double check file permissions and available"
    puts "space, and try again, or choose a different directory."
    return;
  }

  # set image format according to platform and renderer
  switch $renderer {
    snapshot {
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set imgformat "bmp"
        }
        default {
          set imgformat "ppm"
        }
      }
    }
    libtachyon {
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set imgformat "bmp"
        }
        default {
          set imgformat "ppm"
        }
      }
    }
    tachyon {
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set imgformat "bmp"
        }
        default {
          set imgformat "ppm"
        }
      }
    }
    povray {
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set imgformat "bmp"
        }
        default {
          set imgformat "ppm"
        }
      }
    }
    default {
      set imgformat "tga"
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Rendering  " 
    set statusstep  "2"
    update    ;# update the Tk window, callbacks, etc

    switch $movietype {
      trajectory {
        genframes_trajectory       ;# Generate frames from VMD 
      }
      trajectoryrock {
        genframes_trajectory_rock  ;# Generate frames from VMD 
      }
      rotation {
        genframes_rotation         ;# Generate frames from VMD 
      }
      rockandroll {
        genframes_rockandroll      ;# Generate frames from VMD 
      }
      userdefined {
        genframes_userdefined      ;# Generate frames from VMD 
      }
      default {
        genframes_rockandroll      ;# Generate frames from VMD 
      }
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Converting  " 
    set statusstep  "3"
    update    ;# update the Tk window, callbacks, etc
    
    switch [vmdinfo arch] { 
      WIN64 -
      WIN32 {
        convertframes bmp 0   ;# Convert frames to Windows BMP format
      } 
      default {
        convertframes ppm 0   ;# Convert frames to PPM format
      }
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Smoothing   " 
    set statusstep  "4"
    update    ;# update the Tk window, callbacks, etc

    if {$presmooth == "1"} {
      smoothframes           ;# Smooth frames prior to compression
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Rescaling   " 
    set statusstep  "5"
    update    ;# update the Tk window, callbacks, etc

    if {$prescale == "1"} {
      rescaleframes          ;# Rescale frames prior to compression
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Text Labels " 
    set statusstep  "6"
    update    ;# update the Tk window, callbacks, etc

    if {$prelabel == "1"} {
      labelframes            ;# Add text labels to frames prior to compression
    }
  }

  if {$usercancel == "0"} {
    set statusmsg "Encoding    " 
    set statusstep  "7"
    update    ;# update the Tk window, callbacks, etc

    switch $movieformat {
      ffmpeg {
        ffmpeg           ;# Convert frame sequence to MPEG-1 video file
      }
      jpegframes {
        jpegframes       ;# Convert frame sequence to JPEG format
      }
      targaframes {
        targaframes      ;# Convert frame sequence to Truevision Targa format
      }
      ppmtompeg {
        ppmtompeg        ;# Convert frame sequence to MPEG-1 video file
      }
      videomachavi {
        videomachavi     ;# Convert frame sequence to MPEG-1 video file
      }
      videomachmpeg {
        videomachmpeg    ;# Convert frame sequence to MPEG-1 video file
      }
      sgiavi {
        sgiavi           ;# Convert frame sequence to AVI video file
      }
      sgimv  {
        sgimv            ;# Convert frame sequence to SGI Movie video file
      }
      sgimpeg1v  {
        sgimpeg1v        ;# Convert frame sequence to SGI MPEG-1 video file
      }
      sgiqt {
        sgiqt            ;# Convert frame sequence to Quicktime video file
      }
      imgif -
      default {
        imgif            ;# Convert frame sequence to animated GIF file
      }
    }
  }

  set statusmsg "Cleaning    " 
  set statusstep  "8"
  if {$cleanfiles == "1"} {
    cleanframes          ;# delete temporary files and single frames
  }
  update    ;# update the Tk window, callbacks, etc

  if {$usercancel == "1"} {
    set statusmsg "Cancelled  "
    puts "Movie generation Cancelled."
  } else {
    set statusmsg "Completed   "
    puts "Movie generation complete."
  }
  update    ;# update the Tk window, callbacks, etc

  ##
  ## reset status area
  ##
  set statusmsg   "Ready      " ;# most recent status message
  set statusstep  "0"           ;# what step we're on in the process
  set statussteps "0"           ;# how many steps to complete in process
  set statusfrac  "0"           ;# fraction of total work to complete
  set statustotal "0"           ;# total work units to complete for phase
  update    ;# update the Tk window, callbacks, etc
}


##
## Support code for the rock and roll style
##
proc ::MovieMaker::roll_save_viewpoint {} {
   variable viewpoints
   if [info exists viewpoints] {unset viewpoints}
   # get the current matricies
   foreach mol [molinfo list] {
      set viewpoints($mol) [molinfo $mol get { center_matrix rotate_matrix scale_matrix global_matrix }]
   }
}

proc ::MovieMaker::roll_restore_viewpoint {} {
   variable viewpoints
   foreach mol [molinfo list] {
      if [info exists viewpoints($mol)] {
         molinfo $mol set { center_matrix rotate_matrix scale_matrix global_matrix } $viewpoints($mol)
      }
   }
}



##
## Generate all of the frames
##
proc ::MovieMaker::genframes_rockandroll {} {
  variable workdir
  variable numframes
  variable anglestep
  variable renderer
  variable basename 
  variable basefilename
  variable statusfrac
  variable statustotal
  variable usercancel

  variable yangle   15.0;
  variable xangle   10.0;
  variable x;
  variable y;
  variable i;

  puts "Generating image frames using renderer: $renderer"
  set statusfrac "0"
  set statustotal $numframes  
  update    ;# update the Tk window, callbacks, etc

  ::MovieMaker::roll_save_viewpoint; # save original viewpoint

  # Loop over all frames and generate images.
  set frame 0
  for {set i 0} {$i<$numframes} {incr i 1} {
    display resetview
    ::MovieMaker::roll_restore_viewpoint; # restore original viewpoint

    # now tweak relative to that view orientation
    set pipcnt [expr 6.283185 * ($i / ($numframes * 1.0))]
    rotate x by [expr $xangle * sin($pipcnt * 2.0)]
    rotate y by [expr $yangle * sin($pipcnt)]

    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      display resetview
      ::MovieMaker::roll_restore_viewpoint; # restore original viewpoint
      return
    }

    set basefilename [format "%s/$basename.%04d" $workdir $frame]
    display update ui
    renderframe $basefilename

    incr frame
    set statusfrac $frame
  }
  display resetview
  ::MovieMaker::roll_restore_viewpoint; # restore original viewpoint
}


##
## Generate all of the frames
##
proc ::MovieMaker::genframes_rotation {} {
  variable workdir
  variable numframes
  variable anglestep
  variable renderer
  variable basename 
  variable basefilename
  variable statusfrac
  variable statustotal
  variable usercancel

  set statusfrac "0"
  set statustotal $numframes  
  update    ;# update the Tk window, callbacks, etc

  # Loop over all frames and generate images.
  set frame 0
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }

    set basefilename [format "%s/$basename.%04d" $workdir $frame]
    display update ui
    renderframe $basefilename

    rotate y by $anglestep

    incr frame
    set statusfrac $frame
  }
}


##
## Generate all of the frames
##
proc ::MovieMaker::genframes_trajectory_rock {} {
  variable workdir
  variable numframes
  variable renderer
  variable basename 
  variable basefilename
  variable statusfrac
  variable statustotal
  variable usercancel
  variable frame
  variable trjframe
  variable rockframes

  puts "Generating image frames using renderer: $renderer"
  set statusfrac "0"
  set statustotal $numframes  
  update    ;# update the Tk window, callbacks, etc

  # Loop over all frames and generate images.
  set frame 0
  set trjframe 0
  # calculate frames to run each way
  set rockframes [expr $numframes / 2]
 
  for {set i 0} {$i < $rockframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }

    set basefilename [format "%s/$basename.%04d" $workdir $frame]

    puts "Trajectory frame: $trjframe"
    animate goto $trjframe

    display update ui
    renderframe $basefilename

    incr frame
    incr trjframe 1
    set statusfrac $frame
  }

  # fix up active frame for reverse direction
  incr trjframe -1
  for {set i 0} {$i < $rockframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }

    set basefilename [format "%s/$basename.%04d" $workdir $frame]

    puts "Trajectory frame: $trjframe"
    animate goto $trjframe

    display update ui
    renderframe $basefilename

    incr frame
    incr trjframe -1
    set statusfrac $frame
  }

  # backpatch total frame count into variables for use
  # when making final movie..  Hopefully this works.
  set numframes $frame
}

##
## Generate all of the frames
##
proc ::MovieMaker::genframes_trajectory {} {
  variable workdir
  variable numframes
  variable trjstep
  variable renderer
  variable basename 
  variable basefilename
  variable statusfrac
  variable statustotal
  variable usercancel
  variable frame
  variable trjframe

  puts "numframes: $numframes"
  puts "Generating image frames using renderer: $renderer"
  set statusfrac "0"
  set statustotal $numframes  
  update    ;# update the Tk window, callbacks, etc

  # Loop over all frames and generate images.
  set frame 0
  set trjframe 0
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }

    set basefilename [format "%s/$basename.%04d" $workdir $frame]

    animate goto $trjframe

    display update ui
    renderframe $basefilename

    incr frame
    incr trjframe $trjstep
    set statusfrac $frame
  }
}


##
## Generate all of the frames, allowing user code to catch callbacks.
##
proc ::MovieMaker::genframes_userdefined {} {
  variable workdir
  variable numframes
  variable renderer
  variable basename 
  variable basefilename
  variable statusfrac
  variable statustotal
  variable usercancel
  variable userframe

  set statusfrac "0"
  set statustotal $numframes  
  update    ;# update the Tk window, callbacks, etc

  # Loop over all frames and generate images.
  set frame 0
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }

    set userframe $frame ;# user-defined proc gets a callback here
    
    set basefilename [format "%s/$basename.%04d" $workdir $frame]
    display update ui
    renderframe $basefilename

    incr frame
    set statusfrac $frame
  }
}


##
## Render one frame using existing settings
##
proc ::MovieMaker::renderframe { basefilename } {
  global env
  variable renderer
  variable rendercmd
  variable scenefilename 
  variable imgfilename
  variable imgformat

  # set platform-specific executable suffix
  set archexe ""
  switch [vmdinfo arch] {
    WIN64 -
    WIN32 { 
      set archexe ".exe"
    }
  }

  set imgfilename $basefilename.$imgformat

  switch $renderer {
    snapshot {
      render snapshot $imgfilename
    } 
    libtachyon {
      render TachyonInternal $imgfilename
    } 
    tachyon {
      set scenefilename $basefilename.dat
      set tachyonexe [format "tachyon%s" $archexe];
      set tachyoncmd \
        [::ExecTool::find -interactive -description "Tachyon Ray Tracer" \
          -path [file join $env(VMDDIR) "tachyon_[vmdinfo arch]$archexe"] $tachyonexe]
      if {$tachyoncmd == {}} {
        puts "Cannot find Tachyon, aborting"
      }
      set rendercmd [ format "\"%s\"" $tachyoncmd]

      switch $imgformat {
        bmp {
          set rendercmd [concat $rendercmd \
            "-mediumshade $scenefilename -format BMP -aasamples 4 -trans_vmd -o $imgfilename"]
        }

        ppm {
          set rendercmd [concat $rendercmd \
            "-mediumshade $scenefilename -format PPM -aasamples 4 -trans_vmd -o $imgfilename"]
        }

        rgb {
          set rendercmd [concat $rendercmd \
            "-mediumshade $scenefilename -format RGB -aasamples 4 -trans_vmd -o $imgfilename"]
        }

        tga {
          set rendercmd [concat $rendercmd \
            "-mediumshade $scenefilename -format Targa -aasamples 4 -trans_vmd -o $imgfilename"]
        }

        default { 
          puts "Image format unsupported, aborting"
        } 
      }
      render Tachyon $scenefilename $rendercmd
    } 
    povray {
      set scenefilename $basefilename.pov
      set povrayexe [format "povray%s" $archexe];
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set povrayexe "pvengine.exe";
          set povraycmd \
            [::ExecTool::find -interactive -path "c:/program files/POV-Ray for Windows v3.6/bin/pvengine.exe" -description "POV-Ray Ray Tracer" \
              $povrayexe]
        }
        default {
          set povraycmd \
            [::ExecTool::find -interactive -description "POV-Ray Ray Tracer" \
              $povrayexe]
        }
      }
      if {$povraycmd == {}} {
        puts "Cannot find POV-Ray, aborting"
      }
      set rendercmd [ format "\"%s\"" $povraycmd]

      # get image resolution so we can pass it into POV command line
      set imagesize [display get size]
      set xsize [lindex $imagesize 0]
      set ysize [lindex $imagesize 1]

      # Add required Windows-specific options to drive the POV-Ray
      # GUI to do what we'd normally do on Unix
      switch [vmdinfo arch] {
        WIN64 -
        WIN32 {
          set rendercmd [concat $rendercmd "/NR /EXIT"]
        }
      }

      switch $imgformat {
        bmp {
          # XXX Assume that "S" will give us BMP format on Windows
          set rendercmd [concat $rendercmd \
            "-I$scenefilename -O$imgfilename +X +A +FS +W$xsize +H$ysize"]
        }
        ppm {
          set rendercmd [concat $rendercmd \
            "-I$scenefilename -O$imgfilename +X +A +FP +W$xsize +H$ysize"]
        }
      }

      render POV3 $scenefilename $rendercmd
    }
    default {
      puts "Unsupported renderer"
    }
  }
}

##
## Convert to AVI or other formats using "videomach"
##
proc ::MovieMaker::videomachavi  {} {
  global env
  variable basename
  variable numframes
  variable framerate
  variable statusfrac
  variable statustotal
  variable mybasefilename 
  variable myoutfilename 
  variable workdir

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting BMP sequence to AVI video format"
  puts "Attempting to convert using VideoMach"

  set mybasefilename [file nativename [file join $workdir "$basename.0000.bmp"]]
  set myoutfilename  [file nativename [file join $workdir "$basename.avi"]]

  file delete -force $myoutfilename

  set vmach [::ExecTool::find -interactive \
    -description "VideoMach audio/video builder and converter" \
    -path "c:/program files/videomach-3.4.1/videomach.exe" videomach.exe]

  # XXX - this hack uses CMD.EXE or COMMAND.COM to call VideoMach, allowing
  # it to handle filenames that contain spaces.
  # We also might want to use a catch around the exec statement.
  if {$vmach != {}} {
    set $vmach [file nativename $vmach]
    set rc [catch {
      exec $env(COMSPEC) << "
        \"$vmach\" /OpenSeq=\"$mybasefilename\" /SaveVideo=\"$myoutfilename\" /Start /Exit
        exit
      "
    }]
  } else {
    error "No VideoMach executable"
  }
}


##
## Convert to MPEG or other formats using "videomach"
##
proc ::MovieMaker::videomachmpeg {} {
  global env
  variable basename
  variable numframes
  variable framerate
  variable statusfrac
  variable statustotal
  variable mybasefilename 
  variable myoutfilename 
  variable workdir

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting BMP sequence to MPEG-1 video format"
  puts "Attempting to convert using VideoMach"

  set mybasefilename [file nativename [file join $workdir "$basename.0000.bmp"]]
  set myoutfilename  [file nativename [file join $workdir "$basename.mpg"]]

  file delete -force $myoutfilename

  set vmach [::ExecTool::find -interactive \
    -description "VideoMach audio/video builder and converter" \
    -path "c:/program files/videomach-3.1.5/videomach.exe" videomach.exe]

  # XXX - this hack uses CMD.EXE or COMMAND.COM to call VideoMach, allowing
  # it to handle filenames that contain spaces.
  # We also might want to use a catch around the exec statement.
  if {$vmach != {}} {
    set $vmach [file nativename $vmach]
    set rc [catch {
      exec $env(COMSPEC) << "
        \"$vmach\" /OpenSeq=\"$mybasefilename\" /SaveVideo=\"$myoutfilename\" /Start /Exit
        exit
      "
    }]
  } else {
    error "No VideoMach executable"
  }
}

##
## Convert to AVI using SGI "dmconvert"
##
proc ::MovieMaker::sgiavi {} {
  variable numframes
  variable framerate
  variable basename
  variable basefilename
  variable workdir
  variable statusfrac
  variable statustotal
  variable mybasefilename 
  variable lastframe
  variable bitrate

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc
  set lastframe [expr $numframes - 1]

  puts "Converting frames to AVI video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

  file delete -force $mybasefilename.avi
  puts "dmconvert -v -f avi -p video,comp=jpeg,brate=$bitrate,rate=$framerate -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 $mybasefilename.####.ppm $mybasefilename.avi"
  ::ExecTool::exec dmconvert -v -f avi -p video,comp=jpeg,brate=$bitrate,rate=$framerate \
   -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 \
   $mybasefilename.####.ppm $mybasefilename.avi >@ stdout
}

##
## Convert to SGI MPEG-1 video file using SGI "dmconvert"
##
proc ::MovieMaker::sgimpeg1v {} {
  variable numframes
  variable framerate
  variable basename
  variable basefilename
  variable workdir
  variable statusfrac
  variable statustotal
  variable lastframe 
  variable bitrate

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc
  set lastframe [expr $numframes - 1]

  puts "Converting frames to SGI MPEG-1 video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

  file delete -force $mybasefilename.mpg
  puts "dmconvert -v -f mpeg1v -p video,rate=$framerate -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 $mybasefilename.####.ppm $mybasefilename.mpg" 
  ::ExecTool::exec dmconvert -v -f mpeg1v -p video,rate=$framerate \
   -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 \
   $mybasefilename.####.ppm $mybasefilename.mpg >@ stdout
}

##
## Convert to SGI Movie using SGI "dmconvert"
##
proc ::MovieMaker::sgimv {} {
  variable numframes
  variable framerate
  variable basename
  variable basefilename
  variable workdir
  variable statusfrac
  variable statustotal
  variable lastframe 
  variable bitrate

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc
  set lastframe [expr $numframes - 1]

  puts "Converting frames to SGI Movie video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

  file delete -force $mybasefilename.mv
  puts "dmconvert -v -f sgimv -p video,comp=jpeg,brate=$bitrate,rate=$framerate -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 $mybasefilename.####.ppm $mybasefilename.mv"
  ::ExecTool::exec dmconvert -v -f sgimv -p video,comp=jpeg,brate=$bitrate,rate=$framerate \
   -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 \
   $mybasefilename.####.ppm $mybasefilename.mv >@ stdout
}

##
## Convert to Quicktime using SGI "dmconvert"
##
proc ::MovieMaker::sgiqt {} {
  variable numframes
  variable framerate
  variable basename
  variable basefilename
  variable workdir
  variable statusfrac
  variable statustotal
  variable lastframe
  variable bitrate

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc
  set lastframe [expr $numframes - 1]

  puts "Converting frames to Quicktime video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

  file delete -force $mybasefilename.mov
  puts "dmconvert -v -f qt -p video,comp=qt_mjpega,brate=$bitrate,rate=$framerate -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 $mybasefilename.####.ppm $mybasefilename.mov"
  ::ExecTool::exec dmconvert -v -f qt -p video,comp=qt_mjpega,brate=$bitrate,rate=$framerate \
   -n $mybasefilename.####.ppm,start=0,end=$lastframe,step=1 \
   $mybasefilename.####.ppm $mybasefilename.mov >@ stdout
}


##
## Convert to MPEG using "sampeg"
##
proc ::MovieMaker::sampeg2 {} {
  variable numframes
  variable framerate
  variable basename
  variable lastframe
  variable basefilename
  variable workdir
  variable statusfrac
  variable statustotal

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting Targa frames to MPEG-1 video format"
  
  set lastframe [expr $numframes - 1]
  set basefilename [format "%s/$basename" $workdir] 

  ::ExecTool::exec sampeg2/sampeg2_0.6.5.bin -1 --targa \
    --firstframe=0 --lastframe=$lastframe \
    $basefilename.%04d.tga $basefilename.mpg >@ stdout
}

##
## Convert to MPEG using "ffmpeg" 
##
proc ::MovieMaker::ffmpeg {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to MPEG-1 video format"
   
  set mybasefilename [format "%s/$basename" $workdir] 
 
  puts "ffmpeg -an -r $framerate -i $mybasefilename.%04d.ppm $mybasefilename.mpg"
  file delete -force $mybasefilename.mpg  
  set foo [catch { ::ExecTool::exec ffmpeg -an -r $framerate -i $mybasefilename.%04d.ppm $mybasefilename.mpg >@ stdout}]
#   ::ExecTool::exec ffmpeg -an -r $framerate -i $mybasefilename.%04d.ppm $mybasefilename.mpg
}


##
## Convert to MPEG using "ppmtompeg" 
##
proc ::MovieMaker::ppmtompeg {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo
  variable parfile
  variable frame
  variable framename
  variable lastframe

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to MPEG-1 video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

  # generate MPEG-1 encoder parameter file
  set parfile [open "$mybasefilename.par" w]
  puts $parfile "PATTERN    IBBPBBPBBPBBPBB"
  puts $parfile "FORCE_ENCODE_LAST_FRAME"          ;# force anim loopable
  puts $parfile "OUTPUT     $mybasefilename.mpg"
  puts $parfile "INPUT_DIR  $workdir"
  puts $parfile "INPUT"

  set lastframe [format "%04d" [expr $numframes - 1]]
  puts $parfile "$basename.*.ppm \[0000-$lastframe\]"

#  for {set frame "0"} {$frame < $numframes} {incr frame} {
#    set framename [format "$basename.%04d.ppm" $frame]
#    puts $parfile "$framename"
#  } 

  puts $parfile "END_INPUT"
  puts $parfile "BASE_FILE_FORMAT PPM"
  puts $parfile "INPUT_CONVERT *"
  puts $parfile "GOP_SIZE 15"
  puts $parfile "SLICES_PER_FRAME 1"
  puts $parfile "PIXEL HALF"
  puts $parfile "RANGE 32"
  puts $parfile "PSEARCH_ALG LOGARITHMIC"
  puts $parfile "BSEARCH_ALG CROSS2"
  puts $parfile "IQSCALE 8"
  puts $parfile "PQSCALE 10"
  puts $parfile "BQSCALE 25"
  puts $parfile "REFERENCE_FRAME DECODED"
  close $parfile

  puts "ppmtompeg $mybasefilename.par"
  file delete -force $mybasefilename.mpg  
  set foo [catch { ::ExecTool::exec ppmtompeg $mybasefilename.par >@ stdout }]
}


##
## Convert to MPEG using "mencodermsmpeg4v2" 
##
proc ::MovieMaker::mencodermsmpeg4v2 {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo
  variable parfile
  variable frame
  variable framename
  variable lastframe

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to Microsoft MPEG-4 Version 2 video format"
  
  set mybasefilename [format "%s/$basename" $workdir] 

#  set optimalbitrate [expr 50 * 25 * 640 * 480 / 256]
#  set lastframe [format "%04d" [expr $numframes - 1]]
#  puts $parfile "$basename.*.ppm \[0000-$lastframe\]"
#  for {set frame "0"} {$frame < $numframes} {incr frame} {
#    set framename [format "$basename.%04d.ppm" $frame]
#    puts $parfile "$framename"
#  } 

  file delete -force $mybasefilename.mpg  

  set foo [catch { ::ExecTool::exec mencoder -ovc lavc -lavcopts vcodec=msmpeg4v2 vbitrate=1500000:mbd=2:keyint=132:vqblur=1.0:cmp=2:subcmp=2:dia=2:mv0:last_pred=3 $basename\*.ppm >@ stdout }]
}


##
## Convert to animated GIF using ImageMajick
##
proc ::MovieMaker::imgif {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo
  variable delay

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to animated GIF format"
  set mybasefilename [format "%s/$basename" $workdir] 
  set delay [format "%5.2f" [expr 100.0 / $framerate]] 
 
  puts "convert -delay $delay -loop 4 $mybasefilename.*.ppm $mybasefilename.gif"
  file delete -force $mybasefilename.gif
  ::ExecTool::exec convert -delay $delay -loop 4 $mybasefilename.*.ppm $mybasefilename.gif >@ stdout

##
## A re-compress using gimp, yields a file 1/8th the size of convert's 
## original output.
##
## gimp --no-interface --no-data --batch \
##   '(let* ( (img (car (file-gif-load 1 "untitled.gif" "untitled.gif")))
##            (drawable (car (gimp-image-active-drawable img))))
##      (gimp-convert-indexed img 0 0 255 0 1 "mypalette")
##      (file-gif-save 1 img drawable
##                     "untitled2.gif" "untitled2.gif" 0 1 100 0)
##      (gimp-quit 0))'
##

}


##
## Convert to JPEG frames
##
proc ::MovieMaker::jpegframes {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo
  variable delay

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to JPEG format"
  convertframes jpg 1

  set mybasefilename [format "%s/$basename" $workdir] 
  set delay [format "%5.2f" [expr 100.0 / $framerate]] 
}


##
## Convert to TrueVision Targa frames
##
proc ::MovieMaker::targaframes {} {
  variable numframes
  variable framerate
  variable basename
  variable workdir
  variable mybasefilename
  variable statusfrac
  variable statustotal
  variable foo
  variable delay

  set statusfrac  "0"
  set statustotal "1"
  update    ;# update the Tk window, callbacks, etc

  puts "Converting frames to Targa format"
  convertframes tga 1

  set mybasefilename [format "%s/$basename" $workdir] 
  set delay [format "%5.2f" [expr 100.0 / $framerate]] 
}


##
## Convert frames to the format required by the selected video encoder
##
proc ::MovieMaker::convertframes { newformat finalformat } {
  variable imgformat
  variable numframes
  variable oldfilename
  variable newfilename
  variable basename
  variable workdir
  variable statusfrac
  variable statustotal
  variable usercancel
  variable foo

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  if { $finalformat } {
    set prefix "final."
    if { $imgformat == $newformat } {
      puts "No frame format conversion necessary, copying to final destination."
      return
    }
  } else {
    set prefix ""
    if { $imgformat == $newformat } {
      puts "No frame format conversion necessary, continuing."
      return
    }
  }


  puts "Converting frames from $imgformat format to $newformat..."

  # Loop over all frames and convert images.
  switch $newformat {
    ppm {
      switch $imgformat {
        tga {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            ::ExecTool::exec tgatoppm $oldfilename > $newfilename
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        rgb {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            set foo [catch {::ExecTool::exec sgitopnm $oldfilename > $newfilename}]
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        ppm {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            file copy -force $oldfilename $newfilename
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        default { 
          puts "Conversion from $imgformat to $newformat unsupported, aborting"
        } 
      }
    }


    jpg {
      switch $imgformat {
        ppm -
        tga -
        rgb {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            ::ExecTool::exec convert -quality 100% $oldfilename JPEG:$newfilename >@ stdout
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        jpg {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            file copy -force $oldfilename $newfilename
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        default { 
          puts "Conversion from $imgformat to $newformat unsupported, aborting"
        } 
      }
    }


    tga {
      switch $imgformat {
        ppm -
        jpg -
        rgb {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            ::ExecTool::exec convert $oldfilename $newfilename >@ stdout
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        tga {
          for {set i 0} {$i < $numframes} {incr i 1} {
            if {$usercancel == "1"} {
              set statusmsg "Cancelled  "
              return
            }
            set oldfilename [format "%s/$basename.%04d.$imgformat" $workdir $i]
            set newfilename [format "%s/$prefix$basename.%04d.$newformat" $workdir $i]
            file delete -force $newfilename
            file copy -force $oldfilename $newfilename
            set statusfrac $i
            update    ;# update the Tk window, callbacks, etc
          }
        }
        default { 
          puts "Conversion from $imgformat to $newformat unsupported, aborting"
        } 
      }
    }

    default {
      puts "Conversion unsupported, aborting"
    }
  }
}


##
## Convert frames to the format required by the selected video encoder
##
proc ::MovieMaker::smoothframes { } {
  variable numframes
  variable oldfilename
  variable newfilename
  variable basename
  variable workdir
  variable statusfrac
  variable statustotal
  variable usercancel

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  puts "Smoothing image frames."

  # Loop over all frames and process images.
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }
    set oldfilename [format "%s/$basename.%04d.ppm" $workdir $i]
    set newfilename [format "%s/orig.$basename.%04d.ppm" $workdir $i]
    file delete -force $newfilename
    file rename -force -- $oldfilename $newfilename
    ::ExecTool::exec pnmsmooth $newfilename > $oldfilename
    file delete -force $newfilename
    set statusfrac $i
    update    ;# update the Tk window, callbacks, etc
  }
}



##
## Convert frames to the format required by the selected video encoder
##
proc ::MovieMaker::rescaleframes { } {
  variable numframes
  variable oldfilename
  variable newfilename
  variable basename
  variable workdir
  variable statusfrac
  variable statustotal
  variable usercancel
  variable scalefactor

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  puts "Rescaling image frames."

  # Loop over all frames and process images.
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }
    set oldfilename [format "%s/$basename.%04d.ppm" $workdir $i]
    set newfilename [format "%s/orig.$basename.%04d.ppm" $workdir $i]
    file delete -force $newfilename
    file rename -force -- $oldfilename $newfilename
    ::ExecTool::exec pnmscale $scalefactor  $newfilename > $oldfilename
    file delete -force $newfilename
    set statusfrac $i
    update    ;# update the Tk window, callbacks, etc
  }
}


##
## Tag frames with copyright or other text, prior to video encoding
##
proc ::MovieMaker::labelframes { } {
  variable numframes
  variable oldfilename
  variable newfilename
  variable basename
  variable workdir
  variable statusfrac
  variable statustotal
  variable usercancel
  variable labeltext
  variable labelcolor
  variable labelbgcolor
  variable labelsize
  variable labelrow
  variable localrow

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  puts "Tagging image frames with user-specified text."

  if {$labelrow == "auto"} {
    set localrow [expr $labelsize + 3];
  } else {
    set localrow $labelrow
  }

  # Loop over all frames and process images.
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }
    set oldfilename [format "%s/$basename.%04d.ppm" $workdir $i]
    set newfilename [format "%s/orig.$basename.%04d.ppm" $workdir $i]
    file delete -force $newfilename
    file rename -force -- $oldfilename $newfilename

    ##
    ## image compositing method for image-based logos etc...
    ## ::ExecTool::exec  pnmcomp -invert -alpha stamp-30.pgm black-30.ppm $newfilename > $oldfilename
    ##

    ::ExecTool::exec ppmlabel -size $labelsize -y $localrow -color $labelcolor -background $labelbgcolor -text $labeltext $newfilename > $oldfilename
    file delete -force $newfilename
    set statusfrac $i
    update    ;# update the Tk window, callbacks, etc
  }
}


##
## Composite frames with copyright or other images, prior to video encoding
##
proc ::MovieMaker::compositeframes { } {
  variable numframes
  variable oldfilename
  variable newfilename
  variable basename
  variable workdir
  variable statusfrac
  variable statustotal
  variable usercancel

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  puts "Compositing image frames with user-specified image."

  # Loop over all frames and process images.
  for {set i 0} {$i < $numframes} {incr i 1} {
    if {$usercancel == "1"} {
      set statusmsg "Cancelled  "
      return
    }
    set oldfilename [format "%s/$basename.%04d.ppm" $workdir $i]
    set newfilename [format "%s/orig.$basename.%04d.ppm" $workdir $i]
    file delete -force $newfilename
    file rename -force -- $oldfilename $newfilename
    
    # image compositing method for image-based logos etc...
    ::ExecTool::exec  pnmcomp -invert -alpha stamp-30.pgm black-30.ppm $newfilename > $oldfilename
    file delete -force $newfilename
    set statusfrac $i
    update    ;# update the Tk window, callbacks, etc
  }
}


##
## Clean up all of the temporary frames once the whole
## animation is done.
##
proc ::MovieMaker::cleanframes {} {
  variable numframes
  variable basename
  variable workdir 
  variable filespec
  variable fileset
  variable statusfrac
  variable statustotal

  set statusfrac  "0"
  set statustotal $numframes
  update    ;# update the Tk window, callbacks, etc

  puts "Cleaning generated data, frames, and encoder parameter files"

  file delete -force $workdir/$basename.par
  for {set i 0} {$i < $numframes} {incr i 1} {
    set filespec [format "$workdir/$basename.%04d" $i]
    set files $filespec 
    file delete -force $files.ppm $files.tga $files.jpg \
               $files.rgb $files.bmp $files.dat
    set statusfrac  $i
    # don't update the GUI on OS X; it's very slow 
    if { [vmdinfo arch] != "MACOSX" && [vmdinfo arch] != "MACOSXX86" } {
      update ;# update the Tk window, callbacks, etc
    }  
  }
}

# This gets called by VMD the first time the menu is opened.
proc vmdmovie_tk_cb {} {
  variable foobar
  # Don't destroy the main window, because we want to register the window
  # with VMD and keep reusing it.  The window gets iconified instead of
  # destroyed when closed for any reason.
  #set foobar [catch {destroy $::MovieMaker::w  }]  ;# destroy any old windows

  ::MovieMaker::moviemaker   ;# start the movie maker
  return $MovieMaker::w
}




