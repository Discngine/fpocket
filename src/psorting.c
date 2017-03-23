
#include "../headers/psorting.h"

/*

## GENERAL INFORMATION
##
## FILE 					psorting.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
## This file contains all function needed to sort pocket according to a given
## criteria.
##
## MODIFICATIONS HISTORY
##
##	28-11-08	(v) Corresp renamed to ovlp
##	28-11-08	(v) Created + Comments UTD
##	
## TODO or SUGGESTIONS
##
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

static void pock_qsort_rec(c_lst_pockets *pockets, node_pocket **pocks, 
						   int start, int end, 
						   int (*fcmp)(const node_pocket*, const node_pocket*) ) ;

static int pock_partition(c_lst_pockets *pockets, node_pocket **pocks, 
						  int start, int end, 
						  int (*fcmp)(const node_pocket*, const node_pocket*));

/**
   ## FUNCTION: 
	sort_pockets 
  
   ## SPECIFICATION: 
	Top function used to sort pockets. First we copy the chained list of 
	pockets in a tab to make use of indices (for the quick sort algorithm),
	and then we will sort this tab, and update in the same time the chained list.
	

	Finally, the given chained list will be modified and sorted using the 
	function given in argument.
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets: The list of pockets that will be updated
	@ int (*fcmp)(const node_pocket*, const node_pocket*): Comparison function
  
   ## RETURN:
  
*/
void sort_pockets(c_lst_pockets *pockets, 
				  int (*fcmp)(const node_pocket*, const node_pocket*)) 
{
	size_t npock = 0 ;
	node_pocket **pocks = (node_pocket **)my_calloc(pockets->n_pockets, sizeof(node_pocket*)) ;
	node_pocket *cur = pockets->first ;

	while(cur && npock < pockets->n_pockets) {
		pocks[npock] = cur ;
		cur = cur->next ;
		npock++ ;
	}
	pock_qsort_rec(pockets, pocks, 0,  npock-1, fcmp) ;

	my_free(pocks) ;
}

/**
   ## FUNCTION: 
	static pock_qsort_rec
  
   ## SPECIFICATION: 
	This function will perform a recursive quick sort on the given tab, updating
	the corresponding chained list.
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets : The list of pockets that will be updated
	@ node_pocket **pocks    : Tab that will be sorted
	@ int start				 : start index of the sort
	@ int end				 : end index of the sort
	@ int (*fcmp)(const node_pocket*, const node_pocket*): Comparison function
  
   ## RETURN:
  
*/
static void pock_qsort_rec(c_lst_pockets *pockets, node_pocket **pocks, 
						   int start, int end, 
						   int (*fcmp)(const node_pocket*, const node_pocket*) )
{
	if(start < end) {
		int piv = 0 ;
		piv = pock_partition(pockets, pocks, start, end, fcmp) ;
		
		pock_qsort_rec(pockets, pocks, start, piv-1, fcmp) ;
		pock_qsort_rec(pockets, pocks, piv+1, end, fcmp) ;
	}
}

/**
   ## FUNCTION: 
	static pock_partition
  
   ## SPECIFICATION:
	Partition fuction used for the quicksort. The comparison between two pockets
	is done with the function given in last argument. The pivot is chosen as the
	first element of the tab. A possible amelioration is to chose it randomly,
	to avoid low performance on already sorted tab...

	The function is sorting a tab of pointer to the pockets, and will update the
	corresponding chained list.
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets : The list of pockets that will be updated
	@ node_pocket **pocks    : Tab that will be sorted
	@ int start				 : start index of the sort
	@ int end				 : end index of the sort
	@ int (*fcmp)(const node_pocket*, const node_pocket*): Comparison function
  
   ## RETURN:
  
*/
static int pock_partition(c_lst_pockets *pockets, node_pocket **pocks, int start, int end, 
							int (*fcmp)(const node_pocket*, const node_pocket*))
{
	node_pocket *cpock = NULL,
				*tmp = NULL,
				*piv = NULL ;
	
	int c = start,
		i = 0 ;
		
	piv = pocks[start] ;	 // TODO: chose randomly the pivot.
	for(i = start+1 ; i <= end ; i++) {
		cpock = pocks[i] ;
		if( fcmp(cpock, piv) == -1) {
			c++ ;
			if(c != i) {
				swap_pockets(pockets, pocks[c], pocks[i]) ;
				tmp = pocks[c] ;
				pocks[c] = pocks[i] ; pocks[i] = tmp ;
			}
		}
	}
	
	if(c != start) {
		swap_pockets(pockets, pocks[c], piv) ;
		tmp = pocks[c] ;
		pocks[c] = pocks[start] ; pocks[start] = tmp ;
	
	}

	return(c) ;
}

/**
   ## FUNCTION: 
	compare_pockets_nasph
  
   ## SPECIFICATION:
	Function comparing two pocket on there number of alpha spheres. 
	Uses this for quicksort, or whatever you want...
  
   ## PARAMETRES:
	@ const node_pocket *p1: Pocket 1
	@ const node_pocket *p2: Pocket 2
  
   ## RETURN:. 
  
*/
int compare_pockets_nasph(const node_pocket *p1, const node_pocket *p2) 
{
	if(p1->pocket->pdesc->nb_asph < p2->pocket->pdesc->nb_asph) return 1 ;
	else return -1 ;
}


/**
   ## FUNCTION: 
	compare_pockets_volume
  
   ## SPECIFICATION:
	Function comparing two pocket on there volume. Uses this for quicksort, or
	whatever you want...
  
   ## PARAMETRES:
	@ const node_pocket *p1: Pocket 1
	@ const node_pocket *p2: Pocket 2
  
   ## RETURN:
	1 if the volume of p2 is greater than the volume of p1, -1 else. 
  
*/
int compare_pockets_volume(const node_pocket *p1, const node_pocket *p2) 
{
	if(p1->pocket->pdesc->volume < p2->pocket->pdesc->volume) return 1 ;
	else return -1 ;
}

/**
   ## FUNCTION: 
	compare_pockets_score
  
   ## SPECIFICATION:
	Function comparing two pocket on there score. Uses this for quicksort, or
	whatever you want...
  
   ## PARAMETRES:
	@ const node_pocket *p1: Pocket 1
	@ const node_pocket *p2: Pocket 2
  
   ## RETURN:
	1 if the score of p2 is greater than the score of p1, -1 else. 
  
*/
int compare_pockets_score(const node_pocket *p1, const node_pocket *p2) 
{
	if(p1->pocket->score < p2->pocket->score) return 1 ;
	else return -1 ;
}

/**
   ## FUNCTION: 
	compare_pockets_corresp
  
   ## SPECIFICATION:
	Function comparing two pocket on there correspondance with the ligan (for the
	test programm). Uses this for quicksort, orwhatever you want...
  
   ## PARAMETRES:
	@ const node_pocket *p1: Pocket 1
	@ const node_pocket *p2: Pocket 2
  
   ## RETURN:
	1 if the correspondance of p2 is greater than the correspondance of p1, -1 else. 
  
*/
int compare_pockets_corresp(const node_pocket *p1, const node_pocket *p2) 
{
	if(p1->pocket->ovlp < p2->pocket->ovlp) return 1 ;
	else return -1 ;
}

/**
   ## FUNCTION: 
	compare_pockets_vol_corresp
  
   ## SPECIFICATION:
	Function comparing two pocket on there volume correspondance with the ligan 
	(for the test programm). Uses this for quicksort, orwhatever you want...
  
   ## PARAMETRES:
	@ const node_pocket *p1: Pocket 1
	@ const node_pocket *p2: Pocket 2
  
   ## RETURN:
	1 if the volume correspondance of p2 is greater than the volume  
	correspondance of p1, -1 else. 
  
*/
int compare_pockets_vol_corresp(const node_pocket *p1, const node_pocket *p2) 
{
	if(p1->pocket->vol_corresp < p2->pocket->vol_corresp) return 1 ;
	else return -1 ;
}

