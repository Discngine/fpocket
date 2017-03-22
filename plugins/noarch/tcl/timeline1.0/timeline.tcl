#timeline.tcl  -- VMD script to list/select 2D trajectory info
# of a protein molecule
#
# Copyright (c) 2002 The Board of Trustees of the University of Illinois
#
# Barry Isralewitz  barryi@ks.uiuc.edu    
# vmd@ks.uiuc.edu
#
# $Id: timeline.tcl,v 1.30 2006/09/12 08:07:00 johns Exp $
#

package provide timeline 1.0

proc timeline {} {
  return [::timeline::startTimeline]
}

#######################
#create the namespace
#######################
namespace eval ::timeline {
    variable clicked "-1"
    variable oldmin "0.0"
    variable oldmax "2.0"
    variable lastcalc "0" ; # last calculation, 0=clear, 1=SecStr, 2=x-pos, 3=Phi, 4=delta-Psi, 5=Res-RMSD
}


####################
#define the procs
####################
proc ::timeline::recalc {} {
  variable lastcalc

  switch $lastcalc {
  0   { clearData; showall 1}
  1   { calcDataStruct; showall 1 }
  2   { calcDataX; showall 1 }
  3   { calcDataPhi; showall 1 }
  4   { calcDataDeltaPsi; showall 1 }
  5   { ::rmsdtool ; showall 1 }
  }
}

proc ::timeline::canvasScrollY {args} { 
  variable w

  eval $w.can yview $args
  eval $w.vertScale yview $args 
}     
proc ::timeline::canvasScrollX {args} { 
  variable w

  eval $w.can xview $args
  eval $w.horzScale xview $args 
  
  return
}


proc ::timeline::lookupCode {resname} {
  variable codes

  set result ""
  if {[catch { set result $codes($resname) } ]} {
    set result $resname
  } else {
    set result " $result "
  }
  return $result
}

proc ::timeline::stopZoomSeq {} {
  menu timeline off
}

proc ::timeline::chooseColor {field intensity} {
  variable dataName
  set field_color_type 4 
  #hack to sefault to struct field type coloring
  if {$dataName($field) != "struct"} {
    if {$intensity < 0} {set intensity 0}
    if {$intensity > 255} {set intensity 255}
    set intensity [expr int($intensity)]
    #set field_color_type $field 
    #check color mapping
    set field_color_type 3 
  }
  #super hacky here
  switch -exact $field_color_type {         
    #temporaily diable so greyscale color  only
    3333 {   
      set red $intensity
      set green [expr 255 - $intensity]
      set blue 150 
    }
    4 {
      #the field_color_type hack sends all structs to here 
      if { [catch {
        switch $intensity {
          
######
## CMM 08/28/06 mmccallum@pacific.edu
##
# modify the colors displayed in order to better match what shows up in the
# "structure" representation.  Please note that I have set 3_{10} 
# helices to be blue, to provide more contrast between the purple (alpha)
# and default mauve/pinkish for 3_{10} helices from the "structure" rep
####
#  This gives blue = 3_{10}, purple = alpha, red = pi helix
###################################################
          B {set red 180; set green 180; set blue 0}
          C {set red 255; set green 255; set blue 255}
          E {set red 255; set green 255; set blue 100}
          T {set red 70; set green 150; set blue 150}
          # G = 3_{10}
          G {set red 20; set green 20; set blue 255}
          # H = alpha;  this was fine-tuned a bit to match better.
          H {set red 235; set green 130; set blue 235}
          I {set red 225; set green 20; set blue 20}
          default {set red 100; set green 100; set blue 100}
        }
        
      } ] 
         } { #badly formatted file, intensity may be a number
        set red 0; set green 0; set blue 0 
      }
    }
    default {
      #set red [expr 200 - int (200.0 * ($intensity / 255.0) )]
      #set green $red
      #set red 140; set blue 90; set green 90;
      set red $intensity
      set green $intensity
      set blue $intensity
    }
  }
  
  #convert red blue green 0 - 255 to hex
  set hexred     [format "%02x" $red]
  set hexgreen   [format "%02x" $green]
  set hexblue    [format "%02x" $blue]
  set hexcols [list $hexred $hexgreen $hexblue]

  return $hexcols
}


proc ::timeline::redraw {name func op} {
  
  variable x1 
  variable y1 
  variable so
  variable w 
  variable monoFont
  variable xcanwindowmax 
  variable ycanwindowmax 
  variable xcanmax 
  variable ycanmax
  variable ybox 
  variable xsize 
  variable ysize 
  variable resnamelist 
  variable structlist 
  variable betalist 
  variable sel 
  variable canvasnew 
  variable scalex 
  variable scaley 
  variable dataVal 
  variable dataValNum 
  variable dataName 
  variable dataNameLast 
  variable ytopmargin 
  variable ybottommargin 
  variable vertTextSkip   
  variable xcolbond_rad 
  variable bond_res 
  variable rep 
  variable xcol 
  variable vertTextRight
  variable vertHighLeft
  variable vertHighRight
  variable amino_code_toggle 
  variable dataWidth 
  variable dataMargin 
  variable firstData 
  variable dataMin 
  variable dataMax 
  variable xPosScaleVal
  variable usableMolLoaded
  variable rectCreated
  variable prevScalex
  variable prevScaley
  variable numFrames
  

  if { ($usableMolLoaded) && ($dataValNum >=0 ) } {
    set ysize [expr $ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValNum + 1) )]  

    set xsize [expr  $xcol($firstData) +  ($scalex *  $dataWidth * (2 + $numFrames) ) ]

    set ycanmax(data) $ysize
    set xcanmax(data) $xsize

    if {$ycanmax(data) < $ycanwindowmax} {
      set ycanmax(data) $ycanwindowmax
    }


    if {$xcanmax(data) < $xcanwindowmax} {
      set xcanmax(data) $xcanwindowmax
    }

    $w.can configure -scrollregion "0 0 $xcanmax(data) $ycanmax(data)"
    $w.vertScale configure -scrollregion "0 0 $xcanmax(vert) $ycanmax(data)"
    $w.horzScale configure -scrollregion "0 0 $xcanmax(data) $ycanmax(horz)"
    drawVertScale
    drawHorzScale
    
    set fieldLast  $dataNameLast
    #puts "fieldLast is $dataNameLast"
    #temporary, until put multi-cols in
    


    #draw data on can
    #loop over all data fields

    if {! $rectCreated} {
      #this until separate data and scale highlighting
      $w.vertScale delete yScalable
      $w.can delete dataScalable
      #puts "drawing rects, scalex is $scalex"
      #hack here -- for now skip B-field stuff, so minimal stuff drawn
      puts "seeting min/max, firstData= $firstData" 
      for {set field [expr $firstData + 1]} {$field <= $fieldLast} {incr field} {
        
        
        set xPosFieldLeft [expr int  ( $xcol($firstData) + ($scalex * $dataWidth * ($field - $firstData)  ) ) ]
        set xPosFieldRight [expr int ( $xcol($firstData) + ($scalex * $dataWidth * ($field - $firstData + 1 - $dataMargin)  ) ) ]
        
        #now draw data rectangles
        #puts "drawing field $field at xPosField $xPosField" 
        set y 0.0
        
        set intensity 0
        
        for {set i 0} {$i<=$dataValNum} {incr i} { 
          set val $dataVal($field,$i)
          if {$val != "null"} {
            #calculate color and create rectange
            
            set ypos [expr $ytopmargin + ($scaley * $y)]
            
            #should Prescan  to find range of values!   
            #this should be some per-request-method range / also allow this to be adjusted
            
            #set intensity except if field 4 (indexed struct)
            #puts "field = $field, dataName($field) = $dataName($field),i= $i" 
            if {$dataName($field) != "struct"} {
              ##if { ( ($field != 4)  ) } open brace here 
              set range [expr $dataMax($field) - $dataMin($field)]
              if { ($range > 0)  && ([string is double $val] )} {
                set intensity  [expr int (255 * ( ($val - $dataMin($field) ) / $range)) ]
              }
              
              
              
              set hexcols [chooseColor $field $intensity]
            } else {
              #horrifyingly, sends string for data, tcl is typeless
              set hexcols [chooseColor $field $val ]
            }
            foreach {hexred hexgreen hexblue} $hexcols {} 

            
            #draw data rectangle
            $w.can create rectangle  [expr $xPosFieldLeft] [expr $ypos ] [expr $xPosFieldRight]  [expr $ypos + ($scaley * $ybox)]  -fill "\#${hexred}${hexgreen}${hexblue}" -outline "" -tags dataScalable
          }
          
          set y [expr $y + $ybox]
        }
      } 

      drawVertHighlight 
    }  else {

      #$w.can scale dataRect $xcol($firstdata) $ytopmargin 1 $scaley
      #$w.can scale dataScalable $xcol($firstData) [expr $ytopmargin] 1 [expr $scaley / $prevScaley ]

      $w.can scale dataScalable $xcol($firstData) [expr $ytopmargin] [expr $scalex / $prevScalex]  [expr $scaley / $prevScaley ]
      #now for datarect
      $w.vertScale scale yScalable 0 [expr $ytopmargin] 1  [expr $scaley / $prevScaley ]

    } 
    
    set rectCreated 1
    set prevScaley $scaley
    set prevScalex $scalex
  }

  return
}



proc ::timeline::makecanvas {} {

  variable xcanmax 
  variable ycanmax
  variable w
  variable xsize
  variable ysize 
  variable xcanwindowmax 
  variable ycanwindowmax
  variable horzScaleHeight
  variable vertScaleWidth 
  set xcanmax(data) $xsize 
  set ycanmax(data) $ysize
  
  
  #make main canvas




  
  canvas $w.spacer1 -width [expr $vertScaleWidth+20] -height [expr $horzScaleHeight + 40] -bg #C0C0E0
  canvas $w.spacer2 -width [expr $vertScaleWidth+20] -height [expr $horzScaleHeight + 40] -bg #C0C0E0
  canvas $w.can -width [expr $xcanwindowmax] -height $ycanwindowmax -bg #E9E9D9 -xscrollcommand "$w.xs set" -yscrollcommand "$w.ys set" -scrollregion  "0 0 $xcanmax(data) $ycanmax(data)" 
  canvas $w.vertScale -width $vertScaleWidth -height $ycanwindowmax -bg #C0D0C0 -yscrollcommand "$w.ys set" -scrollregion "0 0 $vertScaleWidth $ycanmax(data)" 

  canvas $w.horzScale -width $xcanwindowmax -height  $horzScaleHeight  -scrollregion "0 0 $xcanmax(data) $horzScaleHeight" -bg #A9A9A9 -xscrollcommand "$w.xs set"
  #pack the horizontal (x) scrollbar
  pack $w.spacer1 -in $w.cfr -side left  -anchor e  
  pack $w.spacer2 -in $w.cfr -side bottom -anchor s  
  pack $w.can  -in $w.cfr -side left -anchor sw 
  #vertical scale/labels
  place $w.vertScale -in $w.can -relheight 1.0 -relx 0.0 -rely 0.5 -bordermode outside -anchor e
  #now place the vertical (y) scrollbar
  place $w.ys -in $w.vertScale -relheight 1.0 -relx 0.0 -rely 0.5 -bordermode outside -anchor e
  # horizontal scale/labels
  place $w.horzScale -in $w.can -relwidth 1.0 -relx 0.5 -rely 1.0 -bordermode outside -anchor n
  #now place the horizontal (x) scrollbar
  place $w.xs -in $w.horzScale -relwidth 1.0 -relx 0.5 -rely 1.0 -bordermode outside -anchor n
  # may need to specify B1-presses shift/nonshift separately...
  bind $w.can <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 data}]
  bind $w.can <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 data}]
  bind $w.can <ButtonPress-2>  [namespace code {timeBarJump %x %y 0 data}]
  bind $w.can <B1-Motion>  [namespace code {keepMovingMarquee %x %y data}]
  bind $w.can <B2-Motion>  [namespace code {timeBarJump %x %y 0 data}]
  bind $w.can <ButtonRelease-1> [namespace code {letGoMarquee %x %y data}]

  bind $w.vertScale <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 vert}]
  bind $w.vertScale <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 vert}]
  bind $w.vertScale <ButtonPress-2>  [namespace code {timeBarJump %x %y 0 vert}]
  bind $w.vertScale <B1-Motion>  [namespace code {keepMovingMarquee %x %y vert}]
  bind $w.vertScale <B2-Motion>  [namespace code {timeBarJump %x %y 0 vert}]
  bind $w.vertScale <ButtonRelease-1> [namespace code {letGoMarquee %x %y vert}]

  bind $w.horzScale <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 horz}]
  bind $w.horzScale <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 horz}]
  bind $w.horzScale <ButtonPress-2>  [namespace code {timeBarJump %x %y 0 horz}]
  bind $w.horzScale <B1-Motion>  [namespace code {keepMovingMarquee %x %y horz}]
  bind $w.horzScale <F12><B2-Motion>  [namespace code {timeBarJump %x %y 0 horz}]
  bind $w.horzScale <ButtonRelease-1> [namespace code {letGoMarquee %x %y horz}]
  lower $w.spacer1 $w.cfr
  lower $w.spacer2 $w.cfr
  
  return
} 


proc ::timeline::reconfigureCanvas {} {
  variable xcanmax
  variable ycanmax
  variable w
  variable ysize 
  variable xcanwindowmax 
  variable ycanwindowmax
  variable horzScaleHeight
  variable vertScaleWidth
  variable xcanwindowStarting
  variable xcanwindowmax 
  variable firstData
  variable xcol

  #in future, add to xcanwindowstarting if we widen window
  set xcanwindowmax  $xcanwindowStarting 


  #check if can cause trouble if no mol loaded...
  $w.can configure  -height $ycanwindowmax -width $xcanwindowmax 
  $w.horzScale configure  -height  $horzScaleHeight  -scrollregion "0 0 $xcanmax(data) $horzScaleHeight"

  $w.vertScale configure  -width $vertScaleWidth -scrollregion "0 0 $vertScaleWidth $ycanmax(data)" 
  $w.horzScale delete all
  $w.vertScale delete all
  $w.can delete all

}

proc ::timeline::draw_traj_highlight {xStart xFinish} {

  variable w 
  variable dataVal 
  variable dataValNum 
  variable xcol 
  variable ytopmargin 
  variable ytopmargin 
  variable scaley
  variable ybox  
  variable currentMol 
  variable rep 
  variable bond_rad 
  variable bond_res
  variable rectCreated

  puts "now in draw_traj_highlight, xStart = $xStart, rectCreated = $rectCreated"
  $w.can delete trajHighlight 
  for {set i 0} {$i<=$dataValNum} {incr i} {
    if  {$dataVal(picked,$i) == 1} {
      set ypos [expr $ytopmargin+ ($scaley * $i *$ybox)]
      
      set red 0 
      set green 0 
      set blue 255 
      #convert red blue green 0 - 255 to hex
      set hexred     [format "%02x" $red]
      set hexgreen   [format "%02x" $green]
      set hexblue    [format "%02x" $blue]
      

      ###draw highlight only if not yet drawn -- if rectCreated is 0, we may just cleared the rects
      ###     to redraw free of accumulated scaling errors
      ###if {($dataVal(pickedId,$i) == "null") || ($rectCreated == 0)} 
      
      #always draw trajBox
      #after prototype, merge this with normal highlight draw method
      set trajBox [$w.can create rectangle  $xStart $ypos $xFinish [expr $ypos + ($scaley * $ybox)]  -fill "\#${hexred}${hexgreen}${hexblue}" -stipple gray25 -outline "" -tags [list dataScalable trajHighlight ] ]
      #puts "trajBox is $trajBox, xStart = $xStart, $xFinish = $xFinish"
      
      #$w.can lower $dataVal(pickedId,$i) vertScaleText 
      
      
      
    }
  }
}

proc ::timeline::drawVertHighlight  {} {

  variable w 
  variable dataVal 
  variable dataValNum 
  variable xcol 
  variable ytopmargin 
  variable scaley
  variable ybox  
  variable currentMol 
  variable rep 
  variable bond_rad 
  variable bond_res
  variable rectCreated
  variable vertHighLeft
  variable vertHighRight

  set red 255
  set green 0
  set blue 255
  #convert red blue green 0 - 255 to hex
  set hexred     [format "%02x" $red]
  set hexgreen   [format "%02x" $green]
  set hexblue    [format "%02x" $blue]
  set highlightColorString    "\#${hexred}${hexgreen}${hexblue}" 

  for {set i 0} {$i<=$dataValNum} {incr i} {
    if  {$dataVal(picked,$i) == 1} {
      set ypos [expr $ytopmargin+ ($scaley * $i *$ybox)]
      
      
      #draw highlight only if not yet drawn -- if rectCreated is 0, we may  just cleared the rects
      #     to redraw free of accumulated scaling errors
      if {($dataVal(pickedId,$i) == "null") || ($rectCreated == 0)} {

        set dataVal(pickedId,$i)  [$w.vertScale create rectangle  $vertHighLeft $ypos $vertHighRight [expr $ypos + ($scaley * $ybox)]  -fill $highlightColorString -outline "" -tags yScalable]
        
        
        $w.vertScale lower $dataVal(pickedId,$i) vertScaleText 
        
      }
      
    }
  }

  
  #make selection string to display in VMD 
  set ll "" 
  set prevChain "Empty" 




  #Cannot be held by chain  

  for {set i 0} {$i <= $dataValNum} {incr i} {
    if {$dataVal(picked,$i) == 1} {
      if { [string compare $prevChain $dataVal(2,$i)] != 0} {
        #chain is new or has changed
        append ll ") or (chain $dataVal(2,$i)  and resid $dataVal(0,$i)"
      } else {
        append ll " $dataVal(0,$i)"
      }
      set prevChain $dataVal(2,$i)
    }
  }  
  append ll ")"
  set ll [string trimleft $ll ") or " ]

  #check for the state when mol first loaded
  if {$ll ==""} {
    set ll "none"
  } 
  
  
  if {($rep($currentMol) != "null")} {

    if { [expr [molinfo $currentMol get numreps] -1] >= $rep($currentMol) } {

      mol modselect $rep($currentMol) $currentMol $ll
    } else {
      createHighlight  $ll      
    }
  } else {
    createHighlight  $ll        
    #mol selection $ll
    #mol modstyle $rep($currentMol)  $currentMol Bonds $bond_rad $bond_res
    #mol color ColorID 11 
    #get info about this
  }
  return
}


proc ::timeline::list_pick {name element op} {
  
  global vmd_pick_atom 
  global vmd_pick_mol 
  global vmd_pick_shift_state  

  variable w 
  variable xcanmax
  variable ycanmax
  variable xcanwindowmax 
  variable ycanwindowmax
  variable ybox
  variable ytopmargin 
  variable ybottommargin 
  variable vertTextSkip 
  variable scaley 
  variable dataVal 
  variable dataValNum 
  variable dataName 
  variable dataNameLast 
  variable bond_rad 
  variable bond_res 
  variable rep 
  variable xcol 
  variable ysize 
  variable currentMol
  # get the coordinates



  #later deal with top (and rep)  etc. for multi-mol use


  
  if {$vmd_pick_mol == $currentMol} {
    
    set sel [atomselect $currentMol "index $vmd_pick_atom"]
    
    set pickedresid [lindex [$sel get {resid}] 0] 
    set pickedchain  [lindex [$sel get {chain}] 0] 
    set pickedresname [lindex  [$sel get {resname}] 0]
    
    
    set pickedOne -1
    for {set i 0} {$i <= $dataValNum} {incr i} {
      
      if {($dataVal(0,$i) == $pickedresid) && ($dataVal(1,$i) == $pickedresname) &&  ($dataVal(2,$i) == $pickedchain)} {
        set pickedOne $i
        
        break
      }
    }
    
    if {$pickedOne >= 0} {
      set ypos [expr $ytopmargin+ ($scaley * $i *$ybox)]
      
      #do bitwise AND to check for shift-key bit
      if {$vmd_pick_shift_state & 1} {
        set shiftPressed 1
      } else {
        set shiftPressed 0
      }
      

      
      if {$shiftPressed == 0 } {
        #delete all from canvas

        for {set i 0} {$i <= $dataValNum} {incr i} {
          set dataVal(picked,$i) 0
          if {$dataVal(pickedId,$i) != "null"} {
            $w.can delete $dataVal(pickedId,$i)
            set dataVal(pickedId,$i) "null"
          }
        }
      }
      
      
      set dataVal(picked,$pickedOne) 1
      
      drawVertHighlight 
      
      #scroll to picked
      set center [expr $ytopmargin + ($ybox * $scaley * $pickedOne) ] 
      set top [expr $center - 0.5 * $ycanwindowmax]
      
      if {$top < 0} {
        set top 0
      }
      set yfrac [expr $top / $ysize]
      $w.can yview moveto $yfrac
    }
    
  }
  return
}



proc ::timeline::zoomSeqMain {} {
  #------------------------
  #------------------------
  # main code starts here
  #vars initialized a few lines down
  

  #puts "in zoomSeqMain.."
  variable w 
  variable monoFont
  variable eo 
  variable x1 
  variable y1 
  variable startShiftPressed 
  variable startCanvas
  variable vmd_pick_shift_state 
  variable amino_code_toggle 
  variable bond_rad 
  variable bond_res
  variable so 
  variable xcanwindowmax 
  variable ycanwindowmax 
  variable xcanmax 
  variable ycanmax
  variable ybox 
  variable ysize 
  variable resnamelist 
  variable structlist 
  variable betalist 
  variable sel 
  variable canvasnew 
  variable scaley 
  variable dataVal 
  variable dataHash
  variable rectId
  #dataValNum is -1 if no data present, 
  variable dataValNum 
  variable dataName 
  variable dataNameLast 
  variable ytopmargin 
  variable ybottommargin 
  variable xrightmargin
  variable vertTextSkip   
  variable xcolbond_rad 
  variable bond_res 
  variable rep 
  variable xcol 
  variable amino_code_toggle 
  variable dataWidth 
  variable dataMargin 
  variable firstData 
  variable dataMin 
  variable dataMax 
  variable xPosScaleVal
  variable currentMol
  variable fit_scalex
  variable fit_scaley
  variable usableMolLoaded 
  variable initializedVars
  variable prevScalet
  variable rectCreated
  variable windowShowing
  variable needsDataUpdate 
  variable numFrames

  #if there are no mols at all,
  #there certainly aren't any non-graphics mols
  if {[molinfo num] ==0} {
    set usableMolLoaded 0
  }
  

  #Init vars and draw interface
  if {$initializedVars == 0} {
    initVars
    draw_interface
    makecanvas
    set initializedVars 1
    #watch the slider value, tells us when to redraw
    #this sets a trace for ::timeline::scaley
    
  } else {
    #even if no molecule is present
    reconfigureCanvas
  }   
  
  
  #-----
  #Now load info from the current molecule, must reload for every molecule change
  
  if {$usableMolLoaded} {
    #get info for new mol
    #set needsDataUpdate 0
    
    set dataNameLast 2
    #The number of dataNames
    
    #lets fill  a (dataNameLast +1 ) x (dataValNum +1) array
    #dataValNum we'll be the number of objects we found with VMD search
    #if doing proteins, liekly all residues, found with 'name CA'
    
    set dataValNum -1
    #if no data is available, dataValNum will remain -1 
    

    # set  a new  trace below, only if dataValNum > -1  
    
    set currentMol_name [molinfo $currentMol get name]
    wm title $w "VMD Timeline  $currentMol_name (mol $currentMol) "
    set sel [atomselect $currentMol "all and name CA"]
    #below assumes sel retrievals in same order each time, fix this 
    #by changing to one retreival and chopping up result
    set datalist  [$sel get {resid resname chain}]
    puts "Checking sequence info. for molecule $currentMol..."

    catch {unset dataHash}
    
    foreach elem $datalist {
      
      incr dataValNum
      #set picked state to false -- 'picked' is only non-numerical field
      set dataVal(picked,$dataValNum) 0
      set dataVal(pickedId,$dataValNum) "null"
      set theResid [ lindex [split $elem] 0]
      set dataVal(0,$dataValNum) $theResid 
      
      set dataVal(1,$dataValNum) [ lindex [split $elem] 1]
      set dataVal(1code,$dataValNum) [lookupCode $dataVal(1,$dataValNum)]
      set theChain [ lindex [split $elem] 2]
      set dataVal(2,$dataValNum) $theChain 
      #for fast index searching later
      set dataHash($theResid,$theChain) $dataValNum
    }
    #if datalist is length 0 (empty), dataValNum is still -1, 
    #So we must check before each use of dataValNum     
    
    #set the molec. structure so nothing is highlighted yet
    set rep($currentMol) "null"
    
    
    if {$dataValNum <= -1 } {
      #puts "Couldn't find a sequence in this molecule.\n"
      return
    }
    
    
    
    
    #So dataValNum is number of the last dataVal.  It is also #elements -1, 
    
    #numFrames (and routines that use it)  will eventualy be changed
    # to reflect loaded data, and  multi-frame-data groups
    set numFrames [molinfo $currentMol get numframes]
    
    set fit_scalex [expr (0.0 + $xcanwindowmax - $xcol($firstData) ) / ($dataWidth * (2 + $numFrames) ) ]
    set fit_scaley [expr (0.0 + $ycanwindowmax - $ytopmargin - $ybottommargin) / ($ybox * ($dataValNum + 1) ) ]
    #since we zero-count.

    set scaley 1.0
    set scalex $fit_scalex 
    puts "Restarting data, scalex = $scalex, scaley= $scaley"
    #this trace only set if dataValNum != -1

    #Other variable-adding methods
    #should not change this number.  We trust $sel to always
    #give dataValNum elems, other methods might not work as well.
    
    
    #handle if this value is 0 or -1
    
    
    #don't need datalist anymore
    unset datalist 
    
    
    
    #now lets fill in some data
    
    #new data, so need to redraw rects when time comes
    set rectCreated 0 
    #also set revScaley back to 1 
    set prevScaley scaley
    set prevScalex scalex 
    #fill in betalist (B-factors/temp factors called beta by VMD)
    incr dataNameLast
    set betalist [$sel get beta]
    set dataName($dataNameLast) "B value"
    set dataMin($dataNameLast) 0.0
    set dataMax($dataNameLast) 150.0
    set i 0
    foreach elem $betalist {
      set dataVal($dataNameLast,$i) $elem
      incr i
    }
    
    # Now there are 4 dataNames,   current
    #value of dataNameNum is 3. last is numbered (dataNameLast) = 3
    
    
    unset  betalist ;#done with it


    #fill in traj data with X position (very fast) 
    
    calcDataX
    #puts "after initial calcDataX, dataNameLast= $dataNameLast, dataVal(8,8)= $dataVal(8,8)"
    



    #lets add another data field, just to test...
    #incr dataNameLast

    #set test_pos_list [$sel get y]
    #set dataName($dataNameLast) "test Y"
    #set dataMin($dataNameLast) 0 
    #set dataMax($dataNameLast) 10 
    #set i 0
    #foreach elem $test_pos_list {
    #    set dataVal($dataNameLast,$i)  $elem
    #    incr i
    #}
    #unset test_pos_list
    
    
  } 
  
  #puts "time for first redraw, scales, min/max not calced"
  #redraw first time
  redraw name func ops
  
  #now draw the scales (after the data, we may need to extract min/max 
  #------
  #draw color legends, loop over all data fields
  set fieldLast  $dataNameLast
  #puts "dataName(0) is $dataName(0) dataName(1) is $dataName(1)"
  

  return
}


proc ::timeline::molChooseMenu {name function op} {
  variable w

  variable usableMolLoaded
  variable currentMol
  variable prevMol
  variable nullMolString
  $w.mol.menu delete 0 end



  set molList ""
  foreach mm [molinfo list] {
    if {[molinfo $mm get filetype] != "graphics"} {
      lappend molList $mm
      #add a radiobutton, but control via commands, not trace,
      #since if this used a trace, the trace's callback
      #would delete that trace var, causing app to crash.
      #variable and value only for easy button lighting
      #$w.mol.menu add radiobutton -variable [namespace current]::currentMol -value $mm -label "$mm [molinfo $mm get name]" -command [namespace code "molChoose name function op"]
      $w.mol.menu add radiobutton -variable [namespace current]::currentMol -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {$molList == ""} {
    set usableMolLoaded  0
    if {$prevMol != $nullMolString} {
      set currentMol $nullMolString
    }
  } else {

    #deal with first (or from-no mol state) mol load
    # and, deal with deletion of currentMol, if mols present
    # by setting the current mol to whatever top is
    if {($usableMolLoaded == 0) || [lsearch -exact $molList $currentMol]== -1 } {
      set usableMolLoaded 1
      set currentMol [molinfo top]
    }

  }


  
  
  return
}

#################
# set unit cell dialog
proc ::timeline::setScaling {args} {
  variable clicked
  variable trajMin
  variable trajMax 

  # save old values 
  set oldmin $trajMin
  set oldmax $trajMax

  set d .scalingdialog
  catch {destroy $d}
  toplevel $d -class Dialog
  wm title $d {Set Scaling for Timeline}
  wm protocol $d WM_DELETE_WINDOW {set ::timeline::clicked -1}
  wm minsize  $d 220 120  

  # only make the dialog transient if the parent is viewable.
  if {[winfo viewable [winfo toplevel [winfo parent $d]]] } {
      wm transient $d [winfo toplevel [winfo parent $d]]
  }

  frame $d.bot
  frame $d.top
  $d.bot configure -relief raised -bd 1
  $d.top configure -relief raised -bd 1
  pack $d.bot -side bottom -fill both
  pack $d.top -side top -fill both -expand 1

  # dialog contents:
  label $d.head -justify center -relief raised -text {Set scaling for timeline:}
    pack $d.head -in $d.top -side top -fill both -padx 6m -pady 6m
    grid $d.head -in $d.top -column 0 -row 0 -columnspan 2 -sticky snew 
    label $d.la  -justify left -text {Bottom value:}
    label $d.lb  -justify left -text {Top value:}
    set i 1
    grid columnconfigure $d.top 0 -weight 2
    foreach l "$d.la $d.lb" {
        pack $l -in $d.top -side left -expand 1 -padx 3m -pady 3m
        grid $l -in $d.top -column 0 -row $i -sticky w 
        incr i
    }

    entry $d.ea  -justify left -textvariable ::timeline::trajMin
    entry $d.eb  -justify left -textvariable ::timeline::trajMax
    set i 1
    grid columnconfigure $d.top 1 -weight 2
    foreach l "$d.ea $d.eb" {
        pack $l -in $d.top -side left -expand 1 -padx 3m -pady 3m
        grid $l -in $d.top -column 1 -row $i -sticky w 
        incr i
    }
    
    # buttons
    button $d.ok -text {OK} -command {::timeline::recalc ; set ::timeline::clicked 1}
    grid $d.ok -in $d.bot -column 0 -row 0 -sticky ew -padx 10 -pady 4
    grid columnconfigure $d.bot 0
    button $d.cancel -text {Cancel} -command {set ::timeline::trajMin $timeline::oldmin ; set ::timeline::trajMax $::timeline::oldmax ; set ::timeline::clicked 1}
    grid $d.cancel -in $d.bot -column 1 -row 0 -sticky ew -padx 10 -pady 4
    grid columnconfigure $d.bot 1

    bind $d <Destroy> {set ::timeline::clicked -1}
    set oldFocus [focus]
    set oldGrab [grab current $d]
    if {[string compare $oldGrab ""]} {
        set grabStatus [grab status $oldGrab]
    }
    grab $d
    focus $d

    # wait for user to click
    vwait ::timeline::clicked
    catch {focus $oldFocus}
    catch {
        bind $d <Destroy> {}
        destroy $d
    }
    if {[string compare $oldGrab ""]} {
      if {[string compare $grabStatus "global"]} {
            grab $oldGrab
      } else {
          grab -global $oldGrab
        }
    }
    return
}


proc ::timeline::printCanvas {} {
  variable w
  #extract first part of molecule name to print here?
  set filename "VMD_Timeline_Window.ps"
  set filename [tk_getSaveFile -initialfile $filename -title "VMD Timeline Print" -parent $w -filetypes [list {{Postscript Files} {.ps}} {{All files} {*} }] ]
  if {$filename != ""} {
    $w.can postscript -file $filename
  }
  
  return
}





proc ::timeline::getStartedMarquee {x y shiftState whichCanvas} {

  variable w 
  variable x1 
  variable y1 
  variable so
  variable str 
  variable eo 
  variable g 
  variable startCanvas 
  variable startShiftPressed
  variable xcanmax
  variable ycanmax
  variable usableMolLoaded

  
  
  if {$usableMolLoaded} {

    #calculate offset for canvas scroll
    set startShiftPressed $shiftState   
    set startCanvas $whichCanvas 
    #get actual name of canvas
    switch -exact $startCanvas {
      data {set drawCan can}
      vert {set drawCan vertScale}
      horz {set drawCan horzScale}
      default {puts "problem with finding canvas..., startCanvas= >$startCanvas<"} 
    }   
    set x [expr $x + $xcanmax($startCanvas) * [lindex [$w.$drawCan xview] 0]] 
    set y [expr $y + $ycanmax($startCanvas) * [lindex [$w.$drawCan yview] 0]] 
    
    set x1 $x
    set y1 $y
    

    puts "getStartedMarquee x= $x  y= $y, startCanvas= $startCanvas" 
    #Might have other canvas tools in future..   
    # Otherwise, start drawing rectangle for selection marquee
    
    set so [$w.$drawCan create rectangle $x $y $x $y -fill {} -outline red]
    set eo $so
  } 
  return
}


proc ::timeline::molChoose {name function op} {

  variable scaley
  variable w
  variable currentMol
  variable prevMol
  variable nullMolString
  variable rep 
  variable usableMolLoaded
  variable needsDataUpdate
  variable windowShowing
  


  #this does complete restart
  #can do this more gently...
  
  #trace vdelete scaley w [namespace code redraw]
  #trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
  
  #if there's a mol loaded, and there was an actual non-graphic mol last
  #time, and if there has been a selection, and thus a struct highlight
  #rep made, delete the highlight rep.
  if {($usableMolLoaded)  && ($prevMol != $nullMolString) && ($rep($prevMol) != "null")} {



    #catch this since currently is exposed to user, so 
    #switching/reselecting  molecules can fix problems.
    ##puts "About to delete rep=$rep($prevMol) for prevMol= $prevMol"
    #determine if this mol exists...
    if  {[lsearch -exact [molinfo list] $prevMol] != -1}  {
      #determine if this rep exists (may have been deleted by user)
      if { [expr [molinfo $prevMol get numreps] -1] >= $rep($prevMol) } { 
        
        mol delrep $rep($prevMol) $prevMol 
      }
    }
    
  }

  set prevMol $currentMol

  #can get here when window is not displayed if:
  #   molecule is loaded, other molecule delete via Molecule GUI form.
  # So, we'll only redraw (and possible make a length (wallclock) call
  # to STRIDE) if sequence window is showing
  
  set needsDataUpdate 1


  if {$windowShowing} {
    set needsDataUpdate 0
    #set this immediately, so other  calls can see this
    
    [namespace current]::zoomSeqMain
  }


  
  #reload/redraw stuff, settings (this may elim. need for above lines...)
  
  
  #change molecule choice and redraw if needed (visible && change) here...
  #change title of window as well
  ##wm title $w "VMD Timeline  $currentMol_name (mol $currentMol) "
  
  #reload sutff (this may elim. need for above lines...)

  return
}
proc ::timeline::keepMovingMarquee {x y whichCanvas} {

  variable x1 
  variable y1 
  variable so 
  variable w 
  variable xcanmax 
  variable ycanmax
  variable startCanvas
  variable usableMolLoaded
  #get actual name of canbas
  switch -exact $startCanvas {
    data {set drawCan can}
    vert {set drawCan vertScale}
    horz {set drawCan horzScale}
    default {puts "problem with finding canvas (moving marquee)..., startCanvas= $startCanvas"}
  } 

  
  if {$usableMolLoaded} {

    #next two lines for debeugging only
    set windowx $x
    set windowy $y 
    #calculate offset for canvas scroll
    set x [expr $x + $xcanmax($startCanvas) * [lindex [$w.$drawCan xview] 0]] 
    set y [expr $y + $ycanmax($startCanvas) * [lindex [$w.$drawCan yview] 0]] 
    
    
    
    
    $w.$drawCan coords $so $x1 $y1 $x $y
  }
  return
}

proc ::timeline::letGoMarquee {x y whichCanvas} {


  variable x1 
  variable y1 
  variable startShiftPressed 
  variable startCanvas
  variable so 
  variable eo 
  variable w 
  variable xcanmax
  variable ycanmax
  variable ySelStart 
  variable ySelFinish 
  variable ybox 
  variable ytopmargin 
  variable ybottommargin 
  variable vertTextSkip 
  variable scalex 
  variable scaley 
  variable dataVal 
  variable dataValNum 
  variable dataName 
  variable dataNameLast 
  variable bond_rad 
  variable bond_res 
  variable rep 
  variable xcol
  variable currentMol
  variable usableMolLoaded
  variable firstData
  variable dataWidth 
  variable ycanwindowmax  
  variable numFrames
  variable firstStructField
  #set actual name of canvas
  switch -exact $startCanvas {
    data {set drawCan can}
    vert {set drawCan vertScale}
    horz {set drawCan horzScale}
    default {puts "problem with finding canvas (moving marquee)..., startCanvas= $startCanvas"}
  }

  if {$usableMolLoaded} {
    #calculate offset for canvas scroll
    set x [expr $x + $xcanmax(data) * [lindex [$w.$drawCan xview] 0]] 
    set y [expr $y + $ycanmax(data) * [lindex [$w.$drawCan yview] 0]] 

    #compute the frame at xSelStart
    if {$x1 < $x} {
      set xSelStart $x1
      set xSelFinish $x
    }  else {
      set xSelStart $x
      set xSelFinish $x1
    }
    puts "xSelStart is $xSelStart xSelFinish is $xSelStart" 
    
    #in initVars we hardcode firstStructField to be 4
    #later, there may be many field-groups that can be stretched 
    set xPosStructStart [expr int ($xcol($firstData) + ($dataWidth * ($firstStructField - $firstData) ) )] 

    set selStartFrame [expr  int (($xSelStart - $xcol($firstData))/ ($dataWidth * $scalex)) - 1 ]
    set selFinishFrame [expr int( ($xSelFinish - $xcol($firstData))/ ($dataWidth * $scalex) ) - 1]
    if { $selFinishFrame > $numFrames} {
      set selFinishFrame $numFrames
    }
    puts "selected frames $selStartFrame to   $selFinishFrame"

    if {$y1 < $y} {
      set ySelStart $y1
      set ySelFinish $y}  else {
        
        set ySelStart $y
        set ySelFinish $y1
      }
    
    set startObject [expr 0.0 + ((0.0 + $ySelStart - $ytopmargin) / ($scaley * $ybox))]
    set finishObject [expr 0.0 + ((0.0 + $ySelFinish - $ytopmargin) / ($scaley * $ybox))]
    
    
    
    if {$startShiftPressed == 1} {
      set singleSel 0
    } else {
      set singleSel 1
    }
    
    if {$startObject < 0} {set startObject 0}
    if {$finishObject < 0} {set finishObject 0}
    if {$startObject > $dataValNum} {set startObject   $dataValNum }
    if {$finishObject > $dataValNum} {set finishObject $dataValNum }
    set startObject [expr int($startObject)]
    set finishObject [expr int($finishObject)]
    
    
    
    #clear all if click/click-drag, don't clear if shift-click, shift-click-drag
    
    if {$singleSel == 1} {
      
      for {set i 0} {$i <= $dataValNum} {incr i} {
        set dataVal(picked,$i) 0
        if {$dataVal(pickedId,$i) != "null"} {
          
          $w.vertScale delete $dataVal(pickedId,$i)
          set dataVal(pickedId,$i) "null"
        }
      }

    } else {
      
      #just leave alone 
    }
    
    
    
    
    #set flags for selection
    for {set i $startObject} {$i <= $finishObject} {incr i} {
      set dataVal(picked,$i) 1
    }
    
    
    
    set field 0
    #note that the column will be 0, but the data will be from picked
    
    drawVertHighlight 
    
    
    puts "now to delete outline, eo= $eo" 
    $w.$drawCan delete $eo
    $w.can delete timeBarRect 
    #now that highlight changed, can animate
    #if single selection in frame area, animate, then jump to that frame
    if {  ($selStartFrame >= 0) } {
      if {$selFinishFrame > $selStartFrame} {
        #draw a box to show selected animation

        
        #hardcoded, assumes the traj group starts at col 4
        #optimizations obvious, much math repeated...
        set xStartFrame [expr  ( ($selStartFrame + .9) * ($dataWidth * $scalex)) +  $xcol($firstData)]
        #stretch across width of ending frame
        set xFinishFrame [expr  ( ($selFinishFrame+ 1.9) * ($dataWidth * $scalex)) +  $xcol($firstData)]

        puts "now to  draw_traj_highlight $xStartFrame $xFinishFrame"
        draw_traj_highlight $xStartFrame $xFinishFrame

        set xTimeBarEnd  [expr  ( ($selStartFrame + 1.9) * ($dataWidth * $scalex)) +  $xcol($firstData)]
        
        set timeBar [$w.can create rectangle  $xStartFrame 1 $xTimeBarEnd [expr $ycanmax(data) ]   -fill "\#000000" -stipple gray50 -outline "" -tags [list dataScalable timeBarRect ] ]
        display update ui
        #maybe store top, and restore it afterwards
        mol top $currentMol
        #make this controllable, and animation repeatable without
        #need to reselect
        for {set r 1} {$r <= 3} {incr r} {
          for {set f $selStartFrame} {$f <= $selFinishFrame} {incr f} {
            puts "time for anim. goto is [time {animate goto $f} ]"
            puts "time for draw = [time { drawTimeBar $f}]"
            puts "time for disp update = [time {display update ui}]" 
          }
        }
        $w.can delete timeBarRect 

      } 
      animate goto $selStartFrame
      drawTimeBar $selStartFrame 
      puts "now jumped to frame $selStartFrame for molecule $currentMol"
    }
    

  }
  return
}

proc ::timeline::showall { do_redraw} {



  variable scalex 
  variable scaley 
  variable fit_scalex
  variable fit_scaley
  variable usableMolLoaded
  variable rectCreated 
  variable userScalex
  variable userScaley

  #only redraw once...
  if {$usableMolLoaded} {
    if {$do_redraw == 1} {
      set rectCreated 0
    }   
    
    set scalex $fit_scalex        
    set scaley $fit_scaley
    set userScalex 1.0
    set userScaley 1.0 

    redraw name func ops
  }

  return
}


proc ::timeline::every_res {} {

  variable usableMolLoaded
  variable rectCreated
  variable fit_scalex
  #this forces redraw, to cure any scaling floating point errors
  #that have crept in 
  set rectCreated 0

  variable scaley
  variable scalex

  if {$usableMolLoaded} {
    #redraw, set x and y  at once
    set scalex $fit_scalex 
    set userScalex 1.000 
    set userScaley 1.000
    set scaley 1.0
    redraw name func ops
  }
  
  return
}


proc ::timeline::resname_toggle {} {

  variable w 
  variable amino_code_toggle
  variable usableMolLoaded
  
  if {$usableMolLoaded} {


    if {$amino_code_toggle == 0} {
      set amino_code_toggle 1
      $w.resname_toggle configure -text "3-letter code"
    } else {
      set amino_code_toggle 0
      $w.resname_toggle configure -text "1-letter code"
    }
    
    redraw name function op
  }
  return
}




proc ::timeline::initVars {} {

  variable usableMolLoaded 0
  variable windowShowing 0
  variable needsDataUpdate 0
  variable dataNameLast 2
  variable dataValNum -1
  variable eo 0
  variable x1 0 
  variable y1 0
  variable startCanvas ""
  variable startShiftPressed 0
  variable vmd_pick_shift_state 0
  variable amino_code_toggle 0
  variable bond_rad 0.5
  variable bond_res 10
  variable so ""
  variable nullMolString ""
  variable currentMol $nullMolString
  variable prevMol $nullMolString

  variable  userScalex 1
  variable  userScaley 1
  variable  userScaleBoth 1
  variable  scalex 1
  variable  scaley 1
  variable prevScalex 1
  variable prevScaley 1
  
  variable ytopmargin 5
  variable ybottommargin 10
  variable xrightmargin 8

  #variable xcanwindowStarting 780 
  variable xcanwindowStarting 685 
  variable ycanwindowStarting 574 

  variable numFrames 1
  variable xcanwindowmax  $xcanwindowStarting
  variable ycanwindowmax $ycanwindowStarting 
  variable xcanmax
  set xcanmax(data) 610
  set xcanmax(vert) 95
  set xcanmax(horz) $xcanmax(data)
  #make this sensible!
  variable ycanmax
  set ycanmax(data) 400
  set ycanmax(vert) $ycanmax(data) 
  set ycanmax(horz) 46 
  variable codes
  variable trajMin -180
  variable trajMax 180
  #hard coded, should change
  variable firstStructField 4

  array set codes {ALA A ARG R ASN N ASP D ASX B CYS C GLN Q GLU E
    GLX Z GLY G HIS H ILE I LEU L LYS K MET M PHE F PRO P SER S
    THR T TRP W TYR Y VAL V}
  
  
  

  #tests if rects for current mol have been created (should extend 
  #so memorize all rectIds in 3dim array, and track num mols-long 
  #vector of rectCreated. Would hide rects for non-disped molec,
  #and remember to delete the data when molec deleted.
  
  variable rectCreated 0

  #the box height
  variable ybox 15.0
  #text skip doesn't need to be same as ybox (e.g. if bigger numbers than boxes in 1.0 scale)
  variable vertTextSkip $ybox

  
  # For vertical scale appearance
  variable vertHighLeft 2
  variable vertHighRight 100
  variable vertTextRight 96
  #The first 3 fields, 0 to 2 are printed all together, they are text
  variable xcol
  set xcol(0) 10.0
  variable horzScaleHeight 30
  variable vertScaleWidth 100
  variable dataWidth 85
  variable dataMargin 0
  variable xPosScaleVal 32
  #so rectangge of data is drawn at width $dataWidth - $dataMargin (horizontal measures)
  #
  #residu name data is in umbered entires lowerthan 3
  variable firstData 3
  #puts "firstData is $firstData"
  #column that multi-col data first  appears in

  #old setting from when vertscale and data were on same canvas
  #set xcol($firstData)  96 
  set xcol($firstData)  1 
  #The 4th field (field 3) is the "first data field"
  #we use same data structure for labels and data, but now draw in separate canvases 
  
  # the names for  three fields of data 
  
  #just for self-doc
  # dataVal(picked,n) set if the elem is picked
  # dataVal(pickedId,n) contains the canvas Id of the elem's highlight rectangle
  

  variable dataName

  set dataName(picked) "picked" 
  set dataName(pickedId) "pickedId"
  #not included in count of # datanames
  
  set dataName(0) "resid"
  set dataName(1) "resname"
  set dataName(1code) "res-code"
  set dataName(2) "chain"
  ###set dataName(3) "check error.." 
  
  
}


proc ::timeline::Show {} {
  variable windowShowing
  variable needsDataUpdate
  set windowShowing 1

  
  if {$needsDataUpdate} {
    set needsDataUpdate 0
    #set immmediately, so other binding callbacks will see
    [namespace current]::zoomSeqMain
  }

}

proc ::timeline::Hide {} {
  variable windowShowing 
  set windowShowing 0

}



proc ::timeline::createHighlight { theSel} {

  variable currentMol
  variable bond_rad
  variable bond_res
  variable rep
  #draw first selection, as first residue 
  set rep($currentMol) [molinfo $currentMol get numreps]
  mol selection $theSel
  mol material Opaque
  mol addrep $currentMol
  mol modstyle $rep($currentMol)  $currentMol  Bonds $bond_rad $bond_res
}



proc ::timeline::draw_interface {} {
  variable w 

  variable eo 
  variable x1  
  variable y1 
  variable startCanvas
  variable startShiftPressed 
  variable vmd_pick_shift_state 
  variable amino_code_toggle 
  variable bond_rad 
  variable bond_res
  variable so 
  variable xcanwindowmax 
  variable ycanwindowmax 
  variable xcanmax 
  variable ycanmax
  variable ybox 
  variable xsize 
  variable ysize 
  variable resnamelist 
  variable structlist 
  variable betalist 
  variable sel 
  variable canvasnew 
  variable userScalex
  variable userScaley
  variable scalex 
  variable scaley 
  variable dataVal 
  variable dataValNum 
  variable dataName 
  variable dataNameLast 
  variable ytopmargin 
  variable ybottommargin 
  variable vertTextSkip   
  variable xcolbond_rad 
  variable bond_res 
  variable rep 
  variable xcol 
  variable amino_code_toggle 
  variable dataWidth 
  variable dataMargin 
  variable firstData 
  variable dataMin 
  variable dataMax 
  variable xPosScaleVal
  variable currentMol
  variable fit_scalex 1.0
  variable fit_scaley 1.0
  variable usableMolLoaded 
  variable numFrames 
  variable userScaleBoth

  frame $w.menubar -height 30 -relief raised -bd 2
  pack $w.menubar -in $w -side top -anchor nw -padx 1 -fill x

  #frame $w.fr -width 700 -height 810 -bg #FFFFFF -bd 2 ;#main frame

  #pack $w.fr

  label $w.txtlab -text "Zoom "

  frame $w.panl -width 150 -height [expr $ycanwindowmax + 80] -bg #C0C0D0 -relief raised -bd 1 
  frame $w.cfr -width 350 -height [expr $ycanwindowmax + 85] -borderwidth 1  -bg #D96060 -relief raised -bd 3
  pack $w.panl -in $w -side left -padx 2  -fill y
  #pack $w.cfr -in $w.fr -side left -padx 2 -expand yes -fill both 
  pack $w.cfr -in $w -side left -padx 2 -expand yes -fill both 

  scale $w.panl.zoomlevel -from 0.01 -to 2.01 -length 150 -sliderlength 30  -resolution 0.01 -tickinterval 0.5 -repeatinterval 30 -showvalue true -variable [namespace current]::userScaley -command [namespace code userScaleyChanged] 

  scale $w.zoomBothlevel -orient horizontal -from 0.001 -to 4.000 -length 120 -sliderlength 30  -resolution 0.001 -tickinterval 3.999 -repeatinterval 30 -showvalue true -variable [namespace current]::userScaleBoth -command [namespace code userScaleBothChanged] 
  scale $w.zoomXlevel -orient horizontal -from 0.001 -to 4.000 -length 120 -sliderlength 30  -resolution 0.001 -tickinterval 3.999 -repeatinterval 30 -showvalue true -variable [namespace current]::userScalex -command [namespace code userScalexChanged] 

  #pack $w.panl $w.cfr -in $w.fr -side left -padx 2
  pack $w.panl.zoomlevel -in $w.panl -side right -ipadx 5 -padx 3

  button $w.showall  -text "fit all" -command [namespace code {showall 0}]
  button $w.every_res  -text "every residue" -command [namespace code every_res]
  button $w.resname_toggle  -text "1-letter code" -command [namespace code resname_toggle]

  #draw canvas
  button $w.stop_zoomseq -text "Close Window" -command [namespace code stopZoomSeq]
  
  #trace for molecule choosing popup menu 
  trace variable ::vmd_initialize_structure w  [namespace code molChooseMenu]
  
  menubutton $w.mol -relief raised -bd 2 -textvariable [namespace current]::currentMol -direction flush -menu $w.mol.menu
  menu $w.mol.menu -tearoff no


  molChooseMenu name function op
  


  label $w.molLab -text "Molecule:"

  scrollbar $w.ys -command [namespace code {canvasScrollY}]
  
  scrollbar $w.xs -orient horizontal -command [namespace code {canvasScrollX}]



  #fill the  top menu
  menubutton $w.menubar.file -text "File" -underline 0 -menu $w.menubar.file.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.file config -width 5
  menubutton $w.menubar.calculate -text "Calculate" -underline 0 -menu $w.menubar.calculate.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.calculate config -width 10
  menubutton $w.menubar.graphics -text "Appearance" -underline 0 -menu $w.menubar.graphics.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.graphics config -width 11

  pack $w.menubar.file  $w.menubar.calculate $w.menubar.graphics  -side left

  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu
  menu $w.menubar.help.menu -tearoff no

  $w.menubar.help.menu add command -label "Timeline Help" -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/timeline"
  $w.menubar.help.menu add command -label "Structure codes..." -command  [namespace code {tk_messageBox -parent $w  -type ok -message "Secondary Structure Codes\n\nT        Turn\nE        Extended conformation\nB        Isolated bridge\nH        Alpha helix\nG        3-10 helix\nI         Pi-helix\nC        Coil (none of the above)\n" } ]

  pack $w.menubar.help -side right 
  
  #File menu
  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Print to file..." -command [namespace code {printCanvas} ] 
  $w.menubar.file.menu add command -label "Load data file..." -command [namespace code {loadDataFile ""}  ] 
  $w.menubar.file.menu add command -label "Write data file..." -command [namespace code {writeDataFile ""}  ] 
  $w.menubar.file.menu add command -label "Close Window" -command [namespace code stopZoomSeq] 
  
  #Calculate menu
  
  menu $w.menubar.calculate.menu  -tearoff no

  
  $w.menubar.calculate.menu add command -label "Clear data"  -command  [namespace code clearData] 
  $w.menubar.calculate.menu add command -label "Calc. Sec. Struct"  -command [namespace code {calcDataStruct; showall 1}] 
  $w.menubar.calculate.menu add command -label "Calc. X position"  -command [namespace code {calcDataX; showall 1}] 
  $w.menubar.calculate.menu add command -label "Calc. Phi"  -command [namespace code {calcDataPhi; showall 1}] 
  $w.menubar.calculate.menu add command -label "Calc. Delta Psi"  -command [namespace code {calcDataDeltaPsi; showall 1}] 
  $w.menubar.calculate.menu add command -label "Calc. per-res RMSD" -command "::rmsdtool" 
  
  #Graphics menu
  menu $w.menubar.graphics.menu -tearoff no
  $w.menubar.graphics.menu add cascade -label "Highlight color/style" -menu $w.menubar.graphics.menu.highlightMenu 
  $w.menubar.graphics.menu add command -label "Set scaling..." -command  [namespace code setScaling]
  #Second level menu for highlightColor 

  set dummyHighlight 1 
  #set dummyHighlight so drawn selected first time, we use -command for actual var change
  menu $w.menubar.graphics.menu.highlightMenu -tearoff no
  $w.menubar.graphics.menu.highlightMenu add radiobutton -label "Yellow" -command {set highlightColor yellow} -variable dummyHighlight -value 0 
  $w.menubar.graphics.menu.highlightMenu add radiobutton -label "Purple" -command {set highlightColor purple} -variable dummyHighlight -value 1 
  

  
  #the w.can object made here
  set ysize [expr $ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValNum + 1))]    
  set xsize [expr  $xcol($firstData) +  ($scalex *  $dataWidth * (1 + $numFrames) ) ]





  place $w.txtlab -in $w.panl.zoomlevel  -bordermode outside -rely 0.0 -relx 0.5 -anchor s
  place $w.showall -in $w.panl.zoomlevel  -bordermode outside -rely 1.0 -relx 0.5 -anchor n
  place $w.every_res  -in $w.showall -bordermode outside -rely 1.0 -relx 0.5 -anchor n
  place $w.resname_toggle -in $w.every_res -bordermode outside -rely 1.0 -y 40 -relx 0.5 -anchor n
  place  $w.stop_zoomseq -in $w.txtlab  -bordermode outside -rely 0.0 -y -140 -relx 0.5 -anchor s
  place  $w.zoomXlevel -in $w.stop_zoomseq  -bordermode outside -rely 0.0 -y 30  -relx 0.5 -anchor n
  place  $w.zoomBothlevel -in $w.stop_zoomseq  -bordermode outside -rely 0.0  -relx 0.5 -anchor s 
  
  place $w.mol -in $w.panl.zoomlevel  -bordermode outside -rely -.3 -relx 0.85 -anchor s
  place $w.molLab -in $w.mol -bordermode outside -rely 0.5 -relx 0 -anchor e
  #done with interface elements     


  #ask window manager for size of window

  #turn traces  on (initialize_struct trace comes later)
  #trace variable userScalex w  [namespace code redraw]
  #trace variable userScaley w  [namespace code redraw]
  trace variable ::vmd_pick_atom w [namespace code list_pick]
  trace variable currentMol w [namespace code molChoose]

}

proc  ::timeline::timeBarJump {x y shiftState whichCanvas} {
  variable xcol
  variable firstData
  variable dataWidth
  variable scalex
  variable currentMol
  variable numFrames
  variable xcanmax
  variable w
  #maybe store top, and restore it afterwards
  set x [expr $x + $xcanmax(data) * [lindex [$w.can xview] 0]]

  set cursorFrame [expr  int (($x - $xcol($firstData))/ ($dataWidth * $scalex)) - 1 ]
  if {$cursorFrame > $numFrames}  {
    set cursorFrame $numFrames
  }
  
  if {$cursorFrame < 0 } { 
    set cursorFrame 0
  } 
  if { [molinfo $currentMol get frame] != $cursorFrame } { 
    #test, and save/restore
    mol top $currentMol
    animate goto $cursorFrame

    #puts "jumped to $cursorFrame"
    drawTimeBar $cursorFrame
    #update both GL and tk timebar
    display update
    display update ui
    #puts "time for disp. update = [time {display update}]"
    #puts "time for disp. update ui= [time {display update ui}]"
  }
}

proc  ::timeline::drawTimeBar {f} {
  variable w
  variable dataWidth
  variable scalex
  variable xcol 
  variable firstData
  variable ycanmax

  #puts "showing frame $f"
  set xTimeBarStart  [expr  ( ($f + 1.0 ) * ($dataWidth * $scalex)) +  $xcol($firstData)]
  set xTimeBarEnd  [expr  ( ($f + 2.0 ) * ($dataWidth * $scalex)) +  $xcol($firstData)]
  #puts "xTimeBarStart= $xTimeBarStart  xTimeBarEnd = $xTimeBarEnd"
  #more efficient to re-configure x1 x2
  $w.can delete timeBarRect
  set timeBar [$w.can create rectangle  $xTimeBarStart 1 $xTimeBarEnd [expr $ycanmax(data) ]   -fill "\#000000" -stipple gray50 -outline "" -tags [list dataScalable timeBarRect ] ]

  #move the time line 
} 

proc ::timeline::writeDataFile {filename} {
  variable w
  variable dataName
  variable dataVal
  variable dataValNum
  variable currentMol
  variable firstStructField
  variable numFrames

  if {$filename == ""  } {
    set filename [tk_getSaveFile -initialfile $filename -title "Save Trajectory Da ta file" -parent $w -filetypes [list { {.dat files} {.dat} } { {Text files} {.txt}} {{All files} {*} }] ]
    set writeDataFile [open $filename w]
    puts $writeDataFile "# VMD sequence data"
    puts $writeDataFile "# CREATOR= $::tcl_platform(user)"
    puts $writeDataFile "# DATE= [clock format [clock seconds]]"
    puts $writeDataFile "# TITLE= [molinfo $currentMol get name]"
    puts $writeDataFile "# NUM_FRAMES= $numFrames "
    puts $writeDataFile "# FIELD= $dataName($firstStructField) "
    set endStructs [expr $firstStructField + $numFrames]
    for {set field $firstStructField} {$field <= $endStructs} {incr field} {
      for {set i 0} {$i<=$dataValNum} {incr i} {

        set val $dataVal($field,$i)
        set resid $dataVal(0,$i)
        set chain $dataVal(2,$i)
        set frame [expr $field - $firstStructField]
        puts $writeDataFile "$resid $chain CA $frame $val"
      }
    }
    close $writeDataFile
  }
  return
}
proc ::timeline::calcDataStruct {} {
  variable w
  variable dataName
  variable dataVal
  variable dataNameLast
  variable dataValNum
  variable currentMol
  variable firstTrajField
  variable numFrames
  variable dataMin
  variable dataMax
  variable lastcalc
  
  set curDataName 3
  set lastcalc 1
  set sel [atomselect $currentMol "all and name CA"]
  for {set trajFrame 0} {$trajFrame <= $numFrames} {incr  trajFrame} {
    incr curDataName  
    
    animate goto $trajFrame 
    display update ui
    $sel frame $trajFrame
    puts "set frame to $trajFrame"
    
    puts "now update for mol $currentMol"
    mol ssrecalc $currentMol
    puts "updated"
    set structlist [$sel get structure]
    #puts "setting dataName($curDataName) to struct..."
    set dataName($curDataName) "struct"

    set i 0
    foreach elem $structlist {
      set dataVal($curDataName,$i) $elem
      incr i
      
    }
    
    puts "last data name at $curDataName"
    unset structlist; #done with it

  }

  #if just setting one set of data for every frame, 
  #should clear unused dataVal()'s, etc. here.
  
  set dataNameLast $curDataName
  return
}

proc ::timeline::calcDataPhi {} {
  variable w
  variable dataNameLast
  variable dataName
  variable dataVal
  variable dataValNum
  variable currentMol
  variable firstTrajField
  variable numFrames
  variable dataMin
  variable dataMax
  variable trajMin
  variable trajMax
  variable lastcalc

  set lastcalc 3
  set curDataName 3
  set sel [atomselect $currentMol "all and name CA"]

  for {set trajFrame 0} {$trajFrame <= $numFrames} {incr  trajFrame} {
    incr curDataName

    animate goto $trajFrame
    display update ui

    $sel frame $trajFrame
    #puts "set frame to $trajFrame"

    #this is quick check, not real way to do it
    #that it doesn't use 'same selelction'
    # currently just depends on 'sel get' order being same
    #method as other stuff, should really get data and sort it
    #
    set trajList [$sel get phi]
    set dataName($curDataName) "phi-val"

    set i 0
    foreach elem $trajList {
      set dataVal($curDataName,$i) $elem
      incr i
    }
    #puts "curDataName is $curDataName"
    set dataMin($curDataName) $trajMin 
    set dataMax($curDataName) $trajMax
  }
}

proc ::timeline::calcDataDeltaPsi {} {
  variable w
  variable dataNameLast
  variable dataName
  variable dataVal
  variable dataValNum
  variable currentMol
  variable firstTrajField
  variable numFrames
  variable dataMin
  variable dataMax
  variable trajMin
  variable trajMax
  variable lastcalc

  set lastcalc 4
  set curDataName 3
  set sel [atomselect $currentMol "all and name CA"]

  for {set trajFrame 0} {$trajFrame <= $numFrames} {incr  trajFrame} {
    incr curDataName

    animate goto $trajFrame
    display update ui

    $sel frame $trajFrame
    #puts "set frame to $trajFrame"

    #this is quick check, not real way to do it
    #that it doesn't use 'same selelction'
    # currently just depends on 'sel get' order being same
    #method as other stuff, should really get data and sort it
    #
    set trajList [$sel get psi]
    set dataName($curDataName) "psi-val"

    set i 0
    foreach elem $trajList {
      set dataVal($curDataName,$i) $elem
      incr i
    }
    #puts "curDataName is $curDataName"
    set dataMin($curDataName) $trajMin
    set dataMax($curDataName) $trajMax
  }
}


proc ::timeline::calcDataX {} {
  variable w
  variable dataNameLast
  variable dataName
  variable dataVal
  variable dataValNum
  variable currentMol
  variable firstTrajField
  variable numFrames
  variable dataMin
  variable dataMax
  variable trajMin
  variable trajMax 
  variable lastcalc

  set lastcalc 2
  set curDataName 3
  set sel [atomselect $currentMol "all and name CA"]
  
  for {set trajFrame 0} {$trajFrame <= $numFrames} {incr  trajFrame} {
    incr curDataName
    
    animate goto $trajFrame
    display update ui

    $sel frame $trajFrame
    #puts "set frame to $trajFrame"
    
    #this is quick check, not real way to do it 
    #that it doesn't use 'same selelction' 
    # currently just depends on 'sel get' order being same
    #method as other stuff, should really get data and sort it
    #
    set trajList [$sel get x]
    set dataName($curDataName) "x-val"
    
    set i 0
    foreach elem $trajList {
      set dataVal($curDataName,$i) $elem
      incr i
    }
    #puts "curDataName is $curDataName"
    set dataMin($curDataName) $trajMin 
    set dataMax($curDataName) $trajMax 
  }  

  set dataNameLast $curDataName
  puts "in calcDataX, dataNameLast is $dataNameLast"
  return
}

proc ::timeline::loadDataFile {filename} {

  variable w
  variable dataVal
  variable dataHash
  variable dataValNum
  variable dataName
  variable firstStructField
  variable rectCreated 


  variable dataName
  
  if {$filename == ""  } {
    set filename [tk_getOpenFile -initialfile $filename -title "Open Trajectory Data file" -parent $w -filetypes [list { {.dat files} {.dat} } { {Text files} {.txt}} {{All files} {*} }] ]

  } 
  set dataFile [open $filename r]
  #get file lines into an array
  set commonName ""
  set fileLines ""
  while {! [eof $dataFile] } {
    gets $dataFile curLine
    if { (! [regexp "^#" $curLine] ) && ($curLine != "" ) } {
      
      lappend fileLines $curLine
    } else {
      if { [regexp "^# FIELD=" $curLine] } { 
        set commonName [lindex [split $curLine " "] 2]
        puts "Loading file, field name is $commonName"
      } 
    }
  }
  #done with the file close it 
  close $dataFile
  #set frameList ""
  #data-containing frames
  foreach line $fileLines {
    #puts "the line is >$line<"
    foreach {resid chain atom frame val} [split $line " "] {}
    #puts "resid= $resid chain= $chain atom= $atom frame= $frame val= $val" 
    lappend frameList $frame
  } 
  #puts "framelist is $frameList"

  set frameList [lsort -unique -increasing -integer $frameList]
  set minFrame [lindex $frameList 0]
  set maxFrame [lindex $frameList end]
  puts "frameList is $frameList"
  #  no lkonger find frame list, since catching errors on frame assignment
  #has same effect.  Could still 
  #assign values in a new Group
  # (temporarlily, to hard-coded fields, if still in hacky version)
  puts "now check fileLines:\n"
  foreach line $fileLines {
    #puts "assigning data, the line is >$line<"
    foreach {resid chain atom frame val} [split $line " "] {}
    
    
    #this assumes consecutive frames, should use frameList somewhere
    # if we really want proper reverse lookup
    if { [ catch {set fieldForFrame [expr $firstStructField + $frame ]} ] } {
      set fieldForFrame -2
      puts "couldn't read frame text \"$frame\""
    }

    #now do lookup via dataHash to find index in dataVal 
    if {[catch {set theIndex $dataHash($resid,$chain)} ]} {
      puts "failed to find data for resid=$resid, chain=$chain"
    } else {
      if { [catch {set dataVal($fieldForFrame,$theIndex) $val} ]} {
        puts "didn't find data for frame $frame, field= $fieldForFrame, index= $theIndex, new_val= $val"
      } else {
        set dataName($fieldForFrame) $commonName
        #puts "succesfully assigned dataVal($fieldForFrame,$theIndex) as $dataVal($fieldForFrame,$theIndex)" 
      }
    }
  }  
  

  #now delete the list of data lines, no longer needed
  unset fileLines

  #redraw the data rects
  showall 1  

  return
}

proc ::timeline::clearData {} {
  variable w
  variable dataVal
  variable dataValNum
  variable firstStructField
  variable numFrames
  variable usableMolLoaded
  variable rectCreated
  variable lastcalc


  set lastcalc 0
  puts "clearing 2D data..."
  set endStructs [expr $firstStructField + $numFrames]
  for {set field $firstStructField} {$field <= $endStructs} {incr field} {
    for {set i 0} {$i<=$dataValNum} {incr i} {

      set  dataVal($field,$i) "null"
      # for the special struct case, the 0 shold give default color
      #puts "dataVal($field,$i) is now $dataVal($field,$i)"
      #set resid $dataVal(0,$i)
      #set chain $dataVal(2,$i)
      #set frame [expr $field - $firstStructField]
      #puts $writeDataFile "$resid $chain CA $frame $val"
      
    }
  }
  #redraw the data rects
  showall 1
  return
}
proc  ::timeline::userScaleBothChanged {val} {
  variable userScalex
  variable userScaley
  variable userScaleBoth
  variable scaley
  variable fit_scalex
  variable fit_scaley
  variable scalex
  set scalex [expr $userScaleBoth * $fit_scalex]
  set scaley [expr $userScaleBoth * $fit_scaley]
  set userScaleX  $userScaleBoth
  set userScaleY $userScaleBoth
  redraw name func op
  #puts "redrawn, userScaleBoth= $userScaleBoth, scalex= $scalex, userScalex= $userScalex, scaley= $scaley, userScaley= $userScaley"
  return
}
proc  ::timeline::userScalexChanged {val} {
  variable userScalex
  variable scalex
  variable fit_scalex
  set scalex [expr $userScalex * $fit_scalex]
  redraw name func op
  #puts "redrawn, scalex= $scalex, userScalex= $userScalex"
  return
}
proc ::timeline::userScaleyChanged {val} {
  variable userScaley
  variable scaley
  variable fit_scaley
  #until working ok, still do direct mapping
  set scaley [expr $userScaley * $fit_scaley]
  #set scaley $userScaley 
  redraw name func op
  #puts "redrawn, scaley= $scaley, userScaley= $userScaley"
  return
}


proc ::timeline::drawVertScale {} {
  variable w
  variable ytopmargin
  variable scaley
  variable ybox
  variable dataValNum
  variable dataVal
  variable vertTextSkip
  variable verTextLeft
  variable vertTextRight
  variable amino_code_toggle
  variable monoFont

  $w.vertScale delete vertScaleText 

  
  #when adding new column, add to this list (maybe adjustable later)
  #The picked fields 
  
  #Add the text...
  set field 0           

  #note that the column will be 0, but the data will be from picked
  
  
  set yDataEnd [expr $ytopmargin + ($scaley * $ybox * ($dataValNum +1))]
  set y 0.0

  set yposPrev  -10000.0

  #Add the text to vertScale...
  set field 0            



  #we want text to appear in center of the dataRect we are labeling
  set vertOffset [expr $scaley * $ybox / 2.0]

  #don't do $dataValNum, its done at end, to ensure always print last 
  for {set i 0} {$i <= $dataValNum} {incr i} {
    set ypos [expr $ytopmargin + ($scaley * $y) + $vertOffset]
    if { ( ($ypos - $yposPrev) >= $vertTextSkip) && ( ( $i == $dataValNum) || ( ($yDataEnd - $ypos) > $vertTextSkip) ) } {
      if {$amino_code_toggle == 0} {
        set res_string $dataVal(1,$i)} else {
          set res_string $dataVal(1code,$i)
        }
      


      #for speed, we use vertScaleText instead of $dataName($field)
      $w.vertScale create text $vertTextRight $ypos -text "$dataVal(0,$i) $res_string $dataVal(2,$i)" -width 200 -font $monoFont -justify right -anchor e -tags vertScaleText 

      set yposPrev  $ypos
    }        
    set y [expr $y + $vertTextSkip]
    
  } 
  
  
}


proc ::timeline::drawHorzScale {} {
  variable w
  variable ytopmargin
  variable scalex
  variable dataValNum
  variable dataVal
  variable monoFont
  variable firstData
  variable dataNameLast 
  variable xcol
  variable numframes    
  variable dataWidth

  $w.horzScale delete horzScaleText 

  
  #when adding new column, add to this list (maybe adjustable later)
  #The picked fields 
  
  #Add the text...

  #note that the column will be 0, but the data will be from picked
  
  #we want text to appear in center of the dataRect we are labeling
  set fieldLast $dataNameLast
  #ensure minimal horizaontal spacing
  set horzSpacing 17 
  set horzDataTextSkip [expr $dataWidth]
  set scaledHorzDataTextSkip [expr $scalex * $dataWidth]
  set scaledHorzDataOffset [expr $scalex * $dataWidth / 2.0]
  set ypos 20 
  set xStart [expr ($xcol($firstData) + $scalex * $dataWidth)]
  set xDataEnd  [expr int ($xStart +  $scalex * ($dataWidth * ($fieldLast - $firstData -1) ) )] 
  set x 0 


  #don't do $dataValNum, its done at end, to ensure always print last 

  #numbers are scaled for 1.0 until xpos
  #this is tied to data fields, which is produced from frames upong
  #first drawing. Should really agreee with writeDataFile, which currently uses frames, not fields
  set xposPrev -1000 
  #there is B data in $firstData, traj data starts at firstData+1
  for {set field [expr $firstData+1]} {$field <= $fieldLast} {incr field} {
    set frameNum [expr $field - $firstData -1]
    
    set xpos [expr int ($xStart + ($scalex * $x) + $scaledHorzDataOffset)]
    if { ( ($xpos - $xposPrev) >= $horzSpacing) && ( ( $field == $fieldLast) || ( ($xDataEnd - $xpos) > $horzSpacing) ) } {

      


      #for speed, we use vertScaleText instead of $dataName($field)
      $w.horzScale create text $xpos $ypos -text "$frameNum" -width 30 -font $monoFont -justify center -anchor s -tags horzScaleText 

      set xposPrev  $xpos
    }        
    set x [expr $x + $horzDataTextSkip]
    
  } 

  
}

#############################################
# end of the proc definitions
############################################






####################################################
# Execution starts here. 
####################################################

#####################################################
# set traces and some binidngs, then call zoomSeqMain
#####################################################
proc ::timeline::startTimeline {} {
  
  ####################################################
  # Create the window, in withdrawn form,
  # when script is sourced (at VMD startup)
  ####################################################
  variable w .vmd_timeline_Window
  set windowError 0
  set errMsg ""

  #if timeline has already been started, just deiconify window
  if { [winfo exists $w] } {
    wm deiconify $w 
    return
  }

  if { [catch {toplevel $w -visual truecolor} errMsg] } {
    puts "Info) Timeline window can't find trucolor visual, will use default visual.\nInfo)   (Error reported was: $errMsg)" 
    if { [catch {toplevel $w } errMsg ]} {
      puts "Info) Default visual failed, Timeline window cannot be created. \nInfo)   (Error reported was: $errMsg)"    
      set windowError 1
    }
  }
  if {$windowError == 0} { 
    #don't withdraw, not under vmd menu control during testing
    #wm withdraw $w
    wm title $w "VMD Timeline"
    #wm resizable $w 0 0 
    wm resizable $w 1 1 

    variable w
    variable monoFont
    variable initializedVars 0
    variable needsDataUpdate 0 

    #overkill for debugging, should only need to delete once....
    trace vdelete currentMol w [namespace code molChoose]
    trace vdelete currentMol w [namespace code molChoose]
    trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
    trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
    trace vdelete ::vmd_initialize_structure w  [namespace code molChooseMenu]
    trace vdelete ::vmd_initialize_structure w  [namespace code molChooseMenu]


    bind $w <Map> "+[namespace code Show]"
    bind $w <Unmap> "+[namespace code Hide]"
    #specify monospaced font, 12 pixels wide
    #font create tkFixedMulti -family Courier -size -12
    #for test run tkFixed was made by normal sequence window
    set monoFont tkFixed

    #call to set up, after this, all is driven by trace and bind callbacks
    zoomSeqMain
  }
  return $w
}
