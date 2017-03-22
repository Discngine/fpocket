# bignum library in pure Tcl [VERSION 7Sep2004]
# Copyright (C) 2004 Salvatore Sanfilippo <antirez at invece dot org>
# Copyright (C) 2004 Arjen Markus <arjen dot markus at wldelft dot nl>
#
# LICENSE
#
# This software is:
# Copyright (C) 2004 Salvatore Sanfilippo <antirez at invece dot org>
# Copyright (C) 2004 Arjen Markus <arjen dot markus at wldelft dot nl>
# The following terms apply to all files associated with the software
# unless explicitly disclaimed in individual files.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
# 
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# 
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
# 
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal 
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license. 

# TODO
# - pow and powm should check if the exponent is zero in order to return one

package provide bignum 1.0

namespace eval bignum {}

#################################### Misc ######################################

# Don't change atombits define if you don't know what you are doing.
# Note that it must be a power of two, and that 16 is too big
# because expr may overflow in the product of two 16 bit numbers.
set ::bignum::atombits 16
set ::bignum::atombase [expr {1 << $::bignum::atombits}]
set ::bignum::atommask [expr {$::bignum::atombase-1}]

# Note: to change 'atombits' is all you need to change the
# library internal representation base.

# Return the max between a and b (not bignums)
proc bignum::max {a b} {
    expr {($a > $b) ? $a : $b}
}

# Return the min between a and b (not bignums)
proc bignum::min {a b} {
    expr {($a < $b) ? $a : $b}
}

############################ Basic bignum operations ###########################

# Returns a new bignum initialized to the value of 0.
#
# The big numbers are represented as a Tcl lists
# The all-is-a-string representation does not pay here
# bignums in Tcl are already slow, we can't slow-down it more.
#
# The bignum representation is [list bignum <sign> <atom0> ... <atomN>]
# Where the atom0 is the least significant. Atoms are the digits
# of a number in base 2^$::bignum::atombits
#
# The sign is 0 if the number is positive, 1 for negative numbers.

# Note that the function accepts an argument used in order to
# create a bignum of <atoms> atoms. For default zero is
# represented as a single zero atom.
#
# The function is designed so that "set b [zero [atoms $a]]" will
# produce 'b' with the same number of atoms as 'a'.
proc bignum::zero {{value 0}} {
    set v [list bignum 0 0]
    while { $value > 1 } {
       lappend v 0
       incr value -1
    }
    return $v
}

# Get the bignum sign
proc bignum::sign bignum {
    lindex $bignum 1
}

# Get the number of atoms in the bignum
proc bignum::atoms bignum {
    expr {[llength $bignum]-2}
}

# Get the i-th atom out of a bignum.
# If the bignum is shorter than i atoms, the function
# returns 0.
proc bignum::atom {bignum i} {
    if {[::bignum::atoms $bignum] < [expr {$i+1}]} {
	return 0
    } else {
	lindex $bignum [expr {$i+2}]
    }
}

# Set the i-th atom out of a bignum. If the bignum
# has less than 'i+1' atoms, add zero atoms to reach i.
proc bignum::setatom {bignumvar i atomval} {
    upvar 1 $bignumvar bignum
    while {[::bignum::atoms $bignum] < [expr {$i+1}]} {
	lappend bignum 0
    }
    lset bignum [expr {$i+2}] $atomval
}

# Set the bignum sign
proc bignum::setsign {bignumvar sign} {
    upvar 1 $bignumvar bignum
    lset bignum 1 $sign
}

# Remove trailing atoms with a value of zero
# The normalized bignum is returned
proc bignum::normalize bignumvar {
    upvar 1 $bignumvar bignum
    set atoms [expr {[llength $bignum]-2}]
    set i [expr {$atoms+1}]
    while {$atoms && [lindex $bignum $i] == 0} {
	set bignum [lrange $bignum 0 end-1]
	incr atoms -1
	incr i -1
    }
    if {!$atoms} {
	set bignum [list bignum 0 0]
    }
    return $bignum
}

# Return the absolute value of N
proc bignum::abs n {
    ::bignum::setsign n 0
    return $n
}

################################# Comparison ###################################

# Compare by absolute value. Called by bignum::cmp after the sign check.
#
# Returns 1 if |a| > |b|
#         0 if a == b
#        -1 if |a| < |b|
#
proc bignum::abscmp {a b} {
    if {[llength $a] > [llength $b]} {
	return 1
    } elseif {[llength $a] < [llength $b]} {
	return -1
    }
    set j [expr {[llength $a]-1}]
    while {$j >= 2} {
	if {[lindex $a $j] > [lindex $b $j]} {
	    return 1
	} elseif {[lindex $a $j] < [lindex $b $j]} {
	    return -1
	}
	incr j -1
    }
    return 0
}

# High level comparison. Return values:
#
#  1 if a > b
# -1 if a < b
#  0 if a == b
#
proc bignum::cmp {a b} { ; # same sign case
    if {[::bignum::sign $a] == [::bignum::sign $b]} {
	if {[::bignum::sign $a] == 0} {
	    ::bignum::abscmp $a $b
	} else {
	    expr {-([::bignum::abscmp $a $b])}
	}
    } else { ; # different sign case
	if {[::bignum::sign $a]} {return -1}
	return 1
    }
}

# Return true if 'z' is zero.
proc bignum::iszero z {
    expr {[llength $z] == 3 && [lindex $z 2] == 0}
}

# Comparison facilities
proc bignum::lt {a b} {expr {[::bignum::cmp $a $b] < 0}}
proc bignum::le {a b} {expr {[::bignum::cmp $a $b] <= 0}}
proc bignum::gt {a b} {expr {[::bignum::cmp $a $b] > 0}}
proc bignum::ge {a b} {expr {[::bignum::cmp $a $b] >= 0}}
proc bignum::eq {a b} {expr {[::bignum::cmp $a $b] == 0}}
proc bignum::ne {a b} {expr {[::bignum::cmp $a $b] != 0}}

########################### Addition / Subtraction #############################

# Add two bignums, don't care about the sign.
proc bignum::rawAdd {a b} {
    while {[llength $a] < [llength $b]} {lappend a 0}
    while {[llength $b] < [llength $a]} {lappend b 0}
    set r [::bignum::zero [expr {[llength $a]-1}]]
    set car 0
    for {set i 2} {$i < [llength $a]} {incr i} {
	set sum [expr {[lindex $a $i]+[lindex $b $i]+$car}]
	set car [expr {$sum >> $::bignum::atombits}]
	set sum [expr {$sum & $::bignum::atommask}]
	lset r $i $sum
    }
    if {$car} {
	lset r $i $car
    }
    ::bignum::normalize r
}

# Subtract two bignums, don't care about the sign. a > b condition needed.
proc bignum::rawSub {a b} {
    set atoms [::bignum::atoms $a]
    set r [::bignum::zero $atoms]
    while {[llength $b] < [llength $a]} {lappend b 0} ; # b padding
    set car 0
    incr atoms 2
    for {set i 2} {$i < $atoms} {incr i} {
	set sub [expr {[lindex $a $i]-[lindex $b $i]-$car}]
	set car 0
	if {$sub < 0} {
	    incr sub $::bignum::atombase
	    set car 1
	}
	lset r $i $sub
    }
    # Note that if a > b there is no car in the last for iteration
    ::bignum::normalize r
}

# Higher level addition, care about sign and call rawAdd or rawSub
# as needed.
proc bignum::add {a b} {
    # Same sign case
    if {[::bignum::sign $a] == [::bignum::sign $b]} {
	set r [::bignum::rawAdd $a $b]
	::bignum::setsign r [::bignum::sign $a]
    } else {
	# Different sign case
	set cmp [::bignum::abscmp $a $b]
	# 's' is the sign, set accordingly to A or B negative
	set s [expr {[::bignum::sign $a] == 1}]
	switch -- $cmp {
	    0 {return [::bignum::zero]}
	    1 {
		set r [::bignum::rawSub $a $b]
		::bignum::setsign r $s
		return $r
	    }
	    -1 {
		set r [::bignum::rawSub $b $a]
		::bignum::setsign r [expr {!$s}]
		return $r
	    }
	}
    }
    return $r
}

# Higher level subtraction, care about sign and call rawAdd or rawSub
# as needed.
proc bignum::sub {a b} {
    # Different sign case
    if {[::bignum::sign $a] != [::bignum::sign $b]} {
	set r [::bignum::rawAdd $a $b]
	::bignum::setsign r [::bignum::sign $a]
    } else {
	# Same sign case
	set cmp [::bignum::abscmp $a $b]
	# 's' is the sign, set accordingly to A and B both negative or positive
	set s [expr {[::bignum::sign $a] == 1}]
	switch -- $cmp {
	    0 {return [::bignum::zero]}
	    1 {
		set r [::bignum::rawSub $a $b]
		::bignum::setsign r $s
		return $r
	    }
	    -1 {
		set r [::bignum::rawSub $b $a]
		::bignum::setsign r [expr {!$s}]
		return $r
	    }
	}
    }
    return $r
}

############################### Multiplication #################################

set ::bignum::karatsubaThreshold 32

# Multiplication. Calls Karatsuba that calls Base multiplication under
# a given threshold.
proc bignum::mul {a b} {
    set r [::bignum::kmul $a $b]
    # The sign is the xor between the two signs
    ::bignum::setsign r [expr {[::bignum::sign $a]^[::bignum::sign $b]}]
}

# Karatsuba Multiplication
proc bignum::kmul {a b} {
    set n [expr {[::bignum::max [llength $a] [llength $b]]-2}]
    set nmin [expr {[::bignum::min [llength $a] [llength $b]]-2}]
    if {$nmin < $::bignum::karatsubaThreshold} {return [::bignum::bmul $a $b]}
    set m [expr {($n+($n&1))/2}]

    set x0 [concat [list bignum 0] [lrange $a 2 [expr {$m+1}]]]
    set y0 [concat [list bignum 0] [lrange $b 2 [expr {$m+1}]]]
    set x1 [concat [list bignum 0] [lrange $a [expr {$m+2}] end]]
    set y1 [concat [list bignum 0] [lrange $b [expr {$m+2}] end]]

    if {0} {
    puts "m: $m"
    puts "x0: $x0"
    puts "x1: $x1"
    puts "y0: $y0"
    puts "y1: $y1"
    }

    set p1 [::bignum::kmul $x1 $y1]
    set p2 [::bignum::kmul $x0 $y0]
    set p3 [::bignum::kmul [::bignum::add $x1 $x0] [::bignum::add $y1 $y0]]

    set p3 [::bignum::sub $p3 $p1]
    set p3 [::bignum::sub $p3 $p2]
    set p1 [::bignum::lshiftAtoms $p1 [expr {$m*2}]]
    set p3 [::bignum::lshiftAtoms $p3 $m]
    set p3 [::bignum::add $p3 $p1]
    set p3 [::bignum::add $p3 $p2]
    return $p3
}

# Base Multiplication.
proc bignum::bmul {a b} {
    set r [::bignum::zero [expr {[llength $a]+[llength $b]-3}]]
    for {set j 2} {$j < [llength $b]} {incr j} {
	set car 0
	set t [list bignum 0 0]
	for {set i 2} {$i < [llength $a]} {incr i} {
	    # note that A = B * C + D + E
	    # with A of N*2 bits and C,D,E of N bits
	    # can't overflow since:
	    # (2^N-1)*(2^N-1)+(2^N-1)+(2^N-1) == 2^(2*N)-1
	    set t0 [lindex $a $i]
	    set t1 [lindex $b $j]
	    set t2 [lindex $r [expr {$i+$j-2}]]
	    set mul [expr {wide($t0)*$t1+$t2+$car}]
	    set car [expr {$mul >> $::bignum::atombits}]
	    set mul [expr {$mul & $::bignum::atommask}]
	    lset r [expr {$i+$j-2}] $mul
	}
	if {$car} {
	    lset r [expr {$i+$j-2}] $car
	}
    }
    ::bignum::normalize r
}

################################## Shifting ####################################

# Left shift 'z' of 'n' atoms. Low-level function used by bignum::lshift
# Exploit the internal representation to go faster.
proc bignum::lshiftAtoms {z n} {
    while {$n} {
	set z [linsert $z 2 0]
	incr n -1
    }
    return $z
}

# Right shift 'z' of 'n' atoms. Low-level function used by bignum::lshift
# Exploit the internal representation to go faster.
proc bignum::rshiftAtoms {z n} {
    set z [lreplace $z 2 [expr {$n+1}]]
}

# Left shift 'z' of 'n' bits. Low-level function used by bignum::lshift.
# 'n' must be <= $::bignum::atombits
proc bignum::lshiftBits {z n} {
    set atoms [llength $z]
    set car 0
    for {set j 2} {$j < $atoms} {incr j} {
	set t [lindex $z $j]
	lset z $j \
	    [expr {wide($car)|((wide($t)<<$n)&$::bignum::atommask)}]
	set car [expr {wide($t)>>($::bignum::atombits-$n)}]
    }
    if {$car} {
	lappend z 0
	lset z $j $car
    }
    return $z ; # No normalization needed
}

# Right shift 'z' of 'n' bits. Low-level function used by bignum::rshift.
# 'n' must be <= $::bignum::atombits
proc bignum::rshiftBits {z n} {
    set atoms [llength $z]
    set car 0
    for {set j [expr {$atoms-1}]} {$j >= 2} {incr j -1} {
	set t [lindex $z $j]
	lset z $j [expr {wide($car)|(wide($t)>>$n)}]
	set car \
	    [expr {(wide($t)<<($::bignum::atombits-$n))&$::bignum::atommask}]
    }
    ::bignum::normalize z
}

# Left shift 'z' of 'n' bits.
proc bignum::lshift {z n} {
    set atoms [expr {$n / $::bignum::atombits}]
    set bits [expr {$n & ($::bignum::atombits-1)}]
    bignum::lshiftBits [bignum::lshiftAtoms $z $atoms] $bits
}

# Right shift 'z' of 'n' bits.
proc bignum::rshift {z n} {
    set atoms [expr {$n / $::bignum::atombits}]
    set bits [expr {$n & ($::bignum::atombits-1)}]
    bignum::rshiftBits [bignum::rshiftAtoms $z $atoms] $bits
}

############################## Bit oriented ops ################################

# Set the bit 'n' of 'bignumvar'
proc bignum::setbit {bignumvar n} {
    upvar 1 $bignumvar z
    set atom [expr {$n / $::bignum::atombits}]
    set bit [expr {1 << ($n & ($::bignum::atombits-1))}]
    incr atom 2
    while {$atom >= [llength $z]} {lappend z 0}
    lset z $atom [expr {[lindex $z $atom]|$bit}]
}

# Clear the bit 'n' of 'bignumvar'
proc bignum::clearbit {bignumvar n} {
    upvar 1 $bignumvar z
    set atom [expr {$n / $::bignum::atombits}]
    incr atom 2
    if {$atom >= [llength $z]} {return $z}
    set mask [expr {$::bignum::atommask^(1 << ($n & ($::bignum::atombits-1)))}]
    lset z $atom [expr {[lindex $z $atom]&$mask}]
    ::bignum::normalize z
}

# Test the bit 'n' of 'z'. Returns true if the bit is set.
proc bignum::testbit {z n} {
    set atom [expr {$n / $::bignum::atombits}]
    if {$atom >= [llength $z]} {return 0}
    incr atom 2
    set mask [expr {1 << ($n & ($::bignum::atombits-1))}]
    expr {([lindex $z $atom] & $mask) != 0}
}

# Return the number of bits needed to represent 'z'.
proc bignum::bits z {
    set atoms [::bignum::atoms $z]
    set bits [expr {($atoms-1)*$::bignum::atombits}]
    set atom [lindex $z [expr {$atoms+1}]]
    while {$atom} {
	incr bits
	set atom [expr {$atom >> 1}]
    }
    return $bits
}

################################## Division ####################################

# Division. Returns [list n/d n%d]
#
# I got this algorithm from PGP 2.6.3i (see the mp_udiv function).
# Here is how it works:
#
# Input:  N=(Nn,...,N2,N1,N0)radix2
#         D=(Dn,...,D2,D1,D0)radix2
# Output: Q=(Qn,...,Q2,Q1,Q0)radix2 = N/D
#         R=(Rn,...,R2,R1,R0)radix2 = N%D
#
# Assume: N >= 0, D > 0
#
# For j from 0 to n
#      Qj <- 0
#      Rj <- 0
# For j from n down to 0
#      R <- R*2
#      if Nj = 1 then R0 <- 1
#      if R => D then R <- (R - D), Qn <- 1
#
# Note that the doubling of R is usually done leftshifting one position.
# The only operations needed are bit testing, bit setting and subtraction.
#
# This is the "raw" version, don't care about the sign, returns both
# quotient and rest as a two element list.
# This procedure is used by divqr, div, mod, rem.
proc bignum::rawDiv {n d} {
    set bit [expr {[::bignum::bits $n]-1}]
    set r [list bignum 0 0]
    set q [::bignum::zero [expr {[llength $n]-2}]]
    while {$bit >= 0} {
	set b_atom [expr {($bit / $::bignum::atombits) + 2}]
	set b_bit [expr {1 << ($bit & ($::bignum::atombits-1))}]
	set r [::bignum::lshiftBits $r 1]
	if {[lindex $n $b_atom]&$b_bit} {
	    lset r 2 [expr {[lindex $r 2] | 1}]
	}
	if {[::bignum::abscmp $r $d] >= 0} {
	    set r [::bignum::rawSub $r $d]
	    lset q $b_atom [expr {[lindex $q $b_atom]|$b_bit}]
	}
	incr bit -1
    }
    ::bignum::normalize q
    list $q $r
}

# Divide by single-atom immediate. Used to speedup bignum -> string conversion.
# The procedure returns a two-elements list with the bignum quotient and
# the remainder (that's just a number being <= of the max atom value).
proc bignum::rawDivByAtom {n d} {
    set atoms [::bignum::atoms $n]
    set t 0
    set j $atoms
    incr j -1
    for {} {$j >= 0} {incr j -1} {
	set t [expr {($t << $::bignum::atombits)+[lindex $n [expr {$j+2}]]}]
	lset n [expr {$j+2}] [expr {$t/$d}]
	set t [expr {$t % $d}]
    }
    ::bignum::normalize n
    list $n $t
}

# Higher level division. Returns a list with two bignums, the first
# is the quotient of n/d, the second the remainder n%d.
# Note that if you want the *modulo* operator you should use bignum::mod
#
# The remainder sign is always the same as the divident.
proc bignum::divqr {n d} {
    if {[::bignum::iszero $d]} {
	error "Division by zero"
    }
    foreach {q r} [::bignum::rawDiv $n $d] break
    ::bignum::setsign q [expr {[::bignum::sign $n]^[::bignum::sign $d]}]
    ::bignum::setsign r [::bignum::sign $n]
    list $q $r
}

# Like divqr, but only the quotient is returned.
proc bignum::div {n d} {
    lindex [::bignum::divqr $n $d] 0
}

# Like divqr, but only the remainder is returned.
proc bignum::rem {n d} {
    lindex [::bignum::divqr $n $d] 1
}

# Modular reduction. Returns N modulo M
proc bignum::mod {n m} {
    set r [lindex [::bignum::divqr $n $m] 1]
    if {[::bignum::sign $m] != [::bignum::sign $r]} {
	set r [::bignum::add $r $m]
    }
    return $r
}

# Returns true if n is odd
proc bignum::isodd n {
    expr {[lindex $n 2]&1}
}

# Returns true if n is even
proc bignum::iseven n {
    expr {!([lindex $n 2]&1)}
}

############################# Power and Power mod N ############################

# Returns b^e
proc bignum::pow {b e} {
    if {[::bignum::iszero $e]} {return [list bignum 0 1]}
    # The power is negative is the base is negative and the exponent is odd
    set sign [expr {[::bignum::sign $b] && [::bignum::isodd $e]}]
    # Set the base to it's abs value, i.e. make it positive
    ::bignum::setsign b 0
    # Main loop
    set r [list bignum 0 1]; # Start with result = 1
    while {[::bignum::abscmp $e [list bignum 0 1]] > 0} { ;# While the exp > 1
	if {[::bignum::isodd $e]} {
	    set r [::bignum::mul $r $b]
	}
	set e [::bignum::rshiftBits $e 1] ;# exp = exp / 2
	set b [::bignum::mul $b $b]
    }
    set r [::bignum::mul $r $b]
    ::bignum::setsign r $sign
    return $r
}

# Returns b^e mod m
proc bignum::powm {b e m} {
    if {[::bignum::iszero $e]} {return [list bignum 0 1]}
    # The power is negative is the base is negative and the exponent is odd
    set sign [expr {[::bignum::sign $b] && [::bignum::isodd $e]}]
    # Set the base to it's abs value, i.e. make it positive
    ::bignum::setsign b 0
    # Main loop
    set r [list bignum 0 1]; # Start with result = 1
    while {[::bignum::abscmp $e [list bignum 0 1]] > 0} { ;# While the exp > 1
	if {[::bignum::isodd $e]} {
	    set r [::bignum::mod [::bignum::mul $r $b] $m]
	}
	set e [::bignum::rshiftBits $e 1] ;# exp = exp / 2
	set b [::bignum::mod [::bignum::mul $b $b] $m]
    }
    set r [::bignum::mul $r $b]
    ::bignum::setsign r $sign
    set r [::bignum::mod $r $m]
    return $r
}

################################## Square Root #################################

# SQRT using the 'binary sqrt algorithm'.
#
# The basic algoritm consists in starting from the higer-bit
# the real square root may have set, down to the bit zero,
# trying to set every bit and checking if guess*guess is not
# greater than 'n'. If it is greater we don't set the bit, otherwise
# we set it. In order to avoid to compute guess*guess a trick
# is used, so only addition and shifting are really required.
proc bignum::sqrt n {
    if {[lindex $n 1]} {
	error "Square root of a negative number"
    }
    set i [expr {(([::bignum::bits $n]-1)/2)+1}]
    set b [expr {$i*2}] ; # Bit to set to get 2^i*2^i

    set r [::bignum::zero] ; # guess
    set x [::bignum::zero] ; # guess^2
    set s [::bignum::zero] ; # guess^2 backup
    set t [::bignum::zero] ; # intermediate result
    for {} {$i >= 0} {incr i -1; incr b -2} {
	::bignum::setbit t $b
	set x [::bignum::rawAdd $s $t]
	::bignum::clearbit t $b
	if {[::bignum::abscmp $x $n] <= 0} {
	    set s $x
	    ::bignum::setbit r $i
	    ::bignum::setbit t [expr {$b+1}]
	}
	set t [::bignum::rshiftBits $t 1]
    }
    return $r
}

################################## Random Number ###############################

# Returns a random number in the range [0,2^n-1]
proc bignum::rand bits {
    set atoms [expr {($bits+$::bignum::atombits-1)/$::bignum::atombits}]
    set shift [expr {($atoms*$::bignum::atombits)-$bits}]
    set r [list bignum 0]
    while {$atoms} {
	lappend r [expr {int(rand()*(1<<$::bignum::atombits))}]
	incr atoms -1
    }
    set r [::bignum::rshiftBits $r $shift]
    return $r
}

############################ Convertion to/from string #########################

# The string representation charset. Max base is 36
set bignum::cset "0123456789abcdefghijklmnopqrstuvwxyz"

# Convert 'z' to a string representation in base 'base'.
# Note that this is missing a simple but very effective optimization
# that's to divide by the biggest power of the base that fits
# in a Tcl plain integer, and then to perform divisions with [expr].
proc bignum::tostr {z {base 10}} {
    if {[string length $::bignum::cset] < $base} {
	error "base too big for string convertion"
    }
    if {[::bignum::iszero $z]} {return 0}
    set sign [::bignum::sign $z]
    set str {}
    while {![::bignum::iszero $z]} {
	foreach {q r} [::bignum::rawDivByAtom $z $base] break
	append str [string index $::bignum::cset $r]
	set z $q
    }
    if {$sign} {append str -}
    # flip the resulting string
    set flipstr {}
    set i [string length $str]
    incr i -1
    while {$i >= 0} {
	append flipstr [string index $str $i]
	incr i -1
    }
    return $flipstr
}

# Create a bignum from a string representation in base 'base'.
proc bignum::fromstr {str {base 0}} {
    set z [::bignum::zero]
    set str [string trim $str]
    set sign 0
    if {[string index $str 0] eq {-}} {
	set str [string range $str 1 end]
	set sign 1
    }
    if {$base == 0} {
	switch -- [string tolower [string range $str 0 1]] {
	    0x {set base 16; set str [string range $str 2 end]}
	    ox {set base 8 ; set str [string range $str 2 end]}
	    bx {set base 2 ; set str [string range $str 2 end]}
	    default {set base 10}
	}
    }
    if {[string length $::bignum::cset] < $base} {
	error "base too big for string convertion"
    }
    set bigbase [list bignum 0 $base] ; # Build a bignum with the base value
    set basepow [list bignum 0 1] ; # multiply every digit for a succ. power
    set i [string length $str]
    incr i -1
    while {$i >= 0} {
	set digitval [string first [string index $str $i] $::bignum::cset]
	if {$digitval == -1} {
	    error "Illegal char '[string index $str $i]' for base $base"
	}
	set bigdigitval [list bignum 0 $digitval]
	set z [::bignum::rawAdd $z [::bignum::mul $basepow $bigdigitval]]
	set basepow [::bignum::mul $basepow $bigbase]
	incr i -1
    }
    if {![::bignum::iszero $z]} {
	::bignum::setsign z $sign
    }
    return $z
}

#namespace eval bignum {
#    namespace export *
#}
################################################################################

#namespace import ::bignum::*


#set a [rand 10000]
#set b [rand 10000]
#puts [time {set c1 [bmul $a $b]}]
#puts [time {set c2 [kmul $a $b]}]
#puts [string match [tostr $c1] [tostr $c2]]
