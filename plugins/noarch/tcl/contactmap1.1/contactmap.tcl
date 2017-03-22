#
# contactmap.tcl  -- compare 2 molecules, in the style of a contact map
#
# Copyright (c) 2002 The Board of Trustees of the University of Illinois
#
# Barry Isralewitz  barryi@ks.uiuc.edu    
# vmd@ks.uiuc.edu
#
# $Id: contactmap.tcl,v 1.43 2006/04/16 23:15:20 johns Exp $
#
#
# To try out:
# 0) start vmd
# 1) mol pdbload 1tit
# 2) source contactmap.tcl; contactmap
# 3) select "fit all", then "Calculate: Calc res-res Dists"
# 4) move over contact map with button 2 (middle button) pressed
#    to see pair selected
# 5) After changing moelcule/typed selection, re-select MoleculeA
#    popup menui, then re-select "Calculate: Calc res-res Dists".
# 6) Move mouse over contact map with middle button pressed to see the vert and horz axis highlights
# 7) caveat: only aware of molec# changes after MoleculeA is changed.  To change both, change B, then A.
#   Note: fun to try with slightly misaligned molecs, try two copies
#    slightly moved/shifted from each other.
#
# BUGS/TODO:
# * Disjoint sets of residues (e.g. "(resid 1 to 3) or (resid 5 to 10)")
#   don't display properly
# * Scale isn't always aligned with map
# * Not all residues included in selection
# * Marquee doesn't create highlight in VMD graphics window

package provide contactmap 1.0

#######################
#create the namespace
#######################
proc contactmap {} {
  return [::contactmap::startContactmap]
}
namespace eval ::contactmap {
  namespace export aligntool
  variable fit_scalex 1
  variable fit_scaley 1
}


####################
#define the procs
####################

# Optionally print potentially useful messages on the console.
proc ::contactmap::verbose {args} {
  variable verboseChannel

  if {$verboseChannel != {}} {
    puts $verboseChannel [lindex $args 0]
  }
}

# Scroll the canvases
proc ::contactmap::canvasScrollY {args} {
  variable w
  eval $w.cfr.can yview $args
  eval $w.cfr.vertScale yview $args 
}

proc ::contactmap::canvasScrollX {args} { 
  variable w
  eval $w.cfr.can xview $args
  eval $w.cfr.horzScale xview $args 
}


# Find the one-letter code for the given resname
proc ::contactmap::lookupCode {resname} {
  variable codes

  set result ""
  if {[catch { set result $codes($resname) } ]} {
    set result $resname
  } else {
    set result " $result "
  }
  return $result
}


# Return a greyscale triplet corresponding to the given intensity as a string 
# of hexidecimal values
proc ::contactmap::chooseColor {field intensity} {
  variable dataName

  set field_color_type 4 
  #hack to sefault to struct field type coloring
  if {$dataName($field) != "struct"} {
    if {$intensity < 0} {set intensity 0}
    if {$intensity > 255} {set intensity 255}
    set intensity [expr {int($intensity)}]
    #set field_color_type $field 
    #check color mapping
    set field_color_type 3 
  }
  #super hacky here
  switch -exact $field_color_type {      
    #temporaily diable so greyscale color  only
    3333 {   
      set red $intensity
      set green [expr {255 - $intensity}]
      set blue 150 
    }
    4 {
      #the field_color_type hack sends all structs to here 
      if {
          [catch {
            switch $intensity {
              
              B {set red 180; set green 180; set blue 0}
              C {set red 255; set green 255; set blue 255}
              E {set red 255; set green 255; set blue 100}
              T {set red 70; set green 150; set blue 150}
              G {set red 255; set green 160; set blue 255}
              H {set red 225; set green 130; set blue 225}
              I {set red 225; set green 20; set blue 20}
              default {set red 100; set green 100; set blue 100}
            }
          } ] 
        } else { #badly formatted file, intensity may be a number
          set red 0; set green 0; set blue 0 
        } 
    }
    default {
      #set red [expr {200 - int (200.0 * ($intensity / 255.0) )}]
      #set green $red
      #set red 140; set blue 90; set green 90;
      set red $intensity
      set green $intensity
      set blue $intensity
    }
  }
  #convert red blue green 0 - 255 to hex
  set hexcols [format "\#%02x%02x%02x" $red $green $blue]

  return $hexcols
}


# Redraw all canvases
proc ::contactmap::redraw {name func op} {
  variable w 
  variable x1 
  variable y1 
  variable xcanwindowmax 
  variable ycanwindowmax 
  variable xcanmax 
  variable ycanmax
  variable ybox 
  variable xsize 
  variable ysize 
  variable scalex 
  variable scaley 
  variable dataValA 
  variable dataValANum 
  variable dataName 
  variable dataNameLast 
  variable ytopmargin 
  variable ybottommargin 
  variable xcol 
  variable dataWidth 
  variable firstData 
  variable dataMin 
  variable dataMax 
  variable usableMolLoaded
  variable rectCreated
  variable prevScalex
  variable prevScaley
  variable numHoriz

  if { ($usableMolLoaded) && ($dataValANum >=0 ) } {
    set ysize [expr {$ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValANum + 1) )}]  
    set xsize [expr {$xcol($firstData) +  ($scalex *  $dataWidth * (2 + $numHoriz) )}]
    set ycanmax(data) $ysize
    set xcanmax(data) $xsize
    if {$ycanmax(data) < $ycanwindowmax} {
      set ycanmax(data) $ycanwindowmax
    }

    if {$xcanmax(data) < $xcanwindowmax} {
      set xcanmax(data) $xcanwindowmax
    }

    set prevScrollRegion [$w.cfr.can cget -scrollregion]
    $w.cfr.can configure -scrollregion "0 0 $xcanmax(data) $ycanmax(data)"
    $w.cfr.vertScale configure -scrollregion "0 0 $xcanmax(vert) $ycanmax(data)"
    $w.cfr.horzScale configure -scrollregion "0 0 $xcanmax(data) $ycanmax(horz)"
    drawVertScale
    drawHorzScale
    set fieldLast  $dataNameLast
    #verbose "fieldLast is $dataNameLast"
    #temporary, until put multi-cols in
   
    if {! $rectCreated} {
      # The data has not been drawn, so draw it

      $w.cfr.vertScale delete yScalable
      $w.cfr.can delete dataScalable
      #verbose "drawing rects, scalex is $scalex"
      #hack here -- for now skip B-field stuff, so minimal stuff drawn
      verbose "setting min/max, firstData= $firstData"

      # Draw the canvas 
      for {set field  $firstData}  {$field <= $fieldLast} {incr field} {
        set intensity 0
        for {set yPos 0} {$yPos < $dataValANum} {incr yPos} { 
          set val $dataValA($field,$yPos)
          if {$val != "null"} {
            #calculate color and create rectange
            #set intensity except if field 4 (indexed struct)
            if {$dataName($field) != "struct"} {
              set range [expr {$dataMax($field) - $dataMin($field)}]
              if { ($range > 0)  && ([string is double $val] )} {
                set intensity  [expr {int (255 * ( ($val - $dataMin($field) ) / $range))}]
              }
              
              set hexcols [chooseColor $field $intensity]
            } else {
              set hexcols [chooseColor $field $val ]
            }

            #draw data rectangle
            set xPosFieldLeft [expr {$field - $firstData}]
            set xPosFieldRight [expr {$xPosFieldLeft + 1}]
            set yPosBottom [expr {$yPos + 1}]
            $w.cfr.can create rectangle \
              $xPosFieldLeft $yPos $xPosFieldRight $yPosBottom  \
              -fill $hexcols -outline "" -tags dataScalable
          }
        }
      }

      drawVertHighlight
      #drawHorizHighlight

      # Scale the canvas to the proper width
      $w.cfr.can scale dataScalable 0 0 \
        [expr {1.0 * $xcanmax(data) / ($fieldLast - $firstData)}] \
        [expr {1.0 * $ycanmax(data) / $dataValANum}]

    } else {
      # The data is drawn, simply rescale it to the proper dimensions
      $w.cfr.can scale dataScalable 0 0 \
        [expr {1.0 * $xcanmax(data) / [lindex $prevScrollRegion 2]}] \
        [expr {1.0 * $ycanmax(data) / [lindex $prevScrollRegion 3]}]
      #now for datarect
      $w.cfr.vertScale scale yScalable 0 0 1  [expr {$scaley / $prevScaley}]
    }
    
    set rectCreated 1
    set prevScaley $scaley
    set prevScalex $scalex
  }

  return
}


# Make all canvases 
proc ::contactmap::makecanvas {} {
  variable w
  variable xcanmax 
  variable ycanmax
  variable xsize
  variable ysize 
  variable xcanwindowmax 
  variable ycanwindowmax
  set xcanmax(data) $xsize 
  set ycanmax(data) $ysize

  scrollbar $w.cfr.ys -orient vertical \
    -command [namespace code {canvasScrollY}]
  scrollbar $w.cfr.xs -orient horizontal \
    -command [namespace code {canvasScrollX}]

  canvas $w.cfr.can -width [expr {$xcanwindowmax}] -height $ycanwindowmax \
    -xscrollcommand "$w.cfr.xs set" -yscrollcommand "$w.cfr.ys set" \
    -scrollregion  "0 0 $xcanmax(data) $ycanmax(data)" -relief flat -bd 0
  ##TODO? uncomment to enable auto-resizing
  #canvas $w.cfr.can -width [expr {$xcanwindowmax}] -height $ycanwindowmax \
  # -xscrollcommand [namespace code dataCanvasScrollX] \
  # -yscrollcommand [namespace code dataCanvasScrollY] \
  # -scrollregion  "0 0 $xcanmax(data) $ycanmax(data)" 

  canvas $w.cfr.vertScale -width $xcanmax(vert) -height $ycanwindowmax \
    -bg "#3FB6BF" -relief sunken -bd 2 -yscrollcommand "$w.cfr.ys set" \
    -scrollregion "0 0 $xcanmax(vert) $ycanmax(data)" 
  canvas $w.cfr.horzScale -width $xcanwindowmax -height  $ycanmax(horz) \
    -bg "#3FB6BF" -relief sunken -bd 2 -xscrollcommand "$w.cfr.xs set" \
    -scrollregion "0 0 $xcanmax(data) $ycanmax(horz)" 

  # Place the canvases and scrollbars in a grid
  grid $w.cfr.ys \
    -row 0 -column 0 -sticky ns
  grid $w.cfr.vertScale \
    -row 0 -column 1 -sticky ns
  grid $w.cfr.can \
    -row 0 -column 2 -sticky nsew
  grid $w.cfr.horzScale \
    -row 1 -column 2 -sticky ew
  grid $w.cfr.xs \
    -row 2 -column 2 -sticky ew
  grid columnconfigure $w.cfr 2 -weight 1
  grid rowconfigure $w.cfr 0 -weight 1

  bind $w.cfr.can <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 data}]
  bind $w.cfr.can <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 data}]
  bind $w.cfr.can <ButtonPress-2>  [namespace code {showPair %x %y 0 data}]
  bind $w.cfr.can <B1-Motion>  [namespace code {keepMovingMarquee %x %y data}]
  bind $w.cfr.can <B2-Motion>  [namespace code {showPair %x %y 0 data}]
  bind $w.cfr.can <ButtonRelease-1> [namespace code {letGoMarquee %x %y data}]

  bind $w.cfr.vertScale <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 vert}]
  bind $w.cfr.vertScale <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 vert}]
  bind $w.cfr.vertScale <ButtonPress-2>  [namespace code {showPair %x %y 0 vert}]
  bind $w.cfr.vertScale <B1-Motion>  [namespace code {keepMovingMarquee %x %y vert}]
  bind $w.cfr.vertScale <B2-Motion>  [namespace code {showPair %x %y 0 vert}]
  bind $w.cfr.vertScale <ButtonRelease-1> [namespace code {letGoMarquee %x %y vert}]

  bind $w.cfr.horzScale <ButtonPress-1>  [namespace code {getStartedMarquee %x %y 0 horz}]
  bind $w.cfr.horzScale <Shift-ButtonPress-1>  [namespace code {getStartedMarquee %x %y 1 horz}]
  bind $w.cfr.horzScale <ButtonPress-2>  [namespace code {showPair %x %y 0 horz}]
  bind $w.cfr.horzScale <B1-Motion>  [namespace code {keepMovingMarquee %x %y horz}]
  bind $w.cfr.horzScale <B2-Motion>  [namespace code {showPair %x %y 0 horz}]
  bind $w.cfr.horzScale <ButtonRelease-1> [namespace code {letGoMarquee %x %y horz}]
}

# XXX - ?
proc ::contactmap::reconfigureCanvas {} {
  variable w
  variable xcanmax
  variable ycanmax
  variable xcanwindowmax 
  variable ycanwindowmax
  variable xcanwindowStarting

  #in future, add to xcanwindowstarting if we widen window
  set xcanwindowmax  $xcanwindowStarting 

  #check if can cause trouble if no mol loaded...
  $w.cfr.can configure  -height $ycanwindowmax -width $xcanwindowmax 
  $w.cfr.horzScale configure  -height $ycanmax(horz) -scrollregion "0 0 $xcanmax(data) $ycanmax(horz)"

  $w.cfr.vertScale configure  -width $xcanmax(vert) -scrollregion "0 0 $xcanmax(vert) $ycanmax(data)" 
  $w.cfr.horzScale delete all
  $w.cfr.vertScale delete all
  $w.cfr.can delete all
}

# Highlight the selected residues after making a selection
proc ::contactmap::drawVertHighlight  {} {
  variable w 
  variable dataValA 
  variable dataValANum 
  variable ytopmargin 
  variable scaley
  variable ybox  
  variable currentMolA 
  variable rep 
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

  for {set i 0} {$i<=$dataValANum} {incr i} {
    if  {$dataValA(picked,$i) == 1} {
      set ypos [expr {$ytopmargin+ ($scaley * $i *$ybox)}]
      
      
      #draw highlight only if not yet drawn -- if rectCreated is 0, we may  just cleared the rects
      #     to redraw free of accumulated scaling errors
      if {($dataValA(pickedId,$i) == "null") || ($rectCreated == 0)} {

        set dataValA(pickedId,$i)  [$w.cfr.vertScale create rectangle  $vertHighLeft $ypos $vertHighRight [expr {$ypos + ($scaley * $ybox)}]  -fill $highlightColorString -outline "" -tags yScalable]
        
        
        $w.cfr.vertScale lower $dataValA(pickedId,$i) vertScaleText 
        
      }
      
    }
  }

  set ll [makeSelText dataValA  $dataValANum 1]

  
  if {($rep($currentMolA) != "null")} {

    if { [expr {[molinfo $currentMolA get numreps] - 1}] >= $rep($currentMolA) } {

      mol modselect $rep($currentMolA) $currentMolA $ll
    } else {
      createHighlight  rep currentMolA  $ll 11  
    }
  } else {
    createHighlight  rep currentMolA $ll 11  
  }

  return
}


# Atom pick callback
proc ::contactmap::list_pick {name element op} {
  global vmd_pick_atom 
  global vmd_pick_mol 
  global vmd_pick_shift_state  

  variable w 
  variable ycanwindowmax
  variable ybox
  variable ytopmargin 
  variable scaley 
  variable dataValA 
  variable dataValANum 
  variable ysize 
  variable currentMolA
  # get the coordinates

  #XXX - later deal with top (and rep)  etc. for multi-mol use
  
  if {$vmd_pick_mol == $currentMolA} {
    set sel [atomselect $currentMolA "index $vmd_pick_atom"]
    
    set pickedresid [lindex [$sel get {resid}] 0] 
    set pickedchain  [lindex [$sel get {chain}] 0] 
    set pickedresname [lindex  [$sel get {resname}] 0]
    
    set pickedOne -1
    for {set i 0} {$i <= $dataValANum} {incr i} {
      
      if {($dataValA(0,$i) == $pickedresid) && ($dataValA(1,$i) == $pickedresname) &&  ($dataValA(2,$i) == $pickedchain)} {
        set pickedOne $i
        
        break
      }
    }
    
    if {$pickedOne >= 0} {
      set ypos [expr {$ytopmargin+ ($scaley * $i *$ybox)}]
      
      #do bitwise AND to check for shift-key bit
      if {$vmd_pick_shift_state & 1} {
        set shiftPressed 1
      } else {
        set shiftPressed 0
      }
      
      if {$shiftPressed == 0 } {
        #delete all from canvas

        for {set i 0} {$i <= $dataValANum} {incr i} {
          set dataValA(picked,$i) 0
          if {$dataValA(pickedId,$i) != "null"} {
            $w.cfr.can delete $dataValA(pickedId,$i)
            set dataValA(pickedId,$i) "null"
          }
        }
      }
      
      set dataValA(picked,$pickedOne) 1
      
      drawVertHighlight 
      #drawHorizHighlight  
      
      #scroll to picked
      set center [expr {$ytopmargin + ($ybox * $scaley * $pickedOne)}] 
      set top [expr {$center - 0.5 * $ycanwindowmax}]
      
      if {$top < 0} {
        set top 0
      }
      set yfrac [expr {$top / $ysize}]
      $w.cfr.can yview moveto $yfrac
    }
    
  }
  return
}


# Find info for both molecules
proc ::contactmap::updateResData {} {
  variable repPairA
  variable currentMolA
  variable currentMolA_name 
  variable dataValA
  variable dataValANum
  variable dataHashA
  variable selTextA
  variable repPairB
  variable currentMolB
  variable currentMolB_name 
  variable dataValB
  variable dataValBNum
  variable dataHashB
  variable selTextB

  findResData repPairA currentMolA currentMolA_name dataValA dataValANum dataHashA $selTextA
  findResData repPairB currentMolB currentMolB_name dataValB dataValBNum dataHashB $selTextB
}


# Store molecule info in appropriate data structures
proc ::contactmap::findResData {rPair cMol cMol_name dVal dValNum dHash selectionText} {
  variable rep

  upvar $rPair repPair $cMol currentMol $cMol_name currentMol_name $dVal dataVal $dValNum dataValNum $dHash dataHash 
  set dataValNum -1 
  set currentMol_name [molinfo $currentMol get name]
  set sel [atomselect $currentMol "$selectionText and name CA"]
  #set sel [atomselect $currentMol "resid 1 to 15  and name CA"]
  #below assumes sel retrievals in same order each time, fix this 
  #by changing to one retreival and chopping up result
  set datalist  [$sel get {resid resname chain}]
  verbose "Checking sequence info. for molecule $currentMol..."
  
  #clear this dataHash
  catch {unset dataHash}

  #the upvar'd dataHash is set again below, and reappears in the namespace.  
  foreach elem $datalist {
    #set picked state to false -- 'picked' is only non-numerical field
    incr dataValNum
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
  set repPair($currentMol) "null"
  
  if {$dataValNum <= -1 } {
    #verbose "Couldn't find a sequence in this molecule.\n"
    return
  }
  unset datalist
  verbose "dataValNum = $dataValNum"
} 


# Set up the contact map
proc ::contactmap::contactmapMain {} {
  #------------------------
  #------------------------
  # main code starts here
  #vars initialized a few lines down

  #verbose "in contactmapMain.."
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
  variable dataValA 
  variable dataValB 
  variable dataHashA
  variable dataHashB
  variable rectId
  #dataValANum is -1 if no data present, 
  variable dataValANum 
  variable dataValBNum 
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
  variable currentMolA
  variable currentMolA_name
  variable currentMolB
  variable currentMolB_name
  variable fit_scalex
  variable fit_scaley
  variable usableMolLoaded 
  variable initializedVars
  variable prevScalet
  variable rectCreated
  variable windowShowing
  variable needsDataUpdate 
  variable numHoriz
  variable selTextA
  variable selTextB
  variable pairVal
  variable repPairA
  variable repPairB

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
    #this sets a trace for ::contactmap::scaley
    
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
    
    #lets fill  a (dataNameLast +1 ) x (dataValANum +1) array
    #dataValANum we'll be the number of objects we found with VMD search
    #if doing proteins, liekly all residues, found with 'name CA'
    
    set dataValANum -1
    set dataValBNum -1 
    #if no data is available, dataValANum will remain -1  

    updateResData

    wm title $w "VMD Seq Compare: $currentMolA_name (mol $currentMolA)   $currentMolB_name (mol $currentMolB)"
    #So dataValANum is number of the last dataValA.  It is also #elements -1, 
    
    #numHoriz (and routines that use it)  will eventualy be changed
    # to reflect loaded data, and  multi-frame-data groups
    set numHoriz $dataValBNum 
    
    set fit_scalex [expr {(0.0 + $xcanwindowmax - $xcol($firstData) ) / ($dataWidth * (2 + $numHoriz) )}]
    set fit_scaley [expr {(0.0 + $ycanwindowmax - $ytopmargin - $ybottommargin) / ($ybox * ($dataValANum + 1) )}]
    #since we zero-count.

    set scaley 1.0
    set scalex $fit_scalex 
    verbose "Restarting data, scalex = $scalex"
    #this trace only set if dataValANum != -1

    #Other variable-adding methods
    #should not change this number.  We trust $selA to always
    #give dataValANum elems, other methods might not work as well.
    #if need this data, recreate sel.  
    
    #handle if this value is 0 or -1
    
    #now lets fill in some data
    
    #new data, so need to redraw rects when time comes
    set rectCreated 0 
    #also set revScaley back to 1 
    set prevScaley scaley
    set prevScalex scalex 

    #XXX - don't calculate distance during initialization
    #fill in traj data with res-res position 
    #calcDataDist
  }

  #get min/max of some data
  
  #verbose "time for first redraw, scales, min/max not calced"
  #redraw first time
  redraw name func ops
  
  #now draw the scales (after the data, we may need to extract min/max 

  #------
  #draw color legends, loop over all data fields
  set fieldLast  $dataNameLast
  #verbose "dataName(0) is $dataName(0) dataName(1) is $dataName(1)"
  
  return
}


# Create/update the molecule menus with the list of currently loaded
# molecules.  A trace on vmd_initialize_structure calls this whenever a
# molecule is loaded or deleted.
proc ::contactmap::molChooseMenu {name function op} {
  variable w
  variable usableMolLoaded
  variable currentMolA
  variable currentMolB
  variable prevMolA
  variable prevMolB
  variable nullMolString

  $w.cp.mols.menuA.molA.menu delete 0 end
  $w.cp.mols.menuB.molB.menu delete 0 end

  set molList ""
  foreach mm [molinfo list] {
    if {[molinfo $mm get filetype] != "graphics"} {
      lappend molList $mm
      #add a radiobutton, but control via commands, not trace,
      #since if this used a trace, the trace's callback
      #would delete that trace var, causing app to crash.
      #variable and value only for easy button lighting
      $w.cp.mols.menuA.molA.menu add radiobutton \
        -variable [namespace current]::currentMolA -value $mm \
        -label "$mm [molinfo $mm get name]"
      $w.cp.mols.menuB.molB.menu add radiobutton \
        -variable [namespace current]::currentMolB -value $mm \
        -label "$mm [molinfo $mm get name]"
    }
  }

  #set if any non-Graphics molecule is loaded
  if {$molList == ""} {
    set usableMolLoaded  0
    if {$prevMolA != $nullMolString} {
      set currentMolA $nullMolString
      set currentMolB $nullMolString
    }
  } else {
    # Deal with first (or from-no mol state) mol load.
    set usableMolLoaded 1

    # Handle the deletion of the selected molecule
    if {[lsearch -exact $molList $currentMolB] == -1} {
      set currentMolB [molinfo top]
    }
    if {[lsearch -exact $molList $currentMolA] == -1} {
      set currentMolA [molinfo top]
    }
  }

  return
}

# Write the contact map to a file
proc ::contactmap::printCanvas {} {
  variable w
  #extract first part of molecule name to print here?
  set filename "VMD_Contactmap_Window.ps"
  set filename [tk_getSaveFile -initialfile $filename -title "VMD Contactmap Print" -parent $w -filetypes [list {{Postscript Files} {.ps}} {{All files} {*} }] ]
  if {$filename != ""} {
    $w.cfr.can postscript -file $filename
  }
  
  return
}

# Called when the user begins making a selection, draws the rectangle
proc ::contactmap::getStartedMarquee {x y shiftState whichCanvas} {
  variable w 
  variable x1 
  variable y1 
  variable so
  variable eo 
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
      data {set drawCan $w.cfr.can}
      vert {set drawCan $w.cfr.vertScale}
      horz {set drawCan $w.cfr.horzScale}
      default {puts "problem with finding canvas..., startCanvas= >$startCanvas<"} 
    }   
    set x [expr {$x + $xcanmax($startCanvas) * [lindex [$drawCan xview] 0]}] 
    set y [expr {$y + $ycanmax($startCanvas) * [lindex [$drawCan yview] 0]}] 
    
    set x1 $x
    set y1 $y
    
    verbose "getStartedMarquee x= $x  y= $y, startCanvas= $startCanvas" 
    #Might have other canvas tools in future..   
    # Otherwise, start drawing rectangle for selection marquee
    
    set so [$drawCan create rectangle $x $y $x $y -fill {} -outline red]
    set eo $so
  } 
  return
}

# Update display when a new molecule is selected in the drop-down menu
proc ::contactmap::molChoose {name function op} {
  variable w
  variable scaley
  variable currentMolA
  variable prevMolA
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
  if {($usableMolLoaded)  && ($prevMolA != $nullMolString) && ($rep($prevMolA) != "null")} {

    #catch this since currently is exposed to user, so 
    #switching/reselecting  molecules can fix problems.
    verbose "About to delete rep=$rep($prevMolA) for prevMolA= $prevMolA"
    #determine if this mol exists...
    if  {[lsearch -exact [molinfo list] $prevMolA] != -1}  {
      #determine if this rep exists (may have been deleted by user)
      if { [expr {[molinfo $prevMolA get numreps] - 1}] >= $rep($prevMolA) } { 
        
        mol delrep $rep($prevMolA) $prevMolA 
      }
    }
    
  }

  set prevMolA $currentMolA

  #can get here when window is not displayed if:
  #   molecule is loaded, other molecule delete via Molecule GUI form.
  # So, we'll only redraw (and possible make a length (wallclock) call
  # to STRIDE) if sequence window is showing
  
  set needsDataUpdate 1

  if {$windowShowing} {
    set needsDataUpdate 0
    #set this immediately, so other  calls can see this
    
    [namespace current]::contactmapMain
  }
  
  #reload/redraw stuff, settings (this may elim. need for above lines...)
  
  #change molecule choice and redraw if needed (visible && change) here...
  #change title of window as well
  ##wm title $w "VMD Contactmap  $currentMolA_name (mol $currentMolA) "
  
  #reload sutff (this may elim. need for above lines...)

  return
}

# Draw the selection rectangle when the mouse is dragged.
proc ::contactmap::keepMovingMarquee {x y whichCanvas} {
  variable w 
  variable x1 
  variable y1 
  variable so 
  variable xcanmax 
  variable ycanmax
  variable startCanvas
  variable usableMolLoaded

  #get actual name of canbas
  switch -exact $startCanvas {
    data {set drawCan $w.cfr.can}
    vert {set drawCan $w.cfr.vertScale}
    horz {set drawCan $w.cfr.horzScale}
    default {puts "problem with finding canvas (moving marquee)..., startCanvas= $startCanvas"}
  } 
  
  if {$usableMolLoaded} {
    #next two lines for debeugging only
    set windowx $x
    set windowy $y 
    #calculate offset for canvas scroll
    set x [expr {$x + $xcanmax($startCanvas) * [lindex [$drawCan xview] 0]}] 
    set y [expr {$y + $ycanmax($startCanvas) * [lindex [$drawCan yview] 0]}] 
    
    $drawCan coords $so $x1 $y1 $x $y
  }
  return
}

# Clear the selection rectangle, and highlight the selected residues.
proc ::contactmap::letGoMarquee {x y whichCanvas} {
  variable w 
  variable x1 
  variable y1 
  variable startShiftPressed 
  variable startCanvas
  variable eo 
  variable xcanmax
  variable ycanmax
  variable ySelStart 
  variable ySelFinish 
  variable ybox 
  variable ytopmargin 
  variable vertTextSkip 
  variable scalex 
  variable scaley 
  variable dataValA 
  variable dataValANum 
  variable xcol
  variable usableMolLoaded
  variable firstData
  variable dataWidth 
  variable numHoriz
  variable firstStructField

  #set actual name of canvas
  switch -exact $startCanvas {
    data {set drawCan $w.cfr.can}
    vert {set drawCan $w.cfr.vertScale}
    horz {set drawCan $w.cfr.horzScale}
    default {puts "problem with finding canvas (moving marquee)..., startCanvas= $startCanvas"}
  }

  if {$usableMolLoaded} {
    #calculate offset for canvas scroll
    set x [expr {$x + $xcanmax(data) * [lindex [$drawCan xview] 0]}] 
    set y [expr {$y + $ycanmax(data) * [lindex [$drawCan yview] 0]}] 

    #compute the residue at xSelStart
    if {$x1 < $x} {
      set xSelStart $x1
      set xSelFinish $x
    }  else {
      set xSelStart $x
      set xSelFinish $x1
    }
    verbose "xSelStart is $xSelStart xSelFinish is $xSelStart" 
    
    #in initVars we hardcode firstStructField to be 4
    #later, there may be many field-groups that can be stretched 
    set xPosStructStart [expr {int ($xcol($firstData) + ($dataWidth * ($firstStructField - $firstData) ) )}] 

    set selStartHoriz [expr {int (($xSelStart - $xcol($firstData))/ ($dataWidth * $scalex)) - 1}]
    set selFinishHoriz [expr {int( ($xSelFinish - $xcol($firstData))/ ($dataWidth * $scalex) ) - 1}]
    if { $selFinishHoriz> $numHoriz} {
      set selFinishHoriz $numHoriz
    }
    verbose "selected x residues $selStartHoriz to $selFinishHoriz"

    if {$y1 < $y} {
      set ySelStart $y1
      set ySelFinish $y
    }  else {
      set ySelStart $y
      set ySelFinish $y1
    }
    
    set startObject [expr {0.0 + ((0.0 + $ySelStart - $ytopmargin) / ($scaley * $ybox))}]
    set finishObject [expr {0.0 + ((0.0 + $ySelFinish - $ytopmargin) / ($scaley * $ybox))}]
    
    if {$startShiftPressed == 1} {
      set singleSel 0
    } else {
      set singleSel 1
    }
    
    if {$startObject < 0} {set startObject 0}
    if {$finishObject < 0} {set finishObject 0}
    if {$startObject > $dataValANum} {set startObject   $dataValANum }
    if {$finishObject > $dataValANum} {set finishObject $dataValANum }
    set startObject [expr {int($startObject)}]
    set finishObject [expr {int($finishObject)}]
    verbose "selected y residues $startObject to $finishObject" 
    
    #clear all if click/click-drag, don't clear if shift-click, shift-click-drag
    
    if {$singleSel == 1} {
      for {set i 0} {$i <= $dataValANum} {incr i} {
        set dataValA(picked,$i) 0
        if {$dataValA(pickedId,$i) != "null"} {
          $w.cfr.vertScale delete $dataValA(pickedId,$i)
          set dataValA(pickedId,$i) "null"
        }
      }

    } else {
      #just leave alone  
    }
    
    #set flags for selection
    for {set i $startObject} {$i <= $finishObject} {incr i} {
      set dataValA(picked,$i) 1
    }
    
    set field 0
    #note that the column will be 0, but the data will be from picked
    
    drawVertHighlight 
    #drawHorizHighlight  
    
    verbose "now to delete outline, eo= $eo" 
    $drawCan delete $eo
  }
  return
}


# Draw the entire range of residues in MoleculeA
proc ::contactmap::showall { do_redraw} {
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
    set userScaley $fit_scaley 

    redraw name func ops
  }

  return
}


# Draw one line per residue in MoleculeA
proc ::contactmap::every_res {} {
  variable usableMolLoaded
  variable rectCreated
  variable fit_scalex

  #this forces redraw, to cure any scaling floating point errors
  #that have crept in 
  #XXX - get rid of this
  #set rectCreated 0

  variable scaley
  variable scalex

  if {$usableMolLoaded} {
    #redraw, set x and y  at once
    set scalex 1.0
    set scaley 1.0
    redraw name func ops
  }
  
  return
}

# Toggle between one- and three-character residue names in display
proc ::contactmap::resname_toggle {} {
  variable w 
  variable amino_code_toggle
  variable usableMolLoaded
  
  if {$usableMolLoaded} {
    if {$amino_code_toggle == 0} {
      set amino_code_toggle 1
      $w.cp.disp.resname_toggle configure -text "3-letter code"
    } else {
      set amino_code_toggle 0
      $w.cp.disp.resname_toggle configure -text "1-letter code"
    }
    
    redraw name function op
  }
  return
}


# Initialize the variables
proc ::contactmap::initVars {} {
  variable verboseChannel {}
  variable usableMolLoaded 0
  variable windowShowing 0
  variable needsDataUpdate 0
  variable dataNameLast 2
  variable dataValANum -1
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
  variable currentMolA $nullMolString
  variable currentMolB $nullMolString
  variable prevMolA $nullMolString
  variable prevMolB $nullMolString

  variable userScalex 1
  variable userScaley 1
  variable scalex 1
  variable scaley 1
  variable prevScalex 1
  variable prevScaley 1
  
  variable ytopmargin 5
  variable ybottommargin 10
  variable xrightmargin 8

  #variable xcanwindowStarting 780 
  variable xcanwindowStarting 685 
  variable ycanwindowStarting 574 

  variable numHoriz 1
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
  variable selTextA "all"
  variable selTextB "all"
  variable pairTextA "Residue:"
  variable pairTextB "Residue:"
  variable pairVal "Distance:"
  variable xScaling 0 
  variable yScaling 0 
  #hard coded, should change
  variable firstStructField 4
  variable alignIndex
  set alignIndex(num) 0

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

  variable dataWidth 85
  variable dataMargin 0
  variable xPosScaleVal 32
  #so rectangge of data is drawn at width $dataWidth - $dataMargin (horizontal measures)
  #
  #residu name data is in umbered entires lowerthan 3
  variable firstData 3
  #verbose "firstData is $firstData"
  #column that multi-col data first  appears in

  set xcol($firstData)  1 
  #The 4th field (field 3) is the "first data field"
  #we use same data structure for labels and data, but now draw in separate canvases 
 
  # the names for  three fields of data 
  
  #just for self-doc
  # dataValA(picked,n) set if the elem is picked
  # dataValA(pickedId,n) contains the canvas Id of the elem's highlight rectangle
  
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


proc ::contactmap::Show {} {
  variable windowShowing
  variable needsDataUpdate

  set windowShowing 1
  
  if {$needsDataUpdate} {
    set needsDataUpdate 0
    #set immmediately, so other binding callbacks will see
    [namespace current]::contactmapMain
  }
}
proc ::contactmap::Hide {} {
  variable windowShowing 
  set windowShowing 0
}

# Draw a rep to highlight the selected residue
proc ::contactmap::createHighlight { theRep theCurrentMol seltext col} {
  variable bond_rad
  variable bond_res

  upvar $theRep rep $theCurrentMol currentMol 

  #draw first selection, as first residue 
  set rep($currentMol) [molinfo $currentMol get numreps]
  mol selection $seltext
  mol material Opaque
  mol color ColorID $col 
  mol addrep $currentMol
  mol modstyle $rep($currentMol)  $currentMol  Bonds $bond_rad $bond_res
}


# Create the non-canvas portions of the GUI
proc ::contactmap::draw_interface {} {
  variable w 
  variable ycanwindowmax 
  variable ybox 
  variable xsize 
  variable ysize 
  variable sel 
  variable userScalex
  variable userScaley
  variable scalex 
  variable scaley 
  variable dataValANum 
  variable ytopmargin 
  variable ybottommargin 
  variable xcol 
  variable dataWidth 
  variable firstData 
  variable currentMolA
  variable numHoriz 
  variable selTextA
  variable selTextB
  variable pairTextA
  variable pairTextB
  variable pairVal

  ## Menu Bar start
  frame $w.menubar -height 30 -relief raised -bd 2

  # File menu
  menubutton $w.menubar.file -text File -underline 0 -menu $w.menubar.file.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.file config -width 5

  menu $w.menubar.file.menu -tearoff no
  $w.menubar.file.menu add command -label "Print to file..." -command [namespace code {printCanvas} ] 

##
## XXX These are broken currently, so hide them from the user
##
#  $w.menubar.file.menu add command -label "Load data file..." -command [namespace code {loadDataFile ""}  ] 
#  $w.menubar.file.menu add command -label "Write data file..." -command [namespace code {writeDataFile ""}  ] 

  pack $w.menubar.file -side left

  # Calculate menu
  menubutton $w.menubar.calculate -text Calculate -underline 0 -menu $w.menubar.calculate.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.calculate config -width 10

  menu $w.menubar.calculate.menu  -tearoff no
  $w.menubar.calculate.menu add command -label "Clear data" \
    -command [namespace code clearData]
  $w.menubar.calculate.menu add command -label "Calc. res-res Dists" \
    -command [namespace code {calcDataDist; showall 1}]
  
  pack $w.menubar.calculate -side left

  # Help menu
  menubutton $w.menubar.help -text Help -underline 0 -menu $w.menubar.help.menu

  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "Contactmap Help" \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/contactmap"
  $w.menubar.help.menu add command -label "Structure codes..." \
    -command  [namespace code {tk_messageBox -parent $w  -type ok -message "Secondary Structure Codes\n\nT        Turn\nE        Extended conformation\nB        Isolated bridge\nH        Alpha helix\nG        3-10 helix\nI         Pi-helix\nC        Coil (none of the above)\n" } ]

  pack $w.menubar.help -side right 

  pack $w.menubar -side top -anchor nw -padx 1 -fill x
  ## Menu Bar end

  ## Control Panel begin
  frame $w.cp

  frame $w.cp.zoom
  scale $w.cp.zoom.zoomBothlevel -orient horizontal -from 0.001 -to 4.000 \
    -resolution 0.001 -tickinterval 3.999 -repeatinterval 30 -showvalue true \
    -variable [namespace current]::userScaleBoth -label "Zoom All" \
    -command [namespace code userScaleBothChanged] 

  scale $w.cp.zoom.zoomXlevel -orient horizontal -from 0.001 -to 40.000 \
    -resolution 0.001 -tickinterval 39.999 -repeatinterval 30 -showvalue true \
    -variable [namespace current]::userScalex -label "Zoom X"\
    -command [namespace code userScalexChanged] 
  pack $w.cp.zoom.zoomBothlevel $w.cp.zoom.zoomXlevel \
    -side top -anchor w -fill x
  pack $w.cp.zoom -side top -padx 5 -pady 5 -fill x

  frame $w.cp.mols
  frame $w.cp.mols.menuA
  label $w.cp.mols.menuA.molLabA -text "Molecule A:"
  menubutton $w.cp.mols.menuA.molA -relief raised -bd 2 -direction flush \
    -textvariable [namespace current]::currentMolA \
    -menu $w.cp.mols.menuA.molA.menu
  menu $w.cp.mols.menuA.molA.menu -tearoff no
  pack $w.cp.mols.menuA.molLabA $w.cp.mols.menuA.molA -side left

  entry $w.cp.mols.selA -text "all" -textvariable [namespace current]::selTextA
  label $w.cp.mols.selTextA -anchor w \
    -textvariable [namespace current]::pairTextA

  frame $w.cp.mols.menuB
  label $w.cp.mols.menuB.molLabB -text "Molecule B:"
  menubutton $w.cp.mols.menuB.molB -relief raised -bd 2 -direction flush \
    -textvariable [namespace current]::currentMolB -menu $w.cp.mols.menuB.molB.menu
  menu $w.cp.mols.menuB.molB.menu -tearoff no
  pack $w.cp.mols.menuB.molLabB $w.cp.mols.menuB.molB -side left

  entry $w.cp.mols.selB -text "all" -textvariable [namespace current]::selTextB
  label $w.cp.mols.selTextB -anchor w \
    -textvariable [namespace current]::pairTextB

  label $w.cp.mols.pair -anchor w \
    -textvariable [namespace current]::pairVal
  pack $w.cp.mols.menuA $w.cp.mols.selA $w.cp.mols.selTextA \
   $w.cp.mols.menuB $w.cp.mols.selB $w.cp.mols.selTextB $w.cp.mols.pair \
   -side top -anchor w -fill x
  pack $w.cp.mols -side top -padx 5 -pady 5 -fill x

  frame $w.cp.zoomY
  scale $w.cp.zoomY.zoomlevel -from 0.01 -to 2.01 \
    -resolution 0.01 -tickinterval 0.5 -repeatinterval 30 -showvalue true \
    -variable [namespace current]::userScaley -label "Zoom Y" \
    -command [namespace code userScaleyChanged]
  pack $w.cp.zoomY.zoomlevel \
    -side top -anchor n -fill y -expand yes
  pack $w.cp.zoomY -side top -padx 5 -pady 5 -fill both -expand yes

  frame $w.cp.fit
  button $w.cp.fit.showall  -text "fit all" \
    -command [namespace code {showall 0}]
  button $w.cp.fit.every_res  -text "every residue" \
    -command [namespace code every_res]
  pack $w.cp.fit.showall $w.cp.fit.every_res \
    -side top -anchor w -fill x
  pack $w.cp.fit -side top -padx 5 -pady 5 -fill x

  frame $w.cp.disp
  button $w.cp.disp.resname_toggle  -text "1-letter code" \
    -command [namespace code resname_toggle]
  pack $w.cp.disp.resname_toggle \
    -side top -anchor w -fill x
  pack $w.cp.disp -side top -padx 5 -pady 5 -fill x

  pack $w.cp -side left -padx 2 -pady 2 -expand no -fill y
  ## Control Panel end

  ## Canvas Frame begin 
  frame $w.cfr -width 350

  set ysize [expr {$ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValANum + 1))}]    
  set xsize [expr {$xcol($firstData) + ($scalex *  $dataWidth * ($numHoriz))}]

  pack $w.cfr -side left -padx 2 -pady 2 -expand yes -fill both
  ## Canvas Frame end

  # Update the menu
  molChooseMenu name function op
  
  # turn traces  on (initialize_struct trace comes later)
  trace variable ::vmd_initialize_structure w  [namespace code molChooseMenu]
  trace variable ::vmd_pick_atom w [namespace code list_pick]
  trace variable currentMolA w [namespace code molChoose]
}


# Highlight the middle-clicked residues
proc  ::contactmap::showPair {x y shiftState whichCanvas} {
  variable w
  variable xcol
  variable firstData
  variable dataWidth
  variable scalex
  variable scaley
  variable dataValA
  variable dataValANum
  variable dataValB
  variable currentMolA
  variable currentMolB
  variable numHoriz
  variable xcanmax
  variable ycanmax
  variable ytopmargin
  variable ybox
  variable repPairA
  variable repPairB
  variable pairTextA
  variable pairTextB
  variable pairVal

  #XXX - should use same code as marquee checks!
  #maybe store top, and restore it afterwards
  set x [expr {$x + $xcanmax(data) * [lindex [$w.cfr.can xview] 0]}]
  set y [expr {$y + $ycanmax(data) * [lindex [$w.cfr.can yview] 0]}]
  set cursorXnum [expr {int (($x - $xcol($firstData))/ ($dataWidth * $scalex)) - 1}]
  set cursorYnum [expr {int (0.0 + ((0.0 + $y - $ytopmargin) / ($scaley * $ybox)))}]
  
  if {$cursorXnum> $numHoriz}  {
    set cursorXnum $numHoriz
  }
  
  if {$cursorXnum< 0 } { 
    set cursorXnum 0
  } 
  
  if {$cursorYnum>$dataValANum} {
    set cursorYnum $dataValANum
  }
  if {$cursorYnum < 0} {
    set cursorYnum 0 
  }

  set residA $dataValA(0,$cursorYnum)
  set chainA $dataValA(2,$cursorYnum)
  set residB $dataValB(0,$cursorXnum)
  set chainB $dataValB(2,$cursorXnum)
  if {[catch {set val  $dataValA([expr {$firstData+$cursorXnum}],$cursorYnum)}] } { 
    set pairVal "Distance:" 
  } else {
    set pairVal [format "Distance: %.02f" $val]
  }
  set seltextA "resid $residA and chain $chainA"
  set pairTextA "Residue: r $residA  ch $chainA"
  set seltextB "resid $residB and chain $chainB"
  set pairTextB "Residue: r $residB  ch $chainB"
  
  verbose "$cursorXnum $cursorYnum chainA= $chainA residA= $residA   chainB= $chainB residB= $residB" 

  #highlight resisdues in the graph

  #show the two involved residues in GL window
  if {($repPairA($currentMolA) != "null")} {

    if { [expr {[molinfo $currentMolA get numreps] - 1}] >= $repPairA($currentMolA) } {

      mol modselect $repPairA($currentMolA) $currentMolA $seltextA
    } else {
      createHighlight  repPairA currentMolA $seltextA 7 
    }
  } else {
    createHighlight repPairA currentMolA $seltextA 7 
  }
  
  if {($repPairB($currentMolB) != "null")} {

    if { [expr {[molinfo $currentMolB get numreps] - 1}] >= $repPairB($currentMolB) } {

      mol modselect $repPairB($currentMolB) $currentMolB $seltextB
    } else {
      createHighlight  repPairB currentMolB $seltextB 5 
    }
  } else {
    createHighlight repPairB currentMolB $seltextB 5 
  }
  
  return
}


##
## XXX This is broken currently, so hide it from the user
##
# Write the contact map data to a file
proc ::contactmap::writeDataFile {filename} {
  variable w
  variable dataName
  variable dataValA
  variable dataValANum
  variable currentMolA
  variable firstStructField
  variable numHoriz

  if {$filename == ""  } {
    set filename [tk_getSaveFile -initialfile $filename -title "Save Trajectory Da ta file" -parent $w -filetypes [list { {.dat files} {.dat} } { {Text files} {.txt}} {{All files} {*} }] ]
    set writeDataFile [open $filename w]
    puts $writeDataFile "# VMD sequence data"
    puts $writeDataFile "# CREATOR= $::tcl_platform(user)"
    puts $writeDataFile "# DATE= [clock format [clock seconds]]"
    puts $writeDataFile "# TITLE= [molinfo $currentMolA get name]"
    puts $writeDataFile "# NUM_FRAMES= $numHoriz "
    puts $writeDataFile "# FIELD= $dataName($firstStructField) "
    set endStructs [expr {$firstStructField + $numHoriz}]
    for {set field $firstStructField} {$field <= $endStructs} {incr field} {
      for {set i 0} {$i<=$dataValANum} {incr i} {

        set val $dataValA($field,$i)
        set resid $dataValA(0,$i)
        set chain $dataValA(2,$i)
        set frame [expr {$field - $firstStructField}]
        puts $writeDataFile "$resid $chain CA $frame $val"
      }
    }
    close $writeDataFile
  }
  return
}

# Calculate inter-residue distances
proc ::contactmap::calcDataDist {} {
  variable w
  variable dataNameLast
  variable dataName
  variable dataValA
  variable dataValANum
  variable currentMolA
  variable dataValBNum
  variable currentMolB
  variable dataMin
  variable dataMax
  variable firstData 
  variable selTextA 
  variable selTextB

  verbose "in calcDataDist, dataValANum= $dataValANum, dataValBNum= $dataValBNum"

  # Update data
  updateResData

  set selA [atomselect $currentMolA "$selTextA and name CA"]
  set selB [atomselect $currentMolB "$selTextB and name CA"]
  set coorListA [$selA get [list x y z] ]
  set coordListB [$selB get [list x y z] ]
  $selA delete
  $selB delete

  for {set indexA 0} {$indexA <= $dataValANum} {incr indexA} {
    set aCoord [lindex $coorListA $indexA]

    for {set indexB 0} {$indexB <= $dataValBNum} {incr indexB} {
      set bCoord [lindex $coordListB $indexB] 
      set diff [veclength [vecsub $bCoord $aCoord] ]
      set dataName([expr {$indexB+$firstData}]) "x-val"
      set dataValA([expr {$indexB+$firstData}],$indexA) $diff
      #verbose "aCoord= $aCoord, bCoord= $bCoord, diff= $diff, dataValA([expr {$indexB+$firstData}],$indexA)= $dataValA([expr {$indexB+$firstData}],$indexA)"
      #verbose "curDataName is $curDataName"
    }  
    set dataMin($indexA) 0 
    set dataMax($indexA) 10 
  }
  unset coorListA
  unset coordListB
  set dataNameLast $dataValBNum

  return
}

##
## XXX This is broken currently, so hide it from the user
##
# Load map from file
proc ::contactmap::loadDataFile {filename} {
  variable w
  variable dataValA
  variable dataHashA
  variable dataName
  variable firstStructField
  
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
        verbose "Loading file, field name is $commonName"
      } 
    }
  }
  #done with the file close it 
  close $dataFile
  #set frameList ""
  #data-containing frames
  foreach line $fileLines {
    #verbose "the line is >$line<"
    foreach {resid chain atom frame val} [split $line " "] {}
    #verbose "resid= $resid chain= $chain atom= $atom frame= $frame val= $val" 
    lappend frameList $frame
  } 
  #verbose "framelist is $frameList"

  set frameList [lsort -unique -increasing -integer $frameList]
  set minFrame [lindex $frameList 0]
  set maxFrame [lindex $frameList end]
  verbose "frameList is $frameList"
  #  no lkonger find frame list, since catching errors on frame assignment
  #has same effect.  Could still 
  #assign values in a new Group
  # (temporarlily, to hard-coded fields, if still in hacky version)
  verbose "now check fileLines:\n"
  foreach line $fileLines {
    #verbose "assigning data, the line is >$line<"
    foreach {resid chain atom frame val} [split $line " "] {}
    
    
    #this assumes consecutive frames, should use frameList somewhere
    # if we really want proper reverse lookup
    if { [ catch {set fieldForFrame [expr {$firstStructField + $frame}]} ] } {
      set fieldForFrame -2
      verbose "couldn't read frame text \"$frame\""
    }

    #now do lookup via dataHashA to find index in dataValA 
    if {[catch {set theIndex $dataHashA($resid,$chain)} ]} {
      verbose "failed to find data for resid=$resid, chain=$chain"
    } else {
      if { [catch {set dataValA($fieldForFrame,$theIndex) $val} ]} {
        verbose "didn't find data for frame $frame, field= $fieldForFrame, index= $theIndex, new_val= $val"
      } else {
        set dataName($fieldForFrame) $commonName
        #verbose "succesfully assigned dataValA($fieldForFrame,$theIndex) as $dataValA($fieldForFrame,$theIndex)" 
      }
    }
  }  
  

  #now delete the list of data lines, no longer needed
  unset fileLines

  #redraw the data rects
  showall 1  

  return
}

# Clears the data
proc ::contactmap::clearData {} {
  variable dataValA
  variable dataValANum
  variable firstStructField
  variable numHoriz

  verbose "clearing 2D data..."
  set endStructs [expr {$firstStructField + $numHoriz}]
  for {set field $firstStructField} {$field <= $endStructs} {incr field} {
    for {set i 0} {$i<=$dataValANum} {incr i} {

      set  dataValA($field,$i) "null"
      # for the special struct case, the 0 shold give default color
      #verbose "dataValA($field,$i) is now $dataValA($field,$i)"
      #set resid $dataValA(0,$i)
      #set chain $dataValA(2,$i)
      #set frame [expr {$field - $firstStructField}]
      #verbose $writeDataFile "$resid $chain CA $frame $val"
      
    }
  }
  #redraw the data rects
  showall 1
  return
}

proc  ::contactmap::userScaleBothChanged {val} {
  variable userScalex
  variable userScaley
  variable userScaleBoth
  variable scaley
  variable fit_scaley
  variable scalex
  variable fit_scalex

  set scalex [expr {$userScaleBoth * $fit_scalex}]
  set scaley [expr {$userScaleBoth * $fit_scaley}]
  set userScaleX  $userScaleBoth
  set userScaleY $userScaleBoth
  redraw name func op
  #verbose "redrawn, userScaleBoth= $userScaleBoth, scalex= $scalex, userScalex= $userScalex, scaley= $scaley, userScaley= $userScaley"

  return
}

proc  ::contactmap::userScalexChanged {val} {
  variable userScalex
  variable scalex
  variable fit_scalex
  set scalex [expr {$userScalex * $fit_scalex}]
  redraw name func op
  #verbose "redrawn, scalex= $scalex, userScalex= $userScalex"
  return
}

proc ::contactmap::userScaleyChanged {val} {
  variable userScaley
  variable scaley
  variable fit_scaley
  #until working ok, still do direct mapping
  set scaley $userScaley 
  redraw name func op
  return
}



proc ::contactmap::drawVertScale {} {
  variable w
  variable ytopmargin
  variable scaley
  variable ybox
  variable dataValANum
  variable dataValA
  variable vertTextSkip
  variable vertTextRight
  variable amino_code_toggle
  variable monoFont

  $w.cfr.vertScale delete vertScaleText 
  
  #when adding new column, add to this list (maybe adjustable later)
  #The picked fields 
  
  #Add the text...
  set field 0      

  #note that the column will be 0, but the data will be from picked
  
  set yDataEnd [expr {$ytopmargin + ($scaley * $ybox * ($dataValANum +1))}]
  set y 0.0

  set yposPrev  -10000.0

  #Add the text to vertScale...
  set field 0       

  #we want text to appear in center of the dataRect we are labeling
  set vertOffset [expr {$scaley * $ybox / 2.0}]

  #don't do $dataValANum, its done at end, to ensure always print last 
  for {set i 0} {$i <= $dataValANum} {incr i} {
    set ypos [expr {$ytopmargin + ($scaley * $y) + $vertOffset}]
    if { ( ($ypos - $yposPrev) >= $vertTextSkip) && ( ( $i == $dataValANum) || ( ($yDataEnd - $ypos) > $vertTextSkip) ) } {
      if {$amino_code_toggle == 0} {
        set res_string $dataValA(1,$i)} else {
          set res_string $dataValA(1code,$i)
        }

      #for speed, we use vertScaleText instead of $dataName($field)
      $w.cfr.vertScale create text $vertTextRight $ypos -text "$dataValA(0,$i) $res_string $dataValA(2,$i)" -width 200 -font $monoFont -justify right -anchor e -tags vertScaleText 

      set yposPrev  $ypos
    }        
    set y [expr {$y + $vertTextSkip}]
  } 
}

proc ::contactmap::drawHorzScale {} {
  variable w
  variable amino_code_toggle
  variable ytopmargin
  variable scalex
  variable dataValBNum
  variable dataValB
  variable monoFont
  variable firstData
  variable xcol
  variable dataWidth

  $w.cfr.horzScale delete horzScaleText

  #when adding new column, add to this list (maybe adjustable later)
  #The picked fields

  #Add the text...

  #note that the column will be 0, but the data will be from picked

  #we want text to appear in center of the dataRect we are labeling
  #ensure minimal horizaontal spacing
  if {$amino_code_toggle == 0} {
    set horzSpacing 30
  } else {
    set horzSpacing 20
  }

  set horzDataTextSkip [expr $dataWidth]
  set scaledHorzDataTextSkip [expr $scalex * $dataWidth]
  set scaledHorzDataOffset [expr $scalex * $dataWidth / 2.0]
  set ypos 40
  set xStart [expr ($xcol($firstData) + $scalex * $dataWidth)]
  set xDataEnd  [expr int ($xStart +  $scalex * ($dataWidth * ($dataValBNum) ) )]
  set x 0

  #don't do $dataValBNum, its done at end, to ensure always print last

  #numbers are scaled for 1.0 until xpos
  #this is tied to data fields, which is produced from frames upong
  #first drawing. Should really agreee with writeDataFile, which currently uses frames, not fields
  set xposPrev -1000
  #there is B data in $firstData, traj data starts at firstData+1
  for {set i 0} {$i <= $dataValBNum} {incr i} {
    set xpos [expr int ($xStart + ($scalex * $x) + $scaledHorzDataOffset)]
    if { ( ($xpos - $xposPrev) >= $horzSpacing) && ( ( $i == $dataValBNum) || ( ($xDataEnd - $xpos) > $horzSpacing) ) } {

      if {$amino_code_toggle == 0} {
        set res_string $dataValB(1,$i)} else {
        set res_string $dataValB(1code,$i)
      }

      #for speed, we use vertScaleText instead of $dataName($field)
      $w.cfr.horzScale create text $xpos $ypos -text "$dataValB(0,$i)\n$res_string\n$dataValB(2,$i)" -width 30 -font $monoFont -justify center -anchor s -tags horzScaleText

      set xposPrev  $xpos
    }

    set x [expr $x + $horzDataTextSkip]
  }
}


proc ::contactmap::makeSelText {dval dataValNum pickedonly } {
  upvar $dval dataVal  

  #make selection string to display in VMD 
  set selectText  "" 
  set prevChain "Empty" 

  #Cannot be held by chain  

  for {set i 0} {$i <= $dataValNum} {incr i} {
    if { ($pickedonly == 0) || ($dataVal(picked,$i) == 1  )} {
      if { [string compare $prevChain $dataVal(2,$i)] != 0} {
        #chain is new or has changed
        append selectText ") or (chain $dataVal(2,$i)  and resid $dataVal(0,$i)"
      } else {
        append selectText " $dataVal(0,$i)"
      }
      set prevChain $dataVal(2,$i)
    }
  }  
  append selectText ")"
  set selectText [string trimleft $selectText ") or " ]

  #check for the state when mol first loaded
  if {$selectText ==""} {
    set selectText "none"
  } 
}

#############################################
# end of the proc definitions
############################################






####################################################
# Execution starts here. 
####################################################

#####################################################
# set traces and some binidngs, then call contactmapMain
#####################################################
proc ::contactmap::startContactmap {} { 
  
  ####################################################
  # Create the window, in withdrawn form,
  # when script is sourced (at VMD startup)
  ####################################################
  variable  w  .vmd_contactmap_Window
  set windowError 0
  set errMsg ""
  #if contactmap has already been started, just deiconify window
  if { [winfo exists $w] } {
    wm deiconify $w 
    return
  }

  if { [catch {toplevel $w -visual truecolor} errMsg] } {
    puts "Info) Contact map can't find trucolor visual, will use default visual.\nInfo)   (Error reported was: $errMsg)" 
    if { [catch {toplevel $w } errMsg ]} {
      puts "Info) Default visual failed, contact map cannot be created. \nInfo)   (Error reported was: $errMsg)"   
      set windowError 1
    }
  }
  if {$windowError == 0} { 
    #don't withdraw, not under vmd menu control during testing
    wm title $w "VMD Contactmap"
    wm resizable $w 1 1

    variable monoFont

    variable initializedVars 0
    variable needsDataUpdate 0 

    trace vdelete currentMolA w [namespace code molChoose]
    trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
    trace vdelete ::vmd_initialize_structure w  [namespace code molChooseMenu]

    # Bind to the toplevel window and set variables that indicate whether
    # the window is shown and needs redrawing
    # Use bindtags so that these events are bound to the toplevel window
    # only... binding directly to a toplevel causes the event to be
    # triggered for each child window.
    bindtags $w [linsert [bindtags $w] 1 bind$w]
    bind bind$w <Map> "+[namespace code Show]"
    bind bind$w <Unmap> "+[namespace code Hide]"

    #specify monospaced font, 12 pixels wide
    #font create tkFixedMulti -family Courier -size -12
    #for test run tkFixed was made by normal sequence window
    set monoFont tkFixed
    #slight var clear, takes care of biggest space use
    catch {unset dataValA}
    catch {unset dataValB}

    #call to set up, after this, all is driven by trace and bind callbacks
    contactmapMain
  }
  return $w
}

