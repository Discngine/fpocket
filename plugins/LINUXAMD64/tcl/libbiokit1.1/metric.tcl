# University of Illinois Open Source License
# Copyright 2004-2007 Luthey-Schulten Group, 
# All rights reserved.
#
# $Id: metric.tcl,v 1.4 2013/04/15 16:29:19 johns Exp $
# 
# Developed by: Luthey-Schulten Group
# 			     University of Illinois at Urbana-Champaign
# 			     http://www.scs.illinois.edu/~schulten
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the Software), to deal with 
# the Software without restriction, including without limitation the rights to 
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
# of the Software, and to permit persons to whom the Software is furnished to 
# do so, subject to the following conditions:
# 
# - Redistributions of source code must retain the above copyright notice, 
# this list of conditions and the following disclaimers.
# 
# - Redistributions in binary form must reproduce the above copyright notice, 
# this list of conditions and the following disclaimers in the documentation 
# and/or other materials provided with the distribution.
# 
# - Neither the names of the Luthey-Schulten Group, University of Illinois at
# Urbana-Champaign, nor the names of its contributors may be used to endorse or
# promote products derived from this Software without specific prior written
# permission.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL 
# THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS WITH THE SOFTWARE.
#
# Author(s): Elijah Roberts

# This package implements a color map for the sequence editor that colors
# sequence elements based upon the q value of the element.

package provide libbiokit 1.1
package require seqdata 1.1

# Declare global variables for this package.
namespace eval ::Libbiokit::Metric {

    # Export the package namespace.
    namespace export calculateRMSD

# ------------------------------------------------------------------------
    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculateRMSD {sequenceIDs} {
        
        # Initialize the color map.
        array unset metricMap 
        
        # Get the RMSD scores.
        set scores [::Libbiokit::getRMSDPerResidue $sequenceIDs]
                
        # Go through each sequence in the list.
        for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
            # Get the sequence id.
            set sequenceID [lindex $sequenceIDs $i]
            
            # Go through each element in the sequence.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            
                # Set the score.
                set score [lindex [lindex $scores $i] $element]
                set metricMap($sequenceID,$element) $score
            }
        }
        
        # Return the color map.
        return [array get metricMap]
    }

# ------------------------------------------------------------------------
   # Gets the color that corresponds to the specified value.
   # args: value - value of which to retrieve the color, 0.0-1.0
   # return: hex string representing color associated with passed in value.
   proc calculateRMSDNormalized {sequenceIDs} {
        
#      # Initialize the color map.
#      array unset metricMap 
        
      # Get the RMSD scores.
      set scores [::Libbiokit::getRMSDPerResidue $sequenceIDs]
        
      # Figure out the maximum RMSD.
      set maxRMSD 0.0
      foreach scoreList $scores {
         foreach score $scoreList {
            if {$score > $maxRMSD} {
               set maxRMSD $score
            }
         }
      }
                
      set colorValueMap "[::SeqEditWidget::getColorMap]\::getColorIndexForValue"

      # Go through each sequence in the list.
      for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
         # Get the sequence id.
         set sequenceID [lindex $sequenceIDs $i]

         # Go through each element in the sequence.
         for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
            
            # Set the score.
            set score [lindex [lindex $scores $i] $element]
            if {$score >= 0.0} {
               seq set color $sequenceID $element [$colorValueMap \
                                               [expr 1.0-($score/$maxRMSD)]]
#               set metricMap($sequenceID,$element) [expr 1.0-($score/$maxRMSD)]
            } else {
               seq set color $sequenceID $element [$colorValueMap 0.0]
            }
         }
      }
        
#      # Return the color map.
#      return [array get metricMap]
   } ; # end of calculateRMSDNormalized

# ------------------------------------------------------------------------
   # Gets the color that corresponds to the specified value.
   # args: value - The value of which to retrieve the color, 0.0 - 1.0
   # return: hex string representing color associated with the passed in value.
   proc colorQres {sequenceIDs} {
        
      # Get the q scores.
      set scores [::Libbiokit::getQPerResidue $sequenceIDs]

      set colorValueMap "[::SeqEditWidget::getColorMap]\::getColorIndexForValue"

      # Go through each sequence in the list.
      for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
         # Get the sequence id.
         set sequenceID [lindex $sequenceIDs $i]
            
         # Go through each element in the sequence.
         for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} \
                                                             {incr element} {
            set score [lindex [lindex $scores $i] $element]
#            if { $sequenceID == 2 } { puts "metric.tcl.calculateQres:elem: $element, score: $score, colorval:  [$colorValueMap $score]" }
            seq set color $sequenceID $element [$colorValueMap $score]

         }
      }
   }

# ------------------------------------------------------------------------
   # calculate a qRes array
   # args: sequenceIDs list of IDs we are calculating for
   # return: array of qRes values. 1st dim: sequence, 2nd dim: element in
   # sequece.  array value: qRes value at that point
   proc calculateQres {sequenceIDs} {
#      puts "metric.tcl.calculateQres.start. seqIDs:$sequenceIDs"
      array unset metricMap 
        
      # Get the q scores.
      set scores [::Libbiokit::getQPerResidue $sequenceIDs]

      # Go through each sequence in the list.
      for {set i 0} {$i < [llength $sequenceIDs]} {incr i} {
        
         # Get the sequence id.
         set sequenceID [lindex $sequenceIDs $i]
         
         set seqLength [SeqData::getSeqLength $sequenceID]

         # Go through each element in the sequence.
         for {set element 0} {$element < $seqLength} {incr element} {
            set metricMap($sequenceID,$element) [lindex \
                                                 [lindex $scores $i] $element]
         }
      }

      # Return the color map.
      return [array get metricMap]
   }

# --------------------------------------------------------------------------
    # Gets the color that corresponds to the specified value.
    # args:     value - The value of which to retrieve the color, this should be between 0.0 and 1.0.
    # return:   A hex string representing the color associated with the passed in value.
    proc calculateContactsPerResidue {sequenceIDs} {
        
        # Initialize the color map.
        array unset contactsMap 
        
        # Go through each sequence in the list.
        set maxCount 0
        foreach sequenceID $sequenceIDs {
            
            # Get the contacts per residue.
            set contactsPerResidue [::Libbiokit::getContactsPerResidue $sequenceID]            
            
            # Get the max count.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
                set contactsMap($sequenceID,$element) [lindex $contactsPerResidue $element]
                if {[lindex $contactsPerResidue $element] > $maxCount} {
                    set maxCount [lindex $contactsPerResidue $element]
                }                
            }
        }
        
        set colorValueMap "[::SeqEditWidget::getColorMap]\::getColorIndexForValue"
        set colorNameMap "[::SeqEditWidget::getColorMap]\::getColorIndexForName"
        
        # Normalize the counts.
        foreach sequenceID $sequenceIDs {
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
                if {$maxCount > 0} {
                    set normalizedContacts [expr 0.5+(double($contactsMap($sequenceID,$element))/double($maxCount*2))]
                    seq set color $sequenceID $element [$colorValueMap $normalizedContacts]
                } else {
                    seq set color $sequenceID $element [$colorNameMap white]
                }
            }
        }
    }
    
# --------------------------------------------------------------------------
    proc calculateContactOrderPerResidue {sequenceIDs} {
        
        # Initialize the color map.
        array unset contactOrdersMap 
        
        # Go through each sequence in the list.
        set maxValue 0.0
        foreach sequenceID $sequenceIDs {
            
            # Get the contacts per residue.
            set contactOrderPerResidue [::Libbiokit::getContactOrderPerResidue $sequenceID]            
            
            # Get the values.
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
                set contactOrdersMap($sequenceID,$element) [lindex $contactOrderPerResidue $element]
                if {$contactOrdersMap($sequenceID,$element) > $maxValue} {
                    set maxValue $contactOrdersMap($sequenceID,$element)
                }                
            }
        }
            
        set colorValueMap "[::SeqEditWidget::getColorMap]\::getColorIndexForValue"
        set colorNameMap "[::SeqEditWidget::getColorMap]\::getColorIndexForName"
        
        # Normalize the values.
        foreach sequenceID $sequenceIDs {
            for {set element 0} {$element < [SeqData::getSeqLength $sequenceID]} {incr element} {
                if {$maxValue > 0.0} {
                    set normalizedContacts [expr 0.5+(double($contactOrdersMap($sequenceID,$element))/double($maxValue*2.0))]
                    seq set color $sequenceID $element [$colorValueMap $normalizedContacts]
                } else {
                    seq set color $sequenceID $element [$colorNameMap white]
                }
            }
        }
    }
}
