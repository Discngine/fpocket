############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################
#
# $Id: cluster.tcl,v 1.2 2013/04/15 16:54:14 johns Exp $
#

package provide upgma_cluster 1.2

namespace eval ::UPGMA_Cluster {
    
    # Directory to write temp files.
    global env
    variable tempDir $env(TMPDIR)  

    # The prefix for temp files.
    variable filePrefix "upgma_cluster"
    
    # This method sets the temp file options used by the cluster package.
    # args:     newTempDir - The new temp directory to use.
    #           newFilePrefix - The prefix to use for temp files.
    proc setTempFileOptions {newTempDir newFilePrefix} {

        variable tempDir
        variable filePrefix
        
        # Set the temp directory and file prefix.
        set tempDir $newTempDir
        set filePrefix $newFilePrefix
    }
    
    # This method creates a UPGMA tree given a similarity matrix.
    # args:     matrix - The similarity matrix.
    # return:   The UPGMA tree in JE format. 
    proc createUPGMATree {matrix} {
        
        variable tempDir
        variable filePrefix
    
        # Delete any old files.
        foreach file [glob -nocomplain $tempDir/$filePrefix.*] {
            file delete -force $file
        }
        
        # Write out the matrix.
        set fp [open "$tempDir/$filePrefix.matrix" w]
        foreach row $matrix {
            puts $fp [join $row " "]
        }
        close $fp        
                
        # Run the cluster command.        
        set out [run "$tempDir" "$filePrefix.matrix"]
        
        return $out
    }
    
        
    proc run {wd args} {
        
        variable clusterdir
        global env
    
        set clusterdir $env(UPGMA_CLUSTERPLUGINDIR)

        switch [vmdinfo arch] {
            WIN32 {
                set cmd "exec {$clusterdir/upgmaclu.exe}"
                append wd "/" 
            }
            default {
                set cmd "exec {$clusterdir/upgmaclu}"
            }
        }
    
        set pwd [pwd]
    
        cd "$wd"
    
        foreach arg $args {
            append cmd " $arg"
        }
    
        puts "UPGMA_Cluster Info) Running upgma_cluster with command $cmd"
        
        set rc [catch {eval $cmd} out]
    
        cd $pwd
    
        return $out
    }
}
