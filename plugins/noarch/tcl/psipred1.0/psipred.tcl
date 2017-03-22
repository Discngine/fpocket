############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# Package for using clustalw on sequences obtained from the seqdata package.

package provide psipred 1.0
package require seqdata 1.0
package require blast 1.0

namespace eval ::Psipred {
    
    # Export the package namespace.
    namespace export Psipred

    # Directory to write temp files.
    global env
    variable tempDir ""
    if {[info exists env(TMPDIR)]} {
        set tempDir $env(TMPDIR)
    }

    # The prefix for temp files.
    variable filePrefix "psipred"
    
    # The directories where the blast executables are located.
    variable psipredProgramDir ""
    variable psipredDataDir ""
    variable psipredDB ""
    
    # The current CPU architecture.
    variable architecture ""
    
    # Whether or not the reference has yet been printed.
    variable printedReference 0
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        # Import global variables.
        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setPackageOptions {newPsipredProgramDir newPsipredDataDir newPsipredDB} {

        # Import global variables.
        variable psipredProgramDir
        variable psipredDataDir
        variable psipredDB
        
        # Figure out the program directory.
        set psipredProgramDir $newPsipredProgramDir
        if {[llength [glob -nocomplain [file join $psipredProgramDir "psipred*"]]] == 0} {
            if {[llength [glob -nocomplain [file join $psipredProgramDir "bin" "psipred*"]]] > 0} {
                set psipredProgramDir [file join $psipredProgramDir "bin"]
            }
        }
        
        # Figure out the data directory.
        set psipredDataDir $newPsipredDataDir
        if {![file isdirectory $psipredDataDir]} {
            if {[file isdirectory [file join $newPsipredProgramDir $psipredDataDir]]} {
                set psipredDataDir [file join $newPsipredProgramDir $psipredDataDir]
            }
        }
            
        # Figure out the db name.
        set psipredDB $newPsipredDB
        regsub -nocase {\.pal$|\.phr$|\.pin$|\.pnd$|\.pni$|\.psd$|\.psi$|\.psq$} $psipredDB "" psipredDB
    }
    
    # This method sets the temp file options used by thr stamp package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setArchitecture {newArchitecture} {

        # Import global variables.
        variable architecture
        
        # Set the temp directory and file prefix.
        set architecture $newArchitecture
    }
    
    proc checkPackageConfiguration {} {

        # Import global variables.
        variable architecture
        variable psipredProgramDir
        variable psipredDataDir
        variable psipredDB
        
        set errors {}
        
        if {$architecture == ""} {
            lappend errors "The architecture is not known."
        }
        if {$psipredProgramDir == ""} {
            lappend errors "No PSIPRED installation directory was specified."
        } elseif {![file isdirectory $psipredProgramDir]} {
            lappend errors "The PSIPRED installation directory could not be found."
        } else {
            set programSuffix ""
            if {$architecture == "WIN32"} {
                set programSuffix ".exe"
            }
            if {![file exists [file join $psipredProgramDir "psipred$programSuffix"]]} {
                lappend errors "A PSIPRED program file could not be found: psipred$programSuffix"
            }
            if {![file exists [file join $psipredProgramDir "psipass2$programSuffix"]]} {
                lappend errors "A PSIPRED program file could not be found: psipass2$programSuffix"
            }
        }
        if {$psipredDataDir == ""} {
            lappend errors "No PSIPRED data directory was specified."
        } elseif {![file isdirectory $psipredDataDir]} {
            lappend errors "The PSIPRED data directory could not be found."
        } else {
            if {![file exists [file join $psipredDataDir "weights.dat"]]} {
                lappend errors "A PSIPRED weights file could not be found: weights.dat"
            }
            if {![file exists [file join $psipredDataDir "weights.dat2"]]} {
                lappend errors "A PSIPRED weights file could not be found: weights.dat2"
            }
            if {![file exists [file join $psipredDataDir "weights.dat3"]]} {
                lappend errors "A PSIPRED weights file could not be found: weights.dat3"
            }
            if {![file exists [file join $psipredDataDir "weights.dat4"]]} {
                lappend errors "A PSIPRED weights file could not be found: weights.dat4"
            }
            if {![file exists [file join $psipredDataDir "weights_p2.dat"]]} {
                lappend errors "A PSIPRED weights file could not be found: weights_p2.dat"
            }
        }
        if {$psipredDB == ""} {
            lappend errors "No PSIPRED database was specified."
        } elseif {[llength [glob -nocomplain "$psipredDB.p*"]] == 0} {
            lappend errors "The PSIPRED database could not be found: $psipredDB"
        }
        
        return $errors
    }
    
    proc calculateSecondaryStructure {sequenceID} {
        
        # Import global variables.
        variable tempDir
        variable filePrefix
        variable psipredDataDir
        variable psipredDB
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Make sure the package is configured correctly.
        if {[checkPackageConfiguration] != {}} {
            set errorString [join [checkPackageConfiguration] "\n "]
            error "The PSIPRED package is not correctly configured. Please check the configuration options. The following errors were encountered:\n $errorString"
        }
        
        # Save the sequence as a fasta file.
        set inputFilename "$tempDir/$filePrefix.fasta"
        ::SeqData::Fasta::saveSequences $sequenceID $inputFilename
        
        # Perform the psiblast search to get the pssm matrix.
        set checkpointFilename "$tempDir/$filePrefix.chk"
        set blastOutputFilename "$tempDir/$filePrefix.blast"
        set output [::Blast::run $tempDir blastpgp -v 5000 -b 0 -j 3 -h 0.001 -d $psipredDB -i $inputFilename -C $checkpointFilename -o $blastOutputFilename]
        
        # Extract the pssm matrix from the checkpoint file.
        set pnFilename "$tempDir/$filePrefix.pn"
        set snFilename "$tempDir/$filePrefix.sn"
        set matrixFilename "$tempDir/$filePrefix.mtx"
        set fp [open $pnFilename w]
        puts $fp "[lindex [file split $checkpointFilename] end]"
        close $fp
        set fp [open $snFilename w]
        puts $fp "[lindex [file split $inputFilename] end]"
        close $fp
        set output [::Blast::run $tempDir makemat -P "$tempDir/$filePrefix"]
        
        # Run psipred.
        set ssFilename "$tempDir/$filePrefix.ss"
        set ss2Filename "$tempDir/$filePrefix.ss2"
        set output [run $tempDir psipred $matrixFilename "$psipredDataDir/weights.dat" "$psipredDataDir/weights.dat2" "$psipredDataDir/weights.dat3" "$psipredDataDir/weights.dat4" > $ssFilename]
        set output [run $tempDir psipass2 "$psipredDataDir/weights_p2.dat" 1 1.0 1.0 $ss2Filename $ssFilename]
        
        # Parse the output file.
        set ss [parseHFormat $output]
        
        # Return the results.
        return $ss
    }
    
    proc parseHFormat {string} {
        set prediction ""
        set predictionLines [regexp -all -inline {Pred\:\s\S+} $string]
        foreach predictionLine $predictionLines {
            if {[regexp {Pred\:\s(\S+)} $predictionLine unused predictionPart]} {
                append prediction $predictionPart
            }
        }
        return [split $prediction ""]
    }
    
    proc run {wd program args} {
        
        # Import global variables.
        global env
        variable psipredProgramDir
        variable architecture
        
        # If this is windows, append .exe to the program name.
        if {$architecture == "WIN32"} {
            append program ".exe"
        }
        
        # If we have a psipred program dir.
        set cmd ""
        if {$psipredProgramDir != ""} {
            
            # Try to find the binary.
            if {[file exists [file join $psipredProgramDir bin $program]]} {
                set cmd "exec \"[file join $psipredProgramDir bin $program]\""
            } elseif {[file exists [file join $psipredProgramDir $program]]} {
                set cmd "exec \"[file join $psipredProgramDir $program]\""
            }
        }
        
        # If we don't have a binary, just rely on the path.
        if {$cmd == ""} {
            set cmd "exec $program"
        }
        
        # Append the arguments.
        foreach arg $args {
            append cmd " \"$arg\""
        }
    
        # Print out the reference message.
        printReference        
        
        # Run the command and then return to the working directory.
        puts "Psipred Info) Running $program with command $cmd"
        set rc [catch {eval $cmd} out]
        puts "Psipred Info) $program returned with code $rc."
        
        # If there was an error during execution, throw it.
        if {$rc != 0} {
            error $out
        }
    
        return $out
    }
    
    proc printReference {} {
        
        # Import global variables.
        variable printedReference
        
        # Print out the reference message.
        if {!$printedReference} {
            set printedReference 1
            puts "Psipred Reference) In any publication of scientific results based in part or"
            puts "Psipred Reference) completely on the use of the program PSIPRED, please reference:"
            puts "Psipred Reference) Jones DT. Protein secondary structure prediction based on"
            puts "Psipred Reference) position-specific scoring matrices. J. Mol. Biol."
            puts "Psipred Reference) 1999;292:195-202."
        }
    }
    
}