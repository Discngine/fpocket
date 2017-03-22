############################################################################
#cr
#cr            (C) Copyright 1995-2003 The Board of Trustees of the
#cr                        University of Illinois
#cr                         All Rights Reserved
#cr
############################################################################

# Simple edit package
# provides functionality to edit sequence alignments from MultiSeq in an
# external editor

package provide simpleedit 1.0

namespace eval ::SimpleEdit:: {
  variable filename ""

  namespace export doSimpleEdit
}

proc ::SimpleEdit::doSimpleEdit { } {
  variable filename

  if {[exportSimpleEditorFile $filename] == 1} {
    if {[invokeEditor $filename] == 1} {
      if {[importSimpleEditorFile $filename] == 1} {
        return 1
      }
      return 0
    }
    return 0
  }
}

# Exports the simple editor file.
# args: path to the file to write
# return: 1 if the file is successfully written, or 0 on error
proc ::SimpleEdit::exportSimpleEditorFile { path } {
  # first try to open the output file
  if { [catch {set fd [open $path "w"]}] > 0 } {
    return 0
  }
  
  set groups [::SeqEditWidget::getGroups]

  # write out the data...
  foreach group $groups {
    puts $fd "# $group"
    foreach seq [::SeqEditWidget::getSequencesInGroup $group] {
      puts $fd "[::SeqData::getName $seq]\t[join [::SeqData::getSeq $seq] {}]"
    }
  }

  close $fd

  return 1
}

# Imports the simple editor file after editing.
# args: path to file to read
# return: 1 if file is successfully read, or 0 on error
proc ::SimpleEdit::importSimpleEditorFile { path } {
  # first try to open the input file
  if { [catch {set fd [open $path "r"]}] > 0 } {
    return 0
  }

  # read the file, overwriting sequences where names match --
  # which should be all sequences, but this makes it safe against
  # some kinds of weirdness
  set editorSequences [::SeqEditWidget::getSequences]
  set updatedSequences {}
  while {![eof $fd]} {
    set line [gets $fd]

    # Make sure line isn't a comment
    if { [regexp {^#.*$} $line] == 0 } {
      # simple 2-part line -- name and sequence
      set lineparts [split $line]
      set name [lindex $lineparts 0]
      set seq [split [lindex $lineparts 1] {}]
      set matchingSeqID -1
      foreach editorSequenceID $editorSequences {
        if {[::SeqData::getName $editorSequenceID] == $name} {
          set matchingSeqID $editorSequenceID
          lappend updateSequences $matchingSeqID
          break
        }
      }
      if {$matchingSeqID != -1} {
        ::SeqData::setSeq $matchingSeqID $seq
      }
    }
  }

  close $fd

  ::SeqEditWidget::updateSequences $updatedSequences

  return 1
}


# Runs the editor
proc ::SimpleEdit::invokeEditor { path } {
  # XXX add code here to override the default internal editor.
  # using $end(EDITOR) is dangerous, since it might point to 
  # a text mode editor (frequently vi) which can hang VMD.
  # for the time being we hook into the textview plugin
  # 
  #global env
  #if { [catch {eval "exec -- $env(EDITOR) $path"}] > 0 } {
  #  return 0
  #}
  #
  if {[catch {package require textview 1.1}]} {
    return 1
  } 
  puts "SimpleEdit) spawning internal text editor"
  ::TextView::textview "$path"
  puts "SimpleEdit) done."
  return 0
}

# Sets up the simple edit temp file
proc ::SimpleEdit::setFilename { dir prefix } {
  variable filename

  set filename ""

  append filename $dir "/" $prefix ".simpleEdit"
}

