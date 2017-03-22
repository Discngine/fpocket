#
# Molefacture -- structure building plugin
#
# $Id: molefacture.tcl,v 1.88 2007/07/12 22:19:20 petefred Exp $
#

package require idatm
package require readcharmmtop
package provide molefacture 1.1

namespace eval ::Molefacture:: {

   proc initialize {} {
      variable selectcolor lightsteelblue
      global env
      variable toplist
      set deftop [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]
      set toplist [::Toporead::read_charmm_topology $deftop]

      variable molidorig
      variable slavemode      0;  # Molefacture can be run as a slave for another application
      variable exportfilename "molefacture_save.xbgf"
      variable mastercallback {}; # When we are done editing in slavemode this callback of the master will be called

      variable origsel     {}
      variable origmolid "" ;# molid of parent molecule
      variable origseltext "" ;# Selection text used to start molefacture
#      variable cursel      {}
#      set cursel [atomselect top none]
      variable bondlist    {}
      variable anglelist   {}
      variable tmpmolid -1
      variable atommarktags {}
      variable ovalmarktags {}
      variable labelradius  0.2
      variable picklist     {}
      variable pickmode     "atomedit"
      variable totalcharge  0
      variable atomlistformat {}
      variable bondlistformat {}
      variable anglelistformat {}
      variable bondlength {}
      variable dihedral   0
      variable dihedmarktags {}
      variable projectsaved 1

      variable showvale     1
      variable showellp     1

      variable angle 0
      variable anglemarktags {}

#      variable lpmol
#      set lpmol [mol new]

      variable atomlist    {}
      variable oxidation {}
#      variable atomaddlist {}
      variable valencelist {}
      variable openvalencelist {}
      variable lonepairs {}
      variable vmdindexes {}
      variable chargelist {}
      variable molid      -1
      variable fragmentlist
      variable taglist
      variable templist
      variable atomlistformat
      variable bondtaglist
      variable bondlistformat
      variable aapath [file join $::env(MOLEFACTUREDIR) lib amino_acids]
      variable protlasthyd -1
      variable phi 0;# phi value for protein builder
      variable psi 0 ;# psi value for protein builder

      variable addfrags ;# Array containing paths to fragments for H replacement, indexed by fragment name
      variable basefrags ;# Array containing paths to fragments used for making new molecules, indexed by basefrag name

      variable periodic {{} H HE LI BE B C N O F NE NA MG AL SI P S CL AR K CA SC TI V CR MN FE CO \
			    NI CU ZN GA GE AS SE BR KR RB SR Y ZR NB MO TC RU RH PD AG CD IN SN SB \
			    TE I XE CS BA LA CE PR ND PM SM EU GD TB DY HO ER TM YB LU HF TA W RE OS \
			    IR PT AU HG TL PB BI PO AT RN}
      variable valence
      array set valence {{} {0} H {1} HE {0} \
			    LI {1} BE {2}  B {3}  C {4}  N {3}  O {2}  F {1} NE {0} \
			    NA {1} MG {2} AL {3} SI {4}  P {3 5}  S {2 6} CL {1} AR {0} \
			     K {1} CA {2} SC {0} TI {0}  V {0} CR {0} MN {0} FE {2 3 4 6} CO {0} NI {0} CU {0} ZN {0} \
			    GA {3} GE {4} AS {3} SE {2} BR {1} KR {0} \
	                    RB {1} SR {2}  Y {0} ZR {0} NB {0} MO {0} TC {0} RU {0} RH {0} PD {0} AG {0} CD {0} \
			    IN {3} SN {4} SB {3} TE {2}  I {1} XE {0} \
			    CS {1} BA {2} \
			    LA {0} CE {0} PR {0} ND {0} PM {0} SM {0} EU {0} GD {0} TB {0} DY {0} HO {0} ER {0} TM {0} YB {0} \
			    LU {0} HF {0} TA {0}  W {0} RE {0} OS {0} IR {0} PT {0} AU {0} HG {0} \
			    TL {0} PB {0} BI {0} PO {0} AT {0} RN {0}}
      variable octet
      array set octet {{} 0 H 2 HE 2 \
			  LI 8 BE 8 B 8 C 8 N 8 O 8 F 8 NE 8 NA 8 MG 8 AL 8 SI 8 P 10 S 8 CL 8 AR 8 \
			  K 18 CA 18 SC 18 TI 18 V 18 CR 18 MN 18 FE 18 CO 18 NI 18 CU 18 ZN 18 \
			  GA 18 GE 18 AS 18 SE 18 BR 18 KR 18 RB 18 SR 18 Y 18 ZR 18 \
			  NB 18 MO 18 TC 18 RU 18 RH 18 PD 18 AG 18 CD 18 IN 18 SN 18 SB 18 \
			  TE 18  I 18 XE 18 CS 32 BA 0 LA 0 CE 0 PR 0 ND 0 PM 0 SM 0 EU 0 GD 0 TB 0 DY 0 HO 0 ER 0 TM 0 YB 0 LU 0 HF 0 TA 0 W 0 RE 0 OS 0 \
			  IR 0 PT 0 AU 0 HG 0 TL 0 PB 0 BI 0 PO 0 AT 0 RN 0 }
   }

   variable availablehyd 0

   initialize

}


proc ::Molefacture::set_slavemode { callback filename } {
   variable slavemode 1
   variable exportfilename $filename
   variable mastercallback $callback
}

## Temporary gui for getting molefacture started
proc ::Molefacture::molefacture_start {} {

  if { [winfo exists .molefacstart] } {
    wm deiconify .molefacstart
    focus .molefacstart
    return
  }



   set w [toplevel ".molefacstart"]
   wm title $w "Molefacture - Molecule Builder"
   wm resizable $w 0 0
   variable atomsel

   set atomsel ""

   label $w.warning -text "Enter a selection below and click \"Start\" to start molefacture \nand edit the atoms of this selection. Please check the documentation \n(accessible through the Help menu) to learn how to use it." -width 55
   frame $w.entry
   label $w.entry.sel -text "Selection: "
   entry $w.entry.entry -textvar [namespace current]::atomsel 
   button $w.entry.go -text "Start Molefacture" -command "[namespace current]::molefacture_gui_aux $[namespace current]::atomsel; wm state $w withdrawn"

   pack $w.entry.sel $w.entry.entry $w.entry.go -side left -fill x
   pack $w.warning $w.entry
}

proc ::Molefacture::molefacture_gui_aux {seltext} {
#  puts "|$seltext|"
  if {$seltext == ""} {
    set mysel ""
  } elseif {$seltext == "index"} {
      tk_messageBox -icon error -type ok -title Error \
      -message "You entered a selection containing no atoms. If you want to create a new molecule, invoke molefacture with no selection. Otherwise, please make a selection containing at least one atom."
      return
  } else {
    set mysel [atomselect top "$seltext"]
    if {[$mysel num] > 200} {
      tk_messageBox -icon error -type ok -title Warning \
	       -message "The current version of molefacture is best used on structures of 200 atoms or smaller. Future versions will be able to handle larger structures. You may continue, but some features may work slowly. See the molefacture documentation for more details."
    }
  }

  variable origseltext
  set origseltext $seltext

  if {$seltext != ""} {
    variable origmolid
    set origmolid [molinfo top]
  }

  ::Molefacture::molefacture_gui $mysel
  if {$mysel != ""} {$mysel delete}
}

###################################################
# Clean up and quit the program.                  #
###################################################

proc ::Molefacture::done { {force 0} } {
   fix_changes
   variable projectsaved 
   variable slavemode
   #variable exportfilename

   if {!$projectsaved && !$force && !$slavemode} {
      set reply [tk_dialog .foo "Quit - save file?" "Quit Molefacture - Save molecule?" \
        questhead  0 "Save" "Don't save" "Cancel"]
      switch $reply {
	 0 { fix_changes; export_molecule_gui}
	 1 { }
	 2 { return 0 }
      }
   }

   # Make the master molecule visible again
   variable molidorig
   if {$molidorig != -1} {molinfo $molidorig set drawn 1}

   # Remove_traces
   foreach t [trace info variable vmd_pick_atom] {
      trace remove variable vmd_pick_atom write ::Molefacture::atom_picked_fctn
   }

   # Set mouse to rotation mode
   mouse mode 0
   mouse callback off; 

   if { [winfo exists .molefac] }    { wm withdraw .molefac }

   if {$slavemode} {
      variable exportfilename
      variable mastercallback
      variable atomlist
      variable bondlist
      fix_changes
      export_molecule $exportfilename
      $mastercallback $exportfilename
   }

   variable tmpmolid
   mol delete $tmpmolid

   # Cleanup
   if {[file exists Molefacture_tmpmol.xbgf]} { file delete Molefacture_tmpmol.xbgf }

   # Close molefacture
}

proc molefacture_tk {} {
  # If already initialized, just turn on
  if { [winfo exists .molefacstart] } {
    wm deiconify .molefacstart
  } else {
    ::Molefacture::molefacture_start
  }
  return .molefacstart
}

#Load all procs from other molefacture files
foreach lib { molefacture_builder.tcl \
              molefacture_state.tcl \
              molefacture_geometry.tcl \
              molefacture_gui.tcl \
              molefacture_edit.tcl \
              molefacture_internals.tcl } {
  if { [catch { source [file join $env(MOLEFACTUREDIR) $lib] } errmsg ] } {
    error "ERROR: Could not load molefacture library file $lib: $errmsg"
  }
}  

