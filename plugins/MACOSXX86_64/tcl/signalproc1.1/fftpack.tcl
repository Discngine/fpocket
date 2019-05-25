# hello emacs this is -*- tcl -*-
#
# FFT utilities package.
#
# (c) 2008-2009 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
########################################################################
#
# $Id: fftpack.tcl,v 1.2 2013/04/15 17:41:23 johns Exp $
#
# create package and namespace and default all namespace global variables.
package require fftcmds 1.1
package provide fftpack 1.1

namespace eval ::FFTPack:: {
    namespace export cmplx2real_1d cmplx2imag_1d cmplx2conj_1d cmplx2ampl_1d 
    namespace export cmplxscale_1d 
}

#####################
# generate list of real from complex
proc ::FFTPack::cmplx2real_1d {list} {
    set res {}
    foreach cmplx $list {
        lappend res [lindex $cmplx 0]
    }
    return $res
}

#####################
# generate list of imag from complex
proc ::FFTPack::cmplx2imag_1d {list} {
    set res {}
    foreach cmplx $list {
        lappend res [lindex $cmplx 1]
    }
    return $res
}

#####################
# generate list of conjugate from complex
proc ::FFTPack::cmplx2conj_1d {list} {
    set res {}
    foreach cmplx $list {
        lappend res [list [lindex $cmplx 0] [expr -1.0*[lindex $cmplx 1]]]
    }
    return $res
}

#####################
# generate scaled list of complex
proc ::FFTPack::cmplxscale_1d {scalef list} {
    set res {}
    foreach cmplx $list {
        lappend res [vecscale $scalef $cmplx]
    }
    return $res
}

#####################
# generate list of amplitude
proc ::FFTPack::cmplx2ampl_1d {list} {
    set res {}
    foreach cmplx $list {
        set c  [lindex $cmplx 0]
        set s  [lindex $cmplx 1]
        lappend res [expr {sqrt($c*$c+$s*$s)}]
    }
    return $res
}

############################################################
# Local Variables:
# mode: tcl
# time-stamp-format: "%u %02d.%02m.%y %02H:%02M:%02S %s"
# End:
############################################################

