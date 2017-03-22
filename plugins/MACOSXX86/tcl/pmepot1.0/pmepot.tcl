#
# Tcl/Tk front-end for PME routines
#
# $Id: pmepot.tcl,v 1.7 2007/08/06 21:36:48 jim Exp $
#
package provide pmepot 1.0.4

namespace eval ::PMEPot {

  package require pmepot_core 1.0

  namespace export pmepot

  variable default_grid_resolution 1.0
  variable default_grid_max_dim 512
  variable default_cell_padding 10.0
  variable default_ewald_factor 0.25
  variable debug 1

}

proc pmepot { args } { return [eval ::PMEPot::pmepot $args] }

proc ::PMEPot::pmepot { args } {
  variable debug
  set nargs [llength $args]
  if {$nargs == 0 || $nargs % 2} {
    puts "usage: pmepot ?-arg val?..."
    puts "  -mol <molid> (defaults to top, do not combine with -sel)"
    puts "  -sel <selection> (proc returned by atomselect command)"
    puts "  -frames <begin:end> or <begin:step:end> or all or now"
    puts "  -updatesel yes or no (default) (update selection for each frame)"
    puts "  -pad <d> (cell is bounding box plus d on each side)"
    puts "  -cell <{{ox oy oz} {ax ay az} {bx by bz} {cx cy cz}}> (o is center)"
    puts "  -xscfile <filename> (get cell from NAMD .xsc file)"
    puts "  -grid <{na nb nc}> (integer grid dimensions for PME)"
    puts "  -grid <n> (integer grid dimension for PME, n > 8)"
    puts "  -grid <resolution> (grid resolution for PME in Angstroms)"
    puts "  -dxfile <filename> (write potential map to file)"
    puts "  -loadmol <molid> or none or same or new (molecule to load data to)"
    puts "  -ewaldfactor <factor> (specify ewald factor)"
    error "error: empty argument list or odd number of arguments: $args"
  }
  foreach {name val} $args {
    switch -- $name {
      -mol { set arg(mol) $val }
      -sel { set arg(sel) $val }
      -frames { set arg(frames) $val }
      -updatesel { set arg(updatesel) $val }
      -pad { set arg(pad) $val }
      -cell { set arg(cell) $val }
      -xscfile { set arg(xscfile) $val }
      -grid { set arg(grid) $val }
      -dxfile { set arg(dxfile) $val }
      -loadmol { set arg(loadmol) $val }
      -ewaldfactor { set arg(ewaldfactor) $val }
      default { error "unknown argument: $name $val" }
    }
  }

  # get mol and selection
  if [info exists arg(mol)] {
    if [info exists arg(sel)] {
      error "options -mol and -sel are mutually exclusive"
    }
    set mol $arg(mol)
  } elseif [info exists arg(sel)] {
    set sel $arg(sel)
    set mol [$sel molid]
    if $debug {puts "sel: $sel"}
  } else {
    set mol [molinfo top]
  }
  if $debug {puts "mol: $mol"}

  # get frames
  set nowframe [molinfo $mol get frame]
  set lastframe [expr [molinfo $mol get numframes] - 1]
  if [info exists arg(frames)] {
    set fl [split $arg(frames) :]
    switch -- [llength $fl] {
      1 {
        switch -- $fl {
          all {
            set frames_begin 0
            set frames_end $lastframe
          }
          now {
            set frames_begin $nowframe
          }
          last {
            set frames_begin $lastframe
          }
          default {
            set frames_begin $fl
          }
        }
      }
      2 {
        set frames_begin [lindex $fl 0]
        set frames_end [lindex $fl 1]
      }
      3 {
        set frames_begin [lindex $fl 0]
        set frames_step [lindex $fl 1]
        set frames_end [lindex $fl 2]
      }
      default { error "bad -frames arg: $arg(frames)" }
    }
  } elseif { [info exists sel] } {
    set frames_begin [$sel frame]
    switch -- $frames_begin {
      now {
        set frames_begin $nowframe
      }
      last {
        set frames_begin $lastframe
      }
    }
  } else {
    set frames_begin $nowframe
  }
  if { ! [info exists frames_step] } { set frames_step 1 }
  if { ! [info exists frames_end] } { set frames_end $frames_begin }
  switch -- $frames_end {
    end - last { set frames_end $lastframe }
  }
  if { [ catch {
    if { $frames_begin < 0 } {
      set frames_begin [expr $lastframe + 1 + $frames_begin]
    }
    if { $frames_end < 0 } {
      set frames_end [expr $lastframe + 1 + $frames_end]
    }
    if { ! ( [string is integer $frames_begin] && \
	   ( $frames_begin >= 0 ) && ( $frames_begin <= $lastframe ) && \
	   [string is integer $frames_end] && \
	   ( $frames_end >= 0 ) && ( $frames_end <= $lastframe ) && \
	   ( $frames_begin <= $frames_end ) && \
	   [string is integer $frames_step] && ( $frames_step > 0 ) ) } {
      error
    }
  } ok ] } { error "bad -frames arg: $arg(frames)" }
  if $debug {
    puts "frames_begin: $frames_begin"
    puts "frames_step: $frames_step"
    puts "frames_end: $frames_end"
  }

  if [info exists arg(updatesel)] {
    switch -- $arg(updatesel) {
      yes { set updatesel 1 }
      no { set updatesel 0 }
      default { error "bad -updatesel arg: $arg(updatesel)" }
    }
  } else {
    set updatesel 0
  }
  if $debug {
    puts "updatesel: $updatesel"
  }

  # get cell dimensions
  if [info exists arg(cell)] {
    set cell $arg(cell)
  } elseif [info exists arg(xscfile)] {
    set cell [read_xsc_file $arg(xscfile)]
  } elseif [info exists arg(pad)] {
      set cell [make_padded_cell $mol $arg(pad)]
  } elseif [catch {get_cell_from_vmd $mol} cell] {
    variable default_cell_padding
    set cell [make_padded_cell $mol $default_cell_padding]
  }
  if $debug {puts "cell: $cell"}

  # get grid dimensions
  if [info exists arg(grid)] {
    if {[llength $arg(grid)] == 1} {
      if {$arg(grid) < 8.0} {
        set grid [make_grid_from_cell $cell $arg(grid)]
      } else {
        set grid [list $arg(grid) $arg(grid) $arg(grid)]
      }
    } else {
      set grid $arg(grid)
    }
  } else {
    variable default_grid_resolution
    set grid [make_grid_from_cell $cell $default_grid_resolution]
  }
  if $debug {puts "grid: $grid"}

  # get ewald factor
  if [info exists arg(ewaldfactor)] {
    set ewaldfactor $arg(ewaldfactor)
  } else {
    variable default_ewald_factor
    set ewaldfactor $default_ewald_factor
  }
  if $debug {puts "ewaldfactor: $ewaldfactor"}

  # get dxfile
  if [info exists arg(dxfile)] {
    set savedxfile 1
    set dxfile $arg(dxfile)
  } else {
    set savedxfile 0
    set dxfile [tempfile "pmedx_"]
  }
  if $debug {puts "dxfile: $dxfile"}

  # get loadmol
  if [info exists arg(loadmol)] {
    set loadmol $arg(loadmol)
    if {[string equal $loadmol "none"] && ! $savedxfile} {
      error "must provide \"-dxfile <file>\" when using \"-loadmol none\""
    }
    if [string equal $loadmol "same"] { set loadmol $mol }
  } else {
    set loadmol new
  }
  if $debug {puts "loadmol: $loadmol"}

  set tmpsel [atomselect $mol "charge != 0"]
  if { [$tmpsel num] == 0 } {
    $tmpsel delete
    error "no atoms with charges in molecule $mol"
  }

  set pme [pmepot_create $grid $ewaldfactor]
  if {! [info exists sel]} {
    set sel $tmpsel
  }
  if { [$sel num] == 0 } {
    $tmpsel delete
    error "no atoms in selection"
  }
  set oldselframe [$sel frame]
  set errFlag [catch {
    for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {
      puts "processing frame $f"
      $sel frame $f
      if { $updatesel } { puts "updating selection"; $sel update }
      pmepot_add $pme $cell [$sel get {x y z charge}]
    }
  } errMsg]
  $sel frame $oldselframe
  if { $updatesel } { puts "updating selection"; $sel update }
  $tmpsel delete
  if { $errFlag } {
    pmepot_destroy $pme
    error $errMsg
  }
  puts "writing potential to $dxfile"
  set errFlag [catch {pmepot_writedx $pme $dxfile} errMsg]
  pmepot_destroy $pme
  if { $errFlag } { error $errMsg }

  set errFlag [catch {
    switch -- $loadmol {
      none { }
      new {
        puts "loading potential from $dxfile to new molecule"
        set loadmol [mol new $dxfile type dx waitfor all]
        mol rename $loadmol "[molinfo $mol get name] PME"
        if { [ catch {
          molinfo $loadmol set {a b c alpha beta gamma} [make_vmd_cell $cell]
        } errMsg ] } {
          puts "unable to set cell in vmd: $errMsg"
        }
      }
      default {
        puts "loading potential from $dxfile to molecule $loadmol"
        mol addfile $dxfile type dx molid $loadmol waitfor all
      }
    }
  } errMsg ]

  if { ! $savedxfile } { file delete $dxfile }

  if $errFlag { error $errMsg }

  if { ! [string equal $loadmol "none"] } { return $loadmol }
}

proc ::PMEPot::make_grid_from_cell { cell resolution {max 0} } {
  foreach { o a b c } $cell { break }
  set a [expr 1.0 * [veclength $a] / $resolution]
  set b [expr 1.0 * [veclength $b] / $resolution]
  set c [expr 1.0 * [veclength $c] / $resolution]
  set na [good_fft_dim $a $max]
  set nb [good_fft_dim $b $max]
  set nc [good_fft_dim $c $max]
  return [list $na $nb $nc]
}

proc ::PMEPot::make_padded_cell { mol pad {usersel ""} } {
  if { [string equal $usersel ""] } {
    set sel [atomselect $mol "all"]
    set minmax [measure minmax $sel]
    $sel delete
  } else {
    set minmax [measure minmax $usersel]
  }
  set min [lindex $minmax 0]
  set max [lindex $minmax 1]
  set origin [vecscale 0.5 [vecadd $min $max]]
  set pad [expr $pad * 2.0]
  set side [vecadd [vecsub $max $min] [list $pad $pad $pad]]
  foreach {x y z} $side { break }
  return [list $origin [list $x 0 0] [list 0 $y 0] [list 0 0 $z]]
}

proc ::PMEPot::cell_sin { deg } {
  return [expr cos(acos(0.)*(($deg-90.0)/90.0))]
}
proc ::PMEPot::cell_cos { deg } {
  return [expr -1. * sin(acos(0.)*(($deg-90.0)/90.0))]
}

proc ::PMEPot::get_cell_from_vmd { mol } {
  set vmdcell [molinfo $mol get {a b c alpha beta gamma}]
  foreach {a b c alpha beta gamma} $vmdcell { break }
  if { $a <= 1.0 || $b <= 1.0 || $c <= 1.0 } {
    error "periodic cell information not present for molecule $mol"
  }

  set sel [atomselect $mol "all"]
  set minmax [measure minmax $sel]
  $sel delete
  set min [lindex $minmax 0]
  set max [lindex $minmax 1]
  set origin [vecscale 0.5 [vecadd $min $max]]

  return [make_namd_cell $origin $vmdcell]
}

proc ::PMEPot::make_namd_cell { origin vmdcell } {
  foreach {a b c alpha beta gamma} $vmdcell { break }

  set sinAB [cell_sin $gamma]
  set cosAB [cell_cos $gamma]
  set sinBC [cell_sin $alpha]
  set cosBC [cell_cos $alpha]
  set sinAC [cell_sin $beta]
  set cosAC [cell_cos $beta]

  set a_x [expr 1. * $a]

  set b_x [expr $b * $cosAB]
  set b_y [expr $b * $sinAB]

  if { $sinAB == 0 } {
    error "unit cell is degenerate (gamma = $gamma)"
  }

  set c_x [expr $c * $cosAC]
  set c_y [expr $c * ($cosBC - $cosAC * $cosAB) / $sinAB]
  set c_z2 [expr $c*$c - $c_x*$c_x - $c_y*$c_y]
  if { $c_z2 < 0. } {
    set c_z 0.
  } else {
    set c_z [expr sqrt($c_z2)]
  }

  return [list $origin [list $a_x 0 0] [list $b_x $b_y 0] [list $c_x $c_y $c_z]]
}

proc ::PMEPot::read_xsc_file { filename } {
  set f [open $filename "r"]
  while {[gets $f line] >= 0} {
    if {[lindex $line 0] == {#$LABELS}} {
      set labels [lrange $line 1 end]
      continue
    }
    if {[lindex $line 0] == {#}} {
      continue
    }
    foreach value $line label $labels {
       set c($label) $value
    }
  }
  close $f
  return [list [list $c(o_x) $c(o_y) $c(o_z)] \
               [list $c(a_x) $c(a_y) $c(a_z)] \
               [list $c(b_x) $c(b_y) $c(b_z)] \
               [list $c(c_x) $c(c_y) $c(c_z)] ]
}

proc ::PMEPot::good_fft_dim { r {max 0} } {
  variable default_grid_max_dim
  if { $max == 0 } { set max $default_grid_max_dim }
  if { $max < 8 } { error "max dimension of $max is too small" }
  set nl [list 8 10 12 16 20 24 30 32 36 40 48 50 56 60 64 72 80 \
		84 88 96 100 108 112 120 128]
  set goodn 8
  foreach mi {1 2 3 4 5 6 8 10} {
    foreach ni $nl {
      set n [expr $mi * $ni]
      if {$n > $max} { return $goodn }
      if {$n > $goodn} { set goodn $n }
      if {$goodn >= $r} { return $goodn }
    }
  }
  return $goodn
}

proc ::PMEPot::make_vmd_cell { cell } {
  foreach {origin avec bvec cvec} $cell { }
  foreach {a_x a_y a_z} $avec { }
  foreach {b_x b_y b_z} $bvec { }
  foreach {c_x c_y c_z} $cvec { }
  set deg [expr 180.0 / acos(-1.0)]
  if { $a_x <= 0 || $a_y != 0 || $a_z != 0 } {
    error "a not along x axis: $avec"
  }
  set a $a_x
  if { $b_y <= 0 || $b_z != 0 } { error "b not on x-y plane: $bvec" }
  set b [veclength $bvec]
  if { $c_z <= 0 || $b_z != 0 } { error "b not on x-y plane: $bvec" }
  set c [veclength $cvec]
  set alpha [expr $deg * acos([vecdot $bvec $cvec]/($b * $c))]
  set beta [expr $deg * acos([vecdot $cvec $avec]/($c * $a))]
  set gamma [expr $deg * acos([vecdot $avec $bvec]/($a * $b))]
  return [list $a $b $c $alpha $beta $gamma]
}


# copied from fileutil.tcl --
#
#	Tcl implementations of standard UNIX utilities.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2002      by Phil Ehrens <phil@slug.org> (fileType)
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# ::fileutil::tempdir --
#
#	Return the correct directory to use for temporary files.
#	Python attempts this sequence, which seems logical:
#
#       1. The directory named by the `TMPDIR' environment variable.
#
#       2. The directory named by the `TEMP' environment variable.
#
#       3. The directory named by the `TMP' environment variable.
#
#       4. A platform-specific location:
#            * On Macintosh, the `Temporary Items' folder.
#
#            * On Windows, the directories `C:\\TEMP', `C:\\TMP',
#              `\\TEMP', and `\\TMP', in that order.
#
#            * On all other platforms, the directories `/tmp',
#              `/var/tmp', and `/usr/tmp', in that order.
#
#        5. As a last resort, the current working directory.
#
# Arguments:
#	None.
#
# Side Effects:
#	None.
#
# Results:
#	The directory for temporary files.

proc ::PMEPot::TempDir {} {
    global tcl_platform env
    set attempdirs [list]

    foreach tmp {TMPDIR TEMP TMP} {
	if { [info exists env($tmp)] } {
	    lappend attempdirs $env($tmp)
	}
    }

    switch $tcl_platform(platform) {
	windows {
	    lappend attempdirs "C:\\TEMP" "C:\\TMP" "\\TEMP" "\\TMP"
	}
	macintosh {
	    set tmpdir $env(TRASH_FOLDER)  ;# a better place?
	}
	default {
	    lappend attempdirs [file join / tmp] \
		[file join / var tmp] [file join / usr tmp]
	}
    }

    foreach tmp $attempdirs {
	if { [file isdirectory $tmp] && [file writable $tmp] } {
	    return $tmp
	}
    }

    # If nothing else worked...
    return [pwd]
}

if { [package vcompare [package provide Tcl] 8.4] < 0 } {
    proc ::PMEPot::tempdir {} {
	return [TempDir]
    }
} else {
    proc ::PMEPot::tempdir {} {
	return [file normalize [TempDir]]
    }
}

# ::fileutil::tempfile --
#
#   generate a temporary file name suitable for writing to
#   the file name will be unique, writable and will be in the 
#   appropriate system specific temp directory
#   Code taken from http://mini.net/tcl/772 attributed to
#    Igor Volobouev and anon.
#
# Arguments:
#   prefix     - a prefix for the filename, p
# Results:
#   returns a file name
#

proc ::PMEPot::TempFile {prefix} {
    set tmpdir [tempdir]

    set chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    set nrand_chars 10
    set maxtries 10
    set access [list RDWR CREAT EXCL TRUNC]
    set permission 0600
    set channel ""
    set checked_dir_writable 0
    set mypid [pid]
    for {set i 0} {$i < $maxtries} {incr i} {
 	set newname $prefix
 	for {set j 0} {$j < $nrand_chars} {incr j} {
 	    append newname [string index $chars \
		    [expr {([clock clicks] ^ $mypid) % 62}]]
 	}
	set newname [file join $tmpdir $newname]
 	if {[file exists $newname]} {
 	    after 1
 	} else {
 	    if {[catch {open $newname $access $permission} channel]} {
 		if {!$checked_dir_writable} {
 		    set dirname [file dirname $newname]
 		    if {![file writable $dirname]} {
 			return -code error "Directory $dirname is not writable"
 		    }
 		    set checked_dir_writable 1
 		}
 	    } else {
 		# Success
		close $channel
 		return $newname
 	    }
 	}
    }
    if {[string compare $channel ""]} {
 	return -code error "Failed to open a temporary file: $channel"
    } else {
 	return -code error "Failed to find an unused temporary file name"
    }
}

if { [package vcompare [package provide Tcl] 8.4] < 0 } {
    proc ::PMEPot::tempfile {{prefix {}}} {
	return [TempFile $prefix]
    }
} else {
    proc ::PMEPot::tempfile {{prefix {}}} {
	return [file normalize [TempFile $prefix]]
    }
}


