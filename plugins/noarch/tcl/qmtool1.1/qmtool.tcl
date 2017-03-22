#
# QM tool plugin for setting up QM jobs
#
# $Id: qmtool.tcl,v 1.43 2007/09/12 13:41:59 saam Exp $
#
# QMtool is a graphical user interface for quantum chemical simulations.
# Currently only Gaussian is supported but future versions will also support
# GAMESS. With QMtool you can easily set up many different kinds of QM
# simulation such as geometry optimizations and freqency calculations,
# specify solvents and more. After you ran the simulation you can load the
# QM logfiles and analyze the results such as plotting energies or the IR
# spectrum. You can also get a detailed thermochemistry analysis and you can
# graphically study the normal modes or (for frequency calculations). Even
# though QMtool simplifies the setup significantly and does some error
# checking on the input, it is indispensable that you have an idea of what
# you're doing. Consult the Gaussian manual!

#  Features of QMtool include:
#  -----------------------------

#  Reading several input formats:
#     - Z-matrix files
#     - Gaussian input files
#     - Paratool internal coordinate files
#     - Gaussian log files

#  Parse various info from Gaussian output:
#     - molecular geometries
#     - population analysis (Mulliken/NPA charges)
#     - ESP charges
#     - dipole moments
#     - Cartesian and internal coordinate Hessians
#     - unit conversion to Kcal/mol
#     - assign force constants to internal coordinates
#     - thermochemistry analysis

#  Setup Gaussian input files for different types of simulation
#     - optimization
#     - frequency
#     - single point
#     - support for continuum solvent models (PCM)

#  Work with internal coordinates:
#     - Autogeneration
#     - pick bonds/angles/diheds/imprps with mouse
#     - selecting coordinates from list, vizualizaton in VMD

#  Analysis:
#     - SCF energy plots
#     - plotting vibrational spectra
#     - normal mode analysis and animation
#     - many different atom labels including Mulliken and NPA charges
#     - force constants and internal coordinates are graphically mapped 
#       onto the molecule.



#  Usage: qmtool [-xyz|-pdb|-xbgf|-log|-com|-zmt|-int <file>] [-nogui] [-mol <molid>]

package provide qmtool 1.1
package require atomedit
package require utilities

namespace eval ::QMtool:: {
   namespace export qmtool
   namespace export setup_QM_simulation
   namespace export get_totalcharge
   namespace export get_multiplicity
   namespace export get_internal_hessian
   namespace export get_internal_coordinates
   namespace export set_internal_coordinates
   namespace export get_cartesian_coordinates
   namespace export get_spectrum
   namespace export get_scfenergies
   namespace export get_atomproplist
   namespace export get_molidlist
   namespace export get_molid
   namespace export set_molid
   namespace export use_vmd_molecule
   namespace import ::util::lrevert

   proc default_zmat {} {
      return {{0 0 0 0 0 0 0 0}}
   }
   proc initialize { } {
      variable w  {}
      variable workdir    "[pwd]";            # working directory
      variable selectcolor lightsteelblue
      variable statustext "Welcome to QMtool!"; # Text that is displayed in the status line
      variable statuscolor green3;      # Color of the text in the status line
      variable molid     -1;            # Molecule ID
      variable molidlist {};            # List of all loaded Molecule IDs
      variable molnamelist {};          # List of all loaded Molecule IDs and names (for the listbox)
      variable molownlist  {};          # List of molecule ids that are owned by qmtool, 
                                        # i.e mols that qmtool is allowed to delete
      variable msgret      {};          # Message box return value
   }
   initialize
}

proc ::QMtool::init_variables { ns } {
   if {[namespace exists $ns]} {
      #puts "Reinitializing namespace $ns."
   } else {
      #puts "Creating namespace $ns"
   }

   namespace eval $ns {
      variable optcompleted 0;              # Optimization completed?
      variable normalterm 0;                # Normal termination of Gaussian?

      # Simulation specifications
      variable filename  {};     # name of input/output file
      variable filetype  {};     # type of input/output file
      variable basename  {};     # basename for all simulation files
      variable checkfile {};     # checkpoint file used for the simulation
      variable fromcheckfile {}; # copy simulation checkfile from this file
      variable nproc     {};     # number of processores requested
      variable memory    {};     # amount of memory requested
      variable method    {};     # ab initio methof to be used (HF/UHF/B3LYP...)
      variable basisset  {};     # basisset for the simulation (STO-3G/6-31+G*...)
      variable simtype   {};     # singlepoint, optimization or frequency
      variable optmaxcycles {};  # max. mnumber of optimization cycles (if empty use Gaussian's default).
      #variable optimize  {};     # singlepoint, optimization or frequency
      #variable frequency {};     # singlepoint, optimization or frequency
      variable otherkey  {};     # additional keywords
      variable geometry  {};     # Geom keyword
      variable guess     {};     # Guess keyword
      variable coordtype {};     # Internal or Modredundant or explictly given coordinates
      variable route     {};     # route section in Gaussian input files
      variable title     {};     # title string in Gaussian input files
      variable autotitle {};     # automatically generated title string
      variable extratitle {};    # automatically generated extra title string
      variable totalcharge {};   # total system charge
      variable multiplicity {};  # multiplicity
      variable nimag        {};  # imaginary frequencies
      variable scfenergies  {};  # SCF energies and relative SCF energies
      variable dipolemoment {};  # Dipole moment from wavefunction
      variable espdipolemoment {};  # Dipole moment from ESP charge distribution
      variable hinderedrotor 0;  # Perform Hindered Rotor Analysis for Frequency jobs?
      variable thermalenergy {}; # Thermal energies and Entropy
      variable temperature   {}; # Temperature used for thermochemical analysis
      variable Evacuum       {};
      variable Esolv         {};
      variable Gvacuum       {};
      variable Gsolv         {};
      variable EGvacuum       {};
      variable EGsolv         {};
      variable dGsolvation   {};
      variable thermElist    {};
      variable thermPlist    {};
      variable dGsolvationTotal {};
      variable dGsolvationE     {};
      variable dGsolvationP     {};
      variable dGreactionGas    {};
      variable dGreactionSol    {};
      variable dGreactionCycle  {};
      variable eductlist     {};
      variable productlist   {};
      variable linewavenumbers {};  # harmonic frequencies
      variable lineintensities {};  # harmonic intensities
      variable normalmodes     {};  # Normal mode components for each atom
      variable normalmodescaling 0.5; # Normal mode visualization scaling factor
      variable normalmodesteps   80;  #
      variable normalmodearrows  1;   # Draw arrows indicating the normal mode vibration
      variable availmethods {RHF UHF ROHF B3LYP UB3LYP MP2 UMP2 AM1 PM3 MNDO INDO CNDO CBS-4M CBS-QB3};
      variable calcesp      0;      # calculate the ESP charges
      variable calcnbo      0;      # Perform NBO population analysis
      variable calcnboread  0;      # Perform NBO population analysis and specify Lewis structure
      variable orientation  {};
      variable PCMmethod    {};   # PCM method 
      variable solvent  "None";   # Solvent (Water, ethanole, octane, ...)
      variable calcdGsolv    0;   # Compute dG of solvation?
      variable scanstepsize {};   # Range of potential scan
      variable scansteps    {};   # Number of potential scan steps

      # zmat header values as variables and some flags
      variable natoms    0;
      variable ncoords   0;
      variable nbonds    0;
      variable nangles   0;
      variable ndiheds   0;
      variable nimprops  0;
      variable havepar   0;       # are bondlengths and angle values present?
      variable havefc    0;       # are force constants present?
      variable havecart  0;       # are cartesian coords present?
      variable havemulliken 0;    # are mulliken charges present?
      variable havenpa   0;       # are NPA charges present?
      variable haveesp   0;       # are ESP charges present?
      variable havelewis 0;       # are Lewis charges present?
      variable numfixed  0;       # are fixed atoms present?
      variable nmods     0;       # number of modredundant coordinates
      variable zmat    [::QMtool::default_zmat]; # list of internal coordinates
      variable allzmat [::QMtool::default_zmat]; # list internal coordinates for each frame
      variable inthessian      {};               # Hessian matrix in internal coordinates
      variable inthessian_kcal {};               # Hessian matrix in internal coordinates and kcal
      variable carthessian  {};                  # Hessian matrix in cartesian coordinates
      variable HFscalefac    0.89;  # Scaling factor that cures systematic overestimation of frequencies
      variable B3LYPscalefac 0.963; # Scaling factor that cures systematic overestimation of frequencies

      # Atom based properties
      variable atomproptags   {Index Elem Name Flags}; # Tags for the atomproperties that are displayed
      variable atomproplist     {};    # Unformatted list of properties for each atom
      variable atompropformlist {};    # Atom property list formatted for atomedit.
      variable atompropformtags {};    # The formatted list of tags.
      variable cartesians       {};    # Cartesians coordinates for the molecule

      # for the edit coordinate window
      variable addtype "bond";        # selected type of coordinate in 'add coordinate' window
      variable gendepangle 1;         # generate all angles containing the new bond?
      variable gendepdihed 1;         # generate diheds containing the new bond?
      variable gendepdihedmode "all"; # generate all diheds containing the new bond?
      variable autogendiheds "all";   # Autogenerate one or all diheds per torsion?
      variable removedependent 1;     # remove all coords that depend on a deleted coordinate?
      variable addcoorddoctext "-Pick two atoms-"
      variable pickmode "conf";       # are we currently picking atoms?
      variable picklist {};           # list of previously picked atoms.
      variable maxbondlength 1.6;     # maximum bond length for bond recalculation
      variable labelscaling 1;        # Scale coordinate labels with force constant values?
      variable labelradius 0.11;      # default radius for the label tubes
      variable labelsize 1;           # Size of text labels

      # for the pick.list window:
      variable selintcoorlist {};     # list of actually selected internal coordinates
      variable act       0;           # actually selected coordinate
      variable seldelete 1;           # flag for scrolling
	 
      # for atom labels:
      variable atomlabeltags {};      # tags for drawing primitives returned by the "draw" command
      variable atomlabelselected 1;   # only draw labels for selected atoms
      variable atommarktags  {};
      variable Indexlabels   0
      variable Elemlabels    0
      variable Namelabels    0
      variable Flagslabels   0
      variable Typelabels    0
      variable Chargelabels  0
      variable Lewislabels   0
      variable Mulliklabels  0
      variable MulliGrlabels 0
      variable NPAlabels     0
      variable ESPlabels     0

      
      # for internal coordinate labels
      variable intcoorlabeltags  {};   # tags for drawing primitives returned by the "draw" command
      variable intcoorlabelselected 0; # only draw labels for selected atoms
      variable intcoormarktags   {};
      variable intcoortaglabels  1
      variable intcoornamelabels 1
      variable intcoorvallabels  1
      variable intcoorfclabels   1     
      variable labelradius 0.21;   # default radius for the label balls and tubes

      # For NBO analysis
#      variable lewisatomlist  {};
#      variable lewisbondlist  {};
      variable lewislonepairs {};

      variable availsolvents {
	 water               {Water H2O 78.39}
	 acetonitrile        {Acetonitrile CH3CN 36.64} 
	 dimethoxysulfoxide  {DiMethylSulfoxide DMSO 46.7}
	 methanol            {Methanol CH3OH 32.63}
	 ethanol             {Ethanol CH3CH2OH 24.55}
	 isoquinoline        {Isoquinoline 10.43}
	 quinoline           {Quinoline 9.03}
	 chloroform          {Chloroform CHCl3 4.9}
	 ether               {Ether CH3CH2OCH2CH3 4.335}
	 diethylether        {DiEthylEther CH3CH2OCH2CH3 4.335}
	 dichloromethane     {DiChloroMethane   CH2Cl2 8.93}
	 methylenechloride   {MethyleneChloride CH2Cl2 8.93}
	 dichloroethane      {DiChloroEthane CH2ClCH2Cl 10.36}
	 carbontetrachloride {CarbonTetrachloride CCl4 2.228}
	 benzene             {Benzene C6H6 2.247}
	 toluene             {Toluene C6H5CH3 2.379}
	 chlorobenzene       {ChloroBenzene C6H4Cl 5.621}
	 nitromethane        {NitroMethane CH3NO2 38.2}
	 heptane             {Heptane C7H16 1.92}
	 cyclohexane         {CycloHexane C6H12 2.023}
	 aniline             {Aniline C5H5NH2 6.89}
	 acetone             {Acetone CH3COCH3 20.7}
	 tetrahydrofurane    {TetraHydroFuran THF 7.58}
	 argon               {Argon Ar 1.43}
	 krypton             {Krypton Kr 1.519}
	 xenon               {Xenon Xe 1.706}
      }
  }

}


###############################################
# Some user interface commands.               #
###############################################

proc ::QMtool::get_molidlist {} {
   return $::QMtool::molidlist
}

proc ::QMtool::get_molnamelist {} {
   return $::QMtool::molnamelist
}

# Get the current molecule ID
proc ::QMtool::get_molid {} {
   return $::QMtool::molid
}

# Set a new current molecule
proc ::QMtool::set_molid { newmolid } {
   variable molidlist
   if {[lsearch $molidlist $newmolid]<0} {
      error "::QMtool::set_molid: Molecule $newmolid not found!"
   }
   #variable molid $newmolid 
   molecule_select $newmolid
}

proc ::QMtool::get_force_constants {} {
   set fc {}
   foreach entry $::QMtool::zmat {
      lappend $fc [lindex $entry 4]
   }
   return $fc
}

proc ::QMtool::get_internal_coordinates {} {
   return $::QMtool::zmat
}

proc ::QMtool::set_internal_coordinates { zmat } {
   update_zmat $zmat
}

proc ::QMtool::get_cartesian_coordinates {} {
   return $::QMtool::cartesians
}

proc ::QMtool::get_atomproplist { args } {
   return $::QMtool::atomproplist
}

proc ::QMtool::get_internal_hessian {} {
   return $::QMtool::inthessian
}

proc ::QMtool::get_internal_hessian_kcal {} {
   return $::QMtool::inthessian_kcal
}

proc ::QMtool::get_cartesian_hessian {} {
   return $::QMtool::carthessian
}

proc ::QMtool::get_spectrum {} {
   return $::QMtool::linespectrum
}

proc ::QMtool::get_intensities {} {
   return $::QMtool::lineintensities
}

proc ::QMtool::get_multiplicity {} {
   return $::QMtool::multiplicity
}

proc ::QMtool::get_totalcharge {} {
   return $::QMtool::totalcharge
}

proc ::QMtool::get_scfenergies {} {
   return $::QMtool::scfenergies
}

proc ::QMtool::get_fromcheckfile {} {
   return $::QMtool::fromcheckfile
}

proc ::QMtool::get_checkfile {} {
   return $::QMtool::checkfile
}

proc ::QMtool::get_memory {} {
   return $::QMtool::memory
}

proc ::QMtool::get_nproc {} {
   return $::QMtool::nproc
}

proc ::QMtool::get_basename {} {
   return $::QMtool::basename
}

proc ::QMtool::set_title { mytitle } {
   variable title $mytitle
}

proc ::QMtool::set_simtype { mysimtype } {
   variable simtype $mysimtype
}

proc ::QMtool::set_coordtype { mycoordtype } {
   variable coordtype $mycoordtype
}

proc ::QMtool::set_otherkey { myotherkey } {
   variable otherkey $myotherkey
}

proc ::QMtool::set_guess { myguess } {
   variable guess $myguess
}

proc ::QMtool::set_geometry { mygeometry } {
   variable geometry $mygeometry
}

proc ::QMtool::set_method { mymethod } {
   variable method $mymethod
}

proc ::QMtool::get_method { } {
   return $::QMtool::method
}

proc ::QMtool::get_basisset { } {
   return $::QMtool::basisset
}

proc ::QMtool::set_basisset { mybasisset } {
   variable basisset $mybasisset
}

proc ::QMtool::set_basename { mybasename } {
   variable basename $mybasename
}

proc ::QMtool::set_fromcheckfile { myfromcheckfile } {
   variable fromcheckfile $myfromcheckfile
}

proc ::QMtool::set_memory { mymemory } {
   variable memory $mymemory
}

proc ::QMtool::set_nproc { mynproc } {
   variable nproc $mynproc
}

proc ::QMtool::set_multiplicity { mymultiplicity } {
   variable multiplicity $mymultiplicity
}

proc ::QMtool::set_totalcharge { mytotalcharge } {
   variable totalcharge $mytotalcharge
}

proc ::QMtool::set_lewischarges { lewischarges } {
   set i 0
   foreach charge $lewischarges {
      set_atomprop Lewis $i $charge
      #puts "Lewis=[get_atomprop Lewis $i]"
      incr i
   }
   variable havelewis 1
   variable atomproptags 
   if {[lsearch $atomproptags Lewis]<0} {
      lappend atomproptags Lewis
   }
   atomedit_update_list
}

proc qmtool { args } {
   eval ::QMtool::qmtool $args
}

proc ::QMtool::qmtool { args } {
   variable zmat
   variable molidlist
   variable wordir "[pwd]";

   # Initialize variables with default values
   initialize
   init_variables ::QMtool
   
   # Use GUI by default
   set gui 1

   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      if {$i=="-nogui"}  then {
         set gui 0
         set arglist [lreplace $arglist $argnum $argnum]
         continue
      }
      incr argnum
   }
   
   set argsnoopt $arglist
   set startmolid -1
   set loadlist {}
   # Scan for options with one argument
   foreach {i j} $arglist {
      set pos [lsearch $argsnoopt $i]
      if {[string index $i 0]!="-"} { continue }
      set type [string range $i 1 end]
      switch $type {
	 xyz  { lappend loadlist xyz $j }
	 pdb  { lappend loadlist pdb $j }
	 xbgf { lappend loadlist xbgf $j }
	 log  { lappend loadlist log $j }
	 com  { lappend loadlist com $j }
	 zmt  { lappend loadlist zmt $j }
	 int  { lappend loadlist int $j }
	 mol  { set startmolid $j }
	 default { error "Unknown option -$type." }
      }
      set argsnoopt [lreplace $argsnoopt $pos [expr $pos+1]]
   }

   if {[llength $argsnoopt]} { error "Error parsing command line!" }

   foreach file $argsnoopt {
      lappend loadlist unknown $file
   }

   foreach {type file} $loadlist {
      puts "Load $type $file"
      load_file $file $type
   }
   
   update

   if {$startmolid>=0} {
      use_vmd_molecule $startmolid
   }

   # If no molecule was loaded, create a new one
   if {![llength $molidlist]} {
      if {[molinfo top]>=0} {
	 puts "Using coordinates of current top molecule [molinfo top]."
	 use_vmd_molecule [molinfo top]
      } else {
	 puts "No molecule loaded, creating empty structure."
	 setstatus "No coordinates present. Please load a molecule." red
      }
   }
   
   # Start the gui?
   if {$gui} {
      qmtool_gui
   }
}

proc ::QMtool::use_vmd_molecule { id } {
   if {[lsearch [molinfo list] $id]<0} {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Molecule $id does not exist!"
      return 0
   }
   if {$::QMtool::molid>=0} {
      molecule_export
   }
   molecule_export
   molecule_add $id
   init_variables ::QMtool
   init_atomprops
   atomedit_update_list
   
   update_molidlist
   molecule_select $::QMtool::molid
   variable basename [file rootname [molinfo $id get name]]
   return 1
}

proc ::QMtool::qmtool_gui {} {
   variable w 
   variable selectcolor

   # If already initialized, just turn on
   if { [winfo exists .qmtool] } {
      wm deiconify .qmtool
      raise .qmtool
      return
   }

   set w [toplevel ".qmtool"]
   wm title $w "QMtool"
   wm resizable $w 0 0

   tk_setPalette background [.qmtool cget -bg] selectbackground $selectcolor

   menu $w.menu -tearoff 0
   menu $w.menu.file -tearoff 0
   $w.menu add cascade -label "File" -menu $w.menu.file -underline 0

   menu $w.menu.file.open -tearoff 0

   $w.menu.file add cascade -label "Open" -menu $w.menu.file.open

   set m $w.menu.file.open
   $m add command -label "Gaussian simulation logfile" -command {::QMtool::opendialog log}
   $m add command -label "Gaussian input file" -command {::QMtool::opendialog com}
   $m add command -label "Z-matrix" -command {::QMtool::opendialog zmt}
   $m add command -label "PDB file" -command {::QMtool::opendialog pdb}
   $m add command -label "Load coordinates through VMD" -command {
      #set newmolid [lindex [molinfo list] end]
      #trace add variable vmd_initialize_structure($newmolid) write ::QMtool::register_vmd_molecule
      menu files on
   }
   menu $w.menu.file.save -tearoff 0
   $w.menu.file add cascade -label "Save" -menu $w.menu.file.save

   set m $w.menu.file.save
   $m add command -label "Gaussian input file" \
      -command {::QMtool::edit_gaussian_ok dontclose; ::QMtool::opendialog writecom ${::QMtool::basename}.com}
   $m add command -label "PDB file" \
      -command {::QMtool::opendialog writepdb ${::QMtool::basename}.pdb}

   $w.menu.file add command -label "Delete molecule" -command {::QMtool::molecule_delete}
   $w.menu.file add command -label "Reset molecule data" \
      -command {
	 ::QMtool::clear_zmat; 
	 ::QMtool::init_variables [namespace current]; 
	 ::QMtool::molecule_export
      }
   $w.menu.file add separator
   $w.menu.file add command -label "Reset all" -command {::QMtool::reset_all}


   menu $w.menu.edit -tearoff 0
   $w.menu add cascade -label "Edit" -menu $w.menu.edit -underline 0

   $w.menu.edit add command -label "Gaussian input file" -accelerator <Ctrl-g> -command {::QMtool::setup_QM_simulation}
   $w.menu.edit add command -label "Edit Lewis structure in Molefacture" -accelerator <Ctrl-m> \
      -command {::QMtool::molefacture_start}
   $w.menu.edit add separator
   $w.menu.edit add command -label "Atom properties" -accelerator <Ctrl-a> -command {::QMtool::edit_atom_properties}
   $w.menu.edit add command -label "Internal coordinates" -accelerator <Ctrl-i> -command {::QMtool::edit_internal_coords}

   menu $w.menu.analysis -tearoff 0
   $w.menu add cascade -label "Analysis" -menu $w.menu.analysis -underline 0

   $w.menu.analysis add command -label "Plot SCF energies" \
      -command {::QMtool::plot_scf_energies} -state disabled
   $w.menu.analysis add command -label "Plot spectrum" \
      -command {::QMtool::plot_spectrum} -state disabled
   $w.menu.analysis add command -label "Thermochemistry" \
      -command {::QMtool::thermochemistry}
   $w.menu.analysis add command -label "Normal mode analysis" \
      -command {::QMtool::normalmode_gui}

   menu $w.menu.labels -tearoff 0
   $w.menu add cascade -label "Labels" -menu $w.menu.labels -underline 0

   $w.menu.labels add checkbutton -label "Internal coordinate tags" -variable ::QMtool::intcoortaglabels \
      -command {::QMtool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Internal coordinate atom names" -variable ::QMtool::intcoornamelabels \
      -command {::QMtool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Internal coordinate values" -variable ::QMtool::intcoorvallabels \
      -command {::QMtool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Force constants" -variable ::QMtool::intcoorfclabels \
      -command {::QMtool::update_intcoorlabels}
   $w.menu.labels add separator
   $w.menu.labels add checkbutton -label "Indices" -variable ::QMtool::Indexlabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Names" -variable ::QMtool::Namelabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Types" -variable ::QMtool::Typelabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "User charges" -variable ::QMtool::Chargelabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Lewis charges" -variable ::QMtool::Lewislabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Mulliken charges" -variable ::QMtool::Mulliklabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Mulliken charge groups" -variable ::QMtool::MulliGrlabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "ESP charges" -variable ::QMtool::ESPlabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add checkbutton -label "NPA charges" -variable ::QMtool::NPAlabels \
      -command {::QMtool::update_atomlabels}
   $w.menu.labels add separator
   $w.menu.labels add checkbutton -label "Selected atoms only" -variable ::QMtool::atomlabelselected \
      -command {::QMtool::update_atomlabels}

   # Display the menu
   $w configure -menu $w.menu

   ############## frame for file info #################
   labelframe $w.files -bd 2 -relief ridge -text "Info"

   frame $w.files.f

   label $w.files.f.filetypelabel -text "Filetype: "
   label $w.files.f.filetypevar -textvariable ::QMtool::filetype
   grid $w.files.f.filetypelabel -column 0 -row 0 -sticky w
   grid $w.files.f.filetypevar   -column 1 -row 0 -sticky w

   label $w.files.f.filenamelabel -text "Filename: "
   label $w.files.f.filenamevar -textvariable ::QMtool::filename
   grid $w.files.f.filenamelabel -column 0 -row 1 -sticky w
   grid $w.files.f.filenamevar   -column 1 -row 1 -sticky w

   label $w.files.f.checklabel -text "Checkfile: "
   label $w.files.f.checkvar -textvariable ::QMtool::checkfile
   grid $w.files.f.checklabel -column 0 -row 2 -sticky w
   grid $w.files.f.checkvar   -column 1 -row 2 -sticky w

   label $w.files.f.nproclabel -text "Nproc: "
   label $w.files.f.nprocvar -textvariable ::QMtool::nproc
   grid $w.files.f.nproclabel -column 0 -row 3 -sticky w
   grid $w.files.f.nprocvar   -column 1 -row 3 -sticky w

   label $w.files.f.memorylabel -text "Memory: "
   label $w.files.f.memoryvar -textvariable ::QMtool::memory
   grid $w.files.f.memorylabel -column 0 -row 4 -sticky w
   grid $w.files.f.memoryvar   -column 1 -row 4 -sticky w

   label $w.files.f.routelabel -text "Route: "
   label $w.files.f.routevar -wraplength 10c -justify left -textvariable ::QMtool::route
   grid $w.files.f.routelabel  -column 0 -row 5 -sticky wn
   grid $w.files.f.routevar    -column 1 -row 5 -sticky wn

   label $w.files.f.titlelabel -text "Title: "
   label $w.files.f.titlevar -wraplength 10c -justify left -textvariable ::QMtool::title
   grid $w.files.f.titlelabel -column 0 -row 6 -sticky wn
   grid $w.files.f.titlevar   -column 1 -row 6 -sticky wn

   label $w.files.f.chargelabel -text "Total charge: "
   label $w.files.f.chargevar -textvariable ::QMtool::totalcharge
   grid $w.files.f.chargelabel -column 0 -row 7 -sticky w
   grid $w.files.f.chargevar   -column 1 -row 7 -sticky w

   label $w.files.f.multiplabel -text "Multiplicity: "
   label $w.files.f.multipvar -textvariable ::QMtool::multiplicity
   grid $w.files.f.multiplabel -column 0 -row 8 -sticky w
   grid $w.files.f.multipvar   -column 1 -row 8 -sticky w

   label $w.files.f.nimaglabel -text "Imaginary freq: "
   label $w.files.f.nimagvar -textvariable ::QMtool::nimag
   grid $w.files.f.nimaglabel -column 0 -row 9 -sticky w
   grid $w.files.f.nimagvar   -column 1 -row 9 -sticky w

   pack $w.files.f -anchor w

   ############## frame for molecule list #################
   labelframe $w.mol -bd 2 -relief ridge -text "Molecule list" -padx 1m -pady 1m
   frame $w.mol.list
   scrollbar $w.mol.list.scroll -command "$w.mol.list.list yview"
   listbox $w.mol.list.list -activestyle dotbox -yscroll "$w.mol.list.scroll set" -font {tkFixed 9} \
      -width 72 -height 5 -setgrid 1 -selectmode browse -selectbackground $selectcolor -listvariable ::QMtool::molnamelist
   pack $w.mol.list.list $w.mol.list.scroll -side left -fill y -expand 1
   pack $w.mol.list

   # This will be executed when a new molecule is selected:   
   bind $w.mol.list.list <<ListboxSelect>> {
      ::QMtool::molecule_select
   }


   variable statuscolor
   frame $w.status
   label $w.status.text -textvariable ::QMtool::statustext -fg $statuscolor
   pack $w.status.text


   ##
   ## pack up the main frame
   ##
   pack $w.files  $w.mol $w.status -side top -pady 5 -padx 3 -fill x -anchor w


   bind $w <Control-a> {
      ::QMtool::edit_atom_properties
   }

   bind $w <Control-i> {
      ::QMtool::edit_internal_coords
   }

   bind $w <Control-m> {
      ::QMtool::molefacture_start
   }

   bind $w <Control-g> {
      ::QMtool::setup_QM_simulation
   }

   bind $w <FocusIn> {
      if {"%W"==".qmtool" && [winfo exists .qmtool.mol.list.list]} {
	 mouse mode 0
	 set ::QMtool::pickmode none
	 trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn
      }
   }

   variable lineintensities
   if {[llength $lineintensities]} {
      .qmtool.menu.analysis entryconfigure 1 -state normal
   }

   variable scfenergies
   if {[llength $scfenergies]>2} {
      .qmtool.menu.analysis entryconfigure 0 -state normal
   }


   variable molid
   variable molidlist
   #puts "molid: $molid; molidlist $molidlist"
   if {$molid>=0} {
      if {[molinfo $::QMtool::molid get numframes]>0} {
	 ::QMtool::update_molidlist
	 ::QMtool::update_intcoorlist
      }
   }

}

##########################################
# Add a new molecule to the list.        #
##########################################

proc ::QMtool::molecule_add {id} {
   variable molid
   variable molidlist

   set oldmolid $molid
   variable molid $id

   if {$molid!=-1} {
      # Trace the existence of the new molecule
      global vmd_initialize_structure
      trace add variable vmd_initialize_structure($::QMtool::molid) \
	 write ::QMtool::molecule_assert
      #puts -nonewline "Trace: vmd_initialize_structure($::QMtool::molid) "
      #puts "[trace info variable vmd_initialize_structure($::QMtool::molid)]"
   } else {
      return
   }

   # Create a new subnamespace with the name $mol
   init_variables ::QMtool::mol${id} 

   lappend molidlist $molid
   update_molidlist

   if {[winfo exists .qmtool.mol.list.list] && $oldmolid>=0 } {
      .qmtool.mol.list.list itemconfigure [lsearch $molidlist $oldmolid] \
	 -background $::QMtool::selectcolor
      .qmtool.mol.list.list activate      [expr [llength $molidlist]-1]
      .qmtool.mol.list.list selection clear 0 end
      .qmtool.mol.list.list selection set [lsearch $molidlist $molid]
      .qmtool.mol.list.list itemconfigure [lsearch $molidlist $molid] \
	 -background $::QMtool::selectcolor
   }

}


##########################################################
# This is called when the VMD mol initialization state   #
# is changed, i.e. when a molecule is deleted from VMD's #
# list. If it exists in QMtool then also delete it.      #
##########################################################

proc ::QMtool::molecule_assert { n id args } {
   global vmd_initialize_structure
   #puts "::QMtool::molecule_assert trace ${n}($id) = $vmd_initialize_structure($id)"
   if {$vmd_initialize_structure($id)==0} { molecule_delete $id }
}


##########################################################
# Delete molecule $mol from the list.                    #
##########################################################

proc ::QMtool::molecule_delete { {id {}}} {
   variable molid
   variable molidlist
   set index 0

   if {![llength $id]} {
      #if {![winfo exists .qmtool.mol.list.list]} { return }
      set id $molid
      if {$molid<0} { return }
   }


   # Remove the trace
   foreach t [trace info variable vmd_initialize_structure($id)] {
      trace remove variable vmd_initialize_structure($id) write ::QMtool::molecule_assert
   }

   #puts "Deleting molecule $id from ($molidlist)."
   namespace delete ::QMtool::mol${id}

   # Delete the molecule from VMD if QMtool is the owner, i.e. if
   # the molecule was loaded through QMtool.
   variable molownlist
   if {[lsearch $molownlist $id]>0} {
      mol delete $id
   }

   # Update the molidlist
   set newidlist {}
   foreach mol $molidlist {
      if {$mol==$id} { continue }
      lappend newidlist $mol
   }
   set molidlist $newidlist

   # Delete all variable values if no molecule is left.
   if {![llength $molidlist]} { 
      init_variables ::QMtool 
      variable molid -1
      if {[winfo exists .qmtool]} {
	 .qmtool.menu.analysis entryconfigure 0 -state disabled
	 .qmtool.menu.analysis entryconfigure 1 -state disabled
      }
   }

   # Determine new current molecule
   if {$index>=[llength $molidlist]} { set index [expr [llength $molidlist]-1] }
   variable molid [lindex $molidlist $index]

   update_molidlist

   if {$molid>0} {
      # Make current molecule active
      molecule_import $molid
   }
}


##########################################################
# Import molecule $mol from the list as the current one. #
##########################################################

proc ::QMtool::molecule_import {{id {}} } {
   variable molid
   variable molidlist

   set index [lsearch $molidlist $id]
   if {![llength $id] && [winfo exists .qmtool.mol.list.list]} {
      set index [.qmtool.mol.list.list curselection]
      set id [lindex $molidlist $index]
   }
   #puts "Selected molecule $id from {$molidlist}"

   # Get a list of all variable names in the corresponding namespace:
   set varlist [info vars ::QMtool::mol${id}::*]

   # Loop over the list and initialize all variables in ::QMtool::
   foreach var $varlist {
      variable [namespace tail $var] [subst $${var}]
   }
   variable molid $id

   # Make the selected molecule the top mol.
   molinfo $molid set top 1

   # Undraw all other molecules in VMD unless they are not owned by QMtool:
   variable molownlist
   foreach m [molinfo list] {
      if {[lsearch $molownlist $m]<0} { continue }
      if {$m==$molid} { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   if {![winfo exists .qmtool.mol.list.list]} { return }

   # Blank the background
   foreach i $molidlist {
      .qmtool.mol.list.list itemconfigure [lsearch $molidlist $i] -background {}
   }

   # Update the selection in the listbox
   .qmtool.mol.list.list selection clear 0 end
   .qmtool.mol.list.list selection set $index
   .qmtool.mol.list.list activate $index
   .qmtool.mol.list.list itemconfigure $index -background $::QMtool::selectcolor

   update_intcoorlist
}


##########################################################
# Export molecule all data from the current molecule to  #
# ::QMtool::mol${id}.                                  #
##########################################################

proc ::QMtool::molecule_export { {id {}} } {
   variable molid
   if {![llength $id]} {
      set id $molid
   }
   if {$id==-1} { return }

   #puts "Exporting current molecule $id {$::QMtool::molidlist}"

   #if {[lsearch $::QMtool::molidlist $id]<0} {
   #   error "::QMtool::molecule_export: Molecule $id doesn't exist!"
   #}

   # Get a list of all variable names in the corresponding namespace:
   set varlist [info vars ::QMtool::mol${id}::*]

   # Loop over the list and initialize all variables with the values from ::QMtool::
   foreach var $varlist {
      set localvarname "::QMtool::[namespace tail $var]"
      variable $var [subst $${localvarname}]
   }

   set molid $id
}


#################################################################
# Select a molecule from the list. Exports the current molecule #
# and imports all data from the new molecule.                   #
#################################################################

proc ::QMtool::molecule_select { {id {}} } {
   if {![llength $::QMtool::molidlist]} { puts "NO $::QMtool::molidlist"; return 1 }

   # Export current molecule:
   ::QMtool::molecule_export

   # Import data from the newly selected molecule:
   ::QMtool::molecule_import $id
}

proc ::QMtool::update_molidlist {} {
   variable w
   variable molid
   variable molidlist
   variable molnamelist

   # These are the tags that appear in the listing:
   set molnamelist {}
   foreach t $molidlist {
      set tag [format "%3i  %s" $t [molinfo $t get name]] 
      lappend molnamelist "$tag"
   }

   if {![winfo exists .qmtool.mol.list.list]} { return 1 }


   if {[llength $molidlist]} {
      .qmtool.mol.list.list selection clear 0 end
      .qmtool.mol.list.list selection set [lsearch $molidlist $molid]
      .qmtool.mol.list.list activate [lsearch $molidlist $molid]
      .qmtool.mol.list.list itemconfigure [lsearch $molidlist $molid] \
	 -background $::QMtool::selectcolor
   }

   return 1
}

proc ::QMtool::update_zmat { {newzmat {}} } {
   variable zmat
   variable molid
   if {[llength $newzmat]} {
      variable zmat $newzmat
   }
   set header [lindex $zmat 0]
   variable natoms   [lindex $header 0]
   variable ncoords  [lindex $header 1]
   variable nbonds   [lindex $header 2]
   variable nangles  [lindex $header 3]
   variable ndiheds  [lindex $header 4]
   variable nimprops [lindex $header 5]
   variable havepar  [lindex $header 6]
   variable havefc   [lindex $header 7]

   # only update the picklist if a molecule is present:
   if {$molid>=0} {
      if {[molinfo $molid get numframes]>0} {
	 update_intcoorlist
      }
   }

   if {[winfo exists .qmtool_intcoor.l.zmat.scaling]} {
      if {$havefc==0} {
	 .qmtool_intcoor.l.zmat.scaling.check configure    -state disabled
	 .qmtool_intcoor.l.zmat.scaling.tubespin configure -state disabled
      } else {
	 .qmtool_intcoor.l.zmat.scaling.check configure    -state normal
	 .qmtool_intcoor.l.zmat.scaling.tubespin configure -state normal
      }
   }
   return 1
}

proc ::QMtool::clear_zmat { } {
   variable zmat
   variable natoms  [lindex [lindex $zmat 0] 0]
   variable ncoords 0
   variable nbonds  0
   variable nangles 0
   variable ndiheds 0
   variable nimprops 0
   variable havepar 0
   variable havefc  0
   variable zmat [list [list $natoms $ncoords $nbonds $nangles $ndiheds $nimprops $havepar $havefc]]
   update_intcoorlist
   return 1
}

############################################################
### This function is invoked whenever an atom is picked. ###
############################################################

proc ::QMtool::atom_picked_fctn { args } {
   global vmd_pick_atom
   global vmd_pick_shift_state
   variable picklist
   variable addtype
   variable pickmode
   
   #puts "pickmode=$pickmode; addtype=$addtype; picked atom $vmd_pick_atom; $picklist"
   lappend picklist $vmd_pick_atom
   set sel [atomselect top "index $vmd_pick_atom"]

   if {$pickmode=="conf"} {
      variable labelradius
      draw color yellow
      draw sphere [join [$sel get {x y z}]] radius [expr 1.21*$labelradius]
      
      if {$addtype=="bond" && [llength $picklist]==2} {
	 register_bond
      } elseif {$addtype=="angle" && [llength $picklist]==3} {
	 register_angle
      } elseif {$addtype=="dihed" && [llength $picklist]==4} {
	 register_dihed
      } elseif {$addtype=="imprp" && [llength $picklist]==4} {
	 register_imprp
      } 
      label delete Atoms all

   } elseif {$pickmode=="atomedit"} {
      #puts "Selected atom $vmd_pick_atom"
      if {!$vmd_pick_shift_state} { 
	 set picklist $vmd_pick_atom 
	 label delete Atoms all
      } 

      # Blank all item backgrounds
      for {set i 0} {$i<[.qmtool_atomedit.cart.list.list index end]} {incr i} {
	 .qmtool_atomedit.cart.list.list itemconfigure $i -background {}
      }
      .qmtool_atomedit.cart.list.list selection clear 0 end

      foreach i $picklist {
	 .qmtool_atomedit.cart.list.list selection set $i
      }
      .qmtool_atomedit.cart.list.list see $vmd_pick_atom
      draw_selatoms
      update_atomlabels
   }
}


######################################################
### Get path file name for opening                 ###
######################################################

proc ::QMtool::opendialog { type {initialfile ""} } {
   variable filename
   variable filetype
   variable fromcheckfile
   variable workdir
   variable molid

   set sel {}
   if { [winfo exists .qmtool_intcoor.l.zmat.pick.list] } { 
      set sel [.qmtool_intcoor.l.zmat.pick.list curselection]
   }
   set types {}

   if {$type=="zmt"} {
      set types {
	 {{PSF files}       {.zmt .zmat}  }
	 {{All files}        *            }
      }
   } elseif {$type=="com" || $type=="writecom"} {
      set types {
	 {{Gaussian input files}       {.com .cmd}  }
	 {{All files}        *            }
      }
   } elseif {$type=="int" || $type=="writeint" || $type=="writeselint"} {
      set types {
	 {{Internal coordinate files}       {.intcoor}  }
	 {{All files}        *            }
      }
   } elseif {$type=="log"} {
      set types {
	 {{Gaussian logfiles} {.log .gau}   }
	 {{All Files}        *            }
      }
   } elseif {$type=="check"} {
      set types {
	 {{Gaussian checkpoint files} {.chk} }
	 {{All Files}        *            }
      }
   } elseif {$type=="pdb"} {
      set types {
	 {{PDB files} {.pdb}   }
	 {{All Files}        *            }
      }
   } elseif {$type=="writepdb"} {
      set types {
	 {{PDB Files} {.pdb}   }
	 {{All Files}        *            }
      }
   } else {
      error "::QMtool::opendialog: unknown type $type"

   }

   set newpathfile {}
   if {$filetype=="workdir"} {
      set workdir [tk_chooseDirectory \
		  -initialdir "." -title "Choose working directory"] 
   } elseif {$type=="writepdb" || $type=="writeint" || $type=="writecom"|| $type=="writeselint"} {
      set newpathfile [tk_getSaveFile \
			  -title "Choose file name" \
			  -initialdir $workdir -filetypes $types -initialfile $initialfile]
   } else {
      set newpathfile [tk_getOpenFile \
			  -title "Choose file name" \
			  -initialdir $workdir -filetypes $types]
   }

   set file $newpathfile
   set dir [file normalize [file dirname $newpathfile]]
   set normwd [file normalize $workdir]
   if {$dir==$normwd} {set file [file tail $newpathfile]}

   if {[string length $file] > 0} {
      switch $type {
	 writeint     { write_intcoords $file }
	 writeselint  { write_intcoords $file -sel $sel }
	 writecom     { write_gaussian_input $file }
	 writepdb     { 
	    set sel [atomselect $molid all]
	    $sel writepdb $file
	    $sel delete
	 }
	 check        { set fromcheckfile $file }
	 default      { load_file $file $type }
      }
      return 1
   }
   return 0
}

proc ::QMtool::load_file { file {type unknown} } {
   variable molidlist
   if {![llength $molidlist]} { init_variables ::QMtool }
   set molid -1

   switch $type {
      int { read_intcoords $file; }
      zmt { set molid [read_zmtfile $file] }
      com { set molid [read_gaussian_input $file] }
      log { set molid [load_gaussian_log $file] }
      default { 
	 # Save data from current molecule
	 molecule_export
	 
	 # Clear current namespace
	 init_variables [namespace current]
	 
	 if {$type=="unknown"} {
	    set molid [mol new $file]
	 } else {
	    set molid [mol new $file type $type]
	 }
	 variable natoms [molinfo $molid get numatoms]

	 # Add new molecule to the list
	 if {$molid>=0} {
	    molecule_add $molid
	    setstatus "Molecule loaded." green3

	 } else {
	    tk_messageBox -icon error -type ok -title Message \
	       -message "Could not load file $file"
	 }
      }
   }

   variable atomproplist
   variable natoms
   if {![llength $atomproplist] && $natoms>0} {
      init_atomprops
   }

   atomedit_update_list

   update_molidlist
   molecule_select $::QMtool::molid
   
   return $molid
}


proc ::QMtool::init_atomprops {} {
   variable atomproplist
   variable molid
   set sel [atomselect $molid all]
   variable natoms [$sel num]
   set i 0
   foreach index [$sel list] name [$sel get name] elemind [$sel get atomicnumber] {
      lappend atomproplist [default_atomprop_entry]
      set_atomprop Index $i $index
      set_atomprop Name  $i $name
      set_atomprop Elem  $i [atomnum2element $elemind]
      incr i
   }
   variable atomproptags {Index Name Elem Flags}
   $sel delete
}


###################################################################
# Start molefacture with the base molecule.                       #
###################################################################

proc ::QMtool::molefacture_start { {msel {}} } {
   variable molid
   if {$molid<0} { 
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please load a molecule first!"
      return 0
   }
   if {![llength $msel]} {
      if {$molid>=0} {
	 set msel [atomselect $molid "all"]
      }
   }

   #puts "parent=$molidparent base=$molidbase msel=[$msel text] num=[$msel num] names=[$msel get {name atomicnumber}]"
   ::Molefacture::molefacture_gui $msel
   variable molnamebase
   variable molidlist  
   variable molnamelist  
   set tmpfilename [lindex $molnamelist [lsearch $molidlist $molid] 1]
   set filename "[regsub {_hydrogen|_molef} [file rootname $tmpfilename] {}]_molef.xbgf"
   ::Molefacture::set_slavemode ::QMtool::molefacture_callback $filename
   $msel delete
}


###################################################################
# function to be called when editing in molefacture is finished.  #
###################################################################

proc ::QMtool::molefacture_callback { filename } {
   #puts "Molefacture_callback $filename"
   variable molid
   set oldmolid $molid

   set newmolid [load_file $filename xbgf]
   variable molidlist
   variable molnamelist

   molecule_select $oldmolid
   molecule_export $newmolid
   molecule_select $newmolid

   set all   [atomselect $molid "all"]
   # We get the Lewis charges from the XBGF charge field
   foreach lewischarge [$all get charge] index [$all list] {
      set_atomprop Lewis $index [expr int($lewischarge)]
   }

   set hydro [atomselect $molid "beta 0.8"]
   $all   set beta 0.0
   $hydro set beta 0.5
   $all delete
   $hydro delete
}


#####################################################
### Remove all old traces:                        ###
#####################################################

proc ::QMtool::remove_traces {} {
   global vmd_pick_atom
   global vmd_frame
   global vmd_initialize_structure
   variable molid
   variable molidlist

   foreach t [trace info variable vmd_pick_atom] {
      trace remove variable vmd_pick_atom write ::QMtool::atom_picked_fctn
   }

   if {$molid>=0} {
      foreach t [trace info variable vmd_frame($molid)] {
	 trace remove variable vmd_frame($molid) write ::QMtool::update_frame
      }
   }

   foreach mol $molidlist {
      foreach t [trace info variable vmd_initialize_structure($molid)] {
	 trace remove variable vmd_initialize_structure($molid) write ::QMtool::molecule_assert
      }
   }
}


###################################################
# Clean up and quit the program.                  #
###################################################

proc ::QMtool::reset_all {} {

#    set reply [tk_dialog .foo "Reset - save file" "Quitting QMtool - Save project changes?" \
# 		 question 0 "Save" "Don't save" "Cancel"]
#    switch $reply {
#       0 { save_project $::QMtool::projectname }
#       1 { }
#       2 { return 0 }
#    }

   remove_traces

   # Set mouse to rotation mode
   mouse mode 0
   mouse callback off; 

   if { [winfo exists .qm_setup] }        { wm withdraw .qm_setup }
   if { [winfo exists .qm_nbo] }          { wm withdraw .qm_nbo }
   if { [winfo exists .qmtool_intcoor] }  { wm withdraw .qmtool_intcoor }
   if { [winfo exists .qmtool_atomedit] } { ::Atomedit::reset .qmtool_atomedit; destroy .qmtool_atomedit }

   if {[molinfo top]>=0} { 
      if {[molinfo top get numatoms]} {
	 draw delete all
      }
   }

   # Delete child namespaces
   foreach ns [namespace children ::QMtool::] {
      namespace delete $ns
      puts "Deleting namespace $ns"
   }

   # Forget everything:
   init_variables ::QMtool
   initialize
}

proc ::QMtool::default_atomprop_entry {} {
   return [list {} {} {} {} {} {} {} {} {} {} {} {}]
}

##################################################
# Callback function for VMD's extension menu.    #
##################################################
proc qmtool_tk_cb {} {
  ::QMtool::qmtool
  return $::QMtool::w
}


source [file join $env(QMTOOLDIR) qmtool_analysis.tcl]
source [file join $env(QMTOOLDIR) qmtool_atomedit.tcl]
source [file join $env(QMTOOLDIR) qmtool_aux.tcl]
source [file join $env(QMTOOLDIR) qmtool_charges.tcl]
source [file join $env(QMTOOLDIR) qmtool_intcoor.tcl]
source [file join $env(QMTOOLDIR) qmtool_readwrite.tcl]
source [file join $env(QMTOOLDIR) qmtool_setup.tcl]
 
