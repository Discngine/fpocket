#include "../headers/refine.h"
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
## FILE 					refine.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			30-01-12
##
## SPECIFICATIONS
##
## This file defins several routines which refine the clustering algorithm
## used by fpocket. In particular, we merge pockets too closed from each other
## we drop small pockets, and we perform reindexation after those operations.
##
## MODIFICATIONS HISTORY
##
##      30-01-12        (p)  Adding apply clustering routine for new clustering
##	09-02-09	(v)  Drop tiny pocket routine added
##	28-11-08	(v)  Comments UTD 
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
## (v) Improve and optimize the algorithm.
##

*/


/**
   ## FUNCTION:
	apply_clustering


   ## SPECIFICATION:
        Using prior clustering results written to vertice resid's, update and
 *      merge pockets here

   ## PARAMETRES:
	@ c_lst_pockets *pockets : The list of pockets.
	@ s_fparams *params      : Parameters

   ## RETURN:
	void

*/
void apply_clustering(c_lst_pockets *pockets, s_fparams *params)
{
	node_pocket *nextPocket;
	node_pocket *curMobilePocket;

	node_pocket *pcur = NULL ;
        s_vvertice *vcur=NULL;
        int cur_resid=-1;
        s_vvertice *vmobile=NULL;

        int cur_mobile_resid=-2;

	if(pockets) {
            pcur = pockets->first ;
            while(pcur) {
                vcur=pcur->pocket->v_lst->first->vertice;
                curMobilePocket = pcur->next ;
                cur_resid=vcur->resid;
                while(curMobilePocket) {
                    vmobile=curMobilePocket->pocket->v_lst->first->vertice;
                    cur_mobile_resid=vmobile->resid;
                    nextPocket = curMobilePocket->next;
                    
                    if(cur_resid==cur_mobile_resid) {
                    // Merge pockets if barycentres are close to each other
                            mergePockets(pcur, curMobilePocket, pockets);
                    }
                    curMobilePocket = nextPocket ;
                }

                pcur = pcur->next ;
            }
	}
	else {
		fprintf(stderr, "! No pocket to refine! (argument NULL: %p).\n", pockets) ;
	}
}


/**
   ## FUNCTION: 
	dropSmallNpolarPockets
	--
   ## SPECIFICATION:
	Refine algorithm: will remove small pockets (depends on the corresponding
	parameters in params), pockets containing less than NB apolar alpha spheres
	(given in params)..
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets : The list of pockets.
	@ s_fparams *params      : Parameters
  
   ## RETURN:
	void
  
*/
void dropSmallNpolarPockets(c_lst_pockets *pockets, s_fparams *params)
{
	double pasph = 0.0 ;
	node_pocket *npcur = NULL,
				*nextPocket1 = NULL;
	s_pocket *pcur = NULL ;
	
	if(pockets) {
		npcur = pockets->first ;
		while(npcur) {
			pcur = npcur->pocket ;
			nextPocket1 = npcur->next ;
			pasph = (float)((float)pcur->nAlphaApol/(float)pcur->v_lst->n_vertices) ;


			if(pcur->v_lst->n_vertices < (size_t) params->min_pock_nb_asph 
				||  pasph <  (params->refine_min_apolar_asphere_prop || pcur->pdesc->as_density<params->min_as_density)){
			/* If the pocket is too small or has not enough apolar alpha
			 * spheres, drop it */
				dropPocket(pockets, npcur);		
			}

			if(pockets->n_pockets <= 0) fprintf(stderr, "! No Pockets Found while refining\n");
			npcur = nextPocket1 ;
		}
	}
	else {
		fprintf(stderr, "! No pockets to drop from (argument NULL: %p).\n", pockets) ;
	}

}

/**
   ## FUNCTION:
	drop_tiny
	--
   ## SPECIFICATION:
	Drop really tiny pockets (< 5 alpha spheres)
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets : The list of pockets.
  
   ## RETURN:
	void
  
*/
void drop_tiny(c_lst_pockets *pockets, s_fparams *params)
{
	node_pocket *npcur = pockets->first,
				*npnext = NULL ;
	while(npcur) {
		npnext = npcur->next ;

		if(npcur->pocket->v_lst->n_vertices < params->min_pock_nb_asph){
		/* If the pocket is really small, drop it */
			dropPocket(pockets, npcur);
		}

		if(pockets->n_pockets <= 0) fprintf(stderr, "! No Pockets Found while refining\n");
		npcur = npnext ;
	}
}

/**
   ## FUNCTION: 
	reIndexPockets
  
   ## SPECIFICATION:
	Reindex pockets, after dropping and merging operations on pockets and
	recalculate barycentres in the same loop
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets: The list of pockets.
  
   ## RETURN:
	void
  
*/
void reIndexPockets(c_lst_pockets *pockets)
{
	node_vertice *vcur = NULL ;
	node_pocket *pcur = NULL ;
	s_pocket *pock_cur = NULL ;

	int curPocket = 0,
		n_vert ;

	float posSum[3];

	if(pockets && pockets->n_pockets > 0) {
		pcur = pockets->first ;
		while(pcur) {
			curPocket++ ;						//new index counter
			n_vert = 0 ;

			pock_cur = pcur->pocket ;
			pock_cur->bary[0]=0 ;
			pock_cur->bary[1]=0 ;
			pock_cur->bary[2]=0 ;
				
			posSum[0]=0; posSum[1]=0; posSum[2]=0;
			if(pock_cur->v_lst){
				vcur = pock_cur->v_lst->first;
				while(vcur){
					posSum[0] += vcur->vertice->x;
					posSum[1] += vcur->vertice->y;
					posSum[2] += vcur->vertice->z;
					n_vert++;
	
					vcur->vertice->resid = curPocket;	//set new index
					vcur = vcur->next ;
				}
			}
			else {
				fprintf(stderr, "! Empty Pocket...something might be wrong over here ;).\n") ; 
			}
			//set new barycentre
			pock_cur->bary[0] = posSum[0]/(float)n_vert;
			pock_cur->bary[1] = posSum[1]/(float)n_vert;
			pock_cur->bary[2] = posSum[2]/(float)n_vert;
			pcur = pcur->next ;
		}
	}
	else {
		fprintf(stderr, "! No pocket to reindex.\n") ;
	}
}

