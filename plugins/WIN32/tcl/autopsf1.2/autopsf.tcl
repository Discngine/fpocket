##
## Automatic PSF Builder Plugin
##
## Authors: Peter Freddolino, John Stone, Jan Saam
##          vmd@ks.uiuc.edu
##
## $Id: autopsf.tcl,v 1.106 2007/07/12 22:40:04 petefred Exp $
##
## Home Page:
##   http://www.ks.uiuc.edu/Research/vmd/plugins/autopsf
##
package require readcharmmtop
package require psfgen
package require solvate
package require autoionize
package require paratool
package require psfcheck
package provide autopsf 1.2


namespace eval ::autopsf:: {
   namespace export autopsf
   
   #define package variables
   variable basename   "autopsf";  # default output prefix
   variable patchlist  {};         # List of user defined patches
   variable ssbondlist {};         # List of distance based S-S bonds
   variable extrabonds {};         # List of bonds from CONECT 
   variable mutatehis  {};         # List protonation types for metal bound histidines
   variable cysironbondlist {};    # List of cysteine-iron bonds
   variable chaintoseg {};         # pairlist that matches chain identifiers with segids
   variable segtoseg {};           # pairlist that matches input segment identifiers with segids
   variable hetnamlist {};         # List of long names for hetero compounds from orig. PDB
   variable zerocoord  {};         # List of atoms located at the origin.
   variable oseltext   "";         # User provided selection text. This part will be built by psfgen. 
   variable regenall false;        # If true, we'll run regenerate angles dihedrals
   variable nofailedguess false;
   variable allfrag  true;
   variable pfrag    false;
   variable ofrag    false;
   variable nfrag    false;
   variable water    false;
   variable ionize   false;
   variable nuctype RNA ;
   variable guess    true;
   variable autoterm true;        # Automatically apply terminal patches.
   variable useParatool   true;   # This flag is for debugging only.
   variable nullMolString "none"; # When no molecule is loaded use this string in the GUI option menu
   variable currentMol    "none"; # molid of the currently selected molecule
   variable tmpmolid      -1;     # molid of the molecule built by psfgen
   variable paratoolownedmol {};  # If this contains $tmpmolid then its ownership has changed to Paratool
   variable topfiles      {};     # List of user specified topology files
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
   variable guistep 0
   variable splitonly false

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
  variable regenall false
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
       set regenall true
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
       set nofailedguess true
       set arglist [lreplace $arglist $argnum $argnum]
       continue
    }
    if {$i == "-gui"}     {
       set gui true
       set arglist [lreplace $arglist $argnum $argnum]
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
	     lappend patchlist $j;
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
  lappend topfiles [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
  psfcontext new delete
}


proc ::autopsf::autopsf_gui {} {
  variable w
  variable selectcolor
  variable gui true
  variable chaintexts
  

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
  $w.menubar.help config -width 5
  pack $w.menubar.options -side left
  pack $w.menubar.help -side right

  
  # Main options menu
  menu $w.menubar.options.menu -tearoff no
  $w.menubar.options.menu add radiobutton -label "Psfgen options" -indicatoron false -font {-weight bold}
  $w.menubar.options.menu add checkbutton -label "Regenerate angles/dihedrals"   -variable [namespace current]::regenall
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
      -width 55 -height 3 -setgrid 1 -selectmode browse -selectbackground $selectcolor \
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
  grid [checkbutton $w.sels.allfrag -text "Everything" -width 9 -variable [namespace current]::allfrag] -row $irow -column 0 -sticky ew
  grid [checkbutton $w.sels.pfrag -text "Protein" -width 9 -variable [namespace current]::pfrag] -row $irow -column 1 -sticky w
  grid [checkbutton $w.sels.nfrag -text "Nucleic Acid" -width 13 -variable [namespace current]::nfrag] -row $irow -column 2 -sticky w
#  grid [radiobutton $w.sels.rna -text "RNA" -width 5 -value "RNA" -variable [namespace current]::nuctype] -row $irow -column 2 -sticky ew
#  grid [radiobutton $w.sels.dna -text "DNA" -width 5 -value "DNA" -variable [namespace current]::nuctype] -row $irow -column 3 -sticky ew 
incr irow


  grid [checkbutton $w.sels.other -text "Other:" -width 13 -variable [namespace current]::ofrag] -row $irow -column 0 -sticky w
  grid [entry $w.sels.osel -textvariable [namespace current]::oseltext] -row $irow -column 1 -columnspan 2 -sticky ew
  incr irow
  grid [button $w.sels.next -text "Guess and split chains using current selections" -command [namespace current]::aftersels_gui] -column 0 -columnspan 4 -sticky ew
  incr row

#Frame for inspecting chains
   variable formattext " Name Length  Index  Range Nter Cter Type" 
   grid [labelframe $w.chains -bd 2 -relief ridge -text "Step 3: Chains Identified" -padx 1m -pady 1m] -row $row -column 0 -columnspan 4 -sticky nsew
   label $w.chains.label -font {tkFixed 9} -textvariable [namespace current]::formattext -relief flat -bd 2 -justify left
   frame $w.chains.list
   scrollbar $w.chains.list.scroll -command "$w.chains.list.list yview"
   listbox $w.chains.list.list -activestyle dotbox -yscroll "$w.chains.list.scroll set" -font {tkFixed 9} \
      -width 45 -height 5 -setgrid 1 -selectmode extended -selectbackground $selectcolor \
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
  label $w.patches.label -font {tkFixed 9} -textvar [namespace current]::patchformattext -relief flat -bd 2 -justify left
  frame $w.patches.list
  scrollbar $w.patches.list.scroll -command "$w.patches.list.list yview"
  listbox $w.patches.list.list -activestyle dotbox -yscroll "$w.patches.list.scroll set" -font {tkFixed 9} -width 45 -height 5 -setgrid 1 -selectmode extended -selectbackground $selectcolor -listvariable [namespace current]::patchtexts
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
   set allfrag 0
   set nfrag 0
   set ofrag 0
   set osel ""
   set nuctype "RNA"
}

proc ::autopsf::reset_gui {} {
   global env
   variable topfiles
   variable patchlist
   set patchlist [list]
   set topfiles [list]
   lappend topfiles [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
   global pfrag
   global nfrag
   global allfrag
   global ofrag
   global osel
   global nuctype
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
   set pfrag 0
   set allfrag 1
   set nfrag 0
   set ofrag 0
   set osel ""
   set nuctype "RNA"
   variable guistep
   resetpsf
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
   resetpsf

   puts "WORKING ON: $currentMol"
   if {[write_selection_tempfiles $currentMol] != 0} { return 2 }

   # Run psfcheck on the molecule to generate a temporary topology file
   # containing entries for unknown RESIs. It will be needed to build a
   # structure with psfgen since psfgen would choke on unknown residue names.
   if {[checktop] != 0} { return 2 }

   variable basename
   variable currentMol
   variable ssbondlist
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

  #Open log file
  set logfileout [open "${basename}.log" "w"]

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
      } elseif {[lindex $ssbond 0]=="seg"} {
	      set seg1 [lindex [lsearch -inline $segtoseg "{[lrange $ssbond 1 2]} *"] 1]
	      set seg2 [lindex [lsearch -inline $segtoseg "{[lrange $ssbond 4 5]} *"] 1]
      } else {
	      set seg1 [lindex $ssbond 1]
	      set seg2 [lindex $ssbond 4]
      }

#      puts $logfileout "patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]"
#      patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]
#      array set newpatch {patchname "DISU" seg1 $seg1 res1 [lindex $ssbond 2] seg2 $seg2 res2 [lindex $ssbond 5]}
      set newpatch [list "DISU" $seg1 [lindex $ssbond 2] $seg2 [lindex $ssbond 5]]
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
   variable patchlist
   variable logfileout

   #apply patches
   foreach patch $patchlist {
     set mylength [llength $patch]
     if {$mylength == 5} {
       puts $logfileout "Applying patch: [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2] [lindex $patch 3]:[lindex $patch 4]"
       eval "patch [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2] [lindex $patch 3]:[lindex $patch 4]"
     } elseif {$mylength == 3} {
       puts $logfileout "Applying patch: [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2]"
       eval "patch [lindex $patch 0] [lindex $patch 1]:[lindex $patch 2]"
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
		  puts $logfile "Deleting atom $segid:$resid $atom with unspecified coordinates."
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
   }
   #close $logfileout
   clean_tempfiles
}

#Proc to clean up temp files
proc ::autopsf::clean_tempfiles {} {
   variable basename
   foreach tempfile [glob -nocomplain ${basename}-temp* ${basename}*modified*] { file delete $tempfile }
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
   resetpsf

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
   
   puts "WORKING ON: $currentMol"
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

  #Open log file
  set logfileout [open "${basename}.log" "w"]

  puts $logfileout "\#Original PDB file: \n\#PDBSTART"
  set pdbfileold [open "${basename}-temp.pdb" "r"]
  puts $logfileout [read $pdbfileold]
  close $pdbfileold
  puts $logfileout "\#PDBEND"

   # Build the segments
   psfsegments $logfileout

   # Apply the used specified patches
   variable patchlist
   variable segtoseg
   foreach userpatch $patchlist {
   #   set patch [lindex $userpatch 0]
   #   foreach segres [lrange $userpatch 1 end] {
	 #set newseg [lindex [lsearch -inline $segtoseg "{[split $segres :]} *"] 1]
	 #puts $logfileout "\#Applying patch $newseg:[lindex [split $segres :] 1]"
	 #append patch " $newseg:[lindex [split $segres :] 1]"
   #   }
      puts $userpatch
   #   puts $patch
      eval patch $userpatch
   }

   set ssbondlist [find_ssbonds]; 
   foreach ssbond $ssbondlist {
      set seg1 {}
      set seg2 {}
      puts "SSBOND definition: $ssbondlist" ;# REMOVEME
      if {[lindex $ssbond 0]=="chain"} {
	      set seg1 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 1 2]} *"] 1]
	      set seg2 [lindex [lsearch -inline $chaintoseg "{[lrange $ssbond 4 5]} *"] 1]
      } elseif {[lindex $ssbond 0]=="seg"} {
	      set seg1 [lindex [lsearch -inline $segtoseg "{[lrange $ssbond 1 2]} *"] 1]
	      set seg2 [lindex [lsearch -inline $segtoseg "{[lrange $ssbond 4 5]} *"] 1]
      } else {
	      set seg1 [lindex $ssbond 1]
	      set seg2 [lindex $ssbond 4]
      }

      puts "\#patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]" ;#REMOVEME
      puts $logfileout "\#patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]"
      patch DISU $seg1:[lindex $ssbond 2] $seg2:[lindex $ssbond 5]
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

   # Remove failed guesses
   variable zerocoord
   variable nofailedguess
   if {$nofailedguess} {
      foreach segid [segment segids] {
	 foreach resid [segment resids $segid] {
	    foreach atom [segment atoms $segid $resid] {
	       set coord [segment coordinates $segid $resid $atom]
	       if {$coord=={0.000000 0.000000 0.000000} && [lsearch $zerocoord "$segid $resid $atom"]<0} {
		  puts $logfileout "\#Deleting atom $segid:$resid $atom with unspecified coordinates."
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

   #close $logfileout
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
  if { [psfupdate [join $topfiles "|"] "${basename}-temp.xbgf" "${basename}-temp.top"] != 0} { 
    puts "ERROR: psf checking did not work correctly."
    puts "There may be something wrong with the input structure."
    return 1
  }
  
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
             default {set typestr "Other"}
           }
           set newstring [format $chainformat $segname $length $start $end $nter $cter $typestr]
           lappend chaintexts $newstring
   } 

#   puts "$fnamelist"
   return $fnamelist
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
   set residues 1
   set oldsegid ""
   set last [list]
   set isrna 0
   set isdna 0

   #Clear current list of chain representations
   foreach rep $chainreps {
      mol delrep $rep $currentMol
   }

   foreach line [split [read -nonewline $in] \n] {
       set head [string range $line 0 5]
       if { ![string compare $head "ATOM  "] || 
	    ![string compare $head "HETATM"] } {
	  # Check if current residue is water
	  set oldresname $resname
	  set oldwater $curwater
          set oldnuc $curnuc
          set oldo $curo
          set oldprot $curprot
	  set oldcurseg $curseg
	  set curwater 0 
          set curnuc 0
          set curprot 0
          set curo 0
	  set resname [string trim [string range $line 17 20]]
	  set curseg  [string trim [string range $line 72 75]]
	  set curres  [string trim [string range $line 22 25]]
#	  set residstarts
#	  set residends

	  # Store atoms that are at the origin
	  if {$nofailedguess} {
	     set coor [string range $line 30 53]
	     if {[vecsub {0 0 0} $coor]=={0.0 0.0 0.0}} {
		set name [string trim [string range $line 12 15]]
		#puts "Atom $curseg:$curres $name located at {0 0 0}"
		lappend zerocoord [list $curseg $curres $name]
	     }	     
	  }

          if { $resname=="HOH " || $resname=="TIP3" } { 
	     set curwater 1 
          } 
          if {[regexp {ALA|ARG|ASN|ASP|CYS|GLN|GLU|GLY|HIS|HSD|HSE|HSP|ILE|LEU|LYS|MET|PHE|PRO|SER|THR|TRP|TYR|VAL} $resname] } {
             set curprot 1
	  } 
          if {[regexp {GUA|CYT|THY|ADE|URA|^A$|^C$|^G$|^T$|^U$} $resname]} { 
             set curnuc 1
          if {[regexp {^U$|URA} $resname]} {
             set isrna 1
             set isdna 0
          }
          if {[regexp {^T$|THY} $resname]} {
             set isrna 0
             set isdna 1
          }
	  } 
          if {!$curnuc && !$curprot && !$curwater} {
             set curo 1
          }

	  # Is the segment type changing?
	  if { $curwater && !$oldwater } { set newseg 1 }
          if { $curprot && !$oldprot} { set newseg 1 }
          if { $curnuc && !$oldnuc} { set newseg 1 }
          if { $curo && !$oldo } { set newseg 1 }
	  
	  # Check if the segID changes
	  if {$curseg!=$oldcurseg} {
	     set newseg 1
	     if {[llength $segid]} {
		    lappend segtoseg   [list [list $curseg $curres] $segid]
	     }
	  }

	  # Check the resID increment
	  if { $first } { set oldres [expr $curres-1] ; set residues 0}
	  set resdif [expr $curres - $oldres]


	  # If we have a resID increment > 1 then close the old file
	  if { $newseg || (!$curwater && ($resdif != 0 && $resdif != 1 && !($resdif == 2 && $oldres == -1))) } {
	     if {[info exists out]} {
                lappend chainends [expr [lindex $equivindices [expr $lineindex - 2]] + 1]
                lappend cters [get_cter $segid]
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
	  } elseif {($resdif != 0)} {
	     # Add this residue to the chain:res->segid and seg:res->segid lookup tables
	     lappend chaintoseg [list [list [string index $line 21] $curres] $segid]
       incr residues
	     lappend segtoseg   [list [list $curseg $curres] $segid]
       set oldres $curres
	  }

	  # Start a new file	  
	  if { $newfile == 1 } {
	     incr nseg

	     # Determine segment type
       if { $curwater } { 
         incr nwatseg; 
         set segid "W${nwatseg}" 
         # Add this residue to the chain:res->segid lookup table
         lappend chaintoseg [list [list [string index $line 21] $curres] $segid]
         lappend segtoseg   [list [list $curseg $curres] $segid]
         lappend chaintypes 3
      } 
      if {$curprot} { 
        set npseg [expr $npseg+1]; 
        set segid "P${npseg}"
        # Add this residue to the chain:res->segid lookup table
        lappend chaintoseg [list [list [string index $line 21] $curres] $segid]
        lappend segtoseg   [list [list $curseg $curres] $segid]
        lappend chaintypes 0
      } 
      if {$curnuc} {
        set nnseg [expr $nnseg+1];
        set segid "N${nnseg}"
        # Add this residue to the chain:res->segid lookup table
        lappend chaintoseg [list [list [string index $line 21] $curres] $segid]
        lappend segtoseg   [list [list $curseg $curres] $segid]
        if {$isrna == 1} {
          lappend chaintypes 2
            } else {
              lappend chaintypes 1
            }
         } 
         if {$curo} {
           set noseg [expr $noseg+1];
           set segid "O${noseg}"
           # Add this residue to the chain:res->segid lookup table
           lappend chaintoseg [list [list [string index $line 21] $curres] $segid]
           lappend segtoseg   [list [list $curseg $curres] $segid]
           lappend chaintypes 3
           }

           set newname "${fname}_${segid}.pdb"
	     set out [open $newname w]
             lappend nters [get_nter $segid $resname]
             lappend chainnames $segid
             lappend chainstarts [expr [lindex $equivindices [expr $lineindex - 1]] + 1]
	     lappend fnamelist $newname
	  #   set first 1
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
	  puts $out $line  
       }
       incr lineindex
       set last [list]
       lappend last [expr $lineindex - 1]
       lappend last [get_cter $segid]
       lappend last $residues
   }
   lappend chainends [expr [lindex $last 0] - 1]
   lappend cters [lindex $last 1]
   lappend chainlengths [expr [lindex $last 2] + 1]
   close $out
   close $in

   set chaintoseg [lsort -unique -index 0 $chaintoseg]
   set segtoseg [lsort -unique -index 0 $segtoseg]

   set chainlengths [lreplace $chainlengths end end [expr [lindex $chainlengths end] - 1]]

   foreach segname $chainnames length $chainlengths start $chainstarts end $chainends nter $nters cter $cters type $chaintypes {
           switch $type {
             0 {set typestr "Prot "}
             1 {set typestr "DNA  "}
             2 {set typestr "RNA  "}
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


  set nseg 0
  foreach segname $chainnames length $chainlengths start $chainstarts end $chainends nter $nters cter $cters  segfile $splitsegfiles type $chaintypes {
    incr nseg
    set tail [string range $segfile [expr [string last "_" $segfile]+1] end]
    set segid ""
    regsub {\.pdb$} $tail "" segid
    set iswater [regexp {^W[0-9]*$} $segid]
    set isother [regexp {^O[0-9]*$} $segid]
    set protnuc [regexp {^P*$|^N*$} $segid]
    set prot [regexp {^P[0-9]*$} $segid]
    set nuc  [regexp {^N[0-9]*$} $segid]

    puts $logfileout "\#Creating chain $segname: $length residues from indices $start to $end in original file. Patches: Nter $nter, Cter $cter"

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
    }
    coordpdb $segfile $segid
    if {$type == 1} {
      apply_dna_patch $segfile $segid
    }

    file delete $segfile $segid
  }
}

proc ::autopsf::get_cter {segid} {
        # Return a standard C terminal patch for the given segment type
    set prot [regexp {^P[0-9]*$} $segid]
    set nuc  [regexp {^N[0-9]*$} $segid]

#puts "CTER calc: $nuc $prot"

    if {$nuc} {
            return "3TER"
    } elseif {$prot} {
            return "CTER"
    } else {
            return "none"
    }
}

proc ::autopsf::get_nter {segid resname} {
    set prot [regexp {^P[0-9]*$} $segid]
    set nuc  [regexp {^N[0-9]*$} $segid]

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
	 set mysel [atomselect $tmpmolid "segid $segid and resid $resid and type \"XX\[A-Z\]+\""]
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

   set basename "${basename}_modified"
   file copy ${basename}.pdb ${basename}-temp.pdb
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
   puts "cleanup: $basename"
   foreach tempfile [glob ${basename}-temp* ${basename}_modified*] { file delete $tempfile }

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

      set sel2 [atomselect $currentMol "(not resid $resid) and resname CYS and name SG and index > $index and exwithin 3.0 of index $index"]
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
  set currtop [molinfo top]
  set tempmol [mol new $infile]
  set sel [atomselect top {name 'O3*' or name O3'}]

  foreach resid [$sel get resid] resname [$sel get resname] {
    if {$resname == "CYT" || $resname == "THY" || $resname == "T" || $resname == "C"} {
      patch DEO1 $segname:$resid
    }
    if {$resname == "ADE" || $resname == "GUA" || $resname == "A" || $resname == "G"} {
      patch DEO2 $segname:$resid
    }
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

	set patchsellist [$w.patches.list.list curselection]

  set patchsellist [lreverse $patchsellist]
  foreach patchind $patchsellist {
    set patchlist [lreplace $patchlist $patchind $patchind]
  }
  update_patchtexts
}

proc ::autopsf::lreverse {mylist} {
  set newlist [list]
  while {[llength $mylist] != 0} {
    set newelem [lindex $mylist end]
    lappend newlist $newelem
    set mylist [lreplace $mylist end end]
  }

  return $newlist
}
