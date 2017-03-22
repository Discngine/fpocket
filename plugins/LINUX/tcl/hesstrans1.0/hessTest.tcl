# Test procs for libhessTrans.so
#   To run in a tcl shell:
#     > tclsh
#     % load libhessTrans.so
#     % source hessTest.tcl
#   Then just call the three functions: getWater, getFormiate, & getImidazole
#   Make sure libhessTrans.so and libnewmatWrap.so are in your library path.
#   You might need to set LD_LIBRARY_PATH to point to the directory that contains them.

# Run a water molecule through the hessian transformation


# Run a water molecule through the hessian transformation
proc getWater {} {

    set numCartesians 3
    set numBonds 2
    set numAngles 1
    set numDihedrals 0
    set numImpropers 0

    set numInternals [expr $numBonds + $numAngles]
    
    puts "  Load Cartesians"
    set cartesianListW [list -0.095459 0.0 -0.068090 -0.066224 0.0 0.900520 0.829898 0.0 -0.355797]
    # Contains cartesians and cartesian Hessian
    set cartesianArrayW [new_double [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]]
    puts "  \$numCartesians = $numCartesians; expr \$numCartesians * 3 = [expr $numCartesians * 3]"
    for {set i 0} {$i < [expr $numCartesians * 3]} {incr i} {
	set_double $cartesianArrayW $i [lindex $cartesianListW $i]
    }
    puts "  llength \$cartesianListW = [llength $cartesianListW]"

    set hessianCartesianList [list 0.515263 0.000000 -0.106281 -0.0492245 0.000000 0.0133860 -0.466038 0.000000 0.0928953 \
			      0.000000 -0.0000600487 0.000000 0.000000 0.0000300243 0.000000 0.000000 0.0000300243 0.000000 \
			      -0.106281 0.000000 0.588454 -0.0506252 0.000000 -0.502634 0.156906 0.000000 -0.0858201 \
			      -0.0492245 0.000000 -0.0506252 0.0494782 0.000000 -0.00126218 -0.000253672 0.000000 0.0518874 \
			      0.000000 0.0000300243 0.000000 0.000000 -0.0000607375 0.000000 0.000000 0.0000307132 0.000000 \
			      0.0133860 0.000000 -0.502634 -0.00126218 0.000000 0.516579 -0.0121238 0.000000 -0.0139454 \
			      -0.466038 0.000000 0.156906 -0.000253672 0.000000 -0.0121238 0.466292 0.000000 -0.144783 \
			      0.000000 0.0000300243 0.000000 0.000000 0.0000307132 0.000000 0.000000 -0.0000607375 0.000000 \
			      0.0928953 0.000000 -0.0858201 0.0518874 0.000000 -0.0139454 -0.144783 0.000000 0.0997655]
    for {set i 0} {$i < [expr ($numCartesians*3) * ($numCartesians*3)]} {incr i} {
	set_double $cartesianArrayW [expr ($numCartesians*3) + $i] [lindex $hessianCartesianList $i]
    }
    puts "  llength \$hessianCartesianList = [llength $hessianCartesianList]"

    set intArrayW [new_int [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]]
    set j 0

    puts "  Load Bonds"
    set bondListW [list 1 2 1 3]
    puts "  \$numBonds = $numBonds; expr \$numBonds * 2 = [expr $numBonds * 2]"
    for {set i 0} {$i < [expr $numBonds * 2]} {incr i} {
	set_int $intArrayW $j [lindex $bondListW $i]
	incr j
    }

    puts "  Load Angles"
    set angleListW [list 2 1 3]
    puts "  \$numAngles = $numAngles; expr \$numAngles * 3 = [expr $numAngles * 3]"
    for {set i 0} {$i < [expr $numAngles * 3]} {incr i} {
	set_int $intArrayW $j [lindex $angleListW $i]
	incr j
    }


    set hessianInternal [new_double [expr $numInternals * $numInternals]]

    puts "(\$numCartesians * 3) + ((\$numCartesians*3)*(\$numCartesians*3))= [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]"
    check_double $cartesianArrayW [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]
    puts "(\$numBonds * 2) + (\$numAngles * 3) = [expr ($numBonds * 2) + ($numAngles * 3)]"
    check_int $intArrayW [expr ($numBonds * 2) + ($numAngles * 3)]

    puts "  getInternalHessian"
    set ret [getInternalHessian $cartesianArrayW $intArrayW $hessianInternal $numCartesians $numBonds $numAngles $numDihedrals $numImpropers]
    puts $ret

    puts "Hessian in internal coordinates:"
    for {set i 0} {$i < $numInternals} {incr i} {
	for {set j 0} {$j < $numInternals} {incr j} {
	    set index [expr ($i * $numInternals) + $j]
	    puts -nonewline [get_double $hessianInternal $index]
	    puts -nonewline " "
	}
	puts " "
    }

    delete_double $cartesianArrayW
    delete_int $intArrayW
    delete_double $hessianInternal
}


# Run a formiate molecule through the hessian transformation
proc getFormiate {} {
    puts "Formiate"
    
    set numCartesians 4
    set numBonds 3
    set numAngles 3
    set numDihedrals 0
    set numImpropers 1

    set numInternals [expr $numBonds + $numAngles + $numDihedrals + $numImpropers]
    
    puts "  Load Cartesians"
    set cartesianListW [list -0.094371 0.0 0.048921 0.038377 0.0 1.281795 1.053697 0.0 1.976075 -0.923703 0.0 1.855209]
    #set cartesianArrayW [new_double [expr $numCartesians * 3]]
    set cartesianArrayW [new_double [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]]
    puts "  \$numCartesians = $numCartesians; expr \$numCartesians * 3 = [expr $numCartesians * 3]"
    for {set i 0} {$i < [expr $numCartesians * 3]} {incr i} {
	set_double $cartesianArrayW $i [lindex $cartesianListW $i]
    }
    puts "  llength \$cartesianListW = [llength $cartesianListW]"
    
    set hessianCartesianList [list 0.116369 0.000000 0.0690148 -0.129156 0.000000 -0.0209901 0.00765969 0.000000 -0.0853240 0.00512733 0.000000 0.0372992 \
			      0.000000 0.0346797 0.000000 0.000000 -0.0963023 0.000000 0.000000 0.0321698 0.000000 0.000000 0.0294529 0.000000 \
			      0.0690148 0.000000 0.738407 -0.00545521 0.000000 -0.601136 -0.0846844 0.000000 -0.0839934 0.0211248 0.000000 -0.0532776 \
			      -0.129156 0.000000 -0.00545521 0.823401 0.000000 0.171911 -0.517086 0.000000 -0.236030 -0.177159 0.000000 0.0695739 \
			      0.000000 -0.0963023 0.000000 0.000000 0.276065 0.000000 0.000000 -0.0922339 0.000000 0.000000 -0.0875292 0.000000 \
			      -0.0209901 0.000000 -0.601136 0.171911 0.000000 0.963529 -0.220557 0.000000 -0.259140 0.0696361 0.000000 -0.103253 \
			      0.00765969 0.000000 -0.0846844 -0.517086 0.000000 -0.220557 0.575617 0.000000 0.321754 -0.0661901 0.000000 -0.0165128 \
			      0.000000 0.0321698 0.000000 0.000000 -0.0922339 0.000000 0.000000 0.0301875 0.000000 0.000000 0.0298766 0.000000 \
			      -0.0853240 0.000000 -0.0839934 -0.236030 0.000000 -0.259140 0.321754 0.000000 0.326165 -0.000400506 0.000000 0.0169683 \
			      0.00512733 0.000000 0.0211248 -0.177159 0.000000 0.0696361 -0.0661901 0.000000 -0.000400506 0.238222 0.000000 -0.0903604 \
			      0.000000 0.0294529 0.000000 0.000000 -0.0875292 0.000000 0.000000 0.0298766 0.000000 0.000000 0.0281997 0.000000 \
			      0.0372992 0.000000 -0.0532776 0.0695739 0.000000 -0.103253 -0.0165128 0.000000 0.0169683 -0.0903604 0.000000 0.139562]
    for {set i 0} {$i < [expr ($numCartesians*3) * ($numCartesians*3)]} {incr i} {
	set_double $cartesianArrayW [expr ($numCartesians*3) + $i] [lindex $hessianCartesianList $i]
    }
    puts "  llength \$hessianCartesianList = [llength $hessianCartesianList]"

    set intArrayW [new_int [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]]
    set j 0

    puts "  Load Bonds"
    set bondListW [list 1 2 2 3 2 4]
    puts "  \$numBonds = $numBonds; expr \$numBonds * 2 = [expr $numBonds * 2]"
    for {set i 0} {$i < [expr $numBonds * 2]} {incr i} {
	set_int $intArrayW $j [lindex $bondListW $i]
	incr j
    }
    
    puts "  Load Angles"
    set angleListW [list 1 2 3 1 2 4 3 2 4]
    puts "  \$numAngles = $numAngles; expr \$numAngles * 3 = [expr $numAngles * 3]"
    for {set i 0} {$i < [expr $numAngles * 3]} {incr i} {
	set_int $intArrayW $j [lindex $angleListW $i]
	incr j
    }
    
    puts "  Load Dihedrals"
    set dihedralListW [list ]
    puts "  \$numDihedrals = $numDihedrals; expr \$numDihedrals * 4 = [expr $numDihedrals * 4]"
    for {set i 0} {$i < [expr $numDihedrals * 4]} {incr i} {
	set_int $intArrayW $j [lindex $dihedralListW $i]
	incr j
    }
    
    puts "  Load Impropers"
    set improperListW [list 3 1 4 2]
    puts "  \$numImpropers = $numImpropers; expr \$numImpropers * 4 = [expr $numImpropers * 4]"
    for {set i 0} {$i < [expr $numImpropers * 4]} {incr i} {
	set_int $intArrayW $j [lindex $improperListW $i]
	incr j
    }


    set hessianInternal [new_double [expr $numInternals * $numInternals]]
    for {set i 0} {$i < [expr $numInternals * $numInternals]} {incr i} {
	set_double $hessianInternal $i 0
    }

    
    puts "(\$numCartesians * 3) + ((\$numCartesians*3)*(\$numCartesians*3)) = [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]"
    check_double $cartesianArrayW [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]
    puts "(\$numBonds * 2) + (\$numAngles * 3) + (\$numDihedrals * 4) + (\$numImpropers * 4) = [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]"
    check_int $intArrayW [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]

    puts "  getInternalHessian"
    set ret [getInternalHessian $cartesianArrayW $intArrayW $hessianInternal $numCartesians $numBonds $numAngles $numDihedrals $numImpropers]
    puts $ret

    puts "Hessian in internal coordinates:"
    for {set i 0} {$i < $numInternals} {incr i} {
	for {set j 0} {$j < $numInternals} {incr j} {
	    set index [expr ($i * $numInternals) + $j]
	    puts -nonewline [get_double $hessianInternal $index]
	    puts -nonewline " "
	}
	puts " "
    }

    delete_double $cartesianArrayW
    delete_int $intArrayW
    delete_double $hessianInternal
}


# Run an imidazole molecule through the hessian transformation
proc getImidazole {} {
    puts "Imidazole"
    
    set numCartesians 9
    set numBonds 8
    set numAngles 9
    set numDihedrals 8
    set numImpropers 0

    set numInternals [expr $numBonds + $numAngles + $numDihedrals + $numImpropers]
    
    puts "  Load Cartesians"
    set cartesianListW [list -0.002165 0.015029 -0.008626 0.016991 0.010965 1.371235 1.311097 0.026977  1.850226 2.069098 0.017004  0.769608 1.324627 0.015961 -0.380462 -0.819240 0.004005  2.054659 3.149084 0.019064  0.764514 1.677245 0.015944 -1.326908 -0.804737 0.005051 -0.731246]
    #set cartesianArrayW [new_double [expr $numCartesians * 3]]
    set cartesianArrayW [new_double [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]]
    puts "  \$numCartesians = $numCartesians; expr \$numCartesians * 3 = [expr $numCartesians * 3]"
    for {set i 0} {$i < [expr $numCartesians * 3]} {incr i} {
	set_double $cartesianArrayW $i [lindex $cartesianListW $i]
    }
    puts "  llength \$cartesianListW = [llength $cartesianListW]"

    set hessianCartesianList [list 0.702368 0.00272371 0.158802 -0.0993604 -0.000127214 -0.00118501 -0.0208712 -0.000173209 -0.0148905 -0.0845374 -0.000425404 -0.0540718 -0.288084 -0.000913563 0.0498786 0.00713302 0.0000509624 0.0220713 0.00116782 -0.00000837995 -0.000167505 0.00404145 0.0000756407 -0.00250568 -0.221858 -0.00120254 -0.157931 \
			      0.00272371 0.105871 0.00161978 -0.000138147 -0.0637503 -0.000430887 -0.000235544 0.0167697 -0.000125522 -0.000393634 0.0155289 -0.000232881 -0.000865532 -0.0490245 0.000131599 0.0000223830 -0.000286432 0.0000708208 -0.0000103319 0.00272262 -0.0000138193 0.0000382482 -0.00770645 -0.0000106015 -0.00114115 -0.0201248 -0.00100848 \
			      0.158802 0.00161978 0.773297 0.0151902 -0.000363827 -0.386924 -0.0868052 -0.000390768 -0.0323668 -0.00475487 -0.0000678163 -0.0157507 0.0421028 0.000140865 -0.126944 -0.00355068 -0.00000604433 -0.00636402 -0.00214266 -0.00000962319 -0.00619313 0.0287691 0.0000767058 0.00259669 -0.147610 -0.000999268 -0.201350 \
			      -0.0993604 -0.000138147 0.0151902 0.698207 0.00183503 -0.169203 -0.246120 -0.000732202 -0.0525225 -0.0956775 -0.000321769 0.0620396 -0.0267033 -0.000174463 0.0142645 -0.229682 -0.000441687 0.150015 0.000164060 -0.0000283378 0.00355703 -0.00854572 -0.0000222412 -0.00223107 0.00771850 0.0000238146 -0.0211106 \
			      -0.000127214 -0.0637503 -0.000363827 0.00183503 0.131418 0.000267434 -0.000741181 -0.0694259 -0.000278100 -0.000400718 0.0106126 0.000241842 -0.0000803128 0.0120875 -0.0000455539 -0.000466835 -0.0288112 0.000275455 -0.0000235809 0.00683895 0.000000 -0.0000377326 0.00249756 -0.00000473040 0.0000425430 -0.00146736 -0.0000925065 \
			      -0.00118501 -0.000430887 -0.386924 -0.169203 0.000267434 0.753312 -0.0624481 -0.000318566 -0.124766 0.00455546 0.0000379250 0.00893127 0.0739957 0.000157496 -0.0620183 0.146905 0.000234542 -0.184712 0.00301253 -0.00000608384 -0.00374670 0.00257648 0.0000264335 0.000444931 0.00179027 0.0000317055 -0.000521610 \
			      -0.0208712 -0.000235544 -0.0868052 -0.246120 -0.000741181 -0.0624481 0.509826 0.00148305 -0.0676021 -0.202925 -0.000358211 0.158075 -0.00614126 0.00000576750 0.0471490 -0.0211648 -0.0000740812 -0.0108164 -0.0121669 0.0000172210 0.0281760 -0.00195747 -0.0000642656 -0.00266761 0.00152032 -0.0000327579 -0.00306053 \
			      -0.000173209 0.0167697 -0.000390768 -0.000732202 -0.0694259 -0.000318566 0.00148305 0.103075 0.000263646 -0.000353192 -0.0751434 0.000335685 -0.0000817710 0.0211255 0.0000434403 -0.0000372830 -0.00507951 -0.00000990659 -0.0000238758 -0.00526977 0.000124676 -0.0000567633 0.00697417 -0.0000198706 -0.0000247569 0.00697426 -0.0000283354 \
			      -0.0148905 -0.000125522 -0.0323668 -0.0525225 -0.000278100 -0.124766 -0.0676021 0.000263646 0.559199 0.135421 0.000280532 -0.305964 -0.0143292 -0.000198034 -0.103457 0.0168931 0.0000930307 0.0135602 0.00268921 0.0000121110 0.00426402 -0.00767418 -0.0000492366 -0.00488259 0.00201512 0.00000157376 -0.00558720 \
			      -0.0845374 -0.000393634 -0.00475487 -0.0956775 -0.000400718 0.00455546 -0.202925 -0.000353192 0.135421 0.913252 0.00309809 -0.0556369 -0.183043 -0.000649743 -0.0975639 -0.00553817 -0.0000472940 -0.00406857 -0.355538 -0.00136353 0.000858327 0.0181297 0.000133003 0.0170857 -0.00412254 -0.0000229788 0.00410373 \
			      -0.000425404 0.0155289 -0.0000678163 -0.000321769 0.0106126 0.0000379250 -0.000358211 -0.0751434 0.000280532 0.00309809 0.130303 0.000288135 -0.000691704 -0.0560926 -0.000574900 -0.0000411404 0.00515123 -0.0000244549 -0.00136515 -0.0239914 -0.0000283424 0.000131111 -0.00902644 0.0000827270 -0.0000258191 0.00265829 0.00000619507 \
			      -0.0540718 -0.000232881 -0.0157507 0.0620396 0.000241842 0.00893127 0.158075 0.000335685 -0.305964 -0.0556369 0.000288135 0.619365 -0.0947015 -0.000480145 -0.234291 -0.00247395 -0.0000120311 -0.000311967 -0.00334472 -0.0000306095 -0.0574256 -0.0137391 -0.000101114 -0.0102560 0.00385337 -0.00000888153 -0.00429800 \
			      -0.288084 -0.000865532 0.0421028 -0.0267033 -0.0000803128 0.0739957 -0.00614126 -0.0000817710 -0.0143292 -0.183043 -0.000691704 -0.0947015 0.651798 0.00241667 -0.116619 0.000782867 -0.0000289331 -0.000379196 -0.00935909 -0.0000665274 -0.0316164 -0.122242 -0.000602487 0.127318 -0.0170084 0.000000 0.0142289 \
			      -0.000913563 -0.0490245 0.000140865 -0.000174463 0.0120875 0.000157496 0.00000576750 0.0211255 -0.000198034 -0.000649743 -0.0560926 -0.000480145 0.00241667 0.0772575 -0.000253408 -0.0000160104 0.00519791 -0.0000119089 -0.0000256958 -0.00242861 -0.000120912 -0.000557486 -0.00354364 0.000678051 -0.0000854755 -0.00457896 0.0000879956 \
			      0.0498786 0.000131599 -0.126944 0.0142645 -0.0000455539 -0.0620183 0.0471490 0.0000434403 -0.103457 -0.0975639 -0.000574900 -0.234291 -0.116619 -0.000253408 0.925576 -0.00241786 -0.0000239609 -0.00579351 0.00174851 0.00000940976 0.00386271 0.125889 0.000767374 -0.410999 -0.0223289 -0.0000539998 0.0140644 \
			      0.00713302 0.0000223830 -0.00355068 -0.229682 -0.000466835 0.146905 -0.0211648 -0.0000372830 0.0168931 -0.00553817 -0.0000411404 -0.00247395 0.000782867 -0.0000160104 -0.00241786 0.248452 0.000539358 -0.157277 -0.000410578 -0.00000402365 0.00124209 0.000690037 -0.00000355972 0.0000157561 -0.000261966 0.00000711144 0.000662899 \
			      0.0000509624 -0.000286432 -0.00000604433 -0.000441687 -0.0288112 0.000234542 -0.0000740812 -0.00507951 0.0000930307 -0.0000472940 0.00515123 -0.0000120311 -0.0000289331 0.00519791 -0.0000239609 0.000539358 0.0229559 -0.000298983 -0.00000639852 0.00110550 0.00000427630 0.000000 0.00193399 0.00000175242 0.00000780851 -0.00216735 0.00000741878 \
			      0.0220713 0.0000708208 -0.00636402 0.150015 0.000275455 -0.184712 -0.0108164 -0.00000990659 0.0135602 -0.00406857 -0.0000244549 -0.000311967 -0.000379196 -0.0000119089 -0.00579351 -0.157277 -0.000298983 0.182590 -0.000343632 -0.00000276545 0.000805630 0.00128481 0.000000 0.000377758 -0.000487016 0.00000193774 -0.000152684 \
			      0.00116782 -0.0000103319 -0.00214266 0.000164060 -0.0000235809 0.00301253 -0.0121669 -0.0000238758 0.00268921 -0.355538 -0.00136515 -0.00334472 -0.00935909 -0.0000256958 0.00174851 -0.000410578 -0.00000639852 -0.000343632 0.376866 0.00145992 -0.00125092 -0.000537423 0.00000242050 -0.000615669 -0.000185567 -0.00000730430 0.000247348 \
			      -0.00000837995 0.00272262 -0.00000962319 -0.0000283378 0.00683895 -0.00000608384 0.0000172210 -0.00526977 0.0000121110 -0.00136353 -0.0239914 -0.0000306095 -0.0000665274 -0.00242861 0.00000940976 -0.00000402365 0.00110550 -0.00000276545 0.00145992 0.0203176 0.0000355368 0.00000227317 -0.00114240 -0.00000521806 -0.00000861260 0.00184745 -0.00000275756 \
			      -0.000167505 -0.0000138193 -0.00619313 0.00355703 0.000000 -0.00374670 0.0281760 0.000124676 0.00426402 0.000858327 -0.0000283424 -0.0574256 -0.0316164 -0.000120912 0.00386271 0.00124209 0.00000427630 0.000805630 -0.00125092 0.0000355368 0.0573028 0.000374206 0.00000272487 0.000200901 -0.00117280 -0.00000412571 0.000929370 \
			      0.00404145 0.0000382482 0.0287691 -0.00854572 -0.0000377326 0.00257648 -0.00195747 -0.0000567633 -0.00767418 0.0181297 0.000131111 -0.0137391 -0.122242 -0.000557486 0.125889 0.000690037 0.000000 0.00128481 -0.000537423 0.00000227317 0.000374206 0.110256 0.000475876 -0.136579 0.000166005 0.00000420809 -0.000901116 \
			      0.0000756407 -0.00770645 0.0000767058 -0.0000222412 0.00249756 0.0000264335 -0.0000642656 0.00697417 -0.0000492366 0.000133003 -0.00902644 -0.000101114 -0.000602487 -0.00354364 0.000767374 -0.00000355972 0.00193399 0.000000 0.00000242050 -0.00114240 0.00000272487 0.000475876 0.0110623 -0.000721403 0.00000561285 -0.00104904 -0.00000129053 \
			      -0.00250568 -0.0000106015 0.00259669 -0.00223107 -0.00000473040 0.000444931 -0.00266761 -0.0000198706 -0.00488259 0.0170857 0.0000827270 -0.0102560 0.127318 0.000678051 -0.410999 0.0000157561 0.00000175242 0.000377758 -0.000615669 -0.00000521806 0.000200901 -0.136579 -0.000721403 0.422454 0.000179810 0.000000 0.0000642058 \
			      -0.221858 -0.00114115 -0.147610 0.00771850 0.0000425430 0.00179027 0.00152032 -0.0000247569 0.00201512 -0.00412254 -0.0000258191 0.00385337 -0.0170084 -0.0000854755 -0.0223289 -0.000261966 0.00000780851 -0.000487016 -0.000185567 -0.00000861260 -0.00117280 0.000166005 0.00000561285 0.000179810 0.234032 0.00122985 0.163761 \
			      -0.00120254 -0.0201248 -0.000999268 0.0000238146 -0.00146736 0.0000317055 -0.0000327579 0.00697426 0.00000157376 -0.0000229788 0.00265829 -0.00000888153 0.000000 -0.00457896 -0.0000539998 0.00000711144 -0.00216735 0.00000193774 -0.00000730430 0.00184745 -0.00000412571 0.00000420809 -0.00104904 0.000000 0.00122985 0.0179075 0.00103177 \
			      -0.157931 -0.00100848 -0.201350 -0.0211106 -0.0000925065 -0.000521610 -0.00306053 -0.0000283354 -0.00558720 0.00410373 0.00000619507 -0.00429800 0.0142289 0.0000879956 0.0140644 0.000662899 0.00000741878 -0.000152684 0.000247348 -0.00000275756 0.000929370 -0.000901116 -0.00000129053 0.0000642058 0.163761 0.00103177 0.196852]
    for {set i 0} {$i < [expr ($numCartesians*3) * ($numCartesians*3)]} {incr i} {
	set_double $cartesianArrayW [expr ($numCartesians*3) + $i] [lindex $hessianCartesianList $i]
    }
    puts "  llength \$hessianCartesianList = [llength $hessianCartesianList]"

    set intArrayW [new_int [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]]
    set j 0
    
    puts "  Load Bonds"
    set bondListW [list 1 2 1 9 2 3 2 6 3 4 4 5 4 7 5 8]
    puts "  \$numBonds = $numBonds; expr \$numBonds * 2 = [expr $numBonds * 2]"
    for {set i 0} {$i < [expr $numBonds * 2]} {incr i} {
	set_int $intArrayW $j [lindex $bondListW $i]
	incr j
    }
    
    puts "  Load Angles"
    set angleListW [list 2 1 9 1 2 3 1 2 6 3 2 6 2 3 4 3 4 5 3 4 7 5 4 7 4 5 8]
    puts "  \$numAngles = $numAngles; expr \$numAngles * 3 = [expr $numAngles * 3]"
    for {set i 0} {$i < [expr $numAngles * 3]} {incr i} {
	set_int $intArrayW $j [lindex $angleListW $i]
	incr j
    }
    
    puts "  Load Dihedrals"
    set dihedralListW [list 9 1 2 3 9 1 2 6 1 2 3 4 6 2 3 4 2 3 4 5 2 3 4 7 3 4 5 8 7 4 5 8]
    puts "  \$numDihedrals = $numDihedrals; expr \$numDihedrals * 4 = [expr $numDihedrals * 4]"
    for {set i 0} {$i < [expr $numDihedrals * 4]} {incr i} {
	set_int $intArrayW $j [lindex $dihedralListW $i]
	incr j
    }
    
    puts "  Load Impropers"
    set improperListW [list ]
    puts "  \$numImpropers = $numImpropers; expr \$numImpropers * 4 = [expr $numImpropers * 4]"
    for {set i 0} {$i < [expr $numImpropers * 4]} {incr i} {
	set_int $intArrayW $j [lindex $improperListW $i]
	incr j
    }
    

    set hessianInternal [new_double [expr $numInternals * $numInternals]]
    for {set i 0} {$i < [expr $numInternals * $numInternals]} {incr i} {
	set_double $hessianInternal $i 0
    }

    #puts "  Allocate Hessian"
    #set hessianArrayW [new_double 3]
    #set_double $hessianArrayW 0 0.0
    #set_double $hessianArrayW 1 0.0
    #set_double $hessianArrayW 2 0.0
    
    puts "(\$numCartesians * 3) + ((\$numCartesians*3)*(\$numCartesians*3)) = [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]"
    check_double $cartesianArrayW [expr ($numCartesians * 3) + (($numCartesians*3)*($numCartesians*3))]
    puts "(\$numBonds * 2) + (\$numAngles * 3) + (\$numDihedrals * 4) + (\$numImpropers * 4) = [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]"
    check_int $intArrayW [expr ($numBonds * 2) + ($numAngles * 3) + ($numDihedrals * 4) + ($numImpropers * 4)]
    
    puts "  getInternalHessian"
    set ret [getInternalHessian $cartesianArrayW $intArrayW $hessianInternal $numCartesians $numBonds $numAngles $numDihedrals $numImpropers]
    puts $ret

    puts "Hessian in internal coordinates:"
    for {set i 0} {$i < $numInternals} {incr i} {
	for {set j 0} {$j < $numInternals} {incr j} {
	    set index [expr ($i * $numInternals) + $j]
	    puts -nonewline [get_double $hessianInternal $index]
	    puts -nonewline " "
	}
	puts " "
    }

    delete_double $cartesianArrayW
    delete_int $intArrayW
    delete_double $hessianInternal
}


proc getNone {} {
    
    set numCartesians 0
    set numBonds 0
    set numAngles 0
    set numDihedrals 0
    set numImpropers 0


    puts "  Load Cartesians"
    set cartesianArrayW [new_double 0]
    puts "  Load Bonds"
    set bondArrayW [new_int 0]
    puts "  Load Angles"
    set angleArrayW [new_int 0]
    puts "  Load Dihedrals"
    set dihedralArrayW [new_int 0]
    puts "  Load Impropers"
    set improperArrayW [new_int 0]
    puts "\$numCartesians = $numCartesians"
    check_double $cartesianArrayW [expr $numCartesians * 3]
    puts "\$numBonds = $numBonds"
    check_int $bondArrayW [expr $numBonds * 2]
    puts "\$numAngles = $numAngles"
    check_int $angleArrayW [expr $numAngles * 3]
    puts "\$numDihedrals = $numDihedrals"
    check_int $dihedralArrayW [expr $numDihedrals * 4]
    puts "\$numImpropers = $numImpropers"
    check_int $improperArrayW [expr $numImpropers * 4]

    #puts "  getInternalHessian"
    #set ret [getInternalHessian $cartesianArrayW $intArrayW $hessianInternal $numCartesians $numBonds $numAngles $numDihedrals $numImpropers]
    #puts $ret
}
