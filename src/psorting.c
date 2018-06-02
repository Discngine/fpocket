
#include "../headers/psorting.h"
/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
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

