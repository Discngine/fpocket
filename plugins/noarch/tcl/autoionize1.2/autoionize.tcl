#!/usr/local/bin/vmd
# replace some water molecules with Na and Cl ions
# Ilya Balabin, July 15, 2003
# $Id: autoionize.tcl,v 1.11 2006/03/17 19:02:16 petefred Exp $

package require psfgen 1.2
package provide autoionize 1.1

proc autoionize_usage { } {
    puts "Autoionize adds Na and Cl ions to the solvent. Ion positions"
    puts "are random, but there are minimum distances between ions and"
    puts "molecule as well as between any two ions. If an ion "
    puts "concentration is specified, autoionize will also attempt to "
    puts "neutralize the total charge of the system."
    puts ""
    puts "Usage: autoionize -psf file.psf -pdb file.pdb \[options\]"
    puts "Required options (use EITHER '-is' OR '-nna' and '-ncl'):"
    puts "  -is <conc.>         : desired total ion concentration (mol/L, defined as (#Na+#Cl)/V)"
    puts "  -nna <Nna>          : number of Na ions"
    puts "  -ncl <Ncl>          : number of Cl ions"
    puts "Other options:"
    puts "  -o <prefix>         : output file prefix (default 'ionized')"
    puts "  -from <distance>    : min distance from molecule (default 5A)"
    puts "  -between <distance> : min distance between ions (default 5A)"
    puts "  -seg <segname>      : specify new segment name (default ION)"
    error ""
}

proc autoionize {args} {
    global errorInfo errorCode
    set oldcontext [psfcontext new]  ;# new context
    set errflag [catch { eval autoionize_core $args } errMsg]
    set savedInfo $errorInfo
    set savedCode $errorCode
    psfcontext $oldcontext delete  ;# revert to old context
    if $errflag { error $errMsg $savedInfo $savedCode }
}

proc autoionize_core {args} {
    # total max placing ion attempts
    set maxTries 10

    # check if #arguments is a) even, b) >= 6
    set n [llength $args]
    if { [expr fmod($n,2)] } { autoionize_usage }
    if { $n < 6 } { autoionize_usage }

    # get all options
    for { set i 0 } { $i < $n } { incr i 2 } {
        set key [lindex $args $i]
        set val [lindex $args [expr $i + 1]]
        set cmdline($key) $val
    }

    # check that mandatory options are defined
    if { ![info exists cmdline(-psf)] \
      || ![info exists cmdline(-pdb)] \
      || ![info exists cmdline(-is)] \
      && (![info exists cmdline(-nna)] \
       || ![info exists cmdline(-ncl)]) } {
        autoionize_usage
    }

    # set mandatory parameters
    set psffile $cmdline(-psf)
    set pdbfile $cmdline(-pdb)

    # set optional parameters
    set prefix "ionized"
    if { [info exists cmdline(-o)] } {
        set prefix $cmdline(-o)
    }
    set from 5
    if { [info exists cmdline(-from)] } {
	set from $cmdline(-from)
    }
    set between 5
    if { [info exists cmdline(-between)] } {
	set between $cmdline(-between)
    }
  set segname "ION"
  if { [info exists cmdline(-seg)] } {
    set segname $cmdline(-seg)
  }
    
    # set package WD and files
    global env
    set topfile $env(AUTOIONIZEDIR)/ions.top

    # read in topology
    topology $topfile

    # read in system
    puts "\nAutoionize) Reading ${psffile}/${pdbfile}..."
    resetpsf
    readpsf $psffile
    coordpdb $pdbfile
    mol load psf $psffile pdb $pdbfile

    # compute net charge of the system
    set sel [atomselect top all]
    set netCharge [eval "vecadd [$sel get charge]"]
    $sel delete
    puts "\nAutoionize) System net charge before adding ions: ${netCharge}e"
    
    # if ion concentration given, compute Nna and Ncl
    if { [info exists cmdline(-is)] } {
	set ionConc $cmdline(-is)
	puts "Autoionize) Desired ion concentration ${ionConc} mol/L"

	# compute Nna and Ncl
	set sel [atomselect top "water and noh"]
	set nWater [$sel num]
	set nNa [expr (-$netCharge + 0.0187 * $ionConc * $nWater)/2.0]
	set nNa [expr int([expr $nNa + 0.5])]
	set nCl [expr $netCharge + $nNa]
	set nCl [expr int([expr $nCl + 0.5])]
	
	# check if ion concentration is reasonable
	if {$nNa < 0} {
	    puts "Autoionize) WARNING: ion concentration too low, cannot add Na ions!"
	    set nNa 0
	    set nCl [expr int([expr $netCharge + 0.5])]
	}
	if {$nCl < 0} {
	    puts "Autoionize) WARNING: ion concentration too low, cannot add Cl ions!"
	    set nNa [expr -int([expr $netCharge + 0.5])]
	    set nCl 0
	}

    } else {
	# otherwise set Nna and Ncl to command line values
	set nNa $cmdline(-nna)
	set nCl $cmdline(-ncl)
	puts "Autoionize) Required ${nNa} Na and ${nCl} Cl ions"
    }
    set nIons [expr $nNa + $nCl]
    puts "Autoionize) Adding ${nNa} Na and ${nCl} Cl ions, total $nIons ions"
    puts "Autoionize) Required min distance from molecule ${from}A"
    puts "Autoionize) Required min distance between ions ${between}A"
    puts "Autoionize) Output file prefix \'${prefix}\'"


    # find water oxygens to replace with ions
    set nTries 0
    while {1} {
	set ionList {}
	while {[llength $ionList] < $nIons} {
	    if {[llength $ionList]} {
		set sel [atomselect top "noh and water and not (within $from of not water or within $between of index [concat $ionList])"]
	    } else {
		set sel [atomselect top "noh and water and not (within $from of not water)"]
	    }
	    set watIndex [$sel get index]
	    set watSize [llength $watIndex]
	    if {!$watSize} {break}
	    set thisNum [expr int($watSize * rand())]
	    set thisIon [lindex $watIndex $thisNum]
	    lappend ionList $thisIon
      $sel delete
	}
	if {[llength $ionList] == $nIons} {break}

	incr nTries
	if {$nTries == $maxTries} {
	    puts "Autoionize) ERROR: Failed to add ions from $maxTries tries"
	    puts "Autoionize) Try decreasing -from and/or -between parameters,"
	    puts "Autoionize) decreasing ion concentration, or adding more water molecules..."
	    exit
	}	
    }
    puts "Autoionize) Obtained positions for $nIons ions"

    # select and delete the waters but store the coordinates!
    set sel [atomselect top "index $ionList"]
    set waterPos [$sel get {x y z}]
    set num1 [llength $waterPos]
    puts "Autoionize) Tagged ${num1} water molecules for deleting"

    set num1 0
    foreach segid [$sel get segid] resid [$sel get resid] {
	delatom $segid $resid
	incr num1
    }
    puts "Autoionize) Deleted ${num1} water molecules"

    # set Na and Cl resid lists
    set naResList {}
    for { set res 1 } { $res <= $nNa } { incr res } {
	lappend naResList $res
    }
    set clResList {}
    for { set res 1 } { $res <= $nCl } { incr res } {
    lappend clResList [expr $nNa+$res]
    }
    set num1 [llength $naResList]
    set num2 [llength $clResList]
    puts "Autoionize) Adding ${num1} SOD and ${num2} CLA residues..."

  # make topology entries
  segment $segname {
    first NONE
    last NONE
    foreach resid $naResList { residue $resid SOD }
    foreach resid $clResList { residue $resid CLA }
  }

    # randomize ion positions (otherwise Cl ions tend to stick together)
    puts "Autoionize) Randomizing ion positions..."
    set newPos {}
    while {[llength $waterPos] > 0} {
	set thisNum [expr [llength $waterPos] * rand()]
	set thisNum [expr int($thisNum)]
	lappend newPos [lindex $waterPos $thisNum]
	set waterPos [lreplace $waterPos $thisNum $thisNum]
    }
    set waterPos $newPos
    
    # assign ion coordinates
    set naPos [lrange $waterPos 0 [expr $nNa - 1]]
    foreach pos $naPos resid $naResList {
	coord $segname $resid SOD $pos
    }
    set num1 [llength $naPos]
    puts "Autoionize) Assigned ${num1} Na coordinates"
    set clPos [lrange $waterPos $nNa end]
    foreach pos $clPos resid $clResList {
	coord $segname $resid CLA $pos
    }
    set num1 [llength $clPos]
    puts "Autoionize) Assigned ${num1} Cl coordinates"
    
    writepsf $prefix.psf
    writepdb $prefix.pdb

    # update displayed molecule
    puts "Autoionize) Reloading the system with added ions..."
    mol delete top
    mol load psf $prefix.psf pdb $prefix.pdb

    # re-compute net charge of the system
    set sel [atomselect top all]
    set netCharge [eval "vecadd [$sel get charge]"]
    $sel delete
    puts "\nAutoionize) System net charge after adding ions: ${netCharge}e"
    
    puts "Autoionize) All done."
}
