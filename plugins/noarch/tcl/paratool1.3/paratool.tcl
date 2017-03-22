#
# Paratool plugin
#
# $Id: paratool.tcl,v 1.103 2007/09/12 13:42:48 saam Exp $
#

#  Usage: paratool [-xyz|-pdb file] [-log|-com|-zmt|-int|-zmat file]


#  Paratool
#  ============================
# Paratool provides a graphical interface for force field parametrizations of molecules
# that are not contained in your force field. It is designed to generate CHARMM or AMBER
# compliant parameters (while it is more specialized on CHARMM).

# The plugin helps you to generate the molecule or the moleular fragment that should be
# parametrized and to set up the necessary quantumchemical calculations (you'll need
# Gaussian, later versions will also support GAMESS). Paratool reads the logfiles of the
# QM simulations, computes force field parameters for bonds, angles dihedrals and impropers
# by transforming the Hessian into internal coordinates and converting all values into
# units based on kcal/mol, Å and degrees. You can assign atom types and the corresponding
# VDW parameters from a list of already existing types or generates new types (all chemical
# elements H - Rn supported). The charges can be determined using restricted electrostatic
# potential fitting RESP (AMBER style) or CHARMM style charges using their supramolecular
# approach which requires another Gaussian calculation.

# Paratool generates input for all necessary external programs collects and compiles all
# the necessary data, organizes and displays them neatly in lists and projects them onto
# your molecule in VMD. Finally it will write the topology and parameter files you'll need
# to build the molecule using psfgen and run your simulation in your favourite simulation
# package, e.g. NAMD. 


# Atom tag code:
# --------------
# Paratool:
# original pdb/psf     beta=0.0
# CompDB added atom    beta=0.3
# Environment atom     beta=1.0
# --> unparametrized atoms beta<1.0
#
# Molefacture:
# original unparametrized  occu=1.0
# added hydrogen fixed     occu=0.8
# added hydrogen draft     occu=0.5
# deleted atom             occu=0.3
# repository atoms         occu=0.0
# --> shown atoms          occu>0.4

# Molecules in Paratool
# ---------------------
#
# Paratool knows five different molecules:
# 1) Parent molecule: This is the molecule with the embedded unparametrized fragment.
#    Ideally it is provided by autopsf. The parent mol never changes so that we can
#    always revert to the initial state by deleting the other molecules.
# 2) Base molecule: Contains the unparametrized fragment plus a user defined 
#    selection of surrounding atoms that might be needed to build the model for 
#    QM geometry optimization for which the base molecule is the input structure.
#    The base molecules is updated whenever the user selection changes or topology 
#    info from the component database is retrieved. The basemolecule can be modified 
#    manually using Molefacture.
# 3) Optimized geometry: Structure after QM geom. optimization. Typically a Gaussian
#    or Gamesss logfile loaded through the GAMESS/GAUSSIAN molfile plugin.
#    This is the input structure for the frequency calc. and the Single point calc.
# 4) Frequency calculation: A Gaussian/Gamess logfile that provides the Hessian matrix.
# 5) Singlepoint calculation: A Gaussian/Gamess logfile that provides data for 
#    the determination of charges.

package require exectool 1.2
package require qmtool
package require molefacture
package require atomedit
package require readcharmmtop
package require readcharmmpar
package require multiplot
package require namdgui
package require optimization
package require namdserver
package provide paratool 1.3

# package require resptool is done on the fly in paratool_respcharges.tcl
# package require hesstrans is done in ::Paratool::transform_hessian_cartesian_to_internal

namespace eval ::Paratool:: {
   namespace export paratool
   namespace export select_atoms;      # for charmmcharges
   namespace export update_atomlabels; # for charmmcharges
   namespace export atomedit_draw_selatoms; # for charmmcharges
   namespace export get_atomprop; # for charmmcharges
   namespace export set_atomprop; # for charmmcharges
   namespace export format_float;
   namespace import ::util::clear_bondlist; # qmtool_aux.tcl
   namespace import ::QMtool::angles_per_vmdbond; # qmtool_intcoor.tcl
   namespace import ::QMtool::diheds_per_vmdbond; # qmtool_intcoor.tcl

   proc default_zmat {} {
      return {{0 0 0 0 0 0 0 0}}
   }
   proc initialize { } {
      # general stuff
      variable w;                       # Handle to main window
      variable bigmolid    -1;          # This is the molid of the entire molecule, containing subprojects
      variable projectlist {};          # List of projects associated with this molecule

      variable projectname   "project1.ptl";  # Name of the loaded project, basename for files
      variable projectsaved  1;               # Are all project data saved?
      variable savenamespacelist {::Paratool::Refinement}; # List of child namespaces that should be saved with the project
      variable workdir       "[pwd]";         # working directory
      variable selectcolor   lightsteelblue
      variable viewpointbase {};
      variable fixedfont     {Courier 9};

      variable molidparent     -1;  # Mol ID of the parent pdb file
      variable molidbase       -1;  # The original geometry
      variable molidopt        -1;  # QM optimized geometry
      variable molidsip        -1;  # Single point calc for charges, NBO,...
      variable molnameparent   {};  # Name of the parent pdb file
      variable molnamebase     {};  # Name of the fragment pdb file (orig. conformation)
      variable molnameopt      {};  # Name of QM geometry optimization logfile
      variable molnamesip      {};  # Name of QM single point calculation logfile
      variable molnamefreq     {};  # Name of QM frequency calculation logfile
      variable chkfileopt      {};  # Checkpoint file of QM geometry opt.
      variable chkfilesip      {};  # Checkpoint file of Single point calc.
      variable chkfilefreq     {};  # Checkpoint file of frequency calculation
      variable optmethod       {};  # QM method of frequency calculation
      variable freqmethod      {};  # QM method of frequency calculation
      variable optbasisset     {};  # QM basisset of frequency calculation
      variable freqbasisset    {};  # QM basisset of frequency calculation
      variable unparsel        {};  # Indices of unparametrized atoms in parent molecule
      variable extrabonds      {};  # List of atom pairs sepcified by {segid resid name} for inter-residue bonds
      variable fragmentseltext {unparametrized};  # Indices of fragment selection
      variable oldfragmentseltext {};
      variable fragmentrepparent {};  # unique representation name
      variable fragmentrepbase   {};  # unique representation name
      atomselect macro unparametrized   "beta<1"
      atomselect macro addedmolefacture "occupancy 0.8"

      variable topologyfiles    {};  # List of loaded CHARMM topology files
      variable paramsetfiles    {};  # List of loaded CHARMM parameter files
      variable topologylist     {};  # List in which the topology data are kept
      variable paramsetlist     {};  # List in which the parameters are kept
      variable psfconformations {};  # angles, diheds, imprps for parent molecule from psf
      variable newtopofile      {};  # File containing the new topology
      variable newtopology      {};  # New topology data
      variable newparamfile     {};  # File containing the new parameters
      variable newparamset      {};  # New parameter set
      variable useamberparams    0;  # Instead of CHARMM use AMBER topo/params (but in CHARMM format)
      variable psfgeninputfile  {};  # File name for autogenerated psfgen input files
      variable psf              {};  # PSF file resulting from psfgen
      variable pdb              {};  # PDB file resulting from psfgen
      variable namdserver        0;  

      variable totalcharge     0.0;  # total system charge
      variable multiplicity      1;  # multiplicity
      variable istmcomplex       0;  # Is this a transition metal complex
      variable isironsulfur      0;  # Is this an iron-sulphur complex?
      variable tmliganddistance 2.5; # Max distance for tmcomplex-ligand bonds
      variable tmcomplexlist    {};  # List of existing TM-complexes
      variable tmligandlist     {};  # List of ligand residues for each TM-complex
      variable complexbondlist  {};  # List of complex-ligand bonds
      variable tmcomplex        {};  # List of atoms belonging to the selected complex
      variable tmligands        {};  # List of {segid resid} pairs defining the ligands of the selected complex
      variable tmuseimidazole    0;  # Use imidazole instead of HIS in TM complexes
      variable tmuseethanethiol  0;  # Replace CYS by methyl-capped CYS sidechain in TM complexes
      variable histoimd         {};  # List of histidines that are modeled as imidazoles
      variable tmimdtopology     0;  
      variable ligandstotalcharge {};
      variable centertotalcharge  {};
      variable tmincludediheds   0;
      variable tmincludeimprps   0;
      variable tmincludeangles   0;
      variable tmnewtypes       {};
      variable tmpatchname      {};
      variable patchtopology    {};
      variable tmpatch          {};
      variable exclusions       {}; # List of explicitly excluded nonbonded pairs
      variable tmexclusion     "same as rest"; # Exclusion policy for metal complexes
      variable tmsegrestrans    {}; # Translation between segids and resids of base and built molecules
      variable exactdihedrals    0;

      # Coordinates:
      # We keep a copy of the cartesians coordinates just in case the user messes
      # around with the logfiles.
      variable basecartesians {}; # cartesian coordinates of the original system
      variable optcartesians  {}; # cartesian coordinates of the optimized system

      variable zmat    {{0 0 0 0 0 0 0 0}}; # list of internal coordinates
      variable zmatqm            {};  # original list of internal coordinates from QMtool
      variable hessian           {};  # Hessian in cartesian coordinates
      variable inthessian_kcal   {};  # Hessian in internal coordinates and kcal/mol
      variable formatintcoorlist {};  # formatted zmat
      variable scfenergies       {};  # SCF energies of optimizations and potential scans
      variable dipolemoment      {};  # Dipole moment from QMtool
      
      # zmat header values as variables and some flags
      variable natoms   0;
      variable ncoords  0;
      variable nbonds   0;
      variable nangles  0;
      variable ndiheds  0;
      variable nimprops 0;
      variable havepar  0;       # are bondlengths and angle values present?
      variable havefc   0;       # are force constants present?
      variable havecart 0;       # are cartesian coords present?
      variable havemulliken 0;   # are mulliken charges present?
      variable havenpa  0;       # are NPA charges present?
      variable haveesp  0;       # are ESP charges present?
      variable haveresp 0;       # are RESP charges present?
      variable havesupram 0;     # are CHARMM supramolecular charges present?
      variable havefofi 0;       # are Force Field charges present?
      variable numfixed 0;       # are fixed atoms present?
      variable newparamsonly 1;  # only write new parameters (calculated, not from CHARMM)

      variable atomproplist  {};  
      variable atompropcanon {Index Elem Name Type Known Resid Rname Segid VDWeps VDWrmin VDWeps14 VDWrmin14 Charge}
      variable atomproptags  [concat $atompropcanon Lewis]
      variable atompropformlist  {}
      variable atompropformtags  {}
      variable atompropeditabletags  {Elem Name Type Resid Rname Segid VDWeps VDWrmin VDWeps14 VDWrmin14 Charge Lewis}
      variable atompropeditablenames {Elem Name Type Resid Rname Segid VDWeps VDWrmin VDWeps14 VDWrmin14 Charge Lewis}
      variable copychargetypes       {Lewis};  # Charge types that can be copied in Atomedit
      variable havetypes    0;
      variable ringlist    {};    # List of rings in molidbase
      variable labelscaling 0;    # Scale coordinate labels with force constant values?
      variable labelradius 0.21;  # default radius for the label tubes
      variable labelsize 1.0;     # Size of text labels
      variable labeldist   2;     # Distance between an atom and its label
      variable labelres   20;     # Resolution of the label spheres and tubes
      variable bondthickness 0.1; # Bond radius of normal bonds

      # for the intcoor window:
      variable selintcoorlist {};     # list of actually selected internal coordinates
      variable pickmode "conf";       # are we currently picking atoms?
      variable picklist {};           # list of previously picked atoms.
      variable selectedpar0 {};
      variable selectedpar1 {};
      variable selectedpar2 {};
      variable selectedpar3 {};
      
      # for atom labels:
      variable atomlabeltags     {};  # tags for drawing primitives returned by the "draw" command
      variable atomlabelselected  1;  # only draw labels for selected atoms
      variable atommarktags      {};
      variable Indexlabels        0
      variable Elemlabels         0
      variable Namelabels         0
      variable Typelabels         0
      variable Knownlabels        0
      variable Residlabels        0
      variable Rnamelabels        0
      variable Segidlabels        0
      variable VDWepslabels       0
      variable VDWrminlabels      0
      variable VDWeps14labels     0
      variable VDWrmin14labels    0
      variable Chargelabels       0
      variable Lewislabels        0
      variable Mulliklabels       0
      variable MulliGrlabels      0
      variable NPAlabels          0
      variable SupraMlabels       0
      variable ESPlabels          0
      variable RESPlabels         0
      variable ForceFlabels       0
      
      # for internal coordinate labels
      variable intcoortaglabels  1
      variable intcoornamelabels 1
      variable intcoorvallabels  1
      variable intcoorfclabels   1
      variable intcoormarktags   {};  # List of graphics tags for internal coordinate labels

      # for charmm charges
      variable havecharmmcharge 0; # are charmm type charges present?
      variable optmethod   {}
      variable optbasisset {}

      # for nbo analysis
#      variable havelewis           0
      variable nbofilename         {}
      variable lewisdoublebonds    {}
      variable lewischargedatoms   {}
      variable lewischargeselected {}
      variable lewislonepairs      {}
      variable lewislonepairsbeta  {}

      # For the Component finder
      variable componentdburl  "http://pdb.rutgers.edu/public-component-erf.cif";  # URL of CCD (mmCIF)
      variable componentdbpath "[file join $workdir [file tail $componentdburl]]"; # Path of PDB Chemical Component Dict.
      if {![file exists $componentdbpath]} { set componentdbpath {} }
      variable compchecktext {};
      variable compid        {}
      variable compidlist    {}
      variable compdatalist  {}
      variable compname      {}
      variable comptype      {}
      variable compformula   {}
      variable compsynonyms  {}
      variable compatomlist  {}
      variable compbondlist  {}
      variable compatomnamelist {};

      # for the edit internal coordinate window
      variable addtype "bond";        # selected type of coordinate in 'add coordinate' window
      variable gendepangle 0;         # generate all angles containing the new bond?
      variable gendepdihed 0;         # generate diheds containing the new bond?
      variable gendepdihedmode "all"; # generate one or all diheds containing the new bond?
      variable genvmdbond  0;         # generate bonds in VMD only?
      variable autogendiheds "all";   # Autogenerate one or all diheds per torsion?
      variable removedependent 1;     # remove all coords that depend on a deleted coordinate?
      variable maxbondlength 1.65;    # maximum bond length for bond recalculation
      variable importknowntopo 1;     # Import topologies for known conformations from file?
      variable chooseanalogformat {}; # Format string for Analog Parameter list
      variable intcoorformat {};      # Format string for internal coordinate list
      variable charmmoverridesqm 1;   # Shall CHARMM parameters override QM-based parameters?
      variable matchingtypes 0;       # Show only params for matching types when choosing analog params?
      variable matchtypespattern {};  # Pattern used to find matching parameters choosing analog params
      variable scanenergies {};   # SCF energies from rigid potential scan 
      variable scanwidth   0.5;   # Potential scan width (in each direction) for forcefield based scans
      variable scansteps   50;    # Number of potential scan steps for forcefield based scans
      variable qmscanwidth 0.5;   # Potential scan width (in each direcction) for QM based scans
      variable qmscansteps 8;     # Number of potential scan steps for QM based scans
      variable qmscanentry {};    # Name tag of the zmatentry that was scanned
      variable qmscantype "Rigid";    # Rigid or Relaxed
      variable selparamlist {};
      variable selparformat {};
      variable selpareditformat {};
   }
   initialize
}


#######################################################
# Wrapper to make calling of the main program easier. #
#######################################################

proc paratool { args } {
   if {![namespace exists ::Paratool]} {
      # Create and initialize variables with default values
      ::Paratool::initialize
   }
   eval ::Paratool::paratool $args
}


################################################
# The main startup routine, evaluates the      #
# command line arguments and starts the GUI.   #
################################################

proc ::Paratool::paratool { args } {
   variable workdir  "[pwd]";
   variable useamberparams
   global env
   if {!$useamberparams} {
      variable topologyfiles [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
      variable paramsetfiles [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]
   } else {
      variable topologyfiles [file join $env(CHARMMTOPDIR) top_amber2charmm.inp]
      variable paramsetfiles [file join $env(CHARMMPARDIR) par_amber2charmm.inp]
   }
   variable topologylist  [list [::Toporead::read_charmm_topology $topologyfiles]]
   variable paramsetlist  [list [::Pararead::read_charmm_parameters $paramsetfiles]]


   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      #if {$i=="-nogui"}  then {
      #   set gui 0
      #   set arglist [lreplace $arglist $argnum $argnum]
      #   continue
      #}
      #incr argnum
   }

   set loadparent {}
   set loadbase {}
   set loadopt  {}
   set loadsip  {}
   # Scan for options with one argument
   foreach {i j} $arglist {
      if {$i=="-project" || $i=="-p"}      then { 
	 load_project $j
      }
      if {$i=="-top"} then { 
	 variable topologylist
	 variable topologyfiles
	 foreach file $j {
	    set ret [lsearch -exact $topologyfiles $file]
	    if {$ret>=0} {
	       set topologyfiles [lreplace $topologyfiles $ret $ret]
	       set topologylist  [lreplace $topologylist  $ret $ret]
	    }
	    lappend topologylist [::Toporead::read_charmm_topology $file]
	    lappend topologyfiles $file
	 }
      }
      if {$i=="-par"} then { 
	 variable paramsetlist
	 variable paramsetfiles
	 foreach file $j {
	    set ret [lsearch -exact $parameterfiles $file]
	    if {$ret>=0} {
	       set paramsetfiles [lreplace $paramsetfiles $ret $ret]
	       set paramsetlist  [lreplace $paramsetlist  $ret $ret]
	    }
	    lappend paramsetlist [::Pararead::read_charmm_parameters $file]
	    lappend paramsetfiles $file
	 }
      }
      if {$i=="-unparsel"}      then { 
	 variable unparsel $j
      }
      if {$i=="-extrabonds"}      then { 
	 variable extrabonds $j
      }
      if {$i=="-parent"}      then { 
	 set loadparent $j
      }
      if {$i=="-parentid"}      then { 
	 # This is used by autopsf to invoke Paratool with the currently loaded molecule
	 variable molidparent $j
	 if {[lsearch [molinfo list] $j]>=0} {
	    variable molnameparent [lindex [join [molinfo $j get filename]] 0]

	    # Setup a trace on the existence of this molecule
	    global vmd_initialize_structure
	    trace add variable vmd_initialize_structure($molidparent) write ::Paratool::molecule_assert
	 } else {
	    error "No molecule with molid $j loaded!"
	 }
      }
      if {$i=="-basemol"}      then { 
	 set loadbase $j
      }
      if {$i=="-optgeom"}      then { 
	 set loadopt $j
      }
      if {$i=="-sp"}      then { 
	 set loadsip $j
      }
   }

   variable unparsel
   variable molidparent

   if {$molidparent>=0} {
      set all [atomselect $molidparent all]

      # Set multiple bondorders right
      import_bondorders_from_topology $molidparent

      # Get the angles, dihedrals and impropers from PSF
      import_conformations_from_psf $molidparent

      if {[llength $unparsel]} {
	 # Remember the initial unparametrized atom independently
	 $all set beta 1
	 $all set occupancy 1
	 $unparsel set beta 0
      }
      $all delete

   }

   # First load the parent molecule
   if {[llength $loadparent]} { load_parentmolecule $loadparent }

   # We must load the molecules in the right order:
   if {[llength $loadbase]}   { load_basemolecule   $loadbase; }
   if {[llength $loadopt]}    { load_molecule OPT   $loadopt }
   if {[llength $loadsip]}    { load_molecule SIP   $loadsip }
   
   if {$molidparent>=0} {
      # Set explicitly provided bonds
      set_extrabonds
      
      # Find centers of metal complexes
      find_complex_centers $molidparent

      update_fragment_selection
   }


   # Start the gui
   paratool_gui
}


###############################################
# Starts the GUI.                             #
###############################################

proc ::Paratool::paratool_gui {} {
   variable w
   variable selectcolor

   # If already initialized, just turn on
   if { [winfo exists .paratool] } {
      wm deiconify .paratool
      raise .paratool
      return
   }

   set w [toplevel ".paratool"]
   wm title $w "Paratool Main"
   wm resizable $w 0 0
   wm protocol .paratool WM_DELETE_WINDOW {
      ::Paratool::unmap_children
      wm withdraw .paratool
   }

   tk_setPalette background [.paratool cget -bg] selectbackground $selectcolor

   menu $w.menu -tearoff 0
   menu $w.menu.file -tearoff 0
   $w.menu add cascade -label "File" -menu $w.menu.file -underline 0

   menu $w.menu.file.open -tearoff 0

   $w.menu.file add command -label "Load project" -command {::Paratool::opendialog loadproject}
   $w.menu.file add command -label "Save project" -command {
      ::Paratool::opendialog saveproject $::Paratool::projectname }

   $w.menu.file add separator
   $w.menu.file add command -label "Load parent molecule" -command { 
      ::Paratool::opendialog loadparentmol
   }
   $w.menu.file add separator
   $w.menu.file add command -label "Load molecule for parametrization (base molecule)" -command { 
      ::Paratool::opendialog loadbasemol
   }
   $w.menu.file add command -label "Save base molecule" -command {
      ::Paratool::opendialog savebasemol $::Paratool::molnamebase
   }
   $w.menu.file add separator
   $w.menu.file add command -label "Setup QM geometry optimization" -command {
      ::Paratool::setup_geometry_opt
   }
   $w.menu.file add command -label "Import optimized geometry" \
      -command {::Paratool::opendialog loadoptgeom "[file rootname ${::Paratool::molnamebase}]_opt"}

#    $w.menu.file add separator
#    $w.menu.file add command -label "Setup QM frequency calculation" -command {
#       ::Paratool::setup_frequency_calc
#    }
#    $w.menu.file add command -label "Import force constants from freq. calc." \
#       -command {::Paratool::opendialog loadfreq "[file rootname ${::Paratool::molnamebase}]_freq"}

   $w.menu.file add separator
   $w.menu.file add command -label "Write topology file" \
      -command {::Paratool::write_topology }

   $w.menu.file add command -label "Write parameter file" \
      -command {::Paratool::write_parameters}

   $w.menu.file add command -label "Write psfgen input file and run psfgen" \
      -command {::Paratool::write_psfgen_input -build }

   $w.menu.file add command -label "NAMD test simulation" \
      -command { ::Paratool::namd_testsim }

   $w.menu.file add separator
   $w.menu.file add command -label "Reset all" -command {::Paratool::reset_all}


   menu $w.menu.hessian -tearoff 0
   $w.menu add cascade -label "Hessian" -menu $w.menu.hessian -underline 0

   $w.menu.hessian add command -label "Setup QM single point calc. (Hessian, charges)" -command {
      ::Paratool::setup_singlepoint_calc
   }
   $w.menu.hessian add command -label "Import Hessian/charges from single point calc." \
      -command {::Paratool::opendialog loadsip "[file rootname ${::Paratool::molnamebase}]_sp"}
   $w.menu.hessian add command -label "Import raw cartesian Hessian" \
      -command {::Paratool::opendialog rawhess}

   $w.menu.hessian add separator
   $w.menu.hessian add command -label "Setup internal coord. transformation of Hessian" -command {
      ::Paratool::setup_coordinate_trans
   }
   $w.menu.hessian add command -label "Import force constants from transformation" \
      -command {::Paratool::opendialog loadtransf "[file rootname ${::Paratool::molnamebase}]_transf"}
   $w.menu.hessian add separator
   $w.menu.hessian add command -label "View Hessian (internal coords)" -accelerator <Ctrl-h> \
      -command {::Paratool::Hessian::gui}


   menu $w.menu.edit -tearoff 0
   $w.menu add cascade -label "Edit" -menu $w.menu.edit -underline 0

   $w.menu.edit add command -label "Atom properties" -accelerator <Ctrl-a> \
      -command {::Paratool::edit_atom_properties}
   $w.menu.edit add command -label "Internal coordinates" -accelerator <Ctrl-i> \
      -command {::Paratool::edit_internal_coords}
   $w.menu.edit add command -label "Auto assign type names" -accelerator <Ctrl-t> \
      -command {::Paratool::assign_unique_atomtypes}
   $w.menu.edit add command -label "Auto assign VDW parameters" -accelerator <Ctrl-v> \
      -command {::Paratool::autoassign_vdw_params}

   $w.menu.edit add separator
   $w.menu.edit add command -label "Determine chemical compound"  -accelerator <Ctrl-d> \
      -command { ::Paratool::component_finder }

   $w.menu.edit add separator
   $w.menu.edit add command -label "Metal complexes/FeS-clusters" -accelerator <Ctrl-m> \
      -command ::Paratool::metal_complex_gui

   $w.menu.edit add separator
   $w.menu.edit add command -label "Lewis structure in Molefacture" -accelerator <Ctrl-l> \
      -command ::Paratool::molefacture_start 

   $w.menu.edit add separator
   $w.menu.edit add command -label "Refine 1-4 nonbonded interactions" -accelerator <Ctrl-n> \
      -command {::Paratool::Refinement::nonb_gui}

   menu $w.menu.charges -tearoff 0
   $w.menu add cascade -label "Charges" -menu $w.menu.charges -underline 0

   $w.menu.charges add command -label "Determine CHARMM type charges" \
      -command {::CHARMMcharge::setup_charmm_charges}
   $w.menu.charges add command -label "Determine RESP charges (AMBER)" \
      -command {::Paratool::resp_charges}

   menu $w.menu.labels -tearoff 0
   $w.menu add cascade -label "Labels" -menu $w.menu.labels -underline 0

   $w.menu.labels add checkbutton -label "Internal coordinate tags" -variable ::Paratool::intcoortaglabels \
      -command {::Paratool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Internal coordinate atom names" -variable ::Paratool::intcoornamelabels \
      -command {::Paratool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Internal coordinate values" -variable ::Paratool::intcoorvallabels \
      -command {::Paratool::update_intcoorlabels}
   $w.menu.labels add checkbutton -label "Force constants" -variable ::Paratool::intcoorfclabels \
      -command {::Paratool::update_intcoorlabels}
   $w.menu.labels add separator
   $w.menu.labels add checkbutton -label "Indices" -variable ::Paratool::Indexlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Names" -variable ::Paratool::Namelabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Types" -variable ::Paratool::Typelabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "User charges" -variable ::Paratool::Chargelabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Lewis charges" -variable ::Paratool::Lewislabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Mulliken charges" -variable ::Paratool::Mulliklabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Mulliken charge groups" -variable ::Paratool::MulliGrlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "ESP charges" -variable ::Paratool::ESPlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "NPA charges" -variable ::Paratool::NPAlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "CHARMM charges" -variable ::Paratool::SupraMlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add checkbutton -label "Force field charges" -variable ::Paratool::ForceFlabels \
      -command {::Paratool::update_atomlabels}
   $w.menu.labels add separator
   $w.menu.labels add checkbutton -label "Selected atoms only" -variable ::Paratool::atomlabelselected \
      -command {::Paratool::update_atomlabels}

   $w.menu.labels add separator
   $w.menu.labels add command -label "Clear atom labels" \
      -command {
	 set ::Paratool::Indexlabels 0; 
	 set ::Paratool::Namelabels 0; 
	 set ::Paratool::Typelabels 0; 
	 set ::Paratool::Chargelabels 0; 
	 set ::Paratool::Lewislabels 0; 
	 set ::Paratool::Mulliklabels 0; 
	 set ::Paratool::Mulliklabels 0;
	 set ::Paratool::NPAlabels 0;
	 set ::Paratool::SupraMlabels 0;
	 set ::Paratool::ESPlabels 0; 
	 set ::Paratool::RESPlabels 0; 
	 set ::Paratool::ForceFlabels 0; 
	 ::Paratool::update_atomlabels}
   $w.menu.labels add command -label "Clear internal coord labels" \
      -command {
	 .paratool_intcoor.zmat.pick.list selection clear 0 end;
	 set ::Paratool::selintcoorlist {};
	 ::Paratool::update_intcoorlabels;
	 if {![winfo exists .paratool_atomedit]} {
	    set ::Atomedit::paratool_atomedit_selection {}
	    ::Paratool::update_atomlabels
	    ::Paratool::atomedit_draw_selatoms
	 }
      }
   $w.menu.labels add command -label "Clear all VMD labels" \
      -command {label delete Atoms all; label delete Bonds all; label delete Angles all;
      label delete Dihedrals all}

   ## help menu
   menu $w.menu.help -tearoff no
   $w.menu add cascade -label "Help" -menu $w.menu.help -underline 0
   $w.menu.help add command -label "About" \
      -command {tk_messageBox -type ok -title "About ParaTool" \
		   -message "Easy generation of force field parameters.\nAuthor: Jan Saam"}
   $w.menu.help add command -label "Citation" \
      -command {tk_messageBox -type ok -title "Citing ParaTool" \
		   -message "Please use the reference given on the website:\nhttp://www.ks.uiuc.edu/Research/vmd/plugins/paratool/"}
   $w.menu.help add command -label "Help..." \
      -command {vmd_open_url "http://www.ks.uiuc.edu/Research/vmd/plugins/paratool/"}
   # "vmd_open_url [string trimright [vmdinfo www] /]/plugins/paratool"

   # Finally show the menu:
   $w configure -menu $w.menu

   ############## frame for project info #################
   labelframe $w.proj -bd 2 -relief ridge -text "Project" -padx 1m -pady 1m

   label  $w.proj.nameentry  -textvariable ::Paratool::projectname -width 50 -font {Helvetica 10 }
   pack $w.proj.nameentry

   frame $w.proj.workdir
   label  $w.proj.workdir.label  -text "Working directory: "
   entry  $w.proj.workdir.entry  -textvariable ::Paratool::workdir -width 65 -relief sunken -justify left -state readonly
   button $w.proj.workdir.button -text "Choose" -command { ::Paratool::opendialog workdir }
   pack $w.proj.workdir.label $w.proj.workdir.entry $w.proj.workdir.button -side left -anchor e -padx 1m -pady 1m
   pack $w.proj.workdir  -padx 1m -pady 1m -anchor e 

   pack $w.proj -side top -pady 5 -padx 3 -fill x -anchor w

   labelframe $w.mol -text "Molecules"
   label  $w.mol.legendid   -text "ID"
   label  $w.mol.legendname -text "Molecule file name"
   grid $w.mol.legendid    -row 0 -column 1 -sticky w -padx 1m
   grid $w.mol.legendname  -row 0 -column 2 -sticky w -padx 1m

   label  $w.mol.parentlabel  -text "Parent molecule: "
   entry  $w.mol.parentid     -textvariable ::Paratool::molidparent -width 3 -justify right -state readonly
   entry  $w.mol.parententry  -textvariable ::Paratool::molnameparent -width 50 -relief sunken \
      -justify left -state readonly
   grid $w.mol.parentlabel  -row 1 -column 0 -sticky w -padx 1m
   grid $w.mol.parentid     -row 1 -column 1 -sticky w -padx 1m
   grid $w.mol.parententry  -row 1 -column 2 -sticky w -padx 1m

   label  $w.mol.baselabel  -text "Molecule to parametrize (base molecule): "
   entry  $w.mol.baseid     -textvariable ::Paratool::molidbase -width 3 -justify right -state readonly
   entry  $w.mol.baseentry  -textvariable ::Paratool::molnamebase -width 50 -relief sunken \
      -justify left -state readonly
   grid $w.mol.baselabel  -row 2 -column 0 -sticky w -padx 1m
   grid $w.mol.baseid     -row 2 -column 1 -sticky w -padx 1m
   grid $w.mol.baseentry  -row 2 -column 2 -sticky w -padx 1m

   label  $w.mol.optlabel  -text "Optimized geometry: "
   entry  $w.mol.optid     -textvariable ::Paratool::molidopt -width 3 -justify right -state readonly
   entry  $w.mol.optentry  -textvariable ::Paratool::molnameopt -width 50 -relief sunken \
      -justify left -state readonly
   grid $w.mol.optlabel  -row 3 -column 0 -sticky w  -padx 1m
   grid $w.mol.optid     -row 3 -column 1 -sticky w  -padx 1m
   grid $w.mol.optentry  -row 3 -column 2 -sticky we -padx 1m

#    label  $w.mol.freqlabel  -text "Freqency calc. (Hessian): "
#    entry  $w.mol.freqid     -textvariable ::Paratool::molidfreq -width 3 -justify right -state readonly
#    entry  $w.mol.freqentry  -textvariable ::Paratool::molnamefreq -width 50 -relief sunken \
#       -justify left -state readonly
#    grid $w.mol.freqlabel  -row 4 -column 0 -sticky w  -padx 1m
#    grid $w.mol.freqid     -row 4 -column 1 -sticky w  -padx 1m
#    grid $w.mol.freqentry  -row 4 -column 2 -sticky we -padx 1m

   label  $w.mol.siplabel  -text "Single point calc. (Hessian + charges): "
   entry  $w.mol.sipid     -textvariable ::Paratool::molidsip -width 3 -justify right -state readonly
   entry  $w.mol.sipentry  -textvariable ::Paratool::molnamesip -width 50 -relief sunken \
      -justify left -state readonly
   grid $w.mol.siplabel  -row 5 -column 0 -sticky w -padx 1m
   grid $w.mol.sipid     -row 5 -column 1 -sticky w -padx 1m
   grid $w.mol.sipentry  -row 5 -column 2 -sticky we -padx 1m

   pack $w.mol  -padx 1m -pady 1m -ipady 1m -anchor e -expand 1 -fill x

   labelframe $w.frag -text "Edit fragment for parametrization" -padx 1m -pady 1m
   frame  $w.frag.size
   label  $w.frag.size.sel -text "Selection of atoms from parent molecule:"
   entry  $w.frag.size.entry -textvariable ::Paratool::fragmentseltext -width 48
   button $w.frag.size.button -text "Reset" -command ::Paratool::reset_selection
   grid $w.frag.size.sel    -column 2 -row 0 -sticky w
   grid $w.frag.size.entry  -column 3 -row 0 -sticky w
   grid $w.frag.size.button -column 4 -row 0 -sticky w
   pack $w.frag.size -padx 1m -pady 1m
   bind $w.frag.size.entry <Return> {
      ::Paratool::update_fragment_selection
   }
   update_fragsel_entry_state
   trace add variable ::Paratool::molidparent write ::Paratool::update_fragsel_entry_state

   frame $w.frag.molef
   label $w.frag.molef.label -text "Edit fragment manually using Molefacture: "
   button $w.frag.molef.button -text "Edit in Molefacture" -command ::Paratool::molefacture_start
   grid $w.frag.molef.label  -column 0 -row 0 -sticky w
   grid $w.frag.molef.button -column 1 -row 0 -sticky w
   pack $w.frag.molef -padx 1m -pady 1m

   pack $w.frag -padx 1m -pady 1m -expand 1 -fill x

   ############## frame for topology file list #################
   labelframe $w.topo -bd 2 -relief ridge -text "Topology files" -padx 1m -pady 1m
   frame $w.topo.list
   scrollbar $w.topo.list.scroll -command "$w.topo.list.list yview"
   listbox $w.topo.list.list -activestyle dotbox -yscroll "$w.topo.list.scroll set" \
      -width 80 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::topologyfiles
   frame  $w.topo.list.buttons
   button $w.topo.list.buttons.add -text "Add"    -command {
      ::Paratool::opendialog topo
      ::Paratool::import_bondorders_from_topology $::Paratool::molidbase
      ::Paratool::assign_ForceF_charges
      ::Paratool::atomedit_update_list
   }
   button $w.topo.list.buttons.delete -text "Delete" -command {
      foreach i [.paratool.topo.list.list curselection] {
	 .paratool.topo.list.list delete $i
	 set ::Paratool::topologylist [lreplace $::Paratool::topologylist $i $i] 
	 ::Paratool::assign_ForceF_charges
	 ::Paratool::atomedit_update_list
      }
   }
   pack $w.topo.list.buttons.add $w.topo.list.buttons.delete -expand 1 -fill x
   pack $w.topo.list.list -side left  -fill x -expand 1
   pack $w.topo.list.scroll $w.topo.list.buttons -side left -fill y -expand 1
   pack $w.topo.list -expand 1 -fill x

   frame $w.topo.new
   label $w.topo.new.label -text "New topology file: "
   entry $w.topo.new.entry -relief sunken -width 68 -justify left -state readonly \
      -textvariable ::Paratool::newtopofile
   button $w.topo.new.button -text "Write" -command { ::Paratool::write_topology }
   pack $w.topo.new.label $w.topo.new.entry $w.topo.new.button -side left -anchor w
   pack $w.topo.new -anchor w -pady 1m

   frame $w.amber
   checkbutton $w.amber.check -text "Instead of CHARMM use AMBER topologies and parameters (in CHARMM format)" \
      -variable ::Paratool::useamberparams -command { ::Paratool::toggle_charmm_amber }
   pack $w.amber.check -side left -anchor w

   ############## frame for parameter file list #################
   labelframe $w.para -bd 2 -relief ridge -text "Parameter files" -padx 1m -pady 1m
   frame $w.para.list
   scrollbar $w.para.list.scroll -command "$w.para.list.list yview"
   listbox $w.para.list.list -activestyle dotbox -yscroll "$w.para.list.scroll set" \
      -width 80 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::Paratool::paramsetfiles
   frame  $w.para.list.buttons
   button $w.para.list.buttons.add -text "Add"    -command {
      ::Paratool::opendialog para
      ::Paratool::assign_vdw_params
      ::Paratool::atomedit_update_list nocomplexcheck
   }
   button $w.para.list.buttons.delete -text "Delete" -command {
      foreach i [.paratool.para.list.list curselection] {
	 .paratool.para.list.list delete $i
	 set ::Paratool::paramsetlist  [lreplace $::Paratool::paramsetlist $i $i]
      }
      for {set i 0} {$i<$::Paratool::natoms} {incr i} {
	 ::Paratool::set_atomprop VDWeps    $i {}
	 ::Paratool::set_atomprop VDWrmin   $i {}
	 ::Paratool::set_atomprop VDWeps14  $i {}
	 ::Paratool::set_atomprop VDWrmin14 $i {}
      }
      if {$::Paratool::molidbase<0} { return }
      ::Paratool::assign_vdw_params
      ::Paratool::atomedit_update_list nocomplexcheck
   }
   pack $w.para.list.buttons.add $w.para.list.buttons.delete -expand 1 -fill x
   pack $w.para.list.list  -side left  -fill x -expand 1
   pack $w.para.list.scroll $w.para.list.buttons -side left -fill y -expand 1
   pack $w.para.list -side top  -expand 1 -fill x

   frame $w.para.new
   label $w.para.new.label -text "New parameter file: "
   entry $w.para.new.entry -relief sunken -width 68 -justify left -state readonly \
      -textvariable ::Paratool::newparamfile
   button $w.para.new.button -text "Write" -command { ::Paratool::write_parameters }
   pack $w.para.new.label $w.para.new.entry $w.para.new.button -side left -anchor w
   pack $w.para.new -side bottom -anchor w -pady 1m

   pack $w.topo $w.amber $w.para -padx 1m -pady 1m -expand 1 -fill x



   bind $w <Control-i> {
      ::Paratool::edit_internal_coords
   }

   bind $w <Control-g> {
      ::Paratool::edit_gaussian_setup
   }

   bind $w <Control-a> {
      ::Paratool::edit_atom_properties
   }

   bind $w <Control-t> {
      ::Paratool::assign_unique_atomtypes
   }

   bind $w <Control-v> {
      ::Paratool::autoassign_vdw_params
   }

   bind $w <Control-n> {
      ::Paratool::Refinement::nonb_gui
   }

   bind $w <Control-d> {
      ::Paratool::component_finder
   }

   bind $w <Control-m> {
      ::Paratool::metal_complex_gui
   }

   bind $w <Control-h> {
      ::Paratool::Hessian::gui
   }

   bind $w <FocusIn> {
      if {"%W"==".paratool" && [winfo exists .paratool.mol.list.list]} {
	 set ::Paratool::pickmode none
      }
   }


   # If a metal complex was detected open the appropriate GUI window
   #variable tmcomplex
   #if {[llength $tmcomplex]} { after idle ::Paratool::metal_complex_gui }
}


proc ::Paratool::update_fragsel_entry_state { args } {
   if {$::Paratool::molidparent<=0} {
      .paratool.frag.size.entry configure -state disabled
   } else {
      .paratool.frag.size.entry configure -state normal
   }
}

################################################################
# Gets called whenever the frame of $molidbase is changed,     #
# i.e. switches between original and optimizd geometry.        #
################################################################

proc ::Paratool::update_frame { n id args } {
   #puts "Update frame: [molinfo top get frame]"

   # Update atom markers of selected atoms
   atomedit_draw_selatoms

   # Update internal coordinate atom labels
   #intcoor_draw_selatoms

   # Update the atom text labels
   update_atomlabels

   # Update internal coordinate atom and text labels
   update_intcoorlabels
}


#################################################################
# This changes the selection of the representation that belongs #
# to the parent molecule.                                       #
#################################################################

proc ::Paratool::update_fragment_selection {} {
   variable molidparent
   variable molidbase
   variable molnameparent
   variable molnamebase
   variable fragmentseltext 
   variable oldfragmentseltext 
   variable fragmentrepparent
   variable compid

#    if {$molidparent<0 && $molidbase>=0} {
#       set all [atomselect $molidbase "all"]     
#       write_xbgf [file rootname $molnamebase]_parent.xbgf $all
#       $all delete
#       load_parentmolecule [file rootname $molnamebase]_parent.xbgf
#    }

   if {$molidparent<0} { return }

   #variable oldfragmentseltext $fragmentseltext
   if {$molidparent>=0} {
      molinfo $molidparent set drawn 1
      set sel [atomselect $molidparent "$fragmentseltext"]
      if {![$sel num]} {
	 tk_messageBox -icon error -type ok -title Message -parent .paratool \
	    -message "Selection contains no atoms!"
	 return 0
      }
      if {$molidbase<0} {
	 $sel set type {{}}
	 write_xbgf [file rootname $molnameparent].xbgf $sel
	 load_basemolecule "[file rootname ${molnameparent}].xbgf"
	 if {$molidbase<0} { return 0 }
      }
      $sel delete
   }

   variable bondthickness
   if {![llength $compid]} {
      if {$molidparent>=0} {
	 # Hide previous representations
	 for {set rep 0} {$rep<[molinfo $molidparent get numreps]} {incr rep} {
	    mol showrep $molidparent $rep off
	 }
	 mol selection $fragmentseltext
	 mol representation "Bonds $bondthickness"
	 mol addrep $molidparent
	 variable fragmentrepparent [mol repname $molidparent [expr [molinfo $molidparent get numreps]-1]]
	 mol representation "VDW $bondthickness"
	 mol addrep $molidparent 
      }
      init_componentlist
   }

   # Write a molecule with the unparametrized fragment from $molidbase 
   set sel [atomselect $molidbase "$fragmentseltext"]

   # Only use new atoms for the new basemol
   if {$molidbase>=0} {
      puts "Using following atoms from current basemol for new basemol:"
      puts [$sel list]
      write_xbgf [file rootname $molnamebase].xbgf $sel
   }

   set addindexes {}
   set fragselparent {}
   set atomdefseltext "none"
   if {$molidparent>=0} {
      mol selection $fragmentseltext
      mol representation "Bonds $bondthickness"
      mol modrep [mol repindex $molidparent $fragmentrepparent] $molidparent
      mol representation "VDW $bondthickness"
      mol modrep [expr [mol repindex $molidparent $fragmentrepparent]+1] $molidparent

      # Select the new selection from the parent molecule 
      # excluding the unparametrized fragment because it contains no hydrogens
      # Then append it to the new file
      variable istmcomplex
      variable isironsulfur
      set fragselparent [atomselect $molidparent "($fragmentseltext)"]

      # Compare unique atom defs for parent with basemol
      # Make list of unique atom definitions
      set atomdeflist {}
      foreach atomdef [$sel get {name resid resname segid}] {
	 lappend atomdeflist $atomdef
	 append atomdefseltext " or (name \"[lindex $atomdef 0]\" and resid [lindex $atomdef 1] and segid [lindex $atomdef 3])"
      }

      foreach atomdef [$fragselparent get {name resid resname segid}] index [$fragselparent list] {
	 if {[lsearch $atomdeflist $atomdef]<0} {
	    lappend addindexes $index
	 }
      }
   }
   $sel delete

   # Determine bonds that span between the selections of parent and base molecule
   variable complexbondlist
   set parentsel1 [atomselect $molidparent "($fragmentseltext) and not ($atomdefseltext)"]
   set parentsel2 [atomselect $molidparent "($fragmentseltext) and ($atomdefseltext)"]
   foreach atombondlist [$parentsel1 getbonds] bolist [$parentsel1 getbondorders] atom [$parentsel1 get {segid resid name}] {
      foreach bond $atombondlist bo $bolist {
	 if {[lsearch [$parentsel2 list] $bond]>=0} {
	    set b [atomselect $molidparent "index $bond"]
	    #puts "EXTRABOND: {$atom}--[$b get {segid resid name}]; $bo"
	    set newbond [list $atom [join [$b get {segid resid name}]]]
	    if {[lsearch $complexbondlist "{$newbond} *"]<0 &&
		[lsearch $complexbondlist "{[lrevert $newbond]} *"]<0} {
	       if {$atom<$bond} {
		  lappend complexbondlist [list $newbond $bo]
	       } else {
		  lappend complexbondlist [list [lrevert $newbond] $bo]
	       }
	    }
	    $b delete
	 }
      }
   }
   set complexbondlist [lsort -unique $complexbondlist]
   $parentsel1 delete
   $parentsel2 delete

   if {$molidparent>=0 && [llength $addindexes]} {
      # Add selected atoms from parentmolecule to new basemol, 
      # the complex-ligand bonds are also added explicitely.
      set outsel [atomselect $molidparent "index $addindexes"]
      puts "Adding following atoms from parentmol to new basemol:"
      puts [$outsel list]
      variable complexbondlist

      # complexbondlist contains bonds that span between the selections of parent and base molecule
      puts "adding"
      add_selection_to_xbgf "[file rootname $molnamebase].xbgf" $outsel $complexbondlist;
      $fragselparent delete 
      $outsel delete
   }

   # Replace the current fragment molecule with the new one
   load_basemolecule "[file rootname ${molnamebase}].xbgf"; # "${basename}_hydrogen.psf"
}


##############################################################
# Resets the fragment selection by reloading a basemolecule  #
# containing all unparametrized atoms.                       #
##############################################################

proc ::Paratool::reset_selection {} {
   variable molidparent
   variable molnamebase
   variable istmcomplex 
   variable isironsulfur
   variable fragmentseltext "unparametrized"
   if {$istmcomplex || $isironsulfur} {
      variable fragmentseltext "(unparametrized or ligands)"
   }
   set sel [atomselect $molidparent "$fragmentseltext"]
   write_xbgf [file rootname $molnamebase].xbgf $sel
   $sel delete
   load_basemolecule "[file rootname ${molnamebase}].xbgf"
}


################################################
# These functions launch QMtools simulation    #
# setup window with some hopefully well chosen #
# defaults for the respective type of job.     #
################################################

proc ::Paratool::setup_geometry_opt {} {
   variable molidbase
   if {![llength $::QMtool::molidlist]} {
      #::QMtool::init_variables ::QMtool
      ::QMtool::qmtool -mol $molidbase -nogui; # -pdb [get_coorfilename $molidbase]
   } else {
      ::QMtool::use_vmd_molecule $molidbase
   }
   ::QMtool::set_simtype  "Geometry optimization"
   ::QMtool::set_basename "${::QMtool::basename}_opt"
   variable istmcomplex
   variable isironsulfur
   if {$istmcomplex || $isironsulfur} {
      # For metal containing structures we need an unrestricted method
      ::QMtool::set_method   "UB3LYP"
      ::QMtool::set_basisset "6-31G+*"
   } else {
      ::QMtool::set_method   "RHF"
      ::QMtool::set_basisset "6-31G*"
   }
   ::QMtool::set_otherkey "SCF=Tight"
   set ::QMtool::calcesp 0
   set ::QMtool::calcnpa 0
   ::QMtool::set_totalcharge  [expr round($::Paratool::totalcharge)]
   ::QMtool::set_multiplicity $::Paratool::multiplicity
   ::Paratool::alias_qmtool_atomnames
   #puts "::QMtool::atomproplist=$::QMtool::atomproplist"
   ::QMtool::setup_QM_simulation 
}

proc ::Paratool::setup_qm_potscan {} {
   variable molidbase
   variable molnamebase
   variable molidopt
   variable molnameopt
   if {$::Paratool::molidopt<0} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Please load a molecule with optimized geometry first!"
      return 0
   }
   if {![llength $::QMtool::molidlist]} {
      ::QMtool::qmtool -mol $molidbase -nogui; 
   } else {
      ::QMtool::use_vmd_molecule $molidbase
   }
   variable zmat
   variable selintcoorlist
   set tag ""
   foreach selintcoor $selintcoorlist {
      append tag "_"
      append tag [lindex $zmat [expr {$selintcoor+1}] 0]
   }
   variable qmscantype
   ::QMtool::set_basename "[regsub {_opt$} [file rootname $molnameopt] {}]_${qmscantype}scan${tag}"
   #::QMtool::set_simtype  "Geometry optimization"
   ::QMtool::set_simtype  "$qmscantype potential scan"
   ::QMtool::set_coordtype "Internal (explicit)"
   #::QMtool::set_coordtype "Internal (auto)"
   variable optmethod
   variable optbasisset
   ::QMtool::set_method   $optmethod
   ::QMtool::set_basisset $optbasisset
   set ::QMtool::calcesp 0
   set ::QMtool::calcnpa 0

   variable qmscanwidth
   variable qmscansteps
   # Store local copies of variables because they are overridden with defaults
   # in scan_coordinate->update_intcoorlist
   set scanwidth $qmscanwidth
   set scansteps $qmscansteps

   if {$qmscantype=="Rigid"} {
      # We are faking a rigid potential scan by setting the maximum number
      # of optimization cycles per scan step to 1. The advantage is that we 
      # can use the convenient ModRedundant input method for the internal coordinates.
      # Otherwise we would have to use the keyword Scan and construct a regular Z-matrix.
      set ::QMtool::optmaxcycles 1; # This assures a rigid potscan.
      # Add the S flag to the selected coordinates and F to the rest
      scan_coordinate -rigid
   }
   if {$qmscantype=="Relaxed"} {
      # Add the S flag to the selected coordinates
      scan_coordinate -relaxed
   }

   ::QMtool::set_totalcharge  [expr round($::Paratool::totalcharge)]
   ::QMtool::set_multiplicity $::Paratool::multiplicity
   variable chkfileopt
   ::QMtool::set_fromcheckfile $chkfileopt
   # Taking the geometry and wavefunction from checkfile wouldn't make sense here
   # because we change the geometry anyway and the SCF has to be run
   ::QMtool::set_geometry  "Z-matrix"
   ::QMtool::set_guess     "Take guess from checkpoint file"

   ::QMtool::set_internal_coordinates $::Paratool::zmat

   # Restore the values
   variable qmscanwidth $scanwidth
   variable qmscansteps $scansteps
   set ::QMtool::scanwidth $scanwidth
   set ::QMtool::scansteps $scansteps
   set ::QMtool::scanstepsize [expr {$scanwidth/double($scansteps)}]
   alias_qmtool_atomnames
   ::QMtool::setup_QM_simulation 
}

proc ::Paratool::setup_singlepoint_calc {} {
   variable molidopt
   variable molidbase
   variable molnameopt
   if {$molidopt<0} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Please load a molecule with optimized geometry first!"
      return 0
   }
   variable natoms
   variable ncoords
   #if {$ncoords<[expr 3*$natoms-6]} {
   #   tk_messageBox -icon error -type ok -title Message -parent .paratool \
   #	 -message "Must have at least 3*natoms-6=[expr 3*$natoms-6] coordinates.\nCurrently only $ncoords coordinates are defined."
   #   edit_internal_coords
   #   return 0
   #}

   if {![llength $::QMtool::molidlist]} {
      ::QMtool::qmtool -mol $molidopt -nogui;
   } else {
      ::QMtool::use_vmd_molecule $molidopt
   }
   ::QMtool::set_simtype  "Frequency"
   ::QMtool::set_basename  "[regsub {_opt$} [file rootname $molnameopt] {}]_sp"
   variable optmethod
   variable optbasisset
   if {[llength $optmethod] && [llength $optbasisset]} {
      ::QMtool::set_method   $optmethod
      ::QMtool::set_basisset $optbasisset
   } else {
      variable istmcomplex
      variable isironsulfur
      if {$istmcomplex || $isironsulfur} {
	 # For metal containing structures we need an unrestricted method
	 ::QMtool::set_method   "UB3LYP"
	 ::QMtool::set_basisset "6-31G+*"
      } else {
	 ::QMtool::set_method   "RHF"
	 ::QMtool::set_basisset "6-31G*"
      }
   }
   set ::QMtool::calcesp 1
   set ::QMtool::calcnpa 1
   ::QMtool::set_otherkey "SCF=Tight"
   ::QMtool::set_totalcharge [expr round($::Paratool::totalcharge)]
   ::QMtool::set_multiplicity $::Paratool::multiplicity
   variable chkfileopt
   ::QMtool::set_fromcheckfile $chkfileopt
   ::QMtool::set_geometry  "Checkpoint file"
   ::QMtool::set_guess     "Read geometry and wavefunction from checkfile"
   variable zmat
   if {[llength $zmat]>1} {
      ::QMtool::set_coordtype "Internal (explicit)"
      ::QMtool::set_internal_coordinates $zmat
   } else {
      ::QMtool::set_coordtype "Internal (auto)"
   }

   set lewischarges {}
   set sel [atomselect $molidbase all]
   foreach i [$sel list] {
      lappend lewischarges [get_atomprop Lewis $i]
   }
   $sel delete
   ::QMtool::set_lewischarges $lewischarges

   alias_qmtool_atomnames
   ::QMtool::setup_QM_simulation
}

proc ::Paratool::setup_coordinate_trans {} {
   variable hessian
   variable molidsip
   variable molnamesip
   if {$molidsip<0 && ![llength $hessian]} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "Please load a frequency calculation first!"
      return 0
   }
   variable natoms
   variable ncoords
   if {$ncoords<[expr 3*$natoms-6]} {
      tk_messageBox -icon error -type ok -title Message -parent .paratool \
	 -message "For cartesian-->internal coordinate transformations you must have at least 3*natoms-6=[expr 3*$natoms-6] coordinates.\nCurrently only $ncoords coordinates are defined. You can autogenerate them or specify them manually."
      edit_internal_coords
      return 0
   }

   if {![llength $::QMtool::molidlist]} {
      ::QMtool::qmtool -mol $molidsip -nogui;
   } else {
      ::QMtool::use_vmd_molecule $molidsip
   }
   set ::QMtool::simtype   "Coordinate transformation"
   set ::QMtool::basename  "[regsub {_sp$} [file rootname $molnamesip] {}]_transf"
   set ::QMtool::fromcheck "${::QMtool::basename}_freq.chk"
   set ::QMtool::coordtype "Internal (explicit)"
   variable optmethod
   variable optbasisset
   if {[llength $optmethod] && [llength $optbasisset]} {
      ::QMtool::set_method   $optmethod
      ::QMtool::set_basisset $optbasisset
   } else {
      variable istmcomplex
      variable isironsulfur
      if {$istmcomplex || $isironsulfur} {
	 # For metal containing structures we need an unrestricted method
	 ::QMtool::set_method   "UB3LYP"
	 ::QMtool::set_basisset "6-31G+*"
      } else {
	 ::QMtool::set_method   "RHF"
	 ::QMtool::set_basisset "6-31G*"
      }
   }
   set ::QMtool::calcesp 0
   set ::QMtool::calcnpa 0
   set ::QMtool::totalcharge  [expr round($::Paratool::totalcharge)]
   set ::QMtool::multiplicity $::Paratool::multiplicity
   set ::QMtool::zmat         $::Paratool::zmat
   variable chkfilefreq
   set ::QMtool::fromcheckfile $chkfilefreq
   set ::QMtool::geometry  "Checkpoint file"
   set ::QMtool::guess     "Read geometry and wavefunction from checkfile"
   ::QMtool::set_internal_coordinates $::Paratool::zmat
   alias_qmtool_atomnames
   ::QMtool::setup_QM_simulation 
}


############################################################
# This function is invoked whenever an atom is picked.     #
#                                                          #
# ATTENTION:                                               #
# Errors in this function are caught by VMD and will not   #
# be reported. Instead the functions returns at the point  #
# where the error occured.                                 #
############################################################


proc ::Paratool::atom_picked_fctn { args } {
   global vmd_pick_atom
   global vmd_pick_shift_state
   variable picklist
   variable addtype
   variable pickmode
   variable molidbase

   if {$vmd_pick_shift_state} { 
      # If a selected atom is picked then deselect it, 
      # otherwise add it to the picklist.
      set pos [lsearch $picklist $vmd_pick_atom]
      if {$pos>=0} {
	 set picklist [lreplace $picklist $pos $pos]
      } else {
	 lappend picklist $vmd_pick_atom
      }
   } else {
      set picklist $vmd_pick_atom
      label delete Atoms all
      variable selintcoorlist
      if {[winfo exists .paratool_intcoor.zmat.pick.list]} {
	 # Blank all item backgrounds
	 foreach i $selintcoorlist {
	    .paratool_intcoor.zmat.pick.list itemconfigure $i -background {}
	 }
	 set ::Paratool::selintcoorlist {}
	 .paratool_intcoor.zmat.pick.list selection clear 0 end
      }
   }

   #puts "pickmode=$pickmode; picked atom $vmd_pick_atom; $picklist"

   variable zmat
   if {[winfo exists .paratool_intcoor]} {
      if {[llength $picklist]==1} {
	 .paratool_intcoor.frame2.type.bond     configure -state disabled
	 .paratool_intcoor.frame2.type.vmdbond  configure -state disabled
	 .paratool_intcoor.frame2.type.addangle configure -state disabled
	 .paratool_intcoor.frame2.type.adddihed configure -state disabled
	 .paratool_intcoor.frame2.type.angle    configure -state disabled
	 .paratool_intcoor.frame2.type.dihed    configure -state disabled
	 .paratool_intcoor.frame2.type.imprp    configure -state disabled
      } elseif {[llength $picklist]==2} {
	 set addtype bond
	 # Check if the coordinate exists already
	 set pos [is_zmat_bond $picklist]
	 if {$pos>=0} {
	    # The coordinate exists, we select it
	    select_intcoor [expr $pos-1] noupdatepicklist
 	    .paratool_intcoor.zmat.pick.list selection clear 0 end
 	    .paratool_intcoor.zmat.pick.list selection set [expr $pos-1]
	    .paratool_intcoor.zmat.pick.list see [expr $pos-1]
	 }
	 .paratool_intcoor.frame2.type.bond     configure -state normal
	 .paratool_intcoor.frame2.type.vmdbond  configure -state normal
	 if {$::Paratool::genvmdbond} { 
	    .paratool_intcoor.frame2.type.addangle configure -state disabled
	    .paratool_intcoor.frame2.type.adddihed configure -state disabled
	 } else {
	    .paratool_intcoor.frame2.type.addangle configure -state normal
	    .paratool_intcoor.frame2.type.adddihed configure -state normal
	 }
	 .paratool_intcoor.frame2.type.angle    configure -state disabled
	 .paratool_intcoor.frame2.type.dihed    configure -state disabled
	 .paratool_intcoor.frame2.type.imprp    configure -state disabled
      } elseif {[llength $picklist]==3} {
	 set addtype angle
	 # Check if the coordinate exists already
	 set pos [is_zmat_angle $picklist]
	 if {$pos>=0} {
	    # The coordinate exists, we select it
	    select_intcoor [expr $pos-1] noupdatepicklist
	    .paratool_intcoor.zmat.pick.list selection clear 0 end
	    .paratool_intcoor.zmat.pick.list selection set [expr $pos-1]
	    .paratool_intcoor.zmat.pick.list see [expr $pos-1]
	 }
	 
	 .paratool_intcoor.frame2.type.bond     configure -state disabled
	 .paratool_intcoor.frame2.type.vmdbond  configure -state disabled
	 .paratool_intcoor.frame2.type.addangle configure -state disabled
	 .paratool_intcoor.frame2.type.adddihed configure -state disabled
	 .paratool_intcoor.frame2.type.angle    configure -state normal
	 .paratool_intcoor.frame2.type.dihed    configure -state disabled
	 .paratool_intcoor.frame2.type.imprp    configure -state disabled
      } elseif {[llength $picklist]==4} {
	 .paratool_intcoor.frame2.type.dihed    configure -state normal
	 .paratool_intcoor.frame2.type.imprp    configure -state normal

	 set chain [is_improper $picklist $molidbase]
	 if {[llength $chain]} {
	    set addtype imprp
	    .paratool_intcoor.frame2.type.dihed    configure -state disabled
	 } else {
	    set addtype dihed
	    .paratool_intcoor.frame2.type.imprp    configure -state disabled
	    set chain [is_chain $picklist $molidbase]
	 }

	 if {[llength $chain]} { 
	    # Check if the coordinate exists already
	    set pos [lsearch -regexp $zmat "\\s$addtype\\s\\{($chain|[lrevert $chain])\\}\\s"]
	    set picklist $chain

	    if {$pos>=0} {
	       # The coordinate exists, we select it
	       select_intcoor [expr $pos-1] noupdatepicklist
	       .paratool_intcoor.zmat.pick.list selection clear 0 end
	       .paratool_intcoor.zmat.pick.list selection set [expr $pos-1]
	       .paratool_intcoor.zmat.pick.list see [expr $pos-1]
	    }
	 }
	 
	 .paratool_intcoor.frame2.type.bond     configure -state disabled
	 .paratool_intcoor.frame2.type.vmdbond  configure -state disabled
	 .paratool_intcoor.frame2.type.addangle configure -state disabled
	 .paratool_intcoor.frame2.type.adddihed configure -state disabled
	 .paratool_intcoor.frame2.type.angle    configure -state disabled
      } 
   }
  
   # Select atoms in atomproplist and draw spheres
   select_atoms $picklist

   if {$pickmode=="chargegroup"} {
      if {[winfo exists .charmmcharge]} {
	 ::CHARMMcharge::select_chargegroup_atoms $picklist
      }
   } 
}


######################################################
### Get path file name for opening                 ###
######################################################

proc ::Paratool::opendialog { type {initialfile ""} } {
   variable workdir
   
   set types {}
   
   if {$type=="topo"} {
      set types {
	 {{CHARMM topology files}       {.top top*.inp}  }
	 {{All files}        *            }
      }
   } elseif {$type=="para"} {
      set types {
	 {{CHARMM parameter files}       {.par par*.inp}  }
	 {{All files}        *            }
      }
   } elseif {$type=="potscan"} {
      set types {
	 {{Gaussian logfiles}     {.log}  }
	 {{All files}        *            }
      }
   } elseif {$type=="loadproject" || $type=="saveproject"} {
      set types {
	 {{Paratool project files}  {.ptl}  }
	 {{All files}        *              }
      }
   } elseif {$type=="loadoptgeom" || $type=="loadsip" || $type=="loadtransf"} {
      set types {
	 {{Gaussian logfiles} {.log}   }
	 {{All Files}        *            }
      }
   } elseif {$type=="compdbpath"} {
      set types {
	 {{PDB Chemical Component Dictionary} {.cif} }
	 {{All Files}        *            }
      }
   } elseif {$type=="optwat" || $type=="optsyswat"} {
      set types {
	 {{Gaussian logfiles} {.log} }
	 {{All Files}        *       }
      }
   } elseif {$type=="loadparentmol" || $type=="loadbasemol" || $type=="syswat"} {
      set types {
	 {{PDB files} {.pdb}   }
	 {{XBGF files} {.xbgf} }
	 {{XYZ files} {.xyz}   }
	 {{All Files}  *       }
      }
   } elseif {$type=="savebasemol"} {
      set types {
	 {{XBGF files} {.xbgf}  }
	 {{All Files}  *       }
      }
   } elseif {$type=="writetopo"} {
      set types {
	 {{CHARMM topology files}    {.top top*.inp} }
	 {{All files}        *            }
      }
   } elseif {$type=="writepara"} {
      set types {
	 {{CHARMM parameter files}   {.par par*.inp} }
	 {{All files}        *            }
      }
   } elseif {$type=="writepsfgen"} {
      set types {
	 {{PSFgen input files}       {.pgn}  }
	 {{All files}        *            }
      }
   } elseif {$type=="rawhess"} {
      set types {
	 {{ASCII Data files}      {.dat}  }
	 {{All files}              *      }
      }
   } elseif {$type=="workdir"} {
      # Do nothing
   } else {
      error "::Paratool::opendialog: unknown type $type"
   }

   set newpathfile {}
   if {$type=="workdir"} {
      set workdir [tk_chooseDirectory -parent .paratool \
		  -initialdir "." -title "Choose working directory"] 
   } elseif {$type=="saveproject" || $type=="writetopo" || $type=="writepara" || $type=="writepsfgen" || \
		$type=="savebasemol"} {
      set newpathfile [tk_getSaveFile \
			  -title "Choose file name" -parent .paratool \
			  -initialdir $workdir -filetypes $types -initialfile $initialfile]
   } else {
      set newpathfile [tk_getOpenFile \
			  -title "Choose file name" -parent .paratool \
			  -initialdir $workdir -filetypes $types]
   }

   set file $newpathfile
   set dir [file normalize [file dirname $newpathfile]]
   set normwd [file normalize $workdir]
   if {$dir==$normwd && $workdir==[pwd]} {set file [file tail $newpathfile]}

   if {[string length $file] > 0} {
      if {$type=="int"}  {  
	 read_intcoords $file
      }
      if {$type=="loadproject"}  {  
	 load_project $file
      }
      if {$type=="saveproject"}  {  
	 save_project $file
      }
      if {$type=="savebasemol"} { 
	 variable molidbase
	 set all [atomselect $molidbase all]
	 write_xbgf $file $all
	 $all delete
      }
      if {$type=="topo"}  {  
	 variable topologylist
	 variable topologyfiles
	 lappend topologylist [::Toporead::read_charmm_topology $file]
	 lappend topologyfiles $file
      }
      if {$type=="para"}  {  
	 variable paramsetlist
	 variable paramsetfiles
	 lappend paramsetlist [::Pararead::read_charmm_parameters $file]
	 lappend paramsetfiles $file
      }
      if {$type=="loadparentmol"} { 
	 load_parentmolecule $file
      }
      if {$type=="loadbasemol"} { 
	 load_basemolecule $file
      }
      if {$type=="loadoptgeom"} { 
	 load_molecule OPT $file
      }
      if {$type=="loadsip" || $type=="loadtransf"} { 
	 load_molecule SIP $file
      }
      if {$type=="compdbpath"} { 
	 variable componentdbpath $file
      }
      if {$type=="optwat"} { 
	 ::CHARMMcharge::load_water $file
	 set ::CHARMMcharge::molnamewater $file
      }
      if {$type=="syswat"} { 
	 ::CHARMMcharge::load_syswat $file
	 set ::CHARMMcharge::molnamesyswat $file
      }
      if {$type=="optsyswat"} { 
	 ::CHARMMcharge::load_optsyswat $file
	 set ::CHARMMcharge::molnamesyswatopt $file
      }
      if {$type=="writetopo"} {
	 write_topology_file $file
      }
      if {$type=="writepara"} {
	 write_parameter_file $file
      }
      if {$type=="writepsfgen"} {
	 return $file
      }
      if {$type=="potscan"} {
	 load_molecule SCAN $file
      }
      if {$type=="rawhess"} {
	 read_raw_cartesian_hessian $file
      }
      return 1
   }
   return 0
}

##########################################################
# Switch between using CHARMM and AMBER topo/params.     #
##########################################################

proc ::Paratool::toggle_charmm_amber {} {
   # Delete all existing topologies
   .paratool.topo.list.list selection set 0 end
   .paratool.topo.list.buttons.delete invoke

   # Delete all existing topologies
   .paratool.para.list.list selection set 0 end
   .paratool.para.list.buttons.delete invoke
   
   variable topologyfiles
   variable paramsetfiles
   variable useamberparams
   global env
   if {!$useamberparams} {
      variable topologyfiles [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
      variable paramsetfiles [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]
   } else {
      variable topologyfiles [file join $env(CHARMMTOPDIR) top_amber2charmm.inp]
      variable paramsetfiles [file join $env(CHARMMPARDIR) par_amber2charmm.inp]
   }
   variable topologylist  [list [::Toporead::read_charmm_topology $topologyfiles]]
   variable paramsetlist  [list [::Pararead::read_charmm_parameters $paramsetfiles]]

   variable molidbase
   if {$molidbase<0} { return }

   ::Paratool::import_bondorders_from_topology $::Paratool::molidbase
   ::Paratool::assign_ForceF_charges
   ::Paratool::atomedit_update_list
   
   ::Paratool::assign_vdw_params
   ::Paratool::atomedit_update_list nocomplexcheck 
}


##########################################################
# Load the molecule that should be paramerized.          #
##########################################################

proc ::Paratool::load_parentmolecule { file {file2 {}}} {
   set newmolid [mol new $file]
   if {[llength $file2]} {
      mol addfile $file2
   }

   variable molidparent
   if {$newmolid>=0} {
      if {$molidparent>=0} { mol delete $molidparent }
      variable molidparent $newmolid
   } else {
      tk_messageBox -icon error -type ok -title Message \
	 -message "Could not load molecule $file"
      return 0
   }
   variable molnameparent [molinfo $newmolid get name]
   variable projectsaved 0

   puts "Parent molecule $molnameparent loaded."

   # If no psf file was loaded we have no realiable type info:
   if {[lsearch -regexp [molinfo $molidparent get filetype] "psf|xbgf"]<0} {
      set all [atomselect $molidparent all]
      $all set type {{}}
   }

   import_bondorders_from_topology $molidparent

   # Undraw all other molecules in VMD:
   foreach m [molinfo list] {
      if {$m==$newmolid}    { molinfo $m set drawn 1; continue }
      molinfo $m set drawn 0
   }

   # Set the representation to Bonds so that we can make use of the new bondorder feature
   mol selection all
   mol representation Lines
   mol modrep 0 $newmolid

   # Setup a trace on the existence of this molecule
   global vmd_initialize_structure
   trace add variable vmd_initialize_structure($newmolid) write ::Paratool::molecule_assert

   puts "before find"
   find_complex_centers $molidparent
   puts "after find"
}


#####################################################
### Remove all old traces:                        ###
#####################################################

proc ::Paratool::remove_traces {} {
   global vmd_pick_atom
   global vmd_frame
   global vmd_initialize_structure

   foreach t [trace info variable vmd_pick_atom] {
      trace remove variable vmd_pick_atom write ::Paratool::atom_picked_fctn
   }

   variable molidparent
   variable molidbase
   variable molidopt
   variable molidsip
   if {$molidbase>=0} {
      foreach t [trace info variable vmd_frame($molidbase)] {
	 trace remove variable vmd_frame($molidbase) write ::Paratool::update_frame
      }
   }

   variable ::CHARMMcharge::molidwater  
   variable ::CHARMMcharge::molidsyswat 
   foreach molid [list $molidparent $molidbase $molidopt $molidsip $molidwater $molidsyswat] {
      foreach t [trace info variable vmd_initialize_structure($molid)] {
	 trace remove variable vmd_initialize_structure($molid) write ::Paratool::molecule_assert
      }
   }

}

###################################################
# Clean up and reset the program.                 #
###################################################

proc ::Paratool::reset_all { {ask askuser} } {
   variable projectsaved

   if {$ask=="askuser" && !$projectsaved} {
      set reply [tk_dialog .foo "Reset - Save project" "Paratool has unsaved data. - Save project changes before complete reset?" \
		    question 0 "Save" "Don't save" "Cancel"]
      switch $reply {
	 0 { save_project $::Paratool::projectname }
	 1 { }
	 2 { return 0 }
      }
   }

   # Set mouse to rotation mode
   mouse mode 0
   mouse callback off; 

   # Close all children windows
   unmap_children

   # Delete the molecules
   remove_traces
   variable molidbase
   variable molidparent
   variable molidopt
   variable molidsip
   if {$molidparent>=0} { mol delete $molidparent }
   if {$molidbase>=0}   { mol delete $molidbase }
   if {$molidopt>=0}    { mol delete $molidopt }
   if {$molidsip>=0}    { mol delete $molidsip }
   if {$::CHARMMcharge::molidwater>=0}  { mol delete $::CHARMMcharge::molidwater }
   if {$::CHARMMcharge::molidsyswat>=0} { mol delete $::CHARMMcharge::molidsyswat }

   # Reinitialize child namespaces
   foreach ns [namespace children ::Paratool::] {
      #namespace delete $ns
      namespace eval $ns { initialize }
      puts "Initializing namespace $ns"
   }

   # Forget everything:
   initialize
   ::CHARMMcharge::initialize

   # Reinitialize some filenames
   variable workdir  "[pwd]";
   global env
   variable topologyfiles [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
   variable topologylist  [list [::Toporead::read_charmm_topology $topologyfiles]]
   variable paramsetfiles [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]
   variable paramsetlist  [list [::Pararead::read_charmm_parameters $paramsetfiles]]
}


#############################################
# Close all children windows.               #
#############################################

proc ::Paratool::unmap_children {} {
   if { [winfo exists .paratool_intcoor] }      { wm withdraw .paratool_intcoor }
   if { [winfo exists .paratool_chooseanalog] } { wm withdraw .paratool_chooseanalog }
   if { [winfo exists .paratool_choosetype] }   { wm withdraw .paratool_choosetype }
   if { [winfo exists .charmmcharge] }          { destroy .charmmcharge; destroy .charmmcharge_balance }
   if { [winfo exists .paratool_metal] }        { wm withdraw .paratool_metal }
   if { [winfo exists .paratool_atomedit] }     { wm withdraw .paratool_atomedit }
   if { [winfo exists .components] }            { wm withdraw .components }
}


###################################################################
# Start molefacture with the base molecule.                       #
###################################################################

proc ::Paratool::molefacture_start { {msel {}} } {
   variable molidbase
   if {$molidbase<0} { 
      tk_messageBox -icon error -type ok -title Message \
	 -message "Please load a basis molecule first!"
      return 0
   }
   if {![llength $msel]} {
      set msel [atomselect $molidbase "all"]
      ::Molefacture::molefacture_gui $msel
      $msel delete
   } else {
      ::Molefacture::molefacture_gui $msel
   }

   #puts "parent=$molidparent base=$molidbase msel=[$msel text] num=[$msel num] names=[$msel get {name atomicnumber}]"

   variable molnamebase
   set filename "[regsub {_hydrogen|_molef} [file rootname ${molnamebase}] {}]_molef.xbgf"
   ::Molefacture::set_slavemode ::Paratool::molefacture_callback $filename
}


###################################################################
# function to be called when editing in molefacture is finished.  #
###################################################################

proc ::Paratool::molefacture_callback { filename } {
   puts "Molefacture_callback $filename"
   load_basemolecule $filename

   variable molidbase
   set all   [atomselect $molidbase "all"]

   set hydro [atomselect $molidbase "beta 0.8"]
#   $all   set beta 0.0
#   $hydro set beta 0.5
   $all delete
   $hydro delete

   if {[winfo exists .paratool_atomedit]} {
      set_pickmode_atomedit
   }
}


##################################################
# Callback function for VMD's extension menu.    #
##################################################

proc paratool_tk_cb {} {
   ::Paratool::paratool_gui
   return $::Paratool::w
}

source [file join $env(PARATOOLDIR) paratool_atomedit.tcl]
source [file join $env(PARATOOLDIR) paratool_aux.tcl]
source [file join $env(PARATOOLDIR) paratool_respcharges.tcl]
source [file join $env(PARATOOLDIR) paratool_charmmcharges.tcl]
source [file join $env(PARATOOLDIR) paratool_intcoor.tcl]
source [file join $env(PARATOOLDIR) paratool_lists.tcl]
source [file join $env(PARATOOLDIR) paratool_readwrite.tcl]
source [file join $env(PARATOOLDIR) paratool_tmcomplex.tcl]
source [file join $env(PARATOOLDIR) paratool_components.tcl]
source [file join $env(PARATOOLDIR) paratool_topology.tcl]
source [file join $env(PARATOOLDIR) paratool_parameters.tcl]
source [file join $env(PARATOOLDIR) paratool_potscan.tcl]
source [file join $env(PARATOOLDIR) paratool_energies.tcl]
source [file join $env(PARATOOLDIR) paratool_refinement.tcl]
#source [file join $env(PARATOOLDIR) paratool_numerics.tcl]
source [file join $env(PARATOOLDIR) paratool_hessian.tcl]
