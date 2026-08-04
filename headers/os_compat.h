/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */


#ifndef DH_OS_COMPAT
#define DH_OS_COMPAT

/* ------------------------------ INCLUDES ---------------------------------- */

#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef _WIN32
#include <direct.h>
#else
#include <unistd.h>
#endif

/* ------------------------------ DESCRIPTION ------------------------------- */
/**
 * Directory creation and permissions, which are the only places where fpocket
 * needs to know which operating system it runs on.
 *
 * These used to be done by handing a command to system(): "mkdir -p", "chmod +x".
 * That made the output directories depend on a POSIX shell being present, and it
 * passed a filename straight to that shell. Doing the same work through the C
 * library removes both problems and is what lets fpocket build on Windows, where
 * mkdir() takes no mode and chmod +x has no meaning.
 */

/* ------------------------------- PUBLIC MACROS ---------------------------- */

#define M_MAX_MKDIR_PATH 2048 /**< longest path m_mkdir_p will walk */

/* ------------------------------ PUBLIC FUNCTIONS -------------------------- */

/**
   ## FUNCTION:
        m_mkdir

   ## SPECIFICATION:
        Creates a single directory. An already existing directory is a success:
        fpocket rewrites its output folder on every run.

   ## PARAMETRES:
        @ const char *path : directory to create

   ## RETURN:
        int : 0 on success, -1 otherwise

*/
static int m_mkdir(const char *path)
{
    int status;

#ifdef _WIN32
    status = _mkdir(path);
#else
    status = mkdir(path, 0755);
#endif

    if (status != 0 && errno == EEXIST) return 0;

    return status;
}

/**
   ## FUNCTION:
        m_mkdir_p

   ## SPECIFICATION:
        Creates a directory and every missing parent, as "mkdir -p" did. Both
        separators are accepted because fpocket builds its paths with '/' even
        when running on Windows.

   ## PARAMETRES:
        @ const char *path : directory to create

   ## RETURN:
        int : 0 on success, -1 otherwise

*/
static int m_mkdir_p(const char *path)
{
    char tmp[M_MAX_MKDIR_PATH];
    size_t len,
           i;

    len = strlen(path);
    if (len == 0 || len >= sizeof(tmp)) return -1;

    strcpy(tmp, path);

    /* A trailing separator would make the final mkdir act on an empty name. */
    while (len > 1 && (tmp[len-1] == '/' || tmp[len-1] == '\\')) {
        tmp[len-1] = '\0';
        len --;
    }

    /* i starts at 1 so that a leading '/' is not mistaken for a component. */
    for (i = 1; i < len; i++) {
        if (tmp[i] == '/' || tmp[i] == '\\') {
            char sep = tmp[i];
            tmp[i] = '\0';
            if (m_mkdir(tmp) != 0) return -1;
            tmp[i] = sep;
        }
    }

    return m_mkdir(tmp);
}

/**
   ## FUNCTION:
        m_tmpdir

   ## SPECIFICATION:
        Directory for the scratch files handed to qhull. TMPDIR is honoured first
        so an existing setup keeps working; Windows names the same thing TEMP or
        TMP and has no /tmp, which is why the hardcoded fallback used to leave
        fopen() returning NULL and the tessellation writing through it.

   ## PARAMETRES:
        void

   ## RETURN:
        const char * : an existing directory, without a trailing separator

*/
static const char *m_tmpdir(void)
{
    const char *d;

    d = getenv("TMPDIR");
    if (d && *d) return d;

#ifdef _WIN32
    d = getenv("TEMP");
    if (d && *d) return d;

    d = getenv("TMP");
    if (d && *d) return d;

    return ".";
#else
    return "/tmp";
#endif
}

/**
   ## FUNCTION:
        m_make_executable

   ## SPECIFICATION:
        Marks a file as executable. fpocket uses it on the shell wrappers it
        writes for VMD and PyMOL. Windows decides by extension, so there is
        nothing to do there.

   ## PARAMETRES:
        @ const char *path : file to mark

   ## RETURN:
        int : 0 on success, -1 otherwise

*/
static int m_make_executable(const char *path)
{
#ifdef _WIN32
    (void) path;
    return 0;
#else
    struct stat st;

    if (stat(path, &st) != 0) return -1;

    return chmod(path, st.st_mode | S_IXUSR | S_IXGRP | S_IXOTH);
#endif
}

#endif
