# NAMDgui
# -------

# Author:
# Jan Saam
# Institute of Biochemistry
# Charite Berlin
# Germany
# saam@charite.de


# NAMDgui automatically sets up NAMD config files and can also run NAMD jobs
# It provides reasonable defaults for many parameters and a GUI to adjust them.

# Usage: namdgui -min 100 -run 1000 -psf mymolecule.psf -pdb mymolecule.pdb -sel water -o "mymolecule"

package require readcharmmpar
package require exectool 1.2
package require pbctools
package provide namdgui 1.1

namespace eval ::NAMDgui:: {
   namespace export namd

   proc init_variables {} {
      global env
      variable w                         ;# handle to main window
      variable gui         1;             # want to use the gui
      variable basename    ""
      variable namdconfig  "";            # NAMD config file
      variable workdir     "."
      variable pdb         ""
      variable psf         ""
      variable pdb_old     ""
      variable psf_old     ""
      variable xscfile         ""
      variable molid       -1
      variable sel         ""
      variable seltext     "all"
      variable fixedatoms  1
      variable numfixed    "Selection of mobile atoms:   (0/0 atoms)"
      variable numatoms    0
      variable runsteps    10000
      variable minsteps    1000
      variable firsttimestep       0
      variable freq        0
      variable timestep    1
      variable nonbondedfreq  2
      variable fullelectfreq  4
      variable stepspercycle  20
      variable outputenergies 100
      variable exclude      "scaled1-4"
      variable scale14      1
      variable switching    on
      variable switchdist   12
      variable cutoff       14
      variable pairlistdist 16
      variable COMmotion    no
      variable dielectric   1.0
      variable par          {}
      lappend par [file join $env(CHARMMPARDIR) par_all27_prot_lipid_na.inp]
      variable simdir      "./"
      variable ensemble    "NVE"
      variable temperature 310
      variable pressure    1.01325
      variable pme         0
      variable pbc         0
      variable pbcfromxsc  0
      variable continued   0
      variable inbasename  ""
      variable cell        {}
      variable cell1       {0 0 0}
      variable cell2       {0 0 0}
      variable cell3       {0 0 0}
      variable cello       {0 0 0}
      variable pbcfile     ""
      variable psfloaded   0
      variable pdbloaded   0
      variable minimize    1
      variable dynamics    0
      variable binaryoutput   "no"
      variable binaryrestart  "no"
      variable restartfreq 1000
      variable tclforcesscript ""
      variable namd_button "Run NAMD"
   }
   init_variables
}

proc namdgui { args } {
   eval ::NAMDgui::namdgui $args
}

proc namdgui_tk {} {
  variable w

  ::NAMDgui::namdgui
  return $::NAMDgui::w
}

proc ::NAMDgui::namdgui { args } {
   variable gui
   variable pdb         
   variable psf         
   variable molid       [molinfo top]
   variable sel         {}
   variable seltext  
   variable namdconfig {}
   variable numfixed
   variable numatoms
   variable runsteps       
   variable minsteps    
   variable firsttimestep       
   variable freq       
   variable par        
   variable simdir     
   variable temperature
   variable pressure  
   variable ensemble
   variable pbc        
   variable pme
   variable pbcfromxsc
   variable continued  
   variable inbasename     
   variable xscfile        
   variable pbcfile    
   variable psfloaded
   variable pdbloaded
   variable minimize
   variable dynamics
   variable basename
   #variable tclforce
   variable tclforcesscript
   variable workdir [pwd]
   remove_traces

   # Scan for single options
   set argnum 0
   set arglist $args
   foreach i $args {
      if {$i=="-NPT"}  then {
	 set ensemble NPT
	 set pbc 1
         set arglist [lreplace $arglist $argnum $argnum]
	 continue
      }
      if {$i=="-NVT"}  then {
	 set ensemble NVT
         set arglist [lreplace $arglist $argnum $argnum]
	 continue
      }
      if {$i=="-nogui"}  then {
         set gui 0
         set arglist [lreplace $arglist $argnum $argnum]
	 continue
      }
      if {$i=="-pbc"}  then {
         set pbc 1
	 set pbcfromxsc 1
         set arglist [lreplace $arglist $argnum $argnum]
	 continue
      }
      if {$i=="-pme"}  then {
         set pme 1
	 set pbc 1
	 set pbcfromxsc 1
         set arglist [lreplace $arglist $argnum $argnum]
	 continue
      }
      incr argnum
   }

   # Scan for options with argument
   foreach {i j} $arglist {
      if {$i=="-psf"}      then { set psf $j }
      if {$i=="-pdb"}      then { set pdb $j }
      if {$i=="-cont"}     then { set pdb $j; set continued 1 }
      if {$i=="-xsc"}      then { set xscfile $j; }
      if {$i=="-sel"}      then { set sel $j }
      if {$i=="-min"}      then { set minsteps $j; set minimize 1 }
      if {$i=="-run"}      then { set runsteps $j; set dynamics 1 }
      if {$i=="-first"}    then { set firsttimestep $j }
      if {$i=="-freq"}     then { set freq $j }
      if {$i=="-o"}        then { set basename $j }
      if {$i=="-par"}      then { set par $j }
      if {$i=="-addpar"}   then { lappend par $j }
      if {$i=="-simdir"}   then { set simdir $j }
      if {$i=="-namd"}     then { set namd $j }
      if {$i=="-T"}        then { set temperature $j }
      if {$i=="-press"}    then { set pressure $j }
      if {$i=="-tclforce"} then { set tclforcesscript $j }
   }

   # Evaluate the selection
   if {[llength $sel]} {
      # Selection was given as command line option
      if {[string match "atomselect?*" $sel]} {
	 set molid [$sel molid]
	 set seltext [$sel text]
	 set numatoms [molinfo $molid get numatoms]
	 set numfixed "Selection of mobile atoms:   ([$sel num]/$numatoms atoms)"
	 set psfloaded 1
      } else {
	 if {[molinfo num]} {
	    set molid [molinfo top get id]
	    set psfloaded 1
	 }
	 set seltext $sel
      }
   } else {
      # No selection given, use default "all"
      if {[molinfo num]} {
	 set molid [molinfo top get id]
	 set seltext all
	 set numatoms [molinfo $molid get numatoms]
	 set numfixed "Selection of mobile atoms:   (0/$numatoms atoms)"
	 set psfloaded 1
      }
   }

   # Set the pdb/psf filenames
   if {$psfloaded && ![llength $pdb]} {
      # Get the pdb filename
      foreach i [join [molinfo $molid get filetype]] j [join [molinfo $molid get filename]] {
         if {$i=="pdb"}     { set pdb $j; set pdbloaded 1; }
      }
   }
   if {$psfloaded && ![llength $psf]} {
      # Get the psf filename
      foreach i [join [molinfo $molid get filetype]] j [join [molinfo $molid get filename]] {
         if {$i=="psf"} { set psf $j }
      }
   }

   if {![llength $basename]} {
      set basename [file rootname $pdb] 
   }
   if {![llength $xscfile]} {
      set xscfile ${basename}.xsc 
   }

   if {!$freq && $minimize} { set freq 50 }
   if {!$freq && $dynamics} { set freq 500 }

   if {$gui} {
      namdgui_gui
   } else {
      run
   }
}


proc ::NAMDgui::namdgui_gui {} {
   variable w
   variable pdb
   variable psf
   variable runsteps
   variable firsttimestep
   variable basename
   variable workdir
   variable continued
   variable exclude
   variable scale14
   variable binaryoutput
   variable binaryrestart
   variable restartfreq
   variable ensemble
   variable cell1
   variable cell2
   variable cell3
   variable cello

   # If already initialized, just turn on
   if { [winfo exists .namdgui] } {
      wm deiconify $w
      return
   }
   
   set w [toplevel ".namdgui"]
   wm title $w "NAMDgui"
   wm resizable $w 0 0
   #wm protocol $w WM_DELETE_WINDOW {
      #remove_traces
       # destroy .namdgui
   #}

   menu $w.menu -tearoff 0
   menu $w.menu.file -tearoff 0
   $w.menu add cascade -label "File" -menu $w.menu.file -underline 0

   menu $w.menu.file.open -tearoff 0

   $w.menu.file add command -label "Load NAMD config file" -command {
      ::NAMDgui::opendialog namd $::NAMDgui::namdconfig
   }
   $w.menu.file add command -label "Save NAMD config file" -command {
      if {![llength $::NAMDgui::namdconfig]} {
	 set ::NAMDgui::namdconfig ${::NAMDgui::basename}.namd
      }
      ::NAMDgui::opendialog save $::NAMDgui::namdconfig
   }

   $w.menu.file add separator
   $w.menu.file add command -label "Reset all" -command {::NAMDgui::init_variables}


   menu $w.menu.edit -tearoff 0
   $w.menu add cascade -label "Edit" -menu $w.menu.edit -underline 0
   $w.menu.edit add command -label "Other Simulation Parameters" -accelerator <Ctrl-g> -command {::NAMDgui::simparams_gui}
   $w.menu.edit add command -label "TCL Forces" -accelerator <Ctrl-l> -command {::NAMDgui::tclforces_gui}

   menu $w.menu.help -tearoff 0
   $w.menu add cascade -label "Help" -menu $w.menu.help -underline 0
   $w.menu.help add command -label "Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/namdgui"

   $w configure -menu $w.menu


   ############# frame for general stuff #################
   labelframe $w.general -bd 2 -relief ridge -text "General"

   # Working directory
   labelentryframe $w.general.workdir "Working dir" ::NAMDgui::workdir 45 \
      -browse {::NAMDgui::opendialog workdir}
   
   # Simulation basename
   labelentryframe $w.general.basename "Simulation basename:" ::NAMDgui::basename 45
   
   pack $w.general.workdir $w.general.basename -pady 3 -padx 3 -anchor e


   ############## frame for filename entries #################
   labelframe $w.files -bd 2 -relief ridge -text "Input files"

   # psf file
   labelentryframe $w.files.psf "PSF file:" ::NAMDgui::psf 45 -validate focusout -vcmd ::NAMDgui::validate_psf \
      -browse {::NAMDgui::opendialog psf}

   # pdb file
   labelentryframe $w.files.pdb "PDB file:" ::NAMDgui::pdb 45 -validate focusout -vcmd ::NAMDgui::validate_pdb \
      -browse {::NAMDgui::opendialog pdb}

   # xsc file
   labelentryframe $w.files.xsc "XSC file:"  ::NAMDgui::xscfile 45 -validate focusout -vcmd ::NAMDgui::validate_xsc \
      -browse {::NAMDgui::opendialog xsc}

   # Parameter files
   labelframe  $w.files.par -bd 2 -text "Parameter files" -padx 1m -pady 1m

   frame $w.files.par.multi
   scrollbar $w.files.par.multi.scroll -command "$w.files.par.multi.list yview"
   listbox $w.files.par.multi.list -yscroll "$w.files.par.multi.scroll set" \
      -width 50 -height 3 -setgrid 1 -selectmode extended -listvariable ::NAMDgui::par
   pack $w.files.par.multi.list $w.files.par.multi.scroll -side left -fill y -expand 1

   frame  $w.files.par.multi.buttons
   button $w.files.par.multi.buttons.add -text "Add"    -command {
      ::NAMDgui::opendialog par
   }
   button $w.files.par.multi.buttons.delete -text "Delete" -command {
      foreach i [.namdgui.files.par.multi.list curselection] {
	 .namdgui.files.par.multi.list delete $i
      }
   }
   pack $w.files.par.multi.buttons.add $w.files.par.multi.buttons.delete -expand 1 -fill x
   pack $w.files.par.multi.list -side left  -fill x -expand 1
   pack $w.files.par.multi.scroll $w.files.par.multi.buttons -side left -fill y -expand 1
   pack $w.files.par.multi -expand 1 -fill x

#    # This will be executed when a new molecule is selected:   
#    bind $w.proj.topo.list.list <<ListboxSelect>> {
#       puts "selected topology %P"
#       #::Paratool::molecule_select
#    }




   toggle_continued
   
   pack $w.files.psf $w.files.pdb $w.files.xsc -padx 3 -anchor e
   pack $w.files.par -pady 1m -padx 2m  -expand 1 -fill x -ipady 1 -ipadx 1


   ############# frame for simulation timesteps #################
   labelframe $w.timesteps -bd 2 -relief ridge -text "Timesteps"

   # Minimization
   frame $w.timesteps.mini
   checkbutton $w.timesteps.mini.check -text "Minimization" -variable ::NAMDgui::minimize -relief flat \
      -command ::NAMDgui::toggle_minimization
   labelentryframe $w.timesteps.mini.steps "Number of steps:" ::NAMDgui::minsteps 12 \
      -validate focusout -vcmd ::NAMDgui::validate_steps
   pack $w.timesteps.mini.check  -padx 3 -anchor e -side left
   pack $w.timesteps.mini.steps  -padx 3 -anchor e -side right
   toggle_minimization

   # Equilibration
   frame $w.timesteps.equi
   checkbutton $w.timesteps.equi.check -text "Molecular dynamics" -variable ::NAMDgui::dynamics -relief flat \
      -command ::NAMDgui::toggle_equilibration
   labelentryframe $w.timesteps.equi.steps "Number of steps:" ::NAMDgui::runsteps 12 \
      -validate focusout -vcmd ::NAMDgui::validate_steps
   pack $w.timesteps.equi.check -padx 3 -anchor e -side left
   pack $w.timesteps.equi.steps -padx 3 -anchor e -side right
   toggle_equilibration

   # Continue run
   frame $w.timesteps.cont
   checkbutton $w.timesteps.cont.check -text "Continue simulation (get first timestep from XSC file)" \
      -variable ::NAMDgui::continued -relief flat -command ::NAMDgui::toggle_continued
   pack $w.timesteps.cont.check  -padx 3 -anchor e -side left

   # First time step
   labelentryframe $w.timesteps.first "First time step:" ::NAMDgui::firsttimestep 12

   pack $w.timesteps.mini $w.timesteps.equi $w.timesteps.cont -padx 3 -anchor w -fill x
   pack $w.timesteps.first -padx 6 -anchor w -fill x


   ############# frame for ensemble settings #################
   labelframe $w.ensemble -bd 2 -relief ridge -text "Ensemble"

   frame $w.ensemble.thermo

   frame $w.ensemble.thermo.pt
   labelentryframe $w.ensemble.thermo.pt.temp  "Temperature (Kelvin):" ::NAMDgui::temperature 12
   labelentryframe $w.ensemble.thermo.pt.press "Pressure (bar):"    ::NAMDgui::pressure 12
   pack $w.ensemble.thermo.pt.temp $w.ensemble.thermo.pt.press -padx 3 -anchor e 
 
   frame $w.ensemble.thermo.type
   foreach i {NVE NVT NPT} {
      radiobutton $w.ensemble.thermo.type.[string tolower $i] -text $i -variable ::NAMDgui::ensemble -relief flat \
	 -value $i -command ::NAMDgui::toggle_pressure
      pack $w.ensemble.thermo.type.[string tolower $i]  -side top -anchor e -fill x
   }

   pack $w.ensemble.thermo.type -padx 3 -anchor e -side left 
   pack $w.ensemble.thermo.pt   -padx 3 -anchor e -side right 

   frame $w.ensemble.pbc
   checkbutton $w.ensemble.pbc.check -text "Periodic boundary conditions (read unit cell from XSC file)" \
      -variable ::NAMDgui::pbc -relief flat -command ::NAMDgui::toggle_pbc
   pack $w.ensemble.pbc.check -side left -padx 3

   button $w.ensemble.pbc.edit -text "Edit" -command ::NAMDgui::pbc_edit
   pack $w.ensemble.pbc.edit -side left -padx 3

   frame $w.ensemble.pme
   checkbutton $w.ensemble.pme.check -text "Particle Mesh Ewald (needs periodic boundary conditions)" \
      -variable ::NAMDgui::pme -relief flat
   pack $w.ensemble.pme.check -side left -padx 3

   pack $w.ensemble.thermo $w.ensemble.pbc $w.ensemble.pme -fill x -padx 3
   toggle_pressure
   toggle_pbc

   ############# frame for mobile/fixed atoms #################
   labelframe $w.mobile -bd 2 -relief ridge -text "Mobile/fixed atoms"

   # Selection
   label $w.mobile.label -textvariable ::NAMDgui::numfixed
   entry $w.mobile.entry -textvariable ::NAMDgui::seltext -width 65 \
      -validate focusout -vcmd {::NAMDgui::validate_sel $::NAMDgui::seltext %W %v}
   button $w.mobile.show -text "Show selection" -command ::NAMDgui::show_selection

   pack $w.mobile.label $w.mobile.entry -pady 3 -padx 3 -anchor w -side top
   pack $w.mobile.show  -padx 3 -anchor w -side top


   # frame for Go/Quit buttons
   frame $w.go     
   button $w.go.write -text "Write NAMD config file" -command {
      if {![llength $::NAMDgui::namdconfig]} {
	 set ::NAMDgui::namdconfig ${::NAMDgui::basename}.namd
      }
puts $::NAMDgui::namdconfig
      ::NAMDgui::opendialog save $::NAMDgui::namdconfig
   }
   button $w.go.go  -textvariable ::NAMDgui::namd_button -command ::NAMDgui::run
   label $w.go.status -textvariable ::NAMDgui::namd_status
   pack $w.go.write $w.go.go  -side left -anchor w
   pack $w.go.status -padx 3m -side left -anchor w
 

   ##
   ## pack up the main frame
   ##
   pack $w.general $w.files $w.timesteps $w.ensemble $w.mobile \
      $w.go -side top -pady 5 -padx 3 -ipady 1m -fill x -anchor w
 
   foreach file $NAMDgui::par {
      validate_file $file
   }
   foreach file $NAMDgui::tclforcesscript {
      validate_file $file
   }
}

proc ::NAMDgui::show_selection {} {
   variable w
   variable sel
   variable seltext
   if {![validate_sel $seltext]} { return }

   set draw_method  "Licorice"
   set color_method "Name"
   mol selection [$sel text]
   mol representation $draw_method
   mol color  $color_method
   set rep_number [molinfo [$sel molid] get numreps]
   mol addrep [$sel molid]
   puts "Generated representation $rep_number with draw method '$draw_method' and color method '$color_method'"
}

proc ::NAMDgui::pbc_edit {} {
   variable cell
   variable cell1
   variable cell2
   variable cell3
   variable cello
   toplevel ".pbcedit"
   wm title .pbcedit "Edit PBC"

   set cell1 [lindex $cell 0]
   set cell2 [lindex $cell 1]
   set cell3 [lindex $cell 2]
   set cello [lindex $cell 3]
   # Unit cell vectors
   frame .pbcedit.cell
   labelentryframe .pbcedit.cell.v1 "cell1:" ::NAMDgui::cell1 20
   labelentryframe .pbcedit.cell.v2 "cell2:" ::NAMDgui::cell2 20
   labelentryframe .pbcedit.cell.v3 "cell3:" ::NAMDgui::cell3 20
   labelentryframe .pbcedit.cell.ori "origin:" ::NAMDgui::cello 20
   pack .pbcedit.cell.v1 .pbcedit.cell.v2 .pbcedit.cell.v3 .pbcedit.cell.ori -pady 3 -padx 3 -anchor e

   frame .pbcedit.buttons
   button .pbcedit.buttons.ok     -text "Ok" -command ::NAMDgui::pbc_edit_ok
   button .pbcedit.buttons.cancel -text "Cancel" -command ::NAMDgui::pbc_edit_cancel
   pack .pbcedit.buttons.ok .pbcedit.buttons.cancel -pady 3 -padx 3 -side left

   pack .pbcedit.cell .pbcedit.buttons
}

proc ::NAMDgui::pbc_edit_ok {} {
   variable cell
   variable cell1
   variable cell2
   variable cell3
   variable cello
   variable pbcfromxsc

   set cell [list $cell1 $cell2 $cell3 $cello]
   ::PBCTools::pbcset $cell -namd
   set pbcfromxsc 0
   destroy .pbcedit 
}

proc ::NAMDgui::pbc_edit_cancel {} {
   destroy .pbcedit 
}

######################################################
### Get path file name for opening                 ###
######################################################

proc ::NAMDgui::opendialog { filetype {initialfile ""}} {
   variable psf
   variable pdb
   variable par
   variable tclforcesscript
   variable xscfile
   variable workdir
   variable w

   set types {}

   if {$filetype=="psf"} {
      set types {
	 {{PSF Files}       {.psf}        }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="pdb"} {
      set types {
	 {{PDB Files}       {.pdb .coor}  }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="xsc"} {
      set types {
	 {{XSC Files}       {.xsc .xst}   }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="tcl"} {
      set types {
	 {{TCL Files}       {.tcl}   }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="par"} {
      set types {
	 {{Parameter Files} {.inp .par}   }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="namd"} {
      set types {
	 {{NAMD Configuration Files} {.namd .conf}   }
	 {{All Files}        *            }
      }
   } elseif {$filetype=="save"} {
      set types {
	 {{NAMD Configuration Files} {.namd .conf}   }
	 {{All Files}        *            }
      }
   }

   set newpathfile {}
   if {$filetype=="workdir"} {
      set workdir [tk_chooseDirectory \
		  -initialdir "." -title "Choose working directory"] 
   } elseif {$filetype=="par"} {
      set newpathfile [tk_getOpenFile \
			  -title "Choose file name" \
			  -initialdir $workdir -filetypes $types -multiple 1]
   } elseif {$filetype=="save"} {
      set newpathfile [tk_getSaveFile \
			  -title "Choose file name" \
			  -initialdir $workdir -filetypes $types -initialfile $initialfile]
   } else {
      set newpathfile [tk_getOpenFile \
			  -title "Choose file name" \
			  -initialdir $workdir -filetypes $types -initialfile $initialfile]
   }

   if {[string length $newpathfile] > 0} {
      if {$filetype=="psf"} { set psf $newpathfile; }
      if {$filetype=="pdb"} { set pdb $newpathfile; }
      if {$filetype=="xsc"} { set xscfile $newpathfile; }
      if {$filetype=="par" && [validate_file $newpathfile]} {
	 foreach file $newpathfile {
	    set dir [file normalize [file dirname $file]]
	    set normwd [file normalize $workdir]
	    if {$dir==$normwd} {set file [file tail $file]}
	    lappend par $file;
	 }
      }
      if {$filetype=="tcl" && [validate_file $newpathfile]} {
	 foreach file $newpathfile {
	    set dir [file normalize [file dirname $file]]
	    set normwd [file normalize $workdir]
	    if {$dir==$normwd} {set file [file tail $file]}
	    lappend tclforcesscript $file;
	 }
      }
      if {$filetype=="namd"} { 
	 ::NAMDconfig::load_namdconfig $newpathfile	 
      }
      if {$filetype=="save"} { 
	 variable namdconfig $newpathfile
	 ::NAMDgui::config_only 
      }
      return 1
   }
   return 0
}



proc ::NAMDgui::validate_file {file {W 0} {V 0}} {
   variable w

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   set file [string trim $file]
   
   if {![llength $file]} { return 0 }
   
   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	 -message "Didn't find file \"$file\""
      return 0
   }

   return 1
}

proc ::NAMDgui::validate_pdb {file {W 0} {V 0}} {
   variable w
   variable pdbloaded
   variable pdb
   variable pdb_old
   variable workdir
   variable molid

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   set file [string trim $file]

   if {![llength $file]} { return 0 }

   set dir [file normalize [file dirname $file]]
   set normwd [file normalize $workdir]
   if {$dir==$normwd} {set file [file tail $file]}

   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	-message "Didn't find file \"$file\""
      return 0
   }

   set pdb $file

   # If a new pdb file is selected load it into the top molecule
   if {$file!=$pdb_old && ![molinfo $molid get numframes]} {
      if {[catch {mol addfile $file type pdb}]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	    -message "Error loading PDB file \"$file\""
	 return 0
      } else {
	 set pdb_old $file
	 puts "Loaded $file into molecule $molid"
      }
   } else {
      puts "new=old"
   }

   set pdbloaded 0
   return 1
}

proc ::NAMDgui::validate_psf {file {W 0} {V 0}} {
   variable w
   variable seltext
   variable molid
   variable psfloaded
   variable psf
   variable psf_old
   variable workdir

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   set psfloaded 0

   set file [string trim $file]

   if {![llength $file]} { return 0 }

   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	-message "Didn't find file PSF file \"$file\""
      return 0
   }

   set dir [file normalize [file dirname $file]]
   set normwd [file normalize $workdir]
   if {$dir==$normwd} {set file [file tail $file]}
   set psf $file

   # If a new psf file is selected load the new molecule
   if {$file!=$psf_old} {
      if {[catch {set molid [mol load psf $file]}]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	    -message "Error loading PSF file \"$file\""
	 return 0
      } else {
	 set psf_old $file
	 set numatoms [molinfo $molid get numatoms]
	 puts "Loaded $file as molecule $molid"
      }
   } else {
      puts "new=old"
   }


   set psfloaded 1
   validate_sel $seltext
   return 1
}

proc ::NAMDgui::validate_xsc {file {W 0} {V 0}} {
   variable w
   variable workdir
   variable xscfile 

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   set file [string trim $file]

   if {![llength $file]} { return 0 }

   set dir [file normalize [file dirname $file]]
   set normwd [file normalize $workdir]
   if {$dir==$normwd} {set file [file tail $file]}

   if {![file exists $file]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	-message "Didn't find file \"$file\""
      return 0
   }

   set xscfile $file
   read_xsc $xscfile

   return 1
}

proc ::NAMDgui::validate_sel {seltext {W 0} {V 0}} {
   variable w
   variable molid
   variable sel
   variable numfixed
   variable numatoms
   variable psfloaded

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   if { !$psfloaded } { return 0 }

   if {[catch {atomselect $molid "$seltext"}]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	-message "Didn't understand selection $seltext"
      return 0
   } else {
      puts "Making selection"
      set sel [atomselect top "$seltext"]
      set numatoms [molinfo $molid get numatoms]
      set numfixed "Selection of mobile atoms:   ([$sel num]/$numatoms atoms)"
      $sel global
   }

   return 1
}

proc ::NAMDgui::validate_steps {steps {W 0} {V 0}} {
   variable w
   variable minsteps
   variable runsteps
   variable stepspercycle

   if { $W!=0 } {
      eval after idle "$W config -validate $V"
   }

   if {$minsteps && [expr $minsteps%$stepspercycle]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	 -message "Number of steps must be a multiple of stepsPerCycle ($stepspercycle)"
      return 0
   }
   if {$runsteps && [expr $runsteps%$stepspercycle]} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	 -message "Number of steps must be a multiple of stepsPerCycle ($stepspercycle)"
      return 0
   }
   return 1
}

proc ::NAMDgui::toggle_pressure {} {
   variable w
   variable ensemble
   variable pbc

   if {$ensemble=="NPT"} {
      set pbc 1
      $w.ensemble.thermo.pt.press.entry configure -state normal
   } else {
      $w.ensemble.thermo.pt.press.entry configure -state disabled
   }
   toggle_pbc
}

proc ::NAMDgui::toggle_pbc {} {
   variable w
   variable pbc
   variable xscfile
   variable ensemble
   variable continued
   variable cell

   if {$pbc || $continued} {
      if {$pbc} {
	 # Check if xsc file exists
	 if {! [file exists $xscfile]} {
	    tk_messageBox -icon error -type ok -title Message -parent $w \
	       -message "Didn't find xsc file $xscfile"
	 } else {
	    puts "Reading $xscfile ..."
	    read_xsc "$xscfile"
	    puts "PBC geometry:"
	    puts $cell
	 }
      }
      $w.files.xsc.entry configure -state normal
      #$w.files.xsc.browse configure -state normal
      $w.ensemble.pme.check configure -state normal
   } else {
      if {$ensemble=="NPT" && !$pbc} { 
	 set ensemble "NVT" 
      }
      $w.files.xsc.entry configure -state disabled
      #$w.files.xsc.browse configure -state disabled
      $w.ensemble.pme.check configure -state disabled
   }
}


proc ::NAMDgui::toggle_continued {} {
   variable w
   variable continued
   variable xscfile
   variable pdb
   variable pbc
   variable inbasename
   variable firsttimestep

   if {$continued} {
      # First get file basename for namd input:
      if {![llength $xscfile]} {
	 set inbasename [file rootname $pdb]
      } else {
	 set inbasename [file rootname $xscfile]
      }

      # Check if xsc file exists
      if {! [file exists $xscfile]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	-message "Didn't find xsc file $xscfile"
      } else {
	 puts "Reading $xscfile ..."
	 read_xsc "$xscfile"
	 puts "Setting first timestep to $firsttimestep"
      }
      
      $w.files.xsc.entry configure -state normal
      #$w.files.xsc.browse configure -state normal
   } else {
      puts "Setting first timestep to 0 (default)"
      set firsttimestep 0
      if {!$pbc} {
	 $w.files.xsc.entry configure -state disabled
      }
   }
}

proc ::NAMDgui::toggle_minimization {} {
   variable w
   variable minimize
   if {$minimize} {
      $w.timesteps.mini.steps.entry configure -state normal
   } else {
      $w.timesteps.mini.steps.entry configure -state disabled
   }
}

proc ::NAMDgui::toggle_equilibration {} {
   variable w
   variable dynamics
   if {$dynamics} {
      $w.timesteps.equi.steps.entry configure -state normal
   } else {
      $w.timesteps.equi.steps.entry configure -state disabled
   }
}


proc ::NAMDgui::config_only {} {
   if {![check_input]} { return }
   write_files
}


proc ::NAMDgui::check_input {} {
   variable w
   variable pdb         
   variable psf         
   variable molid
   variable numatoms
   variable sel         
   variable seltext
   variable psfloaded
   variable pdbloaded
   variable psf_old
   variable outputenergies
   variable stepspercycle

   if {[expr $outputenergies % $stepspercycle] || $outputenergies<$stepspercycle} {
      tk_messageBox -icon error -type ok -title Message -parent $w \
	 -message "Energy output freqency must be a multiple of steps per cycle!"
      return 0    
   }

   set i 0
   foreach file $NAMDgui::par {
      if {![validate_file $file]} {
	 $w.files.par.multi.list selection set $i
	 delete_par
	 opendialog par
	 return 0
      }
      incr i
   }
   set i 0
   foreach file $NAMDgui::tclforcesscript {
      if {![validate_file $file]} {
	 $w.files.tcl.multi.list selection set $i
	 delete_tcl
	 opendialog tcl
	 return 0
      }
       incr i
  }

   # Load the structure
   if {!$psfloaded} {
      if {![file exists $psf]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	    -message "Didn't find file PSF file \"$psf\""
	 return 0
      }
   }
   if {!$pdbloaded} {
      if {![file exists $pdb]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	    -message "Didn't find file PDB file\"$pdb\""
	 return 0
      }
   }
   if {!$psfloaded} {
      mol load psf $psf pdb $pdb
      set molid [molinfo top]
      set psfloaded 1
      set pdbloaded 1
      set numatoms [molinfo top get numatoms]
      set psf_old $psf
   }
   if {!$pdbloaded} {
      mol addfile $pdb type pdb
   }

   puts "psf: $psf"
   puts "pdb: $pdb"
   puts ""

   # Make selection if the selection does not yet exist
   if {![string match "atomselect?*" $sel]} {
      puts      "selection does not exist"

      if {[catch {atomselect $molid "$seltext"}]} {
	 tk_messageBox -icon error -type ok -title Message -parent $w \
	    -message "Didn't understand selection $seltext"
	 return 0
      } else {
	 puts "Making selection"
	 set sel [atomselect $molid "$seltext"]
	 $sel global
      }
   }
   puts "Nonfixed atoms:"
   puts "[$sel text]"

   return 1
}

proc ::NAMDgui::read_xsc {file} {
   variable cell
   variable cell1
   variable cell2
   variable cell3
   variable cello
   variable firsttimestep
   variable continued
   variable pbc
   variable pbcfromxsc

   set fd [open $file r]
      while {![eof $fd]} {
	 set line [gets $fd]
	 if {[string first \# $line]==-1 && [llength $line]>0} {
	    if {$continued} {set first [lindex $line 0]}
	    # Get PBC vectors
	    if {$pbc} {
	       foreach {a b c} [lrange $line 1 3] {}
	       set cell1 [format "%.2f %.2f %.2f" $a $b $c]
	       foreach {a b c} [lrange $line 4 6] {}
	       set cell2 [format "%.2f %.2f %.2f" $a $b $c]
	       foreach {a b c} [lrange $line 7 9] {}
	       set cell3 [format "%.2f %.2f %.2f" $a $b $c]
	       foreach {a b c} [lrange $line 10 12] {}
	       set cello [format "%.2f %.2f %.2f" $a $b $c]
	       set cell [list $cell1 $cell2 $cell3 $cello]
	       set pbcfromxsc 1
	    }
	 }
      }
      close $fd
}

proc ::NAMDgui::write_files {} {
   variable w
   variable pdb         
   variable psf
   variable xscfile
   variable par
   variable molid
   variable basename
   variable inbasename     
   variable minsteps    
   variable runsteps 
   variable timestep
   variable nonbondedfreq
   variable fullelectfreq
   variable stepspercycle
   variable outputenergies
   variable minimize
   variable dynamics
   variable continued
   variable ensemble
   variable temperature
   variable pressure
   variable pbc
   variable pme
   variable pbcfromxsc
   variable sel         
   variable seltext
   variable cell
   variable firsttimestep
   variable freq       
   variable exclude
   variable scale14
   variable binaryoutput
   variable binaryrestart
   variable restartfreq
   variable tclforcesscript
   variable namdconfig
   variable switching
   variable switchdist
   variable cutoff
   variable pairlistdist
   variable COMmotion
   variable dielectric

   if {[file exists ${basename}.namd]} {
      set ret [tk_messageBox -icon warning -type okcancel -title Message -parent $w \
		  -message "File ${basename}.namd exists! Overwrite?"]
      if {$ret=="cancel"} { return }
   }

   # Write the fixed atoms file 
   set all [atomselect $molid all]
   $all set occupancy 1
   $sel set occupancy 0
   puts ""
   puts "[$sel num] mobile atoms"
   puts "[expr [$all num]-[$sel num]] fixed atoms"
   puts "---------------------------------"
   puts "[$all num] atoms total"
   $all writepdb ${basename}_fixed.pdb

   # Write the config file:
   set conf [open ${basename}.namd w]
   puts $conf "\# NAMD Config file - autogenerated by NAMDgui plugin"
   puts $conf "\# Author: Jan Saam,  saam@charite.de"
   puts $conf ""

   if {[llength $tclforcesscript]} {
      puts $conf "TCLForces               on"
      foreach script $tclforcesscript {
	 puts $conf "TCLForcesScript         $script"
      }
      puts $conf ""
   }

   puts $conf "# input"
   if {$continued} {
      puts $conf "set input               $inbasename"
      puts $conf "coordinates             \${input}.coor"
      puts $conf "velocities              \${input}.vel"
      puts $conf "extendedSystem          \${input}.xsc"
   } else {
      puts $conf "coordinates             $pdb"
      if {[llength $xscfile] && $pbc && $pbcfromxsc} {
	 puts $conf "extendedSystem          $xscfile"
      }
   }

   puts $conf "structure               $psf"
   foreach p $par {
      puts $conf "parameters              $p"
   }
   puts $conf "paratypecharmm          on"
   puts $conf ""
   puts $conf "# output"
   puts $conf "set output              $basename"
   puts $conf "outputname              \$output"
   puts $conf "dcdfile                 \${output}.dcd"
   puts $conf "xstFile                 \${output}.xst"
   puts $conf "dcdfreq                 $freq"
   puts $conf "xstFreq                 $freq"
   puts $conf ""
   puts $conf "binaryoutput            $binaryoutput"
   puts $conf "binaryrestart           $binaryrestart"
   puts $conf "outputEnergies          $outputenergies"
   puts $conf "restartfreq             $restartfreq"
   puts $conf ""
   variable fixedatoms
   if {[$sel text]=="all" || !$fixedatoms} {
      puts $conf "fixedAtoms              off"
   } else {
      puts $conf "# mobile atom selection:"
      puts $conf "# [join $seltext]"
      puts $conf "fixedAtoms              on"
      puts $conf "fixedAtomsFile          ${basename}_fixed.pdb"
      puts $conf "fixedAtomsCol           O"
   }

   puts $conf ""
   puts $conf "# Basic dynamics"
   puts $conf "exclude                 $exclude"
   puts $conf "1-4scaling              $scale14"
   puts $conf "COMmotion               $COMmotion"
   puts $conf "dielectric              $dielectric"

   puts $conf ""
   puts $conf "# Simulation space partitioning"
   puts $conf "switching               $switching"
   if {$switching} {
      puts $conf "switchdist              $switchdist"
   }
   puts $conf "cutoff                  $cutoff"
   puts $conf "pairlistdist            $pairlistdist"

   puts $conf ""
   puts $conf "# Multiple timestepping"
   puts $conf "firsttimestep           $firsttimestep"
   #puts $conf "numsteps                $runsteps"
   puts $conf "timestep                $timestep"
   puts $conf "stepspercycle           $stepspercycle"
   puts $conf "nonbondedFreq           $nonbondedfreq"      
   puts $conf "fullElectFrequency      $fullelectfreq"

   puts $conf ""
   puts $conf "# Temperature control"
   puts $conf "";			# 
   puts $conf "set temperature         $temperature"
   if {!$continued} {
      puts $conf "temperature             \$temperature;  # initial temperature"
   }
   if {$dynamics && ($ensemble=="NPT" || $ensemble=="NVT")} {
      puts $conf ""
      puts $conf "# Langevin Dynamics"
      puts $conf "langevin                on;            # do langevin dynamics"
      puts $conf "langevinDamping         5;              # damping coefficient (gamma) of 5/ps"
      puts $conf "langevinTemp            \$temperature;   # bath temperature"
      puts $conf "langevinHydrogen        no;             # don't couple langevin bath to hydrogens"
      puts $conf "seed                    12345"
      puts $conf ""
      if {$ensemble=="NPT"} {
	 puts $conf "# Pressure control"
	 puts $conf "langevinPiston          on"
	 puts $conf "langevinPistonTarget    $pressure; # in bar -> 1.01325 bar = 1 atm"
	 puts $conf "langevinPistonPeriod    200"
	 puts $conf "langevinPistonDecay     100"
	 puts $conf "langevinPistonTemp      \$temperature"
	 puts $conf "useFlexibleCell         no"
	 puts $conf "useGroupPressure        no"
	 puts $conf "fixedAtomsForces        off"
      }
   }

   if {$pbc} {
      puts $conf ""
      puts $conf "# PBC"
      # Only specify the PBC cell when the info is not read from xsc.
      # This prevents the "Elect energy jumping bug" in NAMD
      if {!$pbcfromxsc} {
	 puts $conf "cellBasisVector1        [lindex $cell 0]"
	 puts $conf "cellBasisVector2        [lindex $cell 1]"
	 puts $conf "cellBasisVector3        [lindex $cell 2]"
	 puts $conf "cellOrigin              [lindex $cell 3]"
      }
      puts $conf "wrapAll                 on"
      puts $conf "dcdUnitCell             yes"
      if {$pme} {
	 puts $conf ""
	 puts $conf "PME                     yes"
	 puts $conf "PMEGridSizeX            [pmegridsize [expr int([veclength [lindex $cell 0]])]]"
	 puts $conf "PMEGridSizeY            [pmegridsize [expr int([veclength [lindex $cell 1]])]]"
	 puts $conf "PMEGridSizeZ            [pmegridsize [expr int([veclength [lindex $cell 2]])]]"
      }
   }

   puts $conf ""
   puts $conf ""
   puts $conf "# Scripting"
   puts $conf ""
   if {$minimize} {
      puts $conf "minimize            $minsteps"
      if {$dynamics} { puts $conf "reinitvels          \$temperature" }
   }
   if {$dynamics} {
      puts $conf "run                 [expr $runsteps-$firsttimestep]"
   }
   close $conf
}

proc ::NAMDgui::run {} {
   variable simdir
   variable basename
   variable namd_fd
   variable namd_button
   
   # If NAMD is running, do nothing
   if {[string equal $namd_button "Stop NAMD"]} {
      # Try to kill the process.
      # XXX - this simply won't work on Windows without a seperate "kill"
      # program being installed, so fail gracefully.
      puts "Stopping NAMD."
      if { [catch {exec kill [pid $namd_fd]} err] } {
	 puts "namdrun: can't close NAMD:\n  $err"
      }
      return
   }
   if {![check_input]} { return }

   write_files
   
   #Start NAMD
   puts ""
   puts "Starting NAMD..."
   set olddir [pwd]
   set logname ${basename}.out
   
   set namdbin {}
   # Prompt the user for NAMD binary location if necessary
   switch [vmdinfo arch] {
      WIN64 -
      WIN32 {
	 set namdbin [::ExecTool::find -interactive namd2.exe]
      }
      default {
	 set namdbin [::ExecTool::find -interactive namd2]
      }
   }
   
   set ret [catch {
      cd $simdir
      file delete -force  $logname
      
      #::ExecTool::exec $namdbin ${basename}.namd >& $logname &
   } var]
   
   set pid 0
   
   
   variable namd_input "${basename}.namd"
   variable namd_button "Stop NAMD"
   variable namd_status "Status: Running"
   # cope with filenames containing spaces
   set namdcmd [format "\"%s\"" $namdbin]
   
   variable namd_log_fd [open $logname w]
   # Attach NAMD to a filehandle and print output as it becomes available
   if { [catch {set namd_fd [open "|$namdcmd $namd_input"]}] } {
      puts "namdrun: error running $namdbin"
      ::NAMDgui::namd_stop
   } else {
      fconfigure $namd_fd -blocking false
      fileevent $namd_fd readable [list ::NAMDgui::read_handler $namd_fd]
   }
   
   # Be sure to return to the old directory before passing on any error
   cd $olddir
   
   if {$ret} { error $var }
   
   return
}

# Call this function when namd is done
proc ::NAMDgui::namd_stop {} {
  variable namd_status
  variable namd_button
  variable namd_fd

  if { [catch {close $namd_fd} err] } {
    puts "namdgui) Warning: possible problem while running NAMD:\n  $err"
  }

  set namd_status "Status: Ready"
  set namd_button "Run NAMD"
}

# Read and print a line of NAMD output.
proc ::NAMDgui::read_handler { chan } {
  if {[eof $chan]} {
    fileevent $chan readable ""
    ::NAMDgui::namd_stop
    return
  }

   if {[gets $chan line] > 0} {
     puts $::NAMDgui::namd_log_fd "$line"
  }
}



proc ::NAMDgui::remove_traces {} {
   trace remove variable ::NAMDgui::exclude write ::NAMDgui::toggle_exclude
}

proc ::NAMDgui::labelentryframe {widget text var width args} {
   set browse {}
   set side   "-side right "
   set anchor "-anchor e"
   set validate {}
   set vcmd {}
   set argnum 0
   set arglist $args
   # Scan for options with argument
   foreach {i j} $args {
      if {$i=="-browse"} then { 
	 set browse "-command [list $j]"; 
	 set arglist [lreplace $arglist $argnum [expr $argnum+1]]
	 continue
      }
      if {$i=="-side"} then { 
	 set side "-side $j"; 
	 set arglist [lreplace $arglist $argnum [expr $argnum+1]]
	 continue
      }
      if {$i=="-anchor"} then { 
	 set side "-anchor $j"; 
	 set arglist [lreplace $arglist $argnum [expr $argnum+1]]
	 continue
      }
      if {$i=="-validate"} then { 
	 set validate "-validate $j"; 
	 set arglist [lreplace $arglist $argnum [expr $argnum+1]]
	 continue
      }
      if {$i=="-validatecommand" || $i=="-vcmd"} then { 
	 set vcmd "-validatecommand {$j %P %W %v}"; 
	 set arglist [lreplace $arglist $argnum [expr $argnum+1]]
	 continue
      }
      incr argnum 2
   }

   frame $widget
   label $widget.label -text $text
   entry $widget.entry -width $width -relief sunken -bd 2 -textvariable $var
   eval $widget.entry config $validate $vcmd
   if {[llength $browse]} {
      eval button $widget.browse -text "Browse" $browse
      pack $widget.browse -fill x -anchor e -padx 3 -side right
   }
   eval pack $widget.entry $side $anchor [join $arglist]
   eval pack $widget.label -fill x -anchor e -padx 3 -side right
   bind $widget.entry <Return> "$widget.entry validate"
}


proc ::NAMDgui::labelmenubuttonframe {widget text var width bopt args} {
   if {![llength $args]} {set args "-anchor e -side right"}
   frame $widget
   label $widget.label -text $text
   #entry $widget.entry -width $width -relief sunken -bd 2 -textvariable $var
   eval tk_optionMenu $widget.menubutton ::NAMDgui::exclude [join $bopt]
   $widget.menubutton configure -width [expr $width-5] -bd 2 
   eval pack $widget.menubutton [join $args]
   eval pack $widget.label -fill x -anchor e -padx 3 -side right
}

namespace eval ::NAMDconfig:: {

   # Provide our own implementation of 'unknown'
   proc my_unknown args {
      # Maybe the command was provided in uppercase, we implemented only lowercase, so try lower:
      set tolowercom ::NAMDconfig::[string tolower [lindex $args 0]]
      #puts "Didn't find command [lindex $args 0], trying $tolowercom"

      if {![llength [info procs $tolowercom]]} {
	 puts stderr "WARNING: ignoring command: $args"
	 return
      }

      rename unknown tmp_unknown
      set ret [catch "eval $tolowercom [lrange $args 1 end]"]
      rename tmp_unknown unknown
      eval $tolowercom [lrange $args 1 end]

      return $ret
   }

   proc load_namdconfig { file } {
      # Save the original one so we can chain to it
      if {[llength [info procs ::_original_unknown]]} {
	 uplevel 1 "rename ::_original_unknown {}"
      }

      if {[llength [info procs ::unknown]]} {
	 uplevel 1 rename ::unknown ::_original_unknown
      }

      uplevel 1 rename ::NAMDconfig::my_unknown ::unknown

      # Execute the file contents in this namespace
      set fid [open $file]
      set data [read -nonewline $fid]
      eval $data

      # Restore the original 'unknown' script
      rename ::unknown ::NAMDconfig::my_unknown
      rename ::_original_unknown ::unknown
   }

   proc tclforces { onoff }         { set ::NAMDgui::tclforces 1 }
   proc tclforcesscript { script }  { lappend ::NAMDgui::tclforcesscript $script }
   proc coordinates { coor }        { set ::NAMDgui::coordinates $coor }
   proc velocities  { vel }         { set ::NAMDgui::velocities $vel }
   proc extendedsystem { xsc }      { set ::NAMDgui::xscfile $xsc }
   proc structure { psf }           { set ::NAMDgui::psf $psf }
   proc parameters { par }          { lappend ::NAMDgui::par $par }
   proc paratypecharmm { onoff }    { set ::NAMDgui::paratypecharmm $onoff }
   proc outputname { name }         { set ::NAMDgui::basename $name }
   proc dcdfile { dcd }             { set ::NAMDgui::dcd $dcd }
   proc xstfile { xst }             { set ::NAMDgui::xst $xst }
   proc dcdfreq { freq }            { set ::NAMDgui::dcdfreq $freq }
   proc xstfreq { freq }            { set ::NAMDgui::xstfreq $freq }
   proc fixedatoms { onoff }        { set ::NAMDgui::fixedatoms $onoff }
   proc binaryoutput { yesno }      { set ::NAMDgui::binaryoutput $yesno }
   proc binaryrestart { yesno }     { set ::NAMDgui::binaryrestart $yesno }
   proc outputenergies { freq }     { set ::NAMDgui::outputenergies $freq }
   proc restartfreq { freq }        { set ::NAMDgui::restartfreq $freq }
   proc exclude { excl }            { set ::NAMDgui::exclude $excl }
   proc 1-4scaling { scale }        { set ::NAMDgui::scale14 $scale }
   proc cutoff { cut }              { set ::NAMDgui::cutoff $cut }
   proc switching { onoff }         { set ::NAMDgui::switching $onoff }
   proc switchdist { dist }         { set ::NAMDgui::switchdist $dist }
   proc pairlistdist { dist }       { set ::NAMDgui::pairlistdist $dist }
   proc firsttimestep { step }      { set ::NAMDgui::firsttimestep $step }
   proc timestep { step }           { set ::NAMDgui::timestep $step }
   proc stepspercycle { step }      { set ::NAMDgui::stepspercycle $step }
   proc nonbondedfreq { freq }      { set ::NAMDgui::nonbondedfreq $freq }
   proc fullelectfrequency { freq } { set ::NAMDgui::fullelectfreq $freq }
   proc temperature { temp }        { set ::NAMDgui::temperature $temp }
   proc reinitvels { temp }         { set ::NAMDgui::reinitveltemp $temp }
   proc minimize { step }           { set ::NAMDgui::minsteps $step }
   proc run      { step }           { set ::NAMDgui::runsteps $step }
   proc dielectric { diel }         { set ::NAMDgui::dielectric $diel }
   proc commotion { comm }          { set ::NAMDgui::COMmotion $comm }
   proc dummy {} { puts DUMMY }
}

########################################################################
# Returns the factorization according to 2,3,5 and the residue factor. #
########################################################################

proc ::NAMDgui::factorize { z } {
   set five  0
   set three 0
   set two   0
   while {![expr $z%5]} {set z [expr $z/5]; incr five}
   while {![expr $z%3]} {set z [expr $z/3]; incr three}
   while {![expr $z%2]} {set z [expr $z/2]; incr two}
   return "$z $two $three $five"
}


########################################################################
# Returns the optimum PMEgridSize that can be expressed in             #
# factors of 2,3,5                                                     #
########################################################################

proc ::NAMDgui::pmegridsize { z } {
   set i 0
   set sign 1
   set div 2 
   while {$div>1} {
      set newz [expr $sign*$i+$z]
      set div [lindex [factorize $newz] 0]
      if {$sign==1} { incr i }
      set sign [expr -$sign]
   }
   return $newz
}



global env
source [file join $env(NAMDGUIDIR) namdgui_tclforces.tcl]



