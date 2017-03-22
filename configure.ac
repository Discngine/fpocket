#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

# Need the 2.59 version of autoconf
AC_PREREQ(2.59)

# Intialize autoconf, specifiting package name, version and authors
AC_INIT([fpocket], 1.0, [P. Schmidtke <pschmidtke@mmb.pcb.ub.es> and V. Le Guilloux <vincent.le-guilloux@univ-orleans.fr>])

# Check that we run autoconf in the right directory
AC_CONFIG_SRCDIR([src/fpmain.c])

# Auxiliary scripts such as install-sh and depcomp should be in builx-aux
# AC_CONFIG_AUX_DIR([build-aux])

# Initialize automake (foreign package for the moment)
AM_INIT_AUTOMAKE([-Wall -Werror foreign])

# Check for C compiler and make utility
AC_PROG_CC
AC_PROG_MAKE_SET

# Declare output header and output files (Makefiles)
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
        Makefile
        man/Makefile
        bin/Makefile
        ])

# Launch the tool
AC_OUTPUT
