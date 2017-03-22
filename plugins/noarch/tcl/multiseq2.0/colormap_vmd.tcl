############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide multiseq 2.0

# Declare global variables for this package.
namespace eval ::MultiSeq::ColorMap::VMD {

    # Export the package namespace.
    namespace export getColorMap

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc getColor {value} {
        
        # Figure out the index to use.
        set index [expr int($value*([colorinfo max]-[colorinfo num]-1))+[colorinfo num]]
        
        # Get the color from the VMD palette.
        set components [colorinfo rgb $index]
    
        # Get the color components
        set r [expr int(double(0xFF)*[lindex $components 0])]
        set g [expr int(double(0xFF)*[lindex $components 1])]
        set b [expr int(double(0xFF)*[lindex $components 2])]
        
        set color "#[format %02X $r][format %02X $g][format %02X $b]"
        return $color
    }
}    
