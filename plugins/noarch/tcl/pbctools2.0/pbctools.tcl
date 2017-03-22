##
## PBC Tools 2.0
##
## A plugin for the handling of periodic boundary conditions.
##
## Authors: 
##   Jerome Henin <Jerome.Henin _at_ edam.uhp-nancy.fr>
##   Olaf Lenz <olenz _at_ fias.uni-frankfurt.de>
##   Cameron Mura <cmura _at_ mccammon.ucsd.edu>
##   Jan Saam <saam _at_ charite.de>
##
## The pbcbox procedure copies a lot of the ideas of Axel Kohlmeiers
## script vmd_draw_unitcell.
##
## $Id: pbctools.tcl,v 1.5 2007/07/31 16:06:06 johns Exp $
##
package provide pbctools 2.1

###################################################
# Main namespace procedures
###################################################
# Main UI
proc pbc { args } {
    proc usage {} {
	puts "usage: pbc <command> \[args...\]"
	puts ""
	puts "Setting/getting PBC information:"
	puts "  set \$cell \[options...\]"
	puts "  get \[options...\]"
	puts "  readxst \$xstfile \[options...\]"
	puts ""
	puts "Drawing a box:"
	puts "  box \[options...\]"
	puts "  box_draw \[options...\]"
	puts ""
	puts "(Un)Wrapping atoms:"
	puts "  wrap \[options...\]"
	puts "  unwrap \[options...\]"
	puts ""
	return
    }

    if { [llength $args] < 1 } then { usage; return }
    set command [ lindex $args 0 ]
    set args [lrange $args 1 end]
    set fullcommand "::PBCTools::pbc$command"

#     puts "command=$command"
#     puts "fullcommand=$fullcommand"
#     puts "args=$args"

    if { [ string length [namespace which -command $fullcommand]] } then {
	eval "$fullcommand $args"
    } else { usage; return }
}

