package require exectool
package provide cionize 1.0

namespace eval ::cionize:: {
  namespace export cionize

  # variables for package settings
  variable jobname ;# prefix for output files
  variable tmpname ;# prefix for temporary files
  variable r_ion_solute 
  variable r_ion_ion
  variable bordersize
  variable gridspacing
  variable gridfile
  variable xyzdim
  variable gridout ;# Grid output before ion placement
  variable gridafter ;# Grid output after ion placement
  variable ions ;# list of ions to be placed
  variable nprocs
  variable runtype ;# Calculation method to be used
  variable molid ;# Molecule ID to run on
}

proc ::cionize::init_defaults {} {
# Initialize all of the namespace variables. Should be called before each run
  variable jobname 
  variable tmpname
  variable r_ion_solute 
  variable r_ion_ion
  variable bordersize
  variable gridspacing
  variable gridfile
  variable gridafter
  variable xyzdim
  variable gridout
  variable ions 
  variable nprocs
  variable runtype 
  variable molid

  set jobname "cionize"
  set tmpname "cionize-temp"
  set r_ion_solute ""
  set r_ion_ion ""
  set bordersize ""
  set gridspacing ""
  set gridfile ""
  set xyzdim ""
  set gridout ""
  set gridafter ""
  set ions ""
  set nprocs 1
  set runtype "single"
  set molid ""
}

proc ::cionize::show_usage {} {
# Give usage instructions
  puts "cionize: Calculate a coulombic potential and place ions"
  puts "Usage: cionize -mol <molnumber> <option1> <option2>..."
  puts "Options:"
  puts "  Switches:"
  puts "    -mg (Use multilevel summation approximation)"
  puts "    -dp (Use double precision calculation)"
  puts "  Single argument options:"
  puts "    -mol <molecule> (REQUIRED: Run on molid <molecule>)"
  puts "    -prefix <prefix> (Use <prefix> as the prefix for output files"
  puts "    -ris <radius> (Enforce a minimum ion-solute distance of <radius>)"
  puts "    -rii <radius> (Enforce a minimum ion-ion distance of <radius>)"
  puts "    -border <length> (Pad the system by <length> in each direction)"
  puts "    -gridspacing <spacing> (Density of potential grid)"
  puts "    -ingrid <file> (Read grid from <file> instead of calculating it)"
  puts "    -xyzdim <xmin ymin zmin xmax ymax zmax> (Use specified grid boundary)"
  puts "    -go <file> (Output grid to <file> after potential calculation)"
  puts "    -ga <file> (Output grid to <file> after ion placement)"
  puts "    -np <number> (Use <number> processors)"
  puts "  Ion placement options:"
  puts "    -ions <ionstring> (Place ions contained in <ionstring>"
  puts "    <ionstring> should be a set of bracket enclosed ions, with each ion"
  puts "     containing the information {name number charge} for the ion to be"
  puts "     placed. <ionstring> should be contained in quotes; e.g.,"
  puts "     \"\{SOD 4 1\} \{CLA 4 -1\}\" places 4 sodium and for chloride ions."
}

proc ::cionize::cionize { args } {
# perform a cionize run

  puts "Starting cionize..."

  init_defaults

  set numargs [llength $args]
  if {$numargs == 0} {show_usage; return}

# Parse command line arguments
  if {[parse_args $args] != 0} {show_usage; return}

# Construct cionize input file
  set infile [write_input_file]

# Run cionize
  run_cionize $infile

# clean up
  cleanup_cionize_run 

  puts "cionize completed! See VMD Console for details"

}

proc ::cionize::parse_args {argblock} {
# Parse all command line arguments to cionize and set the correct
# namespace variables. Return 0 on success, other value on failure
  variable jobname 
  variable tmpname
  variable r_ion_solute 
  variable r_ion_ion
  variable bordersize
  variable gridspacing
  variable gridfile
  variable gridafter
  variable xyzdim
  variable gridout
  variable ions 
  variable nprocs
  variable runtype 
  variable molid

  #puts "Argblock: $argblock"
  #puts "Args: [lindex $argblock 0]"
  set args $argblock

  set argnum 0
  set arglist $args

# Parse switches
  foreach i $args {
    if {$i == "-mg"} {
      if {$runtype == "double"} {
        puts "WARNING: Can only choose one of -dp or -mg. Using multilevel summation."
      }
      set runtype "multigrid"
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }

    if {$i == "-dp"} {
      if {$runtype == "multigrid"} {
        puts "WARNING: Can only choose one of -dp or -mg. Using double precision."
      }
      set runtype "double"
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }

    incr argnum
  }

# Parse single option variables
  set otherarglist {} 
#  puts "Arglist: $arglist"
  foreach {i j} $arglist {
#    puts "Parsing $i | $j"
    if {$i == "-mol"} { set molid $j ; continue}
    if {$i == "-prefix"} { 
      set jobname "$j"
      set tmpname "$j-temp"
      continue
    }
    if {$i == "-ris"} {set r_ion_solute $j; continue}
    if {$i == "-rii"} {set r_ion_ion $j; continue}
    if {$i == "-border"} {set bordersize $j; continue}
    if {$i == "-ingrid"} {set gridfile $j; continue}
    if {$i == "-go"} {set gridout $j; continue}
    if {$i == "-ga"} {set gridafter $j; continue}
    if {$i == "-np"} {set nprocs $j; continue}
    if {$i == "-ions"} {set ions $j; continue}
    if {$i == "-gridspacing"} {set gridspacing $j; continue}
    lappend otherarglist $i $j
  }

  if {[llength $otherarglist] > 0} {
    puts "WARNING: Unrecognized command line arguments $otherarglist will be ignored"
  }

  return 0

}

proc ::cionize::write_input_file {} {
# Write an input file for cionize based on the defined namespace variables

  variable jobname 
  variable tmpname
  variable r_ion_solute 
  variable r_ion_ion
  variable bordersize
  variable gridspacing
  variable gridfile
  variable gridafter
  variable xyzdim
  variable gridout
  variable ions 
  variable nprocs
  variable runtype 
  variable molid

  set inpfile [open "$jobname.in" "w"]

  if {$r_ion_solute != ""} {puts $inpfile "R_ION_SOLUTE $r_ion_solute"}
  if {$r_ion_ion != ""} {puts $inpfile "R_ION_ION $r_ion_ion"}
  if {$bordersize != ""} {puts $inpfile "BORDERSIZE $bordersize"}
  if {$gridspacing != ""} {puts $inpfile "GRIDSPACING $gridspacing"}
  if {$xyzdim != ""} {puts $inpfile "XYZDIM $xyzdim"}
  if {$gridfile != ""} {puts $inpfile "GRIDFILE $gridfile"}

  puts $inpfile "BEGIN"

  if {$gridout != ""} {puts $inpfile "SAVEGRID $gridout"}
  set ionnum 1
  foreach ion $ions {
    set name [lindex $ion 0]
    set n [lindex $ion 1]
    set charge [lindex $ion 2]
    set oname "$jobname-ions_$ionnum-$name.pdb"
    puts $inpfile "PLACEION $name $n $charge"
    puts $inpfile "SAVEION $oname"
  }
  if {$gridafter != ""} {puts $inpfile "SAVEGRID $gridafter"}
  
  close $inpfile
  return "$jobname.in"
}

proc ::cionize::run_cionize { inputfile } {
# Run cionize on the chosen input file
  global env
  variable molid
  variable tmpname
  variable runtype
  variable nprocs

# First write the structure to be ionized
  set sel [atomselect $molid all]
  $sel writepqr $tmpname.pqr
  $sel delete

# Find and run cionize
  eval ::ExecTool::exec "$env(CIONIZEBINDIR)/cionize" -i $inputfile -m $runtype -p $nprocs $tmpname.pqr >&@ stdout

}

proc ::cionize::cleanup_cionize_run {} {
  variable tmpname

  file delete [glob "$tmpname*"]
}


