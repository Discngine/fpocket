
#include "../headers/sort.h"

/*

## GENERAL INFORMATION
##
## FILE 					sort.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##  This file contains routines used to sort atoms and vertices systems using
##  coordinates x, y or z. We define a structure containing all information
##  
##
## MODIFICATIONS HISTORY
##
##	11-02-09	(v)  Modified argument type for sorting function
##	28-11-08	(v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Gives more explanation for the file description.

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

static void merge_atom_vert(s_vsort *lsort, s_atm **atoms, int natms, s_vvertice **pvert, int nvert) ;
static void qsort_dim(s_vect_elem *lst, int len) ;
static void qsort_rec(s_vect_elem *lst, int start, int end) ;
static int partition_x(s_vect_elem *lst, int start, int end) ;
 
/**
   ## FUNCTION: 
	get_sorted_list
  
   ## SPECIFICATION: 
	This function will return a lists which will contains all atoms and vertices 
	sorted on x axis.
	First, we merge atom and vertice lists into those a single list. Then they 
	will be sorted using a quickSort algorithm, using the x positions of vertices
	 and atoms as criteria for sorting.
  
   ## PARAMETRES:
	@ s_pdb *pdb			: PDB structure, basically containing atoms
	@ s_vvertice **pvert, int nvert : List of vertices (if NULL, only atoms will be sorted)
  
   ## RETURN:
	  s_vsort*: pointer to the structure containing all sorted data (see .h)
  
*/
s_vsort* get_sorted_list(s_atm **atoms, int natms, s_vvertice **pvert, int nvert)
{
	s_vsort *lsort = (s_vsort *) my_malloc(sizeof(s_vsort)) ;
	
	lsort->nelem = 0 ;

	if(atoms) lsort->nelem += natms ;
	if(pvert) lsort->nelem += nvert ;

	if(lsort->nelem == 0) return NULL ;

	/* Allocate memory */
	lsort->xsort = (s_vect_elem*) my_malloc((lsort->nelem)*sizeof(s_vect_elem)) ;
	
	merge_atom_vert(lsort, atoms, natms, pvert, nvert) ;
	qsort_dim(lsort->xsort, lsort->nelem) ;
	
	return lsort ;

}

/**
   ## FUNCTION: 
	merge_atom_vert
  
   ## SPECIFICATION: 
	Merge atom and vertice lists into three single list that
	will be sorted next.
  
   ## PARAMETRES:
	@ s_vsort *lsort        : Structure that should contains the 3 lists
	@ s_pdb *pdb            : pdb structure containing atoms
	@ s_vvertice **pvert, int nvert : List of v ertices
  
   ## RETURN:
  
*/
static void merge_atom_vert(s_vsort *lsort, s_atm **atoms, int natms, s_vvertice **pvert, int nvert)
{
	s_vect_elem *cur = NULL ;
	
	int i = 0, j = 0,
		pos ;

	if(atoms) {
		for(i = 0 ; i < natms ; i++) {
			atoms[i]->sort_x = i ;
			cur = &(lsort->xsort[i]) ;
			cur->data = atoms[i] ;
			cur->type = M_ATOM_TYPE ;
		}
	}
	
	if(pvert) {
		for(j = 0 ; j < nvert ; j++) {
			pos = i + j ;
			
			pvert[j]->sort_x = pos ;
			cur = &(lsort->xsort[pos]) ;
			cur->data = pvert[j] ;
			cur->type = M_VERTICE_TYPE ;
		}
	}
}

/**
   ## FUNCTION: 
	qsort_dim
  
   ## SPECIFICATION: 
  
   ## PARAMETRES:
	@ s_vect_elem *lst : List of vector to sort
	@ int *len         : Length of the list
  
   ## RETURN:
  
*/
static void qsort_dim(s_vect_elem *lst, int len)
{
	qsort_rec(lst, 0,  len-1) ;
}

/**
   ## FUNCTION: 
	static qsort_rec
  
   ## SPECIFICATION: 
    qsort routine adapted to what we wanna do.
  
   ## PARAMETRES:
	@ s_vect_elem *lst : List of vector to sort
	@ int start		   : Sort from start
	@ int end		   : to end
  
   ## RETURN:
    void
  
*/
static void qsort_rec(s_vect_elem *lst, int start, int end)
{
	if(start < end) {
		int piv = 0 ;
		piv = partition_x(lst, start, end) ;
		
		qsort_rec(lst, start, piv-1) ;
		qsort_rec(lst, piv+1, end) ;
	}
}

/**
   ## FUNCTION: 
	static partition_x
  
   ## SPECIFICATION: 
	Partition function for the qsort on atoms and vertices, using the X coordinate
	as criteria to sort the list.
  
   ## PARAMETRES:
	@ s_vect_elem *lst : List of vector to sort
	@ int start        : Sort from start
	@ int end          : to end
  
   ## RETURN:
   int: qsort index
  
*/
static int partition_x(s_vect_elem *lst, int start, int end)
{
	s_vect_elem tmp ;
	s_atm *acur      = NULL ;
	s_vvertice *vcur = NULL ;
	
	int c = start,
		i ;
		
	float piv ;	 /* TODO: chose randomly the pivot. */
	
	piv = (lst[start].type == M_ATOM_TYPE)? ((s_atm*)lst[start].data)->x : 
											((s_vvertice*)lst[start].data)->x ;
	
	for(i = start+1 ; i <= end ; i++) {
		if(lst[i].type == M_ATOM_TYPE) {
			acur = ((s_atm*) lst[i].data) ;
			if(acur->x < piv) {
				c++ ;
			
				/* We have to swap, so change indices, and swap elements. */
				if(lst[c].type == M_ATOM_TYPE) ((s_atm*)lst[c].data)->sort_x = i ;
				else ((s_vvertice*)lst[c].data)->sort_x = i ;
				
				acur->sort_x = c ;
				
				tmp = lst[c] ;
				lst[c] = lst[i] ; lst[i] = tmp ;
			}
		}
		else {
			vcur = ((s_vvertice*)lst[i].data) ;
			if(vcur->x < piv) {
				c++ ;
			
				/* We have to swap, so change indices, and swap elements. */
				if(lst[c].type == M_ATOM_TYPE) ((s_atm*)lst[c].data)->sort_x = i ;
				else ((s_vvertice*)lst[c].data)->sort_x = i ;
				
				vcur->sort_x = c ;
				
				tmp = lst[c] ;
				lst[c] = lst[i] ; lst[i] = tmp ;
			}
		}
	}
	
	if(lst[c].type == M_ATOM_TYPE) ((s_atm*)lst[c].data)->sort_x = start ;
	else ((s_vvertice*)lst[c].data)->sort_x = start ;
	
	if(lst[start].type == M_ATOM_TYPE) ((s_atm*)lst[start].data)->sort_x = c ;
	else ((s_vvertice*)lst[start].data)->sort_x = c ;
			
	tmp = lst[c] ;
	lst[c] = lst[start] ; lst[start] = tmp ;

	return(c);
}

/**
   ## FUNCTION: 
	print_sorted_lst
  
   ## SPECIFICATION: 
	Print one of the sorted tab of a  s_vsort structure
  
   ## PARAMETRES:
	@ s_vsort *lsort : Structure containing tab
	@ FILE *buf      : Buffer to print in.
  
   ## RETURN:
  
*/
void print_sorted_lst(s_vsort *lsort, FILE *buf)
{
	s_vect_elem *lst = NULL ;
	lst = lsort->xsort ; fprintf(buf, "\n========== Printing list of vertices and atoms sorted on X axe:\n") ;
	
	float cval, prev = -1.0 ;
	int i ;
	
	for(i = 0 ; i < lsort->nelem ; i++) {
		fprintf(buf, "> Element at %d: ", i);
		if(lst[i].type == M_ATOM_TYPE) {
			s_atm *a = (s_atm*) lst[i].data ;
			cval = a->x ;
			fprintf(buf, " ATOM coord = %f, index stored: %d", cval, a->sort_x) ;
		}
		else {
			s_vvertice *v = (s_vvertice*) lst[i].data ;
			cval = v->x ;
			
			fprintf(buf, " VERTICE coord = %f, index stored: %d", cval, v->sort_x) ;
		}
		
		if(prev > cval) fprintf(buf, " !!!!!!! ") ;
		fprintf(buf, "\n") ;
		
		prev = cval ;	
	}
}

/**
   ## FUNCTION: 
	free_s_vsort
  
   ## SPECIFICATION: 
	Free memory for s_vsort structure
  
   ## PARAMETRES:
	@ s_vsort *lsort: Structure to free
  
   ## RETURN:
  
*/
void free_s_vsort(s_vsort *lsort)
{
	if(lsort) {
		if(lsort->xsort) my_free(lsort->xsort) ;
		
		my_free(lsort) ;
	}
}

