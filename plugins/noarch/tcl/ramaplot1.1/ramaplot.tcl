#
# Ramachandran plot generator
#
# $Id: ramaplot.tcl,v 1.9 2006/08/16 04:05:45 johns Exp $
# 
# Version history:
#
# 1.1:
# include the mk3drama script to create a color coded 3d-ramachandran 
# histogram graph in a new 'molecule'
#

package provide ramaplot 1.1

namespace eval ::RamaPlot:: {
  #namespace export ramaplot

  variable selection ""	;# atom selections for current molecule 
  variable molid ""	;# molid of current molecule
  variable seltext all  ;# selection text in entry box
  variable hlresid -1   ;# highlight resid
  variable w 		;# handle to window
  variable data		;# you know, data
  variable box		;# all those little boxes I draw
  variable lastsavedfile ramaplot.ps
  variable moldispstat "";# store displayed status before hiding for mk3drama
}

proc ::RamaPlot::ramaCanvas { c args } {
  frame $c
  eval { canvas $c.canvas -highlightthickness 0 -borderwidth 0 -background white} $args
  grid $c.canvas -sticky news
  grid rowconfigure $c 0 -weight 1
  grid columnconfigure $c 0 -weight 1
  return $c.canvas
}

proc ::RamaPlot::ramaZones { c } {
 catch {unset zlist}
lappend zlist { \
  {-180.2       42.9 }\
  {-140.8       16.1 }\
  {-86.0        16.1 }\
  {-74.3        45.6 }\
  {-74.3        72.5 }\
  {-44.3        102.0 }\
  {-44.3        161.1 }\
  {-46.9        179.9 }\
  {-180         180} \
  }

 lappend zlist { \
  {-156.5       91.3 }\
  {-70.4        91.3 }\
  {-54.7        112.8 }\
  {-54.7        173.2 }\
  {-136.95      173.2 }\
  {-136.9       155.8 }\
  {-156.5       135.6}\
  {-156.5       91.3 }\
  }

lappend zlist { \
  {-180.        -34.9 }\
  {-164.3       -42.9 }\
  {-133.0       -42.9 }\
  {-109.5       -32.2 }\
  {-106.9       -21.4 }\
  {-44.3        -21.4 }\
  {-44.3        -71.1 }\
  {-180.0       -71.1 }\
  }

lappend zlist { \
  {-156.5       -60.4 }\
  {-54.7        -60.4 }\
  {-54.7        -40.2 }\
  {-100.4       -40.2 }\
  {-123.9       -51.0 }\
  {-156.5       -51.0 }\
  {-156.5       -60.4 }\
  }

lappend zlist {
  {-180.0       -163.8 } \
  {-75.6        -163.8 } \
  {-46.9        -180.0 } \
  {-180.0       -180.0 } \
  }

lappend zlist {
  {62.6 14.7 } \
  {62.6 96.7 } \
  {45.6 79.2 } \
  {45.6 26.8 } \
  {62.6 14.7 } \
  }

  foreach zone $zlist color { green blue green blue green green  } {
    set poly ""
    foreach z $zone {
      lassign $z phi psi
      lappend poly [expr 185 + $phi] [expr 185 - $psi]
    }
    eval {$c create polygon} $poly {-tag zone -fill $color}
  }
}

proc ramaplot {} {
  ::RamaPlot::ramaplot
}

proc ::RamaPlot::ramaplot {} {
  # Just create the window and initialize data structures
  # No molecule has been selected yet
  # Also set up traces on VMD variables

  variable selection
  variable w
    
  global vmd_frame
  global vmd_initialize_structure

  # If already initialized, just turn on 
  if [winfo exists .rama] {
    wm deiconify $w
    return
  }

  set w [toplevel ".rama"]
  wm title $w "RamaPlot - Dynamic Ramachandran plots for VMD"
  wm resizable $w 0 0
  bind $w <Destroy> ::RamaPlot::destroy
  
  # This is necessary to make ramaplot update itself when first opened to make
  # sure it's displaying current information.
  bind $w <Map> ::RamaPlot::ramaUpdate
 
  frame $w.top

  # Create menubar
  frame $w.top.menubar -relief raised -bd 2
  pack $w.top.menubar -padx 1 -fill x -side top
  menubutton $w.top.menubar.file -text "File   " -underline 0 -menu $w.top.menubar.file.menu
  $w.top.menubar.file config -width 5
  pack $w.top.menubar.file -side left

  # File menu
  menu $w.top.menubar.file.menu -tearoff no
  $w.top.menubar.file.menu add command -label "Print to file..." \
        -command [namespace code printCanvas]


  # Help menu
  menubutton $w.top.menubar.help -text "Help   " -menu $w.top.menubar.help.menu
  $w.top.menubar.help config -width 5
  pack $w.top.menubar.help -side right 
  menu $w.top.menubar.help.menu -tearoff no
  $w.top.menubar.help.menu add command -label "Ramaplot Help..." -command "vmd_open_url [string trimright [vmdinfo www] /]/plugins/ramaplot"


  ramaCanvas $w.fr -width 370 -height 370
  pack $w.fr -in $w.top -fill both -expand true -side left

  ramaZones $w.fr.canvas

  frame $w.data

  # Create molecule selection menu
  frame $w.data.mol
  label $w.data.mol.l -text Molecule -anchor w
  menubutton $w.data.mol.m -relief raised -bd 2 -direction flush \
	-textvariable ::RamaPlot::molid \
	-menu $w.data.mol.m.menu
  menu $w.data.mol.m.menu 
  trace variable ::RamaPlot::molid w [namespace code ramaChangeMolecule]

  pack $w.data.mol.l -side left
  pack $w.data.mol.m -side right
  pack $w.data.mol -side top

  # Create atom selection entry
  frame $w.data.sel
  label $w.data.sel.l -text Selection -anchor w
  entry $w.data.sel.e -relief sunken -width 18 -bg White \
	-textvariable [namespace current]::seltext
  bind $w.data.sel.e <Return> [namespace code ramaChangeMolecule]
  pack $w.data.sel.l -side top
  pack $w.data.sel.e -side top
  pack $w.data.sel -side top

  # Create fields for displaying info about last clicked residue
  frame $w.data.info
  foreach field {Segid Resname Resid Phi Psi} {
    label $w.data.info.l$field -text $field -anchor w
    entry $w.data.info.e$field -relief sunken -width 10
    grid $w.data.info.l$field $w.data.info.e$field -sticky news
  }
  pack $w.data.info -side top

  # 3d rama plot buttons.
  frame  $w.data.space -height 50
  button $w.data.mk3d  -text {Create 3-d Histogram} -command [namespace code mk3drama]
  button $w.data.del3d -text {Delete 3-d Histogram} -command [namespace code del3drama]
  pack $w.data.space $w.data.mk3d $w.data.del3d -side top

  pack $w.data -in $w.top -side right

  pack $w.top
  # Draw grid lines on the x and y axes
  $w.fr.canvas create line 5 185 365 185 -tag grid
  $w.fr.canvas create line 185 5 185 365 -tag grid
  $w.fr.canvas bind residue <Button-1> [namespace code { ramaHighlight %x %y}]
  $w.fr.canvas bind line <Button-1> [namespace code { ramaGoto %W}]

  # Update the marks every time there's a new frame
  trace variable vmd_frame w [namespace code ramaUpdate]

  # Update the molecules when molecules are deleted or added
  trace variable vmd_initialize_structure w [namespace code ramaUpdateMolecules]

  # Set up the molecule list
  ramaUpdateMolecules
}

# Finds the 
proc ::RamaPlot::ramaGoto { w } {
  set id [ $w find withtag current]
  set taglist [$w gettags $id]
  set listindex [lsearch -glob $taglist frame*]
  if { $listindex < 0 } {
    return
  }
  set frametag [lindex $taglist $listindex]
  lassign [split $frametag :] foo frame
  animate goto $frame
}


proc ::RamaPlot::printCanvas { args } {
  variable w
  variable lastsavedfile

  set filename [tk_getSaveFile \
        -initialfile $lastsavedfile \
        -title "Print Ramachandran diagram to file" \
        -parent $w \
        -filetypes [list {{Postscript files} {.ps}} {{All files} {*}}]]
  if {$filename != ""} {
    $w.fr.canvas postscript -file $filename
    set lastsavedfile $filename
  }
  return
}

proc ::RamaPlot::destroy { args } {
  # Delete traces
  # Delete remaining selections

  variable selection
  variable molid
  global vmd_frame
  global vmd_initialize_structure
  
  trace vdelete molid w [namespace code ramaChangeMolecule]
  trace vdelete vmd_frame w [namespace code ramaUpdate]
  trace vdelete vmd_initialize_structure w [namespace code ramaUpdateMolecules]

  catch {$selection delete}
}

proc ::RamaPlot::ramaUpdateMolecules { args } {
  variable selection
  variable w
  variable molid

  set mollist [molinfo list]
  
  # Invalidate the selection if necessary
  if { [lsearch $mollist $molid] < 0 } {
    catch {$selection delete}
    set selection ""
  }    

  # Update the molecule browser
  $w.data.mol.m.menu delete 0 end
  $w.data.mol.m configure -state disabled
  if { [llength $mollist] != 0 } {
    foreach id $mollist {
      if {[molinfo $id get filetype] != "graphics"} {
        $w.data.mol.m configure -state normal 
        $w.data.mol.m.menu add radiobutton -value $id \
	  -label "$id [molinfo $id get name]" \
	  -variable ::RamaPlot::molid 
      }
    }
  }
}

proc ::RamaPlot::ramaChangeMolecule { args } {
  variable selection
  variable seltext
  variable molid
  variable box
  variable data
  variable w
  variable hlresid
 
  # Invalidate the highlight resid
  set hlresid -1

  # Get rid of the highlights from the previous molecule
  $w.fr.canvas delete line

  if { $molid == "" || [lsearch [molinfo list] $molid] < 0} {
    return
  }
   
  wm title $w "Ramachandran plot for molecule $molid [molinfo $molid get name]"
  if { $seltext == "" } {
    set seltext all
  }
  if {![catch {set sel [atomselect $molid "name CA and $seltext"]}]} {
    catch {$selection delete}
    set selection $sel
    $selection global
  } else {
    puts "Unable to create new selection!"
    return
  }

  # Process data and boxes
  # data has unique residues as keys and {{segid resid resname} id phi psi}
  # as values.
  # Populate data array with names.  Since the names presumably won't change
  # we can do this now and save some time in ramaHighlight.  We store the id
  # in the data array as well so that when we update, we can easily move the
  # correct box.  We use the box array only to look up selections.

  catch {unset box}
  catch {unset data}
  $w.fr.canvas delete residue

  set recsize 2.5
  set xmin -185
  set ymax 185

  foreach residue [$selection get residue] \
          namedata [$selection get {segid resid resname}] {
    set x1 [expr -$xmin - $recsize]
    set y1 [expr $ymax + $recsize]
    set x2 [expr $x1 + 2 * $recsize]
    set y2 [expr $y1 - 2 * $recsize]
    set id [$w.fr.canvas create rectangle $x1 $y1 $x2 $y2 \
                -fill yellow -tags residue]
    set box($id) $residue
    set data($residue) [list $namedata $id 0 0]
  }
  ramaUpdate
}

proc ::RamaPlot::ramaUpdate { args } {
  variable data
  variable box
  variable w
  variable selection
  variable hlresid
 
  if { ![string compare $selection ""] } {
    return
  }

  # Don't update if the window isn't turned on
  if { [string compare [wm state $w] normal] } {
    return
  }

  foreach residue [$selection get residue] \
          phi [$selection get phi] \
          psi [$selection get psi] {
    lassign $data($residue) names id oldphi oldpsi
    set dphi [expr $phi - $oldphi]
    set dpsi [expr $oldpsi - $psi]
    set data($residue) [list $names $id $phi $psi]
    # Move the box to its correct position
    $w.fr.canvas move $id $dphi $dpsi
  }
  if { $hlresid >= 0 } {
    lassign $data($hlresid) names id phi psi
    $w.data.info.ePhi delete 0 end
    $w.data.info.ePhi insert 0 $phi
    $w.data.info.ePsi delete 0 end
    $w.data.info.ePsi insert 0 $psi
  } else {
    $w.fr.canvas delete highlight
  }

}

proc ::RamaPlot::ramaHighlight { x y } {
  variable data
  variable box
  variable w
  variable selection
  variable hlresid
  variable highlighton

  set id [$w.fr.canvas find withtag current]
  set taglist [$w.fr.canvas gettags $id]
  if { [lsearch $taglist residue] < 0 } {
    return
  }

  $w.fr.canvas delete line
  $w.fr.canvas itemconfigure highlight -outline black -fill yellow
  $w.fr.canvas dtag residue highlight

  set residue $box($id)
  lassign $data($residue) names id phi psi
  lassign $names segid resid resname
  foreach field {Segid Resid Resname Phi Psi} \
          value [list $segid $resid $resname $phi $psi] {
    $w.data.info.e$field delete 0 end
    $w.data.info.e$field insert 0 $value
  }

  # Highlight the selected residue
  $w.fr.canvas itemconfigure $id -outline red -fill red
  $w.fr.canvas addtag highlight withtag $id

  # Draw lines for the trajectory of the selected residue, unless we just
  # selected the same residue
  if { $hlresid == $resid && $highlighton == 1 } {
    set highlighton 0
    return
  }
  set hlresid $resid
  set highlighton 1

  if { [string compare $selection ""] } {
    set molid [$selection molid]
    set n [molinfo $molid get numframes]

    set sel [atomselect $molid "residue $residue and name CA"]
    for { set i 0 } { $i < $n } { incr i } {
      $sel frame $i
      lassign [lindex [$sel get {phi psi}] 0]  phi psi
      set phi [expr $phi + 185]
      set psi [expr 185 - $psi]
      $w.fr.canvas create rectangle \
	[expr $phi -2.5] [expr $psi -2.5] [expr $phi + 2.5] [expr $psi + 2.5] \
	-tag "line frame:$i"
      set oldphi $phi
      set oldpsi $psi
    }
    # We want to be able to see the highlight above the lines.
    # We need catch because raise causes an error if no lines are drawn.  Lame!
    catch {$w.fr.canvas raise highlight line}
  }

}

# creates a color coded 3d-ramachandran histogram graph 
# in a new 'molecule'
# Copyright (c) 2003-2006 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
# some ideas 'borrowed' from the script 3D_grapher by Andrew Dalke.
proc ::RamaPlot::mk3drama {{res 48}} {
    variable selection
    variable moldispstat

    if { ![string compare $selection ""] } {
         return
    }
    set sel $selection
    # sanity check(s).
    set a [$sel num]
    if { $a < 1} {
        tk_dialog .errmsg {RamaPlot Error} "No atoms in selection." error 0 Dismiss
        return
    }
    set n [molinfo [$sel molid] get numframes]
    if {$n < 1} {
        tk_dialog .errmsg {RamaPlot Error} "No coordinate data available." error 0 Dismiss
        return
    }

    # define binwidth
    set w [expr ($res - 1.0)/360.0]

    # clear histogram
    for {set i 0} {$i <= $res} {incr i} {
        for {set j 0} {$j <= $res} {incr j} {
            set data($i,$j) 0
        }
    }

    # collect data into histogram
    puts "collecting dihedral data from $n frames for $a atoms"
    for {set i 0 } { $i < $n } { incr i } {
        $sel frame $i
        $sel update

        foreach a [$sel get {phi psi}] {
            set phi [lindex $a 0]
            set psi [lindex $a 1]
            incr data([expr int(($phi + 180.0) * $w)],[expr int(($psi + 180.0) * $w)])
        }
    }

    # find maximum for normalization
    set maxz 0
    for {set i 0} {$i < $res} {incr i} {
        for {set j 0} {$j < $res} {incr j} {
            if { $data($i,$j) > $maxz } {set maxz $data($i,$j)}
        }
    }

    # turn off all existing molecules and save their views.
    save_viewpoint
    set moldispstat {}
    foreach mol [molinfo list] {
        lappend moldispstat [molinfo $mol get {id drawn}]
        mol off $mol
    }

    # (re-)create dummy molecule to draw into
    foreach m [molinfo list] {
      if {[molinfo $m get name] == "{3d Ramachandran Histogram}"} {
         mol delete $m
      }
    }
    set mol [mol new]
    mol rename top {3d Ramachandran Histogram}

    # the resulting graph should have a size of 10x10x5
    # and centered at the origin. get scaling factors for that.
    set len  [expr 10.0 / $res]
    set norm [expr 5.0 / $maxz]

    # make sure the data wraps around nicely
    # and normalize the histogram
    for {set i 0} {$i <= $res} {incr i} {
        set data([expr $res - 1],$i) $data(0,$i)
        set data($res,$i) $data(1,$i)
        set data($i,[expr $res - 1]) $data($i,0)
        set data($i,$res) $data($i,1)
    }
    for {set i 0} {$i <= $res} {incr i} {
        for {set j 0} {$j <= $res} {incr j} {
            set data($i,$j) [expr $data($i,$j) * $norm]
        }
    }

    # setup color scaling
    color scale method BGR
    color scale max 0.9
    color scale midpoint 0.3

    # get min/max colorid
    set mincolor [colorinfo num]
    set maxcolor [colorinfo max]
    set ncolorid [expr $maxcolor - $mincolor]

    # finally draw the surface by drawing triangles between
    # the midpoint and the corners of each square of data points
    for {set i 0} {$i < $res} {incr i} {
        for {set j 0} {$j < $res} {incr j} {

            # precalculate some coordinates and indices
            set i2 [expr $i + 1]
            set j2 [expr $j + 1]

            set x1 [expr ($i  - (0.5 * $res)) * $len]
            set x2 [expr ($i2 - (0.5 * $res)) * $len]
            set xm [expr 0.5 * ($x1 + $x2)]

            set y1 [expr ($j  - (0.5 * $res)) * $len]
            set y2 [expr ($j2 - (0.5 * $res)) * $len]
            set ym [expr 0.5 * ($y1 + $y2)]

            set zm [expr ($data($i,$j) + $data($i2,$j2) \
                        + $data($i2,$j) + $data($i,$j2)) / 4.0] 

            # calculate color for the triangles. note: we normalize to Zmax=5.0.
            graphics $mol color [expr $mincolor + int (0.2 * $ncolorid * $zm)] 

            # draw 4 triangles
            graphics $mol triangle "$x1 $y1 $data($i,$j)"     \
                "$xm $ym $zm" "$x2 $y1 $data($i2,$j)"
            graphics $mol triangle "$x1 $y1 $data($i,$j)"     \
                "$x1 $y2 $data($i,$j2)" "$xm $ym $zm"
            graphics $mol triangle "$x2 $y2 $data($i2,$j2)"   \
                "$x2 $y1 $data($i2,$j)" "$xm $ym $zm"
            graphics $mol triangle "$x2 $y2 $data($i2,$j2)"   \
                "$xm $ym $zm" "$x1 $y2 $data($i,$j2)"
        }
    }

    # add some decorations to the graph so that the 
    # peaks can be more easily located.
    # border
    graphics $mol color red
    graphics $mol sphere {-5.0 -5.0 0.0} radius 0.15 resolution 30
    graphics $mol sphere { 5.0 -5.0 0.0} radius 0.15 resolution 30
    graphics $mol sphere {-5.0  5.0 0.0} radius 0.15 resolution 30
    graphics $mol sphere { 5.0  5.0 0.0} radius 0.15 resolution 30
    graphics $mol cylinder { 5.0  5.0 0.0} {-5.0  5.0 0.0} radius 0.15 resolution 30
    graphics $mol cylinder {-5.0  5.0 0.0} {-5.0 -5.0 0.0} radius 0.15 resolution 30
    graphics $mol cylinder {-5.0 -5.0 0.0} { 5.0 -5.0 0.0} radius 0.15 resolution 30
    graphics $mol cylinder { 5.0 -5.0 0.0} { 5.0  5.0 0.0} radius 0.15 resolution 30
    # 0 degree lines
    graphics $mol color yellow
    graphics $mol sphere {-5.0  0.0 0.0} radius 0.1 resolution 30
    graphics $mol sphere { 5.0  0.0 0.0} radius 0.1 resolution 30
    graphics $mol sphere { 0.0 -5.0 0.0} radius 0.1 resolution 30
    graphics $mol sphere { 0.0  5.0 0.0} radius 0.1 resolution 30
    graphics $mol cylinder { 5.0  0.0 0.0} {-5.0  0.0 0.0} radius 0.1 resolution 30
    graphics $mol cylinder { 0.0  5.0 0.0} { 0.0 -5.0 0.0} radius 0.1 resolution 30
    # text labels 
    if {[string compare [colorinfo category Display Background] "white"] == 0} {
        graphics $mol color black
    } else {
        graphics $mol color white
    }
    graphics $mol text {0.0 -5.8 0.0} {Phi} size 2
    graphics $mol text {5.2  0.0 0.0} {Psi} size 2

    # set viewing angle to a resonable default.
    display resetview
    rotate x by -55
    rotate y by 10
    scale by 0.95

    # clean up
    unset data
}

# if there's rama plot display, delete it and restore the previous view(s).
proc ::RamaPlot::del3drama { } {
    variable moldispstat

    set deleted 0
    foreach m [molinfo list] {
        if {[molinfo $m get name] == "{3d Ramachandran Histogram}"} {
            mol delete $m
            set deleted 1
        }
    }

    # no restore if there was non 3d graph.
    if {$deleted == 0 } {
         return
    }
    foreach stat $moldispstat {
        if {[lindex $stat 1]} {
            mol on [lindex $stat 0]
        }
    }
    restore_viewpoint
}


proc ramaplot_tk {} {
  ::RamaPlot::ramaplot
  return $::RamaPlot::w
}

