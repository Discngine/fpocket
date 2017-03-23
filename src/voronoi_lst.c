
#include "../headers/voronoi_lst.h"

/*

## GENERAL INFORMATION
##
## FILE 					voronoi_lst.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			02-12-08
##
## SPECIFICATIONS
##
##  Routines dealing with chained list of vertices.
##
## MODIFICATIONS HISTORY
##
##	03-11-10	(v)  Added method to remove a node (not tested yet)
##	02-12-08	(v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
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

/**
   ## FONCTION: 
   lst_vertices_alloc
  
   ## SPECIFICATION: 
	Allocate a list of vertices
  
   ## PARAMETRES:
  
   ## RETURN:
	c_lst_vertices*
  
*/
c_lst_vertices *c_lst_vertices_alloc(void) 
{
	c_lst_vertices *lst = (c_lst_vertices *)my_malloc(sizeof(c_lst_vertices)) ;

	lst->first = NULL ;
	lst->last = NULL ;
	lst->current = NULL ;
	lst->n_vertices = 0 ;

	return lst ;
}

/**
   ## FONCTION: 
	node_vertice_alloc
  
   ## SPECIFICATION: 
	Allocate memory for one vertice node.
  
   ## PARAMETRES:
	@ s_vvertice *vertice : pointer to the vertice to store in the node
  
   ## RETURN:
	node_vertice*: Allocated node
  
*/
node_vertice *node_vertice_alloc(s_vvertice *vertice)
{
	node_vertice *n_vertice = (node_vertice *) my_malloc(sizeof(node_vertice)) ;

	n_vertice->next = NULL ;
	n_vertice->prev = NULL ;
	n_vertice->vertice = vertice ;
	
	return n_vertice ;
}

/**
   ## FONCTION: 
	c_vertice_lst_add_first
  
   ## SPECIFICATION: 
	Add a vertice at the first position of the list.
  
   ## PARAMETRES:
	@ c_lst_vertices *lst : chained list of vertices
	@ s_vvertice *vertice : vertice to add
  
   ## RETURN:
	node_vertice *: pointer toi the new node.
  
*/
node_vertice *c_lst_vertices_add_first(c_lst_vertices *lst, s_vvertice *vertice)
{
	node_vertice *newn = NULL ;

	if(lst) {
		newn = node_vertice_alloc(vertice) ;
		lst->first->prev = newn ;
		newn->next = lst->first ;

		lst->first = newn ;
		lst->n_vertices += 1 ;
	}
	
	return newn ;
}

/**
   ## FONCTION: 
	c_vertice_lst_add_last
  
   ## SPECIFICATION: 
	Add a vertice at the end of the chained list
  
   ## PARAMETRES:
	@ c_lst_pocket *lst   : chained list of pockets
	@ s_vvertice *vertice : vertice to add
  
   ## RETURN:
	node_vertice *: Pointer to the new node
  
*/
node_vertice *c_lst_vertices_add_last(c_lst_vertices *lst,s_vvertice *vertice)
{
	struct node_vertice *newn = NULL ;
        
	if(lst) {
		newn = node_vertice_alloc(vertice) ;
		if(lst->last) {
			newn->prev = lst->last ;
			lst->last->next = newn ;
		}
		else {
			lst->first = newn ;
		}
		lst->last = newn ;
		lst->n_vertices += 1 ;
	}

	return newn ;
}

/**
   ## FONCTION:
	c_lst_vertices_drop

   ## SPECIFICATION:
    Remove a node. We don't free the memory of the node.

   ## PARAMETRES:
	@ c_lst_vertices *lst : chained list of vertices
	@ node_vertice *node : node to remove

   ## RETURN:
	node_vertice *: a pointer to the node following the node to remove (might be
                    null if the node removed was the last node of the list).

*/
node_vertice *c_lst_vertices_drop(c_lst_vertices *lst, node_vertice *node)
{
    node_vertice *next = node->next ;
    if(node->next != NULL) {
        /* The node is not the last one*/
        node->next->prev = node->prev ;
        if(node->prev == NULL) {
            /* The node was the first node*/
            lst->first = node->next ;
        }
        else {
            node->prev->next = node->next ;
        }
    }
    else {
        /* We are at the end of the list */
        if(node->prev != NULL) {
            node->prev->next = NULL ;
        }
        else {
            /* Last node in the list..*/
            lst->first = NULL ;
            lst->last = NULL ;
        }
    }
    
	lst->n_vertices -= 1 ;
    
    return next ;
}

/**
   ## FONCTION: 
   lst_vertice_free
  
   ## SPECIFICATION: 
	Free memory of a chained list
  
   ## PARAMETRES:
	@ c_lst_vertices *lst: list of voronoi vertices
  
   ## RETURN:
  
*/
void c_lst_vertices_free(c_lst_vertices *lst) 
{
	//fprintf(stdout, "Freeing list of vertices\n") ;
	node_vertice *next = NULL ;
	
	if(lst) {
		lst->current = lst->first ;
		while(lst->current) {
			next = lst->current->next ;
			my_free(lst->current) ;
			lst->current = next ;
        }
	}

	lst->first = NULL ;
	lst->last = NULL ;
	lst->current = NULL ;

	my_free(lst) ;
}

/**
   ## FUNCTION: 
	get_vert_contacted_atms
  
   ## SPECIFICATION: 
	Get the list of atoms contacted by each vertice in the given list of vertices.
  
   ## PARAMETRES:
	@ c_lst_vertices *v_lst : The list of vertices of the pocket.
	@ int *nneigh           : OUTPUT A pointer to the number of neighbour found, 
 							  will be modified
  
   ## RETURN:
	A tab of pointers to the pocket contacting atoms.
  
*/
s_atm** get_vert_contacted_atms(c_lst_vertices *v_lst, int *nneigh) 
{
	int i ;
	int nb_neigh = 0 ;
	int atm_seen[v_lst->n_vertices * 4] ;

	s_atm **neigh = (s_atm **)my_malloc(sizeof(s_atm*)*v_lst->n_vertices * 4) ;
	
	node_vertice *cur = v_lst->first ;

	while(cur) {
		s_vvertice *vcur = cur->vertice ;
		
		for(i = 0 ; i < 4 ; i++) {
		/* For each neighbor, if this atom has not been see yet, add it. */
			if(!in_tab(atm_seen, nb_neigh, vcur->neigh[i]->id)) {
				neigh[nb_neigh] = vcur->neigh[i] ;
				atm_seen[nb_neigh] = neigh[nb_neigh]->id ;
				nb_neigh++ ;
			}
		}

		cur = cur->next ;
	}

	*nneigh = nb_neigh ;

	return neigh ;
}
