WHAT:   Enhanced Tk Console for all Tk platforms

WHERE:  http://tkcon.sourceforge.net/
	http://www.purl.org/net/hobbs/tcl/script/

REQUIREMENTS: Tcl/Tk 8.0+
	Tested through Tcl/Tk 8.4.
        tkcon is all Tcl/Tk code, no compiling required

tkcon is a replacement for the standard console that comes with Tk (on
Windows/Mac, but also works on Unix).  tkcon provides many more features
than the standard console and works on all platforms where Tcl/Tk is
available.  It is meant primarily to aid one when working with the little
details inside tcl and tk and to give Unix users the GUI console provided
by default in the Mac and Windows Tk.

FEATURES:
    Command history
    Path (Unix style) / Proc / Variable name expansion
    Multiple consoles, each with its own state (via multiple interpreters)
    Captures stdout and stderr to console window (puts overridden)
    Hot errors (click on error result to see stack trace)
    Electric character matching (a la emacs)
    Electric proc highlighting
    Enhanced history searching
    Configurable
    Cut / Copy / Paste between windows (interoperates with native platform)
    Communication between consoles and other Tk interpreters
        (including non-tcl ones)
    Works on all Tk platforms

CONTACT: Jeffrey Hobbs, jeff.hobbs at acm.org or jeff at hobbs.org

GETTING STARTED:

tkcon is a single drop-in file.  On Windows, I place this on the desktop
and double-click on it instead of wish/tclsh.  On Unix, I place it in a
directory on my path and run this instead of wish.  I don't have a Mac...

Documentation can be reading by starting with index.html in the docs/
subdirectory.  Happying Tcl'ing!
