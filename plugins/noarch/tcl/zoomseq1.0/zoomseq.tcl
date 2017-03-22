# zoomseq.tcl  -- VMD script to list/select sequence of a protein molecule
#
# Copyright (c) 2001 The Board of Trustees of the University of Illinois
#
# Barry Isralewitz  barryi@ks.uiuc.edu    
# vmd@ks.uiuc.edu
#
# $Id: zoomseq.tcl,v 1.15 2006/01/26 22:24:45 johns Exp $
#

package provide zoomseq 1.0


#######################
#create the namespace
#######################
namespace eval ::vmd_zoomSeq {}


####################
#define the procs
####################

proc ::vmd_zoomSeq::canvasScrollX {args} { 
    variable w

    eval $w.can xview $args
    eval $w.scale xview $args 
    
    return
}

proc ::vmd_zoomSeq::findLongFormCode {resname} {
    variable expandCodes 
    set result ""
    if {[catch { set result $expandCodes($resname) } ]} {
      set result $resname
    } 
    #leave result as-is
    return $result
}
  
proc ::vmd_zoomSeq::lookupCode {resname } {
    variable longShortCodes
    set result ""
    if {[catch { set result $longShortCodes($resname) } ]} {
      set result $resname
    } else {
      set result " $result "
    }
    return $result
}

proc ::vmd_zoomSeq::stopZoomSeq {} {
    menu sequence off
}

proc ::vmd_zoomSeq::chooseColor {field intensity} {

    if {$field != 4} {
	if {$intensity < 0} {set intensity 0}
	if {$intensity > 255} {set intensity 255}
	set intensity [expr int($intensity)]
    }
    
    switch $field {	    
	3 {   
	    set red $intensity
	    set green [expr 255 - $intensity]
	    set blue 150 
	}
	4 {
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
	}
	
	5 {
			
	    set red [expr 200 - int (200.0 * ($intensity / 255.0) )]
	    set green $red
	    set blue $intensity
		    }
	6 {		
	    set blue [expr 200 - int (200.0 * ($intensity / 255.0) )]
	    set green $blue
	    set red   $intensity
	}
	default {
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


proc ::vmd_zoomSeq::redraw {name func op} { 
    
    variable x1 
    variable y1 
    variable so
    variable sb 
    variable w 
    variable monoFont
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
    variable dataValNum 
    variable dataName 
    variable dataNameLast 
    variable ytopmargin 
    variable ybottommargin 
    variable textskip   
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
    variable usableMolLoaded
    variable rectCreated
    variable prevScaley
    #puts "rectCreated is $rectCreated"
    ##destroy $w.can   


		
    $w.can delete resid

    if { ($usableMolLoaded) && ($dataValNum >=0 ) } {
	set ysize [expr $ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValNum + 1) )]  

	set ycanmax $ysize

	if {$ycanmax < $ycanwindowmax} {
	    set ycanmax $ycanwindowmax
	}

	$w.can configure -scrollregion "0 0 $xcanmax $ycanmax"
	
	
	#----start make window
	#set ysize [expr $ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValNum + 1) )]    
	#start canvas size change
	## $w.can -configure -scrollregion  "0 0 $xcanmax $ycanmax"
	#makecanvas
	#----end make window
	
	
	
	#when adding new column, add to this list (maybe adjustable later)
	#The picked fields 
	
	#Add the text...
	set field 0    	

	#note that the column will be 0, but the data will be from picked
	
	
	set yDataEnd [expr $ytopmargin + ($scaley * $ybox * ($dataValNum +1))]
	set y 0.0

	set yposPrev  -10000.0

	#Add the text...
	set field 0    	 



	#we want text to appear in center of the dataRect we are labeling
	set vertOffset [expr $scaley * $ybox / 2.0]

	set textStartX [expr $xcol(3) - 4 ]
	#don't do $dataValNum, its done at end, to ensure always print last 
	for {set i 0} {$i <= $dataValNum} {incr i} {
	    set ypos [expr $ytopmargin + ($scaley * $y) + $vertOffset]
	    if { ( ($ypos - $yposPrev) >= $textskip) && ( ( $i == $dataValNum) || ( ($yDataEnd - $ypos) > $textskip) ) } {
		if {$amino_code_toggle == 0} {
		    set res_string $dataVal(1,$i)} else {
			set res_string $dataVal(1code,$i)
		    }
		


		#for speed, we use "resid" instead of $dataName($field)
		#puts "font = $monoFont";
		$w.can create text $textStartX $ypos -text "$dataVal(0,$i) $res_string $dataVal(2,$i)" -width 200 -font $monoFont -justify right -anchor e -tags "resid"

		set yposPrev  $ypos
	    }        
	    set y [expr $y + $textskip]
	    
	} 
    
	
	set fieldLast  $dataNameLast
	#temporary, until put multi-cols in
	


	#draw data
	#loop over all data fields

	    if {! $rectCreated} {

		$w.can delete dataScalable
		for {set field $firstData} {$field <= $fieldLast} {incr field} {
	    
		    set xPosField [expr int ($xcol($firstData) + ($dataWidth * ($field - $firstData) ) )]
		    
		    
		    #now draw data rectangles
		    
		    set y 0.0
		    
		    set intensity 0
		    
		    for {set i 0} {$i<=$dataValNum} {incr i} { 
			if {$dataVal($field,$i) != "null"} {
			    #calculate color and create rectange
			    
			    set ypos [expr $ytopmargin + ($scaley * $y)]
			    
			    #should Prescan  to find range of values!	
			    #this should be some per-request-method range / also allow this to be adjusted
			    
			    #set intensity except if field 4 (indexed struct)
			    if { ( ($field != 4)  ) } {
				set range [expr $dataMax($field) - $dataMin($field)]
				if {$range > 0} {
				    set intensity  [expr int (255 * ( ($dataVal($field,$i) - $dataMin($field) ) / $range)) ]
				}
				
				
				
				set hexcols [chooseColor $field $intensity]
			    } else {
				#horrifyingly, sends string for data, tcl is typeless
				set hexcols [chooseColor $field $dataVal($field,$i)]
			    }
			    
			    set hexred [lindex $hexcols 0]
			    set hexgreen [lindex $hexcols 1]
			    set hexblue [lindex $hexcols 2]
			    
			    #draw data rectangle
			    
			    $w.can create rectangle  [expr $xPosField] [expr $ypos ] [expr $xPosField + $dataWidth -$dataMargin ]  [expr $ypos + ($scaley * $ybox)]  -fill "\#${hexred}${hexgreen}${hexblue}" -outline "" -tags dataScalable
			}
			set y [expr $y + $ybox]
		    }
		} 

		set field 0
		draw_highlight $field
		
	    }  else {

		#$w.can scale dataRect $xcol($firstdata) $ytopmargin 1 $scaley
		$w.can scale dataScalable $xcol($firstData) [expr $ytopmargin] 1 [expr $scaley / $prevScaley ]

	    } 
	
	set rectCreated 1
	set prevScaley $scaley
    }

    return
}




proc ::vmd_zoomSeq::makecanvas {} {

    variable xcanmax 
    variable ycanmax 
    variable w
    variable ysize 
    variable xcanwindowmax 
    variable ycanwindowmax
    
    #set xcanmax 610.0
    set ycanmax $ysize
    
    set scaleCanvasHeight 46
    
    #make main canvas


 canvas $w.can -width $xcanwindowmax -height $ycanwindowmax -bg #c0c0c0 -yscrollcommand "$w.ys set" -scrollregion  "0 0 $xcanmax $ycanmax" 
    #make small canvas for data scales/keys
    canvas $w.scale -width $xcanwindowmax -height  $scaleCanvasHeight  -scrollregion "0 0 $xcanmax $scaleCanvasHeight" -bg #a0a0a0 
    pack $w.scale -in $w.cfr -side bottom -anchor sw
    pack $w.can $w.ys -in $w.cfr -side left -fill x -fill y    
    
    bind $w.can <ButtonPress>  [namespace code {getStartedMarquee %x %y %s}]
    bind $w.can <B1-Motion>  [namespace code {keepMovingMarquee %x %y}]
    bind $w.can <B3-Motion>  [namespace code {keepMovingMarquee %x %y}]
    bind $w.can <ButtonRelease> [namespace code {letGoMarquee %x %y %b}]
    
    return
} 


proc ::vmd_zoomSeq::reconfigureCanvas {} {
    variable xcanmax 
    variable ycanmax 
    variable w
    variable ysize 
    variable xcanwindowmax 
    variable ycanwindowmax
    variable scaleCanvasHeight
    variable xcanwindowStarting
    variable xcanwindowmax 
    variable firstData
    variable xcol

    #in future, add to xcanwindowstarting if we widen window
    set xcanwindowmax  $xcanwindowStarting 


    #check if can cause trouble if no mol loaded...
    $w.can configure  -height $ycanwindowmax -width $xcanwindowmax 
    $w.scale configure  -height  $scaleCanvasHeight  -scrollregion "0 0 $xcanmax $scaleCanvasHeight"

    $w.scale delete all
    $w.can delete all

}


proc ::vmd_zoomSeq::draw_highlight {field} {

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

    for {set i 0} {$i<=$dataValNum} {incr i} {
	if  {$dataVal(picked,$i) == 1} {
	    set ypos [expr $ytopmargin+ ($scaley * $i *$ybox)]
	    
	    set red 255
	    set green 255
	    set blue 0
	    #convert red blue green 0 - 255 to hex
	    set hexred     [format "%02x" $red]
	    set hexgreen   [format "%02x" $green]
	    set hexblue    [format "%02x" $blue]
	    
	    #draw highlight only if not yet drawn -- if rectCreated is 0, we may  just cleared the rects
	    #     to redraw free of accumulated scaling errors
	    if {($dataVal(pickedId,$i) == "null") || ($rectCreated == 0)} {

		set dataVal(pickedId,$i)  [$w.can create rectangle  [expr $xcol($field) - 5] $ypos [expr $xcol([expr $field + 3]) - 2 ] [expr $ypos + ($scaley * $ybox)]  -fill "\#${hexred}${hexgreen}${hexblue}" -outline "" -tags dataScalable]
		
		
		$w.can lower $dataVal(pickedId,$i)  "resid"
	    
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
        set repid [mol repindex $currentMol $rep($currentMol)]
        if { $repid >= 0 } {
            mol modselect $repid $currentMol $ll
        } else {
            createHighlight  $ll	
        }
    } else {
        createHighlight  $ll	
    }
    return
}


proc ::vmd_zoomSeq::list_pick {name element op} {
    
    variable w 
    # If the window isn't open, do nothing
    if { ![string equal [wm state $w] normal] } {
      return
    }

    global vmd_pick_atom 
    global vmd_pick_mol 
    global vmd_pick_shift_state  

    variable xcanmax 
    variable ycanmax  
    variable xcanwindowmax 
    variable ycanwindowmax
    variable ybox
    variable ytopmargin 
    variable ybottommargin 
    variable textskip 
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
	    set field 0	
	    
	    draw_highlight $field
	    
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



proc ::vmd_zoomSeq::zoomSeqMain {} {
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
    variable vmd_pick_shift_state 
    variable amino_code_toggle 
    variable bond_rad 
    variable bond_res
    variable so 
    variable sb 
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
    variable rectId
    #dataValNum is -1 if no data present, 
    variable dataValNum 
    variable dataName 
    variable dataNameLast 
    variable ytopmargin 
    variable ybottommargin 
    variable textskip   
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
    variable fit_scaley
    variable usableMolLoaded 
    variable initializedVars
    variable prevScalet
    variable rectCreated
    variable windowShowing
    variable needsDataUpdate 

    
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
	#this sets a trace for ::vmd_zoomSeq::scaley
	
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
	
	trace vdelete  scaley w  [namespace code redraw]
	set scaley 1.0
    # set  a new  trace below, only if dataValNum > -1	
	
	set currentMol_name [molinfo $currentMol get name]
  wm title $w "VMD Sequence  $currentMol_name (mol $currentMol) "
    #would use 'nucleic', but it currently fails to find terminal nucleic acid residues
   set sel [atomselect $currentMol "(all and name CA) or ( (not protein) and  ( (name \"C3\\'\") or (name \"C3\\*\") ) ) "] 
	#below assumes sel retrievals in same order each time, fix this 
	#by changing to one retreival and chopping up result
	set datalist  [$sel get {resid resname chain}]

	puts "Checking sequence info. for molecule $currentMol..."
	
	foreach elem $datalist {
	    
	    incr dataValNum
	    #set picked state to false -- 'picked' is only non-numerical field
	    set dataVal(picked,$dataValNum) 0
	    set dataVal(pickedId,$dataValNum) "null"
	    set dataVal(0,$dataValNum) [ lindex [split $elem] 0]
	    
	    set dataVal(1,$dataValNum) [ findLongFormCode [ lindex [split $elem] 1] ]
	    set dataVal(1code,$dataValNum) [lookupCode $dataVal(1,$dataValNum)]
	    set dataVal(2,$dataValNum) [ lindex [split $elem] 2]
	    
	    
	}
    #if datalist is length 0 (empty), dataValNum is still -1, 
    #So we must check before each use of dataValNum  	
	
	#set the molec. structure so nothing is highlighted yet
	set rep($currentMol) "null"
	
	
	if {$dataValNum <= -1 } {
	    #puts "Couldn't find a sequence in this molecule.\n"
        return
	}
  
    #this trace only set if dataValNum != -1
    trace variable scaley w  [namespace code redraw]

	#So dataValNum is number of the last dataVal.  It is also #elements -1, 
	
	set fit_scaley [expr (0.0 + $ycanwindowmax - $ytopmargin - $ybottommargin) / ($ybox * ($dataValNum + 1) ) ]
	#sicne we zero-count.
	
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
	set prevScaley 1
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
	
	
	#fill in structlist
	incr dataNameLast
	set structlist [$sel get structure]
	set dataName($dataNameLast) "struct"
	
	set i 0
	foreach elem $structlist {
	    set dataVal($dataNameLast,$i) $elem
	    incr i
	}


	unset structlist; #done with it


	#lets add another data field, just to test...
	#incr dataNameLast

	#set test_pos_list [$sel get y]
	#set dataName($dataNameLast) "test Y"
	#set dataMin($dataNameLast) -20
	#set dataMax($dataNameLast) +100
	#set i 0
	#foreach elem $test_pos_list {
	#    set dataVal($dataNameLast,$i)  $elem
	#    incr i
	#}
	#unset test_pos_list



    
}
      #redraw first time
    redraw name func ops
 
    #now draw the scales (after the data, we may need to extract min/max 

	#------
        #draw color legends, loop over all data fields
    set fieldLast  $dataNameLast
    #temporary, until put multi-cols in
    for {set field $firstData} {$field <= $fieldLast} {incr field} {
	    
	set xPosField [expr int ($xcol($firstData) + ($dataWidth * ($field - $firstData) ) )]
	
	#print the the title in center of data rectangle width
	$w.scale create text [expr int($xPosField + ( ($dataWidth -$dataMargin)/ 2.0) )] 1 -text "$dataName($field)" -width 200 -font $monoFont -justify center -anchor n 
	
	
	
	#make a scale across data rectange width

	set size [expr $dataWidth - $dataMargin]
	if {$field != 4} {
	    set minString [format "%.3g" $dataMin($field)]
	    set maxString [format "%.3g" $dataMax($field)]
	    $w.scale create text [expr $xPosField - 2  ] $xPosScaleVal -text $minString -width 50 -font $monoFont -justify center -anchor nw
	    $w.scale create text [expr int ($xPosField - $dataMargin + $dataWidth +2 )] $xPosScaleVal -text $maxString -width 50 -font $monoFont -justify center -anchor ne
	    
	    set range [expr $dataMax($field) - $dataMin($field)]
	    #bounds check, should really print error message
	    if {$range <= 0} {
		puts "Bad range for field $dataName($field), min= $dataMin($field) max= $dataMax($field), range = $range"
		set $dataMin($field) -100
		set $dataMax($field) 100
		set $range [expr $dataMax($field) - $dataMin($field)]
		puts "Reset range for $dataName($field), new values: min= $dataMin($field) max= $dataMax($field), range = $range"
	    }
	    
	    for {set yrect 0} {$yrect < $size} {incr yrect} {
		
		#draw linear scale
		set val [expr ( ( 0.0+ $yrect  )/ ($size -1)) * 255]
		#puts "val = $val , range = $range"
		set hexcols [chooseColor $field $val]		     
		
		set hexred [lindex $hexcols 0]
		set hexgreen [lindex $hexcols 1]
		set hexblue [lindex $hexcols 2]
		

		    $w.scale create rectangle [expr $xPosField + $yrect] 15 [expr $xPosField + $yrect] 30 -fill  "\#${hexred}${hexgreen}${hexblue}" -outline ""
	    }
	} else {
	    
	    set prevNameIndex -1
	    for {set yrect 0} {$yrect < $size} {incr yrect} {
		set names [list T E B H G I C "other"]
		
		set nameIndex [expr int ([expr [llength $names] -1]  * ($yrect+0.0)/$size)]
		set curName [lindex $names  $nameIndex]
		
		if {$nameIndex != $prevNameIndex} {
			#set line to black
		    set hexred 0
		    set hexgreen 0
		    set hexblue 0
		    
		    #draw text
		    $w.scale create text [expr int ($xPosField + $yrect+ 3)] $xPosScaleVal -text $curName -width 20 -font $monoFont -justify left -anchor nw
		} else {
		    
		    
		    
		    set hexcols [chooseColor $field $curName]
		    
		    set hexred [lindex $hexcols 0]
		    set hexgreen [lindex $hexcols 1]
		    set hexblue [lindex $hexcols 2]
		}

		$w.scale create rectangle [expr $xPosField + $yrect] 15 [expr $xPosField + $yrect] 30 -fill  "\#${hexred}${hexgreen}${hexblue}" -outline ""
		    set prevNameIndex $nameIndex
	    }
	    set hexred 0
	    set hexgreen 0
	    set hexblue 0
	    $w.scale create rectangle [expr $xPosField + $yrect] 15 [expr $xPosField + $size] 30 -fill  "\#${hexred}${hexgreen}${hexblue}" -outline ""
	}
    }	
    #done with color legends
    #-------
   
    
    #set the canvas tool, right now there's only one, object selector
    set sb "obj"
    

    return
}


proc ::vmd_zoomSeq::molChooseMenu {name function op} {
    variable w

    variable usableMolLoaded
    variable currentMol
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
        set currentMol $nullMolString
    } else {
	    set usableMolLoaded 1
        # Choose top molecule if currentMol is invalid
        if {[lsearch -exact $molList $currentMol]== -1 } {
            set currentMol [molinfo top]
	    }
    } 
    return
}

proc ::vmd_zoomSeq::printCanvas {} {
    variable w
    #extract first part of molecule name to print here?
    set filename "VMD_Sequence_Window.ps"
    set filename [tk_getSaveFile -initialfile $filename -title "VMD Sequence Print" -parent $w -filetypes [list {{Postscript Files} {.ps}} {{All files} {*} }] ]
    if {$filename != ""} {
	$w.can postscript -file $filename
    }
    
    return
}





proc ::vmd_zoomSeq::getStartedMarquee {x y shiftState} {

    variable w 
    variable x1 
    variable y1 
    variable sb    
    variable so
    variable str 
    variable eo 
    variable g 
    variable startShiftPressed
    variable xcanmax 
    variable ycanmax
    variable usableMolLoaded
    
    if {$usableMolLoaded} {

	#calculate offset for canvas scroll
	
	set x [expr $x + $xcanmax * [lindex [$w.can xview] 0]] 
	set y [expr $y + $ycanmax * [lindex [$w.can yview] 0]] 
	
	set x1 $x
	set y1 $y
	
	#do bitwise AND to check for shift-key bit
	if {$shiftState & 1} {
	    set startShiftPressed 1
	    
	} else {
	    set startShiftPressed 0
	}
	
	#Might have other canvas tools in future..	 
	# Otherwise, start drawing rectangle for selection marquee
	
	if { [string compare $sb "obj"] == 0} {
	    set so [$w.can create rectangle $x $y $x $y -fill {} -outline red]
	    set eo $so
	    return
	} 
    }
    return
}

proc ::vmd_zoomSeq::molChoose {name function op} {

    variable rep 
    variable needsDataUpdate
    variable windowShowing
    
    # delete all highlight reps
    foreach molid [array names rep] {
        set repid [mol repindex $molid $rep($molid)]
        if { $repid >= 0 } {
            mol delrep $repid $molid
        }
    }

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
    return
}

proc ::vmd_zoomSeq::keepMovingMarquee {x y} {

    variable x1 
    variable y1 
    variable so 
    variable sb 
    variable w 
    variable xcanmax 
    variable ycanmax

    variable usableMolLoaded
    
    if {$usableMolLoaded} {

	#next two lines for debeugging only
	set windowx $x
	set windowy $y 
	#calculate offset for canvas scroll
	set x [expr $x + $xcanmax * [lindex [$w.can xview] 0]] 
	set y [expr $y + $ycanmax * [lindex [$w.can yview] 0]] 
	
	
	if {[string compare $sb "text"] == 0 } {
	    return
	}
	
	
	$w.can coords $so $x1 $y1 $x $y
    }
    return
}

proc ::vmd_zoomSeq::letGoMarquee {x y b} {


    variable x1 
    variable y1 
    variable startShiftPressed 
    variable so 
    variable sb 
    variable eo 
    variable w 
    variable xcanmax 
    variable ycanmax 
    variable ySelStart 
    variable ySelFinish 
    variable ybox 
    variable ytopmargin 
    variable ybottommargin 
    variable textskip 
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

    if {$usableMolLoaded} {
	#calculate offset for canvas scroll
	set x [expr $x + $xcanmax * [lindex [$w.can xview] 0]] 
	set y [expr $y + $ycanmax * [lindex [$w.can yview] 0]] 

	#Might have other canvas tools in future...
	if { [string compare $sb "obj"] == 0} {
	    
	    
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
	    
	    if {$singleSel == 1 && $b != 3 } {
		
		for {set i 0} {$i <= $dataValNum} {incr i} {
		    set dataVal(picked,$i) 0
		    if {$dataVal(pickedId,$i) != "null"} {
			
			$w.can delete $dataVal(pickedId,$i)
			set dataVal(pickedId,$i) "null"
		    }
		}
	    } else {
		
		#just leave alone	
	    }
	    
	    
      if { $b == 3 } {
        # unhighlighted selected residues
	      for {set i $startObject} {$i <= $finishObject} {incr i} {
          set dataVal(picked,$i) 0
          if { $dataVal(pickedId,$i) != "null" } {
            $w.can delete $dataVal(pickedId,$i)
            set dataVal(pickedId,$i) "null"
          }
        }
      } else {
        # highlight selected residues
	      for {set i $startObject} {$i <= $finishObject} {incr i} {
          set dataVal(picked,$i) 1
        }
      }
	    
	    
	    set field 0
	    #note that the column will be 0, but the data will be from picked
	    
	    draw_highlight $field
	    
	    
	    
	    
	    $w.can delete $eo
	    
	}
    }
    return
}

proc ::vmd_zoomSeq::showall {} {



    variable scaley 
    variable fit_scaley
    variable usableMolLoaded
    
    if {$usableMolLoaded} {
	set scaley $fit_scaley
    }

    return
}


proc ::vmd_zoomSeq::every_res {} {

    variable usableMolLoaded
    variable rectCreated

    #this forces redraw, to cure any scaling floating point errors
    #that have crept in 
    set rectCreated 0

    variable scaley


    if {$usableMolLoaded} {
	set rectCreated 0
	set scaley 1.0
    }
    
    return
}


proc ::vmd_zoomSeq::resname_toggle {} {

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


 

proc ::vmd_zoomSeq::initVars {} {        
    variable usableMolLoaded 0
    variable windowShowing 0
    variable needsDataUpdate 0
    variable dataNameLast 2
    variable dataValNum -1
    variable eo 0
    variable x1 0 
    variable y1 0
    variable startShiftPressed 0
    variable vmd_pick_shift_state 0
    variable amino_code_toggle 0
    variable bond_rad 0.5
    variable bond_res 10
    variable so ""
    variable sb ""
    variable nullMolString ""
    variable currentMol $nullMolString
    variable  scaley 1
    variable prevScaley 1
    
    variable ytopmargin 5
    variable ybottommargin 10


    variable xcanwindowStarting 260

    variable xcanwindowmax  $xcanwindowStarting
    variable ycanwindowmax 620
    variable xcanmax 610
    variable scaleCanvasHeight 46


    variable longShortCodes
    array set longShortCodes {ALA A ARG R ASN N ASP D ASX B CYS C GLN Q GLU E GLX Z GLY G HIS H HSD H HSE H HSP H ILE I LEU L LYS K MET M PHE F PRO P SER S THR T TRP W TYR Y VAL V ADE A GUA G THY T CYT C URA U}
  
    #these may appear in structure files in 1-letter form 
    #We need subset, since there is some overlap between
    #amino acids and nucleic acids in 1-letter code.  
    #Amino acids rarely appear in struct files in 1-letter form
    variable expandCodes
    array set expandCodes {A ADE G GUA T THY C CYT U URA}    
    
    
     

    #tests if rects for current mol have been created (should extend 
    #so memorize all rectIds in 3dim array, and track num mols-long 
    #vector of rectCreated. Would hide rects for non-disped molec,
    #and remember to delete the data when molec deleted.
    
    variable rectCreated 0

    #the box height
    variable ybox 15.0
    #text skip doesn't need to be same as ybox (e.g. if bigger numbers than boxes in 1.0 scale)
    variable textskip $ybox
    

    

    #The first 3 fields, 0 to 2 are printed all together, they are text
    variable xcol
    set xcol(0) 10.0

    variable dataWidth 85
    variable dataMargin 15
    variable xPosScaleVal 32
    #so rectangge of data is drawn at width $dataWidth - $dataMargin (horizontal measures)
    variable firstData 3
    #column that multi-col data first  appears in

    set xcol($firstData)  96 
    #The 4th field (field 3) is the "first data field"
    
    
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
    

}


proc ::vmd_zoomSeq::Show {} {
    variable windowShowing
    variable needsDataUpdate
    set windowShowing 1

    
    if {$needsDataUpdate} {
	set needsDataUpdate 0
	#set immmediately, so other binding callbacks will see
	[namespace current]::zoomSeqMain
    }

}

proc ::vmd_zoomSeq::Hide {} {
    variable windowShowing 
    set windowShowing 0

}

	

proc ::vmd_zoomSeq::createHighlight { theSel} {

    variable currentMol
    variable bond_rad
    variable bond_res
    variable rep
    mol selection $theSel
    mol material Opaque
    mol color ColorID 4
    set repid [molinfo $currentMol get numreps]
    mol addrep $currentMol
    set rep($currentMol) [mol repname $currentMol $repid]
    mol modstyle $repid $currentMol Bonds $bond_rad $bond_res
}

proc ::vmd_zoomSeq::draw_interface {} {
    variable w 

    variable eo 
    variable x1  
    variable y1 
    variable startShiftPressed 
    variable vmd_pick_shift_state 
    variable amino_code_toggle 
    variable bond_rad 
    variable bond_res
    variable so 
    variable sb 
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
    variable dataValNum 
    variable dataName 
    variable dataNameLast 
    variable ytopmargin 
    variable ybottommargin 
    variable textskip   
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
    variable fit_scaley
    variable usableMolLoaded 

  # If already initialized, just turn on 
  if [winfo exists .vmd_SequenceWindow] {
    wm deiconify $w
    return
  }

    ####################################################
    # Create the window, in withdrawn form,
    # when script is sourced (at VMD startup)
    ####################################################
    set windowError 0
    set errMsg ""
    set w  .vmd_SequenceWindow
    if [catch {toplevel $w -visual truecolor} errMsg] {
        puts "Info) Sequence window can't find trucolor visual, will use default visual.\nInfo)   (Error reported was: $errMsg)" 
        if { [catch {toplevel $w } errMsg ]} {
          puts "Info) Default visual failed, Sequence window cannot be created. \nInfo)   (Error reported was: $errMsg)" 	
	      set windowError 1
        }
    }
    if $windowError {
      error "$errMsg" 
    }
    
		wm withdraw $w
		wm title $w "VMD Sequence"
		wm resizable $w 0 0 
    
		bind $w <Map> "+[namespace code Show]"
		bind $w <Unmap> "+[namespace code Hide]"

    frame $w.fr -width 700 -height 810 -bd 2 ;#main frame

    pack $w.fr

    label $w.txtlab -text "Zoom "
    



    frame $w.fr.menubar -relief raised -bd 2
    pack $w.fr.menubar -padx 1 -fill x


    frame $w.fr.panl -width 130 -height [expr $ycanwindowmax + 80] -bg #c0c0c0  
    frame $w.cfr -width 300 -height [expr $ycanwindowmax + 20] -bd 1
    pack $w.fr.panl $w.cfr -in $w.fr -side left -padx 2 -after $w.fr.menubar -fill x

    scale $w.fr.panl.zoomlevel -from 0.01 -to 2.01 -length 150 -sliderlength 30  -resolution 0.01 -tickinterval 0.5 -repeatinterval 30 -showvalue true -variable [namespace current]::scaley 

    pack $w.fr.panl $w.cfr -in $w.fr -side left -padx 2
    pack $w.fr.panl.zoomlevel -in $w.fr.panl -side right -ipadx 5 -padx 3

    button $w.showall  -text "fit all" -command [namespace code showall]
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

    scrollbar $w.ys -command "$w.can yview" 
    
    #scrollbar $w.xs -orient horizontal -command [namespace code {canvasScrollX}]



     #fill the  top menu
    menubutton $w.fr.menubar.file -text "File   " -underline 0 -menu $w.fr.menubar.file.menu
    $w.fr.menubar.file config -width 5

    menubutton $w.fr.menubar.graphics -text "Graphics   " -underline 0 -menu $w.fr.menubar.graphics.menu
    $w.fr.menubar.graphics config -width 8
    pack $w.fr.menubar.file -side left


    menubutton $w.fr.menubar.help -text "Help   " -underline 0 -menu $w.fr.menubar.help.menu
    $w.fr.menubar.help config -width 5

    menu $w.fr.menubar.help.menu -tearoff no

    $w.fr.menubar.help.menu add command -label "Sequence Viewer Help" -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/zoomseq" 
    $w.fr.menubar.help.menu add command -label "Structure codes..." -command  [namespace code {tk_messageBox -parent $w  -type ok -message "Secondary Structure Codes\n\nT        Turn\nE        Extended conformation\nB        Isolated bridge\nH        Alpha helix\nG        3-10 helix\nI         Pi-helix\nC        Coil (none of the above)\n" } ]

    pack $w.fr.menubar.help -side right 
    
    #File menu
    menu $w.fr.menubar.file.menu -tearoff no
    $w.fr.menubar.file.menu add command -label "Print to file..." -command [namespace code {printCanvas} ] 
    $w.fr.menubar.file.menu add command -label "Close Sequence Window" -command [namespace code stopZoomSeq] 

    #Graphics menu
    menu $w.fr.menubar.graphics.menu -tearoff no
    $w.fr.menubar.graphics.menu add cascade -label "Line Width" \
	-menu $w.fr.menubar.graphics.menu.fmenu
    $w.fr.menubar.graphics.menu add command -label "Highlight color/style" \
	-command [namespace code {set_highlight_style}]
    
    #the w.can object made here
set ysize [expr $ytopmargin+ $ybottommargin + ($scaley *  $ybox * ($dataValNum + 1))]    


place $w.txtlab -in $w.fr.panl.zoomlevel  -bordermode outside -rely 0.0 -relx 0.5 -anchor s
place $w.showall -in $w.fr.panl.zoomlevel  -bordermode outside -rely 1.0 -relx 0.5 -anchor n
place $w.every_res  -in $w.showall -bordermode outside -rely 1.0 -relx 0.5 -anchor n
place $w.resname_toggle -in $w.every_res -bordermode outside -rely 1.0 -y 40 -relx 0.5 -anchor n
place  $w.stop_zoomseq -in $w.txtlab  -bordermode outside -rely 0.0 -y -140 -relx 0.5 -anchor s

     
place $w.mol -in $w.fr.panl.zoomlevel  -bordermode outside -rely -.3 -relx 0.85 -anchor s
place $w.molLab -in $w.mol -bordermode outside -rely 0.5 -relx 0 -anchor e
#done with interface elements     


#ask window manager for size of window

    #turn traces  on (initialize_struct trace comes later)
    trace variable scaley w  [namespace code redraw]
    trace variable ::vmd_pick_atom w [namespace code list_pick]
    trace variable currentMol w [namespace code molChoose]

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
namespace eval ::vmd_zoomSeq { 
		variable w
		variable monoFont

		variable initializedVars 0
		variable needsDataUpdate 0 

		#specify monospaced font, 12 pixels wide
		font create tkFixed -family Courier -size -12
		set monoFont tkFixed
    
		#overkill for debugging, should only need to delete once....
		trace vdelete scaley w [namespace code redraw]
		trace vdelete scaley w [namespace code redraw]
		trace vdelete currentMol w [namespace code molChoose]
		trace vdelete currentMol w [namespace code molChoose]
		trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
		trace vdelete ::vmd_pick_atom w  [namespace code list_pick] 
		trace vdelete ::vmd_initialize_structure w  [namespace code molChooseMenu]
		trace vdelete ::vmd_initialize_structure w  [namespace code molChooseMenu]
}


proc zoomseq_tk {} {
  ::vmd_zoomSeq::zoomSeqMain
  return $::vmd_zoomSeq::w
}

#puts "Loaded the sequence viewer."
