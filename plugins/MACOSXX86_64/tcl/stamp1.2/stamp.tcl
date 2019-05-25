############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: stamp.tcl,v 1.4 2013/04/15 17:44:40 johns Exp $
#

package provide stamp 1.2

namespace eval ::STAMP:: {
    
    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "stamp"
    
    # The current CPU architecture.
    variable architecture ""
    
    # Whether or not the reference has yet been printed.
    variable printedReference 0
    
    # Array variables to hold parsed stamp output
    variable viewtrans
    variable viewrot
    variable seqdata
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
    # This method sets the architecture that STAMP is running on.
    # args:     newArchitecture - The architecture being used.
    proc setArchitecture {newArchitecture} {

        variable architecture
        
        # Set the temp directory and file prefix.
        set architecture $newArchitecture
    }

# -------------------------------------------------------------------
    # This function will actually align the requested things.
    #   "args" is a list of atomselect things to be aligned.
    proc alignStructures {sequences scan scanslide scanscore slowscan npass} {

        variable tempDir
        variable filePrefix
        variable viewtrans
        variable viewrot
        variable seqdata
   
#        puts "stamp.tcl.alignStructures. seqs: $sequences, scan: $scan, slide: $scanslide, score: $scanscore, slow: $slowscan, npass: $npass"
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Go through the sequences.
        set alignmentType ""
        set atomtype ""
        for {set i 0} {$i < [llength $sequences]} {incr i} {
            
            # Get the sequenceID.
            set sequenceID [lindex $sequences $i]
            
            # See what kind of atomtype we are looking for, if we don't already know.
            set sequenceType [::SeqData::getType $sequenceID]
            if {$alignmentType == ""} {
                set alignmentType $sequenceType
                if {$sequenceType == "protein"} {
                    set atomtype "CA"
                } elseif {$sequenceType == "rna" || $sequenceType == "dna"} {
                    set atomtype "P"
                }
            }
                
            # See if this sequence is composed completely of the selected type.
            if {[llength [SeqData::VMD::getResidues $sequenceID "name $atomtype"]] != [llength [SeqData::VMD::getResidues $sequenceID]]} {
                
                # Write out and error and return.
                set r [SeqData::VMD::getResidues $sequenceID "name $atomtype"]
                #puts "[::SeqData::getSeq $sequenceID]"
                #puts "Comparing:$r:"
                error "The selection in sequence [::SeqData::getName $sequenceID] was not completely composed of $sequenceType residues and can not be aligned by STAMP."
            }
            
            # See if this sequence is of the right type.
            if {($sequenceType == "protein" && $atomtype == "CA") || (($sequenceType == "rna" || $sequenceType == "dna") && $atomtype == "P")} {
                    
                # Write out the PDB files with the backbone atoms for stamp to use.
                ::SeqData::VMD::writeStructure $sequenceID "$tempDir/$filePrefix.$i.pdb" "name $atomtype"
                
            } else {
                
                # Write out and error and return.
                error "The selection in sequence [::SeqData::getName $sequenceID] was not of the same type as the other sequences and can not be aligned to them."
            }
        }
        
        # Set up the start domain file.
        set start_domain [open "$tempDir/$filePrefix.start.domain" w]
        puts $start_domain "$filePrefix.0.pdb 0 { ALL }"
        close $start_domain
        
        # Set up the remainder domain file.
        set db_domain [open "$tempDir/$filePrefix.db.domain" w]
        for {set i 1} {$i < [llength $sequences]} {incr i} {
            puts $db_domain "$filePrefix.$i.pdb $i { ALL }"
        }
        close $db_domain

        set atomTypeParam 0
        if {$atomtype == "P"} {
            set atomTypeParam 1
        }
        
        # Run the rough fit of stamp.
        set rough_out [run "$tempDir" -f \"$filePrefix.start.domain\" -scan $scan -scanslide $scanslide -scanscore $scanscore -slowscan $slowscan -n $npass -d \"$filePrefix.db.domain\" -ATOMTYPE $atomTypeParam -prefix $filePrefix]    
        
        # Run the final fit of stamp.
        set final_out [run "$tempDir" -f \"$filePrefix.scan\" -ATOMTYPE $atomTypeParam -prefix $filePrefix]
        
        # Test and make sure stamp returned files for all the input molecules.
        for {set i 1} {$i < [llength $sequences]} {incr i} {
            if {! [file exists "$tempDir/$filePrefix.$i"]} {
                error "STAMP was unable to align the loaded molecules because they are not similar enough."
            }
        }
        
        # Get the name of the file with the output 
        set outfile "$filePrefix.[expr [llength $sequences]-1]"
        
        # Clear view transform matrices.
        if {[info exists viewrot]} { 
            unset viewrot 
        }
        if {[info exists viewtrans]} { 
            unset viewtrans 
        }
        
        # Clear prev. alignment data.
        if {[info exists seqdata]} { 
            unset seqdata 
        }
          
        # Parse the output.        
        set out_fh [open $tempDir/$outfile r]
        if { [info exists mlist] } { unset mlist }
        set num_out 0
        while {![eof $out_fh]} {
            if {[gets $out_fh inline] > 0} {
                if {[regexp {^.*\{[ ]+ALL.*$} $inline]} {
                        
                    # A filename line.
                    set mnum [lrange [split $inline "."] 1 1]
                    if { $num_out < $mnum } { set num_out $mnum }
                    lappend mlist $mnum
                    set dline 0
                    
                } elseif {[regexp {^.*[0-9]+\.[0-9]+[ ]+.[0-9]+\.[0-9]+[ ]+.[0-9]+\.[0-9]+[ ]+.[0-9]+\.[0-9]+[ ]+.*$} $inline]} {
                    
                    # A matrix line.
                    set tmpar ""
                    set num_read 0
                    foreach num [split $inline] {
                        if {[regexp {^.*[0-9].*$} $num]} {
                            if {$num_read < 3} {
                                incr num_read
                                lappend tmpar $num
                            } else {
                                lappend viewrot($mnum) $num
                            }
                        }
                    }
                    lappend viewtrans($mnum) $tmpar
                    incr dline
                    
                } elseif {[regexp {^([ ]|[A-Z])+[ ]+[\?]+.*$} $inline]} {
                    
                    set i 0
                    foreach m $mlist {
                        lappend seqdata($m) [string range $inline $i $i]
                        incr i
                    }
                }
            }
        }
        close $out_fh
            
        # Replace non-letter chars in sequence data with "-"
        for {set i 0} {$i <= $num_out} {incr i} {
            for {set j 0} {$j < [llength $seqdata($i)]} {incr j} {
                if {![regexp {[A-Z]} [lindex $seqdata($i) $j]] } {
                    set seqdata($i) [lreplace $seqdata($i) $j $j "-"]
                }
            }
        }
        
        # Create the new sequences.
        set newSequenceIDs {}
        for {set i 0} {$i < [llength $sequences]} {incr i} {
            
            # Get the original sequence.
            set oldSequenceID [lindex $sequences $i]
            
            # Create a new sequence.
            set newSequenceID [::SeqData::duplicateSequence $oldSequenceID]
            
            # Set the sequence data.
            ::SeqData::setSeq $newSequenceID $seqdata($i)
                        
            # Add it to the list.
            lappend newSequenceIDs $newSequenceID
        }

        # Return the new sequence ids.
        return $newSequenceIDs
    }
    
    proc getRotations {} {

        variable viewrot

        # Return the data, if we have any.        
        if { [info exists viewrot] } {
            return [array get viewrot]
        } else {
            return  {}
        }
    }
    
    proc getTransformations {} {

        variable viewtrans
        

        # Return the data, if we have any.        
        if { [info exists viewtrans] } {
            return [array get viewtrans]
        } else {
            return  {}
        }
    }
	
    # Runs the STAMP executable. This method should only be called from inside the STAMP package.
    # arg:      args - The list of arguments that should be passed to the program.
    proc run {wd args} {
        
        global env
        variable architecture
    
        # Get the location of the executable
        set stampdir $env(STAMPPLUGINDIR)

        # Build the name of the executable.    
        switch $architecture {
            WIN32 {
                set cmd "exec {$stampdir/stamp.exe}"
                append wd "/" 
            }
            default {
                set cmd "exec {$stampdir/stamp}"
            }
        }
    
        # Append the arguments.
        foreach arg $args {
            append cmd " $arg"
        }
    
        # Get the current directoty.
        set pwd [pwd]
    
        # Change to the working directory.
        cd "$wd"
    
        # Execute the command.
        printReference
        puts "STAMP Info) Running STAMP with command $cmd"
        set rc [catch {eval $cmd} out]
    
        # Change back to the old working directory.
        cd $pwd
    
        # If there was an error during execution, throw it.
        if {$rc != 0} {
            error $out
        }
        
        return $out
    }
    
    proc printReference {} {
        
        variable printedReference
        
        # Print out the reference message.
        if {!$printedReference} {
            set printedReference 1
            puts "STAMP Reference) In any publication of scientific results based in part or"
            puts "STAMP Reference) completely on the use of the program STAMP, please reference:"
            puts "STAMP Reference) Russell RB, Barton GJ. Multiple protein sequence alignment"
            puts "STAMP Reference) from tertiary structure comparison: assignment of global and"
            puts "STAMP Reference) residue confidence levels. Proteins. 1992 Oct;14(2):309-23."
        }
    }
}
