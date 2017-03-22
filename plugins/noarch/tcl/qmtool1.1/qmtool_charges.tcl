#
# routines for reading/writing charges
#
# $Id: qmtool_charges.tcl,v 1.4 2006/03/15 02:48:31 saam Exp $
#

#########################################################
# Read next set of NPA charges with respect to current  #
# file position from Gaussian logfile.                  #
#########################################################

proc ::QMtool::read_gaussian_npacharges { fid } {
   variable havenpa 0
   variable npachargelabels 0

   # Remember file position. In case no NPA charges are found, we can rewind.
   set filepos [tell $fid]

   set offset 0;
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # We only read Link0
      if {[string match "Normal termination of Gaussian*" $line]} { break }

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }
      if {[string match "Summary of Natural Population Analysis:" $line]} {
	 incr offset;
      }
      
      if {$offset>6} {
	 if {[string match "==========*" $line]} { continue }
	 if {[string match "* Total *" $line]} {
	    set totalcharge [lindex $line 3]
	    set havenpa 1
	    break
	 }
	 set index   [expr [lindex $line 1]-1]
	 set_atomprop NPA $index [lindex $line 2]
      }
   }

   if {!$havenpa} { 
      puts "NPA charges not found!" 
      seek $fid $filepos
   }
   variable atomproptags
   lappend atomproptags NPA
   return 1
}


#########################################################
# Read next set of ESP charges with respect to current  #
# file position from Gaussian logfile.                  #
#########################################################

proc ::QMtool::read_gaussian_espcharges { fid } {
   variable haveesp 0
   variable espchargelabels 0

   # Remember file position. In case no ESP charges are found, we can rewind.
   set filepos [tell $fid]

   set offset 0;
   while {![eof $fid]} {
      set line [string trim [gets $fid]]

      # We only read Link0
      if {[string match "Normal termination of Gaussian*" $line]} { break }

      # Look for the beginning of parameter list
      if {$offset} { incr offset; }
      if {[string match "Charges from ESP fit*" $line]} {
	 incr offset;
      }
      
      if {$offset==2} {
	 variable espdipolemoment [lrange $line 3 5]
      }

      if {$offset>3} {
	 if {[string match "--------*" $line]} {
	    set haveesp 1
	    break
	 }
	 set index   [expr [lindex $line 0]-1]
	 set_atomprop ESP $index [lindex $line 2]
      }
   }

   if {!$haveesp} { 
      puts "ESP charges not found!" 
      seek $fid $filepos
   } 

   variable atomproptags
   lappend atomproptags ESP
   return 1
}




proc ::QMtool::compute_dipolemoment {} {
   variable molid
   set sel [atomselect $molid all]
   set dipole {0 0 0}
   foreach i [$sel get index] r [$sel get {x y z}] {
      set q [get_atomprop ESP $i]
      set dipole [vecadd $dipole [vecscale $q $r]]
   }
   $sel delete
   set debye [expr 1.0/0.20948957046]
   return [vecscale $dipole $debye]
}





