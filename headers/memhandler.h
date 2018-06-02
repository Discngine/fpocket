/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
#ifndef DH_MEMHANDLER
#define DH_MEMHANDLER

/* -----------------------------INCLUDES--------------------------------------*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>
#include <time.h>


/* -------------------------------MACROS--------------------------------------*/

#define M_EXIT 1    /**< exit flag*/
#define M_CONTINUE 0 /**< continue flag */

/* ------------------------- PUBLIC STRUCTURES ------------------------------ */

/* ----------------------------PROTOTYPES-------------------------------------*/

void* my_malloc(size_t nb) ;
void* my_calloc(size_t nb, size_t s) ;
void* my_realloc(void *ptr, size_t nb) ;
void my_free(void *bloc) ;
void my_exit(void) ;
void print_number_of_objects_in_memory(void);
void free_all(void) ;
void print_ptr_lst(void) ;

#endif
