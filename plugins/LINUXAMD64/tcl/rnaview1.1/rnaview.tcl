#
# rnaview - calls rnaview to calculate base pair information and writes
#           a bpseq file, or optionally an extended one.
#
# Leonardo Trabuco <ltrabuco@ks.uiuc.edu>
# Elizabeth Villa <villa@ks.uiuc.edu>
#
# $Id: rnaview.tcl,v 1.5 2013/04/15 17:31:11 johns Exp $
#

package require exectool 1.2
package provide rnaview 1.1

namespace eval ::RNAView:: {

  variable defaultMolid {top}
  variable defaultSelText {nucleic}
  variable defaultBpType "*"
  variable defaultBpCt "*"
  variable defaultKeepFiles 0
  variable defaultExtendedBpseq 0
  variable tmpPDB {tmp_rnaview.pdb}
  variable printedReference 0

}

proc rnaview { args } { return [eval ::RNAView::rnaview $args] }

proc ::RNAView::rnaview_usage { } {

  variable defaultMolid
  variable defaultSelText
  variable defaultBpType
  variable defaultBpCt  

  puts "Usage: rnaview -bpseq <output base pair file> ?options?"
  puts "  -mol <molid> (default: $defaultMolid)"
  puts "  -sel <seltext> (default: $defaultSelText)"
  puts "  -bptype <base pair type> (default: $defaultBpType)"
  puts "  -bpct <cis or trans base pair> (default: $defaultBpCt)"
  puts "  -debug -- keep intermediate files"
  puts "  -ext -- write an extended bpseq format"

  return

}

proc ::RNAView::rnaview { args } {

  variable defaultMolid
  variable defaultSelText
  variable defaultBpType
  variable defaultBpCt  
  variable defaultKeepFiles
  variable defaultExtendedBpseq
  variable tmpPDB
  variable printedReference
  global env

  set nargs [llength $args]
  if { $nargs == 0 || $nargs % 2 } {
    if { $nargs == 0 } {
      rnaview_usage
      error ""
    }
  }

  if {!$printedReference} {
    set printedReference 1
    puts "RNAView Reference) In any publication of scientific results based in part or"
    puts "RNAView Reference) completely on the use of RNAView, please reference:"
    puts "RNAView Reference) H. Yang, F. Jossinet, N. Leontis, L. Chen, J. Westbrook,"
    puts "RNAView Reference) H. Berman, E. Westhof, Nucl. Acids Res. 31 (2003) 3450-3460."
  }

  # debug mode?
  set pos [lsearch -exact $args {-debug}]
  if { $pos != -1 } {
    set keepFiles 1
    set args [lreplace $args $pos $pos]
  } else {
    set keepFiles $defaultKeepFiles
  }

  # write an extended bpseq file?
  set pos [lsearch -exact $args {-ext}]
  if { $pos != -1 } {
    set extendedBpseq 1
    set args [lreplace $args $pos $pos]
  } else {
    set extendedBpseq $defaultExtendedBpseq
  }

  foreach {name val} $args {
    switch -- $name {
      -mol { set arg(mol) $val }
      -sel { set arg(sel) $val }
      -bpseq { set arg(bpseq) $val }
      -bptype {set arg(bptype) $val }
      -bpct { set arg(bpct) $val }
    }
  }

  if { [info exists arg(mol)] } {
    set molid $arg(mol)
  } else {
    set molid $defaultMolid
  }
  if { $molid == "top" } {
    set molid [molinfo top]
  }

  if { [info exists arg(sel)] } {
    set seltext $arg(sel)
  } else {
    set seltext $defaultSelText
  }

  if { [info exists arg(bpseq)] } {
    set bpseqFileName $arg(bpseq)
  } else {
    rnaview_usage
    error "bpseq filename missing."
  }

 if { [info exists arg(bptype)] } {
    set bptype $arg(bptype)
  } else {
    set bptype $defaultBpType
  }

 if { [info exists arg(bpct)] } {
    set bpct $arg(bpct)
  } else {
    set bpct $defaultBpCt
  }

  # Write a pdb file to feed rnaview
  set sel [atomselect $molid "nucleic and ($seltext)"]
  if { [$sel num] == 0 } {
    $sel delete
    error "The selection does not contain nucleic acid."
  }

  # Check if resids are unique and get a list of resids
  set residList [lsort -integer -unique [$sel get resid]]
  set numResid [llength $residList]
  set numResidue [llength [lsort -unique [$sel get residue]]]
  if { $numResid != $numResidue } {
    $sel delete
    error "Selection does not contain unique resids. This is a requirement for bpseq format."
  }

  $sel writepdb $tmpPDB
  $sel delete

  # Call rnaview to calculate base bairs
  set rnaviewBin [file join $env(RNAVIEW) rnaview]
  if [catch {eval ::ExecTool::exec {$rnaviewBin} $tmpPDB >&@ stdout} errMsg] {
    error $errMsg
  }

  # Define a graph to store the base pair info 
  foreach resid1 $residList {
    set isPaired($resid1) 0
    foreach resid2 $residList {
      set bp($resid1,$resid2) 0
    }
  }

  # Parse rnaview output file

  # It's hard to catch errors from rnaview since it returns 0 even upon
  # error. Need to check if the file it generates is empty.
  if { [file size "${tmpPDB}.out"] == 0 } {
    # Delete intermediate files
    if { $keepFiles != 1 } {
      file delete $tmpPDB
      file delete "${tmpPDB}.out"
      file delete "base_pair_statistics.out"
    }
    error "RNAView generated an empty output. Please check the console for error messages and make sure RNAView is properly installed on your system."
  }

  set rnaviewFile [open "${tmpPDB}.out" r]
  while { [gets $rnaviewFile line] != -1 } {
    if { [string match "BEGIN_base-pair" $line] != 0 } {
      while { [gets $rnaviewFile line] != -1} {
        if { [string match "END_base-pair" $line] != 0 } {
    	  break
        }

        # Consider only certain type of basepair (input is bptype, bpct)
        if { [string match "$bptype" [lindex $line 6]] == 0 || \
             [string match "$bpct" [lindex $line 7]] == 0 } {
          continue
        }

        set bp1 [lindex $line 2]
        set bp2 [lindex $line 4]
        set bp($bp1,$bp2) 1
        set bp($bp2,$bp1) 1
        set bp($bp1,$bp2,type) [lindex $line 6]
        set bp($bp2,$bp1,type) [lindex $line 6]
        set bp($bp1,$bp2,ct)   [lindex $line 7]
        set bp($bp2,$bp1,ct)   [lindex $line 7]

        set isPaired($bp1) 1
        set isPaired($bp2) 1
      }
    }
  }
  close $rnaviewFile

  # Write bpseq file
  set bpseq [open $bpseqFileName w]
  foreach resid1 $residList {
    set sel [atomselect $molid "resid $resid1 and ($seltext)"]
    # Use 1-letter code for resname
    set resname1 [string range [lsort -unique [$sel get resname]] 0 0]
    $sel delete
    if { $isPaired($resid1) == 0 } {
      puts $bpseq "$resid1 $resname1 0"
    }
    foreach resid2 $residList {
      if { $bp($resid1,$resid2) == 1 } {
        if $extendedBpseq {
          puts $bpseq "$resid1 $resname1 $resid2 $bp($resid1,$resid2,type) $bp($resid1,$resid2,ct)"
        } else {
          puts $bpseq "$resid1 $resname1 $resid2"
        }
      }
    }
  }
  close $bpseq

  # Delete intermediate files
  if { $keepFiles != 1 } {
    file delete $tmpPDB
    file delete "${tmpPDB}.out"
    file delete "base_pair_statistics.out"
  }

  return

}

