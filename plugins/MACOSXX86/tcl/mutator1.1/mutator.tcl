
# Generate pdb file of each protein segment (VMD)
# If needed, generate pdb-psf file of everything but proteins (VMD/psfgen)
# Build psf-pdb of protein with mutation included (VMD/psfgen)
# If needed, merge pdb-psf file of everything but protein with mutated protein (psfgen)
# Write FEP files if requested

# TODO
# Add support to patches. 
# Implement for nucleic acids?
# Allow to run a short minimization?
# Allow use of alternative topoplogy files? (check the current one).
# JH: warn user not to use FEP file generation on termini (patching problem)
#
# Author: Marcos Sotomayor / Jerome Henin / Chris Chipot.

package require alchemify
package require psfgen
package require readcharmmtop
package provide mutator 1.1

proc mutator_usage { } {
    puts "Usage: mutator -psf <psffile> -pdb <pdbfile> -o <prefix>  -ressegname <targetresiduesegname> -resid <targetresid> -mut <resname> -FEP <prefix2>" 
    puts "Options:"
    puts "    -o <prefix> (data will be written to prefix.psf/prefix.pdb)"
    puts "    -ressegname <targetresiduesegname> (If not specified, residues of all segments are mutated)"
    puts "    -resid <targetresid>"
    puts "    -mut <resname> (three letter name of residue that will replace target residue)"
    puts "     (ALA, ARG, ASN, ASP, CYS, GLN, GLU, GLY, HSD, HSE, HSP, ILE, LEU, LYS, MET, PHE, PRO, SER, THR, TRP, TYR, VAL)" 
    puts "    -FEP <prefix> (FEP files will be written to prefix.fep.psf/prefix.fep"
    error ""
}

proc mutator {args} {
    global errorInfo errorCode
    set oldcontext [psfcontext new]  ;# new context
    set errflag [catch { eval mutator_core $args } errMsg]
    set savedInfo $errorInfo
    set savedCode $errorCode
    psfcontext $oldcontext delete  ;# revert to old context
    if $errflag { error $errMsg $savedInfo $savedCode }
}

proc mutator_core {args} {
    global env 
    
    # Print usage information if no arguments are given
    if { ![llength $args] } {
	mutator_usage
    }
    
    # get all options
    # 
    
    set n [llength $args]
    
    for { set i 0 } {$i < $n } { incr i 2 } {
	set key [lindex $args $i]
	set val [lindex $args [expr $i+1]]
	set cmdline($key) $val
    }
    
    # check that mandatory options are defined
    if {![info exists cmdline(-psf)]\
	    || ![info exists cmdline(-pdb)]\
	    || ![info exists cmdline(-o)]\
	    || ![info exists cmdline(-resid)]\
	    || ![info exists cmdline(-mut)]} {
	mutator_usage
    }
    
    # set mandatory parameters
    set psffile $cmdline(-psf)
    set pdbfile $cmdline(-pdb)
    set prefix $cmdline(-o)
    set resid $cmdline(-resid)
    set mut $cmdline(-mut)
    
    # set optional parameters
    if { [info exists cmdline(-ressegname)] } {
	set ressegname $cmdline(-ressegname)
    }
    if { [info exists cmdline(-FEP)] } {
	set fepprefix $cmdline(-FEP)
    }
  
    set topfile [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
    set feptopfile [file join $env(CHARMMTOPDIR) top_all27_hybrid.inp]

    puts "\n Mutator: Reading $psffile/$pdbfile..."
    
    # Loading psf/pdb files
    
    mol load psf $psffile pdb $pdbfile
    set prot [atomselect top "protein"]
    set notprot [atomselect top "not protein"]
    
    # Checking for protein
    
    if { [$prot num] == 0} {
	puts "\n Mutator: protein not found! where did the protein go dude?"
	error "Mutator 1.1 failed."
    }
    
    # Write pdbs for each protein segment
    
    foreach i [lsort -unique [$prot get segname]] {
	set c [atomselect top "segname $i"]
	puts "\n Writing temporary pdb file for protein segment $i"
	$c writepdb mtemp-$i.pdb
	$c delete
    }
    
    # Write psf/pdb for non-protein stuff (water, membrane, ions, etc.)
    
    puts "Reading topology from $topfile..."
    topology $topfile
    if { [$notprot num] != 0} {
	resetpsf
	readpsf $psffile
	coordpdb $pdbfile
	foreach seg [$prot get segname] res [$prot get resid] {
	    delatom $seg $res
	}
	guesscoord
	
	puts "\n Mutator: Writing temporary files for non-protein components"
	writepsf mtemp-nprot.psf
	writepdb mtemp-nprot.pdb
    }
    
    # Build protein with mutation
    puts "\n Mutator: Building protein segments" 
    resetpsf
    foreach i [lsort -unique [$prot get segname]] {
	segment $i {
	    pdb mtemp-$i.pdb
	    if { [info exists cmdline(-ressegname)] } {
		#puts "\n Mutator DEBUG: $i $ressegname"
		if { $i == $ressegname } {
		    puts "\n Mutator: Residue $resid of segment $ressegname has been mutated to $mut"
		    mutate $resid $mut
		}
	    } else {
		puts "\n Mutator: Residue $resid of segment $i has been mutated to $mut"
		mutate $resid $mut
	    }
	}
	coordpdb mtemp-$i.pdb $i
    }
    
    # Reading non protein stuff
    if { [$notprot num] != 0} {
	readpsf mtemp-nprot.psf
	coordpdb mtemp-nprot.pdb
    }
    
    # Saving all
    guesscoord
    writepdb $prefix.pdb
    writepsf $prefix.psf
    resetpsf
    
    # FEP
    if { [info exists cmdline(-FEP)] } {
	array set aa {
	    ALA   A
	    CYS   C
	    ASP   D
	    GLU   E
	    PHE   F
	    GLY   G
	    HSD   H
	    HSE   X
	    HSP   Z
	    ILE   I
	    LYS   K
	    LEU   L
	    MET   M
	    ASN   N
	    PRO   P
	    GLN   Q
	    ARG   R
	    SER   S
	    THR   T
	    VAL   V
	    TRP   W
	    TYR   Y
	}

	resetpsf
	puts "Reading hybrid topology from $feptopfile..."
	topology $feptopfile
	foreach i [lsort -unique [$prot get segname]] {
	    segment $i {
		pdb mtemp-$i.pdb
		set alpha [atomselect top "segname $i and resid $resid and alpha"]
		set oldres [$alpha get resname]
		set hyb [format "%s2%s" $aa($oldres) $aa([string toupper $mut])]
		if { [info exists cmdline(-ressegname)] } {
		    #puts "\n Mutator DEBUG: $i $ressegname"
		    if { $i == $ressegname } {
			puts "\n Mutator: Residue $oldres $resid of segment $ressegname is now $hyb"
			mutate $resid $hyb
			regenerate angles dihedrals
		    }
		} else {
		    puts "\n Mutator: Residue $oldres $resid of segment $i is now $hyb"
		    mutate $resid $hyb
		    regenerate angles dihedrals
		}
		$alpha delete
	    }
	    coordpdb mtemp-$i.pdb $i
	}
	
	# Reading non protein stuff
	if { [$notprot num] != 0} {
	    readpsf mtemp-nprot.psf
	    coordpdb mtemp-nprot.pdb
	}
	
	# Saving all fep
	guesscoord
	writepdb $fepprefix.fep.pdb
	writepsf $fepprefix.tmp.fep.psf
	
	# FEPfile	
	# Loading pdb 
    
	mol new $fepprefix.fep.pdb type pdb
	set prot [atomselect top "protein"]
	foreach i [lsort -unique [$prot get segname]] {
	    if { [info exists cmdline(-ressegname)] } {
		if { $i == $ressegname } {
		    set modified [atomselect top "segname $ressegname and resid $resid and not name N HN CA HA C O"]
		}
	    } else {
		set modified [atomselect top "segname $i and resid $resid and not name N HN CA HA C O"]
	    }
	}
	
	foreach i [$modified list] {
	    set temp [atomselect top "index $i"]
	    set letter [string index [$temp get name] end]
	    
	    # This works fine with standard patches
	    # Ideally, we should use a smarter test here to handle all possible patches
	    # We would need some additional data to identify mutated atoms
	    if { $letter == "A" } {
		lappend initial $i
	    } elseif { $letter == "B" } {
		lappend final $i
	    } else {
		puts "Mutator: WARNING - unexpected atom name [$temp get name]: belongs to a patch?"
	    }
            $temp delete
	}
	set init [atomselect top "index $initial"]
	set fin  [atomselect top "index $final"]
	
	$init set beta -1.0
	$fin  set beta 1.0
	
	animate write pdb $fepprefix.fep waitfor all
	
	#mol delete top

	# Run alchemify	
	set exit_code [alchemify $fepprefix.tmp.fep.psf $fepprefix.fep.psf $fepprefix.fep]

	if { $exit_code } {
	    puts "\n Mutator: ERROR --- Alchemify returned code $exit_code\n"
	} else {
	    puts "\n Mutator: Alchemify completed successfully.\n"
	}
	file delete -force $fepprefix.tmp.fep.psf
	file delete -force $fepprefix.fep.pdb
    }
    
    # Deleting temporary items
    foreach i [lsort -unique [$prot get segname]] {
	file delete -force mtemp-$i.pdb
    }
    if { [$notprot num] != 0} {
	file delete -force mtemp-nprot.psf
	file delete -force mtemp-nprot.pdb
    }
    
    mol delete top
    mol delete top

    # Loading mutated/hybrid system
    if { [info exists cmdline(-FEP)] } {
	mol load psf $fepprefix.fep.psf pdb $fepprefix.fep
	mol delrep 0 top
	mol representation Lines
	mol color Beta
	mol selection {all}
	mol material Opaque
	mol addrep top
    } else {
	mol load psf $prefix.psf pdb $prefix.pdb
    }
    
    # re-compute net charge of the system
    set sel [atomselect top all]
    set netCharge [eval "vecadd [$sel get charge]"]
    $sel delete
    puts "\n Mutator: System net charge after mutation: ${netCharge}e"
    
    puts "\n Mutator 1.1 completed successfully."
    puts "\n WARNING: mutations were performed using psfgen. Original backbone atom coordinates
were used for positions of backbone atoms of the new amino acid(s). Original coordinates of side
chain atoms named identically to atoms of the new amino acid(s) were used for positions of the new
side chain atoms. The position of the remaining atoms was guessed using internal coordinates for each amino acid.
It is therefore *highly recommended* to visually inspect the resulting structure and perform a 
minimization/equilibration of the system."
    puts "\n WARNING: special patches (disulfide bridges or neutral termini) in your protein may have been
eliminated while performing the mutation." 
    return 0
}

