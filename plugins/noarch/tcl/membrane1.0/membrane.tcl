#
# Replicate membrane patch (VMD/psfgen)
#
# $Id: membrane.tcl,v 1.19 2005/11/23 03:25:39 petefred Exp $
#
package require psfgen 1.2
package provide membrane 1.0 

namespace eval ::Membrane:: {
  variable w

  variable uselipid
  variable xdim
  variable ydim
  variable prefix
#  variable TOPOLOGY_READ
#  set TOPOLOGY_READ 0
}

proc membrane { args }  { return [eval ::Membrane::membrane $args] }

proc ::Membrane::membrane_usage { } {
    puts "Usage: membrane -l <lipid> -x <xsize> -y <ysize> {-o <prefix>}"
    puts "  <lipid> is lipid name (POPC or POPE; others as added)"
    puts "  <xsize> and <ysize> are membrane sizes in X and Y (Angstroms)"
    puts "  <prefix> is optional output file prefix (default \"membrane\")"
    error ""
}

proc ::Membrane::membrane { args } {
  global errorInfo errorCode
  set oldcontext [psfcontext new]  ;# new context
  set errflag [catch { eval membrane_core $args } errMsg]
  set savedInfo $errorInfo
  set savedCode $errorCode
  psfcontext $oldcontext delete  ;# revert to old context
  if $errflag { error $errMsg $savedInfo $savedCode }
}


proc ::Membrane::membrane_core { args } {
    # check if #arguments is a) even, b) >= 6 and <= 8
    set n [llength $args]
    if { [expr fmod($n,2)] } { membrane_usage }
    if { $n < 6 && $n > 8 } { membrane_usage }
    
    # get all options
    for { set i 0 } { $i < $n } { incr i 2 } {
	set key [lindex $args $i]
	set val [lindex $args [expr $i + 1]]
	set cmdline($key) $val 
    }
    
    # check that mandatory options are defined
    if { ![info exists cmdline(-l)] \
      || ![info exists cmdline(-x)] \
      || ![info exists cmdline(-y)] } {
	membrane_usage
    }
    
    # set parameters
    set lipid [string tolower $cmdline(-l)]
    set LIPID [string toupper $lipid]
    set xsize $cmdline(-x)
    set ysize $cmdline(-y)
    

    # set optional parameters
    set prefix "membrane"
    if { [info exists cmdline(-o)] } {
	set prefix $cmdline(-o)
    }

    # set package WD and files
    global env 
    if ([info exists env(MEMBRANEDIR)]) {
      set psffile $env(MEMBRANEDIR)/${lipid}_box.psf
      set pdbfile $env(MEMBRANEDIR)/${lipid}_box.pdb
      set topfile $env(MEMBRANEDIR)/top_all27_prot_lipid.inp
    } else {
      set psffile [file normalize [file dirname [info script]]]/${lipid}_box.psf
      set pdbfile [file normalize [file dirname [info script]]]/${lipid}_box.pdb
      set topfile [file normalize [file dirname [info script]]]/top_all27_prot_lipid.inp
    }  
    set tempfile temp

    # read in topology (unless already read) and membrane structure
    # disabled 11/22/2005 by petefred
    # Reason: caused crash on repeated membrane generation, and there's no
    # real reason to keep this in (that I can see)
#    variable TOPOLOGY_READ
#    if { [catch {if {$TOPOLOGY_READ != 1} {}}] } {
	set TOPOLOGY_READ 1
	topology $topfile
#    }
    resetpsf
    readpsf $psffile
    mol load psf $psffile pdb $pdbfile
    
    # measure *water* dimensions (it is OK for some lipids to stick out)
    set selwat [atomselect top water]
    set minmax [measure minmax $selwat]
    foreach {min max} $minmax {}
    foreach {xmin ymin zmin} $min {}
    foreach {xmax ymax zmax} $max {}
    set watxsize [expr $xmax - $xmin]
    set watysize [expr $ymax - $ymin]

    # find out how many patch copies to make
    set nx [expr int($xsize/$watxsize) + 1]
    set ny [expr int($ysize/$watysize) + 1]
    puts "replicating $LIPID patch $nx by $ny..."
    
    # set parameters for replicating
    set patch [atomselect top all]

    set lip1 [atomselect top "segid LIP1"]
    set reslip1_unique [lsort -unique -integer [$lip1 get resid]]
    set reslip1 [$lip1 get resid]
    set namlip1 [$lip1 get name]

    set lip2 [atomselect top "segid LIP2"]
    set reslip2_unique [lsort -unique -integer [$lip2 get resid]]
    set reslip2 [$lip2 get resid]
    set namlip2 [$lip2 get name]

    set wat [atomselect top "resname TIP3"]
    set segwat [lsort -unique [$wat get segid]]
    set watsel {}
    set reswat_unique {}
    set reswat {}
    set namwat {}
    set poswat {}
    foreach seg $segwat {
	set sel [atomselect top "water and segid $seg"]
	lappend watsel $sel
	lappend reswat_unique [lsort -unique -integer [$sel get resid]]
	lappend reswat [$sel get resid]
	lappend namwat [$sel get name]
	lappend poswat [$sel get {x y z}]
    }

    # set compensation for gaps
    set watxsize [expr $watxsize - 1.5]
    set watysize [expr $watysize - 1.5]

    # do actual replicating
    set nlip 0
    set nwat 0
    for { set i 0 } { $i < $nx } { incr i } {
	set movex [expr $xmin + $i * $watxsize]
	for { set j 0 } { $j < $ny } { incr j } {
	    set movey [expr $ymin + $j * $watysize]
	    set vec [list $movex $movey 0]
	    
	    $patch moveby $vec 
	    
	    # Create new patch replica... 
	    incr nlip
	    set seglip "L1${nlip}"
	    segment $seglip {
		first NONE
		last NONE
		foreach res $reslip1_unique {
		    residue $res $LIPID
		}
	    }
	    foreach res $reslip1 name $namlip1 pos [$lip1 get {x y z}] {
		coord $seglip $res $name $pos
	    }
	    set seglip "L2${nlip}"
	    segment $seglip {
		first NONE
		last NONE
		foreach res $reslip2_unique {
		    residue $res $LIPID
		}
	    }
	    foreach res $reslip2 name $namlip2 pos [$lip2 get {x y z}] {
		coord $seglip $res $name $pos
	    }

	    foreach seg $segwat wsel $watsel reslist_unique $reswat_unique reslist $reswat namlist $namwat poslist $poswat {

		incr nwat
		set thiswatseg "W${nwat}"
		segment $thiswatseg {
		    auto none
		    foreach res $reslist_unique {
			residue $res "TIP3"
		    }
		}
		
 		foreach res $reslist name $namlist pos [$wsel get {x y z}] {
		    coord $thiswatseg $res $name $pos
		}
		
 	    }   
	    
	    $patch moveby [vecinvert $vec] 
	}
    }
    
    # Remove the original unit cell
    set segdel [lsort -unique [$patch get segid]]
    foreach seg $segdel {
	delatom $seg
    }
    
    # write out temp files
    writepsf $tempfile.psf
    writepdb $tempfile.pdb

    # reload molecule
    mol delete top
    resetpsf
    readpsf $tempfile.psf
    coordpdb $tempfile.pdb
    mol load psf $tempfile.psf pdb $tempfile.pdb

    # Cut off the extra lipids and water
    set watxpad 4
    set watypad 3.5
    set sel [atomselect top "resname TIP3"]
    set minmax [measure minmax $sel]
    foreach {min max} $minmax {}
    foreach {xmin ymin zmin} $min {}
    foreach {xmax ymax zmax} $max {}
    set x0 [expr $xmin + $xsize]
    set y0 [expr $ymin + $ysize]
    # lipids
    set sel [atomselect top "resname $LIPID and same residue as (x>$x0 or y>$y0)"]
    set segdel [lsort -unique [$sel get segid]]
    foreach seg $segdel {
	set sel [atomselect top "segname $seg and same residue as (x>$x0 or y>$y0)"]
	set resdel [lsort -unique -integer [$sel get resid]]
	foreach res $resdel {delatom $seg $res}
    }
    # water
    set x0 [expr $x0 - $watxpad]
    set y0 [expr $y0 - $watypad]
    set sel [atomselect top "resname TIP3 and same residue as (x>$x0 or y>$y0)"]
    set segdel [lsort -unique [$sel get segid]]
    foreach seg $segdel {
	set sel [atomselect top "segname $seg and same residue as (x>$x0 or y>$y0)"]
	set resdel [lsort -unique -integer [$sel get resid]]
	foreach res $resdel {delatom $seg $res}
    }

    # write out the resulting files
    writepsf $prefix.psf
    writepdb $prefix.pdb

    # clean up
    puts "deleting temporary files"
    file delete $tempfile.psf
    file delete $tempfile.pdb
    
    # update displayed molecule
    mol delete top
    mol load psf $prefix.psf pdb $prefix.pdb

}


proc ::Membrane::membrane_gui {} {
    variable w
    variable uselipid
    variable xdim
    variable ydim
    variable prefix
 
    if { [winfo exists .membrane] } {
        wm deiconify $w
        return
    }

    set w [toplevel ".membrane"]
    wm title $w "Membrane"
    wm resizable $w yes yes
    set row 0

    set ::Membrane::uselipid "POPC"
    set ::Membrane::xdim 0
    set ::Membrane::ydim 0
    set ::Membrane::prefix "membrane"
                                                                                                     
    #Add a menubar
    frame $w.menubar -relief raised -bd 2
    grid  $w.menubar -padx 1 -column 0 -columnspan 4 -row $row -sticky ew
    menubutton $w.menubar.help -text "Help" -underline 0 \
    -menu $w.menubar.help.menu
    $w.menubar.help config -width 5
    pack $w.menubar.help -side right
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About Membrane" \
    -message "Membrane building tool."}
    $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/membrane"
    incr row

    #Select the lipid to use
    grid [label $w.lipidpicklab -text "Lipid: "] \
    -row $row -column 0 -sticky w
    grid [menubutton $w.lipidpick -textvar ::Membrane::uselipid \
    -menu $w.lipidpick.menu -relief raised] \
    -row $row -column 1 -columnspan 3 -sticky ew
    menu $w.lipidpick.menu -tearoff no
    $w.lipidpick.menu add command -label "POPC" \
    -command {set ::Membrane::uselipid "POPC" }
    $w.lipidpick.menu add command -label "POPE" \
    -command {set ::Membrane::uselipid "POPE"}
    incr row

    grid [label $w.mwlabel -text "Membrane X Length: "] \
    -row $row -column 0 -columnspan 3 -sticky w
    grid [entry $w.mw -width 7 -textvariable ::Membrane::xdim] -row $row -column 3 -columnspan 1 -sticky ew
    incr row

    grid [label $w.mhlabel -text "Membrane Y Length: "] \
    -row $row -column 0 -columnspan 3 -sticky w
    grid [entry $w.mh -width 7 -textvariable ::Membrane::ydim] -row $row -column 3 -columnspan 1 -sticky ew
    incr row

    grid [label $w.prelabel -text "Output Prefix: "] \
    -row $row -column 0 -columnspan 2 -sticky w
    grid [entry $w.prefix -width 20 -textvariable ::Membrane::prefix] -row $row -column 2 -columnspan 2 -sticky ew
    incr row

    grid [button $w.gobutton -text "Generate Membrane" \
      -command [namespace code {
        puts "membrane_core -l $uselipid -x $xdim -y $ydim -o $prefix"
#        membrane_core -l POPC -x 30 -y 30 -o membrane
        membrane_core -l "$uselipid" -x "$xdim" -y "$ydim" -o "$prefix"
      } ]] -row $row -column 0 -columnspan 4 -sticky nsew

}

proc membrane_tk {} {
  ::Membrane::membrane_gui
  return $::Membrane::w
}



