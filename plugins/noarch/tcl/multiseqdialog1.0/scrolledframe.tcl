package provide multiseqdialog 1.0

namespace eval ::MultiSeqDialog::scrolledframe {
    
    namespace export scrolledframe

  # ==============================
  #
  # scrolledframe
  set version 0.9.1
  set (debug,place) 0
  #
  # a scrolled frame
  #
  # (C) 2003, ulis
  #
  # NOL licence (No Obligation Licence)
  #
  # Changes (C) 2004, KJN
  #
  # NOL licence (No Obligation Licence)
  # ==============================
  #
  # Hacked package, no documentation, sorry
  # See example at bottom
  #
  # ------------------------------
  # v 0.9.1
  #  automatic scroll on resize
  # ==============================

    package provide Scrolledframe $version

    # --------------
    #
    # create a scrolled frame
    #
    # --------------
    # parm1: widget name
    # parm2: options key/value list
    # --------------
    proc scrolledframe {w args} \
    {
      variable {}
      # create a scrolled frame
      frame $w
      # trap the reference
      rename $w ::MultiSeqDialog::scrolledframe::_$w
      # redirect to dispatch
      interp alias {} $w {} ::MultiSeqDialog::scrolledframe::dispatch $w
      # create scrollable internal frame
      frame $w.scrolled -highlightt 0 -padx 0 -pady 0
      # place it
      place $w.scrolled -in $w -x 0 -y 0
      if {$(debug,place)} { puts "place $w.scrolled -in $w -x 0 -y 0" } ;#DEBUG
      # init internal data
      set ($w:vheight) 0
      set ($w:vwidth) 0
      set ($w:vtop) 0
      set ($w:vleft) 0
      set ($w:xscroll) ""
      set ($w:yscroll) ""
      set ($w:width)    0
      set ($w:height)   0
      set ($w:fillx)    0
      set ($w:filly)    0
      # configure
      if {$args != ""} { uplevel 1 ::MultiSeqDialog::scrolledframe::config $w $args }
      # bind <Configure>
      bind $w <Configure> [namespace code [list resize $w]]
      bind $w.scrolled <Configure> [namespace code [list resize $w]]
      # return widget ref
      return $w
    }

    # --------------
    #
    # dispatch the trapped command
    #
    # --------------
    # parm1: widget name
    # parm2: operation
    # parm2: operation args
    # --------------
    proc dispatch {w cmd args} \
    {
      variable {}
      switch -glob -- $cmd \
      {
        con*    { uplevel 1 [linsert $args 0 ::MultiSeqDialog::scrolledframe::config $w] }
        xvi*    { uplevel 1 [linsert $args 0 ::MultiSeqDialog::scrolledframe::xview  $w] }
        yvi*    { uplevel 1 [linsert $args 0 ::MultiSeqDialog::scrolledframe::yview  $w] }
        default { uplevel 1 [linsert $args 0 ::MultiSeqDialog::scrolledframe::_$w    $cmd] }
      }
    }

    # --------------
    # configure operation
    #
    # configure the widget
    # --------------
    # parm1: widget name
    # parm2: options
    # --------------
    proc config {w args} \
    {
      variable {}
      set options {}
      set flag 0
      foreach {key value} $args \
      {
        switch -glob -- $key \
        {
          -fill   \
          {
            # new fill option: what should the scrolled object do if it is smaller than the viewing window?
            if {$value == "none"} {
               set ($w:fillx) 0
               set ($w:filly) 0
            } elseif {$value == "x"} {
               set ($w:fillx) 1
               set ($w:filly) 0
            } elseif {$value == "y"} {
               set ($w:fillx) 0
               set ($w:filly) 1
            } elseif {$value == "both"} {
               set ($w:fillx) 1
               set ($w:filly) 1
            } else {
               error "invalid value: should be \"$w configure -fill value\", where \"value\" is \"x\", \"y\", \"none\", or \"both\""
            }
            resize $w force
            set flag 1
          }
          -xsc*   \
          {
            # new xscroll option
            set ($w:xscroll) $value
            set flag 1
          }
          -ysc*   \
          {
            # new yscroll option
            set ($w:yscroll) $value
            set flag 1
          }
          default { lappend options $key $value }
        }
      }
      # check if needed
      if {!$flag || $options != ""} \
      {
        # call frame config
        uplevel 1 [linsert $options 0 ::MultiSeqDialog::scrolledframe::_$w config]
      }
    }

    # --------------
    # resize proc
    #
    # Update the scrollbars if necessary, in response to a change in either the viewing window
    # or the scrolled object.
    # Replaces the old resize and the old vresize
    # A <Configure> call may mean any change to the viewing window or the scrolled object.
    # We only need to resize the scrollbars if the size of one of these objects has changed.
    # Usually the window sizes have not changed, and so the proc will not resize the scrollbars.
    # --------------
    # parm1: widget name
    # parm2: pass anything to force resize even if dimensions are unchanged
    # --------------
    proc resize {w args} \
    {
      variable {}
      set force [llength $args]

      set _vheight     $($w:vheight)
      set _vwidth      $($w:vwidth)
      # compute new height & width
      set ($w:vheight) [winfo reqheight $w.scrolled]
      set ($w:vwidth)  [winfo reqwidth  $w.scrolled]

      # The size may have changed, e.g. by manual resizing of the window
      set _height     $($w:height)
      set _width      $($w:width)
      set ($w:height) [winfo height $w] ;# gives the actual height of the viewing window
      set ($w:width)  [winfo width  $w] ;# gives the actual width of the viewing window

      if {$force || $($w:vheight) != $_vheight || $($w:height) != $_height} {
        # resize the vertical scroll bar
        yview $w scroll 0 unit
        # yset $w
      }

      if {$force || $($w:vwidth) != $_vwidth || $($w:width) != $_width} {
        # resize the horizontal scroll bar
        xview $w scroll 0 unit
        # xset $w
      }
    } ;# end proc resize

    # --------------
    # xset proc
    #
    # resize the visible part
    # --------------
    # parm1: widget name
    # --------------
    proc xset {w} \
    {
      variable {}
      # call the xscroll command
      set cmd $($w:xscroll)
      if {$cmd != ""} { catch { eval $cmd [xview $w] } }
    }

    # --------------
    # yset proc
    #
    # resize the visible part
    # --------------
    # parm1: widget name
    # --------------
    proc yset {w} \
    {
      variable {}
      # call the yscroll command
      set cmd $($w:yscroll)
      if {$cmd != ""} { catch { eval $cmd [yview $w] } }
    }

    # -------------
    # xview
    #
    # called on horizontal scrolling
    # -------------
    # parm1: widget path
    # parm2: optional moveto or scroll
    # parm3: fraction if parm2 == moveto, count unit if parm2 == scroll
    # -------------
    # return: scrolling info if parm2 is empty
    # -------------
    proc xview {w {cmd ""} args} \
    {
      variable {}
      # check args
      set len [llength $args]
      switch -glob -- $cmd \
      {
        ""      {set args {}}
        mov*    \
        { if {$len != 1} { error "wrong # args: should be \"$w xview moveto fraction\"" } }
        scr*    \
        { if {$len != 2} { error "wrong # args: should be \"$w xview scroll count unit\"" } }
        default \
        { error "unknown operation \"$cmd\": should be empty, moveto or scroll" }
      }
      # save old values:
      set _vleft $($w:vleft)
      set _vwidth $($w:vwidth)
      set _width  $($w:width)
      # compute new vleft
      set count ""
      switch $len \
      {
        0       \
        {
          # return fractions
          if {$_vwidth == 0} { return {0 1} }
          set first [expr {double($_vleft) / $_vwidth}]
          set last [expr {double($_vleft + $_width) / $_vwidth}]
          if {$last > 1.0} { return {0 1} }
          return [list [format %g $first] [format %g $last]]
        }
        1       \
        {
          # absolute movement
          set vleft [expr {int(double($args) * $_vwidth)}]
        }
        2       \
        {
          # relative movement
          foreach {count unit} $args break
          if {[string match p* $unit]} { set count [expr {$count * 9}] }
          set vleft [expr {$_vleft + $count * 0.1 * $_width}]
        }
      }
      if {$vleft + $_width > $_vwidth} { set vleft [expr {$_vwidth - $_width}] }
      if {$vleft < 0} { set vleft 0 }
      if {$vleft != $_vleft || $count == 0} \
      {
        set ($w:vleft) $vleft
        xset $w
        if {$($w:fillx) && ($_vwidth < $_width || $($w:xscroll) == "") } {
          # "scrolled object" is not scrolled, because it is too small or because no scrollbar was requested
          # fillx means that, in these cases, we must tell the object what its width should be
          place $w.scrolled -in $w -x [expr {-$vleft}] -width $_width
          if {$(debug,place)} { puts "place $w.scrolled -in $w -x [expr {-$vleft}] -width $_width" } ;#DEBUG
        } else {
          place $w.scrolled -in $w -x [expr {-$vleft}] -width {}
          if {$(debug,place)} { puts "place $w.scrolled -in $w -x [expr {-$vleft}] -width {}" } ;#DEBUG
        }

      }
    }

    # -------------
    # yview
    #
    # called on vertical scrolling
    # -------------
    # parm1: widget path
    # parm2: optional moveto or scroll
    # parm3: fraction if parm2 == moveto, count unit if parm2 == scroll
    # -------------
    # return: scrolling info if parm2 is empty
    # -------------
    proc yview {w {cmd ""} args} \
    {
      variable {}
      # check args
      set len [llength $args]
      switch -glob -- $cmd \
      {
        ""      {set args {}}
        mov*    \
        { if {$len != 1} { error "wrong # args: should be \"$w yview moveto fraction\"" } }
        scr*    \
        { if {$len != 2} { error "wrong # args: should be \"$w yview scroll count unit\"" } }
        default \
        { error "unknown operation \"$cmd\": should be empty, moveto or scroll" }
      }
      # save old values
      set _vtop $($w:vtop)
      set _vheight $($w:vheight)
  #    set _height [winfo height $w]
      set _height $($w:height)
      # compute new vtop
      set count ""
      switch $len \
      {
        0       \
        {
          # return fractions
          if {$_vheight == 0} { return {0 1} }
          set first [expr {double($_vtop) / $_vheight}]
          set last [expr {double($_vtop + $_height) / $_vheight}]
          if {$last > 1.0} { return {0 1} }
          return [list [format %g $first] [format %g $last]]
        }
        1       \
        {
          # absolute movement
          set vtop [expr {int(double($args) * $_vheight)}]
        }
        2       \
        {
          # relative movement
          foreach {count unit} $args break
          if {[string match p* $unit]} { set count [expr {$count * 9}] }
          set vtop [expr {$_vtop + $count * 0.1 * $_height}]
        }
      }
      if {$vtop + $_height > $_vheight} { set vtop [expr {$_vheight - $_height}] }
      if {$vtop < 0} { set vtop 0 }
      if {$vtop != $_vtop || $count == 0} \
      {
        set ($w:vtop) $vtop
        yset $w
        if {$($w:filly) && ($_vheight < $_height || $($w:yscroll) == "")} {
          # "scrolled object" is not scrolled, because it is too small or because no scrollbar was requested
          # filly means that, in these cases, we must tell the object what its height should be
          place $w.scrolled -in $w -y [expr {-$vtop}] -height $_height
          if {$(debug,place)} { puts "place $w.scrolled -in $w -y [expr {-$vtop}] -height $_height" } ;#DEBUG
        } else {
          place $w.scrolled -in $w -y [expr {-$vtop}] -height {}
          if {$(debug,place)} { puts "place $w.scrolled -in $w -y [expr {-$vtop}] -height {}" } ;#DEBUG
        }
      }
    }
  }