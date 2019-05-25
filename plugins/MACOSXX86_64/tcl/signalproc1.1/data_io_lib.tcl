# hello emacs this is -*- tcl -*-
#
# data i/o utilities package.
#
# support for writing reading different file formats into tcl (and VMD).
#
# (c) 2008-2009 by Axel Kohlmeyer <akohlmey@cmm.chem.upenn.edu>
########################################################################
#
# $Id: data_io_lib.tcl,v 1.3 2013/04/15 17:41:23 johns Exp $
#

package require fftpack 1.1
package provide data_io_lib 1.1

namespace eval ::DataIOLib {
    namespace import ::FFTPack::cmplx2*
    namespace export transp_list_of_lists gen_lin_list 
    namespace export read_list write_list write_2d_list
    namespace export write_3d_list_real write_3d_list_imag
}


# turn an m-element list of lists with n elements each
# into an n-element lists of m-elements
proc ::DataIOLib::transp_list_of_lists {list} {
    set n [llength [lindex $list 0]]

    for {set i 0} {$i < $n} {incr i} {
        set lol($i) {}
    }
    foreach l $list {
        for {set i 0} {$i < $n} {incr i} {
            lappend lol($i) [lindex $l $i]
        }
    }
    set res {}
    for {set i 0} {$i < $n} {incr i} {
        lappend res $lol($i)
    }
    return $res
}

# generate a linear sequence of numbers
proc ::DataIOLib::gen_lin_list {start delta num} {
    set res {}
    for {set i 0} {$i < $num} {incr i} {
        lappend res [expr {$start + $i*$delta}]
    }
    return $res
}

# gnuplot style 1d-output
proc ::DataIOLib::write_list {name list {title {data file}}} {
    set fp [open $name w]
    puts $fp "\# $title"
    foreach dat $list {
        puts $fp $dat
    }
    close $fp
}

# read one column from gnuplot style 1d date
proc ::DataIOLib::read_list {name {column 0}} {
    set lst {}
    set fp [open $name r]
    while {1} {
        set c [gets $fp line]
        # skip over comment only lines
        if {[regexp {^[:space:]*\#.*$} $line]} continue
        if {[eof $fp]} {
            close $fp
            break
        }
        # skip over empty lines.
        if {[regexp {^[:space:]*$} $line]} continue
        if {[string equal $column "all"]} {
            lappend lst $line
        } else {
            lappend lst [lindex $line $column]
        }
    }
    return $lst
}

# gnuplot style 2d-output
proc ::DataIOLib::write_2d_list {name list {title "2d-data set by tcl"}} {
    set fp [open $name w]
    set i 0
    puts $fp "\# $title"
    foreach l $list {
        set j 0
        foreach  dat $l {
            puts $fp "$i $j $dat"
            incr j
        }
        puts $fp ""
        incr i
    }
    close $fp
}

# IBM data explorer style 3d output.
# * object 1 class gridpositions counts xn yn zn
# * origin xorg yorg zorg
# * delta xdel 0 0
# * delta 0 ydel 0
# * delta 0 0 zdel
# * object 2 class gridconnections counts xn yn zn
# * object 3 class array type double rank 0 items { xn*yn*zn } [binary] data follows
# * f1 f2 f3
# * f4 f5 f6
# * .
#
proc write_3d_list_real {name list {title "by tcl"}} {
    set fp [open $name w]
    puts $fp "\# DX format output: $title"
    set nx [llength $list] 
    set ny [llength [lindex $list 0]] 
    set nz [llength [lindex $list 0 0]]
    puts $fp "object 1 class gridpositions counts $nx $ny $nz"
    puts $fp "origin 0.0 0.0 0.0"
    puts $fp "delta  1 0 0"
    puts $fp "delta  0 1 0"
    puts $fp "delta  0 0 1"
    puts $fp "object 2 class gridconnections counts $nx $ny $nz"
    puts $fp "object 3 class array type double rank 0 items [expr $nx*$ny*$nz] data follows"
    foreach x $list {
        foreach y $x {
            foreach z [cmplx2real_1d $y] {
                puts $fp [format %12.8f $z]
            }
        }
    }
    puts $fp "attribute \"dep\" string \"positions\""
    puts $fp "\nobject \"3d-data\" class field"
    puts $fp "component \"positions\" value 1"
    puts $fp "component \"connections\" value 2"
    puts $fp "component \"data\" value 3"
    close $fp
}

proc write_3d_list_imag {name list} {
    set fp [open $name w]
    puts $fp "\# DX format output"
    set nx [llength $list] 
    set ny [llength [lindex $list 0]] 
    set nz [llength [lindex $list 0 0]]
    puts $fp "object 1 class gridpositions counts $nx $ny $nz"
    puts $fp "origin 0.0 0.0 0.0"
    puts $fp "delta  1 0 0"
    puts $fp "delta  0 1 0"
    puts $fp "delta  0 0 1"
    puts $fp "object 2 class gridconnections counts $nx $ny $nz"
    puts $fp "object 3 class array type double rank 0 items [expr $nx*$ny*$nz] data follows"
    foreach x $list {
        foreach y $x {
            foreach z [cmplx2imag_1d $y] {
                puts $fp [format %12.8f $z]
            }
        }
    }
    puts $fp "attribute \"dep\" string \"positions\""
    puts $fp "\nobject \"3d-data\" class field"
    puts $fp "component \"positions\" value 1"
    puts $fp "component \"connections\" value 2"
    puts $fp "component \"data\" value 3"
    close $fp
}
    
