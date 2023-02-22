
#include "../headers/fpocket.h"
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
c_lst_pockets *search_pocket(s_pdb *pdb, s_fparams *params, s_pdb *pdb_w_lig)
{

    clock_t b, e;
    time_t bt, et;

    c_lst_pockets *pockets = NULL;

    s_clusterlib_vertices *clusterlib_vertices = NULL;
    Node *cluster_tree = NULL;

    /* Calculate and read voronoi vertices comming from qhull */

    //    fprintf(stdout, "========= fpocket algorithm begins =========\n");

    if (DEBUG)
    {
        fprintf(stdout, "> Calculating vertices ...\n");
    }

    bt = clock();

    // s_lst_vvertice *lvert = load_vvertices(pdb, params->min_apol_neigh,
    //                                        params->asph_min_size,
    //                                        params->asph_max_size, 0.0, 0.0, 0.0);

    s_lst_vvertice *lvert = load_vvertices(pdb, params, 0.0, 0.0, 0.0);

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

    if (DEBUG)
    {
        fprintf(stdout, "distance measure : %c\n", params->clustering_method);
        fprintf(stdout, "%d vertices\n", lvert->nvert);
        fprintf(stdout, "needing %.5f s to read the vertices", (double)(clock() - b) / CLOCKS_PER_SEC);
    }

    if (DEBUG)
    {
        fprintf(stdout, "Preparing for clustering\n");
    }

    if (DEBUG)
        print_number_of_objects_in_memory();
    if (params->xlig_resnumber == -1 && params->xpocket_n == 0)
    {
        clusterlib_vertices = prepare_vertices_for_cluster_lib(lvert, params->clustering_method, params->distance_measure);
        if (DEBUG)
            fprintf(stdout, "Clustering\n");
        //    fprintf(stdosut,"distance measure : %c\n",clusterlib_vertices->method);

        if (DEBUG)
            print_number_of_objects_in_memory();

        cluster_tree = treecluster(lvert->nvert,
                                   3,
                                   clusterlib_vertices->pos,
                                   clusterlib_vertices->mask,
                                   clusterlib_vertices->weight,
                                   clusterlib_vertices->transpose,
                                   clusterlib_vertices->dist,
                                   clusterlib_vertices->method,
                                   NULL);
        if (DEBUG)
            print_number_of_objects_in_memory();
        if (cluster_tree == NULL)
        {
            fprintf(stderr, "Error in creating clustering tree, return NULL pointer...breaking up");
            return (0);
        }
        int **clusterIds = cuttree_distance(lvert->nvert, cluster_tree, params->clust_max_dist);
        // int i;
        if (DEBUG)
            print_number_of_objects_in_memory();
        transferClustersToVertices(clusterIds, lvert);

        if (DEBUG)
            fprintf(DEBUG_STREAM, "freeing clusterlib vertices now\n");
        free_cluster_lib_vertices(clusterlib_vertices, lvert->nvert);
        free_cluster_tree(cluster_tree);
        free_cluster_ids(clusterIds, lvert->nvert);
    }
    if (lvert == NULL)
    {
        fprintf(stderr, "! Vertice calculation failed!\n");
        return NULL;
    }

    pockets = assign_pockets(lvert);
    if (DEBUG)
    {
        fprintf(DEBUG_STREAM, "After pocket assignment :\n");
        fflush(DEBUG_STREAM);
        print_number_of_objects_in_memory();
        fprintf(DEBUG_STREAM, "\tpocket : %p :\n\tpocket vertice list : %p\n", pockets, pockets->vertices);
        fflush(DEBUG_STREAM);
    }

    apply_clustering(pockets, params);
    if (DEBUG)
    {
        fprintf(DEBUG_STREAM, "applied clustering to pockets");
        print_number_of_objects_in_memory();
    }

    if (pockets)
    {
        reIndexPockets(pockets);

        //        fprintf(stdout, "> Calculating descriptors and score...\n");

        if (DEBUG)
            print_number_of_objects_in_memory();
        set_pockets_descriptors(pockets, pdb, params, pdb_w_lig);
        if (DEBUG)
            print_number_of_objects_in_memory();

        /* Drop small and too polar binding pockets */

        if (DEBUG)
        {
            print_number_of_objects_in_memory();
            fprintf(DEBUG_STREAM, "drop small and polar clusters\n");
        }

        dropSmallNpolarPockets(pockets, params);
        if (DEBUG)
            print_number_of_objects_in_memory();

        reIndexPockets(pockets);
        if (DEBUG)
            print_number_of_objects_in_memory();

        /* Sorting pockets */
        if (DEBUG)
            print_number_of_objects_in_memory();
        sort_pockets(pockets, M_SCORE_SORT_FUNCT);
        if (DEBUG)
            print_number_of_objects_in_memory();

        // sort_pockets(pockets, M_NASPH_SORT_FUNCT) ;

        if (DEBUG)
            print_number_of_objects_in_memory();
        reIndexPockets(pockets);
        if (DEBUG)
            print_number_of_objects_in_memory();
        //        int i;

        if (params->fpocket_running && params->flag_do_grid_calculations && params->topology_path)
            calculate_pocket_energy_grids(pockets, params, pdb);
        // params->fpocket_running &&
    }

    return pockets;
}
