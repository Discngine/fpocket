##
## Automatic PSF Builder Plugin
##
## Authors: Peter Freddolino, John Stone, Jan Saam, Joao Ribeiro
##          vmd@ks.uiuc.edu
##
##           
## $Id: autopsf.tcl,v 1.142 2016/09/21 18:19:02 jribeiro Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/autopsf
##
##
## TODO:
##   - Allow the window to be maximized/minimized, allow more than 4-5 lines
##     in the chain list area at once.
##   - Edit more than one chain at a time.
##   - Add an option to see both the fragment and chain name for every part.
##
package require readcharmmtop
package require psfgen
package require solvate
package require autoionize
package require paratool
package require psfcheck
package require topotools
package provide autopsf 1.6


namespace eval ::autopsf:: {
  namespace export autopsf
  
  #define package variables
  variable basename   "autopsf";  # default output prefix
  variable patchlist  {};         # List of user defined patches
  variable ssbondlist {};         # List of distance based S-S bonds
  variable glycanbondlist {};     # List of distance based glycosidic bonds
  variable extrabonds {};         # List of bonds from CONECT 
  variable mutatehis  {};         # List protonation types for metal bound histidines
  variable mutatelist {};         # List of user defined mutations qwikmd
  variable cysironbondlist {};    # List of cysteine-iron bonds
  variable chaintoseg {};         # pairlist that matches chain identifiers with segids
  variable segtoseg {};           # pairlist that matches input segment identifiers with segids
  variable hetnamlist {};         # List of long names for hetero compounds from orig. PDB
  variable zerocoord  {};         # List of atoms located at the origin.
  variable oseltext   "protein or nucleic or glycan";         # User provided selection text. This part will be built by psfgen. 
  variable regenall 1;        # If true, we'll run regenerate angles dihedrals
  variable casesen 1; # if true, we make psfgen case sensitive
  variable nofailedguess false;
  variable frags    "all";
  variable allfrag  true;
  variable pfrag    false;
  variable ofrag    false;
  variable nfrag    false;
  variable water    false;
  variable ionize   false;
  variable qwikmd false; # If true, use qwikmd macro selection fro protein, nucleic and glycan
  variable nuctype RNA ;
  variable guess    true;
  variable autoterm true;        # Automatically apply terminal patches.
  variable useParatool   true;   # This flag is for debugging only.
  variable nullMolString "none"; # When no molecule is loaded use this string in the GUI option menu
  variable currentMol    "none"; # molid of the currently selected molecule
  variable tmpmolid      -1;     # molid of the molecule built by psfgen
  variable paratoolownedmol {};  # If this contains $tmpmolid then its ownership has changed to Paratool
  variable topfiles      {};     # List of user specified topology files
  variable patched    false;   	# If we're re-running psfgen after finding unparameterized residues,
				# we don't want to re-apply the automatically generated disulfide and 
				# glycan patches, or we'll end up with duplicate parameters that will crash
				# simulations.
  variable incomplete 1
  variable chaintexts
  set chaintexts [list]
  variable nters
  variable chainformat "%-4s %6i %6i-%6i %4s %4s %5s" 
  set nters [list]
  variable cters 
  set cters [list]
  variable chainstarts [list]
  variable chainends [list]
  variable chainlengths
  variable chainreps [list]
  variable selforchain
  variable newchain_type 3
  variable newchain_type_text
  trace add variable newchain_type write ::autopsf::update_newchain_text
  trace add variable frags write ::autopsf::update_fragtypes
  variable guistep 0
  variable splitonly false
  #are we using charmm36 topology files? (Important for NA)
  variable charmm36 0 
  
  # track log file name so we can close and reopen it as necessary
  variable logfilename {}
  
  # keep track of the temporary molecule loaded into VMD so we can delete it when done
  variable tempMol {}
  
  # GUI related stuff
  variable gui
  variable w
  variable selectcolor lightsteelblue; # Background color selected listbox elements

  # Index of the currently highlighted vdw rep
  variable vdwrepindex 
  set vdwrepindex -1

  trace add variable [namespace current]::currentMol write ::autopsf::molmenuaux 
  set pfrag 0
  set allfrag 0
  set nfrag 0
  set ofrag 0
  set osel ""
  set nuctype "RNA"
}

proc autopsf { args }     { return [eval ::autopsf::autopsf $args] }
proc autopsfgui { args }  { return [eval ::autopsf::autopsf -gui $args] }

proc ::autopsf::autopsf_usage { } {	 
  puts "Usage: autopsf -mol <molnumber> <option1> <option2>..."	 
  puts "Options:"	 
  puts "  Switches:"	 
  puts "    -protein (only generate psf for protein)"	 
  puts "    -nucleic (only generate psf for nucleic acid segment)"	 
  puts "    -solvate (run solvate on structure after psf generation)"	 
  puts "    -ionize (run autoionize on structure after psf generation)"	 
  puts "    -noguess (don't use guesscoord during psf building)"	 
  puts "    -noterm (don't automatically add terminii to proteins)"	 
  puts "    -rotinc <increment> (degree increment for rotation)"	 
  puts "    -gui (force graphical interface mode)"	 
  puts "    -regen (regenerate angles/dihedrals)"
  puts "    -splitonly (split chains, but don't build structure)"
  puts "  Single option arguments:"	 
  puts "    -mol <molecule> (REQUIRED: Run on molid <molecule>)"	 
  puts "    -prefix <prefix> (Use <prefix> as the prefix to output files)"	 
  puts "    -top <top> (Use topology file <top>)"	 
  puts "    -include <selection> (Include fragment specified by <selection> in psf generation"	 
  puts "    -patch <patch> (Apply a patch -- see docs for syntax)"
  error ""	 
}

#####################################################
# This funtion is called when the user chooses      #
# autopsf from VMD's extension menu.                #
#####################################################

proc autopsf_tk_cb {} {
  ::autopsf::autopsf -gui
  return $::autopsf::w
}


proc ::autopsf::autopsf { args } {
  variable allfrag true
  variable pfrag   false
  variable nfrag   false
  variable ofrag   false
  variable water   false
  variable ionize  false
  variable gui     false
  variable regenall 1
  variable guess   true
  variable autoterm true
  variable splitonly false
  variable oseltext
  variable basename
  variable topfiles
  variable currentMol top
  variable incomplete 1
  variable nofailedguess false;
  variable patchlist  [list];
  variable mutatelist [list];
  variable qwikmd false;
  set numargs [llength $args]	 
  if {$numargs == 0} {autopsf_usage}

  puts "Welcome to AUTOPSF!"
  puts "The automatic structure builder."

  # Setup the autopsf-provided topology file.
  init_default_topology

  set argnum 0
  set arglist $args
  #Parse switches
  foreach i $args {
    if {$i == "-protein"} {
      set pfrag true; set allfrag false
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-regen"} {
      set regenall 1
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-nucleic"} {
      set nfrag true; set allfrag false
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-solvate"} {
      set water true
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-ionize"}  {
      set ionize true
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-splitonly"}  {
      set splitonly true
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-noguess"}     {
      set guess false
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-noterm"}     {
      set autoterm false
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-nofailedguess"}     {
      puts "autopsf) Warning: ignoring unimplemented option -nofailedguess"
      #set nofailedguess true
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-gui"}     {
      set gui true
      set arglist [lreplace $arglist $argnum $argnum]
      continue
    }
    if {$i == "-qwikmd"} {
      set qwikmd true
      set oseltext "qwikmd_protein or qwikmd_nucleic or qwikmd_glycan or qwikmd_lipid"
      continue
    }
    incr argnum
  }

  #Parse single option variables
  #False if we've set a non-default topology file
  set otherarglist {}
  foreach {i j} $arglist {
    if {$i=="-prefix"}  then { set basename $j; continue  }
    if {$i=="-patch"}   then {
	    set patchlist $j;
      continue
    }
    if {$i=="-mutate"} {
      set mutatelist $j;
      continue
    }
    if {$i=="-top"}     then { 
      set topfiles [list]
      foreach file $j {
	  lappend topfiles $file;
      }
      continue
    }
    if {$i=="-include"} then { set ofrag true; set allfrag false; set oseltext $j; continue }
    if {$i=="-mol"} then {set currentMol $j}
    lappend otherarglist $i $j
  }

  if {$gui} {
    autopsf_gui
  } else {
    # We are running in batch mode
    return [psfmain]
  }
}


proc ::autopsf::init_default_topology {} {
  global env
  variable topfiles
  variable casesen
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all36_prot.rtf]
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all36_lipid.rtf]
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all36_na.rtf]
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all36_carb.rtf]
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all36_cgenff.rtf]
  lappend topfiles [file join $env(CHARMMTOPDIR) toppar_all36_carb_glycopeptide.str]
  lappend topfiles [file join $env(CHARMMTOPDIR) toppar_water_ions_namd.str]
  psfcontext new delete
  if $casesen {
    psfcontext mixedcase
  }
}


proc ::autopsf::autopsf_gui {} {
  variable w
  variable selectcolor
  variable gui true
  variable chaintexts
  variable casesen
  

  if { [winfo exists .autopsf] } {
    wm deiconify $w
    return
  }

  set w [toplevel ".autopsf"]
  wm title $w "AutoPSF"
  wm resizable $w no no 
  set row 0

  #wm protocol .autopsf WM_DELETE_WINDOW { ::autopsf::quit }

  #Add a menubar
  frame $w.menubar -relief raised -bd 2
  grid  $w.menubar -padx 1 -column 0 -columnspan 4 -row $row -sticky ew
  menubutton $w.menubar.options -text "Options" -underline 0 \
    -menu $w.menubar.options.menu
  menubutton $w.menubar.help -text "Help" -underline 0 \
    -menu $w.menubar.help.menu
  # XXX - set menubutton width to avoid truncation in OS X
  $w.menubar.options config -width 8
  $w.menubar.help config -width 5
  pack $w.menubar.options -side left
  pack $w.menubar.help -side right

  
  # Main options menu
  menu $w.menubar.options.menu -tearoff no
  $w.menubar.options.menu add radiobutton -label "Psfgen options" -indicatoron false -font {-weight bold}
  $w.menubar.options.menu add checkbutton -label "Regenerate angles/dihedrals"   -variable [namespace current]::regenall
  $w.menubar.options.menu add checkbutton -label "Preserve UPPER/lower case"   -variable [namespace current]::casesen
  $w.menubar.options.menu add separator
  $w.menubar.options.menu add radiobutton -label "Post-psfgen options" -indicatoron false -font {-weight bold}
  $w.menubar.options.menu add checkbutton -label "Add solvation box" -variable [namespace current]::water
  $w.menubar.options.menu add checkbutton -label "Add neutralizing ions"  -variable [namespace current]::ionize

  ## help menu
  menu $w.menubar.help.menu -tearoff no
  $w.menubar.help.menu add command -label "About" \
    -command {tk_messageBox -type ok -title "About AutoPSF" \
	      -message "Automatic structure building tool."}
  $w.menubar.help.menu add command -label "Help..." \
    -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/autopsf"
  incr row

  # Input information
  grid [labelframe $w.input -bd 2 -relief ridge -text "Step 1: Input and Output Files" -padx 1m -pady 1m] -row $row -column 0 -columnspan 4 -sticky nsew
incr row

  #Select a current molecule
  frame $w.input.basics
  label $w.input.basics.mollable -text "Molecule: "
  menubutton $w.input.basics.mol -height 1 -width 14 -textvar [namespace current]::molMenuText -menu $w.input.basics.mol.menu -relief raised
  menu $w.input.basics.mol.menu -tearoff no
  pack $w.input.basics.mollable $w.input.basics.mol -expand 1 -fill x -side left
  
  label $w.input.basics.fplabel -text "Output basename: "
  entry $w.input.basics.prefix  -textvariable [namespace current]::basename
#  pack $w.input.fplabel  -side top
  pack $w.input.basics.fplabel $w.input.basics.prefix -side left

  pack $w.input.basics 

  labelframe $w.input.topo -bd 2 -relief ridge -text "Topology files" -padx 1m -pady 1m
  frame $w.input.topo.list
  scrollbar $w.input.topo.list.scroll -command "$w.input.topo.list.list yview"
  listbox $w.input.topo.list.list -activestyle dotbox -yscroll "$w.input.topo.list.scroll set" -font {tkFixed 9} \
      -width 55 -height 2 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable [namespace current]::topfiles
  frame $w.input.topo.list.buttons
  button $w.input.topo.list.buttons.add -text "Add" -command [namespace code {
      set toptypes {
      {{CHARMM Topology Files} {.top .inp .rtf}}
	{{All Files} {*}}
      }
      set temploc [tk_getOpenFile -filetypes $toptypes]
	if {$temploc!=""} {lappend topfiles $temploc}
  }]
  button $w.input.topo.list.buttons.delete -text "Delete" -command [namespace code {
      foreach i [.autopsf.input.topo.list.list curselection] {
	.autopsf.input.topo.list.list delete $i
      }
      psfcontext new delete
      if $casesen {
	psfcontext mixedcase
      }
  }]
  pack $w.input.topo.list.buttons.add $w.input.topo.list.buttons.delete -expand 1 -fill x -side top
  pack $w.input.topo.list.list $w.input.topo.list.scroll -side left -fill y -expand 1
  pack $w.input.topo.list.buttons -side left
  pack $w.input.topo.list 
  button $w.input.next -text "Load input files" -command [namespace current]::afterinput_gui  
  pack $w.input.topo
  pack $w.input.next -fill x

  grid [labelframe $w.sels -relief ridge -text "Step 2: Selections to include in PSF/PDB" -padx 1m -pady 1m] -row $row -column 0 -columnspan 4 -sticky nsew
  set irow 0
  grid [radiobutton $w.sels.allfrag -text "Everything" -width 9 -variable [namespace current]::frags -value "all"] -row $irow -column 0 -sticky ew
  grid [radiobutton $w.sels.pfrag -text "Protein" -width 9 -variable [namespace current]::frags -value "psel"] -row $irow -column 1 -sticky w
  grid [radiobutton $w.sels.nfrag -text "Nucleic Acid" -width 13 -variable [namespace current]::frags -value "nsel"] -row $irow -column 2 -sticky w
#  grid [radiobutton $w.sels.rna -text "RNA" -width 5 -value "RNA" -variable [namespace current]::nuctype] -row $irow -column 2 -sticky ew
#  grid [radiobutton $w.sels.dna -text "DNA" -width 5 -value "DNA" -variable [namespace current]::nuctype] -row $irow -column 3 -sticky ew 
incr irow


  grid [radiobutton $w.sels.other -text "Other:" -width 13 -variable [namespace current]::frags -value "osel"] -row $irow -column 0 -sticky w
  grid [entry $w.sels.osel -textvariable [namespace current]::oseltext] -row $irow -column 1 -columnspan 2 -sticky ew
  incr irow
  grid [button $w.sels.next -text "Guess and split chains using current selections" -command [namespace current]::aftersels_gui] -column 0 -columnspan 4 -sticky ew
  incr row

#Frame for inspecting chains
  variable formattext " Name Length  Index  Range Nter Cter Type" 
  grid [labelframe $w.chains -bd 2 -relief ridge -text "Step 3: Segments Identified" -padx 1m -pady 1m] -row $row -column 0 -columnspan 4 -sticky nsew
  label $w.chains.label -font {tkFixed 9} -textvariable [namespace current]::formattext -relief flat -justify left
  frame $w.chains.list
  scrollbar $w.chains.list.scroll -command "$w.chains.list.list yview"
  listbox $w.chains.list.list -activestyle dotbox -yscroll "$w.chains.list.scroll set" -font {tkFixed 9} \
      -width 45 -height 4 -setgrid 1 -selectmode extended -selectbackground $selectcolor \
      -listvariable [namespace current]::chaintexts
  pack $w.chains.label -side top -anchor w
  pack $w.chains.list.list $w.chains.list.scroll -side left -fill y -expand 1
  frame $w.chains.edits
  button $w.chains.edits.add -text "Add a new chain" -command [namespace current]::addchain_gui 
  button $w.chains.edits.edit -text "Edit chain" -command [namespace current]::editchain_gui 
  button $w.chains.edits.del -text "Delete chain" -command [namespace current]::delchain_gui 
  button $w.chains.finish -text "Create chains" -command [namespace current]::afterchains_gui 
  pack $w.chains.edits.add $w.chains.edits.edit $w.chains.edits.del -side top -fill x -expand 1
  pack $w.chains.finish -side bottom -fill x
  pack $w.chains.edits -side right -anchor n -expand 1
  pack $w.chains.list -side left
  incr row

#Frame for patches
  variable patchformattext " Patch  Segid:Resid  Segid:Resid"
  grid [labelframe $w.patches -bd 2 -relief ridge -text "Step 4: Patches" -padx 1m -pady 1m] -row $row -column 0 -columnspan 4 -sticky nsew
  label $w.patches.label -font {tkFixed 9} -textvar [namespace current]::patchformattext -relief flat -justify left
  frame $w.patches.list
  scrollbar $w.patches.list.scroll -command "$w.patches.list.list yview"
  listbox $w.patches.list.list -activestyle dotbox -yscroll "$w.patches.list.scroll set" -font {tkFixed 9} -width 45 -height 4 -setgrid 1 -selectmode extended -selectbackground $selectcolor -listvariable [namespace current]::patchtexts
  pack $w.patches.label -side top -anchor w
  pack $w.patches.list.list $w.patches.list.scroll -side left -fill y -expand 1
  frame $w.patches.edits
  button $w.patches.edits.add -text "Add patch" -command [namespace current]::addpatch_gui 
  button $w.patches.edits.del -text "Delete patch" -command [namespace current]::delpatch_gui 
  button $w.patches.finish -text "Apply patches and finish PSF/PDB" -command [namespace current]::makepatches_gui 
  pack $w.patches.edits.add $w.patches.edits.del -side top -fill x -expand 1
  pack $w.patches.finish -side bottom -fill x
  pack $w.patches.edits -side right -anchor n -fill x -expand 1
  pack $w.patches.list -side left
  incr row

  grid [button $w.resetbutton -text "Reset Autopsf" -command [namespace current]::reset_gui]  \
  -row $row -column 0 -columnspan 2 -sticky nsew -padx 1m
#  grid [button $w.cleanbutton -text "Delete temp files" -command [namespace current]::clean_tempfiles]  \
#  -row $row -column 2 -columnspan 2 -sticky nsew -padx 1m
#  incr row
  grid [button $w.gobutton -text "I'm feeling lucky" -command [namespace current]::runpsfgen]  \
  -row $row -column 2 -columnspan 4 -sticky nsew -padx 1m


  fill_mol_menu $w.input.basics.mol.menu
  trace add variable ::vmd_initialize_structure write ::autopsf::vmd_init_struct_trace

  # Get long names for hetero compounds
  variable currentMol
  if {$currentMol!="none"} {
      variable hetnamlist [get_pdb_hetnam $currentMol]
  }

  #Set up a way to highlight the currently selected chain
  bind $w.chains.list.list <<ListboxSelect>> [namespace code {
      variable currentMol
      variable curselection
      variable vdwrepindex
      variable chainstarts
      variable chainends

      if {$vdwrepindex == -1} {
      # Add a rep, and find the rep number of our newly added rep
	set vdwrepindex 0
	while  { ! [catch {mol repname $currentMol} ] } {
	  incr vdwrepindex
	}
	incr vdwrepindex
	mol addrep $currentMol
      }

      mol modstyle $vdwrepindex $currentMol {VDW 1.0}

      set curselection [%W curselection]
      set chainstart [lindex $chainstarts $curselection]
      set chainend [lindex $chainends $curselection]
      mol modselect $vdwrepindex $currentMol "index [expr $chainstart - 1] to [expr $chainend - 1]"

  }]

  #disable_sels
  #disable_chains
  #enable_input
  set gui true
}

################################################
# Accessory proc for the trace on currentMol.  #
# Gets called whenever a molecule is selected. #
################################################

proc ::autopsf::molmenuaux {mol index op} {
  variable currentMol
  variable molMenuText
  if { ! [catch { molinfo $currentMol get name } name ] } {
    set molMenuText "$currentMol: $name"
    set pos [string last "_autopsf" [file rootname $name]]
    if {$pos>=0} {
	set name [string range $name 0 [expr $pos-1]]
    }
    variable basename "[file rootname $name]_autopsf"
  } else { 
    set molMenuText "$currentMol"
    if {$molMenuText=="none"} {
	variable basename "" 
    } else {
	variable basename "molecule${currentMol}_autopsf"
    }
  }
}


#########################################################
# Proc to get all the current molecules for a menu.     #
# For now, shamelessly ripped off from the PME plugin.  #
#########################################################

proc ::autopsf::fill_mol_menu {name} {
  variable currentMol
  variable nullMolString
  $name delete 0 end

  set molList {}
  foreach mm [array names ::vmd_initialize_structure] {
    if { $::vmd_initialize_structure($mm) != 0} {
      lappend molList $mm
      $name add radiobutton -variable [namespace current]::currentMol \
      -value $mm -label "$mm [molinfo $mm get name]" \
	-command [namespace code {
	    # If user changes current molecule then update long names for hetero compounds
	    variable currentMol
	    variable hetnamlist [get_pdb_hetnam $currentMol]
	}]
    }
  }

  #set if any non-Graphics molecule is loaded
  if {[lsearch -exact $molList $currentMol] == -1} {
    if {[lsearch -exact $molList [molinfo top]] != -1} {
      set currentMol [molinfo top]
    } else { set currentMol $nullMolString }
  }
}


##################################################
# Accessory proc for traces on the mol menu.     #
##################################################

proc ::autopsf::vmd_init_struct_trace {structure index op} {
  variable w
  puts "Autopsf: Updating structures"
  fill_mol_menu $w.input.basics.mol.menu
}

proc ::autopsf::afterinput_gui {} {
  variable pfrag
  variable nfrag
  variable allfrag
  variable ofrag
  variable osel
  variable currentMol
  variable guistep

  if {$guistep != 0} {
    tk_messageBox -icon error -type ok -title Error -parent .autopsf -message "You've already specified and analyzed the input molecule. If you want to work on a different molecule, click Reset AutoPSF to start over."
  }
  puts "WORKING ON: $currentMol"
  if {$currentMol=="none"} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf \
	-message "No molecule loaded!"
      return 0
  }

  variable topfiles
  if {![llength $topfiles]} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf \
	-message "No topology file specified!"
      return 0
  }
  
  # We overwrite the previous tmp molecule
  variable tmpmolid
  if {$tmpmolid>0} { mol delete $tmpmolid ; set tmpmolid -1 }
  #disable_input 
  #enable_sels
  set guistep 1
  set pfrag 0
  set allfrag 1
  set frags all
  set nfrag 0
  set ofrag 0
  set osel "protein or nucleic"
  set nuctype "RNA"
}

proc ::autopsf::reset_gui {} {
  global env
  variable ssbondlist
  set ssbondlist [list]
  variable glycanbondlist
  set glycanbondlist [list]
  variable extrabonds
  set extrabonds [list]
  variable mutatehis
  set mutatehis [list]
  variable mutatelist
  set mutatelist [list]
  variable cysironbondlist 
  set cysironbondlist [list]
  variable chaintoseg 
  set chaintoseg [list]
  variable segtoseg
  set segtoseg [list]
  variable oseltext "protein or nucleic"
  variable regenall 1
  variable nofailedguess false
  variable ionize false
  variable guess true
  variable autoterm true
  variable incomplete 1
  variable water false

  variable topfiles
  variable patchlist
  variable frags
  set patchlist [list]
  set topfiles [list]
  init_default_topology
  variable pfrag
  variable nfrag
  variable allfrag
  variable ofrag
  variable osel
  variable nuctype
  variable chaintexts
  set chaintexts [list]
  variable chainnames
  set chainnames [list]
  variable patchtexts
  set patchtexts [list]
  variable chainsellist [list]
  variable chainstarts [list]
  variable chainends [list]
  variable nters [list]
  variable cters [list]
  variable chainnames [list]
  variable chainlengths [list]
  #Chaintypes is 1 for nucleic acid chains, 0 for others
  variable chaintypes [list]
  set frags "all"
  set pfrag 0
  set allfrag 1
  set nfrag 0
  set ofrag 0
  set osel ""
  set nuctype "RNA"
  variable guistep
  resetpsf_autopsf
  #disable_sels
  #enable_input
  #disable_chains
  set guistep 0
  variable currentMol
  variable vdwrepindex
  if {$vdwrepindex != -1} {mol delrep $vdwrepindex $currentMol}
  set vdwrepindex -1
  
}

proc ::autopsf::aftersels_gui {} {
  variable allfrag
  variable pfrag
  variable nfrag
  variable ofrag
  variable oseltext
  variable currentMol
  variable nuctype
  variable guistep


  if {$guistep == 0} {
    tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "You have not yet finished specifying the input molecules. If you are done with them, click \"Load input files\" in the Input and Output Files frame."
    return
  }
#   if {$guistep == 2} {
#     tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "You have already specified the selections for this molecule. If you want to change them, click \"Reset AutoPSF\" to start over."
#   }

  if {!($allfrag || $ofrag || $nfrag || $pfrag)} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "WARNING: No fragments selected! You need to select at least some portions of the molecule to include in the psf and pdb"
      return
  }


  if {$nuctype == "DNA"} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "Warning: AutoPSF cannot yet create DNA, although this is planned for a future version. For now, you will need to use psfgen manually to create DNA. RNA can be made normally."
      return
  }
  #if {$pfrag || $nfrag} {set allfrag false}
  #if {$oseltext != ""} {
  #   set ofrag true
  #   set allfrag false
  #}

  # Delete all previous segments from the structure but keep topogy and aliases
  resetpsf_autopsf

  puts "WORKING ON: $currentMol"
  preformat_pdb $currentMol
  
  if {[write_selection_tempfiles $currentMol] != 0} { return 2 }

  # Run psfcheck on the molecule to generate a temporary topology file
  # containing entries for unknown RESIs. It will be needed to build a
  # structure with psfgen since psfgen would choke on unknown residue names.
  if {[checktop] != 0} { return 2 }

  variable basename
  variable currentMol
  variable ssbondlist
  variable glycanbondlist
  variable chaintoseg
  variable segtoseg
  variable splitsegfiles [split_protein_and_water_pdb "${basename}-temp.pdb"]
  #disable_sels
  #enable_chains
#   set guistep 2
}

proc autopsf::afterchains_gui {} {
  variable basename
  variable chainnames
  variable chaintoseg
  variable segtoseg
  variable patchlist
  variable logfileout
  variable logfilename
#   variable guistep
  if {![info exists chainnames] || [llength $chainnames] == 0} {
    tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "Your molecule needs to have at least one chain to create a psf and pdb. Please either use the Guess Chains button or add a chain manually."
    return
  }
#   if {$guistep == 0} {
#     tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "You have not yet finished specifying the input molecules. If you are done with them, click \"Continue to Next Step\" in the Input and Output Files frame."
#   }
#   if {$guistep == 1} {
#     tk_messageBox -icon error -type ok -title Message -parent .autopsf -message "You have not yet finished specifying the selections to use. If you are done with this, click the \"Continue to next step\" button in the Selections frame."
#   }

  # Load our temporary topology file
  topology ${basename}-temp.top

  # Apply default resname and name aliases
  psfaliases

  # mutated HIS
  set tmpmutate {}
  variable mutatehis
  foreach his $mutatehis {
      set segid {}
      if {[lindex $his 0]=="chain"} {
	      lappend segid [lindex [lsearch -inline $chaintoseg "[list [lrange $his 1 2]] *"] 1]
      } elseif {[lindex $his 0]=="seg"} {
	      lappend segid [lindex [lsearch -inline $segtoseg "[list [lrange $his 1 2]] *"] 1]
      } else {
	      set segid [lindex $his 1]
      }
      lappend tmpmutate [list $segid [lindex $his 2] [lindex $his 3]]
  }
  variable mutatehis $tmpmutate

  # perform residues mutations
  set tmpmutate {}
  variable mutatelist
  #set mutatelist [lindex $mutatelist 0]
  if {$mutatelist != ""} {
    foreach mut $mutatelist {
       set segid [lindex [lsearch -inline $chaintoseg "[list [lrange $mut 0 1]] *" ] 1]
       lappend tmpmutate [list $segid [lindex $mut 1] [lindex $mut 2]]
    }
    variable mutatelist $tmpmutate
  }

  #Open log file for the first time
  set logfilename "${basename}.log"
  set logfileout [open $logfilename w]

  puts $logfileout "\#Original PDB file: \n\#PDBSTART"
  set pdbfileold [open "${basename}-temp.pdb" "r"]
  puts $logfileout [read $pdbfileold]
  close $pdbfileold
  puts $logfileout "\#PDBEND"

  # Build the segments
  psfsegments $logfileout

  set ssbondlist [find_ssbonds]; 
  foreach ssbond $ssbondlist {
      set seg1 {}
      set seg2 {}
      if {[lindex $ssbond 0]=="chain"} {
	      set seg1 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 1 2]} *"] 1]
	      set seg2 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 4 5]} *"] 1]
      } else {
	      set seg1 [lindex $ssbond 1]
	      set seg2 [lindex $ssbond 4]
      }

#      puts $logfileout "patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]"
#      patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]
#      array set newpatch {patchname "DISU" seg1 $seg1 res1 [lindex $ssbond 2] seg2 $seg2 res2 [lindex $ssbond 5]}
      set newpatch "DISU $seg1 [lindex $ssbond 2] $seg2 [lindex $ssbond 5]"
      if {[lsearch -exact $chainnames $seg1] >= 0 && [lsearch -exact $chainnames $seg2] >= 0} {
      lappend patchlist $newpatch
    }

  }
  
  set glycanbondlist [make_glycan_patches]
  
  foreach glycanbond $glycanbondlist {
    set seg1 {}
    set seg2 {}
    if {[lindex $glycanbond 0] == "chain"} {
      set seg1 [lindex [lsearch -inline $chaintoseg "{[lrange $glycanbond 1 2]} *"] 1]
      set seg2 [lindex [lsearch -inline $chaintoseg "{[lrange $glycanbond 4 5]} *"] 1]
    } else {
      set seg1 [lindex $glycanbond 1]
      set seg2 [lindex $glycanbond 4]
    }
    
    set patch [lindex $glycanbond 6]
    set newpatch [list $patch $seg1 [lindex $glycanbond 2] $seg2 [lindex $glycanbond 5] ]
    if {[lsearch -exact $chainnames $seg1] >= 0 && [lsearch -exact $chainnames $seg2] >= 0} {
      lappend patchlist $newpatch
    }
  }

  
  
  

  # Deprotonate cysteines that are bound to iron (for Fe-S clusters)
  variable cysironbondlist
  foreach cysironbond $cysironbondlist {
      set cysteine [lindex $cysironbond 0]
      set segid {}
      if {[lindex $cysteine 0]=="chain"} {
	      lappend segid [lindex [lsearch -inline $chaintoseg "[list [lrange $cysteine 1 2]] *"] 1]
      } elseif {[lindex $cysteine 0]=="seg"} { 
	      lappend segid [lindex [lsearch -inline $segtoseg "[list [lrange $cysteine 1 2]] *"] 1]
      } else {
	      set segid [lindex $cysteine 1]
      }

      # Apply CYS deprotonation patch
      #puts $logfileout "patch CYSD ${segid}:[lindex $cysteine 2]"
      #patch CYSD ${segid}:[lindex $cysteine 2]
      set newpatch [list "CYSD" $seg1 [lindex $ssbond 2] "" ""]
      puts "Adding patch || $newpatch"
#      array set newpatch {patchname "CYSD" seg1 $segid res1 [lindex $cysteine 2] seg2 "" res2 ""}
      lappend patchlist $newpatch
  }

  update_patchtexts
  
  close $logfileout
  
  if {[llength $patchlist] == 0} {
    tk_messageBox -icon info -type ok -title Message -parent .autopsf -message "Because no patches were automatically assigned to your molecule, a complete psf and pdb will be generated now. If you would like to add patches and regenerate these files, use the Add patch button and click \"Apply patches and finish PSF/PDB\" when done. A new psf/pdb combo will then be generated."
    makepatches_gui
  }
}

proc autopsf::makepatches_gui {} {
  variable basename
  variable chainnames
  variable chaintoseg
  variable segtoseg
  # variable patchlist
  variable patchtexts
  variable logfilename
  variable logfileout
  variable patched
  
  # re-open logfile in append mode
  set logfileout [open $logfilename a] 
  
  #apply patches
  #foreach patch $patchlist {
    #set mylength [llength $patch]
    #if {$mylength == 5} {
      #puts $logfileout "Applying patch: [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2] [lindex $patch 3]:[lindex $patch 4]"
      #eval "patch [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2] [lindex $patch 3]:[lindex $patch 4]"
    #} elseif {$mylength == 3} {
      #puts $logfileout "Applying patch: [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2]"
      #eval "patch [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2]"
    #}
  #}
  foreach patch $patchtexts {eval "patch $patch"}
  set patched true


  # Remove failed guesses
  variable zerocoord
  variable nofailedguess
  if {$nofailedguess} {
      foreach segid [segment segids] {
	foreach resid [segment resids $segid] {
	    foreach atom [segment atoms $segid $resid] {
	      set coord [segment coordinates $segid $resid $atom]
	      if {[veclength [vecsub $coord {0.000000 0.000000 0.000000}]] < 0.00001 && [lsearch $zerocoord "$segid $resid $atom"]<0} {
		  puts $logfileout "Deleting atom $segid:$resid $atom with unspecified coordinates."
		  delatom $segid $resid $atom
	      }
	    }
	}
      }
  }

  # Translate the extra bondlist from chain to segid.
  translate_extrabonds_chain_to_segid

  # Guess positions of missing atoms
  variable guess
  if {$guess} { guesscoord }

# Regenerate coordinates if we were asked to
  variable regenall
  if {$regenall} {
    regenerate angles dihedrals
  }

  if { [catch { writepsf ${basename}_tmpfile.psf ; writepdb ${basename}_tmpfile.pdb } err] } {
      puts "ERROR: Couldn't write temp files. Do you have enough disk space?"
      return 2
  }
  
  # Look for unparametrized atoms (type=XX*).                       
  # If such atoms exist cut out a selection residues containing them
  # and launch a listbox with the unparametrized residues.          
  # From the listbox you can select residues to delete and rerun    
  # psfgen or parametrize them using PARATOOL.                      
  set unparcode [checkparams]
  if {$unparcode == 0} {
    variable water
    variable ionize
    if {$water}  { solvate ${basename}.psf ${basename}.pdb -o ${basename} -t 12 }
    if {$ionize} { autoionize -psf ${basename}.psf -pdb ${basename}.pdb -o ${basename} -is 0.5 }

    mol load psf ${basename}.psf pdb ${basename}.pdb
    tk_messageBox -type ok -title "Autopsf" -parent .autopsf \
	    -message "Structure complete. Your structure is in\n${basename}.pdb\n${basename}.psf\n Please remember that while AutoPSF usually makes correct guesses about things, its accuracy cannot be guaranteed. You should always inspect your structure prior to simulations; in particular, please check that the appropriate termini were used in the appropriate places, and that the chains have been split properly."
    variable currentMol
    #molinfo $currentMol set drawn 1
    variable vdwrepindex
    mol delrep $vdwrepindex $currentMol
    set vdwrepindex -1
    cleanup

  }
  close $logfileout
}

#Proc to clean up temp files
proc ::autopsf::clean_tempfiles {} {
  variable basename
  variable tempMol
  foreach tempfile [glob -nocomplain ${basename}-temp* ${basename}*modified* ${basename}_preformat*] { file delete $tempfile }
  mol delete $tempMol
}

#Procs to enable and disable different parts of the gui
proc ::autopsf::enable_input {} {
	variable w
	$w.input.mollable configure -state normal
	$w.input.mol configure -state normal
	$w.input.fplabel configure -state normal
	$w.input.prefix configure -state normal
	$w.input.topo.list.list configure -state normal
	$w.input.topo.list.buttons.add configure -state normal
	$w.input.topo.list.buttons.delete configure -state normal
	$w.input.next configure -state normal
}

proc ::autopsf::disable_input {} {
	variable w
	$w.input.mollable configure -state disabled
	$w.input.mol configure -state disabled
	$w.input.fplabel configure -state disabled
	$w.input.prefix configure -state disabled
	$w.input.topo.list.list configure -state disabled
	$w.input.topo.list.buttons.add configure -state disabled
	$w.input.topo.list.buttons.delete configure -state disabled
	$w.input.next configure -state disabled
}

proc ::autopsf::enable_sels {} {
	variable w
	$w.sels.allfrag configure -state normal
	$w.sels.pfrag configure -state normal
	$w.sels.nfrag configure -state normal
	$w.sels.rna configure -state normal
	$w.sels.dna configure -state normal 
	$w.sels.other configure -state normal
	$w.sels.osel configure -state normal
	$w.sels.next configure -state normal
}

proc ::autopsf::disable_sels {} {
	variable w
	$w.sels.allfrag configure -state disabled
	$w.sels.pfrag configure -state disabled
	$w.sels.nfrag configure -state disabled
	$w.sels.rna configure -state disabled
	$w.sels.dna configure -state disabled 
	$w.sels.other configure -state disabled
	$w.sels.osel configure -state disabled
	$w.sels.next configure -state disabled
}

proc ::autopsf::enable_chains {} {
	variable w
	$w.chains.list.list configure -state normal
	$w.chains.edits.add configure -state normal
	$w.chains.edits.edit configure -state normal
	$w.chains.edits.del configure -state normal
	$w.chains.finish configure -state normal
}

proc ::autopsf::disable_chains {} {
	variable w
	$w.chains.list.list configure -state disabled
	$w.chains.edits.add configure -state disabled
	$w.chains.edits.edit configure -state disabled
	$w.chains.edits.del configure -state disabled
	$w.chains.finish configure -state disabled
}

##########################################################
# This is called when psfgen is run from the GUI.        #
# (In batch mode "psfmain" is called directly)           #
# runpsfgen checks for the existence of a molecule and   #
# a topology file and finally runs psfmain.              #
##########################################################

proc ::autopsf::runpsfgen {} {
  variable currentMol
  puts "WORKING ON: $currentMol"
  if {$currentMol=="none"} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf \
	-message "No molecule loaded!"
      return 0
  }

  variable topfiles
  if {![llength $topfiles]} {
      tk_messageBox -icon error -type ok -title Message -parent .autopsf \
	-message "No topology file specified!"
      return 0
  }
  
  # We overwrite the previous tmp molecule
  variable tmpmolid
  if {$tmpmolid>0} { mol delete $tmpmolid ; set tmpmolid -1 }
  
  # If there is a user provided selection, use it for the build.
  variable allfrag
  variable pfrag
  variable nfrag
  variable ofrag
  variable oseltext
  

  if {$pfrag || $nfrag} {set allfrag false}

  
  if {$oseltext != ""} {
      set ofrag true
      set allfrag false
  }

  # Delete all previous segments from the structure but keep topogy and aliases
  resetpsf_autopsf

  # The main psfgen driving routine
  psfmain


  # FIXME: I think we should not reset the gui. (Jan)

  # After building reset the gui
#    set allfrag true
#    set pfrag   false
#    set nfrag   false
#    set ofrag   false
#    variable water  false
#    variable ionize false

  variable incomplete 1
}

########################################################
# The main psfgen driving routine.                     #
########################################################

proc ::autopsf::psfmain {} {
  variable basename
  variable currentMol
  variable ssbondlist
  variable chaintoseg
  variable segtoseg
  variable allfrag
  variable pfrag
  variable nfrag
  variable ofrag
  variable oseltext
  variable gui
  variable chainnames
  variable patched
  variable patchtexts
  variable logfilename
  variable logfileout
  puts "WORKING ON: $currentMol"
  preformat_pdb $currentMol
  
  if {[write_selection_tempfiles $currentMol] != 0} { return 2 }

  # Run psfcheck on the molecule to generate a temporary topology file
  # containing entries for unknown RESIs. It will be needed to build a
  # structure with psfgen since psfgen would choke on unknown residue names.
  if {[checktop] != 0} { return 2 }

  # Split the original PDB into one PDB file per segment
  # Segments are automatically determined by gaps in the resid numbering
  # and by chain IDs. At the same time a chain:resid to segid translation table
  # is generated because chains sometimes include cofactors such as metal ions.
  variable splitsegfiles [split_protein_and_water_pdb "${basename}-temp.pdb"]
  variable splitonly
  if {$splitonly == true} {return 0}

  # Load our temporary topology file
  topology ${basename}-temp.top
  puts "${basename}-temp.top"
  
  #foreach file [glob ${basename}*.*] {
   # file copy -force $file ./test/$file
  #}

  # Apply default resname and name aliases
  psfaliases

  # mutated HIS
  set tmpmutate {}
  variable mutatehis
  foreach his $mutatehis {
      set segid {}
      if {[lindex $his 0]=="chain"} {
	      lappend segid [lindex [lsearch -inline $chaintoseg "[list [lrange $his 1 2]] *"] 1]
      } elseif {[lindex $his 0]=="seg"} { 
	      lappend segid [lindex [lsearch -inline $segtoseg "[list [lrange $his 1 2]] *"] 1]
      } else {
	      set segid [lindex $his 1]
      }
      lappend tmpmutate [list $segid [lindex $his 2] [lindex $his 3]]
  }
  variable mutatehis $tmpmutate

  # perform residues mutations
  set tmpmutate {}
  variable mutatelist
  if {$mutatelist != ""} {
    foreach mut $mutatelist {
      set segid [lindex [lsearch -inline $chaintoseg "[list [lrange $mut 0 1]] *" ] 1]
      lappend tmpmutate [list $segid [lindex $mut 1] [lindex $mut 2]]
    }
    variable mutatelist $tmpmutate
  }

  # If continuing from GUI run, re-open existing logfile. Otherwise, create a new one
  if { $logfilename != "" } {
	  set logfileout [open $logfilename a]
  } else {
	set logfilename "${basename}.log"
	set logfileout [open $logfilename w]
}

  puts $logfileout "\#Original PDB file: \n\#PDBSTART"
  set pdbfileold [open "${basename}-temp.pdb" "r"]
  puts $logfileout [read $pdbfileold]
  close $pdbfileold
  puts $logfileout "\#PDBEND"

  # Build the segments
  psfsegments $logfileout

  # Apply the user specified patches
  variable patchlist
  variable segtoseg
  if { !$gui } {
	  set patchaux {}
	  set patchaux $patchlist
	  set patchlist {}
        foreach patch $patchaux {
		lset patch 1 [lindex [lsearch -inline $chaintoseg "[list [lrange $patch 1 2]] *" ] 1] 
		if {[llength $patch] == 5} {
		  lset patch 3 [lindex [lsearch -inline $chaintoseg "[list [lrange $patch 3 4]] *" ] 1] 
		} 
		lappend patchlist $patch
	  }
  }
 
  update_patchtexts
  foreach patch $patchtexts { eval "patch $patch" }
#  set patched true

#  foreach userpatch $patchlist {
#   #   set patch [lindex $userpatch 0]
#   #   foreach segres [lrange $userpatch 1 end] {
# 	#set newseg [lindex [lsearch -inline $segtoseg "{[split $segres :]} *"] 1]
# 	#puts $logfileout "NOTE: Applying patch $newseg:[lindex [split $segres :] 1]"
# 	#append patch " $newseg:[lindex [split $segres :] 1]"
#   #   }
#      set userpatch "[lindex $userpatch 0] [lindex $userpatch 1]:[lindex $userpatch 2]   [lindex $userpatch 3]:[lindex $userpatch 4]"
#      puts $userpatch
      #   puts $patch
#      eval patch $userpatch
#  }
  
  if {!$patched} {
    set ssbondlist [find_ssbonds]; 
    foreach ssbond $ssbondlist {
	set seg1 {}
	set seg2 {}
	# puts "SSBOND definition: $ssbondlist" ;# REMOVEME
	if {[lindex $ssbond 0]=="chain"} {
		set seg1 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 1 2]} *"] 1]
		set seg2 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 4 5]} *"] 1]
	} else {
		set seg1 [lindex $ssbond 1]
		set seg2 [lindex $ssbond 4]
	}

	# puts "\#patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]" ;#REMOVEME
	puts $logfileout "\#patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]"
	patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]
    }
    
    set glycanbondlist [make_glycan_patches]
    
    foreach glycanbond $glycanbondlist {
      set seg1 {}
      set seg2 {}
      if {[lindex $glycanbond 0] == "chain"} {
	set seg1 [lindex [lsearch -inline $chaintoseg "{[lrange $glycanbond 1 2]} *"] 1]
	set seg2 [lindex [lsearch -inline $chaintoseg "{[lrange $glycanbond 4 5]} *"] 1]
      } else {
	set seg1 [lindex $glycanbond 1]
	set seg2 [lindex $glycanbond 4]
      }
      
      set patch [lindex $glycanbond 6]
      puts $logfileout "\#patch $patch $seg1:[lindex $glycanbond 2] $seg2:[lindex $glycanbond 5]"
      patch $patch $seg1:[lindex $glycanbond 2] $seg2:[lindex $glycanbond 5]
    }

    # Deprotonate cysteines that are bound to iron (for Fe-S clusters)
    variable cysironbondlist
    foreach cysironbond $cysironbondlist {
	set cysteine [lindex $cysironbond 0]
	set segid {}
	if {[lindex $cysteine 0]=="chain"} {
		lappend segid [lindex [lsearch -inline $chaintoseg "[list [lrange $cysteine 1 2]] *"] 1]
	} elseif {[lindex $cysteine 0]=="seg"} { 
		lappend segid [lindex [lsearch -inline $segtoseg "[list [lrange $cysteine 1 2]] *"] 1]
	} else {
		set segid [lindex $cysteine 1]
	}

	# Apply CYS deprotonation patch
	puts $logfileout "\#patch CYSD ${segid}:[lindex $cysteine 2]"
	puts "Adding patch | $cysironbond | ${segid}:[lindex $cysteine 2]"
	patch CYSD ${segid}:[lindex $cysteine 2]
    }
  }
  # Remove failed guesses
  variable zerocoord
  variable nofailedguess
  if {$nofailedguess} {
      foreach segid [segment segids] {
	foreach resid [segment resids $segid] {
	    foreach atom [segment atoms $segid $resid] {
	      set coord [segment coordinates $segid $resid $atom]
	      if {$coord=={0.000000 0.000000 0.000000} && [lsearch $zerocoord "$segid $resid $atom"]<0} {
		  puts $logfileout "\#Deleting atom $segid:$resid $atom with unspecified coordinates." ;#"
		  delatom $segid $resid $atom
	      }
	    }
	}
      }
  }

  # Translate the extra bondlist from chain to segid.
  translate_extrabonds_chain_to_segid

  # Guess positions of missing atoms
  variable guess
  if {$guess} { guesscoord }

# Regenerate coordinates if we were asked to
  variable regenall
  if {$regenall} {
    regenerate angles dihedrals
  }

  if { [catch { writepsf ${basename}_tmpfile.psf ; writepdb ${basename}_tmpfile.pdb } err] } {
      puts "ERROR: Couldn't write temp files. Do you have enough disk space?"
      return 2
  }
  
  # Look for unparametrized atoms (type=XX*).                       
  # If such atoms exist cut out a selection residues containing them
  # and launch a listbox with the unparametrized residues.          
  # From the listbox you can select residues to delete and rerun    
  # psfgen or parametrize them using PARATOOL.                      
  set unparcode [checkparams]

  # Solvate and ionize if it is asked for, and then clean temp files
  if {$unparcode == 0} {
    variable water
    variable ionize
    if {$water}  { solvate ${basename}.psf ${basename}.pdb -o ${basename} -t 12 }
    if {$ionize} { autoionize -psf ${basename}.psf -pdb ${basename}.pdb -o ${basename} -is 0.5 }

    mol load psf ${basename}.psf pdb ${basename}.pdb
    if {$gui} {
      tk_messageBox -type ok -title "Autopsf" -parent .autopsf \
	      -message "Structure complete. Your structure is in\n${basename}.pdb\n${basename}.psf\n Please remember that while AutoPSF usually makes correct guesses about things, its accuracy cannot be guaranteed. You should always inspect your structure prior to simulations; in particular, please check that the appropriate termini were used in the appropriate places, and that the chains have been split properly."
      variable vdwrepindex
      set vdwrepindex -1
    } else {
		puts "Structure complete. Your structure is in\n${basename}.pdb\n${basename}.psf\n Please remember that while AutoPSF usually makes correct guesses about things, its accuracy cannot be guaranteed. You should always inspect your structure prior to simulations; in particular, please check that the appropriate termini were used in the appropriate places, and that the chains have been split properly."
    }
  }
  
  # These were temp files for splitting the pdb and for checktop
  variable basename
  foreach tempfile [glob ${basename}-temp*] { file delete $tempfile }

  close $logfileout
  set qwikmd false
  if {!$unparcode} {
	cleanup
  }
  return $unparcode
}


##############################################################
# Writes a temp PDB file of the user provided selection to   #
# split into fragments and run psfgen on.                    #
# The temp XBGF file containing (only) the bonds from the    #
# CONECT records of the original PDB is for psfcheck.        #
##############################################################

proc ::autopsf::write_selection_tempfiles { mol } {
  variable basename
  variable currentMol
  variable equivindices
  
  #Type of fragments to do
  variable allfrag
  variable pfrag
  variable nfrag
  variable ofrag
  variable qwikmd
  variable oseltext

  puts "pfrag: $pfrag ofrag: $ofrag allfrag: $allfrag osel: $oseltext nfrag: $nfrag"
  
  #Pick out the selections to be processed
  set writesel {}
  if {$allfrag} {
    set writesel [atomselect $currentMol all]
  } else {
    set writestring "none"
    if {$pfrag} {
      set writestring "$writestring or protein"
    }
    if {$nfrag} {
      set writestring "$writestring or nucleic"
    }
    if {$ofrag} {
      set writestring "$writestring or $oseltext"
    }
    if {$qwikmd} {
      set writestring "$writestring or $oseltext"
    }
    set writesel [atomselect $currentMol "$writestring"]
  }

  if {[$writesel num] == 0} {error "Need to have at least one atom in your selection!" ; return 2}

  #Write a temporary pdb file to split into fragments and run psfgen on
  if { [catch { $writesel writepdb ${basename}-temp.pdb } err] } {
    puts "ERROR: Couldn't write temp files. Do you have enough disk space?"
    return 2
  }

  #Store the bondinfo
  set bondlist   [$writesel getbonds]
  set bondorders [$writesel getbondorders]

  #Delete all bonds
  set nobonds {}
  foreach atom [$writesel list] {
    lappend nobonds {}
  }
  $writesel setbonds $nobonds
  $writesel setbondorders $nobonds

  #Read the CONECT info and set bonds accordingly
  set file [file rootname [molinfo $currentMol get name]].pdb
  # Since the addition of the format pdb functions (proc preformat_pdb) autopsf is not capable of reading 
  # the CONECT info, when the pdb is loaded from a local file (not directly from the PDB databank). The new created *_formatted.pdb
  # doesn't carry this information present in the original pdb file.
  read_pdb_conect $file $currentMol

  #Write a temporary xbgf file for checktop
  if { [catch { $writesel writexbgf ${basename}-temp.xbgf } err] } {
    puts "ERROR: Couldn't write temp files. Do you have enough disk space?"
    return 2
  }

  #Restore the bond info
  $writesel setbonds $bondlist
  $writesel setbondorders $bondorders

  #Save the index conversions
  set equivindices [$writesel get index]

  return 0
}


###################################################################
# Run psfcheck on the molecule to replace all unrecognized atoms  #
# with an XX* type.                                               #
# Psfcheck generates a temporary topology file containing entries #
# for unknown RESIs. It will be needed to build a structure with  #
# psfgen since psfgen would choke on unknown residue names.       #
###################################################################

proc ::autopsf::checktop {} {
  variable topfiles
  variable basename
  variable charmm36

  #check to see if we are using charmm36. important for patching NA.
  #checks for both older and charmm36 patches and sets the flag accordingly,
  #in such a way that the first patch takes precedence, similar to behavior found
  #elsewhere. Will print a warning to user.
  #
  set na_patch_detected 0
  puts "$topfiles"
  foreach top $topfiles {
    set f [open $top "r"]
    set r [read $f]
    if { [regexp -all -lineanchor {^PRES DEO5} $r] > 0 } {
      puts "DETECTED CHARMM36 NA"
      if {$na_patch_detected == 0} {
        set charmm36 1
      }
      incr na_patch_detected
    }
    if { [regexp -all -lineanchor {^PRES DEO1} $r] > 0 } {
      if {$na_patch_detected == 0} {
        set charmm36 0
      }
      incr na_patch_detected
    }
    close $f
  }
  if {$na_patch_detected > 1} {
    puts "WARNING: multiple nucleic acid patch definitions detected. Using first input definition."
  }
  if { [psfupdate [join $topfiles "|"] "${basename}-temp.xbgf" "${basename}-temp.top"] != 0} { 
    puts "ERROR: psf checking did not work correctly."
    puts "There may be something wrong with the input structure."
    return 1
  }
  # If there is more than one stream file in the input topologies, the RETURN statement
  # found at the end of each one will cause problems (psfgen will stop at the first one).
  # Let's strip them out.
  #
  # exec sed -i "s/return//gI" ${basename}-temp.top
  set infile [open $basename-temp.top r]
  set outfile [open $basename-temp.tmp w]
  set infile_data [read $infile]
  close $infile
  set data [split $infile_data "\n"]
  foreach line $data {
    if {![regexp -nocase return $line]} {
      puts $outfile "$line"
    }
  }
  close $outfile
  file rename -force $basename-temp.tmp $basename-temp.top  
  return 0
}

#Proc to delete a current chain
proc ::autopsf::delchain_gui {} {
	variable chainnames
	variable chainlengths
	variable chainstarts
	variable chainends
	variable chaintypes
	variable nters
	variable cters
	variable w
	variable basename
	variable splitsegfiles

	set chainsellist [$w.chains.list.list curselection]
  set chainsellist [lreverse $chainsellist]

	set chainind [lindex $chainsellist 0]
	foreach chainind $chainsellist {
	set chainnames [lreplace $chainnames $chainind $chainind]
	set chainstarts [lreplace $chainstarts $chainind $chainind]
	set chainends [lreplace $chainends $chainind $chainind]
	set chaintypes [lreplace $chaintypes $chainind $chainind]
	set nters [lreplace $nters $chainind $chainind]
	set cters [lreplace $cters $chainind $chainind]
	set chainlengths [lreplace $chainlengths $chainind $chainind]
	}

	set splitsegfiles [resplit_chains "${basename}-temp.pdb"]

}

#Proc to edit a current chain
proc ::autopsf::editchain_gui {} {
	variable chainnames
	variable chainlengths
	variable chainstarts
	variable chainends
	variable nters
	variable cters
	variable w
	variable chainind
	variable chaintypes
	set chainsellist [$w.chains.list.list curselection]
	if {[llength $chainsellist]!=1} {
		tk_messageBox -icon error -type ok -title Message -message "You must select exactly one chain to edit"
		return
	}
	set chainind [lindex $chainsellist 0]


	variable newchain_name [lindex $chainnames $chainind]
	variable newchain_start [lindex $chainstarts $chainind]
	variable newchain_end [lindex $chainends $chainind]
	variable newchain_nter [lindex $nters $chainind]
	variable newchain_cter [lindex $cters $chainind]
	variable newchain_type [lindex $chaintypes $chainind]

	if {[winfo exists .chaineditor]} {
	  wm deiconify .chaineditor
	  raise .chaineditor
	  return
	}

	set v [toplevel ".chaineditor"]
	wm title $v "Autopsf - Edit Chain"
	wm resizable $v 0 1
puts $chainind
	set row 0
#        label $v.namelabel -text "Chain Name: "
#        entry $v.name -textvariable [namespace current]::newchain_name
#        label $v.startlabel -text "First Atom: "
#        entry $v.start -textvariable [namespace current]::newchain_start
#        label $v.endlabel -text "Last Atom: "
#        entry $v.end -textvariable [namespace current]::newchain_end
#        label $v.nterlabel -text "N terminal patch: "
#        entry $v.nter -textvariable [namespace current]::newchain_nter
#        label $v.cterlabel -text "C terminal patch: "
#        entry $v.cter -textvariable [namespace current]::newchain_cter

#        button $v.addchain -text "Done" -command [namespace current]::editchain 

#        button $v.cancel -text "Cancel" -command "after idle destroy $v"

#	pack $v.namelabel $v.name $v.startlabel $v.start $v.endlabel $v.end 
#	pack $v.nterlabel $v.nter $v.cterlabel $v.cter 
#	pack $v.addchain $v.cancel

	#Basic Information
	frame $v.info
	label $v.info.namelabel -text "Chain Name: "
	entry $v.info.name -textvariable [namespace current]::newchain_name
	pack $v.info.namelabel $v.info.name -side left

	#Index entry
	frame $v.indices
	labelframe $v.indices.frame -bd 2 -relief ridge -text "Chain Definition" -padx 1m -pady 1m
	#Frame for the actual indices
	frame $v.indices.frame.index
	label $v.indices.frame.index.startlabel -text "First Atom: "
	entry $v.indices.frame.index.start -textvariable [namespace current]::newchain_start
	label $v.indices.frame.index.endlabel -text "Last Atom: "
	entry $v.indices.frame.index.end -textvariable [namespace current]::newchain_end
	pack $v.indices.frame.index.startlabel $v.indices.frame.index.start $v.indices.frame.index.endlabel $v.indices.frame.index.end -side left

	label $v.indices.frame.or -text "Or get indices from a selection: "

	#Frame for index selection
	frame $v.indices.frame.sel
	label $v.indices.frame.sel.label -text "Selection: "
	entry $v.indices.frame.sel.entry -textvar [namespace current]::selforchain -width 35
	button $v.indices.frame.sel.button -text "Get indices" -command [namespace current]::setnewindices 
	pack $v.indices.frame.sel.label $v.indices.frame.sel.entry $v.indices.frame.sel.button -side left -fill x

	pack $v.indices.frame.index $v.indices.frame.or $v.indices.frame.sel
	pack $v.indices.frame


	#Frame for other stuff
	frame $v.other
	label $v.other.nterlabel -text "N terminal patch: "
	entry $v.other.nter -textvariable [namespace current]::newchain_nter -width 6
	label $v.other.cterlabel -text "C terminal patch: "
	entry $v.other.cter -textvariable [namespace current]::newchain_cter -width 6
	label $v.other.typelabel -text "Chain type: "
	menubutton $v.other.type -height 1 -relief raised -textvar [namespace current]::newchain_type_text -menu $v.other.type.menu
	menu $v.other.type.menu -tearoff no
	pack $v.other.nterlabel $v.other.nter $v.other.cterlabel $v.other.cter $v.other.typelabel $v.other.type -side left 

	#Make the type menu
	$v.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 0 -label "Protein"
	$v.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 1 -label "DNA"
	$v.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 2 -label "RNA"
	$v.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 3 -label "Other"

	#Frame for buttons
	frame $v.buttons
	button $v.buttons.addchain -text "Apply" -command [namespace current]::editchain

	button $v.buttons.cancel -text "Done" -command "after idle destroy $v"
	pack $v.buttons.addchain $v.buttons.cancel -side left

	pack $v.info $v.indices $v.other $v.buttons
	
}

proc ::autopsf::editchain {} {
	variable chainnames
	variable chainlengths
	variable chainstarts
	variable chainends
	variable chaintypes
	variable nters
	variable cters
	variable splitsegfiles
	variable basename
	variable newchain_name 
	variable newchain_start
	variable newchain_end 
	variable newchain_nter 
	variable newchain_cter
	variable newchain_type
	variable chainind
	puts $chainind

	set chainnames [lreplace $chainnames $chainind $chainind $newchain_name]
	set chainstarts [lreplace $chainstarts $chainind $chainind $newchain_start]
	set chainends [lreplace $chainends $chainind $chainind $newchain_end]
	set nters [lreplace $nters $chainind $chainind $newchain_nter]
	set cters [lreplace $cters $chainind $chainind $newchain_cter]
	set chaintypes [lreplace $chaintypes $chainind $chainind $newchain_type]

	set splitsegfiles [resplit_chains "${basename}-temp.pdb"]

}

#Proc to add a new chain

proc ::autopsf::addchain_gui {} {
	variable newchain_name "chainname"
	variable newchain_start 0
	variable newchain_end 0
	variable newchain_nter "none"
	variable newchain_cter "none"

	if {[winfo exists .chainadder]} {
	  wm deiconify .chainadder
	  raise .chainadder
	  return
	}

	set w [toplevel ".chainadder"]
	wm title $w "Autopsf - Add Chain"
	wm resizable $w no no

	set row 0
	#Basic Information
	frame $w.info
	label $w.info.namelabel -text "Chain Name: "
	entry $w.info.name -textvariable [namespace current]::newchain_name
	pack $w.info.namelabel $w.info.name -side left

	#Index entry
	frame $w.indices
	labelframe $w.indices.frame -bd 2 -relief ridge -text "Chain Definition" -padx 1m -pady 1m
	#Frame for the actual indices
	frame $w.indices.frame.index
	label $w.indices.frame.index.startlabel -text "First Atom: "
	entry $w.indices.frame.index.start -textvariable [namespace current]::newchain_start
	label $w.indices.frame.index.endlabel -text "Last Atom: "
	entry $w.indices.frame.index.end -textvariable [namespace current]::newchain_end
	pack $w.indices.frame.index.startlabel $w.indices.frame.index.start $w.indices.frame.index.endlabel $w.indices.frame.index.end -side left

	label $w.indices.frame.or -text "Or get indices from a selection: "

	#Frame for index selection
	frame $w.indices.frame.sel
	label $w.indices.frame.sel.label -text "Selection: "
	entry $w.indices.frame.sel.entry -textvar [namespace current]::selforchain -width 35
	button $w.indices.frame.sel.button -text "Get indices" -command [namespace current]::setnewindices 
	pack $w.indices.frame.sel.label $w.indices.frame.sel.entry $w.indices.frame.sel.button -side left -fill x

	pack $w.indices.frame.index $w.indices.frame.or $w.indices.frame.sel
	pack $w.indices.frame


	#Frame for other stuff
	frame $w.other
	label $w.other.nterlabel -text "N terminal patch: "
	entry $w.other.nter -textvariable [namespace current]::newchain_nter -width 6
	label $w.other.cterlabel -text "C terminal patch: "
	entry $w.other.cter -textvariable [namespace current]::newchain_cter -width 6
	label $w.other.typelabel -text "Chain type: "
	menubutton $w.other.type -height 1 -relief raised -textvar [namespace current]::newchain_type_text -menu $w.other.type.menu
	menu $w.other.type.menu -tearoff no
	pack $w.other.nterlabel $w.other.nter $w.other.cterlabel $w.other.cter $w.other.typelabel $w.other.type -side left 

	#Make the type menu
	$w.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 0 -label "Protein"
	$w.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 1 -label "DNA"
	$w.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 2 -label "RNA"
	$w.other.type.menu add radiobutton -variable [namespace current]::newchain_type -value 3 -label "Other"

	#Frame for buttons
	frame $w.buttons
	button $w.buttons.addchain -text "Add chain" -command [namespace current]::addchain

	button $w.buttons.cancel -text "Cancel" -command "after idle destroy $w"
	pack $w.buttons.addchain $w.buttons.cancel -side left

	pack $w.info $w.indices $w.other $w.buttons

}

proc ::autopsf::addchain {} {
	variable chainnames
	variable chainlengths
	variable chainstarts
	variable chaintypes
	variable chainends
	variable nters
	variable cters
	variable splitsegfiles
	variable basename
	variable newchain_name 
	variable newchain_start
	variable newchain_end 
	variable newchain_nter 
	variable newchain_cter
	variable newchain_type

	lappend chainnames $newchain_name
	lappend chaintypes $newchain_type
	lappend chainstarts $newchain_start
	lappend chainends $newchain_end
	lappend nters $newchain_nter
	lappend cters $newchain_cter
	lappend chainlengths 0

	set splitsegfiles [resplit_chains "${basename}-temp.pdb"]

}


#Proc to recreate chain files according to user-edited specifications
#Currently, it will follow the atom index specifications given, and report the
#new number of residues

proc ::autopsf::resplit_chains { fname } {
  variable chainformat
  variable chaintoseg 
  variable segtoseg
  variable ctermini 
  variable zerocoord 
  variable nofailedguess
  variable segtypes 
  variable segbounds 
  variable nters
  variable chaintexts
  variable cters
  variable chainstarts
  variable chainends
  variable chainlengths
  variable chainnames
  variable currentMol
  variable chaintypes
  set in [open "$fname" r]
  set nseg 0
  set first  1
  set newfile 1
  set curwater 0
  set oldwater 0
  set newseg  0
  set nwatseg 0
  set npseg   0
  set nnseg 0
  set noseg 0
  set curnuc 0
  set curprot 0
  set curo 0
  set oldnuc 0
  set oldprot 0
  set oldo 0
  set segid {}
  set resname {}
  set curseg {}
  set oldcurseg {}
  set segtype ""
  set segstart ""
  set lineindex 0
  set residues 0
  set oldsegid ""
  set last [list]
  set chaintoseg [list]
  set segtoseg [list]
  set fnamelist [list]

  set sel [atomselect $currentMol all]
  $sel writepdb "$fname"
  set allchainfile [open "$fname" r]
  set farray [split [read -nonewline $allchainfile] \n] 
  set index 0
  foreach segname $chainnames start $chainstarts end $chainends {
    set newname "${fname}_${segname}.pdb"
    set out [open $newname w] 
    puts "Chain: $start $end"
    set myrange [lrange $farray $start $end]
    lappend fnamelist $newname
    foreach line $myrange {
	puts $out $line
    }
    set oldres -1
    set residues 0
    foreach line $myrange {
      set curres  [string trim [string range $line 22 25]]
      set resname [string trim [string range $line 17 20]]
      set curseg  [string trim [string range $line 72 75]]
      set curres  [string trim [string range $line 22 25]]
      set resdif [expr $curres - $oldres]
#       puts "Residues: $curres $oldres"
      if {$resdif != 0} {
	incr residues
	      lappend chaintoseg [list [list [string index $line 21] $curres] $segname]
	lappend segtoseg [list [list $curseg $curres] $segname]
      }
#      puts "Nres: $residues"

      set oldres $curres

    }

    close $out
    set chainlengths [lreplace $chainlengths $index $index $residues]
    incr index
    }

  set chaintexts [list]
  foreach segname $chainnames length $chainlengths start $chainstarts end $chainends nter $nters cter $cters type $chaintypes {
#           puts "$segname $length $start $end $nter $cter"
	  switch $type {
	    0 {set typestr "Prot "}
	    1 {set typestr "DNA  "}
	    2 {set typestr "RNA  "}
	    3 {set typestr "Water"}
	    4 {set typestr "Glyc "}
	    default {set typestr "Other"}
	  }
	  set newstring [format $chainformat $segname $length $start $end $nter $cter $typestr]
	  lappend chaintexts $newstring
  } 

#   puts "$fnamelist"
  return $fnamelist
}


###################################################################
# AutoPSF expects each segment to appear in a contiguous block in #
# the input PDB file. This is fine for glycans, but heteroatoms   #
# are often jumbled at the end with no rhyme or reason. In        #
# particular, we want to be able to give each N-linked glycan     #
# its own segname, but this is impossible without pre-sorting the #
# PDB file prior to passing through AutoPSF.                      #
###################################################################



###################################################################
# Procedure to ensure the continuity of the atom indexes on each  #
# residue and also the increasing number of the resiIDs on each   #
# chain. To ensure the atom indexing, ::TopoTools::selections2mol #
# loads atoms selection containing individual residue, keeping a  #
# continuous number of the atoms. The increasing number of the    #
# is done by the "foreach residue $residueList" loop              #
################################################################### 
proc ::autopsf::sort_to_writepdb { molid selection outPutFileName} {
  set sel [list] 
  foreach chain [lsort -unique [$selection get chain]] {
    set selectionAux [atomselect $molid "\(residue [$selection get residue]\) and chain \"$chain\""]  
    set residueList [lsort -unique -integer -increasing  [$selectionAux get residue] ]

    set residList [$selectionAux get resid]
    array set x {}
    set res {}
    foreach e $residList {
        if {[info exists x($e)]} continue
        lappend res $e
        set x($e) {}
    }
    set residList $res
    set reslength [expr [llength $residList] -1]
   
    
    set resListIncr 0
    set reorderResids 0
    if {[lindex $residList 0] > [lindex $residList 1] && [llength $residList] > 1} {
      set reorderResids 1
      puts "Warning: Residues ID with inverted order: [lindex $residList 0] -- [lindex $residList end], chain ${chain}."
      puts "Warning: Residues will be order according to the atom sequence."

    }
    set residList [lsort -integer -increasing $residList]
    foreach residue $residueList {
      set selAux [atomselect $molid "residue $residue"]
       if {$reorderResids == 1} {
        $selAux set resid [lindex $residList $resListIncr]
      }
      
      lappend sel $selAux
     
      incr resListIncr
    }
   $selectionAux delete
  } 
 if {[llength $sel] > 0} {
    set auxMol [::TopoTools::selections2mol $sel]
    set selAll [atomselect $auxMol all]
    $selAll writepdb ${outPutFileName}
    
    foreach seli $sel {
      $seli delete
    }
    $selAll delete
    mol delete $auxMol 
  } else {
    $selection writepdb ${outPutFileName}
  }
}

proc ::autopsf::preformat_pdb { molid } {
  variable basename
  variable currentMol
  variable tempMol
  variable qwikmd
  array set sorted_glycans {}
  array set glycan_olist {}
  set final_segnames {}
  set all_glycans [list]
  set glycsegs ""
  set thisresdat [list]
  # An ugly hack because the atomselect keyword "protein" will not capture protein residues with missing
  # backbone atoms
  set protres {ALA ARG ASN ASP CYS GLN GLU GLY HIS HSD HSE HSP ILE LEU LYS MET PHE PRO SER THR TRP TYR VAL}
  ## In case of being called by qwikmd, use qwikmd macros to identify the different molecules types:
  ## qwikmd_protein for protein, qwikmd_glycan for glycans. 
  ## Only water has no macro defined in qwikmd.  
  set seltext "resname $protres"
  if {$qwikmd} {
    set seltext "qwikmd_protein"
  } 
  set protein [atomselect $molid $seltext]
  set ion [atomselect $molid ion]
  set water [atomselect $molid water]
  if {!$qwikmd} {
    set glycan [atomselect $molid glycan]
    set other [atomselect $molid "not (($seltext) or ion or water or glycan)"]
  } else {
    set glycan [atomselect $molid qwikmd_glycan]
    set other [atomselect $molid "not (($seltext) or ion or water or qwikmd_glycan)"]
  }
  #Only proteins,glycans and other (everything but water and ions) are reordered
  sort_to_writepdb $molid $protein ${basename}_preformat_protein.pdb
  sort_to_writepdb $molid $glycan ${basename}_preformat_glycan.pdb
  sort_to_writepdb $molid $other ${basename}_preformat_other.pdb
  # $protein writepdb ${basename}_preformat_protein.pdb
   $ion writepdb ${basename}_preformat_ion.pdb 
   $water writepdb ${basename}_preformat_water.pdb
  # $glycan writepdb ${basename}_preformat_glycan.pdb
  # $other writepdb ${basename}_preformat_other.pdb 
  
  set filenames [list ${basename}_preformat_protein.pdb ${basename}_preformat_ion.pdb \
		      ${basename}_preformat_water.pdb ${basename}_preformat_glycan.pdb \
		      ${basename}_preformat_other.pdb ]
  
  $protein delete
  $ion delete
  $water delete
  $glycan delete
  $other delete
  
  # Single out the glycans for sorting. We'll first sort them by chain and resid,
  # then use a final geometric test to make sure that all interconnected residues
  # are in contiguous blocks.
  
  set in [open ${basename}_preformat_glycan.pdb r]
  set pdbdata [split [read $in] "\n"]
  close $in
  set i 0
  set thisline [lindex $pdbdata $i]
  while {$i <= [llength $pdbdata]} {
    set head [string range $thisline 0 5]
    if { ![regexp {ATOM|HETATM} $head] } {
      incr i
      set thisline [lindex $pdbdata $i]
      puts $head
      continue
    } else {
      set resname [string trim [string range $thisline 17 20]]
      set curseg  [string trim [string range $thisline 72 75]]
      set curchain [string index $thisline 21]
      set curres  [string trim [string range $thisline 22 25]]
      set curresA [string trim [string range $thisline 26 26]]
      set thisresdat {}
      
   while {[string trim [string range $thisline 22 25]] == $curres &&
              [string trim [string range $thisline 26 26]] == $curresA &&
                       [string index $thisline 21] == $curchain} {	
          lappend thisresdat $thisline
	        incr i
	        set thisline [lindex $pdbdata $i]	
      }

      set thisres [list $curchain $curres $curresA]
      lappend all_glycans "{[lrange $thisres 0 2]} {[lrange $thisresdat 0 end]}"

    }
  }

  set all_glycans [lsort -dictionary -index 0 $all_glycans]

  set ngseg 0
  set first 1
  foreach  resid $all_glycans {
    set glycres [lindex $resid 0]
    set glycdata [lindex $resid 1]
    set thischain [lindex $glycres 0]
    set thisresid [lindex $glycres 1]
    set C1coords ""
    foreach entry $glycdata {
      set thisname [string trim [string range $entry 13 16]]
      if { $thisname == "C1" } {
	set C1x [string trim [string range $entry 30 37]]
	set C1y [string trim [string range $entry 38 45]]
	set C1z [string trim [string range $entry 46 53]]
	set C1coords [list $C1x $C1y $C1z]
      }
    
    }  
      # Perform an initial sort to group glycans into connected fragments

    if {$first} {
      set segname "${thischain}G1"
      incr ngseg
      lappend glycsegs [list $segname $C1coords] ;# keep the C1 coordinates of the stem of this fragment
    } else {
      set i 0
      set foundlink 0
      while { $i < [llength $glycsegs] && !$foundlink } {
	set thisseg [lindex [lindex $glycsegs $i] 0]
	incr i
	foreach oxygen $glycan_olist($thisseg) {
	  set Ocoords [lrange $oxygen 1 3]
	  if { [vecdist $C1coords $Ocoords ] <= 2. } {
	    set segname $thisseg
	    set foundlink 1
	    break
	  }
	}
      }
      if {!$foundlink} {
	incr ngseg
	set segname "${thischain}G$ngseg"
	lappend glycsegs [list $segname $C1coords]
      }
      
    }

    
    lappend sorted_glycans($segname) $glycdata
    
    # Add the oxygen atoms of the current residue to the running tally for this segment.
    foreach entry $glycdata {
      set thisname [string trim [string range $entry 13 16]]
      if { [regexp {^O[0-9]*$} $thisname ] } {
	set thisx [string trim [string range $entry 30 37]]
	set thisy [string trim [string range $entry 38 45]]
	set thisz [string trim [string range $entry 46 53]]
	lappend glycan_olist($segname) "$thisname $thisx $thisy $thisz"
      }
    }
    set first 0
  }  
  set glycsegs [lsort -dictionary $glycsegs]
  puts "Step 3 done"
  # Now that we have the glycan residues sorted into connected fragments, we just have
  # to do one final sort to check if any fragments should be linked into one. Most of the
  # time this should be superfluous, but it will catch glycans with unusual numbering. We take
  # the free C1 terminus from each fragment and search for contact with oxygens from every
  # other glycan segment. If one is found, the two segments are merged. Finally, the segments
  # are renumbered so that each chain starts from 1.
  set i 0
  foreach entry $glycsegs {
    set seg [lindex $entry 0]
    set C1coords [lindex $entry 1]
    set foundlink 0
    set j 0
    while { $j < [llength $glycsegs] && !$foundlink } {
      set thisseg [lindex [lindex $glycsegs $j] 0]
      puts $thisseg
      foreach oxygen $glycan_olist($thisseg) {
	if {$thisseg == $seg} {incr j; continue}
	set Ocoords [lrange $oxygen 1 3]
	if { [vecdist $C1coords $Ocoords ] <= 2.} {
	  lappend sorted_glycans($thisseg) $sorted_glycans($seg)
	  lappend glycan_olist($thisseg) $glycan_olist($seg)
	  array unset $sorted_glycans($seg)
	  array unset $glycan_olist($seg)
	  set glycsegs [lreplace glycsegs $i $i]
	  set foundlink 1
	  puts "found link between $seg and $thisseg"
	  break
	}
	incr j
      }
    }
    incr i
  }
  # set curseg  [string trim [string range $thisline 72 75]]
  set lastchainid ""
  set segsthischain 0
  for {set i 0} {$i < [llength $glycsegs] } {incr i} {
    set thisseg [lindex [lindex $glycsegs $i] 0]
    set thischainid [string index $thisseg 0]
    if { $thischainid == $lastchainid } {
      incr segsthischain
    } else {
      set segsthischain 1
    }
    set newseg ${thischainid}G$segsthischain
    set sorted_glycans($newseg) $sorted_glycans($thisseg)
    set lastchainid $thischainid
    set thischain [list]
    foreach res $sorted_glycans($thisseg) {
      set thisres [list]
      foreach line $res {
	set line [string replace $line 72 75 "[format %-4s $newseg]"]
	lappend thisres $line
      }
      lappend thischain $thisres
    }
    # puts "Old segname is $thisseg, new segname is $newseg"
    set sorted_glycans($newseg) $thischain
    if {$newseg != $thisseg} {
      array unset sorted_glycans($thisseg)
    }
    lappend final_segnames $newseg
  }
  # set final_segnames $glycsegs

  set out [open ${basename}_preformat_glycan.pdb w]
  foreach seg $final_segnames {
    foreach res $sorted_glycans([lindex $seg 0]) {
      foreach line $res {
	puts $out $line
      }
    }

    
   
  }
  close $out
  
  set out [open ${basename}_formatted.pdb w]
  
  foreach file $filenames {
    set in [open $file r]
    fcopy $in $out 
    close $in
  }
  close $out

  #strip out the CRYST and END lines
  set in [open ${basename}_formatted.pdb r]
  set out [open ${basename}_formatted_stripped.pdb w]
  while { [gets $in line] >= 0 } {
    set head [string range $line 0 5]
    if { [regexp {ATOM}  $line] } {
      puts $out $line
    }
  }
  close $in
  close $out
  
  file copy -force ${basename}_formatted_stripped.pdb ${basename}_formatted.pdb
  file delete ${basename}_formatted_stripped.pdb
    
  
  set tempMol [mol new ${basename}_formatted.pdb]
  set currentMol $tempMol
  foreach tempfile $filenames {
  file delete $tempfile
  }
  

}

##################################################################
# Split the original PDB into one PDB file per segment.          #
# Segments are automatically determined by gaps in the resid     #
# numbering and by chain IDs. At the same time a chain:resid to  #
# segid translation table is generated because chains sometimes  #
# include cofactors such as metal ions.                          #
##################################################################
  
proc ::autopsf::split_protein_and_water_pdb { fname } {
  variable chainformat
  variable currentMol
  variable chaintoseg {}
  variable segtoseg {}
  variable segtoseg {}
  variable seglist {}
  variable ctermini {}
  variable zerocoord {}
  variable nofailedguess
  variable segtypes {}
  variable segbounds {}
  variable equivindices
  variable nters
  variable chaintexts
  variable cters
  variable chainstarts
  variable chainends
  variable chainlengths
  variable chainnames
  variable chainreps
  variable chaintypes
  variable thischaintype
  variable segsthischain
  variable qwikmd
  set nters [list]
  set chainlengths [list]
  set cters [list]
  set chainstarts [list]
  set chainends [list]
  set chainnames [list]
  set chaintypes [list]
  set chaintexts [list]
  set in [open $fname r]
  set nseg 0
  set first  1
  set newfile 1
  set curwater 0
  set oldwater 0
  set newseg  0
  set nwatseg 0
  set npseg   0
  set nnseg 0
  set ngseg 0
  set noseg 0
  set curnuc 0
  set curprot 0
  set curo 0
  set curglyc 0
  set oldnuc 0
  set oldprot 0
  set oldglyc 0
  set oldo 0
  set segid {}
  set resname {}
  set curseg {}
  set oldcurseg {}
  set curchain {}
  set oldcurchain {}
  set segtype ""
  set segstart ""
  set lineindex 0
  set residues 1
  set oldsegid ""
  set last [list]
  set isrna 0
  set isdna 0
  set thischaintype 3
  set segsthischain 0
  set thisresdat ""
  set lastresdat ""
  set curglycdat [list]
  set all_glycans [list]
  array set sorted_glycans {}
  array set glycan_olist {}
  set glycsegs {}
  
  #Clear current list of chain representations
  foreach rep $chainreps {
      mol delrep $rep $currentMol
  }
    
  
  set pdbdata [split [read -nonewline $in] \n]
  close $in
  set i 0
  set thisline [lindex $pdbdata $i]
  while {$i <= [llength $pdbdata]} {
    set head [string range $thisline 0 5]
    if { [string compare $head "ATOM  "] != 0  && [string compare $head "HETATM"] !=0 } {
      incr i
      set thisline [lindex $pdbdata $i]
      puts $head
      continue
    } else {
      set oldresname $resname
      set oldwater $curwater
      set oldnuc $curnuc
      set oldo $curo
      set oldprot $curprot
      set oldglyc $curglyc
      set oldcurseg $curseg
      set oldcurchain $curchain
      set curwater 0 
      set curnuc 0
      set curprot 0
      set curo 0
      set curglyc 0
      set resname [string trim [string range $thisline 17 20]]
      set curseg  [string trim [string range $thisline 72 75]]
      set curchain [string index $thisline 21]
      set curres  [string trim [string range $thisline 22 25]]
      set curresA [string trim [string range $thisline 26 26]]
      set lastresdat $thisresdat
      set thisresdat {}
      set C1coords {}
      
      # Store atoms that are at the origin
      if {$nofailedguess} {
	set coor [string range $line 30 53]
	if {[vecsub {0 0 0} $coor]=={0.0 0.0 0.0}} {
	    set name [string trim [string range $line 12 15]]
	    #puts "Atom $curseg:$curres $name located at {0 0 0}"
            lappend zerocoord [list $curseg $curres $name]
	}	     
      }
      
      
      
      if {[regexp {HOH|TIP3|TIP4|TP4E|TP4V|TP3E|SPCE|SPC} $resname]} {
	set curwater 1 
      }
      if {[regexp {ALA|ARG|ASN|ASP|CYS|^GLN|GLU|GLY|HIS|HSD|HSE|HSP|ILE|LEU|LYS|MET|PHE|PRO|SER|THR|TRP|TYR|VAL} $resname] } {
	set curprot 1
      }
      if {$qwikmd && !$curprot} {
        set list [atomselect macro qwikmd_protein]
      	if {[string first  "or (resname $resname)" $list] > -1 } {
		set curprot 1
      	}
      }
      if {[regexp {GUA|CYT|THY|ADE|URA|^A$|^C$|^G$|^T$|^U$|^Ar$|^Ad$|^Cr$|^Cd$|^Gr$|^Gd$|^Ur$|^Td$|^DA$|^DT$|^DG$|^DC$} $resname]} { 
	set curnuc 1
  }
    if {$qwikmd && !$curnuc} {
         set list [atomselect macro qwikmd_nucleic]
      if {[string first  "or (resname $resname)" $list] > -1 } {
  set curnuc 1
      }
    }
    if {$curnuc} {
	if {[regexp {^U$|URA|^Ur$} $resname]} {
	  set isrna 1
	  set isdna 0
	}
	if {[regexp {^T$|THY|^Td$|^DT$|^DA$|^DG$|DC$} $resname]} {
	  set isrna 0
	  set isdna 1
	}
	}
      
      if {[regexp {AMAN|BMAN|AFUC|BGLN|MAN|BMA|FUC|NAG|AGLC|BGLC|AALT|BALT|AALL|BALL|AGAL|BGAL|AGUL|BGUL|AIDO|BIDO|ATAL|BTAL|AXYL|BXYL|AFUC|BFUC|ARHM|BRHM} $resname]} {
	set curglyc 1
      }
    if {$qwikmd && !$curglyc} {
         set list [atomselect macro qwikmd_glycan]
      if {[string first  "or (resname $resname)" $list] > -1 } {
  set curglyc 1
      }
      }
      if {!$curnuc && !$curprot && !$curwater && !$curglyc} {
	set curo 1
      }

      # Is the segment type changing?
      if { $curwater && !$oldwater } { set newseg 1 }
      if { $curprot && !$oldprot} { set newseg 1 }
      if { $curnuc && !$oldnuc} { set newseg 1 }
      if { $curglyc && !$oldglyc} { set newseg 1 }
      if { $curo && !$oldo } { set newseg 1 }

      # Check if the segID changes
      if {$curseg!=$oldcurseg || $curchain != $oldcurchain} {
	set newseg 1
	if {[llength $segid]} {
		lappend segtoseg   [list [list $curseg $curres] $segid]
	}
      }
      set firstresindex $lineindex ;# index of the first atom of this residue
      set lastresindex [expr $lineindex - 1]; #last atom of last residue
      # read in and temporarily store one complete residue
      while {[string trim [string range $thisline 22 25]] == $curres &&
	     [string trim [string range $thisline 26 26]] == $curresA && [string trim [string range $thisline 21 21]] == $curchain} {
	lappend thisresdat $thisline
	incr i
	incr lineindex
	set thisline [lindex $pdbdata $i]	
      }

      
      # Check the resID increment
      if { $first } { set oldres [expr $curres-1] ; set residues 0}
      
      set resdif [expr $curres - $oldres]
  

      # In some legitimate cases the protein resID can take a non-unit step:
      #   - Insertions in antibodies can be, for example, 100A, 100B, 100C etc.
      #     VMD will give all of these the resid label 100, and all but one will
      #     be dropped if not properly handled. If we just assume all residues of the
      #     same number are connected, missing residues in such a stretch will not be
      #     handled, and we'll get an erroneously connected chain;
      #   - Deletions in antibodies are the inverse of this: the resID may jump
      #     2 or more units without an actual break in the chain
      #   - N-terminal expression tags on proteins are often given negative resIDs.
      #     Some include zero, some don't; in the latter the jump from -1 to 1 has
      #     to be handled. 
      #
      # In the below approach, we specifically isolate all cases where a protein residue
      # has a non-unit increment in resID from the previous one. We then pull out the
      # {x,y,z} coordinates of the C atom from the preceding residue and the N atom from
      # this one, and check to see if they're less than 2A apart. If so, we assume they're
      # part of the same chain. If not, we stop this segment and start a new one.
      
      
      if { !$newseg && !$first && $curprot && $resdif != 1 } {
	# find the C atom of the previous residue. Note that in the event of AltLoc entries,
	# this will simply pick the first one.
	foreach entry $lastresdat {
	  if { [string trim [string range $entry 13 16]] == "C" } {
	    set Cx [string trim [string range $entry 30 37]]
	    set Cy [string trim [string range $entry 38 45]]
	    set Cz [string trim [string range $entry 46 53]]
	    set Ccoords [list $Cx $Cy $Cz]
	    break
	  }
	}
	foreach entry $thisresdat {
	  if { [string trim [string range $entry 13 16]] == "N" } {
	    set Nx [string trim [string range $entry 30 37]]
	    set Ny [string trim [string range $entry 38 45]]
	    set Nz [string trim [string range $entry 46 53]]
	    set Ncoords [list $Nx $Ny $Nz]
	    break
	  }
	}

	if { [vecdist $Ccoords $Ncoords] >= 2. } {
	  set newseg 1
	}
      }
      #check if the non-consecutive nucleic residues are connected (Bond formed by O3' - P)
   if { !$newseg && !$first && $curnuc && $resdif != 1 } {
    set Ocoords [list]
    set Pcoords [list]
     foreach entry $lastresdat {
        if { [regexp "^O3" [string trim [string range $entry 13 16]]] == 1 } {
          set Ox [string trim [string range $entry 30 37]]
          set Oy [string trim [string range $entry 38 45]]
          set Oz [string trim [string range $entry 46 53]]
          set Ocoords [list $Ox $Oy $Oz]
          break
        }
      }
      foreach entry $thisresdat {
        if { [string trim [string range $entry 13 16]] == "P" } {
          set Px [string trim [string range $entry 30 37]]
          set Py [string trim [string range $entry 38 45]]
          set Pz [string trim [string range $entry 46 53]]
          set Pcoords [list $Px $Py $Pz]
          break
        }
      }
      if {[llength $Ocoords] > 0 && [llength $Pcoords] > 0} {
        if {[vecdist $Ocoords $Pcoords] >= 2. } {
          set newseg 1
        }
      } else {
         set newseg 1
      }
   }    
      
      # A related problem exists for glycans. While a typical glycan chain is numbered
      # sequentially, the chain itself is often branched and there are multiple possible
      # glycosidic linkages, meaning that assignment of bonding must be done geometrically.
      # To make matters worse, connected glycans are not necessarily grouped in a logical
      # order in the PDB file: there may be any number of different HETERO residues between
      # spatially adjacent glycan residues. In order to work within the existing AutoPSF
      # framework (which requires each segment to be contiguous within the PDB file), 
      # I added a new proc (::autopsf::preformat_pdb) to be run at the very beginning
      # of the AutoPSF process. The function of this proc is to split the PDB into its 
      # different fragments (protein, water, ion, glycan, other), sort the glycans into
      # connected groups, and then write everything back into a single PDB file to be fed
      # to the main proc. I take the opportunity to give the glycans unique segnames 
      # ({chain}G{index}) there, which makes the job here easy. If the current residue is a glycan
      # we simply set the output segname to $curseg.
      
      

      # If any of the conditions for a new segment are satisfied, 
      if { $newseg || (!$curwater && !$curprot && !$curglyc && !$curnuc && ($resdif != 0 && $resdif != 1 && !($resdif == 2 && $oldres == -1))) } {
	if {[info exists out]} {
	    lappend chainends [expr [lindex $equivindices [expr $lastresindex]] + 1]
	    lappend cters [get_cter $segid $thischaintype]
	    lappend chainlengths $residues
#                mol color Name
#                mol representation Lines 1.000
#                mol selection index "[lindex $chainstarts end] to [lindex $chainends end]"
#                mol addrep $currentMol
	    set residues 1
	    set oldres -1
	    puts $out END
	    close $out
	    set newfile 1
	    lappend ctermini [list $segid $oldresname]
	}

	if {$curchain == $oldcurchain} {
	  puts "Current chain: $curchain   Old chain: $oldcurchain"
	  incr segsthischain
	} else {
	  puts "Current chain: $curchain   Old chain: $oldcurchain"
	  set segsthischain 1
	}
      } elseif {($resdif != 0)} {
	# Add this residue to the chain:res->segid and seg:res->segid lookup tables
	lappend chaintoseg [list [list [string index $thisline 21] $curres] $segid]
	incr residues
	lappend segtoseg   [list [list $curseg $curres] $segid]
	set oldres $curres
      }

      # Start a new file	  
      if { $newfile == 1 } {
	incr nseg
	puts "Curwater: $curwater Curprot: $curprot Curnuc: $curnuc Curo: $curo Curglyc: $curglyc"
	# Determine segment type
	if {!$curglyc } {
    set segid {}
  }
      if { $curwater } { 
	  incr nwatseg;
	  set prefix "${curchain}W"
	  set thischaintype 3
	} elseif {$curprot} {
	  incr npseg 
	  set prefix "${curchain}P"
	  set thischaintype 0
	} elseif {$curnuc}  {
	  incr nnseg
	  set prefix "${curchain}N"
	  if {$isrna == 1} {
	    set thischaintype 2
	  } else {
	    set thischaintype 1
	  }
	} elseif {$curglyc} {
	  set segid $curseg
    set prefix "${curchain}O"
	  set thischaintype 4
	} elseif {$curo} {
	  incr noseg
	  set prefix "${curchain}O"
	  set thischaintype 3
	}
	
	if {!$curglyc || $segid == ""} {
	  set segsthischain [expr {[regexp -all "$prefix\[0-9\]+" $seglist] + 1}]  
	  set segid "$prefix${segsthischain}" 
	}
	# Add this residue to the chain:res->segid lookup table
	lappend chaintoseg [list [list $curchain $curres] $segid]
	lappend segtoseg   [list [list $curseg $curres] $segid]
	if {[regexp -all "$segid" $seglist] == 0} {
	  lappend seglist $segid
	}
	lappend chaintypes $thischaintype

	set newname "${fname}_${segid}.pdb"
	set out [open $newname w]
	lappend nters [get_nter $segid $resname $thischaintype]

	lappend chainnames $segid
	lappend chainstarts [expr [lindex $equivindices [expr $firstresindex]] + 1]
	lappend fnamelist $newname
	# set first 1
	set newfile 0
	set newseg 0
	set isrna 0
	set isdna 0
	set oldres $curres
	puts "Segment $nseg: Starting with resid $curres, file $newname"
      } else {
	if {$curnuc} {
	  if {$isdna} {
	    set chaintypes [lreplace $chaintypes end end 1]
	  } else {
	    set chaintypes [lreplace $chaintypes end end 2]
	  }
	}
	set oldres $curres
	set first  0
      }
      foreach line $thisresdat {
	puts $out $line  
      }
      
    }
  
    set last [list]
    lappend last $lineindex
    lappend last [get_cter $segid $thischaintype]
    lappend last $residues
  }
  lappend chainends [expr [lindex $last 0] - 1]
  lappend cters [lindex $last 1]
  lappend chainlengths [expr [lindex $last 2] + 1]
  close $out
  set chaintoseg [lsort -unique -index 0 $chaintoseg]
  set segtoseg [lsort -unique -index 0 $segtoseg]

  set chainlengths [lreplace $chainlengths end end [expr [lindex $chainlengths end] - 1]]


  foreach segname $chainnames length $chainlengths start $chainstarts end $chainends nter $nters cter $cters type $chaintypes {
    switch $type {
      0 {set typestr "Prot "}
      1 {set typestr "DNA  "}
      2 {set typestr "RNA  "}
      3 {set typestr "Water"}
      4 {set typestr "Glyc "}
      default {set typestr "Other"}
    }
    set newstring [format $chainformat $segname $length $start $end $nter $cter $typestr]
    lappend chaintexts $newstring
  } 
  
  

  


  return $fnamelist
}
  
  


############################################################
# Makes some common aliases necessary to properly generate #
# protein and nucleic acid psfs.                           #
############################################################

proc ::autopsf::psfaliases {} {
  # Define common aliases
  # Here's for nucleics
  pdbalias residue G GUA
  pdbalias residue C CYT
  pdbalias residue A ADE
  pdbalias residue T THY
  pdbalias residue U URA
  # Coot residue naming convention
  pdbalias residue Gr GUA
  pdbalias residue Gd GUA
  pdbalias residue Cr CYT
  pdbalias residue Cd CYT
  pdbalias residue Ar ADE
  pdbalias residue Ad ADE
  pdbalias residue Ur URA
  pdbalias residue Td THY
  pdbalias residue DT THY
  pdbalias residue DG GUA
  pdbalias residue DC CYT
  pdbalias residue DA ADE
  # Glycans. Currently only the four common "stem" residues of
  # N-linked glycans are implemented
  pdbalias residue BMA BMAN
  pdbalias residue MAN AMAN
  pdbalias residue FUC AFUC
  pdbalias residue NAG BGLN ;# NOTE: Resname changed from CHARMM-36 standard
                     # to fit the 4-character resname limit of VMD/NAMD
                     
  

  foreach bp { GUA CYT ADE THY URA } {
    pdbalias atom $bp "O5\*" O5'
    pdbalias atom $bp "C5\*" C5'
    pdbalias atom $bp "O4\*" O4'
    pdbalias atom $bp "C4\*" C4'
    pdbalias atom $bp "C3\*" C3'
    pdbalias atom $bp "O3\*" O3'
    pdbalias atom $bp "C2\*" C2'
    pdbalias atom $bp "O2\*" O2'
    pdbalias atom $bp "C1\*" C1'
    pdbalias atom $bp "OP1" O1P
    pdbalias atom $bp "OP2" O2P
  }

  pdbalias atom ILE CD1 CD
  pdbalias atom SER HG HG1
  pdbalias residue HIS HSD

# Heme aliases
  pdbalias residue HEM HEME
  pdbalias atom HEME "N A" NA
  pdbalias atom HEME "N B" NB
  pdbalias atom HEME "N C" NC
  pdbalias atom HEME "N D" ND

# Water aliases
  pdbalias residue HOH TIP3
  pdbalias atom TIP3 O OH2

# Ion aliases
  pdbalias residue K POT
  pdbalias atom K K POT
  pdbalias residue ICL CLA
  pdbalias atom ICL CL CLA
  pdbalias residue INA SOD
  pdbalias atom INA NA SOD
  pdbalias residue CA CAL
  pdbalias atom CA CA CAL
  pdbalias residue ZN ZN2

# Other aliases
  pdbalias atom LYS 1HZ HZ1
  pdbalias atom LYS 2HZ HZ2
  pdbalias atom LYS 3HZ HZ3

  pdbalias atom ARG 1HH1 HH11
  pdbalias atom ARG 2HH1 HH12
  pdbalias atom ARG 1HH2 HH21
  pdbalias atom ARG 2HH2 HH22

  pdbalias atom ASN 1HD2 HD21
  pdbalias atom ASN 2HD2 HD22

}


##################################################################
# Use psfgen to build each segment from $splitsegfiles and read  #
# the coordinates from the same files.                           #
##################################################################

proc ::autopsf::psfsegments {logfileout} {
  variable splitsegfiles
  variable ctermini
  variable autoterm
  variable nters
  variable cters
  variable basename
  variable chainnames
  variable chainlengths
  variable chainstarts
  variable chainends
  variable chaintypes
  variable currentMol
  set nseg 0
  foreach segname $chainnames length $chainlengths start $chainstarts end $chainends nter $nters cter $cters  segfile $splitsegfiles type $chaintypes {
    puts "segfiles $splitsegfiles"
    puts $segfile
    incr nseg
    set tail [string range $segfile [expr [string last "_" $segfile]+1] end]
    set segid ""
    regsub {\.pdb$} $tail "" segid
    set iswater [regexp {^W[0-9]*$} $segid]
    set isother [regexp {^O[0-9]*$} $segid]
    set protnuc [regexp {^P*$|^N*$} $segid]
    set prot [regexp {^P[0-9]*$} $segid]
    set nuc  [regexp {^N[0-9]*$} $segid]

    puts "$start $end"
    puts $logfileout "\#Creating chain $segname: $length residues from indices $start to $end in original file. Patches: Nter $nter, Cter $cter" 	;#"

    # fix the segment names in the original file
    set segsel [atomselect $currentMol "serial $start to $end"]
    $segsel set segname $segname
    $segsel delete


    segment $segid {
      pdb $segfile

      # We alias the C-terminal OXT atoms to OT2 so that psfgen has to guess one atom less.
      # Otherwise psfgen's CTER oxygen guesses do not reproduce the crystal structure exactly
      # It also makes sure that the bonding pattern stays the same.
      if {$prot && $autoterm} {
	# Also, make sure to use the right patches for the n terminus of certain
	# amino acids
	set cterr [lindex [lsearch -inline $ctermini "$segid *"] 1]
	pdbalias atom $cterr OXT OT2
	#set lookfile [open $segfile r]
	#gets $lookfile line
	#gets $lookfile line
	#set firstres [string range $line 17 20]
	#if {$firstres == "GLY "} {first GLYP}
	#if {$firstres == "PRO "} {first PROP}
	#close $lookfile
      }

#      if { $iswater || $isother || !$autoterm } {
#	 first none
#	 last none
#      }

#      if { $nuc && $autoterm } {
#        first 5PHO
#        last 3TER
#      }

      first $nter
      last $cter


      variable mutatehis
      foreach mut [lsearch -inline -all $mutatehis "$segid *"] {
	puts "mutating [lindex $mut 1] [lindex $mut 2]"
	puts $logfileout "\#mutating [lindex $mut 1] [lindex $mut 2]"
	mutate [lindex $mut 1] [lindex $mut 2] 
      }

      variable mutatelist
      foreach mut [lsearch -inline -all $mutatelist "$segid *"] {
        puts "mutating [lindex $mut 1] [lindex $mut 2]"
        puts $logfileout "\#mutating [lindex $mut 1] [lindex $mut 2]"
        mutate [lindex $mut 1] [lindex $mut 2] 
      }
    }
    coordpdb $segfile $segid
    if {$type == 1} {

      apply_dna_patch $segfile $segid
    }

    file delete $segfile $segid
  }
}

proc ::autopsf::get_cter {segid thischaintype} {
	# Return a standard C terminal patch for the given segment type
    set prot [expr {$thischaintype == 0}]
    set nuc  [expr {$thischaintype == 1 || $thischaintype == 2}]

#puts "CTER calc: $nuc $prot"

    if {$nuc} {
	    return "3TER"
    } elseif {$prot} {
	    return "CTER"
    } else {
	    return "none"
    }
}

proc ::autopsf::get_nter {segid resname thischaintype} {
    set prot [expr {$thischaintype == 0}]
    set nuc  [expr {$thischaintype == 1 || $thischaintype == 2}]

    if {$prot} {
	    if {$resname == "GLY"} {
		    return "GLYP"
	    } elseif {$resname == "PRO"} {
		    return "PROP"
	    } else {
		    return "NTER"
	    }

    } elseif {$nuc} {
	    return "5TER"
    } else {
	    return "none"
    }
}


########################################################
# Translate the extra bondlist from chain to segid.    #
########################################################

proc ::autopsf::translate_extrabonds_chain_to_segid {} {
  set tmplist {}
  variable extrabonds
  variable chaintoseg
  variable segtoseg
  foreach bond $extrabonds {
      set atom0 [lindex $bond 0]
      set atom1 [lindex $bond 1]
      set segid0 {}
      set segid1 {}
      if {[lindex $atom0 0]=="chain"} {
	      lappend segid0 [lindex [lsearch -inline $chaintoseg "[list [lrange $atom0 1 2]] *"] 1]
      } else {
	      set segid0 [lindex $atom0 1]
      }

      if {[lindex $atom1 0]=="chain"} {
	      lappend segid1 [lindex [lsearch -inline $chaintoseg "[list [lrange $atom1 1 2]] *"] 1]
      } elseif {[lindex $atom1 0]=="seg"} {
	      lappend segid1 [lindex [lsearch -inline $segtoseg "[list [lrange $atom1 1 2]] *"] 1]
      } else {
	      set segid1 [lindex $atom1 1]
      }

      # Alias C-termini
      if {[lindex $atom0 4]=="OXT"} { lset atom0 4 OT2 }
      if {[lindex $atom1 4]=="OXT"} { lset atom1 4 OT2 }

      #puts "$segid0 [lindex $atom0 2] [lindex $atom0 4] -- $segid1 [lindex $atom1 2] [lindex $atom1 4]"
      lappend tmplist [list [list $segid0 [lindex $atom0 2] [lindex $atom0 4]] [list $segid1 [lindex $atom1 2] [lindex $atom1 4]]]
  }
  variable extrabonds $tmplist
}


######################################################################
# Look for unparametrized atoms (type=XX*).                          #
# If such atoms exist cut out a selection residues containing them   #
# and launch a listbox with the unparametrized residues.             #
# From the listbox you can select residues to delete and rerun       #
# psfgen or parametrize them using PARATOOL.                         #
######################################################################

proc ::autopsf::checkparams {} {
  variable basename
  variable currentMol
  variable tmpmolid  [mol load psf ${basename}_tmpfile.psf pdb ${basename}_tmpfile.pdb]
  variable gui
  variable unparsel [list]; #List of unparameterized selections

  set sel [atomselect $tmpmolid "type \"XX\[A-Z\]+\""]
  set segidlist [lsort -unique [$sel get segid]]
  foreach segid $segidlist {
      set segsel [atomselect $tmpmolid "segid $segid and type \"XX\[A-Z\]+\""]
      set residlist [lsort -unique [$segsel get resid]]
      foreach resid $residlist {
##
##       We must escape the resid name to make autopsf cope with negative resids
##       that show up in PDB files where DNA helices come together.
##       By quoting the resid string, we prevent it from being interpreted
##       as either a malformed regex or a numeric value showing up where it 
##       doesn't belong.
##       Example PDB codes: 3Q5R 3D6Z 3D70 1EXJ
##
	set mysel [atomselect $tmpmolid "segid $segid and resid \"$resid\" and type \"XX\[A-Z\]+\""]
	if {[$mysel num] > 0} {
	    puts "Warning: I found some undefined atom types in $segid:$resid ([lsort -unique [$mysel get resname]])"
      
	    set myindex [$mysel list]
	    #Cut out a selection by first taking everything in the same residue as the
	    #target, then expanding by two bonds, and then taking everything in the
	    #same residue as that
	    
	    set ressel [atomselect $tmpmolid "(same chain as index $myindex) and (same segid as index $myindex) and (same resid as index $myindex)"]
	    if {[regexp {[0-9]} [$ressel getbonds]]} {
	      set ressel [atomselect $tmpmolid "index [$ressel get index] or index [join [$ressel getbonds]]"]
	    }
	    if {[regexp {[0-9]} [$ressel getbonds]]} {
	      set ressel [atomselect $tmpmolid "same residue as (index [$ressel get index] or index [join [$ressel getbonds]])"]
	    }
	    
	    #Now append these indices to the unparsel list, and remove the indices 
	    #we've picked from the list of atoms still needing parameterization
	    
	    lappend unparsel [list [$ressel get index] [lsort -unique [$ressel get resname]] \
				[lsort -unique [$ressel get segid]] [lsort -unique [$ressel get resid]] \
				[$ressel get name]]

	    $ressel delete
	}
      }
      puts $unparsel 
  }    

  if {[$sel num] > 0 && !($gui)} {
      puts "Warning: This molecule contains unparameterized residues."
      puts "Please use the GUI version to begin parameterization."
      return 1
  }
  $sel delete

  if {[llength $unparsel]} {
      variable incomplete 1
      # Launch a GUI that lets you choose from unparametrized fragments
      # The selected fragments can be deleted or paramertized using Paratool.
      #puts "Frag: $unparsel"
      fragment_chooser
      return 1
  } else {
      # everything seems to be fine!
      # Rename the tmpfile to the output filename
      variable incomplete 0
      set tmpfilename ${basename}_tmpfile
      if {[file exists ${tmpfilename}.psf]} { 
	file copy -force  $tmpfilename.psf ${basename}.psf
	file delete $tmpfilename.psf 
      }
      if {[file exists ${tmpfilename}.pdb]} {
	file copy -force  $tmpfilename.pdb ${basename}.pdb
	file delete $tmpfilename.pdb
      }
      if {[file exists ${basename}_modified.pdb]} {
	file delete ${basename}_modified.pdb
	variable paratoolownedmol
	foreach molid [molinfo list] {
	    if {[lsearch $paratoolownedmol $molid]<0 && [molinfo $molid get name]=="${basename}_modified.pdb"} {
	      mol delete $molid
	    }
	}
      }
      mol delete $tmpmolid
  }

  return 0
  
}


##############################################
# This GUI provides a list of unparametrized #
# fragments from which you can choose which  #
# ones you want to sent to Paratool. You can #
# also delete unwanted fragments from the    #
# pdb and rerun psfgen.                      #
##############################################

proc ::autopsf::fragment_chooser {} {
  variable unparsel
  variable fchooserheader "Autopsf has detected [llength $unparsel] unparametrized components."
  variable tmpmolid

  # If already initialized, just turn on
  if {[winfo exists .fchooser]} {
      init_fragmentlist
      wm deiconify .fchooser
      raise .fchooser
      return
  }

  set w [toplevel ".fchooser"]
  wm title $w "Autopsf - Component chooser"
  wm resizable $w no no
  wm protocol .fchooser WM_DELETE_WINDOW { ::autopsf::quit_chooser }

  set selectcolor lightsteelblue
  variable basename

  # initialize the fragmentlist and the highlight reps

  frame $w.frag
  labelframe $w.frag.docu -text "Info" -padx 2m -pady 2m
  label $w.frag.docu.1 -textvariable ::autopsf::fchooserheader -font {-size 10 -weight bold }
  label $w.frag.docu.2 -text "Don't worry, there are several things you can do:"
  label $w.frag.docu.3 -text "1) Load an additional topology file that contains the missing information and rerun psfgen."
  label $w.frag.docu.4 -text "2) Delete the component from your system and rerun psfgen."
  label $w.frag.docu.5 -text "3) Parametrize the unknown components using Paratool."
  pack $w.frag.docu.1  -pady 1m
  pack $w.frag.docu.2 $w.frag.docu.3 $w.frag.docu.4 $w.frag.docu.5 -anchor w
  pack $w.frag.docu -fill x -expand 1 -padx 1m -pady 1m -ipadx 2m

  ############## frame for fragment list #################
  labelframe $w.frag.topo -bd 2 -relief ridge -text "Unparametrized components" -padx 1m -pady 1m
  frame $w.frag.topo.list
  scrollbar $w.frag.topo.list.scroll -command "$w.frag.topo.list.list yview"
  listbox $w.frag.topo.list.list -activestyle dotbox -yscroll "$w.frag.topo.list.scroll set" -font {tkFixed 9} \
      -width 40 -height 4 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
      -listvariable ::autopsf::fragmentlist
  frame  $w.frag.topo.buttons
  button $w.frag.topo.buttons.add -text "Parametrize"  -command [namespace code {
      variable unparsel
      set i [.fchooser.frag.topo.list.list curselection]
      set frag [lindex $unparsel $i]
      set sel [atomselect $tmpmolid "index [join [lindex $frag 0]]"]
      set resname [lindex [$sel get resname] 0]

      $sel set beta 0.2;   # This is used by Paratool!
      $sel set type {\ };  # We need empty type information for Paratool

      if { [catch { $sel writexbgf ${basename}_${resname}_${i}.xbgf } err] } {
	puts "ERROR: Couldn't write temp files. Do you have enough disk space?"
	return 2
      }

      if {$useParatool} {
	variable topfiles
	variable extrabonds
	::Paratool::reset_all 
	::Paratool::paratool -top $topfiles -parentid $tmpmolid -unparsel $sel \
	    -basemol ${basename}_${resname}_${i}.xbgf -extrabonds $extrabonds
	variable paratoolownedmol
	lappend paratoolownedmol $tmpmolid
      } else {
	$sel writepdb ${basename}_${resname}_${i}.pdb
	set ok [tk_messageBox -message "Error: Paratool is not enabled in this build. The coordinates of the unparameterized fragment have been saved to ${basename}_frag${i}.pdb. You can use this to parameterize your segment externally." \
	-icon error -type ok ]
      }

      $sel delete
      return 0
  }]

  button $w.frag.topo.buttons.delete -text "Delete" -command [namespace code {
      variable tmpmolid
      variable unparsel
      variable fragmentlist
      set i [.fchooser.frag.topo.list.list curselection]
      set frag [lindex $unparsel $i]
      set sel [atomselect $tmpmolid "index [join [lindex $frag 0]]"]
      #puts [$sel list]
      $sel set segid NONE
      $sel delete
      set unparsel      [lreplace $unparsel $i $i]
      set fragmentlist  [lreplace $fragmentlist  $i $i]
      mol modstyle [mol repindex $tmpmolid [lindex $repnames $i]] $tmpmolid {VDW 0.0}
      set repnames [lreplace $repnames $i $i]
      mol modstyle [mol repindex $tmpmolid [lindex $repnames $curselection]] $tmpmolid {VDW 1.0}
  }]

  pack $w.frag.topo.buttons.add $w.frag.topo.buttons.delete -expand 1 -side left
  pack $w.frag.topo.list.list -side left -fill both -expand 1
  pack $w.frag.topo.list.scroll -side left -fill both
  pack $w.frag.topo.buttons -side bottom
  pack $w.frag.topo.list -fill both -expand 1

  pack $w.frag.topo -padx 1m -pady 1m -fill both -expand 1

  button $w.frag.rerun -text "Rerun psfgen" -command [namespace current]::rerunpsfgen
  pack $w.frag.rerun -padx 1m -pady 1m -fill x -expand 1

  pack $w.frag

  $w.frag.topo.list.list selection set 0

  init_fragmentlist

  bind $w.frag.topo.list.list <Delete> [namespace code {
      .fchooser.frag.topo.list.buttons.delete invoke
  }]

  bind $w.frag.topo.list.list <<ListboxSelect>> [namespace code {
      variable tmpmolid
      variable repnames
      variable curselection
      mol modstyle [mol repindex $tmpmolid [lindex $repnames $curselection]] $tmpmolid {Licorice 0.5}; #{VDW 0.5}
      mol modstyle [mol repindex $tmpmolid [lindex $repnames [%W curselection]]] $tmpmolid {VDW 1.0}
      set curselection [%W curselection]
  }]

  bind $w <FocusIn> [namespace code {
      if {"%W"==".fchooser" && [winfo exists .fchooser.frag.topo.list.list]} {
	# Restore the selection
	variable curselection
	%W.frag.topo.list.list selection clear 0 end
	foreach i $curselection {
	    %W.frag.topo.list.list selection set $i
	}
	focus .fchooser.frag.topo.list.list
      }
  }]
}

proc ::autopsf::init_fragmentlist {} {
  variable unparsel
  variable tmpmolid
  variable fragmentlist {}
  mol representation {Licorice 0.5}; #{VDW 0.5}
  variable repnames {}
  variable hetnamlist
  variable currentMol

  # Get long names for hetero compounds
  array set hetnamarray $hetnamlist

  set i 1
  foreach frag $unparsel {
      set len [format "%4i" [llength [lindex $frag 0]]]
      set resname [lindex $frag 1]
      set longname [lindex [array get hetnamarray $resname] 1]
      set num [format "%2i" $i]
      lappend fragmentlist "$num: $resname $len atoms, $longname"
      mol selection "index [join [lindex $frag 0]]"
      #puts "$tmpmolid: [join [lindex $frag 0]]"
      mol addrep $tmpmolid
      lappend repnames [mol repname $tmpmolid $i]
      incr i
  }
  variable curselection 0
  mol modstyle [mol repindex $tmpmolid [lindex $repnames $curselection]] $tmpmolid {VDW 1.0}

  foreach mol [molinfo list] {
      if {$mol==$tmpmolid} {
	molinfo $mol set drawn 1
      } else { molinfo $mol set drawn 0 }
  }
  .fchooser.frag.topo.list.list selection set 0
}


#######################################################
# Writes a pdb file that lacks the deleted fragments  #
# (marked by segid NONE). The new pdb is loaded as    #
# a new molecule and psfgen will be run again.        #
#######################################################

proc ::autopsf::rerunpsfgen {} {
  variable tmpmolid
  variable basename
  variable ofrag
  variable oseltext
  if {[lsearch [molinfo list] $tmpmolid] == -1} {
    set ok [tk_messageBox -message "Error: You already deleted the molecule you were working on" \
	-icon error -type ok ]
    wm state .fchooser withdrawn
    quit_chooser
    set tmpmolid -1
    return
  }

  variable paratoolownedmol
  foreach molid [molinfo list] {
      if {[lsearch $paratoolownedmol $molid]<0 && [molinfo $molid get name]=="${basename}_modified.pdb"} {
	mol delete $molid
      }
  }
  set sel [atomselect $tmpmolid "not segid NONE"]
  $sel writepdb ${basename}_modified.pdb
  $sel delete
  set newmolid [mol load pdb ${basename}_modified.pdb]
  variable currentMol $newmolid
  set tmpfilename ${basename}_tmpfile
  if {[file exists ${tmpfilename}.psf]} { file delete $tmpfilename.psf }
  if {[file exists ${tmpfilename}.pdb]} { file delete $tmpfilename.pdb }

  catch {file copy -force ${basename}.pdb ${basename}-temp.pdb}
  
  # This is needed to avoid problems when running from the GUI.
  # runpsfgen sets ofrag to true if $oseltext returns a non-empty
  # string. Since upon initialisation the GUI sets oseltext to
  # "protein or nucleic" the net result is that osel will always
  # be true, and all other residues will be stripped from the final
  # file.

  if {!$ofrag} {
    set oseltext ""
  }
  
  
  
  runpsfgen
}

######################################################
# Recalculate the bonds based on the atom distance.  #
# VMD's bondlist and zmat will be updated.           #
# Angles and dihedrals containing deleted bonds are  #
# not removed.                                       #
######################################################

proc ::autopsf::recalculate_bonds { sel {maxbondlength 1.6}} {

  set vmdbondlist {}
  foreach pos1 [$sel get {x y z}] i [$sel get index] {
      set sublist {}
      foreach pos2 [$sel get {x y z}] j [$sel get index] {
	set dist [veclength [vecsub $pos1 $pos2]]
	if {$dist<$maxbondlength && $i!=$j} {
	    lappend sublist $j
	}
      }
      lappend vmdbondlist $sublist
  }

  $sel setbonds $vmdbondlist
}

################################################
# Function for quitting the chooser.           #
# Currently it doesn't do very much.           #
################################################

proc ::autopsf::quit_chooser {} {
  after idle destroy .fchooser

  # Delete the tmp molecule that contains the unknown types
  variable tmpmolid
  variable paratoolownedmol
  if {[lsearch $paratoolownedmol $tmpmolid]<0} {
      # Delete the tmp molecule and set currentMol drawn.
      if {[lsearch [molinfo list] $tmpmolid]>=0} { mol delete $tmpmolid }
      variable currentMol
#      molinfo $currentMol set drawn 1

      # If the build wasn't complete we should destroy the tmpfiles!
      variable basename
      set tmpfilename ${basename}_tmpfile
      if {[file exists ${tmpfilename}.psf]} { file delete $tmpfilename.psf }
      if {[file exists ${tmpfilename}.pdb]} { file delete $tmpfilename.pdb }
  }
}


proc ::autopsf::cleanup {} {
  # These were temp files for splitting the pdb and for checktop

  variable basename
  variable tempMol
  foreach tempfile [glob -nocomplain ${basename}-temp* ${basename}*modified* ${basename}_preformat*] { file delete $tempfile }
  mol delete $tempMol


  # If the molecule hasn't been taken over by Paratool, we will delete the files
  variable incomplete
  variable tmpmolid
  variable paratoolownedmol
  if {[lsearch $paratoolownedmol $tmpmolid]<0 && $incomplete} {
      variable basename
      set tmpfilename ${basename}_tmpfile
      if {[file exists ${tmpfilename}.psf]} { file delete $tmpfilename.psf }
      if {[file exists ${tmpfilename}.pdb]} { file delete $tmpfilename.pdb }
      if {[lsearch [molinfo list] $tmpmolid]>=0} { mol delete $tmpmolid }
      variable currentMol
      molinfo $currentMol set drawn 1
      variable vdwrepindex
      mol delrep $vdwrepindex $currentMol
  }
}


# Read the SSBOND record from a pdb file and returns
# a list containing the disulfide bridge infos
# (Currently unused proc)
proc ::autopsf::read_pdb_ssbonds { file } {
  set ssbondlist {}
  set fid [open $file r]
  while {![eof $fid]} {
      set line [gets $fid]
      if {[string equal "SSBOND" [lindex $line 0]]} {
	set resname1 [string trim [string range $line 11 13]]
	set chain1   [string index $line 15]
	set resid1   [string trim [string range $line 17 20]]
	set resname2 [string trim [string range $line 25 27]]
	set chain2   [string index $line 29]
	set resid2   [string trim [string range $line 31 34]]
	lappend ssbondlist [list $resname1 $chain1 $resid1 $resname2 $chain2 $resid2]
      }
  }
  return $ssbondlist;
}

# Finds the SS-bonds based on the S-S distance
# Used in proc psfmain {}.
proc ::autopsf::find_ssbonds { {dist 3.0} } {
  puts "Determine S-S bonds based on distance <${dist}A"
  variable currentMol
  set ssbonds [list]
  set sel [atomselect $currentMol "resname CYS and name SG"]
  foreach sg [$sel get {index segid segname chain resid}] {
      foreach { index segid segname chain resid } $sg { break } 
      set segkey seg
      set segment $segname
      if {![llength $segment]} {
	set segkey chain
	set segment $chain
      }
      if {![llength $segment]} { 
	      set segkey segid
	      set segment $segid
      }

      set sel2 [atomselect $currentMol "resname CYS and name SG and (not same residue as index $index) and index > $index and exwithin 3.0 of index $index"]
      if {![$sel2 num]} { continue }

      foreach sg2 [$sel2 get {segid segname chain resid}] {
	    foreach { segid2 segname2 chain2 resid2 } $sg2 { break }
      set segkey2 seg
      set segment2 $segname2
      if {![llength $segment2]} {
	      set segkey2 chain
	      set segment2 $chain2
      }
	    if {![llength $segment2]} { 
	      set segkey2 segid
	      set segment2 $segid2
	    }
	    lappend ssbonds [list $segkey $segment $resid $segkey2 $segment2 $resid2]
      break
    }
  }

  return $ssbonds
}

proc ::autopsf::make_glycan_patches { {dist 2.0} } {
  variable currentMol
  variable qwikmd
  set linklist ""
  set glycanbonds ""
  set C1list [list] 
  set glycannames {AMAN BMAN AFUC BGLN MAN BMA FUC NAG AGLC BGLC AALT BALT AALL BALL AGAL BGAL AGUL BGUL AIDO BIDO ATAL BTAL AXYL BXYL AFUC BFUC ARHM BRHM}
  if {!$qwikmd} {
    set C1sel [atomselect $currentMol "(resname $glycannames) and name C1"]
  } else {
    set C1sel [atomselect $currentMol "qwikmd_glycan and name C1"]
  }
  
  puts [$C1sel get index]
  foreach Cindex [$C1sel get index] {
    set thisC [atomselect $currentMol "index $Cindex"]
    lappend C1list [lindex [$thisC get {resname chain segname resid index}] 0]
    $thisC delete
  }
  $C1sel delete
  foreach entry $C1list {
    set C1 [lindex $entry 4]
    puts "Resname: [lindex $entry 0] Chain: [lindex $entry 1] Segname [lindex $entry 2] Resid [lindex $entry 3] Index [lindex $entry 4]"
    set linkatom [atomselect top "name O1 O2 O3 O4 O6 ND2 and within $dist of index $C1"]
#    puts "Glycan $entry is within $dist of [$linkatom get {resname chain segname resid name}]"
    if { [$linkatom get index] != "" } {
      lappend linklist [lindex [$linkatom get {resname chain segname resid name}] 0]
    } else {
      lappend linklist "None"
    }
    $linkatom delete
  }
  foreach C1entry $C1list linkentry $linklist {
    foreach { currentresname currentchain currentsegname currentresid currentindex } $C1entry {break}
    if { $linkentry == "None" } {
      puts "WARNING: glycan residue $currentresname $currentsegname:$currentresid has no link at reducing terminus"
      continue
    }
    foreach { linkresname linkchain linksegname linkresid linkname } $linkentry {break}
puts " $currentresname $currentchain $currentsegname $currentresid $currentindex; \
	$linkresname $linkchain $linksegname $linkresid $linkname"
    if {[regexp {AMAN|AFUC|AGLC|AALT|AALL|AGAL|AGUL|AIDO|ATAL|AXYL|ARHM|ADEO|ARIB|AARB|ALYF|AXYF|MAN|FUC} $currentresname] } { ;# put all alpha-1 carbohydrate residues here
	set dir1 "a"
    } else {
	set dir1 "b"
    }
    set link2num 0  ; # to catch case of an unlinked glycan
    set protlink 0
    if {$linkname == "ND2"} {
	set protlink 1
    } elseif {$linkname == "O2"} {
	set link2num 2
	if { [ regexp {AMAN|BMAN|MAN|BMA|AALT|BALT|ARHM|BRHM|AIDO|BIDO|ATAL|BTAL} $linkresname] } { ;# put all residues with an axial O2 here
	    set dir2 "a"
	} else {
	    set dir2 "b"
	}
    } elseif {$linkname == "O3"} {
	set link2num 3
	if {[regexp {AALT|BALT|AALL|BALL|AGUL|BGUL|AIDO|BIDO} $linkresname] != -1} { ;# put all residues with an axial O3 here
	    set dir2 "a"
	} else {
	    set dir2 "b"
	}
    } elseif {$linkname == "O4"} {
	set link2num 4
	if { [regexp {AFUC|BFUC|FUC|AGAL|BGAL|AGUL|BGUL|AIDO|BIDO|ATAL|BTAL} $linkresname] } { ;# put all residues with an axial O4 here
	    set dir2 "a"
	} else {
	    set dir2 "b"
	}
    } elseif {$linkname == "O6"} {
	set link2num 6
	set dir2 "b"
    }
    set segkey1 "seg"
    set segment1 $currentsegname
    if {![llength $segment1]} {
      set segkey1 "chain"
      set segment1 $currentchain
    }
    
    set segkey2 "seg"
    set segment2 $linksegname
    if {![llength $segment1]} {
      set segkey2 "chain"
      set segment2 $linkchain
    }
    
    set patch ""
    if {$protlink} {
      set patch "NGLB"
    } elseif { $link2num } {
      set patch "1$link2num$dir1$dir2"
    } else { 
      puts "WARNING: glycan residue $currentresname $currentsegname:$currentresid has no link at reducing terminus"
      continue
    }
    
    lappend glycanbonds [list $segkey2 $segment2 $linkresid $segkey1 $segment1 $currentresid $patch]
    
  }

  return $glycanbonds
    
}


proc ::autopsf::get_pdb_hetnam { molid } {
  set hetnamlist {}
  set remarks [split [molinfo $molid get remarks] "\n"]
  foreach line $remarks {      
      if {[string equal "HETNAM" [string range $line 0 5]]} {
	set resname [lindex $line 1]
	set longname [lrange $line 2 end]
	lappend hetnamlist $resname $longname
      }
  }
  return $hetnamlist
}

proc ::autopsf::read_pdb_conect { file molid } {
  variable gui
  puts "Reading PDB CONECT records..."
  #Check if we're using something loaded from the pdb
  if {[molinfo $molid get filetype] == "webpdb"} {
      #Download the file locally
      set pdbcode [molinfo $molid get accession]
      set pdbfile "$pdbcode-tmp-autopsf-conrecords.pdb"

      # Adapted to new PDB website layout, which changed on 1/1/2006
      set url [format "http://www.rcsb.org/pdb/downloadFile.do?fileFormat=pdb&compression=NO&structureId=%s" $pdbcode]

      puts "Downloading PDB file from URL:\n  $url"
  
      vmdhttpcopy $url $pdbfile
    
      if {[file exists $pdbfile] > 0} {
	if {[file size $pdbfile] > 0} {
	  puts "PDB download complete."
	} else {
	  file delete -force $pdbfile
	  puts "Failed to download PDB file."
	}
      } else {
	puts "Failed to download PDB file."
      }

      set frompdb true
      set file "$pdbfile"
    } else {
      set frompdb false
    }

  if {[file exists $file] <= 0} {
    if {$gui} {
	set findfile [tk_dialog .dei "Couldn't find original PDB" "Do you want to specify the location of the original coordinate file?" questhead 0 Yes No]
	if {$findfile == 0} {
	  set file [tk_getOpenFile]
	}
    }

    if {[file exists $file] <= 0} {
      puts "Warning: I couldn't find the original pdb to assign connectivity\nUsing autogenerated connectivity only"
      return
    }
  }

  set fid [open $file r]
  set data [read -nonewline $fid]
  close $fid

  if {$frompdb == true} {
      file delete -force $file
  }

  set indextrans {}
  set bondlist {}
  set modelone 1
  set i 0
  foreach line [split $data \n] {
      set keyword [string trim [string range $line 0 5]]
      if {[string equal "ENDMDL" $keyword]} { set modelone 0 }
      if {$modelone && ([string equal "ATOM" $keyword] || [string equal "HETATM" $keyword])} {
	lappend indextrans [string trim [string range $line 6 10]] $i
	incr i
	continue
      }
      
      if {[string equal "CONECT" [string range $line 0 5]]} {
	set index [string trim [string range $line 6 10]]
	set bond1 [string trim [string range $line 11 15]]
	set bond2 [string trim [string range $line 16 20]]
	set bond3 [string trim [string range $line 21 25]]
	set bond4 [string trim [string range $line 26 30]]
	set bonds [join [join [list $bond1 $bond2 $bond3 $bond4]]]
	set pos [lsearch $bondlist {$index *}]
#   puts "$pos $index | $bonds"
	if {$pos<0} {
	    lappend bondlist [list $index $bonds]
	} else {
#     puts "$pos $index"
	    lset bondlist $pos $index [join [list [lindex $bondlist $pos 1] $bonds]]
	}
      }
  }

  atomselect macro transitionmetal "((atomicnumber>=21 and atomicnumber<=31) or (atomicnumber>=39 and atomicnumber<=50) or (atomicnumber>=57 and atomicnumber<=84) or (atomicnumber>=89))"
  variable currentMol
  variable extrabonds {}
  variable mutatehis {}
  variable cysironbondlist {}
  array set translation $indextrans
  foreach entry $bondlist {
      set index [lindex $entry 0]
      set ind0 [lindex [array get translation $index] 1]
      foreach bond [lindex $entry 1] {
	set ind1 [lindex [array get translation $bond] 1]
  #puts "$ind0 $ind1 $molid"
	::Paratool::vmd_addbond $ind0 $ind1 $molid -2.0;
	set sel0 [atomselect $molid "index $ind0"]
	set sel1 [atomselect $molid "index $ind1"]
	set atom0 [join [$sel0 get {resid resname name}]]
	set atom1 [join [$sel1 get {resid resname name}]]
  # Get a segment key -- try segname first, then chain, then default
  set segkey0 seg
  set segment0 [join [$sel0 get segname]]
	if {![llength $segment0]} { 
	  set segkey0 chain
	  set segment0 [join [$sel0 get chain]]
	}
	if {![llength $segment0]} { 
	    set segkey0 segid
	    set segment0 [join [$sel0 get segid]]
	}

  set segkey1 seg
  set segment1 [join [$sel0 get segname]]
	if {![llength $segment1]} { 
	  set segkey1 chain
	  set segment1 [join [$sel1 get chain]]
  }
	if {![llength $segment1]} { 
	    set segkey1 segid
	    set segment1 [join [$sel1 get segid]]
	}

  puts "CYSD LIST: $segkey0 | $segment0 || $segkey1 | $segment1"
	if {$segment0!=$segment1 || [lindex $atom0 0]!=[lindex $atom1 0]} {
	    # Extrabonds are bonds between different residues, e.g. in complexes
	    set a0 [join [list $segkey0 $segment0 $atom0]] 
	    set a1 [join [list $segkey1 $segment1 $atom1]]
	    # Only add bonds, if its reverse dosn't exist yet
	    if {[lsearch $extrabonds [list $a1 $a0]]<0} {
	      lappend extrabonds [list $a0 $a1]
	    }

	    set atomnum0 [join [$sel0 get atomicnumber]]
	    set atomnum1 [join [$sel1 get atomicnumber]]

	    # Find Cys-iron bonds
	    set cys {}
	    set iron {}
	    if {([lrange $atom0 1 2]=="CYS SG" && $atomnum1==26)} {
	      set cys  [join [list $segkey0 $segment0 $atom0]]
	      set iron [join [list $segkey1 $segment1 $atom1]] 
	    } elseif {([lrange $atom1 1 2]=="CYS SG" && $atomnum0==26)} {
	      set cys  [join [list $segkey1 $segment1 $atom1]] 
	      set iron [join [list $segkey0 $segment0 $atom0]]
	    }
	    
      puts "Adding: $cys | $iron"
	    if {[llength $cys] && [llength $iron]} {
	      lappend cysironbondlist [list $cys $iron]
	    }

	    # Find HIS-metal bonds:
	    # Looking for resid HIS and depending on the atomtype of the complex-bond 
	    # forming atom (ND1|NE2) the residue will later be aliased to HSE or HSD.
	    # $mutatehis is a list containing info about which HIS has to be mutated into what.
	    # Format: {chain|segid $segid $resid HSE|HSD}
	    if {($atomnum1>=21 && $atomnum1<=31) || ($atomnum1>=29 && $atomnum1<=50) || 
	($atomnum1>=57 && $atomnum1<=84) || $atomnum1>=89} {
	if {[lrange $atom0 1 2]=="HIS ND1"} {
	    lappend mutatehis [list $segkey0 $segment0 [lindex $atom0 0] HSE]
	}
	if {[lrange $atom0 1 2]=="HIS NE2"} {
	lappend mutatehis [list $segkey0 $segment0 [lindex $atom0 0] HSD]
	}
      }
      if {($atomnum0>=21 && $atomnum0<=31) || ($atomnum0>=29 && $atomnum0<=50) || 
      ($atomnum0>=57 && $atomnum0<=84) || $atomnum0>=89} {
	if {[lrange $atom1 1 2]=="HIS ND1"} {
	  lappend mutatehis [list $segkey1 $segment1 [lindex $atom1 0] HSE]
	}
      if {[lrange $atom1 1 2]=="HIS NE2"} {
	lappend mutatehis [list $segkey1 $segment1 [lindex $atom1 0] HSD]
      }
      }
    }
    }
}
}

proc ::autopsf::get_pdb_conect { molid } {
  set remarks [split [molinfo $molid get remarks] "\n"]
  set indextrans {}
  set bondlist {}
  set i 0
  foreach line $remarks {      
      if {[string equal "CONECT" [string range $line 0 5]]} {
	set index [string trim [string range $line 6 10]]
	set bond1 [string trim [string range $line 11 15]]
	set bond2 [string trim [string range $line 16 20]]
	set bond3 [string trim [string range $line 21 25]]
	set bond4 [string trim [string range $line 26 30]]
	set bonds [join [join [list $bond1 $bond2 $bond3 $bond4]]]
	set pos [lsearch $bondlist {$index *}]
	if {$pos<0} {
	    lappend bondlist [list $index $bonds]
	} else {
	    lset bondlist $pos $index [join [list [lindex $bondlist $pos 1] $bonds]]
	}
      }
  }

  variable currentMol
  array set translation $indextrans
  foreach entry $bondlist {
      set index [lindex $entry 0]
      set atom0 [lindex [array get translation $index] 1]
      foreach bond [lindex $entry 1] {
	set atom1 [lindex [array get translation $bond] 1]
	puts "::Paratool::vmd_addbond $atom0 $atom1"
	::Paratool::vmd_addbond $atom0 $atom1 $molid; #currentMol
      }
  }
}

#proc ::autopsf::makepsfcontext {} {
#  variable psfcontext
#  set psfcontext 
#}

proc ::autopsf::setnewindices {} {
  variable selforchain
  variable currentMol
  variable newchain_start
  variable newchain_end

  set sel [atomselect $currentMol "$selforchain"]
  set indexlist [$sel get index]
  $sel delete

  set last [lindex $indexlist 0]
  set first $last
  set indexlist [lreplace $indexlist 0 0]
  foreach index $indexlist {
    incr last
    if {$index != $last} {
      tk_messageBox -icon error -type ok -title Error -message "Invalid chain definition: there was a gap between index [expr $last - 1] and $index. Please define your chain using a continuous selection."
      return 1
    }
  }

  incr first
  incr last
  set newchain_start $first
  set newchain_end $last
  return 0
}

# Apply patches to a segment needed to transform RNA to DNA
proc ::autopsf::apply_dna_patch {infile segname} {
  variable charmm36

  set currtop [molinfo top]
  set tempmol [mol new $infile]
  set sel [atomselect top {name 'O3*' or name O3'}]

  set i 0
  foreach resid [$sel get resid] resname [$sel get resname] {
    if { [regexp {CYT|^C$|^Cd$|^DC$|THY|^T$|^Td$|^DT$} $resname] } {
    # if {$resname == "CYT" || $resname == "THY" || $resname == "T" || $resname == "C" || $resname == "Cd" || $resname == "Td"} {}
      if $charmm36 {
        if {$i == 0} {
          patch DEO5 $segname:$resid
        } else {
          patch DEOX $segname:$resid
        }
      } else {
        patch DEO1 $segname:$resid
      }
    }
    if { [regexp {ADE|^A$|^Ad$|^DA$|GUA|^G$|^Gd$|^DG$} $resname] } {
    # if {$resname == "ADE" || $resname == "GUA" || $resname == "A" || $resname == "G" || $resname == "Ad" || $resname == "Gd"} {}
      if $charmm36 {
        if {$i == 0} {
          patch DEO5 $segname:$resid
        } else {
          patch DEOX $segname:$resid
        }
      } else {
        patch DEO2 $segname:$resid
      }
    }
    incr i
  }

  mol top $currtop
  mol delete $tempmol
  $sel delete
}

proc ::autopsf::update_newchain_text { args } {
  variable newchain_type
  variable newchain_type_text

  switch $newchain_type {
    0 {set newchain_type_text "Prot "}
      1 {set newchain_type_text "DNA  "}
      2 {set newchain_type_text "RNA  "}
      default {set newchain_type_text "Other"}
    }
}

proc ::autopsf::update_patchtexts {} {
  variable patchtexts
  variable patchlist

  set patchtexts [list]
  set patchformat3 "%-5s  %5s:%-5i"
  set patchformat5 "%-5s  %5s:%-5i  %5s:%-5i"
  foreach patch $patchlist {
  set mylength [llength $patch]
  if {$mylength == 3} {
    lappend patchtexts [format $patchformat3 [lindex $patch 0] [lindex $patch 1] [lindex $patch 2]]
  } elseif {$mylength == 5} {
    lappend patchtexts [format $patchformat5 [lindex $patch 0] [lindex $patch 1] [lindex $patch 2] [lindex $patch 3] [lindex $patch 4]]
  } 
}

}

#Proc to add a new patch

proc ::autopsf::addpatch_gui {} {
	variable newpatch_name ""
	variable newpatch_seg1 ""
	variable newpatch_res1 ""
	variable newpatch_seg2 ""
	variable newpatch_res2 ""

	if {[winfo exists .patchadder]} {
	  wm deiconify .patchadder
	  raise .patchadder
	  return
	}

	set w [toplevel ".patchadder"]
	wm title $w "Autopsf - Add Patch"
	wm resizable $w no no

	set row 0
	#Basic Information
	frame $w.top
	label $w.top.namelabel -text "Patch type: "
	entry $w.top.name -textvariable [namespace current]::newpatch_name
	label $w.top.seg1label -text "Segment 1: "
	entry $w.top.seg1 -textvar [namespace current]::newpatch_seg1
	label $w.top.res1label -text "Residue 1: "
	entry $w.top.res1 -textvar [namespace current]::newpatch_res1
	frame $w.bottom
	label $w.bottom.seg2label -text "Segment 2: (opt)"
	entry $w.bottom.seg2 -textvar [namespace current]::newpatch_seg2
	label $w.bottom.res2label -text "Residue 2: (opt)"
	entry $w.bottom.res2 -textvar [namespace current]::newpatch_res2
	pack $w.top.namelabel $w.top.name $w.top.seg1label $w.top.seg1 $w.top.res1label $w.top.res1 -side left
	pack $w.bottom.seg2label $w.bottom.seg2 $w.bottom.res2label $w.bottom.res2 -side left


	#Frame for buttons
	frame $w.buttons
	button $w.buttons.addpatch -text "Add patch" -command [namespace current]::addpatch
	button $w.buttons.cancel -text "Done" -command "after idle destroy $w"
	pack $w.buttons.addpatch $w.buttons.cancel -side left

	pack $w.top $w.bottom $w.buttons

}

proc ::autopsf::addpatch {} {

  variable patchlist
  variable newpatch_name
  variable newpatch_seg1
  variable newpatch_res1
  variable newpatch_seg2
  variable newpatch_res2

  if {$newpatch_seg2 == "" || $newpatch_res2 == ""} {
    set newpatch [list $newpatch_name $newpatch_seg1 $newpatch_res1]
  } else {
    set newpatch [list $newpatch_name $newpatch_seg1 $newpatch_res1 $newpatch_seg2 $newpatch_res2]
  }
  
  lappend patchlist $newpatch
  update_patchtexts
}

#Delete the selected patch from the list
proc ::autopsf::delpatch_gui {} {
  variable patchlist
  variable w

  set patchsellist [lreverse [$w.patches.list.list curselection]]

  foreach patchind $patchsellist {
    set patchlist [lreplace $patchlist $patchind $patchind]
  }
  update_patchtexts
}

# maintain the current selected fragment in the gui
proc ::autopsf::update_fragtypes { args } {
  variable frags
  variable allfrag
  variable pfrag
  variable nfrag
  variable ofrag

  set allfrag false
  set ofrag false
  set nfrag false
  set pfrag false

  switch $frags {
    all { set allfrag true }
    psel {set pfrag true}
    nsel {set nfrag true}
    osel {set ofrag true}
  }

}

proc ::autopsf::resetpsf_autopsf {} {
  # run resetpsf and initialize anything that is necessary
  
  
  variable casesen
  resetpsf

  if $casesen {
    psfcontext mixedcase
  }
}
