
#include "../headers/cluster.h"
/*

 * Copyright <2008-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
/*

## GENERAL INFORMATION
##
## FILE 					cluster.h
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##	This file contains currently only one function, providing
##	a mutliple linkage clustering algorithm performed on a list
##	of pockets.
##
## MODIFICATIONS HISTORY
##
##      19-11-08        (p)  Extension of comments, change in multiple linkage clustering
##	28-11-08	(v)  Comments UTD + minor relooking
##	11-05-08	(v)  singleLinkageClustering -> pck_sl_clust
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##
## TODO or SUGGESTIONS
##
##	(v) Possible improvement:
##		Use the sorted structure to find neighbors in a more
##		efficient way.
##	(v) Rename the file ! (mlcluster.c for example...)
##		Or maybe move this function into pocket.c, as the
##		algorithm deals with pockets only...
##	(v) Check and update if necessary comments of each function!!

*/


void pck_final_clust(c_lst_pockets *pockets, s_fparams *params,float max_dist, int min_nneigh,s_pdb *pdb,s_pdb *pdb_w_lig)
{
	node_pocket *pcur = NULL,
				*pnext = NULL ,
				*curMobilePocket = NULL ;

	node_vertice *vcur = NULL ;
	node_vertice *curMobileVertice = NULL ;

	s_vvertice *vvcur = NULL,
			   *mvvcur = NULL ;
	float vcurx,
		  vcury,
		  vcurz ;
        float curdist;
        float curasphdens,dens1,dens2;
        float **dmat;   /*distance matrix*/
        size_t i,j;
        dmat=(float **)malloc(sizeof(float *)*pockets->n_pockets);
        for(i=0;i<pockets->n_pockets;i++) {
            dmat[i]=(float *) malloc(sizeof(float)*pockets->n_pockets);
            for(j=0;j<pockets->n_pockets;j++) dmat[i][j]=0.0;
        }

	/* Flag to know if two clusters are next to each other by single linkage
	 * clustering...or not */
	int nflag ;

	if(!pockets) {
		fprintf(stderr, "! Incorrect argument during Multiple Linkage Clustering.\n") ;
		return ;
	}

	/* Set the first pocket */
        set_pockets_descriptors(pockets,pdb,params,pdb_w_lig);
	pcur = pockets->first ;
        fprintf(stdout,"\n% Pockets : Having %d comparisons\n",pockets->n_pockets,pockets->n_pockets*pockets->n_pockets);
        i=0;
        size_t n_slist=0;
	while(pcur) {
            j=i+1;
            /* Set the second pocket */
		curMobilePocket = pcur->next ;
		while(curMobilePocket) {
                        curdist=0.0;
            
			nflag = 0 ;
			/* Set the first vertice/alpha sphere center of the first pocket */
			vcur = pcur->pocket->v_lst->first ;
			while(vcur){
            
				/* Set the first vertice/alpha sphere center of the second pocket */
				curMobileVertice = curMobilePocket->pocket->v_lst->first ;
				vvcur = vcur->vertice ;
				vcurx = vvcur->x ;
				vcury = vvcur->y ;
				vcurz = vvcur->z ;

				/* Double loop for vertices -> if not near */
				while(curMobileVertice){

					mvvcur = curMobileVertice->vertice ;
                                        if(dist(vcurx, vcury, vcurz, mvvcur->x, mvvcur->y, mvvcur->z)<max_dist) curdist-=1.0;
					curMobileVertice = curMobileVertice->next;
				}
				vcur = vcur->next ;
			}

			pnext =  curMobilePocket->next ;
			/* If the distance flag has counted enough occurences of near neighbours, merge pockets*/
				/* If they are next to each other, merge them */
				//mergePockets(pcur,curMobilePocket,pockets);
                        //fprintf(stdout,"\ni %d j %d\n",i,j),

                        dens1=pcur->pocket->pdesc->as_density;
                        dens1=((isnan(dens1)) ? 0.0 : dens1);

                        dens2=curMobilePocket->pocket->pdesc->as_density;
                        dens2=((isnan(dens2)) ? 0.0 : dens2);
                        curasphdens=0.01*(dens1-dens2)*(dens1-dens2);
                        curasphdens+=(exp(0.1*dens1)+exp(0.1*dens2))/2.0-1.0;
                        //curasphdens=0.0;
                        dmat[i][j]=curdist;
                        dmat[j][i]=curdist;
                        curMobilePocket = pnext ;
                        n_slist++;
                        j++;
                }
		pcur = pcur->next ;
                i++;
	}
        

        /* Now we have to merge nearby pockets without loosing track*/

        /*create a chained list with track on */
        n_slist=((pockets->n_pockets*pockets->n_pockets)-pockets->n_pockets)/2;
        s_sorted_pocket_list *slist=NULL;
        slist=(s_sorted_pocket_list *)my_malloc(sizeof(s_sorted_pocket_list)*n_slist);
        //s_sorted_pocket_list slist[n_slist];
        for(i=0;i<n_slist;i++) slist[i].dist=0.0;
        //for(i=0;i<n_slist;i++)slist[i]=(s_sorted_pocket_list *)my_malloc(sizeof(s_sorted_pocket_list));
/*
        s_sorted_pocket_list *el=my_malloc(sizeof(s_sorted_pocket_list));
*/
//        pcur=pockets->first;


        int c=0;
        for(i=0;i<pockets->n_pockets-1;i++){
            //curMobilePocket=pcur->next;
            for(j=i+1;j<pockets->n_pockets;j++){

/*
                el->dist=dmat[i][j];
*/
                memcpy(&(slist[c].dist),&(dmat[i][j]),sizeof(float));
                //slist[i+j-1].dist=dmat[i][j];
                slist[c].pid1=i;
                slist[c].pid2=j;
/*
                printf("dist : %f\n",slist[c].dist);
*/
                //if(i==173 && j==299)fprintf(stdout,"\ncurdist %d %d %f %f\n",j+i-1, n_slist,dmat[i][j], slist[j+i-1].dist);
                //fprintf(stdout,"%f %d %d\n",slist[c].dist,slist[c].pid1,slist[c].pid2);
                c++;
            }
  //          pcur=pcur->next;
        }
        //for(i=0;i<n_slist;i++) if(slist[i].dist<-480.0)fprintf(stdout,"%f %d %d\n",slist[i].dist,slist[i].pid1,slist[i].pid2);
        //fflush(stdout);
        qsort((void *)slist,n_slist,sizeof(s_sorted_pocket_list),comp_pocket);


/*
        for(i=0;i<n_slist;i++) fprintf(stdout,"%f %d %d\n",slist[i].dist,slist[i].pid1,slist[i].pid2);
*/
        /*TODO : debug here there are still some neighbours with nan pid's after the qsort*/
        i=0;

        /*create a tmp pocket list for updating pointers*/
        node_pocket **pock_list=my_malloc(sizeof(node_pocket *)*pockets->n_pockets);
        pcur=pockets->first;
        i=0;
        /*get a list of pointers to nodes*/
        while(pcur) {
            pock_list[i]=pcur;
            pcur=pcur->next;
            i++;
        }

        int idx1,idx2;
        node_pocket *p1,*p2;
        i=0;
        size_t init_n_pockets=pockets->n_pockets;

        while((slist[i].dist<=-min_nneigh) && (i<n_slist)){
            /*for all nearby pockets merge*/
/*
            fprintf(stdout,"%f\n",slist[i].dist);
*/
            idx1=slist[i].pid1;
            idx2=slist[i].pid2;

            /*fprintf(stdout,"%d %d\n",idx1,idx2);
            fflush(stdout);*/
            if(pock_list[idx1]!=pock_list[idx2]){
                p1=*(pock_list+idx1);
                p1=pock_list[idx1];
                p2=*(pock_list+idx2);
                p2=pock_list[idx2];
/*
                dens1=((isnan(p1->pocket->pdesc->as_density)) ? 0.0 : p1->pocket->pdesc->as_density)/p1->pocket->pdesc->nb_asph;
*/
/*
                dens2=((isnan(p2->pocket->pdesc->as_density)) ? 0.0 : p2->pocket->pdesc->as_density)/p2->pocket->pdesc->nb_asph;
*/
                //printf("%f vs %f\n",dens1/p1->pocket->pdesc->nb_asph, dens2/p1->pocket->pdesc->nb_asph);
/*
                if(dens1 < 0.1 && dens2 < 0.1){
*/
                    for(j=0;j<init_n_pockets;j++){
                        if(pock_list[j]==p2){ //j!=idx2 &&
                            pock_list[j]=p1;
                            //fprintf(stdout,"update %d to %d\n",j, idx1);
                        }
                    }

                    mergePockets(p1,p2,pockets);
                    pock_list[idx2]=p1;
/*
                }
*/
            }
            i++;
        }

        //for(i=0;i<pockets->n_pockets-1;i++){
            //fprintf(stdout,"dist %d vs %d = %f\n",slist[i].p1->pocket->rank,slist[i].p2->pocket->rank,slist[i].dist);
        //}

        /*free dmat*/
        for(i=0;i<pockets->n_pockets;i++) free(dmat[i]);
        free(dmat);

}




int comp_pocket(const void *el1, const void *el2)
{

    s_sorted_pocket_list *ia = (s_sorted_pocket_list *)el1;
    s_sorted_pocket_list *ib = (s_sorted_pocket_list *)el2;

    //if (ia->dist<0.0)printf("dist %f\n",((s_sorted_pocket_list *)el1)->dist);
  if (ia->dist <  ib->dist) return -1;
  if (ia->dist == ib->dist) return  0;
  if (ia->dist >  ib->dist) return  1;
    return 0;
}




/**
   ## FONCTION:
	void pck_ml_clust(c_lst_pockets *pockets, s_fparams *params)

   ## SPECIFICATION:
	This function will apply a mutliple linkage clustering algorithm on the given
	list of pockets. Considering two pockets, if params->ml_clust_min_nneigh
	alpha spheres are separated by a distance lower than params->ml_clust_max_dist,
	then merge the two pockets.

   ## PARAMETRES:
	@ c_lst_pockets *pockets  : The list of pockets
	@ s_fparams *params       : Parameters of the program, including single
								linkage parameters

   ## RETURN:
	void

*/
void pck_ml_clust(c_lst_pockets *pockets, s_fparams *params)
{
	node_pocket *pcur = NULL,
				*pnext = NULL ,
				*curMobilePocket = NULL ;

	node_vertice *vcur = NULL ;
	node_vertice *curMobileVertice = NULL ;

	s_vvertice *vvcur = NULL,
			   *mvvcur = NULL ;
	float vcurx,
		  vcury,
		  vcurz ;

	/* Flag to know if two clusters are next to each other by single linkage
	 * clustering...or not */
	int nflag ;

	if(!pockets) {
		fprintf(stderr, "! Incorrect argument during Single Linkage Clustering.\n") ;
		return ;
	}

	/* Set the first pocket */
	pcur = pockets->first ;
	while(pcur) {
		/* Set the second pocket */
		curMobilePocket = pcur->next ;
		while(curMobilePocket) {
			nflag = 0 ;
			/* Set the first vertice/alpha sphere center of the first pocket */
			vcur = pcur->pocket->v_lst->first ;
			while(vcur && nflag <= params->sl_clust_min_nneigh){
				/* Set the first vertice/alpha sphere center of the second pocket */
				curMobileVertice = curMobilePocket->pocket->v_lst->first ;
				vvcur = vcur->vertice ;
				vcurx = vvcur->x ;
				vcury = vvcur->y ;
				vcurz = vvcur->z ;

				/* Double loop for vertices -> if not near */
				while(curMobileVertice && nflag <= params->sl_clust_min_nneigh){
					mvvcur = curMobileVertice->vertice ;
					if(dist(vcurx, vcury, vcurz, mvvcur->x, mvvcur->y, mvvcur->z)
						< params->sl_clust_max_dist) {
													/*if beneath the clustering max distance, increment the distance flag*/
						nflag++;
					}
					curMobileVertice = curMobileVertice->next;
				}
				vcur = vcur->next ;
			}

			pnext =  curMobilePocket->next ;
			/* If the distance flag has counted enough occurences of near neighbours, merge pockets*/
			if(nflag >= params->sl_clust_min_nneigh) {
				/* If they are next to each other, merge them */
				mergePockets(pcur,curMobilePocket,pockets);
			}
			curMobilePocket = pnext ;
		}

		pcur = pcur->next ;
	}
}

/**
   ## FONCTION:
	void pck_ml_clust(c_lst_pockets *pockets, s_fparams *params)

   ## SPECIFICATION:
	This function will apply a mutliple linkage clustering algorithm on the given
	list of pockets. Considering two pockets, if params->ml_clust_min_nneigh
	alpha spheres are separated by a distance lower than params->ml_clust_max_dist,
	then merge the two pockets.

   ## PARAMETRES:
	@ c_lst_pockets *pockets  : The list of pockets
	@ s_fparams *params       : Parameters of the program, including single
								linkage parameters

   ## RETURN:
	void

*/
void pck_ml_clust_test(c_lst_pockets *pockets, s_fparams *params)
{
	node_pocket *pcur = NULL,
				*pnext = NULL ,
				*curMobilePocket = NULL ;

	node_vertice *vcur = NULL ;
	node_vertice *curMobileVertice = NULL ;

	s_vvertice *vvcur = NULL,
			   *mvvcur = NULL ;
	float vcurx,
		  vcury,
		  vcurz ;

	/* Flag to know if two clusters are next to each other by single linkage
	 * clustering...or not */
	int nflag,
		restart = 0;

	if(!pockets) {
		fprintf(stderr, "! Incorrect argument during Single Linkage Clustering.\n") ;
		return ;
	}
	printf("ML starting\n") ;
	/* Set the first pocket */
	pcur = pockets->first ;
	while(pcur) {
		/* Set the second pocket */
		curMobilePocket = pcur->next ;
		while(curMobilePocket) {
			nflag = 0 ;
			/* Set the first vertice/alpha sphere center of the first pocket */
			vcur = pcur->pocket->v_lst->first ;
			while(vcur && nflag <= params->sl_clust_min_nneigh){
				/* Set the first vertice/alpha sphere center of the second pocket */
				curMobileVertice = curMobilePocket->pocket->v_lst->first ;
				vvcur = vcur->vertice ;
				vcurx = vvcur->x ;
				vcury = vvcur->y ;
				vcurz = vvcur->z ;

				/* Double loop for vertices -> if not near */
				while(curMobileVertice && nflag <= params->sl_clust_min_nneigh){
					mvvcur = curMobileVertice->vertice ;
					if(dist(vcurx, vcury, vcurz, mvvcur->x, mvvcur->y, mvvcur->z)
						< params->sl_clust_max_dist) {
													/*if beneath the clustering max distance, increment the distance flag*/
						nflag++;
						break ; /* Ensure that at least N vertice in one of the
								   two pockets have N vertice at a distance
								   <= SL_MAX_DST */
					}
					curMobileVertice = curMobileVertice->next;
				}
				vcur = vcur->next ;
			}

			pnext =  curMobilePocket->next ;
			/* If the distance flag has counted enough occurences of near neighbours, merge pockets*/
			if(nflag >= params->sl_clust_min_nneigh) {
				/* If they are next to each other, merge them */
				mergePockets(pcur,curMobilePocket,pockets);
				restart = 1 ; printf("Merging\n") ;
				break ;
			}
			curMobilePocket = pnext ;
		}

		/* Restart the algorithm if two pockets have been merged */
		if(restart == 1) {
			restart = 0 ;
			pcur = pockets->first ;
		}
		else pcur = pcur->next ;
	}
	printf("ML ending\n") ;
}


