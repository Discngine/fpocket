##
## NAMD Energy Evaluator Plugin
##
## A script for evaluating energies using NAMD, with a simple Tk 
## interface.
##
## Authors: Peter Freddolino, John Stone
##          vmd@ks.uiuc.edu
##
## $Id: namdenergy.tcl,v 1.50 2007/03/09 21:22:56 kvandivo Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/namdenergy
##
##  Example:
##    source namdenergy.tcl
##    set sel1 [atomselect top "resname ALA"]
##    namdenergy -vdw -sel $sel1 -ofile "out.dat" 
##    A list of all callable flags follows:
##      ts -- starting time step
##      stride -- stride at which the dcd was recorded/loaded
##      timemult -- length of timestep in fs
##      skip -- number of frames in dcd to skip between each calculation
##      par -- user defined parameter file
##      ofile -- file to output energy data
##      switch -- switch distance for namd
##      cutoff -- cutoff distance for namd
##      sel1 -- selection 1
##      sel2 -- selection 2
##      energy -- type of energy to be calculated
##      silent -- do not print output if this is set
##
##    All have sensible defaults except for energy and the selections
##


package require exectool 1.2
package require multiplot
package require readcharmmpar

package provide namdenergy 1.2

namespace eval ::namdEnergy:: {
  namespace export namdenergy
  namespace export namdenergy-parse

  #define package variables

  #FIXME: AUTO ID WHAT MOLECULE YOU"RE USING
  #Default force field parameters:
  variable defpar [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]
  #Output file object
  variable fout
  #Starting timestep and stride for dcd processing
  variable ts
  variable stride
  #Length of timestep (if not 1) and skip rate in dcds
  variable timemult
  variable skip
  variable silent
  variable debug
  variable jobname
  variable stype
  variable ctype
  variable switch
  variable cutoff
  variable extsystem ""
  variable nsel
  variable cfile
  variable energy
  variable psf
  variable par
  variable sel1 
  variable sel2
  variable usableMolLoaded 0
  variable currentMol
  variable pme
  variable enertypestring
  variable nullMolString "none"
  variable namdcmd "DUMMY"
  variable keepforce
  variable projforce
  variable cmvec ;# List of the vector between centers of mass of the selections
  variable runext 0 ;# If 1, we're going to run namd separately
  variable runextcommand "" ;# Command to run namd
  variable analyze 0 ;# If 1, we're just analyzing some previous output
  variable analyzefile "" ;# File with energy output that we want to parse
  variable plot 0 ;# Toggle whether we should plot the results
  variable use_biocore 0 ;# GUI toggle for using BioCoRE
  variable run 1;  # Toggle whether we should run NAMD or just prepare the input file
  variable server 0;  # Toggle whether we should prepare input for NAMD in server mode
  variable highprecisionenergies 0
  variable temperature 0;
  variable gui 0
  variable dielectric 1.0
  
  variable remjob_inputfiles {}
  variable remjob_outputfiles {}
  variable remjob_localdir {}
  variable remjob_id -1
  variable remjob_abort 0
  variable remjob_done
  variable biocore_params {}
  
  set keepforce 0
  set projforce 0
  set cmvec [list]


  set debug 0
  set currentMol $nullMolString
  variable molMenuText
  trace add variable [namespace current]::currentMol write ::namdEnergy::molmenuaux 


}

proc namdenergy { args }  { return [eval ::namdEnergy::namdenergy $args] }

proc ::namdEnergy::namdenergy_usage {} {
  puts "namdEnergy) Usage: namdenergy (-bond || -angl || -dihe || -impr || -conf || -vdw || -elec || -nonb || -all) -sel sel1 <sel2> <option1> <option2> ..."
  puts "namdEnergy) Options:"
  puts "namdEnergy)   -ofile <file> (name for file to output energy to)"
  puts "namdEnergy)   -tempname <prefix> (prefix for temporary files)"
  puts "namdEnergy)   -switch <switch> (set switching distance for VDW interactions to <switch>)"
  puts "namdEnergy)   -cutoff <cutoff> (set nonbond cutoff to <cutoff>)"
  puts "namdEnergy)   -skip <skip> (Calculate energy once every <skip> frames"
  puts "namdEnergy)   -ts <timestep> (Simulation starts at time <timestep>)"
  puts "namdEnergy)   -diel <dielectric> (Relative dielectric constant)"
  puts "namdEnergy)   -timemult <length> (Frames are <length> fs long)"
  puts "namdEnergy)   -stride <stride> (There were <stride> frames between each frame written to the trajectory)"
  puts "namdEnergy)   -par <file1> -par <file2> ... (Parameter files to use)"
  puts "namdEnergy)   -silent (If present, no energy output is printed)"
  puts "namdEnergy)   -debug (If present, temporary files will not be deleted)"
  puts "namdEnergy)   -keepforce (Show force output as well as energies)"
  puts "namdEnergy)   -projforce (Show projection of force onto distance between selection  centers of mass)"
  puts "namdEnergy)   -gui (Force creation of gui after parsing command line options)"
  puts "namdEnergy)   -extsys <file> (Set up boundary conditions from an xsc file)"
  puts "namdEnergy)   -pme (Use pme; requires extsys)"
  puts "namdEnergy)   -plot (Plot energies using multiplot)"
  puts "namdEnergy)   -norun (Only create NAMD input file, don't run NAMD)"
  puts "namdEnergy)   -server (Start NAMD in server mode; to be used with NAMDserver plugin)"
  puts "namdEnergy)   -T <temperature>"
  puts "namdEnergy)   -highprec (for servermode: use high precision energies)"
  puts "namdEnergy)   -runext biocore: Submit job in background using BioCoRE"
  puts "namdEnergy)   -biocoreparams <paramlist> : Parameter list { key1 value1 key2 value2... } needed to submit the BioCoRE run"
  error ""
}

proc ::namdEnergy::molmenuaux {mol index op} {
  #Accessory proc for the trace on currentMol
  variable currentMol
  variable molMenuText
  if { ! [catch { molinfo $currentMol get name } name ] } {
    set molMenuText "$currentMol: $name"
  } else { set molMenuText "$currentMol" }
}

proc ::namdEnergy::namdenergy { args } {
  #This is the frontend text proc for namdenergy; it will print all the usual
  #output and return a nested list containing all of the namdenergy output
  #(formatting of this list is in the documentation)

  #Set the standard defaults
  variable ofile ""
  variable fout
  variable ts     0;    # Starting timestep for a dcd
  variable stride 1;    # Stride in timesteps at which a dcd was written
  variable timemult 1; # Number of fs per timestep
  variable skip   0;    # Number of frames to skip between each calculation for a dcd
  variable silent 0;
  #FIXME: PROVIDE A RANDOM JOBNAME TO AVOID OVERLAPS
  variable jobname "namd"
  variable stype ""
  variable ctype ""
  variable cfile ""
  variable switch 10
  variable cutoff 12
  variable pme 0
  variable extsystem ""
  variable temperature 0
  variable nsel   0
  variable energy ""
  variable psf    ""
  variable par    [list]
  variable sel1   ""
  variable sel2   ""
  variable debug 0
  variable keepforce 0
  variable projforce 0
  variable currentMol
  variable runext
  variable runextcommand
  variable plot   0
  variable run    1
  variable server 0
  variable highprecisionenergies 0
  variable use_biocore 0
  variable biocore_params {}
  variable gui 0
  variable dielectric 1.0
  variable sfile
  set sfile ""
  set currentMol top

  if {$args == ""} {namdenergy_usage}
  

  # Get coordinate and structure files from VMD
  # Scan for single options
  set argnum 0
  set arglist $args
  set energylist {-all -bond -angl -dihe -impr -vdw -elec -nonb -conf -hbon}
  
  set energy ""
  foreach i $args {
    if {[lsearch $energylist [string range $i 0 4]]>=0}  then { 
      set energy "$i $energy" 
      set arglist [lreplace $arglist $argnum $argnum] 
      continue
    }
    if {$i == "-silent"} {
       set silent 1
       set arglist [lreplace $arglist $argnum $argnum]
       continue
    }
    if {$i == "-debug"} {
       set debug 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-pme"} {
      set pme 1
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-keepforce"} {
       set keepforce 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-projforce"} {
       set projforce 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-gui"} {
       set gui 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-plot"} {
       set plot 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-norun"} {
       set run 0; set gui 0
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-server"} { 
       set run 0; set gui 0; set server 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    if {$i == "-highprec"} { 
       set highprecisionenergies 1
       set arglist [lreplace $arglist $argnum $argnum] 
       continue
    }
    incr argnum
  }

  # Scan for the selections 
  set lower [lsearch $arglist "-sel"]
  if {$lower>=0}  then { 
     set upper [lsearch -start [expr $lower+1] $arglist "-*"]
 if {$upper == -1} {set upper [llength $arglist]}
     if {[expr $upper-$lower]>=2} { 
	set sel1 [lindex $arglist [expr $lower+1]]
	set nsel 1
     }
     if {[expr $upper-$lower]==3} { 
	set sel2 [lindex $arglist [expr $lower+2]]
	set nsel 2
     }
     set arglist [lreplace $arglist $lower [expr $upper-1]]
  }
# Set the proper molid
  set currentMol [$sel1 molid]
  if {$nsel==2 && [$sel1 molid] != [$sel2 molid]} {
    error "You cannot (currently) calculate interactions between two different molecules!"
    return
  }


  # Scan for options with one argument
  set argnum 0
  set otherarglist {}
  foreach {i j} $arglist {
    if {$i=="-tempname"}   then { set jobname $j; continue }
    if {$i=="-diel"}   then { set dielectric $j; continue }
    if {$i=="-ts"}   then { set ts $j; continue }
    if {$i=="-timemult"}   then { set timemult $j; continue }
    if {$i=="-stride"}   then { set stride $j; continue }
    if {$i=="-skip"}   then { set skip $j; continue }
    if {$i=="-par"}   then { lappend par $j; continue  }
    if {$i=="-ofile"} then { set ofile $j; continue  }
    if {$i=="-switch"} then { set switch $j; continue  }
    if {$i=="-cutoff"} then { set cutoff $j; continue  }
    if {$i=="-extsys"} then {set extsystem $j; continue }
    if {$i=="-runext"} then { set runext 1; set runextcommand $j; continue}
    if {$i=="-psf"}   then { set psf $j; set stype psf; continue  }
    if {$i=="-T"}   then { set temperature $j; continue  }
    if {$i=="-biocoreparams"}   then { set biocore_params "$j"; continue  }
#    if {$i=="-dcd"}   then { set cfile $j; set ctype dcd; continue  }
#    if {$i=="-pdb"}   then { set cfile $j; set cfile pdb; continue  }
    lappend otherarglist $i $j
  }

  #Run subproccesses to actually calculate the energy
  if {$gui == 1} {
    ::namdEnergy::namdenergy_mainwin 0
  } else {
    return [namdmain]
  }
}

proc ::namdEnergy::namdenergy-parse {file energytypes} {
  set result [parse_ener_output $energytypes $file]
  return result
}


proc ::namdEnergy::namdmain { } {
  #This proc takes the input harvested from the gui or the command line, and
  #Then actually runs the energy calculations we want
  variable ofile
  variable fout
  variable ts
  variable stride
  variable timemult
  variable skip
  variable silent
  variable jobname
  variable par
  variable stype
  variable ctype
  variable cfile
  variable switch
  variable cutoff
  variable nsel
  variable energy
  variable psf
  variable sel1
  variable sel2
  variable debug
  variable runext
  variable runextcommand
  variable plot
  variable use_biocore
  variable run
  variable gui
  variable currentMol
  variable dielectric
  variable sfile

  # Using the gui... set the flag
  set gui 1
  # If we used the gui, the use_biocore flag may be set, so transfer
  # those settings to the runext flags
  if {$use_biocore == 1} {
    puts "namdEnergy) Using BioCoRE"
    set runext 1
    set runextcommand "biocore"
  } else {
    set runext 0
    set runextcommand ""
  }
  
  foreach i [join [molinfo $currentMol get filetype]] j [join [molinfo $currentMol get filename]] {
    if {$i=="psf"} {
      set sfile $j
      set stype $i
    }
    if {$i=="parm" || $i=="parm7"} {
      set stype $i
      set sfile $j
    }
#    if {$i=="pdb" || $i=="dcd"} {
#      set ctype $i
#      set cfile $j
#    }
  }
  #if {$stype=="parm7"} { set par "$sfile" }

  # If no psf was specified explicitely, use the loaded psf if it exists
  if {![llength $psf] && $stype=="psf"} { 
     set psf "$sfile"
  }

  if {$debug != 0} {puts "namdEnergy) sanity"}
  sanitycheck
  if {$debug != 0} {puts "namdEnergy) namdconf"}
  namdconf
  

  if {$debug != 0} {puts "namdEnergy) namdrun"}
  if {$run} {
     namdrun
  } else {
     return 0
  }
  
  if {$runext == 1 && $runextcommand != "biocore" } {
    puts "namdEnergy) Your job is now running; when it is done, you can analyze the results by running namdenergy-parse ${jobname}-temp.log \"$energy\""
    return 0
  }
  
  if {$runext == 1 && $runextcommand == "biocore" } {
    if { $gui == 0 } {
      puts "namdEnergy) Your job has been submitted to BioCoRE. When it is done, you will be notified here, and you can analyze the results by running namdenergy-parse ${jobname}-temp.log \"$energy\""
    }
    return 0
  }
  
  # Only get here if its a local job running in-line
  namdmain2
}

proc ::namdEnergy::namdmain2 {} {
  variable keepforce
  variable ofile
  variable fout
  variable ts
  variable stride
  variable timemult
  variable skip
  variable silent
  variable jobname
  variable par
  variable stype
  variable ctype
  variable cfile
  variable switch
  variable cutoff
  variable nsel
  variable energy
  variable psf
  variable sel1
  variable sel2
  variable debug
  variable runext
  variable runextcommand
  variable plot
  variable use_biocore
  variable run
  variable gui
  variable dielectric
  variable enertypestring
  
  if {$ofile == ""} {set fout "stdout"} else {set fout [open $ofile "w"]}

  if {$debug != 0} {puts "namdEnergy) parse"}
  set result [parse_ener_output $energy ${jobname}-temp.log]
  set outputlist [lindex $result 0]

  if {$ofile != ""} {close $fout}

  if {$debug == 0} {cleanup}
  
  if {$plot == 1} {
    #Use multiplot to plot the energies
    set enerlist [split $energy]
    set xvals [gathervals 0 $outputlist] ;#x values for graph
    if {[llength $xvals] < 2} {puts "namdEnergy) Not plotting, because there's only one timestep" ; return $outputlist}
    set totalcol [lsearch [cleanlist [split $enertypestring]] "Total"]
    #puts [cleanlist [split $enertypestring] ]
    set totals [gathervals $totalcol $outputlist] ;#total energies
    set curenertype 2 ;# column we should be looking in for the next energy

    #Generate the initial plot with the total values plotted
    set plothandle [multiplot -x $xvals -y $totals -title "NAMDEnergy Plot" -xlabel "Timestep" -ylabel "Energy (kcal/mol)"]
    $plothandle configure -set 0 -lines -linewidth 4 -marker point -fillcolor black -radius 4 -legend "Total Energy"

      #Plot the other energies from our simulation, one by one
    if {[lsearch $enerlist "-bond"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-conf"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "red" "Bond Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-angl"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-conf"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "orange" "Angle Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-dihe"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-conf"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "yellow" "Dihedral Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-impr"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-conf"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "green" "Improper Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-elec"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-nonb"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "cyan" "Electrostatic Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-vdw"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-nonb"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "blue" "VdW Energies"
      #puts "DEBUG: Adding vdw energies $xvals | $curcol"
      incr curenertype
    }
    if {[lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-conf"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "violet" "Conformational Energies"
      incr curenertype
    }
    if {[lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-nonb"] >= 0} {
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle $curenertype $xvals $curcol "white" "Nonbond Energies"
      incr curenertype
    }
    # Plot forces as well, if we have them
    if {$keepforce != 0} {
      incr curenertype
      #puts "Taking column $curenertype from $outputlist"
      if {[lsearch $enerlist "-vdw"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-nonb"] >= 0} {
        set curcol [gathervals $curenertype $outputlist]
      #puts "DEBUG: Adding vdw forces $xvals | $curcol"
        addset $plothandle [expr $curenertype - 1] $xvals $curcol "blue" "VdW Forces (kcal/mol A)" 1
        incr curenertype
      }
      if {[lsearch $enerlist "-elec"] >= 0 || [lsearch $enerlist "-all"] >= 0 || [lsearch $enerlist "-nonb"] >= 0} {
        set curcol [gathervals $curenertype $outputlist]
        addset $plothandle [expr $curenertype - 1] $xvals $curcol "cyan" "Electrostatic Forces (kcal/mol A)" 1
        incr curenertype
      }
      set curcol [gathervals $curenertype $outputlist]
      addset $plothandle [expr $curenertype - 1] $xvals $curcol "black" "Total Forces (kcal/mol A)" 1
    }
      


    $plothandle replot
  }

  return $outputlist

}

proc ::namdEnergy::addset {plot curenertype xvals yvals color name {dash 0}} {
 $plot add $xvals $yvals
 if {$dash == 0} {
   $plot configure -set [expr $curenertype - 1] -lines -linewidth 4 -linecolor $color -color $color -marker point -radius 4 -fillcolor $color -legend $name -plot
 } else {
   $plot configure -set [expr $curenertype - 1] -lines -linewidth 4 -linecolor $color -color $color -marker point -radius 4 -dash "." -fillcolor $color -legend $name -plot 
 }
}

proc ::namdEnergy::gathervals {index array} {
  #Goes into a doubly nested list, and returns the index-th column
  set column [list]
  foreach row $array {
    lappend column [lindex $row $index]
  }

  return $column
}





proc ::namdEnergy::cleanup {} {
  #Removes any temp files generated by the run
  variable jobname
  foreach tempfile [glob ${jobname}-temp*] {file delete $tempfile}
}

proc ::namdEnergy::sanitycheck {} {
  #This proc checks that all is well with the input parameters that have been
  #specified, printing and returning an error code if there is a problem
  
  variable par
  variable defpar
  variable stype
  variable ctype
  variable nsel
  variable energy
  variable psf
  variable stype

  global env
  set defpar [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]

  #Check for use/existance of default parameter file
  if {![llength $par] && !($stype == "parm") && !($stype == "parm7")} {
    if {[file exists $defpar]} {
      puts "namdEnergy) Using default parameter file (charmm stype):"
      puts $defpar
      lappend par "$defpar"
    } else {
      puts $defpar
      error "No parameter file given, default parameter file not found:"
    }
  } 
  
  #Check for specification of psf
  if {($stype!="psf") && ($stype!="parm") && ($stype!="parm7")} {
    error "No structure file (psf) found!"
  }
  
#  if {!($ctype=="pdb" || $ctype=="dcd")} { 
#    error "No coordinate file (pdb/dcd) found!"
#  }
  
  #check that we got a selection
  if {$nsel==0} {
    error "No selection specified!"
  }

  #Check that our energy options are sane
  set energylist {-all -bond -angl -dihe -impr -vdw -elec -nonb -conf -hbon}
  if {![llength $energy]} {
    error "No energy type specified!\nUse one of \[$energylist\]"
  }
  
  set bondlist {all bond angl dihe impr conf}
  if {$nsel==2} {
    foreach bondener $bondlist {
      if {[lsearch -regexp $energy $bondener] > -1} {
          error "Interaction energy can only be computed for -vdw, -elec or -nonb!"
      }
    }
  }


}
          
proc ::namdEnergy::namdconf {} {
  # Write a namd configuration file to use in the run
  #Everything will be given the prefix $jobname

  variable jobname
  variable psf
  variable par
  variable ctype
  variable cfile
  variable cutoff
  variable extsystem
  variable switch
  variable nsel
  variable sel1
  variable sel2
  variable ts
  variable stride
  variable skip
  variable keepforce
  variable projforce
  variable currentMol
  variable temperature
  variable pme
  variable runext
  variable runextcommand
  variable remjob_inputfiles
  variable remjob_outputfiles
  variable dielectric
  variable stype
  variable sfile

  # Write the pair interaction PDB needed for NAMD to know what groups we care about
  #FIXME: Right now it is called $jobname-temp.pdb
  set notsel [atomselect $currentMol all frame first]
  set oldbetas [$notsel get beta]
  $notsel set beta 0
  $sel1 set beta 1
  if {$nsel != 1} {
    $sel2 set beta 2
  }

  $notsel writepdb ${jobname}-temp.pdb
  $notsel set beta $oldbetas
  set xyz [vecsub [lindex [measure minmax $notsel ] 1] [lindex [measure minmax $notsel] 0]]
  $notsel delete

  set namdconf [open ${jobname}-temp.namd w]
  lappend remjob_inputfiles [ file normalize "${jobname}-temp.namd" ]
  puts $namdconf "################################################################################\n
  
  # NAMD configuration file generated automatically by NAMDenergy\n
  # It may be ugly, but it should work.\n
  # I wouldn\'t recommend using it for anything else though.\n
  ################################################################################\n"

# Set up topology and parameters
  if {$stype == "parm" || $stype == "parm7"} {
    puts $namdconf "amber\t\ton"
    puts $namdconf "parmfile\t\t$sfile"
  } else {
  if { $runext == 1 && $runextcommand == "biocore" } {
    puts $namdconf "structure\t\t[file tail $psf]"
  } else {
    puts $namdconf "structure\t\t$psf"
  }
  lappend remjob_inputfiles "$psf"
  puts $namdconf "paraTypeCharmm\t\ton"
  puts "PARS: $par"
  foreach parfile $par {
    puts "$parfile"
    if { $runext == 1 && $runextcommand == "biocore" } {
       puts $namdconf "parameters\t\t[file tail $parfile]"
    } else {
       puts $namdconf "parameters\t\t$parfile"
    }
    lappend remjob_inputfiles "$parfile"
  }
  }

  puts $namdconf "numsteps\t\t 1"
  puts $namdconf "exclude\t\t\t scaled1-4"
  puts $namdconf "outputname\t\t ${jobname}-temp"
  lappend remjob_outputfiles "${jobname}-temp.coor"
  lappend remjob_outputfiles "${jobname}-temp.vel"
  
  puts $namdconf "temperature\t\t $temperature"
  if {$temperature==0} {
     puts $namdconf "COMmotion \t\t yes"
  }
#  if {$ctype == "pdb"} {puts $namdconf "coordinates\t\t$cfile"}
  puts $namdconf "cutoff\t\t\t $cutoff"
  puts $namdconf "dielectric\t\t $dielectric"
  if {$extsystem != ""} {
    puts $namdconf "extendedSystem\t\t\t $extsystem"
    lappend remjob_inputfiles "$extsystem"
    if {$pme != 0} {
      puts $namdconf "PME on\nPMEGridSizeX [expr int([lindex $xyz 0] * 1.2)]\nPMEGridSizeY [expr int([lindex $xyz 1] * 1.2)]\nPMEGridSizeZ [expr int([lindex $xyz 2] * 1.2)]\n"
    }
  }
  puts $namdconf "switchdist\t\t $switch"
  puts $namdconf "pairInteraction\t\t on"
  puts $namdconf "pairInteractionGroup1 1"
  puts $namdconf "pairInteractionFile   ${jobname}-temp.pdb"
  # Will be included after the "coordinates" command
  # lappend remjob_inputfiles "${jobname}-temp.pdb"
  
  if {$nsel == 1} {
    puts $namdconf "pairInteractionSelf\t\t on"
  } else {
    puts $namdconf "pairInteractionGroup2 2"
  }
  puts $namdconf "coordinates ${jobname}-temp.pdb"
  lappend remjob_inputfiles "${jobname}-temp.pdb"

  # Write the servermode settings
  variable server
  if {$server} {
     puts $namdconf ""
     variable highprecisionenergies
     if {$highprecisionenergies} {
	puts $namdconf "proc return_energies { labels values } {"
	puts $namdconf "   global socket requestedenergy printlabels"
	#     puts $namdconf "   print Labels: \$labels"
	#     puts $namdconf "   print Values: \$values"
	#     puts $namdconf "   print Total Energy: \[lindex \$values \[lsearch \$labels TOTAL\]\]"
	puts $namdconf "   if \{\$socket==0\} \{ return \}"
	puts $namdconf "   if \{\$requestedenergy==\"ALL\"\} \{"
	puts $namdconf "       set energy \$values"
	puts $namdconf "       puts \$socket \"ETITLE: \$labels\""
	puts $namdconf "   \} else \{"
	puts $namdconf "       set energy \[lindex \$values \[lsearch \$labels \$requestedenergy\]\]"
	puts $namdconf "   \}"
	puts $namdconf "   puts \$socket \"ENERGY: \$energy\""
	puts $namdconf "}\n"
	
	puts $namdconf "callback return_energies \n"
	
	puts $namdconf "set socket 0"
	puts $namdconf "set requestedenergy \"ALL\""
     } else {
	puts $namdconf "\# Must run one step to invoke molecule building and to get the ETITLE line"
	puts $namdconf "run 0"
     }

     puts $namdconf ""
     puts $namdconf "proc NAMD_Server \{port\} \{ \n   global sockid"
     puts $namdconf "   set sockid(main) \[socket -server NAMDAccept \$port\]"
     puts $namdconf "   puts \"NAMD_Server started. Listening...\""
     puts $namdconf "\} \n"
     
     puts $namdconf "proc NAMDAccept \{sock addr port\} \{\n   global sockid"
     puts $namdconf "   puts \"Accept \$sock from \$addr port \$port\""
     puts $namdconf "   set sockid(addr,\$sock) \[list \$addr \$port\]"
     puts $namdconf "   fconfigure \$sock -buffering line"
     puts $namdconf "   fileevent \$sock readable \[list read_data \$sock\]"
     puts $namdconf "   global socket"
     puts $namdconf "   set socket \$sock"
     puts $namdconf "\}\n"
     
     puts $namdconf "proc read_data \{sock\} \{\n   global sockid"
     puts $namdconf "   if \{\[eof \$sock\] || \[catch \{gets \$sock line\}\]\} \{"
     puts $namdconf "      # end of file or abnormal connection drop"
     puts $namdconf "      close \$sock"
     puts $namdconf "      puts \"Close \$sockid(addr,\$sock)\""
     puts $namdconf "      unset sockid(addr,\$sock)"
     puts $namdconf "      close \$sockid(main)"
     puts $namdconf "      \# This is going to stop NAMD:"
     puts $namdconf "      global forever"
     puts $namdconf "      set forever 0"
     puts $namdconf "   \} else \{"
     puts $namdconf "      if \{\[string compare \$line \"quit\"\] == 0\} \{"
     puts $namdconf "         \# Prevent new connections."
     puts $namdconf "         \# Existing connections stay open."
     puts $namdconf "         close \$sockid(main)"
     puts $namdconf "         \# Close current connection."
     puts $namdconf "         puts \$sock \"Closing server \$sockid(addr,\$sock)\""
     puts $namdconf "         close \$sock"
     puts $namdconf "         puts \"Close \$sockid(addr,\$sock)\""
     puts $namdconf "         unset sockid(addr,\$sock)"
     puts $namdconf "         \# This is going to stop NAMD:"
     puts $namdconf "         global forever"
     puts $namdconf "         set forever 0"
     puts $namdconf "      \}"
     puts $namdconf "      # Print what was sent and evaluate it as command"
     puts $namdconf "      puts \"\$line\""
     puts $namdconf "      if \{ \[catch \$line ret\] \} \{"
     puts $namdconf "         puts \$sock \"NAMD: Error executing '\$line'\""
     puts $namdconf "      \} else \{"
     puts $namdconf "         # Return the result"
     puts $namdconf "         puts \$sock \"\$ret\""
     puts $namdconf "      \}"
     puts $namdconf "   \}"
     puts $namdconf "\}\n"
     
     # With this function the client can request the evaluation of all
     # frames in the given dcd. Upon each "run 0" The calllback routine will 
     # be invoked which puts the energies into the socket. If an energy label is
     # specified then only this energy is returned.
     # The labels are returned for the first frame.
     puts $namdconf "proc compute_coordset \{dcdfile \{label ALL\}\} \{"
     puts $namdconf "   global requestedenergy printlabels socket"
     puts $namdconf "   set requestedenergy \$label"
     puts $namdconf "   set printlabels 1"
     puts $namdconf "   set ts 1"
     puts $namdconf "   coorfile open dcd \$dcdfile"
     puts $namdconf "   while \{ !\[coorfile read\] \} \{"
     puts $namdconf "      if \{\$ts==2\} \{ set printlabels 0 \}"
     puts $namdconf "      firstTimestep \$ts"
     puts $namdconf "      run 0"
     puts $namdconf "      incr ts 1"
     puts $namdconf "   \}"
     if {$highprecisionenergies} {
	puts $namdconf "   puts \$socket \"FINISHED WITH \[expr \$ts-1\] FRAMES.\""
	puts $namdconf "   flush \$socket"
     }
     puts $namdconf "   coorfile close"
     puts $namdconf "\}\n"
     
     puts $namdconf "NAMD_Server 11554 \n"
     puts $namdconf "vwait forever"

  } else {
     #Now that we're always using a dcd of whatever the user has loaded,
     #we always need to use dcd-reading logic
    if {[molinfo $currentMol get numframes] > 1} {
     puts $namdconf "set ts $ts\ncoorfile open dcd ${jobname}-temp.dcd"
     puts $namdconf "while \{ \!\[coorfile read\] \} \{"
     puts $namdconf "   firstTimestep \$ts\n   run 0\n   incr ts $stride"
     puts $namdconf "\}\ncoorfile close" 
     lappend remjob_inputfiles "${jobname}-temp.dcd"
   } else {
     puts $namdconf "run 0"
   }
  } 

  if {[catch {close $namdconf} err]} {
    error "Failed to write config file: $err"
  }
  
  # Write the pair interaction PDB needed for NAMD to know what groups we care about
  #FIXME: Right now it is called $jobname-temp.pdb
  set notsel [atomselect $currentMol all frame first]
  set oldbetas [$notsel get beta]
  $notsel set beta 0
  $sel1 set beta 1
  if {$nsel != 1} {
    $sel2 set beta 2
  }

  $notsel writepdb ${jobname}-temp.pdb
  $notsel set beta $oldbetas
  $notsel delete

  #Write a dcd to run the simulation on; this has whatever the user has loaded
  animate write dcd ${jobname}-temp.dcd waitfor all skip $skip $currentMol

  variable run
  if {!$run} { return }

  #Get the centers of mass for the parts of the trajectory we're looking at
  if {$keepforce != 0 && $nsel == 2} {

     variable cmvec
     set cmvec [list]
     for {set i 0} {$i < [molinfo $currentMol get numframes]} {incr i [expr $skip + 1]} {
	$sel1 frame $i
	$sel2 frame $i
	set cm1 [measure center $sel1 weight mass]
	set cm2 [measure center $sel2 weight mass]
	set cm12 [vecsub $cm1 $cm2]
	set cm12 [vecscale $cm12 1]
	lappend cmvec $cm12
     }
  }

    
#END NAMD SETUP PROC
}

proc ::namdEnergy::namdrun { } {
  #This proc actually runs the namd job from the configuration file $jobname.namd
  #This is ripe for expansion (or a separate module) to get a variety of run
  #targets available
  #Output goes to $jobname.log
  variable runext 
  variable runextcommand 
  variable nsel
  variable sel1
  variable sel2
  variable jobname
  variable namdcmd
  variable remjob_inputfiles
  variable remjob_outputfiles
  variable remjob_localdir

  if {$namdcmd == "DUMMY"} {
    set  namdcmd \
    [::ExecTool::find -interactive \
      -description "NAMD 2.x Molecular Dynamics Engine" \
      -path [file join /usr/local/bin/namd2] namd2]
  }

  if {$nsel==2} {
    if {[$sel1 num] == 0 || [$sel2 num] == 0} {
      error "Both selections must contain at least one atom"
    }
    puts "namdEnergy) \nComputing interaction energy between:"
    puts "namdEnergy) [$sel1 text]"
    puts "namdEnergy) and"
    puts "namdEnergy) [$sel2 text]\n"
  } else {
    if {[$sel1 num] < 2} {
      error "You must have at least 2 atoms in your selection for interaction energies"
    }
    puts "namdEnergy) Computing energy for selection:"
    puts "namdEnergy) [$sel1 text]\n"
  }
  
  #NOTE THAT THIS IS CURRENTLY A SINGLE THREADED WAY OF DOING THINGS; EVENTUALLY WE WANT TO HAVE THIS GEARED UP FOR BATCH SUBMISSION, SO WE'RE GOING TO HAVE TO INTRODUCE CHILD PROCESSES; I JUST DON'T FEEL LIKE FORKING THINGS YET (AND WE NEED TO DISCUSS IT)
  # Tell the user what's happening
  if {$runext == 0} {
    puts "namdEnergy) Running:"
    puts "namdEnergy) $namdcmd ${jobname}-temp.namd \n"
    #Run the job and put output into the log file
    exec $namdcmd ${jobname}-temp.namd > ${jobname}-temp.log
  } else {
    if {$runextcommand == "biocore" } {
      puts "namdEnergy) Input files: $remjob_inputfiles"
      puts "namdEnergy) Output files: $remjob_outputfiles"
      set remjob_localdir "[pwd]"
      run_remote
      return
    } else {
      set namdcommand $runextcommand
      set namdcommand [string map {INPUT ${jobname}-temp.namd LOGFILE ${jobname}-temp.log} $namdcommand]
      puts "namdEnergy) Running external analysis command $namdcommand"
      puts "namdEnergy) Input files: $remjob_inputfiles"
      puts "namdEnergy) Output files: $remjob_outputfiles"
      exec $namdcommand
    }
  }
}


proc ::namdEnergy::parse_ener_output {outputtype filename} {

  #This proc will parse the raw output from namd and return the desired energy data as part of a vector
  #The return will come as { bond angle dihedral improper elec vdw conf nonbond total} if -all is selected; otherwise, the elements which are requested will come in the order shown above
  #Output is assumed to be in a file called $filename

  variable fout
  variable ts
  variable stride
  variable timemult
  variable skip
  variable silent
  variable keepforce
  variable projforce
  variable nsel
  variable cmvec
  #Set the standard defaults
  #FIXME: PROVIDE A RANDOM JOBNAME TO AVOID OVERLAPS
  set jobname "namd"
  set silent 0
  set par   [list]
  set psf   ""
  set sfile ""
  set stype ""
  set cfile ""
  set ctype ""
  set ofile ""  
  set switch 10
  set cutoff 12
  set sel1 ""
  set sel2 ""
  set energy ""
  #Starting timestep for a dcd
  set ts 0
  #Stride in timesteps at which a dcd was written
  set stride 1
  #Number of frames to skip between each calculation for a dcd
  set skip 0
  #Number of fs per timestep
  set timemult 1
  set frame 0
  set skip1 [expr $skip + 1]
  set stride [expr $skip1 * $stride * $timemult]
  

  #Read the input
  set ifile [open $filename r]
#  set namdstring [read $ifile]
#  close $ifile

  #Initialize variables to hold lists of the output from all frames
  set outputlists [list]

  #Set up a header line for the output
  #Create the output headings and vector
  lappend lhead "Frame         "
  lappend lhead "Time          "
  set fstringh "%-12i  %-12i  "
  if ([regexp {all|bond|conf} $outputtype]) {lappend lhead "Bond          "}
  if ([regexp {all|angl|conf} $outputtype]) {lappend lhead "Angle         "}
  if ([regexp {all|dihe|conf} $outputtype]) {lappend lhead "Dihed         "}
  if ([regexp {all|impr|conf} $outputtype]) {lappend lhead "Impr          "}
  if ([regexp {all|elec|nonb} $outputtype]) {lappend lhead "Elec          "}
  if ([regexp {all|vdw|nonb} $outputtype]) {lappend lhead "VdW           "}
  if ([regexp {all|conf} $outputtype]) {lappend lhead "Conf          "}
  if ([regexp {all|nonb} $outputtype]) {lappend lhead "Nonbond       "}
  lappend lhead "Total         "
  if {$nsel == 2 && $keepforce != 0 && [regexp {all|vdw|nonb} $outputtype]} {lappend lhead "VdWForce      "}
  if {$nsel == 2 && $keepforce != 0 && [regexp {all|nonb|elec} $outputtype]} {lappend lhead "ElecForce     "}
  if {$nsel == 2 && $keepforce != 0} {lappend lhead "TotalForce    "}
  set headerstring [join $lhead ""]
  if {$silent != 1} { puts $fout "$headerstring" }

#  set namdlist [split $namdstring "\n"]
  set framenum 0

  set startts $ts
while {[gets $ifile enerstring] >= 0} {
  #Skip unless we're on an energy line
  if {[regexp {^ENERGY:} $enerstring] == 0} {continue}
#  puts "Search: [regexp {^ENERGY:} $enerstring] "
#  puts $enerstring
  #Initialize the variables to hold data from this frame
  set outputlist [list]
  #Next, make a list with all of the energy fields
  set enerlist [split $enerstring]
  set enerlist [cleanlist $enerlist]

  #Tally up what we want for conformation, nonbond, and total energies
  set confenergy [listsum [lrange $enerlist 2 5]]
        set nbenergy [listsum [lrange $enerlist 6 7]]
  
  #Create the output headings and vector
  lappend outputlist $frame
  lappend outputlist $ts
  if ([regexp {all|bond|conf} $outputtype]) {lappend outputlist [lindex $enerlist 2] }
  if ([regexp {all|angl|conf} $outputtype]) {lappend outputlist [lindex $enerlist 3] }
  if ([regexp {all|dihe|conf} $outputtype]) {lappend outputlist [lindex $enerlist 4] }
  if ([regexp {all|impr|conf} $outputtype]) {lappend outputlist [lindex $enerlist 5] }
  if ([regexp {all|elec|nonb} $outputtype]) {lappend outputlist [lindex $enerlist 6] }
  if ([regexp {all|vdw|nonb} $outputtype]) {lappend outputlist [lindex $enerlist 7] }
  set totalenergy [listsum [lrange $outputlist 2 end]]
  if ([regexp {all|conf} $outputtype]) {lappend outputlist $confenergy}
  if ([regexp {all|nonb} $outputtype]) {lappend outputlist $nbenergy}
  lappend outputlist $totalenergy

  #If we're keeping forces, get the force output as well
  if {$nsel == 2 && $keepforce != 0} {
  gets $ifile
  gets $ifile forcestring 
#  set forceindex [lsearch -regexp $namdlist "^PAIR INTERACTION:"]
#  if {$forceindex < 0} {break}
#  set forcestring [lindex $namdlist $forceindex]
#  set namdlist [lreplace $namdlist $forceindex $forceindex]
#puts "$forceindex $forcestring"


  #Parse the force line
  set forcelist [split $forcestring]
  set forcelist [cleanlist $forcelist]
  set vdwmag 0
  set elecmag 0

  if {$nsel == 2 && $keepforce != 0 && [regexp {all|vdw|nonb} $outputtype]} {
    set forceindex [lsearch -regexp  $forcelist "^VDW_FORCE"]
    set vdwvec [list]
    lappend vdwvec [lindex $forcelist [expr $forceindex + 1]] 
    lappend vdwvec [lindex $forcelist [expr $forceindex + 2]] 
    lappend vdwvec [lindex $forcelist [expr $forceindex + 3]]
    set vdwproj 1
    if {$projforce != 0} {
            if {[veclength $vdwvec] == 0} {
              set vdwproj 0
            } elseif {[veclength [lindex $cmvec $framenum]] == 0} {
              puts "namdEnergy) Warning: Encountered undefined distance vector on step $frame. Force calculations may not be valid."
              set vdwproj 1
            } else { 
              set vdwproj [vecdot [vecnorm $vdwvec] [vecnorm [lindex $cmvec $framenum]]]
            }
    }
    set vdwmag [expr $vdwproj * [veclength $vdwvec]]
    lappend outputlist $vdwmag
  }

  if {$nsel == 2 && $keepforce != 0 && [regexp {all|elec|nonb} $outputtype]} {
    set forceindex [lsearch -regexp  $forcelist "^ELECT_FORCE"]
    set elvec [list]
    lappend elvec [lindex $forcelist [expr $forceindex + 1]] 
    lappend elvec [lindex $forcelist [expr $forceindex + 2]] 
    lappend elvec [lindex $forcelist [expr $forceindex + 3]]
#    set elvec {[lindex $forcelist [expr $forceindex + 1]] [lindex $forcelist [expr $forceindex + 2]] [lindex $forcelist [expr $forceindex + 3]]}
    set elecproj 1
    if {$projforce != 0} {
            if {[veclength $elvec] == 0} {
              set elecproj 0
            } elseif {[veclength [lindex $cmvec $framenum]] == 0} {
              puts "namdEnergy) Warning: Encountered undefined distance vector on step $frame. Force calculations may not be valid."
              set elecproj 1
            } else { 
              set elecproj [vecdot [vecnorm $elvec] [vecnorm [lindex $cmvec $framenum]]]
            }
    }
    set elecmag [expr $elecproj * [veclength $elvec]]
    lappend outputlist $elecmag
  }

  set totforce [expr $vdwmag + $elecmag]
  lappend outputlist $totforce
  incr framenum
}

  #print the output line
  #There has GOT to be a prettier way to do this if my tcl-fu was stronger, but it works
  if {$silent != 1} {
    set outputstring [format $fstringh $frame $ts]
    set spacer "  "
    puts -nonewline $fout $outputstring
    for {set i 2} {$i < [llength $outputlist]} {incr i} {
      set addition [lindex $outputlist $i]
      puts -nonewline $fout [format "%-+12g" $addition]
      puts -nonewline $fout $spacer
    } 
    puts $fout ""
  }

  #add the output to our return data
  lappend outputlists $outputlist

  incr frame $skip1
  incr ts $stride 
}

  set ts $startts
  if {[catch {close $ifile} err]} {
    error "Couldn't write output file: $err"
  }

  variable enertypestring 
  set enertypestring $headerstring
  return [list $outputlists $headerstring]
}

proc ::namdEnergy::listsum {mylist} {
  #Returns the sum of elements of a list (I couldn't find a builtin for this)
  set sum [if {[llength $mylist]} {expr [join $mylist +]} {expr 0}]
  return $sum
}

proc ::namdEnergy::cleanlist {mylist} {
  #Returns a copy of mylist with all empty elements removed
  for {set i 0} {$i < [llength $mylist]} {incr i} {
    if {[lindex $mylist $i] != {}} {lappend newlist [lindex $mylist $i]}
  }
  return $newlist
}

proc ::namdEnergy::gui_init_defaults {} {
  variable w
  variable ofile
  variable fout
  variable ts
  variable stride
  variable timemult
  variable skip
  variable silent
  variable jobname
  variable par
  variable stype
  variable ctype
  variable cfile
  variable switch
  variable cutoff
  variable nsel
  variable energy
  variable psf
  variable par
  variable sel1
  variable sel2
  variable debug
  variable keepforce
  #Set the standard defaults
  #FIXME: PROVIDE A RANDOM JOBNAME TO AVOID OVERLAPS
  set jobname "namd"
  set silent 0
  set par   [list]
  set psf   ""
  set sfile ""
  set stype ""
  set cfile ""
  set ctype ""
  set ofile ""  
  set switch 10
  set cutoff 12
  set nsel 0
  set sel1 ""
  set sel2 ""
  set energy ""
  #Starting timestep for a dcd
  set ts 0
  #Stride in timesteps at which a dcd was written
  set stride 1
  #Number of frames to skip between each calculation for a dcd
  set skip 0
  #Number of fs per timestep
  set timemult 1
}

proc ::namdEnergy::namdenergy_mainwin {{defaults 1}} {
  variable w
  variable ofile
  variable fout
  variable ts
  variable stride
  variable timemult
  variable skip
  variable silent
  variable jobname
  variable par
  variable stype
  variable ctype
  variable cfile
  variable switch
  variable cutoff
  variable nsel
  variable energy
  variable psf
  variable par
  variable sel1
  variable sel2
  variable debug
  variable keepforce
  variable molMenuText
  variable plot
  variable pme
  variable extsystem 
  set extsystem ""

  if {$defaults == 1} {
    gui_init_defaults
  } else {
    set [namespace current]::seltext1 [$sel1 text]
    if {$nsel == 2} {set [namespace current]::seltext2 [$sel2 text]}
set enerlist [split $energy]
    if {[lsearch $enerlist "-all"] >= 0} {set [namespace current]::allflag 1}
    if {[lsearch $enerlist "-vdw"] >= 0} {set [namespace current]::vdwflag 1}
    if {[lsearch $enerlist "-elec"] >= 0} {set [namespace current]::elecflag 1}
    if {[lsearch $enerlist "-nonb"] >= 0} {set [namespace current]::nbflag 1}
    if {[lsearch $enerlist "-bond"] >= 0} {set [namespace current]::bondflag 1}
    if {[lsearch $enerlist "-angl"] >= 0} {set [namespace current]::anglflag 1}
    if {[lsearch $enerlist "-dihe"] >= 0} {set [namespace current]::dihedflag 1}
    if {[lsearch $enerlist "-impr"] >= 0} {set [namespace current]::impflag 1}
    if {[lsearch $enerlist "-conf"] >= 0} {set [namespace current]::confflag 1}
  }
    

#De-minimize if the window is already running
  if { [winfo exists .namdenergy] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".namdenergy"]
  wm title $w "NAMDEnergy"
  wm resizable $w yes yes
  set row 0

  #Add a menubar
  frame $w.menubar -relief raised -bd 2
  grid  $w.menubar -padx 1 -column 0 -columnspan 5 -row $row -sticky ew
  menubutton $w.menubar.help -text "Help" -underline 0 \
    -menu $w.menubar.help.menu
  $w.menubar.help config -width 5
  pack $w.menubar.help -side right
 
  ## help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About NAMD Energy" \
              -message "A tool for calculating interaction energies with NAMD."}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/namdenergy"
  incr row

  grid [label $w.mollable -text "Molecule: "] \
    -row $row -column 0 -sticky w
  grid [menubutton $w.mol -textvar [namespace current]::molMenuText \
    -menu $w.mol.menu -relief raised] \
    -row $row -column 1 -columnspan 4 -sticky ew
  menu $w.mol.menu -tearoff no
  incr row

  #Input for selection #1
  grid [label $w.sel1label -text "Selection 1: "] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel1 -width 30 \
    -textvariable [namespace current]::seltext1] \
    -row $row -column 1 -columnspan 4 -sticky ew
  incr row

  #Input for selection #2
  grid [label $w.sel2label -text "Selection 2 (opt): "] \
    -row $row -column 0 -sticky w
  grid [entry $w.sel2 -width 20 \
    -textvariable [namespace current]::seltext2] \
    -row $row -column 1 -columnspan 4 -sticky ew
  incr row

  #Selection of energy type
  grid [label $w.enerlabel -text "Energy Type: "] \
    -row $row -column 0 -columnspan 4 -sticky w 
  grid [checkbutton $w.allen -text "All   " -variable [namespace current]::allflag -anchor w] -row $row -column 1 -sticky w 
  grid [checkbutton $w.vdw -text "VDW   " -variable [namespace current]::vdwflag] -row $row -column 2 -sticky w
  grid [checkbutton $w.elec -text "Elec   " -variable [namespace current]::elecflag] -row $row -column 3 -sticky w
  grid [checkbutton $w.nbond -text "Nonbond" -variable [namespace current]::nbflag] -row $row -column 4 -sticky w
  incr row
  grid [checkbutton $w.bond -text "Bonds  " -variable [namespace current]::bondflag] -row $row -column 0 -sticky w
  grid [checkbutton $w.ang -text "Angles" -variable [namespace current]::angflag] -row $row -column 1 -sticky w
  grid [checkbutton $w.dihed -text "Dihedrals" -variable [namespace current]::dihedflag] -row $row -column 2 -sticky w
  grid [checkbutton $w.impr -text "Impropers  " -variable [namespace current]::impflag] -row $row -column 3 -sticky w
  grid [checkbutton $w.conf -text "Conformational" -variable [namespace current]::confflag] -row $row -column 4 -sticky w
  incr row

  #NAMD Parameters
  grid [label $w.ofilelabel -text "Output File: "] \
    -row $row -column 0 -sticky w
  grid [entry $w.ofile -width 10 \
    -textvariable [namespace current]::ofile] \
    -row $row -column 1 -columnspan 1 -sticky e
  grid [label $w.switchlabel -text "Switch: "] \
    -row $row -column 2 -sticky w
  grid [entry $w.switch -width 3 \
    -textvariable [namespace current]::switch] \
    -row $row -column 2 -columnspan 1 -sticky e
  frame $w.cutoffdielbox 
  label $w.cutoffdielbox.cutofflabel -text "Cutoff: "
  entry $w.cutoffdielbox.cutoff -width 3 -textvar [namespace current]::cutoff
  label $w.cutoffdielbox.diellabel -text "Dielectric: "
  entry $w.cutoffdielbox.diel -width 3 -textvar [namespace current]::dielectric
  grid $w.cutoffdielbox -row $row -column 3 -sticky ew
#  puts "err"
  pack $w.cutoffdielbox.cutofflabel $w.cutoffdielbox.cutoff -side left
  pack $w.cutoffdielbox.diel $w.cutoffdielbox.diellabel -side right -anchor e
#  puts "err1"
  grid [label $w.skiplabel -text "Skip: "] \
    -row $row -column 4 -sticky w
  grid [entry $w.skip -width 3 \
    -textvariable [namespace current]::skip] \
    -row $row -column 4 -columnspan 1 -sticky e
  incr row
  
  grid [label $w.jobnamelabel -text "Temp File Prefix: "] \
    -row $row -column 0 -sticky w
  grid [entry $w. -width 10 \
    -textvariable [namespace current]::jobname] \
    -row $row -column 1 -columnspan 1 -sticky e
  grid [label $w.tslabel -text "Timestep: "] \
    -row $row -column 2 -sticky w
  grid [entry $w.ts -width 3 \
    -textvariable [namespace current]::ts] \
    -row $row -column 2 -columnspan 1 -sticky e
  grid [label $w.tmlabel -text "Step Length: "] \
    -row $row -column 3 -sticky w
  grid [entry $w.tm -width 2 \
    -textvariable [namespace current]::timemult] \
    -row $row -column 3 -columnspan 1 -sticky e
  grid [label $w.stridelabel -text "Stride: "] \
    -row $row -column 4 -sticky w
  grid [entry $w.stride -width 3 \
    -textvariable [namespace current]::stride] \
    -row $row -column 4 -columnspan 1 -sticky e
  incr row

  grid [label $w.parlabel -text "Parameter Files (opt): "] \
    -row $row -column 0 -sticky w
  grid [entry $w.par -width 30 \
    -textvariable [namespace current]::par] \
    -row $row -column 1 -columnspan 2 -sticky e
  grid [button $w.parbutton -text "Find" \
    -command [ namespace code { 
      set partypes {
        {{Charmm Parameters} {.par .inp}}
        {{All Files} {*}}
      }
      set temploc [tk_getOpenFile -filetypes $partypes]
      if {$temploc != ""} {lappend par $temploc}
      }
    ]] -row $row -column 3 -columnspan 1 -sticky nsew
  grid [button $w.parresetbutton -text "Reset" \
    -command [ namespace code {
      set par [list] 
      set parfile ""
    }
    ]] -row $row -column 4 -columnspan 1 -sticky nsew
  incr row

  #Periodic boundary conditions
  grid [label $w.periodlabel -text "XSC File (opt): "] -row $row -column 0 -sticky w
  grid [entry $w.xscfile -width 20 -textvar [namespace current]::extsystem] -row $row -column 1 -columnspan 2 -sticky ew
  frame $w.xscbuttons 
  button $w.xscbuttons.xscbrowse -text "Browse" -command [ namespace code {
        set filetypes { 
          {{NAMD xsc file} {.xsc}}
          {{All Files} {*}}
        }
        set ::namdEnergy::extsystem [tk_getOpenFile -filetypes $filetypes]
    }
  ]
  button $w.xscbuttons.xscgen -text "Generate" -command ::namdEnergy::xscgengui
  pack $w.xscbuttons.xscbrowse $w.xscbuttons.xscgen -side left -fill x 
  grid $w.xscbuttons -row $row -column 3 -columnspan 1 -sticky nsew 
  grid [checkbutton $w.pmebutton -text "PME" -variable [namespace current]::pme] -row $row -column 4 -sticky w
  incr row

  #Other random stuff
  grid [checkbutton $w.silent -text "Silent   " -variable [namespace current]::silent] -row $row -column 0 -sticky w
  grid [checkbutton $w.debug -text "Debug" -variable [namespace current]::debug] -row $row -column 1 -sticky w
  grid [checkbutton $w.force -text "Show Force Output  " -variable [namespace current]::keepforce] -row $row -column 2 -sticky w
  grid [checkbutton $w.forcep -text "Show Only Force Projection" -variable [namespace current]::projforce] -row $row -column 3 -sticky w
  grid [checkbutton $w.plot -text "Plot output  " -variable [namespace current]::plot] -row $row -column 4 -sticky w
  incr row
  

  grid [button $w.gobutton -text "Run NAMDEnergy" \
    -command [ namespace code {
      mol top $currentMol
      variable sel1
      variable sel2
      variable nsel
      set energy ""
      set psf ""
      if {$allflag != 0} {set energy "-all $energy"}
      if {$vdwflag != 0} {set energy "-vdw $energy"}
      if {$elecflag != 0} {set energy "-elec $energy"}
      if {$nbflag != 0} {set energy "-nonb $energy"}
      if {$bondflag != 0} {set energy "-bond $energy"}
      if {$angflag != 0} {set energy "-angl $energy"}
      if {$dihedflag != 0} {set energy "-dihe $energy"}
      if {$impflag != 0} {set energy "-impr $energy"}
      if {$confflag != 0} {set energy "-conf $energy"}
      if {$seltext1 != ""} {set nsel 1 ; set sel1 [atomselect top "$seltext1"]}
      if {$seltext2 != ""} {set nsel 2 ; set sel2 [atomselect top "$seltext2"]}
      namdmain
      $sel1 delete
      if {$nsel==2} {$sel2 delete}
      }
      ]] -row $row -column 0 -columnspan 3 -sticky nsew 
  
  grid [radiobutton $w.usebiocore \
    -text "Run job remotely (BioCoRE)"  -value "1" \
    -variable ::namdEnergy::use_biocore -anchor w] \
    -row $row -column 3 -columnspan 1 -sticky nsew
    
  grid [radiobutton $w.uselocal \
    -text "Run job locally"  -value "0" \
    -variable ::namdEnergy::use_biocore -anchor w ] \
    -row $row -column 4 -columnspan 1 -sticky nsew

  incr row
    
  fill_mol_menu $w.mol.menu
  trace add variable ::vmd_initialize_structure write \
    ::namdEnergy::vmd_init_struct_trace
}

proc ::namdEnergy::vmd_init_struct_trace {structure index op} {
  variable w
  #Accessory proc for traces on the mol menu
  fill_mol_menu $w.mol.menu
}



proc ::namdEnergy::fill_mol_menu {name} {
  #Proc to get all the current molecules for a menu
  #For now, shamelessly ripped off from the PME plugin
  variable usableMolLoaded
  variable currentMol
  variable nullMolString
  $name delete 0 end

  set molList ""
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      lappend molList $mm
      $name add radiobutton -variable [namespace current]::currentMol \
      -value $mm -label "$mm [molinfo $mm get name]"
    }
  }

#set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
      set currentMol [molinfo top]
      set usableMolLoaded 1
    } else {
      set currentMol $nullMolString
      set usableMolLoaded  0
    }
  }
}


# This gets called by VMD the first time the menu is opened.
proc namdenergy_tk_cb {} {
  ::namdEnergy::namdenergy_mainwin
  return $::namdEnergy::w
}

proc ::namdEnergy::xscgengui {} {
  variable xlen 0
  variable ylen 0
  variable zlen 0
  variable xcen 0
  variable ycen 0
  variable zcen 0

  if {[winfo exists .xscgen]} {
    wm deiconify .xscgen
    raise .xscgen
    return
  }

  set w [toplevel ".xscgen"]
  wm title $w "Generate XSC File"
  wm resizable $w no no

  set row 0
  # Cell lengths
  grid [label $w.xlenlabel -text "X length:"] -row $row -column 0 -sticky w
  grid [entry $w.xlen -width 5 -textvar ::namdEnergy::xlen] -row $row -column 1 -sticky ew
  grid [label $w.ylenlabel -text "Y length:"] -row $row -column 2 -sticky w
  grid [entry $w.ylen -width 5 -textvar ::namdEnergy::ylen] -row $row -column 3 -sticky ew
  grid [label $w.zlenlabel -text "Z length:"] -row $row -column 4 -sticky w
  grid [entry $w.zlen -width 5 -textvar ::namdEnergy::zlen] -row $row -column 5 -sticky ew

  incr row
  # Cell center
  grid [label $w.xcenlabel -text "X center:"] -row $row -column 0 -sticky w
  grid [entry $w.xcen -width 5 -textvar ::namdEnergy::xcen] -row $row -column 1 -sticky ew
  grid [label $w.ycenlabel -text "Y center:"] -row $row -column 2 -sticky w
  grid [entry $w.ycen -width 5 -textvar ::namdEnergy::ycen] -row $row -column 3 -sticky ew
  grid [label $w.zcenlabel -text "Z center:"] -row $row -column 4 -sticky w
  grid [entry $w.zcen -width 5 -textvar ::namdEnergy::zcen] -row $row -column 5 -sticky ew

  incr row
  # Action buttons
  grid [button $w.guessbutton -text "Guess from molecule" -command ::namdEnergy::guess_xsc] -row $row -column 0 -columnspan 3
  grid [button $w.setbutton -text "Done" -command {
        ::namdEnergy::writexscfile
        grab release .xscgen 
        after idle destroy .xscgen 
      }] -row $row -column 3 -columnspan 3

}

proc ::namdEnergy::guess_xsc {} {
  variable xlen 
  variable ylen 
  variable zlen
  variable xcen 
  variable ycen 
  variable zcen  
  variable currentMol

  set fullsel [atomselect $currentMol all]
  set minmax [measure minmax $fullsel]
  set center [measure center $fullsel]

  set diff [vecsub [lindex $minmax 1] [lindex $minmax 0]]
  set xlen [lindex $diff 0]
  set ylen [lindex $diff 1]
  set zlen [lindex $diff 2]
  set xcen [lindex $center 0]
  set ycen [lindex $center 1]
  set zcen [lindex $center 2]

  $fullsel delete
}

proc ::namdEnergy::writexscfile {} {
  variable xlen 
  variable ylen 
  variable zlen
  variable xcen 
  variable ycen 
  variable zcen
  variable jobname
  variable extsystem

  set ofile [open "${jobname}-temp.xsc" "w"]
  puts $ofile "# NAMD extended system configuration file"
  puts $ofile "# Generated by NAMDEnergy"
  puts $ofile "#\$LABELS step a_x a_y a_z b_x b_y b_z c_x c_y c_z o_x o_y o_z"
  puts $ofile "0 $xlen 0 0 0 $ylen 0 0 0 $zlen $xcen $ycen $zcen"
  if { [catch {close $ofile} err] } {
    error "Couldn't properly write xsc file: $err"
  }

  set extsystem "${jobname}-temp.xsc"
}

proc ::namdEnergy::run_remote { } {
  variable jobname
  variable gui
  variable remjob_id
  variable remjob_inputfiles
  variable remjob_outputfiles
  variable remjob_localdir
  
  puts "namdEnergy) Running on biocore"
  if { $gui == 0 } {
    puts "namdEnergy) BioCoRE not yet implemented in text mode"
    return
  }
  
  if { $remjob_id == -1 } {
    set remjob_id [ ::ExecTool::remjob_create_job ]
  } else {
    if { $gui } {
      set res [tk_dialog .biocore_err "Job already running" \
        "It looks like there's already a job running. Forget about old job?" \
        error 0 "Forget old job" "Keep waiting" ]
      if { $res == 0 } {
        cancel_biocore_job $remjob_id 1
      }
    } else {
      puts "namdEnergy) It looks like there's already a job running. To ignore it, run \"::namdEnergy::cancel_biocore_job $remjob_id 0\""
    }
    return
  }
  
  set err [::ExecTool::remjob_config_prog $remjob_id "biocore" 1]
  if { $err != 0 } {
    tk_dialog .biocore_err "BioCoRE Connection Problem" \
      "Connection to BioCoRE failed. Cancelling job." \
      error 0 "Ok"
    cancel_biocore_job $remjob_id 0
    puts "namdEnergy) remjob_config_prog error $err"
    return
  }
  
  set now [ clock seconds ]
  set namesuffix [ clock format $now -format %G%m%d ].[expr $now % 100000]
  set myjobname $jobname.$namesuffix

  set job(biocore_jobName) [list $myjobname ]
  set job(biocore_jobDesc) [list "VMD NAMDEnergy plugin" ]
  set job(biocore_workDir) [list $myjobname ]
  set job(biocore_cmd) [list "namd2" ]
  set job(biocore_cmdParams) [list "${jobname}-temp.namd" ]
  
  set err [ ::ExecTool::remjob_config_account $remjob_id \
    [ array get job ] {::namdEnergy::run_remote2} \
    {::namdEnergy::cancel_biocore_job} ]
    
  if { $err != 0 } {
    puts "namdEnergy) run_remote error $err"
  }
  return
}

proc ::namdEnergy::cancel_biocore_job { job_id { show_cancel_dialog 1 }} {
  variable gui
  variable remjob_id

  if { $gui == 1 && $show_cancel_dialog } {
    remjob_biocore_message_dialog "Your remote NAMD job has not been submitted"
  }
  puts "namdEnergy) job cancelled"
  set remjob_id -1
}

proc ::namdEnergy::run_remote2 { job_id } {
  variable gui
  
  set err [ finish_config $job_id ]
  if { $err != 0 } {
    if { $gui == 1 } {
      switch $err {
        infileerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The input files could not be read from your local machine, or namdEnergy was unable to connect to BioCoRE. Try logging in to BioCoRE again via the Extensions:BioCoRE:Login menu, and try running your job again. (Error: $err)"
        }
        stdoutfileerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The filename specified for the NAMD standard output is not writeable. (Error: $err)"
        }
        stderrfileerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The filename specified for the NAMD standard error is not writeable. (Error: $err)"
        }
        outputfileerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. One of the output files requested from the run is not writeable. (Error: $err)"
        }
        validateerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The job failed validation. Try logging in to BioCoRE again via the Extensions:BioCoRE:Login menu, and try running your job again. (Error: $err)"
        }
        sendfileerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The input files could not be sent to BioCoRE. Try logging in to BioCoRE again via the Extensions:BioCoRE:Login menu, and try running your job again. (Error: $err)"
        }
        runerr {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. The job could not be submitted. Try logging in to BioCoRE again via the Extensions:BioCoRE:Login menu, and try running your job again. (Error: $err)"
        }
        default {
          remjob_biocore_message_dialog "There was a problem submitting your job to BioCoRE. Try logging in to BioCoRE again via the Extensions:BioCoRE:Login menu, and try running your job again. (Error: $err)"
        }
      }
    } else {
      puts "namdEnergy) Error submitting job: $err"
    }
    cancel_biocore_job $job_id 0

  } else {
    if { $gui == 1 } {
      remjob_biocore_message_dialog "Your remote NAMD job has been submitted to BioCoRE. A message will inform you when it is complete"
    } else {
      puts "namdEnergy) Your remote NAMD job has been submitted to BioCoRE. A message will inform you when it is complete"
    }
    # Wait for completion
    ::namdEnergy::biocore_reschedule_status_check
  }
}

proc ::namdEnergy::finish_config { job_id } {
  variable jobname
  variable remjob_id
  variable remjob_localdir
  variable remjob_inputfiles
  variable remjob_outputfiles
  variable gui
  
  # Set up the input file list for staging  
  foreach f $remjob_inputfiles {
    set err [::ExecTool::remjob_config_input_file $remjob_id $f]
    if { $err != 0 } {
      puts "namdEnergy) config_input_file error\[$f\]: $err"
      return "infileerr"
    }
  }
  
  # Config stdout and stderr
  set err [::ExecTool::remjob_config_stdout_file $remjob_id $remjob_localdir \
      "${jobname}-temp.log" 0]
  if { $err != 0 } {
    puts "namdEnergy) config_stdout_file error <$remjob_id,$remjob_localdir,${jobname}-temp.log>: $err"
    return "stdoutfileerr"
  }
  set err [::ExecTool::remjob_config_stderr_file $remjob_id $remjob_localdir \
      "${jobname}-temp.err" 0]
  if { $err != 0 } {
    puts "namdEnergy) config_stderr_file error: <$remjob_id,$remjob_localdir,${jobname}-temp.log>: $err"    
    return "stderrfileerr"
  }
  
  # Set up the output files
  foreach f $remjob_outputfiles {
    set err [ ::ExecTool::remjob_config_output_file $remjob_id \
      $remjob_localdir $f 0 ]
    if { $err != 0 } {
      puts "namdEnergy) Config_output_file error \[$f\]: $err"
      return "outfileerr"
    }
  }
  
  # Make sure the job is set up correctly  
  set err [::ExecTool::remjob_config_validate $remjob_id ]
  if { $err != 0 } {
    puts "namdEnergy) config_validate error: $err"
    return "validateerr"
  }

  # Send the input files
  set err [::ExecTool::remjob_send_files $remjob_id]
  if { $err != 0 } {
    puts "namdEnergy) send_files error $err"
    return "sendfileerr"
  }
  
  # Start the job
  set err [::ExecTool::remjob_run $remjob_id]
  if { $err != 0 } {
    puts "namdEnergy) remjob_run error $err"
    return "runerr"
  }
  return 0
}

proc ::namdEnergy::biocore_check_status {} {
  variable remjob_id
  variable remjob_abort
  
  set status [ ::ExecTool::remjob_poll $remjob_id ]
  if { $status == -1 || $status == -2 } {
    puts "namdEnergy) Error retrieving status $status"
  }
  
  if { [ ::ExecTool::remjob_isComplete $status ] } {
    after idle { ::namdEnergy::biocore_retrieve_files }
    return
  }

  if { !$remjob_abort } {
    # Wait 5 seconds, then check again
    after 5000 { ::namdEnergy::biocore_reschedule_status_check }
  } else {
    puts "namdEnergy) namdEnergy status check aborted"
  }
}

proc ::namdEnergy::biocore_reschedule_status_check {} {
  # Only check if we are otherwise idle
  after idle { after 0 ::namdEnergy::biocore_check_status }
}

proc ::namdEnergy::biocore_retrieve_files {} {
  variable jobname
  variable energy
  variable gui
  variable ofile
  variable fout
  variable remjob_outputfiles
  variable remjob_id
  variable remjob_done
  
  puts "namdEnergy) Retrieving files"
  foreach f [ concat $remjob_outputfiles "${jobname}-temp.log" "${jobname}-temp.err"] {
    puts "namdEnergy) Getting $f"
    set err [ ::ExecTool::remjob_get_file $remjob_id $f ]
    if { $err != 0 } {
      puts "namdEnergy) Error retrieving $f: $err"
    }
  }
  
  # Actually go get the files
  set handle [ ::ExecTool::remjob_start_transfer $remjob_id ]
  if { $handle < 0 }  {
    puts "namdEnergy) Error start_transfer: $handle"
  }
  
  # Wait for transfer to complete
  set file_status 0
  while { $file_status != 1 } {
    after 10000
    set file_status [ ::ExecTool::remjob_waitfor_transfer $remjob_id $handle ]
    if { $file_status < 0 } {
      puts "namdEnergy) File transfer status: $file_status"
      break
    }
  }
  
  puts "namdEnergy) Got files"
  if { $gui == 1 } {
    remjob_biocore_message_dialog "Your remote NAMD job is complete. The results will now appear in the VMD console"
    namdmain2
  } else {
    puts "namdEnergy) namdEnergy is complete: analyzing results"
    namdmain2
  }
  set remjob_done 1
}

# Private remjob_biocore_error_dialog
# Convenience function for displaying a dialog box when some internal
# error occurs
proc ::namdEnergy::remjob_biocore_message_dialog { msg } {
  tk_dialog .biocore_msg "NAMDEnergy Message" \
    $msg "" 0 "Okay"
}
