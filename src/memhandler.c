
#include "../headers/memhandler.h"

/*

## GENERAL INFORMATION
##
## FILE 					memhandler.h
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##	This file implements a memory handler. Whenever you call 
##	my_bloc_malloc function, the allocated pointer will be 
##	stored in a simple chained list. Then, if a malloc fails, 
##	or if you call the my_exit function, all allocated variable 
##	will be freed if not NULL of course. Therefore, a bloc 
##	allocated by my_... functions MUST be freed by the my_free, 
##	or a double free error should appears.
##
##	WARNING
##
##	This is an easy way to handle memory. However, if many bloc 
##	are allocated and removed during the programm, it might be 
##	solwed down as for each free, as we have to look for the bloc 
##	to free in the list, and remove it.
##
##	REMEMBER: if you use my_malloc, you MUST use my_free. If you 
##	free a bloc allocated by my_(..), and if you call free_all at 
##	the end, a double free coprruption will occure.
##
## MODIFICATIONS HISTORY
##
##	28-11-08	(v)  Comments UTD
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##

*/


/*
    COPYRIGHT DISCLAIMER

    Vincent Le Guilloux, Peter Schmidtke and Pierre Tuffery, hereby
	claim all copyright interest in the program “fpocket” (which
	performs protein cavity detection) written by Vincent Le Guilloux and Peter
	Schmidtke.

    Vincent Le Guilloux  01 Decembre 2012
    Peter Schmidtke      01 Decembre 2012
    Pierre Tuffery       01 Decembre 2012

    GNU GPL

    This file is part of the fpocket package.

    fpocket is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fpocket is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with fpocket.  If not, see <http://www.gnu.org/licenses/>.

**/


/**< Pointer node of a chained list */

typedef struct ptr_node 
{
	struct ptr_node *next ; /**< next pointer node*/
	void *ptr ; /**< pointer to void*/

} ptr_node ;

/**< Simple chained structures to store allocated pointers */
typedef struct
{
	ptr_node *first ;   /**< first pointer of the chained list*/
	ptr_node *last ; /**< last pointer in the chained list*/

	size_t n_ptr ; /**< size of the chained list*/

} ptr_lst ;


static ptr_lst *ST_lst_alloc = NULL ;/* A list containing all the allocated pointers. */
#ifdef M_MEM_DEBUG
static FILE *ST_fdebug = NULL ;
#endif

static ptr_node* ptr_node_alloc(void *ptr) ;
static void add_bloc(void *bloc) ; 
static void remove_bloc(void *bloc) ;


/**
   ## FUNCTION: 
	my_malloc
  
   ## SPECIFICATION: 
	Allocate memory for a bloc of size s.
  
   ## PARAMETRES:
	@ size_t s : Size of the bloc to allocate
  
   ## RETURN:
	void *: Pointer to the allocated bloc
  
*/
void* my_malloc(size_t s)
{
	void *bloc = malloc(s) ;

	if(bloc == NULL) {
		fprintf(stderr, "! malloc failed in my_bloc_malloc. Programm will exit, as demanded.\n") ;
		my_exit() ;
	}

	#ifdef M_MEM_DEBUG
	if(ST_fdebug) fprintf(ST_fdebug, "> (M)Allocation success at: <%p>\n", bloc) ;
	#endif
	add_bloc(bloc) ;

	return bloc ;
}

/**
   ## FUNCTION: 
	my_calloc
  
   ## SPECIFICATION: 
	Allocate memory for nb bloc of size s using calloc standart function.
  
   ## PARAMETRES:
	@ size_t nb : Number of bloc to allocate
	@ size_t s  : Size of the bloc to allocate
  
   ## RETURN:
	void *: Pointer to the allocated bloc
  
*/
void* my_calloc(size_t nb, size_t s)
{
	void *bloc = calloc(nb, s) ;

	if(bloc == NULL){
		fprintf(stderr, "! malloc failed in my_bloc_malloc. Programm will exit, as demanded.\n") ;
		my_exit() ;
	}
	#ifdef M_MEM_DEBUG
	if(ST_fdebug) fprintf(ST_fdebug, "> (C)Allocation success at: <%p>\n", bloc) ;
	#endif
	add_bloc(bloc) ;

	return bloc ;
}

/**
   ## FUNCTION: 
	my_realloc
  
   ## SPECIFICATION: 
	Allocate memory for a bloc of size s using calloc standart function.
  
   ## PARAMETRES:
	@ size_t s : Size of the bloc to allocate
	@ int exit : Whether we exit the programm if malloc fails.
  
   ## RETURN:
	void *: Pointer to the allocated bloc
  
*/
void* my_realloc(void *ptr, size_t s)
{
	void *tmp = ptr ;
	ptr = realloc(ptr, s) ;

	if(ptr == NULL){
		fprintf(stderr, "! malloc failed in my_bloc_malloc. Programm will exit, as demanded.\n") ;
		my_exit() ;
	}
	else {
		if(tmp && tmp != ptr) {
		#ifdef M_MEM_DEBUG
			 if(ST_fdebug) fprintf(ST_fdebug, "> Realloc generates a new pointer: <%p> newly allocated at %p. \n", tmp, ptr) ;
		#endif

	/* If the newly allocated pointer is different from previou s
	   one, remove previous from the list and add new one. Else, 
	   ptr doesn't need to be added. */
			remove_bloc(tmp) ;
			add_bloc(ptr) ;
		}
	}

	return ptr ;
}


/**
   ## FONCTION: 
	ptr_node_alloc
  
   ## SPECIFICATION: 
	Allocate a simple chained node.
  
   ## PARAMETRES:
	@ void *ptr: Pointer
  
   ## RETURN:
	ptr_node*
  
*/
static ptr_node* ptr_node_alloc(void *ptr)
{
	ptr_node *node = (ptr_node *) malloc(sizeof(ptr_node)) ;

	if(node) {
		node->ptr = ptr ;
		node->next = NULL ;
	}
	else {
		fprintf(stderr, "! malloc failed in my_bloc_malloc. Programm will exit, as demanded.\n") ;
		my_exit() ;
	}
	
	return node ;
}


/**
   ## FUNCTION: 
	my_free
  
   ## SPECIFICATION: 
	Free memory for the given bloc, and remove this pointer from the list.
  
   ## PARAMETRES:
	@ void *bloc: Pointer to free.
  
   ## RETURN:
  
*/
void my_free(void *bloc) 
{
        
	if(bloc) {
	#ifdef M_MEM_DEBUG
		if(ST_fdebug) fprintf(ST_fdebug, "> (my_free) Freeing bloc <%p>!\n", bloc) ;
		fflush(ST_fdebug) ;
	#endif
 		remove_bloc(bloc) ;
		free(bloc) ;
	}
	else {
	#ifdef M_MEM_DEBUG
		if(ST_fdebug) fprintf(ST_fdebug, "! Cannot free a NULL variable!\n") ;
	#endif
	}

}

/**
   ## FUNCTION: 
	static add_bloc
  
   ## SPECIFICATION: 
	Add an allocated pointer (bloc) to the list ST_lst_alloc. 

	This function is supposed to be called by my_malloc, my_calloc or my_realloc 
	functions only.
  
   ## PARAMETRES:
	@ void *bloc: The pointer to remove
  
   ## RETURN:
  
*/
static void add_bloc(void *bloc) 
{	
	#ifdef M_MEM_DEBUG
		if(ST_fdebug) fprintf(ST_fdebug, "> Adding bloc %p\n", bloc) ;
	#endif

	/* First check if the list exists, if not create it. */
	if(!ST_lst_alloc) {

		ST_lst_alloc = (ptr_lst*) malloc(sizeof(ptr_lst)) ;
		if(!ST_lst_alloc) {
			fprintf(stderr, "! malloc failed in add_bloc while creating the list. Programm will exit.\n") ;
			my_exit() ;
		}
		#ifdef M_MEM_DEBUG
			ST_fdebug = fopen("memory_debug.tmp", "w") ;
		#endif

		ST_lst_alloc->first = NULL ;
		ST_lst_alloc->last = NULL ;
		ST_lst_alloc->n_ptr = 0 ;
	}

	/* Now add the bloc to the chained list */

	ptr_node *newn = ptr_node_alloc(bloc) ;
	if(ST_lst_alloc->first) {
		newn->next = ST_lst_alloc->first ;
		ST_lst_alloc->first = newn ;
	}
	else {
		ST_lst_alloc->first = newn ;
		ST_lst_alloc->last = newn ;
	}

	ST_lst_alloc->n_ptr += 1 ;
}

/**
   ## FUNCTION: 
	static remove_bloc
  
   ## SPECIFICATION: 
	Remove the given pointer (node) from the list ST_lst_alloc. Donc free the
	memory.

	This function is supposed to be called by my_free function and not another.
  
   ## PARAMETRES:
	@ void *bloc: The pointer to remove.
  
   ## RETURN:	void
  
*/
static void remove_bloc(void *bloc)
{
#ifdef M_MEM_DEBUG
	size_t i = 0 ;
#endif
	/* First check if the list exists, if not create it. */
	if(ST_lst_alloc) {

		ptr_node *cur = ST_lst_alloc->first,
				 *prev = cur ;
	#ifdef M_MEM_DEBUG
		if(!cur && ST_fdebug) fprintf(ST_fdebug, "> No element in the list, so cannot remove <%p>...\n", bloc) ;
		size_t prev_s = ST_lst_alloc->n_ptr ;
	#endif
		while(cur) {
			if(cur->ptr == bloc) {
			/* Remove bloc */
				#ifdef M_MEM_DEBUG
					if(ST_fdebug) fprintf(ST_fdebug, "> Removing <%p>...\n", cur->ptr) ;
				#endif
				if(cur == ST_lst_alloc->first) {
					ST_lst_alloc->first = cur->next ;
				}
				else if(cur == ST_lst_alloc->last) {
					ST_lst_alloc->last = prev ;
					prev->next = NULL ;
				}
				else {
					prev->next = cur->next ;
				}

				cur->next = NULL ;
				free(cur) ;
				ST_lst_alloc->n_ptr -= 1 ;

				break ;
			}
		#ifdef M_MEM_DEBUG
			i++ ;
		#endif

			prev = cur ;
			cur = cur->next ;
		}
	#ifdef M_MEM_DEBUG
		if(i == prev_s && ST_fdebug) fprintf(ST_fdebug, "Memhandler: <%p> not found!\n", bloc) ;
	#endif
	}

	#ifdef M_MEM_DEBUG
	else {
		if(ST_fdebug) fprintf(ST_fdebug, "! No bloc allocated -> cannot remove given argument from an empty list.\n") ;
	}	
	#endif
        
}


int get_number_of_objects_in_memory(void){
    if(ST_lst_alloc) {
        return(ST_lst_alloc->n_ptr);
    }
    return(0);
}

void print_number_of_objects_in_memory(void){
    if(ST_lst_alloc) {
        printf("Having %d objects in memory\n",(int)ST_lst_alloc->n_ptr);
    }
}

/**
   ## FUNCTION: 
	free_all 
  
   ## SPECIFICATION: 
	Free all pointers allocated and present in the list ST_lst_alloc. If a
	NULL pointer is found, ignore it.
  
   ## PARAMETRES:	void
  
   ## RETURN: 	void
  
*/
void free_all(void) 
{
	if(ST_lst_alloc) {

		ptr_node *cur = ST_lst_alloc->first,
				 *tmp = cur ;
		while(cur) {
			if(cur->ptr) {
 			#ifdef M_MEM_DEBUG
 				if(ST_fdebug) fprintf(ST_fdebug, "> Freeing <%p>.\n", cur->ptr) ;
 			#endif
				free(cur->ptr) ;
				cur->ptr = NULL ;
			}
		#ifdef M_MEM_DEBUG
			else {
				if(ST_fdebug) fprintf(ST_fdebug, "! A NULL bloc has been found in free_all!! Ignoring this bloc...\n") ;
			}
		#endif

			tmp = cur->next ;
			cur->next = NULL ;
			free(cur) ;

			cur = tmp ;
		}
		
		free(ST_lst_alloc) ;
		ST_lst_alloc = NULL ;

	}
#ifdef M_MEM_DEBUG
	else {
		if(ST_fdebug) fprintf(ST_fdebug, "! No bloc allocated -> cannot free memory...\n") ;
	}
#endif
}
 
/**
   ## FUNCTION: 
	my_exit
  
   ## SPECIFICATION: 
	Before exiting the programm, just free all allocated pointers (if any). This
	allows to exit the programme whenever one wants during the execution without
	dealing with memory allocation/desallocation.

	This implies to use my_malloc and my_free functions instead of standart
	functions. Only memory blocs allocated with those functions will be freed
	when my_exit is called.
  
   ## PARAMETRES:	void
  
   ## RETURN:	void
  
*/
void my_exit(void) 
{
	free_all() ;

	exit(1) ;
}

/**
   ## FUNCTION: 
	print_ptr_lst 
  
   ## SPECIFICATION: 
	Print allocated pointers stored in ST_lst_alloc for debugging purpose.
  
   ## PARAMETRES:	void
  
   ## RETURN:	void
  
*/
void print_ptr_lst(void) 
{
	if(ST_lst_alloc && ST_lst_alloc->n_ptr > 0) {
		int i = 0 ;
		ptr_node *cur = ST_lst_alloc->first ;
		fprintf(stdout, "\t==============\n\tLst of %d allocated ptr: \n", (int) ST_lst_alloc->n_ptr) ;
		fprintf(stdout, "\tFirst: <%p> - Last: <%p>\n", ST_lst_alloc->first->ptr, ST_lst_alloc->last->ptr) ;
		
		while(cur) {
			if(cur->ptr) {
				fprintf(stdout, "\t<%p> <%d>\n", cur->ptr, (int)sizeof(cur->ptr)) ;
			}
			else {
				fprintf(stdout, "\t! A NULL bloc has been found in position %d.\n", i) ;
			}

			cur = cur->next ;
		}
	}
	else {
		fprintf(stdout, "\t! No bloc allocated yet...\n") ;
	}
}

