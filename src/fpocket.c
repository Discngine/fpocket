
#include "../headers/fpocket.h" 

/*

## GENERAL INFORMATION
##
## FILE 					fpocket.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##	Top function(s) to use for looking for pockets in a given protein.
##	This function will call successively all function necessary to
##	perform pocket detection using voronoi vertices.
##
##	No output is writen, just the list of pockets are returned.
##
## MODIFICATIONS HISTORY
##
 * ##   28-10-12        (p)  Introducing novel more standard clustering approach
##	09-02-09	(v)  Drop tiny pocket step added
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

/**
   ## FUNCTION: 
        pockets search_pocket
  
   ## SPECIFICATION: 
        This function will call all functions needed for the pocket finding algorith
        and will return the list of pockets found on the protein.
  
   ## PARAMETRES:
        @ s_pdb *pdb : The pdb data of the protein to handle.
        @ s_fparams  : Parameters of the algorithm
  
   ## RETURN:
        A chained list of pockets found, sorted according to the current critera
        (the default is a scoring function)
  
 */
c_lst_pockets* search_pocket(s_pdb *pdb, s_fparams *params, s_pdb *pdb_w_lig) {

    clock_t b, e;
    time_t bt, et;

    c_lst_pockets *pockets = NULL;

    s_clusterlib_vertices *clusterlib_vertices = NULL;
    Node *cluster_tree = NULL;


    /* Calculate and read voronoi vertices comming from qhull */

//    fprintf(stdout, "========= fpocket algorithm begins =========\n");

    if (DEBUG) {
        fprintf(stdout, "> Calculating vertices ...\n");
    }

    bt = clock();


    s_lst_vvertice *lvert = load_vvertices(pdb, params->min_apol_neigh,
            params->asph_min_size,
            params->asph_max_size, 0.0, 0.0, 0.0);

    /*if(lvert->nvert>8000){*/
     /*   params->asph_max_size=7.6;
        params->asph_min_size=3.2;
        params->clust_max_dist=1.8;
        params->clustering_method='s';
        params->min_pock_nb_asph=20;*/
    /*}else {
        params->asph_max_size=M_MAX_ASHAPE_SIZE_DEFAULT;
        params->asph_min_size=M_MIN_ASHAPE_SIZE_DEFAULT;
        params->clust_max_dist=M_CLUST_MAX_DIST;
        params->clustering_method='a';
        params->min_pock_nb_asph=M_MIN_POCK_NB_ASPH;
    }*/
    
   
    if (DEBUG) {
         fprintf(stdout,"distance measure : %c\n",params->clustering_method);
        fprintf(stdout, "%d vertices\n", lvert->nvert);
        fprintf(stdout, "needing %.5f s to read the vertices", (double) (clock() - b) / CLOCKS_PER_SEC);
    }



    if (DEBUG) {
        fprintf(stdout, "Preparing for clustering\n");
    }

    if (DEBUG) print_number_of_objects_in_memory();
    fprintf(stdout,"xlig_resnumber %d\n",params->xlig_resnumber);
    fflush(stdout);
    if(params->xlig_resnumber==-1){
    
        clusterlib_vertices = prepare_vertices_for_cluster_lib(lvert, params->clustering_method, params->distance_measure);
        if (DEBUG) fprintf(stdout, "Clustering\n");
    //    fprintf(stdosut,"distance measure : %c\n",clusterlib_vertices->method);

        if (DEBUG) print_number_of_objects_in_memory();

        cluster_tree = treecluster(lvert->nvert,
                3,
                clusterlib_vertices->pos,
                clusterlib_vertices->mask,
                clusterlib_vertices->weight,
                clusterlib_vertices->transpose,
                clusterlib_vertices->dist,
                clusterlib_vertices->method,
                NULL);
        if (DEBUG) print_number_of_objects_in_memory();
        if (cluster_tree == NULL) {
            fprintf(stderr, "Error in creating clustering tree, return NULL pointer...breaking up");
            return (0);
        }
        int **clusterIds = cuttree_distance(lvert->nvert, cluster_tree, params->clust_max_dist);
        //int i;
        if (DEBUG) print_number_of_objects_in_memory();
        transferClustersToVertices(clusterIds, lvert);

        if (DEBUG) fprintf(DEBUG_STREAM, "freeing clusterlib vertices now\n");
        free_cluster_lib_vertices(clusterlib_vertices, lvert->nvert);
        free_cluster_tree(cluster_tree);
        free_cluster_ids(clusterIds, lvert->nvert);
    }
    if (lvert == NULL) {
        fprintf(stderr, "! Vertice calculation failed!\n");
        return NULL;
    }

    pockets = assign_pockets(lvert);
    if (DEBUG) {
        fprintf(DEBUG_STREAM, "After pocket assignment :\n");
        fflush(DEBUG_STREAM);
        print_number_of_objects_in_memory();
        fprintf(DEBUG_STREAM, "\tpocket : %p :\n\tpocket vertice list : %p\n", pockets, pockets->vertices);
        fflush(DEBUG_STREAM);
    }

    apply_clustering(pockets, params);
    if (DEBUG) {
        fprintf(DEBUG_STREAM, "applied clustering to pockets");
        print_number_of_objects_in_memory();
    }

    if (pockets) {
        reIndexPockets(pockets);

//        fprintf(stdout, "> Calculating descriptors and score...\n");

        if (DEBUG)print_number_of_objects_in_memory();
        set_pockets_descriptors(pockets, pdb, params, pdb_w_lig);
        if (DEBUG) print_number_of_objects_in_memory();


        /* Drop small and too polar binding pockets */

        if (DEBUG) {
            print_number_of_objects_in_memory();
            fprintf(DEBUG_STREAM, "drop small and polar clusters\n");
        }

        dropSmallNpolarPockets(pockets, params);
        if (DEBUG) print_number_of_objects_in_memory();

        reIndexPockets(pockets);
        if (DEBUG) print_number_of_objects_in_memory();

        /* Sorting pockets */
        if (DEBUG) print_number_of_objects_in_memory();
        sort_pockets(pockets, M_SCORE_SORT_FUNCT);
        if (DEBUG) print_number_of_objects_in_memory();

        //sort_pockets(pockets, M_NASPH_SORT_FUNCT) ;


        if (DEBUG) print_number_of_objects_in_memory();
        reIndexPockets(pockets);
        if (DEBUG) print_number_of_objects_in_memory();
//        int i;
        
        if (params->fpocket_running && params->flag_do_grid_calculations && params->topology_path) calculate_pocket_energy_grids(pockets, params,pdb);
//params->fpocket_running && 

    }

    return pockets;
}

