# Prepares input files to run dowser

# TODO:
#
# - convert_na_resnames
#   * test for DNA
#
# - convert_na_termini
#   * when using fragment, give more info about which residues will be 
#     changed (chain, segname)
#   * update fragment code with the latest addition to the chain code,
#     that supports DNA: done, need testing
#   * code up the option to use autopsf's way of guessing the chain
#   * test DNA support
#
# - maybe add hydrogens to MO? before running dowser? (in the future)
#
# - need to further test modify_mo_residues and convert_mo_mg_water
#
# - maybe have a list of all entries in the dowser dictionary and test if 
#   we'll have troubles beforehand
#
# - Write the processing stuff to a log file: how to deal with psfgen?
#
# - rundowser at the command-line...
# 
# - when combining waters, need to allow for deletion of crystal waters
#   (the defaults should be set according to options used when running
#    dowser)
#
# - do we need to make sure the proteins have unique ids?
#
# - catch error if user tries to run dowser before processing file


package require exectool 1.2
package require readcharmmtop
package require psfgen
package provide dowser 1.0

namespace eval ::Dowser:: {

  variable moResidueCutoff 3.25 ;# to decide if a water coordinates a Mg2+
  variable waterTopologyFile 
  variable debug 1
  variable dowserManual "http://hekto.med.unc.edu:8080/HERMANS/software/DOWSER/Dowman.htm"
  variable defaultArgHetero 0
  variable defaultArgProbe "0.2"
  variable defaultArgSeparation "1.0"
  variable defaultArgXtal "default"

}

proc ::Dowser::init_water_topology {} {
  global env
  variable waterTopologyFile

  set waterTopologyFile [file join $env(CHARMMTOPDIR) top_all27_prot_lipid_na.inp]

}

#######################################################################
#                         CONVERT RESNAMES 
#######################################################################

proc ::Dowser::convert_resnames_usage { } {
  puts "Converts residue names to comply with dowser conventions."
  puts "Usage: convert_resnames -pdb <input pdb file> -o <output pdb file> ?options?"
  puts "Options:"
  puts "   -psf <input psf file>"
  return
}

proc ::Dowser::convert_resnames { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_resnames_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_resnames_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_resnames_usage
    error "ERROR: Input PDB file not specified."
  } elseif { [info exists arg(psf)] } {
    set molid [mol new $arg(psf) waitfor all]
    mol addfile $arg(pdb) waitfor all molid $molid
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_resnames_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  puts ""
  puts "Dowser) ********************************************"
  puts "Dowser) Converting non-nucleic acid residue names..."
  puts "Dowser) ********************************************"
  puts ""

  # Water molecules
  set sel [atomselect $molid "water"]
  $sel set resname "HOH"
  $sel delete

  # POT -> K
  set sel [atomselect $molid "resname POT"]
  $sel set resname "K"
  $sel delete

  # ZN2 -> ZN
  set sel [atomselect $molid "resname ZN2"]
  $sel set resname "ZN"
  $sel delete

  # CAL -> CA
  set sel [atomselect $molid "resname CAL"]
  $sel set resname "CA"
  $sel delete

  # (HSD|HSE|HSP) -> HSP
  set sel [atomselect $molid "resname HSD HSE HSP"]
  $sel set resname "HIS"
  $sel delete

  # The following cases are more specific to our own work

  # CYN -> CYS (CYN: unprotonated cysteine for zinc fingers)
  set sel [atomselect $molid "resname CYN"]
  $sel set resname "CYS"
  $sel delete

  puts -nonewline "Dowser) Writing file $outFile with converted non-nucleic acid residue names... "
  set all [atomselect $molid all]
  $all writepdb "$outFile"
  $all delete
  puts "Done."

  mol delete $molid

  return

}

#######################################################################
#                       CONVERT NA RESNAMES 
#######################################################################

proc ::Dowser::convert_na_resnames_usage { } {
  puts "Converts nucleic acid residue names from 3- to 1-letter codes:"
  puts "RNA:"
  puts "  ADE -> A"
  puts "  CYT -> C"
  puts "  GUA -> G"
  puts "  URA -> U"
  puts "DNA:"
  puts "  ADE -> DA"
  puts "  CYT -> DC"
  puts "  GUA -> DG"
  puts "  THY -> DT"
  puts "Usage: convert_na_resnames -pdb <input pdb file> -o <output pdb file> ?options?"
  puts "Options:"
  puts "   -psf <psf file>"
  puts "   -na \[rna|dna|auto\] (default: auto)"
  return
}

proc ::Dowser::convert_na_resnames { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_na_resnames_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_na_resnames_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -o { set arg(o) $val }
      -na { set arg(na) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_na_resnames_usage
    error "ERROR: Input PDB file not specified."
  } elseif { [info exists arg(psf)] } {
    set molid [mol new $arg(psf) waitfor all]
    mol addfile $arg(pdb) waitfor all molid $molid
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_na_resnames_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  if { [info exists arg(na)] } {
    if { $arg(na) == "rna" } {
      set naType "rna"
    } elseif { $arg(na) == "dna" } {
      set naType "dna"
    } elseif { $arg(na) == "auto" } {
      set naType "auto"
    } else {
      error "ERROR: invalid value for option -na: $arg(na)"
    }
  } else {
    set naType "auto"
  }

  puts ""
  puts "Dowser) ****************************************"
  puts "Dowser) Converting nucleic acid residue names..."
  puts "Dowser) ****************************************"
  puts ""

  # First test if we have nucleic acid residues at all
  set sel [atomselect $molid "resname A C T G U ADE CYT THY GUA URA"]
  set naNum [$sel num]
  $sel delete
  if { $naNum == 0 } {
    puts "Dowser) No nucleic acid residues were detected when processing the residue names."
  } elseif { $naType == "dna" } {
    set sel [atomselect $molid "resname U URA"]
    if { [$sel num] > 0 } {
      puts "Dowser) Waning: Found U or URA residue(s), but the nucleic acid type was set to DNA. These residues will be treated as RNA."
      $sel set resname "U"
    }
    $sel delete

    set sel [atomselect $molid "resname A ADE"]
    $sel set resname "DA"
    $sel delete

    set sel [atomselect $molid "resname T THY"]
    $sel set resname "DT"
    $sel delete

    set sel [atomselect $molid "resname C CYT"]
    $sel set resname "DC"
    $sel delete

    set sel [atomselect $molid "resname G GUA"]
    $sel set resname "DG"
    $sel delete

  } elseif { $naType == "rna" } {
    puts "Dowser) All nucleic acid residues will be assumed to be RNA."

    set sel [atomselect $molid "resname DA DT DC DG"]
    if { [$sel num] > 0 } {
      puts "Dowser) Warning: Found residue(s) DA or DT or DC or DG, but nucleic acid type was set to RNA. These residues will be treated as DNA."
    }
    $sel delete

    set sel [atomselect $molid "resname T THY"]
    if { [$sel num] > 0 } {
      puts "Dowser) Warning: Found T or THY residue(s), but nucleic acid type was set to RNA. Could it be an RNA modification? These residues will be treated as DNA."
      $sel set resname "DT"
    }
    $sel delete
    
    set sel [atomselect $molid "resname ADE"]
    $sel set resname "A"
    $sel delete

    set sel [atomselect $molid "resname CYT"]
    $sel set resname "C"
    $sel delete

    set sel [atomselect $molid "resname GUA"]
    $sel set resname "G"
    $sel delete

    set sel [atomselect $molid "resname URA"]
    $sel set resname "U"
    $sel delete

  } elseif { $naType == "dna" } {
    puts "Dowser) All nucleic acid residues will be assumed to be DNA."
  } else {
    set sel [atomselect $molid "resname A ADE"]
    if { [$sel num] > 0 } {
      puts -nonewline "Dowser) Converting residues ADE ... "
      set selResNum [llength [lsort -unique [$sel get residue]]]
      #set selP [atomselect $molid {(resname A ADE) and name P}]
      #set selResNum [$selP num]
      #$selP delete
      set selO2 [atomselect $molid {(resname A ADE) and (name 'O2\'' 'O2*')}]
      set selO2Num [$selO2 num]
      $selO2 delete
      if { $selResNum == $selO2Num } {
        # we only have RNA
        $sel set resname "A"
      } elseif { $selO2Num == 0 } {
        # we only have DNA
        $sel set resname "DA"
      } else {
        foreach residue [$sel get residue] {
          set selResidue [atomselect $molid "residue $residue"]
          set selResidueO2 [atomselect $molid {residue $residue and name 'O2\'' 'O2*'}]
          if { [$selResidueO2 num] > 0 } {
            # is RNA
            $selResidue set resname "A"
          } else {
            # is DNA
            $selResidue set resname "DA"
          }
          $selResidue delete
          $selResidueO2 delete
        }
      }
      puts "Done."
    }
    $sel delete

    set sel [atomselect $molid "resname C CYT"]
    if { [$sel num] > 0 } {
      puts -nonewline "Dowser) Converting residues CYT ... "
      set selResNum [llength [lsort -unique [$sel get residue]]]
      #set selP [atomselect $molid {(resname C CYT) and name P}]
      #set selResNum [$selP num]
      #$selP delete
      set selO2 [atomselect $molid {(resname C CYT) and (name 'O2\'' 'O2*')}]
      set selO2Num [$selO2 num]
      $selO2 delete
      if { $selResNum == $selO2Num } {
        # we only have RNA
        $sel set resname "C"
      } elseif { $selO2Num == 0 } {
        # we only have DNA
        $sel set resname "CT"
      } else {
        foreach residue [$sel get residue] {
          set selResidue [atomselect $molid "residue $residue"]
          set selResidueO2 [atomselect $molid {residue $residue and name 'O2\'' 'O2*'}]
          if { [$selResidueO2 num] > 0 } {
            # is RNA
            $selResidue set resname "C"
          } else {
            # is DNA
            $selResidue set resname "DC"
          }
          $selResidue delete
          $selResidueO2 delete
        }
      }
      puts "Done."
    }
    $sel delete
 
    set warningThyRNA 0
    set sel [atomselect $molid "resname T THY"]
    if { [$sel num] > 0 } {
      puts -nonewline "Dowser) Converting residues THY ... "
      set selO2 [atomselect $molid {(resname T THY) and (name 'O2\'' 'O2*')}]
      set selO2Num [$selO2 num]
      $selO2 delete
      if { $selO2Num == 0 } {
        # we only have DNA
        $sel set resname "DT"
      } else {
        foreach residue [$sel get residue] {
          set selResidue [atomselect $molid "residue $residue"]
          set selResidueO2 [atomselect $molid {residue $residue and name 'O2\'' 'O2*'}]
          if { [$selResidueO2 num] > 0 } {
            # is RNA
            $selResidue set resname "DT"
            set warningThyRNA 1
          } else {
            # is DNA
            $selResidue set resname "DT"
          }
          $selResidue delete
          $selResidueO2 delete
        }
        if $warningThyRNA {
          puts ""
          puts "Dowser) Warning: THY residues with an O2' atom will be treated as DNA. This seems like an RNA modification, but it is not supported by Dowser."
        }
      }
      puts "Done."
    }
    $sel delete

    set sel [atomselect $molid "resname G GUA"]
    if { [$sel num] > 0 } {
      puts -nonewline "Dowser) Converting residues GUA ... "
      set selResNum [llength [lsort -unique [$sel get residue]]]
      #set selP [atomselect $molid {(resname G GUA) and name P}]
      #set selResNum [$selP num]
      #$selP delete
      set selO2 [atomselect $molid {(resname G GUA) and (name 'O2\'' 'O2*')}]
      set selO2Num [$selO2 num]
      $selO2 delete
      if { $selResNum == $selO2Num } {
        # we only have RNA
        $sel set resname "G"
      } elseif { $selO2Num == 0 } {
        # we only have DNA
        $sel set resname "DG"
      } else {
        foreach residue [$sel get residue] {
          set selResidue [atomselect $molid "residue $residue"]
          set selResidueO2 [atomselect $molid {residue $residue and name 'O2\'' 'O2*'}]
          if { [$selResidueO2 num] > 0 } {
            # is RNA
            $selResidue set resname "G"
          } else {
            # is DNA
            $selResidue set resname "DG"
          }
          $selResidue delete
          $selResidueO2 delete
        }
      }
      puts "Done."
    }
    $sel delete

    set warningUraDNA 0
    set sel [atomselect $molid "resname U URA"]
    if { [$sel num] > 0 } {
      puts -nonewline "Dowser) Converting residues URA ... "
      set selResNum [llength [lsort -unique [$sel get residue]]]
      #set selP [atomselect $molid {(resname U URA) and name P}]
      #set selResNum [$selP num]
      #$selP delete
      set selO2 [atomselect $molid {(resname U URA) and (name 'O2\'' 'O2*')}]
      set selO2Num [$selO2 num]
      $selO2 delete
      if { $selResNum == $selO2Num } {
        # We only have RNA
        $sel set resname "U"
      } else {
        foreach residue [$sel get residue] {
          set selResidue [atomselect $molid "residue $residue"]
          set selResidueO2 [atomselect $molid {residue $residue and name 'O2\'' 'O2*'}]
          if { [$selResidueO2 num] > 0 } {
            # is RNA
            $selResidue set resname "U"
          } else {
            # is DNA
            $selResidue set resname "U"
            set warningUraDNA 1
          }
          $selResidue delete
          $selResidueO2 delete
        }
        if $warningUraDNA {
          puts ""
          puts "Dowser) Warning: URA residues without an O2' atom will be treated as RNA."
        }
      }
      puts "Done."
    }
    $sel delete
  }

  puts -nonewline "Writing file $outFile with converted nucleic acid residues names... "
  set all [atomselect $molid all]
  $all writepdb "$outFile"
  $all delete
  puts "Done."

  mol delete $molid

  return
}

#######################################################################
#                          CONVERT NAMES 
#######################################################################

proc ::Dowser::convert_names_usage { } {
  puts "Converts atom names to be consistent with dowser conventions."
  puts "Usage: convert_names -pdb <input pdb file> -o <output pdb file> ?options?"
  puts "Options:"
  puts "   -psf <input psf file>"
  return
}

#
# Convert atom names to be consistent with Dowser naming. There's not 
# really a need to convert hydrogen atom names, since Dowser will place 
# them if needed.
#
proc ::Dowser::convert_names { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_names_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_names_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_names_usage
    error "ERROR: Input PDB file not specified."
  } elseif { [info exists arg(psf)] } {
    set molid [mol new $arg(psf) waitfor all]
    mol addfile $arg(pdb) waitfor all molid $molid
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_names_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  puts ""
  puts "Dowser) *****************************************"
  puts "Dowser) Converting non-nucleic acid atom names..."
  puts "Dowser) *****************************************"
  puts ""

  # Water oxygen
  set sel [atomselect $molid "water and oxygen"]
  $sel set name "OW"
  $sel delete

  # POT -> K
  set sel [atomselect $molid "name POT"]
  $sel set name "K"
  $sel delete

  # ILE CD -> CD1
  set sel [atomselect $molid "resname ILE and name CD"]
  $sel set name "CD1"
  $sel delete

  # CTER 
  # CHARMM: OT1 -> O, OT2 -> OT 
  # PDB: OXT -> OT
  set sel [atomselect $molid "name OT1"]
  $sel set name "O"
  $sel delete
  set sel [atomselect $molid "name OT2 OXT"]
  $sel set name "OT"
  $sel delete

  # Protein N-terminus
  # ------------------
  #
  # Will dowser replace these hydrogens? If so, it doesn't matter
  #
  # Yeah, it doesn't matter. But need to test for proline
  # 
  # Dowser uses by default NH3:
  #
  # RESIDUE NH3
  # ATOM NH3  H    NOT  N     0.000    0.0    0.0   0.248 H
  # ATOM NH3  N    H    CA    1.000    0.0    0.0   0.129 N
  # ATOM NH3  H2   N    NOT   1.000  109.5  -60.0   0.248 H
  # ATOM NH3  H3   N    NOT   1.000  109.5   60.0   0.248 H
  #
  # CHARMM patches:
  #
  # PRES NTER         1.00 ! standard N-terminus
  # GROUP                  ! use in generate statement
  # ATOM N    NH3    -0.30 !
  # ATOM HT1  HC      0.33 !         HT1
  # ATOM HT2  HC      0.33 !     (+)/
  # ATOM HT3  HC      0.33 ! --CA--N--HT2
  # ATOM CA   CT1     0.21 !   |    \
  # ATOM HA   HB      0.10 !   HA    HT3
  # DELETE ATOM HN
  # BOND HT1 N HT2 N HT3 N
  # DONOR HT1 N
  # DONOR HT2 N
  # DONOR HT3 N
  # IC HT1  N    CA   C     0.0000  0.0000  180.0000  0.0000  0.0000
  # IC HT2  CA   *N   HT1   0.0000  0.0000  120.0000  0.0000  0.0000
  # IC HT3  CA   *N   HT2   0.0000  0.0000  120.0000  0.0000  0.0000
  #
  # 
  # PRES GLYP         1.00 ! Glycine N-terminus
  # GROUP                  ! use in generate statement
  # ATOM N    NH3    -0.30 !
  # ATOM HT1  HC      0.33 !   HA1   HT1
  # ATOM HT2  HC      0.33 !   | (+)/
  # ATOM HT3  HC      0.33 ! --CA--N--HT2
  # ATOM CA   CT2     0.13 !   |    \
  # ATOM HA1  HB      0.09 !   HA2   HT3
  # ATOM HA2  HB      0.09 !
  # DELETE ATOM HN
  # BOND HT1 N HT2 N HT3 N
  # DONOR HT1 N
  # DONOR HT2 N
  # DONOR HT3 N
  # IC HT1  N    CA   C     0.0000  0.0000  180.0000  0.0000  0.0000
  # IC HT2  CA   *N   HT1   0.0000  0.0000  120.0000  0.0000  0.0000
  # IC HT3  CA   *N   HT2   0.0000  0.0000  120.0000  0.0000  0.0000
  # 
  # PRES PROP         1.00 ! Proline N-Terminal
  # GROUP                  ! use in generate statement
  # ATOM N    NP     -0.07 !   HA
  # ATOM HN1  HC      0.24 !   |
  # ATOM HN2  HC      0.24 !  -CA   HN1
  # ATOM CD   CP3     0.16 !  /  \ /
  # ATOM HD1  HA      0.09 !       N(+)
  # ATOM HD2  HA      0.09 !      / \
  # ATOM CA   CP1     0.16 !  -CD    HN2
  # ATOM HA   HB      0.09 !   | \
  # BOND HN1 N HN2 N       !  HD1 HD2
  # DONOR HN1 N
  # DONOR HN2 N
  # IC HN1  CA   *N   CD    0.0000  0.0000  120.0000  0.0000  0.0000
  # IC HN2  CA   *N   HN1   0.0000  0.0000  120.0000  0.0000  0.0000
  #
  
  # CYA (Cysteine charged into CCA-3' of tRNA)
  # Need to rename hydrogens in N-terminus
  # This assumes an NTER patch has been applied. If this is not the 
  # case, Dowser will guess the position of the hydrogens anyway
  set selTest [atomselect $molid "resname CYA"]
  if { [$selTest num] > 0 } {
    set sel [atomselect $molid "resname CYA and name HT1"]
    $sel set name "H"
    $sel delete
    set sel [atomselect $molid "resname CYA and name HT2"]
    $sel set name "H2"
    $sel delete
    set sel [atomselect $molid "resname CYA and name HT3"]
    $sel set name "H3"
    $sel delete
  }
  $selTest delete

  puts -nonewline "Dowser) Writing file $outFile with converted non-nucleic acid atom names... "

  set all [atomselect $molid "all"]
  $all writepdb "$outFile"
  $all delete

  puts "Done."

  mol delete $molid

  return

}

#######################################################################
#                         CONVERT NA NAMES 
#######################################################################

proc ::Dowser::convert_na_names_usage { } {
  puts "Converts primes (') to asteriks (*) in nucleic acid atom names"
  puts "Usage: convert_na_names -pdb <input pdb file> -o <output pdb file> ?options?"
  puts "Options:"
  puts "   -psf <input psf file>"
  return
}

proc ::Dowser::convert_na_names { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_na_names_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_na_names_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_na_names_usage
    error "ERROR: Input PDB file not specified."
  } elseif { [info exists arg(psf)] } {
    set molid [mol new $arg(psf) waitfor all]
    mol addfile $arg(pdb) waitfor all molid $molid
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_na_names_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  puts ""
  puts "Dowser) *************************************"
  puts "Dowser) Converting nucleic acid atom names..."
  puts "Dowser) *************************************"
  puts ""
  #puts "Dowser) Converting glycosidic atom names (O3'->O3*, ...)"

  # Since we deal with modified nucleic acid residues, it is important to 
  # process all residues, not only the standard ones.

  # First, check if we have atom names with primes at all
  set selPrimes [atomselect $molid {name ".*'"}]
  set selPrimesNum [$selPrimes num]
  $selPrimes delete

  if { $selPrimesNum != 0 } {

    # This could be done with regular expressions, but in this way I know
    # I'm changing only the atom names supported by Dowser, and it should
    # be a little faster

    # O5' -> O5*
    set sel [atomselect $molid {name "O5'"}]
    $sel set name "O5*"
    $sel delete
 
    # C5' -> C5*
    set sel [atomselect $molid {name "C5'"}]
    $sel set name "C5*"
    $sel delete

    # H5' -> H5*
    set sel [atomselect $molid {name "H5'"}]
    $sel set name "H5*"
    $sel delete

    # H5'' -> H5**
    set sel [atomselect $molid {name "H5''"}]
    $sel set name "H5**"
    $sel delete

    # C4' -> C4*
    set sel [atomselect $molid {name "C4'"}]
    $sel set name "C4*"
    $sel delete

    # H4' -> H4*
    set sel [atomselect $molid {name "H4'"}]
    $sel set name "H4*"
    $sel delete

    # O4' -> O4*
    set sel [atomselect $molid {name "O4'"}]
    $sel set name "O4*"
    $sel delete

    # C1' -> C1*
    set sel [atomselect $molid {name "C1'"}]
    $sel set name "C1*"
    $sel delete

    # H1' -> H1*
    set sel [atomselect $molid {name "H1'"}]
    $sel set name "H1*"
    $sel delete

    # C2' -> C2*
    set sel [atomselect $molid {name "C2'"}]
    $sel set name "C2*"
    $sel delete

    # H2'' -> H2**
    set sel [atomselect $molid {name "H2''"}]
    $sel set name "H2**"
    $sel delete

    # O2' -> O2*
    set sel [atomselect $molid {name "O2'"}]
    $sel set name "O2*"
    $sel delete

    # H2' -> H2*
    set sel [atomselect $molid {name "H2'"}]
    $sel set name "H2*"
    $sel delete

    # C3' -> C3*
    set sel [atomselect $molid {name "C3'"}]
    $sel set name "C3*"
    $sel delete

    # H3' -> H3*
    set sel [atomselect $molid {name "H3'"}]
    $sel set name "H3*"
    $sel delete

    # O3' -> O3*
    set sel [atomselect $molid {name "O3'"}]
    $sel set name "O3*"
    $sel delete

  }


  puts -nonewline "Dowser) Writing file $outFile with converted nucleic acid atom names... "

  set all [atomselect $molid "all"]
  $all writepdb $outFile
  $all delete

  puts "Done."

  mol delete $molid

  return
}

#######################################################################
#                        MODIFY MO RESIDUES
#######################################################################

proc ::Dowser::modify_mo_residues_usage { } {
  puts "Finds all water molecules around a Mg2+ ion and group them in a single residue called MO# where # is the number of water molecules. Hydrogens that are part of water molecules around a Mg2+ are deleted."
  puts "Usage: modify_mo_residues -pdb <input pdb file> -o <output pdb file>"
  return
}

proc ::Dowser::modify_mo_residues { args } {

  variable moResidueCutoff

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      modify_mo_residues_usage
      error ""
    }
    if { $nargs % 2 } {
      modify_mo_residues_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    modify_mo_residues_usage
    error "ERROR: Input PDB file not specified."
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    modify_mo_residues_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  # Use the beta field to flag that a water already belongs to an MO?
  # residue to avoid double assignment.
  set all [atomselect $molid "all"]
  $all set beta 0
  $all delete

  set mgSel [atomselect $molid "type MG"]
  set deletedHydrogens {}
  set moIndices {}
  set residCounter 1

  foreach mgId [$mgSel get index] {

    set selMg [atomselect $molid "index $mgId"]
    set selWat [atomselect $molid "beta 0 and water and same residue as within $moResidueCutoff of index $mgId"]
    set selWatOx [atomselect $molid "beta 0 and noh and water and same residue as within $moResidueCutoff of index $mgId"]
    set selWatHy [atomselect $molid "beta 0 and hydrogen and water and same residue as within $moResidueCutoff of index $mgId"]

    # If no waters were found close to Mg2+, don't do anything
    if { [$selWat num] != 0 } {

      # Don't consider these waters anymore
      $selWat set beta 1
  
      # Mark hydrogen atoms for deletion
      lappend deletedHydrogens [$selWatHy get index]

      # Mark waters and Mg2+ to be printed at the end of the file
      lappend moIndices $mgId
      lappend moIndices [$selWatOx get index]
  
      set numWaters [$selWatOx num]
      set newResName "MO$numWaters"
      if { $numWaters > 6 } {
        puts "Warning: Found more than 6 waters coordinating Mg2+ with index $mgId (will create an $newResName residue)"
      }
  
      set newNames {}
      for { set i 1 } { $i <= $numWaters } { incr i } {
        lappend newNames "O$i"
      }
  
      $selWatOx set element O
      $selWatOx set name $newNames
      $selWatOx set resid $residCounter
      $selWatOx set resname $newResName
      $selMg set element MG
      $selMg set resid $residCounter
      $selMg set resname $newResName
  
      incr residCounter
    
    } 

    $selMg delete
    $selWat delete
    $selWatOx delete
    $selWatHy delete

  }

  $mgSel delete

  if { $deletedHydrogens != {} || $moIndices != {} } {
    set notMO [atomselect $molid "not index [join $deletedHydrogens] [join $moIndices]"]
    if { $deletedHydrogens != {} } {
      set selDelHy [atomselect $molid "index [join $deletedHydrogens]"]
      puts "[$selDelHy num] hydrogens from water molecules will be deleted"
      $selDelHy delete
    }
  } else {
    set notMO [atomselect $molid "all"]
  }

  puts -nonewline "Writing processed pdb file $outFile ..."

  if { $moIndices != {} } {
    
    set tmpFile "modify_mo_residues_temp.pdb"
    set tmpFileMO "modify_mo_residues_temp2.pdb"

    $notMO writepdb "$tmpFile"

    set inNotMO [open "$tmpFile" r]
    set out [open "$outFile" w]

    gets $inNotMO line
    while {![regexp {END} $line]} {
      puts $out $line
      gets $inNotMO line
    }
    close $inNotMO
    file delete -force "$tmpFile"

    set selMO [atomselect $molid "index [join $moIndices]"]

    foreach moResid [lsort -integer -unique [$selMO get resid]] {

      set selResMO [atomselect $molid "resid $moResid and index [join $moIndices]"]
      $selResMO writepdb "$tmpFileMO"
      $selResMO delete
      set inMO [open "$tmpFileMO" r]
      gets $inMO line
      gets $inMO line
      while {![regexp {END} $line]} {
        puts $out $line
        gets $inMO line
      }
      close $inMO
      file delete -force "$tmpFileMO"

    }

    $selMO delete
    puts $out "END"
    close $out

  } else {
    $notMO writepdb "$outFile"
  }

  $notMO delete
  puts "Done."

  return

}

#######################################################################
#                      CONVERT MO TO MG-WATER
#######################################################################

proc ::Dowser::convert_mo_mg_water_usage { } {
  puts "Converts MO? residues (Mg2+ complexed with water molecules) into MG and HOH residues."
  puts "Usage: convert_mo_mg_water -pdb <input pdb file> -o <output pdb file>"
  return
}

proc ::Dowser::convert_mo_mg_water { args } { 

  variable tmpMOWaterFile "convert_mo_mg_water_temp1.pdb"
  variable tmpNotMOWaterFile "convert_mo_mg_water_temp2.pdb"

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_mo_mg_water_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_mo_mg_water_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_mo_mg_water_usage
    error "ERROR: Input PDB file not specified."
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_mo_mg_water_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  # Are there MO? residues at all?
  set selMO [atomselect $molid {resname "MO.*"}]
  if { [$selMO num] == 0 } {
    puts "No MO? residues were found."
    $selMO delete
    set all [atomselect $molid "all"]
    $all writepdb "$outFile"
    $all delete
    return
  }
  $selMO delete

  # change resname of MG ions in MO? resideus
  set selMOMG [atomselect $molid {resname "MO.*" and name MG}]
  if { [$selMOMG num] == 0 } {
    puts "No MG2+ ions were found in MO? residues."
  } else {
    $selMOMG set resname MG
  }
  $selMOMG delete

  # Change name and resname of MO? waters
  set selMOwater [atomselect $molid {resname "MO.*" and (water or name "O.*" or oxygen or hydrogen)}]
  puts "DEBUG: selMOwater num: [$selMOwater num]"
  # If there are not water molecules in MO? residues, we're done
  if { [$selMOwater num] == 0 } {
    puts "No water molecules in MO? residues were found."
    set all [atomselect $molid "all"]
    $all writepdb "$outFile"
    $all delete
    $selMOwater $delete
    return
  } else {
    set selMOoxygen [atomselect $molid {resname "MO.*" and name "O.*"}]
    puts "DEBUG: selMOoxygen num: [$selMOoxygen num]"
    if { [$selMOoxygen num] == 0 } {
      puts "No oxygen within MO? residues were found."
      $selMOoxygen delete
    } else {
      $selMOoxygen set name "OH2"
      $selMOoxygen delete
    }
    $selMOwater set resname HOH
    set MOWaterIndices [$selMOwater get index]
    $selMOwater writepdb "$tmpMOWaterFile"
    $selMOwater delete
  }

  set selMO [atomselect $molid {resname "MO.*"}]
  if { [$selMO num] > 0 } {
    puts "It seems that there's something other than water and Mg2+ ions in MO? residues. I'm not going to change these residues further."
  }
  set selNotMOwater [atomselect $molid "not index $MOWaterIndices"]
  $selNotMOwater writepdb "$tmpNotMOWaterFile"
  $selNotMOwater delete

  # concatenate the files
  set inWat [open "$tmpMOWaterFile" r]
  set inNotWat [open "$tmpNotMOWaterFile" r]
  set out [open "$outFile" w]
  
  gets $inNotWat line
  while {![regexp {END} $line]} {
    puts $out $line
    gets $inNotWat line
  }
  close $inNotWat
  
  gets $inWat line
  gets $inWat line
  while {![regexp {END} $line]} {
    puts $out $line
    gets $inWat line
  }
  close $inWat
  
  puts $out "END"
  close $out

  file delete -force "$tmpMOWaterFile"
  file delete -force "$tmpNotMOWaterFile"

  return

}

#######################################################################
#                      CONVERT NA TERMINI
#######################################################################

proc ::Dowser::convert_na_termini_usage { } {
  puts "Converts nucleic acid termini residues to comply with Dowser conventions."
  puts "Usage: convert_na_termini -pdb <input pdb file> -o <output pdb file> ?options?"
  puts "Options:"
  puts "   -psf <input psf file>"
  puts "   -split \[chain|fragment|segname|autopsf|auto\]"
  puts "   -na \[rna|dna|auto\] (default: auto)"
  return
}

proc ::Dowser::convert_na_termini { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_na_termini_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_na_termini_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -o { set arg(o) $val }
      -split { set arg(split) $val }
      -na { set arg(na) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_na_termini_usage
    error "ERROR: Input PDB file not specified."
  } elseif { [info exists arg(psf)] } {
    set molid [mol new $arg(psf) waitfor all]
    mol addfile $arg(pdb) waitfor all molid $molid
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    convert_na_termini_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  if { ![info exists arg(split)] || $arg(split) == "auto"} {
    set splitMethod "auto"
  } elseif { $arg(split) == "chain" } {
    set splitMethod "chain"
  } elseif { $arg(split) == "fragment" } {
    set splitMethod "fragment"
  } elseif { $arg(split) == "segname" } {
    set splitMethod "segname"
    #puts "Dowser) convert_na_termini: Option -split segname is not supported yet. Using -split auto instead..."
    #set splitMethod "auto"
  } elseif { $arg(split) == "autopsf" } {
    puts "Dowser) convert_na_termini: Option -split autopsf is not supported yet. Using -split auto instead..."
    set splitMethod "auto"
  } else {
    error "ERROR: Unrecognized value for option -split: $arg(split)"
  }

  if { [info exists arg(na)] } {
    if { $arg(na) == "rna" } {
      set naType "rna"
    } elseif { $arg(na) == "dna" } {
      set naType "dna"
    } elseif { $arg(na) == "auto" } {
      set naType "auto"
    } else {
      error "ERROR: invalid value for option -na: $arg(na)"
    }
  } else {
    set naType "auto"
  }

  puts ""
  puts "Dowser) **********************************"
  puts "Dowser) Processing nucleic acid termini..."
  puts "Dowser) **********************************"
  puts ""

  # Does this structure even has nucleic acid?
  set selNucleic [atomselect $molid "resname A T C G U ADE THY CYT GUA URA"]
  set selNucleicNum [$selNucleic num]
  $selNucleic delete
  if { $selNucleicNum == 0 } {

    puts "Dowser) No nucleic acid residues were found."
    puts -nonewline "Dowser) Writing file $outFile ... "
    set all [atomselect $molid "all"]
    $all writepdb "$outFile"
    $all delete
    mol delete $molid
    return

  } else {

    # to make it easy the concatenation to generate the new residue names
    set five 5
    set three 3

    if { $splitMethod == "auto" } {
      # if a psf file was given, use fragment; otherwise, use autopsf
      if { [info exists arg(psf)] } {
        puts "Dowser) Since a psf file was provided, the method 'fragment' will be used to split nucleic acid strands"
        set splitMethod "fragment"
      } else {
        #TODO: change this when the autopsf code is ready
        #set splitMethod "autopsf"
        puts "Dowser) Using method 'fragment' to split nucleic acid strands"
        set splitMethod "fragment"
      }
    }
  
    # don't try to guess chain information, just go by whatever is in the
    # pdb file; also assume the lowest resid corresponds to the beginning
    # of the chain and the highest resid corresponds to the end
    if { $splitMethod == "chain" } {

      ##########################
      # SPLIT STRANDS BY CHAIN #
      ##########################

      set notWatIon [atomselect $molid "not (water or ion)"]
      foreach chain [lsort -unique [$notWatIon get chain]] {
        if { $chain != {} } {
  
          # does this chain contain nucleic acid?
          set selNucleic [atomselect $molid "chain $chain and resname A C T G U DA DC DT DG ADE CYT THY GUA URA"]
          set selNucleicNum [$selNucleic num]
          $selNucleic delete
          if { $selNucleicNum == 0 } {
            continue
          }
  
          set selChain [atomselect $molid "not (water or ion) and chain $chain"]
          set resids [lsort -unique -integer [$selChain get resid]]
          $selChain delete
          set residsNum [llength $resids]
  
          # process the first residue
          set firstResid [lindex $resids 0]
          set firstResidSel [atomselect $molid "not (water or ion) and chain $chain and resid $firstResid"]
          set resName [lsort -unique [$firstResidSel get resname]]
          # let's be picky
          if { [llength $resName] != 1 } {
            puts "Warning: More than one residue ($resName) were identified as the first residue of chain $chain. The first residue of chain $chain will not be processed."
          } else {
            # is this a common nucleic acid residue?
            set selTest [atomselect $molid "not (water or ion) and chain $chain and resid $firstResid and resname A C T G U DA DC DT DG ADE CYT THY GUA URA"]
            if { [$selTest num] != 0 } {
              # is this RNA?
              set isRNA 0
              if { $naType == "auto" } {
                set atomNames [$firstResidSel get name]
                foreach name $atomNames {
                  if { $name == "O2'" || $name == "O2*" } {
                    set isRNA 1
                  }
                }
              }
              if { $naType == "rna" || $isRNA == 1 } {
                if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                  set newResName $argmatch$five
                  puts "Dowser) Chain $chain, resid $firstResid: resname $resName -> $newResName"
                  $firstResidSel set resname $newResName
                } else { 
                  puts "Dowser) Warning: Chain $chain, resid $firstResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
                }
              } else {
                if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                  set newResName "D$argmatch$five"
                  puts "Dowser) Chain $chain, resid $firstResid: resname $resName -> $newResName"
                  $firstResidSel set resname $newResName
                } else {
                  puts "Dowser) Warning: Chain $chain, resid $firstResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
                }
              }
            }
            $selTest delete
          }
          $firstResidSel delete
  
          # process the last residue
          set lastResid [lindex $resids [expr {$residsNum - 1}]]
          set lastResidSel [atomselect $molid "not (water or ion) and chain $chain and resid $lastResid"]
          set resName [lsort -unique [$lastResidSel get resname]]
          # let's be picky
          if { [llength $resName] != 1 } {
            puts "Warning: More than one residue ($resName) were identified as the last residue of chain $chain. The last residue of chain $chain will not be processed." 
          } else {
            # is this a common nucleic acid residue?
            set selTest [atomselect $molid "not (water or ion) and chain $chain and resid $lastResid and resname A C T G U ADE CYT THY GUA URA"]
            if { [$selTest num] != 0 } {
              if { $naType == "rna" || $isRNA == 1 } {
                if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                  set newResName $argmatch$three
                  puts "Dowser) Chain $chain, resid $lastResid: resname $resName -> $newResName"
                  $lastResidSel set resname $newResName
                } else { 
                  puts "Dowser) Warning: Chain $chain, resid $lastResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
                }
              } else {
                if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                  set newResName "D$argmatch$three"
                  puts "Dowser) Chain $chain, resid $lastResid: resname $resName -> $newResName"
                  $lastResidSel set resname $newResName
                } else {
                  puts "Dowser) Warning: Chain $chain, resid $lastResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
                }
              }
            }
            $selTest delete
  
          }
          $lastResidSel delete
        }
      }
 
    } elseif { $splitMethod == "segname" } {

      ############################
      # SPLIT STRANDS BY SEGNAME #
      ############################

      set notWatIon [atomselect $molid "not (water or ion)"]
      foreach segname [lsort -unique [$notWatIon get segname]] {
        if { $segname != {} } {
  
          # does this segname contain nucleic acid?
          set selNucleic [atomselect $molid "segname $segname and resname A C T G U DA DC DT DG ADE CYT THY GUA URA"]
          set selNucleicNum [$selNucleic num]
          $selNucleic delete
          if { $selNucleicNum == 0 } {
            continue
          }
  
          set selSegname [atomselect $molid "not (water or ion) and segname $segname"]
          set resids [lsort -unique -integer [$selSegname get resid]]
          $selSegname delete
          set residsNum [llength $resids]
  
          # process the first residue
          set firstResid [lindex $resids 0]
          set firstResidSel [atomselect $molid "not (water or ion) and segname $segname and resid $firstResid"]
          set resName [lsort -unique [$firstResidSel get resname]]
          # let's be picky
          if { [llength $resName] != 1 } {
            puts "Warning: More than one residue ($resName) were identified as the first residue of segname $segname. The first residue of segname $segname will not be processed."
          } else {
            # is this a common nucleic acid residue?
            set selTest [atomselect $molid "not (water or ion) and segname $segname and resid $firstResid and resname A C T G U DA DC DT DG ADE CYT THY GUA URA"]
            if { [$selTest num] != 0 } {
              # is this RNA?
              set isRNA 0
              if { $naType == "auto" } {
                set atomNames [$firstResidSel get name]
                foreach name $atomNames {
                  if { $name == "O2'" || $name == "O2*" } {
                    set isRNA 1
                  }
                }
              }
              if { $naType == "rna" || $isRNA == 1 } {
                if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                  set newResName $argmatch$five
                  puts "Dowser) Segname $segname, resid $firstResid: resname $resName -> $newResName"
                  $firstResidSel set resname $newResName
                } else { 
                  puts "Dowser) Warning: Segname $segname, resid $firstResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
                }
              } else {
                if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                  set newResName "D$argmatch$five"
                  puts "Dowser) Segname $segname, resid $firstResid: resname $resName -> $newResName"
                  $firstResidSel set resname $newResName
                } else {
                  puts "Dowser) Warning: Segname $segname, resid $firstResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
                }
              }
            }
            $selTest delete
          }
          $firstResidSel delete
  
          # process the last residue
          set lastResid [lindex $resids [expr {$residsNum - 1}]]
          set lastResidSel [atomselect $molid "not (water or ion) and segname $segname and resid $lastResid"]
          set resName [lsort -unique [$lastResidSel get resname]]
          # let's be picky
          if { [llength $resName] != 1 } {
            puts "Warning: More than one residue ($resName) were identified as the last residue of segname $segname. The last residue of segname $segname will not be processed." 
          } else {
            # is this a common nucleic acid residue?
            set selTest [atomselect $molid "not (water or ion) and segname $segname and resid $lastResid and resname A C T G U ADE CYT THY GUA URA"]
            if { [$selTest num] != 0 } {
              if { $naType == "rna" || $isRNA == 1 } {
                if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                  set newResName $argmatch$three
                  puts "Dowser) Segname $segname, resid $lastResid: resname $resName -> $newResName"
                  $lastResidSel set resname $newResName
                } else { 
                  puts "Dowser) Warning: Segname $segname, resid $lastResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
                }
              } else {
                if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                  set newResName "D$argmatch$three"
                  puts "Dowser) Segname $segname, resid $lastResid: resname $resName -> $newResName"
                  $lastResidSel set resname $newResName
                } else {
                  puts "Dowser) Warning: Segname $segname, resid $lastResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
                }
              }
            }
            $selTest delete
  
          }
          $lastResidSel delete
        }
      }
  
    } elseif { $splitMethod == "fragment" } {

      #############################
      # SPLIT STRANDS BY FRAGMENT #
      #############################
    
      set notWatIon [atomselect $molid "not (water or ion)"]
      # if we don't have anything that's not water or ion, we're done
      if { [$notWatIon num] == 0 } {
        $notWatIon delete
        set all [atomselect $molid "all"]
        $all writepdb $outFile
        $all delete
        mol delete $molid
        return
      }
      set fragmentList [lsort -unique [$notWatIon get fragment]] 
      puts "Dowser) Processing [llength $fragmentList] fragments (water and ions are ignored)..."
      set selTest [atomselect $molid "fragment $fragmentList"]
      # sanity check
      if { [$notWatIon num] != [$selTest num] } {
        puts "Dowser) Warning: It looks like some water or ions were assigned to the same fragment as something other than water or ions"
      }
      foreach fragment $fragmentList {
  
        # does this fragment contain nucleic acid?
        set selNucleic [atomselect $molid "fragment $fragment and resname A C T G U ADE CYT THY GUA URA"]
        set selNucleicNum [$selNucleic num]
        $selNucleic delete
        if { $selNucleicNum == 0 } {
          continue
        }
  
        set selFrag [atomselect $molid "fragment $fragment"]
        set resids [lsort -unique -integer [$selFrag get resid]]
        $selFrag delete
        set residsNum [llength $resids]

        # process the first residue
        set firstResid [lindex $resids 0]
        set firstResidSel [atomselect $molid "not (water or ion) and fragment $fragment and resid $firstResid"]
        set resName [lsort -unique [$firstResidSel get resname]]
        # let's be picky
        if { [llength $resName] != 1 } {
          puts "Warning: More than one residue ($resName) were identified as the first residue of fragment $fragment. The first residue of fragment $fragment will not be processed."
        } else {
          # is this a common nucleic acid residue?
          set selTest [atomselect $molid "not (water or ion) and fragment $fragment and resid $firstResid and resname A C T G U DA DC DT DG ADE CYT THY GUA URA"]
          if { [$selTest num] != 0 } {
            # is this RNA?
            set isRNA 0
            if { $naType == "auto" } {
              set atomNames [$firstResidSel get name]
              foreach name $atomNames {
                if { $name == "O2'" || $name == "O2*" } {
                  set isRNA 1
                }
              }
            }
            if { $naType == "rna" || $isRNA == 1 } {
              if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                set newResName $argmatch$five
                puts "Dowser) Fragment $fragment, resid $firstResid: resname $resName -> $newResName"
                $firstResidSel set resname $newResName
              } else { 
                puts "Dowser) Warning: Fragment $fragment, resid $firstResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
              }
            } else {
              if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                set newResName "D$argmatch$five"
                puts "Dowser) Fragment $fragment, resid $firstResid: resname $resName -> $newResName"
                $firstResidSel set resname $newResName
              } else {
                puts "Dowser) Warning: Fragment $fragment, resid $firstResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
              }
            }
          }
          $selTest delete
        }
        $firstResidSel delete

        # process the last residue
        set lastResid [lindex $resids [expr {$residsNum - 1}]]
        set lastResidSel [atomselect $molid "not (water or ion) and fragment $fragment and resid $lastResid"]
        set resName [lsort -unique [$lastResidSel get resname]]
        # let's be picky
        if { [llength $resName] != 1 } {
          puts "Warning: More than one residue ($resName) were identified as the last residue of fragment $fragment. The last residue of fragment $fragment will not be processed." 
        } else {
          # is this a common nucleic acid residue?
          set selTest [atomselect $molid "not (water or ion) and fragment $fragment and resid $lastResid and resname A C T G U ADE CYT THY GUA URA"]
          if { [$selTest num] != 0 } {
            if { $naType == "rna" || $isRNA == 1 } {
              if { [regexp {^(A|C|U|G).*} $resName fullmatch argmatch] } {
                set newResName $argmatch$three
                puts "Dowser) Fragment $fragment, resid $lastResid: resname $resName -> $newResName"
                $lastResidSel set resname $newResName
              } else { 
                puts "Dowser) Warning: Fragment $fragment, resid $lastResid, resname $resName was expected to be RNA but is not a valid RNA residue. This residue will not be processed."
              }
            } else {
              if { [regexp {^D?(A|C|T|G).*} $resName fullmatch argmatch] } {
                set newResName "D$argmatch$three"
                puts "Dowser) Fragment $fragment, resid $lastResid: resname $resName -> $newResName"
                $lastResidSel set resname $newResName
              } else {
                puts "Dowser) Warning: Fragment $fragment, resid $lastResid, resname $resName was expected to be DNA but is not a valid DNA residue. This residue will not be processed."
              }
            }
          }
          $selTest delete

        }
        $lastResidSel delete

      }
  
    } elseif { $splitMethod == "autopsf" } {

      #######################################################
      # SPLIT STRANDS USING THE SAME ALGORITHM AUTOPSF USES #
      #######################################################

      puts "Dowser) ERROR: The autopsf option to split nucleic acid strands is not available yet."

    }

    puts -nonewline "Dowser) Writing file $outFile with converted nucleic acid termini residue names... "
    set all [atomselect $molid "all"]
    $all writepdb $outFile
    $all delete
    $notWatIon delete
    puts "Done."

  }

  mol delete $molid
  return

}

#######################################################################
#                           KEEP WATERS
#######################################################################

proc ::Dowser::keep_waters_usage { } {
  puts "Adds hydrogens to all water molecules and format the file to force dowser to keep these waters."
  puts "Usage: keep_waters -pdb <input pdb file> -o <output pdb file>"
  return
}

proc ::Dowser::keep_waters { args } {

  variable tmpWaterFile "temp_keep_water.pdb"
  variable tmpWaterSegNamePrefix "temp_keep_water_segname_"
  variable tmpNotWaterFile "temp_keep_water_not_water.pdb"
  variable waterTopologyFile 

  init_water_topology

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      keep_waters_usage
      error ""
    }
    if { $nargs % 2 } {
      keep_waters_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    keep_waters_usage
    error "ERROR: Input PDB file not specified."
  } else {
    set molid [mol new $arg(pdb) waitfor all]
  }

  if { ![info exists arg(o)] } {
    keep_waters_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set outFile $arg(o)
  }

  puts ""
  puts "Dowser) *************************************************************"
  puts "Dowser) Forcing dowser to keep all water molecules already present..."
  puts "Dowser) *************************************************************"
  puts ""

  # Write a pdb file with all water molecules, including possibly
  # present hydrogen atoms
  set wat [atomselect $molid "water"]
  # if there's no water in the structure, we're done
  if { [$wat num] == 0 } {
    puts "No water molecules were found in file $arg(pdb)."
    $wat delete
    set all [atomselect $molid "all"]
    $all writepdb "$outFile"
    $all delete
    mol delete $molid
    return
  }
  set watO [atomselect $molid "noh and water"]
  set watSegNames [lsort -unique [$wat get segname]]
  $wat set resname "TIP3"
  $wat delete
  $watO set name "OH2"
  $watO delete
  foreach segName $watSegNames {
    if { $segName == {} } {
      if { [llength $watSegNames] > 1 } {
        set watSegSel [atomselect $molid "water and not segname $watSegNames"]
        set watSegO [atomselect $molid "noh and water and not segname $watSegNames"]
      } else {
        set watSegSel [atomselect $molid "water"]
        set watSegO [atomselect $molid "noh and water"]
      }
      $watSegSel set segname KWAT
      set segName "KWAT"
      set watResid 1
      foreach id [$watSegO get index] {
        set watResSel [atomselect $molid "same residue as index $id"]
        $watResSel set resid $watResid
        $watResSel delete
        incr watResid
      }
      $watSegO delete
    } else {
      set watSegSel [atomselect $molid "water and segname $segName"]
    }
    $watSegSel writepdb "$tmpWaterSegNamePrefix$segName.pdb"
    $watSegSel delete
  }

  # Write a pdb file with the rest of the structure for future use
  set notWat [atomselect $molid "not water"]
  if { [$notWat num] == 0 } {
    set watOnly 1
  } else {
    set watOnly 0
    $notWat writepdb "$tmpNotWaterFile"
  }
  $notWat delete

  # Add hydrogens to water molecules with psfgen
  psfcontext reset
  topology "$waterTopologyFile"
  foreach segName $watSegNames {
    if { $segName == {} } {
      set segName "KWAT"
    }
    segment $segName {
      pdb "$tmpWaterSegNamePrefix$segName.pdb"
      auto none
    }
    coordpdb "$tmpWaterSegNamePrefix$segName.pdb" $segName
  }
  guesscoord
  writepdb "$tmpWaterFile"

  # Now $tmpWaterFile contains all water molecules with hydrogens,
  # whereas $tmpNotWaterFile contains all non-water molecules. We just
  # need to join them. Let's do it manually to be more generic.
  set outTmp [open "$outFile-temp.pdb" w]
  set inWat [open "$tmpWaterFile" r]
  if { $watOnly == 0 } {
    set inNotWat [open "$tmpNotWaterFile" r]
    gets $inNotWat line
    while {![regexp {END} $line]} {
      puts $outTmp $line
      gets $inNotWat line
    }
    close $inNotWat
  }
  gets $inWat line
  gets $inWat line
  while {![regexp {END} $line]} {
    puts $outTmp $line
    gets $inWat line
  }
  close $inWat
  close $outTmp

  # Now let's rename things to use residue TRE instead of TIP3
  set tmpMolid [mol new "$outFile-temp.pdb" waitfor all]
  set selwat [atomselect $tmpMolid "resname TIP3"]
  $selwat set resname "TRE"
  $selwat delete
  set selO [atomselect $tmpMolid "resname TRE and name OH2"]
  $selO set name "OW"
  $selO delete
  set all [atomselect $tmpMolid all]
  $all writepdb $outFile
  $all delete
  mol delete $tmpMolid

  # Delete temporary files
  file delete -force "$tmpWaterFile"
  file delete -force "$tmpNotWaterFile"
  file delete -force "$outFile-temp.pdb"
  foreach segName $watSegNames {
    file delete -force "$tmpWaterSegNamePrefix$segName.pdb"
  }

  mol delete $molid
  return

}

#######################################################################
#                    CONVERT HOH ATOM TO HETATM
#######################################################################

proc ::Dowser::convert_hoh_hetatm_usage { } {
  puts "Converts the ATOM entries for residues HOH to HETATM."
  puts "Usage: convert_hoh_hetatm -pdb <input pdb file> -o <output pdb file>"
  return
}

proc ::Dowser::convert_hoh_hetatm { args } {

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      convert_hoh_hetatm_usage
      error ""
    }
    if { $nargs % 2 } {
      convert_hoh_hetatm_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(pdb)] } {
    convert_hoh_hetatm_usage
    error "ERROR: Input PDB file not specified."
  } else {
    set in [open "$arg(pdb)" r]
  }

  if { ![info exists arg(o)] } {
    convert_hoh_hetatm_usage
    error "ERROR: Output PDB file not specified."
  } else {
    set out [open "$arg(o)" w]
  }

  puts ""
  puts "Dowser) *****************************************"
  puts "Dowser) Converting HOH ATOM entries to HETATM... "
  puts "Dowser) *****************************************"
  puts ""
  
  puts -nonewline "Dowser) Writing file $arg(o) with converted HOH entries... "

  # search for HOH in columns 18-20
  gets $in line
  while {$line != ""} {
    if { [regexp {^ATOM  (...........HOH.*)} $line fullmatch argmatch] } {
      puts $out "HETATM$argmatch"
    } else {
      puts $out $line
    }
    gets $in line
  }

  puts "Done."

  close $in
  close $out

  return

}

#######################################################################
#                           RUN DOWSER
#######################################################################

proc ::Dowser::rundowser_wrapper { args } {

  variable defaultArgHetero
  variable defaultArgProbe
  variable defaultArgSeparation
  variable defaultArgXtal

  set nargs [llength $args]

#  puts ""
#  puts "DEBUG: Entered rundowser_wrapper"
#  puts "DEBUG: args = $args"
#  puts ""

  if { $nargs == 0 } { 
#    rundowser_wrapper_usage
    error ""
  } 

  set inputPDB [lindex [join $args] 0]
  set args [lrange [split [join $args]] 1 end]

#  puts ""
#  puts "DEBUG: Entered rundowser_wrapper"
#  puts "DEBUG: args = $args"
#  puts ""

  if { [expr {$nargs-1}] % 2 } {
#    rundowser_wrapper_usage
    error "ERROR: odd number of optional arguments $args"
  }

  foreach {name val} $args {
    switch -- $name {
      -cmd { set arg(cmd) $val }
      -log { set arg(log) $val }
      -hetero { set arg(hetero) $val }
      -probe { set arg(probe) $val }
      -separation { set arg(separation) $val }
      -xtal { set arg(xtal) $val }
      -atomtypes { set arg(atomtypes) $val }
      -atomparms { set arg(atomparms) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { [info exists arg(log)] } {
    set logFile $arg(log)
  }

  if { [info exists arg(cmd)] } {
    set dowserCmd "$arg(cmd)"
    if { ![info exists arg(log)] } {
      set logFile "$arg(cmd).log"
    }
  } else {
    set dowserCmd "dowser"
    if { ![info exists arg(log)] } {
      set logFile "dowser.log"
    }
  }
  #puts "DEBUG: arg(cmd) = $arg(cmd); dowserCmd = $dowserCmd"

  if { [info exists arg(hetero)] } {
    set argHetero $arg(hetero)
  } else {
    set argHetero $defaultArgHetero
  }

  if { [info exists arg(probe)] } {
    set argProbe $arg(probe)
  } else {
    set argProbe $defaultArgProbe
  }

  if { [info exists arg(separation)] } {
    set argSeparation $arg(separation)
  } else {
    set argSeparation $defaultArgSeparation
  }

  if { [info exists arg(xtal)] } {
    set argXtal $arg(xtal)
  } else {
    set argXtal $defaultArgXtal
  }

  if { [info exists arg(atomtypes)] } {
    set argAtomtypes $arg(atomtypes)
    set hasAtomtypes 1
  } else {
    set hasAtomtypes 0
  }

  if { [info exists arg(atomparms)] } {
    set argAtomparms $arg(atomparms)
    set hasAtomparms 1
  } else {
    set hasAtomparms 0
  }

#  puts "DEBUG:"
#  puts "  inputPDB = $inputPDB"
#  puts "  argHetero = $argHetero"
#  puts "  hasAtomtypes = $hasAtomtypes"
#  puts "  hasAtomparms = $hasAtomparms"
#  puts "  argXtal = $argXtal"
#  puts "  argProbe = $argProbe"
#  puts "  argSeparation = $argSeparation"

  if { $argHetero == 1 } {

    if { $hasAtomtypes == 0 && $hasAtomparms == 0 } {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -noxtalwater"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -onlyxtalwater"
      } else {
        error "Unrecognized option -xtal $argXtal"
      }
  
    } elseif { $hasAtomtypes == 1 && $hasAtomparms == 0 } {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -atomtypes $argAtomtypes"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -noxtalwater -atomtypes $argAtomtypes"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -onlyxtalwater -atomtypes $argAtomtypes"
      }
  
    } elseif { $hasAtomtypes == 0 && $hasAtomparms == 1 } {
      
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -atomparms $argAtomparms"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -noxtalwater -atomparms $argAtomparms"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -onlyxtalwater -atomparms $argAtomparms"
      }
  
    } else {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -atomtypes $argAtomtypes -atomparms $argAtomparms"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -noxtalwater -atomtypes $argAtomtypes -atomparms $argAtomparms"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -hetero -probe $argProbe -separation $argSeparation -onlyxtalwater -atomtypes $argAtomtypes -atomparms $argAtomparms"
      }
  
    }

  } else {

    if { $hasAtomtypes == 0 && $hasAtomparms == 0 } {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -noxtalwater"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -onlyxtalwater"
      } else {
        error "Unrecognized option -xtal $argXtal"
      }
  
    } elseif { $hasAtomtypes == 1 && $hasAtomparms == 0 } {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -atomtypes $argAtomtypes"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -noxtalwater -atomtypes $argAtomtypes"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -onlyxtalwater -atomtypes $argAtomtypes"
      }
  
    } elseif { $hasAtomtypes == 0 && $hasAtomparms == 1 } {
      
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -atomparms $argAtomparms"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -noxtalwater -atomparms $argAtomparms"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -onlyxtalwater -atomparms $argAtomparms"
      }
  
    } else {
  
      if { $argXtal == "default" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -atomtypes $argAtomtypes -atomparms $argAtomparms"
      } elseif { $argXtal == "noxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -noxtalwater -atomtypes $argAtomtypes -atomparms $argAtomparms"
      } elseif { $argXtal == "onlyxtalwater" } {
        set dowserArgs "$inputPDB -probe $argProbe -separation $argSeparation -onlyxtalwater -atomtypes $argAtomtypes -atomparms $argAtomparms"
      }
  
    }

  }

  set dowserBin [::ExecTool::find -interactive $dowserCmd]

  puts "Dowser) Running ::ExecTool::exec $dowserBin $dowserArgs ..."
  eval ::ExecTool::exec $dowserBin "$dowserArgs" >&@ stdout
  puts "Dowser) Done with dowser."

  return

}

#######################################################################
#                          COMBINE WATERS
#######################################################################

proc ::Dowser::combine_waters_usage { } {
  puts "Combine waters placed by dowser with a given psf/pdb combo."
  puts "Usage: combine_waters -pdb <input pdb file> -psf <input psf file> -dow <list of pdb with dowser waters> -o <output prefix>"
  return
}

proc ::Dowser::combine_waters { args } {

  set tmpWaterFile "temp_combine_water.pdb"
  set tmpWaterMolidPrefix "temp_dowser_water_molid_"
  set tmpWaterSegNamePrefix "temp_dowser_water_segname_"
  #variable tmpNotWaterFile "temp_keep_water_not_water.pdb"
  variable waterTopologyFile 

  set dowserSegments {}
  set dowserMolids {}

  init_water_topology

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      combine_waters_usage
      error ""
    }
    if { $nargs % 2 } {
      combine_waters_usage
      error "ERROR: odd number of arguments $args"
    }
  }

  foreach {name val} $args {
    switch -- $name {
      -pdb { set arg(pdb) $val }
      -psf { set arg(psf) $val }
      -dow { set arg(dow) $val }
      -o { set arg(o) $val }
      default { error "unkown argument: $name $val" }
    }
  }

  if { ![info exists arg(psf)] } {
    combine_waters_usage
    error "ERROR: Input PSF file not specified."
  } else {
    #set inputMolid [mol new $arg(psf) type psf waitfor all]
    set inputPSF $arg(psf)
  }

  if { ![info exists arg(pdb)] } {
    combine_waters_usage
    error "ERROR: Input PDB file not specified."
  } else {
    #mol addfile $arg(pdb) type pdb molid $inputMolid waitfor all
    set inputPDB $arg(pdb)
  }

  if { ![info exists arg(dow)] } {
    combine_waters_usage
    error "ERROR: Input PDB file not specified."
  } else {
    foreach file $arg(dow) {
      if { [catch { set molid [mol new $file type pdb waitfor all] } err] } {
        puts "Dowser) WARNING: PDB file $file is empty and will be ignored."
      } else {
        lappend dowserMolids $molid
      }
    }
  }

  if { ![info exists arg(o)] } {
    combine_waters_usage
    error "ERROR: Output prefix not specified."
  } else {
    set outFile $arg(o)
  }

  puts ""
  puts "Dowser) ****************************************************"
  puts "Dowser) Combining dowser waters with input psf/pdb combo... "
  puts "Dowser) ****************************************************"
  puts ""

  puts "Dowser) Processing dowser waters..."
  if { [llength $dowserMolids] == 0 } {
    puts "Dowser) No dowser waters were found. Giving up..."
    return
  }
  # first concatenate all dowser waters
  foreach molid $dowserMolids {
    set sel [atomselect $molid all]
    $sel set segname "FOO"
    $sel set resname "TIP3"
    set selO [atomselect $molid {noh}]
    $selO set name "OH2"
    $selO delete
    $sel writepdb "$tmpWaterMolidPrefix$molid.pdb"
    $sel delete
    mol delete $molid
  }
  set out [open $tmpWaterFile w]
  foreach molid $dowserMolids {
    set in [open "$tmpWaterMolidPrefix$molid.pdb" r]
    gets $in line
    gets $in line
    while {![regexp {END} $line]} {
      puts $out $line
      gets $in line
    }
    close $in
    file delete -force "$tmpWaterMolidPrefix$molid.pdb"
  }
  close $out

  # Now split Dowser waters into segments
  set dowserMolid [mol new $tmpWaterFile type pdb waitfor all]
  file delete -force $tmpWaterFile
  set sel [atomselect $dowserMolid all]
  set segNum 1
  set resid 1
  set i 1
  puts "Dowser) Processing segment DW$segNum ..."
  foreach residue [lsort -integer -unique [$sel get residue]] {
    # allow only 9000 waters in each segment
    if { $i == 9000 } {
      set i 1
      set resid 1
      incr segNum
      puts "Processing segment DW$segNum ..."
    }
    set selRes [atomselect $dowserMolid "residue $residue"]
    $selRes set resid $resid
    $selRes set segname "DW$segNum"
    $selRes delete
    incr resid
    incr i
  }
  $sel delete
  for {set i 1} {$i <= $segNum} {incr i} {
    set segname "DW$i"
    set sel [atomselect $dowserMolid "segname $segname"]
    $sel writepdb "$tmpWaterSegNamePrefix$segname.pdb"
    $sel delete
  }
  mol delete $dowserMolid

  # Add the waters placed by Dowser to psf/pdb file

  resetpsf
  readpsf $inputPSF
  coordpdb $inputPDB

  topology $waterTopologyFile

  for {set i 1} {$i <= $segNum} {incr i} {
    set segname "DW$i"
    segment $segname {
      pdb "$tmpWaterSegNamePrefix$segname.pdb"
      first none
      last none
    }
    coordpdb "$tmpWaterSegNamePrefix$segname.pdb" $segname
    file delete -force "$tmpWaterSegNamePrefix$segname.pdb"
  }

#  guesscoord

  writepsf "$outFile.psf"
  writepdb "$outFile.pdb"

  mol new "$outFile.psf" type psf waitfor all
  mol addfile "$outFile.pdb" type pdb waitfor all

  return

}
