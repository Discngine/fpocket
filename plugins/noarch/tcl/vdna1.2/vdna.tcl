##################################
## vdna:    VERSION 1.2
##  TcBishop, Tulane University
##################################
## $Revision: 1.3 $ 
## $Id: vdna.tcl,v 1.3 2007/03/08 02:39:40 johns Exp $
## 
## Please e-mail improvements or comments to
##  
##  Author: Tom Bishop 
##    bishop@tulane.edu 
##    504-988-6203
##    http://dna.cbr.tulane.edu
## NO CITATION YET
#####################################
###  NOTES:
###  this script reconstructs a 3D curve using
###   the DNA interbasepair helical parameters 
###  Gamma = (shift,slide,rise)
###  Omega = (tilt,roll,twist)
###  Default is 14 nucleosomes 146bp each. 
###  and a 27bp length of straight linker 
##   The linker has twist 35.4deg/bp and rise 3.32A/bp
##   The nucleosomes have bend of 4.3deg/bp 
##      and superhelical pitch 20.6A
##
## IT is an excellent aide for understanding 
##   Woodcock PNAS 1993 or Leuba PNAS 1994
##   or Schiessel's two-angle plots
########################3
## VERSION 1.2
##  introduced options for rand variation in linker length
##  and nucleosome wrapping
######################################
### USAGE:
### requires VMD 1.8.2 or greater from www.ks.uiuc.edu
######################################

## Tell Tcl that we're a package and any dependencies we may have
package provide vdna 1.2


namespace eval ::VDNA:: {
  ##################################
  ### USER DEFINABLE INPUTS
  ##################################
  ### LnkBp:         no. nlinker basepairs
  ### LnkVar:        random variation in bp of nlinker
  ### WrapsPerNuc:   number of times DNA wraps around the core 
  ### WrapsVars:     random variation % of WrapsPerNuc
  ### NNuc:          number of nucleosomes to draw
  ### 3DNA = 1,0 create output for use with 3DNA
  ##################################
  variable LnkBp 
  variable LnkVar
  variable WrapsPerNuc 
  variable WrapsVar 
  variable NNuc 
  variable 3DNA 
  #################################

  ##################################
  ### derived and fixed inputs
  ##################################
  variable Pi 3.14159265358979
  ### Nucleosome Parameters 
  variable NucTwist   #  Twist of DNA in nucleosome
  variable NucKappa   #  Curvature of DNA on nucleosome
  variable NucGamma   #  Pitch of Nucleosome superhelix
  variable NucRise    #  Rise per BP in nucleosome
  ###  Linker parameters
  variable LnkTwist   #  Twist of DNA in Linker
  variable LnkRise    #  Rise per BP in Linker
  ##################################
  ### cross-section of the rod for drawing
  ##################################
  ### ideal (Wdth)^2 + (Dpth)^2 = (20)^2
  ###  and Dpth = 1.7*Wdth
  variable Wdth       #  width of the rod graphic
  variable Dpth       #  depth of the rod graphic
  ##################################
  ### variables for Numerical Integration
  ##################################
  variable NumSteps   # num steps per basepair
  variable deltaS     # 1/numSteps
}

##########################################################
#	PROCEDURE DEFINITIONS
#  1) OMEGA  
#  2) GAMMA
#  3) DRAW_CUBE
#  4) INTEGRATE
#  5) MAKEEND
#  6) RESETVARS
##########################################################

#######################################
###      OMEGA(s, isNuc)
#######################################
### returns (tilt,roll,twist)
### isNuc =1 returns values for the nucleosome core
### isNuc =0 returns values for the linker DNA
proc ::VDNA::Omega { s isNuc } {

  if { $isNuc } {
    variable NucKappa
    variable NucTwist
    set O3   $NucTwist
    set O2 [expr  { $NucKappa * cos($s*$O3)}]
    set O1 [expr  { $NucKappa * sin($s*$O3)}]	

  } else {
    variable LnkTwist
    set O3 $LnkTwist
    set O2 0.0
    set O1 0.0
  }
    return [list $O1 $O2 $O3]
}
### END OF OMEGA

#######################################
#### GAMMA (s, isNuc)
#######################################
### returns (shift,slide,rise)
### isNuc =1 returns values for the nucleosome core
### isNuc =0 returns values for the linker DNA
proc ::VDNA::Gamma { s isNuc} {
    	
  if { $isNuc } { 
    variable NucTwist
    variable NucGamma
    variable NucRise
    set O3  $NucTwist
    set G3  $NucRise
    set G2 [expr { $NucGamma * cos($s*$O3) } ]
    set G1 [expr { $NucGamma * sin($s*$O3) } ]

  } else {
    variable LnkRise
    set G3  $LnkRise
    set G2  0.0
    set G1  0.0
  }

#  puts "Gamma: $G1 $G2 $G3"
  return [list $G1 $G2 $G3]
}
## end of GAMMA

#######################################
### DRAW_CUBE from END1 to END2
#######################################
### End1 and End2 are lists of 3-vectors 
### each End contains the coordinates for 4 points in space
proc ::VDNA::draw_cube { End1 End2 } {
  variable graphmol

#  if {[llength $End1] != 4 } { return "ERROR: draw_cube inproper data format End1"}
#  if {[llength $End2] != 4 } { return "ERROR: draw_cube inproper data format End2"}

  for {set k 0 } { $k <= 3 } { incr k } { 
    set Pt(1,$k) [lindex $End1 $k]
    set Pt(2,$k) [lindex $End2 $k]
  }

  for { set k 0 } { $k <=3 } { incr k } {
    set kp  [expr {($k+1)%4}]
    set kpp [expr {($k+2)%4}]
    set km  [expr {($k-1)%4}]

    # normals for first set of triangles
    set n11  [vecnorm [vecsub $Pt(1,$km)  $Pt(1,$k)]]
    set n12  [vecnorm [vecsub $Pt(2,$kpp) $Pt(2,$kp)]]
    set n13  [vecnorm [vecsub $Pt(1,$kpp) $Pt(1,$kp)]]

    # normals for second set of triangles
    set n21  [vecnorm [vecsub $Pt(1,$km)  $Pt(1,$k)]]
    set n22  [vecnorm [vecsub $Pt(2,$km)  $Pt(2,$k)]]
    set n23  [vecnorm [vecsub $Pt(2,$kpp) $Pt(2,$kp)]]

    # use trinorms so that graphics are smooth
    graphics $graphmol color [expr {$k%2}]
    graphics $graphmol trinorm $Pt(1,$k) $Pt(2,$kp) $Pt(1,$kp) $n11 $n12 $n13 
    graphics $graphmol trinorm $Pt(1,$k) $Pt(2,$k)  $Pt(2,$kp) $n21 $n22 $n23
  }
} 
### end of DRAW_CUBE

#######################################
###  INTEGRATE Rod Centerline and Directors
#######################################
###   3-vectors: Omega,Gamma,R
###   9-vector:  D = d1,d2,d3
proc ::VDNA::Integrate { W G R D } {
	variable NumSteps 
	variable deltaS 

## translation of centerline to next increment 
###    R(s+ds) = R(s) +  D*G*ds
###    D(s+ds) = D(s) +  D*W*ds
## where D is matrix of directors
    set d(1) [lindex $D 0]
    set d(2) [lindex $D 1]
    set d(3) [lindex $D 2]
  for { set N 1 } { $N <= $NumSteps } { incr N } {   
    set G1 [expr {$deltaS * [lindex $G 0]} ]
    set G2 [expr {$deltaS * [lindex $G 1]} ]
    set G3 [expr {$deltaS * [lindex $G 2]} ]
    set vecx [vecscale $G1 $d(1)]
    set vecy [vecscale $G2 $d(2)]
    set vecz [vecscale $G3 $d(3)]
    set rvec [vecadd $vecx $vecy $vecz]
    set R [vecadd $R $rvec]
    
    # rotation of directors to next increment	
    set vecx [vecscale [lindex $W 0] $d(1)]
    set vecy [vecscale [lindex $W 1] $d(2)]
    set vecz [vecscale [lindex $W 2] $d(3)]
    set Om   [vecadd $vecx $vecy $vecz ]
    for { set k 1 } { $k <= 3 } { incr k } {
      set dvec1($k) [veccross $Om $d($k) ]
      set dvec1($k) [vecscale $dvec1($k) $deltaS]
      set dvec2($k) $d($k)
      set d($k) [vecadd $dvec1($k) $dvec2($k)]
      set d($k) [vecnorm $d($k) ]
    }
  }

    #  end of tranformation of centerline and directors 

     return [list  $R $d(1) $d(2) $d(3) ]
}

###  end of Integrate 

#######################################
###  MAKEEND
#######################################
## inputs: R (centerline) and D (directors)
##  return the 4pts for the END
proc ::VDNA::MakeEnd { RandD } { 

   variable Wdth
   variable Dpth

   set R  [lindex $RandD 0]
   set d1 [lindex $RandD 1]
   set d2 [lindex $RandD 2]
   set d3 [lindex $RandD 3]
  
  set sign(0)  1
  set sign(1)  1
  set sign(2) -1
  set sign(3) -1
  set End ""
  for { set j 0 } { $j <= 3} { incr j } {
    set scale [expr $sign($j)/2.0 * $Wdth]
    set vec1  [vecscale $scale $d1 ]
    set scale [expr $sign([expr ($j-1)%4 ])/2.0 * $Dpth]
    set vec2  [vecscale $scale $d2]
    set Pt($j) [vecadd $vec1 $vec2 ]
    set Pt($j) [vecadd $R $Pt($j) ]
    set End [ lappend End1 $Pt($j)]
  }
   return $End
}

#######################################
###      RESETVARS
#######################################
proc ::VDNA::resetvars {} {
  variable Pi 3.14159265358979
  variable LnkBp 27.0
  variable LnkVar 0.0
  variable WrapsPerNuc 1.75
  variable WrapsVar  00
  variable NNuc 14.0
  variable 3DNA 0
  variable Wdth 5.0
  variable Dpth 17.2
  variable NucTwist    [expr {14.0 * 2.0 * $Pi / 146.0 }]
  variable NucKappa    [expr {1.75 * 2.0 * $Pi / 146.0 }]
  variable NucGamma  [expr {-20.6 * 1.75   / 146.0}]
  variable NucRise  3.32 
  variable LnkTwist [expr {35.4 *  $Pi / 180}]
  variable LnkRise  [expr 3.32 ]
  variable NumSteps 10
  variable deltaS 0.1
}

#########################
### INITIALIZE MAIN  LOOP
#########################

proc ::VDNA::vdna {} {
  variable Pi 
  variable LnkBp 
  variable LnkVar
  variable LnkTwist
  variable WrapsPerNuc 
  variable WrapsVar
  variable NNuc 
  variable NucComplete
  variable 3DNA 
  variable graphmol

  ### initialize the graphics
  mol delete [molinfo top]
  mol new
  set graphmol [molinfo top]

  ### WARNGING if DELTA S is too large
  ### the numerical integration does not converge
  ### but graphics will still be produced
  ###  deltaS of 0.1 is sufficient to capture the 
  ###  the curvature of a nucleosome 
  ###   
  puts "STARTING VDNA"
  ##################################
  ##### orientation of first basepair
  ##################################
  set R { 0.0 0.0 0.0 }   
  set d1 { 1.0 0.0 0.0 }  
  set d2 { 0.0 1.0 0.0 }  
  set d3 { 0.0 0.0 1.0 }  
  set D [list $d1 $d2 $d3 ]
  set RandD [list $R $d1 $d2 $d3 ]

  set End1 [MakeEnd $RandD ]

  puts "Completed initialization"
  
  #########################
  ###  MAIN  LOOP
  #########################
  ### there are three nested loops
  ###   For (n = 1;NNucs;n++)
  ###     For (s =0;NucBp;s++)
  ###        draw nucleosomes
  ###     End
  ###     For (s =0;LnkBp+Rand*LnkVar;s++)
  ###         draw linkers
  ###     End
  ###   End
  ################################

  display update off
  puts "Drawing $NNuc nucleosomes "
  set NucBp  [expr 146.0 * $WrapsPerNuc / 1.75 ]
  puts " $NucBp bp per  nucleosome:  Wrapping: $WrapsPerNuc "
  puts " Wrapping Variation by $WrapsVar percent "
  puts " $LnkBp bp Linker Length :   \
Linker Twist: [expr $LnkTwist* $LnkBp /(2*$Pi)] turns"
  puts " $LnkVar bp Linker Random Variation  "

  for { set iNuc 1 } { $iNuc <= $NNuc } { incr iNuc } {
   puts "Calculating Nucleosome no. $iNuc of $NNuc"
################
### Nucleosome LOOP
################
   set s 0 
   set NucCenter { 0.0 0.0 0.0 }
   set Entry  $R
   set TEntry  [lindex $D 2]
   set NucLoop [ expr 146.0 * $WrapsPerNuc*(1.0 + $WrapsVar*rand()/100.0 )/ 1.75]
   puts " Nucleosome Length in bp: $NucLoop "
   while {$s < $NucLoop} { 
    set isNuc 1 
    set sp [expr { $s +1 } ]

    set Om3  [ Omega $sp $isNuc ] 
    set Ga3  [ Gamma $sp $isNuc ]

    set RandD [ Integrate $Om3 $Ga3 $R $D ] 
    set R [lindex $RandD 0]
    set D [lrange $RandD 1 end]

    set NucCenter [vecadd $NucCenter $R ]
   
    set End2  [MakeEnd $RandD ]
    draw_cube $End1 $End2

 ## set up for next iteration
    set End1 $End2
    set s $sp
 }

## calculate/draw for each nucleosome  
  set Exit $R
  set TExit  [lindex $D 2]
  set NucCenter [vecscale [expr 1.0/$NucBp ] $NucCenter  ]
  graphics $graphmol color [expr {int($iNuc)%7 }]
  graphics $graphmol sphere $NucCenter radius 40 resolution 20
  set Dyad [vecscale 0.5 [vecadd $Entry $Exit]]
  graphics $graphmol color [expr {int($iNuc)%7 } ]
  graphics $graphmol sphere $Dyad radius 10 resolution 10
  set Angle [expr acos ( [vecdot $TEntry $TExit ] \
         / ([veclength $TEntry] * [veclength $TExit]) ) ] 
  puts "Entry $Entry: Exit $Exit "
  puts "Entry-Exit Angle: $Angle [expr $Angle*180/$Pi ] "

################
### LINKER LOOP
################
  set s 0
  set LnkLoop [ expr rand() * $LnkVar + $LnkBp ]
  puts "Size of Linker $LnkLoop"
  while { $s < $LnkLoop } { 
    set isNuc  0
    set sp [expr { $s +1 } ]
    set Om3  [ Omega $sp $isNuc ] 
    set Ga3  [ Gamma $sp $isNuc ]

   
   set RandD [ Integrate $Om3 $Ga3 $R $D ] 
   set R [lindex $RandD 0]
   set D [lrange $RandD 1 end]
    
      set End2 [MakeEnd $RandD ]
  
      draw_cube $End1 $End2

      ## set up for next iteration
      set End1 $End2
      set s $sp
  }
  set NucComplete $iNuc 
 }
  display projection orthographic
  display update on
  display resetview

}

proc ::VDNA::vdnatk {} {
  variable Pi
  variable LnkBp 
  variable LnkVar
  variable WrapsPerNuc 
  variable WrapsVar 
  variable NNuc 
  variable NucComplete 
  variable 3DNA 
  variable Wdth 
  variable Dpth 
  variable NucTwist
  variable NucKappa
  variable NucGamma
  variable NucRise 
  variable LnkTwist
  variable LnkRise 
  variable NumSteps

  resetvars

 # If already initialized, just turn on
  if { [winfo exists .vdnatk] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".vdnatk"]
  wm title $w "vdna Tool Kit" 
  wm resizable $w 0 0

  ##
  ## make the menu bar
  ##
  frame $w.menubar -relief raised -bd 2 ;# frame for menubar
  pack $w.menubar -padx 1 -fill x

  menubutton $w.menubar.help -text "Help" -underline 0 -menu $w.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.help config -width 5

  ##
  ## help menu
  ##
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/vdna"

  pack $w.menubar.help -side right

  ##
  ## Number of Nucleosomes to generate
  ##
  frame $w.numnucs ;#  number of nucleosomes
  label $w.numnucs.label -text "Number of Nucleosomes:"
  entry $w.numnucs.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::VDNA::NNuc
  pack $w.numnucs.label $w.numnucs.entry -side left -anchor w


  ##
  ## Wrapping  around the Core and Wrapping Variation
  ##
  frame $w.wrapspernuc ;#  Wrapping
  label $w.wrapspernuc.label -text "Wraps around Core :"
  entry $w.wrapspernuc.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::VDNA::WrapsPerNuc
  pack $w.wrapspernuc.label $w.wrapspernuc.entry -side left -anchor w

  frame $w.wrapsvar ;#  Wrapping Variation
  label $w.wrapsvar.label -text "Wrapping Variation(%):"
  entry $w.wrapsvar.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::VDNA::WrapsVar
  pack $w.wrapsvar.label $w.wrapsvar.entry -side left -anchor w
  ##
  ## Linker Length and Variation
  ##
  frame $w.lnklngth;#  Length of Linker in Bp
  label $w.lnklngth.label -text "Linker Length (bp):"
  entry $w.lnklngth.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::VDNA::LnkBp
  pack $w.lnklngth.label $w.lnklngth.entry -side left -anchor w

  frame $w.lnkvar;#  Variation of Linker in Bp
  label $w.lnkvar.label -text "Linker Variation(bp):"
  entry $w.lnkvar.entry -width 4 -relief sunken -bd 2 \
    -textvariable ::VDNA::LnkVar
  pack $w.lnkvar.label $w.lnkvar.entry -side left -anchor w
  ##
  ##  Go and Reset buttons
  ##
  frame $w.goreset        ;# frame for Go buttons
  button $w.goreset.gobutton     -text "Draw It" -command ::VDNA::vdna
  button $w.goreset.resetbutton  -text "Reset All" -command ::VDNA::resetvars

  pack $w.goreset.gobutton $w.goreset.resetbutton  \
   -side left -anchor w

  ##
  ## Progress area
  ##

  frame $w.status
  label $w.status.label -text " Nucleosome: "
  label $w.status.step  -textvariable ::VDNA::NucComplete
  label $w.status.slash -text " of "
  label $w.status.steps -textvariable ::VDNA::NNuc
  pack  $w.status.label $w.status.step $w.status.slash \
    $w.status.steps -side left -anchor w

  ##
  ## pack up the main frame
  ##
  pack $w.numnucs $w.lnklngth $w.lnkvar $w.wrapspernuc $w.wrapsvar\
       $w.status \
       $w.goreset \
       -side top -pady 10 -fill x -anchor w
}

# This gets called by VMD the first time the menu is opened.
proc vdna_tk_cb {} {
  ::VDNA::vdnatk
  return $VDNA::w
}



