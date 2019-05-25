#
# $Id: bossconvert.tcl,v 1.2 2013/04/15 15:34:24 johns Exp $
#
package provide bossconvert 1.0
package require exectool

namespace eval ::BOSSconvert:: {
    variable boss "BOSS"
    variable autozmat "autozmat"
    variable BOSSdirdefined 0
    variable haveBOSS 0
    variable haveTopology 0
    variable selection
    variable ZmatrixFile ""
    variable BOSSspcalcFile ""  
    variable TopologyExec "" 
    variable TopologyDir ""     


    proc BOSScite {} {
        puts "Running BOSS. Please cite: Jorgensen and Tirado-Rives, J. Comp. Chem., 26:1689-1700 (2005).\n"
    }

    proc Topologycite {} {
        puts "\nRunning Topology converter, courtesy of Markus K. Dalghren and Peter T. Dalghren\n"
    }

    proc checkforboss { } {
         foreach key [array names ::env] {
            if  { $key == "BOSSdir" && $::env($key) != "" && $::env($key) != " " } {
                set ::BOSSconvert::BOSSdirdefined 1
            }
         }
         if { $::BOSSconvert::BOSSdirdefined == 1 } {
            set ::BOSSconvert::boss [::ExecTool::find -description "BOSS" -path $::env(BOSSdir) "BOSS" ]
            set ::BOSSconvert::autozmat [::ExecTool::find -description "BOSS" -path $::env(BOSSdir) "autozmat" ]
         }
         if { [file executable $::BOSSconvert::boss] && [file executable $::BOSSconvert::autozmat] } {
            set ::BOSSconvert::haveBOSS 1
         }
    }

    proc checkTopology { } {
       set topologydirDefined 0
       foreach key [array names ::env] {
           if { $key == "VMDBOSSCONVERT" && $::env($key) != "" && $::env($key) != " " } {
             set topologydirDefined 1
           }
       }
       if { $topologydirDefined == 1 } {
          set ::BOSSconvert::TopologyDir  "$::env(VMDBOSSCONVERT)"
          set ::BOSSconvert::TopologyExec [::ExecTool::find -description "Topology" -path $::BOSSconvert::TopologyExec "Topology" ]
          if [catch {eval ::ExecTool::exec {$::BOSSconvert::TopologyExec}  } output errMsg] {
              error $errMsg
          } else {
            set ::BOSSconvert::haveTopology 1
          }
        }
    }

    proc init { } {
        variable haveBOSS
        if { [vmdinfo arch ] != "WIN64" && [vmdinfo arch] != "WIN32" } { 
            ::BOSSconvert::checkTopology
            ::BOSSconvert::checkforboss
        }
        #if { $haveBOSS == 0 } {
        #    puts "Could not execute BOSS or autozmat - check BOSS installation and make sure BOSSdir is defined in the environment"
        #}
    }

    init

}


proc ::BOSSconvert::gui {} {
    variable w
    variable haveBOSS
    variable haveTopology
    

    if { $haveTopology != 1 } {
        if { [vmdinfo arch ] == "WIN64" || [vmdinfo arch] == "WIN32" } { 
            set msg "The BOSSconvert is currenlty only available on Linux and OS X systems."
        } else {
            set msg "The Topology executable could not be found.\nPlease check your installation of VMD."
        }    
        tk_messageBox -message $msg -type ok -title "BOSSconvert Error" -icon error    
        return
    }



    if { [winfo exists .bossconvert] } {
        wm deiconify .bossconvert
        focus .bossconvert
        return
    }

    set w [toplevel .bossconvert]
    wm title $w "BOSSconvert"
    wm resizable $w 0 0

    frame $w.menubar -relief raised -bd 2
    menubutton $w.menubar.help -text "Help" -underline 0 -menu $w.menubar.help.menu
    $w.menubar.help config -width 5
    menu $w.menubar.help.menu -tearoff no
    $w.menubar.help.menu add command -label "Instructions"  -command {
        tk_messageBox -message "BOSSconvert employs the BOSS software (http://zarbi.chem.yale.edu/software.html) to parameterise molecules using OPLS and convert the paratemers to VMD/NAMD readable topology (.rtf) and parameter (.prm) files.\n\nUse BOX 1 to perform the parameterization using BOSS. Alternatively, use BOX 2 to convert the output of a previous BOSS parameterization.\n"\
           -type ok\
           -title "BOSSconvert instructions" -icon error  }
    $w.menubar.help.menu add command -label "More info"  -command { 
     vmd_open_url [string trimright [vmdinfo www] /]/plugins/bossconvert }
    pack $w.menubar.help -side right
    pack $w.menubar -fill x


#    frame $w.infotext 

#    label $w.infotext.text -text $t -wraplength 7c -bd 3 -justify left
#    pack $w.infotext.text -side top
#    pack $w.infotext -side left

    labelframe $w.box1 -relief ridge -text "BOX 1: OPLS parameterization using BOSS" -bd 2 -padx 2m -pady 2m
    if { $haveBOSS != 1 } {
        set noBossMsg "It appears that you do not have BOSS installed.\nIf you do, make sure that the BOSSdir\nenvironment variable is defined and restart VMD.\n"
        label $w.box1.msg -text $noBossMsg  -width 48
        grid $w.box1.msg 

    } else {
        label $w.box1.seltext -text "     Selection:" 
        entry $w.box1.sel -textvar sel -width 35
        label $w.box1.chargetext -text "        Charge:" 
        radiobutton $w.box1.q0 -text "0" -value "0" -variable charge 
        radiobutton $w.box1.q1 -text "-1" -value "-1" -variable charge
        radiobutton $w.box1.q2 -text "+1" -value "+1" -variable charge
        label $w.box1.prefixtext -text "         Prefix:" 
        entry $w.box1.pref -textvar prefix1 -width 35
        label $w.box1.moltext -text "    Molecule:"
        entry $w.box1.mol -textvar mol -width 4
        button $w.box1.run -text "Run" -command { ::BOSSconvert::BOX1run $sel $charge $prefix1 $mol } -width 5
        button $w.box1.clear -text "Clear" -command { set charge 0; set sel ""; set prefix1 ""; set mol "top"} -width 5
        if {$haveBOSS != 1} {
            $w.box1.sel configure -state disabled
            $w.box1.q0 configure -state disabled
            $w.box1.q1 configure -state disabled
            $w.box1.q2 configure -state disabled
            $w.box1.pref configure -state disabled
            $w.box1.run configure -state disabled
            $w.box1.clear configure -state disabled
            $w.box1.mol configure -state disabled
        }
        grid $w.box1.seltext -row 0 -column 0 
        grid $w.box1.sel -row 0 -column 1 -columnspan 3 
        grid $w.box1.chargetext -row 1 -column 0
        grid $w.box1.q0 -row 1 -column 1 
        grid $w.box1.q1 -row 1 -column 2 
        grid $w.box1.q2 -row 1 -column 3
        grid $w.box1.prefixtext -row 2 -column 0
        grid $w.box1.pref -row 2 -column 1 -columnspan 3
        grid $w.box1.moltext -row 3 -column 0 
        grid $w.box1.mol -row 3 -column 1 -sticky ew
        grid $w.box1.run -row 3 -column 2 
        grid $w.box1.clear -row 3 -column 3  

        $w.box1.q0 select
        while { [$w.box1.mol get] != "" } {
            $w.box1.mol delete 0 
        }
        set a [$w.box1.mol insert 0 "top"]
    #    pack $w.box1 -fill x -padx 2 -pady 2 -side right
    }

    labelframe $w.box2 -relief ridge -text "BOX 2: Convert BOSS output" -bd 2 -padx 1m -pady 1m
    label $w.box2.zmatfiletext -text "BOSS Z-matrix:"
    entry $w.box2.zmatfile -textvar zmatfile
    button $w.box2.zmatfilebrowse -text "Browse" -command {set zmatfile [tk_getOpenFile -title "Select BOSS Z-Matrix file"]}
    label $w.box2.bossouttext  -text "   BOSS output:" 
    entry $w.box2.bossout -textvar bossout
    button $w.box2.bossoutbrowse -text "Browse" -command { set bossout [tk_getOpenFile -title "Select BOSS output file"]}
    label $w.box2.prefixtext -text "             Prefix:" 
    entry $w.box2.pref -textvar prefix2 -width 35
    button $w.box2.run -text "Run" -command { ::BOSSconvert::BOX2run $prefix2 $zmatfile $bossout } -width 5
    button $w.box2.clear -text "Clear" -command { set zmatfile ""; set bossout ""; set prefix2 ""} -width 5
    grid $w.box2.zmatfiletext -row 0 -column 0    
    grid $w.box2.zmatfile -row 0 -column 1 -columnspan 2
    grid $w.box2.zmatfilebrowse -row 0 -column 3    
    grid $w.box2.bossouttext -row 1 -column 0    
    grid $w.box2.bossout -row 1 -column 1 -columnspan 2
    grid $w.box2.bossoutbrowse -row 1 -column 3    
    grid $w.box2.prefixtext -row 2 -column 0
    grid $w.box2.pref -row 2 -column 1 -columnspan 3 -sticky nsew
    grid $w.box2.run -row 3 -column 2 
    grid $w.box2.clear -row 3 -column 3  

    pack $w.box1 $w.box2  -padx 2 -pady 2 
}


proc ::BOSSconvert::BOX1run { sel charge prefix mol } {

    if { $sel == "" } {
        tk_messageBox -message "Enter text for atom selection." -type ok -title "BOSSconvert Error" -icon error    
        return
        
    }

    if { $charge == "" } {
        tk_messageBox -message "Select charge (-1,0,+1)." -type ok -title "BOSSconvert Error" -icon error    
        return
        
    }

    if { $prefix == "" } {
        tk_messageBox -message "Enter a prefix for output files (prefix.rtf, prefix.prm, prefix.pdb, prefix.psf)." -type ok -title "BOSSconvert Error" -icon error    
        return
    }

    if { $prefix == "" } {
        tk_messageBox -message "Enter a molecule id." -type ok -title "BOSSconvert Error" -icon error    
        return
        
    }
    set errno [catch { set a [atomselect $mol $sel] } msg]
    if { $errno != 0 } {
        tk_messageBox -message "atomselect error ($msg): Check selection text and molecule id." -type ok -title "BOSSconvert Error" -icon error    
        return
    } else {
        $a delete
    }

    set d [file dirname $prefix]
    if { ![file exists $d] || ![file writable $d] } {
        tk_messageBox -message "Invalid prefix, check that $d exists and that you have write access." -type ok -title "BOSSconvert Error" -icon error    
        return
    }
    

    ::BOSSconvert::run $sel $charge $prefix $mol
    
}

proc ::BOSSconvert::BOX2run { prefix zmatfile bossout } {
    if { $prefix == "" } {
        tk_messageBox -message "Enter a prefix for output files (prefix.rtf, prefix.prm)." -type ok -title "BOSSconvert Error" -icon error    
        return
    }    

    set d [file dirname $prefix]
    if { ![file exists $d] || ![file writable $d] } {
        tk_messageBox -message "Invalid prefix, check that $d exists and that you have write access." -type ok -title "BOSSconvert Error" -icon error    
        return
    }

    if { ![file exists $zmatfile] } {
        tk_messageBox -message "BOSS Z-matrix file $zmatfile not found." -type ok -title "BOSSconvert Error" -icon error    
        return
    }

    if { ![file exists $zmatfile] } {
        tk_messageBox -message "BOSS output file $bossout not found." -type ok -title "BOSSconvert Error" -icon error    
        return
    }


    ::BOSSconvert::createPRMTOP $prefix $zmatfile $bossout 
}

proc ::BOSSconvert::run { selectiontext charge prefix {mol top}} {
    set sel [atomselect $mol $selectiontext]
    set createresult [::BOSSconvert::createBossFiles $sel $charge]

    if { $createresult != "" } {
        $sel delete
        return -1       
    }

    set convertresult [::BOSSconvert::createPRMTOP $prefix]

    if { $convertresult != "" } {
        $sel delete
        return -1
    }

    ::BOSSconvert::createPDBPSF $selectiontext $prefix $mol
    $sel delete
    
    puts "\n"
    puts "Parameters written to $prefix.prm"
    puts "Topology written to $prefix.rtf"
    puts "PDB file written: $prefix.pdb"
    puts "PSF file written: $prefix.psf"

}



proc ::BOSSconvert::createBossFiles { selection charge } {
    variable autozmat
    variable boss
    variable haveBOSS
    variable ZmatrixFile 
    variable BOSSspcalcFile 
    if { $haveBOSS != 1 } {
        puts "BOSS was not located. Install BOSS and make sure \$BOSSdir is correctly defined"
        return -1
    }

    set pdbname "BOSSconvert_tmpfile.pdb"
    set integercharge 0
    if { [$selection num] == 0 } {
        puts "BOSSconvert error: No atoms in selection"
        return -1
    }
    #set c [vecsum [$selection get charge]]
    #set intC [expr int($c)]
    #if { [expr abs($c-$intC)] < 0.01 } {
    #    set integercharge 1
    #}

    #if { $integercharge == 0} {
    #    puts "BOSSconvert error: Selection has non-integer charge"   
    #    return -1
    #}

    if { [expr abs($charge)] > 1 } {
        puts "BOSSconvert error: Total charge must be -1,0,+1"
        return -1
    }

    set AM1SPcmd "AM1SPcmd"
    if { $charge == -1} {
        set AM1SPcmd "AM1SP-cmd"
    } elseif { $charge == +1} {
        set AM1SPcmd "AM1SP+cmd"
    }
    set AM1SPcmd [file join $::env(BOSSdir) scripts $AM1SPcmd]
    set SPMcmd [file join $::env(BOSSdir) scripts SPMcmd]

    if { ![file exists $AM1SPcmd] } {
        puts "BOSScovert error: did not find $AM1SPcmd"
        return -1
    }
    if { ![file exists $SPMcmd] } {
        puts "BOSScovert error: did not find $SPMcmd"
        return -1
    }

    ::BOSSconvert::BOSScite

    $selection writepdb $pdbname
    catch { exec $autozmat -i pdb -z default $pdbname > optzmat } bossexecerror
    catch { exec csh $AM1SPcmd } AM1SPcmderror
    file delete optzmat
    file delete plt.pdb
    file rename sum optzmat
    catch { exec csh $SPMcmd } SPMcmderror
    #file rename sum "BOSSconvert_tmpfile.z"
    file delete plt.pdb
    file delete optzmat
    #file rename out "BOSSconvert_tmpfile.bossout"
    file delete $pdbname
 
    set fi [open sum r]
    set ZmatrixFile [read $fi]
    close $fi
    set fi [open out r]
    set BOSSspcalcFile [read $fi]
    close $fi
    file delete sum
    file delete out
     #puts "$execerror"
}


proc ::BOSSconvert::createPRMTOP { prefix {zmatrixfilename ""} {bossoutputname ""} } {
    variable ZmatrixFile 
    variable BOSSspcalcFile 
    variable TopologyExec
    variable TopologyDir

    set prmname BOSSconvert_tmpmol.prm
    set rtfname BOSSconvert_tmpmol.rtf

    if { $zmatrixfilename == "" && $bossoutputname == "" } {
        if { $ZmatrixFile == "" || $BOSSspcalcFile == "" } {
            puts "BOSSconvert error: generatePRMTOP must be run after createBossFiles or with zmatrixfilename and bossoutputname parameters"
            return -1
        }
        set fo [open "BOSSconvert_tmpmol.z" w]
        puts $fo "$ZmatrixFile"
        close $fo
        set fo [open "BOSSconvert_tmpmol.bossout" w]
        puts $fo "$BOSSspcalcFile"
        close $fo
        set zmatrixfilename BOSSconvert_tmpmol.z
        set bossoutputname BOSSconvert_tmpmol.bossout
    } elseif { $zmatrixfilename == "" || $bossoutputname == ""  } {
        puts "BOSSconvert error: need to specify both zmatrixfilename and bossoutpuname parameters or neither"
        return -1
    } else {
        set sl [string length $zmatrixfilename]
        if { [string range $zmatrixfilename [expr $sl-2] [expr $sl-1]] != ".z" } {
            puts "BOSSconvert error: zmatrixfilename must end in .z"
            return -1
        }
        set prmname [string range $zmatrixfilename 0 [expr $sl-2]]
        set rtfname "${prmname}rtf"
        set prmname "${prmname}prm"
    }
   
    ::BOSSconvert::Topologycite
    set Topologycmd $TopologyExec
    append Topologycmd " -bossout $bossoutputname"
    append Topologycmd " -oplspar [file join $TopologyDir oplsaa.par]"
    append Topologycmd " -oplssb [file join $TopologyDir oplsaa.sb]"
    append Topologycmd " -imprlist [file join $TopologyDir imprlist]"
    append Topologycmd " $zmatrixfilename"

    if [catch {eval ::ExecTool::exec $Topologycmd } output err] {
            error $err
    }

    set data [split $output "\n"]
    set natoms [lindex [split [lindex $data 0] " "] 0]
    set nbonds [lindex [split [lindex $data 1] " "] 0]
    set nangles [lindex [split [lindex $data 2] " "] 0]
    set ndihedrals [lindex [split [lindex $data 3] " "] 0]
    set nimpropers [lindex [split [lindex $data 4] " "] 0]
    puts "atoms=$natoms"
    puts "bonds=$nbonds"
    puts "angles=$nangles"
    puts "dihedrals=$ndihedrals"
    puts "impropers=$nimpropers"
    
    set fi [open alias r]
    set aliasfile [read $fi]
    close $fi
    set fi [open missingbonds r]
    set missingbondsfile [read $fi]
    close $fi
    file rename -force $rtfname $prefix.rtf
    file rename -force $prmname $prefix.prm
    puts ""
    puts "aliases used for OPLS atom types:"
    puts "$aliasfile"
    file delete alias
    file delete missingbonds

    if { $missingbondsfile != "" } {
        puts "Missing bonds: "
        puts $missingbondsfile
    }

    if {$zmatrixfilename == "BOSSconvert_tmpmol.z"} {
        file delete $zmatrixfilename
    }
    if {$bossoutputname == "BOSSconvert_tmpmol.bossout"} {
        file delete $bossoutputname
    }

    puts "Topology written to $prefix.rtf"
    puts "Parameters written to $prefix.prm"
    
}

proc ::BOSSconvert::renameAtoms { seltext rtffile {mol top} } {

    set sel [atomselect $mol "$seltext"]
    
    set fi [open $rtffile r]
    set data [split [read $fi] "\n"]
    close $fi
    
    set anames [list]
    set atypes [list]
    set acharges [list]
    foreach line $data {
        if { [string first "ATOM" $line] != -1} {
            set name [lindex $line 1]
            set type [lindex $line 2]
            set charge [lindex $line 3]
            lappend anames $name
            lappend atypes $type
            lappend acharges $charge
        } elseif { [string first "RESI" $line] != -1 } {
            set resname [lindex [split $line " "] 1]
        }
    }

    puts "Types: $atypes"
    puts "Charges: $acharges"
    $sel set name $anames
    $sel set type $atypes
    $sel set charge $acharges
    $sel delete
}

proc ::BOSSconvert::createPDBPSF { seltext prefix {mol top} } {
    variable autozmat
    variable boss
    variable haveBOSS
    variable ZmatrixFile 
    variable BOSSspcalcFile 
    if { $haveBOSS != 1 } {
        puts "BOSS was not located. Install BOSS and make sure \$BOSSdir is correctly defined"
        return -1
    }

    set rtfname "${prefix}.rtf"
    set pdbname "${prefix}.pdb"
    set psfname "${prefix}.psf"

    set xZPDB [file join $::env(BOSSdir) scripts xZPDB]

    if { ![file exists $xZPDB] } {
        puts "BOSScovert error: did not find $xZPDB"
        return -1
    }

    set topmol [molinfo top]

    if { $ZmatrixFile == ""  || ![file exists $rtfname]} {
        puts "BOSSconvert error: need to run createBossFiles and createPRMTOP first"
        return -1
    }
    set fo [open "${prefix}.z" w]
    puts $fo $ZmatrixFile
    close $fo

    ::BOSSconvert::BOSScite

    catch { exec $xZPDB $prefix } bossexecerror
    
    set m [mol new $pdbname]
    set a [atomselect $m all]
    set segname [lindex [$a get segname] 0]
    if { $segname == "" } {
        set segname "A"
        $a set segname $segname
    }
    $a writepdb $pdbname
    $a delete
    mol delete $m
    
    set BOSScontext [psfcontext create]
    psfcontext eval $BOSScontext { 
      resetpsf
      topology $rtfname
      segment $segname {
        pdb $pdbname
        first none
        last none
        auto angles dihedrals
      }
      coordpdb $pdbname
      writepsf $psfname
      writepdb $pdbname
    }

    set m [mol new $psfname]
    mol addfile $pdbname waitfor all
    
    file delete "${prefix}.z"
    file delete "out"
    mol top $topmol 
    
}

proc bossconvert_tk {} {
  ::BOSSconvert::gui
  return $::BOSSconvert::w
}

