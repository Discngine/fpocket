#
# Wrapper to run volutil binary
#
# $Id: volutil.tcl,v 1.3 2013/04/15 17:57:35 johns Exp $
#

package require exectool
package require mdff_tmp
package provide volutil 1.3

namespace eval ::VolUtil:: {

  variable volutilBin

}

proc ::VolUtil::init_files { } {
  global env
  variable volutilBin
  switch [vmdinfo arch] {
    WIN64 -
    WIN32 {
      set volutilBin [file join $env(VOLUTILDIR) volutil.exe]
    }
    default {
      set volutilBin [file join $env(VOLUTILDIR) volutil]
    }
  }
}

proc volutil { args } { return [eval ::VolUtil::volutil $args] }

proc ::VolUtil::volutil { args } {

  variable volutilBin

  # set $volutilBin
  ::VolUtil::init_files

  # Get temporary filename
  set tmpDir [::MDFF::Tmp::tmpdir]
  set tmpError [file join $tmpDir \
  [::MDFF::Tmp::tmpfilename -prefix volutil -suffix .err -tmpdir $tmpDir]]

  # Check if a filename was specified to redirect volutil's output. If
  # so, the output will be redirected to a file and the file's content
  # will be printed to the terminal at the end of execution. If not,
  # volutil's output will simply be printed to the terminal. This is a
  # workaround since 'exec' does not allow as to 'tee' the output. The
  # caller will be in charge of parsing volutil's output.

  if { [lindex $args 0] == "-tee" } {
    set output [lindex $args 1]
    set args [lreplace $args 0 0]
    set args [lreplace $args 0 0]

    if { [lindex $args 0] == "-quiet" } {
      set args [lreplace $args 0 0]
      set quiet 1
    } else {
      set quiet 0
    }

    if {[catch {eval ::ExecTool::exec {$volutilBin} $args >$output 2>$tmpError} errMsg]} {
      set file [open $tmpError r]
      set err [read $file]
      close $file
      file delete $tmpError
      error $err
    }

    if { $quiet == 0 } {
      set out [open $output r]
      puts [read $out]
      close $out
    }

  } elseif {[catch {eval ::ExecTool::exec {$volutilBin} $args >&@ stdout 2>$tmpError} errMsg]} {
    set file [open $tmpError r]
    set err [read $file]
    close $file
    file delete $tmpError
    error $err
  }
  file delete $tmpError

  return

}

