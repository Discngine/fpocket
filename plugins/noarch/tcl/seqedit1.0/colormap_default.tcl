############################################################################
#cr
#cr            (C) Copyright 1995-2004 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

############################################################################
# RCS INFORMATION:
#
#       $RCSfile: colormap_default.tcl,v $
#       $Author: erobert3 $        $Locker:  $             $State: Exp $
#       $Revision: 1.1.2.1 $       $Date: 2005/07/01 15:03:17 $
#
############################################################################

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the conservation of the element.

package provide seqedit 1.0

# Declare global variables for this package.
namespace eval ::SeqEdit::ColorMap::Default {

    # Export the package namespace.
    namespace export getColorMap

    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc getColor {value} {
        
        # Calculate the percentages.
        if {$value == 0.0} {
            
            # White.
            set gPercentage 1.0
            set rPercentage 1.0
            set bPercentage 1.0
            
        } elseif {$value >= 0.0 && $value <= 0.5} {
            
            # From R to G.
            set gPercentage [expr ($value)/0.5]
            set rPercentage [expr 1.0-$gPercentage]
            set bPercentage 0.0
            
        } elseif {$value > 0.5 && $value <= 1.0} {
            
            # From G to B.
            set bPercentage [expr ($value-0.5)/0.5]
            set gPercentage [expr 1.0-$bPercentage]
            set rPercentage 0.0
        }
    
        # Get the color components
        set r "0xFF"
        set g "0xFF"
        set b "0xFF"
        
        # Adjust the color components.
        set r [expr int(double($r)*$rPercentage)]
        set g [expr int(double($g)*$gPercentage)]
        set b [expr int(double($b)*$bPercentage)]
        
        set color "#[format %02X $r][format %02X $g][format %02X $b]"
        return $color
    }
}    
