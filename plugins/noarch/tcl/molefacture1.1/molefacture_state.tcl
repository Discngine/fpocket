proc ::Molefacture::init_oxidation {} {
  #Initialize the oxidation array

  variable oxidation
  variable tmpmolid
  variable periodic 
  variable valence
  set oxidation [list]
  set sel [atomselect $tmpmolid all]

  foreach atom [$sel get index] {
    set mother [atomselect $tmpmolid "index $atom"]
    set element  [lindex $periodic [$mother get atomicnumber]]
#puts "$atom $element [$mother get atomicnumber]"
    set valences [lindex [array get valence $element] 1] 
#puts "DEBUG a"
#    set valences [lindex [array get valence $element] [lindex $oxidation $atom]] 
    set i 0
#    puts "Valence: $valences"
    if {[llength $valences] > 1} {
#      puts "Checking valence for atom $atom"
      set currval [lindex $valences $i]
      set numbonds [llength [lindex [$mother getbonds] 0]]
#puts "Comparing: currval=$currval numbonds=$numbonds"
      while {$currval < $numbonds && $i < [llength $valences]} {
        incr i
        set currval [lindex $valences $i]
      }
#puts "Comparing: currval=$currval numbonds=$numbonds"
      if {[llength $valences] < $i} {incr i -1}

    }
    $mother delete
    lappend oxidation $i
#puts "DEBUG: index: $atom oxlength: [llength $oxidation]"
  }
#  puts $oxidation
#  puts "exit"
}




proc ::Molefacture::drawlone {startcoor endcoor} {
#  variable lpmol
  if {$endcoor == ""} {return}
  variable tmpmolid
  graphics $tmpmolid color purple 
  variable ovalmarktags
  variable tmpmolid

  lappend ovalmarktags [graphics $tmpmolid cone $endcoor $startcoor radius 0.15] 
  lappend ovalmarktags [graphics $tmpmolid sphere $endcoor radius 0.15 ]
  graphics $tmpmolid color green
}

proc ::Molefacture::drawlp {startcoor endcoor} {
#  variable lpmol
#        puts "DEBUG F"
  if {$endcoor == ""} {return}
#puts "Entering drawlp"
  variable tmpmolid
  variable ovalmarktags
#puts "Coors: $startcoor $endcoor"
  set v1 [vecsub $startcoor {0 0 0}]
  set v2 [vecsub $endcoor {0 0 0}]
  set pvec [veccross $v1 $v2]
  if {[veclength $pvec] == 0} {set pvec {1 0 0}}
  set mvec [vecscale 0.3 [vecnorm $pvec]]

  set distvec [vecsub $startcoor $endcoor]
  set distvec [vecscale 0.75 $distvec]

  lappend ovalmarktags [graphics $tmpmolid cone [vecsub $startcoor $distvec] $startcoor radius 0.1]
  lappend ovalmarktags [graphics $tmpmolid sphere [vecadd $endcoor $mvec] radius 0.15]
  lappend ovalmarktags [graphics $tmpmolid sphere [vecsub $endcoor $mvec] radius 0.15] 
#puts "DEBUG G"
}

proc ::Molefacture::drawlpbarbell {startcoor endcoor1 endcoor2} {
  variable tmpmolid
  variable ovalmarktags

  lappend ovalmarktags [graphics $tmpmolid cone $endcoor1 $startcoor radius 0.15] 
  lappend ovalmarktags [graphics $tmpmolid sphere $endcoor1 radius 0.15 ]
  lappend ovalmarktags [graphics $tmpmolid cone $endcoor2 $startcoor radius 0.15] 
  lappend ovalmarktags [graphics $tmpmolid sphere $endcoor2 radius 0.15 ]
}

proc ::Molefacture::assign_elements {} {
   variable tmpmolid
   variable periodic

   set sel [atomselect $tmpmolid "occupancy>0.4"]

   foreach name [$sel get name] resname [$sel get resname] mass [$sel get mass] index [$sel get index] {
     set curratom [atomselect $tmpmolid "index $index"]
     set element [get_element $name $resname $mass]
#puts "$name $resname $mass $index $element"
     set element_id [lsearch $periodic "$element"]
     $curratom set atomicnumber $element_id
     $curratom delete
   }
}

proc ::Molefacture::update_openvalence { } {
   variable tmpmolid
   variable periodic
   variable valence
   variable atomlist        [list] 
   variable chargelist      [list]
   variable openvalencelist [list]
   variable totalcharge 0
   variable oxidation
   variable atomlistformat
   variable projectsaved
   set projectsaved 0

#puts "DEBUG D"
#puts "$tmpmolid"
   set sel [atomselect $tmpmolid "occupancy>0.4"]
   foreach vmdind [$sel list] name [$sel get name] sbonds [$sel getbonds] bondorders [$sel getbondorders] elemind [$sel get atomicnumber] truecharge [$sel get charge] type [$sel get type] {
      if {$vmdind == ""} { continue }
      set nbonds 0
      foreach bo $bondorders {
         set bo [expr int($bo)]
         if {$bo < 0} { set bo 1 } 
         incr nbonds $bo
      }
#      puts "Elemind: $elemind"
      set element [lindex $periodic $elemind]
#puts "DEBUG: 5"
      if {[lindex $oxidation $vmdind] == ""} {set oxidation [lset oxidation $vmdind 0]}
#    puts "Ox: $vmdind | [lindex $oxidation $vmdind] | [lindex [array get valence $element] 1]"
      set val  [lindex [lindex [array get valence $element] 1] [lindex $oxidation $vmdind]]
#set val 4
#puts "Index: $vmdind Valence: $val ox: [lindex $oxidation $vmdind]"
#puts "$vmdind | $name | $sbonds | $bondorders | $elemind | $truecharge | $type"
      set openval [expr $val-$nbonds]
#puts "DEBUG: 6"
#puts "For atom of type $element, we have valence of $val, $nbonds bonds, and an open valence of $openval"
      lappend openvalencelist $openval
      set charge [expr $nbonds-$val]
      set totalcharge [expr $charge + $totalcharge]
      lappend chargelist $charge
      set myval [lindex [lindex [array get valence $element] 1] [lindex $oxidation $vmdind]]
#puts "Index: $vmdind oxstate $myval oxnum [lindex $oxidation $vmdind]"
#      puts "\[format \"$atomlistformat\" $vmdind $name $element $openval $charge $myval\]"
      if {$type == ""} {
        set type "X"
      }
      set myval [expr int($myval)]
      if {$element == ""} {set element "X"}
      if {$type    == ""} {set type   "{}"}
      set formatcommand "\[format \"$atomlistformat\" $vmdind $name $type $element $openval $charge $myval $truecharge\]"
#      puts "Element: $element"
#puts "$formatcommand"
#      eval set atomelem "$formatcommand"
      set atomelem [format $atomlistformat $vmdind $name $type $element $openval $charge $myval $truecharge]
      #lappend atomlist [format "%5i %4s %2s %2i %+2i" $vmdind $name $element $openval $charge]
      lappend atomlist $atomelem
   }

   # Clean up
   catch {$sel delete}

   # Delete unneeded temporary molecules
   foreach molid [molinfo list] {
     #puts "Checking for deletion: $molid"
     if {$molid == $tmpmolid} {continue}
     if {[string compare -length 12 "Molefacture_" [molinfo $molid get name]] == 0} {mol delete $molid}
   }

   draw_openvalence
   variable bondlist [bondlist]
   variable anglelist [anglelist]
}

proc ::Molefacture::fix_changes {} {
  variable tmpmolid
  set sel [atomselect $tmpmolid "occupancy>0.45 and occupancy<1"]
  $sel set occupancy 0.8
  $sel delete

  set sel [atomselect $tmpmolid "occupancy < 0.45"]
  $sel set occupancy 0
  $sel delete
}

proc ::Molefacture::undo_changes {} {
  # Remove added hydrogens
  variable tmpmolid
  set sel [atomselect $tmpmolid "occupancy 0.5"]
  set indexarray [$sel get index]
  foreach i $indexarray {
    set sel2 [atomselect $tmpmolid "index $i"]
    set bonds2 [$sel2 getbonds]
    foreach j $bonds2 {
      vmd_delbond $i $j 
      vmd_delbond $j $i
    }
    $sel2 delete
  }
  $sel set occupancy 0
    
  $sel delete

  # Undelete deleted atoms
  set sel [atomselect $tmpmolid "occupancy 0.3"]
  set indexarray [$sel get index]
  foreach i $indexarray {
    set sel2 [atomselect $tmpmolid "index $i"]
    set bonds2 [$sel2 getbonds]
#puts "Bonds: $bonds2"
    foreach j [join $bonds2] {
#            puts "$i $j"
      vmd_addbond $i $j 
      vmd_addbond $j $i
    }
    $sel2 delete
  }
  $sel set occupancy 1
  $sel delete
  update_openvalence
}
